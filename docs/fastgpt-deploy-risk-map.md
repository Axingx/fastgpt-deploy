# FastGPT 部署风险地图

这份文档把 FastGPT 部署和升级中常见的痛点拆成诊断层级。后续写脚本时，应该先看脚本要覆盖哪一层风险。

## L0：服务器基础环境

风险：

- Docker 或 Docker Compose 没装、版本太低，或者命令名是 `docker-compose` 而不是 `docker compose`。
- CPU 指令集不满足镜像要求。
- 磁盘空间不足，无法容纳数据库、MinIO 对象、Docker layer 和离线镜像包。
- 端口被防火墙、安全组或已有服务占用。

建议收集：

```bash
docker -v
docker compose version
docker-compose -v
uname -a
lscpu
df -h
free -h
ss -lntp
```

已知判断：

- 官方 Docker 文档建议 Docker Compose 版本至少在 2.17 以上。
- 旧 CPU 可能无法运行 Mongo 5，官方文档和商业版 PDF 都提到可以切换到 Mongo 4.x。
- 较新的 MinIO 镜像可能在老 CPU 上出现 `CPU does not support x86-64-v2`，商业版 PDF 提到可以降级 MinIO 镜像。

## L1：镜像与离线包完整性

风险：

- 离线包缺少 `docker-compose.yml` 中引用的镜像。
- pull/save 脚本里的 tag 和 compose 文件不一致。
- 只升级了 FastGPT 主镜像，但 plugin、code sandbox、MCP、OpenSandbox、AIProxy 等镜像没有同步确认。
- 客户服务器不能访问公网镜像仓库，但 compose 启动时仍尝试拉取缺失镜像。

建议收集：

```bash
docker images
docker compose config
grep -R "image:" docker-compose.yml
```

规则：

- 每个 FastGPT 版本和部署类型都要维护独立镜像清单。
- 用户提供的 `docker-pull-commands.sh` 和 `docker-save-commands.sh` 只作为历史样例，不作为当前真相。
- 后续脚本应读取同一份镜像 manifest，不要在多个脚本里重复硬编码 tag。

## L2：基础服务

风险：

- Mongo 启动失败、副本集没有初始化，或者 `MONGODB_URI` 里的账号密码不一致。
- PostgreSQL 或 pgvector 初始化失败。
- Redis 密码、内存限制或持久化配置导致服务异常。
- MinIO 已启动但 bucket 或 endpoint 不可用。

建议收集：

```bash
docker compose ps
docker logs mongo --tail 200
docker logs fastgpt-pg --tail 200
docker logs fastgpt-redis --tail 200
docker logs fastgpt-minio --tail 200
```

常见现象：

- Mongo 日志出现 `Illegal instruction`，通常是 CPU 指令集不兼容。
- FastGPT 报 `Operation auth_codes.findOne() buffering timed out after 10000ms`，通常说明 Mongo 不可达、凭证错误或副本集启动失败。
- 报 `relation "modeldata" does not exist`，通常指向 PostgreSQL 连接或初始化失败。

## L3：FastGPT 服务层

风险：

- `fastgpt-app`、`fastgpt-pro`、plugin、code sandbox、MCP server、OpenSandbox、AIProxy 任一服务单独失败。
- 商业版 `fastgpt-pro` 配置和主服务 `fastgpt-app` 配置漂移。
- `PRO_URL`、`PLUGIN_BASE_URL`、`CODE_SANDBOX_URL`、AIProxy 地址写错。
- OpenSandbox 动态容器残留在网络中，导致 `docker compose down` 后网络无法删除。

建议收集：

```bash
docker logs fastgpt-app --tail 300
docker logs fastgpt-pro --tail 300
docker logs fastgpt-plugin --tail 300
docker logs fastgpt-code-sandbox --tail 300
docker logs fastgpt-opensandbox-server --tail 300
docker network ls
docker network inspect fastgpt_opensandbox
```

已知判断：

- 商业版部署里，`fastgpt-app` 和 `fastgpt-pro` 的存储、Token、域名等配置需要保持产品预期的一致性。
- 网络清理不应该放在默认部署路径里。只有确认是动态沙盒容器残留时，才进入恢复步骤。

## L4：外部访问与反向代理

风险：

- 必要端口没有对用户开放。
- Nginx 或其他反向代理丢失必要 Header。
- FastGPT 在代理后面时，客户端 IP Header 可能被伪造。
- `FE_DOMAIN`、`FILE_DOMAIN` 或 `STORAGE_EXTERNAL_ENDPOINT` 为空，或用户浏览器无法访问。

建议收集：

```bash
curl -I http://<host>:3000
curl -I http://<host>:3002
curl -I http://<host>:9000
curl -I http://<host>:3005
```

已知判断：

- 官方 Docker 文档要求 FastGPT 主服务、S3 服务、MCP 服务端口可访问。
- 官方 S3 排查文档指出，签名不一致常见原因是 Nginx 没有正确透传 Host。代理 MinIO/S3 时要保留端口。
- 如果 FastGPT 前面有反向代理，要谨慎配置可信代理，不要信任普通客户端传来的 `X-Forwarded-For`。

## L5：业务配置

风险：

- root 用户无法登录，因为 Mongo 或配置初始化失败。
- 模型没有配置，导致对话或索引失败。
- 离线部署无法访问插件市场。
- 商业版 License 的域名与实际部署访问域名不一致。
- 模型或配置对象结构异常导致前端页面崩溃。

建议收集：

```bash
docker logs fastgpt-app --tail 300
docker logs fastgpt-pro --tail 300
```

已知判断：

- 官方文档要求至少配置一个语言模型和一个索引模型。
- 从 FastGPT v4.14.0 开始，`fastgpt-plugin` 镜像只提供运行环境，系统插件需要单独安装。
- 商业版离线部署中，插件 `.pkg` 可能需要人工导入，不能依赖公网插件市场。

## L6：升级与回滚

风险：

- 只改镜像 tag，却漏掉对应版本要求的升级初始化脚本。
- 跨多个版本升级，但没有执行中间版本脚本。
- 数据库或对象存储没有备份。
- 客户服务器误从公网拉取未审核镜像，而不是使用已交付离线包。

建议收集：

```bash
docker compose config
docker images
docker compose ps
```

规则：

- 升级 runbook 必须把镜像 tag 变更和初始化脚本分开写。
- 官方升级说明指出 FastGPT 升级通常包括修改镜像和执行升级初始化脚本。
- 跨版本升级前必须备份数据，并优先逐版本阅读和执行升级说明。
