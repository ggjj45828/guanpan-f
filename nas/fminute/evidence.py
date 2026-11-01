"""Versioned compact Research Evidence contract for DecisionContext consumers."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
import hashlib
import json
from typing import Mapping
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .archive import ArchiveError


EVIDENCE_SCHEMA_VERSION = 2
EVIDENCE_METHODOLOGY_VERSION = "minute-research-2"
TRUSTED_MINUTE_RESEARCH_SOURCES = frozenset({
    "Tencent Finance minute/query (public web endpoint)",
    "Eastmoney push2his 1-minute kline (public web endpoint)",
})
# No dividend factor provider is currently connected to the deployment. Do not
# promote arbitrary source labels to AI-usable research until one is verified.
TRUSTED_DIVIDEND_RESEARCH_SOURCES: frozenset[str] = frozenset()


def _valid_grid_spacing_selection(value: object) -> bool:
    if not isinstance(value, Mapping):
        return False
    spacings = value.get("spacings")
    if not isinstance(spacings, Mapping) or any(not isinstance(key, str) or
                                                not isinstance(row, Mapping)
                                                for key, row in spacings.items()):
        return False
    selected = value.get("selectedSpacing")
    reviewable = [key for key, row in spacings.items()
                  if row.get("evidenceState") == "available_for_review"]
    if selected is None:
        return not reviewable and all(row.get("selectedByTraining") is False and
                                      row.get("outOfSample") is None
                                      for row in spacings.values())
    if not isinstance(selected, str) or selected not in spacings or reviewable != [selected]:
        return False
    chosen = spacings[selected]
    if (chosen.get("selectedByTraining") is not True or
            chosen.get("headlinePopulation") != "out_of_sample" or
            not isinstance(chosen.get("outOfSample"), Mapping)):
        return False
    return all(key == selected or (
        row.get("evidenceState") != "available_for_review" and
        row.get("selectedByTraining") is False and row.get("outOfSample") is None)
        for key, row in spacings.items())


@dataclass(frozen=True)
class ResearchEvidenceEnvelope:
    evidence_id: str
    security_code: str
    market: str
    start_date: date
    end_date: date
    data_start_date: date | None
    data_end_date: date | None
    strategy_version: str | None
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
            security = payload["securityCode"]
            market = payload["market"]
            if not isinstance(security, str) or not isinstance(market, str):
                raise TypeError("securityCode/market")
            interval = payload["range"]
            if not isinstance(interval, Mapping):
                raise TypeError("range")
            start_value = interval["start"]
            end_value = interval["end"]
            if not isinstance(start_value, str) or not isinstance(end_value, str):
                raise TypeError("range dates")
            start = date.fromisoformat(start_value)
            end = date.fromisoformat(end_value)
            if start.isoformat() != start_value or end.isoformat() != end_value:
                raise ValueError("range dates")
            data_interval = payload.get("dataRange")
            if data_interval is None:
                data_start = data_end = None
            else:
                if not isinstance(data_interval, Mapping):
                    raise TypeError("dataRange")
                data_start = date.fromisoformat(str(data_interval["start"]))
                data_end = date.fromisoformat(str(data_interval["end"]))
                if (data_start.isoformat() != str(data_interval["start"]) or
                        data_end.isoformat() != str(data_interval["end"])):
                    raise ValueError("dataRange")
            strategy_version = payload.get("strategyVersion")
            if strategy_version is not None and (
                    not isinstance(strategy_version, str) or not strategy_version.strip()):
                raise ValueError("strategyVersion")
            as_of_value = payload["asOf"]
            if not isinstance(as_of_value, str):
                raise TypeError("asOf")
            as_of = datetime.fromisoformat(as_of_value.replace("Z", "+00:00"))
            coverage = payload["sessionCoverage"]
            evidence = payload["researchEvidence"]
            timezone_name = payload.get("timezone")
            if timezone_name is not None and not isinstance(timezone_name, str):
                raise TypeError("timezone")
            source_values = payload["sources"]
            if (not isinstance(source_values, (list, tuple)) or
                    any(not isinstance(item, str) or not item.strip() for item in source_values)):
                raise TypeError("sources")
            sources = tuple(sorted(set(source_values)))
            minimum_quality = payload["minimumQuality"]
            eligible_days = payload["qualifiedIndependentDays"]
            if type(minimum_quality) is not int or type(eligible_days) is not int:
                raise TypeError("minimumQuality/qualifiedIndependentDays")
        except (KeyError, TypeError, ValueError) as exc:
            raise ArchiveError("research evidence payload is missing required contract fields") from exc
        if timezone_name is not None:
            if not timezone_name.strip():
                raise ArchiveError("research evidence timezone must be nonblank")
            try:
                ZoneInfo(timezone_name)
            except (ZoneInfoNotFoundError, ValueError) as exc:
                raise ArchiveError("research evidence timezone must be a valid IANA zone") from exc
        if (not security.strip() or not market.strip() or end < start or as_of.tzinfo is None or
                not isinstance(generated_at, datetime) or generated_at.tzinfo is None or
                as_of.utcoffset() is None or generated_at.utcoffset() is None or
                generated_at < as_of or minimum_quality < 0 or minimum_quality > 100 or
                eligible_days < 0 or (eligible_days > 0 and not sources) or
                (eligible_days > 0 and timezone_name is None) or
                ((data_start is None) != (data_end is None)) or
                (eligible_days > 0 and data_start is None) or
                (data_start is not None and
                 (data_start < start or data_end < data_start or data_end > end)) or
                not isinstance(coverage, Mapping) or not isinstance(evidence, Mapping)):
            raise ArchiveError("research evidence payload violates schema v2 constraints")
        if payload.get("rawMinuteBarsIncluded") is not False or payload.get("tradePlan") is not None:
            raise ArchiveError("research evidence must exclude raw minute bars and executable plans")
        if set(evidence) - {"vwapBreak", "morningRecovery", "gridSpacingReplay", "dividendQuality"}:
            raise ArchiveError("research evidence contains an unsupported evidence type")
        if ("gridSpacingReplay" in evidence and
                not _valid_grid_spacing_selection(evidence["gridSpacingReplay"])):
            raise ArchiveError("grid spacing evidence must expose at most one training-selected holdout")
        if (any(not isinstance(key, str) or not key.strip() for key in coverage) or
                any(type(value) is not int or value < 0 for value in coverage.values())):
            raise ArchiveError("session coverage counts must be nonnegative integers")
        if eligible_days > 0 and eligible_days > coverage.get("complete", 0):
            raise ArchiveError("research evidence coverage contradicts eligible sample counts")
        if any(not isinstance(source, str) or not source for source in sources):
            raise ArchiveError("research source identifiers must be nonempty strings")
        if eligible_days > 0 and not set(sources).issubset(TRUSTED_MINUTE_RESEARCH_SOURCES):
            raise ArchiveError("qualified minute research contains an untrusted provider source")
        dividend = evidence.get("dividendQuality") if isinstance(evidence, Mapping) else None
        if isinstance(dividend, Mapping) and dividend.get("evidenceState") == "evidence_available":
            factors = dividend.get("factors")
            factor_rows = list(factors.values()) if isinstance(factors, Mapping) else []
            factor_sources = [factor.get("source") for factor in factor_rows
                              if isinstance(factor, Mapping)]
            if (not factor_sources or len(factor_sources) != len(factor_rows) or
                    any(not isinstance(source, str) or not source.strip()
                        for source in factor_sources) or
                    not set(factor_sources).issubset(TRUSTED_DIVIDEND_RESEARCH_SOURCES)):
                raise ArchiveError("dividend evidence contains an untrusted provider source")
        limitations = ("Historical observational evidence; not a forecast or trade instruction.",
                       "Only complete sessions meeting the configured quality and as-of gates are eligible.",
                       "Market calendar and provider coverage require deployment verification.")
        stable = {"schemaVersion": EVIDENCE_SCHEMA_VERSION,
                  "methodologyVersion": EVIDENCE_METHODOLOGY_VERSION,
                  "securityCode": security, "market": market,
                  "startDate": start.isoformat(), "endDate": end.isoformat(),
                  "dataRange": ({"start": data_start.isoformat(), "end": data_end.isoformat()}
                                if data_start is not None else None),
                  "strategyVersion": strategy_version,
                  # Preserve the source contract timestamp exactly. The service emits
                  # canonical UTC; preserving it lets clients verify the same bytes.
                  "asOfEpochMillis": _epoch_millis(as_of),
                  "generatedAtEpochMillis": _epoch_millis(generated_at),
                  "timezone": timezone_name,
                  "sessionCoverage": dict(coverage),
                  "qualifiedIndependentDays": eligible_days,
                  "minimumQuality": minimum_quality,
                  "sources": list(sources), "evidence": dict(evidence),
                  "limitations": list(limitations),
                  "rawMinuteBarsIncluded": False, "tradePlan": None}
        stable = _canonical_numbers(stable)
        evidence_id = hashlib.sha256(json.dumps(stable, sort_keys=True, separators=(",", ":"),
                                                ensure_ascii=False, allow_nan=False).encode()).hexdigest()
        return cls(evidence_id, security, market, start, end, data_start, data_end,
                   strategy_version,
                   as_of.astimezone(timezone.utc), generated_at.astimezone(timezone.utc),
                   timezone_name,
                   dict(coverage), eligible_days, minimum_quality, sources, dict(evidence),
                   limitations)

    def to_dict(self) -> dict:
        return {"schemaVersion": EVIDENCE_SCHEMA_VERSION,
                "methodologyVersion": EVIDENCE_METHODOLOGY_VERSION,
                "evidenceId": self.evidence_id,
                "securityCode": self.security_code, "market": self.market,
                "range": {"start": self.start_date.isoformat(), "end": self.end_date.isoformat()},
                "dataRange": ({"start": self.data_start_date.isoformat(),
                               "end": self.data_end_date.isoformat()}
                              if self.data_start_date is not None and self.data_end_date is not None else None),
                "strategyVersion": self.strategy_version,
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
    utc_value = value.astimezone(timezone.utc)
    epoch = datetime(1970, 1, 1, tzinfo=timezone.utc)
    delta = utc_value - epoch
    microseconds = ((delta.days * 86_400 + delta.seconds) * 1_000_000 + delta.microseconds)
    sign = -1 if microseconds < 0 else 1
    # Match Swift FloatingPoint.rounded()'s nearest, ties-away-from-zero rule
    # without passing through a binary float or Python's ties-to-even round().
    return sign * ((abs(microseconds) + 500) // 1_000)
