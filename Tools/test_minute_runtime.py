import unittest
from datetime import date, datetime, timezone
from types import SimpleNamespace

from nas.fminute.runtime import select_realtime_rows_for_session, summarize_backfill_cycle
from nas.fminute.service import ServiceError


class BackfillCycleSummaryTests(unittest.TestCase):
    def test_failed_tasks_mark_worker_degraded_and_expose_reason(self):
        summary = summarize_backfill_cycle([{
            "securityCode": "159866",
            "tradingDate": "2026-10-08",
            "attempts": 1,
            "queueStatus": "queued",
            "report": {"result": "unavailable", "reason": "RemoteDisconnected"},
        }], queue_depth=840)

        self.assertEqual(summary["status"], "degraded")
        self.assertEqual(summary["processed"], 1)
        self.assertEqual(summary["completed"], 0)
        self.assertEqual(summary["requeued"], 1)
        self.assertEqual(summary["lastFailures"][0]["reason"], "RemoteDisconnected")

    def test_empty_batch_is_idle_and_successful_batch_is_ok(self):
        self.assertEqual(summarize_backfill_cycle([], 840)["status"], "idle")
        summary = summarize_backfill_cycle([{"queueStatus": "complete"}], 839)
        self.assertEqual(summary["status"], "ok")
        self.assertEqual(summary["completed"], 1)
        self.assertEqual(summary["requeued"], 0)


class RealtimeSessionFilterTests(unittest.TestCase):
    def test_filters_vendor_rows_outside_session_and_reports_them(self):
        day = date(2026, 10, 27)
        valid_stamp = datetime(2026, 10, 27, 5, 1, tzinfo=timezone.utc)
        out_of_session = datetime(2026, 10, 27, 5, 0, tzinfo=timezone.utc)
        session = SimpleNamespace(market="CN", trading_date=day,
                                  expected_timestamps=(valid_stamp,))
        valid = SimpleNamespace(security_code="159352", market="CN", trading_date=day,
                                timestamp=valid_stamp)
        extra = SimpleNamespace(security_code="159352", market="CN", trading_date=day,
                                timestamp=out_of_session)

        selected, filtered = select_realtime_rows_for_session([extra, valid], session, "159352")

        self.assertEqual(selected, (valid,))
        self.assertEqual(filtered, (out_of_session.isoformat(),))

    def test_rejects_provider_identity_mismatch_instead_of_filtering_it(self):
        day = date(2026, 10, 27)
        stamp = datetime(2026, 10, 27, 5, 1, tzinfo=timezone.utc)
        session = SimpleNamespace(market="CN", trading_date=day,
                                  expected_timestamps=(stamp,))
        wrong_code = SimpleNamespace(security_code="159941", market="CN", trading_date=day,
                                     timestamp=stamp)

        with self.assertRaisesRegex(ServiceError, "mismatched security"):
            select_realtime_rows_for_session([wrong_code], session, "159352")


if __name__ == "__main__":
    unittest.main()
