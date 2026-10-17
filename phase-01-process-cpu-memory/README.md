# Phase 1: Process, CPU, Memory & cgroups Mechanics

## Core Mental Models

### 1. Process Lifecycle & Zombies

- A zombie process (`Z` / `<defunct>`) consumes 0 bytes of RAM and 0% CPU. Its execution context, stack, and heap have already been freed by the kernel.
- It only occupies a slot in the kernel's process table so that its exit status code remains available for its parent.
- The parent process is expected to read this status code via the `wait()` or `waitpid()` system call.
- Running `kill -9` directly against a zombie PID fails because there is no active execution thread or signal handler to receive signals.
- To clear a zombie, terminate the parent process (`kill -15` or `kill -9`). Once the parent exits, the orphaned zombie is adopted by PID 1 (`systemd`), which automatically reaps the exit status and cleans the PID entry.

### 2. Unlinked Open File Descriptors ("Ghost Disk Leak")

- A filesystem frees allocated storage blocks only when two independent conditions are met:
  1. Directory hard link count drops to 0 (`rm` removes directory entry).
  2. Open file descriptor count in the kernel drops to 0 (processes close handle).
- If a running process retains an open file descriptor when an uncoordinated deletion occurs, the directory pointer vanishes, but physical disk blocks remain locked.
- Identification:
  - Run `lsof +L1` to list open files with a link count less than 1.
  - Or inspect: `ls -l /proc/*/fd/* 2>/dev/null | grep deleted`
- Zero-Downtime Remediation:
  - Truncate the file directly via the procfs handle without killing the application:
    `: > /proc/<PID>/fd/<FD_NUM>`
  - Or: `truncate -s 0 /proc/<PID>/fd/<FD_NUM>`

### 3. Memory Allocation Mechanics

- **Virtual Memory Size (VSS / `VmSize`):** Total virtual address space requested by the process via `malloc()`. This does not consume physical RAM until pages are actively written.
- **Resident Set Size (RSS / `VmRSS`):** Real physical memory mapped to actual silicon RAM pages for that process. RSS overcounts shared libraries loaded across multiple programs.
- **High Water Mark (`VmHWM`):** The historical peak resident memory this process consumed during its lifespan.
- **Proportional Set Size (PSS):** Retrieved from `/proc/<PID>/smaps_rollup`. Evenly apportions shared library overhead among sharing processes, providing the most accurate per-process footprint.
- **Kernel Out-Of-Memory (OOM) Management:**
  - When physical RAM and swap are exhausted, the kernel scans processes, calculates an `oom_score`, and terminates the highest-scoring candidate with `SIGKILL`.
  - `/proc/<PID>/oom_score`: Current badness calculation.
  - `/proc/<PID>/oom_score_adj`: Score adjustment knob ranging from `-1000` (immune to termination) to `+1000` (first priority target).

### 4. CPU Scheduling vs Load Average

- **Load Average Definition:** The exponentially decaying average of tasks that are currently executing on a CPU core, runnable and queued for a CPU core, or blocked in Uninterruptible Sleep (`D` state).
- Load Average does not directly measure CPU usage percentage.
- On an N-core system:
  - `Load < N`: System has capacity to spare.
  - `Load = N`: Cores are fully utilized without queuing.
  - `Load > N`: Tasks are queuing up.
- **D-State Trap:** If `uptime` reports high load (e.g., 8.0 on a 2-core VM) while CPU utilization (`%us` / `%sy`) shows idle (`id = 99%`), tasks are blocked waiting on disk hardware, dead NFS mounts, or kernel I/O locks. A process in D-state cannot be killed by `kill -9`.

### 5. Control Groups (cgroups v2)

- cgroups provide kernel-level resource metering and isolation for CPU, memory, and I/O.
- Modern distributions mount cgroups v2 at `/sys/fs/cgroup`.
- Setting `memory.max` enforces a hard memory limit for all processes mapped into `cgroup.procs`.
- When aggregate resident memory in the cgroup exceeds `memory.max`, the kernel executes `oom-kill` constrained strictly to `CONSTRAINT_MEMCG`. The rest of the host remains unaffected.
- This is the identical underlying mechanism leveraged by container engines (containerd, runc, Kubernetes) to enforce memory limits and trigger OOMKilled (Exit Code 137).

---

## Lab Execution Guide

### 1. Zombie Lifecycle Lab

```bash
python3 scripts/01_zombie_lifecycle.py
# In another terminal:
ps -ef | grep -E "defunct|python3"
# Kill the parent PID to trigger automatic cleanup
```

### 2. Ghost Disk Recovery Lab

```bash
chmod +x scripts/02_ghost_disk_leak.sh
./scripts/02_ghost_disk_leak.sh
```

### 3. cgroup Memory Capping Lab

```bash
chmod +x scripts/03_cgroup_memory_limit.sh
./scripts/03_cgroup_memory_limit.sh
```

### 4. Live System Triage

```bash
chmod +x scripts/04_system_triage.sh
./scripts/04_system_triage.sh
```
