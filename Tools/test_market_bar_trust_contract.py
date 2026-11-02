from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MarketBarTrustContractTests(unittest.TestCase):
    def test_archived_daily_bars_require_market_specific_upstream_sources(self):
        quality = (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8")
        local_quant = (ROOT / "Sources/FCore/LocalQuantEngine.swift").read_text(encoding="utf-8")
        nas_client = (ROOT / "GuanpanFApp/Sources/FNASConnection.swift").read_text(encoding="utf-8")
        acceptance = (ROOT / "Tests/FCoreTests/LocalQuantEngineTests.swift").read_text(encoding="utf-8")

        self.assertIn("public enum FMarketBarTrustPolicy", quality)
        self.assertIn("isTrustedSecurityDailySource(history.source)", local_quant)
        self.assertIn("isTrustedSecurityDailySource(body.source)", nas_client)
        self.assertIn("isTrustedIndexDailySource(body.source, indexCode: indexCode)", nas_client)
        self.assertIn("testUntrustedDailyHistoryCannotContributeLocalQuantFactors", acceptance)
        self.assertIn("testMarketBarTrustPolicySeparatesNikkeiAndTencentDailySources", acceptance)

    def test_ios_cumulative_volume_reset_is_not_fabricated_as_zero(self):
        parser = (ROOT / "Sources/FCore/MarketMinuteData.swift").read_text(encoding="utf-8")
        acceptance = (ROOT / "Tests/FCoreTests/MarketMinuteDataTests.swift").read_text(encoding="utf-8")
        self.assertIn("delta.isFinite && delta >= 0 ? delta : nil", parser)
        self.assertNotIn("max(Decimal.zero, cumulativeVolume - $0)", parser)
        self.assertIn("testCumulativeVolumeRegressionIsUnknownAndDoesNotBecomeZeroVolume", acceptance)

    def test_live_minute_providers_filter_non_session_rows(self):
        core_parser = (ROOT / "Sources/FCore/MarketMinuteData.swift").read_text(encoding="utf-8")
        app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        acceptance = (ROOT / "Tests/FCoreTests/MarketMinuteDataTests.swift").read_text(encoding="utf-8")

        self.assertIn("FMainlandTradingCalendar.isContinuousSessionTime(at: stamp, timeZone: timeZone)", core_parser)
        eastmoney = app.split("let expectedDay = formatter.string(from: fetchedAt).prefix(10)", 1)[1].split(
            "let samples = byTimestamp.keys.sorted()", 1
        )[0]
        self.assertIn("FMainlandTradingCalendar.isContinuousSessionTime(at: stamp, timeZone: timeZone)", eastmoney)
        self.assertIn("testParserDropsLunchAndAfterHoursRowsButKeepsSessionBoundaries", acceptance)

    def test_chart_explains_unknown_volume_on_the_partial_intraday_average(self):
        chart = (ROOT / "GuanpanFApp/Sources/FUnifiedSecurityChart.swift").read_text(encoding="utf-8")
        self.assertIn("let unknownVolumeCount = samples.filter { $0.volume == nil }.count", chart)
        self.assertIn("成交量未知 \\(unknownVolumeCount) 点", chart)
        summary = chart.split("private func unavailableOverlaySummary", 1)[1].split(
            "private struct FChartSurfaceModifier", 1
        )[0]
        self.assertIn("case .partial(let reason), .stale(let reason): unavailable.append(reason)", summary)


if __name__ == "__main__":
    unittest.main()
