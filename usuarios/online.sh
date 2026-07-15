#!/bin/bash  
#==================================================  
# KevinTech Multi Script  
# Usuarios SSH Online  
# Compatible:  
# OpenSSH  
# HTTP Injector  
# HTTP Custom  
# TLS Tunnel  
# Dropbear  
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
  
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"  
echo -e "${CYAN}║${MAGENTA}            👁 USUARIOS SSH ONLINE 👁             ${CYAN}║${RESET}"  
echo -e "${CYAN}╠════╦════════════════════╦══════════╦══════════╦════════════╣${RESET}"  
  
printf "${CYAN}║${WHITE} %-2s ${CYAN}║ ${WHITE}%-18s ${CYAN}║ ${WHITE}%-8s ${CYAN}║ ${WHITE}%-8s ${CYAN}║ ${WHITE}%-10s${CYAN}║${RESET}\n" \  
"N°" "USUARIO" "ONLINE" "LÍMITE" "EXPIRA"  
  
echo -e "${CYAN}╠════╬════════════════════╬══════════╬══════════╬════════════╣${RESET}"  
  
TOTAL_USERS=0  
TOTAL_CONN=0  
  
declare -A ONLINE  
declare -A LIMIT  
declare -A EXPIRE  
#==================================================  
# DETECTAR USUARIOS SSH CONECTADOS  
#==================================================  
  
while read -r USER; do  
  
    [[ -z "$USER" ]] && continue  
  
    case "$USER" in  
        root|unknown|"[accepted]"|"[net]"|"listener")  
            continue  
        ;;  
    esac  
  
    ((ONLINE["$USER"]++))  
    ((TOTAL_CONN++))  
  
done < <(  
  
ps -ef | awk '  
  
/sshd:/ {  
  
    if ($8=="sshd:") {  
  
        USER=$9  
  
        gsub("\\[priv\\]","",USER)  
        gsub("@pts/.*","",USER)  
  
        if(USER!="root" &&  
           USER!="unknown" &&  
           USER!="[accepted]" &&  
           USER!="[net]" &&  
           USER!=""){  
  
            print USER  
  
        }  
  
    }  
  
}  
  
' | sort  
  
)  
#==================================================  
# OBTENER LÍMITE Y FECHA DE EXPIRACIÓN  
#==================================================  
  
for USER in $(printf "%s\n" "${!ONLINE[@]}" | sort); do  
  
    ((TOTAL_USERS++))  
  
    #-----------------------------  
    # LÍMITE DE CONEXIONES  
    #-----------------------------  
    MAX=$(awk -v u="$USER" '  
        $1==u && $2=="hard" && $3=="maxlogins" {  
            print $4  
            exit  
        }  
    ' /etc/security/limits.conf 2>/dev/null)  
  
    [[ -z "$MAX" ]] && MAX="∞"  
  
    LIMIT["$USER"]="$MAX"  
  
    #-----------------------------  
    # FECHA DE EXPIRACIÓN  
    #-----------------------------  
    EXP=$(chage -l "$USER" 2>/dev/null | awk -F': ' '/Account expires/ {print $2}')  
  
    case "$EXP" in  
        ""|"never"|"Never"|"Nunca")  
            EXP="Nunca"  
        ;;  
    esac  
  
    EXPIRE["$USER"]="$EXP"  
  
done  
#==================================================  
# MOSTRAR TABLA  
#==================================================  
  
NUM=1  
  
for USER in $(printf "%s\n" "${!ONLINE[@]}" | sort); do  
  
    printf "${CYAN}║${WHITE} %02d ${CYAN}║ ${GREEN}%-18s ${CYAN}║ ${YELLOW}%8s ${CYAN}║ ${BLUE}%8s ${CYAN}║ ${WHITE}%-10s${CYAN}║${RESET}\n" \  
        "$NUM" \  
        "$USER" \  
        "${ONLINE[$USER]}" \  
        "${LIMIT[$USER]}" \  
        "${EXPIRE[$USER]}"  
  
    ((NUM++))  
  
done  
  
#==================================================  
# SI NO HAY USUARIOS  
#==================================================  
  
if [[ $TOTAL_USERS -eq 0 ]]; then  
  
    echo -e "${CYAN}║${RED}             No hay usuarios conectados.              ${CYAN}║${RESET}"  
  
fi  
  
#==================================================  
# PIE  
#==================================================  
  
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"  
echo -e "${WHITE} Usuarios Online    : ${GREEN}$TOTAL_USERS${RESET}"  
echo -e "${WHITE} Conexiones Activas : ${GREEN}$TOTAL_CONN${RESET}"  
echo -e "${WHITE} Actualizado        : ${GREEN}$(date '+%d/%m/%Y %H:%M:%S')${RESET}"  
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"  
  
echo  
read -n1 -s -r -p "Presione cualquier tecla para regresar..."  
