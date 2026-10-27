"""NAS-facing orchestration for the portable F minute archive core.

This module supplies durable, bounded scheduling and exact-date APIs. It does
not configure a market data vendor or infer an exchange calendar.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from enum import IntEnum
from decimal import Decimal
from pathlib import Path
from typing import Callable, Mapping, Protocol, Sequence
import sqlite3

from .archive import ArchiveError, MarketSession, MinuteArchive, MinuteBar, MinuteProvider
from .research import (
    build_morning_selloff_recovery_evidence, build_vwap_break_evidence,
    replay_grid_spacing_evidence,
)
from .evidence import ResearchEvidenceEnvelope


class ServiceError(ValueError):
    pass


class BackfillQueueFull(ServiceError):
    pass


DEFAULT_INITIAL_BACKFILL_SESSIONS = 5


class MarketCalendar(Protocol):
    def sessions(self, market: str, start: date, end: date) -> Sequence[MarketSession]: ...


class BackfillPriority(IntEnum):
    HOLDING = 0
    WATCHLIST = 10
    AI_RESEARCH = 20
    BENCHMARK = 30

    @classmethod
    def parse(cls, value: str) -> "BackfillPriority":
        try:
            return {
                "holding": cls.HOLDING,
                "watchlist": cls.WATCHLIST,
                "aiResearch": cls.AI_RESEARCH,
                "benchmark": cls.BENCHMARK,
            }[value]
        except KeyError as exc:
            raise ServiceError("unsupported backfill priority") from exc


@dataclass(frozen=True)
class BackfillTask:
    security_code: str
    market: str
    trading_date: date
    priority: BackfillPriority
    attempts: int
    status: str
    next_attempt_at: datetime
    last_error: str | None


class MinuteArchiveService:
    def __init__(self, archive: MinuteArchive, queue_path: Path | str,
                 calendars: Mapping[str, MarketCalendar],
                 providers: Mapping[str, Sequence[MinuteProvider]], *,
                 max_queued_sessions: int = 10_000,
                 lease_seconds: int = 180,
                 retry_base_seconds: int = 60,
                 retry_max_seconds: int = 21_600,
                 max_backfill_attempts: int = 5,
                 clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc)):
        if (max_queued_sessions < 1 or lease_seconds < 1 or retry_base_seconds < 1 or
                retry_max_seconds < retry_base_seconds or max_backfill_attempts < 1):
            raise ServiceError("invalid queue or retry bounds")
        self.archive = archive
        self.queue_path = Path(queue_path)
        self.queue_path.parent.mkdir(parents=True, exist_ok=True)
        self.calendars = dict(calendars)
        self.providers = {market: tuple(items) for market, items in providers.items()}
        self.max_queued_sessions = max_queued_sessions
        self.lease_seconds = lease_seconds
        self.retry_base_seconds = retry_base_seconds
        self.retry_max_seconds = retry_max_seconds
        self.max_backfill_attempts = max_backfill_attempts
        self.clock = clock
        with self._connect() as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                PRAGMA synchronous=FULL;
                CREATE TABLE IF NOT EXISTS queue_meta (
                    key TEXT PRIMARY KEY, value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS backfill_task (
                    security_code TEXT NOT NULL, market TEXT NOT NULL, trading_date TEXT NOT NULL,
                    priority INTEGER NOT NULL, status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
                    next_attempt_at TEXT NOT NULL, lease_until TEXT, last_error TEXT,
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                    PRIMARY KEY(security_code, market, trading_date)
                );
                CREATE INDEX IF NOT EXISTS idx_backfill_ready
                    ON backfill_task(status, next_attempt_at, priority, created_at);
            """)
            self._validate_queue(db)

    @staticmethod
    def _validate_queue(db: sqlite3.Connection) -> None:
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise ServiceError("backfill queue integrity check failed")
        meta_info = db.execute("PRAGMA table_info(queue_meta)").fetchall()
        meta_columns = {row["name"] for row in meta_info}
        meta_primary_key = tuple(row["name"] for row in sorted(
            (row for row in meta_info if row["pk"]), key=lambda row: row["pk"]))
        if not {"key", "value"}.issubset(meta_columns) or meta_primary_key != ("key",):
            raise ServiceError("backfill queue metadata schema is incomplete")
        task_info = db.execute("PRAGMA table_info(backfill_task)").fetchall()
        columns = {row["name"] for row in task_info}
        task_primary_key = tuple(row["name"] for row in sorted(
            (row for row in task_info if row["pk"]), key=lambda row: row["pk"]))
        required = {"security_code", "market", "trading_date", "priority", "status",
                    "attempts", "next_attempt_at", "lease_until", "last_error",
                    "created_at", "updated_at"}
        if not required.issubset(columns) or task_primary_key != (
                "security_code", "market", "trading_date"):
            raise ServiceError("backfill queue schema is incomplete")
        version = db.execute("SELECT value FROM queue_meta WHERE key='schema_version'").fetchone()
        if version is None:
            # Existing v0 queues predate the explicit metadata row. Preserve their
            # terminal failures while adopting the explicit status vocabulary.
            db.execute("UPDATE backfill_task SET status='permanent_unavailable' WHERE status='failed'")
            db.execute("INSERT INTO queue_meta(key,value) VALUES('schema_version','2')")
        elif version[0] not in {"1", "2"}:
            raise ServiceError("backfill queue schema is unsupported")
        elif version[0] == "1":
            # v1 used one overloaded `failed` state. Preserve those rows as
            # terminal unavailable tasks; operators may explicitly enqueue them again.
            db.execute("UPDATE backfill_task SET status='permanent_unavailable' WHERE status='failed'")
            db.execute("UPDATE queue_meta SET value='2' WHERE key='schema_version'")
        rows = db.execute("SELECT * FROM backfill_task").fetchall()
        valid_statuses = {"queued", "running", "complete", "partial", "missing",
                          "out_of_provider_coverage", "retryable", "permanent_unavailable"}
        valid_priorities = {int(item) for item in BackfillPriority}
        for row in rows:
            try:
                MinuteArchiveService._validate_identity(row["security_code"], row["market"])
                if date.fromisoformat(row["trading_date"]).isoformat() != row["trading_date"]:
                    raise ValueError("non-canonical date")
                if (type(row["priority"]) is not int or row["priority"] not in valid_priorities or
                        row["status"] not in valid_statuses or type(row["attempts"]) is not int or
                        row["attempts"] < 0):
                    raise ValueError("invalid queue enum or counter")
                for key in ("created_at", "updated_at"):
                    stamp = datetime.fromisoformat(row[key])
                    if stamp.tzinfo is None or stamp.utcoffset() is None:
                        raise ValueError("naive queue timestamp")
                if row["next_attempt_at"] is not None:
                    stamp = datetime.fromisoformat(row["next_attempt_at"])
                    if stamp.tzinfo is None or stamp.utcoffset() is None:
                        raise ValueError("naive next-attempt timestamp")
                elif row["status"] in {"queued", "retryable", "running"}:
                    raise ValueError("retryable task has no next-attempt timestamp")
                if row["lease_until"] is not None:
                    lease = datetime.fromisoformat(row["lease_until"])
                    if lease.tzinfo is None or lease.utcoffset() is None:
                        raise ValueError("naive lease timestamp")
                if (row["status"] == "running") != (row["lease_until"] is not None):
                    raise ValueError("queue lease does not match task status")
                if row["last_error"] is not None and not isinstance(row["last_error"], str):
                    raise ValueError("invalid error field")
            except (KeyError, TypeError, ValueError, OverflowError) as exc:
                raise ServiceError("backfill queue contains invalid task data") from exc

    def _connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.queue_path, timeout=30, isolation_level="IMMEDIATE")
        db.row_factory = sqlite3.Row
        return db

    @staticmethod
    def _stamp(value: datetime) -> str:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ServiceError("timestamps must be timezone-aware")
        return value.astimezone(timezone.utc).isoformat(timespec="seconds")

    @staticmethod
    def _validate_identity(security_code: str, market: str) -> None:
        if (not isinstance(security_code, str) or not security_code or
                security_code.strip() != security_code or len(security_code) > 32):
            raise ServiceError("invalid security code")
        if (not isinstance(market, str) or not market or
                market.strip() != market or len(market) > 16):
            raise ServiceError("invalid market")

    def _calendar(self, market: str) -> MarketCalendar:
        try:
            return self.calendars[market]
        except KeyError as exc:
            raise ServiceError("no calendar configured for market") from exc

    def _calendar_sessions(self, market: str, start: date, end: date) -> tuple[MarketSession, ...]:
        if type(start) is not date or type(end) is not date or end < start:
            raise ServiceError("calendar range must use ordered calendar dates")
        sessions = tuple(self._calendar(market).sessions(market, start, end))
        if any(not isinstance(session, MarketSession) or session.market != market or
               type(session.trading_date) is not date or
               not start <= session.trading_date <= end for session in sessions):
            raise ServiceError("calendar returned a session outside the requested market/date range")
        if len({session.trading_date for session in sessions}) != len(sessions):
            raise ServiceError("calendar returned duplicate trading dates")
        return tuple(sorted(sessions, key=lambda session: session.trading_date))

    def enqueue_backfill(self, security_code: str, market: str, start: date, end: date,
                         priority: BackfillPriority) -> dict:
        self._validate_identity(security_code, market)
        if type(start) is not date or type(end) is not date:
            raise ServiceError("backfill range must use calendar dates")
        if not isinstance(priority, BackfillPriority):
            raise ServiceError("backfill priority must be an explicit BackfillPriority")
        if end < start:
            raise ServiceError("end date precedes start date")
        sessions = self._calendar_sessions(market, start, end)
        sessions = tuple(session for session in sessions if session.expected_timestamps)
        requested_sessions = len(sessions)
        evaluated_at = self.clock()
        sessions = tuple(session for session in sessions
                         if self.archive.evaluate_session(
                             security_code, session, evaluated_at=evaluated_at
                         )["status"] != "complete")
        already_covered = requested_sessions - len(sessions)
        now = self._stamp(evaluated_at)
        inserted = 0
        with self._connect() as db:
            db.execute("BEGIN IMMEDIATE")
            active = db.execute("SELECT COUNT(*) FROM backfill_task WHERE status IN ('queued','retryable','running')").fetchone()[0]
            new_keys = []
            for session in sessions:
                found = db.execute("SELECT status FROM backfill_task WHERE security_code=? AND market=? AND trading_date=?",
                                   (security_code, market, session.trading_date.isoformat())).fetchone()
                if found is None or found["status"] not in {"queued", "retryable", "running"}:
                    new_keys.append(session)
            if active + len(new_keys) > self.max_queued_sessions:
                raise BackfillQueueFull("backfill queue capacity reached")
            for session in sessions:
                day = session.trading_date.isoformat()
                existing = db.execute("SELECT status FROM backfill_task WHERE security_code=? AND market=? AND trading_date=?",
                                      (security_code, market, day)).fetchone()
                db.execute("""INSERT INTO backfill_task
                    (security_code,market,trading_date,priority,status,attempts,next_attempt_at,lease_until,last_error,created_at,updated_at)
                    VALUES (?,?,?,?, 'queued',0,?,NULL,NULL,?,?)
                    ON CONFLICT(security_code,market,trading_date) DO UPDATE SET
                    priority=MIN(backfill_task.priority,excluded.priority), status='queued',
                    attempts=CASE WHEN backfill_task.status IN ('partial','missing','out_of_provider_coverage','permanent_unavailable') THEN 0 ELSE backfill_task.attempts END,
                    next_attempt_at=excluded.next_attempt_at, lease_until=NULL,last_error=NULL,updated_at=excluded.updated_at""",
                    (security_code, market, day, int(priority), now, now, now))
                inserted += 1
        return {"securityCode": security_code, "market": market,
                "requestedSessions": requested_sessions, "alreadyCoveredSessions": already_covered,
                "queuedOrRequeued": inserted,
                "priority": priority.name.lower()}

    def enqueue_initial_history(self, security_code: str, market: str, *, through: date,
                                sessions_back: int = DEFAULT_INITIAL_BACKFILL_SESSIONS,
                                priority: BackfillPriority = BackfillPriority.WATCHLIST) -> dict:
        self._validate_identity(security_code, market)
        if type(through) is not date:
            raise ServiceError("history cutoff must be a calendar date")
        if type(sessions_back) is not int or sessions_back < 1 or sessions_back > 500:
            raise ServiceError("sessions_back must be between 1 and 500")
        if not isinstance(priority, BackfillPriority):
            raise ServiceError("backfill priority must be an explicit BackfillPriority")
        # Calendar supplies actual sessions, so using a bounded calendar-day lookback
        # avoids inventing trading days and covers holidays without synthetic rows.
        start = through - timedelta(days=min(730, sessions_back * 2))
        sessions = self._calendar_sessions(market, start, through)
        sessions = tuple(session for session in sessions if session.expected_timestamps)[-sessions_back:]
        if not sessions:
            return {"securityCode": security_code, "market": market,
                    "requestedSessions": 0, "alreadyCoveredSessions": 0,
                    "queuedOrRequeued": 0,
                    "priority": priority.name.lower()}
        return self.enqueue_backfill(security_code, market, sessions[0].trading_date,
                                     sessions[-1].trading_date, priority)

    def on_instrument_added(self, security_code: str, market: str, *, added_to: str,
                            through: date,
                            sessions_back: int = DEFAULT_INITIAL_BACKFILL_SESSIONS) -> dict:
        if not isinstance(added_to, str):
            raise ServiceError("unsupported instrument category")
        priorities = {"holding": BackfillPriority.HOLDING,
                      "watchlist": BackfillPriority.WATCHLIST,
                      "aiResearch": BackfillPriority.AI_RESEARCH,
                      "benchmark": BackfillPriority.BENCHMARK}
        try:
            priority = priorities[added_to]
        except KeyError as exc:
            raise ServiceError("unsupported instrument category") from exc
        return self.enqueue_initial_history(security_code, market, through=through,
                                            sessions_back=sessions_back, priority=priority)

    def ingest_realtime(self, bars: Sequence[MinuteBar]) -> list[dict]:
        if not bars:
            return []
        groups: dict[tuple[str, str, date], list[MinuteBar]] = {}
        for bar in bars:
            try:
                bar.validate()
            except ArchiveError as exc:
                raise ServiceError("invalid realtime minute observation") from exc
            groups.setdefault((bar.security_code, bar.market, bar.trading_date), []).append(bar)
        output = []
        evaluated_at = self.clock()
        for (security, market, day), group in groups.items():
            session = next((item for item in self._calendar_sessions(market, day, day)
                            if item.trading_date == day), None)
            if session is None:
                raise ServiceError("realtime data received for a date absent from the market calendar")
            if any(bar.timestamp not in session.expected_timestamps for bar in group):
                raise ServiceError("realtime row falls outside the market session schedule")
            stored = self.archive.ingest(group, mode="realtime")
            coverage = self.archive.evaluate_session(security, session, evaluated_at=evaluated_at)
            output.append({"securityCode": security, "market": market,
                           "tradingDate": day.isoformat(), "storedObservations": stored,
                           "coverage": coverage})
        return output

    def get_history(self, security_code: str, market: str, trading_date: date,
                    *, available_as_of: datetime | None = None,
                    minimum_quality: int = 80) -> dict:
        self._validate_identity(security_code, market)
        if type(trading_date) is not date:
            raise ServiceError("trading_date must be a calendar date")
        if type(minimum_quality) is not int or not 0 <= minimum_quality <= 100:
            raise ServiceError("minimum quality must be between 0 and 100")
        if available_as_of is not None:
            try:
                aware_cutoff = (available_as_of.tzinfo is not None and
                                available_as_of.utcoffset() is not None)
                current = self.clock()
                aware_now = current.tzinfo is not None and current.utcoffset() is not None
                if not aware_cutoff or not aware_now:
                    raise ServiceError("available_as_of and service clock must be timezone-aware")
                if available_as_of.astimezone(timezone.utc) > current.astimezone(timezone.utc):
                    raise ServiceError("available_as_of cannot be in the future")
            except (OverflowError, ValueError) as exc:
                raise ServiceError("available_as_of is invalid") from exc
        session = next((item for item in self._calendar_sessions(market, trading_date, trading_date)
                        if item.trading_date == trading_date), None)
        if session is None:
            return {"securityCode": security_code, "market": market,
                    "tradingDate": trading_date.isoformat(), "status": "not-a-session",
                    "coverage": None, "bars": []}
        coverage = self.archive.evaluate_session(security_code, session,
                                                 evaluated_at=available_as_of or self.clock(),
                                                 minimum_quality=minimum_quality,
                                                 available_as_of=available_as_of)
        bars = self.archive.query_day(security_code, market, trading_date,
                                      available_as_of=available_as_of)
        api_bars = [{
            "securityCode": row["security_code"],
            "market": row["market"],
            "tradingDate": row["trading_date"],
            "timestamp": row["timestamp"],
            "price": row["price"],
            "cumulativeVolume": row["cumulative_volume"],
            "minuteVolume": row["minute_volume"],
            "volumeMethod": row["volume_method"],
            "source": row["source"],
            "fetchedAt": row["fetched_at"],
            "sourceTimestamp": row["source_timestamp"],
            "dataQuality": row["data_quality"],
            "sourceTrust": row["source_trust"],
            "completeness": row["completeness"],
            "schemaVersion": row["schema_version"],
        } for row in bars]
        return {"securityCode": security_code, "market": market,
                "tradingDate": trading_date.isoformat(), "status": coverage["status"],
                "timezone": session.timezone_name, "coverage": coverage, "bars": api_bars}

    def get_research_evidence(self, security_code: str, market: str, start: date, end: date,
                              *, as_of: datetime, minimum_independent_days: int = 20,
                              minimum_quality: int = 90) -> dict:
        """Return bounded statistics from qualified archived sessions, never raw minute series."""
        self._validate_identity(security_code, market)
        if type(start) is not date or type(end) is not date:
            raise ServiceError("research range must use calendar dates")
        if not isinstance(as_of, datetime):
            raise ServiceError("research as-of must be a datetime")
        generated_at = self.clock()
        if (as_of.tzinfo is None or as_of.utcoffset() is None or generated_at.tzinfo is None or
                generated_at.utcoffset() is None or as_of > generated_at or
                end < start or (end - start).days > 730):
            raise ServiceError("research requires a timezone-aware as-of and a range of at most 730 days")
        if (type(minimum_independent_days) is not int or not 1 <= minimum_independent_days <= 500 or
                type(minimum_quality) is not int or not 0 <= minimum_quality <= 100):
            raise ServiceError("research thresholds are outside supported bounds")
        sessions = self._calendar_sessions(market, start, end)
        if len(sessions) > 500:
            raise ServiceError("research calendar returned too many sessions")
        eligible = []
        status_counts = {"complete": 0, "partial": 0, "missing": 0, "not-a-session": 0}
        for session in sessions:
            if not session.expected_timestamps:
                status_counts["not-a-session"] += 1
                continue
            coverage = self.archive.evaluate_session(
                security_code, session, evaluated_at=as_of,
                minimum_quality=minimum_quality, available_as_of=as_of)
            status_counts[coverage["status"]] = status_counts.get(coverage["status"], 0) + 1
            rows = self.archive.research_rows(security_code, market, session.trading_date,
                                              session, as_of=as_of, min_quality=minimum_quality)
            if coverage["status"] != "complete" or not rows:
                continue
            eligible.append({"tradingDate": session.trading_date.isoformat(),
                             "timezone": session.timezone_name, "complete": True,
                             "qualityScore": coverage["qualityScore"],
                             "confidenceScore": coverage["confidenceScore"],
                             "qualityFactors": coverage["qualityFactors"],
                             "crossVerifiedTimestamps": coverage["crossVerifiedTimestamps"],
                             "bars": rows})
        if eligible:
            factor_names = tuple(eligible[0]["qualityFactors"])
            data_quality = {
                "scoringMethod": "weighted-session-quality-v1",
                "eligibleSessions": len(eligible),
                "averageQuality": round(sum(row["qualityScore"] for row in eligible) / len(eligible), 2),
                "averageConfidence": round(sum(row["confidenceScore"] for row in eligible) / len(eligible), 2),
                "averageFactors": {name: round(sum(row["qualityFactors"][name] for row in eligible) /
                                                len(eligible), 2) for name in factor_names},
                "crossSourceVerifiedSessions": sum(row["crossVerifiedTimestamps"] > 0
                                                    for row in eligible),
                "singleSourceSessions": sum(row["crossVerifiedTimestamps"] == 0
                                             for row in eligible),
            }
        else:
            data_quality = {"scoringMethod": "weighted-session-quality-v1", "eligibleSessions": 0,
                            "averageQuality": None, "averageConfidence": None,
                            "averageFactors": {}, "crossSourceVerifiedSessions": 0,
                            "singleSourceSessions": 0}
        vwap = build_vwap_break_evidence(eligible, research_as_of=as_of,
                                         minimum_independent_days=minimum_independent_days,
                                         minimum_quality=minimum_quality)
        recovery = build_morning_selloff_recovery_evidence(
            eligible, research_as_of=as_of, minimum_independent_days=minimum_independent_days,
            minimum_quality=minimum_quality)
        grid = replay_grid_spacing_evidence(
            eligible, research_as_of=as_of,
            spacing_percentages=(Decimal("0.5"), Decimal("1"), Decimal("1.5"), Decimal("2")),
            minimum_independent_days=minimum_independent_days, minimum_quality=minimum_quality)
        vwap["dataQuality"] = data_quality
        recovery["dataQuality"] = data_quality
        grid["dataQuality"] = data_quality
        # Keep the mobile/AI payload compact: statistics and provenance, never raw bars,
        # session ledgers, or per-signal sample rows. Those remain available from NAS for
        # audited research and exact-date chart requests.
        for section in (vwap, recovery):
            sample_rows = section.pop("samples", None)
            if sample_rows is not None:
                section["sampleCount"] = len(sample_rows)
        for value in grid["spacings"].values():
            session_rows = value.pop("sessions", None)
            if session_rows is not None:
                value["sessionCount"] = len(session_rows)
        payload = {"securityCode": security_code, "market": market,
                "range": {"start": start.isoformat(), "end": end.isoformat()},
                "asOf": as_of.astimezone(timezone.utc).isoformat(),
                "timezone": self._timezone_for_market(market, sessions),
                "sessionCoverage": status_counts, "qualifiedIndependentDays": len(eligible),
                "minimumQuality": minimum_quality, "sources": sorted({
                    row["source"] for session in eligible for row in session["bars"]}),
                "researchEvidence": {"vwapBreak": vwap, "morningRecovery": recovery,
                                     "gridSpacingReplay": grid},
                "rawMinuteBarsIncluded": False, "tradePlan": None}
        return ResearchEvidenceEnvelope.create(payload, generated_at=generated_at).to_dict()

    def get_diagnostics(self, security_code: str, market: str,
                        start: date | None = None, end: date | None = None) -> dict:
        self._validate_identity(security_code, market)
        if ((start is not None and type(start) is not date) or
                (end is not None and type(end) is not date)):
            raise ServiceError("diagnostic range must use calendar dates")
        if (start is None) != (end is None) or (start is not None and end is not None and end < start):
            raise ServiceError("diagnostic date range must contain ordered start/end dates")
        expected = self._calendar_sessions(market, start, end) if start and end else ()
        result = self.archive.diagnostics(security_code, market,
                                          expected if start and end else None,
                                          evaluated_at=self.clock())
        result["days"] = [{
            "tradingDate": row["trading_date"],
            "minuteCount": row["count"],
            "firstTimestamp": row["first_ts"],
            "lastTimestamp": row["last_ts"],
            "lastFetchedAt": row["last_fetch"],
            "sourceCount": row["source_count"],
            "completeness": row["status"],
        } for row in result["days"]]
        result["timezone"] = self._timezone_for_market(market, expected)
        result["diagnosticRange"] = {"start": start.isoformat(), "end": end.isoformat()} if start and end else None
        result["missingDaysScope"] = ("requestedCalendarRange" if start and end
                                       else "recordedCoverageOnly")
        result["missingDaysMayBeUnderstated"] = not (start and end)
        result["queuedBackfillSessions"] = self.queue_count(security_code, market)
        return result

    def _timezone_for_market(self, market: str, sessions: Sequence[MarketSession]) -> str | None:
        if sessions:
            return sessions[0].timezone_name
        calendar = self._calendar(market)
        zone = getattr(calendar, "timezone_name", None)
        return str(zone) if zone else None

    def queue_count(self, security_code: str | None = None,
                    market: str | None = None) -> int:
        if (security_code is None) != (market is None):
            raise ServiceError("security code and market filters must be provided together")
        if security_code is not None and market is not None:
            self._validate_identity(security_code, market)
            where = "status IN ('queued','retryable','running') AND security_code=? AND market=?"
            parameters = (security_code, market)
        else:
            where = "status IN ('queued','retryable','running')"
            parameters = ()
        with self._connect() as db:
            return int(db.execute(f"SELECT COUNT(*) FROM backfill_task WHERE {where}", parameters).fetchone()[0])

    def queue_snapshot(self) -> list[dict]:
        with self._connect() as db:
            rows = db.execute("SELECT security_code,market,trading_date,priority,status,attempts,next_attempt_at,last_error FROM backfill_task WHERE status!='complete' ORDER BY priority,created_at,trading_date").fetchall()
            return [dict(row) for row in rows]

    def backfill_status(self, securities: Sequence[str], market: str, *, through: date,
                        sessions_back: int = DEFAULT_INITIAL_BACKFILL_SESSIONS) -> dict:
        """Summarize a bounded, explicit recent-session plan without inventing coverage."""
        if type(through) is not date or type(sessions_back) is not int or not 1 <= sessions_back <= 500:
            raise ServiceError("invalid backfill status range")
        unique = tuple(dict.fromkeys(securities))
        if not unique:
            return {"market": market, "securityCount": 0, "plannedSessions": 0,
                    "plannedTasks": 0, "coveragePercent": 0.0,
                    "complete": 0, "partial": 0, "missing": 0, "outOfProviderCoverage": 0, "retryable": 0,
                    "permanentUnavailable": 0, "providerCoverage": self.provider_coverage(market),
                    "earliestRealHistoryDate": None, "latestRealHistoryDate": None}
        for code in unique:
            self._validate_identity(code, market)
        calendar = self._calendar(market)
        start = through - timedelta(days=max(sessions_back * 2, sessions_back + 14))
        sessions = [item for item in self._calendar_sessions(market, start, through)
                    if item.expected_timestamps]
        sessions = sessions[-sessions_back:]
        counters = {key: 0 for key in ("complete", "partial", "missing", "outOfProviderCoverage",
                                        "retryable", "permanentUnavailable")}
        real_dates: set[str] = set()
        archive_states: dict[tuple[str, str], str] = {}
        for code in unique:
            diag = self.archive.diagnostics(code, market, sessions, evaluated_at=self.clock())
            for row in diag["days"]:
                archive_states[(code, row["trading_date"])] = row["status"]
                if row.get("count", 0) > 0: real_dates.add(row["trading_date"])
        planned_tasks = len(sessions) * len(unique)
        with self._connect() as db:
            rows = db.execute("SELECT security_code,trading_date,status FROM backfill_task WHERE market=?", (market,)).fetchall()
        task_states = {(row["security_code"], row["trading_date"]): row["status"] for row in rows}
        for code in unique:
            for session in sessions:
                key = (code, session.trading_date.isoformat())
                archive_state, task_state = archive_states.get(key, "missing"), task_states.get(key)
                if archive_state == "complete": counters["complete"] += 1
                elif archive_state == "partial": counters["partial"] += 1
                elif task_state in {"queued", "retryable", "running"}: counters["retryable"] += 1
                elif task_state == "partial": counters["partial"] += 1
                elif task_state == "out_of_provider_coverage": counters["outOfProviderCoverage"] += 1
                elif task_state == "permanent_unavailable": counters["permanentUnavailable"] += 1
                else: counters["missing"] += 1
        coverage = round(100 * counters["complete"] / planned_tasks, 2) if planned_tasks else 0.0
        providers = self.provider_coverage(market)
        return {"market": market, "securityCount": len(unique),
                "plannedSessions": len(sessions), "plannedTasks": planned_tasks,
                **counters, "coveragePercent": coverage,
                "providerCoverage": providers,
                "earliestRealHistoryDate": min(real_dates) if real_dates else None,
                "latestRealHistoryDate": max(real_dates) if real_dates else None,
                "planStartDate": sessions[0].trading_date.isoformat() if sessions else None,
                "planEndDate": sessions[-1].trading_date.isoformat() if sessions else None}

    def provider_coverage(self, market: str) -> list[dict]:
        """Report only empirically declared provider bounds; unknown stays unknown."""
        return [{"provider": provider.name,
                 "coverageStart": (provider.coverage_start.isoformat()
                                   if isinstance(getattr(provider, "coverage_start", None), date) else None),
                 "coverageEnd": (provider.coverage_end.isoformat()
                                 if isinstance(getattr(provider, "coverage_end", None), date) else None),
                 "currentSessionOnly": bool(getattr(provider, "current_session_only", False)),
                 "coverageEvidence": getattr(provider, "coverage_evidence", "not empirically established")}
                for provider in self.providers.get(market, ())]

    def run_backfill_batch(self, *, limit: int = 10) -> list[dict]:
        if limit < 1 or limit > 500:
            raise ServiceError("batch limit must be between 1 and 500")
        results = []
        for _ in range(limit):
            now_dt = self.clock()
            now = self._stamp(now_dt)
            lease_until = self._stamp(now_dt + timedelta(seconds=self.lease_seconds))
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                row = db.execute("""SELECT * FROM backfill_task
                    WHERE status IN ('queued','retryable') AND next_attempt_at<=?
                    OR (status='running' AND lease_until<=?)
                    ORDER BY priority,created_at,trading_date LIMIT 1""", (now, now)).fetchone()
                if row is None:
                    break
                task_key = (row["security_code"], row["market"], row["trading_date"])
                attempts = int(row["attempts"]) + 1
                db.execute("UPDATE backfill_task SET status='running',attempts=?,lease_until=?,updated_at=? WHERE security_code=? AND market=? AND trading_date=?",
                           (attempts, lease_until, now, *task_key))
            security, market, day_text = task_key
            day = date.fromisoformat(day_text)
            try:
                session = next((item for item in self._calendar_sessions(market, day, day)
                                if item.trading_date == day), None)
                if session is None:
                    report = {"tradingDate": day_text, "result": "not-a-session", "source": None}
                else:
                    reports = self.archive.backfill(security, market, [session],
                                                    self.providers.get(market, ()), fetched_at=now_dt)
                    report = reports[0] if reports else {"tradingDate": day_text, "result": "unavailable"}
            except Exception as exc:
                report = {"tradingDate": day_text, "result": "unavailable",
                          "reason": type(exc).__name__ + ": " + str(exc)}
            complete = report.get("result") in {"complete", "already-covered", "not-a-session"}
            known_out_of_coverage = report.get("result") == "out_of_provider_coverage"
            terminal_failure = not complete and not known_out_of_coverage and attempts >= self.max_backfill_attempts
            delay = min(self.retry_max_seconds, self.retry_base_seconds * (2 ** min(attempts - 1, 12)))
            retry_at = self._stamp(now_dt + timedelta(seconds=delay))
            message = report.get("reason") or (None if complete else str(report.get("result", "incomplete")))
            if complete:
                status = "complete"
            elif known_out_of_coverage:
                status = "out_of_provider_coverage"
            elif terminal_failure and report.get("result") == "partial":
                status = "partial"
            elif terminal_failure:
                status = "permanent_unavailable"
            else:
                status = "retryable"
            with self._connect() as db:
                db.execute("""UPDATE backfill_task SET status=?,lease_until=NULL,
                    next_attempt_at=?,last_error=?,updated_at=?
                    WHERE security_code=? AND market=? AND trading_date=?""",
                    (status, retry_at, message, now,
                     *task_key))
            results.append({"securityCode": security, "market": market,
                            "tradingDate": day_text, "attempts": attempts,
                            "queueStatus": status,
                            "nextAttemptAt": retry_at if status == "retryable" else None,
                            "report": report})
        return results
