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

source "$CONFIG"

clear

CYAN="\e[1;96m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
YELLOW="\e[1;93m"
GREEN="\e[1;92m"
WHITE="\e[1;97m"
RESET="\e[0m"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}        🛡️ KevinTech Multi Script 🛡️${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}            📢 INSTALADOR DE PROTOCOLOS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf "${GREEN} [01]${WHITE} ➮ OpenSSH           [%s]\n" "$OPENSSH"
printf "${GREEN} [02]${WHITE} ➮ System DNS        [%s]\n" "$SYSTEMDNS"
printf "${GREEN} [03]${WHITE} ➮ WebSocket         [%s]\n" "$WEBSOCKET"
printf "${GREEN} [04]${WHITE} ➮ Nginx             [%s]\n" "$NGINX"
printf "${GREEN} [05]${WHITE} ➮ Dropbear         [%s]\n" "$DROPBEAR"
printf "${GREEN} [06]${WHITE} ➮ SSL/TLS          [%s]\n" "$SSL"
printf "${GREEN} [07]${WHITE} ➮ BadVPN           [%s]\n" "$BADVPN"
printf "${GREEN} [08]${WHITE} ➮ UDP Custom       [%s]\n" "$UDP_CUSTOM"
printf "${GREEN} [09]${WHITE} ➮ SlowDNS         [%s]\n" "$SLOWDNS"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}            🛠 HERRAMIENTAS${RESET}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
printf "${GREEN} [10]${WHITE} ➮ Block Torrent\n"
printf "${GREEN} [11]${WHITE} ➮ Archivo Online\n"
printf "${GREEN} [12]${WHITE} ➮ Speedtest\n"
printf "${GREEN} [13]${WHITE} ➮ Detalles VPS\n"
printf "${GREEN} [14]${WHITE} ➮ Block Ads\n"
printf "${GREEN} [15]${WHITE} ➮ Herramientas\n"
printf "${GREEN} [16]${WHITE} ➮ Reiniciar Servicios\n"
printf "${GREEN} [17]${WHITE} ➮ Firewall\n"
printf "${GREEN} [18]${WHITE} ➮ Cambiar contraseña Root\n"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW} [0]${WHITE} ➮ Regresar${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
read -rp " ► Opción: " OP

case "$OP" in
1)
    bash "$BASE/protocolos/openssh.sh"
;;

2)
    bash "$BASE/protocolos/dropbear.sh"
;;

3)
    bash "$BASE/protocolos/openvpn.sh"
;;

4)
    bash "$BASE/protocolos/ssl.sh"
;;

5)
    bash "$BASE/protocolos/shadowsocks.sh"
;;

6)
    bash "$BASE/protocolos/squid.sh"
;;

7)
    bash "$BASE/protocolos/python.sh"
;;

8)
    bash "$BASE/protocolos/v2ray.sh"
;;

9)
    bash "$BASE/protocolos/clash.sh"
;;

10)
    bash "$BASE/protocolos/blocktorrent.sh"
;;

11)
    bash "$BASE/protocolos/onlinefile.sh"
;;

12)
    bash "$BASE/protocolos/speedtest.sh"
;;

13)
    bash "$BASE/protocolos/detalles.sh"
;;

14)
    bash "$BASE/protocolos/blockads.sh"
;;

15)
    bash "$BASE/protocolos/herramientas.sh"
;;

16)
    bash "$BASE/protocolos/reiniciar.sh"
;;

17)
    bash "$BASE/protocolos/firewall.sh"
;;

18)
    bash "$BASE/protocolos/rootpass.sh"
;;

0)
    exec bash "$BASE/menu.sh"
;;

*)
    echo ""
    echo "❌ Opción inválida."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
;;

esac
