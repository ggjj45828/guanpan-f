import Foundation
import CryptoKit

/// Recursive JSON values keep the NAS evidence tree structured without creating
/// a permissive `Any` escape hatch in DecisionContext.
public indirect enum FResearchJSONValue: Codable, Equatable, Sendable {
    case object([String: FResearchJSONValue])
    case array([FResearchJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null; return }
        if let value = try? single.decode(Bool.self) { self = .bool(value); return }
        if let value = try? single.decode(Double.self) { self = .number(value); return }
        if let value = try? single.decode(String.self) { self = .string(value); return }
        if let values = try? decoder.container(keyedBy: ResearchDynamicKey.self) {
            var object: [String: FResearchJSONValue] = [:]
            for key in values.allKeys { object[key.stringValue] = try values.decode(FResearchJSONValue.self, forKey: key) }
            self = .object(object)
            return
        }
        if var values = try? decoder.unkeyedContainer() {
            var array: [FResearchJSONValue] = []
            while !values.isAtEnd { array.append(try values.decode(FResearchJSONValue.self)) }
            self = .array(array)
            return
        }
        throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unsupported research JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .object(values):
            var container = encoder.container(keyedBy: ResearchDynamicKey.self)
            for (key, value) in values { try container.encode(value, forKey: ResearchDynamicKey(key)) }
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values { try container.encode(value) }
        case let .string(value): var container = encoder.singleValueContainer(); try container.encode(value)
        case let .number(value):
            var container = encoder.singleValueContainer()
            if value.isFinite, value.rounded() == value, let integer = Int64(exactly: value) {
                try container.encode(integer)
            } else {
                try container.encode(value)
            }
        case let .bool(value): var container = encoder.singleValueContainer(); try container.encode(value)
        case .null: var container = encoder.singleValueContainer(); try container.encodeNil()
        }
    }

    fileprivate var objectValue: [String: FResearchJSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    fileprivate var integerValue: Int? {
        guard case let .number(value) = self, value.isFinite, value.rounded() == value else { return nil }
        return Int(exactly: value)
    }

    fileprivate var numberValue: Double? {
        guard case let .number(value) = self, value.isFinite else { return nil }
        return value
    }

    fileprivate var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    fileprivate var isNull: Bool { if case .null = self { return true }; return false }
}

private struct ResearchDynamicKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int? = nil
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}

public struct FResearchDateRange: Codable, Equatable, Sendable {
    public let start: String
    public let end: String
}

/// Direct Codable representation of NAS `ResearchEvidenceEnvelope` schema v1.
/// Evidence is compact statistics only; raw minute bars and executable plans are rejected.
public struct FResearchEvidenceEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let methodologyVersion: String
    public let evidenceId: String
    public let securityCode: String
    public let market: String
    public let range: FResearchDateRange
    public let asOf: String
    public let generatedAt: String
    public let timezone: String?
    public let sessionCoverage: [String: Int]
    public let qualifiedIndependentDays: Int
    public let minimumQuality: Int
    public let sources: [String]
    public let evidence: [String: FResearchJSONValue]
    public let limitations: [String]
    public let rawMinuteBarsIncluded: Bool
    public let tradePlan: FResearchJSONValue

    public var observedAt: Date { Self.parseTimestamp(asOf) ?? .distantPast }
    public var generatedAtDate: Date { Self.parseTimestamp(generatedAt) ?? .distantPast }

    /// True only when the requested evidence family itself meets the walk-forward
    /// gate; another qualified section cannot authorize a different strategy.
    public func hasQualifiedEvidence(_ family: String) -> Bool {
        guard let value = evidence[family] else { return false }
        return Self.hasQualifiedNode(value)
    }

    public func validate(capturedAt: Date, contextCreatedAt: Date) throws {
        guard schemaVersion == 1, methodologyVersion == "minute-research-1",
              Self.digest(evidenceId), Self.nonBlank(securityCode), Self.nonBlank(market),
              let start = Self.parseDay(range.start), let end = Self.parseDay(range.end), start <= end,
              let asOfDate = Self.parseTimestamp(asOf), let generatedDate = Self.parseTimestamp(generatedAt),
              generatedDate >= asOfDate, asOfDate <= contextCreatedAt,
              generatedDate <= capturedAt, capturedAt <= contextCreatedAt,
              sources.allSatisfy(Self.nonBlank),
              (qualifiedIndependentDays == 0 || !sources.isEmpty),
              qualifiedIndependentDays >= 0, minimumQuality >= 0, minimumQuality <= 100,
              rawMinuteBarsIncluded == false, tradePlan.isNull,
              Set(evidence.keys).isSubset(of: Set(["vwapBreak", "morningRecovery", "gridSpacingReplay", "dividendQuality"])),
              !evidence.isEmpty, !Self.containsForbiddenPayload(.object(evidence)),
              try calculatedContentDigest() == evidenceId else {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        let data = try JSONEncoder().encode(evidence)
        guard data.count <= 32_768 else {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        for count in sessionCoverage.values where count < 0 {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        if let dividend = evidence["dividendQuality"] {
            guard Self.validDividendNode(dividend, envelopeAsOf: asOfDate) else {
                throw FDecisionContextError.invalidResearchEvidence(evidenceId)
            }
        }
    }

    public func isUsableForAI(capturedAt: Date, contextCreatedAt: Date, now: Date) -> Bool {
        guard minimumQuality >= 90,
              (try? validate(capturedAt: capturedAt, contextCreatedAt: contextCreatedAt)) != nil,
              now >= capturedAt, now.timeIntervalSince(asOfDate) <= FContextDataClass.nasResearch.maximumAge else {
            return false
        }
        if let dividend = evidence["dividendQuality"] {
            return Self.validDividendNode(dividend, envelopeAsOf: asOfDate)
        }
        guard qualifiedIndependentDays >= 25 else { return false }
        return Self.hasQualifiedNode(.object(evidence))
    }

    public var compactSummary: String {
        let qualified = Self.qualifiedNodeCount(.object(evidence))
        return "\(market)/\(securityCode) · 合格研究类型 \(qualified) · 独立交易日 \(qualifiedIndependentDays) · 来源 \(sources.joined(separator: ","))"
    }

    private var asOfDate: Date { observedAt }

    private static func hasQualifiedNode(_ value: FResearchJSONValue) -> Bool {
        if let object = value.objectValue {
            if object["evidenceState"]?.stringValue == "available_for_review",
               let training = object["trainingDays"]?.integerValue, training >= 20,
               let outOfSample = object["outOfSampleDays"]?.integerValue, outOfSample >= 5,
               let share = object["maxMonthlySampleShare"]?.numberValue,
               let maximum = object["maximumMonthlySampleShare"]?.numberValue,
               share >= 0, maximum >= 0, share <= maximum, maximum <= 0.5 {
                return true
            }
            return object.values.contains(where: hasQualifiedNode)
        }
        return false
    }

    /// Dividend evidence has factor provenance gates, not minute-research day counts.
    private static func validDividendNode(_ value: FResearchJSONValue, envelopeAsOf: Date) -> Bool {
        guard let root = value.objectValue,
              root["evidenceState"]?.stringValue == "evidence_available",
              root["referenceInterpretation"]?.stringValue == "descriptive_only_not_a_hard_gate",
              root["tradePlan"]?.isNull == true,
              let factors = root["factors"]?.objectValue,
              let coverage = root["factorCoverage"]?.objectValue,
              let available = coverage["available"]?.integerValue, available >= 3,
              let expected = coverage["expected"]?.integerValue, expected == 10,
              Set(factors.keys).isSubset(of: Set(["currentYield", "consecutivePayments", "payoutRatio",
                  "earningsQuality", "dividendTrend", "freeCashFlow", "indexDividendTraits",
                  "valuation", "interestRateContext", "peerComparison"])),
              factors["currentYield"] != nil else { return false }
        for factor in factors.values {
            guard let item = factor.objectValue,
                  let source = item["source"]?.stringValue, !source.trimmingCharacters(
                    in: .whitespacesAndNewlines).isEmpty,
                  let quality = item["quality"]?.integerValue, quality >= 90,
                  let observedText = item["observedAt"]?.stringValue,
                  let fetchedText = item["fetchedAt"]?.stringValue,
                  let observedAt = parseTimestamp(observedText),
                  let fetchedAt = parseTimestamp(fetchedText),
                  observedAt <= fetchedAt, fetchedAt <= envelopeAsOf else { return false }
        }
        return true
    }

    private static func qualifiedNodeCount(_ value: FResearchJSONValue) -> Int {
        guard let object = value.objectValue else { return 0 }
        let isQualified = object["evidenceState"]?.stringValue == "available_for_review" &&
            (object["trainingDays"]?.integerValue ?? 0) >= 20 &&
            (object["outOfSampleDays"]?.integerValue ?? 0) >= 5 &&
            (object["maxMonthlySampleShare"]?.numberValue ?? -1) >= 0 &&
            (object["maximumMonthlySampleShare"]?.numberValue ?? -1) >= 0 &&
            (object["maxMonthlySampleShare"]?.numberValue ?? 1) <=
            (object["maximumMonthlySampleShare"]?.numberValue ?? 0) &&
            (object["maximumMonthlySampleShare"]?.numberValue ?? 1) <= 0.5
        return (isQualified ? 1 : 0) + object.values.reduce(0) { $0 + qualifiedNodeCount($1) }
    }

    private static func containsForbiddenPayload(_ value: FResearchJSONValue) -> Bool {
        switch value {
        case let .object(object):
            return object.contains { key, child in
                let normalized = key.lowercased()
                if ["bars", "minutebars", "samples", "tradeplan"].contains(normalized) {
                    return !child.isNull
                }
                return containsForbiddenPayload(child)
            }
        case let .array(values):
            return values.contains(where: containsForbiddenPayload)
        default: return false
        }
    }

    private static func digest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    /// Mirrors NAS `ResearchEvidenceEnvelope.create` stable payload. Quality,
    /// coverage, source and eligibility gates are content-addressed as well as stats.
    func calculatedContentDigest() throws -> String {
        guard let asOfDate = Self.parseTimestamp(asOf),
              let generatedDate = Self.parseTimestamp(generatedAt) else {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        let stable: [String: FResearchJSONValue] = [
            "schemaVersion": .number(Double(schemaVersion)),
            "methodologyVersion": .string(methodologyVersion),
            "securityCode": .string(securityCode),
            "market": .string(market),
            "startDate": .string(range.start),
            "endDate": .string(range.end),
            "asOfEpochMillis": .number((asOfDate.timeIntervalSince1970 * 1_000).rounded()),
            "generatedAtEpochMillis": .number((generatedDate.timeIntervalSince1970 * 1_000).rounded()),
            "timezone": timezone.map(FResearchJSONValue.string) ?? .null,
            "sessionCoverage": .object(sessionCoverage.mapValues { .number(Double($0)) }),
            "qualifiedIndependentDays": .number(Double(qualifiedIndependentDays)),
            "minimumQuality": .number(Double(minimumQuality)),
            "sources": .array(sources.map(FResearchJSONValue.string)),
            "evidence": .object(evidence),
            "limitations": .array(limitations.map(FResearchJSONValue.string)),
            "rawMinuteBarsIncluded": .bool(rawMinuteBarsIncluded),
            "tradePlan": tradePlan
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(FResearchJSONValue.object(stable))
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    private static func nonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private static func parseDay(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
    private static func parseTimestamp(_ value: String) -> Date? {
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]
        ] {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let parsed = formatter.date(from: value) { return parsed }
        }
        return nil
    }
}

/// A read-only, point-in-time reference attached to a DecisionContext.
public struct FDecisionResearchEvidence: Codable, Equatable, Sendable, Identifiable {
    public var id: String { envelope.evidenceId }
    public let envelope: FResearchEvidenceEnvelope
    public let capturedAt: Date

    public init(envelope: FResearchEvidenceEnvelope, capturedAt: Date) {
        self.envelope = envelope
        self.capturedAt = capturedAt
    }

    public func validate(contextCreatedAt: Date) throws {
        try envelope.validate(capturedAt: capturedAt, contextCreatedAt: contextCreatedAt)
    }

    public func isUsableForAI(contextCreatedAt: Date, now: Date) -> Bool {
        envelope.isUsableForAI(capturedAt: capturedAt, contextCreatedAt: contextCreatedAt, now: now)
    }
}

/// Audit metadata for multiple versions of one research scope. All versions remain
/// in DecisionContext; the selected ID is explicit in the advisor request.
public struct FResearchEvidenceVersionConflict: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(market):\(securityCode):\(range.start):\(range.end)" }
    public let securityCode: String
    public let market: String
    public let range: FResearchDateRange
    public let schemaVersions: [Int]
    public let methodologyVersions: [String]
    public let evidenceIDs: [String]
    public let selectedEvidenceID: String?

    public init(securityCode: String, market: String, range: FResearchDateRange,
                schemaVersions: [Int], methodologyVersions: [String],
                evidenceIDs: [String], selectedEvidenceID: String?) {
        self.securityCode = securityCode
        self.market = market
        self.range = range
        self.schemaVersions = schemaVersions
        self.methodologyVersions = methodologyVersions
        self.evidenceIDs = evidenceIDs
        self.selectedEvidenceID = selectedEvidenceID
    }
}
