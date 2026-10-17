#!/usr/bin/env bash
# Decommissions an LVM stack and removes fstab entries prior to disk detachment.
# Usage: sudo ./03_safe_disk_decommission.sh /dev/sdX /datadrive
set -euo pipefail

DEVICE="${1:-}"
MOUNT_POINT="${2:-/datadrive}"
VG_NAME="vg_data"
LV_NAME="lv_data"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: sudo $0 <block-device> [mount-point]"
    echo "Example: sudo $0 /dev/sda /datadrive"
    exit 1
fi

echo "[1/5] Unmounting $MOUNT_POINT..."
if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT"
fi

echo "[2/5] Cleaning /etc/fstab entry..."
sed -i "\|$MOUNT_POINT|d" /etc/fstab
mount -a

echo "[3/5] Removing Logical Volume..."
if lvdisplay "/dev/$VG_NAME/$LV_NAME" > /dev/null 2>&1; then
    lvremove -y "/dev/$VG_NAME/$LV_NAME"
fi

echo "[4/5] Removing Volume Group..."
if vgdisplay "$VG_NAME" > /dev/null 2>&1; then
    vgremove "$VG_NAME"
fi

echo "[5/5] Wiping Physical Volume signature on $DEVICE..."
if pvdisplay "$DEVICE" > /dev/null 2>&1; then
    pvremove "$DEVICE"
fi

echo "Teardown complete. Disk is safe to detach and delete via Azure Portal."