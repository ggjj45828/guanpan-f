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
        VStack(alignment: .leading, spacing: 14) {
            FEditorialMasthead(model: model, theme: theme)
            FEditorialMarketRibbon(model: model, theme: theme)
            HomeAdvisorLead(model: model, theme: theme, treatment: .editorial)
            FEditorialResearchLine(model: model, theme: theme)
            HomePortfolioLead(model: model, theme: theme, treatment: .editorial)
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
        .modifier(FThemeSurfaceModifier(theme: theme, radius: 24))
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
            .modifier(FThemeSurfaceModifier(theme: theme, radius: 32))
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

/// Editorial home donor adaptation: the arrangement follows B's compact masthead
/// and market-first rhythm while every value and destination comes from F models.
private struct FEditorialMasthead: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date())
    }

    private var portfolioCountText: String {
        switch model.ledgerState {
        case .available: return "\(model.holdings.count) 只持仓"
        case .loading: return "账本读取中"
        case .notEstablished: return "尚未建立账本"
        case .unavailable: return "持仓状态不可用"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("观盘 MAX  ·  今日组合")
                    .font(.caption.weight(.semibold)).tracking(0.8)
                    .foregroundStyle(theme.accent)
                Spacer()
                NavigationLink(value: FHomeRoute.market) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看行情")
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(greeting)，")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(theme.ink)
                    Text(dateText)
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("先看真实组合，再判断今天。")
                        .font(.subheadline.weight(.medium)).foregroundStyle(theme.ink.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "sparkles")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(theme.accent)
                    .frame(width: 52, height: 52)
                    .background(theme.accent.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)
            }
            HStack(spacing: 7) {
                Circle().fill(model.ledgerState == .available ? theme.manifest.tokens.positive : theme.manifest.tokens.warning)
                    .frame(width: 7, height: 7)
                Text(model.ledgerState == .available ? "本机真实账本已读取" : model.ledgerStatus)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(portfolioCountText)
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }
}

private struct FEditorialMarketRibbon: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme

    private var codes: [String] {
        Array(Set(model.holdings.map(\.instrumentCode) + model.watchlistCodes)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("市场速览").font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.marketCalendarStatusText)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            if codes.isEmpty {
                NavigationLink(value: FHomeRoute.market) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line").foregroundStyle(theme.accent)
                        Text("添加自选证券后，在这里查看真实行情")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(codes.prefix(6), id: \.self) { code in
                            quoteChip(code)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(theme.ink.opacity(0.10)).frame(height: 0.7) }
        .overlay(alignment: .bottom) { Rectangle().fill(theme.ink.opacity(0.10)).frame(height: 0.7) }
    }

    private func quoteChip(_ code: String) -> some View {
        let snapshot = model.marketDataByCode[code]
        let now = Date()
        let isFresh = snapshot.map {
            $0.latestPrice != nil && $0.quoteTimestamp <= now && now.timeIntervalSince($0.quoteTimestamp) <= 120
        } ?? false
        let name = model.holdings.first(where: { $0.instrumentCode == code })?.name ?? code
        let quoteStatus = snapshot.map {
            "\(isFresh ? "行情时间" : "旧行情") · \($0.quoteTimestamp.formatted(date: .omitted, time: .shortened))"
        } ?? model.marketRefreshStateByCode[code] ?? "等待真实报价"
        return NavigationLink(value: FHomeRoute.instrument(code)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(name).font(.caption.weight(.semibold)).lineLimit(1)
                    Circle().fill(isFresh ? theme.manifest.tokens.positive : theme.manifest.tokens.unavailable)
                        .frame(width: 5, height: 5)
                }
                Text(snapshot?.latestPrice.map { "¥\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "行情待更新")
                    .font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(isFresh ? theme.ink : theme.manifest.tokens.unavailable)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text("\(code) · \(quoteStatus)")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 142, alignment: .leading)
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(theme.manifest.tokens.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.ink.opacity(0.08), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }
}

private struct FEditorialResearchLine: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme

    var body: some View {
        NavigationLink(value: FHomeRoute.crossMarket) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "globe.asia.australia").foregroundStyle(theme.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("跨市场与研究").font(.caption.weight(.semibold)).foregroundStyle(theme.ink)
                    Text("跨市场实时联动尚未接入 · NAS 为可选归档增强（\(model.nasConnectionStatus)）")
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
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
                Text(portfolioResult.map { "上次分析 · \($0.generatedAt.formatted(date: .omitted, time: .shortened))" } ?? "组合级")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }

            if model.isAskingAdvisor, portfolioResult != nil {
                Label("正在更新 · 暂时显示上次组合判断", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.manifest.tokens.warning)
            } else if let result = portfolioResult,
                      model.advisorStatus != "尚未开始分析",
                      !model.advisorStatus.hasPrefix("已完成 DecisionContext") {
                Label("最近请求未完成 · 仍显示 \(result.generatedAt.formatted(date: .omitted, time: .shortened)) 的组合判断",
                      systemImage: "exclamationmark.clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.manifest.tokens.warning)
                    .fixedSize(horizontal: false, vertical: true)
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
                        Text(model.isAskingAdvisor ? "正在分析真实组合" : (portfolioResult == nil ? "生成组合判断" : "更新组合判断"))
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
                    .foregroundStyle(pnl >= 0 ? theme.manifest.tokens.positive : theme.manifest.tokens.negative)
            }
        } else {
            Text("行情待更新")
                .font(.caption2).foregroundStyle(theme.manifest.tokens.unavailable)
        }
    }
}

private struct HomeMarketResearchStrip: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    var compact = false

    private var newestHoldingQuote: FCurrentIntradaySnapshot? {
        let now = Date()
        return model.holdings.compactMap { model.marketDataByCode[$0.instrumentCode] }
            .filter {
                $0.latestPrice != nil && $0.quoteTimestamp <= now &&
                now.timeIntervalSince($0.quoteTimestamp) <= 120
            }
            .max { $0.quoteTimestamp < $1.quoteTimestamp }
    }

    var body: some View {
        if compact {
            VStack(spacing: 10) {
                signal(.marketObservation)
                signal(.crossMarketPulse)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("市场与研究脉搏").font(.subheadline.weight(.semibold))
                HStack(alignment: .top, spacing: 10) {
                    signal(.marketObservation)
                    signal(.crossMarketPulse)
                }
            }
        }
    }

    private func signal(_ role: FHomeCardRole) -> some View {
        let isMarket = role == .marketObservation
        let title = isMarket ? "今日市场观察" : "跨市场观察"
        let subtitle = isMarket
            ? model.marketCalendarStatusText
            : "实时跨市场行情尚未接入"
        let detail = isMarket
            ? (newestHoldingQuote.map { "持仓行情 · \($0.source) · \($0.quoteTimestamp.formatted(date: .omitted, time: .shortened))" }
               ?? "尚无可用的持仓实时行情")
            : "NAS历史研究为可选增强；不会阻断本机顾问"
        return NavigationLink(value: isMarket ? FHomeRoute.market : FHomeRoute.crossMarket) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: role.symbol).foregroundStyle(theme.accent)
                    Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                }
                Text(subtitle).font(.caption2.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(compact ? 2 : 1).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(compact ? 3 : 2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 108 : 92, alignment: .topLeading)
            .padding(12)
            .modifier(FThemeSurfaceModifier(theme: theme, radius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvisorComposer: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    let instrumentCode: String?
    @FocusState private var composerFocused: Bool

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
                .focused($composerFocused)
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
                Button {
                    composerFocused = false
                    model.askAdvisor(instrumentCode: instrumentCode)
                } label: {
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
        .modifier(FThemeSurfaceModifier(theme: theme, radius: 22))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { composerFocused = false }
            }
        }
    }
}

private struct PortfolioCard: View {
    @ObservedObject var model: FHomeModel
    var theme: FHomeTheme = .editorial
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("真实组合").font(.headline)
            LabeledContent("现金", value: model.cashText)
            LabeledContent("持仓", value: "\(model.holdings.count) 项")
            LabeledContent("今日证券盈亏", value: "不可用 · 缺可靠前收与日初持仓口径")
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
                                holdingMark(item)
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
        .modifier(FThemeSurfaceModifier(theme: theme, radius: 20))
    }

    @ViewBuilder
    private func holdingMark(_ holding: FHomeHolding) -> some View {
        let now = Date()
        if let snapshot = model.marketDataByCode[holding.instrumentCode],
           let price = snapshot.latestPrice,
           snapshot.quoteTimestamp <= now,
           now.timeIntervalSince(snapshot.quoteTimestamp) <= 120,
           let unrealized = try? FSecurityPnLCalculator.episodeUnrealizedPnL(
                units: holding.units, bookCost: holding.bookCost, currentPrice: price
           ) {
            Text("现价 ¥\(NSDecimalNumber(decimal: price).stringValue) · 本轮持仓浮盈亏 ¥\(NSDecimalNumber(decimal: unrealized).stringValue)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(unrealized >= 0 ? theme.manifest.tokens.positive : theme.manifest.tokens.negative)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else if model.marketDataByCode[holding.instrumentCode] != nil {
            Text("行情已过时或无有效价格 · 暂不计算持仓浮盈亏")
                .font(.caption2).foregroundStyle(theme.manifest.tokens.unavailable)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("等待真实行情 · 持仓浮盈亏暂不可用")
                .font(.caption2).foregroundStyle(theme.manifest.tokens.unavailable)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RouteCard: View {
    let route: FHomeRoute
    let title: String
    let detail: String
    let icon: String
    let theme: FHomeTheme
    private var accent: Color { theme.accent }
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
            .modifier(FThemeSurfaceModifier(theme: theme, radius: 18))
        }.buttonStyle(.plain)
    }
}

private struct FThemeSurfaceModifier: ViewModifier {
    let theme: FHomeTheme
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch theme.surfaceTreatment {
        case .terminal, .minimal:
            content.background(theme.manifest.tokens.surface.opacity(0.98))
                .overlay(alignment: .bottom) { Rectangle().fill(theme.accent.opacity(0.24)).frame(height: 0.5) }
        case .glass, .orbit:
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius + 8))
                .overlay(RoundedRectangle(cornerRadius: radius + 8).stroke(.white.opacity(0.28), lineWidth: 1))
                .shadow(color: theme.accent.opacity(0.12), radius: 16, y: 8)
        case .ink:
            content.background(theme.manifest.tokens.background.opacity(0.78))
                .overlay(alignment: .leading) { Rectangle().fill(theme.accent).frame(width: 2) }
        case .magazine:
            content.background(theme.manifest.tokens.background.opacity(0.9))
                .overlay(alignment: .top) { Rectangle().fill(theme.accent.opacity(0.7)).frame(height: 1) }
        case .bento, .adaptive:
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius + 4))
                .overlay(RoundedRectangle(cornerRadius: radius + 4).stroke(theme.accent.opacity(0.18), lineWidth: 1))
        case .editorial:
            content.background(theme.manifest.tokens.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(theme.ink.opacity(0.09), lineWidth: 0.8))
                .shadow(color: theme.ink.opacity(0.035), radius: 8, y: 3)
        case .card:
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

private struct FHomeRoleRenderer: View {
    let role: FHomeCardRole
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme

    var body: some View {
        Group {
            if role == .portfolio {
                PortfolioCard(model: model, theme: theme)
            } else if role == .advisorGuidance {
                VStack(spacing: 8) {
                    RouteCard(route: role.route, title: role.title, detail: role.detail,
                              icon: role.symbol, theme: theme)
                    AdvisorComposer(model: model, theme: theme)
                }
            } else {
                RouteCard(route: role.route, title: role.title, detail: role.detail,
                          icon: role.symbol, theme: theme)
            }
        }
        .accessibilityIdentifier("home.role.\(role.rawValue)")
    }
}

struct HomeDestination: View {
    let route: FHomeRoute
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
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
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 16))
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
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 16))
                } else {
                    Text("当前未持有；行情与证券级顾问仍可查看。真实持仓仅来自本机账本。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 9) {
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
                } label: {
                    HStack {
                        Text("盈亏口径").font(.headline)
                        Spacer()
                        Text("今日 · 本轮 · 累计 · 做T")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .modifier(FThemeSurfaceModifier(theme: theme, radius: 16))
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
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 16))
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
                        height: 510)
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
                                height: 500)
                        } else {
                            Text("尚无真实日 K 数据；请求失败时不会用分时点拼接。")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        Text(model.dailyKlineStateByCode[code] ?? "数据源：腾讯日 K · 未复权；等待请求")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    Text(model.marketRefreshStateByCode[code] ?? "尚未取得实时行情")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(snapshot.map { "\($0.source) · 行情时间 \($0.quoteTimestamp.formatted(date: .omitted, time: .standard)) · 获取于 \($0.fetchedAt.formatted(date: .omitted, time: .standard))" }
                         ?? "无数据时明确显示不可用，不使用占位或模拟价格。")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let snapshot {
                        Text(Self.quoteFreshnessText(snapshot, now: Date()))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
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
                                height: 510)
                            Text("真实归档数据 · \(archived.sourceSummary) · \(archived.coverageSummary)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                AdvisorComposer(model: model, theme: theme, instrumentCode: code)
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
            VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.standard) {
                Text("AI 私人投资顾问")
                    .font(.largeTitle.bold())
                Text("未指定持仓证券的提问按真实组合分析；明确指定证券代码或从证券详情进入时按证券级分析。")
                    .foregroundStyle(.secondary)
                Text("发送时读取本机只读账本快照和带来源/时点的行情；若配置且可用，会附带合格 NAS 研究。NAS 不可用不阻止基础顾问判断。")
                    .font(.footnote).foregroundStyle(.secondary)
                AdvisorComposer(model: model, theme: theme)
                VStack(alignment: .leading, spacing: 10) {
                    Text("本次可用上下文").font(.headline)
                    LabeledContent("真实账本", value: model.ledgerStatus)
                    LabeledContent("持仓行情", value: model.holdings.isEmpty ? "暂无证券行情请求" : "按持仓证券逐项获取")
                    LabeledContent("建议成绩单", value: model.candidateShadowJournalStatus)
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
                .modifier(FThemeSurfaceModifier(theme: theme, radius: 18))
                VStack(alignment: .leading, spacing: 10) {
                    Text("决策成绩单 · 最近30天").font(.headline)
                    if let summary = model.candidateShadowSummary {
                        LabeledContent("建议记录", value: "\(summary.candidateCount) 条 · WAIT \(summary.waitCount)")
                        LabeledContent("触发 / WAIT机会 / 未触发", value: "\(summary.triggeredCount) / \(summary.opportunityObservedCount) / \(summary.notTriggeredCount)")
                        LabeledContent("已过期 / 观察完成", value: "\(summary.expiredCount) / \(summary.observationWindowCompleteCount)")
                        LabeledContent("真实执行", value: "已关联 \(summary.executedCount) · 已复核未执行 \(summary.unexecutedCount) · 尚未核实 \(summary.executionUnknownCount)")
                        LabeledContent("Advisor原始方向可评价样本", value: "\(summary.evaluableDirectionalCount) · 正向 \(summary.favorableDirectionalCount)")
                        Text("当前仅评价DeepSeek原始建议的方向性市场结果，不是最终Guard建议胜率或账户收益；没有成交关联不代表确认未执行。")
                            .font(.caption).foregroundStyle(.secondary)
                        let perSecurity = summary.bySecurity.keys.sorted().map { code in
                            let value = summary.bySecurity[code]!
                            return "\(code) · \(value.candidateCount) 条 · 触发 \(value.triggeredCount) · WAIT机会 \(value.opportunityObservedCount) · 可评价 \(value.evaluableDirectionalCount)"
                        }.joined(separator: "\n")
                        if !perSecurity.isEmpty {
                            Text(perSecurity).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(model.candidateShadowJournalStatus).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("AI建议、市场走势和用户真实成交分别记录。影子成绩单只跟踪真实行情与成交编号，不生成模拟现金、持仓或收益，也不修改Ledger。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(16)
                .modifier(FThemeSurfaceModifier(theme: theme, radius: 18))
                Text("发送时重新读取本机真实账本和标的行情，再构建 DecisionContext 并运行 Risk Guard / AI Guard；NAS 研究仅在配置且可用时附加。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .navigationTitle("AI 私人投资顾问")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refreshCandidateShadowSummary() }
    }
}

private struct CrossMarketOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "globe.asia.australia")
                .font(.largeTitle).foregroundStyle(.secondary)
            Text("暂无合格跨市场证据").font(.title2.bold())
            Text("跨市场实时行情与研究尚未接入。NAS 可提供可选历史研究增强；样本、时区或数据质量未达到门槛时，不会把观察伪装成研究结论。NAS 不影响本机基础顾问功能。")
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
                        let isFeeAdjustment = entry.kind == .feeAdjustment
                        let displayedFee = isFeeAdjustment ? entry.fee : (entry.effectiveFee ?? entry.fee)
                        let feeLabel = isFeeAdjustment ? "手续费差额" :
                            (entry.effectiveFee != nil && entry.effectiveFee != entry.fee
                                ? "手续费（修正后）" : "手续费")
                        Text("\(isCashOnlyAdjustment ? "现金对账调整" : entry.kind.label)\(entry.instrumentName.map { " · \($0)" } ?? "")")
                        Text("\(entry.occurredAt.formatted(date: .numeric, time: .shortened)) · 变动 \(entry.cashDelta.description) · 余额 \(entry.resultingCashBalance.description) · \(feeLabel) \(displayedFee.description)")
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
    @State private var hasAutoCheckedNAS = false
    @FocusState private var settingsInputFocused: Bool
    private var theme: FHomeTheme { FHomeTheme(rawValue: themeRaw) ?? .editorial }

    var body: some View {
        Form {
            Section("在线 AI") {
                SecureField("DeepSeek API Key", text: $deepSeekKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($settingsInputFocused)
                    .accessibilityIdentifier("settings.ai.deepseekKey")
                Button("安全保存 DeepSeek Key") {
                    settingsInputFocused = false
                    model.saveDeepSeekKey(deepSeekKeyDraft)
                    deepSeekKeyDraft = ""
                }
                .accessibilityIdentifier("settings.ai.saveKey")
                LabeledContent("状态", value: model.aiKeyStatus)
            }
            Section("NAS 与数据服务（可选）") {
                TextField("NAS 地址，例如 http://192.168.1.20:8788", text: $nasBaseAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($settingsInputFocused)
                Button {
                    settingsInputFocused = false
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
                if nasBaseAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("尚未填写 NAS 地址，连接测试还没有开始。")
                        .font(.caption).foregroundStyle(theme.manifest.tokens.unavailable)
                } else {
                    Text(model.nasConnectionStatus)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("局域网请连接同一 Wi‑Fi 或 VPN；蜂窝网络请使用可达的 HTTPS 地址。")
                    .font(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("连接方式与安全说明") {
                Text("NAS用于可选的历史归档、备份与研究增强，不是观盘max正常使用的前置条件。连接测试只读取 /readyz，不发送持仓，也不要求单独令牌。NAS 的 8788 端口对可达网络开放，请限制网络入口。")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent("历史分钟查询", value: nasBaseAddress.isEmpty ? "需配置 NAS；覆盖待验证" : "查询接口已编码；真实覆盖待验证")
                LabeledContent("自动历史同步", value: "未接入")
                LabeledContent("新闻来源", value: "未接入真实来源")
                Text("实时分钟与日K使用腾讯公开行情接口。历史分钟通过可选 NAS 按日期查询；NAS Ready 只代表服务在线，不代表指定日期已有完整分钟归档。当前历史来源覆盖未通过实测，缺失日期不会补造。新闻目前没有接入供应商或真实新闻接口。")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("主题") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FHomeTheme.allCases) { item in
                            Button { themeRaw = item.rawValue } label: {
                                HStack(spacing: 5) {
                                    if theme == item {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text(item.manifest.name)
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme == item ? theme.accent : theme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(theme == item ? theme.accent.opacity(0.13) : theme.background.opacity(0.72),
                                            in: Capsule())
                                .overlay(Capsule().stroke(theme.accent.opacity(theme == item ? 0.55 : 0.16), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("theme.selector.\(item.rawValue)")
                        }
                    }
                }
                Text("当前：\(theme.manifest.name) · \(theme.manifest.layout.description)")
                    .font(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("查看全部主题预览") {
                    ForEach(FHomeTheme.allCases) { item in
                        Button { themeRaw = item.rawValue } label: {
                            FThemeGalleryRow(theme: item, selected: theme == item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("主题切换只改变信息编排与呈现。浅色基础token已接入；深色/护眼、动态字体和跨设备截图仍待Simulator验收。当前Tab与导航栈由各自的NavigationStack保留。")
                    .font(.footnote).foregroundStyle(.secondary)
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
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
        .listRowBackground(theme.manifest.tokens.surface)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { settingsInputFocused = false }
            }
        }
        .task {
            guard !hasAutoCheckedNAS else { return }
            hasAutoCheckedNAS = true
            guard !nasBaseAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            await model.configureAndTestNAS(baseAddress: nasBaseAddress)
        }
    }
}

private struct FThemeGalleryRow: View {
    let theme: FHomeTheme
    let selected: Bool
    private var manifest: FThemeManifest { theme.manifest }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(manifest.name).font(.headline)
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent) }
            }
            structuralPreview
            Text(manifest.layout.description).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("密度：\(manifest.layout.informationDensity)")
                Spacer()
                Text(manifest.useCase)
            }
            .font(.caption2).foregroundStyle(.secondary)
            Text(manifest.appearanceCompatibility)
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityIdentifier("theme.gallery.\(theme.rawValue)")
    }

    private var isTerminal: Bool { theme.surfaceTreatment == .terminal || theme.surfaceTreatment == .minimal }

    @ViewBuilder
    private var structuralPreview: some View {
        switch theme.layoutFamily {
        case .radialMap:
            GeometryReader { proxy in
                ZStack {
                    Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1)
                        .frame(width: 46, height: 46)
                        .position(x: proxy.size.width / 2, y: 25)
                    Circle().fill(theme.accent.opacity(0.55))
                        .frame(width: 14, height: 14)
                        .position(x: proxy.size.width / 2, y: 25)
                    ForEach(0..<4, id: \.self) { index in
                        Capsule().fill(theme.accent.opacity(0.35 + Double(index) * 0.12))
                            .frame(width: 26, height: 7)
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

private enum FMarketListScope: String, CaseIterable, Identifiable {
    case holdings, watchlist, combined
    var id: String { rawValue }
    var title: String {
        switch self {
        case .holdings: "持仓"
        case .watchlist: "自选"
        case .combined: "持仓 + 自选"
        }
    }
}

struct MarketOverview: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @State private var securityLookupCode = ""
    @State private var listScope: FMarketListScope = .combined
    @FocusState private var securityLookupFocused: Bool
    private var theme: FHomeTheme { FHomeTheme(rawValue: themeRaw) ?? .editorial }

    private var isValidSecurityCode: Bool {
        let bytes = securityLookupCode.utf8
        return bytes.count == 6 && bytes.allSatisfy { (48...57).contains($0) }
    }

    private var refreshableSecurityCodes: [String] {
        let heldCodes = model.holdings.map(\.instrumentCode)
        let lookupCodes = isValidSecurityCode ? [securityLookupCode] : []
        return Array(Set(heldCodes + model.watchlistCodes + lookupCodes)).sorted()
    }

    private var visibleSecurityCodes: [String] {
        switch listScope {
        case .holdings: model.holdings.map(\.instrumentCode)
        case .watchlist: model.watchlistCodes
        case .combined: Array(Set(model.holdings.map(\.instrumentCode) + model.watchlistCodes)).sorted()
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.standard) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("实时行情").font(.title3.weight(.semibold)).foregroundStyle(theme.ink)
                        Text("报价每 10 秒更新；曲线按上游分钟时间戳绘制。")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        Text(model.marketCalendarStatusText).font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    Spacer(minLength: 4)
                    Button {
                        Task { await model.refreshMarketData(for: refreshableSecurityCodes) }
                    } label: {
                        if model.refreshingMarketCodes.isEmpty {
                            Label("刷新", systemImage: "arrow.clockwise")
                        } else {
                            HStack(spacing: 5) { ProgressView().controlSize(.small); Text("更新中") }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.refreshingMarketCodes.isEmpty || refreshableSecurityCodes.isEmpty)
                    .accessibilityIdentifier("market.refresh.all")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("证券查询").font(.headline).foregroundStyle(theme.ink)
                    TextField("输入6位证券代码", text: $securityLookupCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .focused($securityLookupFocused)
                        .padding(.horizontal, 12).frame(height: 46)
                        .background(theme.manifest.tokens.surface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("market.security-code")
                        .onChange(of: securityLookupCode) { value in
                            let digits = String(value.unicodeScalars
                                .filter { (48...57).contains($0.value) }.prefix(6))
                            if digits != value { securityLookupCode = digits }
                        }
                    HStack(spacing: 12) {
                        NavigationLink(value: FHomeRoute.instrument(securityLookupCode)) {
                            Label("打开详情", systemImage: "arrow.up.forward")
                        }
                        .disabled(!isValidSecurityCode)
                        .accessibilityIdentifier("market.open-security")
                        Button { model.toggleWatchlist(securityLookupCode) } label: {
                            Label(model.isInWatchlist(securityLookupCode) ? "移出自选" : "加入自选",
                                  systemImage: model.isInWatchlist(securityLookupCode) ? "star.slash" : "star")
                        }
                        .disabled(!isValidSecurityCode)
                        .accessibilityIdentifier("market.watchlist.toggle")
                        if securityLookupFocused {
                            Button("收起键盘") { securityLookupFocused = false }
                                .accessibilityIdentifier("market.security-code.dismiss")
                        }
                    }
                    Text("自选只保存关注关系，不会创建真实持仓或改变账本。")
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }

                Picker("证券列表", selection: $listScope) {
                    ForEach(FMarketListScope.allCases) { scope in Text(scope.title).tag(scope) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("market.list.scope")

                if visibleSecurityCodes.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: listScope == .watchlist ? "star" : "chart.line.uptrend.xyaxis")
                            .font(.title2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        Text(listScope == .watchlist ? "自选列表为空" : "当前没有真实持仓")
                            .font(.headline).foregroundStyle(theme.ink)
                        Text(listScope == .watchlist
                             ? "在上方输入证券代码并加入自选。自选不会创建持仓。"
                             : "添加关注证券，或切换到“自选”查看未持仓标的的真实行情。")
                            .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                }

                ForEach(visibleSecurityCodes, id: \.self) { code in
                    let holding = model.holdings.first { $0.instrumentCode == code }
                    let snapshot = model.marketDataByCode[code]
                    VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.compact) {
                        HStack(spacing: 8) {
                            NavigationLink(value: FHomeRoute.instrument(code)) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(holding?.name ?? code).font(.headline).foregroundStyle(theme.ink)
                                        HStack(spacing: 6) {
                                            Text(code).font(.caption.monospaced())
                                            Text(holding == nil ? "自选关注" : "真实持仓")
                                        }
                                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                    }
                                    Spacer(minLength: 6)
                                    Text(snapshot?.latestPrice.map { "¥\($0.description)" } ?? "—")
                                        .font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(theme.ink)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("market.instrument.\(code)")
                            Button { model.toggleWatchlist(code) } label: {
                                Image(systemName: model.isInWatchlist(code) ? "star.fill" : "star")
                                    .foregroundStyle(model.isInWatchlist(code) ? theme.accent : theme.manifest.tokens.secondaryForeground)
                                    .frame(minWidth: 40, minHeight: 40).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(model.isInWatchlist(code) ? "移出自选" : "加入自选")
                            .accessibilityIdentifier("market.watchlist.\(code)")
                        }
                        if let snapshot {
                            FUnifiedSecurityChart(
                                model: FChartPresentationBuilder.live(
                                    snapshot, holding: holding,
                                    candidate: model.advisorResult?.candidate,
                                    ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt),
                                height: 360)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("暂无真实行情 · 点按刷新获取上游报价")
                                .font(.caption).foregroundStyle(theme.manifest.tokens.unavailable)
                                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        }
                        Text(snapshot.map {
                            "行情时间 \($0.quoteTimestamp.formatted(date: .omitted, time: .standard)) · 获取于 \($0.fetchedAt.formatted(date: .omitted, time: .standard)) · \($0.source)"
                        } ?? "行情时间/来源待获取")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
                        Text(model.marketRefreshStateByCode[code] ?? "等待首次请求")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
                    }
                    .padding(.bottom, theme.manifest.tokens.spacing.standard)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(theme.manifest.tokens.foreground.opacity(0.10)).frame(height: 0.7)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, theme.manifest.tokens.spacing.compact)
            .padding(.bottom, theme.manifest.tokens.spacing.spacious)
        }
        .navigationTitle("今日市场观察")
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
        .tint(theme.accent)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await model.refreshMarketData(for: refreshableSecurityCodes) }
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

