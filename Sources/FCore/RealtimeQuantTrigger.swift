import Foundation

/// The direction of a user-reviewable Candidate Plan monitored by the local
/// trigger. This type does not represent an order and cannot mutate the ledger.
public enum FQuantPlanDirection: String, Codable, Equatable, Sendable {
    case buy
    case sell
    case tBuy
    case tSell

    fileprivate var approachesFromAbove: Bool {
        self == .buy || self == .tBuy
    }
}

/// A bounded, deterministic price zone copied from a guarded Candidate Plan.
/// Creation is only a data contract; callers must pass only user-reviewable
/// plans with a fresh, security-matched Regime assessment. A trigger never
/// submits an order or marks a plan filled.
public struct FQuantTriggerPlan: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let securityCode: String
    public let direction: FQuantPlanDirection
    public let lowerPrice: Decimal
    public let upperPrice: Decimal
    public let suggestedQuantity: Int64
    public let validFrom: Date
    public let validUntil: Date
    public let invalidationPrice: Decimal?

    public init(id: UUID = UUID(), securityCode: String, direction: FQuantPlanDirection,
                lowerPrice: Decimal, upperPrice: Decimal, suggestedQuantity: Int64,
                validFrom: Date, validUntil: Date, invalidationPrice: Decimal? = nil) throws {
        let sourceCodeIsValid = securityCode.count == 6 && securityCode.utf8.count == 6 &&
            securityCode.utf8.allSatisfy { (48...57).contains($0) }
        let pricesAreValid = upperPrice >= lowerPrice &&
            FMainlandFundTradingRules.isValidLimitPrice(lowerPrice) &&
            FMainlandFundTradingRules.isValidLimitPrice(upperPrice)
        let datesAreValid = validFrom.timeIntervalSince1970.isFinite &&
            validUntil.timeIntervalSince1970.isFinite && validFrom < validUntil
        let invalidationIsValid: Bool
        if let invalidationPrice {
            invalidationIsValid = FMainlandFundTradingRules.isValidLimitPrice(invalidationPrice) &&
                (direction.approachesFromAbove ? invalidationPrice < lowerPrice : invalidationPrice > upperPrice)
        } else {
            invalidationIsValid = true
        }
        guard sourceCodeIsValid, pricesAreValid,
              FMainlandFundTradingRules.isValidOrderUnits(suggestedQuantity),
              datesAreValid, invalidationIsValid else { throw FMarketDataError.invalidPayload }
        self.id = id
        self.securityCode = securityCode
        self.direction = direction
        self.lowerPrice = lowerPrice
        self.upperPrice = upperPrice
        self.suggestedQuantity = suggestedQuantity
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.invalidationPrice = invalidationPrice
    }

    private enum CodingKeys: String, CodingKey {
        case id, securityCode, direction, lowerPrice, upperPrice, suggestedQuantity
        case validFrom, validUntil, invalidationPrice
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: values.decode(UUID.self, forKey: .id),
            securityCode: values.decode(String.self, forKey: .securityCode),
            direction: values.decode(FQuantPlanDirection.self, forKey: .direction),
            lowerPrice: values.decode(Decimal.self, forKey: .lowerPrice),
            upperPrice: values.decode(Decimal.self, forKey: .upperPrice),
            suggestedQuantity: values.decode(Int64.self, forKey: .suggestedQuantity),
            validFrom: values.decode(Date.self, forKey: .validFrom),
            validUntil: values.decode(Date.self, forKey: .validUntil),
            invalidationPrice: values.decodeIfPresent(Decimal.self, forKey: .invalidationPrice))
    }

}

/// Latest verified exchange quote. Timestamp trust and retrieval time remain
/// explicit so local triggers can fail closed on stale or unverifiable quotes.
public struct FQuantQuoteSnapshot: Equatable, Sendable {
    public let securityCode: String
    public let price: Decimal
    public let temporalMetadata: FQuoteTemporalMetadata

    public init(securityCode: String, price: Decimal, temporalMetadata: FQuoteTemporalMetadata) throws {
        let sourceCodeIsValid = securityCode.count == 6 && securityCode.utf8.count == 6 &&
            securityCode.utf8.allSatisfy { (48...57).contains($0) }
        guard sourceCodeIsValid, price > 0,
              NSDecimalNumber(decimal: price).doubleValue.isFinite,
              temporalMetadata.source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw FMarketDataError.invalidPayload
        }
        self.securityCode = securityCode
        self.price = price
        self.temporalMetadata = temporalMetadata
    }

    public init(snapshot: FCurrentIntradaySnapshot, sessionStatus: FMarketSessionStatus) throws {
        let metadata = FQuoteTemporalMetadata(
            quoteTimestamp: snapshot.quoteTimestamp, fetchedAt: snapshot.fetchedAt,
            source: snapshot.source, timestampTrust: .verifiedExchangeTimestamp,
            marketSessionStatus: sessionStatus)
        try self.init(securityCode: snapshot.securityCode,
                      price: snapshot.latestPrice ?? 0, temporalMetadata: metadata)
    }
}

public enum FRealtimeTriggerState: String, Codable, Equatable, Sendable {
    case waiting
    case approaching
    case triggered
    case leftZone
    case filled
    case invalidated
    case expired
    case paused
}

/// User-facing signal classification. `triggered` only means the observed
/// price is inside a plan zone; it never means an order was placed or filled.
public enum FQuantSignal: String, Codable, Equatable, Sendable {
    case hold
    case wait
    case approachingBuy
    case buyCandidate
    case approachingSell
    case sellCandidate
    case tBuyCandidate
    case tSellCandidate
    case invalidated
    case filled
}

public struct FQuantRealtimeAssessment: Equatable, Sendable {
    public let planID: UUID?
    public let securityCode: String
    public let state: FRealtimeTriggerState
    public let signal: FQuantSignal
    /// Deterministic proximity/state score, not a predicted return or win rate.
    public let signalScore: Int
    /// Evidence usability score: 100 only when the plan and quote are structurally
    /// valid and the quote has a verified, fresh exchange timestamp; otherwise 0.
    /// It is not a probability of profit.
    public let confidence: Int
    public let reasonCodes: [String]
    public let lowerPrice: Decimal?
    public let upperPrice: Decimal?
    public let suggestedQuantity: Int64?
    public let validUntil: Date?
    public let invalidationPrice: Decimal?
    /// Timestamp the caller must persist for duplicate/out-of-order protection.
    /// It never moves backward when an older quote is ignored.
    public let lastProcessedQuoteTimestamp: Date?
    /// Timestamp carried by the quote used to produce this assessment, which may
    /// be older than `lastProcessedQuoteTimestamp` when the quote was ignored.
    public let quoteTimestamp: Date?
    public let marketRegime: FMarketRegime?
    public let marketRiskLevel: FMarketRiskLevel?
    /// When quote quality/session pauses monitoring, persist this state and
    /// pass it back as `previousOperationalState` after the pause clears.
    public let resumeState: FRealtimeTriggerState?
}

/// Stateless, deterministic price-zone evaluator. The caller persists the last
/// state, plan ID, last processed quote timestamp, and (when paused) resumeState
/// and supplies them on the next quote. A prior state from a replaced plan is
/// discarded, repeated/out-of-order quotes cannot advance it, and a missed zone
/// is never reconstructed as a fresh trigger from the latest price alone.
public enum FRealtimeQuantTrigger {
    public static let defaultMaximumQuoteAge: TimeInterval = FQuoteTemporalMetadata.defaultMaximumAge
    public static let defaultApproachDistance: Decimal = Decimal(string: "0.003")!

    public static func evaluate(plan: FQuantTriggerPlan?, quote: FQuantQuoteSnapshot,
                                 previousState: FRealtimeTriggerState = .waiting,
                                 previousPlanID: UUID? = nil,
                                 previousOperationalState: FRealtimeTriggerState? = nil,
                                 marketContext: FMarketRegimeAssessment? = nil,
                                 now: Date = Date(),
                                 maximumQuoteAge: TimeInterval = defaultMaximumQuoteAge,
                                 approachDistance: Decimal = defaultApproachDistance,
                                 previousQuoteTimestamp: Date? = nil)
        -> FQuantRealtimeAssessment {
        // Every return path, including paused and terminal states, must expose
        // a monotonic persistence watermark. A stale asynchronous callback can
        // still reach an early return before the duplicate-quote gate below.
        func assessment(plan: FQuantTriggerPlan?, quote: FQuantQuoteSnapshot,
                        marketContext: FMarketRegimeAssessment?, state: FRealtimeTriggerState,
                        reasons: [String], confidence: Int,
                        resumeState: FRealtimeTriggerState? = nil,
                        lastProcessedQuoteTimestamp: Date? = nil) -> FQuantRealtimeAssessment {
            let metadata = quote.temporalMetadata
            let usableQuoteTimestamp: Date?
            if let plan, quote.securityCode == plan.securityCode,
               metadata.timestampTrust == .verifiedExchangeTimestamp,
               FMarketQuoteTrustPolicy.isTrusted(metadata.source),
               let timestamp = metadata.quoteTimestamp, let fetchedAt = metadata.fetchedAt,
               timestamp.timeIntervalSince1970.isFinite, fetchedAt.timeIntervalSince1970.isFinite,
               timestamp <= fetchedAt, fetchedAt <= now, timestamp <= now {
                usableQuoteTimestamp = timestamp
            } else {
                usableQuoteTimestamp = nil
            }
            let priorWatermark = previousQuoteTimestamp.flatMap { timestamp -> Date? in
                timestamp.timeIntervalSince1970.isFinite && timestamp <= now ? timestamp : nil
            }
            let monotonicTimestamp = [priorWatermark, usableQuoteTimestamp].compactMap { $0 }.max()
            let explicitWatermark = lastProcessedQuoteTimestamp.flatMap { timestamp -> Date? in
                timestamp.timeIntervalSince1970.isFinite && timestamp <= now ? timestamp : nil
            }
            let effectiveTimestamp = [explicitWatermark, monotonicTimestamp]
                .compactMap { $0 }.max()
            return Self.assessment(plan: plan, quote: quote, marketContext: marketContext,
                state: state, reasons: reasons, confidence: confidence, resumeState: resumeState,
                lastProcessedQuoteTimestamp: effectiveTimestamp)
        }
        let stateBelongsToPlan = previousState == .waiting || previousPlanID == plan?.id
        let storedState = stateBelongsToPlan ? previousState : .waiting
        let operationalState = storedState == .paused
            ? (previousOperationalState ?? .waiting) : storedState
        guard now.timeIntervalSince1970.isFinite, maximumQuoteAge.isFinite,
              maximumQuoteAge >= 0, approachDistance >= 0, approachDistance < 1,
              NSDecimalNumber(decimal: approachDistance).doubleValue.isFinite else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["invalid_evaluation_parameters"], confidence: 0,
                              resumeState: operationalState)
        }

        guard let plan else {
            return assessment(plan: nil, quote: quote, marketContext: marketContext, state: .waiting,
                              reasons: ["no_candidate_plan"], confidence: 0)
        }

        if operationalState == .filled || operationalState == .invalidated ||
            operationalState == .expired || operationalState == .leftZone {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: operationalState,
                              reasons: ["terminal_plan_state"], confidence: 0)
        }
        guard quote.securityCode == plan.securityCode else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["quote_plan_security_mismatch"], confidence: 0,
                              resumeState: operationalState)
        }
        if now >= plan.validUntil {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .expired,
                              reasons: ["plan_expired"], confidence: 0)
        }
        if now < plan.validFrom {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .waiting,
                              reasons: ["plan_not_yet_valid"], confidence: 0)
        }
        guard quote.temporalMetadata.freshness(at: now, maximumAge: maximumQuoteAge) == .fresh,
              let quoteTimestamp = quote.temporalMetadata.quoteTimestamp else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["quote_stale_or_unverified"], confidence: 0,
                              resumeState: operationalState)
        }
        guard quoteTimestamp >= plan.validFrom else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["quote_predates_plan_validity"], confidence: 0,
                              resumeState: operationalState)
        }
        guard quote.temporalMetadata.marketSessionStatus == .continuous else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["market_not_in_continuous_session"], confidence: 0,
                              resumeState: operationalState)
        }

        guard let marketContext else {
            return assessment(plan: plan, quote: quote, marketContext: nil, state: .paused,
                              reasons: ["market_context_unavailable"], confidence: 0,
                              resumeState: operationalState)
        }
        // A market-level assessment without an explicit security identity is
        // not evidence that this plan's ETF is mapped to that market.
        guard marketContext.securityCode == quote.securityCode,
              marketContext.market == "security:\(quote.securityCode)" else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["market_context_security_mismatch"], confidence: 0,
                              resumeState: operationalState)
        }
        if marketContext.regime == .dataUnreliable {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["DATA_UNRELIABLE"], confidence: 0,
                              resumeState: operationalState)
        }
        let regimeMemoryEvaluatedAt = marketContext.memory.lastEvaluationAt
        guard let regimeDataAsOf = marketContext.dataAsOf,
              regimeDataAsOf.timeIntervalSince1970.isFinite,
              regimeMemoryEvaluatedAt.timeIntervalSince1970.isFinite,
              (0...100).contains(marketContext.confidence),
              regimeDataAsOf <= regimeMemoryEvaluatedAt,
              regimeMemoryEvaluatedAt <= now,
              regimeDataAsOf <= now,
              now.timeIntervalSince(regimeDataAsOf) <= 5 * 86_400,
              now.timeIntervalSince(regimeMemoryEvaluatedAt) <= 5 * 86_400 else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["market_context_stale_or_unverified"], confidence: 0,
                              resumeState: operationalState)
        }
        // A fresh quote must not be evaluated against regime evidence from a
        // later market observation. Wall-clock freshness alone does not prevent
        // this form of look-ahead when quotes arrive out of order.
        guard regimeDataAsOf <= quoteTimestamp else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["market_context_postdates_quote"], confidence: 0,
                              resumeState: operationalState)
        }
        guard regimeMemoryEvaluatedAt <= quoteTimestamp else {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["market_context_stale_or_unverified"], confidence: 0,
                              resumeState: operationalState)
        }
        if marketContext.riskLevel == .r4Extreme &&
            (plan.direction == .buy || plan.direction == .tBuy) {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: ["EXTREME_MARKET_RISK"], confidence: 0,
                              resumeState: operationalState)
        }
        if plan.direction == .tBuy && !marketContext.ordinaryTBuyAllowed {
            let reason = marketContext.regime == .bearTrend
                ? "BEAR_REGIME_T_BUY_RESTRICTED" : "MARKET_REGIME_T_BUY_RESTRICTED"
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .paused,
                              reasons: [reason], confidence: 0,
                              resumeState: operationalState)
        }

        if let previousQuoteTimestamp, quoteTimestamp <= previousQuoteTimestamp {
            return assessment(plan: plan, quote: quote, marketContext: marketContext,
                              state: storedState == .paused ? .paused : operationalState,
                              reasons: ["duplicate_or_out_of_order_quote_ignored"], confidence: 0,
                              resumeState: storedState == .paused ? operationalState : nil,
                              lastProcessedQuoteTimestamp: previousQuoteTimestamp)
        }

        if let invalidationPrice = plan.invalidationPrice,
           (plan.direction.approachesFromAbove ? quote.price <= invalidationPrice : quote.price >= invalidationPrice) {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .invalidated,
                              reasons: ["plan_invalidation_price_crossed"], confidence: 100)
        }

        if quote.price >= plan.lowerPrice && quote.price <= plan.upperPrice {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .triggered,
                              reasons: ["price_inside_plan_zone"], confidence: 100)
        }

        if plan.direction.approachesFromAbove {
            if quote.price > plan.upperPrice {
                let nearUpperBound = isWithinBuyApproach(quote.price, upperBound: plan.upperPrice,
                                                         distance: approachDistance)
                if operationalState == .triggered {
                    return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .leftZone,
                                      reasons: ["price_left_trigger_zone"], confidence: 100)
                }
                return assessment(plan: plan, quote: quote, marketContext: marketContext,
                                  state: nearUpperBound ? .approaching : .waiting,
                                  reasons: [nearUpperBound ? "approaching_buy_zone" : "waiting_above_buy_zone"],
                                  confidence: 100)
            }
            if operationalState == .approaching || operationalState == .triggered {
                return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .leftZone,
                                  reasons: ["price_crossed_below_buy_zone_without_observed_fill"], confidence: 100)
            }
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .waiting,
                              reasons: ["price_below_buy_zone"], confidence: 100)
        }

        if quote.price < plan.lowerPrice {
            let nearLowerBound = isWithinSellApproach(quote.price, lowerBound: plan.lowerPrice,
                                                       distance: approachDistance)
            if operationalState == .triggered {
                return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .leftZone,
                                  reasons: ["price_left_trigger_zone"], confidence: 100)
            }
            return assessment(plan: plan, quote: quote, marketContext: marketContext,
                              state: nearLowerBound ? .approaching : .waiting,
                              reasons: [nearLowerBound ? "approaching_sell_zone" : "waiting_below_sell_zone"],
                              confidence: 100)
        }
        if operationalState == .approaching || operationalState == .triggered {
            return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .leftZone,
                              reasons: ["price_crossed_above_sell_zone_without_observed_fill"], confidence: 100)
        }
        return assessment(plan: plan, quote: quote, marketContext: marketContext, state: .waiting,
                          reasons: ["price_above_sell_zone"], confidence: 100)
    }

    private static func isWithinBuyApproach(_ price: Decimal, upperBound: Decimal,
                                            distance: Decimal) -> Bool {
        guard let ratio = safeRatio(price, upperBound) else { return false }
        return ratio <= 1 + distance
    }

    private static func isWithinSellApproach(_ price: Decimal, lowerBound: Decimal,
                                             distance: Decimal) -> Bool {
        guard let ratio = safeRatio(price, lowerBound) else { return false }
        return ratio >= 1 - distance
    }

    private static func safeRatio(_ numerator: Decimal, _ denominator: Decimal) -> Decimal? {
        guard denominator > 0 else { return nil }
        var dividend = numerator
        var divisor = denominator
        var result = Decimal.zero
        let status = NSDecimalDivide(&result, &dividend, &divisor, .plain)
        guard (status == .noError || status == .lossOfPrecision), result.isFinite else { return nil }
        return result
    }

    private static func assessment(plan: FQuantTriggerPlan?, quote: FQuantQuoteSnapshot,
                                   marketContext: FMarketRegimeAssessment?,
                                   state: FRealtimeTriggerState, reasons: [String],
                                   confidence: Int,
                                   resumeState: FRealtimeTriggerState? = nil,
                                   lastProcessedQuoteTimestamp: Date? = nil) -> FQuantRealtimeAssessment {
        let signal: FQuantSignal
        let score: Int
        switch state {
        case .waiting, .paused:
            signal = .wait; score = 0
        case .approaching:
            switch plan?.direction {
            case .buy: signal = .approachingBuy
            case .sell: signal = .approachingSell
            case .tBuy: signal = .approachingBuy
            case .tSell: signal = .approachingSell
            case nil: signal = .wait
            }
            score = 60
        case .triggered:
            switch plan?.direction {
            case .buy: signal = .buyCandidate
            case .sell: signal = .sellCandidate
            case .tBuy: signal = .tBuyCandidate
            case .tSell: signal = .tSellCandidate
            case nil: signal = .wait
            }
            score = 100
        case .leftZone, .invalidated, .expired:
            signal = .invalidated; score = 0
        case .filled:
            signal = .filled; score = 0
        }
        return FQuantRealtimeAssessment(planID: plan?.id, securityCode: quote.securityCode,
            state: state, signal: signal, signalScore: score, confidence: confidence,
            reasonCodes: reasons, lowerPrice: plan?.lowerPrice, upperPrice: plan?.upperPrice,
            suggestedQuantity: state == .paused ? nil : plan?.suggestedQuantity,
            validUntil: plan?.validUntil,
            invalidationPrice: plan?.invalidationPrice,
            lastProcessedQuoteTimestamp: lastProcessedQuoteTimestamp,
            quoteTimestamp: quote.temporalMetadata.quoteTimestamp,
            marketRegime: marketContext?.regime, marketRiskLevel: marketContext?.riskLevel,
            resumeState: resumeState)
    }
}
