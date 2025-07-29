#!/bin/bash

# set -euo pipefail

OPENWRT_VERSIONS=("24.10.2" "23.05.3" "Custom")

IMG_TYPE="generic-squashfs-combined-efi"
# IMG_TYPE="generic-ext4-combined-efi"

DOWNLOAD_DIR="/tmp"

OPENWRT_VERSION=""
OPENWRT_URL="https://downloads.openwrt.org/releases"
ARCH1="x86"
ARCH2="64"
IMG_NAME=""
DOWNLOAD_PATH=""

show_message() {
    whiptail --title "PeDitXOS Installer" --msgbox "$1" 12 70
}

if ! command -v whiptail >/dev/null 2>&1; then
    echo "Error: 'whiptail' is not installed. Please install it first."
    exit 1
fi

PV_AVAILABLE=false
if command -v pv >/dev/null 2>&1; then
    PV_AVAILABLE=true
fi

SHA256SUM_AVAILABLE=false
if command -v sha256sum >/dev/null 2>&1; then
    SHA256SUM_AVAILABLE=true
fi

while true; do
    VERSION_OPTIONS=()
    for ver in "${OPENWRT_VERSIONS[@]}"; do
        VERSION_OPTIONS+=("$ver" "")
    done
    SELECTED_VERSION_OPTION=$(whiptail --title "OpenWrt Version" --menu "Select OpenWrt Version:" 15 60 5 "${VERSION_OPTIONS[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$SELECTED_VERSION_OPTION" ]; then
        show_message "No OpenWrt version selected. Exiting."
        exit 0
    fi

    if [ "$SELECTED_VERSION_OPTION" == "Custom" ]; then
        CUSTOM_VERSION=$(whiptail --title "Custom Version" --inputbox "Enter custom version (e.g., 24.10.3):" 10 60 "" 3>&1 1>&2 2>&3)
        [ -z "$CUSTOM_VERSION" ] && continue
        OPENWRT_VERSION="$CUSTOM_VERSION"
    else
        OPENWRT_VERSION="$SELECTED_VERSION_OPTION"
    fi

    IMG_NAME="openwrt-${OPENWRT_VERSION}-${ARCH1}-${ARCH2}-${IMG_TYPE}.img.gz"
    DOWNLOAD_URL="$OPENWRT_URL/${OPENWRT_VERSION}/targets/${ARCH1}/${ARCH2}/$IMG_NAME"
    DOWNLOAD_PATH="$DOWNLOAD_DIR/$IMG_NAME"
    
    show_message "Verifying OpenWrt version existence...\nURL: $DOWNLOAD_URL"
    if ! wget --spider -q "$DOWNLOAD_URL"; then
        show_message "Error: Image does not exist for this version/type.\n\nURL checked:\n$DOWNLOAD_URL"
        continue
    fi

    if whiptail --title "Confirm Download" --yesno "OpenWrt version: $OPENWRT_VERSION\nImage type: $IMG_TYPE\n\nDownload now?" 12 70; then
        show_message "Starting download of $IMG_NAME..."
        mkdir -p "$DOWNLOAD_DIR"
        
        wget -q --show-progress --output-document="$DOWNLOAD_PATH" "$DOWNLOAD_URL" 2>&1 | 
        (
            trap "kill $!" EXIT
            PERCENT_OLD=0
            while IFS= read -r line; do
                PERCENTAGE=$(echo "$line" | grep -o '[0-9]*%' | tr -d '%' | tail -n 1)
                if [[ "$PERCENTAGE" =~ ^[0-9]+$ && "$PERCENTAGE" -gt "$PERCENT_OLD" ]]; then
                    echo "$PERCENTAGE"
                    PERCENT_OLD=$PERCENTAGE
                fi
            done
        ) | whiptail --gauge "Downloading $IMG_NAME..." 8 70 0

        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            show_message "Error: Failed to download the image. Please check your internet connection."
            rm -f "$DOWNLOAD_PATH"
            continue
        fi

        if [ ! -s "$DOWNLOAD_PATH" ]; then
            show_message "Error: Downloaded file is empty. The storage at '$DOWNLOAD_DIR' might be full."
            rm -f "$DOWNLOAD_PATH"
            continue
        fi
        
        show_message "Download complete. Verifying integrity..."
        
        if $SHA256SUM_AVAILABLE; then
            CHECKSUM_URL="$OPENWRT_URL/${OPENWRT_VERSION}/targets/${ARCH1}/${ARCH2}/sha256sums"
            EXPECTED_SHA256=$(wget -qO- "$CHECKSUM_URL" | grep "$IMG_NAME" | awk '{print $1}')
            
            if [ -n "$EXPECTED_SHA256" ]; then
                CURRENT_SHA256=$(sha256sum "$DOWNLOAD_PATH" | awk '{print $1}')
                if [ "$EXPECTED_SHA256" != "$CURRENT_SHA256" ]; then
                    if ! whiptail --title "Checksum Mismatch!" --yesno "WARNING: Checksum does not match. The file might be corrupted.\n\nContinue anyway?"; then
                        rm -f "$DOWNLOAD_PATH"
                        continue
                    fi
                else
                    show_message "Checksum OK. File integrity verified."
                fi
            fi
        fi

        show_message "Starting decompression..."
        IMG_PATH="${DOWNLOAD_PATH%.gz}"
        
        if $PV_AVAILABLE; then
            (pv "$DOWNLOAD_PATH" | zcat > "$IMG_PATH") 2>&1 | whiptail --gauge "Decompressing..." 8 70 0
        else
            zcat "$DOWNLOAD_PATH" > "$IMG_PATH"
        fi
        
        if [ ${PIPESTATUS[0]} -ne 0 ] && [ ${PIPESTATUS[1]} -ne 0 ]; then
             show_message "Error: Decompression failed. The downloaded file might be corrupted."
             rm -f "$DOWNLOAD_PATH" "$IMG_PATH"
             continue
        fi

        if [ ! -s "$IMG_PATH" ]; then
            show_message "Error: Decompression resulted in an empty file. Not enough space or corrupted source."
            rm -f "$DOWNLOAD_PATH" "$IMG_PATH"
            continue
        fi
        
        rm -f "$DOWNLOAD_PATH"
        show_message "Decompression successful.\nImage ready at: $IMG_PATH"
        
    else
        continue
    fi

    DISKS_INFO=$(lsblk -dno NAME,SIZE,MODEL -e 7)
    if [ -z "$DISKS_INFO" ]; then
        show_message "Error: No physical disk found to flash!"
        continue
    fi

    OPTIONS=()
    while read -r line; do
        if [ -n "$line" ]; then
            name=$(echo "$line" | awk '{print $1}')
            details=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')
            OPTIONS+=("/dev/$name" "$details")
        fi
    done <<< "$DISKS_INFO"

    TARGET_DISK=$(whiptail --title "Select Target Disk" --menu "Select the disk to flash:" 20 78 10 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    [ -z "$TARGET_DISK" ] && continue

    if whiptail --title "FINAL WARNING" --yesno "ARE YOU SURE you want to ERASE and flash $TARGET_DISK?" 12 70; then
        
        show_message "Flashing image to $TARGET_DISK..."

        dd if="$IMG_PATH" of="$TARGET_DISK" bs=4M conv=fsync status=progress 2>&1 | 
        whiptail --gauge "Flashing... DO NOT INTERRUPT!" 8 70 0

        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            show_message "Error: Flashing failed!"
            continue
        fi

        rm -f "$IMG_PATH"
        sync
        show_message "Flashing completed successfully.\nReboot to start PeDitXOS."
        break
    else
        continue
    fi
done
