from datetime import date, datetime, timezone
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from nas.fminute.archive import MinuteArchive
from nas.fminute.calendar import Mainland2026Calendar
from nas.fminute.calendar_sync import (
    SSE_URL, SZSE_INDEX_URL, CalendarStore, OfficialCalendarSync,
)
from nas.fminute.providers import (
    EastmoneyMinuteHistoryProvider, TencentCurrentMinuteProvider,
)
from nas.fminute.runtime import _configured_securities, build_service, calendar_sync_due
from nas.fminute.service import MinuteArchiveService, ServiceError


class MinuteProviderTests(unittest.TestCase):
    def _calendar_pages(self, szse_text=None):
        holidays = (
            "元旦：1月1日（星期四）至1月3日（星期六）休市。",
            "春节：2月15日（星期日）至2月23日（星期一）休市。",
            "清明节：4月4日（星期六）至4月6日（星期一）休市。",
            "劳动节：5月1日（星期五）至5月5日（星期二）休市。",
            "端午节：6月19日（星期五）至6月21日（星期日）休市。",
            "中秋节：9月25日（星期五）至9月27日（星期日）休市。",
            "国庆节：10月1日（星期四）至10月7日（星期三）休市。",
            "另外：1月4日（星期日）、2月14日（星期六）、2月28日（星期六）为周末休市。",
        )
        sse = "<html><h1>年度休市安排</h1><p>2026年休市安排</p><p>" + "</p><p>".join(holidays) + "</p></html>"
        if szse_text is None:
            szse_text = "2026年部分节假日休市安排 " + " ".join(holidays)
        index = ('<html><a href="/disclosure/notice/general/t20251222_618087.html">'
                 '关于深圳证券交易所2026年部分节假日休市安排的通知</a></html>')
        pages = {SSE_URL: sse.encode(), SZSE_INDEX_URL: index.encode(),
                 "https://www.szse.cn/disclosure/notice/general/t20251222_618087.html":
                    ("<html><body>" + szse_text + "</body></html>").encode()}
        return pages

    def test_official_calendar_sync_requires_both_sources_and_publishes_atomic_version(self):
        with tempfile.TemporaryDirectory() as directory:
            pages = self._calendar_pages()
            store = CalendarStore(os.path.join(directory, "calendar.json"))
            sync = OfficialCalendarSync(store, fetch=lambda url: pages[url],
                                        clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc))
            result = sync.sync_year(2026)
            self.assertEqual(result["status"], "updated")
            payload = store.load()
            self.assertEqual(len(payload["years"]["2026"]["closedDates"]), 36)
            self.assertEqual({item["exchange"] for item in payload["years"]["2026"]["sources"]},
                             {"SSE", "SZSE"})
            calendar = Mainland2026Calendar(store.path)
            self.assertIn(2026, calendar.supported_years)
            self.assertEqual(calendar.sessions("CN", date(2026, 10, 1), date(2026, 10, 1)), ())

    def test_official_calendar_mismatch_keeps_previous_version_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            pages = self._calendar_pages()
            store = CalendarStore(os.path.join(directory, "calendar.json"))
            sync = OfficialCalendarSync(store, fetch=lambda url: pages[url],
                                        clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc))
            self.assertEqual(sync.sync_year(2026)["status"], "updated")
            before = store.path.read_bytes()
            pages = self._calendar_pages("2026年部分节假日休市安排 元旦：1月2日（星期五）休市。 "
                                         "春节：2月16日（星期一）至2月23日（星期一）休市。 "
                                         "清明节：4月4日（星期六）至4月6日（星期一）休市。 "
                                         "劳动节：5月1日（星期五）至5月5日（星期二）休市。 "
                                         "端午节：6月19日（星期五）至6月21日（星期日）休市。 "
                                         "中秋节：9月25日（星期五）至9月27日（星期日）休市。 "
                                         "国庆节：10月1日（星期四）至10月7日（星期三）休市。")
            result = sync.sync_year(2026)
            self.assertEqual(result["status"], "not_updated")
            self.assertEqual(store.path.read_bytes(), before)

    def test_unpublished_year_is_not_guessed_or_written(self):
        with tempfile.TemporaryDirectory() as directory:
            pages = self._calendar_pages()
            store = CalendarStore(os.path.join(directory, "calendar.json"))
            sync = OfficialCalendarSync(store, fetch=lambda url: pages[url],
                                        clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc))
            result = sync.sync_year(2027)
            self.assertEqual(result["status"], "not_updated")
            self.assertEqual(store.load()["years"], {})

    def test_calendar_store_corruption_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "calendar.json")
            store = CalendarStore(path)
            store.publish(2027, frozenset({date(2027, 1, 1), date(2027, 1, 2)}), [],
                          fetched_at="2026-12-01T00:00:00+00:00")
            with open(path, "rb") as stream:
                raw = bytearray(stream.read())
            raw[-2] = ord("x")
            with open(path, "wb") as stream:
                stream.write(raw)
            with self.assertRaises(ServiceError):
                Mainland2026Calendar(path).sessions("CN", date(2027, 1, 4), date(2027, 1, 4))

    def test_calendar_sync_schedule_runs_monthly_and_allows_late_year_retry(self):
        from zoneinfo import ZoneInfo
        local = ZoneInfo("Asia/Shanghai")
        self.assertTrue(calendar_sync_due(datetime(2026, 10, 26, 9, 0, tzinfo=local), None, None))
        self.assertTrue(calendar_sync_due(datetime(2026, 11, 1, 0, 10, tzinfo=local), None, None))
        self.assertFalse(calendar_sync_due(datetime(2026, 11, 2, 0, 10, tzinfo=local),
                                           (2026, 11), None))
        retry = datetime(2026, 12, 8, 0, 10, tzinfo=local)
        self.assertTrue(calendar_sync_due(retry, (2026, 12), retry))

    def test_szse_official_notice_link_cannot_redirect_fetcher_to_other_hosts(self):
        with tempfile.TemporaryDirectory() as directory:
            pages = self._calendar_pages()
            pages[SZSE_INDEX_URL] = (
                '<a href="https://attacker.invalid/calendar">'
                '2026年部分节假日休市安排</a>').encode("utf-8")
            calls = []

            def fetch(url):
                calls.append(url)
                if url not in pages:
                    raise AssertionError("untrusted URL must not be fetched")
                return pages[url]

            sync = OfficialCalendarSync(CalendarStore(os.path.join(directory, "calendar.json")),
                                        fetch=fetch,
                                        clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc))
            self.assertEqual(sync.sync_year(2026)["status"], "not_updated")
            self.assertNotIn("https://attacker.invalid/calendar", calls)

    def test_tencent_current_minute_parser_is_timestamped_and_does_not_guess_first_delta(self):
        day = date(2026, 10, 26)
        fetched = datetime(2026, 10, 26, 2, 0, tzinfo=timezone.utc)
        body = '{"data":{"sz159352":{"data":{"date":"20261026","data":[' \
               '"0930 1.199 900","0931 1.200 1000","0932 1.201 1120"]}}}}'
        bars = TencentCurrentMinuteProvider.parse(body, "159352", "CN", day, fetched_at=fetched)
        self.assertEqual(len(bars), 2)
        self.assertEqual(bars[0].source_timestamp, bars[0].timestamp)
        self.assertEqual(bars[0].timestamp.strftime("%H:%M"), "09:31")
        self.assertEqual(bars[0].minute_volume, 1000)
        self.assertEqual(bars[0].volume_method, "cumulative_delta")
        self.assertEqual(bars[1].minute_volume, 120)
        self.assertEqual(bars[1].volume_method, "cumulative_delta")

    def test_tencent_parser_rejects_wrong_date_and_future_rows(self):
        fetched = datetime(2026, 10, 26, 1, 31, tzinfo=timezone.utc)
        wrong = '{"data":{"sz159352":{"data":{"date":"20261023","data":["0931 1.2 5"]}}}}'
        with self.assertRaises(ValueError):
            TencentCurrentMinuteProvider.parse(wrong, "159352", "CN", date(2026, 10, 26), fetched_at=fetched)
        future = '{"data":{"sz159352":{"data":{"date":"20261026","data":["1000 1.2 5"]}}}}'
        with self.assertRaises(ValueError):
            TencentCurrentMinuteProvider.parse(future, "159352", "CN", date(2026, 10, 26), fetched_at=fetched)

    def test_tencent_provider_refuses_old_session_before_network(self):
        provider = TencentCurrentMinuteProvider(clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc),
                                                opener=lambda *args, **kwargs: self.fail("must not call network"))
        with self.assertRaisesRegex(ValueError, "current session"):
            provider.fetch("159352", "CN", date(2026, 10, 23))

    def test_real_adapter_rows_pass_through_calendar_and_archive_ingestion(self):
        day = date(2026, 10, 26)
        fetched = datetime(2026, 10, 26, 2, 0, tzinfo=timezone.utc)
        body = '{"data":{"sz159352":{"data":{"date":"20261026","data":[' \
               '"0930 1.199 900","0931 1.200 1000","0932 1.201 1120"]}}}}'
        bars = TencentCurrentMinuteProvider.parse(body, "159352", "CN", day, fetched_at=fetched)
        with tempfile.TemporaryDirectory() as directory:
            service = MinuteArchiveService(
                MinuteArchive(os.path.join(directory, "archive.sqlite3")),
                os.path.join(directory, "queue.sqlite3"),
                {"CN": Mainland2026Calendar()}, {"CN": ()}, clock=lambda: fetched)
            result = service.ingest_realtime(bars)
            self.assertEqual(result[0]["storedObservations"], 2)
            self.assertEqual(result[0]["coverage"]["status"], "partial")
            self.assertEqual(result[0]["coverage"]["observedCount"], 2)

    def test_eastmoney_parser_keeps_exact_date_and_source_volume(self):
        day = date(2026, 10, 23)
        fetched = datetime(2026, 10, 26, 2, tzinfo=timezone.utc)
        rows = [
            "2026-10-23 09:31,1.20,1.21,1.22,1.19,125,0,0,0,0,0",
            "2026-10-22 09:31,1.20,1.21,1.22,1.19,999,0,0,0,0,0",
        ]
        bars = EastmoneyMinuteHistoryProvider.parse(rows, "159352", "CN", day, fetched_at=fetched)
        self.assertEqual(len(bars), 1)
        self.assertEqual(bars[0].minute_volume, 125)
        self.assertEqual(bars[0].volume_method, "source_minute")
        self.assertEqual(bars[0].source_timestamp, bars[0].timestamp)

    def test_eastmoney_history_provider_uses_exact_date_request(self):
        from io import BytesIO
        from urllib.parse import urlparse, parse_qs

        class Response:
            status = 200
            def __enter__(self): return self
            def __exit__(self, *args): return False
            def read(self, _size):
                return b'{"data":{"klines":["2026-10-23 09:31,1.2,1.21,1.22,1.19,5"]}}'

        captured = {}
        def opener(request, timeout):
            captured["url"] = request.full_url
            captured["timeout"] = timeout
            return Response()

        provider = EastmoneyMinuteHistoryProvider(
            opener=opener, clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc))
        bars = provider.fetch("159352", "CN", date(2026, 10, 23))
        query = parse_qs(urlparse(captured["url"]).query)
        self.assertEqual(query["secid"], ["0.159352"])
        self.assertEqual(query["klt"], ["1"])
        self.assertEqual(query["beg"], ["20261023"])
        self.assertEqual(query["end"], ["20261023"])
        self.assertEqual(len(bars), 1)

    def test_eastmoney_refuses_current_day_to_prevent_partial_source_mixing(self):
        provider = EastmoneyMinuteHistoryProvider(
            clock=lambda: datetime(2026, 10, 26, 2, tzinfo=timezone.utc),
            opener=lambda *args, **kwargs: self.fail("must not call network"))
        with self.assertRaisesRegex(ValueError, "finalized historical"):
            provider.fetch("159352", "CN", date(2026, 10, 26))

    def test_calendar_uses_official_sessions_and_fails_closed_outside_2026(self):
        calendar = Mainland2026Calendar()
        open_days = calendar.sessions("CN", date(2026, 10, 8), date(2026, 10, 8))
        self.assertEqual(len(open_days), 1)
        self.assertEqual(len(open_days[0].expected_timestamps), 240)
        self.assertEqual(open_days[0].expected_timestamps[119].strftime("%H:%M"), "11:30")
        self.assertEqual(open_days[0].expected_timestamps[120].strftime("%H:%M"), "13:01")
        self.assertEqual(calendar.sessions("CN", date(2026, 10, 10), date(2026, 10, 10)), ())
        self.assertEqual(calendar.sessions("CN", date(2026, 10, 1), date(2026, 10, 1)), ())
        with self.assertRaises(ServiceError):
            calendar.sessions("CN", date(2027, 1, 1), date(2027, 1, 2))

    def test_default_runtime_is_wired_to_real_providers(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
            "F_MINUTE_SECURITIES": "159352,159941",
            "F_MINUTE_DATA_DIR": directory,
        }):
            service = build_service()
            self.assertIn("CN", service.calendars)
            names = [provider.name for provider in service.providers["CN"]]
            self.assertEqual(len(names), 2)
            self.assertIn("Eastmoney", names[0])
            self.assertIn("Tencent", names[1])
            self.assertEqual(service.runtime_worker.securities, ("159352", "159941"))
            self.assertIsNotNone(service.runtime_worker.calendar_sync)
            self.assertEqual(Path(service.runtime_worker.calendar_sync.store.path).resolve(),
                             (Path(directory) / "official-calendar-v1.json").resolve())
            self.assertTrue(os.path.exists(os.path.join(directory, "minute-archive.sqlite3")))

    def test_runtime_requires_explicit_security_universe(self):
        previous = os.environ.pop("F_MINUTE_SECURITIES", None)
        try:
            with self.assertRaisesRegex(RuntimeError, "F_MINUTE_SECURITIES"):
                _configured_securities()
        finally:
            if previous is not None:
                os.environ["F_MINUTE_SECURITIES"] = previous


if __name__ == "__main__":
    unittest.main()
