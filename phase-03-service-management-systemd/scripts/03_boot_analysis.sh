#!/usr/bin/env bash
# Evaluates system startup timing and isolates sequential bottlenecks.
set -euo pipefail

echo "=== System Boot Time Summary ==="
systemd-analyze

echo -e "\n=== Top 5 Slowest Initializing Services ==="
systemd-analyze blame | head -n 5

echo -e "\n=== Critical Path Dependency Tree ==="
systemd-analyze critical-chain --no-pager