#!/usr/bin/env bash
# Live operational triage script for CPU, Memory, and D-state processes.
set -euo pipefail

echo "=== System Load & Architecture ==="
uptime
lscpu | grep -E "^CPU\(s\):|Model name:"

echo -e "\n=== Top Memory Consumers (Real Resident RAM) ==="
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 6

echo -e "\n=== Processes in D-State (Uninterruptible Sleep) ==="
ps -eo pid,user,stat,comm | grep -E " D| D\+" || echo "No processes currently in D-state."

echo -e "\n=== Top OOM Candidates (Ranked by Kernel Badness) ==="
for p in /proc/[0-9]*; do
  if [ -f "$p/oom_score" ]; then
    echo "$(cat "$p/oom_score" 2>/dev/null) $(tr '\0' ' ' < "$p/cmdline" 2>/dev/null | head -c 40) (PID: ${p##*/})"
  fi
done 2>/dev/null | sort -nr | head -n 5