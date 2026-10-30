"""Small JSON HTTP adapter; network reachability is the deployment access boundary."""
from __future__ import annotations

from datetime import date, datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from zoneinfo import ZoneInfo
import json

from .service import BackfillPriority, MinuteArchiveService, ServiceError


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ServiceError("duplicate JSON object keys are not allowed")
        result[key] = value
    return result


def _reject_constant(value: str):
    raise ServiceError("non-finite JSON numbers are not allowed")


def _only_parameters(query: dict[str, str], allowed: set[str]) -> None:
    unknown = set(query) - allowed
    if unknown:
        raise ServiceError("unsupported query parameter")


def _parse_date(value: str) -> date:
    parsed = date.fromisoformat(value)
    if parsed.isoformat() != value:
        raise ServiceError("dates must use canonical YYYY-MM-DD format")
    return parsed


def make_handler(service: MinuteArchiveService):
    class MinuteArchiveHandler(BaseHTTPRequestHandler):
        server_version = "FMinuteArchive/1"

        def log_message(self, _format: str, *_args) -> None:
            # The host service should route structured logs without credentials/query strings.
            return

        def _json(self, status: HTTPStatus, payload: dict) -> None:
            body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            self.send_response(status.value)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _dashboard(self) -> None:
            page = Path(__file__).with_name("dashboard.html").read_bytes()
            self.send_response(HTTPStatus.OK.value)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(page)

        def _query(self) -> dict[str, str]:
            parsed = parse_qs(urlparse(self.path).query, keep_blank_values=True, strict_parsing=True)
            if any(len(values) != 1 for values in parsed.values()):
                raise ServiceError("query parameters must occur once")
            return {key: values[0] for key, values in parsed.items()}

        def do_GET(self) -> None:
            parsed = urlparse(self.path)
            if parsed.path in {"/", "/dashboard"}:
                self._dashboard()
                return
            if parsed.path == "/livez":
                self._json(HTTPStatus.OK, {"status": "alive", "service": "f-minute-archive"})
                return
            try:
                if parsed.path == "/readyz":
                    archive_status = service.archive.readiness_check()
                    configured_markets = sorted(set(service.calendars) & set(service.providers))
                    calendar_status = {}
                    calendar_errors = {}
                    for market in configured_markets:
                        calendar = service.calendars[market]
                        zone_name = getattr(calendar, "timezone_name", "UTC")
                        current_year = datetime.now(ZoneInfo(zone_name)).year
                        try:
                            years = list(getattr(calendar, "supported_years", ()))
                        except Exception as exc:
                            years = []
                            calendar_errors[market] = type(exc).__name__
                        calendar_status[market] = {"currentYear": current_year, "supportedYears": years}
                    ready = (archive_status == "ok" and bool(configured_markets) and
                             not calendar_errors and
                             all(value["currentYear"] in value["supportedYears"]
                                 for value in calendar_status.values()))
                    worker = getattr(service, "runtime_worker", None)
                    backfill_status = {}
                    if worker is not None:
                        for market in configured_markets:
                            try:
                                zone = ZoneInfo(getattr(service.calendars[market], "timezone_name", "UTC"))
                                backfill_status[market] = service.backfill_status(
                                    worker.securities, market,
                                    through=datetime.now(zone).date())
                            except Exception as exc:
                                backfill_status[market] = {"status": "unavailable",
                                                           "error": type(exc).__name__ + ": " + str(exc)}
                    status = HTTPStatus.OK if ready else HTTPStatus.SERVICE_UNAVAILABLE
                    self._json(status, {"status": "ready" if ready else "not_ready",
                                        "archive": archive_status,
                                        "archiveCheck": "schema_and_tables_only",
                                        "configuredMarkets": configured_markets,
                                        "calendar": calendar_status,
                                        "calendarErrors": calendar_errors,
                                        "providerNames": {market: [provider.name for provider in service.providers[market]]
                                                          for market in configured_markets},
                                        "backfillStatus": backfill_status,
                                        "realtimeWorker": getattr(getattr(service, "runtime_worker", None),
                                                                  "last_cycle", {"status": "not_configured"}),
                                        "backfillWorker": getattr(getattr(service, "runtime_worker", None),
                                                                  "last_backfill_cycle", {"status": "not_configured"}),
                                        "calendarSync": getattr(getattr(service, "runtime_worker", None),
                                                                "last_calendar_cycle", {"status": "not_configured"})})
                    return
                query = self._query()
                if parsed.path == "/api/v1/minute-history":
                    required = {"securityCode", "market", "tradingDate"}
                    _only_parameters(query, required | {"availableAsOf", "minimumQuality"})
                    if not required.issubset(query):
                        raise ServiceError("securityCode, market, and tradingDate are required")
                    day = _parse_date(query["tradingDate"])
                    as_of = datetime.fromisoformat(query["availableAsOf"].replace("Z", "+00:00")) if "availableAsOf" in query else None
                    quality = int(query.get("minimumQuality", "80"))
                    if not 0 <= quality <= 100:
                        raise ServiceError("minimumQuality must be between 0 and 100")
                    result = service.get_history(query["securityCode"], query["market"], day,
                                                 available_as_of=as_of, minimum_quality=quality)
                    self._json(HTTPStatus.OK, result)
                    return
                if parsed.path == "/api/v1/minute-history/diagnostics":
                    _only_parameters(query, {"securityCode", "market", "startDate", "endDate"})
                    if not {"securityCode", "market"}.issubset(query):
                        raise ServiceError("securityCode and market are required")
                    start = _parse_date(query["startDate"]) if "startDate" in query else None
                    end = _parse_date(query["endDate"]) if "endDate" in query else None
                    self._json(HTTPStatus.OK, service.get_diagnostics(query["securityCode"], query["market"], start, end))
                    return
                if parsed.path == "/api/v1/minute-history/research":
                    required = {"securityCode", "market", "startDate", "endDate", "asOf"}
                    _only_parameters(query, required | {"minimumIndependentDays", "minimumQuality"})
                    if not required.issubset(query):
                        raise ServiceError("securityCode, market, startDate, endDate, and asOf are required")
                    as_of = datetime.fromisoformat(query["asOf"].replace("Z", "+00:00"))
                    minimum_days = int(query.get("minimumIndependentDays", "20"))
                    quality = int(query.get("minimumQuality", "90"))
                    result = service.get_research_evidence(
                        query["securityCode"], query["market"], _parse_date(query["startDate"]),
                        _parse_date(query["endDate"]), as_of=as_of,
                        minimum_independent_days=minimum_days, minimum_quality=quality)
                    self._json(HTTPStatus.OK, result)
                    return
                if parsed.path == "/api/v1/minute-history/backfill-queue":
                    _only_parameters(query, set())
                    self._json(HTTPStatus.OK, {"queuedSessions": service.queue_count(), "tasks": service.queue_snapshot()})
                    return
                self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})
            except (ValueError, ServiceError) as exc:
                self._json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})

        def do_POST(self) -> None:
            if urlparse(self.path).path != "/api/v1/minute-history/backfill":
                self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length < 1 or length > 16_384:
                    raise ServiceError("request body size is invalid")
                raw = self.rfile.read(length)
                if len(raw) != length:
                    raise ServiceError("request body is truncated")
                payload = json.loads(raw, object_pairs_hook=_unique_object,
                                     parse_constant=_reject_constant)
                if not isinstance(payload, dict):
                    raise ServiceError("request body must be a JSON object")
                required = {"securityCode", "market", "startDate", "endDate", "priority"}
                if set(payload) != required:
                    raise ServiceError("body must contain exactly securityCode, market, startDate, endDate, priority")
                if any(not isinstance(payload[key], str) for key in required):
                    raise ServiceError("all backfill fields must be strings")
                result = service.enqueue_backfill(
                    payload["securityCode"], payload["market"],
                    _parse_date(payload["startDate"]), _parse_date(payload["endDate"]),
                    BackfillPriority.parse(payload["priority"]))
                self._json(HTTPStatus.ACCEPTED, result)
            except (ValueError, TypeError, ServiceError) as exc:
                self._json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})

    return MinuteArchiveHandler
