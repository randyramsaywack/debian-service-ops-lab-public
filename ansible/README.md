# Ansible

This directory will hold the Debian baseline rebuild path.

Current structure:

```text
ansible/
  ansible.cfg
  inventories/
    lab/
      hosts.yml
      group_vars/
  playbooks/
    baseline.yml
    hardening.yml
    patch.yml
    validate.yml
  roles/
    common/
    ssh/
    sudo/
    firewall/
    time_sync/
```

Implemented so far:

- `ansible.cfg` with repo-local defaults
- `inventories/lab/hosts.yml` with the current `ops-dev` target
- `inventories/lab/group_vars/all.yml` for shared baseline variables
- `playbooks/baseline.yml` as the first Debian 12 baseline playbook
- `playbooks/hardening.yml` as the first hardening playbook
- `playbooks/nginx-demo.yml` as the first service rollout playbook
- `playbooks/app-demo.yml` as the first proxied application stack playbook
- `roles/common/` as the initial baseline role
- `roles/ssh/`, `roles/sudo/`, `roles/firewall/`, and `roles/fail2ban/` as the first hardening roles
- `roles/nginx_demo/` as the first application-facing service role
- `roles/app_demo/` as the first managed backend application role

Current target:

- `ops-dev` at `10.0.0.10`
- SSH user: `debian`

Run the first baseline from this directory:

```sh
ansible-playbook playbooks/baseline.yml
ansible-playbook playbooks/hardening.yml
ansible-playbook playbooks/nginx-demo.yml
ansible-playbook playbooks/app-demo.yml
```

Useful checks:

```sh
ansible all -m ping
ansible-inventory --graph
```
