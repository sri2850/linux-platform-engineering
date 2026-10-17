# Phase 2: Storage Subsystems, LVM & Filesystem Recovery

## Core Mental Models

### 1. Inodes vs Storage Data Blocks

- Every formatted filesystem partition divides space into two pools:
  - **Data Blocks:** Store actual file payload bytes. Tracked using `df -h`.
  - **Inode Table:** Stores metadata (owner, permissions, timestamps, block pointers). Tracked using `df -i`.
- Every file or directory consumes exactly 1 inode, regardless of its byte size.
- 0-byte or 1-byte file floods exhaust `IFree` while raw disk space remains almost entirely empty.
- When `IFree = 0`, write operations fail with `No space left on device` even with gigabytes of free disk space.
- Deleting millions of small files via `rm -rf *` triggers `Argument list too long` because glob expansion exceeds the kernel's `ARG_MAX` buffer. Always stream deletions:
  ```bash
  find /target/path -type f -delete
  ```

### 2. Logical Volume Manager (LVM) Architecture

LVM decouples logical partitions from physical disk boundaries across three layers:

```text
[ Physical Disks / Cloud Disks ] ──> /dev/sdX
                 │
                 ▼
[ Physical Volumes (PV) ]        ──> pvcreate /dev/sdX
                 │
                 ▼
[ Volume Group (VG) ]            ──> vgcreate vg_data /dev/sdX
                 │
                 ▼
[ Logical Volume (LV) ]          ──> lvcreate -l 100%FREE -n lv_data vg_data
                 │
                 ▼
[ Filesystem & Mount ]           ──> mkfs.ext4 / mount /datadrive
```

- **Physical Volume (PV):** Formats the raw block device with an LVM metadata header.
- **Volume Group (VG):** Aggregates multiple PVs into a pooled storage group.
- **Logical Volume (LV):** Carves out usable block storage slices from the VG.
- **Atomic Online Growth:**
  To consume newly expanded storage on a mounted drive without downtime:
  ```bash
  sudo lvextend -r -l +100%FREE /dev/vg_data/lv_data
  ```
  The `-r` flag automatically invokes `resize2fs` (ext4) or `xfs_growfs` (XFS) while the filesystem is mounted.

### 3. Cloud Persistent Storage & /etc/fstab Rules

- **Device Node Drift:** In cloud platforms (Azure, AWS), device node letters (`/dev/sda`, `/dev/sdb`, `/dev/sdc`) are dynamically assigned by the SCSI subsystem during kernel boot enumeration. Attaching or detaching drives can cause letters to shift between reboots.
- **Persistent Identification:** Never use `/dev/sdX` in `/etc/fstab`. Always identify partitions by their filesystem UUID:
  ```bash
  sudo blkid /dev/vg_data/lv_data
  ```
- **The `nofail` Option:**
  - Standard syntax:
    ```text
    UUID=f8c5d2da-4478-4bc3-83eb-3730f5dd7070  /datadrive  ext4  defaults,nofail  0  2
    ```
  - Without `nofail`, if an attached cloud data disk fails to mount or is detached, systemd stalls the boot process and drops into an emergency rescue shell (`emergency.target`), cutting off SSH access.
  - With `nofail`, systemd logs the failure and continues booting to multi-user mode.
- **Pre-Reboot Verification:**
  Always test `/etc/fstab` edits before rebooting:
  ```bash
  sudo umount /datadrive
  sudo mount -a
  ```
  If `mount -a` returns zero errors and mounts `/datadrive`, the configuration is valid for reboot.

### 4. Safe Cloud Disk Decommissioning

Tearing down a cloud disk must occur in reverse order to prevent kernel I/O panics:

1. `umount /datadrive`
2. Remove the mount line from `/etc/fstab` and run `mount -a`.
3. `lvremove -y /dev/vg_data/lv_data`
4. `vgremove vg_data`
5. `pvremove /dev/sdX`
6. Detach and delete the disk via the cloud control plane.

---

## Lab Execution Guide

### 1. Inode Starvation & Streaming Deletion Lab

```bash
chmod +x scripts/01_inode_starvation_lab.sh
./scripts/01_inode_starvation_lab.sh
```

### 2. Azure LVM Provisioning & Live Resizing

```bash
chmod +x scripts/02_azure_lvm_lifecycle.sh
# Execute against an attached data disk:
sudo ./scripts/02_azure_lvm_lifecycle.sh /dev/sdc /datadrive
```

### 3. Safe Decommissioning

```bash
chmod +x scripts/03_safe_disk_decommission.sh
# Teardown the stack prior to cloud detachment:
sudo ./scripts/03_safe_disk_decommission.sh /dev/sdc /datadrive
```
