import XCTest
@_spi(LedgerStorage) import FCore
@testable import FAdvisor

final class CandidateShadowScorecardTests: XCTestCase {
    private let base = ISO8601DateFormatter().date(from: "2026-10-28T02:00:00Z")!

    func testFreshTriggeredCandidateKeepsMarketOutcomeSeparateFromUserExecution() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待回落到计划买入区", targetPriceZone: zone,
            invalidationPrice: 1.08, validUntil: base.addingTimeInterval(3_600))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.104", at: 60))
        try record.appendMarketObservation(quote("1.110", at: 360))
        try record.appendMarketObservation(quote("1.115", at: 900))

        let result = record.evaluation(asOf: base.addingTimeInterval(901))
        XCTAssertEqual(result.status, .triggered)
        XCTAssertEqual(result.executionStatus, .executionUnknown,
                       "没有成交关联不等于确认未执行")
        XCTAssertEqual(result.triggerPrice, Decimal(string: "1.104"))
        XCTAssertEqual(result.freshObservationCount, 3)
        XCTAssertEqual(result.dataQuality, .freshVerified)
        XCTAssertGreaterThan(result.returnAfter5Minutes ?? 0, 0)
        XCTAssertNil(result.confirmedFillIDs.first)
    }

    func testHistoricalEvaluationDoesNotReadFutureMarketEvents() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(3_600))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.104", at: 600))

        let asOfBeforeQuote = record.evaluation(asOf: base.addingTimeInterval(300))
        XCTAssertEqual(asOfBeforeQuote.freshObservationCount, 0)
        XCTAssertEqual(asOfBeforeQuote.status, .insufficientData)
        XCTAssertNil(asOfBeforeQuote.triggeredAt)
    }

    func testStaleQuotesAreRetainedAsQualityEvidenceButDoNotTrigger() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(3_600))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        let staleQuote = try FCandidateShadowMarketObservation(
            securityCode: "159352", price: 1.104,
            quoteTimestamp: base.addingTimeInterval(60),
            capturedAt: base.addingTimeInterval(300), source: "provider",
            timestampTrust: .verifiedExchangeTimestamp, sessionStatus: .continuous)
        try record.appendMarketObservation(staleQuote)

        let result = record.evaluation(asOf: base.addingTimeInterval(301))
        XCTAssertEqual(result.status, .insufficientData)
        XCTAssertEqual(result.dataQuality, .staleObserved)
        XCTAssertEqual(result.staleObservationCount, 1)
        XCTAssertNil(result.triggeredAt)
    }

    func testWaitWithoutStructuredOpportunityRuleIsNotGivenAQualityScore() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .wait)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "今天不交易", validUntil: base.addingTimeInterval(1_800))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.20", at: 300))

        let result = record.evaluation(asOf: base.addingTimeInterval(1_801))
        XCTAssertEqual(result.status, .insufficientData,
                       "没有明确WAIT失效/机会规则时不能事后把不交易记成正确")
        XCTAssertNil(result.returnAfter5Minutes)
        XCTAssertNil(result.maximumFavorableExcursion)
        XCTAssertEqual(result.executionStatus, .executionUnknown)
    }

    func testOnlyConfirmedFillIDChangesExecutionStatusAndNeverCreatesLedgerFacts() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy, units: 300)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "计划买入")
        var record = FCandidateShadowRecord(snapshot: snapshot)
        XCTAssertEqual(record.evaluation(asOf: base).executionStatus, .executionUnknown)

        try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: UUID(), linkedAt: base.addingTimeInterval(10), units: 100))
        XCTAssertEqual(record.evaluation(asOf: base.addingTimeInterval(11)).executionStatus,
                       .partiallyExecuted)
        XCTAssertEqual(record.evaluation(asOf: base.addingTimeInterval(11)).confirmedFillIDs.count, 1)
        XCTAssertEqual(context.holdings, [], "Shadow linkage cannot create a holding")
        XCTAssertEqual(context.cashBalance, 1_000, "Shadow linkage cannot change Ledger cash")
    }

    func testOnlyExplicitReviewCanCountAsUnexecuted() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "观察计划")
        var record = FCandidateShadowRecord(snapshot: snapshot)
        XCTAssertEqual(record.evaluation(asOf: base).executionStatus, .executionUnknown)

        try record.appendExecutionReview(FCandidateShadowExecutionReview(
            reviewedAt: base.addingTimeInterval(300), note: "已确认没有执行"))
        XCTAssertEqual(record.evaluation(asOf: base.addingTimeInterval(301)).executionStatus, .unexecuted)
        XCTAssertEqual(context.cashBalance, 1_000)
        XCTAssertEqual(context.holdings, [])
    }

    func testUnverifiedOrPreDecisionQuotesCannotBeAdded() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待")
        var record = FCandidateShadowRecord(snapshot: snapshot)
        let beforeDecision = try FCandidateShadowMarketObservation(
            securityCode: "159352", price: 1.10, quoteTimestamp: base.addingTimeInterval(-1),
            capturedAt: base, source: "provider", timestampTrust: .verifiedExchangeTimestamp,
            sessionStatus: .continuous)
        XCTAssertThrowsError(try record.appendMarketObservation(beforeDecision))
        XCTAssertThrowsError(try FCandidateShadowMarketObservation(
            securityCode: "159352", price: 1.10, quoteTimestamp: base.addingTimeInterval(1),
            capturedAt: base.addingTimeInterval(2), source: "provider",
            timestampTrust: .fetchedAtOnly, sessionStatus: .continuous))
    }

    func testSnapshotIsImmutableAndDuplicateCandidateCannotReplaceHistory() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .sell)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "卖出观察")
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        XCTAssertThrowsError(try archive.append(snapshot))
        XCTAssertEqual(archive.records.first?.snapshot.targetPrice, candidate.limitPrice)
        XCTAssertEqual(archive.records.first?.snapshot.planType, .sell)
    }

    func testExpiredUntriggeredPlanIsCountedAsUntriggeredNotSuccessful() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待回落", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(600))
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        try archive.appendMarketObservation(quote("1.120", at: 120))

        let evaluation = archive.records[0].evaluation(asOf: base.addingTimeInterval(601))
        let summary = archive.scorecard(since: base, asOf: base.addingTimeInterval(601))
        XCTAssertEqual(evaluation.status, .expired)
        XCTAssertNil(evaluation.triggeredAt)
        XCTAssertEqual(summary.expiredCount, 1)
        XCTAssertEqual(summary.notTriggeredCount, 1)
    }

    func testConfirmedCandidateLimitSuppliesAnExplicitOneSidedTriggerRule() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "限价观察", validUntil: base.addingTimeInterval(3_600))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.103", at: 60))

        let result = record.evaluation(asOf: base.addingTimeInterval(61))
        XCTAssertEqual(result.status, .triggered)
        XCTAssertEqual(result.triggerPrice, Decimal(string: "1.103"))
        XCTAssertEqual(result.evaluatedLayer, .deepSeekAdvisor)
    }

    func testPostTriggerEvaluationWindowContinuesAfterCandidateExpiry() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(120))
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        try archive.appendMarketObservation(quote("1.104", at: 60))
        try archive.appendMarketObservation(quote("1.108", at: 360))
        try archive.appendMarketObservation(quote("1.115", at: 3_660))

        let evaluation = archive.records[0].evaluation(asOf: base.addingTimeInterval(3_661))
        let summary = archive.scorecard(since: base, asOf: base.addingTimeInterval(3_661))
        XCTAssertEqual(evaluation.status, .expired)
        XCTAssertEqual(evaluation.triggeredAt, base.addingTimeInterval(60))
        XCTAssertTrue(evaluation.observationWindowComplete,
                      "计划过期与触发后的行情观察完成是两个不同事实")
        XCTAssertEqual(summary.expiredCount, 1)
        XCTAssertEqual(summary.observationWindowCompleteCount, 1)
        XCTAssertNotNil(evaluation.returnAfter5Minutes,
                        "触发后的5分钟市场表现仍需保留，即使Candidate有效期已结束")
    }

    private func makeContext(at date: Date) throws -> FDecisionContext {
        let opening = FAccountOpeningSnapshot(capturedAt: date.addingTimeInterval(-60), cashBalance: 1_000)
        let book = FAccountBook(openingSnapshot: opening, cashBalance: 1_000,
                                updatedAt: date.addingTimeInterval(-60))
        let ledger = try book.readOnlySnapshot(capturedAt: date)
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: date.addingTimeInterval(-10),
            fetchedAt: date, source: "fixture-provider", timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let observation = FContextObservation(dataClass: .quote, subject: "159352",
            source: "fixture-provider", observedAt: metadata.quoteTimestamp, capturedAt: date,
            decimalValue: 1.10, quoteTemporalMetadata: metadata)
        return FDecisionContext(snapshot: ledger, observations: [observation])
    }

    private func makeCandidate(context: FDecisionContext, action: FDecisionAction,
                               units: Int64 = 200) -> FCandidateRecommendation {
        FCandidateRecommendation(accountDigest: context.accountDigest, action: action,
            instrumentCode: "159352", units: action == .wait ? nil : units,
            limitPrice: action == .wait ? nil : Decimal(string: "1.104"), rationale: "shadow fixture")
    }

    private func quote(_ price: String, at offset: TimeInterval) throws -> FCandidateShadowMarketObservation {
        let quoteTime = base.addingTimeInterval(offset)
        return try FCandidateShadowMarketObservation(securityCode: "159352",
            price: Decimal(string: price)!, quoteTimestamp: quoteTime,
            capturedAt: quoteTime.addingTimeInterval(1), source: "fixture-provider",
            timestampTrust: .verifiedExchangeTimestamp, sessionStatus: .continuous)
    }
}
