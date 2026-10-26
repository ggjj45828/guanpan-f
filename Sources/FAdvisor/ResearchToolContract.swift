import Foundation

/// Model-callable research operations. These names are not transaction tools and
/// must never be mapped to a ledger writer or broker API.
public enum FAdvisorResearchTool: String, Codable, CaseIterable, Equatable, Sendable {
    case minutePatternSummary
    case vwapBreakStudy
    case morningRecoveryStudy
    case gridSpacingReplay
    case dividendQualityStudy
}

public struct FAdvisorResearchToolCall: Codable, Equatable, Sendable {
    public let tool: FAdvisorResearchTool
    public let securityCode: String
    public let market: String
    public let startDate: String
    public let endDate: String
    public let asOf: Date

    public init(tool: FAdvisorResearchTool, securityCode: String, market: String,
                startDate: String, endDate: String, asOf: Date) {
        self.tool = tool
        self.securityCode = securityCode
        self.market = market
        self.startDate = startDate
        self.endDate = endDate
        self.asOf = asOf
    }

    /// Binds an untrusted model request to the active question and its captured time.
    /// It only authorizes retrieval of historical evidence; it cannot create plans.
    public func validate(for request: FAdvisorQuestionRequest, now: Date = Date()) throws {
        guard !securityCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let start = Self.day(startDate), let end = Self.day(endDate), start <= end,
              (end.timeIntervalSince(start) / 86_400) <= 730,
              asOf.timeIntervalSince1970.isFinite,
              asOf <= now, request.decisionContextCreatedAt.map({ asOf <= $0 }) == true,
              Self.matchesScope(securityCode, scope: request.scope) else {
            throw FAdvisorResearchToolError.invalidOrUnboundRequest
        }
    }

    /// Executes a bounded read-only NAS research request and validates the provider response
    /// against the exact requested instrument, market, date range, and decision timestamp.
    /// Only quality-qualified compact evidence can be returned to the advisor caller.
    public func execute(using provider: any FAdvisorResearchProviding,
                        for request: FAdvisorQuestionRequest,
                        now: Date = Date()) async throws -> FDecisionResearchEvidence {
        try validate(for: request, now: now)
        guard let contextCreatedAt = request.decisionContextCreatedAt else {
            throw FAdvisorResearchToolError.invalidOrUnboundRequest
        }
        let result = try await provider.evidence(for: self)
        let receivedAt = Date()
        // A tool response arrives after the initial question context. Its facts
        // remain frozen at the requested asOf; the caller must capture a new
        // DecisionContext before sending this evidence to the model again.
        guard result.capturedAt.timeIntervalSince1970.isFinite,
              result.capturedAt <= receivedAt.addingTimeInterval(300) else {
            throw FAdvisorResearchToolError.invalidOrUnboundResponse
        }
        try result.validate(contextCreatedAt: result.capturedAt)
        let envelope = result.envelope
        let expectedEvidenceKey: String?
        switch tool {
        case .minutePatternSummary: expectedEvidenceKey = nil
        case .vwapBreakStudy: expectedEvidenceKey = "vwapBreak"
        case .morningRecoveryStudy: expectedEvidenceKey = "morningRecovery"
        case .gridSpacingReplay: expectedEvidenceKey = "gridSpacingReplay"
        case .dividendQualityStudy: expectedEvidenceKey = "dividendQuality"
        }
        guard envelope.securityCode == securityCode,
              envelope.market == market,
              envelope.range.start == startDate,
              envelope.range.end == endDate,
              envelope.observedAt <= asOf,
              expectedEvidenceKey.map({ envelope.evidence[$0] != nil }) ?? !envelope.evidence.isEmpty,
              result.isUsableForAI(contextCreatedAt: result.capturedAt, now: receivedAt) else {
            throw FAdvisorResearchToolError.invalidOrUnboundResponse
        }
        return result
    }

    private static func matchesScope(_ code: String, scope: FAdvisorEntryScope) -> Bool {
        switch scope {
        case .portfolio: return true
        case let .instrument(requested): return code == requested
        }
    }

    private static func day(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let result = formatter.date(from: value), formatter.string(from: result) == value else {
            return nil
        }
        return result
    }
}

public enum FAdvisorResearchToolError: Error, Equatable, Sendable {
    case invalidOrUnboundRequest
    case invalidOrUnboundResponse
}

/// Provider contract returns compact read-only evidence. No candidate plan or
/// ledger mutation operation is part of this protocol.
public protocol FAdvisorResearchProviding: Sendable {
    func evidence(for call: FAdvisorResearchToolCall) async throws -> FDecisionResearchEvidence
}
