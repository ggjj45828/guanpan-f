import Foundation

/// Contract for an online or local language model. The model can return only a
/// candidate recommendation; this target has no dependency on real-ledger writes.
public protocol FAdvisorModelProviding: Sendable {
    func candidate(for request: FAdvisorQuestionRequest) async throws -> FCandidateRecommendation
}

public struct FAdvisorDecisionAssessment: Equatable, Sendable {
    public let candidate: FCandidateRecommendation
    public let guardResult: FDecisionGuardResult

    /// True means the candidate may be shown for user review. It never authorizes
    /// execution or changes the real account ledger.
    public var isEligibleForUserReview: Bool { guardResult.allowedForReview }

    public init(candidate: FCandidateRecommendation, guardResult: FDecisionGuardResult) {
        self.candidate = candidate
        self.guardResult = guardResult
    }
}

public enum FAdvisorDecisionPipelineError: Error, Equatable, Sendable {
    case requestContextMismatch
}

/// Read-only final decision orchestration: validate the captured context, call a
/// model provider, then apply deterministic guards before returning a reviewable
/// candidate. Persistence and ledger-writing APIs are intentionally absent.
public struct FAdvisorDecisionPipeline: Sendable {
    private let model: any FAdvisorModelProviding

    public init(model: any FAdvisorModelProviding) {
        self.model = model
    }

    public func assess(request: FAdvisorQuestionRequest,
                       context: FDecisionContext,
                       now: Date = Date()) async throws -> FAdvisorDecisionAssessment {
        try await assess(request: request, context: context, now: now, completionTime: Date())
    }

    /// Internal clock seam lets boundary tests reproduce slow model responses
    /// without sleeping for the quote freshness interval.
    func assess(request: FAdvisorQuestionRequest,
                context: FDecisionContext,
                now: Date,
                completionTime: Date) async throws -> FAdvisorDecisionAssessment {
        try context.validate(now: now)
        guard request.accountID == context.accountID,
              request.accountDigest == context.accountDigest,
              request.decisionContextID == context.id,
              request.decisionContextCreatedAt == context.createdAt,
              request.portfolioContext?.matches(context, scope: request.scope) == true,
              request.researchEvidenceMatches(context, at: now),
              request.advisorProjectionsAreValid(for: context) else {
            throw FAdvisorDecisionPipelineError.requestContextMismatch
        }

        let candidate = try await model.candidate(for: request)
        // A slow model response must not inherit the quote freshness from the
        // request start. Preserve deterministic future-dated fixtures while
        // advancing ordinary requests to the actual response completion time.
        let completedAt = max(now, completionTime)
        let base = FDecisionGuards.evaluate(candidate, in: context, using: request, now: completedAt)
        var findings = base.findings
        if case let .instrument(code) = request.scope,
           let candidateCode = candidate.instrumentCode, candidateCode != code {
            findings.append(.instrumentScopeMismatch(expected: code, actual: candidateCode))
        }
        let unique = Array(Set(findings)).sorted { String(describing: $0) < String(describing: $1) }
        return FAdvisorDecisionAssessment(
            candidate: candidate,
            guardResult: FDecisionGuardResult(allowedForReview: unique.isEmpty, findings: unique))
    }
}
