from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MainlandFundTradingRulesContractTests(unittest.TestCase):
    def test_rules_are_enforced_before_any_asset_change_candidate_is_reviewable(self):
        source = (ROOT / "Sources/FAdvisor/DecisionContext.swift").read_text(encoding="utf-8")
        guard = source.split("public enum FRiskGuard", 1)[1].split("private func strategyID", 1)[0]
        self.assertIn("FMainlandFundTradingRules.isValidBuyUnits(units)", guard)
        self.assertIn("FMainlandFundTradingRules.isValidSellUnits(units, currentHolding: holdingUnits)", guard)
        self.assertIn("FMainlandFundTradingRules.isValidLimitPrice(price)", guard)

    def test_policy_covers_standard_fund_lots_price_increment_and_odd_lot_exit(self):
        source = (ROOT / "Sources/FCore/MainlandFundTradingRules.swift").read_text(encoding="utf-8")
        for requirement in (
            "minimumOrderUnits: Int64 = 100",
            "maximumOrderUnits: Int64 = 1_000_000",
            'Decimal(string: "0.001")',
            "units == currentHolding",
            "NSDecimalRound(&rounded, &input, 3, .plain)",
        ):
            self.assertIn(requirement, source)
        tests = (ROOT / "Tests/FCoreTests/MainlandFundTradingRulesTests.swift").read_text(encoding="utf-8")
        self.assertIn("testSellAllowsLotMultiplesOrEntireOddLotRemainderOnly", tests)
        self.assertIn("testLimitPriceMustUseOneThousandthYuanIncrement", tests)

    def test_risk_guard_regressions_reject_invalid_lot_and_tick(self):
        tests = (ROOT / "Tests/FCoreTests/MarketChartAcceptanceTests.swift").read_text(encoding="utf-8")
        self.assertIn("let fractionalLot = FCandidateRecommendation", tests)
        self.assertIn("let fractionalPrice = FCandidateRecommendation", tests)

    def test_realtime_trigger_plan_reuses_the_same_lot_and_tick_policy(self):
        trigger = (ROOT / "Sources/FCore/RealtimeQuantTrigger.swift").read_text(encoding="utf-8")
        self.assertIn("FMainlandFundTradingRules.isValidLimitPrice(lowerPrice)", trigger)
        self.assertIn("FMainlandFundTradingRules.isValidLimitPrice(upperPrice)", trigger)
        self.assertIn("FMainlandFundTradingRules.isValidOrderUnits(suggestedQuantity)", trigger)
        decoder = trigger.split("public init(from decoder: Decoder) throws", 1)[1].split(
            "/// Latest verified exchange quote", 1
        )[0]
        self.assertIn("try self.init(", decoder)
        self.assertIn("suggestedQuantity: values.decode(Int64.self, forKey: .suggestedQuantity)", decoder)
        acceptance = (ROOT / "Tests/FCoreTests/RealtimeQuantTriggerTests.swift").read_text(encoding="utf-8")
        self.assertIn("testTriggerPlansRejectInvalidFundOrderLotsAndPriceTicks", acceptance)
        self.assertIn("testDecodedTriggerPlansRevalidateOrderRulesAndPriceZone", acceptance)
