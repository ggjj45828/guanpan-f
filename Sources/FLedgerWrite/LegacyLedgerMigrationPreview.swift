import Foundation
import FCore
import CryptoKit

/// A reviewed opening snapshot bound to the exact legacy archive bytes.
/// Construction is restricted to `make` so callers cannot pair arbitrary account
/// state with unrelated A/B provenance.
public struct FLegacyLedgerMigrationPreview: Sendable {
    public let sourceKind: FLegacyLedgerSourceKind
    public let legacyAccountID: String?
    public let sourceSHA256: String
    public let sourceByteLength: Int
    public let candidateAccountBook: FAccountBook
    public let capturedAt: Date

    private let sourceBytes: Data

    private init(sourceKind: FLegacyLedgerSourceKind, legacyAccountID: String?,
                 sourceBytes: Data, candidateAccountBook: FAccountBook, capturedAt: Date) {
        self.sourceKind = sourceKind
        self.legacyAccountID = legacyAccountID
        self.sourceBytes = sourceBytes
        self.sourceSHA256 = Self.sha256(sourceBytes)
        self.sourceByteLength = sourceBytes.count
        self.candidateAccountBook = candidateAccountBook
        self.capturedAt = capturedAt
    }

    /// Strictly decodes a supported NextBook v1 JSON archive. Both a bare book and
    /// the `{current, events}` audit wrapper are accepted. Legacy event histories
    /// are intentionally retained only as source bytes and never replayed.
    public static func make(sourceKind: FLegacyLedgerSourceKind, sourceBytes: Data,
                            capturedAt: Date) throws -> FLegacyLedgerMigrationPreview {
        guard !sourceBytes.isEmpty, capturedAt.timeIntervalSince1970.isFinite else {
            throw FLedgerPersistenceError.invalidMigrationSource
        }
        let decoder = JSONDecoder()
        let decoded: LegacyArchive
        do { decoded = try decoder.decode(LegacyArchive.self, from: sourceBytes) }
        catch { throw FLedgerPersistenceError.invalidMigrationSource }

        let legacy = decoded.current
        guard legacy.schemaVersion == 1,
              legacy.cash.isFinite, legacy.cash >= 0,
              UUID(uuidString: legacy.id) != nil,
              legacy.positions.count <= 10_000 else {
            throw FLedgerPersistenceError.invalidMigrationSource
        }

        var codes = Set<String>()
        var positions: [FPosition] = []
        for item in legacy.positions {
            let code = item.code.trimmingCharacters(in: .whitespacesAndNewlines)
            guard code == item.code, Self.validCode(code), codes.insert(code).inserted,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.units >= 0, item.bookCost.isFinite, item.bookCost >= 0 else {
                throw FLedgerPersistenceError.invalidMigrationSource
            }
            if item.units == 0 { continue }
            positions.append(FPosition(
                id: FLedgerMigrationReceipt.targetPositionID(
                    accountID: try FLedgerMigrationReceipt.targetAccountID(for: migrationKey(
                        sourceKind: sourceKind, accountID: legacy.id,
                        sourceSHA256: sha256(sourceBytes))), instrumentCode: code),
                instrumentCode: code, name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                units: item.units, bookCost: item.bookCost, acquiredAt: item.acquiredAt))
        }

        let targetID = try FLedgerMigrationReceipt.targetAccountID(for: migrationKey(
            sourceKind: sourceKind, accountID: legacy.id, sourceSHA256: sha256(sourceBytes)))
        let opening = FAccountOpeningSnapshot(capturedAt: capturedAt,
                                              cashBalance: legacy.cash, positions: positions)
        let book = FAccountBook(accountID: targetID, openingSnapshot: opening,
                                cashBalance: legacy.cash, positions: positions,
                                updatedAt: capturedAt)
        do { try book.validate(now: capturedAt) }
        catch { throw FLedgerPersistenceError.invalidMigrationSource }
        return FLegacyLedgerMigrationPreview(sourceKind: sourceKind,
            legacyAccountID: legacy.id, sourceBytes: sourceBytes,
            candidateAccountBook: book, capturedAt: capturedAt)
    }

    func validatedSourceBytes() throws -> Data {
        guard sourceByteLength == sourceBytes.count,
              sourceSHA256 == Self.sha256(sourceBytes) else {
            throw FLedgerPersistenceError.invalidMigrationSource
        }
        return sourceBytes
    }

    private struct LegacyArchive: Decodable {
        let current: LegacyBook
        enum CodingKeys: String, CodingKey { case current }
        init(from decoder: Decoder) throws {
            if let wrapper = try? decoder.container(keyedBy: CodingKeys.self),
               wrapper.contains(.current) {
                current = try wrapper.decode(LegacyBook.self, forKey: .current)
            } else {
                current = try LegacyBook(from: decoder)
            }
        }
    }

    private struct LegacyBook: Decodable {
        let schemaVersion: Int
        let id: String
        let cash: Decimal
        let positions: [LegacyPosition]
        enum CodingKeys: String, CodingKey { case schemaVersion, id, cash, positions }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            id = try values.decode(String.self, forKey: .id)
            cash = try values.decode(Decimal.self, forKey: .cash)
            positions = try values.decodeIfPresent([LegacyPosition].self, forKey: .positions) ?? []
        }
    }

    private struct LegacyPosition: Decodable {
        let code: String
        let name: String
        let units: Int64
        let bookCost: Decimal
        let acquiredAt: Date?
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func migrationKey(sourceKind: FLegacyLedgerSourceKind,
                                     accountID: String, sourceSHA256: String) -> String {
        FLedgerMigrationReceipt.makeIdempotencyKey(sourceKind: sourceKind,
                                                   legacyAccountID: accountID,
                                                   sourceSHA256: sourceSHA256)
    }

    private static func validCode(_ code: String) -> Bool {
        (2...16).contains(code.count) && code.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-"
        }
    }
}
