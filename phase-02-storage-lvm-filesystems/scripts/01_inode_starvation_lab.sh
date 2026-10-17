#!/usr/bin/env bash
# Demonstrates inode depletion while raw disk space remains unaffected.
set -euo pipefail

LAB_DIR="/tmp/inode_starvation_lab"
mkdir -p "$LAB_DIR"

echo "Initial Inode and Block Status:"
df -i /tmp
df -h /tmp

echo "Allocating 50,000 zero-byte files..."
bash -c 'for i in $(seq 1 50000); do touch /tmp/inode_starvation_lab/file_$i; done'

echo -e "\nPost-allocation Inode and Block Status:"
df -i /tmp
df -h /tmp

echo -e "\nLocating directories with high inode counts:"
find /tmp -xdev -printf '%h\n' | sort | uniq -c | sort -k 1 -nr | head -n 5

echo -e "\nCleaning up using memory-efficient streaming deletion:"
find "$LAB_DIR" -type f -delete
rmdir "$LAB_DIR"

echo "Post-cleanup Inode Status:"
df -i /tmp