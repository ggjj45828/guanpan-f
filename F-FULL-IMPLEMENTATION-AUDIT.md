# F 全盘未完成功能审计

## 2026-11-01 Regime核心拒绝异常日K数值

- 复核 `FMarketRegimeEngine` 发现，它会丢弃非有限或非正收盘价后继续用剩余bar分类；对收盘价可用但负成交量、OHLC部分缺失或高低价关系矛盾也未做核心校验。上游读取器校验不能替代FCore公共引擎的安全边界。
- 引擎现对所有落入as-of/now有效区间的bar验证收盘价与完整/全缺OHLCV结构；成交量必须非负且OHLC关系自洽。任一坏bar令数据不可靠、清空策略许可并返回 `daily_bar_values` 因子及 `invalid_daily_bar_values` 原因码。as-of之后的坏bar仍忽略，避免污染历史回放。
- 新增2项FCore XCTest定义，覆盖负/非有限数值、错误OHLC、部分字段及未来坏bar no-lookahead。Market Regime与追踪Python合同19/19通过；全量Python 293项中291项通过，另2项因本机缺PyYAML无法导入；compileall、架构边界及diff检查通过。当前无Swift/Xcode，新增XCTest未执行。未提交/推送。

## 2026-11-01 验收文档与当前源码状态对齐

- 对照当前 `Sources/FCore/LocalQuantEngine.swift`、Advisor 上下文接线和架构校准发现：若干较早的“当前状态”段落仍称没有因子评分、Quant仅为价格区间Trigger；这与现有八类描述性因子及三类策略准备状态不符，容易把未实现范围写错。
- 在主验收矩阵增加优先级更高的当前工作树校准：明确区分已有因子观测/策略准备、缺失的正式信号/参数资格/生产Trigger闭环，并保留NAS验证链和KOSPI历史接口的真实限制。历史段落仍留存用于追溯，不当作当前状态。
- 重新核对当前工作树验收计数：FCore 329项、UI 11项；Python 292项中290项通过，2项因本机缺PyYAML未导入。`compileall`、架构边界和diff检查通过；Swift/Xcode不可用，Apple执行仍为0。未提交/推送。

## 2026-11-01 iPhone跨市场指数历史解码缺少有限数值检查

- NAS的指数日线归档服务会校验OHLCV有限性，但iPhone的 `FNASIndexDailyHistoryClient` 仍直接将解析后的 Decimal 转成 Double，客户端未独立拒绝NaN/无穷或不可有限转换的值。
- 指数日线Decimal解码现在要求 `Decimal.isFinite` 且 `NSDecimalNumber.doubleValue.isFinite`，否则该字段解析失败，整条历史响应不会送入Market Regime。Daily-history wiring测试14/14通过；这仅是源合同覆盖，未在本机运行Swift。
- 当前没有Swift/Xcode编译证据；NAS真实接口异常响应未注入实测。未提交/推送。

## 2026-11-01 iOS腾讯累计成交量回退被伪装成零

- iOS腾讯实时分钟解析在累计成交量减少时对负差值使用 `max(0, delta)`，会把数据源计数器回退伪装成真实零成交量；量价统计可能继续使用错误成交量。
- 现在价格点保留、对应成交量设为未知，之后以回退后的计数作为新基准。NAS provider 在同类回退时也将该点成交量设为未知。图表继续将可用分钟量加权线标为部分/非官方，并在图表说明里显示成交量未知的点数。新增回归覆盖初值、回退、恢复和后续增量；解析与图表Python源码合同加追踪共3/3通过。
- FCore XCTest定义增至327项，Windows主机无Swift/Xcode，新增XCTest未编译或执行；真实上游行为仍需实网确认。未提交/推送。

## 2026-11-01 NAS研究把非有限收益统计标为可审阅

- 当前归档允许有限且可转Float的极端价格（例如1e308和1e-300）。VWAP下穿后的百分比收益、早盘低点后的回收幅度或网格费用后净值可以超过Float范围；旧实现会输出Infinity，并可能仍将样本标记为available_for_review。
- VWAP、早盘回撤修复、网格三个研究器现拒绝超出有限Float范围及下溢成零的计算结果，报告rejectedNumericObservations；walk-forward聚合也fail-closed拒绝非有限样本。新增三类极值行情/数值回归，证明它们不会进入训练或OOS汇总。
- NAS研究、分钟归档、provider、runtime、service、股息研究和追踪组合128/128通过；全量Python 288项、286通过，另2个模块因缺PyYAML无法导入；py_compile通过。未部署NAS、未提交/推送。

## 2026-11-01 NAS研究builder将布尔阈值误当作有效最小样本门

- 服务入口会严格要求`minimum_independent_days`为真正的整数，但底层VWAP、早盘回撤修复、网格研究builder只比较数值；Python中`True == 1`，直接调用builder时可能把最小训练/样本外天数降至1，且`maximum_monthly_concentration=True`也会通过1.0边界。
- 新增共享严格校验：两个样本阈值必须是正的内建整数，月份集中度必须是有限的内建int/float并在(0,1]内，bool一律拒绝。三种builder分别新增回归，验证最小训练天数、样本外天数和集中度边界。
- NAS分钟服务全套45/45通过，`py_compile`通过；全量Python发现287项、285通过，两个模块因缺PyYAML未能导入。此变更只影响NAS Python；未部署到NAS，未提交/推送。

## 2026-11-01 Advisor无目标证券时跳过无效新闻请求

- 组合顾问没有真实持仓时，`targetCodes`为空；旧流程仍启动同花顺快讯请求，但新闻只按证券代码关联，抓到的内容不会进入Advisor上下文，形成无用外网访问。
- `refreshNewsFeedInBackground` 现在先检查目标证券列表；空列表更新状态为“当前没有目标证券，跳过证券关联快讯”并返回，不建后台任务。新增Python源契约覆盖该早退顺序。
- Advisor安全、新闻信任、Home及追踪合同合并执行61/61通过；全量Python发现286项，284项通过，两项因缺PyYAML未能导入。Swift/Xcode不可用，App仍需Apple编译及设备验证；未提交/推送。

## 2026-11-01 首页账本内资产估值补齐

- 原首页只显示现金、持仓数量、今日证券盈亏和逐证券本轮浮盈亏，缺少组合层面的持仓市值与总资产摘要。
- 新增 `FPortfolioMarketValuationCalculator`，仅对人民币账本计算现金+全部真实持仓市值；每一笔持仓必须有可信且不超过120秒的行情。任一报价缺失、过期、来源不可信、账本异常或结果不可表示时，整项失败关闭；界面列出缺报价代码，不把可用部分相加。报价时点使用所有估值行情中最早的一个。
- 新增5个FCore XCTest定义（完整组合、缺报价、过时/不可信报价、现金-only/币种、Decimal溢出）及首页Python源契约；Home布局/追踪专项30/30通过。全量Python发现285项、283通过、2个模块因缺PyYAML导入失败；compileall与架构边界通过。
- Swift/Xcode不可用：324项FCore XCTest和11项UI XCTest均未在本机运行；尚无本次改动的Apple编译或Simulator/真机视觉证据。总值范围明确为“账本内”，不代表券商账外资金或完整家庭资产。尚未提交/推送。

## 2026-11-01 美国指数夏令时回拨时点存在歧义

- B-136核对发现，纳斯达克供应商行情时间按 `America/New_York` 本地时区解析。秋季回拨日的重复墙上时间（如 01:30）没有UTC offset时对应两个不同瞬间；原解析器会由系统任选一个，使行情时点最多差一小时。
- `FMarketIndexTimestamp.parse` 现在枚举该墙上时间附近时区offset并验证候选UTC瞬间；若找到多个则拒绝。春季跳时不存在的本地时刻仍由往返校验拒绝。新增纽约DST切换前后正例及回拨/跳时反例Swift XCTest定义，Python源合同15/15通过。
- 当前FCore测试定义319项、App UI 11项；全量Python发现284项，282项通过，2项因本机缺PyYAML未导入。Swift/Xcode不可用，新增XCTest和DST规则仍未Apple编译执行。此修复不完成全跨市场UTC存储、官方交易日历或全部市场DST验收；未提交/推送。

## 2026-11-01 首页主题验收遗漏径向布局节点关系

- 十主题UI用例对九个常规主题检查纵向角色顺序，却将数据星图主题整个排除；原用例名仍写“顺序一致”，可能造成覆盖范围被误读。
- 更新用例名并为星图主题增加组合居中、行情右上、跨市场右下、顾问左下及三个导航节点均可点击的几何/交互断言；同步修正B-053/B-060/B-104追踪锚点和未验收状态。Home布局Python合同25/25及追踪合同3/3通过；XCTest尚未由Simulator执行，截图仍未人工审阅。

## 2026-11-01 NAS上游响应大小限制只截断而未拒绝超限

- Tencent/Nikkei指数日线与Tencent/Eastmoney分钟采集器用 `read(limit)` 限制了内存，但未判断真实响应是否超过上限；即使Content-Length缺失/不可信，也可能把合法JSON前缀当成完整响应继续解析。
- 新增共享 `read_bounded_body`：校验Content-Length，最多实际读取上限+1字节，并在任何超限时失败；接入NAS指数、分钟和官方日历HTTP采集器。部署包按整个 `nas/fminute/*.py` 打包，会自动包含新模块。
- 新增精确上限、超限流、Content-Length、错误声明值仍被真实读取上限拦截及源接线回归。相关NAS provider/index/runtime/service测试79/79通过；全量Python发现282项，其中280通过、两项因本机缺PyYAML无法导入；pip安装尝试因代理套接字权限被拦截。Swift/iOS不可用；真实上游与NAS部署未验证。

## 2026-11-01 追踪表命名测试锚点未做失效检查

- 145行/列结构及文件路径存在检查原本通过，但没有验证明确写出的`test...`函数名仍存在。盘点当前追踪表有71个显式命名测试锚点，71个目前都能在对应Swift/Python测试文件找到；旧合同若遇测试重命名不会失败。
- 扩展追踪表合同，逐个解析`.swift:`和`.py:`后面的命名测试方法，要求源文件有对应`func`/`def`定义，同时保留连续ID和文件路径检查。合同3/3通过；完整Python发现更新为264项、262项通过，两个PyYAML依赖模块导入失败。未改动任何产品行为。

## 2026-11-01 日盈亏初始快照门控接受非规范交易日期

- B-018 的 `openingSnapshotSupportsDailyPnL` 通过 `split("-").compactMap(Int)` 解析日期；它会丢弃空字段，因此 `2026--10-20` 被解释为2026年10月20日。该入口用于判断有初始持仓的开盘时点能否支撑全天证券盈亏，畸形日期必须失败关闭。
- 改用精确10字节ASCII `yyyy-MM-dd` 结构并将日历解析结果回转为规范日期，拒绝双连字符、非补零月份、无效日历日和Unicode数字。LedgerSchema XCTest加入反例；Python源合同与Advisor/盈亏合同26/26通过。Swift XCTest未能在当前主机运行。

## 2026-11-01 Advisor非阻塞回归未覆盖全部NAS路径

- 实际调用顺序确认：提问主路径只读当前缓存的NAS Research Summary，并在独立`Task`中刷新摘要；行情刷新调用实时公开行情源，不调用NAS。历史指数Regime由独立刷新入口读取NAS，没有放在Advisor同步调用链。
- 原源码合同只禁止Advisor `await refreshNASResearchEvidence`，没有覆盖其它NAS客户端或指数Regime刷新；扩展同一合同，移除背景刷新块后禁止任何Await NAS client、NAS cache refresh和历史指数Regime刷新，并断言实时行情刷新不含NAS调用。
- Advisor安全合同23/23通过；行为源码未改动，Swift/XCTest和真实网络耗时仍待Apple/设备验收。

## 2026-11-01 NAS历史采集与研究准入复核

- 沿 provider→archive→queue→research 逐段检查：provider空结果会记为失败并继续备用源；不在会话预期时间内的行先拒绝再写入；不完整/质量不达标的会话不会进入研究样本；回填仅在全部预期分钟、质量、来源完整性、成交量和时间门均满足时标记complete。部分结果会重试，达到上限后保留为partial，不会伪装为完整。
- 当前 source coverage 明确标注尚未实证，研究输出也显式给出单源/交叉验证会话数；即使研究有可审阅结果，生产端仍没有策略资格签发器，Local Quant继续拒绝资产变化候选。
- 运行分钟归档、补采服务、runtime、指数日线与API专项测试：123/123通过。这个结果验证确定性逻辑，不证明真实上游历史覆盖或NAS部署运行。

## 2026-11-01 Actions并发与NAS包入口复核

- 当前仅有两个GitHub Actions工作流；各自以`github.workflow`建立独立并发组，`cancel-in-progress: false`，每个工作流最多一个运行任务，因此工作流合计并发上限为2，符合用户当前限制。工作流合同5/5通过。
- NAS发布包把Compose与Dockerfile放在项目根目录，并将构建上下文改为`.`；Dockerfile所需的`nas/`目录、entrypoint和Python模块均按包路径包含。实际构建21文件ZIP并检查根目录布局及构建路径通过。Compose YAML解析/类型断言因本机缺PyYAML依赖仍需CI执行。
- 本轮无需调整工作流或打包代码；没有提交或推送。

## 2026-11-01 主验收矩阵顶部快照过期

- 需求追踪表仍有145个连续且唯一的B编号，但`F-MASTER-ACCEPTANCE-MATRIX.md`顶部快照把FCore测试定义数写成220，并错误称本机没有Python，和当前工作树与前一轮实际执行结果冲突。
- 重新从当前源树统计为FCore 309项测试定义、UI 10项；Windows可运行Python 3.12，完整发现263项、261项通过，两个PyYAML依赖模块导入失败。修正顶部快照，并同步记录HTTP响应流式上限与本轮未执行Apple测试的边界。
- 本项是文档准确性修复；145行连续ID的事实仅证明追踪表结构完整，不代表145项全部实现或验收。

## 2026-11-01 iOS公开网络读取仍无响应体上限

- 审计发现实时行情、跨市场指数、NAS Research和DeepSeek仍有多个`URLSession.data(for:)`调用，会在JSON/字段校验前完整缓存服务器响应；NAS专用读取器已有流式限制，但实现重复且其它网络路径没有保护。
- 新增共享流式HTTP读取器：检查已知Content-Length并在读取期间强制上限。NAS与Research 4MB、DeepSeek 2MB、公开指数/行情128KB；新闻客户端仍按既有1MB上限独立读取。应用源码不再有整段无界`URLSession.data(for:)`调用。
- 加入覆盖所有App Swift源文件的合同检查。网络边界聚焦测试18/18通过；Python全量发现263项、261通过，两个模块因缺PyYAML不能导入。Swift/XCTest未执行；未提交/推送。

## 2026-11-01 ETF映射追踪说明漏记159352→中证A500

- 复核B-141时发现追踪说明只提159941→Nasdaq-100，却漏记已登记并接入的159352→中证A500映射；同一行还把跨市场归因概括为Unavailable，容易和已有的benchmark-only Advisor/Local Quant使用相冲突。
- 已区分“普通指数状态不得自动归因”与“两项已核验发行方基准映射”，补齐来源范围、门控用途和仍未实现的其它ETF溢价/流动性组合；增加合同校验明确登记的两项映射。
- 测试待本轮复跑；未提交/推送。

## 2026-11-01 跨市场指数页仍声称没有ETF映射

- 逐项复核 B-140 UI 时发现，指数页说明仍称指数Regime“尚未映射到持仓ETF”，与已实现的159352→中证A500、159941→纳指100发行方映射以及Advisor/Local Quant门控相矛盾。
- 已改成只列两项已确认映射，并说明用途是顾问背景和Local Quant策略准备；明确不代表策略资格/交易信号，其他ETF不自动套用。新增源码合同并更新B-140。
- 图表/跨市场UI/Advisor安全/追溯合同50/50通过；完整Python发现252项通过，两个PyYAML依赖模块无法导入；当前SwiftUI和真机视觉未执行；未提交/推送。

## 2026-11-01 当前IOPV污染历史分时与日K纵轴

- B-059要求明确说明IOPV是实时快照、不是历史序列。检查共享ChartOverlayModel发现，只要当前IOPV可用，它就被加入所有图表的priceRange；统一Canvas也会在历史分时和日K画当前IOPV水平线。当前值因此能把历史纵轴拉宽，并被误读为历史参考。
- Core现提供只用于`.liveIntraday`的`liveIOPV`；价格范围与iOS绘制/图层选择都通过该门，历史分时和日K不会接收当前IOPV值，并明确提示“IOPV仅实时快照，无历史序列”。新增实时图保留IOPV范围和历史图排除IOPV范围的XCTest，以及UI源码合同；更新B-059、F-18/F-41。
- 图表UI源码合同、追溯和Advisor安全合同49/49通过；完整Python发现251项通过，另有两个PyYAML依赖模块无法导入；compileall、架构边界和差异检查通过。当前Windows没有Swift/Xcode/Simulator，本轮Swift编译、XCTest与设备视觉仍待验证；未提交/推送。

## 2026-11-01 映射指数Regime接受晚于观察时点的数据

- Risk Guard的普通证券Regime已拒绝 `dataAsOf` 晚于观察/采集时间的证据；继续逐路审查发现，发行方映射指数Regime只校验到采集时间，缺少与 `observedAt` 的比较。若NAS Regime观测在旧时间采集、但引用中声明更晚的行情数据，映射ETF买入门仍可能接受。
- `FDecisionMappedBenchmarkEvidence` 现同时要求 `dataAsOf <= observedAt`、`<= capturedAt`、`<= now`；新增映射证据时序倒置反例，扩展Risk Guard源码合同，并在B-086列明两种Regime证据的时序要求。
- 新增Swift XCTest未能在当前Windows主机执行；关联Advisor安全/追溯合同25/25通过，完整Python发现250项通过，另两个PyYAML依赖模块无法导入；compileall、架构边界和 `git diff --check` 通过。未提交/推送。

## 2026-11-01 当前状态页与工作树证据不一致

- 追溯审计发现 `F-STATUS.md` 顶部当前快照仍称FCore只有257项测试、本机没有Python解释器，并把Regime/Local Quant当前完成度写成旧状态；实际源树有295项FCore XCTest定义，Python 3.12可执行，且已有Regime/Local Quant因子消费代码。旧描述会把历史限制误当成当前事实。
- 已更正状态快照：标明295/10项测试定义、Python当前结果、Apple工具链缺失、已编码组件与仍未端到端验证的边界。没有把代码存在表述为策略资格通过。
- 当前完整Python发现执行250项通过，两个模块因缺少PyYAML无法导入；修正一个新增源码合同测试中的Python无效转义警告后，相关聚焦合同24/24通过。编译、架构边界、追溯检查和差异空白检查通过；Apple编译/XCTest仍未执行。未提交/推送。

## 2026-11-01 NAS历史刷新不会清除上游已移除日期

- 复核指数/证券日K归档更新策略发现，成功刷新只UPSERT，不会清除本次上游完整快照覆盖范围内、但上游已移除的日期；旧的错误/撤回K线因此长期参与Regime。
- `IndexDailyHistoryArchive._write`现只在本次返回数据的首末日期范围内删除不再出现的已归档日期，然后事务内写入最新行；范围外历史仍保留。新增先归档60行、源端撤回其中一日、成功刷新后数据库及响应都不再包含撤回行的回归。
- NAS指数历史专项、API与追踪检查均通过；本机可运行Python全集243项通过（两项PyYAML依赖模块未导入），`compileall`、架构边界与`git diff --check`通过。真实上游修订行为仍需NAS部署验收；未提交/推送。

## 2026-11-01 Security Daily P&L公开计算入口未校验反序列化摘要

- 账本回归已证明DecisionContext会拒绝被篡改的FDailyTradeSummary，但独立的`FSecurityPnLCalculator.dailySecurityPnL`公开重载没有调用摘要自检；可将有效买入填单JSON中的`buyQuantity`改为0，再直接计算出结果。
- 两个计算重载现在都要求摘要在其自身`lastFillTime`及CN交易日口径下通过结构/金额/数量/时间完整性验证，否则抛`invalidInputs`。新增回归确认篡改摘要不能通过任一重载。
- Security Daily P&L源码契约与B-018追踪检查4项通过；本机可运行Python全集242项通过（两项PyYAML依赖模块未导入），`compileall`、架构边界和`git diff --check`通过。新增Swift XCTest未在Apple工具链执行；未提交/推送。

## 2026-11-01 日经CSV显式交易日坏收盘价被静默丢弃

- 复核指数历史源的质量门发现，日经CSV对可解析日期上的格式错误或非正收盘价会静默跳过；NAS可能用其余至少60行继续标记available，使受损交易日看起来像正常缺市。
- 现在仅忽略无效日期行、当前未完成日和明确缺值占位（空、`.`、`-`、`N/A`）；已完成日期配坏格式/坏数值时整份拉取失败关闭，不写入更新缓存。增加千分位错位、NaN和零收盘价回归。
- NAS指数历史专项与API测试、B-140追踪契约均通过；本机可运行Python全集242项通过（两项PyYAML依赖模块未导入），`compileall`、架构边界与`git diff --check`通过。实网CSV和Apple端Regime仍待部署/设备验收；未提交/推送。

## 2026-11-01 Trigger报价水位回退与未来时点污染

- 继续复核B-145乱序保护发现，终止计划、过期计划或无计划早退仍可能让旧报价写回而回退水位；修复后又发现单纯取最大值会让未来/未验证/错标的报价污染水位。
- 现在所有返回路径都保留单调时点，但只有同计划证券、可信来源、可信交换时间且`quoteTimestamp <= fetchedAt <= now`的报价才可推进；无计划、不可信、未来或错证券报价不建立/推进水位。新增早退、未来报价、未知来源和无计划回归。
- Regime/Trigger源码契约及B-145追踪结构11项通过；本机可运行Python全集241项通过（两项PyYAML依赖模块未导入）；`compileall`、架构边界和`git diff --check`通过。新增Swift XCTest尚未由Apple工具链执行；未提交/推送。

## 2026-11-01 本地全量可运行检查复核

- 重新执行 `unittest` 发现时，241个不依赖PyYAML的测试全部通过；`test_ios_app_structure.py` 与 `test_nas_deployment_package.py` 因当前Python运行时未安装PyYAML而无法导入。仓库iOS/Python CI均声明安装PyYAML后运行完整发现，仍需CI结果确认这两模块。
- `python -m compileall -q nas Tools`、`Tools/verify_architecture_boundaries.py` 和 `git diff --check` 均通过。仅有Git提示部分工作文件采用LF、Git配置下次写入会转换CRLF，不是差异检查失败。
- 当前主机没有Swift/Xcode，Apple Package/XCTest、iOS设备/Simulator视觉与导航验收仍未完成；本轮没有提交或推送。NAS研究资格闭环、逐证券交易规则和实机端到端仍属开放项。

## 2026-11-01 Trigger计划Codable解码绕过构造器校验

- 在为`FQuantTriggerPlan`增加份额/价格规则时继续核对其存储契约，发现合成`Codable.init(from:)`不会调用经过校验的公开构造器；不合法的归档JSON仍可能带着1份/非tick价格进入Trigger。
- Trigger计划现用自定义解码器委托到唯一校验构造器。新增先编码有效计划、再逐项篡改数量、区间边界和失效价、要求解码拒绝的XCTest，并补Python源码契约。
- 相关Python源码契约13项通过，可运行Python全集241项通过（两个依赖PyYAML的模块未纳入）；Swift/XCTest需Apple CI。未提交/推送。

## 2026-11-01 Realtime Trigger计划未执行交易单位/价格步长门

- 延伸B-089交易规则审计发现，Risk Guard虽检查CN场内基金候选的100份数量单位和0.001元限价，但`FQuantTriggerPlan`构造器只要求份额为正、价格有限；内部Trigger计划因此可携带1/10份数量或非合法tick区间。
- Trigger计划现与Risk Guard共用场内基金规则：所有触发计划份额需符合100份递增和单笔上限，买卖区间及失效价都必须是0.001元递增。卖出剩余零头仍可通过直接Candidate完整卖出，但Trigger计划本身因缺少Ledger持仓上下文，不创建非整手卖出提醒。
- 补充非法份额、非法区间价和非法失效价的XCTest，并扩展Python源码契约。可运行Python全集241项通过（两个依赖PyYAML的模块未纳入）；该Swift XCTest尚待Apple工具链执行。逐证券涨跌幅和特殊交易规则仍未接入。未提交/推送。

## 2026-11-01 Realtime Trigger重复报价/乱序报价保护

- 逐项核对B-145 Candidate/Trigger状态迁移时发现，纯Trigger只接收上次状态与计划ID，没有上次已处理报价时点。若同一快照重复处理或异步响应乱序，旧价格仍在120秒新鲜窗内时可以错误推进状态，例如把已触发计划误标为LeftZone，或把重复快照再次当成新触发。
- Trigger API现接收调用方持久化的`previousQuoteTimestamp`。报价时间未严格晚于上次时间时不推进候选状态；仍先执行会话、Regime和风险检查，避免重复报价绕过新风险状态。评估结果分开提供当前报价时点与单调不回退的`lastProcessedQuoteTimestamp`，旧报价仅供诊断，调用方应只持久化后者。接入端尚未存在，未来App调用必须保存并传入该时点。
- 新增重复触发价与旧离区价XCTest及Python源码契约；可运行Python全集240项通过（两个依赖PyYAML的模块未纳入本轮）。Apple XCTest尚未运行。候选生成/持久化/通知链仍未接通；未提交/推送。

## 2026-11-01 Risk Guard拒绝不符合场内基金份额与价格步长的委托

- 对照B-089核验FRiskGuard时发现，虽然候选会校验现金、持仓和正数限价，但1份/10份买入与非0.001元倍数的价格仍可放行。上交所与深交所规则规定基金竞价买入以100份递增、基金报价最小步长0.001元，且单笔申报上限为100万份。
- 新增FCore通用场内基金规则校验并接到每个资产变化候选的Risk Guard：买入份额按100份且不超过100万份；卖出允许100份倍数或一次性卖出全部剩余份额；价格必须是0.001元步长。未实现逐产品涨跌幅/特殊交易限制，不能假设统一涨跌幅。
- 新增规则纯函数回归、Guard反例及Python源码契约，并更新B-089。修改后可运行Python全集239项通过；相关Risk Guard/源码契约26项通过；Python compileall、架构边界及`git diff --check`通过。Swift XCTest本机无法运行。官方依据：[上交所ETF交易问答](https://www.sse.com.cn/assortment/fund/etf/question/c/c_20240118_5734754.shtml)、[上交所2026年修订交易规则](https://www.sse.com.cn/lawandrules/sselawsrules2025/fund/trading/c/c_20260424_10817739.shtml)、[深交所2026年修订交易规则](https://docs.static.szse.cn/www/lawrules/rule/trade/W020260424690713155663.pdf)。逐证券涨跌幅和ETF特殊交易限制仍待有来源的规则数据接入。

## 2026-11-01 iPhone Research Evidence资格门核对训练/OOS样本与日期

- 继续复核NAS Research Evidence消费路径时发现，iPhone原先只看`evidenceState`、训练/OOS数量和月度集中度，没有复核独立日数是否等于两段数量之和、嵌套统计的样本数是否一致，也没有检查训练与OOS日期顺序及其是否落在实际归档`dataRange`内。摘要字段因此可能与证据实际样本区间矛盾。
- iPhone资格判断现在要求独立日数一致且不超过Envelope覆盖；训练/OOS最小样本门、嵌套统计日数、训练结束早于OOS开始，以及两段都位于dataRange内必须全部成立。compact summary与按证据族资格判断复用同一门槛。
- 新增不一致样本数和重叠窗口拒绝回归，并补源码契约。NAS归档/证据服务专项92项通过；可运行Python全集236项通过（排除两个依赖PyYAML的模块）；`compileall`、架构边界检查和`git diff --check`通过。当前主机没有Swift/Xcode，Apple编译与XCTest尚未执行；未提交/推送。

## 2026-11-01 网格参数扫描只开放训练期选出的一个样本外结果

- 在修正样本外headline之后继续追查B-134的多重比较风险：固定4个网格间距都可展示同一留出集表现，仍允许按测试集挑出赢家。
- 网格间距现在只按训练期税后每交易日收益选择一个正收益候选（相同收益取较小间距）；仅该候选暴露样本外统计，其他间距的OOS统计置空。未找到正收益训练候选时不展示任何OOS结果。Research Evidence服务端和iPhone Guard校验最多一个被训练期选中的网格留出结果；方法版本升级为`minute-research-2`，旧方法摘要不能被标成当前证据。
- 新增NAS证据单选门回归、iPhone拒绝重复网格holdout回归和旧方法版本拒绝回归；分钟归档研究和服务端相关回归92项通过。之后的可运行Python全集已增至236项通过（两个依赖PyYAML的模块未纳入本轮），Apple编译/XCTest未执行。此前UI摘要夹具也发现`qualifiedIndependentDays=28`却声明complete覆盖仅20，已修正夹具以匹配证据约束。

## 2026-11-01 NAS研究Headline误混训练集与样本外集

- B-134/B-135复核发现，VWAP、早盘急跌修复与网格回放虽然计算了按日期留出的 `training` / `outOfSample` 统计，但 `medianReturnPercent`、`recoveryRate`、`netAfterFees` 等摘要字段仍用全部样本计算，导致训练期结果掺入样本外结论。
- 三类研究现在分别发布训练集与样本外指标；既有headline字段明确改为仅对应时间序列holdout，并标记 `headlinePopulation=out_of_sample`。资格门未通过时headline仍为Unavailable；网格成交笔数也区分训练集、样本外和全量描述计数。此修复不等同于统计显著性或策略资格认证。
- 分钟归档研究回归47项通过，涵盖训练/OOS结果方向相反的样例。NAS实网Research Evidence兼容、Swift摘要消费和Apple构建仍待验证；未提交/推送。

## 2026-11-01 Shadow计划触发后的失效条件观察

- B-144逐项核对发现，Shadow归档允许已经触发的Candidate继续记录一小时市场结果，但若计划 `validUntil` 早于该窗口结束，失效价只在原有效期内检查，窗口内后续跌破失效价会被漏记。
- 失效检查现覆盖至同一触发后观察窗口的末尾；没有触发时仍受原计划有效期约束。新增有效期结束后触发并跌破失效价的XCTest和源码契约。
- 源码契约39项通过；新Swift XCTest未在本机执行。Quant-only、Risk Guard层与最终建议的独立结果评分仍未实现，未提交/推送。

## 2026-11-01 复核此前零波动修复遗漏的最终返回条件

- 本轮重新核对 `returnVolatility` 源码时发现，先前审计记录和回归测试声明零方差已保留为有效观测，但函数最终仍使用 `result > 0`，因此实际会返回 `nil`。这是此前静态验证只核对方差中间条件、没有核对函数出口导致的漏检。
- 已将最终条件改为有限且 `>= 0`；需要正波动率作为分母的因子仍由各自调用点要求 `scale > 0`。源码契约现在同时确认允许零值且禁止旧的正数门槛；Swift XCTest已断言返回值为0，但当前Windows没有Swift/Xcode，尚未执行Apple编译或XCTest。
- 该发现说明历史审计文本本身也需以当前代码复核，不能把此前记录当成实现证据。未提交/推送。

## 2026-11-01 Quant 资格策略与双 Regime 一致性

- 深入检查 mapped-market Risk Guard 后发现，虽然 ETF 自身和发行方映射指数的 Regime 都能阻止严重风险，但 Guard 原先只验证策略资格绑定了证券和自身 Regime，没有核验凭证中的具体策略是否同时被两层 Regime 允许。
- 新增共享 Regime 策略许可查询和规范策略 ID 映射；普通买入/做T/网格必须同时通过证券 Regime 与映射指数 Regime 的策略许可。未知策略 ID 失败关闭；卖出减仓不受这项买入策略许可检查影响。
- 新增 Bull 下不允许 Mean Reversion、映射指数 Bear 下不允许 Mean Reversion 的双层回归，并补充 Python 源码契约。Swift/Python 测试和 Apple 编译仍未执行；不提交/推送。

## 2026-11-01 Guard 拒绝候选的顾问卡片回归

- 复核顾问慢链发现FRiskGuard确实会拒绝缺少资格、旧行情或风险不允许的资产变更候选；Advisor卡片也已有分支，拒绝时隐藏Candidate Plan和成交登记按钮、显示Guard原因。
- 这条关键UI安全边界此前没有专门回归；新增 `test_guard_denied_candidate_is_not_rendered_as_reviewable_or_confirmable` 源码契约，并更新B-086。真实Simulator拒绝态和按钮可达性仍未执行/验收。

## 2026-11-01 跨市场实时指数刷新与NAS历史Regime刷新解耦

- 首页实时指数刷新此前会无等待地启动NAS历史指数Regime请求；虽不阻塞报价，但把独立的实时操作和NAS历史依赖耦合，也会在每次实时刷新时重复触碰NAS。
- 实时刷新现在只请求手机直连的指数报价；首页首次打开时将实时行情与NAS历史Regime作为两个独立并行任务。另提供独立的“更新历史状态”按钮，供NAS地址变化或历史数据更新后手动重读。
- 新增源码契约，核对实时刷新和实时按钮不含NAS调用，同时保留独立历史加载入口。当前主机没有可运行的Python/Swift/Xcode工具链，契约、Apple编译和屏幕验收尚未执行；未提交/推送。

## 2026-11-01 F-16在线顾问现状复核

- 旧验收总表把DeepSeek联网调用和Keychain密钥存储都列为未接入，与当前`FDeepSeekCandidateProvider`和`FAdvisorAIKeychain`源码不符，已更正为“已编码、实网未验”。
- 仍开放的实际缺口是本地Quant合格策略资格未下放、公开新闻接口稳定性与无持久缓存、真实密钥端到端、模型拒绝路径/错误降级的设备验收和当前dirty App的Apple构建；没有把实现代码或测试定义误记为运行通过。

## 2026-11-01 Advisor可选新闻不再同步阻塞

- 复核确认 Advisor 每次提问都 `await FNewsClient.fetchLatest()`，第三方新闻接口最长等待8秒，尽管系统约定无新闻时也应继续基础分析。
- Advisor现在只把24小时内新鲜、已缓存的新闻加入本轮上下文；无缓存时写入明确Unavailable观察并立刻继续。新闻刷新独立后台执行，合并并发请求，失败/空响应后120秒内不重复请求；仅驻留内存的缓存不会跨应用重启保留。
- 将纯新闻Feed/新鲜度模型放入FCore，新增 `Tests/FCoreTests/NewsFeedTests.swift` 覆盖24小时边界、未来/过期fetch、晚于feed采集时点的文章和空缓存；feed文章不得晚于采集时点。另新增 `Tools/test_advisor_safety_contract.py` 源码契约覆盖后台刷新和不等待网络。Advisor安全、新闻信任、Home与追踪源合同合并执行60/60通过；全量Python发现285项，283项通过，两个依赖PyYAML的模块仍因环境缺该依赖无法导入。Swift/Xcode不可用，NewsFeed XCTest及App编译未执行；公共新闻接口和设备网络行为未实测；未提交/推送。

## 2026-11-01 持久离线行情缓存与新鲜度边界

- B-082复核确认实时分钟行情此前只存在`FHomeModel.marketDataByCode`内存，应用重启后无法展示上次真实分时。
- 新增FCore `FMarketQuoteCache`：每证券一个版本化JSON快照、单记录最多500点/512KB、最多250个证券文件、30天保留，写入原子替换；超量、过期、损坏或错误版本文件在回读时清除。回读重建`FCurrentIntradaySnapshot`以重复校验代码、样本、来源和时点；乱序旧写不能覆盖更新记录。iPhone仅在实时provider成功后异步保存；启动时恢复并标记“本机缓存/仅供离线查看”，刷新失败时保留最近缓存并明确显示时间与错误。
- Advisor/Risk Guard仍检查行情120秒新鲜度，Trigger亦要求新鲜行情；旧档案只展示，不被当作当前实时证据。新增缓存 XCTest 和 App source contract；当前环境未运行Swift/Python，飞行模式/设备验收尚缺；未提交/推送。

## 2026-11-01 持久行情缓存文件类型边界

- 复核缓存目录遍历时发现，名字匹配证券代码的目录或符号链接也会进入记录清理/解码路径；目录清理会失败，而链接会被跟随读取，不符合缓存仅管理自身普通文件的边界。
- 缓存读取和容量淘汰现在只筛选普通文件并排除符号链接。新增回归定义：同名目录和指向目录外目标的链接均保留、不载入，链接目标字节不变；source contract 同步检查此约束。
- 当前无可用Swift/Python执行工具，本次只完成源码/测试定义和静态检查；Apple XCTest、源契约及设备缓存验收仍待执行；未提交/推送。

## 2026-11-01 Local Quant 平稳行情波动率边界

- 逐项复查Local Quant因子时发现，收益序列方差为零会被`returnVolatility`当成无效值，导致真实平稳行情的波动率测量被显示为Unavailable。
- 零方差现在保留为有效的0波动观测；需要以波动率作为归一化除数的因子仍只在尺度大于0时计算方向分数，不会除以零。新增平稳20分钟行情回归与源码契约；NAS参数资格、候选生成和Guard边界不变。
- 当前Swift/Python测试定义未运行；Apple编译、因子UI展示和真实报价验收待执行；未提交/推送。

## 2026-11-01 Local Quant 趋势结构历史覆盖边界

- 对照“MA20/60/250结构”检查因子计算，发现趋势结构会在仅有MA20时就输出可用值，单一均线不能表达多期限结构，且未提示覆盖不足。
- 现在至少需要两个独立可用的均线期限才输出趋势结构；20日历史保持Unavailable，60日历史可利用MA20/60，不会把缺少MA250伪装成已覆盖。新增20/60日历史分界 XCTest 与源码契约。
- 策略资格和候选行为未放宽。当前Swift/Python测试定义未执行；Apple编译、真实日线与因子界面验收待执行；未提交/推送。

## 2026-11-01 本地策略资格必须绑定市场Regime

- Quant架构要求按“证券 × Regime × 策略”分别验证；当前运行时资格票据只绑定证券、策略ID和版本，存在把Range资格复用于Bull/Bear的结构性缺口。
- 资格观察与不可序列化运行时grant现均要求相同的`FMarketRegime`；FRiskGuard先确认新鲜的证券Regime，再只接受该Regime对应的策略资格。增加跨Regime借用拒绝回归，并更新已授权候选夹具。
- 当前仍无NAS产出的生产资格包，也无Apple工具链运行证据；此改动只是把授权契约和风险门槛绑定正确，未宣称本地策略已经具备资格。未提交/推送。
- 复核同一DecisionContext可携带多个同证券Regime观察；原实现按数组顺序采用第一个有效状态，存在输入顺序决定放行结果的问题。现在同证券当前Regime必须唯一，否则失败关闭；新增相互冲突的Range/Bear观察回归。Swift/Python执行仍不可用。

## 2026-11-01 账户级杂费与现金对账分类

- B-088审计发现账户级杂费虽然可通过现金调整入口记账，但和余额对账使用同一个无类别事件，现金流水只能靠自由文本识别，不能稳定区分费用与余额更正。
- `FCashMovement`新增可选类别，兼容旧账本解码；负向账户级费用记为`accountExpense`，正向余额核对记为`cashReconciliation`。流水显示对应类别，并继续保持无证券代码、无fill关联；不改变证券成本/盈亏与持仓。用户界面明确展示两种现金事项。
- 增加Ledger XCTest断言类别、无证券归属和“账户级费用不可记成现金流入”，并增加源码契约；当前主机没有可运行Python/Swift工具链，尚未执行这些测试，也未做Apple编译或Simulator验收。无提交/推送。

## 2026-11-01 Risk Guard缺少Market Regime硬门槛

- B-086核对发现Realtime Trigger会暂停Extreme风险下的普通T买，但通用`FRiskGuard`只校验行情、资格、份额和现金。直接通过顾问守卫提交的已资格化买入候选仍可能绕过Regime状态。
- FRiskGuard现要求同证券、新鲜且引用的FCore Regime证据；校验Regime/Risk值、confidence与dataAsOf，超过5日、错证券、缺字段均失败关闭。买入/做T/网格在R3/R4、Risk-Off、Extreme、Uncertain或Data Unreliable下被拒；卖出风控不被同一买入门槛误拦。
- 增加错证券Regime、未引用Regime、Extreme、Risk-Off、严重风险、数据不可靠与过期证据回归，并更新已授权候选夹具。源码契约已加；Windows无Swift/Python运行工具，本轮未执行测试或Apple构建。无提交/推送。
- 后续检查补充买入不追价门槛：Risk Guard拒绝高于最新新鲜成交价的买入/做T/网格限价，并有回归定义。当前行情快照没有已验证bid/ask或盘口数量字段，价差宽度和相对盘口深度无法安全计算；不以分钟成交量冒充盘口。该部分仍开放。

## 2026-11-01 跨市场指数报价滞后未在卡片显示

- 指数卡片此前展示原始行情时间和供应商交易状态，但交易中报价即使已滞后仍未明确标记；交易状态未验证时也缺少按时点年龄的提示。首页可将较旧的跨市场报价看成当前行情。
- 现在用共享120秒时间阈值和同一时间可信度校验；OPEN报价显式显示新鲜/滞后/未验证，CLOSE显示最后行情时间，未知状态显示时点新鲜度且不假定已收盘。对未验证时点先失败关闭。修复OPEN/CLOSE标签始终包含交易时段文字，覆盖既有UI验收断言。
- 指数卡片用15秒TimelineView重算显示新鲜度，不增加网络请求，避免静止页面永远保留“新鲜”标签。源码契约已覆盖这项行为；完整Swift/Python/UI运行仍需目标工具链。

## 2026-11-01 修复 B-009 追踪表缺少测试锚点列

- 145项结构检查发现B-009将源码锚点与测试锚点合并在同一Markdown单元格，导致该行只有12列，其余144行均为13列。已拆分源码/测试锚点，并补入本轮实时行情可信度回归。复核确认B-001…B-145顺序连续、145项唯一且每行13列。

## 2026-11-01 统一实时行情新鲜度阈值

- 顾问与 Risk Guard 默认以120秒作为实时行情新鲜度上限；首页与实时图表此前使用300秒，造成同一报价在不同区域显示“新鲜”与“过期”的结论不一致。
- `FQuoteTemporalMetadata.defaultMaximumAge`现作为统一阈值；首页文字与盘中图表状态共用该规则，边界定义为120秒整仍新鲜，超过即过期。新增核心边界回归和首页/图表源码契约。
- 本轮只完成源码级校核；当前环境无Swift/Xcode测试执行能力，相关XCTest与iOS视觉验收仍待macOS/CI。

## 2026-11-01 Trigger拒绝未映射的宽基Regime上下文

- Trigger此前只校验Regime携带的`securityCode`与候选证券相同；调用方仍可把通用`CN`宽基状态标注为该证券，然后触发交易候选。生产页面当前使用证券自身日K键`security:<代码>`，所以现在同时强制校验该精确市场键；未建立指数到ETF的映射时，通用宽基上下文暂停候选。新增反例 XCTest 与源码契约，Apple执行仍待CI。

## 2026-11-01 Tencent指数行情时间戳接受非法日历日期

- 指数解析器通过`Calendar.date(from:)`构造时点，却没有核对构造后的年月日时分秒；同时无效时区会回退到设备本地时区。Foundation可能归一化不存在日期，而本地时区回退会误读跨市场时间。现已抽取FCore共享解析器，逐项回验日期组件且无效时区直接返回`nil`；增加了非法日期/时间、无效时区及有效解析XCTest和源码契约，Apple/Python测试尚未运行。

## 2026-11-01 Market Regime MA250已计算但未参与分类

- `ma250`此前只出现在返回的均线字典中，分类只用MA20/MA60。现在增加MA60/MA250趋势因子；满250个样本时，短期与长期结构冲突会立即切到`transition`并退出记忆中的旧Bull/Bear确认态，不再等待常规趋势确认周期，并返回`short_long_trend_conflict`原因码。短期反弹不会直接标成Bull，长期上升中的短期回落也不会直接标成Bear。少于250日时因子明确Unavailable，仍保留原有最低60日数据门槛。新增样本不足、两个方向冲突和已确认Bull即时退出的XCTest、源码契约；当前无Swift/Python运行证据。

## 2026-11-01 解码后的每日成交摘要缺少数量与金额交叉校验

- `FDailyTradeSummary`可经Codable解码，原`isValid`虽检查有限值、日期、手续费合计和时间，却允许“买入数量为0、买入金额为正”等不可能的日汇总进入DecisionContext。现在校验总成交量不溢出、成交笔数与成交份额边界一致、零数量侧必须同时没有金额/费用、无卖出时已实现盈亏必须为0，并拒绝未规范化证券代码。新增摘要直接篡改拒绝及嵌入DecisionContext后解码校验失败的XCTest，并补充Advisor源码契约；Swift/Python执行仍待环境验证。

## 2026-11-01 无行情时点的指数数值被计作可用行情

- 腾讯/日经响应可以包含价格和涨跌幅但没有可验证的交易时点；UI虽显示“行情时点未核验”，`FMarketIndexQuote.isAvailable`仍只检查两个数值，使整体可用数量失真并隐藏部分原因。现在分开表示“有数值”与“行情可用”：无时间戳或有不可用原因时仍能展示原始读数和原因，但计入Unavailable/Partial，不会被报为完整可用行情。新增首页源码契约；App编译和现场数据验证待Apple环境。

## 2026-11-01 Tencent指数报价时间可领先本机接收时间

- 腾讯行情原先允许`observedAt`比响应接收时间晚60秒；报价误时或未来时点因此仍可能被显示为可信行情。现改为严格要求`observedAt <= fetchedAt`，模型可用性也复核时间有限性、顺序和来源。新增源契约反例；Apple编译与真实响应验证未执行。

## 2026-11-01 Market Regime可能把分钟样本误算作交易日

- 引擎只检查样本数≥60和时间新鲜度，没有验证相邻样本是否真是日K。分钟序列误接入时也会形成“60个交易日”，从而生成看似可靠的MA/回撤/波动状态。
- 现在要求至少两个独立样本且相邻K线间隔不小于12小时；不满足时核心因子不可用，Regime为`dataUnreliable`、策略集为空、普通T买被禁止。该结构校验只作硬门槛，不额外增加Regime信心分。当前所有App调用都来自NAS日K映射，正常日线仍满足该间隔。
- 新增小时级分钟样本拒绝XCTest和源码契约。Node源码核对及`git diff --check`通过；Swift执行/CI未运行，需Apple CI验证。

## 2026-11-01 图表绘图区高度未按用户反馈缩短

- 证券详情的实时、历史和日K图表调用传入460pt，行情卡片传入420pt；图表内部额外80pt的分支要求高度至少600pt，现有页面均不会命中，旧记录中“高度增加80pt”不能代表当前调用已调整。
- 当时详情图表现改为400pt、行情卡片360pt，并移除无实际调用价值的隐式高度扩张；该历史尺寸已由2026-11-01后续截图反馈修订为统一320pt，见本审计末尾记录。
- 新增源码契约核对三个详情入口、行情卡片入口和无隐式扩张。Node检查及`git diff --check`通过；实际视觉比例需Simulator截图/真机验收，本机无Apple工具链。

## 2026-11-01 已实现盈亏合计溢出与无成交语义混淆

- `FDailyTradeSummary.aggregateRealizedPnL`在无成交或多证券合计超出Decimal范围时都会返回nil；`FDecisionContext`此前注释把nil只解释为“没有成交”，Advisor提示也未区分两种情况。多标的极端账本下模型可能把不可表示的合计误说成0或没有成交。
- 修正上下文字段语义，并明确要求：有日摘要但组合合计为null时，只能说明合计Unavailable/不可表示，不能当作0或无成交。增加Advisor源码契约。
- Node源码核对和`git diff --check`通过；Python回归、Swift测试与App构建尚未运行，需CI验证。

## 2026-11-01 做T卖出未完全配对时仍报告部分正收益

- `FTradeContributionCalculator`遇到卖出1000份、之后只买回500份时会返回已配对部分的正贡献；汇总未携带配对数量，Advisor可能把该数误读为当日完整T贡献。这违反“任何T卖出未配对时T贡献Unavailable”的Ledger产品红线。
- 现在任一T卖出批次仍有剩余数量时，整项T贡献返回nil；普通交易明确标记为ordinary且没有T成交时仍可返回0。完整配对仍按原FIFO数量和双边手续费计算。
- 回归更新为部分配对的计算器和每日摘要都返回nil，并增加完整1000份配对的精确值断言；B-018追踪同步。Node源码核对和`git diff --check`通过；Swift XCTest/App构建未在本机执行，需Apple CI验证。

## 2026-11-01 NAS分钟Complete状态未校验覆盖契约一致性

- iPhone原先只在`qualityPassed == false`时降低Complete；若该字段缺失/类型错误，或`coverage.status`、完整度/成交量门、expected/observed、缺失时间戳与实际bars数量矛盾，NAS顶层仍返回`complete`时客户端可能照样显示Complete。
- 现在只有覆盖状态同为complete、quality/completeness/volume全部明确为true、expected为正、observed与expected及实际bar数一致、缺失时间戳为空时才保留Complete；其余Complete响应降为Partial并说明元数据不完整或不一致。
- 新增源码契约覆盖上述全部条件，并与采集时间格式边界检查并存；NAS API回归同时断言其正常complete响应包含一致的状态、计数、空缺失列表及三项true质量门。Node源码核对及`git diff --check`通过；Python/Swift/App运行验证仍需CI。

## 2026-11-01 NAS分钟采集时间格式错误仍保留样本

- iPhone历史分钟读取原先只在采集时间成功解析时检查其不早于行情时间且不晚于当前时点；若字段存在但格式错误，条件绑定失败会跳过时间范围检查，分钟点仍进入图表，尽管整日被降为Partial。
- 现对存在的`fetchedAt`要求必须成功解析且满足`bar timestamp ≤ fetchedAt ≤ 当前时点`，否则剔除该条；完全缺字段的旧格式仍可作为未评估样本显示，但整日Complete会降为Partial。
- 更新`Tools/test_daily_history_wiring.py`的源码契约以锁定解析失败剔除及时间上下界。Node源码核对、145条追踪结构和`git diff --check`通过；Python/XCTest/App构建未在本机执行，需Python CI与Apple CI继续验证。

## 2026-11-01 NAS `/readyz` 指数状态查询未受限

- 分钟归档健康检查已改成只读短连接，但 `/readyz` 仍调用指数历史 `status()`；该实现通过普通10秒连接逐指数读取，且使用历史详情读取路径。在SQLite写锁下仍可能让Ready请求显著延迟。
- 指数Ready摘要现在使用单个只读连接，连接等待上限1秒；仅查八个已验证指数的元数据，并取各自最新最多500个交易日期，不加载OHLCV详情，也不扫描可能包含大量证券条目的元数据表。独立历史查询与研究读取仍保留原路径。
- 新增Python回归验证Ready状态不调用完整历史读取器、只开一次只读短连接、元数据SQL限制指数代码并保留样本状态。Node内置SQLite用含1000个证券元数据记录的合成库核对相同SQL仅返回6个支持指数，且60日K记录正常计数；这不是Python方法的端到端测试。当前主机的`python.exe`是不可启动的WindowsApps占位入口，Python回归尚未执行，需Python CI运行。Swift/Apple验收与部署验收不受此修改影响，仍按矩阵待验证。

## 2026-11-01 Candidate Shadow Guard 默认态保守化

- App调用经核对已显式传入`assessment.guardResult.allowedForReview`，不存在当前主流程漏传；但快照公共初始化器原先默认`guardAllowed=true`，未来漏传时会把未验证候选错误记为Guard放行。
- 初始化器默认改为`false`，真实App放行状态继续显式传入。新增 XCTest 验证默认拒绝和显式放行，并增加App接线源码契约。
- Node源码契约核对通过：145条需求ID连续唯一、FCore XCTest定义数220、App显式传入真实Guard结果、初始化器默认拒绝及回归用例均匹配。`git diff --check`通过；XCTest/App编译仍需Apple CI。

## 2026-11-01 Market Regime 市场广度因子缺少来源与时点

- `FMarketRegimeInput`原先接受裸`breadthRatio`，没有来源、观测时点和采集时点；即使数据过期/伪造，也会直接影响riskOff及Extreme分类。
- 输入现在使用涨家数/跌家数计数，并随附来源、市场观测时间和采集时间；仅接受样本总数无溢出、计数非负、来源非空且两类时点均在asOf/now之前、两小时内的数据。无效广度因子显示Unavailable且不参与风险信号。当前没有生产供应商接线，保持不可用，未伪造数据。
- 新增新鲜广度生效、过期/未来/空来源/计数溢出拒绝两项XCTest和源码契约；Node静态检查通过后再记，Swift测试需Apple CI验证。更新B-012追踪说明。
- 同一观测现在还携带市场标识，必须与Regime输入的市场上下文精确匹配，避免将恒生广度用于A股状态。已有无效广度回归增加了错市场场景，维持两项用例数。
- 宽基指数风险观测同样新增`marketContext`并要求与当前Regime输入相同；已有重复指数用例同时投喂一个标记为US上下文的纳指下跌数据，确认它不进入CN同步风险计数。
- 再增加按市场上下文的指数代码白名单：CN只接收上证/深成/沪深300/创业板；US仅NDX、HK仅HSI、JP仅日经、KR仅KOSPI；`security:<code>`在没有证券-指数映射时不接收任何指数风险。回归也覆盖“把usNDX错误标成CN来源”的情况。

## 2026-11-01 跨市场指数JSON数值严格校验

- Naver指数JSON字段以`Any`读取后，统一数值解析器会把JSON布尔值桥接成`NSNumber`，可能将错误响应`true`误读成数值1；非有限Decimal也可能进入涨跌幅显示。
- 指数解析现显式拒绝CoreFoundation Boolean，并要求Decimal及其Double显示值都有限。新增 `test_cross_market_index_numbers_reject_boolean_and_nonfinite_payloads` 源码契约。
- Node静态检查及Swift/App编译待验证；本机无Apple工具链。

## 2026-11-01 Shadow失效价必须落在计划区间外侧

- Shadow快照原先只要求失效价为正且有限，没有要求它处于触发区的风险侧。买入失效价高于买入区时，价格刚进入买区即可先被标为失效；卖出方向也存在对应问题。
- 新增共用规则：买入/日内买入失效价必须低于买入区下界（或限价），卖出失效价必须高于卖出区上界（或限价）；没有方向的WAIT/HOLD/GRID等不接受失效价。快照构造和解码归档校验共同使用，并新增初始化及篡改归档回归。
- Node静态检查与差异检查待执行；Swift XCTest/构建仍需Apple CI。

## 2026-11-01 Candidate Shadow 解码档案字段校验不完整

- `Codable`解码不会执行模型的throwing初始化器。`FCandidateShadowArchive.validate()`此前未复核冻结价格区间、引用价格/时间、数量、失效价、追价距离，以及市场/成交/复核事件时间；上下限颠倒的损坏档案可通过验证。
- 快照构造现在也检查解码来的价格区间，归档加载校验补齐上述字段和有限时间戳检查。新增回归先编码合法档案，再篡改冻结价格区间顺序，解码成功但必须被`validate()`拒绝。
- Node静态契约和CRLF感知差异检查通过；XCTest与Swift构建尚未在本机执行，需Apple CI验证。

## 2026-11-01 Candidate Shadow 执行复核与成交关联互斥

- Candidate Shadow 原先禁止“已有成交关联后再写未执行复核”，却允许先写未执行复核、再追加成交关联。后一顺序会制造互相矛盾的记录，`validate()`会拒绝归档，且评估仍优先显示未执行。
- 现在存在执行复核时拒绝后续成交关联，拒绝后原记录仍可通过归档校验。新增 `testExecutionReviewPreventsConflictingFillLinkAndKeepsArchiveValid`。
- XCTest/Swift构建需Apple CI执行，本机只完成源码静态检查。

## 2026-11-01 Candidate Shadow 触发后观察窗口超出60分钟

- 触发后窗口原先取 `max(validUntil, triggerAt + 60分钟)`。计划有效期超过一小时后，影子记录继续采集至计划到期，MFE/MAE会混入触发后数小时表现，和B-091的5/15/30/60分钟评估口径不符。
- 现在未触发计划仍观察至 `validUntil`；一旦出现有效触发，结束时点固定为首次触发后60分钟。候选有效期和触发后统计窗口分别计算。新增长有效期候选在触发后一小时拒绝后续行情的 XCTest。
- XCTest/Swift构建须由Apple CI执行；本机只可进行源码静态检查。

## 2026-11-01 Advisor 重新验证 Regime 底层日线新鲜度

- Advisor 原先只检查 Regime 评估最近何时被下载/计算；若取数时底层日线刚好接近5天上限，之后缓存评估仍可能被当作新鲜量化状态传给模型，即使底层市场数据已过期。
- 新增统一 Regime 数据新鲜度检查，证券与指数在 Advisor 上下文中都要求 `dataAsOf` 非未来且距分析时点不超过5天；Regime评估/下载时间仍单独按quantState缓存期限检查。新增源码回归契约要求两个路径都调用此检查。
- 本机Python/Swift工具链不可用，回归与编译需CI验证。

## 2026-11-01 Market Regime 旧记忆跨越过长数据间隔

- `FMarketRegimeMemory` 原先只检查字段/计数是否合法，没有检查 `lastEvaluationAt` 与最新有效日K的相对时间。停用数周后重新打开，旧的 Bull/Risk 状态仍会参与三日切换确认；若存储记忆时间晚于回放中的最新bar，也可能泄漏未来状态。
- 现在最新bar与记忆时间相差超过 `maximumDataAge`，或记忆晚于最新bar时，评估会丢弃旧记忆并从当前观测重新分类。新增 stale Bull→falling bars 以及 future memory→historical replay 两个 XCTest。
- 本机无法运行Swift/Xcode；该回归需Apple CI执行。静态源码差异检查待完成。

## 2026-11-01 NAS历史分钟质量失败不能冒充完整

- iPhone客户端原先只在分钟存在无效/重复项、来源元数据缺失或没有coverage时，将NAS声明的 `complete` 降为 `partial`。若NAS同时返回 `status=complete` 和 `coverage.qualityPassed=false`，图表仍会映射为 `.complete`，尽管摘要文字显示质量未达标。
- 现在客户端将明确质量失败也作为降级条件，并在覆盖摘要说明“质量门未通过，降为Partial”。新增 `test_nas_minute_quality_failure_cannot_be_marked_complete` 源码契约。
- 本机Swift/Python工具链不可用；只可进行源码级检查，XCTest/CI和真机NAS响应仍待验证。

## 2026-11-01 NAS历史分钟未来时间戳校验

- 同一客户端只拒绝 `fetchedAt < minute timestamp`，没有拒绝将来的分钟或将来的采集时间。NAS质量计算会检查未来时间，但客户端仍可能接受伪造/错误的 `complete` 响应并将未来价格画入历史图表。
- 历史分钟读取现在以单次捕获的当前时点校验分钟时间与可解析采集时间，并拒绝负分钟成交量；未来/负量记录被剔除，Complete因剔除而自动降级。新增 `test_nas_minute_reader_rejects_future_bar_and_fetch_timestamps` 源码契约。
- Python/Swift工具链在当前机器不可用；静态源码检查通过后仍需CI测试及真实NAS响应验收。

## 2026-11-01 当前工作树计数校正

- 需求映射表复核为 B-001…B-145 共145条，连续且无重复；映射存在不等于对应功能通过。
- 当前源树静态计数为 FCore XCTest 220个、App UI XCTest 10个；本地未执行。新增的两个Regime记忆用例、两个广度质量用例和五个Shadow边界用例只计作定义，未计作通过。此前153/165与UI 3/4的数字是不同历史快照，不能当作当前测试数或通过数。
- 当前Windows环境没有可用Python或Apple构建工具链。本轮当前证据仅为Node静态契约检查、源文件复核和CRLF感知差异空白检查；Python套件、Swift/Xcode构建、CI与视觉验收均为待验证。
- 后续审计应继续逐项核对145需求的源码、回归覆盖和验收证据；不要因编号完整或测试定义存在而标记通过。

## 2026-11-01 初始持仓录入异步查名覆盖手工输入

- 初始持仓页已按要求分开录入券商现金和证券份额/成本，代码会触发证券名称查询；但查询未返回时用户可先手工改名，迟到回包会覆盖手工输入。
- 增加每个持仓草稿的手工改名标记；用户更改代码时重置标记，自动查询回包再次核对代码及标记后才填名。每份成本、计算总成本和券商现金同时增加有限数校验，避免无穷Decimal进入保存流程。
- `Tools/test_home_layout_contract.py` 新增自动查名优先级、每份成本、分离现金和数值边界源码契约；真机UI验收仍待Apple工具链，本机Python/Swift测试未执行。更新了主验收矩阵中错误标注为“入口缺失”的行。

## 2026-11-01 Realtime Trigger 缺少 Regime 输入时的候选绕行

- `FRealtimeQuantTrigger.evaluate` 原先把 `marketContext` 设为可选；缺上下文时，fresh quote只要进入公开构造的计划价格区间就会返回 BUY/T_BUY 候选。这绕过了“当前市场状态、风险是否允许”的核心量化门槛。
- 现在非空计划必须带有证券代码匹配且最近日线不超过5天的 Regime assessment；上下文缺失或过期时返回 `paused` / `wait`，置信度为0。原候选成功用例改为显式构造同证券、可靠的Range assessment；新增缺失/过期Regime拒绝回归。
- XCTest 定义和 `Tools/test_market_regime_contract.py` 源码契约未在本机执行（无 Swift/Xcode/Python），还需CI/Apple工具链验证。App当前尚未接入完整Local Quant，保持不生成可执行资产变化候选。

## 2026-11-01 NAS `/readyz` 响应耗时复核

- `/readyz` 原先每次请求调用全库 `PRAGMA integrity_check`，随后逐行验证所有归档分钟和覆盖记录；还为每个证券执行滚动覆盖重算，诊断SQL会聚合该证券整个分钟历史。这是随历史增长而变慢的健康检查路径，可能导致 iPhone 十秒请求超时。
- 新增只读、1秒连接超时的 `MinuteArchive.readiness_check()`，仅确认数据库可打开、版本元数据和必要表可读。滚动历史覆盖移至独立 `/api/v1/backfill-status`，证券日K全量库存移至 `/api/v1/daily-history-status`，网页可独立加载；iPhone读 `/readyz` 不再触发全库扫描、每证券重算或完整库存枚举。深度完整性扫描仍在启动验证和显式 `integrity_check()` 执行。
- 归档不可用时，`/readyz` 现在返回HTTP 503和`not_ready`，不会把 `ArchiveError` 误分类成400输入错误。新增回归确保 `/readyz` 不调用完整性扫描、覆盖重算或证券日K库存枚举，并确保独立状态端点仍可用。NAS/Python测试当前无法在此环境启动：WindowsApps Python入口不可用，WSL访问被系统拒绝。新增用例未执行；需在 Python CI运行后再确认性能改动。

## 2026-11-01 Local Quant 资格授权边界复核

- 找到可复现的 Guard 绕行：`FQuantStrategyQualificationEvidence.observation` 是公开工厂；任意调用方可自行生成新鲜、带 `qualification=qualified` 的公开观察，再通过公开 `FDecisionContext` 初始化器提供它。Risk Guard 原先只解析这段可伪造文本，没有证明它来自已验证的 Local Quant 包。这与“Local Quant 未实现时所有资产变化候选保持阻止”不一致。
- 资格观察工厂和验证逻辑现为 FAdvisor 内部接口；Risk Guard 还要求一个只由 FAdvisor 内部代码传递的运行时授权，授权绑定证券、策略、版本、观察ID和生成时点。授权不进入 JSON 编码，解码的历史上下文会丢失授权并回到拒绝状态。没有包生成/验证器，因此公开 App 流程仍然无法签发授权，候选继续 fail-closed。
- 新增 XCTest 覆盖公开伪造资格观察被拒绝、经内部授权的资格通过、过期授权拒绝，以及 JSON round-trip 不保留授权。XCTest/Swift 编译在本机不可运行；需 Apple CI 验证。

## 2026-11-01 Advisor 证券代码 ASCII 边界复核

- 行情搜索UI按UTF-8字节校验六位 ASCII，但 Advisor 接口原先使用 Swift `Character.isNumber`；非ASCII数字字符可通过 Advisor 的六位校验，却无法被行情解析器转换成规范的沪深报价代码，最终形成不可识别的证券上下文。
- Advisor 目标标的校验与实时行情刷新筛选现统一调用六位 ASCII 字节校验。新增 `Tools/test_advisor_safety_contract.py` 源码契约，要求两条路径共用校验器。
- 修改关联 B-010 数据质量追踪。Windows本机未能运行 Python/Swift测试；新增回归与App编译须由可用工具链验证。

## 2026-11-01 Advisor 过期缓存行情被误作可用上下文

- 刷新失败会保留图表中的最后行情快照；Advisor 原先只检查缓存是否存在，因此即使行情在刷新/新闻请求期间超过120秒，仍会把旧价格作为数值报价观察交给模型。Risk Guard 会拒绝引用过期报价的资产变化候选，但 Advisor 输入和结果状态仍可能让旧行情看起来像当前报价。
- Advisor 构造 DecisionContext 时现按最终 `contextCaptureTime` 再验报价时间；超过120秒或时点未验证时，写入带明确旧时间的不可用观察，不把价格作为数值行情送入模型。图表缓存保留用于查看历史，不改变价格事实。
- 新增 `test_advisor_never_passes_a_stale_cached_quote_as_current_evidence` 源码契约。当前环境无法运行Python/Swift回归，App编译与实际刷新故障场景仍待CI验证。

## 2026-11-01 跨市场指数未知时段误标已收盘

- 跨市场卡片原来把任何非 `OPEN` 的供应商状态（包括 nil/空值/未知字符串）映射为“已收盘”；Tencent/Sina 当前适配器没有提供时段状态，因此会被错误标成闭市。未验证时点的卡片也不显示交易时段。
- 现在只有显式 `OPEN` 显示“交易中”，显式 `CLOSE`/`CLOSED` 显示“已收盘”；缺失或其他状态统一显示“交易时段未验证”，且该标签同时出现在行情时点已验证、只知获取时间和暂无时点三种分支。
- 新增 `test_index_quote_time_never_calls_an_unknown_session_closed` 源码契约，并更新 B-009/F-26。Python契约、Swift编译和Simulator截图未运行，设备显示仍待验收。

## 2026-11-01 CI 验收链复核

- NAS/Python workflow 安装 PyYAML，发现 `Tools/test_*.py` 的全部 unittest，执行 Python compileall 与架构边界检查；`nas/**`、`Tools/**`、`Sources/**`、`Tests/**`、`GuanpanFApp/**` 的相关改动会触发。iOS workflow 在 macOS 15 运行 Swift tests、XcodeGen、iOS Device/Simulator build、导航 UI tests 和 xcresult 截图导出。源码检查未发现测试发现规则或相关变更路径遗漏。
- 为防止后续误删 Apple 验收步骤，`Tools/test_ci_workflow_contract.py` 新增 iOS workflow 静态契约检查。测试未执行；本机无 Python/Swift，当前工作树也未推送，因此不能声称这些 workflow 已对本轮改动运行。

## 2026-11-01 跨市场指数历史时区契约复核

- NAS 日K客户端原先接受响应中任何系统认识的时区，没有核对该时区是否符合 `indexCode`；一个格式有效但市场错误的时区会改变交易日边界和Regime时间对齐。另一个问题是日经与KOSPI虽已明确标为暂无已验证历史源，客户端刷新仍会向NAS发出不支持的历史请求。
- iPhone现在只请求七个已有历史适配器的Tencent指数，其他指数明确返回“历史日K来源未验证”；支持的指数必须和固定时区对应，响应时区不匹配即失败关闭。新增跨市场日K source-contract 检查，并更新 B-012。
- Python/Swift 自动测试本轮都无法执行（Windows Python入口和Apple工具链均不可用）；已检查修改结构，需在可运行的Python和Apple CI中执行新回归及客户端编译。

## 2026-11-01 A500 指数与持仓映射审计

- B-118要求持仓证券具备有来源的指数背景。实际检查发现 159352 南方中证A500ETF没有对应指数行情/日K条目，之前仅能看到通用A股指数；这会丢失产品声明的CSI A500背景。
- 新增 `sh000510` 中证A500实时指数与NAS日K历史代码，使用Asia/Shanghai时区；新增159352→sh000510只读Advisor benchmark映射。映射来源指向南方基金产品详情，指数代码依据中证官方方法文件；指数历史来源沿用已配置Tencent接口。增加NAS解析、固定时区、iPhone导航和映射回归定义。
- Tencent实时端点本轮返回了 `sh000510` / 中证A500有效行情快照；网页工具无法验证历史K线接口在生产环境的响应，NAS实网归档、Swift/XCTest、Python回归和设备显示仍待CI/部署验收。此映射只提供Advisor市场背景，尚未进入Local Quant策略参数或资格化。无提交/推送。

## 2026-11-01 已映射ETF的市场Regime门控复核

- 继续顺着B-118/B-129检查发现，159352与159941的来源映射此前只写入Advisor `mapped-index` 观察；Local Quant仍只看ETF自身Regime，Risk Guard也不会在对应市场Regime严重或缺失时阻断普通买入。
- Local Quant现按发行方映射核验精确指数键、历史Regime时点和获取时点；已映射标的缺少/过期/错指数上下文时策略准备为Unavailable，所选策略同时必须被证券Regime和映射指数Regime允许，严重/极端市场风险时禁用策略。FRiskGuard对已映射证券的买入候选要求新鲜且可验证的对应指数证据并要求引用；R3/R4、Risk-Off、Extreme、Uncertain或Data-Unreliable时拒绝普通买入。卖出减仓不依赖该映射，未映射证券不借用其他指数。
- 新增LocalQuant测试覆盖A500和Nasdaq映射、缺失/过期/错指数、熊市策略限制及Extreme禁用；Risk Guard测试覆盖映射缺失/过期、证据引用与严重风险。同步更新B-011/B-047/B-118/B-129/B-140/B-145和架构说明。Python/Swift测试及编译本机仍不可用；改动尚待CI验收。无提交/推送。

## 2026-11-01 Regime 到实时 Trigger 的证券映射复核

- 找到一处可复现的安全边界缺口：`FRealtimeQuantTrigger` 原先只在 Regime 上下文“有证券代码且不同于候选证券”时暂停；上下文证券代码为空时会继续给出价格区间候选。市场级状态不能因此被默认为适用于任意 ETF。
- Trigger 现在要求已提供的 Regime 上下文必须明确匹配候选证券，否则状态为 `paused`、信号为 `wait`。新增回归用例用完整可靠但没有证券映射的 Regime 输入验证该拒绝路径，并保留“数据不足”的既有独立测试。更新 B-011 追踪证据。
- 本机缺少 Swift/Xcode，新增 XCTest 尚未编译或执行；需在 Apple CI/工具链确认。Python 入口仍不可启动，因此本轮没有新的 Python 测试结果。

## 2026-11-01 账本并发与手续费回放复核

- 复核 `FAccountBookStore` 写入路径：进程内互斥与跨进程文件锁覆盖摘要比对及原子替换；写入要求完整前置摘要匹配，写后回读验证，失败时恢复上一个已验证文件。`FConfirmedLedgerWriter` 的读取和写入分离由乐观摘要校验兜底；已有跨实例并发回归断言两个竞争的入金仅一个成功，账本保留一条流水。
- 复核手续费更正：只读快照先投影更正后的成交费用，再派生Episode已实现盈亏、成本及日汇总；已有更正、撤销、部分卖出成本和归档恢复回归覆盖。本轮未发现可复现缺陷，未改动该逻辑。
- 本机当前 `python.exe` 解析到受限的 WindowsApps 占位入口，启动失败；本轮未能重跑 Python 套件。此前工作记录的 155/155 结果仍是最近一次成功运行，不应算作本轮重测。当前本机也没有 Swift/Xcode/XcodeGen，iOS 编译、XCTest、模拟器视觉验收仍待可用 Apple 工具链。

## 当前审计现场（2026-10-26；历史记录见下方）

> 2026-10-27复查：Actions run `40343237878` 对已提交HEAD执行FCore 121/121、XcodeGen、iOS Device/Simulator Build成功；导航UI测试失败，具体断言日志未取得。当前dirty Swift路由改动无编译/测试证据；本机无Xcode。详见实时交接。

- F 的当前状态由工作树定义：本地 `main` / HEAD `4d258f199c7575f84251154b8929c30fba271508`，且当前存在未提交NAS/Python、Advisor Swift及文档修改。HEAD只用于追溯。
- 最新Apple CI run `40343237878`：FCore 121/121，XcodeGen、Device Build、Simulator Build通过；App UI导航测试失败，首个断言日志暂不可读。该run不包含当前dirty Swift路由修改；本机没有Swift/Xcode/XcodeGen。
- B-145逐项表已增加A/B状态、已知问题、F源码/测试锚点、F逐项状态和人工验收字段；锚点是待核候选映射，并非逐项已验证。A源码当前不可读；B工作副本可读但145项尚未逐条和F源码核对，不能继承其状态。
- 本轮静态核查：清仓移除0份额当前投影但保留fills；历史Episode和累计已实现盈亏从期初快照/成交流水投影；现金重放与余额校验存在。Advisor的组合问题误用详情默认证券码问题已作一处低风险修正，等待编译/测试。
- 图表静态检查：当前/历史分钟与日K共用 `FUnifiedSecurityChart`；可见纵轴联合主序列、均线、有效overlay及可用IOPV。真实NAS分钟、AI/DeepSeek及交互/横屏仍无当前实网或Simulator验收证据。
- NAS runtime局部测试2/2曾实际通过；本轮没有执行完整Python/NAS套件。Apple验证证据见上文；dirty Swift改动仍未验证。

## CI续记（2026-10-26 19:43 Asia/Shanghai；覆盖较早现场）

- run `40315965909` / `016a1a3` 全成功：FCore 121/121、Device/Simulator Build、UI 3/3、截图导出与未签名IPA。
- Simulator截图证明详情页可滚到日K，真实蜡烛/MA/成交量可见；历史分钟附件却与日K附件同帧，仍未证明历史NAS区已到达。另发现资产摘要值与完整日K日期横向裁切。
- 当前本地未提交：历史截图前强制滚动、竖排资产摘要、紧凑日K日期轴。未编译或测试；等待CI。

## CI续记（2026-10-26 19:32 Asia/Shanghai；覆盖下方较旧状态）

- 已推送 `c96a17e` 的 Actions run `40314328798`：FCore 121/121通过，XcodeGen、Device/Simulator Build成功；UI 3执行、2通过、1失败。唯一失败是详情滚动后日K标题不可见；截图导出成功，IPA跳过。
- 初步根因是统一图表Canvas的独占DragGesture截走父ScrollView手势。当前工作树把它改为 simultaneousGesture；仅源码静态修改，尚未编译或执行。真实视觉通过仍未取得。

## CI续记（2026-10-26 19:20 Asia/Shanghai；覆盖下方旧现场记录）

- `1c10912` 已推送；其 Actions run `40312257829` 的FCore 121/121通过，XcodeGen、iOS Device Build、Simulator Build成功。UI 3项执行，2项通过、1项失败；单一导航用例的日K/历史分钟两个可见性断言失败，IPA因此跳过，截图导出成功。
- 工件9张页面截图显示详情页刷新区右侧仍裁切，日K/历史附件与顶部截图重复，页面未滚动到目标区域。已清仓标题可见性测试通过，当前与已清仓资产截图并不相同。
- 后续本地修复已把价格/刷新改为纵向布局，并用整屏手势滚动；当前这些修改及实时文档尚未提交，未编译或执行。等待下一轮 Apple CI。

## 最新现场补充（2026-10-26 18:20 Asia/Shanghai）

- 当前本地HEAD `1c10912e8d1c2a0b6fdc3720b73f6fada28c5e20`，Swift源码干净，状态文档有未提交更新，相对origin/main ahead 1。提交含证券详情窄屏价格/刷新行收敛及UI截图滚动断言；未推送、未编译、未执行。
- 远端run `40305133985`（`04b0deb`）成功：XcodeGen、Device/Simulator Build、旧版App UI 3/3及未签名IPA成功，导出8张Simulator截图。人工查看这些旧版截图并未通过视觉验收：证券详情价格与刷新按钮横向截断；证券详情日K截图与顶部截图相同；当前持仓截图与已清仓截图相同，说明测试没有确认目标内容可见。
- FCore精确 121/121 是run `40303339340`的既有通过结果；本地当前提交未执行（defined 121 / executed 0 / passed 0 / failed 0）。本地3项UI测试同样尚未运行。当前不能把“前一提交CI成功”转述为当前提交通过。
- GitHub连接经只读网页/API与push重试仍失败（HTTPS 443无法连接/API限流），未强推、未改变远端。恢复连接后先推送并验证当前本地提交，再基于新附件复查截图。

> 实时更新（2026-10-26 18:07）：Actions run `40303339340` 已实际通过FCore XCTest 121/121、旧版App UI XCTest 3/3、XcodeGen、Device/Simulator Build和未签名IPA。价格范围两项新增回归均通过。其后当前工作树修改了行情证券代码入口、UI截图附件与workflow导出；这3个文件尚未编译/执行。之前的CI已启动Simulator跑UI用例，但没有成功页截图/人工视觉验收；本轮下一CI会导出截图。清仓详情真实Ledger数据和服务端E2E仍待验证；下方旧记录只用于追溯。

审计起始checkpoint：提交 `622c9079307aef6f1af61d9b18e83528702c081f`；本报告后续追加至队列修补提交 `4175bdad598d050e548ce4e1a60b16f17fa4d5ff`。（审计前 `main` / `F-CHECKPOINT`）。本报告区分源码、静态检查、Python实跑、Swift测试定义和目标环境验证；任何一层都不替代另一层。

## 总体状态

- F Master Acceptance Matrix：34项功能需求全部仍为 `defined`，EXT-1…EXT-5 为 `external pending`。当前没有任何整项标记为F验收通过。
- B Master Acceptance Matrix：B-001…B-145编号连续映射并保留原需求输入、F处置和供体裁决；这些是需求追踪，不代表145项功能已实现或已通过F验收。旧B状态与证据不继承。
- Python NAS范围本轮实跑68/68通过：分钟归档37、分钟服务/Research Evidence接口25、红利研究6；只读账本迁移dry-run另6/6通过（本轮合计74/74）；`py_compile` 和架构边界静态脚本通过。
- Swift XCTest未执行：FCore 31、Ledger Boundary 26、Market/Chart/Advisor 42、Home Card Contract 6、Sync Policy 2，全部 `executed=0 / passed=0 / failed=0`。当前环境未发现 `swift` 或 `xcodebuild`。
- 仓库含Swift Package库/测试target与GuanpanFApp XcodeGen规格和SwiftUI首页骨架；尚未生成/构建Xcode项目，也未在Simulator或真机运行，不能算原生App已交付。

## 按验收范围的未完成项

| 范围 | 当前证据 | 未完成/未验证 |
|---|---|---|
| F-01…F-04 真实账本与规则 | 账本schema、现金/持仓不变式和规则代码及XCTest已定义 | Swift编译/测试、实际账本全链验证未做 |
| F-05…F-11 成交边界、原子持久化、备份/恢复、A/B→F迁移 | 独立Ledger写模块、用户确认入口、只读dry-run/迁移预览和存储边界已编码 | Swift回归未跑；崩溃/磁盘故障/重启/真实旧数据迁移仍未验证 |
| F-12…F-15 Memory/Profile/Context/Guards | 版本化存储、投影、时点/质量门控和拒绝规则已编码 | XCTest未跑；模型调用层和生产运行链尚未验证 |
| F-16 最终AI指导 | Keychain密钥存取、DeepSeek Candidate provider、只读Ledger/行情/新闻/Profile/Memory/Regime上下文、scope处理及Risk/AI Guard均有实现；NAS摘要与第三方新闻均为非阻塞可选项，新闻只用新鲜内存缓存 | 真实API成功/超时/畸形回答与用户设备端到端未验收；新闻源是不稳定网页接口且无持久缓存；本地Quant资格链未接入，资产变化候选保持fail-closed；当前dirty App未Apple编译 |
| F-17 做T/网格/回本 | NAS研究函数和Advisor只读工具契约已编码 | Provider调用编排、与真实持仓/手续费/流动性联结及历史真实档案回放未完成 |
| F-18 行情与图表 | Quote时间语义、质量门控、图表hit-test纯逻辑已编码 | 真实行情源、分钟/日K/IOPV/盘口接入；原生手势、缩放横屏和屏幕验收未完成 |
| F-19、F-25、F-33 NAS研究 | 历史分钟归档/补采/完整度/查询/研究、红利证据、紧凑Research Evidence契约有本地实现和Python测试 | 真实数据源可用范围、交易日历/时区生产验证、NAS 8788部署、长期运行/容量/灾备、跨市场真实样本外研究、新闻链路及手机端到端均未验证；低质量/无样本时不能给AI当合格证据 |
| F-20 同步/离线/通知 | 三通道策略定义和纯逻辑已编码 | 传输协议、离线队列冲突/恢复UI、通知投递与跨设备恢复未完成 |
| F-21…F-22、F-26…F-32 原生UI/交互 | SwiftUI首页壳、五个布局分支、AI输入/快捷问题、市场/跨市场/顾问/真实组合独立路由、持仓详情和诚实不可用状态已编码；账本现金状态映射有纯逻辑与XCTest定义 | Xcode项目尚未生成/构建/运行；在线AI和真实行情未接入；五主题视觉差异质量、首页时间/来源实际呈现、历史分时入口、原生K线手势、横屏/设备适配和可发现性均未验收 |
| F-23…F-24 架构与验证 | Python架构边界检查通过；多个XCTest套件已定义 | Swift构建与所有XCTest均未执行；静态脚本不代表编译或运行通过 |
| F-30 红利 | NAS多因子证据整理器本地实现 | 真实基本面来源、持续分红/派息率/现金流质量及iOS高级设置仍待接入验证；4%不得作为硬门槛 |
| F-34 B145需求承接 | 145项编号、处置、来源映射连续 | 逐项F代码/运行证据仍需随着对应F模块分别验收；目前无B项目可因B曾通过而转为F通过 |

## 外部验证待办

1. macOS/Swift/Xcode编译与全部XCTest；iOS Simulator截图、导航/大字体/无障碍验证；iPhone横屏、重启和实际可发现性。
2. NAS 8788真实部署、行情供应商、历史回补范围、交易日历、长期存储、备份恢复及持续采集。
3. GitHub远端：当前仓库未配置Git remote，因此推送/Actions/跨机同步未验证。
4. 真实行情、新闻、在线AI密钥/服务、推送通知及手机—NAS端到端。
5. A/B旧账本样本的只读dry-run报告审阅与真实迁移回滚演练；不得以合成样本替代用户真实数据验证。

## 本轮发现并修正的状态问题

- F-STATUS中的HEAD曾指向`ecbd8c4…`，而Git实际checkpoint为`9ca9681…`。
- F-25矩阵把分钟归档/服务计为51项；本轮实际为36+18=54项。红利研究另6项，NAS Python实跑总数为61，不把研究Evidence服务测试重复计算。
- F-CHECKPOINT-MANIFEST与F-LATEST包仍指向最初基线`f6d3e257…`，包校验状态陈旧。本轮重建bundle/ZIP并更新校验摘要。
- 检查发现的未提交覆盖改动删除了矩阵条目、B UI裁决和一项Ledger XCTest；已丢弃这些未提交覆盖，以提交checkpoint内容为准。

## 后续推进记录

- 为A/B→F只读迁移dry-run新增6项Python安全回归，实跑6/6通过：重复运行稳定、CLI不修改源文件、旧事件仅保留原始证据、负现金/重复证券/未知schema拒绝生成候选。此验证不代表Swift迁移写入、原子回滚或真实账本迁移通过。

## AI管线推进

- 已加只读模型Provider契约与`FAdvisorDecisionPipeline`：request/context先匹配，模型只产Candidate，再由Risk/AI Guard裁定是否可供用户审阅；不含Ledger写接口。研究工具响应严格匹配请求标的、市场、日期和时点，并仅返回质量合格证据。相关Swift测试已定义，未执行；无Swift/Xcode不能标成通过。

## 原生UI推进

- 增加 GuanpanFApp/project.yml 和 SwiftUI 首页骨架，含五个不同布局分支、分语义目的页、AI问题输入区、真实账本只读摘要和诚实的行情/AI未接入状态。静态契约检查通过；XcodeGen、Swift、Xcode均不可用，未编译/运行，真实视觉差异、导航可发现性、iPhone/横屏仍待验。交易录入、完整详情图表和在线服务不在该骨架中。

- 静态复核移除了App对FCore LedgerStorage SPI的直接调用，改用公开的只读Ledger snapshot reader；未获得Swift编译证据。

- 修正Research Tool异步响应时序：数据观察截止时间仍绑定旧Context；返回捕获时间允许晚于旧Context，但只有进入新捕获的DecisionContext后才能送回AI。新增Swift回归定义，未执行。

## 研究证据完整性修补

- 发现NAS Research Evidence的evidenceId原先未覆盖合格独立日数、最低质量、交易日覆盖等信任字段；Swift客户端只验证其十六进制格式。现将这些字段与统计内容一起纳入确定性摘要，iOS收到载荷后重算摘要，不匹配即拒绝。
- 新增Python回归验证质量、覆盖、来源和独立样本数任一变更都会改变evidenceId，且整数浮点规范化，并将asOf/generatedAt统一为UTC毫秒，同时纳入时区和限制文本；Market/Chart/Advisor XCTest增加跨端固定摘要和字段篡改拒绝定义。Python实跑通过；Swift未执行，跨端编码兼容仍待Xcode实际验证。

## AI候选行情依据

- Risk Guard此前只检查上下文中存在该标的的新鲜报价，候选可以不引用这条证据。现要求资产变更候选引用对应的可信新鲜报价ID；新增正反 XCTest定义，尚未执行。

## 回本候选边界

- `recoveryPlan` 原先未经过资产变更订单规则校验，可能携带份额/限价字段或指向非持仓证券。现在仅允许绑定当前真实持仓且不得携带结构化订单字段；新增1项 XCTest，未执行。回本策略计算和外部历史证据仍未完成。

## 做T与网格候选证据

- 网格候选此前可借用同一证据包内其他研究类型通过；现在必须引用同证券、满足walk-forward质量门槛的`gridSpacingReplay`。做T所需当日VWAP、盘口和双边费用上下文尚未形成，当前显式fail-closed。新增1项 XCTest定义，未执行。

## 历史分钟查询截止时间

- `availableAsOf`此前未强制时区感知，也未阻止未来截止时间。Service现在拒绝naive datetime和晚于服务时钟的值，避免本地时间异常及回放未来数据。边界回归已执行通过。
- F-25原记录的分钟归档/服务测试数55/55与当前定义不符，已按实际36+22修正为58/58；不改变F整体验收标准。

## 原生设备族

- XcodeGen规格原先仅声明iPhone。现设置target family为iPhone+iPad并由本地YAML解析核对通过；项目生成、编译、布局和设备截图仍待Xcode/Simulator/真机验证。

## Advisor响应时效

- Decision Pipeline此前在模型返回后仍使用请求开始时的`now`判断报价新鲜度。现改为完成时刻重新运行Guards，防止请求等待期间过期报价仍放行。新增XCTest定义，当前无Swift/Xcode未执行。

## 首页真实账本状态语义

- Home 首屏此前仅按`holdings.isEmpty`显示“无持仓”，会把未建立或读取失败误示为空仓。现在模型显式区分loading/not established/available/unavailable，组合卡与AI输入区显示对应状态。源码修正未经过Xcode/Simulator/真机验证。

## AI输入快捷问题

- 首屏Composer此前只有一条快捷问题。现补充组合操作、买入、降成本、做T和建议变化五类可点问题；Xcode编译与设备上是否易发现尚未验证。

## Matrix与UI源码对齐

- F-21/22/27/32此前仍写“尚未实现入口/路由”，与已有SwiftUI首页壳不一致。已按源码更新为“壳/路由/输入/五布局已编码，在线服务、完整图表及设备可发现性未验收”，没有将静态存在标作运行通过。

## 真实持仓证券详情入口

- 真实持仓行此前不可进入标的详情，也无法从该标的范围打开顾问。现在增加持仓→证券详情路由，详情只显示本地真实份额/成本，行情明确标为未接入；顾问标题、输入提示、快捷问题与发送scope带该证券代码。实际AI请求组装、在线服务与设备可发现性仍未实现/验证。

## UI验收矩阵细节校正

- F-26/28/31矩阵先前分别把市场入口、主题选择器、AI输入写成未实现；源码已有这些入口与基础视图，但数据服务、视觉质量、历史分时/K线和设备可发现性仍未验收。已将状态改为“编码存在、运行/设备未验”。

## XCTest定义数核对

- 静态统计`LedgerSchemaTests.swift`有31个XCTest方法，其中第31项为只读已实现盈亏派生。状态/Matrix由30更正到31；没有Swift/Xcode，仍是`executed=0 / passed=0 / failed=0`。

## 2026-10-26 本轮管线审查

- 发现FAdvisorQuestionRequest的自定义解码器允许请求携带独立于已捕获DecisionContext的研究证据。虽然常规初始化由Context派生，但模型调用管线原先没有对解码后的证据集合再做绑定校验。
- 已在模型调用前核对请求内合格Research Evidence与Context派生集合完全相同，并核对版本冲突元数据；任一不符均拒绝请求。新增篡改请求的Boundary XCTest定义。
- 当前实跑：Python 70/70；`py_compile`通过；架构边界脚本通过。XCTest定义数Ledger Boundary=25，executed=0/passed=0/failed=0。

## AI顾问投影解码边界

- Profile/Memory是与DecisionContext分离的只读投影，但也会经过Codable解码。常规构造器的过滤规则不能自动保护解码载荷。
- 增加投影点用校验：Profile检查asOf、未来修订、属性/修订唯一性和值/置信度；Memory检查账户、证券范围、条目上限、排序、未来决策/证据/结果和文本字段。请求解码与决策管线入口均拒绝不合格投影。
- 新增Profile未来修订和Memory未来决策Swift回归定义。当前没有Swift/Xcode，均未执行。

## NAS诊断范围审计

- 发现单标的诊断响应把全局补采队列数作为该证券的排队交易日数展示，造成诊断口径错误。
- 新增按证券和市场筛选的队列计数；诊断接口使用该范围，全局队列端点继续返回全局数量。回归验证两个证券各排3日时各自诊断显示3、全局显示6。
- 本轮分钟服务Python实跑23/23通过；NAS Python合计65/65，包含只读迁移dry-run为71/71。

## NAS补采队列容量审计

- 失败任务重新排队时此前未计入容量预检，可使活动队列突破配置上限。现在将失败任务重新激活与新任务一并计入容量。
- 增加超限回归：失败任务重排+新日期超过容量时拒绝整个批次，已排队/失败记录保持原状。分钟服务Python测试24/24通过；全套NAS 66/66、含迁移dry-run 72/72。

## NAS补采队列状态一致性审计

- 发现队列的complete标记曾阻止归档缺口重新补采，尽管缺口评估已判定需要回补。
- 现在归档覆盖率是唯一完成依据；归档不足时，旧complete任务可以重新排队并重新占用容量。
- 增加状态不一致恢复回归。分钟服务Python测试25/25通过；NAS Python 67/67，含迁移dry-run为73/73。

## 全盘摘要一致性复核

- F Matrix、F-STATUS和全盘审计当前计数已统一为 NAS Python 67/67、迁移dry-run另6/6；合计73/73。FCore XCTest 31项定义、Ledger Boundary 26项定义、Market/Chart/Advisor 42项定义、Home Card 6项定义、Sync Policy 2项定义均未执行。
- 全部 F-01…F-34 仍保持 defined；不是已验收通过。

## 分钟数据库语义完整性审计

- SQLite PRAGMA integrity_check只能确认数据库页/索引结构，没有验证业务行。现在 backup、restore 和 integrity_check 也校验分钟点、成交量来源、UTC时间、数据质量、schema与交易日覆盖字段。
- 损坏分钟价格在SQLite结构层仍可读，但新语义校验会拒绝完整性确认、备份及恢复，且不会发布恢复目标。回归测试已覆盖。
- Archive Python 37/37通过；分钟服务25/25、红利6/6，NAS Python 68/68；加账本只读迁移dry-run 6项共74/74。

## 首页账本状态呈现审计

- 发现HomeModel在账本读取失败或读取中时，cashText一律显示“未建立”，会把未知/不可读状态误报为空账户。
- 新增纯展示映射并接入首页：读取中、未建立、不可读取、可用现金分别显示；可用但余额缺失时显示“不可用”。新增Home Card XCTest定义，Swift/Xcode未执行。

## 审计陈述对齐源码复核

- 对照当前F SwiftUI源码和F-MASTER-ACCEPTANCE-MATRIX，已将原生UI范围改成“壳/布局分支/输入/独立语义路由已编码，服务接入、完整图表与设备验收未完成”，不再把已编码部分概括为未实现。
- Home Card Contract XCTest定义数同步为7；executed=0，Xcode未执行。


## 2026-10-26 NAS HTTP 边界与长期留存复审

- 发现 backfill HTTP handler 先将输入身份用 `str()` 强制转换，JSON number等类型可能被解释成合法证券代码；`json.loads` 默认接受重复字段并保留最后值；GET路由忽略未知参数。
- 已收紧为重复JSON键和非有限数字拒绝、字段类型严格校验、截断请求体拒绝及各GET路由参数白名单。无效请求返回400且不改变补采队列。新增回归覆盖数字证券代码、重复priority键和额外查询参数。全套Python为74/74（在现有HTTP测试内增加断言，测试方法数不变），`py_compile`、架构边界和差异空白检查通过；XCTest定义数/执行数不变，执行0。
- 留存复审确认归档默认永久保留且无删除操作；`RetentionPolicy`仍是声明性模型，压缩、分区、备份轮换和NAS容量运行验证未完成。暂不启用自动清理，避免在真实容量和保留偏好未知时丢失长期研究历史。

- 补采任务入队进一步校验精确日期类型、显式优先级枚举和交易日历唯一交易日；日历重复日期或错误优先级时 fail-closed，队列保持不变。现有分钟服务测试内加入回归，NAS Python仍74/74通过，XCTest未执行。

## 2026-10-26 补采队列恢复完整性复审

- 队列数据库在进程重启后此前没有明确schema版本，也不校验已持久化任务行。对损坏的优先级/状态/日期/计数/时间戳，worker可能延迟失败或错误调度。
- 新增queue schema v1标记与启动校验：先执行SQLite完整性检查，再校验所需列、schema版本、security/market、规范交易日期、优先级/状态枚举、attempts和带时区时间戳。无版本的旧队列只在通过同一行校验后升级标记；未知未来版本或损坏任务拒绝启动，不自动清理/覆盖。
- 新增回归检查有效队列有版本标记、损坏任务拒绝恢复、未知未来版本拒绝恢复。分钟服务26/26、归档37/37、红利6/6、只读迁移dry-run6/6，总计75/75；py_compile及架构边界检查通过。Swift XCTest仍执行0。
- 启动恢复校验补充运行租约一致性：`running` 必须有租约，其他状态不得残留租约，避免无租约的运行中任务永久卡队列。新增损坏租约回归，Python全套75/75仍通过。

- 分钟诊断接口审计发现未传日期范围时，`missingDays`只代表已记录覆盖状态，可能被误读为完整历史范围的缺失总数。现增加`missingDaysScope`和`missingDaysMayBeUnderstated`；指定起止日期时按交易日历计算精确范围，未指定则明确为记录覆盖范围。HTTP回归验证范围内两个未归档交易日计为缺失、无范围时不宣称完整；全套Python75/75通过。

## 2026-10-26 交易日历时区对象校验

- 发现`MarketSession`仅检查`tzinfo`非空，没有检查`utcoffset()`是否有效；自定义tzinfo若返回None，`astimezone()`可能采用主机本地时区语义。
- 现要求市场/交易日期/时区/日程结构有效，且每个时间戳都有非空有效UTC偏移；日历交易日必须为纯`date`，时点序列必须为不可变tuple。无效offset、datetime冒充date和list日程均被拒绝。
- 新增3项归档回归。分钟服务26/26、归档38/38、红利6/6、迁移dry-run6/6，总76/76；XCTest仍未执行。

- NAS服务公共入口日期类型复审：初始补采、历史查询、研究查询和诊断查询现在要求纯`date`；初始回补窗口拒绝bool冒充整数，身份和优先级在空交易日范围也先校验。新增回归断言覆盖datetime冒充交易日及bool窗口；全套Python76/76通过。

- 分钟观测幂等键审计发现，同一标的/分钟/来源/抓取时刻若携带相互冲突的值，SQLite `INSERT OR IGNORE`会静默保留首条，且当前投影可能与append-only观察历史分歧。现对同键不同内容 fail-closed，并在写当前投影前检测；批次冲突时整批事务回滚。回归同时验证完全相同回放幂等、矛盾观察拒绝和前序新点回滚。归档39/39、服务26/26、红利6/6、迁移6/6，总计77/77；py_compile/架构边界通过。

- 分钟归档启动迁移审计发现，已有数据表缺失`archive_meta.schema_version`时初始化会直接补写当前版本，可能把未知旧格式或元数据损坏伪装成当前schema。现启动前识别既有数据表并验证schema元数据；已有归档缺版本或版本字段损坏时停止，不重标/覆盖。全新空库仍正常初始化。新增恢复回归验证既有分钟行保持不变且损坏元数据不被补写。归档40/40、服务26/26、红利6/6、迁移6/6，总计78/78；`py_compile`与架构边界通过。

- 归档备份验证复审发现`_validate_database`仅把schema版本转成整数比较，会接受非规范值（如`01`），但新归档初始化已拒绝该值，导致备份可能产出无法重启读取的包。现让integrity_check/backup/restore共用严格版本校验；缺失、非规范、非数字及未来版本统一拒绝。新增测试确认损坏元数据不会生成备份；全套Python78/78通过。

- 补采队列schema复审确认仅检查列名不足以维护任务幂等性。启动校验现在同时验证`queue_meta.key`唯一键与`backfill_task(security_code, market, trading_date)`复合主键；表被重建或丢失唯一约束时拒绝启动。新增无主键队列恢复回归，全套Python78/78通过。

- 分钟归档备份发布审计发现备份使用`os.replace`覆盖已有目标，而restore已采用拒绝覆盖策略。现备份改为同目录原子no-clobber发布；已有目标返回明确错误且原有字节保持不变。回归覆盖此保护，全套Python78/78通过，`py_compile`、架构边界和`git diff --check`通过。

- 分钟归档启动路径之前只校验schema版本，未执行完整SQLite和业务行完整性检查；损坏数据库可被服务对象打开。现构造阶段在schema初始化后立即验证数据库结构和分钟/coverage语义；无效库启动即fail-closed。已有语义损坏测试增加重启拒绝断言，全套Python78/78通过。

- 交易日历接入审计发现严格校验仅在补采和研究路径执行；历史查询/实时采集/诊断可能接受异市场、越界或重复日期响应。现提取统一日历入口，所有服务调用验证MarketSession类型、market、日期范围及唯一交易日，并按日期排序。回归确认重复/异市场日历在查询与实时写入前被拒绝，归档无新增数据；全套Python78/78通过。

- 分钟成交量完整度审计发现，仅检查累计量单调递增，未验证标记为`cumulative_delta`的分钟成交量是否等于相邻累计量差；缺失累计量也可能作为研究证据。现要求差分来源同时携带累计量和分钟量；完整度检查全日累计序列无缺点、单调，且每个差分与上一分钟一致（首分钟使用开盘累计量基准）。矛盾或缺失数据标Partial，不能进研究。新增回归覆盖缺累计值和差值不匹配；全套Python78/78通过。

- 长期采集诊断的执行计划复审发现collection_log按标的/模式求最新抓取时间没有复合索引，记录增长后会扫描整张采集日志。归档初始化现幂等创建`(security_code, market, mode, fetched_at)`索引，并在诊断回归中核对索引存在；全套Python78/78通过。
- 补采采集日志索引回归进一步验证旧归档缺少该索引时，重启会幂等重建索引而不改变历史分钟/覆盖数据；全套Python78/78仍通过。


## 2026-10-26 全盘循环补充

- 红利历史收益率去重原先依赖输入顺序，同一观测时间的多个来源可能改变历史分位与来源列表；历史质量分还接受高于100的值。已实施确定性优选（质量、抓取时间、来源和值排序）及质量范围校验，并增加输入正序/逆序一致性回归。红利测试7/7；分钟归档40/40、服务26/26、迁移dry-run6/6，当前 Python 总计79/79。
- Swift/Xcode 与设备链仍属于 External Verification Pending；XCTest 未执行，结果保持 defined 与 executed 分离。


- NAS HTTP授权复核发现授权器结果此前被truthy转换；现仅严格接受布尔True，所有其他返回值及异常均fail-closed。新增授权边界回归。分钟服务27/27、归档40/40、红利7/7、只读迁移dry-run6/6，Python总计80/80。


- 历史分钟provider返回会话日历外时间戳的情况此前会先写归档再因完整度不足而标Partial，导致历史查询可见盘外点。现provider响应在落库前整体校验交易时段时间表；异常源不写数据并允许fallback。新增回归；归档41/41、服务27/27、红利7/7、迁移dry-run6/6，当前Python总计81/81。


- 分钟覆盖诊断此前存在 crash 后残留未评估状态、请求范围外 missing 污染范围计数、且缺失交易日没有逐日状态的问题。现按指定日历范围重算 coverage 并列出缺失/部分日期，统计仅覆盖请求范围；未指定范围保留 recorded-coverage-only 语义。新增回归覆盖崩溃窗口、Partial识别、Missing日期输出和范围隔离。归档43/43、服务27/27、红利7/7、只读迁移dry-run6/6，共83/83通过。

- 无范围诊断原先只在汇总中计入“已评估但无分钟行”的missing日期，逐日数组没有相应记录。现把已有coverage日期列入days，仍不推断未评估交易日；明确记录范围可能低估。回归纳入分钟归档测试，不改变当前测试项数。


## iOS build pipeline review — 2026-10-26

- The repository workflow targeted the obsolete `GuanpanNext/ios` tree and old scheme, so it could not build this F app. Updated triggers to current F package/source/app paths, run Swift package tests on macOS, generate `GuanpanF.xcodeproj`, build generic iOS device and simulator targets, and package an unsigned IPA. YAML and path contract pass static validation. This Linux environment has no Swift, Xcode, or XcodeGen; CI is configured but unexecuted, so XCTest remains defined=31/executed=0/passed=0/failed=0 and EXT-3 remains pending.


- iOS app target static review found a compile-blocking missing package dependency: `GuanpanFApp.swift` references FAdvisor public presentation types but the app target neither imported nor linked FAdvisor. Added the import and XcodeGen product dependency. Static module/dependency consistency passes; Apple toolchain build remains unexecuted and pending.

## 2026-10-26 NAS部署壳审计

新增 NAS HTTP runner、Dockerfile、Compose 持久卷和运行配置示例。runner 强制要求强度至少32 UTF-8字节的 API token 与显式 `module:function` runtime factory；未配置真实日历/Provider 时服务 readiness fail-closed。HTTP smoke 实际验证 `/livez` 200、匿名 `/readyz` 401、空 Provider `/readyz` 503。Python 语法、Compose YAML结构检查通过，现有 NAS/迁移 Python 套件83/83通过。当前环境无 Docker，未做镜像构建或真实 NAS 部署；真实行情、生产交易日历、NAS端口8788和部署备份恢复仍 External Verification Pending。该运行壳尚不是完整生产部署包。

## 2026-10-26 默认真实 Provider 与 Calendar 接入

F 默认 runtime 不再要求用户提供 Python 插件。新增腾讯当日分钟采集、东财按精确日期请求1分钟历史数据适配器、明确来源时间/成交量语义和2026年沪深交易日历；后端启动后回补已配置证券最近最多120个有日历的交易日，实时采集与补采分别运行，历史源慢请求不阻塞实时轮询。腾讯09:30开盘集合数据只作为源端观察、不进入正常分钟档案；首根09:31分钟累计成交量纳入首分钟成交量，并由严格差分校验保护。源无数据/格式变化仍保存Missing或Partial，不伪造覆盖。腾讯接口在本环境实网返回并通过F日历校验写入临时SQLite（16条、240预期，状态Partial）；东财历史接口本次超时，不能声称历史源已实网验证。2026交易日历根据上交所2026休市公告核对，未知年份fail-closed。新增Provider/Calendar/runtime测试10项，NAS/迁移 Python总计93/93通过；语法、架构边界和Compose结构检查通过。Docker镜像、NAS端口8788、实时长期运行、东财历史覆盖、其他年份官方日历及NAS备份恢复仍External Verification Pending。

## 2026-10-26 NAS容器entrypoint解释器路径故障

- NAS日志显示tini无法exec `/usr/local/bin/f-minute-entrypoint`。Dockerfile的COPY目标与Compose包内路径核对一致；真实原因是shell脚本使用CRLF，内核把shebang解释器解析为`/bin/sh\r`，因此表现为目标脚本“找不到”。
- 已规范脚本为LF，新增`.gitattributes` `*.sh text eol=lf`；Dockerfile构建期增加shebang检查，部署包回归校验脚本首行和无CR字符。既有部署包测试7/7通过，shell语法检查通过，ZIP内脚本字节已核验。
- 当前环境无Docker/Podman，镜像构建及容器启动未执行。NAS侧必须重新Build镜像并重建容器后复核日志；旧镜像重启不包含修复。生产恢复仍External Verification Pending。


## 2026-10-26 NAS liveness 与 GitHub F 编译闸门状态

> 后续覆盖：以下 unauthorized 描述属于旧运行容器。用户已授权移除NAS API token；当前源码不再校验 `X-Api-Key`，部署中的容器未更新。

- 用户实测 NAS `:8788/livez` 返回 `{"status":"alive","service":"f-minute-archive"}`，可确认端口和服务进程可达。用户另给 `{"error":"unauthorized"}`，没有路径和请求头，无法据此区分根路径访问、遗漏token或token不匹配。匿名 `/livez` 成功；`/readyz` 和业务API必须带有效 `X-Api-Key`。未提供 readiness 响应或 token 验证结果；日历、归档、provider和生产数据准备状态仍未验证。
- 已创建私有GitHub仓库 `ggjj45828/guanpan-f`。本地repo配置了该 `origin`。用户已明确授权上传，但本地 `git push` 在认证前因缺GitHub用户名凭据失败，没有上传对象；GitHub connector尚未连接。已有 `guanpan-pro-native` Actions成功记录只覆盖B的 `b-latest`，不可用于证明F构建。当前无Swift/Xcode/XcodeGen或GitHub CLI；FCore 39条与App UI 2条XCTest均保持未执行，首次F构建闸门未通过。

## iOS 可运行版本收敛：统一图表叠加层 — 2026-10-26

- 从 `606f470` CLEAN checkpoint 开始，未回退至任何旧基线。新增 `FChartOverlayModel`，将既有实时分钟、NAS历史分钟和日K的 `FChartDataModel` 作为唯一数据入口；成本、均价、前收、IOPV和Candidate仅以同证券且已标注来源/获取时间的 `FChartPriceOverlay` / `FIOPVObservation` 进入模型。
- 该模型拒绝跨证券与重复同类overlay；视窗纵轴合并实际K线高低点或分钟价格与全部可用overlay，Unavailable项目不产出数字或曲线。它为“不可因其他曲线挤出真实线”提供共享核心，但尚未把现有各SwiftUI图表替换成一个渲染器。
- 没有新增或运行XCTest；Swift/Xcode仍不可用，保持 FCore XCTest `39 defined / 0 executed / 0 passed / 0 failed`，App UI `2 / 0 / 0 / 0`。本机Python命令也不可用，架构脚本本阶段未执行；不能将文件级复核误报为编译或测试通过。

## iOS 可运行版本收敛：确认成交到重新判断 — 2026-10-26

- 原生 App 以前只展示 Candidate Plan，真实 Ledger writer 未被 UI 消费。现在只有通过 Guard 的 `.buy`/`.sell` 候选可打开确认表单；用户必须输入实际价格、份额、证券名称和确认说明，再按一次确认写入。表单是记录已经完成的真实成交，不向券商或外部交易端发送订单。
- 写入路径重读账本并匹配 Candidate digest，卖出按当前仓位执行成本分摊，固定单笔 ETF 费用 CNY 0.10，随后经 `FConfirmedLedgerWriter` 原子持久化。成功后旧结果清除、账本重读，并按原作用域重新请求 Advisor；做T/网格/回本不自动生成或拆分 Ledger 成交。
- 无 Swift/Xcode/Simulator，未编译或执行 UI/XCTest；这是一段已编码的安全闭环，不是已验证的真实资产写入功能。

## iOS 可运行版本收敛：Advisor 画像与记忆投影 — 2026-10-26

- App 原先直接创建问题请求，导致已有的 Investor Profile / Decision Memory 存储没有进入在线 Advisor。现改用 `FAdvisorRequestAssembler`，仅将冻结时点、当前 account/scope 的受限投影放入请求；该存储与 Ledger writer 分离。
- Guard 完成后，冻结的 DecisionContext 与由结果生成的 Decision Memory 先后以 optimistic digest 保存；持久化错误会中止“已完成”结果，不把不可审计的建议呈现给用户。Profile 尚无编辑 UI，且不从模型回答自动学习。
- 未执行 Swift 编译、XCTest、真实 Profile/Memory 恢复或在线模型联调；全部仍为 External Verification Pending。

## 2026-11-01 exact-main local audit continuation

- Audit baseline is repository `main` HEAD `0296013f20156b23831cedd6d95f707eb6d89cc3`, in an isolated local copy. No commit or push was made.
- The B-001…B-145 mapping contains 145 unique continuous IDs. A mechanical scan now finds 82 rows carrying the generic “待逐项核验” status. Profile rows B-031…B-037, news/AI rows B-038…B-044, and Advisor/portfolio rows B-045…B-051 were individually inspected against current F source, tests and UI; implementation and missing acceptance are stated separately. This count is only traceability hygiene; it does not prove implementation or acceptance. B-140 records cross-market UI/source evidence and its unverified status explicitly.
- NAS portability audit found that Windows could reject directory `fsync` and hard-link publication. Calendar publication could replace its file and then report failure; archive backup/restore could fail despite valid staged data. Archive/restore now use same-directory atomic no-clobber rename on Windows and retain hard-link publication plus directory `fsync` on POSIX. Calendar publication skips only unsupported Windows directory `fsync`; file contents are still flushed before replacement.
- Regime freshness audit found that a newly fetched response could make old daily bars appear current. `FMarketRegimeEngine` now requires the newest bar itself to be within `maximumDataAge`; a stale-bars XCTest definition was added.
- Regime transition audit found that re-evaluating the same daily bar could count as another confirmation session. Confirmation now advances only when the latest bar timestamp advances. The iOS app passes per-security memory back to the engine and stores reliable memory in versioned `UserDefaults` keys; `dataUnreliable` results do not overwrite the last reliable memory. A same-bar re-fetch XCTest definition covers both regime and risk confirmation counters.
- Regime benchmark-input audit found that the engine accepted anonymous raw returns with no index identity or time metadata, so stale/future/duplicate index values could count as separate crash signals. Input now requires an identified market, source, observation time, capture time and finite session return; observations outside the 36-hour alignment window, captured before observation, from the future or malformed are excluded. Repeated market IDs count once; conflicting returns at the latest timestamp exclude that market. Added XCTest definitions for stale/future exclusion, duplicate-index deduplication and conflicting-duplicate rejection, and updated crash-trigger fixtures to the typed contract. The live cross-market series is not yet supplied as benchmark observations to ETF-specific Regime assessments.
- Local checks: NAS archive/provider tests 60/60 passed; NAS service tests excluding loopback HTTP cases 30/30 passed; runtime 5/5; read-only legacy ledger migration 6/6; dividend research 7/7. Python `py_compile`, architecture-boundary verifier, and `git diff --check` passed. The counts are local suite results, not Apple CI results.
- Verification limits: this Windows sandbox denies loopback sockets (`WinError 10013`), denies the system temp location unless redirected, and restricts hard-link publication; the latter exposed and informed the portability correction. PyYAML is unavailable, so the iOS structure and NAS deployment-package Python tests could not start. Swift/Xcode/XcodeGen are unavailable; no XCTest, iOS build, Simulator, or screenshot review was performed.
- Cross-market continuation: replaced the static `CrossMarketOverview` placeholder with a themed index board and explicit per-index price, change, source, source time or unverified-time status, market time zone and unavailable reason. Added direct phone requests for Tencent (Shanghai, Shenzhen, CSI 300, ChiNext, Nasdaq-100, Hang Seng), Sina (Nikkei 225; source time is unavailable and is explicitly barred from Regime/Quant), and Naver (KOSPI; requires a parseable source timestamp). Tencent/KOSPI observations more than 72 hours old or in the future are rejected. Refresh is independent of NAS; NAS remains optional for historical research. Home entry cards now describe the direct index connection.
- Cross-market continuation: added a durable NAS index daily-history archive/API for Tencent's configured Mainland China, Nasdaq-100 and Hang Seng symbols. NAS validates OHLCV, rejects duplicate dates, excludes the current incomplete session, persists `/data/index-daily-history.sqlite3`, and reports sample count/range/fetch age in the API and `/readyz`. The iPhone reads historical bars only through NAS, evaluates an index-specific `FMarketRegimeAssessment`, stores reliable index confirmation memory separately by code, and displays state/risk/confidence/data cutoff beside each index. Japan/Korea remain quote-observation-only because no verified daily-history adapter is available.
- Cross-market verification limits: this Windows environment has no Swift/Xcode toolchain, so the iOS/NAS client integration has not compiled, run on iPhone, or been verified against live provider responses. Regime requires at least 60 valid completed sessions and the engine freshness limit; insufficient or stale history is explicitly shown unavailable. Supported index histories now receive independent index-level assessment, but those states are not yet mapped into each ETF's security-specific Regime/Local Quant context. Market-specific exchange calendars, source coverage, sample alignment, and external-provider semantics remain unverified. The complete Local Quant factor/strategy/Guard/Trigger chain is still not connected through the UI.
- Regression acceptance added: `testCrossMarketIndexBoardIsDiscoverableAndListsConfiguredMarkets` asserts the home entry, cross-market route, refresh control, all eight configured index cards, and a Regime status row per index. `Tools/test_index_history.py` covers completed-session filtering, unsupported-market rejection, OHLC/date validation, durable caching and stale-cache failure state (6/6 passed). `Tools/test_index_history_api.py` defines HTTP response/validation acceptance but was not executed because this sandbox blocks loopback sockets. Swift/XCTest remains unexecuted because Swift/Xcode are unavailable. The UI test does not verify provider data or screenshot quality.
- Index-history freshness review found that a persisted `fetchedAt` timestamp in the future could pass the cache TTL comparison and be reported as fresh. The archive now treats future timestamps as stale in both the history API and `/readyz`, and forces a refresh attempt; a regression case was added. Index-history suite is now 7/7 passed.
- Investor Profile trace audit (B-031…B-037): verified the eight current attribute keys; explicit/learned/temporary revision sources; as-of projection; optimistic persistent store; request assembly and DecisionMemory citation snapshots; and protection against learned values replacing explicit preferences. The initial audit found no user-facing profile editor, so explicit settings controls and confirmed single-attribute deletion were added in this continuation. No production learner from confirmed fills/feedback, statistical sample threshold, calibrated confidence, or proof that confidence changes recommendation ranking exists. XCTest definitions cover model boundaries, but are not executed here. Rows distinguish coded paths from outstanding acceptance and are not marked passed.
- Profile usability fix: added settings controls for the eight explicit preference fields, persistent save/correction through the versioned profile store, and individually confirmed deletion that preserves other attributes and never touches the Ledger. Added an FCore test for confirmed single-attribute deletion and an App UI acceptance for save/clear. These Swift changes are not compiled or executed here; automatic behavior learning remains intentionally unimplemented pending a defined, auditable sample policy.
- News/AI trace audit (B-038…B-044): verified the 24-hour/40-item public feed parser, explicit security-code association, minimum URL/date checks, market-background separation, and cited-observation guard path. Optional news now uses fresh in-memory cache and background refresh, so the public feed timeout no longer delays Advisor; no dedicated parser/network/news-impact acceptance suite or live provider/DeepSeek run was found. The app has online DeepSeek only; deterministic local Regime/Guard code exists, but no offline LLM, no complete Local Quant connection, and no auto-fallback. These facts and limitations are recorded per row; none is marked end-to-end passed.
- Advisor/portfolio audit (B-045…B-051): verified only one online DeepSeek Candidate provider; deterministic guards remain separate from Ledger writes; Portfolio scope projects all holdings/cash; and current ETF constituent overlap data is absent. A concrete gap was found: Market Regime appeared on screens and in memory but was not part of the frozen DeepSeek context, while the Local Quant hard block was attached only after the model replied. `quantState` observations now carry fresh cached security Regime and separately identified cached index Regime with explicit no-security-mapping metadata, or per-index Unavailable reasons. The pre-model context also states that trading candidates are blocked while Local Quant is incomplete. A 36-hour freshness/unavailable-state XCTest definition and DecisionMemory snapshot check were added. The security-to-market mapping, securities' historical source coverage, Apple compilation and real DeepSeek roundtrip remain unverified.


## 2026-11-01 security daily history source audit

- Verified that `refreshDailyKline` fetched Tencent daily bars directly from the iPhone even though these bars feed historical chart/regime calculations. Replaced that path with `FNASecurityDailyHistoryClient` and `/api/v1/security-daily-history`; the iPhone still fetches live quotes directly. The existing NAS daily archive now accepts only six-digit mainland codes with supported exchange prefixes, maps them to `sh`/`sz` symbols upstream, stores completed OHLCV bars in the durable daily-history SQLite archive, and explicitly filters the current session. It reports source/fetchedAt/range/sample count and `available`/`insufficient`/`stale`/`unavailable`; `/readyz` also exposes collected securities and freshness. No synthetic rows are generated.
- The iOS reader checks security identity, unadjusted status, at least 60 rows, provider metadata, fetchedAt within 36 hours and not in the future, valid Shanghai trading dates, valid OHLCV and strictly increasing dates before creating the chart/Regime snapshot. The UI now identifies the data as NAS archived daily K-line.
- Added provider mapping/current-day rejection, exchange-prefixed request, durable security projection, and HTTP endpoint acceptance definitions. The index/security daily-history suite passed 9/9; combined unaffected local suites passed 90/90, including three new static data-path checks; Python syntax, architecture boundary verifier and `git diff --check` passed. HTTP loopback endpoint tests remain unexecuted because Windows sandbox denies loopback sockets; Swift/Xcode/XCTest and live NAS/provider checks remain unverified.
- B-005, B-007, B-009, B-012 and B-138 were updated with the corrected data path and remaining verification. The 145 requirement IDs remain; 85 rows still carry generic status and require individual audit. No commit or push was made.


## 2026-11-01 position-purpose and home-layout audit

- B-052 audit distinguishes implemented trade accounting from position allocation: F records Episode economic cost and only labels/attributes T contribution when confirmed fills are classifiable, but position units remain aggregated and are not explicitly divided into long-term core units versus tactical units. The trace row now records this as partial with the required quantity-allocation and ledger invariants outstanding; no guessed automatic fill classification was added.
- B-063/B-066/B-073 source review found fixed half-width cards in the modern and creative-bento themes on narrow devices. Modern now keeps portfolio/advisor full-width and puts market/cross-market summaries in an adaptive grid with a 260pt minimum. Static bento uses the same width threshold instead of forcing two HStack columns. The data-starmap placed left/right nodes on the center card's horizontal band; nodes and spokes now use four diagonal positions to leave the center clear.
- Added `Tools/test_home_layout_contract.py` to assert adaptive widths, full-width primary cards and separated star-map nodes. Three structural regressions passed. Trace rows B-052/B-063/B-066/B-073 now reflect current evidence; 145 unique requirement IDs remain, with 87 generic statuses still needing individual inspection. Simulator, narrow-device screenshots, Dynamic Type, VoiceOver and Apple CI remain unverified. No commit or push was made.


## 2026-11-01 appearance and theme audit

- B-074 review found `FHomeRoot.rootStack` forcibly set `.colorScheme` to light and also forced navigation-bar color schemes per theme. Removed those overrides. `FThemeLayoutRegistry` now creates dynamic UIKit-backed colors for each theme's light/dark backgrounds, surfaces, foregrounds, semantic market/risk colors, chart overlays and accents; accent buttons use a separate contrasting foreground. B-071/B-074 rows now distinguish coded support from contrast acceptance.
- Added a dark-appearance UI screenshot test for all ten home themes and extended `Tools/test_home_layout_contract.py` to catch a forced-light regression and require dynamic tokens. Four structural checks pass. Eye-care mode, Dynamic Type, contrast ratios, actual iOS screenshots, Apple build and UI XCTest remain unverified.
- Trace matrix remains 145 unique continuous IDs with 84 generic statuses remaining. No commit or push was made.


## 2026-11-01 landscape support audit

- B-075 review found no explicit supported-orientation list in the iOS target. Added portrait plus both landscape orientations to `GuanpanFApp/project.yml` and a UI acceptance that rotates to landscape, opens security 159352 and verifies the detail scroll container remains available. The test dismisses the number-pad keyboard before opening the security page. A standard-library source check validates both landscape declarations and the UI test contract.
- Orientation metadata and test are encoded but unverified until Apple CI/Simulator. In landscape, chart height, axis labels, gesture targeting, bottom-tab safe area and keyboard dismissal still need screenshot/device acceptance. Trace matrix retains 145 unique IDs and 84 generic statuses.


## 2026-11-01 NAS status coverage wording audit

- Settings previously described live minute and daily K together as Tencent direct, even though daily history had moved to NAS, and said automatic historical sync was not connected despite the NAS worker. Corrected the UI: live quote source remains direct from iPhone; security/index daily history reads from NAS; background history collection is described as deployment-universe scoped.
- `/readyz` was being reduced to only Ready/configured-market text in the iPhone. It now also summarizes realtime/backfill worker states and available archived index/security daily K counts, preserving the existing explicit warning that Ready does not prove full date coverage. Added source-level regressions. Server HTTP integration and actual NAS/phone status display remain unverified here.
- B-079/B-080 now record the Ready-vs-coverage boundary and the distinct network/provider failure messages. The current 145-row matrix has 82 generic status rows remaining.

## 2026-11-01 navigation and advisor audit

- B-076 source review confirms five distinct bottom tabs, each with its own `NavigationStack`; the existing primary-destination UI test visits the routes. B-077 is only a single-question/latest-result flow; no persisted conversation history or session list was found, so the trace marks chat as partial instead of claiming a full chat implementation. B-078's result card renders conclusion, basis, read-only ledger snapshot, holdings, quote/research status, risks, invalidation conditions and guarded Candidate Plan.
- Added stable accessibility identifiers to the advisor composer/context/result sections, explicit long-text expansion for conclusion and basis, a UI acceptance for the advisor context rows, and a source-contract regression. The device UI test remains unrun because this workspace has no Apple toolchain. Trace rows B-076/B-078 record implementation evidence with simulator acceptance pending; B-077 records the missing conversation history as an open product gap. The matrix contains 145 unique continuous requirement IDs and 79 generic statuses remaining. No commit or push was made.
- Inspection of B-081/B-082 found no UserNotifications chain and no explicit persisted offline quote cache/freshness contract. The trace now marks notifications unimplemented and offline operation partial; stale UI state must not be presented as a complete offline mode. Define notification triggers and data-specific offline cache behavior before implementation. Generic `待逐项核验` statuses now number 77; no commit or push was made.
- B-083/B-086 source review confirms advisor NAS Research is consumed from a fresh local cache and refreshed in a detached task, while deterministic guards require fresh cited quotes and enforce cash/units; the app separately blocks asset-changing candidates until Local Quant exists. B-084 uses device-only Keychain storage with a secure, cleared entry field; B-085's advisor request paths contain no direct console logging. Added four static safety-contract regressions. This does not replace device Keychain, NAS latency, log-scrubbing or Apple XCTest acceptance. The trace now records these concrete implementation findings; generic `待逐项核验` statuses number 73. No commit or push was made.
- B-087/B-089/B-090/B-091/B-092/B-093 evidence review: cash checks enforce limit-price notional plus estimated fee against actual available cash, but no user-defined reserve floor exists; no per-security official lot/tick/limit rule model exists; AI candidates carry no probability score and Regime confidence is not a probability; the shadow scorecard records outcomes but evaluates Advisor direction only; future timestamps and Research as-of limits are checked but company-action/provider-revision leakage is unproven; unavailable paths and guards exist but require broader real-provider/UI acceptance. Updated these trace rows to name the implemented boundary and remaining evidence rather than copy generic anchors. The remaining generic row count is 67; no commit or push was made.
- B-094/B-102 review found the Python test discovery was not part of Actions, NAS/Tools-only changes did not trigger the only existing workflow, and `test_ios_app_structure.py` still asserted removed pre-Keychain/optional-NAS copy. Updated that test to assert the current Advisor Keychain/NAS context contract. Added `.github/workflows/f-python-nas.yml` to run all Python tests, compile Python sources and verify architecture boundaries on relevant source/NAS/Tools changes; added a workflow path/run contract test. CI is not triggered for this dirty tree because push is prohibited, so Linux integration tests and YAML-dependent tests are still pending on Actions. B-094..B-102 now record current evidence and missing runs. The complete Windows discovery attempt produced 138 tests with 6 environment errors: four loopback requests blocked by `WinError 10013` and two PyYAML imports unavailable. The matrix has 145 unique rows and 58 generic statuses remaining. No commit or push was made.
- B-103/B-104 confirms theme screenshot test definitions exist but visual comparison has not been performed; B-110 remains explicitly unaccepted after the user's layout feedback. B-105..B-115 now point to existing delivery/architecture/continuation records and preserve unverified status. Created `CONTINUATION.md` with Ledger/NAS/Quant/Regime/no-fabrication/no-push redlines and confirmed gaps, and added a regression contract for it. B-116..B-120 source search found no cross-market lead-lag windows, verified ETF benchmark baskets, A-share lunch snapshots, or post-lunch reaction statistics. Added a guard regression that prevents assigning index Regime to an ETF without an explicit mapping, and recorded the absent research functions as not implemented. The matrix now has 145 IDs and 40 generic statuses remaining. No commit or push was made.
- B-121..B-132 source review found no conditional lead-lag analysis, market-pair divergence model, overnight/opening/close-to-next-day response model, FX context, per-ETF learned leader ranking, or session profile. The index Regime engine only counts synchronized fresh benchmark declines for risk and the Advisor includes index state with `securityMapping=Unavailable`; this is not ETF lead-source mapping. IOPV is a chart overlay when supplied, not an Advisor execution gate. Candidate Shadow supports intraday observation and fill linkage but does not implement the full multi-layer Quant hypothesis/confirmation/strategy-selection lifecycle. Updated the rows with these implemented boundaries and explicit absent features. The matrix now has 145 IDs and 28 generic statuses remaining. No commit or push was made.
- B-133..B-145 evidence review: NAS has chronological walk-forward/quality/temporal-concentration controls for existing study families, archive `available_as_of` filtering and source-time validation; this does not prove cross-market selection, correction-aware no-lookahead, multiple-comparison calibration, or adequate 100–200 day samples. CN 2026 calendar is the only built-in official calendar year/market. Advisor system prompt contains structured human explanation rules; DecisionMemory persists context observations; CandidateShadow keeps intraday market and fill links; the single-context pipeline is coded. These remain partial pending the omitted research engines, official calendar coverage, device/real-service execution and full outcome feedback. Updated trace rows to preserve that distinction. The matrix now has 145 IDs and 17 generic statuses remaining. No commit or push was made.

- B-053..B-072 theme and home-layout trace pass: replaced generic status wording with specific code/test evidence, current implementation limits, and explicit screenshot/device acceptance. The trace has 145 unique requirement rows and zero generic 待逐项核验 row statuses; B-097 now reflects that count. This only closes generic trace wording, not the pending simulator visual acceptance, and does not declare overall completion. No commit or push was made.

- Re-ran the selected Python/NAS suite after the theme trace pass: 105 tests passed. compileall, architecture-boundary verification, git diff --check, and the 145-row/unique-ID/13-column/zero-generic-status trace validation passed. The separate index-history HTTP integration test could not bind a loopback socket on this Windows host (WinError 10013); it remains to be confirmed on Linux CI. Swift/Xcode simulator acceptance is unavailable here. No commit or push was made.

- Removed a Windows-only test-environment failure from NAS HTTP route coverage by adding `Tools/http_test_harness.py`, which sends raw HTTP/1.1 requests through the production `BaseHTTPRequestHandler` using in-memory streams. Migrated the index/security daily-history, minute-history, diagnostics, research, `/readyz`, and backfill endpoint tests from local TCP listeners; all affected route tests pass. Full local discovery now runs 139 tests successfully; the only two discovery errors are imports for `test_ios_app_structure.py` and `test_nas_deployment_package.py`, because PyYAML is absent from this runtime (the CI workflow installs it). `compileall`, architecture boundaries, `git diff --check`, and 145-row trace validation pass. Swift/Xcode/Simulator acceptance remains unavailable. No commit or push was made.

- Follow-up B-060/B-061 theme audit found that home and chart text used SwiftUI `.secondary`/`.tertiary` foreground styles, bypassing the selected theme's semantic palette on custom light/dark surfaces. Home content and `FUnifiedSecurityChart` now use each theme's foreground tokens; the Advisor result card receives the active theme explicitly. Added a source contract to catch a return to system semantic colors. `F-B-145-TRACEABILITY.md` records this source-level correction; screenshots and Apple build remain unverified. No commit or push was made.
- Index coverage transparency fix: /readyz previously omitted requested Japan (int_nikkei) and Korea (KOSPI) from the NAS historical-index collection map, making missing historical support invisible. The archive status at that historical checkpoint included both as unavailable. This was later superseded for Nikkei by the official close-only CSV adapter; KOSPI remains unavailable. Updated deployment notes and B-012 evidence, with archive and /readyz regressions. The 140 locally runnable Python tests passed at that historical checkpoint; compileall, architecture boundaries, diff check, and 145-row trace validation pass. Two YAML-dependent modules still cannot load locally without PyYAML. No commit or push was made.
- Regime factor review found `realizedVolatility20Sessions` is annualized and risk escalation starts at 25%/35%, but the explanation emitted `volatility_expanded` at 3.5% annualized. Aligned the explanation threshold to 25% (the existing R1 threshold) and added XCTest cases for ordinary (~8%) and elevated (~32%) annualized volatility, including expected risk level and reason. Swift tests cannot run on this Windows host; source diff and Python regressions are rerun separately. No commit or push was made.
- Found a data-boundary hole in `FCurrentIntradaySnapshot`/`FChartDataModel`: direct callers could pass non-ASCII numeral security codes, negative minute volume, non-finite price/OHLCV, or invalid daily ranges. Added ASCII-code, finite timestamp/number, positive price, nonnegative volume, and OHLCV consistency validation at snapshot/chart boundaries, plus Swift regression cases for minute snapshot, daily snapshot, and chart series. Updated B-010/B-058 trace anchors. Swift/XCTest remains unrun without Apple tooling; static and Python verification is reported separately. No commit or push was made.
- Follow-up numeric-boundary audit found `LedgerSchema.isFinite` only excluded NaN, so positive/negative infinity could pass ledger money checks; the same NaN-only pattern existed in Advisor context, PnL, fees, and related projections. Replaced those predicates with true `Decimal.isFinite`; chart IOPV/overlay values and timestamps now also reject infinities. Added XCTest definitions for infinite cash, fill price, chart price, IOPV time, and overlay time; updated B-010. Verification: 140 locally runnable Python tests passed at that historical checkpointed; `compileall` and architecture-boundary verification passed; trace has 145 IDs and zero generic row statuses. Swift/XCTest cannot run here (no Swift/Xcode); `git diff --check` requires CRLF-aware checking for this checkout. No commit or push was made.
- Continued boundary review found chart `priceRange` validated finite inputs but did not protect Decimal padding arithmetic from overflow before constructing `ClosedRange`. It now checks the maximum representable bound and all computed range values, returning unavailable when it cannot create a valid finite range. Added a greatest-finite-Decimal range regression and extended minute/daily snapshot tests with infinity values. These Swift tests remain defined but unexecuted without Apple tooling. No commit or push was made.
- Regime review found volumeExpansionRatio accepted infinite/negative daily volumes and could turn an infinite ratio into an independent crash signal. The factor now requires all 20 volume observations to be finite and nonnegative, computes averages without avoidable intermediate overflow, and returns unavailable for a non-finite final ratio. Added an XCTest definition confirming infinite volume cannot raise risk; updated B-011. Swift/XCTest remains unexecuted. No commit or push was made.
- Follow-up chart arithmetic audit found daily moving averages summed Decimals before dividing, which can overflow with individually finite bars. The MA accumulator now divides each bar value first and rejects non-finite results; added a greatest-finite Decimal daily-series regression that checks finite chart bounds. B-058 was updated; XCTest remains unexecuted without Swift/Xcode.
- Regime public API review found that an infinite maximumDataAge makes arbitrarily old source and bar timestamps pass the freshness comparison. The evaluator now treats non-finite or negative age limits as invalid and fails the assessment closed; XCTest definitions cover infinity, NaN and negative limits. Updated B-011. Swift/XCTest remains unexecuted without Apple tooling.
- NAS/Advisor audit found the mobile summary labelled the requested query window as dataRange, which could overstate actual archive coverage. Research Evidence schema v2 now content-addresses a separate dataRange derived from qualified sessions; envelopes with at least 25 qualified days require that actual range inside the requested range. iPhone displays actual dataRange plus sampleCount, researchGeneratedAt, explicit unavailable strategyVersion, methodologyVersion and freshness. Old schema v1 evidence fails closed. Added server tests for sparse actual coverage, range binding and missing-range rejection, plus Swift contract fixtures. Python service suite: 34/34 passed; full Python suite rerun pending. Swift/XCTest remains unexecuted.
- Research Evidence v2 verification completed: full locally runnable Python discovery passed 142/142; `compileall`, architecture-boundary verifier, CRLF-aware `git diff --check`, and the 145-row/145-unique/13-column/zero-generic-status trace check passed. Two PyYAML-dependent modules and all Swift/XCTest/iOS build gates remain unavailable in this host.
- Follow-up provenance review added optional `strategyVersion` to the NAS Research Evidence v2 payload and content digest. Missing version remains explicitly `Unavailable` in the iPhone summary; methodologyVersion is not presented as a released strategy. Recomputed the cross-language fixture digest and added an XCTest asserting strategyVersion changes the digest. All locally runnable Python tests pass 142/142; compileall and architecture-boundary verification pass. The new XCTest remains unexecuted without Apple tooling, and NAS/iPhone integration remains unverified. No commit or push was made.
- Realtime trigger boundary audit found `approachDistance` accepted values >=1 and multiplied high finite Decimal prices by a threshold factor, which can overflow and corrupt proximity classification. It now requires `0 <= approachDistance < 1` and compares finite price ratios; added XCTest definitions for invalid distance and near-maximum Decimal prices, and recorded the still-open Local Quant/strategy selection gap in B-129. Python suite remains 142/142; Swift/XCTest cannot run on this host. No commit or push was made.
- Market Regime replay audit found conflicting bars at the same timestamp were resolved by input order. Conflicting duplicate timestamps are now excluded and force `Data Unreliable`; byte-equivalent duplicates still collapse to one bar. Added regression coverage that reverses the conflicting rows and requires identical factors plus a blocked T-buy state. Updated B-011; XCTest is defined but cannot be executed without Swift/Xcode. No commit or push was made.
- Cross-index risk review found the engine counted individually fresh benchmark declines as synchronous even when their observation times were 25 hours apart. Multi-market confirmation now requires the latest qualified observations to fit within an 18-hour span; otherwise the combined benchmark factor is unavailable. Added aligned/unaligned observation regressions and updated B-011. XCTest remains unexecuted without Swift/Xcode; no commit or push was made.
- Follow-up MA review found `FDailyKlineSnapshot.movingAverage` still summed finite `Decimal` closes before dividing, although the chart-model implementation had already been hardened. It now divides each close before accumulation and returns unavailable on a non-finite result. Added a maximum-finite-price XCTest and updated B-058; Apple execution remains pending. No commit or push was made.
- Persisted Regime memory review found public memory values could contain overflowing/negative confirmation counters or non-finite timestamps, leading to arithmetic traps or corrupted hysteresis. The evaluator now validates persisted memory invariants before using it; malformed state is ignored for transitions and marks the assessment `Data Unreliable`. Added XCTest coverage for Int.max counters, negative counters and infinite time. Updated B-011; XCTest cannot run without Swift/Xcode. No commit or push was made.
- Ledger-to-Advisor arithmetic review found individually finite daily buy/sell fees could overflow when combined, and per-security finite realized P&L could overflow when summed for the portfolio. Daily summaries now reject unrepresentable total fees; a shared portfolio aggregator returns unavailable on overflow and is used consistently by DecisionContext and Advisor entries. Added XCTest cases for both boundaries and updated B-010/B-018. Swift tests remain unexecuted without Apple tooling; no commit or push was made.
- Read-only ledger projection audit found cumulative realized P&L and cash-flow projection fields were not checked before publishing a snapshot. Snapshot construction now rejects unrepresentable history or cash-flow totals with explicit errors rather than exposing infinite/NaN amounts. Added a valid high-turnover ledger regression whose per-event balances remain finite while lifetime realized P&L exceeds Decimal range. Updated B-018; XCTest remains unexecuted without Apple tooling. No commit or push was made.
- Advisor P&L composition audit found current/lifetime total P&L added individually finite realized and unrealized values directly; a range overflow invalidated the entire DecisionContext. These optional aggregate fields now become unavailable on overflow, while other valid Advisor facts remain usable. Added FCore-boundary XCTest definitions for finite, overflowing and non-finite aggregation; Apple tests remain unexecuted. No commit or push was made.
- Added a Python source-contract regression to ensure both Ledger Snapshot and Advisor P&L overflow gates remain wired; the locally runnable Python suite is now 143/143 passing. `compileall`, architecture boundaries, trace structure and CRLF-aware diff checks pass. Swift/XCTest execution remains unavailable because the host has no Swift/Xcode toolchain. No commit or push was made.
- Follow-up Decimal boundary review found approach-distance division and Candidate Shadow chase/return calculations could exceed Decimal range for finite accepted inputs. The realtime trigger now fails closed to `waiting` if the approach ratio is unrepresentable; Shadow scorecard leaves lifecycle status intact when a chase threshold overflows and omits an unrepresentable return statistic. Added regressions for the overflow and normal sell-left-zone paths; updated B-129. Python suite remains 143/143 and architecture checks pass. Swift/XCTest is still unavailable here; no commit or push was made.
- Ledger cost-allocation review found `totalBookCost * unitsSold / totalUnits` could overflow in the intermediate product even when the final partial-sale basis was representable. Allocation now computes a bounded share first, then applies it to total cost; added a near-maximum Decimal/Int64 regression and updated B-018. Swift/XCTest remains unexecuted without Apple tooling; no commit or push was made.
- Market Regime numeric-quality review found finite positive closes could still make core return/volatility calculations overflow while the input was marked reliable. Core technical factors are now required for a reliable classification, and moving averages divide observations before summing. Added regressions for an extreme finite price span and a large constant series; updated B-011. Swift/XCTest remains unexecuted without Apple tooling; no commit or push was made.
- Added two host-runnable source-contract checks for the Market Regime numeric fail-closed behavior. The locally runnable Python suite now passes 145/145; `compileall`, architecture boundaries, trace structure, and changed-file whitespace checks pass. Apple XCTest/iOS build remain unavailable on this host; no commit or push was made.
- Research Evidence contract review found Python coercing booleans, floats, and numeric strings into sample/quality integers, and neither side checked that eligible research days fit complete-session coverage. The NAS envelope now enforces exact input types, canonical dates, nonblank coverage keys, and eligible-days <= complete; iPhone validation enforces the same count relationship. Added server and Swift regressions plus a local source-contract check. Full Python suite: 147/147; compileall, architecture boundaries, trace structure, and changed-file whitespace checks pass. Swift/XCTest remains unexecuted on this host; no commit or push was made.
- Cross-language digest review reproduced different NAS/iPhone millisecond normalization for exact half-millisecond timestamps (Python ties-to-even versus Swift ties-away-from-zero). NAS now performs exact integer microsecond rounding using ties-away-from-zero; added positive/negative rounding tests and a fixed shared digest vector for Python and Swift. Full Python suite: 149/149; compileall, architecture boundaries, trace structure, and changed-file whitespace checks pass. Swift/XCTest remains unexecuted here; no commit or push was made.
- Index archive freshness review found missing/corrupt fetch metadata could be treated as available; an error on an archive with rows but no metadata even recorded the current time as a successful fetch. The archive now treats absent/invalid timestamps as stale, safely parses metadata, and records an empty successful-fetch marker instead of inventing a fresh time. Added regression coverage for missing, empty, and malformed timestamps; targeted index suite passes 11/11. Full Python suite: 150/150; compileall, architecture boundaries, trace structure, and changed-file whitespace checks pass. No commit or push was made.
- Research timezone audit found a qualified Research Evidence envelope could omit the calendar timezone or provide a blank/unknown identifier, even though eligible trading days depend on that timezone. NAS now requires a valid IANA zone when supplied and requires one for any eligible sample; iPhone applies the same validity/required-field checks. Added Python and Swift regressions plus a source-contract check. Full Python suite: 150/150; compileall, architecture boundaries, trace structure, and changed-file whitespace checks pass. Swift/XCTest remains unavailable here; no commit or push was made.
- Runtime lifecycle audit found `/readyz` returned only the last completed worker cycle, so a stopped or unexpectedly exited worker could still look successful; calendar sync exceptions also escaped the thread and left stale status. Health output now pairs cycle outcome with `workerState` (`running`, `stopping`, `stopped`, `exited`, or `not_started`), calendar sync failures are recorded with a bounded error summary and a weekly retry, and starting while an old worker thread is still alive now raises instead of silently returning. An unconfigured calendar worker is explicitly `not_configured`. Added runtime regression tests and updated B-006. All host-runnable non-YAML Python modules pass (154 tests); `compileall`, architecture boundaries, 145-row trace structure, and scoped whitespace checks pass. Full discovery is blocked only because PyYAML is absent for two YAML-dependent test modules. Swift/XCTest and NAS deployment behavior remain unverified; no commit or push was made.
- iPhone live-quote concurrency audit found `refreshMarketData` returned immediately for securities already in flight. An Advisor request could therefore read an older cached quote while a UI refresh was still fetching; this failed closed later but caused avoidable inconsistent analysis. Refresh calls now share and await one per-security task. A response older than the cached quote is no longer appended to the Candidate Shadow market journal. Added a host-runnable source contract and updated B-007/B-008. Python source-contract regression passes; Swift build/XCTest and device interleaving behavior remain unverified. No commit or push was made.
- Local Quant safety audit found the “Local Quant absent” asset-change veto existed only in the App's `runAdvisorQuestion` wrapper. Direct callers of the shared `FDecisionGuards`/`FRiskGuard` could omit that wrapper and pass a buy with only a fresh quote. Risk Guard now independently requires fresh, cited, security-specific strategy qualification evidence with a strategy ID/version; absent, stale, mismatched, or uncited qualification fails closed. Removed the duplicate App-only veto and added XCTest definitions for missing/stale/uncited/qualified evidence; the optional-NAS buy and qualified day-trade fixtures now supply a separate local strategy qualification. Updated B-019/B-145. Python contract checks are runnable; XCTest cannot run on this Windows host, so do not claim compilation or Apple execution. No commit or push was made.
- Chart arithmetic audit found the app chart duplicated daily MA calculation with sum-then-divide, while its FCore chart model and daily snapshot had already been changed to divide-then-sum. At extreme finite closes the duplicate UI path could overflow even when the FCore path returned a valid average. Added shared `FDailyMovingAverage`, routed all three calculations through it, and added an app-source contract that prevents the UI path from reintroducing sum-first logic. The existing FCore maximum-finite regression now exercises the shared helper; updated B-058. Latest host-runnable non-YAML Python suite passes 155/155, `compileall`, architecture boundaries, trace structure and scoped whitespace checks pass; Swift/XCTest and chart rendering remain unverified. No commit or push was made.
- B-083 follow-up found NAS Research summaries were cached only by security code. After changing the configured NAS endpoint, a fresh old-server summary could still enter Advisor context, and an in-flight old response could repopulate it. The cache now uses a normalized endpoint key and generation; endpoint changes clear summaries, context capture rechecks the generation, and old in-flight results are discarded. Added a source contract. Apple compilation and a delayed-response endpoint-switch test remain unverified. No commit or push was made.
- Expanded the B-083 endpoint-isolation fix after finding the same stale-source risk in NAS security daily K, archived minutes and index/security Regime. NAS address changes now invalidate all in-memory NAS-derived snapshots and Regime memory; security history and minute-history responses check the source generation before publishing; index Regime responses are discarded and retried after a source change; persisted Regime memory keys are SHA-256 namespaced by normalized endpoint. Settings text edits invalidate the old source immediately; same-source concurrent daily-K/minute-history reads also reject a response whose fetch time predates the cached response. Added source-contract assertions for each read path and out-of-order response guard. iOS compilation and delayed endpoint-switch runtime acceptance remain unavailable here. No commit or push was made.
- B-009 live quote review found Tencent ETF reference parsing accepted provider timestamps up to 60 seconds in the future, and chart freshness treated negative age as fresh; Naver/KOSPI used the same future-time tolerance. Tightened all to observedAt <= fetchedAt/now, added ordered finite reference-time validation, and require nonnegative age <= 15 minutes before labeling IOPV/premium fresh. Also corrected the Eastmoney fallback source label. Added source-contract coverage. Provider behavior and iOS build remain unverified without network/device and Apple tooling. No commit or push was made.
- B-009 follow-up found cached live minute charts reported Complete during lunch, pre-open and after close; the freshness label also clamped negative age to zero. The chart now marks non-continuous sessions stale, unknown calendars partial, and future/unverified capture time stale; the UI returns an explicit unverified/future label instead of 0 seconds ago. Added source-contract coverage. Simulator screenshots and Swift execution remain pending. No commit or push was made.
- Session-chain check found the app's foreground activation path always called autoRefreshMarketData() once before entering the already-gated 10-second loop; the function itself had no session guard. It now exits unless the reviewed mainland calendar says .continuous, so opening/resuming outside the verified session cannot trigger automatic quote requests. Manual refresh remains available and displays explicit session/freshness state. Added a source-contract regression and updated B-009. Simulator/provider verification is pending. No commit or push was made.
- Local Quant MVP audit found the app had no deterministic factor-observation layer beyond price-zone monitoring. Added `FLocalQuantEngine` in FCore with eight explicit factor observations, three MVP strategy readiness states, exact per-security Regime matching, 120-second/continuous-session gates, and a 180-second maximum gap for short-horizon samples. It never emits candidate prices, quantities, or qualification; absent NAS-validated parameters it remains `NO_TRADE`. Added Swift regression definitions and host-runnable source-contract checks; updated B-129 and the architecture status. App/Advisor/Risk Guard wiring, NAS research qualification, Apple compilation and XCTest execution remain open. No commit or push was made.
- Local Quant integration audit found that new factor measurements were not part of the Advisor request despite being available in FCore. `runAdvisorQuestion` now captures an observation-only Local Quant summary in the same DecisionContext, including factor values/scores/reasons, quote time/freshness, Regime, allowed-strategy readiness and candidatePlanGenerated=false. It only uses an already-cached IOPV if fresh; NAS Research refresh remains an unawaited Task. The prompt identifies these as descriptive measurements rather than probability or qualification evidence. Added source-contract assertions and updated B-044/B-045/B-129/B-145 and the architecture notes. App compilation, request serialization and live Advisor behavior remain unverified; no commit or push was made.
- Security Daily P&L integration audit found the formula and scenario tests existed but DecisionContext always returned nil and both Home and detail UI hardcoded Unavailable. Added a 15-minute, same-China-trading-date `previousClose` observation; derive opening units from Ledger end units and the exact-day confirmed buy/sell summary using overflow-checked integer arithmetic; calculate only with fresh synchronized price/reference evidence; and recompute the serialized P&L during DecisionContext validation to reject tampering. The app now supplies the provider reference, and Home/Instrument views refresh the displayed amount/fallback every 15 seconds. Added regressions for populated and no-trade calculations, stale reference, impossible quantities and tampered context plus a source-contract. Updated B-018 and the acceptance matrix. Swift tests, iOS build, live provider date alignment and device UI remain unverified; no commit or push was made.

### 2026-11-01 — Nikkei historical Regime source

- Added NAS routing to the official Nikkei Indexes daily close CSV. The parser accepts ISO or slash-separated dates, quoted thousands separators, ignores current-session/missing rows, and emits close-only daily records. It never fabricates OHLCV.
- Made the SQLite archive migrate existing NOT NULL OHLCV columns to nullable columns while preserving prior rows. Per-index provider attribution now records the actual Nikkei or Tencent source.
- Added the Nikkei code/timezone to the iPhone NAS history reader and historical Regime fanout. The decoder validates close-only shape or complete OHLCV and rejects mixed/partial OHLCV.
- KOSPI remains unavailable because the package has no KRX adapter or credential wiring; formal API approval alone is not sufficient. Nikkei publisher terms limit the feed to personal use absent authorization.
- Added regression definitions for CSV parsing, archive provenance/nullable fields, legacy DB migration, readiness status, and source wiring. This host cannot run Python tests or Apple builds; these remain pending. No commit or push was made.

## 2026-11-01 Local Quant Regime observation time validation

- Local Quant previously trusted `FMarketRegimeMemory.lastEvaluationAt` freshness without requiring the assessment's actual `dataAsOf`. A malformed or manually constructed Range assessment could therefore be treated as available while its evidence time was absent, future, or stale.
- Local Quant now requires nonmissing finite `dataAsOf`, no later than both the memory evaluation and current time, within five days, and a confidence score from 0 through 100. Invalid assessments become `security_regime_unavailable`; no candidate or strategy qualification is granted.
- Added XCTest definitions for missing, future, and six-day-old evidence plus a Python source-contract check; updated B-044. Neither suite nor the Apple build ran on this host because no Python/Swift toolchain is available. No commit or push.

### 2026-11-01 Local Quant evidence timestamp regression

- `FLocalQuantEngine.validRegime` previously relied on `memory.lastEvaluationAt` alone. It now requires finite `dataAsOf`, requires it not to exceed the memory timestamp or current time, applies the five-day age limit to the evidence timestamp itself, and validates confidence within 0–100.
- Added a focused XCTest covering missing, future, and six-day-old `dataAsOf`, plus a source-contract regression and B-044 update. Test definitions and iOS compilation remain unexecuted on this Windows host.

### 2026-11-01 Risk Guard Regime timestamp ordering

- Regime evidence parsing already rejected future or stale `dataAsOf` relative to the current evaluation time, but it did not require the claimed data time to be no newer than the observation's own `observedAt` and `capturedAt`.
- The Guard now rejects that internally impossible provenance. Added a regression using a fresh observation whose claimed market data is newer than its evaluation/capture time, and a source-contract check; B-086 now records the rule. Apple/XCTest and Python execution remain unavailable on this host.

### 2026-11-01 Advisor ETF benchmark-context mapping

- Cross-market index Regimes were captured as independent observations only. For the issuer-confirmed Nasdaq-100 ETF 159941, this meant DeepSeek could not reference the corresponding cached Nasdaq-100 Regime while analyzing an actual holding.
- Added a source-backed 159941 → `usNDX` mapping used only for a fresh, timestamp-valid, benchmark-only Advisor observation. Missing or stale NAS Regime stays explicitly unavailable; the prompt requires separate ETF quote, premium/IOPV and liquidity evidence. No mapping enters the ETF's full Regime, Local Quant, Risk Guard or strategy qualification.
- Added a registry XCTest and source-contract assertions; updated B-011, B-047, B-118 and B-141 plus the architecture status and continuation log. Static wiring was manually inspected. Python source-contract and Apple XCTest/build execution remain unavailable on this Windows host; live NAS/iPhone behavior is not verified. No commit or push.

### 2026-11-01 Traceability file-anchor audit

- A mechanical audit of all 145 B requirement rows found five explicit source/test file anchors that did not resolve: four `HomeExperience.swift` / `ThemeLayoutManifest.swift` references omitted the `GuanpanFApp/Sources/` prefix, and the B-144 test reference omitted `Tests/FCoreTests/`.
- Corrected the anchors. Added `Tools/test_traceability_contract.py` to CI-discovered Python tests; it checks contiguous unique B-001…B-145 IDs, 13 table columns, and existence of every explicit source/test file path (including wildcard directory anchors).
- Node cross-check of the current table passed: 145 rows, 13 columns, 725 explicit file anchors, zero missing paths. Python test is defined but not executed because this host's Python launcher is unavailable. No commit or push.

### 2026-11-01 Live-quote source trust audit

- Current FCore treated any nonblank `source` string with a valid timestamp as a fresh quote. The public observation/quote initializers let an unconfigured source pass the shared freshness check; this could feed Advisor, Risk Guard, Local Quant, and RealtimeQuantTrigger. The cross-market board also counted any nonblank source as available.
- Added `FMarketQuoteTrustPolicy` with exact labels for the app's active Tencent/Eastmoney minute sources and Tencent/Sina/Naver index/reference sources. Quote freshness and index availability now require an allowlisted source; a timestamp-valid unknown source remains displayable with an explicit “来源未验证” label and fails closed in decision consumers.
- Provider adapters share the policy constants. Added XCTest definitions for unknown-source Advisor freshness, Local Quant factor suppression and Trigger pause; added a source-contract test. Updated B-009/B-086. Static wiring inspection remains; Python and Swift suites/build are not executable on this host. The source label is an allowlist check, not cryptographic provider authentication. No commit or push.

### 2026-11-01 Archived-bar provenance audit

- NAS historical responses previously accepted any nonblank `source`; Local Quant checked daily-history identity and age but not the upstream provider. An unconfigured source could therefore contribute moving-average/trend factors, and an index response could claim a different provider from its intended market.
- Added market-specific daily provenance checks: security daily bars require the configured Tencent Finance daily K-line source; index histories require Tencent for supported indices and the official Nikkei close CSV only for `int_nikkei`. Local Quant suppresses factors from an untrusted security-history source. Existing OHLCV/range/status checks remain in place.
- Added Local Quant XCTest and a CI source-contract test; updated B-011/B-012/B-044/B-086 traceability and architecture status. Static wiring inspection passes; Python/Swift execution and NAS/iPhone provider behavior are not yet verified. No commit or push.

### 2026-11-01 Research-evidence provenance audit

- Qualified minute-research envelopes previously required only nonblank source labels. That allowed an arbitrary provider name to accompany an otherwise qualified NAS Research Summary into iPhone Advisor context.
- NAS now rejects qualified minute evidence unless every source is one of the configured Tencent Finance or Eastmoney minute providers. iPhone repeats the allowlist check before evidence can validate or become usable for AI. Zero-qualified and separate dividend-quality evidence preserve their existing behavior.
- Added NAS and Swift regression definitions for unknown sources, including a Swift case that recomputes the evidence digest to ensure the rejection is about provenance rather than a stale hash. Updated B-083 traceability.
- Node traceability check passed: 145 contiguous rows, 13 columns, 481 explicit source/test path anchors found and zero missing. `git diff --check` is clean. Python and Apple tests/build have not run on this host; live NAS evidence has not been checked. No commit or push.

### 2026-11-01 Dividend research provenance follow-up

- Review found no production dividend data connector or verified provider registry: only a generic evidence builder and an abstract research-tool provider interface exist. Both NAS envelope creation and iPhone evidence validation previously accepted any nonblank dividend factor source.
- Added explicit dividend source trust policies. The verified provider set is empty until a real provider is connected, so dividend evidence remains unavailable to Advisor instead of being treated as verified. The standalone descriptive factor calculation remains usable for research development.
- Updated Swift and Python regression definitions to reject evidence from the unconfigured provider; updated B-083 traceability. Tests/build remain unexecuted on this Windows host. No commit or push.

### 2026-11-01 News evidence trust audit

- FCore previously allowed any constructed `FNewsFeed` with a recent timestamp to enter the Advisor path. Available `.news` observations also validated without requiring the configured news provider or serialized article evidence.
- Added an exact provider gate in FCore, article HTTPS/time/content checks, duplicate-link suppression, and a DecisionContext gate requiring trusted provider provenance plus the evidence payload for available news. The app's client now uses the shared provider identity. Added a regression for unknown providers and duplicate links; updated B-038/B-039.
- Traceability structure/path check and `git diff --check` are being rerun. Swift/Python execution and live endpoint response validation remain pending. No commit or push.

- Follow-up news checks also cover source identity at the DecisionContext boundary: unknown-provider news cannot become available evidence without a serialized payload. B-038/B-039 now distinguish the core source/freshness regression from still-unverified endpoint parsing and real response behavior.
- Added a DecisionContext regression for trusted-provider/payload requirements and a Python wiring contract; feed tests now use the actual configured provider and reject unknown providers while deduplicating links. Static traceability verifies 145 contiguous rows/13 columns and all explicit file anchors resolve; runtime tests remain pending.

### 2026-11-01 Quote response identity audit

- Tencent `qt.gtimg.cn` security reference and name fetches selected the response body but discarded the response's `v_<symbol>` key. A mismatched body could therefore be labeled as the requested security even when the provider returned a different symbol.
- Added a shared FCore response parser that requires an exact requested-symbol echo, and routed both reference and name parsing through it. Added valid/mismatched symbol XCTest coverage; updated B-009.
- This verifies text-response identity before field use. The real upstream behavior and Apple build remain unverified on this host. No commit or push.

### 2026-11-01 NAS archived-minute provenance audit

- The modern NAS minute reader validated identity, timestamps and coverage but only required each archived bar's source label to be nonblank. A mislabeled or unknown provider could therefore remain in the historical chart, and complete coverage might be presented as complete.
- Added an exact Tencent/Eastmoney archived-minute provider allowlist. Unknown-source bars are discarded; their presence downgrades a reported Complete archive to Partial with an explicit source warning. Added FCore policy XCTest and NAS-reader source-contract coverage; updated B-007.
- Legacy B compatibility remains labeled `legacy-unassessed` and never claims Complete because that endpoint lacks per-bar provenance/fetch time. Real NAS source labels remain to be verified after deployment. No commit or push.

- Final static cross-check after the provenance edits: 145 traceability rows, contiguous B-001…B-145 IDs, 13 columns, and zero missing explicit source/test file anchors. `git diff --check` is clean. Python regression execution is unavailable because `py` is not installed and the WindowsApps `python.exe` cannot start. No commit or push.

### 2026-11-01 Python CI test-discovery audit

- The workflow runs `python -m unittest discover`, but three source-contract files (`test_local_quant_contract.py`, `test_security_daily_pnl_wiring.py`, `test_account_expense_classification.py`) contained only top-level pytest-style functions. Unittest silently imported them without executing those assertions.
- Wrapped those assertions in `unittest.TestCase` methods, renamed helper functions so they are not mistaken for discoverable tests, and added an AST guard that fails if any future `test_*.py` reintroduces top-level `test_` functions. This restores actual CI coverage for Local Quant, daily P&L wiring and account-expense classification.
- Python execution could not be run locally (`py` is unavailable; WindowsApps `python.exe` fails to start). Static source inspection confirms the three files now expose TestCase methods. No commit or push.

### 2026-11-01 Ledger finite-value boundary audit

- The account schema already rejects non-finite persisted state, but several mutation and app-input guards used only `isNaN`. That allowed infinite intermediates to travel farther into arithmetic before eventual validation, and legacy migration relied on the downstream initializer for finiteness.
- Tightened cash movements, fee corrections, broker display cost, fill consideration/debit/credit and cash arithmetic, plus legacy migration inputs, to require finite Decimals at their boundaries. App cash adjustment, fee, fill price and broker-cost text checks now fail early. Added a mutation atomicity XCTest for infinite cash movement and fee correction, plus a user-input wiring contract. Updated B-010.
- Python contracts in three modules were also converted into unittest-discoverable tests; an AST regression prevents top-level pytest-style functions from silently escaping CI. Local Python execution remains unavailable. No commit or push.
- Static follow-up confirms all 23 `Tools/test_*.py` modules contain no top-level `test_` functions that unittest would skip; the workflow-discovery guard covers this invariant. Ledger finite guards have no remaining `isNaN` checks in `Sources/FLedgerWrite` or `GuanpanFApp.swift` write paths. `git diff --check` remains clean.

### 2026-11-01 ETF IOPV decision-context audit

- Fresh Tencent IOPV was used to calculate a Local Quant factor but was not serialized as its own Advisor observation; FRiskGuard therefore could not require a candidate to cite it. IOPV older than 15 minutes could also contribute to the factor.
- Added a same-security IOPV premium observation in percent, accepted only from the configured Tencent reference source, and set its freshness boundary to 90 seconds. FRiskGuard now requires a fresh available IOPV observation to be cited by an asset-changing candidate. Local Quant rejects stale/unknown-source IOPV; added regressions for source, age and citation behavior.
- No premium threshold or order-book liquidity feed is defined/verified, so neither is fabricated: no threshold block is claimed, and liquidity remains unavailable. Runtime XCTest/Apple build still require CI or an Apple host. No commit or push.

### 2026-11-01 本轮可运行验证复核

- 使用仓库的 Python 3.12 运行当前可导入的 `Tools/test_*.py`：243 项通过、0失败。`test_ios_app_structure.py` 与 `test_nas_deployment_package.py` 因本机缺少 PyYAML 无法导入；CI工作流会安装 PyYAML，故这两模块本轮未验证，不能记为通过。
- `python -m compileall -q nas Tools`、架构边界检查、145条B需求编号/锚点检查和 `git diff --check` 通过。
- 本轮复核NAS日K刷新删除逻辑、账本费用更正回放与现金对账、新闻来源门和HTTP API边界；未发现足以证明的新缺陷，因此没有为增加提交数量而制造代码改动。Swift/Xcode/Simulator、NAS实机、外部行情源和真实成交端到端仍需外部环境验收。
- 所有更改仍仅在工作区；本轮没有提交或推送。

### 2026-11-01 首页主题角色顺序验收补强

- 复核发现十主题截图UI测试此前只断言首页导航存在并保存截图，没有断言四个首页角色卡均可访问，也没有验证非星图主题的卡片垂直顺序。
- 为主题首页角色统一增加 `home.role.*` 可访问性标识；星图的组合中心和四个节点也使用同一角色标识。十主题UI回归现在检查四角色存在，并在非星图主题验证“组合→市场→跨市场→顾问”的屏幕Y坐标顺序。星图保留空间节点布局，不套用垂直排序规则。
- 增加Python源码契约测试并更新B-053/B-060/B-104。相关Python契约通过；新增Simulator XCTest尚未执行，现阶段不能宣称十主题视觉验收通过。继续要求Apple UI测试截图与人工视觉复核。无提交/推送。

Validation after theme-role acceptance additions: all 244 locally runnable Python tests passed; the new home-layout source-contract test passed as part of that run. Focused traceability and home-layout tests passed; Python compile, architecture-boundary check, contiguous traceability IDs and `git diff --check` passed. PyYAML test modules and all Apple XCTest/build checks remain as previously recorded, not run.

- 追加复核发现 editorial、dashboard、ink、glass 等主题部分自定义卡绕过通用渲染器，首轮统一标识契约未覆盖 ink 的通用角色调用。已调整契约为同时检查标准角色渲染或自定义标识，并补全 editorial 的四类标识、dashboard/ink/glass 的自定义组合/顾问标识；复跑后当前可运行套件为245项全通过，home-layout与traceability聚焦测试25项通过。仍待Apple XCTest确认SwiftUI/XCUI实际可访问树与坐标断言。

### 2026-11-01 GitHub Actions并发限制

- 用户要求推送后的Actions同时运行数不超过两个。复核发现Python/NAS与iOS工作流此前没有并发控制。
- 两个工作流现分别使用基于workflow名称的仓库级并发组，且不取消已运行构建，因此最多各有一个活动构建、合计最多两个。新增工作流合同测试，CONTINUATION记入此操作红线，B-102追踪行已更新。
- YAML工作流因本机PyYAML缺失无法完整解析；合同测试直接检查工作流文本。GitHub Actions执行仍需后续推送后取证；当前未提交/推送。

Latest verification after the Actions concurrency change: 246 locally importable Python tests passed; 30 focused traceability/home-layout/workflow-contract tests passed. Python compilation, architecture boundary, and diff checks passed. The two PyYAML-dependent modules remain unrun because local package installation cannot reach the configured network proxy; no Apple/Xcode runtime is available.

### 2026-11-01 Ledger确认顺序审计

- 确认FAccountBook的fills、cash movements与fee adjustments共享单调sequence，但解码验证此前没有要求用户确认时点随sequence单调，也没要求`updatedAt`覆盖最后事件确认时点。一个余额完全对账、但序号2确认时间早于序号1的账本可通过验证；后续新增事件也可能早于历史确认时间。
- 新增统一确认事件回放校验：sequence升序的确认时间不可倒退，且account `updatedAt`不早于最后事件确认时间。新增两个现金事件确认时间倒退的LedgerSchema XCTest与Python源码合同；B-018更新。
- 本轮Swift/XCTest未在Windows执行，Python合同待全量复跑；这是已编码未验证，不关闭账本验收。无提交/推送。

Ledger event-order follow-up validation: 247 locally importable Python tests passed, including the new event-confirmation source contract; the 10 focused Security P&L / traceability / CI contract tests passed. Python compileall, architecture boundary and diff checks passed. The Swift regression is defined but not run on Apple toolchain.

- KOSPI history audit: the official KRX Open API does offer KOSPI series daily prices, but the repository contains no KRX adapter, authorization-key injection, runtime route, or trusted iPhone source. Previous wording implied an approved key alone would enable history; corrected `/readyz`, deployment documentation, B-012/B-140 evidence, and regressions to state the actual limitation. Official service requires application and an `AUTH_KEY` request header. This correction does not implement KOSPI collection; pacing, parsing, authorization, packaging, and real-data validation remain open. Python/source checks recorded separately; no commit or push.
- KOSPI history API consistency: readiness classified KOSPI as a known unavailable market, but the direct history endpoint rejected it as an unknown input with HTTP 400. The archive now returns a structured `unavailable` response for the known KOSPI code without calling a fallback provider; genuinely unknown codes still return 400. Added API and archive regressions. This improves state reporting only; it does not implement the KRX collector or make the KOSPI history/Regime available.
- KRX collector design evidence: the official KOSPI daily API accepts a single `basDd` date per request and requires an authorized `AUTH_KEY`; therefore rebuilding 60+ sessions synchronously inside an iPhone history request would risk repeating many network calls and recreating the NAS timeout problem. Any KRX implementation must use a rate-bounded background/incremental collector, persist progress by date, and expose `insufficient` until complete-session coverage meets the Regime minimum. This remains an implementation requirement, not a completed feature. [KRX KOSPI API specification](https://openapi.krx.co.kr/contents/OPP/USES/service/OPPUSES001_S2.cmd?BO_ID=EREKZauXnMmxyIlqzeDN)
- Local Quant factor provenance audit: the eight-factor payload passed factor values but omitted each factor's own source and observation time. In addition, the pure-daily `movingAverageStructure` had been stamped with the live quote timestamp, and the mixed live-price/daily-history `trendStructure` named only the daily source. Factor observations now preserve per-measurement source and observedAt; Trend Structure carries its latest completed daily-bar date and both input sources, while MA Structure uses its actual last daily-bar time. The Advisor context now serializes those provenance fields. Added XCTest and source-contract regression; XCTest is not executable on this Windows host. No commit/push.
- Quant qualification authorization audit: `FRiskGuard` requires a runtime-only grant in addition to a qualified-looking observation, and JSON decoding strips grants, but there was no contract preventing future production code from calling the generic observation/grant constructors without a verified NAS package. Confirmed no current production issuer exists; added a source contract that forbids production calls until the strategy package verifier is implemented, while retaining the XCTest that proves decoded contexts lose the grant. This preserves fail-closed behavior; it does not complete NAS qualification. Local Quant/Advisor/trace suite 34/34 passes; Swift/XCTest remains unexecuted here. No commit/push.
- News security-code audit: the public-feed parser and FCore freshness gate used Unicode `isNumber` for related security codes, which admits non-ASCII numerals that cannot identify the six-digit market instruments used by Ledger/quotes. Both boundaries now require exactly six ASCII digits (the provider's short codes are zero-padded only after the ASCII check). Added FCore XCTest and source contract; real feed and Swift execution remain pending. No commit/push.
- News parser acceptance audit: production parsing was embedded in the app client, leaving no deterministic raw-response unit coverage. Extracted the bounded Tonghuashun response parser into FCore and kept the app client as HTTP transport/error mapping. Parser and `recent` consumption both now require HTTPS URLs with a nonempty host and no URL credentials. Added XCTest coverage for seconds/milliseconds timestamps, 24-hour/future filtering, deduplication, security-code normalization, credential/insecure links, 40-item cap, oversized body, and malformed schema. Swift/XCTest and the live endpoint remain unverified; source contracts pass. No commit/push.

- Market Regime evidence provenance audit: public input objects previously let any nonblank `source` string on breadth/benchmark observations contribute to risk classification, and an index could be counted as its own benchmark. Added exact market-to-provider benchmark trust, excluded self-benchmark observations, and fail-closed breadth until a verified production breadth provider exists. Added XCTest definitions and Python source-contract coverage. Production cross-index observation wiring still has no call site; the feature remains unavailable until verified observations are actually supplied. Apple tests/build remain unexecuted here; no commit or push.

- Daily Regime source audit: the engine previously treated any nonblank `FMarketRegimeInput.source` as trusted, so a caller could attach arbitrary bars with `source=fixture` and receive a decision-grade regime. It now requires the exact configured Tencent daily source for supported Tencent markets/securities and the official Nikkei close-only source for Japan; unknown market/source pairs and unsupported indices such as KOSPI fail closed. Added XCTest and Python source-contract coverage. This is source-label allowlisting, not cryptographic provider authentication; Apple tests/build remain pending. No commit/push.

- Multi-index Regime wiring follow-up: previously no production call passed benchmark observations. NAS index daily fetch now preserves all completed, source-validated archives, derives each peer index one-session close return, and supplies it to each index Regime with the peer source, bar timestamp, and NAS capture time. Core market allowlists and 18-hour synchronization remain the final gates; KOSPI has no history and cannot contribute. Added a wiring contract. iOS execution and real cross-market samples/device validation remain pending; no commit/push.

- Cross-index period-alignment audit: comparing only peer close timestamps could treat two markets as synchronized even when one return covered a different holiday/session interval. `FMarketRegimeBenchmarkObservation` now carries optional `sessionStartAt`; legacy or missing interval starts fail closed. The engine checks both peer observation-time and return-window-start alignment, then aligns peer starts to the target index bars before counting risk. Added XCTest and source wiring checks. Apple execution and holiday-calendar/device validation remain pending; no commit/push.

- Legacy benchmark compatibility check: older serialized benchmark observations may lack the new return interval start. They remain decodable but do not influence risk classification; added a regression ensuring the missing interval fails closed.
- 2026-11-01 Shadow Scorecard分母/覆盖口径复核：此前只要过期前有任意一条新鲜行情，就会把Candidate计入`notTriggered`；触发后观察窗只检查截止时间和存在行情，稀疏数据仍可能标为完成；没有触发价/区间的WAIT也可能进入未触发统计，稀疏采样下的MFE/MAE也会低估真实窗口极值。现要求具备明确触发条件，且窗口两端和相邻采样间隔均在最大行情年龄内；结束但覆盖不足的触发窗口显示`insufficientData`，无价格条件WAIT不计未触发，MFE/MAE仅在完整覆盖时提供。增加稀疏及WAIT回归，更新B-091。Python源码合同3/3、全量可导入Python用例254项通过，另两模块因缺PyYAML导入失败；299项FCore XCTest尚未在Apple工具链运行。无提交/推送。
- 2026-11-01 Shadow行情证据复核：观察构造器此前允许任意非空来源；评分只检查时间差，未在触发与样本计数路径重新验证来源，因此伪造来源可污染触发和结果。现构造时要求行情来源位于共享可信清单，评分/观察窗仅使用重新验证为可信、价格有限为正且满足快照年龄上限的报价，归档解码校验同时复算`isFresh`并拒绝伪造源。新增未知来源、解码后篡改归档回归及Python源码契约；Shadow契约5/5通过、`git diff --check`通过。Swift XCTest仍未在Apple工具链执行；无提交/推送。
- 本轮审计验证：Python全集发现276项，274项通过，2个模块因环境缺少PyYAML而无法导入（iOS结构与NAS部署包）；本次Ledger mutation/Shadow/追溯合同11/11、`compileall`、架构边界和`git diff --check`通过，317项FCore XCTest定义尚未由Swift/Xcode执行。未提交/推送。
- 2026-11-01 账本并发写入审计（B-027/B-145）：写入器原先分开await读取AccountBook与Archive Digest，actor可在两次读取之间重入；若另一写入先提交，旧AccountBook可能与新Digest配对，乐观写入将覆盖并发更新。现加入单次读取验证Archive并同时返回AccountBook、Ledger Digest和Archive Content Digest，四类更新均以同一Archive Digest保存；Candidate成交再比对分析时Ledger Digest，变化即拒绝。新增旧Candidate拒绝Swift XCTest与3项源码合同，Advisor/P&L/账本并发合同32/32通过；当前Swift XCTest仍未在Apple工具链执行。未提交/推送。
- 2026-11-01 Local Quant触发时序复核：有效期开始前的可信行情若在`validFrom`后仍新鲜，原逻辑可能把计划生效前的价格误当作生效后的触发。现拒绝quoteTimestamp早于计划有效时点的观测并暂停本轮触发，增加Swift回归和源码合同，更新B-145。完整Python发现255项运行（两模块因缺PyYAML导入失败），300项FCore XCTest仍未在Apple工具链执行。无提交/推送。
- 2026-11-01 行情缓存顺序复核：缓存保存曾优先使用HTTP抓取时间，导致较晚抓取的旧交易所行情可覆盖较新的缓存；启动恢复只比较抓取时间，亦可能用旧行情覆盖当前内存快照。现以交易所行情时间为主序、抓取时间为同点次序，且持久化与恢复使用相同规则。新增延迟旧报价 XCTest、更新B-008与缓存源码契约。聚焦缓存/追溯5/5通过；全量Python发现255项运行、两项PyYAML模块无法导入；301项FCore XCTest未能在Apple工具链执行。无提交/推送。
- 2026-11-01 初始持仓日盈亏审计：录入表单把当前持仓作为“今天的账本起点”，实际是在用户点击保存时建立。如果有持仓的开账快照在交易日开盘后建立，既无开盘前份额基准也无导入前成交流水，先前却会把它当全天日初份额计算证券日总盈亏。只读Ledger快照现传递开账时点和初始证券代码，FCore门控仅允许开盘前快照或非初始、由当天确认成交重建的证券计算当日日总盈亏；开盘后导入的初始持仓当日显示Unavailable，下一交易日恢复。App与Advisor共用门控，更新B-018并新增回归。Swift测试未执行，本地Windows缺少Apple工具链；无提交/推送。
- 2026-11-01 日盈亏兼容性复审：旧版序列化DecisionContext没有初始Ledger快照时点，缺失元数据曾按“没有初始持仓”放行，可能让旧快照中的证券日盈亏绕过新门控。现在旧上下文仍可解码，但缺开账时点时派生日盈亏不可用，原先带非空日盈亏的上下文在校验时被拒绝；新增回归和Python源码合同。Swift XCTest未执行；无提交/推送。
- 初始持仓日盈亏修复后验证：日盈亏、Advisor安全与追溯契约28/28通过；完整Python发现255项运行、两项PyYAML模块导入失败。Python compileall、架构边界与diff检查通过。302项FCore XCTest未在Apple工具链执行。

- News transport audit: parser-level size rejection alone did not cap memory used by the app's one-shot URLSession download. Replaced it with a bounded streaming read, checking Content-Length when provided and stopping on the first byte beyond the 1MB limit. This is now covered by a source contract and traced under B-038; Swift API availability/compile and live endpoint behavior remain pending Apple/network verification.

- Daily history freshness audit: fetch-time freshness alone did not prove the newest daily bar itself was recent. NAS archive/readiness/status now check the last actual completed trading date (five-calendar-day bound); the iPhone security-daily reader and Local Quant reject old or future last bars. Added a stale-bar-with-fresh-fetch NAS regression and an FCore Local Quant XCTest definition; B-138 records this boundary. Python acceptance passed; Swift and real NAS/iPhone behavior still require external execution.

- Freshness boundary follow-up: added explicit five-day inclusive boundary coverage in NAS Python and Local Quant XCTest definitions, with the prior test covering data older than five days. B-138 now points to both positive and negative cases. Python focused set passes 82/82; Swift remains unexecuted.

- News empty-response cache audit: HTTP success with no valid recent articles previously replaced the still-fresh in-memory cache. FCore now preserves the existing cache unless the response has usable recent articles, while all Advisor use continues through the regular freshness/provider gate. UI status explains retained cache use. Added deterministic cache-policy XCTest and source contract; B-038 trace updated. Swift execution/live source remain pending.

- NAS HTTP response-size audit: the five iOS NAS routes previously used one-shot `data(for:)`, leaving readiness/history bodies unbounded until decode. Added a shared 4MB streaming cap with early Content-Length rejection and stop-on-overflow behavior; traced in B-038/B-138 with a regression covering every NAS call site. Apple compile and live NAS responses remain pending.

- 2026-11-01 Candidate Shadow成交关联复核：成交关联此前只校验UUID唯一性，调用者可以把随机UUID和任意时间写成“确认成交”，且测试曾把这种行为当作通过。现在所有追加入口都要求提供只读Ledger快照，并核对Ledger账户ID、fill ID、成交时间（不得晚于快照时点）、证券代码、买卖方向和完整成交份额；只读投影不暴露价格、手续费或确认备注。补充随机ID、时间偏差、未来成交时点、份额不符、跨账户/证券/方向和有效成交回归及Python源码合同。旧Shadow归档仍可解码，但缺少账户ID的旧记录不可追加Fill；当前没有App生产调用方，真实成交关联流程尚未接通。Shadow源码合同4/4通过；Swift/XCTest未执行，无提交/推送。
- 2026-11-01 B-030决策变化解释复核：DecisionMemory此前没有冻结原请求scope，证券级与组合级记忆可能混入对照。新记录现在保留请求scope，投影只纳入同scope记录；Advisor系统提示要求对比历史/当前结论与证据差异，无同范围历史项时明确不可比，且不把时间先后说成因果或把旧证据当当前事实。新增scope过滤XCTest定义和安全源码合同；尚无确定性差异引擎/专用UI，真实模型输出未验证。
- 2026-11-01 B-036画像顾问边界复核：`profileUseConstraint`此前仅作为request计算属性存在，DeepSeek系统提示未实际附加该约束；响应JSON也没有画像revision引用字段，因此Candidate/DecisionMemory无法验证模型引用。现将画像作为不可信用户偏好数据的约束实际附加到system prompt，扩展响应格式读取`citedInvestorProfileRevisionIDs`，只允许引用本次投影ID并交由Guard二次验证；未知、重复或越界引用拒绝。补充Guard XCTest断言和Advisor源码合同。真实DeepSeek输出、Apple编译及设备路径未验证。

- 2026-11-01 B-032画像投影失效复核：Advisor画像投影先前没有携带temporary revision的expiresAt，因而解码后的投影无法验证临时偏好在as-of时点仍有效。投影现保留expiresAt，并在point-of-use拒绝source与expiry字段不匹配、已到期或非有限时点；新增解码后篡改为已过期的FCore XCTest定义与源码合同。原始B-034完整字段清单不在项目sources只读快照或当前输出矩阵可定位范围内，八个现有字段不能据此认定完整；未推断缺失字段。

- 2026-11-01 跨市场指数时点解析审计（B-012/B-136）：`FMarketIndexTimestamp.parse`原先过滤任意字符串中的所有数字；畸形payload例如前缀带无关文字仍可能被拼成合法交易所时点。现要求输入整体严格为12或14位ASCII数字，新增混字、格式符及全角数字拒绝用例，并在B-012/B-136更新证据。市场Regime与指数映射当前仍将日经/韩国历史数据缺口显式标Unavailable，B-136全市场UTC归一与DST回放仍未完成。跨市场Regime/指数历史/API源码合同34/34通过；最新全量Python发现272项，其中270通过、2项因缺PyYAML导入失败；Swift/XCTest未执行。

- 2026-11-01 Market Regime严重风险门控复核（B-011）：确认的Bull/Range标签可能因Regime变更确认滞后而与已确认R3风险并存；原`allowedStrategies`只封锁R4，Local Quant对证券自身Regime也只看策略白名单。现在核心R3/R4均返回空策略集，Local Quant另行拒绝证券自身R3+风险，即使缓存标签仍是Bull；新增市场引擎与Local Quant XCTest及两个Python源码合同。Market Regime/Local Quant/Advisor/追踪合同50/50通过，Swift/XCTest未执行。

- 2026-11-01 B-018日盈亏/做T口径源码续审：重新核对`LedgerSnapshot`的有效手续费投影、Asia/Shanghai当日成交汇总、已实现卖出盈亏、Security Daily P&L期初/期末份额与成交额公式，以及T cycle配对。当前代码没有发现账户级费用混入证券损益、成交费用重复扣除或未配对T卖出被报为完整收益的路径；未配对结果保持Unavailable。此为源码审阅结论，不代表Apple XCTest执行或券商实账对账，也未改业务代码。

- 2026-11-01 复核外部完整追溯审计中的旧B-011发现：审计指出 main `0296013` 的证券Regime调用使用`previous=nil`且未进入DecisionContext。当前dirty工作树已从按NAS端点/证券键控的内存或UserDefaults恢复历史状态、传入引擎并在可靠时保存；Advisor对证券scope构造同证券Regime观察并加入唯一DecisionContext。补充Python接线合同覆盖恢复/保存/Advisor注入；该旧缺陷在当前源码中已修复，仍需Apple CI和真实设备跨日回放验收。

- 2026-11-01 B-011 Regime时间输入边界复核：公开引擎曾允许负无穷bar时间戳通过`timestamp <= asOf/now`并进入历史价格序列；现显式拒绝任何非有限时间戳，并令整次分类Data Unreliable，策略权限清空。新增XCTest与Python源码合同；Regime/追踪/Local Quant合同本轮聚焦26/26通过，Swift未执行。

- 2026-11-01 iOS实时分钟时段复核：Tencent和Eastmoney回包此前允许当日午休、收盘后的分钟点混入图表与量化输入；现校验每个样本点处于大陆连续交易时段，开盘竞价仍独立排除。新增午休/盘后剔除并保留11:30、13:00边界的XCTest，以及来源接线合同。尚需在Apple工具链执行XCTest；本地继续跑Python合同与代码静态检查。未提交/推送。

- 实时分钟时段回归结果：MarketBarTrust与traceability源码合同7/7通过；compileall -q Tools nas与git diff --check通过。全量Python发现291项，289通过、2项因本机缺PyYAML导入失败；本机无Swift/Xcode/XcodeGen，新增Swift XCTest未执行。

- Local Quant VWAP integration audit: changed the all-samples-volume requirement to tolerate the parser's intentionally unknown first delta only when ≥20 session samples and ≥90% known-volume coverage are present. Unknown observations are excluded; poor coverage/zero volume stays unavailable. Added partial/poor coverage XCTest and host contract, updated B-010. Apple XCTest unavailable locally; no commit/push.

- VWAP覆盖率修正验证：LocalQuant、market bar trust和traceability合同17/17通过；全量Python discovery 292项，290通过，两个PyYAML依赖模块无法导入；compileall与diff check通过。FCore XCTest定义327项，未在当前Windows主机执行。无提交/推送。

- RealtimeTrigger now validates both Regime evidence time and hysteresis-memory evaluation time: finite, evidence time ≤ memory time ≤ now, each at most five days old; confidence must be within 0…100. Previously a future/inconsistent memory timestamp could pass while dataAsOf appeared fresh. Added regression and B-086 trace update. Market Regime/Local Quant/traceability contracts 28/28 passed; architecture boundary and diff checks passed. Apple XCTest unavailable; no commit/push.

- RealtimeTrigger Regime chronology gate now validates both evidence and hysteresis-memory evaluation times: finite, dataAsOf ≤ memory time ≤ now, each at most five days old, with confidence in 0…100. Added regression and B-086 trace update. Market Regime/Local Quant/traceability contracts 28/28 passed; architecture boundary and diff checks passed. Apple XCTest remains unavailable locally. No commit/push.

- Daily summary decode identity audit: FDailyTradeSummary.isValid previously accepted any nonblank, trimmed security code, unlike the ledger's six-ASCII-digit identity rule. A tampered decoded summary could therefore be included in daily realized P&L aggregation. Validation now requires exactly six ASCII digits; added decoded short/fullwidth/alpha regressions and updated B-018. Focused daily P&L/traceability source contracts 6/6 pass. Swift XCTest unavailable locally; no commit/push.
## 2026-11-01 腾讯实时分钟累计成交量断档

- 逐行复核实时分钟解析器发现，累计成交量字段缺失或非法时，解析器将该分钟量标为未知，却保留了上一条有效累计量基准。下一条可读累计量因此产生跨多个分钟的差值，并被误当成单分钟成交量，可能污染VWAP和量能异常观察。
- 缺失/非法累计量现在会清空差分基准；恢复后的第一条有效累计量只建立基准并保持该分钟量未知，下一条才恢复单分钟差值。累计量回退行为保持原有“该点未知并重建基准”规则。
- 新增 `testMissingCumulativeVolumeBreaksDeltaContinuity`，并把回归锚点补入 B-007。聚焦Python合同37/37、`compileall`、架构边界及`git diff --check`通过；本机没有Swift/Xcode，XCTest没有执行。完整Python重跑因Windows回环套接字访问错误中断；最近一次完整发现293项、291通过、2项因缺PyYAML导入失败。未提交/推送。
## 2026-11-01 Security Daily P&L前收来源未受限

- B-018复核发现，`previousClose`观察虽有15分钟新鲜度和证券/日期一致性门槛，但DecisionContext此前接受任意非空来源标签；这会让未经核验的前收数值参与证券日盈亏公式。
- 新增精确Tencent参考行情来源策略，并在观察验证和日盈亏取值两处同时校验；非可信来源不能生成日PnL，也不能通过DecisionContext验证。LedgerSchema XCTest增加伪造来源反例，B-018追踪更新。
- Security Daily P&L、Advisor安全及追踪合同33/33通过，Python编译通过。Swift/XCTest未在本机执行；无提交/推送。

## 2026-11-01 后续全盘审计

- 复核多市场指数日K provider/NAS API/Regime接线、首页与持仓录入、CI触发与并发。未发现本轮可确认的新产品缺陷；KOSPI实时行情已接入，历史KOSPI因KRX适配器/授权缺失明确Unavailable。
- 指数/Regime/Advisor聚焦回归90/90通过；首页、账户费用、PnL、行情缓存、追踪及CI合同47/47通过。Windows默认临时目录拒绝SQLite文件后，将测试临时目录指向工作区并通过。
- Swift/Xcode/XCTest/Simulator仍不可用，因此Apple编译、自动化UI和视觉验收未完成。工作仅在本地；无提交/推送。

## 2026-11-01 KOSPI历史指数接入

- 新增NAS侧Naver Finance KOSPI日线provider，复用已有Naver市场来源体系但使用独立历史接口；校验表头、日期与OHLCV，过滤KST当日数据，并将来源精确标为`Naver Finance KOSPI daily chart (public web endpoint)`。
- 接入multi-market路由、/readyz和历史API归档状态、iPhone允许时区/来源策略与KR Market Regime证据策略。Naver常见`YYYY.MM.DD`与`YYYYMMDD`两类日期均有解析回归；不可信实时报价标签不能冒充历史来源。
- 接口未公开稳定契约，本机无外网访问，当前只验证fixtures和源码连接；NAS实网可用性、覆盖长度与实际交易日必须在部署后核验。不得把代码接入描述为已验证真实历史数据。

## 2026-11-02 首批CI失败修复

- 首批推送`9273dd3`触发的NAS/Python run成功；iOS Swift package compile 因`MarketQuoteCache.loadAll`默认参数引用`Self`、`LedgerHistoryProjection`现金流水闭包漏写`return`、`MarketRegimeEngine.qualifiedBenchmarks`闭包输出类型无法推断而失败。已分别改为具体类型静态常量、显式return、显式闭包参数/返回类型。
- 指数/Regime/历史接线相关55项Python回归、compileall、架构边界与diff检查通过。修复后的Apple编译需下个iOS Actions run确认。

## 2026-11-02 第二轮Apple编译问题修复

- 第二轮iOS Actions仍在Swift package compile失败，并暴露继续向下编译才出现的错误：`ResearchEvidence.swift`未导入FCore而引用来源信任策略；`CandidateShadowScorecard`新增参数缺少类型默认值声明且嵌套optional directional moves推断成Any；`DecisionContext`对必填String日期使用`.map`导致迭代Character。均已修改，待第三轮Apple CI验证。
- 同SHA的NAS/Python run通过；本机仍不能运行Swift/Xcode，不能将本地静态修改当作Apple构建通过。

## 2026-11-01 用户图表高度反馈

- 参考截图显示证券详情纵向图表占屏过高。详情实时分时、日K、NAS历史分钟及紧凑行情图统一设为320pt；图表增加稳定可访问性标识，UI测试对详情实时图和日K图高度设上限，并更新源码合同与B-058追踪。
- Home/追踪Python合同30/30通过，`git diff --check`通过。当前FCore XCTest定义332项、App UI定义12项，均未在本机Apple工具链执行。全量Python发现293项、291项通过；`test_ios_app_structure`和`test_nas_deployment_package`因环境缺PyYAML不能导入。Swift/Xcode/Simulator不可用，不能在此确认真实布局高度或截图观感，仍需Apple UI run/真机检查。未提交/推送。

## 2026-11-01 Local Quant 输入信任续审

- 检查 `FLocalQuantEngine` 的实时分钟、证券日K、证券 Regime、映射指数 Regime 和 IOPV 五类输入：实时行情 freshness 共享来源白名单与未来时点门；日K检查精确证券/来源、抓取时点及最近bar时效；Regime校验证据时点、市场/证券身份和风险等级；映射指数必须匹配发行人登记的指数并校验获取/观察时点；IOPV要求腾讯参考源、完整质量与90秒有效期。没有发现当前可绕过这些信任条件的路径。
- Local Quant、Market Regime、报价信任及追踪合同30/30通过。该静态合同不代替Swift XCTest，当前仍无Apple编译/执行证据。无提交/推送。

## 2026-11-01 Ledger金额与每日盈亏续审

- 检查已确认成交按序重放、数量溢出、卖出成本移除、费用更正、现金/持仓对账、日已实现盈亏及做T配对。有限性、成本口径和配对不完整均会拒绝或返回不可用；没有确认金额错算路径。
- 账户费用分类、Ledger写入并发、证券日盈亏、Shadow成交关联和追踪合同16/16通过。Swift/XCTest仍未执行；未提交/推送。

## 2026-11-01 数据星图角色标识冲突

- 星图中心的组合摘要与外围可点击真实资产导航节点此前复用`home.role.portfolio`。因此UI测试用`firstMatch`查询组合角色时会命中中心摘要，无法保证资产导航节点本身存在且可点击。
- 中心摘要改用`home.star-map.center`；十主题UI用例现在断言组合导航角色只出现一次、四个导航节点都可点击且不与中心摘要重叠。Home/追踪Python合同30/30通过，`git diff --check`通过；本机无Simulator，Swift UI XCTest未执行。

2026-11-01 NAS lower-chain follow-up: strict response-size handling, minute archive/providers/runtime/service, research evidence and dividend research tests passed 131/131 with temporary files redirected to the workspace. The official KRX KOSPI-series daily-history API documents an `AUTH_KEY` request header and a baseline-date query; current compose/runtime has no credential injection or KOSPI daily adapter. Keep history unavailable until a key path and compliant, bounded collection/attribution flow are implemented; the live KOSPI quote is not a substitute for Regime history. The full NAS-qualified strategy package to Local Quant remains an open requirement. No commit/push.
