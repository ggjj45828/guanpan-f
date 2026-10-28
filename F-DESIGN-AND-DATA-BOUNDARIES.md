# F 版设计与数据边界

## 账本

F 使用独立的账本存储和 schema。NAS 的行情、新闻、统计和研究结果均是外部证据，不是账本主数据。任何账本迁移都必须由用户明确发起，展示来源、目标、现金/持仓/成交/审计对账结果并在确认后写入；失败时保留原数据并可恢复。A/B 账本不会自动同步或合并。

## 决策（现行架构）

F 维护单一 DecisionContext。快通道由 iPhone 本地确定性 Quant、Risk Guard 和 Realtime Trigger 处理新鲜行情与 Candidate 状态，不等待 DeepSeek；慢通道由 DeepSeek 对真实组合/证券、现金/成本/当日成交、可靠行情、日线/近期分钟、Quant 状态及可选市场背景做高层判断。DeepSeek不作逐tick判断，Quant/Advisor/Trigger均无Ledger写权限。Candidate不等同订单；只有用户确认券商真实成交才能通过 `FConfirmedLedgerWriter` 写账。盈亏、Episode成本、券商成本和T贡献均从真实Ledger事实确定性派生。

## NAS（可选增强，不是核心依赖）

NAS保留为可选同步、历史归档、备份与扩展研究服务。NAS关机、未配置、不可达或穿透失败不能使本地Ledger、行情、Quant、Guard或Advisor基础流程不可用。Research Evidence有合格数据时可加入慢通道DecisionContext；没有时明确Unavailable，不能生成假证据。NAS API 与手机连接继续使用端口 `8788`、专属 Compose 项目 `guanpan-advisor-f`、专属 volume `guanpan_advisor_f_data` 和数据库 `guanpan-advisor-f.sqlite3`。NAS 只保存 F 自己的数据；源码备份、研究档案和真实投资账本使用不同目录/数据卷。端口被占用时停止部署，不覆盖已有容器来抢占。更完整的双速决策/Quant/Trigger契约见 `F-LOCAL-QUANT-ARCHITECTURE.md`。

## 视觉

F 的五个产品主题方向为：东方编辑室、现代卡片、交易仪表盘、杂志卡片、创意拼图。每个主题要有自己的布局节奏、信息层级、卡片组织和图表强调方式；单纯换色不计为独立主题。以同一组真实样式数据检查 iPhone 窄屏、动态字体、深浅环境、空/错误/陈旧数据和横屏图表。
