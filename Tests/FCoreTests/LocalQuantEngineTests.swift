import XCTest
@testable import FCore

final class LocalQuantEngineTests: XCTestCase {
    private func quote(now: Date, age: TimeInterval = 60,
                       gapAfterIndex: Int? = nil,
                       code: String = "159352",
                       source: String = FMarketQuoteTrustPolicy.tencentMinuteSource) throws
        -> FCurrentIntradaySnapshot {
        let fetchedAt = now.addingTimeInterval(-3)
        let lastTimestamp = now.addingTimeInterval(-age)
        let samples = (0..<20).map { index -> FMinuteSample in
            let price = 1.0 + Double(index) * 0.0002 + Double(index % 3) * 0.0001
            let gapOffset = gapAfterIndex.map { index > $0 ? 60.0 : 0.0 } ?? 0
            let timestamp = lastTimestamp.addingTimeInterval(Double(index - 19) * 60 + gapOffset)
            return FMinuteSample(timestamp: timestamp,
                                 price: Decimal(string: String(format: "%.6f", price))!,
                                 volume: Decimal(index < 15 ? 100 : 200))
        }
        return try FCurrentIntradaySnapshot(securityCode: code, samples: samples,
                                            quoteTimestamp: lastTimestamp, fetchedAt: fetchedAt,
                                            source: source)
    }

    private func rangeRegime(now: Date, dataAsOfOverride: Date? = nil,
                             omitDataAsOf: Bool = false,
                             code: String = "159352",
                             regime: FMarketRegime = .range,
                             risk: FMarketRiskLevel = .r0Normal) -> FMarketRegimeAssessment {
        let dataAsOf = omitDataAsOf ? nil : (dataAsOfOverride ?? now.addingTimeInterval(-86_400))
        let memory = FMarketRegimeMemory(confirmedRegime: regime,
                                         confirmedRiskLevel: risk,
                                         lastEvaluationAt: now.addingTimeInterval(-3_600))
        return FMarketRegimeAssessment(market: "security:\(code)", securityCode: code,
                                       regime: regime, riskLevel: risk, confidence: 80,
                                       factors: [], reasons: ["fixture"], dataAsOf: dataAsOf,
                                       movingAverages: [:], return5Sessions: nil,
                                       return20Sessions: nil, drawdown20Sessions: nil,
                                       realizedVolatility20Sessions: nil, volumeExpansion: nil,
                                       allowedStrategies: [.meanReversion], observationOnly: false,
                                       ordinaryTBuyAllowed: true, memory: memory)
    }

    private func indexRegime(now: Date, indexCode: String = "sh000510",
                             regime: FMarketRegime = .range,
                             risk: FMarketRiskLevel = .r0Normal,
                             dataAsOf: Date? = nil) -> FMarketRegimeAssessment {
        let memory = FMarketRegimeMemory(confirmedRegime: regime, confirmedRiskLevel: risk,
                                         lastEvaluationAt: now.addingTimeInterval(-3_600))
        let allowed: Set<FQuantStrategyKind>
        switch regime {
        case .bullTrend: allowed = [.trendPullback, .vwapDeviation, .maStructure]
        case .range: allowed = [.meanReversion, .vwapDeviation]
        case .bearTrend, .highVolatility, .recovery, .transition: allowed = [.maStructure]
        case .riskOff, .extremeRisk, .uncertain, .dataUnreliable: allowed = []
        }
        return FMarketRegimeAssessment(market: "index:\(indexCode)", securityCode: nil,
            regime: regime, riskLevel: risk, confidence: 80, factors: [], reasons: ["fixture"],
            dataAsOf: dataAsOf ?? now.addingTimeInterval(-86_400), movingAverages: [:],
            return5Sessions: nil, return20Sessions: nil, drawdown20Sessions: nil,
            realizedVolatility20Sessions: nil, volumeExpansion: nil,
            allowedStrategies: allowed, observationOnly: false,
            ordinaryTBuyAllowed: risk < .r3Severe, memory: memory)
    }

    func testProducesEightExplainableFactorsWithoutInventingCandidate() throws {
        let now = Date()
        let quote = try quote(now: now)
        let iopv = try FIOPVObservation(securityCode: "159352", value: Decimal(string: "1.01"),
                                        observedAt: now.addingTimeInterval(-5),
                                        fetchedAt: now.addingTimeInterval(-2),
                                        source: FMarketQuoteTrustPolicy.tencentReferenceSource,
                                        quality: .complete)
        let assessment = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: nil, regime: nil,
                                                    iopv: iopv, sessionStatus: .continuous, now: now)

        XCTAssertEqual(assessment.factors.map(\.kind), FLocalQuantFactorKind.allCases)
        XCTAssertTrue(assessment.factors.first(where: { $0.kind == .vwapDeviation })?.isAvailable == true)
        XCTAssertNotNil(assessment.factors.first(where: { $0.kind == .vwapDeviation })?.directionalScore)
        XCTAssertTrue(assessment.factors.first(where: { $0.kind == .iopvPremium })?.isAvailable == true)
        XCTAssertEqual(assessment.disposition, .wait)
        XCTAssertFalse(assessment.candidatePlanGenerated)
        XCTAssertTrue(assessment.strategies.allSatisfy { !$0.qualified })
    }

    func testFreshQuoteAndRangeRegimeStillWaitForQualifiedNASParameters() throws {
        let now = Date()
        let assessment = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
                                                    regime: rangeRegime(now: now), iopv: nil,
                                                    sessionStatus: .continuous,
                                                    mappedBenchmarkRegime: indexRegime(now: now),
                                                    mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
                                                    mappedBenchmarkIndexCode: "sh000510", now: now)
        let meanReversion = try XCTUnwrap(assessment.strategies.first { $0.strategy == .meanReversion })

        XCTAssertEqual(assessment.disposition, .noTrade)
        XCTAssertEqual(meanReversion.readiness, .awaitingQualifiedParameters)
        XCTAssertEqual(meanReversion.reasonCode, "nas_strategy_parameters_not_qualified")
        XCTAssertFalse(meanReversion.qualified)
        XCTAssertFalse(assessment.candidatePlanGenerated)
    }

    func testMappedBenchmarkIsSecuritySpecificFreshAndControlsStrategyReadiness() throws {
        let now = Date()
        let missing = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now), iopv: nil, sessionStatus: .continuous, now: now)
        XCTAssertEqual(missing.benchmarkIndexCode, "sh000510")
        XCTAssertNil(missing.benchmarkRegime)
        XCTAssertTrue(missing.reasonCodes.contains("mapped_benchmark_unavailable:sh000510"))
        XCTAssertTrue(missing.strategies.allSatisfy { $0.reasonCode == "mapped_benchmark_unavailable" })

        let fresh = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now), iopv: nil, sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "sh000510", now: now)
        XCTAssertEqual(fresh.benchmarkRegime, .range)
        XCTAssertEqual(fresh.strategies.first?.readiness, .awaitingQualifiedParameters)

        let nasdaq = FLocalQuantEngine.evaluate(quote: try quote(now: now, code: "159941"),
            dailyHistory: nil, regime: rangeRegime(now: now, code: "159941"), iopv: nil,
            sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now, indexCode: "usNDX"),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "usNDX", now: now)
        XCTAssertEqual(nasdaq.benchmarkIndexCode, "usNDX")
        XCTAssertEqual(nasdaq.benchmarkRegime, .range)

        let wrongIndex = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now), iopv: nil, sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now, indexCode: "usNDX"),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "usNDX", now: now)
        XCTAssertNil(wrongIndex.benchmarkRegime)
        XCTAssertTrue(wrongIndex.reasonCodes.contains("mapped_benchmark_unavailable:sh000510"))

        let stale = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now), iopv: nil, sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now,
                dataAsOf: now.addingTimeInterval(-6 * 86_400)),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "sh000510", now: now)
        XCTAssertNil(stale.benchmarkRegime)
        XCTAssertTrue(stale.reasonCodes.contains("mapped_benchmark_unavailable:sh000510"))

        let benchmarkDataAfterEvaluation = FLocalQuantEngine.evaluate(quote: try quote(now: now),
            dailyHistory: nil, regime: rangeRegime(now: now), iopv: nil,
            sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now, dataAsOf: now.addingTimeInterval(-600)),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "sh000510", now: now)
        XCTAssertNil(benchmarkDataAfterEvaluation.benchmarkRegime,
                     "Index bar data must not be later than the Regime evaluation time")

        let extreme = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now), iopv: nil, sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now, regime: .extremeRisk, risk: .r4Extreme),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "sh000510", now: now)
        XCTAssertEqual(extreme.benchmarkRegime, .extremeRisk)
        XCTAssertTrue(extreme.strategies.allSatisfy { $0.reasonCode == "mapped_benchmark_severe_risk" })

        let bear = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now), iopv: nil, sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now, regime: .bearTrend, risk: .r2High),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "sh000510", now: now)
        XCTAssertTrue(bear.strategies.allSatisfy {
            $0.readiness == .disabledByRegime && $0.reasonCode == "mapped_benchmark_disallows_strategy"
        })
    }

    func testSevereSecurityRiskDisablesLocalStrategiesDespiteBullRegimeTag() throws {
        let now = Date()
        let assessment = FLocalQuantEngine.evaluate(
            quote: try quote(now: now), dailyHistory: nil,
            regime: rangeRegime(now: now, regime: .bullTrend, risk: .r3Severe),
            iopv: nil, sessionStatus: .continuous,
            mappedBenchmarkRegime: indexRegime(now: now),
            mappedBenchmarkFetchedAt: now.addingTimeInterval(-30),
            mappedBenchmarkIndexCode: "sh000510", now: now)

        XCTAssertTrue(assessment.strategies.allSatisfy {
            $0.readiness == .disabledByRegime && $0.reasonCode == "security_regime_severe_risk"
        })
    }

    func testUnknownProviderCannotContributeLiveLocalQuantFactors() throws {
        let now = Date()
        let assessment = FLocalQuantEngine.evaluate(
            quote: try quote(now: now, source: "unconfigured-provider"), dailyHistory: nil,
            regime: nil, iopv: nil, sessionStatus: .continuous, now: now)

        XCTAssertEqual(assessment.quoteFreshness, .unverified)
        XCTAssertFalse(assessment.factors.first { $0.kind == .vwapDeviation }?.isAvailable ?? true)
        XCTAssertFalse(assessment.candidatePlanGenerated)
    }

    func testIOPVFactorRejectsUnknownOrStaleReferenceSource() throws {
        let now = Date()
        let untrusted = try FIOPVObservation(securityCode: "159352", value: 1.01,
            observedAt: now.addingTimeInterval(-5), fetchedAt: now.addingTimeInterval(-2),
            source: "unconfigured-provider", quality: .complete)
        let stale = try FIOPVObservation(securityCode: "159352", value: 1.01,
            observedAt: now.addingTimeInterval(-91), fetchedAt: now.addingTimeInterval(-90),
            source: FMarketQuoteTrustPolicy.tencentReferenceSource, quality: .complete)

        for iopv in [untrusted, stale] {
            let assessment = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
                regime: nil, iopv: iopv, sessionStatus: .continuous, now: now)
            XCTAssertFalse(assessment.factors.first { $0.kind == .iopvPremium }?.isAvailable ?? true)
        }
    }

    func testRegimeWithMissingFutureOrStaleDataTimeFailsClosed() throws {
        let now = Date()
        let quote = try quote(now: now)
        let missing = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: nil,
            regime: rangeRegime(now: now, omitDataAsOf: true), iopv: nil,
            sessionStatus: .continuous, now: now)
        let future = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: nil,
            regime: rangeRegime(now: now, dataAsOfOverride: now.addingTimeInterval(60)), iopv: nil,
            sessionStatus: .continuous, now: now)
        let stale = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: nil,
            regime: rangeRegime(now: now, dataAsOfOverride: now.addingTimeInterval(-6 * 86_400)), iopv: nil,
            sessionStatus: .continuous, now: now)

        for assessment in [missing, future, stale] {
            XCTAssertNil(assessment.marketRegime)
            XCTAssertEqual(assessment.disposition, .wait)
            XCTAssertTrue(assessment.reasonCodes.contains("security_regime_unavailable"))
            XCTAssertTrue(assessment.strategies.allSatisfy { $0.readiness == .unavailableRegime })
        }
    }

    func testStaleQuoteOrClosedSessionCannotProvideLiveFactors() throws {
        let now = Date()
        let stale = FLocalQuantEngine.evaluate(quote: try quote(now: now, age: 180),
                                               dailyHistory: nil, regime: nil, iopv: nil,
                                               sessionStatus: .continuous, now: now)
        let closed = FLocalQuantEngine.evaluate(quote: try quote(now: now), dailyHistory: nil,
                                                regime: nil, iopv: nil, sessionStatus: .closed,
                                                now: now)

        XCTAssertEqual(stale.disposition, .wait)
        XCTAssertEqual(stale.quoteFreshness, .stale)
        XCTAssertFalse(stale.factors.first(where: { $0.kind == .vwapDeviation })?.isAvailable == true)
        XCTAssertEqual(closed.disposition, .wait)
        XCTAssertFalse(closed.factors.first(where: { $0.kind == .shortMomentum })?.isAvailable == true)
    }

    func testShortHorizonFactorsRejectLargeGapsInMinuteSamples() throws {
        let now = Date()
        let gapped = FLocalQuantEngine.evaluate(quote: try quote(now: now, age: 180, gapAfterIndex: 9),
                                                dailyHistory: nil, regime: nil, iopv: nil,
                                                sessionStatus: .continuous, now: now)

        XCTAssertEqual(gapped.quoteFreshness, .fresh)
        XCTAssertFalse(gapped.factors.first(where: { $0.kind == .shortMomentum })?.isAvailable == true)
        XCTAssertFalse(gapped.factors.first(where: { $0.kind == .meanReversion })?.isAvailable == true)
        XCTAssertFalse(gapped.factors.first(where: { $0.kind == .volumeAnomaly })?.isAvailable == true)
    }

    func testFlatValidSeriesReportsZeroVolatilityInsteadOfUnavailable() throws {
        let now = Date()
        let fetchedAt = now.addingTimeInterval(-3)
        let samples = (0..<20).map { index in
            FMinuteSample(timestamp: now.addingTimeInterval(Double(index - 20) * 60),
                          price: Decimal(string: "1.25")!, volume: 100)
        }
        let quote = try FCurrentIntradaySnapshot(securityCode: "159352", samples: samples,
                                                 quoteTimestamp: samples.last!.timestamp,
                                                 fetchedAt: fetchedAt,
                                                 source: FMarketQuoteTrustPolicy.tencentMinuteSource)

        let assessment = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: nil, regime: nil,
                                                    iopv: nil, sessionStatus: .continuous, now: now)
        let volatility = try XCTUnwrap(assessment.factors.first { $0.kind == .intradayVolatility })
        let vwapDeviation = try XCTUnwrap(assessment.factors.first { $0.kind == .vwapDeviation })

        XCTAssertTrue(volatility.isAvailable)
        XCTAssertEqual(volatility.value, 0)
        XCTAssertTrue(vwapDeviation.isAvailable)
        XCTAssertEqual(vwapDeviation.value, 0)
    }

    func testVWAPAllowsSmallUnknownVolumeCoverageButRejectsPoorCoverage() throws {
        let now = Date()
        let complete = try quote(now: now)
        let oneUnknown = complete.samples.enumerated().map { index, sample in
            FMinuteSample(timestamp: sample.timestamp, price: sample.price,
                          volume: index == 0 ? nil : sample.volume)
        }
        let partial = try FCurrentIntradaySnapshot(
            securityCode: complete.securityCode, samples: oneUnknown,
            quoteTimestamp: complete.quoteTimestamp, fetchedAt: complete.fetchedAt,
            source: complete.source)
        let poorCoverage = complete.samples.enumerated().map { index, sample in
            FMinuteSample(timestamp: sample.timestamp, price: sample.price,
                          volume: index < 3 ? nil : sample.volume)
        }
        let incomplete = try FCurrentIntradaySnapshot(
            securityCode: complete.securityCode, samples: poorCoverage,
            quoteTimestamp: complete.quoteTimestamp, fetchedAt: complete.fetchedAt,
            source: complete.source)

        let usable = FLocalQuantEngine.evaluate(quote: partial, dailyHistory: nil,
            regime: nil, iopv: nil, sessionStatus: .continuous, now: now)
        let unavailable = FLocalQuantEngine.evaluate(quote: incomplete, dailyHistory: nil,
            regime: nil, iopv: nil, sessionStatus: .continuous, now: now)

        XCTAssertTrue(usable.factors.first { $0.kind == .vwapDeviation }?.isAvailable == true,
                      "A missing first delta must not permanently disable the VWAP factor")
        XCTAssertEqual(usable.factors.first { $0.kind == .vwapDeviation }?.qualityNote,
                       "VWAP仅使用已知成交量点：19/20（95%）；未知量点已忽略")
        XCTAssertFalse(unavailable.factors.first { $0.kind == .vwapDeviation }?.isAvailable ?? true,
                       "More than 10% unknown volume must fail closed")
    }

    func testTrendStructureRequiresAtLeastTwoAvailableMovingAverageHorizons() throws {
        let now = Date()
        let quote = try quote(now: now)
        let shortHistory = try dailyHistory(count: 20, now: now)
        let broaderHistory = try dailyHistory(count: 60, now: now)

        let short = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: shortHistory,
                                               regime: nil, iopv: nil,
                                               sessionStatus: .continuous, now: now)
        let broader = FLocalQuantEngine.evaluate(quote: quote, dailyHistory: broaderHistory,
                                                 regime: nil, iopv: nil,
                                                 sessionStatus: .continuous, now: now)

        XCTAssertFalse(short.factors.first { $0.kind == .trendStructure }?.isAvailable == true)
        XCTAssertEqual(short.factors.first { $0.kind == .trendStructure }?.unavailableReason,
                       "趋势均线或波动尺度不足")
        XCTAssertTrue(broader.factors.first { $0.kind == .trendStructure }?.isAvailable == true)
    }

    func testDailyQuantFactorsCarryTheirActualSourcesAndObservationTimes() throws {
        let now = Date()
        let quote = try quote(now: now)
        let history = try dailyHistory(count: 60, now: now)
        let assessment = FLocalQuantEngine.evaluate(
            quote: quote, dailyHistory: history, regime: nil, iopv: nil,
            sessionStatus: .continuous, now: now)
        let trend = try XCTUnwrap(assessment.factors.first { $0.kind == .trendStructure })
        let movingAverage = try XCTUnwrap(assessment.factors.first { $0.kind == .movingAverageStructure })
        let latestDailyBar = try XCTUnwrap(history.bars.last)

        XCTAssertEqual(trend.observedAt, quote.quoteTimestamp)
        XCTAssertEqual(trend.supportingDataAsOf, latestDailyBar.tradingDate)
        XCTAssertEqual(trend.source, "\(quote.source) + \(history.source)")
        XCTAssertEqual(movingAverage.observedAt, latestDailyBar.tradingDate,
                       "纯日线均线因子不能冒用实时行情时点")
        XCTAssertNil(movingAverage.supportingDataAsOf)
        XCTAssertEqual(movingAverage.source, history.source)
    }

    func testUntrustedDailyHistoryCannotContributeLocalQuantFactors() throws {
        let now = Date()
        let untrusted = try dailyHistory(count: 60, now: now, source: "unconfigured-daily-source")
        let assessment = FLocalQuantEngine.evaluate(
            quote: try quote(now: now), dailyHistory: untrusted, regime: nil,
            iopv: nil, sessionStatus: .continuous, now: now)

        XCTAssertFalse(assessment.factors.first { $0.kind == .movingAverageStructure }?.isAvailable ?? true)
        XCTAssertEqual(assessment.factors.first { $0.kind == .movingAverageStructure }?.unavailableReason,
                       "新鲜证券日K不可用")
        XCTAssertFalse(assessment.candidatePlanGenerated)
    }

    func testRecentlyFetchedDailyArchiveWithOldLastBarCannotContributeFactors() throws {
        let now = Date()
        let currentHistory = try dailyHistory(count: 60, now: now)
        let oldBars = currentHistory.bars.map { bar in
            FDailyBar(tradingDate: bar.tradingDate.addingTimeInterval(-6 * 86_400),
                      open: bar.open, close: bar.close, high: bar.high, low: bar.low, volume: bar.volume)
        }
        let staleHistory = try FDailyKlineSnapshot(
            securityCode: currentHistory.securityCode, bars: oldBars,
            fetchedAt: now.addingTimeInterval(-60), source: currentHistory.source,
            adjustment: currentHistory.adjustment)
        let assessment = FLocalQuantEngine.evaluate(
            quote: try quote(now: now), dailyHistory: staleHistory, regime: nil,
            iopv: nil, sessionStatus: .continuous, now: now)

        XCTAssertFalse(assessment.factors.first { $0.kind == .movingAverageStructure }?.isAvailable ?? true)
        XCTAssertEqual(assessment.factors.first { $0.kind == .movingAverageStructure }?.unavailableReason,
                       "新鲜证券日K不可用")
    }

    func testDailyBarAtFiveCalendarDayFreshnessBoundaryCanContributeFactors() throws {
        let now = Date()
        let currentHistory = try dailyHistory(count: 60, now: now)
        let boundaryBars = currentHistory.bars.map { bar in
            FDailyBar(tradingDate: bar.tradingDate.addingTimeInterval(-4 * 86_400),
                      open: bar.open, close: bar.close, high: bar.high, low: bar.low, volume: bar.volume)
        }
        let boundaryHistory = try FDailyKlineSnapshot(
            securityCode: currentHistory.securityCode, bars: boundaryBars,
            fetchedAt: now.addingTimeInterval(-60), source: currentHistory.source,
            adjustment: currentHistory.adjustment)
        let assessment = FLocalQuantEngine.evaluate(
            quote: try quote(now: now), dailyHistory: boundaryHistory, regime: nil,
            iopv: nil, sessionStatus: .continuous, now: now)

        XCTAssertTrue(assessment.factors.first { $0.kind == .movingAverageStructure }?.isAvailable == true)
    }

    func testMarketBarTrustPolicySeparatesNikkeiAndTencentDailySources() {
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedIndexDailySource(
            FMarketBarTrustPolicy.tencentDailySource, indexCode: "usNDX"))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedIndexDailySource(
            FMarketBarTrustPolicy.nikkeiDailyCloseSource, indexCode: "int_nikkei"))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedIndexDailySource(
            FMarketBarTrustPolicy.naverKospiDailySource, indexCode: "KOSPI"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedIndexDailySource(
            FMarketBarTrustPolicy.nikkeiDailyCloseSource, indexCode: "usNDX"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedIndexDailySource(
            FMarketBarTrustPolicy.tencentDailySource, indexCode: "int_nikkei"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedIndexDailySource(
            FMarketBarTrustPolicy.naverKospiDailySource, indexCode: "usNDX"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedSecurityDailySource(
            FMarketBarTrustPolicy.nikkeiDailyCloseSource))
    }

    func testMarketBarTrustPolicyRequiresKnownMinuteArchiveProvider() {
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedMinuteArchiveSource(
            FMarketBarTrustPolicy.tencentMinuteArchiveSource))
        XCTAssertTrue(FMarketBarTrustPolicy.isTrustedMinuteArchiveSource(
            FMarketBarTrustPolicy.eastmoneyMinuteArchiveSource))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedMinuteArchiveSource("unverified-provider"))
        XCTAssertFalse(FMarketBarTrustPolicy.isTrustedMinuteArchiveSource(nil))
    }

    private func dailyHistory(count: Int, now: Date,
                              source: String = FMarketBarTrustPolicy.tencentDailySource) throws -> FDailyKlineSnapshot {
        let fetchedAt = now.addingTimeInterval(-60)
        let bars = (0..<count).map { index in
            let date = now.addingTimeInterval(Double(index - count) * 86_400)
            return FDailyBar(tradingDate: date, open: 1, close: 1, high: 1,
                             low: 1, volume: 1_000)
        }
        return try FDailyKlineSnapshot(securityCode: "159352", bars: bars, fetchedAt: fetchedAt,
                                       source: source, adjustment: "不复权")
    }
}
