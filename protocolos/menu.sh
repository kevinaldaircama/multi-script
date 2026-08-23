#!/bin/bash

# ==============================================================
#             🛡️ KEVINTECH MULTI SCRIPT
#                 PROTOCOL MANAGEMENT PANEL
# ==============================================================
# Archivo: /etc/kevintech/protocolos/menu.sh
# Config : /etc/kevintech/config.conf
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
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
# COMPROBACIONES
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

if [[ ! -f "$CONFIG" ]]; then
    clear
    echo
    echo -e "${RED}${BOLD}✘ ERROR DE CONFIGURACIÓN${RESET}"
    echo
    echo -e "${WHITE}No se encontró:${RESET}"
    echo -e "${YELLOW}$CONFIG${RESET}"
    echo
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null

# ==============================================================
# FUNCIONES GENERALES
# ==============================================================

separator() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

module_exists() {
    [[ -f "$1" ]]
}

run_module() {

    local FILE="$1"

    if ! module_exists "$FILE"; then
        echo
        echo -e "${RED}✘ Módulo no encontrado${RESET}"
        echo -e "${GRAY}$FILE${RESET}"
        pause
        return
    fi

    chmod +x "$FILE" 2>/dev/null

    bash "$FILE"

    echo
    pause
}

# ==============================================================
# ESTADO DE SERVICIOS
# ==============================================================

service_exists() {
    systemctl cat "$1" &>/dev/null
}

service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

status_service() {

    local SERVICE="$1"
    local CONFIG_STATUS="$2"

    if service_exists "$SERVICE"; then

        if service_active "$SERVICE"; then
            echo -e "${GREEN}● ACTIVO${RESET}"
        else
            echo -e "${RED}● OFF${RESET}"
        fi

    else

        if [[ "$CONFIG_STATUS" == "ON" ]]; then
            echo -e "${YELLOW}● CONFIGURADO${RESET}"
        else
            echo -e "${GRAY}● OFF${RESET}"
        fi

    fi
}

status_config() {

    local VALUE="$1"

    if [[ "$VALUE" == "ON" ]]; then
        echo -e "${GREEN}● ACTIVO${RESET}"
    else
        echo -e "${GRAY}● OFF${RESET}"
    fi
}

# ==============================================================
# INFORMACIÓN DEL SERVIDOR
# ==============================================================

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

get_ram() {
    free -h 2>/dev/null |
        awk '/Mem:/ {print $3 "/" $2}'
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

get_disk() {
    df -h / 2>/dev/null |
        awk 'NR==2 {print $5}'
}

get_uptime() {
    uptime -p 2>/dev/null |
        sed 's/^up //'
}

get_online() {
    who 2>/dev/null | wc -l
}

# ==============================================================
# BARRA DE PROGRESO
# ==============================================================

progress_bar() {

    local VALUE="$1"
    local SIZE=10
    local FILLED

    FILLED=$((VALUE * SIZE / 100))

    local BAR=""

    for ((i=0; i<FILLED; i++)); do
        BAR+="█"
    done

    for ((i=FILLED; i<SIZE; i++)); do
        BAR+="░"
    done

    echo "$BAR"
}

# ==============================================================
# CABECERA
# ==============================================================

show_header() {

    local HOST
    local IP
    local RAM
    local CPU
    local DISK
    local UPTIME
    local ONLINE

    HOST=$(hostname 2>/dev/null)
    IP=$(get_ip)
    RAM=$(get_ram)
    CPU=$(get_cpu)
    DISK=$(get_disk)
    UPTIME=$(get_uptime)
    ONLINE=$(get_online)

    local CPU_NUM="${CPU%\%}"
    local DISK_NUM="${DISK%\%}"

    [[ "$CPU_NUM" =~ ^[0-9]+$ ]] || CPU_NUM=0
    [[ "$DISK_NUM" =~ ^[0-9]+$ ]] || DISK_NUM=0

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🛡️ KEVINTECH MULTI SCRIPT${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                ${GRAY}PROTOCOL PANEL v$VERSION${RESET}                 ${CYAN}║${RESET}"
    separator

    printf "${CYAN}║${RESET} ${WHITE}🖥 SERVIDOR${RESET} %-17s ${WHITE}🌐 IP${RESET} %-19s ${CYAN}║${RESET}\n" \
        "${HOST:0:17}" "${IP:0:19}"

    printf "${CYAN}║${RESET} ${WHITE}⏱ UPTIME${RESET}  %-17s ${WHITE}👥 ONLINE${RESET} %-17s ${CYAN}║${RESET}\n" \
        "${UPTIME:0:17}" "$ONLINE"

    separator

    printf "${CYAN}║${RESET} ${WHITE}⚡ CPU${RESET} %-5s ${GREEN}%s${RESET}  ${WHITE}💾 DISCO${RESET} %-5s ${GREEN}%s${RESET} ${CYAN}║${RESET}\n" \
        "$CPU" "$(progress_bar "$CPU_NUM")" "$DISK" "$(progress_bar "$DISK_NUM")"

    printf "${CYAN}║${RESET} ${WHITE}🧠 RAM${RESET} %-48s ${CYAN}║${RESET}\n" \
        "$RAM"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ==============================================================
# ESTADOS
# ==============================================================

OPENSSH_STATUS=$(status_service "ssh" "${OPENSSH:-OFF}")
CHECKUSER_STATUS=$(status_service "checkuser" "${CHECKUSER:-OFF}")
DROPBEAR_STATUS=$(status_service "dropbear_custom" "${DROPBEAR:-OFF}")
SSL_STATUS=$(status_service "haproxy" "${SSL:-OFF}")
UDP_STATUS=$(status_service "udp-custom" "${UDP_CUSTOM:-OFF}")
SLOWDNS_STATUS=$(status_service "dnstt" "${SLOWDNS:-OFF}")
XRAY_STATUS=$(status_service "xray" "${V2RAY:-OFF}")
OPENVPN_STATUS=$(status_service "openvpn-server@server" "${OPENVPN:-OFF}")
HYSTERIA_STATUS=$(status_service "hysteria1-server" "${HYSTERIA:-OFF}")

ZIPVPN_STATUS=$(status_config "${ZIPVPN:-OFF}")
BADVPN_STATUS=$(status_config "${BADVPN:-OFF}")

# ==============================================================
# MENÚ
# ==============================================================

while true; do

    clear

    show_header

    echo
    echo -e "${BLUE}${BOLD}  🔐 PROTOCOLOS DE CONEXIÓN${RESET}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"

    printf "  ${GREEN}${BOLD}[01]${RESET} 🔐 %-19s %b\n" \
        "OpenSSH" "$OPENSSH_STATUS"

    printf "  ${GREEN}${BOLD}[02]${RESET} 📦 %-19s %b\n" \
        "ZIPVPN" "$ZIPVPN_STATUS"

    printf "  ${GREEN}${BOLD}[03]${RESET} 🚪 %-19s %b\n" \
        "Dropbear" "$DROPBEAR_STATUS"

    printf "  ${GREEN}${BOLD}[04]${RESET} 🔒 %-19s %b\n" \
        "SSL / TLS" "$SSL_STATUS"

    printf "  ${GREEN}${BOLD}[05]${RESET} ⚡ %-19s %b\n" \
        "BadVPN" "$BADVPN_STATUS"

    printf "  ${GREEN}${BOLD}[06]${RESET} 🚀 %-19s %b\n" \
        "UDP Custom" "$UDP_STATUS"

    printf "  ${GREEN}${BOLD}[07]${RESET} 🌐 %-19s %b\n" \
        "SlowDNS" "$SLOWDNS_STATUS"

    printf "  ${GREEN}${BOLD}[08]${RESET} ☁️  %-19s %b\n" \
        "Xray / V2Ray" "$XRAY_STATUS"

    printf "  ${GREEN}${BOLD}[09]${RESET} 👤 %-19s %b\n" \
        "CheckUser" "$CHECKUSER_STATUS"

    printf "  ${GREEN}${BOLD}[10]${RESET} 🔐 %-19s %b\n" \
        "OpenVPN Pro" "$OPENVPN_STATUS"

    printf "  ${GREEN}${BOLD}[11]${RESET} 🔰 %-19s %b\n" \
        "Hysteria v1" "$HYSTERIA_STATUS"

    echo
    echo -e "${BLUE}${BOLD}  🛠️ ADMINISTRACIÓN DEL SISTEMA${RESET}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"

    echo -e "  ${GREEN}${BOLD}[12]${RESET} 🧰 Herramientas"
    echo -e "  ${GREEN}${BOLD}[13]${RESET} 🔄 Reiniciar Servicios"
    echo -e "  ${GREEN}${BOLD}[14]${RESET} 🔥 Firewall"

    echo
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Regresar al Menú Principal"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)
            run_module "$BASE/protocolos/openssh.sh"
            ;;

        2)
            run_module "$BASE/protocolos/zipvpn.sh"
            ;;

        3)
            run_module "$BASE/protocolos/dropbear.sh"
            ;;

        4)
            run_module "$BASE/protocolos/ssl.sh"
            ;;

        5)
            run_module "$BASE/protocolos/badvpn.sh"
            ;;

        6)
            run_module "$BASE/protocolos/udpcustom.sh"
            ;;

        7)
            run_module "$BASE/protocolos/slowdns.sh"
            ;;

        8)
            run_module "$BASE/protocolos/v2ray.sh"
            ;;

        9)
            run_module "$BASE/protocolos/checkuser.sh"
            ;;

        10)
            run_module "$BASE/protocolos/openvpn.sh"
            ;;

        11)
            run_module "$BASE/protocolos/udphisteria.sh"
            ;;

        12)
            run_module "$BASE/herramientas/menu.sh"
            ;;

        13)
            run_module "$BASE/herramientas/reiniciar.sh"
            ;;

        14)
            run_module "$BASE/herramientas/firewall.sh"
            ;;

        0)
            clear
            exec bash "$BASE/menu.sh"
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