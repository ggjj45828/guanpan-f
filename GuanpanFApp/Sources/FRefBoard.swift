import SwiftUI
import FCore
import FAdvisor

// MARK: - 参考稿首页板（观盘max）
//
// 严格按用户给的参考图搭：品牌栏 → 资产卡 → AI 今日判断 → 持仓纪律/现金缓冲
// → 市场脉搏（三列）→ 自选监控（评分 + 涨跌幅）→ 底栏。
// 四套皮肤对应参考图的蓝海资产 / 深空终端 / 极光全景 / 暗夜科技，
// 同一套布局，只换画布、卡片、强调色与资产卡渐变。
//
// 数据一律来自本机账本与真实行情，取不到就显示「—」或状态文案，
// 不为了好看编造数字。

enum FRefBoardSkinID: String, CaseIterable, Identifiable {
    case blue, terminal, aurora, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: return "蓝海资产"
        case .terminal: return "深空终端"
        case .aurora: return "极光全景"
        case .night: return "暗夜科技"
        }
    }

    var note: String {
        switch self {
        case .blue: return "温暖清晰，资产导向"
        case .terminal: return "专业高密，交易终端"
        case .aurora: return "多彩模块，全景洞察"
        case .night: return "沉稳高效，科技质感"
        }
    }
}

struct FRefBoardSkin {
    let isLight: Bool
    let canvasTop: Color
    let canvasBottom: Color
    let card: Color
    let cardAlt: Color
    let ink: Color
    let muted: Color
    let line: Color
    let accent: Color
    let up: Color
    let down: Color
    let assetGradient: [Color]
    let brandDark: Color
    let brandWarm: Color
    let aiIcon: Color
    let chipBg: Color
    let chipInk: Color

    private static func c(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    static func palette(_ id: FRefBoardSkinID) -> FRefBoardSkin {
        switch id {
        case .blue:
            return FRefBoardSkin(
                isLight: true,
                canvasTop: c(243, 246, 252), canvasBottom: c(233, 239, 250),
                card: c(255, 255, 255), cardAlt: c(247, 249, 254),
                ink: c(15, 31, 51), muted: c(124, 138, 160), line: c(226, 232, 242),
                accent: c(47, 107, 255), up: c(226, 59, 50), down: c(18, 154, 92),
                assetGradient: [c(23, 58, 99), c(47, 111, 168), c(127, 183, 232)],
                brandDark: c(23, 58, 99), brandWarm: c(240, 122, 42),
                aiIcon: c(232, 72, 63), chipBg: c(253, 240, 230), chipInk: c(201, 122, 34))
        case .terminal:
            return FRefBoardSkin(
                isLight: false,
                canvasTop: c(7, 11, 12), canvasBottom: c(5, 8, 9),
                card: c(15, 21, 23), cardAlt: c(19, 27, 29),
                ink: c(230, 242, 237), muted: c(111, 128, 123), line: c(29, 39, 41),
                accent: c(53, 224, 161), up: c(255, 90, 82), down: c(53, 224, 161),
                assetGradient: [c(6, 37, 27), c(12, 58, 42), c(16, 80, 58)],
                brandDark: c(230, 242, 237), brandWarm: c(242, 160, 61),
                aiIcon: c(232, 72, 63), chipBg: c(58, 42, 24), chipInk: c(232, 178, 105))
        case .aurora:
            return FRefBoardSkin(
                isLight: true,
                canvasTop: c(246, 245, 252), canvasBottom: c(239, 236, 251),
                card: c(255, 255, 255), cardAlt: c(246, 242, 255),
                ink: c(26, 22, 48), muted: c(138, 133, 166), line: c(230, 225, 245),
                accent: c(123, 92, 250), up: c(226, 59, 50), down: c(18, 154, 92),
                assetGradient: [c(91, 72, 232), c(142, 107, 255), c(196, 168, 255)],
                brandDark: c(59, 46, 140), brandWarm: c(240, 122, 42),
                aiIcon: c(232, 72, 63), chipBg: c(241, 236, 255), chipInk: c(107, 83, 214))
        case .night:
            return FRefBoardSkin(
                isLight: false,
                canvasTop: c(5, 7, 9), canvasBottom: c(3, 4, 5),
                card: c(12, 17, 19), cardAlt: c(16, 23, 26),
                ink: c(228, 239, 236), muted: c(106, 122, 120), line: c(26, 35, 38),
                accent: c(47, 216, 160), up: c(255, 90, 82), down: c(47, 216, 160),
                assetGradient: [c(3, 30, 24), c(10, 53, 42), c(14, 74, 56)],
                brandDark: c(228, 239, 236), brandWarm: c(242, 160, 61),
                aiIcon: c(232, 72, 63), chipBg: c(53, 39, 26), chipInk: c(224, 170, 99))
        }
    }
}

// MARK: - 首页

struct FRefBoardHome: View {
    @ObservedObject var model: FHomeModel
    let skinID: FRefBoardSkinID
    @State private var amountsHidden = false

    private var skin: FRefBoardSkin { FRefBoardSkin.palette(skinID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            brandBar
            assetCard
            aiJudgementCard
            disciplineRow
            pulseCard
            watchCard
            footer
        }
    }

    // MARK: 品牌栏

    private var brandBar: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text("观盘").font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(skin.brandDark)
                    Text("max").font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(skin.brandWarm)
                }
                Text("看懂市场 · 做更好的投资决策")
                    .font(.system(size: 9.5))
                    .foregroundStyle(skin.muted)
            }
            Spacer(minLength: 4)
            NavigationLink(value: FHomeRoute.market) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(skin.ink)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索行情")

            NavigationLink(value: FHomeRoute.advisor) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(skin.ink)
                        .frame(width: 30, height: 30)
                    if model.advisorResult == nil {
                        Circle().fill(skin.aiIcon)
                            .frame(width: 6, height: 6)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("待处理提醒")
        }
        .padding(.top, 2)
    }

    // MARK: 资产卡

    private var assetCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text("我的真实资产（人民币）")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                Button {
                    amountsHidden.toggle()
                } label: {
                    Image(systemName: amountsHidden ? "eye.slash" : "eye")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(amountsHidden ? "显示金额" : "隐藏金额")
                Spacer(minLength: 0)
                NavigationLink(value: FHomeRoute.portfolio) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.16), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.reference.assets.open")
            }

            if let total = totalAssets {
                Text(amountsHidden ? "••••••" : FRefFormat.plain(total, digits: 2))
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.white)
                    .padding(.top, 5)
                HStack(spacing: 6) {
                    Text("今日收益")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    if let change = dayChange {
                        Text(amountsHidden ? "••••" : FRefFormat.signedMoney(change))
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(dayChangePercent.map { FRefFormat.percent($0) } ?? "—")
                            .font(.system(size: 10.5, weight: .semibold))
                    } else {
                        Text("待行情补齐").font(.system(size: 10.5, weight: .medium))
                    }
                }
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.96))
                .padding(.top, 3)
            } else {
                Text("尚未建立本机账本")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                NavigationLink(value: FHomeRoute.portfolio) {
                    HStack(spacing: 5) {
                        Text("录入持仓与现金，开始计算")
                            .font(.system(size: 10.5, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(skin.brandDark)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.94), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 7)
                .accessibilityIdentifier("home.reference.setup-ledger")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(colors: skin.assetGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                FRefBoardTerrain()
                    .fill(.white.opacity(skin.isLight ? 0.14 : 0.06))
                if !skin.isLight {
                    RadialGradient(colors: [.white.opacity(0.10), .clear],
                                   center: .topTrailing, startRadius: 4, endRadius: 150)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.white.opacity(skin.isLight ? 0.20 : 0.12), lineWidth: 0.8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.portfolio")
    }

    // MARK: AI 今日判断

    private var aiJudgementCard: some View {
        NavigationLink(value: FHomeRoute.advisor) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().fill(skin.aiIcon)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("AI 今日判断")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(skin.ink)
                        Text(model.advisorResult == nil ? "等待" : "已生成")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(skin.chipInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(skin.chipBg, in: Capsule())
                        Spacer(minLength: 0)
                    }
                    Text(aiHeadline)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(skin.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(aiBasis)
                        .font(.system(size: 10.5))
                        .foregroundStyle(skin.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(skin.muted)
                    .padding(.top, 6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(skin.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(skin.line, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.advisorGuidance")
    }

    private var aiHeadline: String {
        if let result = model.advisorResult { return result.narrative.conclusion }
        if model.ledgerState != .available { return "先建立真实账本" }
        if model.isAskingAdvisor { return "正在结合持仓分析" }
        return "等待今日判断"
    }

    private var aiBasis: String {
        if let result = model.advisorResult { return result.narrative.basis }
        if model.ledgerState != .available {
            return "顾问不构造虚拟持仓。录入真实持仓后，判断才会基于你的成本与仓位。"
        }
        return "点开 AI 顾问提问，结论会同时给出依据、风险与失效条件。"
    }

    // MARK: 持仓纪律 / 现金缓冲

    private var disciplineRow: some View {
        HStack(spacing: 9) {
            disciplineCard(title: "当前持仓纪律",
                           ratio: positionRatio,
                           okText: "符合",
                           symbol: "checkmark.shield.fill")
            disciplineCard(title: "现金缓冲",
                           ratio: cashRatio,
                           okText: "充足",
                           symbol: "banknote.fill")
        }
    }

    private func disciplineCard(title: String, ratio: Double?, okText: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(skin.accent)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(skin.muted)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let ratio {
                    Text("约").font(.system(size: 9)).foregroundStyle(skin.muted)
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(skin.ink)
                } else {
                    Text("—").font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(skin.muted)
                }
                Spacer(minLength: 2)
                if let ratio, isHealthy(ratio, forTitle: title) {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark").font(.system(size: 7, weight: .black))
                        Text(okText).font(.system(size: 8.5, weight: .semibold))
                    }
                    .foregroundStyle(skin.down)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(skin.down.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(skin.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(skin.line, lineWidth: 0.8))
    }

    /// 纪律区间来自本机规则，不是 AI 结论：持仓 40%–85%、现金 10%–40%。
    private func isHealthy(_ ratio: Double, forTitle title: String) -> Bool {
        if title.contains("现金") { return ratio >= 0.10 && ratio <= 0.45 }
        return ratio >= 0.40 && ratio <= 0.85
    }

    // MARK: 市场脉搏

    private var pulseCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("市场脉搏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(skin.ink)
                Spacer(minLength: 0)
                NavigationLink(value: FHomeRoute.market) {
                    HStack(spacing: 2) {
                        Text("更多").font(.system(size: 10))
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(skin.muted)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(pulseItems) { item in
                    pulseColumn(item)
                }
                if pulseItems.count < 3 {
                    ForEach(Array(0..<(3 - pulseItems.count)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(skin.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(skin.line, lineWidth: 0.8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.marketObservation")
    }

    private func pulseColumn(_ item: FRefPulseItem) -> some View {
        NavigationLink(value: FHomeRoute.marketIndex(item.code)) {
            VStack(spacing: 3) {
                Text(item.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(skin.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.changeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                FRefBang(value: item.change ?? 0, color: item.tone, isLight: skin.isLight)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: 自选监控

    private var watchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("自选监控（\(watchItems.count)）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(skin.ink)
                Spacer(minLength: 0)
                HStack(spacing: 22) {
                    Text("评分").font(.system(size: 9)).foregroundStyle(skin.muted)
                    Text("涨跌幅").font(.system(size: 9)).foregroundStyle(skin.muted)
                }
            }
            if watchItems.isEmpty {
                NavigationLink(value: FHomeRoute.market) {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(skin.accent)
                        Text("在行情页添加自选，这里会显示评分与涨跌幅")
                            .font(.system(size: 10.5))
                            .foregroundStyle(skin.muted)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(watchItems.enumerated()), id: \.element.id) { index, item in
                        watchRow(item)
                        if index < watchItems.count - 1 {
                            Rectangle().fill(skin.line).frame(height: 0.7)
                                .padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(skin.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(skin.line, lineWidth: 0.8))
    }

    private func watchRow(_ item: FRefWatchItem) -> some View {
        NavigationLink(value: FHomeRoute.instrument(item.code)) {
            HStack(spacing: 8) {
                Text("ETF")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(skin.accent.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.code)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(skin.muted)
                        .monospacedDigit()
                    Text(item.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(skin.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if !item.spark.isEmpty {
                    FRefSparkline(values: item.spark, color: item.tone, width: 34, height: 15)
                }
                Text(item.scoreText)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(skin.ink)
                    .frame(width: 26, alignment: .trailing)
                Text(item.changeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.change == nil ? skin.muted : item.tone)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Text("本机账本 · 只做测算与提示，不向券商下单 · 行情带时间戳，评分由本机规则计算")
            .font(.system(size: 9))
            .foregroundStyle(skin.muted.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 1)
    }

    // MARK: 数据

    private var valuation: FPortfolioMarketValuation? {
        // 复用首页已有的估值口径：总资产、持仓市值与当日盈亏都由模型算好。
        if case let .success(value) = model.portfolioMarketValuation(at: Date()) { return value }
        return nil
    }

    private var totalAssets: Decimal? { valuation?.totalAssets }
    private var holdingsMarketValue: Decimal? { valuation?.holdingsMarketValue }
    private var dayChange: Decimal? { valuation?.dayChange }

    private var dayChangePercent: Decimal? {
        guard let dayChange, let totalAssets else { return nil }
        let base = totalAssets - dayChange
        guard base > 0 else { return nil }
        return dayChange / base * 100
    }

    private var cashRatio: Double? {
        guard let totalAssets, let holdings = holdingsMarketValue, totalAssets > 0 else { return nil }
        let cash = totalAssets - holdings
        return max(0, min(1, NSDecimalNumber(decimal: cash / totalAssets).doubleValue))
    }

    private var positionRatio: Double? {
        guard let totalAssets, let holdings = holdingsMarketValue, totalAssets > 0 else { return nil }
        return max(0, min(1, NSDecimalNumber(decimal: holdings / totalAssets).doubleValue))
    }

    private var pulseItems: [FRefPulseItem] {
        let preferred = ["sh000001", "sz399001", "sz399006"]
        var picked: [FMarketIndexQuote] = []
        for code in preferred {
            if let quote = model.marketIndexQuotes.first(where: { $0.code == code && $0.latestPrice != nil }) {
                picked.append(quote)
            }
        }
        if picked.count < 3 {
            for quote in model.marketIndexQuotes where quote.latestPrice != nil && picked.count < 3 {
                if !picked.contains(where: { $0.code == quote.code }) { picked.append(quote) }
            }
        }
        return picked.map { quote in
            let change = quote.changePercent
            let tone: Color = {
                guard let change else { return skin.muted }
                if change > 0 { return skin.up }
                if change < 0 { return skin.down }
                return skin.muted
            }()
            return FRefPulseItem(
                id: quote.code,
                code: quote.code,
                name: shortIndexName(quote.name),
                changeText: change.map { FRefFormat.percent($0) } ?? "—",
                change: change.map { NSDecimalNumber(decimal: $0).doubleValue },
                tone: tone)
        }
    }

    private func shortIndexName(_ name: String) -> String {
        name.replacingOccurrences(of: "指数", with: "")
            .replacingOccurrences(of: "成指", with: "成指")
    }

    private var watchItems: [FRefWatchItem] {
        var codes = model.watchlistCodes
        if codes.isEmpty { codes = model.holdings.map(\.instrumentCode) }
        return codes.prefix(3).map { code in
            let snapshot = model.marketDataByCode[code]
            let latest = snapshot?.latestPrice
            let previous = model.marketReferenceByCode[code]?.previousClose
            let change: Decimal? = {
                guard let latest, let previous, previous > 0 else { return nil }
                return (latest - previous) / previous * 100
            }()
            let tone: Color = {
                guard let change else { return skin.muted }
                if change > 0 { return skin.up }
                if change < 0 { return skin.down }
                return skin.muted
            }()
            let name = model.holdings.first(where: { $0.instrumentCode == code })?.name ?? code
            let rawScore = model.watchlistQuantAssessment(for: code)?.watchlistDirectionalScore
            let scoreText: String = {
                guard let rawScore else { return "—" }
                let mapped = max(0, min(100, 50 + rawScore))
                return "\(mapped)"
            }()
            let spark = snapshot?.samples.suffix(40).map {
                NSDecimalNumber(decimal: $0.price).doubleValue
            } ?? []
            return FRefWatchItem(
                id: code,
                code: code,
                name: name,
                scoreText: scoreText,
                changeText: change.map { FRefFormat.percent($0) } ?? "—",
                change: change.map { NSDecimalNumber(decimal: $0).doubleValue },
                tone: tone,
                spark: Array(spark))
        }
    }
}

// MARK: - 数据小结构

struct FRefPulseItem: Identifiable {
    let id: String
    let code: String
    let name: String
    let changeText: String
    let change: Double?
    let tone: Color
}

struct FRefWatchItem: Identifiable {
    let id: String
    let code: String
    let name: String
    let scoreText: String
    let changeText: String
    let change: Double?
    let tone: Color
    let spark: [Double]
}

// MARK: - 装饰与微型图形

/// 资产卡上的远山剪影：纯装饰，不承载任何数据。
struct FRefBoardTerrain: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.33, y: h * 0.64))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.46))
        path.addLine(to: CGPoint(x: w, y: h * 0.66))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

/// 指数微趋势：以 0 轴居中的短条，长度按涨跌幅占 2% 的比例，不放最大最小值的假折线。
struct FRefBang: View {
    let value: Double
    let color: Color
    let isLight: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let center = width / 2
            let fraction = min(abs(value) / 2.0, 1.0)
            let barWidth = max(1.5, center * fraction)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill((isLight ? Color.black : Color.white).opacity(0.07))
                    .frame(height: 3)
                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: barWidth, height: 3)
                    .offset(x: value >= 0 ? center : center - barWidth)
            }
            .frame(height: geo.size.height, alignment: .center)
        }
    }
}
