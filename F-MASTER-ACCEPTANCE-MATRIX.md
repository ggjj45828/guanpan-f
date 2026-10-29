# F Master Acceptance Matrix

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
- 新增架构验收：AI建议、Quant信号、市场结果、用户确认成交四者必须分离；Candidate快照不可变；Shadow只存市场事实和成交ID，不可写Ledger；没有Fill关联时Execution=Unknown；明确复核后才可记未执行。NAS为可选能力，不是Advisor依赖。
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
| NAS可选，不再阻断Advisor | `GuanpanFApp/Sources/GuanpanFApp.swift`及NAS客户端 | 既有基础接线；服务E2E仍未验证 | NAS关机/未配置时验证本地核心链正常；不再要求NAS历史分钟作为必经条件 |

## 历史HEAD与验证快照（已由上方当前工作树补记覆盖）

- HEAD `b099c9d0d9c703f56540b6fa4d3d30cfbb3ddefe`，`main`与`origin/main`同步，工作树干净；合并后通过普通push更新远端，没有强推。
- 历史Apple CI Run `40710039609`指向`b099c9d`；其最终run结论为failure，但唯一job取消且无步骤。它不验证本工作树。
- 当前定义：FCore XCTest 153；App UI XCTest 3。旧提交140/140及3/3不可继承。
- NAS降级为可选同步/备份/归档/研究增强；核心链改为实时行情 + 真实Ledger + 本地确定性Quant + Risk Guard + Realtime Trigger + DeepSeek Advisor。当前Quant仅价格区间触发评估器；完整Quant因子、Risk/行情/持久化/UI接线未完成，资产变化Candidate保持fail-closed。
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
| P1 NAS客户端 | 用户报告手机HTTPS NAS未连接；本轮没有手机现场响应或NAS目标可访问证据 | NAS是可选增强；不猜测、不改NAS服务端；等待手机新错误证据 | 未解决/未验证，不阻断核心顾问 |
| P2 顾问/成交 | 没有当前HEAD真实DeepSeek→Guard→Candidate→确认成交→Writer→现金/成本/盈亏/T事实→复判E2E | 保持Candidate只读、只有用户确认真实成交写账 | 未完成；需外部Key、服务和真实操作验收 |
| P2 数据/市场 | 实时报价、跨市场实时数据、可靠新闻、均价/前收/IOPV的真实数据质量不能由静态代码证明 | 保持缺源Unavailable；NAS只作可选；不造研究证据 | 多项未接入或External Pending |
| P2 恢复/提醒 | 通知中心、价格/计划提醒、跨设备同步恢复、完整备份恢复仍是B/F差距项 | 未新增大页面；保留在NRG清单 | 未完成 |
| P3 兼容/交互 | 横屏全屏状态恢复、图表手势冲突、长文本/Dynamic Type、iPhone Air适配、10主题灰度构图对比没有本轮实测 | 不把CI自动截图或UI XCTest当人工视觉结果 | External Pending |
| P4 发布 | 当前dirty Swift未编译，当前HEAD Apple CI未执行；当前Windows无Swift/XcodeGen/xcodebuild | 禁止继承旧CI结果；静态检查通过，架构边界脚本因Python启动器不可用未运行 | External Verification Pending |
| P4 Git | GitHub Desktop Fetch确认本地HEAD相对真实origin/main ahead 1 / behind 8；存在分叉 | 尚未reconcile/push；先审查8个远端提交并保留本地工作树，再普通推送 | 同步处理中；禁止强推 |

本轮完成的源码收口：图表MA、均价/成本/券商成本/IOPV/Candidate叠加、数据质量状态及K线上涨/下跌色改用`FThemeSemanticTokens`；CardGrid、Dashboard、FluidGlass的manifest roleOrder已对齐实际布局。仍未解决的已知源码结构问题：不同layout的几何结构由SwiftUI family renderer实现，Gallery预览只能展示简化role顺序；十主题尚不能纯靠注册manifest扩展。后续须CI与主题截图审阅，不能把Theme Manifest存在写成架构收口。

| 验收项 | 当前工作树证据 | 状态 |
|---|---|---|
| NAS核心依赖移除 | Advisor无NAS配置时跳过请求；NAS Evidence只在上下文提供时可选引用。NAS不再是核心决策前置；历史矩阵中旧的“NAS是必需条件”只作历史追溯 | 已编码，当前Swift未编译；NAS服务端未改 |
| Trigger状态机回归 | `Tests/FCoreTests/RealtimeQuantTriggerTests.swift`新增12项定义；涵盖等待、接近/触发、过期、stale/未验证/休市暂停、暂停恢复后错过价格区、证券/计划身份错配、显式失效、T信号和Filled边界 | FCore总计153 defined；当前HEAD 0 executed / 0 passed / 0 failed |
| Apple CI/Simulator | 当前本机无Swift/Xcode/XcodeGen；最近Run 58为取消，不能为当前dirty工作树提供构建结果 | External Verification Pending；无当前树Simulator截图/人工验收 |
| Git同步 | HEAD `e500fc84f6dd8acf93cc32305aefcff28e700f4e`；相对缓存origin/main ahead 1 / behind 8，远端实时状态未确认 | 未reconcile、未push；禁止强推 |

当前实现仍缺完整Quant因子（MA/成交量/波动/真实Ledger上下文）、Risk Guard集成、实时行情订阅、状态持久化/通知和Home/Detail接线；资产变化Candidate仍fail-closed。`git diff --check`通过；架构边界脚本因Windows Python启动器不可用而未执行。NAS真实部署、历史分钟、DeepSeek E2E、真实成交闭环和Simulator人工验收仍未完成。不得把定义数或静态检查写成测试通过。

## 2026-10-28 核心架构决策更新（覆盖旧的NAS必经表述）

- 产品决策：NAS降为可选同步/备份/历史归档/扩展研究服务；核心为实时行情 + 真实Ledger + iPhone本地Quant + Risk Guard + DeepSeek Advisor + Realtime Trigger。完整契约见 `F-LOCAL-QUANT-ARCHITECTURE.md`。
- 旧行中将“NAS分钟研究”设为所有 Advisor/Candidate 的必经门槛，均被本次决策取代。NAS Evidence仍是可选增强；无NAS不可阻断基础Advisor。T/网格等受风险约束的动作不能简单移除原有保护，须由可验证的本地Quant条件替代并通过测试后才可调整。
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
| F-THEME-08 外观兼容 | Manifest诚实标注浅色基础token已接入，深色/护眼与Dynamic Type待完成 | 部分编码 | light/dark/eye-care、文字缩放和小屏待验 |

## 关键Ledger字段当前实现边界

| 能力 | 当前源码事实 | 状态 | 未完成条件 |
|---|---|---|---|
| Security Daily P&L / 今日盈亏 | `Sources/FAdvisor/DecisionContext.swift`构建`FDecisionInstrumentPnL`时将`securityDailyPnL`设为`nil`；提示词会要求Unavailable，不会借用已实现盈亏代替 | 尚未接通，安全降级已编码 | 增加可追溯的当日开盘持仓数量来源，以及带日期/来源/质量的可靠前收输入；二者完整时才调用确定性公式，并覆盖日内清仓重买和跨日测试 |

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
| F-16 | AI 最终建议读取真实持仓、行情、可选背景与风险证据 | defined | DeepSeek provider、只读账本快照、DecisionContext、Risk/AI Guard及组合/证券scope已编码；NAS现为可选增强，无NAS不得单独阻断基础顾问；本地Quant尚未接入，资产变化候选由“Quant未接入”fail-closed；新闻仍Unavailable；当前HEAD未编译/未联调 |
| F-17 | T、网格、回本仅为 AI 可调用分析工具，不自动交易 | defined | NAS研究工具保留为可选能力；FAIGuard仍保留T/vwapBreak、网格/gridSpacingReplay条件，须待本地Quant安全条件替代并验证后才可改；策略和真实服务适配未完成。旧119项CI数字仅为历史，不代表当前HEAD |
| F-18 | 行情、分时、日K、MA250、IOPV、盘口标注来源/新鲜度 | defined | 统一`FUnifiedSecurityChart`由当前/历史分钟和日K共用；MA/成交量/成本/券商成本/Candidate/IOPV按可见层参与价格范围。IOPV有值时存在绘制与图例路径，但没有可靠来源，保持Unavailable。图表语义色本轮改为主题tokens，未编译；视觉、手势和真机仍待验 |
| F-19 | 可选NAS归档/研究、跨市场和新闻与真实账本隔离 | defined | NAS v6曾有用户提供的实时分钟归档烟测；NAS不再是Advisor核心前置。NAS历史补采曾返回empty source response；跨市场/新闻/iOS端到端和长期运行未验证。跨市场非对称关系与证券级映射没有合格样本，不进入DecisionContext |
| F-20 | 同步、离线冲突、通知与恢复状态可见且不丢账 | defined | 三通道策略已编码；传输、离线队列、通知 UI 和恢复体验未实现；FCore 119项全量已执行通过，但这不覆盖缺失的产品功能 |
| F-21 | AI 聊天、导航、图表、横屏和设备布局可用 | defined | 原生五Tab与独立NavigationStack、真实账本/行情、AI顾问输入和结果页已接线；当前/历史分钟和日K已复用共享SwiftUI renderer。App UI XCTest 3/3通过（run 旧执行编号省略；覆盖导航、Advisor主要控件和资产页基础结构）；图表功能/视觉、横屏和设备布局验收仍未完成 |
| F-22 | 十个独立主题的 token、页面一致性、可读性和设备截图验收 | defined | 十个首页layout family、语义token与共享role renderer已编码但未Apple编译；跨页面一致性、主题差异截图、可读性和设备验收未完成；未继承 A/B 主题结论为通过 |
| F-23 | 单一权威实现、模块边界、依赖和故障可诊断 | defined | FCore/FAdvisor/FLedgerWrite 依赖隔离；架构边界脚本当前通过；Actions run 旧执行编号省略 已完成 FCore 与 App Device/Simulator Build；后续修改仍需重跑 |
| F-24 | 核心测试按模块执行，记录 defined/executed/passed/failed | defined | 账本 XCTest 已定义；FCore XCTest：119 executed / 119 passed / 0 failed（Actions run 旧执行编号省略）；各产品验收项仍按实际覆盖范围判定 |
| F-25 | NAS历史分钟补采、实时归档、完整度、长期留存、查询、诊断和研究证据/no-lookahead | defined | 归档/补采/查询/研究链已编码；累计量差分来源必须保留累计量且差值匹配分钟量；归档启动/完整性/备份恢复校验、no-clobber备份、版本化队列和严格HTTP输入/授权边界已覆盖；交易日历、日期、时区、幂等、Partial门控、指定日期Missing/Partial逐日诊断和范围隔离有回归；无范围时列出已评估coverage日期并明确可能低估；分钟服务27/27、归档43/43、红利研究7/7、只读迁移dry-run6/6、Provider/Calendar/runtime10/10，合计93/93通过；腾讯当日接口已实网取样并写入F归档；东财历史接口本云端超时、生产交易日历与NAS部署仍待外部验证 |
| F-26 | 指数卡区分行情时间、获取时间、来源、新鲜度和交易时段；闭市保留最后有效时间 | defined | Quote元数据与最大有效期校验已编码；首页有独立市场入口但当前行情明确 unavailable；现金状态文案区分读取中/未建立/不可读取/已读取；FCore整体119项CI通过，真实源/闭市行为与原生显示仍待验收 |
| F-27 | 首页显著提供组合问答输入、发送、快捷问题和真实持仓上下文；详情入口绑定证券 | defined | 首页/Advisor页输入、发送和快捷问题已接入；默认聚焦首个真实持仓，详情绑定标的；发送时重读账本并构建请求。只读持仓会发送至用户配置的DeepSeek；实际可发现性待Simulator/真机验收 |
| F-28 | 十主题统一普通文字/页面颜色；仅保留业务语义图表色 | defined | Manifest语义token与Gallery已编码；部分首页组件消费主题表面token，图表/全部专业页主题token尚未接入；深色/护眼与设备验收未完成 |
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
| F-41 | F拥有独立App图标；图表指标可逐项显示/隐藏并按可见序列定纵轴；iPhone Air页面布局与真实交互验收 | defined | 1024px独立F图标资产、MA/成交量/成本/券商成本/均价/前收/Candidate/IOPV开关及隐藏MA不再参与视区纵轴已编码；新增一个价格范围XCTest定义。此前F图例为静态文字，B版统一图表有可切换指标按钮。本轮Swift未编译；iPhone Air截图/人工验收、图标进入IPA均待新Apple CI与设备检查 |
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
