#!/usr/bin/env bash
# End-to-end setup script for an attached Azure Data Disk.
# Usage: sudo ./02_azure_lvm_lifecycle.sh /dev/sdX /datadrive
set -euo pipefail

DEVICE="${1:-}"
MOUNT_POINT="${2:-/datadrive}"
VG_NAME="vg_data"
LV_NAME="lv_data"

if [[ -z "$DEVICE" || ! -b "$DEVICE" ]]; then
    echo "Usage: sudo $0 <block-device> [mount-point]"
    echo "Example: sudo $0 /dev/sdc /datadrive"
    exit 1
fi

echo "[1/6] Initializing Physical Volume on $DEVICE..."
pvcreate "$DEVICE"

echo "[2/6] Creating Volume Group $VG_NAME..."
vgcreate "$VG_NAME" "$DEVICE"

echo "[3/6] Allocating Logical Volume $LV_NAME (100% of VG)..."
lvcreate -l 100%FREE -n "$LV_NAME" "$VG_NAME"

LV_PATH="/dev/$VG_NAME/$LV_NAME"

echo "[4/6] Formatting with ext4 filesystem..."
mkfs.ext4 -F "$LV_PATH"

echo "[5/6] Creating mount directory $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"

UUID_VAL=$(blkid -s UUID -o value "$LV_PATH")

echo "[6/6] Appending persistent mount to /etc/fstab..."
echo "UUID=$UUID_VAL  $MOUNT_POINT  ext4  defaults,nofail  0  2" >> /etc/fstab

echo "Executing mount verification..."
mount -a
df -h "$MOUNT_POINT"
echo "LVM storage deployment completed successfully."