"""Source-traceable dividend research evidence; never emits a trade decision."""
from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import json
from math import isfinite
from statistics import median
from typing import Mapping, Sequence

from .archive import ArchiveError

DIVIDEND_FACTORS = (
    "currentYield", "consecutivePayments", "payoutRatio", "earningsQuality",
    "dividendTrend", "freeCashFlow", "indexDividendTraits", "valuation",
    "interestRateContext", "peerComparison",
)


def _timestamp(value: object) -> datetime:
    if not isinstance(value, str):
        raise ValueError("timestamp must be an ISO string")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("timestamp must include a timezone")
    return parsed.astimezone(timezone.utc)


def build_dividend_research_evidence(
        factors: Mapping[str, Mapping], *, as_of: datetime,
        historical_yields: Sequence[Mapping] = (),
        reference_yield_percent: float = 4.0,
        minimum_quality: int = 80) -> dict:
    """Normalize available evidence and calculate a descriptive historical rank.

    The 4% reference is context only. It never gates eligibility or produces a
    buy/hold/sell classification. Missing or late data are reported, not filled.
    """
    if (as_of.tzinfo is None or as_of.utcoffset() is None or
            type(minimum_quality) is not int or not 0 <= minimum_quality <= 100 or
            isinstance(reference_yield_percent, bool) or
            not isinstance(reference_yield_percent, (int, float)) or
            not isfinite(reference_yield_percent) or reference_yield_percent < 0):
        raise ArchiveError("invalid dividend research parameters")
    cutoff = as_of.astimezone(timezone.utc)
    normalized: dict[str, dict] = {}
    excluded: dict[str, str] = {}
    for name in DIVIDEND_FACTORS:
        row = factors.get(name)
        if row is None:
            excluded[name] = "not_provided"
            continue
        if not isinstance(row, Mapping):
            excluded[name] = "invalid_record"
            continue
        try:
            source = row["source"]
            observed_at = _timestamp(row["observedAt"])
            fetched_at = _timestamp(row["fetchedAt"])
            quality = row["quality"]
            value = row["value"]
            if (not isinstance(source, str) or not source.strip() or
                    type(quality) is not int or not 0 <= quality <= 100 or
                    quality < minimum_quality or observed_at > cutoff or fetched_at > cutoff or
                    observed_at > fetched_at or value is None):
                excluded[name] = "quality_or_as_of_gate"
                continue
            if isinstance(value, Decimal):
                if not value.is_finite():
                    excluded[name] = "non_finite_value"
                    continue
                value = str(value)
            if isinstance(value, float) and not isfinite(value):
                excluded[name] = "non_finite_value"
                continue
            json.dumps(value, allow_nan=False)
            if name == "currentYield" and (not _finite_numeric(value) or float(value) < 0):
                excluded[name] = "invalid_numeric_yield"
                continue
            unit = row.get("unit")
            normalized[name] = {
                "value": value, "unit": unit, "source": source.strip(),
                "observedAt": observed_at.isoformat(), "fetchedAt": fetched_at.isoformat(),
                "quality": quality,
            }
        except (KeyError, TypeError, ValueError, OverflowError):
            excluded[name] = "invalid_record"

    current = normalized.get("currentYield")
    history_rows: list[tuple[datetime, float, str, datetime, int]] = []
    for row in historical_yields:
        try:
            observed_at = _timestamp(row["observedAt"])
            fetched_at = _timestamp(row["fetchedAt"])
            source = row["source"]
            quality = row["quality"]
            value = float(row["value"])
            if (not isinstance(source, str) or not source.strip() or
                    type(quality) is not int or not 0 <= quality <= 100 or quality < minimum_quality or
                    observed_at > fetched_at or fetched_at > cutoff or observed_at > cutoff or
                    not isfinite(value) or value < 0):
                continue
            history_rows.append((observed_at, value, source.strip(), fetched_at, quality))
        except (KeyError, TypeError, ValueError, OverflowError):
            continue
    history_rows.sort(key=lambda item: item[0])
    # One observation time is one sample regardless of how many providers
    # reported it. Select the strongest eligible record deterministically so
    # provider/input ordering cannot change the percentile or source summary.
    deduplicated: dict[datetime, tuple[datetime, float, str, datetime, int]] = {}
    for item in history_rows:
        previous = deduplicated.get(item[0])
        if previous is None or (item[4], item[3], item[2], item[1]) > (
                previous[4], previous[3], previous[2], previous[1]):
            deduplicated[item[0]] = item
    history_values = [item[1] for item in deduplicated.values()]
    yield_history = {
        "eligibleObservations": len(history_values),
        "firstObservedAt": min(deduplicated).isoformat() if deduplicated else None,
        "lastObservedAt": max(deduplicated).isoformat() if deduplicated else None,
        "medianYieldPercent": median(history_values) if history_values else None,
        "currentYieldPercentile": (
            sum(value <= float(current["value"]) for value in history_values) / len(history_values)
            if current is not None and history_values and _finite_numeric(current["value"]) else None
        ),
        "sources": sorted({item[2] for item in deduplicated.values()}),
    }
    current_yield = float(current["value"]) if current and _finite_numeric(current["value"]) else None
    return {
        "researchType": "multifactor-dividend-evidence",
        "asOf": cutoff.isoformat(),
        "evidenceState": "evidence_available" if normalized else "insufficient_evidence",
        "referenceYieldPercent": float(reference_yield_percent),
        "referenceInterpretation": "descriptive_only_not_a_hard_gate",
        "currentYieldContext": (
            "at_or_above_reference" if current_yield is not None and current_yield >= reference_yield_percent
            else "below_reference" if current_yield is not None else "unavailable"
        ),
        "yieldHistory": yield_history,
        "factors": normalized,
        "excludedFactors": excluded,
        "factorCoverage": {"available": len(normalized), "expected": len(DIVIDEND_FACTORS)},
        "tradePlan": None,
    }


def _finite_numeric(value: object) -> bool:
    if isinstance(value, bool):
        return False
    try:
        return isfinite(float(value))
    except (TypeError, ValueError, OverflowError):
        return False
