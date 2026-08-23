#!/bin/bash

# ==============================================================
#             🛡️ KEVINTECH MULTI SCRIPT
#                  TOOLS MANAGEMENT PANEL
# ==============================================================
# Archivo: /etc/kevintech/herramientas/menu.sh
# ==============================================================

BASE="/etc/kevintech"
VERSION="2.0"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# COMPROBAR ROOT
# ==============================================================

if [[ $EUID -ne 0 ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este panel requiere permisos de root.${RESET}"
    echo
    exit 1
fi

# ==============================================================
# FUNCIONES
# ==============================================================

separator() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

run_tool() {

    local FILE="$1"

    if [[ ! -f "$FILE" ]]; then

        echo
        echo -e "${RED}✘ Herramienta no encontrada${RESET}"
        echo -e "${GRAY}$FILE${RESET}"
        pause

        return
    fi

    chmod +x "$FILE" 2>/dev/null

    bash "$FILE"

    echo
    pause
}

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

get_cpu() {

    local CPU

    CPU=$(top -bn1 2>/dev/null |
        awk '/Cpu\(s\)/ {
            for(i=1;i<=NF;i++) {
                if($i ~ /id,/) {
                    gsub(",", "", $(i-1))
                    printf "%.0f", 100-$(i-1)
                    exit
                }
            }
        }')

    [[ -z "$CPU" ]] && CPU="0"

    echo "${CPU}%"
}

get_ram() {

    free -h 2>/dev/null |
        awk '/Mem:/ {print $3 "/" $2}'
}

get_disk() {

    df -h / 2>/dev/null |
        awk 'NR==2 {print $5}'
}

get_uptime() {

    uptime -p 2>/dev/null |
        sed 's/^up //'
}

# ==============================================================
# CABECERA
# ==============================================================

show_header() {

    local HOST
    local IP
    local CPU
    local RAM
    local DISK
    local UPTIME

    HOST=$(hostname 2>/dev/null)
    IP=$(get_ip)
    CPU=$(get_cpu)
    RAM=$(get_ram)
    DISK=$(get_disk)
    UPTIME=$(get_uptime)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🛠️ KEVINTECH TOOLS${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                 ${GRAY}SYSTEM TOOLS PANEL v$VERSION${RESET}             ${CYAN}║${RESET}"

    separator

    printf "${CYAN}║${RESET} ${WHITE}🖥 SERVIDOR${RESET} %-17s ${WHITE}🌐 IP${RESET} %-19s ${CYAN}║${RESET}\n" \
        "${HOST:0:17}" "${IP:0:19}"

    printf "${CYAN}║${RESET} ${WHITE}⏱ UPTIME${RESET}  %-17s ${WHITE}⚡ CPU${RESET} %-18s ${CYAN}║${RESET}\n" \
        "${UPTIME:0:17}" "$CPU"

    separator

    printf "${CYAN}║${RESET} ${WHITE}💾 RAM${RESET} %-20s ${WHITE}💿 DISCO${RESET} %-16s ${CYAN}║${RESET}\n" \
        "$RAM" "$DISK"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ==============================================================
# MENÚ
# ==============================================================

while true; do

    clear

    show_header

    echo
    echo -e "${BLUE}${BOLD}  🧰 HERRAMIENTAS DEL SISTEMA${RESET}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"

    printf "  ${GREEN}${BOLD}[01]${RESET} 🧱 %-35s\n" \
        "Block Torrent"

    printf "  ${GREEN}${BOLD}[02]${RESET} 📂 %-35s\n" \
        "Archivo Online"

    printf "  ${GREEN}${BOLD}[03]${RESET} ⚡ %-35s\n" \
        "Speedtest"

    printf "  ${GREEN}${BOLD}[04]${RESET} 🖥️  %-35s\n" \
        "Detalles VPS"

    printf "  ${GREEN}${BOLD}[05]${RESET} 🚫 %-35s\n" \
        "Block Ads"

    printf "  ${GREEN}${BOLD}[06]${RESET} 🔑 %-35s\n" \
        "Cambiar contraseña Root"

    printf "  ${GREEN}${BOLD}[07]${RESET} 🔎 %-35s\n" \
        "Scanner Host / Dominio"

    printf "  ${GREEN}${BOLD}[08]${RESET} 🤖 %-35s\n" \
        "Bot Telegram"

    echo
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  ${WHITE}Regresar al Menú de Protocolos${RESET}"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)
            run_tool "$BASE/herramientas/blocktorrent.sh"
            ;;

        2)
            run_tool "$BASE/herramientas/archivoonline.sh"
            ;;

        3)
            run_tool "$BASE/herramientas/speedtest.sh"
            ;;

        4)
            run_tool "$BASE/herramientas/detalles.sh"
            ;;

        5)
            run_tool "$BASE/herramientas/blockads.sh"
            ;;

        6)
            run_tool "$BASE/herramientas/rootpass.sh"
            ;;

        7)
            run_tool "$BASE/herramientas/scanner.sh"
            ;;

        8)
            run_tool "$BASE/herramientas/dewisep.sh"
            ;;

        0)
            clear
            exec bash "$BASE/protocolos/menu.sh"
            ;;

        "")
            ;;

        *)
            echo
            echo -e "  ${RED}${BOLD}✘ Opción inválida.${RESET}"
            sleep 1
            ;;

    esac

done