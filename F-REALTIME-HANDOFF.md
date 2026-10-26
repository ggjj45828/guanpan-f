# F 实时进度交接

> 给主聊天读取的工作区现场快照。状态以本文生成时的 F 工作树和源码为准；commit 仅供追溯，不定义当前开发状态。每个明显开发阶段完成或用户要求汇报时更新本文，不为更新本文强制提交或停止开发。

更新时间：2026-10-26 16:22（Asia/Shanghai）

## 一、当前工作区状态

- 唯一 Active Development：`C:\Users\Administrator\.codex\.chatgpt-projects\g-p-6ac90ddb9a888191a751dc24eb6a329d\F`
- 当前真实开发状态：功能收口与Apple验证。最新 CI 已在 macOS 编译 F Swift Package、执行 FCore XCTest 119/119通过并成功生成 Xcode 工程；iOS Device App 首次编译发现 App 层 Swift 错误，当前正在逐项修复。
- 最近完成模块：FCore 119项测试在 GitHub Actions 实际执行并全数通过；修复 Ledger 同进程并发写锁与相关测试夹具；Risk Guard 对非有限/溢出金额进行显式检查。统一图表共享渲染首轮接线和成交后 Ledger→Advisor 重判断链仍属于源码已编码、未在 App 运行验证。
- 当前工作树包含 iOS App 首次编译错误的最小修复，以及实时状态文档同步。Actions run `40292039312` 已验证 plist 路径修复、Package编译、FCore XCTest 119/119通过及XcodeGen成功；Device App Build发现 Keychain 字典类型推断、GuardResult公共初始化权限、跨文件视图可见性和Ledger snapshot访问级别错误。当前修复已编码，待复编验证。
- 正在开发：复编 iOS Device App，按实际编译反馈继续收敛；成功后再跑 Simulator Build 与 UI Test。没有新增模拟数据或自动交易。
- 仍未完成：App Build/UI Test/Simulator/真机；图表横屏全屏、均价/前收可靠数据源和真实手势验收；NAS历史分钟与真实服务联调、DeepSeek在线联调。

## 二、功能真实完成度

### 【已完成并验证】

- 当前仓库现场核验：HEAD 与 `main` 一致；本次开始时工作树干净，当前唯一未提交变化是新建本交接文档。验证方式：读取 Git 状态、HEAD 和分支引用。
- NAS 分钟/研究后端：状态文档记录了多个 Python 回归阶段通过，包括最新完整套件记录 93/93，以及之后独立部署包回归 7/7；这是文档中的既往执行记录，本次交接未重跑，不能等同于当前部署验证。
- NAS `/livez` 曾由用户实测可达；这只证明进程/端口存活，不证明 readiness、生产行情和历史覆盖完整。

### 【已编码但未验证】

- 原生 iOS 首页五布局、独立主导航入口、真实 Ledger 只读展示、Portfolio/Security scope、行情请求、NAS 历史分钟日期查询、日K与均线展示。
- Advisor 请求流水线：Ledger 快照/现金持仓、行情和 NAS Evidence、DecisionContext、Risk/AI Guard、DeepSeek JSON 候选、Candidate Plan 展示、Profile/Memory 输入及决策持久化。
- buy/sell Candidate 的用户确认表单、二次输入成交事实、摘要复核、`FConfirmedLedgerWriter` 写入及成交后重新判断。
- Swift 测试源码现有 FCore XCTest 119 个 `test…` 定义、App UI XCTest 2 个定义。最新 GitHub Actions 实际执行 FCore 119 / passed 119 / failed 0；App UI executed=0。测试定义的静态计数来自当前测试源码，执行结果来自 Actions run `40292039312`。
- 统一 renderer 已接入首页行情卡、详情当前分时、NAS历史分钟及日K；日K绘制实际成交量和 MA5/10/20/60/250；账本持仓按 bookCost/units 显示真实单位成本线；同证券 buy/sell Candidate 可绘制候选价线。价格范围将纳入可见蜡烛、均线及有效价格 overlay。
- 统一 renderer 编码了长按/十字、点选、拖动平移和缩放；尚未经过 Apple 编译、Simulator 和可视检查，不能标为可用完成。
- 仓库工作流运行于 `macos-15`，包含 Swift package tests、XcodeGen、iOS device/Simulator build、UI tests和构建产物。最新 run `40292039312`：Swift Package Build、119项XCTest、XcodeGen成功；Device App Build失败，Simulator/UI Test未开始。当前 Windows工作区仍无 `swift`、`xcodebuild`、`xcodegen`；Apple编译和测试证据仅来自该远端macOS run。

### 【正在开发】

- iOS 可运行版本收敛仍未闭环。统一 renderer 首轮已推送；Actions 已触发但失败。先读取失败步骤/日志，再做最小修复。本地没有 Swift/Xcode/XcodeGen；未取得有效 Apple 编译反馈前控制新增 Swift 规模。

### 【尚未完成】

- Swift/Xcode/XcodeGen 编译，FCore XCTest 与 App UI XCTest 实际执行，Simulator 截图/交互、横屏、多屏幕尺寸、真机验证。
- 统一图表的实际编译/运行尚未验证；K柱 OHLC 点选细节和横屏全屏未完成。单位成本与 Candidate 价格已编码为 overlay；均价/前收没有可靠源，当前明确 Unavailable；IOPV 无可靠源，保持 Unavailable。
- 在线 DeepSeek、NAS 真实服务、真实行情长期稳定性及新闻源的端到端实网联调。
- Portfolio Advisor 当前虽已编码范围识别与完整组合请求，但真实 provider/Guard/设备流程未通过运行验证。
- Investor Profile 当前无用户编辑、纠错/撤销 UI；通知与真机推送、跨设备同步/恢复也未验收。

## 三、iOS 当前状态

状态含义：**完成并验证**=相应平台实际验证；**已编码未验证**=源码存在但无平台运行证据；**开发中**=有基础实现，核心目标未闭环；**未开始**=未发现对应实现。

| 功能 | 当前状态 | 现场说明 |
|---|---|---|
| 首页 | 已编码未验证 | SwiftUI 首页与导航存在；真实资产只读。当前无构建/可发现性验证。 |
| 行情 | 已编码未验证 | 腾讯当前分钟/报价和日K请求代码存在；真实长期稳定性、来源/质量展示的设备体验未验证。 |
| 证券详情 | 已编码未验证 | 当前/历史分钟、日K入口及 Advisor 证券 scope 已编码；无设备验证。 |
| 当前分时 | 已编码未验证 | 现由统一 renderer 消费 FChartDataModel；未编译/设备验证。 |
| 历史分时 | 已编码未验证 | NAS 按标的/交易日请求与日期选择接入统一 renderer；实网查询和日期切换无运行证据。 |
| 日K | 已编码未验证 | 真实日K及统一蜡烛图 renderer 存在；未编译。 |
| 成交量 | 已编码未验证 | 统一日K renderer 使用源 volume 绘制量柱；未视觉/数值验证。 |
| MA5/10/20/60/250 | 已编码未验证 | 共享 renderer 从真实日收盘价计算，价格范围也包含可见均线；未编译/验证。 |
| 成本线 | 已编码未验证 | 从真实 Ledger 的 bookCost/units 生成同证券 overlay，读取账本捕获时点作为来源时间；未设备验证。 |
| 均价线 | 未开始 | 无可靠成交均价/VWAP来源，界面明确 Unavailable；不从分钟价格自行伪造。 |
| 前收线 | 未开始 | 当前行情响应未提供可靠前收字段，界面明确 Unavailable。 |
| IOPV | 未开始 | DTO 支持 unavailable/有效值；没有可靠 IOPV 数据源，不能显示伪线。 |
| K柱点击 | 已编码未验证 | 统一renderer有点选日期/索引和日K OHLCV选中摘要；hit-test精度/Simulator待验证。 |
| 十字光标 | 已编码未验证 | 统一renderer长按/按钮进入并拖动定位；未在Simulator验证。 |
| 拖动 | 已编码未验证 | 放大后统一renderer平移时间窗口；未在Simulator验证。 |
| 缩放 | 已编码未验证 | 统一renderer缩放分钟和日K序列；未在Simulator验证。 |
| 横屏全屏 | 开发中 | interaction 状态 DTO 有 landscapeFullscreen；未见完整横屏 renderer/设备验证。 |
| AI标记 | 已编码未验证 | 同证券通过Guard展示的买/卖Candidate可作为虚线价格标记；尚未编译及设备检查。 |
| 真实资产 | 已编码未验证 | 使用真实账本只读快照；Confirmed fill 通过独立用户确认入口更新。未在 Apple 环境编译/执行。 |
| 设置 | 已编码未验证 | 设置页、主题选择、连接状态及 DeepSeek Key Keychain 保存源码存在。 |
| 通知中心 | 未开始 | 推送/通知中心仍在 External Verification Pending，未发现完整功能。 |

## 四、AI 私人投资顾问当前状态

| 环节 | 状态与边界 |
|---|---|
| Portfolio Advisor | 已编码未验证；组合意图先于旁带证券代码判定，组装完整真实持仓、现金及逐证券报价/研究状态。需实机请求验证。 |
| Security Advisor | 已编码未验证；证券详情或明确代码进入指定证券 scope，可分析非持仓标的；数据缺失显式记录。 |
| 输入框/发送/快捷问题 | 已编码未验证；首页 Composer、发送及快捷问题源码存在。 |
| 真实持仓/现金 | 真实 Ledger snapshot 已编码接入；只读投影进入 DecisionContext。 |
| Investor Profile | 存储与时点投影已接 Advisor；没有用户编辑 UI，实际恢复未验。 |
| Decision Memory | 存储与受限投影已接 Advisor；持久化链未运行验证。 |
| 当前行情 | App 请求并组装当前报价观察；实源、时效及故障行为未实机验证。 |
| NAS Research Evidence | App 请求、身份/时间/摘要验证及 DecisionContext 接线已编码；生产 NAS 联调未做。 |
| 历史分钟研究 | Research Evidence 可通过 NAS 历史研究 endpoint 进入 Advisor；IOS/服务端实网端到端未验证。 |
| 新闻 | 未接入可靠新闻源。 |
| DecisionContext | 已编码捕获/校验/持久化；XCTest未执行。 |
| Risk Guard / AI Guard | Pipeline 在显示候选前运行 Guard；源码存在、无 Swift 执行证据。 |
| DeepSeek | Chat Completions provider 与 Keychain Key 接线已编码；真实 API 联调未验证。 |
| Candidate Plan | 作为只读建议输出；不得直接写 Ledger。 |
| 用户确认真实成交 | buy/sell 确认表单要求用户填入实际成交信息；无券商下单能力。未运行验证。 |
| Ledger 更新 | 确认后经唯一 writer 原子写入，检查账户摘要、余额、费用及成本政策；已编码未编译/未执行。 |
| 成交后 AI 重新判断 | 重新加载快照并按原 Portfolio/Security scope 重跑；已编码未验证。 |

链路逐段状态：**真实 Ledger → 当前行情 → NAS Research Evidence → DecisionContext → Risk/AI Guard → DeepSeek → Candidate Plan** 的 App 源码连接已存在，但每段 Apple 编译、真实源、在线服务均未验证；**Candidate Plan → 用户确认事实 → Ledger 更新 → AI 重新判断** 已有显式确认及 writer 路径，但没有 Simulator/真实设备执行证据。因此这是“已编码链路”，不能称“已贯通并可用”。

## 五、NAS 与历史数据

- 实时行情采集：腾讯 provider 与 NAS 归档代码已存在；曾有一次腾讯实网回包写临时 SQLite、16 条/240 预期并标 Partial 的记录。生产长期采集及用户 NAS 当前状态未验证。
- 历史分钟归档/补采：NAS SQLite、provider fallback、精确日期查询、coverage Partial/Missing/Stale 和研究质量门控已有实现；东财历史源曾超时，不能称所有历史日期已覆盖。
- iOS 查询历史分钟：详情页按日期调用 `/api/v1/minute-history`，选择并显示结果/coverage 的代码已存在；实际 iPhone 查询仍待验证。
- 历史分钟进入 AI：App Research client 调用 `/api/v1/minute-history/research` 并校验 envelope 后加入上下文；生产端到端尚未验证。
- 日K：iOS 有腾讯日K请求及 parser，NAS 独立分钟服务不代表日K已有 NAS 归档/质量状态。
- IOPV：无可靠源；Unavailable。不得计算或绘制替代线。
- 跨市场：页面/路由语义存在，但有效跨市场行情研究供给仍待接入或实测。
- 新闻：未接入。
- 缺失/Partial/Stale：数据模型和 NAS 明确状态支持；App 与真实 NAS 上的每种状态显示需实测，不可拿空数据补线。

## 六、当前测试状态

| 测试范围 | defined | executed | passed | failed |
|---|---:|---:|---:|---:|
| FCore XCTest target（当前测试源码逐文件统计） | 119 | 119 | 119 | 0 |
| App UI XCTest | 2 | 0 | 0 | 0 |
| Python/NAS | 不在本次执行 | 0（本交接期间） | 0（本交接期间） | 0（本交接期间） |

- 当前 FCore 定义数为 119；GitHub Actions run `40292039312` 的 Swift package build与XCTest实际结果为 119 executed / 119 passed / 0 failed。该结果仅验证 Package，不代表 App Build/UI Test通过。
- Python/NAS：当前文档最后记录的完整套件是 93/93；随后独立 NAS 部署包记录 7/7。该数字是历史执行记录，本次没有运行 Python/NAS，不能作为当前新代码的 fresh pass，也不可将两个不同阶段简单相加。
- Swift编译：远端 macOS 已实际编译 FCore/FAdvisor/FLedgerWrite；App target首次编译失败，当前正在修复错误。
- 远端 iOS CI：run `40292039312` 中 XCTest通过119/119、XcodeGen通过；Device App Build失败。Simulator Build/UI Test被跳过。
- iOS App Build：未成功。Simulator：未运行。UI Test：executed=0。真机：未验证。本机仍没有 Swift/Xcode/XcodeGen。

## 七、当前最重要的 5 个缺口

1. Apple 工具链缺失，所有 Swift 与 App 接线没有编译/运行保障。
2. 统一图表 renderer 已接线但 Apple workflow 未通过；编译问题、交互和画面仍未验证。
3. DeepSeek、NAS、行情虽有 App 代码，但没有 iPhone 上的真实服务端到端证据。
4. 真实成交闭环代码涉及资产账本，尚未在 XCTest/Simulator/设备上验证边界和可用性。
5. NAS历史分钟、DeepSeek与真实行情的 iPhone 端到端服务验证仍缺失；UI Test、Simulator和真机也未运行。

## 八、下一阶段

当前应优先：**修复当前 App target 的首批 Swift 编译错误 → 重编Device App → 编译通过后跑 Simulator Build/UI Test → Simulator启动和截图检查 → 横屏/不同尺寸/真机 → 再联调真实 NAS/DeepSeek/行情。Package已完成119项测试；下一步仍以App编译收敛为先。**

统一 renderer 是当前最高产品优先级：此工作树已经将分钟/历史分钟/日K入口迁到一个视图，下一步主要是构建反馈和逐步补齐真实来源。Apple 首次编译是最高验证优先级，有环境后暂停新增 Swift 功能先清编译错误。

## 九、方向偏差检查

- 模拟账户/虚拟持仓/虚拟盈亏：当前审阅范围未发现其进入 F 真实资产主路径；资产页以只读真实 Ledger 为源。
- 自动真实交易：未发现券商下单路径；Candidate Plan 需用户明确确认成交后才记录。
- NAS无限测试而iOS停滞：近期代码有 Advisor/Ledger/iOS推进；NAS Python测试已积累较多，接下来不应为增加测试数量推迟 iOS/Apple 验证。
- 重复图表：旧的分钟和日K renderer 已删除，当前分时/历史分钟/日K调用同一个 `FUnifiedSecurityChart`。仍需编译和 UI 视觉验证。
- Portfolio误作单证券：源码路由和 DeepSeek 系统提示要求组合级读取全部持仓现金；需通过执行测试验证。
- 假IOPV/假盘口/假历史：源码设计为Unavailable/显式缺证据；未发现造数路径，真实源需实测。
- 绕过 Risk/AI Guard：现有 Pipeline 将候选交 Guard 后再展示；仍需运行验证。
- A/B旧UI污染：本次没有发现 A/B UI 被复制进入当前 F App；F五布局是当前 App 自身实现。
- 五主题只换色：代码文档描述五种布局分支，但未做 Simulator 视觉验收；不能声称五主题体验已完成。

## 十、机器可读摘要

F_CURRENT_STATUS_BEGIN

当前开发阶段：功能收口、首次App编译修复与验证
当前正在开发：修复Actions run 40292039312发现的App Swift编译错误；修复内容尚未复编
刚刚完成：Apple macOS FCore XCTest 119/119通过；XcodeGen成功生成工程
未提交工作：当前工作树含Keychain字典类型、GuardResult公开初始化器、跨文件路由视图可见性、Ledger快照访问级别修复及状态文档同步
iOS完成度：真实资产双视图、现金/成交流水和Advisor生命周期上下文已编码；尚未通过全套Swift测试和App Build
AI顾问完成度：组合/证券路由、真实账本/行情/NAS证据/Context/Guard/DeepSeek/Candidate及成交后复判均已编码，未端到端验证
统一图表完成度：单一renderer已消费当前分钟/NAS历史分钟/日K；MA5/10/20/60/250、成交量、真实单位成本、Candidate和手势已编码；未编译/视觉验证，均价/前收/IOPV unavailable，横屏未完成
NAS历史数据完成度：NAS精确日期归档及iOS按日查询/研究接线已编码；实机与生产端到端待验证，存在Missing/Partial/Stale
Apple编译验证：FCore/FAdvisor/FLedgerWrite已由macOS编译；XcodeGen已生成工程；iOS Device App Build External Verification Pending（当前失败错误已在工作树修复，待复编）
当前测试：FCore XCTest defined=119/executed=119/passed=119/failed=0（Actions run 40292039312）；App UI defined=2/executed=0/passed=0/failed=0；Python/NAS本阶段未执行
最大缺口：App target编译通过；随后Simulator Build/UI Test/启动与视觉交互验证；NAS/DeepSeek/行情真实端到端
下一步：将当前App编译修复提交到CI并逐轮修正第一根因，成功后立即继续Simulator Build、UI Test和Simulator检查

F_CURRENT_STATUS_END

---

## 实时增量：真实 Ledger 生命周期与现金流水联动（当前工作树）

- 当前模块：修复首次 Apple/Swift 编译暴露的问题；真实 Ledger 生命周期与现金流水修复已编码，统一图表仍是下一产品模块。
- 已编码：Confirmed Fill 持久记录证券名称；清仓仍只从正持仓投影移除，成交历史保留；只读快照新增持仓周期、历史表现与现金流水；资产页新增“当前持仓/已清仓”视图及现金/成交明细；再次买入从零开始建立新周期和成本；AI请求接收历史周期摘要，区分当前成本与历史已实现收益。
- 现金规则：每笔买入现金减少“成交额+手续费”，每笔卖出现金增加“成交额-手续费”；现金转入/转出按已确认 FCashMovement 投影；展示的期末现金来自当前真实 Ledger，并应与流水最后余额一致。App 成交手续费采用 FETFTradeFeePolicy 的每笔 0.10 元。AI Candidate 仍无 Ledger 写权限，只有用户确认实际成交后才写入。
- 测试定义：新增三项 XCTest（清仓→重新建仓→episode/现金/AI上下文；部分卖出仍为Active且现金对账；连续三轮清仓重建及每笔0.10手续费）。FCore 静态定义总数 119；本地执行 0 / 通过 0 / 失败 0。远端 Swift test 已执行但失败，尚未得到通过结果。
- 当前工作树含未提交修改：`Sources/FLedgerWrite/LedgerTransactions.swift` 移除与 FCore 重复的 digest 实现，以及本交接文件；锁实现和显式返回修复已推送至 `main`。
- 尚未验证：旧账本 JSON 解码兼容、修复后的 macOS/Xcode 编译、119项 XCTest、App Build、UI Test、Simulator和真实设备；NAS历史研究数据与 Ledger 的保留仍是不同存储域，本次未变更 NAS。
- 远端验证：run 40286512110、40287179530、40288061070、40288358122 均在 `swift test` 步骤失败，工程生成、iOS Build、UI Test均被跳过。已修 LedgerWrite/FCore imports、DecisionMemoryProjection import、两处 macOS flock 名称冲突和七处显式返回；最新错误是 FCore 与 FLedgerWrite 同时暴露重复的 `ledgerStateDigest()`，已删除写模块重复实现并统一使用 FCore SPI。该修复尚待下一次远端执行。未声称 Apple 构建或测试通过。
- 方向检查：没有新增模拟账户/虚拟资产/自动交易；没有给缺失历史补造证券名（旧流水无名称时显示“名称未记录”）；当前没有发现 F watchlist 删除接口，未增加 watchlist 能力。
- 下一阶段顺序：修完并通过 Swift 包编译与119项 XCTest → 统一图表 → 再执行 Apple 工程生成、App Build、UI Test、Simulator → 真实 NAS/DeepSeek/行情端到端。遵循用户刚重申的顺序，不把失败的 Swift test 误报成 App 已编译。
