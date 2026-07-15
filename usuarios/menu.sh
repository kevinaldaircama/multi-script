#!/bin/bash

BASE="/etc/kevintech"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

while true; do
clear

RAM=$(free -h | awk '/Mem:/ {print $7}')
CPU=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); printf("%.0f%%",100-a[length(a)])}')

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                 🛡️ KevinTech Multi Script 🛡️                ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${WHITE}               🔐 PANEL DE ADMINISTRACIÓN SSH               ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${WHITE} 💾 RAM Libre : ${GREEN}%-10s${WHITE} ⚡ CPU : ${GREEN}%-5s${CYAN}║${RESET}\n" "$RAM" "$CPU"

echo -e "${GREEN}  [01]${WHITE} 👤 Crear Usuario SSH"
echo -e "${GREEN}  [02]${WHITE} 🗑 Eliminar Usuario"
echo -e "${GREEN}  [03]${WHITE} ♻ Renovar / Editar Usuario"
echo -e "${GREEN}  [04]${WHITE} 📋 Lista de Usuarios"
echo -e "${GREEN}  [05]${WHITE} 🌐 Usuarios Conectados"
echo -e "${GREEN}  [06]${WHITE} 📢 Banner SSH / Dropbear"
echo -e "${GREEN}  [07]${WHITE} 🔒 Bloquear / Desbloquear"
echo -e "${GREEN}  [08]${WHITE} 💾 Backup de Usuarios"

echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${YELLOW} Kevin Tech Tutorials ${WHITE}•${MAGENTA} Privanox VPN ${WHITE}• ${GREEN}v1.0 ${CYAN}          ║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${RED}  [00]${WHITE} ⬅ Volver al Menú Principal"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo
read -rp "$(echo -e "${GREEN}➜ Seleccione una opción: ${RESET}")" op

case "$op" in
1) bash "$BASE/usuarios/add.sh" ;;
2) bash "$BASE/usuarios/delete.sh" ;;
3) bash "$BASE/usuarios/edit.sh" ;;
4) bash "$BASE/usuarios/list.sh" ;;
5) bash "$BASE/usuarios/online.sh" ;;
6) bash "$BASE/usuarios/banner.sh" ;;
7) bash "$BASE/usuarios/block.sh" ;;
8) bash "$BASE/usuarios/backup.sh" ;;
0) exec bash "$BASE/menu.sh" ;;
*)
    echo
    echo -e "${RED}✘ Opción inválida.${RESET}"
    sleep 2
;;
esac

done
