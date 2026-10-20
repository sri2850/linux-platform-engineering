#!/usr/bin/env bash
# Audits active listening sockets, socket states, and kernel network queues.
set -euo pipefail

echo "=== Active Listening TCP Ports & Bound Daemons ==="
ss -tlpn

echo -e "\n=== Socket State Summary ==="
ss -s

echo -e "\n=== Current Kernel TCP Allocation Limits ==="
sysctl net.ipv4.ip_local_port_range net.core.somaxconn net.ipv4.tcp_tw_reuse