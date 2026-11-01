from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DailyHistoryWiringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        cls.settings = (ROOT / "GuanpanFApp/Sources/HomeExperience.swift").read_text(encoding="utf-8")
        cls.nas_client = (ROOT / "GuanpanFApp/Sources/FNASConnection.swift").read_text(encoding="utf-8")
        cls.api = (ROOT / "nas/fminute/http_api.py").read_text(encoding="utf-8")
        cls.provider = (ROOT / "nas/fminute/index_history.py").read_text(encoding="utf-8")
        cls.minute_provider = (ROOT / "nas/fminute/providers.py").read_text(encoding="utf-8")
        cls.market_quality = (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8")

    def test_security_daily_kline_uses_nas_and_live_quote_path_remains_separate(self):
        start = self.app.index("    func refreshDailyKline(for code: String) async {")
        end = self.app.index("    private func researchSummaryStatus", start)
        refresh = self.app[start:end]
        self.assertIn("FNASecurityDailyHistoryClient.fetch", refresh)
        self.assertNotIn("FQuoteHTTPClient.fetchDailyKline", refresh)
        self.assertIn("func refreshMarketData", self.app)

    def test_ios_nas_reader_validates_identity_freshness_and_real_daily_bars(self):
        self.assertIn('"/api/v1/security-daily-history"', self.nas_client)
        self.assertIn("body.securityCode == securityCode", self.nas_client)
        self.assertIn("body.status == \"available\"", self.nas_client)
        self.assertIn("body.sampleCount == body.bars.count", self.nas_client)
        self.assertIn("Date().timeIntervalSince(fetchedAt) <= 36 * 60 * 60", self.nas_client)
        self.assertIn("row.tradingDate < todayText", self.nas_client)
        self.assertIn("maximumCompletedBarAge", self.nas_client)
        self.assertIn("latestBar.tradingDate <= Date()", self.nas_client)
        self.assertIn("now.timeIntervalSince(latestBar.tradingDate) <= maximumDailyBarAge",
                      (ROOT / "Sources/FCore/LocalQuantEngine.swift").read_text(encoding="utf-8"))

    def test_nas_endpoint_and_provider_are_allowlisted_archived_and_fail_explicitly(self):
        self.assertIn('if parsed.path == "/api/v1/security-daily-history":', self.api)
        self.assertIn("archive.get_security_history(query[\"securityCode\"])", self.api)
        self.assertIn("SECURITY_CODE.fullmatch(security_code)", self.provider)
        self.assertIn('"stale"', self.provider)
        self.assertIn("MAX_DAILY_BAR_AGE = timedelta(days=5)", self.provider)
        self.assertIn("self._latest_bar_fresh(index_code, rows, now)", self.provider)
        self.assertIn("self._latest_bar_fresh(code, rows, now)", self.provider)
        self.assertIn('"insufficient"', self.provider)
        self.assertIn('"unavailable"', self.provider)

    def test_nas_http_bodies_are_bounded_while_streaming(self):
        bounded = (ROOT / "GuanpanFApp/Sources/FBoundedHTTPClient.swift").read_text(encoding="utf-8")
        self.assertIn("URLSession.shared.bytes(for: request)", bounded)
        self.assertIn("http.expectedContentLength > Int64(maximumResponseBytes)", bounded)
        self.assertIn("for try await byte in bytes", bounded)
        self.assertIn("FBoundedHTTPClientError.responseTooLarge", bounded)
        self.assertNotIn("URLSession.shared.data(for: request)", self.nas_client)
        self.assertEqual(self.nas_client.count("FBoundedHTTPClient.data(for: request, maximumResponseBytes: 4_000_000)"), 5)

    def test_all_app_http_responses_are_streamed_with_endpoint_limits(self):
        app_sources = list((ROOT / "GuanpanFApp/Sources").glob("*.swift"))
        combined = "\n".join(path.read_text(encoding="utf-8") for path in app_sources)
        self.assertNotIn("URLSession.shared.data(for:", combined)
        self.assertIn("maximumResponseBytes: 2_000_000", combined)  # DeepSeek / research
        self.assertIn("maximumResponseBytes: 128_000", combined)  # index quote endpoints
        self.assertIn("maximumResponseBytes: 128_000", combined)  # bounded live quote endpoints
        self.assertIn("maximumResponseBytes: 4_000_000", combined)  # NAS history

    def test_index_history_reader_enforces_expected_market_timezone(self):
        start = self.nas_client.index("enum FNASIndexDailyHistoryClient {")
        end = self.nas_client.index("enum FNASHistoricalMinuteClient", start)
        reader = self.nas_client[start:end]
        for code, timezone_name in (
            ("sh000001", "Asia/Shanghai"), ("sz399001", "Asia/Shanghai"),
            ("sh000300", "Asia/Shanghai"), ("sz399006", "Asia/Shanghai"),
            ("sh000510", "Asia/Shanghai"),
            ("usNDX", "America/New_York"), ("hkHSI", "Asia/Hong_Kong"),
            ("int_nikkei", "Asia/Tokyo"), ("KOSPI", "Asia/Seoul"),
        ):
            self.assertIn(f'"{code}": "{timezone_name}"', reader)
            self.assertIn(f'"{code}": "{timezone_name}"', self.provider)
        self.assertIn("guard let expectedTimeZone = supportedTimeZones[indexCode] else", reader)
        self.assertIn("body.timezone == expectedTimeZone", reader)
        self.assertIn("该指数尚无经过验证的历史日K来源", reader)
        self.assertIn("MultiMarketDailyProvider(TencentIndexDailyProvider(), NikkeiDailyCloseProvider(),",
                      (ROOT / "nas/fminute/runtime.py").read_text(encoding="utf-8"))
        self.assertIn("Nikkei Indexes official daily close CSV", self.provider)
        self.assertIn("Naver Finance KOSPI daily chart (public web endpoint)", self.provider)
        self.assertIn('if index_code == "KOSPI":\n            return self.naver.name', self.provider)
        self.assertIn("KOSPI history uses Naver Finance's public daily-chart endpoint",
                      (ROOT / "nas/DEPLOYMENT.md").read_text(encoding="utf-8"))
        self.assertIn("def source_name", self.provider)
        self.assertIn('getattr(self.provider, "source_name"', self.provider)
        self.assertIn("fallback_source", self.provider)
        self.assertIn("rawOHLCVPresent.allSatisfy({ !$0 })", reader)
        self.assertIn("parsedOHLCV.allSatisfy({ $0 != nil })", reader)
        decimal_parser = reader.split("private static func decimal(_ raw: String)", 1)[1]
        self.assertIn("value.isFinite", decimal_parser)
        self.assertIn("NSDecimalNumber(decimal: value).doubleValue.isFinite", decimal_parser)


    def test_archived_index_daily_returns_feed_synchronized_regime_benchmarks(self):
        self.assertIn("benchmarkObservations: benchmarks", self.app)
        self.assertIn("latestBar.close / previousBar.close - 1", self.app)
        self.assertIn("observedAt: latestBar.timestamp, sessionStartAt: previousBar.timestamp", self.app)
        self.assertIn("capturedAt: peerHistory.fetchedAt", self.app)
        self.assertIn(r'marketContext: "index:\(result.code)"', self.app)
        self.assertIn("FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource",
                      (ROOT / "Sources/FCore/MarketRegimeEngine.swift").read_text(encoding="utf-8"))
        self.assertIn("peers are derived only", self.app.lower())

    def test_nas_minute_quality_failure_cannot_be_marked_complete(self):
        start = self.nas_client.index("private static func makeArchive(body:")
        end = self.nas_client.index("private static func fetchLegacyB", start)
        reader = self.nas_client[start:end]
        self.assertIn("let qualityFailed = body.coverage?.qualityPassed == false", reader)
        self.assertIn("coverage.qualityPassed == true", reader)
        self.assertIn("coverage.completenessPassed == true", reader)
        self.assertIn("coverage.volumePassed == true", reader)
        self.assertIn("let needsDowngrade = discardedCount > 0 || missingProvenance || !coverageConsistent", reader)
        self.assertIn("qualityFailed ?", reader)

    def test_nas_minute_reader_rejects_future_bar_and_fetch_timestamps(self):
        start = self.nas_client.index("private static func makeArchive(body:")
        end = self.nas_client.index("private static func fetchLegacyB", start)
        reader = self.nas_client[start:end]
        self.assertIn("let validationTime = Date()", reader)
        self.assertIn("stamp <= validationTime", reader)
        self.assertIn("guard let fetchedAt = parseTimestamp(fetchedAtText)", reader)
        self.assertIn("fetchedAt >= stamp, fetchedAt <= validationTime else { return nil }", reader)
        self.assertIn("bar.minuteVolume.map { $0 >= 0 }", reader)

    def test_nas_minute_reader_rejects_unknown_archived_provider_sources(self):
        start = self.nas_client.index("private static func makeArchive(body:")
        end = self.nas_client.index("private static func fetchLegacyB", start)
        reader = self.nas_client[start:end]
        self.assertIn("FMarketBarTrustPolicy.isTrustedMinuteArchiveSource(bar.source)", reader)
        self.assertIn("来源未验证或采集时间缺失，降为Partial", reader)

    def test_ios_archive_allowlist_matches_actual_nas_minute_provider_names(self):
        self.assertIn('"Tencent Finance minute/query (public web endpoint)"', self.market_quality)
        self.assertIn('"Eastmoney push2his 1-minute kline (public web endpoint)"', self.market_quality)
        self.assertIn('name = "Tencent Finance minute/query (public web endpoint)"', self.minute_provider)
        self.assertIn('name = "Eastmoney push2his 1-minute kline (public web endpoint)"', self.minute_provider)

    def test_nas_complete_minute_state_requires_consistent_coverage_metadata(self):
        start = self.nas_client.index("private static func makeArchive(body:")
        end = self.nas_client.index("private static func fetchLegacyB", start)
        reader = self.nas_client[start:end]
        for required in [
            'coverage.status?.lowercased() == "complete"',
            "coverage.qualityPassed == true",
            "coverage.completenessPassed == true",
            "coverage.volumePassed == true",
            "let expected = coverage.expectedCount, expected > 0",
            "let observed = coverage.observedCount, observed == expected",
            "observed == expected",
            "observed == body.bars.count",
            "let missing = coverage.missingTimestamps, missing.isEmpty",
        ]:
            self.assertIn(required, reader)
        self.assertIn("!coverageConsistent", reader)
        self.assertIn("完整度元数据缺失或不一致，降为Partial", reader)

    def test_settings_describes_realtime_and_historical_sources_separately(self):
        self.assertIn('LabeledContent("实时行情", value: "iPhone 直连公开行情源")', self.settings)
        self.assertIn('LabeledContent("证券历史日 K", value: nasBaseAddress.isEmpty ? "需配置 NAS" : "通过 NAS 读取归档")',
                      self.settings)
        self.assertIn('LabeledContent("NAS 后台历史采集"', self.settings)
        self.assertNotIn('LabeledContent("实时分钟 / 日 K", value: "腾讯公开行情接口")', self.settings)

    def test_ready_status_includes_worker_health_and_daily_history_coverage(self):
        self.assertIn("let realtimeWorker: Worker?", self.nas_client)
        self.assertIn("let backfillWorker: Worker?", self.nas_client)
        self.assertIn("let indexDailyHistory: HistoryCollection?", self.nas_client)
        self.assertIn("let securityDailyHistory: HistoryCollection?", self.nas_client)
        self.assertIn("operationalSummary", self.nas_client)
        self.assertIn("items.values.filter { $0.status == \"available\" }.count", self.nas_client)


if __name__ == "__main__":
    unittest.main()
