#!/bin/sh

# ==============================================================================
# ezOS LuCI Application - Uninstaller v1.0
# This script completely removes the ezOS Flasher tool and all its components.
# ==============================================================================

# --- Helper Functions ---
log_success() {
    echo "[SUCCESS] $1"
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Uninstall Logic ---
uninstall_package() {
    log_info "Starting ezOS LuCI App uninstallation..."

    # Step 1: Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root. Please use 'su' or 'sudo'."
    fi

    # Step 2: Stop and disable any old service (ignore errors)
    /etc/init.d/ezos stop >/dev/null 2>&1
    /etc/init.d/ezos disable >/dev/null 2>&1

    # Step 3: Remove all files associated with the ezOS Flasher
    log_info "Removing files..."
    rm -f /etc/config/ezos
    rm -f /etc/init.d/ezos
    rm -f /usr/bin/ezos_flash.sh
    rm -f /usr/lib/lua/luci/controller/ezos.lua
    rm -f /usr/lib/lua/luci/controller/ezos_status.lua # Ensure old conflicting file is gone
    rm -f /usr/lib/lua/luci/model/cbi/ezos.lua
    rm -rf /usr/lib/lua/luci/view/ezos

    # Step 4: Remove the WAN firewall rule for LuCI
    log_info "Removing WAN firewall rule for LuCI..."
    if uci -q get firewall.luci_wan >/dev/null 2>&1; then
        uci delete firewall.luci_wan
        uci commit firewall
        /etc/init.d/firewall restart >/dev/null 2>&1
        log_success "WAN firewall rule removed."
    else
        log_info "WAN firewall rule not found, skipping."
    fi

    # Step 5: Clear LuCI cache to remove the menu entry
    log_info "Clearing LuCI cache..."
    rm -f /tmp/luci-indexcache

    log_success "ezOS LuCI App has been completely uninstalled."
    log_info "You may need to log out and log back into LuCI for the menu to disappear."
    log_info "This script will now self-destruct."

    # Step 6: Self-destruct
    rm -- "$0"
}

# --- Script Entry Point ---
uninstall_package
