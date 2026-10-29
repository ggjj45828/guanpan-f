# B UI 源码地图（静态核对）

审计时间：2026-10-29
对象：用户提供的附件 `C:\Users\Administrator\Downloads\B-LATEST..zip`（B Frozen Candidate 归档），交叉核对公开仓库 `ggjj45828/guanpan-pro-native`；本地 `../GuanpanNext-work/ios` 是另一份较早副本，不再作为基线。

## 源码真实性与版本状态

- `B-LATEST..zip` 现已由用户提供，实际路径 `C:\Users\Administrator\Downloads\B-LATEST..zip`，2,028,932 bytes、143 entries。包内 `B-FROZEN-HEAD.txt` 指定冻结候选 HEAD `9ddfe32b787ad9e522a48eb55ff8231227d79599`；GitHub 中该 commit 存在，提交说明 `Freeze B as an acceptance candidate`，日期 2026-10-25。
- 已对包内 `SHA256SUMS.txt` 列出的 142 个文件逐一校验：142 checked，0 mismatch，0 missing。ZIP 包含完整源码树和测试定义；没有截图、`.xcresult` 或 `.ipa`。`B-STATUS.md` 未随 ZIP 一起封装，包内 HEAD 文件称它是单独 sidecar。
- GitHub 公共仓库：[guanpan-pro-native](https://github.com/ggjj45828/guanpan-pro-native)。`b-latest` 当前 HEAD 为 `caaa398eb267566db3c5764b6a146fab6d6e0ccf`，比归档冻结 HEAD 新；其历史显示冻结后先有 CI 分支提交，再有 `NextNewsImpact.swift` 缺失 `return` 修复。B donor 和版本审计以 ZIP 明确标记的 `9ddfe32` 为冻结基线，后续分支仅作为修复历史参考。仓库当前连接为 pull-only，未发现 tag。
- ZIP 和仓库的 `B-MASTER-ACCEPTANCE-MATRIX.md` 将版本标成 **Frozen Candidate**。因此有真实冻结候选源码，但仍不能证明它与用户手机当前安装的 B 包逐字节一致。
- ZIP 含 39 个 Swift 文件、`Assets.xcassets`、Swift Package/XcodeGen 工程、单元/UI 测试源和 GitHub Actions 工作流。资源有 AppIcon PNG；未发现自定义字体文件。
- 当前 `b-latest` HEAD 的 [Build iOS IPA #193](https://github.com/ggjj45828/guanpan-pro-native/actions/runs/40191659330) 于 2026-10-25 成功，上传未签名 IPA artifact（约 7.68 MB，尚未过期）。这是 ZIP 冻结 commit 之后的构建修复版本；不代表 ZIP 冻结 SHA 的 UI/XCTest或视觉验收通过。
- 当前 `b-latest` HEAD 的 [Build iOS IPA #193](https://github.com/ggjj45828/guanpan-pro-native/actions/runs/40191659330) 于 2026-10-25 成功，上传未签名 IPA artifact（约 7.68 MB，尚未过期）。同 SHA 没有可见的完整 UI/XCTest 验证记录；前一 SHA 的 IPA Build 失败，Foundation workflow 成功。不能把 Build IPA 成功写成 UI/视觉验收通过。
- 远端核心 UI 文件：`guanpan-pro-native/Sources/GuanpanAdvisorApp.swift`（`RootView`、导航、路由及主要 Screen）、`ThemeHome.swift`（共用 `HomeSnapshot` 的主题首页 Renderer）、`UnifiedChartView.swift`（证券图表主 Renderer）、`IndexDetailView.swift`（指数页面）、`PortfolioSummaryViews.swift` / `GPAssetCards.swift`（资产卡和组合摘要）、`AIGuidanceViews.swift` / `DeepSeekMobile.swift`（顾问呈现）、`DesignSystem.swift` / `ThemeKit.swift` / `AppThemeCore.swift`（视觉系统/主题）。
- 本地 `../GuanpanNext-work/ios` 有 18 个 Swift 源文件且无 `.git`；它不是 ZIP 冻结版本，不能作为页面审计基线。下方旧表暂留作旧副本观察，不得引用为 Frozen B 页面结构。
- 已解压候选源码：`../GuanpanNext-work/`，可正常读取；原生 SwiftUI 源码根为 `../GuanpanNext-work/ios/Sources/`。
- Git 身份：该目录没有 `.git`，因此没有可报告的 B HEAD、分支或冻结 tag。不能用 F 的提交号代替 B 版本号。
- 项目版本：`ios/project.yml` 声明 `MARKETING_VERSION=3.6.0`、`CURRENT_PROJECT_VERSION=25`、iOS 17.0；这是项目配置值，不是 Git/冻结版本证明。
- `SOURCE_STATUS.txt` 标注日期为 2026-10-20，称源码仍在集中开发、未达到完整交付，并记录当时 iOS XCTest、Xcode 构建、Simulator、截图和真机均未验证。因此不能确认该候选目录就是之前约定的最终 Frozen B。
- 源码结构：18 个 Swift 源文件，含 App、导航、行情、证券详情、图表、AI、资产、设置、设计系统、核心模型和测试配置；可用于源码级页面映射。
- 发现版本内不一致：`GuanpanNextApp.swift` 的实际 `GPTabBar` 列出“行情/持仓/网格/收息/AI 引擎/我的”六项，`RootView`也构造六个入口；同一文件中的旧 `GPMainTab` 仍定义“总览”，而 `NativeNavigationTests.swift` 却断言存在“总览”Tab。README 另称“五个原生主页面”。这是候选快照内部不一致，进一步说明它不是可验证的 Frozen release。
- 资源：`Assets.xcassets` 只发现 AppIcon PNG 与 Contents 清单；未发现自定义字体文件。颜色、字体族、留白和组件主要由 `DesignSystem.swift` 的 Swift 代码定义。
- 截图/构建产物：UITest 源码会创建 `XCTAttachment(screenshot:)`，但当前目录没有 `.xcresult`、`.ipa` 或测试运行截图。`design/`、`previews/` 有 SVG/HTML 设计稿，不能当作真实运行截图。
- 结论：**用户提供的 B Frozen Candidate ZIP 存在、归档 SHA-256 校验全通过，并指向 GitHub 可核验的冻结候选 commit `9ddfe32`。后续 UI donor 审计以 ZIP 内源码为准；本地旧副本和当前分支更新只作旁证。它仍是候选冻结版本，和手机安装版是否完全一致尚无证据。**

## B Frozen Candidate ZIP 的页面和组件映射

| 用户页面/能力 | ZIP 源码入口 | 关键组件/依赖 | 静态源码所见 |
|---|---|---|---|
| 启动、主导航 | `guanpan-pro-native/Sources/GuanpanAdvisorApp.swift` → `RootView` → `PrimaryNavigation` | `GPTabBar`、`GPRoute`、`RouteDestination` | 五个主入口：首页、行情、持仓、AI、我的；深层功能由 route push，而非重复放入底栏。 |
| 首页 | `guanpan-pro-native/Sources/ThemeHome.swift` → `ThemeHomeScreen` | 同一 `HomeSnapshot`；`EditorialHome`、`ModernHome`、`DashboardHome`、`MagazineHome`、`PuzzleHome`；`HomeIndexBoard`、`LeadOpportunityCard`、跨市场卡等 | 五种布局分支读取同一首页快照；这是实际的首页布局分化，不只是颜色 token。 |
| 行情 | `GuanpanAdvisorApp.swift` → `MarketScreen` | `GlobalIndexStrip`、`InstrumentRow`、搜索/过滤/刷新 | 代码级行情列表、指数区、自选/持仓入口及详情路由。 |
| 证券详情 | `GuanpanAdvisorApp.swift` → `InstrumentDetailScreen` | `UnifiedChartView`、数据面板/编辑区、`WorthBuyPanel`、`OrderBookView`、`TradeEntrySheet` | 行情、图表、持仓、数据状态和分析/提醒入口位于统一证券上下文。 |
| 分时、日K、历史及全屏 | `UnifiedChartView.swift`；全屏容器为 `GuanpanAdvisorApp.swift` → `FullscreenChartScreen` | `NextChartDataset`、`NextChartSample`、均线/成交量/副图、缩放/选点等 | 一个主证券图 renderer 被详情和全屏复用；是否真实手势顺畅仍需运行验收。 |
| AI顾问 | `GuanpanAdvisorApp.swift` → `AIHubScreen` / `DecisionScreen`；`AIGuidanceViews.swift` | `AIChatScreen`、`AIGuidanceSection`、`CandidatePlanRow`、`AIFillSheet`、`AIGuidanceDetailSheet`；`DeepSeekMobile.swift` | 今日指导、证据、Candidate 和真实成交表单源码均在；不据此推断实网 DeepSeek 或用户完整操作已验证。 |
| 真实资产/持仓 | `GuanpanAdvisorApp.swift` → `AssetsScreen` | `HoldingsBreakdownPanel`、`GPAssetCards.swift` 的资产卡/曲线/环图、`PositionRow`、`AddPositionSheet`、`TradeEntrySheet` | 有资产摘要、分证券展示、现金/流水与持仓录入、交易确认入口。 |
| 设置 | `GuanpanAdvisorApp.swift` → `SettingsScreen` | `DesignSystem.swift`、`ThemeKit.swift`、`AppThemeCore.swift`、服务/通知/备份路由 | 有外观设置与系统配置入口；不同页面实际使用一致性需按源码进一步核验。 |
| 公共视觉系统 | `DesignSystem.swift` / `ThemeKit.swift` / `AppThemeCore.swift` | `GPPalette`、`DesignTokens`、`EditorialSection`、`DataPanel`、`GPCard`、字体/颜色/间距令牌 | 五套 `AppTheme` 和共享组件/语义色集中管理；主题是否全页面统一，应验证各页面是否都使用 tokens。 |
| 资产/研究公共组件 | `PortfolioSummaryViews.swift`、`GPAssetCards.swift`、`LocalRuleViews.swift` | 资产摘要、指标卡、评分、全球指数带、持仓行和规则面板 | 组件复用与呈现代码可直接评估迁移；F 仍须接自己的真实模型与 Ledger。 |

## 旧本地副本映射（不代表 B Frozen Candidate）

| 用户页面/能力 | B 源文件与 Root View | 关键子组件/依赖 | 静态源码说明 |
|---|---|---|---|
| 启动页 / 主导航 | `ios/Sources/GuanpanNextApp.swift` → `RootView` → `PrimaryNavigation` | `GPTabBar`、`RouteDestination`、`GPRoute`；共享颜色由 `.environment(\.gp, GPPalette)` 注入 | 候选源码根当前进入“行情”，自绘六入口底栏；未找到独立首页/总览内容页。`GPMainTab.overview` 与 UI Test 的“总览”断言疑似遗留代码。 |
| 行情 | `GuanpanNextApp.swift` → `MarketScreen` | `GlobalIndexStrip`（`LocalRuleViews.swift`）、`InstrumentRow`、证券查询、自选/持仓筛选、行滑动操作 | 入口包含代码查询、列表过滤、刷新和证券详情路由；行情行显示来源/新鲜度。 |
| 证券详情 | `GuanpanNextApp.swift` → `InstrumentDetailScreen` | `UnifiedChartView`、`DataPanel`、`EditorialSection`、`GPDataRow`、`WorthBuyPanel`、`OrderBookView`、`TradeEntrySheet` | 同一证券页组织报价、图表、账户与成本、数据状态、风险/研究入口及真实交易记录表单。B 的旧业务口径不得直接带入 F。 |
| 当前分时 / 日K | `ios/Sources/UnifiedChartView.swift` → `UnifiedChartView` | `NextChartDataset` / `NextChartSample`、图层开关、均线、量能副图、选点/光标、复权 | 分时使用固定交易时段；日K及其他周期使用同一 renderer；图层状态保存在本地。 |
| 历史分时 / 全屏图表 | `GuanpanNextApp.swift` → `FullscreenChartScreen`；图表绘制仍由 `UnifiedChartView` 完成 | 日期选择、“最新”入口、横屏尺寸分支、导航状态保存 | 全屏页面有历史日期控制和横屏说明；实际 NAS/历史数据与手势表现必须另行实测。 |
| 日K/指数详情 | `ios/Sources/IndexDetailView.swift` → `IndexDetailScreen` / `IndexIntradayChart`；日线仍调用统一图表 | `UnifiedChartView`、`GlobalIndexSeries` | 指数页有自身市场信息布局，不应迁移成第二套证券图 renderer。 |
| AI 私人顾问 | `GuanpanNextApp.swift` → `DecisionScreen` → `AIAnswerView` / `AIInputsCard` | `DeepSeekMobile.swift`、`LocalRules.swift`、`LocalRuleViews.swift`、`EditorialSection` | 结构化输入、结论、证据与风险、计划/跟踪入口位于该页面。旧模拟/自动策略业务按产品决定剔除。 |
| 真实资产/持仓 | `GuanpanNextApp.swift` → `AssetsScreen` | `PortfolioSummaryViews.swift` 的 `HoldingsBreakdownPanel`；`LocalRuleViews.swift` 的 `PositionRow`、`PositionEditSheet`；`AddPositionSheet`、`TradeEntrySheet` | 有资产摘要、持仓明细、补录持仓、现金对账和确认操作。F 应复用入口/信息层级，写入仍走 F Ledger。 |
| 持仓详情/成交 | `LocalRuleViews.swift` → `PositionRow`、`PositionEditSheet`；`GuanpanNextApp.swift` → `TradeEntrySheet`、`LedgerHistoryScreen` | `NextCore.swift`、`NextAppModel.swift` | 持仓编辑与已确认买卖有明确表单/确认步骤；其券商成本算法仅作 UI donor，F 继续使用 Episode/券商双成本语义。 |
| 设置 | `GuanpanNextApp.swift` → `SettingsScreen` | `EditorialSection`、`GPDataRow`、Keychain 管理、主题/外观、NAS、提醒/备份路由 | 设置页覆盖外观和多组数据/AI设置；源代码存在不证明服务端已部署。 |
| 主题/颜色/字体/留白 | `ios/Sources/DesignSystem.swift` → `GPTheme`、`GPPalette`、`GPAppearance` | `gpFont`、`EditorialSection`、`DataPanel`、`GPValue`、`GPStatus`、`GPDataRow`、`GPActionButton` | 4种系统/浅/深/护眼外观；自定义调色、字体族、Dynamic Type 档位；主页面共享 palette。它是统一设计系统，不是多套首页 layout 家族。 |
| 页面容器/键盘 | `DesignSystem.swift` → `GPPageBackground` / `GPKeyboardDismiss` | `.gpKeyboardDismiss()`、滚动键盘处理 | 内容限宽、页面背景、键盘完成按钮集中复用。 |
| 其他页面 | `GuanpanNextApp.swift` → `GridLabScreen`、`DividendHistoryScreen`、`AlertCenterScreen`、`DecisionHistoryScreen`、`BackupRestoreScreen` | `LocalRuleViews.swift`、`PortfolioSummaryViews.swift`、`IndexDetailView.swift` | 其中网格/模拟/虚拟账户等依照 F 已确认产品方向不恢复；通知、审计、搜索、备份的成熟入口可单独评估。 |

## 验证边界

`NativeNavigationTests.swift` 定义了主页面、证券详情、全屏图表、AI 深链和截图附件测试；当前快照的测试期望与导航实现不一致。没有运行产物，所以只能确认测试源码存在，不能声称 B 当前版本通过编译、UI 测试、Simulator 或真机视觉验收。
