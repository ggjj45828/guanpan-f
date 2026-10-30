import XCTest
@testable import FCore

final class FLocalQuantEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot() throws -> (FCurrentIntradaySnapshot, FDailyKlineSnapshot, FMarketRegimeAssessment) {
        let dailyBars = (0..<70).map { index -> FDailyBar in
            let day = now.addingTimeInterval(Double(index - 69) * 86_400)
            return FDailyBar(tradingDate: day, open: 100, close: 100, high: 101, low: 99, volume: 1_000)
        }
        let daily = try FDailyKlineSnapshot(securityCode: "159352", bars: dailyBars,
            fetchedAt: now, source: "fixture-daily", adjustment: "不复权")
        let samples = (0..<20).map { index in
            FMinuteSample(timestamp: now.addingTimeInterval(Double(index - 20) * 60),
                          price: Decimal(string: "1.00")! + Decimal(index) / 10_000,
                          volume: 100)
        }
        let quote = try FCurrentIntradaySnapshot(securityCode: "159352", samples: samples,
            quoteTimestamp: samples.last!.timestamp, fetchedAt: now, source: "fixture-live")
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let indexBars = (0..<70).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 69) * 86_400), close: 100)
        }
        let history = FMarketBenchmarkHistory(benchmark: mapping.primaryBenchmark, bars: indexBars,
            sourceUpdatedAt: now, source: "fixture-index", sessionTimeZoneIdentifier: "Asia/Shanghai")
        let securityRegimeBars = dailyBars.map {
            FMarketRegimeBar(timestamp: $0.tradingDate,
                close: NSDecimalNumber(decimal: $0.close).doubleValue)
        }
        let regime = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "security:159352", securityCode: "159352",
                contextKind: mapping.market, asOf: now, sourceUpdatedAt: now, source: "fixture-security",
                bars: securityRegimeBars, benchmarkHistories: [history], benchmarkMapping: mapping),
            now: now)
        return (quote, daily, regime)
    }

    func testFreshInputsProduceOnlyExplicitlyUnqualifiedShadowScores() throws {
        let (quote, daily, regime) = try snapshot()
        let result = FLocalQuantEngine.evaluate(securityCode: "159352",
            quote: quote, daily: daily, marketRegime: regime, now: now)
        XCTAssertEqual(result.readiness, .shadowOnly)
        XCTAssertNil(result.strategyVersion)
        XCTAssertEqual(result.strategies.count, 3)
        XCTAssertEqual(result.factors.count, 8)
        XCTAssertTrue(result.strategies.allSatisfy { $0.score.map { (-100...100).contains($0) } ?? true })
        XCTAssertFalse(result.factors.first(where: { $0.key == "volume_anomaly" })?.available ?? true)
        XCTAssertFalse(result.factors.first(where: { $0.key == "premium_iopv" })?.available ?? true)
    }

    func testStaleQuoteFailsClosedBeforeScoring() throws {
        let (quote, daily, regime) = try snapshot()
        let result = FLocalQuantEngine.evaluate(securityCode: "159352",
            quote: quote, daily: daily, marketRegime: regime,
            now: now.addingTimeInterval(10 * 60))
        XCTAssertEqual(result.readiness, .unavailable)
        XCTAssertEqual(result.riskReasons, ["实时行情缺失、过期或标的代码不匹配"])
        XCTAssertTrue(result.strategies.isEmpty)
    }

    func testRecentDownloadCannotMakeStaleDailyBarsUsable() throws {
        let (quote, daily, regime) = try snapshot()
        let staleBars = daily.bars.map { bar in
            FDailyBar(tradingDate: bar.tradingDate.addingTimeInterval(-10 * 86_400),
                open: bar.open, close: bar.close, high: bar.high, low: bar.low, volume: bar.volume)
        }
        let staleDaily = try FDailyKlineSnapshot(securityCode: "159352", bars: staleBars,
            fetchedAt: now, source: "fixture-current-retrieval-stale-bars", adjustment: "不复权")
        let result = FLocalQuantEngine.evaluate(securityCode: "159352",
            quote: quote, daily: staleDaily, marketRegime: regime, now: now)
        XCTAssertEqual(result.readiness, .unavailable)
        XCTAssertEqual(result.riskReasons, ["真实日K缺失、过期或不足60个交易日"])
    }

    func testMissingPrimaryRegimeHistoryFailsClosed() throws {
        let (quote, daily, _) = try snapshot()
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let bars = (0..<70).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 69) * 86_400), close: 100)
        }
        let securityRegime = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "security:159352", securityCode: "159352",
                contextKind: mapping.market, asOf: now, sourceUpdatedAt: now,
                source: "fixture-security", bars: bars, benchmarkMapping: mapping), now: now)
        let result = FLocalQuantEngine.evaluate(securityCode: "159352",
            quote: quote, daily: daily, marketRegime: securityRegime, now: now)
        XCTAssertEqual(result.readiness, .unavailable)
        XCTAssertTrue(result.riskReasons.contains("主基准历史或市场Regime不可用"))
    }
}
