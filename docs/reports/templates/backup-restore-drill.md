# Backup and Restore Drill Report (TEMPLATE)

This file is a blank template. Copy it to `docs/reports/YYYY-MM-DD-ops-restore-drill.md` and fill in the placeholders with real captured output. Do not commit this file with invented values.

- Date: `<YYYY-MM-DD>`
- Source host: `<source-host>` at `<source-ip>`
- Restore host: `<ops-restore>` at `<restore-ip>`
- Proxmox node: `proxmox-a.example.internal`
- Source VMID: `<source-vmid>`
- Restore VMID: `<restore-vmid>`
- Pre-drill snapshot name: `<snapshot-name>`
- Off-host archive path: `<off-host-target>/ops-lab-app-data.tgz`
- Planned RPO: `<minutes>` minutes
- Planned RTO: `<minutes>` minutes
- Final result: `<PASS or FAIL>`

## Change Summary

Drill driven by `docs/runbooks/backup-restore-drill.md`. No production state was modified.

## Step 1 - Pre-drill Validation

Command:

```sh
./scripts/validate-host.sh debian@<source-ip> \
  --service ops-lab-api \
  --service nginx \
  --http-url http://<source-ip>/healthz \
  --http-url http://<source-ip>/api/healthz
```

Output:

```text
<paste real validator output here, or "Not captured">
```

## Step 2 - Proxmox Snapshot

Command:

```sh
ssh root@proxmox-a.example.internal 'qm snapshot <source-vmid> <snapshot-name> --description "ops-lab backup/restore drill"'
```

Output:

```text
<paste real qm output here, or "Not captured">
```

## Step 3 - Off-host Archive

Commands:

```sh
ssh debian@<source-ip> 'sudo tar -C / \
  --exclude=/opt/ops-lab-app/venv \
  -czf /tmp/ops-lab-app-data.tgz \
  opt/ops-lab-app/current \
  etc/ops-lab-api.env \
  etc/systemd/system/ops-lab-api.service'

scp debian@<source-ip>:/tmp/ops-lab-app-data.tgz <off-host-target>/
```

Captured archive size:

```text
<paste real ls -lh output here, or "Not captured">
```

## Step 4 - Restore VM Provisioning

Command:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh <restore-vmid> ops-restore --start'
```

Output:

```text
<paste real new-debian-vm.sh output here, or "Not captured">
```

Baseline and hardening applied to the restore VM:

```sh
ansible-playbook playbooks/baseline.yml --limit ops-restore
ansible-playbook playbooks/hardening.yml --limit ops-restore
```

## Step 5 - Restore App Data Path

Commands:

```sh
scp <off-host-target>/ops-lab-app-data.tgz debian@<restore-ip>:/tmp/
ssh debian@<restore-ip> 'sudo tar -C / -xzf /tmp/ops-lab-app-data.tgz'
ssh debian@<restore-ip> 'sudo systemctl daemon-reload && sudo systemctl restart ops-lab-api'
```

Output:

```text
<paste real tar/systemctl output here, or "Not captured">
```

## Step 6 - Post-restore Validation

Command:

```sh
./scripts/validate-host.sh debian@<restore-ip> \
  --service ops-lab-api \
  --service nginx \
  --http-url http://<restore-ip>/healthz \
  --http-url http://<restore-ip>/api/healthz
```

Output:

```text
<paste real validator output here, or "Not captured">
```

## Measured RPO and RTO

- Measured RPO: `<minutes>` minutes
- Measured RTO: `<minutes>` minutes

If either value exceeds the planned target, record the cause in the next section.

## Issues, Fixes, Follow-ups

- `<short bullet for each surprise, fix, or deferred item>`

## Final Result

`<PASS or FAIL>`
