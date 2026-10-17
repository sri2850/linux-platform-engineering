#!/usr/bin/env bash
# Demonstrates unlinked open file descriptors holding disk space.
set -euo pipefail

LOG_FILE="/tmp/phantom_app.log"
echo "Creating 1GB log allocation..."
fallocate -l 1G "$LOG_FILE"

echo "Launching background reader to lock descriptor..."
tail -f "$LOG_FILE" > /dev/null &
APP_PID=$!

echo "Simulating uncoordinated log removal..."
rm -f "$LOG_FILE"

echo "Checking filesystem space:"
df -h /tmp

echo "Detecting unlinked descriptor:"
lsof +L1 || ls -l /proc/*/fd/* 2>/dev/null | grep deleted || true

echo "Applying zero-downtime truncation on PID: $APP_PID..."
# Identify the descriptor number holding the deleted file
FD_NUM=$(ls -l /proc/"$APP_PID"/fd 2>/dev/null | grep "phantom_app.log" | awk '{print $9}' | head -n 1)

if [[ -n "$FD_NUM" ]]; then
    : > "/proc/$APP_PID/fd/$FD_NUM"
    echo "Descriptor truncated. Re-evaluating disk space:"
    df -h /tmp
fi

echo "Cleaning up process..."
kill -9 "$APP_PID" 2>/dev/null || true