# F iOS 全盘静态审计

> 实时更新（2026-10-26）：最新 Apple CI 已完成Swift Package、FCore XCTest 119/119、XcodeGen、iOS Device Build及Simulator Build；两项 App UI XCTest中1项通过、1项因状态文案查询失败。Advisor状态行可访问性修复已编码，待复跑；真机仍未验证。历史审计中“App仅有骨架”的结论已过期；余下旧记录只作追溯。

## 2026-10-26 行情刷新增量复核

在原审计所述骨架之后，F 当前工作区新增了直连 Tencent minute/query 的当前日分钟请求器、严格响应解析、每证券 Observable 快照、首页持仓曲线和详情曲线绑定、详情页立即刷新与常规交易时段10秒自动请求，以及按钮加载/成功/失败反馈。增加8项 MarketMinuteData XCTest定义。此增量尚无 Swift/Xcode 编译证据，未在Simulator或iPhone运行；图表可见性、刷新按钮响应、分钟源真实响应和跨年行为仍External Verification Pending。2027交易日历不会自动生效，未审核年份暂停自动刷新。

审计日期：2026-10-26（Asia/Shanghai）  
审计基线：`52e0fdae984e9c4580a52b562f211d55e7cf7249`；修复后的提交见当前 `F-CHECKPOINT`。  
审计范围：`Package.swift`、`GuanpanFApp/project.yml`、App/首页 SwiftUI 源码、Swift Package 模块依赖、XCTest 定义、GitHub Actions 构建工作流、F iOS/交互验收文档。  
方法边界：当前执行容器为 Linux；没有 `swift`、`swiftc`、`xcodebuild` 或 `xcodegen`。以下结论属于源码/配置静态审阅；没有 Swift 编译、模拟器运行、IPA 产出或设备验收证据。

## 本轮发现并修复

| 项目 | 发现 | 修复与证据 | 结果 |
|---|---|---|---|
| XcodeGen App 模块依赖 | `GuanpanFApp.swift` 使用 `FHomeLedgerAvailability`、`FHomeCardPresentation`，二者定义在 `FAdvisor`；App target 原先未导入或链接该产品 | 加入 `import FAdvisor` 与 `GuanpanF` target 的 `FAdvisor` package product；静态核对 App 本地模块 imports 与产品依赖 | 已修；需 macOS/Xcode 实际编译确认 |
| Application Support 路径 | App 启动时对目录数组执行 `first!`，异常环境下会直接崩溃 | 改为 guard；不可用时设置账本状态 `.unavailable` 和明确状态文案，不访问或修改资产 | 已修；Swift 编译/运行待外部验证 |
| iOS CI 路径 | 旧工作流指向不存在的 `GuanpanNext/ios` 与旧 scheme，F 源码变化不能触发正确构建 | 改为监听 F 的 Package/Sources/Tests/GuanpanFApp；macOS job 配置 Swift Package 测试、XcodeGen、iOS device 与 simulator build、unsigned IPA 和构建证据上传 | YAML/路径静态验证通过；远端 Action 未执行 |

## 当前实现状态

| 区域 | 源码状态 | 验收状态 |
|---|---|---|
| Swift Package | FCore、FAdvisor、FLedgerWrite 三产品；Advisor 依赖 FCore；写入边界独立 | 未编译，Package XCTest defined 31 / executed 0 |
| App target | iOS 16，iPhone+iPad；依赖 FCore、FAdvisor、FLedgerWrite；显示名与 Bundle ID 已配置 | XcodeGen 未运行，target/scheme 尚未生成验证 |
| 真实账本首页 | 通过 `readLedgerSnapshot` 只读读取现金、持仓份额、成本；区分 loading/not-established/unavailable/available | 静态可见；设备持久化路径、重启、空账本和损坏账本 UX 未运行验证 |
| 首页布局/路由 | 五种主题布局分支；市场、跨市场、AI指导、组合和证券详情使用不同 route case | 源码有不同目的地；页面数据任务多数未实现，可发现性未验收 |
| AI 问答 | 文本框、发送按钮、快捷问题、组合/证券上下文标签已编码 | 发送动作目前只弹出“在线 AI 尚未接入”提示；没有组装并调用 DecisionContext/Advisor Pipeline/模型服务 |
| 行情/市场 | 市场观察与跨市场路由页面明确显示数据不可用 | 无真实行情、指数 quote timestamp/source/freshness、新闻或跨市场研究接入 |
| 图表/历史分时 | Package 内存在图表 hit-test 纯逻辑和 XCTest 定义 | App target 没有实际图表视图、历史日期控件、K线手势或横屏图表链路 |
| 主题 | 五套不同首页布局分支与基础背景/accent | 设计 token、全屏页面一致性、动态字体、无障碍对比和截图审查未完成 |
| 首页职责契约 | `FHomeCardContract` 定义角色和目的地约束 | SwiftUI 当前直接使用私有 `FHomeRoute`/`RouteCard`，没有用 contract 驱动卡片目录；静态契约不保证实际点击路径 |
| XCTest | Matrix 中各套件 defined 状态保持 | 无 Swift/Xcode；所有 XCTest executed=0，不能宣称通过 |

## 需要继续完成的 iOS 工作

1. 在 macOS 上运行 `xcodegen generate` 与 `xcodebuild -list`，修正生成工程/Swift 类型错误。
2. 运行 31 项 FCore XCTest，再运行 Boundary、Market/Chart/Advisor、Home Card、Sync Policy 套件；逐套记录执行结果。
3. 将 AI Composer 接入真实 DecisionContext 组装和 Advisor Pipeline；配置密钥安全存储、在线模型调用、失败/离线状态和 Guard 输出。未接服务时继续清楚标为不可用。
4. 建立真实行情/指数时间状态页面，接入 NAS 历史分时查询；不得显示模拟报价、伪时间或伪 IOPV。
5. 在 App target 实现统一分时/日K图表、按交易日查看、tap/long-press/drag/zoom/landscape 和选中详情；复用现有 hit-test 模型。
6. 以 `FHomeCardContract` 作为唯一卡片职责/路由目录，避免 UI 私有 route 与验收契约长期分叉。
7. 完成五主题设计 token、VoiceOver、大字模式、iPhone/iPad 首屏与布局、实际可发现性验证。
8. 远端 macOS CI 尚未运行；GitHub remote/Actions 权限与产物获取仍列 External Verification Pending。

## 本地静态验证

- XcodeGen spec 与 Workflow YAML 可被 PyYAML 解析。
- App 的 FCore/FAdvisor/FLedgerWrite imports 与 XcodeGen package products 静态一致。
- CI trigger 覆盖 F Package、模块源码、测试及 App spec；device/simulator destination 与 IPA artifact 路径配置存在。
- 这些检查不代表 Swift 编译、XCTest、模拟器、IPA 或真机验证通过。

## 2026-10-26 原生主应用接线增量

见 [F-IOS-APP-INTEGRATION-ADDENDUM.md](F-IOS-APP-INTEGRATION-ADDENDUM.md)。App 已增加首页、行情、AI顾问、真实资产、设置五个独立 `TabView` 入口和独立导航栈；AI顾问页显示上下文可用状态并保留明确的未发送状态，真实资产页只读，设置页切换完整主题并显示连接/数据诊断状态。跨市场页面有独立语义和空证据提示。

新增 `GuanpanFAppUITests` target 与2项UI测试定义，并将其加入XcodeGen scheme和macOS CI步骤。当前无Swift/Xcode/XcodeGen，故工程生成、编译与UI测试均未执行。NAS客户端/API token Keychain、DecisionContext/Guard/在线AI、NAS历史查询、日K/历史分时和真机检查仍未接入或待外部验证；此阶段不代表整体App完成。

## 2026-10-26 双作用域与历史分时复核

- Advisor 调用现依据详情入口、持仓代码/名称或组合默认路由到 `.instrument(code)` / `.portfolio`。组合请求逐证券收集当前报价及NAS研究（含明确不可用 observation），使用完整真实账本投影；采集前后与模型返回后均核对账本摘要。
- Guard 对组合范围候选仍按其明确证券代码校验实时报价、可用现金/持仓单位和策略研究证据；组合候选不允许以无标的资产变更结论通过。Candidate 只读展示。
- App层将ETF一次成交估费固定为0.10元、做T买卖两笔按0.20元，AI返回费用不一致时补充Guard finding并阻止作为可审阅候选；仍需XCTest/设备链路确认实际输出。
- 证券详情页新增NAS历史分钟按日请求与日期选择，展示归档来源、coverage与缺失分钟；空结果不画曲线。该实现尚未编译，NAS响应解码/日期选择/UI仍待Xcode及真实NAS运行验证。
- Advisor结果里的组合报价逐项展示证券代码、价格、行情时、抓取时、来源和交易时段；上下文仍分别保留quoteTimestamp与fetchedAt。
- 本次没有增加 Swift XCTest 定义；FCore保持39 defined/0 executed，App UI保持2 defined/0 executed。实际 Swift 编译仍是最高外部技术债。
- 统一图表目前仍缺K线、MA5/10/20/60/250、IOPV、持仓成本/均价/前收线及横屏；页面“真实数据可见/交互可用”不得据当前折线图宣称完成。

## 2026-10-26 保守做T与分钟图交互复核

- `FAIGuard` 不再因未提供订单簿而无条件拒绝 `.dayTrade`。仍要求同证券 `.quote` 通过 freshness 检查且市场时段为 `.continuous`，并要求候选引用同证券、CN市场、质量合格的 `vwapBreak` 研究；Risk Guard继续检查持仓份额和现金。由此允许无盘口保守候选，不允许没有行情/研究的猜测候选。
- AI系统提示禁止声称分析了未提供的盘口；UI把这种候选显示为“保守基础做T·盘口未接入”。ETF买卖单费/做T双边估费校验仍由App层执行。
- 统一分钟折线复用当前/历史bars，加入长按/按钮进入十字光标、拖动选点、缩放及放大后历史窗口平移。尚无日K candle series，故K柱命中、MA、成交量、成本/均价/前收、IOPV和横屏布局还未实现。
- 既有Swift测试场景已改为覆盖无盘口基础做T，定义总数未变；没有Swift/Xcode，执行数仍为0。当前没有用静态检查替代编译/Simulator验收。

## 2026-10-26 证券详情日 K 数据增量

- 已增加腾讯未复权日 K REST请求与FCore parser，输出OHLCV、交易日期、来源、fetchedAt及复权标签；异常/空响应不构造占位bars。 MA窗口由真实收盘价滚动计算，未满足完整窗口时返回nil。
- 证券详情页展示日K蜡烛与MA5/10/20/60/250，并标示来源/抓取时点/未复权状态和不足周期。详情页同时刷新实时分时和日 K。
- 未编译：当前Linux没有Swift、Xcode或XcodeGen。Tencent JSON响应兼容性、Swift编译、均线准确性和Canvas外观均需后续macOS/Xcode验证。成交量、K柱交互、成本/均价/前收/IOPV叠加、历史日K和横屏仍未完成。
- 测试定义维持FCore 39、App UI 2；executed/pass/fail均为0。静态 `git diff --check`仅验证补丁空白格式，不代表编译或行为验收。

## 2026-10-26 统一图表契约静态审阅

- 新增FCore `ChartDataModel.swift`，用同一数据容器表达实时分时、历史分钟和日K；对序列与窗口类型、点的顺序、质量状态、来源/抓取时点作基本校验。实时分时要求可信quoteTimestamp，历史/日线不把fetchedAt伪装成行情时间。
- 新增 `FIOPVObservation`、成本/均价/前收/IOPV/Candidate价格overlay DTO，及可视range、selectedIndex、zoomScale、crosshair和landscapeFullscreen状态。DTO尚未接入HTTP来源或任何页面；IOPV仍Unavailable，候选标记不能写账。
- 静态检查：架构边界PASS、`git diff --check` PASS。没有Swift/Xcode，未编译；没有增加或执行XCTest，定义数保持FCore 39、App UI 2。边界模型是否满足Swift编译/Sendable一致性仍必须经macOS编译闸门确认。

## 2026-10-26 IOPV DTO状态一致性修正

- 发现 `FIOPVObservation` 允许 `.unavailable(reason)` 与有效数值同时通过构造校验。已将有效值路径限定为非Unavailable，并要求Unavailable路径不携带值、来源和时间，仅保留缺失原因。
- `git diff --check`及架构边界静态检查通过。无Swift/Xcode，未编译或运行测试；FCore保持39 defined/0 executed，App UI保持2/0。该修正确认DTO边界，不代表真实IOPV行情已接入。

## 2026-10-26 Portfolio Advisor 路由边界复核

- 组合意图现在先于旁带的六位数字和持仓代码/名称识别。若用户明确询问全组合，即使问题提及单只持仓或金额，也仍将所有真实持仓、现金、逐证券报价/研究及缺失状态纳入Context；从详情页显式发起的请求仍保持Security scope。
- 未持仓代码仅在非组合问题中按明确证券查询拒绝；不会把例如现金数字误当成证券代码来阻断组合Advisor。
- 修改限于现有范围路由分支，无新增SwiftUI或测试定义。架构脚本、diff空白检查通过；Swift编译与XCTest仍未执行，计数保持39/0及2/0。


## 2026-10-26 Advisor 空仓与未持有证券路由修正

- 复核发现“当前账本没有真实持仓”被用作全局Advisor拒绝条件，且目标证券必须存在于真实持仓；这同时阻断合法的现金组合问题和未持有证券的买入分析。现在账本snapshot可读即可创建Advisor上下文；组合scope投影全部真实持仓与现金，Security scope可用明确六位代码，不要求其已持有。
- 详情页显式传入的证券代码优先保持Security scope；普通组合意图优先于文本内证券代码。证券报价和NAS研究不可用时继续以不可用观察保留原因。没有Ledger写入路径。
- 静态验证：`git diff --check`、架构边界脚本通过；无Swift/Xcode，未编译/执行XCTest；计数保持FCore 39/0、App UI 2/0。
