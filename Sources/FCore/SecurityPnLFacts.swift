import Foundation

/// Deterministic marked-to-market contribution for one security over a trading day.
/// Prices are external market facts; Ledger fills and fees remain the accounting source.
public enum FSecurityPnLCalculator {
    /// Imported opening holdings recorded after the CN session begins do not prove
    /// how many units were held at the prior close. Their first-day total P&L is
    /// therefore unavailable until a later trading date provides a known baseline.
    public static func openingSnapshotSupportsDailyPnL(openingSnapshotCapturedAt: Date,
                                                       securityCode: String,
                                                       openingPositionCodes: Set<String>,
                                                       tradingDate: String,
                                                       timeZoneIdentifier: String = "Asia/Shanghai") -> Bool {
        guard openingSnapshotCapturedAt.timeIntervalSince1970.isFinite,
              securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }) else { return false }
        guard openingPositionCodes.contains(securityCode) else { return true }
        let dateBytes = Array(tradingDate.utf8)
        guard dateBytes.count == 10, dateBytes[4] == 45, dateBytes[7] == 45,
              dateBytes.enumerated().allSatisfy({ index, byte in
                  index == 4 || index == 7 || (48...57).contains(byte)
              }),
              let year = Int(String(decoding: dateBytes[0..<4], as: UTF8.self)),
              let month = Int(String(decoding: dateBytes[5..<7], as: UTF8.self)),
              let day = Int(String(decoding: dateBytes[8..<10], as: UTF8.self)),
              let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let dayStart = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let canonicalDate = try? FDailyTradeSummary.tradingDate(
                for: dayStart, timeZoneIdentifier: timeZoneIdentifier),
              canonicalDate == tradingDate,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let sessionStart = calendar.date(byAdding: .minute, value: 570, to: dayStart),
              openingSnapshotCapturedAt < nextDay else { return false }
        return openingSnapshotCapturedAt < dayStart || openingSnapshotCapturedAt < sessionStart
    }

    /// Derives the opening quantity from the real closing position and the
    /// captured day's confirmed buy/sell totals. A nil summary means no fills
    /// for this security on `tradingDate`, not missing data.
    public static func dailySecurityPnL(securityCode: String, tradingDate: String,
                                        previousClose: Decimal,
                                        trades: FDailyTradeSummary?,
                                        endOfDayUnits: Int64,
                                        currentPrice: Decimal) throws -> Decimal {
        if let trades,
           (trades.securityCode != securityCode || trades.tradingDate != tradingDate ||
            !trades.isValid(asOf: trades.lastFillTime)) {
            throw FSecurityPnLError.invalidInputs
        }
        let buyQuantity = trades?.buyQuantity ?? 0
        let sellQuantity = trades?.sellQuantity ?? 0
        let (withSells, sellOverflow) = endOfDayUnits.addingReportingOverflow(sellQuantity)
        let (startOfDayUnits, buyOverflow) = withSells.subtractingReportingOverflow(buyQuantity)
        guard endOfDayUnits >= 0, !sellOverflow, !buyOverflow, startOfDayUnits >= 0 else {
            throw FSecurityPnLError.invalidInputs
        }
        return try calculateDailySecurityPnL(startOfDayUnits: startOfDayUnits,
            previousClose: previousClose, buyAmount: trades?.buyAmount ?? .zero,
            sellAmount: trades?.sellAmount ?? .zero, totalFees: trades?.totalFees ?? .zero,
            endOfDayUnits: endOfDayUnits, currentPrice: currentPrice)
    }

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
              trades.isValid(asOf: trades.lastFillTime),
              previousClose > 0, currentPrice > 0,
              previousClose.isFinite, currentPrice.isFinite,
              !buyOverflow, !sellOverflow, expectedEnd >= 0,
              expectedEnd == endOfDayUnits else {
            throw FSecurityPnLError.invalidInputs
        }
        // End market value + sell proceeds - buy consideration - fees - opening market value.
        // This survives an intraday close/reopen and does not depend on episode identity.
        return try calculateDailySecurityPnL(startOfDayUnits: startOfDayUnits,
            previousClose: previousClose, buyAmount: trades.buyAmount,
            sellAmount: trades.sellAmount, totalFees: trades.totalFees,
            endOfDayUnits: endOfDayUnits, currentPrice: currentPrice)
    }

    private static func calculateDailySecurityPnL(startOfDayUnits: Int64,
                                                  previousClose: Decimal,
                                                  buyAmount: Decimal,
                                                  sellAmount: Decimal,
                                                  totalFees: Decimal,
                                                  endOfDayUnits: Int64,
                                                  currentPrice: Decimal) throws -> Decimal {
        guard startOfDayUnits >= 0, endOfDayUnits >= 0,
              previousClose > 0, currentPrice > 0,
              previousClose.isFinite, currentPrice.isFinite,
              buyAmount >= 0, buyAmount.isFinite,
              sellAmount >= 0, sellAmount.isFinite,
              totalFees >= 0, totalFees.isFinite else { throw FSecurityPnLError.invalidInputs }
        let result = Decimal(endOfDayUnits) * currentPrice + sellAmount -
            buyAmount - totalFees - Decimal(startOfDayUnits) * previousClose
        guard result.isFinite else { throw FSecurityPnLError.invalidInputs }
        return result
    }

    public static func episodeUnrealizedPnL(units: Int64, bookCost: Decimal,
                                            currentPrice: Decimal) throws -> Decimal {
        guard units >= 0, bookCost >= 0, currentPrice > 0,
              bookCost.isFinite, currentPrice.isFinite else { throw FSecurityPnLError.invalidInputs }
        let result = Decimal(units) * currentPrice - bookCost
        guard result.isFinite else { throw FSecurityPnLError.invalidInputs }
        return result
    }
}

public enum FSecurityPnLError: Error, Equatable, Sendable {
    case invalidInputs
}
