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

DNS_PORT="53"
SSH_PORT="22"

while true; do

clear

source "$CONFIG"

if [[ "$SLOWDNS" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}             🐌 SLOWDNS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado    : $STATUS"
echo -e " DNS       : ${SLOWDNS_DOMAIN:-NO CONFIGURADO}"
echo -e " Puerto    : $DNS_PORT UDP"
echo -e " SSH       : $SSH_PORT OpenSSH"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


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


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP


case "$OP" in


1)

if [[ "$SLOWDNS" == "OFF" ]]; then


clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        INSTALAR SLOWDNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -rp "Ingrese su dominio NS (ej: ns1.dominio.com): " NS_DOMAIN


if [[ -z "$NS_DOMAIN" ]]; then

echo "❌ Dominio vacío."
sleep 3
continue

fi


echo ""
echo "📦 Instalando dependencias..."

apt update -y >/dev/null 2>&1

apt install -y iodine >/dev/null 2>&1


echo "🔓 Desbloqueando servicio..."

systemctl unmask iodined >/dev/null 2>&1


echo "🌐 Liberando puerto DNS 53..."

systemctl disable --now systemd-resolved >/dev/null 2>&1

rm -f /etc/resolv.conf

echo "nameserver 8.8.8.8" > /etc/resolv.conf



echo "⚙️ Creando servicio SlowDNS..."


cat > /etc/systemd/system/iodined.service <<EOF

[Unit]
Description=SlowDNS Tunnel Server
After=network.target


[Service]
Type=simple

ExecStart=/usr/sbin/iodined -f -c -P kevintech 10.0.0.1 $NS_DOMAIN

Restart=always
RestartSec=5


[Install]
WantedBy=multi-user.target

EOF



systemctl daemon-reload

systemctl enable iodined

systemctl restart iodined



sed -i 's/^SLOWDNS=.*/SLOWDNS=ON/' "$CONFIG"

if grep -q "^SLOWDNS_DOMAIN=" "$CONFIG"; then

sed -i "s/^SLOWDNS_DOMAIN=.*/SLOWDNS_DOMAIN=$NS_DOMAIN/" "$CONFIG"

else

echo "SLOWDNS_DOMAIN=$NS_DOMAIN" >> "$CONFIG"

fi


SLOWDNS="ON"

SLOWDNS_DOMAIN="$NS_DOMAIN"



echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       ✅ SLOWDNS ACTIVADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🌐 NS Dominio : $NS_DOMAIN"
echo "🔌 DNS Puerto : 53 UDP"
echo "🔐 SSH Puerto : 22"
echo "🔑 Password   : kevintech"
echo ""
echo "📱 Configuración App:"
echo "NS Host  : $NS_DOMAIN"
echo "SSH Host : IP DEL VPS"
echo "SSH Port : 22"


else


read -rp "¿Eliminar SlowDNS? (s/n): " R

[[ "$R" != "s" ]] && continue


systemctl stop iodined 2>/dev/null

systemctl disable iodined 2>/dev/null


rm -f /etc/systemd/system/iodined.service


apt remove iodine -y >/dev/null 2>&1


sed -i 's/^SLOWDNS=.*/SLOWDNS=OFF/' "$CONFIG"


SLOWDNS="OFF"


echo "✅ SlowDNS eliminado."


fi


sleep 3

;;


2)

systemctl restart iodined

echo "✅ SlowDNS reiniciado."

sleep 2

;;


3)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "          ESTADO SLOWDNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl status iodined --no-pager


echo ""

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
