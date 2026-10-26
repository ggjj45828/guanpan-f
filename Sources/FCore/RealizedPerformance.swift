import Foundation

/// Read-only realized performance derived from confirmed sell fills.
/// It has no persistence handle and cannot change cash, positions, costs, or ledger events.
public struct FRealizedInstrumentPerformance: Equatable, Sendable, Identifiable {
    public var id: String { instrumentCode }
    public let instrumentCode: String
    public let sellFillCount: Int
    public let unitsSold: Int64
    public let grossProceeds: Decimal
    public let fees: Decimal
    public let costBasisRemoved: Decimal
    public let netRealizedProfit: Decimal

    public var returnOnRemovedCost: Decimal? {
        guard costBasisRemoved > 0 else { return nil }
        let value = netRealizedProfit / costBasisRemoved
        return value.isNaN ? nil : value
    }
}

public struct FRealizedPerformanceSnapshot: Equatable, Sendable {
    public let accountID: UUID
    public let ledgerDigest: String
    public let currencyCode: String
    public let sellFillCount: Int
    public let unitsSold: Int64
    public let grossProceeds: Decimal
    public let fees: Decimal
    public let costBasisRemoved: Decimal
    public let netRealizedProfit: Decimal
    public let byInstrument: [FRealizedInstrumentPerformance]

    /// Produces a report from confirmed ledger facts only. Candidate plans, quotes,
    /// market value, cash movements, and unrealized gains are deliberately excluded.
    public static func derive(from book: FAccountBook, now: Date = Date()) throws
        -> FRealizedPerformanceSnapshot {
        try book.validate(now: now)
        struct Accumulator {
            var sellFillCount = 0
            var unitsSold: Int64 = 0
            var grossProceeds: Decimal = 0
            var fees: Decimal = 0
            var costBasisRemoved: Decimal = 0
        }
        var totals = Accumulator()
        var instruments: [String: Accumulator] = [:]

        for fill in book.fills.sorted(by: { $0.sequence < $1.sequence }) where fill.side == .sell {
            guard let removed = fill.costBasisRemoved else {
                throw FLedgerValidationError.missingSellCostBasis(fill.id)
            }
            let (nextUnits, overflow) = totals.unitsSold.addingReportingOverflow(fill.units)
            guard !overflow else { throw FLedgerValidationError.positionQuantityOverflow(fill.instrumentCode) }
            let proceeds = fill.price * Decimal(fill.units)
            guard !proceeds.isNaN else { throw FLedgerValidationError.invalidFill(fill.id) }
            totals.sellFillCount += 1
            totals.unitsSold = nextUnits
            totals.grossProceeds += proceeds
            totals.fees += fill.fee
            totals.costBasisRemoved += removed

            var item = instruments[fill.instrumentCode, default: Accumulator()]
            let (itemUnits, itemOverflow) = item.unitsSold.addingReportingOverflow(fill.units)
            guard !itemOverflow else { throw FLedgerValidationError.positionQuantityOverflow(fill.instrumentCode) }
            item.sellFillCount += 1
            item.unitsSold = itemUnits
            item.grossProceeds += proceeds
            item.fees += fill.fee
            item.costBasisRemoved += removed
            guard !totals.grossProceeds.isNaN, !totals.fees.isNaN, !totals.costBasisRemoved.isNaN,
                  !item.grossProceeds.isNaN, !item.fees.isNaN, !item.costBasisRemoved.isNaN else {
                throw FLedgerValidationError.invalidFill(fill.id)
            }
            instruments[fill.instrumentCode] = item
        }

        func net(_ value: Accumulator) throws -> Decimal {
            let result = value.grossProceeds - value.fees - value.costBasisRemoved
            guard !result.isNaN else { throw FLedgerValidationError.invalidCash }
            return result
        }
        let rows = try instruments.keys.sorted().map { code -> FRealizedInstrumentPerformance in
            guard let value = instruments[code] else {
                throw FLedgerValidationError.invalidCash
            }
            return FRealizedInstrumentPerformance(
                instrumentCode: code, sellFillCount: value.sellFillCount, unitsSold: value.unitsSold,
                grossProceeds: value.grossProceeds, fees: value.fees,
                costBasisRemoved: value.costBasisRemoved, netRealizedProfit: try net(value))
        }
        return FRealizedPerformanceSnapshot(
            accountID: book.accountID, ledgerDigest: try book.ledgerStateDigest(),
            currencyCode: book.currencyCode, sellFillCount: totals.sellFillCount,
            unitsSold: totals.unitsSold, grossProceeds: totals.grossProceeds,
            fees: totals.fees, costBasisRemoved: totals.costBasisRemoved,
            netRealizedProfit: try net(totals), byInstrument: rows)
    }
}
