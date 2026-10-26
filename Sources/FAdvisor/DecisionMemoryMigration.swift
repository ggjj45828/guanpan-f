import Foundation

public struct FDecisionMemoryMigrationShard: Codable, Equatable, Sendable {
    public let accountID: UUID
    public let year: Int
    public let month: Int
    public let recordIDs: [UUID]
    public let estimatedPayloadBytes: Int

    public var stableKey: String {
        "\(accountID.uuidString.lowercased())/\(String(format: "%04d-%02d", year, month))"
    }
}

/// A read-only, deterministic description of how a validated v1 archive maps
/// to immutable account/month shards. It contains no write capability.
public struct FDecisionMemoryMigrationPlan: Codable, Equatable, Sendable {
    public let sourceSchemaVersion: Int
    public let sourceDigest: String
    public let recordCount: Int
    public let accountCount: Int
    public let duplicateIDs: [UUID]
    public let orderingViolationIDs: [UUID]
    public let invalidRecordIDs: [UUID]
    public let rejectionReasons: [String]
    public let shards: [FDecisionMemoryMigrationShard]
    public let estimatedPayloadBytes: Int

    public var isEligible: Bool {
        sourceSchemaVersion == 1 && duplicateIDs.isEmpty &&
        orderingViolationIDs.isEmpty && invalidRecordIDs.isEmpty
    }

    public init(archive: FDecisionMemoryArchive, sourceDigest: String,
                now: Date = Date()) throws {
        try self.init(records: archive.records, sourceSchemaVersion: archive.schemaVersion,
                      sourceDigest: sourceDigest, now: now)
    }

    /// Pure planner entry point, also used by validation tests to exercise
    /// corrupt legacy payloads without writing a fixture to disk.
    public init(records: [FDecisionMemory], sourceSchemaVersion: Int = 1,
                sourceDigest: String, now: Date = Date()) throws {
        guard sourceDigest.count == 64,
              sourceDigest.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdef").contains($0) }) else {
            throw FAdvisorPersistenceError.corruptDocument("invalid migration source digest")
        }
        guard sourceSchemaVersion == 1 else {
            throw FAdvisorPersistenceError.unsupportedArchiveVersion(sourceSchemaVersion)
        }
        var invalid = Set<UUID>()
        for record in records {
            do { try record.validate(now: now) }
            catch { invalid.insert(record.id) }
        }
        let identifiers = records.map(\.id)
        let identifierCounts = Dictionary(grouping: identifiers, by: { $0 })
        let duplicates = identifierCounts.filter { $0.value.count > 1 }.keys.sorted {
            $0.uuidString < $1.uuidString
        }
        var orderingViolations = Set<UUID>()
        for (previous, current) in zip(records, records.dropFirst()) {
            if current.decidedAt < previous.decidedAt ||
                (current.decidedAt == previous.decidedAt && current.id.uuidString < previous.id.uuidString) {
                orderingViolations.insert(current.id)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var grouped: [String: (account: UUID, year: Int, month: Int, records: [FDecisionMemory])] = [:]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        for record in records {
            guard !invalid.contains(record.id) else { continue }
            let parts = calendar.dateComponents([.year, .month], from: record.decidedAt)
            guard let year = parts.year, let month = parts.month,
                  (1...12).contains(month) else {
                invalid.insert(record.id)
                continue
            }
            let key = "\(record.accountID.uuidString.lowercased())/\(String(format: "%04d-%02d", year, month))"
            var bucket = grouped[key] ?? (record.accountID, year, month, [])
            bucket.records.append(record)
            grouped[key] = bucket
        }

        let plannedShards = try grouped.keys.sorted().map { key -> FDecisionMemoryMigrationShard in
            let bucket = grouped[key]!
            let records = bucket.records.sorted {
                if $0.decidedAt != $1.decidedAt { return $0.decidedAt < $1.decidedAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            let bytes = try encoder.encode(records).count
            return FDecisionMemoryMigrationShard(accountID: bucket.account,
                                                  year: bucket.year, month: bucket.month,
                                                  recordIDs: records.map(\.id),
                                                  estimatedPayloadBytes: bytes)
        }
        self.sourceSchemaVersion = sourceSchemaVersion
        self.sourceDigest = sourceDigest
        recordCount = records.count
        accountCount = Set(records.map(\.accountID)).count
        duplicateIDs = duplicates
        orderingViolationIDs = orderingViolations.sorted { $0.uuidString < $1.uuidString }
        invalidRecordIDs = invalid.sorted { $0.uuidString < $1.uuidString }
        var reasons: [String] = []
        if !duplicates.isEmpty { reasons.append("duplicate-record-ids") }
        if !orderingViolations.isEmpty { reasons.append("non-canonical-source-order") }
        if !invalid.isEmpty { reasons.append("invalid-records") }
        rejectionReasons = reasons
        shards = plannedShards
        estimatedPayloadBytes = plannedShards.reduce(0) { $0 + $1.estimatedPayloadBytes }
    }
}
