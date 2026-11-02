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

    func testShadowSnapshotDefaultsToGuardDeniedUnlessExplicitlyAllowed() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let conservative = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "计划观察")
        let allowed = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "计划观察", guardAllowed: true)

        XCTAssertFalse(conservative.guardAllowed)
        XCTAssertTrue(allowed.guardAllowed)
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
            capturedAt: base.addingTimeInterval(300), source: FMarketQuoteTrustPolicy.tencentMinuteSource,
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

        let fillID = UUID()
        let fillTime = base.addingTimeInterval(10)
        let fill = FConfirmedFill(id: fillID, sequence: 1, tradedAt: fillTime,
            instrumentCode: "159352", side: .buy, units: 100, price: 1.10, fee: 0,
            userConfirmation: .init(confirmedAt: fillTime, confirmationNote: "用户确认成交"))
        let ledger = try FAccountBook(accountID: context.accountID,
            openingSnapshot: .init(capturedAt: base, cashBalance: 1_000),
            cashBalance: 890, positions: [FPosition(instrumentCode: "159352", name: "测试ETF",
                units: 100, bookCost: 110, acquiredAt: fillTime)], fills: [fill],
            updatedAt: fillTime).readOnlySnapshot(capturedAt: base.addingTimeInterval(11))
        XCTAssertThrowsError(try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: UUID(), linkedAt: fillTime, units: 100), ledgerSnapshot: ledger),
            "任意UUID不得伪装成账本已确认成交")
        XCTAssertThrowsError(try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: fillID, linkedAt: fillTime.addingTimeInterval(1), units: 100),
            ledgerSnapshot: ledger), "成交时间必须与真实账本记录一致")
        XCTAssertThrowsError(try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: fillID, linkedAt: fillTime, units: 99), ledgerSnapshot: ledger),
            "关联份额必须等于账本实际成交份额")
        let otherAccountLedger = try FAccountBook(accountID: UUID(),
            openingSnapshot: .init(capturedAt: base, cashBalance: 1_000),
            cashBalance: 890, positions: [FPosition(instrumentCode: "159352", name: "测试ETF",
                units: 100, bookCost: 110, acquiredAt: fillTime)], fills: [fill],
            updatedAt: fillTime).readOnlySnapshot(capturedAt: base.addingTimeInterval(11))
        XCTAssertThrowsError(try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: fillID, linkedAt: fillTime, units: 100),
            ledgerSnapshot: otherAccountLedger), "不得将另一个账户的成交挂入当前Shadow")
        let otherSecurityFill = FConfirmedFill(id: fillID, sequence: 1, tradedAt: fillTime,
            instrumentCode: "510300", side: .buy, units: 100, price: 1.10, fee: 0,
            userConfirmation: .init(confirmedAt: fillTime, confirmationNote: "用户确认成交"))
        let otherSecurityLedger = try FAccountBook(openingSnapshot: .init(capturedAt: base, cashBalance: 1_000),
            cashBalance: 890, positions: [FPosition(instrumentCode: "510300", name: "另一ETF",
                units: 100, bookCost: 110, acquiredAt: fillTime)], fills: [otherSecurityFill],
            updatedAt: fillTime).readOnlySnapshot(capturedAt: base.addingTimeInterval(11))
        XCTAssertThrowsError(try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: fillID, linkedAt: fillTime, units: 100),
            ledgerSnapshot: otherSecurityLedger), "不得关联另一个证券的成交")
        let sellFill = FConfirmedFill(id: fillID, sequence: 1, tradedAt: fillTime,
            instrumentCode: "159352", side: .sell, units: 100, price: 1.10, fee: 0,
            costBasisRemoved: 110,
            userConfirmation: .init(confirmedAt: fillTime, confirmationNote: "用户确认成交"))
        let sellOpeningPosition = FPosition(instrumentCode: "159352", name: "测试ETF",
            units: 200, bookCost: 220, acquiredAt: base)
        let wrongSideLedger = try FAccountBook(
            openingSnapshot: .init(capturedAt: base, cashBalance: 890, positions: [sellOpeningPosition]),
            cashBalance: 1_000, positions: [FPosition(instrumentCode: "159352", name: "测试ETF",
                units: 100, bookCost: 110, acquiredAt: base)], fills: [sellFill],
            updatedAt: fillTime).readOnlySnapshot(capturedAt: base.addingTimeInterval(11))
        XCTAssertThrowsError(try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: fillID, linkedAt: fillTime, units: 100),
            ledgerSnapshot: wrongSideLedger), "买入Candidate不得关联卖出成交")
        let futureFillTime = base.addingTimeInterval(20)
        let futureFill = FConfirmedFill(sequence: 1, tradedAt: futureFillTime,
            instrumentCode: "159352", side: .buy, units: 100, price: 1.10, fee: 0,
            userConfirmation: .init(confirmedAt: futureFillTime, confirmationNote: "用户确认成交"))
        let futureLedger = try FAccountBook(openingSnapshot: .init(capturedAt: base, cashBalance: 1_000),
            cashBalance: 890, positions: [FPosition(instrumentCode: "159352", name: "测试ETF",
                units: 100, bookCost: 110, acquiredAt: futureFillTime)], fills: [futureFill],
            updatedAt: futureFillTime).readOnlySnapshot(capturedAt: base.addingTimeInterval(11))
        var futureRecord = FCandidateShadowRecord(snapshot: snapshot)
        XCTAssertThrowsError(try futureRecord.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: futureFill.id, linkedAt: futureFillTime, units: 100),
            ledgerSnapshot: futureLedger), "尚未到达成交时点的账本记录不得计入已执行")
        try record.appendConfirmedExecution(FCandidateShadowFillLink(
            confirmedFillID: fillID, linkedAt: fillTime, units: 100), ledgerSnapshot: ledger)
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

    func testExecutionReviewPreventsConflictingFillLinkAndKeepsArchiveValid() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "观察计划")
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        try archive.appendExecutionReview(candidateID: candidate.id,
            review: FCandidateShadowExecutionReview(
                reviewedAt: base.addingTimeInterval(10), note: "已确认没有执行"))

        let emptyLedger = try FAccountBook(openingSnapshot: .init(capturedAt: base, cashBalance: 1_000),
            cashBalance: 1_000, updatedAt: base).readOnlySnapshot(capturedAt: base)
        XCTAssertThrowsError(try archive.appendConfirmedExecution(candidateID: candidate.id,
            link: FCandidateShadowFillLink(confirmedFillID: UUID(),
                linkedAt: base.addingTimeInterval(11), units: 100),
            ledgerSnapshot: emptyLedger))

        XCTAssertNoThrow(try archive.validate())
        XCTAssertEqual(archive.records.first?.evaluation(asOf: base.addingTimeInterval(12)).executionStatus,
                       .unexecuted)
    }

    func testDecodedArchiveRevalidatesFrozenPriceZoneBounds() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let validZone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "观察", targetPriceZone: validZone)
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        let encoded = try JSONEncoder().encode(archive)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var records = try XCTUnwrap(root["records"] as? [[String: Any]])
        var record = try XCTUnwrap(records.first)
        var frozen = try XCTUnwrap(record["snapshot"] as? [String: Any])
        var zone = try XCTUnwrap(frozen["targetPriceZone"] as? [String: Any])
        zone["lower"] = 1.105
        zone["upper"] = 1.103
        frozen["targetPriceZone"] = zone
        record["snapshot"] = frozen
        records[0] = record
        root["records"] = records
        let corrupted = try JSONSerialization.data(withJSONObject: root)
        let decoded = try JSONDecoder().decode(FCandidateShadowArchive.self, from: corrupted)

        XCTAssertThrowsError(try decoded.validate())
    }

    func testShadowSnapshotRequiresInvalidationBeyondThePlanZone() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)

        XCTAssertThrowsError(try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "买入观察", targetPriceZone: zone, invalidationPrice: 1.104))

        let valid = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "买入观察", targetPriceZone: zone, invalidationPrice: 1.08)
        var archive = FCandidateShadowArchive()
        try archive.append(valid)
        let encoded = try JSONEncoder().encode(archive)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var records = try XCTUnwrap(root["records"] as? [[String: Any]])
        var record = try XCTUnwrap(records.first)
        var frozen = try XCTUnwrap(record["snapshot"] as? [String: Any])
        frozen["invalidationPrice"] = 1.104
        record["snapshot"] = frozen
        records[0] = record
        root["records"] = records
        let corrupted = try JSONSerialization.data(withJSONObject: root)
        let decoded = try JSONDecoder().decode(FCandidateShadowArchive.self, from: corrupted)

        XCTAssertThrowsError(try decoded.validate())
    }

    func testUnverifiedOrPreDecisionQuotesCannotBeAdded() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待")
        var record = FCandidateShadowRecord(snapshot: snapshot)
        let beforeDecision = try FCandidateShadowMarketObservation(
            securityCode: "159352", price: 1.10, quoteTimestamp: base.addingTimeInterval(-1),
            capturedAt: base, source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            timestampTrust: .verifiedExchangeTimestamp,
            sessionStatus: .continuous)
        XCTAssertThrowsError(try record.appendMarketObservation(beforeDecision))
        XCTAssertThrowsError(try FCandidateShadowMarketObservation(
            securityCode: "159352", price: 1.10, quoteTimestamp: base.addingTimeInterval(1),
            capturedAt: base.addingTimeInterval(2), source: "provider",
            timestampTrust: .fetchedAtOnly, sessionStatus: .continuous))
    }

    func testUntrustedShadowQuoteSourceIsRejectedAndDecodedArchiveIsRevalidated() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "观察", targetPriceZone: zone)
        let quoteTime = base.addingTimeInterval(60)
        XCTAssertThrowsError(try FCandidateShadowMarketObservation(
            securityCode: "159352", price: 1.104, quoteTimestamp: quoteTime,
            capturedAt: quoteTime.addingTimeInterval(1), source: "spoofed-provider",
            timestampTrust: .verifiedExchangeTimestamp, sessionStatus: .continuous))

        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.104", at: 60))
        var archive = FCandidateShadowArchive(records: [record])
        let encoded = try JSONEncoder().encode(archive)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var records = try XCTUnwrap(root["records"] as? [[String: Any]])
        var storedRecord = try XCTUnwrap(records.first)
        var events = try XCTUnwrap(storedRecord["events"] as? [[String: Any]])
        var event = try XCTUnwrap(events.first)
        var marketPayload = try XCTUnwrap(event["market"] as? [String: Any])
        if var associatedValue = marketPayload["_0"] as? [String: Any] {
            associatedValue["source"] = "spoofed-provider"
            marketPayload["_0"] = associatedValue
        } else {
            marketPayload["source"] = "spoofed-provider"
        }
        event["market"] = marketPayload
        events[0] = event
        storedRecord["events"] = events
        records[0] = storedRecord
        root["records"] = records
        archive = try JSONDecoder().decode(FCandidateShadowArchive.self,
            from: JSONSerialization.data(withJSONObject: root))

        XCTAssertThrowsError(try archive.validate())
        XCTAssertNil(archive.records[0].evaluation(asOf: base.addingTimeInterval(61)).triggeredAt)
        XCTAssertEqual(archive.records[0].evaluation(asOf: base.addingTimeInterval(61)).freshObservationCount, 0)
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
        for offset in stride(from: 60.0, through: 600.0, by: 60.0) {
            try archive.appendMarketObservation(quote("1.120", at: offset))
        }

        let evaluation = archive.records[0].evaluation(asOf: base.addingTimeInterval(601))
        let summary = archive.scorecard(since: base, asOf: base.addingTimeInterval(601))
        XCTAssertEqual(evaluation.status, .expired)
        XCTAssertNil(evaluation.triggeredAt)
        XCTAssertEqual(summary.expiredCount, 1)
        XCTAssertEqual(summary.notTriggeredCount, 1)
        XCTAssertTrue(evaluation.observationWindowComplete)
    }

    func testSparseExpiredUntriggeredPlanIsNotCountedAsNoTrigger() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待回落", validUntil: base.addingTimeInterval(600))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.120", at: 120))

        let evaluation = record.evaluation(asOf: base.addingTimeInterval(601))

        XCTAssertEqual(evaluation.status, .expired)
        XCTAssertFalse(evaluation.notTriggered,
                       "稀疏行情不能证明有效期内从未触发")
        XCTAssertFalse(evaluation.observationWindowComplete)
    }

    func testWaitWithoutAPriceConditionIsNotCountedAsUntriggered() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .wait)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "继续观察", validUntil: base.addingTimeInterval(600))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        for offset in stride(from: 60.0, through: 600.0, by: 60.0) {
            try record.appendMarketObservation(quote("1.120", at: offset))
        }

        let evaluation = record.evaluation(asOf: base.addingTimeInterval(601))

        XCTAssertEqual(evaluation.status, .insufficientData)
        XCTAssertFalse(evaluation.notTriggered,
                       "没有明确价格条件的WAIT不属于未触发计划分母")
    }

    func testTriggeredPlanStillDetectsInvalidationAfterPlanExpiry() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待回落", targetPriceZone: zone,
            invalidationPrice: 1.08, validUntil: base.addingTimeInterval(120))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.104", at: 60))
        try record.appendMarketObservation(quote("1.079", at: 180))

        let evaluation = record.evaluation(asOf: base.addingTimeInterval(181))

        XCTAssertEqual(evaluation.triggeredAt, base.addingTimeInterval(60))
        XCTAssertEqual(evaluation.status, .invalidationObserved)
        XCTAssertEqual(evaluation.observationWindowComplete, false)
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

    func testBuyChaseThresholdOverflowDoesNotCrashOrMarkCandidateLeftZone() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let maximum = Decimal.greatestFiniteMagnitude
        let zone = try FShadowPriceZone(lower: 1, upper: maximum)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(3_600), maxChaseDistance: maximum)
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.104", at: 60))

        XCTAssertEqual(record.evaluation(asOf: base.addingTimeInterval(61)).status, .triggered)
    }

    func testSellLeavingPlanZoneUsesTheConfiguredChaseDistance() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .sell)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待反弹", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(3_600), maxChaseDistance: Decimal(string: "0.01"))
        var record = FCandidateShadowRecord(snapshot: snapshot)
        try record.appendMarketObservation(quote("1.104", at: 60))
        try record.appendMarketObservation(quote("1.080", at: 120))

        XCTAssertEqual(record.evaluation(asOf: base.addingTimeInterval(121)).status, .leftZone)
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
        for offset in stride(from: 120.0, through: 3_660.0, by: 60.0) {
            try archive.appendMarketObservation(quote("1.108", at: offset))
        }

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

    func testPostTriggerObservationWindowIsCappedAtOneHourEvenForLongPlans() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let zone = try FShadowPriceZone(lower: 1.103, upper: 1.105)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待", targetPriceZone: zone,
            validUntil: base.addingTimeInterval(14_400))
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        try archive.appendMarketObservation(quote("1.104", at: 60))
        for offset in stride(from: 120.0, through: 3_660.0, by: 60.0) {
            try archive.appendMarketObservation(quote("1.108", at: offset))
        }
        try archive.appendMarketObservation(quote("1.120", at: 10_800))

        let record = try XCTUnwrap(archive.records.first)
        let evaluation = record.evaluation(asOf: base.addingTimeInterval(10_801))

        XCTAssertEqual(record.events.count, 61,
                       "一小时以后的数据不得混入已触发候选的影子观察窗口")
        XCTAssertEqual(evaluation.status, .observationWindowComplete)
        XCTAssertTrue(evaluation.observationWindowComplete)
        XCTAssertEqual(try XCTUnwrap(evaluation.maximumFavorableExcursion),
                       Decimal(string: "0.00362318840579710144927536231884057971")!)
    }

    func testSparseTriggeredWindowIsInsufficientInsteadOfComplete() throws {
        let context = try makeContext(at: base)
        let candidate = makeCandidate(context: context, action: .buy)
        let snapshot = try FCandidateShadowSnapshot(candidate: candidate, context: context,
            advisorConclusion: "等待", validUntil: base.addingTimeInterval(7_200))
        var archive = FCandidateShadowArchive()
        try archive.append(snapshot)
        try archive.appendMarketObservation(quote("1.104", at: 60))
        try archive.appendMarketObservation(quote("1.108", at: 3_600))

        let evaluation = try XCTUnwrap(archive.records.first)
            .evaluation(asOf: base.addingTimeInterval(3_661))

        XCTAssertEqual(evaluation.status, .insufficientData)
        XCTAssertFalse(evaluation.observationWindowComplete)
        XCTAssertNil(evaluation.maximumFavorableExcursion,
                     "覆盖不足时不能把采样点极值冒充完整窗口MFE")
        XCTAssertNil(evaluation.maximumAdverseExcursion,
                     "覆盖不足时不能把采样点极值冒充完整窗口MAE")
    }

    private func makeContext(at date: Date) throws -> FDecisionContext {
        let opening = FAccountOpeningSnapshot(capturedAt: date.addingTimeInterval(-60), cashBalance: 1_000)
        let book = FAccountBook(openingSnapshot: opening, cashBalance: 1_000,
                                updatedAt: date.addingTimeInterval(-60))
        let ledger = try book.readOnlySnapshot(capturedAt: date)
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: date.addingTimeInterval(-10),
            fetchedAt: date, source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: .continuous)
        let observation = FContextObservation(dataClass: .quote, subject: "159352",
            source: FMarketQuoteTrustPolicy.tencentMinuteSource, observedAt: metadata.quoteTimestamp, capturedAt: date,
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
            capturedAt: quoteTime.addingTimeInterval(1), source: FMarketQuoteTrustPolicy.tencentMinuteSource,
            timestampTrust: .verifiedExchangeTimestamp, sessionStatus: .continuous)
    }
}
