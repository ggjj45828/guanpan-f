# Approved Mockup → SwiftUI 页面映射

更新：2026-11-04。视觉验收基准为用户确认的六套主题模拟图；B版不再是当前UI设计约束。图像目前来自本对话附件，仓库没有随附原始图片文件，因此使用会话内Reference ID，不虚构磁盘路径。

## 验收规则

每一行都必须完成：定位对应参考图 → 重建该图的信息组织 → 绑定F真实业务数据 → 导出当前准确SHA的Simulator截图 → 并排人工比较 → 列出并修正结构差异 → 记录验收。

视觉状态：`Visual Pending` / `Difference Review` / `Accepted`。只有存在当前SHA截图、差异清单已关闭、人工对照记录后才能标 `Accepted`。代码、Manifest、UI XCTest和自动截图导出均不能单独关闭视觉验收。

## Reference 图像索引

| Reference ID | 用户参考图 | 覆盖内容 | 仓库文件 |
|---|---|---|---|
| REF-MOCKUP-6-HOME | 对话附件中的并排首页方案 | 六主题首页构图、资产/顾问/市场层级、底部导航 | 尚未落库；Conversation attachment |
| REF-MOCKUP-6-PAGES-A | 对话附件全页面概念板 A | 首页、行情、证券详情、AI、资产、设置 | 尚未落库；Conversation attachment |
| REF-MOCKUP-6-PAGES-B | 对话附件全页面概念板 B | 首页、行情、K线、AI、资产、设置及居中AI底栏 | 尚未落库；Conversation attachment |

## 主题 × 页面映射

| Theme | Page | Reference Image | 当前SwiftUI入口/视图 | F真实数据绑定 | 实现状态 | 截图/差异 | 验收 |
|---|---|---|---|---|---|---|---|
| 山水头版 | 首页 | REF-MOCKUP-6-HOME | `HomeLayout → FDesignedThemeHome` | FHomeModel：真实Ledger、实时行情、Quant、Advisor、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | 行情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `MarketOverview` | FHomeModel：报价、Watchlist、Local Quant观察分 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | 证券详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `HomeDestination.instrumentDestination` | F行情、Ledger、Quant、Candidate和数据质量 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | 分时 / 日K / MACD | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `FUnifiedSecurityChart` | 真实行情bars、时间戳、质量与Semantic Tokens | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | AI顾问 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `AdvisorOverview` | F DecisionContext、DeepSeek、Quant、风险、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | 跨市场 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `CrossMarketOverview / MarketIndexDetailOverview` | 真实指数快照、来源、时间和交易时段 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | 资产 / 持仓详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `RealAssetsOverview / HomeDestination.instrumentDestination` | 唯一真实Ledger、现金、持仓与历史成交 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | 设置 / 主题选择 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `SettingsOverview / FThemeGalleryRow` | 同一Manifest、主题选择与连接状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 山水头版 | Tab / Navigation | REF-MOCKUP-6-HOME / REF-MOCKUP-6-PAGES-B | `FHomeRoot / FBottomNavigationBar` | 当前Tab与Navigation状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 首页 | REF-MOCKUP-6-HOME | `HomeLayout → FDesignedThemeHome` | FHomeModel：真实Ledger、实时行情、Quant、Advisor、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 行情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `MarketOverview` | FHomeModel：报价、Watchlist、Local Quant观察分 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 证券详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `HomeDestination.instrumentDestination` | F行情、Ledger、Quant、Candidate和数据质量 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 分时 / 日K / MACD | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `FUnifiedSecurityChart` | 真实行情bars、时间戳、质量与Semantic Tokens | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | AI顾问 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `AdvisorOverview` | F DecisionContext、DeepSeek、Quant、风险、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 跨市场 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `CrossMarketOverview / MarketIndexDetailOverview` | 真实指数快照、来源、时间和交易时段 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 资产 / 持仓详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `RealAssetsOverview / HomeDestination.instrumentDestination` | 唯一真实Ledger、现金、持仓与历史成交 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | 设置 / 主题选择 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `SettingsOverview / FThemeGalleryRow` | 同一Manifest、主题选择与连接状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 深空终端 | Tab / Navigation | REF-MOCKUP-6-HOME / REF-MOCKUP-6-PAGES-B | `FHomeRoot / FBottomNavigationBar` | 当前Tab与Navigation状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 首页 | REF-MOCKUP-6-HOME | `HomeLayout → FDesignedThemeHome` | FHomeModel：真实Ledger、实时行情、Quant、Advisor、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 行情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `MarketOverview` | FHomeModel：报价、Watchlist、Local Quant观察分 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 证券详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `HomeDestination.instrumentDestination` | F行情、Ledger、Quant、Candidate和数据质量 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 分时 / 日K / MACD | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `FUnifiedSecurityChart` | 真实行情bars、时间戳、质量与Semantic Tokens | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | AI顾问 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `AdvisorOverview` | F DecisionContext、DeepSeek、Quant、风险、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 跨市场 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `CrossMarketOverview / MarketIndexDetailOverview` | 真实指数快照、来源、时间和交易时段 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 资产 / 持仓详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `RealAssetsOverview / HomeDestination.instrumentDestination` | 唯一真实Ledger、现金、持仓与历史成交 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | 设置 / 主题选择 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `SettingsOverview / FThemeGalleryRow` | 同一Manifest、主题选择与连接状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 珊瑚拼贴 | Tab / Navigation | REF-MOCKUP-6-HOME / REF-MOCKUP-6-PAGES-B | `FHomeRoot / FBottomNavigationBar` | 当前Tab与Navigation状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 首页 | REF-MOCKUP-6-HOME | `HomeLayout → FDesignedThemeHome` | FHomeModel：真实Ledger、实时行情、Quant、Advisor、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 行情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `MarketOverview` | FHomeModel：报价、Watchlist、Local Quant观察分 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 证券详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `HomeDestination.instrumentDestination` | F行情、Ledger、Quant、Candidate和数据质量 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 分时 / 日K / MACD | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `FUnifiedSecurityChart` | 真实行情bars、时间戳、质量与Semantic Tokens | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | AI顾问 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `AdvisorOverview` | F DecisionContext、DeepSeek、Quant、风险、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 跨市场 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `CrossMarketOverview / MarketIndexDetailOverview` | 真实指数快照、来源、时间和交易时段 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 资产 / 持仓详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `RealAssetsOverview / HomeDestination.instrumentDestination` | 唯一真实Ledger、现金、持仓与历史成交 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | 设置 / 主题选择 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `SettingsOverview / FThemeGalleryRow` | 同一Manifest、主题选择与连接状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 蓝海资产 | Tab / Navigation | REF-MOCKUP-6-HOME / REF-MOCKUP-6-PAGES-B | `FHomeRoot / FBottomNavigationBar` | 当前Tab与Navigation状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 首页 | REF-MOCKUP-6-HOME | `HomeLayout → FDesignedThemeHome` | FHomeModel：真实Ledger、实时行情、Quant、Advisor、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 行情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `MarketOverview` | FHomeModel：报价、Watchlist、Local Quant观察分 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 证券详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `HomeDestination.instrumentDestination` | F行情、Ledger、Quant、Candidate和数据质量 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 分时 / 日K / MACD | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `FUnifiedSecurityChart` | 真实行情bars、时间戳、质量与Semantic Tokens | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | AI顾问 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `AdvisorOverview` | F DecisionContext、DeepSeek、Quant、风险、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 跨市场 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `CrossMarketOverview / MarketIndexDetailOverview` | 真实指数快照、来源、时间和交易时段 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 资产 / 持仓详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `RealAssetsOverview / HomeDestination.instrumentDestination` | 唯一真实Ledger、现金、持仓与历史成交 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | 设置 / 主题选择 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `SettingsOverview / FThemeGalleryRow` | 同一Manifest、主题选择与连接状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 夜航量化 | Tab / Navigation | REF-MOCKUP-6-HOME / REF-MOCKUP-6-PAGES-B | `FHomeRoot / FBottomNavigationBar` | 当前Tab与Navigation状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 首页 | REF-MOCKUP-6-HOME | `HomeLayout → FDesignedThemeHome` | FHomeModel：真实Ledger、实时行情、Quant、Advisor、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 行情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `MarketOverview` | FHomeModel：报价、Watchlist、Local Quant观察分 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 证券详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `HomeDestination.instrumentDestination` | F行情、Ledger、Quant、Candidate和数据质量 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 分时 / 日K / MACD | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `FUnifiedSecurityChart` | 真实行情bars、时间戳、质量与Semantic Tokens | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | AI顾问 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `AdvisorOverview` | F DecisionContext、DeepSeek、Quant、风险、Candidate | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 跨市场 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `CrossMarketOverview / MarketIndexDetailOverview` | 真实指数快照、来源、时间和交易时段 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 资产 / 持仓详情 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `RealAssetsOverview / HomeDestination.instrumentDestination` | 唯一真实Ledger、现金、持仓与历史成交 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | 设置 / 主题选择 | REF-MOCKUP-6-PAGES-A / REF-MOCKUP-6-PAGES-B | `SettingsOverview / FThemeGalleryRow` | 同一Manifest、主题选择与连接状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
| 极光全景 | Tab / Navigation | REF-MOCKUP-6-HOME / REF-MOCKUP-6-PAGES-B | `FHomeRoot / FBottomNavigationBar` | 当前Tab与Navigation状态 | 有公共SwiftUI入口；逐主题构图是否对应模拟图尚未核对 | 当前SHA截图待导出；差异清单未完成 | Visual Pending |
## 设计与实现状态分离

- 设计已确认：六套模拟图作为视觉目标；主题布局可以不同，同一主题内保持颜色、字体、组件和导航连贯。
- SwiftUI实现：源码能定位六套首页及各业务页的共享入口；公共入口不证明每个主题都已按图完成独立布局。
- Simulator视觉验证：当前没有当前精确SHA的人工对照证据；全部行保持 `Visual Pending`。
- iPhone Air实机：External Pending。
- 历史B UI地图和B→F迁移文件保留为 `Superseded / Historical`，不作为本矩阵来源或视觉判定依据。