#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="nginx"
PORT="81"

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}             🌍 NGINX MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$NGINX" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e " Estado     : $STATUS"
echo -e " Puerto     : $PORT"
echo -e " Servicio   : nginx"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$NGINX" == "ON" ]]; then
cat <<EOF
 [1] ➮ Desinstalar Nginx
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar Nginx
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)

if [[ "$NGINX" == "ON" ]]; then

read -rp "¿Desinstalar Nginx? (s/n): " R
[[ "$R" != "s" ]] && continue

systemctl stop nginx
systemctl disable nginx

apt remove nginx -y

sed -i 's/NGINX=ON/NGINX=OFF/' "$CONFIG"
NGINX=OFF

echo ""
echo "✅ Nginx desinstalado."

else

apt update
apt install nginx -y

systemctl enable nginx
systemctl restart nginx

sed -i 's/NGINX=OFF/NGINX=ON/' "$CONFIG"
NGINX=ON

echo ""
echo "✅ Nginx instalado."

fi

sleep 2

;;

2)

if [[ "$NGINX" == "ON" ]]; then

systemctl restart nginx

echo ""
echo "✅ Servicio reiniciado."

sleep 2

fi

;;

3)

if [[ "$NGINX" == "ON" ]]; then

systemctl status nginx --no-pager

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
