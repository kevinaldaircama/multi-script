#!/bin/bash

#==================================================
# KevinTech Multi Script
# CheckUser
#==================================================

BASE="/etc/kevintech"

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

check_installed() {
    [[ -f /usr/lib/chall/chall.sh ]]
}
status_checkuser() {
    if [[ -f /usr/lib/chall/chall.sh ]]; then
        echo -e "${GREEN}🟢 ACTIVO${RESET}"
    else
        echo -e "${RED}🔴 OFF${RESET}"
    fi
}

while true; do
    clear
    
    CHECKUSER_STATUS=$
(status_checkuser)

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}           🛡 KevinTech Multi Script${RESET}"
    echo -e "${WHITE}               MENÚ CHECKUSER${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    printf " ${GREEN}[01]${RESET} 👤 CheckUser Multi-Apps    %b\n" "$CHECKUSER_STATUS"
    echo -e " ${GREEN}[02]${RESET} 🌐 CheckUser DTunnel"
    echo -e " ${GREEN}[03]${RESET} 🚀 CheckUser DTunnel-Go"
    echo -e " ${GREEN}[04]${RESET} 🔗 online app"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${GREEN}[00]${RESET} ↩ Regresar"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo
    read -rp " ► Opción: " OP

    case "$OP" in

        1|01)
            if check_installed; then
                chall
            else
                bash <(curl -sL https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/instcheck.sh)
                [[ -x "$(command -v chall)" ]] && chall
            fi
        ;;

        2|02)
            bash <(curl -sL https://raw.githubusercontent.com/PhoenixxZ2023/DTCheckUser/master/install.sh)
        ;;

        3|03)
            bash <(curl -sL https://n9.cl/yo2nc)
        ;;

        4|04)
            onlineapp.sh
        ;;

        0|00)
            exec bash "$BASE/protocolos/menu.sh"
        ;;

        *)
            echo
            echo -e "${RED}❌ Opción inválida.${RESET}"
            sleep 2
        ;;
    esac
done
