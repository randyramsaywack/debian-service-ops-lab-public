# ops-dev FastAPI + Frontend Rollout Report

- Date: 2026-05-03
- Host: `ops-dev`
- Target IP: `10.0.0.10`
- Related Linear issues:
  - `RAP-100` Define capstone service stack and deployment shape
  - `RAP-96` Implement validation suite + report format
- Scope: deploy a small FastAPI backend under `systemd`, serve a static frontend through `nginx`, proxy `/api` to the backend, and validate both host and app endpoints

## Change Summary

Applied from the repo:

- `ansible/playbooks/app-demo.yml`
- `scripts/validate-host.sh --http-url http://10.0.0.10/healthz --http-url http://10.0.0.10/api/healthz`

Expected result:

- `ops-lab-api.service` runs on `127.0.0.1:8000`
- `nginx` proxies `/api/*` to the FastAPI backend
- `http://10.0.0.10/` serves a small HTML/JS frontend
- `http://10.0.0.10/api/healthz` returns JSON health state
- `http://10.0.0.10/api/message` returns a small JSON payload from the backend

## Before Change

### App service status

Command:

```sh
ssh debian@10.0.0.10 'systemctl status ops-lab-api --no-pager || true'
```

Output:

```text
Unit ops-lab-api.service could not be found.
```

### API health endpoint

Command:

```sh
curl -i --max-time 5 http://10.0.0.10/api/healthz || true
```

Output:

```text
HTTP/1.1 404 Not Found
Server: nginx/1.22.1
Date: Mon, 04 May 2026 00:18:30 GMT
Content-Type: text/html
Content-Length: 153
Connection: keep-alive

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.22.1</center>
</body>
</html>
```

### API message endpoint

Command:

```sh
curl -i --max-time 5 http://10.0.0.10/api/message || true
```

Output:

```text
HTTP/1.1 404 Not Found
Server: nginx/1.22.1
Date: Mon, 04 May 2026 00:18:30 GMT
Content-Type: text/html
Content-Length: 153
Connection: keep-alive

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.22.1</center>
</body>
</html>
```

## Implementation Notes

1. Add a dedicated `app_demo` role for a tiny FastAPI backend.
2. Run the backend through `systemd` as `ops-lab-api.service`.
3. Keep the backend private on `127.0.0.1:8000`.
4. Update the `nginx` site so `/api/*` is reverse-proxied to the backend.
5. Replace the static smoke page with a small frontend that fetches API health and message data.
6. Extend validation to check both `/healthz` and `/api/healthz`.

## After Change

### App service status

Command:

```sh
ssh debian@10.0.0.10 'systemctl status ops-lab-api --no-pager'
```

Output:

```text
● ops-lab-api.service - Ops Lab FastAPI backend
     Loaded: loaded (/etc/systemd/system/ops-lab-api.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-05-03 20:20:08 EDT; 19s ago
   Main PID: 8309 (uvicorn)
      Tasks: 8 (limit: 2314)
     Memory: 32.7M
        CPU: 302ms
     CGroup: /system.slice/ops-lab-api.service
             └─8309 /opt/ops-lab-app/venv/bin/python3 /opt/ops-lab-app/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000

May 03 20:20:08 ops-dev systemd[1]: Started ops-lab-api.service - Ops Lab FastAPI backend.
May 03 20:20:09 ops-dev uvicorn[8309]: INFO:     Started server process [8309]
May 03 20:20:09 ops-dev uvicorn[8309]: INFO:     Waiting for application startup.
May 03 20:20:09 ops-dev uvicorn[8309]: INFO:     Application startup complete.
May 03 20:20:09 ops-dev uvicorn[8309]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
May 03 20:20:12 ops-dev uvicorn[8309]: INFO:     127.0.0.1:44372 - "GET /api/healthz HTTP/1.1" 200 OK
May 03 20:20:27 ops-dev uvicorn[8309]: INFO:     10.0.0.5:0 - "GET /api/healthz HTTP/1.1" 200 OK
May 03 20:20:27 ops-dev uvicorn[8309]: INFO:     10.0.0.5:0 - "GET /api/message HTTP/1.1" 200 OK
```

### API health endpoint

Command:

```sh
curl -i --max-time 5 http://10.0.0.10/api/healthz
```

Output:

```text
HTTP/1.1 200 OK
Server: nginx/1.22.1
Date: Mon, 04 May 2026 00:20:27 GMT
Content-Type: application/json
Content-Length: 15
Connection: keep-alive

{"status":"ok"}
```

### API message endpoint

Command:

```sh
curl -i --max-time 5 http://10.0.0.10/api/message
```

Output:

```text
HTTP/1.1 200 OK
Server: nginx/1.22.1
Date: Mon, 04 May 2026 00:20:27 GMT
Content-Type: application/json
Content-Length: 63
Connection: keep-alive

{"message":"Hello from the Debian Service Operations Lab API."}
```

### Combined validator run

Command:

```sh
./scripts/validate-host.sh debian@10.0.0.10 --http-url http://10.0.0.10/healthz --http-url http://10.0.0.10/api/healthz
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
PASS  HTTP endpoint returns success: http://10.0.0.10/healthz
PASS  HTTP endpoint returns success: http://10.0.0.10/api/healthz

Summary: 11 passed, 0 failed
```
