#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="dropbear"
PORT=""

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          🔐 DROPBEAR MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$DROPBEAR" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e " Estado     : $STATUS"
echo -e " Puerto     : $PORT"
echo -e " Servicio   : dropbear"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$DROPBEAR" == "ON" ]]; then
cat <<EOF
 [1] ➮ Desinstalar Dropbear
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar Dropbear
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)

if [[ "$DROPBEAR" == "ON" ]]; then

read -rp "¿Desinstalar Dropbear? (s/n): " R
[[ "$R" != "s" ]] && continue

systemctl stop dropbear
systemctl disable dropbear

apt remove dropbear -y

sed -i 's/DROPBEAR=ON/DROPBEAR=OFF/' "$CONFIG"
DROPBEAR=OFF

echo ""
echo "✅ Dropbear desinstalado."

else

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       INSTALAR DROPBEAR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "PUERTOS RECOMENDADOS:"
echo " [1] Puerto 90"
echo " [2] Puerto 143"
echo ""

read -rp "Selecciona puerto: " DP

case "$DP" in

1)
PORT="90"
;;

2)
PORT="143"
;;

*)
echo "❌ Puerto inválido"
sleep 2
continue
;;

esac


echo ""
echo "📦 Instalando Dropbear..."

apt update
apt install dropbear -y


echo "⚙️ Configurando puerto $PORT..."

sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$PORT/" /etc/default/dropbear


systemctl enable dropbear
systemctl restart dropbear


sed -i 's/DROPBEAR=OFF/DROPBEAR=ON/' "$CONFIG"

DROPBEAR=ON


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DROPBEAR INSTALADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔐 Puerto SSH : $PORT"

fi

sleep 2

;;

2)

if [[ "$DROPBEAR" == "ON" ]]; then

systemctl restart dropbear

echo ""
echo "✅ Servicio reiniciado."

sleep 2

fi

;;

3)

if [[ "$DROPBEAR" == "ON" ]]; then

systemctl status dropbear --no-pager

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
