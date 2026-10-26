# F Master Acceptance Matrix

本矩阵由 F 产品红线、A/B Frozen 源码裁决、F 自身实施范围及 B 版 Master Acceptance Matrix 的 145 项需求共同形成。B 145 项需求追踪见 [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)：保留原编号和需求来源，逐项标注 F 处理结论；不继承 B 实现状态或测试证据。A/B 的测试结果都不算 F 通过。每项先标为 `defined`；只有 F 自身执行并保留证据后才能更新为 `executed`、`passed` 或 `failed`。外部条件另标 `external pending`。

## 当前 F 验证快照（2026-10-26）

FCore XCTest：121 defined / 121 executed / 121 passed / 0 failed；两项图表价格范围回归已在Actions run `40303339340`通过。App UI XCTest：3 defined / 3 executed / 3 passed / 0 failed，但该结果对应本轮新UI代码改动之前的版本。XcodeGen、Device/Simulator Build和未签名IPA成功。Simulator截图附件及证券代码查询导航刚加入，待下一轮CI验证；空账本未注入虚构持仓，真实Episode详情仍未做数据级验收。

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
| F-16 | AI 最终建议串联真实持仓、行情、新闻、研究和风险证据 | defined | 原生App接入DeepSeek候选provider、NAS质量门控Evidence、实时分钟报价、只读Ledger快照、DecisionContext与Risk/AI Guard；组合意图优先纳入全持仓/现金/逐证券行情与研究，即使提及单只证券仍保持组合范围；无合格同标的NAS研究时阻断资产变更候选；新闻仍显式不可用；Swift/iOS/在线服务未验证 |
| F-17 | T、网格、回本仅为 AI 可调用分析工具，不自动交易 | defined | NAS 历史分析函数和 Advisor 研究工具调用边界已编码；NAS Provider编排已绑定响应身份/范围/时点/质量；回本候选仅允许绑定真实持仓并以分析文本表达，拒绝下单字段；网格要求同标的合格gridSpacingReplay；做T因盘口/VWAP/双边费用上下文未齐而fail-closed；真实持仓策略适配未完成；FCore 119项全量已在Actions执行通过，但策略和真实服务适配仍待专项验收 |
| F-18 | 行情、批量行情、分时、日 K、MA250、IOPV、盘口标注来源/新鲜度 | defined | Tencent实时分钟行情与NAS历史分钟已接入；新增Tencent未复权日K解析/蜡烛/MA5/10/20/60/250；FCore统一分时/日K、Unavailable/Partial/Stale、IOPV及价格叠加DTO已定义并约束状态一致性。统一`FChartOverlayModel`仅将有来源的成本/均价/前收/IOPV/Candidate叠加层纳入同一可视纵轴，Unavailable不生成伪线；FUnifiedSecurityChart已由当前/历史分钟和日K页面共用，并随App Device/Simulator Build编译（run 40298657796）；实线包含真实持仓成本和Candidate，MA/量柱编码完成；均价/前收/IOPV因无可靠源保持Unavailable，真实图表视觉/手势仍待专项验收 |
| F-19 | NAS 历史研究、跨市场和新闻与真实账本隔离 | defined | NAS 分钟归档/补采/研究及红利多因子证据和版本化 DecisionContext 接入已编码；实源、跨市场、新闻和生产部署待外部验证 |
| F-20 | 同步、离线冲突、通知与恢复状态可见且不丢账 | defined | 三通道策略已编码；传输、离线队列、通知 UI 和恢复体验未实现；FCore 119项全量已执行通过，但这不覆盖缺失的产品功能 |
| F-21 | AI 聊天、导航、图表、横屏和设备布局可用 | defined | 原生五Tab与独立NavigationStack、真实账本/行情、AI顾问输入和结果页已接线；当前/历史分钟和日K已复用共享SwiftUI renderer。App UI XCTest 3/3通过（run 40298657796；覆盖导航、Advisor主要控件和资产页基础结构）；图表功能/视觉、横屏和设备布局验收仍未完成 |
| F-22 | 五个独立主题的 token、页面一致性、可读性和设备截图验收 | defined | 五主题首页布局分支和基础颜色已编码；设计token完整性、主题差异质量、一致性与设备截图验收未完成；未继承 A/B 主题结论为通过 |
| F-23 | 单一权威实现、模块边界、依赖和故障可诊断 | defined | FCore/FAdvisor/FLedgerWrite 依赖隔离；架构边界脚本当前通过；Actions run 40298657796 已完成 FCore 与 App Device/Simulator Build；后续修改仍需重跑 |
| F-24 | 核心测试按模块执行，记录 defined/executed/passed/failed | defined | 账本 XCTest 已定义；FCore XCTest：119 executed / 119 passed / 0 failed（Actions run 40298657796）；各产品验收项仍按实际覆盖范围判定 |
| F-25 | NAS历史分钟补采、实时归档、完整度、长期留存、查询、诊断和研究证据/no-lookahead | defined | 归档/补采/查询/研究链已编码；累计量差分来源必须保留累计量且差值匹配分钟量；归档启动/完整性/备份恢复校验、no-clobber备份、版本化队列和严格HTTP输入/授权边界已覆盖；交易日历、日期、时区、幂等、Partial门控、指定日期Missing/Partial逐日诊断和范围隔离有回归；无范围时列出已评估coverage日期并明确可能低估；分钟服务27/27、归档43/43、红利研究7/7、只读迁移dry-run6/6、Provider/Calendar/runtime10/10，合计93/93通过；腾讯当日接口已实网取样并写入F归档；东财历史接口本云端超时、生产交易日历与NAS部署仍待外部验证 |
| F-26 | 指数卡区分行情时间、获取时间、来源、新鲜度和交易时段；闭市保留最后有效时间 | defined | Quote元数据与最大有效期校验已编码；首页有独立市场入口但当前行情明确 unavailable；现金状态文案区分读取中/未建立/不可读取/已读取；FCore整体119项CI通过，真实源/闭市行为与原生显示仍待验收 |
| F-27 | 首页显著提供组合问答输入、发送、快捷问题和真实持仓上下文；详情入口绑定证券 | defined | 首页/Advisor页输入、发送和快捷问题已接入；默认聚焦首个真实持仓，详情绑定标的；发送时重读账本并构建请求。只读持仓会发送至用户配置的DeepSeek；实际可发现性待Simulator/真机验收 |
| F-28 | 五主题统一普通文字/页面颜色；仅保留业务语义图表色 | defined | App已有主题选择器、五布局分支和基础颜色；统一设计token、业务图表色及视觉质量/设备验收未完成 |
| F-29 | 分时/日K统一支持点击、长按十字光标、拖动、缩放、横屏与选中详情 | defined | hit-testing坐标验证与复用已编码；当前/历史分钟与日K已接入共享 renderer。基础图表模型回归包含于FCore 119/119通过；renderer内实际手势、横屏全屏及显示效果仍待Simulator专项/真机验收 |
| F-30 | 红利研究采用多因素证据；4%仅为自动模式参考，显式高级设置才启用自定义最低值 | defined | NAS多因素证据整理器及版本化Research Evidence输出已编码；历史观测重复时按质量/抓取时点确定性去重并拒绝质量分越界，红利研究Python 7/7通过；真实基本面来源、Advisor/UI消费和高级自定义设置仍未接入，不能据此给出真实资产买卖结论 |
| F-31 | 首次使用者可发现AI输入、历史分时、K线选择、数据时间/来源、AI依据和主操作 | defined | AI输入/快捷问题/真实账本状态和持仓证券详情入口已编码；历史分时、K线选择、行情来源新鲜度及依据展示仍待原生可发现性验收；Simulator/真机评估待外部验证 |
| F-32 | B五种布局为F主要布局设计基线；首页每卡职责、信息和目标路由唯一；不同语义入口必须有独立页面 | defined | 五种首页布局保留；市场观察、跨市场脉搏、AI指导、真实资产各有独立route/page；每个主Tab有独立NavigationStack。源码检查通过，实际可发现性仍待设备验证 | |
| F-33 | NAS Research Evidence版本化只读进入DecisionContext；只传紧凑统计/来源/时点，不传原始分钟/计划；过期、低质量、样本不足、未来时间fail-closed | defined | 紧凑证据与日期/质量校验已编码；有合格日必须有来源，零合格日可空来源；超大计数转换 fail-closed；evidenceId覆盖信任元数据并由iOS重算；FCore 119项整体CI通过，生产跨端服务联调和业务验收仍未完成 |
| F-34 | B版145项需求逐项溯源、F需求处置与独立验收 | defined | [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)：保留 B-001…B-145 编号与验收输入，逐项给出 F 需求处置、供体裁决和 F 独立验收状态；B 状态不继承。编号连续性已静态核对，F 实现仍按各项验收。 |
| F-35 | 行情按证券刷新并更新共享图表快照，显示来源/行情时间/获取时间 | defined | Swift数据绑定已编码；实时源、设备图表响应待验证 |
| F-36 | 未知年份交易日历 fail-closed，日历按正式来源审核 | defined | 仅当前配置年度启用；其他年份和实机行为待验收 |
| F-37 | NAS按月核验官方交易日历，双源一致后原子发布 | defined | Worker/存储已编码；目标NAS运行和实网兼容待验证 |
| F-38 | 原生主导航、只读真实资产、显著AI输入、设置和NAS安全配置 | defined | 五Tab/独立导航栈、AI上下文状态、只读账本页、主题设置、NAS URL与Keychain token、只读`/readyz`检查已编码；本轮3项UI XCTest实际执行并通过（run 40298657796）；覆盖主导航、Advisor控件和资产视图/现金流水入口，不代表真实清仓Episode内容、成交闭环或图表交互已验收 |
| F-39 | NAS部署包在大小写敏感的Compose项目名校验下可解析 | defined | Compose固定`name: guanpan-f`；部署包显式包含Python package markers；修复entrypoint CRLF shebang，并在Dockerfile构建时校验`#!/bin/sh`；部署包测试7/7与shell语法检查通过。NAS挂载卷属主初始化后降权至UID 10001；Docker/NAS目标环境仍External Verification Pending |
| F-40 | 真实持仓 Advisor：组合级 + 证券级 Ledger→行情/研究→DecisionContext→Risk/AI Guard→Candidate Plan | defined | App源码现按入口/问题区分组合与证券范围；真实账本空仓时组合Advisor仍可分析现金；明确六位代码/证券入口可分析尚未持有的证券；组合问题纳入全部真实持仓/现金、逐证券报价和 NAS Evidence/缺失状态。单笔买入/卖出 Candidate 现可由用户填写实际成交并显式确认后调用唯一 Ledger writer，成功后失效旧 Candidate、重读账本并重跑相同作用域 Advisor；做T/网格/回本不自动写入。ETF单笔0.10元及做T双边0.20元估费由iOS校验。基础做T不强制盘口，但要求连续时段可信新鲜行情及同标的合格vwapBreak研究。证券详情页接入NAS按日历史分钟；分钟折线支持长按/按钮十字光标、拖动选点/平移、提示和缩放。当前代码已通过Actions run 40298657796的XcodeGen、iOS Device/Simulator Build及3项UI XCTest；FCore 119/119通过。统一图表及历史详情已编码并编译，但交互/画面、清仓真实账本数据、成交后AI闭环和NAS/DeepSeek/行情生产联调仍待专项验收；均价/前收/IOPV无可靠源保持Unavailable，横屏仍未完成 |
| EXT-1 | GitHub DNS / 远端可达性和跨机同步验证 | external pending | 私有 `ggjj45828/guanpan-f` 已通过GitHub API发布F源码；Actions run `40298657796` 成功。跨机克隆/恢复及持续同步仍待验证 |
| EXT-2 | NAS 端口 8788 与部署/恢复链验证 | external pending | 用户确认 `/livez` 返回 `status=alive`；`/readyz`、token、Provider/Calendar readiness、历史数据和备份恢复仍待验证 |
| EXT-3 | macOS、Swift/Xcode 构建和模拟器测试 | external pending | GitHub macOS Actions run `40298657796` 用Xcode 16.4完成Swift编译、Device/Simulator Build、FCore 119/119及App UI 3/3；人工截图/交互、横屏/多尺寸和真机仍待验证 |
| EXT-4 | iPhone 真机、横屏和推送通知验收 | external pending | 需设备环境 |
| EXT-5 | 实际行情、新闻与在线 AI 服务接入验证 | external pending | 外部服务配置/联调待做 |

当前矩阵为40项 `defined`、5项 `external pending`。FCore XCTest defined=119 / executed=119 / passed=119 / failed=0；App UI XCTest defined=3 / executed=3 / passed=3 / failed=0（run `40298657796`）。已清仓详情修改编译通过，但无真实清仓账本数据的UI专项验收。这不代表所有产品验收项已通过；Python结果和静态检查也不代表真机、生产NAS或在线服务通过。不得继承A/B状态。



> 以下为追加的阶段性历史记录；其中旧测试计数反映当时工作树，当前数字以上方“当前 F 验证快照”为准。

部署阶段补充（2026-10-26）：F-25 的分钟服务已有显式运行壳与持久化部署配置；runner/鉴权/readiness 的本地 HTTP smoke 通过，Compose YAML结构检查通过，现有 Python 套件83/83通过。Docker镜像、真实 provider/calendar 插件、NAS 8788部署及生产备份恢复未验证，均保持 External Verification Pending，不能标为部署通过。


Provider/Calendar接入补充（2026-10-26）：F默认runtime现配置腾讯当前交易日分钟采集、东财精确日期历史分钟请求和沪深2026交易日历，启动时排队最多120个受支持交易日，实时采集与补采分线程运行。腾讯实网数据已在本环境经日历校验并写临时SQLite，盘中16/240点标Partial；东财历史请求本云端超时，不能算历史覆盖通过。非2026年日历fail-closed。Docker镜像、NAS部署及生产回补覆盖仍External Verification Pending。

NAS容器启动故障修复（2026-10-26）：用户日志显示`No module named 'nas.fminute'`。部署ZIP构建器此前只复制`nas/fminute/*.py`，未打包根`nas/__init__.py`；现补齐显式package marker，并在Docker镜像构建阶段执行真实模块import自检。部署包套件6/6通过、解压包import smoke通过、相关`py_compile`通过。当前环境无Docker，未能验证镜像构建；修复包需在目标NAS重新部署，生产启动仍External Verification Pending。FCore XCTest defined=39 / executed=0 / passed=0 / failed=0；App UI XCTest defined=2 / executed=0 / passed=0 / failed=0。

NAS SQLite 数据目录权限修复（2026-10-26）：用户日志显示`sqlite3.OperationalError: unable to open database file`。原因是NAS bind mount覆盖镜像中已chown的`/data`，UID 10001无法写入宿主目录。entrypoint以root准备`/data`属主和权限、修复属主不匹配的顶层既有数据项，再通过`util-linux`的`setpriv`降权到UID 10001启动Python；未更改存储路径或数据库内容。部署包测试7/7、解压模块导入smoke、shell语法及py_compile通过。无Docker/NAS，构建和生产重启仍External Verification Pending。


NAS 8788 / GitHub F repo 状态补充（2026-10-26）：用户实测 `/livez` 返回 alive，因此端口存活检查通过；后续 `unauthorized` 未注明路径/请求头，根路径匿名访问或受保护路由缺失/错误token都会返回401；生产就绪性未验证。私有 `ggjj45828/guanpan-f` 已创建但为空；用户已授权上传，推送因环境无GitHub认证失败，尚无F工作流执行结果。`guanpan-pro-native` Actions成功运行对应B源，不计作F验证。
