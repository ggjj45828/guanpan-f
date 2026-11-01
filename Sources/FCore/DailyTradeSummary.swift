import Foundation

/// Immutable, read-only trade facts derived exclusively from confirmed Ledger fills.
/// Amounts are gross consideration; fees are reported separately. Realized P/L uses
/// the cost basis recorded on each confirmed sell fill.
public struct FDailyTradeSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(securityCode)@\(tradingDate)" }
    public let securityCode: String
    public let tradingDate: String
    public let buyQuantity: Int64
    public let buyAmount: Decimal
    public let sellQuantity: Int64
    public let sellAmount: Decimal
    public let buyFees: Decimal
    public let sellFees: Decimal
    public let totalFees: Decimal
    /// Legacy field name retained for Codable compatibility. This is daily realized
    /// trading P&L from sells; it is neither security-wide daily P&L nor T contribution.
    public let realizedPnL: Decimal
    /// Nil until every relevant fill is explicitly classified and T legs are reliably paired.
    public let tContribution: Decimal?
    public let fillCount: Int
    public let firstFillTime: Date
    public let lastFillTime: Date

    fileprivate init(securityCode: String, tradingDate: String,
                     buyQuantity: Int64, buyAmount: Decimal,
                     sellQuantity: Int64, sellAmount: Decimal,
                     buyFees: Decimal, sellFees: Decimal,
                     realizedPnL: Decimal, tContribution: Decimal?, fillCount: Int,
                     firstFillTime: Date, lastFillTime: Date) {
        self.securityCode = securityCode
        self.tradingDate = tradingDate
        self.buyQuantity = buyQuantity
        self.buyAmount = buyAmount
        self.sellQuantity = sellQuantity
        self.sellAmount = sellAmount
        self.buyFees = buyFees
        self.sellFees = sellFees
        totalFees = buyFees + sellFees
        self.realizedPnL = realizedPnL
        self.tContribution = tContribution
        self.fillCount = fillCount
        self.firstFillTime = firstFillTime
        self.lastFillTime = lastFillTime
    }

    public var dailyRealizedTradingPnL: Decimal { realizedPnL }

    /// Returns an exact representable portfolio total, or nil when there are no
    /// summaries or the Decimal sum overflows. Callers must not use infinity as P&L.
    public static func aggregateRealizedPnL(_ summaries: [FDailyTradeSummary]) -> Decimal? {
        guard !summaries.isEmpty else { return nil }
        var total = Decimal.zero
        for summary in summaries {
            total += summary.realizedPnL
            guard total.isFinite else { return nil }
        }
        return total
    }

    /// Summarizes only fills that occurred on the as-of local trading date. The
    /// timezone is explicit so a UTC day boundary cannot move a CN fill to another day.
    static func derive(from fills: [FConfirmedFill], asOf: Date,
                       timeZoneIdentifier: String = "Asia/Shanghai") throws -> [FDailyTradeSummary] {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw FDailyTradeSummaryError.invalidTimeZone(timeZoneIdentifier)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let targetLabel = try tradingDate(for: asOf, timeZoneIdentifier: timeZoneIdentifier)
        let todaysFills = fills.filter { fill in
            guard fill.tradedAt <= asOf else { return false }
            return calendar.isDate(fill.tradedAt, inSameDayAs: asOf)
        }

        let groups = Dictionary(grouping: todaysFills, by: \.instrumentCode)
        return try groups.keys.sorted().map { code in
            let ordered = (groups[code] ?? []).sorted {
                if $0.sequence != $1.sequence { return $0.sequence < $1.sequence }
                return $0.id.uuidString < $1.id.uuidString
            }
            var buyQuantity: Int64 = 0
            var sellQuantity: Int64 = 0
            var buyAmount = Decimal.zero
            var sellAmount = Decimal.zero
            var buyFees = Decimal.zero
            var sellFees = Decimal.zero
            var realizedPnL = Decimal.zero

            for fill in ordered {
                let (quantity, overflow) = (fill.side == .buy ? buyQuantity : sellQuantity)
                    .addingReportingOverflow(fill.units)
                guard !overflow else { throw FDailyTradeSummaryError.quantityOverflow(code) }
                let gross = fill.price * Decimal(fill.units)
                guard gross.isFinite else { throw FDailyTradeSummaryError.invalidAmount(code) }
                switch fill.side {
                case .buy:
                    buyQuantity = quantity
                    buyAmount += gross
                    buyFees += fill.fee
                case .sell:
                    guard let costBasisRemoved = fill.costBasisRemoved else {
                        throw FDailyTradeSummaryError.missingSellCostBasis(fill.id)
                    }
                    sellQuantity = quantity
                    sellAmount += gross
                    sellFees += fill.fee
                    realizedPnL += gross - fill.fee - costBasisRemoved
                }
            }
            guard buyAmount.isFinite, sellAmount.isFinite, buyFees.isFinite,
                  sellFees.isFinite, realizedPnL.isFinite else {
                throw FDailyTradeSummaryError.invalidAmount(code)
            }
            guard (buyFees + sellFees).isFinite else {
                throw FDailyTradeSummaryError.invalidAmount(code)
            }
            guard let first = ordered.map(\.tradedAt).min(),
                  let last = ordered.map(\.tradedAt).max() else {
                throw FDailyTradeSummaryError.emptyGroup(code)
            }
            return FDailyTradeSummary(
                securityCode: code, tradingDate: targetLabel,
                buyQuantity: buyQuantity, buyAmount: buyAmount,
                sellQuantity: sellQuantity, sellAmount: sellAmount,
                buyFees: buyFees, sellFees: sellFees, realizedPnL: realizedPnL,
                tContribution: FTradeContributionCalculator.contribution(from: ordered),
                fillCount: ordered.count, firstFillTime: first, lastFillTime: last)
        }
    }

    /// Returns the ISO trading-date label used by summaries for an as-of instant.
    public static func tradingDate(for asOf: Date,
                                   timeZoneIdentifier: String = "Asia/Shanghai") throws -> String {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw FDailyTradeSummaryError.invalidTimeZone(timeZoneIdentifier)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return label(calendar.dateComponents([.year, .month, .day], from: asOf))
    }

    public func isValid(asOf: Date, timeZoneIdentifier: String = "Asia/Shanghai") -> Bool {
        let expectedTotalFees = buyFees + sellFees
        let (totalQuantity, quantityOverflow) = buyQuantity.addingReportingOverflow(sellQuantity)
        let minimumFillCount = (buyQuantity > 0 ? 1 : 0) + (sellQuantity > 0 ? 1 : 0)
        guard let fillCountAsQuantity = Int64(exactly: fillCount) else { return false }
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier),
              securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              securityCode == securityCode.trimmingCharacters(in: .whitespacesAndNewlines),
              !securityCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              tradingDate == Self.dateLabel(asOf, timeZone: timeZone),
              buyQuantity >= 0, sellQuantity >= 0, fillCount > 0,
              !quantityOverflow, fillCount >= minimumFillCount,
              fillCountAsQuantity <= totalQuantity,
              buyAmount.isFinite, sellAmount.isFinite, buyFees.isFinite, sellFees.isFinite,
              buyAmount >= 0, sellAmount >= 0, buyFees >= 0, sellFees >= 0,
              (buyQuantity == 0 ? buyAmount == 0 && buyFees == 0 : buyAmount > 0),
              (sellQuantity == 0 ? sellAmount == 0 && sellFees == 0 : sellAmount > 0),
              expectedTotalFees.isFinite, totalFees.isFinite, totalFees == expectedTotalFees,
              realizedPnL.isFinite, (sellQuantity > 0 || realizedPnL == 0),
              (tContribution.map { $0.isFinite } ?? true),
              firstFillTime <= lastFillTime, lastFillTime <= asOf,
              Self.dateLabel(firstFillTime, timeZone: timeZone) == tradingDate,
              Self.dateLabel(lastFillTime, timeZone: timeZone) == tradingDate else { return false }
        return true
    }

    private static func dateLabel(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return label(calendar.dateComponents([.year, .month, .day], from: date))
    }

    private static func label(_ components: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", components.year ?? 0,
               components.month ?? 0, components.day ?? 0)
    }
}

/// Calculates only the quantity that can be paired in timestamp order from an explicit
/// T sell to a later T buyback. Unmatched sells are reductions, not T contribution.
public enum FTradeContributionCalculator {
    public static func contribution(from fills: [FConfirmedFill]) -> Decimal? {
        guard !fills.isEmpty, fills.allSatisfy({ $0.tradeIntent != nil }) else { return nil }
        let tFills = fills.filter { $0.tradeIntent == .tSell || $0.tradeIntent == .tBuyback }
        guard !tFills.isEmpty else { return .zero }

        var cycles: [String: [FConfirmedFill]] = [:]
        for fill in tFills {
            guard let date = try? FDailyTradeSummary.tradingDate(for: fill.tradedAt),
                  let cycle = fill.tCycleID else { return nil }
            cycles["\(fill.instrumentCode)@\(date)#\(cycle)", default: []].append(fill)
        }
        struct SellLot {
            var remainingUnits: Int64
            let originalUnits: Int64
            let price: Decimal
            let fee: Decimal
            var allocatedFee: Decimal
        }

        var total = Decimal.zero
        for cycleKey in cycles.keys.sorted() {
            guard let cycleFills = cycles[cycleKey] else { return nil }
            let orderedCycleFills = cycleFills.sorted {
                if $0.tradedAt != $1.tradedAt { return $0.tradedAt < $1.tradedAt }
                if $0.sequence != $1.sequence { return $0.sequence < $1.sequence }
                return $0.id.uuidString < $1.id.uuidString
            }
            var sellLots: [SellLot] = []
            var lotIndex = 0
            var cycleContribution = Decimal.zero
            var matchedUnits: Int64 = 0
            for fill in orderedCycleFills {
                guard let intent = fill.tradeIntent,
                      let cycle = fill.tCycleID,
                      !cycle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                switch (intent, fill.side) {
                case (.tSell, .sell):
                    sellLots.append(SellLot(remainingUnits: fill.units,
                                            originalUnits: fill.units,
                                            price: fill.price, fee: fill.fee, allocatedFee: 0))
                case (.tBuyback, .buy):
                    var remainingBuyback = fill.units
                    var allocatedBuybackFee = Decimal.zero
                    while remainingBuyback > 0 {
                        guard lotIndex < sellLots.count else { return nil }
                        var lot = sellLots[lotIndex]
                        let matched = min(remainingBuyback, lot.remainingUnits)
                        let (nextMatched, overflow) = matchedUnits.addingReportingOverflow(matched)
                        guard !overflow else { return nil }
                        matchedUnits = nextMatched
                        let allocatedSellFee = matched == lot.remainingUnits
                            ? lot.fee - lot.allocatedFee
                            : lot.fee * Decimal(matched) / Decimal(lot.originalUnits)
                        cycleContribution += (lot.price - fill.price) * Decimal(matched) - allocatedSellFee
                        lot.allocatedFee += allocatedSellFee
                        lot.remainingUnits -= matched
                        remainingBuyback -= matched
                        if lot.remainingUnits == 0 {
                            sellLots[lotIndex] = lot
                            lotIndex += 1
                        } else {
                            sellLots[lotIndex] = lot
                        }
                        let allocatedBuyFee = remainingBuyback == 0
                            ? fill.fee - allocatedBuybackFee
                            : fill.fee * Decimal(matched) / Decimal(fill.units)
                        allocatedBuybackFee += allocatedBuyFee
                    }
                    cycleContribution -= allocatedBuybackFee
                default: return nil
                }
            }
            // A partially matched T sell is not a complete, reportable T result.
            // Without exposing matched and unmatched quantities separately, returning
            // only the paired slice can be mistaken for the day's full T contribution.
            guard sellLots.allSatisfy({ $0.remainingUnits == 0 }) else { return nil }
            guard cycleContribution.isFinite else { return nil }
            total += cycleContribution
        }
        return total.isFinite ? total : nil
    }
}

public enum FDailyTradeSummaryError: Error, Equatable, Sendable {
    case invalidTimeZone(String)
    case quantityOverflow(String)
    case invalidAmount(String)
    case missingSellCostBasis(UUID)
    case emptyGroup(String)
}
