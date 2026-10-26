# F Decision Memory 分段归档设计

## 目标与当前限制

当前 `FDecisionMemoryStore` 将全部记录放在一个带摘要的 JSON envelope 中。`recentProjection` 将交给 Advisor 的对象限制为最多5条，但底层仍须读取、解码并校验整个 envelope。因此它限制了请求体，不解决长期记录增长时的整档 I/O 和解码成本。

本设计仅涉及 Advisor 私有 Decision Memory。不得改变真实 Ledger、成交确认语义或 Profile/Context 存储格式。当前 JSON v1 保留为可迁移来源和独立备份格式，不能静默删除。

## 选定方案：不可变记录 + 月份索引 + 原子代际指针

- 每条 Memory 保存为不可变记录文件，文件名由 accountID 和 memory UUID 确定；写入后校验内容摘要。
- 每个 account/month 使用不可变、带版本号的索引快照，记录该月每条 Memory 的 UUID、decidedAt、instrumentCode、文件名和摘要。
- 不可变 generation manifest 引用各账户月份索引的文件名及摘要。
- 唯一提交点是小型 `CURRENT` 指针文件。新记录、索引、manifest 均先完成原子写入、同步和读回校验，最后原子替换 `CURRENT`。
- 崩溃发生在指针替换之前时，旧 generation 仍是权威状态；未引用的新文件视为孤儿，可诊断后清理。指针替换后，新 generation 必须完整可读。
- `CURRENT` 至少保留上一代恢复指针；清理旧 generation 前先验证当前 generation 与备份。

## 查询

1. 校验 `CURRENT` 和 generation manifest 摘要。
2. 按 accountID、证券范围、as-of 与月份倒序读取索引；不扫描其他账户或未来月份。
3. 从最近索引收集最多5条匹配 UUID。
4. 只读取并校验这些记录文件，过滤 `decidedAt > asOf` 和 `outcome.recordedAt > asOf`。
5. 严格检查 Profile revision 与候选引用属于这次 Advisor 请求。

索引提供近期读取所需字段，不复制建议全文；完整正文只在选中记录时加载。归档保留完整历史，索引应可从记录重建。

## v1 迁移与回滚

- Dry-run 只读 v1 envelope，校验 format/schema、archivedAt 与 content digest；迁移专用解码不跳过 envelope 校验，只把 payload 不变式交给报告器，以便列出重复 UUID、非规范排序和无效记录。上述问题 fail-closed 并带稳定拒绝原因。输出记录总数、账户/月分布、ID、源摘要和字节估算，不写入目标目录。字节估算明确只计 JSON 记录数组，不代表文件系统实际占用。
- 正式迁移先写入全新 staging generation；每个不可变记录与月索引都读回核验，最后校验 manifest 后原子切换 `CURRENT`。
- 若 staging 中断，当前指针不变；重跑通过 source digest 与 deterministic file IDs 幂等续做。
- 迁移后对新旧表示做全量 ID 集合、DecisionMemory 内容摘要、outcome/confirmedFill 引用、账户隔离和排序对账。迁移报告与旧 v1 envelope 保留。
- 迁移不改 A/B，不触碰 Ledger；不能把没有 v1 源的空数据伪装成“已迁移”。

## 备份与恢复

- 备份是带摘要清单的只读 generation 包，包含 CURRENT、manifest、所有被引用的索引和记录；备份写 staging 目录，逐项校验后再发布。
- 恢复先完整校验备份 generation，再写入独立 staging generation；只有 `expectedPriorDigest` 匹配当前 CURRENT digest 时才原子切换指针。
- 失败、摘要冲突、缺失记录、损坏记录或跨账户引用必须保持当前 generation 不变。
- 保留恢复前 generation 作为可诊断 rollback point；显式恢复需要报告 source digest、current digest、restored digest 与记录数。

## 未来验收

必须新增且在 Swift/Xcode 可用后执行：legacy dry-run无写入、迁移幂等、内容/ID完全对账、不同账户隔离、按月/as-of/证券范围查询、只加载限定记录、孤儿文件不影响当前指针、每个写入阶段注入崩溃、指针切换原子性、备份恢复 digest 冲突保护、损坏 fail-closed、旧 JSON 请求兼容、真实 Ledger digest 始终不变。

当前状态：只读 dry-run、分段generation写入、月份索引查询、CURRENT提交、legacy回退和分段generation独立备份/全量校验/expected prior generation恢复已编码；相关XCTest仅定义、未执行。v1仍是权威写入源，可用于重建缓存；旧分段备份会因源摘要不匹配而拒绝恢复。同目录Memory写入已增加POSIX flock协调，尚未执行多进程竞争验证；六处写入故障注入已在Boundary XCTest中定义但未执行。Swift/Xcode缺失不改变此状态。
