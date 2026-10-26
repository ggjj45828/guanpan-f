from datetime import date, datetime, timedelta, timezone
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
import json
import sqlite3
import threading
import tempfile
import unittest

from nas.fminute.archive import ArchiveError, MarketSession, MinuteArchive, MinuteBar
from nas.fminute.service import (
    BackfillPriority, BackfillQueueFull, MinuteArchiveService, ServiceError,
)
from nas.fminute.http_api import make_handler
from nas.fminute.evidence import ResearchEvidenceEnvelope

UTC = timezone.utc


def make_session(day: date, count: int = 4, market: str = "CN") -> MarketSession:
    local = datetime.combine(day, datetime.min.time(), tzinfo=timezone(timedelta(hours=8)))
    stamps = tuple(local.replace(hour=9, minute=31 + index) for index in range(count))
    return MarketSession(market, day, "Asia/Shanghai", stamps)


def make_bars(session: MarketSession, *, fetched_at: datetime, price: str = "1.25",
              count: int | None = None, quality: int = 95, source: str = "fixture") -> list[MinuteBar]:
    stamps = session.expected_timestamps[:count] if count is not None else session.expected_timestamps
    return [MinuteBar("159352", session.market, session.trading_date, stamp,
                      price, index + 1, 1, "source_minute", source, fetched_at,
                      stamp, quality, quality, "complete")
            for index, stamp in enumerate(stamps)]


class Calendar:
    timezone_name = "Asia/Shanghai"

    def __init__(self, sessions):
        self._sessions = tuple(sessions)

    def sessions(self, market, start, end):
        return tuple(session for session in self._sessions
                     if session.market == market and start <= session.trading_date <= end)


class Provider:
    name = "fixture"

    def __init__(self, session, *, count=None):
        self.session, self.count, self.calls = session, count, 0

    def fetch(self, security_code, market, trading_date):
        self.calls += 1
        if (security_code, market, trading_date) != ("159352", self.session.market, self.session.trading_date):
            return []
        return make_bars(self.session, fetched_at=datetime(2026, 10, 25, 1, tzinfo=UTC), count=self.count)


class MutableClock:
    def __init__(self, value):
        self.value = value

    def __call__(self):
        return self.value


class MinuteServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.archive = MinuteArchive(root / "archive.sqlite")
        self.sessions = [make_session(date(2026, 10, day)) for day in (20, 21, 22)]
        self.calendar = Calendar(self.sessions)
        self.clock = MutableClock(datetime(2026, 10, 25, 2, tzinfo=UTC))
        self.service = MinuteArchiveService(
            self.archive, root / "queue.sqlite", {"CN": self.calendar},
            {"CN": [Provider(self.sessions[-1])]}, max_queued_sessions=10,
            retry_base_seconds=60, clock=self.clock)

    def tearDown(self):
        self.temp.cleanup()

    def test_historical_query_requires_exact_requested_trading_date(self):
        self.archive.ingest(make_bars(self.sessions[0], fetched_at=self.clock()), mode="backfill")
        result = self.service.get_history("159352", "CN", date(2026, 10, 20))
        self.assertEqual(result["tradingDate"], "2026-10-20")
        self.assertEqual(result["status"], "complete")
        self.assertEqual(len(result["bars"]), 4)
        self.assertEqual(result["bars"][0]["tradingDate"], "2026-10-20")
        self.assertIn("fetchedAt", result["bars"][0])
        self.assertEqual(self.service.get_history("159352", "CN", date(2026, 10, 19))["status"], "not-a-session")

    def test_as_of_history_and_completeness_exclude_later_versions(self):
        session = self.sessions[0]
        early = datetime(2026, 10, 20, 10, tzinfo=UTC)
        late = datetime(2026, 10, 20, 14, tzinfo=UTC)
        self.archive.ingest(make_bars(session, fetched_at=early, price="1.25", quality=90), mode="realtime")
        self.archive.ingest(make_bars(session, fetched_at=late, price="1.30", quality=99), mode="backfill")
        result = self.service.get_history("159352", "CN", session.trading_date, available_as_of=early)
        self.assertEqual(result["status"], "complete")
        self.assertEqual({bar["price"] for bar in result["bars"]}, {"1.25"})
        self.assertEqual(self.archive.query_day("159352", "CN", session.trading_date)[0]["price"], "1.30")

    def test_realtime_ingest_checks_calendar_session_and_archives(self):
        result = self.service.ingest_realtime(make_bars(self.sessions[0], fetched_at=self.clock()))
        self.assertEqual(result[0]["storedObservations"], 4)
        self.assertEqual(result[0]["coverage"]["status"], "complete")
        invalid = make_bars(self.sessions[0], fetched_at=self.clock())
        invalid[0] = MinuteBar("159352", "CN", date(2026, 10, 19), invalid[0].timestamp,
                               "1.2", 1, 1, "source_minute", "fixture", self.clock(),
                               invalid[0].timestamp, 95, 95, "complete")
        with self.assertRaises(ServiceError):
            self.service.ingest_realtime(invalid)

    def test_initial_backfill_uses_calendar_sessions_and_bounded_lookback(self):
        report = self.service.enqueue_initial_history("159352", "CN", through=date(2026, 10, 22),
                                                       sessions_back=2, priority=BackfillPriority.HOLDING)
        queued = self.service.queue_snapshot()
        self.assertEqual(report["requestedSessions"], 2)
        self.assertEqual([row["trading_date"] for row in queued], ["2026-10-21", "2026-10-22"])

    def test_holdings_are_queued_ahead_of_watchlist_and_benchmark(self):
        self.service.on_instrument_added("159352", "CN", added_to="benchmark",
                                         through=date(2026, 10, 20), sessions_back=1)
        self.service.on_instrument_added("510500", "CN", added_to="holding",
                                         through=date(2026, 10, 20), sessions_back=1)
        snapshot = self.service.queue_snapshot()
        self.assertEqual(snapshot[0]["security_code"], "510500")
        self.assertEqual(snapshot[0]["priority"], int(BackfillPriority.HOLDING))

    def test_duplicate_enqueues_are_idempotent_and_promote_priority(self):
        day = self.sessions[0].trading_date
        self.service.enqueue_backfill("159352", "CN", day, day, BackfillPriority.BENCHMARK)
        self.service.enqueue_backfill("159352", "CN", day, day, BackfillPriority.HOLDING)
        self.assertEqual(self.service.queue_count(), 1)
        self.assertEqual(self.service.queue_snapshot()[0]["priority"], int(BackfillPriority.HOLDING))

    def test_gap_discovery_skips_complete_sessions(self):
        session = self.sessions[0]
        self.archive.ingest(make_bars(session, fetched_at=self.clock()), mode="backfill")
        self.archive.evaluate_session("159352", session, evaluated_at=self.clock())
        result = self.service.enqueue_backfill("159352", "CN", session.trading_date,
                                               session.trading_date, BackfillPriority.HOLDING)
        self.assertEqual(result["alreadyCoveredSessions"], 1)
        self.assertEqual(result["queuedOrRequeued"], 0)
        self.assertEqual(self.service.queue_count(), 0)

    def test_queue_capacity_rejects_whole_request_without_partial_enqueue(self):
        service = MinuteArchiveService(self.archive, Path(self.temp.name) / "small.sqlite",
                                       {"CN": self.calendar}, {}, max_queued_sessions=2,
                                       clock=self.clock)
        with self.assertRaises(BackfillQueueFull):
            service.enqueue_backfill("159352", "CN", self.sessions[0].trading_date,
                                     self.sessions[-1].trading_date, BackfillPriority.WATCHLIST)
        self.assertEqual(service.queue_count(), 0)

    def test_worker_completes_backfill_and_is_idempotent_after_restart(self):
        session = self.sessions[0]
        service = MinuteArchiveService(self.archive, Path(self.temp.name) / "persisted-queue.sqlite",
                                       {"CN": self.calendar}, {"CN": [Provider(session)]}, clock=self.clock)
        service.enqueue_backfill("159352", "CN", session.trading_date, session.trading_date,
                                 BackfillPriority.HOLDING)
        result = service.run_backfill_batch(limit=1)
        self.assertEqual(result[0]["queueStatus"], "complete")
        restarted = MinuteArchiveService(self.archive, Path(self.temp.name) / "persisted-queue.sqlite",
                                         {"CN": self.calendar}, {"CN": [Provider(session)]}, clock=self.clock)
        self.assertEqual(restarted.queue_count(), 0)
        self.assertEqual(len(self.archive.query_day("159352", "CN", session.trading_date)), 4)

    def test_partial_provider_result_is_reported_and_retried_with_backoff(self):
        session = self.sessions[0]
        provider = Provider(session, count=2)
        service = MinuteArchiveService(self.archive, Path(self.temp.name) / "retry.sqlite",
                                       {"CN": self.calendar}, {"CN": [provider]}, clock=self.clock,
                                       retry_base_seconds=60)
        service.enqueue_backfill("159352", "CN", session.trading_date, session.trading_date,
                                 BackfillPriority.HOLDING)
        first = service.run_backfill_batch(limit=1)[0]
        self.assertEqual(first["queueStatus"], "queued")
        self.assertEqual(first["report"]["result"], "partial")
        self.assertEqual(service.run_backfill_batch(limit=1), [])
        self.clock.value += timedelta(seconds=61)
        self.assertEqual(service.run_backfill_batch(limit=1)[0]["report"]["result"], "partial")
        self.assertEqual(provider.calls, 2)

    def test_diagnostics_report_coverage_sources_collection_times_and_database_size(self):
        complete, partial, missing = self.sessions
        self.archive.ingest(make_bars(complete, fetched_at=self.clock(), source="realtime-fixture"),
                            mode="realtime")
        self.archive.evaluate_session("159352", complete, evaluated_at=self.clock())
        self.archive.ingest(make_bars(partial, fetched_at=self.clock(), count=2,
                                      source="backfill-fixture"), mode="backfill")
        self.archive.evaluate_session("159352", partial, evaluated_at=self.clock())

        report = self.service.get_diagnostics("159352", "CN",
                                              complete.trading_date, missing.trading_date)
        self.assertEqual(report["firstMinuteDate"], complete.trading_date.isoformat())
        self.assertEqual(report["lastMinuteDate"], partial.trading_date.isoformat())
        self.assertEqual(report["archivedTradingDays"], 2)
        self.assertEqual(report["completeDays"], 1)
        self.assertEqual(report["partialDays"], 1)
        self.assertEqual(report["missingDays"], 1)
        self.assertEqual(datetime.fromisoformat(report["lastRealtimeCollection"]), self.clock())
        self.assertEqual(datetime.fromisoformat(report["lastBackfill"]), self.clock())
        self.assertEqual(report["sources"], ["backfill-fixture", "realtime-fixture"])
        self.assertGreater(report["databaseBytes"], 0)
        self.assertEqual([day["completeness"] for day in report["days"]],
                         ["complete", "partial", "missing"])

    def test_diagnostics_include_calendar_timezone_and_missing_expected_sessions(self):
        report = self.service.get_diagnostics("159352", "CN", date(2026, 10, 20), date(2026, 10, 22))
        self.assertEqual(report["timezone"], "Asia/Shanghai")
        self.assertEqual(report["missingDays"], 3)
        self.assertEqual(report["queuedBackfillSessions"], 0)

    def test_diagnostics_queue_count_is_scoped_to_requested_security(self):
        start, end = date(2026, 10, 20), date(2026, 10, 22)
        self.service.enqueue_backfill("159352", "CN", start, end, BackfillPriority.HOLDING)
        self.service.enqueue_backfill("563020", "CN", start, end, BackfillPriority.WATCHLIST)
        report = self.service.get_diagnostics("159352", "CN", start, end)
        self.assertEqual(report["queuedBackfillSessions"], 3)
        self.assertEqual(self.service.queue_count("159352", "CN"), 3)
        self.assertEqual(self.service.queue_count(), 6)

    def test_requeueing_failed_sessions_respects_capacity_and_rolls_back(self):
        limited = MinuteArchiveService(
            self.archive, Path(self.temp.name) / "limited-queue.sqlite",
            {"CN": self.calendar}, {"CN": []}, max_queued_sessions=2,
            clock=self.clock)
        first, second, third = self.sessions
        limited.enqueue_backfill("159352", "CN", first.trading_date, second.trading_date,
                                 BackfillPriority.HOLDING)
        with sqlite3.connect(limited.queue_path) as db:
            db.execute("UPDATE backfill_task SET status='failed' WHERE trading_date=?",
                       (first.trading_date.isoformat(),))
        with self.assertRaises(BackfillQueueFull):
            limited.enqueue_backfill("159352", "CN", first.trading_date, third.trading_date,
                                     BackfillPriority.HOLDING)
        self.assertEqual(limited.queue_count(), 1)
        statuses = {item["trading_date"]: item["status"] for item in limited.queue_snapshot()}
        self.assertEqual(statuses, {first.trading_date.isoformat(): "failed",
                                    second.trading_date.isoformat(): "queued"})

    def test_archive_gap_requeues_a_previously_complete_task(self):
        day = self.sessions[0].trading_date
        self.service.enqueue_backfill("159352", "CN", day, day, BackfillPriority.HOLDING)
        with sqlite3.connect(self.service.queue_path) as db:
            db.execute("UPDATE backfill_task SET status='complete' WHERE trading_date=?",
                       (day.isoformat(),))
        result = self.service.enqueue_backfill("159352", "CN", day, day,
                                               BackfillPriority.HOLDING)
        self.assertEqual(result["queuedOrRequeued"], 1)
        self.assertEqual(self.service.queue_count("159352", "CN"), 1)
        self.assertEqual(self.service.queue_snapshot()[0]["status"], "queued")

    def test_research_endpoint_returns_compact_fail_closed_evidence(self):
        session = self.sessions[0]
        self.archive.ingest(make_bars(session, fetched_at=self.clock()), mode="backfill")
        result = self.service.get_research_evidence(
            "159352", "CN", session.trading_date, session.trading_date,
            as_of=self.clock(), minimum_independent_days=2)
        self.assertEqual(result["qualifiedIndependentDays"], 1)
        self.assertEqual(result["evidence"]["vwapBreak"]["windows"]["5"]["evidenceState"],
                         "insufficient_independent_days")
        self.assertFalse(result["rawMinuteBarsIncluded"])
        self.assertIsNone(result["tradePlan"])
        self.assertEqual(result["schemaVersion"], 1)
        self.assertEqual(result["methodologyVersion"], "minute-research-1")
        self.assertTrue(result["evidenceId"])
        repeated = self.service.get_research_evidence(
            "159352", "CN", session.trading_date, session.trading_date,
            as_of=self.clock(), minimum_independent_days=2)
        self.assertEqual(result["evidenceId"], repeated["evidenceId"])
        self.assertIn("limitations", result)
        self.assertNotIn("bars", result)
        self.assertNotIn("samples", result["evidence"]["vwapBreak"])
        self.assertNotIn("samples", result["evidence"]["morningRecovery"])
        self.assertTrue(all("sessions" not in item and "sessionCount" in item
                            for item in result["evidence"]["gridSpacingReplay"]["spacings"].values()))

    def test_research_evidence_contract_rejects_raw_data_and_trade_plans(self):
        session = self.sessions[0]
        self.archive.ingest(make_bars(session, fetched_at=self.clock()), mode="backfill")
        evidence = self.service.get_research_evidence(
            "159352", "CN", session.trading_date, session.trading_date, as_of=self.clock())
        internal = {"securityCode": evidence["securityCode"], "market": evidence["market"],
                    "range": evidence["range"], "asOf": evidence["asOf"],
                    "sessionCoverage": evidence["sessionCoverage"],
                    "qualifiedIndependentDays": evidence["qualifiedIndependentDays"],
                    "minimumQuality": evidence["minimumQuality"], "sources": evidence["sources"],
                    "timezone": evidence["timezone"], "researchEvidence": evidence["evidence"],
                    "rawMinuteBarsIncluded": True, "tradePlan": None}
        with self.assertRaises(ArchiveError):
            ResearchEvidenceEnvelope.create(internal, generated_at=self.clock())
        internal["rawMinuteBarsIncluded"] = False
        internal["tradePlan"] = {"side": "buy"}
        with self.assertRaises(ArchiveError):
            ResearchEvidenceEnvelope.create(internal, generated_at=self.clock())
        internal["tradePlan"] = None
        internal["sources"] = []
        with self.assertRaises(ArchiveError):
            ResearchEvidenceEnvelope.create(internal, generated_at=self.clock())
        internal["qualifiedIndependentDays"] = 0
        valid_no_data = ResearchEvidenceEnvelope.create(internal, generated_at=self.clock())
        self.assertEqual(valid_no_data.sources, ())

    def test_research_evidence_id_covers_quality_and_eligibility_metadata(self):
        payload = {"securityCode": "159352", "market": "CN",
                   "range": {"start": "2026-10-20", "end": "2026-10-22"},
                   "asOf": "2026-10-25T02:00:00Z", "sessionCoverage": {"complete": 3},
                   "qualifiedIndependentDays": 3, "minimumQuality": 90,
                   "sources": ["fixture"],
                   "researchEvidence": {"vwapBreak": {"evidenceState": "insufficient_independent_days"}},
                   "rawMinuteBarsIncluded": False, "tradePlan": None}
        first = ResearchEvidenceEnvelope.create(payload, generated_at=self.clock())
        for field, changed in (("qualifiedIndependentDays", 25), ("minimumQuality", 80),
                               ("sessionCoverage", {"complete": 2, "partial": 1}),
                               ("sources", ["other-source"])):
            altered = dict(payload)
            altered[field] = changed
            candidate = ResearchEvidenceEnvelope.create(altered, generated_at=self.clock())
            self.assertNotEqual(first.evidence_id, candidate.evidence_id, field)

    def test_research_evidence_digest_canonicalizes_integral_float_encoding(self):
        payload = {"securityCode": "159352", "market": "CN",
                   "range": {"start": "2026-10-20", "end": "2026-10-22"},
                   "asOf": "2026-10-25T02:00:00Z", "sessionCoverage": {"complete": 1},
                   "qualifiedIndependentDays": 0, "minimumQuality": 90, "sources": [],
                   "researchEvidence": {"vwapBreak": {"metric": 1.0}},
                   "rawMinuteBarsIncluded": False, "tradePlan": None}
        as_integer = ResearchEvidenceEnvelope.create(payload, generated_at=self.clock())
        payload["researchEvidence"] = {"vwapBreak": {"metric": 1}}
        as_float = ResearchEvidenceEnvelope.create(payload, generated_at=self.clock())
        self.assertEqual(as_integer.evidence_id, as_float.evidence_id)

    def test_research_evidence_id_covers_generated_time_and_timezone(self):
        payload = {"securityCode": "159352", "market": "CN",
                   "range": {"start": "2026-10-20", "end": "2026-10-22"},
                   "asOf": "2026-10-25T02:00:00Z", "timezone": "Asia/Shanghai",
                   "sessionCoverage": {"complete": 3}, "qualifiedIndependentDays": 0,
                   "minimumQuality": 90, "sources": [],
                   "researchEvidence": {"vwapBreak": {"metric": 0.5}},
                   "rawMinuteBarsIncluded": False, "tradePlan": None}
        first = ResearchEvidenceEnvelope.create(payload, generated_at=self.clock())
        later = ResearchEvidenceEnvelope.create(payload, generated_at=self.clock() + timedelta(seconds=1))
        different_timezone = dict(payload, timezone="UTC")
        other_zone = ResearchEvidenceEnvelope.create(different_timezone, generated_at=self.clock())
        self.assertNotEqual(first.evidence_id, later.evidence_id)
        self.assertNotEqual(first.evidence_id, other_zone.evidence_id)

    def test_dividend_quality_evidence_is_accepted_as_distinct_research_family(self):
        payload = {"securityCode": "563020", "market": "CN",
                   "range": {"start": "2026-10-01", "end": "2026-10-23"},
                   "asOf": "2026-10-23T07:58:00Z", "sessionCoverage": {},
                   "qualifiedIndependentDays": 0, "minimumQuality": 90,
                   "sources": ["dividend-provider"],
                   "researchEvidence": {"dividendQuality": {"evidenceState": "evidence_available"}},
                   "rawMinuteBarsIncluded": False, "tradePlan": None}
        envelope = ResearchEvidenceEnvelope.create(
            payload, generated_at=datetime(2026, 10, 23, 8, tzinfo=UTC))
        self.assertIn("dividendQuality", envelope.to_dict()["evidence"])
        self.assertEqual(envelope.qualified_independent_days, 0)

    def test_research_evidence_obeys_fetched_at_as_of_cutoff(self):
        session = self.sessions[0]
        self.archive.ingest(make_bars(session, fetched_at=self.clock()), mode="backfill")
        earlier = self.clock() - timedelta(days=1)
        result = self.service.get_research_evidence(
            "159352", "CN", session.trading_date, session.trading_date, as_of=earlier,
            minimum_independent_days=1)
        self.assertEqual(result["qualifiedIndependentDays"], 0)
        self.assertEqual(result["sessionCoverage"]["missing"], 1)
        with self.assertRaises(ServiceError):
            self.service.get_research_evidence(
                "159352", "CN", session.trading_date, session.trading_date,
                as_of=self.clock() + timedelta(seconds=1), minimum_independent_days=1)

    def test_http_api_requires_auth_and_returns_date_specific_history_and_diagnostics(self):
        session = self.sessions[0]
        self.archive.ingest(make_bars(session, fetched_at=self.clock()), mode="backfill")
        handler = make_handler(self.service, lambda request: request.headers.get("X-Api-Key") == "secret")
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=2)
            connection.request("GET", "/api/v1/minute-history?securityCode=159352&market=CN&tradingDate=2026-10-20")
            unauthorized = connection.getresponse()
            self.assertEqual(unauthorized.status, 401)
            unauthorized.read()
            connection.close()

            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=2)
            connection.request("GET", "/api/v1/minute-history?securityCode=159352&market=CN&tradingDate=2026-10-20",
                               headers={"X-Api-Key": "secret"})
            response = connection.getresponse()
            payload = json.loads(response.read())
            self.assertEqual(response.status, 200)
            self.assertEqual(payload["tradingDate"], "2026-10-20")
            self.assertEqual(len(payload["bars"]), 4)
            self.assertEqual(payload["bars"][0]["securityCode"], "159352")
            connection.request("GET", "/api/v1/minute-history?securityCode=159352&market=CN&tradingDate=2026-10-20&unexpected=1",
                               headers={"X-Api-Key": "secret"})
            unknown_parameter = connection.getresponse()
            self.assertEqual(unknown_parameter.status, 400)
            unknown_parameter.read()
            connection.request("GET", "/api/v1/minute-history?securityCode=159352&market=CN&tradingDate=2026-W43-2",
                               headers={"X-Api-Key": "secret"})
            invalid_date = connection.getresponse()
            self.assertEqual(invalid_date.status, 400)
            invalid_date.read()
            connection.request("GET", "/api/v1/minute-history/diagnostics?securityCode=159352&market=CN",
                               headers={"X-Api-Key": "secret"})
            diagnostics = json.loads(connection.getresponse().read())
            self.assertEqual(diagnostics["firstMinuteDate"], "2026-10-20")
            self.assertEqual(diagnostics["days"][0]["tradingDate"], "2026-10-20")
            self.assertEqual(diagnostics["missingDaysScope"], "recordedCoverageOnly")
            self.assertTrue(diagnostics["missingDaysMayBeUnderstated"])
            connection.request("GET", "/api/v1/minute-history/diagnostics?securityCode=159352&market=CN&startDate=2026-10-20&endDate=2026-10-22",
                               headers={"X-Api-Key": "secret"})
            ranged_diagnostics = json.loads(connection.getresponse().read())
            self.assertEqual(ranged_diagnostics["missingDaysScope"], "requestedCalendarRange")
            self.assertFalse(ranged_diagnostics["missingDaysMayBeUnderstated"])
            self.assertEqual(ranged_diagnostics["missingDays"], 2)
            research_url = ("/api/v1/minute-history/research?securityCode=159352&market=CN"
                            "&startDate=2026-10-20&endDate=2026-10-20"
                            "&asOf=2026-10-25T02:00:00Z&minimumIndependentDays=20")
            connection.request("GET", research_url, headers={"X-Api-Key": "secret"})
            research = json.loads(connection.getresponse().read())
            self.assertFalse(research["rawMinuteBarsIncluded"])
            self.assertIsNone(research["tradePlan"])
            connection.close()
        finally:
            server.shutdown()
            thread.join(timeout=2)
            server.server_close()

    def test_http_authorizer_requires_literal_boolean_true(self):
        truthy_authorizers = (lambda _request: "authorized", lambda _request: 1)
        for authorize in truthy_authorizers:
            handler = make_handler(self.service, authorize)
            self.assertFalse(handler.__new__(handler)._authorized())
        handler = make_handler(self.service, lambda _request: True)
        self.assertTrue(handler.__new__(handler)._authorized())
        handler = make_handler(self.service, lambda _request: (_ for _ in ()).throw(RuntimeError()))
        self.assertFalse(handler.__new__(handler)._authorized())

    def test_readyz_fails_closed_when_calendar_does_not_review_current_year(self):
        handler = make_handler(self.service, lambda request: request.headers.get("X-Api-Key") == "secret")
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=2)
            connection.request("GET", "/readyz", headers={"X-Api-Key": "secret"})
            unsupported = connection.getresponse()
            unsupported_payload = json.loads(unsupported.read())
            self.assertEqual(unsupported.status, 503)
            self.assertEqual(unsupported_payload["status"], "not_ready")
            self.assertEqual(unsupported_payload["calendar"]["CN"]["supportedYears"], [])

            current_year = datetime.now().year
            self.calendar.supported_years = (current_year,)
            connection.request("GET", "/readyz", headers={"X-Api-Key": "secret"})
            supported = connection.getresponse()
            supported_payload = json.loads(supported.read())
            self.assertEqual(supported.status, 200)
            self.assertEqual(supported_payload["calendar"]["CN"]["currentYear"], current_year)

            class CorruptCalendar:
                timezone_name = "Asia/Shanghai"

                @property
                def supported_years(self):
                    raise RuntimeError("corrupt calendar store")

            self.service.calendars["CN"] = CorruptCalendar()
            connection.request("GET", "/readyz", headers={"X-Api-Key": "secret"})
            corrupt = connection.getresponse()
            corrupt_payload = json.loads(corrupt.read())
            self.assertEqual(corrupt.status, 503)
            self.assertEqual(corrupt_payload["calendarErrors"]["CN"], "RuntimeError")
            connection.close()
        finally:
            server.shutdown()
            thread.join(timeout=2)
            server.server_close()

    def test_http_backfill_endpoint_validates_and_enqueues_explicit_priority(self):
        handler = make_handler(self.service, lambda request: request.headers.get("X-Api-Key") == "secret")
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=2)
            body = json.dumps({"securityCode": "159352", "market": "CN",
                               "startDate": "2026-10-20", "endDate": "2026-10-20",
                               "priority": "holding"})
            connection.request("POST", "/api/v1/minute-history/backfill", body,
                               {"Content-Type": "application/json", "Content-Length": str(len(body)),
                                "X-Api-Key": "secret"})
            response = connection.getresponse()
            payload = json.loads(response.read())
            self.assertEqual(response.status, 202)
            self.assertEqual(payload["priority"], "holding")
            self.assertEqual(self.service.queue_count(), 1)

            malformed = json.dumps({"securityCode": 159352, "market": "CN",
                                    "startDate": "2026-10-20", "endDate": "2026-10-20",
                                    "priority": "holding"})
            connection.request("POST", "/api/v1/minute-history/backfill", malformed,
                               {"Content-Type": "application/json", "X-Api-Key": "secret"})
            invalid_type = connection.getresponse()
            self.assertEqual(invalid_type.status, 400)
            invalid_type.read()
            duplicate_key = ('{"securityCode":"159352","market":"CN",'
                             '"startDate":"2026-10-20","endDate":"2026-10-20",'
                             '"priority":"holding","priority":"benchmark"}')
            connection.request("POST", "/api/v1/minute-history/backfill", duplicate_key,
                               {"Content-Type": "application/json", "X-Api-Key": "secret"})
            duplicate = connection.getresponse()
            self.assertEqual(duplicate.status, 400)
            duplicate.read()
            non_finite = ('{"securityCode":"159352","market":"CN",'
                          '"startDate":"2026-10-20","endDate":"2026-10-20",'
                          '"priority":"holding","extra":NaN}')
            connection.request("POST", "/api/v1/minute-history/backfill", non_finite,
                               {"Content-Type": "application/json", "X-Api-Key": "secret"})
            invalid_constant = connection.getresponse()
            self.assertEqual(invalid_constant.status, 400)
            invalid_constant.read()
            self.assertEqual(self.service.queue_count(), 1)
            connection.close()
        finally:
            server.shutdown()
            thread.join(timeout=2)
            server.server_close()

    def test_invalid_history_request_fails_closed_without_substituting_today(self):
        missing = self.service.get_history("159352", "CN", date(2026, 10, 19))
        self.assertEqual(missing["status"], "not-a-session")
        self.assertEqual(missing["bars"], [])
        with self.assertRaises(ServiceError):
            self.service.enqueue_backfill("159352", "CN", date(2026, 10, 22),
                                          date(2026, 10, 20), BackfillPriority.HOLDING)
        with self.assertRaises(ServiceError):
            self.service.enqueue_backfill("159352", "CN", date(2026, 10, 20),
                                          date(2026, 10, 20), 0)
        self.assertEqual(self.service.queue_count(), 0)

        class DuplicateCalendar:
            def sessions(_self, market, start, end):
                return (self.sessions[0], self.sessions[0])

        self.service.calendars["CN"] = DuplicateCalendar()
        with self.assertRaises(ServiceError):
            self.service.enqueue_backfill("159352", "CN", date(2026, 10, 20),
                                          date(2026, 10, 20), BackfillPriority.HOLDING)
        self.assertEqual(self.service.queue_count(), 0)
        with self.assertRaises(ServiceError):
            self.service.get_history("159352", "CN", date(2026, 10, 20))
        with self.assertRaises(ServiceError):
            self.service.get_diagnostics("159352", "CN", date(2026, 10, 20), date(2026, 10, 22))

        wrong_market_session = MarketSession("JP", date(2026, 10, 20), "Asia/Shanghai",
                                             self.sessions[0].expected_timestamps)

        class WrongMarketCalendar:
            def sessions(_self, market, start, end):
                return (wrong_market_session,)

        self.service.calendars["CN"] = WrongMarketCalendar()
        with self.assertRaises(ServiceError):
            self.service.get_history("159352", "CN", date(2026, 10, 20))
        with self.assertRaises(ServiceError):
            self.service.ingest_realtime(make_bars(self.sessions[0], fetched_at=self.clock()))
        self.assertEqual(self.archive.query_day("159352", "CN", date(2026, 10, 20)), [])
        with self.assertRaises(ServiceError):
            self.service.get_history("159352", "CN", date(2026, 10, 20), minimum_quality=101)
        with self.assertRaises(ServiceError):
            self.service.get_history("159352", "CN", datetime(2026, 10, 20))
        with self.assertRaises(ServiceError):
            self.service.enqueue_initial_history("159352", "CN", through=datetime(2026, 10, 25))
        with self.assertRaises(ServiceError):
            self.service.enqueue_initial_history("159352", "CN", through=date(2026, 10, 25),
                                                 sessions_back=True)
        with self.assertRaises(ServiceError):
            self.service.get_diagnostics("159352", "CN", datetime(2026, 10, 20), date(2026, 10, 22))
        with self.assertRaises(ServiceError):
            self.service.get_history("159352", "CN", date(2026, 10, 20),
                                    available_as_of=datetime(2026, 10, 20, 10))
        with self.assertRaises(ServiceError):
            self.service.get_history("159352", "CN", date(2026, 10, 20),
                                    available_as_of=self.clock() + timedelta(seconds=1))

    def test_backfill_queue_revalidates_persisted_schema_and_rows_after_restart(self):
        day = self.sessions[0].trading_date
        self.service.enqueue_backfill("159352", "CN", day, day, BackfillPriority.HOLDING)
        with sqlite3.connect(self.service.queue_path) as db:
            version = db.execute("SELECT value FROM queue_meta WHERE key='schema_version'").fetchone()
            self.assertEqual(version[0], "1")
            db.execute("UPDATE backfill_task SET priority=999 WHERE trading_date=?", (day.isoformat(),))
        with self.assertRaises(ServiceError):
            MinuteArchiveService(self.archive, self.service.queue_path, {"CN": self.calendar},
                                 {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)

        clean_queue = Path(self.temp.name) / "future-version-queue.sqlite"
        MinuteArchiveService(self.archive, clean_queue, {"CN": self.calendar},
                             {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)
        with sqlite3.connect(clean_queue) as db:
            db.execute("UPDATE queue_meta SET value='999' WHERE key='schema_version'")
        with self.assertRaises(ServiceError):
            MinuteArchiveService(self.archive, clean_queue, {"CN": self.calendar},
                                 {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)

        lease_queue = Path(self.temp.name) / "invalid-lease-queue.sqlite"
        lease_service = MinuteArchiveService(self.archive, lease_queue, {"CN": self.calendar},
                                             {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)
        lease_service.enqueue_backfill("159352", "CN", day, day, BackfillPriority.HOLDING)
        with sqlite3.connect(lease_queue) as db:
            db.execute("UPDATE backfill_task SET status='running', lease_until=NULL WHERE trading_date=?",
                       (day.isoformat(),))
        with self.assertRaises(ServiceError):
            MinuteArchiveService(self.archive, lease_queue, {"CN": self.calendar},
                                 {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)

        no_key_queue = Path(self.temp.name) / "missing-queue-key.sqlite"
        no_key_service = MinuteArchiveService(self.archive, no_key_queue, {"CN": self.calendar},
                                              {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)
        no_key_service.enqueue_backfill("159352", "CN", day, day, BackfillPriority.HOLDING)
        with sqlite3.connect(no_key_queue) as db:
            db.execute("DROP INDEX idx_backfill_ready")
            db.execute("ALTER TABLE backfill_task RENAME TO old_backfill_task")
            db.execute("""CREATE TABLE backfill_task (
                security_code TEXT NOT NULL, market TEXT NOT NULL, trading_date TEXT NOT NULL,
                priority INTEGER NOT NULL, status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
                next_attempt_at TEXT NOT NULL, lease_until TEXT, last_error TEXT,
                created_at TEXT NOT NULL, updated_at TEXT NOT NULL)""")
            db.execute("INSERT INTO backfill_task SELECT * FROM old_backfill_task")
            db.execute("DROP TABLE old_backfill_task")
        with self.assertRaises(ServiceError):
            MinuteArchiveService(self.archive, no_key_queue, {"CN": self.calendar},
                                 {"CN": [Provider(self.sessions[-1])]}, clock=self.clock)


if __name__ == "__main__":
    unittest.main()
