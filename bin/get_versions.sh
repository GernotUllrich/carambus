#!/bin/bash

# IP-Address
IPADDRESS=$(ifconfig -a |grep 'netmask 255.255.255.0' |grep -oE 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk '{print $2}')
# Modell
MODEL=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0' || echo "Unbekannt")
# OS-Version
OS=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2- | tr -d '\0' | tr -d '"' || echo "Unbekannt")
# Architektur
ARCH=$(uname -m)
# Linux Partition
SD=$(sudo fdisk -l /dev/mmcblk0 2>/dev/null | grep Linux | awk '{print $5}' || echo "Unbekannt")
# RAM
RAM=$(free -hm)
echo "IP-Address: $IPADDRESS"
echo "Modell: $MODEL"
echo "OS-Version: $OS"
echo "Architektur: $ARCH"
echo "SD-Karte: $SD"
echo "RAM: $RAM"
# Versuch per XDG Variablen
if [ -n "$XDG_CURRENT_DESKTOP" ]; then
  echo "Desktop-Environment: $XDG_CURRENT_DESKTOP"
elif [ -n "$DESKTOP_SESSION" ]; then
  echo "Desktop-Environment: $DESKTOP_SESSION"
elif [ -n "$GDMSESSION" ]; then
  echo "Desktop-Environment: $GDMSESSION"
else
  # Fallback: Prozessliste prüfen
  de=$(ps -e | egrep -io "gnome|kde|mate|cinnamon|lxde|xfce|jwm" | head -1)
  if [ -n "$de" ]; then
    echo "Desktop-Environment (Prozess): $de"
  else
    echo "Desktop-Environment nicht erkannt"
  fi
fi
iwlist wlan0 channel
iwconfig wlan0
