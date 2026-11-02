from pathlib import Path
import unittest
import re


ROOT = Path(__file__).resolve().parents[1]


class AdvisorSafetyContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        cls.advisor = (ROOT / "GuanpanFApp/Sources/FAdvisorVerticalSlice.swift").read_text(encoding="utf-8")
        cls.guards = (ROOT / "Sources/FAdvisor/DecisionContext.swift").read_text(encoding="utf-8")
        cls.ledger_snapshot = (ROOT / "Sources/FCore/LedgerSnapshot.swift").read_text(encoding="utf-8")
        cls.daily_summary = (ROOT / "Sources/FCore/DailyTradeSummary.swift").read_text(encoding="utf-8")
        cls.ledger_acceptance = (ROOT / "Tests/FCoreTests/LedgerSchemaTests.swift").read_text(encoding="utf-8")
        cls.research_contract = (ROOT / "Sources/FAdvisor/ResearchEvidence.swift").read_text(encoding="utf-8")
        cls.research_acceptance = (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8")
        cls.settings = (ROOT / "GuanpanFApp/Sources/HomeExperience.swift").read_text(encoding="utf-8")

    def test_advisor_uses_cached_research_and_does_not_wait_for_nas(self):
        start = self.app.index("    private func runAdvisorQuestion(instrumentCode requestedCode: String?) async {")
        end = self.app.index("    func selectInstrument", start)
        flow = self.app[start:end]
        self.assertIn("nasResearchEvidenceByCode[code]", flow)
        background_refresh = (
            "Task {\n"
            "                await refreshNASResearchEvidence(for: targetCodes,\n"
            "                                                 baseAddress: researchBaseAddress,\n"
            "                                                 expectedGeneration: researchGeneration)\n"
            "            }"
        )
        self.assertIn(background_refresh, flow)
        advisor_without_background_refresh = flow.replace(background_refresh, "")
        self.assertIsNone(re.search(
            r"(?m)^\s*await\s+(?:refreshNAS\w*|refreshHistoricalIndexRegimes|FNAS\w*\.fetch\w*)\(",
            advisor_without_background_refresh,
        ))
        self.assertNotIn("refreshHistoricalIndexRegimes()", flow)

        quote_refresh_start = self.app.index("    func refreshMarketData(for requestedCodes: [String]? = nil) async {")
        quote_refresh_end = self.app.index("    private func performMarketRefresh(for code: String) async {",
                                           quote_refresh_start)
        quote_refresh = self.app[quote_refresh_start:quote_refresh_end]
        self.assertIn("FQuoteHTTPClient.fetchMarketReference(code: code)", quote_refresh)
        self.assertNotIn("FNAS", quote_refresh)
        self.assertNotIn("refreshHistoricalIndexRegimes", quote_refresh)

    def test_advisor_prompt_keeps_nas_optional_and_limits_summary_to_fresh_cache(self):
        prompt_start = self.advisor.index('var system = """')
        prompt_end = self.advisor.index('\n        """', prompt_start)
        system_prompt = self.advisor[prompt_start:prompt_end]
        self.assertIn("NAS仅为可选同步、历史归档与研究增强", system_prompt)
        self.assertIn("单次分析绝不请求或等待NAS", system_prompt)
        self.assertIn("历史Quant研究摘要暂不可用", system_prompt)
        self.assertIn("判断变化规则", system_prompt)
        self.assertIn("证券范围只比较同一 instrumentCode", system_prompt)
        self.assertIn("没有可比的同范围历史判断", system_prompt)
        self.assertIn("时间先后不代表因果", system_prompt)
        for field in ("researchGeneratedAt", "dataRange", "sampleCount",
                      "strategyVersion", "freshness"):
            self.assertIn(field, system_prompt)

    def test_decision_memory_freezes_and_filters_the_original_analysis_scope(self):
        memory = (ROOT / "Sources/FAdvisor/DecisionMemory.swift").read_text(encoding="utf-8")
        projection = (ROOT / "Sources/FAdvisor/DecisionMemoryProjection.swift").read_text(encoding="utf-8")
        self.assertIn("scope = advisorRequest?.scope", memory)
        self.assertIn("record.scope == nil || record.scope == scope", projection)
        self.assertIn("entry.scope == nil || entry.scope == scope", projection)
        acceptance = (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8")
        self.assertIn("testDecisionMemoryProjectionKeepsOnlyMatchingExplicitScope", acceptance)

    def test_profile_use_constraint_and_revision_citations_reach_deepseek_and_guard(self):
        entry = (ROOT / "Sources/FAdvisor/AdvisorEntry.swift").read_text(encoding="utf-8")
        self.assertIn("不得据此预测用户下一笔交易", entry)
        self.assertIn("citedInvestorProfileRevisionIDs中逐一引用", entry)
        self.assertIn("if let profileConstraint = request.profileUseConstraint", self.advisor)
        self.assertIn('let citedInvestorProfileRevisionIDs: [UUID]', self.advisor)
        self.assertIn("availableProfileRevisionIDs", self.advisor)
        self.assertIn("citedInvestorProfileRevisionIDs: citedProfileRevisionIDs", self.advisor)
        self.assertIn('"citedInvestorProfileRevisionIDs":[]', self.advisor)
        acceptance = (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8")
        self.assertIn("unknownProfileCandidate", acceptance)

    def test_decoded_profile_projection_retains_and_rechecks_temporary_expiry(self):
        projection = (ROOT / "Sources/FAdvisor/InvestorProfileProjection.swift").read_text(encoding="utf-8")
        acceptance = (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8")
        self.assertIn("public let expiresAt: Date?", projection)
        self.assertIn("(preference.source == .temporary) == (preference.expiresAt != nil)", projection)
        self.assertIn("$0 > asOf", projection)
        self.assertIn("testProfileProjectionRevalidatesTemporaryPreferenceExpiryAfterDecode", acceptance)

    def test_nas_research_qualification_checks_split_counts_and_dates(self):
        for rule in ("independent == training + outOfSample",
                     "trainingStats[\"days\"]?.integerValue == training",
                     "outStats[\"days\"]?.integerValue == outOfSample",
                     "trainingEnd < outStart", "outEnd <= dataEnd",
                     "independent <= maximumIndependentDays"):
            self.assertIn(rule, self.research_contract)
        acceptance = (ROOT / "Tests/FCoreTests/MarketChartAcceptanceTests.swift").read_text(encoding="utf-8")
        self.assertIn("testResearchQualificationRequiresConsistentChronologicalWindows", acceptance)

    def test_advisor_uses_fresh_cached_news_and_never_waits_for_optional_news(self):
        start = self.app.index("    private func runAdvisorQuestion(instrumentCode requestedCode: String?) async {")
        end = self.app.index("    func selectInstrument", start)
        flow = self.app[start:end]
        self.assertIn("cachedNewsFeed?.recent(at: newsCheckedAt)", flow)
        self.assertIn("refreshNewsFeedInBackground(for: targetCodes)", flow)
        self.assertNotIn("await FNewsClient.fetchLatest()", flow)
        self.assertIn("没有新鲜的已缓存新闻；本轮不等待新闻源", flow)
        self.assertLess(flow.index("refreshNewsFeedInBackground(for: targetCodes)"),
                        flow.index("await refreshMarketData(for: targetCodes)"))
        start = self.app.index("    private func refreshNewsFeedInBackground(for targetCodes: [String]) {")
        end = self.app.index("    func configureAndTestNAS(", start)
        background = self.app[start:end]
        self.assertIn("newsRefreshTask = Task", background)
        self.assertIn("try await FNewsClient.fetchLatest()", background)
        self.assertIn("now.timeIntervalSince(lastAttempt) < 120", background)
        feed = (ROOT / "Sources/FCore/NewsData.swift").read_text(encoding="utf-8")
        recent_start = feed.index("    public func recent(at now: Date")
        recent_end = feed.index("\n    }", recent_start) + len("\n    }")
        freshness = feed[recent_start:recent_end]
        self.assertIn("fetchedAt <= now", freshness)
        self.assertIn("article.publishedAt >= cutoff, article.publishedAt <= fetchedAt", freshness)
        self.assertIn("guard !recentArticles.isEmpty else { return nil }", freshness)
        acceptance = (ROOT / "Tests/FCoreTests/NewsFeedTests.swift").read_text(encoding="utf-8")
        for test_name in ("testRecentKeepsOnlyArticlesInsideTheFreshnessWindow",
                          "testRecentRejectsFutureOrExpiredFetchTime",
                          "testRecentRejectsArticlesDatedAfterTheFeedFetch",
                          "testRecentRejectsEmptyAndInvalidFreshnessWindow"):
            self.assertIn(test_name, acceptance)

    def test_advisor_skips_news_network_request_when_there_are_no_target_securities(self):
        start = self.app.index("    private func refreshNewsFeedInBackground(for targetCodes: [String]) {")
        end = self.app.index("    func configureAndTestNAS(", start)
        background = self.app[start:end]
        self.assertIn("guard !targetCodes.isEmpty", background)
        self.assertIn("当前没有目标证券，跳过证券关联快讯", background)
        self.assertLess(background.index("guard !targetCodes.isEmpty"),
                        background.index("newsRefreshTask != nil"))

    def test_nas_derived_caches_are_bound_to_endpoint_and_reject_old_inflight_results(self):
        sync_start = self.app.index("    private func synchronizeNASDataSource(baseAddress: String) -> UInt64 {")
        refresh_start = self.app.index("    private func refreshNASResearchEvidence(for codes: [String], baseAddress: String,", sync_start)
        refresh_end = self.app.index("    func configureAndTestNAS(", refresh_start)
        cache = self.app[sync_start:refresh_end]
        self.assertIn("components.host = components.host?.lowercased()", cache)
        self.assertIn("nasResearchEvidenceByCode.removeAll()", cache)
        self.assertIn("archivedIntradayByCode.removeAll()", cache)
        self.assertIn("dailyKlineByCode.removeAll()", cache)
        self.assertIn("securityRegimeByCode.removeAll()", cache)
        self.assertIn("marketIndexRegimesByCode.removeAll()", cache)
        self.assertIn("regimeMemoryByCode.removeAll()", cache)
        self.assertIn("nasDataGeneration &+= 1", cache)
        self.assertIn("expectedGeneration", cache)
        self.assertIn("synchronizeNASDataSource(\n                    baseAddress: UserDefaults.standard.string", cache)
        self.assertIn("refreshingNASResearchCodes[code] == expectedGeneration", cache)
        self.assertIn('"guanpan.f.regime.memory.v2.\\(namespace).\\(code)"', self.app)
        self.assertIn("guard synchronizeNASDataSource(baseAddress: currentBaseAddress) == generation else { return }",
                      self.app)
        for function_start, function_end in [
            ("    func loadArchivedIntraday(for code: String) async {", "    func refreshDailyKline(for code: String) async {"),
            ("    func refreshDailyKline(for code: String) async {", "    private func researchSummaryStatus("),
        ]:
            operation = self.app[self.app.index(function_start):self.app.index(function_end)]
            self.assertIn("synchronizeNASDataSource(baseAddress: baseAddress)", operation)
            self.assertIn("== generation else { return }", operation)
        archived_start = self.app.index("    func loadArchivedIntraday(for code: String) async {")
        archived_end = self.app.index("    func refreshDailyKline(for code: String) async {", archived_start)
        self.assertIn("current.fetchedAt > archive.fetchedAt", self.app[archived_start:archived_end])
        daily_start = archived_end
        daily_end = self.app.index("    private func researchSummaryStatus(", daily_start)
        self.assertIn("current.fetchedAt > snapshot.fetchedAt", self.app[daily_start:daily_end])
        regime_start = self.app.index("    func refreshHistoricalIndexRegimes() async {")
        regime_end = self.app.index("    private static func isValidSixDigitSecurityCode", regime_start)
        regime_refresh = self.app[regime_start:regime_end]
        self.assertIn("retryForChangedNAS = true", regime_refresh)
        self.assertIn("synchronizeNASDataSource(baseAddress: currentBaseAddress) == generation", regime_refresh)

        start = self.app.index("    private func runAdvisorQuestion(instrumentCode requestedCode: String?) async {")
        end = self.app.index("    func selectInstrument", start)
        flow = self.app[start:end]
        self.assertLess(flow.index("synchronizeNASDataSource(baseAddress: researchBaseAddress)"),
                        flow.index("nasResearchEvidenceByCode[code]"))
        self.assertIn("if currentResearchGeneration != researchGeneration", flow)
        self.assertIn("researchByCode.removeAll()", flow)
        self.assertIn(".onChange(of: nasBaseAddress) { newAddress in", self.settings)
        self.assertIn("model.nasAddressDidChange(newAddress)", self.settings)

    def test_advisor_and_quote_refresh_require_six_ascii_digit_codes(self):
        helper_start = self.app.index("    private static func isValidSixDigitSecurityCode(_ code: String) -> Bool {")
        helper_end = self.app.index("\n    func refreshMarketData(", helper_start)
        helper = self.app[helper_start:helper_end]
        self.assertIn("code.utf8", helper)
        self.assertIn("bytes.count == 6", helper)
        self.assertIn("(48...57).contains($0)", helper)

        advisor_start = self.app.index("    private func runAdvisorQuestion(instrumentCode requestedCode: String?) async {")
        advisor_end = self.app.index("    func selectInstrument", advisor_start)
        advisor = self.app[advisor_start:advisor_end]
        self.assertIn("!Self.isValidSixDigitSecurityCode(focusCode)", advisor)

        refresh_start = self.app.index("    func refreshMarketData(for requestedCodes: [String]? = nil) async {")
        refresh_end = self.app.index("    private func performMarketRefresh", refresh_start)
        refresh = self.app[refresh_start:refresh_end]
        self.assertIn(".filter { Self.isValidSixDigitSecurityCode($0) }", refresh)

    def test_advisor_never_passes_a_stale_cached_quote_as_current_evidence(self):
        start = self.app.index("            let sessionStatus = FMainlandTradingCalendar.status(at: contextCaptureTime)")
        end = self.app.index("                if let feed = newsByCode[code]", start)
        quote_capture = self.app[start:end]
        self.assertIn("quoteMetadata.freshness(at: contextCaptureTime) == .fresh", quote_capture)
        self.assertIn("缓存行情已过期或时点未验证", quote_capture)
        self.assertIn("decimalValue: nil", quote_capture)
        self.assertIn("timestampTrust: .unavailable", quote_capture)

    def test_research_summary_shows_actual_range_and_provenance_fields(self):
        start = self.app.index("    private func researchSummaryStatus(")
        end = self.app.index("    private func regimeMemoryKey", start)
        summary = self.app[start:end]
        for field in ("envelope.generatedAt", "envelope.dataRange",
                      "envelope.qualifiedIndependentDays", "envelope.methodologyVersion",
                      "envelope.strategyVersion", "freshness 有效"):
            self.assertIn(field, summary)
        self.assertIn("schemaVersion == 2", self.research_contract)
        self.assertIn("qualifiedIndependentDays == 0 || dataRange != nil", self.research_contract)
        self.assertIn('"dataRange": dataRange.map', self.research_contract)
        self.assertIn('"strategyVersion": strategyVersion.map', self.research_contract)

    def test_api_key_is_device_only_keychain_data_and_never_shown_in_plain_text(self):
        keychain_start = self.advisor.index("enum FAdvisorAIKeychain {")
        keychain_end = self.advisor.index("enum FNASResearchClient", keychain_start)
        keychain = self.advisor[keychain_start:keychain_end]
        self.assertIn("kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly", keychain)
        self.assertIn("SecItemUpdate", keychain)
        self.assertIn("SecItemAdd", keychain)
        self.assertIn('SecureField("DeepSeek API Key"', self.settings)
        self.assertIn("deepSeekKeyDraft = \"\"", self.settings)
        self.assertNotIn("print(apiKey", self.app + self.advisor)
        self.assertNotIn("debugPrint(apiKey", self.app + self.advisor)

    def test_advisor_sources_contain_no_direct_secret_or_authorization_logging(self):
        for source in (self.app, self.advisor):
            self.assertNotIn("print(", source)
            self.assertNotIn("debugPrint(", source)
            self.assertNotIn("NSLog(", source)

    def test_asset_changing_candidate_requires_fresh_cited_quote_cash_and_units(self):
        start = self.guards.index("public enum FRiskGuard {")
        end = self.guards.index("public enum FAIGuard {", start)
        guard = self.guards[start:end]
        for requirement in ["context.freshQuote(for: code, at: now)",
                            "missingCitedEvidence(freshQuote.id)",
                            "insufficientUnits", "insufficientCash"]:
            self.assertIn(requirement, guard)

        self.assertIn("context.strategyQualificationGrants", guard)
        self.assertIn("grant.authorizes($0, securityCode: code, regime: regimeEvidence.regime, at: now)", guard)
        self.assertIn("enum FQuantStrategyQualificationEvidence", self.guards)
        self.assertNotIn("public static func observation(securityCode:", self.guards)
        self.assertIn("strategyQualificationGrants = []", self.guards)
        self.assertIn("runtime authorization grant is deliberately never serialized", self.guards)
        self.assertIn("缺少新鲜、合格且版本可追溯的本地 Quant 策略资格证据", self.guards)
        self.assertIn("FContextObservation(\n            dataClass: .quantState, subject: \"strategy-qualification:159352\"",
                      self.research_acceptance)
        self.assertIn("伪造资格标记", self.research_acceptance)
        self.assertIn("Runtime qualification grants must not survive archive/JSON decoding",
                      self.research_acceptance)
        self.assertNotIn("requiresRealtimeQuant", self.app)

    def test_shadow_snapshot_records_actual_guard_verdict_and_defaults_denied(self):
        start = self.app.index("                    let shadowSnapshot = try FCandidateShadowSnapshot(")
        end = self.app.index("                    try await candidateShadowJournalStore.append", start)
        call = self.app[start:end]
        self.assertIn("guardAllowed: assessment.guardResult.allowedForReview", call)
        shadow = (ROOT / "Sources/FAdvisor/CandidateShadowScorecard.swift").read_text(encoding="utf-8")
        self.assertIn("guardAllowed: Bool = false", shadow)

    def test_guard_denied_candidate_is_not_rendered_as_reviewable_or_confirmable(self):
        card_start = self.settings.index("private struct FAdvisorResultCard")
        start = self.settings.index("            if result.isReviewable {", card_start)
        end = self.settings.index('            Text("真实资产只能在用户确认真实成交后变化', start)
        card = self.settings[start:end]
        reviewable, denied = card.split(
            "\n            } else {\n", 1)
        self.assertIn('Text("Candidate Plan · 仅供用户审阅")', reviewable)
        self.assertIn('accessibilityIdentifier("advisor.confirm-real-fill")', reviewable)
        self.assertIn('Text("Guard 已阻止此候选计划")', denied)
        self.assertNotIn("candidateDescription", denied)
        self.assertNotIn('advisor.confirm-real-fill', denied)

    def test_unrepresentable_nonempty_daily_pnl_is_not_described_as_zero_or_no_trades(self):
        self.assertIn(
            "dailyTradeSummaries非空但dailyPortfolioRealizedPnL为null",
            self.advisor)
        self.assertIn("组合日已实现盈亏合计不可表示/Unavailable", self.advisor)
        self.assertIn("不得解释为0或无成交", self.advisor)

    def test_decoded_daily_summary_rejects_impossible_side_totals(self):
        for invariant in [
            "fillCountAsQuantity <= totalQuantity",
            "buyQuantity == 0 ? buyAmount == 0 && buyFees == 0 : buyAmount > 0",
            "sellQuantity == 0 ? sellAmount == 0 && sellFees == 0 : sellAmount > 0",
            "sellQuantity > 0 || realizedPnL == 0",
        ]:
            self.assertIn(invariant, self.daily_summary)
        self.assertIn("testDecodedDailyTradeSummaryRejectsAmountWithoutMatchingSideQuantity",
                      self.ledger_acceptance)
        self.assertIn("testDecisionContextRejectsTamperedDailyTradeSummaryAfterDecoding",
                      self.ledger_acceptance)

    def test_advisor_waits_for_an_existing_shared_live_quote_refresh(self):
        start = self.app.index("    func refreshMarketData(for requestedCodes: [String]? = nil) async {")
        end = self.app.index("    func isInWatchlist(", start)
        refresh = self.app[start:end]
        self.assertIn("private var marketRefreshTasks: [String: Task<Void, Never>]", self.app)
        self.assertIn("for code in codes where marketRefreshTasks[code] == nil", refresh)
        self.assertIn("let activeTasks = codes.compactMap { marketRefreshTasks[$0] }", refresh)
        self.assertIn("for task in activeTasks { await task.value }", refresh)
        self.assertIn("private func performMarketRefresh(for code: String) async", refresh)
        stale_guard = refresh.index("guard isNewerThanCache else")
        shadow_write = refresh.index("appendMarketObservation(observation)")
        self.assertLess(stale_guard, shadow_write)

    def test_index_regime_is_not_attributed_to_a_security_without_a_mapping(self):
        self.assertIn("securityMapping=Unavailable", self.app)
        self.assertIn("禁止把该指数状态归到目标ETF", self.advisor)
        self.assertIn("不推断该指数与持仓证券的对应关系", self.app)
        self.assertIn("FMarketIndexSecurityMappingRegistry.mapping(for: code)", self.app)
        self.assertIn('subject: "mapped-index:\\(code)"', self.app)
        self.assertIn("contextRole=benchmark_only", self.app)
        self.assertIn("not_strategy_qualification=true", self.app)
        self.assertIn("ETF本地价格、IOPV/溢价与成交/流动性事实分别判断", self.advisor)
        self.assertIn("testETFIndexMappingRegistryIsExplicitAndIssuerSourced",
                      (ROOT / "Tests/FCoreTests/MarketRegimeEngineTests.swift").read_text(encoding="utf-8"))
        mapping = (ROOT / "Sources/FCore/MarketRegimeEngine.swift").read_text(encoding="utf-8")
        self.assertIn('securityCode: "159352", indexCode: "sh000510", indexName: "中证A500"', mapping)
        self.assertIn('securityCode: "159941", indexCode: "usNDX", indexName: "Nasdaq-100"', mapping)

    def test_mapped_market_regime_is_a_local_quant_and_risk_guard_gate(self):
        local_quant = (ROOT / "Sources/FCore/LocalQuantEngine.swift").read_text(encoding="utf-8")
        mapped_start = self.guards.index("private struct FDecisionMappedBenchmarkEvidence")
        mapped_end = self.guards.index("public struct FCandidateRecommendation", mapped_start)
        mapped_evidence = self.guards[mapped_start:mapped_end]
        self.assertIn("mapped_benchmark_unavailable", local_quant)
        self.assertIn("mapped_benchmark_severe_risk", local_quant)
        self.assertIn("FDecisionMappedBenchmarkEvidence.find(", self.guards)
        self.assertIn("缺失、过期或来源不匹配", self.guards)
        self.assertIn("testMappedETFBuyRequiresFreshOrderedBenchmarkAndBlocksSevereMappedRisk",
                      (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8"))
        self.assertIn("FMarketRegimeEngine.allowedStrategies(for: regime", self.guards)
        self.assertIn("qualificationID:", (ROOT / "Sources/FCore/MarketRegimeEngine.swift").read_text(encoding="utf-8"))
        self.assertIn("testMappedETFBuyRequiresStrategyAllowedByBothRegimes",
                      (ROOT / "Tests/FCoreTests/BoundaryAcceptanceTests.swift").read_text(encoding="utf-8"))
        self.assertIn("dataAsOf <= observedAt, dataAsOf <= observation.capturedAt", mapped_evidence)

    def test_advisor_requires_fresh_underlying_bars_for_security_and_index_regimes(self):
        self.assertIn("private static func isMarketRegimeDataFresh(_ assessment: FMarketRegimeAssessment, at now: Date)",
                      self.app)
        self.assertIn("return now.timeIntervalSince(dataAsOf) <= 5 * 86_400", self.app)
        self.assertIn("Self.isMarketRegimeDataFresh(regime, at: contextCaptureTime)", self.app)
        self.assertGreaterEqual(
            self.app.count("Self.isMarketRegimeDataFresh(regime, at: contextCaptureTime)"), 2)

    def test_risk_guard_rejects_regime_data_newer_than_its_observation_capture(self):
        self.assertIn("dataAsOf <= observationTime", self.guards)
        self.assertIn("dataAsOf <= observation.capturedAt", self.guards)
        self.assertIn("regimeTimeInFutureOfItsObservation", self.research_acceptance)

    def test_unrepresentable_ledger_and_advisor_totals_fail_closed(self):
        self.assertIn("history.lifetimeRealizedProfit.isFinite", self.ledger_snapshot)
        self.assertIn("entry.cashDelta.isFinite", self.ledger_snapshot)
        self.assertIn("throw FLedgerSnapshotError.unrepresentablePositionHistory", self.ledger_snapshot)
        self.assertIn("FDecisionFinancialMath.add(episodeRealized, episodeUnrealized)", self.guards)
        self.assertIn("FDecisionFinancialMath.add(lifetimeRealized, lifetimeUnrealized)", self.guards)
        self.assertIn("guard total.isFinite else { return nil }", self.guards)

    def test_iphone_rejects_research_sample_count_above_complete_coverage(self):
        self.assertIn('sessionCoverage.keys.allSatisfy(Self.nonBlank)', self.research_contract)
        self.assertIn('qualifiedIndependentDays <= (sessionCoverage["complete"] ?? 0)',
                      self.research_contract)
        self.assertIn("testResearchEvidenceRejectsQualifiedDaysAboveCompleteCoverage",
                      self.research_acceptance)
        self.assertIn("testResearchDigestMatchesNASAtHalfMillisecondTimestamps",
                      self.research_acceptance)
        self.assertIn("qualifiedIndependentDays == 0 || timezone != nil", self.research_contract)
        self.assertIn("TimeZone(identifier: $0) != nil", self.research_contract)
        self.assertIn("testQualifiedResearchEvidenceRequiresAValidTimeZone", self.research_acceptance)

    def test_risk_guard_requires_fresh_security_regime_and_blocks_severe_buy_risk(self):
        self.assertIn("private struct FDecisionMarketRegimeEvidence", self.guards)
        self.assertIn('observation.subject == securityCode && observation.source == "FCore Market Regime Engine"',
                      self.guards)
        self.assertIn("now.timeIntervalSince(dataAsOf) <= 5 * 86_400", self.guards)
        self.assertIn("FDecisionMarketRegimeEvidence.find(", self.guards)
        self.assertIn("regimeEvidence.risk >= .r3Severe", self.guards)
        self.assertIn(".riskOff, .extremeRisk, .uncertain, .dataUnreliable", self.guards)
        self.assertIn("candidate.citedObservationIDs.contains(regimeEvidence.observation.id)", self.guards)
        self.assertIn("testRiskGuardRequiresFreshMatchingRegimeAndBlocksSevereBuyRisk", self.research_acceptance)
        self.assertIn("metadata[\"regime\"] == regime.rawValue", self.guards)
        self.assertIn("$0.securityCode == code && $0.regime == regimeEvidence.regime", self.guards)
        self.assertIn("regime: FMarketRegime, strategyID: String", self.guards)
        self.assertIn("震荡策略资格不得用于牛市", self.research_acceptance)
        self.assertIn("price > currentPrice", self.guards)
        self.assertIn("为避免追价", self.guards)
        self.assertIn("testRiskGuardRejectsBuyLimitAboveLatestPriceAsChasing", self.research_acceptance)
        self.assertIn("guard candidates.count == 1, let observation = candidates.first", self.guards)
        self.assertIn("conflictingRegime", self.research_acceptance)


if __name__ == "__main__":
    unittest.main()
