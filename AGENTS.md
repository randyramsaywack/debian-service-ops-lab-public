# Agent Handoff

This repository is the sanitized public portfolio copy of a Debian service operations lab. Treat it as a public-safe infrastructure project: keep examples reproducible, useful, and free of private hostnames, private IP ranges, secrets, API keys, and personal key paths.

## Start Here

Read these files before making changes:

- `README.md`
- `docs/architecture.md`
- `docs/inventory.md`
- `ansible/README.md`
- `scripts/README.md`
- `docs/runbooks/staged-patching.md`

## Project Goal

Show production-like systems administration work on Debian:

- VM provisioning from a Proxmox cloud-init template
- repeatable Ansible baseline and hardening
- staged patching with validation gates
- Nginx plus a small FastAPI-style application surface
- maintenance reports with real command output
- future monitoring, logging, backup, restore, and capstone upgrade evidence

This is a portfolio repo, but the work should remain operationally believable. Prefer small, concrete, verifiable improvements over broad mock architecture.

## Public-Safety Rules

- Do not add real private hostnames, internal domains, public IPs, private IPs from a real network, SSH key paths, tokens, API keys, emails, or account identifiers.
- Use sanitized examples such as `proxmox-a.example.internal`, `ops-dev`, `10.0.0.10`, and `/root/bin/admin-workstation.pub`.
- Do not invent command output and present it as real. If output is illustrative, label it clearly as an example.
- Keep report files factual. Real reports should include actual command output captured from a lab host; templates should be named and described as templates.
- Do not add encrypted vaults, `.env` files, private inventory, or generated local state.

## Current State

Implemented in this public snapshot:

- sanitized project README and architecture docs
- sanitized Proxmox cloud-init template runbook
- `scripts/new-debian-vm.sh` helper for full clones
- `scripts/validate-host.sh` pass/fail validator
- `scripts/patch-report.sh` report helper
- Ansible baseline, hardening, Nginx demo, and app demo playbooks
- reports for baseline/hardening, Nginx smoke service, FastAPI/frontend rollout, and patching
- staged patching runbook with dev -> stage -> prod gates

Not yet implemented in this public snapshot:

- dedicated `ops-stage` and `ops-prod` evidence
- PostgreSQL role and backup/restore drill
- monitoring stack configuration
- central logging stack configuration
- final capstone service upgrade runbook

## Good Next Tasks

The best next tasks for an autonomous coding agent are:

- Add a sanitized PostgreSQL role/runbook that supports the existing app-demo story without adding secrets.
- Add a backup and restore drill runbook for the app data path, including validation commands and a report template.
- Add monitoring/logging scaffolding that is realistic but does not require private infrastructure.
- Improve validation scripts to support optional database, systemd service, and HTTP endpoint checks.
- Keep README, inventory, and runbooks synchronized with any new playbooks or scripts.

Avoid huge rewrites. This project benefits most from incremental operational evidence.

## Validation Commands

Run these checks after changes when the relevant tools are available:

```sh
bash -n scripts/*.sh
cd ansible
ansible-playbook playbooks/baseline.yml --syntax-check
ansible-playbook playbooks/hardening.yml --syntax-check
ansible-playbook playbooks/nginx-demo.yml --syntax-check
ansible-playbook playbooks/app-demo.yml --syntax-check
```

For documentation-only changes, at least check links/paths manually and confirm no private values were introduced:

```sh
rg -n "randyland|home\\.|10\\.1\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.|api[_-]?key|token|secret|password|BEGIN .*PRIVATE KEY" .
```

If a command cannot be run in the current environment, say so in the final summary instead of hiding it.

## Change Style

- Preserve the current plain Markdown style.
- Keep commands copy/pasteable.
- Prefer ASCII unless an existing file already uses non-ASCII for a reason.
- Keep Ansible roles idempotent.
- Keep shell scripts strict with `set -euo pipefail`.
- Update docs whenever commands, scripts, inventory, or playbooks change.

## Final Response Expectations

When handing work back to a human, include:

- what changed
- what validation ran
- any commands that still need to be run on real infrastructure
- any assumptions or remaining risks
