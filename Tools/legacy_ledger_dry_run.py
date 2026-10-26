#!/usr/bin/env python3
"""Read-only A/B NextBook to F opening-snapshot migration preview.

This tool never writes to the source or to the F ledger. It reads one legacy
JSON file and emits a JSON report to stdout. Any future commit path belongs in
FCore and must independently enforce confirmation, idempotency and rollback.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import uuid
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

SWIFT_REFERENCE_UNIX_SECONDS = Decimal("978307200")
MAX_INT64 = (1 << 63) - 1
CODE_PATTERN = re.compile(r"^[A-Za-z0-9.-]{2,16}$")


def reject_constant(value: str) -> None:
    raise ValueError(f"non-finite JSON number: {value}")


def parse_decimal(value: Any) -> Decimal | None:
    if isinstance(value, bool) or not isinstance(value, (int, Decimal)):
        return None
    try:
        result = Decimal(value)
    except (InvalidOperation, ValueError, TypeError):
        return None
    return result if result.is_finite() else None


def decimal_text(value: Decimal) -> str:
    return format(value, "f")


def parse_legacy_date(value: Any) -> datetime | None:
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    number = parse_decimal(value)
    if number is None:
        return None
    # Codable Date uses seconds since Apple's 2001 reference date in ordinary
    # JSONEncoder output. The source backups use that default; the fingerprint
    # helper is the known path that emits milliseconds since Unix epoch.
    if abs(number) >= Decimal("100000000000"):
        number /= Decimal(1000)
    else:
        number += SWIFT_REFERENCE_UNIX_SECONDS
    try:
        return datetime.fromtimestamp(float(number), tz=timezone.utc)
    except (OverflowError, OSError, ValueError):
        return None


def iso_date(value: datetime) -> str:
    return value.isoformat(timespec="microseconds").replace("+00:00", "Z")


def decode_json(raw: bytes) -> Any:
    return json.loads(raw.decode("utf-8-sig"), parse_float=Decimal,
                      parse_int=int, parse_constant=reject_constant)


def add_date_diagnostic(value: Any, label: str, warnings: list[str]) -> None:
    if value is None:
        return
    if parse_legacy_date(value) is None:
        warnings.append(f"{label}: date is present but not safely understood; raw source will be retained")


def summarize_events(book: dict[str, Any], warnings: list[str]) -> dict[str, int]:
    counts: dict[str, int] = {}
    fields = ("fills", "cashMovements", "incomeEvents", "dividendEvents", "history")
    for field in fields:
        value = book.get(field)
        if field not in book:
            warnings.append(f"{field}: absent (legacy decoder may default this to empty); no history is replayed")
            counts[field] = 0
            continue
        if value is None:
            warnings.append(f"{field}: explicitly null; no history is replayed")
            counts[field] = 0
            continue
        if not isinstance(value, list):
            warnings.append(f"{field}: malformed collection; raw source evidence is required")
            counts[field] = -1
            continue
        counts[field] = len(value)
        for index, item in enumerate(value):
            label = f"{field}[{index}]"
            if not isinstance(item, dict):
                warnings.append(f"{label}: malformed entry; raw source will be retained")
                continue
            date_fields = {
                "fills": ("date",), "cashMovements": ("date",),
                "incomeEvents": ("exDate", "payDate", "receivedAt"),
                "dividendEvents": ("date",), "history": ("date",),
            }[field]
            for date_field in date_fields:
                if date_field in item:
                    add_date_diagnostic(item[date_field], f"{label}.{date_field}", warnings)
            if field == "fills" and item.get("side") not in ("buy", "sell"):
                warnings.append(f"{label}.side: unrecognized; fill is not replayed into F")
    audit_events = book.get("__auditEvents", [])
    counts["auditEvents"] = len(audit_events) if isinstance(audit_events, list) else -1
    if "__auditEvents" not in book:
        warnings.append("auditEvents: absent; source was a bare NextBook or the wrapper omitted events")
    return counts


def make_report(source_kind: str, raw: bytes, captured_at: datetime) -> dict[str, Any]:
    source_hash = hashlib.sha256(raw).hexdigest()
    warnings: list[str] = []
    errors: list[str] = []
    parsed = None
    try:
        parsed = decode_json(raw)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
        errors.append(f"JSON decode failed: {error}")

    book: dict[str, Any] = {}
    if isinstance(parsed, dict):
        if "current" in parsed:
            current = parsed.get("current")
            if isinstance(current, dict):
                book = dict(current)
                events = parsed.get("events", [])
                book["__auditEvents"] = events
                if not isinstance(events, list):
                    warnings.append("wrapper.events: malformed; raw source will be retained")
            else:
                errors.append("wrapper.current is absent, null, or not an object")
        else:
            book = parsed
            warnings.append("source is a bare NextBook rather than a NextAuditedBook wrapper")
    elif parsed is not None:
        errors.append("top-level JSON value must be an object")

    if book:
        schema_version = book.get("schemaVersion")
        if isinstance(schema_version, bool) or not isinstance(schema_version, int):
            errors.append("schemaVersion is missing or is not an integer")
        elif schema_version != 1:
            errors.append(f"unsupported schemaVersion: {schema_version}")
        legacy_id = book.get("id")
        if not isinstance(legacy_id, str):
            warnings.append("account id is missing or malformed; target account ID will be deterministically derived from source bytes")
        else:
            try:
                uuid.UUID(legacy_id)
            except ValueError:
                warnings.append("account id is not a UUID; target account ID will be deterministically derived from source bytes")
        if "importedAt" in book:
            add_date_diagnostic(book["importedAt"], "importedAt", warnings)

        cash = parse_decimal(book.get("cash")) if "cash" in book else None
        if cash is None:
            errors.append("cash is missing, null, non-numeric, or non-finite")
        elif cash < 0:
            errors.append("cash is negative")

        raw_positions = book.get("positions")
        positions: list[dict[str, Any]] = []
        seen_codes: set[str] = set()
        zero_positions = 0
        if not isinstance(raw_positions, list):
            errors.append("positions is missing, null, or not an array")
        else:
            for index, position in enumerate(raw_positions):
                label = f"positions[{index}]"
                if not isinstance(position, dict):
                    errors.append(f"{label} is not an object")
                    continue
                code = position.get("code")
                name = position.get("name")
                units = position.get("units")
                cost = parse_decimal(position.get("bookCost")) if "bookCost" in position else None
                if not isinstance(code, str) or not CODE_PATTERN.fullmatch(code):
                    errors.append(f"{label}.code is invalid for F")
                    continue
                if code in seen_codes:
                    errors.append(f"duplicate position code: {code}")
                    continue
                seen_codes.add(code)
                if not isinstance(name, str) or not name.strip():
                    errors.append(f"{label}.name is missing or blank")
                    continue
                if isinstance(units, bool) or not isinstance(units, int) or units < 0 or units > MAX_INT64:
                    errors.append(f"{label}.units is invalid or outside Int64 range")
                    continue
                if cost is None or cost < 0:
                    errors.append(f"{label}.bookCost is invalid, negative, or non-finite")
                    continue
                acquired_at = position.get("acquiredAt")
                if acquired_at is not None:
                    parsed_acquired_at = parse_legacy_date(acquired_at)
                    if parsed_acquired_at is None:
                        errors.append(f"{label}.acquiredAt is present but invalid; candidate is blocked")
                        continue
                else:
                    parsed_acquired_at = None
                if units == 0:
                    zero_positions += 1
                    warnings.append(f"{label} has zero units; it will not become an active F position")
                    continue
                mapped_position = {"code": code, "name": name.strip(), "units": units,
                                   "bookCost": decimal_text(cost)}
                if parsed_acquired_at is not None:
                    mapped_position["acquiredAt"] = iso_date(parsed_acquired_at)
                positions.append(mapped_position)

        if zero_positions:
            warnings.append(f"zero-unit legacy positions excluded from active F snapshot: {zero_positions}")
        counts = summarize_events(book, warnings)
        replayable_history = sum(max(0, counts.get(field, 0)) for field in
                                 ("fills", "cashMovements", "incomeEvents", "dividendEvents", "history", "auditEvents"))
        if replayable_history:
            warnings.append("legacy fills, cash movements, income/dividends, asset history, and audit snapshots are counted but not translated into F ledger events; retain the exact source archive")
    else:
        counts = {name: 0 for name in ("fills", "cashMovements", "incomeEvents", "dividendEvents", "history", "auditEvents")}
        cash = None
        positions = []
        legacy_id = None

    source_identity = legacy_id if isinstance(legacy_id, str) else "missing-id"
    idempotency_key = hashlib.sha256(
        f"guanpan-f-migration-v1:{source_kind}:{source_identity}:{source_hash}".encode("utf-8")
    ).hexdigest()
    account_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"guanpan-f:{idempotency_key}"))
    if not errors and cash is not None:
        for position in positions:
            position["id"] = str(uuid.uuid5(uuid.UUID(account_id), position["code"]))
        candidate = {
            "accountID": account_id,
            "schemaVersion": 1,
            "currencyCode": "CNY",
            "openingSnapshot": {
                "capturedAt": iso_date(captured_at),
                "cashBalance": decimal_text(cash),
                "positions": positions,
            },
            "historicalReplay": "none; legacy events lack F sequence/confirmation/cost-basis evidence",
        }
    else:
        candidate = None

    warnings = list(dict.fromkeys(warnings))
    return {
        "reportFormat": "F-Legacy-Ledger-Dry-Run-v1",
        "mode": "read-only-dry-run",
        "source": {"kind": source_kind, "sha256": source_hash, "byteLength": len(raw),
                   "legacyAccountID": legacy_id if isinstance(legacy_id, str) else None},
        "idempotencyKey": idempotency_key,
        "status": "ready-for-review" if candidate is not None else "blocked",
        "candidateFOpeningSnapshot": candidate,
        "legacyRecordCounts": counts,
        "historicalEventsAppliedToF": 0,
        "warnings": warnings,
        "errors": errors,
        "writeOperations": 0,
        "realAccountModified": False,
        "requiredBeforeAnyImport": [
            "preserve and verify the exact source bytes",
            "show this report and require explicit user confirmation",
            "check expected current F account digest and reject a non-empty target",
            "persist the idempotency key with migration provenance atomically",
            "execute F migration tests for repeat import, rollback, and reconciliation",
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-kind", choices=("A", "B"), required=True)
    parser.add_argument("--input", required=True, type=Path, help="A/B real-ledger-v1.json or NextAuditedBook JSON")
    parser.add_argument("--captured-at", help="ISO-8601 UTC timestamp; omit to use current UTC time")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        raw = args.input.read_bytes()
    except OSError as error:
        print(json.dumps({"status": "blocked", "errors": [str(error)], "writeOperations": 0}, indent=2), file=sys.stdout)
        return 2
    if args.captured_at:
        parsed = parse_legacy_date(args.captured_at)
        if parsed is None:
            print(json.dumps({"status": "blocked", "errors": ["--captured-at is not valid ISO-8601"],
                              "writeOperations": 0, "realAccountModified": False}, indent=2), file=sys.stdout)
            return 2
        captured_at = parsed
    else:
        captured_at = datetime.now(timezone.utc)
    report = make_report(args.source_kind, raw, captured_at)
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if report["status"] == "ready-for-review" else 1


if __name__ == "__main__":
    raise SystemExit(main())
