#!/bin/bash

list_interfaces() {
    ip link show | awk -F: '$0 !~ "lo|vir|@|docker|br-" && $0 ~ "^[0-9]+:" {print $2}' | tr -d ' '
}

ask_vlan() {
    INTERFACE=$1

    whiptail --title "⚠ VLAN Configuration Warning ⚠" --msgbox \
"VLAN (Virtual LAN) is an advanced networking feature.\n
Incorrect configuration may cause connectivity or security issues.\n
Only proceed if you understand VLANs.\n" 12 60

    if (whiptail --yesno "Do you want to configure VLAN for $INTERFACE?" 8 60); then
        vlan_menu
    fi
}

vlan_menu() {
    while true; do
        OPTION=$(whiptail --title "VLAN Configuration" --menu "Choose an option:" 15 60 4 \
        "1" "Show existing VLANs" \
        "2" "Add VLAN" \
        "3" "Delete VLAN" \
        "4" "Back to main menu" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            break
        fi

        case $OPTION in
            1) view_vlans ;;
            2) add_vlan ;;
            3) delete_vlan ;;
            4) break ;;
            *) ;;
        esac
    done
}

view_vlans() {
    VLANS=$(uci show network | grep 'switch_vlan')
    whiptail --title "Existing VLANs" --msgbox "$VLANS" 20 70
}

add_vlan() {
    VLAN_ID=$(whiptail --inputbox "Enter VLAN ID (e.g., 10):" 8 60 "10" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    VLAN_PORT=$(whiptail --inputbox "Enter VLAN port number (e.g., 0):" 8 60 "0" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    whiptail --yesno "Should the VLAN port be tagged?" 8 60
    if [ $? -ne 0 ]; then
        VLAN_TAGGED=""
    else
        VLAN_TAGGED="t"
    fi

    VLAN_NAME="vlan${VLAN_ID}"

    uci set network.${VLAN_NAME}=switch_vlan
    uci set network.${VLAN_NAME}.device='switch0'
    uci set network.${VLAN_NAME}.vlan="$VLAN_ID"
    uci set network.${VLAN_NAME}.ports="${VLAN_PORT}${VLAN_TAGGED}"

    uci commit network
    whiptail --msgbox "VLAN $VLAN_ID on port $VLAN_PORT ${VLAN_TAGGED:+(Tagged)} added." 8 60
}

delete_vlan() {
    VLANS=$(uci show network | grep 'switch_vlan' | awk -F. '{print $2}' | cut -d= -f1)
    options=()
    for v in $VLANS; do
        options+=("$v" "")
    done

    SELECTED=$(whiptail --title "Delete VLAN" --menu "Select a VLAN to delete:" 20 60 10 "${options[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    uci delete network."$SELECTED"
    uci commit network
    whiptail --msgbox "VLAN $SELECTED deleted." 8 60
}

configure_wan() {
    interfaces=$(list_interfaces)
    choices=()
    for i in $interfaces; do
        choices+=("$i" "")
    done

    SELECTED_WAN=$(whiptail --title "Select WAN Interface" --menu "Choose the WAN network interface:" 20 60 10 "${choices[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        return
    fi

    uci set network.wan=interface
    uci set network.wan.ifname="$SELECTED_WAN"
    uci set network.wan.proto='dhcp'
    uci commit network

    ask_vlan "$SELECTED_WAN"

    /etc/init.d/network restart
    whiptail --msgbox "WAN interface set to $SELECTED_WAN with DHCP." 8 60
}

configure_bridge() {
    interfaces=$(list_interfaces)
    choices=()
    for i in $interfaces; do
        choices+=("$i" "")
    done

    SELECTED_BRIDGE=$(whiptail --title "Select Bridge Interface" --menu "Choose the Bridge network interface:" 20 60 10 "${choices[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        return
    fi

    BRIDGE_IP=$(whiptail --inputbox "Enter static IP for Bridge:" 8 60 "192.168.1.2" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    BRIDGE_NETMASK=$(whiptail --inputbox "Enter Netmask:" 8 60 "255.255.255.0" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    BRIDGE_GATEWAY=$(whiptail --inputbox "Enter Gateway:" 8 60 "192.168.1.1" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    BRIDGE_DNS=$(whiptail --inputbox "Enter DNS:" 8 60 "8.8.8.8" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return; fi

    uci set network.lan=interface
    uci set network.lan.ifname="$SELECTED_BRIDGE"
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$BRIDGE_IP"
    uci set network.lan.netmask="$BRIDGE_NETMASK"
    uci set network.lan.gateway="$BRIDGE_GATEWAY"
    uci set network.lan.dns="$BRIDGE_DNS"
    uci commit network

    ask_vlan "$SELECTED_BRIDGE"

    /etc/init.d/network restart
    whiptail --msgbox "Bridge interface set to $SELECTED_BRIDGE with IP $BRIDGE_IP." 8 60
}

network_menu() {
    while true; do
        OPTION=$(whiptail --title "OpenWrt Network Configurator" --menu "Choose an option:" 15 60 4 \
        "1" "Configure WAN interface" \
        "2" "Configure Bridge interface" \
        "3" "Exit" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            break
        fi

        case $OPTION in
            1) configure_wan ;;
            2) configure_bridge ;;
            3) break ;;
            *) ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    network_menu
fi

bash setup.sh
