import unittest

from nas.fminute.runtime import summarize_backfill_cycle


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


if __name__ == "__main__":
    unittest.main()
