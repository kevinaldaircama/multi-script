#!/bin/bash
#==================================================
# KevinTech Multi Script
# Usuarios SSH Online (Resumen)
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

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}           👁 USUARIOS SSH CONECTADOS 👁           ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════════════╦═════════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-26s ${CYAN}║ ${WHITE}%-15s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "CONECTADOS"

echo -e "${CYAN}╠════╬════════════════════════════╬═════════════════╣${RESET}"

TOTAL=0
declare -A USERS

#=========================================
# CONTAR CONEXIONES OPENSSH
#=========================================

while read -r USER TTY FECHA HORA RESTO; do

    [[ -z "$USER" ]] && continue

    # Ignorar root
    [[ "$USER" == "root" ]] && continue

    ((USERS["$USER"]++))

done < <(who)

#=========================================
# MOSTRAR USUARIOS
#=========================================

for USER in $(printf "%s\n" "${!USERS[@]}" | sort); do

    ((TOTAL++))

    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-26s ${CYAN}║ ${YELLOW}%-15s${CYAN}║${RESET}\n" \
    "$TOTAL" "$USER" "${USERS[$USER]}"

done
#=========================================
# SI NO HAY USUARIOS CONECTADOS
#=========================================

if [[ $TOTAL -eq 0 ]]; then

    echo -e "${CYAN}║${RED}           No hay usuarios conectados.            ${CYAN}║${RESET}"

fi

#=========================================
# PIE DE LA TABLA
#=========================================

echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"
echo -e "${WHITE} Usuarios conectados : ${GREEN}$TOTAL${RESET}"
echo -e "${WHITE} Última actualización: ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
