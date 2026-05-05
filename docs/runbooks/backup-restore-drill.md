# Backup and Restore Drill

This runbook defines the first repeatable backup and restore drill for the lab service VM and its app data path.

The goal is to prove, on demand, that the lab can recover the running service from a known-good backup without overwriting production state, and to capture dated evidence with a clear pass or fail line.

## Scope

Current first-pass coverage:

- Proxmox VM-level snapshot of the service VM
- Off-host copy of the app data path archive
- Filesystem restore of the app data path into an isolated VM
- Service-level validation after restore
- Dated drill report under `docs/reports/`

Out of scope for this first pass:

- PostgreSQL logical backups (added when the Postgres role lands)
- Encrypted off-host targets
- Cross-node restore (`proxmox-a` to `proxmox-b`)

## Current Targets

- Source service VM: `ops-dev` at `10.0.0.10`
- App data path on the source VM:
  - `/opt/ops-lab-app/current` (FastAPI source rendered by the `app_demo` role)
  - `/etc/ops-lab-api.env` (rendered service environment file)
  - `/etc/systemd/system/ops-lab-api.service` (rendered unit file)
- Restore target VM: an isolated clone, for example `ops-restore` on `proxmox-a.example.internal`
- Off-host copy target: documented in `backups/README.md`; do not write into the source VM

The Python virtualenv at `/opt/ops-lab-app/venv` is intentionally rebuilt by the `app_demo` role and is not part of the data archive.

## Design Principles

- Never restore over a live production VM. Always restore into a separate VM with a different name and IP.
- Treat the Proxmox snapshot as the primary recovery path and the filesystem archive as the verification artifact.
- Run the same validation command against the restored host that is used after patching.
- Capture both an attempted RPO and an attempted RTO for every drill, even if the first run is slow.
- Do not invent output. If a step is skipped or a tool is unavailable, write that in the report.

## Pre-Flight Checklist

Before starting a drill:

- confirm the source VM identity and IP
- confirm the source VM is healthy with `scripts/validate-host.sh`
- confirm the off-host copy target has free space
- confirm the restore VM name is not in use on the Proxmox node
- record the planned RPO and RTO targets in the report header

## Drill Workflow

### 1. Capture a pre-drill validation snapshot

```sh
./scripts/validate-host.sh debian@10.0.0.10 \
  --service ops-lab-api \
  --service nginx \
  --http-url http://10.0.0.10/healthz \
  --http-url http://10.0.0.10/api/healthz
```

### 2. Take a Proxmox snapshot of the source VM

```sh
ssh root@proxmox-a.example.internal \
  'qm snapshot 9101 pre-drill-$(date -u +%Y%m%dT%H%M%SZ) --description "ops-lab backup/restore drill"'
```

### 3. Create an off-host archive of the app data path

```sh
ssh debian@10.0.0.10 'sudo tar -C / \
  --exclude=/opt/ops-lab-app/venv \
  -czf /tmp/ops-lab-app-data.tgz \
  opt/ops-lab-app/current \
  etc/ops-lab-api.env \
  etc/systemd/system/ops-lab-api.service'

scp debian@10.0.0.10:/tmp/ops-lab-app-data.tgz <off-host-target>/
ssh debian@10.0.0.10 'rm -f /tmp/ops-lab-app-data.tgz'
```

Replace `<off-host-target>` with the documented backup target. Do not invent a real path here.

### 4. Provision the restore VM

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9199 ops-restore --start'
```

Then run the Ansible baseline and hardening against the restore VM so it matches the source baseline before data is restored.

### 5. Restore the app data path into the restore VM

```sh
scp <off-host-target>/ops-lab-app-data.tgz debian@<ops-restore-ip>:/tmp/
ssh debian@<ops-restore-ip> 'sudo tar -C / -xzf /tmp/ops-lab-app-data.tgz'
ssh debian@<ops-restore-ip> 'sudo systemctl daemon-reload && sudo systemctl restart ops-lab-api'
```

### 6. Validate the restored service

```sh
./scripts/validate-host.sh debian@<ops-restore-ip> \
  --service ops-lab-api \
  --service nginx \
  --http-url http://<ops-restore-ip>/healthz \
  --http-url http://<ops-restore-ip>/api/healthz
```

The drill passes only if every check in the validator returns `PASS` and the report records measured RPO and RTO values.

### 7. Decommission the restore VM

```sh
ssh root@proxmox-a.example.internal 'qm stop 9199 && qm destroy 9199'
```

Keep the off-host archive long enough to satisfy the documented retention policy in `backups/README.md`.

## RPO and RTO

Record both in every drill report:

- RPO: time between the most recent backup and the simulated incident
- RTO: wall-clock time from drill start to a passing validator on the restore VM

Do not copy values forward between drills. Each drill measures its own.

## Failure and Rollback

If the drill cannot complete:

- record the failing step and the exact error in the report
- leave the source VM untouched
- destroy the partially provisioned restore VM
- file a follow-up task before retrying the drill

Source VM rollback is only required if the snapshot or archive step damaged the source. In that case, restore the source VM from the pre-drill Proxmox snapshot taken in step 2.

## Evidence Standard

For each drill keep:

- one dated report under `docs/reports/YYYY-MM-DD-ops-restore-drill.md`
- the validator output from steps 1 and 6
- the snapshot name and the archive filename
- a final line stating `PASS` or `FAIL`

A blank report template lives at `docs/reports/templates/backup-restore-drill.md`.

## Future Work

- Add a PostgreSQL section once the Postgres role lands, covering `pg_dump` and verified restore into the drill VM.
- Add an automated `scripts/restore-drill.sh` once the manual flow above has produced at least one passing report.
- Document encrypted off-host transport once the off-host target is finalized.
