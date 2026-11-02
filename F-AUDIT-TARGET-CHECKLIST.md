# F 全盘审计目标清单

## 2026-11-02 当前全盘细微Bug审计（HEAD 3f930f0基线；本节优先于后续历史状态）

| ID | 发现 | 证据 | 集中修复 | 验证/状态 |
|---|---|---|---|---|
| BUG-01 | Advisor用于DecisionContext的IOPV溢价，可能使用Tencent参考响应自身价格，和本轮Quant报价不同步；即使两个源各自新鲜也可跨时点混算 | `GuanpanFApp/Sources/GuanpanFApp.swift` 的 `.iopv` observation过去基于 `reference.latestPrice`，而同一循环Quant使用 `quote` | 要求 `reference.observedAt <= quote.quoteTimestamp`；用 `quote.latestPrice` 与该IOPV算溢价；不满足则不注入 | 已编码；未编译、未跑Swift测试、未实机验证 |
| BUG-02 | Tencent日K没有完成状态字段；同一交易日临时OHLC/close可进入Local Quant及Regime/指数联动，日期午夜时间戳会掩盖未完成事实 | `FTencentDailyKlineParser`将 `day` 行作为普通bar；Quant以前按日期年龄接受；Regime摄取端以前直接使用所有行 | Local Quant始终排除报价当地日期及未来日K，避免仅凭时钟推断供应商已定稿；证券Regime按上海日期过滤；跨市场Regime按各自交易所时区过滤并以截断bars计算指数基准；原始bars仍保留给图表 | 已编码；未编译、未跑Swift测试、未实网回放 |
| BUG-03 | NAS历史分钟HTTP 200解码失败时，只显示顶层字段清单，不能定位嵌套字段缺失/类型错误 | `FNASHistoricalMinuteClient.fetch`过去以`try? decode`吞掉具体`DecodingError`，实机提示无法对应模型中的具体字段/路径 | 现在保留原响应摘要，并附`DecodingError`的coding path、缺失字段或期望类型；HTTP 200错误仍直接报告首个端点，不用旧兼容404覆盖 | 已编码；未编译；需要下一次实机查询确认诊断与真实payload吻合 |
| EXT-01 | NAS历史分钟真实部署契约未通过：用户设备曾收到HTTP 200但字段与iOS decoder不符，并有兼容路径404 | 用户截图/错误文案记录于历史交接 | 本轮不猜服务端payload、不修改NAS部署；须用实际部署响应对齐契约 | 外部待验；不能标完成 |
| EXT-02 | 同花顺新闻公开接口与Advisor引用真实可达性无当前设备E2E | 源码有来源/时间/链接校验和上下文约束，但无实机请求/真实回答证据 | 保留无新闻时明确降级；需联网设备验真 | 外部待验 |
| EXT-03 | iPhone Air视觉、连续缩放/拖动、手势与导航冲突未人工实测 | Windows环境无Simulator；旧截图不等于当前HEAD | 等待可交互Apple设备，不能以CI截图导出替代 | 外部待验 |
| EXT-04 | DeepSeek→Candidate→用户确认成交→Ledger→Advisor复判无真实E2E | 当前只有源码路径和旧提交CI记录 | 需真实设备/Key/用户确认成交流程逐环验证；禁止Candidate写Ledger | 外部待验 |

### 本轮范围与证据限制

- 这是源码静态审计和修复；本轮没有运行任何测试或Swift编译，也没有新增测试。当前HEAD的旧CI不覆盖本轮dirty Swift改动。
- GitHub只读API确认远端`main`为`a1ba64582c29340596d5f5f1639ebc5478a5186c`，是本地提交链祖先；Actions queued/in_progress均为0。源码修复提交`19590bd`及本交接记录提交后，本地`main` ahead 6。普通push因`getaddrinfo() thread failed to start`失败；未强推、未触发CI。
- 这轮没有把所有产品级外部验收（主题截图、B/F同态对照、NAS、新闻、iPhone Air、DeepSeek真实闭环）伪装为代码Bug已修复。

> 本清单以当前远端 `main` 为准，逐项记录源码核对、可执行验证和外部验收证据。`源码已确认`不等于运行通过；旧 SHA 的测试结果不自动继承到新 SHA。

## 本轮基线

- 审计日期：2026-11-02（Asia/Shanghai）
- 审计开始时 HEAD / `origin/main`：`c6ba442835d712b444c27d158aefdc5f1aecdf04`；开始时工作树干净且与远端一致。
- 本轮开始基线 HEAD / GitHub `main`：`a1ba64582c29340596d5f5f1639ebc5478a5186c`，经GitHub提交列表确认；工作树开始时干净。
- 最近可复核的 iOS 证据：Run 225 [41404815642](https://github.com/ggjj45830/guanpan-f/actions/runs/41404815642)，FCore 335/335、UI XCTest 12/12、XcodeGen、Device/Simulator Build、截图导出、IPA校验/打包/上传通过。Artifact 13123048046对应其实际代码SHA；不是本轮新Swift修改的验证。CI截图尚未人工逐张审阅。
- 最近可复核的 NAS/Python 证据：Run 29 [41404817391](https://github.com/ggjj45830/guanpan-f/actions/runs/41404817391)，306项、compileall、架构边界通过；其与当前SHA的包含关系需按Actions记录核对，不把数字自动继承到后续修改。
- 静态修复：跨市场摘要涨跌颜色已从硬编码系统红/绿改用主题 `positive` / `negative` semantic token；Run 225已编译验证。
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
| A20 | 自选证券加入/移除、打分、曲线与自动更新 | 已有每10秒报价刷新；当前改动新增只读Local Quant方向因子均值（要求新鲜报价且≥3个有效因子）及基于真实分钟样本的紧凑迷你线；尚未Swift编译/CI | 编码未验证 | 当前改动需Apple CI；随后看行情列表截图与实机刷新。分数只叫方向观察分，不代表收益概率或交易建议 |
| A21 | 首页第一屏信息层次与主题对应布局 | HomeLayout含10个family renderer；首页核心role组件存在 | 不达标—视觉验收；用户持续反馈丑/层级乱 | 逐主题截图审阅首页布局、信息层级；只针对可见问题调整，CI截图不能替代手工审阅 |
| A22 | 一个主题在全App颜色/排版/卡片/导航一致 | 全局`@AppStorage`主题驱动manifest/token，页面使用共享theme | 源码部分确认；当前SHA CI通过，跨页面一致性未验证 | 已修复跨市场指数涨跌标签硬编码红/绿，改用正/负语义token；仍需逐主题截图抽查首页、行情、证券详情、AI、资产、设置的背景、字色、间距、导航 |
| A23 | 10主题不是换色；保持全App结构和信息职责 | 10个theme/layout family及HomeLayout renderer存在；Settings gallery可折叠 | 源码确认；灰度构图与各页覆盖未验 | 建立各主题×核心页面截图矩阵；三套标杆先完成，未有截图证据不得写达标 |
| A24 | 设置页信息密度、滚动与主题栏不混乱 | 本轮将投资者画像输入、数据诊断、研究细节改为折叠；NAS高级说明原已折叠；未编译/未截图验证 | 编码未验证 | Apple CI与新旧设置页截图；确认主要状态、主题选择、NAS地址与持仓入口没有藏进高级折叠 |
| A25 | 键盘输入可收起且不遮挡操作 | 行情搜索有FocusState与“收起键盘”按钮；表单键盘关闭路径需逐页检 | 部分源码确认 | 搜索所有TextField/Form，统一有提交/关闭手段并可滚动至确认按钮；UI Test/Simulator验证 |
| A26 | 五个主Tab互不混淆、返回栈保留 | 五个主Tab各自NavigationStack；Run224 UI 12/12 | 自动验证通过（Run224旧Swift SHA）；手工返回状态仍待验 | 真机检查切主题/切Tab返回原路由、选中的证券和图表周期/日期是否保留 |
| A27 | App显示名、图标、IPA | Run224 IPA交付门检查通过，观盘max及AppIcon纳入编译产物 | 自动验证通过（Run224） | 用户安装后仅处理实机安装差异；当前无须继续改包线 |
| A28 | 隐私、安全与禁止自动交易 | 本轮对Swift源码搜索下单/订单路径、明文Key模式和`FConfirmedLedgerWriter`调用点：未发现券商下单接口或硬编码密钥；6处writer调用用于券商成本/现金/费用人工确认、初始账本、Candidate确认成交、手工成交 | 部分静态扫描通过；URLSession出站数据字段与全部间接调用仍未完整审计 | 继续逐个检查所有外发请求的payload、日志与错误文案，确认无账本/持仓泄漏；扫描fixture和构建产物后才能关闭 |
| A29 | B→F成熟UI不退化 | B源码地图、gap audit、non-regression清单存在；B真实UI对照已部分记录 | 未达成，F当前整体视觉不如B（用户实际反馈） | 按首页→行情→证券详情/图表→AI→资产逐页对照源码与截图，迁移成熟布局而不复制B业务逻辑 |
| A30 | XCTest定义/执行/通过数如实登记 | Run225 335/335 FCore、12/12 UI；Run29 306 Python，均对应当前SHA | 当前SHA指定CI全部通过；设备人工验收External Pending | 新提交每次记录对应SHA与真实执行数；绝不把定义数写成执行数 |
| A31 | Simulator截图人工审阅与iPhone Air验收 | Run225截图Artifact 13123048046已导出；无本轮人工逐张查看/真机触摸证据 | 外部待验 | 取得artifact截图逐页查看；可交互Apple Simulator/iPhone Air时验收滚动、手势、长文本和状态恢复 |
| A32 | NAS、实时行情、新闻、DeepSeek、真实成交全链E2E | 现有源码分别有客户端/协议/边界，但无完整同一真实账户端到端证据 | 外部待验 | 明确分段验收证据：服务→iOS数据→DecisionContext→DeepSeek→Candidate→人工真实成交→Ledger复判 |

## 本轮已发现并立即修复

| 项目 | 核查结果 | 修复 |
|---|---|---|
| 追踪合同是否随 acceptance matrix 变更触发NAS/Python CI | 旧流程曾漏掉追踪矩阵变更，导致B-058源码锚点过期后CI失败 | `.github/workflows/f-python-nas.yml` 已增加两个追踪矩阵文档到push/PR paths；Run 28对当前 `c6ba442…` 实际通过306项、compileall和边界检查 |
| 初始持仓入口是否缺失 | 当前源码并非完全没有：首页/真实资产均有未建账录入入口，已建空账本时有真实成交开仓入口，且UI测试检查录入表单标识 | 不改Ledger语义；把“已实现/设备发现性待验”列为明确项，避免错误宣称不存在或已完全解决 |
| 图表MACD是否缺失 | 当前源码已有MACD计算、绘制和副图切换；但此前截图可能未选择MACD，图表体验仍有尺寸/布局问题 | 记录为“能力存在，发现性/比例待验”，继续逐主题视觉验收 |
| 主题语义涨跌色是否统一 | 跨市场指数摘要原先直接使用系统红/绿，绕过主题语义色 | 已改为 `positive` / `negative` semantic token；待Apple CI编译与深浅外观截图确认 |
| 自动下单与Ledger writer入口首轮扫描 | Swift源码内未命中下单接口/订单路由或明文密钥模式；6个writer call site均对应用户发起的账本更正、初始快照或成交确认 | 首轮边界扫描未发现自动交易路径；完整外发请求数据审计仍开放 |

## 本轮修复闭环

| 修复 | 源码 | 验证 |
|---|---|---|
| 跨市场指数摘要不跟随主题的问题 | `GuanpanFApp/Sources/HomeExperience.swift` | 当前SHA `edd14a3` 的iOS Run 225通过；CI仅证明构建与自动测试，不证明截图视觉检查完成 |

## 仍未达标/待外部验证（不得写成完成）

- A13/A16：均价、前收、IOPV和指定日NAS历史分钟仍缺当前设备真实来源/响应证据；Unavailable安全降级保留。
- A17：同花顺新闻实现存在，但真实设备可达、文章链接/时间和Advisor引用链未验。
- A20：自选加入/移除和行情已接线；自选确定性评分及自动迷你趋势图没有被确认完整接线，缺口保持打开，不以未经验证的因子均值造分。
- A21–A24/A29：主题层与10套首页自动截图存在；当前没有人工灰度构图、跨页面一致性或B/F逐页截图对照，不能宣称视觉达标。
- A31/A32：Simulator截图虽由Run 225导出，但未人工逐页查看；iPhone Air、NAS实机、DeepSeek及真实成交E2E仍External Pending。

## 后续逐轮处理顺序

1. 当前远端代码先做静态风险扫描：Ledger写入口、现金/费用、Candidate边界、Stale/Partial/Missing降级、secret/自动交易路径。
2. 完成行情/图表的源码链路审计，优先修复可以由当前代码证实的轴标签、拥挤、次图布局缺陷。
3. 按六个核心页面逐主题查看截图并修正明显问题；未有可视化证据的主题不关闭。
4. 对NAS历史API、新闻、均价/前收/IOPV分别做实际provider契约核验；无法从当前环境证明的保持Unavailable并记录外测步骤。
5. 更新 `F-REALTIME-HANDOFF.md` 与 `F-MASTER-ACCEPTANCE-MATRIX.md`，每个完成项绑定当前提交/测试/截图证据。

## 2026-11-02 后续逐项复核（当前工作树）

- 本轮开始先从GitHub确认 `main` 为 `a1ba64582c29340596d5f5f1639ebc5478a5186c`，工作树干净。`a1ba645` 的Combined Status未返回status检查；它是审计记录提交，不得继承Run225的Swift验证为本轮新增代码的CI。
- **A20 自选评分与趋势（编码中，未编译）：** 自选行现在改为紧凑真实分钟迷你线；报价仍由既有10秒行情轮询刷新。新增方向观察分仅聚合新鲜报价下可用的Local Quant方向因子，少于3个因子或报价过期则显示样本不足；文案明确分数不是收益概率/策略信号。新增新鲜度和最少样本回归。当前Windows缺Swift/Xcode，未执行FCore XCTest，也未生成新截图；须进入Apple CI后再复核实际构建与UI。
- **A24 设置密度（编码中，未编译）：** 画像编辑、数据诊断、高级研究细节折叠；投资者画像保存/清除可见性UI测试已加展开动作。NAS配置/测试和主题选择保持直接可见。未做Simulator截图对比，不能声称视觉验收通过。
- **A22/A23 全主题跨页一致性：** 本轮没有足够截图逐一核对10主题×首页、行情、证券详情、AI、资产、设置。源码中虽使用共享manifest/token，仍记未验；不能用全局环境修改完成度替代逐页证据。
- **A29 B/F逐页视觉对照：** B冻结源码文件地图与需求记录可用，但当前没有同设备、同状态的B/F逐页人工截图证据。本轮未声称达到B；逐页面比较仍未验，CI screenshot export不算审阅。
- **A16 NAS历史分钟实机契约：** 已知用户手机截图返回HTTP 200但schema与iOS契约不一致，兼容路由返回404；当前环境没有用户NAS部署响应样本/地址与iPhone网络。此项没有修复或实机通过证据，仍是外部待验。`/readyz`只证明ready，不代表指定日期分钟可读。
- **A17 新闻真实可达与顾问引用：** 源码有新闻客户端及DecisionContext引用边界，但本轮没有手机网络响应、标题/来源/发布时间/URL或真实DeepSeek请求证据；仍未验。若Google/新闻域名在用户网络不可达，必须基于实际设备错误换成可达源；不能以CI通网或编译通过代替。
- **A31 iPhone Air验收：** 当前为Windows环境，无可交互Apple Simulator或iPhone Air。本轮没有启动真机，也没有触控/视觉验收；外部待验。
- **A32 DeepSeek→真实成交闭环：** 没有可供本轮使用的真实用户DeepSeek密钥会话、Candidate执行、用户确认券商成交与复判证据。不得自动交易/模拟成交；仍未完成。
- 本轮新Swift/UI代码尚无编译、测试或截图结果。外部待验项不因源码修改关闭。下次必须先检查Actions队列数量（并行不超过2），再推送该具体SHA；等待其实际结果，首错修复后再重跑。

## 2026-11-02 逐项目标复核（本轮增量；覆盖本文件较早的冲突性旧状态）

### 新增微小缺陷：行情与Regime观察时间错配

- 风险：只检查Regime相对当前时钟足够新，无法防止旧/乱序报价搭配报价之后才观察到的Regime状态，形成决策时间穿越。
- 修复：本机Quant的证券/映射指数Regime以及实时Trigger均要求研究证据时间不晚于输入行情时间；违规安全降级为WAIT/暂停，不产生交易触发。
- 同类修复：IOPV观察时间必须不晚于对应报价时间，防止用之后的IOPV给旧报价计算溢价。
- 回归锚点：`LocalQuantEngineTests.testRegimeEvidenceLaterThanQuoteCannotInfluenceLocalQuant`；`RealtimeQuantTriggerTests.testRegimeEvidenceLaterThanQuoteCannotTriggerFromOlderQuote`。
- 实测：相关静态合同82/82通过，格式检查通过；Swift/XCTest当前环境未执行，等待Apple CI。该项在Apple CI通过前不可标记为已验证。

| 目标 | 当前检查/实际修改 | 状态与仍需证据 |
|---|---|---|
| 自选评分与自动趋势图 | `MarketOverview`沿用每10秒行情刷新；自选行由报价快照中的真实分钟样本绘制48pt趋势线。新增`FLocalQuantAssessment.watchlistDirectionalScore`：报价必须fresh且至少3个有效方向因子；样本不足不显示分数，且文案明确不是收益概率/交易信号；增加稀疏/过期单测定义。 | 已编码；本机Swift执行0、当前SHA Apple编译0；刷新连贯度和可读性未视觉验收。 |
| 设置页密度 | 画像编辑、数据诊断和低频研究信息已折叠；NAS地址/测试及主题入口保持可见；UI测试加入先展开画像区。 | 已编码；未编译、未运行UI测试、未截图。 |
| 全主题跨页面一致性 | 共用`guanpan.f.homeTheme`由首页、行情、图表、顾问、资产/设置等读取；共享语义tokens已使用。但跨页背景/表面/导航/字体/Dynamic Type覆盖不等于只共用一个key；图表坐标仍见系统secondary色。 | 部分源码一致；主题×页面视觉验收未执行，不能关项。逐主题检查首页、行情、证券详情/图表、顾问、资产、设置及浅/深/护眼仍待做。 |
| B/F逐页视觉对照 | Frozen donor精确来源为用户包SHA `9ddfe32b787ad9e522a48eb55ff8231227d79599`；本轮再次读取该SHA的`ThemeHome.swift`、`UnifiedChartView.swift`、`DesignSystem.swift`。B使用共享palette/environment、5种首页renderer、统一图表/图层交互及动态字号；对读了F当前市场列表/主题/图表。 | 已有源码静态对读；无B/F同设备同状态截图；按用户真机反馈仍判F不如B。逐页视觉退化关闭0项。 |
| NAS历史数据实机契约 | NAS `/api/v1/minute-history`查询参数和当前iOS decoder静态相符；旧手机截图曾报HTTP 200字段不合及兼容路由404。此环境访问不到实际部署容器与iPhone穿透响应。 | 仅代码契约静态匹配；指定日覆盖、bars数量、时间戳、Partial/Complete和图表显示External Pending。未改NAS服务端，无需部署。 |
| 新闻真实可达与顾问引用 | `FNewsClient`使用同花顺公开网页接口；后台缓存后将证券关联的标题/来源/发布时间/HTTPS URL作为只读news observation；Advisor只可引用输入标题，不得冒充全文，缺新闻不阻塞基础分析。 | 源码链已核；当前设备实际响应、相关新闻关联和DeepSeek引用无实证，External Pending。 |
| iPhone Air验收 | 当前Windows无Xcode/可操作Simulator/iPhone Air；旧CI截图只是artifact。 | External Pending；本轮人工截图审阅/触控证据0。 |
| DeepSeek真实成交闭环 | Candidate、Guard、用户确认成交后的writer及Quant重算源码路径存在；本轮无真实DeepSeek会话、券商成交及复判证据。Candidate不能写Ledger。 | External Pending；需真实行情+DeepSeek+用户确认真实成交同链记录，不用模拟fill冒充。 |

最新远端核对（本轮结束）：GitHub `main`仍为`a1ba64582c29340596d5f5f1639ebc5478a5186c`；检查前30条Actions活跃数0。当前审计修复已在本地提交`c93ea4cb2667f9dff945b3a68f9376a809d71f51`，未推送。普通`git push origin main`连续两次在本机网络层失败：`getaddrinfo() thread failed to start`；GitHub连接器仍可读取远端，但不代表本地push成功。Apple CI未运行，当前Swift变更未编译/测试。

方向观察分边界补充：`watchlistDirectionalScore`是对当前可用、带波动归一化的因子分数做等权均值，至少3个因子且实时报价fresh时显示。它不是经过历史验证的预测评分/胜率，UI已明确标注“方向观察分”；“自选评分有效性”仍待真实历史验证，不得称为已验证AI评分。

补充：本轮将`FUnifiedSecurityChart.swift`坐标/网格/副图标注/十字线/图层中性颜色接入当前主题secondaryForeground token。静态改动已做，未编译、未截图；不得关闭A22/A23。

## 2026-11-02 本轮源码审计增量（基于本地 HEAD b65ee7c，dirty）

- 本地分支 `main` 当前 HEAD `b65ee7c9bd7275a9a03089a10e4b310aec62cdac`，比本地记录的 `origin/main` 超前2个提交；当前有未提交源码与追溯修改。此次没有fetch/push、没有新Apple CI，也没有Swift编译器，旧CI结果不覆盖这批修改。
- 图表A10：实时分时的横轴改为按当天实际观测分钟扩展，午休保持压缩时间映射；分钟样本断档超过2.5个交易分钟时断开绘线，避免跨空数据假连线；窄屏标签间距提高。代码和静态合同已改，尚未Swift编译/Simulator/手机验收。
- NAS A14/A16：iOS历史分钟旧兼容路由现在仅在新路由返回404/405时尝试。HTTP 200契约错误、5xx/其他状态直接保留首个端点诊断，不再叠加旧路径404掩盖原因。新增 `Tools/test_nas_client_contract.py` 源码合同。它改善错误定位，不等于修复实际NAS部署版本或取到历史分钟。
- NAS可选架构：本地Quant未认证策略参数的状态/理由不再命名为“NAS验证未完成”；改为“本机策略参数包尚未接入/未通过本机验证”，仍安全保持WAIT/不生成交易候选。同步Advisor合同及F-145 B-043测试锚点，防止旧矩阵把NAS写成核心前置。
- 实际验证：当前本地定向合同73/73通过；排除需要PyYAML而当前运行时未安装的两个工具测试模块后，全其余仓库工具测试295/295通过；NAS Python `compileall`通过；`git diff --check`需先修复B-043表格行尾空格后再记最终状态。当前Swift编译/测试、Apple CI、截图人工审阅均为0。
- 未关闭：自选分数的预测有效性、全主题跨页视觉一致、B/F同状态逐页对比、均价/前收/IOPV真实供应商、NAS部署端实际payload与手机历史分钟、新闻实际可达并被DeepSeek真实引用、iPhone Air真机、真实DeepSeek→真实成交→账本→复判闭环。需要相应设备、部署数据或真实服务，不能由静态修改关闭。

## 2026-11-02 续审状态

- 本轮设置页已把NAS明确降为可选服务，并显示新闻最近请求状态；Home源码契约28/28及NAS/Local Quant/Advisor/Traceability合同41/41通过。一次宽套件尝试出现错误且无正常总结，不记作通过。
- 自选真实分钟迷你线、条件性方向观察分、持仓录入/成交建仓入口、MACD切换源码已定位。观察分不是回测胜率；真机可发现性及刷新/图表体验仍待验。
- 仍未过：全主题跨页截图一致性；B/F同设备逐页视觉比较；NAS指定日期真实HTTP payload与iPhone穿透；同花顺新闻设备可达并经DeepSeek引用；iPhone Air验收；DeepSeek真实成交到账本及Advisor复判。
- 远端main为`a1ba64582c29340596d5f5f1639ebc5478a5186c`，GitHub API显示最近Actions活跃0；本地fetch失败，未推送、未跑当前SHA Apple CI。不能把旧CI继承为本轮编译结果。
