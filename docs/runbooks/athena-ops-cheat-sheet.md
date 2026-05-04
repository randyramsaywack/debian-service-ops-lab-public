# Athena Ops Cheat Sheet

This is a practice-first command reference for the current Debian operations lab workflow on `proxmox-a.example.internal`.

Use this when you want to rebuild the template, create a clone, validate the guest, and run the current Ansible baseline and hardening playbooks without hunting through multiple documents.

## Assumptions

- Proxmox node: `proxmox-a.example.internal`
- Template VMID: `9002`
- Template name: `tpl-debian12-bookworm-athena`
- Storage: `proxmox-zfs`
- Bridge: `vmbr0`
- Current dev VM: `ops-dev`
- Current `ops-dev` IP: `10.0.0.10`
- Repo path on admin workstation:

```sh
/Users/example-user/Documents/Codex/debian-service-ops-lab
```

## 1. Basic Proxmox Checks

List VMs:

```sh
ssh root@proxmox-a.example.internal 'qm list'
```

Inspect a VM config:

```sh
ssh root@proxmox-a.example.internal 'qm config 9002'
ssh root@proxmox-a.example.internal 'qm config 9101'
```

Check storage:

```sh
ssh root@proxmox-a.example.internal 'pvesm status'
```

List downloaded cloud images:

```sh
ssh root@proxmox-a.example.internal 'ls -lah /var/lib/vz/template/cloud'
```

## 2. Refresh the Athena Clone Helper

Copy the current helper script to Athena:

```sh
ssh root@proxmox-a.example.internal 'mkdir -p /root/bin'
scp /Users/example-user/Documents/Codex/debian-service-ops-lab/scripts/new-debian-vm.sh \
  root@proxmox-a.example.internal:/root/bin/new-debian-vm.sh
ssh root@proxmox-a.example.internal \
  'chmod +x /root/bin/new-debian-vm.sh && ls -l /root/bin/new-debian-vm.sh /root/bin/admin-workstation.pub /root/.ssh/admin-bootstrap.pub'
```

What this helper currently does:

- creates a full clone with `qm clone --full 1`
- clones from template `9002`
- resizes the root disk to `20G`
- sets `ciuser=debian`
- sets `ipconfig0=dhcp`
- injects both `/root/.ssh/admin-bootstrap.pub` and `/root/bin/admin-workstation.pub`

## 3. Create a New VM from the Template

Create and start a new clone:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9101 ops-dev --start'
```

Create a larger VM:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9102 ops-stage --final-size 32G --cores 4 --memory 4096 --start'
```

Create a VM with a static IP:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9103 ops-prod --ip 10.0.0.20/24 --gw 10.0.0.1 --start'
```

## 4. Validate a Fresh Clone

Ping the host:

```sh
ping -c 2 10.0.0.10
```

SSH in:

```sh
ssh debian@10.0.0.10
```

One-shot health checks:

```sh
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.10 'hostnamectl --static && systemctl is-system-running'
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.10 'cloud-init status --wait && systemctl is-active qemu-guest-agent && ip -brief addr show && df -h /'
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.10 'cat /etc/machine-id'
```

## 5. Fix Stale SSH Host Keys on Reused DHCP IPs

If a DHCP address gets reused by a new clone, your admin workstation may have an old SSH host key cached.

Remove the stale key:

```sh
ssh-keygen -R 10.0.0.10
```

Reconnect and accept the new host key:

```sh
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.10
```

## 6. Diagnose Duplicate DHCP Leases

If two guests get the same IPv4 address, compare VM names, MACs, and machine IDs:

```sh
ssh root@proxmox-a.example.internal 'for id in 9101 9102; do echo "VMID $id"; qm config "$id" | sed -n "/^name:/p;/^net0:/p"; qm guest exec "$id" -- /bin/cat /etc/machine-id; echo; done'
```

If the MAC addresses differ but the machine IDs match, the template identity was not sanitized before templating.

## 7. Rebuild the Template

Create the base VM shell:

```sh
ssh root@proxmox-a.example.internal '
qm create 9002 \
  --name tpl-debian12-bookworm-athena \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0
qm set 9002 --scsihw virtio-scsi-single
qm set 9002 --serial0 socket --vga serial0
qm set 9002 --agent enabled=1
'
```

Import the Debian 12 QGA image and add cloud-init:

```sh
ssh root@proxmox-a.example.internal '
qm set 9002 --scsi0 proxmox-zfs:0,import-from=/var/lib/vz/template/cloud/debian-12-generic-amd64-qga.qcow2,discard=on
qm set 9002 --ide2 proxmox-zfs:cloudinit
qm set 9002 --ciuser debian
qm set 9002 --ipconfig0 ip=dhcp
qm set 9002 --boot order=scsi0
qm config 9002
'
```

Start the VM and wait for the guest agent:

```sh
ssh root@proxmox-a.example.internal '
qm start 9002
for i in $(seq 1 30); do
  if qm guest cmd 9002 ping >/dev/null 2>&1; then
    echo guest-agent-ready
    break
  fi
  sleep 2
done
'
```

Sanitize identity before templating:

```sh
ssh root@proxmox-a.example.internal '
qm guest exec 9002 -- /bin/sh -lc "truncate -s 0 /etc/machine-id && rm -f /var/lib/dbus/machine-id && cloud-init clean && sync && shutdown -h now"
'
```

Convert to template after shutdown:

```sh
ssh root@proxmox-a.example.internal '
qm template 9002
qm config 9002
'
```

## 8. Validate the Rebuilt Template with Two Test Clones

Create two disposable validation clones:

```sh
ssh root@proxmox-a.example.internal '
/root/bin/new-debian-vm.sh 9198 tpl-verify-a --start
/root/bin/new-debian-vm.sh 9199 tpl-verify-b --start
'
```

Compare machine IDs and IPs:

```sh
ssh root@proxmox-a.example.internal '
for id in 9198 9199; do
  echo "VMID $id"
  qm config "$id" | sed -n "/^name:/p;/^net0:/p"
  qm guest exec "$id" -- /bin/cat /etc/machine-id
  qm guest cmd "$id" network-get-interfaces | sed -n "1,220p"
  echo
done
'
```

Destroy the test clones:

```sh
ssh root@proxmox-a.example.internal '
qm stop 9198 || true
qm stop 9199 || true
sleep 2
qm destroy 9198 --destroy-unreferenced-disks 1 --purge 1 || true
qm destroy 9199 --destroy-unreferenced-disks 1 --purge 1 || true
qm list
'
```

## 9. Ansible Baseline

Move into the Ansible directory:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab/ansible
```

Check inventory:

```sh
ansible-inventory --graph
ansible-inventory --host ops-dev
```

Check connectivity:

```sh
ansible all -m ping
```

Apply the baseline playbook:

```sh
ansible-playbook playbooks/baseline.yml
```

Optional checks:

```sh
ansible-playbook playbooks/baseline.yml --syntax-check
ansible-playbook playbooks/baseline.yml --check
```

## 10. Ansible Hardening

Apply the hardening playbook:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab/ansible
ansible-playbook playbooks/hardening.yml
```

Validate after hardening:

```sh
ssh debian@10.0.0.10 'sudo -n true && echo sudo-ok'
ssh debian@10.0.0.10 'sudo sshd -T | egrep "permitrootlogin|passwordauthentication|pubkeyauthentication|x11forwarding|usedns"'
ssh debian@10.0.0.10 'sudo ufw status verbose'
ssh debian@10.0.0.10 'sudo fail2ban-client status sshd'
ansible all -m ping
```

## 11. Deploy the nginx Smoke Service on ops-dev

Update the repo first so Athena/workstation docs and playbooks match:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab
git pull
```

Reapply hardening so `ops-dev` picks up `80/tcp` in UFW:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab/ansible
ansible-playbook playbooks/hardening.yml
```

Deploy the nginx smoke service:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab/ansible
ansible-playbook playbooks/nginx-demo.yml
```

Validate the service manually:

```sh
ssh debian@10.0.0.10 'systemctl status nginx --no-pager'
ssh debian@10.0.0.10 'sudo ufw status verbose'
curl -I --max-time 5 http://10.0.0.10
curl --max-time 5 http://10.0.0.10/healthz
```

Run the combined host + HTTP validator:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab
./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz
```

## 12. Deploy the FastAPI Demo Backend + Frontend

Deploy the backend and refreshed frontend:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab/ansible
ansible-playbook playbooks/app-demo.yml
```

Validate the backend service and proxied endpoints:

```sh
ssh debian@10.0.0.10 'systemctl status ops-lab-api --no-pager'
curl -i --max-time 5 http://10.0.0.10/api/healthz
curl -i --max-time 5 http://10.0.0.10/api/message
curl -I --max-time 5 http://10.0.0.10
```

Run the combined host + frontend/backend validator:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab
./scripts/validate-host.sh debian@10.0.0.10 \
  --http-url http://10.0.0.10/healthz \
  --http-url http://10.0.0.10/api/healthz
```

## 13. Useful Ad Hoc Commands

Check guest IPs through Proxmox guest agent:

```sh
ssh root@proxmox-a.example.internal 'qm guest cmd 9101 network-get-interfaces | sed -n "1,220p"'
```

Check machine ID through Proxmox guest exec:

```sh
ssh root@proxmox-a.example.internal 'qm guest exec 9101 -- /bin/cat /etc/machine-id'
```

Run simple ad hoc checks through Ansible:

```sh
cd /Users/example-user/Documents/Codex/debian-service-ops-lab/ansible
ansible ops-dev -a 'hostnamectl --static'
ansible ops-dev -a 'systemctl is-active qemu-guest-agent'
ansible ops-dev -a 'ip -brief addr show eth0'
```

## 14. Best Practice Reminders

- Keep one SSH session open while applying firewall or SSH changes.
- Open a second fresh SSH session before closing the original one.
- Allow SSH in the firewall before enabling default deny.
- Clear `/etc/machine-id` before turning a prepared guest into a template.
- Validate a rebuilt template with at least two fresh clones before trusting it.
- Practice on `ops-dev` first, then promote the same documented process to later hosts.
