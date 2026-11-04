# B → F UI 迁移矩阵

审计基线：用户提供的 `C:\Users\Administrator\Downloads\B-LATEST..zip`；包内冻结候选 HEAD `9ddfe32b787ad9e522a48eb55ff8231227d79599`，142 项 SHA256 校验全通过。仓库 `b-latest` 的 `caaa398eb267566db3c5764b6a146fab6d6e0ccf` 是后续修复，不替代归档基线。本地 `GuanpanNext-work/ios` 仅作旧副本；ZIP 与用户手机最终安装版是否完全一致仍未验证。此表记录可迁移体验，不表示把 B 业务代码并入 F。

状态定义：结构迁移采用用户要求的状态；F数据状态和视觉状态另列。Simulator/实机证据缺失时保持未验证。

| 页面 | B 布局/交互可借鉴内容 | F 必须保留/重构 | B 旧业务不迁移 | 当前 F 源码 | 结构迁移 | 已接 F 真实数据 | Simulator 验证 | 视觉状态 |
|---|---|---|---|---|---|---|---|---|
| 首页 | 明确的编辑标题、分层区段、紧凑资产指标、跨场景入口；注意候选B源码没有独立总览页，入口从行情开始，资产页内有摘要 | 以 F Portfolio Advisor、真实资产、Quant/Trigger、风险和可选NAS为唯一数据输入；保留F自己的首页路由 | 模拟账户、虚拟盈亏、数字孪生入口 | GuanpanFApp/Sources/HomeExperience.swift HomeLayout / FEditorialMasthead / FEditorialMarketRibbon / HomeAdvisorLead / FEditorialResearchLine / HomePortfolioLead；GuanpanFApp/Sources/GuanpanFApp.swift FHomeRoot | 首轮已编码并通过Run 73编译 | 已接F真实Ledger、Advisor与持仓/自选行情；自动快速Quant未完整 | 截图已导出；人工审阅/交互未验证 | 仅源码层承接B的编辑页眉、市场先览和层级节奏；仍未判视觉接近B |
| 行情 | 指数带、输入代码、全部/自选/持仓筛选、列表来源/时效、行滑动快捷动作、空状态 | 自选与真实持仓分离；只读行情数据；F每10秒行情状态 | 自动真实交易、虚拟撮合 | HomeExperience.swift MarketOverview | 已定位B源码 | 已接F真实持仓/自选/腾讯报价请求；全局搜索和B完整列表体验待评估 | 未验证 | 用户反馈不如B；无法证明接近 |
| 证券详情 | 单证券上下文连续组织报价、状态、图表、研究/AI、持仓操作；快捷刷新、关注和全屏入口 | F Episode/Broker双成本、日内/本轮/Lifetime/T语义、候选与确认成交边界、质量和来源状态 | B的旧账本成本算法、旧模拟计划、未验证盘口值 | HomeExperience.swift HomeDestination；FUnifiedSecurityChart.swift | 已定位B源码 | 部分：F行情、Ledger、Advisor、Candidate源码已接入页面 | 未验证 | 用户反馈不如B；无法证明接近 |
| 分时/K线图表 | 固定A股日内时间轴、清楚的图层显隐、量能/副图、十字选择、缩放/平移、横屏全屏与日期入口 | F的唯一 FUnifiedSecurityChart、真实来源和质量、可见overlay共同定轴、成本双口径、无假IOPV/前收/均价 | B旧来源/价格语义；绝不复制第二renderer | GuanpanFApp/Sources/FUnifiedSecurityChart.swift | 已定位B源码 | 部分：F当前行情/日K/NAS历史精确日期输入存在；真实NAS历史覆盖无证据 | 未验证；iPhone Air未验 | 用户明确认为F图表差；不能称接近 |
| AI私人顾问 | B 的结构化输入、结论/证据/风险层次、证券上下文、决策复盘入口 | F组合/证券scope、Risk/AI Guard、Candidate快照、Quant/Shadow及只读真实Ledger | B模拟策略/自动委托/虚拟成交 | HomeExperience.swift AdvisorOverview / AdvisorComposer；GuanpanFApp.swift Advisor pipeline | 已定位B源码 | F本地Ledger/行情上下文已接；新闻源未接，DeepSeek真实闭环未验证 | 未验证 | 用户认为F整体不如B；不能称接近 |
| 真实资产 | 资产摘要、持仓拆分、现金与成交入口、补录已有持仓、审计和确认交互 | F的不可变fills、Episode、手续费更正、券商成本录入、Daily/Episode/Lifetime/T独立语义 | 旧成本/账本计算，模拟资产和虚拟账户 | HomeExperience.swift RealAssetsOverview；GuanpanFApp.swift FConfirmedLedgerWriter | 已定位B源码 | F真实Ledger读页/流水已接；目前没有独立手动录入持仓/真实fill入口 | 未验证 | 用户反馈F资产/整体UI不如B；不能称接近 |

## 操作顺序

1. 已取得并核验用户提供的 Frozen Candidate ZIP；若要认定与手机B同版，仍需同版本截图/构建身份，不阻塞源码供体迁移。
2. Frozen源码地图已建立；以 ZIP 内实现校正旧审计，旧副本仅作历史旁证。
3. 首页第一轮结构迁移已编码，Run 73对该SHA的Device/Simulator Build和UI XCTest全通过；复用F模型与业务路由，没有搬入B策略/账本代码。截图已导出，待人工视觉审阅。
4. 先在可交互 Simulator 取得 B参考、F旧版、F新版截图，再决定是否将结构方案推广到其他页。
5. 只有截图审阅/操作完成，才能从“已定位B源码”推进到“已完成结构迁移”“Simulator验证”或视觉接近/达到/超过B。

## 2026-11-02 逐页状态校正

| 页面/能力 | 固定B Frozen源码对照 | 当前增量 | 视觉判断 |
|---|---|---|---|
| 首页 | `ThemeHome.swift` 多布局共享HomeSnapshot；B确切手机版身份未证 | 本轮未改首页布局 | F不如B，未新验 |
| 行情/自选 | B完整筛选/列表与统一设计系统可作donor | F加真实分钟sparkline和有样本门槛的描述分 | 已编码未编译/未截图；不判胜 |
| 证券详情 | B在单证券上下文/层级组织可借鉴，F数据字段保留 | 本轮未改 | F不如B，未新验 |
| 分时/K线 | B `UnifiedChartView.swift` 为统一交互donor；绝不复制B数据业务 | 本轮未改图表 | F不如B，手势和视觉未验 |
| AI Advisor | B共享DesignSystem与结构化区段；F保留真实DecisionContext | NAS可选文案清理 | DeepSeek实网/引用未验 |
| 真实资产 | B页面组织可借鉴；F唯一真实Ledger | 本轮未改 | F不如B，真机未验 |
| 设置/主题 | B `DesignSystem.swift` 全局tokens | F折叠低频区，主题选择保留 | 已编码未编译/截图；全主题跨页未验 |
# Historical / Superseded — 2026-11-04

This matrix records the former B→F donor plan. It is retained as historical audit context only. B Frozen is no longer the UI visual source of truth. Current UI acceptance follows user-approved mockups; see `F-MOCKUP-TO-SWIFTUI-MATRIX.md`.
