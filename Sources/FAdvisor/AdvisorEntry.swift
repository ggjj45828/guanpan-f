import Foundation
import FCore

public enum FAdvisorEntryScope: Codable, Equatable, Sendable {
    case portfolio
    case instrument(String)

    public var displayName: String {
        switch self {
        case .portfolio: return "我的真实组合"
        case let .instrument(code): return code
        }
    }
}

/// A question carries the already-captured real account context. Callers do not
/// ask the user to retype cash, cost basis, or holdings before asking the advisor.
public struct FAdvisorQuestionRequest: Codable, Equatable, Sendable {
    public let question: String
    public let scope: FAdvisorEntryScope
    public let decisionContextID: UUID
    public let decisionContextCreatedAt: Date?
    public let accountID: UUID
    public let accountDigest: String
    /// Read-only holdings, cash and observations actually supplied to the advisor.
    /// It contains no ledger writer or mutable account object.
    public let portfolioContext: FAdvisorPortfolioContextProjection?
    /// Only quality-gated, compact NAS evidence is sent; the account remains read-only.
    public let researchEvidence: [FDecisionResearchEvidence]
    /// Conflicting versions remain visible even when one eligible version is selected.
    public let researchEvidenceVersionConflicts: [FResearchEvidenceVersionConflict]
    /// Effective profile preferences at request time; this is advisory context only.
    public let investorProfile: FAdvisorInvestorProfileProjection?
    /// Only a bounded history through the captured context time is included.
    public let decisionMemory: FAdvisorDecisionMemoryProjection?

    /// Include this instruction in the model system prompt when a profile is present.
    public var profileUseConstraint: String? {
        guard investorProfile != nil else { return nil }
        return "投资者画像只能用于建议排序、风险表达和策略适配；不得据此预测用户下一笔交易、推断未表达的即时意图或修改真实资产。画像不是成交证据。"
    }

    private static let maximumEncodedRequestBytes = 65_536

    public init(question: String, scope: FAdvisorEntryScope,
                decisionContext: FDecisionContext, investorProfile profile: FInvestorProfile? = nil,
                decisionMemory: FAdvisorDecisionMemoryProjection? = nil,
                now: Date = Date()) throws {
        try decisionContext.validate(now: now)
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FAdvisorEntryError.emptyQuestion
        }
        if case let .instrument(code) = scope,
           code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw FAdvisorEntryError.invalidInstrument
        }
        guard decisionMemory == nil ||
                (decisionMemory?.accountID == decisionContext.accountID &&
                 decisionMemory?.asOf == decisionContext.createdAt) else {
            throw FAdvisorEntryError.contextProjectionMismatch
        }
        self.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scope = scope
        decisionContextID = decisionContext.id
        decisionContextCreatedAt = decisionContext.createdAt
        accountID = decisionContext.accountID
        accountDigest = decisionContext.accountDigest
        portfolioContext = FAdvisorPortfolioContextProjection(context: decisionContext)
        researchEvidence = decisionContext.usableResearchEvidence(at: now)
        researchEvidenceVersionConflicts = decisionContext.researchEvidenceVersionConflicts(at: now)
        investorProfile = try profile.map {
            try FAdvisorInvestorProfileProjection(profile: $0, asOf: decisionContext.createdAt,
                                                  validatedAt: now)
        }
        self.decisionMemory = decisionMemory
        guard try JSONEncoder().encode(self).count <= Self.maximumEncodedRequestBytes else {
            throw FAdvisorEntryError.payloadTooLarge
        }
    }

    /// Verifies that decoded request payloads carry exactly the eligible research
    /// references and conflict metadata derived from the immutable context. A
    /// serialized request is untrusted input and cannot add or replace evidence.
    public func researchEvidenceMatches(_ context: FDecisionContext,
                                        at now: Date = Date()) -> Bool {
        researchEvidence == context.usableResearchEvidence(at: now) &&
            researchEvidenceVersionConflicts == context.researchEvidenceVersionConflicts(at: now)
    }

    public func advisorProjectionsAreValid(for context: FDecisionContext) -> Bool {
        guard let asOf = decisionContextCreatedAt else {
            return investorProfile == nil && decisionMemory == nil
        }
        return (investorProfile?.isValid(asOf: asOf) ?? true) &&
            (decisionMemory?.isValid(accountID: context.accountID, scope: scope, asOf: asOf) ?? true)
    }

    private enum CodingKeys: String, CodingKey {
        case question, scope, decisionContextID, decisionContextCreatedAt, accountID, accountDigest
        case portfolioContext
        case researchEvidence, researchEvidenceVersionConflicts, investorProfile, decisionMemory
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        question = try values.decode(String.self, forKey: .question)
        scope = try values.decode(FAdvisorEntryScope.self, forKey: .scope)
        decisionContextID = try values.decode(UUID.self, forKey: .decisionContextID)
        decisionContextCreatedAt = try values.decodeIfPresent(Date.self, forKey: .decisionContextCreatedAt)
        accountID = try values.decode(UUID.self, forKey: .accountID)
        accountDigest = try values.decode(String.self, forKey: .accountDigest)
        portfolioContext = try values.decodeIfPresent(FAdvisorPortfolioContextProjection.self,
                                                       forKey: .portfolioContext)
        researchEvidence = try values.decodeIfPresent([FDecisionResearchEvidence].self,
                                                       forKey: .researchEvidence) ?? []
        researchEvidenceVersionConflicts = try values.decodeIfPresent(
            [FResearchEvidenceVersionConflict].self, forKey: .researchEvidenceVersionConflicts) ?? []
        investorProfile = try values.decodeIfPresent(FAdvisorInvestorProfileProjection.self,
                                                     forKey: .investorProfile)
        decisionMemory = try values.decodeIfPresent(FAdvisorDecisionMemoryProjection.self,
                                                     forKey: .decisionMemory)
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FAdvisorEntryError.emptyQuestion
        }
        guard decisionMemory == nil ||
                (decisionMemory?.accountID == accountID && decisionContextCreatedAt != nil &&
                 decisionMemory?.asOf == decisionContextCreatedAt),
              decisionContextCreatedAt == nil ||
                (investorProfile == nil || investorProfile?.asOf == decisionContextCreatedAt),
              decisionContextCreatedAt.map({ asOf in
                  (investorProfile?.isValid(asOf: asOf) ?? true) &&
                    (decisionMemory?.isValid(accountID: accountID, scope: scope, asOf: asOf) ?? true)
              }) ?? (investorProfile == nil && decisionMemory == nil) else {
            throw FAdvisorEntryError.contextProjectionMismatch
        }
        if let portfolioContext,
           (portfolioContext.contextID != decisionContextID ||
            portfolioContext.accountID != accountID || portfolioContext.accountDigest != accountDigest ||
            portfolioContext.capturedAt != decisionContextCreatedAt) {
            throw FAdvisorEntryError.contextProjectionMismatch
        }
        guard try JSONEncoder().encode(self).count <= Self.maximumEncodedRequestBytes else {
            throw FAdvisorEntryError.payloadTooLarge
        }
    }
}

/// Bounded immutable projection sent with a portfolio question. It intentionally
/// has no ledger store, transaction API, or candidate-plan mutation capability.
public struct FAdvisorPortfolioContextProjection: Codable, Equatable, Sendable {
    public let contextID: UUID
    public let accountID: UUID
    public let accountDigest: String
    public let capturedAt: Date
    public let cashBalance: Decimal
    public let holdings: [FDecisionHoldingSnapshot]
    public let observations: [FContextObservation]

    fileprivate init(context: FDecisionContext) {
        contextID = context.id
        accountID = context.accountID
        accountDigest = context.accountDigest
        capturedAt = context.createdAt
        cashBalance = context.cashBalance
        holdings = context.holdings
        observations = context.observations
    }

    public func matches(_ context: FDecisionContext) -> Bool {
        contextID == context.id && accountID == context.accountID &&
            accountDigest == context.accountDigest && capturedAt == context.createdAt &&
            cashBalance == context.cashBalance && holdings == context.holdings &&
            observations == context.observations
    }
}

public enum FAdvisorEntryError: Error, Equatable, Sendable {
    case emptyQuestion
    case invalidInstrument
    case invalidProjectionTime
    case invalidMemoryProjectionLimit
    case contextProjectionMismatch
    case payloadTooLarge
}

public enum FAdvisorPromptShortcuts {
    public static let commonQuestions = [
        "今天我的持仓需要操作吗？",
        "159352 现在适合买入吗？",
        "我的 A500 怎么降低成本？",
        "今天适合做 T 吗？",
        "为什么今天的建议和昨天不一样？"
    ]
}

/// Loads advisory documents through their read-only actor APIs. Ledger access is
/// deliberately absent; the caller must supply a captured immutable context.
public struct FAdvisorRequestAssembler: Sendable {
    private let profileStore: FInvestorProfileStore
    private let memoryStore: FDecisionMemoryStore

    public init(profileStore: FInvestorProfileStore, memoryStore: FDecisionMemoryStore) {
        self.profileStore = profileStore
        self.memoryStore = memoryStore
    }

    public func assemble(question: String, scope: FAdvisorEntryScope,
                         decisionContext: FDecisionContext, now: Date = Date()) async throws
        -> FAdvisorQuestionRequest {
        let profile = try await profileStore.load(now: now)
        let memoryProjection = try await memoryStore.recentProjection(
            accountID: decisionContext.accountID, scope: scope,
            asOf: decisionContext.createdAt, now: now)
        return try FAdvisorQuestionRequest(question: question, scope: scope,
                                           decisionContext: decisionContext,
                                           investorProfile: profile,
                                           decisionMemory: memoryProjection, now: now)
    }
}
