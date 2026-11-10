# Enterprise Linux Systems Engineering Runbook (Phases 1–7)

A modular, command-by-command reference manual. No monolithic scripts; each command addresses a specific operational condition or diagnostic check.

---

## Quick Navigation
* [Phase 1: Process, CPU, Memory Internals & Shell Tooling](#phase-1-process-cpu-memory-internals--shell-tooling)
* [Phase 2: Storage Subsystems, Filesystems, LVM & OverlayFS](#phase-2-storage-subsystems-filesystems-lvm--overlayfs)
* [Phase 3: Service Management, Systemd & Boot Chain](#phase-3-service-management-systemd--boot-chain)
* [Phase 4: Low-Level Networking, Sockets & Packet Filtering](#phase-4-low-level-networking-sockets--packet-filtering)
* [Phase 5: Core Enterprise Administration, Access Governance & Clocks](#phase-5-core-enterprise-administration-access-governance--clocks)
* [Phase 6: Linux Namespaces & Manual Container Assembly](#phase-6-linux-namespaces--manual-container-assembly)
* [Phase 7: OS Security, Hardening, Kernel Interfaces & Azure Linux](#phase-7-os-security-hardening-kernel-interfaces--azure-linux)
* [The Universal 4-Step Incident Triage Progression](#the-universal-4-step-incident-triage-progression)

---

## Phase 1: Process, CPU, Memory Internals & Shell Tooling

### Process States & Zombie Reaping
* **List all processes with scheduling state and kernel wait channels:**
  ```bash
  ps -eo state,pid,ppid,comm,wchan:20
  ```
  *When to run:* When processes appear frozen or load average is elevated.

* **Find zombie (`Z`) processes and identify parent PIDs:**
  ```bash
  ps -eo stat,pid,ppid,comm | awk '$1 ~ /Z/'
  ```
  *When to run:* When defunct processes accumulate in the task table.

* **Terminate the parent process to allow PID 1 to reap the zombie:**
  ```bash
  kill -15 <PARENT_PID>
  ```
  *When to run:* When `kill -9 <ZOMBIE_PID>` fails because the process is already dead.

* **Inspect the kernel execution call stack of a blocked process:**
  ```bash
  sudo cat /proc/<PID>/stack
  ```
  *When to run:* When a process is stuck in uninterruptible sleep (`D` state).

### Ghost Disk Leaks (Unlinked Open File Descriptors)
* **Locate deleted files held open by running processes:**
  ```bash
  lsof +L1
  ```
  *When to run:* When `df -h` shows a full disk, but `du -sh /*` reports low usage.

* **Identify open deleted files directly through procfs:**
  ```bash
  ls -l /proc/*/fd/* 2>/dev/null | grep '(deleted)'
  ```
  *When to run:* When `lsof` is not installed on the system.

* **Count open file descriptors for a specific process:**
  ```bash
  ls -1 /proc/<PID>/fd | wc -l
  ```
  *When to run:* Checking for descriptor leaks before hitting limits.

* **Truncate an open deleted file in place without stopping the service:**
  ```bash
  : > /proc/<PID>/fd/<FD_NUMBER>
  ```
  *When to run:* Immediate disk space recovery without service downtime.

### Memory Accounting & OOM Diagnostics
* **Extract physical PSS, RSS, and virtual size for a process:**
  ```bash
  grep -E "^(Pss|Rss|Size):" /proc/<PID>/smaps_rollup
  ```
  *When to run:* Verifying true memory footprint versus shared libraries.

* **Inspect kernel memory overcommit configuration:**
  ```bash
  cat /proc/sys/vm/overcommit_memory
  ```
  *When to run:* 0 = heuristic, 1 = always overcommit, 2 = strict limit.

* **Check the kernel OOM killer badness score for a process:**
  ```bash
  cat /proc/<PID>/oom_score
  ```
  *When to run:* Determining which process the kernel will terminate during memory starvation.

* **Tune process OOM kill priority (-1000 to +1000):**
  ```bash
  echo -500 | sudo tee /proc/<PID>/oom_score_adj
  ```
  *When to run:* Protecting critical daemons (-1000 = immune).

* **Scan kernel ring buffer for Out-Of-Memory termination logs:**
  ```bash
  sudo dmesg -T | grep -E -i "oom|killed process|out of memory"
  ```
  *When to run:* When a process exits abruptly with status code 137 (`status=9/KILL`).

### CPU Scheduling & Queue Depth
* **Measure run-queue depth (`r`), blocked I/O tasks (`b`), and wait time (`wa`):**
  ```bash
  vmstat 1 5
  ```
  *When to run:* Identifying whether load is driven by CPU computation or storage stalls.

* **Check 1, 5, and 15-minute load averages and running task counts:**
  ```bash
  cat /proc/loadavg
  ```
  *When to run:* Baseline system load assessment.

* **List all processes currently stuck in uninterruptible sleep (`D`):**
  ```bash
  ps -eo state,pid,ppid,comm | awk '$1 ~ /D/'
  ```
  *When to run:* When load average is high but CPU utilization is low.

### Resilient Shell Standards
* **Production Bash strict mode configuration:**
  ```bash
  set -euo pipefail
  ```
  *When to run:* At the top of shell scripts to prevent silent failures.

* **Signal trap pattern for cleanup operations:**
  ```bash
  trap 'rm -f /tmp/lockfile.lock; exit $?' EXIT INT TERM
  ```
  *When to run:* Ensuring temporary files or locks are cleaned up on cancellation or failure.

---

## Phase 2: Storage Subsystems, Filesystems, LVM & OverlayFS

### Inodes vs. Data Blocks
* **Inspect disk capacity usage (Data Blocks):**
  ```bash
  df -h
  ```
  *When to run:* Routine storage checks.

* **Inspect inode metadata table usage:**
  ```bash
  df -i
  ```
  *When to run:* When applications fail with `No space left on device` but `df -h` shows free space.

* **Find directories containing the highest number of files/inodes:**
  ```bash
  sudo find / -xdev -printf '%h\n' | sort | uniq -c | sort -k1 -n
  ```
  *When to run:* Pinpointing which directory exhausted the inode pool.

* **Delete millions of files safely without hitting `ARG_MAX` buffer errors:**
  ```bash
  sudo find /path/to/target -type f -name "*.tmp" -delete
  ```
  *When to run:* When `rm *` fails with `Argument list too long`.

### Logical Volume Manager (LVM)
* **Discover block devices, sizes, and SCSI LUNs (HCTL):**
  ```bash
  lsblk -o NAME,HCTL,SIZE,MOUNTPOINTS,TYPE
  ```
  *When to run:* After attaching a new cloud managed disk.

* **Initialize a physical block device for LVM:**
  ```bash
  sudo pvcreate /dev/sdX
  ```
  *When to run:* Initial setup of raw disks.

* **Display physical volume information:**
  ```bash
  sudo pvs
  ```
  *When to run:* Verifying raw storage allocation.

* **Create a volume group from physical volumes:**
  ```bash
  sudo vgcreate vg_data /dev/sdX
  ```
  *When to run:* Aggregating disks into an allocation pool.

* **Display volume group information:**
  ```bash
  sudo vgs
  ```
  *When to run:* Checking free extents in a volume group.

* **Create a logical volume using all available volume group space:**
  ```bash
  sudo lvcreate -l 100%FREE -n lv_data vg_data
  ```
  *When to run:* Allocating storage for a filesystem.

* **Display logical volume information:**
  ```bash
  sudo lvs
  ```
  *When to run:* Verifying logical volume paths.

* **Format a logical volume with an ext4 filesystem:**
  ```bash
  sudo mkfs.ext4 /dev/vg_data/lv_data
  ```
  *When to run:* Preparing the volume for file storage.

* **Perform live online filesystem and volume expansion:**
  ```bash
  sudo lvextend -r -l +100%FREE /dev/vg_data/lv_data
  ```
  *When to run:* Resizing volumes on-the-fly without unmounting.

### Persistent Mounts & Decommissioning
* **Extract filesystem UUID for persistent configuration:**
  ```bash
  sudo blkid /dev/vg_data/lv_data
  ```
  *When to run:* Before adding entries to `/etc/fstab`.

* **Test `/etc/fstab` configuration without rebooting:**
  ```bash
  sudo mount -a
  ```
  *When to run:* Validating mount syntax to avoid boot drops to `emergency.target`.

* **Safe cloud disk decommission sequence:**
  ```bash
  sudo umount /mnt/data
  sudo sed -i '\|/mnt/data|d' /etc/fstab
  sudo mount -a
  sudo lvremove -y /dev/vg_data/lv_data
  sudo vgremove vg_data
  sudo pvremove /dev/sdX
  ```
  *When to run:* Detaching storage cleanly before deleting cloud disks.

### OverlayFS
* **Mount an OverlayFS structure manually:**
  ```bash
  sudo mount -t overlay overlay -o lowerdir=/opt/base,upperdir=/opt/diff,workdir=/opt/work /opt/merged
  ```
  *When to run:* Assembling container image layers from scratch.

---

## Phase 3: Service Management, Systemd & Boot Chain

### Boot Chain Forensics
* **Inspect kernel boot command line parameters:**
  ```bash
  cat /proc/cmdline
  ```
  *When to run:* Checking root partition parameters, console redirection, or quiet splash settings.

* **List installed kernel and ramdisk images:**
  ```bash
  ls -lh /boot
  ```
  *When to run:* Checking kernel versions and disk usage under `/boot`.

* **Inspect driver modules packed inside the `initramfs` ramdisk:**
  ```bash
  lsinitramfs /boot/initrd.img-$(uname -r) | grep -E "kernel/drivers/(block|scsi|nvme)"
  ```
  *When to run:* Troubleshooting boot errors like `Unable to mount root fs on unknown-block`.

* **Measure overall boot latency:**
  ```bash
  systemd-analyze
  ```
  *When to run:* Diagnosing slow machine startups.

* **List slowest boot services:**
  ```bash
  systemd-analyze blame
  ```
  *When to run:* Identifying services delaying multi-user readiness.

* **Trace the critical chain path of default boot targets:**
  ```bash
  systemd-analyze critical-chain
  ```
  *When to run:* Isolating unit dependency bottlenecks during initialization.

### Systemd Administration & Governance
* **Reload systemd configuration following changes to unit files:**
  ```bash
  sudo systemctl daemon-reload
  ```
  *When to run:* After creating or editing files in `/etc/systemd/system/`.

* **Enable on boot and start a unit immediately:**
  ```bash
  sudo systemctl enable --now <unit_name>
  ```
  *When to run:* Activating services or timers persistently.

* **Audit service status, active PID, and cgroup tree:**
  ```bash
  systemctl status <unit_name>
  ```
  *When to run:* Verifying process health and recent log output.

* **Query real-time service memory usage from cgroups v2:**
  ```bash
  cat /sys/fs/cgroup/system.slice/<unit_name>.service/memory.current
  ```
  *When to run:* Checking actual memory usage against `MemoryMax`.

* **Check cgroup memory limits and OOM event counters:**
  ```bash
  cat /sys/fs/cgroup/system.slice/<unit_name>.service/memory.events
  ```
  *When to run:* Diagnosing whether a service was killed by cgroups.

### Binary Logging (`journalctl`)
* **Follow live logs for a specific service:**
  ```bash
  sudo journalctl -u <unit_name> -f
  ```
  *When to run:* Active monitoring during deployment.

* **Filter service logs strictly from the current boot:**
  ```bash
  sudo journalctl -u <unit_name> -b --no-pager
  ```
  *When to run:* Isolating logs after a system restart.

* **Filter system-wide logs by priority (errors through emergency):**
  ```bash
  sudo journalctl -p err..alert -b --no-pager
  ```
  *When to run:* Quick triage of critical system failures.

* **Limit journal storage to prevent disk exhaustion:**
  ```bash
  sudo journalctl --vacuum-size=200M
  ```
  *When to run:* Reclaiming disk space from log files.

---

## Phase 4: Low-Level Networking, Sockets & Packet Filtering

### Interface & Route Diagnostics (`iproute2`)
* **Display network interface states, IPs, and MTUs:**
  ```bash
  ip -br addr show
  ```
  *When to run:* Checking IP assignment and whether an interface is up or down.

* **Display the kernel routing table:**
  ```bash
  ip route show
  ```
  *When to run:* Verifying default gateways and Longest Prefix Match (LPM) routes.

* **Inspect the ARP neighbor table:**
  ```bash
  ip neighbor show
  ```
  *When to run:* Checking Layer 2 MAC resolution for adjacent hosts.

### Socket States & Sizing
* **List all listening TCP sockets with process IDs and numeric ports:**
  ```bash
  ss -tlpn
  ```
  *When to run:* Verifying if a service is bound to `0.0.0.0` (all interfaces) or `127.0.0.1` (local only).

* **Display summary statistics for all socket states:**
  ```bash
  ss -s
  ```
  *When to run:* Checking for `TIME_WAIT` accumulation or socket leaks.

* **Filter TCP sockets for a specific port:**
  ```bash
  ss -tan | grep :<PORT>
  ```
  *When to run:* Checking for sockets in `CLOSE_WAIT` (application leaks) or `TIME_WAIT`.

* **Inspect file descriptor limits for a running PID:**
  ```bash
  cat /proc/<PID>/limits | grep "open files"
  ```
  *When to run:* Troubleshooting `Too many open files` errors (`-EMFILE`).

* **List active file descriptors on a running PID:**
  ```bash
  ls -la /proc/<PID>/fd/
  ```
  *When to run:* Identifying open sockets, files, and pipes.

### Netfilter & Firewall Auditing (`iptables`)
* **List filtering rules with line numbers, packet counters, and byte hits:**
  ```bash
  sudo iptables -L INPUT -n -v --line-numbers
  sudo iptables -L OUTPUT -n -v --line-numbers
  ```
  *When to run:* Pinpointing which rule is dropping or rejecting traffic.

* **Insert an ACCEPT rule at the top of the INPUT chain:**
  ```bash
  sudo iptables -I INPUT 1 -p tcp --dport <PORT> -j ACCEPT
  ```
  *When to run:* Overriding subsequent drop rules (first match wins).

* **Append a DROP rule to the bottom of the INPUT chain:**
  ```bash
  sudo iptables -A INPUT -p tcp --dport <PORT> -j DROP
  ```
  *When to run:* Blocking traffic silently (causes client timeouts).

* **Delete an iptables rule by line number:**
  ```bash
  sudo iptables -D INPUT <LINE_NUMBER>
  ```
  *When to run:* Removing a problematic firewall rule.

### DNS Resolution Stack & `systemd-resolved`
* **Audit active upstream DNS servers and link domains:**
  ```bash
  resolvectl status
  ```
  *When to run:* Verifying which DNS server is being queried on the active interface.

* **Flush the local systemd-resolved DNS cache:**
  ```bash
  sudo resolvectl flush-caches
  ```
  *When to run:* Clearing stale DNS records after an IP change.

* **Query a specific DNS server directly, bypassing `/etc/resolv.conf`:**
  ```bash
  dig @127.0.0.53 <DOMAIN> +short
  ```
  *When to run:* Testing if the local caching resolver is healthy.

* **Inspect Name Service Switch lookup order:**
  ```bash
  grep "^hosts:" /etc/nsswitch.conf
  ```
  *When to run:* Verifying whether `/etc/hosts` takes precedence over DNS.

### Packet Capture (`tcpdump`)
* **Capture 5 packets on `eth0` for port 80 without resolving names:**
  ```bash
  sudo tcpdump -i eth0 -nn -c 5 "tcp port 80"
  ```
  *When to run:* Verifying inbound and outbound traffic on the wire.

* **Capture TCP SYN packets (connection establishment attempts):**
  ```bash
  sudo tcpdump -i eth0 -nn "tcp[tcpflags] & tcp-syn != 0"
  ```
  *When to run:* Identifying connection requests hitting the interface.

* **Write raw network packets to a file for analysis:**
  ```bash
  sudo tcpdump -i eth0 -w /tmp/capture.pcap -c 100
  ```
  *When to run:* Capturing traces for Wireshark inspection.

---

## Phase 5: Core Enterprise Administration, Access Governance & Clocks

### User & Group Database Administration
* **Create a system service account without login shell or home directory:**
  ```bash
  sudo useradd -r -s /bin/false <USERNAME>
  ```
  *When to run:* Provisioning unprivileged accounts for background daemons.

* **Create an operational user with a home directory and bash shell:**
  ```bash
  sudo useradd -m -s /bin/bash <USERNAME>
  ```
  *When to run:* Provisioning human operators or deployment accounts.

* **Add