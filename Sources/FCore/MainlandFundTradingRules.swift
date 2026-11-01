import Foundation

/// Common auction order constraints for exchange-traded fund units on the
/// Shanghai and Shenzhen markets. Product-specific price limits and exceptions
/// remain unavailable until a verified per-security rule source is connected.
public enum FMainlandFundTradingRules {
    public static let minimumOrderUnits: Int64 = 100
    public static let maximumOrderUnits: Int64 = 1_000_000
    public static let minimumPriceIncrement = Decimal(string: "0.001")!

    public static func isValidBuyUnits(_ units: Int64) -> Bool {
        isValidOrderUnits(units)
    }

    public static func isValidOrderUnits(_ units: Int64) -> Bool {
        units > 0 && units <= maximumOrderUnits && units.isMultiple(of: minimumOrderUnits)
    }

    public static func isValidSellUnits(_ units: Int64, currentHolding: Int64) -> Bool {
        guard units > 0, units <= maximumOrderUnits, units <= currentHolding else { return false }
        return units.isMultiple(of: minimumOrderUnits) || units == currentHolding
    }

    public static func isValidLimitPrice(_ price: Decimal) -> Bool {
        guard price.isFinite, price > 0 else { return false }
        var input = price
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &input, 3, .plain)
        return rounded == price
    }
}
