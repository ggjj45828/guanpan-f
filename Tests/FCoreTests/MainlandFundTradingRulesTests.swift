import XCTest
@testable import FCore

final class MainlandFundTradingRulesTests: XCTestCase {
    func testBuyOrdersUseHundredUnitLotsAndOneMillionMaximum() {
        XCTAssertTrue(FMainlandFundTradingRules.isValidBuyUnits(100))
        XCTAssertTrue(FMainlandFundTradingRules.isValidBuyUnits(1_000_000))
        XCTAssertFalse(FMainlandFundTradingRules.isValidBuyUnits(1))
        XCTAssertFalse(FMainlandFundTradingRules.isValidBuyUnits(150))
        XCTAssertFalse(FMainlandFundTradingRules.isValidBuyUnits(1_000_100))
    }

    func testSellAllowsLotMultiplesOrEntireOddLotRemainderOnly() {
        XCTAssertTrue(FMainlandFundTradingRules.isValidSellUnits(100, currentHolding: 250))
        XCTAssertTrue(FMainlandFundTradingRules.isValidSellUnits(250, currentHolding: 250))
        XCTAssertFalse(FMainlandFundTradingRules.isValidSellUnits(150, currentHolding: 250))
        XCTAssertFalse(FMainlandFundTradingRules.isValidSellUnits(300, currentHolding: 250))
        XCTAssertFalse(FMainlandFundTradingRules.isValidSellUnits(0, currentHolding: 250))
    }

    func testLimitPriceMustUseOneThousandthYuanIncrement() {
        XCTAssertTrue(FMainlandFundTradingRules.isValidLimitPrice(Decimal(string: "1.234")!))
        XCTAssertTrue(FMainlandFundTradingRules.isValidLimitPrice(Decimal(string: "0.001")!))
        XCTAssertFalse(FMainlandFundTradingRules.isValidLimitPrice(Decimal(string: "1.2345")!))
        XCTAssertFalse(FMainlandFundTradingRules.isValidLimitPrice(Decimal.zero))
    }
}
