#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
YELLOW="\e[1;93m"
RESET="\e[0m"

SERVICE1="badvpn-udpgw-7300"
SERVICE2="badvpn-udpgw-7200"

PORT1="7300"
PORT2="7200"

BIN="/usr/local/bin/badvpn-udpgw"
while true; do

clear

source "$CONFIG"

if [[ "$BADVPN" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}            🌐 BADVPN MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado      : $STATUS"
echo -e " Puerto 1    : $PORT1"
echo -e " Puerto 2    : $PORT2"
echo -e " Servicio    : BadVPN UDPGW"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$BADVPN" == "ON" ]]; then
cat <<EOF
 [1] ➮ Reinstalar BadVPN
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [4] ➮ Desinstalar
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar BadVPN
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in
