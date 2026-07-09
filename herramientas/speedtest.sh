#!/bin/bash

BASE="/etc/kevintech"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
RESET="\e[0m"

while true; do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}              🚀 SPEEDTEST${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
echo " [1] ➮ Ejecutar Speedtest"
echo
echo " [0] ➮ Regresar"
echo

read -rp " ► Opción: " OP

case "$OP" in

1)
    if command -v speedtest >/dev/null 2>&1; then
        speedtest
    else
        echo
        echo -e "${RED}❌ Speedtest oficial no está instalado.${RESET}"
        echo
        echo "Instálalo primero y vuelve a intentarlo."
    fi

    echo
    read -n1 -r -p "Presione una tecla para continuar..."
;;

0)
    exec bash "$BASE/herramientas/menu.sh"
;;

*)
    echo "❌ Opción inválida."
    sleep 2
;;

esac

done
