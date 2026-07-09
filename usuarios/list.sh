#!/bin/bash
#==================================================
# KevinTech Multi Script
# Lista de Usuarios SSH
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

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                      📋 USUARIOS REGISTRADOS SSH 📋                      ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦══════════════════╦══════════════╦════════╦══════════════════════════╣${RESET}"
printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-16s ${CYAN}║ ${WHITE}%-12s ${CYAN}║ ${WHITE}%-6s ${CYAN}║ ${WHITE}%-24s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "EXPIRA" "DÍAS" "ESTADO"
echo -e "${CYAN}╠════╬══════════════════╬══════════════╬════════╬══════════════════════════╣${RESET}"

TOTAL=0
ACTIVOS=0
EXPIRADOS=0

for USER in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd); do

EXPIRA=$(chage -l "$USER" | awk -F': ' '/Account expires/{print $2}')

if [[ "$EXPIRA" == "never" ]]; then
    FECHA="Nunca"
    DIAS="∞"
    ESTADO="${GREEN}Activo${RESET}"
    ((ACTIVOS++))
else
    FECHA=$(date -d "$EXPIRA" +%Y-%m-%d 2>/dev/null)

    HOY=$(date +%s)
    FIN=$(date -d "$FECHA" +%s)

    REST=$(( (FIN - HOY) / 86400 ))

    if [[ $REST -lt 0 ]]; then
        DIAS="0"
        ESTADO="${RED}Expirado${RESET}"
        ((EXPIRADOS++))
    else
        DIAS="$REST"
        ESTADO="${GREEN}Activo${RESET}"
        ((ACTIVOS++))
    fi
fi

((TOTAL++))

printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${WHITE}%-16s ${CYAN}║ ${WHITE}%-12s ${CYAN}║ ${WHITE}%-6s ${CYAN}║ %-33b${CYAN}║${RESET}\n" \
"$TOTAL" "$USER" "$FECHA" "$DIAS" "$ESTADO"

done

echo -e "${CYAN}╠════╩══════════════════╩══════════════╩════════╩══════════════════════════╣${RESET}"
echo -e "${WHITE} Total Usuarios : ${GREEN}$TOTAL"
echo -e "${WHITE} Activos        : ${GREEN}$ACTIVOS"
echo -e "${WHITE} Expirados      : ${RED}$EXPIRADOS"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════╝${RESET}"

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
