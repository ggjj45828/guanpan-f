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
        case .crossMarketPulse: "跨市场行情 · NAS为可选历史归档与研究增强"
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
    let portfolioSurface: Color
    let advisorSurface: Color
    let marketSurface: Color
    let highlightSurface: Color
    let surfaceGradient: [Color]
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
        case .referenceDark:
            // 严格对齐参考稿：近黑画布 #0B0B0D + 卡片 #151517，常暗不随系统外观变化。
            background = adaptive(light: (0.043, 0.043, 0.051), dark: (0.043, 0.043, 0.051))
            surface = adaptive(light: (0.082, 0.082, 0.090), dark: (0.082, 0.082, 0.090))
        case .editorial:
            background = adaptive(light: (0.965, 0.953, 0.925), dark: (0.075, 0.068, 0.060))
            surface = adaptive(light: (0.995, 0.988, 0.968), dark: (0.13, 0.12, 0.11))
        case .modern:
            background = adaptive(light: (0.942, 0.955, 0.972), dark: (0.055, 0.070, 0.090))
            surface = adaptive(light: (0.990, 0.995, 1.0), dark: (0.12, 0.14, 0.17))
        case .dashboard:
            background = adaptive(light: (0.018, 0.035, 0.075), dark: (0.018, 0.035, 0.075))
            surface = adaptive(light: (0.035, 0.075, 0.14), dark: (0.035, 0.075, 0.14))
        case .magazine:
            background = adaptive(light: (0.975, 0.947, 0.914), dark: (0.08, 0.06, 0.045))
            surface = adaptive(light: (1.0, 0.982, 0.953), dark: (0.15, 0.11, 0.09))
        case .bento:
            background = adaptive(light: (0.958, 0.958, 0.985), dark: (0.055, 0.045, 0.15))
            surface = adaptive(light: (1.0, 1.0, 1.0), dark: (0.12, 0.12, 0.22))
        case .adaptiveBento:
            background = adaptive(light: (0.15, 0.19, 0.88), dark: (0.07, 0.10, 0.50))
            surface = adaptive(light: (0.99, 0.99, 1.0), dark: (0.10, 0.14, 0.48))
        case .inkModern:
            background = adaptive(light: (0.956, 0.944, 0.911), dark: (0.07, 0.06, 0.04))
            surface = adaptive(light: (0.992, 0.982, 0.955), dark: (0.13, 0.115, 0.085))
        case .minimalTerminal:
            background = adaptive(light: (0.008, 0.035, 0.09), dark: (0.008, 0.035, 0.09))
            surface = adaptive(light: (0.025, 0.075, 0.15), dark: (0.025, 0.075, 0.15))
        case .fluidGlass:
            background = adaptive(light: (0.913, 0.933, 0.968), dark: (0.045, 0.065, 0.11))
            surface = adaptive(light: (0.979, 0.987, 1.0), dark: (0.10, 0.14, 0.21))
        case .dataStarMap:
            background = adaptive(light: (0.936, 0.925, 0.963), dark: (0.06, 0.05, 0.09))
            surface = adaptive(light: (0.989, 0.984, 1.0), dark: (0.13, 0.11, 0.18))
        }
        let foreground = adaptive(light: (0.12, 0.15, 0.19), dark: (0.91, 0.93, 0.96))
        let portfolioSurface: Color
        let advisorSurface: Color
        let marketSurface: Color
        let highlightSurface: Color
        let surfaceGradient: [Color]
        switch theme {
        case .referenceDark:
            portfolioSurface = adaptive(light: (0.102, 0.102, 0.114), dark: (0.102, 0.102, 0.114))
            advisorSurface = adaptive(light: (0.55, 0.35, 0.95), dark: (0.55, 0.35, 0.95))
            marketSurface = adaptive(light: (0.067, 0.067, 0.075), dark: (0.067, 0.067, 0.075))
            highlightSurface = adaptive(light: (0.784, 0.969, 0.318), dark: (0.784, 0.969, 0.318))
            surfaceGradient = [adaptive(light: (0.11, 0.11, 0.12), dark: (0.11, 0.11, 0.12)),
                               adaptive(light: (0.055, 0.055, 0.062), dark: (0.055, 0.055, 0.062))]
        case .editorial:
            portfolioSurface = adaptive(light: (0.08, 0.22, 0.60), dark: (0.08, 0.22, 0.60))
            advisorSurface = adaptive(light: (0.98, 0.34, 0.25), dark: (0.72, 0.19, 0.16))
            marketSurface = adaptive(light: (1.0, 0.96, 0.88), dark: (0.17, 0.14, 0.11))
            highlightSurface = adaptive(light: (0.97, 0.77, 0.55), dark: (0.42, 0.27, 0.18))
            surfaceGradient = [adaptive(light: (0.99, 0.95, 0.86), dark: (0.16, 0.12, 0.08)), adaptive(light: (0.83, 0.73, 0.57), dark: (0.25, 0.18, 0.11))]
        case .dashboard:
            portfolioSurface = adaptive(light: (0.02, 0.17, 0.37), dark: (0.02, 0.17, 0.37))
            advisorSurface = adaptive(light: (0.01, 0.33, 0.36), dark: (0.01, 0.33, 0.36))
            marketSurface = adaptive(light: (0.04, 0.11, 0.22), dark: (0.04, 0.11, 0.22))
            highlightSurface = adaptive(light: (0.30, 0.16, 0.44), dark: (0.30, 0.16, 0.44))
            surfaceGradient = [adaptive(light: (0.01, 0.07, 0.16), dark: (0.01, 0.07, 0.16)), adaptive(light: (0.02, 0.19, 0.32), dark: (0.02, 0.19, 0.32))]
        case .minimalTerminal:
            portfolioSurface = adaptive(light: (0.035, 0.14, 0.34), dark: (0.035, 0.14, 0.34))
            advisorSurface = adaptive(light: (0.04, 0.12, 0.24), dark: (0.04, 0.12, 0.24))
            marketSurface = adaptive(light: (0.025, 0.10, 0.21), dark: (0.025, 0.10, 0.21))
            highlightSurface = adaptive(light: (0.25, 0.13, 0.42), dark: (0.25, 0.13, 0.42))
            surfaceGradient = [adaptive(light: (0.01, 0.04, 0.14), dark: (0.01, 0.04, 0.14)), adaptive(light: (0.03, 0.15, 0.30), dark: (0.03, 0.15, 0.30))]
        case .bento:
            portfolioSurface = adaptive(light: (0.06, 0.15, 0.48), dark: (0.06, 0.15, 0.48))
            advisorSurface = adaptive(light: (0.98, 0.28, 0.35), dark: (0.72, 0.13, 0.24))
            marketSurface = adaptive(light: (0.39, 0.82, 0.94), dark: (0.04, 0.35, 0.46))
            highlightSurface = adaptive(light: (0.99, 0.76, 0.24), dark: (0.52, 0.35, 0.07))
            surfaceGradient = [adaptive(light: (0.25, 0.20, 0.96), dark: (0.13, 0.12, 0.50)), adaptive(light: (0.06, 0.56, 0.98), dark: (0.04, 0.29, 0.72))]
        case .adaptiveBento:
            portfolioSurface = adaptive(light: (0.05, 0.39, 0.98), dark: (0.03, 0.23, 0.63))
            advisorSurface = adaptive(light: (0.98, 0.30, 0.38), dark: (0.73, 0.14, 0.25))
            marketSurface = adaptive(light: (0.92, 0.98, 1.0), dark: (0.04, 0.27, 0.54))
            highlightSurface = adaptive(light: (1.0, 0.79, 0.25), dark: (0.55, 0.36, 0.06))
            surfaceGradient = [adaptive(light: (0.23, 0.13, 0.93), dark: (0.11, 0.09, 0.48)), adaptive(light: (0.04, 0.45, 0.98), dark: (0.02, 0.26, 0.66))]
        case .modern:
            portfolioSurface = adaptive(light: (0.04, 0.34, 0.90), dark: (0.04, 0.34, 0.90))
            advisorSurface = adaptive(light: (0.97, 0.32, 0.33), dark: (0.70, 0.13, 0.21))
            marketSurface = adaptive(light: (0.98, 0.98, 1.0), dark: (0.11, 0.13, 0.19))
            highlightSurface = adaptive(light: (0.22, 0.74, 0.62), dark: (0.04, 0.37, 0.31))
            surfaceGradient = [adaptive(light: (0.05, 0.39, 0.98), dark: (0.04, 0.26, 0.62)), adaptive(light: (0.01, 0.20, 0.75), dark: (0.02, 0.12, 0.42))]
        case .magazine:
            portfolioSurface = adaptive(light: (0.91, 0.34, 0.19), dark: (0.64, 0.20, 0.14))
            advisorSurface = adaptive(light: (0.70, 0.20, 0.31), dark: (0.52, 0.13, 0.25))
            marketSurface = adaptive(light: (0.98, 0.78, 0.33), dark: (0.52, 0.36, 0.12))
            highlightSurface = adaptive(light: (0.55, 0.38, 0.72), dark: (0.35, 0.24, 0.52))
            surfaceGradient = [adaptive(light: (1.0, 0.89, 0.71), dark: (0.20, 0.11, 0.10)),
                               adaptive(light: (0.94, 0.68, 0.48), dark: (0.32, 0.16, 0.13))]
        case .inkModern:
            portfolioSurface = adaptive(light: (0.12, 0.28, 0.55), dark: (0.10, 0.23, 0.43))
            advisorSurface = adaptive(light: (0.76, 0.25, 0.17), dark: (0.60, 0.18, 0.13))
            marketSurface = adaptive(light: (0.28, 0.53, 0.48), dark: (0.15, 0.35, 0.31))
            highlightSurface = adaptive(light: (0.89, 0.69, 0.40), dark: (0.43, 0.30, 0.13))
            surfaceGradient = [adaptive(light: (0.98, 0.93, 0.82), dark: (0.14, 0.12, 0.10)),
                               adaptive(light: (0.88, 0.79, 0.63), dark: (0.23, 0.19, 0.13))]
        case .fluidGlass:
            portfolioSurface = adaptive(light: (0.12, 0.48, 0.80), dark: (0.08, 0.34, 0.60))
            advisorSurface = adaptive(light: (0.46, 0.32, 0.82), dark: (0.31, 0.22, 0.64))
            marketSurface = adaptive(light: (0.18, 0.70, 0.76), dark: (0.07, 0.42, 0.49))
            highlightSurface = adaptive(light: (0.95, 0.43, 0.58), dark: (0.62, 0.23, 0.39))
            surfaceGradient = [adaptive(light: (0.79, 0.88, 1.0), dark: (0.10, 0.15, 0.25)),
                               adaptive(light: (0.83, 0.80, 0.98), dark: (0.20, 0.14, 0.32))]
        case .dataStarMap:
            portfolioSurface = adaptive(light: (0.20, 0.40, 0.94), dark: (0.13, 0.29, 0.72))
            advisorSurface = adaptive(light: (0.82, 0.28, 0.66), dark: (0.60, 0.17, 0.48))
            marketSurface = adaptive(light: (0.10, 0.67, 0.78), dark: (0.04, 0.39, 0.52))
            highlightSurface = adaptive(light: (0.98, 0.66, 0.18), dark: (0.59, 0.35, 0.07))
            surfaceGradient = [adaptive(light: (0.80, 0.85, 1.0), dark: (0.12, 0.12, 0.27)),
                               adaptive(light: (0.94, 0.82, 0.98), dark: (0.25, 0.13, 0.30))]
        }
        let accent: Color
        switch theme {
        case .referenceDark: accent = adaptive(light: (0.784, 0.969, 0.318), dark: (0.784, 0.969, 0.318))
        case .editorial, .inkModern: accent = adaptive(light: (0.68, 0.29, 0.18), dark: (0.92, 0.55, 0.39))
        case .modern: accent = adaptive(light: (0.18, 0.39, 0.82), dark: (0.48, 0.65, 0.98))
        case .dashboard: accent = adaptive(light: (0.16, 0.53, 0.61), dark: (0.42, 0.77, 0.84))
        case .magazine: accent = adaptive(light: (0.69, 0.27, 0.19), dark: (0.95, 0.52, 0.40))
        case .bento: accent = adaptive(light: (0.31, 0.24, 0.87), dark: (0.67, 0.62, 1.0))
        case .adaptiveBento: accent = adaptive(light: (0.98, 0.98, 1.0), dark: (0.88, 0.91, 1.0))
        case .minimalTerminal: accent = adaptive(light: (0.52, 0.78, 0.88), dark: (0.58, 0.84, 0.94))
        case .fluidGlass: accent = adaptive(light: (0.42, 0.61, 0.93), dark: (0.62, 0.78, 1.0))
        case .dataStarMap: accent = adaptive(light: (0.76, 0.67, 0.95), dark: (0.87, 0.79, 1.0))
        }
        let accentForeground: Color
        switch theme {
        case .referenceDark: accentForeground = adaptive(light: (0.043, 0.043, 0.051), dark: (0.043, 0.043, 0.051))
        case .editorial, .modern, .dashboard, .magazine, .bento, .inkModern:
            accentForeground = adaptive(light: (1.0, 1.0, 1.0), dark: (0.08, 0.09, 0.11))
        case .adaptiveBento:
            accentForeground = adaptive(light: (0.07, 0.08, 0.22), dark: (0.04, 0.05, 0.15))
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
        case .referenceDark:
            name = "深黑柠檬"; useCase = "严格对齐参考稿：近黑画布、悬浮暗卡、柠檬绿强调与超大资产数字。"
            typography = "56pt 级数字 + 13pt 灰标签 + 单层无衬线"
            navigation = "纯图标底栏 + 中央悬浮渐变 AI 球"
            advisor = "橙粉紫蓝渐变 AI 洞察卡"
            market = "胶囊筛选 + 迷你走势行"
            assets = "资产总览大数字 + 环形占比行"
            chart = "暗底细网格 + 柠檬绿主色"
        case .editorial:
            name = "山水头版"; useCase = "暖纸色、山景资产主视觉与朱红今日判断。"; typography = "财经刊物式标题 + 靛蓝资产数字"
            navigation = "暖白底部导航"; advisor = "朱红主编判断面板"; market = "三栏指数速览"; assets = "山景叠层资产头版"; chart = "纸感内嵌图表"
        case .modern:
            name = "蓝海资产"; useCase = "蓝色资产主卡、珊瑚顾问与轻量市场卡。"; typography = "大号资产数字 + 紧凑无衬线"; navigation = "明亮底部导航"
            advisor = "输入与快捷问题卡片"; market = "宽屏并列、窄屏堆叠的摘要卡片"; assets = "持仓列表摘要"; chart = "标准卡片容器"
        case .dashboard:
            name = "深空终端"; useCase = "暗色行情终端，市场、分时和自选同屏。"; typography = "紧凑终端数字 + 青绿图表"; navigation = "深色终端底部导航"
            advisor = "青色实时判断面板"; market = "三栏指数行情"; assets = "资产指标头部"; chart = "行情与真实分钟折线同屏"
        case .magazine:
            name = "杂志卡片"; useCase = "按专题阅读组合和市场信息。"; typography = "大标题 + 章节副标题"; navigation = "标准底部导航"
            advisor = "顾问专栏"; market = "专题章节"; assets = "头版组合摘要"; chart = "杂志版面容器"
        case .bento:
            name = "珊瑚拼贴"; useCase = "白底异形网格，顾问、资产与行情各自成色。"; typography = "高对比标题 + 彩色功能节点"; navigation = "白底底部导航"
            advisor = "宽幅顾问模块"; market = "独立网格单元"; assets = "大尺寸组合单元"; chart = "拼图式边框容器"
        case .inkModern:
            name = "东方墨韵"; useCase = "偏好留白与现代东方财经编辑表达。"; typography = "墨色标题 + 朱砂数字强调"; navigation = "轻量文字导航"
            advisor = "今日主笔摘要"; market = "章节式观察栏"; assets = "编辑式资产摘要"; chart = "无边框纸面区"
        case .minimalTerminal:
            name = "夜航量化"; useCase = "先看真实行情曲线，再看组合判断和量化状态。"; typography = "等宽数字 + 青色走势"; navigation = "暗色快捷导航"
            advisor = "直接进入数据流"; market = "表格式行情流"; assets = "单行账户摘要"; chart = "平面细分割容器"
        case .fluidGlass:
            name = "流体玻璃"; useCase = "偏好空间层次但仍需高可读性。"; typography = "清晰无衬线 + 突出关键数字"; navigation = "悬浮材质导航"
            advisor = "空间中心顾问面板"; market = "分层行情片段"; assets = "悬浮组合面板"; chart = "半透明外围材质"
        case .dataStarMap:
            name = "数据星图"; useCase = "从中心判断跳转外围市场与研究节点。"; typography = "中心数字 + 节点短标签"; navigation = "节点式首页入口 + 标准底栏"
            advisor = "中央决策摘要"; market = "外围市场节点"; assets = "中央真实资产节点"; chart = "专业页面保持稳定容器"
        case .adaptiveBento:
            name = "极光全景"; useCase = "高饱和蓝紫背景、浮动现金与彩色信息拼图。"; typography = "白色标题 + 明亮分区数字"; navigation = "高对比蓝色底部导航"
            advisor = "风险态自动扩展"; market = "状态感知小模块"; assets = "正常态大模块"; chart = "自适应网格外围"
        }
        let tokens = FThemeSemanticTokens(
            background: background, surface: surface, portfolioSurface: portfolioSurface,
            advisorSurface: advisorSurface, marketSurface: marketSurface,
            highlightSurface: highlightSurface, surfaceGradient: surfaceGradient, foreground: foreground,
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

    private static func accentFallback(_ theme: FHomeTheme) -> Color {
        switch theme {
        case .magazine, .inkModern: adaptive(light: (0.72, 0.28, 0.19), dark: (0.90, 0.48, 0.36))
        case .fluidGlass: adaptive(light: (0.26, 0.48, 0.88), dark: (0.50, 0.70, 1.0))
        case .dataStarMap: adaptive(light: (0.48, 0.30, 0.75), dark: (0.74, 0.62, 0.98))
        default: adaptive(light: (0.22, 0.40, 0.70), dark: (0.45, 0.66, 0.95))
        }
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
    /// Resolve only the six currently approved visual concepts. Old persisted
    /// theme identifiers remain decodable for migration, but must not cause a
    /// different theme to reappear on a detail screen or chart.
    static func selected(_ rawValue: String) -> FHomeTheme {
        guard let theme = FHomeTheme(rawValue: rawValue), allCases.contains(theme) else { return .editorial }
        return theme
    }

    var layoutFamily: FHomeLayoutFamily {
        switch self {
        case .referenceDark: .cardGrid
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

