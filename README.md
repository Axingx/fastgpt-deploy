# fastgpt-deploy

FastGPT Docker deployment knowledge base and offline delivery toolkit.

This repository is being built to reduce repeated manual lookup across FastGPT official docs, commercial deployment notes, and customer-specific offline deployment steps.

## Current Focus

Phase C: troubleshooting system first.

Before adding automation scripts, the project documents the deployment risk map, evidence collection flow, and acceptance checks. The scripts should later be derived from these documents instead of becoming another pile of one-off commands.

## Planned Scope

- Community Docker Compose deployment notes.
- Commercial edition offline deployment notes.
- Versioned image lists and package manifests.
- Preflight, healthcheck, evidence collection, and rollback scripts.
- Upgrade runbooks based on official FastGPT upgrade notes.

## Non-Goals

- This repository should not store customer secrets, licenses, private domain names, or real credentials.
- This repository should not store the commercial deployment PDF itself unless we explicitly decide it is safe for a public GitHub repository.
- This repository is not a fork of FastGPT and should not duplicate official documentation wholesale.

## Documentation Map

- [Deployment Risk Map](docs/fastgpt-deploy-risk-map.md)
- [Troubleshooting Checklist](docs/troubleshooting-checklist.md)
- [Commercial Offline Notes](docs/commercial-offline-notes.md)
- [Source References](docs/source-references.md)
- [Project Plan](docs/project-plan.md)

## Source Priority

1. Current official FastGPT documentation.
2. Version-specific official upgrade notes.
3. Commercial deployment PDF and provided attachment scripts.
4. Local customer deployment evidence.

When sources conflict, record the conflict in docs before turning it into automation.
