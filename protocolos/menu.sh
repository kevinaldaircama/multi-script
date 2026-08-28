#!/usr/bin/env bash

# ==============================================================
#                 🛡️ KEVINTECH MULTI SCRIPT
#                    PROTOCOL MANAGEMENT PANEL
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/menu.sh
# Config  : /etc/kevintech/config.conf
# Versión : 3.0 Premium
#
# ==============================================================
#                    KEVINTECH / PRIVANOX
# ==============================================================

set -o pipefail

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
PROTOCOL_DIR="$BASE/protocolos"
TOOLS_DIR="$BASE/herramientas"

VERSION="3.0"
PANEL_NAME="KEVINTECH MULTI SCRIPT"

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
# SEGURIDAD / PREPARACIÓN
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

if [[ ! -d "$BASE" ]]; then
    mkdir -p "$BASE"
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
# UTILIDADES
# ==============================================================

separator() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

line() {
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# ==============================================================
# MÓDULOS
# ==============================================================

module_exists() {
    [[ -f "$1" ]]
}

run_module() {

    local FILE="$1"

    if [[ -z "$FILE" ]]; then
        echo -e "${RED}✘ Módulo no especificado.${RESET}"
        pause
        return 1
    fi

    if ! module_exists "$FILE"; then
        echo
        echo -e "${RED}${BOLD}✘ MÓDULO NO ENCONTRADO${RESET}"
        echo
        echo -e "${WHITE}Archivo:${RESET}"
        echo -e "${YELLOW}$FILE${RESET}"
        echo
        pause
        return 1
    fi

    if [[ ! -x "$FILE" ]]; then
        chmod +x "$FILE" 2>/dev/null
    fi

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    KEVINTECH MODULE                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${GRAY}Ejecutando:${RESET} ${WHITE}$(basename "$FILE")${RESET}"
    echo

    bash "$FILE"
    local EXIT_CODE=$?

    echo

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo -e "${GREEN}✔ Módulo finalizado correctamente.${RESET}"
    else
        echo -e "${RED}✘ El módulo terminó con código: $EXIT_CODE${RESET}"
    fi

    pause
}

# ==============================================================
# SYSTEMD
# ==============================================================

service_exists() {
    systemctl cat "$1" &>/dev/null
}

service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

service_enabled() {
    systemctl is-enabled --quiet "$1" 2>/dev/null
}

status_service() {

    local SERVICE="$1"
    local CONFIG_STATUS="${2:-OFF}"

    if service_exists "$SERVICE"; then

        if service_active "$SERVICE"; then
            echo -e "${GREEN}● ONLINE${RESET}"

        elif service_enabled "$SERVICE"; then
            echo -e "${YELLOW}● STOPPED${RESET}"

        else
            echo -e "${RED}● OFF${RESET}"
        fi

    else

        if [[ "$CONFIG_STATUS" == "ON" ]]; then
            echo -e "${YELLOW}● CONFIG${RESET}"
        else
            echo -e "${GRAY}● OFF${RESET}"
        fi
    fi
}

status_config() {

    local VALUE="${1:-OFF}"

    case "${VALUE^^}" in

        ON|1|YES|TRUE)
            echo -e "${GREEN}● ON${RESET}"
            ;;

        *)
            echo -e "${GRAY}● OFF${RESET}"
            ;;
    esac
}

# ==============================================================
# INFORMACIÓN DEL SERVIDOR
# ==============================================================

get_hostname() {
    hostname 2>/dev/null || echo "Servidor"
}

get_ip() {

    local IP

    IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    [[ -z "$IP" ]] && IP="N/A"

    echo "$IP"
}

get_ram() {

    free -h 2>/dev/null |
        awk '/^Mem:/ {
            printf "%s / %s", $3, $2
        }'
}

get_ram_percent() {

    free 2>/dev/null |
        awk '/^Mem:/ {
            if ($2 > 0)
                printf "%.0f", ($3/$2)*100
            else
                print "0"
        }'
}

get_cpu() {

    local CPU

    CPU=$(top -bn1 2>/dev/null |
        awk '/Cpu\(s\)/ {

            for(i=1;i<=NF;i++) {

                if($i ~ /id,/) {

                    value=$(i-1)
                    gsub(",", "", value)

                    printf "%.0f", 100-value

                    exit
                }
            }
        }')

    [[ "$CPU" =~ ^[0-9]+$ ]] || CPU=0

    echo "$CPU"
}

get_disk_percent() {

    local DISK

    DISK=$(df / 2>/dev/null |
        awk 'NR==2 {gsub("%","",$5); print $5}')

    [[ "$DISK" =~ ^[0-9]+$ ]] || DISK=0

    echo "$DISK"
}

get_disk_used() {

    df -h / 2>/dev/null |
        awk 'NR==2 {print $3 "/" $2}'
}

get_uptime() {

    uptime -p 2>/dev/null |
        sed 's/^up //'
}

get_processes() {

    ps -e --no-headers 2>/dev/null |
        wc -l
}

get_online() {

    who 2>/dev/null |
        wc -l
}

get_kernel() {

    uname -r 2>/dev/null || echo "N/A"
}

get_arch() {

    uname -m 2>/dev/null || echo "N/A"
}

# ==============================================================
# BARRA DE PROGRESO
# ==============================================================

progress_bar() {

    local VALUE="${1:-0}"
    local SIZE="${2:-10}"

    valid_number "$VALUE" || VALUE=0

    (( VALUE > 100 )) && VALUE=100
    (( VALUE < 0 )) && VALUE=0

    local FILLED=$(( VALUE * SIZE / 100 ))
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

    local HOST IP RAM CPU DISK DISK_USED UPTIME ONLINE
    local PROCESSES KERNEL ARCH RAM_PERCENT

    HOST=$(get_hostname)
    IP=$(get_ip)
    RAM=$(get_ram)
    RAM_PERCENT=$(get_ram_percent)

    CPU=$(get_cpu)

    DISK=$(get_disk_percent)
    DISK_USED=$(get_disk_used)

    UPTIME=$(get_uptime)
    ONLINE=$(get_online)

    PROCESSES=$(get_processes)
    KERNEL=$(get_kernel)
    ARCH=$(get_arch)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🛡️ $PANEL_NAME${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                  ${GRAY}PROTOCOL PANEL v$VERSION${RESET}                   ${CYAN}║${RESET}"

    separator

    printf "${CYAN}║${RESET} ${WHITE}🖥 SERVIDOR${RESET} %-17s ${WHITE}🌐 IP${RESET} %-20s ${CYAN}║${RESET}\n" \
        "${HOST:0:17}" "${IP:0:20}"

    printf "${CYAN}║${RESET} ${WHITE}⏱ UPTIME${RESET}  %-17s ${WHITE}👥 ONLINE${RESET} %-20s ${CYAN}║${RESET}\n" \
        "${UPTIME:0:17}" "$ONLINE"

    printf "${CYAN}║${RESET} ${WHITE}⚙ PROCESOS${RESET} %-15s ${WHITE}🧩 ARCH${RESET} %-20s ${CYAN}║${RESET}\n" \
        "$PROCESSES" "$ARCH"

    printf "${CYAN}║${RESET} ${WHITE}🐧 KERNEL${RESET} %-44s ${CYAN}║${RESET}\n" \
        "${KERNEL:0:44}"

    separator

    printf "${CYAN}║${RESET} ${WHITE}⚡ CPU${RESET} %-5s ${GREEN}%s${RESET}  ${WHITE}💾 DISCO${RESET} %-5s ${GREEN}%s${RESET} ${CYAN}║${RESET}\n" \
        "${CPU}%" \
        "$(progress_bar "$CPU")" \
        "${DISK}%" \
        "$(progress_bar "$DISK")"

    printf "${CYAN}║${RESET} ${WHITE}🧠 RAM${RESET} %-10s ${GREEN}%s${RESET} %-26s ${CYAN}║${RESET}\n" \
        "${RAM_PERCENT}%" \
        "$(progress_bar "$RAM_PERCENT")" \
        "$RAM"

    printf "${CYAN}║${RESET} ${WHITE}💽 DISCO USADO${RESET} %-42s ${CYAN}║${RESET}\n" \
        "$DISK_USED"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ==============================================================
# ESTADOS
# ==============================================================
# Se calculan nuevamente cada vez que se muestra el menú.

get_statuses() {

    OPENSSH_STATUS=$(status_service "ssh" "${OPENSSH:-OFF}")

    CHECKUSER_STATUS=$(status_service \
        "checkuser" \
        "${CHECKUSER:-OFF}")

    DROPBEAR_STATUS=$(status_service \
        "dropbear_custom" \
        "${DROPBEAR:-OFF}")

    SSL_STATUS=$(status_service \
        "haproxy" \
        "${SSL:-OFF}")

    UDP_STATUS=$(status_service \
        "udp-custom" \
        "${UDP_CUSTOM:-OFF}")

    SLOWDNS_STATUS=$(status_service \
        "dnstt" \
        "${SLOWDNS:-OFF}")

    XRAY_STATUS=$(status_service \
        "xray" \
        "${V2RAY:-OFF}")

    OPENVPN_STATUS=$(status_service \
        "openvpn-server@server" \
        "${OPENVPN:-OFF}")

    HYSTERIA_STATUS=$(status_service \
        "hysteria1-server" \
        "${HYSTERIA:-OFF}")

    ZIPVPN_STATUS=$(status_config "${ZIPVPN:-OFF}")

    BADVPN_STATUS=$(status_config "${BADVPN:-OFF}")
}

# ==============================================================
# MENÚ DE PROTOCOLOS
# ==============================================================

show_protocol_menu() {

    get_statuses

    echo
    echo -e "${BLUE}${BOLD}  🔐 PROTOCOLOS DE CONEXIÓN${RESET}"
    line

    printf "  ${GREEN}${BOLD}[01]${RESET} 🔐 %-20s %b\n" \
        "OpenSSH" "$OPENSSH_STATUS"

    printf "  ${GREEN}${BOLD}[02]${RESET} 📦 %-20s %b\n" \
        "ZIPVPN" "$ZIPVPN_STATUS"

    printf "  ${GREEN}${BOLD}[03]${RESET} 🚪 %-20s %b\n" \
        "Dropbear" "$DROPBEAR_STATUS"

    printf "  ${GREEN}${BOLD}[04]${RESET} 🔒 %-20s %b\n" \
        "SSL / TLS" "$SSL_STATUS"

    printf "  ${GREEN}${BOLD}[05]${RESET} ⚡ %-20s %b\n" \
        "BadVPN" "$BADVPN_STATUS"

    printf "  ${GREEN}${BOLD}[06]${RESET} 🚀 %-20s %b\n" \
        "UDP Custom" "$UDP_STATUS"

    printf "  ${GREEN}${BOLD}[07]${RESET} 🌐 %-20s %b\n" \
        "SlowDNS" "$SLOWDNS_STATUS"

    printf "  ${GREEN}${BOLD}[08]${RESET} ☁️  %-20s %b\n" \
        "Xray / V2Ray" "$XRAY_STATUS"

    printf "  ${GREEN}${BOLD}[09]${RESET} 👤 %-20s %b\n" \
        "CheckUser" "$CHECKUSER_STATUS"

    printf "  ${GREEN}${BOLD}[10]${RESET} 🔐 %-20s %b\n" \
        "OpenVPN" "$OPENVPN_STATUS"

    printf "  ${GREEN}${BOLD}[11]${RESET} 🛡️  %-20s %b\n" \
        "Hysteria" "$HYSTERIA_STATUS"

    echo
    echo -e "${BLUE}${BOLD}  🛠️ ADMINISTRACIÓN DEL SISTEMA${RESET}"
    line

    echo -e "  ${GREEN}${BOLD}[12]${RESET} 🧰 Herramientas"
    echo -e "  ${GREEN}${BOLD}[13]${RESET} 🔄 Reiniciar Servicios"
    echo -e "  ${GREEN}${BOLD}[14]${RESET} 🔥 Firewall"
    echo -e "  ${GREEN}${BOLD}[15]${RESET} 🤖 Bot Telegram"

    echo
    line

    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Regresar al Menú Principal"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo
}

# ==============================================================
# PROCESAR OPCIÓN
# ==============================================================

process_option() {

    local OP="$1"

    case "$OP" in

        1|01)
            run_module "$PROTOCOL_DIR/openssh.sh"
            ;;

        2|02)
            run_module "$PROTOCOL_DIR/zipvpn.sh"
            ;;

        3|03)
            run_module "$PROTOCOL_DIR/dropbear.sh"
            ;;

        4|04)
            run_module "$PROTOCOL_DIR/ssl.sh"
            ;;

        5|05)
            run_module "$PROTOCOL_DIR/badvpn.sh"
            ;;

        6|06)
            run_module "$PROTOCOL_DIR/udpcustom.sh"
            ;;

        7|07)
            run_module "$PROTOCOL_DIR/slowdns.sh"
            ;;

        8|08)
            run_module "$PROTOCOL_DIR/v2ray.sh"
            ;;

        9|09)
            run_module "$PROTOCOL_DIR/checkuser.sh"
            ;;

        10)
            run_module "$PROTOCOL_DIR/openvpn.sh"
            ;;

        11)
            run_module "$PROTOCOL_DIR/histeria.sh"
            ;;

        12)
            run_module "$TOOLS_DIR/menu.sh"
            ;;

        13)
            run_module "$TOOLS_DIR/reiniciar.sh"
            ;;

        14)
            run_module "$TOOLS_DIR/firewall.sh"
            ;;

        15)
            run_module "$BASE/telegram/install.sh"
            ;;

        0|00)
            clear
            if [[ -f "$BASE/menu.sh" ]]; then
                exec bash "$BASE/menu.sh"
            else
                exit 0
            fi
            ;;

        "")
            ;;

        *)
            echo
            echo -e "  ${RED}${BOLD}✘ Opción inválida: $OP${RESET}"
            sleep 1
            ;;
    esac
}

# ==============================================================
# CTRL+C
# ==============================================================

trap '
    echo
    echo -e "${YELLOW}⚠️  Regresando...${RESET}"
    sleep 1
    clear
    exit 0
' INT TERM

# ==============================================================
# BUCLE PRINCIPAL
# ==============================================================

while true; do

    clear

    show_header

    show_protocol_menu

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    process_option "$OP"

done