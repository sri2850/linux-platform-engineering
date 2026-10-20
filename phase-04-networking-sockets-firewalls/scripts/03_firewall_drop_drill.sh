#!/usr/bin/env bash
# Demonstrates silent DROP behavior, rule inspection via counters, and cleanup.
set -euo pipefail

TARGET_IP="1.1.1.1"

echo "[1/4] Baseline ping test to $TARGET_IP..."
ping -c 2 "$TARGET_IP"

echo -e "\n[2/4] Appending silent DROP rule on OUTPUT chain..."
iptables -A OUTPUT -p icmp -d "$TARGET_IP" -j DROP

echo "Attempting ping during drop enforcement (timeout expected)..."
ping -c 2 -W 2 "$TARGET_IP" || echo "Ping failed as expected due to silent DROP."

echo -e "\n[3/4] Inspecting packet counter on blocking rule:"
iptables -L OUTPUT -n -v --line-numbers

echo -e "\n[4/4] Removing test DROP rule..."
iptables -D OUTPUT -p icmp -d "$TARGET_IP" -j DROP

echo "Re-validating network egress..."
ping -c 2 "$TARGET_IP"
echo "Drill completed successfully."