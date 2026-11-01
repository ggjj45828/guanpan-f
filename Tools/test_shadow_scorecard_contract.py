from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCORECARD = (ROOT / "Sources/FAdvisor/CandidateShadowScorecard.swift").read_text(encoding="utf-8")
TESTS = (ROOT / "Tests/FCoreTests/CandidateShadowScorecardTests.swift").read_text(encoding="utf-8")


class ShadowScorecardContractTests(unittest.TestCase):
    def test_only_trusted_fresh_quotes_can_trigger_or_count_toward_shadow(self) -> None:
        observation = SCORECARD.split("public struct FCandidateShadowMarketObservation", 1)[1].split(
            "public struct FCandidateShadowFillLink", 1
        )[0]
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted(source)", observation)
        self.assertIn("price > 0, NSDecimalNumber(decimal: price).doubleValue.isFinite", observation)
        self.assertIn("func isVerifiedFresh(maximumAge: TimeInterval)", observation)
        evaluation = SCORECARD.split("public func evaluation(asOf: Date)", 1)[1].split(
            "private func hasLeftZone", 1
        )[0]
        self.assertGreaterEqual(evaluation.count("isVerifiedFresh(maximumAge:"), 2)
        archive_validation = SCORECARD.split("public func validate() throws", 1)[1].split(
            "public func scorecard", 1
        )[0]
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted(observation.source)", archive_validation)
        self.assertIn("observation.isFresh ==", archive_validation)
        self.assertIn("testUntrustedShadowQuoteSourceIsRejectedAndDecodedArchiveIsRevalidated", TESTS)

    def test_triggered_plan_monitors_invalidation_through_outcome_window(self) -> None:
        evaluation = SCORECARD.split("public func evaluation(asOf: Date)", 1)[1].split(
            "private func hasLeftZone", 1
        )[0]
        invalidation = evaluation.split("let invalidated =", 1)[1].split("let status:", 1)[0]
        self.assertIn("market.first(where:", invalidation)
        self.assertNotIn("marketBeforeExpiry.first(where:", invalidation)
        self.assertIn("testTriggeredPlanStillDetectsInvalidationAfterPlanExpiry", TESTS)

    def test_completion_and_no_trigger_require_continuous_fresh_market_coverage(self) -> None:
        evaluation = SCORECARD.split("public func evaluation(asOf: Date)", 1)[1].split(
            "private func hasLeftZone", 1
        )[0]
        self.assertIn("Self.hasContinuousCoverage", evaluation)
        self.assertIn("outcomeCoverageComplete", evaluation)
        self.assertIn("trigger == nil && outcomeCoverageComplete", evaluation)
        self.assertIn("snapshot.hasTriggerCondition && trigger == nil", evaluation)
        self.assertIn("maximumFavorableExcursion: outcomeCoverageComplete ? directionalMoves.max() : nil", evaluation)
        self.assertIn("maximumAdverseExcursion: outcomeCoverageComplete ? directionalMoves.min() : nil", evaluation)
        self.assertIn("testWaitWithoutAPriceConditionIsNotCountedAsUntriggered", TESTS)
        self.assertIn("outcomeCoverageComplete ? .observationWindowComplete : .insufficientData", evaluation)
        self.assertIn("testSparseExpiredUntriggeredPlanIsNotCountedAsNoTrigger", TESTS)
        self.assertIn("testSparseTriggeredWindowIsInsufficientInsteadOfComplete", TESTS)

    def test_coverage_rejects_large_gaps_and_requires_both_window_edges(self) -> None:
        coverage = SCORECARD.split("private static func hasContinuousCoverage", 1)[1].split(
            "private func hasLeftZone", 1
        )[0]
        self.assertIn("first.quoteTimestamp.timeIntervalSince(start) <= maximumGap", coverage)
        self.assertIn("end.timeIntervalSince(last.quoteTimestamp) <= maximumGap", coverage)
        self.assertIn("gap <= maximumGap", coverage)

    def test_execution_link_requires_a_real_ledger_fill_and_matching_time(self) -> None:
        append = SCORECARD.split("public mutating func appendConfirmedExecution", 1)[1].split(
            "public mutating func appendExecutionReview", 1
        )[0]
        self.assertIn("ledgerSnapshot: FReadOnlyLedgerSnapshot", append)
        self.assertIn("ledgerSnapshot.confirmedFills.first { $0.id == link.confirmedFillID }", append)
        self.assertIn("confirmedFill.tradedAt == link.linkedAt", append)
        self.assertIn("confirmedFill.tradedAt <= ledgerSnapshot.capturedAt", append)
        self.assertIn("confirmedFill.instrumentCode == snapshot.securityCode", append)
        self.assertIn("link.units == confirmedFill.units", append)
        self.assertIn("ledgerAccountID == ledgerSnapshot.accountID", append)
        self.assertIn("不得将另一个账户的成交挂入当前Shadow", TESTS)
        self.assertIn("尚未到达成交时点的账本记录不得计入已执行", TESTS)
        self.assertIn("任意UUID不得伪装成账本已确认成交", TESTS)
        self.assertIn("成交时间必须与真实账本记录一致", TESTS)
        self.assertIn("关联份额必须等于账本实际成交份额", TESTS)
