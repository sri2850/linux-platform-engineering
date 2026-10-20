#!/usr/bin/env bash
# Inspects Layer 2, Layer 3, and upstream DNS resolution status.
set -euo pipefail

echo "=== Layer 2/3 Interfaces ==="
ip -br addr show

echo -e "\n=== Routing Table & Default Gateway ==="
ip route show

echo -e "\n=== ARP / Neighbor Cache ==="
ip neigh show

echo -e "\n=== Active Upstream DNS Settings ==="
resolvectl status 2>/dev/null | grep -E "Current DNS Server|DNS Servers|Link 2" || systemd-resolve --status 2>/dev/null | grep -E "Current DNS Server|DNS Servers"