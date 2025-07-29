#!/bin/sh

CHOICE=$(whiptail --title "DNS Changer" --menu "Choose a DNS provider:" 20 78 12 \
"1" "Google (8.8.8.8, 8.8.4.4)" \
"2" "iCloud (1.1.1.1, 1.1.1.2)" \
"3" "Shecan (185.51.200.2, 178.22.122.100)" \
"4" "Begzar (185.55.226.26, 185.55.225.25)" \
"5" "Electro (78.157.42.101, 78.157.42.100)" \
"6" "Shelter (91.92.255.160, 91.92.255.242)" \
"7" "Radar (10.202.10.10, 10.202.10.11)" \
"8" "Custom (Enter two IP addresses manually)" \
"9" "Use WAN Gateway IP as DNS" 3>&1 1>&2 2>&3)

EXIT_STATUS=$?
if [ $EXIT_STATUS -ne 0 ]; then
    bash setup.sh
fi

case $CHOICE in
  1)
    DNS1="8.8.8.8"
    DNS2="8.8.4.4"
    ;;
  2)
    DNS1="1.1.1.1"
    DNS2="1.1.1.2"
    ;;
  3)
    DNS1="185.51.200.2"
    DNS2="178.22.122.100"
    ;;
  4)
    DNS1="185.55.226.26"
    DNS2="185.55.225.25"
    ;;
  5)
    DNS1="78.157.42.101"
    DNS2="78.157.42.100"
    ;;
  6)
    DNS1="91.92.255.160"
    DNS2="91.92.255.242"
    ;;
  7)
    DNS1="10.202.10.10"
    DNS2="10.202.10.11"
    ;;
  8)
    DNS1=$(whiptail --inputbox "Enter first DNS IP:" 8 39 --title "Custom DNS" 3>&1 1>&2 2>&3)
    DNS2=$(whiptail --inputbox "Enter second DNS IP:" 8 39 --title "Custom DNS" 3>&1 1>&2 2>&3)
    ;;
  9)
    GATEWAY_IP=$(ip route show default | grep 'dev wan' | awk '{print $3}')
    if [ -z "$GATEWAY_IP" ]; then
      GATEWAY_IP=$(ip route show default | awk '{print $3}' | head -n1)
    fi
    if [ -z "$GATEWAY_IP" ]; then
      whiptail --msgbox "Failed to detect WAN Gateway IP." 10 50
      bash setup.sh
    fi
    DNS1="$GATEWAY_IP"
    DNS2="$GATEWAY_IP"
    ;;
  *)
    bash setup.sh
    ;;
esac

uci set network.wan.dns="${DNS1} ${DNS2}"
uci commit network
/etc/init.d/network restart

whiptail --msgbox "DNS updated to: ${DNS1}, ${DNS2}" 10 50

bash setup.sh
