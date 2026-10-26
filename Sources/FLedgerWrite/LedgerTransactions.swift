import Foundation
import CryptoKit

public enum FLedgerMutationError: Error, Equatable, Sendable {
    case duplicateFill(UUID)
    case duplicateCashMovement(UUID)
    case insufficientCash
    case missingPosition(String)
    case insufficientUnits(String)
    case invalidCostBasis(String)
    case invalidInstrumentName
}

public extension FAccountBook {
    /// Returns an updated value only after the proposed user-confirmed fill reconciles.
    /// The application layer must call this only from an explicit user confirmation action.
    /// Durable storage must still succeed before the UI publishes the returned value.
    func applyingUserConfirmedFill(_ fill: FConfirmedFill, instrumentName: String,
                                   now: Date = Date()) throws -> FAccountBook {
        try validate(now: now)
        guard !fills.contains(where: { $0.id == fill.id }) else {
            throw FLedgerMutationError.duplicateFill(fill.id)
        }
        let lastSequence = (fills.map(\.sequence) + cashMovements.map(\.sequence)).max() ?? 0
        guard lastSequence < UInt64.max, fill.sequence == lastSequence + 1 else {
            let expected = lastSequence == UInt64.max ? UInt64.max : lastSequence + 1
            throw FLedgerValidationError.invalidEventSequence(expected: expected, actual: fill.sequence)
        }
        guard fill.userConfirmation.confirmedAt >= updatedAt else {
            throw FLedgerValidationError.implausibleTimestamp("confirmation.beforeUpdatedAt")
        }
        guard !instrumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FLedgerMutationError.invalidInstrumentName
        }
        let retainedName = instrumentName.trimmingCharacters(in: .whitespacesAndNewlines)
        var retainedFill = fill
        retainedFill.instrumentName = retainedName

        let beforeDigest = try ledgerStateDigest()
        var result = self
        let consideration = fill.price * Decimal(fill.units)
        guard !consideration.isNaN else { throw FLedgerValidationError.invalidFill(fill.id) }

        switch fill.side {
        case .buy:
            let debit = consideration + fill.fee
            guard !debit.isNaN, result.cashBalance >= debit else {
                throw FLedgerMutationError.insufficientCash
            }
            result.cashBalance -= debit
            if let index = result.positions.firstIndex(where: { $0.instrumentCode == fill.instrumentCode }) {
                let (units, overflow) = result.positions[index].units.addingReportingOverflow(fill.units)
                guard !overflow else { throw FLedgerValidationError.positionQuantityOverflow(fill.instrumentCode) }
                result.positions[index].units = units
                result.positions[index].bookCost += debit
                result.positions[index].name = retainedName
            } else {
                result.positions.append(FPosition(instrumentCode: fill.instrumentCode, name: retainedName,
                                                 units: fill.units, bookCost: debit))
            }
        case .sell:
            guard let index = result.positions.firstIndex(where: { $0.instrumentCode == fill.instrumentCode }) else {
                throw FLedgerMutationError.missingPosition(fill.instrumentCode)
            }
            guard fill.units <= result.positions[index].units else {
                throw FLedgerMutationError.insufficientUnits(fill.instrumentCode)
            }
            guard let removedCost = fill.costBasisRemoved else {
                throw FLedgerMutationError.invalidCostBasis(fill.instrumentCode)
            }
            let policyCost = try FAccountingPolicy.costBasisRemoved(
                unitsSold: fill.units,
                totalUnits: result.positions[index].units,
                totalBookCost: result.positions[index].bookCost)
            guard removedCost == policyCost else {
                throw FLedgerValidationError.costBasisPolicyMismatch(
                    sequence: fill.sequence, expected: policyCost, actual: removedCost)
            }
            let credit = consideration - fill.fee
            guard !credit.isNaN else { throw FLedgerValidationError.invalidFill(fill.id) }
            result.cashBalance += credit
            result.positions[index].units -= fill.units
            result.positions[index].bookCost -= removedCost
            result.positions[index].name = retainedName
            if result.positions[index].units == 0 {
                guard result.positions[index].bookCost == 0 else {
                    throw FLedgerMutationError.invalidCostBasis(fill.instrumentCode)
                }
                result.positions.remove(at: index)
            }
        }

        result.fills.append(retainedFill)
        result.updatedAt = fill.userConfirmation.confirmedAt
        try result.validate(now: now)
        let afterDigest = try result.ledgerStateDigest()
        result.audits.append(FLedgerAuditEvent(
            occurredAt: fill.userConfirmation.confirmedAt,
            action: fill.side == .buy ? "用户确认成交买入" : "用户确认成交卖出",
            reason: fill.userConfirmation.confirmationNote,
            priorLedgerDigest: beforeDigest,
            resultingLedgerDigest: afterDigest
        ))
        try result.validate(now: now)
        return result
    }

    /// Applies a user-confirmed deposit, withdrawal, or income event to a value copy.
    /// The application layer must call this only from an explicit confirmation action and
    /// persist the returned book before publishing it.
    func applyingUserConfirmedCashMovement(_ movement: FCashMovement,
                                           now: Date = Date()) throws -> FAccountBook {
        try validate(now: now)
        guard !cashMovements.contains(where: { $0.id == movement.id }) else {
            throw FLedgerMutationError.duplicateCashMovement(movement.id)
        }
        let lastSequence = (fills.map(\.sequence) + cashMovements.map(\.sequence)).max() ?? 0
        guard lastSequence < UInt64.max, movement.sequence == lastSequence + 1 else {
            let expected = lastSequence == UInt64.max ? UInt64.max : lastSequence + 1
            throw FLedgerValidationError.invalidEventSequence(expected: expected, actual: movement.sequence)
        }
        guard movement.userConfirmation.confirmedAt >= updatedAt else {
            throw FLedgerValidationError.implausibleTimestamp("confirmation.beforeUpdatedAt")
        }
        guard movement.amount != 0, !movement.amount.isNaN else {
            throw FLedgerValidationError.invalidCashMovement(movement.id)
        }
        let newCash = cashBalance + movement.amount
        guard !newCash.isNaN, newCash >= 0 else { throw FLedgerMutationError.insufficientCash }

        let beforeDigest = try ledgerStateDigest()
        var result = self
        result.cashBalance = newCash
        result.cashMovements.append(movement)
        result.updatedAt = movement.userConfirmation.confirmedAt
        try result.validate(now: now)
        let afterDigest = try result.ledgerStateDigest()
        result.audits.append(FLedgerAuditEvent(
            occurredAt: movement.userConfirmation.confirmedAt,
            action: movement.amount > 0 ? "用户确认现金增加" : "用户确认现金减少",
            reason: movement.reason,
            priorLedgerDigest: beforeDigest,
            resultingLedgerDigest: afterDigest
        ))
        try result.validate(now: now)
        return result
    }

    /// SHA-256 over canonicalized economic state. Audit rows are omitted to avoid a recursive hash;
    /// each audit row stores the before/after financial-state digests.
    func ledgerStateDigest() throws -> String {
        struct DigestState: Codable {
            var accountID: UUID
            var schemaVersion: Int
            var currencyCode: String
            var openingSnapshot: FAccountOpeningSnapshot
            var cashBalance: Decimal
            var positions: [FPosition]
            var fills: [FConfirmedFill]
            var cashMovements: [FCashMovement]
            var updatedAt: Date
        }

        let state = DigestState(
            accountID: accountID,
            schemaVersion: schemaVersion,
            currencyCode: currencyCode,
            openingSnapshot: FAccountOpeningSnapshot(
                capturedAt: openingSnapshot.capturedAt,
                cashBalance: openingSnapshot.cashBalance,
                positions: openingSnapshot.positions.sorted { $0.instrumentCode < $1.instrumentCode }
            ),
            cashBalance: cashBalance,
            positions: positions.sorted { $0.instrumentCode < $1.instrumentCode },
            fills: fills.sorted {
                if $0.tradedAt != $1.tradedAt { return $0.tradedAt < $1.tradedAt }
                return $0.id.uuidString < $1.id.uuidString
            },
            cashMovements: cashMovements.sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.id.uuidString < $1.id.uuidString
            },
            updatedAt: updatedAt
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let digest = SHA256.hash(data: try encoder.encode(state))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
