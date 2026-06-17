# 诊断脚本设计

这份文档定义未来诊断脚本应该做什么、不应该做什么。目标是把 `docs/troubleshooting-checklist.md` 里的人工排查步骤，逐步变成可重复执行、可脱敏、可打包的证据收集工具。

第一版脚本只做只读诊断，不做修复，不重启容器，不删除网络，不修改 compose/config。

## 目标

- 快速收集 FastGPT 部署环境的基础证据。
- 帮助判断问题属于服务器环境、镜像包、基础服务、FastGPT 服务、外部访问、模型配置、对象存储还是升级流程。
- 生成一个可发给同事或供应商的脱敏证据包。
- 为后续 healthcheck、offline package 校验和升级检查脚本提供统一输出格式。

## 非目标

- 不自动修复问题。
- 不执行 `docker compose down`、`docker restart`、`docker network prune`、`docker rm -f` 等会改变环境的命令。
- 不上传日志到外部服务。
- 不收集客户真实业务数据。
- 不默认输出完整环境变量，因为其中可能包含密钥。

## 推荐脚本结构

```text
scripts/
  diagnose.sh              # 诊断入口，只读收集证据
  lib/
    common.sh              # 日志、路径、命令存在性检查
    redact.sh              # 脱敏规则
    docker.sh              # Docker 相关只读检查
    compose.sh             # Compose 配置和服务检查
    fastgpt.sh             # FastGPT 容器日志和关键变量检查
    storage.sh             # MinIO/S3 endpoint 检查
    network.sh             # 端口和网络检查
  recover/
    README.md              # 恢复动作说明，只写文档，不默认执行
```

第一版可以先只实现 `diagnose.sh`，等输出稳定后再拆分 `lib/`。

## 运行方式

建议入口：

```bash
./scripts/diagnose.sh
./scripts/diagnose.sh --compose-file docker-compose.yml
./scripts/diagnose.sh --output ./diagnostics
./scripts/diagnose.sh --profile commercial
```

推荐参数：

- `--compose-file`：指定 compose 文件，默认 `docker-compose.yml`。
- `--output`：指定输出目录，默认 `diagnostics/<timestamp>`。
- `--profile`：指定部署类型，可选 `community`、`commercial`。
- `--tail`：指定每个容器日志行数，默认 300。
- `--no-logs`：只收集环境和配置，不收集容器日志。
- `--redact-only`：对已有输出做脱敏处理，便于重新检查。

## 输出目录

推荐输出：

```text
diagnostics/
  2026-06-18T00-30-00/
    summary.md
    host/
      date.txt
      uname.txt
      cpu.txt
      disk.txt
      memory.txt
      ports.txt
    docker/
      version.txt
      compose-version.txt
      ps.txt
      ps-all.txt
      images.txt
      networks.txt
    compose/
      config.redacted.yml
      images.txt
      important-env.redacted.txt
    logs/
      mongo.log
      fastgpt-pg.log
      fastgpt-redis.log
      fastgpt-minio.log
      fastgpt-app.log
      fastgpt-pro.log
      fastgpt-plugin.log
      fastgpt-code-sandbox.log
      fastgpt-mcp-server.log
      fastgpt-aiproxy.log
    checks/
      storage.md
      external-access.md
      model-path.md
    diagnostic-package.tar.gz
```

`diagnostic-package.tar.gz` 只能包含脱敏后的内容。

## 只读命令清单

第一版允许执行：

```bash
date
uname -a
lscpu
df -h
free -h
ss -lntp
docker -v
docker compose version
docker-compose -v
docker compose ps
docker ps -a
docker images
docker network ls
docker compose config
docker logs <container> --tail <n>
curl -I <endpoint>
```

注意：

- `docker compose config` 输出必须脱敏后保存。
- `docker logs` 输出保存前要经过脱敏规则。
- `curl -I` 只请求 Header，避免下载对象或业务内容。

## 禁止默认执行的命令

这些命令只能出现在恢复文档中，不能由 `diagnose.sh` 默认执行：

```bash
docker compose down
docker compose up -d
docker restart <container>
docker network prune
docker network rm <network>
docker rm -f <container>
docker volume rm <volume>
rm -rf <path>
```

如果未来需要恢复脚本，必须独立命名，例如 `scripts/recover-sandbox-network.sh`，并满足：

- 默认 dry-run。
- 执行前打印将要删除的容器或网络。
- 需要用户显式传入 `--confirm`。
- 文档中写清适用错误和前置证据。

## 脱敏规则

至少脱敏以下内容：

- `ROOT_KEY`
- `DEFAULT_ROOT_PSW`
- `TOKEN_KEY`
- `FILE_TOKEN_KEY`
- `AES256_SECRET_KEY`
- `PLUGIN_TOKEN`
- `CODE_SANDBOX_TOKEN`
- `AIPROXY_API_TOKEN`
- `ADMIN_KEY`
- `MONGODB_URI`
- `REDIS_URL`
- `PG_URL`
- `STORAGE_ACCESS_KEY_ID`
- `STORAGE_SECRET_ACCESS_KEY`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`
- `OPENAI_BASE_URL`
- `CHAT_API_KEY`
- `Authorization: Bearer ...`
- `sk-...` 形式的模型密钥
- License 字符串

推荐替换格式：

```text
ROOT_KEY=<redacted:ROOT_KEY>
MONGODB_URI=mongodb://<redacted>:<redacted>@mongo:27017/fastgpt?authSource=admin
Authorization: Bearer <redacted:bearer-token>
```

脱敏要保留结构，方便判断 host、端口和参数是否正确。

## 检查分层

脚本输出的 `summary.md` 应按风险地图分层：

- L0 服务器基础环境。
- L1 镜像与离线包完整性。
- L2 基础服务。
- L3 FastGPT 服务层。
- L4 外部访问与反向代理。
- L5 业务配置。
- L6 升级与回滚。

每层输出：

- `status`：`ok`、`warning`、`error` 或 `unknown`。
- `evidence`：对应文件路径。
- `next_steps`：建议人工查看的位置。

示例：

```markdown
## L2 基础服务

status: warning

evidence:

- `logs/mongo.log`
- `docker/ps.txt`

next_steps:

- 如果 `mongo` 不在 running 状态，先查看 `logs/mongo.log`。
- 如果日志中有 `Illegal instruction`，优先检查 CPU 指令集和 Mongo 镜像版本。
```

## 商业版特定检查

当 `--profile commercial` 时，额外检查：

- `fastgpt-pro` 容器是否存在。
- `fastgpt-app` 是否配置 `PRO_URL`。
- `fastgpt-pro` 和 `fastgpt-app` 的存储相关环境变量是否一致。
- `fastgpt-pro` 日志是否有 License、域名或 Admin 后台相关错误。
- 对外端口是否包含商业版 Admin 入口。

第一版只做静态检查和日志收集，不登录后台、不自动验证 License。

## 离线部署特定检查

未来可加入 `--offline-package <path>`，用于检查离线包：

- `image-list.txt` 是否存在。
- `checksums.sha256` 是否存在。
- compose 中的镜像是否都在 image list 中。
- tar 包文件是否存在并通过 checksum。
- 是否有 load/start/healthcheck 操作说明。

第一版可先不实现，只在 `summary.md` 中提示离线包检查尚未执行。

## 错误处理

脚本不应该因为某个命令不存在就整体失败。建议策略：

- 命令不存在：记录为 `unknown`，继续后续检查。
- 容器不存在：记录为 `unknown`，不要退出。
- Docker daemon 不可用：记录 L0/L1 为 `error`，跳过 Docker 相关检查。
- compose 文件不存在：记录 L1 为 `error`，跳过 compose 检查。
- 权限不足：记录原始错误，并提示需要用有 Docker 权限的用户执行。

## 提交前验证

实现脚本时至少验证：

```bash
bash -n scripts/diagnose.sh
shellcheck scripts/diagnose.sh
./scripts/diagnose.sh --help
./scripts/diagnose.sh --output /tmp/fastgpt-diagnostics-test
```

如果本机没有 Docker 或没有目标 compose 文件，可以先验证：

- `--help` 正常。
- 缺少 Docker 时输出清晰错误。
- 缺少 compose 文件时输出清晰错误。
- 脱敏函数能覆盖典型密钥格式。

## 第一版实现建议

建议第一版只做：

1. 参数解析。
2. 创建输出目录。
3. 收集 host 和 Docker 基础信息。
4. 收集 `docker compose ps`、`docker ps -a`、`docker images`。
5. 保存脱敏后的 `docker compose config`。
6. 按固定容器名收集日志，容器不存在时跳过。
7. 生成 `summary.md`。

先让证据收集稳定，再考虑 endpoint 检查、离线包检查和恢复脚本。
