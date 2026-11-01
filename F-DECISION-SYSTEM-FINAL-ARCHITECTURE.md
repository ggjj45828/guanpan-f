# 观盘max投资决策系统：正式架构定稿

状态：产品决策已定稿；实现按阶段推进。本文取代与之冲突的旧要求。文档定稿、源码编码、编译、自动测试、Simulator/真机和真实服务联调是不同状态。

## 当前工作树校准（2026-11-01；覆盖下方较早的“当前状态”快照）

- `FMarketRegimeEngine`已编码多因子Regime；`FLocalQuantEngine`已计算八类描述性因子和三类策略准备状态，并将来源、行情时点与日线支撑日期带入Advisor只读上下文。因子方向分不是收益概率，也不会单独生成交易信号、价位或份额。
- NAS Research支持历史分钟研究证据，但没有可在生产端验证并签发`FQuantStrategyQualificationGrant`的策略包验签链；所以Local Quant策略仍未qualified，资产变化Candidate继续fail-closed。
- `FRealtimeQuantTrigger`只有纯状态评估器，没有App生产调用方；当前缺候选计划的合格来源，也没有持续报价订阅、状态持久化、通知与Trigger UI闭环。不能绕过缺失的策略资格去接线触发器。
- Market Regime可消费已支持的证券/指数日线与159352→CSI A500、159941→Nasdaq-100两项明确映射；其他ETF映射、KOSPI历史日线、完整多市场交易日历/UTC与DST统一、市场广度生产源仍未完成或须保持Unavailable。
- 当前FCore XCTest定义319项、App UI定义11项；全量Python发现284项，282项通过，2项因本机缺PyYAML而未导入。Apple构建与XCTest未在当前dirty工作树执行；不继承较早SHA的CI结果。

以下日期较早的验收记录保留作历史，不覆盖本节对当前工作树的描述。

## 产品目标与不可混淆的事实

观盘max是一位围绕用户真实账户工作、快速、可验证、愿意等待并能承认错误的私人投资顾问。目标不是声称预测准确或保证收益。

四类事实必须独立保存和展示：

1. **Quant Signal**：本地确定性规则在当时数据上的输出。
2. **AI Advice**：DeepSeek Advisor对真实Ledger、行情、Quant和背景的解释、计划与风险判断。
3. **Market Result**：随后真实行情及其质量。
4. **User Execution**：用户确认的真实成交。只有该事实可以进入真实Ledger。

Candidate、触发、影子评分和Advisor都没有Ledger写权限。真实账户只由用户确认成交、现金对账及合法Ledger更正产生。不得建虚拟现金、虚拟持仓或模拟账本。

## 核心链路

```text
快通道（不等DeepSeek）
真实行情 → 本机确定性Quant → Risk Guard → Candidate Realtime Trigger → 状态/提醒

慢通道
真实Ledger + 行情 + Quant状态 + Market Regime + 必要背景/新闻
    → DeepSeek Advisor → 风险/理由/失效条件 → Candidate Plan

事后评价
不可变Candidate快照 + 后续真实行情 → Advice/Market Shadow Review
用户手工成交 → 明确确认 → FConfirmedLedgerWriter → Ledger → Quant重算 → Advisor按需复判
```

DeepSeek不是逐tick或高频引擎。系统定位于分钟级/日内波段辅助，不自动下单、不追价。NAS不是实时行情、本机已安装合格策略包执行、Risk Guard或DeepSeek单次请求的同步依赖；NAS故障时Ledger、行情、本地基础Advisor和有效策略包仍可工作。NAS历史分钟数据则是Quant研究、回测、Validation、样本外评估和策略资格签发的主依据。没有NAS验证资格的规则不得下放为可交易策略。DeepSeek只消费本机已有且未过期的Research Summary缓存；缓存缺失或过期时继续分析并标注不可用，绝不等待NAS。

慢速研究链：NAS历史分钟数据 → Quant Research → Backtest → Validation → Out-of-Sample → Strategy Qualification → 不可变Strategy Version/参数包 → iPhone Local Quant。该链路异步于盘中决策和DeepSeek Advisor。

## 本地Quant与风险门

第一版Quant是确定性、可解释、可单测和可回放的少量因子；每项输入须有来源、交易时间、新鲜度和缺失状态。可靠数据不存在时显示Unavailable，不捏造盘口、IOPV、均价、前收、历史行情或胜率。

输出至少覆盖 HOLD、WAIT、NO_TRADE、APPROACHING_BUY/SELL、BUY/SELL_CANDIDATE、T_BUY/SELL_CANDIDATE、LEFT_ZONE、INVALIDATED、DATA_UNRELIABLE，并携带reason codes、目标区、份额依据、validUntil、失效条件、quote timestamp和data freshness。confidence只有具备明确统计定义与足够样本时才能提供；否则为空/证据不足。最小优势必须扣除实际费用、价差、人工延迟和踏空风险。NO_TRADE是正式结果。

Market Regime由确定性数据导出，最少包含上涨趋势、下跌趋势、震荡、高/低波动、异常和数据不可靠。每证券Quant Profile与策略版本须由真实历史数据验证，并经Backtest、Validation、Out-of-Sample与Strategy Qualification；不能凭DeepSeek或开发者直觉固化参数。策略资格按证券×Regime×策略版本绑定，并记录数据范围、样本数、样本外指标、来源、生成时间与有效期。缺少或过期参数包时Local Quant只能WAIT/NO_TRADE。Risk Guard可以否决信号，不能自行创造新交易。行情过期、异常、现金不足、持仓不足、计划失效或风险不合格时必须暂停/阻止。

同一组合的多标的机会必须共同竞争真实现金、仓位与集中度；Advisor需排序、分配优先级或等待，不能把全部现金重复分配给每只证券。Analysis Plan必须与可执行Candidate明确区分。

## Candidate 与实时提醒

Candidate是不可变计划快照，至少保存唯一ID、证券、策略/版本、Quant层输出、DeepSeek层输出、最终建议、生成时行情及时间、目标价格区、计划方向/份额、有效期、quote max age、max chase distance、失效条件、Market Regime、Guard结果和来源。

生命周期至少覆盖 Draft、Waiting、Approaching、Triggered、LeftZone、Invalidated、Expired、UserIgnored、PartiallyFilled、Filled、Cancelled。Approaching按证券tick size、近期分钟波动和计划类型计算；具体阈值必须确定且可验证。超出计划区和允许追价距离后进入LeftZone，明确不追价。Stale行情不能触发。重复提醒须去重/冷却。

BUY/SELL Candidate只有在真实现金/持仓约束满足后才可作为可执行建议；被Guard否决的AI原始建议仍可作为Advisor层历史证据保存，但最终建议应记录为WAIT/BLOCKED，不能显示成已放行的交易计划。

## Candidate Shadow Score 与真实执行结果

Shadow Score不是模拟账户。对每个正式Candidate，包括WAIT/NO_TRADE、失败、未触发、失效、过期和数据不足项，保存不可变原始快照及追加式后续事件。旧Candidate不可被新参数/新建议覆盖。

分别评估 Quant Only、DeepSeek Advisor、Advisor Override 和 Final Advice。各层输入/输出如果当时没有真实记录，保持缺失；不得回填推断。策略同时保留策略ID和版本，版本升级不重写旧表现。

Shadow评价至少区分：触发、触发时刻/价格、5/15/30/60分钟结果、收盘结果、MFE/MAE、失效条件、机会/踏空风险、数据质量、用户是否执行及部分/完整执行。需要比较计划策略与不操作/Hold基准，并分别按证券、策略、市场Regime和时间段分析。缺行情、Partial、Stale或Unavailable时降低评价等级或排除，不归咎成策略表现。WAIT需要结构化机会/失效规则，否则只能记为不可评价，不能事后声称判断正确。

统计应同时显示分母、样本数量、覆盖范围和数据质量。没有足够样本外证据不得给胜率、置信度或“成功”结论。最近30天汇总不得只收录成功建议。影子成绩不计入真实P&L/T Contribution。没有Confirmed Fill关联不能推断用户未执行；需要用户明确复核才能记为未执行。

当前首段实现只保存Advisor候选与最终Guard结果、可靠报价事件、成交ID关联和描述性计数；没有稳定的持续行情采样、收盘评分、Hold对照、策略/Regime统计、可证明的Quant层输出或WAIT结构化机会规则。当前描述性“有利方向数量”不是胜率，不是交易收益，不能据此称成绩单已完成。

## 真实成交与Ledger语义

用户在券商手工成交后，明确输入真实价格、份额、费用并二次确认；唯一Writer原子更新真实Ledger。真实Fill ID与Candidate ID可关联，但这条关联本身绝不生成/修改账本。部分成交只记录真实成交份额，余量继续、修改或取消需重新判断。

成交成功后重算现金、份额、Episode Economic Cost、Broker Display Cost、Security Daily P&L、Current Episode P&L、今日已实现交易盈亏、T Contribution及Lifetime P&L；Quant立即读取更新后的真实Ledger，旧Candidate依规则失效/调整，必要时DeepSeek复判。成本、费用与T配对规则遵循既定Ledger语义；普通减仓/清仓不能自动算T。

## 策略验证与晋降级

策略生命周期：Experimental → Observed → Qualified → Preferred → Degraded → Retired。任何参数比较必须分隔Training、Validation、Out-of-Sample，防未来数据泄漏；不允许用同一历史窗口调参并证明成功。最低样本和稳定性门槛由后续有依据地定义。策略/模型升级保留版本和当时数据，不改写旧Candidate成绩。

## 当前工作树实现状态（2026-10-28）

- 已编码未Apple验证：`Sources/FAdvisor/CandidateShadowScorecard.swift`追加式本地日志、不可变快照、来源可信报价、未来时点过滤、5/15/30/60分钟候选触发后价格变化、MFE/MAE、Candidate与Confirmed Fill ID关联、明确用户未执行复核、按证券描述性30日计数。当前方向性统计只评估DeepSeek原始动作，不代表Guard后的Final Advice、Quant或用户收益。
- 已接入源码但未编译：Advisor完成后保存原始DeepSeek建议/最终Guard结论；用户真实成交成功后追加Fill ID；行情刷新成功后追加报价；AI页显示描述性决策成绩单。以上不是持续行情订阅或完整Shadow评分。
- 有定义未执行：`Tests/FCoreTests/CandidateShadowScorecardTests.swift`新增11项影子边界回归；当前FCore defined=164、App UI defined=3。Windows环境没有Swift/Xcode，尚无此dirty源码的编译/测试证据。
- 未实现：正式本地Quant因子评分与Market Regime；完整实时Trigger订阅/提醒；完整Candidate状态持久化；固定Approaching/max-chase规则；分策略层的真实独立输出；完整Advice-vs-Market-vs-Execution对照；Hold/机会成本基准；收盘评分；策略样本外晋降级；真实DeepSeek/真实成交E2E。
- 安全边界：以上缺项保持缺项状态；Candidate和Shadow日志没有Ledger writer权限，shadow Fill association只记录已成功真实写入的Fill ID。

## 当前优先级

P0 Ledger与Apple CI；P1 B→F原生体验；P2最小可靠本地Quant；P3 Market Regime/Risk Guard；P4 Candidate/Trigger；P5首页和详情接线；P6 Shadow Score/Decision Scorecard；P7 DeepSeek读取Quant形成组合/证券建议；P8确认成交→Ledger→Quant复算→Advisor复判；P9三套标杆主题；P10其余主题/策略扩展。NAS研究不属于当前核心P级主线。

验收严格区分：设计、编码、编译、测试定义、实际执行、Simulator、真机、真实服务。旧要求把NAS分钟研究列为Advisor必经前置的部分均标记为Superseded。

## 2026-10-29 当前工作树校准（覆盖上方2026-10-28实现快照）

- 当前仓库F的HEAD为 `0dff6c3d84af3870d4a10adcb02fcbea0d492b2a`；本地 `main` 与缓存 `origin/main` 同SHA，工作树干净。这只代表本地Git状态。
- 本轮HEAD涉及统一图表显示密度/横轴/图例控件、盈亏折叠、主题表面和自选行情刷新；没有新增Quant、Candidate、Shadow或Ledger实现。
- GitHub连接器对当前SHA返回空workflow run和空combined status，无法确认当前Apple CI是否已启动或完成。**当前SHA CI未核实**，不得继承旧run结论。Windows当前环境无Xcode/Swift，未能本地Apple编译。
- 有部分价格区Trigger evaluator与Candidate Shadow追加记录；完整本机多因子Quant、Market Regime、实时报价订阅/后台触发、Risk Guard接线、首页/详情Quant状态、完整Shadow评分与基准对照、DeepSeek真实E2E及成交后Advisor复判仍未完成。
- NAS不再是Advisor同步前置；NAS历史分钟研究仍是策略Qualification的依据，但完整Research→Strategy Package管线未完成，不能宣称已落地。手机HTTPS连通性没有新现场证据，仍待验证。
- 测试定义不等于当前HEAD执行。FCore/UI XCTest、Simulator启动/人工视觉、真机和真实服务E2E必须分别以当前SHA的实际证据记录。

## Run 69 live status correction (2026-10-29)

Run 40802741213 is now confirmed running for SHA 0dff6c3d84af3870d4a10adcb02fcbea0d492b2a. FCore, XcodeGen, Device Build and Simulator Build steps report success; App UI XCTest is in progress, with screenshot export, IPA and artifact steps pending. This supersedes the earlier “CI未核实” wording for this SHA. Exact test totals/final status remain pending. The architecture-document-only edits currently in the local worktree are not included in run 69.

## Run 69 final execution evidence (2026-10-29)

- Run 40802741213 for Swift HEAD 0dff6c3d84af3870d4a10adcb02fcbea0d492b2a completed with success.
- Actual test totals: FCore 164/164 passed, 0 failed; App UI XCTest 3/3 passed, 0 failed.
- XcodeGen, Device Build, Simulator Build, screenshot export, unsigned IPA validation and upload all succeeded. Artifact ID 12866733256. The package validation confirms display name “观盘max” and AppIcon metadata.
- This verifies the tested Swift SHA only. Simulator screenshots were exported but not manually reviewed; iPhone Air, gestures, real NAS HTTPS and DeepSeek E2E remain unverified. Documentation changes made after this run are not part of the CI-tested SHA.

## 本地文档提交未推送补正（2026-10-29）

Run 69通过的Swift源码SHA为0dff6c3d84af3870d4a10adcb02fcbea0d492b2a。之后只提交了五份Markdown状态文档；git push因“getaddrinfo() thread failed to start”失败，本地main比缓存origin/main ahead 1。Swift未修改，Run 69结论仍只对应其SHA；文档提交没有远端CI证据。

## 文档推送与Swift验证关系校正（2026-10-29）

本轮五份文档已通过GitHub Desktop成功推送，当前本地与远端main同步。Workflow只监控Swift/工程及workflow路径，因此文档更新没有新触发Apple CI。当前Swift代码的最近验证SHA仍为0dff6c3d84af3870d4a10adcb02fcbea0d492b2a；Run69全绿的FCore、UI XCTest、工程生成、Device/Simulator Build、截图导出、IPA校验与artifact上传均只对应该Swift SHA。

## 当前工作树校准（2026-11-01）

以下状态覆盖上方2026-10-28/29实现快照，不改写历史CI记录：

- FCore现在已有确定性多因子Market Regime分类器、Risk Guard资格硬门和独立Candidate价格区间Trigger；Market Regime使用MA20/60结构，并在满250日时使用MA60/250长趋势因子。长短趋势冲突分类为Transition；不足250日时长周期因子Unavailable。
- 首页可显示上证、深证、沪深300、创业板、纳斯达克100、日经225、KOSPI和恒生行情。NAS历史日K仅为已验证的六个代码开放归档读取；日经与KOSPI历史仍Unavailable。证券级Regime依据该证券自身NAS日K，指数状态尚未通过可靠映射并入ETF自身状态。
- 完整Local Quant v1仍未实现：描述性因子观测和归一方向评分已编码，但因子尚未组合成正式策略信号或完成策略选择；持仓/现金约束下的参数包生成、策略资格签发、盘中持续评估与Trigger接线、状态持久化/通知也未闭环。Risk Guard因缺少可验证策略资格包而继续拒绝资产变化候选。
- 2026-11-01本地dirty工作树的Swift/Python测试及Apple Build尚未运行；此前Run 69只验证其记录的旧SHA，不作为当前工作树证据。NAS实网、Simulator视觉、真机和真实市场表现仍需分别验收。
