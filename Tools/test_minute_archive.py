from contextlib import closing
from datetime import date, datetime, time, timedelta, timezone, tzinfo
from dataclasses import replace
from decimal import Decimal
from pathlib import Path
import tempfile
import unittest
import sqlite3

from nas.fminute.archive import ArchiveError, MarketSession, MinuteArchive, MinuteBar
from nas.fminute.research import (
    _finite_result_float,
    build_morning_selloff_recovery_evidence, build_vwap_break_evidence,
    replay_grid_spacing_evidence,
)

UTC = timezone.utc
DAY = date(2026, 10, 8)
BASE = datetime(2026, 10, 8, 9, 30, tzinfo=UTC)


def make_session(day=DAY, count=4):
    opening = datetime.combine(day, datetime.min.time(), tzinfo=UTC).replace(hour=9, minute=30)
    stamps = tuple(opening + timedelta(minutes=i + 1) for i in range(count))
    return MarketSession("CN", day, "Asia/Shanghai", stamps)


def bars(session, *, source="provider-a", fetched=None, quality=95, trust=95, price="1.25",
         volume_method="source_minute", source_timestamp=None, completeness="complete"):
    fetched = fetched or datetime(2026, 10, 9, 10, tzinfo=UTC)
    result = []
    for i, stamp in enumerate(session.expected_timestamps):
        result.append(MinuteBar("159352", session.market, session.trading_date, stamp,
                                price, i + 1, 1, volume_method, source, fetched,
                                source_timestamp or stamp, quality, trust, completeness))
    return result


def research_row(stamp, price):
    return {"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
            "fetched_at": (stamp + timedelta(minutes=1)).isoformat(), "price": str(price),
            "minute_volume": 100, "volume_method": "source_minute", "data_quality": 98,
            "source_trust": 99, "source": "fixture"}


class Provider:
    def __init__(self, name, result=None, error=None):
        self.name, self.result, self.error = name, result, error
        self.calls = 0

    def fetch(self, security_code, market, trading_date):
        self.calls += 1
        if self.error:
            raise self.error
        return self.result or []


class InvalidTimezone(tzinfo):
    def utcoffset(self, dt):
        return None

    def dst(self, dt):
        return None

    def tzname(self, dt):
        return "invalid"


class MinuteArchiveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "minutes.sqlite"
        self.archive = MinuteArchive(self.path)
        self.session = make_session()
        self.now = datetime(2026, 10, 10, 10, tzinfo=UTC)

    def tearDown(self):
        self.tmp.cleanup()

    def test_first_deployment_backfills_available_history_and_records_range(self):
        provider = Provider("history", bars(self.session))
        report = self.archive.backfill("159352", "CN", [self.session], [provider], fetched_at=self.now)
        self.assertEqual(report[0]["result"], "complete")
        self.assertTrue(report[0]["firstAvailableDate"].startswith("2026-10-08T09:31"))
        self.assertTrue(report[0]["lastAvailableDate"].startswith("2026-10-08T09:34"))
        self.assertEqual(len(self.archive.query_day("159352", "CN", DAY)), 4)

    def test_incremental_backfill_only_requests_uncovered_days(self):
        provider = Provider("history", bars(self.session))
        self.archive.backfill("159352", "CN", [self.session], [provider], fetched_at=self.now)
        report = self.archive.backfill("159352", "CN", [self.session], [provider], fetched_at=self.now)
        self.assertEqual(report[0]["result"], "already-covered")
        self.assertEqual(provider.calls, 1)

    def test_repeat_backfill_is_idempotent(self):
        data = bars(self.session)
        self.archive.ingest(data, mode="backfill")
        before = self.archive.query_day("159352", "CN", DAY)
        self.archive.ingest(data, mode="backfill")
        self.assertEqual(before, self.archive.query_day("159352", "CN", DAY))

    def test_conflicting_observation_with_reused_source_timestamp_rolls_back(self):
        row = bars(self.session)[0]
        self.archive.ingest([row], mode="backfill")
        conflicting = replace(row, price="9.99")
        with self.assertRaises(ArchiveError):
            self.archive.ingest([bars(self.session)[1], conflicting], mode="backfill")
        self.assertEqual(self.archive.query_day("159352", "CN", DAY)[0]["price"], row.price)
        with closing(sqlite3.connect(self.archive.path)) as db, db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM minute_observation").fetchone()[0], 1)
        self.assertEqual(len(self.archive.query_day("159352", "CN", DAY)), 1)

    def test_missing_expected_minutes_are_reported(self):
        data = bars(self.session)[:-1]
        self.archive.ingest(data, mode="backfill")
        report = self.archive.evaluate_session("159352", self.session, evaluated_at=self.now)
        self.assertEqual(report["status"], "partial")
        self.assertEqual(len(report["missingTimestamps"]), 1)

    def test_low_quality_rows_are_partial_and_excluded_from_research(self):
        self.archive.ingest(bars(self.session, quality=40, trust=40), mode="backfill")
        report = self.archive.evaluate_session("159352", self.session, evaluated_at=self.now, minimum_quality=90)
        self.assertEqual(report["status"], "partial")
        self.assertEqual(self.archive.research_rows("159352", "CN", DAY, self.session, as_of=self.now), [])

    def test_complete_session_passes_research_gate(self):
        current = datetime(2026, 10, 8, 10, tzinfo=UTC)
        self.archive.ingest(bars(self.session, fetched=current), mode="realtime")
        report = self.archive.evaluate_session("159352", self.session, evaluated_at=self.now)
        self.assertEqual(report["status"], "complete")
        self.assertEqual(len(self.archive.research_rows("159352", "CN", DAY, self.session, as_of=self.now)), 4)

    def test_row_marked_partial_cannot_pass_session_gate_and_backfill_can_upgrade_it(self):
        partial = bars(self.session, fetched=self.now - timedelta(minutes=1), completeness="partial")
        self.archive.ingest(partial, mode="realtime")
        report = self.archive.evaluate_session("159352", self.session, evaluated_at=self.now)
        self.assertFalse(report["completenessPassed"])
        self.assertEqual(report["status"], "partial")
        upgraded = self.archive.backfill("159352", "CN", [self.session],
                                         [Provider("provider-a", bars(self.session, fetched=self.now))],
                                         fetched_at=self.now)
        self.assertEqual(upgraded[0]["result"], "complete")

    def test_invalid_price_volume_and_future_source_timestamp_are_rejected(self):
        row = bars(self.session, fetched=self.now)[0]
        invalid_rows = [
            MinuteBar(row.security_code, row.market, row.trading_date, row.timestamp, "inf",
                      row.cumulative_volume, row.minute_volume, row.volume_method, row.source,
                      row.fetched_at, row.source_timestamp, row.data_quality, row.source_trust, row.completeness),
            MinuteBar(row.security_code, row.market, row.trading_date, row.timestamp, row.price,
                      1.5, row.minute_volume, row.volume_method, row.source,
                      row.fetched_at, row.source_timestamp, row.data_quality, row.source_trust, row.completeness),
            MinuteBar(row.security_code, row.market, row.trading_date, row.timestamp, row.price,
                      row.cumulative_volume, True, row.volume_method, row.source,
                      row.fetched_at, row.source_timestamp, row.data_quality, row.source_trust, row.completeness),
            MinuteBar(row.security_code, row.market, row.trading_date, row.timestamp, row.price,
                      row.cumulative_volume, row.minute_volume, row.volume_method, row.source,
                      row.fetched_at, row.fetched_at + timedelta(seconds=1), row.data_quality,
                      row.source_trust, row.completeness),
        ]
        for invalid in invalid_rows:
            with self.subTest(invalid=invalid):
                with self.assertRaises(ArchiveError):
                    self.archive.ingest([invalid], mode="backfill")

    def test_existing_archive_without_valid_schema_version_is_not_relabelled(self):
        row = bars(self.session)[0]
        self.archive.ingest([row], mode="backfill")
        with closing(sqlite3.connect(self.archive.path)) as db, db:
            db.execute("DELETE FROM archive_meta WHERE key='schema_version'")
        with self.assertRaises(ArchiveError):
            MinuteArchive(self.archive.path)
        with closing(sqlite3.connect(self.archive.path)) as db, db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM minute_bar").fetchone()[0], 1)
            self.assertIsNone(db.execute("SELECT value FROM archive_meta WHERE key='schema_version'").fetchone())
            db.execute("INSERT INTO archive_meta(key,value) VALUES('schema_version','01')")
        with self.assertRaises(ArchiveError):
            self.archive.integrity_check()
        rejected = Path(self.tmp.name) / "noncanonical-version-backup.sqlite"
        with self.assertRaises(ArchiveError):
            self.archive.backup(rejected)
        self.assertFalse(rejected.exists())

        invalid_path = Path(self.tmp.name) / "invalid-version.sqlite"
        MinuteArchive(invalid_path)
        with closing(sqlite3.connect(invalid_path)) as db, db:
            db.execute("UPDATE archive_meta SET value='unknown' WHERE key='schema_version'")
        with self.assertRaises(ArchiveError):
            MinuteArchive(invalid_path)

    def test_as_of_cutoff_preserves_subseconds_and_excludes_future_bar_timestamps(self):
        cutoff = datetime(2026, 10, 8, 10, 0, 0, 500_000, tzinfo=UTC)
        fetched_after_cutoff = bars(self.session, fetched=cutoff + timedelta(microseconds=1))
        self.archive.ingest(fetched_after_cutoff, mode="realtime")
        self.assertEqual(self.archive.query_day("159352", "CN", DAY, available_as_of=cutoff), [])

        future_bar = MinuteBar("159352", "CN", DAY, cutoff + timedelta(seconds=1), "1.25",
                               1, 1, "source_minute", "provider-a", cutoff,
                               cutoff, 95, 95, "complete")
        self.archive.ingest([future_bar], mode="backfill")
        self.assertEqual(self.archive.query_day("159352", "CN", DAY, available_as_of=cutoff), [])

    def test_lunch_break_is_calendar_defined_and_unexpected_lunch_rows_fail(self):
        morning = tuple(datetime(2026, 10, 8, 11, m, tzinfo=UTC) for m in (28, 29))
        afternoon = tuple(datetime(2026, 10, 8, 13, m, tzinfo=UTC) for m in (0, 1))
        session = MarketSession("CN", DAY, "Asia/Shanghai", morning + afternoon)
        self.archive.ingest(bars(session, fetched=self.now), mode="realtime")
        self.assertEqual(self.archive.evaluate_session("159352", session, evaluated_at=self.now)["status"], "complete")
        lunch_stamp = datetime(2026, 10, 8, 12, 0, tzinfo=UTC)
        lunch_bar = MinuteBar("159352", "CN", DAY, lunch_stamp, "1.2", 5, 1, "source_minute",
                              "provider-a", self.now, lunch_stamp, 95, 95, "complete")
        self.archive.ingest([lunch_bar], mode="backfill")
        report = self.archive.evaluate_session("159352", session, evaluated_at=self.now)
        self.assertEqual(report["status"], "partial")
        self.assertEqual(report["unexpectedTimestampCount"], 1)

    def test_half_day_uses_calendar_expected_count(self):
        short = make_session(count=2)
        self.archive.ingest(bars(short, fetched=self.now), mode="realtime")
        report = self.archive.evaluate_session("159352", short, evaluated_at=self.now)
        self.assertEqual(report["expectedCount"], 2)
        self.assertEqual(report["status"], "complete")

    def test_holiday_is_not_misreported_as_missing(self):
        holiday = MarketSession("CN", date(2026, 10, 9), "Asia/Shanghai", ())
        self.assertEqual(self.archive.evaluate_session("159352", holiday, evaluated_at=self.now)["status"], "not-a-session")

    def test_market_timezone_is_part_of_market_day_contract(self):
        jp_stamp = datetime(2026, 10, 8, 9, 1, tzinfo=timezone(timedelta(hours=9)))
        jp = MarketSession("JP", DAY, "Asia/Tokyo", (jp_stamp,))
        row = MinuteBar("1321", "JP", DAY, jp_stamp, "40000", 3, 3, "source_minute",
                        "jp-source", self.now, jp_stamp, 96, 96, "complete")
        self.archive.ingest([row], mode="backfill")
        self.assertEqual(len(self.archive.query_day("1321", "JP", DAY)), 1)
        self.assertEqual(self.archive.query_day("1321", "CN", DAY), [])

    def test_market_session_rejects_invalid_or_mutable_timezone_schedule(self):
        invalid = datetime(2026, 10, 8, 9, 31, tzinfo=InvalidTimezone())
        with self.assertRaises(ArchiveError):
            MarketSession("CN", DAY, "Asia/Shanghai", (invalid,))
        with self.assertRaises(ArchiveError):
            MarketSession("CN", datetime(2026, 10, 8), "Asia/Shanghai", ())
        with self.assertRaises(ArchiveError):
            MarketSession("CN", DAY, "Asia/Shanghai", [])

    def test_older_lower_quality_data_cannot_overwrite_better_row(self):
        better = bars(self.session, source="trusted", fetched=self.now, quality=99, trust=99)
        self.archive.ingest(better, mode="realtime")
        older = bars(self.session, source="fallback", fetched=self.now - timedelta(days=1), quality=60, trust=50, price="9.99")
        self.archive.ingest(older, mode="backfill")
        self.assertEqual(self.archive.query_day("159352", "CN", DAY)[0]["price"], "1.25")

    def test_higher_score_partial_row_cannot_replace_complete_point_in_time_data(self):
        complete = bars(self.session, source="trusted", fetched=self.now, quality=95, trust=95)
        self.archive.ingest(complete, mode="realtime")
        later = self.now + timedelta(seconds=1)
        partial = bars(self.session, source="fallback", fetched=later, quality=100, trust=100,
                       price="9.99", completeness="partial")
        self.archive.ingest(partial, mode="backfill")
        self.assertEqual(self.archive.query_day("159352", "CN", DAY)[0]["price"], "1.25")
        point_in_time = self.archive.query_day("159352", "CN", DAY, available_as_of=later)
        self.assertEqual({row["price"] for row in point_in_time}, {"1.25"})
        report = self.archive.evaluate_session("159352", self.session, evaluated_at=later,
                                               available_as_of=later)
        self.assertEqual(report["status"], "complete")

    def test_provider_fallback_uses_next_source(self):
        bad = Provider("unavailable", error=OSError("offline"))
        good = Provider("fallback", bars(self.session))
        result = self.archive.backfill("159352", "CN", [self.session], [bad, good], fetched_at=self.now)
        self.assertEqual(result[0]["source"], ["fallback"])
        self.assertEqual(bad.calls, 1)
        self.assertEqual(good.calls, 1)

    def test_backfill_skips_current_only_provider_for_historical_session(self):
        history = Provider("history", error=OSError("history source unavailable"))
        current_only = Provider("current", error=ValueError("current session only"))
        current_only.current_session_only = True
        result = self.archive.backfill("159352", "CN", [self.session],
                                       [history, current_only], fetched_at=self.now)
        self.assertEqual(result[0]["result"], "unavailable")
        self.assertEqual(result[0]["reason"], "OSError: history source unavailable")
        self.assertEqual(history.calls, 1)
        self.assertEqual(current_only.calls, 0)

    def test_backfill_rejects_out_of_session_rows_before_writing_and_falls_back(self):
        invalid_rows = bars(self.session, source="invalid-provider")
        invalid_rows.append(replace(
            invalid_rows[-1], timestamp=invalid_rows[-1].timestamp + timedelta(minutes=1),
            source_timestamp=invalid_rows[-1].timestamp + timedelta(minutes=1)))
        invalid = Provider("invalid-provider", invalid_rows)
        valid = Provider("valid-provider", bars(self.session, source="valid-provider"))
        result = self.archive.backfill("159352", "CN", [self.session], [invalid, valid],
                                       fetched_at=self.now)
        self.assertEqual(result[0]["result"], "complete")
        self.assertEqual(result[0]["source"], ["valid-provider"])
        archived = self.archive.query_day("159352", "CN", DAY)
        self.assertEqual(len(archived), len(self.session.expected_timestamps))
        self.assertTrue(all(row["source"] == "valid-provider" for row in archived))

    def test_query_returns_requested_historical_day(self):
        self.archive.ingest(bars(self.session), mode="backfill")
        self.assertEqual(len(self.archive.query_day("159352", "CN", date(2026, 10, 8))), 4)
        self.assertEqual(self.archive.query_day("159352", "CN", date(2026, 10, 7)), [])

    def test_no_lookahead_filters_later_observation_versions(self):
        first_time = datetime(2026, 10, 8, 10, tzinfo=UTC)
        later_time = datetime(2026, 10, 8, 14, tzinfo=UTC)
        self.archive.ingest(bars(self.session, fetched=first_time, price="1.25"), mode="realtime")
        self.archive.ingest(bars(self.session, fetched=later_time, price="1.30", source_timestamp=later_time), mode="realtime")
        point_in_time = self.archive.query_day("159352", "CN", DAY, available_as_of=first_time)
        self.assertEqual(len(point_in_time), 4)
        self.assertEqual({row["price"] for row in point_in_time}, {"1.25"})

    def test_backfilled_later_data_is_not_claimed_as_historically_available(self):
        self.archive.ingest(bars(self.session, fetched=self.now), mode="backfill")
        cutoff = datetime(2026, 10, 8, 13, tzinfo=UTC)
        self.assertEqual(self.archive.query_day("159352", "CN", DAY, available_as_of=cutoff), [])
        self.assertEqual(self.archive.research_rows("159352", "CN", DAY, self.session, as_of=cutoff), [])

    def test_restart_and_backup_restore_preserve_history(self):
        self.archive.ingest(bars(self.session), mode="backfill")
        backup = Path(self.tmp.name) / "backup.sqlite"
        backup_digest = self.archive.backup(backup)
        restored_path = Path(self.tmp.name) / "restored.sqlite"
        restored = MinuteArchive.restore_backup(backup, restored_path)
        self.assertEqual(restored.integrity_check(), "ok")
        self.assertEqual(backup_digest, restored._logical_digest(restored_path))
        self.assertEqual(self.archive.query_day("159352", "CN", DAY), restored.query_day("159352", "CN", DAY))
        restarted = MinuteArchive(self.path)
        self.assertEqual(len(restarted.query_day("159352", "CN", DAY)), 4)

    def test_restore_never_overwrites_existing_destination(self):
        self.archive.ingest(bars(self.session), mode="backfill")
        backup = Path(self.tmp.name) / "backup.sqlite"
        self.archive.backup(backup)
        existing = Path(self.tmp.name) / "already-exists.sqlite"
        existing.write_bytes(b"keep-existing-data")
        with self.assertRaises(ArchiveError):
            MinuteArchive.restore_backup(backup, existing)
        self.assertEqual(existing.read_bytes(), b"keep-existing-data")

    def test_integrity_and_backup_restore_reject_semantically_corrupt_rows(self):
        self.archive.ingest(bars(self.session), mode="backfill")
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute("UPDATE minute_bar SET price='NaN' WHERE timestamp=(SELECT MIN(timestamp) FROM minute_bar)")
        with self.assertRaises(ArchiveError):
            self.archive.integrity_check()
        with self.assertRaises(ArchiveError):
            MinuteArchive(self.path)
        with self.assertRaises(ArchiveError):
            self.archive.backup(Path(self.tmp.name) / "rejected.sqlite")

        corrupt_backup = Path(self.tmp.name) / "corrupt-backup.sqlite"
        source = sqlite3.connect(self.path)
        target = sqlite3.connect(corrupt_backup)
        try:
            source.backup(target)
        finally:
            target.close()
            source.close()
        restored_path = Path(self.tmp.name) / "must-not-publish.sqlite"
        with self.assertRaises(ArchiveError):
            MinuteArchive.restore_backup(corrupt_backup, restored_path)
        self.assertFalse(restored_path.exists())

    def test_backup_rejects_live_database_as_destination(self):
        with self.assertRaises(ArchiveError):
            self.archive.backup(self.path)
        existing = Path(self.tmp.name) / "existing-backup.sqlite"
        existing.write_bytes(b"preserve-existing-backup")
        with self.assertRaises(ArchiveError):
            self.archive.backup(existing)
        self.assertEqual(existing.read_bytes(), b"preserve-existing-backup")

    def test_cumulative_volume_requires_explicit_derived_minute_volume(self):
        row = bars(self.session)[0]
        invalid = MinuteBar(row.security_code, row.market, row.trading_date, row.timestamp, row.price,
                            row.cumulative_volume, None, "cumulative_delta", row.source,
                            row.fetched_at, row.source_timestamp, row.data_quality, row.source_trust,
                            row.completeness)
        with self.assertRaises(ArchiveError):
            self.archive.ingest([invalid], mode="backfill")
        missing_cumulative = replace(invalid, cumulative_volume=None, minute_volume=1)
        with self.assertRaises(ArchiveError):
            self.archive.ingest([missing_cumulative], mode="backfill")


    def test_research_evidence_uses_complete_sessions_and_reports_independent_days(self):
        sessions = []
        for offset in range(3):
            day = date(2026, 10, 8 + offset)
            points = []
            for index, price in enumerate(("10", "9", "8", "8.5")):
                stamp = datetime.combine(day, datetime.min.time(), tzinfo=UTC) + timedelta(hours=9, minutes=31 + index)
                points.append({"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
                               "fetched_at": (stamp + timedelta(minutes=1)).isoformat(),
                               "price": price, "minute_volume": 10, "volume_method": "source_minute",
                               "data_quality": 98, "source_trust": 99, "source": "fixture"})
            sessions.append({"tradingDate": day.isoformat(), "complete": True, "bars": points})
        evidence = build_vwap_break_evidence(sessions, research_as_of=self.now,
                                             horizons_minutes=(1,), minimum_independent_days=2,
                                             minimum_out_of_sample_days=1,
                                             maximum_monthly_concentration=1.0)
        result = evidence["windows"]["1"]
        self.assertEqual(result["independentDays"], 3)
        self.assertEqual(result["evidenceState"], "available_for_review")
        self.assertEqual(result["trainingDays"], 2)
        self.assertEqual(result["outOfSampleDays"], 1)
        self.assertLess(result["training"]["endDate"], result["outOfSample"]["startDate"])
        self.assertIsNone(evidence["tradePlan"])

    def test_research_fails_closed_for_partial_or_future_source_minutes(self):
        raw = bars(self.session, fetched=datetime(2026, 10, 8, 10, tzinfo=UTC))
        rows = [{"timestamp": row.timestamp.isoformat(), "source_timestamp": row.timestamp.isoformat(),
                 "fetched_at": row.fetched_at.isoformat(), "price": str(row.price),
                 "minute_volume": row.minute_volume, "volume_method": row.volume_method,
                 "data_quality": row.data_quality, "source_trust": row.source_trust, "source": row.source}
                for row in raw]
        sessions = [{"tradingDate": DAY.isoformat(), "complete": False, "bars": rows},
                    {"tradingDate": "2026-10-07", "complete": True,
                     "bars": [dict(row, source_timestamp=(self.now + timedelta(hours=1)).isoformat()) for row in rows]}]
        evidence = build_vwap_break_evidence(sessions, research_as_of=self.now,
                                             horizons_minutes=(1,), minimum_independent_days=1)
        self.assertEqual(evidence["windows"]["1"]["independentDays"], 0)
        self.assertEqual(evidence["windows"]["1"]["evidenceState"], "insufficient_independent_days")
        late_fetch_rows = [dict(row, fetched_at=(self.now + timedelta(minutes=1)).isoformat())
                           for row in rows]
        late_fetch = build_vwap_break_evidence(
            [{"tradingDate": DAY.isoformat(), "complete": True, "bars": late_fetch_rows}],
            research_as_of=self.now, horizons_minutes=(1,), minimum_independent_days=1)
        self.assertEqual(late_fetch["windows"]["1"]["independentDays"], 0)

    def test_research_rejects_truthy_completeness_and_untrusted_row_contracts(self):
        stamp = datetime(2026, 10, 8, 9, 31, tzinfo=UTC)
        row = {"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
               "fetched_at": stamp.isoformat(), "price": "10", "minute_volume": 10,
               "volume_method": "source_minute", "data_quality": 95,
               "source_trust": 95, "source": "fixture"}
        for session in (
                {"tradingDate": DAY.isoformat(), "complete": 1, "bars": [row, row, row]},
                {"tradingDate": DAY.isoformat(), "complete": True,
                 "bars": [dict(row, source="  "), row, row]},
                {"tradingDate": DAY.isoformat(), "complete": True,
                 "bars": [dict(row, volume_method="invented"), row, row]}):
            result = build_vwap_break_evidence(
                [session], research_as_of=self.now, horizons_minutes=(1,),
                minimum_independent_days=1, minimum_out_of_sample_days=1,
                maximum_monthly_concentration=1.0)
            self.assertEqual(result["windows"]["1"]["independentDays"], 0)

    def test_research_rejects_timezone_objects_without_offsets(self):
        invalid = datetime(2026, 10, 10, 10, tzinfo=InvalidTimezone())
        with self.assertRaises(ArchiveError):
            build_vwap_break_evidence([], research_as_of=invalid)
        with self.assertRaises(ArchiveError):
            build_morning_selloff_recovery_evidence([], research_as_of=invalid)
        with self.assertRaises(ArchiveError):
            replay_grid_spacing_evidence([], research_as_of=invalid,
                                         spacing_percentages=(Decimal("1"),))

    def test_research_does_not_claim_significance_below_sample_threshold(self):
        evidence = build_vwap_break_evidence([], research_as_of=self.now,
                                             horizons_minutes=(5, 15), minimum_independent_days=20)
        self.assertEqual(evidence["windows"]["5"]["medianReturnPercent"], None)
        self.assertEqual(evidence["windows"]["15"]["evidenceState"], "insufficient_independent_days")

    def test_research_rejects_nonfinite_float_statistics_before_marking_reviewable(self):
        self.assertIsNone(_finite_result_float(Decimal("1e-400")))

        def session_for(day, prices, minute_offsets):
            rows = []
            for price, (hour, minute) in zip(prices, minute_offsets):
                stamp = datetime.combine(day, datetime.min.time(), tzinfo=UTC).replace(
                    hour=hour, minute=minute)
                rows.append({"timestamp": stamp.isoformat(),
                             "source_timestamp": stamp.isoformat(),
                             "fetched_at": (stamp + timedelta(minutes=1)).isoformat(),
                             "price": price, "minute_volume": 1,
                             "volume_method": "source_minute", "data_quality": 98,
                             "source_trust": 99, "source": "fixture"})
            return {"tradingDate": day.isoformat(), "complete": True,
                    "timezone": "UTC", "bars": rows}

        days = (date(2026, 10, 8), date(2026, 10, 9))
        extreme_vwap = [session_for(day, ("1", "1", "1e308", "1e-300", "1e308"),
                                   ((9, 31), (9, 32), (9, 33), (9, 34), (9, 35)))
                        for day in days]
        vwap = build_vwap_break_evidence(
            extreme_vwap, research_as_of=self.now, horizons_minutes=(1,),
            minimum_independent_days=1, minimum_out_of_sample_days=1,
            maximum_monthly_concentration=1.0)["windows"]["1"]
        self.assertEqual(vwap["rejectedNumericObservations"], 2)
        self.assertEqual(vwap["independentDays"], 0)
        self.assertEqual(vwap["evidenceState"], "insufficient_independent_days")
        self.assertIsNone(vwap["outOfSampleMeanReturnPercent"])
        self.assertEqual(vwap["samples"], [])

        extreme_recovery = [session_for(day, ("1e308", "1e-300", "1e308"),
                                        ((9, 31), (9, 32), (14, 25)))
                            for day in days]
        recovery = build_morning_selloff_recovery_evidence(
            extreme_recovery, research_as_of=self.now,
            minimum_independent_days=1, minimum_out_of_sample_days=1,
            maximum_monthly_concentration=1.0)
        self.assertEqual(recovery["rejectedNumericObservations"], 2)
        self.assertEqual(recovery["independentDays"], 0)
        self.assertEqual(recovery["evidenceState"], "insufficient_independent_days")
        self.assertIsNone(recovery["outOfSampleMedianRecoveryPercent"])
        self.assertEqual(recovery["samples"], [])

        extreme_grid = [session_for(day, ("1", "0.98", "1.01"),
                                    ((9, 31), (9, 32), (9, 33)))
                        for day in days]
        grid = replay_grid_spacing_evidence(
            extreme_grid, research_as_of=self.now, spacing_percentages=(Decimal("1"),),
            units=10 ** 400, minimum_independent_days=1,
            minimum_out_of_sample_days=1, maximum_monthly_concentration=1.0
        )["spacings"]["1"]
        self.assertEqual(grid["rejectedNumericObservations"], 2)
        self.assertEqual(grid["independentDays"], 0)
        self.assertEqual(grid["evidenceState"], "insufficient_independent_days")
        self.assertEqual(grid["totalObservedCompletedRoundTrips"], 0)
        self.assertIsNone(grid["outOfSampleNetAfterFees"])
        self.assertEqual(grid["sessions"], [])

    def test_walk_forward_holdout_is_chronological_and_uses_independent_months(self):
        sessions = []
        for month in (8, 9, 10, 11, 12):
            day = date(2026, month, 8)
            points = []
            for index, price in enumerate(("10", "9", "8", "8.5")):
                stamp = datetime.combine(day, datetime.min.time(), tzinfo=UTC) + timedelta(hours=9, minutes=31 + index)
                points.append({"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
                               "fetched_at": (stamp + timedelta(minutes=1)).isoformat(),
                               "price": price, "minute_volume": 10, "volume_method": "source_minute",
                               "data_quality": 98, "source_trust": 99, "source": "fixture"})
            sessions.append({"tradingDate": day.isoformat(), "complete": True, "bars": points})
        evidence = build_vwap_break_evidence(
            sessions, research_as_of=datetime(2027, 1, 1, tzinfo=UTC), horizons_minutes=(1,),
            minimum_independent_days=4, minimum_out_of_sample_days=1)
        result = evidence["windows"]["1"]
        self.assertEqual(result["trainingDays"], 4)
        self.assertEqual(result["outOfSampleDays"], 1)
        self.assertEqual(result["outOfSample"]["startDate"], "2026-12-08")
        self.assertEqual(result["maxMonthlySampleShare"], 0.2)
        self.assertEqual(result["evidenceState"], "available_for_review")

    def test_vwap_headline_metrics_are_chronological_holdout_only(self):
        sessions = []
        for month, prices in zip((8, 9, 10, 11, 12),
                                 (("10", "9", "8", "8.5"),) * 4 + (("10", "9", "8", "10"),)):
            day = date(2026, month, 10)
            start = datetime.combine(day, datetime.min.time(), tzinfo=UTC).replace(hour=9, minute=31)
            sessions.append({"tradingDate": day.isoformat(), "complete": True,
                             "bars": [research_row(start + timedelta(minutes=index), price)
                                      for index, price in enumerate(prices)]})

        result = build_vwap_break_evidence(
            sessions, research_as_of=datetime(2027, 1, 1, tzinfo=UTC), horizons_minutes=(2,),
            minimum_independent_days=4, minimum_out_of_sample_days=1)["windows"]["2"]

        self.assertEqual(result["evidenceState"], "available_for_review")
        self.assertEqual(result["headlinePopulation"], "out_of_sample")
        self.assertLess(result["trainingMedianReturnPercent"], 0)
        self.assertGreater(result["outOfSampleMedianReturnPercent"], 0)
        self.assertEqual(result["medianReturnPercent"], result["outOfSampleMedianReturnPercent"])

    def test_morning_recovery_headline_rate_uses_only_oos_holdout(self):
        local_zone = timezone(timedelta(hours=8))
        sessions = []
        for month, close in zip((8, 9, 10, 11, 12), ("9.7", "9.7", "9.7", "9.7", "10.2")):
            day = date(2026, month, 10)
            rows = [research_row(datetime.combine(day, time(9, 31), local_zone), "10"),
                    research_row(datetime.combine(day, time(9, 32), local_zone), "9.8"),
                    research_row(datetime.combine(day, time(14, 29), local_zone), close)]
            sessions.append({"tradingDate": day.isoformat(), "timezone": "Asia/Shanghai",
                             "complete": True, "bars": rows})

        result = build_morning_selloff_recovery_evidence(
            sessions, research_as_of=datetime(2027, 1, 1, tzinfo=UTC),
            minimum_independent_days=4, minimum_out_of_sample_days=1)["recoveryRate"]
        evidence = build_morning_selloff_recovery_evidence(
            sessions, research_as_of=datetime(2027, 1, 1, tzinfo=UTC),
            minimum_independent_days=4, minimum_out_of_sample_days=1)

        self.assertEqual(evidence["headlinePopulation"], "out_of_sample")
        self.assertEqual(evidence["trainingRecoveryRate"], 0)
        self.assertEqual(result, 1)
        self.assertEqual(evidence["outOfSampleRecoveryRate"], result)

    def test_grid_headline_net_uses_only_oos_holdout(self):
        sessions = []
        training_prices = ("10", "9.8", "10.1", "10")
        holdout_prices = ("10", "9.8", "10.1", "9.8", "10.1", "9.8", "10.1")
        for month in (8, 9, 10, 11, 12):
            day = date(2026, month, 10)
            start = datetime.combine(day, datetime.min.time(), tzinfo=UTC).replace(hour=9, minute=31)
            prices = holdout_prices if month == 12 else training_prices
            sessions.append({"tradingDate": day.isoformat(), "complete": True,
                             "bars": [research_row(start + timedelta(minutes=index), price)
                                      for index, price in enumerate(prices)]})

        result = replay_grid_spacing_evidence(
            sessions, research_as_of=datetime(2027, 1, 1, tzinfo=UTC),
            spacing_percentages=(Decimal("1"),), units=10, minimum_independent_days=4,
            minimum_out_of_sample_days=1)["spacings"]["1"]

        self.assertEqual(result["headlinePopulation"], "out_of_sample")
        self.assertEqual(Decimal(result["netAfterFees"]), Decimal(result["outOfSampleNetAfterFees"]))
        self.assertNotEqual(result["netAfterFees"], str(sum(
            (Decimal(row["netAfterFees"]) for row in result["sessions"]), Decimal(0))))

    def test_grid_spacing_sweep_selects_on_training_and_withholds_other_holdouts(self):
        sessions = []
        training_prices = ("10", "9.9", "10.1", "10")
        holdout_prices = ("10", "9.8", "10.1", "10")
        for month in (8, 9, 10, 11, 12):
            day = date(2026, month, 10)
            start = datetime.combine(day, datetime.min.time(), tzinfo=UTC).replace(hour=9, minute=31)
            prices = holdout_prices if month == 12 else training_prices
            sessions.append({"tradingDate": day.isoformat(), "complete": True,
                             "bars": [research_row(start + timedelta(minutes=index), price)
                                      for index, price in enumerate(prices)]})

        result = replay_grid_spacing_evidence(
            sessions, research_as_of=datetime(2027, 1, 1, tzinfo=UTC),
            spacing_percentages=(Decimal("1"), Decimal("2")), units=10,
            minimum_independent_days=4, minimum_out_of_sample_days=1)

        self.assertEqual(result["selectedSpacing"], "1")
        self.assertEqual(result["selectionPolicy"],
                         "highest positive training mean net-after-fees; ties choose smaller spacing; only one holdout reported")
        self.assertEqual(result["spacings"]["1"]["evidenceState"], "available_for_review")
        self.assertTrue(result["spacings"]["1"]["selectedByTraining"])
        self.assertEqual(result["spacings"]["2"]["evidenceState"], "not_selected_by_training")
        self.assertFalse(result["spacings"]["2"]["selectedByTraining"])
        self.assertIsNone(result["spacings"]["2"]["outOfSample"])
        self.assertIsNone(result["spacings"]["2"]["outOfSampleNetAfterFees"])

    def test_temporal_concentration_fails_closed_without_publishing_summary(self):
        sessions = []
        for day_number in range(1, 6):
            day = date(2026, 10, day_number)
            points = []
            for index, price in enumerate(("10", "9", "8", "8.5")):
                stamp = datetime.combine(day, datetime.min.time(), tzinfo=UTC) + timedelta(hours=9, minutes=31 + index)
                points.append({"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
                               "fetched_at": (stamp + timedelta(minutes=1)).isoformat(),
                               "price": price, "minute_volume": 10, "volume_method": "source_minute",
                               "data_quality": 98, "source_trust": 99, "source": "fixture"})
            sessions.append({"tradingDate": day.isoformat(), "complete": True, "bars": points})
        evidence = build_vwap_break_evidence(
            sessions, research_as_of=datetime(2026, 11, 1, tzinfo=UTC), horizons_minutes=(1,),
            minimum_independent_days=3, minimum_out_of_sample_days=1)
        result = evidence["windows"]["1"]
        self.assertEqual(result["evidenceState"], "insufficient_temporal_diversity")
        self.assertEqual(result["maxMonthlySampleShare"], 1.0)
        self.assertIsNone(result["medianReturnPercent"])

    def test_morning_selloff_recovery_uses_local_market_time_and_cutoff(self):
        local_zone = timezone(timedelta(hours=8))
        stamps = [datetime(2026, 10, 8, 9, 31, tzinfo=local_zone),
                  datetime(2026, 10, 8, 11, 29, tzinfo=local_zone),
                  datetime(2026, 10, 8, 14, 29, tzinfo=local_zone)]
        rows = [{"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
                 "fetched_at": (stamp + timedelta(minutes=1)).isoformat(), "price": price,
                 "minute_volume": 100, "volume_method": "source_minute", "data_quality": 98,
                 "source_trust": 99, "source": "fixture"}
                for stamp, price in zip(stamps, ("10", "9.8", "9.9"))]
        session = {"tradingDate": DAY.isoformat(), "timezone": "Asia/Shanghai",
                   "complete": True, "bars": rows}
        evidence = build_morning_selloff_recovery_evidence(
            [session], research_as_of=self.now, drop_threshold_percent=Decimal("1"),
            minimum_independent_days=1, minimum_out_of_sample_days=1,
            maximum_monthly_concentration=1.0)
        self.assertEqual(evidence["independentDays"], 1)
        self.assertEqual(evidence["evidenceState"], "insufficient_independent_days")
        cutoff_evidence = build_morning_selloff_recovery_evidence(
            [session], research_as_of=datetime(2026, 10, 8, 6, 20, tzinfo=UTC),
            minimum_independent_days=1, minimum_out_of_sample_days=1,
            maximum_monthly_concentration=1.0)
        self.assertEqual(cutoff_evidence["independentDays"], 0)

    def test_grid_spacing_replay_uses_close_only_and_bilateral_fees(self):
        local_zone = timezone(timedelta(hours=8))
        stamps = [datetime(2026, 10, 8, 9, 31 + index, tzinfo=local_zone) for index in range(4)]
        rows = [{"timestamp": stamp.isoformat(), "source_timestamp": stamp.isoformat(),
                 "fetched_at": self.now.isoformat(), "price": price, "minute_volume": 100,
                 "volume_method": "source_minute", "data_quality": 98, "source_trust": 99,
                 "source": "fixture"}
                for stamp, price in zip(stamps, ("10", "9.9", "10.1", "9.9"))]
        session = {"tradingDate": DAY.isoformat(), "complete": True, "bars": rows}
        evidence = replay_grid_spacing_evidence(
            [session], research_as_of=self.now, spacing_percentages=(Decimal("1"),),
            units=1, fee_per_side=Decimal("0.10"), minimum_independent_days=1,
            minimum_out_of_sample_days=1, maximum_monthly_concentration=1.0)
        result = evidence["spacings"]["1"]
        self.assertEqual(result["independentDays"], 1)
        self.assertIn("close-only", evidence["fillModel"])
        self.assertEqual(result["sessions"][0]["completedRoundTrips"], 1)
        self.assertEqual(Decimal(result["sessions"][0]["netAfterFees"]), Decimal("-0.101"))
        self.assertIsNone(evidence["tradePlan"])


    def test_ingest_batch_rolls_back_atomically_after_database_failure(self):
        rows = bars(self.session)
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute("CREATE TRIGGER reject_second BEFORE INSERT ON minute_bar "
                       "WHEN NEW.timestamp LIKE '%09:32:00%' "
                       "BEGIN SELECT RAISE(ABORT,'injected failure'); END")
        with self.assertRaises(sqlite3.IntegrityError):
            self.archive.ingest(rows, mode="backfill")
        self.assertEqual(self.archive.query_day("159352", "CN", DAY), [])
        with closing(sqlite3.connect(self.path)) as db, db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM minute_observation").fetchone()[0], 0)

    def test_cumulative_volume_regression_marks_session_partial(self):
        rows = bars(self.session, fetched=self.now)
        bad = list(rows)
        row = bad[2]
        bad[2] = MinuteBar(row.security_code, row.market, row.trading_date, row.timestamp,
                           row.price, 1, row.minute_volume, "cumulative_delta", row.source,
                           row.fetched_at, row.source_timestamp, row.data_quality,
                           row.source_trust, row.completeness)
        self.archive.ingest(bad, mode="realtime")
        report = self.archive.evaluate_session("159352", self.session, evaluated_at=self.now)
        self.assertFalse(report["volumePassed"])
        self.assertEqual(report["status"], "partial")

        mismatch_archive = MinuteArchive(Path(self.tmp.name) / "delta-mismatch.sqlite")
        mismatch_rows = list(bars(self.session, fetched=self.now))
        mismatch_rows[2] = replace(mismatch_rows[2], minute_volume=2,
                                   volume_method="cumulative_delta")
        mismatch_archive.ingest(mismatch_rows, mode="backfill")
        mismatch_report = mismatch_archive.evaluate_session("159352", self.session,
                                                            evaluated_at=self.now)
        self.assertFalse(mismatch_report["volumePassed"])
        self.assertEqual(mismatch_report["status"], "partial")

    def test_diagnostics_count_expected_but_unarchived_sessions_as_missing(self):
        next_day = date(2026, 10, 12)
        missing_session = make_session(next_day)
        report = self.archive.diagnostics("159352", "CN", [missing_session])
        self.assertEqual(report["missingDays"], 1)
        self.assertEqual(report["archivedTradingDays"], 0)
        self.assertEqual(report["days"][0]["trading_date"], next_day.isoformat())
        self.assertEqual(report["days"][0]["status"], "missing")

    def test_diagnostics_repairs_unassessed_partial_day_after_ingest(self):
        self.archive.ingest(bars(self.session, fetched=self.now)[:2], mode="backfill")
        report = self.archive.diagnostics("159352", "CN", [self.session],
                                          evaluated_at=self.now)
        self.assertEqual(report["archivedTradingDays"], 1)
        self.assertEqual(report["partialDays"], 1)
        self.assertEqual(report["missingDays"], 0)
        self.assertEqual(report["days"][0]["status"], "partial")

    def test_diagnostics_missing_count_is_scoped_to_requested_calendar(self):
        older_session = make_session(date(2026, 10, 7))
        self.archive.evaluate_session("159352", older_session, evaluated_at=self.now)
        self.archive.evaluate_session("159352", self.session, evaluated_at=self.now)
        scoped = self.archive.diagnostics("159352", "CN", [self.session],
                                          evaluated_at=self.now)
        unscoped = self.archive.diagnostics("159352", "CN", evaluated_at=self.now)
        self.assertEqual(scoped["missingDays"], 1)
        self.assertEqual([day["trading_date"] for day in scoped["days"]], [DAY.isoformat()])
        self.assertEqual(unscoped["missingDays"], 2)
        self.assertEqual([day["trading_date"] for day in unscoped["days"]],
                         ["2026-10-07", DAY.isoformat()])
        self.assertTrue(all(day["count"] == 0 for day in unscoped["days"]))

    def test_diagnostics_report_dates_quality_and_database_size(self):
        self.archive.ingest(bars(self.session, fetched=self.now), mode="realtime")
        self.archive.evaluate_session("159352", self.session, evaluated_at=self.now)
        report = self.archive.diagnostics("159352", "CN")
        self.assertEqual(report["firstMinuteDate"], "2026-10-08")
        self.assertEqual(report["lastMinuteDate"], "2026-10-08")
        self.assertEqual(report["completeDays"], 1)
        self.assertGreater(report["databaseBytes"], 0)
        self.assertIsNotNone(report["lastRealtimeCollection"])
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute("DROP INDEX idx_collection_log_instrument_mode_fetched")
        MinuteArchive(self.path)
        with closing(sqlite3.connect(self.path)) as db, db:
            index_names = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='index'")}
        self.assertIn("idx_collection_log_instrument_mode_fetched", index_names)


if __name__ == "__main__":
    unittest.main()
