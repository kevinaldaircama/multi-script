#!/bin/bash

#=========================================================
#        KEVIN TECH MULTI SCRIPT - PREMIUM EDITION
#=========================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

#=========================================================
# VERIFICAR CONFIGURACIÓN
#=========================================================

if [[ ! -f "$CONFIG" ]]; then
    clear
    echo ""
    echo "❌ No se encontró config.conf"
    echo "👉 Ejecuta primero install.sh"
    echo ""
    exit 1
fi

source "$CONFIG"

grep -q "^OPTIMIZAR=" "$CONFIG" || \
    echo "OPTIMIZAR=OFF" >> "$CONFIG"

source "$CONFIG"

#=========================================================
# VARIABLES
#=========================================================

ZIPVPN=${ZIPVPN:-OFF}
OPTIMIZAR=${OPTIMIZAR:-OFF}
SYSTEMDNS=${SYSTEMDNS:-OFF}
XRAY=${XRAY:-OFF}
CUPSD=${CUPSD:-OFF}
SSL_TUNNEL=${SSL_TUNNEL:-OFF}
CLOUDFLARE_STATUS=${CLOUDFLARE_STATUS:-OFF}
PROXY_STATUS=${PROXY_STATUS:-OFF}
AUTO_START=${AUTO_START:-OFF}

OPENSSH=${OPENSSH:-ON}
DROPBEAR=${DROPBEAR:-OFF}
BADVPN=${BADVPN:-OFF}
UDP_CUSTOM=${UDP_CUSTOM:-OFF}
SLOWDNS=${SLOWDNS:-OFF}
HYSTERIA=${HYSTERIA:-OFF}
OPENVPN=${OPENVPN:-OFF}
BHTTP=${BHTTP:-OFF}
CHECKUSER=${CHECKUSER:-OFF}

#=========================================================
# PUERTOS
#=========================================================

SSH_PORT="${SSH_PORT:-22}"
DROPBEAR_PORTS="${DROPBEAR_PORTS:-90,143,109}"
SSL_PORTS="${SSL_PORTS:-80,443,8080}"
ZIPVPN_PORT="${ZIPVPN_PORT:-22643}"
BADVPN_PORTS="${BADVPN_PORTS:-7200,7300}"
UDP_CUSTOM_PORT="${UDP_CUSTOM_PORT:-36712}"
SLOWDNS_PORT="${SLOWDNS_PORT:-5300}"
XRAY_PORT="${XRAY_PORT:-443}"
OPENVPN_PORT="${OPENVPN_PORT:-1194}"
BHTTP_PORT="${BHTTP_PORT:-8088}"

#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"

RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

ORANGE="\e[38;5;214m"
PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
SKY="\e[38;5;117m"
LIME="\e[38;5;154m"
GOLD="\e[38;5;220m"

BOLD="\e[1m"
DIM="\e[2m"
BLINK="\e[5m"

#=========================================================
# VERSIÓN
#=========================================================

VERSION_FILE="$BASE/version.txt"

VERSION_URL="https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/version.txt"

if [[ -f "$VERSION_FILE" ]]; then
    VERSION_ACTUAL=$(head -n1 "$VERSION_FILE" | tr -d '\r')
else
    VERSION_ACTUAL="v2.0"
fi

NUEVA_VERSION=$(curl -fsSL \
    --max-time 5 \
    "$VERSION_URL" 2>/dev/null |
    head -n1 |
    tr -d '\r')

[[ -z "$NUEVA_VERSION" ]] && NUEVA_VERSION="No disponible"

#=========================================================
# INFORMACIÓN VPS
#=========================================================

OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")

CPU=$(nproc)

IP=$(hostname -I 2>/dev/null | awk '{print $1}')

TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')

USED_RAM=$(free -h | awk '/Mem:/ {print $3}')

FREE_RAM=$(free -h | awk '/Mem:/ {print $7}')

RAM_USE=$(free | awk '/Mem:/ {
    printf("%.0f"),$3/$2*100
}')

CPU_USE=$(top -bn1 2>/dev/null |
    grep "Cpu(s)" |
    awk '{print int($2+$4)}')

DISK=$(df -h / | awk 'NR==2 {print $5}')

UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')

#=========================================================
# DETECCIÓN REAL DE SSH
#=========================================================

ssh_instalado() {

    systemctl cat ssh.service >/dev/null 2>&1 && return 0
    systemctl cat sshd.service >/dev/null 2>&1 && return 0

    [[ -x /usr/sbin/sshd ]] && return 0

    return 1
}

ssh_activo() {

    systemctl is-active --quiet ssh.service 2>/dev/null && return 0
    systemctl is-active --quiet sshd.service 2>/dev/null && return 0

    return 1
}

#=========================================================
# DROPBEAR
#=========================================================

dropbear_instalado() {

    [[ -x /usr/sbin/dropbear ]] && return 0

    systemctl cat dropbear.service >/dev/null 2>&1 && return 0

    return 1
}

dropbear_activo() {

    systemctl is-active --quiet dropbear.service 2>/dev/null && return 0

    pgrep -x dropbear >/dev/null 2>&1 && return 0

    return 1
}

#=========================================================
# SSL / HAPROXY
#=========================================================

ssl_instalado() {

    [[ -x /usr/sbin/haproxy ]] && return 0

    systemctl cat haproxy.service >/dev/null 2>&1 && return 0

    return 1
}

ssl_activo() {

    systemctl is-active --quiet haproxy.service 2>/dev/null && return 0

    return 1
}

#=========================================================
# ZIVPN
#=========================================================

zivpn_instalado() {

    [[ -x /usr/local/bin/zivpn ]] && return 0
    [[ -x /usr/bin/zivpn ]] && return 0
    [[ -d /etc/zivpn ]] && return 0

    systemctl cat zivpn.service >/dev/null 2>&1 && return 0

    return 1
}

zivpn_activo() {

    systemctl is-active --quiet zivpn.service 2>/dev/null && return 0

    pgrep -x zivpn >/dev/null 2>&1 && return 0

    return 1
}

#=========================================================
# BADVPN
#=========================================================

badvpn_instalado() {

    [[ -x /usr/local/bin/badvpn-udpgw ]] && return 0

    systemctl cat badvpn-udpgw-7300.service >/dev/null 2>&1 && return 0

    systemctl cat badvpn-udpgw-7200.service >/dev/null 2>&1 && return 0

    return 1
}

badvpn_activo() {

    systemctl is-active --quiet badvpn-udpgw-7300.service 2>/dev/null && return 0

    systemctl is-active --quiet badvpn-udpgw-7200.service 2>/dev/null && return 0

    pgrep -f badvpn-udpgw >/dev/null 2>&1 && return 0

    return 1
}

#=========================================================
# UDP CUSTOM
#=========================================================

udpcustom_instalado() {

    [[ -x /usr/local/bin/udp-custom ]] && return 0
    [[ -x /usr/bin/udp-custom ]] && return 0

    systemctl cat udp-custom.service >/dev/null 2>&1 && return 0

    return 1
}

udpcustom_activo() {

    systemctl is-active --quiet udp-custom.service 2>/dev/null && return 0

    pgrep -x udp-custom >/dev/null 2>&1 && return 0

    return 1
}

#=========================================================
# SLOWDNS
#=========================================================

slowdns_instalado() {

    [[ -d /etc/slowdns ]] && return 0

    [[ -x /usr/local/bin/dnstt-server ]] && return 0

    [[ -x /usr/local/bin/dnstt ]] && return 0

    systemctl cat dnstt.service >/dev/null 2>&1 && return 0

    systemctl cat slowdns.service >/dev/null 2>&1 && return 0

    return 1
}

slowdns_activo() {

    systemctl is-active --quiet dnstt.service 2>/dev/null && return 0

    systemctl is-active --quiet slowdns.service 2>/dev/null && return 0

    pgrep -f dnstt-server >/dev/null 2>&1 && return 0

    return 1
}

#=========================================================
# XRAY / V2RAY
#=========================================================

xray_instalado() {

    [[ -x /usr/local/bin/xray ]] && return 0

    [[ -x /usr/bin/xray ]] && return 0

    [[ -f /usr/local/etc/xray/config.json ]] && return 0

    [[ -f /etc/xray/config.json ]] && return 0

    systemctl cat xray.service >/dev/null 2>&1 && return 0

    return 1
}

xray_activo() {

    systemctl is-active --quiet xray.service 2>/dev/null && return 0

    pgrep -x xray >/dev/null 2>&1 && return 0

    return 1
}

#=========================================================
# HYSTERIA
#=========================================================

hysteria_instalado() {

    systemctl cat hysteria1-server.service >/dev/null 2>&1 && return 0

    systemctl cat hysteria.service >/dev/null 2>&1 && return 0

    [[ -x /usr/local/bin/hysteria ]] && return 0

    [[ -x /usr/bin/hysteria ]] && return 0

    [[ -f /etc/hysteria/config.yaml ]] && return 0

    return 1
}

hysteria_activo() {

    systemctl is-active --quiet hysteria1-server.service 2>/dev/null && return 0

    systemctl is-active --quiet hysteria.service 2>/dev/null && return 0

    return 1
}

#=========================================================
# OPENVPN
#=========================================================

openvpn_instalado() {

    [[ -x /usr/sbin/openvpn ]] && return 0

    systemctl cat openvpn-server@server.service >/dev/null 2>&1 && return 0

    [[ -f /etc/openvpn/server/server.conf ]] && return 0

    return 1
}

openvpn_activo() {

    systemctl is-active --quiet openvpn-server@server.service 2>/dev/null && return 0

    return 1
}

#=========================================================
# BHTTP
#=========================================================

bhttp_instalado() {

    systemctl cat bhttp.service >/dev/null 2>&1 && return 0

    [[ -f /etc/systemd/system/bhttp.service ]] && return 0

    [[ -x /usr/local/bin/bhttp ]] && return 0

    return 1
}

bhttp_activo() {

    systemctl is-active --quiet bhttp.service 2>/dev/null && return 0

    return 1
}

get_bhttp_port() {

    local PORT=""

    PORT=$(systemctl cat bhttp.service 2>/dev/null |
        grep -oE -- '--port[= ]+[0-9]+' |
        grep -oE '[0-9]+' |
        tail -n1)

    if [[ -z "$PORT" ]]; then

        PORT=$(grep -oE \
            -- '--port[= ]+[0-9]+' \
            /etc/systemd/system/bhttp.service \
            2>/dev/null |
            grep -oE '[0-9]+' |
            tail -n1)

    fi

    if [[ -z "$PORT" ]]; then

        PORT=$(systemctl cat bhttp.service 2>/dev/null |
            grep -oE ':[0-9]{2,5}' |
            grep -oE '[0-9]{2,5}' |
            tail -n1)

    fi

    [[ -z "$PORT" ]] && PORT="${BHTTP_PORT:-8088}"

    echo "$PORT"
}

#=========================================================
# CHECKUSER
#=========================================================

checkuser_instalado() {

    systemctl cat checkgestor.service >/dev/null 2>&1 && return 0

    systemctl cat checkuser.service >/dev/null 2>&1 && return 0

    systemctl cat ssh-ws-internal.service >/dev/null 2>&1 && return 0

    [[ -f /usr/bin/checkgestor ]] && return 0

    [[ -f /usr/lib/checkgestor/checkgestor.py ]] && return 0

    return 1
}

checkuser_activo() {

    systemctl is-active --quiet checkgestor.service 2>/dev/null && return 0

    systemctl is-active --quiet checkuser.service 2>/dev/null && return 0

    systemctl is-active --quiet ssh-ws-internal.service 2>/dev/null && return 0

    return 1
}

#=========================================================
# CUENTAS SSH
#=========================================================

get_ssh_users() {

    local TOTAL

    TOTAL=$(awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" &&
        $1 != "ubuntu" &&
        $1 != "root" {
            count++
        }

        END {
            print count+0
        }
    ' /etc/passwd 2>/dev/null)

    echo "${TOTAL:-0}"
}

#=========================================================
# SSH CONECTADOS
#=========================================================

get_ssh_online() {

    local ONLINE

    ONLINE=$(who 2>/dev/null |
        awk 'NF >= 1 {
            print $1
        }' |
        sort -u |
        wc -l)

    echo "${ONLINE:-0}"
}

#=========================================================
# V2RAY CUENTAS
#=========================================================

get_v2ray_users() {

    local TOTAL=0
    local CFG=""

    if [[ -f /usr/local/etc/xray/config.json ]]; then

        CFG="/usr/local/etc/xray/config.json"

    elif [[ -f /etc/xray/config.json ]]; then

        CFG="/etc/xray/config.json"

    fi

    if [[ -n "$CFG" ]] &&
       command -v jq >/dev/null 2>&1; then

        TOTAL=$(jq '
            [
                .inbounds[]?.
                settings?.
                clients[]?
            ] | length
        ' "$CFG" 2>/dev/null)

    fi

    echo "${TOTAL:-0}"
}

#=========================================================
# V2RAY CONECTADOS
#=========================================================

get_v2ray_online() {

    local LOG="/var/log/xray/access.log"

    [[ ! -f "$LOG" ]] && {
        echo "0"
        return
    }

    local ONLINE

    ONLINE=$(tail -n 3000 "$LOG" 2>/dev/null |
        sed -nE '
            s/.*email: ([^, ]+).*/\1/p
        ' |
        sort -u |
        wc -l)

    echo "${ONLINE:-0}"
}

#=========================================================
# OPENVPN CUENTAS
#=========================================================

get_openvpn_users() {

    local DIR="/etc/openvpn/server/easy-rsa/pki/issued"

    local TOTAL=0
    local CERT
    local NAME

    [[ ! -d "$DIR" ]] && {
        echo "0"
        return
    }

    for CERT in "$DIR"/*.crt; do

        [[ ! -f "$CERT" ]] && continue

        NAME="$(basename "$CERT" .crt)"

        [[ "$NAME" == "server" ]] && continue

        TOTAL=$((TOTAL + 1))

    done

    echo "$TOTAL"
}

#=========================================================
# OPENVPN CONECTADOS
#=========================================================

get_openvpn_online() {

    local STATUS=""

    if [[ -f "/etc/openvpn/server/openvpn-status.log" ]]; then

        STATUS="/etc/openvpn/server/openvpn-status.log"

    elif [[ -f "/var/log/openvpn/status.log" ]]; then

        STATUS="/var/log/openvpn/status.log"

    elif [[ -f "/etc/openvpn/openvpn-status.log" ]]; then

        STATUS="/etc/openvpn/openvpn-status.log"

    fi

    [[ -z "$STATUS" ]] && {
        echo "0"
        return
    }

    awk -F',' '
        /^CLIENT_LIST,/ {
            count++
        }

        END {
            print count+0
        }
    ' "$STATUS" 2>/dev/null
}

#=========================================================
# HYSTERIA CUENTAS
#=========================================================

get_hysteria_users() {

    local TOTAL=0

    if [[ -f "/etc/hysteria/config.yaml" ]]; then

        TOTAL=$(grep -Eic \
            '^[[:space:]]*(user|username|password)[[:space:]]*:' \
            "/etc/hysteria/config.yaml" 2>/dev/null)

    fi

    echo "${TOTAL:-0}"
}

#=========================================================
# HYSTERIA CONECTADOS
#=========================================================

get_hysteria_online() {

    local ONLINE=0

    if systemctl is-active --quiet hysteria1-server.service 2>/dev/null; then

        ONLINE=$(journalctl \
            -u hysteria1-server.service \
            --since "5 minutes ago" \
            --no-pager \
            2>/dev/null |
            grep -Eic \
            'connected|connection|client|accepted')

    elif systemctl is-active --quiet hysteria.service 2>/dev/null; then

        ONLINE=$(journalctl \
            -u hysteria.service \
            --since "5 minutes ago" \
            --no-pager \
            2>/dev/null |
            grep -Eic \
            'connected|connection|client|accepted')

    fi

    echo "${ONLINE:-0}"
}

#=========================================================
# CUENTAS
#=========================================================

SSH_COUNT=$(get_ssh_users)
SSH_ONLINE=$(get_ssh_online)

DROPBEAR_COUNT="$SSH_COUNT"
DROPBEAR_ONLINE="$SSH_ONLINE"

V2RAY_COUNT=$(get_v2ray_users)
V2RAY_ONLINE=$(get_v2ray_online)

HYSTERIA_COUNT=$(get_hysteria_users)
HYSTERIA_ONLINE=$(get_hysteria_online)

OPENVPN_COUNT=$(get_openvpn_users)
OPENVPN_ONLINE=$(get_openvpn_online)

#=========================================================
# BHTTP PUERTO REAL
#=========================================================

if bhttp_instalado; then
    BHTTP_PORT=$(get_bhttp_port)
fi

#=========================================================
# FUNCIÓN PARA MOSTRAR PROTOCOLO
#=========================================================

mostrar_protocolo() {

    local NOMBRE="$1"
    local PUERTO="$2"
    local ICONO="$3"
    local ESTADO="$4"

    if [[ "$ESTADO" == "ON" ]]; then

        printf "   ${GREEN}[✓]${RESET} ${WHITE}${ICONO} %-13s${RESET}" \
            "$NOMBRE"

        if [[ -n "$PUERTO" ]]; then
            printf " ${GRAY}(%s)${RESET}" "$PUERTO"
        fi

        printf " ${GREEN}ON${RESET}\n"

    else

        printf "   ${YELLOW}[!]${RESET} ${WHITE}${ICONO} %-13s${RESET}" \
            "$NOMBRE"

        if [[ -n "$PUERTO" ]]; then
            printf " ${GRAY}(%s)${RESET}" "$PUERTO"
        fi

        printf " ${RED}OFF${RESET}\n"

    fi
}

#=========================================================
# ESTADO DE PROTOCOLOS
#=========================================================

PROTOCOLOS=()

if ssh_instalado; then

    if ssh_activo; then
        PROTOCOLOS+=("SSH|${SSH_PORT}|🔐|ON")
    else
        PROTOCOLOS+=("SSH|${SSH_PORT}|🔐|OFF")
    fi

fi

if zivpn_instalado; then

    if zivpn_activo; then
        PROTOCOLOS+=("ZiVPN|${ZIPVPN_PORT}|📦|ON")
    else
        PROTOCOLOS+=("ZiVPN|${ZIPVPN_PORT}|📦|OFF")
    fi

fi

if dropbear_instalado; then

    if dropbear_activo; then
        PROTOCOLOS+=("Dropbear|${DROPBEAR_PORTS}|🚪|ON")
    else
        PROTOCOLOS+=("Dropbear|${DROPBEAR_PORTS}|🚪|OFF")
    fi

fi

if ssl_instalado; then

    if ssl_activo; then
        PROTOCOLOS+=("SSL/TLS|${SSL_PORTS}|🔒|ON")
    else
        PROTOCOLOS+=("SSL/TLS|${SSL_PORTS}|🔒|OFF")
    fi

fi

if badvpn_instalado; then

    if badvpn_activo; then
        PROTOCOLOS+=("BadVPN|${BADVPN_PORTS}|⚡|ON")
    else
        PROTOCOLOS+=("BadVPN|${BADVPN_PORTS}|⚡|OFF")
    fi

fi

if udpcustom_instalado; then

    if udpcustom_activo; then
        PROTOCOLOS+=("UDP Custom|${UDP_CUSTOM_PORT}|🚀|ON")
    else
        PROTOCOLOS+=("UDP Custom|${UDP_CUSTOM_PORT}|🚀|OFF")
    fi

fi

if slowdns_instalado; then

    if slowdns_activo; then
        PROTOCOLOS+=("SlowDNS|${SLOWDNS_PORT}|🌐|ON")
    else
        PROTOCOLOS+=("SlowDNS|${SLOWDNS_PORT}|🌐|OFF")
    fi

fi

if xray_instalado; then

    if xray_activo; then
        PROTOCOLOS+=("Xray/V2Ray|${XRAY_PORT}|☁️|ON")
    else
        PROTOCOLOS+=("Xray/V2Ray|${XRAY_PORT}|☁️|OFF")
    fi

fi

if checkuser_instalado; then

    if checkuser_activo; then
        PROTOCOLOS+=("CheckUser||👤|ON")
    else
        PROTOCOLOS+=("CheckUser||👤|OFF")
    fi

fi

if openvpn_instalado; then

    if openvpn_activo; then
        PROTOCOLOS+=("OpenVPN|${OPENVPN_PORT}|🔐|ON")
    else
        PROTOCOLOS+=("OpenVPN|${OPENVPN_PORT}|🔐|OFF")
    fi

fi

if hysteria_instalado; then

    if hysteria_activo; then
        PROTOCOLOS+=("Hysteria||🛡️|ON")
    else
        PROTOCOLOS+=("Hysteria||🛡️|OFF")
    fi

fi

if bhttp_instalado; then

    if bhttp_activo; then
        PROTOCOLOS+=("BHTTP|${BHTTP_PORT}|🌐|ON")
    else
        PROTOCOLOS+=("BHTTP|${BHTTP_PORT}|🌐|OFF")
    fi

fi

#=========================================================
# VPS
#=========================================================

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${BOLD}${WHITE}             KEVIN TECH CONTROL PANEL${RESET}             ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY}                  PREMIUM EDITION${RESET}                  ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo ""

echo -e " ${GOLD}◆${RESET} ${YELLOW}OS${RESET}      ${GRAY}:${RESET} ${WHITE}$OS${RESET}"

echo -e " ${GOLD}◆${RESET} ${YELLOW}UPTIME${RESET}  ${GRAY}:${RESET} ${WHITE}$UPTIME${RESET}"

echo -e " ${GOLD}◆${RESET} ${YELLOW}IP/DOM${RESET}  ${GRAY}:${RESET} ${SKY}$IP${RESET} ${GRAY}/${RESET} ${PINK}${SERVER_DOMAIN:-sin-dominio}${RESET}"

echo -e " ${GOLD}◆${RESET} ${YELLOW}DISCO${RESET}   ${GRAY}:${RESET} ${WHITE}$DISK usado${RESET}"

echo -e " ${GOLD}◆${RESET} ${YELLOW}CPU${RESET}     ${GRAY}:${RESET} ${LIME}${CPU_USE}%${RESET} ${GRAY}|${RESET} ${WHITE}Cores: $CPU${RESET}"

echo -e " ${GOLD}◆${RESET} ${YELLOW}RAM${RESET}     ${GRAY}:${RESET} ${LIME}${USED_RAM}/${TOTAL_RAM}${RESET} ${GRAY}|${RESET} ${WHITE}Libre: $FREE_RAM${RESET}"

#=========================================================
# PROTOCOLOS
#=========================================================

echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " ${MAGENTA}${BOLD}◆ PROTOCOLOS INSTALADOS${RESET}"

echo ""

TOTAL_PROTO=${#PROTOCOLOS[@]}

if (( TOTAL_PROTO == 0 )); then

    echo -e "   ${GRAY}○ No hay protocolos instalados${RESET}"

else

    for ITEM in "${PROTOCOLOS[@]}"; do

        IFS='|' read -r NOMBRE PUERTO ICONO ESTADO <<< "$ITEM"

        mostrar_protocolo \
            "$NOMBRE" \
            "$PUERTO" \
            "$ICONO" \
            "$ESTADO"

    done

fi

echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

#=========================================================
# CUENTAS
#=========================================================

echo -e " ${BLUE}${BOLD}◆ CUENTAS POR PROTOCOLO${RESET}"

echo ""

if ssh_instalado; then

    printf "   ${WHITE}SSH${RESET}        ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
        "$SSH_COUNT" "$SSH_ONLINE"

fi

if dropbear_instalado; then

    printf "   ${WHITE}Dropbear${RESET}   ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
        "$DROPBEAR_COUNT" "$DROPBEAR_ONLINE"

fi

if xray_instalado; then

    printf "   ${WHITE}V2Ray${RESET}      ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
        "$V2RAY_COUNT" "$V2RAY_ONLINE"

fi

if hysteria_instalado; then

    printf "   ${WHITE}Hysteria${RESET}   ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
        "$HYSTERIA_COUNT" "$HYSTERIA_ONLINE"

fi

if openvpn_instalado; then

    printf "   ${WHITE}OpenVPN${RESET}    ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
        "$OPENVPN_COUNT" "$OPENVPN_ONLINE"

fi

if bhttp_instalado; then

    printf "   ${WHITE}BHTTP${RESET}      ${GRAY}:${RESET} ${CYAN}SSH${RESET} ${GRAY}(usa cuentas SSH)${RESET}\n"

fi

echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

#=========================================================
# OPCIONES
#=========================================================

echo -e " ${GOLD}${BOLD}[01]${RESET} ${WHITE}👥 Usuarios SSH${RESET}        ${GOLD}${BOLD}[05]${RESET} ${WHITE}📦 Instalar protocolos${RESET}"

echo -e " ${GOLD}${BOLD}[02]${RESET} ${WHITE}🛩️ Optimizar VPS${RESET}       ${GOLD}${BOLD}[06]${RESET} ${WHITE}🔄 Update / Remove${RESET}"

echo -e " ${GOLD}${BOLD}[03]${RESET} ${WHITE}🌐 Cambiar dominio${RESET}     ${GOLD}${BOLD}[00]${RESET} ${WHITE}🚪 Salir${RESET}"

echo -e " ${GOLD}${BOLD}[04]${RESET} ${WHITE}⚒️ Auto inicio${RESET}"

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

#=========================================================
# VERSIÓN
#=========================================================

if [[ "$NUEVA_VERSION" != "No disponible" &&
      "$NUEVA_VERSION" != "$VERSION_ACTUAL" ]]; then

    echo -e "${YELLOW}  ⚡ NUEVA VERSIÓN DISPONIBLE: ${GREEN}${NUEVA_VERSION}${RESET}"

    echo -e "${GRAY}  Versión instalada: ${WHITE}${VERSION_ACTUAL}${RESET}"

else

    echo -e "${GREEN}  ✔ SISTEMA ACTUALIZADO${RESET}"

    echo -e "${GRAY}  Versión: ${WHITE}${VERSION_ACTUAL}${RESET}"

fi

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

echo -e "${WHITE}         Kevin Tech Multi Script${RESET}"

echo -e "${GRAY}              Premium Edition${RESET}"

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

echo ""

echo -ne "${CYAN}${BOLD}➜${RESET} ${WHITE}Seleccione una opción ${GRAY}➤${RESET} "

read -r OPCION

#=========================================================
# CASE
#=========================================================

case "$OPCION" in

1)

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                 👥 CREACION DE USUARIOS                     ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""

    if [[ -f "$BASE/usuarios/menu.sh" ]]; then

        bash "$BASE/usuarios/menu.sh"

    else

        echo -e "${RED}❌ El módulo de usuarios no está instalado.${RESET}"

        sleep 2

    fi

    exec bash "$BASE/menu.sh"

    ;;

2)

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                    🚀 OPTIMIZAR VPS                         ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""

    if [[ -f "$BASE/herramientas/optimizar.sh" ]]; then

        bash "$BASE/herramientas/optimizar.sh"

    else

        echo -e "${RED}❌ No se encontró optimizar.sh${RESET}"

        sleep 2

    fi

    exec bash "$BASE/menu.sh"

    ;;

3)

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                  🌐 CAMBIAR DOMINIO                         ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""

    if [[ -f "$BASE/herramientas/change-domain" ]]; then

        bash "$BASE/herramientas/change-domain"

    else

        echo -e "${RED}❌ No se encontró change-domain.${RESET}"

        sleep 2

    fi

    exec bash "$BASE/menu.sh"

    ;;

4)

    FILE="/etc/profile.d/kevintech.sh"

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                    🔄 AUTO INICIO                           ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""

    if [[ "$AUTO_START" == "OFF" ]]; then

        sed -i 's/^AUTO_START=.*/AUTO_START=ON/' "$CONFIG"

        cat > "$FILE" <<'EOF'
#!/bin/bash

if [[ $- == *i* ]]; then
    menu
fi
EOF

        chmod +x "$FILE"

        echo -e "${GREEN}✅ Auto inicio activado correctamente.${RESET}"

    else

        sed -i 's/^AUTO_START=.*/AUTO_START=OFF/' "$CONFIG"

        rm -f "$FILE"

        echo -e "${YELLOW}⚠️ Auto inicio desactivado.${RESET}"

    fi

    sleep 2

    exec bash "$BASE/menu.sh"

    ;;

5)

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                📦 INSTALADOR DE PROTOCOLOS                  ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""

    if [[ -f "$BASE/protocolos/menu.sh" ]]; then

        bash "$BASE/protocolos/menu.sh"

    else

        echo -e "${RED}❌ No se encontró el menú de protocolos.${RESET}"

        sleep 2

    fi

    exec bash "$BASE/menu.sh"

    ;;

6)

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║                    🛠 UPDATE / REMOVE                       ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""

    echo -e "${YELLOW}[1]${WHITE} 🗑 Remover Script"
    echo -e "${YELLOW}[2]${WHITE} 🔄 Actualizar Script"
    echo -e "${YELLOW}[0]${WHITE} 🔙 Volver"

    echo ""

    read -rp "$(echo -e "${CYAN}➜ Seleccione una opción ${WHITE}➤ ${RESET}")" OP6

    case "$OP6" in

        1)

            clear

            echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${WHITE}║                  ⚠️ ELIMINAR SCRIPT                         ║${RESET}"
            echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

            echo ""

            echo -e "${YELLOW}[1]${WHITE} 🗑 Eliminar Kevin Tech Multi Script"
            echo -e "${YELLOW}[2]${WHITE} ♻️ Reconstruir / Reinstalar VPS"
            echo -e "${YELLOW}[0]${WHITE} 🔙 Volver"

            echo ""

            read -rp "$(echo -e "${CYAN}➜ Seleccione una opción ${WHITE}➤ ${RESET}")" OPDEL

            case "$OPDEL" in

                1)

                    clear

                    echo -e "${RED}⚠️ Eliminando Kevin Tech Multi Script...${RESET}"

                    sleep 1

                    rm -rf /etc/kevintech

                    rm -f /usr/local/bin/menu

                    rm -f /etc/profile.d/kevintech.sh

                    echo ""

                    echo -e "${GREEN}✅ Script eliminado correctamente.${RESET}"
                    echo -e "${GREEN}🧹 Sistema limpiado correctamente.${RESET}"

                    sleep 3

                    exit

                    ;;

                2)

                    clear

                    echo -e "${YELLOW}⚠️ Esta operación puede borrar/reconstruir el VPS.${RESET}"
                    echo ""

                    read -rp "Escribe RECONSTRUIR para continuar: " CONFIRMAR

                    if [[ "$CONFIRMAR" != "RECONSTRUIR" ]]; then

                        echo ""
                        echo -e "${GREEN}Operación cancelada.${RESET}"
                        sleep 2
                        exec menu

                    fi

                    echo ""
                    echo -e "${YELLOW}♻️ Iniciando reconstrucción del VPS...${RESET}"

                    cd /root || exit

                    wget -q \
                        https://raw.githubusercontent.com/oktaviaps/rebuild-vps/main/uinstal \
                        -O uinstal

                    chmod +x uinstal

                    ./uinstal

                    ;;

                0)

                    exec menu

                    ;;

                *)

                    echo -e "${RED}❌ Opción inválida.${RESET}"

                    sleep 2

                    exec menu

                    ;;

            esac

            ;;

        2)

            clear

            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                 🔄 ACTUALIZANDO SCRIPT${RESET}              ${CYAN}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

            echo ""

            UPDATE="/etc/kevintech/update.sh"

            if [[ ! -f "$UPDATE" ]]; then

                echo -e "${RED}❌ No se encontró update.sh${RESET}"

                echo ""

                echo -e "${YELLOW}Ubicación esperada:${RESET}"

                echo -e " ${GRAY}➜${RESET} ${WHITE}$UPDATE${RESET}"

                sleep 3

                exec menu

            fi

            chmod +x "$UPDATE"

            echo -e "${CYAN}◆${RESET} ${WHITE}Ejecutando actualizador...${RESET}"

            echo ""

            bash "$UPDATE"

            STATUS=$?

            echo ""

            if [[ $STATUS -eq 0 ]]; then

                echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}        ✅ ACTUALIZACIÓN COMPLETADA CORRECTAMENTE${RESET}      ${GREEN}║${RESET}"
                echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

            else

                echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${RED}║${RESET} ${WHITE}${BOLD}              ❌ ERROR EN LA ACTUALIZACIÓN${RESET}             ${RED}║${RESET}"
                echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

            fi

            echo ""

            sleep 2

            exec menu

            ;;

        0)

            exec menu

            ;;

        *)

            echo -e "${RED}❌ Opción inválida.${RESET}"

            sleep 2

            exec menu

            ;;

    esac

    ;;

0)

    clear

    echo ""

    echo -e "${GREEN}👋 Gracias por usar Kevin Tech Multi Script Premium.${RESET}"

    echo ""

    exit

    ;;

*)

    echo ""

    echo -e "${RED}❌ Opción inválida.${RESET}"

    sleep 1

    exec bash "$BASE/menu.sh"

    ;;

esac
