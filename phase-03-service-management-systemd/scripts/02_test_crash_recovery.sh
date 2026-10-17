#!/usr/bin/env bash
# Demonstrates systemd crash detection and self-healing supervision.
set -euo pipefail

INITIAL_PID=$(pgrep -u appsvc -f worker.py || true)

if [[ -z "$INITIAL_PID" ]]; then
    echo "Error: appworker is not running. Start it with systemctl start appworker."
    exit 1
fi

echo "Current active PID: $INITIAL_PID"
echo "Sending SIGKILL (kill -9) to simulate unhandled fatal crash..."
sudo kill -9 "$INITIAL_PID"

echo "Waiting 4 seconds for systemd supervision loop..."
sleep 4

NEW_PID=$(pgrep -u appsvc -f worker.py || true)

if [[ -n "$NEW_PID" && "$NEW_PID" != "$INITIAL_PID" ]]; then
    echo "Self-healing verified. New running PID: $NEW_PID"
    sudo systemctl status appworker --no-pager | head -n 10
else
    echo "Recovery verification failed."
    exit 1
fi