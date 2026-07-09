#!/bin/bash

#==================================================
# KevinTech Multi Script
# Menú de Herramientas
#==================================================

BASE="/etc/kevintech"

clear

CYAN="\e[1;96m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
YELLOW="\e[1;93m"
GREEN="\e[1;92m"
WHITE="\e[1;97m"
RESET="\e[0m"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}          🛠 KevinTech Herramientas 🛠${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

printf "${GREEN} [01]${WHITE} ➮ Block Torrent\n"
printf "${GREEN} [02]${WHITE} ➮ Archivo Online\n"
printf "${GREEN} [03]${WHITE} ➮ Speedtest\n"
printf "${GREEN} [04]${WHITE} ➮ Detalles VPS\n"
printf "${GREEN} [05]${WHITE} ➮ Block Ads\n"
printf "${GREEN} [06]${WHITE} ➮ Cambiar contraseña Root\n"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW} [00]${WHITE} ➮ Regresar${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
read -rp " ► Opción: " OP

case "$OP" in

1)
    bash "$BASE/herramientas/blocktorrent.sh"
;;

2)
    bash "$BASE/herramientas/archivoonline.sh"
;;

3)
    bash "$BASE/herramientas/speedtest.sh"
;;

4)
    bash "$BASE/herramientas/detalles.sh"
;;

5)
    bash "$BASE/herramientas/blockads.sh"
;;

6)
    bash "$BASE/herramientas/rootpass.sh"
;;

0)
    exec bash "$BASE/protocolos/menu.sh"
;;

*)
    echo "❌ Opción inválida."
    sleep 2
    exec bash "$BASE/herramientas/menu.sh"
;;

esac
