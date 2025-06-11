#!/bin/bash

# USAGE: sudo ./Restore_Pi_Sd_Card.sh backupfilename.tar.gz /dev/sdX
# Example: sudo ./Restore_Pi_Sd_Card.sh pi_backup.tar.gz /dev/sdb

set -euxo pipefail

BACKUP_ARCHIVE="$1"
RESTORE_DEV="$2"

if [[ -z "$BACKUP_ARCHIVE" || -z "$RESTORE_DEV" ]]; then
  echo "Usage: sudo $0 backupfilename.tar.gz /dev/sdX"
  exit 1
fi

if [ ! -f "$BACKUP_ARCHIVE" ]; then
  echo "Error: Backup archive not found."
  exit 1
fi

read -p "This will erase all data on $RESTORE_DEV. Continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

BOOT_PART="${RESTORE_DEV}1"
ROOT_PART="${RESTORE_DEV}2"

# Partition the SD card
echo "Creating partition table on $RESTORE_DEV..."
parted --script "$RESTORE_DEV" mklabel msdos
parted --script "$RESTORE_DEV" mkpart primary fat32 1MiB 256MiB
parted --script "$RESTORE_DEV" mkpart primary ext4 256MiB 100%

sleep 1

# Format partitions
echo "Formatting partitions..."
mkfs.vfat "$BOOT_PART"
mke2fs -F -t ext4 "$ROOT_PART"

# Create mount points
mkdir -p /mnt/sd_boot /mnt/sd_root

# Mount partitions
echo "Mounting partitions..."
mount "$BOOT_PART" /mnt/sd_boot
mount "$ROOT_PART" /mnt/sd_root

# Extract the backup archive
TEMP_DIR=$(mktemp -d)
echo "Extracting backup archive to $TEMP_DIR..."
tar -I zstd -xf "$BACKUP_ARCHIVE" -C "$TEMP_DIR"

# Locate actual backup folder
BACKUP_ROOT=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [[ ! -d "$BACKUP_ROOT/boot" || ! -d "$BACKUP_ROOT/root" ]]; then
  echo "Error: Extracted backup does not contain boot/ and root/ folders in expected structure."
  umount /mnt/sd_boot || true
  umount /mnt/sd_root || true
  rmdir /mnt/sd_boot /mnt/sd_root || true
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Copy files to partitions
echo "Restoring boot partition..."
rsync -aAXH --whole-file --bwlimit=20m --inplace --info=progress2 "$BACKUP_ROOT/boot/" /mnt/sd_boot
sync
echo 3 > /proc/sys/vm/drop_caches
sync

echo "Restoring root partition..."
rsync -aAXH --whole-file --bwlimit=20m --inplace --info=progress2 "$BACKUP_ROOT/root/" /mnt/sd_root
sync
echo 3 > /proc/sys/vm/drop_caches
sync

# Fix fstab and cmdline.txt with new PARTUUIDs
BOOT_UUID=$(blkid -s PARTUUID -o value "$BOOT_PART")
ROOT_UUID=$(blkid -s PARTUUID -o value "$ROOT_PART")

echo "Updating fstab and cmdline.txt with new PARTUUIDs..."
sed -i "s|PARTUUID=[^ ]\+|PARTUUID=$ROOT_UUID|" /mnt/sd_boot/cmdline.txt
sed -i "s|PARTUUID=[^ ]\+\s\+/boot|PARTUUID=$BOOT_UUID  /boot|" /mnt/sd_root/etc/fstab
sed -i "s|PARTUUID=[^ ]\+\s\+/\s|PARTUUID=$ROOT_UUID  / |" /mnt/sd_root/etc/fstab

# Sync and unmount
echo "Syncing and unmounting..."
sync
sleep 3
umount /mnt/sd_boot || true
umount /mnt/sd_root || true
sleep 1
rmdir /mnt/sd_boot /mnt/sd_root || true

rm -rf "$TEMP_DIR"

# Eject device
sync
udisksctl unmount -b "$BOOT_PART" 2>/dev/null || true
udisksctl unmount -b "$ROOT_PART" 2>/dev/null || true
udisksctl power-off -b "$RESTORE_DEV" 2>/dev/null || true

echo "Restore completed successfully."
