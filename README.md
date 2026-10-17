# Linux Platform & Systems Engineering Reference

Production-grade Linux system administration patterns, kernel mechanics, and incident triage runbooks.

## Structure

- **Phase 1: Process, CPU, Memory & cgroups**
  - Zombie process lifecycles and signal handling limits
  - Unlinked open file descriptor exhaustion and zero-downtime recovery
  - Virtual, Resident, and Proportional Memory sizing
  - Kernel Out-Of-Memory (OOM) score mechanics
  - Load average computation vs CPU utilization
  - cgroups v2 resource capping and isolation
- **Phase 2: Storage Subsystems, LVM & Filesystem Recovery**
  - Data blocks vs inode exhaustion
  - Logical Volume Management (PV, VG, LV) and live expansion
  - Persistent disk mounting with UUIDs and `nofail`
  - Safe cloud disk decommissioning flows
