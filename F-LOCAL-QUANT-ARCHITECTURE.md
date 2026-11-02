# 观盘max本地 Quant 与双速决策架构

> 本文件保留本地Quant/双速链路的实现细节。完整的最终投资决策、Candidate、Shadow Score、策略验证与优先级以`F-DECISION-SYSTEM-FINAL-ARCHITECTURE.md`为准；后者取代冲突旧要求。

状态：产品架构已确定；实现分阶段推进。文档完成不代表功能实现或验证完成。

## 产品决策

NAS 不属于盘中实时行情、iPhone 已安装策略包的本地执行、Risk Guard 或 DeepSeek 单次分析的同步依赖；NAS故障不得阻断这些基础流程。策略参数包必须经过可复核的 Backtest、Validation、Out-of-Sample 与 Strategy Qualification 后才可下放iPhone；历史数据可以来自本机缓存、用户提供数据或可选NAS归档，NAS不是资格认证方或运行前置。没有可用且未过期的合格策略包时，Local Quant必须保持 WAIT/NO_TRADE，不得用手写参数替代。NAS Research Summary可作为DeepSeek的可选缓存上下文，但单次提问绝不等待NAS。

策略验证链：可用历史数据（本机缓存/导入/可选NAS） → Quant Research → Backtest → Validation → Out-of-Sample → Strategy Qualification → 不可变Strategy Version/参数包 → iPhone Local Quant。NAS只是可选数据来源之一。它与盘中快通道异步运行；DeepSeek Advisor只消费本机已有且未过期的Research Summary（若有）。

## 唯一业务事实源

```text
实时行情 ──→ iPhone 本地 Quant Engine ──→ Risk Guard ──→ Realtime Trigger ──→ 即时状态/本地提醒
     │                   ↑                       ↑                    │
     └──────┬────────────┘                       │                    │
            │                                    │                    │
真实 Ledger (只读) ──→ DeepSeek Advisor ──→ Candidate Plan ───────────┘
                              ↑
日线/近期分钟、市场背景/新闻、Quant 状态、本机已有的可选 NAS Research Summary

慢速资格链（不进入盘中请求等待链）
可用历史数据（本地/导入/可选NAS） → Backtest/Validation/OOS → Strategy Qualification/Version → iPhone策略包

用户在券商手工成交 → 用户明确确认 → FConfirmedLedgerWriter → Ledger → Quant 重算 → Advisor按需复判
```

Ledger、行情、Episode/双成本/P&L/交易事实、Research Evidence、DecisionContext、Advisor、Candidate Plan 和确认成交写入口始终各自唯一。NAS 的 Research Evidence 是可选上下文；本地 Quant 是行情快速评估与计划触发器，不是第二个账本，也不拥有写账权限。DeepSeek 是较慢的组合/证券投资顾问，不是逐 tick 引擎。Realtime Trigger 只读可靠行情和用户可审阅的 Candidate Plan。

## 快通道与慢通道

### 快通道

行情更新 → 确定性 Quant 计算 → Risk Guard → Trigger 状态迁移 → App 即时状态/提醒。

- 不等待、不调用 DeepSeek或NAS。
- 行情必须有来源、交易时间和新鲜度；Stale/Unavailable 时暂停实时指导并保留明确状态。
- Quant 因子必须确定、可解释、可回测；证据不足时输出 WAIT/低置信度，不猜方向。
- 状态至少覆盖 HOLD、WAIT、APPROACHING_BUY、BUY_CANDIDATE、APPROACHING_SELL、SELL_CANDIDATE、T_BUY_CANDIDATE、T_SELL_CANDIDATE、INVALIDATED；Candidate 生命周期覆盖 Waiting、Approaching、Triggered、LeftZone、Filled、Invalidated、Expired。
- Trigger 到价只产生提示/候选状态，不自动下单，不写 Ledger。用户手工交易并确认后才写账。

### 慢通道

真实 Ledger + 现金/持仓/成本/当天成交事实 + 可靠行情/日线/近期分钟 + Quant 状态 + 可选新鲜新闻/市场背景/本机已有且未过期的NAS Research Summary缓存 → DeepSeek Advisor → Portfolio/Security 结论、Candidate Plan、依据、风险与失效条件。Advisor不请求、不等待NAS；摘要缺失或过期时仍继续基础分析并标注“历史Quant研究摘要暂不可用”。

- DeepSeek 不负责逐 tick 监控，也不得重算 Ledger 数字、费用或 Quant 状态。
- Advisor单次请求不得同步请求或等待NAS；无新鲜Research Summary时继续基础分析并明确标注不可用。
- Advisor 可以建议 HOLD/WAIT；没有交易机会时“不交易”是完整结果。
- Candidate Plan 是用户审阅对象；只有真实成交确认进入 `FConfirmedLedgerWriter`。

## Quant v1 边界

输入只接受真实来源数据：最新价/时间/新鲜度、有效分时与成交量、可用均价/前收/MA5/10/20/60/250、分钟波动/日内振幅/趋势特征、真实 Ledger 只读快照（持仓、现金、Episode Economic Cost、Broker Display Cost、当日 confirmed fills/T Contribution）、既有 Candidate Plan。IOPV/折溢价只在可靠来源存在时输入，否则 unavailable。

输出包含状态、signalScore、confidence、reasonCodes、目标价格区间、建议数量、validUntil、invalidation、quoteTimestamp。Quant v1 不内置未经验证的 ML/LLM；不凭空产生目标价和数量。若没有经 Guard 校验的计划区间/数量依据、行情过期、信号冲突、样本不足或风险不满足，输出 WAIT/HOLD 并说明原因。后续回测统计需来自真实本地行情，不足样本显示“样本不足/低置信度”。

## 状态迁移与迟到提醒

Candidate Plan 从 Waiting 到 Approaching/Triggered；当价格已离开计划区间时显示 LeftZone，不追价；随后可由用户成交确认变为 Filled，或按 Guard/有效期转为 Invalidated/Expired。行情 Stale 时不得新触发，显示“行情已过期，实时计划暂停”。状态转换需使用前一状态和可靠 quote timestamp，不能只用当前价格推断先前是否触发。Filled 仅表示用户确认的真实成交事实，不能由触价推断。

## 安全与财务语义

- Quant/Advisor/Trigger 对 Ledger 全部只读。
- 只有用户明确确认的真实成交可进入唯一写入口 `FConfirmedLedgerWriter`。
- Episode Economic Cost、Broker Display Cost、Security Daily P&L、Current Episode P&L、Realized P&L、T Contribution、Lifetime P&L 继续分离；Quant 读取 Ledger 派生事实，不另算、不写回。
- Candidate/Trigger 不自动调整现金、份额、成本、费用或成交历史。
- 风险 Guard 不能因无 NAS 而拒绝整个基础 Advisor；危险动作仍须满足可核验的本地行情、现金/持仓约束和对应安全证据。任何放宽必须以本地 Quant 可复现条件替代并有回归测试，不能简单删除 Guard。

## 当前落地进度（2026-10-28）

- 已编码：`Sources/FCore/RealtimeQuantTrigger.swift` 提供纯确定性的 Candidate 价格区间监控：WAIT、Approaching、Triggered、LeftZone、Filled、Invalidated、Expired、Paused；只读取带来源/可信交易时间/会话状态的报价，不接触Ledger writer。
- 当前输入边界：依赖的 `FCurrentIntradaySnapshot` 只接受六位数字CN代码；这一版触发器不是跨市场Quant。美股/日股/韩股接入前需要统一市场身份、时区/交易日历和真实报价契约，不能仅按代码匹配。
- 已编码：暂停状态带 `resumeState`，允许调用端持久化并在行情恢复时恢复此前操作状态，避免 stale 期间穿过触发区后又被当成可新触发机会。调用方尚未接线，当前只是引擎契约。
- 已定义未执行：`Tests/FCoreTests/RealtimeQuantTriggerTests.swift` 有12项状态机回归，覆盖无计划等待、接近/触发、过期/未生效、stale/未验证/非连续交易时段暂停、暂停恢复后错过区间、失效价、证券错配、计划更换时清除旧状态、Filled不能由触价推断、T买卖信号区分。
- 不是完整Quant v1：还没有价格/MA/成交量/波动/持仓/现金因子评分，也没有Risk Guard接线、实时行情订阅、状态持久化/通知、首页/详情UI或历史回放。不得把当前价格区间监控称为“本地Quant已完成”。
- 当前资产变化Candidate仍在App层被明确阻止，直到Quant/Guard/Trigger完整接线；本引擎本身也不写Ledger、不下单、不确认成交。
- Risk Guard 的资格门除新鲜、标的匹配、候选引用外，还要求 FAdvisor 内部不可序列化的运行时授权；公开文本观察和 JSON 恢复上下文不能自行获得资格。真实 Local Quant 包验证/授权签发器仍未实现，因此此项继续 fail-closed。

## 分阶段实现与验收

1. P0：保留 Ledger/T/手续费语义；确认当前首页 Swift 修改的 Apple CI 证据。Run 58 已取消，不能记作编译或测试结果。
2. P1：继续首页及核心页面 B→F 体验整改；Simulator/真机视觉状态单独标记。
3. P2：在 FCore 引入纯确定性 Quant 输入/输出与本地计算，先用真实 quote/ledger 事实和保守 WAIT 策略；单元测试覆盖新鲜/过期、信号冲突、成本口径、无持仓/低现金、IOPV unavailable、NO TRADE。只读因子观察已接入Advisor冻结上下文；尚未接Risk Guard/Trigger，没有独立验证通过的本地策略参数包，也不是完整Quant v1。NAS为可选研究/归档增强，不是本地策略资格的强制授权方。
4. P3：先将当前纯状态评估器接入经Risk Guard批准的Candidate，再实现可持久化、幂等、可恢复的状态管理与本地提醒；迟到时LeftZone、不追价。当前没有实时订阅、持久化或提醒接线。
5. P4：向首页、证券详情、Advisor 接入本地 Quant 状态；NAS 缺席不得阻断核心基础流程。
6. P5-P6：DeepSeek 将 Quant 当作确定性只读事实；完成 Candidate→快通道触发→手工成交确认→Ledger→Quant 重算→Advisor 复判。
7. NAS 历史分钟研究独立异步运行，是策略验证与资格签发的依据，不是盘中行情、已安装合格包本地执行或DeepSeek单次分析的同步前提。策略包必须携带证券/Regime/策略版本、数据范围、样本数、Validation与OOS指标、来源、生成时间和有效期；资格缺失或过期时Local Quant保持WAIT/NO_TRADE。

所有代码必须按 defined、compiled、executed、Simulator、实机分开报告。当前 Windows 环境没有 Swift/Xcode；新 Swift 修改只能在 Apple CI 真实执行后标记编译/测试通过。

## 当前工作树校准（2026-11-01）

本节覆盖上方2026-10-28开发快照中的旧状态描述：

- `FMarketRegimeEngine`现已接入确定性多因子分类和风险门控，个股与指数历史各自计算，不会仅凭代码相近自动映射市场。输入样本至少60个真实日K；MA60/MA250因子只有在250个日K可用时才启用；短期趋势与MA250长趋势冲突时进入Transition。
- `FLocalQuantEngine`现有FCore只读因子观察切片，输出8项因子测量、可用时的波动率归一化方向评分/不可用原因，以及Mean Reversion、Trend Pullback、VWAP Deviation策略准备状态；证券Regime必须精确匹配代码且未过期；日K必须来自按市场白名单确认的来源，实时因子要求120秒内、来源allowlist验证的报价和连续交易时段，短周期因子还要求最近20条分钟样本间隔不超过180秒。每个因子摘要包含自身来源和观测时点；Trend Structure同时注明所用日线的最后日期及实时行情源，纯日线MA Structure不再冒用实时行情时间。159352和159941的发行方映射Regime也参与策略准备：缺失/过期/错指数则映射证券策略Unavailable，策略需同时被ETF Regime与映射市场Regime允许，严重风险禁用。App已将摘要写入Advisor冻结上下文，IOPV仅消费当时已有的新鲜缓存，不增加请求等待。它不生成价位、份额、Candidate或NAS资格；策略参数尚无独立的本地验证/授权包时保持未qualified/NO_TRADE，NAS仅为可选历史研究来源。其余未映射证券不借用其他指数状态。
- `FRealtimeQuantTrigger`及`FRiskGuard`的核心类型已存在；159352/159941的发行方映射Regime现进入Local Quant策略准备，并在买入Guard中校验映射来源/时效、要求引用，严重/极端风险时拒绝普通买入。全标的实时策略评估、符合资格的本地策略包、持久化与提醒尚未闭环。缺少验证资格时，资产变化候选保持阻止。
- 当前没有生产代码可以签发 `FQuantStrategyQualificationGrant`；Advisor解码的DecisionContext会丢弃运行时授权，Guard只有测试显式注入授权才能放行量化候选。Python源码合同现阻止本地策略参数验证器实现前出现生产授权签发调用；NAS不是生产授权的必经路径。
- 当前跨市场指数板有8个实时行情位；NAS历史日K已支持七个Tencent指数代码，日经可取官方收盘价，KOSPI历史来源仍Unavailable。159352→CSI A500与159941→Nasdaq-100发行方映射现进入Advisor背景、Local Quant策略准备和Risk Guard严重风险门控；映射自身不构成NAS策略资格，映射缺失/过期时对应标的策略保持Unavailable。其他证券映射、跨市场Lead-Lag、宽度真实来源、各市场完整日历及样本外策略研究仍未实现或未验收。
- MA250与指数时间戳新增回归定义尚未在Apple/Python环境执行。不得用旧Run 69结果证明当前dirty worktree通过。
