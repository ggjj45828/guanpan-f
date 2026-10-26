import Foundation
import CryptoKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private struct FMemorySegmentRecordFile: Codable, Equatable {
    let schemaVersion: Int
    let record: FDecisionMemory
    let recordDigest: String
}

private struct FMemorySegmentIndexEntry: Codable, Equatable {
    let id: UUID
    let decidedAt: Date
    let instrumentCode: String?
    let relativePath: String
    let recordFileDigest: String
}

private struct FMemorySegmentIndex: Codable, Equatable {
    let schemaVersion: Int
    let accountID: UUID
    let year: Int
    let month: Int
    let entries: [FMemorySegmentIndexEntry]
}

private struct FMemorySegmentIndexReference: Codable, Equatable {
    let accountID: UUID
    let year: Int
    let month: Int
    let relativePath: String
    let indexDigest: String
}

private struct FMemorySegmentManifestMaterial: Codable, Equatable {
    let schemaVersion: Int
    let generationID: String
    let sourceDigest: String
    let recordCount: Int
    let indexes: [FMemorySegmentIndexReference]
}

private struct FMemorySegmentManifest: Codable, Equatable {
    let material: FMemorySegmentManifestMaterial
    let manifestDigest: String
}

private struct FMemorySegmentCurrent: Codable, Equatable {
    let schemaVersion: Int
    let generationID: String
    let manifestDigest: String
}

private struct FMemoryBackupMaterial: Codable, Equatable {
    let schemaVersion: Int
    let current: FMemorySegmentCurrent
}

private struct FMemoryBackupDocument: Codable, Equatable {
    let material: FMemoryBackupMaterial
    let backupDigest: String
}

public struct FDecisionMemoryMigrationReceipt: Codable, Equatable, Sendable {
    public let sourceDigest: String
    public let generationID: String
    public let recordCount: Int
    public let indexCount: Int
    public let wasAlreadyCommitted: Bool
}

public struct FDecisionMemoryBackupReceipt: Codable, Equatable, Sendable {
    public let generationID: String
    public let sourceDigest: String
    public let recordCount: Int
    public let backupDigest: String
}

public struct FDecisionMemoryRestoreReceipt: Codable, Equatable, Sendable {
    public let generationID: String
    public let sourceDigest: String
    public let recordCount: Int
    public let wasAlreadyCurrent: Bool
}

/// Immutable segmented Memory archive. A generation becomes visible only when
/// the verified CURRENT pointer is atomically replaced.
actor FSegmentedDecisionMemoryStore {
    enum FaultPoint: Equatable, Sendable {
        case afterRecordWrite
        case afterIndexWrite
        case afterManifestWrite
        case afterGenerationRename
        case beforeCurrentCommit
        case afterCurrentWrite
    }

    private let root: URL
    private let generations: URL
    private let currentURL: URL
    private let previousURL: URL
    private let faultInjector: (@Sendable (FaultPoint) throws -> Void)?

    init(directory: URL,
         faultInjector: (@Sendable (FaultPoint) throws -> Void)? = nil) {
        root = directory
        generations = directory.appendingPathComponent("generations", isDirectory: true)
        currentURL = directory.appendingPathComponent("CURRENT.json")
        previousURL = directory.appendingPathComponent("CURRENT.previous.json")
        self.faultInjector = faultInjector
    }

    func currentSourceDigest() throws -> String? {
        guard let pointer = try readCurrent() else { return nil }
        return try loadManifest(generationID: pointer.generationID,
                                expectedDigest: pointer.manifestDigest).material.sourceDigest
    }

    func invalidateCurrent() throws {
        guard try readCurrent() != nil else { return }
        // Removing the commit pointer makes the untouched legacy archive
        // authoritative before any subsequent v1 mutation begins.
        let pointerBytes = try Data(contentsOf: currentURL)
        try atomicDurableWrite(pointerBytes, to: previousURL)
        try FileManager.default.removeItem(at: currentURL)
        try synchronizeDirectory(root)
    }

    /// Internal entry point. FDecisionMemoryStore supplies a source freshly
    /// loaded and authenticated from its v1 envelope.
    func install(archive: FDecisionMemoryArchive,
                 plan: FDecisionMemoryMigrationPlan,
                 expectedSourceDigest: String,
                 expectedPriorGenerationID: String?,
                 now: Date) throws -> FDecisionMemoryMigrationReceipt {
        guard plan.isEligible, plan.sourceDigest == expectedSourceDigest else {
            throw FAdvisorPersistenceError.corruptDocument("migration plan is not eligible")
        }
        let recomputed = try FDecisionMemoryMigrationPlan(archive: archive,
                                                          sourceDigest: expectedSourceDigest,
                                                          now: now)
        guard recomputed == plan else {
            throw FAdvisorPersistenceError.corruptDocument("migration plan/source mismatch")
        }

        let prior = try readCurrent()
        let generationID = "v1-\(expectedSourceDigest)"
        if prior?.generationID == generationID {
            let verified = try loadManifest(generationID: generationID,
                                            expectedDigest: prior!.manifestDigest)
            guard verified.material.sourceDigest == expectedSourceDigest,
                  verified.material.recordCount == archive.records.count else {
                throw FAdvisorPersistenceError.corruptDocument("current generation/source mismatch")
            }
            try verifyGeneration(at: generationDirectory(generationID), manifest: verified)
            return FDecisionMemoryMigrationReceipt(sourceDigest: expectedSourceDigest,
                                                   generationID: generationID,
                                                   recordCount: archive.records.count,
                                                   indexCount: verified.material.indexes.count,
                                                   wasAlreadyCommitted: true)
        }
        guard prior?.generationID == expectedPriorGenerationID else {
            throw FAdvisorPersistenceError.concurrentModification(
                expected: expectedPriorGenerationID, actual: prior?.generationID)
        }

        try FileManager.default.createDirectory(at: generations,
                                                withIntermediateDirectories: true)
        let staging = root.appendingPathComponent(".staging-\(UUID().uuidString)",
                                                  isDirectory: true)
        try FileManager.default.createDirectory(at: staging,
                                                withIntermediateDirectories: true)
        do {
            let manifest = try buildGeneration(archive: archive, plan: plan,
                                               generationID: generationID,
                                               staging: staging)
            try verifyGeneration(at: staging, manifest: manifest)
            try synchronizeDirectoryTree(staging)
            let destination = generationDirectory(generationID)
            if FileManager.default.fileExists(atPath: destination.path) {
                let existing = try loadManifest(generationID: generationID,
                                                expectedDigest: manifest.manifestDigest)
                try verifyGeneration(at: destination, manifest: existing)
                try FileManager.default.removeItem(at: staging)
            } else {
                try FileManager.default.moveItem(at: staging, to: destination)
                try faultInjector?(.afterGenerationRename)
                try synchronizeDirectory(generations)
                try synchronizeDirectory(root)
            }

            // Recheck optimistic concurrency immediately before the commit point.
            let latest = try readCurrent()
            guard latest?.generationID == expectedPriorGenerationID else {
                throw FAdvisorPersistenceError.concurrentModification(
                    expected: expectedPriorGenerationID, actual: latest?.generationID)
            }
            let finalManifest = try loadManifest(generationID: generationID,
                                                 expectedDigest: manifest.manifestDigest)
            try verifyGeneration(at: destination, manifest: finalManifest)
            let pointer = FMemorySegmentCurrent(schemaVersion: 1,
                                                generationID: generationID,
                                                manifestDigest: finalManifest.manifestDigest)
            try commit(pointer, expectedPriorGenerationID: expectedPriorGenerationID)
            return FDecisionMemoryMigrationReceipt(sourceDigest: expectedSourceDigest,
                                                   generationID: generationID,
                                                   recordCount: archive.records.count,
                                                   indexCount: finalManifest.material.indexes.count,
                                                   wasAlreadyCommitted: false)
        } catch {
            if FileManager.default.fileExists(atPath: staging.path) {
                try? FileManager.default.removeItem(at: staging)
            }
            throw error
        }
    }

    func createBackup(at destination: URL) throws -> FDecisionMemoryBackupReceipt {
        guard let pointer = try readCurrent() else { throw FAdvisorPersistenceError.documentMissing }
        let destination = destination.standardizedFileURL
        let rootPath = root.standardizedFileURL.path + "/"
        guard destination != root.standardizedFileURL,
              !destination.path.hasPrefix(rootPath),
              !FileManager.default.fileExists(atPath: destination.path) else {
            throw FAdvisorPersistenceError.invalidBackupDestination
        }
        let manifest = try loadManifest(generationID: pointer.generationID,
                                        expectedDigest: pointer.manifestDigest)
        try verifyGeneration(at: generationDirectory(pointer.generationID), manifest: manifest)
        let material = FMemoryBackupMaterial(schemaVersion: 1, current: pointer)
        let backup = FMemoryBackupDocument(material: material,
                                           backupDigest: digest(try encode(material)))
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".\(destination.lastPathComponent).staging-\(UUID().uuidString)",
                                                    isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            let stagedGeneration = staging.appendingPathComponent("generations", isDirectory: true)
                .appendingPathComponent(pointer.generationID, isDirectory: true)
            try FileManager.default.createDirectory(at: stagedGeneration.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: generationDirectory(pointer.generationID),
                                             to: stagedGeneration)
            try writeVerified(try encode(backup), to: staging.appendingPathComponent("BACKUP.json"))
            try writeVerified(try encode(pointer), to: staging.appendingPathComponent("CURRENT.json"))
            let copied = try loadManifest(at: stagedGeneration,
                                          generationID: pointer.generationID,
                                          expectedDigest: pointer.manifestDigest)
            try verifyGeneration(at: stagedGeneration, manifest: copied)
            try synchronizeDirectoryTree(staging)
            try FileManager.default.moveItem(at: staging, to: destination)
            try synchronizeDirectory(parent)
            let restoredBackup = try loadBackup(at: destination)
            return FDecisionMemoryBackupReceipt(generationID: pointer.generationID,
                                                sourceDigest: manifest.material.sourceDigest,
                                                recordCount: manifest.material.recordCount,
                                                backupDigest: restoredBackup.0.backupDigest)
        } catch {
            if FileManager.default.fileExists(atPath: staging.path) {
                try? FileManager.default.removeItem(at: staging)
            }
            throw error
        }
    }

    func restoreBackup(from source: URL,
                       expectedPriorGenerationID: String?) throws
        -> FDecisionMemoryRestoreReceipt {
        let (backup, manifest) = try loadBackup(at: source)
        let pointer = backup.material.current
        let current = try readCurrent()
        if current == pointer {
            try verifyGeneration(at: generationDirectory(pointer.generationID), manifest: manifest)
            return FDecisionMemoryRestoreReceipt(generationID: pointer.generationID,
                                                 sourceDigest: manifest.material.sourceDigest,
                                                 recordCount: manifest.material.recordCount,
                                                 wasAlreadyCurrent: true)
        }
        guard current?.generationID == expectedPriorGenerationID else {
            throw FAdvisorPersistenceError.concurrentModification(
                expected: expectedPriorGenerationID, actual: current?.generationID)
        }
        let destination = generationDirectory(pointer.generationID)
        if FileManager.default.fileExists(atPath: destination.path) {
            let existing = try loadManifest(generationID: pointer.generationID,
                                            expectedDigest: pointer.manifestDigest)
            try verifyGeneration(at: destination, manifest: existing)
        } else {
            try FileManager.default.createDirectory(at: generations,
                                                    withIntermediateDirectories: true)
            let staging = root.appendingPathComponent(".restore-\(UUID().uuidString)",
                                                      isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            do {
                let stagedGeneration = staging.appendingPathComponent(pointer.generationID,
                                                                       isDirectory: true)
                try FileManager.default.copyItem(
                    at: source.appendingPathComponent("generations", isDirectory: true)
                        .appendingPathComponent(pointer.generationID, isDirectory: true),
                    to: stagedGeneration)
                try synchronizeDirectoryTree(staging)
                let copiedManifest = try loadManifest(at: stagedGeneration,
                                                      generationID: pointer.generationID,
                                                      expectedDigest: pointer.manifestDigest)
                try verifyGeneration(at: stagedGeneration, manifest: copiedManifest)
                try FileManager.default.moveItem(at: stagedGeneration, to: destination)
                try FileManager.default.removeItem(at: staging)
                try synchronizeDirectory(generations)
                try synchronizeDirectory(root)
            } catch {
                if FileManager.default.fileExists(atPath: staging.path) {
                    try? FileManager.default.removeItem(at: staging)
                }
                throw error
            }
        }
        try commit(pointer, expectedPriorGenerationID: expectedPriorGenerationID)
        return FDecisionMemoryRestoreReceipt(generationID: pointer.generationID,
                                             sourceDigest: manifest.material.sourceDigest,
                                             recordCount: manifest.material.recordCount,
                                             wasAlreadyCurrent: false)
    }

    func backupSourceDigest(at source: URL) throws -> String {
        try loadBackup(at: source).1.material.sourceDigest
    }

    func recentProjection(accountID: UUID, scope: FAdvisorEntryScope,
                          asOf: Date, maximumEntries: Int = 5,
                          now: Date = Date()) throws
        -> FAdvisorDecisionMemoryProjection? {
        guard asOf <= now else { throw FAdvisorEntryError.invalidProjectionTime }
        guard (1...5).contains(maximumEntries) else {
            throw FAdvisorEntryError.invalidMemoryProjectionLimit
        }
        guard let pointer = try readCurrent() else { return nil }
        let manifest = try loadManifest(generationID: pointer.generationID,
                                        expectedDigest: pointer.manifestDigest)
        var entries: [FMemorySegmentIndexEntry] = []
        for reference in manifest.material.indexes where reference.accountID == accountID {
            guard monthStart(year: reference.year, month: reference.month) <= asOf else { continue }
            let indexURL = try safeURL(reference.relativePath, generationID: pointer.generationID)
            let bytes = try Data(contentsOf: indexURL)
            guard digest(bytes) == reference.indexDigest else {
                throw FAdvisorPersistenceError.corruptDocument("memory index digest mismatch")
            }
            let index = try JSONDecoder().decode(FMemorySegmentIndex.self, from: bytes)
            guard index.schemaVersion == 1, index.accountID == accountID,
                  index.year == reference.year, index.month == reference.month else {
                throw FAdvisorPersistenceError.corruptDocument("memory index identity mismatch")
            }
            entries += index.entries.filter { entry in
                guard entry.decidedAt <= asOf else { return false }
                switch scope {
                case .portfolio: return true
                case let .instrument(code): return entry.instrumentCode == nil || entry.instrumentCode == code
                }
            }
        }
        let selected = entries.sorted {
            if $0.decidedAt != $1.decidedAt { return $0.decidedAt > $1.decidedAt }
            return $0.id.uuidString > $1.id.uuidString
        }.prefix(maximumEntries)
        var records: [FDecisionMemory] = []
        for entry in selected {
            let url = try safeURL(entry.relativePath, generationID: pointer.generationID)
            let bytes = try Data(contentsOf: url)
            guard digest(bytes) == entry.recordFileDigest else {
                throw FAdvisorPersistenceError.corruptDocument("memory record digest mismatch")
            }
            let stored = try JSONDecoder().decode(FMemorySegmentRecordFile.self, from: bytes)
            guard stored.schemaVersion == 1, stored.record.id == entry.id,
                  stored.record.accountID == accountID,
                  stored.record.decidedAt == entry.decidedAt,
                  stored.record.instrumentCode == entry.instrumentCode,
                  digest(try encode(stored.record)) == stored.recordDigest else {
                throw FAdvisorPersistenceError.corruptDocument("memory record/index mismatch")
            }
            try stored.record.validate(now: now)
            records.append(stored.record)
        }
        return try FAdvisorDecisionMemoryProjection(records: records, accountID: accountID,
                                                    scope: scope, asOf: asOf,
                                                    validatedAt: now,
                                                    maximumEntries: maximumEntries)
    }

    private func buildGeneration(archive: FDecisionMemoryArchive,
                                 plan: FDecisionMemoryMigrationPlan,
                                 generationID: String,
                                 staging: URL) throws -> FMemorySegmentManifest {
        var references: [FMemorySegmentIndexReference] = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let grouped = Dictionary(grouping: archive.records) { record in
            let components = calendar.dateComponents([.year, .month], from: record.decidedAt)
            return "\(record.accountID.uuidString.lowercased())/\(String(format: "%04d-%02d", components.year!, components.month!))"
        }
        guard grouped.count == plan.shards.count else {
            throw FAdvisorPersistenceError.corruptDocument("migration shard count mismatch")
        }
        for shard in plan.shards {
            guard let records = grouped[shard.stableKey]?.sorted(by: recordOrder) else {
                throw FAdvisorPersistenceError.corruptDocument("migration shard missing")
            }
            guard records.map(\.id) == shard.recordIDs else {
                throw FAdvisorPersistenceError.corruptDocument("migration shard IDs mismatch")
            }
            var indexEntries: [FMemorySegmentIndexEntry] = []
            for record in records {
                let recordDigest = digest(try encode(record))
                let relativePath = "records/\(record.accountID.uuidString.lowercased())/\(record.id.uuidString.lowercased()).json"
                let envelope = FMemorySegmentRecordFile(schemaVersion: 1,
                                                        record: record,
                                                        recordDigest: recordDigest)
                let recordFileBytes = try encoder.encode(envelope)
                try writeVerified(recordFileBytes,
                                  to: safeURL(relativePath, base: staging))
                try faultInjector?(.afterRecordWrite)
                indexEntries.append(FMemorySegmentIndexEntry(id: record.id,
                                                             decidedAt: record.decidedAt,
                                                             instrumentCode: record.instrumentCode,
                                                             relativePath: relativePath,
                                                             recordFileDigest: digest(recordFileBytes)))
            }
            let indexPath = "indexes/\(shard.stableKey).json"
            let index = FMemorySegmentIndex(schemaVersion: 1, accountID: shard.accountID,
                                            year: shard.year, month: shard.month,
                                            entries: indexEntries)
            let indexBytes = try encoder.encode(index)
            try writeVerified(indexBytes, to: safeURL(indexPath, base: staging))
            try faultInjector?(.afterIndexWrite)
            references.append(FMemorySegmentIndexReference(accountID: shard.accountID,
                                                           year: shard.year, month: shard.month,
                                                           relativePath: indexPath,
                                                           indexDigest: digest(indexBytes)))
        }
        let material = FMemorySegmentManifestMaterial(schemaVersion: 1,
                                                      generationID: generationID,
                                                      sourceDigest: plan.sourceDigest,
                                                      recordCount: archive.records.count,
                                                      indexes: references.sorted {
                                                          "\($0.accountID.uuidString.lowercased())/\(String(format: "%04d-%02d", $0.year, $0.month))" <
                                                          "\($1.accountID.uuidString.lowercased())/\(String(format: "%04d-%02d", $1.year, $1.month))"
                                                      })
        let manifest = FMemorySegmentManifest(material: material,
                                              manifestDigest: digest(try encoder.encode(material)))
        try writeVerified(try encoder.encode(manifest),
                          to: staging.appendingPathComponent("manifest.json"))
        try faultInjector?(.afterManifestWrite)
        return manifest
    }

    private func verifyGeneration(at directory: URL,
                                  manifest: FMemorySegmentManifest) throws {
        guard digest(try encode(manifest.material)) == manifest.manifestDigest else {
            throw FAdvisorPersistenceError.corruptDocument("manifest digest mismatch")
        }
        var recordCount = 0
        var allRecordIDs = Set<UUID>()
        var allIndexKeys = Set<String>()
        for reference in manifest.material.indexes {
            let indexKey = "\(reference.accountID.uuidString.lowercased())/\(reference.year)-\(reference.month)"
            guard allIndexKeys.insert(indexKey).inserted,
                  (1...12).contains(reference.month) else {
                throw FAdvisorPersistenceError.corruptDocument("duplicate or invalid memory index reference")
            }
            let indexBytes = try Data(contentsOf: safeURL(reference.relativePath, base: directory))
            guard digest(indexBytes) == reference.indexDigest else {
                throw FAdvisorPersistenceError.corruptDocument("index digest mismatch")
            }
            let index = try JSONDecoder().decode(FMemorySegmentIndex.self, from: indexBytes)
            guard index.schemaVersion == 1, index.accountID == reference.accountID,
                  index.year == reference.year, index.month == reference.month else {
                throw FAdvisorPersistenceError.corruptDocument("index identity mismatch")
            }
            var previousEntry: FMemorySegmentIndexEntry?
            let nextMonthStart = reference.month == 12
                ? monthStart(year: reference.year + 1, month: 1)
                : monthStart(year: reference.year, month: reference.month + 1)
            for entry in index.entries {
                guard allRecordIDs.insert(entry.id).inserted,
                      entry.decidedAt >= monthStart(year: reference.year, month: reference.month),
                      entry.decidedAt < nextMonthStart else {
                    throw FAdvisorPersistenceError.corruptDocument("duplicate or misdated memory index entry")
                }
                if let previousEntry, !entryOrder(previousEntry, entry) {
                    throw FAdvisorPersistenceError.corruptDocument("non-canonical memory index order")
                }
                previousEntry = entry
                let bytes = try Data(contentsOf: safeURL(entry.relativePath, base: directory))
                guard digest(bytes) == entry.recordFileDigest else {
                    throw FAdvisorPersistenceError.corruptDocument("record file digest mismatch")
                }
                let stored = try JSONDecoder().decode(FMemorySegmentRecordFile.self, from: bytes)
                guard stored.schemaVersion == 1, stored.record.id == entry.id,
                      stored.record.accountID == reference.accountID,
                      stored.record.decidedAt == entry.decidedAt,
                      stored.record.instrumentCode == entry.instrumentCode,
                      digest(try encode(stored.record)) == stored.recordDigest else {
                    throw FAdvisorPersistenceError.corruptDocument("record/index identity mismatch")
                }
                recordCount += 1
            }
        }
        guard recordCount == manifest.material.recordCount else {
            throw FAdvisorPersistenceError.corruptDocument("manifest record count mismatch")
        }
    }

    private func loadManifest(generationID: String,
                              expectedDigest: String) throws -> FMemorySegmentManifest {
        try loadManifest(at: generationDirectory(generationID), generationID: generationID,
                         expectedDigest: expectedDigest)
    }

    private func loadManifest(at directory: URL, generationID: String,
                              expectedDigest: String) throws -> FMemorySegmentManifest {
        let url = directory.appendingPathComponent("manifest.json")
        let bytes = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(FMemorySegmentManifest.self, from: bytes)
        guard manifest.material.schemaVersion == 1,
              manifest.material.generationID == generationID,
              manifest.manifestDigest == expectedDigest,
              digest(try encode(manifest.material)) == manifest.manifestDigest else {
            throw FAdvisorPersistenceError.corruptDocument("invalid generation manifest")
        }
        return manifest
    }

    private func loadBackup(at directory: URL) throws
        -> (FMemoryBackupDocument, FMemorySegmentManifest) {
        let documentBytes = try Data(contentsOf: directory.appendingPathComponent("BACKUP.json"))
        let document = try JSONDecoder().decode(FMemoryBackupDocument.self, from: documentBytes)
        guard document.material.schemaVersion == 1,
              digest(try encode(document.material)) == document.backupDigest else {
            throw FAdvisorPersistenceError.corruptDocument("backup manifest digest mismatch")
        }
        let pointerBytes = try Data(contentsOf: directory.appendingPathComponent("CURRENT.json"))
        let pointer = try JSONDecoder().decode(FMemorySegmentCurrent.self, from: pointerBytes)
        try validate(pointer)
        guard pointer == document.material.current else {
            throw FAdvisorPersistenceError.corruptDocument("backup CURRENT mismatch")
        }
        let generation = directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(pointer.generationID, isDirectory: true)
        let manifest = try loadManifest(at: generation, generationID: pointer.generationID,
                                        expectedDigest: pointer.manifestDigest)
        try verifyGeneration(at: generation, manifest: manifest)
        return (document, manifest)
    }

    private func commit(_ pointer: FMemorySegmentCurrent,
                        expectedPriorGenerationID: String?) throws {
        try faultInjector?(.beforeCurrentCommit)
        let latest = try readCurrent()
        guard latest?.generationID == expectedPriorGenerationID else {
            throw FAdvisorPersistenceError.concurrentModification(
                expected: expectedPriorGenerationID, actual: latest?.generationID)
        }
        let manifest = try loadManifest(generationID: pointer.generationID,
                                        expectedDigest: pointer.manifestDigest)
        try verifyGeneration(at: generationDirectory(pointer.generationID), manifest: manifest)
        let previousBytes = try? Data(contentsOf: currentURL)
        if let previousBytes { try atomicDurableWrite(previousBytes, to: previousURL) }
        let pointerBytes = try encode(pointer)
        do {
            try atomicDurableWrite(pointerBytes, to: currentURL)
            try faultInjector?(.afterCurrentWrite)
            guard try readCurrent() == pointer else {
                throw FAdvisorPersistenceError.corruptDocument("CURRENT readback mismatch")
            }
        } catch {
            guard let installedBytes = try? Data(contentsOf: currentURL),
                  installedBytes == pointerBytes else { throw error }
            do {
                if let previousBytes {
                    try atomicDurableWrite(previousBytes, to: currentURL)
                } else {
                    try FileManager.default.removeItem(at: currentURL)
                    try synchronizeDirectory(root)
                }
            } catch {
                throw FAdvisorPersistenceError.rollbackFailed(String(describing: error))
            }
            throw error
        }
    }

    private func readCurrent() throws -> FMemorySegmentCurrent? {
        guard FileManager.default.fileExists(atPath: currentURL.path) else { return nil }
        let pointer = try JSONDecoder().decode(FMemorySegmentCurrent.self,
                                              from: Data(contentsOf: currentURL))
        try validate(pointer)
        _ = try loadManifest(generationID: pointer.generationID,
                             expectedDigest: pointer.manifestDigest)
        return pointer
    }

    private func validate(_ pointer: FMemorySegmentCurrent) throws {
        let generationDigest = String(pointer.generationID.dropFirst(3))
        guard pointer.schemaVersion == 1, pointer.generationID.hasPrefix("v1-"),
              generationDigest.count == 64,
              generationDigest.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "0123456789abcdef").contains($0)
              }) else {
            throw FAdvisorPersistenceError.corruptDocument("invalid CURRENT pointer")
        }
    }

    private func generationDirectory(_ id: String) -> URL {
        generations.appendingPathComponent(id, isDirectory: true)
    }

    private func monthStart(year: Int, month: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = 1
        return components.date ?? .distantFuture
    }

    private func safeURL(_ relativePath: String, generationID: String) throws -> URL {
        try safeURL(relativePath, base: generationDirectory(generationID))
    }

    private func safeURL(_ relativePath: String, base: URL) throws -> URL {
        guard !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains(".."),
              !relativePath.split(separator: "/").contains(".") else {
            throw FAdvisorPersistenceError.corruptDocument("unsafe segmented archive path")
        }
        return relativePath.split(separator: "/").reduce(base) {
            $0.appendingPathComponent(String($1))
        }
    }

    private func recordOrder(_ lhs: FDecisionMemory, _ rhs: FDecisionMemory) -> Bool {
        if lhs.decidedAt != rhs.decidedAt { return lhs.decidedAt < rhs.decidedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func entryOrder(_ lhs: FMemorySegmentIndexEntry,
                            _ rhs: FMemorySegmentIndexEntry) -> Bool {
        if lhs.decidedAt != rhs.decidedAt { return lhs.decidedAt < rhs.decidedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private func writeVerified(_ bytes: Data, to url: URL) throws {
        try atomicDurableWrite(bytes, to: url)
        guard try Data(contentsOf: url) == bytes else {
            throw FAdvisorPersistenceError.corruptDocument("segment write readback mismatch")
        }
    }

    private func atomicDurableWrite(_ bytes: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
        try synchronizeDirectory(url.deletingLastPathComponent())
    }

    private func synchronizeDirectory(_ url: URL) throws {
        let descriptor: Int32 = url.path.withCString { path in
            #if canImport(Darwin)
            return Darwin.open(path, O_RDONLY)
            #elseif canImport(Glibc)
            return Glibc.open(path, O_RDONLY)
            #else
            return -1
            #endif
        }
        guard descriptor >= 0 else {
            throw FAdvisorPersistenceError.corruptDocument("cannot open archive directory for sync")
        }
        defer {
            #if canImport(Darwin)
            _ = Darwin.close(descriptor)
            #elseif canImport(Glibc)
            _ = Glibc.close(descriptor)
            #endif
        }
        #if canImport(Darwin)
        let result = Darwin.fsync(descriptor)
        #elseif canImport(Glibc)
        let result = Glibc.fsync(descriptor)
        #else
        let result: Int32 = -1
        #endif
        guard result == 0 else {
            throw FAdvisorPersistenceError.corruptDocument("archive directory sync failed")
        }
    }

    private func synchronizeDirectoryTree(_ directory: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            throw FAdvisorPersistenceError.corruptDocument("cannot enumerate generation directories")
        }
        var directories = [directory]
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                directories.append(url)
            }
        }
        for url in directories.sorted(by: { $0.pathComponents.count > $1.pathComponents.count }) {
            try synchronizeDirectory(url)
        }
    }
}
