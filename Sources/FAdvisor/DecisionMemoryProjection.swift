import Foundation

public struct FAdvisorMemoryEvidenceProjection: Codable, Equatable, Sendable {
    public let kind: FDecisionEvidenceKind
    public let source: String
    public let summary: String
    public let observedAt: Date
    public let isStale: Bool
    public let timestampTrust: FQuoteTimeTrust?

    fileprivate init(_ evidence: FDecisionEvidence) {
        kind = evidence.kind
        source = String(evidence.source.prefix(96))
        summary = String(evidence.summary.prefix(320))
        observedAt = evidence.observedAt
        isStale = evidence.isStale
        timestampTrust = evidence.timestampTrust
    }
}

public struct FAdvisorMemoryOutcomeProjection: Codable, Equatable, Sendable {
    public let recordedAt: Date
    public let confirmedFillCount: Int
    public let summary: String
    public let userFeedback: String?

    fileprivate init(_ outcome: FDecisionOutcome) {
        recordedAt = outcome.recordedAt
        confirmedFillCount = outcome.confirmedFillIDs.count
        summary = String(outcome.summary.prefix(500))
        userFeedback = outcome.userFeedback.map { String($0.prefix(500)) }
    }
}

/// Bounded decision history for explaining changes in advice. Only facts known
/// at the DecisionContext time are included; this is not a mutable Memory store.
public struct FAdvisorDecisionMemoryReference: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let decidedAt: Date
    public let action: FDecisionAction
    public let instrumentCode: String?
    public let recommendation: String
    public let rationale: String
    public let conditions: [String]
    public let evidence: [FAdvisorMemoryEvidenceProjection]
    public let outcomes: [FAdvisorMemoryOutcomeProjection]

    fileprivate init(_ memory: FDecisionMemory, asOf: Date) {
        id = memory.id
        decidedAt = memory.decidedAt
        action = memory.action
        instrumentCode = memory.instrumentCode
        recommendation = String(memory.recommendation.prefix(800))
        rationale = String(memory.rationale.prefix(1_000))
        conditions = memory.conditions.prefix(5).map { String($0.prefix(200)) }
        evidence = memory.evidence.prefix(8).map(FAdvisorMemoryEvidenceProjection.init)
        outcomes = memory.outcomes.filter { $0.recordedAt <= asOf }
            .suffix(3).map(FAdvisorMemoryOutcomeProjection.init)
    }
}

public struct FAdvisorDecisionMemoryProjection: Codable, Equatable, Sendable {
    public let accountID: UUID
    public let asOf: Date
    public let entries: [FAdvisorDecisionMemoryReference]

    public init(records: [FDecisionMemory], accountID: UUID, scope: FAdvisorEntryScope,
                asOf: Date, validatedAt: Date, maximumEntries: Int = 5) throws {
        guard asOf.timeIntervalSince1970.isFinite, asOf <= validatedAt else {
            throw FAdvisorEntryError.invalidProjectionTime
        }
        guard (1...5).contains(maximumEntries) else {
            throw FAdvisorEntryError.invalidMemoryProjectionLimit
        }
        let scoped = records.filter { record in
            guard record.accountID == accountID, record.decidedAt <= asOf else { return false }
            switch scope {
            case .portfolio:
                return true
            case let .instrument(code):
                return record.instrumentCode == nil || record.instrumentCode == code
            }
        }
        for record in scoped { try record.validate(now: validatedAt) }
        self.accountID = accountID
        self.asOf = asOf
        entries = scoped.sorted {
            if $0.decidedAt != $1.decidedAt { return $0.decidedAt > $1.decidedAt }
            return $0.id.uuidString > $1.id.uuidString
        }.prefix(maximumEntries).map { FAdvisorDecisionMemoryReference($0, asOf: asOf) }
    }

    /// Validates the bounded, point-in-time projection after decoding so future
    /// outcomes or out-of-scope memories cannot enter the model context.
    public func isValid(accountID expectedAccountID: UUID, scope: FAdvisorEntryScope,
                        asOf expectedAsOf: Date) -> Bool {
        guard accountID == expectedAccountID, asOf == expectedAsOf,
              asOf.timeIntervalSince1970.isFinite, entries.count <= 5,
              Set(entries.map(\.id)).count == entries.count else { return false }
        for (index, entry) in entries.enumerated() {
            guard entry.decidedAt.timeIntervalSince1970.isFinite, entry.decidedAt <= asOf,
                  Self.nonBlank(entry.recommendation),
                  Self.nonBlank(entry.rationale), entry.conditions.count <= 5,
                  entry.conditions.allSatisfy(Self.nonBlank),
                  entry.evidence.count <= 8, entry.outcomes.count <= 3,
                  entry.outcomes.allSatisfy({ $0.recordedAt.timeIntervalSince1970.isFinite &&
                      $0.recordedAt <= asOf && $0.confirmedFillCount >= 0 &&
                      Self.nonBlank($0.summary) &&
                      ($0.userFeedback.map(Self.nonBlank) ?? true) }),
                  entry.evidence.allSatisfy({ $0.observedAt.timeIntervalSince1970.isFinite &&
                      $0.observedAt <= asOf && Self.nonBlank($0.source) &&
                      Self.nonBlank($0.summary) }) else { return false }
            switch scope {
            case .portfolio: break
            case let .instrument(code):
                guard entry.instrumentCode == nil || entry.instrumentCode == code else { return false }
            }
            if index > 0 {
                let prior = entries[index - 1]
                guard prior.decidedAt > entry.decidedAt ||
                    (prior.decidedAt == entry.decidedAt &&
                     prior.id.uuidString > entry.id.uuidString) else { return false }
            }
        }
        return true
    }

    private static func nonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
