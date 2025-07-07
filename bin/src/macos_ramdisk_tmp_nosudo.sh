#!/usr/bin/env bash
# macOS RAM disk for tmp without requiring sudo
# Creates a 1GB RAM disk and makes it accessible as ~/tmp-ramdisk

set -euo pipefail

# Configuration
RAMFS_SIZE_MB=1024
VOLUME_NAME="RAM-Disk-Tmp"
RAMDISK_PATH="$HOME/tmp-ramdisk"

# Check if we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is for macOS only" >&2
    exit 1
fi

# Check if already set up
if [[ -d "$RAMDISK_PATH" ]] && mount | grep -q "$RAMDISK_PATH"; then
    # Double-check by looking at the filesystem type
    fs_type=$(mount | grep "$RAMDISK_PATH" | awk '{print $5}' | head -1)
    if [[ "$fs_type" == "apfs" ]]; then
        echo "RAM disk already mounted at $RAMDISK_PATH (filesystem: $fs_type)"
        exit 0
    else
        echo "WARNING: $RAMDISK_PATH is mounted but filesystem type is $fs_type (not apfs)"
        echo "Continuing to try mounting the RAM disk..."
    fi
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

# The disk will be auto-mounted at /Volumes/$VOLUME_NAME
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Wait for auto-mount
echo "Waiting for auto-mount..."
sleep 2

# Verify mount
if ! mount | grep -q "$MOUNT_POINT"; then
    echo "Auto-mount failed, trying manual mount..."
    if ! diskutil mount "/dev/$APFS_VOLUME"; then
        echo "Failed to mount /dev/$APFS_VOLUME" >&2
        hdiutil detach "$RAMDISK_DEV" 2>/dev/null || true
        exit 5
    fi
fi

# Create symlink to user-accessible location
echo "Creating symlink at $RAMDISK_PATH..."
[[ -L "$RAMDISK_PATH" ]] && rm "$RAMDISK_PATH"
[[ -d "$RAMDISK_PATH" ]] && rmdir "$RAMDISK_PATH" 2>/dev/null || true
ln -s "$MOUNT_POINT" "$RAMDISK_PATH"

# Set proper permissions on the mount point
chmod 1777 "$MOUNT_POINT"

echo "RAM disk successfully created at $MOUNT_POINT"
echo "Accessible via symlink at $RAMDISK_PATH"
echo "Size: ${RAMFS_SIZE_MB}MB"