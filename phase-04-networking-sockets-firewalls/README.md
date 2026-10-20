# Phase 4: Low-Level Networking, Sockets & Packet Filtering

## Core Mental Models

### 1. Modern Network Management (`iproute2`)

- Modern distributions replace deprecated `net-tools` (`ifconfig`, `route`, `arp`) with `iproute2`.
- Layer 2/3 link states and addresses: `ip -br addr show`
- Kernel IP routing table and default gateway: `ip route show`
- Layer 2 ARP cache table: `ip neighbor show`

### 2. Socket Lifecycles & Connection States

- Socket information is queried via `ss` (Socket Statistics), which inspects the kernel's `sock_diag` netlink interface directly.
- Standard inspection: `sudo ss -tlpn` (TCP, Listening, Process/PID, Numeric).
- **`TIME_WAIT` Accumulation:**
  - Occurs after the local endpoint initiates active closure. Held for 60 seconds (2 × MSL) to ensure late in-flight packets do not collide with new connections.
  - High-traffic microservices without connection pooling or HTTP Keep-Alive can exhaust the ephemeral port range (`net.ipv4.ip_local_port_range`).
- **`CLOSE_WAIT` Accumulation:**
  - The remote client has closed the connection, but the local application has not invoked `close()` on the socket descriptor.
  - Indicates an application bug or thread leak. Cannot be cleared by kernel tuning; the process must close the file descriptor or be restarted.

### 3. Netfilter Packet Filtering (`iptables` / `nftables`)

- Linux processes packets through core Netfilter chains:
  - `INPUT`: Packets destined for local sockets on this host.
  - `OUTPUT`: Packets originating from local processes exiting to the network.
  - `FORWARD`: Packets traversing this host as a router/gateway.
- **`DROP` vs `REJECT`:**
  - `REJECT`: Immediately returns an ICMP unreachable or TCP RST packet (`Connection refused`).
  - `DROP`: Silently discards packets, forcing clients to wait until application/TCP timeout expires. Silent drops are a primary cause of mysterious connection latency.
- Rules are inspected with packet and byte counters via: `sudo iptables -L -n -v`.

### 4. DNS Resolution Chain & `systemd-resolved`

- Applications invoke resolver libraries via `getaddrinfo()`.
- Resolution path:
  1. `/etc/nsswitch.conf` directs lookup order (`files`, `dns`).
  2. `/etc/hosts` resolves static overrides.
  3. `/etc/resolv.conf` directs queries to the local stub resolver (`127.0.0.53:53`).
  4. `systemd-resolved` resolves from memory cache or forwards upstream (e.g., Azure DNS `168.63.129.16`).
- Triage:
  - Check active link DNS configuration: `resolvectl status`
  - Flush local in-memory cache: `sudo resolvectl flush-caches`

### 5. Kernel TCP Tuning (`sysctl`)

- Ephemeral port expansion: `net.ipv4.ip_local_port_range = 10240 65535`
- Backlog handshake queue expansion: `net.core.somaxconn = 65535`
- Connection synchronization backlog: `net.ipv4.tcp_max_syn_backlog = 8192`
- Persistent configuration: saved in `/etc/sysctl.d/` and loaded via `sudo sysctl --system`.

---

## Lab Execution Guide

### 1. Interface & Route Inspection

```bash
chmod +x scripts/01_network_triage.sh
./scripts/01_network_triage.sh
```

### 2. Socket Audit & Backlog Inspection

```bash
chmod +x scripts/02_socket_audit.sh
sudo ./scripts/02_socket_audit.sh
```

### 3. Firewall Drop & Triage Simulation

```bash
chmod +x scripts/03_firewall_drop_drill.sh
sudo ./scripts/03_firewall_drop_drill.sh
```
