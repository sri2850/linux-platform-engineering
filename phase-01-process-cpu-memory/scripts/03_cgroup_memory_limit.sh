#!/usr/bin/env bash
# Demonstrates kernel cgroups v2 resource capping and isolated OOM enforcement.
set -euo pipefail

CGROUP_DIR="/sys/fs/cgroup/sandbox_demo"

echo "[1/4] Creating cgroup sandbox..."
sudo mkdir -p "$CGROUP_DIR"

echo "[2/4] Setting 100MB hard limit..."
echo "100M" | sudo tee "$CGROUP_DIR/memory.max"

echo "[3/4] Validating limit..."
cat "$CGROUP_DIR/memory.max"

echo "[4/4] Attaching subshell and triggering cgroup OOM..."
sudo bash -c "echo \$\$ > $CGROUP_DIR/cgroup.procs && stress --vm 1 --vm-bytes 200M --vm-hang 5" || true

echo "Reviewing kernel ring buffer for cgroup isolation:"
sudo dmesg -T | tail -n 15 | grep -E "oom-kill|Memory cgroup" || true

echo "Tearing down cgroup..."
sudo rmdir "$CGROUP_DIR"