import SwiftUI
import FCore

// MARK: - 共用

enum FProFeeModel {
    /// 场内 ETF / LOF 代码段；508/180 是 REITs，交易规则不同，按个股处理更保守。
    static func isExchangeTradedFund(_ code: String) -> Bool {
        let prefixes = ["15", "16", "18", "50", "51", "52", "56", "58", "59"]
        guard prefixes.contains(where: { code.hasPrefix($0) }) else { return false }
        return !(code.hasPrefix("508") || code.hasPrefix("180"))
    }

    static func commission(_ amount: Decimal) -> Decimal {
        max(5, amount * Decimal(string: "0.00025")!)
    }

    /// 卖出：佣金 + 印花税（ETF/LOF 免印花税）。
    static func sellFee(_ amount: Decimal, code: String) -> Decimal {
        let stamp = isExchangeTradedFund(code) ? 0 : amount * Decimal(string: "0.0005")!
        return commission(amount) + stamp
    }
}

private struct FProPageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(FRef.lime)
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(FRef.ink)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(FRef.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

private struct FProNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(FRef.muted.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 网格助手

struct FGridLevel: Identifiable {
    let id: Int
    let buyPrice: Decimal
    let sellPrice: Decimal
    let shares: Int
    let capital: Decimal
    let netProfit: Decimal
}

struct FGridPlan {
    let code: String
    let name: String
    let price: Decimal
    let low: Decimal
    let high: Decimal
    let step: Decimal
    let levels: Int
    let sharesPerLevel: Int
    let capitalPerLevel: Decimal
    let netProfitPerGrid: Decimal
    let cashNeeded: Decimal
    let atr: Decimal
    let rows: [FGridLevel]
    let barsUsed: Int

    var stepPercent: Decimal {
        price > 0 ? step / price * 100 : 0
    }

    var gridYieldPercent: Decimal {
        capitalPerLevel > 0 ? netProfitPerGrid / capitalPerLevel * 100 : 0
    }
}

enum FGridPlanEngine {
    /// 只用真实日 K：区间取最近 N 根的高低点，档距由区间等分，
    /// 每档份额按可用资金与一手 100 份取整。不预测方向、不假装能成交。
    static func plan(code: String, name: String, price: Decimal, bars: [FDailyBar],
                     levels: Int, cash: Decimal, reserveRatio: Decimal) -> FGridPlan? {
        guard price > 0, bars.count >= 20, levels >= 2, levels <= 12 else { return nil }
        let window = Array(bars.suffix(60))
        guard let low = window.map(\.low).min(), let high = window.map(\.high).max(), high > low else { return nil }

        var trueRanges: [Decimal] = []
        for (index, bar) in window.enumerated() where index > 0 {
            let previousClose = window[index - 1].close
            let range = max(bar.high - bar.low, abs(bar.high - previousClose), abs(bar.low - previousClose))
            trueRanges.append(range)
        }
        let atrWindow = Array(trueRanges.suffix(14))
        let atr = atrWindow.isEmpty ? (high - low) / Decimal(levels)
            : atrWindow.reduce(0, +) / Decimal(atrWindow.count)

        let step = (high - low) / Decimal(levels)
        guard step > 0 else { return nil }

        let usableCash = cash * reserveRatio
        let budgetPerLevel = usableCash / Decimal(levels)
        let rawShares = budgetPerLevel / price
        let lots = NSDecimalNumber(decimal: rawShares / 100).intValue
        let shares = max(0, lots * 100)
        let capitalPerLevel = price * Decimal(shares)

        var rows: [FGridLevel] = []
        for index in 0..<levels {
            let buyPrice = high - Decimal(index) * step
            let sellPrice = buyPrice + step
            guard buyPrice > 0 else { continue }
            let buyAmount = buyPrice * Decimal(shares)
            let sellAmount = sellPrice * Decimal(shares)
            let fees = FProFeeModel.commission(buyAmount) + FProFeeModel.sellFee(sellAmount, code: code)
            let profit = sellAmount - buyAmount - fees
            rows.append(FGridLevel(id: index, buyPrice: buyPrice, sellPrice: sellPrice,
                                   shares: shares, capital: buyAmount, netProfit: profit))
        }

        return FGridPlan(code: code, name: name, price: price, low: low, high: high,
                         step: step, levels: levels, sharesPerLevel: shares,
                         capitalPerLevel: capitalPerLevel,
                         netProfitPerGrid: rows.first?.netProfit ?? 0,
                         cashNeeded: capitalPerLevel * Decimal(levels),
                         atr: atr, rows: rows, barsUsed: window.count)
    }
}

struct FGridAssistantView: View {
    @ObservedObject var model: FHomeModel
    @State private var selectedCode = ""
    @State private var levels = 6
    @State private var reservePercent = 60.0

    private var candidates: [FHomeHolding] { model.holdings }

    private var price: Decimal? {
        guard !selectedCode.isEmpty else { return nil }
        return model.marketDataByCode[selectedCode]?.latestPrice
            ?? model.marketReferenceByCode[selectedCode]?.latestPrice
    }

    private var plan: FGridPlan? {
        guard let holding = candidates.first(where: { $0.instrumentCode == selectedCode }),
              let price,
              let bars = model.dailyKlineByCode[selectedCode]?.bars, !bars.isEmpty else { return nil }
        let cash = model.cashBalance ?? 0
        return FGridPlanEngine.plan(code: holding.instrumentCode, name: holding.name,
                                    price: price, bars: bars, levels: levels,
                                    cash: cash, reserveRatio: Decimal(reservePercent / 100))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FProPageHeader(eyebrow: "网格 · 只测算不下单", title: "网格助手",
                               subtitle: "区间取最近 60 根真实日 K 的高低点，档距等分；份额按可用现金和 100 份一手取整，费用按佣金万 2.5（最低 5 元）+ 卖出印花税计算。")
                selectorCard
                if let plan {
                    summaryCard(plan)
                    levelsCard(plan)
                    assumptionCard(plan)
                } else {
                    emptyCard
                }
                FProNotice(text: "网格不是稳赚：跌破区间下沿会满仓被套，涨破上沿会空仓踏空。本页只给出机械测算，成交仍需你在券商自行下单。")
            }
            .padding(16)
        }
        .background(FRefCanvasBackground())
        .navigationTitle("网格助手")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedCode.isEmpty { selectedCode = candidates.first?.instrumentCode ?? "" }
        }
    }

    private var selectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if candidates.isEmpty {
                Text("先在真实账本里录入持仓，网格才有标的。")
                    .font(.system(size: 12)).foregroundStyle(FRef.muted)
            } else {
                Picker("标的", selection: $selectedCode) {
                    ForEach(candidates) { holding in
                        Text("\(holding.name) \(holding.instrumentCode)").tag(holding.instrumentCode)
                    }
                }
                .pickerStyle(.menu)
                .tint(FRef.lime)
                .accessibilityIdentifier("grid.instrument")

                HStack {
                    Text("档数").font(.system(size: 12)).foregroundStyle(FRef.muted)
                    Spacer()
                    Stepper("\(levels) 档", value: $levels, in: 2...12)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FRef.ink)
                        .tint(FRef.lime)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("投入现金比例").font(.system(size: 12)).foregroundStyle(FRef.muted)
                        Spacer()
                        Text("\(Int(reservePercent))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FRef.ink)
                    }
                    Slider(value: $reservePercent, in: 20...100, step: 5).tint(FRef.lime)
                }
                if let price {
                    LabeledContent("现价", value: "¥\(FRefFormat.plain(price, digits: 3))")
                        .font(.system(size: 12))
                }
                LabeledContent("可用现金", value: model.cashBalance.map { FRefFormat.money($0) } ?? "—")
                    .font(.system(size: 12))
            }
        }
        .padding(16)
        .foregroundStyle(FRef.ink)
        .fRefCard()
    }

    private func summaryCard(_ plan: FGridPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(plan.name) · \(plan.code)")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(FRef.ink)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("¥\(FRefFormat.plain(plan.price, digits: 3))")
                    .font(.system(size: 34, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(FRef.ink)
                Text("ATR14 ¥\(FRefFormat.plain(plan.atr, digits: 3))")
                    .font(.system(size: 11)).foregroundStyle(FRef.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric("网格区间", "\(FRefFormat.plain(plan.low, digits: 2)) – \(FRefFormat.plain(plan.high, digits: 2))")
                metric("档距", "¥\(FRefFormat.plain(plan.step, digits: 3)) · \(FRefFormat.plain(plan.stepPercent, digits: 2))%")
                metric("每档份额", "\(plan.sharesPerLevel) 份")
                metric("每档资金", FRefFormat.money(plan.capitalPerLevel))
                metric("单格净利", FRefFormat.money(plan.netProfitPerGrid))
                metric("单格收益率", "\(FRefFormat.plain(plan.gridYieldPercent, digits: 2))%")
                metric("满格占用", FRefFormat.money(plan.cashNeeded))
                metric("样本", "\(plan.barsUsed) 根日 K")
            }
            positionBar(plan)
        }
        .padding(16)
        .fRefCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(FRef.muted)
            Text(value).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                .foregroundStyle(FRef.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func positionBar(_ plan: FGridPlan) -> some View {
        let span = max(plan.high - plan.low, 0.0001)
        let raw = (plan.price - plan.low) / span
        let fraction = min(max(NSDecimalNumber(decimal: raw).doubleValue, 0), 1)
        return VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(FRef.lime).frame(width: max(3, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
            HStack {
                Text("下沿 \(FRefFormat.plain(plan.low, digits: 2))").font(.system(size: 10)).foregroundStyle(FRef.muted)
                Spacer()
                Text("现价位于 \(Int(fraction * 100))%").font(.system(size: 10, weight: .semibold)).foregroundStyle(FRef.ink)
                Spacer()
                Text("上沿 \(FRefFormat.plain(plan.high, digits: 2))").font(.system(size: 10)).foregroundStyle(FRef.muted)
            }
        }
    }

    private func levelsCard(_ plan: FGridPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("挂档表").font(.system(size: 15, weight: .semibold)).foregroundStyle(FRef.ink)
                Spacer()
                Text("自下而上").font(.system(size: 10)).foregroundStyle(FRef.muted)
            }
            HStack {
                Text("买入价").frame(width: 74, alignment: .leading)
                Text("卖出价").frame(width: 74, alignment: .leading)
                Text("份额").frame(width: 54, alignment: .trailing)
                Spacer()
                Text("净利").frame(width: 66, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(FRef.muted)
            ForEach(plan.rows.sorted(by: { $0.buyPrice < $1.buyPrice })) { row in
                HStack {
                    Text(FRefFormat.plain(row.buyPrice, digits: 3))
                        .frame(width: 74, alignment: .leading).foregroundStyle(FRef.ink)
                    Text(FRefFormat.plain(row.sellPrice, digits: 3))
                        .frame(width: 74, alignment: .leading).foregroundStyle(FRef.muted)
                    Text("\(row.shares)")
                        .frame(width: 54, alignment: .trailing).foregroundStyle(FRef.ink)
                    Spacer()
                    Text(FRefFormat.money(row.netProfit))
                        .frame(width: 66, alignment: .trailing)
                        .foregroundStyle(row.netProfit >= 0 ? FRef.up : FRef.down)
                }
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                if row.id < plan.rows.count - 1 {
                    Rectangle().fill(FRef.hairline).frame(height: 1)
                }
            }
        }
        .padding(16)
        .fRefCard()
    }

    private func assumptionCard(_ plan: FGridPlan) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("测算口径").font(.system(size: 12, weight: .semibold)).foregroundStyle(FRef.ink)
            Text("· 区间：最近 \(plan.barsUsed) 根日 K 的最低最低价与最高最高价，不预测突破。")
                .font(.system(size: 11)).foregroundStyle(FRef.muted)
            Text("· 份额：每档 \(plan.sharesPerLevel) 份，\(plan.sharesPerLevel == 0 ? "当前现金不足一手，请降低档数或投入比例。" : "按 100 份一手向下取整。")")
                .font(.system(size: 11)).foregroundStyle(plan.sharesPerLevel == 0 ? FRef.up : FRef.muted)
            Text("· 费用：买卖各收佣金万 2.5（最低 5 元），\(FProFeeModel.isExchangeTradedFund(plan.code) ? "ETF/LOF 免印花税" : "卖出另收 0.05% 印花税")。")
                .font(.system(size: 11)).foregroundStyle(FRef.muted)
            Text("· 未计滑点、冲击成本与分红除权；实际成交价可能长期不触发。")
                .font(.system(size: 11)).foregroundStyle(FRef.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fRefCard()
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还算不出网格")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(FRef.ink)
            Text(price == nil
                 ? "这只标的还没有可信现价。先到行情页刷新一次。"
                 : "需要至少 20 根真实日 K 才能取区间。到标的详情页加载日 K 后回来。")
                .font(.system(size: 12)).foregroundStyle(FRef.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fRefCard()
    }
}

// MARK: - 收息池

struct FDividendEntry: Codable, Identifiable {
    var id: String { code }
    let code: String
    var name: String
    /// 每份每年现金分红（元）。ETF 按每份，个股按每股。
    var dividendPerUnit: Double
}

struct FDividendValuation {
    let entry: FDividendEntry
    let price: Decimal?
    let yieldPercent: Double?
    let targetPrice: Double?
    let percentile: Double?
    let score: Int
    let verdict: String

    var tone: Color {
        if score >= 70 { return FRef.lime }
        if score >= 50 { return Color(red: 0.98, green: 0.72, blue: 0.30) }
        return FRef.muted
    }
}

enum FDividendEngine {
    /// 评分只用两类可解释事实：股息率相对目标的高低（60%），
    /// 现价在最近 60 日区间的位置（40%，越低越好）。
    static func valuation(entry: FDividendEntry, price: Decimal?, bars: [FDailyBar],
                          targetYield: Double) -> FDividendValuation {
        guard let price, price > 0 else {
            return FDividendValuation(entry: entry, price: nil, yieldPercent: nil,
                                      targetPrice: nil, percentile: nil, score: 0,
                                      verdict: "缺现价")
        }
        let priceValue = NSDecimalNumber(decimal: price).doubleValue
        let yieldPercent = entry.dividendPerUnit > 0 ? entry.dividendPerUnit / priceValue * 100 : nil
        let targetPrice = entry.dividendPerUnit > 0 && targetYield > 0
            ? entry.dividendPerUnit / targetYield * 100 : nil

        var percentile: Double?
        let window = Array(bars.suffix(60))
        if window.count >= 20, let low = window.map({ NSDecimalNumber(decimal: $0.low).doubleValue }).min(),
           let high = window.map({ NSDecimalNumber(decimal: $0.high).doubleValue }).max(), high > low {
            percentile = (priceValue - low) / (high - low)
        }

        guard let yieldPercent else {
            return FDividendValuation(entry: entry, price: price, yieldPercent: nil,
                                      targetPrice: nil, percentile: percentile, score: 0,
                                      verdict: "待填分红")
        }
        let yieldScore = min(max(yieldPercent / max(targetYield, 0.1), 0), 1.4) / 1.4 * 60
        let positionScore = (1 - (percentile ?? 0.5)) * 40
        let score = Int((yieldScore + positionScore).rounded())
        let verdict: String
        switch score {
        case 70...: verdict = "值得分批"
        case 50..<70: verdict = "观察等位"
        default: verdict = "偏贵/收益不足"
        }
        return FDividendValuation(entry: entry, price: price, yieldPercent: yieldPercent,
                                  targetPrice: targetPrice, percentile: percentile,
                                  score: score, verdict: verdict)
    }
}

struct FDividendPoolView: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.dividendPool") private var poolRaw = "[]"
    @AppStorage("guanpan.f.dividendTargetYield") private var targetYield = 4.5
    @State private var newCode = ""
    @State private var newDividend = ""
    @State private var status = ""

    private var entries: [FDividendEntry] {
        guard let data = poolRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FDividendEntry].self, from: data) else { return [] }
        return decoded
    }

    private func persist(_ list: [FDividendEntry]) {
        guard let data = try? JSONEncoder().encode(list),
              let raw = String(data: data, encoding: .utf8) else { return }
        poolRaw = raw
    }

    private var valuations: [FDividendValuation] {
        entries.map { entry in
            let price = model.marketDataByCode[entry.code]?.latestPrice
                ?? model.marketReferenceByCode[entry.code]?.latestPrice
            let bars = model.dailyKlineByCode[entry.code]?.bars ?? []
            return FDividendEngine.valuation(entry: entry, price: price, bars: bars, targetYield: targetYield)
        }
        .sorted { $0.score > $1.score }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FProPageHeader(eyebrow: "收息 · 股息率与位置", title: "收息池",
                               subtitle: "股息率 = 你填的每份年度现金分红 ÷ 现价；位置分 = 现价在最近 60 日区间的高低。两项合成 0–100 分，不做「反推你该拿多少股息」那套。")
                targetCard
                addCard
                if valuations.isEmpty {
                    Text("收息池还是空的。把常看的红利 ETF 或高股息个股加进来，填上最近一次年度分红即可评分。")
                        .font(.system(size: 12)).foregroundStyle(FRef.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).fRefCard()
                } else {
                    ForEach(valuations, id: \.entry.code) { valuation in
                        row(valuation)
                    }
                }
                FProNotice(text: "分红数据没有公开稳定接口，本页不自动抓取也不估算：每份分红需要你按基金公告/年报填写。填错会直接算错股息率。ETF 分红会除权，股息率高不等于总回报高。")
            }
            .padding(16)
        }
        .background(FRefCanvasBackground())
        .navigationTitle("收息池")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目标股息率").font(.system(size: 12)).foregroundStyle(FRef.muted)
                Spacer()
                Text("\(FRefFormat.plain(Decimal(targetYield), digits: 1))%")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(FRef.ink)
            }
            Slider(value: $targetYield, in: 2...8, step: 0.5).tint(FRef.lime)
            Text("达到该股息率所需的买入价会显示在每一行；现价低于它才算「到了位置」。")
                .font(.system(size: 10)).foregroundStyle(FRef.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).fRefCard()
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("加入标的").font(.system(size: 14, weight: .semibold)).foregroundStyle(FRef.ink)
            HStack(spacing: 8) {
                TextField("六位代码", text: $newCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("dividend.code")
                TextField("每份年分红", text: $newDividend)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("dividend.amount")
            }
            Button {
                addEntry()
            } label: {
                Text("加入收息池")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FRef.lime.opacity(canAdd ? 1 : 0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(FRef.lime.opacity(canAdd ? 0.7 : 0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
            .accessibilityIdentifier("dividend.add")
            if !status.isEmpty {
                Text(status).font(.system(size: 10)).foregroundStyle(FRef.muted)
            }
            if !model.watchlistCodes.isEmpty {
                Text("从自选快速加入").font(.system(size: 10)).foregroundStyle(FRef.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.watchlistCodes, id: \.self) { code in
                            Button {
                                newCode = code
                                status = "已填入 \(code)，请补每份年分红"
                            } label: {
                                Text(code)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FRef.ink)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.white.opacity(0.05), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16).fRefCard()
    }

    private var canAdd: Bool {
        guard newCode.count == 6, let amount = Double(newDividend) else { return false }
        return amount > 0
    }

    private func addEntry() {
        guard let amount = Double(newDividend), amount > 0, newCode.count == 6 else { return }
        let name = model.holdings.first(where: { $0.instrumentCode == newCode })?.name ?? newCode
        var list = entries.filter { $0.code != newCode }
        list.append(FDividendEntry(code: newCode, name: name, dividendPerUnit: amount))
        persist(list)
        status = "已加入 \(name) \(newCode)"
        newCode = ""
        newDividend = ""
    }

    private func row(_ valuation: FDividendValuation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(valuation.entry.name)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(FRef.ink).lineLimit(1)
                    Text("\(valuation.entry.code) · 每份分红 \(FRefFormat.plain(Decimal(valuation.entry.dividendPerUnit), digits: 3))")
                        .font(.system(size: 10)).foregroundStyle(FRef.muted)
                }
                Spacer(minLength: 0)
                Text("\(valuation.score)")
                    .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(valuation.tone)
                Text("分").font(.system(size: 10)).foregroundStyle(FRef.muted)
            }
            HStack(spacing: 14) {
                detail("现价", valuation.price.map { "¥\(FRefFormat.plain($0, digits: 3))" } ?? "—")
                detail("股息率", valuation.yieldPercent.map { "\(FRefFormat.plain(Decimal($0), digits: 2))%" } ?? "待填")
                detail("目标买价", valuation.targetPrice.map { "¥\(FRefFormat.plain(Decimal($0), digits: 3))" } ?? "—")
                detail("60日位置", valuation.percentile.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
            }
            HStack(spacing: 6) {
                Text(valuation.verdict)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(valuation.tone)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().stroke(valuation.tone.opacity(0.6), lineWidth: 0.8))
                Spacer()
                Button {
                    persist(entries.filter { $0.code != valuation.entry.code })
                } label: {
                    Text("移除").font(.system(size: 10)).foregroundStyle(FRef.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .fRefCard()
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 9)).foregroundStyle(FRef.muted)
            Text(value).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(FRef.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 跑赢基准

private struct FBenchmarkDay: Codable, Identifiable {
    var id: String { day }
    let day: String
    let portfolioPercent: Double
    let indexPercent: Double
}

struct FBenchmarkView: View {
    @ObservedObject var model: FHomeModel
    @AppStorage("guanpan.f.benchmarkHistory") private var historyRaw = "[]"

    private var history: [FBenchmarkDay] {
        guard let data = historyRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FBenchmarkDay].self, from: data) else { return [] }
        return decoded.sorted { $0.day < $1.day }
    }

    private var indexQuote: FMarketIndexQuote? {
        model.marketIndexQuotes.first { $0.code == "sh000001" }
    }

    private var todayPortfolioPercent: Double? {
        var change: Decimal = 0
        var base: Decimal = 0
        var covered = false
        for holding in model.holdings {
            guard let latest = model.marketDataByCode[holding.instrumentCode]?.latestPrice
                    ?? model.marketReferenceByCode[holding.instrumentCode]?.latestPrice,
                  let previous = model.marketReferenceByCode[holding.instrumentCode]?.previousClose,
                  previous > 0 else { continue }
            change += (latest - previous) * Decimal(holding.units)
            base += previous * Decimal(holding.units)
            covered = true
        }
        guard covered, base > 0 else { return nil }
        return NSDecimalNumber(decimal: change / base).doubleValue * 100
    }

    private var todayIndexPercent: Double? {
        guard let value = indexQuote?.changePercent else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FProPageHeader(eyebrow: "基准 · 每天一比", title: "跑赢基准",
                               subtitle: "组合当日收益按每只持仓「现价 − 昨收」加权计算，现金不产生波动；基准取上证指数当日涨跌幅。每天打开就记一条，逐步攒出真实的超额曲线。")
                todayCard
                if history.count >= 2 { historyCard } else { seedCard }
                if !history.isEmpty { recentCard }
                FProNotice(text: "口径说明：这里只比较当日价格波动，不剔除申赎与转账带来的现金变化（当日买卖会让权重在盘中变化）；因此它是「今天赚得比指数多吗」的近似，不是基金净值式的严格归因。历史从本版第一次记录开始，不回溯补造。")
            }
            .padding(16)
        }
        .background(FRefCanvasBackground())
        .navigationTitle("跑赢基准")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { recordToday() }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日").font(.system(size: 12)).foregroundStyle(FRef.muted)
            HStack(alignment: .top, spacing: 12) {
                bigMetric("组合", todayPortfolioPercent)
                bigMetric("上证", todayIndexPercent)
                bigMetric("超额", excess(todayPortfolioPercent, todayIndexPercent))
            }
            if let portfolio = todayPortfolioPercent, let index = todayIndexPercent {
                let excessValue = portfolio - index
                Text(excessValue >= 0
                     ? "今天比上证多赚 \(FRefFormat.plain(Decimal(abs(excessValue)), digits: 2)) 个百分点。"
                     : "今天比上证少赚 \(FRefFormat.plain(Decimal(abs(excessValue)), digits: 2)) 个百分点。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(excessValue >= 0 ? FRef.up : FRef.down)
            } else {
                Text("还差 持仓昨收 或 上证当日涨跌，先把行情页刷新一次。")
                    .font(.system(size: 12)).foregroundStyle(FRef.muted)
            }
        }
        .padding(16).fRefCard()
    }

    private func bigMetric(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10)).foregroundStyle(FRef.muted)
            Text(value.map { FRefFormat.percent(Decimal($0)) } ?? "—")
                .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                .foregroundStyle(value == nil ? FRef.muted : ((value ?? 0) >= 0 ? FRef.up : FRef.down))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func excess(_ portfolio: Double?, _ index: Double?) -> Double? {
        guard let portfolio, let index else { return nil }
        return portfolio - index
    }

    private var cumulative: (portfolio: Double, index: Double)? {
        guard !history.isEmpty else { return nil }
        var p = 1.0
        var i = 1.0
        for day in history {
            p *= (1 + day.portfolioPercent / 100)
            i *= (1 + day.indexPercent / 100)
        }
        return ((p - 1) * 100, (i - 1) * 100)
    }

    private var winRate: Double? {
        guard !history.isEmpty else { return nil }
        let wins = history.filter { $0.portfolioPercent > $0.indexPercent }.count
        return Double(wins) / Double(history.count) * 100
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("累计（\(history.count) 个记录日）")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(FRef.ink)
            if let cumulative {
                HStack(spacing: 12) {
                    bigMetric("组合", cumulative.portfolio)
                    bigMetric("上证", cumulative.index)
                    bigMetric("超额", cumulative.portfolio - cumulative.index)
                }
            }
            if let winRate {
                Text("胜率 \(FRefFormat.plain(Decimal(winRate), digits: 0))%（\(history.filter { $0.portfolioPercent > $0.indexPercent }.count)/\(history.count) 天）")
                    .font(.system(size: 11)).foregroundStyle(FRef.muted)
            }
            excessChart
        }
        .padding(16).fRefCard()
    }

    /// 超额收益柱：零轴上红（跑赢）下绿（跑输），与 A 股口径一致。
    private var excessChart: some View {
        let rows = Array(history.suffix(20))
        let values = rows.map { $0.portfolioPercent - $0.indexPercent }
        let peak = max(values.map { abs($0) }.max() ?? 1, 0.01)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width / CGFloat(max(rows.count, 1))
                ZStack(alignment: .center) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { _, day in
                            let value = day.portfolioPercent - day.indexPercent
                            let ratio = abs(value) / peak
                            let barHeight = max(2, geo.size.height / 2 * CGFloat(ratio))
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(value >= 0 ? FRef.up : FRef.down)
                                    .frame(width: max(2, width * 0.55), height: barHeight)
                            }
                        }
                    }
                }
            }
            .frame(height: 56)
            HStack {
                Text(rows.first?.day ?? "").font(.system(size: 9)).foregroundStyle(FRef.muted)
                Spacer()
                Text(rows.last?.day ?? "").font(.system(size: 9)).foregroundStyle(FRef.muted)
            }
        }
    }

    private var seedCard: some View {
        Text("只有 1 条记录，还画不出曲线。明天收盘后再打开一次，就会开始累计；记录只存在本机。")
            .font(.system(size: 12)).foregroundStyle(FRef.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).fRefCard()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("最近记录").font(.system(size: 13, weight: .semibold)).foregroundStyle(FRef.ink)
            ForEach(history.suffix(7).reversed()) { day in
                HStack {
                    Text(day.day).font(.system(size: 11)).foregroundStyle(FRef.muted)
                    Spacer()
                    Text(FRefFormat.percent(Decimal(day.portfolioPercent)))
                        .font(.system(size: 11, weight: .medium)).monospacedDigit()
                        .foregroundStyle(day.portfolioPercent >= 0 ? FRef.up : FRef.down)
                    Text("vs").font(.system(size: 9)).foregroundStyle(FRef.muted)
                    Text(FRefFormat.percent(Decimal(day.indexPercent)))
                        .font(.system(size: 11, weight: .medium)).monospacedDigit()
                        .foregroundStyle(day.indexPercent >= 0 ? FRef.up : FRef.down)
                    Text(FRefFormat.percent(Decimal(day.portfolioPercent - day.indexPercent)))
                        .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(day.portfolioPercent - day.indexPercent >= 0 ? FRef.up : FRef.down)
                        .frame(width: 62, alignment: .trailing)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(16).fRefCard()
    }

    private func recordToday() {
        guard let portfolio = todayPortfolioPercent, let index = todayIndexPercent else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        let day = formatter.string(from: Date())
        var list = history.filter { $0.day != day }
        list.append(FBenchmarkDay(day: day, portfolioPercent: portfolio, indexPercent: index))
        list.sort { $0.day < $1.day }
        if let data = try? JSONEncoder().encode(Array(list.suffix(250))),
           let raw = String(data: data, encoding: .utf8) {
            historyRaw = raw
        }
    }
}
