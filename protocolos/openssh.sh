#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

clear

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}            🔐 OPENSSH MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$OPENSSH" == "ON" ]]; then
    ESTADO="${GREEN}🟢 ACTIVO${RESET}"
else
    ESTADO="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e " Estado     : $ESTADO"
echo -e " Puerto     : 22"
echo -e " Servicio   : ssh"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$OPENSSH" == "ON" ]]; then
cat <<EOF
 [1] ➮ Desinstalar OpenSSH
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar OpenSSH
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
read -rp " ► Opción: " OP

case $OP in

1)

if [[ "$OPENSSH" == "ON" ]]; then

echo ""
read -rp "¿Desinstalar OpenSSH? (s/n): " R

[[ "$R" != "s" ]] && continue

apt remove openssh-server -y

sed -i 's/OPENSSH=ON/OPENSSH=OFF/' "$CONFIG"

OPENSSH=OFF

echo ""
echo "✅ OpenSSH desinstalado."

sleep 2

else

apt update

apt install openssh-server -y

systemctl enable ssh

systemctl restart ssh

sed -i 's/OPENSSH=OFF/OPENSSH=ON/' "$CONFIG"

OPENSSH=ON

echo ""
echo "✅ OpenSSH instalado."

sleep 2

fi

;;

2)

if [[ "$OPENSSH" == "ON" ]]; then

systemctl restart ssh

echo ""
echo "✅ Servicio reiniciado."

sleep 2

fi

;;

3)

if [[ "$OPENSSH" == "ON" ]]; then

systemctl status ssh --no-pager

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
