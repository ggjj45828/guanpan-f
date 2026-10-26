# F NAS 自动交易日历同步增补

日期：2026-10-26

## 运行方式

NAS 后台 `MinuteRuntimeWorker` 增加 `f-official-calendar-sync` worker：服务启动时立即检查一次；之后每月 1 日检查当前年和下一年。每年 11 月起，如果下一年公告仍未发布，会每周重试；当前年仍未受支持或本次源请求失败时也会每周重试。

来源限定为上交所年度休市页与深交所官方公告索引/公告正文。下载链接必须是 HTTPS 且仍在 `szse.cn` 官方域名。只有当页面明确出现目标年份、严格解析出合理的休市日期集合、沪深集合完全一致时，才写入 `/data/official-calendar-v1.json`。记录包括 schemaVersion、休市日期、来源 URL、原始页面 SHA-256 和 fetchedAt。

日历写入先生成临时文件、fsync、读回验证摘要，再原子替换并 fsync 目录。未发布、页面格式变化、来源不一致、下载/解析错误和存储损坏均不会生成 guessed calendar；旧版本保留，未支持年份继续 fail-closed。`/readyz` 输出当前年、已支持年份、同步结果；日历存储损坏或当前年未覆盖时返回503。

## 验证边界

本轮 Python 测试使用官方公告结构的确定性夹具，覆盖双源一致后发布、跨源不一致保留旧版本、目标年未发布不推算、存储摘要损坏拒绝、按月/启动/晚年重试调度、未知年份 readiness 503。所有这些本地测试实际执行；并未从当前受限云端直接抓取 SSE/SZSE 实网，也没有 Docker/NAS 8788 部署证据。首次生产运行必须观察 `/readyz.calendarSync` 的实际结果。

本地 Python 计数：分钟归档43、分钟服务28、Provider/日历16、红利7、旧账本迁移dry-run6，共100/100通过；`py_compile` 和架构边界检查通过。NAS生产网络/官方页面兼容、月度调度、故障重启恢复仍 External Verification Pending。A/B Frozen 未修改。
