+====================================================================================================+
|                                        USERSPACE RUNTIME                                           |
+====================================================================================================+
|                                                                                                    |
|   [ systemd (PID 1) ] (Phase 3)                                                                    |
|     ├── cgroups Control Slices (/sys/fs/cgroup/system.slice/)                                      |
|     │     ├── MemoryMax = 150M  ─────────┐ (Triggers OOM if breached)                              |
|     │     └── CPUQuota  = 50%   ─────────┼─────────────────────────┐                               |
|     └── Namespace Sandboxing             │                         │                               |
|           ├── PrivateTmp = true          │                         │                               |
|           └── ProtectSystem = strict     │                         │                               |
|                                          ▼                         ▼                               |
|   [ Application Process (e.g., Python / Nginx) ]              [ Network Client / Curl ]            |
|     ├── Memory: VSS -> PSS -> RSS (Phase 1)                        │                               |
|     ├── Limits: LimitNOFILE (Max Open FDs)                         ▼                               |
|     │                                                [ Socket API: socket(), bind(), connect() ]   |
|     ├── File Descriptors (/proc/<PID>/fd/) (Phase 1)               │                               |
|     │     ├── FD 0, 1, 2 (stdin, stdout -> journald)               │                               |
|     │     ├── FD 3 (Log File Handle) ──────────┐                   │                               |
|     │     └── FD 4 (TCP Socket Descriptor) ────┼────────┐          │                               |
+=====│==========================================│========│==========│===============================+
|     │           LINUX KERNEL SUBSYSTEMS        │        │          │                               |
+=====│==========================================│========│==========│===============================+
|     │                                          │        │          │                               |
|  [ VFS & Storage Engine ] (Phase 2)            │        │          ▼                               |
|     ├── Inode Table (Metadata: df -i) <────────┘        │  [ TCP/IP Network Stack ] (Phase 4)      |
|     │     └── Link Count (NLINK = 0 vs >0)              │     ├── Local Stub (127.0.0.53:53)       |
|     ├── Data Blocks (Storage Payload: df -h)            │     │     └── /etc/resolv.conf           |
|     └── Logical Volume Manager (LVM)                    │     ├── Socket Queues & States           |
|           └── LV -> VG -> PV -> SCSI (/dev/sda)         │     │     └── LISTEN, SYN_RECV,          |
|                                                         │     │         ESTABLISHED, TIME_WAIT     |
|                                                         │     │     └── Backlogs (somaxconn)       |
|  [ Process & Memory Scheduler ] (Phase 1)               │     │                                    |
|     ├── Run Queue: Runnable (R) (us/sy)                 │     ▼                                    |
|     ├── Wait Queue: Blocked on I/O (D-State) (b/wa)     │  [ Netfilter Hook Chains ] (Phase 4)     |
|     ├── OOM Subsystem: checks oom_score & terminates    │     ├── PREROUTING (NAT)                 |
|     └── Swap Subsystem: Pages to disk (si/so thrashing) │     ├── INPUT / OUTPUT (DROP vs REJECT)  |
|                                                         │     └── POSTROUTING (SNAT/Masquerade)    |
|                                                         │                   │                      |
+=========================================================│===================│======================+
|                   PHYSICAL / HYPERVISOR HARDWARE (Azure Cloud)              │                      |
+=============================================================================│======================+
|     ├── Block Storage Controller (Managed Disks: SCSI Bus) <────────────────┘                      |
|     ├── Physical RAM Chips                                                                         |
|     ├── CPU Cores (vCPUs: us, sy, id, wa, st)                                                      |
|     └── Network Interface Card (NIC / eth0 / Wire Server: 168.63.129.16) <────────────────────────┘
