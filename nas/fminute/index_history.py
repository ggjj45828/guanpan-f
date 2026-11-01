"""Durable NAS archive for completed daily index bars used by Market Regime."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from threading import Lock
from typing import Protocol
from contextlib import closing
import csv
import ast
from io import StringIO
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo
import re
import json
import sqlite3

from .http_limits import read_bounded_body


INDEX_TIMEZONES = {
    "sh000001": "Asia/Shanghai",
    "sz399001": "Asia/Shanghai",
    "sh000300": "Asia/Shanghai",
    "sh000510": "Asia/Shanghai",
    "sz399006": "Asia/Shanghai",
    "usNDX": "America/New_York",
    "hkHSI": "Asia/Hong_Kong",
    "int_nikkei": "Asia/Tokyo",
    "KOSPI": "Asia/Seoul",
}
TENCENT_INDEX_CODES = frozenset(INDEX_TIMEZONES) - {"int_nikkei", "KOSPI"}
SECURITY_CODE = re.compile(r"^[5690123][0-9]{5}$")
SOURCE = "Tencent Finance daily K-line (archived by F NAS)"
NAVER_KOSPI_SOURCE = "Naver Finance KOSPI daily chart (public web endpoint)"
USER_AGENT = "GuanpanF-IndexHistory/1"
MAX_DAILY_BAR_AGE = timedelta(days=5)


@dataclass(frozen=True)
class IndexDailyBar:
    trading_date: date
    open: str | None
    close: str
    high: str | None
    low: str | None
    volume: str | None

    def validate(self) -> None:
        if type(self.trading_date) is not date:
            raise ValueError("index daily trading date must be a date")
        try:
            close = Decimal(self.close)
            optional = (self.open, self.high, self.low, self.volume)
            if any(value is not None for value in optional) and any(value is None for value in optional):
                raise ValueError("OHLCV must be complete or absent")
            if all(value is not None for value in optional):
                opening, high, low, volume = (Decimal(value) for value in optional)
            else:
                opening = high = low = volume = None
        except (InvalidOperation, TypeError, ValueError) as exc:
            raise ValueError("index daily bar contains invalid numbers") from exc
        values = [close] + ([opening, high, low, volume] if opening is not None else [])
        if (not all(value.is_finite() for value in values) or close <= 0 or
                (opening is not None and (low <= 0 or volume < 0 or high < max(opening, close) or
                                          low > min(opening, close) or high < low))):
            raise ValueError("index daily OHLCV values are inconsistent")


class IndexDailyProvider(Protocol):
    name: str

    def fetch(self, index_code: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]: ...


class TencentIndexDailyProvider:
    """Fetches only an allowlisted index symbol; current partial sessions are discarded."""

    name = SOURCE

    def __init__(self, *, timeout: float = 12.0, opener=urlopen):
        self.timeout, self.opener = timeout, opener

    def fetch(self, index_code: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if index_code not in TENCENT_INDEX_CODES and not SECURITY_CODE.fullmatch(index_code):
            raise ValueError("unsupported index or security code")
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("index fetch time must be timezone-aware")
        symbol = index_code
        if SECURITY_CODE.fullmatch(index_code):
            symbol = ("sh" if index_code[0] in "569" else "sz") + index_code
        query = urlencode({"param": f"{symbol},day,,,300,"})
        request = Request("https://web.ifzq.gtimg.cn/appstock/app/fqkline/get?" + query,
                          headers={"Referer": "https://gu.qq.com/", "User-Agent": USER_AGENT,
                                   "Accept": "application/json"})
        with self.opener(request, timeout=self.timeout) as response:
            if response.status != 200:
                raise OSError("Tencent index daily source unavailable")
            body = read_bounded_body(response, 4_000_000, source="Tencent index daily").decode(
                "utf-8", "strict")
        return self.parse(body, index_code, fetched_at=fetched_at)

    @staticmethod
    def parse(body: str, index_code: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if index_code not in TENCENT_INDEX_CODES and not SECURITY_CODE.fullmatch(index_code):
            raise ValueError("unsupported index or security code")
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("index fetch time must be timezone-aware")
        start, end = body.find("{"), body.rfind("}")
        if start < 0 or end < start:
            raise ValueError("invalid Tencent index daily response")
        payload = json.loads(body[start:end + 1])
        symbol = index_code
        if SECURITY_CODE.fullmatch(index_code):
            symbol = ("sh" if index_code[0] in "569" else "sz") + index_code
        rows = (payload.get("data", {}).get(symbol, {}).get("day") or [])
        if not isinstance(rows, list) or not rows:
            raise ValueError("Tencent returned no index daily rows")
        zone = ZoneInfo(INDEX_TIMEZONES.get(index_code, "Asia/Shanghai"))
        current_local_date = fetched_at.astimezone(zone).date()
        bars: dict[date, IndexDailyBar] = {}
        for row in rows:
            if not isinstance(row, list) or len(row) < 6 or not isinstance(row[0], str):
                raise ValueError("Tencent index daily row has an invalid shape")
            try:
                trading_date = date.fromisoformat(row[0])
                if trading_date.isoformat() != row[0]:
                    raise ValueError("index date is not canonical")
                if trading_date >= current_local_date:
                    continue
                bar = IndexDailyBar(trading_date, *(str(value) for value in row[1:6]))
                bar.validate()
            except (TypeError, ValueError) as exc:
                raise ValueError("Tencent index daily row failed validation") from exc
            if trading_date in bars:
                raise ValueError("Tencent returned duplicate index trading dates")
            bars[trading_date] = bar
        result = tuple(bars[key] for key in sorted(bars))
        if not result:
            raise ValueError("Tencent returned no completed index sessions")
        return result


class NikkeiDailyCloseProvider:
    """Official Nikkei daily close CSV; personal-use source, not OHLCV."""

    name = "Nikkei Indexes official daily close CSV (personal use)"
    url = "https://indexes.nikkei.co.jp/nkave/historical/nikkei_stock_average_daily_en.csv"

    def __init__(self, *, timeout: float = 20.0, opener=urlopen):
        self.timeout, self.opener = timeout, opener

    def fetch(self, index_code: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if index_code != "int_nikkei":
            raise ValueError("unsupported Nikkei index")
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("index fetch time must be timezone-aware")
        request = Request(self.url, headers={"User-Agent": USER_AGENT, "Accept": "text/csv"})
        with self.opener(request, timeout=self.timeout) as response:
            if response.status != 200:
                raise OSError("Nikkei daily history source unavailable")
            body = read_bounded_body(response, 2_000_000, source="Nikkei daily CSV").decode(
                "utf-8-sig", "strict")
        return self.parse(body, fetched_at=fetched_at)

    @staticmethod
    def parse(body: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("index fetch time must be timezone-aware")
        reader = csv.DictReader(StringIO(body))
        if not reader.fieldnames:
            raise ValueError("Nikkei CSV has no header")
        fields = {name.strip().lower(): name for name in reader.fieldnames if name}
        date_field, close_field = fields.get("date"), fields.get("close")
        if date_field is None or close_field is None:
            raise ValueError("Nikkei CSV does not contain Date and Close fields")
        current_day = fetched_at.astimezone(ZoneInfo(INDEX_TIMEZONES["int_nikkei"])).date()
        bars: dict[date, IndexDailyBar] = {}
        for row in reader:
            raw_date = (row.get(date_field) or "").strip()
            try:
                trading_date = date.fromisoformat(raw_date)
                if trading_date.isoformat() != raw_date:
                    continue
            except ValueError:
                try:
                    trading_date = datetime.strptime(raw_date, "%Y/%m/%d").date()
                    if trading_date.strftime("%Y/%m/%d") != raw_date:
                        continue
                except ValueError:
                    continue
            if trading_date >= current_day:
                continue
            raw_close = (row.get(close_field) or "").strip()
            if not raw_close or raw_close in {".", "-", "N/A"}:
                continue
            if not re.fullmatch(r"(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?", raw_close):
                raise ValueError(f"Nikkei CSV contains malformed close value for {trading_date}")
            bar = IndexDailyBar(trading_date=trading_date, open=None, close=raw_close.replace(",", ""),
                                high=None, low=None, volume=None)
            try:
                bar.validate()
            except ValueError as exc:
                raise ValueError(f"Nikkei CSV contains invalid close value for {trading_date}") from exc
            if trading_date in bars:
                raise ValueError("Nikkei CSV contains duplicate trading dates")
            bars[trading_date] = bar
        result = tuple(bars[key] for key in sorted(bars))
        if not result:
            raise ValueError("Nikkei CSV contains no completed daily closes")
        return result


class NaverKospiDailyProvider:
    """Fetches the KOSPI daily chart from Naver Finance's public chart endpoint."""

    name = NAVER_KOSPI_SOURCE
    url = "https://api.finance.naver.com/siseJson.naver"
    _number = re.compile(r"^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$")

    def __init__(self, *, timeout: float = 12.0, opener=urlopen):
        self.timeout, self.opener = timeout, opener

    def fetch(self, index_code: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if index_code != "KOSPI":
            raise ValueError("unsupported Naver index")
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("index fetch time must be timezone-aware")
        query = urlencode({"symbol": "KOSPI", "requestType": "0",
                           "count": "500", "timeframe": "day"})
        request = Request(self.url + "?" + query,
                          headers={"Referer": "https://finance.naver.com/",
                                   "User-Agent": USER_AGENT,
                                   "Accept": "text/plain, application/json"})
        with self.opener(request, timeout=self.timeout) as response:
            if response.status != 200:
                raise OSError("Naver KOSPI daily source unavailable")
            body = read_bounded_body(response, 1_000_000, source="Naver KOSPI daily").decode(
                "utf-8", "strict")
        return self.parse(body, fetched_at=fetched_at)

    @classmethod
    def parse(cls, body: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("index fetch time must be timezone-aware")
        try:
            rows = ast.literal_eval(body.strip())
        except (SyntaxError, ValueError, TypeError) as exc:
            raise ValueError("invalid Naver KOSPI daily response") from exc
        if (not isinstance(rows, list) or len(rows) < 2 or
                not isinstance(rows[0], list) or
                [str(value).strip() for value in rows[0][:6]] !=
                ["날짜", "시가", "고가", "저가", "종가", "거래량"]):
            raise ValueError("Naver KOSPI daily response has an unexpected header")
        current_day = fetched_at.astimezone(ZoneInfo(INDEX_TIMEZONES["KOSPI"])).date()

        def number(value: object) -> str:
            if not isinstance(value, (str, int)) or isinstance(value, bool):
                raise ValueError("Naver KOSPI daily field is not a numeric string")
            raw = str(value).strip()
            if not cls._number.fullmatch(raw):
                raise ValueError("Naver KOSPI daily field has an invalid numeric format")
            return raw.replace(",", "")

        bars: dict[date, IndexDailyBar] = {}
        for row in rows[1:]:
            if not isinstance(row, list) or len(row) < 6:
                raise ValueError("Naver KOSPI daily row has an invalid shape")
            raw_day = row[0]
            if isinstance(raw_day, int) and not isinstance(raw_day, bool):
                raw_day = str(raw_day)
            if not isinstance(raw_day, str):
                raise ValueError("Naver KOSPI daily date is invalid")
            try:
                date_format = "%Y%m%d" if re.fullmatch(r"[0-9]{8}", raw_day) else "%Y.%m.%d"
                trading_date = datetime.strptime(raw_day, date_format).date()
                if trading_date.strftime(date_format) != raw_day:
                    raise ValueError("noncanonical Naver KOSPI date")
            except ValueError as exc:
                raise ValueError("Naver KOSPI daily date is invalid") from exc
            if trading_date >= current_day:
                continue
            bar = IndexDailyBar(trading_date=trading_date, open=number(row[1]),
                                high=number(row[2]), low=number(row[3]),
                                close=number(row[4]), volume=number(row[5]))
            try:
                bar.validate()
            except ValueError as exc:
                raise ValueError(f"Naver KOSPI bar failed validation for {trading_date}") from exc
            if trading_date in bars:
                raise ValueError("Naver returned duplicate KOSPI trading dates")
            bars[trading_date] = bar
        result = tuple(bars[key] for key in sorted(bars))
        if not result:
            raise ValueError("Naver returned no completed KOSPI sessions")
        return result


class MultiMarketDailyProvider:
    """Routes only explicit index identities to their verified source."""

    def __init__(self, tencent: IndexDailyProvider, nikkei: IndexDailyProvider,
                 naver: IndexDailyProvider):
        self.tencent, self.nikkei, self.naver = tencent, nikkei, naver

    @property
    def name(self) -> str:
        return "F NAS multi-market daily archive"

    def source_name(self, index_code: str) -> str:
        if index_code == "int_nikkei":
            return self.nikkei.name
        if index_code == "KOSPI":
            return self.naver.name
        return self.tencent.name

    def fetch(self, index_code: str, *, fetched_at: datetime) -> tuple[IndexDailyBar, ...]:
        if index_code == "int_nikkei":
            return self.nikkei.fetch(index_code, fetched_at=fetched_at)
        if index_code == "KOSPI":
            return self.naver.fetch(index_code, fetched_at=fetched_at)
        if index_code in INDEX_TIMEZONES and index_code != "int_nikkei":
            if index_code in TENCENT_INDEX_CODES:
                return self.tencent.fetch(index_code, fetched_at=fetched_at)
        if SECURITY_CODE.fullmatch(index_code):
            return self.tencent.fetch(index_code, fetched_at=fetched_at)
        raise ValueError("unsupported index or security code")


class IndexDailyHistoryArchive:
    """Caches real index bars durably and reports stale/insufficient data explicitly."""

    def __init__(self, path: Path | str, provider: IndexDailyProvider, *,
                 clock=lambda: datetime.now(timezone.utc),
                 cache_ttl: timedelta = timedelta(minutes=15)):
        if not isinstance(cache_ttl, timedelta) or cache_ttl.total_seconds() < 0:
            raise ValueError("index cache TTL must be nonnegative")
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.provider, self.clock, self.cache_ttl = provider, clock, cache_ttl
        self._locks_guard = Lock()
        self._code_locks: dict[str, Lock] = {}
        with closing(self._connect()) as db:
            db.executescript("""
                PRAGMA journal_mode=WAL;
                PRAGMA synchronous=FULL;
                CREATE TABLE IF NOT EXISTS index_daily_bar (
                    index_code TEXT NOT NULL, trading_date TEXT NOT NULL,
                    open TEXT, close TEXT NOT NULL, high TEXT,
                    low TEXT, volume TEXT, source TEXT NOT NULL,
                    fetched_at TEXT NOT NULL,
                    PRIMARY KEY(index_code, trading_date)
                );
                CREATE TABLE IF NOT EXISTS index_daily_meta (
                    index_code TEXT PRIMARY KEY, last_fetched_at TEXT NOT NULL,
                    last_error TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_index_daily_date
                    ON index_daily_bar(index_code, trading_date);
            """)
            self._migrate_nullable_ohlcv(db)

    @staticmethod
    def _migrate_nullable_ohlcv(db: sqlite3.Connection) -> None:
        columns = {row[1]: row for row in db.execute("PRAGMA table_info(index_daily_bar)")}
        if not columns or not any(columns[name][3] for name in ("open", "high", "low", "volume")):
            return
        with db:
            db.execute("""CREATE TABLE index_daily_bar_v2 (
                index_code TEXT NOT NULL, trading_date TEXT NOT NULL,
                open TEXT, close TEXT NOT NULL, high TEXT, low TEXT, volume TEXT,
                source TEXT NOT NULL, fetched_at TEXT NOT NULL,
                PRIMARY KEY(index_code, trading_date))""")
            db.execute("""INSERT INTO index_daily_bar_v2
                (index_code,trading_date,open,close,high,low,volume,source,fetched_at)
                SELECT index_code,trading_date,open,close,high,low,volume,source,fetched_at
                FROM index_daily_bar""")
            db.execute("DROP TABLE index_daily_bar")
            db.execute("ALTER TABLE index_daily_bar_v2 RENAME TO index_daily_bar")
            db.execute("CREATE INDEX idx_index_daily_date ON index_daily_bar(index_code, trading_date)")

    def _connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        return db

    def _code_lock(self, index_code: str) -> Lock:
        with self._locks_guard:
            return self._code_locks.setdefault(index_code, Lock())

    @staticmethod
    def _latest_bar_fresh(index_code: str, rows, now: datetime) -> bool:
        if not rows or now.tzinfo is None or now.utcoffset() is None:
            return False
        try:
            raw_date = rows[-1]["trading_date"]
            latest = date.fromisoformat(raw_date)
            if latest.isoformat() != raw_date:
                return False
            local_today = now.astimezone(ZoneInfo(INDEX_TIMEZONES.get(index_code, "Asia/Shanghai"))).date()
            age = local_today - latest
        except (KeyError, TypeError, ValueError):
            return False
        return timedelta(0) <= age <= MAX_DAILY_BAR_AGE

    def _stale_reason(self, index_code: str, rows, now: datetime,
                      fetched: datetime | None, fetch_age_seconds: int | None) -> str | None:
        if not rows:
            return None
        if fetched is None or fetch_age_seconds is None:
            return "归档缺少有效采集时间"
        if fetch_age_seconds < 0:
            return "归档时间在未来，时钟或数据异常"
        if fetch_age_seconds > 36 * 60 * 60:
            return "归档超过36小时未更新"
        if not self._latest_bar_fresh(index_code, rows, now):
            return "最近完整交易日数据超过5个自然日"
        return None

    @staticmethod
    def _stamp(value: datetime) -> str:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("index timestamps must be timezone-aware")
        return value.astimezone(timezone.utc).isoformat(timespec="seconds")

    def get_history(self, index_code: str) -> dict:
        if index_code not in INDEX_TIMEZONES and not SECURITY_CODE.fullmatch(index_code):
            raise ValueError("unsupported index or security code")
        now = self.clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise ValueError("index archive clock must be timezone-aware")
        with self._code_lock(index_code):
            cached = self._read(index_code)
            fetched_at = self._parse_fetch_time(cached["fetchedAt"])
            if fetched_at is not None:
                age = now - fetched_at
                # A clock correction or corrupt persisted timestamp must never
                # make a future fetch look fresh indefinitely.
                if timedelta(0) <= age <= self.cache_ttl:
                    return self._response(index_code, cached, now)
            try:
                bars = self.provider.fetch(index_code, fetched_at=now)
                if (not bars or any(not isinstance(bar, IndexDailyBar) for bar in bars) or
                        tuple(sorted(bars, key=lambda item: item.trading_date)) != bars or
                        len({item.trading_date for item in bars}) != len(bars)):
                    raise ValueError("index provider returned invalid history ordering")
                for bar in bars:
                    bar.validate()
                    if bar.trading_date >= now.astimezone(ZoneInfo(
                            INDEX_TIMEZONES.get(index_code, "Asia/Shanghai"))).date():
                        raise ValueError("index provider returned an incomplete current session")
                self._write(index_code, bars, now)
                cached = self._read(index_code)
                return self._response(index_code, cached, now)
            except Exception as exc:
                self._record_error(index_code, str(exc), now)
                cached = self._read(index_code)
                result = self._response(index_code, cached, now)
                if result["bars"]:
                    result["status"] = "stale"
                else:
                    result["status"] = "unavailable"
                result["unavailableReason"] = "历史日K源不可用：" + (str(exc) or type(exc).__name__)
                return result

    def status(self) -> dict:
        now = self.clock()
        indexes = {}
        # Readiness polls must not wait behind a writer for the normal archive
        # timeout or load OHLCV payloads. Use one short, read-only connection
        # and fetch only the latest bounded date window for each known index.
        uri = self.path.resolve().as_uri() + "?mode=ro"
        with closing(sqlite3.connect(uri, uri=True, timeout=1)) as db:
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA query_only=ON")
            index_codes = tuple(INDEX_TIMEZONES)
            placeholders = ",".join("?" for _ in index_codes)
            metadata = {row["index_code"]: row for row in db.execute(
                "SELECT index_code,last_fetched_at,last_error FROM index_daily_meta "
                f"WHERE index_code IN ({placeholders})", index_codes)}
            for index_code in INDEX_TIMEZONES:
                rows = db.execute("""SELECT trading_date FROM index_daily_bar
                    WHERE index_code=? ORDER BY trading_date DESC LIMIT 500""",
                                  (index_code,)).fetchall()
                rows.reverse()
                meta = metadata.get(index_code)
                fetched = self._parse_fetch_time(meta["last_fetched_at"] if meta else None)
                last_error = meta["last_error"] if meta else None
                age_delta = now - fetched if fetched else None
                age = int(age_delta.total_seconds()) if age_delta is not None else None
                latest_bar_fresh = self._latest_bar_fresh(index_code, rows, now)
                state = ("not_collected" if not rows else
                         ("stale" if fetched is None or age is None or age < 0 or age > 36 * 60 * 60 or
                          not latest_bar_fresh else
                          ("available" if len(rows) >= 60 else "insufficient")))
                indexes[index_code] = {
                    "status": state,
                    "sampleCount": len(rows),
                    "dataRange": {"start": rows[0]["trading_date"] if rows else None,
                                  "end": rows[-1]["trading_date"] if rows else None},
                    "fetchedAt": fetched.isoformat() if fetched else None,
                    "cacheAgeSeconds": age,
                    "lastError": last_error,
                    "unavailableReason": self._stale_reason(index_code, rows, now, fetched, age)
                        if state == "stale" else None,
                }
        return {"status": "observed", "indexes": indexes}

    def security_status(self) -> dict:
        now = self.clock()
        with closing(self._connect()) as db:
            codes = [row[0] for row in db.execute(
                "SELECT DISTINCT index_code FROM index_daily_bar ORDER BY index_code")
                if SECURITY_CODE.fullmatch(row[0])]
        securities = {}
        for code in codes:
            cached = self._read(code)
            rows = cached["rows"]
            fetched = self._parse_fetch_time(cached["fetchedAt"])
            age_delta = now - fetched if fetched else None
            age = int(age_delta.total_seconds()) if age_delta is not None else None
            latest_bar_fresh = self._latest_bar_fresh(code, rows, now)
            state = ("not_collected" if not rows else
                     ("stale" if fetched is None or age is None or age < 0 or age > 36 * 60 * 60 or
                      not latest_bar_fresh else
                      ("available" if len(rows) >= 60 else "insufficient")))
            securities[code] = {
                "status": state, "sampleCount": len(rows),
                "dataRange": {"start": rows[0]["trading_date"] if rows else None,
                              "end": rows[-1]["trading_date"] if rows else None},
                "fetchedAt": fetched.isoformat() if fetched else None,
                "cacheAgeSeconds": age, "lastError": cached["lastError"],
                "unavailableReason": self._stale_reason(code, rows, now, fetched, age)
                    if state == "stale" else None,
            }
        return {"status": "observed", "securities": securities}

    def get_security_history(self, security_code: str) -> dict:
        if not SECURITY_CODE.fullmatch(security_code):
            raise ValueError("unsupported security code")
        result = self.get_history(security_code)
        return {"securityCode": security_code, "timezone": "Asia/Shanghai",
                "status": result["status"], "source": result["source"],
                "fetchedAt": result["fetchedAt"], "cacheAgeSeconds": result["cacheAgeSeconds"],
                "dataRange": result["dataRange"], "sampleCount": result["sampleCount"],
                "adjustment": "不复权", "bars": result["bars"],
                "unavailableReason": result["unavailableReason"]}

    def _read(self, index_code: str) -> dict:
        with closing(self._connect()) as db:
            meta = db.execute("SELECT * FROM index_daily_meta WHERE index_code=?", (index_code,)).fetchone()
            rows = db.execute("""SELECT * FROM index_daily_bar WHERE index_code=?
                ORDER BY trading_date DESC LIMIT 500""", (index_code,)).fetchall()
        rows = list(reversed(rows))
        fetched_at = meta["last_fetched_at"] if meta else None
        return {"fetchedAt": fetched_at if fetched_at else None,
                "lastError": meta["last_error"] if meta else None, "rows": rows}

    def _write(self, index_code: str, bars: tuple[IndexDailyBar, ...], fetched_at: datetime) -> None:
        stamp = self._stamp(fetched_at)
        source = getattr(self.provider, "source_name", lambda _code: self.provider.name)(index_code)
        dates = {bar.trading_date.isoformat() for bar in bars}
        first_date, last_date = min(dates), max(dates)
        with closing(self._connect()) as db:
            with db:
                existing_dates = db.execute("""SELECT trading_date FROM index_daily_bar
                    WHERE index_code=? AND trading_date BETWEEN ? AND ?""",
                    (index_code, first_date, last_date)).fetchall()
                removed = [(index_code, row["trading_date"]) for row in existing_dates
                           if row["trading_date"] not in dates]
                if removed:
                    db.executemany("DELETE FROM index_daily_bar WHERE index_code=? AND trading_date=?",
                                   removed)
                for bar in bars:
                    db.execute("""INSERT INTO index_daily_bar
                        (index_code,trading_date,open,close,high,low,volume,source,fetched_at)
                        VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(index_code,trading_date) DO UPDATE SET
                        open=excluded.open,close=excluded.close,high=excluded.high,low=excluded.low,
                        volume=excluded.volume,source=excluded.source,fetched_at=excluded.fetched_at""",
                        (index_code, bar.trading_date.isoformat(), bar.open, bar.close,
                         bar.high, bar.low, bar.volume, source, stamp))
                db.execute("""INSERT INTO index_daily_meta(index_code,last_fetched_at,last_error)
                    VALUES(?,?,NULL) ON CONFLICT(index_code) DO UPDATE SET
                    last_fetched_at=excluded.last_fetched_at,last_error=NULL""", (index_code, stamp))

    def _record_error(self, index_code: str, error: str, now: datetime) -> None:
        with closing(self._connect()) as db:
            with db:
                old = db.execute("SELECT last_fetched_at FROM index_daily_meta WHERE index_code=?",
                                 (index_code,)).fetchone()
                # An error is not a successful fetch. If no successful-fetch time
                # exists, preserve that absence instead of inventing a fresh one.
                last_fetched = (old["last_fetched_at"] or "") if old else ""
                db.execute("""INSERT INTO index_daily_meta(index_code,last_fetched_at,last_error)
                    VALUES(?,?,?) ON CONFLICT(index_code) DO UPDATE SET last_error=excluded.last_error""",
                    (index_code, last_fetched, error[:300]))

    def _response(self, index_code: str, cached: dict, now: datetime) -> dict:
        rows = cached["rows"]
        fetched = IndexDailyHistoryArchive._parse_fetch_time(cached["fetchedAt"])
        age = int((now - fetched).total_seconds()) if fetched else None
        latest_bar_fresh = self._latest_bar_fresh(index_code, rows, now)
        status = ("stale" if fetched is None or age is None or age < 0 or age > 36 * 60 * 60 or
                  not latest_bar_fresh else
                  ("available" if len(rows) >= 60 else "insufficient"))
        stale_reason = self._stale_reason(index_code, rows, now, fetched, age)
        bars = [{"tradingDate": row["trading_date"], "open": row["open"],
                 "close": row["close"], "high": row["high"], "low": row["low"],
                 "volume": row["volume"], "source": row["source"]} for row in rows]
        fallback_source = getattr(self.provider, "source_name",
                                  lambda _code: self.provider.name)(index_code)
        return {"indexCode": index_code, "timezone": INDEX_TIMEZONES.get(index_code, "Asia/Shanghai"),
                "status": status, "source": rows[-1]["source"] if rows else fallback_source,
                "fetchedAt": fetched.isoformat() if fetched else None,
                "cacheAgeSeconds": age, "dataRange": {
                    "start": rows[0]["trading_date"] if rows else None,
                    "end": rows[-1]["trading_date"] if rows else None,
                }, "sampleCount": len(rows), "bars": bars,
                "unavailableReason": (cached["lastError"] if cached["lastError"] else
                    ("历史数据少于60个有效交易日" if status == "insufficient" else
                    (stale_reason if status == "stale" else None)))}

    @staticmethod
    def _parse_fetch_time(value: object) -> datetime | None:
        if not isinstance(value, str) or not value.strip():
            return None
        try:
            parsed = datetime.fromisoformat(value)
        except (TypeError, ValueError, OverflowError):
            return None
        if parsed.tzinfo is None or parsed.utcoffset() is None:
            return None
        return parsed
