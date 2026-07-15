#!/bin/bash
#==================================================
# KevinTech Multi Script
# Monitor de Usuarios SSH Online
# Compatible con:
# OpenSSH • HTTP Injector • HTTP Custom
# TLS Tunnel • WebSocket • Dropbear
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

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

clear

#==============================
# CABECERA
#==============================

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}            👁 USUARIOS SSH CONECTADOS 👁              ${CYAN}║${RESET}"
echo -e "${CYAN}╠════╦════════════════════╦══════════╦══════════╦════════════╣${RESET}"

printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-8s ${CYAN}║ ${WHITE}%-8s ${CYAN}║ ${WHITE}%-10s${CYAN}║${RESET}\n" \
"N°" "USUARIO" "ONLINE" "LÍMITE" "EXPIRA"

echo -e "${CYAN}╠════╬════════════════════╬══════════╬══════════╬════════════╣${RESET}"

TOTAL_USERS=0
TOTAL_CONN=0

declare -A ONLINE
declare -A LIMIT
declare -A EXPIRE
#=========================================
# DETECTAR USUARIOS SSH CONECTADOS
# Compatible con HTTP Injector / Custom
#=========================================

while read -r PID USER; do

    # Ignorar procesos vacíos
    [[ -z "$PID" ]] && continue
    [[ -z "$USER" ]] && continue

    # Ignorar root
    [[ "$USER" == "root" ]] && continue

    # Sumar conexión
    ((ONLINE["$USER"]++))
    ((TOTAL_CONN++))

done < <(

ps -eo pid,user,cmd | awk '
/sshd:/ {

    if ($2 != "root") {

        print $1, $2

    }

}
'

)
#=========================================
# OBTENER LÍMITE Y FECHA DE EXPIRACIÓN
#=========================================

for USER in "${!ONLINE[@]}"; do

    ((TOTAL_USERS++))

    #-----------------------------
    # Límite de conexiones
    #-----------------------------
    MAX=$(grep "^$USER[[:space:]]" /etc/security/limits.conf 2>/dev/null | \
          awk '/maxlogins/ {print $4}' | head -1)

    [[ -z "$MAX" ]] && MAX="∞"

    LIMIT["$USER"]="$MAX"

    #-----------------------------
    # Fecha de expiración
    #-----------------------------
    EXP=$(chage -l "$USER" 2>/dev/null | \
          awk -F': ' '/Account expires/ {print $2}')

    if [[ -z "$EXP" || "$EXP" == "never" || "$EXP" == "Nunca" ]]; then
        EXP="Nunca"
    fi

    EXPIRE["$USER"]="$EXP"

done
