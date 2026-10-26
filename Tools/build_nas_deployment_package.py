from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_FILES = (
    ("nas/.env.example", ".env.example"),
    ("nas/__init__.py", "nas/__init__.py"),
    ("nas/Dockerfile", "nas/Dockerfile"),
    ("nas/compose.yml", "nas/compose.yml"),
    ("nas/DEPLOYMENT.md", "nas/DEPLOYMENT.md"),
    ("nas/docker-entrypoint.sh", "nas/docker-entrypoint.sh"),
)


def build_package(destination: Path) -> Path:
    destination = destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="guanpan-f-nas-") as temporary:
        stage = Path(temporary)
        for source_relative, target_relative in PACKAGE_FILES:
            source = ROOT / source_relative
            target = stage / target_relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

        for source in (ROOT / "nas" / "fminute").glob("*.py"):
            target = stage / "nas" / "fminute" / source.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

        compose_path = stage / "nas" / "compose.yml"
        compose = compose_path.read_text(encoding="utf-8")
        compose = compose.replace("context: ..\n      dockerfile: nas/Dockerfile",
                                  "context: .\n      dockerfile: Dockerfile")
        compose_path.unlink()
        (stage / "compose.yml").write_text(compose, encoding="utf-8")
        shutil.copy2(stage / "nas" / "Dockerfile", stage / "Dockerfile")
        (stage / "nas" / "Dockerfile").unlink()
        (stage / "nas" / "DEPLOYMENT.md").unlink()
        deploy_doc = """# 观盘 F NAS 分钟归档部署包

本包按 NAS Container Manager / Compose 项目根目录组织。Compose 项目名固定为合法小写 `guanpan-f`。若 NAS 界面要求单独填写项目名，也请填写 `guanpan-f`，不要使用带大写字母的名称。解压后，`compose.yml`、`Dockerfile`、`.env.example` 和 `nas/` 必须位于同一目录；选择包含 `compose.yml` 的目录作为项目目录，不要选择更深一层的 `nas/`。

## 部署

1. 将 ZIP 解压到 NAS 上长期保留的项目目录，例如 `/volume1/docker/guanpan-f`。
2. 复制 `.env.example` 为 `.env`。设置唯一随机 `F_MINUTE_API_TOKEN`（至少 32 个 UTF-8 字节），并将 `F_MINUTE_SECURITIES` 改成真实持仓/自选证券代码。
3. 默认数据目录为项目内 `./data`，会持久保存在解压目录。启动脚本会把挂载目录及属主不匹配的顶层数据文件调整为服务UID 10001，然后降权运行；该操作保留数据内容。若 NAS 使用不允许容器修改属主的 NFS/root-squash 或只读目录，服务会明确报权限错误，需要改用可写本地目录。
4. 在 NAS 容器管理器创建 Compose 项目，项目来源选择这份解压目录，读取根目录 `compose.yml` 并构建。
5. 启动后先检查 `/livez`，再用 `X-Api-Key` 请求 `/readyz` 和受保护 API。`/livez` 成功不代表上游历史数据已完整。

命令行部署时，在本目录执行：

```sh
docker compose --env-file .env -f compose.yml config
docker compose --env-file .env -f compose.yml up -d --build
```

服务运行需要由部署者配置的随机令牌。缺少令牌或真实证券代码时，Compose 会拒绝启动。API token 不写入镜像或包内默认值。

## 数据与验证边界

SQLite、补采状态和官方日历保存在 `/data` 挂载目录。当前项目目录默认挂载 `./data`；备份前确认该目录位于 NAS 持久卷。备份与恢复应先在单独目录演练。

此包不代表已部署。目标 NAS 上的镜像构建、8788 端口、官方日历同步、实时行情与历史覆盖仍需实际运行检查。历史行情源可能不可用或覆盖受限，缺失数据不会伪造。
"""
        (stage / "DEPLOYMENT.md").write_text(deploy_doc, encoding="utf-8")

        git_head = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
            capture_output=True, text=True,
        ).stdout.strip()
        (stage / "HEAD.txt").write_text(git_head + "\n", encoding="ascii")

        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=9) as archive:
            for path in sorted(stage.rglob("*")):
                if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc":
                    archive.write(path, path.relative_to(stage).as_posix())
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a root-layout F NAS deployment ZIP")
    parser.add_argument("destination", nargs="?", type=Path,
                        default=ROOT.parent / "F-NAS-DEPLOYMENT.zip")
    args = parser.parse_args()
    package = build_package(args.destination)
    print(package)
    print(f"bytes={package.stat().st_size}")


if __name__ == "__main__":
    main()
