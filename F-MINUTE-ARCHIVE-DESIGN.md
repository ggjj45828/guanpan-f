# F Historical Minute Archive and Research

Status: portable archive, bounded durable worker queue, exact-date service API, diagnostics and authenticated HTTP adapter are implemented; production NAS/calendar/provider/iOS integration remain External Verification Pending. B Frozen remains read-only.

## Arbitration

| Candidate | Frozen source evidence | Decision |
|---|---|---|
| A | `references/A-FROZEN/GuanpanNext/server/domain.py` has a timestamp-keyed `minute_archive`, write deduplication and date lookup; `server/app.py` exposes archived rows. `server/workers.py` collects current minute data. | Useful date-query and retention precedent; no verified historical backfill worker or session completeness/research pipeline. |
| B | `references/B-FROZEN/nas-advisor-compat/server/domain.py` adds provider/fetch provenance and first-observed records; `workers.py` collects current-session minutes; `mobile_research.py` quality-gates VWAP and window statistics. | Reuse ideas for immutable provenance, research-only output and fail-closed quality checks. Current worker is current-session collection; no verified broad historical backfill worker. |
| F | `nas/fminute/archive.py` introduces append-only observation history, a best-current projection, provider fallback backfill, exact-date query, session completeness, diagnostics, SQLite backup and point-in-time filtering. | **F Refactor**: build one calendar-aware, versioned minute archive and research contract; adapt only proven A/B rules. No direct A/B merge or copied service implementation. |

## Data and collection contract

The archive stores security code, market, market trading date, timestamp, price, source-minute or cumulative-delta volume provenance, cumulative volume where supplied, source, fetched-at, source timestamp, quality, trust, completeness and schema version. Timestamps are timezone-aware; a market calendar assigns a trading date. A database key includes security, market, trading date and timestamp. Revision observations are append-only; the `minute_bar` projection only promotes a better quality/trust/completeness observation or a newer equal-ranked observation. Lower-ranked backfill never erases a stronger live sample.

Realtime collection and historical backfill share the same validated ingest path and remain separately logged. Backfill receives explicit expected sessions, tries providers in priority order, can combine useful partial results, and records the actual time range/source and missing timestamps. Providers may return a shorter history; F records the available coverage and never expands it with synthetic points. There is no daily-volume-to-minute allocation path.

The core takes a market calendar's expected timestamps. Mainland normal sessions are expected to have the exchange's actual session points (typically 240 minute closes), while half-days, holidays and exceptional sessions come from the calendar. Lunch break is absent from the expected schedule, and an unexpected lunch observation is quality degradation. A session is complete only if all expected points exist, timestamps are inside the schedule, minute volume is present and continuous where cumulative volume exists, source quality/trust meet the selected threshold, and the capture is not from the future. Empty schedules are `not-a-session`, not `missing`.

## NAS and iOS contract to implement

- `GET /api/v1/minute-history?securityCode=159352&market=CN&tradingDate=2026-10-08`: return the exact session, status, source/coverage metadata, and ordered points. Never silently substitute today.
- `GET /api/v1/minute-history/diagnostics?securityCode=159352&market=CN`: return first/latest minute date, archived/complete/partial/missing trading-day counts, last live/backfill times, sources, coverage and database bytes.
- `POST /api/v1/minute-history/backfill`: accept a bounded date range and explicit holding/watchlist/AI-research/benchmark priority; tasks persist in SQLite, skip already complete sessions, retry incomplete/failed sessions with bounded backoff, and reclaim expired worker leases.
- `GET /api/v1/minute-history/backfill-queue`: expose queued task state for operations. All HTTP routes require a host-provided authorization callback; this module does not bind a port or ship an API credential.
- Initial deployment, real holding/watchlist additions and detected gaps enqueue bounded backfill, prioritizing holdings, then watchlists, AI-research instruments, then benchmark series. Default target is 60–120 sessions when providers support it. Provider limits and actual first/last dates are surfaced.
- iOS uses one chart dataset/model for live and historical dates. Date selection requests an exact NAS session; prior/next controls follow the exchange calendar. Historical charts suppress current cost/real-time overlays unless their historical value and timestamp are available. No history means an explicit unavailable state.
- Market-local calendars and IANA zones normalize instants before cross-market lead/lag analysis. Date strings are not used to align markets.

## Research and look-ahead boundary

The phone does not receive bulk minute archives. NAS computes bounded, auditable Research Evidence (sample/session counts, completeness, sources, window, as-of, statistics and limitations), and DecisionContext carries only this compact evidence. VWAP, T candidates, grid spacing, pattern frequencies and cross-market effects fail closed without their declared high-quality session coverage, independent-day count and out-of-sample requirements. Insufficient evidence is reported as such.

`query_day(..., available_as_of=...)` selects only observation versions fetched by the cutoff whose source timestamp is not after it. Later backfill cannot be presented as data the system had at an earlier decision. If historical point-in-time availability cannot be established, replay is unavailable rather than guessed. Post-cutoff observations may serve as outcomes only.

## Storage and operations

SQLite WAL + full synchronous mode provides a portable starting point with indexes by instrument/session/time, by as-of fetch time, and collection-log instrument/mode/fetch-time diagnostics. `PRAGMA integrity_check` and SQLite's online backup API are implemented and exercised. Schema version is stored; unknown future versions fail closed. Diagnostics report archive/WAL/shared-memory footprint plus filesystem total/used/free bytes when the host can provide them; these are observations only and never trigger cleanup. No automatic pruning exists. Default retention is indefinite; if capacity policy is later enabled, held/watchlisted instruments are protected, annual closed partitions may be compressed, and every archive/backup needs hash and restore verification. Actual NAS capacity, filesystem durability, backup rotation, compression and restore drills remain pending. The portable service now defines the calendar/provider protocols, bounded durable queue, worker batch runner and authenticated HTTP handler. The real NAS host must supply its exchange calendar, provider registration, periodic worker scheduling, route/server mounting, access control policy and production monitoring.

## Current code and verification boundary

`nas/fminute/archive.py` provides schema v1, normalized point ingestion, revision history, quality-preserving upsert, calendar-based completeness, exact-day and point-in-time queries, provider fallback, diagnostics, backup and integrity checks. `nas/fminute/research.py` emits compact VWAP-cross outcomes, morning selloff/afternoon recovery statistics and close-only grid-spacing replay. All require complete, high-quality sessions, use independent trading days and an explicit research cutoff; grid replay avoids inferring intraminute ordering and subtracts bilateral fees. Every output is evidence only and has no trade plan. `Tools/test_minute_archive.py` has 40 archive/research tests and `Tools/test_minute_service.py` has 26 service/HTTP/evidence-contract tests; all 66 local synthetic-fixture tests pass in this environment. Synthetic data is used only as a test fixture and does not claim that any real market data has been captured. NAS host integration, real calendar/source coverage and production HTTP deployment remain External Verification Pending.
