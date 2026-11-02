from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MarketQuoteTrustContractTests(unittest.TestCase):
    def test_decision_grade_quotes_are_limited_to_configured_provider_sources(self):
        quality = (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8")
        minute_data = (ROOT / "Sources/FCore/MarketMinuteData.swift").read_text(encoding="utf-8")
        app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        acceptance = (ROOT / "Tests/FCoreTests/MarketChartAcceptanceTests.swift").read_text(encoding="utf-8")

        self.assertIn("public enum FMarketQuoteTrustPolicy", quality)
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted(source)", quality)
        self.assertIn("return FMarketQuoteTrustPolicy.isTrusted(source) ? label", quality)
        index_quote = app[app.index("struct FMarketIndexQuote:"):app.index("typealias FHomeLedgerState")]
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted(source)", index_quote)
        self.assertIn("FMarketQuoteTrustPolicy.tencentMinuteSource", minute_data)
        self.assertIn("previousCumulativeVolume = nil", minute_data)
        self.assertIn("testMissingCumulativeVolumeBreaksDeltaContinuity", (
            ROOT / "Tests/FCoreTests/MarketMinuteDataTests.swift").read_text(encoding="utf-8"))
        for source in ["tencentMinuteSource", "eastmoneyMinuteSource",
                       "tencentReferenceSource", "sinaIndexSource", "naverIndexSource"]:
            self.assertIn(f"public static let {source} =", quality)
        self.assertIn("testUnknownProviderCannotBecomeDecisionGradeByUsingFreshTimestamp", acceptance)


if __name__ == "__main__":
    unittest.main()
