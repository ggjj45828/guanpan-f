# F：A/B Frozen Candidate 源码裁决

日期：2026-10-25（Asia/Shanghai）  
性质：只读审计结果；没有改动 A/B。源码存在不等于已运行或通过验收。

## 候选身份与快照可信度

| 候选 | Frozen HEAD | 用于本次源码审阅的快照 | 时间/完整性说明 |
|---|---|---|---|
| A | `eb6fa384a2df8c503eb76d13f68d080c08be31ad` | `candidates/A-LATEST.zip`，SHA-256 `F1E09D0D13D99017537EFB831FC6BA15EF67C3CCE3526173C77AFED508C2B9E8` | A-STATUS 声明 ZIP 对应此 HEAD；源码历史谱系与旧目录未确认等同。远程未验证、NAS未配置。 |
| B | `9ddfe32b787ad9e522a48eb55ff8231227d79599` | 用户指定路径 `work/github-upload/B-LATEST.zip`，F只读副本 `candidates/B-LATEST.zip`，SHA-256 `EEEC94C0433482C66DF0F6CA20ACA3993E2349AC5E39CD1CA92E711F690305B3` | STATUS自报哈希匹配；包内 `B-FROZEN-HEAD.txt` 与本地Git HEAD一致；内嵌 `SHA256SUMS.txt` 142/142文件哈希通过；与此前独立Git归档141个共同文件完全一致。 `CANDIDATE-MANIFEST.json` 的134项中70项文件哈希/长度已过时，不能作为本次有效清单。 |

A-LATEST 与此前 F 捕获副本字节哈希完全相同。此前 F 内部留存过另一份旧 B-LATEST（`29dafce...`，SHA-256 `7679BFF0...`），它已归档为 previous capture，不是本次正式基准。此次 `work/github-upload/B-LATEST.zip` 与指定 HEAD 匹配；源码内容比较结果与此前正确 HEAD 的 Git 归档相同。包内旧 `CANDIDATE-MANIFEST.json` 与当前内容不一致，是 B 检查点附带的清单技术债；独立 SHA256SUMS、HEAD标记与逐文件对比完成了本次来源确认。

A/B 都确认冻结。远端 GitHub 与 NAS 快照均未核实，故这里是本机只读审阅检查点，不代表跨设备灾备完成。

## 模块裁决表

判定含义：胜出代表该 checkpoint 的源码设计/覆盖更适合作为 F 的供体，不代表产品验收通过。证据路径均相对 `review-sources/A/GuanpanNext/` 或正式包解压目录 `review-sources/B-LATEST-9ddfe32/`；该目录与之前 HEAD Git归档141个共同文件逐字节相同。

| 模块 | 裁决 | 源码证据与判断 |
|---|---|---|
| 真实账本 schema / 唯一账户 | 融合 | A `ios/Sources/NextCore.swift`、`NextAppModel.swift` 已有 Decimal 账本、校验与审计；B `guanpan-pro-native/Sources/NextCore.swift` 保持其结构并增加安全校验与关联字段。两者同源 schema v1，不能把这视为两个可直接混用的数据库。F 定义自己的版本化 schema。 |
| 唯一 ID / 重复与溢出防护 | B胜 | B `NextCore.swift` 有重复标识、溢出安全汇总及时间 plausibility 检查；A 的同源模型较基础。B 的新增 XCTest 尚未在此环境执行。 |
| 真实成交流水 | 融合 | 两边都有人工成交、费用/已实现损益和流水历史；B `NextCore.swift` 增加 `candidatePlanID`、`decisionMemoryID` 的可选关联。F 只接受用户确认的真实成交，关联字段适配进入新 schema。 |
| 现金与现金流水 | 平手 | 两边共用 `NextCashMovement`、现金变动和账本路径；未见有证据说明一方在覆盖或执行上胜出。迁移前仍需逐笔现金守恒审计。 |
| 持仓成本 / 对账 | B胜 | B 增加时间、极端份额/累计值校验；A 有 `NextAuditedBook` 前后值审计。F 融合审计事件与 B 的防溢出校验。 |
| 备份、恢复与损坏保护 | B胜 | B `NextAppModel.swift`/`NextAppModelState.swift` 的仓储有损坏文件保护、写前安全副本、整组替换逻辑；A `BackupDocument.swift` 与本地仓储提供基础备份。B 恢复需在 F 重新进行故障注入/回滚验证。 |
| schema 迁移机制 | 两边都有问题，F重构 | 双方账本仍以 schemaVersion 1 为基础；A/B 数据不可直接混用，未见满足 F 迁移要求的完整跨版本 dry-run/可回滚/幂等迁移报告链。 |
| Decision Memory | B胜 | B `NextDecisionMemory.swift` 有当时行情、持仓、研究、新闻、画像、结论、风险、有效期快照；复盘 diff/outcome 纯模型；A 无等价独立模块。B 的测试源码存在，但冻结后变更未完整实测。 |
| Investor Profile | B胜 | B `InvestorProfile.swift`、`InvestorProfileView.swift`，并由 `NextAppModelState.swift` 更新画像；A 无等价独立模型。需 F 审计学习只基于真实反馈、避免偏置。 |
| DecisionContext | B胜 | B `NextAIGuide.swift`、`NextAppModelState.swift` 形成共享的证据/用户上下文与单一手机指导路径；A `DeepSeekMobile.swift` / NAS context 路径存在分歧（A STATUS 已指出 prompt/schema 不一致）。需在 F 收敛唯一 schema。 |
| Risk Guard | B胜 | B `NextCore.swift`/`NextCandidatePlans.swift` 有持仓集中度、目标权重、最坏成交情形与异常报价门槛等；A 主要是规则校验和本机计划逻辑。B 最新边界 XCTest 未执行。 |
| AI Guard / 结构与数值边界 | B胜 | B `NextAIGuide.swift`、`server/ai.py` 明确 schema 校验、模型不得提供订单/数字事实；A `server/ai.py` 有服务端 schema/金额校验但手机与 NAS 链路不一致。AI 建议仍需端到端一致性验收。 |
| AI 最终决策闭环 | B胜 | B 将候选计划、用户真实成交确认、Decision Memory、画像反馈与手机唯一指导连接；见 `NextAppModelState.swift`、`NextCandidatePlans.swift`、`NextDecisionMemory.swift`。闭环链路代码更完整，但当前 Swift 端执行证据不足，故不视为已验收。 |
| T 策略 | 平手 | 两边继承相同策略/计划模块；B 将计划与成交/Risk Guard关联更严。不能仅凭函数存在认定策略实盘适用，F 先采用纯计划工具并重验。 |
| 网格 | 平手 | A `server/grid.py` / `ios/Sources/LocalRules.swift` 与 B `server/grid.py` / `NextCandidatePlans.swift` 均有计划逻辑。B 的计划风险边界较强；F 仍应将网格限定为 AI 可调用的候选工具，不自动下单。 |
| 回本分析 | 平手 | 两边有组合/策略分析基础；没有独立、同输入的真实数据回放结果支持胜负。迁移后重算并核验费用、分红、现金流。 |
| 行情数据来源与校验 | B胜 | B `MarketDataSources.swift`、`MarketDataService.swift` 与 NAS API 有显式来源模式、时效及异常隔离；A `MarketDataService.swift` 具来源标记和行情缓存但证据/降级路径较少。仍需外部行情端到端验证。 |
| 分时 | B胜 | 两边图表可展示分时；B NAS `nas-advisor-compat/server/mobile_research.py` 与 `server/workers.py` 有历史分钟质量、覆盖率与研究归档链路，来源/时间记录更明确。真实长期 NAS 数据仍待积累。 |
| 日 K | B胜 | 两者都有 NAS/手机日 K 下载与缓存；B `NextAppModelState.swift` 的源偏好、失效缓存、离线可用路径更清晰，F 仍需统一来源 freshness 规则。 |
| MA250 | 平手 | A/B `UnifiedChartView.swift` 均有 MA250/长均线绘制；B 标明有效历史不足时降级展示。需用缺失/不足/250+ bars 测试在 F 复验。 |
| IOPV | 平手 | 两边图表及报价模型均可显示 IOPV；B 有来源/ETF 类型校验和同轴图例，A 也有 IOPV 叠加。来源可用性仍依供应商/ETF 实测。 |
| 五档盘口 | 两边都有问题，F重构 | 两边快照均未能证明完整五档盘口数据源、时间戳/量价校验、图表交互和设备验收链闭合。按需求作为独立行情模块重做/补证。 |
| NAS 长期研究 | B胜 | B `nas-advisor-compat/server/mobile_research.py`、`workers.py`、`domain.py` 及 `tests/test_research_only.py` 有分钟档案质量筛选、窗口统计与研究输出。B 报告 68/68；该结果来自 B 的状态和日志记录，本次没有重跑。 |
| 跨市场 | B胜 | B `nas-advisor-compat/server/cross_market.py` 有严格时间可用性/未来数据隔离、历史回放与复现资格门槛；A `GlobalIndices.swift` 以全球指数观察为主，未见相当研究回放深度。研究只能复核风险，不能直接授权交易。 |
| 新闻 | B胜 | B `NextNewsImpact.swift`、`server/app.py`、`NextAppModelState.swift` 提供新闻来源、时间、缓存与持仓关联；A 未见同等完整手机新闻影响模块。标题与链接仍需实源验证。 |
| 同步 / 冲突 | B胜 | B `NextAppModelState.swift` 有账本 fingerprint、NAS revision 对比、冲突时停止覆盖并提示先下载核对；A NAS 同步路径较基础。此模块涉及真实账本，F 重写协议层并独立隔离存储。 |
| 离线与缓存 | B胜 | B 行情/新闻/研究保留最后可信缓存，NAS 失联时说明状态且按来源偏好降级；A 有缓存但系统化状态与来源门槛较少。F 需用断网/过期/时钟异常场景验证。 |
| 通知 | 平手 | 两边都有本地通知与提醒设置；B 增加报价 freshness 和静默/去重边界，A 基础提醒实现较简。平台授权、后台触发时机均无当前设备实测。 |
| 备份恢复（NAS / 跨设备） | 两边都有问题，F重构 | A/B 都报告远程 GitHub 未核实、NAS 源码灾备未验证；产品内账本备份不等于跨设备源码备份。F 要分别定义源码、研究档案、真实账本的备份/恢复。 |
| AI 聊天 | 平手 | 双方有 DeepSeek 移动端连接；B 密钥轮换保护更明确，A 也能生成解释。聊天能力本身不等于最终决策闭环，F 不让 LLM 成为账本或交易权限源。 |
| 导航与交互 | 平手 | 两边共享原生导航主干；B 有场景主题映射与计划/决策记忆入口，A 页面和页面内容更早成熟。缺少可核验的同设备最新截图/交互验收。 |
| 横屏图表 | 平手 | 两边共用统一图表与图层；没有冻结候选同设备 landscape 截图/布局断言支持胜负。F 必须单独验收横屏与窄屏，不继承 UI 绿灯。 |
| 设备适配 / 可访问性 | A胜 | A `DesignSystem.swift` 明确字体族、字号档位及共享组件，较 B 当前视图代码更成熟；B 五主题自动路由功能多，但截图缺失。A优势仅限 token/字号供体，不能代表 iPhone 全面通过。 |
| 测试体系与可验证性 | B胜 | A/B 均有 Swift 与 NAS 测试源、部分 CI 工作流和待验证的设备/外部集成。Frozen 源码与 STATUS 声明可用于理解已有验证边界；具体的 F 测试清单由 F 源码裁决和产品红线独立建立，A/B 状态均不继承。 |
| 可维护性 | 两边都有问题，F重构 | 两者 SwiftUI 主模型/状态协调文件较大，服务与客户端存在兼容/多端 schema 历史路径；B 业务模块更清晰拆分但跨文件耦合增加。F 按 domain/repository/use-case/UI 分层并生成数据契约。 |

## 五套主题：单独裁决

用户已明确选择 B 五种首页布局作为 F 的主要布局设计基线；F 重建首页卡片的独立职责、信息内容和真实路由。源码中 View 存在或可点击不构成通过；禁止不同卡片汇入同一个伪目标页。

B `guanpan-pro-native/Sources/AppThemeCore.swift` 明确列出五个 AppTheme；`ThemeHome.swift` 用一份 `HomeSnapshot` 为五种首页布局供数，分别路由到 EditorialHome、ModernHome、DashboardHome、MagazineHome、PuzzleHome。A `ios/Sources/DesignSystem.swift` 的 GPTheme 是 system/light/dark/comfort 显示外观，不是五个产品布局。A 的 `design/` 与 `previews/` 含界面方向稿，但不能据此证明五主题已实现。

| 主题 | 裁决 | 依据与后续决定 |
|---|---|---|
| 东方编辑室 | B胜 | B 有独立 editorial 布局和场景映射，视觉目标与“彩色东方编辑室”相符；需补真实行情/长标题/小屏截图验收。 |
| 现代卡片 | B胜 | B 有独立 ModernHome 与 token；A 的共享卡片/字号能力可供体迁移。布局复用、动态字体仍需真机复核。 |
| 交易仪表盘 | B胜 | B 将其设为深色 dashboard，数据密度与行情任务匹配；横屏和红绿色辨识度待截图/无障碍验证。 |
| 杂志卡片 | B胜 | B 有独立 MagazineHome、衬线标题和留白方向；需核验 AI 建议摘要不重复、信息层级与阅读效率。 |
| 创意拼图/Bento | B胜 | B 有独立 PuzzleHome 和彩色卡片组织；需核验卡片高度变化、动态类型和窄屏滚动负担。 |

**视觉结论的边界：** 本次源码证明 B 做了五种独立首页布局的实现，不证明五套主题“完美”或视觉验收通过。没有本次冻结提交对应的同设备截图，不对像素质量或 iPhone 实机表现打通过标记。建议 F 从 B 五布局择优借鉴，从 A 取共享 token/字号机制；主题组件保持纯展示，接收同一 `HomeSnapshot`/统一决策模型，逐主题独立迭代。

## 技术底座裁决

**选择：建立干净 F 骨架，不选 A 或 B 整仓作为底座。** A/B 原生核心高度同源，B 的增量对风险、计划、画像、记忆、主题和研究有价值；但账本 schema 仍是版本化数据边界，B 的增强字段不应把 A 真实账本直接升级或与 NAS 数据混写。F Acceptance Matrix 只由 A/B Frozen 源码裁决、F 产品红线和 F 实施范围建立；用户明确说明多发的 B Matrix 不采用。A/B 状态均不继承为 F 通过，迁入的每个模块由 F 自己执行/记录验证。

F 首期不复制整套 A 或 B 工程。先冻结字段定义、来源及不变量，再为迁移器建立只读解析器与差异报告：源文件哈希/版本、现金守恒、持仓单位和成本、成交逐项唯一 ID、费用、分红/现金流水、Decision Memory 和 Investor Profile 单独报告。真正执行迁移时，先完整备份目标账本，dry-run，校验与报告；要求显式用户确认后再原子写入。迁移 ID/源指纹实现幂等，失败保留原账本并支持回滚。候选计划和 AI 输出永不改账；只有用户确认实际成交才可写真实账本。

F NAS 外部端口固定要求 `8788`，A/B 配置保持原样。F 与 A/B 必须用不同服务标识、Compose 项目、存储卷、数据库和 App 数据容器；上线前另行确认 NAS 的 8788 空闲，不能靠覆盖现有服务抢端口。

## F Acceptance / 证据口径

F 验收项按 F 自身范围定义，不采用误发的 B Matrix。逐项状态使用 `defined / executed / passed / failed / external pending` 五类证据字段；没有 F 自身执行记录就不能显示 passed。新增 A 独有且有价值的功能和本裁决表差距项必须加进 F 矩阵。首轮重点为 schema/真实账本与恢复、Decision Memory/Profile/Context/Guards、行情来源质量、研究隔离及 AI 最终闭环。

本审计只读静态源码；没有运行 A/B 测试，也没有把两边已有测试数认领为 F 证据。A Swift 63 项、Python 89 个测试函数为 STATUS 中静态计数，当前执行数分别 0 与仅 1 个 mock 自测通过；B 报告 NAS 研究 68/68、NAS 同步子集 35/35，但冻结 HEAD Swift 新增测试未执行，HTTP 与设备/真实 NAS 联调 External Pending。F 迁移后全部重新验收。

## A/B 退出条件

A/B 维持 Frozen Candidate 与只读源，不继续普通开发。完成 F 核心 schema、备份与安全迁移、核心模块首轮迁移及逐模块归属后，A/B 转只读 Archive；所有后续常规产品工作进入 F。只有重大账本/恢复/安全缺陷才登记例外，不自动同步任何工作树。

## 主题对比维度记录

静态源码能确认布局和 token 的划分，不能确认真实设备视觉质量。因此各主题进入 F 后要用同一组真实持仓/行情/新闻/AI数据与同一屏幕规格进行逐屏截图；该截图属于 F 的新证据。

| 维度 | 源码可见的差异 | 当前裁决与需要的 F 证据 |
|---|---|---|
| 布局与信息层级 | B 五个独立 Home 视图共用 `HomeSnapshot`；A 是现有首页/组合/详情页面体系与 SVG 方向稿。 | B 布局更适合作为五主题布局供体；检查重点摘要、真实持仓、数据新鲜度、风险/动作顺序是否始终明确。 |
| 字体与留白 | B 主题描述包含杂志衬线标题、编辑室晨报留白；A `DesignSystem.swift` 有字族、字号和动态类型 token。 | 组合采用 B 的主题字型方向+A 的可访问字号机制；动态字体截图验证截断和卡片高度。 |
| 卡片形态与密度 | B 有 modern/dashboard/magazine/puzzle 独立首页组件，主题描述覆盖高密度与拼图块；A 提供通用卡片和组合组件。 | B 提供差异化版式，A 的组件复用原则可参考。以密度测试确认不是单纯换色或重复展示相同摘要。 |
| 图表融合和行情阅读 | A/B 都有 UnifiedChartView、MA/IOPV 图层与个股详情；B 有主题 token 与多主题首页，但本次未证实图表按五主题分别重排。 | 图表首轮保持一套可信图表；主题控制颜色、强调和周边布局。验收盘口/分时/日K标签、图例、悬浮详情与窄屏可读。 |
| AI 顾问交互 | B 主题首页将指导 headline、逐只持仓理由、可执行项、计划数纳入同一快照；A 有顾问预览稿和 AI/组合卡片。 | B 的共同快照利于避免切主题时决策数据不一致。检查建议事实/推断/风险/等待条件，且明确手工成交确认入口。 |
| 色彩、一致性与明暗 | B `ThemeKit.swift` 提供主题 palette/token，dashboard 强制深色；A GPTheme 有 system/light/dark/comfort 外观模式与共享 token。 | 分离产品主题和显示模式；审核涨跌色语义、对比度、告警色与深浅背景。截图覆盖 dashboard 与其他主题深浅环境。 |
| 组件复用 | B 五种首页以统一 HomeSnapshot 驱动；A 有 GPTheme 与共享 DesignSystem 组件。 | F 共享数据模型/卡片语义和图表组件，但允许主题独立布局，禁止通过主题复制业务计算。 |
| iPhone / 横屏 | B 有 UI XCTest 源和布局实现，但冻结候选没有本轮可核验截图；A 有 Navigation UI 测试源与适配字号，均无当前真机证据。 | 两边无可直接继承的视觉通过。F 需最窄支持设备、动态字体、横屏图表、空/错误/过期数据与安全区截图。 |

**总视觉取舍：** 以 B 的五个布局和东方编辑室的暖色方向作主题供体，借 A 的设计 token、动态字号及共享组件思路；把精密交易台能力放在数据层级、图表交互与来源/风险标识上；AI 私人顾问以解释、证据、等待条件和用户确认流程呈现。当前不宣布任何主题达到“完美”。

