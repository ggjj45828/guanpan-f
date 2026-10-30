"""F minute archive core: real observations only, explicit sessions, fail-closed research."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Iterable, Iterator, Protocol, Sequence
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
import json
import math
import os
import shutil
import sqlite3
import tempfile
from contextlib import contextmanager

SCHEMA_VERSION = 1


class ArchiveError(ValueError):
    pass


class ProviderOutOfCoverage(ArchiveError):
    """A provider explicitly confirmed that the requested date is outside its range."""


def _valid_positive_decimal(value: object) -> bool:
    try:
        number = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        return False
    return number.is_finite() and number > 0


@dataclass(frozen=True)
class MinuteBar:
    security_code: str
    market: str
    trading_date: date
    timestamp: datetime
    price: str
    cumulative_volume: int | None
    minute_volume: int | None
    volume_method: str
    source: str
    fetched_at: datetime
    source_timestamp: datetime | None
    data_quality: int
    source_trust: int
    completeness: str
    schema_version: int = SCHEMA_VERSION

    def validate(self) -> None:
        if (not isinstance(self.security_code, str) or not self.security_code.strip() or
                not isinstance(self.market, str) or not self.market.strip() or
                not isinstance(self.source, str) or not self.source.strip()):
            raise ArchiveError("security, market, and source are required")
        timestamps = (self.timestamp, self.fetched_at) + (() if self.source_timestamp is None else (self.source_timestamp,))
        if any(value.tzinfo is None or value.utcoffset() is None for value in timestamps):
            raise ArchiveError("timestamps must be timezone-aware")
        if self.timestamp.date() != self.trading_date:
            raise ArchiveError("timestamp must be normalized to the market's trading-date timezone")
        if self.source_timestamp is not None and self.source_timestamp > self.fetched_at:
            raise ArchiveError("source timestamp cannot be later than local retrieval time")
        if not isinstance(self.price, str):
            raise ArchiveError("price must be stored as a decimal string")
        try:
            value = float(self.price)
        except (TypeError, ValueError) as exc:
            raise ArchiveError("invalid price") from exc
        if not math.isfinite(value) or value <= 0:
            raise ArchiveError("price must be finite and positive")
        if (type(self.data_quality) is not int or type(self.source_trust) is not int or
                not 0 <= self.data_quality <= 100 or not 0 <= self.source_trust <= 100):
            raise ArchiveError("quality and source trust must be in [0,100]")
        if self.volume_method not in {"source_minute", "cumulative_delta", "unknown"}:
            raise ArchiveError("unsupported volume method")
        if self.minute_volume is not None and (type(self.minute_volume) is not int or self.minute_volume < 0):
            raise ArchiveError("minute volume cannot be negative")
        if self.cumulative_volume is not None and (type(self.cumulative_volume) is not int or self.cumulative_volume < 0):
            raise ArchiveError("cumulative volume cannot be negative")
        if (self.volume_method == "cumulative_delta" and
                (self.minute_volume is None or self.cumulative_volume is None)):
            raise ArchiveError("cumulative delta must carry source cumulative and derived minute volume")
        if self.completeness not in {"complete", "partial", "unknown"}:
            raise ArchiveError("invalid completeness label")
        if type(self.schema_version) is not int or self.schema_version != SCHEMA_VERSION:
            raise ArchiveError("unsupported minute schema version")


@dataclass(frozen=True)
class MarketSession:
    market: str
    trading_date: date
    timezone_name: str
    expected_timestamps: tuple[datetime, ...]

    def __post_init__(self) -> None:
        if (not isinstance(self.market, str) or not self.market or self.market.strip() != self.market or
                type(self.trading_date) is not date or not isinstance(self.timezone_name, str) or
                not self.timezone_name.strip() or not isinstance(self.expected_timestamps, tuple)):
            raise ArchiveError("invalid market session identity, date, timezone, or schedule")
        if any(not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() is None
               for value in self.expected_timestamps):
            raise ArchiveError("session timestamps must be timezone-aware with a valid UTC offset")
        try:
            market_zone = ZoneInfo(self.timezone_name)
        except ZoneInfoNotFoundError as exc:
            raise ArchiveError("unknown market timezone") from exc
        if any(value.astimezone(market_zone).date() != self.trading_date for value in self.expected_timestamps):
            raise ArchiveError("session timestamps must use market-local trading-date semantics")
        if len(set(self.expected_timestamps)) != len(self.expected_timestamps):
            raise ArchiveError("duplicate expected session timestamp")


class MinuteProvider(Protocol):
    name: str
    def fetch(self, security_code: str, market: str, trading_date: date) -> Sequence[MinuteBar]: ...


class MinuteArchive:
    """SQLite archive shared by real-time ingestion and historical backfill."""

    def __init__(self, path: Path | str):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            existing_tables = {row[0] for row in db.execute(
                "SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
            existing_data_tables = existing_tables & {
                "minute_bar", "minute_observation", "session_coverage", "collection_log"}
            if "archive_meta" not in existing_tables:
                if existing_data_tables:
                    raise ArchiveError("existing archive has no schema metadata; migration is required")
            else:
                try:
                    existing_version = db.execute(
                        "SELECT value FROM archive_meta WHERE key='schema_version'").fetchone()
                except sqlite3.DatabaseError as exc:
                    raise ArchiveError("archive schema metadata is damaged") from exc
                if existing_version is None:
                    if existing_data_tables:
                        raise ArchiveError("existing archive has no schema version; migration is required")
                else:
                    self._validate_schema_version(existing_version[0])
            db.executescript("""
                PRAGMA journal_mode=WAL;
                PRAGMA synchronous=FULL;
                CREATE TABLE IF NOT EXISTS archive_meta (
                    key TEXT PRIMARY KEY, value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS minute_bar (
                    security_code TEXT NOT NULL, market TEXT NOT NULL, trading_date TEXT NOT NULL,
                    timestamp TEXT NOT NULL, price TEXT NOT NULL,
                    cumulative_volume INTEGER, minute_volume INTEGER, volume_method TEXT NOT NULL,
                    source TEXT NOT NULL, fetched_at TEXT NOT NULL, source_timestamp TEXT,
                    data_quality INTEGER NOT NULL, source_trust INTEGER NOT NULL,
                    completeness TEXT NOT NULL, schema_version INTEGER NOT NULL,
                    PRIMARY KEY(security_code, market, trading_date, timestamp)
                );
                CREATE INDEX IF NOT EXISTS idx_minute_day ON minute_bar(market, security_code, trading_date, timestamp);
                CREATE INDEX IF NOT EXISTS idx_minute_fetch ON minute_bar(fetched_at);
                CREATE TABLE IF NOT EXISTS minute_observation (
                    observation_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    security_code TEXT NOT NULL, market TEXT NOT NULL, trading_date TEXT NOT NULL,
                    timestamp TEXT NOT NULL, price TEXT NOT NULL,
                    cumulative_volume INTEGER, minute_volume INTEGER, volume_method TEXT NOT NULL,
                    source TEXT NOT NULL, fetched_at TEXT NOT NULL, source_timestamp TEXT,
                    data_quality INTEGER NOT NULL, source_trust INTEGER NOT NULL,
                    completeness TEXT NOT NULL, schema_version INTEGER NOT NULL,
                    UNIQUE(security_code, market, trading_date, timestamp, source, fetched_at)
                );
                CREATE INDEX IF NOT EXISTS idx_minute_observation_asof
                    ON minute_observation(security_code,market,trading_date,fetched_at,timestamp);
                CREATE TABLE IF NOT EXISTS session_coverage (
                    security_code TEXT NOT NULL, market TEXT NOT NULL, trading_date TEXT NOT NULL,
                    expected_count INTEGER NOT NULL, observed_count INTEGER NOT NULL,
                    missing_timestamps TEXT NOT NULL, status TEXT NOT NULL, evaluated_at TEXT NOT NULL,
                    source_summary TEXT NOT NULL, schema_version INTEGER NOT NULL,
                    PRIMARY KEY(security_code, market, trading_date)
                );
                CREATE TABLE IF NOT EXISTS collection_log (
                    security_code TEXT NOT NULL, market TEXT NOT NULL, mode TEXT NOT NULL,
                    source TEXT NOT NULL, fetched_at TEXT NOT NULL, result TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_collection_log_instrument_mode_fetched
                    ON collection_log(security_code,market,mode,fetched_at);
            """)
            row = db.execute("SELECT value FROM archive_meta WHERE key='schema_version'").fetchone()
            if row is None:
                db.execute("INSERT INTO archive_meta(key,value) VALUES('schema_version',?)", (str(SCHEMA_VERSION),))
            try:
                self._validate_database(db)
            except sqlite3.DatabaseError as exc:
                raise ArchiveError("archive startup validation failed") from exc

    @staticmethod
    def _validate_schema_version(raw_version: object) -> None:
        if not isinstance(raw_version, str) or not raw_version.isascii() or not raw_version.isdecimal():
            raise ArchiveError("archive schema version metadata is invalid")
        version = int(raw_version)
        if version > SCHEMA_VERSION:
            raise ArchiveError("archive schema is newer than this reader")
        if version < SCHEMA_VERSION or str(version) != raw_version:
            raise ArchiveError("archive migration required; refusing implicit downgrade")

    @staticmethod
    def _open_connection(path: Path) -> sqlite3.Connection:
        db = sqlite3.connect(path, timeout=30, isolation_level="IMMEDIATE")
        db.row_factory = sqlite3.Row
        return db

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        """Open a transaction-scoped connection and always release its file handle."""
        db = self._open_connection(self.path)
        try:
            with db:
                yield db
        finally:
            db.close()

    @staticmethod
    def _iso(value: datetime) -> str:
        # Retain subsecond retrieval/source times so an as-of cutoff cannot admit
        # a row fetched later in the same second.
        return value.astimezone(timezone.utc).isoformat(timespec="microseconds")

    def ingest(self, bars: Iterable[MinuteBar], *, mode: str) -> int:
        """Atomically insert observations; weaker/older rows cannot replace stronger rows."""
        if mode not in {"realtime", "backfill"}:
            raise ArchiveError("mode must be realtime or backfill")
        prepared = []
        for bar in bars:
            bar.validate()
            prepared.append((bar, (
                bar.data_quality, bar.source_trust, bar.completeness == "complete",
                self._iso(bar.fetched_at))))
        if not prepared:
            return 0
        changed = 0
        with self._connect() as db:
            db.execute("BEGIN IMMEDIATE")
            for bar, rank in prepared:
                key = (bar.security_code, bar.market, bar.trading_date.isoformat(), self._iso(bar.timestamp))
                values = (*key, bar.price, bar.cumulative_volume, bar.minute_volume, bar.volume_method,
                          bar.source, self._iso(bar.fetched_at), self._iso(bar.source_timestamp) if bar.source_timestamp else None,
                          bar.data_quality, bar.source_trust, bar.completeness, bar.schema_version)
                previous = db.execute("""SELECT security_code,market,trading_date,timestamp,price,
                    cumulative_volume,minute_volume,volume_method,source,fetched_at,source_timestamp,
                    data_quality,source_trust,completeness,schema_version
                    FROM minute_observation WHERE security_code=? AND market=? AND trading_date=?
                    AND timestamp=? AND source=? AND fetched_at=?""",
                    (*key, bar.source, self._iso(bar.fetched_at))).fetchone()
                if previous is not None and tuple(previous) != tuple(values):
                    raise ArchiveError("conflicting observation reused the same source and fetched timestamp")
                old = db.execute("SELECT * FROM minute_bar WHERE security_code=? AND market=? AND trading_date=? AND timestamp=?", key).fetchone()
                if old:
                    if (old["source"] == bar.source and old["fetched_at"] == self._iso(bar.fetched_at) and
                            tuple(old) != tuple(values)):
                        raise ArchiveError("conflicting observation reused the same source and fetched timestamp")
                    old_rank = (old["data_quality"], old["source_trust"],
                                old["completeness"] == "complete", old["fetched_at"])
                    # A candidate may replace the current projection only when it
                    # is no worse on every quality axis. Lexicographic ranking can
                    # let a high numeric score hide weaker trust/completeness.
                    if (rank[0] < old_rank[0] or rank[1] < old_rank[1] or
                            rank[2] < old_rank[2] or
                            (rank[:3] == old_rank[:3] and rank[3] <= old_rank[3])):
                        continue
                inserted_observation = db.execute("INSERT OR IGNORE INTO minute_observation (security_code,market,trading_date,timestamp,price,cumulative_volume,minute_volume,volume_method,source,fetched_at,source_timestamp,data_quality,source_trust,completeness,schema_version) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", values).rowcount
                if not inserted_observation and previous is None:
                    raise ArchiveError("minute observation could not be stored")
                db.execute("""INSERT OR REPLACE INTO minute_bar VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", values)
                changed += 1
                db.execute("INSERT INTO collection_log VALUES(?,?,?,?,?,?)", (
                    bar.security_code, bar.market, mode, bar.source, self._iso(bar.fetched_at), "stored"))
        return changed

    def evaluate_session(self, security_code: str, session: MarketSession, *, evaluated_at: datetime,
                         minimum_quality: int = 80, maximum_gap_minutes: int = 5,
                         available_as_of: datetime | None = None) -> dict:
        if evaluated_at.tzinfo is None or evaluated_at.utcoffset() is None:
            raise ArchiveError("evaluation timestamp must be timezone-aware")
        if available_as_of is not None and (available_as_of.tzinfo is None or available_as_of.utcoffset() is None):
            raise ArchiveError("availability cutoff must be timezone-aware")
        if type(minimum_quality) is not int or not 0 <= minimum_quality <= 100 or type(maximum_gap_minutes) is not int or maximum_gap_minutes < 0:
            raise ArchiveError("invalid session quality or maximum-gap threshold")
        expected = tuple(sorted(session.expected_timestamps))
        expected_set = {self._iso(ts) for ts in expected}
        if not expected_set:
            return {"securityCode": security_code, "market": session.market,
                    "tradingDate": session.trading_date.isoformat(), "expectedCount": 0,
                    "observedCount": 0, "missingTimestamps": [], "status": "not-a-session",
                    "qualityPassed": False, "completenessPassed": False, "volumePassed": False,
                    "longGap": False, "futureFetchedAt": False, "futureDataTimestamp": False,
                    "unexpectedTimestampCount": 0, "sources": [],
                    "firstAvailableDate": None, "lastAvailableDate": None}
        rows = self.query_day(security_code, session.market, session.trading_date,
                              available_as_of=available_as_of)
        observed = {row["timestamp"]: row for row in rows if row["timestamp"] in expected_set}
        unexpected_count = sum(row["timestamp"] not in expected_set for row in rows)
        with self._connect() as db:
            missing = sorted(expected_set - set(observed))
            completeness_ok = bool(observed) and all(row["completeness"] == "complete" for row in observed.values())
            volume_ok = bool(observed) and all(row["minute_volume"] is not None and row["volume_method"] != "unknown" for row in observed.values())
            ordered_rows = [observed[key] for key in sorted(observed)]
            cumulative_values = [row["cumulative_volume"] for row in ordered_rows]
            has_cumulative = any(value is not None for value in cumulative_values)
            if has_cumulative and any(value is None for value in cumulative_values):
                volume_ok = False
            if has_cumulative:
                volume_ok = volume_ok and all(
                    right >= left for left, right in zip(cumulative_values, cumulative_values[1:]))
                for index, row in enumerate(ordered_rows):
                    if row["volume_method"] != "cumulative_delta":
                        continue
                    if index == 0:
                        volume_ok = volume_ok and row["cumulative_volume"] == row["minute_volume"]
                    else:
                        prior = ordered_rows[index - 1]["cumulative_volume"]
                        volume_ok = volume_ok and prior is not None and (
                            row["cumulative_volume"] - prior == row["minute_volume"])
            future_fetched = available_as_of is None and any(
                datetime.fromisoformat(row["fetched_at"]) > evaluated_at for row in observed.values())
            future_data_timestamp = available_as_of is None and any(
                datetime.fromisoformat(row["timestamp"]) > evaluated_at or
                (row["source_timestamp"] is not None and
                 datetime.fromisoformat(row["source_timestamp"]) > evaluated_at)
                for row in observed.values())
            expected_positions = {stamp: index for index, stamp in enumerate(sorted(expected_set))}
            observed_positions = sorted(expected_positions[stamp] for stamp in observed)
            observed_timestamps = [datetime.fromisoformat(stamp) for stamp in sorted(observed)]
            long_gap = any((right_index - left_index > 1 and
                            (right_time - left_time).total_seconds() / 60 > maximum_gap_minutes)
                           for left_index, right_index, left_time, right_time in
                           zip(observed_positions, observed_positions[1:], observed_timestamps, observed_timestamps[1:]))
            count_complete = len(observed) == len(expected_set) and bool(expected_set)
            source_names = sorted({row["source"] for row in observed.values()})
            source_trust_score = (sum(row["source_trust"] for row in observed.values()) / len(observed)
                                  if observed else 0.0)
            coverage_score = 100 * len(observed) / len(expected_set)
            timestamp_validity = 0.0 if future_fetched or future_data_timestamp or unexpected_count else 100.0
            session_completeness = 100.0 if count_complete and completeness_ok and not long_gap else coverage_score
            missing_bar_score = coverage_score
            prices_valid = all(_valid_positive_decimal(row["price"]) for row in observed.values())
            cross_verified_timestamps = 0
            if observed:
                cutoff = self._iso(available_as_of) if available_as_of is not None else None
                cross_sql = ("SELECT COUNT(*) FROM (SELECT timestamp FROM minute_observation "
                             "WHERE security_code=? AND market=? AND trading_date=?")
                cross_params: list[object] = [security_code, session.market, session.trading_date.isoformat()]
                if cutoff is not None:
                    cross_sql += " AND fetched_at<=? AND timestamp<=? AND (source_timestamp IS NULL OR source_timestamp<=?)"
                    cross_params.extend((cutoff, cutoff, cutoff))
                cross_sql += " GROUP BY timestamp HAVING COUNT(DISTINCT source)>=2)"
                cross_verified_timestamps = int(db.execute(cross_sql, cross_params).fetchone()[0])
            cross_source_score = (100.0 if cross_verified_timestamps >= len(observed) * 0.8 else
                                  (65.0 if cross_verified_timestamps else 35.0))
            latest_fetch = max((datetime.fromisoformat(row["fetched_at"]) for row in observed.values()),
                               default=None)
            fetch_age_days = (max(0.0, (evaluated_at - latest_fetch).total_seconds() / 86400)
                              if latest_fetch else None)
            freshness_score = (max(0.0, 100.0 - fetch_age_days * 4) if fetch_age_days is not None else 0.0)
            volume_score = 100.0 if volume_ok else (50.0 if any(row["minute_volume"] is not None for row in observed.values()) else 0.0)
            factors = {
                "sourceTrust": round(source_trust_score, 2),
                "coverage": round(coverage_score, 2),
                "timestampValidity": round(timestamp_validity, 2),
                "sessionCompleteness": round(session_completeness, 2),
                "missingBars": round(missing_bar_score, 2),
                "priceValidity": 100.0 if prices_valid else 0.0,
                "volumeContinuity": round(volume_score, 2),
                "crossSourceVerification": round(cross_source_score, 2),
                "freshness": round(freshness_score, 2),
            }
            weights = {"sourceTrust": .20, "coverage": .18, "timestampValidity": .12,
                       "sessionCompleteness": .15, "missingBars": .12, "priceValidity": .08,
                       "volumeContinuity": .05, "crossSourceVerification": .05, "freshness": .05}
            quality_score = round(sum(factors[key] * weight for key, weight in weights.items()), 2)
            confidence_score = round(quality_score * (1.0 if cross_verified_timestamps else .78), 2)
            quality_ok = bool(observed) and prices_valid and quality_score >= minimum_quality
            status = "complete" if count_complete and quality_ok and completeness_ok and volume_ok and not future_fetched and not future_data_timestamp and not long_gap and unexpected_count == 0 else ("partial" if observed else "missing")
            report = {"securityCode": security_code, "market": session.market, "tradingDate": session.trading_date.isoformat(),
                      "expectedCount": len(expected_set), "observedCount": len(observed), "missingTimestamps": missing,
                      "status": status, "qualityPassed": quality_ok, "volumePassed": volume_ok,
                      "completenessPassed": completeness_ok,
                      "longGap": long_gap, "unexpectedTimestampCount": unexpected_count,
                      "futureFetchedAt": future_fetched, "futureDataTimestamp": future_data_timestamp,
                      "sources": source_names,
                      "qualityScore": quality_score,
                      "confidenceScore": confidence_score,
                      "qualityFactors": factors,
                      "crossVerifiedTimestamps": cross_verified_timestamps,
                      "fetchAgeDays": round(fetch_age_days, 3) if fetch_age_days is not None else None,
                      "firstAvailableDate": session.trading_date.isoformat() if observed else None,
                      "lastAvailableDate": session.trading_date.isoformat() if observed else None}
            # Point-in-time replay must not replace the current diagnostic projection.
            if available_as_of is None:
                db.execute("INSERT OR REPLACE INTO session_coverage VALUES (?,?,?,?,?,?,?,?,?,?)", (
                    security_code, session.market, session.trading_date.isoformat(), len(expected_set), len(observed),
                    json.dumps(missing), status, self._iso(evaluated_at), json.dumps(source_names), SCHEMA_VERSION))
            return report

    def query_day(self, security_code: str, market: str, trading_date: date, *,
                  available_as_of: datetime | None = None) -> list[dict]:
        clauses = ["security_code=?", "market=?", "trading_date=?"]
        params: list[object] = [security_code, market, trading_date.isoformat()]
        if available_as_of is not None:
            if available_as_of.tzinfo is None or available_as_of.utcoffset() is None:
                raise ArchiveError("as-of timestamp must be timezone-aware")
            cutoff = self._iso(available_as_of)
            clauses.extend(["timestamp<=?", "fetched_at<=?", "(source_timestamp IS NULL OR source_timestamp<=?)"])
            params.extend([cutoff, cutoff, cutoff])
        with self._connect() as db:
            if available_as_of is None:
                rows = db.execute("SELECT * FROM minute_bar WHERE " + " AND ".join(clauses) + " ORDER BY timestamp", params).fetchall()
                return [dict(row) for row in rows]
            observations = db.execute("SELECT * FROM minute_observation WHERE security_code=? AND market=? AND trading_date=? AND timestamp<=? AND fetched_at<=? AND (source_timestamp IS NULL OR source_timestamp<=?) ORDER BY timestamp, (completeness='complete') DESC, source_trust DESC, data_quality DESC, fetched_at DESC", params).fetchall()
            best = {}
            for row in observations:
                best.setdefault(row["timestamp"], dict(row))
            return [best[key] for key in sorted(best)]

    def research_rows(self, security_code: str, market: str, trading_date: date,
                      session: MarketSession, *, as_of: datetime, min_quality: int = 90) -> list[dict]:
        coverage = self.evaluate_session(security_code, session, evaluated_at=as_of,
                                         minimum_quality=min_quality, available_as_of=as_of)
        if coverage["status"] != "complete":
            return []
        rows = self.query_day(security_code, market, trading_date, available_as_of=as_of)
        for row in rows:
            row["research_quality"] = coverage["qualityScore"]
            row["research_confidence"] = coverage["confidenceScore"]
        return rows

    def backfill(self, security_code: str, market: str, sessions: Sequence[MarketSession],
                 providers: Sequence[MinuteProvider], *, fetched_at: datetime) -> list[dict]:
        """Try providers in order for missing/partial days; records actual range and failures."""
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ArchiveError("backfill timestamp must be timezone-aware")
        reports = []
        for session in sessions:
            current = self.query_day(security_code, market, session.trading_date)
            missing_expected = {self._iso(ts) for ts in session.expected_timestamps} - {r["timestamp"] for r in current}
            needs_quality_upgrade = any(r["data_quality"] < 80 or r["source_trust"] < 80 or
                                        r["completeness"] != "complete" or
                                        r["minute_volume"] is None or r["volume_method"] == "unknown"
                                        for r in current)
            if not missing_expected and not needs_quality_upgrade:
                reports.append({"tradingDate": session.trading_date.isoformat(), "result": "already-covered", "source": None})
                continue
            last_error = None
            eligible_providers = 0
            out_of_coverage_count = 0
            used_sources = []
            final_coverage = None
            for provider in providers:
                # Do not invoke a current-session-only endpoint for finalized
                # sessions. Besides wasting retries, its expected rejection can
                # overwrite the useful failure from the historical provider.
                if (getattr(provider, "current_session_only", False) and
                        session.trading_date != fetched_at.astimezone(
                            ZoneInfo(session.timezone_name)).date()):
                    continue
                eligible_providers += 1
                try:
                    rows = provider.fetch(security_code, market, session.trading_date)
                    if not rows:
                        last_error = "empty source response"
                        continue
                    for row in rows:
                        row.validate()
                        if (row.security_code != security_code or row.market != market or
                                row.trading_date != session.trading_date):
                            raise ArchiveError("provider returned a row for a different instrument or session")
                        if row.timestamp not in session.expected_timestamps:
                            raise ArchiveError("provider returned a timestamp outside the market session schedule")
                    self.ingest(rows, mode="backfill")
                    used_sources.append(provider.name)
                    final_coverage = self.evaluate_session(security_code, session,
                                                           evaluated_at=fetched_at)
                    if final_coverage["status"] == "complete":
                        break
                except ProviderOutOfCoverage as exc:
                    out_of_coverage_count += 1
                    last_error = type(exc).__name__ + ": " + str(exc)
                except Exception as exc:  # provider fallback is deliberate; error text retained for diagnosis
                    last_error = type(exc).__name__ + ": " + str(exc)
            if final_coverage is None:
                reports.append({"tradingDate": session.trading_date.isoformat(),
                                "result": ("out_of_provider_coverage"
                                           if eligible_providers > 0 and out_of_coverage_count == eligible_providers
                                           else "unavailable"),
                                "source": None, "reason": last_error or "no historical-capable providers configured"})
            else:
                inserted = self.query_day(security_code, market, session.trading_date)
                reports.append({"tradingDate": session.trading_date.isoformat(),
                                "result": final_coverage["status"],
                                "source": used_sources,
                                "firstAvailableDate": min((r["timestamp"] for r in inserted), default=None),
                                "lastAvailableDate": max((r["timestamp"] for r in inserted), default=None),
                                "missingTimestamps": final_coverage["missingTimestamps"],
                                "coverage": final_coverage})
        return reports

    def diagnostics(self, security_code: str, market: str,
                    expected_sessions: Sequence[MarketSession] | None = None, *,
                    evaluated_at: datetime | None = None) -> dict:
        if evaluated_at is None:
            evaluated_at = datetime.now(timezone.utc)
        if evaluated_at.tzinfo is None or evaluated_at.utcoffset() is None:
            raise ArchiveError("diagnostics evaluation time must be timezone-aware")
        scoped = expected_sessions is not None
        expected = tuple(session for session in (expected_sessions or ())
                         if session.market == market and session.expected_timestamps)
        # Refresh the per-day quality projection at read time. This repairs the
        # crash window between minute ingestion and coverage evaluation, and
        # makes calendar-range diagnostics show explicit missing/partial days.
        coverage_by_day = {
            session.trading_date.isoformat(): self.evaluate_session(
                security_code, session, evaluated_at=evaluated_at)
            for session in expected
        }
        with self._connect() as db:
            rows = db.execute("""SELECT daily.trading_date,daily.count,daily.first_ts,daily.last_ts,
                    daily.last_fetch,daily.source_count,COALESCE(coverage.status,'unassessed') status
                FROM (SELECT trading_date,COUNT(*) count,MIN(timestamp) first_ts,MAX(timestamp) last_ts,
                    MAX(fetched_at) last_fetch,COUNT(DISTINCT source) source_count
                    FROM minute_bar WHERE security_code=? AND market=? GROUP BY trading_date) daily
                LEFT JOIN session_coverage coverage ON coverage.security_code=?
                    AND coverage.market=? AND coverage.trading_date=daily.trading_date
                ORDER BY daily.trading_date""",
                (security_code, market, security_code, market)).fetchall()
            statuses = {row["trading_date"]: row["status"] for row in db.execute("SELECT trading_date,status FROM session_coverage WHERE security_code=? AND market=?", (security_code, market))}
            last_live = db.execute("SELECT MAX(fetched_at) FROM collection_log WHERE security_code=? AND market=? AND mode='realtime'", (security_code, market)).fetchone()[0]
            last_backfill = db.execute("SELECT MAX(fetched_at) FROM collection_log WHERE security_code=? AND market=? AND mode='backfill'", (security_code, market)).fetchone()[0]
            def file_size_or_zero(path: Path) -> int:
                try:
                    return path.stat().st_size
                except FileNotFoundError:
                    # SQLite may remove a WAL/SHM file during a concurrent
                    # checkpoint after the connection was opened.
                    return 0

            storage_files = {
                "archiveFileBytes": file_size_or_zero(self.path),
                "walFileBytes": file_size_or_zero(Path(str(self.path) + "-wal")),
                "sharedMemoryFileBytes": file_size_or_zero(Path(str(self.path) + "-shm")),
            }
            db_size = sum(storage_files.values())
            try:
                filesystem = shutil.disk_usage(self.path.parent)
                storage = {
                    **storage_files,
                    "archiveFootprintBytes": db_size,
                    "filesystemTotalBytes": filesystem.total,
                    "filesystemUsedBytes": filesystem.used,
                    "filesystemFreeBytes": filesystem.free,
                }
            except OSError:
                # Archive diagnostics remain available when the filesystem
                # provider cannot report capacity (for example, a detached mount).
                storage = {
                    **storage_files,
                    "archiveFootprintBytes": db_size,
                    "filesystemTotalBytes": None,
                    "filesystemUsedBytes": None,
                    "filesystemFreeBytes": None,
                }
        days = [dict(row) for row in rows]
        expected_dates = {session.trading_date.isoformat() for session in expected}
        days_by_date = ({row["trading_date"]: row for row in days
                         if row["trading_date"] in expected_dates}
                        if scoped else {row["trading_date"]: row for row in days})
        for day, coverage in coverage_by_day.items():
            if day not in days_by_date:
                days_by_date[day] = {
                    "trading_date": day, "count": 0, "first_ts": None,
                    "last_ts": None, "last_fetch": None, "source_count": 0,
                    "status": coverage["status"],
                }
        if not scoped:
            for day, status in statuses.items():
                if day not in days_by_date:
                    days_by_date[day] = {
                        "trading_date": day, "count": 0, "first_ts": None,
                        "last_ts": None, "last_fetch": None, "source_count": 0,
                        "status": status,
                    }
            days = sorted(days_by_date.values(), key=lambda row: row["trading_date"])
        if scoped:
            days = sorted(days_by_date.values(), key=lambda row: row["trading_date"])
        if scoped:
            missing_days = sum(coverage_by_day[session.trading_date.isoformat()]["status"] == "missing"
                               for session in expected)
        else:
            missing_days = sum(status == "missing" for status in statuses.values())
        return {"securityCode": security_code, "market": market,
                "firstMinuteDate": rows[0]["trading_date"] if rows else None,
                "lastMinuteDate": rows[-1]["trading_date"] if rows else None,
                "archivedTradingDays": len(rows),
                "completeDays": sum(statuses.get(row["trading_date"]) == "complete" for row in days),
                "partialDays": sum(statuses.get(row["trading_date"]) == "partial" for row in days),
                "missingDays": missing_days,
                "lastRealtimeCollection": last_live, "lastBackfill": last_backfill,
                "sources": sorted({source for row in days for source in self._sources_for_day(security_code, market, row["trading_date"])}),
                "databaseBytes": db_size, "storage": storage, "days": days}

    def _sources_for_day(self, security_code: str, market: str, day: str) -> set[str]:
        with self._connect() as db:
            return {row[0] for row in db.execute("SELECT DISTINCT source FROM minute_bar WHERE security_code=? AND market=? AND trading_date=?", (security_code, market, day))}

    def backup(self, destination: Path | str) -> str:
        """Write a consistent SQLite snapshot, verify it, then atomically publish it."""
        destination = Path(destination)
        if destination.resolve() == self.path.resolve():
            raise ArchiveError("backup destination must differ from the live archive")
        destination.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary_name = tempfile.mkstemp(prefix=destination.name + ".", suffix=".tmp",
                                               dir=destination.parent)
        os.close(fd)
        temporary = Path(temporary_name)
        source = self._open_connection(self.path)
        target = sqlite3.connect(temporary)
        try:
            source.backup(target)
            self._validate_database(target)
            target.commit()
            target.close()
            target = None
            with temporary.open("r+b") as stream:
                os.fsync(stream.fileno())
            # Publish without replacing a prior backup. The temporary is in
            # the same directory, so the hard link is an atomic no-clobber move.
            os.link(temporary, destination)
            temporary.unlink()
            self._fsync_directory(destination.parent)
            return self._logical_digest(destination)
        except FileExistsError as exc:
            if target is not None:
                target.close()
                target = None
            if temporary.exists():
                temporary.unlink()
            raise ArchiveError("backup destination already exists") from exc
        except Exception:
            if target is not None:
                target.close()
                target = None
            if temporary.exists():
                temporary.unlink()
            raise
        finally:
            if target is not None:
                target.close()
            source.close()

    @classmethod
    def restore_backup(cls, source_path: Path | str, destination: Path | str) -> "MinuteArchive":
        """Restore to a new path only; never overwrite an existing live database."""
        source_path, destination = Path(source_path), Path(destination)
        if source_path.resolve() == destination.resolve():
            raise ArchiveError("restore source and destination must differ")
        destination.parent.mkdir(parents=True, exist_ok=True)
        source = sqlite3.connect(f"file:{source_path.resolve()}?mode=ro", uri=True)
        fd, temporary_name = tempfile.mkstemp(prefix=destination.name + ".", suffix=".restore",
                                               dir=destination.parent)
        os.close(fd)
        temporary = Path(temporary_name)
        target = sqlite3.connect(temporary)
        try:
            cls._validate_database(source)
            source.backup(target)
            cls._validate_database(target)
            target.commit()
            target.close()
            target = None
            with temporary.open("r+b") as stream:
                os.fsync(stream.fileno())
            # Hard-link publication is atomic and fails if the destination already exists.
            os.link(temporary, destination)
            temporary.unlink()
            cls._fsync_directory(destination.parent)
        except FileExistsError as exc:
            if target is not None:
                target.close()
                target = None
            raise ArchiveError("restore destination already exists") from exc
        except Exception:
            if target is not None:
                target.close()
                target = None
            if temporary.exists():
                temporary.unlink()
            raise
        finally:
            if target is not None:
                target.close()
            source.close()
        return cls(destination)

    @staticmethod
    def _validate_database(db: sqlite3.Connection) -> None:
        result = db.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise ArchiveError("archive integrity check failed: " + str(result))
        row = db.execute("SELECT value FROM archive_meta WHERE key='schema_version'").fetchone()
        if row is None:
            raise ArchiveError("backup archive schema version is missing")
        MinuteArchive._validate_schema_version(row[0])

        required_tables = {"minute_bar", "minute_observation", "session_coverage", "collection_log"}
        tables = {item[0] for item in db.execute(
            "SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
        if not required_tables.issubset(tables):
            raise ArchiveError("archive is missing required tables")

        bar_columns = ("security_code", "market", "trading_date", "timestamp", "price",
                       "cumulative_volume", "minute_volume", "volume_method", "source",
                       "fetched_at", "source_timestamp", "data_quality", "source_trust",
                       "completeness", "schema_version")
        for table in ("minute_bar", "minute_observation"):
            cursor = db.execute(f"SELECT {','.join(bar_columns)} FROM {table}")
            try:
                for values in cursor:
                    MinuteArchive._validate_stored_bar(dict(zip(bar_columns, values)))
            finally:
                cursor.close()

        coverage_columns = ("security_code", "market", "trading_date", "expected_count",
                            "observed_count", "missing_timestamps", "status", "evaluated_at",
                            "source_summary", "schema_version")
        cursor = db.execute(f"SELECT {','.join(coverage_columns)} FROM session_coverage")
        for values in cursor:
            item = dict(zip(coverage_columns, values))
            try:
                day = date.fromisoformat(item["trading_date"])
                missing = json.loads(item["missing_timestamps"])
                sources = json.loads(item["source_summary"])
                evaluated_at = datetime.fromisoformat(item["evaluated_at"])
            except (TypeError, ValueError, json.JSONDecodeError) as exc:
                raise ArchiveError("archive has invalid session coverage metadata") from exc
            if (day.isoformat() != item["trading_date"] or
                    not isinstance(item["security_code"], str) or not item["security_code"].strip() or
                    not isinstance(item["market"], str) or not item["market"].strip() or
                    type(item["expected_count"]) is not int or item["expected_count"] < 1 or
                    type(item["observed_count"]) is not int or
                    not 0 <= item["observed_count"] <= item["expected_count"] or
                    not isinstance(missing, list) or
                    any(not isinstance(value, str) for value in missing) or
                    len(missing) != item["expected_count"] - item["observed_count"] or
                    item["status"] not in {"complete", "partial", "missing"} or
                    (item["status"] == "complete" and
                     (item["observed_count"] != item["expected_count"] or missing)) or
                    not isinstance(sources, list) or
                    any(not isinstance(value, str) or not value.strip() for value in sources) or
                    evaluated_at.tzinfo is None or evaluated_at.utcoffset() is None or
                    evaluated_at.utcoffset().total_seconds() != 0 or
                    type(item["schema_version"]) is not int or item["schema_version"] != SCHEMA_VERSION):
                raise ArchiveError("archive has invalid session coverage metadata")

    @staticmethod
    def _validate_stored_bar(item: dict) -> None:
        try:
            day = date.fromisoformat(item["trading_date"])
            price = Decimal(item["price"])
            timestamp = datetime.fromisoformat(item["timestamp"])
            fetched_at = datetime.fromisoformat(item["fetched_at"])
            source_timestamp = (datetime.fromisoformat(item["source_timestamp"])
                                if item["source_timestamp"] is not None else None)
        except (TypeError, ValueError, InvalidOperation) as exc:
            raise ArchiveError("archive contains an invalid minute observation") from exc

        def canonical_utc(value: datetime, raw: str) -> bool:
            return (value.tzinfo is not None and value.utcoffset() is not None and
                    value.utcoffset().total_seconds() == 0 and
                    value.astimezone(timezone.utc).isoformat(timespec="microseconds") == raw)

        if (day.isoformat() != item["trading_date"] or
                not isinstance(item["security_code"], str) or
                not item["security_code"] or item["security_code"].strip() != item["security_code"] or
                not isinstance(item["market"], str) or not item["market"] or
                item["market"].strip() != item["market"] or
                not price.is_finite() or price <= 0 or
                not canonical_utc(timestamp, item["timestamp"]) or
                not canonical_utc(fetched_at, item["fetched_at"]) or
                (source_timestamp is not None and
                 (not canonical_utc(source_timestamp, item["source_timestamp"]) or
                  source_timestamp > fetched_at)) or
                item["volume_method"] not in {"source_minute", "cumulative_delta", "unknown"} or
                (item["minute_volume"] is not None and
                 (type(item["minute_volume"]) is not int or item["minute_volume"] < 0)) or
                (item["cumulative_volume"] is not None and
                 (type(item["cumulative_volume"]) is not int or item["cumulative_volume"] < 0)) or
                (item["volume_method"] == "cumulative_delta" and
                 (item["minute_volume"] is None or item["cumulative_volume"] is None)) or
                not isinstance(item["source"], str) or not item["source"].strip() or
                type(item["data_quality"]) is not int or not 0 <= item["data_quality"] <= 100 or
                type(item["source_trust"]) is not int or not 0 <= item["source_trust"] <= 100 or
                item["completeness"] not in {"complete", "partial", "unknown"} or
                type(item["schema_version"]) is not int or item["schema_version"] != SCHEMA_VERSION):
            raise ArchiveError("archive contains an invalid minute observation")

    @staticmethod
    def _logical_digest(path: Path) -> str:
        import hashlib
        connection = sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)
        try:
            payload = "\n".join(connection.iterdump()).encode("utf-8")
            return hashlib.sha256(payload).hexdigest()
        finally:
            connection.close()

    @staticmethod
    def _fsync_directory(path: Path) -> None:
        descriptor = os.open(path, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)

    def readiness_check(self) -> str:
        """Perform bounded metadata checks suitable for frequent health probes.

        Full PRAGMA integrity_check and row validation belong in backup/maintenance
        workflows; scanning the archive on every HTTP readiness request can block
        clients as the database grows.
        """
        required_tables = {"minute_bar", "minute_observation", "session_coverage", "collection_log"}
        try:
            with self._connect() as db:
                row = db.execute(
                    "SELECT value FROM archive_meta WHERE key='schema_version'").fetchone()
                if row is None:
                    raise ArchiveError("archive schema version metadata is missing")
                self._validate_schema_version(row[0])
                tables = {item[0] for item in db.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
                if not required_tables.issubset(tables):
                    raise ArchiveError("archive is missing required tables")
            return "ok"
        except sqlite3.DatabaseError as exc:
            raise ArchiveError("archive readiness check failed: " + str(exc)) from exc

    def integrity_check(self) -> str:
        try:
            with self._connect() as db:
                self._validate_database(db)
            return "ok"
        except sqlite3.DatabaseError as exc:
            raise ArchiveError("archive integrity check failed: " + str(exc)) from exc


@dataclass(frozen=True)
class RetentionPolicy:
    """Declarative only: pruning is opt-in and protected instruments are retained."""
    retain_days: int | None = None
    protected_security_codes: frozenset[str] = frozenset()
    compress_closed_years: bool = True
