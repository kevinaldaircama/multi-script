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
echo -e "${CYAN}║${RED}              🗑 ELIMINAR USUARIOS SSH              ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

#==================================================
# SOLO USUARIOS SSH REALES
#==================================================
#
# UID >= 1000
# No root
# No nobody
# No cuentas del sistema
# Shell válido para iniciar sesión
#
USERS=$(awk -F: '
$3 >= 1000 &&
$1 != "nobody" &&
$1 != "root" &&
($7 == "/bin/bash" ||
 $7 == "/bin/sh" ||
 $7 == "/bin/zsh" ||
 $7 == "/usr/bin/bash" ||
 $7 == "/usr/bin/zsh" ||
 $7 == "/usr/bin/fish")
{
    print $1
}' /etc/passwd)

if [[ -z "$USERS" ]]; then
    echo -e "${YELLOW}No existen usuarios SSH para eliminar.${RESET}"
    echo
    read -n1 -s -r -p "Presione una tecla para salir..."
    exit
fi

echo -e "${WHITE}👥 USUARIOS SSH DISPONIBLES:${RESET}"
echo

i=1
declare -a LISTA

while read -r user; do

    [[ -z "$user" ]] && continue

    FECHA=$(chage -l "$user" 2>/dev/null |
        grep "Account expires" |
        cut -d: -f2)

    [[ -z "$FECHA" ]] && FECHA="Nunca"

    printf "${GREEN}[%02d]${WHITE} %-18s ${GRAY}%s${RESET}\n" \
        "$i" "$user" "$FECHA"

    LISTA[$i]="$user"

    ((i++))

done <<< "$USERS"

echo
echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
echo -e "${YELLOW}Opciones:${RESET}"
echo
echo -e " ${WHITE}1${RESET}        → Elimina un usuario"
echo -e " ${WHITE}1 3 5${RESET}  → Elimina varios usuarios"
echo -e " ${RED}ALL${RESET}      → Elimina TODOS los usuarios"
echo -e " ${WHITE}0${RESET}        → Salir"
echo

read -rp "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

#==================================================
# SALIR
#==================================================

[[ "$OP" == "0" ]] && exit

#==================================================
# ELIMINAR TODOS
# SIN PREGUNTAR
#==================================================

if [[ "$OP" =~ ^([Aa][Ll][Ll]|[Tt][Oo][Dd][Oo][Ss])$ ]]; then

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RED}           💥 ELIMINAR TODOS LOS USUARIOS           ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo

    BORRADOS=0

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        echo -e "${YELLOW}🗑 Eliminando:${RESET} ${WHITE}$USER${RESET}"

        pkill -KILL -u "$USER" &>/dev/null
        userdel -r -f "$USER" &>/dev/null

        if ! id "$USER" &>/dev/null; then
            echo -e "${GREEN}✔ Eliminado${RESET}"
            ((BORRADOS++))
        else
            echo -e "${RED}✘ No se pudo eliminar${RESET}"
        fi

    done <<< "$USERS"

    echo
    echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
    echo -e "${GREEN}✔ $BORRADOS usuario(s) eliminado(s).${RESET}"
    echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"

    echo
    read -n1 -s -r -p "Presione una tecla para continuar..."

    continue
fi

#==================================================
# ELIMINAR UNO O VARIOS
# SIN PREGUNTAR
#==================================================

echo
echo -e "${RED}🗑 Se eliminarán:${RESET}"

VALIDO=0

for N in $OP; do

    if [[ -n "${LISTA[$N]}" ]]; then

        echo -e " ${WHITE}• ${LISTA[$N]}${RESET}"

        VALIDO=1
    fi

done

if [[ $VALIDO -eq 0 ]]; then

    echo
    echo -e "${RED}✘ Selección inválida.${RESET}"

    sleep 2
    continue
fi

echo
echo -e "${YELLOW}⚡ Eliminando automáticamente...${RESET}"
echo

BORRADOS=0
FALLIDOS=0

for N in $OP; do

    USER="${LISTA[$N]}"

    [[ -z "$USER" ]] && continue

    # Protección adicional
    case "$USER" in
        root|nobody|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|_apt|systemd-*|messagebus)
            echo -e "${RED}✘ Usuario protegido: $USER${RESET}"
            ((FALLIDOS++))
            continue
            ;;
    esac

    # Cerrar sesiones
    pkill -KILL -u "$USER" &>/dev/null

    # Eliminar usuario + HOME
    userdel -r -f "$USER" &>/dev/null

    if ! id "$USER" &>/dev/null; then

        echo -e "${GREEN}✔ $USER eliminado${RESET}"
        ((BORRADOS++))

    else

        echo -e "${RED}✘ $USER no pudo eliminarse${RESET}"
        ((FALLIDOS++))

    fi

done

echo
echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
echo -e "${GREEN}✔ Eliminados : $BORRADOS${RESET}"
echo -e "${RED}✘ Fallidos   : $FALLIDOS${RESET}"
echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"

echo
read -n1 -s -r -p "Presione una tecla para continuar..."

done