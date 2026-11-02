import XCTest
@_spi(LedgerStorage) import FCore
@testable import FAdvisor

private struct FixedResearchProvider: FAdvisorResearchProviding {
    let result: FDecisionResearchEvidence
    func evidence(for call: FAdvisorResearchToolCall) async throws -> FDecisionResearchEvidence {
        result
    }
}

private struct FixedCandidateModel: FAdvisorModelProviding {
    let result: FCandidateRecommendation
    func candidate(for request: FAdvisorQuestionRequest) async throws -> FCandidateRecommendation {
        result
    }
}

final class MarketChartAcceptanceTests: XCTestCase {
    private let zone = TimeZone(identifier: "Asia/Shanghai")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-23T08:00:00Z")!

    private func securityRegimeObservation(_ code: String = "159352",
                                          at timestamp: Date? = nil) -> FContextObservation {
        let timestamp = timestamp ?? now
        let asOf = timestamp.addingTimeInterval(-600)
        return FContextObservation(dataClass: .quantState, subject: code,
            source: "FCore Market Regime Engine",
            reference: "regime=range; risk=0; confidence=80; dataAsOf=\(ISO8601DateFormatter().string(from: asOf)); source=fixture; factors=trend=available",
            observedAt: timestamp.addingTimeInterval(-1), capturedAt: timestamp, decimalValue: 80)
    }

    private func mappedBenchmarkObservation(
        _ code: String = "159352", regime: FMarketRegime = .range,
        risk: FMarketRiskLevel = .r0Normal, at timestamp: Date? = nil
    ) throws -> FContextObservation {
        let timestamp = timestamp ?? now
        let mapping = try XCTUnwrap(FMarketIndexSecurityMappingRegistry.mapping(for: code))
        let asOf = timestamp.addingTimeInterval(-86_400)
        let asOfText = ISO8601DateFormatter().string(from: asOf)
        return FContextObservation(dataClass: .quantState,
            subject: "mapped-index:\(code)",
            source: "F Verified Issuer Index Mapping + NAS Daily Regime",
            reference: "indexCode=\(mapping.indexCode);indexName=\(mapping.indexName);mappingSource=\(mapping.sourceURL);mapping=issuer_benchmark;contextRole=benchmark_only;regime=\(regime.rawValue);risk=\(risk.rawValue);confidence=80;dataAsOf=\(asOfText);not_strategy_qualification=true",
            observedAt: timestamp.addingTimeInterval(-10), capturedAt: timestamp, decimalValue: 80)
    }

    func testClosedIndexQuoteShowsVerifiedMarketTime() {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: ISO8601DateFormatter().date(from: "2026-10-23T07:00:00Z"),
            fetchedAt: ISO8601DateFormatter().date(from: "2026-10-23T07:02:00Z"),
            source: FMarketQuoteTrustPolicy.tencentReferenceSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .closed)
        XCTAssertEqual(metadata.displayLabel(timeZone: zone), "已收盘 · 10月23日 15:00:00")
        XCTAssertEqual(metadata.freshness(at: now), .stale)
    }

    func testFetchedAtIsExplicitlyNotPresentedAsQuoteTime() {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: nil,
            fetchedAt: ISO8601DateFormatter().date(from: "2026-10-23T07:02:00Z"),
            source: "provider-without-timestamp", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .continuous)
        XCTAssertEqual(metadata.displayLabel(timeZone: zone), "获取于 15:02:00 · 行情时间未验证")
        XCTAssertEqual(metadata.freshness(at: now), .unverified)
        let observation = FContextObservation(dataClass: .quote, subject: "159352",
                                              source: "provider-without-timestamp",
                                              observedAt: nil, capturedAt: now,
                                              decimalValue: 1, quoteTemporalMetadata: metadata)
        XCTAssertNoThrow(try observation.validate(now: now))
        XCTAssertFalse(observation.isFresh(at: now))
    }

    func testMissingSourceTimeGetsAVisibleQualityLabel() {
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: nil,
                                              source: nil, timestampTrust: .unavailable,
                                              marketSessionStatus: .unknown)
        XCTAssertEqual(metadata.displayLabel(timeZone: zone), "时间未验证/来源未提供时间")
    }

    func testFreshnessUsesQuoteTimestampAndNotRetrievalTimestamp() {
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-30),
                                              fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource,
                                              timestampTrust: .verifiedExchangeTimestamp,
                                              marketSessionStatus: .continuous)
        XCTAssertEqual(metadata.freshness(at: now), .fresh)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: -1), .unverified)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: -.infinity), .unverified)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: .infinity), .unverified)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: .nan), .unverified)
        XCTAssertNotEqual(metadata.quoteTimestamp, metadata.fetchedAt)
        let observation = FContextObservation(dataClass: .quote, subject: "159352",
                                              source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp,
                                              capturedAt: now, decimalValue: 1,
                                              quoteTemporalMetadata: metadata)
        XCTAssertNoThrow(try observation.validate(now: now))
        XCTAssertTrue(observation.isFresh(at: now))
        let futureMetadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(1), fetchedAt: now.addingTimeInterval(2),
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let futureObservation = FContextObservation(dataClass: .quote, subject: "159352",
                                                   source: FMarketQuoteTrustPolicy.tencentMinuteSource,
                                                   observedAt: futureMetadata.quoteTimestamp,
                                                   capturedAt: now, decimalValue: 1,
                                                   quoteTemporalMetadata: futureMetadata)
        XCTAssertThrowsError(try futureObservation.validate(now: now.addingTimeInterval(10)))
    }

    func testUnknownProviderCannotBecomeDecisionGradeByUsingFreshTimestamp() {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-1), fetchedAt: now,
            source: "unconfigured-provider", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let observation = FContextObservation(dataClass: .quote, subject: "159352",
            source: "unconfigured-provider", observedAt: metadata.quoteTimestamp,
            capturedAt: now, decimalValue: 1, quoteTemporalMetadata: metadata)

        XCTAssertFalse(FMarketQuoteTrustPolicy.isTrusted("unconfigured-provider"))
        XCTAssertEqual(metadata.freshness(at: now), .unverified)
        XCTAssertFalse(observation.isFresh(at: now))
        XCTAssertTrue(metadata.displayLabel(timeZone: zone).contains("来源未验证"))
        XCTAssertTrue(FMarketQuoteTrustPolicy.isTrusted(FMarketQuoteTrustPolicy.tencentMinuteSource))
        XCTAssertTrue(FMarketQuoteTrustPolicy.isTrusted(FMarketQuoteTrustPolicy.eastmoneyMinuteSource))
        XCTAssertTrue(FMarketQuoteTrustPolicy.isTrusted(FMarketQuoteTrustPolicy.tencentReferenceSource))
        XCTAssertTrue(FMarketQuoteTrustPolicy.isTrusted(FMarketQuoteTrustPolicy.sinaIndexSource))
        XCTAssertTrue(FMarketQuoteTrustPolicy.isTrusted(FMarketQuoteTrustPolicy.naverIndexSource))
    }

    func testAvailableNewsObservationRequiresTrustedProviderAndPayload() throws {
        let untrusted = FContextObservation(dataClass: .news, subject: "CN/global market headlines",
            source: "unverified-news-source", reference: "{}", observedAt: now,
            capturedAt: now, decimalValue: 1)
        XCTAssertThrowsError(try untrusted.validate(now: now))

        let missingPayload = FContextObservation(dataClass: .news, subject: "CN/global market headlines",
            source: FNewsTrustPolicy.providerName, observedAt: now,
            capturedAt: now, decimalValue: 1)
        XCTAssertThrowsError(try missingPayload.validate(now: now))

        let verified = FContextObservation(dataClass: .news, subject: "CN/global market headlines",
            source: FNewsTrustPolicy.providerName, reference: "{}", observedAt: now,
            capturedAt: now, decimalValue: 1)
        XCTAssertNoThrow(try verified.validate(now: now))
    }

    func testDefaultLiveQuoteFreshnessBoundaryIs120Seconds() {
        let exactlyAtBoundary = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-FQuoteTemporalMetadata.defaultMaximumAge),
            fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let justOlder = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(-FQuoteTemporalMetadata.defaultMaximumAge - 0.001),
            fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)

        XCTAssertEqual(FQuoteTemporalMetadata.defaultMaximumAge, 120)
        XCTAssertEqual(FRealtimeQuantTrigger.defaultMaximumQuoteAge,
                       FQuoteTemporalMetadata.defaultMaximumAge)
        XCTAssertEqual(FContextDataClass.quote.maximumAge,
                       FQuoteTemporalMetadata.defaultMaximumAge)
        XCTAssertEqual(FContextDataClass.previousClose.maximumAge, 900)
        XCTAssertEqual(FContextDataClass.iopv.maximumAge, 90)
        XCTAssertEqual(exactlyAtBoundary.freshness(at: now), .fresh)
        XCTAssertEqual(justOlder.freshness(at: now), .stale)
    }

    func testKLineHitTestingSelectsFirstAndLastRenderedBars() {
        let centers = [10.0, 30.0, 50.0]
        XCTAssertEqual(FChartHitTesting.nearestPointIndex(tapX: 10, renderedCenters: centers,
                                                          hitRadius: 4), 0)
        XCTAssertEqual(FChartHitTesting.nearestPointIndex(tapX: 50, renderedCenters: centers,
                                                          hitRadius: 4), 2)
    }

    func testTapEquidistantBetweenBarsDoesNotGuess() {
        XCTAssertNil(FChartHitTesting.nearestPointIndex(tapX: 20,
                                                        renderedCenters: [10, 30], hitRadius: 10))
    }

    func testZoomedAndRotatedLayoutsUseRenderedCoordinates() {
        let transformedCenters = [108.0, 128.0, 148.0]
        XCTAssertEqual(FChartHitTesting.nearestPointIndex(tapX: 129,
                                                          renderedCenters: transformedCenters,
                                                          hitRadius: 6), 1)
    }

    func testDifferentScreenWidthUsesItsOwnLayoutCenters() {
        let narrow = [30.0, 90.0, 150.0]
        XCTAssertEqual(FChartHitTesting.nearestPointIndex(tapX: 149,
                                                          renderedCenters: narrow,
                                                          hitRadius: 8), 2)
    }

    func testChartPriceRangeIncludesVisibleRealOverlaysAndIOPV() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let first = fetchedAt.addingTimeInterval(-120)
        let second = fetchedAt.addingTimeInterval(-60)
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: second, fetchedAt: fetchedAt,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous)
        let chart = try FChartDataModel(securityCode: "159352", window: .liveIntraday,
            series: .minute([FMinuteSample(timestamp: first, price: 10),
                             FMinuteSample(timestamp: second, price: 11)]),
            quality: .complete, temporalMetadata: metadata)
        let cost = try FChartPriceOverlay(securityCode: "159352", kind: .cost,
            points: [FChartOverlayPoint(timestamp: first, value: 12),
                     FChartOverlayPoint(timestamp: second, value: 12)],
            quality: .complete, source: "confirmed ledger", fetchedAt: fetchedAt)
        let iopv = try FIOPVObservation(securityCode: "159352", value: 13,
            observedAt: second, fetchedAt: fetchedAt, source: "verified IOPV source",
            quality: .complete)
        let model = try FChartOverlayModel(chart: chart, priceOverlays: [cost], iopv: iopv)

        let range = try XCTUnwrap(model.priceRange())
        XCTAssertLessThan(range.lowerBound, 10)
        XCTAssertGreaterThan(range.upperBound, 13)
    }

    func testHistoricalIntradayChartExcludesCurrentIOPVFromPriceRange() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let first = fetchedAt.addingTimeInterval(-120)
        let second = fetchedAt.addingTimeInterval(-60)
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "verified-chart-source", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)
        let chart = try FChartDataModel(securityCode: "159352",
            window: .historicalIntraday(tradingDate: first),
            series: .minute([FMinuteSample(timestamp: first, price: 10),
                             FMinuteSample(timestamp: second, price: 11)]),
            quality: .complete, temporalMetadata: metadata)
        let currentIOPV = try FIOPVObservation(securityCode: "159352", value: 13,
            observedAt: second, fetchedAt: fetchedAt, source: "verified IOPV source",
            quality: .complete)
        let model = try FChartOverlayModel(chart: chart, iopv: currentIOPV)

        let range = try XCTUnwrap(model.priceRange())
        XCTAssertNil(model.liveIOPV)
        XCTAssertLessThan(range.upperBound, 12)
    }

    func testChartDataRejectsNonFiniteOrNegativeMinuteAndDailyValues() {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let first = fetchedAt.addingTimeInterval(-60)
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "verified-chart-source", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)

        XCTAssertThrowsError(try FChartDataModel(securityCode: "159352",
            window: .historicalIntraday(tradingDate: first),
            series: .minute([FMinuteSample(timestamp: first, price: -1)]),
            quality: .complete, temporalMetadata: metadata))
        XCTAssertThrowsError(try FChartDataModel(securityCode: "159352",
            window: .historicalIntraday(tradingDate: first),
            series: .minute([FMinuteSample(timestamp: first, price: 1, volume: -1)]),
            quality: .complete, temporalMetadata: metadata))
        XCTAssertThrowsError(try FChartDataModel(securityCode: "159352",
            window: .historicalIntraday(tradingDate: first),
            series: .minute([FMinuteSample(timestamp: first, price: .nan)]),
            quality: .complete, temporalMetadata: metadata))
        let infinity = Decimal.nan
        XCTAssertThrowsError(try FChartDataModel(securityCode: "159352",
            window: .historicalIntraday(tradingDate: first),
            series: .minute([FMinuteSample(timestamp: first, price: infinity)]),
            quality: .complete, temporalMetadata: metadata))
        XCTAssertThrowsError(try FIOPVObservation(securityCode: "159352", value: 1,
            observedAt: first, fetchedAt: Date(timeIntervalSince1970: .infinity),
            source: "fixture", quality: .complete))
        XCTAssertThrowsError(try FChartPriceOverlay(securityCode: "159352", kind: .cost,
            points: [FChartOverlayPoint(timestamp: Date(timeIntervalSince1970: .infinity), value: 1)],
            quality: .complete, source: "fixture", fetchedAt: fetchedAt))

        let invalidDaily = FDailyBar(tradingDate: first, open: 1, close: 1,
            high: 1, low: 1, volume: .nan)
        XCTAssertThrowsError(try FChartDataModel(securityCode: "159352", window: .daily,
            series: .daily([invalidDaily]), quality: .complete,
            temporalMetadata: metadata))
    }

    func testDailyVisibleRangeKeepsOffscreenHistoryMA250InPriceRange() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let start = fetchedAt.addingTimeInterval(-250 * 86_400)
        let bars = (0..<250).map { index -> FDailyBar in
            let close: Decimal = index == 249 ? 1_000 : 1
            return FDailyBar(tradingDate: start.addingTimeInterval(Double(index) * 86_400),
                open: close, close: close, high: close + 1, low: close, volume: 100)
        }
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "verified-daily-source", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)
        let chart = try FChartDataModel(securityCode: "159352", window: .daily,
            series: .daily(bars), quality: .complete, temporalMetadata: metadata)
        let viewport = try FChartInteractionModel(visibleRange: 249..<250, selectedIndex: nil,
            zoomScale: 12, crosshairEnabled: false, presentation: .inline, pointCount: 250)

        let range = try XCTUnwrap(FChartOverlayModel(chart: chart).priceRange(interaction: viewport))
        XCTAssertLessThan(range.lowerBound, 5) // visible MA250 is ~4.996; only the visible candle is near 1,000.
    }

    func testPriceRangeReturnsUnavailableWhenPaddingOverflowsDecimal() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let timestamp = fetchedAt.addingTimeInterval(-60)
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "fixture", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)
        let chart = try FChartDataModel(securityCode: "159352",
            window: .historicalIntraday(tradingDate: timestamp),
            series: .minute([FMinuteSample(timestamp: timestamp,
                price: Decimal.greatestFiniteMagnitude)]),
            quality: .complete, temporalMetadata: metadata)

        XCTAssertNil(try FChartOverlayModel(chart: chart).priceRange())
    }

    func testDailyMovingAverageAvoidsIntermediateDecimalOverflow() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let close = Decimal.greatestFiniteMagnitude / 3
        let start = fetchedAt.addingTimeInterval(-5 * 86_400)
        let bars = (0..<5).map { index in
            FDailyBar(tradingDate: start.addingTimeInterval(Double(index) * 86_400),
                open: close, close: close, high: close, low: close, volume: 0)
        }
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "fixture", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)
        let chart = try FChartDataModel(securityCode: "159352", window: .daily,
            series: .daily(bars), quality: .complete, temporalMetadata: metadata)

        let range = try XCTUnwrap(FChartOverlayModel(chart: chart).priceRange())

        XCTAssertTrue(range.lowerBound.isFinite)
        XCTAssertTrue(range.upperBound.isFinite)
    }

    func testHiddenMovingAveragesDoNotCompressVisiblePriceRange() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let start = fetchedAt.addingTimeInterval(-250 * 86_400)
        let bars = (0..<250).map { index -> FDailyBar in
            let close: Decimal = index >= 248 ? 100 + Decimal(index - 248) : 10
            return FDailyBar(tradingDate: start.addingTimeInterval(Double(index) * 86_400),
                open: close, close: close, high: close + 1, low: close - 1, volume: 100)
        }
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "verified-daily-source", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)
        let chart = try FChartDataModel(securityCode: "159352", window: .daily,
            series: .daily(bars), quality: .complete, temporalMetadata: metadata)
        let viewport = try FChartInteractionModel(visibleRange: 248..<250, selectedIndex: nil,
            zoomScale: 12, crosshairEnabled: false, presentation: .inline, pointCount: 250)

        let range = try XCTUnwrap(FChartOverlayModel(chart: chart).priceRange(
            interaction: viewport, visibleMovingAveragePeriods: []))
        XCTAssertGreaterThan(range.lowerBound, 90)
        XCTAssertLessThan(range.upperBound, 120)
    }

    func testHitTestingRejectsInvalidOrUnsortedCoordinates() {
        XCTAssertNil(FChartHitTesting.nearestPointIndex(tapX: .nan,
                                                        renderedCenters: [10, 20], hitRadius: 4))
        XCTAssertNil(FChartHitTesting.nearestPointIndex(tapX: 10,
                                                        renderedCenters: [20, 10], hitRadius: 4))
        XCTAssertNil(FChartHitTesting.nearestPointIndex(tapX: 10,
                                                        renderedCenters: [0, .nan, 20], hitRadius: 4))
        XCTAssertNil(FChartHitTesting.nearestPointIndex(tapX: 10,
                                                        renderedCenters: [0, 20, 10], hitRadius: 4))
        XCTAssertNil(FChartRenderedXCoordinates(centers: [0, .infinity, 20]))
    }

    func testLargeSeriesHitTestingFindsLastBar() {
        let centers = (0..<100_000).map { Double($0) * 2 }
        let coordinates = FChartRenderedXCoordinates(centers: centers)
        XCTAssertNotNil(coordinates)
        XCTAssertEqual(FChartHitTesting.nearestPointIndex(tapX: 199_998,
                                                          coordinates: coordinates!,
                                                          hitRadius: 0.5), 99_999)
    }

    func testAutomaticDividendModeDoesNotApplyFourPercentHardGate() {
        let preference = FDividendYieldPreference()
        XCTAssertEqual(preference.mode, .automaticAI)
        XCTAssertTrue(preference.passesCustomMinimum(currentYield: Decimal(string: "0.039")))
    }

    func testCustomDividendFloorOnlyAppliesWhenExplicitlySelected() {
        let preference = FDividendYieldPreference(mode: .customMinimum,
                                                 customMinimumYield: Decimal(string: "0.04"))
        XCTAssertFalse(preference.passesCustomMinimum(currentYield: Decimal(string: "0.039")))
        XCTAssertTrue(preference.passesCustomMinimum(currentYield: Decimal(string: "0.041")))
    }

    func testQuestionRequestCarriesPrebuiltPortfolioContext() throws {
        let holding = FPosition(instrumentCode: "159352", name: "中证A500ETF", units: 200,
                                bookCost: 210)
        let opening = FAccountOpeningSnapshot(capturedAt: now.addingTimeInterval(-60), cashBalance: 100,
                                              positions: [holding])
        let book = FAccountBook(openingSnapshot: opening, cashBalance: 100, positions: [holding],
                                updatedAt: now.addingTimeInterval(-60))
        let snapshot = try book.readOnlySnapshot(capturedAt: now)
        let quote = FContextObservation(dataClass: .intraday, subject: "159352", source: "fixture",
                                        observedAt: now.addingTimeInterval(-30), capturedAt: now,
                                        decimalValue: Decimal(string: "1.05"))
        let context = FDecisionContext(snapshot: snapshot, observations: [quote])
        let request = try FAdvisorQuestionRequest(question: "今天我的持仓需要操作吗？",
                                                  scope: .portfolio,
                                                  decisionContext: context, now: now)
        XCTAssertEqual(request.accountID, context.accountID)
        XCTAssertEqual(request.accountDigest, context.accountDigest)
        XCTAssertEqual(request.decisionContextID, context.id)
        XCTAssertEqual(request.portfolioContext?.cashBalance, 100)
        XCTAssertEqual(request.portfolioContext?.holdings.map(\.instrumentCode), ["159352"])
        XCTAssertEqual(request.portfolioContext?.observations, [quote])
        XCTAssertTrue(request.portfolioContext?.matches(context, scope: .portfolio) == true)
        XCTAssertEqual(FAdvisorPromptShortcuts.commonQuestions.count, 5)
    }

    func testNoTradeCandidateCannotCarryOrderFieldsOrUnboundedRationale() throws {
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [])
        let malformedWait = FCandidateRecommendation(
            accountDigest: context.accountDigest, action: .wait, instrumentCode: "159352",
            units: 100, limitPrice: Decimal(string: "1.05"), rationale: "等待")
        let overlongWait = FCandidateRecommendation(
            accountDigest: context.accountDigest, action: .wait,
            rationale: String(repeating: "等待", count: 5_000))

        XCTAssertTrue(FAIGuard.evaluate(malformedWait, in: context, now: now)
            .findings.contains(.invalidCandidate))
        XCTAssertTrue(FAIGuard.evaluate(overlongWait, in: context, now: now)
            .findings.contains(.invalidCandidate))
    }

    func testRecoveryPlanCannotMasqueradeAsOrderOrTargetANonHolding() throws {
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [])
        let noHolding = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .recoveryPlan, instrumentCode: "159352", rationale: "回本分析")
        let noHoldingResult = FAIGuard.evaluate(noHolding, in: context, now: now)
        XCTAssertTrue(noHoldingResult.findings.contains(.invalidCandidate))

        let orderLike = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .recoveryPlan, instrumentCode: "159352", units: 100,
            limitPrice: 1, rationale: "回本计划下单")
        XCTAssertTrue(FAIGuard.evaluate(orderLike, in: context, now: now)
            .findings.contains(.invalidCandidate))
    }

    func testRiskGuardCanValidateBuyWithoutOptionalNASResearch() throws {
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10),
            fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            observedAt: metadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3",
            evaluatedAt: now))
        let qualificationGrant = FQuantStrategyQualificationGrant(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: qualification.id, evaluatedAt: now)
        let regime = securityRegimeObservation()
        let mappedBenchmark = try mappedBenchmarkObservation()
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [quote, qualification, regime, mappedBenchmark],
                                       strategyQualificationGrants: [qualificationGrant])
        XCTAssertTrue(context.researchEvidence.isEmpty)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100, limitPrice: Decimal(string: "0.900")!,
            rationale: "只依据新鲜行情和真实账本形成的待审阅候选",
            citedObservationIDs: [quote.id, qualification.id, regime.id, mappedBenchmark.id])

        let result = FRiskGuard.evaluate(candidate, in: context, now: now)
        XCTAssertTrue(result.allowedForReview,
            "可选Research Summary不是Risk Guard的必要输入，但该ETF仍需本机已有的新鲜指数Regime：\(result.findings)")

        let fractionalLot = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 150, limitPrice: 1,
            rationale: "非法份额候选",
            citedObservationIDs: [quote.id, qualification.id, regime.id, mappedBenchmark.id])
        let fractionalPrice = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 100,
            limitPrice: Decimal(string: "1.0001")!, rationale: "非法价格步长候选",
            citedObservationIDs: [quote.id, qualification.id, regime.id, mappedBenchmark.id])
        for invalidOrder in [fractionalLot, fractionalPrice] {
            let rejected = FRiskGuard.evaluate(invalidOrder, in: context, now: now)
            XCTAssertFalse(rejected.allowedForReview)
            XCTAssertTrue(rejected.findings.contains {
                if case .incompleteTradingEvidence(_) = $0 { return true }
                return false
            })
        }
    }

    func testGridNeedsItsOwnQualifiedStudyAndConservativeDayTradeDoesNotRequireOrderBook() throws {
        let researchContext = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10),
            fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            observedAt: metadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [quote],
                                       researchEvidence: researchContext.researchEvidence)
        let grid = FCandidateRecommendation(accountDigest: context.accountDigest, action: .grid,
            instrumentCode: "159352", units: 10, limitPrice: 1, rationale: "网格候选",
            citedObservationIDs: [quote.id],
            citedResearchEvidenceIDs: [context.researchEvidence[0].id])
        XCTAssertTrue(FAIGuard.evaluate(grid, in: context, now: now).findings
            .contains(.missingQualifiedResearch("gridSpacingReplay:159352")))

        let holding = FPosition(instrumentCode: "159352", name: "中证A500ETF", units: 200,
                                bookCost: 210)
        let opening = FAccountOpeningSnapshot(capturedAt: now.addingTimeInterval(-60), cashBalance: 100,
                                              positions: [holding])
        let book = FAccountBook(openingSnapshot: opening, cashBalance: 100, positions: [holding],
                                updatedAt: now.addingTimeInterval(-60))
        let positionSnapshot = try book.readOnlySnapshot(capturedAt: now)
        let dayTradeMetadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10),
            fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let freshQuote = FContextObservation(dataClass: .quote, subject: "159352", source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            observedAt: dayTradeMetadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: dayTradeMetadata)
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3",
            evaluatedAt: now))
        let qualificationGrant = FQuantStrategyQualificationGrant(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: qualification.id, evaluatedAt: now)
        let regime = securityRegimeObservation()
        let mappedBenchmark = try mappedBenchmarkObservation()
        let dayTradeContext = FDecisionContext(snapshot: positionSnapshot,
                                               observations: [freshQuote, qualification, regime, mappedBenchmark],
                                               researchEvidence: researchContext.researchEvidence,
                                               strategyQualificationGrants: [qualificationGrant])
        let dayTrade = FCandidateRecommendation(accountDigest: dayTradeContext.accountDigest,
            action: .dayTrade, instrumentCode: "159352", units: 100,
            limitPrice: Decimal(string: "0.998")!, estimatedFee: Decimal(string: "0.20")!, rationale: "保守做T候选",
            citedObservationIDs: [freshQuote.id, qualification.id, regime.id, mappedBenchmark.id],
            citedResearchEvidenceIDs: [dayTradeContext.researchEvidence[0].id])
        let dayTradeResult = FDecisionGuards.evaluate(dayTrade, in: dayTradeContext, now: now)
        XCTAssertTrue(dayTradeResult.allowedForReview)
        XCTAssertFalse(dayTradeResult.findings.contains {
            if case .incompleteTradingEvidence(_) = $0 { return true }; return false
        })
    }

    func testAdvisorRechecksQuoteFreshnessAfterModelReturns() async throws {
        let freshNow = Date()
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: freshNow.addingTimeInterval(-10),
            fetchedAt: freshNow, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            observedAt: metadata.quoteTimestamp, capturedAt: freshNow, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let qualification = try XCTUnwrap(FQuantStrategyQualificationEvidence.observation(
            securityCode: "159352", regime: .range, strategyID: "MeanReversion",
            strategyVersion: "v3", evaluatedAt: freshNow))
        let grant = FQuantStrategyQualificationGrant(securityCode: "159352", regime: .range,
            strategyID: "MeanReversion", strategyVersion: "v3",
            observationID: qualification.id, evaluatedAt: freshNow)
        let regime = securityRegimeObservation(at: freshNow)
        let benchmark = try mappedBenchmarkObservation(at: freshNow)
        let context = FDecisionContext(snapshot: try emptySnapshot(capturedAt: freshNow),
            observations: [quote, qualification, regime, benchmark],
            strategyQualificationGrants: [grant])
        let request = try FAdvisorQuestionRequest(question: "可以买入吗？", scope: .instrument("159352"),
                                                  decisionContext: context, now: freshNow)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .buy,
            instrumentCode: "159352", units: 100, limitPrice: 1, rationale: "依据最新报价",
            citedObservationIDs: [quote.id, qualification.id, regime.id, benchmark.id])
        let result = try await FAdvisorDecisionPipeline(model: FixedCandidateModel(result: candidate))
            .assess(request: request, context: context, now: freshNow,
                    completionTime: freshNow.addingTimeInterval(121))
        XCTAssertFalse(result.isEligibleForUserReview)
        XCTAssertTrue(result.guardResult.findings.contains(.invalidContext))
    }

    func testResearchToolCallsAreBoundedToRequestScopeAndCapturedTime() throws {
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [])
        let request = try FAdvisorQuestionRequest(question: "研究159352", scope: .instrument("159352"),
                                                  decisionContext: context, now: now)
        let valid = FAdvisorResearchToolCall(tool: .gridSpacingReplay, securityCode: "159352",
                                             market: "CN", startDate: "2026-10-01",
                                             endDate: "2026-10-23", asOf: now)
        XCTAssertNoThrow(try valid.validate(for: request, now: now))

        let wrongInstrument = FAdvisorResearchToolCall(tool: .minutePatternSummary,
                                                       securityCode: "563020", market: "CN",
                                                       startDate: "2026-10-01", endDate: "2026-10-23",
                                                       asOf: now)
        XCTAssertThrowsError(try wrongInstrument.validate(for: request, now: now))
        let future = FAdvisorResearchToolCall(tool: .vwapBreakStudy, securityCode: "159352",
                                              market: "CN", startDate: "2026-10-01",
                                              endDate: "2026-10-23", asOf: now.addingTimeInterval(1))
        XCTAssertThrowsError(try future.validate(for: request, now: now))
        let tooWide = FAdvisorResearchToolCall(tool: .dividendQualityStudy, securityCode: "159352",
                                               market: "CN", startDate: "2020-01-01",
                                               endDate: "2026-10-23", asOf: now)
        XCTAssertThrowsError(try tooWide.validate(for: request, now: now))
    }

    func testResearchToolExecutionBindsProviderEvidenceToRequestAndContextTime() async throws {
        let capturedAt = Date().addingTimeInterval(-120)
        let asOf = capturedAt.addingTimeInterval(-120)
        let generatedAt = capturedAt.addingTimeInterval(-60)
        let context = try contextWithResearchEvidence(
            evidenceJSON(qualified: true, asOf: asOf, generatedAt: generatedAt),
            capturedAt: capturedAt)
        let request = try FAdvisorQuestionRequest(question: "研究159352",
                                                  scope: .instrument("159352"),
                                                  decisionContext: context, now: capturedAt)
        let call = FAdvisorResearchToolCall(tool: .vwapBreakStudy, securityCode: "159352",
                                            market: "CN", startDate: "2026-10-01",
                                            endDate: "2026-10-23", asOf: asOf)
        let result = try await call.execute(using: FixedResearchProvider(result: context.researchEvidence[0]),
                                            for: request, now: capturedAt)
        XCTAssertTrue(context.researchEvidence[0].isUsableForAI(
            contextCreatedAt: context.createdAt, now: capturedAt))
        XCTAssertEqual(result, context.researchEvidence[0])
    }

    func testResearchToolAcceptsPostRequestCaptureOnlyWithFrozenAsOf() async throws {
        let capturedAt = Date().addingTimeInterval(-120)
        let asOf = capturedAt.addingTimeInterval(-120)
        let generatedAt = capturedAt.addingTimeInterval(-60)
        let context = try contextWithResearchEvidence(
            evidenceJSON(qualified: true, asOf: asOf, generatedAt: generatedAt),
            capturedAt: capturedAt)
        let request = try FAdvisorQuestionRequest(question: "研究159352",
                                                  scope: .instrument("159352"),
                                                  decisionContext: context, now: capturedAt)
        let call = FAdvisorResearchToolCall(tool: .vwapBreakStudy, securityCode: "159352",
                                            market: "CN", startDate: "2026-10-01",
                                            endDate: "2026-10-23", asOf: asOf)
        let envelope = context.researchEvidence[0].envelope
        let postRequestEvidence = FDecisionResearchEvidence(
            envelope: envelope, capturedAt: capturedAt.addingTimeInterval(60))
        let result = try await call.execute(using: FixedResearchProvider(result: postRequestEvidence),
                                            for: request, now: capturedAt)
        XCTAssertTrue(postRequestEvidence.isUsableForAI(
            contextCreatedAt: postRequestEvidence.capturedAt,
            now: capturedAt.addingTimeInterval(60)))
        XCTAssertEqual(result.capturedAt, capturedAt.addingTimeInterval(60))
        XCTAssertLessThanOrEqual(result.envelope.observedAt, context.createdAt)
    }

    func testResearchToolExecutionRejectsWrongInstrumentAndInsufficientEvidence() async throws {
        let wrongSecurityJSON = evidenceJSON(qualified: true)
            .replacingOccurrences(of: "\"securityCode\":\"159352\"",
                                  with: "\"securityCode\":\"563020\"")
        let wrongSecurityContext = try contextWithResearchEvidence(wrongSecurityJSON)
        let request = try FAdvisorQuestionRequest(question: "研究159352",
                                                  scope: .instrument("159352"),
                                                  decisionContext: wrongSecurityContext, now: now)
        let call = FAdvisorResearchToolCall(tool: .vwapBreakStudy, securityCode: "159352",
                                            market: "CN", startDate: "2026-10-01",
                                            endDate: "2026-10-23", asOf: now)
        do {
            _ = try await call.execute(using: FixedResearchProvider(
                result: wrongSecurityContext.researchEvidence[0]), for: request, now: now)
            XCTFail("provider response for a different instrument must be rejected")
        } catch let error as FAdvisorResearchToolError {
            XCTAssertEqual(error, .invalidOrUnboundResponse)
        }

        let insufficientContext = try contextWithResearchEvidence(evidenceJSON(qualified: false))
        let insufficientRequest = try FAdvisorQuestionRequest(question: "研究159352",
            scope: .instrument("159352"), decisionContext: insufficientContext, now: now)
        do {
            _ = try await call.execute(using: FixedResearchProvider(
                result: insufficientContext.researchEvidence[0]), for: insufficientRequest, now: now)
            XCTFail("unqualified evidence must not reach the advisor")
        } catch let error as FAdvisorResearchToolError {
            XCTAssertEqual(error, .invalidOrUnboundResponse)
        }
    }

    func testResearchEvidenceReferenceIsReadOnlyAndQualifiedEvidenceIsUsable() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        try context.validate(now: now)
        XCTAssertEqual(context.usableResearchEvidence(at: now).count, 1)
        XCTAssertEqual(context.researchEvidence[0].id.count, 64)

        let oversizedCount = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"trainingDays\":24", with: "\"trainingDays\":1e300")
        XCTAssertTrue(try contextWithResearchEvidence(oversizedCount)
            .usableResearchEvidence(at: now).isEmpty)

        let negativeConcentration = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"maxMonthlySampleShare\":0.25",
            with: "\"maxMonthlySampleShare\":-0.01")
        XCTAssertTrue(try contextWithResearchEvidence(negativeConcentration)
            .usableResearchEvidence(at: now).isEmpty)

        let missingSource = replacingResearchField("sources", with: [String](),
                                                   in: evidenceJSON(qualified: true))
        XCTAssertThrowsError(try contextWithResearchEvidence(missingSource))
    }

    func testResearchQualificationRequiresConsistentChronologicalWindows() throws {
        let wrongIndependentCount = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"independentDays\":32", with: "\"independentDays\":31")
        let countContext = try contextWithResearchEvidence(wrongIndependentCount)
        XCTAssertTrue(countContext.usableResearchEvidence(at: now).isEmpty)

        let overlappingWindows = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"endDate\":\"2026-09-30\"", with: "\"endDate\":\"2026-10-02\"")
        let overlapContext = try contextWithResearchEvidence(overlappingWindows)
        XCTAssertTrue(overlapContext.usableResearchEvidence(at: now).isEmpty)
    }

    func testQualifiedResearchRejectsUnknownProviderEvenWithRecomputedDigest() throws {
        let untrusted = replacingResearchField("sources", with: ["unverified-provider"],
                                               in: evidenceJSON(qualified: true))
        XCTAssertThrowsError(try contextWithResearchEvidence(recomputedEvidenceJSON(untrusted)))
    }

    func testInsufficientResearchRemainsAuditableButIsExcludedFromAISet() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: false))
        try context.validate(now: now)
        XCTAssertEqual(context.researchEvidence.count, 1)
        XCTAssertTrue(context.usableResearchEvidence(at: now).isEmpty)

        let noHistory = evidenceJSON(qualified: false)
            .replacingOccurrences(of: "\"qualifiedIndependentDays\":4", with: "\"qualifiedIndependentDays\":0")
            .replacingOccurrences(of: "\"sources\":[\"Tencent Finance minute/query (public web endpoint)\"]", with: "\"sources\":[]")
            .replacingOccurrences(of: "\"dataRange\":{\"end\":\"2026-10-23\",\"start\":\"2026-10-05\"},", with: "")
        let noHistoryContext = try contextWithResearchEvidence(noHistory)
        XCTAssertTrue(noHistoryContext.usableResearchEvidence(at: now).isEmpty)
    }

    func testDividendEvidenceFromUnconfiguredProviderIsRejected() throws {
        let factor: [String: Any] = ["value": "3.9", "source": "official-provider", "quality": 95,
                                     "observedAt": "2026-10-23T07:50:00Z",
                                     "fetchedAt": "2026-10-23T07:55:00Z", "unit": "percent"]
        let node: [String: Any] = ["evidenceState": "evidence_available",
                                   "referenceInterpretation": "descriptive_only_not_a_hard_gate",
                                   "tradePlan": NSNull(), "factorCoverage": ["available": 3, "expected": 10],
                                   "factors": ["currentYield": factor, "payoutRatio": factor,
                                               "consecutivePayments": factor]]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(evidenceJSON(qualified: false).utf8))
            as? [String: Any])
        object["qualifiedIndependentDays"] = 0
        object["evidence"] = ["dividendQuality": node]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        XCTAssertThrowsError(try contextWithResearchEvidence(json))
    }

    func testExpiredResearchRemainsInContextButIsExcludedFromAISet() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        XCTAssertEqual(context.researchEvidence.count, 1)
        XCTAssertTrue(context.usableResearchEvidence(at: now.addingTimeInterval(8 * 24 * 3600)).isEmpty)
    }

    func testResearchEvidenceRejectsRawMinuteAndPerSignalArrays() throws {
        let raw = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"evidenceState\":",
            with: "\"samples\":[{\"timestamp\":\"2026-10-23T07:00:00Z\"}],\"evidenceState\":")
        XCTAssertThrowsError(try contextWithResearchEvidence(raw))
    }

    func testLegacyMinuteResearchMethodologyIsNotAcceptedAsCurrentEvidence() throws {
        let legacy = evidenceJSON(qualified: true).replacingOccurrences(
            of: "minute-research-2", with: "minute-research-1")
        XCTAssertThrowsError(try contextWithResearchEvidence(legacy))
    }

    func testResearchEvidenceRequiresOneTrainingSelectedGridHoldout() throws {
        let qualifiedMetrics: [String: Any] = [
            "evidenceState": "available_for_review", "selectedByTraining": true,
            "headlinePopulation": "out_of_sample", "trainingDays": 20,
            "outOfSampleDays": 5, "maxMonthlySampleShare": 0.5,
            "maximumMonthlySampleShare": 0.5,
            "outOfSample": ["days": 5, "mean": 0.1]
        ]
        let withheld: [String: Any] = [
            "evidenceState": "not_selected_by_training", "selectedByTraining": false,
            "outOfSample": NSNull()
        ]
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(evidenceJSON(qualified: true).utf8)) as? [String: Any])
        var evidence = try XCTUnwrap(payload["evidence"] as? [String: Any])
        evidence["gridSpacingReplay"] = ["selectedSpacing": "1",
                                         "spacings": ["1": qualifiedMetrics, "2": withheld]]
        payload["evidence"] = evidence
        let validJSON = String(decoding: try JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertNoThrow(try contextWithResearchEvidence(validJSON))

        var spacings = try XCTUnwrap((evidence["gridSpacingReplay"] as? [String: Any])?["spacings"] as? [String: Any])
        spacings["2"] = qualifiedMetrics
        evidence["gridSpacingReplay"] = ["selectedSpacing": "1", "spacings": spacings]
        payload["evidence"] = evidence
        let repeatedHoldoutJSON = String(decoding: try JSONSerialization.data(
            withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertThrowsError(try contextWithResearchEvidence(repeatedHoldoutJSON))
    }

    func testResearchEvidenceRejectsFutureGeneratedOrCapturedTime() throws {
        let future = evidenceJSON(qualified: true).replacingOccurrences(
            of: "2026-10-23T07:59:00Z", with: "2026-10-23T08:01:00Z")
        XCTAssertThrowsError(try contextWithResearchEvidence(future))

        let invalidCalendarDay = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"end\":\"2026-10-23\"", with: "\"end\":\"2026-02-30\"")
        XCTAssertThrowsError(try contextWithResearchEvidence(invalidCalendarDay))
    }

    func testResearchEvidenceDigestCoversTrustAndEligibilityFields() throws {
        let original = try JSONDecoder().decode(FResearchEvidenceEnvelope.self,
            from: Data(evidenceJSON(qualified: true).utf8))
        XCTAssertEqual(try original.calculatedContentDigest(),
                       "c714379cba21ed199d7cbad7f31d0d33660b58c1e4f5fa7f133d8ff840256302")
        var dataRangeObject = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(evidenceJSON(qualified: true).utf8)) as? [String: Any])
        dataRangeObject["dataRange"] = ["start": "2026-10-04", "end": "2026-10-23"]
        let changedDataRange = try JSONSerialization.data(withJSONObject: dataRangeObject,
            options: [.sortedKeys])
        let changedEnvelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self,
            from: changedDataRange)
        XCTAssertNotEqual(try original.calculatedContentDigest(),
                          try changedEnvelope.calculatedContentDigest())

        var strategyVersionObject = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(evidenceJSON(qualified: true).utf8)) as? [String: Any])
        strategyVersionObject["strategyVersion"] = "mean-reversion-v3"
        let changedStrategyVersion = try JSONSerialization.data(withJSONObject: strategyVersionObject,
            options: [.sortedKeys])
        let strategyEnvelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self,
            from: changedStrategyVersion)
        XCTAssertNotEqual(try original.calculatedContentDigest(),
                          try strategyEnvelope.calculatedContentDigest())

        var missingDataRangeObject = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(evidenceJSON(qualified: true).utf8)) as? [String: Any])
        missingDataRangeObject.removeValue(forKey: "dataRange")
        let missingDataRangeJSON = String(decoding: try JSONSerialization.data(
            withJSONObject: missingDataRangeObject, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertThrowsError(try contextWithResearchEvidence(
            recomputedEvidenceJSON(missingDataRangeJSON)))

        var legacySchemaObject = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(evidenceJSON(qualified: true).utf8)) as? [String: Any])
        legacySchemaObject["schemaVersion"] = 1
        let legacySchemaJSON = String(decoding: try JSONSerialization.data(
            withJSONObject: legacySchemaObject, options: [.sortedKeys]), as: UTF8.self)
        XCTAssertThrowsError(try contextWithResearchEvidence(
            recomputedEvidenceJSON(legacySchemaJSON)))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(evidenceJSON(qualified: true).utf8)) as? [String: Any])
        object["qualifiedIndependentDays"] = 0
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let altered = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: tampered)
        XCTAssertNotEqual(try original.calculatedContentDigest(),
                          try altered.calculatedContentDigest())
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [],
            researchEvidence: [FDecisionResearchEvidence(envelope: altered, capturedAt: now)])
        XCTAssertThrowsError(try context.validate(now: now))
    }

    func testOldDecisionContextWithoutResearchReferencesStillDecodes() throws {
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as? [String: Any])
        object.removeValue(forKey: "researchEvidence")
        let decoded = try JSONDecoder().decode(FDecisionContext.self,
                                               from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.researchEvidence, [])
    }

    func testDecisionMemoryStoresCompactResearchProvenance() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .hold,
                                                 rationale: "保持观察")
        let memory = try FDecisionMemory(context: context, candidate: candidate,
                                         recommendation: "继续持有", rationale: "研究证据仅供参考")
        XCTAssertEqual(memory.evidence.filter { $0.kind == .nasResearch }.count, 1)
        XCTAssertEqual(memory.evidence.first { $0.kind == .nasResearch }?.reference,
                       context.researchEvidence[0].id)
    }

    func testIdenticalResearchEvidenceIDsAreIdempotentlyDeduplicated() throws {
        let envelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self,
                                                from: Data(evidenceJSON(qualified: true).utf8))
        let reference = FDecisionResearchEvidence(envelope: envelope, capturedAt: now)
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [],
                                       researchEvidence: [reference, reference])
        try context.validate(now: now)
        XCTAssertEqual(context.researchEvidence.count, 1)
    }

    func testGeneratedTimestampProducesANewResearchEvidenceVersion() throws {
        let first = try JSONDecoder().decode(FResearchEvidenceEnvelope.self,
                                             from: Data(evidenceJSON(qualified: true).utf8))
        let changed = recomputedEvidenceJSON(evidenceJSON(qualified: true).replacingOccurrences(
            of: "2026-10-23T07:59:00Z", with: "2026-10-23T07:59:30Z"))
        let second = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(changed.utf8))
        XCTAssertNotEqual(first.evidenceId, second.evidenceId)
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [], researchEvidence: [
            FDecisionResearchEvidence(envelope: first, capturedAt: now),
            FDecisionResearchEvidence(envelope: second, capturedAt: now)
        ])
        XCTAssertNoThrow(try context.validate(now: now))
    }

    func testAdvisorRequestSelectsNewestVersionAndReportsConflict() throws {
        let firstJSON = recomputedEvidenceJSON(evidenceJSON(qualified: true).replacingOccurrences(
            of: "2026-10-23T07:59:00Z", with: "2026-10-23T07:58:30Z"))
        let secondJSON = recomputedEvidenceJSON(replacingResearchField(
            "strategyVersion", with: "mean-reversion-v2", in: evidenceJSON(qualified: true)))
        let firstEnvelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(firstJSON.utf8))
        let secondEnvelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(secondJSON.utf8))
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [], researchEvidence: [
            FDecisionResearchEvidence(envelope: firstEnvelope, capturedAt: now),
            FDecisionResearchEvidence(envelope: secondEnvelope, capturedAt: now)
        ])
        let request = try FAdvisorQuestionRequest(question: "分析我的组合", scope: .portfolio,
                                                  decisionContext: context, now: now)
        XCTAssertEqual(context.researchEvidence.count, 2)
        XCTAssertEqual(request.researchEvidence.map(\.id), [secondEnvelope.evidenceId])
        XCTAssertEqual(request.researchEvidenceVersionConflicts.count, 1)
        XCTAssertEqual(request.researchEvidenceVersionConflicts[0].evidenceIDs.count, 2)
        XCTAssertEqual(request.researchEvidenceVersionConflicts[0].selectedEvidenceID,
                       secondEnvelope.evidenceId)
    }

    func testAdvisorRequestCarriesOnlyEffectiveProfilePreferencesAtRequestTime() throws {
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [])
        var profile = FInvestorProfile()
        let initialHorizon = FInvestorProfileRevision(value: .text("15年以上"), confidence: 1,
                                                      source: .explicit,
                                                      updatedAt: now.addingTimeInterval(-600),
                                                      explanation: "用户明确设定长期目标")
        _ = try profile.record(initialHorizon, for: .investmentHorizon, now: now)
        _ = try profile.record(FInvestorProfileRevision(value: .text("20年以上"), confidence: 1,
                                                        source: .explicit,
                                                        updatedAt: now.addingTimeInterval(30),
                                                        explanation: "之后的修正",
                                                        supersedesRevisionID: initialHorizon.id),
                               for: .investmentHorizon, now: now.addingTimeInterval(30))
        _ = try profile.record(FInvestorProfileRevision(value: .text("短期偏好"), confidence: 0.6,
                                                        source: .temporary,
                                                        updatedAt: now.addingTimeInterval(-300),
                                                        explanation: "临时反馈",
                                                        expiresAt: now.addingTimeInterval(-60)),
                               for: .tradingFrequency, now: now.addingTimeInterval(-30))

        let request = try FAdvisorQuestionRequest(question: "今天我的持仓需要操作吗？",
                                                  scope: .portfolio, decisionContext: context,
                                                  investorProfile: profile, now: now)
        XCTAssertEqual(request.investorProfile?.asOf, now)
        XCTAssertEqual(request.investorProfile?.preferences.map(\.attribute), [.investmentHorizon])
        XCTAssertEqual(request.investorProfile?.preferences.first?.value, .text("15年以上"))
        XCTAssertEqual(request.investorProfile?.preferences.first?.source, .explicit)
        XCTAssertEqual(request.investorProfile?.preferences.first?.confidence, 1)
        XCTAssertTrue(request.profileUseConstraint?.contains("不得据此预测用户下一笔交易") == true)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request))
            as? [String: Any])
        legacyObject.removeValue(forKey: "investorProfile")
        let decodedLegacyRequest = try JSONDecoder().decode(
            FAdvisorQuestionRequest.self,
            from: JSONSerialization.data(withJSONObject: legacyObject, options: [.sortedKeys]))
        XCTAssertNil(decodedLegacyRequest.investorProfile)
        XCTAssertNotNil(decodedLegacyRequest.decisionContextCreatedAt)

        let wrongAccountMemory = try FAdvisorDecisionMemoryProjection(records: [], accountID: UUID(),
                                                                       scope: .portfolio,
                                                                       asOf: context.createdAt,
                                                                       validatedAt: now)
        XCTAssertThrowsError(try FAdvisorQuestionRequest(question: "查看历史建议",
                                                         scope: .portfolio,
                                                         decisionContext: context,
                                                         decisionMemory: wrongAccountMemory,
                                                         now: now))
    }

    func testAdvisorRequestRejectsPayloadAboveByteLimit() throws {
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [])
        XCTAssertThrowsError(try FAdvisorQuestionRequest(question: String(repeating: "问", count: 40_000),
                                                         scope: .portfolio, decisionContext: context, now: now))
    }

    func testExpiredEvidenceConflictDoesNotClaimASelectedVersion() throws {
        let firstJSON = recomputedEvidenceJSON(evidenceJSON(qualified: true).replacingOccurrences(
            of: "2026-10-23T07:59:00Z", with: "2026-10-23T07:58:30Z"))
        let secondJSON = recomputedEvidenceJSON(evidenceJSON(qualified: true).replacingOccurrences(
            of: String(repeating: "a", count: 64), with: String(repeating: "b", count: 64)))
        let first = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(firstJSON.utf8))
        let second = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(secondJSON.utf8))
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [], researchEvidence: [
            FDecisionResearchEvidence(envelope: first, capturedAt: now),
            FDecisionResearchEvidence(envelope: second, capturedAt: now)
        ])
        let later = now.addingTimeInterval(8 * 24 * 3600)
        let request = try FAdvisorQuestionRequest(question: "分析我的组合", scope: .portfolio,
                                                  decisionContext: context, now: later)
        XCTAssertTrue(request.researchEvidence.isEmpty)
        XCTAssertNil(request.researchEvidenceVersionConflicts.first?.selectedEvidenceID)
    }

    func testDecisionContextRejectsAggregateResearchPayloadAboveLimit() throws {
        let largeLimitations = String(repeating: "x", count: 13_000)
        let references = try (1...22).map { index -> FDecisionResearchEvidence in
            let json = recomputedEvidenceJSON(evidenceJSON(qualified: true)
                .replacingOccurrences(of: String(repeating: "a", count: 64),
                                      with: String(format: "%064x", index))
                .replacingOccurrences(of: "Historical observational evidence; not a forecast or trade instruction.",
                                      with: largeLimitations + String(index)))
            let envelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(json.utf8))
            return FDecisionResearchEvidence(envelope: envelope, capturedAt: now)
        }
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [],
                                       researchEvidence: references)
        XCTAssertThrowsError(try context.validate(now: now))
    }

    func testAIGuardAcceptsCitationToUsableResearchEvidence() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "依据历史分钟统计继续观察",
                                                 citedResearchEvidenceIDs: [context.researchEvidence[0].id])
        XCTAssertTrue(FAIGuard.evaluate(candidate, in: context, now: now).allowedForReview)
    }

    func testAIGuardRejectsCitationToExpiredResearchEvidence() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let id = context.researchEvidence[0].id
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "引用历史证据", citedResearchEvidenceIDs: [id])
        let result = FAIGuard.evaluate(candidate, in: context,
                                       now: now.addingTimeInterval(8 * 24 * 3600))
        XCTAssertFalse(result.allowedForReview)
        XCTAssertTrue(result.findings.contains(.staleResearchEvidence(id)))
    }

    func testAIGuardRejectsUnknownResearchEvidenceID() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "引用不存在的证据",
                                                 citedResearchEvidenceIDs: [String(repeating: "f", count: 64)])
        XCTAssertTrue(FAIGuard.evaluate(candidate, in: context, now: now).findings
            .contains(.missingResearchEvidence(String(repeating: "f", count: 64)))
        )
    }

    func testDecisionMemoryRejectsUnknownResearchCitation() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "引用不存在的证据",
                                                 citedResearchEvidenceIDs: [String(repeating: "f", count: 64)])
        XCTAssertThrowsError(try FDecisionMemory(context: context, candidate: candidate,
                                                 recommendation: "等待", rationale: "引用必须可追溯"))
    }

    func testLegacyCandidateWithoutResearchCitationFieldDecodes() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .wait,
                                                 rationale: "兼容旧候选")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(candidate)) as? [String: Any])
        object.removeValue(forKey: "citedResearchEvidenceIDs")
        object.removeValue(forKey: "citedDecisionMemoryIDs")
        object.removeValue(forKey: "citedInvestorProfileRevisionIDs")
        let decoded = try JSONDecoder().decode(FCandidateRecommendation.self,
                                               from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.citedResearchEvidenceIDs, [])
        XCTAssertEqual(decoded.citedDecisionMemoryIDs, [])
        XCTAssertEqual(decoded.citedInvestorProfileRevisionIDs, [])
    }

    private func emptySnapshot() throws -> FReadOnlyLedgerSnapshot {
        try emptySnapshot(capturedAt: now)
    }

    private func emptySnapshot(capturedAt: Date) throws -> FReadOnlyLedgerSnapshot {
        let opening = FAccountOpeningSnapshot(capturedAt: capturedAt.addingTimeInterval(-60), cashBalance: 100)
        let book = FAccountBook(openingSnapshot: opening, cashBalance: 100,
                                updatedAt: capturedAt.addingTimeInterval(-60))
        return try book.readOnlySnapshot(capturedAt: capturedAt)
    }

    private func contextWithResearchEvidence(_ json: String) throws -> FDecisionContext {
        try contextWithResearchEvidence(json, capturedAt: now)
    }

    private func contextWithResearchEvidence(_ json: String, capturedAt: Date) throws -> FDecisionContext {
        let verifiedJSON = recomputedEvidenceJSON(json)
        let envelope = try JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: Data(verifiedJSON.utf8))
        let context = FDecisionContext(snapshot: try emptySnapshot(capturedAt: capturedAt), observations: [],
                                       researchEvidence: [FDecisionResearchEvidence(envelope: envelope, capturedAt: capturedAt)])
        try context.validate(now: capturedAt)
        return context
    }

    private func evidenceJSON(qualified: Bool, asOf: Date? = nil, generatedAt: Date? = nil) -> String {
        let asOfText = asOf.map { ISO8601DateFormatter().string(from: $0) } ?? "2026-10-23T07:58:00Z"
        let generatedAtText = generatedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "2026-10-23T07:59:00Z"
        let metrics: [String: Any] = [
            "evidenceState": qualified ? "available_for_review" : "insufficient_independent_days",
            "independentDays": qualified ? 32 : 4,
            "minimumTrainingDays": 20, "minimumOutOfSampleDays": 5,
            "trainingDays": qualified ? 24 : 4,
            "outOfSampleDays": qualified ? 8 : 0,
            "maxMonthlySampleShare": qualified ? 0.25 : 1.0,
            "maximumMonthlySampleShare": 0.5,
            "training": ["days": qualified ? 24 : 4, "startDate": "2026-08-03",
                         "endDate": "2026-09-30", "median": 0.1, "mean": 0.1, "positiveRate": 0.6],
            "outOfSample": ["days": qualified ? 8 : 0, "startDate": "2026-10-01",
                            "endDate": qualified ? ("2026-10-20" as Any) : NSNull(),
                            "median": 0.1, "mean": 0.1, "positiveRate": 0.6]
        ]
        var object: [String: Any] = [
            "schemaVersion": 2, "methodologyVersion": "minute-research-2",
            "evidenceId": String(repeating: "a", count: 64), "securityCode": "159352", "market": "CN",
            "range": ["start": "2026-08-01", "end": "2026-10-23"],
            "dataRange": ["start": "2026-08-03", "end": "2026-10-23"],
            "strategyVersion": NSNull(),
            "asOf": asOfText, "generatedAt": generatedAtText,
            "timezone": "Asia/Shanghai", "sessionCoverage": ["complete": 32, "partial": 1, "missing": 2],
            "qualifiedIndependentDays": qualified ? 32 : 4, "minimumQuality": 90,
            "sources": [FResearchSourceTrustPolicy.tencentMinuteSource],
            "evidence": ["vwapBreak": ["windows": ["5": metrics]],
                         "morningRecovery": ["evidenceState": "insufficient_independent_days"],
                         "gridSpacingReplay": ["selectedSpacing": NSNull(),
                                              "spacings": [String: Any]()]],
            "limitations": [
                "Historical observational evidence; not a forecast or trade instruction.",
                "Only complete sessions meeting the configured quality and as-of gates are eligible.",
                "Market calendar and provider coverage require deployment verification."
            ], "rawMinuteBarsIncluded": false, "tradePlan": NSNull()
        ]
        let provisional = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let envelope = try! JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: provisional)
        object["evidenceId"] = try! envelope.calculatedContentDigest()
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func recomputedEvidenceJSON(_ json: String) -> String {
        var object = try! XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let provisional = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let envelope = try! JSONDecoder().decode(FResearchEvidenceEnvelope.self, from: provisional)
        object["evidenceId"] = try! envelope.calculatedContentDigest()
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func replacingResearchField(_ key: String, with value: Any) -> String {
        replacingResearchField(key, with: value, in: evidenceJSON(qualified: true))
    }

    private func replacingResearchField(_ key: String, with value: Any, in json: String) -> String {
        var object = try! XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        object[key] = value
        return String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                      as: UTF8.self)
    }
}
