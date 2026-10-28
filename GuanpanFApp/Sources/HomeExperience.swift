import SwiftUI
import FCore
import FAdvisor

extension FHomeTheme {
    var background: Color {
        switch self {
        case .editorial: return Color(red: 0.97, green: 0.94, blue: 0.87)
        case .modern: return Color(red: 0.94, green: 0.96, blue: 0.99)
        case .dashboard: return Color(red: 0.055, green: 0.075, blue: 0.12)
        case .magazine: return Color(red: 0.97, green: 0.96, blue: 0.93)
        case .bento: return Color(red: 0.94, green: 0.95, blue: 0.92)
        }
    }
    var ink: Color { self == .dashboard ? .white : Color(red: 0.12, green: 0.15, blue: 0.19) }
    var accent: Color {
        switch self {
        case .editorial: return Color(red: 0.69, green: 0.34, blue: 0.16)
        case .modern: return Color(red: 0.18, green: 0.39, blue: 0.82)
        case .dashboard: return Color(red: 0.26, green: 0.78, blue: 0.81)
        case .magazine: return Color(red: 0.69, green: 0.27, blue: 0.19)
        case .bento: return Color(red: 0.28, green: 0.49, blue: 0.35)
        }
    }
}

struct HomeLayout: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    var body: some View {
        ScrollView {
            Group {
                switch theme {
                case .editorial: editorial
                case .modern: modern
                case .dashboard: dashboard
                case .magazine: magazine
                case .bento: bento
                }
            }
            .padding(18)
        }
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
    }

    private var editorial: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("把每次决定，放回你的长期计划里。")
                .font(.system(size: 27, weight: .bold, design: .serif))
            AdvisorComposer(model: model, theme: theme)
            PortfolioCard(model: model)
            route(.market, "今日市场观察", "行情时间、来源与市场状态", "sun.horizon")
            route(.crossMarket, "跨市场脉搏", "独立的跨市场研究证据", "globe.asia.australia")
            route(.advisor, "AI 今日指导", "组合决策依据与建议", "sparkles")
        }
    }

    private var modern: some View {
        VStack(spacing: 14) {
            AdvisorComposer(model: model, theme: theme)
            PortfolioCard(model: model)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                route(.market, "市场观察", "行情与时点", "chart.xyaxis.line")
                route(.crossMarket, "跨市场", "研究脉搏", "globe")
                route(.advisor, "AI 指导", "决策说明", "sparkles")
                route(.portfolio, "我的持仓", "真实账本", "briefcase")
            }
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("组合现金").font(.caption).foregroundStyle(.secondary)
                    Text(model.cashText).font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Text("真实账本").font(.caption.weight(.semibold))
                    .padding(9).overlay(Capsule().stroke(theme.accent, lineWidth: 1))
            }
            AdvisorComposer(model: model, theme: theme)
            PortfolioCard(model: model)
            HStack(spacing: 10) {
                route(.market, "行情", "市场观察", "waveform.path")
                route(.crossMarket, "跨市", "研究脉搏", "globe")
            }
            route(.advisor, "AI 决策台", "证据、风险和建议", "sparkles")
        }
    }

    private var magazine: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(Date.now.formatted(.dateTime.year().month(.wide).day()).uppercased())
                .font(.caption.weight(.semibold)).tracking(1.2)
            Text("你的资产，\n你的判断。")
                .font(.system(size: 42, weight: .bold, design: .serif))
            Rectangle().fill(theme.accent).frame(width: 54, height: 4)
            Text("本期焦点 · 真实组合与长期研究")
                .font(.subheadline).foregroundStyle(.secondary)
            PortfolioCard(model: model)
            AdvisorComposer(model: model, theme: theme)
            route(.advisor, "顾问专栏", "AI 指导及理由", "text.book.closed")
            route(.market, "今日市场观察", "报价来源、时点与质量", "newspaper")
            route(.crossMarket, "跨市场脉搏", "研究关系与证据", "globe.americas")
        }
    }

    private var bento: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PortfolioCard(model: model).frame(maxWidth: .infinity, minHeight: 210)
                route(.market, "市场观察", "行情与质量", "chart.xyaxis.line")
                    .frame(maxWidth: .infinity, minHeight: 210)
            }
            AdvisorComposer(model: model, theme: theme)
            HStack(spacing: 12) {
                route(.advisor, "AI 今日指导", "组合决策", "sparkles")
                route(.crossMarket, "跨市场脉搏", "研究证据", "globe")
            }
            route(.portfolio, "真实持仓明细", "来自本机账本快照", "list.bullet.rectangle")
        }
    }

    private func route(_ target: FHomeRoute, _ title: String, _ detail: String, _ icon: String) -> some View {
        RouteCard(route: target, title: title, detail: detail, icon: icon, accent: theme.accent)
    }
}

private struct AdvisorComposer: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    let instrumentCode: String?

    init(model: FHomeModel, theme: FHomeTheme, instrumentCode: String? = nil) {
        self.model = model
        self.theme = theme
        self.instrumentCode = instrumentCode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(theme.accent)
                Text(instrumentCode.map { "证券分析 · \($0)" } ?? "组合顾问 · 可指定证券代码")
                    .font(.headline)
                Spacer()
                Text(model.portfolioContextLabel)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            TextField(instrumentCode.map { "例如：\($0) 现在需要操作吗？" } ??
                      "例如：今天我的持仓需要操作吗？", text: $model.question, axis: .vertical)
                .lineLimit(2...4).textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                ForEach(model.commonQuestions(for: instrumentCode), id: \.self) { prompt in
                        Button(prompt) { model.question = prompt }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .tint(theme.accent)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            HStack {
                Spacer()
                Button { model.askAdvisor(instrumentCode: instrumentCode) } label: {
                    Label(model.isAskingAdvisor ? "分析中" : "发送",
                          systemImage: model.isAskingAdvisor ? "hourglass" : "arrow.up.circle.fill")
                }.buttonStyle(.borderedProminent).tint(theme.accent)
                    .disabled(model.isAskingAdvisor)
            }
            Text(model.advisorStatus).font(.caption).foregroundStyle(.secondary)
            Text("组合问题会纳入全部真实持仓；证券详情入口只分析目标证券。账本、行情和合格 NAS 证据只读传入，Candidate Plan 不会改写资产。")
                .font(.caption2).foregroundStyle(.secondary)
            if let result = model.advisorResult {
                FAdvisorResultCard(result: result, accent: theme.accent) {
                    model.beginLedgerConfirmation(for: result)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct PortfolioCard: View {
    @ObservedObject var model: FHomeModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("真实组合").font(.headline)
            LabeledContent("现金", value: model.cashText)
            LabeledContent("持仓", value: "\(model.holdings.count) 项")
            if model.ledgerState == .available && model.holdings.isEmpty {
                Text("账本已读取，当前没有真实持仓").font(.subheadline).foregroundStyle(.secondary)
            } else if model.ledgerState != .available {
                Text("持仓状态未确认 · \(model.ledgerStatus)")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(model.holdings) { item in
                    NavigationLink(value: FHomeRoute.instrument(item.instrumentCode)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.subheadline.weight(.medium))
                                Text(item.instrumentCode).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(item.units) 份").monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct RouteCard: View {
    let route: FHomeRoute
    let title: String
    let detail: String
    let icon: String
    let accent: Color
    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct HomeDestination: View {
    let route: FHomeRoute
    @ObservedObject var model: FHomeModel
    @State private var showingBrokerCostEditor = false
    @State private var brokerCostText = ""
    @State private var brokerCostNote = ""
    var body: some View {
        Group {
            switch route {
            case .market:
                MarketOverview(model: model)
            case .crossMarket:
                CrossMarketOverview()
            case .advisor:
                AdvisorOverview(model: model)
            case .portfolio:
                RealAssetsOverview(model: model)
            case let .instrument(code):
                instrumentDestination(code)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBrokerCostEditor) {
            NavigationStack {
                Form {
                    Section("券商 / 同花顺显示口径") {
                        TextField("每份成本", text: $brokerCostText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("ledger.brokerCost.value")
                        TextField("录入或修正原因", text: $brokerCostNote, axis: .vertical)
                            .accessibilityIdentifier("ledger.brokerCost.note")
                    }
                    Section {
                        Text("此值只记录你实际看到的券商单位成本，不会改写成交、现金或本轮真实经济成本。每次做T或券商口径变化后，可再次核对修正。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("券商展示成本")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingBrokerCostEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            guard case let .instrument(code) = route else { return }
                            Task {
                                await model.confirmBrokerDisplayCost(instrumentCode: code,
                                                                     costText: brokerCostText,
                                                                     note: brokerCostNote)
                                showingBrokerCostEditor = false
                            }
                        }
                        .accessibilityIdentifier("ledger.brokerCost.save")
                    }
                }
            }
        }
    }

    private func unavailable(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.largeTitle.bold())
            Text(description).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(title)
    }

    private func instrumentDestination(_ code: String) -> some View {
        let holding = model.holdings.first { $0.instrumentCode == code }
        let history = model.instrumentHistories.first { $0.instrumentCode == code }
        let instrumentName = holding?.name ?? history?.instrumentName ?? code
        let quoteSnapshot = model.marketDataByCode[code]
        let quoteNow = Date()
        let freshPrice: Decimal? = {
            guard let quoteSnapshot, quoteSnapshot.quoteTimestamp <= quoteNow,
                  quoteNow.timeIntervalSince(quoteSnapshot.quoteTimestamp) <= 120 else { return nil }
            return quoteSnapshot.latestPrice
        }()
        let dailySummary = model.latestLedgerSnapshot?.dailyTradeSummaries.first { $0.securityCode == code }
        let dailyTradingPnL: String = {
            guard model.latestLedgerSnapshot?.dailyTradeSummaryDate != nil else {
                return "不可用 · 历史账本无当日摘要"
            }
            return dailySummary?.dailyRealizedTradingPnL.description ?? "0 · 今日无确认成交"
        }()
        let dailyTDisplay: String = {
            guard model.latestLedgerSnapshot?.dailyTradeSummaryDate != nil else {
                return "不可用 · 历史账本无当日摘要"
            }
            guard let dailySummary else { return "0 · 今日无确认成交" }
            return dailySummary.tContribution?.description ?? "不可精确归类 · 存在未标记/未配对成交"
        }()
        let lifetimeTDisplay = history?.cumulativeTContribution?.description ??
            "不可精确归类 · 存在历史未标记/未配对成交"
        let activeEpisode = history?.episodes.last(where: \.isActive)
        let recordedClosedEpisodesRealized = history?.episodes
            .filter { $0.closedAt != nil }
            .reduce(Decimal.zero) { $0 + $1.netRealizedProfit } ?? .zero
        let closedEpisodesRealized: String = history?.lifetimeHistoryIsComplete == true
            ? recordedClosedEpisodesRealized.description
            : "不可完整统计 · 导入前流水缺失"
        let episodeUnrealized: Decimal? = if let holding, let freshPrice {
            Decimal(holding.units) * freshPrice - holding.bookCost
        } else { nil }
        let episodePnL: Decimal? = if let activeEpisode, let episodeUnrealized {
            activeEpisode.netRealizedProfit + episodeUnrealized
        } else { nil }
        let lifetimePnL: Decimal? = if let history, history.lifetimeHistoryIsComplete,
                              history.activeUnits == 0 {
            history.lifetimeRealizedProfit
        } else if let history, history.lifetimeHistoryIsComplete, let episodeUnrealized {
            history.lifetimeRealizedProfit + episodeUnrealized
        } else { nil }
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(instrumentName).font(.largeTitle.bold())
                Text(code).font(.headline.monospaced())
                if let holding {
                    Group {
                        LabeledContent("真实持仓", value: "\(holding.units) 份")
                        LabeledContent("本轮真实成本/份", value: (holding.bookCost / Decimal(holding.units)).description)
                        LabeledContent("券商展示成本/份", value: holding.brokerDisplayCostPerUnit?.description ?? "未录入")
                        if let updatedAt = holding.brokerDisplayCostUpdatedAt {
                            LabeledContent("券商成本更新时间", value: updatedAt.formatted(date: .numeric, time: .shortened))
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Button(holding.brokerDisplayCostPerUnit == nil ? "录入券商展示成本" : "修正券商展示成本") {
                        brokerCostText = holding.brokerDisplayCostPerUnit.map {
                            NSDecimalNumber(decimal: $0).stringValue
                        } ?? ""
                        brokerCostNote = ""
                        showingBrokerCostEditor = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("ledger.brokerCost.edit")
                } else if let history {
                    Group {
                        LabeledContent("持仓状态", value: "已清仓")
                        LabeledContent("持仓周期", value: "\(history.episodes.count) 轮")
                        LabeledContent(history.lifetimeHistoryIsComplete ? "历史累计已实现盈亏" : "F账本记录内已实现盈亏",
                                       value: history.lifetimeRealizedProfit.description)
                        if !history.lifetimeHistoryIsComplete {
                            Text("导入前成交历史未录入；此数不代表证券完整历史累计。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("当前未持有；行情与证券级顾问仍可查看。真实持仓仅来自本机账本。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("盈亏口径").font(.headline)
                    LabeledContent("今日证券总盈亏", value: "不可用 · 缺可靠前收与今日开盘持仓标记")
                    LabeledContent("今日交易已实现盈亏", value: dailyTradingPnL)
                    LabeledContent("今日做T贡献", value: dailyTDisplay)
                    LabeledContent("历史做T累计贡献", value: lifetimeTDisplay)
                    LabeledContent("当前Episode已实现盈亏", value: activeEpisode.map {
                        $0.historyIsComplete ? $0.netRealizedProfit.description : "不可用 · 导入前本轮成交流水不完整"
                    } ?? "无Active Episode")
                    LabeledContent("当前Episode未实现盈亏", value: episodeUnrealized?.description ?? (holding == nil ? "无当前持仓" : "不可用 · 行情缺失或已过期"))
                    LabeledContent("当前Episode盈亏", value: episodePnL?.description ?? (activeEpisode == nil ? "无Active Episode" : "不可用 · 行情缺失或已过期"))
                    LabeledContent("历史Closed Episodes已实现", value: closedEpisodesRealized)
                    LabeledContent("证券累计总盈亏", value: lifetimePnL?.description ??
                        (history?.lifetimeHistoryIsComplete == false
                            ? "不可用 · 导入前历史流水未录入"
                            : "未实现部分不可用 · 行情缺失或已过期"))
                    Text("今日证券总盈亏含全天市值变化；今日已实现仅统计卖出成交。做T需有明确成交标记，不能用普通卖出代替。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                if let history {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("持仓周期历史").font(.headline)
                        ForEach(history.episodes) { episode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("第\(episode.episodeNumber)轮 · 建仓 \(episode.openedAt.formatted(date: .numeric, time: .omitted))")
                                    .font(.subheadline.weight(.medium))
                                Text(episode.closedAt.map { "清仓 \($0.formatted(date: .numeric, time: .omitted))" } ?? "当前持仓周期")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("本轮已实现盈亏 \(episode.netRealizedProfit.description)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                let snapshot = quoteSnapshot
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot?.latestPrice.map { "¥\($0.description)" } ?? "暂无有效行情")
                            .font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        Button {
                            Task { await model.refreshMarketData(for: [code]) }
                        } label: {
                            if model.refreshingMarketCodes.contains(code) {
                                Label("刷新中", systemImage: "hourglass")
                            } else {
                                Label("刷新实时分时", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                        .disabled(model.refreshingMarketCodes.contains(code))
                        .accessibilityIdentifier("market.refresh.\(code)")
                    }
                    FUnifiedSecurityChart(
                        model: FChartPresentationBuilder.live(snapshot, holding: holding,
                                                              candidate: model.advisorResult?.candidate,
                                                              ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt),
                        height: 190)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("日 K 与均线").font(.headline)
                            Spacer()
                            Button {
                                Task { await model.refreshDailyKline(for: code) }
                            } label: { Label("刷新日 K", systemImage: "arrow.clockwise") }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                        if let daily = model.dailyKlineByCode[code] {
                            FUnifiedSecurityChart(
                                model: FChartPresentationBuilder.daily(daily, holding: holding,
                                                                       candidate: model.advisorResult?.candidate,
                                                                       ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt),
                                height: 250)
                        } else {
                            Text("尚无真实日 K 数据；请求失败时不会用分时点拼接。")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        Text(model.dailyKlineStateByCode[code] ?? "数据源：腾讯日 K · 未复权；等待请求")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    Text(model.marketRefreshStateByCode[code] ?? "尚未取得实时行情")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(snapshot.map { "\($0.source) · 行情时间 \($0.quoteTimestamp.formatted(date: .omitted, time: .standard)) · 获取于 \($0.fetchedAt.formatted(date: .omitted, time: .standard))" }
                         ?? "无数据时明确显示不可用，不使用占位或模拟价格。")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let snapshot {
                        Text(Self.quoteFreshnessText(snapshot, now: Date()))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NAS 历史分时").font(.headline)
                        DatePicker("历史交易日", selection: $model.selectedHistoryDate,
                                   in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                        Button {
                            Task { await model.loadArchivedIntraday(for: code) }
                        } label: {
                            Label("查询所选交易日", systemImage: "calendar.badge.clock")
                        }
                        .buttonStyle(.bordered)
                        Text(model.archiveRefreshStateByCode[code] ?? "选择日期后，从 NAS 分钟归档读取；缺失或部分覆盖会如实标注。")
                            .font(.caption).foregroundStyle(.secondary)
                        if let archived = model.archivedIntradayByCode[code], !archived.samples.isEmpty {
                            FUnifiedSecurityChart(
                                model: FChartPresentationBuilder.historical(archived, holding: holding,
                                                                             ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt),
                                height: 200)
                            Text("真实归档数据 · \(archived.sourceSummary) · \(archived.coverageSummary)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                AdvisorComposer(model: model, theme: .editorial, instrumentCode: code)
            }
            .padding(18)
        }
        .accessibilityIdentifier("market.security-detail.scroll")
        .navigationTitle(code)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            model.selectInstrument(code)
            async let quote: Void = model.refreshMarketData(for: [code])
            async let daily: Void = model.refreshDailyKline(for: code)
            _ = await (quote, daily)
        }
        .onDisappear {
            if model.selectedInstrumentCode == code { model.selectInstrument(nil) }
        }
    }

    private static func quoteFreshnessText(_ snapshot: FCurrentIntradaySnapshot, now: Date) -> String {
        let age = max(0, now.timeIntervalSince(snapshot.quoteTimestamp))
        switch FMainlandTradingCalendar.status(at: now) {
        case .continuous:
            return age <= 300 ? "行情新鲜 · \(Int(age)) 秒前" : "行情已滞后 · \(Int(age / 60)) 分钟前"
        case .lunchBreak: return "午间休市 · 最后分钟 \(snapshot.quoteTimestamp.formatted(date: .omitted, time: .standard))"
        case .preOpen: return "开盘前 · 保留上次有效行情"
        case .closed: return "已收盘或休市 · 最后分钟 \(snapshot.quoteTimestamp.formatted(date: .omitted, time: .standard))"
        case .unknown: return "交易日历未覆盖当前年份 · 时间状态待核验"
        }
    }
}

struct AdvisorOverview: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    private var theme: FHomeTheme { FHomeTheme(rawValue: themeRaw) ?? .editorial }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("AI 私人投资顾问")
                    .font(.largeTitle.bold())
                Text("未指定持仓证券的提问按真实组合分析；明确指定证券代码或从证券详情进入时按证券级分析。")
                    .foregroundStyle(.secondary)
                Text("发送后会将只读账本快照、行情和合格 NAS 研究发送至设置中配置的 DeepSeek。")
                    .font(.footnote).foregroundStyle(.secondary)
                AdvisorComposer(model: model, theme: theme)
                VStack(alignment: .leading, spacing: 10) {
                    Text("本次可用上下文").font(.headline)
                    LabeledContent("真实账本", value: model.ledgerStatus)
                    LabeledContent("持仓行情", value: model.holdings.isEmpty ? "暂无证券行情请求" : "按持仓证券逐项获取")
                    LabeledContent("NAS 历史研究", value: model.nasResearchStatus)
                    LabeledContent("新闻", value: "新闻源尚未接入")
                    HStack {
                        Text("在线 AI")
                        Spacer()
                        Text(model.aiKeyStatus).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("advisor.ai-key-status")
                }
                .font(.subheadline)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                Text("发送时重新读取本机真实账本，获取标的行情与 NAS 研究，再构建 DecisionContext 并运行 Risk Guard / AI Guard。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .navigationTitle("AI 私人投资顾问")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CrossMarketOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "globe.asia.australia")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("暂无合格跨市场证据").font(.title2.bold())
            Text("此页面只呈现 NAS 跨市场研究结果。样本、时区或数据质量未达到门槛时，不会把行情观察伪装成研究结论。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("跨市场脉搏")
    }
}

struct RealAssetsOverview: View {
    @ObservedObject var model: FHomeModel
    @State private var selectedView = 0

    var body: some View {
        List {
            Section("本机真实账本 · 只读") {
                assetSummaryRow("账本状态", value: model.ledgerStatus)
                assetSummaryRow("可用现金", value: model.cashText)
                assetSummaryRow("真实持仓", value: "\(model.holdings.count) 项")
                Picker("资产视图", selection: $selectedView) {
                    Text("当前持仓").tag(0)
                    Text("已清仓").tag(1)
                }.pickerStyle(.segmented)
            }
            if selectedView == 0 {
                Section("当前持仓") {
                if model.holdings.isEmpty {
                    Text(model.ledgerState == .available ? "账本已读取，当前没有真实持仓" : "真实持仓尚不可用")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.holdings) { item in
                    NavigationLink(value: FHomeRoute.instrument(item.instrumentCode)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.headline)
                            Text("\(item.instrumentCode) · \(item.units) 份 · 账面成本 \(item.bookCost.description)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                }
            } else {
                Section("已清仓 / 历史持仓") {
                    let closed = model.instrumentHistories.filter { !$0.isCurrentlyHeld }
                    if closed.isEmpty { Text("暂无已清仓证券记录").foregroundStyle(.secondary) }
                    ForEach(closed) { history in
                        NavigationLink(value: FHomeRoute.instrument(history.instrumentCode)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(history.instrumentName) · \(history.instrumentCode)").font(.headline)
                                Text("\(history.episodes.count) 个持仓周期 · 历史已实现 \(history.lifetimeRealizedProfit.description)")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(history.episodes) { episode in
                                    Text("第\(episode.episodeNumber)轮：\(episode.openedAt.formatted(date: .numeric, time: .omitted)) 建仓 → \(episode.closedAt?.formatted(date: .numeric, time: .omitted) ?? "持有中") · 已实现 \(episode.netRealizedProfit.description)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Section("现金与成交流水") {
                Button("录入其他费用 / 现金对账差额") {
                    model.beginCashAdjustment()
                }
                .sheet(isPresented: $model.showingCashAdjustment) {
                    FCashAdjustmentSheet(model: model)
                }
                .accessibilityIdentifier("ledger.cash-adjustment.begin")
                if !model.cashAdjustmentStatus.isEmpty {
                    Text(model.cashAdjustmentStatus).font(.footnote).foregroundStyle(.secondary)
                }
                if model.cashFlow.isEmpty { Text("暂无可读取的现金流水").foregroundStyle(.secondary) }
                ForEach(model.cashFlow.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        let isCashOnlyAdjustment = entry.reason.hasPrefix("其他费用/现金对账：")
                        Text("\(isCashOnlyAdjustment ? "现金对账调整" : entry.kind.label)\(entry.instrumentName.map { " · \($0)" } ?? "")")
                        Text("\(entry.occurredAt.formatted(date: .numeric, time: .shortened)) · 变动 \(entry.cashDelta.description) · 余额 \(entry.resultingCashBalance.description) · 手续费 \(entry.fee.description)")
                            .font(.caption).foregroundStyle(.secondary)
                        if isCashOnlyAdjustment { Text(entry.reason).font(.caption2).foregroundStyle(.secondary) }
                        if let fillID = entry.sourceFillID, let effectiveFee = entry.effectiveFee {
                            Button("对账 / 更正此笔手续费（当前 \(effectiveFee.description)）") {
                                model.beginFeeCorrection(for: entry)
                            }
                            .font(.caption)
                            .accessibilityIdentifier("ledger.fee-correction.\(fillID.uuidString)")
                        }
                    }
                }
            }
            Section("资产安全") {
                Label("AI 建议和候选计划不写入真实账本", systemImage: "lock.shield")
                Text("只有用户确认实际成交后才写入账本；所有成交和现金变动保留在历史流水中。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("assets.list")
        .navigationTitle("真实资产")
        .sheet(isPresented: $model.showingFeeCorrection) {
            FLedgerFeeCorrectionSheet(model: model)
        }
    }

    private func assetSummaryRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }
}

private extension FReadOnlyCashFlowKind {
    var label: String {
        switch self {
        case .openingBalance: "期初现金"
        case .buy: "买入"
        case .sell: "卖出"
        case .feeAdjustment: "手续费调整"
        case .deposit: "现金转入"
        case .withdrawal: "现金转出"
        }
    }
}

struct SettingsOverview: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @AppStorage("guanpan.f.nas.baseURL") private var nasBaseAddress = ""
    @State private var deepSeekKeyDraft = ""
    private var theme: FHomeTheme { FHomeTheme(rawValue: themeRaw) ?? .editorial }

    var body: some View {
        Form {
            Section("主题") {
                Picker("完整主题", selection: $themeRaw) {
                    ForEach(FHomeTheme.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                Text("主题统一控制页面布局、文字和卡片外观；这里不提供自由文字色盘。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("在线 AI") {
                SecureField("DeepSeek API Key", text: $deepSeekKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.ai.deepseekKey")
                Button("安全保存 DeepSeek Key") {
                    model.saveDeepSeekKey(deepSeekKeyDraft)
                    deepSeekKeyDraft = ""
                }
                .accessibilityIdentifier("settings.ai.saveKey")
                LabeledContent("状态", value: model.aiKeyStatus)
            }
            Section("NAS 连接") {
                TextField("NAS 地址，例如 http://192.168.1.20:8788", text: $nasBaseAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button {
                    Task {
                        await model.configureAndTestNAS(baseAddress: nasBaseAddress)
                    }
                } label: {
                    if model.checkingNASConnection {
                        HStack { ProgressView().controlSize(.small); Text("正在检查 NAS") }
                    } else {
                        Label("保存并测试 NAS", systemImage: "network")
                    }
                }
                .disabled(model.checkingNASConnection)
                .accessibilityIdentifier("settings.nas.test")
                Text(model.nasConnectionStatus)
                    .font(.caption).foregroundStyle(.secondary)
                Text("NAS API 不要求单独令牌。连接测试只读取 /readyz，不发送持仓。8788 端口对可达网络开放；远程访问请使用 HTTPS 并限制网络入口。")
                    .font(.footnote).foregroundStyle(.secondary)
                LabeledContent("同步", value: "未连接")
                LabeledContent("新闻", value: "未接入")
            }
            Section("数据诊断") {
                LabeledContent("真实账本", value: model.ledgerStatus)
                LabeledContent("交易日历", value: model.marketCalendarStatusText)
                if model.marketRefreshStateByCode.isEmpty {
                    Text("尚无行情请求记录").foregroundStyle(.secondary)
                } else {
                    ForEach(model.marketRefreshStateByCode.keys.sorted(), id: \.self) { code in
                        LabeledContent(code, value: model.marketRefreshStateByCode[code] ?? "状态未知")
                    }
                }
            }
            Section("高级研究") {
                LabeledContent("股息判断", value: "自动 / AI 综合判断")
                Text("4% 仅作为研究参考；当前 App 尚未提供自定义最低股息率设置。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings.form")
        .navigationTitle("设置")
        .tint(theme.accent)
    }
}

struct MarketOverview: View {
    @ObservedObject var model: FHomeModel
    @State private var securityLookupCode = ""

    private var isValidSecurityCode: Bool {
        let bytes = securityLookupCode.utf8
        return bytes.count == 6 && bytes.allSatisfy { (48...57).contains($0) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("实时分时行情").font(.headline)
                        Text("报价每 10 秒请求；图表使用上游分钟时间戳。")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(model.marketCalendarStatusText).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await model.autoRefreshMarketData() }
                    } label: {
                        if model.refreshingMarketCodes.isEmpty {
                            Label("刷新", systemImage: "arrow.clockwise")
                        } else {
                            HStack { ProgressView().controlSize(.small); Text("更新中") }
                        }
                    }
                    .disabled(!model.refreshingMarketCodes.isEmpty || model.holdings.isEmpty)
                    .accessibilityIdentifier("market.refresh.all")
                }
            }
            Section("证券查询") {
                TextField("输入6位证券代码", text: $securityLookupCode)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("market.security-code")
                    .onChange(of: securityLookupCode) { value in
                        let digits = String(value.unicodeScalars
                            .filter { (48...57).contains($0.value) }.prefix(6))
                        if digits != value { securityLookupCode = digits }
                    }
                NavigationLink(value: FHomeRoute.instrument(securityLookupCode)) {
                    Label("打开证券详情", systemImage: "arrow.up.forward")
                }
                .disabled(!isValidSecurityCode)
                .accessibilityIdentifier("market.open-security")
                Text("可以查看未持仓证券；真实资产仍只来自本机账本。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.holdings.isEmpty {
                Text("真实账本当前没有持仓标的。行情和图表只会显示所选证券的真实上游数据。")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.holdings) { holding in
                let snapshot = model.marketDataByCode[holding.instrumentCode]
                NavigationLink(value: FHomeRoute.instrument(holding.instrumentCode)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(holding.name).font(.headline)
                                Text(holding.instrumentCode).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(snapshot?.latestPrice.map { "¥\($0.description)" } ?? "—")
                                .font(.title3.weight(.semibold)).monospacedDigit()
                        }
                        FUnifiedSecurityChart(
                            model: FChartPresentationBuilder.live(snapshot, holding: holding,
                                                                  candidate: model.advisorResult?.candidate,
                                                                  ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt),
                            height: 115)
                        Text(snapshot.map {
                            "行情时间 \($0.quoteTimestamp.formatted(date: .omitted, time: .standard)) · 获取于 \($0.fetchedAt.formatted(date: .omitted, time: .standard)) · \($0.source)"
                        } ?? "行情时间/来源待获取")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        Text(model.marketRefreshStateByCode[holding.instrumentCode] ?? "等待首次请求")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(.vertical, 6)
                }
                .accessibilityIdentifier("market.instrument.\(holding.instrumentCode)")
            }
        }
        .navigationTitle("今日市场观察")
        .refreshable { await model.autoRefreshMarketData() }
    }
}

private struct FAdvisorResultCard: View {
    let result: FAdvisorVerticalSliceResult
    let accent: Color
    let confirmLedger: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("顾问结论 · \(result.scopeTitle)").font(.headline)
            Text(result.narrative.conclusion).font(.title3.weight(.semibold))
            Text("依据").font(.subheadline.bold())
            Text(result.narrative.basis).font(.subheadline)
            LabeledContent("真实账本", value: "只读快照 · \(result.ledgerCapturedAt.formatted(date: .abbreviated, time: .shortened))")
            Text("真实持仓").font(.subheadline.bold())
            Text(result.holdingSummary).font(.caption).fixedSize(horizontal: false, vertical: true)
            LabeledContent("可用现金", value: "¥\(NSDecimalNumber(decimal: result.cashBalance))")
            Text("行情").font(.subheadline.bold())
            Text(result.quoteStatus).font(.caption).fixedSize(horizontal: false, vertical: true)
            Text("NAS 研究").font(.subheadline.bold())
            Text(result.researchStatus).font(.caption).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("风险").font(.subheadline.bold())
                ForEach(Array(result.narrative.risks.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)").font(.caption)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("失效条件").font(.subheadline.bold())
                ForEach(Array(result.narrative.invalidationConditions.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)").font(.caption)
                }
            }
            Divider()
            if result.isReviewable {
                if result.candidate.action == .hold || result.candidate.action == .wait {
                    Label("\(result.candidate.action.displayName) · 当前不生成交易候选", systemImage: "pause.circle")
                        .foregroundStyle(accent)
                } else {
                    Text("Candidate Plan · 仅供用户审阅").font(.subheadline.bold())
                    Text(candidateDescription).font(.subheadline)
                    if result.candidate.action == .dayTrade {
                        Label("保守基础做 T · 盘口未接入，未用于判断", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Label("Guard 已通过人工审阅门槛；不下单、不写 Ledger", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                    if result.candidate.action == .buy || result.candidate.action == .sell {
                        Button("登记用户确认的真实成交", action: confirmLedger)
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .accessibilityIdentifier("advisor.confirm-real-fill")
                    } else {
                        Text("做T、网格和回本仅作分析；请逐笔核对真实成交后另行登记。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Guard 已阻止此候选计划").font(.subheadline.bold()).foregroundStyle(.red)
                ForEach(Array(result.assessment.guardResult.findings.enumerated()), id: \.offset) { _, item in
                    Text("• \(item.displayName)").font(.caption).foregroundStyle(.red)
                }
            }
            Text("真实资产只能在用户确认真实成交后变化；此结果没有账本写入能力。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var candidateDescription: String {
        let candidate = result.candidate
        let units = candidate.units.map { "\($0) 份" } ?? "份额未给出"
        let price = candidate.limitPrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? "价格未给出"
        let fee = NSDecimalNumber(decimal: candidate.estimatedFee).stringValue
        return "\(candidate.action.displayName) · \(candidate.instrumentCode ?? result.securityCode) · \(units) · 限价 ¥\(price) · 估算费用 ¥\(fee)"
    }
}

struct FLedgerConfirmationSheet: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("实际成交") {
                    TextField("证券名称", text: $model.actualFillInstrumentName)
                    TextField("实际成交份额", text: $model.actualFillUnitsText)
                        .keyboardType(.numberPad)
                    TextField("实际成交价格", text: $model.actualFillPriceText)
                        .keyboardType(.decimalPad)
                    TextField("实际手续费（默认参考 ¥0.10）", text: $model.actualFillFeeText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("ledger.fill.actual-fee")
                    Text("请按券商实际收取金额填写；¥0.10只是默认参考，确认后将按此费用记入现金和成本/盈亏。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("成交性质（默认普通交易）") {
                    Picker("用途", selection: $model.actualFillTradeIntent) {
                        ForEach(FTradeIntent.allCases, id: \.self) { intent in
                            Text(intent.displayName).tag(intent)
                        }
                    }
                    .accessibilityIdentifier("ledger.fill.intent")
                    if model.actualFillTradeIntent != .ordinary {
                        TextField("T配对编号（卖出与买回填写相同值）",
                                  text: $model.actualFillTCycleID)
                            .accessibilityIdentifier("ledger.fill.t-cycle")
                        Text("只有同一证券、同一交易日、相同编号且先卖后买的真实确认成交才计入T贡献；按成交顺序FIFO匹配已买回份额，未买回卖出余量不算完成T，买回超出可配对卖出量时显示无法精确归类。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("不可逆确认") {
                    TextField("确认说明（必填）", text: $model.ledgerConfirmationNote,
                              axis: .vertical)
                        .lineLimit(2...4)
                    Text("此操作只会登记你已实际完成且确认无误的一笔成交；不会向券商下单。写入成功后，旧 Candidate Plan 将失效，并以更新后的真实账本重新判断。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !model.ledgerWriteStatus.isEmpty {
                    Section("状态") { Text(model.ledgerWriteStatus).font(.footnote) }
                }
            }
            .navigationTitle("确认真实成交")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(model.writingConfirmedFill)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.writingConfirmedFill ? "写入中" : "确认写入") {
                        model.confirmPendingFill()
                    }
                    .disabled(model.writingConfirmedFill ||
                              model.ledgerConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct FLedgerFeeCorrectionSheet: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("逐笔成交费用对账") {
                    TextField("修正后的该笔总手续费", text: $model.correctedFeeText)
                        .keyboardType(.decimalPad)
                    TextField("差额原因（如券商费用补扣/退回）", text: $model.feeCorrectionReason,
                              axis: .vertical)
                        .lineLimit(2...3)
                    Text("原成交记录不会修改。现金差额记在今天；证券成本和历史盈亏按这笔原始成交重新计算。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("确认更正") {
                    TextField("确认说明（必填）", text: $model.feeCorrectionConfirmationNote,
                              axis: .vertical)
                        .lineLimit(2...4)
                }
                if !model.ledgerWriteStatus.isEmpty {
                    Section("状态") { Text(model.ledgerWriteStatus).font(.footnote) }
                }
            }
            .navigationTitle("成交费用对账")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(model.writingFeeCorrection)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.writingFeeCorrection ? "保存中" : "确认更正") {
                        model.confirmFeeCorrection()
                    }
                    .disabled(model.writingFeeCorrection ||
                              model.feeCorrectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              model.feeCorrectionConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct FCashAdjustmentSheet: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("僅調整現金") {
                    Picker("现金方向", selection: $model.cashAdjustmentAddsCash) {
                        Text("减少现金 / 记其他费用").tag(false)
                        Text("增加现金 / 余额补差").tag(true)
                    }
                    TextField("金额（正数）", text: $model.cashAdjustmentAmountText)
                        .keyboardType(.decimalPad)
                    TextField("费用或对账原因", text: $model.cashAdjustmentReason,
                              axis: .vertical)
                        .lineLimit(2...3)
                    Text("无法归属到具体成交的费用只记入现金；不会改变任何证券成本、已实现盈亏或持仓数量。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("确认更正") {
                    TextField("确认说明（必填）", text: $model.cashAdjustmentConfirmationNote,
                              axis: .vertical)
                        .lineLimit(2...4)
                }
                if !model.cashAdjustmentStatus.isEmpty {
                    Section("状态") { Text(model.cashAdjustmentStatus).font(.footnote) }
                }
            }
            .navigationTitle("现金对账差额")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(model.writingCashAdjustment)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.writingCashAdjustment ? "保存中" : "确认调整") {
                        model.confirmCashAdjustment()
                    }
                    .disabled(model.writingCashAdjustment ||
                              model.cashAdjustmentReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              model.cashAdjustmentConfirmationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private extension FDecisionAction {
    var displayName: String {
        switch self {
        case .hold: return "继续持有"
        case .wait: return "等待 / 不交易"
        case .buy: return "买入建议"
        case .sell: return "卖出建议"
        case .dayTrade: return "做 T 建议"
        case .grid: return "网格建议"
        case .recoveryPlan: return "回本分析"
        }
    }
}

extension FMarketSessionStatus {
    var displayName: String {
        switch self {
        case .preOpen: return "盘前"
        case .continuous: return "交易中"
        case .lunchBreak: return "午间休市"
        case .closed: return "已收盘"
        case .unknown: return "交易日历未覆盖"
        }
    }
}

private extension FDecisionGuardFinding {
    var displayName: String {
        switch self {
        case .invalidContext: return "DecisionContext 校验失败"
        case .accountChanged: return "真实账本状态不匹配"
        case .invalidCandidate: return "候选计划字段无效"
        case .missingFreshQuote(let code): return "\(code) 缺少可信新鲜行情"
        case .staleCitedEvidence(_): return "引用行情证据已过期"
        case .missingCitedEvidence(_): return "引用的行情证据不存在"
        case .insufficientCash: return "真实现金不足"
        case .insufficientUnits: return "真实持仓份额不足"
        case .advisorRequestContextMismatch: return "AI 请求与冻结上下文不一致"
        case .instrumentScopeMismatch(_, _): return "AI 返回标的与分析对象不一致"
        case .staleResearchEvidence(_): return "NAS 研究未达到有效性门槛"
        case .missingResearchEvidence(_): return "引用的 NAS 研究证据不存在"
        case .missingDecisionMemory(_): return "引用的 Decision Memory 不存在"
        case .missingInvestorProfileRevision(_): return "引用的画像版本不存在"
        case .missingQualifiedResearch(let key): return "缺少合格策略研究：\(key)"
        case .incompleteTradingEvidence(let reason): return reason
        }
    }
}
