import SwiftUI
import FCore
import FAdvisor

extension FHomeTheme {
    var background: Color { manifest.tokens.background }
    var ink: Color { manifest.tokens.foreground }
    var accent: Color { manifest.tokens.accent }
}

private enum FThemePageRole {
    case security, advisor, market, crossMarket, assets, settings
}

private enum FThemeSurfaceRole {
    case portfolio, advisor, market, research, settings, neutral
}

/// Page headers share business facts but use role-specific composition. The
/// selected theme changes their type, surface and spacing through its manifest.
private struct FThemePageHeader: View {
    let theme: FHomeTheme
    let role: FThemePageRole
    let eyebrow: String
    let title: String
    let subtitle: String
    let symbol: String
    var value: String? = nil
    var valueLabel: String? = nil

    private var tokens: FThemeSemanticTokens { theme.manifest.tokens }

    var body: some View {
        Group {
            switch role {
            case .security: securityHeader
            case .advisor: advisorHeader
            case .market: marketHeader
            case .crossMarket: crossMarketHeader
            case .assets: assetsHeader
            case .settings: settingsHeader
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var editorialFamily: Bool {
        theme.layoutFamily == .editorial || theme.layoutFamily == .inkEditorial || theme.layoutFamily == .magazine
    }

    private var terminalFamily: Bool {
        theme.layoutFamily == .terminalDashboard || theme.layoutFamily == .minimalTerminal
    }

    private var cardRadius: CGFloat {
        switch theme.surfaceTreatment {
        case .terminal, .minimal: 8
        case .glass, .orbit: 28
        case .bento, .adaptive: 24
        default: 18
        }
    }

    private var headerFont: Font {
        if terminalFamily { return .system(size: 21, weight: .bold, design: .monospaced) }
        if editorialFamily { return .system(size: 29, weight: .bold, design: .serif) }
        return .system(size: 25, weight: .bold, design: .rounded)
    }

    private var securityHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(1.1)
                    .foregroundStyle(tokens.accent)
                Text(title).font(headerFont).foregroundStyle(tokens.foreground).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(tokens.secondaryForeground).lineLimit(2)
                if let valueLabel { Text(valueLabel.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(tokens.secondaryForeground) }
            }
            Spacer(minLength: 4)
            if let value {
                Text(value).font(.system(size: terminalFamily ? 20 : 27, weight: .bold,
                                         design: terminalFamily ? .monospaced : .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.68)
                    .foregroundStyle(tokens.foreground)
            } else {
                Image(systemName: symbol).font(.title2.weight(.semibold)).foregroundStyle(tokens.accent)
            }
        }
        .padding(theme.manifest.tokens.spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: cardRadius, role: .market))
    }

    private var advisorHeader: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tokens.accentForeground)
                .frame(width: 48, height: 48)
                .background(tokens.accent, in: RoundedRectangle(cornerRadius: theme.surfaceTreatment == .terminal ? 8 : 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(1)
                    .foregroundStyle(tokens.secondaryForeground)
                Text(title).font(headerFont).foregroundStyle(tokens.foreground)
                Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(tokens.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let value {
                Text(value).font(.caption.weight(.bold)).lineLimit(2).multilineTextAlignment(.trailing)
                    .foregroundStyle(tokens.accentForeground)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(tokens.accent, in: Capsule())
            }
        }
        .padding(theme.manifest.tokens.spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: cardRadius, role: .advisor))
        .overlay(alignment: .leading) {
            if editorialFamily { Rectangle().fill(tokens.accent).frame(width: 3).padding(.vertical, 12) }
        }
    }

    private var marketHeader: some View {
        VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.compact) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(1)
                        .foregroundStyle(tokens.accent)
                    Text(title).font(headerFont).foregroundStyle(tokens.foreground)
                }
                Spacer(minLength: 4)
                Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(tokens.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let value { Text(value).font(.system(size: 18, weight: .bold, design: terminalFamily ? .monospaced : .rounded)).foregroundStyle(tokens.foreground) }
                if let valueLabel { Text(valueLabel).font(.caption.weight(.semibold)).foregroundStyle(tokens.secondaryForeground) }
                Spacer(minLength: 0)
            }
            Text(subtitle).font(.caption).foregroundStyle(tokens.secondaryForeground).fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.manifest.tokens.spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: cardRadius, role: .market))
    }

    private var crossMarketHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().stroke(tokens.accent.opacity(0.25), lineWidth: 1).frame(width: 54, height: 54)
                Circle().fill(tokens.highlightSurface).frame(width: 42, height: 42)
                Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(tokens.accent)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(0.9).foregroundStyle(tokens.accent)
                Text(title).font(headerFont).foregroundStyle(tokens.foreground)
                Text(subtitle).font(.caption).foregroundStyle(tokens.secondaryForeground).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let value {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value).font(.system(size: 19, weight: .bold, design: terminalFamily ? .monospaced : .rounded))
                        .monospacedDigit().foregroundStyle(tokens.foreground)
                    Text(valueLabel ?? "指数").font(.caption2).foregroundStyle(tokens.secondaryForeground)
                }
            }
        }
        .padding(theme.manifest.tokens.spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: cardRadius, role: .research))
    }

    private var assetsHeader: some View {
        VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.compact) {
            HStack {
                Label(eyebrow, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(tokens.accent)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(tokens.secondaryForeground)
            }
            Text(title).font(headerFont).foregroundStyle(tokens.foreground)
            if let value {
                Text(value).font(.system(size: terminalFamily ? 24 : 32, weight: .bold,
                                         design: terminalFamily ? .monospaced : .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(tokens.foreground)
            }
            if let valueLabel { Text(valueLabel).font(.caption.weight(.medium)).foregroundStyle(tokens.secondaryForeground) }
            Text(subtitle).font(.caption).foregroundStyle(tokens.secondaryForeground).fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.manifest.tokens.spacing.spacious)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: cardRadius, role: .portfolio))
    }

    private var settingsHeader: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(tokens.accent)
                Text(title).font(headerFont).foregroundStyle(tokens.foreground)
                Text(subtitle).font(.caption).foregroundStyle(tokens.secondaryForeground).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(tokens.accentForeground)
                if let value { Text(value).font(.caption2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(tokens.accentForeground) }
            }
            .padding(10)
            .background(tokens.accent, in: RoundedRectangle(cornerRadius: theme.surfaceTreatment == .terminal ? 4 : 14, style: .continuous))
        }
        .padding(theme.manifest.tokens.spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: cardRadius, role: .settings))
    }

}

struct HomeLayout: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    var body: some View {
        ScrollView {
            Group {
                switch theme.layoutFamily {
                case .editorial, .cardGrid, .terminalDashboard, .staticBento, .minimalTerminal, .adaptiveBento:
                    FDesignedThemeHome(model: model, theme: theme)
                case .magazine: magazine
                case .inkEditorial: inkEditorial
                case .spatialGlass: fluidGlass
                case .radialMap: dataStarMap
                }
            }
            .padding(theme.manifest.tokens.spacing.standard)
        }
        .accessibilityIdentifier("home.scroll")
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
    }

    private var editorial: some View {
        FSignatureHome(model: model, theme: theme)
    }

    private var modern: some View {
        VStack(spacing: 14) {
            role(.portfolio)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 12)],
                      spacing: 12) {
                role(.marketObservation)
                role(.crossMarketPulse)
            }
            role(.advisorGuidance)
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeMasthead(model: model, theme: theme, eyebrow: "观盘max / LIVE PORTFOLIO")
                .padding(.bottom, 14)
            HomePortfolioLead(model: model, theme: theme, treatment: .terminal)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.portfolio")
                .padding(.bottom, 12)
            Divider().overlay(theme.accent.opacity(0.5))
            role(.marketObservation).padding(.vertical, 12)
            Divider().overlay(theme.accent.opacity(0.5))
            role(.crossMarketPulse).padding(.vertical, 12)
            Divider().overlay(theme.accent.opacity(0.5))
            HomeAdvisorLead(model: model, theme: theme, treatment: .terminal)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
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
                .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            role(.portfolio)
            role(.marketObservation)
            role(.crossMarketPulse)
            role(.advisorGuidance)
        }
    }

    private var bento: some View {
        VStack(spacing: 12) {
            role(.portfolio).frame(minHeight: 210)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 12)],
                      spacing: 12) {
                role(.marketObservation).frame(minHeight: 210)
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
            role(.portfolio)
            role(.marketObservation)
            role(.crossMarketPulse)
            HomeAdvisorLead(model: model, theme: theme, treatment: .editorial)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
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
            role(.portfolio).padding(.vertical, 8)
            Divider()
            role(.marketObservation).padding(.vertical, 8)
            Divider()
            role(.crossMarketPulse).padding(.vertical, 8)
            Divider()
            Text("ADVISOR STREAM").font(.caption.monospaced().weight(.semibold)).padding(.top, 12)
            role(.advisorGuidance).padding(.vertical, 8)
        }
    }

    private var fluidGlass: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeMasthead(model: model, theme: theme, eyebrow: "你的投资空间")
            HomePortfolioLead(model: model, theme: theme, treatment: .glass)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.portfolio")
            role(.marketObservation)
            role(.crossMarketPulse)
            HomeAdvisorLead(model: model, theme: theme, treatment: .glass)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
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
                        for point in [CGPoint(x: width * 0.27, y: height * 0.19),
                                      CGPoint(x: width * 0.73, y: height * 0.19),
                                      CGPoint(x: width * 0.85, y: height * 0.81),
                                      CGPoint(x: width * 0.15, y: height * 0.81)] {
                            path.move(to: center); path.addLine(to: point)
                        }
                    }.stroke(theme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    centralStarSummary.frame(width: min(width * 0.52, 210), height: 150)
                        .position(x: width / 2, y: height / 2)
                    orbitNode(.portfolio, shortTitle: "持仓", x: width * 0.27, y: height * 0.19)
                    orbitNode(.marketObservation, shortTitle: "市场", x: width * 0.73, y: height * 0.19)
                    orbitNode(.crossMarketPulse, shortTitle: "跨市场", x: width * 0.85, y: height * 0.81)
                    orbitNode(.advisorGuidance, shortTitle: "AI 决策", x: width * 0.15, y: height * 0.81)
                }
            }
            .frame(height: 430)
            Text("外围节点进入各自独立页面；证券详情与图表保持专业操作方式。")
                .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.star-map.center")
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
        .accessibilityIdentifier("home.role.\(role.rawValue)")
    }

    private var adaptiveBento: some View {
        let attention = model.ledgerState != .available ||
            (model.advisorResult.map { !$0.assessment.isEligibleForUserReview } ?? false)
        return VStack(spacing: 12) {
            role(.portfolio).frame(minHeight: attention ? 180 : 220)
            role(.marketObservation).frame(minHeight: 130)
            role(.crossMarketPulse).frame(minHeight: 100)
            role(.advisorGuidance).frame(minHeight: attention ? 250 : 180)
        }
        .animation(.easeInOut(duration: 0.18), value: attention)
    }

    @ViewBuilder
    private func role(_ role: FHomeCardRole) -> some View {
        FHomeRoleRenderer(role: role, model: model, theme: theme)
    }

}

/// Six complete homepage compositions based on the two approved concept boards.
/// Every number and status comes from FHomeModel; the artwork is decorative only.
private struct FDesignedThemeHome: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    private var tokens: FThemeSemanticTokens { theme.manifest.tokens }
    private var focusedCodes: [String] {
        Array(Set(model.holdings.map(\.instrumentCode) + model.watchlistCodes)).sorted().prefix(4).map { $0 }
    }

    var body: some View {
        Group {
            switch theme {
            case .editorial: mountainCover
            case .dashboard: deepSpaceTerminal
            case .bento: coralCollage
            case .modern: bluePortfolio
            case .minimalTerminal: nightFlight
            case .adaptiveBento: auroraPanorama
            default: mountainCover
            }
        }
        .padding(.horizontal, theme == .dashboard || theme == .minimalTerminal ? 12 : 16)
        .padding(.top, 10)
        .padding(.bottom, 30)
        .frame(maxWidth: 760, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(tokens.background.ignoresSafeArea())
        .refreshable {
            await model.autoRefreshMarketData()
            await model.refreshMarketIndices()
        }
    }

    private var mountainCover: some View {
        VStack(alignment: .leading, spacing: 18) {
            masthead(eyebrow: "看清市场 · 做对决策", dark: false)
            portfolioPanel(art: true, compact: false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.portfolio")
            advisorPanel(dark: false, compact: false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
            marketSection(dark: false, columns: 3)
            watchlist(dark: false, table: true)
            crossMarketLine
        }
    }

    private var deepSpaceTerminal: some View {
        VStack(alignment: .leading, spacing: 12) {
            masthead(eyebrow: "专业视角 · 实时决策", dark: true)
            portfolioPanel(art: false, compact: true)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.portfolio")
            advisorPanel(dark: true, compact: true)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
            marketSection(dark: true, columns: 3)
            intradayTape(dark: true)
            watchlist(dark: true, table: false)
            crossMarketLine
        }
    }

    private var coralCollage: some View {
        VStack(alignment: .leading, spacing: 12) {
            masthead(eyebrow: "让投资更从容", dark: false)
            advisorPanel(dark: false, compact: false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
            HStack(alignment: .top, spacing: 10) {
                portfolioPanel(art: false, compact: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.role.portfolio")
                NavigationLink(value: FHomeRoute.portfolio) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "chart.bar.xaxis").font(.title2)
                        Text("资产分析").font(.headline)
                        Text(model.ledgerState == .available ? "\(model.holdings.count) 项真实持仓" : model.ledgerStatus)
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right.circle.fill").font(.title2)
                    }
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(14).frame(width: 112, alignment: .leading)
                    .background(tokens.highlightSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 10) {
                marketSection(dark: false, columns: 2)
                    .frame(maxWidth: .infinity)
                quantTile
                    .frame(width: 112)
            }
            watchlist(dark: false, table: false)
            crossMarketLine
        }
    }

    private var bluePortfolio: some View {
        VStack(alignment: .leading, spacing: 14) {
            masthead(eyebrow: "观盘max · 今日组合", dark: false)
            portfolioPanel(art: false, compact: false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.portfolio")
            advisorPanel(dark: false, compact: false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
            marketSection(dark: false, columns: 3)
            watchlist(dark: false, table: false)
            crossMarketLine
        }
    }

    private var nightFlight: some View {
        VStack(alignment: .leading, spacing: 11) {
            masthead(eyebrow: "LOCAL QUANT · LIVE", dark: true)
            portfolioPanel(art: false, compact: true)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.portfolio")
            intradayTape(dark: true)
            advisorPanel(dark: true, compact: true)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
            quantSummary
            marketSection(dark: true, columns: 4)
            watchlist(dark: true, table: false)
            crossMarketLine
        }
    }

    private var auroraPanorama: some View {
        VStack(alignment: .leading, spacing: 13) {
            masthead(eyebrow: "观盘max · 从容看盘", dark: true)
            ZStack(alignment: .topTrailing) {
                portfolioPanel(art: true, compact: false)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.role.portfolio")
                NavigationLink(value: FHomeRoute.portfolio) {
                    VStack(alignment: .leading, spacing: 7) {
                        Image(systemName: "banknote.fill").foregroundStyle(tokens.accent)
                        Text("可用现金").font(.caption)
                        Text(model.cashText).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .foregroundStyle(.black).padding(12).frame(width: 118, alignment: .leading)
                    .background(tokens.highlightSurface, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                }
                .buttonStyle(.plain).padding(8)
            }
            advisorPanel(dark: false, compact: false)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.role.advisorGuidance")
            marketSection(dark: false, columns: 3)
            HStack(alignment: .top, spacing: 10) {
                watchlist(dark: false, table: false)
                quantTile.frame(width: 122)
            }
            crossMarketLine
        }
        .padding(7)
        .background(LinearGradient(colors: tokens.surfaceGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func masthead(eyebrow: String, dark: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("观盘max").font(.system(size: 22, weight: .heavy, design: .rounded))
                Text(eyebrow).font(.caption).foregroundStyle(dark ? .white.opacity(0.72) : tokens.secondaryForeground)
            }
            Spacer()
            Text(Date.now.formatted(.dateTime.month(.abbreviated).day().weekday(.wide)))
                .font(.caption.monospacedDigit()).foregroundStyle(dark ? .white.opacity(0.72) : tokens.secondaryForeground)
        }
        .foregroundStyle(dark ? .white : tokens.foreground)
    }

    private func portfolioPanel(art: Bool, compact: Bool) -> some View {
        let panel = tokens.portfolioSurface
        return VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack {
                Text("真实资产").font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.ledgerState == .available ? "本机账本" : model.ledgerStatus)
                    .font(.caption2).lineLimit(1)
                NavigationLink(value: FHomeRoute.portfolio) {
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                }.buttonStyle(.plain)
            }
            Text(model.portfolioMarketValuation(at: Date()).displayLabel)
                .font(.system(size: compact ? 29 : 35, weight: .bold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.68)
                .accessibilityIdentifier("home.signature.portfolio-value")
            let daily = model.portfolioSecurityDailyPnL(at: Date())
            HStack(spacing: 8) {
                Text("今日").font(.caption)
                Text(daily.map { "\($0 >= 0 ? "+" : "−")¥\(NSDecimalNumber(decimal: abs($0)).stringValue)" }
                     ?? "不可用 · 日初口径/行情未齐")
                    .font(.caption.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.72)
            }
            HStack(spacing: 0) {
                metric("持仓市值", value: holdingsMarketValueText, compact: compact)
                metric("可用现金", value: model.cashText, compact: compact)
                metric("持仓", value: "\(model.holdings.count) 项", compact: compact)
            }
            if art {
                FHomeMountainArtwork().frame(height: 58).opacity(0.62).accessibilityHidden(true)
            } else if !compact {
                FHomePortfolioSparkline(model: model, color: .white.opacity(0.9)).frame(height: 28)
            }
        }
        .foregroundStyle(.white)
        .padding(compact ? 13 : 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: art && theme == .editorial ? [tokens.portfolioSurface, Color(red: 0.11, green: 0.35, blue: 0.72)] : [panel, tokens.surfaceGradient.last ?? panel],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: art ? 25 : 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: art ? 25 : 21).stroke(.white.opacity(0.18), lineWidth: 0.8))
    }

    private var holdingsMarketValueText: String {
        let now = Date()
        var total = Decimal.zero
        for holding in model.holdings {
            guard let quote = model.marketDataByCode[holding.instrumentCode],
                  quote.freshness(at: now) == .fresh, let price = quote.latestPrice else { return "行情不齐" }
            total += price * Decimal(holding.units)
        }
        return "¥\(NSDecimalNumber(decimal: total).stringValue)"
    }

    private func advisorPanel(dark: Bool, compact: Bool) -> some View {
        let result = model.advisorResult.flatMap { $0.scope == .portfolio ? $0 : nil }
        return VStack(alignment: .leading, spacing: compact ? 8 : 11) {
            HStack {
                Label("今日判断", systemImage: "sparkles").font(.headline)
                Spacer()
                Text(result?.candidate.action.displayName ?? "组合级").font(.caption.weight(.semibold))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            Text(result?.narrative.conclusion ?? "先看清真实组合，再决定今天是否操作。")
                .font(.system(size: compact ? 18 : 21, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true).lineLimit(compact ? 3 : 4)
            Text(result?.narrative.basis ?? model.advisorStatus)
                .font(.caption).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                .opacity(0.86)
            if let risk = result?.narrative.risks.first {
                Label(risk, systemImage: "exclamationmark.shield.fill")
                    .font(.caption2.weight(.medium)).lineLimit(2)
            }
            HStack {
                Button {
                    model.question = "今天我的持仓需要操作吗？"
                    model.askAdvisor()
                } label: {
                    Text(model.isAskingAdvisor ? "正在分析" : (result == nil ? "生成今日判断" : "更新今日判断"))
                        .font(.caption.weight(.bold)).padding(.horizontal, 13).padding(.vertical, 9)
                        .foregroundStyle(tokens.accentForeground)
                        .background(tokens.accent, in: Capsule())
                }
                .disabled(model.isAskingAdvisor || model.ledgerState != .available)
                .accessibilityIdentifier("home.advisor.analyze-portfolio")
                NavigationLink(value: FHomeRoute.advisor) {
                    Text("完整依据 →").font(.caption.weight(.semibold))
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                if let result { Text(result.generatedAt.formatted(date: .omitted, time: .shortened)).font(.caption2) }
            }
        }
        .foregroundStyle(.white)
        .padding(compact ? 13 : 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [tokens.advisorSurface, theme == .dashboard || theme == .minimalTerminal ? Color(red: 0.02, green: 0.19, blue: 0.30) : Color(red: 0.98, green: 0.42, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 32, weight: .black)).foregroundStyle(.white.opacity(0.10))
                .padding(20).accessibilityHidden(true)
        }
    }

    private func metric(_ title: String, value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).opacity(0.75)
            Text(value).font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func marketSection(dark: Bool, columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("市场脉搏").font(.headline)
                Spacer()
                NavigationLink(value: FHomeRoute.crossMarket) { Text("查看全部 →").font(.caption) }
                    .buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: columns), spacing: 7) {
                ForEach(Array(model.marketIndexQuotes.prefix(columns == 4 ? 4 : 3))) { quote in
                    NavigationLink(value: FHomeRoute.marketIndex(quote.code)) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(quote.name).font(.caption2.weight(.semibold)).lineLimit(1)
                            Text(quote.latestPrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? "—")
                                .font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.65)
                            Text(quote.changePercent.map { "\($0 >= 0 ? "+" : "")\(NSDecimalNumber(decimal: $0).stringValue)%" } ?? (quote.marketStatus ?? "等待行情"))
                                .font(.caption2.weight(.semibold)).lineLimit(1)
                                .foregroundStyle(quote.changePercent.map { $0 >= 0 ? tokens.positive : tokens.negative } ?? (dark ? .white.opacity(0.7) : tokens.unavailable))
                            Text(quote.observedAt?.formatted(date: .omitted, time: .shortened) ?? "无时间戳")
                                .font(.system(size: 9)).opacity(0.65).lineLimit(1)
                        }
                        .foregroundStyle(dark ? .white : tokens.foreground)
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading).padding(9)
                        .background(dark ? tokens.marketSurface : (theme == .bento ? tokens.marketSurface : tokens.surface),
                                    in: RoundedRectangle(cornerRadius: theme == .dashboard || theme == .minimalTerminal ? 8 : 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.market-index.\(quote.code)")
                }
            }
            NavigationLink(value: FHomeRoute.market) {
                Text(model.marketCalendarStatusText).font(.caption2).foregroundStyle(dark ? .white.opacity(0.7) : tokens.secondaryForeground)
            }.buttonStyle(.plain).accessibilityIdentifier("home.role.marketObservation")
        }
        .foregroundStyle(dark ? .white : tokens.foreground)
        .padding(theme == .dashboard || theme == .minimalTerminal ? 10 : 12)
        .background(dark ? Color.clear : (theme == .bento ? Color.clear : tokens.surface.opacity(0.58)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func watchlist(dark: Bool, table: Bool) -> some View {
        let codes = focusedCodes
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(table ? "自选观察" : "自选").font(.headline)
                Spacer()
                NavigationLink(value: FHomeRoute.market) { Text("查看全部 →").font(.caption) }
                    .buttonStyle(.plain)
            }
            if codes.isEmpty {
                NavigationLink(value: FHomeRoute.market) {
                    Text("添加自选后，在这里查看实时行情和本地量化方向观察。")
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14)
                }.buttonStyle(.plain)
            } else {
                ForEach(codes, id: \.self) { code in
                    let quote = model.marketDataByCode[code]
                    let price = quote?.latestPrice
                    let isFresh = quote.map { $0.freshness(at: Date()) == .fresh } ?? false
                    let score = model.watchlistQuantAssessment(for: code)?.watchlistDirectionalScore
                    NavigationLink(value: FHomeRoute.instrument(code)) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.holdings.first(where: { $0.instrumentCode == code })?.name ?? code)
                                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text("\(code) · \(model.holdings.contains(where: { $0.instrumentCode == code }) ? "持仓" : "自选")")
                                    .font(.caption2.monospaced()).opacity(0.68)
                            }
                            Spacer(minLength: 4)
                            FWatchlistSparkline(samples: quote?.samples ?? [], positiveColor: tokens.positive, negativeColor: tokens.negative)
                                .frame(width: table ? 56 : 38, height: 22).accessibilityHidden(true)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(price.map { "¥\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "—")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                Text(isFresh ? (score.map { "方向观察 \($0 > 0 ? "+" : "")\($0)" } ?? "Quant 样本不足") : "行情待更新")
                                    .font(.system(size: 9)).opacity(0.7).lineLimit(1)
                            }
                        }
                        .foregroundStyle(dark ? .white : tokens.foreground)
                        .padding(.vertical, table ? 8 : 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if code != codes.last { Rectangle().fill(dark ? .white.opacity(0.1) : tokens.foreground.opacity(0.08)).frame(height: 0.5) }
                }
            }
        }
        .foregroundStyle(dark ? .white : tokens.foreground)
        .padding(table ? 12 : 10)
        .background(dark ? Color.black.opacity(0.16) : tokens.surface.opacity(0.82),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quantTile: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "waveform.path.ecg").font(.title3)
            Text("本地量化").font(.caption.weight(.semibold))
            Text(quantScoreText).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
            Text("方向观察\n非买入结论").font(.caption2)
            Spacer(minLength: 0)
            NavigationLink(value: FHomeRoute.market) { Image(systemName: "arrow.right.circle.fill").font(.title2) }
                .buttonStyle(.plain)
        }
        .foregroundStyle(tokens.foreground)
        .padding(12).frame(minHeight: 115, alignment: .topLeading)
        .background(tokens.highlightSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("home.quant.score")
    }

    private var quantScoreText: String {
        guard let code = focusedCodes.first,
              let score = model.watchlistQuantAssessment(for: code)?.watchlistDirectionalScore else { return "—" }
        return "\(score > 0 ? "+" : "")\(score)"
    }

    private var quantSummary: some View {
        HStack(spacing: 7) {
            quantMini("市场", model.marketCalendarStatusText, color: tokens.advisorSurface)
            quantMini("观察", quantScoreText, color: tokens.highlightSurface)
            quantMini("风险", model.holdings.isEmpty ? "无持仓" : "按行情计算", color: tokens.marketSurface)
        }
    }

    private func quantMini(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).opacity(0.72)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
        }
        .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(9)
        .background(color, in: RoundedRectangle(cornerRadius: 9))
    }

    private var intradayCode: String? { focusedCodes.first }

    private func intradayTape(dark: Bool) -> some View {
        let quote = intradayCode.flatMap { model.marketDataByCode[$0] }
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("实时走势").font(.caption.weight(.semibold))
                Spacer()
                Text(intradayCode ?? "暂无自选").font(.caption2.monospaced())
                Text(quote?.quoteTimestamp.formatted(date: .omitted, time: .shortened) ?? "等待行情")
                    .font(.caption2.monospacedDigit()).opacity(0.65)
            }
            FWatchlistSparkline(samples: quote?.samples ?? [], positiveColor: Color(red: 0.12, green: 0.89, blue: 0.75), negativeColor: Color(red: 1, green: 0.37, blue: 0.46))
                .frame(height: theme == .minimalTerminal ? 96 : 70)
            HStack {
                Text("09:30")
                Spacer()
                Text("11:30 → 13:00")
                Spacer()
                Text("15:00")
            }.font(.system(size: 9, design: .monospaced)).opacity(0.62)
        }
        .foregroundStyle(dark ? .white : tokens.foreground)
        .padding(11)
        .background(dark ? tokens.marketSurface : tokens.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var crossMarketLine: some View {
        NavigationLink(value: FHomeRoute.crossMarket) {
            HStack(spacing: 8) {
                Image(systemName: "globe.asia.australia").foregroundStyle(theme.accent)
                Text("跨市场脉搏").font(.caption.weight(.semibold))
                Text("指数 · 数据时点 · 状态").font(.caption2).foregroundStyle(tokens.secondaryForeground)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(tokens.foreground).padding(.vertical, 8)
        }
        .buttonStyle(.plain).accessibilityIdentifier("home.role.crossMarketPulse")
    }
}

private struct FHomeMountainArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.8))
                    path.addCurve(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.42),
                                  control1: CGPoint(x: proxy.size.width * 0.28, y: proxy.size.height * 0.1),
                                  control2: CGPoint(x: proxy.size.width * 0.6, y: proxy.size.height * 0.95))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height)); path.closeSubpath()
                }.fill(Color(red: 0.84, green: 0.72, blue: 0.51).opacity(0.72))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.92))
                    path.addCurve(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.68),
                                  control1: CGPoint(x: proxy.size.width * 0.32, y: proxy.size.height * 0.28),
                                  control2: CGPoint(x: proxy.size.width * 0.7, y: proxy.size.height * 1.12))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height)); path.closeSubpath()
                }.fill(Color(red: 0.18, green: 0.32, blue: 0.44).opacity(0.9))
                Image(systemName: "figure.hiking").font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9)).offset(x: proxy.size.width * 0.34, y: -5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct FHomePortfolioSparkline: View {
    @ObservedObject var model: FHomeModel
    let color: Color
    var body: some View {
        GeometryReader { proxy in
            let snapshots = model.holdings.compactMap { model.marketDataByCode[$0.instrumentCode] }
            let values = snapshots.compactMap { $0.latestPrice }.map { CGFloat(NSDecimalNumber(decimal: $0).doubleValue) }
            if values.count >= 2 {
                Path { path in
                    for index in values.indices {
                        let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * proxy.size.width
                        let minValue = values.min() ?? 0
                        let span = max((values.max() ?? 1) - minValue, 0.000001)
                        let y = proxy.size.height - ((values[index] - minValue) / span * (proxy.size.height - 4)) - 2
                        if index == values.startIndex { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }.stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            } else {
                Rectangle().fill(color.opacity(0.45)).frame(height: 1).offset(y: proxy.size.height / 2)
            }
        }
    }
}

/// A single finished editorial home built from the live F model. The hierarchy is
/// intentionally composed as one briefing surface, a market tape, and plain
/// position rows instead of repeating the same card shell for every role.
private struct FSignatureHome: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme

    private var focusCodes: [String] {
        Array(Set(model.holdings.map(\.instrumentCode) + model.watchlistCodes)).sorted().prefix(4).map { $0 }
    }

    private var portfolioResult: FAdvisorVerticalSliceResult? {
        guard let result = model.advisorResult, result.scope == .portfolio else { return nil }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            masthead
            briefingSurface
            marketTape
            positionList
            researchFooter
            advisorBriefing
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .top)
        .refreshable {
            await model.autoRefreshMarketData()
            await model.refreshMarketIndices()
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(theme.accent).frame(width: 4, height: 17)
                    Text("观盘 MAX").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.1)
                }
                .foregroundStyle(theme.accent)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(model.ledgerState == .available
                                  ? theme.manifest.tokens.positive : theme.manifest.tokens.warning)
                        .frame(width: 6, height: 6)
                    Text(model.ledgerState == .available ? "真实账本" : model.ledgerStatus)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
            HStack(alignment: .lastTextBaseline) {
                Text("今天的组合")
                    .font(.system(size: 31, weight: .semibold, design: .serif))
                    .tracking(-0.6)
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day().weekday(.wide)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
            Text(model.marketCalendarStatusText)
                .font(.caption)
                .foregroundStyle(theme.manifest.tokens.secondaryForeground)
        }
        .accessibilityElement(children: .contain)
    }

    private var briefingSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("账户总览").font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink)
                Spacer()
                NavigationLink(value: FHomeRoute.portfolio) {
                    Label("资产明细", systemImage: "arrow.up.right")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.bottom, 10)

            Text("账本内资产估值")
                .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text(model.portfolioMarketValuation(at: context.date).displayLabel)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-1.1)
                    .lineLimit(1).minimumScaleFactor(0.72)
                    .foregroundStyle(theme.ink)
                    .accessibilityIdentifier("home.signature.portfolio-value")
            }
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                summaryMetric("可用现金", model.cashText)
                metricDivider
                summaryMetric("真实持仓", model.ledgerState == .available ? "\(model.holdings.count) 只" : "待确认")
                metricDivider
                summaryMetric("今日盈亏", "暂不可用")
            }
            .padding(.vertical, 11)
            .overlay(alignment: .top) { hairline }
            .overlay(alignment: .bottom) { hairline }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.role.portfolio")

        }
        .padding(19)
        .background(theme.manifest.tokens.surface, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(theme.accent).frame(width: 3).padding(.vertical, 22)
        }
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous)
            .stroke(theme.ink.opacity(0.075), lineWidth: 0.7))
        .shadow(color: theme.ink.opacity(0.045), radius: 18, x: 0, y: 7)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.briefing-surface")
    }

    private var advisorBriefing: some View {
        HStack(alignment: .top, spacing: 11) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 25, alignment: .leading)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("AI 今日判断").font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink)
                        Spacer()
                        Text(portfolioResult.map { $0.candidate.action.displayName } ?? "组合级")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .lineLimit(1)
                    }
                    Text(portfolioResult?.narrative.conclusion ??
                         (model.advisorResult == nil ? "先看清持仓，再决定今天是否操作。" : "最近一次是单只证券分析，组合判断尚未生成。"))
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(theme.ink)
                        .accessibilityIdentifier("home.advisor.portfolio-conclusion")
                    if let result = portfolioResult {
                        Text(result.narrative.basis)
                            .font(.subheadline)
                            .lineSpacing(2)
                            .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        if let risk = result.narrative.risks.first {
                            Label(risk, systemImage: "exclamationmark.shield")
                                .font(.caption)
                                .foregroundStyle(theme.manifest.tokens.warning)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let invalidation = result.narrative.invalidationConditions.first {
                            Text("失效条件 · \(invalidation)")
                                .font(.caption2)
                                .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                .lineLimit(2)
                        }
                        if let code = result.candidate.instrumentCode,
                           let price = result.candidate.limitPrice,
                           result.isReviewable {
                            Text("候选计划 · \(code) · 参考价 ¥\(NSDecimalNumber(decimal: price).stringValue)\(result.candidate.units.map { " · \($0) 份" } ?? "") · 需你确认真实成交")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(model.advisorStatus)
                            .font(.caption)
                            .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            .lineLimit(2)
                    }
                    HStack(spacing: 12) {
                        Button {
                            model.question = "今天我的持仓需要操作吗？"
                            model.askAdvisor()
                        } label: {
                            HStack(spacing: 7) {
                                if model.isAskingAdvisor { ProgressView().controlSize(.small) }
                                Text(model.isAskingAdvisor ? "正在分析组合" : (portfolioResult == nil ? "生成今日判断" : "更新今日判断"))
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                        .disabled(model.isAskingAdvisor || model.ledgerState != .available)
                        .accessibilityIdentifier("home.advisor.analyze-portfolio")
                        NavigationLink(value: FHomeRoute.advisor) {
                            Text("查看依据").font(.subheadline.weight(.medium)).frame(minHeight: 42)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.top, 15)
            .padding(19)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.manifest.tokens.surface, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(theme.accent).frame(width: 3).padding(.vertical, 22)
            }
            .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(theme.ink.opacity(0.075), lineWidth: 0.7))
            .shadow(color: theme.ink.opacity(0.045), radius: 18, x: 0, y: 7)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.role.advisorGuidance")
    }

    private var marketTape: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("市场在看什么")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Spacer()
                NavigationLink(value: FHomeRoute.market) {
                    Label("全部行情", systemImage: "arrow.up.right").font(.caption.weight(.medium))
                }
                .buttonStyle(.plain).foregroundStyle(theme.accent)
                .accessibilityIdentifier("home.role.marketObservation")
            }
            if focusCodes.isEmpty {
                Text("添加自选后，真实行情与本地观察分会出现在这里。")
                    .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(focusCodes, id: \.self) { code in
                        marketRow(code)
                        if code != focusCodes.last { hairline }
                    }
                }
            }
        }
    }

    private func marketRow(_ code: String) -> some View {
        let quote = model.marketDataByCode[code]
        let fresh = quote.map { $0.freshness(at: Date()) == .fresh && $0.latestPrice != nil } ?? false
        let name = model.holdings.first(where: { $0.instrumentCode == code })?.name ?? code
        let assessment = model.watchlistQuantAssessment(for: code)
        return NavigationLink(value: FHomeRoute.instrument(code)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink).lineLimit(1)
                    Text("\(code) · \(model.holdings.contains(where: { $0.instrumentCode == code }) ? "真实持仓" : "自选")")
                        .font(.caption2.monospaced()).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                Spacer(minLength: 4)
                FWatchlistSparkline(samples: quote?.samples ?? [],
                    positiveColor: theme.manifest.tokens.positive,
                    negativeColor: theme.manifest.tokens.negative)
                    .frame(width: 70, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(quote?.latestPrice.map { "¥\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "—")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(fresh ? theme.ink : theme.manifest.tokens.unavailable)
                    Text(assessment?.watchlistDirectionalScore.map { "观察分 \($0 > 0 ? "+" : "")\($0)" } ?? (fresh ? "样本不足" : "行情待更新"))
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var positionList: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .lastTextBaseline) {
                Text("持仓焦点").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(theme.ink)
                Spacer()
                NavigationLink(value: FHomeRoute.portfolio) {
                    Text("全部持仓").font(.caption.weight(.medium))
                }
                .buttonStyle(.plain).foregroundStyle(theme.accent)
            }
            if model.holdings.isEmpty {
                HStack {
                    Text(model.ledgerState == .available ? "当前空仓 · 历史成交仍保留在账本" : model.ledgerStatus)
                        .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    Spacer()
                    NavigationLink(value: FHomeRoute.portfolio) {
                        Label("录入持仓", systemImage: "plus").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(theme.accent)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.holdings.prefix(4))) { holding in
                        holdingRow(holding)
                        if holding.id != model.holdings.prefix(4).last?.id { hairline }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.portfolio.positions")
    }

    private func holdingRow(_ holding: FHomeHolding) -> some View {
        let quote = model.marketDataByCode[holding.instrumentCode]
        let price = quote.flatMap { $0.freshness(at: Date()) == .fresh ? $0.latestPrice : nil }
        let unrealized = price.flatMap {
            try? FSecurityPnLCalculator.episodeUnrealizedPnL(units: holding.units,
                                                              bookCost: holding.bookCost,
                                                              currentPrice: $0)
        }
        return NavigationLink(value: FHomeRoute.instrument(holding.instrumentCode)) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.name).font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink).lineLimit(1)
                    Text("\(holding.instrumentCode) · \(holding.units) 份")
                        .font(.caption.monospacedDigit()).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(price.map { "¥\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "行情待更新")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(theme.ink)
                    Text(unrealized.map { "本轮 \($0 >= 0 ? "+" : "")¥\(NSDecimalNumber(decimal: $0).stringValue)" }
                         ?? "本轮盈亏暂不可用")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(unrealized.map { $0 >= 0 ? theme.manifest.tokens.positive : theme.manifest.tokens.negative }
                                         ?? theme.manifest.tokens.unavailable)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var researchFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: FHomeRoute.crossMarket) {
                HStack(spacing: 10) {
                    Image(systemName: "globe.asia.australia").foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("跨市场与研究").font(.subheadline.weight(.semibold)).foregroundStyle(theme.ink)
                        Text("市场指数直连 · NAS 可选归档与增强 · \(model.nasConnectionStatus)")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.role.crossMarketPulse")
            hairline
            HStack(spacing: 7) {
                Image(systemName: "clock").font(.caption2)
                Text("行情与本地观察分只采用已验证的真实时间戳；观察分不是胜率或收益预测。")
                    .font(.caption2).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(theme.manifest.tokens.secondaryForeground)
            .padding(.top, 12)
        }
    }

    private func summaryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(title == "今日盈亏" ? theme.manifest.tokens.unavailable : theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Rectangle().fill(theme.ink.opacity(0.10)).frame(width: 0.7, height: 30).padding(.horizontal, 9)
    }

    private var hairline: some View {
        Rectangle().fill(theme.ink.opacity(0.10)).frame(height: 0.7)
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
                        .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
                Spacer()
                Text(portfolioCountText)
                    .font(.caption.monospacedDigit()).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
            }
            if codes.isEmpty {
                NavigationLink(value: FHomeRoute.market) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line").foregroundStyle(theme.accent)
                        Text("添加自选证券后，在这里查看真实行情")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
            $0.latestPrice != nil && $0.freshness(at: now) == .fresh
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
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
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
                    Text("指数行情由手机直连 · NAS为可选归档与研究增强（\(model.nasConnectionStatus)）")
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 7) {
                Circle().fill(model.ledgerState == .available ? theme.manifest.tokens.positive : theme.manifest.tokens.warning)
                    .frame(width: 7, height: 7)
                Text(model.ledgerState == .available ? "本机真实账本" : model.ledgerStatus)
                    .font(.caption2.weight(.medium)).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
                Spacer()
                Text("只读快照")
                    .font(.caption2.weight(.medium)).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.caption2.weight(.medium)).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                        Text(firstRisk).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let invalidation = result.narrative.invalidationConditions.first {
                    Text("失效条件 · \(invalidation)")
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            } else if let result = model.advisorResult {
                Text("最近分析针对 \(result.securityCode)，不是组合判断。")
                    .font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Text("首页不会把单只证券结论当成全组合建议。")
                    .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            } else {
                Text("先读完整持仓，再给今天的判断。")
                    .font(.system(size: 23, weight: .semibold, design: treatment == .terminal ? .monospaced : .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.advisorStatus == "尚未开始分析"
                     ? "组合判断尚未生成。生成前不会用单只证券替代整个组合。"
                     : model.advisorStatus)
                    .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    model.question = "今天我的持仓需要操作吗？"
                    model.askAdvisor()
                } label: {
                    HStack(spacing: 7) {
                        if model.isAskingAdvisor { ProgressView().tint(theme.manifest.tokens.accentForeground) }
                        Text(model.isAskingAdvisor ? "正在分析真实组合" : (portfolioResult == nil ? "生成组合判断" : "更新组合判断"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .foregroundStyle(theme.manifest.tokens.accentForeground)
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
            return quote.latestPrice != nil && quote.freshness(at: now) == .fresh
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的真实资产").font(.headline)
                    Text(model.ledgerState == .available ? "来自本机 Ledger" : model.ledgerStatus)
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
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

            HomePortfolioValuationRow(model: model)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(theme.accent).frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日盈亏")
                        .font(.subheadline.weight(.medium))
                    Text("暂不可用 · 缺少可靠的日初持仓与前收口径")
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                                        .font(.caption.monospacedDigit()).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Circle().fill(freshQuoteCount == model.holdings.count && !model.holdings.isEmpty
                              ? theme.manifest.tokens.positive : theme.manifest.tokens.unavailable)
                    .frame(width: 6, height: 6)
                Text("持仓行情 \(freshQuoteCount)/\(model.holdings.count) 条新鲜")
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                Spacer(minLength: 4)
                Text("Episode成本为主 · 券商成本辅助")
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
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
            Text(label).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
           quote.freshness(at: now) == .fresh,
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
                $0.latestPrice != nil && $0.freshness(at: now) == .fresh
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
            : "上证、纳指、日经、KOSPI、恒生等指数"
        let detail = isMarket
            ? (newestHoldingQuote.map { "持仓行情 · \($0.source) · \($0.quoteTimestamp.formatted(date: .omitted, time: .shortened))" }
               ?? "尚无可用的持仓实时行情")
            : "指数逐项显示行情来源和时点；NAS只提供可选历史归档与研究增强，不阻塞本机Quant或Advisor"
        return NavigationLink(value: isMarket ? FHomeRoute.market : FHomeRoute.crossMarket) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: role.symbol).foregroundStyle(theme.accent)
                    Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                }
                Text(subtitle).font(.caption2.weight(.medium)).foregroundStyle(theme.manifest.tokens.foreground)
                    .lineLimit(compact ? 2 : 1).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
            }
            TextField(instrumentCode.map { "例如：\($0) 现在需要操作吗？" } ??
                      "例如：今天我的持仓需要操作吗？", text: $model.question, axis: .vertical)
                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                .focused($composerFocused)
                .accessibilityIdentifier("advisor.composer.question")
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
            .accessibilityIdentifier("advisor.composer.prompts")
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
            .accessibilityIdentifier("advisor.composer.actions")
            Text(model.advisorStatus).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                .accessibilityIdentifier("advisor.composer.status")
            Text("组合问题会纳入全部真实持仓；证券详情入口只分析目标证券。账本、行情和合格 NAS 证据只读传入，Candidate Plan 不会改写资产。")
                .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            if let result = model.advisorResult {
                FAdvisorResultCard(result: result, theme: theme, accent: theme.accent, risk: theme.manifest.tokens.risk) {
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
            HomePortfolioValuationRow(model: model)
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let valuation = model.portfolioMarketValuation(at: context.date)
                Text("现金 + 全部真实持仓市值 · 持仓行情必须可信且在120秒内")
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                if case .success(let value) = valuation, let quotesAsOf = value.quotesAsOf {
                    Text("估值所用报价截至 \(quotesAsOf.formatted(date: .omitted, time: .standard))")
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
            LabeledContent("持仓", value: "\(model.holdings.count) 项")
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let dailyPnL = model.portfolioSecurityDailyPnL(at: context.date)
                LabeledContent("今日证券盈亏", value: dailyPnL?.description ??
                    (model.holdings.isEmpty ? "无持仓/今日成交" : "不可用 · 需要同日新鲜行情与可信前收"))
            }
            if model.ledgerState == .available && model.holdings.isEmpty {
                Text("账本已读取，当前没有真实持仓").font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                Button { model.prepareManualLedgerFill() } label: {
                    Label("登记已成交买入，开始建仓", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered).tint(theme.accent)
                .accessibilityIdentifier("ledger.manual-fill.emptyPortfolio")
            } else if model.ledgerState == .notEstablished {
                Text("还没有本机账本；可按券商当前余额和持仓建立起点。")
                    .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                Button {
                    model.clearLedgerWriteStatus()
                    model.showingInitialLedgerSetup = true
                } label: {
                    Label("录入现有持仓", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered).tint(theme.accent)
                .accessibilityIdentifier("ledger.opening.home")
            } else if model.ledgerState != .available {
                Text("持仓状态未确认 · \(model.ledgerStatus)")
                    .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            } else {
                ForEach(model.holdings) { item in
                    NavigationLink(value: FHomeRoute.instrument(item.instrumentCode)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).font(.subheadline.weight(.medium))
                                Text(item.instrumentCode).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
           snapshot.freshness(at: now) == .fresh,
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

private struct HomePortfolioValuationRow: View {
    @ObservedObject var model: FHomeModel
    @State private var evaluationDate = Date()

    var body: some View {
        HStack(spacing: 8) {
            Text("账本内资产估值")
            Spacer(minLength: 8)
            Text(model.portfolioMarketValuation(at: evaluationDate).displayLabel)
                .monospacedDigit().multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("portfolio.valuation.total")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { return }
                evaluationDate = Date()
            }
        }
    }
}

private extension Result where Success == FPortfolioMarketValuation,
                               Failure == FPortfolioMarketValuationUnavailableReason {
    var displayLabel: String {
        switch self {
        case .success(let valuation):
            return "¥\(NSDecimalNumber(decimal: valuation.totalAssets).stringValue)"
        case .failure(.ledgerUnavailable):
            return "不可用 · 账本未就绪"
        case .failure(.invalidSnapshotTime):
            return "不可用 · 账本时点无效"
        case .failure(.unsupportedCurrency(let currency)):
            return "不可用 · 暂不支持 \(currency) 估值"
        case .failure(.invalidCashBalance):
            return "不可用 · 现金值无效"
        case .failure(.invalidPosition(let code)):
            return "不可用 · 持仓记录无效（\(code)）"
        case .failure(.missingOrStaleQuotes(let codes)):
            return "不可用 · 行情未齐/已过期（\(codes.joined(separator: "、"))）"
        case .failure(.unrepresentableValue):
            return "不可用 · 总值超出可计算范围"
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
                    Text(detail).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
    let role: FThemeSurfaceRole

    init(theme: FHomeTheme, radius: CGFloat, role: FThemeSurfaceRole = .neutral) {
        self.theme = theme
        self.radius = radius
        self.role = role
    }

    private var tokens: FThemeSemanticTokens { theme.manifest.tokens }

    private var roleTint: Color {
        switch role {
        case .portfolio: tokens.portfolioSurface
        case .advisor: tokens.advisorSurface
        case .market: tokens.marketSurface
        case .research: tokens.highlightSurface
        case .settings, .neutral: tokens.accent
        }
    }

    private var cornerStyle: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var coloredSurface: LinearGradient {
        LinearGradient(colors: [tokens.surface, roleTint.opacity(theme.surfaceTreatment == .bento ? 0.34 : 0.20)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch theme.surfaceTreatment {
        case .terminal, .minimal:
            content.background(theme.manifest.tokens.surface.opacity(0.98))
                .overlay(alignment: .leading) { Rectangle().fill(roleTint).frame(width: 2) }
                .overlay(alignment: .bottom) { Rectangle().fill(roleTint.opacity(0.45)).frame(height: 0.7) }
        case .glass, .orbit:
            content.background {
                RoundedRectangle(cornerRadius: radius + 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: radius + 8, style: .continuous)
                        .fill(roleTint.opacity(0.12)))
            }
                .overlay(RoundedRectangle(cornerRadius: radius + 8).stroke(roleTint.opacity(0.36), lineWidth: 1))
                .shadow(color: roleTint.opacity(0.18), radius: 16, y: 8)
        case .ink:
            content.background {
                cornerStyle.fill(tokens.background)
                    .overlay(cornerStyle.fill(roleTint.opacity(0.095)))
            }
                .overlay(alignment: .leading) { Rectangle().fill(roleTint).frame(width: 3) }
        case .magazine:
            content.background {
                cornerStyle.fill(tokens.background)
                    .overlay(cornerStyle.fill(roleTint.opacity(0.12)))
            }
                .overlay(alignment: .top) { Rectangle().fill(roleTint).frame(height: 2) }
        case .bento:
            content.background(coloredSurface, in: RoundedRectangle(cornerRadius: radius + 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius + 4, style: .continuous)
                    .stroke(roleTint.opacity(0.54), lineWidth: 1.2))
                .shadow(color: roleTint.opacity(0.15), radius: 9, y: 4)
        case .adaptive:
            content.background(coloredSurface, in: RoundedRectangle(cornerRadius: radius + 4, style: .continuous))
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(roleTint).frame(width: 4).padding(.vertical, 12) }
                .overlay(RoundedRectangle(cornerRadius: radius + 4, style: .continuous)
                    .stroke(roleTint.opacity(0.40), lineWidth: 1))
        case .editorial:
            content.background(coloredSurface, in: cornerStyle)
                .overlay(cornerStyle.stroke(roleTint.opacity(0.20), lineWidth: 0.8))
                .shadow(color: theme.ink.opacity(0.035), radius: 8, y: 3)
        case .card:
            content.background(coloredSurface, in: cornerStyle)
                .overlay(cornerStyle.stroke(roleTint.opacity(0.24), lineWidth: 0.9))
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
        .accessibilityElement(children: .contain)
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
                CrossMarketOverview(model: model, theme: theme)
            case let .marketIndex(code):
                MarketIndexDetailOverview(model: model, theme: theme, code: code)
            case .advisor:
                AdvisorOverview(model: model)
            case .portfolio:
                RealAssetsOverview(model: model)
            case let .instrument(code):
                instrumentDestination(code)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
        .tint(theme.accent)
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
                            .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
            Text(description).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
            guard let quoteSnapshot, quoteSnapshot.freshness(at: quoteNow) == .fresh else { return nil }
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
                FThemePageHeader(theme: theme, role: .security,
                               eyebrow: holding == nil ? "自选观察 · 证券详情" : "真实持仓 · 证券详情",
                               title: instrumentName,
                               subtitle: "\(code) · \(quoteSnapshot.map { Self.quoteFreshnessText($0, now: quoteNow) } ?? "等待可靠行情")",
                               symbol: holding == nil ? "chart.xyaxis.line" : "chart.line.uptrend.xyaxis",
                               value: freshPrice.map { "¥\(NSDecimalNumber(decimal: $0).stringValue)" } ?? "行情不可用",
                               valueLabel: "最新价")
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
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 16, role: .portfolio))
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
                                .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        }
                    }
                    .padding(14)
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 16, role: .portfolio))
                } else {
                    Text("当前未持有；行情与证券级顾问仍可查看。真实持仓仅来自本机账本。")
                        .font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 9) {
                    TimelineView(.periodic(from: .now, by: 15)) { context in
                        let dailyPnL = model.securityDailyPnL(for: code, at: context.date)
                        LabeledContent("今日证券总盈亏", value: dailyPnL?.description ??
                            "不可用 · 需要同日行情、可信前收与可核对的日初份额")
                    }
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
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                } label: {
                    HStack {
                        Text("盈亏口径").font(.headline)
                        Spacer()
                        Text("今日 · 本轮 · 累计 · 做T")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                }
                .padding(14)
                .modifier(FThemeSurfaceModifier(theme: theme, radius: 16, role: .portfolio))
                if let history {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("持仓周期历史").font(.headline)
                        ForEach(history.episodes) { episode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("第\(episode.episodeNumber)轮 · 建仓 \(episode.openedAt.formatted(date: .numeric, time: .omitted))")
                                    .font(.subheadline.weight(.medium))
                                Text(episode.closedAt.map { "清仓 \($0.formatted(date: .numeric, time: .omitted))" } ?? "当前持仓周期")
                                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                Text("本轮已实现盈亏 \(episode.netRealizedProfit.description)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                        }
                    }
                    .padding(14)
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 16, role: .research))
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
                                                              ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt,
                                                              reference: model.marketReferenceByCode[code]),
                        height: 420)
                    .padding(.horizontal, -8)
                    .accessibilityIdentifier("market.security-chart.live")
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
                                height: 420)
                            .padding(.horizontal, -8)
                            .accessibilityIdentifier("market.security-chart.daily")
                        } else {
                            Text("尚无真实日 K 数据；请求失败时不会用分时点拼接。")
                                .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .accessibilityIdentifier("market.security-chart.daily.unavailable")
                        }
                        Text(model.securityRegimeStatusByCode[code] ?? "证券自身状态：等待真实日K；市场广度等缺失因子不会估算")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        Text(model.dailyKlineStateByCode[code] ?? "数据源：Tencent Finance daily K-line · iPhone直连 · 未复权；等待请求")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    .padding(.vertical, 8)
                    Text(model.marketRefreshStateByCode[code] ?? "尚未取得实时行情")
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    Text(snapshot.map { "\($0.source) · 行情时间 \($0.quoteTimestamp.formatted(date: .omitted, time: .standard)) · 获取于 \($0.fetchedAt.formatted(date: .omitted, time: .standard))" }
                         ?? "无数据时明确显示不可用，不使用占位或模拟价格。")
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    if let reference = model.marketReferenceByCode[code],
                       reference.hasTrustedTimestamp(at: Date()) {
                        let now = Date()
                        let iopv = reference.iopv.map { value in
                            reference.hasFreshIOPV(at: now)
                                ? " · IOPV参考 ¥\(NSDecimalNumber(decimal: value).stringValue)"
                                : " · IOPV过期/不可用"
                        } ?? " · IOPV过期/不可用"
                        let premium = reference.hasFreshReference(at: now)
                            ? reference.premiumPercent.map { " · 腾讯溢折价 \($0)%" } ?? " · 溢折价不可用"
                            : " · 腾讯溢折价过期/不可用"
                        Text("前收 ¥\(NSDecimalNumber(decimal: reference.previousClose).stringValue)" +
                             iopv +
                             premium + " · \(reference.source) · \(reference.observedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    } else if let reference = model.marketReferenceByCode[code] {
                        Text("参考行情时点不可信或来自未来 · \(reference.source)")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.unavailable)
                    } else if let referenceState = model.marketReferenceStateByCode[code] {
                        Text("前收 / IOPV / 溢折价不可用 · \(referenceState)")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    }
                    if let snapshot {
                        Text(Self.quoteFreshnessText(snapshot, now: Date()))
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        if let archived = model.archivedIntradayByCode[code], !archived.samples.isEmpty {
                            FUnifiedSecurityChart(
                                model: FChartPresentationBuilder.historical(archived, holding: holding,
                                                                             ledgerCapturedAt: model.latestLedgerSnapshot?.capturedAt,
                                                                             daily: model.dailyKlineByCode[code]),
                                height: 420)
                            .padding(.horizontal, -8)
                            .accessibilityIdentifier("market.security-chart.history")
                            Text("真实归档数据 · \(archived.sourceSummary) · \(archived.coverageSummary)")
                                .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        }
                    }
                    .padding(.vertical, 8)
                AdvisorComposer(model: model, theme: theme, instrumentCode: code)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .scrollDismissesKeyboard(.interactively)
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
        let session = FMainlandTradingCalendar.status(at: now)
        let metadata = snapshot.temporalMetadata(marketSessionStatus: session)
        let freshness = metadata.freshness(at: now)
        let age = now.timeIntervalSince(snapshot.quoteTimestamp)
        guard freshness != .unverified else {
            return "行情时间未验证或来自未来"
        }
        switch session {
        case .continuous:
            switch freshness {
            case .fresh: return "行情新鲜 · \(Int(age)) 秒前"
            case .stale: return "行情已滞后 · \(Int(age / 60)) 分钟前"
            case .unverified: return "行情时间未验证或来自未来"
            }
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
    private var theme: FHomeTheme { FHomeTheme.selected(themeRaw) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.standard) {
                let portfolioResult = model.advisorResult.flatMap { $0.scope == .portfolio ? $0 : nil }
                FThemePageHeader(theme: theme, role: .advisor, eyebrow: "观盘max · 决策中枢", title: "今日投资判断",
                               subtitle: portfolioResult?.narrative.conclusion ?? "结合真实持仓、可靠行情与风险状态，再决定操作或等待。",
                               symbol: "sparkles",
                               value: portfolioResult?.candidate.action.displayName ?? model.aiKeyStatus,
                               valueLabel: portfolioResult == nil ? "顾问状态" : "当前结论")
                Text("未指定持仓证券的提问按真实组合分析；明确指定证券代码或从证券详情进入时按证券级分析。")
                    .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                Text("分析读取本机只读账本和带来源、时间戳的行情；NAS仅作为可选增强。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                AdvisorComposer(model: model, theme: theme)
                VStack(alignment: .leading, spacing: 10) {
                    Text("本次可用上下文").font(.headline)
                    LabeledContent("真实账本", value: model.ledgerStatus)
                        .accessibilityIdentifier("advisor.context.ledger")
                    LabeledContent("持仓行情", value: model.holdings.isEmpty ? "暂无证券行情请求" : "按持仓证券逐项获取")
                        .accessibilityIdentifier("advisor.context.quotes")
                    LabeledContent("建议成绩单", value: model.candidateShadowJournalStatus)
                        .accessibilityIdentifier("advisor.context.scorecard")
                    LabeledContent("NAS 历史研究", value: model.nasResearchStatus)
                        .accessibilityIdentifier("advisor.context.nas-research")
                    LabeledContent("新闻", value: model.newsStatus)
                        .accessibilityIdentifier("advisor.context.news")
                    HStack {
                        Text("在线 AI")
                        Spacer()
                        Text(model.aiKeyStatus).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("advisor.ai-key-status")
                }
                .font(.subheadline)
                .padding(16)
                .modifier(FThemeSurfaceModifier(theme: theme, radius: 18, role: .advisor))
                VStack(alignment: .leading, spacing: 10) {
                    Text("决策成绩单 · 最近30天").font(.headline)
                    if let summary = model.candidateShadowSummary {
                        LabeledContent("建议记录", value: "\(summary.candidateCount) 条 · WAIT \(summary.waitCount)")
                        LabeledContent("触发 / WAIT机会 / 未触发", value: "\(summary.triggeredCount) / \(summary.opportunityObservedCount) / \(summary.notTriggeredCount)")
                        LabeledContent("已过期 / 观察完成", value: "\(summary.expiredCount) / \(summary.observationWindowCompleteCount)")
                        LabeledContent("真实执行", value: "已关联 \(summary.executedCount) · 已复核未执行 \(summary.unexecutedCount) · 尚未核实 \(summary.executionUnknownCount)")
                        LabeledContent("Advisor原始方向可评价样本", value: "\(summary.evaluableDirectionalCount) · 正向 \(summary.favorableDirectionalCount)")
                        Text("当前仅评价DeepSeek原始建议的方向性市场结果，不是最终Guard建议胜率或账户收益；没有成交关联不代表确认未执行。")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        let perSecurity = summary.bySecurity.keys.sorted().map { code in
                            let value = summary.bySecurity[code]!
                            return "\(code) · \(value.candidateCount) 条 · 触发 \(value.triggeredCount) · WAIT机会 \(value.opportunityObservedCount) · 可评价 \(value.evaluableDirectionalCount)"
                        }.joined(separator: "\n")
                        if !perSecurity.isEmpty {
                            Text(perSecurity).font(.caption.monospacedDigit()).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        }
                    } else {
                        Text(model.candidateShadowJournalStatus).font(.subheadline).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    Text("AI建议、市场走势和用户真实成交分别记录。影子成绩单只跟踪真实行情与成交编号，不生成模拟现金、持仓或收益，也不修改Ledger。")
                        .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                .padding(16)
                .modifier(FThemeSurfaceModifier(theme: theme, radius: 18, role: .research))
                Text("发送时重新读取本机真实账本和标的行情，再构建 DecisionContext 并运行 Risk Guard / AI Guard；NAS 研究仅在配置且可用时附加。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("AI 私人投资顾问")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refreshCandidateShadowSummary() }
    }
}

private struct MarketIndexDetailOverview: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme
    let code: String

    private var quote: FMarketIndexQuote? { model.marketIndexQuotes.first { $0.code == code } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.manifest.tokens.spacing.standard) {
                FThemePageHeader(theme: theme, role: .crossMarket, eyebrow: "跨市场 · 指数详情",
                    title: quote?.name ?? code,
                    subtitle: "\(quote?.market ?? "市场状态待更新") · 独立指数行情，不映射为ETF持仓",
                    symbol: "chart.xyaxis.line",
                    value: quote?.latestPrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? "不可用",
                    valueLabel: "指数点位")
                if let quote {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("指数代码", value: quote.code)
                        LabeledContent("市场", value: quote.market)
                        LabeledContent("涨跌幅", value: quote.changePercent.map { String(format: "%+.2f%%", NSDecimalNumber(decimal: $0).doubleValue) } ?? "不可用")
                        LabeledContent("行情时间", value: quote.observedAt?.formatted(date: .numeric, time: .standard) ?? "未验证")
                        LabeledContent("数据来源", value: quote.source ?? "待获取")
                        LabeledContent("交易时段", value: quote.marketStatus ?? "未验证")
                        if let reason = quote.unavailableReason {
                            Text(reason).font(.caption).foregroundStyle(theme.manifest.tokens.unavailable)
                        }
                    }
                    .padding(16)
                    .modifier(FThemeSurfaceModifier(theme: theme, radius: 18, role: .market))
                    LabeledContent("历史状态", value: model.marketIndexRegimeStatusByCode[code] ?? "历史状态尚未读取")
                        .font(.subheadline)
                        .padding(14)
                        .modifier(FThemeSurfaceModifier(theme: theme, radius: 14, role: .research))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(theme.manifest.tokens.unavailable)
                        Text("指数行情暂不可用").font(.headline)
                        Text("刷新后查看真实行情，不使用模拟点位。")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                }
                Button {
                    Task {
                        await model.refreshMarketIndices()
                        await model.refreshHistoricalIndexRegimes()
                    }
                } label: {
                    Label("刷新指数数据", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("crossmarket.index.refresh.\(code)")
            }
            .padding(16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(quote?.name ?? code)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if quote == nil { await model.refreshMarketIndices() }
        }
    }
}
private struct CrossMarketOverview: View {
    @ObservedObject var model: FHomeModel
    let theme: FHomeTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FThemePageHeader(theme: theme, role: .crossMarket, eyebrow: "全球市场 · 指数观察", title: "跨市场脉搏",
                               subtitle: "实时指数由手机读取；历史数据与研究服务为可选增强。",
                               symbol: "globe.asia.australia",
                               value: "\(model.marketIndexQuotes.filter { $0.latestPrice != nil }.count) / \(model.marketIndexQuotes.count)",
                               valueLabel: "指数已更新")
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button {
                        Task { await model.refreshMarketIndices() }
                    } label: {
                        if model.refreshingMarketIndices {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.refreshingMarketIndices)
                    .accessibilityIdentifier("crossmarket.refresh")
                    Button {
                        Task { await model.refreshHistoricalIndexRegimes() }
                    } label: {
                        if model.refreshingMarketIndexRegimes {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("更新历史状态", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.refreshingMarketIndexRegimes)
                    .accessibilityIdentifier("crossmarket.history-refresh")
                }

                if let error = model.marketIndicesError {
                    Text(error).font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        .accessibilityIdentifier("crossmarket.partial-status")
                }

                indexCollection


                Text("已支持的指数日K会单独计算指数级 Regime；数据不足或历史源未验证时显示不可用。仅159352→中证A500、159941→纳指100有发行方确认的基准映射，可用于顾问背景和Local Quant策略准备；不代表策略资格或交易信号。其他ETF不自动套用指数状态。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                if let updatedAt = model.marketIndicesUpdatedAt {
                    Text("本机读取于 \(updatedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
            .padding(16)
        }
        .background(theme.background.ignoresSafeArea())
        .accessibilityIdentifier("crossmarket.list")
        .navigationTitle("跨市场脉搏")
        .task {
            let shouldRefreshLiveQuotes = model.marketIndicesUpdatedAt == nil
            async let liveQuotes: Void = {
                if shouldRefreshLiveQuotes { await model.refreshMarketIndices() }
            }()
            async let historicalRegimes: Void = model.refreshHistoricalIndexRegimes()
            _ = await (liveQuotes, historicalRegimes)
        }
    }

    @ViewBuilder
    private var indexCollection: some View {
        switch theme.layoutFamily {
        case .cardGrid, .staticBento, .adaptiveBento:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 10)], spacing: 10) {
                ForEach(model.marketIndexQuotes) { quote in indexCard(quote) }
            }
        case .terminalDashboard, .minimalTerminal:
            VStack(spacing: 0) {
                ForEach(model.marketIndexQuotes) { quote in
                    indexCard(quote)
                    if quote.id != model.marketIndexQuotes.last?.id {
                        Rectangle().fill(theme.manifest.tokens.foreground.opacity(0.12)).frame(height: 1)
                    }
                }
            }
        default:
            LazyVStack(spacing: 13) {
                ForEach(model.marketIndexQuotes) { quote in indexCard(quote) }
            }
        }
    }
    @ViewBuilder
    private func indexCard(_ quote: FMarketIndexQuote) -> some View {
        NavigationLink(value: FHomeRoute.marketIndex(quote.code)) {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(quote.name).font(.headline)
                    Text("\(quote.market) · \(quote.code)").font(.caption2)
                        .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                Spacer()
                if quote.hasNumericQuote, let price = quote.latestPrice, let change = quote.changePercent {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(NSDecimalNumber(decimal: price).stringValue)
                            .font(.title3.monospacedDigit().weight(.semibold))
                        Text(percentText(change))
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(change >= 0
                                ? theme.manifest.tokens.positive
                                : theme.manifest.tokens.negative)
                    }
                } else {
                    Text("不可用").font(.subheadline.weight(.medium)).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text(quoteTimeText(quote, now: context.date))
                    .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
            Text(model.marketIndexRegimeStatusByCode[quote.code] ?? "历史 Regime 尚未读取")
                .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                .accessibilityIdentifier("crossmarket.regime.\(quote.code)")
            if !quote.isAvailable, let reason = quote.unavailableReason {
                Text(reason).font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
        }
        .padding(theme.layoutFamily == .terminalDashboard || theme.layoutFamily == .minimalTerminal ? 9 : 14)
        .frame(maxWidth: .infinity, minHeight: theme.layoutFamily == .staticBento ? 132 : nil, alignment: .leading)
        .modifier(FThemeSurfaceModifier(theme: theme, radius: theme.layoutFamily == .terminalDashboard || theme.layoutFamily == .minimalTerminal ? 5 : 16, role: .market))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("crossmarket.index.\(quote.code)")
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开指数详情")
    }

    private func percentText(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "%+.2f%%", number)
    }

    private func quoteTimeText(_ quote: FMarketIndexQuote, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: quote.timeZoneIdentifier) ?? .current
        formatter.dateFormat = "M月d日 HH:mm:ss"
        let session = marketSessionLabel(quote.marketStatus)
        if let observedAt = quote.observedAt {
            let time = formatter.string(from: observedAt)
            let source = quote.source ?? "来源未知"
            let freshness = quote.freshness(at: now)
            guard freshness != .unverified else {
                return "行情时点未验证 · \(time) · \(source) · \(session)"
            }
            switch quote.marketStatus?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
            case "OPEN":
                switch freshness {
                case .fresh: return "行情新鲜 · \(time) · \(source) · \(session)"
                case .stale:
                    let age = now.timeIntervalSince(observedAt)
                    return "行情滞后 \(Int(age / 60)) 分钟 · \(time) · \(source) · \(session)"
                case .unverified: return "行情时点未验证 · \(time) · \(source) · \(session)"
                }
            case "CLOSE", "CLOSED":
                return "交易时段：已收盘 · 最后行情时间 \(time) · \(source)"
            default:
                let ageLabel: String
                switch freshness {
                case .fresh: ageLabel = "时点在2分钟内"
                case .stale: ageLabel = "时点已滞后 \(Int(now.timeIntervalSince(observedAt) / 60)) 分钟"
                case .unverified: ageLabel = "行情时点未验证"
                }
                return "\(session) · 行情时间 \(time) · \(ageLabel) · \(source)"
            }
        }
        if let fetchedAt = quote.fetchedAt {
            return "获取于 \(formatter.string(from: fetchedAt)) · 行情时点未核验 · \(quote.source ?? "来源未知") · \(session)"
        }
        return "\(quote.source ?? "行情源未配置") · 尚无可用时点 · \(session)"
    }

    private func marketSessionLabel(_ rawStatus: String?) -> String {
        switch rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "OPEN": return "交易时段：交易中"
        case "CLOSE", "CLOSED": return "交易时段：已收盘"
        default: return "交易时段未验证"
        }
    }
}

struct RealAssetsOverview: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @State private var selectedView = 0
    private var theme: FHomeTheme { FHomeTheme.selected(themeRaw) }

    var body: some View {
        List {
            Section {
                FThemePageHeader(theme: theme, role: .assets, eyebrow: "本机账本 · 真实成交", title: "账户总览",
                               subtitle: "持仓、现金与成交记录均来自确认后的真实账本。",
                               symbol: "briefcase.fill",
                               value: model.portfolioMarketValuation(at: Date()).displayLabel,
                               valueLabel: "资产估值")
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 10, trailing: 10))
                    .listRowBackground(Color.clear)
                HStack(spacing: 0) {
                    assetMetric("可用现金", value: model.cashText, color: theme.manifest.tokens.candidate)
                    Rectangle().fill(theme.manifest.tokens.foreground.opacity(0.12)).frame(width: 1, height: 34)
                    assetMetric("持仓证券", value: "\(model.holdings.count) 项", color: theme.manifest.tokens.iopv)
                    Rectangle().fill(theme.manifest.tokens.foreground.opacity(0.12)).frame(width: 1, height: 34)
                    assetMetric("账本状态", value: model.ledgerState == .available ? "正常" : "待处理",
                                color: model.ledgerState == .available ? theme.manifest.tokens.positive : theme.manifest.tokens.warning)
                }
                .padding(.vertical, 12)
                .listRowBackground(theme.manifest.tokens.surface)
                Picker("资产视图", selection: $selectedView) {
                    Text("当前持仓").tag(0)
                    Text("已清仓").tag(1)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("assets.view-picker")
            }
            Section("本机真实账本") {
                assetSummaryRow("账本状态", value: model.ledgerStatus)
                assetSummaryRow("可用现金", value: model.cashText)
                assetSummaryRow("真实持仓", value: "\(model.holdings.count) 项")
                if model.ledgerState == .notEstablished {
                    Button {
                        model.clearLedgerWriteStatus()
                        model.showingInitialLedgerSetup = true
                    } label: {
                        Label("录入现有持仓", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("ledger.opening-snapshot.begin")
                    Text("按券商当前真实现金和持仓建立本机账本起点；这不会伪造成买入成交。")
                        .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                if model.ledgerState == .available {
                    Button { model.prepareManualLedgerFill() } label: {
                        Label("登记已成交买入 / 卖出", systemImage: "arrow.left.arrow.right.circle")
                    }
                    .accessibilityIdentifier("ledger.manual-fill.begin")
                    Text("已建账时，记录券商真实成交；若当前空仓，可录入已成交买入开始建仓。不会向券商下单。")
                        .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
            .listRowBackground(theme.manifest.tokens.portfolioSurface.opacity(0.085))
            if selectedView == 0 {
                Section("当前持仓") {
                if model.holdings.isEmpty {
                    Text(model.ledgerState == .available ? "账本已读取，当前没有真实持仓" : "真实持仓尚不可用")
                        .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                ForEach(model.holdings) { item in
                    NavigationLink(value: FHomeRoute.instrument(item.instrumentCode)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.headline)
                            Text("\(item.instrumentCode) · \(item.units) 份 · 账面成本 \(item.bookCost.description)")
                                .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        }
                    }
                }
                }
                .listRowBackground(theme.manifest.tokens.portfolioSurface.opacity(0.11))
            } else {
                Section("已清仓 / 历史持仓") {
                    let closed = model.instrumentHistories.filter { !$0.isCurrentlyHeld }
                    if closed.isEmpty { Text("暂无已清仓证券记录").foregroundStyle(theme.manifest.tokens.secondaryForeground) }
                    ForEach(closed) { history in
                        NavigationLink(value: FHomeRoute.instrument(history.instrumentCode)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(history.instrumentName) · \(history.instrumentCode)").font(.headline)
                                Text("\(history.episodes.count) 个持仓周期 · 历史已实现 \(history.lifetimeRealizedProfit.description)")
                                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                ForEach(history.episodes) { episode in
                                    Text("第\(episode.episodeNumber)轮：\(episode.openedAt.formatted(date: .numeric, time: .omitted)) 建仓 → \(episode.closedAt?.formatted(date: .numeric, time: .omitted) ?? "持有中") · 已实现 \(episode.netRealizedProfit.description)")
                                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(theme.manifest.tokens.highlightSurface.opacity(0.10))
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
                    Text(model.cashAdjustmentStatus).font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                if model.cashFlow.isEmpty { Text("暂无可读取的现金流水").foregroundStyle(theme.manifest.tokens.secondaryForeground) }
                ForEach(model.cashFlow.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        let isCashOnlyAdjustment = entry.kind == .accountExpense || entry.kind == .cashReconciliation
                        let isFeeAdjustment = entry.kind == .feeAdjustment
                        let displayedFee = isFeeAdjustment ? entry.fee : (entry.effectiveFee ?? entry.fee)
                        let feeLabel = isFeeAdjustment ? "手续费差额" :
                            (entry.effectiveFee != nil && entry.effectiveFee != entry.fee
                                ? "手续费（修正后）" : "手续费")
                        Text("\(entry.kind.label)\(entry.instrumentName.map { " · \($0)" } ?? "")")
                        Text("\(entry.occurredAt.formatted(date: .numeric, time: .shortened)) · 变动 \(entry.cashDelta.description) · 余额 \(entry.resultingCashBalance.description) · \(feeLabel) \(displayedFee.description)")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        if isCashOnlyAdjustment { Text(entry.reason).font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground) }
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
            .listRowBackground(theme.manifest.tokens.marketSurface.opacity(0.085))
            Section("资产安全") {
                Label("AI 建议和候选计划不写入真实账本", systemImage: "lock.shield")
                Text("只有用户确认实际成交后才写入账本；所有成交和现金变动保留在历史流水中。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
            .listRowBackground(theme.manifest.tokens.advisorSurface.opacity(0.085))
        }
        .accessibilityIdentifier("assets.list")
        .navigationTitle("真实资产")
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, theme.layoutFamily == .terminalDashboard || theme.layoutFamily == .minimalTerminal ? 39 : (theme.layoutFamily == .staticBento ? 58 : 50))
        .scrollContentBackground(.hidden)
        .background(theme.manifest.tokens.background.ignoresSafeArea())
        .sheet(isPresented: $model.showingFeeCorrection) {
            FLedgerFeeCorrectionSheet(model: model)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $model.showingInitialLedgerSetup) {
            FInitialLedgerSetupSheet(model: model)
        }
        .sheet(isPresented: $model.showingManualLedgerFill) {
            FManualLedgerFillSheet(model: model)
        }
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
        .tint(theme.accent)
        .listRowBackground(theme.manifest.tokens.surface)
    }

    private func assetSummaryRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            Text(value).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)：\(value)")
    }

    private func assetMetric(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
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
        case .accountExpense: "账户级杂费"
        case .cashReconciliation: "现金对账"
        }
    }
}

struct SettingsOverview: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @AppStorage("guanpan.f.nas.baseURL") private var nasBaseAddress = ""
    @State private var deepSeekKeyDraft = ""
    @State private var hasAutoCheckedNAS = false
    @State private var investorProfileDrafts: [FInvestorProfileAttributeKey: String] = [:]
    @State private var investorPreferencesExpanded = false
    @State private var preferenceAwaitingClear: FInvestorProfileAttributeKey?
    @State private var showingProfileClearConfirmation = false
    @FocusState private var settingsInputFocused: Bool
    private var theme: FHomeTheme { FHomeTheme.selected(themeRaw) }

    var body: some View {
        Form {
            Section {
                FThemePageHeader(theme: theme, role: .settings, eyebrow: "观盘max · 个性空间", title: "账户与体验",
                               subtitle: "统一调整顾问连接、可选数据服务与整套界面风格。",
                               symbol: "slider.horizontal.3", value: theme.manifest.name,
                               valueLabel: "当前主题")
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 10, trailing: 10))
                    .listRowBackground(Color.clear)
            }
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
            Section("投资者画像") {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        investorPreferencesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(investorPreferencesExpanded ? "收起其他偏好" : "更多投资偏好")
                        Spacer()
                        Image(systemName: investorPreferencesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.profile.edit")
                Text("只保存你填写的内容，并在在线顾问分析时作为本次上下文；不会改写账本。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(FInvestorProfileAttributeKey.allCases, id: \.self) { key in
                    if key == .investmentHorizon || investorPreferencesExpanded {
                        VStack(alignment: .leading, spacing: 7) {
                            TextField(profileTitle(key), text: Binding(
                                get: { investorProfileDrafts[key] ?? currentPreferenceText(key) },
                                set: { investorProfileDrafts[key] = $0 }
                            ))
                            .accessibilityIdentifier("profile.preference.\(key.rawValue)")
                            HStack {
                                Button("保存") {
                                    let value = investorProfileDrafts[key] ?? currentPreferenceText(key)
                                    Task {
                                        await model.saveExplicitInvestorPreference(key, value: value)
                                        investorProfileDrafts[key] = nil
                                    }
                                }
                                .disabled(model.loadingInvestorProfile || model.savingInvestorProfile ||
                                          (investorProfileDrafts[key] ?? currentPreferenceText(key))
                                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("profile.preference.save.\(key.rawValue)")
                                if model.investorProfile.attribute(key)?.current() != nil {
                                    Button("清除", role: .destructive) {
                                        preferenceAwaitingClear = key
                                        showingProfileClearConfirmation = true
                                    }
                                    .disabled(model.loadingInvestorProfile || model.savingInvestorProfile)
                                    .accessibilityIdentifier("profile.preference.clear.\(key.rawValue)")
                                }
                            }
                        }
                    }
                }
                Text(model.investorProfileStatus)
                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .accessibilityIdentifier("profile.preference.status")
            }
            Section("可选同步与数据服务") {
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
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
                Text("局域网需同一 Wi‑Fi/VPN；外网请使用手机可达的 HTTPS 地址。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                DisclosureGroup("连接方式与安全说明") {
                Text("NAS是可选同步、归档与备份服务，不是实时行情、Local Quant或基础顾问分析的前置条件。连接测试只读取 /readyz，不发送持仓。远程访问请使用可达的HTTPS入口并限制网络访问。")
                        .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                DisclosureGroup("行情与历史数据") {
                    LabeledContent("实时行情", value: "iPhone 直连公开行情源")
                    LabeledContent("证券历史日 K", value: nasBaseAddress.isEmpty ? "需配置 NAS" : "通过 NAS 读取归档")
                    LabeledContent("历史分钟", value: nasBaseAddress.isEmpty ? "需配置 NAS；实际覆盖待验证" : "NAS 按日期查询；实际覆盖待验证")
                    LabeledContent("指数历史日 K", value: nasBaseAddress.isEmpty ? "需配置 NAS" : "受支持指数通过 NAS 读取")
                    LabeledContent("NAS 后台历史采集", value: nasBaseAddress.isEmpty
                        ? "需配置 NAS" : "按部署标的清单运行；队列与覆盖见连接状态")
                    LabeledContent("新闻来源", value: "同花顺财经 7×24 · 公开网页接口")
                    LabeledContent("新闻最近状态", value: model.newsStatus)
                    Text("新闻仅在实际请求成功且快讯时间有效时进入顾问上下文；关联证券必须由来源明确标注。公开网页接口不保证稳定，标题/摘要不等于已核实全文。NAS Ready只表示服务在线，不代表指定日期已有完整历史分钟。缺失数据不会补造。")
                        .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                                .foregroundStyle(theme == item ? item.manifest.tokens.accent : item.manifest.tokens.foreground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(theme == item ? item.manifest.tokens.accent.opacity(0.13) : item.manifest.tokens.surface.opacity(0.78),
                                            in: Capsule())
                                .overlay(Capsule().stroke(item.manifest.tokens.accent.opacity(theme == item ? 0.55 : 0.16), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("theme.selector.\(item.rawValue)")
                        }
                    }
                }
                Text("当前：\(theme.manifest.name) · \(theme.manifest.layout.description)")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                DisclosureGroup("查看全部主题预览") {
                    ForEach(FHomeTheme.allCases) { item in
                        Button { themeRaw = item.rawValue } label: {
                            FThemeGalleryRow(theme: item, selected: theme == item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("主题切换只改变信息编排与呈现。浅色/深色语义token跟随系统外观；护眼模式、动态字体和跨设备截图仍待Simulator验收。当前Tab与导航栈由各自的NavigationStack保留。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            }
            Section("数据诊断") {
                DisclosureGroup("查看账本、日历与行情请求状态") {
                LabeledContent("真实账本", value: model.ledgerStatus)
                LabeledContent("交易日历", value: model.marketCalendarStatusText)
                if model.marketRefreshStateByCode.isEmpty {
                    Text("尚无行情请求记录").foregroundStyle(theme.manifest.tokens.secondaryForeground)
                } else {
                    ForEach(model.marketRefreshStateByCode.keys.sorted(), id: \.self) { code in
                        LabeledContent(code, value: model.marketRefreshStateByCode[code] ?? "状态未知")
                    }
                }
                }
            }
            Section("高级研究") {
                DisclosureGroup("研究能力与限制") {
                LabeledContent("股息判断", value: "自动 / AI 综合判断")
                Text("4% 仅作为研究参考；当前 App 尚未提供自定义最低股息率设置。")
                    .font(.footnote).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
        }
        .accessibilityIdentifier("settings.form")
        .scrollDismissesKeyboard(.interactively)
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, theme.layoutFamily == .terminalDashboard || theme.layoutFamily == .minimalTerminal ? 39 : (theme.layoutFamily == .staticBento ? 58 : 50))
        .scrollContentBackground(.hidden)
        .background(theme.manifest.tokens.background.ignoresSafeArea())
        .confirmationDialog("清除画像偏好？", isPresented: $showingProfileClearConfirmation,
                            titleVisibility: .visible) {
            Button("清除该项画像", role: .destructive) {
                guard let key = preferenceAwaitingClear else { return }
                investorProfileDrafts[key] = nil
                Task { await model.clearInvestorProfileAttribute(key) }
            }
            Button("取消", role: .cancel) { preferenceAwaitingClear = nil }
        } message: {
            Text("只会删除这项用户偏好，不会改动真实账本或其他画像内容。")
        }
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
        .onChange(of: nasBaseAddress) { newAddress in
            model.nasAddressDidChange(newAddress)
        }
    }

    private func currentPreferenceText(_ key: FInvestorProfileAttributeKey) -> String {
        guard let value = model.investorProfile.attribute(key)?.current()?.value else { return "" }
        switch value {
        case .text(let text): return text
        case .decimal(let number): return NSDecimalNumber(decimal: number).stringValue
        case .integer(let number): return String(number)
        case .boolean(let value): return value ? "是" : "否"
        }
    }

    private func profileTitle(_ key: FInvestorProfileAttributeKey) -> String {
        switch key {
        case .investmentHorizon: return "投资期限"
        case .riskTolerance: return "风险承受"
        case .tradingFrequency: return "交易频率"
        case .patientLimitPreference: return "耐心限价偏好"
        case .dayTradePreference: return "做 T 偏好"
        case .gridPreference: return "网格偏好"
        case .cashReservePreference: return "现金储备偏好"
        case .investmentStyle: return "投资风格"
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
            Text(manifest.layout.description).font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            HStack {
                Text("密度：\(manifest.layout.informationDensity)")
                Spacer()
                Text(manifest.useCase)
            }
            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
            Text(manifest.appearanceCompatibility)
                .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
    @State private var securityLookupName = ""
    @State private var securityLookupStatus = ""
    @State private var securityLookupRetry = 0
    @State private var listScope: FMarketListScope = .combined
    @FocusState private var securityLookupFocused: Bool
    private var theme: FHomeTheme { FHomeTheme.selected(themeRaw) }

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
                FThemePageHeader(theme: theme, role: .market, eyebrow: "实时雷达 · 更新 10 秒", title: "行情新鲜度",
                               subtitle: "手机直连行情源 · 曲线按上游分钟时点绘制",
                               symbol: "waveform.path.ecg", value: model.marketCalendarStatusText,
                               valueLabel: "市场时段")
                HStack {
                    Label("\(visibleSecurityCodes.count) 个关注标的", systemImage: "line.3.horizontal.decrease")
                        .font(.caption.weight(.semibold)).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    Spacer()
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
                            securityLookupName = ""
                            securityLookupStatus = ""
                        }
                        .task(id: "\(securityLookupCode)-\(securityLookupRetry)") {
                            let requested = securityLookupCode
                            guard requested.utf8.count == 6,
                                  requested.utf8.allSatisfy({ (48...57).contains($0) }) else { return }
                            securityLookupStatus = "正在识别证券名称…"
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            if let name = await model.lookupInstrumentName(code: requested),
                               !Task.isCancelled, securityLookupCode == requested {
                                securityLookupName = name
                                securityLookupStatus = "已识别"
                            } else if !Task.isCancelled, securityLookupCode == requested {
                                securityLookupStatus = "行情源暂未识别到名称，可重试或继续查看详情"
                            }
                        }
                    if !securityLookupName.isEmpty {
                        Label(securityLookupName, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.manifest.tokens.positive)
                            .accessibilityIdentifier("market.security-name")
                    } else if !securityLookupStatus.isEmpty {
                        HStack {
                            Text(securityLookupStatus).font(.caption)
                                .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            if securityLookupStatus.hasPrefix("行情源") {
                                Button("重试") { securityLookupRetry += 1 }
                                    .font(.caption.weight(.semibold))
                                    .accessibilityIdentifier("market.security-name.retry")
                            }
                        }
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
                .padding(14)
                .background(theme.manifest.tokens.highlightSurface.opacity(theme == .dashboard || theme == .minimalTerminal ? 0.20 : 0.30),
                            in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(theme.accent.opacity(0.16), lineWidth: 0.8))

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
                                            Text(holding == nil
                                                 ? "自选关注"
                                                 : (model.isInWatchlist(code) ? "真实持仓 · 自选" : "真实持仓"))
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
                            HStack(spacing: 12) {
                                FWatchlistSparkline(samples: snapshot.samples,
                                    positiveColor: theme.manifest.tokens.positive,
                                    negativeColor: theme.manifest.tokens.negative)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .accessibilityLabel("\(code) 盘中趋势")
                                VStack(alignment: .trailing, spacing: 3) {
                                    if let assessment = model.watchlistQuantAssessment(for: code),
                                       let score = assessment.watchlistDirectionalScore {
                                        Text("\(score > 0 ? "+" : "")\(score)")
                                            .font(.subheadline.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(score >= 0 ? theme.manifest.tokens.positive : theme.manifest.tokens.negative)
                                        Text("方向观察分 · \(assessment.watchlistDirectionalFactorCount)因子")
                                            .font(.caption2)
                                            .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                    } else {
                                        Text("样本不足")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(theme.manifest.tokens.unavailable)
                                        Text("不代表收益概率")
                                            .font(.caption2)
                                            .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                                    }
                                }
                            }
                        } else {
                            Text("暂无真实行情 · 刷新后显示趋势与观察分")
                                .font(.caption).foregroundStyle(theme.manifest.tokens.unavailable)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }
                        Text(snapshot.map {
                            "行情时间 \($0.quoteTimestamp.formatted(date: .omitted, time: .standard)) · 获取于 \($0.fetchedAt.formatted(date: .omitted, time: .standard)) · \($0.source)"
                        } ?? "行情时间/来源待获取")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
                        Text(model.marketRefreshStateByCode[code] ?? "等待首次请求")
                            .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground).lineLimit(1)
                    }
                    .padding(13)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(
                                colors: [theme.manifest.tokens.surface,
                                         theme.manifest.tokens.marketSurface.opacity(
                                            theme.surfaceTreatment == .bento || theme.surfaceTreatment == .adaptive ? 0.30 : 0.16)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.manifest.tokens.marketSurface.opacity(0.48), lineWidth: 0.9))
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

private struct FWatchlistSparkline: View {
    let samples: [FMinuteSample]
    let positiveColor: Color
    let negativeColor: Color

    var body: some View {
        GeometryReader { geometry in
            let values = samples.compactMap { sample -> CGFloat? in
                let value = NSDecimalNumber(decimal: sample.price).doubleValue
                return value.isFinite && value > 0 ? CGFloat(value) : nil
            }
            if values.count >= 2, let first = values.first, let last = values.last {
                let minimum = values.min() ?? first
                let maximum = values.max() ?? last
                let span = max(maximum - minimum, max(abs(maximum) * 0.0001, 0.000001))
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = geometry.size.height - ((value - minimum) / span * (geometry.size.height - 4)) - 2
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(last >= first ? positiveColor : negativeColor,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(positiveColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
    }
}

private struct FAdvisorResultCard: View {
    let result: FAdvisorVerticalSliceResult
    let theme: FHomeTheme
    let accent: Color
    let risk: Color
    let confirmLedger: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("顾问结论 · \(result.scopeTitle)").font(.headline)
                .accessibilityIdentifier("advisor.result.heading")
            Text(result.narrative.conclusion).font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("advisor.result.conclusion")
            Text("依据").font(.subheadline.bold())
            Text(result.narrative.basis).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("advisor.result.basis")
            LabeledContent("真实账本", value: "只读快照 · \(result.ledgerCapturedAt.formatted(date: .abbreviated, time: .shortened))")
            Text("真实持仓").font(.subheadline.bold())
            Text(result.holdingSummary).font(.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("advisor.result.holdings")
            LabeledContent("可用现金", value: "¥\(NSDecimalNumber(decimal: result.cashBalance))")
            Text("行情").font(.subheadline.bold())
            Text(result.quoteStatus).font(.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("advisor.result.quotes")
            Text("NAS 研究").font(.subheadline.bold())
            Text(result.researchStatus).font(.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("advisor.result.research")
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
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                    Label("Guard 已通过人工审阅门槛；不下单、不写 Ledger", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    if result.candidate.action == .buy || result.candidate.action == .sell {
                        Button("登记用户确认的真实成交", action: confirmLedger)
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .accessibilityIdentifier("advisor.confirm-real-fill")
                    } else {
                        Text("做T、网格和回本仅作分析；请逐笔核对真实成交后另行登记。")
                            .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                }
            } else {
                Text("Guard 已阻止此候选计划").font(.subheadline.bold()).foregroundStyle(risk)
                ForEach(Array(result.assessment.guardResult.findings.enumerated()), id: \.offset) { _, item in
                    Text("• \(item.displayName)").font(.caption).foregroundStyle(risk)
                }
            }
            Text("真实资产只能在用户确认真实成交后变化；此结果没有账本写入能力。")
                .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
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
                    Picker("现金事项", selection: $model.cashAdjustmentAddsCash) {
                        Text("账户级杂费 / 减少现金").tag(false)
                        Text("现金对账 / 增加余额").tag(true)
                    }
                    TextField("金额（正数）", text: $model.cashAdjustmentAmountText)
                        .keyboardType(.decimalPad)
                    TextField("费用或对账原因", text: $model.cashAdjustmentReason,
                              axis: .vertical)
                        .lineLimit(2...3)
                    Text("账户级杂费会单独分类并减少现金，不归属到具体证券或成交，也不会改变证券成本、已实现盈亏或持仓数量。")
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

private struct FInitialLedgerPositionDraft: Identifiable {
    let id = UUID()
    var instrumentCode = ""
    var name = ""
    var units = ""
    var economicCostPerUnit = ""
}

struct FInitialLedgerSetupSheet: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.dismiss) private var dismiss
    @State private var cashText = ""
    @State private var positions = [FInitialLedgerPositionDraft()]
    @State private var attemptedSave = false
    @FocusState private var inputFocused: Bool

    private var parsedPositions: [FInitialLedgerPositionInput]? {
        guard !positions.isEmpty else { return nil }
        var parsed: [FInitialLedgerPositionInput] = []
        for draft in positions {
            guard let position = parsePosition(draft) else { return nil }
            parsed.append(position)
        }
        let codes = parsed.map { $0.instrumentCode }
        guard Set(codes).count == parsed.count else { return nil }
        return parsed
    }

    private func parsePosition(_ draft: FInitialLedgerPositionDraft) -> FInitialLedgerPositionInput? {
        let code = draft.instrumentCode
        guard code.utf8.count == 6,
              code.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        guard let units = Int64(draft.units), units > 0 else { return nil }
        guard let costPerUnit = Decimal(
            string: draft.economicCostPerUnit,
            locale: Locale(identifier: "en_US_POSIX")
        ), costPerUnit.isFinite, costPerUnit >= 0 else { return nil }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let totalEconomicCost = costPerUnit * Decimal(units)
        guard totalEconomicCost.isFinite, totalEconomicCost >= 0 else { return nil }
        return FInitialLedgerPositionInput(
            instrumentCode: code,
            name: name,
            units: units,
            economicCost: totalEconomicCost,
            brokerDisplayCostPerUnit: nil
        )
    }

    private var canSave: Bool {
        guard model.ledgerState == .notEstablished,
              let cash = Decimal(string: cashText, locale: Locale(identifier: "en_US_POSIX")),
              cash.isFinite, cash >= 0,
              parsedPositions != nil else { return false }
        return true
    }

    private var validationMessage: String {
        guard model.ledgerState == .notEstablished else { return "本机账本已建立；请通过真实成交更新持仓。" }
        guard let cash = Decimal(string: cashText, locale: Locale(identifier: "en_US_POSIX")),
              cash.isFinite, cash >= 0 else { return "请输入券商可用现金；没有现金请填写 0。" }
        guard !positions.isEmpty else { return "至少录入一只当前持仓；空仓也可填入 0 份的现金账本。" }
        for (index, position) in positions.enumerated() {
            if position.instrumentCode.count != 6 { return "第 \(index + 1) 只：请输入 6 位证券代码。" }
            if position.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "第 \(index + 1) 只：名称未识别，请手动填写证券名称。"
            }
            if Int64(position.units).map({ $0 > 0 }) != true { return "第 \(index + 1) 只：请输入大于 0 的持有份额。" }
            if Decimal(string: position.economicCostPerUnit, locale: Locale(identifier: "en_US_POSIX")).map({ $0.isFinite && $0 >= 0 }) != true {
                return "第 \(index + 1) 只：请输入有效的本轮每份成本。"
            }
        }
        return "信息已齐，可以建立本机账本。"
    }

    private var cashEntrySection: some View {
        Section("券商账户现金") {
            TextField("可用现金（没有现金填写 0）", text: $cashText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("ledger.opening.cash")
            Text("按券商当前可用余额填写，用于计算真实账户总资产。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var positionsSection: some View {
        Section("当前真实持仓") {
            Text("录入一只就可以；如有多只，再点下方添加。这里记录券商当前余额，不会伪造成交。")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach($positions) { $position in
                let positionID = position.id
                let ordinal = (positions.firstIndex { $0.id == positionID } ?? 0) + 1
                FInitialLedgerPositionRow(
                    draft: $position,
                    ordinal: ordinal,
                    canRemove: positions.count > 1,
                    model: model
                ) {
                    positions.removeAll { $0.id == positionID }
                }
            }
            Button {
                positions.append(FInitialLedgerPositionDraft())
            } label: {
                Label("添加另一只证券（可选）", systemImage: "plus")
            }
            .accessibilityIdentifier("ledger.opening.position.add")
        }
    }

    private var confirmationSection: some View {
        Section("保存前确认") {
            Text(validationMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(canSave ? .green : (attemptedSave ? Color.red : .secondary))
                .accessibilityIdentifier("ledger.opening.validation")
            Text("这些数字会作为本机真实账本的起点，不代表历史成交。导入前的历史盈亏不会被虚构；保存后请用真实成交更新。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var ledgerStatusSection: some View {
        if !model.ledgerWriteStatus.isEmpty {
            Section("状态") {
                Text(model.ledgerWriteStatus).font(.footnote)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                cashEntrySection
                positionsSection
                confirmationSection
                ledgerStatusSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("录入现有持仓")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(model.writingInitialLedger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.writingInitialLedger ? "保存中…" : "保存账本起点") {
                        guard canSave, let parsedPositions else {
                            attemptedSave = true
                            return
                        }
                        Task {
                            let saved = await model.establishInitialLedger(
                                cashText: cashText, positions: parsedPositions,
                                note: "用户确认录入券商当前现金与现有持仓，建立本机账本起点")
                            if saved { dismiss() }
                        }
                    }
                    .disabled(model.writingInitialLedger)
                    .accessibilityIdentifier("ledger.opening.confirm")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { inputFocused = false }
                }
            }
        }
    }
}

private struct FInitialLedgerPositionRow: View {
    @Binding var draft: FInitialLedgerPositionDraft
    let ordinal: Int
    let canRemove: Bool
    @ObservedObject var model: FHomeModel
    let remove: () -> Void
    @FocusState private var inputFocused: Bool
    @State private var lookupStatus = ""
    @State private var retryLookup = 0
    @State private var lastResolvedName: String?

    private var lookupTaskID: String { "\(draft.instrumentCode)-\(retryLookup)" }

    private func resolveName(for code: String) async {
        guard code.utf8.count == 6,
              code.utf8.allSatisfy({ (48...57).contains($0) }),
              draft.instrumentCode == code else { return }
        lookupStatus = "正在识别名称…"
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, draft.instrumentCode == code else { return }
        if let name = await model.lookupInstrumentName(code: code),
           !Task.isCancelled, draft.instrumentCode == code,
           draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastResolvedName = name
            draft.name = name
            lookupStatus = "已识别：\(name)"
        } else if !Task.isCancelled, draft.instrumentCode == code {
            lookupStatus = "行情源未识别到名称，可手动填写或重试。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("证券 \(ordinal)").font(.subheadline.weight(.semibold))
                Spacer()
                if canRemove {
                    Button("移除", role: .destructive, action: remove)
                        .font(.caption)
                }
            }
            TextField("6位证券代码", text: $draft.instrumentCode)
                .keyboardType(.numberPad).focused($inputFocused)
                .accessibilityIdentifier("ledger.opening.position.code")
                .onChange(of: draft.instrumentCode) { code in
                    let digits = String(code.unicodeScalars
                        .filter { (48...57).contains($0.value) }.prefix(6))
                    if digits != code { draft.instrumentCode = digits; return }
                    draft.name = ""
                    lastResolvedName = nil
                    lookupStatus = ""
                }
                .task(id: lookupTaskID) { await resolveName(for: draft.instrumentCode) }
            TextField("证券名称（自动识别，可修改）", text: $draft.name)
                .focused($inputFocused)
                .accessibilityIdentifier("ledger.opening.position.name")
                .onChange(of: draft.name) { name in
                    if name != lastResolvedName { lastResolvedName = nil }
                }
            if !lookupStatus.isEmpty {
                HStack(spacing: 8) {
                    Text(lookupStatus).font(.caption).foregroundStyle(.secondary)
                    if lookupStatus.hasPrefix("行情源") {
                        Button("重试") { retryLookup += 1 }
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            TextField("当前持有份额", text: $draft.units)
                .keyboardType(.numberPad).focused($inputFocused)
                .accessibilityIdentifier("ledger.opening.position.units")
            TextField("每份真实经济成本（含费用）", text: $draft.economicCostPerUnit)
                .keyboardType(.decimalPad).focused($inputFocused)
                .accessibilityIdentifier("ledger.opening.position.unitCost")
            Text("本轮成本按当前份额 × 每份真实经济成本计算。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ledger.opening.position.\(draft.id.uuidString)")
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



struct FManualLedgerFillSheet: View {
    @ObservedObject var model: FHomeModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("已完成的券商成交") {
                    TextField("证券代码（6位）", text: $model.manualFillInstrumentCode).keyboardType(.numberPad)
                    TextField("证券名称", text: $model.manualFillInstrumentName)
                    Picker("方向", selection: $model.manualFillSide) {
                        Text("买入").tag(FTradeSide.buy)
                        Text("卖出").tag(FTradeSide.sell)
                    }
                    DatePicker("实际成交时间", selection: $model.manualFillTradeAt, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    TextField("真实成交份额", text: $model.manualFillUnitsText).keyboardType(.numberPad)
                    TextField("真实成交价格", text: $model.manualFillPriceText).keyboardType(.decimalPad)
                    TextField("实际手续费", text: $model.manualFillFeeText).keyboardType(.decimalPad)
                    Text("手续费按券商实际金额填写；默认值只作起填参考，可修改。此操作不向券商下单。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("成交用途与审计") {
                    Picker("用途", selection: $model.manualFillTradeIntent) {
                        ForEach(FTradeIntent.allCases, id: \.self) { intent in Text(intent.displayName).tag(intent) }
                    }
                    if model.manualFillTradeIntent != .ordinary {
                        TextField("T配对编号", text: $model.manualFillTCycleID)
                    }
                    TextField("确认说明（必填）", text: $model.manualFillConfirmationNote, axis: .vertical).lineLimit(2...4)
                }
                Section("账本边界") {
                    Text("保存会追加真实成交记录并按账本规则重算现金、成本和盈亏。初始持仓快照只能在账本未建立时录入；本入口不会改写历史快照。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !model.ledgerWriteStatus.isEmpty { Text(model.ledgerWriteStatus).font(.footnote) }
                }
            }
            .navigationTitle("记录真实成交")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(model.writingManualFill) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.writingManualFill ? "写入中" : "继续确认") { model.requestManualLedgerFillConfirmation() }
                        .disabled(model.writingManualFill)
                }
            }
            .confirmationDialog("确认这笔交易已经在券商实际成交？", isPresented: $model.manualFillNeedsFinalConfirmation, titleVisibility: .visible) {
                Button("确认真实成交并更新账本", role: .destructive) { model.confirmManualLedgerFill() }
                Button("返回检查", role: .cancel) { }
            } message: { Text("只登记你填写的成交事实，不会下单。确认后现金、持仓、成本、盈亏和成交流水将更新。") }
        }
    }
}

private struct FInitialCashEntrySheet: View {
    @Binding var cashText: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("券商当前可用现金") {
                    TextField("当前可用现金", text: $cashText)
                        .keyboardType(.decimalPad)
                        .focused($inputFocused)
                        .accessibilityIdentifier("ledger.opening.cash")
                    Text("现金单独录入，不会和持仓份额或成本混在一起。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("录入券商现金")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}


