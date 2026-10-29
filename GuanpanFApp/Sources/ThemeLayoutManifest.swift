import SwiftUI

enum FHomeLayoutFamily: String, CaseIterable, Identifiable {
    case editorial, cardGrid, terminalDashboard, magazine, staticBento
    case inkEditorial, minimalTerminal, spatialGlass, radialMap, adaptiveBento

    var id: String { rawValue }
}

enum FHomeCardRole: String, CaseIterable, Identifiable {
    case portfolio, marketObservation, crossMarketPulse, advisorGuidance

    var id: String { rawValue }

    var route: FHomeRoute {
        switch self {
        case .portfolio: .portfolio
        case .marketObservation: .market
        case .crossMarketPulse: .crossMarket
        case .advisorGuidance: .advisor
        }
    }

    var title: String {
        switch self {
        case .portfolio: "真实资产"
        case .marketObservation: "今日市场观察"
        case .crossMarketPulse: "跨市场脉搏"
        case .advisorGuidance: "AI 今日指导"
        }
    }

    var detail: String {
        switch self {
        case .portfolio: "本机 Ledger 的持仓与现金"
        case .marketObservation: "行情、时点、来源与质量"
        case .crossMarketPulse: "跨市场行情与研究 · NAS 可选增强"
        case .advisorGuidance: "组合上下文、风险与建议"
        }
    }

    var symbol: String {
        switch self {
        case .portfolio: "briefcase"
        case .marketObservation: "chart.xyaxis.line"
        case .crossMarketPulse: "globe.asia.australia"
        case .advisorGuidance: "sparkles"
        }
    }
}

enum FThemeSurfaceTreatment: String {
    case editorial, card, terminal, magazine, bento, ink, minimal, glass, orbit, adaptive
}

enum FThemeMotionLevel: String { case reduced, subtle, spatial }
struct FThemeSpacingScale {
    let compact: CGFloat
    let standard: CGFloat
    let spacious: CGFloat
}

struct FThemeSemanticTokens {
    let background: Color
    let surface: Color
    let foreground: Color
    let secondaryForeground: Color
    let accent: Color
    let positive: Color
    let negative: Color
    let risk: Color
    let warning: Color
    let unavailable: Color
    let partial: Color
    let candidate: Color
    let buyPoint: Color
    let sellPoint: Color
    let episodeCost: Color
    let brokerCost: Color
    let intradayAverage: Color
    let movingAverages: [Color]
    let iopv: Color
    let surfaceTreatment: FThemeSurfaceTreatment
    let spacing: FThemeSpacingScale
}

struct FLayoutManifest: Identifiable {
    let family: FHomeLayoutFamily
    let informationDensity: String
    let description: String
    let roleOrder: [FHomeCardRole]
    let reordersForLocalRiskState: Bool

    var id: String { family.rawValue }
}

struct FThemeManifest: Identifiable {
    let theme: FHomeTheme
    let name: String
    let layout: FLayoutManifest
    let useCase: String
    let typography: String
    let navigationPresentation: String
    let advisorPresentation: String
    let marketPresentation: String
    let assetPresentation: String
    let chartContainerPresentation: String
    let motion: FThemeMotionLevel
    let appearanceCompatibility: String
    let tokens: FThemeSemanticTokens

    var id: String { theme.rawValue }
}

enum FThemeLayoutRegistry {
    static let roleOrder: [FHomeCardRole] = [
        .portfolio, .marketObservation, .crossMarketPulse, .advisorGuidance
    ]

    static func layout(_ family: FHomeLayoutFamily) -> FLayoutManifest {
        let descriptions: [FHomeLayoutFamily: (String, String, Bool)] = [
            .editorial: ("舒展", "问候与市场先览开篇，随后呈现组合顾问、跨市场观察和真实持仓。", false),
            .cardGrid: ("均衡", "两列卡片网格并列展示市场、研究、顾问与资产入口。", false),
            .terminalDashboard: ("紧凑", "现金、行情和决策入口采用紧凑终端层级。", false),
            .magazine: ("舒展", "日期与专题标题先行，随后以长篇章节呈现组合和研究。", false),
            .staticBento: ("中等", "固定大小模块组成拼图，突出资产与AI指导。", false),
            .inkEditorial: ("宽松", "留白、墨色标题与朱砂强调组织成现代财经编辑版面。", false),
            .minimalTerminal: ("高密度", "弱卡片、分割线和数字流构成紧凑行情终端。", false),
            .spatialGlass: ("中等", "AI指导居中，玻璃表面和层叠空间组织信息。", false),
            .radialMap: ("节点式", "AI与真实资产位于中心，市场和研究以外围节点连接。", false),
            .adaptiveBento: ("自适应", "按本地账本可用性与Guard状态确定性调整模块面积。", true)
        ]
        let value = descriptions[family] ?? ("均衡", "共享业务角色布局。", false)
        let order: [FHomeCardRole]
        switch family {
        case .editorial:
            order = [.marketObservation, .advisorGuidance, .crossMarketPulse, .portfolio]
        case .inkEditorial, .magazine, .spatialGlass:
            order = [.advisorGuidance, .portfolio, .marketObservation, .crossMarketPulse]
        case .cardGrid:
            order = [.marketObservation, .crossMarketPulse, .portfolio, .advisorGuidance]
        case .terminalDashboard:
            order = [.portfolio, .marketObservation, .crossMarketPulse, .advisorGuidance]
        case .minimalTerminal:
            order = [.marketObservation, .portfolio, .advisorGuidance, .crossMarketPulse]
        case .radialMap:
            order = [.portfolio, .advisorGuidance, .marketObservation, .crossMarketPulse]
        default:
            order = roleOrder
        }
        return FLayoutManifest(family: family, informationDensity: value.0,
                               description: value.1, roleOrder: order,
                               reordersForLocalRiskState: value.2)
    }

    static func manifest(for theme: FHomeTheme) -> FThemeManifest {
        let family = theme.layoutFamily
        let style = theme.surfaceTreatment
        let isDark = theme == .dashboard
        let background: Color
        let surface: Color
        switch theme {
        case .editorial:
            background = Color(red: 0.965, green: 0.953, blue: 0.925)
            surface = Color(red: 0.995, green: 0.988, blue: 0.968)
        case .modern:
            background = Color(red: 0.942, green: 0.955, blue: 0.972)
            surface = Color(red: 0.990, green: 0.995, blue: 1.0)
        case .dashboard:
            background = Color(red: 0.075, green: 0.10, blue: 0.15)
            surface = Color(red: 0.12, green: 0.16, blue: 0.23)
        case .magazine:
            background = Color(red: 0.975, green: 0.947, blue: 0.914)
            surface = Color(red: 1.0, green: 0.982, blue: 0.953)
        case .bento, .adaptiveBento:
            background = Color(red: 0.935, green: 0.957, blue: 0.935)
            surface = Color(red: 0.985, green: 0.995, blue: 0.980)
        case .inkModern:
            background = Color(red: 0.956, green: 0.944, blue: 0.911)
            surface = Color(red: 0.992, green: 0.982, blue: 0.955)
        case .minimalTerminal:
            background = Color(red: 0.925, green: 0.944, blue: 0.953)
            surface = Color(red: 0.976, green: 0.986, blue: 0.989)
        case .fluidGlass:
            background = Color(red: 0.913, green: 0.933, blue: 0.968)
            surface = Color(red: 0.979, green: 0.987, blue: 1.0)
        case .dataStarMap:
            background = Color(red: 0.936, green: 0.925, blue: 0.963)
            surface = Color(red: 0.989, green: 0.984, blue: 1.0)
        }
        let foreground: Color = isDark ? Color(red: 0.91, green: 0.93, blue: 0.96) : Color(red: 0.12, green: 0.15, blue: 0.19)
        let accent: Color
        switch theme {
        case .editorial, .inkModern: accent = Color(red: 0.68, green: 0.29, blue: 0.18)
        case .modern: accent = Color(red: 0.18, green: 0.39, blue: 0.82)
        case .dashboard: accent = Color(red: 0.26, green: 0.78, blue: 0.81)
        case .magazine: accent = Color(red: 0.69, green: 0.27, blue: 0.19)
        case .bento, .adaptiveBento: accent = Color(red: 0.28, green: 0.49, blue: 0.35)
        case .minimalTerminal: accent = Color(red: 0.52, green: 0.78, blue: 0.88)
        case .fluidGlass: accent = Color(red: 0.42, green: 0.61, blue: 0.93)
        case .dataStarMap: accent = Color(red: 0.76, green: 0.67, blue: 0.95)
        }
        let name: String
        let useCase: String
        let typography: String
        let navigation: String
        let advisor: String
        let market: String
        let assets: String
        let chart: String
        switch theme {
        case .editorial:
            name = "东方编辑室"; useCase = "阅读市场、组合与建议的日常首页。"; typography = "编辑式衬线标题 + 清晰数字"
            navigation = "标准底部导航"; advisor = "组合顾问输入置顶"; market = "章节入口"; assets = "组合摘要卡片"; chart = "纸感外围面板"
        case .modern:
            name = "现代卡片"; useCase = "快速浏览多个独立信息入口。"; typography = "现代无衬线"; navigation = "标准底部导航"
            advisor = "输入与快捷问题卡片"; market = "两列摘要卡片"; assets = "持仓列表摘要"; chart = "标准卡片容器"
        case .dashboard:
            name = "交易仪表盘"; useCase = "偏好紧凑行情与现金指标的用户。"; typography = "等宽数字优先"; navigation = "深色紧凑导航"
            advisor = "数据台内的决策入口"; market = "紧凑行情入口"; assets = "现金/持仓头部指标"; chart = "暗色终端面板"
        case .magazine:
            name = "杂志卡片"; useCase = "按专题阅读组合和市场信息。"; typography = "大标题 + 章节副标题"; navigation = "标准底部导航"
            advisor = "顾问专栏"; market = "专题章节"; assets = "头版组合摘要"; chart = "杂志版面容器"
        case .bento:
            name = "创意拼图"; useCase = "同时查看资产、行情与AI入口。"; typography = "分级标题与数字"; navigation = "标准底部导航"
            advisor = "宽幅顾问模块"; market = "独立网格单元"; assets = "大尺寸组合单元"; chart = "拼图式边框容器"
        case .inkModern:
            name = "东方墨韵"; useCase = "偏好留白与现代东方财经编辑表达。"; typography = "墨色标题 + 朱砂数字强调"; navigation = "轻量文字导航"
            advisor = "今日主笔摘要"; market = "章节式观察栏"; assets = "编辑式资产摘要"; chart = "无边框纸面区"
        case .minimalTerminal:
            name = "极简终端"; useCase = "偏好高密度、少装饰的行情阅读。"; typography = "等宽数字 + 细字号层级"; navigation = "紧凑终端导航"
            advisor = "直接进入数据流"; market = "表格式行情流"; assets = "单行账户摘要"; chart = "平面细分割容器"
        case .fluidGlass:
            name = "流体玻璃"; useCase = "偏好空间层次但仍需高可读性。"; typography = "清晰无衬线 + 突出关键数字"; navigation = "悬浮材质导航"
            advisor = "空间中心顾问面板"; market = "分层行情片段"; assets = "悬浮组合面板"; chart = "半透明外围材质"
        case .dataStarMap:
            name = "数据星图"; useCase = "从中心判断跳转外围市场与研究节点。"; typography = "中心数字 + 节点短标签"; navigation = "节点式首页入口 + 标准底栏"
            advisor = "中央决策摘要"; market = "外围市场节点"; assets = "中央真实资产节点"; chart = "专业页面保持稳定容器"
        case .adaptiveBento:
            name = "动态 Bento"; useCase = "需要异常状态优先显示风险与AI信息。"; typography = "根据模块权重调整字号"; navigation = "标准底部导航"
            advisor = "风险态自动扩展"; market = "状态感知小模块"; assets = "正常态大模块"; chart = "自适应网格外围"
        }
        let tokens = FThemeSemanticTokens(
            background: background, surface: surface, foreground: foreground,
            secondaryForeground: isDark ? Color.white.opacity(0.72) : Color(red: 0.37, green: 0.40, blue: 0.45),
            accent: accent, positive: Color(red: 0.78, green: 0.18, blue: 0.17),
            negative: Color(red: 0.12, green: 0.55, blue: 0.30),
            risk: Color(red: 0.78, green: 0.16, blue: 0.16),
            warning: Color(red: 0.82, green: 0.47, blue: 0.06),
            unavailable: isDark ? Color(red: 0.68, green: 0.72, blue: 0.78) : Color(red: 0.48, green: 0.50, blue: 0.54),
            partial: Color(red: 0.72, green: 0.52, blue: 0.05),
            candidate: accent, buyPoint: Color(red: 0.78, green: 0.18, blue: 0.17),
            sellPoint: Color(red: 0.12, green: 0.55, blue: 0.30),
            episodeCost: Color(red: 0.10, green: 0.40, blue: 0.78),
            brokerCost: Color(red: 0.48, green: 0.32, blue: 0.68),
            intradayAverage: Color(red: 0.52, green: 0.28, blue: 0.67),
            movingAverages: [
                Color(red: 0.82, green: 0.43, blue: 0.12),
                Color(red: 0.16, green: 0.43, blue: 0.72),
                Color(red: 0.46, green: 0.34, blue: 0.68),
                Color(red: 0.10, green: 0.55, blue: 0.50),
                Color(red: 0.72, green: 0.30, blue: 0.43)
            ],
            iopv: Color(red: 0.08, green: 0.53, blue: 0.58), surfaceTreatment: style,
            spacing: spacing(for: family))
        return FThemeManifest(theme: theme, name: name, layout: layout(family), useCase: useCase,
                              typography: typography, navigationPresentation: navigation,
                              advisorPresentation: advisor, marketPresentation: market,
                              assetPresentation: assets, chartContainerPresentation: chart,
                              motion: theme == .fluidGlass ? .spatial : .subtle,
                              appearanceCompatibility: "浅色基础token已接入；深色与护眼语义色、Dynamic Type和截图验收待完成",
                              tokens: tokens)
    }

    private static func spacing(for family: FHomeLayoutFamily) -> FThemeSpacingScale {
        switch family {
        case .minimalTerminal, .terminalDashboard:
            FThemeSpacingScale(compact: 4, standard: 8, spacious: 12)
        case .inkEditorial, .magazine:
            FThemeSpacingScale(compact: 8, standard: 18, spacious: 28)
        case .spatialGlass, .radialMap:
            FThemeSpacingScale(compact: 8, standard: 16, spacious: 24)
        default:
            FThemeSpacingScale(compact: 6, standard: 12, spacious: 20)
        }
    }
}

extension FHomeTheme {
    var layoutFamily: FHomeLayoutFamily {
        switch self {
        case .editorial: .editorial
        case .modern: .cardGrid
        case .dashboard: .terminalDashboard
        case .magazine: .magazine
        case .bento: .staticBento
        case .inkModern: .inkEditorial
        case .minimalTerminal: .minimalTerminal
        case .fluidGlass: .spatialGlass
        case .dataStarMap: .radialMap
        case .adaptiveBento: .adaptiveBento
        }
    }

    var surfaceTreatment: FThemeSurfaceTreatment {
        switch layoutFamily {
        case .editorial: .editorial
        case .cardGrid: .card
        case .terminalDashboard: .terminal
        case .magazine: .magazine
        case .staticBento: .bento
        case .inkEditorial: .ink
        case .minimalTerminal: .minimal
        case .spatialGlass: .glass
        case .radialMap: .orbit
        case .adaptiveBento: .adaptive
        }
    }

    var manifest: FThemeManifest { FThemeLayoutRegistry.manifest(for: self) }
    var title: String { manifest.name }
}
