# F Master Acceptance Matrix

## 当前工作树续更（2026-10-28；以本段为最新状态）

- NAS队列静态查漏发现容器重启会重排`permanent_unavailable`/`out_of_provider_coverage`终态。当前已修正为自动启动保留终态，显式补采仍可重试；Python定向用例2/2通过。未做真实NAS部署验证，历史provider覆盖没有变化。
- 已生成`../F-NAS-QUEUE-RETRY-FIX.zip`（20文件、56,680字节；ZIP完整性及关键NAS源码存在检查通过），供用户部署修复；未构建Docker镜像、未部署NAS。

- 本轮编码逐笔手续费事后更正：追加`FFillFeeAdjustment`、现金补录日结算、有效手续费与成本basis重放、只读历史/日汇总/realized/T投影、现金流水更正行、用户确认Writer入口与资产页简单更正表单；旧fill不改。新增6项Ledger回归测试定义（含旧周期清仓卖出补扣/退费、重开Episode隔离及Archive恢复）。全项仍未Apple编译/执行，详见实时交接和F-145。

- 新增多主题/多布局架构设计：[F-THEME-LAYOUT-MANIFEST-DESIGN.md](F-THEME-LAYOUT-MANIFEST-DESIGN.md)。既有5套首页分支加上5个新增方向，共规划10套；Theme/Layout Manifest注册、共享role renderer及Simulator结构差异验收均尚未实现/验证。该事项排在当前Ledger、Apple CI、NAS历史分钟iOS链路和DeepSeek闭环之后，不新增主题Swift代码。

- 手续费更正实现/测试已提交于`a84c41976ed094a5fe91b8d9185167b848a8a836`，同步验收文档也已提交。远端已指向转移后的`ggjj45830/guanpan-f`，最新fetch因DNS thread启动错误失败，远端实时状态未知；本地存在未推送提交，受保护临时目录未动。
- T Contribution现按时间排序和FIFO批次只匹配先卖后买的实际配对份额；1000卖/500买回只计500及按比例卖出费；普通卖出/减仓不当作T；买回早于卖出或买回量超过此前剩余卖量保持Unavailable。源码/测试位置：`Sources/FCore/DailyTradeSummary.swift`、`Tests/FCoreTests/LedgerSchemaTests.swift`。
- FCore测试定义方法当前静态计数138。当前工作树compile、XCTest执行、passed/failed均无执行证据；旧CI #41 `40622847995`（130/130）仅验证`7a2d63e`，不能覆盖T FIFO或手续费修正。App/UI旧CI数据同样不验证本轮Swift修改。本机无Swift/Xcode/XcodeGen。
- 事后手续费修正已编码，仍未编译/执行：原始fill和原始`costBasisRemoved`保持不变；追加事件负责补录时现金结算，经济投影按有效费用回算basis/已实现和Episode结果。新增6项测试定义，覆盖买入费用补录/冲回、部分卖出basis、卖出手续费、跨Episode隔离、清仓卖出手续费补扣/退回、Writer/Archive恢复和负现金原子拒绝。UI XCTest/Simulator验证仍缺。
- NAS历史分钟进入iOS/Research Evidence、DeepSeek真实E2E、Candidate→确认成交→Ledger→Advisor复判、Simulator人工手势/视觉仍未通过真实端到端验收；人工Simulator为External Pending。

## 当前工作树状态（2026-10-28；优先于下方历史快照）

- Tools全量Python现有测试本轮实际执行112项：105 passed / 2 failed / 5 errors。失败/错误来自Windows POSIX目录fsync不兼容及运行时缺PyYAML；详见实时交接。此结果不能表述为全部通过。
- NAS分钟定向测试最近一次真实执行97项：92 passed / 2 failed / 3 errors。localhost和硬链接限制在较宽权限重跑后解除；剩余均为Windows目录fd/fsync差异，Linux NAS/CI待验证。较早受限执行为89/2/6；均非全套NAS通过。
- 当前F源码状态以本地工作树为准，HEAD为`5f2a1f7`；最近一次可成功读取的`origin/main`跟踪点为`7a2d63e`，本地领先7个提交。`git fetch origin main`本轮仍因`getaddrinfo() thread failed to start`失败，因此此跟踪点不是远端实时证明；没有推送/强推。Tracked Swift/NAS源码干净；本次矩阵与交接文档尚未提交。锁定临时目录`.task-python-temp-b252c94955274b7c90bce865b594fca4/`原样保留。
- 最近可核实的旧代码CI run `40622847995`：FCore 130 defined / 130 executed / 130 passed / 0 failed；XcodeGen、Device Release Build、Simulator Build、App UI XCTest 3/3、截图导出及未签名IPA步骤成功。该CI验证源码提交`7a2d63e`，**不包含之后本地新增的T Contribution成交顺序保护**。
- 当前FCore仍定义130个测试；相对该CI新增的T顺序实现尚未编译/执行，当前修订的验证状态为0 executed / 0 passed / 0 failed；不能把旧CI的130/130套用于当前HEAD。App UI定义3项，最近旧代码CI 3/3成功；这不等于本地后续FCore修改后的App重新Build/UI通过。
- 用户日志`logs_110101703179.zip`：FCore 130项中1项失败，原因是旧断言错误期待清仓后Broker Display Cost变为nil，实际保留`10.35`符合证券级对账语义。后续`logs_110103476656.zip`中FCore 130/130通过，但Device Build首错是`HomeExperience.swift:354` Optional类型缺上下文；该项后来由`7a2d63e`修复，run `40622847995`提供后续全绿证据。
- 本地Windows没有Swift/Xcode/XcodeGen/Simulator。无本轮人工Simulator/真机验收。Python/NAS最近可用证据为定向77/77 passed（非全套；环境受限项未计通过）；本轮未重跑。实时分钟有NAS部署归档证据，历史分钟provider空响应/断连，历史分钟NAS→iOS→Research Evidence仍未E2E；真实DeepSeek及成交后AI复判未E2E。
- 已完成的当前源码审计：T Contribution原实现只核对周期总卖出/买回数量，未约束实际顺序；当前本地版本已按成交时间逐笔确认先卖后买、买回数量不超过尚未买回卖出量，并增加反序回归断言。该修正仅为已编码/未验证。Advisor与FLedgerWrite依赖隔离，Candidate不能直接写Ledger；真实fill仍要求用户填写实际成交和显式确认。
- 费用差额对账的边界已登记：原fill不变，成交费用修正追加审计事件；现金差额在补录时结算，证券成本/损益按原成交事实确定性回算。当前只有成交时录入实际fee及券商显示成本纠正；事后fee adjustment模型/UI/测试尚未实现。安全重放设计需要处理历史卖出`costBasisRemoved`严格校验，不得只补现金流水。
- 当前最高缺口：①把T顺序修正送Apple CI；②事后手续费差额与原成交日盈亏/剩余成本的一致回算；③NAS历史分钟进入iOS并供Research Evidence/DecisionContext使用；④Simulator人工交互/视觉验收；⑤真实DeepSeek Candidate→用户成交→Ledger→重新判断闭环。

## 最新实时CI与工作树状态（2026-10-27 15:19 Asia/Shanghai）

## Ledger盈亏口径增补（2026-10-27）

| 交叉追踪 | F源码/测试 | 当前状态 | 仍需验证 |
|---|---|---|---|
| B-018 / B-027 / B-029 / B-130 / B-145：本轮主成本与券商成本分离；Security Daily P&L、Episode P&L、日已实现、Lifetime P&L、T Contribution分离；同日清仓后买回不重置全天盈亏 | `Sources/FCore/SecurityPnLFacts.swift`; `Sources/FCore/DailyTradeSummary.swift`; `Sources/FCore/LedgerSchema.swift`; `Sources/FLedgerWrite/LedgerTransactions.swift`; `Sources/FAdvisor/DecisionContext.swift`; `GuanpanFApp/Sources/HomeExperience.swift`; `GuanpanFApp/Sources/FUnifiedSecurityChart.swift`; `Tests/FCoreTests/LedgerSchemaTests.swift` | 已编码，未Apple编译/未执行新增测试。当前FCore 129项defined，最近真实执行仍为旧CI 121/121 | 可靠前收/期初数量供给、隔日场景、Broker成本多轮修正/对账、Advisor逐问句字段选择、Simulator UI与真实行情验收；不得把Unavailable改成推算值 |

- Run `40463891229` / `5169df6`：FCore 121/121 passed；XcodeGen、Device Build、Simulator Build成功；App UI XCTest失败（Actions UI Test步骤耗时4m59，详情页面仅显示exit code 65，首个断言尚未取得）。
- 当前待CI设置表单修正：Form增加 `settings.form`，测试针对该容器滚动并验证NAS按钮可点击；测试失败路径明确输出容器accessibility树后退出。不降低断言标准。
- F-145跨市场验收设计已补充时区/日历/DST、no-lookahead、相关/领先/共同风险区分、证券级滚动画像、底层资产与场内ETF溢价条件分离、wait/no-trade和完整Evidence元数据。本项仍未编码/实证。
- 本轮修改未编译；本机无Apple工具链。当前阶段优先触发CI并拿到失败断言，不将自动Simulator启动记作人工验收。

## 最新实时CI与工作树状态（2026-10-27 14:38 Asia/Shanghai）

- Actions run `40460442070` / commit `773608d`: FCore **121 executed / 121 passed / 0 failed**；XcodeGen、Device Build、Simulator Build成功；App UI XCTest **3 executed / 2 passed / 1 failed**。
- 首个且唯一失败为 `PrimaryNavigationUITests.swift:54`，设置页表单尚未滚动到NAS连接区时查询NAS按钮。测试现改为滚动到按钮并要求其 `isHittable`；修改待CI执行，不能记为通过。
- 当前工作树有未提交UI测试修改；本机没有Apple工具链。此前截图导出成功，但截图图像未人工检查。详见 `F-REALTIME-HANDOFF.md`。以下较早CI记录仅为历史证据。

## 实时状态覆盖（2026-10-26；以下旧快照保留作历史）

> 2026-10-27 Actions run `40343237878` 对已提交HEAD完成FCore 121/121、工程生成、Device/Simulator Build；UI主导航用例失败，具体断言日志未取得。本机仍无Xcode且fetch/push受网络限制；当前dirty Swift修改未编译。远端CI曾成功执行，不能称CI整体不可用。

- 当前 F 工作树：`main` / `4d258f199c7575f84251154b8929c30fba271508`，不以该 commit 代替实时源码状态。当前工作树有未提交改动；明细以 `F-REALTIME-HANDOFF.md` 为准。
- Apple CI：最新可见run `40343237878` 对已提交源码执行FCore 121/121、XcodeGen、Device/Simulator Build；App UI测试失败。Annotation仅给出exit code 65，精确断言待原始日志。当前工作树dirty Swift代码不在该run中。
- 本地无 Swift/Xcode/XcodeGen。当前工作树最新 Swift 改动是 Advisor 组合意图优先修正，尚未编译/执行；不得记为通过。当前 NAS/Python改动也没有本轮新测试结果。
- A/B/F追踪表现已补充逐项核验字段。145条的源码/测试位置是按F验收映射给出的候选锚点，仍需逐条确认；A源码当前不可读，B状态不继承，所有F条目仍不得据此宣称通过。
- 本轮静态复核：真实Ledger流水重放/episode保留、候选与真实写账边界、统一图表renderer接线未发现已确认的架构性违规；图表交互/旋转、实时数据质量、AI/NAS/DeepSeek端到端仍未通过运行验收。

## CI续记（2026-10-26 19:43 Asia/Shanghai；覆盖较早运行快照）

- run `40315965909` / `016a1a3`：FCore 121/121、XcodeGen、Device/Simulator Build、App UI 3/3、截图导出和IPA均通过。
- 截图人工确认日K图可见并含真实日K、MA与量柱；历史分钟截图与日K仍相同，故历史分钟可见性/日期切换没有通过人工验收。
- 新本地未提交：强制历史区滚动、资产摘要防横向截断、简化日K时间轴标签。尚未验证，不改验收状态。

## CI续记（2026-10-26 19:32 Asia/Shanghai；覆盖下方旧快照）

- 当前已推送提交 `c96a17e` 的 Actions run `40314328798`：FCore 121/121通过；XcodeGen及Device/Simulator Build成功；UI 3执行、2通过、1失败（详情日K标题经8次滚动仍不可见）；截图导出成功、IPA跳过。
- 当前本地改动：统一图表Canvas的拖动改用 simultaneousGesture，避免阻断外层详情滚动。尚未编译/测试，验收项不更改状态。Python/NAS未执行。

## CI续记（2026-10-26 19:20 Asia/Shanghai；覆盖下方旧快照）

- HEAD `1c10912` 已推送；当前源码后续修改未提交，尚无其编译/测试证据。
- Actions run `40312257829` 对应提交：FCore 121/121通过；XcodeGen、Device Build、Simulator Build成功；UI XCTest 3执行、2通过、1失败（一个测试用例内两个标题可见断言失败）；截图导出成功；IPA跳过。
- UI失败表明证券详情日K、历史分钟标题未被当前滚动方式滚动到可见。新本地修正未验证；不把矩阵需求改绿。Python/NAS本轮未执行。

## 最新实时验证覆盖（2026-10-26 18:20 Asia/Shanghai）

- 本地工作树 HEAD `1c10912e8d1c2a0b6fdc3720b73f6fada28c5e20` 相对 origin/main ahead 1；CLEAN；该本地UI/窄屏布局修正尚未推送或验证，不更改任何验收项为通过。
- 最新远端成功运行 `40305133985` 对应 `04b0deb`，UI XCTest 3/3通过并导出8张截图；截图人工查看发现刷新行右侧裁切、页面滚动未被旧用例验证到，故相应可用性验收仍未通过。
- FCore最近明确工件结果来自run `40303339340`：121/121 passed、0 failed。当前本地HEAD不含于该运行。精确当前提交测试状态：FCore 121项defined，当前提交executed=0/pass=0/fail=0；UI 3项defined，当前提交executed=0/pass=0/fail=0。旧CI结果保留为追溯证据，不继承到新代码。
- 本轮 Python/NAS未执行。Simulator视觉通过、图表数据/交互通过、真实服务联调及真机仍待验收。

本矩阵由 F 产品红线、A/B Frozen 源码裁决、F 自身实施范围及 B 版 Master Acceptance Matrix 的 145 项需求共同形成。B 145 项需求追踪见 [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)：保留原编号和需求来源，逐项标注 F 处理结论；不继承 B 实现状态或测试证据。A/B 的测试结果都不算 F 通过。每项先标为 `defined`；只有 F 自身执行并保留证据后才能更新为 `executed`、`passed` 或 `failed`。外部条件另标 `external pending`。

## 当前 F 验证快照（2026-10-26）

FCore XCTest：121 defined / 121 executed / 121 passed / 0 failed；两项图表价格范围回归已在Actions run `40303339340`通过。App UI XCTest：3 defined / 3 executed / 3 passed / 0 failed，但该结果对应本轮新UI代码改动之前的版本。XcodeGen、Device/Simulator Build和未签名IPA成功。Simulator截图附件及证券代码查询导航刚加入，待下一轮CI验证；空账本未注入虚构持仓，真实Episode详情仍未做数据级验收。

| ID | F 验收范围 | 状态 | F 验证证据 |
|---|---|---|---|
| F-01 | 唯一真实账户；不含模拟账户、虚拟资金或自动真实交易 | defined | 尚未执行 |
| F-02 | 账本 schema 版本、稳定 ID、输入校验和拒绝未知版本 | defined | 首版数据模型与 XCTest 已定义；FCore目标119项整体已在run 40298657796执行并通过，旧账本迁移/设备验收仍待专项验证 |
| F-03 | 现金以用户确认的流水为事实，逐事件无透支且可重放对账 | defined | 已编码 opening balance 与确认资金流水的现金投影；本轮 119 项 FCore XCTest 实际执行通过，但完整产品迁移/设备流程仍待验收 |
| F-04 | 持仓份额、成本、买卖与费用守恒；部分卖出按加权平均分摊；清仓关闭当前 Position Episode 并保留 Security/流水；重买新建 Episode，当前成本不混入旧周期 | defined | `FPositionEpisode`、历史表现投影与清仓/重建仓/现金流水模型已编码；相关 FCore 回归包含在 Actions 119/119 通过结果中；真实旧账本迁移和设备验收仍待验证 |
| F-05 | 成交仅由明确用户确认写入；失败不得改变源状态 | defined | FLedgerWrite 独立模块提供用户确认写入口；App 对 Guard 通过的单笔买入/卖出 Candidate 提供需填写实际成交与确认说明的显式入口，写前重新核对账本摘要并由原子 writer 持久化；Advisor 不依赖写模块。做T/网格/回本不自动写入；Swift/本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-06 | 成交幂等、重复 ID/序号拒绝、审计摘要可校验 | defined | 重复成交 ID/序号校验、事件重放和审计摘要已编码；本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-07 | 候选计划、AI 建议、报价和研究数据不能改账 | defined | FAdvisor 无 FLedgerWrite 依赖；快照读取接口只读；架构边界脚本通过；解码后的Research/Memory/Profile投影须匹配Context与范围并通过no-lookahead/结构校验；新增投影回归已定义、本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-08 | 成本分摊、舍入、部分成交与已实现损益规则明确 | defined | 当前 Episode 成本、已实现/未实现/累计表现只读投影已编码；Ledger Episode XCTest 包含于 Actions 119/119 通过；真实交易对账待外部验证 |
| F-09 | 持久化原子性：成功落盘后才发布 UI 状态 | defined | 临时文件、fsync、锁、原子替换、回读校验及失败回滚已编码；并发 store 写回归包含于 Actions 119/119 通过；文件系统故障/设备重启仍未验证 |
| F-10 | 迁移先备份、dry-run、校验、幂等、可回滚并出报告 | defined | A/B只读dry-run、来源摘要、幂等收据、显式确认导入和拒绝替换已有账本已编码；Python dry-run安全套件6/6通过；Swift 本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-11 | 恢复、备份和损坏检测不得静默覆盖较新账本 | defined | 校验备份/恢复、expected digest 并发保护、损坏检测和显式恢复已编码；本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-12 | Decision Memory 保存决策时证据与后来事实，解释变化 | defined | 版本化记录、受限投影、分段 generation、恢复和 no-lookahead 已编码；App 在完成 Guard 后持久化 Context/Decision Memory，并在下一次问答按作用域读取受限投影；在线链路及 XCTest 未验证 |
| F-13 | Investor Profile 有来源、置信度、修订/撤销与学习边界 | defined | 来源/置信度/解释、显式值保护、临时属性过期、修订及受限投影已编码；App 请求现通过 assembler 读取既有 Profile 投影，但尚无原生编辑/撤销 UI；本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-14 | DecisionContext 数据新鲜度、时点与来源可追溯 | defined | Observation、Quote、Research Evidence 来源/时间/质量门控已编码；本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-15 | Risk Guard 与 AI Guard 可阻断不合规候选并说明原因 | defined | 现金、仓位、报价新鲜度、证据引用、上下文绑定及成本溢出 fail-closed 已编码；模型层约束未接入；本轮 FCore 119 项已实际执行并通过；该验收项仍需专项/外部验收 |
| F-16 | AI 最终建议串联真实持仓、行情、新闻、研究和风险证据 | defined | 原生App接入DeepSeek候选provider、NAS质量门控Evidence、实时分钟报价、只读Ledger快照、DecisionContext与Risk/AI Guard；组合意图优先纳入全持仓/现金/逐证券行情与研究，即使提及单只证券仍保持组合范围；无合格同标的NAS研究时阻断资产变更候选；新闻仍显式不可用；Swift/iOS/在线服务未验证 |
| F-17 | T、网格、回本仅为 AI 可调用分析工具，不自动交易 | defined | NAS 历史分析函数和 Advisor 研究工具调用边界已编码；NAS Provider编排已绑定响应身份/范围/时点/质量；回本候选仅允许绑定真实持仓并以分析文本表达，拒绝下单字段；网格要求同标的合格gridSpacingReplay；做T因盘口/VWAP/双边费用上下文未齐而fail-closed；真实持仓策略适配未完成；FCore 119项全量已在Actions执行通过，但策略和真实服务适配仍待专项验收 |
| F-18 | 行情、批量行情、分时、日 K、MA250、IOPV、盘口标注来源/新鲜度 | defined | Tencent实时分钟行情与NAS历史分钟已接入；新增Tencent未复权日K解析/蜡烛/MA5/10/20/60/250；FCore统一分时/日K、Unavailable/Partial/Stale、IOPV及价格叠加DTO已定义并约束状态一致性。统一`FChartOverlayModel`仅将有来源的成本/均价/前收/IOPV/Candidate叠加层纳入同一可视纵轴，Unavailable不生成伪线；FUnifiedSecurityChart已由当前/历史分钟和日K页面共用，并随App Device/Simulator Build编译（run 40298657796）；实线包含真实持仓成本和Candidate，MA/量柱编码完成；均价/前收/IOPV因无可靠源保持Unavailable，真实图表视觉/手势仍待专项验收 |
| F-19 | NAS 历史研究、跨市场和新闻与真实账本隔离 | defined | NAS v6已部署；2026-10-27 14:11:49实机六证券各归档191条当前日分钟、过滤13:00盘外行，真实实时采集/归档烟测通过；指定过往日期历史补采返回empty source response（当前配置未补齐），跨市场/新闻/iOS端到端和长期运行仍未验证。跨市场非对称条件概率与证券级映射仅登记于F-B-145-TRACEABILITY.md研究口径，尚无实现/合格样本，不能进入DecisionContext |
| F-20 | 同步、离线冲突、通知与恢复状态可见且不丢账 | defined | 三通道策略已编码；传输、离线队列、通知 UI 和恢复体验未实现；FCore 119项全量已执行通过，但这不覆盖缺失的产品功能 |
| F-21 | AI 聊天、导航、图表、横屏和设备布局可用 | defined | 原生五Tab与独立NavigationStack、真实账本/行情、AI顾问输入和结果页已接线；当前/历史分钟和日K已复用共享SwiftUI renderer。App UI XCTest 3/3通过（run 40298657796；覆盖导航、Advisor主要控件和资产页基础结构）；图表功能/视觉、横屏和设备布局验收仍未完成 |
| F-22 | 五个独立主题的 token、页面一致性、可读性和设备截图验收 | defined | 五主题首页布局分支和基础颜色已编码；设计token完整性、主题差异质量、一致性与设备截图验收未完成；未继承 A/B 主题结论为通过 |
| F-23 | 单一权威实现、模块边界、依赖和故障可诊断 | defined | FCore/FAdvisor/FLedgerWrite 依赖隔离；架构边界脚本当前通过；Actions run 40298657796 已完成 FCore 与 App Device/Simulator Build；后续修改仍需重跑 |
| F-24 | 核心测试按模块执行，记录 defined/executed/passed/failed | defined | 账本 XCTest 已定义；FCore XCTest：119 executed / 119 passed / 0 failed（Actions run 40298657796）；各产品验收项仍按实际覆盖范围判定 |
| F-25 | NAS历史分钟补采、实时归档、完整度、长期留存、查询、诊断和研究证据/no-lookahead | defined | 归档/补采/查询/研究链已编码；累计量差分来源必须保留累计量且差值匹配分钟量；归档启动/完整性/备份恢复校验、no-clobber备份、版本化队列和严格HTTP输入/授权边界已覆盖；交易日历、日期、时区、幂等、Partial门控、指定日期Missing/Partial逐日诊断和范围隔离有回归；无范围时列出已评估coverage日期并明确可能低估；分钟服务27/27、归档43/43、红利研究7/7、只读迁移dry-run6/6、Provider/Calendar/runtime10/10，合计93/93通过；腾讯当日接口已实网取样并写入F归档；东财历史接口本云端超时、生产交易日历与NAS部署仍待外部验证 |
| F-26 | 指数卡区分行情时间、获取时间、来源、新鲜度和交易时段；闭市保留最后有效时间 | defined | Quote元数据与最大有效期校验已编码；首页有独立市场入口但当前行情明确 unavailable；现金状态文案区分读取中/未建立/不可读取/已读取；FCore整体119项CI通过，真实源/闭市行为与原生显示仍待验收 |
| F-27 | 首页显著提供组合问答输入、发送、快捷问题和真实持仓上下文；详情入口绑定证券 | defined | 首页/Advisor页输入、发送和快捷问题已接入；默认聚焦首个真实持仓，详情绑定标的；发送时重读账本并构建请求。只读持仓会发送至用户配置的DeepSeek；实际可发现性待Simulator/真机验收 |
| F-28 | 五主题统一普通文字/页面颜色；仅保留业务语义图表色 | defined | App已有主题选择器、五布局分支和基础颜色；统一设计token、业务图表色及视觉质量/设备验收未完成 |
| F-29 | 分时/日K统一支持点击、长按十字光标、拖动、缩放、横屏与选中详情 | defined | hit-testing坐标验证与复用已编码；当前/历史分钟与日K已接入共享 renderer。基础图表模型回归包含于FCore 119/119通过；renderer内实际手势、横屏全屏及显示效果仍待Simulator专项/真机验收 |
| F-30 | 红利研究采用多因素证据；4%仅为自动模式参考，显式高级设置才启用自定义最低值 | defined | NAS多因素证据整理器及版本化Research Evidence输出已编码；历史观测重复时按质量/抓取时点确定性去重并拒绝质量分越界，红利研究Python 7/7通过；真实基本面来源、Advisor/UI消费和高级自定义设置仍未接入，不能据此给出真实资产买卖结论 |
| F-31 | 首次使用者可发现AI输入、历史分时、K线选择、数据时间/来源、AI依据和主操作 | defined | AI输入/快捷问题/真实账本状态和持仓证券详情入口已编码；历史分时、K线选择、行情来源新鲜度及依据展示仍待原生可发现性验收；Simulator/真机评估待外部验证 |
| F-32 | B五种布局为F主要布局设计基线；首页每卡职责、信息和目标路由唯一；不同语义入口必须有独立页面 | defined | 五种首页布局保留；市场观察、跨市场脉搏、AI指导、真实资产各有独立route/page；每个主Tab有独立NavigationStack。源码检查通过，实际可发现性仍待设备验证 | |
| F-33 | NAS Research Evidence版本化只读进入DecisionContext；只传紧凑统计/来源/时点，不传原始分钟/计划；过期、低质量、样本不足、未来时间fail-closed | defined | 紧凑证据与日期/质量校验已编码；有合格日必须有来源，零合格日可空来源；超大计数转换 fail-closed；evidenceId覆盖信任元数据并由iOS重算；FCore 119项整体CI通过，生产跨端服务联调和业务验收仍未完成 |
| F-34 | B版145项需求逐项溯源、F需求处置与独立验收 | defined | [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)：保留 B-001…B-145 编号与验收输入，逐项给出 F 需求处置、供体裁决和 F 独立验收状态；B 状态不继承。编号连续性已静态核对，F 实现仍按各项验收。 |
| F-35 | 行情按证券刷新并更新共享图表快照，显示来源/行情时间/获取时间 | defined | Swift数据绑定已编码；实时源、设备图表响应待验证 |
| F-36 | 未知年份交易日历 fail-closed，日历按正式来源审核 | defined | 仅当前配置年度启用；其他年份和实机行为待验收 |
| F-37 | NAS按月核验官方交易日历，双源一致后原子发布 | defined | Worker/存储已编码；目标NAS运行和实网兼容待验证 |
| F-38 | 原生主导航、只读真实资产、显著AI输入、设置和NAS连接 | defined | 五Tab/独立导航栈、AI上下文状态、只读账本页、主题设置、NAS URL与只读`/readyz`检查已编码；NAS token 配置已按用户明确授权移除。历史UI XCTest结果不代表本次改动已验证。 |
| F-39 | NAS部署包在大小写敏感的Compose项目名校验下可解析 | defined | Compose固定`name: guanpan-f`；部署包显式包含Python package markers；修复entrypoint CRLF shebang，并在Dockerfile构建时校验`#!/bin/sh`；部署包测试7/7与shell语法检查通过。NAS挂载卷属主初始化后降权至UID 10001；Docker/NAS目标环境仍External Verification Pending |
| F-40 | 真实持仓 Advisor：组合级 + 证券级 Ledger→行情/研究→DecisionContext→Risk/AI Guard→Candidate Plan | defined | App源码现按入口/问题区分组合与证券范围；真实账本空仓时组合Advisor仍可分析现金；明确六位代码/证券入口可分析尚未持有的证券；组合问题纳入全部真实持仓/现金、逐证券报价和 NAS Evidence/缺失状态。单笔买入/卖出 Candidate 现可由用户填写实际成交并显式确认后调用唯一 Ledger writer，成功后失效旧 Candidate、重读账本并重跑相同作用域 Advisor；做T/网格/回本不自动写入。ETF单笔0.10元及做T双边0.20元估费由iOS校验。基础做T不强制盘口，但要求连续时段可信新鲜行情及同标的合格vwapBreak研究。证券详情页接入NAS按日历史分钟；分钟折线支持长按/按钮十字光标、拖动选点/平移、提示和缩放。当前代码已通过Actions run 40298657796的XcodeGen、iOS Device/Simulator Build及3项UI XCTest；FCore 119/119通过。统一图表及历史详情已编码并编译，但交互/画面、清仓真实账本数据、成交后AI闭环和NAS/DeepSeek/行情生产联调仍待专项验收；均价/前收/IOPV无可靠源保持Unavailable，横屏仍未完成 |
| EXT-1 | GitHub DNS / 远端可达性和跨机同步验证 | external pending | 私有 `ggjj45828/guanpan-f` 已通过GitHub API发布F源码；Actions run `40298657796` 成功。跨机克隆/恢复及持续同步仍待验证 |
| EXT-2 | NAS 端口 8788 与部署/恢复链验证 | external pending | 旧部署 `/readyz` 返回过 unauthorized；当前源码改为无鉴权，需重建部署后验证 readiness、Provider/Calendar、历史数据和备份恢复。此改动让可达端口的客户端可访问所有API。 |
| EXT-3 | macOS、Swift/Xcode 构建和模拟器测试 | external pending | GitHub macOS Actions run `40298657796` 用Xcode 16.4完成Swift编译、Device/Simulator Build、FCore 119/119及App UI 3/3；人工截图/交互、横屏/多尺寸和真机仍待验证 |
| EXT-4 | iPhone 真机、横屏和推送通知验收 | external pending | 需设备环境 |
| EXT-5 | 实际行情、新闻与在线 AI 服务接入验证 | external pending | 外部服务配置/联调待做 |

当前矩阵为40项 `defined`、5项 `external pending`。FCore XCTest defined=119 / executed=119 / passed=119 / failed=0；App UI XCTest defined=3 / executed=3 / passed=3 / failed=0（run `40298657796`）。已清仓详情修改编译通过，但无真实清仓账本数据的UI专项验收。这不代表所有产品验收项已通过；Python结果和静态检查也不代表真机、生产NAS或在线服务通过。不得继承A/B状态。



> 以下为追加的阶段性历史记录；其中旧测试计数反映当时工作树，当前数字以上方“当前 F 验证快照”为准。

部署阶段补充（2026-10-26）：F-25 的分钟服务已有显式运行壳与持久化部署配置；runner/鉴权/readiness 的本地 HTTP smoke 通过，Compose YAML结构检查通过，现有 Python 套件83/83通过。Docker镜像、真实 provider/calendar 插件、NAS 8788部署及生产备份恢复未验证，均保持 External Verification Pending，不能标为部署通过。


Provider/Calendar接入补充（2026-10-26）：F默认runtime现配置腾讯当前交易日分钟采集、东财精确日期历史分钟请求和沪深2026交易日历，启动时排队最多120个受支持交易日，实时采集与补采分线程运行。腾讯实网数据已在本环境经日历校验并写临时SQLite，盘中16/240点标Partial；东财历史请求本云端超时，不能算历史覆盖通过。非2026年日历fail-closed。Docker镜像、NAS部署及生产回补覆盖仍External Verification Pending。

NAS容器启动故障修复（2026-10-26）：用户日志显示`No module named 'nas.fminute'`。部署ZIP构建器此前只复制`nas/fminute/*.py`，未打包根`nas/__init__.py`；现补齐显式package marker，并在Docker镜像构建阶段执行真实模块import自检。部署包套件6/6通过、解压包import smoke通过、相关`py_compile`通过。当前环境无Docker，未能验证镜像构建；修复包需在目标NAS重新部署，生产启动仍External Verification Pending。FCore XCTest defined=39 / executed=0 / passed=0 / failed=0；App UI XCTest defined=2 / executed=0 / passed=0 / failed=0。

NAS SQLite 数据目录权限修复（2026-10-26）：用户日志显示`sqlite3.OperationalError: unable to open database file`。原因是NAS bind mount覆盖镜像中已chown的`/data`，UID 10001无法写入宿主目录。entrypoint以root准备`/data`属主和权限、修复属主不匹配的顶层既有数据项，再通过`util-linux`的`setpriv`降权到UID 10001启动Python；未更改存储路径或数据库内容。部署包测试7/7、解压模块导入smoke、shell语法及py_compile通过。无Docker/NAS，构建和生产重启仍External Verification Pending。


NAS 8788 / GitHub F repo 状态补充（2026-10-26历史现场）：旧部署 `/livez` 返回 alive，`/readyz` 返回 unauthorized；当前实现已按用户授权移除NAS API token鉴权，目标容器尚未重部署。生产就绪性未验证。
