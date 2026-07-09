#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}        🔄 REINICIAR SERVICIOS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

SERVICIOS=(
ssh
dropbear
nginx
stunnel4
badvpn
udp-custom
websocket
slowdns
zipvpn
)

for S in "${SERVICIOS[@]}"
do

if systemctl list-unit-files | grep -q "^${S}.service"; then

printf "%-15s" "$S"

systemctl restart "$S" >/dev/null 2>&1

sleep 1

if systemctl is-active --quiet "$S"; then

echo -e "${GREEN}✅ OK${RESET}"

else

echo -e "${RED}❌ ERROR${RESET}"

fi

fi

done

echo ""
read -n1 -r -p "Presione una tecla para regresar..."

exec bash "$BASE/herramientas/menu.sh"
