import XCTest
@testable import FCore

final class RealtimeQuantTriggerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_798_000_000)

    private func plan(direction: FQuantPlanDirection = .buy,
                      validUntil: TimeInterval = 600,
                      invalidationPrice: Decimal? = nil) throws -> FQuantTriggerPlan {
        try FQuantTriggerPlan(securityCode: "159352", direction: direction,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(-60),
            validUntil: now.addingTimeInterval(validUntil), invalidationPrice: invalidationPrice)
    }

    private func quote(_ price: String, session: FMarketSessionStatus = .continuous,
                       age: TimeInterval = 1,
                       trust: FQuoteTimeTrust = .verifiedExchangeTimestamp) throws -> FQuantQuoteSnapshot {
        let quoteTime = trust == .verifiedExchangeTimestamp ? now.addingTimeInterval(-age) : nil
        let fetchedAt = trust == .verifiedExchangeTimestamp ? now : now.addingTimeInterval(-age)
        return try FQuantQuoteSnapshot(securityCode: "159352", price: Decimal(string: price)!,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: quoteTime, fetchedAt: fetchedAt,
                source: "test-quote", timestampTrust: trust, marketSessionStatus: session))
    }

    func testNoPlanProducesWaitWithoutInventingOpportunity() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: nil, quote: try quote("1.104"), now: now)
        XCTAssertEqual(result.state, .waiting)
        XCTAssertEqual(result.signal, .wait)
        XCTAssertEqual(result.reasonCodes, ["no_candidate_plan"])
        XCTAssertNil(result.suggestedQuantity)
    }

    func testPriceNearBuyZoneApproachesButDoesNotTrigger() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.108"), now: now)
        XCTAssertEqual(result.state, .approaching)
        XCTAssertEqual(result.signal, .approachingBuy)
        XCTAssertEqual(result.suggestedQuantity, 300)
        XCTAssertEqual(result.signalScore, 60)
    }

    func testPriceInsideBuyZoneTriggersCandidateOnly() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: try quote("1.104"), now: now)
        XCTAssertEqual(result.state, .triggered)
        XCTAssertEqual(result.signal, .buyCandidate)
        XCTAssertEqual(result.reasonCodes, ["price_inside_plan_zone"])
        XCTAssertNotEqual(result.state, .filled)
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
            previousOperationalState: paused.resumeState, now: now)
        XCTAssertEqual(resumed.state, .leftZone)
    }

    func testBuyPriceLeavingZoneAfterTriggerDoesNotEncourageChasing() throws {
        let plan = try plan()
        let result = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.108"),
            previousState: .triggered, previousPlanID: plan.id, now: now)
        XCTAssertEqual(result.state, .leftZone)
        XCTAssertEqual(result.signal, .invalidated)
        XCTAssertEqual(result.reasonCodes, ["price_left_trigger_zone"])
    }

    func testPriceCrossingExplicitInvalidationInvalidatesPlan() throws {
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(invalidationPrice: Decimal(string: "1.100")!),
            quote: try quote("1.099"), now: now)
        XCTAssertEqual(result.state, .invalidated)
        XCTAssertEqual(result.reasonCodes, ["plan_invalidation_price_crossed"])
    }

    func testExpiredAndNotYetValidPlansDoNotTrigger() throws {
        let expired = FRealtimeQuantTrigger.evaluate(plan: try plan(validUntil: -1), quote: try quote("1.104"), now: now)
        let laterPlan = try FQuantTriggerPlan(securityCode: "159352", direction: .buy,
            lowerPrice: Decimal(string: "1.103")!, upperPrice: Decimal(string: "1.105")!,
            suggestedQuantity: 300, validFrom: now.addingTimeInterval(30), validUntil: now.addingTimeInterval(600))
        let waiting = FRealtimeQuantTrigger.evaluate(plan: laterPlan, quote: try quote("1.104"), now: now)
        XCTAssertEqual(expired.state, .expired)
        XCTAssertEqual(waiting.state, .waiting)
    }

    func testSecurityMismatchPausesRatherThanUsingWrongQuote() throws {
        let wrongQuote = try FQuantQuoteSnapshot(securityCode: "159866", price: Decimal(string: "1.104")!,
            temporalMetadata: FQuoteTemporalMetadata(quoteTimestamp: now, fetchedAt: now,
                source: "test-quote", timestampTrust: .verifiedExchangeTimestamp, marketSessionStatus: .continuous))
        let result = FRealtimeQuantTrigger.evaluate(plan: try plan(), quote: wrongQuote, now: now)
        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.reasonCodes, ["quote_plan_security_mismatch"])
    }

    func testManuallyConfirmedFilledStateIsStickyButTriggerNeverInfersFill() throws {
        let plan = try plan()
        let trigger = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.104"), now: now)
        let filled = FRealtimeQuantTrigger.evaluate(plan: plan, quote: try quote("1.104"),
            previousState: .filled, previousPlanID: plan.id, now: now)
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
        XCTAssertEqual(FRealtimeQuantTrigger.evaluate(plan: tBuy, quote: try quote("1.104"), now: now).signal, .tBuyCandidate)
        XCTAssertEqual(FRealtimeQuantTrigger.evaluate(plan: tSell, quote: try quote("1.104"), now: now).signal, .tSellCandidate)
    }

    func testStateFromReplacedPlanIsNotCarriedIntoNewPlan() throws {
        let replacementPlan = try plan()
        let result = FRealtimeQuantTrigger.evaluate(plan: replacementPlan, quote: try quote("1.108"),
            previousState: .triggered, previousPlanID: UUID(), now: now)
        XCTAssertEqual(result.state, .approaching)
        XCTAssertEqual(result.planID, replacementPlan.id)
    }
}
