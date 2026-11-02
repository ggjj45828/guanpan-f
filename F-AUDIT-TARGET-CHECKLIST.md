# F 全盘审计目标清单

> 本清单以当前远端 `main` 为准，逐项记录源码核对、可执行验证和外部验收证据。`源码已确认`不等于运行通过；旧 SHA 的测试结果不自动继承到新 SHA。

## 本轮基线

- 审计日期：2026-11-02（Asia/Shanghai）
- 审计开始时 HEAD / `origin/main`：`c6ba442835d712b444c27d158aefdc5f1aecdf04`；开始时工作树干净且与远端一致。后续审计修改见本清单及工作树差异。
- 最新 iOS 证据：Run 224，SHA `f1f2c291…`，FCore 335/335、UI XCTest 12/12、XcodeGen、Device/Simulator Build 和 IPA 流程通过。当前 HEAD 是文档/CI触发器提交，不改变该次验证过的 Swift 源码；该证据不能代替当前 SHA 的新 UI 视觉验收。
- 最新 NAS/Python 证据：Run 28，提交 `c6ba442…`，306 项、compileall、架构边界通过。
- 本机验证：Home/追踪定向合同 30/30；本机全量Python导入曾受环境依赖影响并被中止，不记为全量通过。
- Simulator 导出截图未人工逐页审阅；iPhone Air真机、图表手势、NAS指定日期数据、真实新闻可达性、DeepSeek真实E2E仍需实测。

## 核对状态定义

- **源码确认**：已在当前树找到实现或边界，尚未因此证明运行正确。
- **自动验证通过**：指定提交的实际测试/CI通过；需注明SHA和范围。
- **不达标—待修**：发现可复现或明确的实现缺口，需先修复再关闭。
- **外部待验**：需要Apple设备、真实账户、NAS/公网服务或人工观察。
- **未核**：本轮还没有足够证据，不得报成通过。

## 审计目标逐项清单

| ID | 审计目标 | 当前源码/证据 | 状态 | 下一步/修复要求 |
|---|---|---|---|---|
| A01 | 真实账本为持仓与现金唯一事实源 | `Sources/FLedgerWrite/LedgerWriteBoundary.swift` 的 `FConfirmedLedgerWriter`；快照来自 `Sources/FCore/LedgerSnapshot.swift` | 源码确认；完整回归需逐项核 | 检查所有写调用均经过确认写入边界，重放、恢复、迁移和现金守恒测试逐类核验 |
| A02 | Candidate、Quant、Advisor不得写Ledger | Advisor生成与确认成交路径位于 `GuanpanFApp/Sources/GuanpanFApp.swift`；确认后才创建 writer | 源码确认；CI覆盖不等于端到端 | 搜索所有写入者和调用图；测试Candidate触发/过期/取消均不改账本 |
| A03 | 初始真实持仓录入入口可发现 | `RealAssetsOverview` 在未建账时显示“录入现有持仓”；`ledger.opening-snapshot.begin`；首页另有入口；UI测试 `PrimaryNavigationUITests.swift` 检查入口/表单 | 源码确认；Run 224 UI 12/12，但实机发现性未验 | 真机核实入口层级与录入持久化；若用户仍找不到，首页保持明显入口并调整文案/位置 |
| A04 | 已建空账本可登记真实成交开仓 | `ledger.manual-fill.begin`；说明只记券商已成交；不向券商下单 | 源码确认 | 核对确认弹窗、必填校验、重启恢复及UI可发现性 |
| A05 | Episode经济成本、券商展示成本、每日/当前/累计盈亏语义分离 | Ledger/Advisor上下文及证券详情字段存在 | 源码确认；真实对账未验 | 逐条复核成本更正、清仓重开、同日卖完重买和历史费用回算测试 |
| A06 | T Contribution只来自可验证T配对/标签 | Daily trade facts、T配对逻辑及Advisor防混用提示存在 | 源码确认；边界组合逐项待核 | 核对先卖后买、先买后卖、部分回补、交错成交及生命周期亏盈反向场景 |
| A07 | 手续费事后更正不可变、现金差额可审计、历史盈亏重算 | 资产页有逐笔费用更正入口；ledger事件/有效费用路径存在 | 源码确认；所有恢复与清仓场景未逐项核 | 检查买卖手续费更正、部分卖出、清仓后/重开后修正及恢复重放一致性 |
| A08 | Candidate Shadow与真实账户结果分离，成功失败都留档 | `Sources/FAdvisor/CandidateShadowScorecard.swift` 和App观察/成交关联调用存在 | 源码确认；市场观测生产采集完整性待核 | 检查WAIT、未触发、过期、行情缺失、执行关联和不可变快照；确认零成交绝不入Ledger |
| A09 | 市场行情定时刷新和视图更新 | `FHomeRoot` scene active时立即刷新，并在连续交易时段每10秒刷新 | 源码确认 | 核实 refresh 是否覆盖报价、指数、图表 series；确认失败保留旧值同时标Stale，而非误报新鲜 |
| A10 | 分时图时间轴与报价点对齐、缩放/拖动流畅 | `FUnifiedSecurityChart.swift` 有统一分时/日K、坐标与手势绘制 | 源码确认；用户截图已显示早盘时间标签挤在一起/未固定的历史问题 | 需对当前实现核对轴刻度算法；设备人工连续缩放/拖动仍外部待验 |
| A11 | 日K有MA5/10/20/60/250、VOL、MACD且可控显隐 | 统一图表源内存在MACD副图、MA/VOL渲染和图层控制 | 源码确认；布局可用性未验 | 检查窄屏图例宽度、MACD位置/占比、图表有效绘图区；按截图人工确认后再关闭 |
| A12 | 图表成本线语义明确 | 统一图表含本轮成本、券商成本overlay路径 | 源码确认 | 验证图例、颜色token、清仓/无成本/券商成本未录入状态；设备截图待验 |
| A13 | 均价、前收、IOPV与溢折价使用真实可信来源 | 缺来源或不新鲜时UI显示Unavailable；禁止伪造 | 不达“可用”产品目标，但安全降级达标 | 盘点B真实行情provider字段映射；没有可靠现有来源时保持不可用，明确标数据缺口，不用算法假造 |
| A14 | NAS连接失败能区分DNS/TLS/超时/HTTP及服务契约错误 | 客户端20秒超时和错误分类已实现；真实设备曾返回HTTP 200但历史分钟schema不匹配、兼容路径404 | 源码确认；真实连接/接口契约不达标待修 | 对照NAS实际部署API schema与iOS decoder；不要把 `/readyz` 200等同历史API成功；取得新手机原始状态后定位 |
| A15 | NAS为可选增强，不阻断本地Quant/基础Advisor | 最新决策为本地优先；设置说明称NAS不可达不阻断实时行情/基本分析 | 源码确认；逐调用故障隔离待核 | 搜索advisor/Quant主调用路径，检查NAS异常只产生缺证据状态，不使主请求失败 |
| A16 | NAS历史日期只显示真实数据和完整性 | exact-date查询decoder和Unavailable状态存在；此前用户截图显示HTTP 200字段不匹配且旧接口404 | 不达标—服务契约/真实数据 | 修复前先确认部署API真实响应字段；验证指定日→bars→coverage→图表完整链，不显示假线 |
| A17 | 新闻源真实、可达、带来源/时间/链接并能进入AI上下文 | `FNewsClient`为同花顺公开网页接口；Advisor提示要求只引用上下文新闻；App显示失败/空状态 | 源码确认；手机真实可达性未验 | 实机连接验证source、publishedAt、URL和证券关联；无结果时不得让模型用记忆冒充新闻 |
| A18 | Advisor使用真实组合/证券scope和数据新鲜度 | `FHomeModel`有portfolio/security scope和Ledger/quote evidence准备 | 源码确认；真实DeepSeek链未完成 | 验证组合问题不被详情证券覆盖；缺Ledger/行情时安全拒绝或降级；DeepSeek请求和Guard做实网E2E |
| A19 | Guard、候选计划有效区间和失效规则 | Guard/量化状态模型已有代码与回归 | 源码确认；生产实时报价驱动触发器待核 | 检查行情Stale时暂停、离开价格区不追价；验证计划生命周期状态和候选版本不可变 |
| A20 | 自选证券加入/移除、打分、曲线与自动更新 | MarketOverview支持搜索及watchlist入口；本轮尚未核实Quant评分/自选走势图是否完整接线 | 未核 | 沿UI→model→quote refresh追踪每个字段；缺Quant分值/迷你图则按既定本地确定性规则修复，不增加模型黑盒 |
| A21 | 首页第一屏信息层次与主题对应布局 | HomeLayout含10个family renderer；首页核心role组件存在 | 不达标—视觉验收；用户持续反馈丑/层级乱 | 逐主题截图审阅首页布局、信息层级；只针对可见问题调整，CI截图不能替代手工审阅 |
| A22 | 一个主题在全App颜色/排版/卡片/导航一致 | 全局`@AppStorage`主题驱动manifest/token，页面使用共享theme | 源码部分确认；跨页面一致性未验证 | 已修复跨市场指数涨跌标签硬编码红/绿，改用正/负语义token；仍需逐主题截图抽查首页、行情、证券详情、AI、资产、设置的背景、字色、间距、导航 |
| A23 | 10主题不是换色；保持全App结构和信息职责 | 10个theme/layout family及HomeLayout renderer存在；Settings gallery可折叠 | 源码确认；灰度构图与各页覆盖未验 | 建立各主题×核心页面截图矩阵；三套标杆先完成，未有截图证据不得写达标 |
| A24 | 设置页信息密度、滚动与主题栏不混乱 | 设置为SwiftUI List分组，主题选择横向条、全部预览折叠 | 不达标—截图反馈显示行高/字段换行与长说明占用过大 | 压缩次要说明、把NAS/数据高级状态分组折叠，保留错误主状态；必须对比新旧截图后验收 |
| A25 | 键盘输入可收起且不遮挡操作 | 行情搜索有FocusState与“收起键盘”按钮；表单键盘关闭路径需逐页检 | 部分源码确认 | 搜索所有TextField/Form，统一有提交/关闭手段并可滚动至确认按钮；UI Test/Simulator验证 |
| A26 | 五个主Tab互不混淆、返回栈保留 | 五个主Tab各自NavigationStack；Run224 UI 12/12 | 自动验证通过（Run224旧Swift SHA）；手工返回状态仍待验 | 真机检查切主题/切Tab返回原路由、选中的证券和图表周期/日期是否保留 |
| A27 | App显示名、图标、IPA | Run224 IPA交付门检查通过，观盘max及AppIcon纳入编译产物 | 自动验证通过（Run224） | 用户安装后仅处理实机安装差异；当前无须继续改包线 |
| A28 | 隐私、安全与禁止自动交易 | 无券商下单路径的设计边界、Keychain、确认成交入口存在 | 源码确认；全仓安全扫描未完成 | 搜索URLSession请求中账本泄漏、secret/fixture及任何自动下单代码；修复发现的高风险项 |
| A29 | B→F成熟UI不退化 | B源码地图、gap audit、non-regression清单存在；B真实UI对照已部分记录 | 未达成，F当前整体视觉不如B（用户实际反馈） | 按首页→行情→证券详情/图表→AI→资产逐页对照源码与截图，迁移成熟布局而不复制B业务逻辑 |
| A30 | XCTest定义/执行/通过数如实登记 | Run224 335/335 FCore、12/12 UI；Run28 306 Python | 指定Run通过；设备人工验收External Pending | 新提交每次记录对应SHA与真实执行数；绝不把定义数写成执行数 |
| A31 | Simulator截图人工审阅与iPhone Air验收 | 仅有CI截图导出证据，无本轮人工查看/真机触摸证据 | 外部待验 | 取得artifact截图逐页查看；可交互Apple Simulator/iPhone Air时验收滚动、手势、长文本和状态恢复 |
| A32 | NAS、实时行情、新闻、DeepSeek、真实成交全链E2E | 现有源码分别有客户端/协议/边界，但无完整同一真实账户端到端证据 | 外部待验 | 明确分段验收证据：服务→iOS数据→DecisionContext→DeepSeek→Candidate→人工真实成交→Ledger复判 |

## 本轮已发现并立即修复

| 项目 | 核查结果 | 修复 |
|---|---|---|
| 追踪合同是否随 acceptance matrix 变更触发NAS/Python CI | 旧流程曾漏掉追踪矩阵变更，导致B-058源码锚点过期后CI失败 | `.github/workflows/f-python-nas.yml` 已增加两个追踪矩阵文档到push/PR paths；Run 28对当前 `c6ba442…` 实际通过306项、compileall和边界检查 |
| 初始持仓入口是否缺失 | 当前源码并非完全没有：首页/真实资产均有未建账录入入口，已建空账本时有真实成交开仓入口，且UI测试检查录入表单标识 | 不改Ledger语义；把“已实现/设备发现性待验”列为明确项，避免错误宣称不存在或已完全解决 |
| 图表MACD是否缺失 | 当前源码已有MACD计算、绘制和副图切换；但此前截图可能未选择MACD，图表体验仍有尺寸/布局问题 | 记录为“能力存在，发现性/比例待验”，继续逐主题视觉验收 |
| 主题语义涨跌色是否统一 | 跨市场指数摘要原先直接使用系统红/绿，绕过主题语义色 | 已改为 `positive` / `negative` semantic token；待Apple CI编译与深浅外观截图确认 |

## 后续逐轮处理顺序

1. 当前远端代码先做静态风险扫描：Ledger写入口、现金/费用、Candidate边界、Stale/Partial/Missing降级、secret/自动交易路径。
2. 完成行情/图表的源码链路审计，优先修复可以由当前代码证实的轴标签、拥挤、次图布局缺陷。
3. 按六个核心页面逐主题查看截图并修正明显问题；未有可视化证据的主题不关闭。
4. 对NAS历史API、新闻、均价/前收/IOPV分别做实际provider契约核验；无法从当前环境证明的保持Unavailable并记录外测步骤。
5. 更新 `F-REALTIME-HANDOFF.md` 与 `F-MASTER-ACCEPTANCE-MATRIX.md`，每个完成项绑定当前提交/测试/截图证据。
