# Proxmox Cloud-Init Template (Debian 12 Bookworm)

This runbook creates a Debian 12 template VM in Proxmox VE that we can clone into `ops-dev`, `ops-stage`, `ops-prod`, etc.

Environment assumptions for this lab:

- Proxmox bridge: `vmbr0`
- Primary VM storage: `proxmox-zfs`
- IP addressing: DHCP (DNS handled elsewhere, e.g. Pi-hole)

## Why We Start With A Template

We want repeatability.

- A template makes VM creation fast and consistent.
- Cloud-init lets us inject host-specific values (hostname, SSH key, optional user) at clone time.
- This keeps "snowflake" differences out of the base image, and puts intentional differences into documented settings.

## What We Are Trying To Prove

At the end, we should be able to clone a VM and confirm:

- the hostname is correct
- we can SSH in using our key (no password)
- the VM is reachable on the network via DHCP
- Proxmox can see guest info via `qemu-guest-agent` (recommended)

## Image Choice (Generic vs Genericcloud)

Debian provides two relevant cloud images:

- `generic`: standard Debian kernel (recommended for maximum compatibility)
- `genericcloud`: "cloud" kernel with many drivers disabled (targets large cloud platforms)

For Proxmox homelab use, prefer `generic` unless you have a reason to use `genericcloud`.

## Step 0: Pick A Template VMID And Name

Pick a VMID that will not collide with normal VMs. Common patterns:

- `9000` for templates
- `9xxx` range reserved for templates

If Athena and Zeus are part of the same Proxmox cluster, VMIDs must be unique cluster-wide. In that case, use different VMIDs for the Athena template and the Zeus template (for example, `9002` on Athena and `9003` on Zeus).

Example used below (cluster-wide unique):

- Athena template VMID: `9002`
- Zeus template VMID: `9003`
- Template name pattern:
  - `tpl-debian12-bookworm-athena`
  - `tpl-debian12-bookworm-zeus`

This runbook shows commands using the Athena example (`9002`). If you are building the Zeus template, substitute `9003` and the `-zeus` name.

## Step 1: Download The Debian 12 Cloud Image (On The Proxmox Node)

On the Proxmox node (Athena or Zeus), download the Debian 12 Bookworm cloud image:

```sh
mkdir -p /var/lib/vz/template/cloud
cd /var/lib/vz/template/cloud

# Generic (recommended for Proxmox)
wget -O debian-12-generic-amd64.qcow2 \
  https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# Alternative: genericcloud
# wget -O debian-12-genericcloud-amd64.qcow2 \
#   https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

Note: if you already have the Debian 12 image on both nodes, you can skip this step.

## Step 2 (Recommended): Install qemu-guest-agent Into The Image

Debian cloud images intentionally do not pre-install `qemu-guest-agent`, because it assumes a trust relationship between guest and host. For Proxmox, we typically want it so Proxmox can read IP information and interact cleanly with the guest.

On the Proxmox node, install the tooling and inject the package into the qcow2.

Recommendation: keep the original downloaded image pristine, and customize a copy so you can re-run the process later without re-downloading.

```sh
apt update
apt install -y libguestfs-tools

cp -a /var/lib/vz/template/cloud/debian-12-generic-amd64.qcow2 \
  /var/lib/vz/template/cloud/debian-12-generic-amd64-qga.qcow2

virt-customize -a /var/lib/vz/template/cloud/debian-12-generic-amd64-qga.qcow2 \
  --install qemu-guest-agent \
  --run-command 'systemctl enable qemu-guest-agent'
```

If you used the `genericcloud` image, adjust the filename accordingly.

## Step 3: Create The Base VM Shell In Proxmox

Create the VM "shell" (no OS installed yet, we will import the disk next):

```sh
qm create 9002 \
  --name tpl-debian12-bookworm-athena \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0
```

Recommended hardware settings for cloud images:

```sh
qm set 9002 --scsihw virtio-scsi-single
qm set 9002 --serial0 socket --vga serial0
qm set 9002 --agent enabled=1
```

Notes on why:

- VirtIO networking + VirtIO SCSI are the "normal" efficient paravirtual devices for KVM.
- Serial console often "just works" better with cloud images and Proxmox.
- Guest agent enables richer VM integration in Proxmox.

## Step 4: Import The Cloud Image Disk Onto ZFS Storage

Attach the (customized) qcow2 into Proxmox storage (`proxmox-zfs`) using `import-from`:

```sh
qm set 9002 --scsi0 proxmox-zfs:0,import-from=/var/lib/vz/template/cloud/debian-12-generic-amd64-qga.qcow2,discard=on
```

If you prefer, you can also import first and attach later, but `import-from` is usually simpler:

```sh
qm importdisk 9002 /var/lib/vz/template/cloud/debian-12-generic-amd64-qga.qcow2 proxmox-zfs
qm config 9002
```

If you use `qm importdisk`, attach the imported disk as `scsi0` before setting boot order. A common mistake is trying to set `--boot order=scsi0` before the VM actually has a `scsi0` device.

Example:

```sh
qm set 9002 --scsi0 proxmox-zfs:vm-9002-disk-0,discard=on
qm set 9002 --boot order=scsi0
```

## Step 5: Add The Cloud-Init Drive

Cloud-init data is provided via a special disk:

```sh
qm set 9002 --ide2 proxmox-zfs:cloudinit
```

## Step 6: Set Template Cloud-Init Defaults

Set the baseline values we want every clone to inherit:

```sh
qm set 9002 --ciuser debian
qm set 9002 --ipconfig0 ip=dhcp
qm set 9002 --sshkey /root/ops-lab-sshkey.pub
qm set 9002 --boot order=scsi0
```

Notes:

- `--ipconfig0 ip=dhcp` is still useful for DHCP-based guests. It makes the intended networking mode explicit to cloud-init.
- Keep SSH public keys on the Proxmox node or your admin workstation, not in this repo.
- If you prefer to inject SSH keys per clone instead of on the template, skip `--sshkey` here and set it on each cloned VM.

## Step 6.5: Sanitize Guest Identity Before Templating

Before converting the VM into a template, clear the machine identity so each clone generates its own unique identity on first boot.

Run this inside the prepared Debian guest before shutting it down for templating:

```sh
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
cloud-init clean
sync
shutdown -h now
```

Why this matters:

- we observed two Athena clones with different MAC addresses but the same `/etc/machine-id`
- both guests then presented the same DHCP client identity and received the same IPv4 lease
- clearing the machine ID before templating prevents clones from inheriting that identity

Observed collision details from Athena:

- `ops-dev` (`9101`) and `some-vm-2` (`9102`) both reported `/etc/machine-id` as `0d40967d261ea1f50e19c0e0b26d4019`
- both guests reported `10.0.0.11` even though their `net0` MAC addresses were different

## Athena Helper Deployment

Current Athena-specific helper/key layout:

- clone helper script: `/root/bin/new-debian-vm.sh`
- Athena root public key: `/root/.ssh/admin-bootstrap.pub`
- MacBook public key copy on Athena: `/root/bin/admin-workstation.pub`

The current helper merges both public keys and injects them into each new clone by default.

Copy or refresh the helper script on Athena from the admin workstation:

```sh
ssh root@proxmox-a.example.internal 'mkdir -p /root/bin'
scp /Users/example-user/Documents/Codex/debian-service-ops-lab/scripts/new-debian-vm.sh \
  root@proxmox-a.example.internal:/root/bin/new-debian-vm.sh
ssh root@proxmox-a.example.internal \
  'chmod +x /root/bin/new-debian-vm.sh && ls -l /root/bin/new-debian-vm.sh /root/bin/admin-workstation.pub /root/.ssh/admin-bootstrap.pub'
```

Why this matters:

- it confirms the helper script is present and executable
- it confirms the MacBook public key copy exists where the helper expects it
- it confirms Athena's root public key exists where the helper expects it

If clone SSH access fails later, this is the first command sequence to rerun.

## Step 7: Convert The VM To A Template

```sh
qm template 9002
```

At this point the template is done.

## Step 8: Clone The Template Into ops-dev

Pick a new VMID for `ops-dev` (example: `101`) and clone:

```sh
qm clone 9002 101 --name ops-dev
```

Now configure cloud-init per-VM values.

### Hostname

```sh
qm set 101 --name ops-dev
```

### SSH Key

The current Athena helper handles key injection automatically using both default public keys:

```sh
/root/.ssh/admin-bootstrap.pub
/root/bin/admin-workstation.pub
```

If you are cloning manually without the helper, you can still inject a specific key file with:

```sh
qm set 101 --sshkey /root/bin/admin-workstation.pub
```

Note: this repo should stay shareable, so we do not commit personal SSH keys here. Keep the key material on the Proxmox node or your admin workstation.

### Cloud-init User

Debian cloud images commonly default to a `debian` user. You can keep that, or set a consistent lab admin user.

Example (choose one):

```sh
# Keep Debian default
# qm set 101 --ciuser debian

# Or set a lab admin user
qm set 101 --ciuser opsadmin
```

### Networking (DHCP)

Since we are using DHCP, set the cloud-init network mode explicitly:

```sh
qm set 101 --ipconfig0 ip=dhcp
```

The VM should then acquire a lease automatically on `vmbr0`.

### Right-Size The Clone Disk

Best practice for this lab is to keep the template disk small and resize each clone to its intended final capacity.

Example: the template disk is `3G`, so add `17G` to reach a final size of `20G`:

```sh
qm resize 101 scsi0 +17G
```

If you prefer absolute sizing, `qm resize` also accepts a final size. That is often easiest to read in automation:

```sh
qm resize 101 scsi0 20G
```

### Boot The VM

```sh
qm start 101
```

### Athena Helper Shortcut

For Athena, the normal path is now to run the helper instead of the manual clone sequence:

```sh
ssh root@proxmox-a.example.internal '/root/bin/new-debian-vm.sh 9101 ops-dev --start'
```

This will:

- create a full clone from template `9002`
- resize `scsi0` to `20G`
- set `ciuser=debian`
- set `ipconfig0=dhcp`
- inject both `/root/.ssh/admin-bootstrap.pub` and `/root/bin/admin-workstation.pub`
- start the VM

## Verification Checklist (Don't Skip This)

From Proxmox:

- Proxmox UI shows the VM is running.
- "Cloud-Init" panel shows the SSH key and user you set.
- Guest agent status becomes healthy (may take a minute after first boot).

From your admin workstation:

- DNS resolves (Pi-hole) or you can find the DHCP lease in your router/Pi-hole.
- SSH works using your key:

```sh
ssh opsadmin@ops-dev.example.internal
```

Athena-based validation and troubleshooting commands used successfully for `ops-dev`:

```sh
ping -c 2 10.0.0.11
ssh-keygen -R 10.0.0.11
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.11 'hostnamectl --static && systemctl is-system-running'
ssh -o StrictHostKeyChecking=accept-new debian@10.0.0.11 'cloud-init status --wait && systemctl is-active qemu-guest-agent && ip -brief addr show && df -h /'
```

Notes:

- if a DHCP address is reused by a fresh clone, `known_hosts` may contain a stale host key for that IP
- `ssh-keygen -R 10.0.0.11` is the first fix for that case
- after the stale entry is removed, reconnect with `StrictHostKeyChecking=accept-new`

For template identity validation, compare machine IDs across two fresh clones:

```sh
ssh root@proxmox-a.example.internal 'for id in 9101 9102; do echo "VMID $id"; qm guest exec "$id" -- /bin/cat /etc/machine-id; echo; done'
```

You want different `out-data` values for each clone. If two clones report the same machine ID, do not trust DHCP uniqueness until the template is fixed.

Inside the VM:

```sh
hostnamectl
systemctl status qemu-guest-agent
cloud-init status --wait
ip -brief addr show
df -h /
```

## Validated Athena Example

Validated on `2026-05-03` against the Athena template (`9002`) using a test clone:

- test clone hostname: `debian12-test`
- observed IPv4 address: `10.0.0.11`
- SSH login succeeded as `debian`
- `cloud-init status --wait` returned `done`
- `qemu-guest-agent` was active
- DHCP, DNS, and outbound network access all worked

This gives us a known-good baseline before we create the named lab hosts such as `ops-dev`.

## Common Pitfalls

- "Guest agent not running": the `qemu-guest-agent` package is missing or the service is disabled.
- Wrong disk attachment: if the imported disk isn't attached as `scsi0`, the VM may not boot as expected.
- SSH key not applied: ensure you set `--sshkey` on the cloned VMID (not only the template).
- Cloud-init didn't re-run: cloud-init runs on first boot; if you are iterating, rebuild a fresh clone or clean cloud-init state in the VM.
- SSH host key mismatch on reused IPs: remove the stale key with `ssh-keygen -R <ip>` and reconnect.
- Different MAC, same IP on multiple clones: check `/etc/machine-id` in each guest. If they match, rebuild the template after clearing `/etc/machine-id` and `/var/lib/dbus/machine-id`.
