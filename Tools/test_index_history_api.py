import json
import tempfile
import unittest
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

from nas.fminute.http_api import make_handler
from nas.fminute.index_history import IndexDailyBar, IndexDailyHistoryArchive
from Tools.http_test_harness import dispatch_json


class Provider:
    name = "fixture index history"

    def __init__(self, bars):
        self.bars = bars

    def fetch(self, index_code, *, fetched_at):
        return self.bars


class IndexHistoryAPITests(unittest.TestCase):
    def test_endpoint_returns_archived_index_daily_history_and_rejects_unknown_code(self):
        with tempfile.TemporaryDirectory() as directory:
            now = datetime(2026, 10, 26, 2, tzinfo=timezone.utc)
            day = date(2026, 10, 23)
            bars = []
            while len(bars) < 60:
                if day.weekday() < 5:
                    bars.append(IndexDailyBar(day, "100", "101", "102", "99", "1000"))
                day -= timedelta(days=1)
            provider = Provider(tuple(reversed(bars)))
            archive = IndexDailyHistoryArchive(Path(directory) / "indexes.sqlite3", provider,
                                                clock=lambda: now)
            handler = make_handler(SimpleNamespace(index_daily_history=archive))

            status, payload = dispatch_json(
                handler, "/api/v1/index-daily-history?indexCode=usNDX")
            self.assertEqual(status, 200)
            self.assertEqual(payload["indexCode"], "usNDX")
            self.assertEqual(payload["status"], "available")
            self.assertEqual(payload["sampleCount"], 60)

            status, unsupported = dispatch_json(
                handler, "/api/v1/index-daily-history?indexCode=KOSPI")
            self.assertEqual(status, 200)
            self.assertEqual(unsupported["indexCode"], "KOSPI")
            self.assertEqual(unsupported["timezone"], "Asia/Seoul")
            self.assertEqual(unsupported["status"], "available")
            self.assertEqual(unsupported["source"], "fixture index history")
            self.assertEqual(unsupported["sampleCount"], 60)
            self.assertEqual(unsupported["timezone"], "Asia/Seoul")

            status, unknown = dispatch_json(
                handler, "/api/v1/index-daily-history?indexCode=not-an-index")
            self.assertEqual(status, 400)
            self.assertIn("error", unknown)

            status, security = dispatch_json(
                handler, "/api/v1/security-daily-history?securityCode=159352")
            self.assertEqual(status, 200)
            self.assertEqual(security["securityCode"], "159352")
            self.assertEqual(security["adjustment"], "不复权")
            self.assertEqual(security["sampleCount"], 60)

            status, invalid_security = dispatch_json(
                handler, "/api/v1/security-daily-history?securityCode=459352")
            self.assertEqual(status, 400)
            self.assertIn("error", invalid_security)

            status, duplicate_parameter = dispatch_json(
                handler, "/api/v1/index-daily-history?indexCode=usNDX&indexCode=hkHSI")
            self.assertEqual(status, 400)
            self.assertIn("error", duplicate_parameter)

            readiness_service = SimpleNamespace(
                archive=SimpleNamespace(integrity_check=lambda: "ok"),
                calendars={}, providers={}, index_daily_history=archive)
            status, readiness = dispatch_json(make_handler(readiness_service), "/readyz")
            self.assertEqual(status, 503)  # No market calendars are configured in this fixture.
            self.assertEqual(readiness["indexDailyHistory"]["indexes"]["int_nikkei"]["status"],
                             "not_collected")
            self.assertEqual(readiness["indexDailyHistory"]["indexes"]["KOSPI"]["status"],
                             "available")

    def test_nikkei_api_preserves_close_only_shape_and_timezone(self):
        with tempfile.TemporaryDirectory() as directory:
            now = datetime(2026, 10, 26, 2, tzinfo=timezone.utc)
            day = date(2026, 10, 23)
            bars = []
            while len(bars) < 60:
                if day.weekday() < 5:
                    bars.append(IndexDailyBar(day, None, "49234.56", None, None, None))
                day -= timedelta(days=1)
            archive = IndexDailyHistoryArchive(Path(directory) / "indexes.sqlite3",
                Provider(tuple(reversed(bars))), clock=lambda: now)
            handler = make_handler(SimpleNamespace(index_daily_history=archive))

            status, payload = dispatch_json(
                handler, "/api/v1/index-daily-history?indexCode=int_nikkei")

            self.assertEqual(status, 200)
            self.assertEqual(payload["timezone"], "Asia/Tokyo")
            self.assertEqual(payload["status"], "available")
            self.assertIsNone(payload["bars"][0]["open"])
            self.assertEqual(payload["bars"][0]["close"], "49234.56")
            self.assertIsNone(payload["bars"][0]["volume"])


if __name__ == "__main__":
    unittest.main()
