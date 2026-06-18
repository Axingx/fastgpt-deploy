# 故障排查清单

这份清单用于部署前检查、启动后验收和故障时取证。先按清单收集证据，再决定是否修改配置或执行恢复命令。

## 1. 确认问题范围

- 部署类型：社区版还是商业版。
- 部署方式：在线部署还是离线部署。
- 向量库：PgVector、Milvus、Zilliz、OceanBase 或 SeekDB。
- FastGPT 版本和镜像来源。
- 问题类型：安装、启动、访问、模型、存储、插件、沙盒还是升级。

## 2. 收集基础证据

```bash
date
docker -v
docker compose version
docker-compose -v
docker compose ps
docker ps -a
docker images
df -h
free -h
```

在修改任何东西之前，先保存这些输出。

## 3. 检查 Compose 一致性

```bash
docker compose config
grep -n "image:" docker-compose.yml
grep -n "STORAGE_EXTERNAL_ENDPOINT\|FE_DOMAIN\|FILE_DOMAIN\|PRO_URL\|PLUGIN_BASE_URL\|AIPROXY_API_ENDPOINT" docker-compose.yml
```

重点看：

- 离线包里是否缺镜像。
- 是否出现未预期的 `latest` tag。
- 需要容器或用户浏览器访问的地址是否误写成 `localhost` 或 `127.0.0.1`。
- 商业版 `fastgpt-pro` 和 `fastgpt-app` 的共享配置是否一致。

## 4. 检查基础服务

```bash
docker logs mongo --tail 200
docker logs fastgpt-pg --tail 200
docker logs fastgpt-redis --tail 200
docker logs fastgpt-minio --tail 200
```

常见判断：

- Mongo 出现 `Illegal instruction`：CPU 不能运行当前 Mongo 镜像。
- FastGPT 报 Mongo buffering timeout：Mongo 不可用、凭证错误或副本集没有启动。
- PostgreSQL 报 `relation "modeldata" does not exist`：PG 连接或初始化失败。
- MinIO/S3 bucket 报错：检查 endpoint、path-style、账号密码和反向代理 Host。

## 5. 检查 FastGPT 服务

```bash
docker logs fastgpt-app --tail 300
docker logs fastgpt-pro --tail 300
docker logs fastgpt-plugin --tail 300
docker logs fastgpt-code-sandbox --tail 300
docker logs fastgpt-mcp-server --tail 200
docker logs fastgpt-aiproxy --tail 200
```

重点看：

- `config.json` 是否是合法 JSON。
- 数据库连接是否失败。
- 模型供应商是否报错。
- plugin 或 sandbox healthcheck 是否失败。
- 商业版 License 或域名是否有异常提示。

## 6. 从服务端和客户端检查对象存储

操作前先回答：

- FastGPT 容器能否访问 `STORAGE_S3_ENDPOINT`？
- 用户浏览器能否访问 `STORAGE_EXTERNAL_ENDPOINT`？
- 代理 MinIO/S3 时，Nginx 是否保留了带端口的 `Host`？
- 公开桶和私有桶名称是否正确？如果复用同一个桶，策略是否明确允许？

可用命令：

```bash
curl -I <STORAGE_EXTERNAL_ENDPOINT>
docker exec fastgpt-app env | grep STORAGE_
docker exec fastgpt-pro env | grep STORAGE_
```

## 7. 检查外部访问

```bash
curl -I http://<host>:3000
curl -I http://<host>:3002
curl -I http://<host>:3005
curl -I http://<host>:9000
```

商业版通常关注：

- `3000`：FastGPT 主服务。
- `3002`：商业版 Pro/Admin 服务，以商业版 PDF 示例为准。
- `3005` 或实际配置的 MCP 端口：MCP server。
- `9000`：用户浏览器需要访问的 MinIO/S3 endpoint。

端口最终以当前 `docker-compose.yml` 为准，不要盲信旧笔记。

## 8. 检查模型链路

按官方建议顺序检查：

1. 直接用 curl 测上游模型 endpoint。
2. 通过 OneAPI 或 AIProxy 测模型。
3. 在 FastGPT 里测模型。
4. 如果日志中能看到实际请求体，复制请求体再单独 curl。

常见判断：

- 知识库索引没有进度：通常是向量模型缺失或没有启用。
- 页面可对话但 API 测试失败：比较 stream 和 non-stream 模式差异。
- 工具调用工作流失败：确认模型供应商和代理都支持 tool call。
- 国内服务器访问海外 API 报 Connection Error：需要可访问的代理或本地模型服务。

## 9. 升级专用检查

升级前：

- 备份 Mongo、PostgreSQL、必要 Redis 数据、MinIO 数据、compose 和 config 文件。
- 记录当前镜像列表。
- 阅读所有跨越版本的官方升级说明。
- 如果新版 compose 把 `./pg/data`、`./mongo/data`、`./fastgpt-minio` 这类宿主机目录改成 named volume，先按 [FastGPT 升级后数据卷恢复 Runbook](fastgpt-volume-data-recovery-runbook.md) 迁移数据。

升级中：

- 明确修改镜像 tag。
- 先在客户服务器加载离线镜像，再执行 `docker compose up -d`。
- 单独执行升级初始化脚本，并记录输出。

升级后：

- 确认容器运行状态。
- 验证登录、模型配置、知识库上传、插件使用、商业版后台访问。

## 10. 给支持人员的证据包

需要升级排查时，准备：

- FastGPT 版本和部署类型。
- 脱敏后的 `docker-compose.yml`。
- 脱敏后的 `config.json`。
- `docker compose ps` 输出。
- 失败容器日志。
- 前端崩溃截图或浏览器 console 错误。
- 复现步骤。
