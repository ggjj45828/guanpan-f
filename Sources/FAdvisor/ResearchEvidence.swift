import Foundation
import CryptoKit
import FCore

/// Dividend factor providers are not yet connected to a verified source in this
/// app. Keep the set explicit so evidence remains unavailable until a real
/// provider is integrated and its provenance contract is reviewed.
public enum FResearchDividendSourceTrustPolicy {
    public static let trustedSources: Set<String> = []

    public static func isTrusted(_ source: String) -> Bool {
        trustedSources.contains(source.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

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

    fileprivate var boolValue: Bool? {
        if case let .bool(value) = self { return value }
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

/// Direct Codable representation of NAS `ResearchEvidenceEnvelope` schema v2.
/// Evidence is compact statistics only; raw minute bars and executable plans are rejected.
public struct FResearchEvidenceEnvelope: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let methodologyVersion: String
    public let evidenceId: String
    public let securityCode: String
    public let market: String
    public let range: FResearchDateRange
    /// Calendar-date span of sessions that actually passed archive quality gates.
    /// This is distinct from the requested query range.
    public let dataRange: FResearchDateRange?
    /// Nil means no NAS-qualified strategy version has been released for this evidence.
    public let strategyVersion: String?
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
        return Self.hasQualifiedNode(value, maximumIndependentDays: qualifiedIndependentDays, dataRange: dataRange)
    }

    public func validate(capturedAt: Date, contextCreatedAt: Date) throws {
        guard schemaVersion == 2, methodologyVersion == "minute-research-2",
              Self.digest(evidenceId), Self.nonBlank(securityCode), Self.nonBlank(market),
              let start = Self.parseDay(range.start), let end = Self.parseDay(range.end), start <= end,
              (dataRange.map {
                  guard let dataStart = Self.parseDay($0.start),
                        let dataEnd = Self.parseDay($0.end) else { return false }
                  return start <= dataStart && dataStart <= dataEnd && dataEnd <= end
              } ?? true),
              (strategyVersion.map(Self.nonBlank) ?? true),
              let asOfDate = Self.parseTimestamp(asOf), let generatedDate = Self.parseTimestamp(generatedAt),
              generatedDate >= asOfDate, asOfDate <= contextCreatedAt,
              generatedDate <= capturedAt, capturedAt <= contextCreatedAt,
              sources.allSatisfy(Self.nonBlank),
              (qualifiedIndependentDays == 0 || sources.allSatisfy(FResearchSourceTrustPolicy.isTrusted)),
              sessionCoverage.keys.allSatisfy(Self.nonBlank),
              (timezone.map(Self.nonBlank) ?? true),
              (timezone.map { TimeZone(identifier: $0) != nil } ?? true),
              (qualifiedIndependentDays == 0 || !sources.isEmpty),
              qualifiedIndependentDays >= 0, minimumQuality >= 0, minimumQuality <= 100,
              qualifiedIndependentDays == 0 || dataRange != nil,
              qualifiedIndependentDays == 0 || timezone != nil,
              qualifiedIndependentDays == 0 ||
                qualifiedIndependentDays <= (sessionCoverage["complete"] ?? 0),
              rawMinuteBarsIncluded == false, tradePlan.isNull,
              Set(evidence.keys).isSubset(of: Set(["vwapBreak", "morningRecovery", "gridSpacingReplay", "dividendQuality"])),
              Self.validGridSpacingSelection(evidence["gridSpacingReplay"]),
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
        guard dataRange != nil else { return false }
        return Self.hasQualifiedNode(.object(evidence), maximumIndependentDays: qualifiedIndependentDays, dataRange: dataRange)
    }

    public var compactSummary: String {
        let qualified = Self.qualifiedNodeCount(.object(evidence), maximumIndependentDays: qualifiedIndependentDays, dataRange: dataRange)
        return "\(market)/\(securityCode) · 合格研究类型 \(qualified) · 独立交易日 \(qualifiedIndependentDays) · 来源 \(sources.joined(separator: ","))"
    }

    private var asOfDate: Date { observedAt }

    private static func hasQualifiedNode(_ value: FResearchJSONValue, maximumIndependentDays: Int,
                                         dataRange: FResearchDateRange?) -> Bool {
        if let object = value.objectValue {
            if isQualifiedNode(object, maximumIndependentDays: maximumIndependentDays, dataRange: dataRange) {
                return true
            }
            return object.values.contains {
                hasQualifiedNode($0, maximumIndependentDays: maximumIndependentDays, dataRange: dataRange)
            }
        }
        return false
    }

    private static func isQualifiedNode(_ object: [String: FResearchJSONValue], maximumIndependentDays: Int,
                                        dataRange: FResearchDateRange?) -> Bool {
        guard object["evidenceState"]?.stringValue == "available_for_review",
              let independent = object["independentDays"]?.integerValue, independent > 0,
              independent <= maximumIndependentDays,
              let training = object["trainingDays"]?.integerValue, training >= 20,
              let outOfSample = object["outOfSampleDays"]?.integerValue, outOfSample >= 5,
              independent == training + outOfSample,
              let minimumTraining = object["minimumTrainingDays"]?.integerValue,
              training >= minimumTraining,
              let minimumOutOfSample = object["minimumOutOfSampleDays"]?.integerValue,
              outOfSample >= minimumOutOfSample,
              let trainingStats = object["training"]?.objectValue,
              trainingStats["days"]?.integerValue == training,
              let outStats = object["outOfSample"]?.objectValue,
              outStats["days"]?.integerValue == outOfSample,
              let trainingStartText = trainingStats["startDate"]?.stringValue,
              let trainingEndText = trainingStats["endDate"]?.stringValue,
              let outStartText = outStats["startDate"]?.stringValue,
              let outEndText = outStats["endDate"]?.stringValue,
              let trainingStart = parseDay(trainingStartText), let trainingEnd = parseDay(trainingEndText),
              let outStart = parseDay(outStartText), let outEnd = parseDay(outEndText),
              trainingStart <= trainingEnd, trainingEnd < outStart, outStart <= outEnd,
              let dataRange,
              let dataStart = parseDay(dataRange.start), let dataEnd = parseDay(dataRange.end),
              dataStart <= trainingStart, trainingEnd <= dataEnd,
              dataStart <= outStart, outEnd <= dataEnd,
              let share = object["maxMonthlySampleShare"]?.numberValue,
              let maximum = object["maximumMonthlySampleShare"]?.numberValue,
              share >= 0, maximum >= 0, share <= maximum, maximum <= 0.5 else { return false }
        return true
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
                  FResearchDividendSourceTrustPolicy.isTrusted(source),
                  let quality = item["quality"]?.integerValue, quality >= 90,
                  let observedText = item["observedAt"]?.stringValue,
                  let fetchedText = item["fetchedAt"]?.stringValue,
                  let observedAt = parseTimestamp(observedText),
                  let fetchedAt = parseTimestamp(fetchedText),
                  observedAt <= fetchedAt, fetchedAt <= envelopeAsOf else { return false }
        }
        return true
    }

    private static func qualifiedNodeCount(_ value: FResearchJSONValue, maximumIndependentDays: Int,
                                           dataRange: FResearchDateRange?) -> Int {
        guard let object = value.objectValue else { return 0 }
        let isQualified = isQualifiedNode(object, maximumIndependentDays: maximumIndependentDays, dataRange: dataRange)
        return (isQualified ? 1 : 0) + object.values.reduce(0) {
            $0 + qualifiedNodeCount($1, maximumIndependentDays: maximumIndependentDays, dataRange: dataRange)
        }
    }

    private static func validGridSpacingSelection(_ value: FResearchJSONValue?) -> Bool {
        guard let value else { return true }
        guard let root = value.objectValue,
              let spacings = root["spacings"]?.objectValue,
              let selectedValue = root["selectedSpacing"] else { return false }
        let reviewable = spacings.filter {
            $0.value.objectValue?["evidenceState"]?.stringValue == "available_for_review"
        }
        guard let selected = selectedValue.stringValue else {
            return selectedValue.isNull && reviewable.isEmpty && spacings.values.allSatisfy { node in
                node.objectValue?["selectedByTraining"]?.boolValue == false &&
                node.objectValue?["outOfSample"]?.isNull == true
            }
        }
        guard reviewable.count == 1, reviewable.first?.key == selected,
              let selectedNode = spacings[selected]?.objectValue,
              selectedNode["selectedByTraining"]?.boolValue == true,
              selectedNode["headlinePopulation"]?.stringValue == "out_of_sample",
              selectedNode["outOfSample"]?.objectValue != nil else { return false }
        return spacings.allSatisfy { key, value in
            guard key != selected, let node = value.objectValue else { return key == selected }
            return node["evidenceState"]?.stringValue != "available_for_review" &&
                node["selectedByTraining"]?.boolValue == false &&
                node["outOfSample"]?.isNull == true
        }
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
            "dataRange": dataRange.map {
                .object(["start": .string($0.start), "end": .string($0.end)])
            } ?? .null,
            "strategyVersion": strategyVersion.map(FResearchJSONValue.string) ?? .null,
            "asOfEpochMillis": .number(Double(try Self.epochMillis(asOf))),
            "generatedAtEpochMillis": .number(Double(try Self.epochMillis(generatedAt))),
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

    /// Converts the timestamp text directly so half-millisecond ties use the
    /// same exact, ties-away-from-zero rounding as the NAS Python serializer.
    private static func epochMillis(_ value: String) throws -> Int64 {
        let pattern = #"^(.*?)(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let baseRange = Range(match.range(at: 1), in: value),
              let zoneRange = Range(match.range(at: 3), in: value) else {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        let baseText = String(value[baseRange]) + String(value[zoneRange])
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let baseDate = formatter.date(from: baseText) else {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        let (baseMillis, overflow) = Int64(baseDate.timeIntervalSince1970).multipliedReportingOverflow(by: 1_000)
        guard !overflow else { throw FDecisionContextError.invalidResearchEvidence(evidenceId) }
        guard match.range(at: 2).location != NSNotFound,
              let fractionRange = Range(match.range(at: 2), in: value) else { return baseMillis }
        let digits = String(value[fractionRange])
        let firstThree = String((digits + "000").prefix(3))
        guard let fractionMillis = Int64(firstThree) else {
            throw FDecisionContextError.invalidResearchEvidence(evidenceId)
        }
        let roundedUp = digits.count > 3 && digits[digits.index(digits.startIndex, offsetBy: 3)] >= "5"
        let fractionalMillis = fractionMillis + (roundedUp ? 1 : 0)
        let (result, additionOverflow) = baseMillis.addingReportingOverflow(fractionalMillis)
        guard !additionOverflow else { throw FDecisionContextError.invalidResearchEvidence(evidenceId) }
        return result
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
