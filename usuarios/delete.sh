#!/bin/bash
#==================================================
# KevinTech Multi Script
# Eliminar Usuarios SSH
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
echo -e "${CYAN}║${RED}             🗑 ELIMINAR USUARIOS SSH              ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

USERS=$(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd)

if [[ -z "$USERS" ]]; then
    echo -e "${YELLOW}No existen usuarios SSH para eliminar.${RESET}"
    echo
    read -n1 -s -r -p "Presione una tecla para salir..."
    exit
fi

echo -e "${WHITE}Usuarios disponibles:${RESET}"
echo

i=1
declare -a LISTA

while read -r user; do
    FECHA=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
    printf "${GREEN}[%02d]${WHITE} %-18s ${GRAY}%s${RESET}\n" "$i" "$user" "$FECHA"
    LISTA[$i]="$user"
    ((i++))
done <<< "$USERS"

echo
echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
echo -e "${YELLOW}Ejemplos:${RESET}"
echo -e " ${WHITE}1${RESET}        -> Elimina un usuario"
echo -e " ${WHITE}1 3 5${RESET}    -> Elimina varios usuarios"
echo -e " ${WHITE}0${RESET}        -> Cancelar"
echo
read -rp "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

[[ "$OP" == "0" ]] && exit

echo
echo -e "${RED}Se eliminarán:${RESET}"

VALIDO=0

for N in $OP; do
    if [[ -n "${LISTA[$N]}" ]]; then
        echo -e " ${WHITE}• ${LISTA[$N]}"
        VALIDO=1
    fi
done

[[ $VALIDO -eq 0 ]] && {
    echo
    echo -e "${RED}Selección inválida.${RESET}"
    sleep 2
    continue
}

echo
read -rp "$(echo -e "${YELLOW}¿Confirma? [S/N]: ${RESET}")" RESP

case "$RESP" in
s|S|si|SI|Sí|sí)

BORRADOS=0

for N in $OP; do
    USER="${LISTA[$N]}"

    if [[ -n "$USER" ]]; then
        pkill -u "$USER" &>/dev/null
        userdel -f "$USER" &>/dev/null
        ((BORRADOS++))
    fi
done

echo
echo -e "${GREEN}✔ $BORRADOS usuario(s) eliminado(s).${RESET}"
sleep 2
;;

*)
echo
echo -e "${YELLOW}Operación cancelada.${RESET}"
sleep 2
;;
esac

break

done
