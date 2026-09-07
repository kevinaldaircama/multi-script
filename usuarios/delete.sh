#!/bin/bash
#=========================================================
# KevinTech Multi Script
# Gestor de Eliminación de Usuarios SSH
# Versión mejorada
#=========================================================

# Colores
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
BOLD="\e[1m"
RESET="\e[0m"

#=========================================================
# VERIFICAR ROOT
#=========================================================

if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║                 ACCESO DENEGADO                     ║${RESET}"
    echo -e "${RED}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}║ Este script debe ejecutarse como ROOT.              ║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${RESET}"
    exit 1
fi

#=========================================================
# OBTENER USUARIOS SSH
#=========================================================

obtener_usuarios() {

    awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" &&
        $1 != "ubuntu" &&
        $1 != "debian" &&
        $1 != "admin"
        {
            print $1
        }
    ' /etc/passwd
}

#=========================================================
# BARRA SUPERIOR
#=========================================================

banner() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          ⚡ KEVINTECH MULTI SCRIPT ⚡             ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}             GESTOR DE USUARIOS SSH                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo
}

#=========================================================
# MOSTRAR USUARIOS
#=========================================================

mostrar_usuarios() {

    USERS=$(obtener_usuarios)

    if [[ -z "$USERS" ]]; then

        echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${RESET}"
        echo -e "${YELLOW}║${WHITE}        No existen usuarios SSH disponibles.         ${YELLOW}║${RESET}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${RESET}"
        echo
        read -n1 -s -r -p "$(echo -e "${GRAY}Presione una tecla para continuar...${RESET}")"
        return 1
    fi

    echo -e "${BLUE}┌────┬────────────────────┬───────────────────────────┐${RESET}"
    echo -e "${BLUE}│${WHITE} Nº ${BLUE}│${WHITE} USUARIO            ${BLUE}│${WHITE} EXPIRACIÓN                ${BLUE}│${RESET}"
    echo -e "${BLUE}├────┼────────────────────┼───────────────────────────┤${RESET}"

    i=1
    unset LISTA
    declare -g -a LISTA

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        FECHA=$(chage -l "$USER" 2>/dev/null |
                awk -F: '/Account expires/ {gsub(/^[ \t]+/,"",$2); print $2}')

        [[ -z "$FECHA" ]] && FECHA="Nunca"

        printf "${BLUE}│${GREEN} %02d ${BLUE}│${WHITE} %-18s ${BLUE}│${GRAY} %-25s ${BLUE}│${RESET}\n" \
            "$i" "$USER" "$FECHA"

        LISTA[$i]="$USER"

        ((i++))

    done <<< "$USERS"

    echo -e "${BLUE}└────┴────────────────────┴───────────────────────────┘${RESET}"
    echo

    TOTAL=$((i-1))

    echo -e "${GRAY}Total de usuarios: ${WHITE}${TOTAL}${RESET}"
    echo

    return 0
}

#=========================================================
# ELIMINAR USUARIO
#=========================================================

eliminar_usuario() {

    local USER="$1"

    [[ -z "$USER" ]] && return 1

    # Protección adicional
    case "$USER" in
        root|nobody|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|systemd-network|systemd-timesync|messagebus|syslog|_apt)
            echo -e "${RED}✘ Usuario protegido: ${WHITE}${USER}${RESET}"
            return 1
            ;;
    esac

    if ! id "$USER" &>/dev/null; then
        echo -e "${YELLOW}⚠ El usuario ${WHITE}${USER}${YELLOW} ya no existe.${RESET}"
        return 1
    fi

    # Cerrar todas las sesiones
    pkill -KILL -u "$USER" 2>/dev/null

    # Eliminar usuario y su HOME
    if userdel -r -f "$USER" &>/dev/null; then
        return 0
    fi

    # Segundo intento
    userdel -f "$USER" &>/dev/null

    if ! id "$USER" &>/dev/null; then
        return 0
    fi

    return 1
}

#=========================================================
# ELIMINAR SELECCIONADOS
#=========================================================

eliminar_seleccionados() {

    local OPCION="$1"

    local BORRADOS=0
    local FALLIDOS=0

    echo
    echo -e "${CYAN}╭──────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${WHITE}                 ELIMINANDO USUARIOS                 ${CYAN}│${RESET}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────╯${RESET}"
    echo

    for N in $OPCION; do

        USER="${LISTA[$N]}"

        [[ -z "$USER" ]] && continue

        echo -ne "${GRAY}• Eliminando ${WHITE}${USER}${GRAY} ... ${RESET}"

        if eliminar_usuario "$USER"; then
            echo -e "${GREEN}✔ OK${RESET}"
            ((BORRADOS++))
        else
            echo -e "${RED}✘ ERROR${RESET}"
            ((FALLIDOS++))
        fi

    done

    echo
    echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
    echo -e "${GREEN}✔ Eliminados : ${WHITE}${BORRADOS}${RESET}"

    if [[ $FALLIDOS -gt 0 ]]; then
        echo -e "${RED}✘ Fallidos   : ${WHITE}${FALLIDOS}${RESET}"
    fi

    echo -e "${CYAN}──────────────────────────────────────────────────────${RESET}"
    echo

    read -n1 -s -r -p "$(echo -e "${GRAY}Presione una tecla para continuar...${RESET}")"
}

#=========================================================
# ELIMINAR TODOS
#=========================================================

eliminar_todos() {

    USERS=$(obtener_usuarios)

    if [[ -z "$USERS" ]]; then
        echo
        echo -e "${YELLOW}No existen usuarios SSH para eliminar.${RESET}"
        sleep 2
        return
    fi

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}              💥 ELIMINACIÓN TOTAL 💥               ${RED}║${RESET}"
    echo -e "${RED}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${RED}║${WHITE} Se eliminarán TODOS los usuarios SSH disponibles.   ${RED}║${RESET}"
    echo -e "${RED}║${YELLOW} Esta acción NO solicita confirmación.               ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${RESET}"
    echo

    BORRADOS=0
    FALLIDOS=0

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        echo -ne "${GRAY}• Eliminando ${WHITE}${USER}${GRAY} ... ${RESET}"

        if eliminar_usuario "$USER"; then
            echo -e "${GREEN}✔ OK${RESET}"
            ((BORRADOS++))
        else
            echo -e "${RED}✘ ERROR${RESET}"
            ((FALLIDOS++))
        fi

    done <<< "$USERS"

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GREEN}                 ✔ PROCESO TERMINADO                ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE} Usuarios eliminados : ${GREEN}${BORRADOS}${CYAN}                         ║${RESET}"

    if [[ $FALLIDOS -gt 0 ]]; then
        echo -e "${CYAN}║${WHITE} Usuarios con error  : ${RED}${FALLIDOS}${CYAN}                         ║${RESET}"
    fi

    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo

    read -n1 -s -r -p "$(echo -e "${GRAY}Presione una tecla para continuar...${RESET}")"
}

#=========================================================
# MENÚ PRINCIPAL
#=========================================================

while true; do

    banner

    if ! mostrar_usuarios; then
        exit 0
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                     OPCIONES                        ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║ ${GREEN}[1]${WHITE} Eliminar un usuario                            ${CYAN}║${RESET}"
    echo -e "${CYAN}║ ${GREEN}[2]${WHITE} Eliminar varios usuarios                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║ ${RED}[3]${WHITE} 💥 Eliminar TODOS los usuarios                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║ ${YELLOW}[0]${WHITE} Salir                                          ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción: ${RESET}")" OPCION

    case "$OPCION" in

        1)

            echo
            read -rp "$(echo -e "${GREEN}Número del usuario: ${RESET}")" NUM

            USER="${LISTA[$NUM]}"

            if [[ -z "$USER" ]]; then
                echo
                echo -e "${RED}✘ Número inválido.${RESET}"
                sleep 2
                continue
            fi

            echo
            echo -ne "${GRAY}• Eliminando ${WHITE}${USER}${GRAY} ... ${RESET}"

            if eliminar_usuario "$USER"; then
                echo -e "${GREEN}✔ ELIMINADO${RESET}"
            else
                echo -e "${RED}✘ ERROR${RESET}"
            fi

            sleep 2
            ;;

        2)

            echo
            echo -e "${GRAY}Ejemplo: ${WHITE}1 3 5${RESET}"
            read -rp "$(echo -e "${GREEN}Números: ${RESET}")" SELECCION

            VALIDO=0

            for N in $SELECCION; do

                if [[ -n "${LISTA[$N]}" ]]; then
                    VALIDO=1
                fi

            done

            if [[ $VALIDO -eq 0 ]]; then
                echo
                echo -e "${RED}✘ Selección inválida.${RESET}"
                sleep 2
                continue
            fi

            eliminar_seleccionados "$SELECCION"
            ;;

        3)

            # SIN CONFIRMACIÓN
            eliminar_todos
            ;;

        0)
            clear
            echo -e "${GREEN}✔ Saliendo de KevinTech...${RESET}"
            sleep 1
            exit 0
            ;;

        *)

            echo
            echo -e "${RED}✘ Opción inválida.${RESET}"
            sleep 2
            ;;

    esac

done