# fastgpt-deploy

这是一个用于沉淀 FastGPT Docker 部署、商业版离线交付、版本升级和故障排查经验的项目。

当前重点不是马上写一堆部署脚本，而是先把部署风险、排查路径和验收标准整理清楚。后续脚本都应该从这些文档反推出来，避免再次变成难维护的命令合集。

## 当前阶段

当前选择的是 **C：故障排查体系优先**。

先解决这些问题：

- 每次出问题时应该先看哪些证据。
- 官方故障排查文档里的经验如何落到本项目。
- 商业版离线部署有哪些额外风险。
- 后续脚本应该检查什么，而不是只负责执行命令。

## 后续计划

- 社区版 Docker Compose 部署说明。
- 商业版离线部署说明。
- 按 FastGPT 版本维护镜像清单和离线包清单。
- 部署前检查、启动后健康检查、证据收集、回滚脚本。
- 基于官方版本升级说明维护升级 runbook。

## 不做什么

- 不保存客户真实密钥、License、Token、私有域名、私有 IP。
- 不把商业版部署 PDF 本体放进公开仓库，除非明确确认可以公开。
- 不全文复制官方文档，只记录本项目需要的判断方法、检查项和来源链接。
- 不把临时讨论直接写成长期规则，先压缩成稳定结论。

## 文档入口

- [部署风险地图](docs/fastgpt-deploy-risk-map.md)
- [故障排查清单](docs/troubleshooting-checklist.md)
- [数据卷恢复 Runbook](docs/fastgpt-volume-data-recovery-runbook.md)
- [诊断脚本设计](docs/diagnostic-script-design.md)
- [商业版离线部署笔记](docs/commercial-offline-notes.md)
- [资料来源](docs/source-references.md)
- [项目计划](docs/project-plan.md)

## 当前可用脚本

第一版诊断脚本：

```bash
./scripts/diagnose.sh --compose-file docker-compose.yml --output ./diagnostics/manual-check --profile commercial
```

它只做只读证据收集和脱敏输出，不会重启容器、删除网络或修改配置。

## 资料优先级

1. 当前官方 FastGPT 文档。
2. 对应版本的官方升级说明。
3. 商业版部署 PDF 和附件脚本。
4. 真实客户环境里的部署证据。

如果资料之间冲突，先在文档里记录冲突，不要直接写进脚本。
