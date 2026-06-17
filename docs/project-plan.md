# Project Plan

## Phase C: Troubleshooting System

Goal:

- Build a source-backed troubleshooting and risk framework before writing deployment automation.

Deliverables:

- `docs/fastgpt-deploy-risk-map.md`
- `docs/troubleshooting-checklist.md`
- `docs/commercial-offline-notes.md`
- `docs/source-references.md`
- `AGENTS.md`

Validation:

- Documents explain official troubleshooting categories.
- Documents capture commercial offline deployment risk.
- Documents identify what later scripts must check.
- No customer secrets or commercial PDF content are committed.

## Phase A: Commercial Offline New Deployment

Goal:

- Generate a repeatable offline deployment package for one commercial FastGPT baseline.

Expected deliverables:

- Versioned image manifest.
- Templated compose/config files.
- Pull, save, load, package, start, and healthcheck scripts.
- Checksums and package manifest.
- Operator runbook.

Design constraint:

- Scripts must read versioned manifests instead of duplicating image tags.

## Phase B: Version Upgrade Flow

Goal:

- Make FastGPT upgrades traceable and reversible.

Expected deliverables:

- Version diff checklist.
- Upgrade script registry.
- Backup checklist.
- Rollback runbook.
- Post-upgrade acceptance checklist.

Design constraint:

- Upgrade steps must separate image changes from initialization scripts.
