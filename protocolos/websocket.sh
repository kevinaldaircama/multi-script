#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="websocket"
PORT="80"

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          🌐 WEBSOCKET MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$WEBSOCKET" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e " Estado     : $STATUS"
echo -e " Puerto     : $PORT"
echo -e " Servicio   : $SERVICE"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$WEBSOCKET" == "ON" ]]; then
cat <<EOF
 [1] ➮ Desinstalar WebSocket
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar WebSocket
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)
if [[ "$WEBSOCKET" == "ON" ]]; then

read -rp "¿Desinstalar WebSocket? (s/n): " R
[[ "$R" != "s" ]] && continue

systemctl stop $SERVICE 2>/dev/null
systemctl disable $SERVICE 2>/dev/null

sed -i 's/WEBSOCKET=ON/WEBSOCKET=OFF/' "$CONFIG"
WEBSOCKET=OFF

echo ""
echo "✅ WebSocket desinstalado."

else

systemctl enable $SERVICE 2>/dev/null
systemctl restart $SERVICE 2>/dev/null

sed -i 's/WEBSOCKET=OFF/WEBSOCKET=ON/' "$CONFIG"
WEBSOCKET=ON

echo ""
echo "✅ WebSocket instalado."

fi

sleep 2
;;

2)

if [[ "$WEBSOCKET" == "ON" ]]; then
systemctl restart $SERVICE

echo ""
echo "✅ Servicio reiniciado."
sleep 2
fi

;;

3)

if [[ "$WEBSOCKET" == "ON" ]]; then
systemctl status $SERVICE --no-pager

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
