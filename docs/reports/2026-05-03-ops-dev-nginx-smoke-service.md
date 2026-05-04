# ops-dev nginx Smoke Service Rollout Report

- Date: 2026-05-03
- Host: `ops-dev`
- Target IP: `10.0.0.10`
- Related Linear issues:
  - `RAP-100` Define capstone service stack and deployment shape
  - `RAP-96` Implement validation suite + report format
- Scope: deploy a small `nginx` service on `ops-dev`, expose `80/tcp`, and validate the host plus HTTP endpoint before and after the change

## Change Summary

Applied from the repo:

- `ansible/playbooks/hardening.yml`
- `ansible/playbooks/nginx-demo.yml`
- `scripts/validate-host.sh --http-url http://10.0.0.10/healthz`

Result:

- `ops-dev` now serves a simple Ansible-managed `nginx` page on port `80`
- UFW allows `22/tcp` and `80/tcp`
- `/healthz` returns `200 OK`

## Before Change

### nginx service status

Command:

```sh
ssh debian@10.0.0.10 'systemctl status nginx --no-pager || true'
```

Output:

```text
Unit nginx.service could not be found.
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

### Local HTTP check

Command:

```sh
ssh debian@10.0.0.10 'curl -I --max-time 5 http://127.0.0.1 || true'
```

Output:

```text
curl: (7) Failed to connect to 127.0.0.1 port 80 after 0 ms: Couldn't connect to server
```

## Implementation Notes

1. Add host-specific vars for `ops-dev` so the firewall can allow `80/tcp`.
2. Apply the hardening playbook again so UFW reflects the host's role.
3. Apply a dedicated `nginx` smoke-service playbook.
4. Validate service status, firewall state, and HTTP responses.
5. Save the commands and outputs here so the workflow is easy to repeat.

## After Change

### nginx service status

Command:

```sh
ssh debian@10.0.0.10 'systemctl status nginx --no-pager'
```

Output:

```text
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-05-03 20:09:11 EDT; 36s ago
       Docs: man:nginx(8)
    Process: 5402 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 5403 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 7367 ExecReload=/usr/sbin/nginx -g daemon on; master_process on; -s reload (code=exited, status=0/SUCCESS)
   Main PID: 5432 (nginx)
      Tasks: 3 (limit: 2314)
     Memory: 2.4M
        CPU: 17ms
     CGroup: /system.slice/nginx.service
             ├─5432 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─7368 "nginx: worker process"
             └─7369 "nginx: worker process"

May 03 20:09:11 ops-dev systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
May 03 20:09:11 ops-dev systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
May 03 20:09:37 ops-dev systemd[1]: Reloading nginx.service - A high performance web server and a reverse proxy server...
May 03 20:09:37 ops-dev nginx[7367]: 2026/05/03 20:09:37 [notice] 7367#7367: signal process started
May 03 20:09:37 ops-dev systemd[1]: Reloaded nginx.service - A high performance web server and a reverse proxy server.
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
80/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
80/tcp (v6)                ALLOW IN    Anywhere (v6)
```

### HTTP headers

Command:

```sh
curl -I --max-time 5 http://10.0.0.10
```

Output:

```text
HTTP/1.1 200 OK
Server: nginx/1.22.1
Date: Mon, 04 May 2026 00:09:47 GMT
Content-Type: text/html
Content-Length: 1253
Last-Modified: Mon, 04 May 2026 00:09:14 GMT
Connection: keep-alive
ETag: "69f7e3aa-4e5"
Accept-Ranges: bytes
```

### Health endpoint

Command:

```sh
curl --max-time 5 http://10.0.0.10/healthz
```

Output:

```text
ok
```

### Validator run

Command:

```sh
./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz
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
PASS  HTTP endpoint returns success

Summary: 10 passed, 0 failed
```

## Replication Notes

- Keep one SSH session open while reapplying firewall changes.
- If you later promote this to `ops-stage` or `ops-prod`, reuse the same report sections and only change host/IP values.
- The next natural step after this smoke service is to add a small FastAPI backend behind `nginx`, then extend validation with an app endpoint and database check.
