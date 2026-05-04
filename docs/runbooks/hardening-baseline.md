# Debian Hardening Baseline

This runbook defines the first conservative host hardening pass for the lab Debian VMs.

The goal is to improve the host security posture without risking admin lockout or burying the lab under unnecessary complexity.

## Scope

Current first-pass controls:

- managed sudo access for the lab admin user
- explicit SSH daemon hardening via a drop-in config
- host firewall enabled with SSH allowed before enforcement
- `fail2ban` protecting SSH with a conservative jail

Current target:

- `ops-dev`

## Design Principles

- Keep one verified SSH session open while applying SSH or firewall changes.
- Prefer a second fresh SSH login test before closing the original session.
- Apply allow rules before enabling a default-deny firewall.
- Start with simple controls that matter in real environments.
- Keep the hardening baseline separate from the general package baseline.

## Current Policy

### Admin access

- admin user: `debian`
- admin group: `sudo`
- current sudo policy: passwordless sudo for the admin user

### SSH policy

- `PermitRootLogin no`
- `PasswordAuthentication no`
- `PubkeyAuthentication yes`
- `X11Forwarding no`
- `UseDNS no`

### Firewall policy

- UFW enabled
- default incoming: deny
- default outgoing: allow
- allowed inbound TCP ports:
  - `22`

### Login protection

- `fail2ban` enabled
- SSH jail backend: `systemd`
- max retry: `5`
- find time: `10m`
- ban time: `1h`
- ban action: `ufw`

## How To Apply

From the repo root:

```sh
cd ansible
ansible-playbook playbooks/hardening.yml
```

## Safe Validation Sequence

After applying the playbook:

1. Keep the original SSH session open.
2. Open a second SSH session from the admin workstation.
3. Confirm sudo still works.
4. Confirm SSH daemon settings match expectations.
5. Confirm firewall is enabled and still allows SSH.

Useful commands:

```sh
ssh debian@10.0.0.10
ssh debian@10.0.0.10 'sudo -n true && echo sudo-ok'
ssh debian@10.0.0.10 'sudo sshd -T | egrep "permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|usedns"'
ssh debian@10.0.0.10 'sudo ufw status verbose'
ssh debian@10.0.0.10 'sudo fail2ban-client status sshd'
```

## Rollback Notes

If SSH access is still available but a setting needs to be reverted:

```sh
cd ansible
ansible-playbook playbooks/hardening.yml -e ssh_hardening_x11_forwarding=yes
```

If a stronger rollback path is needed later, document explicit role-level rollback settings here before applying the baseline to staging or production.
