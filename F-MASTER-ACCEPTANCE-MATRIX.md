## 2026-11-02 当前远端 main 状态（覆盖下方历史快照）

> 后续逐项复核：本轮从GitHub核实最新main为 `a1ba64582c29340596d5f5f1639ebc5478a5186c`。工作树新增自选方向观察分/迷你趋势与设置密度调整尚未编译；后续CI执行前均为“编码待验”。A22/A23/A29/A31/A32以及NAS历史、新闻真实到达仍不能标Pass。详情见 `F-AUDIT-TARGET-CHECKLIST.md` 的2026-11-02逐项复核。

> 后续逐项复核：本轮从GitHub核实最新main为 `a1ba64582c29340596d5f5f1639ebc5478a5186c`。工作树新增自选方向观察分/迷你趋势与设置密度调整尚未编译；后续CI执行前均为“编码待验”。A22/A23/A29/A31/A32以及NAS历史、新闻真实到达仍不能标Pass。详情见 `F-AUDIT-TARGET-CHECKLIST.md` 的2026-11-02逐项复核。

- 当前远端/本地 HEAD：`c6ba442835d712b444c27d158aefdc5f1aecdf04`，工作树干净。
- 全盘逐项目标、源码定位、当前证据和关闭条件：见 [F-AUDIT-TARGET-CHECKLIST.md](F-AUDIT-TARGET-CHECKLIST.md)，A01–A32。未人工验收项不得因代码存在或旧SHA CI通过而升级为完成。
- 最新Python/NAS Run28（当前提交）306项、compileall和架构边界通过；本机定向合同30/30。Windows本机全量unittest未能及时返回，已中断，不记为通过。
- 最新Apple Run224验证Swift SHA `f1f2c291…`：FCore335/335、UI XCTest12/12、XcodeGen、Device/Simulator Build和IPA通过。当前`c6ba442`只变更workflow路径过滤，不改该Swift代码。截图未人工审阅，UI自动测试不等同视觉通过。
- 当前证实的产品入口：持仓录入入口存在（未建账快照；已建空账本登记真实成交开仓）；MACD副图存在。其实际发现性、状态保持和视觉布局仍待设备验收。
- 继续未完成：NAS历史日期真实payload/coverage联调；新闻源设备可达和AI引用；前收/均价/IOPV可信数据源；Quant自选评分/曲线接线；Candidate实时Trigger生产链；设置与多主题全页面一致性；图表手势与iPhone Air；DeepSeek真实E2E和成交后Advisor复判。对应状态详见清单，缺数据时继续Unavailable/Fail Closed。

## 2026-11-01 当前工作树校准（覆盖下方较早快照）

- FCore XCTest定义332项、App UI定义12项；当前dirty源码没有Apple CI运行证据，本机Swift/Xcode/XcodeGen均不可用，故本地Apple执行数为0。不得继承旧SHA的CI结果。
- 本轮完整Python发现293项，291项通过；`test_ios_app_structure`与`test_nas_deployment_package`因当前主机缺PyYAML未能导入。用户图表高度反馈后的Home/追踪合同30/30通过，`compileall`、架构边界检查和`git diff --check`通过。NAS Python CI明确安装PyYAML。
- 2026-11-01按用户参考截图再次缩短统一图表高度：证券详情实时/日K/NAS历史与行情卡片均为320pt；Swift/XCTest/Simulator未运行，截图观感尚未验收，不视为图表视觉通过。
- 数据星图中心摘要与真实资产导航节点的重复可访问性标识已拆分；十主题UI用例加上角色唯一性、四节点可点击和中心无重叠断言。源码合同通过，Simulator验证仍待执行。
- 本地Quant现有八类描述性因子观察、来源/时点/质量理由和三类策略准备状态，已进入Advisor只读上下文；它尚未生成交易信号、价格区间、份额、Candidate或生产资格票据。独立验证策略包、策略组合、持续行情评估、Trigger生产接线、状态持久化/通知仍未闭环；NAS不是核心依赖，资产变化Candidate继续fail-closed。
- 八类跨市场实时指数行情已编码；NAS历史K线现增加Naver公开网页接口的KOSPI日线provider，并接入iPhone历史来源信任与KR Regime。解析/路由/API回归覆盖；该未签约接口尚未NAS实网验证，不能据此声称已具备真实覆盖或稳定可用性。
- 2026-11-02 两批 NAS/Python Actions 成功；iOS Swift package compile 连续暴露的源码错误已修复两轮，仍待第三轮 Apple CI 确认；本机无Swift/Xcode。
- 全量145行追踪表结构连续不代表功能全部完成。NAS部署、真实行情/新闻/DeepSeek、Apple构建与截图、真机视觉、跨市场交易日历和实际策略效果仍需分别验收。本轮无提交或推送。

- Regime核心现对有效历史区间内的非有限/非正收盘价、负成交量、部分OHLCV字段和矛盾OHLC失败关闭，factor与reason均明确报告异常；as-of之后的未来坏bar仍被忽略。回归已定义，Apple XCTest未执行。
## 2026-11-01 较早工作树验证快照（已由上方当前校准覆盖）

- 需求追踪核对：`F-B-145-TRACEABILITY.md` 当前有 B-001…B-145 共 145 行，ID 唯一且连续；这只证明追踪表完整，不代表145项均已实现或验收。
- XCTest 定义数按当前源树重新统计：FCore 325 个 `test...` 方法，App UI 11 个方法。当前工作树尚无这些源码对应的 Apple CI 运行记录，本机 executed/passed/failed 均为 0；旧 Actions 的 165/165 与 UI 4/4 只适用于其记录的旧 SHA。
- 当前Windows会话可运行 Python 3.12，但没有 Swift、XcodeGen 或 Xcode。Python全量发现290项，其中288项通过；两个需要PyYAML的测试模块因本机缺少该依赖而未能导入。新增腾讯累计成交量回退和图表未知量提示合同后通过3/3；Home布局合同27/27、追踪合同3/3、Advisor安全/新闻/Home/追踪合同61/61、NAS分钟服务45/45通过；Python compileall、架构边界与差异检查通过。新增 iOS共享流式HTTP读取器对 NAS/Research/DeepSeek/公开行情设定4MB/2MB/128KB上限；NAS上游provider也有严格读取上限。这些结果不能替代 Swift XCTest、iOS构建或视觉验收。
- 最新本地缺陷修复：NAS三个分钟研究builder现在共同严格校验训练/样本外天数及月份集中度阈值，拒绝Python `bool`被隐式当作整数/数值，避免直接调用时以`True`将最低样本门降至1。新增研究回归后NAS分钟服务45/45通过；全量Python288项，286通过、2项因缺PyYAML导入失败。修改尚无Apple CI相关性，未提交/推送。
- NAS研究数值边界复核：有限正价格可能生成Float无法表示的极值收益。VWAP、早盘回撤修复、网格研究过滤非有限或下溢为零的观测并报告拒绝计数；walk-forward摘要另设防线。分钟归档/service/provider/runtime/research/股息及追踪组合测试128/128通过；全量Python 288项中286通过、2项缺PyYAML。未部署/未提交。
- 画像投影保留temporary revision的expiresAt，并在解码后检查as-of时点仍未过期；新增XCTest定义和源码回归。Swift执行未完成。
- Candidate Shadow新增真实账本Fill关联校验：ID、成交时间、证券、买卖方向和关联份额必须与只读Ledger快照一致；测试仅定义，尚无Apple执行证据。当前无App生产调用方，不能称真实成交复盘流程已接通。
- 账户级未归属杂费新增独立现金流水类别；仅改变账户现金，不影响证券成本或盈亏。新增Swift回归定义但未能在当前Windows工具链执行。
- Risk Guard新增同证券、未过期且必须引用的Market Regime证据门槛；严重风险、Risk-Off、Uncertain和不可靠数据会阻止买入类候选，并拒绝高于最新成交价的买入限价。回归已定义，Swift未执行；Provider没有可验证盘口数据，价差/深度门槛仍未实现。
- Local Quant策略资格票据改为绑定“证券×Regime×策略版本”，跨Regime借用会失败关闭；回归已定义，生产本地策略资格包和Swift执行仍待验；NAS为可选数据源。
- 指数供应商若只返回纽约本地墙上时间，秋季回拨重复时点现在拒绝解析，春季跳时不存在时点也拒绝；新增DST边界XCTest定义。全跨市场UTC归一与官方日历仍缺。
- 同一证券若DecisionContext携带多条相互冲突的新鲜Regime观察，Risk Guard现拒绝按数组顺序选一条；回归已定义，Swift未执行。
- 继续保留旧日期段落作为历史证据；其中标为“当前”的旧测试数量、旧HEAD状态不适用于本段时间的工作树。未提交、未推送。

## 2026-10-29 Run 94 验收增量

| 项目 | 当前代码/入口 | 真实执行结果 | 剩余验收 |
|---|---|---|---|
| 首页持仓入口（Ledger未建立） | 首页Portfolio显示“录入现有持仓”，走确认后的初始真实快照 | SHA `5628275f91001cc751cf13da3f90325f709da0c1`，Run [40868674531](https://github.com/ggjj45830/guanpan-f/actions/runs/40868674531)：FCore 165/165，UI XCTest 4/4，XcodeGen、Device/Simulator Build、截图导出、IPA及Artifact均成功 | 自动UI验证不等于实际导入/重启持久化验收；截图未人工审阅 |
| 首页持仓入口（已建立空账本） | 显示“登记已成交买入，开始建仓”，只录入已在券商完成的真实fill | 同上；UI检查包括空账本入口可发现 | 不支持把存量券商仓位凭空快照导入已建立账本；不得伪造confirmed fill |
| App名称与图标 | Bundle显示名“观盘max”，Info.plist选择AppIcon且归档含图标 | Run94 IPA检查通过，ZIP完整性通过；Artifact `12895991023`，SHA256 `59786355b2057fb6faf9c6e39cadedcbd819276486450db8cf7e2939340cb906` | 仅证明构建产物，不证明用户设备已安装 |
| 视觉与实机 | CI导出9张Simulator UI附件 | 导出成功；未进行人工逐张目检 | iPhone Air、主题一致性、实际布局与手势保持待验；不能标视觉PASS |

---

## 2026-10-29 Run 93 真实执行记录

- 代码SHA `27431788f761ae279ad8e5da1821cee5abf55f3f` 的Run 93 [40865524107](https://github.com/ggjj45830/guanpan-f/actions/runs/40865524107) 成功：FCore 165/165；XcodeGen、Device Build、Simulator Build通过；UI XCTest 4/4；截图导出、IPA校验和Artifact上传通过。
- 本轮图表源码调整已编译：左价格轴占用减小6pt，详情页大图表可用高度增加80pt。截图未人工目检；交互、iPhone Air和真机仍待验收。
- 未验证项目不继承PASS：NAS真实历史分钟、新闻源、均价/前收/IOPV可靠数据、DeepSeek真实E2E、既有券商持仓导入、人工视觉均保持未完成/待验证。

---

# 2026-10-29 最新Apple验证与产品修改结论

- 当前远端Swift代码快照：`5303df7dee8a73de27ad460c8ed562fabb3dee95`；文档更新后的main为`2967a58fa2642f31912744dce3d586a70f8dc437`。均为普通快进提交，无强推。
- Run 91 [40862240070](https://github.com/ggjj45830/guanpan-f/actions/runs/40862240070)，验证代码SHA `662365be15ce2c4426ed6063dea413e2c2540693`：FCore **165/165 passed**；XcodeGen、Device Build、Simulator Build成功；UI XCTest **4/4 passed**；截图导出、IPA校验、artifact上传成功。该SHA包含已建立账本的“记录已完成的真实成交”入口及显式二次确认。Artifact `12892922721`，SHA256 `1d2f0fecdb03007416d1d16283d6c0c809939ca6cc7392a7edd63405adf33a41`。
- Run 92 [40862807997](https://github.com/ggjj45830/guanpan-f/actions/runs/40862807997)，验证Swift代码SHA `5303df7dee8a73de27ad460c8ed562fabb3dee95`：FCore **165/165 passed**；XcodeGen、Device Build、Simulator Build成功；UI XCTest **4/4 passed**；截图导出、IPA校验、artifact上传成功。此SHA另将交易仪表盘改为统一浅色终端配色，去除其特有深色系统外观。Artifact `12893216686`，SHA256 `5997cc8b7d6acabb1669b8edb95a426b1af1faabe7ef4884da293bc9573adda0`。
- 两轮产物日志都校验了显示名“观盘max”、Info.plist选择AppIcon且归档内图标有效。CI截图已经导出，**没有人工逐页审阅**；CI执行Simulator UI测试成功也不等于iPhone Air/真机视觉验收。
- 手动成交入口仅允许登记用户已经完成的券商成交，调用真实确认写入器，保留费用、成交流水、Episode及账本校验；不会创建Candidate成交或自动下单。Run91 UI XCTest覆盖的是已有四项导航/空账本/资产场景，**没有直接点击新手动成交表单**，故其可见UI状态尚未单独人工验收。
- 仍未完成：图表在iPhone Air的实际尺寸/手势及截图人工审阅；跨主题所有页面的逐页视觉一致性；NAS历史分钟真实数据进入手机；可靠新闻、前收、均价、IOPV真实来源；DeepSeek真实端到端及真实成交后Advisor复判。产品整体仍不能写成超过B。

---

# 2026-10-29 观盘max 当前真实进度（远端主线）

- 当前 GitHub `main`：`5303df7dee8a73de27ad460c8ed562fabb3dee95`。本轮远端提交按快进更新；未强推、未覆盖远端历史。Windows 本地工作树仍落后且有本地改动，不以本地 HEAD 代表远端。
- Run 90 [40860441713](https://github.com/ggjj45830/guanpan-f/actions/runs/40860441713)，SHA `0e055bcb577f4e233e6295046b91bb7f84aaecd0`：FCore **165/165 passed**；XcodeGen、Device Build、Simulator Build 成功；UI XCTest **4/4 passed**；截图导出、未签名IPA打包校验和artifact上传成功。IPA显示名为“观盘max”、归档AppIcon有效。此Run的截图尚未人工审阅，不能算视觉/实机通过。
- 本轮后续变更：
  - `662365be` 增加真实资产页“记录已完成的真实成交”入口。初始账户快照仍只用于未建立账本；已建立账本的手动成交必须填写真实成交字段、审计说明并二次确认，沿用 `FConfirmedLedgerWriter.confirmFill`，成功后重读账本并重新请求Advisor；不发券商订单、不创建Candidate虚拟成交。该代码尚未有Apple编译/测试证据。
  - `5303df7d` 将交易仪表盘色板改为统一浅色终端层次，移除仅对该主题强制深色的系统外观，降低系统表单与自定义容器黑白割裂。该代码尚未有Apple编译/截图证据。
- Run 91 [40862240070](https://github.com/ggjj45830/guanpan-f/actions/runs/40862240070) 针对成交入口提交 `662365be`，以及Run 92 [40862807997](https://github.com/ggjj45830/guanpan-f/actions/runs/40862807997) 针对主题提交 `5303df7d`，截至本记录均为 **queued**；没有当前Swift修改的编译、测试结果。紧接着将以含文档的当前主线再触发CI；若Run 91/92开始/结束，分别按其固定SHA记录，不互相继承。
- 图表控制顺序/紧凑尺寸已在Run 87 SHA `9004003`验证成功；不代表手势、布局和iPhone Air视觉通过。仍没有本轮人工查看Simulator截图、iPhone Air交互或真机验收。
- 主要未完成项：
  1. 取得含手动成交入口和仪表盘主题修复的完整Apple CI结果，首错按真实日志修复。
  2. 继续改善图表绘图区和分时横轴可读性；对CI截图做实际视觉审阅，不能把截图导出步骤算人工验收。
  3. NAS历史分钟手机响应仍显示HTTP 200契约不匹配/兼容路径404；没有真实指定日分钟进入iOS的证据。NAS不再是核心Advisor前置条件。
  4. 新闻真实来源仍未接入；均价、前收、IOPV无可靠数据时继续Unavailable，不补造。
  5. B/F视觉差距与十主题跨页一致性仍未完成；用户设备反馈F仍不如B。真机iPhone Air待外部实测。
- 下阶段正在做：等待/核对含本轮Swift修改的Apple CI；按首个真实失败收口。CI成功后检查Simulator导出截图的可访问性/视觉问题，并继续修复真实资产入口和图表布局的产品缺口。

---

# Run 88 编译根因追踪（2026-10-29）

- SHA `b410ef6...`：FCore/XcodeGen通过；Device Build因HomeExperience.swift第2068、2070行引用局部作用域不存在的`theme`失败；后续Simulator Build、UI XCTest、IPA未执行。
- 修复在后继SHA：风险语义token通过显式参数传入Advisor结果卡；修复待下一轮Apple CI验证。
- Run 87（SHA `9004003...`）设备构建和Simulator构建通过，UI XCTest仍执行中；不继承为后继SHA PASS。

---

# 当前远端验证快照（2026-10-29）

- 远端 `main`: `b410ef69b5eed880171012b85181607af651caff`。
- Run 87（SHA `9004003...`）：截至记录时 FCore、XcodeGen、Device Build、Simulator Build通过，UI XCTest进行中；截图/IPA未完成。
- Run 88（当前SHA `b410ef6...`）：截至记录时FCore进行中；构建和UI测试未完成。
- 新增实现状态：VOL/MACD选择器已前置并缩小；首页账本状态和Guard风险颜色改用主题语义token。尚无本SHA全套编译/测试结果，无人工Simulator或真机视觉证据。
- 已知缺口继续保留：账本已建立但空仓时缺少明显的初始持仓入口；NAS历史分钟真实接口未通过；新闻来源未接入；iPhone Air主题一致性和图表手势未人工验收。

---

## 2026-10-29 当前验收状态（Run 86）

| 范围 | 当前证据 | 状态 |
| --- | --- | --- |
| Run 86 / SHA `84cf7510a0a0d5314e78ea62f85b99ba14660b97` | GitHub Actions [40857240283](https://github.com/ggjj45830/guanpan-f/actions/runs/40857240283) job queued；无实际执行结果 | Apple CI等待中 |
| FCore / XcodeGen / Device / Simulator / UI XCTest / IPA | Run 85 [40854072875]仅对SHA `31c2010...` 成功：FCore 165/165、UI XCTest 4/4及构建链通过 | 旧SHA证据，不继承 |
| 统一图表指标控件 | `VOL/MACD`移到第一可见位置，控件高度30→24，修改已提交待编译 | 已编码，未编译，未Simulator人工验收 |
| NAS历史分钟 / 新闻 | NAS实际HTTP 200 payload仍未能解析并取得指定日期bar；新闻真实源、自动历史同步未接入 | 未完成/外部实测待证 |
| 图表操作、主题一致性、iPhone Air | 当前无本轮人工截图审阅、真机手势结果 | External Pending |

> Build、XCTest、Simulator截图导出、人工视觉审阅、真实NAS E2E及真机验收分别记录，不相互替代。

---

# F Master Acceptance Matrix

## 2026-10-29 最新本地改动（待Apple CI）

| 项目 | 当前改动 | 当前状态 | 关闭条件 |
| --- | --- | --- | --- |
| 实时分时横轴 | 交易中/午休按实际观测分钟范围绘制；历史图仍用固定完整交易时段显示覆盖空缺 | 已编码，未编译、未运行 | 当前改动SHA完成Apple CI；Simulator看实际曲线和刻度 |
| 图表点选/十字命中 | 命中区左轴从54pt改为与绘图区一致的44pt，右侧均为8pt | 已编码，未编译、未人工手势验收 | CI通过；Simulator点击/长按/拖动验证 |
| MA/图层按钮 | 降低活动层胶囊背景强度，保留触控高度 | 已编码，未编译、未视觉验收 | CI通过；截图对照确认密度与易点性 |
| 主题栏一致性 | 每个主题选择项使用各自manifest语义色，不再全部套用当前主题色 | 已编码，未编译、未视觉验收 | CI通过；切换主题后跨页检查 |
| 设置页数据状态 | 历史分钟、自动同步、新闻状态归到可折叠扩展数据组；明确同步/新闻未接入 | 已编码，未编译 | CI通过；视觉验收确认未隐藏关键NAS状态 |
| 最近真实CI | Run 85 `40854072875` / SHA `31c2010d4324db6fa8251db0199e1c0cd8540113`：FCore 165/165、UI XCTest 4/4，XcodeGen、Device/Simulator Build、截图导出、IPA打包/校验/Artifact上传通过 | 只适用于Run85 SHA；不得覆盖上方未编译本地改动 | 新SHA完整Apple CI执行后更新本行 |
| NAS/行情/新闻 | 历史分钟真实指定日期、前收/IOPV供应商字段、可靠新闻源、自动历史同步 | 当前没有新的实网证据；维持Unavailable/未接入状态 | 手机端实际请求/来源校验通过；禁止用Ready或HTTP 200替代历史数据验证 |
| UI人工验收 | CI截图可导出，但本轮没有人工看图、iPhone Air或实机触控证据 | External Pending | Simulator截图人工审阅 + iPhone Air实机验收分别记录 |

> 远端`main`经GitHub API核实为`31c2010...`，本地HEAD仍是其父`be0b8f...`；Windows fetch受DNS线程错误影响。推送前必须以远端`31c2010...`为父快进更新，禁止从旧本地引用覆盖远端。

## NAS历史分钟 HTTP 200响应诊断修正（待CI）

| 项目 | 实现/证据 | 当前状态 | 关闭条件 |
| --- | --- | --- | --- |
| HTTP 200但历史分钟响应无法识别 | `GuanpanFApp/Sources/FNASConnection.swift`：支持数字证券代码和snake_case代码/日期；bars错误结构不再静默转换为空；诊断实际请求/响应不匹配。依据手机截图中HTTP 200契约错误与旧路径404 | Run 83 FCore成功；Device Build发现日期解码`??`右侧缺少`try`，已做最小修复，等待下一次Apple CI；真实NAS端点/指定日数据尚未验证 | 当前修复SHA Apple CI通过；手机端重新请求能正确返回真实bars或准确显示Missing/Partial及原因；核验证券、交易日、时间、分钟数和来源 |

## Run 82：当前HEAD完整Apple构建（2026-10-29）

| 项目 | 需求/实现 | 实际证据 | 状态/边界 |
| --- | --- | --- | --- |
| 当前HEAD Apple验证 | `5caf26de3a3b65e8497f56470bb355d42ac3b1e9`；Run 81首错修复：将Ledger状态清除封装为HomeModel方法，保持`private(set)`写权限边界 | Run [40843215165](https://github.com/ggjj45830/guanpan-f/actions/runs/40843215165)：FCore 165/165；XcodeGen、Device Build、Simulator Build、UI XCTest 4/4、截图导出、未签名IPA打包/校验、Artifact上传均成功 | 当前SHA的Apple编译与自动测试通过；截图尚未人工审阅；iPhone Air/真机、NAS/行情/DeepSeek实网E2E仍未通过本轮验证 |

## Run 72：图表横轴标签防碰撞（2026-10-29）

| 项目 | 需求/实现 | 实际证据 | 状态/边界 |
| --- | --- | --- | --- |
| 窄屏分时横轴标签 | 按绘图区宽度与最小间距选择显示标签，避免右侧标签挤压重叠 | Run [40812245517](https://github.com/ggjj45830/guanpan-f/actions/runs/40812245517)，SHA `70105ce992dafbbdcd6dee4608b66201a94c79e0`；FCore 164/164、UI 3/3、XcodeGen、Device/Simulator Build、截图导出、IPA和Artifact全部成功 | 自动编译/测试通过；人工视觉截图未查看，iPhone Air未实测，问题不能标人工验收通过 |

## Run 71：自动行情/当前分时刷新节拍（2026-10-29）

| 项目 | 需求/实现 | 实际证据 | 状态/边界 |
| --- | --- | --- | --- |
| 前台行情轮询节拍 | 交易时段内按请求开始时间维持约10秒节拍；新可靠分钟快照进入状态后，当前分时图随状态重绘 | Run [40808942962](https://github.com/ggjj45830/guanpan-f/actions/runs/40808942962)，源码树 `e6bf545b896e0d90c93981f86d4a6e2e9dfc3b9a`；FCore 164/164、UI XCTest 3/3；XcodeGen、Device/Simulator Build、截图导出、IPA校验/打包、Artifact上传成功 | Apple CI通过；不保证上游每10秒都有新分钟数据；日K和NAS历史分钟不由此轮询刷新 |
| 当前分时视觉与交互 | 图线应随真实行情更新且不伪造行情 | CI截图导出成功，Artifact `12869767202`；当前环境无法取得并查看ZIP | 人工截图审阅、iPhone Air、真机手势External Pending，不能标记视觉通过 |
| Git同步 | 不强推；先确认远端未前进并以普通快进推送 | GitHub `main`现为 `94266a3e7d29751dd9b14feb1106901d669bb26b`；本地提交 `fd68bc3`与远端提交树相同（tree `e6bf545...`）；GitHub API非强推快进成功，本地fetch缓存未更新 | 文件树一致；本地origin跟踪引用因DNS错误暂旧；无历史覆盖 |

## 当前图表横轴改动（2026-10-29；Run 72已编译验证）

| 项目 | 需求/实现 | 实际证据 | 状态/边界 |
| --- | --- | --- | --- |
| 分时/日内时间轴避免标签碰撞 | `FUnifiedSecurityChart`按绘制宽度与最小标签间距挑选刻度，避免右端14:30/15:00等标签叠字 | Run 72 `40812245517` / SHA `70105ce...` 实际FCore 164/164、UI 3/3、XcodeGen、Device/Simulator Build及IPA通过 | Swift编译/自动测试通过；截图导出但未人工查看，iPhone Air/设备视觉和手势仍External Pending。无数据或早盘范围不造点 |

## 2026-10-29 当前分时刷新验收补记

| 要求 | 源码 | 当前状态 | 关闭条件 |
|---|---|---|---|
| 活跃交易时段约每10秒刷新持仓/自选/当前证券的实时分钟快照，当前分时图随新快照重绘；较旧/失败响应不能伪造或倒退曲线 | `GuanpanFApp/Sources/GuanpanFApp.swift`; `GuanpanFApp/Sources/FUnifiedSecurityChart.swift`; `FQuoteHTTPClient.fetchCurrentMinutes` | 静态链路确认；新节拍修改已编码但未编译/测试。日K和NAS历史分钟不随该计时器刷新 | 当前SHA Apple CI通过；截图查看曲线点数/时间戳变化；实机核对上游是否按预期提供新分钟 |

## 当前HEAD实测状态（Run 70，2026-10-29）

- `38c269645470a7f960c484dd3ad9b9d579edbeb0`：FCore **164 executed / 164 passed / 0 failed**；UI XCTest **3 executed / 3 passed / 0 failed**；XcodeGen、iOS Device Build、Simulator Build、截图附件导出、观盘max未签名IPA校验/打包、artifact上传全部通过。
- 证据：[GitHub Actions Run 70](https://github.com/ggjj45830/guanpan-f/actions/runs/40805872905)，Artifact ID `12867429801`。
- 仅记录CI级验证；没有据此宣称Simulator截图已人工审阅、iPhone Air或真机验收通过。

## 2026-10-29：首页组合判断保留与时间标识

| 需求 | 源码 | 当前状态 | 关闭条件 |
|---|---|---|---|
| 分析刷新期间保留上一份真实组合判断，明确标记旧结果与生成时间；请求失败不能让首页静默丢失已有结果 | `GuanpanFApp/Sources/GuanpanFApp.swift`; `GuanpanFApp/Sources/FAdvisorVerticalSlice.swift`; `GuanpanFApp/Sources/HomeExperience.swift` | 当前HEAD已编译，Run 70自动测试通过；旧结果只显示为“上次分析”，非自动实时结论 | Simulator验证加载/失败状态；确认旧结果不会被呈现为最新数据 |
| 首页自动本地Quant快速决策 | `Sources/FCore/RealtimeQuantTrigger.swift`及首页 | 尚未完成：只有Candidate价格区间触发器，没有完整本地因子Quant；当前AI组合判断仍由用户显式发起 | 完整确定性Quant + Guard/行情接线，且真实/模拟行情质量与不交易场景验证通过；不得用DeepSeek逐tick代替 |

## 当前视觉整改快照（2026-10-29；覆盖下方较早状态）

- 用户实机反馈：F整体视觉不如B，部分主题只是换色，交易仪表盘黑白块感明显。当前产品结论仍为**F不如B**。
- 当前基线HEAD `0bc40cc` 的Run 68通过FCore 164/164、UI XCTest 3/3、生成工程、Device/Simulator Build与IPA；这些只覆盖HEAD，不等于人工视觉验收。本轮dirty修改尚未编译。
- 本轮已编码：早盘分时范围按可见真实分钟铺开；图表增高、主线变细、图层按钮缩小；盈亏口径折叠；自选随活跃交易时段自动刷新；交易仪表盘改柔和蓝灰surface、极简终端回到浅纸面。
- 本轮验收状态：`git diff --check`通过；本轮Apple CI=未执行；Simulator人工截图=无；iPhone Air=External Pending。不得把以上编码写成视觉修复完成。
- 当前6个核心页相对B仍不作胜出判断，沿用“整体不如B”；三套标杆主题截图对比尚未完成。下一关闭条件是本轮源码经Apple CI，再审实际Simulator截图并逐项人工确认。

## 2026-10-28 当前工作树权威补记（覆盖下方旧验证快照）

- 当前 `main` HEAD `7094d74496f32fa78e69eeb0792e8ee26da48ca6` 已普通push到`origin/main`，工作树干净。
- 当前代码HEAD对应Run `40717961675`（运行号60）；原始attempt及重跑attempt 2均被GitHub取消，job无执行步骤；当前无运行中CI，无当前提交编译/测试证据。不得把取消当成源码失败或通过。
- 当前定义：FCore 164，UI XCTest 3；本轮新增的11个Shadow测试只定义，当前HEAD executed=0 / passed=0 / failed=0。旧CI PASS不继承。
- 新增架构验收：AI建议、Quant信号、市场结果、用户确认成交四者必须分离；Candidate快照不可变；Shadow只存市场事实和成交ID，不可写Ledger；没有Fill关联时Execution=Unknown；明确复核后才可记未执行。Advisor不等待NAS；NAS历史数据仍用于策略Qualification，完整策略包闭环尚未实现。
- 已编码未编译：本地Candidate Shadow日志、Guard前/最终Advisor动作来源字段、报价事件、生命周期到期与市场观察窗口分别计数、仅触发后计算5/15/30/60分钟方向变化与MFE/MAE、Fill ID链接、每证券描述性计数和AI页展示。
- 当前方向性评价明确标记为DeepSeek原始Advisor层；没有对Quant Only、Guard后Final Advice、Advisor Override分别形成可解释成绩，也没有Hold基准。
- 尚未完成：持续行情采样、收盘表现、Candidate基准/Hold与机会成本、策略/Regime成绩分层、真实Quant层输出、结构化WAIT机会规则、显式取消/忽略/部分成交时间线、足量样本和样本外校准。不得称胜率或绩效已验证。
- 正式架构与优先级详见`F-DECISION-SYSTEM-FINAL-ARCHITECTURE.md`；与旧“NAS Research为Advisor必经”行冲突者均为Superseded。

| 新/合并验收要求 | 源码 / 测试 | 当前状态 | 关闭条件 |
|---|---|---|---|
| Advice/Quant/Market/User Execution分离；只有确认Fill进入Ledger | `Sources/FAdvisor/CandidateShadowScorecard.swift`; `GuanpanFApp/Sources/GuanpanFApp.swift`; `Tests/FCoreTests/CandidateShadowScorecardTests.swift` | 已编码未编译；11项定义未执行 | 当前SHA完整Apple CI通过；App层验证无Candidate/Shadow账本副作用 |
| Candidate原始建议不可变，后续事件追加并防止未来数据泄漏 | 同上 | 已编码未编译；有快照重复拒绝及asOf边界测试 | 增加持久化恢复/数据迁移与事件顺序回归；当前SHA XCTest通过 |
| 可信报价触发、Stale不触发、计划到期与结果观察窗口分离 | `FCandidateShadowRecord.evaluation(asOf:)` | 已编码未编译；触发/陈旧/过期/触发后5分钟观察测试已定义 | Apple XCTest通过；真实行情采样覆盖和跨市场时区另验 |
| 成绩单分策略/Regime、Hold基准、收盘机会成本、Advice层对照 | 新架构文档第Shadow章节 | 尚未实现；明确不显示胜率 | 先形成完整数据契约、市场基准与可审计评分实现，再以真实历史/Out-of-Sample验收 |
| WAIT/NO_TRADE成绩 | 当前无区间规则时保存Candidate但显示不可评分 | 部分编码；无结构化WAIT机会规则不能声称有效 | 结构化机会/失效条件、未触发/机会结果和数据质量规则及回归测试 |
| 本地Quant/Regime、Risk Guard、Trigger完整快通道 | `F-LOCAL-QUANT-ARCHITECTURE.md` | 只有旧价格区间Trigger；完整Quant/Guard/订阅与通知未完成 | 对照新定稿从最小可解释因子开始，当前处于fail-closed |
| NAS非阻塞与策略资格分离 | `GuanpanFApp/Sources/GuanpanFApp.swift`及NAS客户端；`F-LOCAL-QUANT-ARCHITECTURE.md` | Advisor不等待NAS；NAS服务E2E与资格包闭环未验证 | NAS离线时基础Advisor与本地Quant流程仍可用；只有缺少任何独立验证合格的策略包时Local Quant才保持WAIT/NO_TRADE，NAS不是强制验证服务 |

## 历史HEAD与验证快照（已由上方当前工作树补记覆盖）

- HEAD `b099c9d0d9c703f56540b6fa4d3d30cfbb3ddefe`，`main`与`origin/main`同步，工作树干净；合并后通过普通push更新远端，没有强推。
- 历史Apple CI Run `40710039609`指向`b099c9d`；其最终run结论为failure，但唯一job取消且无步骤。它不验证本工作树。
- 当前定义：FCore XCTest 153；App UI XCTest 3。旧提交140/140及3/3不可继承。
- NAS不是盘中/Advisor同步依赖，但其历史分钟研究是策略回测、验证、样本外评估和资格签发的依据；核心链仍为实时行情 + 真实Ledger + 本地确定性Quant + Risk Guard + Realtime Trigger + DeepSeek Advisor。当前Quant仅价格区间触发评估器；完整Quant因子、合格参数包、Risk/行情/持久化/UI接线未完成，资产变化Candidate保持fail-closed。
- 已知主要未完成：当前HEAD Apple CI；Quant/Trigger真实接线；B→F六页体验整改；真实DeepSeek成交闭环；Simulator/iPhone Air手势与视觉验收；NASDAQ/NAS不作为核心前置。细节见下方逐项缺口盘点。
## 已知未完成项完整盘点与本轮整改（2026-10-28；当前源树快照）

以下是本轮对当前可读源码、已登记验收矩阵、产品差距审计和实时交接进行交叉核对后的**全部已知缺口**。它不是“全部完成”声明；代码库以外的实机、外部服务和Apple工具链项必须保留待验。下方旧日期段落仅供追溯，若数字或结论冲突，以本段和`F-REALTIME-HANDOFF.md`最新工作树快照为准。

| 优先级/领域 | 当前发现的缺口 | 本轮修改/处置 | 当前真实状态 |
|---|---|---|---|
| P0 账本/安全 | T费用更正、Episode、双成本、T与总收益分离的先前实现尚未在当前dirty HEAD重新Apple执行；本轮没有可运行Swift/Xcode | 没有改写历史fills或Ledger规则；保留当前实现并记为当前HEAD待CI | 153 FCore defined；本HEAD executed=0 |
| P0 本地实时决策 | 已有价格区间Trigger，不等于完整Quant；没有因子评分、Risk Guard接线、报价订阅/持久化、通知或Home/证券详情联动 | 维持fail-closed，不放行资产变化Candidate；架构说明列出缺口，不伪称引擎完成 | Trigger已编码未编译；其余未实现 |
| P1 原生产品体验 | 用户实机反馈F布局/图表明显不如B；当前没有新Simulator/手机截图；B源码供体不是已确认的用户Frozen build | 本轮不宣称UI达标；保留差距审计和逐页非回归清单，外部验收列出待办 | 当前整体仍不如B；人工验收Pending |
| P1 主题/图表 | MA、K线、均线和overlay颜色之前未统一跟随语义tokens；图表有IOPV渲染/图例代码，但可靠IOPV数据源仍无 | 本轮将颜色接入主题tokens；修正矩阵错误的“renderer不画IOPV”描述 | 已编码未编译；IOPV保持Unavailable |
| P1 品牌/安装包 | 工程配置已写显示名“观盘max”、F自有AppIcon源资源存在；当前dirty HEAD尚未Apple构建及安装验证 | 保留现有名称和图标配置，不重复扩展打包链；在CI/实际安装后核对桌面名称与图标 | 源码资源存在；当前IPA/手机桌面未验证 |
| P1 NAS客户端与研究链 | 用户报告手机HTTPS NAS未连接；本轮没有手机现场响应或NAS目标可访问证据 | 基础Advisor不等待NAS；研究样本及资格包仍依赖可用NAS历史数据；不猜测、不改NAS服务端 | 连接与研究覆盖未解决/未验证；基础顾问不阻断，未qualified策略不放行 |
| P2 顾问/成交 | 没有当前HEAD真实DeepSeek→Guard→Candidate→确认成交→Writer→现金/成本/盈亏/T事实→复判E2E | 保持Candidate只读、只有用户确认真实成交写账 | 未完成；需外部Key、服务和真实操作验收 |
| P2 数据/市场 | 实时报价、跨市场实时数据、可靠新闻、均价/前收/IOPV的真实数据质量不能由静态代码证明；本地合格策略参数包及其验证证据未闭环；NAS历史数据可选 | 缺源保持Unavailable；NAS历史数据用于Quant验证，不造研究证据 | 多项未接入或External Pending |
| P2 恢复/提醒 | 通知中心、价格/计划提醒、跨设备同步恢复、完整备份恢复仍是B/F差距项 | 未新增大页面；保留在NRG清单 | 未完成 |
| P3 兼容/交互 | 横屏全屏状态恢复、图表手势冲突、长文本/Dynamic Type、iPhone Air适配、10主题灰度构图对比没有本轮实测 | 不把CI自动截图或UI XCTest当人工视觉结果 | External Pending |
| P4 发布 | 当前dirty Swift未编译，当前HEAD Apple CI未执行；当前Windows无Swift/XcodeGen/xcodebuild | 禁止继承旧CI结果；静态检查通过，架构边界脚本因Python启动器不可用未运行 | External Verification Pending |
| P4 Git | GitHub Desktop Fetch确认本地HEAD相对真实origin/main ahead 1 / behind 8；存在分叉 | 尚未reconcile/push；先审查8个远端提交并保留本地工作树，再普通推送 | 同步处理中；禁止强推 |

本轮完成的源码收口：图表MA、均价/成本/券商成本/IOPV/Candidate叠加、数据质量状态及K线上涨/下跌色改用`FThemeSemanticTokens`；CardGrid、Dashboard、FluidGlass的manifest roleOrder已对齐实际布局。仍未解决的已知源码结构问题：不同layout的几何结构由SwiftUI family renderer实现，Gallery预览只能展示简化role顺序；十主题尚不能纯靠注册manifest扩展。后续须CI与主题截图审阅，不能把Theme Manifest存在写成架构收口。

| 验收项 | 当前工作树证据 | 状态 |
|---|---|---|
| NAS非阻塞请求与资格门 | Advisor无NAS配置时跳过请求；仅引用本机已有新鲜Research Summary。NAS不阻断基础Advisor或Quant；缺少独立验证合格包时Local Quant fail-closed，NAS数据仅可选进入研究 | 非阻塞接线已编码；完整研究/资格包闭环未实现；当前Swift未编译；NAS服务端未改 |
| Trigger状态机回归 | `Tests/FCoreTests/RealtimeQuantTriggerTests.swift`新增12项定义；涵盖等待、接近/触发、过期、stale/未验证/休市暂停、暂停恢复后错过价格区、证券/计划身份错配、显式失效、T信号和Filled边界 | FCore总计153 defined；当前HEAD 0 executed / 0 passed / 0 failed |
| Apple CI/Simulator | 当前本机无Swift/Xcode/XcodeGen；最近Run 58为取消，不能为当前dirty工作树提供构建结果 | External Verification Pending；无当前树Simulator截图/人工验收 |
| Git同步 | HEAD `e500fc84f6dd8acf93cc32305aefcff28e700f4e`；相对缓存origin/main ahead 1 / behind 8，远端实时状态未确认 | 未reconcile、未push；禁止强推 |

当前实现仍缺完整Quant因子（MA/成交量/波动/真实Ledger上下文）、Risk Guard集成、实时行情订阅、状态持久化/通知和Home/Detail接线；资产变化Candidate仍fail-closed。`git diff --check`通过；架构边界脚本因Windows Python启动器不可用而未执行。NAS真实部署、历史分钟、DeepSeek E2E、真实成交闭环和Simulator人工验收仍未完成。不得把定义数或静态检查写成测试通过。

## 2026-10-28 核心架构决策更新（覆盖旧的NAS必经表述）

- 产品决策：NAS不属于实时行情、已安装合格包本地执行或DeepSeek请求的同步依赖；但NAS历史分钟数据是Quant研究/回测/Validation/OOS/Qualification的主依据。核心仍为实时行情 + 真实Ledger + iPhone本地Quant + Risk Guard + DeepSeek Advisor + Realtime Trigger。完整契约见 `F-LOCAL-QUANT-ARCHITECTURE.md`。
- 旧行中将“NAS分钟研究”设为所有 Advisor 请求的同步等待门槛，均被本次决策取代。NAS Research Summary对Advisor是可选缓存上下文；无NAS不可阻断基础Advisor。策略资格必须有可复核的历史验证证据，但数据来源不限定NAS；没有有效qualified包时必须fail-closed。T/网格等动作须由可验证的合格本地Quant条件替代并通过测试后才可放行。
- 快通道不得等待DeepSeek；慢通道由DeepSeek读取真实账本、可靠行情、Quant状态和可选背景信息制定策略。Trigger只提示、不交易、不写Ledger；真实成交仍只由用户确认后经唯一Writer写入。
- 当前实现状态：无NAS时跳过可选研究请求；资产变化Candidate仍以“Quant尚未接入”fail-closed。本地已新增纯价格区间Realtime Trigger评估器，但完整Quant、Guard接线和调用方仍未实现。`FAIGuard`仍保留dayTrade/vwapBreak和grid/gridSpacingReplay历史研究条件；在新的本地Quant安全条件未接好并验证前不移除。
- 当前HEAD的CI Run 58 `40693877430`已取消；没有当前工作树编译、FCore/UI测试或IPA新通过证据。Windows无Swift/Xcode。旧Run结果不得继承到新dirty源码。
- 当前本地FCore XCTest defined=153（包含新增12个Realtime Trigger定义），当前HEAD executed=0；App UI defined=3，当前HEAD executed=0。
- 产品整改仍在进行：首页已编码、未编译；无本轮Simulator人工视觉或iPhone Air验收。NAS HTTPS等待用户新包实测，NAS服务器无修改。真实DeepSeek/Candidate成交闭环未端到端验证。

## 实时覆盖（2026-10-28；以当前工作树为准）

| 验收项 | 当前证据 | 状态 |
|---|---|---|
| HEAD Apple CI | HEAD `8f71a5945940ab3d27e256fdb9e1c0c5baf42c74` 的 Actions run `40669407503`：FCore 140/140、XcodeGen、Device Build、Simulator Build、App UI XCTest 3/3、未签名IPA打包均成功 | 仅覆盖该HEAD；不能覆盖后续dirty Swift修改 |
| NAS HTTPS连接错误诊断 | IMG_6004只显示URLSession连接阶段失败，没有HTTP状态/readyz body；用户确认HTTPS且B同隧道可用。F代码将超时从8秒改为20秒，并细分无法连接、超时、断网及TLS证书错误 | 已编码，尚未编译/执行/送CI；真实NAS连接仍未证实。NAS服务端未修改 |
| “观盘max”品牌与图标入包 | AppIcon 1024×1024 PNG和XcodeGen AppIcon引用均已存在；工程原桌面显示名为“观盘 F”。现改为“观盘max”，IPA文件名改为`观盘max.ipa`，CI将断言Info.plist名称、AppIcon名称和Assets.car存在 | 已编码未验证；须新CI通过并实际安装新IPA检查桌面图标/名称 |
| 当前工作树/远端 | 本地HEAD `b20fb5c`，领先远端基线2个提交；GitHub API只读确认远端`main`仍为`8f71a59`。普通fetch/push仍报`getaddrinfo() thread failed to start`。NAS诊断、产品名/IPA名和包内图标断言已本地提交；状态文档未提交 | 本地HEAD未送CI。run 40669407503不能覆盖b20fb5c；未强推、未用API写入 |
| Simulator/真机 | CI自动构建和UI测试通过；没有本轮人工截图/交互或iPhone Air真机验证 | External Pending |

FCore与UI测试数字只适用于上述HEAD：FCore 140 defined / 140 executed / 140 passed / 0 failed；App UI 3 defined / 3 executed / 3 passed / 0 failed。当前未提交NAS诊断改动未执行。

## 2026-10-28 iPhone Air反馈与图表/图标/连接修复（当前工作树）

| 范围 | 当前发现/修改 | 状态 |
|---|---|---|
| iPhone Air可用性 | 用户实际反馈IPA页面整体排版混乱；目前没有本轮iPhone Air截图或可交互Simulator证据，旧CI截图不能代替真机布局验收 | 明确未通过人工验收，需新IPA检查并根据具体页面问题继续修复 |
| B/F图表交互 | 对照只读`GuanpanNext-work/ios/Sources/UnifiedChartView.swift`，B有可切换并保存的图层按钮；F旧版只有静态图例。当前F已编码MA5/10/20/60/250、成交量及真实叠加线显隐和可见序列定纵轴，并新增隐藏MA价格范围测试定义 | 未编译/未执行；旧CI不覆盖 |
| F专属图标 | 增加1024×1024、无Alpha的F图标并接入XcodeGen Asset Catalog；不引用B版图标 | 已编码；需XcodeGen/Asset Catalog编译与新IPA确认 |
| NAS连接诊断 | F连接页基于根URL检查`/readyz`，现也接受用户复制的`/readyz`完整地址并标准化；增加本地网络权限/DNS/端口/ATS提示 | 已编码；没有目标NAS地址与iPhone现场，本轮无法做真实连通测试 |

FCore XCTest当前defined=140；新增隐藏MA轴范围测试0 executed。App UI XCTest=3 defined，本轮0 executed。完整Apple CI run `旧执行编号省略` 的139/139和UI 3/3是旧源码证据，不覆盖上述Swift/Asset Catalog修改。

## 2026-10-28 当前工作树静态查错补充（暂停 NAS）

| 范围 | 发现 | 证据/状态 |
|---|---|---|
| Git与CI | HEAD `676da3bd5d963900337cbcc970c083b110e4416c`，本地与`origin/main`对齐；仅两份状态文档未提交。成功Apple CI run `旧执行编号省略` 对应`f366542`，当前Swift源码与其无差异 | 可沿用为同源码构建证据；本轮没有新CI |
| Advisor/Ledger边界 | 静态架构检查确认Advisor target不依赖Ledger writer；真实Advisor选择组合/证券范围和Candidate确认写入路径仍符合只读/用户确认边界 | `verify_architecture_boundaries.py`实际运行通过；真实在线闭环未执行 |
| 主题布局 | Gallery读取manifest的roleOrder，真实HomeLayout使用family-specific布局；本轮已把CardGrid、Dashboard和FluidGlass顺序对齐实际编排；Bento/星图/动态Bento的几何结构不能由单一roleOrder完全表达 | 顺序不一致已编码修正、未编译；Gallery预览/实际结构仍需CI和主题截图核验 |
| 图表主题色 | Unified chart的MA/K柱/成本/Candidate此前硬编码 | 本轮已接入`FThemeSemanticTokens`，已编码未编译，待主题截图对比 |
| IOPV renderer | `FUnifiedSecurityChart.swift`已有可用IOPV观察的图例和水平线绘制，并纳入可见纵轴；目前无可靠真实来源，故实际状态仍应Unavailable | 渲染路径已编码；来源仍不可用；不得伪造数据；截图待验 |
| 图表Unavailable文案 | 均价/前收/IOPV状态行是静态文本；当前确无可靠来源所以目前诚实，未来来源接入后会误报 | 当前非数据造假；记录为接入真实序列时必须修正 |
| 本轮验证限制 | 结构测试因缺PyYAML未执行；本机Swift/Xcode不可用；未运行Swift测试、Simulator人工交互或实网服务 | 不计入通过，不把旧CI称为本轮执行 |


## 当前F工作树状态（2026-10-28；HEAD 6eede46）

| 验收项 | 当前证据 | 状态 |
|---|---|---|
| 本地/远端同步 | GitHub API确认远端`main=94bdb8e0090e5c2b5be91cafeef8fb07d887ad8e`；本地正在其上追加纯文档状态校正，完成后ahead 1。命令行普通push报DNS线程启动失败，GitHub Desktop Fetch曾长时间挂起，本轮状态校正是否推送尚未确认。`7504ac5`误含临时诊断日志，已用普通撤销提交`6eede46`移除；未改写历史 | 撤销提交已同步；当前交接校正待推送；临时文件已从当前树移除 |
| Apple CI | 当前源码树与CI通过HEAD`f366542242e995ec62b068273da65ab2f7f9f860`一致；run`旧执行编号省略`真实执行FCore 139/139、XcodeGen、Device Build、Simulator Build、UI XCTest 3/3、截图导出、未签名IPA检查均成功 | 源码已由完整CI验证；当前文档/撤销提交未单独重跑 |
| NAS→iOS静态契约与定向逻辑 | Python定向逻辑13/13通过：exact-date查询、有限补采状态、provider coverage终态、质量/置信度、Research Evidence时点门控/紧凑契约/digest、Eastmoney日期/成交量解析与请求构造。NAS API与iOS客户端路由/关键字段静态对齐；Advisor Research请求带asOf与90质量门。另有1项本地HTTP测试执行后因`WinError 10013`拒绝localhost socket报ERROR；宽provider suite因日历存储用例挂起而中断。未访问真实provider/NAS | 静态接线和定向逻辑通过；本地HTTP测试受环境限制；真实分钟获取、iOS图表展示及进入DecisionContext的E2E未验证 |
| 手工Simulator/真机 | CI自动截图附件存在；本轮未人工逐图审阅。没有Windows本机Xcode/Simulator或真机证据 | External Pending |
| NAS历史分钟/AI闭环 | 没有真实provider补采到iOS历史分时并进入Research Evidence/DecisionContext的端到端证据；没有真实DeepSeek→Candidate→用户确认成交→Ledger→Advisor复判证据 | 未完成 |
| 十套主题 | 十套Home layout与共享role renderer已在当前CI源码树中Build/XCTest通过；十主题截图构图对比及切换状态保留未人工验证 | Swift已编译；视觉验收待做 |

> 本节为当前状态覆盖；下方较早矩阵条目保留追溯信息。通过一次编译/自动UI测试不代表人工Simulator、真实服务或真机验收通过。

## 2026-10-28 最新 Apple CI 通过（run 旧执行编号省略）

| 验收项 | 当前HEAD实际结果 | 说明 |
|---|---|---|
| FCore XCTest | 139 / 139 executed / passed / 0 failed | run `旧执行编号省略`，HEAD `f366542242e995ec62b068273da65ab2f7f9f860` |
| XcodeGen / Device / Simulator Build | 全部成功 | macOS 15.7.9 / Xcode CI runner |
| App UI XCTest | 3 / 3 executed / passed / 0 failed | 设置页DeepSeek SecureField首屏可发现性修正通过；原断言未移除或放宽 |
| Simulator截图导出 | 成功 | 导出导航截图8项、资产截图1项；自动截图不等于人工视觉或交互验收 |
| 未签名IPA | 打包成功，ZIP完整性检查通过 | 未签名，不代表真机安装/运行 |

远端`main`已包含当前HEAD`f366542`。当前提交CI全绿；人工Simulator手势/视觉、真实NAS/行情/DeepSeek端到端、真机仍为外部待验证。源码修正是设置页section顺序调整，没有更改UI断言。

## 2026-10-28 最新 Apple CI 证据（run 旧执行编号省略）

| 验收项 | 实际结果 | 当前处置 |
|---|---|---|
| FCore XCTest | 139 defined / 139 executed / 139 passed / 0 failed | 当前CI提交`476e429e12ad131a4f0ccbc2c5c4fddf5948f80b`通过 |
| 工程生成与App构建 | XcodeGen成功；iOS Device Build成功；iOS Simulator Build成功 | 当前CI提交通过 |
| App UI XCTest | 3 defined / 3 executed / 2 passed / 1 failed | `testFivePrimaryDestinationsAreDistinctAndDiscoverable`在`PrimaryNavigationUITests.swift:53`找不到首屏不可访问树中的DeepSeek SecureField；产品将在线AI设置前移到主题Gallery之前，原断言保留，修正待新CI验证 |
| Simulator截图导出 | CI执行成功，导出43项UI附件 | 自动截图已导出；没有人工视觉/手势验收证据 |
| 未签名IPA | 步骤跳过 | UI Test步骤失败后未打包 |

产品修正已本地提交`5eeee5d57b4957927598a985a74883af278ebcd8`，只调整`SettingsOverview`设置段排序并保留UI断言；未Apple编译。随后`3f5e045`、`27f6a9d`仅更新交接记录。GitHub API读取确认`main`仍是父提交`476e429e12ad131a4f0ccbc2c5c4fddf5948f80b`，但本地fetch与普通push均因`getaddrinfo() thread failed to start`失败，因此新CI未触发；GitHub Desktop所选仓库路径与当前F工作区不一致，未通过该副本推送。旧run的139/139不能继承给`5eeee5d`。

## 2026-10-28 远端同步补记

- GitHub Desktop已对真正的F工作目录Fetch后普通Push；远端`main`现与`0fbf76d2ae3aed4cb5f32cbedbf6fe23180a446d`一致。推送只包含已提交历史，不包含当前两份未提交文档改动或受保护临时目录。
- 当前HEAD的Apple CI尚未由检查状态证实；历史CI不能继承为当前HEAD通过。

## 2026-10-28 手续费修正CI结果

| 验收项 | 实际执行证据 | 结果 | 当前处理 |
|---|---|---|---|
| 卖出手续费事后更正后已实现盈亏，basis保持不变 | Actions run `旧执行编号省略`：FCore 139项实际执行，138通过/1失败；唯一失败是将`48.00 - 0.35 - 40.04`期望为7.51 | 当前提交未通过；App/Simulator/UI步骤未执行 | 计算与Ledger模型一致应为7.61；测试期望已修正，等待新HEAD Apple CI实际执行 |

修正提交`476e429e12ad131a4f0ccbc2c5c4fddf5948f80b`已普通推送并与远端`main`确认一致；其Apple CI仍待实际检查结果。

## 当前主题/布局实现状态（2026-10-28）

主题验收ID沿用F扩展项，不替代或重编号B-001～B-145。当前实现仅为未经Apple编译的源码状态：

| F需求 | 当前实现证据 | 状态 | 外部验收 |
|---|---|---|---|
| F-THEME-01 Manifest注册与扩展性 | `ThemeLayoutManifest.swift`含十个theme ID、十个layout family、语义token、间距、材质/动效及呈现描述；Home结构仍含显式family分支，新增主题尚不能只注册Manifest完成 | 部分编码、未编译 | Apple编译/XCTest；后续验证是否能以纯展示注册扩展 |
| F-THEME-02 共用业务role renderer | `FHomeRoleRenderer`复用资产、市场、跨市场、组合Advisor组件/唯一route；星图中心只显示Portfolio scope结果 | 已编码未编译 | 检查各布局role唯一与路由正确 |
| F-THEME-03 五种新增首页结构 | ink editorial、minimal terminal、fluid glass、radial map、adaptive Bento分支已编码 | 已编码未编译 | 十主题截图灰度结构差异待验 |
| F-THEME-04 原五布局接入共享roles | editorial/grid/dashboard/magazine/static Bento改用role renderer | 已编码未编译 | Simulator人工操作待验 |
| F-THEME-05 可切换Theme Gallery | 十个选择行含小型结构预览/说明/密度/场景；仅更新theme AppStorage | 已编码未编译 | 导航状态、证券/图表状态保留待实测 |
| F-THEME-06 专业详情页稳定 | 当前没有复制Security Detail/Chart renderer；episode/broker cost、MA、IOPV、Candidate、买卖点token虽登记，尚未接入统一图表 | 部分编码 | 图表/日期/缩放/横屏状态待Simulator验证 |
| F-THEME-07 真实数据状态覆盖与可读性 | 未注入任何主题mock持仓；主题预览只显示结构示意 | 尚待验证 | 空仓/Unavailable/Partial/风险/Candidate等逐态截图 |
| F-THEME-08 外观兼容 | Manifest以动态浅/深色语义Token跟随系统外观；护眼与Dynamic Type仍待完成 | 部分编码 | light/dark需逐主题截图、eye-care、文字缩放和小屏待验 |

## 关键Ledger字段当前实现边界

| 能力 | 当前源码事实 | 状态 | 未完成条件 |
|---|---|---|---|
| Security Daily P&L / 今日盈亏 | DecisionContext在同日新鲜当前价、可信前收、Ledger日期/成交摘要和期末持仓齐全时调用确定性公式；开盘数量由期末份额及当日真实买卖量校验推导，验证时重算以拒绝篡改；首页和证券页随时效显示结果或Unavailable | 已接线源码；Swift测试与设备验收未执行 | 运行无成交、盘中多笔/清仓重买、跨日、前收/现价过期、数量不守恒、序列化篡改和极值算术用例；与真实券商日盈亏对账 |

本轮没有新Apple执行证据：FCore最近定义计数139仍是defined，不得改写为passed；本机无Xcode/Simulator。设计文档存在或Swift源码存在均不等同完成验收。

同步补记：主题实现提交为本地`8dfb656`；GitHub API最近核对远端`main=7a2d63e`且为其祖先，但本机fetch/push均因DNS线程启动失败而未完成，故主题改动尚未触发Apple CI。

## 当前工作树续更（2026-10-28；本段以本文开头主题表及实时交接的较新状态补正）

- 本地HEAD仍为`4f8577b4c405001b6d982d3cd7d4bccc1e18c38e`（只作追溯）。当前工作树有主题/布局Swift及验收文档未提交改动；保护临时目录`.task-python-temp-b252c94955274b7c90bce865b594fca4/`原样未跟踪，未触碰。FCore静态定义计数139；当前未编译主题改动没有新增测试执行证据。当前HEAD没有Apple编译证据；远端实时状态未fetch确认，未推送。

- 新增现金-only对账入口已编码：用户选择增加/减少方向，填写正数金额、原因和确认说明，经`FConfirmedLedgerWriter.confirmCashMovement`追加现金流水；证券成本、持仓数量及盈亏不受影响，更新后旧Candidate失效。当前仅为静态源码存在；未Apple编译、未执行UI/XCTest或人工操作验证。
- 新增一项FCore回归定义`testCashOnlyReconciliationLeavesSecurityPositionsAndCostsUnchanged`，验证未归属现金费用只影响现金，不改变持仓、成本、成交及逐笔费用更正记录。FCore静态定义数为139；新增测试尚未编译/执行。

- 本轮NAS回补队列与实时session边界回归实际执行9项通过：runtime 5/5；队列终态/有限重试/显式重试/近期窗口4/4。provider全套16项为13通过、2失败、1错误；archive 44项为42通过、2错误；service 33项为30通过、3错误，失败/错误受当前Windows环境的目录句柄、硬链接和localhost socket能力限制，详见`F-REALTIME-HANDOFF.md`。不将这些受限套件记作全绿，也不据此声称NAS真实历史数据端到端完成。
- GitHub同步再次失败：本地HEAD仍为`a5a8557c64f7cc43e09a38d570c752e4d915d058`，`origin/main`仅为缓存跟踪点且本地ahead 19；多次fetch均报`getaddrinfo() thread failed to start`，远端HEAD未知，未reconcile/未push/未触发Apple CI。

- Advisor静态查漏已移除Candidate估算费必须≥¥0.10/做T≥¥0.20的硬拦截，本地提交`9c641da`；实际成交费仍以用户确认的真实金额为准。该Swift修改尚未Apple编译/UI验收，需随手续费更正送CI。

- NAS队列静态查漏发现容器重启会重排`permanent_unavailable`/`out_of_provider_coverage`终态。当前已修正为自动启动保留终态，显式补采仍可重试；Python定向用例2/2通过。未做真实NAS部署验证，历史provider覆盖没有变化。
- 已生成`../F-NAS-QUEUE-RETRY-FIX.zip`（20文件、56,680字节；ZIP完整性及关键NAS源码存在检查通过），供用户部署修复；未构建Docker镜像、未部署NAS。

- 本轮编码逐笔手续费事后更正：追加`FFillFeeAdjustment`、现金补录日结算、有效手续费与成本basis重放、只读历史/日汇总/realized/T投影、现金流水更正行、用户确认Writer入口与资产页简单更正表单；旧fill不改。新增6项Ledger回归测试定义（含旧周期清仓卖出补扣/退费、重开Episode隔离及Archive恢复）。全项仍未Apple编译/执行，详见实时交接和F-145。

- 多主题/多布局实现状态见本文件开头“当前主题/布局实现状态”：十个Manifest、十个Home layout family、共享Home role renderer与Theme Gallery已编码但未编译；Simulator布局、色彩/动态字体和交互验收仍待完成。

- 手续费更正实现/测试已提交于`a84c41976ed094a5fe91b8d9185167b848a8a836`，同步验收文档也已提交。远端已指向转移后的`ggjj45830/guanpan-f`，最新fetch因DNS thread启动错误失败，远端实时状态未知；本地存在未推送提交，受保护临时目录未动。
- T Contribution现按时间排序和FIFO批次只匹配先卖后买的实际配对份额；1000卖/500买回只计500及按比例卖出费；普通卖出/减仓不当作T；买回早于卖出或买回量超过此前剩余卖量保持Unavailable。源码/测试位置：`Sources/FCore/DailyTradeSummary.swift`、`Tests/FCoreTests/LedgerSchemaTests.swift`。
- FCore测试定义方法当前静态计数138。当前工作树compile、XCTest执行、passed/failed均无执行证据；旧CI #41 `旧执行编号省略`（130/130）仅验证`7a2d63e`，不能覆盖T FIFO或手续费修正。App/UI旧CI数据同样不验证本轮Swift修改。本机无Swift/Xcode/XcodeGen。
- 事后手续费修正已编码，仍未编译/执行：原始fill和原始`costBasisRemoved`保持不变；追加事件负责补录时现金结算，经济投影按有效费用回算basis/已实现和Episode结果。新增6项测试定义，覆盖买入费用补录/冲回、部分卖出basis、卖出手续费、跨Episode隔离、清仓卖出手续费补扣/退回、Writer/Archive恢复和负现金原子拒绝。UI XCTest/Simulator验证仍缺。
- NAS历史分钟进入iOS/Research Evidence、DeepSeek真实E2E、Candidate→确认成交→Ledger→Advisor复判、Simulator人工手势/视觉仍未通过真实端到端验收；人工Simulator为External Pending。

## 较早工作树快照（2026-10-28；已由上方续更覆盖，保留供追溯）

- Tools全量Python现有测试本轮实际执行112项：105 passed / 2 failed / 5 errors。失败/错误来自Windows POSIX目录fsync不兼容及运行时缺PyYAML；详见实时交接。此结果不能表述为全部通过。
- NAS分钟定向测试最近一次真实执行97项：92 passed / 2 failed / 3 errors。localhost和硬链接限制在较宽权限重跑后解除；剩余均为Windows目录fd/fsync差异，Linux NAS/CI待验证。较早受限执行为89/2/6；均非全套NAS通过。
- 当前F源码状态以本地工作树为准，HEAD为`5f2a1f7`；最近一次可成功读取的`origin/main`跟踪点为`7a2d63e`，本地领先7个提交。`git fetch origin main`本轮仍因`getaddrinfo() thread failed to start`失败，因此此跟踪点不是远端实时证明；没有推送/强推。Tracked Swift/NAS源码干净；本次矩阵与交接文档尚未提交。锁定临时目录`.task-python-temp-b252c94955274b7c90bce865b594fca4/`原样保留。
- 最近可核实的旧代码CI run `旧执行编号省略`：FCore 130 defined / 130 executed / 130 passed / 0 failed；XcodeGen、Device Release Build、Simulator Build、App UI XCTest 3/3、截图导出及未签名IPA步骤成功。该CI验证源码提交`7a2d63e`，**不包含之后本地新增的T Contribution成交顺序保护**。
- 当前FCore仍定义130个测试；相对该CI新增的T顺序实现尚未编译/执行，当前修订的验证状态为0 executed / 0 passed / 0 failed；不能把旧CI的130/130套用于当前HEAD。App UI定义3项，最近旧代码CI 3/3成功；这不等于本地后续FCore修改后的App重新Build/UI通过。
- 用户日志`logs_110101703179.zip`：FCore 130项中1项失败，原因是旧断言错误期待清仓后Broker Display Cost变为nil，实际保留`10.35`符合证券级对账语义。后续`logs_110103476656.zip`中FCore 130/130通过，但Device Build首错是`HomeExperience.swift:354` Optional类型缺上下文；该项后来由`7a2d63e`修复，run `旧执行编号省略`提供后续全绿证据。
- 本地Windows没有Swift/Xcode/XcodeGen/Simulator。无本轮人工Simulator/真机验收。Python/NAS最近可用证据为定向77/77 passed（非全套；环境受限项未计通过）；本轮未重跑。实时分钟有NAS部署归档证据，历史分钟provider空响应/断连，历史分钟NAS→iOS→Research Evidence仍未E2E；真实DeepSeek及成交后AI复判未E2E。
- 已完成的当前源码审计：T Contribution原实现只核对周期总卖出/买回数量，未约束实际顺序；当前本地版本已按成交时间逐笔确认先卖后买、买回数量不超过尚未买回卖出量，并增加反序回归断言。该修正仅为已编码/未验证。Advisor与FLedgerWrite依赖隔离，Candidate不能直接写Ledger；真实fill仍要求用户填写实际成交和显式确认。
- 当时对费用差额对账的静态设计发现仍未实现；该历史状态已由上方当前续更覆盖：事后fee adjustment模型、资产页UI与6项回归测试已编码，并记录在提交`a84c419`，仍待Apple编译/执行。
- 当前最高缺口：①把T顺序修正送Apple CI；②事后手续费差额与原成交日盈亏/剩余成本的一致回算；③NAS历史分钟进入iOS并供Research Evidence/DecisionContext使用；④Simulator人工交互/视觉验收；⑤真实DeepSeek Candidate→用户成交→Ledger→重新判断闭环。

## 最新实时CI与工作树状态（2026-10-27 15:19 Asia/Shanghai）

## Ledger盈亏口径增补（2026-10-27）

| 交叉追踪 | F源码/测试 | 当前状态 | 仍需验证 |
|---|---|---|---|
| B-018 / B-027 / B-029 / B-130 / B-145：本轮主成本与券商成本分离；Security Daily P&L、Episode P&L、日已实现、Lifetime P&L、T Contribution分离；同日清仓后买回不重置全天盈亏 | `Sources/FCore/SecurityPnLFacts.swift`; `Sources/FCore/DailyTradeSummary.swift`; `Sources/FCore/LedgerSchema.swift`; `Sources/FLedgerWrite/LedgerTransactions.swift`; `Sources/FAdvisor/DecisionContext.swift`; `GuanpanFApp/Sources/HomeExperience.swift`; `GuanpanFApp/Sources/FUnifiedSecurityChart.swift`; `Tests/FCoreTests/LedgerSchemaTests.swift` | 已编码，未Apple编译/未执行新增测试。当前FCore 129项defined，最近真实执行仍为旧CI 121/121 | 可靠前收/期初数量供给、隔日场景、Broker成本多轮修正/对账、Advisor逐问句字段选择、Simulator UI与真实行情验收；不得把Unavailable改成推算值 |

- Run `旧执行编号省略` / `5169df6`：FCore 121/121 passed；XcodeGen、Device Build、Simulator Build成功；App UI XCTest失败（Actions UI Test步骤耗时4m59，详情页面仅显示exit code 65，首个断言尚未取得）。
- 当前待CI设置表单修正：Form增加 `settings.form`，测试针对该容器滚动并验证NAS按钮可点击；测试失败路径明确输出容器accessibility树后退出。不降低断言标准。
- F-145跨市场验收设计已补充时区/日历/DST、no-lookahead、相关/领先/共同风险区分、证券级滚动画像、底层资产与场内ETF溢价条件分离、wait/no-trade和完整Evidence元数据。本项仍未编码/实证。
- 本轮修改未编译；本机无Apple工具链。当前阶段优先触发CI并拿到失败断言，不将自动Simulator启动记作人工验收。

## 最新实时CI与工作树状态（2026-10-27 14:38 Asia/Shanghai）

- Actions run `旧执行编号省略` / commit `773608d`: FCore **121 executed / 121 passed / 0 failed**；XcodeGen、Device Build、Simulator Build成功；App UI XCTest **3 executed / 2 passed / 1 failed**。
- 首个且唯一失败为 `PrimaryNavigationUITests.swift:54`，设置页表单尚未滚动到NAS连接区时查询NAS按钮。测试现改为滚动到按钮并要求其 `isHittable`；修改待CI执行，不能记为通过。
- 当前工作树有未提交UI测试修改；本机没有Apple工具链。此前截图导出成功，但截图图像未人工检查。详见 `F-REALTIME-HANDOFF.md`。以下较早CI记录仅为历史证据。

## 实时状态覆盖（2026-10-26；以下旧快照保留作历史）

> 2026-10-27 Actions run `旧执行编号省略` 对已提交HEAD完成FCore 121/121、工程生成、Device/Simulator Build；UI主导航用例失败，具体断言日志未取得。本机仍无Xcode且fetch/push受网络限制；当前dirty Swift修改未编译。远端CI曾成功执行，不能称CI整体不可用。

- 当前 F 工作树：`main` / `4d258f199c7575f84251154b8929c30fba271508`，不以该 commit 代替实时源码状态。当前工作树有未提交改动；明细以 `F-REALTIME-HANDOFF.md` 为准。
- Apple CI：最新可见run `旧执行编号省略` 对已提交源码执行FCore 121/121、XcodeGen、Device/Simulator Build；App UI测试失败。Annotation仅给出exit code 65，精确断言待原始日志。当前工作树dirty Swift代码不在该run中。
- 本地无 Swift/Xcode/XcodeGen。当前工作树最新 Swift 改动是 Advisor 组合意图优先修正，尚未编译/执行；不得记为通过。当前 NAS/Python改动也没有本轮新测试结果。
- A/B/F追踪表现已补充逐项核验字段。145条的源码/测试位置是按F验收映射给出的候选锚点，仍需逐条确认；A源码当前不可读，B状态不继承，所有F条目仍不得据此宣称通过。
- 本轮静态复核：真实Ledger流水重放/episode保留、候选与真实写账边界、统一图表renderer接线未发现已确认的架构性违规；图表交互/旋转、实时数据质量、AI/NAS/DeepSeek端到端仍未通过运行验收。

## CI续记（2026-10-26 19:43 Asia/Shanghai；覆盖较早运行快照）

- run `旧执行编号省略` / `016a1a3`：FCore 121/121、XcodeGen、Device/Simulator Build、App UI 3/3、截图导出和IPA均通过。
- 截图人工确认日K图可见并含真实日K、MA与量柱；历史分钟截图与日K仍相同，故历史分钟可见性/日期切换没有通过人工验收。
- 新本地未提交：强制历史区滚动、资产摘要防横向截断、简化日K时间轴标签。尚未验证，不改验收状态。

## CI续记（2026-10-26 19:32 Asia/Shanghai；覆盖下方旧快照）

- 当前已推送提交 `c96a17e` 的 Actions run `旧执行编号省略`：FCore 121/121通过；XcodeGen及Device/Simulator Build成功；UI 3执行、2通过、1失败（详情日K标题经8次滚动仍不可见）；截图导出成功、IPA跳过。
- 当前本地改动：统一图表Canvas的拖动改用 simultaneousGesture，避免阻断外层详情滚动。尚未编译/测试，验收项不更改状态。Python/NAS未执行。

## CI续记（2026-10-26 19:20 Asia/Shanghai；覆盖下方旧快照）

- HEAD `1c10912` 已推送；当前源码后续修改未提交，尚无其编译/测试证据。
- Actions run `旧执行编号省略` 对应提交：FCore 121/121通过；XcodeGen、Device Build、Simulator Build成功；UI XCTest 3执行、2通过、1失败（一个测试用例内两个标题可见断言失败）；截图导出成功；IPA跳过。
- UI失败表明证券详情日K、历史分钟标题未被当前滚动方式滚动到可见。新本地修正未验证；不把矩阵需求改绿。Python/NAS本轮未执行。

## 最新实时验证覆盖（2026-10-26 18:20 Asia/Shanghai）

- 本地工作树 HEAD `1c10912e8d1c2a0b6fdc3720b73f6fada28c5e20` 相对 origin/main ahead 1；CLEAN；该本地UI/窄屏布局修正尚未推送或验证，不更改任何验收项为通过。
- 最新远端成功运行 `旧执行编号省略` 对应 `04b0deb`，UI XCTest 3/3通过并导出8张截图；截图人工查看发现刷新行右侧裁切、页面滚动未被旧用例验证到，故相应可用性验收仍未通过。
- FCore最近明确工件结果来自run `旧执行编号省略`：121/121 passed、0 failed。当前本地HEAD不含于该运行。精确当前提交测试状态：FCore 121项defined，当前提交executed=0/pass=0/fail=0；UI 3项defined，当前提交executed=0/pass=0/fail=0。旧CI结果保留为追溯证据，不继承到新代码。
- 本轮 Python/NAS未执行。Simulator视觉通过、图表数据/交互通过、真实服务联调及真机仍待验收。

本矩阵由 F 产品红线、A/B Frozen 源码裁决、F 自身实施范围及 B 版 Master Acceptance Matrix 的 145 项需求共同形成。B 145 项需求追踪见 [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)：保留原编号和需求来源，逐项标注 F 处理结论；不继承 B 实现状态或测试证据。A/B 的测试结果都不算 F 通过。每项先标为 `defined`；只有 F 自身执行并保留证据后才能更新为 `executed`、`passed` 或 `failed`。外部条件另标 `external pending`。

## 当前 F 验证快照（2026-10-26）

FCore XCTest：121 defined / 121 executed / 121 passed / 0 failed；两项图表价格范围回归已在Actions run `旧执行编号省略`通过。App UI XCTest：3 defined / 3 executed / 3 passed / 0 failed，但该结果对应本轮新UI代码改动之前的版本。XcodeGen、Device/Simulator Build和未签名IPA成功。Simulator截图附件及证券代码查询导航刚加入，待下一轮CI验证；空账本未注入虚构持仓，真实Episode详情仍未做数据级验收。

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
| F-16 | AI 最终建议读取真实持仓、行情、可选背景与风险证据 | defined | DeepSeek provider、只读账本快照、DecisionContext、Risk/AI Guard及组合/证券scope已编码；NAS历史分钟与Research Summary均为可选研究增强且单次请求不等待NAS；新闻仅使用新鲜内存缓存并在后台更新，无缓存则标Unavailable；本地Quant尚未接入，资产变化候选由“Quant未接入”fail-closed；当前HEAD未编译/未联调 |
| F-17 | T、网格、回本仅为 AI 可调用分析工具，不自动交易 | defined | NAS研究工具保留为可选能力；FAIGuard仍保留T/vwapBreak、网格/gridSpacingReplay条件，须待本地Quant安全条件替代并验证后才可改；策略和真实服务适配未完成。旧119项CI数字仅为历史，不代表当前HEAD |
| F-18 | 行情、分时、日K、MA250、IOPV、盘口标注来源/新鲜度 | defined | 统一`FUnifiedSecurityChart`由当前/历史分钟和日K共用；MA/成交量/成本/券商成本/Candidate按可见层参与范围；当前IOPV仅进入实时分时参考线，不进入历史分时或日K纵轴/绘制，图注明确无历史IOPV序列。实时分时快照现有本机版本化原子缓存，重启后最多恢复250只/30天且保留原行情时点；Advisor/Trigger继续按120秒严格验新鲜度。IOPV没有可靠来源，保持Unavailable。Swift与图表语义色改动未编译；视觉、手势和真机仍待验 |
| F-19 | 可选NAS归档/研究、跨市场和新闻与真实账本隔离 | defined | NAS v6曾有用户提供的实时分钟归档烟测；NAS不再是Advisor核心前置。NAS历史补采曾返回empty source response；跨市场/新闻/iOS端到端和长期运行未验证。跨市场非对称关系与证券级映射没有合格样本，不进入DecisionContext |
| F-20 | 同步、离线冲突、通知与恢复状态可见且不丢账 | defined | 三通道策略已编码；传输、离线队列、通知 UI 和恢复体验未实现；FCore 119项全量已执行通过，但这不覆盖缺失的产品功能 |
| F-21 | AI 聊天、导航、图表、横屏和设备布局可用 | defined | 原生五Tab与独立NavigationStack、真实账本/行情、AI顾问输入和结果页已接线；当前/历史分钟和日K已复用共享SwiftUI renderer。App UI XCTest 3/3通过（run 旧执行编号省略；覆盖导航、Advisor主要控件和资产页基础结构）；图表功能/视觉、横屏和设备布局验收仍未完成 |
| F-22 | 十个独立主题的 token、页面一致性、可读性和设备截图验收 | defined | 十个首页layout family、语义token与共享role renderer已编码但未Apple编译；跨页面一致性、主题差异截图、可读性和设备验收未完成；未继承 A/B 主题结论为通过 |
| F-23 | 单一权威实现、模块边界、依赖和故障可诊断 | defined | FCore/FAdvisor/FLedgerWrite 依赖隔离；架构边界脚本当前通过；Actions run 旧执行编号省略 已完成 FCore 与 App Device/Simulator Build；后续修改仍需重跑 |
| F-24 | 核心测试按模块执行，记录 defined/executed/passed/failed | defined | 账本 XCTest 已定义；FCore XCTest：119 executed / 119 passed / 0 failed（Actions run 旧执行编号省略）；各产品验收项仍按实际覆盖范围判定 |
| F-25 | NAS历史分钟补采、实时归档、完整度、长期留存、查询、诊断和研究证据/no-lookahead | defined | 归档/补采/查询/研究链已编码；累计量差分来源必须保留累计量且差值匹配分钟量；归档启动/完整性/备份恢复校验、no-clobber备份、版本化队列和严格HTTP输入/授权边界已覆盖；交易日历、日期、时区、幂等、Partial门控、指定日期Missing/Partial逐日诊断和范围隔离有回归；无范围时列出已评估coverage日期并明确可能低估；分钟服务27/27、归档43/43、红利研究7/7、只读迁移dry-run6/6、Provider/Calendar/runtime10/10，合计93/93通过；腾讯当日接口已实网取样并写入F归档；东财历史接口本云端超时、生产交易日历与NAS部署仍待外部验证 |
| F-26 | 指数卡区分行情时间、获取时间、来源、新鲜度和交易时段；闭市保留最后有效时间 | defined | Index卡现在会把供应商未知/未提供的交易时段显示为“交易时段未验证”，仅显式OPEN/CLOSE/CLOSED映射为交易中/已收盘，避免未知状态误报闭市；新增源码契约未执行。实时源、闭市保留值与原生显示仍待验收 |
| F-27 | 首页显著提供组合问答输入、发送、快捷问题和真实持仓上下文；详情入口绑定证券 | defined | 首页/Advisor页输入、发送和快捷问题已接入；默认聚焦首个真实持仓，详情绑定标的；发送时重读账本并构建请求。只读持仓会发送至用户配置的DeepSeek；实际可发现性待Simulator/真机验收 |
| F-28 | 十主题统一普通文字/页面颜色；仅保留业务语义图表色 | defined | Manifest动态浅/深色语义token、共享主题表面、图表成本/均价/MA/IOPV颜色和明暗对比强调色已编码；eye-care、完整动态字体、色弱对比与设备截图尚未验证 |
| F-29 | 分时/日K统一支持点击、长按十字光标、拖动、缩放、横屏与选中详情 | defined | hit-testing坐标验证与复用已编码；当前/历史分钟与日K已接入共享 renderer。基础图表模型回归包含于FCore 119/119通过；renderer内实际手势、横屏全屏及显示效果仍待Simulator专项/真机验收 |
| F-30 | 红利研究采用多因素证据；4%仅为自动模式参考，显式高级设置才启用自定义最低值 | defined | NAS多因素证据整理器及版本化Research Evidence输出已编码；历史观测重复时按质量/抓取时点确定性去重并拒绝质量分越界，红利研究Python 7/7通过；真实基本面来源、Advisor/UI消费和高级自定义设置仍未接入，不能据此给出真实资产买卖结论 |
| F-31 | 首次使用者可发现AI输入、历史分时、K线选择、数据时间/来源、AI依据和主操作 | defined | AI输入/快捷问题/真实账本状态和持仓证券详情入口已编码；历史分时、K线选择、行情来源新鲜度及依据展示仍待原生可发现性验收；Simulator/真机评估待外部验证 |
| F-32 | B五种布局为F主要布局设计基线；首页每卡职责、信息和目标路由唯一；不同语义入口必须有独立页面 | defined | 十种布局均复用市场观察、跨市场脉搏、AI指导、真实资产role及唯一route；五个新增布局、Gallery和共享renderer已编码未编译。独立NavigationStack保留；发现性/切换状态待设备验证 | |
| F-33 | NAS Research Evidence作为可选增强只读进入DecisionContext；不作核心顾问必经依赖 | defined | 紧凑证据与日期/质量校验已编码；无NAS时核心Advisor继续运行，只有证据可用才附加；跨端服务联调仍未完成。旧119项CI数字仅是历史证据，不覆盖当前HEAD |
| F-34 | B版145项需求逐项溯源、F需求处置与独立验收 | defined | [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)：保留 B-001…B-145 编号与验收输入，逐项给出 F 需求处置、供体裁决和 F 独立验收状态；B 状态不继承。编号连续性已静态核对，F 实现仍按各项验收。 |
| F-35 | 行情按证券刷新并更新共享图表快照，显示来源/行情时间/获取时间 | defined | Swift数据绑定已编码；实时源、设备图表响应待验证 |
| F-36 | 未知年份交易日历 fail-closed，日历按正式来源审核 | defined | 仅当前配置年度启用；其他年份和实机行为待验收 |
| F-37 | NAS按月核验官方交易日历，双源一致后原子发布 | defined | Worker/存储已编码；目标NAS运行和实网兼容待验证 |
| F-38 | 原生主导航、只读真实资产、显著AI输入、设置和NAS连接 | defined | 五Tab/独立导航栈、AI上下文状态、只读账本页、主题设置、NAS URL与只读`/readyz`检查已编码；NAS token 配置已按用户明确授权移除。历史UI XCTest结果不代表本次改动已验证。 |
| F-39 | NAS部署包在大小写敏感的Compose项目名校验下可解析 | defined | Compose固定`name: guanpan-f`；部署包显式包含Python package markers；修复entrypoint CRLF shebang，并在Dockerfile构建时校验`#!/bin/sh`；部署包测试7/7与shell语法检查通过。NAS挂载卷属主初始化后降权至UID 10001；Docker/NAS目标环境仍External Verification Pending |
| F-40 | 真实持仓 Advisor：组合级 + 证券级 Ledger→行情/研究→DecisionContext→Risk/AI Guard→Candidate Plan | defined | App源码现按入口/问题区分组合与证券范围；真实账本空仓时组合Advisor仍可分析现金；明确六位代码/证券入口可分析尚未持有的证券；组合问题纳入全部真实持仓/现金、逐证券报价和 NAS Evidence/缺失状态。单笔买入/卖出 Candidate 现可由用户填写实际成交并显式确认后调用唯一 Ledger writer，成功后失效旧 Candidate、重读账本并重跑相同作用域 Advisor；做T/网格/回本不自动写入。ETF单笔0.10元及做T双边0.20元估费由iOS校验。基础做T不强制盘口，但要求连续时段可信新鲜行情及同标的合格vwapBreak研究。证券详情页接入NAS按日历史分钟；分钟折线支持长按/按钮十字光标、拖动选点/平移、提示和缩放。当前代码已通过Actions run 40298657796的XcodeGen、iOS Device/Simulator Build及3项UI XCTest；FCore 119/119通过。统一图表及历史详情已编码并编译，但交互/画面、清仓真实账本数据、成交后AI闭环和NAS/DeepSeek/行情生产联调仍待专项验收；均价/前收/IOPV无可靠源保持Unavailable，横屏仍未完成 |
| F-41 | F拥有独立App图标；图表指标可逐项显示/隐藏并按可见序列定纵轴；iPhone Air页面布局与真实交互验收 | defined | 1024px独立F图标资产、MA/成交量/成本/券商成本/均价/前收/Candidate/IOPV开关及隐藏MA不再参与视区纵轴已编码；当前IOPV已限定实时图，新增历史分时排除IOPV纵轴的XCTest和UI源码合同。此前F图例为静态文字，B版统一图表有可切换指标按钮。本轮Swift未编译；iPhone Air截图/人工验收、图标进入IPA均待新Apple CI与设备检查 |
| EXT-1 | GitHub DNS / 远端可达性和跨机同步验证 | external pending | 私有 `ggjj45828/guanpan-f` 已通过GitHub API发布F源码；Actions run `旧执行编号省略` 成功。跨机克隆/恢复及持续同步仍待验证 |
| EXT-2 | NAS 端口 8788 与部署/恢复链验证 | external pending | 旧部署 `/readyz` 返回过 unauthorized；当前源码改为无鉴权，需重建部署后验证 readiness、Provider/Calendar、历史数据和备份恢复。此改动让可达端口的客户端可访问所有API。 |
| EXT-3 | macOS、Swift/Xcode 构建和模拟器测试 | external pending | GitHub macOS Actions run `旧执行编号省略` 用Xcode 16.4完成Swift编译、Device/Simulator Build、FCore 119/119及App UI 3/3；人工截图/交互、横屏/多尺寸和真机仍待验证 |
| EXT-4 | iPhone 真机、横屏和推送通知验收 | external pending | 需设备环境 |
| EXT-5 | 实际行情、新闻与在线 AI 服务接入验证 | external pending | 外部服务配置/联调待做 |

当前矩阵为41项 `defined`、5项 `external pending`。当前FCore XCTest defined=140；本轮新增测试未执行。App UI XCTest defined=3，本轮0 executed。最近完整Apple CI run `旧执行编号省略` 在源码`f366542`上FCore 139/139、App UI 3/3通过，不能继承为当前修改通过。这不代表所有产品验收项已通过；Python结果和静态检查也不代表真机、生产NAS或在线服务通过。不得继承A/B状态。



> 以下为追加的阶段性历史记录；其中旧测试计数反映当时工作树，当前数字以上方“当前 F 验证快照”为准。

部署阶段补充（2026-10-26）：F-25 的分钟服务已有显式运行壳与持久化部署配置；runner/鉴权/readiness 的本地 HTTP smoke 通过，Compose YAML结构检查通过，现有 Python 套件83/83通过。Docker镜像、真实 provider/calendar 插件、NAS 8788部署及生产备份恢复未验证，均保持 External Verification Pending，不能标为部署通过。


Provider/Calendar接入补充（2026-10-26）：F默认runtime现配置腾讯当前交易日分钟采集、东财精确日期历史分钟请求和沪深2026交易日历，启动时排队最多120个受支持交易日，实时采集与补采分线程运行。腾讯实网数据已在本环境经日历校验并写临时SQLite，盘中16/240点标Partial；东财历史请求本云端超时，不能算历史覆盖通过。非2026年日历fail-closed。Docker镜像、NAS部署及生产回补覆盖仍External Verification Pending。

NAS容器启动故障修复（2026-10-26）：用户日志显示`No module named 'nas.fminute'`。部署ZIP构建器此前只复制`nas/fminute/*.py`，未打包根`nas/__init__.py`；现补齐显式package marker，并在Docker镜像构建阶段执行真实模块import自检。部署包套件6/6通过、解压包import smoke通过、相关`py_compile`通过。当前环境无Docker，未能验证镜像构建；修复包需在目标NAS重新部署，生产启动仍External Verification Pending。FCore XCTest defined=39 / executed=0 / passed=0 / failed=0；App UI XCTest defined=2 / executed=0 / passed=0 / failed=0。

NAS SQLite 数据目录权限修复（2026-10-26）：用户日志显示`sqlite3.OperationalError: unable to open database file`。原因是NAS bind mount覆盖镜像中已chown的`/data`，UID 10001无法写入宿主目录。entrypoint以root准备`/data`属主和权限、修复属主不匹配的顶层既有数据项，再通过`util-linux`的`setpriv`降权到UID 10001启动Python；未更改存储路径或数据库内容。部署包测试7/7、解压模块导入smoke、shell语法及py_compile通过。无Docker/NAS，构建和生产重启仍External Verification Pending。


NAS 8788 / GitHub F repo 状态补充（2026-10-26历史现场）：旧部署 `/livez` 返回 alive，`/readyz` 返回 unauthorized；当前实现已按用户授权移除NAS API token鉴权，目标容器尚未重部署。生产就绪性未验证。

## 当前产品级B vs F差距审计（2026-10-28，覆盖旧的UI完成度描述）

| 审计项 | 当前工作树事实 | 当前结论/下一步 |
|---|---|---|
| B供体身份/视觉证据 | `GuanpanNext-work/ios` 有原生SwiftUI；无Git元数据无法证实为B Frozen；现有SVG自称手绘预览，无B真机截图 | 静态源码差距审计完成；设备级对照仍待用户真实B截图/或准确冻结源码 |
| 用户实际体验 | 用户实际在iPhone Air打开F，明确反馈整体布局及图表远差于B | 当前用户体验 **B wins**；不能以F架构优势冲抵 |

| B→F首页体验整改（NRG-26） | B首页结构与当前F首页实机表现对照；当前用户判断F仍不如B | 首页共用Portfolio AI、真实资产摘要、市场/研究独立入口和新鲜度过滤。Run 56/57 FCore均140/140，XcodeGen通过；两次Device Build均因源文件上传内容损坏失败。完整文件已恢复并回读核对一致；Run 58 SHA `9e57569` queued | 已编码；Run 56/57 App Build失败、UI XCTest/Simulator截图未执行；Run 58结果待定；iPhone Air未验，不可标完成 |
| 核心产品页面 | 新文档逐页对照首页、行情、详情、分钟/历史分钟、日K、AI、资产/持仓、设置、主题、NAS、搜索、通知、备份、收息及模拟方向 | 详见 `F-B-UI-PRODUCT-GAP-AUDIT.md` |
| B不得退化 | 建立NRG-01～NRG-24非回归登记；恢复有价值体验仍使用F真实Ledger/Advisor模型 | 详见 `F-B-NON-REGRESSION.md`；“已编码”不等于已验收 |
| 图层可选显隐 | 当前dirty源码已编码MA/成交量/有效overlay显隐与价格域过滤；B源码有逐层控件和持久状态；F当前未编译 | F为已编码未验证；需当前HEAD CI + 图表截图/手势验收 |
| F当前编译/测试 | 最近旧CI为139/139与3个UI用例，SHA `f366542`；不覆盖当前HEAD | 当前HEAD测试状态保持最近真实执行证据，不能继承旧CI为当前PASS |
| 主题完成度 | F源码含10 layout/manifest但Preview和实际硬编码layout存在差异，用户实装体验差 | 10套未完工；按用户要求先做3套标杆，待六核心页面体验达标后再扩展 |
| P0/P1/P2顺序 | 用户定义P0现有Ledger/T/费用验证，P1产品差距审计（本轮文档已建），P2六页面体验整改 | 下一步先fetch/reconcile + 当前HEAD Apple CI；CI后进入首页/行情/详情/图表/AI/资产连续整改 |

| P2 行情页刷新 | 修复刷新集合：已持仓证券 + 当前合法六位输入代码，去重；空仓且未输入合法代码时才禁用 | `GuanpanFApp/Sources/HomeExperience.swift`，已编码未编译；FCore 140 defined/当前不变；App UI无新增测试/未执行 | CI通过后Simulator确认空仓搜索刷新和持仓刷新 |

| P2 图表图层控件 | 图层切换文本与图标放大，最小触控高度44pt，横向滚动不变 | `GuanpanFApp/Sources/FUnifiedSecurityChart.swift` 已编码未编译；无新增测试定义/无执行证据 | 必须在Simulator/iPhone Air上验证控件可点、图表面积、横滑和手势冲突 |

| Apple CI 2026-10-28 / `b882a580` | FCore 140/140 executed/pass；XcodeGen 成功；Device Release Build 在 `FNASConnection.swift:68` 因不存在的 `URLError.Code.localNetworkDenied` 失败；Simulator/UI/IPA skipped | 首个根因已在工作树修复，未编译；普通推送后重跑完整Apple CI | 修复后尚无结果 |
| Apple CI 2026-10-28 / `572cb5f` | FCore 140/140；XcodeGen、Device Release Build、Simulator Build 成功；App UI XCTest 3/3；IPA打包成功 | run `旧执行编号省略`，artifact `旧执行编号省略` | 自动化全绿；人工视觉/手势/iPhone Air真机仍待验收 |
| P2 首页真实资产摘要（旧状态已被下行取代） | 真实持仓行增加新鲜行情下的本轮持仓浮盈亏；全天证券盈亏口径不可靠时显示 unavailable，不伪造 | 旧注记曾为“已编码未编译”；现状态见下方当前HEAD CI记录 | CI编译与自动化已通过；人工真比例/iPhone Air仍待验收 |
| 2026-10-28 CI截图记录 | run `旧执行编号省略` 导出9张 iPhone 16 Pro UI XCTest截图，尺寸 960×1440 | 有CI附件；不是人工视觉验收。样张布局存在比例/裁切疑点 | 需真实 Simulator 比例截图后判断，当前不做全局布局重构 |

| 2026-10-28 P2 首页盈亏语义 + 当前HEAD Apple CI | `HomeExperience.swift` 显示新鲜行情下的本轮持仓浮盈亏；全天证券盈亏缺少可靠前收/日初持仓事实时显示Unavailable原因 | 当前HEAD `6cde9d5e5964b8f67e4cfe54d0a9f918a1deba87` 的CI run `旧执行编号省略`：FCore 140/140、XcodeGen、Device Release Build、Simulator Build、App UI 3/3、未签名IPA全部成功 | **当前SHA编译及CI测试通过**；非人工Simulator/iPhone Air验收。UI截图仍需真实交互设备核查 |
| P2 资产流水手续费更正显示 | 更正后的成交行应显示有效手续费；调整事件显示费用差额，避免原始fee与effective fee误导 | `HomeExperience.swift` 已修正显示标签；不改fill、现金或费用投影 | **已编码，当前尚未编译/测试**；NAS没有修改，不需要部署 |
| App Icon / IPA图标 | 桌面图标使用F专属图标，确认生成IPA的Asset Catalog确实包含该图标 | `Assets.xcassets/AppIcon.appiconset/AppIcon.png` + XcodeGen AppIcon配置存在；当前源码提交晚于图标资源引入提交 | CI Build成功但未解包检查IPA内部Asset Catalog；用户设备报告仍见旧B图标，最新artifact卸载重装验证待完成 |
| App Icon 第二版 / Settings NAS可发现性 | 无文字字母、清晰金融意象；NAS入口不被主题预览埋住；健康检查和数据同步状态分别表达 | SVG/PNG已重做为无字母趋势柱线+信号点；NAS区移至在线AI之后；“历史数据同步未接入”取代静态“同步未连接” | 已编码，Apple CI与IPA内容核验待做；NAS连接本身需根据设备当前网络和真实测试错误E2E验证 |
| iPhone手机布局黑边 | App正常启动时占据预期全屏，不呈上下黑边的居中2:3面板 | 用户IMG_6002截图显示中央圆角面板与大块黑边；FHomeRoot无显式固定高度/弹窗高度约束 | 根因未确定；须在真机确认启动模式/窗口形态后复测，禁止凭图盲加尺寸限制 |
| IMG_6003 设置/NAS/主题入口 | NAS 地址未填写时要清楚提示“未配置”，不能伪装成连接错误；主题应以紧凑主题栏切换，完整预览默认收起 | 当前工作树已编码：NAS区前置、空地址文案区分“尚未测试”、保存地址时只读检查`/readyz`；主题以横向栏显示，完整预览放入折叠区；工程加入`UILaunchScreen`和根视图弹性填充 | 当前更改**尚未编译/CI/真机复验**。用户截图状态栏为5G；局域网地址需Wi-Fi/VPN，远程公网访问需可达HTTPS/VPN。服务端未修改、不需NAS部署 |
| 2026-10-28 当前本地提交送CI | 设置/NAS/图标/手机适配更改需要Apple编译验证 | 本地提交尚未推送；普通Git推送因本机DNS线程错误失败。远端main仍停留在本地基线。当前交接已整理为不包含本机路径或具体运维诊断的状态快照 | 当前提交已进入远端；Apple CI已排队、未开始，仍是External Verification Pending |
| IMG_6004 NAS穿透错误诊断 | 用户用HTTPS穿透访问B正常；F提示“无法连接 NAS” | F连接错误来自URLSession连接阶段，没有HTTP状态/readyz响应。F readiness timeout原为8秒；现改20秒并细分无法连接/超时/断网/TLS错误 | F源码已编码未编译；若仍失败按提示区分端口映射、穿透、容器和TLS。NAS后端未改，不需部署 |
| IMG_6005旧错误提示 | 图中仍显示旧版合并错误文字 | 与8f71a59中的旧提示完全一致；手机很可能尚未安装新诊断IPA | 不作为新代码复测；待b20fb5c CI和新IPA安装后再测 |

| 2026-10-28 图表与键盘可用性整改 | 用户实机指出F图表/布局观感较差，AI/设置输入后键盘难以收起。保留唯一`FUnifiedSecurityChart`，增加价格轴/刻度、压缩午休时间轴、独立日K成交量区、选中K线OHLCV和详情页有效高度；AI及设置输入添加收键盘工具栏/发送保存自动收起 | `GuanpanFApp/Sources/FUnifiedSecurityChart.swift`、`HomeExperience.swift` | 已编码；当前未编译、未执行测试、未Simulator或iPhone Air验收。NAS/行情/DeepSeek真实E2E不受此改动证明 | Apple CI通过后仍需真实设备确认画面、图表点击/手势和键盘入口 |

| 2026-10-28 图表与键盘真实工作树校正 | 本地HEAD `ca9b593ed9327a6eb806ea247e3b9b103a01e001`，图表和键盘整改已提交本地；当前相对缓存origin/main ahead 3，但fetch失败，远端同步状态未知。四份交接/审计文件有未提交修改 | 本机无Xcode；新提交没有编译/测试/Simulator证据。父提交旧CI不得沿用。统一图表新增轴、质量、来源、分离VOL和OHLCV选择，设置主题表面；键盘显式收起 | 编译恢复后先fetch/reconcile，再普通push跑全CI；CI通过后人工检查iPhone Air截图/交互 |

| P2 键盘收起入口 | AI多行输入、DeepSeek/NAS地址、行情证券代码（数字键盘）均须可显式收起；发送/保存动作自动收起 | `HomeExperience.swift` 与 `FUnifiedSecurityChart.swift` 已编码；当前新增行情数字键盘toolbar修改未提交 | `git diff --check`通过；没有Apple编译、测试、Simulator或真机证据 | CI通过后验证键盘显示/收起和导航打开详情 |

| 当前HEAD/Apple CI（2026-10-28） | HEAD `ecb220da28e59ec6bb2b908325f75de2330bb3cd` 已普通push至规范仓库`ggjj45830/guanpan-f`；run `40675520793`：FCore步骤成功、XcodeGen成功、Device Build执行中；UI Test/Simulator/IPA尚未完成 | 必须等run结束后读取实际用例数量和结果；不可继承父版本测试数 |
| NAS实际修复状态 | F连接请求仍为规范化地址GET `/readyz`，无专用token；错误细分和20秒超时进入当前CI。iPhone新包真实HTTPS穿透复测尚无证据 | NAS连接问题未确认解决；NAS后端未改 |

### 2026-10-28 IPA验证门修正

- run `40675520793` 的核心测试、XcodeGen、Device Build、Simulator Build和UI XCTest均成功；IPA归档已产生。最终失败原因是CI读取了错误的Info.plist键层级，导致打包校验失败，不是编译/测试失败。
- 当前工作树已把图标检查路径改为`CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName`，仍待下一次Apple CI验证。
- NAS连接仍需用户iPhone安装新IPA并实际用HTTPS穿透验证；没有NAS后端改动，也没有实机确认。

### CI重试后的图标验证修正

- run `40677313197` 中FCore、XcodeGen、设备/模拟器构建和UI XCTest均成功，IPA阶段再次失败。真实原因：构建产品Info.plist没有`CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName`键。
- 已改为校验图标源manifest/PNG，并用Xcode `assetutil`检查编译后的`Assets.car`包含AppIcon rendition。此检验尚未由CI执行。


## 2026-10-29 行情自选验收增补

- 行情页必须能分开查看真实持仓和自选，也可合并查看；自选只保存证券代码关注关系，不得创建Security持仓、成交、现金或盈亏。
- 自选条目只能展示真实上游行情快照及其时间/来源；行情缺失时明确显示空值/不可用。加入自选后可进入证券详情；清除自选不得改变真实Ledger。
- 当前状态：Swift实现已送Apple CI，构建/测试结果待记录；Simulator视觉验收待人工完成。


## 自选行情页CI修正（2026-10-29）

- Run65真实失败点：行情页键盘Toolbar重载歧义（HomeExperience.swift:1725）。修复是将键盘关闭操作放到聚焦时可见的查询区按钮；不删除关闭键盘能力。后续CI尚待执行/结果填写。


## 行情空状态兼容修复（2026-10-29）

- Run66确认项目deployment target低于iOS17；行情页不使用iOS17专有ContentUnavailableView，改用兼容布局。新CI结果待验证。

## 2026-10-29 当前HEAD与正式架构验收更新（覆盖较早快照）

- **架构覆盖：** NAS是可选同步/备份/归档/扩展，不是核心Advisor必经条件。核心为实时行情 + 真实Ledger + 本机确定性Quant/Risk/Trigger快通道 + DeepSeek慢通道。Quant Signal、AI Advice、Market Result、User Execution严格分离；Candidate/Shadow/Trigger均不得写Ledger。旧NAS必经描述标记Superseded。
- **HEAD：** `0dff6c3d84af3870d4a10adcb02fcbea0d492b2a`；工作树干净，本地`main`与缓存`origin/main`一致。
- **Apple CI：** GitHub连接器没有返回当前SHA可核实的workflow run或combined status；当前SHA结果为“未核实”，不继承旧run测试数字。
- **本轮改动范围：** 统一图表展示、自选刷新、盈亏折叠及主题表面；没有完成首页主动AI今日判断，也未实现完整本机Quant。
- **Quant状态：** 只有基础价格区间Trigger evaluator；正式多因子、Market Regime、Risk Guard完整接线、行情订阅/提醒、首页/证券详情状态接线未完成。
- **其他未验证：** NAS手机HTTPS、Simulator人工视觉、iPhone Air及DeepSeek真实闭环无新完成证据。NAS不是核心链路的阻断项。

## Run 69 live status (2026-10-29)

- Current Swift HEAD 0dff6c3d84af3870d4a10adcb02fcbea0d492b2a has run 40802741213 in progress.
- FCore, XcodeGen, Device Build and Simulator Build steps are successful; UI XCTest remains in progress; screenshot/IPA/artifact steps are pending.
- No final executed test count or all-green result yet. Documentation updates in this worktree have not been pushed and are outside this run.

## Run 69 finalized evidence (2026-10-29)

- SHA 0dff6c3d84af3870d4a10adcb02fcbea0d492b2a; GitHub Actions run 40802741213 succeeded.
- FCore: 164 executed, 164 passed, 0 failed. App UI XCTest: 3 executed, 3 passed, 0 failed.
- XcodeGen, Device Build, Simulator Build, screenshot export, unsigned IPA validation, and artifact upload all succeeded.
- Artifact 12866733256. IPA metadata validation confirms display name “观盘max” and AppIcon. This is not proof of successful iPhone install or human visual approval.
- Current local documentation edits are not included in that tested SHA. They are documentation-only; no Swift code changed in this follow-up.

### 本地文档提交状态补正（2026-10-29）

Run 69通过的源码SHA是0dff6c3d84af3870d4a10adcb02fcbea0d492b2a。之后生成了一个仅含五份Markdown更新的本地提交；本机git push失败，错误为“getaddrinfo() thread failed to start”。当前本地main比缓存origin/main ahead 1；Swift源码未变。当前仅文档提交未推送，也没有其远端CI结果。

### 文档同步最终状态（2026-10-29）

Git命令直推失败后，已通过GitHub Desktop对正确F仓库推送成功，本地main与origin/main同步。文档提交只有Markdown文件，workflow的push paths不会因此触发Apple CI。Swift SHA 0dff6c3d84af3870d4a10adcb02fcbea0d492b2a的Run69已真实验证FCore 164/164、UI XCTest 3/3、XcodeGen、Device/Simulator Build、截图导出、IPA校验和artifact上传成功。

## B Frozen 首页供体迁移（编码状态）

| 验收项 | F实现 | 状态 |
| --- | --- | --- |
| Editorial首页采用B式编辑层级 | 中文问候/日期、真实行情横条、F组合Advisor、跨市场弱层级、真实资产摘要；仅显示F实际持仓/自选快照与来源时间 | 已编码；未编译/未测试/未Simulator验收 |
| 首页账本内资产估值 | 仅将账本现金与全量真实持仓按可信新鲜报价估值；行情缺失/过期时整体不可用，不将部分持仓值冒充总资产 | 已编码；Python契约覆盖完整/缺失报价路径；新增FCore XCTest尚未Apple编译/运行，真机视觉待验 |
| 空行情或过期报价 | 显示等待/状态，不推算指数或涨跌 | 源码静态确认；运行未验证 |
| 主题纸面层级 | Editorial surface使用不透明纸面、细边和轻阴影 | 已编码；截图未验 |
| B视觉胜出声明 | 当前仍依据用户实机反馈：F不如B | 未关闭 |

Run 73 (`bd01362fc72160ebb0fb28ccccb7c9fc4de5071c`) 随后实际通过 FCore 164/164、UI XCTest 3/3、XcodeGen、Device/Simulator Build、截图导出与IPA校验。首页人工视觉验收仍未完成；CI通过不等于B视觉达到。

| 验收项 | 当前实现/证据 | 状态 | 关闭条件 |
|---|---|---|---|
| NAS历史分钟响应诊断与B Frozen兼容 | `GuanpanFApp/Sources/FNASConnection.swift`：区分有效HTTP 200 + Missing与格式/路由失败；F格式失败、质量门失败或未来分钟/采集时间均不能标Complete | Swift dirty、尚未编译/CI/手机实测；NAS历史真实覆盖未知 | 当前SHA Apple CI通过；HTTPS手机查询同证券/日期；页面显示真实Complete/Partial/Missing；有分钟时曲线来自实际返回bar，无数据则不画假线 |
| 市场图可读性与主题作用范围 | `HomeExperience.swift`、`FUnifiedSecurityChart.swift`、`GuanpanFApp.swift`、`ThemeLayoutManifest.swift` | 全宽ScrollView、360pt图表、较小图层控件、连续缩放、日线VOL/MACD、导航/设置/图表主题token，以及证券详情/Advisor面板主题surface与间距均已由Run 75/76编译；Run 76 `40829925945` 成功 | Run 76 SHA `bbba0e60832b5f5c39663f1489f26cf0f3601d21`：FCore 164/164、UI XCTest 3/3、XcodeGen、Device/Simulator Build、截图导出、IPA校验/打包与artifact上传均成功。自动截图未人工审阅、iPhone Air未实测；均价/前收/IOPV真实来源仍未接入；十主题逐页视觉一致性仍待截图验收 |
| 数据星图表面主题一致性 | `GuanpanFApp/Sources/HomeExperience.swift`：中心摘要、外围导航节点 | Run 77 `40831405937` 对SHA `84a191b94e79e0f5d943cf2ba495beda7ccfb3cf` 实际通过编译与自动测试 | FCore 164/164、UI XCTest 3/3、Device/Simulator Build、截图导出和IPA打包/校验通过；截图未人工审阅、iPhone Air未实测，整体主题视觉统一仍待人工截图验收 |
| 图表交互性能与日K日期轴 | `GuanpanFApp/Sources/FUnifiedSecurityChart.swift`：overlay时间索引避免逐点全表扫描；日K横轴按宽度布局并对齐首尾 | Run 78 `40833407806` 对SHA `0ff77a6f51b9cf0b9854f7a3130b134384c189d5` 编译与自动测试通过 | FCore 164/164、UI XCTest 3/3、Device/Simulator Build、截图导出与IPA打包/校验成功；人工触控流畅度及iPhone Air显示仍未验收 |
| 证券图表面积、图例密度与跨页面主题一致性 | `GuanpanFApp/Sources/HomeExperience.swift`、`GuanpanFApp/Sources/FUnifiedSecurityChart.swift`：详情分时/日K/历史图扩大、列表迷你图增高、MA控件缩小、资产页和导航目的页统一主题背景/语义强调 | 已编码；Apple CI未执行；截图未人工检查 | 新SHA Apple CI成功后记为已编译/自动化通过；仍需iPhone Air截图和真实触控检查，不能以CI截图导出替代人工验收 |
| 真实资产初始持仓录入入口 | `RealAssetsOverview`提供显式初始真实持仓入口；现金与单/多只持仓在同一表单录入；证券代码异步查名并允许人工修改；成本输入为每份真实经济成本，系统计算总成本；保存仍经`FConfirmedLedgerWriter.confirmInitialLedger`并明确确认，不生成fills | 已编码；`Tools/test_home_layout_contract.py`静态契约及`testEmptyLedgerOffersInlineCashAndHoldingsEntry`端到端UI测试已定义；当前修复尚待Apple CI执行 | Apple CI验证有效录入后确认按钮可保存并关闭表单；真机验证自动查名及单只证券流程；不能把既有持仓伪造成confirmed fill |

| 集中修复（2026-10-29，当前工作树） | F源码/真实来源边界 | 状态 | 完成证据/剩余关闭条件 |
|---|---|---|---|
| NAS HTTP 200历史响应兼容 | `GuanpanFApp/Sources/FNASConnection.swift` 容忍可选coverage/source/fetchedAt，校验声明的证券/市场/日期，元数据缺失只降级Partial | 已编码；未编译、未实机联调 | 当前合并SHA Apple CI通过；用手机请求真实NAS指定交易日并核验HTTP内容、bar和coverage |
| 分时量价均价与前收 | `FMinuteSample.volume`由Tencent累计量差分；曲线用分钟收盘价×增量成交量加权（非官方VWAP）；前收使用Tencent quote或前一交易日日K | 已编码；来源字段静态对照B，当前目标证券实网返回未验证 | 必须显示来源/时间/质量；真实响应缺失就Unavailable；确认坐标覆盖范围和曲线正确 |
| ETF IOPV/溢折价 | `GuanpanFApp.swift` Tencent quote扩展字段，仅provider明确ETF且当前IOPV新鲜时展示参考 | 已编码；尚无实网响应证据 | 取得真实报价样本验证字段语义、时间和溢折价单位；否则保持Unavailable |
| 初始真实持仓入口 | `RealAssetsOverview`→`FHomeModel.establishInitialLedger`→`FConfirmedLedgerWriter.confirmInitialLedger`；确认审计，不创造fills | 已编码；测试定义但当前HEAD未执行 | 当前HEAD CI通过；空账本UI实际录入和重开验收；已有账本不覆盖 |
| 图表/主题整改 | `FUnifiedSecurityChart.swift`与`HomeExperience.swift`扩大绘图区域、缩小图例、移出MACD左轴标签、跨页主题token | 已编码；当前HEAD无编译证据、无本轮截图 | 合并SHA CI成功；实际查看导出截图并完成iPhone Air触控验收，主题逐页一致性另验 |

| 集中修复后检查 | 当前实现/证据 | 状态 | 关闭条件 |
|---|---|---|---|
| 初始真实持仓快照入口 | `RealAssetsOverview`空账本显示“录入现有持仓”；确认表单写入审计化opening snapshot，不伪造fills | 已编码；合并SHA尚未编译/执行；空账本UI实际操作未验 | Apple CI当前SHA通过；Simulator录入、退出重开和已有账本不可覆盖验收 |
| 分时/历史图表价格参考 | Tencent分钟成交量差分形成量价均价（非官方VWAP）；Tencent前收、鲜活ETF IOPV/溢折价作为实时参考；历史前收从所选日期之前真实日K取得 | 已编码；供应商真实字段/设备响应未验证；无字段保持Unavailable | CI通过；实网逐字段核实值、单位、时间和来源；历史日/当前分时分别核验 |
| NAS HTTP 200历史返回格式兼容 | 可选coverage/source时间元数据与数字字符串价格解码；身份字段校验；来源质量不足降Partial | 已编码；本轮真实NAS历史指定日期未请求 | CI通过并从手机端验证HTTPS endpoint真实body、bars及coverage |
| 图表可读性与真实参考标注 | 收窄价格轴、MACD文字移到右上、IOPV标记为参考、扩展日线/历史绘图布局 | 已编码；当前SHA无构建和截图人工审阅 | Apple CI通过后审阅Simulator截图；iPhone Air手势仍单独验收 |

## 当前HEAD实证补记（Run 84，2026-10-29）

| 验收项 | 实际执行证据 | 状态/剩余要求 |
|---|---|---|
| Apple CI完整链 | SHA `be0b8f783ed0dd2c23dd91b65bbfdcbe82d7c7cf`，Run [40851719577](https://github.com/ggjj45830/guanpan-f/actions/runs/40851719577)，job `123372567830` success；FCore 165/165、UI XCTest 4/4、XcodeGen、Device Build、Simulator Build、截图导出、IPA打包/校验、artifact上传均通过；artifact `12888415712` | 当前SHA自动编译/测试已通过；截图未人工审阅，未替代人工视觉或真机验收 |
| NAS历史响应格式与错误诊断 | `FNASConnection.swift`解码兼容数字`securityCode`、`trading_date`及大小写市场；错误bar结构不会降级为空数据，诊断附请求/返回身份与首条bar字段类型 | 已编译并通过当前CI；真实NAS HTTP 200 body和指定日期历史bar仍待手机HTTPS E2E，不代表NAS已连通 |
| 观盘max图标/名称 | Run 84 IPA日志验证display name `观盘max`、bundle icon `AppIcon`，ZIP结构校验无错误 | CI打包产物已验证；未证明用户手机已安装该IPA |
| 录入现有持仓入口 | UI XCTest `testEmptyLedgerOffersInitialHoldingsEntry`通过 | 自动化可发现入口；真实交互录入、持久化重开仍待Simulator/设备验收 |
| 图表、主题、手机布局 | 当前SHA Simulator Build及截图导出步骤成功 | 未人工查看截图、未测iPhone Air和真实触控；不能据此说界面问题已全部修复，F目前仍不如B |
| 新闻/均价/前收/IOPV/溢价 | 当前Run没有新的供应商或设备真实响应证据 | 未接入或未证实；数据缺失继续显示Unavailable，不得伪造 |

## NAS诊断增量（Run 85，2026-10-29）

| 验收项 | 当前增量 | 状态/关闭条件 |
|---|---|---|
| HTTP 200错误体诊断完整度 | 有服务端`error`说明时仍检查顶层与首条bar实际结构；行级支持`security_code`、`trading_date`、数字证券代码、大小写市场值 | Run 85 [40854072875](https://github.com/ggjj45830/guanpan-f/actions/runs/40854072875) 对SHA `31c2010d4324db6fa8251db0199e1c0cd8540113`：FCore 165/165、UI XCTest 4/4、XcodeGen、Device/Simulator Build、截图导出、IPA打包/校验/上传全通过。真实NAS指定日期响应仍待手机验证 |


## Run 98 证据与当前缺口（2026-10-29）

| 项目 | 当前结果 | 状态边界 |
| --- | --- | --- |
| 当前SHA Apple CI | `311f1c8cf639679b56f327abc000951ea3ef14dc` / Run [40878823535](https://github.com/ggjj45830/guanpan-f/actions/runs/40878823535)：FCore 165/165、UI XCTest 4/4、XcodeGen、Device/Simulator Build、截图导出、unsigned IPA校验/上传通过 | 已编译/自动测试通过；CI截图未人工查看；未真机验收 |
| Tencent ETF IOPV/溢价解析 | Tencent缺省ETF类型时按受支持代码段兜底；不把508/180 REIT纳入ETF；数值支持百分号/千位符；无效溢价过滤值已传入最终模型 | 已编译；缺当前真实供应商响应样本，字段端到端仍待实测 |
| 参考行情错误状态 | 当前取数失败显示诊断并清除旧参考缓存 | 已编译；具体证券/网络实测待设备 |
| NAS指定日分钟 | 当前客户端与仓库NAS服务响应字段静态匹配；readyz不等于指定日数据就绪 | 手机上的HTTPS穿透、bars/coverage真实返回仍未验证 |
| 新闻 | F中没有可靠新闻供应商接线 | 未接入；保持Unavailable，不得伪造 |
| Theme dark/eye-care | Theme registry已有UIKit trait动态浅/深色背景、文字、风险与图表Token；Root不再强制浅色；十主题深色截图UI用例已定义。护眼Token与真实截图仍未验 | 部分编码；需要Apple构建和逐主题对比验证 |
| 视觉验收 | 本次CI截图导出成功 | 未人工视觉审阅；主题一致性、图表手势、iPhone Air、真机均待验 |
## 2026-10-29 新闻证据接入（待Apple CI/手机实网）

| 需求 | F实现 | 状态 | 验收关闭条件 |
|---|---|---|---|
| 顾问使用真实近期新闻 | iOS对每个分析证券按名称/代码查询Google News RSS；限制近24小时，保留媒体/时间/HTTPS跳转链接，作为DecisionContext只读新闻Observation；超时/无匹配明确Unavailable | 已编码；本机DNS不可达；未编译、未实网 | Apple CI通过；真实iPhone成功取到RSS并确认来源/发布时间/链接；DeepSeek能引用实际证据ID并标明标题未核实 |
| 新闻来源边界 | Google News RSS是搜索聚合标题，不是新闻正文或核实事实；链接可能跳转且没有稳定服务承诺；仅查询代码/名称，不发送账本；模型不得从记忆补造即时新闻 | 已加提示词和设置说明；仍待实际顾问验证 | 检查输出引用与缺失降级；RSS不可用时不得声称新闻指导已成功 |


## Run 99/100：顾问新闻标题证据（CI通过，真实新闻E2E未通过）

| 验收项 | 当前实现/证据 | 状态 | 关闭条件 |
|---|---|---|---|
| 新闻Observation进入Advisor上下文 | 对当前Portfolio/证券scope内代码查询近24小时Google News RSS；最多5条、真实标题/媒体/发布时间/HTTPS Google News链接，失败明确Unavailable；RSS内容只读注入DecisionContext | Run 100 `31bee6ce6559d5500d9ef82a1d01b75797d1fe17` 已通过FCore 165/165、UI XCTest 4/4、XcodeGen、Device/Simulator Build、截图导出和unsigned IPA打包/校验/上传 | 实际iPhone取到真实相关标题并确认时间、来源、链接；DeepSeek正确引用Observation且不臆测正文 |
| 新闻可信度与隐私 | Google News RSS是搜索聚合，不是媒体正文/事实核验；链接可能跳转且无稳定服务承诺；只发送证券查询词，不发送Ledger | 已编码并记入AI约束/设置说明 | 设备实网/AI输出实测；失败明确Unavailable；不得以HTTP 200或CI Build替代 |
| 新闻真实E2E | 当前环境DNS无法解析`news.google.com`，Apple CI仅编译和测试，不做RSS外网请求 | External Pending | 设备网络确认可达、标题相关、来源可追溯、AI引用行为正确 |



## 2026-10-29 静态缺陷检查与新闻源变更

| 检查项 | 实际检查 | 结果/状态 | 后续验证 |
|---|---|---|---|
| App源码崩溃型写法 | 扫描App Swift Sources中的fatalError、preconditionFailure、try!、as! | 未发现；固定新闻及DeepSeek URL的强制解包改为安全失败路径 | 当前HEAD Apple Compile + XCTest |
| Ledger写入边界 | 搜索并检查FConfirmedLedgerWriter调用上下文 | 调用集中在明确用户确认的账户/成本/成交/费用修正；Candidate关联在成交后；仅静态结论 | 当前HEAD测试和真实成交E2E |
| 新闻实网 | 真实HTTP尝试 | 本环境本机代理127.0.0.1:7890拒绝连接；端点实测失败于本地代理层，不能判断服务器可达性 | Apple CI后用iPhone网络实测Tonghuashun JSON与新闻关联 |
| 新闻证据边界 | 源码/提示词审阅 | 市场标题仅背景，只有明确证券代码匹配才作为个股新闻；缺失不由模型补造 | DeepSeek引用Observation实测 |


## 2026-10-30 Run 102 actual execution evidence

| Requirement | Actual result | Status |
|---|---|---|
| FCore tests | 165 executed / 165 passed / 0 failed | Passed on source SHA `6c969079ac7499602ee9a8469b057f061d133e08` |
| XcodeGen | Project generation successful | Passed |
| iOS Device Build | Successful | Passed |
| iOS Simulator Build | Successful | Passed |
| App UI XCTest | 4 executed / 4 passed / 0 failed | Automated UI tests passed; not manual visual acceptance |
| Screenshots / IPA | Screenshot export, unsigned IPA validation/package and artifact upload succeeded; artifact `12945537710` | Passed |
| Tonghuashun / NAS / DeepSeek real E2E | No live provider/device verification in this run | External Pending |
| Simulator visual / iPhone Air | CI screenshots were exported but not manually reviewed; no physical-device test | External Pending |

- 实时分钟及指数报价现通过FMarketQuoteTrustPolicy来源白名单；未知source不计作可用/新鲜，也不能进入Advisor、Local Quant或Trigger。相应XCTest与Python合同已定义，当前Windows未执行Python/Swift；未发生提交或推送。

- NAS历史日K现由iPhone按目标市场/指数校验上游来源；本地Quant也拒绝未知证券日K来源。新增回归已定义，未执行Swift/Python。

- 跨市场指数时点解析现在要求完整12/14位ASCII数字，不再从畸形输入中提取数字；Market Regime/指数历史/API合同34/34通过，Swift用例未执行。

- Market Regime门控现令证券自身R3/R4风险立即关闭策略许可；Local Quant不再因仍保留Bull/Range确认标签而报告策略准备可用。新增2项Swift回归定义和源码合同，Market Regime/Local Quant/Advisor/追踪合同50/50通过；Apple XCTest未执行。

- Regime历史bar现拒绝非有限时间戳（包括负无穷），否则该输入可能参与长期均线并被误判可靠。新增Swift回归定义，聚焦合同26/26通过；Swift/XCTest未执行。

## 2026-11-02 XCTest 调用点修复（等待 Actions）

- 第三轮 iOS CI 的 FCore 源文件已编译；测试目标因 6 处 throwing FAccountBook 未加 `try`、2 处 CandidateShadowSnapshot 参数顺序错误、3 处 FConfirmedFill 未传 `fee`、1 处抛错的 priceRange 调用未加 `try` 而中断。
- 上述调用已修正。Windows 环境无 Swift/Xcode，仍须等待下一轮 Apple runner 编译和测试结果；未把它标记为已构建通过。

## 2026-11-02 Risk Guard 溢出用例路径校正（等待 Actions）

第四轮 iOS CI 已编译并运行测试；唯一失败是持久化边界大测试中的 Risk Guard 溢出断言。测试给出的 `Int64.max` 委托量超过场内基金单笔上限，实际命中交易规则拒绝，未进入 Decimal 乘法。现改为合法最大委托量和 `1e126` 价格，使限价仍满足千分位规则、名义金额乘法超出 Decimal 范围，从而验证溢出会 fail closed。下一轮 Actions 确认前保持待验证状态。

第五轮 iOS CI 中该断言再次失败；用例的最新行情价仍低于限价，触发防追价结果并提前离开。已把行情价设为同一超大价格，使下一轮覆盖后续金额校验。Actions 尚待验证。

进一步复核发现 `159352` 买入候选也必须提供映射指数的 Regime 证据；该证据此前未加入测试上下文。现已补齐基准证据及候选引用，下一轮重新验证金额溢出分支。

第六轮运行中该 Risk Guard 用例通过；随后 FDecisionFinancialMath 对 Decimal 极值执行原生 `+` 导致 XCTest 进程 signal 5。已将 `add` / `sum` 改为 `NSDecimalAdd`，遇到任何非 noError 状态都返回 nil。下一轮验证数值修复与完整构建。

第七轮仍在 P&L 极值测试开始后 signal 5，日志没有给出具体断言/堆栈，尚不能确认修改有效。四种算术输入已拆分为单独测试以定位触发项；数值溢出回归保持待验证。

第八轮拆分后可确认 Decimal 极值加法、sum 溢出和相消测试已通过；signal 发生于非有限输入用例启动阶段，其测试值由 `Decimal(Double.infinity)` 构造。现改用 `Decimal.nan` 覆盖非有限拒绝路径，并同时修正账本、行情图与日K相关测试中的同类构造；Actions 待验证。
## 2026-11-02 最新 main 执行证据校准

以下执行证据绑定源码提交 `73bfb479fb60e0d611661157045f6d593fa2c795`；之后仅文档提交 `ad435bda770f649072e90040249c43df851fb7f2`更新了交接/验收记录，没有改变被CI验证的Swift/Python源码。不得把早期运行结果挪用到其他源码SHA。

| 验收项 | 最新 SHA 实际结果 | 证据边界 / 后续验收 |
|---|---|---|
| F Swift package tests | GitHub iOS Run 222 成功 | 本次工具返回的Job步骤没有测试计数；不猜测 defined/executed/passed 数字 |
| XcodeGen / iOS Device Build / Simulator Build | 全部成功 | 仅CI构建证据 |
| 导航 UI XCTest | Job成功 | 不等于人工交互或视觉验收 |
| Simulator截图导出 | 成功，artifact ID `13114433497` | 本轮未人工查看截图；视觉状态仍待审 |
| unsigned IPA打包、校验与上传 | 成功 | 不证明已在iPhone安装、签名或运行 |
| Python/NAS完整CI、compileall、架构边界 | Run 25全部成功 | NAS真实服务、历史数据仍须实测 |
| 本机Windows Python unittest | 295发现；293通过；2个模块因缺PyYAML不能导入 | 环境依赖差异；CI已安装依赖并全绿 |
| NAS HTTPS / 指定历史日分钟→App | 无当前SHA实机端到端证据 | 未验收；Ready/HTTP 200不能替代数据查询成功 |
| 新闻源真实响应与Advisor引用 | 无当前SHA实网证据 | 未验收；源码存在不等于新闻E2E |
| DeepSeek真实服务、Candidate确认成交、Ledger更新后AI复判 | 无当前SHA端到端证据 | 未验收；候选永不直接写账 |
| Simulator人工视觉 / iPhone Air | 未人工验证 | External Pending |
# 2026-11-02 增量验收记录（当前主线续审）

| 条目 | 最新状态 | 证据/限制 |
|---|---|---|
| 统一图表详情尺寸（实时分时/日K/NAS历史分钟） | 已编码并经Apple CI编译/UI XCTest通过 | `GuanpanFApp/Sources/HomeExperience.swift` 三处详情图由320pt增至420pt；行情列表紧凑图仍320pt。无本轮构建或视觉证据。 |
| 统一renderer的指标与手势 | 源码存在，Simulator人工验收待完成 | `FUnifiedSecurityChart.swift` 提供VOL/MACD、MA5/10/20/60/250、成本/候选层、IOPV参考、十字/拖动/缩放；不能据此认定图表体验通过。 |
| 最新已执行Apple CI | Run 224 [41398262288] / Swift SHA `f1f2c2914a4b57e178ab03142e7bb6e57aed7acd`：FCore 335/335、UI XCTest 12/12、XcodeGen、Device/Simulator Build、截图导出、IPA校验/打包均成功 | 420pt图表Swift已编译，自动UI通过；CI截图未人工审阅，iPhone Air仍External Pending |
| 用户设备视觉反馈 | 未通过/External Pending | 用户截图明确指出图表小、轴标签/图层操作观感差；本轮尚无新截图人工审阅。 |

## 2026-11-02 当前HEAD 898849a CI与图表高度回归修正

| 项目 | 当前证据 | 状态 |
|---|---|---|
| HEAD | `898849a29f8bce31c7fc75ce14bed8b1e67c2d55`，本地与 `origin/main` 对齐 | 已推送 |
| iOS Run 223 | [41396767565](https://github.com/ggjj45830/guanpan-f/actions/runs/41396767565)：FCore 335/335、XcodeGen、Device Build、Simulator Build成功；UI XCTest 12项中10通过、2项失败，均为旧320pt上限断言；截图导出及Artifact上传成功，IPA步骤跳过 | 尚不能记为整条通过 |
| Python/NAS Run 26 | [41396767567](https://github.com/ggjj45830/guanpan-f/actions/runs/41396767567)：306项中305通过；唯一失败为`test_home_layout_contract.py:41`仍断言详情图320pt，和新420pt产品要求冲突 | 测试合同需同步，非NAS运行时故障 |
| 测试合同修正 | 静态合同改为详情3处420pt、紧凑图1处320pt；UI XCTest增加详情图400–424.5pt范围断言 | Run 224 UI XCTest 12/12通过；追溯/布局静态合同本机30/30通过 |
| Simulator/人工视觉 | Run 224自动截图已导出但未人工审阅；无iPhone Air实测 | External Pending |
## 2026-11-02 f1f2c29最终CI结果与追溯修正

| 项目 | 证据 | 当前处理 |
|---|---|---|
| Python/NAS Run 27 | [41398262417](https://github.com/ggjj45830/guanpan-f/actions/runs/41398262417)：306项唯一失败为B-058追溯矩阵引用旧UI测试方法 | 已更新B-058锚点；本机相关追溯+布局合同30/30通过；未声称全量CI重跑 |
| iOS Run 224 | [41398262288](https://github.com/ggjj45830/guanpan-f/actions/runs/41398262288)，SHA `f1f2c2914a4b57e178ab03142e7bb6e57aed7acd` | FCore 335/335、UI XCTest 12/12、XcodeGen、Device/Simulator Build、截图导出、观盘max IPA校验与打包均成功 |
| 视觉验收 | Run 224截图Artifact 13120891486 | 已导出，尚未人工逐张审阅；iPhone Air真机验收仍External Pending |

## 2026-11-02 全盘审计清单续记（当前SHA）

- 逐项目标清单：[`F-AUDIT-TARGET-CHECKLIST.md`](F-AUDIT-TARGET-CHECKLIST.md)，A01–A32。各项区分源码确认、指定SHA自动测试和外部验收；不能把一层证据继承成下一层完成。
- 当前SHA `edd14a397b70a8203467c39fa06133baa5e564ff`：iOS Run 225 [41404815642](https://github.com/ggjj45830/guanpan-f/actions/runs/41404815642) 完成FCore 335/335、UI XCTest 12/12、XcodeGen、设备/模拟器Build、截图导出及观盘max IPA打包校验；Python/NAS Run 29 [41404817391](https://github.com/ggjj45830/guanpan-f/actions/runs/41404817391) 完成306 tests、compileall和架构边界检查。
- 该SHA新增Swift修正：跨市场涨跌摘要颜色统一接入主题语义tokens；不能据自动CI断言跨页面主题视觉已经一致。
- 第一轮静态核对：初始持仓入口、真实成交录入路径、MACD显隐renderer及watchlist基础加入/移除源码存在；自选综合评分/迷你走势图、NAS真实部署契约、新闻实网/顾问引用、B→F逐页视觉对比仍未达标或待验。
- 安全边界首轮扫描未发现券商自动下单路由或硬编码密钥；6处Ledger writer调用点均对应用户主动确认操作。出站请求字段/日志/fixture隐私检查尚未完成，不关闭A28。
- 产品架构依照2026-11-02用户决策：实时行情 + 本机Ledger + iPhone Local Quant + Risk Guard + DeepSeek Advisor + Realtime Trigger为核心；NAS为可选增强，不得列为Advisor必经依赖。旧NAS主链条描述若冲突，以该决策为准。
- Simulator截图只记录为“已导出”，未人工逐张审阅；iPhone Air、真实NAS/新闻/DeepSeek/确认成交端到端均保持External Pending。

## 2026-11-02 八项用户目标状态（当前dirty SHA，不继承旧CI）

| 目标 | F源码锚点 | 当前状态 | 关闭证据 |
|---|---|---|---|
| 自选方向观察分/分钟迷你线 | `Sources/FCore/LocalQuantEngine.swift`; `GuanpanFApp.swift`; `HomeExperience.swift` | 已编码、未编译；分数fresh且≥3有效因子 | 本SHA FCore/UI CI + 列表实机每10秒刷新视觉验收 |
| 设置页密度 | `HomeExperience.swift` SettingsOverview | 已编码、未编译 | 当前SHA UI测试、Simulator/手机截图审阅 |
| 主题跨页一致性 | `ThemeLayoutManifest.swift`; 核心View共用theme storage/tokens | 源码部分一致、截图矩阵未做 | 每个主题×6核心页面/明暗护眼截图及人工审阅 |
| B/F逐页视觉比较 | `F-B-UI-PRODUCT-GAP-AUDIT.md`; Frozen SHA `9ddfe32…` | B Frozen源码静态对读；没有同态B/F图；F不如B | 逐页面结构迁移、同尺寸同状态B/F人工截图 |
| NAS历史分钟真实契约 | `FNASConnection.swift`; `nas/fminute/http_api.py` | 源码字段静态匹配；部署端与手机HTTP 200 payload未验 | 同security/date真实响应、coverage/bar/timezone/source、iOS图表准确显示 |
| 新闻真实可达及顾问引用 | `FNewsClient.swift`; Advisor pipeline | 来源实现/上下文传递已核；设备HTTP和DeepSeek引用未验 | iPhone收真实标题/来源/时间/URL并在本轮DeepSeek响应可核引用 |
| iPhone Air | 外部设备验收 | External Pending | 真机界面/输入/导航/图表手势/主题切换录屏或截图 |
| DeepSeek真实成交闭环 | Advisor/Candidate/`FConfirmedLedgerWriter`路径 | 代码路径存在；无真实E2E证据 | 真实会话、原Candidate、用户确认券商fills、Ledger对账、Advisor重新读取全过程 |

旧版矩阵中的历史状态行不代表当前dirty修改已经验证；新增行以本轮核对为准。

图表主题一致性增量：本轮把F图表轴、网格、VOL/MACD标签、十字线、非选中图层中性颜色接入当前theme secondaryForeground。仅编码，未Apple编译或Simulator视觉验证。

## 2026-11-02 量化时间因果顺序回归增量

| 验收项 | 源码要求 | 测试证据 | 当前状态 |
|---|---|---|---|
| 本机Quant Regime不得晚于输入报价 | `FLocalQuantEngine`证券Regime和映射指数Regime的dataAsOf与记忆评估时间均要求不晚于`quote.quoteTimestamp` | `LocalQuantEngineTests.testRegimeEvidenceLaterThanQuoteCannotInfluenceLocalQuant`覆盖证据与记忆时间晚于报价；相关Python源码合同集82/82通过 | 已编码/合同通过；Swift XCTest未在本机执行，待Apple CI |
| IOPV溢价不得混用不同报价时点 | `FLocalQuantEngine`仅接受观察时间不晚于报价时点的IOPV；较新IOPV不参与较早报价的溢价因子 | `LocalQuantEngineTests.testIOPVFactorRejectsUnknownOrStaleReferenceSource`增加较新IOPV+旧报价场景；相关Python源码合同集82/82通过 | 已编码/合同通过；Swift XCTest未在本机执行，待Apple CI |
| 实时Trigger不得以未来Regime评估旧报价 | `FRealtimeQuantTrigger`要求Regime数据与记忆评估时间均不晚于`quoteTimestamp`；违规暂停且confidence=0 | `RealtimeQuantTriggerTests.testRegimeEvidenceLaterThanQuoteCannotTriggerFromOlderQuote`覆盖证据/记忆时点；相关Python源码合同集82/82通过 | 已编码/合同通过；Swift XCTest未在本机执行，待Apple CI |


## 2026-11-02 dirty worktree 审计补充（基于 HEAD b65ee7c）

| 项目 | 源码处理 | 实际验证 | 仍未完成 |
|---|---|---|---|
| 实时分时横轴/真实采样断档 | 按实际当日分钟扩展绘图区；午休压缩；长缺口断线；横轴标签增加最小间距 | Python合同包含图表源码约束；本地合同集通过 | Swift编译、运行截图、iPhone Air连续刷新/手势 |
| NAS历史HTTP 200契约错误诊断 | 非404/405直接显示新路由首错；仅路由不存在才走B兼容路径 | 新增NAS客户端合同，定向合同通过 | 生产NAS payload和指定交易日实际分钟仍未取得 |
| NAS与本地Quant依赖分离 | 本地参数验证不再错误标为NAS qualification；仍未合格时安全WAIT | Advisor/Local Quant静态合同通过 | 参数包/回测质量与Apple编译尚待完成 |
| Python验证 | — | 定向73/73；除2个缺PyYAML模块，其余Tools测试295/295；NAS compileall通过 | 需CI依赖完整环境跑两个未执行模块及完整CI |

此补充工作树dirty且尚未CI编译；以上不得作为最终交付验收。

| 2026-11-02 续审增量 | 变更/结果 | 当前裁决 |
|---|---|---|
| 设置页可选服务与新闻状态 | 将NAS分组命名为“可选同步与数据服务”，缩短网络说明；新闻区域显示`model.newsStatus`并明确公开源与顾问引用边界 | 静态合同通过；Swift未编译/Simulator未验 |
| 自选自动趋势/观察分 | 行情快照10秒轮询并绘制真实分钟迷你线；fresh报价且≥3个有效因子时提供方向观察分 | 已有源码，不等于预测有效；需要历史验证及真机刷新视觉验收 |
| 持仓入口/MACD | 初始真实持仓快照、空仓真实成交建仓、日K MACD源码均存在 | 入口可发现性和交互仍External Pending |
| B/F、全主题、NAS实网、新闻DeepSeek引用、iPhone Air及真实成交闭环 | 保持实际验收要求 | 未通过；不能由源码或旧CI关闭 |
| 本轮证据 | Home布局合同28/28；NAS/Local Quant/Advisor/Traceability 41/41；宽套件运行异常不计通过。远端main=`a1ba64582c29340596d5f5f1639ebc5478a5186c`，最近Actions活跃0；fetch失败，未推送/未触发CI | 当前Swift编译和人工截图验收均未执行 |
## 2026-11-02 全盘Bug审计修复增量（以本节记录的本地dirty源码为准）

| ID | 验收要求 | 当前源码改动 | 状态 | 关闭条件 |
|---|---|---|---|---|
| BUG-01 | IOPV溢价使用不晚于目标行情报价的IOPV，并与Quant使用同一报价价格 | Advisor DecisionContext要求参考观测不晚于报价时间，溢价改用该报价快照价格 | 已编码；未编译/未测试 | 当前SHA Apple CI + 实际报价/参考数据时序回归 |
| BUG-02 | Quant/Regime不得使用报价日或交易所当前日尚未完成的日K | FCore Quant始终排除报价日及未来日K；App证券/跨市场Regime按本地日期过滤；跨市场收益使用过滤后的bars | 已编码；未编译/未测试 | 当前SHA Apple CI + 未收盘/历史报价时点回归 |
| BUG-03 | NAS历史分钟HTTP 200 schema错误必须可定位具体字段，而不被兼容路由404掩盖 | iOS错误现在保留顶层响应诊断，并附DecodingError字段路径及类型/缺失原因；200仍不触发旧路由fallback | 已编码；未编译/未实机 | 当前SHA CI + 用户设备实际HTTP 200响应对照 |
| EXT-01 | NAS exact-date历史分钟部署契约匹配且返回真实bars/coverage | 本轮未改服务端；此前手机存在HTTP 200 schema不符及404证据 | External Pending | 实际部署响应契约、真实日期数据、iOS渲染端到端通过 |
| EXT-02 | 新闻真实源可达并被DeepSeek按ID/来源/时间/链接引用 | 本轮未改新闻provider | External Pending | 真设备实际新闻响应 + Advisor真实响应引用验证 |
| EXT-03 | iPhone Air当前版视觉、图表交互和多主题一致性 | 未进行人工Simulator/真机验证 | External Pending | 当前SHA截图逐页人工审阅与iPhone Air交互 |
| EXT-04 | Candidate真实成交确认后Ledger更新并由Advisor重新读取 | 本轮未进行真实交易E2E | External Pending | 用户确认的真实fills全链路可核对且无候选自动写账 |

上述源码改动尚无本SHA编译或测试证据；不得继承旧SHA的CI结果。当前修复提交为`19590bd`；GitHub只读API确认远端`main`=`a1ba64582c29340596d5f5f1639ebc5478a5186c`为本地链祖先、queued/in_progress Actions=0；普通push因本机`getaddrinfo() thread failed to start`失败，未触发CI。本交接状态记录提交后本地main ahead 6。
# 2026-11-02 六套视觉概念执行增量

| 验收项 | 状态 | 证据/剩余工作 |
|---|---|---|
| 六套首页概念进入Settings主题栏 | 已编码，未编译 | FHomeTheme.allCases限定六套；Apple CI待执行 |
| 六套首页构图有明确差异 | 已编码，未视觉验收 | 山景头版、深空终端、珊瑚拼贴、蓝海资产、夜航量化、极光全景分别使用独立区域排序/模块结构 |
| 单一真实业务模型 | 已编码，未编译 | 六套读取同一FHomeModel；未注入概念图假数据 |
| 主题在首页/行情/详情/图表一致 | 已修源码，未编译 | 首页、市场、顾问、资产、设置、统一图表改用FHomeTheme.selected解析器 |
| 六主题UI XCTest | 已更新，未执行 | 当前Windows无Xcode；必须由Apple CI验证当前HEAD |
| 六套Simulator截图并排对比 | 未完成 | 需当前SHA CI导出后实际查看；导出成功不等于人工视觉通过 |
| iPhone Air / 深浅色 / 动态字体 | External Pending | 需Apple Simulator或真实iPhone验收 |

视觉结果不得因代码实现或测试通过升级为视觉Pass。逐屏截图和灰度构图审查完成前，状态保持“视觉未验收”。

## 2026-11-02 自选/持仓混合状态回归

| 验收项 | 最新CI结果 | 修正/待验证 |
|---|---|---|
| 自选中已持仓证券的身份提示 | Run `41462998125` UI XCTest 12/12通过 | “真实持仓 · 自选”状态和自选筛选回归已由当前SHA验证 |
| 当前SHA编译/完整UI/IPA | Run `41462998125` FCore 338/338、XcodeGen、设备构建、Simulator构建、UI XCTest 12/12、截图导出、IPA校验/打包和Artifact上传全部通过 | Simulator截图已导出；人工逐张视觉审阅及iPhone Air实机验收仍未完成 |

## 2026-11-02 全局页面风格与主导航增量

| 验收项 | 当前实现 | 状态 |
|---|---|---|
| 五项底栏与中央圆形AI入口 | 自绘导航，标签为首页/行情/AI顾问/资产/我的；继续使用原Tab路由 | 已编码；待当前SHA Apple CI |
| 行情、证券详情、AI、跨市场、资产、设置主题统一 | 共享主题感知主视觉和主题色表面已接入核心页面 | 已编码；待当前SHA编译与逐页截图核验 |
| 业务数据与页面真实数据 | 保留现有ViewModel、Ledger、行情和Advisor数据流；未向真实账本注入预览数据 | 已编码；待CI验证 |
| 与用户概念图的视觉一致性 | 已照着暖色底、彩色强调、中央圆形AI导航推进 | 尚未通过截图人工对照；不能标记视觉完成 |
| Windows/Simulator及iPhone Air验收 | 本环境无Xcode/iOS Simulator；需Apple CI图像导出与真实iPhone检查 | External Pending |

