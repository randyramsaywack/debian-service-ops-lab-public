# Debian Service Operations Lab

A production-like Debian homelab operations portfolio covering staged patching, validation, monitoring, logging, hardening, backups, and recovery drills.

## Purpose

This repo demonstrates practical systems administration work: planned changes, reproducible configuration, staged upgrades, validation, monitoring, auditability, rollback, and documented recovery.

Public repo note:

- hostnames, IPs, and key-path examples in this copy are sanitized placeholders

## Start Here

If you are picking up this repo as a collaborator or agent, start with:

- `AGENTS.md` for the public-safe agent handoff, guardrails, and recommended next tasks
- `docs/architecture.md` for the target lab design and maintenance workflow
- `docs/inventory.md` for the current lab host plan

## Current Progress

The lab has moved past planning and into early implementation.

Completed so far:

- Athena Debian 12 Proxmox template rebuilt as `9002`
- template workflow documented in `docs/runbooks/proxmox-cloud-init-template.md`
- clone helper implemented in `scripts/new-debian-vm.sh`
- helper updated to create full clones explicitly with `qm clone --full 1`
- template identity sanitization documented to prevent duplicate `machine-id` and DHCP lease collisions
- `ops-dev` provisioned and validated on Athena
- initial Ansible inventory and baseline playbook implemented and applied successfully to `ops-dev`
- initial hardening baseline implemented and applied successfully to `ops-dev`
- first Ansible-managed `nginx` smoke service prepared for `ops-dev`
- first proxied FastAPI backend + static frontend prepared for `ops-dev`
- staged patching runbook and patch-report helper added for repeatable maintenance evidence
- one real patching report captured from `ops-dev` with final result `PASS`
- Athena practice cheat sheet added for repeatable CLI practice

Current live baseline:

- Proxmox node: `proxmox-a.example.internal`
- template VMID: `9002`
- storage: `proxmox-zfs`
- bridge: `vmbr0`
- clone helper path on Athena: `/root/bin/new-debian-vm.sh`
- current dev VM: `ops-dev` at `10.0.0.10`
- current exposed endpoints:
  - `http://10.0.0.10/`
  - `http://10.0.0.10/healthz`
  - `http://10.0.0.10/api/healthz`
  - `http://10.0.0.10/api/message`

Current proven capabilities:

- clone and validate a Debian 12 VM from a Proxmox cloud-init template
- apply a reproducible Ansible baseline and hardening policy
- expose a service through `nginx` with explicit UFW rules
- run a FastAPI backend under `systemd`
- validate host and HTTP health with a repeatable pass/fail script
- capture maintenance evidence in dated markdown reports with a reusable patch-report helper
- document dev -> stage -> prod promotion gates and rollback criteria

## Success Criteria

- A Debian service VM can be rebuilt from documented configuration and playbooks.
- Updates are tested in staging before production.
- Post-upgrade validation produces a clear pass/fail report.
- Monitoring and logging prove service health before and after maintenance.
- Backups are restored during a documented drill.
- A final capstone runbook explains a realistic Nginx/app/Postgres upgrade scenario.

## Repository Layout

| Path | Purpose |
|------|---------|
| `docs/architecture.md` | Lab architecture, VM roles, network/storage assumptions, and maintenance workflow |
| `docs/runbooks/` | Operational procedures for provisioning, patching, validation, backup, restore, and incidents |
| `docs/reports/` | Dated maintenance reports, restore drill outputs, screenshots, and evidence |
| `ansible/` | Inventories, playbooks, roles, and group variables for Debian hosts |
| `scripts/` | Local validation and reporting helpers |
| `monitoring/` | Monitoring configuration, alert rules, and dashboard exports |
| `logging/` | Central logging configuration and change/incident log templates |
| `backups/` | Backup policy notes, restore drill procedures, and retention documentation |

## Working Today

If you want to use what is already implemented, these are the main entry points:

- Use `docs/runbooks/proxmox-cloud-init-template.md` for the Athena template build and rebuild workflow
- Use `docs/runbooks/athena-ops-cheat-sheet.md` for the command-by-command practice path
- Use `docs/runbooks/hardening-baseline.md` for the current SSH/sudo/firewall/fail2ban policy
- Use `docs/runbooks/staged-patching.md` for the current dev -> stage -> prod maintenance flow
- Use `scripts/README.md` for the Athena helper deployment commands, clone examples, and troubleshooting commands
- Use `ansible/README.md` for the current baseline and hardening playbook commands
- Use `docs/inventory.md` for the current lab VM state

Typical Athena workflow:

1. Refresh the helper script on Athena
2. Clone from template `9002`
3. Validate SSH, cloud-init, guest agent, networking, and disk state
4. Apply the Ansible baseline and hardening playbooks

Current helper usage from the admin workstation:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9101 ops-dev --start'
```

Important implementation note:

- the helper expects `/root/.ssh/admin-bootstrap.pub` and `/root/bin/admin-workstation.pub` to exist on Athena
- the template workflow now includes clearing `/etc/machine-id` before templating so fresh clones get unique identities and DHCP leases

## Current Phase

Foundation and hardening baseline:

- Design the lab architecture.
- Provision dedicated Debian VMs.
- Add Ansible rebuild path.
- Apply practical SSH, firewall, sudo, and login-protection hardening.
- Document the baseline and validation checks.

Current next focus:

- add the next service dependency, likely Postgres, behind the current `nginx` + FastAPI path
- build the matching Zeus template
- provision `ops-stage` so the staged patching flow can be exercised for real

## Validation Evidence

Recent evidence paths:

- `docs/reports/2026-05-03-ops-dev-baseline-hardening.md` for the baseline and hardening validation record
- `docs/reports/2026-05-03-ops-dev-nginx-smoke-service.md` for the first service rollout before/after report
- `docs/reports/2026-05-03-ops-dev-fastapi-frontend-rollout.md` for the first proxied app rollout report
- `docs/reports/2026-05-03-ops-dev-patching.md` for the first generated patching snapshot with final result `PASS`
- `scripts/validate-host.sh` for a fast pass/fail validation summary you can run against a live host

Latest live validation result:

- `./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz --http-url http://10.0.0.10/api/healthz`
- result: `11 passed, 0 failed`
