# Enterprise Systems, Networking & Cloud Architecture Track

> **Target Goal:** Transition from isolated command memorization to Principal-level systems design, cross-layer forensic triage, and failure-domain architecture across **Linux &rarr; Networking &rarr; Azure &rarr; AKS**.

---

## 🗺️ Roadmap Overview

| Section | Focus Area | Status | Key Milestones |
| :--- | :--- | :--- | :--- |
| **Part 1** | Enterprise Linux Systems | `In Progress` | Phases 1–4 Mastered; Phase 5 Next |
| **Part 2** | Universal Networking Prerequisites | `Planned` | L2–L7 Core Protocols, Packet Forensics |
| **Part 3** | Azure Cloud Enterprise Networking | `Planned` | vWAN, Hybrid Hub-Spoke, CNI / eBPF |
| **Part 4** | The Principal-Grade Standard | `Continuous` | Architectural Design & Systematic Triage |

---

## Part 1: The Enterprise Linux Systems Track

### Progress Tracker
- [x] **Phase 1:** Process, CPU, Memory Internals & Core Shell Tooling
- [x] **Phase 2:** Storage Subsystems, Filesystems, LVM & OverlayFS
- [x] **Phase 3:** Service Management, Systemd & Complete Boot Chain
- [x] **Phase 4:** Low-Level Networking, Sockets & Packet Filtering
- [ ] **Phase 5:** Core Enterprise Administration, Access Governance & Clocks *(Next Step)*
- [ ] **Phase 6:** Linux Namespaces & Building Containers from Scratch
- [ ] **Phase 7:** OS Security, Hardening, Kernel Interfaces & Cloud Realities
- [ ] **Phase 8:** Advanced Performance Observability & Tracing (USE / Brendan Gregg)

---

<details>
<summary><strong>Phase 1: Process, CPU, Memory Internals & Core Shell Tooling</strong> <code>[COMPLETED]</code></summary>

1. **Process Lifecycles & Signals**
   - States: `R` (Running), `S` (Interruptible Sleep), `D` (Uninterruptible Sleep), `Z` (Zombie).
   - Defunct & orphan processes; why `kill -9` fails on zombies; reaping via PID 1 (`systemd`).
2. **File Descriptors & Inode Mechanics**
   - Virtual filesystem tables (`/proc/<PID>/fd/`).
   - Resolving 100% ghost disk leaks from deleted-but-open files via truncation:  
     `: > /proc/<PID>/fd/<FD>`
3. **Memory Sizing & Paging Mechanics**
   - VSS (`VmSize`) vs RSS (`VmRSS`) vs PSS (`/proc/<PID>/smaps_rollup`).
   - Page cache, dirty pages writeback daemon (`kswapd`/`flush`), and swap thrashing diagnostics.
4. **The Out-Of-Memory (OOM) Subsystem**
   - Memory overcommit settings (`/proc/sys/vm/overcommit_memory`).
   - Kernel badness scoring (`/proc/<PID>/oom_score` and `oom_score_adj`).
   - Kernel ring buffer forensics via `dmesg -T`.
5. **CPU Scheduling & Queue Depth Mechanics**
   - Load Average as total queue depth (`R` + `D` tasks).
   - High compute saturation vs storage wait; `vmstat 1` triage matrix (`r`, `b`, `us`, `wa`, `so`, `si`).
6. **Core Shell Tooling & Resilient Scripting**
   - Text parsing primitives: `grep -E`, `awk`, `sed`, `find`, `xargs`.
   - Production bash standards: `set -euo pipefail`, trap handlers, stream redirection (`&> /dev/null`).

</details>

<details>
<summary><strong>Phase 2: Storage Subsystems, Filesystems, LVM & OverlayFS</strong> <code>[COMPLETED]</code></summary>

7. **Block Devices, Superblocks & Inode Mechanics**
   - Inode table structure vs raw storage data blocks.
   - Inode starvation (`df -i` at 100%, `df -h` empty) throwing `No space left on device`.
   - Streaming deletion via `find /path -type f -delete` to prevent shell `ARG_MAX` buffer overflows.
8. **Logical Volume Manager (LVM) Hierarchy**
   - 3-tier mapping: Physical Volumes (`pvcreate`) &rarr; Volume Groups (`vgcreate`) &rarr; Logical Volumes (`lvcreate`).
   - Online, zero-downtime block growth via `lvextend -r`.
9. **Filesystem Internals & Resilience**
   - `ext4` vs `XFS` operational differences (one-way expansion vs shrinking limitations).
   - Filesystem repair tools (`fsck`, `xfs_repair`) and journal verification.
10. **Storage Mounting & Persistence**
    - Persistent UUID mounting (`/etc/fstab`) to avoid cloud device node letter swapping (`/dev/sdX`).
    - Preventing boot failure drops (`emergency.target`) using the `nofail` mount option.
    - Cloud disk decommissioning order:  
      `umount` &rarr; `fstab removal` &rarr; `mount -a` &rarr; `lvremove` &rarr; `vgremove` &rarr; `pvremove`.
11. **Filesystem Layering (OverlayFS)**
    - Architecture: `lowerdir` (read-only base), `upperdir` (read-write), `workdir`, and `merged` mount.
    - How container image layers function natively on disk.

</details>

<details>
<summary><strong>Phase 3: Service Management, Systemd & Complete Boot Chain</strong> <code>[COMPLETED + EXTENSION]</code></summary>

12. **The Complete Linux Boot Chain**
    - Stages: `UEFI/BIOS` &rarr; `GRUB2` (kernel args, `init=/bin/bash` recovery) &rarr; `initramfs` &rarr; `Kernel execution` &rarr; `systemd (PID 1)`.
13. **Systemd Service Unit Architecture**
    - Custom unit paths (`/etc/systemd/system/` vs `/lib/systemd/system/`).
    - Unit dependencies: `After=` vs `Wants=` (soft) vs `Requires=` (hard).
    - Lifecycle controls: `Type=simple`, `User=` (least privilege), `Restart=always`, `RestartSec=`, `LimitNOFILE=`.
14. **Process Sandboxing & Kernel Governance**
    - cgroups v2 integration directly inside unit files (`MemoryMax=`, `CPUQuota=`).
    - Filesystem isolation: `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true`, `NoNewPrivileges=true`.
15. **Target Management & Boot Profiling**
    - Runlevels vs Systemd targets (`multi-user.target`, `rescue.target`, `emergency.target`).
    - Boot latency diagnosis: `systemd-analyze`, `systemd-analyze blame`, `systemd-analyze critical-chain`.
16. **Binary Logging Engine (journald)**
    - Structured logging via `journalctl`: `-u <unit>`, `-b` (current boot), `-p err..alert`, `--since`.
    - Vacuuming log storage allocations (`--vacuum-size=200M`).

</details>

<details>
<summary><strong>Phase 4: Low-Level Networking, Sockets & Packet Filtering</strong> <code>[COMPLETED]</code></summary>

17. **Modern Interface & Route Triage**
    - Replacing `net-tools` with `iproute2`: `ip -br addr`, `ip route`, `ip neighbor`.
18. **Socket Lifecycles & State Machines**
    - Low-level socket inspection via `ss -tlpn` and `ss -s`.
    - `TIME_WAIT` accumulation (ephemeral port exhaustion) vs `CLOSE_WAIT` leaks (unclosed application descriptors).
19. **Packet Filtering & Firewall Mechanics**
    - Netfilter packet lifecycle hooks: `PREROUTING`, `INPUT`, `FORWARD`, `OUTPUT`, `POSTROUTING`.
    - Packet inspection: `DROP` (silent timeout) vs `REJECT` (immediate RST / Connection refused).
    - Rule counter auditing (`iptables -L -n -v --line-numbers`) and rule insertion (`-I` vs `-A`).
20. **DNS Resolution Flow & systemd-resolved**
    - Application lookup chain: `/etc/nsswitch.conf` &rarr; `/etc/hosts` &rarr; `/etc/resolv.conf`.
    - Local loopback caching daemon (`127.0.0.53:53`) and resolving upstream (Azure Wire Server: `168.63.129.16`).
    - Cache management and active link evaluation via `resolvectl status` and `resolvectl flush-caches`.
21. **Kernel TCP Tuning via sysctl**
    - Tuning ephemeral ports (`net.ipv4.ip_local_port_range`), connection backlogs (`net.core.somaxconn`), and connection tracking limits.

</details>

<details open>
<summary><strong>Phase 5: Core Enterprise Administration, Access Governance & Clocks</strong> <code>[NEXT STEP]</code></summary>

22. **User Accounts & Group Lifecycles**
    - Internal formats: `/etc/passwd`, `/etc/shadow`, `/etc/group`.
    - Service accounts, system UIDs, group memberships, and least-privilege sudoers delegation (`visudo`).
23. **Advanced POSIX Access Control Lists (ACLs)**
    - Overriding standard owner/group/other `rwxr-xr-x` masks.
    - Setting multi-user/multi-group fine-grained permissions via `getfacl` and `setfacl`.
24. **Scheduled Automation & Daemons**
    - Traditional cron (`/etc/cron.*`, `crontab`).
    - Modern `systemd.timer` units: monotonic timers, calendar events, missed execution catch-up, and journal integration.
25. **Time Synchronization & Clock Drift**
    - Configuring `chronyd` (`chronyc tracking`, `chronyc sources`).
    - Preventing time drift failure modes: Kerberos tickets, OAuth/JWT token invalidation, TLS cert validation, and database consensus splits.
26. **Network Shared Storage (NFS)**
    - Mounting NFS exports, tuning mount parameters (`hard` vs `soft` mounts, `timeo`, `rsize`/`wsize`).
    - Recovering from dead NFS mounts (stale file handles) and safe boot integration (`_netdev` in `/etc/fstab`).

</details>

<details>
<summary><strong>Phase 6: Linux Namespaces & Building Containers from Scratch</strong></summary>

27. **The 6 Core Linux Isolation Namespaces**
    - `pid`: Process tree virtualization (process sees itself as PID 1).
    - `net`: Independent loopback, IP routing, firewall rules, and `veth` virtual interfaces.
    - `mnt`: Isolated filesystem mount trees.
    - `ipc`: System V IPC and POSIX message queue sandboxing.
    - `uts`: Isolated hostnames and domain names.
    - `user`: Mapping non-root host users to root inside the isolated namespace.
28. **Hands-On Container Assembly**
    - Creating a container by hand without Docker or containerd.
    - Combining: `unshare` + root filesystem tarball + `chroot` + `cgroups v2` resource quotas + `veth` pair attached to a bridge.

</details>

<details>
<summary><strong>Phase 7: OS Security, Hardening, Kernel Interfaces & Cloud Realities</strong></summary>

29. **Mandatory Access Control (MAC)**
    - AppArmor (Ubuntu/Debian) and SELinux (RHEL/CentOS) security architectures.
    - Enforcing vs Complain/Permissive modes; reading audit denial logs.
30. **Linux Capabilities Subsystem**
    - Breaking the root monolith into discrete privilege units (`CAP_NET_BIND_SERVICE`, `CAP_SYS_ADMIN`, `CAP_SETUID`).
    - Assigning capabilities directly to compiled binaries via `setcap` and `getcap`.
31. **Host Authentication & SSH Hardening**
    - `sshd_config` production standards: disabling password auth, disabling root login, key algorithms, `MaxAuthTries`.
    - Pluggable Authentication Modules (PAM) structure in `/etc/pam.d/`.
32. **System Auditing & Core Dumps**
    - Kernel event auditing using `auditd` (`auditctl` rules, `ausearch`, `aureport`).
    - Managing core dumps (`coredumpctl`) and configuring process execution limits via `/etc/security/limits.conf` (`ulimit`).
33. **Cloud Infrastructure Internals (Azure Linux)**
    - `cloud-init`: Boot stage execution, metadata consumption, and debugging `/var/log/cloud-init.log`.
    - Azure Linux Agent (`waagent`): Provisioning, swap creation, and extension management.
    - Instance Metadata Service (`IMDS`): Querying `http://169.254.169.254/metadata/instance` for identities, tokens, and network topologies without credentials.

</details>

<details>
<summary><strong>Phase 8: Advanced Performance Observability & Tracing (Brendan Gregg)</strong></summary>

34. **The USE Diagnostic Framework**
    - Systematic measurement across CPU, Memory, Storage, and Network:
      - **Utilization:** Percentage of time the resource was active.
      - **Saturation:** Queue depth / delayed tasks.
      - **Errors:** Controller and device error counters.
35. **Hardware Performance Counters (perf)**
    - CPU Cycles, Instructions Retired, and Instructions Per Cycle (IPC).
    - Cache misses and memory stall profiling via `perf stat` and `perf top`.
36. **CPU Sampling & FlameGraph Visualization**
    - Recording on-CPU stack traces via `perf record`.
    - Generating and interpreting interactive SVG FlameGraphs to isolate inefficient application code.
37. **Off-CPU vs On-CPU Analysis**
    - Differentiating active CPU cycle burning from threads blocked on locks, disk I/O, or futexes.
38. **Dynamic Kernel Tracing (eBPF & bpftrace)**
    - Writing `bpftrace` one-liners to trace disk I/O latency histograms (`biolatency`).
    - Inspecting live socket round-trip times (`tcprtt`) and process spawns (`execsnoop`).
39. **Dynamic Syscall Tracing (strace / ltrace)**
    - Attaching to running daemons (`strace -p <PID> -f`) to debug silent stalls, missing configuration paths, or blocked system calls without source code access.

</details>

---

## Part 2: Universal Networking Prerequisites

Mastering universal networking fundamentals from first principles before applying cloud-layer abstractions:

- [ ] **1. Layer 2 & Layer 3 Foundations**
  - Ethernet frame layout, MAC addressing, ARP protocol flow, and cache inspection.
  - VLAN tagging (`802.1Q`) and broadcast domain boundaries.
  - ICMP error generation (Type 3 Destination Unreachable, Type 11 Time Exceeded).
  - MTU vs MSS: Why 1500-byte packets fail inside encapsulated tunnels (`VXLAN`, `IPsec`, `WireGuard`) without MSS clamping.
- [ ] **2. IP Addressing & Subnet Mathematics**
  - Binary IPv4 math, variable subnet masks, and prefix lengths (`/24`, `/27`, `/30`).
  - RFC 1918 private scopes (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) and overlap remediation.
  - IPv6 fundamentals (ULA vs GUA, `/64` subnets, link-local addressing).
- [ ] **3. Routing & Path Determination**
  - Longest Prefix Match (LPM) logic (why `/28` beats `/24` and `/16`).
  - Default routing (`0.0.0.0/0`) and next-hop resolution.
  - Asymmetric routing: Why stateful firewalls drop asymmetric return traffic.
  - BGP Fundamentals: Autonomous System Numbers (ASN), Route Advertisements, Path Attributes (`AS-Path`, `MED`, `Local Preference`).
- [ ] **4. Network Address Translation (NAT/PAT)**
  - SNAT (outbound internet egress masking) vs DNAT (inbound port forwarding).
  - Port Address Translation (PAT) and the mechanics of SNAT port exhaustion.
- [ ] **5. TCP State Machine & Transmission Controls**
  - 3-way handshake (`SYN`, `SYN-ACK`, `ACK`) and 4-way teardown (`FIN`, `ACK`, `FIN`, `ACK`).
  - Sliding window flow control, slow-start, retransmissions, and duplicate ACKs.
  - Keepalive timers, idle drops, and TCP Reset (`RST`) injection.
- [ ] **6. DNS Architecture & Resolution**
  - Recursive resolvers vs Authoritative nameservers.
  - Record types: `A`, `AAAA`, `CNAME`, `PTR`, `TXT`, `SRV`, `NS`, `SOA`.
  - TTL cache mechanics, split-horizon DNS, and conditional forwarding rules.
- [ ] **7. Transport Layer Security (TLS/PKI)**
  - Public Key Infrastructure, Certificate Authorities (CA), and intermediate trust chains.
  - TLS 1.3 handshake, Server Name Indication (SNI), and cipher suites.
  - Mutual TLS (mTLS) for zero-trust service-to-service communication.
  - TLS Termination vs TLS Passthrough at edge proxies.
- [ ] **8. Application Layer Protocols (HTTP Ecosystem)**
  - HTTP/1.1 (head-of-line blocking) vs HTTP/2 (multiplexed binary framing) vs HTTP/3 (QUIC over UDP).
  - Critical proxy headers: `Host`, `X-Forwarded-For`, `X-Forwarded-Proto`.
- [ ] **9. Load Balancing & Reverse Proxies**
  - Layer 4 (TCP/UDP transport-level hashing) vs Layer 7 (HTTP URL/header routing).
  - Active health probes (TCP socket vs HTTP status code matching) and node draining.
  - Session persistence (cookie affinity) vs round-robin/least-connections balancing.
  - Forward proxies (outbound egress filtering) vs Reverse proxies (ingress protection).
- [ ] **10. Stateful Packet Inspection & Application Firewalls**
  - 5-tuple tracking: Source IP, Source Port, Destination IP, Destination Port, Protocol.
  - Connection tracking states (`NEW`, `ESTABLISHED`, `RELATED`, `INVALID`).
  - Web Application Firewalls (WAF): Inspecting Layer 7 payloads for SQLi, XSS, and HTTP protocol violations.
- [ ] **11. Virtual Private Networks (VPNs)**
  - IPsec architecture: Internet Key Exchange (`IKEv1` vs `IKEv2`), Security Associations (`SA`), `ESP` encapsulation.
  - Policy-based VPNs (interesting traffic matching ACLs) vs Route-based VPNs (Virtual Tunnel Interfaces with dynamic BGP).
  - WireGuard fundamentals: Cryptokey routing.
- [ ] **12. Low-Level Network Packet Diagnostics**
  - Live packet analysis via `tcpdump` (capture filters, TCP flag inspection).
  - Reading PCAP traces in Wireshark (TCP stream reassembly, retransmission analysis).
  - Path and latency analysis using `mtr` and `traceroute` (interpreting intermediate hop drops).

---

## Part 3: Azure Cloud Enterprise Networking Architecture

Mapping universal networking primitives directly into Azure software-defined networks:

- [ ] **1. Core Virtual Networks & IP Schemas**
  - Virtual Networks (VNets), Subnets, and reserved Azure IP offsets (first 4 IPs + last IP reserved).
  - Multi-region enterprise IP schema planning to prevent address collisions.
- [ ] **2. Software-Defined Routing (UDRs)**
  - Azure System Default Routes vs User Defined Routes (UDRs).
  - Longest Prefix Match (LPM) enforcement in Azure route tables.
  - Next-hop types: `VirtualAppliance`, `VirtualNetworkGateway`, `Internet`, `None` (blackhole routing).
- [ ] **3. Ingress & Egress Traffic Filtering**
  - Network Security Groups (NSGs): Stateful 5-tuple filtering rules, default rule evaluation, priority ordering.
  - Application Security Groups (ASGs): Decoupling firewall rules from IP addresses.
  - Azure Firewall & Network Virtual Appliances (NVAs): Next-hop forwarding, IP forwarding (`ip_forward`), and application FQDN filtering.
- [ ] **4. Outbound Egress Scaling**
  - Azure NAT Gateway: Solving SNAT port exhaustion for high-scale microservices and AKS nodes.
  - Outbound rules on Azure Standard Load Balancer.
- [ ] **5. Ingress Traffic Architecture**
  - Azure Load Balancer (Layer 4 regional high-throughput distribution).
  - Azure Application Gateway (Regional Layer 7 reverse proxy, SSL offloading, URL routing, WAF).
  - Azure Front Door (Global Layer 7 anycast reverse proxy with edge CDN and WAF).
  - Azure Traffic Manager (DNS-based global traffic routing).
- [ ] **6. Private Connectivity & Hybrid DNS**
  - Azure Private Endpoints: Mapping PaaS services (SQL, Storage) directly to private IP addresses via virtual network interfaces.
  - Azure Private DNS Zones & Virtual Network Links.
  - Azure Private DNS Resolver: Inbound endpoints (on-prem &rarr; Azure) and Outbound endpoints with Forwarding Rulesets (Azure &rarr; on-prem) to eliminate DNS forwarding loops.
- [ ] **7. Hybrid Cloud Interconnects**
  - Azure VPN Gateway: Route-based active-active IPsec tunnels with dynamic BGP peering.
  - Azure ExpressRoute: Private Peering (on-prem to VNets) vs Microsoft Peering (on-prem to PaaS), Global Reach, and BGP community controls.
- [ ] **8. Enterprise Topology & Transit Routing**
  - Hub-and-Spoke Topology: Overcoming VNet Peering non-transitivity via central firewall inspection.
  - Azure Virtual WAN (vWAN): Fully meshed any-to-any hub routing with native routing intents.
- [ ] **9. Kubernetes (AKS) Network Mechanics**
  - Kubenet (basic pod IP masquerading) vs Azure CNI (direct VNet IP allocation per pod).
  - Azure CNI Overlay: Efficient IP allocation decoupling pod CIDRs from VNet CIDRs.
  - Cilium & eBPF integration: High-throughput packet forwarding bypassing iptables kube-proxy.

---

## Part 4: The Principal-Grade Standard

### 1. Architectural Design Standards
* **Zero-Overlap IP Schematics:** Non-colliding address spaces across cloud, on-prem, branch offices, and acquisitions.
* **Deterministic Transit Paths:** Enforcing symmetrical routing so stateful firewalls never drop return packets.
* **Resilient DNS Topologies:** Eliminating conditional forwarding deadlocks in hybrid enterprise environments.
* **Fault Domain Isolation:** Segmenting blast radiuses using availability zones, decoupled routing tables, and least-privilege egress controls.

### 2. Universal Production Incident Triage Sequence

```text
               [INCIDENT: COMMUNICATION STALL DETECTED]
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 1: DNS LAYER (Layer 7 Resolution)                           │
│ • Did the hostname resolve? To which IP (Public vs Private)?     │
│ • Verify: dig @127.0.0.53 <host>  OR  resolvectl query <host>    │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ (DNS OK)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 2: ROUTING LAYER (Layer 3 Path Determination)               │
│ • Azure: Inspect "Effective Routes" on the Source NIC            │
│ • Linux: ip route show (Verify Longest Prefix Match)             │
│ • NVA / Firewall: Is IP forwarding enabled? Dropping packets?    │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ (Routing OK)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 3: FIREWALL & FILTERING (Layer 4 Access)                    │
│ • NSG: Verify Outbound on Source AND Inbound on Destination      │
│ • Host: Audit iptables / nftables byte counters for drops        │
│ • Conntrack: Is the stateful engine seeing the SYN-ACK return?   │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ (Firewall OK)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ STEP 4: SOCKET & APPLICATION (Layer 7 Host State)                │
│ • ss -tlpn: Bound to 0.0.0.0 or restricted to 127.0.0.1?         │
│ • Descriptors: Hit LimitNOFILE ("Too many open files")?          │
│ • TLS Handshake: Is the CA chain valid? Does SNI match?          │
│ • Health Probes: Has the load balancer drained the node?         │
└──────────────────────────────────────────────────────────────────┘
