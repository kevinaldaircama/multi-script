#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="iodined"
PORT="53"
DOMAIN="${SERVER_DOMAIN}"

while true; do

clear

source "$CONFIG"

if [[ "$SLOWDNS" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              🐌 SLOWDNS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado     : $STATUS"
echo -e " Puerto DNS : $PORT UDP"
echo -e " Servicio   : Iodine DNS Tunnel"
echo -e " Dominio    : ${DOMAIN:-NO CONFIGURADO}"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


if [[ "$SLOWDNS" == "ON" ]]; then

cat <<EOF
 [1] ➮ Desinstalar SlowDNS
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF

else

cat <<EOF
 [1] ➮ Instalar SlowDNS
 [0] ➮ Regresar
EOF

fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP


case "$OP" in


1)

if [[ "$SLOWDNS" == "ON" ]]; then


read -rp "¿Eliminar SlowDNS? (s/n): " R

[[ "$R" != "s" ]] && continue


systemctl stop $SERVICE 2>/dev/null
systemctl disable $SERVICE 2>/dev/null


apt remove iodine -y >/dev/null 2>&1


rm -f /etc/systemd/system/$SERVICE.service


systemctl daemon-reload


sed -i 's/^SLOWDNS=.*/SLOWDNS=OFF/' "$CONFIG"

SLOWDNS="OFF"


echo ""
echo "✅ SlowDNS eliminado."


else


clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        INSTALANDO SLOWDNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


if [[ -z "$SERVER_DOMAIN" ]]; then

echo "❌ Falta dominio configurado."

sleep 3
continue

fi


apt update -y >/dev/null 2>&1

apt install -y iodine >/dev/null 2>&1


echo "🔐 Creando servicio SlowDNS..."


cat > /etc/systemd/system/$SERVICE.service <<EOF

[Unit]
Description=SlowDNS DNS Tunnel
After=network.target


[Service]
Type=simple
ExecStart=/usr/sbin/iodined -f -c -P kevintech 10.0.0.1 dns.${DOMAIN}
Restart=always
RestartSec=5


[Install]
WantedBy=multi-user.target

EOF


systemctl daemon-reload

systemctl enable $SERVICE

systemctl restart $SERVICE


sed -i 's/^SLOWDNS=.*/SLOWDNS=ON/' "$CONFIG"

SLOWDNS="ON"


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       ✅ SLOWDNS ACTIVADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "DNS Puerto : 53"
echo "Dominio    : dns.$DOMAIN"


fi


sleep 3

;;


2)

systemctl restart $SERVICE

echo ""
echo "✅ SlowDNS reiniciado."

sleep 2

;;


3)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ESTADO SLOWDNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl status $SERVICE --no-pager


echo ""
echo "Puerto DNS:"
ss -ulnp | grep ":53"


echo ""

read -n1 -r -p "Presione una tecla..."

;;


0)

exec bash "$BASE/protocolos/menu.sh"

;;


*)

echo "❌ Opción inválida."

sleep 2

;;

esac

done
