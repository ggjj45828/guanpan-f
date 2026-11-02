from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MarketRegimeNumericContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = (ROOT / "Sources/FCore/MarketRegimeEngine.swift").read_text(encoding="utf-8")
        cls.local_quant = (ROOT / "Sources/FCore/LocalQuantEngine.swift").read_text(encoding="utf-8")
        cls.quality = (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8")
        cls.acceptance = (ROOT / "Tests/FCoreTests/MarketRegimeEngineTests.swift").read_text(encoding="utf-8")
        cls.trigger = (ROOT / "Sources/FCore/RealtimeQuantTrigger.swift").read_text(encoding="utf-8")
        cls.trigger_acceptance = (ROOT / "Tests/FCoreTests/RealtimeQuantTriggerTests.swift").read_text(encoding="utf-8")
        cls.index_timestamp = (ROOT / "Sources/FCore/MarketIndexTimestamp.swift").read_text(encoding="utf-8")
        cls.index_timestamp_acceptance = (ROOT / "Tests/FCoreTests/MarketIndexTimestampTests.swift").read_text(encoding="utf-8")
        cls.app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")

    def test_index_timestamps_reject_numeric_extraction_from_malformed_text(self):
        self.assertIn("digits.utf8.count == 12 || digits.utf8.count == 14", self.index_timestamp)
        self.assertIn("digits.utf8.allSatisfy({ (48...57).contains($0) })", self.index_timestamp)
        self.assertIn("testRejectsNonDigitAndNonAsciiTimestampPayloads", self.index_timestamp_acceptance)

    def test_index_timestamps_reject_ambiguous_dst_wall_times(self):
        self.assertIn("isAmbiguousLocalTime", self.index_timestamp)
        self.assertIn("matchingInstants.count > 1", self.index_timestamp)
        self.assertIn("testRejectsAmbiguousAndNonexistentNewYorkDaylightSavingTimes",
                      self.index_timestamp_acceptance)
        self.assertIn("testAcceptsUnambiguousNewYorkTimesOnBothSidesOfDaylightSavingChange",
                      self.index_timestamp_acceptance)

    def test_unavailable_core_factors_force_data_unreliable(self):
        self.assertIn(
            "let coreFactorsAreReliable = ma20 != nil && ma60 != nil && ret5 != nil && ret20 != nil &&",
            self.engine,
        )
        self.assertIn("drawdown20 != nil && vol20 != nil && trendSlope != nil", self.engine)
        self.assertIn("coreFactorsAreReliable &&", self.engine)
        self.assertIn("input.asOf <= now && previousMemoryIsValid", self.engine)
        self.assertIn("testFiniteButNumericallyUnusablePriceSeriesFailsClosed", self.acceptance)

    def test_non_finite_bar_timestamps_fail_closed(self):
        self.assertIn("hasInvalidBarTimestamp", self.engine)
        self.assertIn("!$0.timestamp.timeIntervalSince1970.isFinite", self.engine)
        self.assertIn("testNonFiniteBarTimestampMakesMarketRegimeUnreliable", self.acceptance)

    def test_malformed_in_scope_daily_bar_values_fail_closed(self):
        self.assertIn("hasInvalidBarValues", self.engine)
        self.assertIn("!hasValidPriceData($0)", self.engine)
        self.assertIn("private static func hasValidPriceData", self.engine)
        for condition in [
            "bar.close.isFinite, bar.close > 0",
            "present.allSatisfy(\\.isFinite)",
            "high >= max(open, bar.close)",
            "low <= min(open, bar.close)",
        ]:
            self.assertIn(condition, self.engine)
        self.assertIn("!hasInvalidBarValues", self.engine)
        self.assertIn("volumes.allSatisfy({ $0.isFinite && $0 >= 0 })", self.engine)
        self.assertIn("volume.isFinite, volume < 0", self.engine)
        self.assertIn("factor(\"daily_bar_values\"", self.engine)
        self.assertIn('reasons.append("invalid_daily_bar_values")', self.engine)
        self.assertIn('!["daily_bar_spacing", "daily_bar_values"].contains($0.key)', self.engine)
        self.assertIn("testMalformedInScopeDailyBarValuesFailClosed", self.acceptance)
        self.assertIn("testMalformedFutureBarDoesNotLeakIntoEarlierHistoricalReplay", self.acceptance)

    def test_intraday_samples_cannot_be_counted_as_daily_regime_sessions(self):
        self.assertIn("let hasIntradayBarSpacing = zip(uniqueBars, uniqueBars.dropFirst()).contains", self.engine)
        self.assertIn("< 12 * 60 * 60", self.engine)
        self.assertIn("dailyBarSpacingIsReliable", self.engine)
        self.assertIn('!["daily_bar_spacing", "daily_bar_values"].contains($0.key)', self.engine)
        self.assertIn("testIntradayBarsCannotMasqueradeAsDailyMarketRegimeHistory", self.acceptance)

    def test_ma250_is_a_real_classification_factor_and_conflicts_become_transition(self):
        self.assertIn('factor("trend_MA60_250"', self.engine)
        self.assertIn("longTermTrendSupportsBull", self.engine)
        self.assertIn("longTermTrendSupportsBear", self.engine)
        self.assertIn("hasTimeframeTrendConflict", self.engine)
        self.assertIn('result.append("short_long_trend_conflict")', self.engine)
        for acceptance in [
            "testMA250IsAnUnavailableFactorUntilFullHistoryExists",
            "testShortTermBullCannotOverrideBearishMA250Structure",
            "testShortTermBearCannotOverrideBullishMA250Structure",
            "testShortLongTimeframeConflictImmediatelyExitsRememberedBullTrend",
        ]:
            self.assertIn(acceptance, self.acceptance)

    def test_moving_average_uses_stable_incremental_mean(self):
        start = self.engine.index("private static func averageTail(")
        end = self.engine.index("private static func returnOver(", start)
        average = self.engine[start:end]
        self.assertIn("result += (value - result) / Double(offset + 2)", average)
        self.assertNotIn("tail.reduce(0, +)", average)
        self.assertIn("testMovingAverageAvoidsIntermediateOverflowForLargeFinitePrices", self.acceptance)

    def test_trigger_requires_fresh_same_security_regime_context(self):
        self.assertIn("guard let marketContext else", self.trigger)
        self.assertIn("marketContext.securityCode == quote.securityCode", self.trigger)
        self.assertIn('marketContext.market == "security:\\(quote.securityCode)"', self.trigger)
        mapping_acceptance = (ROOT / "Tests/FCoreTests/MarketRegimeTriggerTests.swift").read_text(encoding="utf-8")
        self.assertIn("testBroadMarketRegimeCannotMasqueradeAsSecuritySpecificContext", mapping_acceptance)
        self.assertIn("now.timeIntervalSince(regimeDataAsOf) <= 5 * 86_400", self.trigger)
        self.assertIn("regimeDataAsOf <= regimeMemoryEvaluatedAt", self.trigger)
        self.assertIn("regimeMemoryEvaluatedAt <= now", self.trigger)
        self.assertIn("now.timeIntervalSince(regimeMemoryEvaluatedAt) <= 5 * 86_400", self.trigger)
        self.assertIn("regimeDataAsOf <= quoteTimestamp", self.trigger)
        self.assertIn("regimeMemoryEvaluatedAt <= quoteTimestamp", self.trigger)
        self.assertIn('["market_context_postdates_quote"]', self.trigger)
        self.assertIn("testMissingMarketRegimeCannotProduceAnAssetChangingTrigger", self.trigger_acceptance)
        self.assertIn("testStaleMarketRegimeCannotProduceAnAssetChangingTrigger", self.trigger_acceptance)
        self.assertIn("testRegimeEvidenceLaterThanQuoteCannotTriggerFromOlderQuote",
                      self.trigger_acceptance)
        self.assertIn("dataAsOf <= quote.quoteTimestamp", self.local_quant)
        self.assertIn("assessment.memory.lastEvaluationAt <= quote.quoteTimestamp", self.local_quant)
        self.assertIn("observedAt <= quote.quoteTimestamp", self.local_quant)
        self.assertIn("lastEvaluation <= quote.quoteTimestamp", self.local_quant)
        self.assertIn("testRegimeEvidenceLaterThanQuoteCannotInfluenceLocalQuant",
                      (ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift").read_text(encoding="utf-8"))
        self.assertIn("testFutureOrInconsistentRegimeMemoryCannotProduceAnAssetChangingTrigger",
                      self.trigger_acceptance)

    def test_trigger_ignores_duplicate_and_out_of_order_quote_timestamps(self):
        self.assertIn("previousQuoteTimestamp: Date? = nil", self.trigger)
        self.assertIn("quoteTimestamp <= previousQuoteTimestamp", self.trigger)
        self.assertIn('"duplicate_or_out_of_order_quote_ignored"', self.trigger)
        self.assertIn("lastProcessedQuoteTimestamp: previousQuoteTimestamp", self.trigger)
        self.assertIn("public let lastProcessedQuoteTimestamp: Date?", self.trigger)
        self.assertIn("Every return path, including paused and terminal states", self.trigger)
        self.assertIn("func testEveryEarlyReturnPreservesMonotonicQuoteWatermark", self.trigger_acceptance)
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted(metadata.source)", self.trigger)
        self.assertIn("timestamp <= fetchedAt, fetchedAt <= now, timestamp <= now", self.trigger)
        self.assertIn("quote.securityCode == plan.securityCode", self.trigger)
        self.assertIn("testDuplicateOrOutOfOrderQuoteCannotAdvanceCandidateState", self.trigger_acceptance)

    def test_trigger_rejects_quote_captured_before_plan_validity(self):
        self.assertIn("quoteTimestamp >= plan.validFrom", self.trigger)
        self.assertIn('"quote_predates_plan_validity"', self.trigger)
        self.assertIn("testQuoteFromBeforePlanValidityCannotTriggerThePlan", self.trigger_acceptance)

    def test_a500_is_a_china_benchmark_and_has_issuer_sourced_security_mapping(self):
        self.assertIn('"sh000510"', self.engine)
        self.assertIn('securityCode: "159352", indexCode: "sh000510"', self.engine)
        self.assertIn("testA500BenchmarkCanContributeOnlyToChinaMarketRiskContext", self.acceptance)

    def test_regime_memory_is_reset_when_stale_or_from_the_future(self):
        self.assertIn("let memoryBarGap = latestBarTimestamp.timeIntervalSince(memory.lastEvaluationAt)",
                      self.engine)
        self.assertIn("if memoryBarGap < 0 || memoryBarGap > maximumDataAge", self.engine)
        self.assertIn("priorMemory = nil", self.engine)
        self.assertIn("testStaleRegimeMemoryCannotPreserveObsoleteConfirmedState", self.acceptance)
        self.assertIn("testFutureRegimeMemoryCannotLeakIntoHistoricalReplay", self.acceptance)

    def test_market_breadth_requires_fresh_timestamped_source_and_valid_counts(self):
        self.assertIn("public struct FMarketRegimeBreadthObservation", self.engine)
        self.assertIn("qualifiedBreadth($0, market: input.market, asOf: input.asOf", self.engine)
        self.assertIn("private static let maximumBreadthAge: TimeInterval = 2 * 60 * 60", self.engine)
        self.assertIn("addingReportingOverflow(observation.decliningCount)", self.engine)
        self.assertIn("observation.observedAt <= now", self.engine)
        self.assertIn("observation.market == market", self.engine)
        self.assertIn("item.marketContext == marketContext", self.engine)
        self.assertIn("allowedCodes.contains(item.marketCode)", self.engine)
        self.assertIn("item.sessionStartAt.map", self.engine)
        self.assertIn("latestStart.timeIntervalSince(earliestStart)", self.engine)
        self.assertIn("synchronizedBenchmarks(qualifiedBenchmarkObservations", self.engine)
        self.assertIn("observation.sessionStartAt", self.engine)
        self.assertIn("private static func permittedBenchmarkCodes(for marketContext: String)", self.engine)
        self.assertIn("testStaleFutureAndMalformedBreadthCannotAffectRiskClassification", self.acceptance)
        self.assertIn("FMarketRegimeEvidenceTrustPolicy.isTrustedBreadthSource", self.engine)
        self.assertIn("testUntrustedDailyBarProviderCannotProduceUsableMarketRegime", self.acceptance)
        self.assertIn("isTrustedRegimeHistorySource", self.engine)
        quality_source_policy = (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8")
        self.assertIn("case \"int_nikkei\":", quality_source_policy)
        self.assertIn("\"sh000510\", \"sz399006\", \"usNDX\", \"hkHSI\"", quality_source_policy)
        self.assertIn("testRegimeEvidenceTrustIsMarketSpecificAndBreadthFailsClosedWithoutProvider", self.acceptance)
        self.assertIn("testUnconfiguredBreadthSourceCannotAffectRiskClassification", self.acceptance)
        self.assertIn("testUnknownBenchmarkSourceCannotAffectRiskClassification", self.acceptance)
        self.assertIn("testIndexCannotCountItselfAsAnIndependentBenchmark", self.acceptance)

    def test_severe_risk_closes_all_regime_strategy_permissions(self):
        self.assertIn("guard reliable, riskLevel < .r3Severe else { return [] }", self.engine)
        self.assertIn("testSevereRiskBlocksStrategiesEvenWhenConfirmedRegimeIsBullish", self.acceptance)

    def test_security_regime_hysteresis_persists_and_reaches_advisor_context(self):
        refresh_start = self.app.index("    func refreshDailyKline(for code: String) async {")
        refresh_end = self.app.index("    private func researchSummaryStatus(", refresh_start)
        refresh = self.app[refresh_start:refresh_end]
        self.assertIn("regimeMemoryByCode[code] ?? loadRegimeMemory(for: code)", refresh)
        self.assertIn("previous: previousMemory", refresh)
        self.assertIn("UserDefaults.standard.set(data, forKey: regimeMemoryKey(for: code))", refresh)

        advisor_start = self.app.index("    private func runAdvisorQuestion(instrumentCode requestedCode: String?) async {")
        advisor_end = self.app.index("    func selectInstrument", advisor_start)
        advisor = self.app[advisor_start:advisor_end]
        self.assertIn('subject: code, source: "FCore Market Regime Engine"', advisor)
        self.assertIn("FDecisionContext(snapshot: freshLedger, observations: observations", advisor)
        self.assertIn("testOneAlignedBenchmarkCannotFormMultiMarketRiskSignal", self.acceptance)
        self.assertIn("testBenchmarkReturnsWithDifferentSessionStartDatesAreExcluded", self.acceptance)
        self.assertIn("testLegacyBenchmarkWithoutSessionStartDoesNotAffectRiskClassification", self.acceptance)
        self.assertIn("testDuplicateBenchmarkWithConflictingSessionStartsIsExcluded", self.acceptance)
        self.assertIn("Set(newest.compactMap(\\.sessionStartAt)).count == 1", self.engine)
        self.assertIn("public enum FMarketRegimeEvidenceTrustPolicy", self.quality)
        self.assertIn("FMarketBarTrustPolicy.nikkeiDailyCloseSource", self.quality)
        self.assertIn("FMarketBarTrustPolicy.tencentDailySource", self.quality)


if __name__ == "__main__":
    unittest.main()
