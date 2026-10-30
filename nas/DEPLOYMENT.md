# F Minute Archive NAS service

The F NAS image now includes a default runtime. You do not need to supply a Python plugin or provider API key for these public quote endpoints. This service has no API token/authentication: every client that can reach port 8788 can read its readiness, archived minute history, research/diagnostics and queue, and can enqueue backfill work. Restrict network reachability at the router/firewall or use a trusted private network; do not expose this port directly to the public internet. The Compose project name is fixed to the valid lowercase name `guanpan-f`; if the NAS UI asks for a project name, use that exact value.

## Connected sources

- **Realtime/current session:** Tencent Finance `minute/query`, adapted from the read-only B Frozen implementation. The parser rejects mismatched dates, malformed prices/volumes and future rows. Its current-session response is polled every minute. 09:30 opening-auction data is not stored as a regular minute bar.
- **Historical backfill:** Eastmoney `push2his` 1-minute K-line endpoint, queried for one exact finalized trading date. Returned rows are stored only for their stated date. The endpoint is unofficial and may limit historical coverage or be unavailable; an empty/failed response stays Missing and never creates bars. The current session is excluded from this provider to prevent mixing its volume semantics with Tencent realtime rows.
- **Calendar:** Mainland Shanghai/Shenzhen 2026 regular sessions use the published 2026 SSE/SZSE holiday notices and Asia/Shanghai timezone. The NAS calendar worker checks both exchanges on the first day of each month. It publishes a new year only when both official pages publish that year, strict parsing succeeds, and the closure dates match exactly. Publication is schema-versioned, SHA-256 checked, and atomic. Missing, malformed, changed, or mismatched pages leave the prior calendar untouched and the new year unsupported. From November onward, if next year's notice is still missing, or any current-year calendar is unsupported, it retries weekly so a late notice can be picked up promptly. The minute schedule excludes lunch and contains 240 regular minute closes.

Both market endpoints are public web interfaces without a user API key, but they are unofficial and can change. The runtime records provider/source timestamps and uses the existing quality gate. Current adapters are assigned conservative quality/trust scores; therefore archived rows do not automatically qualify for the stricter high-quality AI research threshold. B historical coverage status is not inherited by F.

## Deploy

1. Copy `.env.example` to `.env`.
2. Keep `F_MINUTE_DATA_DIR=./data` or set it to another persistent writable NAS directory. Set `F_MINUTE_SECURITIES` to the actual held and watched codes; the example list can be edited.
3. From the project root, check and start the service:

   ```sh
   docker compose --env-file nas/.env -f nas/compose.yml config
   docker compose --env-file nas/.env -f nas/compose.yml up -d --build
   ```

4. After startup, open `http://<NAS地址>:8788/` in a browser for the read-only status page. It displays `/readyz`, realtime/backfill worker state, and lets you query one security/trading date for actual archived bars and coverage diagnostics. The same-origin API routes remain available directly without a token. `/readyz` performs only a bounded SQLite schema/table metadata probe; it does not run a full-file integrity scan on every request. A process health response does not prove full database integrity, upstream freshness, or minute-data completeness. Inspect each requested date's Complete/Partial/Missing status and source timestamps; use the archive backup/restore verification path for a full integrity check.
5. Back up `/data` through the archive backup API and restore it to a separate directory before relying on NAS storage.

The process enqueues up to 120 supported recent sessions per configured security on startup, runs bounded backfill batches, and polls Tencent during the exchange's regular minute timestamps. The official calendar and its provenance are saved under `/data/official-calendar-v1.json`; backfill retry state and minute data are also on the persistent volume. `/readyz` reports calendar coverage, parse/update state, and the configured year range. Calendar HTTP failures cannot enable guessed trading sessions.

The image starts a small root-owned entrypoint only to prepare the mounted `/data` directory for UID 10001. It updates ownership on `/data` and any top-level existing item whose owner differs, then immediately drops privileges with `setpriv` from `util-linux` before starting Python. File contents are preserved. On NAS filesystems that reject `chown` (for example, some NFS root-squash mounts), use a writable local NAS directory or assign the directory and existing files to UID/GID 10001 before startup. Do not remove or recreate the data directory when rebuilding the image.

## Verification status

Local parser/adapter/calendar-sync tests use deterministic fixtures. In this cloud environment, a real Tencent request returned 13 current-session rows; after strict 09:30 handling, 12 rows aligned with the current calendar through the observed minute. Eastmoney historical HTTP request timed out here, so its real availability and historical coverage are External Verification Pending. Docker is unavailable here; image build, NAS deployment, port 8788, live SSE/SZSE page compatibility, monthly scheduler execution and backup/restore remain External Verification Pending. Do not report the service as production-verified until those checks run on the target NAS.

Official 2026 SSE/SZSE calendar notices:

- SSE: https://www.sse.com.cn/disclosure/announcement/general/c/c_20251222_10802507.shtml
- SZSE: https://www.szse.cn/disclosure/notice/general/t20251222_618087.html


## Daily benchmark history

The runtime creates `/data/benchmark-history.sqlite3` and starts a separate best-effort background collector for the Shanghai Composite, CSI 300, CSI A500, Nasdaq 100, S&P 500, Nikkei 225, TOPIX, KOSPI, Hang Seng, and VIX. It initially requests up to 730 calendar days and refreshes every six hours. This public Yahoo Finance chart endpoint is not an exchange contract; each instrument's errors are reported independently and do not make the minute service unready.

Read archived rows with `GET /api/v1/benchmark-history?benchmarkId=nasdaq100&startDate=2026-01-01&endDate=2026-10-30`. Supported IDs are `shanghai_composite`, `csi300`, `csi_a500`, `nasdaq100`, `sp500`, `nikkei225`, `topix`, `kospi`, `hang_seng`, and `vix`. An empty archive returns `status=unavailable`; it never generates missing dates. Rows include source timestamp, fetch time, and source label. Keep the existing persistent `/data` volume during image updates.
