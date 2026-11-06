# 观盘max / F版：多周期 MACD 智能分析实施与验收

本文件只适用于现有观盘max F版。它不新建 GuanpanNext、第二套 App 或新仓库。F 的 Ledger、行情、Local Quant、Risk Guard、Advisor、Candidate 与 Shadow Score 保持现有权威实现；MACD 是接入它们的共享技术证据模块。

## 当前实现快照

| 能力 | F源码位置 | 状态 |
|---|---|---|
| 统一MACD算法、EMA种子、预热及缺失bar重置 | `Sources/FCore/MACDAnalysis.swift` | 已写入 Work；Apple 编译和 XCTest 待运行 |
| 日K价格序列图表调用共享引擎 | `GuanpanFApp/Sources/FUnifiedSecurityChart.swift` | 已接线；Simulator截图/视觉对照待完成 |
| 日线 MACD 作为独立 Local Quant 因子 | `Sources/FCore/LocalQuantEngine.swift` | 已接线到已通过来源与时点校验的已完成日K；本地参数/评分仍不是交易资格 |
| 同周期成交量事实层 | `Sources/FCore/VolumeAnalysis.swift` | 代码已加入MA5/10/20/60、同比周期参考、形成中bar保护和量价事实分类；策略证据默认Experimental；Apple XCTest待运行 |
| Advisor MACD + Volume结构化证据 | `GuanpanFApp/Sources/GuanpanFApp.swift`、`Sources/FAdvisor/DecisionContext.swift`、`Sources/FAdvisor/DecisionMemory.swift` | Advisor上下文含已完成日K的MACD和量能统计；量能字段使用客观证据命名，不代表已验证规则；真实DeepSeek请求/响应待验证 |
| 单元回归向量 | `Tests/FCoreTests/MACDAnalysisTests.swift` | 已添加；当前Windows无Swift/Xcode，未运行 |
| 周/月份线、15/30/60/120分钟真实周期 | 当前行情模型和来源路由 | 尚未证实有对应真实bar源，不生成伪周期；120分钟A股聚合尚未实现 |
| 局部峰谷背离、多周期一致性分类、量价/均线策略关系 | `FCore`分析器 | MACD基础结构及成交量事实层已实现；背离规则与真实多周期关系仍待实现。量价搭配仅是分析证据，不能直接升格为有效交易策略 |
| 每ETF参数训练/验证/OOS/Walk-Forward回测、费用/成交约束、HOLD比较 | Quant/Shadow | 尚未实现 |
| 收盘确认提醒、去重/冷却/静默/撤销 | 提醒中心 | 尚未实现 |
| NAS/iOS一致性数值对照 | 本规范 + NAS接口 | 共享公式已确定；NAS计算器/跨平台黄金向量尚未完成。NAS仍为可选档案，不是核心依赖 |

## 计算契约

- `DIF = EMA(Close, Fast) - EMA(Close, Slow)`；`DEA = EMA(DIF, Signal)`；`Histogram = 2 × (DIF - DEA)`。
- 当前 FCore 采用**SMA种子 EMA**：首个完整 Fast/Slow 窗口的算术平均作为各自首个EMA；之后使用 `alpha = 2/(period+1)` 递推。DEA在首个完整 Signal 个DIF上用SMA初始化。
- 标准参数 `12/26/9`；灵敏参数 `6/13/5`；用户参数必须通过 `FMACDParameters` 的正数、快线小于慢线及安全上限校验。
- 标准参数在没有缺口时，首个完整DIF/DEA/Histogram落在第34根bar（0-based index 33）。公式值不会在预热区间提前伪造。
- `warmupBars`表示首个输出前需要的输入bar数量，不是零基索引；标准参数应为34。计算遇到非有限中间值时丢弃该段并重启预热，禁止向图表/Advisor传播Infinity或NaN。
- Close 缺失、非有限数或非正数会重置EMA状态；后续bar重新完整预热，不跨缺口连接。图表保留输入索引对齐，缺失区间断线。
- 未收盘bar可展示临时值，`signalConfirmed=false`；不可作为正式信号。候选与风险门仍是独立否决层。
- 日线Quant与Advisor仅使用报价交易日前已完成的真实日K；没有可信历史bars就显示Unavailable。周期可用性必须由实际provider/model声明，禁止用日K重采样伪装分钟周期。

## Volume与策略证据分级（2026-11-05补充）

- **数学/工程定义**：同一个`FMACDTimeframe`的bar单独计算Volume MA5/10/20/60、上一组同周期完整bar均值、变化率和连续逐bar变化。MACD和Volume沿用各自真实bar时间轴；无序或重复时间戳直接不可用。
- **形成中bar**：不将部分成交量与完整历史bar比较；其Volume/MA比率及逐bar变化率置空并标为`formingProvisional`。只有显式提供相同周期、相同完成进度且至少5个观察值的参考，才计算同进度比率；不匹配的周期/进度被拒绝。
- **分析证据**：`FPriceVolumeRelation`只描述收盘价升/降/不变与同周期量能高于/不高于参考值的组合，不推断资金净流入、主力吸筹或出货，也不代表未来方向。
- **待验证假设**：MACD/Volume/MA组合、任何放量倍数、单周期或多周期组合以及不同参数优劣，均不得硬编码为BUY/SELL条件。验证需要Training → Validation → Out-of-Sample → Walk-Forward，并比较费用、滑点、频率、回撤及HOLD。
- **策略状态**：`FStrategyEvidenceLevel`提供Experimental、Observational、Validated、Degraded、Retired。新指标/组合只能从Experimental开始；目前没有任何MACD+Volume组合被本仓库的OOS证据验证，因此不得显示Validated或“最佳”。
- **资金边界**：Volume/MACD只提供证据；不能绕过真实持仓、现金、仓位纪律、Risk Guard、Candidate审批或用户确认成交。没有足够历史样本时明确Data Insufficient。

## 2026-11-06 公式边界修正（Work，Apple待验证）

- 修正SMA-seeded EMA预热bar数量的off-by-one：`slow + signal - 1`是首个完整DEA输出所需bar数；首个输出索引仍为`slow + signal - 2`。
- 增加非有限DIF/DEA/Histogram结果的拒绝与重新预热，并以`macd_non_finite_intermediate_rejected`保留诊断事实。
- 增加标准12/26/9在34根bar时首个输出应位于索引33的回归断言。当前本机无Swift/Xcode；新增/已有XCTest尚未运行，不能标为编译或测试通过。

## 2026-11-06 Codemagic 编译修复（待重新运行）

- Codemagic 的 `run_fcore_tests.log` 显示 `intraday.map(assess)` 函数引用参数数量不匹配；后续趋势枚举类型推断错误是同一问题的级联诊断。
- 改为显式单参数闭包 `intraday.map { assess($0) }`，并增加日线 + 120分钟组合分析回归测试。
- 此修复需由 Codemagic 对 `codemagic/ios-trial` 的新提交重新运行验证；当前不标记编译或测试通过。

## 决策边界

MACD是Local Quant的一个独立、可解释因子，不拥有买卖决定权；它不能绕过Position Discipline、Risk Guard、现金缓冲、核心仓/T仓限制或Anti-Overtrading。AI收到的是FCore计算出的结构化指标，不允许模型自行估算DIF/DEA。没有真实数据、样本不足、周期未确认或来源不可信时保持Unavailable/低置信度；HOLD/WAIT仍是正式结果。

## 阶段验收门

1. **计算与真实周期数据**：Apple XCTest通过标准数值向量、EMA预热、缺失/无效bar重置、未收盘bar；确认每周期真实来源/覆盖及iOS—NAS共享黄金向量。
2. **图表和参数**：证券详情图表显示共享引擎输出；可切换周期/参数并保存设置。Simulator按已批准主题模拟图截图对照，不以编译代替视觉验收。
3. **趋势与背离**：确认多周期状态和结构化原因；价格摆点规则、确认/失效点和数据间隔有回归测试。
4. **Quant/Risk**：MACD与Volume事实作为独立证据；不得把Volume方向赋成预测分，不得由金叉/放量单独创建Candidate；持仓/现金/仓位纪律测试证明技术因子不能绕过Risk Guard。
5. **DeepSeek**：保存真实请求与响应，核对MACD/Volume数值逐字段来自FCore上下文，标明未收盘状态和证据等级，未让模型重算指标或将量能解释成资金流。
6. **回测与Shadow**：每ETF训练/验证/样本外和walk-forward；下一可交易bar、0.10元每笔费、滑点配置、交易时段/停牌/涨跌停/未成交约束；与MACD+MA、多周期、无T、长期HOLD对比。样本不足显示证据不足。
7. **提醒和交付**：未收盘提示可撤销且不形成正式Candidate；收盘后去重提醒有触发记录。当前准确SHA的Apple FCore、UI XCTest、Device/Simulator Build和Simulator截图全部通过后才能交付；需人工看图。

ETF参数必须逐证券独立比较 `12/26/9`、`6/13/5` 和用户自定义；不得预设哪组对159941、159352、159545有效，也不得仅选历史收益最高参数。

