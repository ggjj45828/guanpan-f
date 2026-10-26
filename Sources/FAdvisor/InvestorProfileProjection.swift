import Foundation

/// A bounded, point-in-time view of the user's effective preferences for an
/// advisor request. It contains no store handle or mutation capability.
public struct FAdvisorProfilePreference: Codable, Equatable, Sendable, Identifiable {
    public var id: FInvestorProfileAttributeKey { attribute }
    public let attribute: FInvestorProfileAttributeKey
    public let revisionID: UUID
    public let value: FInvestorProfileValue
    public let confidence: Decimal
    public let source: FInvestorProfileSource
    public let updatedAt: Date
    public let explanation: String

    fileprivate init(attribute: FInvestorProfileAttributeKey, revision: FInvestorProfileRevision) {
        self.attribute = attribute
        revisionID = revision.id
        value = revision.value
        confidence = revision.confidence
        source = revision.source
        updatedAt = revision.updatedAt
        explanation = revision.explanation
    }
}

public struct FAdvisorInvestorProfileProjection: Codable, Equatable, Sendable {
    public let asOf: Date
    public let preferences: [FAdvisorProfilePreference]

    public init(profile: FInvestorProfile, asOf: Date, validatedAt: Date = Date()) throws {
        guard asOf.timeIntervalSince1970.isFinite, asOf <= validatedAt else {
            throw FAdvisorEntryError.invalidProjectionTime
        }
        try profile.validate(now: validatedAt)
        self.asOf = asOf
        preferences = profile.attributes.compactMap { attribute in
            attribute.current(at: asOf).map {
                FAdvisorProfilePreference(attribute: attribute.key, revision: $0)
            }
        }.sorted { $0.attribute.rawValue < $1.attribute.rawValue }
    }

    /// Revalidates decoded projections at the point-of-use. Codable payloads do
    /// not inherit the source profile's constructor and revision checks.
    public func isValid(asOf expectedAsOf: Date) -> Bool {
        guard asOf == expectedAsOf, asOf.timeIntervalSince1970.isFinite,
              preferences.count <= FInvestorProfileAttributeKey.allCases.count,
              Set(preferences.map(\.attribute)).count == preferences.count,
              Set(preferences.map(\.revisionID)).count == preferences.count,
              preferences == preferences.sorted(by: {
                  $0.attribute.rawValue < $1.attribute.rawValue
              }) else { return false }
        return preferences.allSatisfy { preference in
            let valueIsValid: Bool
            switch preference.value {
            case let .text(value):
                valueIsValid = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case let .decimal(value): valueIsValid = !value.isNaN
            case .integer, .boolean: valueIsValid = true
            }
            return valueIsValid && !preference.confidence.isNaN &&
                preference.confidence >= 0 && preference.confidence <= 1 &&
                preference.updatedAt.timeIntervalSince1970.isFinite &&
                preference.updatedAt <= asOf &&
                !preference.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
