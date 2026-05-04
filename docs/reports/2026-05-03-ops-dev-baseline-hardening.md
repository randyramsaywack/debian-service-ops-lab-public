# ops-dev Baseline + Hardening Validation Report

- Date: 2026-05-03
- Host: `ops-dev`
- Target IP: `10.0.0.10`
- Scope: baseline package state, service health, firewall status, `fail2ban`, and reboot requirement
- Status: post-change validation captured from the live host on 2026-05-03; pre-change output was not retained

## Change Summary

Applied or validated against the current repo baseline:

- `ansible/playbooks/baseline.yml`
- `ansible/playbooks/hardening.yml`
- SSH hardening drop-in
- UFW enablement with SSH allowed
- `fail2ban` SSH jail

## Before Change

Pre-change evidence was not captured at the time the baseline and hardening playbooks were first applied. The next staged patch or hardening change should record the same commands before maintenance begins.

### Apt state

Command:

```sh
ssh debian@10.0.0.10 'apt list --upgradable'
```

Output:

```text
Not retained
```

### Failed systemd units

Command:

```sh
ssh debian@10.0.0.10 'systemctl --failed'
```

Output:

```text
Not retained
```

### Firewall status

Command:

```sh
ssh debian@10.0.0.10 'sudo ufw status verbose'
```

Output:

```text
Not retained
```

### fail2ban status

Command:

```sh
ssh debian@10.0.0.10 'sudo fail2ban-client status sshd'
```

Output:

```text
Not retained
```

### Reboot requirement

Command:

```sh
ssh debian@10.0.0.10 'if [ -f /var/run/reboot-required ]; then cat /var/run/reboot-required; else echo no-reboot-required; fi'
```

Output:

```text
Not retained
```

## After Change

### Apt state

Command:

```sh
ssh debian@10.0.0.10 'apt list --upgradable'
```

Output:

```text
WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Listing...
```

### Failed systemd units

Command:

```sh
ssh debian@10.0.0.10 'systemctl --failed'
```

Output:

```text
  UNIT LOAD ACTIVE SUB DESCRIPTION
0 loaded units listed.
```

### Firewall status

Command:

```sh
ssh debian@10.0.0.10 'sudo ufw status verbose'
```

Output:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

### fail2ban status

Command:

```sh
ssh debian@10.0.0.10 'sudo fail2ban-client status sshd'
```

Output:

```text
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed: 0
|  `- Journal matches: _SYSTEMD_UNIT=sshd.service + _COMM=sshd
`- Actions
   |- Currently banned: 0
   |- Total banned: 0
   `- Banned IP list:
```

### Reboot requirement

Command:

```sh
ssh debian@10.0.0.10 'if [ -f /var/run/reboot-required ]; then cat /var/run/reboot-required; else echo no-reboot-required; fi'
```

Output:

```text
no-reboot-required
```

## Validator Run

Command:

```sh
./scripts/validate-host.sh debian@10.0.0.10
```

Output:

```text
Validating host: debian@10.0.0.10

PASS  SSH connectivity
PASS  sudo available without password prompt
PASS  system state is running or degraded
PASS  no failed systemd units
PASS  qemu-guest-agent service is active
PASS  ufw is active
PASS  ufw allows SSH on tcp/22
PASS  fail2ban sshd jail is available
PASS  reboot is not required

Summary: 9 passed, 0 failed
```

## Assessment

- Result: post-change validation passed on all checks listed above
- Gap: pre-change evidence is still missing for this first hardening pass
- Next improvement: capture the same command set before and after the next staged patch cycle so this report format becomes a true maintenance delta record
