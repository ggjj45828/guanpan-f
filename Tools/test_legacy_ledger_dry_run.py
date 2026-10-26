#!/usr/bin/env python3
"""Safety checks for the read-only A/B -> F ledger migration preview."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from Tools.legacy_ledger_dry_run import make_report

CAPTURED = datetime(2026, 10, 25, 7, 0, tzinfo=timezone.utc)
ACCOUNT_ID = "a7f4af98-13c8-4332-80b2-b986451697c1"


def legacy_book(**overrides: object) -> dict[str, object]:
    book: dict[str, object] = {
        "schemaVersion": 1,
        "id": ACCOUNT_ID,
        "cash": 125.50,
        "positions": [
            {"code": "159352", "name": "A500", "units": 100,
             "bookCost": 320.12, "acquiredAt": "2026-10-20T07:00:00Z"}
        ],
        "fills": [],
        "cashMovements": [],
        "incomeEvents": [],
        "dividendEvents": [],
        "history": [],
    }
    book.update(overrides)
    return book


class LegacyLedgerDryRunTests(unittest.TestCase):
    def test_repeated_dry_run_is_deterministic_and_never_writes(self) -> None:
        raw = json.dumps(legacy_book(), separators=(",", ":")).encode()
        original = bytes(raw)
        first = make_report("B", raw, CAPTURED)
        second = make_report("B", raw, CAPTURED)
        self.assertEqual(first, second)
        self.assertEqual(first["status"], "ready-for-review")
        self.assertEqual(first["writeOperations"], 0)
        self.assertFalse(first["realAccountModified"])
        self.assertEqual(first["historicalEventsAppliedToF"], 0)
        self.assertEqual(first["candidateFOpeningSnapshot"]["openingSnapshot"]["cashBalance"], "125.5")
        self.assertEqual(raw, original)

    def test_cli_reads_source_without_modifying_it(self) -> None:
        raw = json.dumps(legacy_book(), separators=(",", ":")).encode()
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "real-ledger-v1.json"
            source.write_bytes(raw)
            result = subprocess.run(
                [sys.executable, "Tools/legacy_ledger_dry_run.py", "--source-kind", "A",
                 "--input", str(source), "--captured-at", "2026-10-25T07:00:00Z"],
                check=False, capture_output=True, text=True,
            )
            report = json.loads(result.stdout)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(report["mode"], "read-only-dry-run")
            self.assertEqual(report["writeOperations"], 0)
            self.assertFalse(report["realAccountModified"])
            self.assertEqual(source.read_bytes(), raw)

    def test_wrapper_keeps_historical_events_as_evidence_only(self) -> None:
        wrapper = {"current": legacy_book(fills=[{"side": "buy", "date": "2026-10-21T02:00:00Z"}]),
                   "events": [{"action": "fill", "sequence": 1}]}
        raw = json.dumps(wrapper, separators=(",", ":")).encode()
        report = make_report("A", raw, CAPTURED)
        self.assertEqual(report["status"], "ready-for-review")
        self.assertEqual(report["legacyRecordCounts"]["fills"], 1)
        self.assertEqual(report["legacyRecordCounts"]["auditEvents"], 1)
        self.assertEqual(report["historicalEventsAppliedToF"], 0)
        self.assertIn("exact source archive", " ".join(report["warnings"]))

    def test_negative_cash_blocks_candidate(self) -> None:
        raw = json.dumps(legacy_book(cash=-1)).encode()
        report = make_report("A", raw, CAPTURED)
        self.assertEqual(report["status"], "blocked")
        self.assertIsNone(report["candidateFOpeningSnapshot"])
        self.assertTrue(any("cash is negative" in error for error in report["errors"]))

    def test_duplicate_instrument_blocks_candidate(self) -> None:
        duplicate = [
            {"code": "159352", "name": "A500", "units": 100, "bookCost": 300},
            {"code": "159352", "name": "A500 duplicate", "units": 100, "bookCost": 310},
        ]
        raw = json.dumps(legacy_book(positions=duplicate)).encode()
        report = make_report("B", raw, CAPTURED)
        self.assertEqual(report["status"], "blocked")
        self.assertIsNone(report["candidateFOpeningSnapshot"])
        self.assertIn("duplicate position code: 159352", report["errors"])

    def test_unsupported_schema_blocks_candidate(self) -> None:
        raw = json.dumps(legacy_book(schemaVersion=2)).encode()
        report = make_report("B", raw, CAPTURED)
        self.assertEqual(report["status"], "blocked")
        self.assertIsNone(report["candidateFOpeningSnapshot"])
        self.assertIn("unsupported schemaVersion: 2", report["errors"])


if __name__ == "__main__":
    unittest.main()
