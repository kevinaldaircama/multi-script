#!/bin/bash
#==================================================
# KevinTech Multi Script
# Usuarios SSH Online
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

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                 👁 USUARIOS CONECTADOS SSH 👁                  ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦══════════════════════╦═══════════════╣${RESET}"
printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-20s ${CYAN}║ ${WHITE}%-13s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "IP" "SERVICIO"
echo -e "${CYAN}╠════╬════════════════════╬══════════════════════╬═══════════════╣${RESET}"

TOTAL=0

# OpenSSH
while read -r USER IP _; do
    [[ -z "$USER" || -z "$IP" ]] && continue

    ((TOTAL++))

    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-18s ${CYAN}║ ${WHITE}%-20s ${CYAN}║ ${BLUE}%-13s${CYAN}║${RESET}\n" \
    "$TOTAL" "$USER" "$IP" "OpenSSH"

done < <(
who | while read USER TTY FECHA HORA RESTO
do
IP=$(echo "$RESTO" | tr -d '()')
echo "$USER $IP"
done
)

# Dropbear
if pgrep dropbear >/dev/null 2>&1; then

for PID in $(pgrep dropbear); do

USER=$(ps -o user= -p "$PID" 2>/dev/null)

IP=$(netstat -tnp 2>/dev/null | grep "$PID/" | awk '{print $5}' | cut -d: -f1 | head -1)

[[ -z "$USER" || "$USER" == "root" ]] && continue
[[ -z "$IP" ]] && continue

((TOTAL++))

printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-18s ${CYAN}║ ${WHITE}%-20s ${CYAN}║ ${YELLOW}%-13s${CYAN}║${RESET}\n" \
"$TOTAL" "$USER" "$IP" "Dropbear"

done

fi

if [[ $TOTAL -eq 0 ]]; then
echo -e "${CYAN}║${RED}                  No hay usuarios conectados.                   ${CYAN}║${RESET}"
fi

echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${WHITE} Total de conexiones activas: ${GREEN}$TOTAL${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${RESET}"

echo
echo -e "${GRAY}Actualizado: $(date '+%d/%m/%Y %H:%M:%S')${RESET}"
echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."
