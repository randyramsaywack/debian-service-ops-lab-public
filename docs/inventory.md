# Lab Inventory

Last updated: 2026-05-03

This file tracks only the dedicated Debian service operations lab hosts. Keep broader private homelab inventory in the separate `homelab` repo.

| Role | Hostname | IP address | Proxmox node | VMID | Status | Notes |
|------|----------|------------|--------------|------|--------|-------|
| Dev service VM | `ops-dev` | `10.0.0.10` | `proxmox-a.example.internal` | `9101` | Running | Recreated from Athena template `9002`; validated over SSH with cloud-init, unique machine-id, qemu-guest-agent healthy, nginx on `80/tcp`, and FastAPI backend proxied through `/api` |
| Staging service VM | `ops-stage.example.internal` | TBD | TBD | TBD | Planned | Production-like upgrade testing |
| Production service VM | `ops-prod.example.internal` | TBD | TBD | TBD | Planned | Portfolio service target |
| Monitoring VM | `ops-monitor.example.internal` | TBD | TBD | TBD | Planned | Metrics, alerts, dashboards |
| Logging VM | `ops-log.example.internal` | TBD | TBD | TBD | Planned | Central logs and audit trail |
| Backup target | `ops-backup.example.internal` or NAS path | TBD | TBD | TBD | Planned | Off-host backup and restore target |
