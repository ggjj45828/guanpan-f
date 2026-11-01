import Foundation
@_spi(LedgerStorage) import FCore

/// The only public capability for changing the real ledger. This module is separate
/// from FAdvisor; the FAdvisor target does not depend on FLedgerWrite.
public actor FConfirmedLedgerWriter {
    private let store: FAccountBookStore

    public init(store: FAccountBookStore) { self.store = store }

    @discardableResult
    public func confirmInitialLedger(_ book: FAccountBook,
                                     confirmation: FUserLedgerConfirmation,
                                     now: Date = Date()) async throws -> String {
        try validate(confirmation, now: now)
        var confirmed = book
        confirmed.updatedAt = confirmation.confirmedAt
        try confirmed.validate(now: now)
        guard confirmed.fills.isEmpty, confirmed.cashMovements.isEmpty, confirmed.audits.isEmpty,
              confirmed.openingSnapshot.cashBalance == confirmed.cashBalance,
              confirmed.openingSnapshot.positions.sorted(by: { $0.instrumentCode < $1.instrumentCode }) ==
                confirmed.positions.sorted(by: { $0.instrumentCode < $1.instrumentCode }) else {
            throw FLedgerPersistenceError.invalidInitialLedger
        }
        guard try await store.currentDigest(now: now) == nil else {
            throw FLedgerPersistenceError.targetAlreadyInitialized
        }
        let resultingDigest = try confirmed.ledgerStateDigest()
        confirmed.audits.append(FLedgerAuditEvent(
            occurredAt: confirmation.confirmedAt,
            action: "用户确认录入初始真实账户快照",
            reason: confirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            priorLedgerDigest: nil,
            resultingLedgerDigest: resultingDigest))
        try confirmed.validate(now: now)
        return try await store.save(confirmed, expectedPriorDigest: nil, now: now)
    }

    @discardableResult
    public func confirmFill(_ fill: FConfirmedFill, instrumentName: String,
                            expectedLedgerDigest: String? = nil,
                            now: Date = Date()) async throws -> String {
        try validate(fill.userConfirmation, now: now)
        guard let base = try await store.loadMutationBase(now: now) else {
            throw FLedgerPersistenceError.primaryFileMissing
        }
        if let expectedLedgerDigest, expectedLedgerDigest != base.ledgerDigest {
            throw FLedgerPersistenceError.concurrentModification(
                expected: expectedLedgerDigest, actual: base.ledgerDigest)
        }
        let updated = try base.accountBook.applyingUserConfirmedFill(
            fill, instrumentName: instrumentName, now: now)
        return try await store.save(updated, expectedPriorDigest: base.archiveContentDigest, now: now)
    }

    /// Appends an after-the-fact fee correction only after explicit user confirmation.
    @discardableResult
    public func confirmFillFeeCorrection(fillID: UUID, correctedFee: Decimal, reason: String,
                                         confirmation: FUserLedgerConfirmation,
                                         now: Date = Date()) async throws -> String {
        try validate(confirmation, now: now)
        guard let base = try await store.loadMutationBase(now: now) else {
            throw FLedgerPersistenceError.primaryFileMissing
        }
        let updated = try base.accountBook.correctingFillFee(
            fillID: fillID, correctedFee: correctedFee, reason: reason,
            confirmation: confirmation, now: now)
        return try await store.save(updated, expectedPriorDigest: base.archiveContentDigest, now: now)
    }

    @discardableResult
    public func confirmCashMovement(_ movement: FCashMovement,
                                    now: Date = Date()) async throws -> String {
        try validate(movement.userConfirmation, now: now)
        guard let base = try await store.loadMutationBase(now: now) else {
            throw FLedgerPersistenceError.primaryFileMissing
        }
        let updated = try base.accountBook.applyingUserConfirmedCashMovement(movement, now: now)
        return try await store.save(updated, expectedPriorDigest: base.archiveContentDigest, now: now)
    }

    @discardableResult
    public func confirmBrokerDisplayCost(instrumentCode: String, costPerUnit: Decimal,
                                         confirmation: FUserLedgerConfirmation,
                                         now: Date = Date()) async throws -> String {
        try validate(confirmation, now: now)
        guard let base = try await store.loadMutationBase(now: now) else {
            throw FLedgerPersistenceError.primaryFileMissing
        }
        let updated = try base.accountBook.correctingBrokerDisplayCost(
            instrumentCode: instrumentCode, costPerUnit: costPerUnit,
            confirmation: confirmation, now: now)
        return try await store.save(updated, expectedPriorDigest: base.archiveContentDigest, now: now)
    }

    @discardableResult
    public func confirmInitialMigration(_ preview: FLegacyLedgerMigrationPreview,
                                        confirmation: FUserLedgerConfirmation,
                                        now: Date = Date()) async throws -> String {
        try validate(confirmation, now: now)
        return try await store.importInitialLegacySnapshot(preview,
                                                           confirmation: confirmation,
                                                           now: now)
    }

    @discardableResult
    public func confirmBackupRestore(from source: URL, confirmation: FUserLedgerConfirmation,
                                     now: Date = Date()) async throws -> String {
        try validate(confirmation, now: now)
        let current = try await store.currentDigest(now: now)
        return try await store.restoreBackup(from: source, expectedPriorDigest: current, now: now)
    }

    @discardableResult
    public func confirmRecoveryRestore(confirmation: FUserLedgerConfirmation,
                                       now: Date = Date()) async throws -> String {
        try validate(confirmation, now: now)
        let current = try await store.currentDigest(now: now)
        return try await store.restoreRecoveryCandidate(expectedPriorDigest: current, now: now)
    }

    private func validate(_ confirmation: FUserLedgerConfirmation, now: Date) throws {
        guard !confirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmation.confirmedAt.timeIntervalSince1970.isFinite,
              confirmation.confirmedAt <= now.addingTimeInterval(300) else {
            throw FLedgerPersistenceError.invalidMigrationSource
        }
    }
}

extension FAccountBookStore: FLedgerSnapshotReading {
    public func readLedgerSnapshot(now: Date) async throws -> FReadOnlyLedgerSnapshot? {
        guard let book = try load(now: now) else { return nil }
        return try book.readOnlySnapshot(capturedAt: now)
    }
}
