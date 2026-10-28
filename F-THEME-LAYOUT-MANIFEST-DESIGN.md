# F Theme / Layout Manifest 设计

状态（2026-10-28）：**Manifest注册表和十种首页布局已进入Swift源码；共享Home Role Renderer、基础语义Token、Theme Gallery选择行已编码。尚未经过Apple编译/XCTest，也没有Simulator截图或人工对比。**

主题实现保持增量，不改变Ledger与手续费回算、NAS历史分钟进入iOS/Research Evidence、真实DeepSeek闭环等既定高优先级。现阶段只编码manifest/共享renderer/首页信息结构，不复制业务逻辑，不增加图表renderer；Apple CI仍优先于继续扩展主题细节。

## 目标与边界

主题负责“同一业务信息如何组织和呈现”，不负责计算业务结果。所有主题共享：

`FAccountBook / Ledger projections → market data → NAS Research Evidence → FDecisionContext → Advisor / Guards → Candidate Plan`

主题只选择`ThemeManifest + LayoutManifest + shared page renderer`。因此主题切换不得修改账户、成交、费用、Episode、成本口径、行情来源、Research Evidence质量、Advisor scope、Guards或Candidate状态。

首页卡片继续使用`FHomeCardRole`与已登记的唯一目标route契约。市场观察、跨市场脉搏、AI今日指导、真实资产、风险/异常在各布局中可改变位置、面积和视觉表达，但同一role仍只有一个语义和唯一目标页面。

专业二级页面可以改变导航栏/背景/面板密度等视觉表达，但证券详情、分钟/日K继续使用唯一`FUnifiedSecurityChart`、唯一ChartData/Overlay/Interaction模型和同一ViewModel数据源。

## Manifest分层

### ThemeManifest：视觉语言

每个theme manifest只声明呈现token和兼容范围：

- 稳定`themeID`、显示名、说明、版本、是否可选；
- `layoutFamily`；
- 字体角色与字号层级（标题、数字、正文、辅助标签、等宽金融数字）；
- spacing scale、内容密度和安全区规则；
- surface/card treatment（平面、分割线、卡片、玻璃、无卡片等）；
- navigation treatment；
- AI、market、asset presentation treatment；
- chart container treatment（只影响外围容器，不换renderer/数据模型）；
- 语义色映射（涨跌、警告、风险、成功、不可用等，遵守系统/用户无障碍对比要求）；
- motion level与Reduce Motion降级；
- light、dark、eye-care外观兼容策略；
- dynamic type、VoiceOver、对比度和最小触控尺寸约束。

### LayoutManifest：信息架构

Layout manifest以稳定role描述页面结构，不持有服务、Ledger或Advisor：

- `layoutID`、family与适用页面（首页、导航、AI区域、市场摘要、资产摘要）；
- role到区域/排序/占比/优先级的映射；
- 不同尺寸的断点、列数、堆叠与滚动策略；
- 异常、风险升高、正常状态下的允许重排规则；
- role唯一性、目标route和无证据状态的保留位置；
- 拥挤时的折叠/展开行为，不得删除风险、数据质量、缺失标识或AI保护状态。

注册表由`themeID → ThemeManifest → layoutID → LayoutManifest`解析。新主题只需注册manifest与纯展示renderer/组合策略；不能要求修改Ledger、FAdvisor、DecisionContext、Advisor服务或Research Evidence代码。未知/损坏的已保存ID回退到默认主题，并保留可诊断状态。

主题不能任意组合成未验收的混搭；用户选一个完整theme profile。系统外观变化可由同一theme的light/dark/eye-care token变体承接。

## 10套方向清单

前五项是当前F已经有的首页布局分支/既有规划，不代表全App已经完成；后五项是本次新纳入的方向。每项最终都要有独立信息编排证据，而不是只改色彩或圆角。

| ID | 方向 | 结构差异要求 | 预计Layout family |
|---|---|---|---|
| `editorial` | 东方编辑室 | 编辑式标题、章节顺序、组合与AI叙事层级 | `editorial` |
| `modern` | 现代卡片 | 网格卡片、并列市场/跨市/顾问摘要 | `card-grid` |
| `dashboard` | 交易仪表盘 | 现金与风险指标优先，紧凑专业数据区 | `terminal-dashboard` |
| `magazine` | 杂志卡片 | 日期/专题头版、纵向故事与研究章节 | `magazine` |
| `bento` | 创意拼图 | 固定大小混排模块，清楚区分信息权重 | `static-bento` |
| `ink-modern` | 东方墨韵 | 大留白、墨色层级、朱砂业务强调、现代金融编辑排版，不做古风装饰 | `ink-editorial` |
| `minimal-terminal` | 极简终端 | 弱化卡片、细分割、等宽数字、紧凑但清晰的专业数据层级 | `minimal-terminal` |
| `fluid-glass` | 流体玻璃 | 现代半透明/悬浮空间层次，AI顾问为主视觉，同时保证行情数字对比度 | `spatial-glass` |
| `data-starmap` | 数据星图 | 首页核心资产/AI为中心，市场、风险、跨市场、研究为外围节点；二级页保持高信息密度 | `radial-map` |
| `adaptive-bento` | 动态Bento | 风险/异常时相关模块获得大面积优先；普通状态突出资产与长期研究 | `adaptive-bento` |

`bento`与`adaptive-bento`必须在尺寸/排列规则上真实不同；后者可以依照共享、确定性的Risk/quality状态重排信息，但不能改动Advisor判断，也不能用动效或位置暗示未发生的风险。

## 渲染与扩展约束

当前`FHomeTheme`保留稳定主题ID并映射到`FThemeLayoutRegistry`；注册表为十种主题提供Theme/Layout Manifest，`FHomeRoleRenderer`复用资产、市场、跨市场和顾问角色。新增第11套需要新增主题ID/manifest和纯展示布局family，不复制Ledger、Advisor或行情逻辑。当前Swift未经Apple编译，不能把源码存在视为架构验证通过。

共享renderer按role读取已提供的presentation model：

- 市场摘要读行情/时间/来源/新鲜度；
- 跨市场脉搏读跨市场Evidence及其缺失/质量字段；
- AI今日指导读组合Advisor结果；
- 真实资产只读真实Ledger投影；
- 风险/异常展示现有Guard、质量和服务状态。

renderer不得自行取行情、重算账本、推断成本、生成Research Evidence或绕过Guards。空、Partial、Stale、Unavailable状态在所有布局中均须可见，不得为填满构图制造数据。

## 验收门槛

1. 同一真实业务snapshot在10主题之间切换，Ledger digest、行情观测、Evidence、DecisionContext、Advisor结果和route契约保持不变。
2. 10套主题分别交付首页、市场/资产/AI主视图和证券详情/统一图表截图；截图使用同一组真实验收数据，或明确标注为仅供布局测试的非产品预览fixture，不将fixture当成真实账户/行情验收。
3. 视觉比较必须证明模块顺序、面积/网格/空间组织、信息层级至少存在结构性差异；像素/颜色不同不构成通过。
4. 检查小屏、长证券名、大字模式、深色/护眼模式、可读对比、VoiceOver、触控尺寸和滚动/导航。
5. 每套布局核验五个关键入口的唯一目标route；AI组合问题继续Portfolio scope，指定证券问题才Security scope。
6. 图表数据范围、交互、质量状态和overlay语义在10主题下完全一致；所有页面复用`FUnifiedSecurityChart`。
7. 只有Simulator实际运行、截图对比和人工检查完成后，才可标记主题视觉验收；源码存在或CI UI test通过不等同于主题验收。

## 当前验收状态

- 五种既有主题：首页布局分支已编码；现已接入共享角色renderer及Manifest；Simulator结构/人工验收未完成。
- 五种新增主题：五种首页结构与主题Manifest已编码；专业子页面的主题化、编译与截图人工验收未完成。
- Theme/Layout Manifest注册表及Theme Gallery选择行：已编码，尚未Apple编译或Simulator运行。
- 主题业务隔离、10主题Simulator截图对比、动态类型/无障碍/深色护眼验收：未完成。
- 深色/护眼主题Token、10主题截图对比、动态类型/无障碍与主题切换后的真实导航状态保持仍未完成。主题实现不得挤占Ledger、Apple CI、NAS历史分钟→iOS及AI真实闭环验证。
