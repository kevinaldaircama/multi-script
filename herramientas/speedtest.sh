#!/bin/bash

#==================================================
# KevinTech Multi Script
# Speedtest
#==================================================

BASE="/etc/kevintech"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

instalar(){

if command -v speedtest >/dev/null 2>&1; then
    return
fi

if command -v speedtest-cli >/dev/null 2>&1; then
    return
fi

echo ""
echo "📦 Instalando Speedtest..."

apt-get update -y >/dev/null 2>&1

apt-get install -y speedtest-cli >/dev/null 2>&1

}

ejecutar(){

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}              🚀 SPEEDTEST${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

instalar

if command -v speedtest >/dev/null 2>&1; then

    speedtest

elif command -v speedtest-cli >/dev/null 2>&1; then

    speedtest-cli

else

    echo ""
    echo -e "${RED}❌ No fue posible instalar Speedtest.${RESET}"

fi

echo ""
read -n1 -r -p "Presione una tecla para continuar..."

}

while true
do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}              🚀 SPEEDTEST${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo " [1] ➮ Ejecutar Speedtest"
echo ""
echo " [0] ➮ Regresar"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)
ejecutar
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
