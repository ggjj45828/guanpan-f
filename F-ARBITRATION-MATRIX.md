# A/B Final Arbitration Matrix → F Master Transfer Plan

基准固定为用户指定 HEAD。A：`eb6fa384a2df8c503eb76d13f68d080c08be31ad`，用户指定 `A-LATEST.zip` SHA-256 `F1E09D0D13D99017537EFB831FC6BA15EF67C3CCE3526173C77AFED508C2B9E8`。B：`9ddfe32b787ad9e522a48eb55ff8231227d79599`，用户指定 `work/github-upload/B-LATEST.zip` SHA-256 `EEEC94C0433482C66DF0F6CA20ACA3993E2349AC5E39CD1CA92E711F690305B3`。B内嵌HEAD标记与本地HEAD一致，142项SHA256SUMS全通过，且与独立Git归档141个共同文件逐字节相同。另有 `CANDIDATE-MANIFEST.json` 的134项中70项记录陈旧，本次不用它作为完整性清单。A/B STATUS 仅用于理解其声明的测试状态，不作为代码胜负依据。用户已确认 B 版 Master Acceptance Matrix 的145项作为F需求和验收输入；逐项保留来源编号并重新裁决需求处置及F实现，B的状态/通过证据不继承。

结论代码仅用 `A胜 / B胜 / 融合 / F重构`。实现描述与优点来自静态源码；状态中的通过率不等于本次复测。源路径均相对 `review-sources/A/GuanpanNext/` 和 `review-sources/B-LATEST-9ddfe32/`。

| 模块 | A 实现与源码证据 | B 实现与源码证据 | A 优点 | B 优点 | 风险 | 裁决 | F 采用方案 | 难度 | F 必须重测 |
|---|---|---|---|---|---|---|---|---|---|
| 真实账本 schema | `ios/Sources/NextCore.swift`: NextBook v1、Decimal | `guanpan-pro-native/Sources/NextCore.swift`: 同源 v1，增加关联与语义校验 | 模型较小、容易隔离 | 完整性规则更多 | schema 看似同源也不能共库 | 融合 | 依据不变量另建 F v1 | 高 | 解码、语义、兼容、守恒 |
| 现金 | `NextCore.swift`, `NextAppModel.swift`: 现金余额/变动 | `NextCore.swift`, `NextAppModelState.swift`: 同源并接事务写入 | 本机模型路径简单 | 失败写入守卫较完整 | 现金余额与流水可能漂移 | 融合 | 唯一权威余额+可重算/对账现金流水 | 高 | 入金、出金、手续费、失败事务 |
| 持仓 | `NextCore.swift`: code/units/bookCost/acquiredAt | B 同源持仓，加入时间及份额极值校验 | Decimal成本基础 | 溢出与时间校验细 | 导入历史成本需审计 | 融合 | 规范化持仓并校验汇总 | 高 | 加仓、减仓、极值、恢复 |
| 流水 | `NextCore.swift`: fills/cash movement/asset points | 同源并增加 plan/decision 可选关联 | 真实记账结构已有 | 关联可追溯性较强 | 旧记录缺 ID/来源 | 融合 | 稳定唯一 ID，保留原始事实 | 高 | 唯一性、现金/持仓闭合 |
| 成交确认 | `NextAppModel.swift`: 用户人工登记 | `NextAppModelState.swift`: 人工/候选确认共用 recordTrade | 流程直接 | 计划成交收敛到底层账本入口 | 需审计所有调用不可隐式确认 | B胜 | 用户确认门控一个入口 | 高 | 候选不写账、确认一次写账、幂等 |
| 费用 | `NextCore.swift`: 成交 fee | `NextAppModelState.swift`: 可配置费率、多文件事务 | 简单记录费用 | 设置失败回滚设计 | 券商/ETF费率属外部变量 | B胜 | 费率版本化、成交保存实际费用 | 中 | 手续费边界、费率变更失败 |
| 候选计划 | 本机规则/计划视图与本地规则 | `NextCandidatePlans.swift`, `NextAppModelState.swift` | 基本候选规则 | 状态、有效期、新闻/报价失效和成交关联 | Swift增量未完整运行 | B胜 | 计划是无副作用数据对象 | 高 | 无账本副作用、过期、部分成交 |
| Decision Memory | 无同等独立模型 | `NextDecisionMemory.swift`, `DecisionMemoryView.swift` | — | 决策时点证据快照、结果和改判差异 | 画像反馈可能重复/偏置 | B胜 | 迁移独立审计，模型不作为账本事实 | 高 | 快照稳定、结果关联、重复反馈 |
| Investor Profile | 无同等独立模块 | `InvestorProfile.swift`, `InvestorProfileView.swift` | — | 可解释偏好与角色 | 学习边界和旧状态兼容 | B胜 | 只从用户行为/确认反馈更新 | 中 | 解码、更新来源、反馈幂等 |
| DecisionContext | `DeepSeekMobile.swift`, `NASService.swift`, `server/ai.py` | `NextAIGuide.swift`, `NextAppModelState.swift`, `server/ai.py` | 本机+NAS已有输入链 | 手机上唯一指导聚合，证据更统一 | A已知手机与NAS schema/prompt分歧；B多状态耦合 | B胜 | 单一带版本上下文契约 | 高 | 上下文一致、陈旧、缺数拒答 |
| Risk Guard | `LocalRules.swift`, 服务端advisor校验 | `NextCandidatePlans.swift` 的 portfolio/cross-market guards | 有基本规则基础 | 组合暴露、现金储备、异常行情阻断更广 | 新增边界测试未在冻结点实跑 | B胜 | 提取纯函数、拒绝优先 | 高 | 风险边界、组合极值、过时报价 |
| AI Guard | `server/ai.py`, `advisor.py` schema/数值限制 | 同类校验+ `NextAIGuide.swift` 结构化输出边界 | NAS输入校验已有 | 手机输出与规则候选绑定更完整 | 模型幻觉仍需UI与结果校验 | B胜 | 模型无交易权限，数值仅由规则产生 | 高 | 畸形输出、越权指令、缺字段 |
| AI最终决策闭环 | 本地 context→NAS analyze→解释 | 指导→候选→用户确认→账本→记忆/画像 | 基础端到端构件多 | 业务闭环更完整 | B链条存在但冻结版本未完整平台验证 | B胜 | 唯一手机决策编排，NAS只供证据 | 高 | 全链端到端和拒绝路径 |
| T策略 | `LocalRules.swift`, `server/backtest.py` | `NextCandidatePlans.swift`, `NextCore.swift` | 规则/分析有基础 | 候选化并纳入风险守卫 | 成本、T+1及实际规则敏感 | 融合 | 纯候选策略；禁止自动执行 | 高 | 手续费、可卖份额、行情时间 |
| 网格 | `server/grid.py`, `LocalRules.swift` | `NextCandidatePlans.swift`, `server/grid.py` | 有计划算法 | 组合风险/资金检查较多 | 极端档位与部分成交复杂 | 融合 | F 单一计划算法调用Risk Guard | 高 | 最坏情形、部分成交、不改账 |
| 回本分析 | `NextCore.swift`, `PortfolioSummary.swift` | 同源 + `NextAIGuide.swift` 汇总 | 组合汇总基础 | 接入决策上下文更多 | 分红、费用、外部现金流口径须统一 | 融合 | 从真实流水重建成本口径 | 中 | 对账样例和边界回放 |
| 行情源 | `MarketDataService.swift`, `MarketDataProvenance.md` | `MarketDataSources.swift`, `MarketDataService.swift` | 有来源标注 | 来源偏好、回退状态及新鲜度更系统 | 外部源限流/时区仍待实测 | B胜 | 统一 Quote contract 和质量状态 | 高 | 来源、时间、异常、回退 |
| 批量行情 | `MarketDataService.swift` | `MarketDataSources.swift`, `NextAppModelState.swift` | 批量请求基础 | 聚合来源选择更完整 | 部分返回/代码对齐风险 | B胜 | 并发限流、逐项状态，拒绝串码 | 中 | 混合成功、乱序、缺项 |
| 分时 | `UnifiedChartView.swift`; NAS market API | 同图表 + `nas-advisor-compat/server/mobile_research.py` | 手机展现与数据接入 | 分钟质量筛选与长期档案 | 真实长期积累和覆盖率待NAS验证 | B胜 | B质量筛选规则经审后适配 | 高 | 交易日、缺失分钟、覆盖率 |
| 日K | `MarketDataService.swift`, `UnifiedChartView.swift` | 同源+缓存/来源偏好 `NextAppModelState.swift` | 图表已有 | NAS/手机来源与离线降级更清晰 | 复权/单位/交易日依赖供应源 | B胜 | 统一日K模型及前复权口径 | 中 | 缺口、重复、来源切换 |
| MA250 | `UnifiedChartView.swift`: 完整窗口判断 | `UnifiedChartView.swift`: 长均线与不足窗口降级 | 不足样本隐藏可避免误导 | 有可见不足样本提示 | 两边需统一窗口定义 | 融合 | 250根有效日线，明确不足状态 | 低 | 0/249/250/缺口样本 |
| IOPV | `UnifiedChartView.swift`, `MarketDataService.swift` | `UnifiedChartView.swift`, `MarketDataSources.swift` | 图层已有 | ETF资格/来源时效检查 | 上游未提供时不能推造 | 融合 | 只显示可验证 IOPV | 中 | ETF/非ETF、缺源、陈旧 |
| 盘口 | 未见可验证完整五档链 | 未见可验证完整五档链 | — | — | 供应源、时间与委托量质量无完整证据 | F重构 | 先定源契约和质量等级，再做UI | 高 | 五档对齐、陈旧、空数据 |
| NAS研究 | `server/workers.py`, `server/market.py` | `nas-advisor-compat/server/mobile_research.py`, workers | 有任务与研究端点 | 分钟档案质量、研究纯输出界限清楚 | B 68/68来自状态记录，非本次复跑 | B胜 | 移植统计纯逻辑，不复制服务整仓 | 高 | 计算、质量门槛、断网、重启 |
| 历史数据 | A NAS保存行情/相关性 | B NAS长期分钟档案与回放输入 | 历史图表/市场基础 | 数据质量和可见时间约束更具体 | 历史数据缺口与回填来源风险 | B胜 | 保存采集时间和来源，不反造数据 | 高 | 首次可用时间、缺口、回放隔离 |
| 跨市场 | `GlobalIndices.swift` 指数展示 | `nas-advisor-compat/server/cross_market.py` 研究和未来复现 | 用户能看全球市场 | 时间隔离、复现资格和禁止因果/授权 | 相关性仍非预测 | B胜 | 只作风险背景，不能单独生成买卖 | 高 | look-ahead、时区、样本偏差 |
| 新闻 | 未见同等的手机持仓新闻模型 | `NextNewsImpact.swift`, NAS `server/app.py` | — | 新闻来源/时间与持仓、记忆连接 | RSS可用性与误报须外部验证 | B胜 | 只收标题链接日期，证据分级 | 中 | 去重、陈旧、无来源拒绝 |
| 同步 | `NASService.swift`, `NextAppModel.swift` | `NASService.swift`, `NextAppModelState.swift` revision/fingerprint冲突保护 | 基础同步端点 | 冲突时不覆盖、先下载核对 | 网络失败/多设备并发仍待实机 | B胜 | 账本同步单写者/乐观版本校验 | 高 | 冲突、重复、回滚、并发 |
| 离线 | App模型/行情缓存 | `NextAppModelState.swift` 旧缓存+来源状态 | 有缓存 | 状态提示与回退偏好更多 | 陈旧数据可能被误读 | B胜 | cache携来源和有效期，显著标陈旧 | 中 | 飞行模式、超龄、时钟偏差 |
| 恢复 | `BackupDocument.swift`, `NextAppModel.swift` | `NextAppModelState.swift` 仓储安全副本与恢复入口 | 有档案备份 | 损坏保护与写前副本更细 | 多文件替换中断与跨schema仍需验证 | B胜 | F原子目录/事务恢复流程 | 高 | 损坏文件、写中断、旧档回滚 |
| 备份 | 本地文档与NAS能力 | 本地文档/NAS服务；远程灾备未验证 | 可导出 | 账本与研究路径分离更清晰 | A/B均无已验证跨设备源码灾备 | F重构 | 分别备份源码、研究、账本 | 高 | 校验、加密、恢复演练 |
| 通知 | `LocalNotificationService.swift` | 同名服务+时效/静默/去重约束 | 本地通知接入 | 触发边界更谨慎 | iOS权限、后台限制未真机验证 | B胜 | 只通知用户复核，不代表自动执行 | 中 | 授权、重复、静默、时区 |
| AI聊天 | `DeepSeekMobile.swift` | 同名模块+Key轮换修复 | 可调用在线AI | 凭证轮换和顾问流程约束较强 | Key链及网络均未E2E | B胜 | key安全组件+受控对话 | 中 | 密钥不落日志、断网/超时 |
| 导航 | `GuanpanAdvisorApp.swift`, 多页面视图 | 同名App路由+五主题Scene映射 | 页面成熟、业务覆盖广 | 场景主题切换更完整 | 当前无冻结点真机导航证据 | 融合 | F按任务层级简化导航 | 中 | 深链、返回、动态状态 |
| 图表 | `UnifiedChartView.swift` | 同名扩展图层，MA/IOPV等 | 图层功能已有 | 数据状态和更多层交互 | 同源代码并不等于可视化通过 | 融合 | 一个图表实现、主题token注入 | 高 | 触控、缩放、无数据、图例 |
| 横屏 | 统一图表/SwiftUI布局 | 同源结构+主题布局 | 共用布局基础 | 场景仪表盘有横屏潜力 | 无冻结截图可证效果 | F重构 | 独立横屏信息布局 | 中 | 横屏/安全区/方向锁定 |
| 设备适配 | `DesignSystem.swift` 字号/字体/组件 | `ThemeKit.swift`, `ThemeHome.swift` 五布局 | 动态字号/共享token | 主题路由与布局差异 | 无当前iPhone截图/实机结果 | 融合 | A可访问性机制+B布局供体 | 高 | 最小机型、动态类型、VoiceOver |
| 五主题体系 | A GPTheme system/light/dark/comfort | B `AppThemeCore.swift`, `ThemeHome.swift`, `ThemeKit.swift` | 共享组件、明暗外观 | 真正五种布局和场景切换 | B无本轮可核验主题截图 | B胜 | B五布局为供体，重做F截图验收 | 高 | 五主题同数据/明暗/设备 |
| 测试体系 | `FUNCTION_ACCEPTANCE_MATRIX.md`, XCTest/Python tests | 145项Matrix、Swift/NAS测试和CI | 功能矩阵与模块测试源码 | 验收追踪更严格、数据研究测试多 | B仍1✅/18🟡/126🟠，许多新增Swift未跑 | B胜 | 145条转F并清空证据状态 | 高 | 各迁入模块重跑+E2E |
| 工程维护 | Swift app model与NAS服务 | 同源app model继续增大、另拆模块较多 | 当前代码路径较集中 | domain/plan/memory分文件 | 同源耦合、兼容服务和双侧模型 | F重构 | clean module boundaries；一项能力一实现 | 高 | lint/build、依赖边界、契约测试 |

## UI主题逐项裁决

主题不是底层架构的附属选项。源码对比和视觉资产可用性已另列于 [F-MODULE-ADJUDICATION.md](F-MODULE-ADJUDICATION.md)。A 只能证实四种外观模式；它们不是五套布局主题。B 有五个布局组件和主题token，但缺少冻结提交可核验的本轮截图，因此以下是“代码供体裁决”，不是视觉质量验收。

| 主题 | A实现/证据 | B实现/证据 | 裁决 | F采用方案 |
|---|---|---|---|---|
| 东方编辑室 | `DesignSystem.swift` 可借共享token；A设计稿不是已实现五主题 | `ThemeHome.swift` EditorialHome、`AppThemeCore.swift` editorial | B胜 | B布局做供体，重做密度、色彩与截图；不照抄未验证细节 |
| 现代卡片 | `DesignSystem.swift` 共用卡片/字号 | `ThemeHome.swift` ModernHome、ThemeKit token | B胜 | B版式+A无障碍字号策略 |
| 交易仪表盘 | A dark 是外观模式，没有对应产品布局 | B DashboardHome，固定深底与高密度数据 | B胜 | 借鉴布局，F检查红绿色辨识、图表及横屏 |
| 杂志卡片 | A有方向预览但无对应实现布局 | B MagazineHome，衬线标题/留白表达 | B胜 | B作为布局供体，检查文本层级和重复摘要 |
| 创意拼图/Bento | A无对应实现布局 | B PuzzleHome，彩色拼图卡片 | B胜 | 先借鉴再以F真实数据重新设计，控制滚动负担 |

共同视觉裁决：彩色东方编辑室的温度来自 editorial 布局/暖色token；精密交易台的数据能力来自图表、来源新鲜度和风险层级；AI私人顾问用有证据、风险、等待条件和手工确认的交互表达。主题间共享业务数据，独立布局；不以换色冒充主题。

## 工程裁决

**唯一技术底座：Clean F。** A/B 原生代码有高度同源性，B 是叠加候选计划、记忆、画像、守卫、研究和五主题的扩展线。直接选 A 会丢失 B 的后续产品模块；直接选 B 会把未经迁移审计的账本 schema、状态协调和未验证增量整体带入。F 从纯净工程骨架建立单一领域模型与数据契约，再挑选供体模块，避免整仓复制与双实现。

按本矩阵 40 个业务模块 + 5 个独立主题项估算：**未经适配、原样复制的代码为 0 项；** 29 项裁为 B 供体（约 64%，包括五主题，但都要适配并重测），12 项融合（约 27%，其中吸收 A 的账本审计、快照失效和字号/token 等独有长处），4 项 F 重构（约 9%，迁移、盘口、跨设备备份、横屏专版）。A 没有整模块单独胜出，但 A 的供体能力明确进入融合方案。该估算按矩阵裁决项计数，不代表代码行数、工期或现有代码可直接粘贴；逐项采用须经代码审查和 F 测试。

## 首模块实施令

现在建立 Clean F 的独立 schema/data-model 模块，不复制 A/B 的持久化目录，不接真实账本，不自动计算/发布成交。首模块先定义 Decimal 金额、稳定ID、现金、持仓、真实成交记录、费用、现金流水及审计事件；候选计划、AI与研究对象不允许进入 ledger 写入接口。数据落盘、迁移工具和真实用户导入要等模型和校验测试就绪后另开有备份/报告的实现步骤。

External Pending：GitHub DNS、NAS、Mac/Xcode/Simulator/iPhone 实测。本地可推进项继续，不等待这些外部平台。

## 页面级 UI 实现裁决（独立于数据/业务底座）

以下检查覆盖冻结源码视图和可用 Preview 资产。A 的视觉稿是设计提案，不等于 SwiftUI 已实现或 Simulator 截图；B 的主题代码是实际实现，也不等于已通过真机验收。

| UI 部位 | A 实现/证据 | B 实现/证据 | 裁决 | F 的明确取舍 |
|---|---|---|---|---|
| Theme 定义/选择 | `ios/Sources/DesignSystem.swift`: GPTheme system/light/dark/comfort 四外观模式 | `Sources/AppThemeCore.swift`: 五个 AppTheme、五种场景、auto/fixed；`GuanpanAdvisorApp.swift` route resolve | B胜 | B 的主题/场景模型作供体；显示明暗模式与产品主题拆分成两层 |
| 颜色 Token | `DesignSystem.swift`: GPThemePalette、GPAppearance、共享语义色 | `ThemeKit.swift`: 每主题 palette，图表/风险色 token | 融合 | 吸收两者语义 token；明暗对比和涨跌语义重新统一 |
| 字体 | A `DesignSystem.swift`: 字族/字号档位/自定义外观 | B `DesignSystem.swift`: 动态字号 + 共用 GPScaledFont/组件 | 融合 | A 的外观配置思路+B 当前共享 scaled font，按 VoiceOver/动态类型重测 |
| 卡片 | A `GPCard`, `DataPanel`, `EditorialSection` | B 同名共享组件 + `GPAssetCards.swift` 的 Hero/Donut/Gauge/Plan 卡 | B胜 | 选用 B 卡片供体，删除重复展示和单纯装饰卡，保持组件语义统一 |
| 首页 | A `GuanpanAdvisorApp.swift`/Portfolio summary 单一产品布局；另有 SVG/HTML方向稿 | `ThemeHome.swift`: 同一 `HomeSnapshot` 驱动五个独立首页布局 | B胜 | B 五布局是供体，统一使用 F 的唯一账本和建议数据 |
| 持仓页 | A `PortfolioSummaryViews.swift`, `GPAssetCards.swift` | B `GuanpanAdvisorApp.swift` AssetsScreen + `GPAssetCards.swift` | 融合 | 留真实总资产、现金、成本和风险的清晰层级；只维护一套持仓页 |
| 行情/详情页 | A `IndexDetailView.swift`, `UnifiedChartView.swift`, `LocalRuleViews.swift` | B `GuanpanAdvisorApp.swift` MarketScreen/InstrumentDetailScreen/OrderBookView | B胜 | 借 B 页面密度与分区；盘口数据需通过数据源质量门后才能呈现 |
| AI 顾问页 | A `DeepSeekMobile.swift`, `PortfolioSummaryViews.swift` 与 advisor preview；详情样式较基础 | B `AIGuidanceViews.swift`, `NextAIGuide.swift`, `DecisionScreen`/AIChatScreen | B胜 | 采用证据→判断→风险→等待条件→手动确认的信息顺序；事实和模型解释分区 |
| 图表 | A `UnifiedChartView.swift` 与交互方向稿 | B 同名 `UnifiedChartView.swift`，增加指标/图层状态及主题色 | 融合 | 单一图表实现，F Quote/Chart 数据契约，五主题只定展示样式 |
| 导航 | A `GuanpanAdvisorApp.swift`: 五页原生导航、共享组件 | B 同文件路线增加 AI/决策/主题scene映射及 route | 融合 | 保留原生直达和返回语义，F 精简一级入口而非照搬更多页面 |
| Preview/设计稿 | A 有 `design/visual-directions.html`（四业务场景、明暗交互mock）、`design/观盘Pro-四页全新设计评审.svg`、`previews/观盘Next-五页界面预览.svg`；`ADVISOR_PREVIEW_STATUS.md` 是状态说明 | B 冻结源码树未找到主题截图或 SwiftUI Preview 资产；只有 AppIcon。五主题有源码而缺本轮渲染输出 | A胜 | A 资产作设计参考；另为每个 B 主题补真实渲染和 Simulator 截图，防止把稿件当验收 |
| 截图 | A 资产为 SVG/HTML mock，不是运行中的设备截图 | B 最新主题/详情改动无可核验最新截图，STATUS 也列 External Pending | F重构 | 建立 F 截图基准：同持仓、同行情时间、五主题、小屏/横屏/动态字体 |
| 主题切换 | A 只有四种显示模式切换，不具产品主题/场景切换 | B settings themeChip + `saveAppTheme`, auto/fixed 和 scene recommendation | B胜 | 采用 B 的选择模型，F 验收固定/跟随场景切换不改变数据与建议 |
| 深浅背景 | A system/light/dark/comfort 外观模式和深浅 token | B 五主题 palette；dashboard forcesDark；另有外观模式 | 融合 | 分离主题和明暗模式；dashboard 深色作为默认方案仍需用户偏好与对比度验收 |
| 设备适配 | A DynamicTypeSize 档位、字体族与页面间距 token；预览画布标注安全区，但声明不代表真机验证 | B `.dynamicTypeSize(...)` 与场景布局；五个首页组件，但缺主题截图 | 融合 | 用 A 无障碍字号机制与 B 多布局供体；以最小 iPhone、最大动态字号和安全区实测 |
| 横屏 | A HTML 方向稿明确全屏横屏图表、周期/图层/五档视觉例子 | B 有 FullscreenChartScreen 和图表，但未见锁向/本轮横屏截图证据 | 融合 | 横屏布局独立验收；A只作为交互参考，不把 mock 盘口当真实行情实现 |

A 的 visual-directions.html 明确写明逻辑画布和预览尺寸不代表模拟器/真机验证；画面里的行情、五档盘口和成交信息是视觉稿样例，不能作为接入真实行情证据。故 A 的预览资产只胜在设计评审材料覆盖，B 只胜在五种首页源码实现；F 的正式 UI 质量结论必须等 F 截图/真机验证。

## B 实际使用反馈裁决（F UI / 行情 / AI）

B Frozen 保持只读。代码存在不等于用户能够发现或顺利使用。

| 项目 | B 实际使用问题 | 裁决 | F 决策与验收 |
|---|---|---|---|
| 首页指数行情时间 | 曾持续显示“时间未知”；获取时间不能冒充行情时间 | F重构 | 区分行情时间/获取时间、来源、新鲜度、交易时段；闭市保留最后有效行情时间；缺源时间明确标未验证 |
| AI持仓问答入口 | 源码有问答控件，实际使用时输入入口不明显 | F重构 | 首页首屏展示输入、发送、快捷问题和组合上下文状态；详情入口带入证券；无提示可发现性验收 |
| 普通颜色自定义 | 文字背景和自由色盘参数过多 | F重构 | 五主题统一普通文字/页面颜色；仅保留涨跌、成本、均价、前收、IOPV、买卖点和风险等语义色 |
| 日K点击 | 可滑动，但点击单根K柱未能选中 | F重构 | 统一图表支持点击、长按十字线、拖动、缩放和横屏；覆盖边界/缩放命中测试 |
| 股息率4% | 默认阈值容易被误作机械合格门槛 | F重构 | 默认综合/AI研究；4%仅参考；自定义最低值放高级设置 |
| 首页卡片路由 | 用户要求采用B五种布局基线并让每卡职责独立 | B胜（布局供体）；F重构（职责与路由） | 每卡唯一目标；今日市场观察、跨市场脉搏、AI今日指导进入不同语义页面并实际点击验收 |
| 可发现性 | 源码有功能但实际入口/操作未自然显现 | F重构 | 首次使用者应能找到AI输入、历史分时、K线点选、时间/来源、AI依据和主操作 |


## NAS分钟源适配裁决更新（2026-10-26）

| 能力 | A Frozen | B Frozen | F 裁决 | F 执行结果与边界 |
|---|---|---|---|---|
| 沪深当日分钟采集 | 未发现优于现有接口的独立长期归档链 | B `workers.py`/`market.py` 使用腾讯当日分钟接口并维护沪深/跨市场行情任务 | **B wins（实时源供体）+ F Refactor（架构/归档）** | F 适配腾讯当日分钟响应到F MinuteBar、时间/成交量质量校验及SQLite归档；实网返回并写入当前分钟记录，状态Partial。未复制B服务整体。 |
| 历史分钟补采 | 未证明有可靠历史分钟源 | B minute-archive从运行日起采集，没有覆盖首次部署的长区间补采能力 | **F Refactor** | F新增东财精确交易日1分钟K线请求适配器并接入fallback队列；本云端实网请求超时，实际历史覆盖/接口限制未验，不能标PASS。 |
| 交易日历 | A冻结能力不足以用于F交易日级档案完整度 | B Frozen维护有来源说明的2026沪深和部分跨市日历，但按年静态维护 | **B wins（已核实2026日程供体）+ F Refactor（Fail-closed版本日历契约）** | F提供2026年沪深Asia/Shanghai日历与午休排除；未知年份拒绝生成交易日。未来官方日历更新和NAS端部署仍External Verification Pending。 |

数据源合同为非官方公开网页接口，格式可能变化；没有实际覆盖的日期保持Missing/Partial。

## 后续用户反馈及F原生App裁决

新增行情时间、AI问答发现性、主题色盘、K线点选、股息4%门槛、首页伪入口、五Tab与NAS部署包的A/B/F比较，见 [F-ARBITRATION-IOS-NAS-ADDENDUM.md](F-ARBITRATION-IOS-NAS-ADDENDUM.md)。B Frozen仍只读；F采用自己的实现与验收状态。
