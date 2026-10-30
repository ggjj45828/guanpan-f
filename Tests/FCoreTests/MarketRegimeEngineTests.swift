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
