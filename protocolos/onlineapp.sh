#!/bin/bash
# ==========================================================
#        KevinTech Multi Script - Online App Manager
# ==========================================================

BASE="/etc/kevintech"
ONLINEAPP="/usr/local/bin/onlineapp"

GREEN="\e[1;92m"
RED="\e[1;91m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
RESET="\e[0m"

IP=$(wget -qO- ipv4.icanhazip.com)

start_onlineapp() {

    apt install apache2 -y >/dev/null 2>&1

    sed -i 's/^Listen 80$/Listen 8888/' /etc/apache2/ports.conf >/dev/null 2>&1

    mkdir -p /var/www/html/server

    service apache2 restart >/dev/null 2>&1

    screen -dmS onlineapp "$ONLINEAPP"

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      KevinTech Multi Script${RESET}"
    echo -e "${WHITE}          ONLINE APP${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo -e "${GREEN}✓ Online App iniciada correctamente.${RESET}"
    echo
    echo -e "${WHITE}URL Texto:${RESET}"
    echo "http://$IP:8888/server/online"
    echo
    echo -e "${WHITE}URL JSON:${RESET}"
    echo "http://$IP:8888/server/online_app"
}

stop_onlineapp() {

    screen -S onlineapp -X quit >/dev/null 2>&1
    pkill -f "$ONLINEAPP" >/dev/null 2>&1

    service apache2 stop >/dev/null 2>&1

    rm -rf /var/www/html/server >/dev/null 2>&1

    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}      KevinTech Multi Script${RESET}"
    echo -e "${WHITE}          ONLINE APP${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo -e "${RED}✓ Online App detenida correctamente.${RESET}"
}

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}      KevinTech Multi Script${RESET}"
echo -e "${WHITE}          ONLINE APP${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

if pgrep -f "$ONLINEAPP" >/dev/null; then
    echo -e "Estado: ${GREEN}ACTIVO${RESET}"
    echo
    stop_onlineapp
else
    echo -e "Estado: ${RED}DETENIDO${RESET}"
    echo
    start_onlineapp
fi

echo
read -n1 -s -r -p "Presione cualquier tecla para volver..."
exec bash "$BASE/protocolos/checkuser.sh"
