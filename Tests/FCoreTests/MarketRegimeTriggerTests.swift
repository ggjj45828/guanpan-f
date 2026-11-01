import XCTest
@testable import FCore

final class MarketRegimeTriggerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func assessment(crash: Bool, securityCode: String? = "159352",
                            insufficientHistory: Bool = false) -> FMarketRegimeAssessment {
        let closes: [Double]
        let breadth: FMarketRegimeBreadthObservation?
        let benchmarks: [FMarketRegimeBenchmarkObservation]
        let volumes: [Double]
        if crash {
            closes = Array(repeating: 100, count: 75) + [92, 88, 84, 80, 75]
            breadth = FMarketRegimeBreadthObservation(market: "CN",
                advancingCount: 20, decliningCount: 80,
                observedAt: now.addingTimeInterval(-60), capturedAt: now, source: "fixture")
            benchmarks = [
                FMarketRegimeBenchmarkObservation(marketContext: "CN", marketCode: "sh000001",
                    observedAt: now.addingTimeInterval(-60), capturedAt: now,
                    source: "fixture", sessionReturn: -0.08),
                FMarketRegimeBenchmarkObservation(marketContext: "CN", marketCode: "sz399001",
                    observedAt: now.addingTimeInterval(-60), capturedAt: now,
                    source: "fixture", sessionReturn: -0.06)
            ]
            volumes = Array(repeating: 100, count: 75) + Array(repeating: 400, count: 5)
        } else {
            closes = Array(repeating: 100, count: insufficientHistory ? 20 : 75)
            breadth = nil
            benchmarks = []
            volumes = []
        }
        let bars = closes.enumerated().map { index, close in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - closes.count + 1) * 86_400),
                             close: close, volume: volumes.isEmpty ? nil : volumes[index])
        }
        let market = securityCode.map { "security:\($0)" } ?? "CN"
        return FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: market, securityCode: securityCode, asOf: now,
                sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars,
                breadthObservation: breadth, benchmarkObservations: benchmarks),
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
                source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
                marketSessionStatus: .continuous))
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

    func testUnreliableMarketContextFailsClosed() throws {
        let context = assessment(crash: false, insufficientHistory: true)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
                                                     marketContext: context, now: now)
        XCTAssertEqual(context.regime, .dataUnreliable)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["DATA_UNRELIABLE"])
    }

    func testUnmappedMarketContextCannotTriggerSecurityCandidate() throws {
        let context = assessment(crash: false, securityCode: nil)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
                                                     marketContext: context, now: now)
        XCTAssertNil(context.securityCode)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["market_context_security_mismatch"])
    }

    func testBroadMarketRegimeCannotMasqueradeAsSecuritySpecificContext() throws {
        let bars = (0..<80).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 79) * 86_400), close: 100)
        }
        let broadMarket = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "CN", securityCode: "159352", asOf: now,
                sourceUpdatedAt: now, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars), now: now)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
            marketContext: broadMarket, now: now)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["market_context_security_mismatch"])
    }
}
