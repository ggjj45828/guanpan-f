import json
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
from contextlib import closing
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from nas.fminute.index_history import (
    INDEX_TIMEZONES,
    IndexDailyBar,
    IndexDailyHistoryArchive,
    MultiMarketDailyProvider,
    NikkeiDailyCloseProvider,
    NaverKospiDailyProvider,
    NAVER_KOSPI_SOURCE,
    TencentIndexDailyProvider,
)


class FakeProvider:
    name = "fixture index provider"

    def __init__(self, bars, failure=None):
        self.bars = bars
        self.failure = failure
        self.calls = 0

    def fetch(self, index_code, *, fetched_at):
        self.calls += 1
        if self.failure:
            raise OSError(self.failure)
        return self.bars


class HTTPResponse:
    status = 200

    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, _limit):
        return self.body.encode()


class IndexDailyHistoryTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 26, 10, tzinfo=timezone(timedelta(hours=8)))
        day = date(2026, 10, 23)
        bars = []
        while len(bars) < 60:
            if day.weekday() < 5:
                bars.append(IndexDailyBar(day, "100", "101", "102", "99", "1000"))
            day -= timedelta(days=1)
        self.bars = tuple(reversed(bars))
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "index-daily.sqlite3"

    def tearDown(self):
        self.temp.cleanup()

    def test_provider_filters_current_session_and_preserves_daily_ohlcv(self):
        payload = {"data": {"usNDX": {"day": [
            ["2026-10-22", "100", "102", "104", "99", "1000"],
            ["2026-10-23", "102", "101", "103", "100", "1100"],
            ["2026-10-26", "101", "105", "106", "100", "500"],
        ]}}}
        fetched_at = datetime(2026, 10, 26, 10, tzinfo=timezone(timedelta(hours=-4)))

        result = TencentIndexDailyProvider.parse(json.dumps(payload), "usNDX", fetched_at=fetched_at)

        self.assertEqual([bar.trading_date for bar in result], [date(2026, 10, 22), date(2026, 10, 23)])
        self.assertEqual(result[-1], IndexDailyBar(date(2026, 10, 23), "102", "101", "103", "100", "1100"))

    def test_a500_daily_history_uses_tencent_symbol_and_shanghai_calendar(self):
        payload = {"data": {"sh000510": {"day": [
            ["2026-10-23", "4800", "4790", "4820", "4780", "100000"]
        ]}}}
        rows = TencentIndexDailyProvider.parse(json.dumps(payload), "sh000510", fetched_at=self.now)
        self.assertEqual(rows, (IndexDailyBar(date(2026, 10, 23), "4800", "4790", "4820", "4780", "100000"),))
        self.assertEqual(INDEX_TIMEZONES["sh000510"], "Asia/Shanghai")

    def test_provider_rejects_unsupported_index_and_invalid_ohlc(self):
        fetched_at = self.now
        with self.assertRaisesRegex(ValueError, "unsupported"):
            TencentIndexDailyProvider.parse("{}", "int_nikkei", fetched_at=fetched_at)
        payload = {"data": {"sh000001": {"day": [
            ["2026-10-23", "100", "101", "100", "99", "1000"]
        ]}}}
        with self.assertRaisesRegex(ValueError, "failed validation"):
            TencentIndexDailyProvider.parse(json.dumps(payload), "sh000001", fetched_at=fetched_at)

    def test_nikkei_parser_keeps_official_close_only_rows_without_inventing_ohlcv(self):
        # Thousands separators are valid only when quoted in CSV.
        body = """Date,Close
2026/10/22,"49,123.45"
2026/10/23,"49,234.56"
2026/10/26,"49,999.00"
2026/10/24,.
"""
        fetched_at = datetime(2026, 10, 26, 10, tzinfo=timezone(timedelta(hours=9)))

        bars = NikkeiDailyCloseProvider.parse(body, fetched_at=fetched_at)

        self.assertEqual([bar.trading_date for bar in bars], [date(2026, 10, 22), date(2026, 10, 23)])
        self.assertEqual(bars[0].close, "49123.45")
        self.assertIsNone(bars[0].open)
        self.assertIsNone(bars[0].high)
        self.assertIsNone(bars[0].low)
        self.assertIsNone(bars[0].volume)

    def test_nikkei_parser_rejects_malformed_close_for_a_completed_session(self):
        fetched_at = datetime(2026, 10, 26, 10, tzinfo=timezone(timedelta(hours=9)))
        for close in ("49,12.45", "NaN", "0"):
            with self.subTest(close=close), self.assertRaisesRegex(ValueError, "Nikkei CSV contains"):
                csv_close = f'"{close}"' if "," in close else close
                NikkeiDailyCloseProvider.parse(
                    f"Date,Close\n2026/10/22,{csv_close}\n", fetched_at=fetched_at)

    def test_nikkei_archive_preserves_official_source_and_nullable_ohlcv(self):
        bars = tuple(IndexDailyBar(date(2026, 10, day), None, str(49000 + day), None, None, None)
                     for day in range(20, 26) if date(2026, 10, day).weekday() < 5)
        provider = MultiMarketDailyProvider(
            FakeProvider(self.bars), FakeProvider(bars), FakeProvider(()))
        provider.nikkei.name = NikkeiDailyCloseProvider.name
        archive = IndexDailyHistoryArchive(self.path, provider, clock=lambda: self.now)
        result = archive.get_history("int_nikkei")

        self.assertEqual(result["source"], NikkeiDailyCloseProvider.name)
        self.assertTrue(all(bar["open"] is None and bar["volume"] is None for bar in result["bars"]))
        with closing(sqlite3.connect(self.path)) as db:
            columns = {row[1]: row for row in db.execute("PRAGMA table_info(index_daily_bar)")}
        self.assertEqual(columns["open"][3], 0)
        self.assertEqual(columns["volume"][3], 0)

    def test_nikkei_unavailable_response_does_not_claim_tencent_as_source(self):
        tencent = FakeProvider((), failure="unavailable")
        nikkei = FakeProvider((), failure="unavailable")
        nikkei.name = NikkeiDailyCloseProvider.name
        archive = IndexDailyHistoryArchive(self.path,
            MultiMarketDailyProvider(tencent, nikkei, FakeProvider(())), clock=lambda: self.now)

        result = archive.get_history("int_nikkei")

        self.assertEqual(result["status"], "unavailable")
        self.assertEqual(result["source"], NikkeiDailyCloseProvider.name)

    def test_provider_maps_security_code_and_excludes_current_day(self):
        payload = {"data": {"sz159352": {"day": [
            ["2026-10-22", "1.00", "1.02", "1.04", "0.99", "1000"],
            ["2026-10-26", "1.02", "1.05", "1.06", "1.00", "500"],
        ]}}}
        fetched_at = datetime(2026, 10, 26, 10, tzinfo=timezone(timedelta(hours=8)))

        bars = TencentIndexDailyProvider.parse(json.dumps(payload), "159352", fetched_at=fetched_at)

        self.assertEqual([bar.trading_date for bar in bars], [date(2026, 10, 22)])
        with self.assertRaisesRegex(ValueError, "unsupported"):
            TencentIndexDailyProvider.parse("{}", "459352", fetched_at=fetched_at)

    def test_provider_requests_exchange_prefixed_security_symbol(self):
        captured = []
        payload = json.dumps({"data": {"sz159352": {"day": [
            ["2026-10-22", "1.00", "1.02", "1.04", "0.99", "1000"]
        ]}}})

        def opener(request, timeout):
            captured.append((request.full_url, timeout))
            return HTTPResponse(payload)

        provider = TencentIndexDailyProvider(opener=opener)
        provider.fetch("159352", fetched_at=self.now)

        self.assertIn("param=sz159352%2Cday%2C%2C%2C300%2C", captured[0][0])

    def test_provider_rejects_duplicate_session_dates(self):
        payload = {"data": {"hkHSI": {"day": [
            ["2026-10-22", "100", "101", "102", "99", "1000"],
            ["2026-10-22", "101", "102", "103", "100", "1100"],
        ]}}}
        with self.assertRaisesRegex(ValueError, "duplicate"):
            TencentIndexDailyProvider.parse(json.dumps(payload), "hkHSI", fetched_at=self.now)

    def test_archive_persists_and_uses_fresh_cache_without_second_provider_call(self):
        provider = FakeProvider(self.bars)
        archive = IndexDailyHistoryArchive(self.path, provider, clock=lambda: self.now)
        first = archive.get_history("sh000001")
        second = archive.get_history("sh000001")

        self.assertEqual(first["status"], "available")
        self.assertEqual(first["sampleCount"], 60)
        self.assertEqual(second["bars"], first["bars"])
        self.assertEqual(provider.calls, 1)
        self.assertTrue(self.path.exists())
        self.assertEqual(archive.status()["indexes"]["sh000001"]["status"], "available")

        security = archive.get_security_history("159352")
        self.assertEqual(security["status"], "available")
        self.assertEqual(archive.security_status()["securities"]["159352"]["sampleCount"], 60)

    def test_fresh_fetch_time_cannot_make_old_daily_bars_available(self):
        old_bars = tuple(IndexDailyBar(
            bar.trading_date - timedelta(days=10), bar.open, bar.close,
            bar.high, bar.low, bar.volume) for bar in self.bars)
        archive = IndexDailyHistoryArchive(self.path, FakeProvider(old_bars), clock=lambda: self.now)

        index = archive.get_history("sh000001")
        security = archive.get_security_history("159352")

        self.assertEqual(index["status"], "stale")
        self.assertEqual(index["fetchedAt"], self.now.astimezone(timezone.utc).isoformat(timespec="seconds"))
        self.assertIn("5个自然日", index["unavailableReason"] or "")
        self.assertEqual(archive.status()["indexes"]["sh000001"]["status"], "stale")
        self.assertIn("5个自然日", archive.status()["indexes"]["sh000001"]["unavailableReason"])
        self.assertEqual(security["status"], "stale")
        self.assertEqual(archive.security_status()["securities"]["159352"]["status"], "stale")
        self.assertIn("5个自然日",
                      archive.security_status()["securities"]["159352"]["unavailableReason"])

    def test_last_completed_daily_bar_five_calendar_days_old_is_still_fresh(self):
        boundary_bars = tuple(IndexDailyBar(
            bar.trading_date - timedelta(days=2), bar.open, bar.close,
            bar.high, bar.low, bar.volume) for bar in self.bars)
        archive = IndexDailyHistoryArchive(self.path, FakeProvider(boundary_bars), clock=lambda: self.now)

        result = archive.get_history("hkHSI")

        self.assertEqual(result["status"], "available")
        self.assertIsNone(result["unavailableReason"])
        self.assertEqual(archive.status()["indexes"]["hkHSI"]["status"], "available")

    def test_successful_refresh_removes_obsolete_rows_inside_source_range(self):
        provider = FakeProvider(self.bars)
        archive = IndexDailyHistoryArchive(self.path, provider, clock=lambda: self.now)
        first = archive.get_history("usNDX")
        removed_date = self.bars[30].trading_date.isoformat()
        provider.bars = tuple(bar for bar in self.bars if bar.trading_date.isoformat() != removed_date)
        self.now += timedelta(minutes=16)

        refreshed = archive.get_history("usNDX")

        self.assertEqual(first["sampleCount"], 60)
        self.assertEqual(refreshed["sampleCount"], 59)
        self.assertNotIn(removed_date, {bar["tradingDate"] for bar in refreshed["bars"]})
        with closing(sqlite3.connect(self.path)) as db:
            remaining = db.execute(
                "SELECT COUNT(*) FROM index_daily_bar WHERE index_code=? AND trading_date=?",
                ("usNDX", removed_date)).fetchone()[0]
        self.assertEqual(remaining, 0)

    def test_readiness_status_uses_short_read_only_queries_not_full_history_reader(self):
        archive = IndexDailyHistoryArchive(self.path, FakeProvider(self.bars), clock=lambda: self.now)
        archive.get_history("sh000001")
        archive._read = lambda _code: (_ for _ in ()).throw(
            AssertionError("readiness must not load full OHLCV history"))
        original_connect = sqlite3.connect
        calls = []
        statements = []

        def recording_connect(*args, **kwargs):
            calls.append((args, kwargs))
            connection = original_connect(*args, **kwargs)
            connection.set_trace_callback(statements.append)
            return connection

        with patch("nas.fminute.index_history.sqlite3.connect", side_effect=recording_connect):
            status = archive.status()

        self.assertEqual(status["indexes"]["sh000001"]["status"], "available")
        self.assertEqual(status["indexes"]["sh000001"]["sampleCount"], 60)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][1]["timeout"], 1)
        self.assertTrue(calls[0][1]["uri"])
        self.assertIn("?mode=ro", calls[0][0][0])
        metadata_query = next(statement for statement in statements
                              if "FROM index_daily_meta" in statement)
        self.assertIn("WHERE index_code IN", metadata_query)

    def test_failed_refresh_returns_archived_history_as_stale_with_reason(self):
        good = IndexDailyHistoryArchive(self.path, FakeProvider(self.bars), clock=lambda: self.now)
        good.get_history("sz399001")
        later = self.now + timedelta(hours=2)
        failing = FakeProvider((), failure="upstream timeout")
        archive = IndexDailyHistoryArchive(self.path, failing, clock=lambda: later)

        result = archive.get_history("sz399001")

        self.assertEqual(result["status"], "stale")
        self.assertEqual(result["sampleCount"], 60)
        self.assertIn("upstream timeout", result["unavailableReason"])

    def test_future_archive_timestamp_is_not_treated_as_fresh(self):
        good = IndexDailyHistoryArchive(self.path, FakeProvider(self.bars), clock=lambda: self.now)
        good.get_history("sz399001")
        earlier = self.now - timedelta(hours=1)
        failing = FakeProvider((), failure="refresh failed")
        archive = IndexDailyHistoryArchive(self.path, failing, clock=lambda: earlier)

        result = archive.get_history("sz399001")

        self.assertEqual(result["status"], "stale")
        self.assertEqual(archive.status()["indexes"]["sz399001"]["status"], "stale")

    def test_missing_or_corrupt_fetch_metadata_never_makes_archived_rows_available(self):
        for metadata_value in (None, "", "not-an-iso-timestamp"):
            with self.subTest(metadata_value=metadata_value):
                good = IndexDailyHistoryArchive(self.path, FakeProvider(self.bars), clock=lambda: self.now)
                good.get_history("sh000001")
                with closing(sqlite3.connect(self.path)) as db:
                    if metadata_value is None:
                        db.execute("DELETE FROM index_daily_meta WHERE index_code=?", ("sh000001",))
                    else:
                        db.execute("UPDATE index_daily_meta SET last_fetched_at=? WHERE index_code=?",
                                   (metadata_value, "sh000001"))
                    db.commit()

                later = self.now + timedelta(hours=1)
                failing = IndexDailyHistoryArchive(
                    self.path, FakeProvider((), failure="upstream timeout"), clock=lambda: later)
                result = failing.get_history("sh000001")

                self.assertEqual(result["status"], "stale")
                self.assertIsNone(result["fetchedAt"])
                self.assertIn("upstream timeout", result["unavailableReason"])
                self.assertEqual(failing.status()["indexes"]["sh000001"]["status"], "stale")

    def test_unknown_market_code_is_rejected_and_catalog_is_explicit(self):
        provider = FakeProvider(self.bars)
        archive = IndexDailyHistoryArchive(self.path, provider, clock=lambda: self.now)
        with self.assertRaisesRegex(ValueError, "unsupported"):
            archive.get_history("not-an-index")
        self.assertEqual(set(INDEX_TIMEZONES),
                         {"sh000001", "sz399001", "sh000300", "sh000510", "sz399006", "usNDX", "hkHSI", "int_nikkei", "KOSPI"})
        self.assertEqual(provider.calls, 0)

    def test_naver_kospi_parser_accepts_documented_date_shapes_and_excludes_today(self):
        body = """[['날짜', '시가', '고가', '저가', '종가', '거래량'],
['2026.10.22', '2,480.00', '2,510.00', '2,470.00', '2,500.00', '100000'],
['20261023', '2500', '2530', '2490', '2520', '120000'],
['20261026', '2520', '2550', '2510', '2540', '130000']]"""
        bars = NaverKospiDailyProvider.parse(body, fetched_at=self.now)
        self.assertEqual([bar.trading_date for bar in bars], [date(2026, 10, 22), date(2026, 10, 23)])
        self.assertEqual(bars[0], IndexDailyBar(date(2026, 10, 22), "2480.00", "2500.00",
                                                "2510.00", "2470.00", "100000"))

    def test_naver_kospi_archive_uses_only_naver_route_and_reports_source(self):
        tencent = FakeProvider((), failure="must not use Tencent fallback")
        nikkei = FakeProvider((), failure="must not use Nikkei fallback")
        naver = FakeProvider(self.bars)
        naver.name = NAVER_KOSPI_SOURCE
        provider = MultiMarketDailyProvider(tencent, nikkei, naver)
        provider.naver.name = NAVER_KOSPI_SOURCE
        archive = IndexDailyHistoryArchive(self.path, provider, clock=lambda: self.now)

        result = archive.get_history("KOSPI")

        self.assertEqual(result["status"], "available")
        self.assertEqual(result["timezone"], "Asia/Seoul")
        self.assertEqual(result["source"], NAVER_KOSPI_SOURCE)
        self.assertEqual(result["sampleCount"], 60)
        self.assertEqual(naver.calls, 1)
        self.assertEqual(tencent.calls, 0)
        self.assertEqual(nikkei.calls, 0)

    def test_naver_kospi_parser_rejects_malformed_header_and_values(self):
        fetched_at = self.now
        malformed = [
            "[['wrong', '시가', '고가', '저가', '종가', '거래량'], ['20261023','1','2','1','2','10']]",
            "[['날짜', '시가', '고가', '저가', '종가', '거래량'], ['2026/10/23','1','2','1','2','10']]",
            "[['날짜', '시가', '고가', '저가', '종가', '거래량'], ['20261023','1','2','1','NaN','10']]",
        ]
        for body in malformed:
            with self.subTest(body=body), self.assertRaises(ValueError):
                NaverKospiDailyProvider.parse(body, fetched_at=fetched_at)

    def test_legacy_archive_migrates_required_ohlcv_columns_to_nullable(self):
        with closing(sqlite3.connect(self.path)) as db:
            db.executescript("""
                CREATE TABLE index_daily_bar (
                    index_code TEXT NOT NULL, trading_date TEXT NOT NULL,
                    open TEXT NOT NULL, close TEXT NOT NULL, high TEXT NOT NULL,
                    low TEXT NOT NULL, volume TEXT NOT NULL, source TEXT NOT NULL,
                    fetched_at TEXT NOT NULL, PRIMARY KEY(index_code,trading_date));
                CREATE INDEX idx_index_daily_date ON index_daily_bar(index_code,trading_date);
                CREATE TABLE index_daily_meta (
                    index_code TEXT PRIMARY KEY, last_fetched_at TEXT NOT NULL,last_error TEXT);
                INSERT INTO index_daily_bar VALUES
                    ('sh000001','2026-10-23','100','101','102','99','1000','legacy','2026-10-26T02:00:00+00:00');
            """)
        archive = IndexDailyHistoryArchive(self.path, FakeProvider(self.bars), clock=lambda: self.now)
        with closing(sqlite3.connect(self.path)) as db:
            columns = {row[1]: row for row in db.execute("PRAGMA table_info(index_daily_bar)")}
            row = db.execute("SELECT open,close,volume FROM index_daily_bar WHERE index_code='sh000001'").fetchone()
        self.assertEqual((columns["open"][3], columns["high"][3], columns["low"][3], columns["volume"][3]),
                         (0, 0, 0, 0))
        self.assertEqual(row, ("100", "101", "1000"))


if __name__ == "__main__":
    unittest.main()
