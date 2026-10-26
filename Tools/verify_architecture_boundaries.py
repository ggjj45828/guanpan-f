#!/usr/bin/env python3
"""Static checks for the F Swift package's ledger/advisor module boundary."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def main() -> int:
    package = (ROOT / "Package.swift").read_text(encoding="utf-8")
    expected = {
        "FAdvisor": ["FCore"],
        "FLedgerWrite": ["FCore"],
    }
    for target, dependencies in expected.items():
        match = re.search(
            rf'\.target\(name: "{target}", dependencies: \[([^]]*)\]\)', package
        )
        if not match:
            fail(f"missing explicit target declaration for {target}")
        actual = re.findall(r'"([A-Za-z0-9_]+)"', match.group(1))
        if actual != dependencies:
            fail(f"{target} dependency list is {actual}, expected {dependencies}")

    advisor_sources = sorted((ROOT / "Sources/FAdvisor").glob("*.swift"))
    write_sources = sorted((ROOT / "Sources/FLedgerWrite").glob("*.swift"))
    if not advisor_sources or not write_sources:
        fail("Advisor or LedgerWrite source target is empty")

    forbidden_advisor_tokens = (
        "import FLedgerWrite",
        "FAccountBook",
        "FAccountBookStore",
        "FConfirmedLedgerWriter",
        "applyingUserConfirmedFill",
        "applyingUserConfirmedCashMovement",
    )
    for source in advisor_sources:
        content = source.read_text(encoding="utf-8")
        content = re.sub(r"//[^\n]*", "", content)
        for token in forbidden_advisor_tokens:
            if token in content:
                fail(f"{source.relative_to(ROOT)} reaches LedgerWrite through {token}")

    store = (ROOT / "Sources/FLedgerWrite/LedgerPersistence.swift").read_text(encoding="utf-8")
    boundary = (ROOT / "Sources/FLedgerWrite/LedgerWriteBoundary.swift").read_text(encoding="utf-8")
    if re.search(r"public\s+func\s+save\s*\(", store):
        fail("raw account-book save is public outside the confirmation boundary")
    for method in ("importInitialLegacySnapshot", "restoreBackup", "restoreRecoveryCandidate"):
        if re.search(rf"public\s+func\s+{method}\s*\(", store):
            fail(f"raw {method} is public outside the confirmation boundary")
        if not re.search(rf"public\s+func\s+confirm\w*\([^{{]*", boundary):
            fail("public confirmation facade is missing")

    advisor_persistence = (ROOT / "Sources/FAdvisor/AdvisorPersistence.swift").read_text(encoding="utf-8")
    if "FAccountBookStore" in advisor_persistence or "FConfirmedLedgerWriter" in advisor_persistence:
        fail("advisor persistence references real ledger write capabilities")

    print("PASS: Advisor depends only on FCore; Ledger writes are in a separate target; raw persistence mutation is not public; advisor persistence has no ledger writer reference")
    return 0


if __name__ == "__main__":
    sys.exit(main())
