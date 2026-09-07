#!/bin/bash
#==================================================
# KevinTech Multi Script
# Gestor de Eliminación de Usuarios SSH
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

#──────────────────────────────────────────────────
# FUNCIONES
#──────────────────────────────────────────────────

pause() {
    echo
    read -n1 -s -r -p "$(echo -e "${GRAY}Presiona cualquier tecla para continuar...${RESET}")"
}

banner() {
    clear

    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo -e "║        ${RED}🗑  KEVINTECH • ELIMINADOR SSH${CYAN}              ║"
    echo "║                                                          ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo -e "║  ${WHITE}Gestión rápida de cuentas SSH${CYAN}                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Obtener usuarios normales
obtener_usuarios() {
    mapfile -t USUARIOS < <(
        awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" &&
        $1 != "nogroup" &&
        $1 != "ubuntu" &&
        $1 != "debian" &&
        $1 != "adm" &&
        $1 != "www-data"
        {
            print $1
        }' /etc/passwd
    )
}

#──────────────────────────────────────────────────
# PROGRAMA
#──────────────────────────────────────────────────

while true; do

    banner
    obtener_usuarios

    TOTAL=${#USUARIOS[@]}

    if [[ $TOTAL -eq 0 ]]; then
        echo
        echo -e " ${YELLOW}╭──────────────────────────────────────────────╮${RESET}"
        echo -e " ${YELLOW}│${WHITE}        No hay usuarios SSH disponibles.       ${YELLOW}│${RESET}"
        echo -e " ${YELLOW}╰──────────────────────────────────────────────╯${RESET}"
        pause
        exit 0
    fi

    #──────────────────────────────────────────────
    # ESTADÍSTICAS
    #──────────────────────────────────────────────

    echo -e "${BLUE}┌──────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${BLUE}│${WHITE}  📊 USUARIOS DISPONIBLES: ${GREEN}$TOTAL${BLUE}                         │${RESET}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────┘${RESET}"
    echo

    #──────────────────────────────────────────────
    # LISTA DE USUARIOS
    #──────────────────────────────────────────────

    echo -e "${WHITE}┌──────┬──────────────────────┬────────────────────────────┐${RESET}"
    echo -e "${WHITE}│ Nº   │ Usuario              │ Expiración                 │${RESET}"
    echo -e "${WHITE}├──────┼──────────────────────┼────────────────────────────┤${RESET}"

    for ((i=0; i<TOTAL; i++)); do

        USER="${USUARIOS[$i]}"

        FECHA=$(chage -l "$USER" 2>/dev/null |
            awk -F: '/Account expires/ {
                gsub(/^[ \t]+/, "", $2);
                print $2
            }')

        [[ -z "$FECHA" ]] && FECHA="Sin información"

        printf "${WHITE}│${GREEN} %-4s ${WHITE}│ %-20s │ ${GRAY}%-26s${WHITE} │${RESET}\n" \
            "$((i+1))" "$USER" "$FECHA"

    done

    echo -e "${WHITE}└──────┴──────────────────────┴────────────────────────────┘${RESET}"

    #──────────────────────────────────────────────
    # OPCIONES
    #──────────────────────────────────────────────

    echo
    echo -e "${CYAN}╭──────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${WHITE}                    ACCIONES                             ${CYAN}│${RESET}"
    echo -e "${CYAN}├──────────────────────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}│ ${GREEN}1${WHITE}  → Eliminar un usuario                              ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${GREEN}2${WHITE}  → Eliminar varios usuarios                        ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${RED}3${WHITE}  → ELIMINAR TODOS los usuarios                     ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${GRAY}0${WHITE}  → Salir                                             ${CYAN}│${RESET}"
    echo -e "${CYAN}╰──────────────────────────────────────────────────────────╯${RESET}"

    echo
    read -rp "$(echo -e "${GREEN}➜ Seleccione una opción: ${RESET}")" OPCION

    #──────────────────────────────────────────────
    # SALIR
    #──────────────────────────────────────────────

    [[ "$OPCION" == "0" ]] && exit 0

    #──────────────────────────────────────────────
    # ELIMINAR UNO
    #──────────────────────────────────────────────

    if [[ "$OPCION" == "1" ]]; then

        echo
        read -rp "$(echo -e "${YELLOW}➜ Número del usuario: ${RESET}")" NUM

        if ! [[ "$NUM" =~ ^[0-9]+$ ]] ||
           [[ "$NUM" -lt 1 ]] ||
           [[ "$NUM" -gt "$TOTAL" ]]; then

            echo
            echo -e "${RED}✘ Número inválido.${RESET}"
            sleep 2
            continue
        fi

        USER="${USUARIOS[$((NUM-1))]}"

        echo
        echo -e "${RED}🗑 Eliminando usuario: ${WHITE}$USER${RESET}"

        pkill -u "$USER" 2>/dev/null
        userdel -f "$USER" 2>/dev/null

        if ! id "$USER" &>/dev/null; then
            echo -e "${GREEN}✔ Usuario eliminado correctamente.${RESET}"
        else
            echo -e "${RED}✘ No se pudo eliminar completamente.${RESET}"
        fi

        sleep 2
        continue
    fi

    #──────────────────────────────────────────────
    # ELIMINAR VARIOS
    #──────────────────────────────────────────────

    if [[ "$OPCION" == "2" ]]; then

        echo
        echo -e "${GRAY}Ejemplo: 1 3 5 8${RESET}"
        echo

        read -rp "$(echo -e "${YELLOW}➜ Números: ${RESET}")" SELECCION

        BORRADOS=0

        for NUM in $SELECCION; do

            if ! [[ "$NUM" =~ ^[0-9]+$ ]]; then
                continue
            fi

            if [[ "$NUM" -lt 1 || "$NUM" -gt "$TOTAL" ]]; then
                continue
            fi

            USER="${USUARIOS[$((NUM-1))]}"

            echo -e "${RED}🗑 Eliminando:${WHITE} $USER${RESET}"

            pkill -u "$USER" 2>/dev/null
            userdel -f "$USER" 2>/dev/null

            if ! id "$USER" &>/dev/null; then
                ((BORRADOS++))
            fi

        done

        echo
        echo -e "${GREEN}╭──────────────────────────────────────────────╮${RESET}"
        echo -e "${GREEN}│${WHITE} ✔ Usuarios eliminados: ${GREEN}$BORRADOS${GREEN}                │${RESET}"
        echo -e "${GREEN}╰──────────────────────────────────────────────╯${RESET}"

        sleep 2
        continue
    fi

    #──────────────────────────────────────────────
    # ELIMINAR TODOS
    # SIN CONFIRMACIÓN
    #──────────────────────────────────────────────

    if [[ "$OPCION" == "3" ]]; then

        echo
        echo -e "${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║${WHITE}             ☠ ELIMINANDO TODOS LOS USUARIOS             ${RED}║${RESET}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
        echo

        BORRADOS=0

        for USER in "${USUARIOS[@]}"; do

            echo -e "${RED}🗑 Eliminando:${WHITE} $USER${RESET}"

            pkill -u "$USER" 2>/dev/null
            userdel -f "$USER" 2>/dev/null

            if ! id "$USER" &>/dev/null; then
                ((BORRADOS++))
            fi

        done

        echo
        echo -e "${GREEN}╭──────────────────────────────────────────────────────────╮${RESET}"
        echo -e "${GREEN}│${WHITE}       ✔ LIMPIEZA COMPLETADA                            ${GREEN}│${RESET}"
        echo -e "${GREEN}│${WHITE}       Usuarios eliminados: ${GREEN}$BORRADOS${WHITE}                   ${GREEN}│${RESET}"
        echo -e "${GREEN}╰──────────────────────────────────────────────────────────╯${RESET}"

        sleep 3
        continue
    fi

    echo
    echo -e "${RED}✘ Opción inválida.${RESET}"
    sleep 2

done