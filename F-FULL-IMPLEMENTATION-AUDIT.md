# F 全盘未完成功能审计

> 实时更新（2026-10-26）：GitHub Actions run `40294624613` 已通过 Swift Package/FCore XCTest 119/119、XcodeGen、iOS Device及Simulator Build、当时定义的App UI XCTest 2/2；未签名IPA已打包上传。当前工作树新增第3项资产视图/现金流水UI测试，尚待CI执行。人工视觉/真机和真实服务联调仍待验证；下方旧记录只用于追溯。

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
| F-16 最终AI指导 | 只读请求/上下文组装已编码 | 在线模型接入、密钥管理、真实行情/新闻联合决策、错误降级和端到端输出守卫未完成 |
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
