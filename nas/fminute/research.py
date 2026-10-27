"""Compact, auditable historical minute evidence. This module never creates trade orders."""
from __future__ import annotations

from datetime import date, datetime, time, timezone
from decimal import Decimal, InvalidOperation
from math import ceil, isfinite
from statistics import median, mean
from typing import Mapping, Sequence
from zoneinfo import ZoneInfo

from .archive import ArchiveError


def _is_aware(value: datetime) -> bool:
    return value.tzinfo is not None and value.utcoffset() is not None


def _valid_quality_threshold(value: int) -> bool:
    return type(value) is int and 0 <= value <= 100


def _quality_gate(row: Mapping, minimum_quality: int) -> bool:
    """Prefer the archive's transparent session score; retain strict legacy gates."""
    score = row.get("research_quality")
    if score is None:
        return (type(row.get("data_quality")) is int and row["data_quality"] >= minimum_quality and
                type(row.get("source_trust")) is int and row["source_trust"] >= minimum_quality)
    return (type(score) in (int, float) and isfinite(score) and
            minimum_quality <= score <= 100)


def _walk_forward_summary(samples: Sequence[Mapping], *, value_key: str,
                          minimum_training_days: int, minimum_out_of_sample_days: int,
                          maximum_monthly_concentration: float) -> dict:
    """Chronological holdout and concentration gate, counting each date once."""
    by_day = {}
    duplicates = set()
    for sample in samples:
        day = sample.get("tradingDate")
        try:
            parsed = date.fromisoformat(str(day))
            if parsed.isoformat() != day:
                continue
        except ValueError:
            continue
        if day in by_day:
            duplicates.add(day)
        by_day[day] = sample
    if duplicates:
        return {"evidenceState": "duplicate_trading_dates", "duplicateDates": sorted(duplicates),
                "trainingDays": 0, "outOfSampleDays": 0, "maxMonthlySampleShare": None,
                "training": None, "outOfSample": None}
    ordered = [by_day[day] for day in sorted(by_day)]
    total = len(ordered)
    holdout_count = max(minimum_out_of_sample_days, ceil(total * 0.2)) if total else 0
    split = max(0, total - holdout_count)
    training, holdout = ordered[:split], ordered[split:]
    month_counts = {}
    for sample in ordered:
        month_counts[sample["tradingDate"][:7]] = month_counts.get(sample["tradingDate"][:7], 0) + 1
    concentration = max(month_counts.values(), default=0) / total if total else None

    def summarize(rows):
        values = [float(row[value_key]) for row in rows]
        if not values:
            return {"days": 0, "startDate": None, "endDate": None,
                    "median": None, "mean": None, "positiveRate": None}
        return {"days": len(values), "startDate": rows[0]["tradingDate"],
                "endDate": rows[-1]["tradingDate"], "median": median(values),
                "mean": mean(values), "positiveRate": sum(value > 0 for value in values) / len(values)}

    training_stats, holdout_stats = summarize(training), summarize(holdout)
    enough_training = len(training) >= minimum_training_days
    enough_holdout = len(holdout) >= minimum_out_of_sample_days
    diversified = concentration is not None and concentration <= maximum_monthly_concentration
    if not enough_training:
        state = "insufficient_independent_days"
    elif not enough_holdout:
        state = "insufficient_out_of_sample_days"
    elif not diversified:
        state = "insufficient_temporal_diversity"
    else:
        state = "available_for_review"
    return {"evidenceState": state, "independentDays": total,
            "minimumTrainingDays": minimum_training_days,
            "minimumOutOfSampleDays": minimum_out_of_sample_days,
            "trainingDays": len(training), "outOfSampleDays": len(holdout),
            "holdoutFraction": holdout_count / total if total else None,
            "splitPolicy": "chronological; latest max(minimum holdout, 20%) dates held out",
            "maxMonthlySampleShare": concentration,
            "maximumMonthlySampleShare": maximum_monthly_concentration,
            "training": training_stats, "outOfSample": holdout_stats}


def build_vwap_break_evidence(sessions: Sequence[Mapping], *, research_as_of: datetime,
                              horizons_minutes: Sequence[int] = (5, 15, 30, 60),
                              minimum_independent_days: int = 20,
                              minimum_out_of_sample_days: int = 5,
                              maximum_monthly_concentration: float = 0.5,
                              minimum_quality: int = 90) -> dict:
    """Summarize first intraday downward VWAP crosses per complete independent session.

    Per-signal VWAP uses only bars up to that signal. Later bars are used only as
    outcome labels and must still be at or before research_as_of. This is
    retrospective source-timestamp research, not a claim that a later backfill
    was available to the app at the historical time; strict replay uses the
    archive's fetched-at as-of query.
    """
    if not _is_aware(research_as_of):
        raise ArchiveError("research as-of must be timezone-aware")
    if (not horizons_minutes or any(type(value) is not int or value <= 0 for value in horizons_minutes) or
            minimum_independent_days < 1 or minimum_out_of_sample_days < 1 or
            not _valid_quality_threshold(minimum_quality) or
            not 0 < maximum_monthly_concentration <= 1):
        raise ArchiveError("horizons must be positive integer minutes")
    cutoff = research_as_of.astimezone(timezone.utc)
    output: dict[str, dict] = {}
    all_sources: set[str] = set()
    all_days: set[str] = set()
    for horizon in sorted(set(horizons_minutes)):
        samples = []
        for session in sessions:
            if session.get("complete") is not True:
                continue
            day = session.get("tradingDate")
            bars = session.get("bars")
            if not isinstance(day, str) or not isinstance(bars, Sequence) or isinstance(bars, (str, bytes)):
                continue
            try:
                if date.fromisoformat(day).isoformat() != day:
                    continue
            except ValueError:
                continue
            valid = []
            bad = False
            for row in bars:
                try:
                    stamp = datetime.fromisoformat(row["timestamp"].replace("Z", "+00:00"))
                    fetched = datetime.fromisoformat(row["fetched_at"].replace("Z", "+00:00"))
                    source_stamp = row.get("source_timestamp")
                    source_dt = datetime.fromisoformat(source_stamp.replace("Z", "+00:00")) if source_stamp else stamp
                    if not all(_is_aware(value) for value in (stamp, fetched, source_dt)):
                        raise ValueError("naive timestamp")
                    if (stamp.astimezone(timezone.utc) > cutoff or
                            fetched.astimezone(timezone.utc) > cutoff or
                            source_dt.astimezone(timezone.utc) > cutoff):
                        continue
                    price = Decimal(str(row["price"]))
                    volume = Decimal(str(row["minute_volume"]))
                    if (not price.is_finite() or price <= 0 or not volume.is_finite() or volume < 0 or
                            not _quality_gate(row, minimum_quality) or
                            row["volume_method"] not in {"source_minute", "cumulative_delta"} or
                            not isinstance(row["source"], str) or not row["source"].strip()):
                        bad = True
                        break
                    valid.append((stamp, price, volume, str(row["source"]), fetched))
                except (KeyError, TypeError, ValueError, InvalidOperation):
                    bad = True
                    break
            valid.sort(key=lambda item: item[0])
            if bad or len(valid) < horizon + 2 or len(valid) != len(bars):
                continue
            if len({point[0] for point in valid}) != len(valid):
                continue
            cumulative_value = Decimal(0)
            cumulative_volume = Decimal(0)
            first_cross = None
            previous_side = None
            for index, (_, price, volume, _, _) in enumerate(valid):
                cumulative_value += price * volume
                cumulative_volume += volume
                if cumulative_volume <= 0:
                    continue
                running_vwap = cumulative_value / cumulative_volume
                side = price >= running_vwap
                if previous_side is True and side is False:
                    first_cross = index
                    break
                previous_side = side
            if first_cross is None or first_cross + horizon >= len(valid):
                continue
            signal_price = valid[first_cross][1]
            outcome_price = valid[first_cross + horizon][1]
            change = (outcome_price / signal_price - Decimal(1)) * Decimal(100)
            samples.append({"tradingDate": day, "signalTimestamp": valid[first_cross][0].isoformat(),
                            "outcomeTimestamp": valid[first_cross + horizon][0].isoformat(),
                            "returnPercent": float(change)})
            all_days.add(day)
            all_sources.update(point[3] for point in valid)
        walk_forward = _walk_forward_summary(
            samples, value_key="returnPercent", minimum_training_days=minimum_independent_days,
            minimum_out_of_sample_days=minimum_out_of_sample_days,
            maximum_monthly_concentration=maximum_monthly_concentration)
        output[str(horizon)] = {
            "horizonMinutes": horizon,
            "independentDays": len(samples),
            "minimumIndependentDays": minimum_independent_days,
            "medianReturnPercent": (median(sample["returnPercent"] for sample in samples)
                                    if walk_forward["evidenceState"] == "available_for_review" else None),
            "meanReturnPercent": (mean(sample["returnPercent"] for sample in samples)
                                  if walk_forward["evidenceState"] == "available_for_review" else None),
            **walk_forward,
            "samples": samples,
        }
    return {"researchType": "first-downward-vwap-cross-outcomes",
            "asOf": cutoff.isoformat(), "sourceTimePolicy": "source timestamp <= event and research cutoff",
            "historicalAvailability": "retrospective; use fetched-at cutoff for strict point-in-time replay",
            "eligibleTradingDays": len(all_days), "sources": sorted(all_sources),
            "windows": output, "tradePlan": None}


def _eligible_session_bars(session: Mapping, cutoff: datetime, minimum_quality: int):
    """Validate real, point-in-time observations. Invalid sessions fail closed."""
    bars = session.get("bars")
    if session.get("complete") is not True or not isinstance(bars, Sequence) or isinstance(bars, (str, bytes)):
        return None
    valid = []
    for row in bars:
        try:
            stamp = datetime.fromisoformat(row["timestamp"].replace("Z", "+00:00"))
            fetched = datetime.fromisoformat(row["fetched_at"].replace("Z", "+00:00"))
            source_text = row.get("source_timestamp")
            source_stamp = datetime.fromisoformat(source_text.replace("Z", "+00:00")) if source_text else stamp
            if not all(_is_aware(value) for value in (stamp, fetched, source_stamp)):
                return None
            stamp = stamp.astimezone(timezone.utc)
            if stamp > cutoff or fetched.astimezone(timezone.utc) > cutoff or source_stamp.astimezone(timezone.utc) > cutoff:
                continue
            price = Decimal(str(row["price"]))
            volume = Decimal(str(row["minute_volume"]))
            if (not price.is_finite() or price <= 0 or not volume.is_finite() or volume < 0 or
                    not _quality_gate(row, minimum_quality) or
                    row["volume_method"] not in {"source_minute", "cumulative_delta"} or
                    not isinstance(row["source"], str) or not row["source"].strip()):
                return None
            valid.append({"timestamp": stamp, "price": price, "volume": volume,
                          "source": str(row["source"])})
        except (KeyError, TypeError, ValueError, InvalidOperation):
            return None
    valid.sort(key=lambda row: row["timestamp"])
    if len({row["timestamp"] for row in valid}) != len(valid):
        return None
    return valid


def build_morning_selloff_recovery_evidence(
        sessions: Sequence[Mapping], *, research_as_of: datetime,
        drop_threshold_percent: Decimal = Decimal("1.0"), minimum_independent_days: int = 20,
        minimum_out_of_sample_days: int = 5, maximum_monthly_concentration: float = 0.5,
        minimum_quality: int = 90) -> dict:
    """Estimate same-day recovery after a morning drawdown using only as-of rows.

    A qualifying session falls by the configured amount from its first morning
    bar to a low before 11:30 local time. The outcome is the last eligible quote
    at or before 14:30. It is historical evidence, never a candidate order.
    """
    if (not _is_aware(research_as_of) or not drop_threshold_percent.is_finite() or
            not _valid_quality_threshold(minimum_quality) or drop_threshold_percent <= 0 or minimum_independent_days < 1 or
            minimum_out_of_sample_days < 1 or not 0 < maximum_monthly_concentration <= 1):
        raise ArchiveError("invalid recovery research parameters")
    cutoff = research_as_of.astimezone(timezone.utc)
    samples, sources = [], set()
    for session in sessions:
        day, tz_name = session.get("tradingDate"), session.get("timezone")
        try:
            if not isinstance(day, str) or date.fromisoformat(day).isoformat() != day:
                continue
            zone = ZoneInfo(tz_name)
        except (ValueError, TypeError, KeyError):
            continue
        bars = _eligible_session_bars(session, cutoff, minimum_quality)
        if not bars:
            continue
        local = [(row["timestamp"].astimezone(zone), row) for row in bars]
        morning = [row for stamp, row in local if stamp.date().isoformat() == day and
                   time(9, 30) <= stamp.time() < time(11, 30)]
        outcomes = [row for stamp, row in local if stamp.date().isoformat() == day and
                    time(14, 25) <= stamp.time() <= time(14, 30)]
        if len(morning) < 2 or not outcomes:
            continue
        opening = morning[0]["price"]
        trough = min(morning, key=lambda row: row["price"])
        drop = (trough["price"] / opening - Decimal(1)) * Decimal(100)
        if drop > -drop_threshold_percent:
            continue
        outcome = outcomes[-1]
        recovery = (outcome["price"] / trough["price"] - Decimal(1)) * Decimal(100)
        samples.append({"tradingDate": day, "morningDropPercent": float(drop),
                        "recoveryFromMorningLowPercent": float(recovery),
                        "signalTimestamp": trough["timestamp"].isoformat(),
                        "outcomeTimestamp": outcome["timestamp"].isoformat()})
        sources.update(row["source"] for row in bars)
    count = len(samples)
    walk_forward = _walk_forward_summary(
        samples, value_key="recoveryFromMorningLowPercent", minimum_training_days=minimum_independent_days,
        minimum_out_of_sample_days=minimum_out_of_sample_days,
        maximum_monthly_concentration=maximum_monthly_concentration)
    return {"researchType": "morning-selloff-afternoon-recovery", "asOf": cutoff.isoformat(),
            "dropThresholdPercent": float(drop_threshold_percent), "independentDays": count,
            "minimumIndependentDays": minimum_independent_days,
            "recoveryRate": (sum(s["recoveryFromMorningLowPercent"] > 0 for s in samples) / count
                             if walk_forward["evidenceState"] == "available_for_review" else None),
            "medianRecoveryPercent": (median(s["recoveryFromMorningLowPercent"] for s in samples)
                                      if walk_forward["evidenceState"] == "available_for_review" else None),
            **walk_forward,
            "sources": sorted(sources), "samples": samples, "tradePlan": None}


def replay_grid_spacing_evidence(
        sessions: Sequence[Mapping], *, research_as_of: datetime,
        spacing_percentages: Sequence[Decimal], units: int = 1,
        fee_per_side: Decimal = Decimal("0.10"), minimum_independent_days: int = 20,
        minimum_out_of_sample_days: int = 5, maximum_monthly_concentration: float = 0.5,
        minimum_quality: int = 90) -> dict:
    """Replay simple one-lot grid spacing against observed minute highs/lows.

    The replay is explicitly retrospective and non-executable. A minute can
    fill only one side, avoiding an unsupported assumption about intraminute
    ordering. Incomplete/low-quality sessions are excluded.
    """
    if (not _is_aware(research_as_of) or type(units) is not int or units <= 0 or
            not fee_per_side.is_finite() or fee_per_side < 0 or
            not _valid_quality_threshold(minimum_quality) or
            minimum_independent_days < 1 or minimum_out_of_sample_days < 1 or
            not 0 < maximum_monthly_concentration <= 1 or not spacing_percentages):
        raise ArchiveError("invalid grid replay parameters")
    spacings = sorted(set(Decimal(str(value)) for value in spacing_percentages))
    if any(not value.is_finite() or value <= 0 or value >= 100 for value in spacings):
        raise ArchiveError("grid spacing must be between 0 and 100 percent")
    cutoff = research_as_of.astimezone(timezone.utc)
    trials = {str(value): [] for value in spacings}
    for session in sessions:
        day = session.get("tradingDate")
        try:
            if not isinstance(day, str) or date.fromisoformat(day).isoformat() != day:
                continue
        except ValueError:
            continue
        bars = _eligible_session_bars(session, cutoff, minimum_quality)
        if not bars:
            continue
        anchor = bars[0]["price"]
        for spacing in spacings:
            fraction = spacing / Decimal(100)
            buy_level = anchor * (Decimal(1) - fraction)
            sell_level = None
            completed = 0
            net = Decimal(0)
            for row in bars[1:]:
                # Minute bars contain close only in this archive contract. Do
                # not infer intraminute highs/lows or pretend a level filled.
                price = row["price"]
                if sell_level is None and price <= buy_level:
                    sell_level = buy_level * (Decimal(1) + fraction)
                elif sell_level is not None and price >= sell_level:
                    net += (sell_level - buy_level) * units - fee_per_side * 2
                    completed += 1
                    buy_level = sell_level / (Decimal(1) + fraction)
                    sell_level = None
            trials[str(spacing)].append({"tradingDate": day, "completedRoundTrips": completed,
                                         "netAfterFees": str(net), "openPositionAtCutoff": sell_level is not None,
                                         "lastObservedAt": bars[-1]["timestamp"].isoformat()})
    results = {}
    for spacing, days in trials.items():
        count = len(days)
        dated = [dict(row, netAfterFees=float(row["netAfterFees"])) for row in days]
        walk_forward = _walk_forward_summary(
            dated, value_key="netAfterFees", minimum_training_days=minimum_independent_days,
            minimum_out_of_sample_days=minimum_out_of_sample_days,
            maximum_monthly_concentration=maximum_monthly_concentration)
        results[spacing] = {"independentDays": count, "minimumIndependentDays": minimum_independent_days,
                            "completedRoundTrips": sum(row["completedRoundTrips"] for row in days),
                            "netAfterFees": str(sum((Decimal(row["netAfterFees"]) for row in days), Decimal(0)))
                            if walk_forward["evidenceState"] == "available_for_review" else None,
                            **walk_forward,
                            "sessions": days}
    return {"researchType": "historical-grid-spacing-replay", "asOf": cutoff.isoformat(),
            "unitsPerRoundTrip": units, "feePerSide": str(fee_per_side),
            "fillModel": "close-only; one side per minute; no intraminute high-low inference",
            "spacings": results, "tradePlan": None}
