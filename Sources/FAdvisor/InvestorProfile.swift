import Foundation

public enum FInvestorProfileAttributeKey: String, Codable, CaseIterable, Sendable {
    case investmentHorizon
    case riskTolerance
    case tradingFrequency
    case patientLimitPreference
    case dayTradePreference
    case gridPreference
    case cashReservePreference
    case investmentStyle
}

public enum FInvestorProfileValue: Codable, Equatable, Sendable {
    case text(String)
    case decimal(Decimal)
    case integer(Int64)
    case boolean(Bool)

    private enum CodingKeys: String, CodingKey { case type, text, decimal, integer, boolean }
    private enum ValueType: String, Codable { case text, decimal, integer, boolean }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        switch try values.decode(ValueType.self, forKey: .type) {
        case .text: self = .text(try values.decode(String.self, forKey: .text))
        case .decimal: self = .decimal(try values.decode(Decimal.self, forKey: .decimal))
        case .integer: self = .integer(try values.decode(Int64.self, forKey: .integer))
        case .boolean: self = .boolean(try values.decode(Bool.self, forKey: .boolean))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try values.encode(ValueType.text, forKey: .type); try values.encode(value, forKey: .text)
        case .decimal(let value):
            try values.encode(ValueType.decimal, forKey: .type); try values.encode(value, forKey: .decimal)
        case .integer(let value):
            try values.encode(ValueType.integer, forKey: .type); try values.encode(value, forKey: .integer)
        case .boolean(let value):
            try values.encode(ValueType.boolean, forKey: .type); try values.encode(value, forKey: .boolean)
        }
    }

    fileprivate var isValid: Bool {
        switch self {
        case .text(let value): return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .decimal(let value): return !value.isNaN
        case .integer, .boolean: return true
        }
    }
}

public enum FInvestorProfileSource: String, Codable, Equatable, Sendable {
    case explicit, learned, temporary
}

public struct FInvestorProfileRevision: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let value: FInvestorProfileValue
    public let confidence: Decimal
    public let source: FInvestorProfileSource
    public let updatedAt: Date
    public let explanation: String
    public let expiresAt: Date?
    /// Optional stable link to a DecisionMemory, feedback, or user statement record.
    public let sourceReference: String?
    /// Explicit user correction may supersede one prior revision of the same attribute.
    public let supersedesRevisionID: UUID?

    public init(id: UUID = UUID(), value: FInvestorProfileValue, confidence: Decimal,
                source: FInvestorProfileSource, updatedAt: Date, explanation: String,
                expiresAt: Date? = nil, sourceReference: String? = nil,
                supersedesRevisionID: UUID? = nil) {
        self.id = id
        self.value = value
        self.confidence = confidence
        self.source = source
        self.updatedAt = updatedAt
        self.explanation = explanation
        self.expiresAt = expiresAt
        self.sourceReference = sourceReference
        self.supersedesRevisionID = supersedesRevisionID
    }

    public func validate(now: Date = Date()) throws {
        guard value.isValid, !confidence.isNaN, confidence >= 0, confidence <= 1,
              FInvestorProfileValidation.nonBlank(explanation),
              sourceReference.map(FInvestorProfileValidation.nonBlank) ?? true,
              FInvestorProfileValidation.plausible(updatedAt, now: now),
              (source == .temporary) == (expiresAt != nil),
              expiresAt.map({ $0 > updatedAt && FInvestorProfileValidation.plausible($0, now: now.addingTimeInterval(366 * 24 * 3600)) }) ?? true else {
            throw FInvestorProfileError.invalidRevision
        }
    }
}

public struct FInvestorProfileAttribute: Codable, Equatable, Sendable, Identifiable {
    public var id: FInvestorProfileAttributeKey { key }
    public let key: FInvestorProfileAttributeKey
    public fileprivate(set) var revisions: [FInvestorProfileRevision]

    public init(key: FInvestorProfileAttributeKey, revisions: [FInvestorProfileRevision] = []) {
        self.key = key
        self.revisions = revisions
    }

    public func current(at date: Date = Date()) -> FInvestorProfileRevision? {
        revisions.last(where: { revision in
            guard revision.updatedAt <= date else { return false }
            return revision.expiresAt.map { $0 > date } ?? true
        })
    }

    fileprivate mutating func append(_ revision: FInvestorProfileRevision) {
        revisions.append(revision)
        revisions.sort {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

public enum FInvestorProfileUpdateResult: Equatable, Sendable {
    case applied
    case alreadyApplied
    case protectedByExplicitValue
}

public enum FInvestorProfileError: Error, Equatable, Sendable {
    case invalidRevision
    case duplicateRevision(UUID)
    case invalidProfile
    case explicitResetRequired
}

/// A versioned, explainable profile. It ranks and phrases recommendations only;
/// no profile API accepts a trade or mutates FAccountBook.
public struct FInvestorProfile: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public private(set) var attributes: [FInvestorProfileAttribute]

    public init(attributes: [FInvestorProfileAttribute] = [], schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.attributes = attributes
    }

    public func validate(now: Date = Date()) throws {
        guard schemaVersion == 1,
              Set(attributes.map(\.key)).count == attributes.count else {
            throw FInvestorProfileError.invalidProfile
        }
        var ids = Set<UUID>()
        for attribute in attributes {
            let ordered = attribute.revisions.sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            guard ordered == attribute.revisions else {
                throw FInvestorProfileError.invalidProfile
            }
            for revision in attribute.revisions {
                try revision.validate(now: now)
                if let supersededID = revision.supersedesRevisionID {
                    guard revision.source == .explicit,
                          let superseded = attribute.revisions.first(where: { $0.id == supersededID }),
                          superseded.id != revision.id,
                          superseded.updatedAt < revision.updatedAt ||
                            (superseded.updatedAt == revision.updatedAt &&
                             superseded.id.uuidString < revision.id.uuidString) else {
                        throw FInvestorProfileError.invalidProfile
                    }
                }
                guard ids.insert(revision.id).inserted else {
                    throw FInvestorProfileError.duplicateRevision(revision.id)
                }
            }
        }
    }

    public func attribute(_ key: FInvestorProfileAttributeKey) -> FInvestorProfileAttribute? {
        attributes.first(where: { $0.key == key })
    }

    /// Learned or temporary observations cannot replace a current explicit preference.
    /// A new explicit revision is the only way to correct that preference.
    @discardableResult
    public mutating func record(_ revision: FInvestorProfileRevision,
                                for key: FInvestorProfileAttributeKey,
                                now: Date = Date()) throws -> FInvestorProfileUpdateResult {
        try validate(now: now)
        try revision.validate(now: now)
        if let existing = attributes.flatMap({ $0.revisions }).first(where: { $0.id == revision.id }) {
            guard existing == revision,
                  attributes.first(where: { $0.revisions.contains(where: { $0.id == revision.id }) })?.key == key else {
                throw FInvestorProfileError.duplicateRevision(revision.id)
            }
            return .alreadyApplied
        }
        if let supersededID = revision.supersedesRevisionID {
            guard revision.source == .explicit,
                  let prior = attribute(key)?.revisions.first(where: { $0.id == supersededID }),
                  prior.id != revision.id,
                  prior.updatedAt < revision.updatedAt ||
                    (prior.updatedAt == revision.updatedAt && prior.id.uuidString < revision.id.uuidString) else {
                throw FInvestorProfileError.invalidRevision
            }
        }
        if revision.source != .explicit,
           let current = attribute(key)?.current(at: now),
           current.source == .explicit {
            return .protectedByExplicitValue
        }
        if let index = attributes.firstIndex(where: { $0.key == key }) {
            attributes[index].append(revision)
        } else {
            attributes.append(FInvestorProfileAttribute(key: key, revisions: [revision]))
            attributes.sort { $0.key.rawValue < $1.key.rawValue }
        }
        return .applied
    }

    /// Clears learned/temporary history while retaining explicit user statements.
    public mutating func clearLearnedAndTemporary() {
        for index in attributes.indices {
            attributes[index].revisions.removeAll { $0.source != .explicit }
        }
        attributes.removeAll(where: { $0.revisions.isEmpty })
    }

    /// Full reset is an explicit user action because it removes user-authored preferences.
    public mutating func resetAll(userConfirmed: Bool) throws {
        guard userConfirmed else { throw FInvestorProfileError.explicitResetRequired }
        attributes.removeAll()
    }
}

private enum FInvestorProfileValidation {
    static func nonBlank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    static func plausible(_ date: Date, now: Date) -> Bool {
        date.timeIntervalSince1970.isFinite && date <= now.addingTimeInterval(300)
    }
}
