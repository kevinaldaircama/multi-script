#!/bin/bash

#==================================================
# KevinTech Multi Script
# Instalador de Protocolos
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

clear

echo "      =====>>►► 🛡️ KevinTech ⚔️ Multi Script 🛡️ ◄◄<<====="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "            📢 INSTALACIÓN DE PROTOCOLOS 📢"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

printf " [01]➮ OpenSSH         [%s]\n" "$OPENSSH"
printf " [02]➮ DROPBEAR        [%s]\n" "$DROPBEAR"
printf " [03]➮ OPENVPN         [%s]\n" "$OPENVPN"
printf " [04]➮ SSL/TLS         [%s]\n" "$SSL"
printf " [05]➮ SHADOWSOCKS-R   [%s]\n" "$SHADOWSOCKS"
printf " [06]➮ SQUID           [%s]\n" "$SQUID"
printf " [07]➮ PROXY PYTHON    [OFF]\n"
printf " [08]➮ V2RAY           [%s]\n" "$V2RAY"
printf " [09]➮ CLASH           [OFF]\n"
printf " [10]➮ TROJAN-GO       [%s]\n" "$TROJAN"

echo ""

printf " [11]➮ PSIPHON SERVER  [OFF]\n"
printf " [12]➮ TCP DNS         [OFF]\n"
printf " [13]➮ WEBMIN          [%s]\n" "$WEBMIN"
printf " [14]➮ SlowDNS         [%s]\n" "$SLOWDNS"
printf " [15]➮ SSL->PYTHON     [OFF]\n"
printf " [16]➮ SSLH            [OFF]\n"
printf " [17]➮ OVER WEBSOCKET  [%s]\n" "$WEBSOCKET"
printf " [18]➮ SOCKS5          [%s]\n" "$SOCKS5"
printf " [19]➮ UDP CUSTOM      [%s]\n" "$UDP_CUSTOM"
printf " [20]➮ EN DISEÑO\n"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

printf " [21]➮ BLOCK TORRENT\n"
printf " [22]➮ BadVPN          [%s]\n" "$BADVPN"
printf " [23]➮ TCP BBR         [%s]\n" "$BBR"
printf " [24]➮ FAIL2BAN        [%s]\n" "$FAIL2BAN"
printf " [25]➮ ARCHIVO ONLINE\n"
printf " [26]➮ SPEEDTEST\n"
printf " [27]➮ DETALLES VPS\n"
printf " [28]➮ BLOCK ADS\n"
printf " [29]➮ DNS CUSTOM\n"
printf " [30]➮ HERRAMIENTAS\n"
printf " [31]➮ REINICIAR SERVICIOS\n"
printf " [32]➮ BROOK SERVER    [%s]\n" "$BROOK"
printf " [33]➮ FIREWALL\n"
printf " [34]➮ CAMBIAR ROOT PASSWORD\n"
printf " [35]➮ AToken\n"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo " [0] ➮ REGRESAR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp " ► Opcion : " OP
#==================================================
# Acciones del menú
#==================================================

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
