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
echo -e "${YELLOW}               📡 PROTOCOLOS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf "${GREEN} [01]${WHITE} ➮ OpenSSH        [%s]\n" "$OPENSSH"
printf "${GREEN} [02]${WHITE} ➮ WebSocket      [%s]\n" "$WEBSOCKET"
printf "${GREEN} [03]${WHITE} ➮ ZIPVPN         [%s]\n" "$ZIPVPN"
printf "${GREEN} [04]${WHITE} ➮ Dropbear       [%s]\n" "$DROPBEAR"
printf "${GREEN} [05]${WHITE} ➮ SSL/TLS        [%s]\n" "$SSL"
printf "${GREEN} [06]${WHITE} ➮ BadVPN         [%s]\n" "$BADVPN"
printf "${GREEN} [07]${WHITE} ➮ UDP Custom     [%s]\n" "$UDP_CUSTOM"
printf "${GREEN} [08]${WHITE} ➮ SlowDNS        [%s]\n" "$SLOWDNS"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW}                 🛠 SISTEMA${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf "${GREEN} [09]${WHITE} ➮ Herramientas\n"
printf "${GREEN} [10]${WHITE} ➮ Reiniciar Servicios\n"
printf "${GREEN} [11]${WHITE} ➮ Firewall\n"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW} [00]${WHITE} ➮ Regresar${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
read -rp " ► Opción: " OP

case "$OP" in

1)
bash "$BASE/protocolos/openssh.sh"
;;

2)
bash "$BASE/protocolos/websocket.sh"
;;

3)
bash "$BASE/protocolos/zipvpn.sh"
;;

4)
bash "$BASE/protocolos/dropbear.sh"
;;

5)
bash "$BASE/protocolos/ssl.sh"
;;

6)
bash "$BASE/protocolos/badvpn.sh"
;;

7)
bash "$BASE/protocolos/udpcustom.sh"
;;

8)
bash "$BASE/protocolos/slowdns.sh"
;;

9)
bash "$BASE/herramientas/menu.sh"
;;

10)
bash "$BASE/herramientas/reiniciar.sh"
;;

11)
bash "$BASE/herramientas/firewall.sh"
;;

0)
exec bash "$BASE/menu.sh"
;;

*)
echo "❌ Opción inválida."
sleep 2
exec bash "$BASE/protocolos/menu.sh"
;;

esac
