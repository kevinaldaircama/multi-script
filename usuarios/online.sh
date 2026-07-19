#!/bin/bash
#==================================================
# KevinTech Multi Script
# Usuarios SSH Online v2
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}              👁 USUARIOS ONLINE 👁              ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦═══════════════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-21s${CYAN}║${RESET}\n" \
"ID" "USUARIO" "CONEXIONES"

echo -e "${CYAN}╠════╬════════════════════╬═══════════════════════╣${RESET}"

TOTAL=0
ID=1

declare -A USERS
#==================================================
# CONTAR USUARIOS SSH CONECTADOS
#==================================================

while read -r USER; do

    [[ -z "$USER" ]] && continue
    [[ "$USER" == "root" ]] && continue

    ((USERS["$USER"]++))

done < <(

ps -C sshd -o args= | \
grep "\[priv\]" | \
awk -F'sshd: ' '{print $2}' | \
awk '{print $1}'

)
#==================================================
# MOSTRAR USUARIOS
#==================================================

for USER in $(printf "%s\n" "${!USERS[@]}" | sort); do

    CONN=${USERS[$USER]}

    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-18s ${CYAN}║ ${YELLOW}%-21s${CYAN}║${RESET}\n" \
    "$ID" "$USER" "$CONN"

    ((TOTAL++))
    ((ID++))

done

if [[ $TOTAL -eq 0 ]]; then

    echo -e "${CYAN}║${RED} No hay usuarios conectados.                  ${CYAN}║${RESET}"

fi

echo -e "${CYAN}╠════╩════════════════════╩═══════════════════════╣${RESET}"
echo -e "${WHITE} Usuarios Online : ${GREEN}$TOTAL${RESET}"
echo -e "${WHITE} Actualizado     : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
