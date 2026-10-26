# F 云端开发状态

## 当前工作树快照（2026-10-26 17:27 Asia/Shanghai）

- F 当前阶段：已清仓证券详情修复编译验证通过，转入统一图表产品行为收口。Actions run `40298657796` 完成 FCore XCTest 119/119、XcodeGen、iOS Device Release Build、Simulator Build、App UI XCTest 3/3；未签名IPA已打包并上传。
- Actions run `40298657796` 已执行FCore XCTest 119/119和App UI XCTest 3/3，Device/Simulator Build及IPA artifact均成功；清仓证券详情/持仓周期展示Swift修改包含在本次编译中。UI用例未注入真实清仓数据，因而没有对历史Episode画面做专项验收。Simulator人工视觉/手势、横屏/多尺寸及真机仍待验证。
- 本机没有 Swift/Xcode/XcodeGen；后续 Apple 验证继续通过已有 GitHub macOS workflow进行。历史开发记录保留作追溯，不能覆盖本节实时状态。

## 当前基线

- 当前 CLEAN checkpoint 由 `main` 与 `F-CHECKPOINT` 同一提交标识；完整可恢复 Git 历史另存为 `F-CHECKPOINT.bundle`。本工作区从 F-LATEST 源码包导入，原上游 Git 历史未包含在该包中。
- A Frozen HEAD：`eb6fa384a2df8c503eb76d13f68d080c08be31ad`；B Frozen HEAD：`9ddfe32b787ad9e522a48eb55ff8231227d79599`。本阶段未修改或合并 A/B。
- F 是唯一 Active Development。验收矩阵覆盖 F-01 至 F-40 及 EXT-1 至 EXT-5。B版145项作为需求来源已逐项映射至 [F-B-145-TRACEABILITY.md](F-B-145-TRACEABILITY.md)，不继承B状态；F-34跟踪编号连续性、逐项处置和独立验收。

## 当前实现（代码存在不等于验收通过）

- Ledger 写权限隔离、用户成交确认、原子持久化、备份/恢复、只读决策上下文、Memory/Profile 持久化和三通道同步规则已编码；Swift/XCTest 尚未运行。只读已实现盈亏按确认卖出流水派生，不修改真实账本。
- NAS 分钟链路具备补采、实时归档、完整度评估、精确日期查询、备份恢复、质量门控和 no-lookahead 研究证据。新增红利多因子证据整理器，并接入版本化 NAS Research Evidence/DecisionContext；红利证据按来源、观测时间、抓取时间和质量过滤，不沿用分钟研究25日门槛；4%仅作参考，无交易结论。生产指标源、交易日历准确性及 NAS 部署仍待外部验证。
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

- 用户从 NAS 端口访问得到 `{"status":"alive","service":"f-minute-archive"}`，确认 8788 的 `/livez` 可达且服务进程存活。用户另一次提供 `{"error":"unauthorized"}`，未附路径或请求头；若访问根路径或未携带有效 `X-Api-Key` 请求 `/readyz`/业务API，这是认证边界的预期响应。生产 readiness、token 匹配、归档/日历/provider 状态仍待核验，不能据 `/livez` 宣称数据服务就绪。
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
