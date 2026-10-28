## 当前状态裁决（2026-10-28；工作树细节见后续补记）

- 当前本地`main`已提交本轮修改、工作树干净、尚未push；已fetch确认远端main仍为`b099c9d0d9c703f56540b6fa4d3d30cfbb3ddefe`。Run `40710039609`已取消且未执行步骤，不能作为当前树CI证据。
- F产品体验仍不如B；所有已编码非回归项在当前HEAD CI和人工视觉/交互前不得关闭。品牌名/图标、Home布局、主题切换、NAS可选状态、图表显隐均以最新安装包和设备实测为准。
- NAS为可选服务；无NAS时当前Advisor基础上下文不得被阻断。完整本地Quant接线仍未完成，资产变化Candidate保持fail-closed。
# F-B-NON-REGRESSION

## 当前架构/非回归增补（2026-10-28）

- 新决策不得退化真实账本隔离：Shadow事件、Candidate状态、Quant输出和建议结果均不能改现金、份额、成本、P&L、Fill或T Contribution；只有用户确认真实成交后唯一Writer可写账。
- 新增AI页成绩单不会移除原有Advisor/组合和证券入口；当前只是基础汇总接线，尚未完成屏幕实测，也未证明完整的评分体验优于B。
- NAS降级为可选同步/归档/备份；NAS缺席不能阻断Ledger、实时行情、Quant、Guard或DeepSeek基础Advisor。下方旧NAS必经描述为Superseded。
- 本轮新增11个FCore测试定义；FCore当前共164项定义（全仓167项含3项UI测试），当前HEAD尚未运行。Run 59已取消，没有运行步骤，不得作为编译或非回归通过证据。

## 历史工作树补记（2026-10-28；以开头更新为准）

- 已通过GitHub Desktop Fetch确认远端`main=9e575693de5400a154eafb16fcb08c003f9ce49e`；本地`main=e500fc84f6dd8acf93cc32305aefcff28e700f4e` ahead 1 / behind 8，当前源码尚未合并/提交/编译。
- 本轮主题语义颜色改动仅为已编码未验证。B中成熟图表显隐、图表操作、账本语义等非回归项仍需当前源码CI和Simulator/真机实测后才能关闭；F整体产品体验仍不如B。

## 历史源树状态（2026-10-28）

- 当前HEAD dirty、未编译；不得把下方旧CI、旧commit或过往截图沿用为当前通过证据。
- NRG-04图层语义色本轮开始接入主题tokens，属于已编码未编译；当前真实体验仍被用户评为明显不如B，需Simulator/手机实际操作后才能关闭。
- NRG-25等品牌/图标条目中的旧“已改/待打包”描述只记录历史尝试；最终是否显示“观盘max”及F独立图标必须以当前CI产物与iPhone桌面实测为准。当前工作树无此轮安装验证证据。
- 完整未完成项以 `F-MASTER-ACCEPTANCE-MATRIX.md` 开头当前盘点为准；本表后续状态只作逐项追溯，冲突时更新对应行。

目的：记录 B 中值得保留的实际产品能力，防止 F 重构期间让用户能看到、能使用的功能退化。此清单只确认 B 源码供体存在，不自动继承 B 的行为正确性或 F 的 PASS。

状态定义：
- `待实现`：F 当前 UI/产品体验缺失或明显弱于 B。
- `部分`：F 有代码入口，但体验/完整链路尚未验证。
- `已编码未验证`：源码已实现，当前 HEAD 编译、Simulator/实机未证实。
- `已验证`：必须填写当前 SHA、实际执行平台和截图/测试证据后才能使用。
- `不采用`：已由产品原则排除，不作为非回归要求。

| ID | B 行为/体验 | F 目标行为（仍使用 F 权威业务模型） | F 源码位置/当前状态 | 编译/Simulator/截图 | 是否允许退化 |
|---|---|---|---|---|---|
| NRG-01 | 行情页显示指数条、代码搜索、全部/自选/持仓筛选与证券列表 | F 提供可发现的市场/自选列表、搜索筛选、来源/新鲜度，不将非持仓误作资产 | `F/GuanpanFApp/Sources/HomeExperience.swift` `MarketOverview`；持仓+输入代码已有，完整自选列表弱；待补核 | 未验证；无截图 | 否 |
| NRG-02 | 列表行可进入详情、刷新/分析和快捷操作 | F保留单证券 route 与安全成交确认；不增加自动下单 | `HomeExperience.swift`、`FAdvisorVerticalSlice.swift`；部分 | 当前 dirty 未编译/未截图 | 否 |
| NRG-03 | 详情顶部有代码、价格、涨跌、时间和来源/状态 | F同一屏明确显示报价新鲜度、来源和错误/缓存状态 | `HomeExperience.swift` `HomeDestination`；已编码，布局待验 | 未验证 | 否 |
| NRG-04 | 统一图表支持分时/日K、显隐价格/IOPV/成本/均线/量能/成交点 | F单一 `FUnifiedSecurityChart`；图层可选隐藏且偏好保留，纵轴仅纳入当前可见有效曲线 | `FUnifiedSecurityChart.swift`、`Sources/FCore/ChartDataModel.swift`、`Tests/FCoreTests/MarketChartAcceptanceTests.swift`；当前图层修复 dirty | 未编译；测试新定义、未执行；无 Simulator 对比 | 否 |
| NRG-05 | 图表选点、十字线、缩放/平移、历史日期与全屏入口 | F 保留一致操作并额外显示真实 Partial/Missing；专业页手势稳定 | `FUnifiedSecurityChart.swift`、`HomeExperience.swift`；部分/待手势验收 | 未人工验证 | 否 |
| NRG-06 | MA250 不足时说明数据不足，不画假线 | F使用真实日K，长度不足时隐藏/标明不可用 | `FUnifiedSecurityChart.swift`；需当前 CI 与数据实测 | 未验证 | 否 |
| NRG-07 | 资产总值/现金/持仓/当日盈亏的摘要与明细 | F保留明确的现金、估值完整度、Security Daily P&L、Current Episode P&L及生命周期语义 | `HomeExperience.swift` `RealAssetsOverview`；现金/持仓/历史周期已有，首页摘要/多盈亏层级不足 | 未验证 | 否 |
| NRG-08 | 持仓明细可打开证券详情，查看成本与流水 | F使用 Episode Economic Cost、Broker Display Cost、费用审计与真实 fills，不混成单成本 | `HomeExperience.swift`、`Sources/FLedger/*`；底层语义优先，UI需分层改善 | 未验证/未截图 | 否 |
| NRG-09 | 现金校准/现金流水入口 | F保留只追加的实际差额记录与原因，不回写历史 | `HomeExperience.swift` `FCashAdjustmentSheet`、Ledger writer；已编码，未本机验证 | 未验证 | 否 |
| NRG-10 | 成交流水、审计记录、确认/可撤销处理 | F只能经确认真实成交写账本，审计/修正保留原 fill | `HomeExperience.swift`、`Sources/FLedger`；核心边界以当前 CI为准 | 当前树待 CI | 否 |
| NRG-11 | AI 入口从证券详情携带指定代码，结论拆成证据/风险/等待条件 | F明确区分 Portfolio/Security scope；展示事实、推断、风险、等待和失效条件，缺数据明确说明 | `HomeExperience.swift` Advisor Composer/AdvisorOverview；有输入、快捷问题、scope说明，产品展示待验 | 未验证 | 否 |
| NRG-12 | 主场景导航保留各自 navigation state | F保留首页/行情/顾问/真实资产/设置独立栈和当前实体状态 | `GuanpanFApp.swift` `FHomeRoot`；源码存在、未实机验证 | 未验证 | 否 |
| NRG-13 | 全局搜索跨证券/持仓/决策/流水 | F提供只读跨域搜索并路由到真实 F 数据对象 | 当前五 Tab 未见等价全局入口；待实现 | 未验证 | 否 |
| NRG-14 | 独立通知中心/价格与状态提醒 | F提醒真实行情/NAS/风险/Candidate 状态，不通知虚拟成交 | 当前主导航未见入口；待实现/待验证产品边界 | 未实现 | 否 |
| NRG-15 | 设置支持字号/字体/配色/浅深护眼 | F至少提供正确 Dynamic Type 与三种清晰外观兼容；主题差异不限色板 | `HomeExperience.swift` Settings 当前只有主题选择；gallery说明深色/护眼/动态字体待验证 | 未验证/部分缺失 | 否 |
| NRG-16 | NAS/API、DeepSeek Key、安全状态和测试入口 | F显示可操作连接状态、来源/最后成功与具体错误；Key安全保存；不宣称 readyz=数据链完成 | `HomeExperience.swift` `SettingsOverview`、`FNASConnection.swift`；有readyz/Key字段，用户反馈NAS连不上 | 端到端未通过 | 否 |
| NRG-17 | 备份与恢复、审计版本及冲突确认 | F做 Ledger schema 对应的校验备份/恢复，冲突停止覆盖 | 当前 Settings 未见成熟备份恢复入口；待实现 | 未实现 | 否 |
| NRG-18 | 独立收息/派息历史及证券上下文 | F只接可核实场内 ETF 分派，明确预测值/来源，不把估计当现金 | 当前 F UI未见等价独立入口；需 F-145 产品/真实源复核 | 未完成 | 否 |
| NRG-19 | 主题可切换且字号/配色贯穿组件 | F先交付三套布局差异明显主题，共用业务模型与图表 | F `ThemeLayoutManifest.swift` / `HomeExperience.swift` 十套代码已存在，但当前用户评体验混乱，视觉未验；冻结扩主题 | 当前源未经编译/截图 | 不允许以换色冒充完成 |
| NRG-20 | 收息/网格/数字孪生/策略模拟入口 | 按明确产品方向排除模拟账户、虚拟资金/盈亏、复杂数字孪生和自动真实交易 | 不迁移为 F 页面；做T/网格可作为 Advisor 只读研究能力 | 不适用 | **不采用** |
| NRG-21 | 五档盘口、IOPV、前收、均价等行情辅助层 | 仅在供应源真实、质量合格时展示；否则说明 unavailable | F `FUnifiedSecurityChart.swift` 应以 overlay quality 决定可见性 | 需 provider 实测；不得造线 | 不允许假数据回归 |
| NRG-22 | 错误/空/加载状态可见，用户可刷新/重试 | 所有页面对 Ledger/行情/NAS/AI明确显示加载、可用、Partial、Stale、Missing、Unavailable | 各 F 页面具备部分状态，但部分首页/详情需人工核验 | 当前树未验 | 否 |
| NRG-23 | 全屏图表和返回/恢复 | F进入全屏/横屏后保留证券、周期、日期、缩放和选中点 | F需求/已有部分状态；横屏及状态恢复未实机验 | External Pending | 否 |
| NRG-24 | 首页总览链接分别去市场、资产、AI、研究 | F首页角色路由必须分别到真实对应页面，卡片不共用无关目的地 | `HomeLayout` role renderer/routes；静态源码存在、整体布局反馈失败 | 未验证 | 否 |
| NRG-25 | 安装后的产品名称和独立App图标 | 桌面名称显示“观盘max”；使用F自己的无字母图标，并确认图标资源实际进入安装包 | AppIcon 1024×1024资源已在 `Assets.xcassets/AppIcon.appiconset` 且XcodeGen配置引用；原显示名仍为“观盘 F”。现已改为“观盘max”，CI新增Info.plist/AppIcon/Assets.car打包断言 | 新改动未CI；旧IPA不能证明名称/图标 | 否 |

## 使用规则

- 本表来自可用 B 参考源码，不是 B 冻结版本所有权/版本证明。若用户手机里的 B 与 `GuanpanNext-work` 不同，应补真实 B build、截图或精确源码后增补。
- 代码存在、测试定义、旧 CI PASS、手绘 SVG 均不能填当前 F 的“已验证”。
- 用户已明确排除的模拟/场外/自动交易方向不恢复，也不当作 F 落后。
- 用户报告 F iPhone Air 布局和图表失败：NRG-01/04/05/07/19必须以真实 Simulator/真机截图和操作复测关闭；当前状态不能标PASS。

### 2026-10-28 当前HEAD证据补充

- 首页真实资产摘要改动随 `6cde9d5e5964b8f67e4cfe54d0a9f918a1deba87` 通过Apple CI：本轮CI 140 FCore测试、3个App UI测试实际通过，设备/Simulator构建成功。
- 这是构建/自动化证据，不改变NRG视觉、可发现性及图表交互的未验状态。仍需Simulator截图与手势、iPhone Air实机核验后才能关闭。

### 2026-10-28 设置页可发现性

- 十套主题的大预览不得全部纵向铺开；主题选择应紧凑、完整预览默认收起。当前工作树已编码为横向主题栏+折叠预览，需Apple CI和iPhone Air截图确认可用性。
- NAS连接状态必须区分未填地址、正在测试、服务可用和具体失败；“历史数据同步未接入”不能展示成已连接。当前设置页已编码此区分和保存地址只读检查，待设备真实连接验证。

| B-NR 图表信息层级与输入键盘 | B的图表专业坐标/成交量/时间轴体验不得在F退化；AI及设置输入必须可明确收键盘 | F统一renderer开始补价格轴、午休压缩时间轴、日K成交量子图与选中OHLCV；Composer/Settings加键盘工具栏及提交后收起 | 已编码未编译；未执行CI/Simulator/真机；不得标记通过 | 当前统一图表仍是F权威数据实现，B仅作呈现参考 |

| B-NR 当前验证门与NAS连接 | `FUnifiedSecurityChart`图表重排与多处键盘收起；NAS客户端20秒时限/错误分类 | HEAD `ecb220d` 已推送，Apple CI run `40675520793`正在执行：FCore步骤/XcodeGen已成功、Device Build进行中，UI/Simulator待执行 | 只表示CI中途状态，不得标记最终通过；NAS连接仍需手机安装新包实测 |

| NRG-26 首页AI组合指导和资产层级 | 打开首页即可看到Portfolio级AI判断、真实现金/持仓、新鲜持仓行情及研究/市场入口；今日盈亏无可靠基准时明确Unavailable；Guard阻止结果不展示成交易建议；市场/研究入口分别路由 | `GuanpanFApp/Sources/HomeExperience.swift` 新增三个布局共用的 `HomeAdvisorLead`、`HomePortfolioLead`、`HomeMarketResearchStrip`；东方编辑/墨韵、Dashboard终端、流体玻璃改变信息编排但复用唯一model与业务数据 | Run 56/57 FCore各140/140、XcodeGen通过；Device Build因源码传输损坏失败，UI XCTest未执行。Run 58 `40693877430` queued，源码已小分段恢复并从GitHub回读核对一致；无新截图/人工视觉/真机证据 | 不得以旧Run 55结果、UI XCTest或主题配色冒充验证；B vs F仍判F体验不如B |

### 2026-10-28 App名称/图标与NAS确认门

- `project.yml`声明显示名`观盘max`、AppIcon资产名`AppIcon`；图标素材为无字母方案。run `40675520793` 的IPA步骤因验证脚本查询错误的plist路径失败，需修正后重跑CI，并检查实际IPA/安装结果。
- NAS客户端仍未完成实机HTTPS穿透复测。健康检查使用只读`/readyz`，未请求额外token；不得把客户端错误提示/CI通过视为NAS连接通过。

### AppIcon打包检查的二次修正

- CI run `40677313197`证明本项目构建的Info.plist既无根`CFBundleIconName`，也无预期嵌套键。工作树改为验证Asset Catalog源清单/PNG及编译后`Assets.car`里的AppIcon rendition，等待Apple CI证明。
