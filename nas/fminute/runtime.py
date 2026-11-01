"""Default F NAS runtime: reviewed calendar, real upstreams and durable worker."""
from __future__ import annotations

import os
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from .archive import MinuteArchive
from .calendar import Mainland2026Calendar
from .calendar_sync import CalendarStore, OfficialCalendarSync
from .providers import EastmoneyMinuteHistoryProvider, TencentCurrentMinuteProvider
from .index_history import (IndexDailyHistoryArchive, MultiMarketDailyProvider,
                            NaverKospiDailyProvider, NikkeiDailyCloseProvider,
                            TencentIndexDailyProvider)
from .service import BackfillPriority, MinuteArchiveService, ServiceError

SHANGHAI = ZoneInfo("Asia/Shanghai")


def _error_summary(exc: Exception) -> str:
    message = " ".join(str(exc).split())[:240]
    return f"{type(exc).__name__}: {message}" if message else type(exc).__name__


def select_realtime_rows_for_session(bars, session, security_code: str):
    """Keep only official session timestamps; reject identity mismatches."""
    allowed = set(session.expected_timestamps)
    selected = []
    filtered_timestamps = []
    for bar in bars:
        if (bar.security_code != security_code or bar.market != session.market or
                bar.trading_date != session.trading_date):
            raise ServiceError("realtime provider returned a mismatched security, market, or date")
        if bar.timestamp in allowed:
            selected.append(bar)
        else:
            filtered_timestamps.append(bar.timestamp.isoformat())
    return tuple(selected), tuple(filtered_timestamps)


def calendar_sync_due(now: datetime, last_month: tuple[int, int] | None,
                      retry_at: datetime | None) -> bool:
    """Testable schedule gate: month day one, or a scheduled late-year retry."""
    month_key = (now.year, now.month)
    return (last_month is None or (now.day == 1 and month_key != last_month) or
            (retry_at is not None and now >= retry_at))


def summarize_backfill_cycle(results: list[dict], queue_depth: int) -> dict:
    """Report task outcomes, not just whether the worker loop raised an exception."""
    completed = [row for row in results if row.get("queueStatus") == "complete"]
    requeued = [row for row in results if row.get("queueStatus") in {"queued", "retryable"}]
    failed = [row for row in results if row.get("queueStatus") in {
        "permanent_unavailable", "out_of_provider_coverage", "partial", "missing"}]
    failures = []
    for row in [*requeued, *failed]:
        report = row.get("report") or {}
        failures.append({
            "securityCode": row.get("securityCode"),
            "tradingDate": row.get("tradingDate"),
            "attempts": row.get("attempts"),
            "queueStatus": row.get("queueStatus"),
            "reason": report.get("reason") or report.get("result") or "incomplete",
        })
    return {
        "status": "idle" if not results else ("degraded" if requeued or failed else "ok"),
        "processed": len(results),
        "completed": len(completed),
        "requeued": len(requeued),
        "failed": len(failed),
        "permanentUnavailable": sum(row.get("queueStatus") == "permanent_unavailable" for row in failed),
        "outOfProviderCoverage": sum(row.get("queueStatus") == "out_of_provider_coverage" for row in failed),
        "partial": sum(row.get("queueStatus") == "partial" for row in failed),
        "queueDepth": queue_depth,
        "lastFailures": failures[-3:],
    }


def _configured_securities() -> tuple[str, ...]:
    raw = os.environ.get("F_MINUTE_SECURITIES", "")
    values = tuple(item.strip() for item in raw.split(",") if item.strip())
    if not values:
        raise RuntimeError("F_MINUTE_SECURITIES must list real six-digit holdings/watchlist securities")
    if len(set(values)) != len(values) or any(len(code) != 6 or not code.isascii() or not code.isdigit()
                                               for code in values):
        raise RuntimeError("F_MINUTE_SECURITIES must contain unique six-digit codes")
    return values


class MinuteRuntimeWorker:
    """Backfill task runner plus one-minute polling of current real sessions."""

    def __init__(self, service: MinuteArchiveService, securities: tuple[str, ...],
                 *, calendar_sync: OfficialCalendarSync | None = None,
                 interval_seconds: int = 60):
        self.service, self.securities = service, securities
        self.calendar_sync = calendar_sync
        self.interval_seconds = interval_seconds
        self._stop = threading.Event()
        self._threads: list[threading.Thread] = []
        self.last_cycle: dict = {"status": "not_started"}
        self.last_backfill_cycle: dict = {"status": "not_started"}
        self.last_calendar_cycle: dict = {"status": "not_started"}
        self._started = False
        self._stopping = False

    def worker_snapshot(self, worker: str) -> dict:
        """Return the last cycle together with the actual thread lifecycle."""
        values = {
            "realtime": (self.last_cycle, "f-minute-realtime"),
            "backfill": (self.last_backfill_cycle, "f-minute-backfill"),
            "calendar": (self.last_calendar_cycle, "f-official-calendar-sync"),
        }
        cycle, thread_name = values[worker]
        thread = next((item for item in self._threads if item.name == thread_name), None)
        if worker == "calendar" and self.calendar_sync is None:
            return {"status": "not_configured", "workerState": "not_configured"}
        if thread is not None and thread.is_alive():
            state = "stopping" if self._stopping else "running"
        elif not self._started:
            state = "not_started"
        elif self._stopping:
            state = "stopped"
        else:
            state = "exited"
        return {**cycle, "workerState": state}

    def start(self) -> None:
        if any(thread.is_alive() for thread in self._threads):
            raise RuntimeError("minute runtime worker is already running or still stopping")
        self._stopping = False
        now = datetime.now(timezone.utc)
        startup_errors = []
        for code in self.securities:
            # Prime only the recent provider window. Older history remains
            # queryable as Missing and can be explicitly requested later.
            try:
                self.service.enqueue_initial_history(
                    code, "CN", through=now.astimezone(SHANGHAI).date(),
                    priority=BackfillPriority.HOLDING,
                    # Restarting the worker is not an explicit request to retry
                    # provider dates already classified as terminal.
                    requeue_terminal=False)
            except Exception as exc:
                startup_errors.append(type(exc).__name__)
        self.last_cycle = {"status": "degraded" if startup_errors else "starting",
                           "startupErrors": startup_errors}
        self._stop.clear()
        self._threads = [
            threading.Thread(target=self._run_realtime, name="f-minute-realtime", daemon=True),
            threading.Thread(target=self._run_backfill, name="f-minute-backfill", daemon=True),
        ]
        if self.calendar_sync is not None:
            self._threads.append(threading.Thread(target=self._run_calendar_sync,
                                                  name="f-official-calendar-sync", daemon=True))
        for thread in self._threads:
            thread.start()
        self._started = True

    def stop(self) -> None:
        self._stopping = True
        self._stop.set()
        for thread in self._threads:
            thread.join(timeout=5)

    def _run_backfill(self) -> None:
        while not self._stop.is_set():
            started = datetime.now(timezone.utc)
            try:
                results = self.service.run_backfill_batch(limit=3)
                self.last_backfill_cycle = {
                    **summarize_backfill_cycle(results, self.service.queue_count()),
                    "at": started.isoformat(),
                }
            except Exception as exc:
                self.last_backfill_cycle = {"status": "degraded", "at": started.isoformat(),
                                            "error": type(exc).__name__}
            self._stop.wait(5)

    def _run_calendar_sync(self) -> None:
        last_month = None
        retry_at = None
        while not self._stop.is_set():
            now = datetime.now(SHANGHAI)
            month_key = (now.year, now.month)
            due = calendar_sync_due(now, last_month, retry_at)
            if due:
                last_month = month_key
                try:
                    current = self.calendar_sync.sync_year(now.year)
                    next_year = self.calendar_sync.sync_year(now.year + 1)
                    self.last_calendar_cycle = {"status": "updated" if (current["status"] == "updated" or
                                                                            next_year["status"] == "updated")
                                                else "waiting_for_official_notice",
                                                "checkedAt": now.isoformat(),
                                                "currentYear": current, "nextYear": next_year}
                    retry_current = current["status"] != "updated"
                    retry_next_year = next_year["status"] != "updated" and now.month >= 11
                    needs_retry = retry_current or retry_next_year
                except Exception as exc:
                    self.last_calendar_cycle = {"status": "degraded", "checkedAt": now.isoformat(),
                                                "error": _error_summary(exc)}
                    needs_retry = True
                if needs_retry:
                    # Retry unsupported/current calendars weekly instead of
                    # waiting for the next month. Holiday notices commonly
                    # arrive late in the year.
                    retry_at = now + timedelta(days=7)
                else:
                    retry_at = None
            if retry_at is not None:
                seconds = max(60, min(3600, int((retry_at - datetime.now(SHANGHAI)).total_seconds())))
            else:
                seconds = 3600
            self._stop.wait(seconds)

    def _run_realtime(self) -> None:
        while not self._stop.is_set():
            started = datetime.now(timezone.utc)
            cycle_errors = []
            current_results = []
            local_now = started.astimezone(SHANGHAI)
            try:
                sessions = self.service._calendar_sessions("CN", local_now.date(), local_now.date())
                current_minute = local_now.replace(second=0, microsecond=0)
                if sessions and current_minute in sessions[0].expected_timestamps:
                    session = sessions[0]
                    provider = TencentCurrentMinuteProvider(clock=lambda: datetime.now(timezone.utc))
                    for code in self.securities:
                        try:
                            bars = provider.fetch(code, "CN", local_now.date())
                            scheduled, filtered = select_realtime_rows_for_session(bars, session, code)
                            if not scheduled:
                                raise ServiceError(
                                    f"provider returned no scheduled observations; filtered {len(filtered)} out-of-session rows")
                            results = self.service.ingest_realtime(scheduled)
                            for result in results:
                                result["filteredOutOfSessionCount"] = len(filtered)
                                result["sampleFilteredTimestamps"] = list(filtered[:3])
                            current_results.extend(results)
                        except Exception as exc:
                            detail = _error_summary(exc)
                            cycle_errors.append(f"realtime:{code}:{detail}")
                            current_results.append({"securityCode": code,
                                                    "errorType": type(exc).__name__,
                                                    "error": detail})
            except Exception as exc:
                # An unsupported calendar year is a recorded unavailable state,
                # not a weekday guess or synthetic session.
                detail = _error_summary(exc)
                cycle_errors.append("calendar:" + detail)
                current_results.append({"market": "CN", "errorType": type(exc).__name__,
                                        "error": detail})
            self.last_cycle = {"status": "degraded" if cycle_errors else "ok", "at": started.isoformat(),
                               "realtimeResults": current_results, "errors": cycle_errors}
            self._stop.wait(self.interval_seconds)


def build_service() -> MinuteArchiveService:
    data_dir = Path(os.environ.get("F_MINUTE_DATA_DIR", "/data")).resolve()
    data_dir.mkdir(parents=True, exist_ok=True)
    calendar_store = CalendarStore(data_dir / "official-calendar-v1.json")
    calendar = Mainland2026Calendar(calendar_store.path)
    calendar_sync = OfficialCalendarSync(calendar_store)
    # Eastmoney history is attempted first for old sessions; the Tencent source
    # is strictly current-session-only and cannot manufacture historical rows.
    service = MinuteArchiveService(
        MinuteArchive(data_dir / "minute-archive.sqlite3"),
        data_dir / "backfill-queue.sqlite3",
        {"CN": calendar},
        {"CN": (EastmoneyMinuteHistoryProvider(), TencentCurrentMinuteProvider())},
    )
    service.index_daily_history = IndexDailyHistoryArchive(
        data_dir / "index-daily-history.sqlite3",
        MultiMarketDailyProvider(TencentIndexDailyProvider(), NikkeiDailyCloseProvider(),
                                 NaverKospiDailyProvider()),
        cache_ttl=timedelta(hours=6))
    service.runtime_worker = MinuteRuntimeWorker(service, _configured_securities(),
                                                 calendar_sync=calendar_sync)
    return service
