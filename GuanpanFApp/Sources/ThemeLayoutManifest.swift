import SwiftUI
import UIKit

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
        case .crossMarketPulse: "跨市场行情 · NAS历史数据供Quant验证"
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
    let accentForeground: Color
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
            .cardGrid: ("均衡", "宽屏网格并列展示市场与跨市场入口，窄屏自动堆叠；组合和顾问保持全宽。", false),
            .terminalDashboard: ("紧凑", "现金、行情和决策入口采用紧凑终端层级。", false),
            .magazine: ("舒展", "日期与专题标题先行，随后以长篇章节呈现组合和研究。", false),
            .staticBento: ("中等", "固定大小模块组成拼图，突出资产与AI指导。", false),
            .inkEditorial: ("宽松", "留白、墨色标题与朱砂强调组织成现代财经编辑版面。", false),
            .minimalTerminal: ("高密度", "弱卡片、分割线和数字流构成紧凑行情终端。", false),
            .spatialGlass: ("中等", "AI指导居中，玻璃表面和层叠空间组织信息。", false),
            .radialMap: ("节点式", "AI与真实资产位于中心，市场和研究以外围节点连接。", false),
            .adaptiveBento: ("自适应", "按本地账本可用性与Guard状态调整卡片强调度，卡片顺序固定。", false)
        ]
        let value = descriptions[family] ?? ("均衡", "共享业务角色布局。", false)
        let order = roleOrder
        return FLayoutManifest(family: family, informationDensity: value.0,
                               description: value.1, roleOrder: order,
                               reordersForLocalRiskState: value.2)
    }

    static func manifest(for theme: FHomeTheme) -> FThemeManifest {
        let family = theme.layoutFamily
        let style = theme.surfaceTreatment
        let background: Color
        let surface: Color
        switch theme {
        case .editorial:
            background = adaptive(light: (0.965, 0.953, 0.925), dark: (0.075, 0.068, 0.060))
            surface = adaptive(light: (0.995, 0.988, 0.968), dark: (0.13, 0.12, 0.11))
        case .modern:
            background = adaptive(light: (0.942, 0.955, 0.972), dark: (0.055, 0.070, 0.090))
            surface = adaptive(light: (0.990, 0.995, 1.0), dark: (0.12, 0.14, 0.17))
        case .dashboard:
            background = adaptive(light: (0.925, 0.943, 0.958), dark: (0.04, 0.07, 0.09))
            surface = adaptive(light: (0.987, 0.993, 0.998), dark: (0.08, 0.12, 0.14))
        case .magazine:
            background = adaptive(light: (0.975, 0.947, 0.914), dark: (0.08, 0.06, 0.045))
            surface = adaptive(light: (1.0, 0.982, 0.953), dark: (0.15, 0.11, 0.09))
        case .bento, .adaptiveBento:
            background = adaptive(light: (0.935, 0.957, 0.935), dark: (0.055, 0.08, 0.06))
            surface = adaptive(light: (0.985, 0.995, 0.980), dark: (0.11, 0.14, 0.11))
        case .inkModern:
            background = adaptive(light: (0.956, 0.944, 0.911), dark: (0.07, 0.06, 0.04))
            surface = adaptive(light: (0.992, 0.982, 0.955), dark: (0.13, 0.115, 0.085))
        case .minimalTerminal:
            background = adaptive(light: (0.925, 0.944, 0.953), dark: (0.04, 0.065, 0.075))
            surface = adaptive(light: (0.976, 0.986, 0.989), dark: (0.09, 0.12, 0.13))
        case .fluidGlass:
            background = adaptive(light: (0.913, 0.933, 0.968), dark: (0.045, 0.065, 0.11))
            surface = adaptive(light: (0.979, 0.987, 1.0), dark: (0.10, 0.14, 0.21))
        case .dataStarMap:
            background = adaptive(light: (0.936, 0.925, 0.963), dark: (0.06, 0.05, 0.09))
            surface = adaptive(light: (0.989, 0.984, 1.0), dark: (0.13, 0.11, 0.18))
        }
        let foreground = adaptive(light: (0.12, 0.15, 0.19), dark: (0.91, 0.93, 0.96))
        let accent: Color
        switch theme {
        case .editorial, .inkModern: accent = adaptive(light: (0.68, 0.29, 0.18), dark: (0.92, 0.55, 0.39))
        case .modern: accent = adaptive(light: (0.18, 0.39, 0.82), dark: (0.48, 0.65, 0.98))
        case .dashboard: accent = adaptive(light: (0.16, 0.53, 0.61), dark: (0.42, 0.77, 0.84))
        case .magazine: accent = adaptive(light: (0.69, 0.27, 0.19), dark: (0.95, 0.52, 0.40))
        case .bento, .adaptiveBento: accent = adaptive(light: (0.28, 0.49, 0.35), dark: (0.50, 0.77, 0.57))
        case .minimalTerminal: accent = adaptive(light: (0.52, 0.78, 0.88), dark: (0.58, 0.84, 0.94))
        case .fluidGlass: accent = adaptive(light: (0.42, 0.61, 0.93), dark: (0.62, 0.78, 1.0))
        case .dataStarMap: accent = adaptive(light: (0.76, 0.67, 0.95), dark: (0.87, 0.79, 1.0))
        }
        let accentForeground: Color
        switch theme {
        case .editorial, .modern, .dashboard, .magazine, .bento, .adaptiveBento, .inkModern:
            accentForeground = adaptive(light: (1.0, 1.0, 1.0), dark: (0.08, 0.09, 0.11))
        case .minimalTerminal:
            accentForeground = adaptive(light: (0.06, 0.12, 0.15), dark: (0.04, 0.08, 0.10))
        case .fluidGlass:
            accentForeground = adaptive(light: (0.05, 0.08, 0.15), dark: (0.04, 0.07, 0.12))
        case .dataStarMap:
            accentForeground = adaptive(light: (0.10, 0.07, 0.16), dark: (0.08, 0.05, 0.12))
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
            advisor = "输入与快捷问题卡片"; market = "宽屏并列、窄屏堆叠的摘要卡片"; assets = "持仓列表摘要"; chart = "标准卡片容器"
        case .dashboard:
            name = "交易仪表盘"; useCase = "偏好紧凑行情与现金指标的用户。"; typography = "等宽数字优先"; navigation = "终端式紧凑导航，随系统外观变化"
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
            secondaryForeground: adaptive(light: (0.37, 0.40, 0.45), dark: (0.72, 0.75, 0.80)),
            accent: accent, accentForeground: accentForeground,
            positive: adaptive(light: (0.78, 0.18, 0.17), dark: (1.0, 0.43, 0.40)),
            negative: adaptive(light: (0.12, 0.55, 0.30), dark: (0.37, 0.78, 0.52)),
            risk: adaptive(light: (0.78, 0.16, 0.16), dark: (1.0, 0.42, 0.40)),
            warning: adaptive(light: (0.82, 0.47, 0.06), dark: (1.0, 0.68, 0.27)),
            unavailable: adaptive(light: (0.48, 0.50, 0.54), dark: (0.68, 0.72, 0.78)),
            partial: adaptive(light: (0.72, 0.52, 0.05), dark: (0.94, 0.73, 0.25)),
            candidate: accent,
            buyPoint: adaptive(light: (0.78, 0.18, 0.17), dark: (1.0, 0.43, 0.40)),
            sellPoint: adaptive(light: (0.12, 0.55, 0.30), dark: (0.37, 0.78, 0.52)),
            episodeCost: adaptive(light: (0.10, 0.40, 0.78), dark: (0.42, 0.68, 1.0)),
            brokerCost: adaptive(light: (0.48, 0.32, 0.68), dark: (0.72, 0.59, 0.94)),
            intradayAverage: adaptive(light: (0.52, 0.28, 0.67), dark: (0.78, 0.56, 0.94)),
            movingAverages: [
                adaptive(light: (0.82, 0.43, 0.12), dark: (1.0, 0.66, 0.34)),
                adaptive(light: (0.16, 0.43, 0.72), dark: (0.47, 0.70, 1.0)),
                adaptive(light: (0.46, 0.34, 0.68), dark: (0.74, 0.64, 0.95)),
                adaptive(light: (0.10, 0.55, 0.50), dark: (0.37, 0.81, 0.75)),
                adaptive(light: (0.72, 0.30, 0.43), dark: (0.95, 0.58, 0.68))
            ],
            iopv: adaptive(light: (0.08, 0.53, 0.58), dark: (0.38, 0.79, 0.84)), surfaceTreatment: style,
            spacing: spacing(for: family))
        return FThemeManifest(theme: theme, name: name, layout: layout(family), useCase: useCase,
                              typography: typography, navigationPresentation: navigation,
                              advisorPresentation: advisor, marketPresentation: market,
                              assetPresentation: assets, chartContainerPresentation: chart,
                              motion: theme == .fluidGlass ? .spatial : .subtle,
                              appearanceCompatibility: "浅色/深色语义token跟随系统外观；护眼模式、Dynamic Type与截图验收待完成",
                              tokens: tokens)
    }

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat),
                                 dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let components = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: components.0, green: components.1,
                           blue: components.2, alpha: 1)
        })
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
