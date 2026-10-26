"""Monthly, fail-closed discovery and synchronization of official CN calendars."""
from __future__ import annotations

from datetime import date, datetime, timezone
from html.parser import HTMLParser
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
from typing import Callable
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen

from .service import ServiceError

SSE_URL = "https://www.sse.com.cn/disclosure/dealinstruc/closed/"
SZSE_INDEX_URL = "https://www.szse.cn/www/disclosure/notice/general/"
_DATE = re.compile(r"(?:(?P<month>\d{1,2})月)?(?P<day>\d{1,2})日(?:（星期[一二三四五六日天]）)?")


class _PageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.text: list[str] = []
        self.links: list[tuple[str, str]] = []
        self._anchor_href: str | None = None
        self._anchor_text: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            self._anchor_href = dict(attrs).get("href")
            self._anchor_text = []

    def handle_endtag(self, tag):
        if tag.lower() == "a" and self._anchor_href:
            title = "".join(self._anchor_text).strip()
            if title:
                self.links.append((title, self._anchor_href))
            self._anchor_href = None
            self._anchor_text = []

    def handle_data(self, data):
        value = data.strip()
        if value:
            self.text.append(value)
            if self._anchor_href is not None:
                self._anchor_text.append(value)


def _decode_page(body: bytes) -> tuple[str, list[tuple[str, str]]]:
    # Exchange pages have historically served UTF-8; reject undecodable content
    # rather than silently interpreting a changed encoding as calendar data.
    parser = _PageParser()
    parser.feed(body.decode("utf-8", "strict"))
    text = " ".join(parser.text)
    # Some exchange pages split numerals and Chinese date units across spans.
    text = re.sub(r"(?<=\d)\s+(?=\d|年|月|日)", "", text)
    text = re.sub(r"(?<=[年月日])\s+(?=\d)", "", text)
    return text, parser.links


def parse_official_closures(text: str, year: int) -> frozenset[date]:
    """Parse explicit Chinese holiday closure date spans for exactly one year."""
    if not isinstance(text, str) or not 2000 <= year <= 2200:
        raise ServiceError("invalid official calendar input")
    if not re.search(rf"(?<!\d){year}年(?:部分节假日)?休市安排", text):
        raise ServiceError("official page does not publish the requested calendar year")
    closed: set[date] = set()
    cursor = 0
    while True:
        stop = text.find("休市", cursor)
        if stop < 0:
            break
        # Restrict each parse to the short clause immediately preceding 休市;
        # unrelated dates elsewhere on the page cannot become closures.
        start = max(text.rfind("。", cursor, stop), text.rfind("；", cursor, stop),
                    text.rfind("，", cursor, stop), cursor)
        clause = text[start:stop]
        matches = list(_DATE.finditer(clause))
        if matches:
            if "至" in clause:
                if len(matches) < 2:
                    raise ServiceError("official calendar contains an incomplete closure range")
                first, last = matches[-2], matches[-1]
                left_month = int(first.group("month")) if first.group("month") else None
                right_month = int(last.group("month")) if last.group("month") else left_month
                if left_month is None or right_month is None:
                    raise ServiceError("official calendar date is missing its month")
                try:
                    first_day = date(year, left_month, int(first.group("day")))
                    last_day = date(year, right_month, int(last.group("day")))
                except ValueError as exc:
                    raise ServiceError("official calendar contains an invalid date") from exc
                if first_day > last_day or (last_day - first_day).days > 20:
                    raise ServiceError("official calendar contains an invalid closure range")
                day = first_day
                while day <= last_day:
                    closed.add(day)
                    day = date.fromordinal(day.toordinal() + 1)
            else:
                previous_month = None
                for match in matches:
                    month = int(match.group("month")) if match.group("month") else previous_month
                    if month is None:
                        raise ServiceError("official calendar date is missing its month")
                    try:
                        closed.add(date(year, month, int(match.group("day"))))
                    except ValueError as exc:
                        raise ServiceError("official calendar contains an invalid date") from exc
                    previous_month = month
        cursor = stop + 2
    # Normal annual exchange schedules have several holiday spans. This rejects
    # a partial page, unrelated page, or markup drift that parsed only one date.
    weekdays = {day for day in closed if day.weekday() < 5}
    if not 5 <= len(weekdays) <= 30:
        raise ServiceError("official calendar closure set failed annual sanity checks")
    return frozenset(closed)


class CalendarStore:
    """Integrity-checked, atomic versioned calendar publication store."""
    schema_version = 1

    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> dict:
        if not self.path.exists():
            return {"schemaVersion": self.schema_version, "years": {}}
        try:
            envelope = json.loads(self.path.read_text(encoding="utf-8"))
            payload = envelope["payload"]
            digest = hashlib.sha256(_canonical(payload)).hexdigest()
            if envelope.get("sha256") != digest or payload.get("schemaVersion") != self.schema_version:
                raise ValueError("digest or schema mismatch")
            if not isinstance(payload.get("years"), dict):
                raise ValueError("years missing")
            for year_text, record in payload["years"].items():
                year = int(year_text)
                if not 2000 <= year <= 2200 or not isinstance(record, dict):
                    raise ValueError("invalid year record")
                dates = record.get("closedDates")
                if not isinstance(dates, list) or dates != sorted(set(dates)):
                    raise ValueError("invalid closure date list")
                if any(date.fromisoformat(item).year != year for item in dates):
                    raise ValueError("closure outside year")
            return payload
        except Exception as exc:
            raise ServiceError("official calendar store is corrupt; refusing automatic sessions") from exc

    def publish(self, year: int, closures: frozenset[date], sources: list[dict], *, fetched_at: str) -> None:
        payload = self.load()
        payload["years"][str(year)] = {
            "closedDates": sorted(day.isoformat() for day in closures),
            "sources": sources,
            "fetchedAt": fetched_at,
        }
        envelope = {"payload": payload, "sha256": hashlib.sha256(_canonical(payload)).hexdigest()}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, temp_name = tempfile.mkstemp(prefix=self.path.name + ".", suffix=".tmp", dir=self.path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
                stream.write(json.dumps(envelope, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
                stream.flush()
                os.fsync(stream.fileno())
            # Read back and verify the staged generation before making it live.
            staged_payload = CalendarStore(temp_name).load()
            if staged_payload != payload:
                raise ServiceError("staged calendar failed read-back verification")
            os.replace(temp_name, self.path)
            directory_fd = os.open(self.path.parent, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        except Exception:
            try:
                os.unlink(temp_name)
            except FileNotFoundError:
                pass
            raise


def _canonical(value: dict) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


class OfficialCalendarSync:
    """Read official SSE/SZSE pages; publish only exact cross-source agreement."""
    def __init__(self, store: CalendarStore, *, fetch: Callable[[str], bytes] | None = None,
                 clock=lambda: datetime.now(timezone.utc)):
        self.store = store
        self.fetch = fetch or self._fetch
        self.clock = clock
        self.last_result: dict = {"status": "not_run"}

    @staticmethod
    def _fetch(url: str) -> bytes:
        request = Request(url, headers={"User-Agent": "GuanpanF-NAS/1 calendar-check"})
        with urlopen(request, timeout=15) as response:
            if response.status != 200:
                raise OSError("official calendar source unavailable")
            body = response.read(2_000_001)
        if len(body) > 2_000_000:
            raise ServiceError("official calendar page exceeds size limit")
        return body

    def _szse_article(self, year: int) -> tuple[str, bytes]:
        index_body = self.fetch(SZSE_INDEX_URL)
        _index_text, links = _decode_page(index_body)
        candidates = [(title, urljoin(SZSE_INDEX_URL, href)) for title, href in links
                      if str(year) in title and "休市安排" in title]
        if len(candidates) != 1:
            raise ServiceError("SZSE annual calendar notice is absent or ambiguous")
        url = candidates[0][1]
        if urlparse(url).scheme != "https" or urlparse(url).hostname not in {"szse.cn", "www.szse.cn"}:
            raise ServiceError("SZSE calendar link left the official HTTPS domain")
        return url, self.fetch(url)

    def sync_year(self, year: int) -> dict:
        now = self.clock()
        if now.tzinfo is None or now.utcoffset() is None or not 2000 <= year <= 2200:
            raise ServiceError("calendar sync requires an aware clock and valid year")
        try:
            sse_body = self.fetch(SSE_URL)
            sse_text, _ = _decode_page(sse_body)
            sse_closures = parse_official_closures(sse_text, year)
            szse_url, szse_body = self._szse_article(year)
            szse_text, _ = _decode_page(szse_body)
            szse_closures = parse_official_closures(szse_text, year)
            if sse_closures != szse_closures:
                raise ServiceError("SSE and SZSE official closure dates disagree")
            sources = [
                {"exchange": "SSE", "url": SSE_URL,
                 "sha256": hashlib.sha256(sse_body).hexdigest()},
                {"exchange": "SZSE", "url": szse_url,
                 "sha256": hashlib.sha256(szse_body).hexdigest()},
            ]
            self.store.publish(year, sse_closures, sources, fetched_at=now.isoformat())
            self.last_result = {"status": "updated", "year": year,
                                "closureDays": len(sse_closures), "at": now.isoformat()}
        except Exception as exc:
            # No old calendar is changed on an unpublished/invalid/mismatched page.
            self.last_result = {"status": "not_updated", "year": year,
                                "error": type(exc).__name__, "at": now.isoformat()}
        return dict(self.last_result)
