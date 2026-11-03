Warning: truncated output (original token count: 58454)
Total output lines: 4350

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
                        Image(systemName: "banknote.fill").foregroundStyle(.orange)
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
                        .foregroundStyle(dark ? .black : tokens.advisorSurface)
                        .background(.white, in: Capsule())
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
                    NavigationLink(value: FHomeRoute.crossMarket) {
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
                    }.buttonStyle(.plain)
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
        .foregroundStyle(theme == .dashboard || theme == .minimalTerminal ? .white : .black.opacity(0.82))
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
…28454 tokens truncated…fest.tokens.accent.opacity(theme == item ? 0.55 : 0.16), lineWidth: 1))
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
                .foregroundStyle(canSave ? .green : .secondary)
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
                        guard let parsedPositions else { return }
                        Task {
                            let saved = await model.establishInitialLedger(
                                cashText: cashText, positions: parsedPositions,
                                note: "用户确认录入券商当前现金与现有持仓，建立本机账本起点")
                            if saved { dismiss() }
                        }
                    }
                    .disabled(!canSave || model.writingInitialLedger)
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


