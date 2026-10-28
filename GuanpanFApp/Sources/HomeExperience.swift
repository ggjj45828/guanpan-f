Warning: truncated output (original token count: 24886)
Total output lines: 1918

import SwiftUI
import FCore
import FAdvisor

extension FHomeTheme {
    var background: Color { manifest.tokens.background }
    var ink: Color { manifest.tokens.foreground }
    var accent: Color { manifest.tokens.accent }
}

struct HomeLayout: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    var body: some View {
        ScrollView {
            Group {
                switch theme.layoutFamily {
                case .editorial: editorial
                case .cardGrid: modern
                case .terminalDashboard: dashboard
                case .magazine: magazine
                case .staticBento: bento
                case .inkEditorial: inkEditorial
                case .minimalTerminal: minimalTerminal
                case .spatialGlass: fluidGlass
                case .radialMap: dataStarMap
                case .adaptiveBento: adaptiveBento
                }
            }
            .padding(theme.manifest.tokens.spacing.standard)
        }
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
    }

    private var editorial: some View {
        VStack(alignment: .leading, spacing: 18) {
            HomeMasthead(model: model, theme: theme, eyebrow: "观盘手记 · 今日组合")
            HomeAdvisorLead(model: model, theme: theme, treatment: .editorial)
            HomePortfolioLead(model: model, theme: theme, treatment: .editorial)
            HomeMarketResearchStrip(model: model, theme: theme)
        }
    }

    private var modern: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                role(.marketObservation)
                role(.crossMarketPulse)
                role(.portfolio)
            }
            role(.advisorGuidance)
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeMasthead(model: model, theme: theme, eyebrow: "观盘max / LIVE PORTFOLIO")
                .padding(.bottom, 14)
            HomePortfolioLead(model: model, theme: theme, treatment: .terminal)
                .padding(.bottom, 12)
            Divider().overlay(theme.accent.opacity(0.5))
            HomeMarketResearchStrip(model: model, theme: theme)
                .padding(.vertical, 12)
            Divider().overlay(theme.accent.opacity(0.5))
            HomeAdvisorLead(model: model, theme: theme, treatment: .terminal)
                .padding(.top, 12)
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
            role(.advisorGuidance)
            role(.portfolio)
            role(.marketObservation)
            role(.crossMarketPulse)
        }
    }

    private var bento: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                role(.portfolio).frame(maxWidth: .infinity, minHeight: 210)
                role(.marketObservation)
                    .frame(maxWidth: .infinity, minHeight: 210)
            }
            HStack(spacing: 12) {
                role(.crossMarketPulse)
            }
            role(.advisorGuidance)
        }
    }

    private var inkEditorial: some View {
        VStack(alignment: .leading, spacing: 24) {
            HomeMasthead(model: model, theme: theme, eyebrow: "编辑部 · 观盘手记")
            Text("先看组合，\n再做决定。")
                .font(.system(size: 38, weight: .regular, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(theme.accent).frame(width: 44, height: 3)
            HomeAdvisorLead(model: model, theme: theme, treatment: .editorial)
            HomePortfolioLead(model: model, theme: theme, treatment: .editorial)
            HomeMarketResearchStrip(model: model, theme: theme)
        }
    }

    private var minimalTerminal: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("F / PORTFOLIO").font(.caption.monospaced().weight(.semibold))
                Spacer()
                Text(model.cashText).font(.title3.monospacedDigit().weight(.bold))
            }.padding(.vertical, 12)
            Divider()
            role(.marketObservation).padding(.vertical, 8)
            Divider()
            role(.portfolio).padding(.vertical, 8)
            Divider()
            Text("ADVISOR STREAM").font(.caption.monospaced().weight(.semibold)).padding(.top, 12)
            role(.advisorGuidance).padding(.vertical, 8)
            Divider()
            role(.crossMarketPulse).padding(.vertical, 8)
        }
    }

    private var fluidGlass: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeMasthead(model: model, theme: theme, eyebrow: "你的投资空间")
            HomeAdvisorLead(model: model, theme: theme, treatment: .glass)
            HStack(alignment: .top, spacing: 12) {
                HomePortfolioLead(model: model, theme: theme, treatment: .glass)
                    .frame(maxWidth: .infinity)
                HomeMarketResearchStrip(model: model, theme: theme, compact: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dataStarMap: some View {
        VStack(spacing: 12) {
            Text("组合关系星图").font(.title2.weight(.semibold))
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                ZStack {
                    Circle().stroke(theme.accent.opacity(0.25), lineWidth: 1)
                        .frame(width: min(width * 0.78, 300), height: min(width * 0.78, 300))
                        .position(x: width / 2, y: height / 2)
                    Path { path in
                        let center = CGPoint(x: width / 2, y: height / 2)
                        for point in [CGPoint(x: width / 2, y: 48), CGPoint(x: width - 68, y: height / 2),
                                      CGPoint(x: width / 2, y: height - 48), CGPoint(x: 68, y: height / 2)] {
                            path.move(to: center); path.addLine(to: point)
                        }
                    }.stroke(theme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    centralStarSummary.frame(width: min(width * 0.52, 210), height: 150)
                        .position(x: width / 2, y: height / 2)
                    orbitNode(.marketObservation, shortTitle: "市场", x: width / 2, y: 48)
                    orbitNode(.crossMarketPulse, shortTitle: "跨市场", x: width - 68, y: height / 2)
                    orbitNode(.portfolio, shortTitle: "持仓", x: width / 2, y: height - 48)
                    orbitNode(.advisorGuidance, shortTitle: "AI 决策", x: 68, y: height / 2)
                }
            }
            .frame(height: 430)
            Text("外围节点进入各自独立页面；证券详情与图表保持专业操作方式。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var centralStarSummary: some View {
        VStack(spacing: 8) {
            Text("真实组合中心").font(.headline)
            Text(model.cashText).font(.title3.monospacedDigit().weight(.bold))
            Text("\(model.holdings.count) 项真实持仓").font(.caption)
            Text(portfolioConclusion)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.accent.opacity(0.6), lineWidth: 1))
    }

    private var portfolioConclusion: String {
        guard let result = model.advisorResult, result.scope == .portfolio else {
            return "组合级判断等待更新"
        }
        return result.narrative.conclusion
    }

    private func orbitNode(_ role: FHomeCardRole, shortTitle: String, x: CGFloat, y: CGFloat) -> some View {
        NavigationLink(value: role.route) {
            VStack(spacing: 4) {
                Image(systemName: role.symbol).foregroundStyle(theme.accent)
                Text(shortTitle).font(.caption.weight(.semibold))
            }
            .frame(width: 98, height: 62)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(theme.accent.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
        .accessibilityIdentifier("theme.starmap.\(role.rawValue)")
    }

    private var adaptiveBento: some View {
        let attention = model.ledgerState != .available ||
            (model.advisorResult.map { !$0.assessment.isEligibleForUserReview } ?? false)
        return VStack(spacing: 12) {
            if attention {
                role(.advisorGuidance).frame(minHeight: 250)
                role(.portfolio).frame(minHeight: 145)
                HStack(spacing: 12) {
                    role(.marketObservation)
                    role(.crossMarketPulse)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    role(.portfolio).frame(maxWidth: .infinity, minHeight: 220)
                    role(.marketObservation).frame(maxWidth: .infinity, minHeight: 220)
                }
                role(.crossMarketPulse).frame(minHeight: 100)
                role(.advisorGuidance)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: attention)
    }

    @ViewBuilder
    private func role(_ role: FHomeCardRole) -> some View {
        FHomeRoleRenderer(role: role, model: model, theme: theme)
    }

}

private enum HomeLeadTreatment: Equatable {
    case editorial, terminal, glass
}

private struct HomeMasthead: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    let eyebrow: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold)).tracking(1.1)
                    .foregroundStyle(theme.accent)
                Spacer(minLength: 8)
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day().weekday(.wide)))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 7) {
                Circle().fill(model.ledgerState == .available ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(model.ledgerState == .available ? "本机真实账本" : model.ledgerStatus)
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("只读快照")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct HomeAdvisorLead: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    let treatment: HomeLeadTreatment

    private var portfolioResult: FAdvisorVerticalSliceResult? {
        guard let result = model.advisorResult, result.scope == .portfolio else { return nil }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(theme.accent)
                Text("AI 今日指导").font(.headline)
                Spacer()
                Text(portfolioResult?.isReviewable == true ? "已完成组合分析" : "组合级")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }

            if let result = portfolioResult {
                Text(result.narrative.conclusion)
                    .font(.system(size: 23, weight: .semibold, design: treatment == .terminal ? .monospaced : .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.advisor.portfolio-conclusion")
                Text(result.narrative.basis)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if result.isReviewable {
                        Label(result.candidate.action.displayName,
                              systemImage: result.candidate.action == .wait || result.candidate.action == .hold
                                ? "pause.circle" : "checkmark.shield")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    } else {
                        Label("Guard 阻止候选", systemImage: "exclamationmark.shield")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.manifest.tokens.warning)
                    }
                    if let firstRisk = result.narrative.risks.first {
                        Text(firstRisk).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let invalidation = result.narrative.invalidationConditions.first {
                    Text("失效条件 · \(invalidation)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            } else if let result = model.advisorResult {
                Text("最近分析针对 \(result.securityCode)，不是组合判断。")
                    .font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text("首页不会把单只证券结论当成全组合建议。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("先读完整持仓，再给今天的判断。")
                    .font(.system(size: 23, weight: .semibold, design: treatment == .terminal ? .monospaced : .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.advisorStatus == "尚未开始分析"
                     ? "组合判断尚未生成。生成前不会用单只证券替代整个组合。"
                     : model.advisorStatus)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    model.question = "今天我的持仓需要操作吗？"
                    model.askAdvisor()
                } label: {
                    HStack(spacing: 7) {
                        if model.isAskingAdvisor { ProgressView().tint(.white) }
                        Text(model.isAskingAdvisor ? "正在分析真实组合" : "分析我的真实组合")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .foregroundStyle(.white)
                    .background(theme.accent, in: Capsule())
                }
                .disabled(model.isAskingAdvisor || model.ledgerState != .available)
                .accessibilityIdentifier("home.advisor.analyze-portfolio")

                NavigationLink(value: FHomeRoute.advisor) {
                    Label("查看证据", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44).padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(treatment == .terminal ? 12 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: treatment == .glass ? 28 : 20))
        .overlay(alignment: .leading) {
            if treatment == .editorial {
                Rectangle().fill(theme.accent).frame(width: 3).padding(.vertical, 18)
            }
        }
        .accessibilityIdentifier("home.advisor.lead")
    }
}

private struct HomePortfolioLead: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    let treatment: HomeLeadTreatment

    private var freshQuoteCount: Int {
        let now = Date()
        return model.holdings.filter { holding in
            guard let quote = model.marketDataByCode[holding.instrumentCode] else { return false }
            return quote.latestPrice != nil && quote.quoteTimestamp <= now &&
                now.timeIntervalSince(quote.quoteTimestamp) <= 120
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的真实资产").font(.headline)
                    Text(model.ledgerState == .available ? "来自本机 Ledger" : model.ledgerStatus)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                NavigationLink(value: FHomeRoute.portfolio) {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看真实资产明细")
            }

            HStack(alignment: .top, spacing: 0) {
                metric("可用现金", value: model.cashText)
                Rectangle().fill(theme.ink.opacity(0.12)).frame(width: 1, height: 42)
                    .padding(.horizontal, 14)
                metric("当前持仓", value: model.ledgerState == .available ? "\(model.holdings.count) 只" : "未确认")
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(theme.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日盈亏")
                        .font(.subheadline.weight(.medium))
                    Text("暂不可用 · 缺少可靠的日初持仓与前收口径")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)

            if !model.holdings.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(model.holdings.prefix(2))) { holding in
                        NavigationLink(value: FHomeRoute.instrument(holding.instrumentCode)) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(holding.name).font(.subheadline.weight(.semibold))
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                    Text("\(holding.instrumentCode) · \(holding.units) 份")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 6)
                                compactHoldingMark(holding)
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if holding.id != model.holdings.prefix(2).last?.id {
                            Divider().opacity(0.6)
                        }
                    }
                }
                .padding(.top, 2)
            } else if model.ledgerState == .available {
                Text("账本已读取，目前没有真实持仓。历史清仓记录仍保留在资产页。")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Circle().fill(freshQuoteCount == model.holdings.count && !model.holdings.isEmpty
                              ? theme.manifest.tokens.positive : theme.manifest.tokens.unavailable)
                    .frame(width: 6, height: 6)
                Text("持仓行情 \(freshQuoteCount)/\(model.holdings.count) 条新鲜")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text("Episode成本为主 · 券商成本辅助")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.top, 2)
        }
        .padding(treatment == .terminal ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: treatment == .glass ? 24 : 18))
        .accessibilityIdentifier("home.portfolio.lead")
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: treatment == .terminal ? 21 : 25,
                                     weight: .bold,
                                     design: treatment == .terminal ? .monospaced : .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func compactHoldingMark(_ holding: FHomeHolding) -> some View {
        let now = Date()
        if let quote = model.marketDataByCode[holding.instrumentCode],
           let price = quote.latestPrice,
           quote.quoteTimestamp <= now, now.timeIntervalSince(quote.quoteTimestamp) <= 120,
           let pnl = try? FSecurityPnLCalculator.episodeUnrealizedPnL(
                units: holding.units, bookCost: holding.bookCost, currentPrice: price
           ) {
            VStack(alignment: .trailing, spacing: 3) {
                Text("¥\(NSDecimalNumber(decimal: price).stringValue)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text("本轮 \(pnl >= 0 ? "+" : "")¥\(NSDecimalNumber(decimal: pnl).stringValue)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(pnl >= 0 ? theme.manifest.tokens.p…12886 tokens truncated…rame(width: 26, height: 7)
                            .position(x: [proxy.size.width / 2, proxy.size.width - 24,
                                          proxy.size.width / 2, 24][index],
                                      y: [5, 25, 45, 25][index])
                    }
                }
            }
            .frame(height: 50)
        case .staticBento, .adaptiveBento:
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    previewBlock(height: theme.layoutFamily == .adaptiveBento ? 18 : 14)
                    previewBlock(height: theme.layoutFamily == .adaptiveBento ? 18 : 14)
                }
                HStack(spacing: 3) {
                    previewBlock(height: 7)
                    previewBlock(height: 7)
                    previewBlock(height: 7)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        case .minimalTerminal, .terminalDashboard:
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle().fill(theme.accent.opacity(0.3 + Double(index) * 0.12))
                        .frame(width: CGFloat(80 - index * 11), height: 1)
                }
            }
            .frame(height: 40, alignment: .center)
        case .inkEditorial, .magazine:
            VStack(alignment: .leading, spacing: 4) {
                Rectangle().fill(theme.accent.opacity(0.7)).frame(width: 42, height: 3)
                Rectangle().fill(theme.accent.opacity(0.42)).frame(width: 96, height: 7)
                Rectangle().fill(theme.accent.opacity(0.24)).frame(width: 70, height: 4)
            }
            .frame(height: 40, alignment: .center)
        default:
            HStack(spacing: 3) {
                ForEach(manifest.layout.roleOrder.indices, id: \.self) { index in
                    let role = manifest.layout.roleOrder[index]
                    RoundedRectangle(cornerRadius: isTerminal ? 1 : 4)
                        .fill(theme.accent.opacity(0.25 + Double(index) * 0.14))
                        .frame(width: previewWidth(for: role), height: previewHeight(for: role))
                }
            }
            .frame(height: 40)
        }
    }

    private func previewBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(theme.accent.opacity(0.42))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func previewWidth(for role: FHomeCardRole) -> CGFloat {
        switch theme.layoutFamily {
        case .radialMap: return role == .advisorGuidance || role == .portfolio ? 34 : 18
        case .minimalTerminal: return role == .portfolio ? 42 : 28
        case .staticBento, .adaptiveBento: return role == .advisorGuidance || role == .portfolio ? 40 : 22
        default: return 30
        }
    }

    private func previewHeight(for role: FHomeCardRole) -> CGFloat {
        switch theme.layoutFamily {
        case .magazine, .inkEditorial: return role == .advisorGuidance ? 13 : 7
        case .radialMap: return 10
        case .minimalTerminal: return 4
        case .staticBento, .adaptiveBento: return role == .advisorGuidance ? 15 : 8
        default: return 9
        }
    }
}

struct MarketOverview: View {
    @ObservedObject var model: FHomeModel
    @State private var securityLookupCode = ""
    @FocusState private var securityLookupFocused: Bool

    private var isValidSecurityCode: Bool {
        let bytes = securityLookupCode.utf8
        return bytes.count == 6 && bytes.allSatisfy { (48...57).contains($0) }
    }

    private var refreshableSecurityCodes: [String] {
        let heldCodes = model.holdings.map(\.instrumentCode)
        let lookupCodes = isValidSecurityCode ? [securityLookupCode] : []
        return Array(Set(heldCodes + lookupCodes)).sorted()
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
                        Task { await model.refreshMarketData(for: refreshableSecurityCodes) }
                    } label: {
                        if model.refreshingMarketCodes.isEmpty {
                            Label("刷新", systemImage: "arrow.clockwise")
                        } else {
                            HStack { ProgressView().controlSize(.small); Text("更新中") }
                        }
                    }
                    .disabled(!model.refreshingMarketCodes.isEmpty || refreshableSecurityCodes.isEmpty)
                    .accessibilityIdentifier("market.refresh.all")
                }
            }
            Section("证券查询") {
                TextField("输入6位证券代码", text: $securityLookupCode)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .focused($securityLookupFocused)
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { securityLookupFocused = false }
            }
        }
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

