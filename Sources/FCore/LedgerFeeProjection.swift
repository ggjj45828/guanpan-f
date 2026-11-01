import Foundation

/// Deterministic fee-adjusted economic replay. It creates value copies of fills and never
/// mutates the user's immutable confirmed-fill records.
@_spi(LedgerStorage) public enum FLedgerFeeProjection {
    public struct State {
        public var units: [String: Int64]
        public var costs: [String: Decimal]
    }

    public static func effectiveFees(in book: FAccountBook) throws -> [UUID: Decimal] {
        var fees = Dictionary(uniqueKeysWithValues: book.fills.map { ($0.id, $0.fee) })
        for adjustment in (book.feeAdjustments ?? []).sorted(by: { $0.sequence < $1.sequence }) {
            guard let prior = fees[adjustment.fillID] else {
                throw FLedgerValidationError.feeAdjustmentTargetMissing(adjustment.fillID)
            }
            let next = prior + adjustment.feeDelta
            guard next.isFinite, next >= 0 else {
                throw FLedgerValidationError.invalidFeeAdjustment(adjustment.id)
            }
            fees[adjustment.fillID] = next
        }
        return fees
    }

    public static func replay(opening: FAccountOpeningSnapshot,
                              fills: [FConfirmedFill], fees: [UUID: Decimal],
                              recalculateSellBasis: Bool) throws -> (fills: [FConfirmedFill], state: State) {
        var state = State(units: [:], costs: [:])
        for position in opening.positions {
            state.units[position.instrumentCode] = position.units
            state.costs[position.instrumentCode] = position.bookCost
        }
        var projected: [FConfirmedFill] = []
        for original in fills.sorted(by: { $0.sequence < $1.sequence }) {
            var fill = original
            let fee = fees[fill.id] ?? fill.fee
            guard fee.isFinite, fee >= 0 else {
                throw FLedgerValidationError.invalidFill(fill.id)
            }
            fill.fee = fee
            let code = fill.instrumentCode
            let units = state.units[code, default: 0]
            let cost = state.costs[code, default: 0]
            if fill.side == .buy {
                let (next, overflow) = units.addingReportingOverflow(fill.units)
                guard !overflow else { throw FLedgerValidationError.positionQuantityOverflow(code) }
                state.units[code] = next
                state.costs[code] = cost + fill.price * Decimal(fill.units) + fee
                fill.costBasisRemoved = nil
            } else {
                guard fill.units <= units else { throw FLedgerValidationError.positionUnitUnderflow(code) }
                let removed: Decimal
                if recalculateSellBasis {
                    removed = try FAccountingPolicy.costBasisRemoved(
                        unitsSold: fill.units, totalUnits: units, totalBookCost: cost)
                    fill.costBasisRemoved = removed
                } else {
                    guard let recorded = fill.costBasisRemoved else {
                        throw FLedgerValidationError.missingSellCostBasis(fill.id)
                    }
                    removed = recorded
                }
                guard removed <= cost else { throw FLedgerValidationError.invalidFill(fill.id) }
                state.units[code] = units - fill.units
                state.costs[code] = units == fill.units ? 0 : cost - removed
            }
            projected.append(fill)
        }
        return (projected, state)
    }

    public static func adjustedFills(in book: FAccountBook) throws -> [FConfirmedFill] {
        try replay(opening: book.openingSnapshot, fills: book.fills,
                   fees: effectiveFees(in: book), recalculateSellBasis: true).fills
    }
}
