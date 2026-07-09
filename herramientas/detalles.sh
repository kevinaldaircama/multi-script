#!/bin/bash

#==================================================
# KevinTech Multi Script
# Detalles del VPS
#==================================================

BASE="/etc/kevintech"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

clear

OS=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)
KERNEL=$(uname -r)
ARCH=$(uname -m)
HOST=$(hostname)

CPU=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //')
CORES=$(nproc)

RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
RAM_FREE=$(free -h | awk '/Mem:/ {print $4}')

DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
DISK_USE=$(df -h / | awk 'NR==2 {print $5}')

UPTIME=$(uptime -p)

LOAD=$(uptime | awk -F'load average:' '{print $2}')

IP=$(curl -4 -s ifconfig.me 2>/dev/null)

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}            📋 DETALLES DEL VPS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo -e "${WHITE}Sistema Operativo :${GREEN} $OS${RESET}"
echo -e "${WHITE}Kernel            :${GREEN} $KERNEL${RESET}"
echo -e "${WHITE}Arquitectura      :${GREEN} $ARCH${RESET}"
echo -e "${WHITE}Hostname          :${GREEN} $HOST${RESET}"
echo ""

echo -e "${WHITE}CPU               :${GREEN} $CPU${RESET}"
echo -e "${WHITE}Núcleos           :${GREEN} $CORES${RESET}"
echo ""

echo -e "${WHITE}RAM Total         :${GREEN} $RAM_TOTAL${RESET}"
echo -e "${WHITE}RAM Usada         :${YELLOW} $RAM_USED${RESET}"
echo -e "${WHITE}RAM Libre         :${GREEN} $RAM_FREE${RESET}"
echo ""

echo -e "${WHITE}Disco Total       :${GREEN} $DISK_TOTAL${RESET}"
echo -e "${WHITE}Disco Usado       :${YELLOW} $DISK_USED${RESET}"
echo -e "${WHITE}Disco Libre       :${GREEN} $DISK_FREE${RESET}"
echo -e "${WHITE}Uso del Disco     :${YELLOW} $DISK_USE${RESET}"
echo ""

echo -e "${WHITE}IP Pública        :${GREEN} $IP${RESET}"
echo -e "${WHITE}Uptime            :${GREEN} $UPTIME${RESET}"
echo -e "${WHITE}Carga Sistema     :${YELLOW}$LOAD${RESET}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -n1 -r -p "Presione una tecla para regresar..."

exec bash "$BASE/herramientas/menu.sh"
