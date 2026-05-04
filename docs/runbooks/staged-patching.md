# Staged Patching Workflow

This runbook defines the intended maintenance promotion path for the lab:

1. `ops-dev`
2. `ops-stage`
3. `ops-prod`

Today, `ops-dev` is the active service VM. This runbook documents the exact flow to follow now on dev and later reuse on stage and prod.

## Goals

- make maintenance repeatable instead of improvised
- capture evidence before and after patching
- define clear promotion gates
- define rollback criteria before touching the next environment

## Current Assumptions

- `ops-dev` exists at `10.0.0.10`
- validation is driven by `scripts/validate-host.sh`
- dated evidence is stored under `docs/reports/`
- current service health checks are:
  - `http://10.0.0.10/healthz`
  - `http://10.0.0.10/api/healthz`

## Promotion Model

### Dev

Use dev to:

- apply the first package change
- catch service restart issues
- verify that hardening and app health survive patching

Promote from dev only if:

- the patching command completes without package errors
- required services come back cleanly
- the validator passes
- the final report result is `PASS`

### Stage

Use stage to:

- prove the exact same change on a production-like host
- confirm the same validation and rollback process works again

Promote from stage only if:

- the steps match dev with no surprise fixes
- the validator passes again
- rollback was not needed

### Prod

Use prod only after:

- stage passed
- rollback criteria are still acceptable
- any required snapshot or backup is complete

## Pre-Flight Checklist

Before patching any environment:

- keep one working SSH session open
- confirm the host identity and IP
- confirm the required health endpoints
- capture a pre-change report
- decide rollback triggers before starting

Useful checks:

```sh
ssh debian@10.0.0.10 'hostnamectl --static && systemctl is-system-running'
ssh debian@10.0.0.10 'apt list --upgradable'
ssh debian@10.0.0.10 'systemctl --failed --no-pager'
ssh debian@10.0.0.10 'sudo ufw status verbose'
ssh debian@10.0.0.10 'sudo fail2ban-client status sshd'
curl -i --max-time 5 http://10.0.0.10/healthz
curl -i --max-time 5 http://10.0.0.10/api/healthz
```

## Dev Workflow

### 1. Capture a pre-change report

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab
./scripts/patch-report.sh debian@10.0.0.10 \
  docs/reports/2026-05-XX-ops-dev-pre-patching.md \
  --http-url http://10.0.0.10/healthz \
  --http-url http://10.0.0.10/api/healthz
```

### 2. Apply the package change

For a manual package run:

```sh
ssh debian@10.0.0.10 'sudo apt update && sudo apt upgrade -y'
```

If patching is later automated through Ansible or another repo-controlled script, replace this step with that command and keep the same evidence flow.

### 3. Validate immediately after patching

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab
./scripts/validate-host.sh debian@10.0.0.10 \
  --http-url http://10.0.0.10/healthz \
  --http-url http://10.0.0.10/api/healthz
```

### 4. Capture the post-change report

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab
./scripts/patch-report.sh debian@10.0.0.10 \
  docs/reports/2026-05-XX-ops-dev-post-patching.md \
  --http-url http://10.0.0.10/healthz \
  --http-url http://10.0.0.10/api/healthz
```

### 5. Decide whether to promote

Promote only if:

- validator result is `PASS`
- no unexpected failed units remain
- required HTTP checks succeed
- reboot state is understood and planned for

## Rollback Criteria

Rollback should be triggered if any of the following occur and cannot be resolved quickly inside the maintenance window:

- SSH access is lost or unstable
- a required service fails validation after a reasonable recovery attempt
- `systemctl --failed` shows new critical failures
- `http://.../healthz` or `http://.../api/healthz` fails and you cannot restore service quickly
- package management is left in a broken or half-configured state

## Rollback Options

Choose the least disruptive valid option:

- restart the affected services if the issue is transient
- revert the recent config change if the patch included config updates
- restore from a Proxmox snapshot if one was taken
- rebuild the host from the documented template + Ansible path if recovery is cleaner than in-place repair

## Evidence Standard

For each maintenance event, keep:

- one pre-change report
- one post-change report
- the validator result
- a short final line stating `PASS` or `FAIL`

Good report naming pattern:

- `docs/reports/YYYY-MM-DD-ops-dev-pre-patching.md`
- `docs/reports/YYYY-MM-DD-ops-dev-post-patching.md`
- `docs/reports/YYYY-MM-DD-ops-stage-post-patching.md`
