#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          🌐 SYSTEM DNS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$SYSTEMDNS" == "ON" ]]; then
    ESTADO="${GREEN}🟢 ACTIVO${RESET}"
else
    ESTADO="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e " Estado     : $ESTADO"
echo -e " Puerto     : 53"
echo -e " Servicio   : systemd-resolved"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$SYSTEMDNS" == "ON" ]]; then
cat <<EOF
 [1] ➮ Desinstalar System DNS
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar System DNS
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)

if [[ "$SYSTEMDNS" == "ON" ]]; then

read -rp "¿Desinstalar System DNS? (s/n): " R
[[ "$R" != "s" ]] && continue

systemctl stop systemd-resolved
systemctl disable systemd-resolved

sed -i 's/SYSTEMDNS=ON/SYSTEMDNS=OFF/' "$CONFIG"
SYSTEMDNS=OFF

echo ""
echo "✅ System DNS desinstalado."

sleep 2

else

systemctl enable systemd-resolved
systemctl restart systemd-resolved

sed -i 's/SYSTEMDNS=OFF/SYSTEMDNS=ON/' "$CONFIG"
SYSTEMDNS=ON

echo ""
echo "✅ System DNS instalado."

sleep 2

fi

;;

2)

if [[ "$SYSTEMDNS" == "ON" ]]; then

systemctl restart systemd-resolved

echo ""
echo "✅ Servicio reiniciado."

sleep 2

fi

;;

3)

if [[ "$SYSTEMDNS" == "ON" ]]; then

systemctl status systemd-resolved --no-pager

echo ""
read -n1 -r -p "Presione una tecla..."

fi

;;

0)

exec bash "$BASE/protocolos/menu.sh"

;;

*)

echo ""
echo "❌ Opción inválida."
sleep 2

;;

esac

done
