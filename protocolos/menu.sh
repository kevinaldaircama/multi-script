#!/bin/bash

#==================================================
# KevinTech Multi Script
# Instalador de Protocolos
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No se encontró la configuración."
    exit 1
}

source "$CONFIG" 2>/dev/null

clear

CYAN="\e[1;96m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
YELLOW="\e[1;93m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

status_service() {

    local SERVICE="$1"
    local CONF="$2"

    if systemctl list-unit-files | grep -q "^${SERVICE}.service"; then
        if systemctl is-active --quiet "$SERVICE"; then
            echo -e "${GREEN}🟢 ACTIVO${RESET}"
        else
            echo -e "${RED}🔴 OFF${RESET}"
        fi
    else
        if [[ "$CONF" == "ON" ]]; then
            echo -e "${GREEN}🟢 ACTIVO${RESET}"
        else
            echo -e "${RED}🔴 OFF${RESET}"
        fi
    fi
}

OPENSSH_STATUS=$(status_service ssh "$OPENSSH")
DROPBEAR_STATUS=$(status_service dropbear_custom "$DROPBEAR")
SSL_STATUS=$(status_service haproxy "$SSL")
UDP_STATUS=$(status_service udp-custom "$UDP_CUSTOM")
SLOWDNS_STATUS=$(status_service dnstt "$SLOWDNS")
XRAY_STATUS=$(status_service xray "$V2RAY")

if [[ "$ZIPVPN" == "ON" ]]; then
    ZIPVPN_STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    ZIPVPN_STATUS="${RED}🔴 OFF${RESET}"
fi

if [[ "$BADVPN" == "ON" ]]; then
    BADVPN_STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    BADVPN_STATUS="${RED}🔴 OFF${RESET}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}           🛡 KevinTech Multi Script${RESET}"
echo -e "${WHITE}             MENÚ DE PROTOCOLOS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf " ${GREEN}[01]${RESET} 🔐 OpenSSH          %b\n" "$OPENSSH_STATUS"
printf " ${GREEN}[02]${RESET} 📦 ZIPVPN           %b\n" "$ZIPVPN_STATUS"
printf " ${GREEN}[03]${RESET} 🚪 Dropbear         %b\n" "$DROPBEAR_STATUS"
printf " ${GREEN}[04]${RESET} 🔒 SSL / TLS        %b\n" "$SSL_STATUS"
printf " ${GREEN}[05]${RESET} ⚡ BadVPN           %b\n" "$BADVPN_STATUS"
printf " ${GREEN}[06]${RESET} 🚀 UDP Custom       %b\n" "$UDP_STATUS"
printf " ${GREEN}[07]${RESET} 🌐 SlowDNS          %b\n" "$SLOWDNS_STATUS"
printf " ${GREEN}[08]${RESET} ☁️ Xray / V2Ray     %b\n" "$XRAY_STATUS"
printf " ${GREEN}[09]${RESET} 👤 CheckUser        %b\n" "$CHECKUSER_STATUS"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}                🛠 SISTEMA${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " ${GREEN}[10]${RESET} 🧰 Herramientas"
echo -e " ${GREEN}[11]${RESET} 🔄 Reiniciar Servicios"
echo -e " ${GREEN}[12]${RESET} 🔥 Firewall"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e " ${GREEN}[00]${RESET} ↩ Regresar"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
read -rp " ► Opción: " OP

case "$OP" in
1) bash "$BASE/protocolos/openssh.sh" ;;
2) bash "$BASE/protocolos/zipvpn.sh" ;;
3) bash "$BASE/protocolos/dropbear.sh" ;;
4) bash "$BASE/protocolos/ssl.sh" ;;
5) bash "$BASE/protocolos/badvpn.sh" ;;
6) bash "$BASE/protocolos/udpcustom.sh" ;;
7) bash "$BASE/protocolos/slowdns.sh" ;;
8) bash "$BASE/protocolos/v2ray.sh" ;;
9) bash "$BASE/protocolos/checkuser.sh" ;;
10) bash "$BASE/herramientas/menu.sh" ;;
11) bash "$BASE/herramientas/reiniciar.sh" ;;
12) bash "$BASE/herramientas/firewall.sh" ;;
0) exec bash "$BASE/menu.sh" ;;
*)
echo "❌ Opción inválida."
sleep 2
exec bash "$BASE/protocolos/menu.sh"
;;
esac
