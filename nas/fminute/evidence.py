"""Versioned compact Research Evidence contract for DecisionContext consumers."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
import hashlib
import json
from typing import Mapping

from .archive import ArchiveError


EVIDENCE_SCHEMA_VERSION = 1
EVIDENCE_METHODOLOGY_VERSION = "minute-research-1"


@dataclass(frozen=True)
class ResearchEvidenceEnvelope:
    evidence_id: str
    security_code: str
    market: str
    start_date: date
    end_date: date
    as_of: datetime
    generated_at: datetime
    timezone_name: str | None
    session_coverage: Mapping[str, int]
    qualified_independent_days: int
    minimum_quality: int
    sources: tuple[str, ...]
    evidence: Mapping[str, object]
    limitations: tuple[str, ...]

    @classmethod
    def create(cls, payload: Mapping[str, object], *, generated_at: datetime) -> "ResearchEvidenceEnvelope":
        try:
            security = str(payload["securityCode"])
            market = str(payload["market"])
            interval = payload["range"]
            if not isinstance(interval, Mapping):
                raise TypeError("range")
            start = date.fromisoformat(str(interval["start"]))
            end = date.fromisoformat(str(interval["end"]))
            as_of = datetime.fromisoformat(str(payload["asOf"]).replace("Z", "+00:00"))
            coverage = payload["sessionCoverage"]
            evidence = payload["researchEvidence"]
            source_values = payload["sources"]
            if (not isinstance(source_values, (list, tuple)) or
                    any(not isinstance(item, str) or not item.strip() for item in source_values)):
                raise TypeError("sources")
            sources = tuple(sorted(set(source_values)))
            minimum_quality = int(payload["minimumQuality"])
            eligible_days = int(payload["qualifiedIndependentDays"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ArchiveError("research evidence payload is missing required contract fields") from exc
        if (not security.strip() or not market.strip() or end < start or as_of.tzinfo is None or
                as_of.utcoffset() is None or generated_at.tzinfo is None or generated_at.utcoffset() is None or
                generated_at < as_of or minimum_quality < 0 or minimum_quality > 100 or
                eligible_days < 0 or (eligible_days > 0 and not sources) or
                not isinstance(coverage, Mapping) or not isinstance(evidence, Mapping)):
            raise ArchiveError("research evidence payload violates schema v1 constraints")
        if payload.get("rawMinuteBarsIncluded") is not False or payload.get("tradePlan") is not None:
            raise ArchiveError("research evidence must exclude raw minute bars and executable plans")
        if set(evidence) - {"vwapBreak", "morningRecovery", "gridSpacingReplay", "dividendQuality"}:
            raise ArchiveError("research evidence contains an unsupported evidence type")
        if any(type(value) is not int or value < 0 for value in coverage.values()):
            raise ArchiveError("session coverage counts must be nonnegative integers")
        if any(not isinstance(source, str) or not source for source in sources):
            raise ArchiveError("research source identifiers must be nonempty strings")
        limitations = ("Historical observational evidence; not a forecast or trade instruction.",
                       "Only complete sessions meeting the configured quality and as-of gates are eligible.",
                       "Market calendar and provider coverage require deployment verification.")
        stable = {"schemaVersion": EVIDENCE_SCHEMA_VERSION,
                  "methodologyVersion": EVIDENCE_METHODOLOGY_VERSION,
                  "securityCode": security, "market": market,
                  "startDate": start.isoformat(), "endDate": end.isoformat(),
                  # Preserve the source contract timestamp exactly. The service emits
                  # canonical UTC; preserving it lets clients verify the same bytes.
                  "asOfEpochMillis": _epoch_millis(as_of),
                  "generatedAtEpochMillis": _epoch_millis(generated_at),
                  "timezone": str(payload["timezone"]) if payload.get("timezone") is not None else None,
                  "sessionCoverage": dict(coverage),
                  "qualifiedIndependentDays": eligible_days,
                  "minimumQuality": minimum_quality,
                  "sources": list(sources), "evidence": dict(evidence),
                  "limitations": list(limitations),
                  "rawMinuteBarsIncluded": False, "tradePlan": None}
        stable = _canonical_numbers(stable)
        evidence_id = hashlib.sha256(json.dumps(stable, sort_keys=True, separators=(",", ":"),
                                                ensure_ascii=False, allow_nan=False).encode()).hexdigest()
        return cls(evidence_id, security, market, start, end,
                   as_of.astimezone(timezone.utc), generated_at.astimezone(timezone.utc),
                   str(payload["timezone"]) if payload.get("timezone") is not None else None,
                   dict(coverage), eligible_days, minimum_quality, sources, dict(evidence),
                   limitations)

    def to_dict(self) -> dict:
        return {"schemaVersion": EVIDENCE_SCHEMA_VERSION,
                "methodologyVersion": EVIDENCE_METHODOLOGY_VERSION,
                "evidenceId": self.evidence_id,
                "securityCode": self.security_code, "market": self.market,
                "range": {"start": self.start_date.isoformat(), "end": self.end_date.isoformat()},
                "asOf": self.as_of.isoformat(), "generatedAt": self.generated_at.isoformat(),
                "timezone": self.timezone_name,
                "sessionCoverage": dict(self.session_coverage),
                "qualifiedIndependentDays": self.qualified_independent_days,
                "minimumQuality": self.minimum_quality, "sources": list(self.sources),
                "evidence": dict(self.evidence), "limitations": list(self.limitations),
                "rawMinuteBarsIncluded": False, "tradePlan": None}


def _canonical_numbers(value):
    """Normalize integral floats to JSON integers for Swift/Python digest parity."""
    if isinstance(value, bool) or value is None or isinstance(value, (str, int)):
        return value
    if isinstance(value, float):
        return int(value) if value.is_integer() else value
    if isinstance(value, Mapping):
        return {key: _canonical_numbers(child) for key, child in value.items()}
    if isinstance(value, (list, tuple)):
        return [_canonical_numbers(child) for child in value]
    return value


def _epoch_millis(value: datetime) -> int:
    return round(value.astimezone(timezone.utc).timestamp() * 1_000)
