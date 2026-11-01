import Foundation

public struct FPortfolioMarketValuation: Equatable, Sendable {
    public let cashBalance: Decimal
    public let holdingsMarketValue: Decimal
    public let totalAssets: Decimal
    /// The oldest quote used, so the displayed valuation never implies a later
    /// observation time than every included holding actually has.
    public let quotesAsOf: Date?
}

public enum FPortfolioMarketValuationUnavailableReason: Error, Equatable, Sendable {
    case ledgerUnavailable
    case invalidSnapshotTime
    case unsupportedCurrency(String)
    case invalidCashBalance
    case invalidPosition(String)
    case missingOrStaleQuotes([String])
    case unrepresentableValue
}

/// Calculates a cash-plus-holdings market estimate only when every real holding
/// has a trusted, fresh quote. It never returns a partial portfolio total.
public enum FPortfolioMarketValuationCalculator {
    public static func calculate(
        ledger: FReadOnlyLedgerSnapshot,
        quotes: [String: FCurrentIntradaySnapshot],
        at now: Date,
        maximumQuoteAge: TimeInterval = FQuoteTemporalMetadata.defaultMaximumAge
    ) -> Result<FPortfolioMarketValuation, FPortfolioMarketValuationUnavailableReason> {
        guard now.timeIntervalSince1970.isFinite,
              ledger.capturedAt.timeIntervalSince1970.isFinite,
              ledger.capturedAt <= now,
              maximumQuoteAge.isFinite, maximumQuoteAge >= 0 else {
            return .failure(.invalidSnapshotTime)
        }
        guard ledger.currencyCode == "CNY" else {
            return .failure(.unsupportedCurrency(ledger.currencyCode))
        }
        guard ledger.cashBalance.isFinite, ledger.cashBalance >= 0 else {
            return .failure(.invalidCashBalance)
        }

        var seenCodes = Set<String>()
        for position in ledger.positions {
            let codeIsValid = position.instrumentCode.utf8.count == 6 &&
                position.instrumentCode.utf8.allSatisfy { (48...57).contains($0) }
            guard codeIsValid, position.units > 0,
                  seenCodes.insert(position.instrumentCode).inserted else {
                return .failure(.invalidPosition(position.instrumentCode))
            }
        }

        var missingOrStaleCodes: [String] = []
        var holdingsMarketValue = Decimal.zero
        var valuationTimestamps: [Date] = []
        for position in ledger.positions {
            guard let quote = quotes[position.instrumentCode],
                  quote.securityCode == position.instrumentCode,
                  quote.temporalMetadata().freshness(at: now, maximumAge: maximumQuoteAge) == .fresh,
                  let price = quote.latestPrice, price.isFinite, price > 0 else {
                missingOrStaleCodes.append(position.instrumentCode)
                continue
            }

            var units = Decimal(position.units)
            var unitPrice = price
            var positionValue = Decimal.zero
            let multiplyStatus = NSDecimalMultiply(&positionValue, &units, &unitPrice, .plain)
            guard multiplyStatus == .noError, positionValue.isFinite, positionValue >= 0 else {
                return .failure(.unrepresentableValue)
            }
            var runningTotal = holdingsMarketValue
            var nextValue = Decimal.zero
            let addStatus = NSDecimalAdd(&nextValue, &runningTotal, &positionValue, .plain)
            guard addStatus == .noError, nextValue.isFinite, nextValue >= 0 else {
                return .failure(.unrepresentableValue)
            }
            holdingsMarketValue = nextValue
            valuationTimestamps.append(quote.quoteTimestamp)
        }
        guard missingOrStaleCodes.isEmpty else {
            return .failure(.missingOrStaleQuotes(missingOrStaleCodes.sorted()))
        }

        var cash = ledger.cashBalance
        var holdings = holdingsMarketValue
        var totalAssets = Decimal.zero
        let totalStatus = NSDecimalAdd(&totalAssets, &cash, &holdings, .plain)
        guard totalStatus == .noError, totalAssets.isFinite, totalAssets >= 0 else {
            return .failure(.unrepresentableValue)
        }
        return .success(FPortfolioMarketValuation(
            cashBalance: ledger.cashBalance,
            holdingsMarketValue: holdingsMarketValue,
            totalAssets: totalAssets,
            quotesAsOf: valuationTimestamps.min()))
    }
}
