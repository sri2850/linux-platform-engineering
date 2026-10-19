# Phase 3: Service Management, System Initialization & Systemd

## Core Mental Models

### 1. Architecture of systemd

- **systemd (PID 1):** The root process supervisor and service manager. It coordinates dependencies asynchronously using a Directed Acyclic Graph (DAG).
- **systemctl:** The command-line interface used to inspect, start, stop, enable, and reload unit files.
- **journalctl:** The unified query tool for `systemd-journald`, which captures `stdout`, `stderr`, and syslog streams into indexed binary logs.

### 2. Unit File Layout (/etc/systemd/system/)

Custom system units are placed in `/etc/systemd/system/` and override vendor units in `/lib/systemd/system/`.

- **`[Unit]`**: Metadata and dependency management.
  - `After=`: Ensures the unit starts only after specified units are up.
  - `Wants=`: Soft dependency (non-blocking).
  - `Requires=`: Hard dependency (failure of dependency stops this service).
- **`[Service]`**: Process lifecycle, sandboxing, and execution.
  - `Type=simple`: The default model where `ExecStart` is the main process.
  - `User=` / `Group=`: Drops privileges to non-root service accounts.
  - `Restart=always`: Automatic crash supervision.
  - `RestartSec=`: Backoff delay before reviving a failed process.
  - `LimitNOFILE=`: Overrides process file descriptor limits independently of global system limits.
- **`[Install]`**: Boot target mapping.
  - `WantedBy=multi-user.target`: Creates a symlink in `/etc/systemd/system/multi-user.target.wants/` to enable startup on boot.

### 3. Process Sandboxing & cgroups v2 Integration

Modern systemd units enforce kernel namespaces and cgroups without external container tools:

- `MemoryMax=150M`: Enforces a hard resident memory ceiling (`memory.max`). Exceeding this triggers the cgroup OOM killer specifically for that unit.
- `CPUQuota=50%`: Limits execution time to 50% of a single CPU core via `cpu.max`.
- `ProtectSystem=strict`: Mounts `/usr`, `/boot`, and `/etc` as read-only for the service.
- `ProtectHome=true`: Makes `/root` and `/home` inaccessible to the process.
- `PrivateTmp=true`: Isolates `/tmp` into a private filesystem namespace.
- `NoNewPrivileges=true`: Disallows privilege escalation via setuid binaries.

### 4. Boot Analysis & Journal Queries

- Total Boot Time: `systemd-analyze`
- Slowest Unit Breakdown: `systemd-analyze blame`
- Critical Sequential Chain: `systemd-analyze critical-chain`
- Follow Unit Logs: `journalctl -u <unit> -f`
- Query Logs with Severity Filter: `journalctl -u <unit> -p err..alert`
- Vacuum Log Disk Usage: `journalctl --vacuum-size=200M`

---

## Lab Execution Guide

### 1. Provision and Enable Hardened Service

```bash
chmod +x scripts/01_deploy_hardened_service.sh
sudo ./scripts/01_deploy_hardened_service.sh
```

### 2. Test Self-Healing Recovery

```bash
chmod +x scripts/02_test_crash_recovery.sh
sudo ./scripts/02_test_crash_recovery.sh
```

### 3. Analyze Boot Performance

```bash
chmod +x scripts/03_boot_analysis.sh
./scripts/03_boot_analysis.sh
```


[ Client ]                                            [ Server ]
    │                                                     │  LISTEN
    │ ─── SYN ──────────────────────────────────────────> │  SYN_RECV
    │ <── SYN-ACK ─────────────────────────────────────── │
    │ ─── ACK ──────────────────────────────────────────> │  ESTABLISHED
    │                                                     │
    ▼                                                     ▼
              [ Data Exchange: ESTABLISHED ]
    │                                                     │
    │ ─── FIN ──────────────────────────────────────────> │  CLOSE_WAIT
    │ <── ACK ─────────────────────────────────────────── │
    │ <── FIN ─────────────────────────────────────────── │  LAST_ACK
    │ ─── ACK ──────────────────────────────────────────> │  CLOSED
    ▼                                                     ▼
TIME_WAIT (Client retains for 60s)
