#!/usr/bin/env bash
# macOS RAM disk for /private/tmp
# Creates a 1GB RAM disk mounted at /private/tmp if not already mounted

set -euo pipefail

# Configuration
RAMFS_SIZE_MB=1024
MOUNT_POINT="/private/tmp"
VOLUME_NAME="RAM-Disk"

# Check if we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is for macOS only" >&2
    exit 1
fi

# Check if already mounted
if mount | grep -q "on ${MOUNT_POINT} "; then
    echo "RAM disk already mounted on ${MOUNT_POINT}"
    exit 0
fi

# Check if we have required tools
if ! command -v hdiutil >/dev/null 2>&1; then
    echo "hdiutil not found - required for RAM disk creation" >&2
    exit 1
fi

if ! command -v diskutil >/dev/null 2>&1; then
    echo "diskutil not found - required for disk formatting" >&2
    exit 1
fi

# Create and format RAM disk in one step
echo "Creating and formatting ${RAMFS_SIZE_MB}MB RAM disk..."
RAMFS_SIZE_SECTORS=$((RAMFS_SIZE_MB * 2048))

# Create RAM disk and format it directly
RAMDISK_DEV=$(hdiutil attach -nomount "ram://${RAMFS_SIZE_SECTORS}" | tr -d '[:space:]')

if [[ -z "$RAMDISK_DEV" ]]; then
    echo "Failed to create RAM disk device" >&2
    exit 2
fi

echo "RAM disk device created: ${RAMDISK_DEV}"

# Give the system a moment to register the device
sleep 1

# Partition and format the RAM disk with case-sensitive APFS
echo "Partitioning and formatting as case-sensitive APFS..."
if ! diskutil partitionDisk "$RAMDISK_DEV" 1 GPT "Case-sensitive APFS" "$VOLUME_NAME" 100%; then
    echo "Failed to partition/format RAM disk on: ${RAMDISK_DEV}" >&2
    hdiutil detach "$RAMDISK_DEV" 2>/dev/null || true
    exit 3
fi

# Find the actual APFS volume (not the container)
echo "Finding APFS volume..."
sleep 2  # Give APFS time to create the volume
APFS_VOLUME=$(diskutil list | grep -A 10 "$RAMDISK_DEV" | grep "APFS Volume" | grep "$VOLUME_NAME" | awk '{print $NF}')

if [[ -z "$APFS_VOLUME" ]]; then
    echo "Could not find APFS volume for $VOLUME_NAME" >&2
    diskutil list "$RAMDISK_DEV"
    hdiutil detach "$RAMDISK_DEV" 2>/dev/null || true
    exit 4
fi

echo "Found APFS volume: $APFS_VOLUME"

# Use diskutil to mount at the desired location (requires sudo once)
echo "Mounting RAM disk at ${MOUNT_POINT}..."
if ! sudo diskutil mount -mountPoint "$MOUNT_POINT" "/dev/$APFS_VOLUME"; then
    echo "Failed to mount /dev/$APFS_VOLUME at ${MOUNT_POINT}" >&2
    hdiutil detach "$RAMDISK_DEV" 2>/dev/null || true
    exit 4
fi

# Set proper permissions
sudo chown root:wheel "$MOUNT_POINT"
sudo chmod 1777 "$MOUNT_POINT"

echo "RAM disk successfully mounted at ${MOUNT_POINT} (${RAMFS_SIZE_MB}MB)"