#!/usr/bin/env bash

# ==============================================================
#                 🛡️ KEVINTECH MULTI SCRIPT
#                  PROTOCOL MANAGEMENT PANEL
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/menu.sh
# Config  : /etc/kevintech/config.conf
# Versión : 3.6 Premium
#
# Nuevos módulos:
#   BTUN · Shadowsocks · SOCKS5 · 3X-UI
#   VayDNS · Slipstream · DNSDist
#
# ==============================================================

set -o pipefail

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
PROTOCOL_DIR="$BASE/protocolos"
TOOLS_DIR="$BASE/herramientas"

VERSION="3.6"
PANEL_NAME="KEVINTECH MULTI SCRIPT"

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

    [[ -x "$FILE" ]] || chmod +x "$FILE" 2>/dev/null

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

run_module_first() {
    local FILE
    local FOUND=""

    for FILE in "$@"; do
        if [[ -f "$FILE" ]]; then
            FOUND="$FILE"
            break
        fi
    done

    if [[ -z "$FOUND" ]]; then
        echo
        echo -e "${RED}${BOLD}✘ MÓDULO NO ENCONTRADO${RESET}"
        echo
        echo -e "${WHITE}Se buscaron:${RESET}"
        for FILE in "$@"; do
            echo -e "  ${YELLOW}$FILE${RESET}"
        done
        echo
        pause
        return 1
    fi

    run_module "$FOUND"
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

status_service() {
    local SERVICE="$1"
    local CONFIG_STATUS="${2:-OFF}"

    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        echo -e "${GREEN}● ON${RESET}"
    else
        case "${CONFIG_STATUS^^}" in
            ON|1|YES|TRUE)
                echo -e "${YELLOW}● CFG${RESET}"
                ;;
            *)
                echo -e "${GRAY}● OFF${RESET}"
                ;;
        esac
    fi
}

# --------------------------------------------------------------
# Información del servidor
# --------------------------------------------------------------

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
    free -h 2>/dev/null | awk '/^Mem:/ {printf "%s / %s", $3, $2}'
}

get_ram_percent() {
    free 2>/dev/null | awk '/^Mem:/ {
        if ($2 > 0) printf "%.0f", ($3/$2)*100;
        else print "0"
    }'
}

get_cpu() {
    local CPU
    CPU=$(top -bn1 2>/dev/null | awk '/Cpu\(s\)/ {
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
    DISK=$(df / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')
    [[ "$DISK" =~ ^[0-9]+$ ]] || DISK=0
    echo "$DISK"
}

get_disk_used() {
    df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/^up //'
}

get_processes() {
    ps -e --no-headers 2>/dev/null | wc -l
}

get_online() {
    who 2>/dev/null | wc -l
}

get_kernel() {
    uname -r 2>/dev/null || echo "N/A"
}

get_arch() {
    uname -m 2>/dev/null || echo "N/A"
}

progress_bar() {
    local VALUE="${1:-0}"
    local SIZE="${2:-10}"

    valid_number "$VALUE" || VALUE=0
    (( VALUE > 100 )) && VALUE=100
    (( VALUE < 0 )) && VALUE=0

    local FILLED=$(( VALUE * SIZE / 100 ))
    local BAR=""

    for ((i=0; i<FILLED; i++)); do BAR+="█"; done
    for ((i=FILLED; i<SIZE; i++)); do BAR+="░"; done

    echo "$BAR"
}

show_header() {
    local HOST IP RAM CPU DISK DISK_USED UPTIME ONLINE PROCESSES KERNEL ARCH RAM_PERCENT

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
    echo -e "${CYAN}║${RESET}        ${MAGENTA}${BOLD}🛡️  $PANEL_NAME${RESET}        ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${GRAY}PROTOCOL PANEL • v$VERSION${RESET}              ${CYAN}║${RESET}"
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
        "${CPU}%" "$(progress_bar "$CPU")" "${DISK}%" "$(progress_bar "$DISK")"

    printf "${CYAN}║${RESET} ${WHITE}🧠 RAM${RESET} %-10s ${GREEN}%s${RESET} %-26s ${CYAN}║${RESET}\n" \
        "${RAM_PERCENT}%" "$(progress_bar "$RAM_PERCENT")" "$RAM"

    printf "${CYAN}║${RESET} ${WHITE}💽 DISCO USADO${RESET} %-42s ${CYAN}║${RESET}\n" \
        "$DISK_USED"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# --------------------------------------------------------------
# Estados
# --------------------------------------------------------------

get_statuses() {
    OPENSSH_STATUS=$(status_service "ssh" "${OPENSSH:-OFF}")
    CHECKUSER_STATUS=$(status_service "checkuser" "${CHECKUSER:-OFF}")
    DROPBEAR_STATUS=$(status_service "dropbear_custom" "${DROPBEAR:-OFF}")
    SSL_STATUS=$(status_service "haproxy" "${SSL:-OFF}")
    UDP_STATUS=$(status_service "udp-custom" "${UDP_CUSTOM:-OFF}")
    SLOWDNS_STATUS=$(status_service "dnstt" "${SLOWDNS:-OFF}")

    # Xray nuevo gestor
    XRAY_STATUS=$(status_service "xray" "${XRAY:-${V2RAY:-OFF}}")

    OPENVPN_STATUS=$(status_service "openvpn-server@server" "${OPENVPN:-OFF}")
    HYSTERIA_STATUS=$(status_service "hysteria1-server" "${HYSTERIA:-OFF}")
    BHTTP_STATUS=$(status_service "bhttp" "${BHTTP:-OFF}")

    XHTTP_STATUS=$(status_service "xhttp" "${XHTTP:-OFF}")
    SQUID_STATUS=$(status_service "squid" "${SQUID:-OFF}")
    HCR_STATUS=$(status_service "hcr-server" "${HCR:-OFF}")
    WG_STATUS=$(status_service "wg-quick@wg0" "${WG:-OFF}")

    BTUN_STATUS=$(status_service "btun" "${BTUN:-OFF}")

    SS_PORT="${SS_PORT:-8388}"
    SHADOWSOCKS_STATUS=$(status_service \
        "shadowsocks-libev-server@${SS_PORT}" \
        "${SHADOWSOCKS:-OFF}")

    SOCKS5_STATUS=$(status_service "sockd" "${SOCKS5:-OFF}")
    XUI_STATUS=$(status_service "x-ui" "${XUI:-OFF}")

    # ----------------------------------------------------------
    # VayDNS
    # ----------------------------------------------------------
    VAYDNS_STATUS=$(status_service "vaydns" "${VAYDNS:-OFF}")

    # ----------------------------------------------------------
    # Slipstream
    # ----------------------------------------------------------
    SLIPSTREAM_STATUS=$(status_service "slipstream" "${SLIPSTREAM:-OFF}")

    # ----------------------------------------------------------
    # DNSDist
    # ----------------------------------------------------------
    DNSDIST_STATUS=$(status_service "dnsdist" "${DNSDIST:-OFF}")

    ZIPVPN_STATUS=$(status_config "${ZIPVPN:-OFF}")
    BADVPN_STATUS=$(status_config "${BADVPN:-OFF}")
}

# --------------------------------------------------------------
# Menú
# --------------------------------------------------------------

show_protocol_menu() {
    get_statuses

    echo
    echo -e "${BLUE}${BOLD}  🔐 PROTOCOLOS DE CONEXIÓN${RESET}"
    line

    printf "  ${GREEN}${BOLD}[01]${RESET} 🔐 OpenSSH     %b    " "$OPENSSH_STATUS"
    printf "${GREEN}${BOLD}[02]${RESET} 📦 ZIPVPN      %b\n" "$ZIPVPN_STATUS"

    printf "  ${GREEN}${BOLD}[03]${RESET} 🚪 Dropbear    %b    " "$DROPBEAR_STATUS"
    printf "${GREEN}${BOLD}[04]${RESET} 🔒 SSL/TLS     %b\n" "$SSL_STATUS"

    printf "  ${GREEN}${BOLD}[05]${RESET} ⚡ BadVPN      %b    " "$BADVPN_STATUS"
    printf "${GREEN}${BOLD}[06]${RESET} 🚀 UDP Custom   %b\n" "$UDP_STATUS"

    printf "  ${GREEN}${BOLD}[07]${RESET} 🌐 SlowDNS     %b    " "$SLOWDNS_STATUS"
    printf "${GREEN}${BOLD}[08]${RESET} ☁️ Xray/V2Ray  %b\n" "$XRAY_STATUS"

    printf "  ${GREEN}${BOLD}[09]${RESET} 👤 CheckUser   %b    " "$CHECKUSER_STATUS"
    printf "${GREEN}${BOLD}[10]${RESET} 🔐 OpenVPN     %b\n" "$OPENVPN_STATUS"

    printf "  ${GREEN}${BOLD}[11]${RESET} 🛡️ Hysteria    %b    " "$HYSTERIA_STATUS"
    printf "${MAGENTA}${BOLD}[12]${RESET} 🌐 BHTTP       %b\n" "$BHTTP_STATUS"

    printf "  ${MAGENTA}${BOLD}[13]${RESET} 🚀 XHTTP       %b    " "$XHTTP_STATUS"
    printf "${MAGENTA}${BOLD}[14]${RESET} 🌐 Squid       %b\n" "$SQUID_STATUS"

    printf "  ${MAGENTA}${BOLD}[15]${RESET} 🛡️ HCR         %b    " "$HCR_STATUS"
    printf "${MAGENTA}${BOLD}[16]${RESET} 🛡️ WireGuard   %b\n" "$WG_STATUS"

    printf "  ${MAGENTA}${BOLD}[17]${RESET} ⚡ BTUN        %b    " "$BTUN_STATUS"
    printf "${MAGENTA}${BOLD}[18]${RESET} 🕶️ Shadowsocks %b\n" "$SHADOWSOCKS_STATUS"

    printf "  ${MAGENTA}${BOLD}[19]${RESET} 🔐 SOCKS5      %b    " "$SOCKS5_STATUS"
    printf "${MAGENTA}${BOLD}[20]${RESET} 🖥️ 3X-UI        %b\n" "$XUI_STATUS"

    printf "  ${MAGENTA}${BOLD}[21]${RESET} 🔐 VayDNS      %b    " "$VAYDNS_STATUS"
    printf "${MAGENTA}${BOLD}[22]${RESET} 🚀 Slipstream  %b\n" "$SLIPSTREAM_STATUS"

    printf "  ${MAGENTA}${BOLD}[23]${RESET} 🌐 DNSDist     %b\n" "$DNSDIST_STATUS"

    echo
    echo -e "${BLUE}${BOLD}  🛠️  ADMINISTRACIÓN DEL SISTEMA${RESET}"
    line

    printf "  ${GREEN}${BOLD}[24]${RESET} 🧰 Herramientas          "
    printf "${GREEN}${BOLD}[25]${RESET} 🔄 Reiniciar Servicios\n"

    printf "  ${GREEN}${BOLD}[26]${RESET} 🔥 Firewall              "
    printf "${GREEN}${BOLD}[27]${RESET} 🤖 Bot Telegram\n"

    printf "  ${GREEN}${BOLD}[28]${RESET} 🌐 Web Universal\n"

    echo
    line
    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Regresar al Menú Principal"
    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo
}

# --------------------------------------------------------------
# Procesar opción
# --------------------------------------------------------------

process_option() {
    local OP="$1"

    case "$OP" in

        1|01) run_module "$PROTOCOL_DIR/openssh.sh" ;;
        2|02) run_module "$PROTOCOL_DIR/zipvpn.sh" ;;
        3|03) run_module "$PROTOCOL_DIR/dropbear.sh" ;;
        4|04) run_module "$PROTOCOL_DIR/ssl.sh" ;;
        5|05) run_module "$PROTOCOL_DIR/badvpn.sh" ;;
        6|06) run_module "$PROTOCOL_DIR/udpcustom.sh" ;;
        7|07) run_module "$PROTOCOL_DIR/slowdns.sh" ;;

        # Xray Manager adaptado a KevinTech
        8|08) run_module_first \
            "$PROTOCOL_DIR/xray.sh" \
            "$PROTOCOL_DIR/v2ray.sh" ;;

        9|09) run_module "$PROTOCOL_DIR/checkuser.sh" ;;
        10) run_module "$PROTOCOL_DIR/openvpn.sh" ;;

        11)
            run_module_first \
                "$PROTOCOL_DIR/hysteria.sh" \
                "$PROTOCOL_DIR/histeria.sh"
            ;;

        12) run_module "$PROTOCOL_DIR/bhttp.sh" ;;
        13) run_module "$PROTOCOL_DIR/xhttp.sh" ;;
        14) run_module "$PROTOCOL_DIR/squid.sh" ;;
        15) run_module "$PROTOCOL_DIR/hcr-server.sh" ;;
        16) run_module "$PROTOCOL_DIR/wireguard.sh" ;;

        # ------------------------------------------------------
        # Nuevos protocolos
        # ------------------------------------------------------

        17) run_module "$PROTOCOL_DIR/btun.sh" ;;
        18) run_module "$PROTOCOL_DIR/shadowsocks.sh" ;;
        19) run_module "$PROTOCOL_DIR/socks5.sh" ;;
        20) run_module "$PROTOCOL_DIR/3x-ui.sh" ;;
        21) run_module "$PROTOCOL_DIR/vaydns.sh" ;;
        22) run_module "$PROTOCOL_DIR/slipstream.sh" ;;
        23) run_module "$PROTOCOL_DIR/dnsdist.sh" ;;

        # ------------------------------------------------------
        # Administración
        # ------------------------------------------------------

        24) run_module "$TOOLS_DIR/menu.sh" ;;
        25) run_module "$TOOLS_DIR/reiniciar.sh" ;;
        26) run_module "$TOOLS_DIR/firewall.sh" ;;
        27) run_module "$BASE/telegram/install.sh" ;;
        28) run_module "$BASE/web/installer.sh" ;;

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

trap '
    echo
    echo -e "${YELLOW}⚠️  Regresando...${RESET}"
    sleep 1
    clear
    exit 0
' INT TERM

while true; do
    clear
    show_header
    show_protocol_menu

    read -rp \
        "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    process_option "$OP"
done
