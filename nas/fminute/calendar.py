"""Reviewed mainland exchange session calendar.

The calendar fails closed outside explicitly published/reviewed years. The
2026 closure schedule is based on the Shanghai Stock Exchange 2026 notices;
weekday trading hours are shared by the mainland cash market.
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from .archive import MarketSession
from .calendar_sync import CalendarStore
from .service import ServiceError

SHANGHAI = ZoneInfo("Asia/Shanghai")
CN_2026_CLOSURES = frozenset({
    date(2026, 1, 1), date(2026, 1, 2),
    date(2026, 2, 16), date(2026, 2, 17), date(2026, 2, 18),
    date(2026, 2, 19), date(2026, 2, 20), date(2026, 2, 23),
    date(2026, 4, 6), date(2026, 5, 1), date(2026, 5, 4),
    date(2026, 5, 5), date(2026, 6, 19), date(2026, 9, 25),
    date(2026, 10, 1), date(2026, 10, 2), date(2026, 10, 5),
    date(2026, 10, 6), date(2026, 10, 7),
})


def _minute_range(day: date, start: time, end: time) -> tuple[datetime, ...]:
    current = datetime.combine(day, start, SHANGHAI)
    stop = datetime.combine(day, end, SHANGHAI)
    values = []
    while current <= stop:
        values.append(current)
        current += timedelta(minutes=1)
    return tuple(values)


class Mainland2026Calendar:
    """Official Shanghai/Shenzhen sessions; only stored or built-in years work."""

    timezone_name = "Asia/Shanghai"

    def __init__(self, store_path=None):
        self.store = CalendarStore(store_path) if store_path is not None else None

    @property
    def supported_years(self) -> tuple[int, ...]:
        years = {2026}
        if self.store is not None:
            years.update(int(value) for value in self.store.load()["years"])
        return tuple(sorted(years))

    def _closures(self, year: int) -> frozenset[date]:
        if self.store is not None:
            record = self.store.load()["years"].get(str(year))
            if record is not None:
                return frozenset(date.fromisoformat(value) for value in record["closedDates"])
        if year == 2026:
            return CN_2026_CLOSURES
        raise ServiceError("mainland official calendar is not configured for requested year")

    def sessions(self, market: str, start: date, end: date) -> tuple[MarketSession, ...]:
        if market != "CN" or type(start) is not date or type(end) is not date or start > end:
            raise ServiceError("unsupported mainland calendar query")
        if start.year not in self.supported_years or end.year not in self.supported_years:
            raise ServiceError("mainland official calendar is not configured for requested year")
        result = []
        closures = {year: self._closures(year) for year in range(start.year, end.year + 1)}
        day = start
        while day <= end:
            if day.weekday() < 5 and day not in closures.get(day.year, frozenset()):
                expected = (_minute_range(day, time(9, 31), time(11, 30)) +
                            _minute_range(day, time(13, 1), time(15, 0)))
                result.append(MarketSession("CN", day, self.timezone_name, expected))
            day += timedelta(days=1)
        return tuple(result)
