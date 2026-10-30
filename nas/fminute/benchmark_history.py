"""Persistent daily benchmark history for later cross-market Quant research."""
from __future__ import annotations
from dataclasses import dataclass
from datetime import date, datetime, timezone
import json
import math
import sqlite3
import threading
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class BenchmarkSpec:
    benchmark_id: str
    name: str
    ticker: str
    market: str
    timezone_name: str


BENCHMARKS = {row.benchmark_id: row for row in (
    BenchmarkSpec("shanghai_composite", "上证指数", "000001.SS", "CN", "Asia/Shanghai"),
    BenchmarkSpec("csi300", "沪深300", "000300.SS", "CN", "Asia/Shanghai"),
    BenchmarkSpec("csi_a500", "中证A500", "000510.SS", "CN", "Asia/Shanghai"),
    BenchmarkSpec("nasdaq100", "纳斯达克100", "^NDX", "US", "America/New_York"),
    BenchmarkSpec("sp500", "标普500", "^GSPC", "US", "America/New_York"),
    BenchmarkSpec("nikkei225", "日经225", "^N225", "JP", "Asia/Tokyo"),
    BenchmarkSpec("topix", "TOPIX", "^TOPX", "JP", "Asia/Tokyo"),
    BenchmarkSpec("kospi", "韩国综合指数", "^KS11", "KR", "Asia/Seoul"),
    BenchmarkSpec("hang_seng", "恒生指数", "^HSI", "HK", "Asia/Hong_Kong"),
    BenchmarkSpec("vix", "VIX", "^VIX", "US", "America/New_York"),
)}


class BenchmarkHistoryError(ValueError):
    pass


class YahooBenchmarkProvider:
    name = "Yahoo Finance chart (public best-effort)"

    def __init__(self, *, timeout_seconds: float = 12.0, clock=lambda: datetime.now(timezone.utc)):
        self.timeout_seconds, self.clock = timeout_seconds, clock

    def fetch(self, benchmark_id: str, *, period_days: int = 730) -> list[dict]:
        spec = BENCHMARKS.get(benchmark_id)
        if spec is None:
            raise BenchmarkHistoryError("unsupported benchmark")
        if type(period_days) is not int or not 1 <= period_days <= 3650:
            raise BenchmarkHistoryError("period_days must be between 1 and 3650")
        now = self.clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise BenchmarkHistoryError("clock must return an aware datetime")
        period2 = int(now.timestamp())
        url = (f"https://query1.finance.yahoo.com/v8/finance/chart/{quote(spec.ticker, safe='')}"
               f"?period1={period2-period_days*86400}&period2={period2}&interval=1d&events=history")
        request = Request(url, headers={"User-Agent": "GuanpanF/1.0 (daily benchmark history)"})
        with urlopen(request, timeout=self.timeout_seconds) as response:
            raw = response.read(4_000_001)
        if len(raw) > 4_000_000:
            raise BenchmarkHistoryError("provider response exceeds size limit")
        try:
            payload = json.loads(raw)
            result = payload["chart"]["result"][0]
            timestamps = result["timestamp"]
            values = result["indicators"]["quote"][0]
            closes, opens, highs, lows = (values[key] for key in ("close", "open", "high", "low"))
            volumes = values.get("volume") or [None] * len(timestamps)
            zone = ZoneInfo(result.get("meta", {}).get("exchangeTimezoneName") or spec.timezone_name)
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise BenchmarkHistoryError("provider returned an invalid chart payload") from exc
        fetched_at = now.astimezone(timezone.utc).isoformat()
        bars, seen = [], set()
        for index, epoch in enumerate(timestamps):
            try:
                source_timestamp = datetime.fromtimestamp(int(epoch), timezone.utc)
                if source_timestamp > now.astimezone(timezone.utc):
                    continue
                session_date = source_timestamp.astimezone(zone).date()
                # The provider may return an in-progress daily candle during
                # that exchange's session. Archive only completed local dates;
                # otherwise Regime would treat a live partial close as EOD data.
                if session_date >= now.astimezone(zone).date():
                    continue
                day = session_date.isoformat()
                prices = [opens[index], highs[index], lows[index], closes[index]]
                if any(v is None or not math.isfinite(float(v)) or float(v) <= 0 for v in prices):
                    continue
                volume = volumes[index]
                if volume is not None and (not math.isfinite(float(volume)) or float(volume) < 0):
                    continue
                if day in seen:
                    continue
                seen.add(day)
                bars.append({"benchmarkId": benchmark_id, "date": day,
                    "open": float(prices[0]), "high": float(prices[1]), "low": float(prices[2]),
                    "close": float(prices[3]), "volume": float(volume) if volume is not None else None,
                    "sourceTimestamp": source_timestamp.isoformat(),
                    "fetchedAt": fetched_at, "source": self.name})
            except (TypeError, ValueError, OverflowError):
                continue
        return sorted(bars, key=lambda row: row["date"])


class BenchmarkArchive:
    def __init__(self, path: str | Path):
        self.path = str(path)
        Path(self.path).parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            db.execute("""CREATE TABLE IF NOT EXISTS benchmark_daily (
                benchmark_id TEXT NOT NULL, trading_date TEXT NOT NULL,
                open REAL NOT NULL, high REAL NOT NULL, low REAL NOT NULL, close REAL NOT NULL,
                volume REAL, source_timestamp TEXT NOT NULL, fetched_at TEXT NOT NULL, source TEXT NOT NULL,
                PRIMARY KEY (benchmark_id,trading_date))""")

    def _connect(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        return db

    def ingest(self, rows: list[dict]) -> int:
        if not isinstance(rows, list):
            raise BenchmarkHistoryError("rows must be a list")
        validated = []
        for row in rows:
            try:
                benchmark_id = row["benchmarkId"]
                day = date.fromisoformat(row["date"]).isoformat()
                prices = [float(row[key]) for key in ("open", "high", "low", "close")]
                if benchmark_id not in BENCHMARKS or day != row["date"]:
                    raise ValueError("identity")
                if any(not math.isfinite(v) or v <= 0 for v in prices):
                    raise ValueError("price")
                if prices[1] < max(prices[0], prices[2], prices[3]) or prices[2] > min(prices[0], prices[1], prices[3]):
                    raise ValueError("ohlc")
                fetched = datetime.fromisoformat(row["fetchedAt"].replace("Z", "+00:00"))
                stamp = datetime.fromisoformat(row["sourceTimestamp"].replace("Z", "+00:00"))
                if (fetched.tzinfo is None or stamp.tzinfo is None or stamp > fetched or
                        stamp.astimezone(ZoneInfo(BENCHMARKS[benchmark_id].timezone_name)).date().isoformat() != day):
                    raise ValueError("timestamp")
                volume = row.get("volume")
                if volume is not None and (not math.isfinite(float(volume)) or float(volume) < 0):
                    raise ValueError("volume")
                source = row["source"]
                if not isinstance(source, str) or not source.strip():
                    raise ValueError("source")
                validated.append((benchmark_id, day, *prices, float(volume) if volume is not None else None,
                    stamp.isoformat(), fetched.isoformat(), source[:160]))
            except (KeyError, TypeError, ValueError, OverflowError) as exc:
                raise BenchmarkHistoryError("invalid benchmark daily row") from exc
        with self._connect() as db:
            db.executemany("""INSERT INTO benchmark_daily VALUES (?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(benchmark_id,trading_date) DO UPDATE SET
                open=excluded.open,high=excluded.high,low=excluded.low,close=excluded.close,
                volume=excluded.volume,source_timestamp=excluded.source_timestamp,
                fetched_at=excluded.fetched_at,source=excluded.source""", validated)
        return len(validated)

    def history(self, benchmark_id: str, start: date | None = None, end: date | None = None) -> dict:
        spec = BENCHMARKS.get(benchmark_id)
        if spec is None:
            raise BenchmarkHistoryError("unsupported benchmark")
        if ((start is not None and type(start) is not date) or (end is not None and type(end) is not date)
                or (start is not None and end is not None and end < start)):
            raise BenchmarkHistoryError("invalid date range")
        clauses, params = ["benchmark_id=?"], [benchmark_id]
        if start is not None:
            clauses.append("trading_date>=?")
            params.append(start.isoformat())
        if end is not None:
            clauses.append("trading_date<=?")
            params.append(end.isoformat())
        with self._connect() as db:
            rows = db.execute("SELECT * FROM benchmark_daily WHERE " + " AND ".join(clauses)
                              + " ORDER BY trading_date", params).fetchall()
        bars = [{"benchmarkId": row["benchmark_id"], "tradingDate": row["trading_date"],
                 "open": row["open"], "high": row["high"], "low": row["low"], "close": row["close"],
                 "volume": row["volume"], "sourceTimestamp": row["source_timestamp"],
                 "fetchedAt": row["fetched_at"], "source": row["source"]} for row in rows]
        return {"benchmarkId": spec.benchmark_id, "name": spec.name, "ticker": spec.ticker,
            "market": spec.market, "timezone": spec.timezone_name,
            "status": "available" if bars else "unavailable",
            "reason": None if bars else "history_not_archived_yet",
            "sampleCount": len(bars), "startDate": bars[0]["tradingDate"] if bars else None,
            "endDate": bars[-1]["tradingDate"] if bars else None, "bars": bars}


class BenchmarkHistoryWorker:
    """Background collector that never blocks minute API readiness."""
    def __init__(self, archive: BenchmarkArchive, provider: YahooBenchmarkProvider | None = None,
                 *, interval_seconds: int = 21600, period_days: int = 730):
        self.archive, self.provider = archive, provider or YahooBenchmarkProvider()
        self.interval_seconds, self.period_days = interval_seconds, period_days
        self._stop, self._thread = threading.Event(), None
        self.status = {"status": "not_started", "benchmarks": {}}

    def start(self):
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="f-benchmark-history", daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)

    def collect_once(self):
        outcomes = {}
        for benchmark_id in BENCHMARKS:
            if self._stop.is_set():
                break
            try:
                count = self.archive.ingest(self.provider.fetch(benchmark_id, period_days=self.period_days))
                outcomes[benchmark_id] = {"status": "ok" if count else "empty", "storedRows": count}
            except Exception as exc:
                outcomes[benchmark_id] = {"status": "unavailable",
                    "error": f"{type(exc).__name__}: {str(exc)[:160]}"}
        errors = sum(row["status"] == "unavailable" for row in outcomes.values())
        self.status = {"status": "degraded" if errors else ("ok" if outcomes else "idle"),
            "checkedAt": datetime.now(timezone.utc).isoformat(), "benchmarks": outcomes}
        return self.status

    def _run(self):
        while not self._stop.is_set():
            self.collect_once()
            self._stop.wait(self.interval_seconds)
