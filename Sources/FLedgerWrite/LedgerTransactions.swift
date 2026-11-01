import Foundation
@_spi(LedgerStorage) import FCore

public enum FLedgerMutationError: Error, Equatable, Sendable {
    case duplicateFill(UUID)
    case duplicateCashMovement(UUID)
    case invalidFeeAdjustment(UUID)
    case insufficientCash
    case missingPosition(String)
    case insufficientUnits(String)
    case invalidCostBasis(String)
    case invalidInstrumentName
    case missingPositionForBrokerDisplayCost(String)
    case invalidBrokerDisplayCost(String)
    case invalidBrokerDisplayCostConfirmation
}

private extension FAccountBook {
    mutating func retainBrokerDisplayCost(from position: FPosition) {
        guard let cost = position.brokerDisplayCostPerUnit,
              let updatedAt = position.brokerDisplayCostUpdatedAt else { return }
        var records = brokerDisplayCosts ?? []
        let record = FBrokerDisplayCostRecord(instrumentCode: position.instrumentCode,
                                              costPerUnit: cost, updatedAt: updatedAt)
        if let index = records.firstIndex(where: { $0.instrumentCode == position.instrumentCode }) {
            records[index] = record
        } else {
            records.append(record)
        }
        brokerDisplayCosts = records
    }

    func retainedBrokerDisplayCost(for code: String) -> FBrokerDisplayCostRecord? {
        brokerDisplayCosts?.first { $0.instrumentCode == code }
    }
}

public extension FAccountBook {
    /// Appends a user-confirmed correction to one fill's fee. The original fill is untouched;
    /// cash settles now while the economic projection attributes the corrected fee to that fill.
    func correctingFillFee(fillID: UUID, correctedFee: Decimal, reason: String,
                           confirmation: FUserLedgerConfirmation,
                           now: Date = Date()) throws -> FAccountBook {
        try validate(now: now)
        guard let fill = fills.first(where: { $0.id == fillID }),
              correctedFee.isFinite, correctedFee >= 0,
              !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !confirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmation.confirmedAt >= updatedAt,
              confirmation.confirmedAt <= now.addingTimeInterval(300) else {
            throw FLedgerMutationError.invalidFeeAdjustment(fillID)
        }
        let effectiveFees = try FLedgerFeeProjection.effectiveFees(in: self)
        let priorFee = effectiveFees[fillID] ?? fill.fee
        let delta = correctedFee - priorFee
        guard delta != 0 else { throw FLedgerMutationError.invalidFeeAdjustment(fillID) }
        let newCash = cashBalance - delta
        guard newCash.isFinite, newCash >= 0 else { throw FLedgerMutationError.insufficientCash }

        let lastSequence = (fills.map(\.sequence) + cashMovements.map(\.sequence) +
                            (feeAdjustments ?? []).map(\.sequence)).max() ?? 0
        guard lastSequence < UInt64.max else { throw FLedgerMutationError.invalidFeeAdjustment(fillID) }
        let beforeDigest = try ledgerStateDigest()
        var updated = self
        let event = FFillFeeAdjustment(
            sequence: lastSequence + 1, fillID: fillID, feeDelta: delta,
            occurredAt: confirmation.confirmedAt,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            userConfirmation: confirmation)
        updated.feeAdjustments = (updated.feeAdjustments ?? []) + [event]
        updated.cashBalance = newCash
        updated.updatedAt = confirmation.confirmedAt

        let correctedFees = try FLedgerFeeProjection.effectiveFees(in: updated)
        let projected = try FLedgerFeeProjection.replay(
            opening: updated.openingSnapshot, fills: updated.fills,
            fees: correctedFees, recalculateSellBasis: true).state
        for index in updated.positions.indices {
            let code = updated.positions[index].instrumentCode
            guard projected.units[code, default: 0] == updated.positions[index].units else {
                throw FLedgerValidationError.positionUnitReconciliation(
                    code: code, expected: projected.units[code, default: 0],
                    actual: updated.positions[index].units)
            }
            updated.positions[index].bookCost = projected.costs[code, default: 0]
        }
        try updated.validate(now: now)
        let afterDigest = try updated.ledgerStateDigest()
        updated.audits.append(FLedgerAuditEvent(
            occurredAt: confirmation.confirmedAt,
            action: "用户确认修正成交手续费",
            reason: "\(fill.instrumentCode) · \(reason.trimmingCharacters(in: .whitespacesAndNewlines)) · \(confirmation.confirmationNote)",
            priorLedgerDigest: beforeDigest, resultingLedgerDigest: afterDigest))
        try updated.validate(now: now)
        return updated
    }

    /// Persists the broker's displayed per-unit cost as a user-confirmed annotation.
    /// It never changes economic book cost, units, cash, or fills.
    func correctingBrokerDisplayCost(instrumentCode: String, costPerUnit: Decimal,
                                     confirmation: FUserLedgerConfirmation,
                                     now: Date = Date()) throws -> FAccountBook {
        try validate(now: now)
        guard costPerUnit.isFinite, costPerUnit >= 0 else {
            throw FLedgerMutationError.invalidBrokerDisplayCost(instrumentCode)
        }
        guard !confirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmation.confirmedAt >= updatedAt,
              confirmation.confirmedAt <= now.addingTimeInterval(300) else {
            throw FLedgerMutationError.invalidBrokerDisplayCostConfirmation
        }
        guard let index = positions.firstIndex(where: { $0.instrumentCode == instrumentCode }),
              positions[index].units > 0 else {
            throw FLedgerMutationError.missingPositionForBrokerDisplayCost(instrumentCode)
        }
        var updated = self
        let priorDigest = try ledgerStateDigest()
        updated.positions[index].brokerDisplayCostPerUnit = costPerUnit
        updated.positions[index].brokerDisplayCostUpdatedAt = confirmation.confirmedAt
        let correctedPosition = updated.positions[index]
        updated.retainBrokerDisplayCost(from: correctedPosition)
        updated.updatedAt = confirmation.confirmedAt
        try updated.validate(now: now)
        let resultingDigest = try updated.ledgerStateDigest()
        updated.audits.append(FLedgerAuditEvent(
            occurredAt: confirmation.confirmedAt,
            action: "用户录入/修正券商展示成本",
            reason: confirmation.confirmationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            priorLedgerDigest: priorDigest,
            resultingLedgerDigest: resultingDigest))
        try updated.validate(now: now)
        return updated
    }

    /// Returns an updated value only after the proposed user-confirmed fill reconciles.
    /// The application layer must call this only from an explicit user confirmation action.
    /// Durable storage must still succeed before the UI publishes the returned value.
    func applyingUserConfirmedFill(_ fill: FConfirmedFill, instrumentName: String,
                                   now: Date = Date()) throws -> FAccountBook {
        try validate(now: now)
        guard !fills.contains(where: { $0.id == fill.id }) else {
            throw FLedgerMutationError.duplicateFill(fill.id)
        }
        let lastSequence = (fills.map(\.sequence) + cashMovements.map(\.sequence) +
                            (feeAdjustments ?? []).map(\.sequence)).max() ?? 0
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
        guard consideration.isFinite else { throw FLedgerValidationError.invalidFill(fill.id) }

        switch fill.side {
        case .buy:
            let debit = consideration + fill.fee
            guard debit.isFinite, result.cashBalance >= debit else {
                throw FLedgerMutationError.insufficientCash
            }
            result.cashBalance -= debit
            if let index = result.positions.firstIndex(where: { $0.instrumentCode == fill.instrumentCode }) {
                let previousPosition = result.positions[index]
                result.retainBrokerDisplayCost(from: previousPosition)
                let (units, overflow) = result.positions[index].units.addingReportingOverflow(fill.units)
                guard !overflow else { throw FLedgerValidationError.positionQuantityOverflow(fill.instrumentCode) }
                result.positions[index].units = units
                result.positions[index].bookCost += debit
                result.positions[index].name = retainedName
            } else {
                let brokerCost = result.retainedBrokerDisplayCost(for: fill.instrumentCode)
                result.positions.append(FPosition(instrumentCode: fill.instrumentCode, name: retainedName,
                                                 units: fill.units, bookCost: debit,
                                                 brokerDisplayCostPerUnit: brokerCost?.costPerUnit,
                                                 brokerDisplayCostUpdatedAt: brokerCost?.updatedAt))
            }
        case .sell:
            guard let index = result.positions.firstIndex(where: { $0.instrumentCode == fill.instrumentCode }) else {
                throw FLedgerMutationError.missingPosition(fill.instrumentCode)
            }
            let previousPosition = result.positions[index]
            result.retainBrokerDisplayCost(from: previousPosition)
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
            guard credit.isFinite else { throw FLedgerValidationError.invalidFill(fill.id) }
            result.cashBalance += credit
            guard result.cashBalance.isFinite else { throw FLedgerValidationError.invalidFill(fill.id) }
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
        let lastSequence = (fills.map(\.sequence) + cashMovements.map(\.sequence) +
                            (feeAdjustments ?? []).map(\.sequence)).max() ?? 0
        guard lastSequence < UInt64.max, movement.sequence == lastSequence + 1 else {
            let expected = lastSequence == UInt64.max ? UInt64.max : lastSequence + 1
            throw FLedgerValidationError.invalidEventSequence(expected: expected, actual: movement.sequence)
        }
        guard movement.userConfirmation.confirmedAt >= updatedAt else {
            throw FLedgerValidationError.implausibleTimestamp("confirmation.beforeUpdatedAt")
        }
        guard movement.amount != 0, movement.amount.isFinite else {
            throw FLedgerValidationError.invalidCashMovement(movement.id)
        }
        let newCash = cashBalance + movement.amount
        guard newCash.isFinite, newCash >= 0 else { throw FLedgerMutationError.insufficientCash }

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

}
