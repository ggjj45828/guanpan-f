# F 实时进度交接

> 给主聊天读取的工作区现场快照。状态以本文生成时的 F 工作树和源码为准；commit 仅供追溯，不定义当前开发状态。每个明显开发阶段完成或用户要求汇报时更新本文，不为更新本文强制提交或停止开发。

更新时间：2026-10-26 17:27（Asia/Shanghai）

## 一、当前工作区状态

- 唯一 Active Development：`C:\Users\Administrator\.codex\.chatgpt-projects\g-p-6ac90ddb9a888191a751dc24eb6a329d\F`
- 当前真实开发状态：清仓证券详情入口修复已通过Actions run `40298657796` 的Swift编译、FCore 119/119、Device/Simulator Build及App UI 3/3；未签名IPA已上传。历史证券现在显示清仓状态、Episode和各轮盈亏，并可进入行情/历史分钟/Security Advisor；测试未注入持仓，未覆盖实际清仓账户数据的画面表现。
- 最近完成模块：资产页视图切换/现金流水区可发现性测试实际通过；它不创建或注入持仓。上一轮UI测试也通过导航和Advisor状态入口检查。两轮测试均在GitHub macOS Simulator运行，不等同于人工视觉验收或真机验证。
- 当前已验证代码提交 `83318fa` 发布为远端提交 `7244dd8`，提交树相同；工作树在更新本交接/状态文档后有文档改动待提交。
- 正在开发：回到统一图表行为收口，重点检查历史日K/分时曲线与Candidate/成本overlay交互；下一步用CI和图表专项覆盖验证。
- 仍未完成：Simulator截图/人工视觉、交互、横屏/多尺寸验收与真机；图表均价/前收可靠来源和横屏全屏；NAS历史分钟、DeepSeek及行情真实服务端到端联调。

## 二、功能真实完成度

### 【已完成并验证】

- 当前工作树的新变化：已清仓证券详情修复已包含于Actions run `40298657796` 并通过编译/测试；这之后只有状态文档改动。
- Apple自动验证：GitHub Actions run `40298657796` 实际执行FCore 119/119、App UI 3/3；XcodeGen、Device Release Build、Simulator Build、未签名IPA打包与artifact上传均成功。UI覆盖资产视图入口、现金流水、导航与Advisor基础控件，不覆盖真实清仓账本内容或图表手势。
- NAS 分钟/研究后端：状态文档记录了多个 Python 回归阶段通过，包括最新完整套件记录 93/93，以及之后独立部署包回归 7/7；这是文档中的既往执行记录，本次交接未重跑，不能等同于当前部署验证。
- NAS `/livez` 曾由用户实测可达；这只证明进程/端口存活，不证明 readiness、生产行情和历史覆盖完整。

### 【已编码但未验证】

- 原生 iOS 首页五布局、独立主导航入口、真实 Ledger 只读展示、Portfolio/Security scope、行情请求、NAS 历史分钟日期查询、日K与均线展示。已清仓证券详情历史入口代码已编译，但UI未以真实清仓记录专项验收。
- Advisor 请求流水线：Ledger 快照/现金持仓、行情和 NAS Evidence、DecisionContext、Risk/AI Guard、DeepSeek JSON 候选、Candidate Plan 展示、Profile/Memory 输入及决策持久化。
- buy/sell Candidate 的用户确认表单、二次输入成交事实、摘要复核、`FConfirmedLedgerWriter` 写入及成交后重新判断。
- 当前Swift测试源码含FCore XCTest 119项定义、App UI XCTest 3项定义；run `40298657796` 实际执行FCore 119/119、App UI 3/3通过。已清仓详情Swift修改包含在本轮编译中。
- 统一 renderer 已接入首页行情卡、详情当前分时、NAS历史分钟及日K；日K绘制实际成交量和 MA5/10/20/60/250；账本持仓按 bookCost/units 显示真实单位成本线；同证券 buy/sell Candidate 可绘制候选价线。价格范围将纳入可见蜡烛、均线及有效价格 overlay。
- 统一 renderer 编码了长按/十字、点选、拖动平移和缩放；已随 App target 成功编译，但未被 UI XCTest覆盖，也没有人工视觉/手势验收，不能标为可用完成。
- GitHub Actions run `40298657796`：FCore XCTest 119/119通过，XcodeGen、Device Release Build、Simulator Build、App UI XCTest 3/3通过；未签名 IPA 已打包并上传。该run包含已清仓详情修改。CI使用Xcode 16.4/macOS 15；本机仍无Swift/Xcode/XcodeGen。

### 【正在开发】

- iOS 可运行版本已通过远端编译与基础 UI XCTest门槛；下一步应补真实功能链路和图表交互验证。本地没有 Swift/Xcode/XcodeGen，继续通过 GitHub macOS workflow验证。

### 【尚未完成】

- Simulator截图/人工交互、横屏、多屏幕尺寸及真机验证；CI通过仅证明自动化构建和当前两项 UI XCTest。
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
| 当前分时 | 已编码未验证 | 现由统一 renderer 消费 FChartDataModel；App target已CI编译，数据刷新/画面和设备行为未专项验证。 |
| 历史分时 | 已编码未验证 | NAS 按标的/交易日请求与日期选择接入统一 renderer；实网查询和日期切换无运行证据。 |
| 日K | 已编码未验证 | 真实日K及统一蜡烛图 renderer 存在且已随App target编译；实际数据与画面未专项验证。 |
| 成交量 | 已编码未验证 | 统一日K renderer 使用源 volume 绘制量柱；未视觉/数值验证。 |
| MA5/10/20/60/250 | 已编码未验证 | 共享 renderer 从真实日收盘价计算，价格范围也包含可见均线；已编译，数值/视觉仍待专项验证。 |
| 成本线 | 已编码未验证 | 从真实 Ledger 的 bookCost/units 生成同证券 overlay，读取账本捕获时点作为来源时间；未设备验证。 |
| 均价线 | 未开始 | 无可靠成交均价/VWAP来源，界面明确 Unavailable；不从分钟价格自行伪造。 |
| 前收线 | 未开始 | 当前行情响应未提供可靠前收字段，界面明确 Unavailable。 |
| IOPV | 未开始 | DTO 支持 unavailable/有效值；没有可靠 IOPV 数据源，不能显示伪线。 |
| K柱点击 | 已编码未验证 | 统一renderer有点选日期/索引和日K OHLCV选中摘要；hit-test精度/Simulator待验证。 |
| 十字光标 | 已编码未验证 | 统一renderer长按/按钮进入并拖动定位；未在Simulator验证。 |
| 拖动 | 已编码未验证 | 放大后统一renderer平移时间窗口；未在Simulator验证。 |
| 缩放 | 已编码未验证 | 统一renderer缩放分钟和日K序列；未在Simulator验证。 |
| 横屏全屏 | 开发中 | interaction 状态 DTO 有 landscapeFullscreen；未见完整横屏 renderer/设备验证。 |
| AI标记 | 已编码未验证 | 同证券通过Guard展示的买/卖Candidate可作为虚线价格标记；已编译，图表联动/设备检查未做。 |
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
| DecisionContext | 已编码捕获/校验/持久化；FCore测试集119/119已通过，在线服务端端到端未验。 |
| Risk Guard / AI Guard | Pipeline 在显示候选前运行 Guard；源码存在、无 Swift 执行证据。 |
| DeepSeek | Chat Completions provider 与 Keychain Key 接线已编码；真实 API 联调未验证。 |
| Candidate Plan | 作为只读建议输出；不得直接写 Ledger。 |
| 用户确认真实成交 | buy/sell 确认表单要求用户填入实际成交信息；无券商下单能力。未运行验证。 |
| Ledger 更新 | 确认后经唯一 writer 原子写入，检查账户摘要、余额、费用及成本政策；FCore 119项已通过，App真实成交流程/设备持久化仍未端到端验收。 |
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
| App UI XCTest | 3 | 3 | 3 | 0 |
| Python/NAS | 不在本次执行 | 0（本交接期间） | 0（本交接期间） | 0（本交接期间） |

- 当前 FCore 定义数为 119；GitHub Actions run `40298657796` 的 Swift package build与XCTest实际结果为 119 executed / 119 passed / 0 failed。
- Python/NAS：当前文档最后记录的完整套件是 93/93；随后独立 NAS 部署包记录 7/7。该数字是历史执行记录，本次没有运行 Python/NAS，不能作为当前新代码的 fresh pass，也不可将两个不同阶段简单相加。
- Swift编译：远端 macOS 已编译 FCore/FAdvisor/FLedgerWrite 与 GuanpanF App target。
- 远端 iOS CI：run `40298657796` 中 FCore XCTest 119/119、XcodeGen/Device Build/Simulator Build和App UI XCTest 3/3全部通过，已包含当前已清仓详情Swift改动。
- iOS App Build：当前代码的Device Release与Simulator Debug、3项UI Test均成功，未签名IPA已上传。真机和人工视觉验证仍未完成。本机仍没有 Swift/Xcode/XcodeGen。

## 七、当前最重要的 5 个缺口

1. 自动化已能编译和跑基础UI测试，但还缺 Simulator截图/人工交互、横屏、多尺寸及真机验收。
2. 统一图表 renderer 虽已编译，真实图表数据/叠加/手势视觉行为尚未通过专门 UI 验收。
3. DeepSeek、NAS、行情虽有 App 代码，但没有 iPhone 上的真实服务端到端证据。
4. FCore账本边界测试已通过，但 App 中真实成交确认、持久化及成交后AI重判尚未做完整UI/设备闭环。
5. NAS历史分钟历史日期查询及AI研究、DeepSeek与真实行情仍缺iPhone端到端验证；UI自动化通过不代表真实服务通过。

## 八、下一阶段

当前应优先：**统一图表真实数据/叠加和交互验收 → 补充对应UI覆盖与Simulator视觉检查 → 横屏/多尺寸与真机 → 再联调真实NAS/DeepSeek/行情。Ledger Episode/现金核心测试和已清仓详情编译已通过；真实确认成交App闭环仍待专项验证。**

统一 renderer 是当前最高产品优先级：此工作树已经将分钟/历史分钟/日K入口迁到一个视图，下一步主要是构建反馈和逐步补齐真实来源。Apple CI现已建立稳定编译与测试门槛；后续每次Swift修改继续经Actions验证，优先做已有图表和Ledger产品行为。

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

当前开发阶段：真实资产生命周期修复已编译通过，转入统一图表行为收口
当前正在开发：统一图表分时/历史分时/日K共用渲染器的产品行为与视觉验收
刚刚完成：Actions run 40298657796验证FCore XCTest 119/119、App UI XCTest 3/3、Device/Simulator Build与IPA artifact全部成功
未提交工作：本交接、状态、矩阵与审计文档更新；Swift代码已提交并通过run 40298657796
iOS完成度：当前FCore/App target已在macOS CI编译，FCore119/119与App UI3/3通过；已清仓详情编译通过但未做真实清仓数据的UI验收
AI顾问完成度：组合/证券路由、真实账本/行情/NAS证据/Context/Guard/DeepSeek/Candidate及成交后复判均已编码，未端到端验证
统一图表完成度：单一renderer已消费当前分钟/NAS历史分钟/日K且App target已编译；MA5/10/20/60/250、成交量、真实单位成本、Candidate和手势已编码但未视觉/交互专项验证；均价/前收/IOPV unavailable，横屏未完成
NAS历史数据完成度：NAS精确日期归档及iOS按日查询/研究接线已编码；实机与生产端到端待验证，存在Missing/Partial/Stale
Apple编译验证：FCore/App target已由macOS成功编译；Device/Simulator Build与App UI XCTest通过；未签名IPA artifact已上传
当前测试：FCore XCTest defined=119/executed=119/passed=119/failed=0；App UI defined=3/executed=3/passed=3/failed=0（Actions run 40298657796）；Python/NAS本阶段未执行
最大缺口：统一图表视觉/手势与横屏专项验收；真实成交App路径端到端；NAS历史分钟/DeepSeek/行情真实服务联调
下一步：检查统一图表当前分钟/日K与成本/Candidate overlay显示和手势，补专项UI覆盖，再做Simulator横屏/尺寸验收

F_CURRENT_STATUS_END

---

## 历史增量记录：真实 Ledger 生命周期与现金流水联动（上阶段快照）

> 以下为较早阶段的增量记录，保留当时执行结果供审计；其中“未执行/待编译”等描述不代表当前状态。当前状态以上方更新时间和机器可读摘要为准。

- 当前模块：修复首次 Apple/Swift 编译暴露的问题；真实 Ledger 生命周期与现金流水修复已编码，统一图表仍是下一产品模块。
- 已编码：Confirmed Fill 持久记录证券名称；清仓仍只从正持仓投影移除，成交历史保留；只读快照新增持仓周期、历史表现与现金流水；资产页新增“当前持仓/已清仓”视图及现金/成交明细；再次买入从零开始建立新周期和成本；AI请求接收历史周期摘要，区分当前成本与历史已实现收益。
- 现金规则：每笔买入现金减少“成交额+手续费”，每笔卖出现金增加“成交额-手续费”；现金转入/转出按已确认 FCashMovement 投影；展示的期末现金来自当前真实 Ledger，并应与流水最后余额一致。App 成交手续费采用 FETFTradeFeePolicy 的每笔 0.10 元。AI Candidate 仍无 Ledger 写权限，只有用户确认实际成交后才写入。
- 测试定义：新增三项 XCTest（清仓→重新建仓→episode/现金/AI上下文；部分卖出仍为Active且现金对账；连续三轮清仓重建及每笔0.10手续费）。FCore 静态定义总数 119；本地执行 0 / 通过 0 / 失败 0。远端 Swift test 已执行但失败，尚未得到通过结果。
- 当前工作树含未提交修改：`Sources/FLedgerWrite/LedgerTransactions.swift` 移除与 FCore 重复的 digest 实现，以及本交接文件；锁实现和显式返回修复已推送至 `main`。
- 尚未验证：旧账本 JSON 解码兼容、修复后的 macOS/Xcode 编译、119项 XCTest、App Build、UI Test、Simulator和真实设备；NAS历史研究数据与 Ledger 的保留仍是不同存储域，本次未变更 NAS。
- 远端验证：run 40286512110、40287179530、40288061070、40288358122 均在 `swift test` 步骤失败，工程生成、iOS Build、UI Test均被跳过。已修 LedgerWrite/FCore imports、DecisionMemoryProjection import、两处 macOS flock 名称冲突和七处显式返回；最新错误是 FCore 与 FLedgerWrite 同时暴露重复的 `ledgerStateDigest()`，已删除写模块重复实现并统一使用 FCore SPI。该修复尚待下一次远端执行。未声称 Apple 构建或测试通过。
- 方向检查：没有新增模拟账户/虚拟资产/自动交易；没有给缺失历史补造证券名（旧流水无名称时显示“名称未记录”）；当前没有发现 F watchlist 删除接口，未增加 watchlist 能力。
- 下一阶段顺序：修完并通过 Swift 包编译与119项 XCTest → 统一图表 → 再执行 Apple 工程生成、App Build、UI Test、Simulator → 真实 NAS/DeepSeek/行情端到端。遵循用户刚重申的顺序，不把失败的 Swift test 误报成 App 已编译。
