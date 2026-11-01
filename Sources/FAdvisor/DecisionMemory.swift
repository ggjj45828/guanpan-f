import Foundation
import FCore

public enum FDecisionAction: String, Codable, Equatable, Sendable {
    case hold, wait, buy, sell, dayTrade, grid, recoveryPlan
}

public enum FDecisionEvidenceKind: String, Codable, Equatable, Sendable {
    case holding, cash, quote, previousClose, intradayBar, dailyBar, iopv, news, nasResearch
    case crossMarket, riskState, investorProfile, decisionMemory, userStatement
}

/// A cited fact used at decision time. It stores provenance and a compact captured value,
/// never a live service object or a mutable reference to the real ledger.
public struct FDecisionEvidence: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let kind: FDecisionEvidenceKind
    public let source: String
    public let reference: String?
    public let observedAt: Date
    public let capturedAt: Date
    public let summary: String
    public let isStale: Bool
    public let timestampTrust: FQuoteTimeTrust?

    public init(id: UUID = UUID(), kind: FDecisionEvidenceKind, source: String,
                reference: String? = nil, observedAt: Date, capturedAt: Date,
                summary: String, isStale: Bool = false,
                timestampTrust: FQuoteTimeTrust? = nil) {
        self.id = id
        self.kind = kind
        self.source = source
        self.reference = reference
        self.observedAt = observedAt
        self.capturedAt = capturedAt
        self.summary = summary
        self.isStale = isStale
        self.timestampTrust = timestampTrust
    }
}

public struct FDecisionHoldingSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let name: String
    public let units: Int64
    public let bookCost: Decimal
    public let brokerDisplayCostPerUnit: Decimal?
    public let brokerDisplayCostUpdatedAt: Date?

    public init(instrumentCode: String, name: String, units: Int64, bookCost: Decimal,
                brokerDisplayCostPerUnit: Decimal? = nil,
                brokerDisplayCostUpdatedAt: Date? = nil) {
        self.instrumentCode = instrumentCode
        self.name = name
        self.units = units
        self.bookCost = bookCost
        self.brokerDisplayCostPerUnit = brokerDisplayCostPerUnit
        self.brokerDisplayCostUpdatedAt = brokerDisplayCostUpdatedAt
    }
}

public struct FDecisionOutcome: Codable, Equatable, Sendable {
    public let recordedAt: Date
    /// Links to confirmed F ledger event IDs. This object cannot create those events.
    public let confirmedFillIDs: [UUID]
    public let summary: String
    public let userFeedback: String?

    public init(recordedAt: Date, confirmedFillIDs: [UUID] = [],
                summary: String, userFeedback: String? = nil) {
        self.recordedAt = recordedAt
        self.confirmedFillIDs = confirmedFillIDs
        self.summary = summary
        self.userFeedback = userFeedback
    }
}

/// Append-oriented record of what the advisor knew and recommended at one point in time.
/// It is separate from FAccountBook; only the ledger may own real asset mutations.
public struct FDecisionMemory: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let accountID: UUID
    public let decidedAt: Date
    public let action: FDecisionAction
    /// Optional for legacy memories; new app-created records freeze the request scope.
    public let scope: FAdvisorEntryScope?
    public let instrumentCode: String?
    public let recommendation: String
    public let rationale: String
    public let conditions: [String]
    public let accountDigest: String
    public let cashSnapshot: Decimal
    public let holdingsSnapshot: [FDecisionHoldingSnapshot]
    public let evidence: [FDecisionEvidence]
    public private(set) var outcomes: [FDecisionOutcome]

    public init(id: UUID = UUID(), context: FDecisionContext,
                candidate: FCandidateRecommendation, recommendation: String, rationale: String,
                conditions: [String] = [], advisorRequest: FAdvisorQuestionRequest? = nil) throws {
        try context.validate(now: context.createdAt)
        let observations = Dictionary(uniqueKeysWithValues: context.observations.map { ($0.id, $0) })
        let researchIDs = Set(context.researchEvidence.map(\.id))
        let memoryIDs = Set(advisorRequest?.decisionMemory?.entries.map(\.id) ?? [])
        let profileRevisionIDs = Set(advisorRequest?.investorProfile?.preferences.map(\.revisionID) ?? [])
        let hasAdvisorCitations = !candidate.citedDecisionMemoryIDs.isEmpty ||
            !candidate.citedInvestorProfileRevisionIDs.isEmpty
        guard candidate.accountDigest == context.accountDigest,
              candidate.citedObservationIDs.allSatisfy({ observations[$0] != nil }),
              candidate.citedResearchEvidenceIDs.allSatisfy({ researchIDs.contains($0) }),
              Set(candidate.citedDecisionMemoryIDs).count == candidate.citedDecisionMemoryIDs.count,
              Set(candidate.citedInvestorProfileRevisionIDs).count ==
                candidate.citedInvestorProfileRevisionIDs.count,
              candidate.citedDecisionMemoryIDs.allSatisfy({ memoryIDs.contains($0) }),
              candidate.citedInvestorProfileRevisionIDs.allSatisfy({ profileRevisionIDs.contains($0) }),
              !hasAdvisorCitations || advisorRequest.map({
                  $0.accountID == context.accountID && $0.accountDigest == context.accountDigest &&
                  $0.decisionContextID == context.id && $0.decisionContextCreatedAt == context.createdAt
              }) == true else {
            throw FDecisionMemoryError.invalidRecord
        }
        self.id = id
        accountID = context.accountID
        decidedAt = context.createdAt
        action = candidate.action
        scope = advisorRequest?.scope
        instrumentCode = candidate.instrumentCode
        self.recommendation = recommendation
        self.rationale = rationale
        self.conditions = conditions
        accountDigest = context.accountDigest
        cashSnapshot = context.cashBalance
        holdingsSnapshot = context.holdings
        let observationEvidence = context.observations.map { observation in
            let kind: FDecisionEvidenceKind
            switch observation.dataClass {
            case .quote: kind = .quote
            case .previousClose: kind = .previousClose
            case .intraday: kind = .intradayBar
            case .iopv: kind = .iopv
            case .dailyHistory: kind = .dailyBar
            case .news: kind = .news
            case .nasResearch: kind = .nasResearch
            case .crossMarket: kind = .crossMarket
            case .quantState: kind = .riskState
            }
            let summary = observation.decimalValue.map {
                NSDecimalNumber(decimal: $0).stringValue
            } ?? observation.unavailableReason ?? "不可用"
            let evidenceObservedAt = observation.dataClass == .quote
                ? (observation.quoteTemporalMetadata?.quoteTimestamp ??
                   observation.quoteTemporalMetadata?.fetchedAt ?? observation.observedAt ??
                   observation.capturedAt)
                : (observation.observedAt ?? observation.capturedAt)
            let timestampTrust = observation.dataClass == .quote
                ? (observation.quoteTemporalMetadata?.timestampTrust ?? .unavailable) : nil
            return FDecisionEvidence(id: observation.id, kind: kind, source: observation.source,
                                     reference: observation.reference,
                                     observedAt: evidenceObservedAt,
                                     capturedAt: observation.capturedAt, summary: summary,
                                     isStale: !observation.isFresh(at: context.createdAt),
                                     timestampTrust: timestampTrust)
        }
        let researchReferences = context.researchEvidence.map { reference in
            FDecisionEvidence(kind: .nasResearch,
                              source: reference.envelope.sources.joined(separator: ","),
                              reference: reference.id,
                              observedAt: reference.envelope.observedAt,
                              capturedAt: reference.capturedAt,
                              summary: reference.envelope.compactSummary,
                              isStale: !reference.isUsableForAI(contextCreatedAt: context.createdAt,
                                                               now: context.createdAt))
        }
        let profileReferences = (advisorRequest?.investorProfile?.preferences ?? []).filter {
            candidate.citedInvestorProfileRevisionIDs.contains($0.revisionID)
        }.map { preference in
            FDecisionEvidence(kind: .investorProfile,
                              source: "investor-profile.\(preference.source.rawValue)",
                              reference: preference.revisionID.uuidString,
                              observedAt: preference.updatedAt, capturedAt: context.createdAt,
                              summary: String("\(preference.attribute.rawValue)=\(Self.describe(preference.value)); \(preference.explanation)".prefix(1_500)))
        }
        let memoryReferences = (advisorRequest?.decisionMemory?.entries ?? []).filter {
            candidate.citedDecisionMemoryIDs.contains($0.id)
        }.map { reference in
            FDecisionEvidence(kind: .decisionMemory, source: "decision-memory",
                              reference: reference.id.uuidString,
                              observedAt: reference.decidedAt, capturedAt: context.createdAt,
                              summary: "\(reference.action.rawValue): \(reference.recommendation); \(reference.rationale)")
        }
        evidence = observationEvidence + researchReferences + profileReferences + memoryReferences
        outcomes = []
    }

    private static func describe(_ value: FInvestorProfileValue) -> String {
        switch value {
        case let .text(text): return text
        case let .decimal(number): return NSDecimalNumber(decimal: number).stringValue
        case let .integer(number): return String(number)
        case let .boolean(flag): return flag ? "true" : "false"
        }
    }

    /// Outcome links are accepted only when every fill ID is present in a fresh
    /// read-only account snapshot for the same account.
    public func recording(_ outcome: FDecisionOutcome,
                          verifiedAgainst snapshot: FReadOnlyLedgerSnapshot) throws -> FDecisionMemory {
        guard snapshot.accountID == accountID,
              outcome.recordedAt <= snapshot.capturedAt,
              FDecisionValidation.nonBlank(outcome.summary),
              outcome.userFeedback.map({ FDecisionValidation.nonBlank($0) }) ?? true,
              outcome.confirmedFillIDs.allSatisfy({
                  guard snapshot.confirmedFillIDs.contains($0),
                        let tradedAt = snapshot.confirmedFillTimestamps[$0] else { return false }
                  return decidedAt <= tradedAt && tradedAt <= outcome.recordedAt
              }) else {
            throw FDecisionMemoryError.invalidRecord
        }
        if outcomes.contains(outcome) { return self }
        let priorFillIDs = Set(outcomes.flatMap(\.confirmedFillIDs))
        guard outcome.confirmedFillIDs.allSatisfy({ !priorFillIDs.contains($0) }) else {
            throw FDecisionMemoryError.invalidRecord
        }
        var updated = self
        updated.outcomes.append(outcome)
        try updated.validate(now: snapshot.capturedAt)
        return updated
    }

    public func validate(now: Date = Date()) throws {
        guard FDecisionValidation.plausible(decidedAt, now: now),
              FDecisionValidation.nonBlank(recommendation), FDecisionValidation.nonBlank(rationale),
              FDecisionValidation.digest(accountDigest), cashSnapshot.isFinite, cashSnapshot >= 0,
              scope.map({ value in
                  switch value {
                  case .portfolio: return true
                  case .instrument(let code):
                      return FDecisionValidation.nonBlank(code) &&
                          (instrumentCode == nil || instrumentCode == code)
                  }
              }) ?? true,
              Set(holdingsSnapshot.map(\.instrumentCode)).count == holdingsSnapshot.count,
              holdingsSnapshot.allSatisfy({
                  FDecisionValidation.nonBlank($0.instrumentCode) && FDecisionValidation.nonBlank($0.name) &&
                  $0.units > 0 && $0.bookCost.isFinite && $0.bookCost >= 0 &&
                  ($0.brokerDisplayCostPerUnit.map { $0.isFinite && $0 >= 0 } ?? true)
              }),
              Set(evidence.map(\.id)).count == evidence.count,
              evidence.allSatisfy({
                  FDecisionValidation.nonBlank($0.source) && FDecisionValidation.nonBlank($0.summary) &&
                  FDecisionValidation.plausible($0.observedAt, now: now) &&
                  FDecisionValidation.plausible($0.capturedAt, now: now) &&
                  $0.observedAt <= $0.capturedAt && $0.capturedAt <= decidedAt
              }),
              Set(outcomes.flatMap(\.confirmedFillIDs)).count == outcomes.flatMap(\.confirmedFillIDs).count,
              outcomes.allSatisfy({
                  FDecisionValidation.plausible($0.recordedAt, now: now) &&
                  $0.recordedAt >= decidedAt && FDecisionValidation.nonBlank($0.summary) &&
                  ($0.userFeedback.map(FDecisionValidation.nonBlank) ?? true) &&
                  Set($0.confirmedFillIDs).count == $0.confirmedFillIDs.count
              }) else {
            throw FDecisionMemoryError.invalidRecord
        }
        guard outcomes.indices.allSatisfy({ index in
            !outcomes[..<index].contains(outcomes[index])
        }) else {
            throw FDecisionMemoryError.invalidRecord
        }
    }
}

public enum FDecisionMemoryError: Error, Equatable, Sendable { case invalidRecord }

private enum FDecisionValidation {
    static func nonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    static func digest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy(\.isHexDigit)
    }
    static func plausible(_ value: Date, now: Date) -> Bool {
        value.timeIntervalSince1970.isFinite && value <= now.addingTimeInterval(300)
    }
}
