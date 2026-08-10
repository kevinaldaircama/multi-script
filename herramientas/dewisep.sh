#!/bin/bash
#==================================================
# KevinTech Multi Script
# Privanox Bot (usa install_go.sh original)
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
NC="\e[0m"

SERVICE="depwise.service"

pause() {
    read -rp "Presiona ENTER para continuar..."
}

status_privanox() {
    if systemctl list-unit-files | grep -q "^${SERVICE}"; then
        if systemctl is-active --quiet ${SERVICE}; then
            echo -e "${GREEN}● Privanox Bot: ACTIVO${NC}"
        else
            echo -e "${YELLOW}● Privanox Bot: INSTALADO (DETENIDO)${NC}"
        fi
    else
        echo -e "${RED}● Privanox Bot: NO INSTALADO${NC}"
    fi
}

install_privanox() {
    clear
    echo -e "${CYAN}====================================${NC}"
    echo -e "${WHITE}     PRIVANOX BOT (INSTALADOR ORIGINAL)${NC}"
    echo -e "${CYAN}====================================${NC}"
    echo

    # Llama al install_go.sh ORIGINAL.
    # Si INSTALL_KEY ya fue exportada por el instalador principal,
    # install_go.sh NO volverá a pedir la key.
    bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/privanox-code/main/install_go.sh)

    echo
    status_privanox
    pause
}

start_privanox() {
    systemctl start ${SERVICE}
    echo -e "${GREEN}Privanox Bot iniciado.${NC}"
    pause
}

stop_privanox() {
    systemctl stop ${SERVICE}
    echo -e "${YELLOW}Privanox Bot detenido.${NC}"
    pause
}

restart_privanox() {
    systemctl restart ${SERVICE}
    echo -e "${GREEN}Privanox Bot reiniciado.${NC}"
    pause
}

uninstall_privanox() {
    clear
    echo -e "${RED}Esto ejecutará el desinstalador original de Privanox.${NC}"
    read -rp "¿Continuar? [s/n]: " op

    case "$op" in
        s|S)
            bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/privanox-code/main/install_go.sh)
            ;;
        *)
            echo -e "${YELLOW}Cancelado.${NC}"
            ;;
    esac

    pause
}

privanox_menu() {
    while true; do
        clear
        echo -e "${CYAN}====================================${NC}"
        echo -e "${WHITE}        PRIVANOX BOT MANAGER${NC}"
        echo -e "${CYAN}====================================${NC}"
        status_privanox
        echo
        echo -e "${WHITE} 1.${NC} Instalar / Actualizar Bot"
        echo -e "${WHITE} 2.${NC} Iniciar Bot"
        echo -e "${WHITE} 3.${NC} Detener Bot"
        echo -e "${WHITE} 4.${NC} Reiniciar Bot"
        echo -e "${WHITE} 5.${NC} Ver Estado"
        echo -e "${WHITE} 6.${NC} Ejecutar instalador original (desinstalar)"
        echo -e "${WHITE} 0.${NC} Volver"
        echo
        read -rp "Selecciona una opción: " op

        case "$op" in
            1) install_privanox ;;
            2) start_privanox ;;
            3) stop_privanox ;;
            4) restart_privanox ;;
            5) clear; status_privanox; pause ;;
            6) uninstall_privanox ;;
            0) break ;;
            *) echo -e "${RED}Opción inválida${NC}"; sleep 1 ;;
        esac
    done
}

privanox_menu
