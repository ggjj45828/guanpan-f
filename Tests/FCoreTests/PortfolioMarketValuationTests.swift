import XCTest
@_spi(LedgerStorage) import FCore

final class PortfolioMarketValuationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_798_000_000)

    private func position(_ code: String, units: Int64) -> FPosition {
        FPosition(instrumentCode: code, name: code, units: units, bookCost: 100)
    }

    private func ledger(cash: Decimal, positions: [FPosition], currency: String = "CNY",
                        capturedAt: Date? = nil) throws -> FReadOnlyLedgerSnapshot {
        let snapshotTime = capturedAt ?? now
        let book = FAccountBook(currencyCode: currency,
            openingSnapshot: FAccountOpeningSnapshot(capturedAt: snapshotTime,
                cashBalance: cash, positions: positions),
            cashBalance: cash, positions: positions, updatedAt: snapshotTime)
        return try book.readOnlySnapshot(capturedAt: snapshotTime)
    }

    private func quote(_ code: String, price: String, age: TimeInterval = 1,
                       source: String = FMarketQuoteTrustPolicy.tencentMinuteSource) throws
        -> FCurrentIntradaySnapshot {
        let timestamp = now.addingTimeInterval(-age)
        return try FCurrentIntradaySnapshot(securityCode: code,
            samples: [FMinuteSample(timestamp: timestamp,
                                    price: Decimal(string: price)!, volume: 1)],
            quoteTimestamp: timestamp, fetchedAt: now, source: source)
    }

    func testValuesCashAndEveryFreshHoldingQuoteWithoutMixingCostBasis() throws {
        let ledger = try ledger(cash: Decimal(string: "1500.25")!, positions: [
            position("159352", units: 100), position("510300", units: 200)
        ])
        let result = FPortfolioMarketValuationCalculator.calculate(ledger: ledger, quotes: [
            "159352": try quote("159352", price: "1.234"),
            "510300": try quote("510300", price: "3.456")
        ], at: now)

        guard case .success(let valuation) = result else {
            return XCTFail("Expected a complete current CNY valuation, got \(result)")
        }
        XCTAssertEqual(valuation.cashBalance, Decimal(string: "1500.25"))
        XCTAssertEqual(valuation.holdingsMarketValue, Decimal(string: "814.6"))
        XCTAssertEqual(valuation.totalAssets, Decimal(string: "2314.85"))
        XCTAssertEqual(valuation.quotesAsOf, now.addingTimeInterval(-1))
    }

    func testMissingOneHoldingQuoteRejectsTheWholeTotalInsteadOfShowingPartialValue() throws {
        let ledger = try ledger(cash: 500, positions: [
            position("159352", units: 100), position("510300", units: 200)
        ])
        let result = FPortfolioMarketValuationCalculator.calculate(ledger: ledger, quotes: [
            "159352": try quote("159352", price: "1.234")
        ], at: now)

        XCTAssertEqual(result.failureReason, .missingOrStaleQuotes(["510300"]))
    }

    func testStaleOrUntrustedQuoteCannotContributeToPortfolioValuation() throws {
        let ledger = try ledger(cash: 500, positions: [position("159352", units: 100)])
        let stale = FPortfolioMarketValuationCalculator.calculate(ledger: ledger, quotes: [
            "159352": try quote("159352", price: "1.234", age: 121)
        ], at: now)
        let untrusted = FPortfolioMarketValuationCalculator.calculate(ledger: ledger, quotes: [
            "159352": try quote("159352", price: "1.234", source: "unknown-provider")
        ], at: now)

        XCTAssertEqual(stale.failureReason, .missingOrStaleQuotes(["159352"]))
        XCTAssertEqual(untrusted.failureReason, .missingOrStaleQuotes(["159352"]))
    }

    func testCashOnlyLedgerValuationNeedsNoQuoteAndUnsupportedCurrencyFailsClosed() throws {
        let cashOnly = try ledger(cash: 1250, positions: [])
        let result = FPortfolioMarketValuationCalculator.calculate(
            ledger: cashOnly, quotes: [:], at: now)
        guard case .success(let valuation) = result else {
            return XCTFail("Expected cash-only valuation, got \(result)")
        }
        XCTAssertEqual(valuation.holdingsMarketValue, .zero)
        XCTAssertEqual(valuation.totalAssets, 1250)
        XCTAssertNil(valuation.quotesAsOf)

        XCTAssertThrowsError(try ledger(cash: 1250, positions: [], currency: "USD"),
            "Ledger必须在快照阶段拒绝不支持的币种")
    }

    func testUnrepresentableMarketValueDoesNotOverflowIntoTheDisplayTotal() throws {
        let ledger = try ledger(cash: 500, positions: [position("159352", units: 100)])
        let quote = try FCurrentIntradaySnapshot(securityCode: "159352",
            samples: [FMinuteSample(timestamp: now, price: Decimal.greatestFiniteMagnitude, volume: 1)],
            quoteTimestamp: now, fetchedAt: now, source: FMarketQuoteTrustPolicy.tencentMinuteSource)
        let result = FPortfolioMarketValuationCalculator.calculate(
            ledger: ledger, quotes: ["159352": quote], at: now)

        XCTAssertEqual(result.failureReason, .unrepresentableValue)
    }
}

private extension Result where Failure == FPortfolioMarketValuationUnavailableReason {
    var failureReason: Failure? {
        guard case .failure(let reason) = self else { return nil }
        return reason
    }
}
