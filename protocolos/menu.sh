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

#==============================
# Detectar estado de OpenSSH
#==============================

if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
    OPENSSH_STATUS="ON"
else
    OPENSSH_STATUS="OFF"
fi

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         🛡️ KevinTech Multi Script 🛡️"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "            📢 INSTALADOR DE PROTOCOLOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

printf " [01] ➮ OpenSSH          [%s]\n" "$OPENSSH_STATUS"
printf " [02] ➮ Dropbear         [%s]\n" "$DROPBEAR"
printf " [03] ➮ OpenVPN          [%s]\n" "$OPENVPN"
printf " [04] ➮ SSL/TLS          [%s]\n" "$SSL"
printf " [05] ➮ Shadowsocks-R    [%s]\n" "$SHADOWSOCKS"
printf " [06] ➮ Squid Proxy      [%s]\n" "$SQUID"
printf " [07] ➮ Proxy Python     [OFF]\n"
printf " [08] ➮ V2Ray            [%s]\n" "$V2RAY"
printf " [09] ➮ Clash            [OFF]\n"
printf " [10] ➮ Trojan-Go        [%s]\n" "$TROJAN"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                 HERRAMIENTAS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

printf " [11] ➮ Psiphon Server   [OFF]\n"
printf " [12] ➮ TCP DNS          [OFF]\n"
printf " [13] ➮ Webmin           [%s]\n" "$WEBMIN"
printf " [14] ➮ SlowDNS          [%s]\n" "$SLOWDNS"
printf " [15] ➮ SSL → Python     [OFF]\n"
printf " [16] ➮ SSLH             [OFF]\n"
printf " [17] ➮ Over WebSocket   [%s]\n" "$WEBSOCKET"
printf " [18] ➮ Socks5           [%s]\n" "$SOCKS5"
printf " [19] ➮ UDP Custom       [%s]\n" "$UDP_CUSTOM"
printf " [20] ➮ En desarrollo\n"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

printf " [21] ➮ Block Torrent\n"
printf " [22] ➮ BadVPN           [%s]\n" "$BADVPN"
printf " [23] ➮ TCP BBR          [%s]\n" "$BBR"
printf " [24] ➮ Fail2Ban         [%s]\n" "$FAIL2BAN"
printf " [25] ➮ Archivo Online\n"
printf " [26] ➮ Speedtest\n"
printf " [27] ➮ Detalles VPS\n"
printf " [28] ➮ Block Ads\n"
printf " [29] ➮ DNS Custom\n"
printf " [30] ➮ Herramientas\n"
printf " [31] ➮ Reiniciar Servicios\n"
printf " [32] ➮ Brook Server     [%s]\n" "$BROOK"
printf " [33] ➮ Firewall\n"
printf " [34] ➮ Cambiar Root Password\n"
printf " [35] ➮ AToken\n"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [0] ➮ Regresar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp " ► Opción: " OP

case "$OP" in
1)
while true; do

clear

if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
    SSH_STATUS="🟢 ACTIVO"
else
    SSH_STATUS="🔴 DETENIDO"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "            🔐 OPENSSH MANAGER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Estado : $SSH_STATUS"
echo ""
echo " Puertos configurados:"
grep "^Port" /etc/ssh/sshd_config | awk '{print "   • "$2}'
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [1] ➮ Agregar puerto SSH"
echo " [2] ➮ Cerrar puerto SSH"
echo " [3] ➮ Ver puertos SSH"
echo " [4] ➮ Reiniciar servicio SSH"
echo ""
echo " [0] ➮ Regresar"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp " ► Opción: " SSHOP

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
    bash "$BASE/protocolos/trojan.sh"
;;

10)
    bash "$BASE/protocolos/webmin.sh"
;;

11)
    bash "$BASE/protocolos/slowdns.sh"
;;

12)
    bash "$BASE/protocolos/websocket.sh"
;;

13)
    bash "$BASE/protocolos/socks5.sh"
;;

14)
    bash "$BASE/protocolos/udpcustom.sh"
;;

15)
    bash "$BASE/protocolos/badvpn.sh"
;;

16)
    bash "$BASE/protocolos/bbr.sh"
;;

17)
    bash "$BASE/protocolos/fail2ban.sh"
;;

18)
    bash "$BASE/protocolos/brook.sh"
;;

19)
    bash "$BASE/protocolos/blocktorrent.sh"
;;

20)
    bash "$BASE/protocolos/onlinefile.sh"
;;

21)
    bash "$BASE/protocolos/speedtest.sh"
;;

22)
    bash "$BASE/protocolos/detalles.sh"
;;

23)
    bash "$BASE/protocolos/blockads.sh"
;;

24)
    bash "$BASE/protocolos/herramientas.sh"
;;

25)
    bash "$BASE/protocolos/reiniciar.sh"
;;

26)
    bash "$BASE/protocolos/firewall.sh"
;;

27)
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
