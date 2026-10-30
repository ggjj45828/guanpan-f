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

    func testBenchmarkMappingKeepsRegionalAndGlobalSensorsSeparate() {
        let nasdaq = FMarketBenchmarkMapping.resolve(securityCode: "159941")
        XCTAssertEqual(nasdaq?.market, .usNasdaq100)
        XCTAssertEqual(nasdaq?.primaryBenchmark, .nasdaq100)
        XCTAssertTrue(nasdaq?.secondaryBenchmarks.contains(.sp500) == true)
        XCTAssertFalse(nasdaq?.primaryBenchmark == .sseComposite)

        let a500 = FMarketBenchmarkMapping.resolve(securityCode: "159352")
        XCTAssertEqual(a500?.primaryBenchmark, .csiA500)
        XCTAssertEqual(a500?.secondaryBenchmarks, [.csi300, .sseComposite])
        XCTAssertTrue(a500?.globalSensors.contains(.kospi) == true)

        XCTAssertEqual(FMarketBenchmarkMapping.resolve(securityCode: "513000", instrumentName: "日经ETF")?.primaryBenchmark, .nikkei225)
        XCTAssertEqual(FMarketBenchmarkMapping.resolve(securityCode: "513330", instrumentName: "恒生ETF")?.primaryBenchmark, .hangSeng)
        XCTAssertEqual(FMarketBenchmarkMapping.resolve(securityCode: "513770", instrumentName: "韩国KOSPI ETF")?.primaryBenchmark, .kospi)
    }

    func testBenchmarkInputsRequireFreshTimestampedSourceObservations() {
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let future = FMarketBenchmarkObservation(benchmark: .csiA500, dailyReturn: -0.08,
            observedAt: now.addingTimeInterval(86_400), source: "fixture")
        let stale = FMarketBenchmarkObservation(benchmark: .sseComposite, dailyReturn: -0.08,
            observedAt: now.addingTimeInterval(-10 * 86_400), source: "fixture")
        let input = FMarketRegimeInput(market: "security:159352", securityCode: "159352",
            contextKind: mapping.market, asOf: now, sourceUpdatedAt: now, source: "fixture",
            bars: bars(flat()), benchmarkObservations: [future, stale], benchmarkMapping: mapping)
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.unavailableBenchmarks, [.csiA500])
        XCTAssertEqual(result.globalRegime, .uncertain)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
    }

    func testGlobalRiskOffNeedsSeveralIndependentFreshSensors() {
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159941")!
        let sensors: [FMarketBenchmarkObservation] = [
            .init(benchmark: .nasdaq100, dailyReturn: -0.05, observedAt: now, source: "fixture"),
            .init(benchmark: .sp500, dailyReturn: -0.05, observedAt: now, source: "fixture"),
            .init(benchmark: .hangSeng, dailyReturn: -0.05, observedAt: now, source: "fixture"),
            .init(benchmark: .nikkei225, dailyReturn: -0.05, observedAt: now, source: "fixture")
        ]
        let input = FMarketRegimeInput(market: "security:159941", securityCode: "159941",
            contextKind: mapping.market, asOf: now, sourceUpdatedAt: now, source: "fixture",
            bars: bars(flat()), benchmarkObservations: sensors, benchmarkMapping: mapping)
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.globalRegime, .riskOff)
        XCTAssertEqual(result.availableBenchmarks, [.nasdaq100])
        XCTAssertTrue(result.unavailableBenchmarks.isEmpty)
    }

    func testMissingPrimaryBenchmarkLeavesMappedMarketObservationOnly() {
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let input = FMarketRegimeInput(market: "security:159352", securityCode: "159352",
            contextKind: mapping.market, asOf: now, sourceUpdatedAt: now, source: "fixture",
            bars: bars(flat()), benchmarkMapping: mapping)
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.requiredBenchmarks, [.csiA500])
        XCTAssertEqual(result.unavailableBenchmarks, [.csiA500])
        XCTAssertEqual(result.globalRegime, .uncertain)
        XCTAssertTrue(result.observationOnly)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
    }

    func testInsufficientOrStaleDataFailsClosedAndMarksUnavailableFactors() {
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now.addingTimeInterval(-10 * 86_400), source: "fixture",
            bars: bars(flat(20)), breadthRatio: nil)
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.regime, .dataUnreliable)
        XCTAssertFalse(result.ordinaryTBuyAllowed)
        XCTAssertTrue(result.allowedStrategies.isEmpty)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertFalse(result.factors.first(where: { $0.key == "market_breadth" })?.available ?? true)
    }

    func testHistoricalReplayIgnoresFutureBars() {
        var series = bars(flat())
        series.append(FMarketRegimeBar(timestamp: now.addingTimeInterval(86_400), close: 50))
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: "fixture", bars: series, breadthRatio: 0.52)
        let result = FMarketRegimeEngine.evaluate(input, now: now)
        XCTAssertEqual(result.regime, .range)
        XCTAssertEqual(result.return20Sessions, 0)
        XCTAssertLessThanOrEqual(result.dataAsOf!, now)
    }

    func testIndependentCrashSignalsEscalateToExtremeAndPauseOrdinaryTBuy() {
        var prices = flat(75)
        prices.append(contentsOf: [92, 88, 84, 80, 75])
        var volumes = Array(repeating: 100.0, count: prices.count)
        for index in (prices.count - 5)..<prices.count { volumes[index] = 400 }
        let input = FMarketRegimeInput(market: "CN", asOf: now,
            sourceUpdatedAt: now, source: "fixture", bars: bars(prices, volumes: volumes),
            breadthRatio: 0.20, synchronizedBenchmarkReturns: [-0.08, -0.06, 0.01])
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
            sourceUpdatedAt: now, source: "fixture", bars: bars(prices), breadthRatio: 0.5)
        let previous = FMarketRegimeMemory(confirmedRegime: .range, confirmedRiskLevel: .r0Normal,
            lastEvaluationAt: now.addingTimeInterval(-86_400))
        let result = FMarketRegimeEngine.evaluate(input, previous: previous, now: now)
        XCTAssertEqual(result.regime, FMarketRegime.range)
        XCTAssertEqual(result.memory.pendingRegime, FMarketRegime.bullTrend)
        XCTAssertEqual(result.memory.pendingRegimeSessions, 1)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
