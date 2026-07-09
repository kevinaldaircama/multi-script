#!/bin/bash
#==================================================
# KevinTech Multi Script
# Editar / Renovar Usuario SSH
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

while true; do

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${YELLOW}           ♻ EDITAR / RENOVAR USUARIO SSH          ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

USERS=$(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)

if [[ -z "$USERS" ]]; then
    echo -e "${RED}No existen usuarios SSH.${RESET}"
    sleep 2
    exit
fi

i=1
declare -a LISTA

while read -r USER; do
    FECHA=$(chage -l "$USER" | grep "Account expires" | cut -d: -f2)
    printf "${GREEN}[%02d]${WHITE} %-18s ${GRAY}%s${RESET}\n" "$i" "$USER" "$FECHA"
    LISTA[$i]="$USER"
    ((i++))
done <<< "$USERS"

echo
read -rp "$(echo -e "${GREEN}Seleccione un usuario [0=Salir]: ${RESET}")" NUM

[[ "$NUM" == "0" ]] && exit

USER="${LISTA[$NUM]}"

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}Usuario inválido.${RESET}"
    sleep 2
    continue
fi

while true; do

clear

FECHA=$(chage -l "$USER" | grep "Account expires" | cut -d: -f2)

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}             👤 Usuario: ${WHITE}$USER${CYAN}                  ║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
echo -e "${WHITE} Expira: ${GREEN}$FECHA${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

echo -e "${GREEN}[1]${WHITE} Cambiar contraseña"
echo -e "${YELLOW}[2]${WHITE} Renovar cuenta"
echo -e "${BLUE}[3]${WHITE} Cambiar contraseña y renovar"
echo -e "${RED}[0]${WHITE} Volver"

echo
read -rp "$(echo -e "${GREEN}Opción: ${RESET}")" OP

case "$OP" in

1)

read -rsp "$(echo -e "${GREEN}Nueva contraseña: ${RESET}")" PASS
echo

[[ -z "$PASS" ]] && {
echo -e "${RED}Contraseña vacía.${RESET}"
sleep 2
continue
}

echo "$USER:$PASS" | chpasswd

echo
echo -e "${GREEN}✔ Contraseña actualizada.${RESET}"
sleep 2
;;

2)

read -rp "$(echo -e "${GREEN}Días a renovar: ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

chage -E "$FECHA" "$USER"

echo
echo -e "${GREEN}✔ Cuenta renovada hasta:${WHITE} $FECHA${RESET}"
sleep 2
;;

3)

read -rsp "$(echo -e "${GREEN}Nueva contraseña: ${RESET}")" PASS
echo

read -rp "$(echo -e "${GREEN}Días a renovar: ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

echo "$USER:$PASS" | chpasswd
chage -E "$FECHA" "$USER"

echo
echo -e "${GREEN}✔ Usuario actualizado correctamente.${RESET}"
echo -e "${WHITE} Usuario : ${GREEN}$USER"
echo -e "${WHITE} Expira  : ${GREEN}$FECHA"
sleep 3
;;

0)
break
;;

*)
echo
echo -e "${RED}Opción inválida.${RESET}"
sleep 2
;;

esac

done

break

done
