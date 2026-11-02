# F状态文档说明（2026-11-01）

## 当前源树状态覆盖（2026-11-01；优先于下方历史记录）

- 2026-11-02 `ae6ca432` CI复审：NAS/Python所有测试、Python编译和架构边界检查通过；iOS Swift包335项通过，真机与Simulator app构建通过。12项导航UI测试中11项通过，最后1项的估值行ID未出现在辅助功能树。已将估值展示改为显式合并的标签/数值可访问元素，并让UI验收滚动到该行后再断言；待下一轮CI验证。
- 2026-11-02 `8429a776` CI复审：NAS/Python 306项中305通过，唯一失败是跨市场任务源码合同要求保留并行实时/历史刷新。已本地恢复`async let`并预先捕获actor属性。iOS Swift Package测试、设备构建和Simulator构建通过；12项导航UI测试中8项失败，集中在星图节点坐标、编辑主题缺少首页资产估值行、无NAS日K时UI测试错误要求图表存在、画像测试没有等到可操作/持久化状态。已在本地修复并调整UI验收为检查真实空状态与保存后的控件结果；尚未复跑或推送。
- 2026-11-02 iOS App目标集成编译修复：删除对非可选每日交易日的错误条件绑定；成交影子关联传入已确认账本快照；IOPV溢折价计算移至App可访问范围；因子数字字符串转换显式消除重载歧义；Guard原因改用实际`findings`；行情刷新状态处理可选字典值；Result展示扩展限定Success类型；SwiftUI行情说明去掉ViewBuilder条件赋值；跨市场启动任务预先捕获actor状态再并行刷新。`8429a776`的macOS CI确认Swift包、iOS设备和模拟器app构建通过。
- 2026-11-01 韩股历史指数接入：NAS增设Naver KOSPI日线provider，独立于iPhone实时报价，支持Naver常见日期格式、过滤当日未完成bar、校验OHLCV，并接入日线归档、iPhone可信来源门与KR Regime；新增路由、解析和API回归。Naver历史端点为未签约公开接口，本机无法实网验证，须由NAS部署后的实际请求确认可用性与覆盖。提交推送授权已给出，每次最多两个Actions run；当前尚未提交。
- 2026-11-02 连续CI复审：两批NAS/Python Actions均成功；两批iOS Actions仍在Swift package compile失败。第1批发现缓存默认参数引用`Self`、Ledger现金流水map闭包漏`return`、Regime字典分组推断失败并已修复；第2批继续发现ResearchEvidence缺少FCore import、Shadow快照参数声明和方向收益数组推断错误、DecisionContext把非可选交易日字符串当字符集合处理，均已修复。55项指数/Regime/接线Python回归、Python编译、架构边界检查和差异检查通过；Windows无Swift/Xcode，修复仍需第三批Apple CI确认。
- 2026-11-01 用户图表反馈续审：详情分时、日K、NAS历史分钟及行情卡片图表统一从400/360pt收至320pt；新增稳定可访问性标识、UI高度验收及源码合同。Home/追踪合同30/30通过；全量Python发现293项、291项通过，2项因缺PyYAML无法导入；`git diff --check`通过。Swift/XCTest与Simulator不可用，尚无截图视觉确认。B-058已更新；未提交/推送。
- 2026-11-01 Local Quant 输入信任续审：确认盘中因子只在共享报价时效/来源门通过且处于连续交易时段时计算；证券日K来源与时点、Regime市场身份/数据时点、映射指数身份/获取时间及IOPV来源均有独立门控。未确认可绕过路径。Local Quant、Regime、报价信任与追踪聚焦合同30/30通过；Swift/XCTest未执行；未提交/推送。
- 2026-11-01 Ledger金额与每日盈亏续审：复核真实成交回放、数量溢出、成本移除、费用更正、每日已实现盈亏及T配对；运算结果在账本余额核对或报表聚合处失败关闭，未确认金额错算路径。账户费用、Ledger并发写、每日盈亏、Shadow成交关联及追踪合同16/16通过；Swift/XCTest未执行；未提交/推送。
- 2026-11-01 星图主题无障碍标识续审：发现组合中心摘要与可导航真实资产节点复用`home.role.portfolio`，造成UI查询歧义且未断言资产节点可点击。中心摘要改用独立`home.star-map.center`；UI验收现检查组合角色唯一、四节点均可点击并与中心不重叠。Home/追踪合同30/30通过，diff检查通过；Simulator UI XCTest未执行；未提交/推送。

- 2026-11-01 NAS底层链续审：响应体上限、分钟归档/provider/runtime/service、研究证据与分红研究回归131/131通过（测试临时目录置于工作区）。KRX官方资料确认KOSPI日线接口需要申请AUTH_KEY；目前compose和runtime均无密钥注入及KOSPI历史采集实现，故仍应Unavailable，不能以当前KOSPI实时行情替代Regime日线。Local Quant完整NAS资格包闭环仍是未完成需求。未提交/推送。

- 2026-11-01 后续全盘审计：复核多市场指数日K provider/NAS API/Regime接线、首页与持仓录入、CI触发与并发。未发现本轮可确认的新产品缺陷；KOSPI实时行情已接入，历史KOSPI因KRX适配器/授权缺失明确Unavailable。指数/Regime/Advisor聚焦回归90/90通过；首页、账户费用、PnL、行情缓存、追踪及CI合同47/47通过。Windows默认临时目录拒绝SQLite文件后，将测试临时目录指向工作区并通过；Swift/Xcode/XCTest和Simulator仍不可用。无提交/推送。

- 2026-11-01 B-018前收来源审计：日盈亏计算之前按任意新鲜`previousClose`观察接受数值，没有限定来源。现校验Tencent参考行情精确来源，且在PnL取值和DecisionContext验证两处失败关闭；新增伪造来源Swift回归。Security Daily P&L、Advisor安全和追踪合同33/33通过；Swift/XCTest未执行。未提交/推送。

- 2026-11-01 腾讯分钟量续审发现：累计成交量字段缺失/无效后，旧解析器沿用上一个基准，使下一个可读差值覆盖多个分钟。现清空累计量基准，直到建立新基准后再输出单分钟量；新增缺量连续性 XCTest 和来源合同。相关聚焦合同37/37通过，compileall、架构边界及diff检查通过。本机无Swift/Xcode，XCTest未执行。全量Python重跑因Windows回环套接字访问错误中断；最近一次完整发现293项、291通过，2项因缺PyYAML导入失败。未提交/推送。

- 2026-11-01 Market Regime 输入边界复审：核心此前会过滤掉收盘价非有限/非正的bar后继续用其余历史分类，也不校验负成交量、部分OHLCV字段和矛盾OHLC。现在有效as-of区间的任一坏bar令Regime Data Unreliable并提供专用因子/原因码；未来回放区间的坏bar仍忽略。新增2项FCore XCTest定义；Market Regime与追踪Python合同19/19通过。全量Python发现293项，291项通过，2项因缺PyYAML未能导入；compileall、架构边界及diff检查通过。本机无Swift/Xcode，XCTest未执行；未提交/推送。

- 当前工作树：分支`main`，HEAD `0296013f20156b23831cedd6d95f707eb6d89cc3`，工作树dirty；本轮无提交或推送。origin状态本轮未重新核实。
- 2026-11-01 iOS成交量质量续审：腾讯当前分钟累计成交量回退时，iOS旧逻辑把负差值夹成0；现保留价格点、将该分钟成交量标为未知，并以回退值作为后续差分基准。图表的部分量价均价会明示未知分钟量点数。新增解析器和图表状态合同3/3通过；B-010追踪行已补充。FCore测试定义326项；本机无Swift/Xcode，XCTest尚未执行。全量Python发现292项，290项通过，另2项因缺PyYAML不能导入；无提交/推送。
- 2026-11-01 iOS跨市场指数数值边界：NAS指数历史解码器现仅接受有限Decimal且其Double转换仍有限，避免异常数值进入Market Regime bars。Daily-history wiring回归14/14通过；Swift/Xcode未安装，新增Swift改动未编译/运行。KRX历史接口仍缺获批授权密钥与NAS适配器；无提交/推送。
- 2026-11-01首页资产摘要续审：新增“账本内资产估值”，只计算现金+全部真实持仓市值；必须为CNY、账本时点有效，且每个持仓证券有120秒内可信报价，否则整项显示不可用并列出缺失代码，不显示部分持仓的伪总值。新增5个FCore XCTest定义及首页可访问性UI断言；相关Home/追踪Python合同30/30通过；全量Python发现288项，286项通过、2项因缺PyYAML无法导入；架构边界和compileall通过。当前FCore定义324项、UI定义11项；本机无Swift/Xcode/XcodeGen，新增Swift未编译/执行，需Apple CI及实机核对金额/可访问性。未提交/推送。
- 2026-11-01 Advisor新闻请求边界：组合目标证券为空时跳过证券关联新闻外网请求，状态说明未抓取；新增源码契约。Advisor安全/新闻/Home/追踪相关合同61/61通过；全量Python288项中286通过、2项缺PyYAML未导入。Swift/Xcode不可用，未做Apple构建或网络实测。未提交/推送。
- 2026-11-01 NAS研究阈值审计：三个底层分钟研究builder改为严格要求正整数样本门和有限、非布尔月份集中度；拒绝`True`导致的隐式门槛降级。新增回归，分钟服务45/45通过，`py_compile`通过；全量Python288项，286通过、2项因缺PyYAML无法导入。未提交/推送。
- 2026-11-01 NAS研究非有限统计审计：有限正价格也可能形成超出Float范围的百分比收益/回收或网格净值；VWAP、早盘回撤修复和网格研究此前可输出Infinity并仍标available_for_review。三者现在拒绝不可有限表示/下溢成零的统计样本，记录拒绝数并排除在OOS摘要外；walk-forward汇总另加非有限防线。NAS研究/归档/provider/runtime/service/股息和追踪共128/128通过；全量Python288项，286通过、2项缺PyYAML无法导入；py_compile通过。未提交/推送。
- 当前定义：FCore XCTest方法332项、App UI 12项；dirty工作树在本机执行的Apple测试为0。本机没有Swift/Xcode/XcodeGen，当前Swift及iOS改动没有编译或运行证据。最近一次完整Python发现293项，其中291项通过；两个依赖PyYAML的测试模块因本机缺少该依赖未能导入。Home/追踪聚焦合同30/30通过；Python compileall、架构边界检查与diff检查通过。上述静态/Python结果不能替代Apple运行验收。
- 本轮再次核对持仓初始录入：六位证券代码触发名称查询并允许手动修改，每份真实经济成本乘持有份额得到账本总经济成本，券商现金通过独立表单录入；已有Home源合同和UI入口定义。未发现可确认的实现缺陷；实际网络名称查询、Apple UI运行与持久化实机验收仍待完成。
- 首页主题覆盖：九种常规主题共用Portfolio→Market→Cross-market→Advisor角色顺序；dataStarMap按径向位置布局并检查可点击性。相应UI测试已补充，但未在Simulator运行或人工查看截图，视觉验收仍未通过。
- 跨市场时区审计：纽约秋季回拨时重复的本地时点无法唯一映射UTC；指数时间解析现拒绝这种歧义，也拒绝春季跳时不存在的时点。已增加两项FCore XCTest定义与Python源码合同；Regime/指数合同15/15通过。跨市场UTC存储、交易所日历和全时区DST回放仍未完成。
- 市场日历复审：iPhone的CN本地会话只接受审阅过的2026日历，未审阅年份返回`unknown`；NAS归档和实时采集在写入前核对会话身份、交易日范围及预期分钟。未发现未知年份被当作闭市或可交易的路径。NAS归档、runtime与service 100/100通过；US/HK/JP/KR官方假日和临时停市日历仍未实现。
- 行情自选回归：B→F审计原先误称F缺少自选与筛选；现确认代码查询、自选持久化和持仓/自选/合并列表已接入。补充UI用例验证自选列表与Ledger分离并恢复测试前状态，及源码契约验证存储边界。当前首页合同27/27与追踪3/3通过；UI XCTest未在Apple工具链执行。全市场目录与证券名称搜索仍缺。
- 2026-11-01 B-032续审：画像投影此前丢失临时修订过期时间。投影现在保留 `expiresAt`，解码后重新校验临时来源/过期字段一致且在 `asOf` 后仍有效；新增篡改成过期记录的 XCTest定义与源码合同。Advisor安全/画像合同26/26及追踪合同3/3通过；完整Python发现269项中267通过、两项因缺PyYAML无法导入。八个现有画像字段仍不能由当前镜像证明覆盖原B需求全部子字段，未据此推定完整。Swift/XCTest未执行；无提交/推送。
- 2026-11-01 Shadow成交关联续审：只读Ledger快照现在必须证明账户ID、成交ID、成交时间（不晚于快照）、证券代码、买卖方向及完整成交份额均匹配，避免随机ID/编造时间/跨账户挂接被标记为确认成交。相关Shadow Python合同4/4通过；Swift XCTest仍未执行。旧归档与真实App流程仍未验收；无提交/推送。
- 2026-11-01 B-030续审：DecisionMemory现保存原请求scope，Advisor投影拒绝跨scope历史；提示词要求只比较同范围历史建议、说明证据差异，且无匹配记录时不推断。确定性变化引擎、专用UI与真实模型输出仍未验；Advisor安全合同已增加对应断言。
- 2026-11-01 B-036续审：画像使用约束已真正附加到DeepSeek system prompt；响应支持引用本次画像revision ID，并在Provider与Guard拒绝无效引用。真实DeepSeek输出及Apple构建仍待验。
- 当前产品架构：NAS历史分钟数据仍主要服务Quant回测、Validation、OOS和Strategy Qualification；NAS Research Summary只作为Advisor可选的本机缓存，不得同步阻塞行情或Advisor。Local Quant已有因子与Regime消费骨架，但合格策略包尚未签发/下放，不能声称已形成可交易的完整Quant。Risk Guard与Realtime Trigger存在确定性门控代码，但候选生成、实时报价订阅、持久化、通知和完整UI闭环尚未端到端验收；Candidate继续fail-closed。
- Market Regime已编码多因子分类、来源/市场身份/时效校验、已支持指数历史归档输入和同步的同市场基准观察；KOSPI日线适配器缺失、广度无生产来源，必须保持Unavailable。图表语义色已接入Theme Manifest tokens。Simulator/截图人工审阅、iPhone Air、横屏交互、NAS/DeepSeek实网、真实指数覆盖与映射效果均未验证。
- 已做真实远端Fetch但还未安全reconcile；远端首页/IPA后续提交需要先审阅合并冲突。当前改动不能触发Apple CI，直至正常提交并推送。
- 用户实机反馈当前F整体体验明显不如B；B→F逐页整改尚未关闭。以下历史条目保留作追溯，不得视作当前源码、当前验证或当前需求，冲突时以 `F-REALTIME-HANDOFF.md` 最新快照和 `F-MASTER-ACCEPTANCE-MATRIX.md` 当前盘点为准。
- 2026-11-01 NAS定位修正：顾问提示词、首页研究说明、主题描述和设置页明确NAS历史分钟主要服务Quant回测/策略资格验证，摘要仅作Advisor次要缓存，NAS不可达不阻断实时行情或单次基础分析；当前参数包尚未下放Local Quant。新增Advisor/Home源合同，并修正将后台Task内`await`误识别为同步等待的测试断言。Node静态合同检查通过；Python unittest和Swift/XCTest未执行。
- 2026-11-01 NAS上游响应上限复核：指数与分钟provider此前只读取上限字节数，未拒绝超限响应；现统一验证Content-Length并最多读取上限+1，超限失败关闭。相关NAS回归79/79通过；全量Python 282项中280通过，另两项依赖PyYAML的测试不能导入。Swift及NAS实网未验证。
- 2026-11-01 HTTP响应内存上限：将NAS私有读取器改为应用共享流式读取器，NAS与Advisor Research最多4MB、DeepSeek最多2MB、公开指数/行情最多128KB；已有新闻流式读取仍最多1MB。超过Content-Length或实际流量上限即中止，应用源码中不再保留`URLSession.data(for:)`整段无上限读取。相关Python合同18/18通过；全量发现263项中261项通过、两项因缺PyYAML导入失败。Swift/XCTest未能在本机执行；未提交/推送。

本文件下方旧记录保留为历史快照，不作为当前要求或验证证据。当前规则是：NAS研究不得同步阻塞Advisor；但策略必须经过NAS历史数据回测、验证、样本外评估与资格签发才能成为合格策略包。无有效包时Local Quant继续fail-closed。迁移实施与Apple验证状态以`F-REALTIME-HANDOFF.md`及`F-LOCAL-QUANT-ARCHITECTURE.md`为准。

# F 云端开发状态

## 最新实时状态（2026-10-27 15:19 Asia/Shanghai）

- HEAD `5169df6` 与当时核对的 `origin/main` 对齐；工作树有设置页表单滚动测试及跨市场验收文档修改。
- Apple CI run `40463891229`：FCore 121/121通过，XcodeGen、Device Build、Simulator Build通过；UI XCTest失败，执行摘要未给出断言行号。UI Test步骤耗时4m59。当前日志检查尚未获取xcresult原始失败细节。
- 最新待送CI修正：`SettingsOverview` Form 标记 `settings.form`；测试定位该真实容器，滚动到NAS测试按钮并验证可点击；无法定位容器时清晰失败并返回。尚未编译/执行。
- 最新跨市场原则已补入F-145追踪：严格跨市场时区/日历/DST与no-lookahead，相关/领先/共同因素分层，逐证券动态画像及20/60/120滚动失效，底层资产判断与ETF场内溢价判断分离，等待作为正式决策，Evidence必填统计与质量元数据。尚属设计/验收要求。

## 最新实时状态（2026-10-27 14:38 Asia/Shanghai）

- 当前分支 `main`，最近提交 `773608d`；工作树现在有一项未提交 UI XCTest 修改。Git提交只作追溯。
- 最新 Apple CI run `40460442070`：FCore **121/121 executed / passed / 0 failed**；XcodeGen、Device Build、Simulator Build成功；UI XCTest **3 executed / 2 passed / 1 failed**。
- 失败断言在设置页进入后立即查找滚动表单下方的NAS测试按钮。DeepSeek输入框已可发现；已将UI检查改为先滚动到NAS按钮，再验证按钮可点击。新修改仍未编译/执行，等待Apple CI。当前不是CI整体不可用。
- 本机无Swift/Xcode/XcodeGen。Simulator自动测试已运行，但本轮截图图像未人工审阅；不能将自动启动或截图导出写成人工视觉通过。真实NAS仅有已证实的当日分钟归档；历史分钟、DeepSeek及AI确认成交闭环尚未端到端通过。

## 实时工作树状态（2026-10-27；覆盖下方历史快照）

### 本轮后续实况

- 用户已部署v6。14:11:49 NAS实时worker OK；六只证券各归档191条并过滤真实供应商返回的13:00午休边界行。该真实NAS结果验证了实时分钟→session过滤→归档→状态页；截至14:11，尚非全天完整或iOS/Advisor E2E。同期历史补采处理3/完成0/重排3/队列846，159352指定历史日失败原因为 `empty source response`；Tencent仅支持当前日，Eastmoney对这些过往日期当前未返回分钟数据。当前配置无法补齐这些日期，不能等同网络故障或断言其他历史源不存在。runtime 4/4、py_compile、diff检查通过。
- 新增用户跨市场研究假设，追踪在B-116…B-126，尚未编码/验证且不改变当前验收优先级：用条件概率而非只看相关系数，分别评估日经/TOPIX、韩国市场上涨/下跌及共同方向，对A股总体及每只真实持仓证券的非对称后续影响；按跌幅/急跌分桶，考察同期与后续5/15/30/60分钟、上午/下午、市场状态，并提供N、概率、收益分布、置信度、新鲜度、是否有效及20/60/120交易日滚动稳定性。研究设计须预先设定样本/质量门槛、as-of配对并防未来数据泄漏；门槛未达标不得进入DecisionContext，证券敏感度不得从A股整体结果推断。映射权重由历史研究估计。跨市场脉搏展示市场证据，AI今日指导解释其对真实持仓的含义，保持独立职责。
- 用户v4截图确认页面加载修复后服务Ready/archive OK，但14:04六只证券实时采集均报ServiceError，backfill 3项均重排（队列846，RemoteDisconnected）。修复运行时健康输出以保留具体实时/日历异常原因；runtime测试2/2通过、py_compile通过；v5部署包已打出但未部署，需读原因后继续根因修复。
- 静态审计修复Advisor标的选择：问题明确证券优先于详情页默认代码；强组合措辞保持Portfolio，宽泛“现金/配置/买什么”只有未指明证券时才路由Portfolio。Swift修改未编译、未执行测试。当前本地提交 `820fffb`，用户看到远端仍为 `4d258f1`；push连续3次DNS线程错误失败；新增Swift修改使工作树dirty，等待连接恢复后并入Apple CI。
- 用户报告状态页持续加载；Node脚本语法解析定位内嵌JS模板语法错误，已修复并通过语法解析，fetch增加10秒超时。NAS v4部署包已生成；需重新部署后才能验证真实WebView恢复。Advisor另修复按已清仓证券名称无法选中Security scope的问题；该Swift未编译/测试。
- 增加 NAS 同源只读网页 `http://NAS地址:8788/`：显示真实 readyz/worker/日历与指定证券交易日的分钟覆盖、来源、诊断和价格图。用户已在NAS实开并确认 Ready/HTTP200、archive OK、backfill Degraded(3项重排/队列846/RemoteDisconnected)、日历等待官方公告；修正实时worker缺字段被页面默认成0、分钟UTC时间显示的问题。v3部署包已构建且确认HTML入包，但v3尚未部署。
- 用户提交的 `159866/CN/2026-10-27` NAS 指定日响应含120条真实腾讯分钟记录（北京时间09:31–11:30），状态Partial，240个预期点中缺120；这证明单证券上午数据已归档/可查询，不代表全日、其他证券或iOS/Advisor链路完成。
- 修正 `nas/fminute/archive.py` 的 SQLite 连接生命周期：`_connect()` 事务完成后显式关闭；备份/恢复临时文件用读写句柄执行 `fsync`。NAS定向测试最新4/4通过，Python `py_compile` 与 `git diff --check`通过。
- 更广的分钟归档/runtime测试曾在受限Windows执行为46 executed / 36 passed / 0 failed / 10 errors；主要受备份原子硬链接权限及测试直接打开SQLite连接未关闭造成的Windows锁影响。完整NAS套件尚待Linux CI复跑，不计全套通过。
- 本地没有Swift/Xcode/XcodeGen，当前dirty Swift未编译；未取得新的Apple CI结果或远端同步确认。

> run `40343237878` / job `121643239252` 已执行至 `Run F app navigation UI tests`：按workflow顺序，之前FCore XCTest、XcodeGen、iOS Device Build和Simulator Build步骤成功；当前121项FCore测试121/121通过。App UI定义3项；已确认 `testFivePrimaryDestinationsAreDistinctAndDiscoverable` 执行并失败，Annotations只有exit code 65，精确断言未取得。本机无Swift/Xcode/XcodeGen；dirty Swift未被该run编译。详见F-REALTIME-HANDOFF.md。

- 当前源码状态在工作树 `main` / HEAD `4d258f199c7575f84251154b8929c30fba271508`；本地有未提交修改，详见 `F-REALTIME-HANDOFF.md`。不要将下方较早的CLEAN/CI状态视为当前状态。
- 最新远端CI是 run `40343237878`：FCore 121/121、XcodeGen、Device Build、Simulator Build成功；UI导航测试失败，首个断言未取得。该run针对已提交HEAD，不覆盖dirty Swift改动。本机无 Swift、Xcode、XcodeGen。
- 最新 Swift 源码修正：明确组合/多持仓问题优先 Portfolio scope；详情证券码仅作默认值；单证券“持仓成本”等问题不会仅因出现“持仓”字样而误分类。尚未编译或测试。FCore最近可复核历史为121/121，UI为3/3，但这些数字不能覆盖本次改动。
- 当前任务队列：取得UI失败行并定点修复；将dirty Advisor scope Swift改动送CI；继续静态查Ledger/现金/Episode、统一图表与NAS质量边界。
- iOS Actions workflow 已静态确认：push到`main`且触及`GuanpanFApp/**`时会跑Swift package tests、XcodeGen、Device/Simulator Build和UI Test；本轮fetch失败，因此未push且没有新的编译run/失败日志。
- 当前本地没有重放Python全套或Apple验证。此前局部NAS runtime测试2/2通过；当前远端run完成Simulator Build并运行UI XCTest，未有人手工操作Simulator或确认本次截图。

## CI续记（2026-10-26 19:43 Asia/Shanghai；覆盖下方旧状态）

- 最新已推送 `016a1a3`，run `40315965909` 全成功：FCore 121/121；XcodeGen、Device/Simulator Build、UI XCTest 3/3、截图导出和未签名IPA均成功。
- 人工截图确认图表滚动已恢复，日K真实蜡烛、MA线、成交量可见；行情状态来自Tencent日K。但“历史分钟”截图仍与日K截图相同，不能据UI 3/3宣称历史NAS页面视觉验收通过。
- 本地未提交修正：历史区截图前增加确定性滚动；资产状态/现金值改为垂直文字；日K轴标签缩短为日期。未编译/运行。Python/NAS本轮未执行。

## CI续记（2026-10-26 19:32 Asia/Shanghai；覆盖下方较早快照）

- 当前已推送 HEAD `c96a17e77fd533c58e63123c69cd6e71b2fb406c`，与origin/main同步。工作树当前仅有 `FUnifiedSecurityChart.swift` 和4份状态文档未提交修改。
- Actions run `40314328798`：FCore XCTest 121/121通过；XcodeGen、Device Build、Simulator Build成功。UI 3项执行、2项通过、1项失败；失败是日K标题经8次整屏滑动仍不可见。截图导出成功；IPA因UI失败跳过。
- 根因假设：图表Canvas上的DragGesture抢占详情外层ScrollView的纵向滑动。已在本地改为simultaneousGesture；未编译、未运行，待下一轮CI。Python/NAS本轮0执行/0通过/0失败。

## CI续记（2026-10-26 19:20 Asia/Shanghai；覆盖下方18:20记录）

- HEAD `1c10912e8d1c2a0b6fdc3720b73f6fada28c5e20` 已推送并与 origin/main 对齐。随后源码两文件及四份状态文档有本地未提交修改。
- Actions `40312257829`：FCore XCTest 121/121通过；XcodeGen、Device Build、Simulator Build通过。UI XCTest 3项执行、2项通过、1项失败（同一用例的两个标题可见性断言失败）；截图导出成功，IPA因UI失败跳过。
- 新截图显示价格/刷新仍裁切；日K/历史截图与证券页顶部重复。已清仓标题测试可见性断言通过，截图与当前资产截图不同。
- 当前本地再修：价格与刷新纵向排布，UI改用整屏滚动。此后代码未编译/测试，待推送重跑。Python/NAS本轮 executed 0 / passed 0 / failed 0。

## 最新实时覆盖（2026-10-26 18:20 Asia/Shanghai）

- 当前源码提交 HEAD `1c10912e8d1c2a0b6fdc3720b73f6fada28c5e20`，相对本地 origin/main ahead 1；源码干净，四份状态文档有本次未提交更新。该提交尚未推送；GitHub 443 当前连接失败，因此本提交无 Apple 编译/测试证据。
- 最新远端成功 workflow 为 `40305133985` / commit `04b0deb`：XcodeGen、Device Release Build、Simulator Build、App UI 3/3、截图导出、未签名 IPA步骤成功。其8张Simulator截图经人工查看发现详情刷新行横向截断，并且旧测试未滚动导致日K/历史、当前资产/已清仓图重复；人工视觉验收未通过。
- 精确 FCore 数字最近由run `40303339340` 工件确认：121 defined / 121 executed / 121 passed / 0 failed。当前本地UI修正尚未执行，不能继承为当前提交通过证据。App UI当前定义3项；最近远端版本3/3通过，当前新源码待跑。Python/NAS本轮未执行（0/0/0）。
- 本地窄幅修正已编码：缩短证券详情刷新按钮并收敛价格行；UI自动滚动到日K、历史分钟、已清仓的可见区域后截图。该代码未编译、未运行，等待恢复网络后推送CI。
- 最新视觉证据附件：GitHub Actions run `40305133985` 的 `guanpan-f-ios-build-evidence` / `UI-Screenshots`（8张）；仅旧版界面快照，不能代表修正后的布局。

## 当前工作树快照（2026-10-26 18:07 Asia/Shanghai）

- F 当前阶段：可用性验收 + 真实链路联调 + 缺口收口。Actions run `40303339340` 实际执行FCore XCTest 121/121、旧版App UI XCTest 3/3，XcodeGen、Device Release Build、Simulator Build、未签名IPA均成功。
- 本次CI工件日志确认FCore 121 executed / 121 passed / 0 failed；UI 3 executed / 3 passed / 0 failed。模拟器实际启动并走过旧版主导航与空资产/已清仓tab，但未导出成功页截图，也没有真实持仓数据的清仓详情画面。
- 本机没有 Swift/Xcode/XcodeGen；后续 Apple 验证继续通过已有 GitHub macOS workflow进行。历史开发记录保留作追溯，不能覆盖本节实时状态。
- FCore 价格范围回归（有效overlay/IOPV与历史MA250）已随本次CI实际通过。当前未提交Swift/YAML变更：行情页增加六位证券代码查找并导航到真实证券详情；原3项UI测试中增加导航、页面截图附件；workflow导出PNG。新改动尚未编译执行。
- 本地 `main` 已与 `origin/main` 同步；两侧相同tree的分叉历史通过保留双方父提交的merge commit `35047cf` 收敛，工作树目前有上述3个文件修改。

## 当前基线

- 当前 CLEAN checkpoint 由 `main` 与 `F-CHECKPOINT` 同一提交标识；完整可恢复 Git 历史另存为 `F-CHECKPOINT.bundle`。本工作区从 F-LATEST 源码包导入，原上游 Git 历史未包含在该包中。
- A Frozen HEAD：`eb6fa384a2df8c503eb76d13f68d080c08be31ad`；B Frozen HEAD：`9ddfe32b787ad9e522a48eb55ff8231227d79599`。本阶段未修改或合并 A/B。
- F 是唯一 Active Development。验收矩阵覆盖 F-01 至 F-40 及 EXT-1 至 EXT-5。B版145项作为需求来源已逐项映射至 [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)，不继承B状态；F-34跟踪编号连续性、逐项处置和独立验收。

## 当前实现（代码存在不等于验收通过）

- Ledger 写权限隔离、用户成交确认、原子持久化、备份/恢复、只读决策上下文、Memory/Profile 持久化和三通道同步规则已编码；Swift/XCTest 尚未运行。只读已实现盈亏按确认卖出流水派生，不修改真实账本。
- NAS 分钟链路具备补采、实时归档、完整度评估、精确日期查询、备份恢复、质量门控和 no-lookahead 研究证据。v6于2026-10-27 14:11:49在用户NAS实机完成当前日六证券归档烟测；过往日期补采存在empty source response，长期完整性、其他数据源与iOS/Advisor端到端仍待验证。新增红利多因子证据整理器，并接入版本化 NAS Research Evidence/DecisionContext；红利证据按来源、观测时间、抓取时间和质量过滤，不沿用分钟研究25日门槛；4%仅作参考，无交易结论。跨市场非对称研究假设已记入B-116…B-126追踪设计，未编码、未产出合格结果。
- 图表命中测试、行情时间语义、Advisor 上下文和 Research Evidence 契约已编码；原生iOS SwiftUI首页骨架与XcodeGen项目规格已写（未构建）；在线模型接入、NAS Research Tool 调用边界与响应身份/质量编排已编码，XCTest未执行；真实新闻/行情服务、跨设备同步 UI 仍未完成。
- 全盘复核发现研究入口接受 truthy 的 `complete` 值、空来源/任意 volume_method，并在定制 tzinfo 返回无 offset 时可能按本地时区解释；现已 fail-closed 并新增回归覆盖。发现 Advisor 请求此前未序列化持仓/现金/观察值，现加入只读组合投影，并要求 Guard 校验它与 DecisionContext 完全一致。AI Guard 额外拒绝 hold/wait 携带价格/数量等订单字段、超长理由和重复/空证据引用。
- 恢复 F-01…F-34 主矩阵为统一四列格式，并核对 B-001…B-145 连续映射。

## 本阶段验证

- 测试定义静态复核发现LedgerSchemaTests实际31项（含此前新增的只读已实现盈亏派生测试），故将FCore defined从30纠正为31；executed仍为0。

- FCore XCTest：defined=31 / executed=0 / passed=0 / failed=0（没有 Swift/Xcode，未编译未执行）。
- Ledger Boundary XCTest：defined=26 / executed=0 / passed=0 / failed=0；新增请求证据绑定及Profile/Memory解码投影校验回归定义，未执行。
- Market/Chart/Advisor XCTest：defined=42 / executed=0 / passed=0 / failed=0。
- Home Card Contract XCTest：defined=7 / executed=0 / passed=0 / failed=0；新增现金状态语义回归定义，未执行。
- 分钟归档 Python：defined=43 / executed=43 / passed=43 / failed=0。
- A/B→F账本只读dry-run Python：defined=6 / executed=6 / passed=6 / failed=0。
- 分钟服务/Research Evidence Python：defined=27 / executed=27 / passed=27 / failed=0。
- 红利研究 Python：defined=7 / executed=7 / passed=7 / failed=0。
- NAS Python 合计：defined=77 / executed=77 / passed=77 / failed=0；连同只读迁移dry-run 6项，本轮总计83/83通过。
- `python -m py_compile nas/fminute/*.py Tools/*.py`：通过。
- `python Tools/verify_architecture_boundaries.py`：通过，Advisor 依赖与账本写入口边界符合脚本约束。
- Python结果仅证明当前 Python 范围；不代表 Swift、模拟器、真机、生产 NAS、实源、新闻或在线 AI 验收通过。

## 本阶段推进

- 原生首屏已切换为 FAccountBookStore 的公开只读快照接口；App 不调用Ledger SPI方法。Swift/Xcode未安装，编译仍待验证。

- 新建 GuanpanFApp SwiftUI App target 规格与首页基础视图：五种不同布局分支、四个语义独立路由、明显AI输入/快捷问题、只读真实Ledger展示；无行情或AI provider时显示不可用状态。静态契约检查通过，但XcodeGen/Swift/Xcode未安装；不得记为构建或设备验收通过。

- 增加FAdvisor只读AI决策流水线：先绑定request/context，再调用模型候选接口，最后执行Risk/AI Guard；证券详情范围拒绝错标证券。新增2项XCTest defined、未执行。Research Tool返回也按证券、市场、日期范围、asOf、证据类型和质量门槛校验。

- 增加只读AI决策流水线契约：模型只能返回Candidate，context/request绑定先校验，随后Risk/AI Guard裁定可否展示；标的详情请求会拒绝跨证券候选。无Ledger写依赖。新增2项XCTest defined、未执行。

- 风险边界收紧：买入/卖出/做T/网格候选必须引用同一标的的已验证新鲜报价；新增正反Ledger Boundary XCTest定义，未执行。
- 回本候选收紧：必须指向真实持仓且不能带结构化订单份额/限价/手续费字段；新增AI Guard XCTest定义，未执行。
- 网格候选只接受同一标的合格 gridSpacingReplay 研究引用；做T目前缺少盘口/费用等完整上下文，Guard明确 fail-closed。新增1项策略证据回归定义，未执行。
- NAS历史查询`availableAsOf`现在拒绝无时区和未来截止时间，避免本地时间比较异常及回看未来数据；Service回归通过。
- F App target由仅iPhone改为iPhone+iPad通用设备目标；YAML解析和target setting静态核对通过。
- Advisor Pipeline在模型返回后按完成时刻重新运行报价/风险Guard，避免异步等待期间引用已过期行情；新增1项XCTest定义，未执行。
- 首页账本状态区分读取中、未建立、读取失败、已读取空仓和已读取持仓，避免把未知状态显示为无持仓；SwiftUI代码已改，Xcode/可发现性验证待外部完成。
- AdvisorComposer新增5条横向可点快捷问题（组合操作/买入/降成本/做T/建议变化）；真实持仓行可进入证券独立详情，详情页/快捷问题/发送动作携带证券范围；源码静态核对通过，Xcode与可发现性仍待Simulator/真机验证。
- 新增 Research Tool provider 编排：绑定工具请求的证券、市场、日期范围、asOf和质量门槛；不合格或身份不匹配的NAS响应拒绝传给AI。对应XCTest仅定义，未执行。
- 修复NAS Research Evidence内容完整性：evidenceId现覆盖schema/methodology、标的、日期范围、asOf、交易日覆盖、合格独立日数、最低质量、来源、统计数据、原始分钟/计划排除标志；iOS端用CryptoKit重算并拒绝摘要不匹配载荷。Python/Swift统一整数浮点的规范编码；asOf/generatedAt按UTC毫秒纪元值内容寻址，附带时区和限制文本。新增1项Swift XCTest定义；Python服务回归从19增至22并实跑通过。跨语言固定摘要断言已定义，需Xcode执行后最终确认兼容性。
- 新增 A/B→F Python 只读迁移dry-run安全回归：重复报告确定性、CLI源文件只读、原始历史仅留证据、负现金/重复证券/未知schema fail-closed。6项实际执行通过。该结果不替代Swift migration XCTest或真实账本数据验证。

## External Verification Pending

Swift/Xcode 与 XCTest、iOS Simulator/iPhone、NAS 8788 生产部署和真实行情源/交易日历、GitHub 远端、真实新闻与在线 AI、推送通知、跨设备备份恢复。

## 全盘审计

- Matrix已对齐SwiftUI源码现状：F-21/22/27/32的首页壳、五布局、显著AI输入/快捷问题、四个独立主目的页和持仓详情路由记为已编码；完整图表/AI/设备和实际可发现性仍未验收。

- 逐项未完成功能、外部验证和本轮发现的状态不一致见 [F-FULL-IMPLEMENTATION-AUDIT.md](F-FULL-IMPLEMENTATION-AUDIT.md)。
- F-01…F-34 当前全部保持 defined；没有整项F验收通过。

## 本阶段完成

- B 版 145 项仅作为需求来源和验收输入：逐项保留原编号、F 需求处置、供体裁决、F 映射及独立验收状态；B 的 Implemented/Partial/Not Verified/PASS 等状态不继承。
- F Matrix 当前为 34 项 defined、5 项 external pending。NAS Python 当前实跑 77/77 通过；Swift XCTest 各套件均未执行。

## 唯一精确续接点

从本阶段提交后的 `main` 与 `F-CHECKPOINT` 最新共同 HEAD 继续全盘循环。优先审阅分钟数据库的长期留存、备份恢复与容量诊断契约，再继续AI/NAS接口、行情与原生App链路的本地可验证部分。所有 XCTest 仍保持 defined、executed=0，直到具备 Swift/Xcode 环境实际运行。

- Advisor信任边界：解码后的问题请求不得附加、替换或删改DecisionContext未提供的NAS研究证据/冲突元数据；模型调用前精确比对合格证据集合，不匹配按requestContextMismatch拒绝。新增1项Boundary XCTest定义；Python 70/70、py_compile和架构边界检查本轮实跑通过；Swift仍未执行。

- Advisor投影边界：Profile投影拒绝未来修订、重复属性/修订ID、无效置信度和值；Memory投影拒绝未来决策/结果/证据、重复项、超限和跨证券范围。Request解码及模型调用前均执行验证。新增Profile未来修订和Memory未来决策回归定义，XCTest未执行。

- NAS诊断的补采队列数改为按securityCode+market范围统计；全局队列查询仍返回全量。新增隔离性回归，分钟服务测试25/25通过；全套Python与迁移dry-run累计73/73通过。

- NAS补采容量修正：failed任务重排会占用活动队列容量；达到上限时整笔排队请求拒绝且数据库状态不变。新增容量/回滚回归，分钟服务套件24/24通过。

- NAS补采任务现以归档完整度为准：历史队列任务即使状态为complete，只要分钟归档检测到缺口，也会重新排队。新增缺口恢复回归，分钟服务套件25/25通过。

- 本轮全盘复核校正状态摘要：NAS Python 67/67通过，A/B迁移dry-run另6/6；合计73/73。队列诊断按标的隔离、失败任务重试计入容量、归档缺口可重新排队的修补及回归均已纳入。

- 分钟数据库完整性检查扩展到minute_bar、append-only observations和session coverage的语义校验；损坏价格/时间戳/成交量/来源/覆盖元数据时，backup与restore fail-closed，不发布恢复目标。新增损坏行备份/恢复回归，archive套件37/37通过。

- 首页现金摘要按真实账本状态区分“读取中、未建立、不可读取、可用现金”；读取失败不再显示成“未建立”。纯呈现逻辑与SwiftUI接线已编码，新增Home Card XCTest定义，未执行；Xcode/设备可发现性仍未验证。


- NAS HTTP 边界复审发现 backfill 身份会被 `str()` 强制转换、重复 JSON 键被默认静默覆盖、GET 忽略未知参数。现拒绝重复键/非有限数字/截断请求体，要求 backfill 字段均为字符串，并按路由执行查询参数白名单；回归验证错误请求不会进入补采队列。全套Python74/74通过，py_compile与架构边界脚本通过。
- 分钟归档当前默认永久保留且没有自动修剪；RetentionPolicy 仍是声明性配置。生产容量、压缩/分区、备份轮换和NAS恢复演练未完成，继续 External Verification Pending；实际策略未知时不启用删除。

- 补采任务入队进一步校验精确日期类型、显式优先级枚举和交易日历唯一交易日；日历重复日期或错误优先级时 fail-closed，队列保持不变。现有分钟服务测试内加入回归，NAS Python仍74/74通过，XCTest未执行。

- 补采队列恢复审计发现缺少schema版本和任务行语义校验。现增加queue schema v1元数据；既有无版本队列仅在结构完整且数据校验通过后迁移标记；启动验证SQLite完整性、字段、版本、日期、优先级、状态、重试次数与时区时间戳，未知版本/坏任务fail-closed。新增重启/损坏/未来版本回归。当前分钟服务26/26、归档37/37、红利6/6、迁移dry-run6/6，共75/75；XCTest仍未执行。
- 启动恢复校验补充运行租约一致性：`running` 必须有租约，其他状态不得残留租约，避免无租约的运行中任务永久卡队列。新增损坏租约回归，Python全套75/75仍通过。

- 分钟诊断接口审计发现未传日期范围时，`missingDays`只代表已记录覆盖状态，可能被误读为完整历史范围的缺失总数。现增加`missingDaysScope`和`missingDaysMayBeUnderstated`；指定起止日期时按交易日历计算精确范围，未指定则明确为记录覆盖范围。HTTP回归验证范围内两个未归档交易日计为缺失、无范围时不宣称完整；全套Python75/75通过。

- 交易日历时区校验补强：`MarketSession`拒绝返回`utcoffset=None`的自定义tzinfo、非date交易日和可变list日程，避免Python把无有效时区的时间按本机时区解释。新增三项场景回归；当前分钟服务26/26、归档38/38、红利6/6、迁移dry-run6/6，共76/76；py_compile与架构边界检查通过。

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


- 2026-10-26 全盘复核：红利历史收益率相同观测时点此前由输入顺序决定保留记录，且历史质量分缺少 100 上限。现按质量分、抓取时间、来源和值稳定选择唯一观测，并拒绝越界质量分；新增顺序无关回归。红利研究7/7；分钟归档40/40、分钟服务26/26、红利7/7、迁移dry-run6/6，总计79/79。py_compile、架构边界脚本通过。FCore XCTest defined=31、executed=0、passed=0、failed=0；其他 Swift XCTest 仍未执行。

- 2026-10-26 后续全盘复核：NAS HTTP授权此前以普通 truthy 判定，授权器误返回非空字符串或整数可能被放行。现仅接受字面布尔 `True`，异常和其他值均拒绝；增加回归覆盖字符串、整数、异常与合法True。分钟服务27/27，归档40/40，红利7/7，A/B迁移dry-run6/6，总计80/80。FCore XCTest仍为defined=31、executed=0、passed=0、failed=0。

- 2026-10-26 历史分钟校验补强：backfill provider 返回交易日内但不属于当日交易日历时间表的分钟点时，原逻辑会将其写入主归档，随后虽标 Partial，历史图表仍可能读到盘外点。现整批源响应先验证所有时间戳属于会话预期集合，违规源不落库并继续 fallback。归档41/41、分钟服务27/27、红利7/7、迁移dry-run6/6，合计81/81；py_compile和架构边界检查通过。

- 2026-10-26 分钟覆盖诊断复核：范围内的部分数据若在入库和 coverage 计算之间崩溃，诊断此前可能显示 `unassessed`；范围外已记录的 missing 状态也可能污染指定范围的缺失计数，且缺失日期不列入逐日结果。现诊断按交易日历刷新每个请求日的覆盖状态，列出 Missing/Partial，日期列表与缺失计数按请求范围收敛；未请求范围时仍使用 recorded coverage 口径。新增恢复窗口、部分覆盖和范围隔离回归。归档43/43、服务27/27、红利7/7、只读迁移6/6，总计83/83；XCTest依旧未执行。

- 2026-10-26 覆盖诊断明细补强：未指定范围时，历史上已评估但完全没有分钟行的交易日此前只进入 missingDays 汇总、不出现在 days 明细。现将已有 coverage 记录中的 Missing/Partial/Complete 日期加入明细，同时维持 `recordedCoverageOnly` / `missingDaysMayBeUnderstated` 语义；无范围数据不推断未记录的交易日。回归在既有归档套件43项中验证，无新增或虚报通过项。

- 2026-10-26 iOS构建链推进：发现既有GitHub Actions仍指向废弃的`GuanpanNext/ios`路径，无法针对F源码触发有效构建。现改为监听`Package.swift`、`Sources`、`Tests`、`GuanpanFApp`；macOS job 执行 Swift Package XCTest、XcodeGen 生成F工程、iOS设备与模拟器目标构建，并在成功时打包unsigned IPA及上传日志。YAML和F路径静态核对通过；当前Linux环境无Swift/Xcode/XcodeGen，CI尚未运行，所有XCTest仍保持defined=31/executed=0/passed=0/failed=0，EXT-3保持External Verification Pending。

- 2026-10-26 iOS target静态依赖复核：App源码引用`FHomeLedgerAvailability`与`FHomeCardPresentation`，但此前未导入/链接`FAdvisor`，会导致Swift符号解析失败。现App源码导入FAdvisor、XcodeGen target链接FAdvisor产品；本地模块import与产品依赖静态一致性检查通过。Swift/Xcode不可用，实际编译仍External Verification Pending；XCTest unchanged: defined=31/executed=0/passed=0/failed=0。

- 2026-10-26 iOS 全盘静态审计见 [F-IOS-IMPLEMENTATION-AUDIT.md](F-IOS-IMPLEMENTATION-AUDIT.md)。修复 App target 漏链FAdvisor导致的符号错误风险，并移除 Application Support URL 强制解包。确认当前 App 仍是 UI 骨架：AI发送仅提示未接入，行情/跨市场是不可用状态页，App target 尚无图表/历史日期控件；Card Contract 尚未驱动 SwiftUI 卡片。CI YAML和模块依赖静态检查通过；Linux无Swift/Xcode/XcodeGen，未编译、未运行XCTest。FCore defined=31 / executed=0 / passed=0 / failed=0；EXT-3 External Verification Pending。

- 2026-10-26 NAS部署壳阶段：新增 `nas/fminute/server.py`、Dockerfile、Compose、`.env.example` 与部署说明；HTTP 提供不需认证的 liveness，readiness 和业务 API 需要强令牌，缺少真实 Calendar/Provider 时 readiness 返回 503。Runner HTTP smoke：livez=200、匿名 readyz=401、无 Provider readyz=503；Compose YAML结构检查、`py_compile` 通过；分钟服务/归档、红利研究、只读迁移dry-run共83/83通过。当前无Docker命令，未构建镜像/部署NAS。真实行情Provider、生产交易日历、NAS 8788与备份恢复仍 External Verification Pending。FCore XCTest defined=31 / executed=0 / passed=0 / failed=0。因工作区存在其他预先未提交改动，本阶段不覆盖它们。

- 2026-10-26 NAS真实Provider/Calendar接入：修正上一条将Provider误列为必须外部提供的判断。F默认runtime现接入腾讯当日分钟接口、东财精确日期1分钟历史请求、经官方公告核对的2026年沪深交易日历，并启动实时轮询线程与独立补采线程；启动时对显式证券清单排入最近120个可支持交易日。直接请求腾讯接口实际返回当天分钟数据，经F日历校验写入临时SQLite，16条记录状态Partial、预期240条，符合盘中不报完整的规则；腾讯09:30开盘值不落归档。东财历史请求在本云端超时，故历史真实覆盖仍External Verification Pending；其他年份日历未配置时fail-closed。Provider/Calendar新增回归10项，全NAS/迁移Python 93/93通过，py_compile和架构边界检查通过；Docker不可用，镜像和NAS部署未执行。FCore XCTest defined=31 / executed=0 / passed=0 / failed=0。上一阶段未提交的其他工作区改动继续保留，未覆盖。

- 2026-10-26 行情刷新/图表与日历检查：确认F此前SwiftUI市场页没有行情请求或图表数据绑定，因此不把B的10秒报价定时器当作F完成。新增F腾讯当前日分钟响应严格解析、行情/获取时间区分、可观察的每证券数据状态；持仓首页曲线和详情曲线绑定同一快照；进入详情立即请求、交易时段每10秒刷新；手动按钮显示加载、成功/错误状态。客户端与NAS只认可审核过的2026日历，未知年份暂停刷新/采集，NAS readiness对未支持的当前年份返回503。2027不会自动更新：上交所官方年度休市页当前只列2026，未发现已发布的2027安排；配置须在官方安排发布并审核后更新。新增8项FCore XCTest定义，defined=39 / executed=0 / passed=0 / failed=0。实际执行Python 94/94通过、py_compile通过、架构边界检查PASS；iOS编译/运行、按钮交互和真机图表仍External Verification Pending。A/B Frozen未修改。工作区之前已有的未提交差异保留。


## NAS 后台月度官方交易日历同步 checkpoint

- F 的 NAS 进程启动时立即检查当前年与下一年；此后每月1日检查上交所年度休市页及深交所官方公告索引/公告。
- 两个官方来源均明确发布目标年、严格日期解析通过且闭市日期集合完全一致后，才将带来源URL、原始页面SHA-256和fetchedAt的日历写入 `/data/official-calendar-v1.json`。临时写入后 fsync、读回校验并原子发布。
- 目标年度尚未发布、两源差异、网页变更、下载错误、存储摘要损坏均不覆盖旧日历；未支持年份保持fail-closed。11月起缺少下一年安排、或当前年度未支持/请求故障时，每周重试。`/readyz`显示calendarSync状态和支持年份；存储损坏/当前年未支持返回503。
- 新增测试覆盖双源一致、公告未发布、双源不一致保留旧字节、摘要损坏、启动/每月1日/周重试、非官方域跳转拒绝；Provider/Calendar套件16/16。全NAS/迁移Python 100/100，py_compile与架构边界通过。
- FCore XCTest defined=39 / executed=0 / passed=0 / failed=0。当前云端无法访问官方站点做NAS运行联调，且无Docker/NAS 8788；实网HTML兼容、定时任务、生产重启/备份仍 External Verification Pending。
- 当前阶段代码将单独提交并更新 F-CHECKPOINT、F-LATEST、完整Git bundle、overlay与NAS部署包；A/B Frozen不变。


## 2026-10-26 原生 iOS 主应用与 NAS 接入阶段

- 续接基线：`9114b450b59c185ac434b99b3ba923e7c0d1c67e`。A Frozen `eb6fa384a2df8c503eb76d13f68d080c08be31ad`、B Frozen `9ddfe32b787ad9e522a48eb55ff8231227d79599` 未修改；保留并恢复 B-001…B-145 作为需求输入，不继承B完成状态。
- App根导航改为首页/行情/AI顾问/真实资产/设置五个独立Tab和NavigationStack。不同语义入口有独立route及页面；首页保留五种主题布局。真实资产页只读账本快照；Advisor页提供明显输入/发送/快捷问题/组合状态，在线AI未接入时明确不发送、不生成候选建议；设置页主题和数据状态可见。
- NAS设置新增地址字段与SecureField。token经Keychain `AfterFirstUnlockThisDeviceOnly` 保存，地址存AppStorage；连通性测试只调用带`X-Api-Key`的只读`GET /readyz`，没有传输Ledger。设置文本要求HTTPS或可信家庭LAN；尚未做Xcode、设备网络权限和钥匙串运行验收。
- NAS部署截图阻塞项：旧包将Compose/Dockerfile相对路径按源码根目录组织，与用户选择的NAS项目目录不一致；且没有设置`F_MINUTE_DATA_DIR`。现新增根目录自包含部署ZIP：根目录放`compose.yml`与`Dockerfile`，默认将`./data`持久挂载到`/data`；仍要求部署者提供随机至少32字节`F_MINUTE_API_TOKEN`和真实证券代码。新包未在目标NAS构建或部署，不能标记可部署通过。
- 新增2项App XCUITest定义，覆盖主导航、AI输入与NAS token配置入口；macOS CI增加UI test步骤。XcodeGen与Workflow YAML结构静态检查通过，App源代码/工程未编译。
- 本轮实际执行：NAS/迁移/新增iOS结构与部署包 Python `111/111 PASS`；`py_compile`通过；`Tools/verify_architecture_boundaries.py`通过；XcodeGen/CI YAML结构断言通过。
- 测试状态：FCore XCTest `defined=39 / executed=0 / passed=0 / failed=0`；App UI XCTest `defined=2 / executed=0 / passed=0 / failed=0`。环境无Swift、Xcode、XcodeGen、Docker；没有iOS Build、UI运行或NAS镜像构建/部署证据。
- External Verification Pending：XcodeGen工程生成、Swift Build、FCore XCTest、UI Test/Simulator/截图/iPhone；NAS Compose实际构建、NAS 8788、网络/TLS、真实行情/历史分钟与日历同步；在线AI/新闻/推送与GitHub远端。
- 交付细节见 [F-IOS-APP-INTEGRATION-ADDENDUM.md](F-IOS-APP-INTEGRATION-ADDENDUM.md)；NAS根目录交付和Token说明在新 `F-NAS-DEPLOYMENT.zip` 的 `DEPLOYMENT.md`。

本阶段已提交至 `main`，`F-CHECKPOINT` 与其对齐；F-LATEST、Git bundle、NAS部署ZIP和恢复清单均已重建并校验。后续续接优先补iOS NAS历史日期/诊断客户端，并继续将 DecisionContext/Guard 接入顾问，不绕过Ledger写边界。

## 2026-10-26 NAS Compose项目名修复

- 用户NAS界面报告 `invalid project name "guanpanF"`。Compose项目名只允许小写字母、数字、短横线和下划线；将源码与打包配置固定为 `guanpan-f`，部署说明注明NAS界面若要求项目名也应填写此值。
- 部署包回归5/5通过；全Python套件111/111通过；`py_compile`和架构边界检查通过。Docker/NAS环境不可用，目标设备Compose解析与部署仍 External Verification Pending。
- FCore XCTest `defined=39 / executed=0 / passed=0 / failed=0`；App UI XCTest `defined=2 / executed=0 / passed=0 / failed=0`。


## 2026-10-26 原生 iOS 单证券顾问垂直切片

- 优先推进一个真实证券链路：发送时重新读取本机`FReadOnlyLedgerSnapshot`，刷新当前Tencent分钟行情，向NAS `/api/v1/minute-history/research` 请求最近120日、最低25个独立交易日及质量90的Research Evidence，构建`FDecisionContext`和`FAdvisorQuestionRequest`，运行`FAdvisorDecisionPipeline`的Risk Guard/AI Guard。AI结果卡显示真实份额、账面成本、现金、报价来源/时间、NAS研究摘要、结论、依据、风险、失效条件及受Guard约束的Candidate Plan。
- AI provider仅依赖FCore/FAdvisor，不持有FLedgerWrite或账本句柄。若分析期间Ledger摘要变化则丢弃结果；无同标的合格NAS研究时阻断买入/卖出/做T/网格候选；没有真实Ledger/持仓时不创建演示数据。新闻作为不可用观察显式传入。Candidate Plan只展示，不写Ledger。
- 设置新增DeepSeek API Key的Keychain录入，并在发送前说明只读账本、行情和合格NAS证据将发送到用户配置的模型。按DeepSeek官方当前Chat Completions JSON模式接入`deepseek-flash`非思考模式；不使用已于2026-07-24退役的`deepseek-chat`模型别名。
- 本阶段没有增加Python测试或FCore XCTest定义。FCore XCTest `defined=39 / executed=0 / passed=0 / failed=0`；App UI XCTest `defined=2 / executed=0 / passed=0 / failed=0`。环境没有Swift/Xcode/XcodeGen/Docker，编译、iOS运行、真实账本/NAS/AI端到端均External Verification Pending。
- F Matrix新增F-40，总计40项defined、5项external pending。静态检查不作为iOS验收通过证据。


## 2026-10-26 NAS容器 `nas.fminute` 导入故障修复

- 用户提供NAS日志：`ModuleNotFoundError: No module named 'nas.fminute'`，容器反复重启。
- 部署包构建器此前逐个复制`nas/fminute/*.py`，未将`nas/__init__.py`显式加入ZIP。现补齐`nas/__init__.py`与`nas/fminute/__init__.py`，Dockerfile在复制代码后执行`import nas.fminute.server; import nas.fminute.runtime`构建期检查；镜像缺包会在构建时失败，不再进入容器重启循环。
- 实际验证：部署包测试defined=6 / executed=6 / passed=6 / failed=0；最终打包后解压并运行Python import smoke通过；相关`py_compile`通过。当前环境无Docker命令，镜像构建及目标NAS重部署未执行，保持External Verification Pending。
- FCore XCTest defined=39 / executed=0 / passed=0 / failed=0；App UI XCTest defined=2 / executed=0 / passed=0 / failed=0。未修改A/B Frozen。


## 2026-10-26 NAS SQLite 数据目录权限修复

- 用户日志显示`sqlite3.OperationalError: unable to open database file`，发生于bind mount后的`/data`。镜像构建时对镜像内目录执行`chown`会被NAS挂载覆盖，因此该权限设置没有作用到宿主目录。
- 新增容器entrypoint：root启动阶段仅准备挂载根目录与属主不匹配的顶层数据项，内容保持不变；初版通过`gosu`降权，后经NAS构建反馈改用`util-linux`的`setpriv`切换至UID/GID 10001运行Python。若NAS文件系统禁止chown或只读，entrypoint会给出明确错误后退出。默认持久路径`./data`不变，避免切换到空库遮蔽既有数据。
- 实际验证：NAS部署包测试defined=7 / executed=7 / passed=7 / failed=0；新ZIP解压后模块导入smoke通过；entrypoint `sh -n`通过；相关`py_compile`通过。当前没有Docker命令，镜像构建、属主修复实跑及NAS服务恢复未执行，保持External Verification Pending。
- FCore XCTest defined=39 / executed=0 / passed=0 / failed=0；App UI XCTest defined=2 / executed=0 / passed=0 / failed=0。容器端口仍为8788，未改变API token或真实持仓隔离语义。


## 2026-10-26 单证券 Advisor 范围保护

- 复核单证券垂直切片时发现，组合问题在没有显式证券路由时会默认交给账本第一只持仓分析，可能把单证券结论误认为组合建议。
- 现对常见组合级问句 fail-closed，明确提示当前仅支持证券级分析，并要求指定一只真实持仓证券；首页和顾问页文案标明证券级范围，快捷问题改为证券问题。
- 组合问题不会调用在线模型，也不会生成顾问结果。组合级 Advisor 仍按后续阶段实现，需使用全量持仓、现金、行情、研究和风险上下文。
- 仅做源码静态复核；本环境无 Swift/Xcode，未编译或运行 XCTest。既有测试数保持 FCore 39 defined/0 executed、App UI 2 defined/0 executed。


## 2026-10-26 组合/证券 Advisor 与 NAS 历史分时推进

- Advisor 输入范围现在按入口和问题识别：从证券详情发送时限定该真实持仓；问题中明确证券代码或名称时限定对应持仓；其他问题使用组合范围。组合上下文逐证券并行刷新 Tencent 行情和请求 NAS 历史研究，完整真实持仓、现金、全部可用报价/研究证据及缺失状态进入冻结的 DecisionContext/请求投影。分析采集前后账本摘要需一致；分析完成后再次核对摘要，不一致即丢弃结果。结果逐项呈现 quoteTimestamp、fetchedAt、source 与 market session。
- 组合候选仍通过 Risk/AI Guard。任何资产变更候选必须是持仓标的、具备新鲜同标的行情、满足现金/份额边界且引用合格 NAS 研究；Candidate Plan 只展示，不写 Ledger。iOS Guard 同时校验单次 ETF 买/卖或网格候选估费0.10元、做T往返0.20元；不匹配拒绝展示为可审阅候选。
- 证券详情页新增 NAS 历史分钟查询：调用鉴权 `/api/v1/minute-history`，按用户选择的交易日读取真实 bars 和 coverage，显示来源、覆盖状态、缺失点；无数据/非交易日不绘制伪线。当前视图仍是基础折线，K线、MA、IOPV、十字光标/拖动缩放/横屏还未完成。
- 修复 NAS 镜像因 `gosu` 在当前 Debian slim 源不可用而无法构建的问题：改用 `util-linux` 提供的 `setpriv`，保留 UID/GID 10001 权限切换与数据目录原位保护。部署包专项测试7/7通过；没有 Docker，NAS 镜像重建和目标设备验证仍未执行。
- 本源码包不含原Git目录。为满足本地检查点操作，当前以 F-LATEST v2 建立新的恢复仓库根提交；其不恢复或冒充此前远端提交历史。后续 commit/tag 记录只代表此恢复工作区。Swift/Xcode仍不可用，FCore XCTest `39/0/0/0`、App UI XCTest `2/0/0/0`。


## 2026-10-26 保守做T与分时交互

- 移除 Guard 对所有做T候选无条件要求盘口的阻断。基础档只需目标证券连续交易时段可信新鲜报价、真实持仓/现金/份额约束，以及同标的、被候选明确引用且合格的 `vwapBreak` NAS 研究；不把盘口数据作为基础档前提。缺少当前有效报价/研究仍 fail-closed。iOS系统提示和结果卡明确标注“盘口未接入、未用于判断”；ETF做T费用按买卖两笔共0.20元校验。
- 分时折线图增加真实点拖动选取、长按/按钮进入十字光标、时间/价格提示、双指缩放及放大后横向平移历史窗口，且当前/历史分钟复用同一组件；仍没有K线/数据点点击或横屏全屏实现。
- 更新既有 MarketChartAcceptanceTests 场景，定义在无盘口、但持仓/新鲜报价/合格vwapBreak证据完整时基础做T可供人工审阅；测试定义数量不变。当前无 Swift/Xcode，未运行该测试，FCore仍39/0、App UI仍2/0。
- 仅做静态边界复核；未接入盘口源，不将任何估算/缺省值展示成盘口数据。真实端到端与设备手势体验仍External Verification Pending。

## 2026-10-26 证券详情日 K 与均线数据接入

- FCore新增腾讯未复权日 K 模型与严格解析：校验证券代码、日期顺序、正价格、OHLC关系、非负成交量和来源；保留抓取时间。按真实收盘价计算MA5/10/20/60/250，样本不足返回缺失值，不外推。选择未复权序列，避免与真实Ledger成本线错配。
- 证券详情进入时并行请求Tencent当前分钟和最近300根日K；页面绘制真实OHLC蜡烛及五组均线，显示抓取时间、来源、复权状态及MA样本不足信息。请求失败明确显示不可用，不会以分钟点伪造日K。
- `git diff --check`通过；没有增加测试定义或执行测试。环境为Linux且无Swift/xcodebuild/XcodeGen，故日K Swift源码和App target仍未编译，线上Tencent响应解析、图表显示及MA计算结果均待Xcode与真机验证。FCore XCTest `defined=39 / executed=0 / passed=0 / failed=0`；App UI XCTest `defined=2 / executed=0 / passed=0 / failed=0`。
- 本阶段范围尚不包括成交量子图、K柱选择/十字光标、历史日K日期选择、IOPV、成本/均价/前收线和横屏；当前分钟图已有的手势没有被误报为日K交互验收。NAS历史分时、Advisor组合/证券范围、Guard与Ledger只读边界保持既有状态。

## 2026-10-26 统一图表数据与交互契约

- 从 `6c15564` CLEAN 基线开始完成静态边界审阅：Advisor只依赖FCore，读账通过只读snapshot接口；`FLedgerWrite`仅由App入口消费，Advisor target和Candidate Plan不持有Ledger写能力。`Tools/verify_architecture_boundaries.py`结果PASS。
- FCore新增统一图表数据契约，区分实时分时、历史分时和日K序列；非空数据必须携带行情来源/抓取时间，实时分时要求可信行情时间；缺失数据由Unavailable(reason)表达，覆盖不足/过期由Partial/Stale表达。
- 新增IOPV观测DTO和可验证价格overlay DTO（成本、均价、前收、IOPV及Candidate标记）；新增平台无关图表交互状态（可视区、选点、缩放、十字、横屏全屏）。这些只是数据/状态契约，尚未接入具体数据源或SwiftUI手势，不表示功能已完成。
- 本环境仍为Linux，无Swift、swiftc、Xcode、XcodeGen。没有继续扩大SwiftUI或测试集合；XCTest定义数保持 FCore `39 / 0 / 0 / 0`、App UI `2 / 0 / 0 / 0`。实际执行的静态检查仅架构边界PASS及`git diff --check` PASS，编译闸门仍是最高External Verification Gate。

## 2026-10-26 IOPV质量状态约束复核

- 复核统一图表DTO时发现 `FIOPVObservation` 的可用分支未排除 `Unavailable` 状态，导致调用方理论上可同时提交数值与Unavailable。现要求可用分支显式排除Unavailable；Unavailable分支要求无数值/观测时间/来源/抓取时间并提供原因，避免空值与有效值语义冲突。
- 这是静态契约修正，没有接入或伪造IOPV源；Xcode仍不可用，未编译、未执行测试，测试计数维持FCore `39 / 0 / 0 / 0`、App UI `2 / 0 / 0 / 0`。

## 2026-10-26 Advisor组合意图优先级修正

- 组合Advisor范围复核发现，六位数字会先于组合意图识别，被当作证券代码；组合问句同时提到一只证券时也可能被缩成单证券范围。现先判定明确组合意图：详情页显式目标仍按Security Advisor；其他组合问句忽略旁带证券提及/六位数字，完整分析全部真实持仓与现金。非组合问题仍按已持仓代码/名称限定Security Advisor，并对未持仓的明确六位代码fail-closed。
- 完整上下文仍由 `FDecisionContext` 投影绑定并经 Guard 校验；逐证券行情/研究缺失仍以Unavailable observation表达。此修正未改变账本读取或写入能力。
- 静态检查通过；无Swift/Xcode，未编译、未执行XCTest，FCore `39 / 0 / 0 / 0`、App UI `2 / 0 / 0 / 0`保持不变。

## 2026-10-26 NAS entrypoint CRLF 启动故障修复

- 用户容器日志 `exec /usr/local/bin/f-minute-entrypoint failed: No such file or directory` 对应根因已确认：entrypoint文件是CRLF，第一行实际变成 `/bin/sh\r`，Linux找不到该解释器；文件路径与COPY语句本身正确。
- 将 `nas/docker-entrypoint.sh` 统一为LF，新增 `.gitattributes` 固定shell脚本LF；Dockerfile在镜像构建阶段检查入口首行为 `#!/bin/sh`，防止坏换行进入镜像。回归断言加入既有部署包测试，不增加测试项数量。
- 实际验证：NAS部署包测试7/7通过；`sh -n`通过；ZIP内入口首字节确认 `23 21 2f 62 69 6e 2f 73 68 0a`（LF）；部署包已重建。当前无Docker/Podman，未能在本地构建镜像或启动容器；需NAS重新构建镜像并重建容器，不要仅重启旧容器。
- Swift/Xcode仍不可用；FCore XCTest `39 / 0 / 0 / 0`、App UI XCTest `2 / 0 / 0 / 0`不变。


## 2026-10-26 NAS 8788 存活检查与 F GitHub CI 接入

- 历史现场：用户从 NAS 端口访问得到 `{"status":"alive","service":"f-minute-archive"}`；旧部署 `/readyz` 返回 `unauthorized`。**后续更新：用户确认不需要这层NAS密码并接受可达网络访问；当前工作树已移除 API token 鉴权，旧现场描述不代表新源码/部署行为。** 生产 readiness、归档/日历/provider 状态仍待核验，且运行中容器尚未重部署。

## 当前增量：移除 NAS API Token（2026-10-26）

- 用户确认 NAS API Token 是额外密码且不需要，授权移除并接受可达网络访问。当前 Swift 客户端、NAS HTTP server、Compose、`.env.example`、部署说明与交付包生成说明已移除 token/X-Api-Key；DeepSeek API Key流程未变。
- 所有可达8788端口的设备现在可读 readiness、分钟历史、研究证据、诊断、补采队列并提交补采。安全边界改由用户网络设置承担。目标 NAS 当前容器尚未重部署，所以仍可能返回旧版本的 `unauthorized`。
- 更新了现有测试定义但本轮未执行；Swift/Xcode、NAS Python tests、部署包生成和容器部署均未验证。不能据源码改动宣称测试/编译/部署通过。
- 已创建私有 GitHub 仓库 `ggjj45828/guanpan-f`，本地 `origin` 已配置。自动审查首次拦截源码上传后，用户已明确授权推送到该私有仓库；重试时 Git 返回 `could not read Username`，未完成认证，未上传任何对象。当前没有 `gh` CLI，GitHub connector 也未连接，远端仍为空、F Actions 尚未执行。用户提供的 `guanpan-pro-native/actions` 最近成功构建属于 `b-latest` 的 B 源码，不作为 F 编译证据。
- FCore XCTest `defined=39 / executed=0 / passed=0 / failed=0`；App UI XCTest `defined=2 / executed=0 / passed=0 / failed=0`。当前仍无 Swift/Xcode/XcodeGen；EXT-3 保持 External Verification Pending。


## 2026-10-26 Advisor 空仓与未持有证券作用域修正

- iOS Advisor 原先将“账本有持仓”作为所有问题的前置条件，并要求目标证券已在持仓中，导致现金空仓组合无法询问组合建议、未持有证券无法询问买入问题。现已移除持仓数量门槛；真实账本存在即可进入组合Advisor，空仓组合仍携带现金和完整零持仓快照。
- 非组合问句中的明确六位证券代码、证券详情入口可以进入Security Advisor，即使目标证券未持有；组合意图继续优先，始终以全部持仓和现金为范围。目标证券行情/NAS研究缺失仍写为显式Unavailable观察，不构造数据。分析前后仍检查账本摘要一致；Candidate Plan无Ledger写接口。
- 只做源码静态检查：`git diff --check`与`Tools/verify_architecture_boundaries.py`通过；未编译、未执行测试、未增加测试定义。FCore XCTest `39 / 0 / 0 / 0`；App UI XCTest `2 / 0 / 0 / 0`。Swift/Xcode首次构建仍是最高External Verification Gate。

## 2026-10-26 本地续接：分钟归档容量诊断

- 按续接点复核长期留存、备份恢复和容量诊断。归档默认永久保留；没有自动删除或备份轮换，备份/恢复已进行数据库语义校验、原子 no-clobber 发布；NAS容量和恢复演练仍待目标设备验证。未启用删除策略，避免在真实留存要求未知时丢数据。
- 分钟历史诊断现额外报告SQLite主文件、WAL、共享内存文件各自字节数，以及所在文件系统总量、已用和可用字节。文件系统容量读取失败时返回空值，其他诊断仍可用；此指标只用于观察，不触发清理。`databaseBytes`继续表示上述SQLite文件合计，保持既有字段语义。
- 诊断读取期间若SQLite并发checkpoint移除了WAL/共享内存文件，单文件大小按0记录，避免文件存在性检查与读取间的竞争导致整份诊断失败。
- 本地环境当前从用户提供的F-LATEST源码包续接，不含Git历史；GitHub远端连通核验因当前网络解析失败未完成。此次改动只做代码和文档更新；未运行测试、构建或NAS验证。FCore XCTest `39 / 0 / 0 / 0`；App UI XCTest `2 / 0 / 0 / 0`不变。

## iOS 可运行版本收敛：统一图表叠加层基线

- 在 `606f470` CLEAN checkpoint 上新增 FCore `FChartOverlayModel`：它以现有 `FChartDataModel` 为唯一序列入口，接收同证券、带来源/获取时间的价格叠加层与可用 IOPV；同类叠加重复、跨证券输入一律拒绝。
- 纵轴范围由可视窗口内的真实分钟价或日K高低点，加上可用成本/均价/前收/IOPV/Candidate叠加点共同计算并保留小幅边距。`Unavailable` IOPV/overlay 不贡献任何数值，禁止为完整图形伪造曲线。
- 此阶段只完成核心数据模型，未增加未经Apple工具链验证的大型SwiftUI渲染代码；现有证券详情 NAS 按日历史分钟消费链保持不变。未运行Swift编译或XCTest：FCore XCTest `39 / 0 / 0 / 0`；App UI XCTest `2 / 0 / 0 / 0`。本机Python入口不可用，未将静态脚本记为已执行。

## iOS 可运行版本收敛：用户确认成交闭环

- App 现仅对通过 Guard 的单笔买入/卖出 Candidate Plan 提供“登记用户确认的真实成交”入口。它预填建议值，但要求用户重新填写实际份额、实际价格、证券名称和非空确认说明；该入口不会向券商下单。
- 写入前重读真实账本并核对 Candidate account digest；卖出时按当前真实持仓计算政策成本，手续费固定 CNY 0.10。调用唯一 `FConfirmedLedgerWriter.confirmFill` 后原子更新本地真实账本；账本变化、数据无效或计划已失效均拒绝写入。
- 成功后清除旧 Candidate、重读只读快照，并按原 Portfolio 或 Security scope 重新构建 Advisor 问题。做T、网格与回本计划不自动转换成成交，必须逐笔由用户核对记录。Swift/Xcode不可用：已编码，未编译、未执行 XCTest、未在 Simulator/iPhone 验证。

## iOS 可运行版本收敛：画像与决策记忆进入 Advisor

- App 现在在 Application Support 的独立 `f-advisor` 目录初始化 Investor Profile、Decision Memory 和 DecisionContext 存储；它们不获得 Ledger writer 能力。
- 每次 Advisor 问题使用 `FAdvisorRequestAssembler` 读取按时点受限的 Profile/Memory 投影，再与冻结的账本、行情和 NAS Evidence 共同构建请求。模型结果通过 Guard 后，Context 与 Decision Memory 分别以乐观摘要保护持久化；任一保存失败不展示为完成建议。
- 当前没有画像编辑/撤销 UI，也不从问答自动推断或写入偏好。Swift/Xcode不可用：该链路已编码，未编译、未执行 XCTest、未在真实设备验证。

## 2026-10-26 Active Development 工作区约定

- 用户指定本机唯一 Active Development 工作区为 `C:\Users\Administrator\.codex\.chatgpt-projects\g-p-6ac90ddb9a888191a751dc24eb6a329d\F`。今后 F 的所有源码修改、提交、测试、状态矩阵和 checkpoint 均在此目录进行；A/B 保持只读。
- 当前 F 目录从 ZIP 解包且没有 `.git` 或 checkpoint bundle。提交与 checkpoint 流程需待 Git 元数据恢复后执行；不把源码目录误报为 Git 分支或 checkpoint。

- 2026-11-01 跨市场指数时点解析修复：严格拒绝含混入字符、分隔符或非ASCII数字的供应商时点，避免把抽取数字误当有效时间；市场Regime/指数历史/API聚焦合同34/34通过，新增Swift正反回归定义未在Apple工具链执行。B-136统一UTC/DST验证仍是未完成要求。

- Market Regime门控现令证券自身R3/R4风险立即关闭策略许可；Local Quant不再因仍保留Bull/Range确认标签而报告策略准备可用。新增2项Swift回归定义和源码合同，Market Regime/Local Quant/Advisor/追踪合同50/50通过；Apple XCTest未执行。

- Regime历史bar现拒绝非有限时间戳（包括负无穷），否则该输入可能参与长期均线并被误判可靠。新增Swift回归定义，聚焦合同26/26通过；Swift/XCTest未执行。

- 2026-11-01 iOS实时分钟时段审计：腾讯与东方财富回包此前只按日期/竞价/未来时间筛选，午休及盘后分钟可能进入分时与因子输入。现两解析器按时钟过滤非连续交易分钟，独立于年份审阅过的假日历；增加腾讯午休、收盘边界与未审阅年份时钟判定回归定义及源码合同。Swift测试尚未在本机执行；Python解析/追踪合同7/7通过，compileall与diff检查通过；无提交/推送。

- 2026-11-01 Local Quant VWAP可用性复核：Tencent首个有效分钟的成交量按安全策略记为未知，但VWAP旧逻辑要求每点成交量均已知，导致真实Tencent分钟样本下该因子通常整项不可用。现要求至少20个分钟样本，忽略未知量点后以已知成交量加权，并要求量覆盖率≥90%；覆盖不足或总成交量为零仍Unavailable。新增XCTest与源码合同；Apple执行待有Swift工具链，本轮定向Python结果随后记录；无提交/推送。

- 2026-11-01 Local Quant VWAP回归结果：LocalQuant/MarketBarTrust/追踪相关合同17/17通过；全量Python发现292项，290通过、2项因缺PyYAML导入失败；compileall与diff检查通过。FCore XCTest定义327项；本机无Swift/Xcode，新增用例未编译/执行。无提交/推送。

- 2026-11-01 RealtimeTrigger Regime时序门控：此前只验证Regime dataAsOf，未验证滞后/未来的memory.lastEvaluationAt，未来记忆仍可能通过候选触发门。现同时要求记忆时点有限、≥dataAsOf、≤当前时点且不旧于5日，并验证confidence范围。新增Swift回归；Market Regime/Local Quant/追踪合同28/28通过，架构边界及diff检查通过。XCTest未在本机执行；无提交/推送。

- 2026-11-01 RealtimeTrigger Regime时序门控：此前只验证Regime dataAsOf，未验证滞后/未来的memory.lastEvaluationAt，未来记忆仍可能通过候选触发门。现同时要求记忆时点有限、≥dataAsOf、≤当前时点且不旧于5日，并验证confidence范围。新增Swift回归；Market Regime/Local Quant/追踪合同28/28通过，架构边界及diff检查通过。XCTest未在本机执行；无提交/推送。

- 2026-11-01 每日成交摘要身份校验：解码后的FDailyTradeSummary.isValid此前只要求证券代码非空且无首尾空格，未执行F账本的6位ASCII数字规则；伪造summary身份可能进入DecisionContext日已实现盈亏聚合。现要求exact 6 ASCII digits，新增短码/全角数字/字母代码解码回归并更新B-018。security daily P&L与追踪合同6/6通过，XCTest未在本机执行；无提交/推送。

- 2026-11-02 iOS Actions第三轮定位：FCore生产源码已通过编译，失败发生在 XCTest 源码编译；修复 CandidateShadowScorecardTests 中 throwing FAccountBook 构造、CandidateSnapshot 参数顺序，以及 LedgerSchemaTests 缺少 fee 和 MarketChartAcceptanceTests 缺少 try。Apple XCTest需由下一轮 Actions 确认。

- 2026-11-02 iOS Actions第四轮：Swift测试目标已成功编译并执行；一项风险防护断言失败，因为用例的Int64.max委托份额先被单笔上限规则拒绝，没有覆盖Decimal乘法溢出。已将输入改为合法最大委托份额与超大价格，确保实际经过checkedTradeUsage溢出分支；等待下一轮Apple Actions验证。

- 第五轮 iOS CI 同一用例断言仍失败；将测试行情价同步到待测限价，避免“买入限价高于最新价”的追价门提前返回，继续确认 Decimal 溢出拒绝路径。

- 复核完整FRiskGuard门控后发现该用例还缺少证券映射宽基指数的 Regime 证据；已补充真实格式的基准证据及候选引用，防止必要的市场风险门提前退出。

- 第六轮 iOS CI：FCoreTests 已编译，Risk Guard 溢出用例通过；执行 Advisor P&L Decimal 极值回归时进程 signal 5。定位为 FDecisionFinancialMath 直接使用 `+`，溢出陷阱未返回 nil。已改用 NSDecimalAdd 并检查状态，等待下一轮 CI。

- 第七轮 iOS CI 仍在 P&L 极值测试开始后 signal 5，尚未产生具体断言或堆栈信息。已将四种算术场景拆分为独立 XCTest，以确定究竟是哪项 Decimal 操作导致进程终止；数值修复尚不能宣告通过。

- 第八轮定位：Decimal 极值加法、sum 溢出和相消用例均通过；进程在非有限输入用例开始时退出。该用例通过 `Decimal(Double.infinity)` 构造测试值。已统一使用安全的 `Decimal.nan` 表示非有限值，并修正相应边界测试；等待 CI 确认。

- 2026-11-02 第九轮 CI 全量 XCTest 已揭示多项潜伏问题：研究摘要半毫秒哈希与NAS不一致、研究测试的源字段替换未实际生效、研究版本选择测试生成了不合格证据、Shadow账户夹具不一致、分钟缺口夹具时间戳错位、Market Regime 均值/ OHLCV校验和Decimal日均值存在边界问题。已修复上述源码与测试夹具；研究工具响应可用性门控仍待本轮 Actions 复核。Python可运行测试293项通过；本机Python运行时缺PyYAML，另2个依赖YAML模块未能导入；Windows无Swift/Xcode。尚未推送。
- 第九轮推送的 Python/NAS workflow 通过；iOS 编译在 NSDecimalDivide 的不可变除数 inout 用法处停止，未开始 XCTest。已将除数改为可变副本，本机无Swift工具链，等待下一轮 Actions 编译和测试。
- 第十轮 Python/NAS workflow 通过；Swift 编译继续暴露 ResearchEvidence 的静态时间格式辅助函数引用实例 evidenceId。现将标识显式作为参数传入；等待下一轮Apple Actions验证。
- 第十一轮 Python/NAS workflow 通过；Swift生产模块成功编译，测试源编译发现两处研究来源测试误把私有JSON helper当作String扩展调用。现已改为显式传入JSON参数，下一轮验证完整XCTest。
- 第十二轮 iOS XCTest 已运行，暴露分钟缺口阈值过宽、暂停Trigger仍泄露建议份额、非有限成交量不应污染价格Regime、过期宽基引用测试过期、非法币种应在Ledger快照入口拒绝，以及慢响应测试时钟不可控。已修复/校正对应规则与测试，加入Research Tool可用性断言定位响应拒绝根因；293项本地Python可运行测试通过，下一轮Actions继续验证。
- 第十三轮 Python/NAS workflow 通过；iOS测试模块编译发现新增时点辅助函数使用了实例属性默认参数并意外遮蔽Date变量。已改为可选时点加函数体内默认值，并区分日期字符串名称。下一轮验证编译/XCTest。
- 第十四轮 iOS XCTest 中Advisor新鲜度行为已按断档闭锁；NAS Research Summary本身通过qualified/usability断言，实际拒绝是测试请求范围与返回证据范围不一致（请求起始日为10/1，证据起始日为8/1）。已将有效请求夹具绑定到证据的8/1起始日，下一轮复验；Python/NAS workflow通过。
