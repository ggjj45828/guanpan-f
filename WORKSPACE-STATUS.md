# F 云端主工作区状态

## 当前本机工作区约定（2026-10-26）

- 唯一 Active Development 工作区为 `C:\Users\Administrator\.codex\.chatgpt-projects\g-p-6ac90ddb9a888191a751dc24eb6a329d\F`。所有 F 源码修改、提交、测试、状态矩阵与 checkpoint 均从此目录进行。
- A/B 只读；不得在 A/B 目录改动、提交、测试或创建 checkpoint。B 145项仅作为 F 的需求来源，不继承其实现状态或验证结果。
- 本机当前 F 目录由源码 ZIP 解包，尚无 `.git` 目录或 checkpoint bundle。因此本文其余分支/提交信息是来源工作区记录，不代表当前本机 Git 状态；在恢复仓库元数据前不创建提交或宣称 checkpoint 已建立。

- 唯一 Active Development：本目录 `F`，分支 `main`。
- A Frozen HEAD：`eb6fa384a2df8c503eb76d13f68d080c08be31ad`；B Frozen HEAD：`9ddfe32b787ad9e522a48eb55ff8231227d79599`。两者只读，未合并。
- 主状态文件：`F-STATUS.md`；验收：`F-MASTER-ACCEPTANCE-MATRIX.md`；裁决：`F-ARBITRATION-MATRIX.md`。
- 本地恢复要求：`main` 与 `F-CHECKPOINT` tag 指向同一提交；所有开发阶段更新上述状态和 checkpoint。
- 当前平台没有 Swift/Xcode；所有 XCTest 保持 defined 与 executed 分开记录。Python检查只能证明其自身范围。
- 外部验证待办包括 Swift/Xcode与iOS设备、NAS生产部署/实源、GitHub远端、真实行情/新闻和在线AI。

## 原生 App / NAS 部署阶段续接状态

- 当前续接基线：`main`与`F-CHECKPOINT`同一提交；可用 `F-CHECKPOINT.bundle` 恢复本工作区提交历史。本工作区从 F-LATEST 源码包重新导入，历史包不含上游 `.git`，因此此处不声称恢复原远端提交链。
- F Matrix 需求数40 defined，EXT-1…EXT-5仍 External Pending；B 145项继续作为需求输入，A/B状态和实现通过证据不继承。
- FCore XCTest defined 39 / executed 0 / passed 0 / failed 0；App UI XCTest defined 2 / executed 0 / passed 0 / failed 0。
- NAS新交付包已改为Compose与Dockerfile同根目录，`./data`为持久卷默认。用户授权移除API token认证；可达8788端口的客户端可访问所有API。当前源码/包配置已取消token，NAS实际重建部署未经验证。
- 本轮 Python 总套件111/111通过；py_compile、架构边界和XcodeGen/CI YAML结构检查通过。没有Swift/Xcode/XcodeGen/Docker。
- NAS Compose项目名固定为小写`guanpan-f`，避免NAS界面传入`guanpanF`触发项目名校验错误；修复后目标NAS验证仍待执行。
- 新部署日志暴露 `gosu` 包在目标 Debian slim 软件源不可用；镜像改装 `util-linux` 并用 `setpriv` 降权，专项部署包测试7/7通过。Docker镜像构建和NAS重部署未运行。

- iOS垂直切片源码现已连接真实只读Ledger、单证券行情、NAS研究Evidence、DecisionContext、Guards与DeepSeek Candidate；真实环境及Swift/Xcode验证仍待执行，候选不写Ledger。


- NAS `nas.fminute` 导入故障已在源码与部署打包器修复：显式package markers + Docker构建期模块import检查；新部署包测试6/6、解压import smoke通过。需更新部署ZIP到NAS重新构建；本地无Docker和NAS实际部署，保持External Verification Pending。


- SQLite `/data` 权限故障已修复在新部署包：启动阶段准备NAS挂载目录及顶层数据属主，然后降权至UID 10001运行；`./data` 路径和内容保持原样。部署包测试7/7和包内导入检查通过；无Docker/NAS，仍需用新包重建镜像验证。容器端口继续为8788。

- iOS Advisor 现按证券代码/名称、证券详情入口或组合默认分发；组合范围逐持仓刷新行情和NAS研究。证券详情新增NAS历史分时按日查询。Swift/Xcode不可用，FCore XCTest 39 defined/0 executed、App UI XCTest 2 defined/0 executed。

- 2026-10-26 用户实测 `:8788/livez` 返回 alive，NAS端口/进程可达；另一次401未注明请求路径/请求头，故`/readyz`与token尚未确认。私有GitHub仓库 `ggjj45828/guanpan-f` 已创建并设为本地origin；用户已授权源码上传；推送因当前环境缺GitHub HTTPS认证而失败，未传输对象；GitHub connector未连接，认证方式需配置后再运行F CI。现有 `guanpan-pro-native` Actions 是B构建结果，不能代替F编译。FCore 39/0/0/0、App UI 2/0/0/0保持不变。

- Advisor 作用域续修：组合问题不再要求至少一笔持仓；已建立账本中的现金空仓组合可分析。明确六位证券代码/详情页允许分析尚未持有的标的。Candidate仍只读审阅；Swift/Xcode构建闸门未执行。
