import XCTest
@testable import FCore

final class RealtimeQuantTriggerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_798_000_000)

    private func plan(direction: FQuantPlanDirection = .buy,
                      validUntil: TimeInterval = 600,
                      validFromOffset: TimeInterval = -60,
                      invalidationPrice: Decimal? = nil) throws -> FQuantTriggerPlan {
        try FQuantTriggerPlan(securityCode: "159352", direction: direction,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(validFromOffset),
            validUntil: now.addingTimeInterval(validUntil), invalidationPrice: invalidationPrice)
    }

    private func quote(_ price: String, session: FMarketSessionStatus = .continuous,
                       age: TimeInterval = 1,
                       trust: FQuoteTimeTrust = .verifiedExchangeTimestamp,
                       source: String = FMarketQuoteTrustPolicy.tencentMinuteSource) throws -> FQuantQuoteSnapshot {
        let quoteTime = trust == .verifiedExchangeTimestamp ? now.addingTimeInterval(-age) : nil
        let fetchedAt = trust == .verifiedExchangeTimestamp ? now : now.addingTimeInterval(-age)
        return try FQuantQuoteSnapshot(securityCode: "159352", price: Decimal(string: price)!,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: quoteTime, fetchedAt: fetchedAt,
                source: source, timestampTrust: trust, marketSessionStatus: session))
    }

    private func rangeRegime(asOf: Date? = nil,
                             memoryEvaluationTime: Date? = nil) -> FMarketRegimeAssessment {
        // Keep fixture evidence no later than the default quote timestamp.
        let evaluationTime = asOf ?? now.addingTimeInterval(-2)
        let bars = (0..<80).map { index in
            FMarketRegimeBar(timestamp: evaluationTime.addingTimeInterval(Double(index - 79) * 86_400),
                             close: 100, volume: 1_000)
        }
        let assessment = FMarketRegimeEngine.evaluate(
            FMarketRegimeInput(market: "security:159352", securityCode: "159352", asOf: evaluationTime,
                sourceUpdatedAt: evaluationTime, source: FMarketBarTrustPolicy.tencentDailySource, bars: bars),
            now: evaluationTime)
        guard let memoryEvaluationTime else { return assessment }
        let originalMemory = assessment.memory
        let memory = FMarketRegimeMemory(
            confirmedRegime: originalMemory.confirmedRegime,
            confirmedRiskLevel: originalMemory.confirmedRiskLevel,
            pendingRegime: originalMemory.pendingRegime,
            pendingRegimeSessions: originalMemory.pendingRegimeSessions,
            pendingRiskLevel: originalMemory.pendingRiskLevel,
            pendingRiskSessions: originalMemory.pendingRiskSessions,
            lastEvaluationAt: memoryEvaluationTime)
        return FMarketRegimeAssessment(
            market: assessment.market, securityCode: assessment.securityCode,
            regime: assessment.regime, riskLevel: assessment.riskLevel,
            confidence: assessment.confidence, factors: assessment.factors,
            reasons: assessment.reasons, dataAsOf: assessment.dataAsOf,
            movingAverages: assessment.movingAverages, return5Sessions: assessment.return5Sessions,
            return20Sessions: assessment.return20Sessions,
            drawdown20Sessions: assessment.drawdown20Sessions,
            realizedVolatility20Sessions: assessment.realizedVolatility20Sessions,
            volumeExpansion: assessment.volumeExpansion, allowedStrategies: assessment.allowedStrategies,
            observationOnly: assessment.observationOnly,
            ordinaryTBuyAllowed: assessment.ordinaryTBuyAllowed, memory: memory)
    }

    func testNoPlanProducesWaitWithoutInventingOpportunity() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: nil, quote: try quote("1.104"), now: now)
        XCTAssertEqual(result.state, .waiting)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["no_candidate_plan"])
        XCTAssertNil(result.suggestedQuantity)
    }

    func testUntrustedQuoteSourcePausesTrigger() throws {
        let result = FRealtimeQuantTrigger.evaluate(
            plan: try plan(), quote: try quote("1.104", source: "unconfigured-provider"), now: now)

        XCTAssertEqual(result.state, .paused)
        XCTAssertTrue(result.reasonCodes.contains("quote_stale_or_unverified"))
        XCTAssertNil(result.suggestedQuantity)
    }

    func testPriceNearBuyZoneApproachesButDoesNotTrigger() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.108"),
            marketContext: rangeRegime(), now: now)
        XCTAssertEqual(result.state, .approaching)
        XCTAssertEqual(result.signal, .approachingBuy)
        XCTAssertEqual(result.suggestedQuantity, 300)
        XCTAssertEqual(result.signalScore, 60)
    }

    func testInvalidApproachDistancePausesInsteadOfExpandingZone() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.108"),
            now: now, approachDistance: 1)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["invalid_evaluation_parameters"])
        XCTAssertEqual(result.confidence, 0)
    }

    func testApproachComparisonAvoidsDecimalMultiplicationOverflow() throws {
        let upper = Decimal.greatestFiniteMagnitude * Decimal(string: "0.75")!
        let largePlan = try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: upper, upperPrice: upper, suggestedQuantity: 300,
            validFrom: now.addingTimeInterval(-60), validUntil: now.addingTimeInterval(600))
        let largeQuote = try FQuantQuoteSnapshot(securityCode: "159352",
            price: Decimal.greatestFiniteMagnitude,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: now, fetchedAt: now,
                source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
                marketSessionStatus: .continuous))
        let result = FRealtimeQuantTrigger.evaluate(plan: largePlan, quote: largeQuote,
            marketContext: rangeRegime(), now: now, approachDistance: Decimal(string: "0.9")!)
        XCTAssertEqual(result.state, .approaching)
    }

    func testUnrepresentableApproachRatioFailsClosedToWaiting() throws {
        let minimumTick = Decimal(string: "0.001")!
        let tinyPlan = try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: minimumTick, upperPrice: minimumTick, suggestedQuantity: 300,
            validFrom: now.addingTimeInterval(-60), validUntil: now.addingTimeInterval(600))
        let largeQuote = try FQuantQuoteSnapshot(securityCode: "159352",
            price: Decimal.greatestFiniteMagnitude,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: now, fetchedAt: now,
                source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp,
                marketSessionStatus: .continuous))

        let result = FRealtimeQuantTrigger.evaluate(plan: tinyPlan, quote: largeQuote,
            marketContext: rangeRegime(), now: now)
        XCTAssertEqual(result.state, .waiting)
        XCTAssertEqual(result.reasonCodes, ["waiting_above_buy_zone"])
    }

    func testTriggerPlansRejectInvalidFundOrderLotsAndPriceTicks() throws {
        let validFrom = now.addingTimeInterval(-60)
        let validUntil = now.addingTimeInterval(600)
        XCTAssertThrowsError(try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 10, validFrom: validFrom, validUntil: validUntil))
        XCTAssertThrowsError(try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: Decimal(string: "1.1005")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 100, validFrom: validFrom, validUntil: validUntil))
        XCTAssertThrowsError(try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 100, validFrom: validFrom, validUntil: validUntil,
            invalidationPrice: Decimal(string: "1.1005")!))
    }

    func testDecodedTriggerPlansRevalidateOrderRulesAndPriceZone() throws {
        let sourcePlan = try plan()
        let encoded = try JSONEncoder().encode(sourcePlan)
        XCTAssertEqual(try JSONDecoder().decode(FQuantTriggerPlan.self, from: encoded), sourcePlan)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let mutations: [[String: Any]] = [
            ["suggestedQuantity": 10],
            ["lowerPrice": 1.1005],
            ["upperPrice": 1.1055],
            ["invalidationPrice": 1.1005]
        ]

        for mutation in mutations {
            var tampered = original
            for (key, value) in mutation { tampered[key] = value }
            let data = try JSONSerialization.data(withJSONObject: tampered, options: [.sortedKeys])
            XCTAssertThrowsError(try JSONDecoder().decode(FQuantTriggerPlan.self, from: data),
                                 "decoded plans must pass the same checks as newly created plans")
        }
    }

    func testPriceInsideBuyZoneTriggersCandidateOnly() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.104"),
            marketContext: rangeRegime(), now: now)
        XCTAssertEqual(result.state, .triggered)
        XCTAssertEqual(result.signal, .buyCandidate)
        XCTAssertEqual(result.reasonCodes, ["price_inside_plan_zone"])
        XCTAssertNotEqual(result.state, .filled)
    }

    func testQuoteFromBeforePlanValidityCannotTriggerThePlan() throws {
        let plan = try plan(validFromOffset: -30)
        let result = FRealtimeQuantTrigger.evaluate(plan: plan,
            quote: try quote("1.104", age: 60), marketContext: rangeRegime(), now: now)

        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["quote_predates_plan_validity"])
        XCTAssertEqual(result.confidence, 0)
    }

    func testStaleUnverifiedAndNonContinuousQuotesPauseTrigger() throws {
        let stale = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.104", age: 121), now: now)
        let unverified = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.104", trust: .fetchedAtOnly), now: now)
        let lunch = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.104", session: .lunchBreak), now: now)
        XCTAssertEqual(stale.state, .paused)
        XCTAssertEqual(unverified.state, .paused)
        XCTAssertEqual(lunch.state, .paused)
        XCTAssertEqual(stale.confidence, 0)
    }

    func testPauseRetainsOperationalStateSoMissedZoneIsNotRearmed() throws {
        let plan = try plan()
        let paused = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.104", age: 121),
            previousState: .triggered, previousPlanID: plan.id, now: now)
        XCTAssertEqual(paused.state, .paused)
        XCTAssertEqual(paused.resumeState, .triggered)
        let resumed = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.108"),
            previousState: paused.state, previousPlanID: plan.id,
            previousOperationalState: paused.resumeState, marketContext: rangeRegime(), now: now)
        XCTAssertEqual(resumed.state, .leftZone)
    }

    func testBuyPriceLeavingZoneAfterTriggerDoesNotEncourageChasing() throws {
        let plan = try plan()
        let result = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.108"),
            previousState: .triggered, previousPlanID: plan.id,
            marketContext: rangeRegime(), now: now)
        XCTAssertEqual(result.state, .leftZone)
        XCTAssertEqual(result.signal, .invalidated)
        XCTAssertEqual(result.reasonCodes, ["price_left_trigger_zone"])
    }

    func testDuplicateOrOutOfOrderQuoteCannotAdvanceCandidateState() throws {
        let plan = try plan()
        let olderQuote = try quote("1.108", age: 2)
        let repeatedTriggerPrice = try quote("1.104", age: 1)
        let leftZone = FRealtimeQuantTrigger.evaluate(plan: plan, quote: olderQuote,
            previousState: .triggered, previousPlanID: plan.id,
            marketContext: rangeRegime(), now: now,
            previousQuoteTimestamp: now.addingTimeInterval(-1))
        let duplicate = FRealtimeQuantTrigger.evaluate(plan: plan, quote: repeatedTriggerPrice,
            previousState: .waiting, previousPlanID: plan.id,
            marketContext: rangeRegime(), now: now,
            previousQuoteTimestamp: now.addingTimeInterval(-1))

        XCTAssertEqual(leftZone.state, .triggered,
                       "an older price outside the zone must not mark a previously triggered plan as LeftZone")
        XCTAssertEqual(duplicate.state, .waiting,
                       "reprocessing the same quote timestamp must not create a fresh trigger")
        XCTAssertEqual(leftZone.reasonCodes, ["duplicate_or_out_of_order_quote_ignored"])
        XCTAssertEqual(duplicate.reasonCodes, ["duplicate_or_out_of_order_quote_ignored"])
        XCTAssertEqual(leftZone.quoteTimestamp, now.addingTimeInterval(-2),
                       "the received quote remains available for diagnostics")
        XCTAssertEqual(leftZone.lastProcessedQuoteTimestamp, now.addingTimeInterval(-1),
                       "persisted trigger time must never move backward")
    }

    func testEveryEarlyReturnPreservesMonotonicQuoteWatermark() throws {
        let priorTimestamp = now.addingTimeInterval(-1)
        let delayedQuote = try quote("1.104", age: 2)
        let expired = FRealtimeQuantTrigger.evaluate(plan: try plan(validUntil: -1),
            quote: delayedQuote, now: now, previousQuoteTimestamp: priorTimestamp)
        let terminalPlan = try plan()
        let terminal = FRealtimeQuantTrigger.evaluate(plan: terminalPlan, quote: delayedQuote,
            previousState: .filled, previousPlanID: terminalPlan.id,
            now: now, previousQuoteTimestamp: priorTimestamp)
        let noPlan = FRealtimeQuantTrigger.evaluate(plan: nil, quote: delayedQuote,
            now: now, previousQuoteTimestamp: priorTimestamp)
        let noPlanWithoutWatermark = FRealtimeQuantTrigger.evaluate(
            plan: nil, quote: try quote("1.104"), now: now)
        let futureQuote = try FQuantQuoteSnapshot(securityCode: "159352",
            price: Decimal(string: "1.104")!,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: now.addingTimeInterval(60),
                fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource,
                timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous))
        let futureTimestamp = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: futureQuote,
            now: now, previousQuoteTimestamp: priorTimestamp)
        let untrustedQuote = try quote("1.104", source: "unconfigured-provider")
        let untrustedTimestamp = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: untrustedQuote,
            now: now)

        XCTAssertEqual(expired.state, .expired)
        XCTAssertEqual(terminal.state, .filled)
        XCTAssertEqual(noPlan.state, .waiting)
        XCTAssertEqual(noPlanWithoutWatermark.state, .waiting)
        XCTAssertEqual(futureTimestamp.state, .paused)
        XCTAssertEqual(untrustedTimestamp.state, .paused)
        XCTAssertEqual(expired.lastProcessedQuoteTimestamp, priorTimestamp)
        XCTAssertEqual(terminal.lastProcessedQuoteTimestamp, priorTimestamp)
        XCTAssertEqual(noPlan.lastProcessedQuoteTimestamp, priorTimestamp)
        XCTAssertNil(noPlanWithoutWatermark.lastProcessedQuoteTimestamp)
        XCTAssertEqual(futureTimestamp.lastProcessedQuoteTimestamp, priorTimestamp)
        XCTAssertNil(untrustedTimestamp.lastProcessedQuoteTimestamp)
    }

    func testPriceCrossingExplicitInvalidationInvalidatesPlan() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(invalidationPrice: Decimal(string: "1.100")!),
            quote: try quote("1.099"), marketContext: rangeRegime(), now: now)
        XCTAssertEqual(result.state, .invalidated)
        XCTAssertEqual(result.reasonCodes, ["plan_invalidation_price_crossed"])
    }

    func testExpiredAndNotYetValidPlansDoNotTrigger() throws {
        let expired = FRealtimeQuantTrigger.evaluate(plan: try plan(validUntil: -1), quote: try quote("1.104"), now: now)
        let laterPlan = try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(30), validUntil: now.addingTimeInterval(600))
        let waiting = FRealtimeQuantTrigger.evaluate(plan: laterPlan, quote: try quote("1.104"),
            marketContext: rangeRegime(), now: now)
        XCTAssertEqual(expired.state, .expired)
        XCTAssertEqual(waiting.state, .waiting)
    }

    func testSecurityMismatchPausesRatherThanUsingWrongQuote() throws {
        let wrongQuote = try FQuantQuoteSnapshot(securityCode: "159866", price: Decimal(string: "1.104")!,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: now, fetchedAt: now,
                source: FMarketQuoteTrustPolicy.tencentMinuteSource, timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous))
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: wrongQuote, now: now)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["quote_plan_security_mismatch"])
    }

    func testManuallyConfirmedFilledStateIsStickyButTriggerNeverInfersFill() throws {
        let plan = try plan()
        let trigger = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.104"),
            marketContext: rangeRegime(), now: now)
        let filled = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.104"),
            previousState: .filled, previousPlanID: plan.id, marketContext: rangeRegime(), now: now)
        XCTAssertEqual(trigger.state, .triggered)
        XCTAssertEqual(filled.state, .filled)
        XCTAssertEqual(filled.signal, .filled)
    }

    func testTBuyAndSellDirectionsKeepDistinctCandidateSignals() throws {
        let tBuy = try FQuantTriggerPlan(securityCode: "159352", direction: .tBuy,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(-60), validUntil: now.addingTimeInterval(600))
        let tSell = try FQuantTriggerPlan(securityCode: "159352", direction: .tSell,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(-60), validUntil: now.addingTimeInterval(600))
        XCTAssertEqual(FRealtimeQuantTrigger.evaluate(plan: tBuy, quote: try quote("1.104"),
            marketContext: rangeRegime(), now: now).signal, .tBuyCandidate)
        XCTAssertEqual(FRealtimeQuantTrigger.evaluate(plan: tSell, quote: try quote("1.104"),
            marketContext: rangeRegime(), now: now).signal, .tSellCandidate)
    }

    func testStateFromReplacedPlanIsNotCarriedIntoNewPlan() throws {
        let replacementPlan = try plan()
        let result = FRealtimeQuantTrigger.evaluate(plan: replacementPlan, quote: try quote("1.108"),
            previousState: .triggered, previousPlanID: UUID(), marketContext: rangeRegime(), now: now)
        XCTAssertEqual(result.state, .approaching)
        XCTAssertEqual(result.planID, replacementPlan.id)
    }

    func testMissingMarketRegimeCannotProduceAnAssetChangingTrigger() throws {
        let result = FRealtimeQuantTrigger.evaluate(
            plan: try plan(), quote: try quote("1.104"), now: now)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertEqual(result.reasonCodes, ["market_context_unavailable"])
    }

    func testStaleMarketRegimeCannotProduceAnAssetChangingTrigger() throws {
        let result = FRealtimeQuantTrigger.evaluate(
            plan: try plan(), quote: try quote("1.104"),
            marketContext: rangeRegime(asOf: now.addingTimeInterval(-6 * 86_400)), now: now)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertEqual(result.reasonCodes, ["market_context_stale_or_unverified"])
    }

    func testRegimeEvidenceLaterThanQuoteCannotTriggerFromOlderQuote() throws {
        let quoteSnapshot = try quote("1.104", age: 1)
        let regime = rangeRegime(asOf: now.addingTimeInterval(-0.5))

        let result = FRealtimeQuantTrigger.evaluate(
            plan: try plan(), quote: quoteSnapshot, marketContext: regime, now: now)

        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.confidence, 0)
        XCTAssertEqual(result.reasonCodes, ["market_context_postdates_quote"])

        let oldEvidenceNewMemory = rangeRegime(
            asOf: now.addingTimeInterval(-2), memoryEvaluationTime: now.addingTimeInterval(-0.5))
        let second = FRealtimeQuantTrigger.evaluate(
            plan: try plan(),
            quote: try quote("1.104", age: 1),
            marketContext: oldEvidenceNewMemory,
            now: now)
        XCTAssertEqual(second.state, .paused)
        XCTAssertEqual(second.reasonCodes, ["market_context_stale_or_unverified"])
    }

    func testFutureOrInconsistentRegimeMemoryCannotProduceAnAssetChangingTrigger() throws {
        let base = rangeRegime()
        let futureMemory = FMarketRegimeMemory(
            confirmedRegime: base.memory.confirmedRegime,
            confirmedRiskLevel: base.memory.confirmedRiskLevel,
            pendingRegime: base.memory.pendingRegime,
            pendingRegimeSessions: base.memory.pendingRegimeSessions,
            pendingRiskLevel: base.memory.pendingRiskLevel,
            pendingRiskSessions: base.memory.pendingRiskSessions,
            lastEvaluationAt: now.addingTimeInterval(1))
        let inconsistent = FMarketRegimeAssessment(
            market: base.market, securityCode: base.securityCode, regime: base.regime,
            riskLevel: base.riskLevel, confidence: base.confidence, factors: base.factors,
            reasons: base.reasons, dataAsOf: base.dataAsOf, movingAverages: base.movingAverages,
            return5Sessions: base.return5Sessions, return20Sessions: base.return20Sessions,
            drawdown20Sessions: base.drawdown20Sessions,
            realizedVolatility20Sessions: base.realizedVolatility20Sessions,
            volumeExpansion: base.volumeExpansion, allowedStrategies: base.allowedStrategies,
            observationOnly: base.observationOnly, ordinaryTBuyAllowed: base.ordinaryTBuyAllowed,
            memory: futureMemory)

        let result = FRealtimeQuantTrigger.evaluate(
            plan: try plan(), quote: try quote("1.104"), marketContext: inconsistent, now: now)

        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["market_context_stale_or_unverified"])
    }
}
