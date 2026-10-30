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
        return FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "CN", securityCode: "159352", asOf: now,
                sourceUpdatedAt: now, source: "fixture", bars: bars,
                breadthRatio: breadth, synchronizedBenchmarkReturns: benchmarks),
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
        let context = assessment(crash: false)
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote(),
                                                     marketContext: context, now: now)
        XCTAssertEqual(context.regime, .dataUnreliable)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["DATA_UNRELIABLE"])
    }
}
