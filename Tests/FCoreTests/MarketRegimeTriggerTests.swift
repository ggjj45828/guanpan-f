import XCTest
@testable import FCore

final class MarketRegimeTriggerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func assessment(crash: Bool) -> FMarketRegimeAssessment {
        let closes: [Double]
        let breadth: Double?
        let benchmarks: [Double]
        let volumes: [Double]
        if crash {
            closes = Array(repeating: 100, count: 75) + [92, 88, 84, 80, 75]
            breadth = 0.20
            benchmarks = [-0.08, -0.06]
            volumes = Array(repeating: 100, count: 75) + Array(repeating: 400, count: 5)
        } else {
            closes = Array(repeating: 100, count: 20)
            breadth = nil
            benchmarks = []
            volumes = []
        }
        let bars = closes.enumerated().map { index, close in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - closes.count + 1) * 86_400),
                             close: close, volume: volumes.isEmpty ? nil : volumes[index])
        }
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        return FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "CN", securityCode: "159352",
                contextKind: mapping.market, asOf: now, sourceUpdatedAt: now,
                source: "fixture", bars: bars, breadthRatio: breadth,
                synchronizedBenchmarkReturns: benchmarks,
                benchmarkObservations: crash ? [
                    .init(benchmark: .csiA500, dailyReturn: -0.08, observedAt: now, source: "fixture")
                ] : [],
                benchmarkHistories: crash ? [
                    .init(benchmark: .csiA500, bars: bars, sourceUpdatedAt: now,
                          source: "fixture-index-history", sessionTimeZoneIdentifier: "Asia/Shanghai")
                ] : [], benchmarkMapping: mapping),
            now: now)
    }

    private func plan() throws -> FQuantTriggerPlan {
        try FQuantTriggerPlan(securityCode: "159352", direction: .tBuy,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(-60),
            validUntil: now.addingTimeInterval(600))
    }

    private func quote() throws -> FQuantQuoteSnapshot {
        try FQuantQuoteSnapshot(securityCode: "159352", price: Decimal(string: "1.104")!,
            temporalMetadata: FQuoteTemporalMetadata(
                quoteTimestamp: now.addingTimeInterval(-1), fetchedAt: now,
                source: "fixture", timestampTrust: .verifiedExchangeTimestamp,
                marketSessionStatus: .continuous))
    }

    func testExtremePrimaryIndexBlocksCalmSecurityTBuy() throws {
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let securityBars = (0..<70).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 69) * 86_400), close: 100)
        }
        let indexCloses = Array(repeating: 100.0, count: 70) + [90, 80, 70, 60, 50]
        let indexBars = indexCloses.enumerated().map { index, close in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - indexCloses.count + 1) * 86_400),
                             close: close)
        }
        let context = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "security:159352", securityCode: "159352",
                contextKind: mapping.market, asOf: now, sourceUpdatedAt: now, source: "fixture-security",
                bars: securityBars,
                benchmarkHistories: [
                    .init(benchmark: .csiA500, bars: indexBars, sourceUpdatedAt: now,
                          source: "fixture-index-history", sessionTimeZoneIdentifier: "Asia/Shanghai")
                ], benchmarkMapping: mapping), now: now)
        let result = FRealtimeQuantTrigger.evaluate(
            plan: try plan(), quote: try quote(), marketContext: context, now: now)
        XCTAssertEqual(context.regime, .range)
        XCTAssertEqual(context.marketRegime, .extremeRisk)
        XCTAssertEqual(context.marketRiskLevel, .r4Extreme)
        XCTAssertFalse(context.ordinaryTBuyAllowed)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["EXTREME_MARKET_RISK"])
    }

    func testExtremeMarketRiskBlocksTBuyCandidate() throws {
        let context = assessment(crash: true)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
                                                     marketContext: context, now: now)
        XCTAssertEqual(context.riskLevel, .r4Extreme)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["EXTREME_MARKET_RISK"])
        XCTAssertEqual(result.marketRegime, .extremeRisk)
        XCTAssertEqual(result.marketRiskLevel, .r4Extreme)
    }

    func testMissingPrimaryBenchmarkBlocksRealtimeCandidate() throws {
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let bars = (0..<70).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 69) * 86_400), close: 100)
        }
        let context = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "CN", securityCode: "159352", contextKind: mapping.market,
                asOf: now, sourceUpdatedAt: now, source: "fixture", bars: bars,
                benchmarkMapping: mapping), now: now)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
                                                     marketContext: context, now: now)
        XCTAssertEqual(context.regime, .range)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["PRIMARY_BENCHMARK_UNAVAILABLE"])
    }

    func testUnreliableMarketContextFailsClosed() throws {
        let context = assessment(crash: false)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
                                                     marketContext: context, now: now)
        XCTAssertEqual(context.regime, .dataUnreliable)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["DATA_UNRELIABLE"])
    }
}
