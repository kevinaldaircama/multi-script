#!/bin/bash
#==================================================
# KevinTech Multi Script
# Crear Usuario SSH
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

clear

while true; do

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}             👤 CREAR USUARIO SSH 👤              ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

read -rp "$(echo -e "${GREEN}➤ Usuario:${RESET} ")" USER

if [[ -z "$USER" ]]; then
    echo -e "\n${RED}Debe ingresar un usuario.${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo -e "\n${RED}El usuario ya existe.${RESET}"
    sleep 2
    continue
fi

read -rsp "$(echo -e "${GREEN}➤ Contraseña:${RESET} ")" PASS
echo

if [[ -z "$PASS" ]]; then
    echo -e "\n${RED}Debe ingresar una contraseña.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}➤ Días de duración:${RESET} ")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

useradd -e "$FECHA" -M -s /bin/false "$USER"

echo "$USER:$PASS" | chpasswd

clear

IP=$(curl -4 -s ifconfig.me 2>/dev/null)

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${GREEN}          ✅ USUARIO CREADO CORRECTAMENTE          ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

echo -e "${WHITE} Usuario     : ${GREEN}$USER"
echo -e "${WHITE} Contraseña  : ${GREEN}$PASS"
echo -e "${WHITE} Expira      : ${GREEN}$FECHA"
echo -e "${WHITE} IP Servidor : ${GREEN}$IP"
echo -e "${WHITE} SSH         : ${GREEN}22"
echo -e "${WHITE} Dropbear    : ${GREEN}80,443"

echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"
echo -e "${YELLOW} Usuario creado exitosamente.${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo
read -rp "¿Crear otro usuario? [S/N]: " RESP

case "$RESP" in
s|S|si|SI|Sí|sí)
continue
;;
*)
break
;;
esac

done
