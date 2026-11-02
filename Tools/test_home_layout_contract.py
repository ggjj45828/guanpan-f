from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class HomeLayoutContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.home = (ROOT / "GuanpanFApp/Sources/HomeExperience.swift").read_text(encoding="utf-8")
        cls.ui_tests = (ROOT / "GuanpanFApp/UITests/PrimaryNavigationUITests.swift").read_text(encoding="utf-8")
        cls.app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        cls.manifest = (ROOT / "GuanpanFApp/Sources/ThemeLayoutManifest.swift").read_text(encoding="utf-8")
        cls.project = (ROOT / "GuanpanFApp/project.yml").read_text(encoding="utf-8")
        cls.chart = (ROOT / "GuanpanFApp/Sources/FUnifiedSecurityChart.swift").read_text(encoding="utf-8")
        cls.chart_model = (ROOT / "Sources/FCore/ChartDataModel.swift").read_text(encoding="utf-8")
        cls.quote_trust = (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8")

    def test_daily_chart_uses_the_shared_overflow_safe_moving_average(self):
        start = self.chart.index("    private func movingAverages(for series: FChartSeries)")
        end = self.chart.index("    private func chartHeader(", start)
        calculation = self.chart[start:end]
        self.assertIn("FDailyMovingAverage.values(for: bars, period: $0)", calculation)
        self.assertNotIn("reduce(Decimal.zero)", calculation)
        self.assertIn("FDailyMovingAverage.values(for: bars, period: period)", self.chart_model)

    def test_current_iopv_is_excluded_from_historical_chart_scale_and_renderer(self):
        start = self.chart_model.index("public struct FChartOverlayModel:")
        end = self.chart_model.index("private extension FChartPriceOverlay", start)
        overlay_model = self.chart_model[start:end]
        self.assertIn("guard case .liveIntraday = chart.window else { return nil }", overlay_model)
        self.assertIn("if let iopv = liveIOPV, iopv.isAvailable", overlay_model)
        self.assertIn("model.liveIOPV", self.chart)
        self.assertNotIn('let observation = model.iopv', self.chart)
        self.assertIn("IOPV仅实时快照，无历史序列", self.chart)
        self.assertIn("testHistoricalIntradayChartExcludesCurrentIOPVFromPriceRange",
                      (ROOT / "Tests/FCoreTests/MarketChartAcceptanceTests.swift").read_text(encoding="utf-8"))

    def test_security_detail_charts_use_the_expanded_shared_renderer(self):
        self.assertEqual(self.home.count("height: 420)"), 3)
        self.assertNotIn("height: 320)", self.home)
        for role in ("live", "daily", "history"):
            self.assertIn(f'market.security-chart.{role}', self.home)
        self.assertIn(".frame(height: height)", self.chart)
        self.assertNotIn("height >= 600 ? height + 80", self.chart)
        self.assertIn("testSecurityDetailChartsUseExpandedPhoneHeight", self.ui_tests)

    def test_modern_theme_keeps_portfolio_and_advisor_full_width_with_adaptive_market_grid(self):
        start = self.home.index("    private var modern: some View {")
        end = self.home.index("    private var dashboard", start)
        layout = self.home[start:end]
        self.assertLess(layout.index("role(.portfolio)"), layout.index("LazyVGrid"))
        self.assertIn("GridItem(.adaptive(minimum: 260, maximum: 420)", layout)
        self.assertIn("role(.marketObservation)", layout)
        self.assertIn("role(.crossMarketPulse)", layout)
        self.assertIn("role(.advisorGuidance)", layout)

    def test_nas_is_optional_for_local_quant_and_advisor(self):
        self.assertIn("NAS为可选历史归档与研究增强", self.manifest)
        self.assertIn("NAS只提供可选历史归档与研究增强，不阻塞本机Quant或Advisor", self.home)
        self.assertIn("Section(\"可选同步与数据服务\")", self.home)
        self.assertIn('LabeledContent("新闻最近状态", value: model.newsStatus)', self.home)
        self.assertIn("NAS是可选同步、归档与备份服务", self.home)
        self.assertNotIn("NAS历史分钟用于Quant策略验证，Advisor不等待NAS", self.home)
        self.assertNotIn("当前合格策略参数包尚未下放到Local Quant", self.home)

    def test_live_intraday_plot_expands_with_observed_session_and_breaks_real_gaps(self):
        self.assertIn("zoomScale: displayedZoomScale, window: model.chart.window", self.chart)
        self.assertIn("let sessionEnd = session == .lunchBreak ? 132 : observedEnd", self.chart)
        self.assertIn("return 0...max(sessionEnd, 1)", self.chart)
        self.assertIn("minute - previousSessionMinute <= 2.5", self.chart)
        self.assertIn('(132, "13:00")', self.chart)

    def test_bento_grid_collapses_on_phone_instead_of_forcing_half_width_cards(self):
        start = self.home.index("    private var bento: some View {")
        end = self.home.index("    private var inkEditorial", start)
        layout = self.home[start:end]
        self.assertIn("GridItem(.adaptive(minimum: 260, maximum: 420)", layout)
        self.assertNotIn("HStack(alignment: .top", layout)
        self.assertIn("role(.portfolio).frame(minHeight: 210)", layout)

    def test_six_approved_home_compositions_share_real_model_but_change_layout(self):
        self.assertIn("private struct FDesignedThemeHome", self.home)
        for concept in ("mountainCover", "deepSpaceTerminal", "coralCollage",
                        "bluePortfolio", "nightFlight", "auroraPanorama"):
            self.assertIn(f"case .{ {'mountainCover':'editorial','deepSpaceTerminal':'dashboard','coralCollage':'bento','bluePortfolio':'modern','nightFlight':'minimalTerminal','auroraPanorama':'adaptiveBento'}[concept] }: {concept}", self.home)
        self.assertIn("testSixApprovedVisualConceptsRenderHomeScreenshots", self.ui_tests)
        self.assertIn("testSixApprovedVisualConceptsRenderInSystemDarkAppearance", self.ui_tests)
        self.assertIn("model.portfolioMarketValuation(at: Date())", self.home)
        self.assertIn("model.marketIndexQuotes", self.home)
        self.assertIn("model.advisorResult", self.home)

    def test_all_theme_home_roles_expose_accessibility_identity_and_ui_order_assertions(self):
        self.assertIn('.accessibilityIdentifier("home.role.\\(role.rawValue)")', self.home)
        self.assertIn('.accessibilityIdentifier("home.role.portfolio")', self.home)
        self.assertIn('matching(identifier: "home.role.\\($0)")', self.ui_tests)
        self.assertIn('Set(roles.map(\\.identifier)).count', self.ui_tests)
        self.assertIn('allCases.contains(theme)', self.manifest)

    def test_custom_theme_leads_also_publish_the_shared_home_roles(self):
        editorial = self.home.split("    private var editorial: some View {", 1)[1].split(
            "    private var modern", 1)[0]
        for role in ("portfolio", "marketObservation", "crossMarketPulse", "advisorGuidance"):
            self.assertIn(f'home.role.{role}', editorial)

        dashboard = self.home.split("    private var dashboard: some View {", 1)[1].split(
            "    private var magazine", 1)[0]
        ink = self.home.split("    private var inkEditorial: some View {", 1)[1].split(
            "    private var minimalTerminal", 1)[0]
        glass = self.home.split("    private var fluidGlass: some View {", 1)[1].split(
            "    private var dataStarMap", 1)[0]
        for layout in (dashboard, ink, glass):
            self.assertTrue('home.role.portfolio' in layout or 'role(.portfolio)' in layout)
            self.assertTrue('home.role.advisorGuidance' in layout or 'role(.advisorGuidance)' in layout)

    def test_theme_tokens_follow_system_appearance_instead_of_forcing_light_mode(self):
        self.assertIn("traits.userInterfaceStyle == .dark ? dark : light", self.manifest)
        self.assertIn("appearanceCompatibility: \"浅色/深色语义token跟随系统外观", self.manifest)
        self.assertIn("let accentForeground: Color", self.manifest)
        self.assertIn("tokens.accentForeground", self.home)
        self.assertNotIn(".environment(\\.colorScheme, .light)", self.app)
        self.assertNotIn(".toolbarColorScheme(theme == .dashboard", self.app)
        self.assertIn("testSixApprovedVisualConceptsRenderInSystemDarkAppearance", self.ui_tests)

    def test_home_and_security_chart_semantic_foregrounds_use_the_selected_theme_tokens(self):
        home = self.home.split("struct FLedgerConfirmationSheet: View", 1)[0]
        chart = self.chart
        self.assertNotRegex(home, r"foregroundStyle\(\.(secondary|primary|tertiary)\)")
        self.assertNotRegex(chart, r"foregroundStyle\(\.(secondary|primary|tertiary)\)")
        self.assertIn("theme.manifest.tokens.secondaryForeground", home)
        self.assertIn("theme.manifest.tokens.foreground", home)
        self.assertIn("theme.manifest.tokens.secondaryForeground", chart)

    def test_portfolio_total_requires_every_fresh_trusted_quote_and_shows_unavailable_state(self):
        valuation = (ROOT / "Sources/FCore/PortfolioMarketValuation.swift").read_text(encoding="utf-8")
        card = self.home.split("private struct PortfolioCard: View", 1)[1].split(
            "private struct RouteCard: View", 1)[0]
        self.assertIn("FPortfolioMarketValuationCalculator.calculate", self.app)
        self.assertIn("HomePortfolioValuationRow(model: model)", card)
        self.assertEqual(self.home.count("HomePortfolioValuationRow(model: model)"), 2)
        valuation_row = self.home.split("private struct HomePortfolioValuationRow: View", 1)[1].split(
            "private extension Result", 1)[0]
        self.assertIn('Text("账本内资产估值")', valuation_row)
        self.assertIn("model.portfolioMarketValuation(at: evaluationDate).displayLabel", valuation_row)
        self.assertIn("Task.sleep(nanoseconds: 15_000_000_000)", valuation_row)
        self.assertIn('.accessibilityIdentifier("portfolio.valuation.total")', valuation_row)
        self.assertIn(".accessibilityElement(children: .combine)", valuation_row)
        self.assertIn("全部真实持仓市值", card)
        self.assertIn("FQuoteTemporalMetadata.defaultMaximumAge", valuation)
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted",
                      (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8"))
        self.assertIn("missingOrStaleQuotes", valuation)
        self.assertIn("guard missingOrStaleCodes.isEmpty", valuation)
        self.assertIn("case .failure(.missingOrStaleQuotes(let codes))", self.home)
        self.assertIn("testMissingOneHoldingQuoteRejectsTheWholeTotalInsteadOfShowingPartialValue",
                      (ROOT / "Tests/FCoreTests/PortfolioMarketValuationTests.swift").read_text(encoding="utf-8"))

    def test_ios_target_declares_landscape_and_has_rotation_acceptance(self):
        self.assertIn("UIInterfaceOrientationLandscapeLeft", self.project)
        self.assertIn("UIInterfaceOrientationLandscapeRight", self.project)
        self.assertIn("testLandscapeRotationKeepsSecurityDetailAndChartAccessible", self.ui_tests)

    def test_cross_market_copy_names_only_confirmed_etf_benchmark_mappings(self):
        cross_market = self.home.split('struct CrossMarketOverview:', 1)[1].split(
            '\nstruct ', 1)[0]
        self.assertIn("159352→中证A500、159941→纳指100", cross_market)
        self.assertIn("顾问背景和Local Quant策略准备", cross_market)
        self.assertIn("不代表策略资格或交易信号", cross_market)
        self.assertIn("其他ETF不自动套用指数状态", cross_market)
        self.assertNotIn("指数结果尚未映射到持仓 ETF 的 Regime/Quant", cross_market)

    def test_index_quote_time_never_calls_an_unknown_session_closed(self):
        start = self.home.index("    private func quoteTimeText(_ quote: FMarketIndexQuote, now: Date = Date()) -> String {")
        end = self.home.index("\n}\n\nstruct RealAssetsOverview", start)
        formatter = self.home[start:end]
        card_start = self.home.index("    private func indexCard(_ quote: FMarketIndexQuote) -> some View {")
        card_end = self.home.index("    private func percentText", card_start)
        card = self.home[card_start:card_end]
        self.assertIn("TimelineView(.periodic(from: .now, by: 15))", card)
        self.assertIn("quoteTimeText(quote, now: context.date)", card)
        self.assertIn("let session = marketSessionLabel(quote.marketStatus)", formatter)
        self.assertIn("let freshness = quote.freshness(at: now)", formatter)
        self.assertIn("guard freshness != .unverified else", formatter)
        self.assertIn("· \\(session)", formatter)
        self.assertIn('case "OPEN": return "交易时段：交易中"', formatter)
        self.assertIn('case "CLOSE", "CLOSED": return "交易时段：已收盘"', formatter)
        self.assertIn('case .stale:', formatter)
        self.assertIn('return "行情滞后 \\(Int(age / 60)) 分钟', formatter)
        self.assertIn('交易时段：已收盘 · 最后行情时间', formatter)
        self.assertIn('default: return "交易时段未验证"', formatter)
        self.assertNotIn('== "OPEN" ? " · 交易中" : " · 已收盘"', formatter)
        self.assertIn('indexCard.label.contains("交易时段")', self.ui_tests)

    def test_unverified_index_values_are_visible_but_count_as_unavailable(self):
        start = self.app.index("struct FMarketIndexQuote:")
        end = self.app.index("\ntypealias FHomeLedgerState", start)
        quote = self.app[start:end]
        self.assertIn("var hasNumericQuote: Bool { latestPrice != nil && changePercent != nil }", quote)
        self.assertIn("observedAt.timeIntervalSince1970.isFinite", quote)
        self.assertIn("fetchedAt.timeIntervalSince1970.isFinite", quote)
        self.assertIn("return observedAt <= fetchedAt", quote)
        self.assertIn("func freshness(at now: Date) -> FQuoteFreshness", quote)
        self.assertIn("FQuoteTemporalMetadata(quoteTimestamp: observedAt, fetchedAt: fetchedAt", quote)
        self.assertIn("unavailableReason == nil", quote)
        self.assertIn("FMarketQuoteTrustPolicy.isTrusted(source)", quote)
        start = self.home.index("    private func indexCard(_ quote: FMarketIndexQuote) -> some View {")
        end = self.home.index("    private func percentText", start)
        card = self.home[start:end]
        self.assertIn("if quote.hasNumericQuote, let price = quote.latestPrice", card)
        self.assertIn("if !quote.isAvailable, let reason = quote.unavailableReason", card)

    def test_tencent_index_quote_rejects_future_exchange_timestamp(self):
        start = self.app.index("private static func fetchTencentIndices() async -> [String: FMarketIndexQuote] {")
        end = self.app.index("    private static func fetchSinaNikkei()", start)
        parser = self.app[start:end]
        self.assertIn("observedAt.map({ $0 <= fetchedAt })", parser)
        self.assertNotIn("fetchedAt.addingTimeInterval(60)", parser)

    def test_all_live_reference_quotes_reject_future_timestamps_and_mark_stale_iopv(self):
        kospi_start = self.app.index("    private static func fetchNaverKospi() async -> [String: FMarketIndexQuote] {")
        kospi_end = self.app.index("    private static func unavailable(", kospi_start)
        self.assertIn("observedAt.map({ $0 <= fetchedAt })", self.app[kospi_start:kospi_end])

        reference_start = self.app.index("    static func fetchMarketReference(code: String) async throws -> FTencentMarketReference {")
        reference_end = self.app.index("    static func fetchInstrumentName(", reference_start)
        reference_parser = self.app[reference_start:reference_end]
        self.assertIn("observedAt <= now", reference_parser)
        self.assertNotIn("now.addingTimeInterval(60)", reference_parser)
        self.assertIn("price.isFinite", reference_parser)
        self.assertIn("previousClose.isFinite", reference_parser)
        self.assertIn("$0.isFinite && $0 > 0", reference_parser)
        self.assertIn('public static let eastmoneyMinuteSource = "Eastmoney push2 实时分钟（Tencent 主源不可用时备用）"', self.quote_trust)

        reference_model_start = self.app.index("struct FTencentMarketReference:")
        reference_model_end = self.app.index("struct FMarketIndexQuote:", reference_model_start)
        reference_model = self.app[reference_model_start:reference_model_end]
        self.assertIn("observedAt <= fetchedAt && fetchedAt <= now", reference_model)
        self.assertIn("age >= 0 && age <= 900", reference_model)
        self.assertIn("hasTrustedTimestamp(at: now)", reference_model)

        presentation = self.chart[self.chart.index("enum FChartPresentationBuilder {"):]
        self.assertIn("reference.hasFreshIOPV(at: Date())", presentation)
        self.assertIn('" · IOPV过期/不可用"', self.home)
        self.assertIn('" · 腾讯溢折价过期/不可用"', self.home)
        self.assertIn('Text("参考行情时点不可信或来自未来 · \\(reference.source)")', self.home)

    def test_live_minute_chart_never_marks_closed_or_future_time_data_complete(self):
        start = self.chart.index("    static func live(_ snapshot: FCurrentIntradaySnapshot?")
        end = self.chart.index("    static func historical(", start)
        live_builder = self.chart[start:end]
        self.assertIn("switch session", live_builder)
        self.assertIn("case .lunchBreak:", live_builder)
        self.assertIn("case .preOpen:", live_builder)
        self.assertIn("case .closed:", live_builder)
        self.assertIn("case .unknown:", live_builder)
        self.assertIn(".stale(reason: \"午间休市；展示最后有效分钟\")", live_builder)
        self.assertIn(".stale(reason: \"已收盘或休市；展示最后有效分钟\")", live_builder)
        self.assertIn("snapshot.temporalMetadata(marketSessionStatus: session)", live_builder)
        self.assertIn("metadata.freshness(at: now)", live_builder)
        self.assertIn("行情时间未验证或来自未来", live_builder)

        quote_label_start = self.home.index("    private static func quoteFreshnessText(")
        quote_label_end = self.home.index("\n    }", quote_label_start)
        quote_label = self.home[quote_label_start:quote_label_end]
        self.assertIn("metadata.freshness(at: now)", quote_label)
        self.assertIn("metadata.freshness(at: now)", quote_label)
        self.assertNotIn("max(0, now.timeIntervalSince", quote_label)

    def test_live_quote_freshness_uses_shared_120_second_boundary(self):
        quality_start = self.chart.index("        let quality: FChartDataQuality", self.chart.index("enum FChartPresentationBuilder {"))
        quality_end = self.chart.index("        guard let chart =", quality_start)
        quality = self.chart[quality_start:quality_end]
        self.assertIn("let freshness = metadata.freshness(at: now)", self.chart)
        self.assertIn("switch freshness", quality)
        self.assertIn("case .fresh: quality = .complete", quality)
        self.assertIn('case .stale: quality = .stale(reason: "超过2分钟未更新")', quality)
        self.assertIn('case .unverified: quality = .stale(reason: "行情时间未验证或来自未来")', quality)
        self.assertIn("超过2分钟未更新", quality)
        self.assertNotIn("timeIsVerified", quality)
        self.assertNotIn("quoteAge <= 300", quality)
        quote_label_start = self.home.index("    private static func quoteFreshnessText(")
        quote_label_end = self.home.index("\n    }", quote_label_start)
        quote_label = self.home[quote_label_start:quote_label_end]
        self.assertIn("metadata.freshness(at: now)", quote_label)
        self.assertIn("guard freshness != .unverified", quote_label)
        self.assertIn("case .fresh: return", quote_label)
        self.assertIn("case .stale: return", quote_label)
        self.assertNotIn("age <= FQuoteTemporalMetadata.defaultMaximumAge", quote_label)
        self.assertNotIn("age <= 300", quote_label)
        self.assertNotIn("<= 120", self.home)
        self.assertIn("public static let defaultMaximumAge: TimeInterval = 120",
                      (ROOT / "Sources/FCore/MarketDataQuality.swift").read_text(encoding="utf-8"))
        trigger = (ROOT / "Sources/FCore/RealtimeQuantTrigger.swift").read_text(encoding="utf-8")
        self.assertIn("defaultMaximumQuoteAge: TimeInterval = FQuoteTemporalMetadata.defaultMaximumAge",
                      trigger)
        advisor = (ROOT / "Sources/FAdvisor/DecisionContext.swift").read_text(encoding="utf-8")
        self.assertIn("case .quote: return FQuoteTemporalMetadata.defaultMaximumAge", advisor)
        shadow = (ROOT / "Sources/FAdvisor/CandidateShadowScorecard.swift").read_text(encoding="utf-8")
        self.assertIn("Int(FQuoteTemporalMetadata.defaultMaximumAge)", shadow)
        self.assertIn(").freshness(at: capturedAt) == .fresh", shadow)
        snapshot_model = (ROOT / "Sources/FCore/MarketMinuteData.swift").read_text(encoding="utf-8")
        self.assertIn("public func freshness(at now: Date) -> FQuoteFreshness", snapshot_model)
        self.assertIn("temporalMetadata().freshness(at: now)", snapshot_model)
        self.assertNotIn("timeIntervalSince($0.quoteTimestamp) <= 120", self.home)
        self.assertIn("testLiveSnapshotFreshnessRejectsFutureFetchTime",
                      (ROOT / "Tests/FCoreTests/MarketMinuteDataTests.swift").read_text(encoding="utf-8"))

    def test_automatic_quote_refresh_is_gated_to_verified_continuous_session(self):
        start = self.app.index("    func autoRefreshMarketData() async {")
        end = self.app.index("\n    var cashText:", start)
        automatic_refresh = self.app[start:end]
        self.assertIn("guard FMainlandTradingCalendar.status(at: Date()) == .continuous else { return }",
                      automatic_refresh)
        self.assertIn("await refreshMarketData(for: codes)", automatic_refresh)
        self.assertIn("if FMainlandTradingCalendar.status(at: Date()) == .continuous {",
                      self.app[self.app.index(".task(id: scenePhase)"):])

    def test_live_index_refresh_does_not_request_nas_history(self):
        refresh_start = self.app.index("    func refreshMarketIndices() async {")
        refresh_end = self.app.index("\n    func refreshHistoricalIndexRegimes() async {", refresh_start)
        live_refresh = self.app[refresh_start:refresh_end]
        self.assertNotIn("refreshHistoricalIndexRegimes", live_refresh)
        self.assertNotIn("FNASIndexDailyHistoryClient", live_refresh)
        button_start = self.home.index('Button {\n                        Task { await model.refreshMarketIndices() }')
        button_end = self.home.index(".accessibilityIdentifier(\"crossmarket.refresh\")", button_start)
        self.assertNotIn("refreshHistoricalIndexRegimes", self.home[button_start:button_end])
        history_button_start = self.home.index('Button {\n                        Task { await model.refreshHistoricalIndexRegimes() }')
        history_button_end = self.home.index(".accessibilityIdentifier(\"crossmarket.history-refresh\")",
                                             history_button_start)
        self.assertIn("Button {", self.home[history_button_start:history_button_end])
        screen_task = self.home[self.home.index('.navigationTitle("跨市场脉搏")'):]
        self.assertIn("async let liveQuotes", screen_task)
        self.assertIn("async let historicalRegimes: Void = model.refreshHistoricalIndexRegimes()",
                      screen_task)

    def test_tencent_index_timestamp_rejects_calendar_normalization(self):
        self.assertIn("FMarketIndexTimestamp.parse(raw, timeZoneIdentifier: timeZone)", self.app)
        parser = (ROOT / "Sources/FCore/MarketIndexTimestamp.swift").read_text(encoding="utf-8")
        self.assertIn("let zone = TimeZone(identifier: timeZoneIdentifier) else { return nil }", parser)
        self.assertIn("calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)", parser)
        for component in ["year", "month", "day", "hour", "minute", "second"]:
            self.assertIn(f"verified.{component} ==", parser)
        tests = (ROOT / "Tests/FCoreTests/MarketIndexTimestampTests.swift").read_text(encoding="utf-8")
        self.assertIn("testRejectsImpossibleAndOverflowingCalendarComponents", tests)
        self.assertIn("testRejectsUnknownTimezoneInsteadOfUsingDeviceTimezone", tests)

    def test_cross_market_index_numbers_reject_boolean_and_nonfinite_payloads(self):
        start = self.app.index("private enum FMarketIndexHTTPClient {")
        end = self.app.index("private enum FQuoteProviderError", start)
        client = self.app[start:end]
        decimal_start = client.index("private static func decimal(_ raw: Any?) -> Decimal? {")
        decimal_end = client.index("\n    private static func parseISO8601", decimal_start)
        parser = client[decimal_start:decimal_end]
        self.assertIn("CFGetTypeID(value) != CFBooleanGetTypeID()", parser)
        self.assertIn("number.isFinite", parser)
        self.assertIn("NSDecimalNumber(decimal: number).doubleValue.isFinite", parser)

    def test_opening_holdings_autofill_name_cost_per_unit_and_separate_cash(self):
        start = self.home.index("struct FInitialLedgerSetupSheet: View")
        end = self.home.index("private extension FDecisionAction", start)
        entry = self.home[start:end]
        self.assertIn('TextField("证券名称（自动识别，可修改）", text: $draft.name)', entry)
        self.assertIn("Task { await updateName(for: code) }", entry)
        self.assertIn("draft.instrumentCode == code", entry)
        self.assertIn("draft.nameWasManuallyEdited", entry)
        self.assertIn("draft.nameWasManuallyEdited = false", entry)
        lookup_start = entry.index("private func updateName(for code: String) async {")
        lookup_end = entry.index("\n    var body: some View", lookup_start)
        lookup = entry[lookup_start:lookup_end]
        await_index = lookup.index("await model.lookupInstrumentName(code: code)")
        self.assertLess(lookup.index("guard !draft.nameWasManuallyEdited"), await_index)
        self.assertLess(await_index, lookup.index("!draft.nameWasManuallyEdited else { return }"))
        self.assertIn("draft.instrumentCode == code", lookup)
        self.assertIn('TextField("每份真实经济成本（含费用）", text: $draft.economicCostPerUnit)', entry)
        self.assertIn("let totalEconomicCost = costPerUnit * Decimal(units)", entry)
        self.assertIn("totalEconomicCost.isFinite", entry)
        self.assertIn("cashEntrySection", entry)
        self.assertIn("FInitialCashEntrySheet(cashText: $cashText)", entry)
        self.assertIn("cash.isFinite, cash >= 0", entry)
        establish_start = self.app.index("    func establishInitialLedger(")
        establish_end = self.app.index("\n    func ", establish_start + 8)
        establish = self.app[establish_start:establish_end]
        self.assertIn("cash.isFinite, cash >= 0", establish)
        self.assertIn("$0.economicCost.isFinite && $0.economicCost >= 0", establish)
        self.assertIn("testEmptyLedgerOffersSeparateCashAndHoldingsEntry", self.ui_tests)
        self.assertIn('XCTAssertFalse(app.textFields["ledger.opening.cash"].exists)', self.ui_tests)

    def test_market_watchlist_is_persisted_separately_and_filterable(self):
        start = self.home.index("private enum FMarketListScope: String, CaseIterable, Identifiable")
        end = self.home.index("private struct FAdvisorResultCard", start)
        market = self.home[start:end]
        self.assertIn("case holdings, watchlist, combined", market)
        self.assertIn("case .watchlist: model.watchlistCodes", market)
        self.assertIn('accessibilityIdentifier("market.list.scope")', market)
        self.assertIn('accessibilityIdentifier("market.watchlist.toggle")', market)
        self.assertIn('accessibilityIdentifier("market.watchlist.\\(code)")', market)
        start = self.app.index("    func toggleWatchlist(_ code: String) {")
        end = self.app.index("    func autoRefreshMarketData() async", start)
        watchlist = self.app[start:end]
        self.assertIn("UserDefaults.standard.set(watchlistCodes", watchlist)
        self.assertNotIn("ledgerWriter", watchlist)
        self.assertNotIn("accountBookStore", watchlist)
        self.assertIn("func testWatchlistIsSeparateAndAppearsInItsOwnMarketFilter", self.ui_tests)

    def test_advisor_question_and_context_are_accessible_and_auditable(self):
        start = self.home.index("private struct AdvisorComposer: View")
        end = self.home.index("private struct PortfolioCard: View", start)
        composer = self.home[start:end]
        self.assertIn('accessibilityIdentifier("advisor.composer.question")', composer)
        self.assertIn('accessibilityIdentifier("advisor.composer.prompts")', composer)
        self.assertIn('accessibilityIdentifier("advisor.composer.status")', composer)

        overview_start = self.home.index("struct AdvisorOverview: View")
        overview_end = self.home.index("struct MarketOverview: View", overview_start)
        overview = self.home[overview_start:overview_end]
        for section in ["ledger", "quotes", "scorecard", "nas-research", "news"]:
            self.assertIn(f'advisor.context.{section}', overview)

        result_start = self.home.index("private struct FAdvisorResultCard: View")
        result_end = self.home.index("struct FLedgerConfirmationSheet: View", result_start)
        result = self.home[result_start:result_end]
        for section in ["conclusion", "basis", "holdings", "quotes", "research"]:
            self.assertIn(f'advisor.result.{section}', result)
        self.assertIn("fixedSize(horizontal: false, vertical: true)", result)
        self.assertIn("testAdvisorExposesStructuredQuestionAndContextSections", self.ui_tests)


if __name__ == "__main__":
    unittest.main()
