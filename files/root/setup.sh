#!/bin/bash

enable_luci_wan() {
    whiptail --title "SECURITY WARNING" --yesno "⚠️ WARNING: Enabling LuCI on WAN ⚠️\n\nThis will expose your router's web interface to the Internet!\n\n• Potential security risk\n• Only enable for temporary access\n• Use strong password\n• Consider disabling after use\n\nDo you want to continue?" \
    --yes-button "I Understand the Risk" --no-button "Cancel" 14 65 || return

    uci set firewall.luci_wan=rule
    uci set firewall.luci_wan.name='Allow-LuCI-WAN'
    uci set firewall.luci_wan.src='wan'
    uci set firewall.luci_wan.dest_port='80 443'
    uci set firewall.luci_wan.proto='tcp'
    uci set firewall.luci_wan.target='ACCEPT'
    uci commit firewall
    /etc/init.d/firewall restart

    WAN_IP=$(ifstatus wan | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
    [ -z "$WAN_IP" ] && WAN_IP="your WAN IP"

    whiptail --title "LuCI Enabled on WAN" --msgbox "✅ LuCI access enabled on WAN interface!\n\nAccess your router at:\nhttp://$WAN_IP\n\n⚠️ Remember to disable this when not needed!\n\nTo disable later:\n1. Go to Network → Firewall\n2. Delete 'Allow-LuCI-WAN' rule\n3. Or run: uci delete firewall.luci_wan && uci commit firewall && /etc/init.d/firewall restart" 16 65
}

system_reboot() {
    if whiptail --title "System Reboot" --yesno "Are you sure you want to 🔴 REBOOT 🔴 the system now?" 10 60; then
        echo "System rebooting..."
        reboot
    else
        echo "Reboot cancelled."
    fi
}

HEIGHT=15
WIDTH=40
CHOICE_HEIGHT=7
TITLE="PeDitX EZOS Menu"
MENU="Choose one of the following options:"

CHOICE=$(whiptail --title "$TITLE" --menu "$MENU" \
    $HEIGHT $WIDTH $CHOICE_HEIGHT \
    "1" "Install on X86-64 machine" \
    "2" "DNS Changer" \
    "3" "Enable LuCI on WAN" \
    "4" "Network Configurator" \
    "5" "🔥 Reboot System 🔴" \
    3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus -eq 0 ]; then
    case $CHOICE in
        1)
            bash install.sh
            ;;
        2)
            bash dns.sh
            ;;
        3)
            enable_luci_wan
            ;;
        4)
            bash network.sh
            ;;
        5)
            system_reboot
            ;;
    esac
else
    echo "Operation cancelled."
    exit 1
fi
