# 商业版离线部署笔记

这份笔记整理用户提供的商业版部署 PDF 和附件脚本中的信息。它不是官方商业版文档的替代品。

## 已查看资料

- 本地 PDF：`/Users/axing/Downloads/FastGPT商业版命令行部署教程.pdf`
- 本地 legacy 脚本：`/Users/axing/Downloads/docker-pull-commands.sh`
- 本地 legacy 脚本：`/Users/axing/Downloads/docker-save-commands.sh`

PDF 本体不提交到仓库，因为这个仓库计划公开。

## 商业版主要差异

商业版在主服务 `fastgpt-app` 之外增加 `fastgpt-pro` 服务。

需要重点保持一致的配置：

- MongoDB 连接。
- PostgreSQL 或向量库连接。
- Redis 连接。
- 对象存储配置。
- Plugin URL 和 Token。
- Code sandbox URL 和 Token。
- AIProxy endpoint 和 Token。
- 文件 Token 和加密相关 key。
- `FE_DOMAIN`、`FILE_DOMAIN` 等外部域名配置。

商业版额外关注：

- `fastgpt-app` 需要通过 `PRO_URL` 指向 Pro 服务。
- 商业版 Admin 后台需要单独验证。
- 首次部署需要 License 激活。
- License 签发依赖当前域名，因此申请 License 前要先确认最终访问域名。

## 当前离线交付模式

当前业务现实：

1. 在自己电脑上拉取或准备 Docker 镜像。
2. 导出镜像包。
3. 通过客户提供的上传工具传到客户服务器。
4. 在客户服务器加载镜像。
5. 启动服务。
6. 执行验收检查。

这意味着：

- 客户服务器启动时不能依赖公网拉镜像。
- 离线包必须包含 manifest 和 checksum。
- 离线包必须包含 load、start、healthcheck 步骤。
- 每个离线包必须锁定版本 tag。

## Legacy 脚本观察

下载的 `docker-pull-commands.sh` 和 `docker-save-commands.sh` 默认使用：

- `TAG=v4.14.4`
- `pluginTag=v0.3.4`
- `aiproxy:v0.2.2`
- `fastgpt-sandbox:${TAG}`

商业版 PDF 示例中出现了更新且不同的服务，例如：

- `fastgpt:v4.14.24`
- `fastgpt-pro:v4.14.24`
- `fastgpt-plugin:v0.6.0`
- `fastgpt-code-sandbox:v4.14.12`
- `fastgpt-mcp_server:v4.14.12`
- OpenSandbox 相关镜像
- volume manager
- `aiproxy:v0.6.0`

结论：

- 下载脚本只保留为历史参考。
- 后续脚本必须读取版本化镜像 manifest。
- 不能假设所有组件都和 FastGPT 主服务使用同一个 tag。

## 商业版离线部署验收项

最低验收：

- 主 UI 能打开。
- Pro/Admin UI 能打开。
- root 登录正常。
- License 激活页或授权状态符合预期。
- 用户浏览器能访问 MinIO/S3 endpoint。
- 知识库文件上传正常。
- 知识库索引能启动。
- 已配置的聊天模型能返回。
- 已配置的向量模型能索引。
- plugin runtime 健康。
- 如果工作流依赖代码沙盒，code sandbox 健康。
- AIProxy 能调用至少一个已配置模型供应商。

## 自动化前需要确认的问题

- 第一版支持哪个商业版 FastGPT 基线版本？
- 离线包是否要包含系统插件 `.pkg` 文件，以支持完全离线安装？
- MinIO 是直接暴露、通过 Nginx 代理，还是替换为客户已有对象存储？
- 部署包是否同时支持 `docker compose` 和旧式 `docker-compose` 命令？
- 执行网络清理等破坏性恢复命令前，需要收集哪些证据？
