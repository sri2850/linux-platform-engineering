#!/usr/bin/env bash
# Deploys a least-privilege, sandboxed systemd service from scratch.
set -euo pipefail

echo "[1/5] Creating dedicated service user..."
id -u appsvc &>/dev/null || sudo useradd -r -s /bin/false appsvc

echo "[2/5] Creating application workspace..."
sudo mkdir -p /opt/appsvc

sudo tee /opt/appsvc/worker.py > /dev/null << 'EOF'
import time
import os

print(f"Worker process initialized. PID: {os.getpid()}", flush=True)

tick = 0
while True:
    time.sleep(2)
    tick += 1
    print(f"Heartbeat tick: {tick}", flush=True)
EOF

sudo chown -R appsvc:appsvc /opt/appsvc
sudo chmod 755 /opt/appsvc/worker.py

echo "[3/5] Deploying hardened unit configuration..."
sudo tee /etc/systemd/system/appworker.service > /dev/null << 'EOF'
[Unit]
Description=Demo Enterprise App Worker
After=network.target

[Service]
Type=simple
User=appsvc
Group=appsvc
WorkingDirectory=/opt/appsvc
ExecStart=/usr/bin/python3 /opt/appsvc/worker.py
Restart=always
RestartSec=3s

# Resource Governance (cgroups v2)
MemoryMax=150M
CPUQuota=50%
LimitNOFILE=4096

# Security & Namespace Sandboxing
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo "[4/5] Reloading systemd daemon and enabling unit..."
sudo systemctl daemon-reload
sudo systemctl enable appworker
sudo systemctl restart appworker

echo "[5/5] Verifying operational status..."
sudo systemctl is-active --quiet appworker && echo "Service is active and running."