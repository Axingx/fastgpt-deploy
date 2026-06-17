# AGENTS.md

Guidance for AI agents and maintainers working in this repository.

## Project Intent

This project turns FastGPT Docker deployment, commercial offline delivery, upgrades, and troubleshooting into repeatable documentation and scripts.

The first priority is not automation speed. The first priority is reliable diagnosis: every script should map back to an explicit risk, check, or runbook item.

## Working Rules

- Keep this repository safe for a public GitHub remote.
- Do not commit customer secrets, FastGPT licenses, real tokens, private IPs, private domains, exported image tar files, or generated customer packages.
- Do not commit the commercial PDF itself unless the user explicitly confirms it is safe to publish.
- Prefer documenting source conflicts before guessing.
- Before changing version-specific deployment files, check current official FastGPT docs and the relevant version upgrade note.
- Keep community, commercial, and customer-specific material separated.
- Treat files under `references/` as historical inputs, not as current truth.

## Documentation Placement

- Use `README.md` for the project overview and navigation only.
- Use `AGENTS.md` for repository collaboration rules.
- Use `docs/fastgpt-deploy-risk-map.md` for diagnosis layers and risk categories.
- Use `docs/troubleshooting-checklist.md` for executable preflight, runtime, and evidence checks.
- Use `docs/commercial-offline-notes.md` for commercial edition and offline delivery notes.
- Use `docs/source-references.md` for official and local source tracking.
- Use `references/` for raw or lightly normalized source artifacts that are safe to publish.

## Change Discipline

- Make small, reviewable edits.
- If a new script is added, document which checklist item it supports.
- If a command is destructive, such as pruning networks or removing containers, document the condition that justifies it and keep it out of default happy-path scripts.
- If a command requires live customer infrastructure, write it as an operator step and do not execute it locally.

## Verification Expectations

For documentation-only changes:

- Check that expected files exist.
- Check that Markdown has no unfinished placeholder markers.
- Check git status before finalizing.

For script changes:

- Run shell syntax checks where possible.
- Run scripts in dry-run mode if supported.
- Never claim deployment success without fresh command output from the target environment.
