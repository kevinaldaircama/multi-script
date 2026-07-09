#!/bin/bash

BASE="/etc/kevintech"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

abrir(){

read -rp "Puerto: " PORT

ufw allow "$PORT"

echo ""
echo -e "${GREEN}✅ Puerto $PORT abierto.${RESET}"

sleep 2

}

cerrar(){

read -rp "Puerto: " PORT

ufw delete allow "$PORT"

echo ""
echo -e "${GREEN}✅ Puerto $PORT cerrado.${RESET}"

sleep 2

}

estado(){

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}            🔥 FIREWALL${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

ufw status numbered

echo ""
read -n1 -r -p "Presione una tecla..."

}

while true
do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}            🔥 FIREWALL${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo " [1] ➮ Abrir Puerto"
echo " [2] ➮ Cerrar Puerto"
echo " [3] ➮ Estado Firewall"
echo ""
echo " [0] ➮ Regresar"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)
abrir
;;

2)
cerrar
;;

3)
estado
;;

0)
exec bash "$BASE/herramientas/menu.sh"
;;

*)
echo ""
echo -e "${RED}❌ Opción inválida.${RESET}"
sleep 2
;;

esac

done
