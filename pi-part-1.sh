#!/bin/bash

# ==========================================
# 0. TARGET DRIVE CONFIGURATION
# ==========================================
# DANGER: Set this to the exact block device you want to completely wipe.
TARGET_DEV="/dev/sdX" 

# Create a secure, isolated temporary directory for mounting
WORK_DIR=$(mktemp -d)

# Exit immediately on error and clean up ONLY our specific temp directory
set -e
trap 'echo "Cleaning up..."; umount -R "$WORK_DIR" 2>/dev/null || true; rm -rf "$WORK_DIR"' EXIT

echo "=========================================="
echo "  Arch Linux ARM (64-bit) Imager for RPi4 "
echo "  Target: $TARGET_DEV "
echo "  Workspace: $WORK_DIR "
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

if [ ! -b "$TARGET_DEV" ]; then
    echo "Error: $TARGET_DEV is not a valid block device."
    exit 1
fi

echo "Unmounting existing partitions on $TARGET_DEV..."
umount "${TARGET_DEV}"* 2>/dev/null || true
wipefs -a "$TARGET_DEV" >/dev/null 2>&1

echo "Partitioning $TARGET_DEV..."
sfdisk "$TARGET_DEV" <<EOF
label: dos
size=256M, type=c, bootable
type=83
EOF

# Determine partition naming scheme (sdb1 vs mmcblk0p1)
if [[ "$TARGET_DEV" == *mmcblk* ]] || [[ "$TARGET_DEV" == *nvme* ]]; then
    PART1="${TARGET_DEV}p1"
    PART2="${TARGET_DEV}p2"
else
    PART1="${TARGET_DEV}1"
    PART2="${TARGET_DEV}2"
fi

echo "Formatting boot partition ($PART1) as FAT32..."
mkfs.vfat -F32 "$PART1" >/dev/null

echo "Formatting root partition ($PART2) as ext4..."
mkfs.ext4 -F "$PART2" >/dev/null

echo "Mounting partitions to secure workspace..."
mkdir -p "$WORK_DIR/root"
mount "$PART2" "$WORK_DIR/root"
mkdir -p "$WORK_DIR/root/boot"
mount "$PART1" "$WORK_DIR/root/boot"

ALARM_TAR="ArchLinuxARM-rpi-aarch64-latest.tar.gz"
ALARM_URL="http://os.archlinuxarm.org/os/$ALARM_TAR"

if [ ! -f "$ALARM_TAR" ]; then
    echo "Downloading Arch Linux ARM 64-bit root filesystem..."
    wget -q --show-progress "$ALARM_URL"
else
    echo "Found existing $ALARM_TAR. Skipping download."
fi

echo "Extracting root filesystem..."
bsdtar -xpf "$ALARM_TAR" -C "$WORK_DIR/root"

echo "Syncing data to disk..."
sync

echo "Unmounting partitions..."
umount -R "$WORK_DIR"

echo "=========================================="
echo "Success! The SD card ($TARGET_DEV) is ready."
echo "=========================================="