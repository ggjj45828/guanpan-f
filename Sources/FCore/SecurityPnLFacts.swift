import Foundation

/// Deterministic marked-to-market contribution for one security over a trading day.
/// Prices are external market facts; Ledger fills and fees remain the accounting source.
public enum FSecurityPnLCalculator {
    public static func dailySecurityPnL(securityCode: String, tradingDate: String,
                                        startOfDayUnits: Int64,
                                        previousClose: Decimal,
                                        trades: FDailyTradeSummary,
                                        endOfDayUnits: Int64,
                                        currentPrice: Decimal) throws -> Decimal {
        let (bought, buyOverflow) = startOfDayUnits.addingReportingOverflow(trades.buyQuantity)
        let (expectedEnd, sellOverflow) = bought.subtractingReportingOverflow(trades.sellQuantity)
        guard startOfDayUnits >= 0, endOfDayUnits >= 0,
              trades.securityCode == securityCode,
              trades.tradingDate == tradingDate,
              previousClose > 0, currentPrice > 0,
              !previousClose.isNaN, !currentPrice.isNaN,
              !buyOverflow, !sellOverflow, expectedEnd >= 0,
              expectedEnd == endOfDayUnits else {
            throw FSecurityPnLError.invalidInputs
        }
        // End market value + sell proceeds - buy consideration - fees - opening market value.
        // This survives an intraday close/reopen and does not depend on episode identity.
        let result = Decimal(endOfDayUnits) * currentPrice + trades.sellAmount -
            trades.buyAmount - trades.totalFees - Decimal(startOfDayUnits) * previousClose
        guard !result.isNaN else { throw FSecurityPnLError.invalidInputs }
        return result
    }

    public static func episodeUnrealizedPnL(units: Int64, bookCost: Decimal,
                                            currentPrice: Decimal) throws -> Decimal {
        guard units >= 0, bookCost >= 0, currentPrice > 0,
              !bookCost.isNaN, !currentPrice.isNaN else { throw FSecurityPnLError.invalidInputs }
        let result = Decimal(units) * currentPrice - bookCost
        guard !result.isNaN else { throw FSecurityPnLError.invalidInputs }
        return result
    }
}

public enum FSecurityPnLError: Error, Equatable, Sendable {
    case invalidInputs
}
