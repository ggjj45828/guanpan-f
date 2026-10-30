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

    func testClosedIndexQuoteShowsVerifiedMarketTime() {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: ISO8601DateFormatter().date(from: "2026-10-23T07:00:00Z"),
            fetchedAt: ISO8601DateFormatter().date(from: "2026-10-23T07:02:00Z"),
            source: "verified-provider", timestampTrust: .verifiedExchangeTimestamp,
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
                                              fetchedAt: now, source: "provider",
                                              timestampTrust: .verifiedExchangeTimestamp,
                                              marketSessionStatus: .continuous)
        XCTAssertEqual(metadata.freshness(at: now), .fresh)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: -1), .unverified)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: -.infinity), .unverified)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: .infinity), .unverified)
        XCTAssertEqual(metadata.freshness(at: now, maximumAge: .nan), .unverified)
        XCTAssertNotEqual(metadata.quoteTimestamp, metadata.fetchedAt)
        let observation = FContextObservation(dataClass: .quote, subject: "159352",
                                              source: "provider", observedAt: metadata.quoteTimestamp,
                                              capturedAt: now, decimalValue: 1,
                                              quoteTemporalMetadata: metadata)
        XCTAssertNoThrow(try observation.validate(now: now))
        XCTAssertTrue(observation.isFresh(at: now))
        let futureMetadata = FQuoteTemporalMetadata(
            quoteTimestamp: now.addingTimeInterval(1), fetchedAt: now.addingTimeInterval(2),
            source: "provider", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let futureObservation = FContextObservation(dataClass: .quote, subject: "159352",
                                                   source: "provider",
                                                   observedAt: futureMetadata.quoteTimestamp,
                                                   capturedAt: now, decimalValue: 1,
                                                   quoteTemporalMetadata: futureMetadata)
        XCTAssertThrowsError(try futureObservation.validate(now: now.addingTimeInterval(10)))
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
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: fetchedAt,
            source: "verified-chart-source", timestampTrust: .fetchedAtOnly,
            marketSessionStatus: .closed)
        let chart = try FChartDataModel(securityCode: "159352", window: .historicalIntraday(tradingDate: first),
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
            fetchedAt: now, source: "live-provider", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: "live-provider",
            observedAt: metadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let mapping = FMarketBenchmarkMapping.resolve(securityCode: "159352")!
        let regimeBars = (0..<70).map { index in
            FMarketRegimeBar(timestamp: now.addingTimeInterval(Double(index - 69) * 86_400), close: 100)
        }
        let regime = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "security:159352", securityCode: "159352",
                contextKind: mapping.market, asOf: now, sourceUpdatedAt: now,
                source: "fixture-index-feed", bars: regimeBars,
                benchmarkObservations: [
                    .init(benchmark: .csiA500, dailyReturn: 0.002, observedAt: now, source: "fixture-index-feed")
                ], benchmarkMapping: mapping),
            now: now)
        let regimeEncoder = JSONEncoder()
        regimeEncoder.dateEncodingStrategy = .iso8601
        let regimeJSON = String(data: try regimeEncoder.encode(regime), encoding: .utf8)!
        let regimeObservation = FContextObservation(
            dataClass: .marketRegime, subject: "159352",
            source: "FCore deterministic Market Regime Engine", reference: regimeJSON,
            observedAt: regime.dataAsOf, capturedAt: now,
            decimalValue: Decimal(regime.riskLevel.rawValue))
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [quote, regimeObservation])
        XCTAssertTrue(context.researchEvidence.isEmpty)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest,
            action: .buy, instrumentCode: "159352", units: 10, limitPrice: 1,
            rationale: "只依据新鲜行情和真实账本形成的待审阅候选",
            citedObservationIDs: [quote.id])

        let result = FRiskGuard.evaluate(candidate, in: context, now: now)
        XCTAssertTrue(result.allowedForReview, "NAS不属于行情/现金/持仓风险校验的必要输入：\(result.findings)")
    }

    func testGridNeedsItsOwnQualifiedStudyAndConservativeDayTradeDoesNotRequireOrderBook() throws {
        let researchContext = try contextWithResearchEvidence(evidenceJSON(qualified: true))
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10),
            fetchedAt: now, source: "fixture", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: "fixture",
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
            fetchedAt: now, source: "fixture", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let freshQuote = FContextObservation(dataClass: .quote, subject: "159352", source: "fixture",
            observedAt: dayTradeMetadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: dayTradeMetadata)
        let dayTradeContext = FDecisionContext(snapshot: positionSnapshot, observations: [freshQuote],
                                               researchEvidence: researchContext.researchEvidence)
        let dayTrade = FCandidateRecommendation(accountDigest: dayTradeContext.accountDigest,
            action: .dayTrade, instrumentCode: "159352", units: 1,
            limitPrice: 1, estimatedFee: Decimal(string: "0.20")!, rationale: "保守做T候选",
            citedObservationIDs: [freshQuote.id],
            citedResearchEvidenceIDs: [dayTradeContext.researchEvidence[0].id])
        let dayTradeResult = FDecisionGuards.evaluate(dayTrade, in: dayTradeContext, now: now)
        XCTAssertTrue(dayTradeResult.allowedForReview)
        XCTAssertFalse(dayTradeResult.findings.contains {
            if case .incompleteTradingEvidence(_) = $0 { return true }; return false
        })
    }

    func testAdvisorRechecksQuoteFreshnessAfterModelReturns() async throws {
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(-10),
            fetchedAt: now, source: "fixture", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let quote = FContextObservation(dataClass: .quote, subject: "159352", source: "fixture",
            observedAt: metadata.quoteTimestamp, capturedAt: now, decimalValue: 1,
            quoteTemporalMetadata: metadata)
        let context = FDecisionContext(snapshot: try emptySnapshot(), observations: [quote])
        let request = try FAdvisorQuestionRequest(question: "可以买入吗？", scope: .instrument("159352"),
                                                  decisionContext: context, now: now)
        let candidate = FCandidateRecommendation(accountDigest: context.accountDigest, action: .buy,
            instrumentCode: "159352", units: 10, limitPrice: 1, rationale: "依据最新报价",
            citedObservationIDs: [quote.id])
        let result = try await FAdvisorDecisionPipeline(model: FixedCandidateModel(result: candidate))
            .assess(request: request, context: context, now: now)
        XCTAssertFalse(result.isEligibleForUserReview)
        XCTAssertTrue(result.guardResult.findings.contains(.missingFreshQuote("159352")))
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

        let missingSource = evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"sources\":[\"fixture-provider\"]", with: "\"sources\":[]")
        XCTAssertThrowsError(try contextWithResearchEvidence(missingSource))
    }

    func testInsufficientResearchRemainsAuditableButIsExcludedFromAISet() throws {
        let context = try contextWithResearchEvidence(evidenceJSON(qualified: false))
        try context.validate(now: now)
        XCTAssertEqual(context.researchEvidence.count, 1)
        XCTAssertTrue(context.usableResearchEvidence(at: now).isEmpty)

        let noHistory = evidenceJSON(qualified: false)
            .replacingOccurrences(of: "\"qualifiedIndependentDays\":4", with: "\"qualifiedIndependentDays\":0")
            .replacingOccurrences(of: "\"sources\":[\"fixture-provider\"]", with: "\"sources\":[]")
        let noHistoryContext = try contextWithResearchEvidence(noHistory)
        XCTAssertTrue(noHistoryContext.usableResearchEvidence(at: now).isEmpty)
    }

    func testDividendEvidenceUsesFactorQualityInsteadOfMinuteDayThreshold() throws {
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
        let context = try contextWithResearchEvidence(json)
        XCTAssertEqual(context.usableResearchEvidence(at: now).count, 1)

        var futureNode = node
        var futureFactors = futureNode["factors"] as! [String: [String: Any]]
        futureFactors["currentYield"]?["fetchedAt"] = "2026-10-23T08:01:00Z"
        futureNode["factors"] = futureFactors
        object["evidence"] = ["dividendQuality": futureNode]
        let futureJSON = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
        XCTAssertThrowsError(try contextWithResearchEvidence(futureJSON))
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
                       "80249e4e1aaceac09fba6183f6c509d8b9e056e317dd8b34bfc93b46b1c5bdff")
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
        let secondJSON = recomputedEvidenceJSON(evidenceJSON(qualified: true).replacingOccurrences(
            of: "\"trainingDays\":24", with: "\"trainingDays\":23"))
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
            "trainingDays": qualified ? 24 : 4,
            "outOfSampleDays": qualified ? 8 : 0,
            "maxMonthlySampleShare": qualified ? 0.25 : 1.0,
            "maximumMonthlySampleShare": 0.5
        ]
        var object: [String: Any] = [
            "schemaVersion": 1, "methodologyVersion": "minute-research-1",
            "evidenceId": String(repeating: "a", count: 64), "securityCode": "159352", "market": "CN",
            "range": ["start": "2026-10-01", "end": "2026-10-23"],
            "asOf": asOfText, "generatedAt": generatedAtText,
            "timezone": "Asia/Shanghai", "sessionCoverage": ["complete": 20, "partial": 1, "missing": 2],
            "qualifiedIndependentDays": qualified ? 28 : 4, "minimumQuality": 90, "sources": ["fixture-provider"],
            "evidence": ["vwapBreak": ["windows": ["5": metrics]],
                         "morningRecovery": ["evidenceState": "insufficient_independent_days"],
                         "gridSpacingReplay": ["spacings": [String: Any]()]],
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
}
