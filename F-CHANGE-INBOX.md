# F 版 A/B 变更接收登记

A、B 已冻结为候选版，普通开发只进入 F；A/B 不向 F 自动同步，也不得直接 merge。冻结后发现的重大真实账本、恢复或安全缺陷，先登记并审阅；必要时才显式重开来源候选，且单独做 F 适配与验证。普通功能增强继续在 F 实施。

| 来源 | Frozen Candidate HEAD | 审阅源码快照 SHA-256 | 备注 |
|---|---|---|---|
| A | `eb6fa384a2df8c503eb76d13f68d080c08be31ad` | `F1E09D0D13D99017537EFB831FC6BA15EF67C3CCE3526173C77AFED508C2B9E8` | `A-LATEST.zip` 由 A-STATUS 声明对应 HEAD；远端/NAS 未验证。 |
| B | `9ddfe32b787ad9e522a48eb55ff8231227d79599` | `EEEC94C0433482C66DF0F6CA20ACA3993E2349AC5E39CD1CA92E711F690305B3` | 用户指定 `work/github-upload/B-LATEST.zip`；包内HEAD标记正确，SHA256SUMS 142/142通过，与 HEAD Git归档共同文件一致。CANDIDATE-MANIFEST 中70项过时。 |

此前在 F 内部保存的 B-LATEST 旧捕获（29dafce）保存在 `candidates/B-LATEST-29dafce-previous-capture.zip`，仅供还原比对，不能被认作 Frozen Candidate。

收到获准的新检查点时：先记录 commit、快照 SHA 和文件清单差异；审查源码与既有 F 决策；标记 `adopt / adapt / defer / reject` 并说明 F 实现与证据。数据、数据库、密钥、运行目录、Git 历史绝不整包复制。A/B 的测试结果不继承到 F。
