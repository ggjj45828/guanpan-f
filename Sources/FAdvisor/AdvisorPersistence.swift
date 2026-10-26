import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import CryptoKit

public enum FAdvisorPersistenceError: Error, Equatable, Sendable {
    case corruptDocument(String)
    case unsupportedArchiveVersion(Int)
    case concurrentModification(expected: String?, actual: String?)
    case duplicateRecord(UUID)
    case invalidBackupDestination
    case documentMissing
    case corruptPrimaryRequiresExplicitRestore
    case rollbackFailed(String)
}

public struct FDecisionMemoryArchive: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public private(set) var records: [FDecisionMemory]

    fileprivate init(records: [FDecisionMemory], schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.records = records
    }

    fileprivate mutating func append(_ memory: FDecisionMemory) {
        records.append(memory)
        records.sort {
            if $0.decidedAt != $1.decidedAt { return $0.decidedAt < $1.decidedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    fileprivate func validate(now: Date) throws {
        guard schemaVersion == 1, Set(records.map(\.id)).count == records.count else {
            throw FAdvisorPersistenceError.corruptDocument("invalid memory archive")
        }
        for record in records { try record.validate(now: now) }
    }
}

public struct FDecisionContextArchive: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public private(set) var contexts: [FDecisionContext]

    fileprivate init(contexts: [FDecisionContext] = [], schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.contexts = contexts
    }

    fileprivate mutating func append(_ context: FDecisionContext) {
        contexts.append(context)
        contexts.sort {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    fileprivate func validate(now: Date) throws {
        guard schemaVersion == 1, Set(contexts.map(\.id)).count == contexts.count else {
            throw FAdvisorPersistenceError.corruptDocument("invalid context archive")
        }
        for context in contexts { try context.validate(now: now) }
    }
}

/// Decision memory, profile, and context use separate actors and separate files.
/// None of these stores imports or exposes a Ledger writer capability.
public actor FDecisionMemoryStore {
    private let storage: FAtomicAdvisorDocumentStore<FDecisionMemoryArchive>
    private let segmentedStorage: FSegmentedDecisionMemoryStore
    private let lockFileURL: URL
    private var operationInProgress = false
    private var operationWaiters: [CheckedContinuation<Void, Never>] = []
    private var processLockDescriptor: Int32?

    public init(directory: URL) {
        let directory = directory.standardizedFileURL
        storage = FAtomicAdvisorDocumentStore(
            fileURL: directory.appendingPathComponent("decision-memory-v1.json"),
            recoveryURL: directory.appendingPathComponent("decision-memory-v1.recovery.json"))
        segmentedStorage = FSegmentedDecisionMemoryStore(
            directory: directory.appendingPathComponent("decision-memory-segmented", isDirectory: true))
        lockFileURL = directory.appendingPathComponent("decision-memory.lock")
    }

    public func load(now: Date = Date()) async throws -> FDecisionMemoryArchive? {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await storage.load(now: now)?.payload
    }

    /// Returns only a bounded, point-in-time projection. A validated segmented
    /// generation serves indexed reads; without one, the verified v1 archive
    /// remains the compatibility and recovery path.
    public func recentProjection(accountID: UUID, scope: FAdvisorEntryScope,
                                 asOf: Date, maximumEntries: Int = 5,
                                 now: Date = Date()) async throws
        -> FAdvisorDecisionMemoryProjection? {
        guard asOf <= now else { throw FAdvisorEntryError.invalidProjectionTime }
        guard (1...5).contains(maximumEntries) else {
            throw FAdvisorEntryError.invalidMemoryProjectionLimit
        }
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        if try await segmentedStorage.currentSourceDigest() != nil {
            return try await segmentedStorage.recentProjection(accountID: accountID, scope: scope,
                                                               asOf: asOf, maximumEntries: maximumEntries,
                                                               now: now)
        }
        let legacy = try await storage.load(now: now)
        guard let archive = legacy?.payload else { return nil }
        return try FAdvisorDecisionMemoryProjection(records: archive.records,
                                                    accountID: accountID, scope: scope,
                                                    asOf: asOf, validatedAt: now,
                                                    maximumEntries: maximumEntries)
    }

    public func currentDigest(now: Date = Date()) async throws -> String? {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await storage.load(now: now)?.digest
    }

    /// Validates the v1 archive and returns a deterministic migration report.
    /// This operation is read-only: it creates no target files and cannot
    /// change the current archive or the real Ledger.
    public func migrationDryRun(now: Date = Date()) async throws -> FDecisionMemoryMigrationPlan? {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        guard let stored = try await storage.loadForMigrationInspection(now: now) else { return nil }
        return try FDecisionMemoryMigrationPlan(archive: stored.payload,
                                                sourceDigest: stored.digest, now: now)
    }

    /// Copies the currently authenticated v1 archive into an immutable
    /// segmented generation. The legacy source remains intact for rollback.
    @discardableResult
    public func materializeSegmentedArchive(using plan: FDecisionMemoryMigrationPlan,
                                             expectedPriorGenerationID: String? = nil,
                                             now: Date = Date()) async throws
        -> FDecisionMemoryMigrationReceipt {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        guard let source = try await storage.loadForMigrationInspection(now: now) else {
            throw FAdvisorPersistenceError.documentMissing
        }
        guard source.digest == plan.sourceDigest else {
            throw FAdvisorPersistenceError.concurrentModification(expected: plan.sourceDigest,
                                                                   actual: source.digest)
        }
        let validated = try FDecisionMemoryMigrationPlan(archive: source.payload,
                                                         sourceDigest: source.digest,
                                                         now: now)
        guard validated == plan, validated.isEligible else {
            throw FAdvisorPersistenceError.corruptDocument("dry-run plan is stale or ineligible")
        }
        return try await segmentedStorage.install(archive: source.payload, plan: plan,
                                                  expectedSourceDigest: source.digest,
                                                  expectedPriorGenerationID: expectedPriorGenerationID,
                                                  now: now)
    }

    @discardableResult
    public func createSegmentedBackup(at destination: URL) async throws
        -> FDecisionMemoryBackupReceipt {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await segmentedStorage.createBackup(at: destination)
    }

    @discardableResult
    public func restoreSegmentedBackup(from source: URL,
                                       expectedPriorGenerationID: String?,
                                       now: Date = Date()) async throws
        -> FDecisionMemoryRestoreReceipt {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        guard let legacy = try await storage.load(now: now) else {
            throw FAdvisorPersistenceError.documentMissing
        }
        let backupSourceDigest = try await segmentedStorage.backupSourceDigest(at: source)
        guard backupSourceDigest == legacy.digest else {
            throw FAdvisorPersistenceError.concurrentModification(expected: backupSourceDigest,
                                                                   actual: legacy.digest)
        }
        return try await segmentedStorage.restoreBackup(from: source,
                                                        expectedPriorGenerationID: expectedPriorGenerationID)
    }

    @discardableResult
    public func append(_ memory: FDecisionMemory, expectedPriorDigest: String?,
                       now: Date = Date()) async throws -> String {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try memory.validate(now: now)
        let existing = try await storage.load(now: now)
        var archive = existing?.payload ?? FDecisionMemoryArchive(records: [])
        if let sameID = archive.records.first(where: { $0.id == memory.id }) {
            if sameID == memory, existing?.digest == expectedPriorDigest {
                return existing?.digest ?? ""
            }
            throw FAdvisorPersistenceError.duplicateRecord(memory.id)
        }
        archive.append(memory)
        try await segmentedStorage.invalidateCurrent()
        return try await storage.save(archive, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    @discardableResult
    public func createBackup(at destination: URL, now: Date = Date()) async throws -> String {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await storage.createBackup(at: destination, now: now)
    }

    public func recoveryCandidate(now: Date = Date()) async throws -> FDecisionMemoryArchive? {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await storage.recoveryCandidate(now: now)
    }

    @discardableResult
    public func restoreBackup(from source: URL, expectedPriorDigest: String?,
                              now: Date = Date()) async throws -> String {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await segmentedStorage.invalidateCurrent()
        try await storage.restoreBackup(from: source, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    @discardableResult
    public func restoreRecoveryCandidate(expectedPriorDigest: String?,
                                         replaceCorruptPrimary: Bool = false,
                                         now: Date = Date()) async throws -> String {
        try await acquireExclusiveOperation()
        defer { releaseExclusiveOperation() }
        try await segmentedStorage.invalidateCurrent()
        try await storage.restoreRecoveryCandidate(expectedPriorDigest: expectedPriorDigest,
                                                   replaceCorruptPrimary: replaceCorruptPrimary, now: now)
    }

    private func acquireExclusiveOperation() async throws {
        if !operationInProgress {
            operationInProgress = true
        } else {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                operationWaiters.append(continuation)
            }
        }
        do {
            processLockDescriptor = try await acquireProcessLock()
        } catch {
            releaseExclusiveOperation()
            throw error
        }
    }

    private func releaseExclusiveOperation() {
        if let descriptor = processLockDescriptor {
            #if canImport(Darwin)
            var lock = Darwin.flock()
            lock.l_type = Int16(F_UNLCK)
            lock.l_whence = Int16(SEEK_SET)
            lock.l_start = 0
            lock.l_len = 0
            _ = Darwin.fcntl(descriptor, F_SETLK, &lock)
            _ = Darwin.close(descriptor)
            #elseif canImport(Glibc)
            _ = Glibc.flock(descriptor, LOCK_UN)
            _ = Glibc.close(descriptor)
            #endif
            processLockDescriptor = nil
        }
        if operationWaiters.isEmpty {
            operationInProgress = false
        } else {
            operationWaiters.removeFirst().resume()
        }
    }

    private func acquireProcessLock() async throws -> Int32 {
        try FileManager.default.createDirectory(at: lockFileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let descriptor: Int32 = lockFileURL.path.withCString { path in
            #if canImport(Darwin)
            return Darwin.open(path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
            #elseif canImport(Glibc)
            return Glibc.open(path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
            #else
            return -1
            #endif
        }
        guard descriptor >= 0 else {
            throw FAdvisorPersistenceError.corruptDocument("cannot open Memory process lock")
        }
        while true {
            let result: Int32
            #if canImport(Darwin)
            var lock = Darwin.flock()
            lock.l_type = Int16(F_WRLCK)
            lock.l_whence = Int16(SEEK_SET)
            lock.l_start = 0
            lock.l_len = 0
            result = Darwin.fcntl(descriptor, F_SETLK, &lock)
            #elseif canImport(Glibc)
            result = Glibc.flock(descriptor, LOCK_EX | LOCK_NB)
            #else
            result = -1
            #endif
            if result == 0 { return descriptor }
            let isBusy: Bool
            #if canImport(Darwin)
            isBusy = errno == EWOULDBLOCK || errno == EAGAIN
            #elseif canImport(Glibc)
            isBusy = errno == EWOULDBLOCK || errno == EAGAIN
            #else
            isBusy = false
            #endif
            guard isBusy else {
                #if canImport(Darwin)
                _ = Darwin.close(descriptor)
                #elseif canImport(Glibc)
                _ = Glibc.close(descriptor)
                #endif
                throw FAdvisorPersistenceError.corruptDocument("cannot acquire Memory process lock")
            }
            do { try await Task.sleep(nanoseconds: 10_000_000) }
            catch {
                #if canImport(Darwin)
                _ = Darwin.close(descriptor)
                #elseif canImport(Glibc)
                _ = Glibc.close(descriptor)
                #endif
                throw error
            }
        }
    }
}

public actor FInvestorProfileStore {
    private let storage: FAtomicAdvisorDocumentStore<FInvestorProfile>

    public init(directory: URL) {
        storage = FAtomicAdvisorDocumentStore(
            fileURL: directory.appendingPathComponent("investor-profile-v1.json"),
            recoveryURL: directory.appendingPathComponent("investor-profile-v1.recovery.json"))
    }

    public func load(now: Date = Date()) async throws -> FInvestorProfile? {
        try await storage.load(now: now)?.payload
    }

    public func currentDigest(now: Date = Date()) async throws -> String? {
        try await storage.load(now: now)?.digest
    }

    @discardableResult
    public func save(_ profile: FInvestorProfile, expectedPriorDigest: String?,
                     now: Date = Date()) async throws -> String {
        try profile.validate(now: now)
        return try await storage.save(profile, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    @discardableResult
    public func createBackup(at destination: URL, now: Date = Date()) async throws -> String {
        try await storage.createBackup(at: destination, now: now)
    }

    public func recoveryCandidate(now: Date = Date()) async throws -> FInvestorProfile? {
        try await storage.recoveryCandidate(now: now)
    }

    @discardableResult
    public func restoreBackup(from source: URL, expectedPriorDigest: String?,
                              now: Date = Date()) async throws -> String {
        try await storage.restoreBackup(from: source, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    @discardableResult
    public func restoreRecoveryCandidate(expectedPriorDigest: String?,
                                         replaceCorruptPrimary: Bool = false,
                                         now: Date = Date()) async throws -> String {
        try await storage.restoreRecoveryCandidate(expectedPriorDigest: expectedPriorDigest,
                                                   replaceCorruptPrimary: replaceCorruptPrimary, now: now)
    }
}

public actor FDecisionContextStore {
    private let storage: FAtomicAdvisorDocumentStore<FDecisionContextArchive>

    public init(directory: URL) {
        storage = FAtomicAdvisorDocumentStore(
            fileURL: directory.appendingPathComponent("decision-context-v1.json"),
            recoveryURL: directory.appendingPathComponent("decision-context-v1.recovery.json"))
    }

    public func load(now: Date = Date()) async throws -> FDecisionContextArchive? {
        try await storage.load(now: now)?.payload
    }

    public func currentDigest(now: Date = Date()) async throws -> String? {
        try await storage.load(now: now)?.digest
    }

    @discardableResult
    public func append(_ context: FDecisionContext, expectedPriorDigest: String?,
                       now: Date = Date()) async throws -> String {
        try context.validate(now: now)
        let existing = try await storage.load(now: now)
        var archive = existing?.payload ?? FDecisionContextArchive()
        if let sameID = archive.contexts.first(where: { $0.id == context.id }) {
            if sameID == context, existing?.digest == expectedPriorDigest {
                return existing?.digest ?? ""
            }
            throw FAdvisorPersistenceError.duplicateRecord(context.id)
        }
        archive.append(context)
        return try await storage.save(archive, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    @discardableResult
    public func createBackup(at destination: URL, now: Date = Date()) async throws -> String {
        try await storage.createBackup(at: destination, now: now)
    }

    public func recoveryCandidate(now: Date = Date()) async throws -> FDecisionContextArchive? {
        try await storage.recoveryCandidate(now: now)
    }

    @discardableResult
    public func restoreBackup(from source: URL, expectedPriorDigest: String?,
                              now: Date = Date()) async throws -> String {
        try await storage.restoreBackup(from: source, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    @discardableResult
    public func restoreRecoveryCandidate(expectedPriorDigest: String?,
                                         replaceCorruptPrimary: Bool = false,
                                         now: Date = Date()) async throws -> String {
        try await storage.restoreRecoveryCandidate(expectedPriorDigest: expectedPriorDigest,
                                                   replaceCorruptPrimary: replaceCorruptPrimary, now: now)
    }
}

private protocol FAdvisorPersistable: Codable, Equatable, Sendable {
    func validate(now: Date) throws
}

extension FDecisionMemoryArchive: FAdvisorPersistable {}
extension FDecisionContextArchive: FAdvisorPersistable {}
extension FInvestorProfile: FAdvisorPersistable {}

private struct FAdvisorStoredValue<Payload: FAdvisorPersistable>: Sendable {
    let payload: Payload
    let digest: String
}

private actor FAtomicAdvisorDocumentStore<Payload: FAdvisorPersistable> {
    private struct Envelope: Codable, Equatable {
        let formatVersion: Int
        let archivedAt: Date
        let payload: Payload
        let contentDigest: String
    }

    private struct DigestPayload: Codable {
        let formatVersion: Int
        let archivedAt: Date
        let payload: Payload
    }

    private let fileURL: URL
    private let recoveryURL: URL
    private static var formatVersion: Int { 1 }

    init(fileURL: URL, recoveryURL: URL) {
        self.fileURL = fileURL
        self.recoveryURL = recoveryURL
    }

    func load(now: Date) throws -> FAdvisorStoredValue<Payload>? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let envelope = try decode(Data(contentsOf: fileURL), now: now)
        return FAdvisorStoredValue(payload: envelope.payload, digest: envelope.contentDigest)
    }

    /// Migration inspection still authenticates the v1 envelope, but defers
    /// payload invariants to the read-only planner so it can report violations.
    func loadForMigrationInspection(now: Date) throws -> FAdvisorStoredValue<Payload>? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let envelope = try decode(Data(contentsOf: fileURL), now: now,
                                  validatePayload: false)
        return FAdvisorStoredValue(payload: envelope.payload, digest: envelope.contentDigest)
    }

    func save(_ payload: Payload, expectedPriorDigest: String?, now: Date) throws -> String {
        try payload.validate(now: now)
        let priorBytes: Data? = FileManager.default.fileExists(atPath: fileURL.path)
            ? try Data(contentsOf: fileURL) : nil
        let existing = try priorBytes.map { try decode($0, now: now) }
        let actualDigest = existing?.contentDigest
        guard actualDigest == expectedPriorDigest else {
            throw FAdvisorPersistenceError.concurrentModification(expected: expectedPriorDigest,
                                                                    actual: actualDigest)
        }
        if let priorBytes {
            try atomicWrite(priorBytes, to: recoveryURL)
            _ = try decode(Data(contentsOf: recoveryURL), now: now)
        }
        let envelope = try makeEnvelope(payload, archivedAt: now)
        do {
            try atomicWrite(try encode(envelope), to: fileURL)
            let persisted = try decode(Data(contentsOf: fileURL), now: now)
            guard persisted == envelope else {
                throw FAdvisorPersistenceError.corruptDocument("post-write mismatch")
            }
            return persisted.contentDigest
        } catch {
            do {
                if let priorBytes { try atomicWrite(priorBytes, to: fileURL) }
                else if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            } catch {
                throw FAdvisorPersistenceError.rollbackFailed(String(describing: error))
            }
            throw error
        }
    }

    func createBackup(at destination: URL, now: Date) throws -> String {
        guard destination.standardizedFileURL != fileURL.standardizedFileURL,
              destination.standardizedFileURL != recoveryURL.standardizedFileURL else {
            throw FAdvisorPersistenceError.invalidBackupDestination
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FAdvisorPersistenceError.documentMissing
        }
        let bytes = try Data(contentsOf: fileURL)
        let envelope = try decode(bytes, now: now)
        try atomicWrite(bytes, to: destination)
        guard try decode(Data(contentsOf: destination), now: now) == envelope else {
            throw FAdvisorPersistenceError.corruptDocument("backup readback mismatch")
        }
        return envelope.contentDigest
    }

    func recoveryCandidate(now: Date) throws -> Payload? {
        guard FileManager.default.fileExists(atPath: recoveryURL.path) else { return nil }
        return try decode(Data(contentsOf: recoveryURL), now: now).payload
    }

    func restoreBackup(from source: URL, expectedPriorDigest: String?, now: Date) throws -> String {
        let envelope = try decode(Data(contentsOf: source), now: now)
        return try save(envelope.payload, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    func restoreRecoveryCandidate(expectedPriorDigest: String?, replaceCorruptPrimary: Bool,
                                  now: Date) throws -> String {
        guard FileManager.default.fileExists(atPath: recoveryURL.path) else {
            throw FAdvisorPersistenceError.documentMissing
        }
        let envelope = try decode(Data(contentsOf: recoveryURL), now: now)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return try save(envelope.payload, expectedPriorDigest: expectedPriorDigest, now: now)
        }
        let primaryBytes = try Data(contentsOf: fileURL)
        do {
            let current = try decode(primaryBytes, now: now)
            guard current.contentDigest == expectedPriorDigest else {
                throw FAdvisorPersistenceError.concurrentModification(
                    expected: expectedPriorDigest, actual: current.contentDigest)
            }
            return try save(envelope.payload, expectedPriorDigest: expectedPriorDigest, now: now)
        } catch let error as FAdvisorPersistenceError {
            if case .concurrentModification = error { throw error }
            guard replaceCorruptPrimary, expectedPriorDigest == nil else {
                throw FAdvisorPersistenceError.corruptPrimaryRequiresExplicitRestore
            }
            let forensicURL = fileURL.appendingPathExtension("corrupt-\(UUID().uuidString)")
            try atomicWrite(primaryBytes, to: forensicURL)
            do {
                try atomicWrite(try encode(envelope), to: fileURL)
                let restored = try decode(Data(contentsOf: fileURL), now: now)
                guard restored == envelope else {
                    throw FAdvisorPersistenceError.corruptDocument("recovery readback mismatch")
                }
                return restored.contentDigest
            } catch {
                do { try atomicWrite(primaryBytes, to: fileURL) }
                catch { throw FAdvisorPersistenceError.rollbackFailed(String(describing: error)) }
                throw error
            }
        }
    }

    private func makeEnvelope(_ payload: Payload, archivedAt: Date) throws -> Envelope {
        let material = DigestPayload(formatVersion: Self.formatVersion,
                                     archivedAt: archivedAt, payload: payload)
        return Envelope(formatVersion: Self.formatVersion, archivedAt: archivedAt,
                        payload: payload, contentDigest: try digest(material))
    }

    private func decode(_ bytes: Data, now: Date,
                        validatePayload: Bool = true) throws -> Envelope {
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: bytes) }
        catch { throw FAdvisorPersistenceError.corruptDocument("decode failed") }
        guard envelope.formatVersion == Self.formatVersion else {
            throw FAdvisorPersistenceError.unsupportedArchiveVersion(envelope.formatVersion)
        }
        guard envelope.archivedAt.timeIntervalSince1970.isFinite,
              envelope.archivedAt <= now.addingTimeInterval(300) else {
            throw FAdvisorPersistenceError.corruptDocument("invalid archive timestamp")
        }
        if validatePayload { try envelope.payload.validate(now: now) }
        let material = DigestPayload(formatVersion: envelope.formatVersion,
                                     archivedAt: envelope.archivedAt, payload: envelope.payload)
        guard try digest(material) == envelope.contentDigest else {
            throw FAdvisorPersistenceError.corruptDocument("digest mismatch")
        }
        return envelope
    }

    private func encode(_ envelope: Envelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do { return try encoder.encode(envelope) }
        catch { throw FAdvisorPersistenceError.corruptDocument("encode failed") }
    }

    private func digest(_ material: DigestPayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hash(data: try encoder.encode(material))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }
}
