import Foundation
import CryptoKit

/// A read-only projection of a real account. It contains no write handle or mutable
/// reference to the source `FAccountBook`.
public struct FReadOnlyPositionSnapshot: Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let name: String
    public let units: Int64
    public let bookCost: Decimal
    public let acquiredAt: Date?
    public let brokerDisplayCostPerUnit: Decimal?
    public let brokerDisplayCostUpdatedAt: Date?

    fileprivate init(_ position: FPosition) {
        instrumentCode = position.instrumentCode
        name = position.name
        units = position.units
        bookCost = position.bookCost
        acquiredAt = position.acquiredAt
        brokerDisplayCostPerUnit = position.brokerDisplayCostPerUnit
        brokerDisplayCostUpdatedAt = position.brokerDisplayCostUpdatedAt
    }
}

public struct FReadOnlyLedgerSnapshot: Equatable, Sendable {
    public let accountID: UUID
    public let schemaVersion: Int
    public let currencyCode: String
    public let capturedAt: Date
    public let ledgerDigest: String
    public let cashBalance: Decimal
    public let positions: [FReadOnlyPositionSnapshot]
    public let instrumentHistories: [FInstrumentHistorySnapshot]
    public let cashFlow: [FReadOnlyCashFlowEntry]
    /// Confirmed fills summarized for the CN trading date containing `capturedAt`.
    /// Raw fill records and write capabilities are not exposed to Advisor.
    public let dailyTradeSummaryDate: String
    public let dailyTradeSummaries: [FDailyTradeSummary]
    public let confirmedFillIDs: Set<UUID>
    public let confirmedFillTimestamps: [UUID: Date]

    fileprivate init(book: FAccountBook, capturedAt: Date, digest: String) throws {
        accountID = book.accountID
        schemaVersion = book.schemaVersion
        currencyCode = book.currencyCode
        self.capturedAt = capturedAt
        ledgerDigest = digest
        cashBalance = book.cashBalance
        positions = book.positions.map(FReadOnlyPositionSnapshot.init)
            .sorted { $0.instrumentCode < $1.instrumentCode }
        instrumentHistories = FLedgerHistoryProjection.instruments(from: book)
        let names = Dictionary(uniqueKeysWithValues: instrumentHistories.map {
            ($0.instrumentCode, $0.instrumentName)
        })
        cashFlow = FLedgerHistoryProjection.cashFlow(from: book, namesByCode: names)
        dailyTradeSummaryDate = try FDailyTradeSummary.tradingDate(for: capturedAt)
        dailyTradeSummaries = try FDailyTradeSummary.derive(from: book.fills, asOf: capturedAt)
        confirmedFillIDs = Set(book.fills.map(\.id))
        confirmedFillTimestamps = Dictionary(uniqueKeysWithValues: book.fills.map { ($0.id, $0.tradedAt) })
    }
}

/// The advisor depends only on this read interface. Writer/storage products implement
/// it, while the FAdvisor target has no dependency on those products.
public protocol FLedgerSnapshotReading: Sendable {
    func readLedgerSnapshot(now: Date) async throws -> FReadOnlyLedgerSnapshot?
}

public extension FAccountBook {
    @_spi(LedgerStorage)
    public func readOnlySnapshot(capturedAt: Date = Date()) throws -> FReadOnlyLedgerSnapshot {
        try validate(now: capturedAt)
        return try FReadOnlyLedgerSnapshot(book: self, capturedAt: capturedAt,
                                           digest: try ledgerStateDigest())
    }

    /// Canonical economic-state hash. Audit rows are excluded to avoid recursive hashes;
    /// the audit rows retain before/after state digests.
    @_spi(LedgerStorage) public func ledgerStateDigest() throws -> String {
        struct DigestState: Codable {
            var accountID: UUID
            var schemaVersion: Int
            var currencyCode: String
            var openingSnapshot: FAccountOpeningSnapshot
            var cashBalance: Decimal
            var positions: [FPosition]
            var brokerDisplayCosts: [FBrokerDisplayCostRecord]?
            var fills: [FConfirmedFill]
            var cashMovements: [FCashMovement]
            var updatedAt: Date
        }

        let state = DigestState(
            accountID: accountID, schemaVersion: schemaVersion, currencyCode: currencyCode,
            openingSnapshot: FAccountOpeningSnapshot(
                capturedAt: openingSnapshot.capturedAt, cashBalance: openingSnapshot.cashBalance,
                positions: openingSnapshot.positions.sorted { $0.instrumentCode < $1.instrumentCode }),
            cashBalance: cashBalance,
            positions: positions.sorted { $0.instrumentCode < $1.instrumentCode },
            brokerDisplayCosts: brokerDisplayCosts?.sorted { $0.instrumentCode < $1.instrumentCode },
            fills: fills.sorted {
                if $0.tradedAt != $1.tradedAt { return $0.tradedAt < $1.tradedAt }
                return $0.id.uuidString < $1.id.uuidString
            },
            cashMovements: cashMovements.sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.id.uuidString < $1.id.uuidString
            },
            updatedAt: updatedAt)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return SHA256.hash(data: try encoder.encode(state))
            .map { String(format: "%02x", $0) }.joined()
    }
}
