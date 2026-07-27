#!/bin/bash

BASE="/etc/kevintech"
ONLINEAPP="/usr/local/bin/onlineapp"

GREEN="\e[1;92m"
RED="\e[1;91m"
CYAN="\e[1;96m"
RESET="\e[0m"

start_onlineapp() {
    mkdir -p /var/www/html/server

    if ! pgrep -f "$ONLINEAPP" >/dev/null; then
        screen -dmS onlineapp "$ONLINEAPP"
        echo -e "\n${GREEN}✓ Online App iniciada correctamente.${RESET}"
    else
        echo -e "\n${RED}La Online App ya está en ejecución.${RESET}"
    fi
}

stop_onlineapp() {
    pkill -f "$ONLINEAPP"
    screen -wipe >/dev/null 2>&1

    echo -e "\n${RED}✓ Online App detenida.${RESET}"
}

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "     KevinTech Online App"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if pgrep -f "$ONLINEAPP" >/dev/null; then
    echo -e "Estado: ${GREEN}● ACTIVO${RESET}"
    echo
    read -rp "¿Detener Online App? [S/N]: " op

    [[ "$op" =~ ^[Ss]$ ]] && stop_onlineapp
else
    echo -e "Estado: ${RED}● DETENIDO${RESET}"
    echo
    read -rp "¿Iniciar Online App? [S/N]: " op

    [[ "$op" =~ ^[Ss]$ ]] && start_onlineapp
fi

echo
read -n1 -s -r -p "Presione cualquier tecla para volver..."
exec bash "$BASE/protocolos/checkuser.sh"
