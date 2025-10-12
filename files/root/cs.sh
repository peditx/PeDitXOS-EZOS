#!/bin/bash
# PeDitXOS (OpenWrt) Universal Image Flasher
# This script allows downloading an image from a custom URL and flashing it to a disk.

# --- Functions ---

# Function to display messages using whiptail
show_message() {
    whiptail --title "PeDitXOS Installer" --msgbox "$1" 12 70
}

# --- Initial Checks ---

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# 2. Check if whiptail is installed
if ! command -v whiptail >/dev/null 2>&1; then
    echo "Error: whiptail is not installed. Please install it first (e.g., 'sudo apt-get install whiptail')."
    exit 1
fi

# --- Main Logic ---

# 1. Get the image URL from the user
CUSTOM_URL=$(whiptail --title "Image URL" --inputbox "Please enter the direct download URL for the .img or .img.gz file:" 12 70 3>&1 1>&2 2>&3)

# Exit if user pressed Cancel or entered nothing
if [ -z "$CUSTOM_URL" ]; then
    show_message "No URL entered. Exiting."
    exit 0
fi

# 2. Prepare for download
IMG_NAME=$(basename "$CUSTOM_URL")
DOWNLOAD_PATH="/tmp/$IMG_NAME"

# Check for valid file extension (.img or .img.gz)
if [[ ! "$IMG_NAME" == *.gz && ! "$IMG_NAME" == *.img ]]; then
    show_message "Error: Unsupported file type.\nPlease provide a URL to a .img.gz or .img file."
    exit 1
fi

# 3. Confirm download with the user
if whiptail --title "Confirm Download" --yesno "You are about to download:\n\n$IMG_NAME\n\nFrom URL:\n$CUSTOM_URL\n\nContinue?" 15 70; then
    show_message "Starting download for $IMG_NAME..."
    # Download the file and show a progress bar
    wget --progress=bar:force -O "$DOWNLOAD_PATH" "$CUSTOM_URL" 2>&1 | \
    stdbuf -o0 awk '/%/ { print substr($7, 1, length($7)-1) }' | \
    whiptail --gauge "Downloading..." 6 70 0

    # Check wget's exit status from the pipe
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        show_message "Error: Failed to download the image. Please check the URL and your internet connection."
        rm -f "$DOWNLOAD_PATH"
        exit 1
    fi
else
    show_message "Download cancelled."
    exit 0
fi

# 4. Decompress the image if it's a .gz file
if [[ "$IMG_NAME" == *.gz ]]; then
    show_message "Download Complete!\nDecompressing image..."
    gzip -d "$DOWNLOAD_PATH"
    if [ $? -ne 0 ]; then
        show_message "Error: Failed to decompress the image. The file may be corrupted."
        rm -f "$DOWNLOAD_PATH"
        exit 1
    fi
    IMG_PATH="${DOWNLOAD_PATH%.gz}"
    show_message "Decompression complete.\nImage is ready at: $IMG_PATH"
else # This is for .img files
    IMG_PATH="$DOWNLOAD_PATH"
    show_message "Download complete.\nImage is ready at: $IMG_PATH"
fi

# 5. Select the target disk (Using corrected and safer logic)
# Use mapfile to read lsblk output safely into an array
mapfile -t DISK_LINES < <(lsblk -d -p -n -o NAME,SIZE | grep -E 'sd|vd|nvme|mmcblk')

if [ ${#DISK_LINES[@]} -eq 0 ]; then
    show_message "Error: No suitable disks found (sd, vd, nvme, mmcblk)!"
    exit 1
fi

OPTIONS=()
for line in "${DISK_LINES[@]}"; do
    # Read the name and size from each line into separate variables
    read -r name size <<< "$line"
    OPTIONS+=("$name" "Size: $size")
done

TARGET_DISK=$(whiptail --title "Select Target Disk" --menu "WARNING: ALL DATA WILL BE ERASED!\nSelect the disk to flash the image to:" 20 70 12 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [ -z "$TARGET_DISK" ]; then
    show_message "No disk selected. Exiting."
    rm -f "$IMG_PATH" # Clean up the downloaded file
    exit 0
fi

# 6. Final confirmation before erasing the disk
if whiptail --title "FINAL WARNING" --yesno "Are you absolutely sure you want to flash:\n$IMG_PATH\n\nTO DISK:\n$TARGET_DISK\n\nTHIS WILL PERMANENTLY ERASE ALL DATA ON $TARGET_DISK!" 15 70; then
    show_message "Flashing image to $TARGET_DISK...\nThis may take a while. Please be patient and do not interrupt the process."
    
    # Flash using dd command
    dd if="$IMG_PATH" of="$TARGET_DISK" bs=4M conv=fsync status=progress
    
    sync # Ensure all data is written to the disk
    show_message "Flashing completed successfully!\nYou can now reboot your system."
else
    show_message "Flashing cancelled."
fi

# 7. Final cleanup
echo "Operation finished. Cleaning up temporary files..."
rm -f "$IMG_PATH"
# If the original file was .gz, the compressed file might still exist if decompression failed.
if [ "$IMG_PATH" != "$DOWNLOAD_PATH" ]; then
    rm -f "$DOWNLOAD_PATH"
fi

echo "Cleanup complete. Exiting."
exit 0
