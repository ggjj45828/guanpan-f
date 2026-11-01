import Foundation
import FCore

/// A market-only outcome for an Advisor/Quant recommendation. It has no
/// simulated cash, units, or write capability for the real Ledger.
public enum FCandidateShadowStatus: String, Codable, Equatable, Sendable {
    case pending, triggered, opportunityObserved, notTriggered, leftZone, invalidationObserved, expired,
         observationWindowComplete, insufficientData
}

/// Provenance layers are stored separately so a future Quant/Advisor override
/// can be evaluated without rewriting the final advice snapshot.
public enum FCandidateShadowDecisionLayer: String, Codable, Equatable, Sendable {
    case quantOnly, deepSeekAdvisor, advisorOverride, finalAdvice
}

public struct FCandidateShadowLayerAction: Codable, Equatable, Sendable {
    public let layer: FCandidateShadowDecisionLayer
    public let action: FDecisionAction
    public let strategyID: String?
    public let strategyVersion: String?

    public init(layer: FCandidateShadowDecisionLayer, action: FDecisionAction,
                strategyID: String? = nil, strategyVersion: String? = nil) {
        self.layer = layer
        self.action = action
        self.strategyID = strategyID.map { String($0.prefix(128)) }
        self.strategyVersion = strategyVersion.map { String($0.prefix(64)) }
    }
}

public enum FCandidateShadowExecutionStatus: String, Codable, Equatable, Sendable {
    case unexecuted, partiallyExecuted, fullyExecuted, executionUnknown
}

public enum FCandidateShadowDataQuality: String, Codable, Equatable, Sendable {
    case freshVerified, staleObserved, insufficient
}

private enum FCandidateShadowDecimalMath {
    static func adding(_ lhs: Decimal, _ rhs: Decimal) -> Decimal? {
        var left = lhs
        var right = rhs
        var result = Decimal.zero
        guard NSDecimalAdd(&result, &left, &right, .plain) == .noError,
              NSDecimalNumber(decimal: result).doubleValue.isFinite else { return nil }
        return result
    }

    static func subtracting(_ lhs: Decimal, _ rhs: Decimal) -> Decimal? {
        var left = lhs
        var right = rhs
        var result = Decimal.zero
        guard NSDecimalSubtract(&result, &left, &right, .plain) == .noError,
              NSDecimalNumber(decimal: result).doubleValue.isFinite else { return nil }
        return result
    }

    static func relativeChange(from base: Decimal, to value: Decimal) -> Decimal? {
        guard base > 0 else { return nil }
        var minuend = value
        var subtrahend = base
        var difference = Decimal.zero
        guard NSDecimalSubtract(&difference, &minuend, &subtrahend, .plain) == .noError else {
            return nil
        }
        var numerator = difference
        var denominator = base
        var result = Decimal.zero
        let status = NSDecimalDivide(&result, &numerator, &denominator, .plain)
        guard (status == .noError || status == .lossOfPrecision),
              NSDecimalNumber(decimal: result).doubleValue.isFinite else { return nil }
        return result
    }
}

private enum FCandidateShadowSnapshotRules {
    static func invalidationIsValid(_ invalidationPrice: Decimal?, action: FDecisionAction,
                                   targetPrice: Decimal?, targetPriceZone: FShadowPriceZone?) -> Bool {
        guard let invalidationPrice else { return true }
        guard invalidationPrice > 0,
              NSDecimalNumber(decimal: invalidationPrice).doubleValue.isFinite else { return false }
        switch action {
        case .buy, .dayTrade:
            guard let lowerBound = targetPriceZone?.lower ?? targetPrice else { return false }
            return invalidationPrice < lowerBound
        case .sell:
            guard let upperBound = targetPriceZone?.upper ?? targetPrice else { return false }
            return invalidationPrice > upperBound
        case .wait, .hold, .grid, .recoveryPlan:
            return false
        }
    }
}

public struct FShadowPriceZone: Codable, Equatable, Sendable {
    public let lower: Decimal
    public let upper: Decimal

    public init(lower: Decimal, upper: Decimal) throws {
        guard lower > 0, upper >= lower,
              NSDecimalNumber(decimal: lower).doubleValue.isFinite,
              NSDecimalNumber(decimal: upper).doubleValue.isFinite else {
            throw FCandidateShadowError.invalidSnapshot
        }
        self.lower = lower
        self.upper = upper
    }
}

/// Frozen decision-time facts. The initializer only accepts explicit structured
/// conditions; later market observations are separate append-only events.
public struct FCandidateShadowSnapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let candidateID: UUID
    public let createdAt: Date
    public let securityCode: String?
    public let planType: FDecisionAction
    public let finalAction: FDecisionAction
    public let guardAllowed: Bool
    public let referencePrice: Decimal?
    public let referenceQuoteTimestamp: Date?
    public let targetPrice: Decimal?
    public let targetPriceZone: FShadowPriceZone?
    public let invalidationPrice: Decimal?
    public let suggestedQuantity: Int64?
    public let validUntil: Date?
    public let invalidationConditions: [String]
    public let quantState: String?
    public let decisionLayers: [FCandidateShadowLayerAction]
    public let marketRegime: String?
    public let maxChaseDistance: Decimal?
    public let maxQuoteAgeSeconds: Int
    public let advisorConclusion: String
    public let reasonCodes: [String]
    /// Nil only for legacy archives created before account identity was frozen.
    public let ledgerAccountID: UUID?
    /// Preserve the provider's value and meaning; nil means not supplied.
    public let confidence: Decimal?
    public let accountDigest: String

    public init(candidate: FCandidateRecommendation, context: FDecisionContext,
                advisorConclusion: String, invalidationConditions: [String] = [],
                reasonCodes: [String] = [], quantState: String? = nil,
                confidence: Decimal? = nil, targetPriceZone: FShadowPriceZone? = nil,
                invalidationPrice: Decimal? = nil, validUntil: Date? = nil,
                decisionLayers: [FCandidateShadowLayerAction]? = nil,
                marketRegime: String? = nil, maxChaseDistance: Decimal? = nil,
                finalAction: FDecisionAction? = nil, guardAllowed: Bool = false,
                maxQuoteAgeSeconds: Int(FQuoteTemporalMetadata.defaultMaximumAge)) throws {
        guard candidate.accountDigest == context.accountDigest,
              context.createdAt.timeIntervalSince1970.isFinite,
              candidate.units.map({ $0 > 0 }) ?? true,
              candidate.limitPrice.map({ $0 > 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }) ?? true,
              targetPriceZone.map({ $0.lower > 0 && $0.upper >= $0.lower &&
                  NSDecimalNumber(decimal: $0.lower).doubleValue.isFinite &&
                  NSDecimalNumber(decimal: $0.upper).doubleValue.isFinite }) ?? true,
              confidence.map({ $0.isFinite && $0 >= 0 && $0 <= 1 }) ?? true,
              validUntil.map({ $0.timeIntervalSince1970.isFinite && $0 >= context.createdAt }) ?? true,
              maxChaseDistance.map({ $0 >= 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }) ?? true,
              (1...3_600).contains(maxQuoteAgeSeconds) else {
            throw FCandidateShadowError.invalidSnapshot
        }
        if let code = candidate.instrumentCode {
            guard code.count == 6, code.utf8.count == 6,
                  code.utf8.allSatisfy({ (48...57).contains($0) }) else {
                throw FCandidateShadowError.invalidSnapshot
            }
        }
        let quote = candidate.instrumentCode.flatMap { code in
            context.observations
                .filter {
                    $0.dataClass == .quote && $0.subject == code && $0.decimalValue != nil &&
                    $0.isFresh(at: context.createdAt) &&
                    $0.quoteTemporalMetadata?.timestampTrust == .verifiedExchangeTimestamp
                }
                .max { ($0.observedAt ?? .distantPast) < ($1.observedAt ?? .distantPast) }
        }
        id = UUID()
        candidateID = candidate.id
        createdAt = context.createdAt
        securityCode = candidate.instrumentCode
        planType = candidate.action
        self.finalAction = finalAction ?? candidate.action
        self.guardAllowed = guardAllowed
        referencePrice = quote?.decimalValue
        referenceQuoteTimestamp = quote?.quoteTemporalMetadata?.quoteTimestamp ?? quote?.observedAt
        targetPrice = candidate.limitPrice
        guard FCandidateShadowSnapshotRules.invalidationIsValid(
            invalidationPrice, action: candidate.action,
            targetPrice: candidate.limitPrice, targetPriceZone: targetPriceZone) else {
            throw FCandidateShadowError.invalidSnapshot
        }
        self.targetPriceZone = targetPriceZone
        self.invalidationPrice = invalidationPrice
        suggestedQuantity = candidate.units
        self.validUntil = validUntil
        self.invalidationConditions = invalidationConditions.map { String($0.prefix(512)) }
        self.quantState = quantState.map { String($0.prefix(128)) }
        self.decisionLayers = decisionLayers ?? [
            FCandidateShadowLayerAction(layer: .deepSeekAdvisor, action: candidate.action),
            FCandidateShadowLayerAction(layer: .finalAdvice, action: finalAction ?? candidate.action)
        ]
        self.marketRegime = marketRegime.map { String($0.prefix(128)) }
        self.maxChaseDistance = maxChaseDistance
        self.maxQuoteAgeSeconds = maxQuoteAgeSeconds
        self.advisorConclusion = String(advisorConclusion.prefix(2_000))
        self.reasonCodes = Array(reasonCodes.prefix(32)).map { String($0.prefix(128)) }
        self.confidence = confidence
        accountDigest = candidate.accountDigest
        ledgerAccountID = context.accountID
    }

    fileprivate func isTriggerPrice(_ price: Decimal) -> Bool {
        if let targetPriceZone {
            return price >= targetPriceZone.lower && price <= targetPriceZone.upper
        }
        guard let targetPrice else { return false }
        switch planType {
        case .buy: return price <= targetPrice
        case .sell: return price >= targetPrice
        case .wait, .hold, .dayTrade, .grid, .recoveryPlan: return false
        }
    }

    fileprivate var hasTriggerCondition: Bool {
        if targetPriceZone != nil { return true }
        guard targetPrice != nil else { return false }
        return planType == .buy || planType == .sell
    }
}

public struct FCandidateShadowMarketObservation: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let securityCode: String
    public let price: Decimal
    public let quoteTimestamp: Date
    public let capturedAt: Date
    public let source: String
    public let timestampTrust: FQuoteTimeTrust
    public let sessionStatus: FMarketSessionStatus
    public let isFresh: Bool

    fileprivate func isVerifiedFresh(maximumAge: TimeInterval) -> Bool {
        guard maximumAge.isFinite, maximumAge >= 0,
              timestampTrust == .verifiedExchangeTimestamp,
              FMarketQuoteTrustPolicy.isTrusted(source),
              price > 0, NSDecimalNumber(decimal: price).doubleValue.isFinite,
              quoteTimestamp.timeIntervalSince1970.isFinite,
              capturedAt.timeIntervalSince1970.isFinite,
              quoteTimestamp <= capturedAt else { return false }
        return capturedAt.timeIntervalSince(quoteTimestamp) <= maximumAge
    }

    public init(id: UUID = UUID(), securityCode: String, price: Decimal,
                quoteTimestamp: Date, capturedAt: Date, source: String,
                timestampTrust: FQuoteTimeTrust, sessionStatus: FMarketSessionStatus) throws {
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              price > 0, NSDecimalNumber(decimal: price).doubleValue.isFinite,
              quoteTimestamp.timeIntervalSince1970.isFinite,
              capturedAt.timeIntervalSince1970.isFinite,
              quoteTimestamp <= capturedAt,
              FMarketQuoteTrustPolicy.isTrusted(source),
              timestampTrust == .verifiedExchangeTimestamp else {
            throw FCandidateShadowError.invalidMarketObservation
        }
        self.id = id
        self.securityCode = securityCode
        self.price = price
        self.quoteTimestamp = quoteTimestamp
        self.capturedAt = capturedAt
        self.source = source
        self.timestampTrust = timestampTrust
        self.sessionStatus = sessionStatus
        isFresh = FQuoteTemporalMetadata(
            quoteTimestamp: quoteTimestamp, fetchedAt: capturedAt, source: source,
            timestampTrust: timestampTrust, marketSessionStatus: sessionStatus
        ).freshness(at: capturedAt) == .fresh
    }
}

public struct FCandidateShadowFillLink: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let confirmedFillID: UUID
    public let linkedAt: Date
    public let units: Int64

    public init(id: UUID = UUID(), confirmedFillID: UUID, linkedAt: Date, units: Int64) throws {
        guard units > 0, linkedAt.timeIntervalSince1970.isFinite else {
            throw FCandidateShadowError.invalidExecutionLink
        }
        self.id = id
        self.confirmedFillID = confirmedFillID
        self.linkedAt = linkedAt
        self.units = units
    }
}

/// An explicit, auditable negative execution confirmation. Lack of a linked fill
/// alone is never treated as proof that the user did not trade.
public struct FCandidateShadowExecutionReview: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let reviewedAt: Date
    public let note: String

    public init(id: UUID = UUID(), reviewedAt: Date, note: String) throws {
        guard reviewedAt.timeIntervalSince1970.isFinite,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FCandidateShadowError.invalidExecutionReview
        }
        self.id = id
        self.reviewedAt = reviewedAt
        self.note = String(note.prefix(512))
    }
}

public enum FCandidateShadowEvent: Codable, Equatable, Sendable {
    case market(FCandidateShadowMarketObservation)
    case confirmedExecution(FCandidateShadowFillLink)
    case executionReview(FCandidateShadowExecutionReview)
}

public struct FCandidateShadowRecord: Codable, Equatable, Sendable, Identifiable {
    public let snapshot: FCandidateShadowSnapshot
    public private(set) var events: [FCandidateShadowEvent]
    public var id: UUID { snapshot.id }

    public init(snapshot: FCandidateShadowSnapshot) {
        self.snapshot = snapshot
        events = []
    }

    public mutating func appendMarketObservation(_ observation: FCandidateShadowMarketObservation) throws {
        guard let code = snapshot.securityCode, observation.securityCode == code,
              observation.quoteTimestamp >= snapshot.createdAt,
              events.contains(where: {
                  if case let .market(existing) = $0 {
                      return existing.quoteTimestamp == observation.quoteTimestamp
                  }
                  return false
              }) == false else { throw FCandidateShadowError.invalidMarketObservation }
        events.append(.market(observation))
    }

    public mutating func appendConfirmedExecution(_ link: FCandidateShadowFillLink,
                                                   ledgerSnapshot: FReadOnlyLedgerSnapshot) throws {
        let confirmedFill = ledgerSnapshot.confirmedFills.first { $0.id == link.confirmedFillID }
        guard snapshot.planType == .buy || snapshot.planType == .sell || snapshot.planType == .dayTrade,
              let ledgerAccountID = snapshot.ledgerAccountID,
              ledgerAccountID == ledgerSnapshot.accountID,
              link.linkedAt >= snapshot.createdAt,
              let confirmedFill,
              confirmedFill.tradedAt <= ledgerSnapshot.capturedAt,
              confirmedFill.tradedAt == link.linkedAt,
              confirmedFill.instrumentCode == snapshot.securityCode,
              link.units == confirmedFill.units,
              (snapshot.planType == .dayTrade ||
               (snapshot.planType == .buy && confirmedFill.side == .buy) ||
               (snapshot.planType == .sell && confirmedFill.side == .sell)),
              !events.contains(where: {
                  if case .executionReview = $0 { return true }
                  return false
              }),
              !events.contains(where: {
                  if case let .confirmedExecution(existing) = $0 {
                      return existing.confirmedFillID == link.confirmedFillID
                  }
                  return false
              }) else { throw FCandidateShadowError.invalidExecutionLink }
        events.append(.confirmedExecution(link))
    }

    public mutating func appendExecutionReview(_ review: FCandidateShadowExecutionReview) throws {
        guard review.reviewedAt >= snapshot.createdAt,
              !events.contains(where: {
                  if case .executionReview = $0 { return true }
                  if case .confirmedExecution = $0 { return true }
                  return false
              }) else { throw FCandidateShadowError.invalidExecutionReview }
        events.append(.executionReview(review))
    }

    fileprivate var marketObservationEnd: Date {
        let trigger = events.compactMap { event -> FCandidateShadowMarketObservation? in
            guard case let .market(value) = event,
                  value.isVerifiedFresh(maximumAge: Double(snapshot.maxQuoteAgeSeconds)),
                  value.quoteTimestamp <= (snapshot.validUntil ?? .distantFuture),
                  snapshot.isTriggerPrice(value.price) else { return nil }
            return value
        }.min { $0.quoteTimestamp < $1.quoteTimestamp }
        if let trigger { return trigger.quoteTimestamp.addingTimeInterval(3_600) }
        return snapshot.validUntil ?? snapshot.createdAt.addingTimeInterval(3_600)
    }

    public func evaluation(asOf: Date) -> FCandidateShadowEvaluation {
        let observedMarket = events.compactMap { event -> FCandidateShadowMarketObservation? in
            guard case let .market(value) = event else { return nil }
            return value
        }.filter { $0.quoteTimestamp <= asOf && $0.capturedAt <= asOf }
            .sorted { $0.quoteTimestamp < $1.quoteTimestamp }
        let marketBeforeExpiry = observedMarket.filter {
            $0.isVerifiedFresh(maximumAge: Double(snapshot.maxQuoteAgeSeconds)) &&
            $0.quoteTimestamp <= (snapshot.validUntil ?? .distantFuture)
        }
        let trigger = marketBeforeExpiry.first(where: { snapshot.isTriggerPrice($0.price) })
        let collectionEnd = trigger?.quoteTimestamp.addingTimeInterval(3_600) ??
            (snapshot.validUntil ?? snapshot.createdAt.addingTimeInterval(3_600))
        let allMarket = observedMarket.filter { $0.quoteTimestamp <= collectionEnd }
        let market = allMarket.filter {
            $0.isVerifiedFresh(maximumAge: Double(snapshot.maxQuoteAgeSeconds))
        }
        let outcomeStart = trigger?.quoteTimestamp ?? snapshot.createdAt
        let outcomeCoverageComplete = Self.hasContinuousCoverage(
            market.filter { $0.quoteTimestamp >= outcomeStart },
            from: outcomeStart, through: collectionEnd,
            maximumGap: Double(snapshot.maxQuoteAgeSeconds))
        let executionLinks = events.compactMap { event -> FCandidateShadowFillLink? in
            guard case let .confirmedExecution(value) = event else { return nil }
            return value
        }.filter { $0.linkedAt <= asOf }
        let executedUnits = executionLinks.reduce(Int64(0)) { partial, item in
            let (sum, overflow) = partial.addingReportingOverflow(item.units)
            return overflow ? Int64.max : sum
        }
        let execution: FCandidateShadowExecutionStatus
        if events.contains(where: {
            if case let .executionReview(review) = $0 { return review.reviewedAt <= asOf }
            return false
        }) {
            execution = .unexecuted
        } else if executionLinks.isEmpty {
            execution = .executionUnknown
        } else if let planned = snapshot.suggestedQuantity, executedUnits >= planned {
            execution = .fullyExecuted
        } else {
            execution = .partiallyExecuted
        }

        let invalidated = snapshot.invalidationPrice.flatMap { invalidation in
            // A trigger starts a one-hour outcome window even if the original
            // plan expires sooner. Keep monitoring its frozen invalidation
            // level throughout that window.
            market.first(where: { item in
                switch snapshot.planType {
                case .buy, .dayTrade: return item.price <= invalidation
                case .sell: return item.price >= invalidation
                case .wait, .hold, .grid, .recoveryPlan: return false
                }
            })
        }
        let status: FCandidateShadowStatus
        if snapshot.securityCode == nil || snapshot.referencePrice == nil {
            status = .insufficientData
        } else if snapshot.planType == .wait && snapshot.targetPriceZone == nil {
            status = .insufficientData
        } else if invalidated != nil {
            status = .invalidationObserved
        } else if market.isEmpty {
            status = .insufficientData
        } else if let validUntil = snapshot.validUntil, asOf >= validUntil {
            status = .expired
        } else if asOf >= collectionEnd {
            status = outcomeCoverageComplete ? .observationWindowComplete : .insufficientData
        } else if let maxChase = snapshot.maxChaseDistance,
                  let trigger, let last = market.last,
                  last.quoteTimestamp >= trigger.quoteTimestamp,
                  hasLeftZone(lastPrice: last.price, maxChase: maxChase) {
            status = .leftZone
        } else if trigger != nil {
            status = snapshot.planType == .wait ? .opportunityObserved : .triggered
        } else {
            status = .pending
        }

        let directional: Bool? = switch snapshot.planType {
        case .buy: true
        case .sell: false
        case .dayTrade, .wait, .hold, .grid, .recoveryPlan: nil
        }
        let outcomeAnchor = trigger?.quoteTimestamp ?? snapshot.createdAt
        let outcomeReference = trigger?.price ?? snapshot.referencePrice
        let returnAt: (TimeInterval) -> Decimal? = { horizon in
            guard trigger != nil, let outcomeReference, let directional else { return nil }
            let target = outcomeAnchor.addingTimeInterval(horizon)
            guard let item = market.filter({ $0.quoteTimestamp >= target })
                .min(by: { $0.quoteTimestamp < $1.quoteTimestamp }),
                  abs(item.quoteTimestamp.timeIntervalSince(target)) <= 120 else { return nil }
            guard let raw = FCandidateShadowDecimalMath.relativeChange(
                from: outcomeReference, to: item.price) else { return nil }
            return directional ? raw : -raw
        }
        let directionalMoves = trigger.flatMap { _ in outcomeReference }.flatMap { base in
            directional.map { favorableDirection in
                market.filter { $0.quoteTimestamp >= outcomeAnchor }.compactMap {
                    guard let change = FCandidateShadowDecimalMath.relativeChange(
                        from: base, to: $0.price) else { return nil }
                    return change * (favorableDirection ? Decimal(1) : Decimal(-1))
                }
            }
        } ?? []
        return FCandidateShadowEvaluation(status: status, executionStatus: execution,
            evaluatedLayer: .deepSeekAdvisor,
            dataQuality: market.isEmpty ? (allMarket.isEmpty ? .insufficient : .staleObserved) : .freshVerified,
            observationWindowComplete: asOf >= collectionEnd && outcomeCoverageComplete,
            notTriggered: snapshot.hasTriggerCondition && trigger == nil && outcomeCoverageComplete &&
                asOf >= (snapshot.validUntil ?? snapshot.createdAt.addingTimeInterval(3_600)),
            freshObservationCount: market.count, staleObservationCount: allMarket.count - market.count,
            triggeredAt: trigger?.quoteTimestamp, triggerPrice: trigger?.price,
            returnAfter5Minutes: returnAt(300), returnAfter15Minutes: returnAt(900),
            returnAfter30Minutes: returnAt(1_800), returnAfter60Minutes: returnAt(3_600),
            maximumFavorableExcursion: outcomeCoverageComplete ? directionalMoves.max() : nil,
            maximumAdverseExcursion: outcomeCoverageComplete ? directionalMoves.min() : nil,
            confirmedFillIDs: executionLinks.map(\.confirmedFillID))
    }

    private static func hasContinuousCoverage(_ observations: [FCandidateShadowMarketObservation],
                                              from start: Date, through end: Date,
                                              maximumGap: TimeInterval) -> Bool {
        guard end > start, maximumGap.isFinite, maximumGap > 0,
              let first = observations.first, let last = observations.last,
              first.quoteTimestamp.timeIntervalSince(start) <= maximumGap,
              end.timeIntervalSince(last.quoteTimestamp) <= maximumGap else { return false }
        var previous = first.quoteTimestamp
        for observation in observations.dropFirst() {
            let gap = observation.quoteTimestamp.timeIntervalSince(previous)
            guard gap >= 0, gap <= maximumGap else { return false }
            previous = observation.quoteTimestamp
        }
        return true
    }

    private func hasLeftZone(lastPrice: Decimal, maxChase: Decimal) -> Bool {
        switch snapshot.planType {
        case .buy:
            let upperBound = snapshot.targetPriceZone?.upper ?? snapshot.targetPrice ?? lastPrice
            guard let chaseCeiling = FCandidateShadowDecimalMath.adding(upperBound, maxChase) else {
                return false
            }
            return lastPrice > chaseCeiling
        case .sell:
            let lowerBound = snapshot.targetPriceZone?.lower ?? snapshot.targetPrice ?? lastPrice
            guard let chaseFloor = FCandidateShadowDecimalMath.subtracting(lowerBound, maxChase) else {
                return false
            }
            return lastPrice < chaseFloor
        case .dayTrade, .wait, .hold, .grid, .recoveryPlan:
            return false
        }
    }
}

public struct FCandidateShadowEvaluation: Codable, Equatable, Sendable {
    public let status: FCandidateShadowStatus
    public let executionStatus: FCandidateShadowExecutionStatus
    /// This first implementation evaluates the raw Advisor action only.
    /// Quant-only and post-Guard final-action scoring remain separate work.
    public let evaluatedLayer: FCandidateShadowDecisionLayer
    public let dataQuality: FCandidateShadowDataQuality
    /// Outcome-window completion is separate from the lifecycle state: a plan can
    /// be expired while its post-trigger market observation window is still open.
    public let observationWindowComplete: Bool
    public let notTriggered: Bool
    public let freshObservationCount: Int
    public let staleObservationCount: Int
    public let triggeredAt: Date?
    public let triggerPrice: Decimal?
    /// Direction-adjusted return fractions from the decision-time reference price.
    public let returnAfter5Minutes: Decimal?
    public let returnAfter15Minutes: Decimal?
    public let returnAfter30Minutes: Decimal?
    public let returnAfter60Minutes: Decimal?
    public let maximumFavorableExcursion: Decimal?
    public let maximumAdverseExcursion: Decimal?
    public let confirmedFillIDs: [UUID]
}

public struct FCandidateShadowArchive: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public private(set) var records: [FCandidateShadowRecord]

    public init(records: [FCandidateShadowRecord] = [], schemaVersion: Int = 1) {
        self.records = records
        self.schemaVersion = schemaVersion
    }

    public mutating func append(_ snapshot: FCandidateShadowSnapshot) throws {
        guard !records.contains(where: { $0.snapshot.candidateID == snapshot.candidateID }) else {
            throw FCandidateShadowError.duplicateCandidate
        }
        records.append(FCandidateShadowRecord(snapshot: snapshot))
    }

    public mutating func appendMarketObservation(_ observation: FCandidateShadowMarketObservation) throws {
        for index in records.indices where records[index].snapshot.securityCode == observation.securityCode &&
            observation.quoteTimestamp >= records[index].snapshot.createdAt &&
            observation.quoteTimestamp <= records[index].marketObservationEnd &&
            !records[index].events.contains(where: {
                if case let .market(existing) = $0 { return existing.quoteTimestamp == observation.quoteTimestamp }
                return false
            }) {
            try records[index].appendMarketObservation(observation)
        }
    }

    public mutating func appendConfirmedExecution(candidateID: UUID,
                                                   link: FCandidateShadowFillLink,
                                                   ledgerSnapshot: FReadOnlyLedgerSnapshot) throws {
        guard let index = records.firstIndex(where: { $0.snapshot.candidateID == candidateID }) else {
            throw FCandidateShadowError.candidateNotFound
        }
        guard !records.indices.contains(where: { otherIndex in
            otherIndex != index && records[otherIndex].events.contains(where: {
                if case let .confirmedExecution(existing) = $0 {
                    return existing.confirmedFillID == link.confirmedFillID
                }
                return false
            })
        }) else { throw FCandidateShadowError.invalidExecutionLink }
        try records[index].appendConfirmedExecution(link, ledgerSnapshot: ledgerSnapshot)
    }

    public mutating func appendExecutionReview(candidateID: UUID,
                                               review: FCandidateShadowExecutionReview) throws {
        guard let index = records.firstIndex(where: { $0.snapshot.candidateID == candidateID }) else {
            throw FCandidateShadowError.candidateNotFound
        }
        try records[index].appendExecutionReview(review)
    }

    public func validate() throws {
        guard schemaVersion == 1, Set(records.map(\.snapshot.candidateID)).count == records.count else {
            throw FCandidateShadowError.invalidArchive
        }
        var fillIDs = Set<UUID>()
        for record in records {
            let snapshot = record.snapshot
            guard snapshot.createdAt.timeIntervalSince1970.isFinite,
                  !snapshot.accountDigest.isEmpty,
                  snapshot.referencePrice.map({ $0 > 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }) ?? true,
                  snapshot.referenceQuoteTimestamp.map({
                      $0.timeIntervalSince1970.isFinite && $0 <= snapshot.createdAt
                  }) ?? true,
                  (snapshot.referencePrice == nil) == (snapshot.referenceQuoteTimestamp == nil),
                  snapshot.confidence.map({ $0.isFinite && $0 >= 0 && $0 <= 1 }) ?? true,
                  snapshot.validUntil.map({ $0.timeIntervalSince1970.isFinite && $0 >= snapshot.createdAt }) ?? true,
                  snapshot.targetPrice.map({ $0 > 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }) ?? true,
                  snapshot.targetPriceZone.map({
                      $0.lower > 0 && $0.upper >= $0.lower &&
                      NSDecimalNumber(decimal: $0.lower).doubleValue.isFinite &&
                      NSDecimalNumber(decimal: $0.upper).doubleValue.isFinite
                  }) ?? true,
                  FCandidateShadowSnapshotRules.invalidationIsValid(
                      snapshot.invalidationPrice, action: snapshot.planType,
                      targetPrice: snapshot.targetPrice, targetPriceZone: snapshot.targetPriceZone),
                  snapshot.suggestedQuantity.map({ $0 > 0 }) ?? true,
                  snapshot.maxChaseDistance.map({ $0 >= 0 && NSDecimalNumber(decimal: $0).doubleValue.isFinite }) ?? true,
                  (1...3_600).contains(snapshot.maxQuoteAgeSeconds),
                  snapshot.securityCode.map({
                      $0.count == 6 && $0.utf8.count == 6 && $0.utf8.allSatisfy({ (48...57).contains($0) })
                  }) ?? true else { throw FCandidateShadowError.invalidArchive }
            var marketTimes = Set<Date>()
            var hasExecution = false
            var hasExecutionReview = false
            for event in record.events {
                switch event {
                case let .market(observation):
                    guard observation.securityCode == snapshot.securityCode,
                          observation.quoteTimestamp.timeIntervalSince1970.isFinite,
                          observation.capturedAt.timeIntervalSince1970.isFinite,
                          observation.quoteTimestamp >= snapshot.createdAt,
                          observation.quoteTimestamp <= observation.capturedAt,
                          observation.timestampTrust == .verifiedExchangeTimestamp,
                          observation.price > 0,
                          NSDecimalNumber(decimal: observation.price).doubleValue.isFinite,
                          FMarketQuoteTrustPolicy.isTrusted(observation.source),
                          observation.isFresh == (FQuoteTemporalMetadata(
                              quoteTimestamp: observation.quoteTimestamp,
                              fetchedAt: observation.capturedAt,
                              source: observation.source,
                              timestampTrust: observation.timestampTrust,
                              marketSessionStatus: observation.sessionStatus
                          ).freshness(at: observation.capturedAt) == .fresh),
                          marketTimes.insert(observation.quoteTimestamp).inserted else {
                        throw FCandidateShadowError.invalidArchive
                    }
                case let .confirmedExecution(link):
                    guard snapshot.planType == .buy || snapshot.planType == .sell || snapshot.planType == .dayTrade,
                          link.units > 0, link.linkedAt.timeIntervalSince1970.isFinite,
                          link.linkedAt >= snapshot.createdAt,
                          fillIDs.insert(link.confirmedFillID).inserted,
                          !hasExecutionReview else { throw FCandidateShadowError.invalidArchive }
                    hasExecution = true
                case let .executionReview(review):
                    guard review.reviewedAt.timeIntervalSince1970.isFinite,
                          review.reviewedAt >= snapshot.createdAt, !hasExecution,
                          !hasExecutionReview,
                          !review.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw FCandidateShadowError.invalidArchive
                    }
                    hasExecutionReview = true
                }
            }
        }
    }

    public func scorecard(since: Date, asOf: Date) -> FCandidateShadowSummary {
        let recent = records.filter { $0.snapshot.createdAt >= since && $0.snapshot.createdAt <= asOf }
        let evaluations = recent.map { ($0, $0.evaluation(asOf: asOf)) }
        let bySecurity = Dictionary(grouping: evaluations, by: { $0.0.snapshot.securityCode ?? "组合" })
        let perSecurity = bySecurity.mapValues { items in
            FCandidateShadowInstrumentSummary(
                candidateCount: items.count,
                waitCount: items.filter { $0.0.snapshot.planType == .wait }.count,
                triggeredCount: items.filter { $0.1.triggeredAt != nil && $0.0.snapshot.planType != .wait }.count,
                opportunityObservedCount: items.filter { $0.1.triggeredAt != nil && $0.0.snapshot.planType == .wait }.count,
                notTriggeredCount: items.filter { $0.1.notTriggered }.count,
                invalidatedCount: items.filter { $0.1.status == .invalidationObserved }.count,
                expiredCount: items.filter { $0.1.status == .expired }.count,
                observationWindowCompleteCount: items.filter { $0.1.observationWindowComplete }.count,
                insufficientDataCount: items.filter { $0.1.status == .insufficientData }.count,
                executedCount: items.filter {
                    $0.1.executionStatus == .fullyExecuted || $0.1.executionStatus == .partiallyExecuted
                }.count,
                unexecutedCount: items.filter { $0.1.executionStatus == .unexecuted }.count,
                executionUnknownCount: items.filter { $0.1.executionStatus == .executionUnknown }.count,
                evaluableDirectionalCount: items.filter { $0.1.returnAfter60Minutes != nil }.count,
                favorableDirectionalCount: items.filter { ($0.1.returnAfter60Minutes ?? 0) > 0 }.count)
        }
        return FCandidateShadowSummary(candidateCount: recent.count,
            waitCount: recent.filter { $0.snapshot.planType == .wait }.count,
            triggeredCount: evaluations.filter { $0.1.triggeredAt != nil && $0.0.snapshot.planType != .wait }.count,
            opportunityObservedCount: evaluations.filter { $0.1.triggeredAt != nil && $0.0.snapshot.planType == .wait }.count,
            notTriggeredCount: evaluations.filter { $0.1.notTriggered }.count,
            invalidatedCount: evaluations.filter { $0.1.status == .invalidationObserved }.count,
            expiredCount: evaluations.filter { $0.1.status == .expired }.count,
            observationWindowCompleteCount: evaluations.filter { $0.1.observationWindowComplete }.count,
            insufficientDataCount: evaluations.filter { $0.1.status == .insufficientData }.count,
            executedCount: evaluations.filter {
                $0.1.executionStatus == .fullyExecuted || $0.1.executionStatus == .partiallyExecuted
            }.count,
            unexecutedCount: evaluations.filter { $0.1.executionStatus == .unexecuted }.count,
            executionUnknownCount: evaluations.filter { $0.1.executionStatus == .executionUnknown }.count,
            evaluableDirectionalCount: evaluations.filter { $0.1.returnAfter60Minutes != nil }.count,
            favorableDirectionalCount: evaluations.filter { ($0.1.returnAfter60Minutes ?? 0) > 0 }.count,
            bySecurity: perSecurity)
    }
}

/// Descriptive counts only. Favorable-direction counts are not a win rate and
/// are intentionally accompanied by the number of evaluable samples.
public struct FCandidateShadowInstrumentSummary: Codable, Equatable, Sendable {
    public let candidateCount: Int
    public let waitCount: Int
    public let triggeredCount: Int
    public let opportunityObservedCount: Int
    public let notTriggeredCount: Int
    public let invalidatedCount: Int
    public let expiredCount: Int
    public let observationWindowCompleteCount: Int
    public let insufficientDataCount: Int
    public let executedCount: Int
    public let unexecutedCount: Int
    public let executionUnknownCount: Int
    public let evaluableDirectionalCount: Int
    public let favorableDirectionalCount: Int
}

public struct FCandidateShadowSummary: Codable, Equatable, Sendable {
    public let candidateCount: Int
    public let waitCount: Int
    public let triggeredCount: Int
    public let opportunityObservedCount: Int
    public let notTriggeredCount: Int
    public let invalidatedCount: Int
    public let expiredCount: Int
    public let observationWindowCompleteCount: Int
    public let insufficientDataCount: Int
    public let executedCount: Int
    public let unexecutedCount: Int
    public let executionUnknownCount: Int
    public let evaluableDirectionalCount: Int
    public let favorableDirectionalCount: Int
    public let bySecurity: [String: FCandidateShadowInstrumentSummary]
}

/// Local append-only market-only shadow history. It stores immutable decision
/// snapshots and later real quotes/fill IDs; it is intentionally not a Ledger.
public actor FCandidateShadowJournalStore {
    private let fileURL: URL
    private var archive = FCandidateShadowArchive()
    private var loaded = false

    public init(directory: URL) {
        fileURL = directory.standardizedFileURL.appendingPathComponent("candidate-shadow-v1.json")
    }

    public func load() throws -> FCandidateShadowArchive {
        try ensureLoaded()
        return archive
    }

    public func append(_ snapshot: FCandidateShadowSnapshot) throws {
        try ensureLoaded()
        var next = archive
        try next.append(snapshot)
        try save(next)
    }

    public func appendMarketObservation(_ observation: FCandidateShadowMarketObservation) throws {
        try ensureLoaded()
        var next = archive
        try next.appendMarketObservation(observation)
        try save(next)
    }

    public func appendConfirmedExecution(candidateID: UUID,
                                         link: FCandidateShadowFillLink,
                                         ledgerSnapshot: FReadOnlyLedgerSnapshot) throws {
        try ensureLoaded()
        var next = archive
        try next.appendConfirmedExecution(candidateID: candidateID, link: link,
                                           ledgerSnapshot: ledgerSnapshot)
        try save(next)
    }

    public func appendExecutionReview(candidateID: UUID,
                                      review: FCandidateShadowExecutionReview) throws {
        try ensureLoaded()
        var next = archive
        try next.appendExecutionReview(candidateID: candidateID, review: review)
        try save(next)
    }

    private func ensureLoaded() throws {
        guard !loaded else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            archive = try JSONDecoder().decode(FCandidateShadowArchive.self, from: Data(contentsOf: fileURL))
            try archive.validate()
        }
        loaded = true
    }

    private func save(_ next: FCandidateShadowArchive) throws {
        try next.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try encoder.encode(next).write(to: fileURL, options: .atomic)
        archive = next
    }
}

public enum FCandidateShadowError: Error, Equatable, Sendable {
    case invalidSnapshot
    case invalidMarketObservation
    case invalidExecutionLink
    case invalidExecutionReview
    case duplicateCandidate
    case candidateNotFound
    case invalidArchive
}
