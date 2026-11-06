import SwiftUI
import FCore
import FAdvisor

/// 参考稿（Dribbble / Fintech Mobile App）的视觉常量。
/// 只服务 `FHomeTheme.referenceDark`：近黑画布、悬浮暗卡、柠檬绿强调、
/// 超大资产数字、橙粉紫蓝渐变 AI 卡、纯图标底栏 + 中央悬浮球。
enum FRef {
    static let canvas = Color(red: 0.043, green: 0.043, blue: 0.051)   // #0B0B0D
    static let card = Color(red: 0.082, green: 0.082, blue: 0.090)     // #151517
    static let raised = Color(red: 0.110, green: 0.110, blue: 0.122)   // #1C1C1F
    static let ink = Color(red: 0.960, green: 0.960, blue: 0.970)
    static let muted = Color(red: 0.545, green: 0.545, blue: 0.580)
    static let lime = Color(red: 0.784, green: 0.969, blue: 0.318)     // #C8F751
    /// 国内口径：红涨绿跌。
    static let up = Color(red: 1.000, green: 0.400, blue: 0.400)
    static let down = Color(red: 0.280, green: 0.820, blue: 0.560)
    static let hairline = Color.white.opacity(0.07)
    static let gradient = [
        Color(red: 0.949, green: 0.627, blue: 0.239),
        Color(red: 0.914, green: 0.361, blue: 0.549),
        Color(red: 0.553, green: 0.361, blue: 0.953),
        Color(red: 0.231, green: 0.510, blue: 0.965)
    ]
    static let avatarGradients: [[Color]] = [
        [Color(red: 0.35, green: 0.62, blue: 0.98), Color(red: 0.55, green: 0.36, blue: 0.95)],
        [Color(red: 0.95, green: 0.63, blue: 0.24), Color(red: 0.91, green: 0.36, blue: 0.55)],
        [Color(red: 0.20, green: 0.80, blue: 0.65), Color(red: 0.10, green: 0.55, blue: 0.75)],
        [Color(red: 0.85, green: 0.42, blue: 0.75), Color(red: 0.45, green: 0.30, blue: 0.85)]
    ]
}

enum FRefFormat {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    static func money(_ value: Decimal) -> String {
        currencyFormatter.string(from: NSNumber(value: double(value))) ?? "—"
    }

    static func money(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return money(value)
    }

    static func signedMoney(_ value: Decimal) -> String {
        let text = money(abs(value))
        return (value >= 0 ? "+" : "-") + text
    }

    static func plain(_ value: Decimal, digits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: double(value))) ?? "—"
    }

    static func percent(_ value: Decimal, digits: Int = 2) -> String {
        let text = plain(abs(value), digits: digits)
        return (value >= 0 ? "+" : "-") + text + "%"
    }
}

private struct FRefCardModifier: ViewModifier {
    var radius: CGFloat = 22
    var fill: Color = FRef.card

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(FRef.hairline, lineWidth: 1))
    }
}

extension View {
    func fRefCard(radius: CGFloat = 22, fill: Color = FRef.card) -> some View {
        modifier(FRefCardModifier(radius: radius, fill: fill))
    }
}

struct FRefSparkline: View {
    let values: [Double]
    let color: Color
    var width: CGFloat = 58
    var height: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let resolved = values.count > 1 ? values : [0, 0]
            let minimum = resolved.min() ?? 0
            let maximum = resolved.max() ?? 1
            let span = max(maximum - minimum, 0.0001)
            Path { path in
                for (index, value) in resolved.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(resolved.count - 1, 1))
                    let normalized = (value - minimum) / span
                    let y = geo.size.height * (1 - CGFloat(normalized))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

private struct FRefRing: View {
    let fraction: Double
    var size: CGFloat = 42
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.09), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(FRef.lime, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(FRef.ink)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

struct FReferenceHome: View {
    @ObservedObject var model: FHomeModel

    private var valuation: FPortfolioMarketValuation? {
        if case .success(let value) = model.portfolioMarketValuation(at: Date()) { return value }
        return nil
    }

    private var totalAssets: Decimal? { valuation?.totalAssets }

    private var holdingsMarketValue: Decimal? {
        if let valuation { return valuation.holdingsMarketValue }
        return nil
    }

    private func price(_ code: String) -> Decimal? {
        model.marketDataByCode[code]?.latestPrice ?? model.marketReferenceByCode[code]?.latestPrice
    }

    private func previousClose(_ code: String) -> Decimal? {
        model.marketReferenceByCode[code]?.previousClose
    }

    /// 只用「现价 − 昨收」× 份额，逐项可加；缺昨收的标的直接不参与，不做估算。
    private var dayChange: Decimal? {
        var total: Decimal = 0
        var covered = false
        for holding in model.holdings {
            guard let latest = price(holding.instrumentCode),
                  let previous = previousClose(holding.instrumentCode), previous > 0 else { continue }
            total += (latest - previous) * Decimal(holding.units)
            covered = true
        }
        return covered ? total : nil
    }

    private var dayChangePercent: Decimal? {
        guard let dayChange, let totalAssets else { return nil }
        let base = totalAssets - dayChange
        guard base > 0 else { return nil }
        return dayChange / base * 100
    }

    private var focusedRows: [FHomeHolding] {
        Array(model.holdings.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            greeting
            balanceCard
            statTiles
            insightCard
            quickActions
            holdingsSection
            distributionCard
            marketCard
            crossMarketStrip
            footer
        }
    }

    // MARK: - 顶部问候

    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("欢迎回来")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(FRef.ink)
                Text("\(Date().formatted(date: .abbreviated, time: .omitted)) · 本机真实账本")
                    .font(.system(size: 12))
                    .foregroundStyle(FRef.muted)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(LinearGradient(colors: FRef.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("观").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
            .accessibilityHidden(true)
        }
        .padding(.top, 4)
    }

    // MARK: - 资产大卡

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("总资产")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FRef.muted)
                Spacer(minLength: 0)
                NavigationLink(value: FHomeRoute.portfolio) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FRef.ink)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: Circle())
                        .overlay(Circle().stroke(FRef.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.reference.assets.open")
            }
            Text(FRefFormat.money(totalAssets))
                .font(.system(size: 40, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(FRef.ink)
            if let dayChange {
                HStack(spacing: 5) {
                    Image(systemName: dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(FRefFormat.signedMoney(dayChange))
                    Text("(\(dayChangePercent.map { FRefFormat.percent($0) } ?? "—"))")
                        .opacity(0.9)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(dayChange >= 0 ? FRef.up : FRef.down)
            } else {
                Text("今日涨跌需要每只持仓的昨收价，暂未取齐")
                    .font(.system(size: 11))
                    .foregroundStyle(FRef.muted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fRefCard(radius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.portfolio")
    }

    private var statTiles: some View {
        HStack(spacing: 10) {
            statTile(title: "持仓市值", value: FRefFormat.money(holdingsMarketValue),
                     symbol: "chart.pie.fill")
            statTile(title: "可用现金", value: model.cashBalance.map { FRefFormat.money($0) } ?? "—",
                     symbol: "banknote.fill")
        }
    }

    private func statTile(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FRef.ink)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11)).foregroundStyle(FRef.muted).lineLimit(1)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(FRef.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fRefCard(radius: 18)
    }

    // MARK: - AI 渐变卡

    private var insightCard: some View {
        NavigationLink(value: FHomeRoute.advisor) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.22))
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 洞察")
                        .font(.system(size: 15, weight: .semibold))
                    Text(advisorSubtitle)
                        .font(.system(size: 11))
                        .opacity(0.92)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: FRef.gradient, startPoint: .leading, endPoint: .trailing))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.advisorGuidance")
    }

    private var advisorSubtitle: String {
        if model.ledgerState != .available { return "先建立真实账本，再给出组合判断" }
        if let result = model.advisorResult {
            return "今日判断已生成 · \(result.generatedAt.formatted(date: .omitted, time: .shortened))"
        }
        return model.isAskingAdvisor ? "正在结合持仓与行情分析" : "结合持仓、行情与新闻，给出今日动作"
    }

    // MARK: - 快捷入口（三个 Pro 工具）

    private var quickActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                FGridAssistantView(model: model)
            } label: {
                actionTile(title: "网格", symbol: "square.grid.3x3.fill", badge: "新")
            }
            .buttonStyle(.plain)

            NavigationLink {
                FDividendPoolView(model: model)
            } label: {
                actionTile(title: "收息", symbol: "banknote.on.circle", badge: nil)
            }
            .buttonStyle(.plain)

            NavigationLink {
                FBenchmarkView(model: model)
            } label: {
                actionTile(title: "基准", symbol: "chart.line.uptrend.xyaxis", badge: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionTile(title: String, symbol: String, badge: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FRef.ink)
                .frame(height: 22)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FRef.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .fRefCard(radius: 18)
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(FRef.lime)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(FRef.lime.opacity(0.7), lineWidth: 0.8))
                    .padding(7)
            }
        }
    }

    // MARK: - 持仓

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("持仓")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FRef.ink)
                Spacer()
                NavigationLink(value: FHomeRoute.portfolio) {
                    Text("全部").font(.system(size: 12, weight: .medium)).foregroundStyle(FRef.muted)
                }
                .buttonStyle(.plain)
            }
            if focusedRows.isEmpty {
                Text(model.ledgerState == .available
                     ? "账本里还没有持仓。录入已成交买入后，这里会显示真实成本与今日涨跌。"
                     : model.ledgerStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(FRef.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .fRefCard(radius: 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(focusedRows.enumerated()), id: \.element.id) { index, holding in
                        holdingRow(holding, index: index)
                        if index < focusedRows.count - 1 {
                            Rectangle().fill(FRef.hairline).frame(height: 1).padding(.leading, 60)
                        }
                    }
                }
                .fRefCard(radius: 22)
            }
        }
    }

    private func holdingRow(_ holding: FHomeHolding, index: Int) -> some View {
        let latest = price(holding.instrumentCode)
        let previous = previousClose(holding.instrumentCode)
        let marketValue = latest.map { $0 * Decimal(holding.units) }
        let changePercent: Decimal? = {
            guard let latest, let previous, previous > 0 else { return nil }
            return (latest - previous) / previous * 100
        }()
        let tone = (changePercent ?? 0) >= 0 ? FRef.up : FRef.down
        let closes = model.dailyKlineByCode[holding.instrumentCode]?.bars.suffix(24).map {
            NSDecimalNumber(decimal: $0.close).doubleValue
        } ?? []

        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(LinearGradient(colors: FRef.avatarGradients[index % FRef.avatarGradients.count],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(String(holding.name.prefix(1)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FRef.ink)
                    .lineLimit(1)
                Text("\(holding.instrumentCode) · \(holding.units) 份")
                    .font(.system(size: 11))
                    .foregroundStyle(FRef.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if closes.count > 1 {
                FRefSparkline(values: closes, color: tone)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(FRefFormat.money(marketValue))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(FRef.ink)
                    .lineLimit(1)
                Text(changePercent.map { FRefFormat.percent($0) } ?? "—")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(changePercent == nil ? FRef.muted : tone)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - 持仓分布（环形占比）

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("持仓分布")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FRef.ink)
                Spacer()
                Text("按市值")
                    .font(.system(size: 11))
                    .foregroundStyle(FRef.muted)
            }
            if model.holdings.isEmpty {
                Text("暂无持仓可分配。").font(.system(size: 12)).foregroundStyle(FRef.muted)
            } else {
                let base = holdingsMarketValue ?? 0
                ForEach(Array(model.holdings.prefix(4).enumerated()), id: \.element.id) { _, holding in
                    let value = price(holding.instrumentCode).map { $0 * Decimal(holding.units) }
                    let fraction = (base > 0 ? (value ?? 0) / base : 0)
                    HStack(spacing: 12) {
                        FRefRing(fraction: NSDecimalNumber(decimal: fraction).doubleValue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holding.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FRef.ink)
                                .lineLimit(1)
                            Text("\(holding.units) 份持仓")
                                .font(.system(size: 11))
                                .foregroundStyle(FRef.muted)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(FRefFormat.money(value))
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(FRef.ink)
                            Text(percentText(fraction))
                                .font(.system(size: 11))
                                .foregroundStyle(FRef.muted)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fRefCard(radius: 22)
    }

    private func percentText(_ fraction: Decimal) -> String {
        let percent = fraction * 100
        return "\(FRefFormat.plain(percent, digits: 1))%"
    }

    // MARK: - 市场

    private var marketCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("市场脉搏")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FRef.ink)
                Spacer()
                NavigationLink(value: FHomeRoute.market) {
                    Text("查看").font(.system(size: 11, weight: .medium)).foregroundStyle(FRef.muted)
                }
                .buttonStyle(.plain)
            }
            let quotes = Array(model.marketIndexQuotes.prefix(3))
            if quotes.isEmpty {
                Text("指数行情尚未读取。").font(.system(size: 12)).foregroundStyle(FRef.muted)
            } else {
                ForEach(quotes) { quote in
                    NavigationLink(value: FHomeRoute.marketIndex(quote.code)) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quote.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FRef.ink)
                                    .lineLimit(1)
                                Text(quote.observedAt?.formatted(date: .omitted, time: .shortened) ?? "无时间戳")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FRef.muted)
                            }
                            Spacer(minLength: 0)
                            Text(quote.latestPrice.map { FRefFormat.plain($0) } ?? "—")
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(FRef.ink)
                            Text(quote.changePercent.map { FRefFormat.percent($0) } ?? "—")
                                .font(.system(size: 11, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle((quote.changePercent ?? 0) >= 0 ? FRef.up : FRef.down)
                                .frame(width: 62, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fRefCard(radius: 22)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.marketObservation")
    }

    private var crossMarketStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("跨市场")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FRef.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.marketIndexQuotes.filter { $0.market != "中国" }) { quote in
                        HStack(spacing: 6) {
                            Text(quote.name).font(.system(size: 11, weight: .medium)).foregroundStyle(FRef.ink)
                            Text(quote.changePercent.map { FRefFormat.percent($0) } ?? "—")
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle((quote.changePercent ?? 0) >= 0 ? FRef.up : FRef.down)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .fRefCard(radius: 14)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.role.crossMarketPulse")
    }

    private var footer: some View {
        Text("本机账本 · 只做测算与提示，不向券商下单 · 估值仅使用带时间戳的真实行情")
            .font(.system(size: 10))
            .foregroundStyle(FRef.muted.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }
}
