# 项目计划

## 阶段 C：故障排查体系

目标：

- 在写部署自动化前，先建立有资料来源支撑的排障框架。

交付物：

- `docs/fastgpt-deploy-risk-map.md`
- `docs/troubleshooting-checklist.md`
- `docs/diagnostic-script-design.md`
- `docs/commercial-offline-notes.md`
- `docs/source-references.md`
- `AGENTS.md`
- `scripts/diagnose.sh`
- `tests/diagnose_test.sh`

验收标准：

- 文档覆盖官方故障排查分类。
- 文档覆盖商业版离线部署风险。
- 文档能指导后续脚本应该检查什么。
- 诊断脚本设计区分只读检查、脱敏输出和人工确认的恢复动作。
- 第一版诊断脚本只执行只读命令，并能生成脱敏后的证据目录。
- 不提交客户密钥、商业版 PDF、本地镜像包或客户部署包。

## 阶段 A：商业版离线新部署

目标：

- 针对一个商业版 FastGPT 基线版本，生成可重复使用的离线部署包。

预计交付：

- 版本化镜像 manifest。
- 模板化 compose 和 config 文件。
- pull、save、load、package、start、healthcheck 脚本。
- checksum 和 package manifest。
- 操作 runbook。

设计约束：

- 脚本必须读取版本化 manifest，不要重复硬编码镜像 tag。

## 阶段 B：版本升级流程

目标：

- 让 FastGPT 升级过程可追溯、可验证、可回滚。

预计交付：

- 版本 diff 检查清单。
- 升级脚本登记表。
- 备份清单。
- 回滚 runbook。
- 升级后验收清单。

设计约束：

- 升级步骤必须区分镜像变更和初始化脚本。
