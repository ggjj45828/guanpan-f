import XCTest
@testable import FCore

final class MarketRegimeEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func bars(_ closes: [Double], start: Date? = nil,
                      volumes: [Double]? = nil) -> [FMarketRegimeBar] {
        let origin = start ?? now.addingTimeInterval(-Double(closes.count - 1) * 86_400)
        return closes.enumerated().map { index, close in
            FMarketRegimeBar(timestamp: origin.addingTimeInterval(Double(index) * 86_400),
                             close: close, volume: volumes?[safe: index])
        }
    }

    private func flat(_ count: Int = 70) -> [Double] { Array(repeating: 100, count: count) }

    private func benchmark(_ marketCode: String, sessionReturn value: Double,
                           observedAt: Date? = nil, sessionStartAt: Date? = nil,
                           marketContext: String = "CN") -> FMarketRegimeBenchmarkObservation {
        let source: String
        switch marketCode {
        case "sh000001", "sz399001", "sh000300", "sh000510", "sz399006", "usNDX", "hkHSI":
            source = FMarketBarTrustPolicy.tencentDailySource
        case "int_nikkei": source = FMarketBarTrustPolicy.nikkeiDailyCloseSource
        default: source = "fixture"
        }
        let observedTime = observedAt ?? now.addingTimeInterval(-60)
        return FMarketRegimeBenchmarkObservation(marketContext: marketContext, marketCode: marketCode,
            observedAt: observedTime,
            sessionStartAt: sessionStartAt ?? observedTime.addingTimeInterval(-86_400), capturedAt: now,
            source: source, sessionReturn: value)
    }

    private func breadth(_ advancing: Int64, _ declining: Int64, market: String = "CN",
                         observedAt: Date? = nil, capturedAt: Date? = nil,
                         source: String = "fixture") -> FMarketRegimeBreadthObservation {
        FMarketRegimeBreadthObservation(market: market,
            advancingCount: advancing, decliningCount: declining,
            observedAt: observedAt ?? now.addingTimeInterval(-60),
            capturedAt: capturedAt ?? now, source: source)
    }

    func testETFIndexMappingRegistryIsExplicitAndIssuerSourced() {
        let a500Mapping = FMarketIndexSecurityMappingRegistry.mapping(for: "159352")
        XCTAssertEqual(a500Mapping?.indexCode, "sh000510")
        XCTAssertEqual(a500Mapping?.indexName, "中证A500")
        XCTAssertEqual(a500Mapping?.sourceURL,
                       "https://www.nffund.com/new/personal-financing/detail.html?fundCode=159352&tab=redemption-list")
        XCTAssertEqual(FMarketIndexSecurityMappingRegistry.mapping(for: "159352")?.indexCode,
                       "sh000510")
        let mapping = FMarketIndexSecurityMappingRegistry.mapping(for: "159941")
        XCTAssertEqual(mapping?.indexCode, "usNDX")
        XCTAssertEqual(mapping?.indexName, "Nasdaq-100")
        XCTAssertEqual(mapping?.sourceURL,
                       "https://www.gffunds.com.cn/funds/?fundcode=159941")
        XCTAssertNil(FMarketIndexSecurityMappingRegistry.mapping(for: "1599410"))
    }

    func testRegimeEvidenceTrustIsMarketSpecificAndBreadthFailsClosedWithoutProvider() {
        XCTAssertTrue(FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(
            FMarketBarTrustPolicy.tencentDailySource, indexCode: "usNDX"))
        XCTAssertFalse(FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(
            FMarketQuoteTrustPolicy.sinaIndexSource, indexCode: "usNDX"))
        XCTAssertTrue(FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(
            FMarketBarTrustPolicy.nikkeiDailyCloseSource, indexCode: "int_nikkei"))
        XCTAssertFalse(FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(
            "fixture", indexCode: "sh000510"))
        XCTAssertTrue(FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(
            FMarketBarTrustPolicy.naverKospiDailySource, indexCode: "KOSPI"))
        XCTAssertFalse(FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(
            FMarketQuoteTrustPolicy.naverIndexSource, indexCode: "KOSPI"))
        XCTAssertFalse(FMarketRegimeEvidenceTrustPolicy.isTrustedBreadthSource("fixture", market: "CN"))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            FMarketBarTrustPolicy.nikkeiDailyCloseSource, marketContext: "index:int_nikkei"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            FMarketBarTrustPolicy.tencentDailySource, marketContext: "index:int_nikkei"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            FMarketBarTrustPolicy.tencentDailySource, marketContext: "index:KOSPI"))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            FMarketBarTrustPolicy.naverKospiDailySource, marketContext: "index:KOSPI"))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            FMarketBarTrustPolicy.naverKospiDailySource, marketContext: "KR"))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            FMarketBarTrustPolicy.tencentDailySource, marketContext: "security:159352"))
    }

    func testUntrustedDailyBarProviderCannotProduceUsableMarketRegime() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: "fixture", bars: bars(flat()))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
    }

    func testSevereRiskBlocksStrategiesEvenWhenConfirmedRegimeIsBullish() {
        XCTAssertTrue(FMarketRegimeEngine.allowedStrategies(for: .bullTrend, riskLevel: .r3Severe).isEmpty)
        XCTAssertTrue(FMarketRegimeEngine.allowedStrategies(for: .range, riskLevel: .r4Extreme).isEmpty)
        XCTAssertFalse(FMarketRegimeEngine.allowedStrategies(for: .bullTrend, riskLevel: .r2High).isEmpty)
    }

    func testInsufficientOrStaleDataFailsClosedAndMarksUnavailableFactors() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now.addingTimeInterval(-10 * 86_400), source: "fixture",
            bars: bars(flat(20)))
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertFalse(result.factors.first(where: { $0.key == "market_breadth" })?.available ?? true)
    }

    func testIntradayBarsCannotMasqueradeAsDailyMarketRegimeHistory() {
        let series = (0..<70).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 69) * 60 * 60),
                             close: 100 + Double(index) * 0.01)
        }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: series,
            breadthObservation: breadth(50, 50))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
        XCTAssertFalse(result.factors.first(where: { $0.key == "daily_bar_spacing" })?.available ?? true)
    }

    func testFiniteButNumericallyUnusablePriceSeriesFailsClosed() {
        let prices = Array(repeating: 1e-300, count: 50) + Array(repeating: 1e300, count: 20)
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(prices), breadthObservation: breadth(50, 50))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
    }

    func testMovingAverageAvoidsIntermediateOverflowForLargeFinitePrices() {
        let prices = Array(repeating: Double.greatestFiniteMagnitude, count: 70)
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(prices), breadthObservation: breadth(50, 50))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.regime, .range)
        XCTAssertEqual(result.movingAverages[20]!, Double.greatestFiniteMagnitude,
                       accuracy: Double.greatestFiniteMagnitude * 1e-15)
        XCTAssertEqual(result.movingAverages[60]!, Double.greatestFiniteMagnitude,
                       accuracy: Double.greatestFiniteMagnitude * 1e-15)
        XCTAssertTrue(result.ordinaryTBuyAllowed)
    }

    func testMA250IsAnUnavailableFactorUntilFullHistoryExists() {
        let shortInput = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat(249)))
        let short = FMarketRegimeEngine.evaluate(shortInput, now: now)
        XCTAssertFalse(short.factors.first(where: { $0.key == "trend_MA60_250" })?.available ?? true)
        XCTAssertNil(short.movingAverages[250])

        let fullInput = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat(250)))
        let full = FMarketRegimeEngine.evaluate(fullInput, now: now)
        XCTAssertTrue(full.factors.first(where: { $0.key == "trend_MA60_250" })?.available ?? false)
        XCTAssertEqual(full.movingAverages[250], 100)
    }

    func testShortTermBullCannotOverrideBearishMA250Structure() {
        let prices = Array(repeating: 200.0, count: 190) +
            (0..<110).map { 80.0 + Double($0) * (40.0 / 109.0) }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(prices))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertLessThan(result.movingAverages[60]!, result.movingAverages[250]!)
        XCTAssertLessThan(result.factors.first(where: { $0.key == "trend_MA60_250" })?.value ?? 0, 0)
        XCTAssertEqual(result.regime, .transition)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.reasons.contains("short_long_trend_conflict"))
    }

    func testShortTermBearCannotOverrideBullishMA250Structure() {
        let risingBase = (0..<190).map { 100.0 + Double($0) * (100.0 / 189.0) }
        let fallingTail = (0..<60).map { 200.0 - Double($0) * (40.0 / 59.0) }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(risingBase + fallingTail))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertGreaterThan(result.movingAverages[60]!, result.movingAverages[250]!)
        XCTAssertGreaterThan(result.factors.first(where: { $0.key == "trend_MA60_250" })?.value ?? 0, 0)
        XCTAssertEqual(result.regime, .transition)
    }

    func testShortLongTimeframeConflictImmediatelyExitsRememberedBullTrend() {
        let risingBase = (0..<190).map { 100.0 + Double($0) * (100.0 / 189.0) }
        let fallingTail = (0..<60).map { 200.0 - Double($0) * (40.0 / 59.0) }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(risingBase + fallingTail))
        let priorBull = FMarketRegimeMemory(confirmedRegime: .bullTrend,
            confirmedRiskLevel: .r0Normal, lastEvaluationAt: now.addingTimeInterval(-86_400))

        let result = FMarketRegimeEngine.evaluate(input, previous: priorBull, now: now)

        XCTAssertEqual(result.regime, .transition)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.observationOnly)
        XCTAssertNil(result.memory.pendingRegime)
        XCTAssertTrue(result.reasons.contains("short_long_trend_conflict"))
    }

    func testHistoricalReplayIgnoresFutureBars() {
        var series = bars(flat())
        series.append(FMarketRegimeBar(timestamp: now.addingTimeInterval(86_400), close: 50))
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: series, breadthObservation: breadth(52, 48))
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.regime, .range)
        XCTAssertEqual(result.return20Sessions, 0)
        XCTAssertLessThanOrEqual(result.dataAsOf!, now)
    }

    func testNonFiniteBarTimestampMakesMarketRegimeUnreliable() {
        let invalid = FMarketRegimeBar(timestamp: Date(timeIntervalSince1970: -.infinity), close: 1)
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource,
            bars: bars(flat()) + [invalid])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
    }

    func testMalformedInScopeDailyBarValuesFailClosed() {
        let valid = bars(flat())
        let timestamp = valid.last!.timestamp
        let invalidBars = [
            FMarketRegimeBar(timestamp: timestamp, close: .nan),
            FMarketRegimeBar(timestamp: timestamp, close: 100, volume: -1),
            FMarketRegimeBar(timestamp: timestamp, close: 100, open: 100,
                             high: 99, low: 98, volume: 10),
            FMarketRegimeBar(timestamp: timestamp, close: 100, open: 100)
        ]

        for invalid in invalidBars {
            let input = FMarketRegimeInput(market: "CN", asOf: now,
                sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource,
                bars: Array(valid.dropLast()) + [invalid])
            let result = FMarketRegimeEngine.evaluate(input, now: now)
            XCTAssertEqual(result.regime, .dataUnreliable)
            XCTAssertEqual(result.confidence, 0)
            XCTAssertFalse(result.ordinaryTBuyAllowed)
            XCTAssertFalse(result.factors.first(where: { $0.key == "daily_bar_values" })?.available ?? true)
            XCTAssertTrue(result.reasons.contains("invalid_daily_bar_values"))
        }
    }

    func testMalformedFutureBarDoesNotLeakIntoEarlierHistoricalReplay() {
        var series = bars(flat())
        series.append(FMarketRegimeBar(timestamp: now.addingTimeInterval(86_400),
                                       close: .nan, volume: -.infinity))
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: series)
        let baseline = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()))

        let result = FMarketRegimeEngine.evaluate(input, now: now)
        let baselineResult = FMarketRegimeEngine.evaluate(baseline, now: now)

        XCTAssertEqual(result.regime, .range)
        XCTAssertEqual(result.return20Sessions, 0)
        XCTAssertEqual(result.confidence, baselineResult.confidence)
        XCTAssertTrue(result.factors.first(where: { $0.key == "daily_bar_values" })?.available ?? false)
    }

    func testConflictingDuplicateBarsFailClosedIndependentOfInputOrder() {
        let series = bars(flat())
        let latest = series.last!
        let conflict = FMarketRegimeBar(timestamp: latest.timestamp, close: 80, volume: 500)
        let forwardInput = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: series + [conflict])
        let reversedInput = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: [conflict] + series)

        let forward = FMarketRegimeEngine.evaluate(forwardInput, now: now)
        let reversed = FMarketRegimeEngine.evaluate(reversedInput, now: now)

        XCTAssertEqual(forward.regime, .dataUnreliable)
        XCTAssertEqual(reversed.regime, .dataUnreliable)
        XCTAssertFalse(forward.ordinaryTBuyAllowed)
        XCTAssertFalse(reversed.ordinaryTBuyAllowed)
        XCTAssertEqual(forward.return20Sessions, reversed.return20Sessions)
        XCTAssertEqual(forward.factors, reversed.factors)
    }

    func testFreshFetchCannotMakeOldMarketBarsReliable() {
        let staleBars = bars(flat(), start: now.addingTimeInterval(-100 * 86_400))
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: staleBars, breadthObservation: breadth(52, 48))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
        XCTAssertEqual(result.confidence, 0)
    }

    func testInvalidMaximumDataAgeFailsClosed() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()))

        for maximumAge in [TimeInterval.infinity, .nan, -1] {
            let result = FMarketRegimeEngine.evaluate(input, now: now,
                maximumDataAge: maximumAge)
            XCTAssertEqual(result.regime, .dataUnreliable)
            XCTAssertFalse(result.ordinaryTBuyAllowed)
            XCTAssertTrue(result.allowedStrategies.isEmpty)
        }
    }

    func testMalformedPreviousMemoryFailsClosedWithoutCounterOverflow() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()))
        let malformedMemories = [
            FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r0Normal,
                pendingRegime: .bullTrend, pendingRegimeSessions: .max,
                lastEvaluationAt: now.addingTimeInterval(-86_400)),
            FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r1Elevated,
                pendingRiskLevel: .r0Normal, pendingRiskSessions: .max,
                lastEvaluationAt: now.addingTimeInterval(-86_400)),
            FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r0Normal,
                pendingRegime: .bullTrend, pendingRegimeSessions: -1,
                lastEvaluationAt: now.addingTimeInterval(-86_400)),
            FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r0Normal,
                lastEvaluationAt: Date(timeIntervalSince1970: .infinity))
        ]

        for memory in malformedMemories {
            let result = FMarketRegimeEngine.evaluate(input, previous: memory, now: now)
            XCTAssertEqual(result.regime, .dataUnreliable)
            XCTAssertFalse(result.ordinaryTBuyAllowed)
            XCTAssertTrue(result.allowedStrategies.isEmpty)
            XCTAssertEqual(result.confidence, 0)
        }
    }

    func testIndependentCrashSignalsEscalateToExtremeAndPauseOrdinaryTBuy() {
        var prices = flat(75)
        prices.append(contentsOf: [92, 88, 84, 80, 75])
        var volumes = Array(repeating: 100.0, count: prices.count)
        for index in (prices.count - 5)..<prices.count { volumes[index] = 400 }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(prices, volumes: volumes),
            breadthObservation: breadth(20, 80), benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08),
                benchmark("sz399001", sessionReturn: -0.06),
                benchmark("usNDX", sessionReturn: 0.01)
            ])
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.riskLevel, .r4Extreme)
        XCTAssertEqual(result.regime, .extremeRisk)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertFalse(result.reasons.contains { $0.contains("probability") })
    }

    func testOrdinaryRegimeChangeWaitsForConfirmationSessions() {
        let fallingPrices: [Double] = (0..<50).map { index in
            100.0 - Double(index) * 0.1
        }
        let risingPrices: [Double] = (0..<20).map { index in
            95.2 + Double(index) * 0.75
        }
        let prices = fallingPrices + risingPrices
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(prices), breadthObservation: breadth(50, 50))
        let previous = FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r0Normal,
            lastEvaluationAt: now.addingTimeInterval(-86_400))
        let result = FMarketRegimeEngine.evaluate(input, previous: previous, now: now)
        XCTAssertEqual(result.regime, FMarketRegime.range)
        XCTAssertEqual(result.memory.pendingRegime, FMarketRegime.bullTrend)
        XCTAssertEqual(result.memory.pendingRegimeSessions, 1)
    }

    func testRefreshingSameDailyBarDoesNotCountAsAnotherConfirmationSession() {
        let fallingPrices: [Double] = (0..<50).map { index in
            100.0 - Double(index) * 0.1
        }
        let risingPrices: [Double] = (0..<20).map { index in
            95.2 + Double(index) * 0.75
        }
        let series = bars(fallingPrices + risingPrices)
        let previous = FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r1Elevated,
            pendingRegime: .bullTrend, pendingRegimeSessions: 1,
            pendingRiskLevel: .r0Normal, pendingRiskSessions: 1,
            lastEvaluationAt: now)
        let laterFetch = now.addingTimeInterval(60)
        let input = FMarketRegimeInput(market: "CN", asOf: laterFetch,
            sourceUpdatedAt: laterFetch, source: FMarketBarTrustPolicy.tencentDailySource, bars: series,
            breadthObservation: breadth(50, 50, observedAt: now.addingTimeInterval(-60), capturedAt: now))

        let result = FMarketRegimeEngine.evaluate(input, previous: previous, now: laterFetch)

        XCTAssertEqual(result.regime, .range)
        XCTAssertEqual(result.memory.pendingRegime, .bullTrend)
        XCTAssertEqual(result.memory.pendingRegimeSessions, 1)
        XCTAssertEqual(result.memory.confirmedRiskLevel, .r1Elevated)
        XCTAssertEqual(result.memory.pendingRiskLevel, .r0Normal)
        XCTAssertEqual(result.memory.pendingRiskSessions, 1)
        XCTAssertEqual(result.memory.lastEvaluationAt, now)
    }

    func testStaleRegimeMemoryCannotPreserveObsoleteConfirmedState() {
        let fallingPrices = (0..<70).map { 100.0 - Double($0) * 0.2 }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(fallingPrices))
        let staleBullMemory = FMarketRegimeMemory(confirmedRegime: .bullTrend,
            confirmedRiskLevel: .r0Normal,
            lastEvaluationAt: now.addingTimeInterval(-20 * 86_400))

        let result = FMarketRegimeEngine.evaluate(input, previous: staleBullMemory, now: now)

        XCTAssertEqual(result.regime, .bearTrend)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertNil(result.memory.pendingRegime)
    }

    func testFutureRegimeMemoryCannotLeakIntoHistoricalReplay() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()))
        let futureBullMemory = FMarketRegimeMemory(confirmedRegime: .bullTrend,
            confirmedRiskLevel: .r0Normal,
            lastEvaluationAt: now.addingTimeInterval(86_400))

        let result = FMarketRegimeEngine.evaluate(input, previous: futureBullMemory, now: now)

        XCTAssertEqual(result.regime, .range)
        XCTAssertTrue(result.ordinaryTBuyAllowed)
        XCTAssertNil(result.memory.pendingRegime)
    }

    func testStaleAndFutureBenchmarkObservationsAreUnavailableToRiskClassifier() {
        let stale = benchmark("sh000001", sessionReturn: -0.10,
                              observedAt: now.addingTimeInterval(-2 * 86_400))
        let future = FMarketRegimeBenchmarkObservation(
            marketContext: "CN", marketCode: "usNDX", observedAt: now.addingTimeInterval(60),
            capturedAt: now.addingTimeInterval(120), source: "fixture", sessionReturn: -0.10)
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [stale, future])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        let factor = result.factors.first(where: { $0.key == "fresh_benchmarks" })
        XCTAssertFalse(factor?.available ?? true)
        XCTAssertNil(factor?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testA500BenchmarkCanContributeOnlyToChinaMarketRiskContext() {
        let a500 = benchmark("sh000510", sessionReturn: -0.08)
        let chinaInput = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [a500])
        let usInput = FMarketRegimeInput(market: "US", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [a500])

        let china = FMarketRegimeEngine.evaluate(chinaInput, now: now)
        let us = FMarketRegimeEngine.evaluate(usInput, now: now)

        XCTAssertEqual(china.factors.first(where: { $0.key == "fresh_benchmarks" })?.value, 1)
        XCTAssertNil(us.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
    }

    func testStaleFutureAndMalformedBreadthCannotAffectRiskClassification() {
        let observations = [
            breadth(10, 90, observedAt: now.addingTimeInterval(-3 * 60 * 60)),
            breadth(10, 90, observedAt: now.addingTimeInterval(60),
                    capturedAt: now.addingTimeInterval(120)),
            breadth(10, 90, market: "hkHSI"),
            breadth(10, 90, source: "  "),
            breadth(.max, 1)
        ]

        for observation in observations {
            let input = FMarketRegimeInput(market: "CN", asOf: now,
                sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
                breadthObservation: observation)
            let result = FMarketRegimeEngine.evaluate(input, now: now)
            let factor = result.factors.first(where: { $0.key == "market_breadth" })

            XCTAssertNil(factor?.value)
            XCTAssertFalse(factor?.available ?? true)
            XCTAssertEqual(result.riskLevel, .r0Normal)
        }
    }

    func testUnconfiguredBreadthSourceCannotAffectRiskClassification() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            breadthObservation: breadth(20, 80))

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "market_breadth" })?.value)
        XCTAssertFalse(result.factors.first(where: { $0.key == "market_breadth" })?.available ?? true)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testUnknownBenchmarkSourceCannotAffectRiskClassification() {
        let untrusted = FMarketRegimeBenchmarkObservation(
            marketContext: "CN", marketCode: "sh000510", observedAt: now.addingTimeInterval(-60),
            capturedAt: now, source: "fixture", sessionReturn: -0.08)
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [untrusted])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testIndexCannotCountItselfAsAnIndependentBenchmark() {
        let input = FMarketRegimeInput(market: "index:sh000001", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [benchmark("sh000001", sessionReturn: -0.08,
                                               marketContext: "index:sh000001")])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testDuplicateBenchmarkMarketCannotCountAsIndependentCrashSignals() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08),
                benchmark("sh000001", sessionReturn: -0.08),
                benchmark("usNDX", sessionReturn: -0.08, marketContext: "US"),
                benchmark("usNDX", sessionReturn: -0.08, marketContext: "CN")
            ])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value, 1)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testConflictingLatestReturnsForSameBenchmarkAreExcluded() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08),
                benchmark("sh000001", sessionReturn: 0.02)
            ])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testOneAlignedBenchmarkCannotFormMultiMarketRiskSignal() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08,
                    observedAt: now.addingTimeInterval(-30 * 60 * 60)),
                benchmark("sz399001", sessionReturn: -0.06,
                    observedAt: now.addingTimeInterval(-5 * 60 * 60))
            ])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testSynchronizedBenchmarkDeclinesRemainAvailableToRiskClassifier() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08,
                    observedAt: now.addingTimeInterval(-12 * 60 * 60)),
                benchmark("sz399001", sessionReturn: -0.06,
                    observedAt: now.addingTimeInterval(-5 * 60 * 60))
            ])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertEqual(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value, 2)
        XCTAssertEqual(result.riskLevel, .r2High)
    }

    func testBenchmarkReturnsWithDifferentSessionStartDatesAreExcluded() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08,
                    observedAt: now.addingTimeInterval(-60), sessionStartAt: now.addingTimeInterval(-4 * 86_400)),
                benchmark("sz399001", sessionReturn: -0.06,
                    observedAt: now.addingTimeInterval(-60), sessionStartAt: now.addingTimeInterval(-86_460))
            ])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testLegacyBenchmarkWithoutSessionStartDoesNotAffectRiskClassification() {
        let legacy = FMarketRegimeBenchmarkObservation(
            marketContext: "CN", marketCode: "sh000001",
            observedAt: now.addingTimeInterval(-60), capturedAt: now,
            source: FMarketBarTrustPolicy.tencentDailySource, sessionReturn: -0.08)
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [legacy])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testDuplicateBenchmarkWithConflictingSessionStartsIsExcluded() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(flat()),
            benchmarkObservations: [
                benchmark("sh000001", sessionReturn: -0.08,
                    observedAt: now.addingTimeInterval(-60), sessionStartAt: now.addingTimeInterval(-86_460)),
                benchmark("sh000001", sessionReturn: -0.08,
                    observedAt: now.addingTimeInterval(-60), sessionStartAt: now.addingTimeInterval(-2 * 86_400))
            ])

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.factors.first(where: { $0.key == "fresh_benchmarks" })?.value)
        XCTAssertEqual(result.riskLevel, .r0Normal)
    }

    func testVolatilityExplanationUsesAnnualizedElevatedRiskThreshold() {
        func oscillatingPrices(dailyChange: Double) -> [Double] {
            var prices = [100.0]
            for index in 1..<80 {
                let change = index.isMultiple(of: 2) ? -dailyChange : dailyChange
                prices.append(prices[prices.count - 1] * (1 + change))
            }
            return prices
        }
        func assess(_ dailyChange: Double) -> FMarketRegimeAssessment {
            FMarketRegimeEngine.evaluate(
                FMarketRegimeInput(market: "CN", asOf: now, sourceUpdatedAt: now,
                    source: FMarketBarTrustPolicy.tencentDailySource, bars: bars(oscillatingPrices(dailyChange: dailyChange))),
                now: now)
        }

        let ordinary = assess(0.005) // About 8% annualized volatility.
        let elevated = assess(0.020) // About 32% annualized volatility.

        XCTAssertLessThan(ordinary.realizedVolatility20Sessions ?? .infinity, 0.25)
        XCTAssertFalse(ordinary.reasons.contains("volatility_expanded"))
        XCTAssertGreaterThanOrEqual(elevated.realizedVolatility20Sessions ?? 0, 0.25)
        XCTAssertEqual(elevated.riskLevel, .r1Elevated)
        XCTAssertTrue(elevated.reasons.contains("volatility_expanded"))
    }

    func testNonFiniteVolumeCannotEscalateRegimeRisk() {
        var series = bars(flat(80), volumes: Array(repeating: 100, count: 80))
        for index in (series.count - 5)..<series.count {
            let old = series[index]
            series[index] = FMarketRegimeBar(timestamp: old.timestamp, close: old.close,
                volume: .infinity)
        }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: series)

        let result = FMarketRegimeEngine.evaluate(input, now: now)

        XCTAssertNil(result.volumeExpansion)
        XCTAssertFalse(result.factors.first(where: { $0.key == "volume_expansion" })?.available ?? true)
        XCTAssertEqual(result.riskLevel, .r0Normal)
        XCTAssertEqual(result.regime, .range)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
