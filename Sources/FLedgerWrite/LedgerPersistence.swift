import Foundation
@_spi(LedgerStorage) import FCore
import CryptoKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Darwin record locks coordinate processes; the additional local mutex is required
/// because POSIX record locks do not conflict between file descriptors in one process.
private final class FLedgerInProcessLock: @unchecked Sendable {
    static let shared = FLedgerInProcessLock()
    let lock = NSRecursiveLock()
}

/// Persistence failures are explicit so callers can keep the last published account value
/// when disk I/O, validation, or optimistic concurrency checks fail.
public enum FLedgerPersistenceError: Error, Equatable, Sendable {
    case primaryFileMissing
    case corruptArchive(String)
    case unsupportedArchiveVersion(Int)
    case accountIdentityMismatch
    case concurrentModification(expected: String?, actual: String?)
    case rollbackFailed(String)
    case invalidBackupDestination
    case invalidMigrationSource
    case invalidMigrationIdentity
    case duplicateMigration(String)
    case targetAlreadyInitialized
    case invalidInitialLedger
    case invalidRecoveryDestination
    case storageFailure(String)
}

public enum FLegacyLedgerSourceKind: String, Codable, Equatable, Sendable {
    case A
    case B
}

/// Immutable source evidence and idempotency receipt for a user-confirmed initial migration.
/// The source bytes travel inside the same atomic F archive as the imported opening snapshot.
public struct FLedgerMigrationReceipt: Codable, Equatable, Sendable, Identifiable {
    public var id: String { idempotencyKey }
    public let sourceKind: FLegacyLedgerSourceKind
    public let legacyAccountID: String?
    public let sourceSHA256: String
    public let sourceByteLength: Int
    public let idempotencyKey: String
    public let appliedAt: Date
    public let sourceBytes: Data

    public init(sourceKind: FLegacyLedgerSourceKind, legacyAccountID: String?,
                sourceBytes: Data, appliedAt: Date) throws {
        let sourceHash = Self.sha256(sourceBytes)
        self.sourceKind = sourceKind
        self.legacyAccountID = legacyAccountID
        self.sourceSHA256 = sourceHash
        self.sourceByteLength = sourceBytes.count
        self.idempotencyKey = Self.makeIdempotencyKey(
            sourceKind: sourceKind, legacyAccountID: legacyAccountID, sourceSHA256: sourceHash)
        self.appliedAt = appliedAt
        self.sourceBytes = sourceBytes
    }

    public func validate(now: Date = Date()) throws {
        guard sourceByteLength == sourceBytes.count,
              sourceSHA256 == Self.sha256(sourceBytes),
              sourceSHA256.count == 64,
              sourceSHA256.allSatisfy({ $0.isHexDigit }),
              idempotencyKey == Self.makeIdempotencyKey(
                sourceKind: sourceKind, legacyAccountID: legacyAccountID, sourceSHA256: sourceSHA256),
              appliedAt.timeIntervalSince1970.isFinite,
              appliedAt <= now.addingTimeInterval(300) else {
            throw FLedgerPersistenceError.invalidMigrationSource
        }
    }

    public static func makeIdempotencyKey(sourceKind: FLegacyLedgerSourceKind,
                                          legacyAccountID: String?, sourceSHA256: String) -> String {
        let identity = legacyAccountID ?? "missing-id"
        let value = "guanpan-f-migration-v1:\(sourceKind.rawValue):\(identity):\(sourceSHA256)"
        return sha256(Data(value.utf8))
    }

    public static func targetAccountID(for idempotencyKey: String) throws -> UUID {
        guard isSHA256(idempotencyKey) else { throw FLedgerPersistenceError.invalidMigrationIdentity }
        let namespace = UUID(uuidString: "6ba7b811-9dad-11d1-80b4-00c04fd430c8")!
        return uuidV5(namespace: namespace, name: "guanpan-f:\(idempotencyKey)")
    }

    public static func targetPositionID(accountID: UUID, instrumentCode: String) -> UUID {
        uuidV5(namespace: accountID, name: instrumentCode)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy({ $0.isHexDigit })
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func uuidV5(namespace: UUID, name: String) -> UUID {
        var namespaceBytes = namespace.uuid
        var material = withUnsafeBytes(of: &namespaceBytes) { Data($0) }
        material.append(contentsOf: name.utf8)
        var bytes = Array(Insecure.SHA1.hash(data: material).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

/// A portable, checksummed archive for one real F account book.
/// It contains no candidate plans, AI output, quotes, or research data.
public struct FAccountBookArchive: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 2

    public let formatVersion: Int
    public let accountID: UUID
    public let schemaVersion: Int
    public let archivedAt: Date
    public let ledgerDigest: String
    public let archiveContentDigest: String
    public let migrationReceipts: [FLedgerMigrationReceipt]
    public let accountBook: FAccountBook

    private enum CodingKeys: String, CodingKey {
        case formatVersion, accountID, schemaVersion, archivedAt, ledgerDigest
        case archiveContentDigest, migrationReceipts, accountBook
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try values.decode(Int.self, forKey: .formatVersion)
        let decodedAccountID = try values.decode(UUID.self, forKey: .accountID)
        let decodedSchemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        let decodedArchivedAt = try values.decode(Date.self, forKey: .archivedAt)
        let decodedLedgerDigest = try values.decode(String.self, forKey: .ledgerDigest)
        let decodedArchiveDigest = try values.decode(String.self, forKey: .archiveContentDigest)
        let decodedBook = try values.decode(FAccountBook.self, forKey: .accountBook)

        switch decodedVersion {
        case 1:
            // v1 existed only as the prior F archive format. Verify its exact old
            // digest and ledger invariants before upgrading in memory to format v2.
            try decodedBook.validate(now: decodedArchivedAt)
            guard decodedAccountID == decodedBook.accountID,
                  decodedSchemaVersion == decodedBook.schemaVersion,
                  try decodedBook.ledgerStateDigest() == decodedLedgerDigest,
                  try Self.legacyV1Digest(decodedBook) == decodedArchiveDigest else {
                throw FLedgerPersistenceError.corruptArchive("invalid v1 archive")
            }
            let receipts: [FLedgerMigrationReceipt] = []
            formatVersion = Self.currentFormatVersion
            accountID = decodedAccountID
            schemaVersion = decodedSchemaVersion
            archivedAt = decodedArchivedAt
            ledgerDigest = decodedLedgerDigest
            migrationReceipts = receipts
            accountBook = decodedBook
            archiveContentDigest = try Self.digest(
                formatVersion: Self.currentFormatVersion, accountID: decodedAccountID,
                schemaVersion: decodedSchemaVersion, archivedAt: decodedArchivedAt,
                migrationReceipts: receipts, accountBook: decodedBook)
        case Self.currentFormatVersion:
            formatVersion = decodedVersion
            accountID = decodedAccountID
            schemaVersion = decodedSchemaVersion
            archivedAt = decodedArchivedAt
            ledgerDigest = decodedLedgerDigest
            archiveContentDigest = decodedArchiveDigest
            migrationReceipts = try values.decodeIfPresent([FLedgerMigrationReceipt].self,
                                                           forKey: .migrationReceipts) ?? []
            accountBook = decodedBook
        default:
            throw FLedgerPersistenceError.unsupportedArchiveVersion(decodedVersion)
        }
    }

    public init(accountBook: FAccountBook, migrationReceipts: [FLedgerMigrationReceipt] = [],
                archivedAt: Date = Date()) throws {
        try accountBook.validate(now: archivedAt)
        for receipt in migrationReceipts {
            try receipt.validate(now: archivedAt)
            guard receipt.appliedAt <= archivedAt else {
                throw FLedgerPersistenceError.invalidMigrationSource
            }
        }
        guard Set(migrationReceipts.map(\.idempotencyKey)).count == migrationReceipts.count else {
            throw FLedgerPersistenceError.corruptArchive("duplicate migration receipt")
        }
        self.formatVersion = Self.currentFormatVersion
        self.accountID = accountBook.accountID
        self.schemaVersion = accountBook.schemaVersion
        self.archivedAt = archivedAt
        self.ledgerDigest = try accountBook.ledgerStateDigest()
        self.migrationReceipts = migrationReceipts.sorted { $0.idempotencyKey < $1.idempotencyKey }
        self.accountBook = accountBook
        self.archiveContentDigest = try Self.digest(
            formatVersion: Self.currentFormatVersion, accountID: accountBook.accountID,
            schemaVersion: accountBook.schemaVersion, archivedAt: archivedAt,
            migrationReceipts: self.migrationReceipts, accountBook: accountBook)
    }

    public func validate(now: Date = Date()) throws {
        guard formatVersion == Self.currentFormatVersion else {
            throw FLedgerPersistenceError.unsupportedArchiveVersion(formatVersion)
        }
        guard archivedAt.timeIntervalSince1970.isFinite,
              archivedAt <= now.addingTimeInterval(300), archivedAt >= accountBook.updatedAt else {
            throw FLedgerPersistenceError.corruptArchive("implausible archive timestamp")
        }
        guard accountID == accountBook.accountID,
              schemaVersion == accountBook.schemaVersion else {
            throw FLedgerPersistenceError.accountIdentityMismatch
        }
        try accountBook.validate(now: now)
        guard try accountBook.ledgerStateDigest() == ledgerDigest else {
            throw FLedgerPersistenceError.corruptArchive("ledger digest mismatch")
        }
        guard Set(migrationReceipts.map(\.idempotencyKey)).count == migrationReceipts.count else {
            throw FLedgerPersistenceError.corruptArchive("duplicate migration receipt")
        }
        for receipt in migrationReceipts {
            try receipt.validate(now: now)
            guard receipt.appliedAt <= archivedAt else {
                throw FLedgerPersistenceError.invalidMigrationSource
            }
        }
        let expectedContentDigest = try Self.digest(
            formatVersion: formatVersion, accountID: accountID, schemaVersion: schemaVersion,
            archivedAt: archivedAt, migrationReceipts: migrationReceipts, accountBook: accountBook)
        guard expectedContentDigest == archiveContentDigest else {
            throw FLedgerPersistenceError.corruptArchive("archive content digest mismatch")
        }
    }

    private struct DigestPayload: Codable {
        var formatVersion: Int
        var accountID: UUID
        var schemaVersion: Int
        var archivedAt: Date
        var migrationReceipts: [FLedgerMigrationReceipt]
        var accountBook: FAccountBook
    }

    private static func digest(formatVersion: Int, accountID: UUID, schemaVersion: Int,
                               archivedAt: Date, migrationReceipts: [FLedgerMigrationReceipt],
                               accountBook: FAccountBook) throws -> String {
        let payload = DigestPayload(formatVersion: formatVersion, accountID: accountID,
                                    schemaVersion: schemaVersion, archivedAt: archivedAt,
                                    migrationReceipts: migrationReceipts, accountBook: accountBook)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(payload)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func legacyV1Digest(_ accountBook: FAccountBook) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hash(data: try encoder.encode(accountBook))
            .map { String(format: "%02x", $0) }.joined()
    }
}

struct FAccountBookMutationBase: Sendable {
    let accountBook: FAccountBook
    let ledgerDigest: String
    let archiveContentDigest: String
}

/// Actor-isolated, single-writer file store for an F account book.
/// Saves validate before writing, use optimistic full-content digests, preserve the prior
/// verified archive, atomically replace one file, and read it back before returning.
public actor FAccountBookStore {
    public let fileURL: URL
    public let recoveryURL: URL
    private let processLockURL: URL

    public init(fileURL: URL, recoveryURL: URL? = nil) {
        self.fileURL = fileURL
        self.recoveryURL = recoveryURL ?? fileURL.appendingPathExtension("recovery")
        self.processLockURL = fileURL.appendingPathExtension("lock")
    }

    /// Returns nil only when no primary account file exists.
    public func load(now: Date = Date()) throws -> FAccountBook? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decodeArchive(Data(contentsOf: fileURL), now: now).accountBook
    }

    /// Full account-and-provenance content digest of the verified primary archive.
    public func currentDigest(now: Date = Date()) throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decodeArchive(Data(contentsOf: fileURL), now: now).archiveContentDigest
    }

    /// Reads the account and both optimistic-concurrency digests from the same
    /// validated archive snapshot, so a write cannot pair an old book with a new digest.
    func loadMutationBase(now: Date = Date()) throws -> FAccountBookMutationBase? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let archive = try decodeArchive(Data(contentsOf: fileURL), now: now)
        return FAccountBookMutationBase(accountBook: archive.accountBook,
                                        ledgerDigest: archive.ledgerDigest,
                                        archiveContentDigest: archive.archiveContentDigest)
    }

    /// Atomically saves a complete account snapshot while preserving import receipts.
    /// A missing file accepts only a nil expected digest; replacement requires the exact
    /// current full-content digest to reject stale writes.
    @discardableResult
    func save(_ accountBook: FAccountBook, expectedPriorDigest: String? = nil,
              now: Date = Date()) throws -> String {
        try accountBook.validate(now: now)
        let existingArchive = try verifiedExistingArchive(now: now)
        let receipts = existingArchive?.migrationReceipts ?? []
        let archive = try FAccountBookArchive(accountBook: accountBook,
                                              migrationReceipts: receipts, archivedAt: now)
        return try persist(archive, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    /// Initial migration is restricted to a previously absent F ledger. The candidate must
    /// represent only the source's current cash/positions as its opening snapshot; legacy
    /// events are retained byte-for-byte in the receipt and are never replayed as F fills.
    /// The caller must invoke this only after presenting the dry-run and receiving explicit
    /// user confirmation. No existing account can be replaced by this method.
    @discardableResult
    func importInitialLegacySnapshot(
        _ preview: FLegacyLedgerMigrationPreview, confirmation: FUserLedgerConfirmation,
        expectedPriorDigest: String? = nil, now: Date = Date()
    ) throws -> String {
        let sourceBytes = try preview.validatedSourceBytes()
        let candidate = preview.candidateAccountBook
        let sourceKind = preview.sourceKind
        let legacyAccountID = preview.legacyAccountID
        if let existing = try verifiedExistingArchive(now: now) {
            let sourceHash = Self.sha256(sourceBytes)
            if let receipt = existing.migrationReceipts.first(where: {
                $0.sourceKind == sourceKind && $0.legacyAccountID == legacyAccountID &&
                $0.sourceSHA256 == sourceHash
            }) {
                throw FLedgerPersistenceError.duplicateMigration(receipt.idempotencyKey)
            }
            throw FLedgerPersistenceError.targetAlreadyInitialized
        }
        guard expectedPriorDigest == nil else {
            throw FLedgerPersistenceError.concurrentModification(expected: expectedPriorDigest, actual: nil)
        }
        guard !sourceBytes.isEmpty,
              !confirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmation.confirmedAt >= preview.capturedAt,
              confirmation.confirmedAt <= now.addingTimeInterval(300) else {
            throw FLedgerPersistenceError.invalidMigrationSource
        }
        let receipt = try FLedgerMigrationReceipt(sourceKind: sourceKind,
                                                  legacyAccountID: legacyAccountID,
                                                  sourceBytes: sourceBytes,
                                                  appliedAt: confirmation.confirmedAt)
        guard candidate.accountID == (try FLedgerMigrationReceipt.targetAccountID(for: receipt.idempotencyKey)),
              candidate.fills.isEmpty, candidate.cashMovements.isEmpty, candidate.audits.isEmpty,
              candidate.openingSnapshot.cashBalance == candidate.cashBalance,
              candidate.openingSnapshot.positions == candidate.positions,
              candidate.positions.allSatisfy({
                  $0.id == FLedgerMigrationReceipt.targetPositionID(accountID: candidate.accountID,
                                                                     instrumentCode: $0.instrumentCode)
              }) else {
            throw FLedgerPersistenceError.invalidMigrationIdentity
        }
        try candidate.validate(now: now)

        var imported = candidate
        imported.updatedAt = confirmation.confirmedAt
        let resultingDigest = try imported.ledgerStateDigest()
        imported.audits.append(FLedgerAuditEvent(
            occurredAt: confirmation.confirmedAt,
            action: "用户确认导入 A/B 真实账本快照",
            reason: confirmation.confirmationNote,
            priorLedgerDigest: nil,
            resultingLedgerDigest: resultingDigest))
        try imported.validate(now: now)
        let archive = try FAccountBookArchive(accountBook: imported,
                                              migrationReceipts: [receipt],
                                              archivedAt: confirmation.confirmedAt)
        return try persist(archive, expectedPriorDigest: nil, now: now)
    }

    /// Creates a verified, portable backup at a caller-selected destination.
    @discardableResult
    public func createBackup(at destination: URL, now: Date = Date()) throws -> String {
        guard destination.standardizedFileURL != fileURL.standardizedFileURL,
              destination.standardizedFileURL != recoveryURL.standardizedFileURL else {
            throw FLedgerPersistenceError.invalidBackupDestination
        }
        guard let source = try verifiedExistingData(now: now) else {
            throw FLedgerPersistenceError.primaryFileMissing
        }
        try atomicWrite(source, to: destination)
        return try decodeArchive(Data(contentsOf: destination), now: now).archiveContentDigest
    }

    /// Restores a verified portable backup using the same optimistic and atomic commit path.
    @discardableResult
    func restoreBackup(from source: URL, expectedPriorDigest: String?,
                       now: Date = Date()) throws -> String {
        let archive = try decodeArchive(Data(contentsOf: source), now: now)
        return try persist(archive, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    /// Verifies the retained last-good recovery file without changing the active account.
    public func recoveryCandidate(now: Date = Date()) throws -> FAccountBook? {
        guard FileManager.default.fileExists(atPath: recoveryURL.path) else { return nil }
        return try decodeArchive(Data(contentsOf: recoveryURL), now: now).accountBook
    }

    /// Promotes the retained last-good recovery file only after the caller supplies the current
    /// primary digest. This is deliberately explicit; load never silently swaps account data.
    @discardableResult
    func restoreRecoveryCandidate(expectedPriorDigest: String?,
                                  now: Date = Date()) throws -> String {
        let archive = try decodeArchive(Data(contentsOf: recoveryURL), now: now)
        return try persist(archive, expectedPriorDigest: expectedPriorDigest, now: now)
    }

    private func persist(_ archive: FAccountBookArchive, expectedPriorDigest: String?,
                         now: Date) throws -> String {
        try withProcessLock {
            try archive.validate(now: now)
            guard fileURL.standardizedFileURL != recoveryURL.standardizedFileURL else {
                throw FLedgerPersistenceError.invalidRecoveryDestination
            }
            let existingData = try verifiedExistingData(now: now)
            let existingArchive = try existingData.map { try decodeArchive($0, now: now) }
            let actualDigest = existingArchive?.archiveContentDigest
            guard actualDigest == expectedPriorDigest else {
                throw FLedgerPersistenceError.concurrentModification(
                    expected: expectedPriorDigest, actual: actualDigest)
            }
            if let existingData { try atomicWrite(existingData, to: recoveryURL) }

            let newData = try encodeArchive(archive)
            do {
                try atomicWrite(newData, to: fileURL)
                let persisted = try decodeArchive(Data(contentsOf: fileURL), now: now)
                guard persisted == archive else {
                    throw FLedgerPersistenceError.corruptArchive("post-write archive mismatch")
                }
                return persisted.archiveContentDigest
            } catch {
                do {
                    if let existingData {
                        try atomicWrite(existingData, to: fileURL)
                    } else if FileManager.default.fileExists(atPath: fileURL.path) {
                        try FileManager.default.removeItem(at: fileURL)
                        try synchronizeDirectory(fileURL.deletingLastPathComponent())
                    }
                } catch {
                    throw FLedgerPersistenceError.rollbackFailed(String(describing: error))
                }
                throw error
            }
        }
    }

    private func withProcessLock<T>(_ operation: () throws -> T) throws -> T {
        FLedgerInProcessLock.shared.lock.lock()
        defer { FLedgerInProcessLock.shared.lock.unlock() }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor: Int32 = processLockURL.path.withCString { path in
            #if canImport(Darwin)
            return Darwin.open(path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
            #elseif canImport(Glibc)
            return Glibc.open(path, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
            #else
            return -1
            #endif
        }
        guard descriptor >= 0 else { throw FLedgerPersistenceError.storageFailure("cannot open ledger lock") }
        defer {
            #if canImport(Darwin)
            _ = Darwin.close(descriptor)
            #elseif canImport(Glibc)
            _ = Glibc.close(descriptor)
            #endif
        }
        while true {
            let result: Int32
            #if canImport(Darwin)
            var lock = Darwin.flock()
            lock.l_type = Int16(F_WRLCK)
            lock.l_whence = Int16(SEEK_SET)
            lock.l_start = 0
            lock.l_len = 0
            result = Darwin.fcntl(descriptor, F_SETLKW, &lock)
            #elseif canImport(Glibc)
            result = Glibc.flock(descriptor, LOCK_EX)
            #else
            result = -1
            #endif
            if result == 0 { break }
            if errno == EINTR { continue }
            throw FLedgerPersistenceError.storageFailure("cannot acquire ledger lock")
        }
        defer {
            #if canImport(Darwin)
            var lock = Darwin.flock()
            lock.l_type = Int16(F_UNLCK)
            lock.l_whence = Int16(SEEK_SET)
            lock.l_start = 0
            lock.l_len = 0
            _ = Darwin.fcntl(descriptor, F_SETLK, &lock)
            #elseif canImport(Glibc)
            _ = Glibc.flock(descriptor, LOCK_UN)
            #endif
        }
        return try operation()
    }

    private func verifiedExistingArchive(now: Date) throws -> FAccountBookArchive? {
        guard let data = try verifiedExistingData(now: now) else { return nil }
        return try decodeArchive(data, now: now)
    }

    private func verifiedExistingData(now: Date) throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        _ = try decodeArchive(data, now: now)
        return data
    }

    private func encodeArchive(_ archive: FAccountBookArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do { return try encoder.encode(archive) }
        catch { throw FLedgerPersistenceError.corruptArchive("encode failed: \(error)") }
    }

    private func decodeArchive(_ data: Data, now: Date) throws -> FAccountBookArchive {
        do {
            let archive = try JSONDecoder().decode(FAccountBookArchive.self, from: data)
            try archive.validate(now: now)
            return archive
        } catch let error as FLedgerPersistenceError {
            throw error
        } catch {
            throw FLedgerPersistenceError.corruptArchive("decode failed: \(error)")
        }
    }

    private func atomicWrite(_ data: Data, to destination: URL) throws {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".ledger-" + UUID().uuidString + ".tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw FLedgerPersistenceError.storageFailure("cannot create ledger staging file")
        }
        var published = false
        defer { if !published { try? FileManager.default.removeItem(at: temporary) } }
        do {
            let handle = try FileHandle(forWritingTo: temporary)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            let renameResult: Int32 = temporary.path.withCString { source in
                destination.path.withCString { target in
                    #if canImport(Darwin)
                    return Darwin.rename(source, target)
                    #elseif canImport(Glibc)
                    return Glibc.rename(source, target)
                    #else
                    return -1
                    #endif
                }
            }
            guard renameResult == 0 else {
                throw FLedgerPersistenceError.storageFailure("atomic ledger rename failed")
            }
            published = true
            try synchronizeDirectory(directory)
        } catch {
            throw error
        }
    }

    private func synchronizeDirectory(_ directory: URL) throws {
        let descriptor: Int32 = directory.path.withCString { path in
            #if canImport(Darwin)
            return Darwin.open(path, O_RDONLY)
            #elseif canImport(Glibc)
            return Glibc.open(path, O_RDONLY)
            #else
            return -1
            #endif
        }
        guard descriptor >= 0 else { throw FLedgerPersistenceError.storageFailure("cannot open ledger directory") }
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
        guard result == 0 else { throw FLedgerPersistenceError.storageFailure("ledger directory sync failed") }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
