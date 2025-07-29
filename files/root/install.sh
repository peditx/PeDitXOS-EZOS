#!/bin/bash

OPENWRT_VERSION="23.05.3"
OPENWRT_URL="https://downloads.openwrt.org/releases"
ARCH1="x86"
ARCH2="64"
IMG_NAME="openwrt-${OPENWRT_VERSION}-x86-64-generic-squashfs-combined-efi.img.gz"
DOWNLOAD_PATH="/$IMG_NAME"

show_message() {
    whiptail --title "PeDitXOS" --msgbox "$1" 12 60
}

if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail is not installed. Please install it first."
    exit 1
fi

DOWNLOAD_URL="$OPENWRT_URL/${OPENWRT_VERSION}/targets/${ARCH1}/${ARCH2}/$IMG_NAME"

if whiptail --title "PeDitXOS Installer" --yesno "PeDitXOS Installer\n\nOpenWrt version: $OPENWRT_VERSION\n\nDownload now?" 12 60; then
    show_message "Downloading $IMG_NAME to root directory..."
    wget -O "$DOWNLOAD_PATH" "$DOWNLOAD_URL"

    if [ $? -ne 0 ]; then
        show_message "Error: Failed to download the image."
        exit 1
    fi

    show_message "Download Complete\nDecompressing image..."
    gzip -d "$DOWNLOAD_PATH"
    IMG_PATH="${DOWNLOAD_PATH%.gz}"
    show_message "Decompressed\nImage ready at $IMG_PATH"
else
    show_message "Download cancelled."
    exit 0
fi

DISKS=$(lsblk -dno NAME,SIZE | grep -E 'sd|vd|nvme')

if [ -z "$DISKS" ]; then
    show_message "Error: No disk found to flash!"
    exit 1
fi

OPTIONS=()
for disk in $DISKS; do
    size=$(lsblk -dno SIZE "/dev/$disk")
    OPTIONS+=("/dev/$disk" "$size")
done

TARGET_DISK=$(whiptail --title "PeDitXOS Installer" --menu "Select the disk to flash PeDitXOS (OpenWrt image):" 20 60 10 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [ -z "$TARGET_DISK" ]; then
    show_message "No disk selected. Exiting."
    exit 0
fi

if whiptail --title "PeDitXOS Installer" --yesno "Are you sure to flash $TARGET_DISK?\nThis will erase all data on the disk!" 12 60; then
    show_message "Flashing image to $TARGET_DISK..."
    dd if="$IMG_PATH" of="$TARGET_DISK" bs=4M conv=fsync
    sync
    show_message "Flashing completed successfully.\nReboot to start PeDitXOS."
else
    show_message "Flashing cancelled."
    exit 0
fi
