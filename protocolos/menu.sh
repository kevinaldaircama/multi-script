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
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf "${GREEN} [21]${WHITE} ➮ Block Torrent\n"
printf "${GREEN} [22]${WHITE} ➮ BadVPN            [%s]\n" "$BADVPN"
printf "${GREEN} [23]${WHITE} ➮ TCP BBR           [%s]\n" "$BBR"
printf "${GREEN} [24]${WHITE} ➮ Fail2Ban          [%s]\n" "$FAIL2BAN"
printf "${GREEN} [25]${WHITE} ➮ Archivo Online\n"
printf "${GREEN} [26]${WHITE} ➮ Speedtest\n"
printf "${GREEN} [27]${WHITE} ➮ Detalles VPS\n"
printf "${GREEN} [28]${WHITE} ➮ Block Ads\n"
printf "${GREEN} [29]${WHITE} ➮ DNS Custom\n"
printf "${GREEN} [30]${WHITE} ➮ Herramientas\n"
printf "${GREEN} [31]${WHITE} ➮ Reiniciar Servicios\n"
printf "${GREEN} [32]${WHITE} ➮ Brook Server      [%s]\n" "$BROOK"
printf "${GREEN} [33]${WHITE} ➮ Firewall\n"
printf "${GREEN} [34]${WHITE} ➮ Cambiar Root Password\n"
printf "${GREEN} [35]${WHITE} ➮ AToken\n"

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
    bash "$BASE/protocolos/trojan.sh"
;;

11)
    bash "$BASE/protocolos/psiphon.sh"
;;

12)
    bash "$BASE/protocolos/tcpdns.sh"
;;

13)
    bash "$BASE/protocolos/webmin.sh"
;;

14)
    bash "$BASE/protocolos/slowdns.sh"
;;

15)
    bash "$BASE/protocolos/sslpython.sh"
;;

16)
    bash "$BASE/protocolos/sslh.sh"
;;

17)
    bash "$BASE/protocolos/websocket.sh"
;;

18)
    bash "$BASE/protocolos/socks5.sh"
;;

19)
    bash "$BASE/protocolos/udpcustom.sh"
;;

20)
    clear
    echo ""
    echo "🚧 Esta función aún está en desarrollo."
    sleep 2
    exec bash "$BASE/protocolos/menu.sh"
;;

21)
    bash "$BASE/protocolos/blocktorrent.sh"
;;

22)
    bash "$BASE/protocolos/badvpn.sh"
;;

23)
    bash "$BASE/protocolos/bbr.sh"
;;

24)
    bash "$BASE/protocolos/fail2ban.sh"
;;

25)
    bash "$BASE/protocolos/onlinefile.sh"
;;

26)
    bash "$BASE/protocolos/speedtest.sh"
;;

27)
    bash "$BASE/protocolos/detalles.sh"
;;

28)
    bash "$BASE/protocolos/blockads.sh"
;;

29)
    bash "$BASE/protocolos/dnscustom.sh"
;;

30)
    bash "$BASE/protocolos/herramientas.sh"
;;

31)
    bash "$BASE/protocolos/reiniciar.sh"
;;

32)
    bash "$BASE/protocolos/brook.sh"
;;

33)
    bash "$BASE/protocolos/firewall.sh"
;;

34)
    bash "$BASE/protocolos/rootpass.sh"
;;

35)
    bash "$BASE/protocolos/atoken.sh"
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
