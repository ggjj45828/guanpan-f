"""Real public minute-data adapters used by the default F NAS runtime.

These upstream web endpoints are unofficial and can change. Parsers are strict,
the source name is persisted, and failures return no fabricated observations.
"""
from __future__ import annotations

import json
import re
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

from .archive import MinuteBar
from .http_limits import read_bounded_body

SHANGHAI = ZoneInfo("Asia/Shanghai")
USER_AGENT = "GuanpanF-MinuteArchive/1"


def _instrument_symbol(code: str) -> tuple[str, str]:
    if not isinstance(code, str) or len(code) != 6 or not code.isascii() or not code.isdigit():
        raise ValueError("securityCode must be a six-digit mainland security code")
    first = code[0]
    if first in "569":
        return "sh" + code, "1." + code
    if first in "0123":
        return "sz" + code, "0." + code
    raise ValueError("unsupported exchange code")


def _positive_price(value: str) -> str:
    try:
        price = Decimal(value)
    except (InvalidOperation, TypeError) as exc:
        raise ValueError("provider returned invalid price") from exc
    if not price.is_finite() or price <= 0:
        raise ValueError("provider returned invalid price")
    return format(price, "f")


def _nonnegative_integer(value: str) -> int:
    try:
        number = Decimal(value)
    except (InvalidOperation, TypeError) as exc:
        raise ValueError("provider returned invalid volume") from exc
    if not number.is_finite() or number < 0 or number != number.to_integral_value():
        raise ValueError("provider returned invalid volume")
    return int(number)


class TencentCurrentMinuteProvider:
    """Tencent current-session trace; it deliberately refuses historical dates."""

    name = "Tencent Finance minute/query (public web endpoint)"
    current_session_only = True

    def __init__(self, *, timeout: float = 12.0, opener=urlopen,
                 clock=lambda: datetime.now(timezone.utc)):
        self.timeout, self.opener, self.clock = timeout, opener, clock

    def fetch(self, security_code: str, market: str, trading_date: date) -> tuple[MinuteBar, ...]:
        if market != "CN":
            raise ValueError("Tencent current-minute adapter supports CN only")
        if type(trading_date) is not date:
            raise ValueError("tradingDate must be a date")
        symbol, _ = _instrument_symbol(security_code)
        now = self.clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise ValueError("provider clock must be timezone-aware")
        if now.astimezone(SHANGHAI).date() != trading_date:
            raise ValueError("Tencent minute endpoint only returns the current session")
        url = "https://web.ifzq.gtimg.cn/appstock/app/minute/query?" + urlencode({
            "code": symbol, "_var": "min_data_" + symbol,
        })
        request = Request(url, headers={"Referer": "https://gu.qq.com/", "User-Agent": USER_AGENT})
        with self.opener(request, timeout=self.timeout) as response:
            if response.status != 200:
                raise OSError("Tencent minute source unavailable")
            body = read_bounded_body(response, 2_000_000, source="Tencent current minute").decode(
                "utf-8", "strict")
        return self.parse(body, security_code, market, trading_date, fetched_at=now)

    @staticmethod
    def parse(body: str, security_code: str, market: str, trading_date: date,
              *, fetched_at: datetime) -> tuple[MinuteBar, ...]:
        symbol, _ = _instrument_symbol(security_code)
        start, end = body.find("{"), body.rfind("}")
        if start < 0 or end < start:
            raise ValueError("invalid Tencent minute response")
        node = json.loads(body[start:end + 1]).get("data", {}).get(symbol, {}).get("data", {})
        day_text, rows = node.get("date", ""), node.get("data") or node.get("items")
        if (not isinstance(day_text, str) or re.fullmatch(r"\d{8}", day_text) is None or
                datetime.strptime(day_text, "%Y%m%d").date() != trading_date or not isinstance(rows, list)):
            raise ValueError("Tencent response date or rows do not match the requested session")
        bars: dict[datetime, MinuteBar] = {}
        previous_cumulative: int | None = None
        for row in rows:
            parts = row.split() if isinstance(row, str) else []
            if len(parts) < 2 or re.fullmatch(r"\d{4}", parts[0]) is None:
                continue
            try:
                stamp = datetime.strptime(day_text + parts[0], "%Y%m%d%H%M").replace(tzinfo=SHANGHAI)
                price = _positive_price(parts[1])
                cumulative = _nonnegative_integer(parts[2]) if len(parts) > 2 else None
            except (ValueError, InvalidOperation, OverflowError):
                continue
            if stamp.astimezone(timezone.utc) > fetched_at.astimezone(timezone.utc):
                continue
            # Tencent emits a 09:30 opening-auction value; archive only the
            # regular 09:31 minute close and later session points.
            if stamp.hour == 9 and stamp.minute == 30:
                continue
            if cumulative is not None and previous_cumulative is not None and cumulative < previous_cumulative:
                # A counter reset makes downstream deltas unreliable; retain the
                # price observation but mark volume unknown from this point.
                previous_cumulative = cumulative
                minute_volume, method = None, "unknown"
            elif cumulative is not None and previous_cumulative is not None:
                minute_volume, method = cumulative - previous_cumulative, "cumulative_delta"
                previous_cumulative = cumulative
            elif cumulative is not None and stamp.hour == 9 and stamp.minute == 31:
                # At the true first session close, cumulative volume includes
                # opening-auction volume and is the first minute's accounting.
                previous_cumulative = cumulative
                minute_volume, method = cumulative, "cumulative_delta"
            elif cumulative is not None:
                previous_cumulative = cumulative
                minute_volume, method = None, "unknown"
            else:
                minute_volume, method = None, "unknown"
            bars[stamp] = MinuteBar(
                security_code, market, trading_date, stamp, price, cumulative,
                minute_volume, method, TencentCurrentMinuteProvider.name,
                fetched_at, stamp, 80, 80, "complete")
        if not bars:
            raise ValueError("Tencent response contains no usable current-session rows")
        return tuple(bars[stamp] for stamp in sorted(bars))


class EastmoneyMinuteHistoryProvider:
    """Exact-date 1-minute K-line history attempt; unavailable dates stay missing."""

    name = "Eastmoney push2his 1-minute kline (public web endpoint)"

    def __init__(self, *, timeout: float = 12.0, opener=urlopen,
                 clock=lambda: datetime.now(timezone.utc)):
        self.timeout, self.opener, self.clock = timeout, opener, clock

    def fetch(self, security_code: str, market: str, trading_date: date) -> tuple[MinuteBar, ...]:
        if market != "CN" or type(trading_date) is not date:
            raise ValueError("unsupported Eastmoney history request")
        now = self.clock()
        if now.tzinfo is None or now.utcoffset() is None:
            raise ValueError("provider clock must be timezone-aware")
        if trading_date >= now.astimezone(SHANGHAI).date():
            raise ValueError("Eastmoney adapter is restricted to finalized historical sessions")
        _, secid = _instrument_symbol(security_code)
        day = trading_date.strftime("%Y%m%d")
        query = urlencode({
            "secid": secid,
            "fields1": "f1,f2,f3,f4,f5,f6",
            "fields2": "f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61",
            "klt": "1", "fqt": "0", "beg": day, "end": day,
            "lmt": "5000", "rtntype": "6",
        })
        request = Request("https://push2his.eastmoney.com/api/qt/stock/kline/get?" + query,
                          headers={"Referer": "https://quote.eastmoney.com/", "User-Agent": USER_AGENT})
        with self.opener(request, timeout=self.timeout) as response:
            if response.status != 200:
                raise OSError("Eastmoney minute history unavailable")
            body = read_bounded_body(response, 4_000_000, source="Eastmoney minute history")
            payload = json.loads(body.decode("utf-8", "strict"))
        data = payload.get("data") or {}
        klines = data.get("klines") or []
        if not isinstance(klines, list):
            raise ValueError("Eastmoney minute response has invalid rows")
        fetched = now
        return self.parse(klines, security_code, market, trading_date, fetched_at=fetched)

    @staticmethod
    def parse(klines: list, security_code: str, market: str, trading_date: date,
              *, fetched_at: datetime) -> tuple[MinuteBar, ...]:
        if fetched_at.tzinfo is None or fetched_at.utcoffset() is None:
            raise ValueError("provider clock must be timezone-aware")
        bars: dict[datetime, MinuteBar] = {}
        for row in klines:
            if not isinstance(row, str):
                continue
            fields = row.split(",")
            if len(fields) < 6:
                continue
            try:
                local = datetime.strptime(fields[0], "%Y-%m-%d %H:%M").replace(tzinfo=SHANGHAI)
                volume = _nonnegative_integer(fields[5])
                price = _positive_price(fields[2])  # close price
            except (ValueError, InvalidOperation, OverflowError):
                continue
            if local.date() != trading_date or volume < 0:
                continue
            if local.astimezone(timezone.utc) > fetched_at.astimezone(timezone.utc):
                continue
            bars[local] = MinuteBar(
                security_code, market, trading_date, local, price, None, volume,
                "source_minute", EastmoneyMinuteHistoryProvider.name,
                fetched_at, local, 80, 80, "complete")
        return tuple(bars[stamp] for stamp in sorted(bars))
