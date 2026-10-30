from datetime import date, datetime, timezone
import json
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from types import SimpleNamespace
from urllib.request import urlopen
from unittest.mock import patch

from nas.fminute.benchmark_history import (
    BENCHMARKS, BenchmarkArchive, BenchmarkHistoryError, YahooBenchmarkProvider,
)
from nas.fminute.http_api import make_handler


class BenchmarkHistoryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.archive = BenchmarkArchive(Path(self.directory.name) / "benchmarks.sqlite3")

    def tearDown(self):
        self.directory.cleanup()

    def row(self, **overrides):
        value = {"benchmarkId": "nasdaq100", "date": "2026-10-29",
                 "open": 20000.0, "high": 20200.0, "low": 19900.0, "close": 20100.0,
                 "volume": 1000000, "sourceTimestamp": "2026-10-29T20:00:00+00:00",
                 "fetchedAt": "2026-10-30T14:00:00+00:00", "source": "test provider"}
        value.update(overrides)
        return value

    def test_archive_round_trips_and_empty_is_explicit(self):
        self.assertEqual(self.archive.history("nasdaq100")["status"], "unavailable")
        self.assertEqual(self.archive.ingest([self.row()]), 1)
        result = self.archive.history("nasdaq100", date(2026, 10, 29), date(2026, 10, 29))
        self.assertEqual(result["status"], "available")
        self.assertEqual(result["sampleCount"], 1)
        self.assertEqual(result["bars"][0]["close"], 20100.0)
        self.assertEqual(result["ticker"], "^NDX")

    def test_rejects_invalid_identity_ohlc_and_naive_timestamps(self):
        for row in (self.row(benchmarkId="made_up"), self.row(high=19800),
                    self.row(fetchedAt="2026-10-30T14:00:00")):
            with self.subTest(row=row), self.assertRaises(BenchmarkHistoryError):
                self.archive.ingest([row])

    def test_provider_parses_payload_and_skips_null_price(self):
        payload = {"chart": {"result": [{
            "meta": {"exchangeTimezoneName": "America/New_York"},
            "timestamp": [1793312400, 1793398800],
            "indicators": {"quote": [{"open": [100, None], "high": [105, 105],
                "low": [99, 99], "close": [104, 104], "volume": [2000, 2000]}]}
        }], "error": None}}
        class Response:
            def __enter__(self): return self
            def __exit__(self, *_args): return None
            def read(self, _limit): return json.dumps(payload).encode()
        with patch("nas.fminute.benchmark_history.urlopen", return_value=Response()):
            provider = YahooBenchmarkProvider(clock=lambda: datetime(2026, 10, 30, tzinfo=timezone.utc))
            rows = provider.fetch("nasdaq100")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["close"], 104.0)
        self.assertEqual(BENCHMARKS["hang_seng"].market, "HK")


    def test_http_endpoint_exposes_camel_case_archived_rows(self):
        self.archive.ingest([self.row()])
        service = SimpleNamespace(benchmark_archive=self.archive,
                                  benchmark_worker=SimpleNamespace(status={"status": "ok"}))
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(service))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with urlopen(f"http://127.0.0.1:{server.server_port}/api/v1/benchmark-history"
                         "?benchmarkId=nasdaq100&startDate=2026-10-29&endDate=2026-10-29",
                         timeout=3) as response:
                payload = json.loads(response.read())
            self.assertEqual(payload["status"], "available")
            self.assertEqual(payload["sampleCount"], 1)
            self.assertEqual(payload["bars"][0]["tradingDate"], "2026-10-29")
            self.assertEqual(payload["bars"][0]["fetchedAt"], "2026-10-30T14:00:00+00:00")
            self.assertEqual(payload["collector"]["status"], "ok")
            self.assertNotIn("trading_date", payload["bars"][0])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_unknown_benchmark_and_reversed_range_fail_closed(self):
        with self.assertRaises(BenchmarkHistoryError):
            self.archive.history("unknown")
        with self.assertRaises(BenchmarkHistoryError):
            self.archive.history("nasdaq100", date(2026, 10, 30), date(2026, 10, 29))


if __name__ == "__main__":
    unittest.main()
