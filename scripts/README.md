# Scripts

Local helper scripts will live here.

Available scripts:

- `new-debian-vm.sh`: clone a Debian VM from the Proxmox cloud-init template, resize the disk to a final size, apply common cloud-init settings, and optionally start it
- `validate-host.sh`: run a lightweight remote validation against a Debian host and print a pass/fail summary for SSH, sudo, system state, UFW, `fail2ban`, `qemu-guest-agent`, reboot requirement, and optional systemd units and HTTP endpoints
- `patch-report.sh`: collect a live patching/validation snapshot from a host and write it to a markdown report under `docs/reports/`

Planned next scripts:

- `collect-service-state.sh`

## `new-debian-vm.sh`

This helper is intended to run on a Proxmox node after the Debian 12 template exists.

It always creates full clones with `qm clone --full 1`.

Default behavior:

- clones from template `9002`
- resizes `scsi0` to a final size of `20G`
- sets `ciuser` to `debian`
- configures `ipconfig0` for DHCP
- injects both `/root/.ssh/admin-bootstrap.pub` and `/root/bin/admin-workstation.pub`
- fails fast if either default key file is missing
- adds any extra `--sshkey` file you pass on top of those defaults

Athena deployment commands:

```sh
ssh root@proxmox-a.example.internal 'mkdir -p /root/bin'
scp /Users/example-user/Documents/Codex/debian-service-ops-lab/scripts/new-debian-vm.sh \
  root@proxmox-a.example.internal:/root/bin/new-debian-vm.sh
ssh root@proxmox-a.example.internal \
  'chmod +x /root/bin/new-debian-vm.sh && ls -l /root/bin/new-debian-vm.sh /root/bin/admin-workstation.pub /root/.ssh/admin-bootstrap.pub'
```

Normal Athena usage:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9101 ops-dev --start'
```

Troubleshooting commands from the successful `ops-dev` validation:

```sh
ping -c 2 10.0.0.11
ssh-keygen -R 10.0.0.11
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.11 'hostnamectl --static && systemctl is-system-running'
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.11 'cloud-init status --wait && systemctl is-active qemu-guest-agent && ip -brief addr show && df -h /'
```

Template identity troubleshooting:

```sh
ssh root@proxmox-a.example.internal 'for id in 9101 9102; do echo "VMID $id"; qm config "$id" | sed -n "/^name:/p;/^net0:/p"; qm guest exec "$id" -- /bin/cat /etc/machine-id; echo; done'
```

If the MAC addresses differ but the machine IDs match, the template needs to be sanitized before cloning:

```sh
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
cloud-init clean
sync
shutdown -h now
```

Example:

```sh
./scripts/new-debian-vm.sh 9101 ops-dev --start
```

Static IP example:

```sh
./scripts/new-debian-vm.sh 9102 ops-stage \
  --final-size 32G \
  --cores 4 \
  --memory 4096 \
  --ip 10.0.0.20/24 \
  --gw 10.0.0.1 \
  --sshkey /root/ops-lab-sshkey.pub \
  --start
```

## `validate-host.sh`

This helper runs the current baseline safety checks over SSH and exits non-zero if any check fails.

Current checks:

- SSH connectivity
- passwordless `sudo`
- `systemctl is-system-running` returns `running` or `degraded`
- `systemctl --failed` returns no failed units
- `qemu-guest-agent` is active
- UFW is active and still allows `22/tcp`
- `fail2ban` exposes the `sshd` jail
- no reboot is pending
- optional repeated systemd unit checks when you pass one or more `--service` flags
- optional repeated HTTP endpoint checks when you pass one or more `--http-url` flags

Example:

```sh
./scripts/validate-host.sh debian@10.0.0.10
./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz
./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz --http-url http://10.0.0.10/api/healthz
./scripts/validate-host.sh debian@10.0.0.10 --service nginx --service postgresql
```

## `patch-report.sh`

This helper captures the current patching snapshot and writes a markdown report with:

- upgradable package output
- held package output
- system state
- failed units
- UFW status
- `fail2ban` status
- reboot requirement
- optional HTTP endpoint checks
- the latest `validate-host.sh` result with a final `PASS` or `FAIL`

Example:

```sh
./scripts/patch-report.sh debian@10.0.0.10 \
  docs/reports/2026-05-03-ops-dev-patching.md \
  --http-url http://10.0.0.10/healthz \
  --http-url http://10.0.0.10/api/healthz
```
