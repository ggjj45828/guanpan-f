# F 原生 iOS App 集成阶段增补

日期：2026-10-26

## 结构审阅与本阶段接线

| 边界 | 当前路径/职责 | 本阶段情况 |
|---|---|---|
| App 入口 | `GuanpanFApp/Sources/GuanpanFApp.swift` | 单一 `@main`，共享 `FHomeModel` |
| Navigation | SwiftUI `TabView` + 五个独立 `NavigationStack` | 首页、行情、AI顾问、真实资产、设置五个一级入口；卡片路由继续使用独立 `FHomeRoute` |
| AppState | `FHomeModel` | 只管理本机账本只读快照、当前日分钟快照、用户问题与可见请求状态 |
| FCore | `Sources/FCore` | 账本、市场与图表领域模型；App 通过FCore只读合同读取 |
| Ledger | `FLedgerWrite` / `FAccountBookStore.readLedgerSnapshot` | 当前App只读取账本快照；页面未调用成交写入 API，Candidate Plan/Advisor视图没有写账入口 |
| Market Data | App内严格解析的腾讯当前日分钟请求 | 仅当前日分钟；来源时间/获取时间分开，真实源和用户设备效果仍待验证 |
| NAS Client | `GuanpanFApp/Sources/FNASConnection.swift` | 地址/32字节token校验、Keychain this-device-only存储、只读`GET /readyz`连通性检查已编码；历史指定日期查询和coverage状态未接入 |
| AI Client / DecisionContext | 尚未实现 | 输入可见；发送动作只提示未发送，当前不把输入/持仓发送到在线服务 |
| Risk Guard / AI Guard | FAdvisor/FCore中现有模型和流程 | 尚未接入App的在线咨询请求链；不得声称页面已得到Guard裁定 |
| Settings | `SettingsOverview` | NAS地址写入AppStorage；token输入为SecureField并由Keychain保存；可测试`/readyz`；连接状态/行情日历诊断如实显示；AI凭证尚未接入 |
| Local Persistence | App Support下的 `FAccountBookStore`、Keychain、AppStorage | App只读账户快照；NAS token使用`AfterFirstUnlockThisDeviceOnly`；主题/NAS地址保存在AppStorage；AI/Memory/Profile本机展示链未完成 |

## 已编码

- 一级导航目标为首页、行情、AI私人投资顾问、真实资产、设置。每个Tab使用独立导航栈，市场观察、跨市场脉搏、AI指导和真实资产为不同route和页面。
- 首页仍保留五种主题布局分支；主题选择移至设置页，不新增普通文字/背景自由色盘。
- AI顾问页提供显著输入、发送、快捷问题、真实组合状态以及行情/NAS/新闻/在线AI的上下文可用状态；未配置服务时不发送、不显示占位建议。
- 真实资产页只读显示账本状态、现金、持仓份额和成本；明确说明当前没有成交登记入口。
- Settings页提供NAS地址与SecureField token输入；token保存到本机Keychain，连接测试仅请求NAS `/readyz`，不会发送账本；显示五主题、NAS/AI/同步/新闻连接状态、交易日历和行情请求状态。股息使用“自动/AI综合判断”说明，4%仅作为研究参考。
- 定义两项XCUITest：验证五个主页面导航标题和AI输入/未配置状态的可发现性；CI scheme纳入UI test target。

## 未完成/外部验收

- Swift/Xcode/XcodeGen当前不可用；App和XCUITest均未编译、未执行。FCore XCTest保持 defined=39 / executed=0 / passed=0 / failed=0；App UI XCTest defined=2 / executed=0 / passed=0 / failed=0。
- NAS地址/API token需由用户在App内设置并安全写入Keychain；目前设置页仅展示未配置状态。NAS客户端、证书/网络错误、历史分时查询均未接线。
- DecisionContext装配、在线AI调用、Guard输出、候选计划呈现以及确认成交流程仍未接入App。
- 行情目前依真实持仓代码拉取腾讯当前日分钟；尚无指数卡、完整报价、日K/MA250/IOPV/盘口、历史分钟控件和统一手势图表。
- Simulator、页面截图、VoiceOver、横屏、不同屏幕尺寸、iPhone真机和UI实际可发现性均为External Verification Pending。

本阶段只建立可审核的原生主应用导航与页面接线，不代表App整体完成。
