#!/bin/bash
#===========================================================
# KevinTech Multi Script
# Eliminador Avanzado de Usuarios SSH
# Versión: 3.0
#===========================================================

# Colores
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#-----------------------------------------------------------
# Comprobar root
#-----------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"
    exit 1
fi

#-----------------------------------------------------------
# Usuarios protegidos
#-----------------------------------------------------------
PROTEGIDOS=(
    root
    daemon
    bin
    sys
    sync
    games
    man
    lp
    mail
    news
    uucp
    proxy
    www-data
    backup
    list
    irc
    gnats
    nobody
    systemd-network
    systemd-resolve
    systemd-timesync
    messagebus
    syslog
    _apt
    tss
    uuidd
    tcpdump
    landscape
    pollinate
    sshd
)

#-----------------------------------------------------------
# Verificar si un usuario está protegido
#-----------------------------------------------------------
es_protegido() {
    local USER="$1"

    for P in "${PROTEGIDOS[@]}"; do
        [[ "$USER" == "$P" ]] && return 0
    done

    return 1
}

#-----------------------------------------------------------
# Obtener usuarios normales
#-----------------------------------------------------------
obtener_usuarios() {
    awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" &&
        $7 !~ /(nologin|false)$/ {
            print $1
        }
    ' /etc/passwd
}

#-----------------------------------------------------------
# Fecha de expiración
#-----------------------------------------------------------
obtener_expiracion() {
    local USER="$1"

    chage -l "$USER" 2>/dev/null |
        awk -F: '/Account expires/ {
            gsub(/^[ \t]+/, "", $2);
            print $2
        }'
}

#-----------------------------------------------------------
# Detectar sesiones activas
#-----------------------------------------------------------
sesiones_activas() {
    local USER="$1"

    who 2>/dev/null | awk -v u="$USER" '$1 == u {count++} END {print count+0}'
}

#-----------------------------------------------------------
# Obtener número de procesos
#-----------------------------------------------------------
procesos_usuario() {
    local USER="$1"

    pgrep -u "$USER" 2>/dev/null | wc -l
}

#-----------------------------------------------------------
# Pausa
#-----------------------------------------------------------
pausa() {
    echo
    read -n1 -s -r -p "$(echo -e "${GRAY}Presiona cualquier tecla para continuar...${RESET}")"
}

#-----------------------------------------------------------
# Eliminar usuario
#-----------------------------------------------------------
eliminar_usuario() {
    local USER="$1"

    [[ -z "$USER" ]] && return 1

    if ! id "$USER" &>/dev/null; then
        echo -e "${RED}✘ El usuario '$USER' ya no existe.${RESET}"
        return 1
    fi

    if es_protegido "$USER"; then
        echo -e "${RED}✘ Usuario protegido: $USER${RESET}"
        return 1
    fi

    echo -e "${YELLOW}→ Cerrando sesiones de: ${WHITE}$USER${RESET}"

    # Terminar procesos
    pkill -TERM -u "$USER" 2>/dev/null
    sleep 1

    # Si todavía quedan procesos, finalizar
    pkill -KILL -u "$USER" 2>/dev/null

    echo -e "${YELLOW}→ Eliminando cuenta: ${WHITE}$USER${RESET}"

    if userdel -f "$USER" 2>/dev/null; then
        echo -e "${GREEN}✔ Usuario eliminado: $USER${RESET}"
        return 0
    else
        echo -e "${RED}✘ No se pudo eliminar: $USER${RESET}"
        return 1
    fi
}

#-----------------------------------------------------------
# Menú principal
#-----------------------------------------------------------
while true; do

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RED}              🗑 KEVINTECH USER MANAGER               ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}           Eliminador Avanzado de Usuarios SSH         ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${RESET}"

    mapfile -t USERS < <(obtener_usuarios)

    # Filtrar usuarios protegidos
    LISTA=()

    for USER in "${USERS[@]}"; do
        if ! es_protegido "$USER"; then
            LISTA+=("$USER")
        fi
    done

    TOTAL=${#LISTA[@]}

    if [[ $TOTAL -eq 0 ]]; then

        echo -e "${YELLOW}║ No existen usuarios SSH disponibles para eliminar.   ${CYAN}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"

        pausa
        exit 0
    fi

    echo -e "${CYAN}║ ${WHITE}Usuarios disponibles: ${GREEN}$TOTAL${RESET}${CYAN}                              ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo

    printf "${GRAY}%-5s %-20s %-18s %-10s${RESET}\n" \
        "Nº" "USUARIO" "EXPIRACIÓN" "SESIONES"

    echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}"

    declare -A LISTA_NUM

    i=1

    for USER in "${LISTA[@]}"; do

        EXPIRA=$(obtener_expiracion "$USER")
        SESIONES=$(sesiones_activas "$USER")

        [[ -z "$EXPIRA" ]] && EXPIRA="N/A"

        if [[ "$EXPIRA" == "never" ]]; then
            EXP_COLOR="${GREEN}"
        else
            EXP_COLOR="${YELLOW}"
        fi

        if [[ "$SESIONES" -gt 0 ]]; then
            SES_COLOR="${RED}"
        else
            SES_COLOR="${GRAY}"
        fi

        printf "${GREEN}[%02d]${RESET} %-20s ${EXP_COLOR}%-18s${RESET} ${SES_COLOR}%-10s${RESET}\n" \
            "$i" "$USER" "$EXPIRA" "$SESIONES"

        LISTA_NUM[$i]="$USER"

        ((i++))
    done

    echo
    echo -e "${CYAN}──────────────────────────────────────────────────────────${RESET}"
    echo -e "${WHITE}Opciones:${RESET}"
    echo
    echo -e " ${GREEN}1${RESET}       → Eliminar un usuario"
    echo -e " ${GREEN}1 3 5${RESET}   → Eliminar varios usuarios"
    echo -e " ${RED}ALL${RESET}     → Eliminar TODOS los usuarios"
    echo -e " ${YELLOW}0${RESET}       → Salir"
    echo

    read -rp "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" OPCION

    #-------------------------------------------------------
    # Salir
    #-------------------------------------------------------
    [[ "$OPCION" == "0" ]] && exit 0

    #-------------------------------------------------------
    # ELIMINAR TODOS
    #-------------------------------------------------------
    if [[ "$OPCION" =~ ^([Aa][Ll][Ll]|[Tt][Oo][Dd][Oo][Ss])$ ]]; then

        clear

        echo -e "${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║                 ⚠ BORRADO TOTAL                         ║${RESET}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
        echo
        echo -e "${WHITE}Se encontraron ${RED}$TOTAL${WHITE} usuarios para eliminar.${RESET}"
        echo

        for USER in "${LISTA[@]}"; do
            echo -e " ${RED}•${RESET} $USER"
        done

        echo
        echo -e "${RED}⚠ ATENCIÓN: Esta operación eliminará TODAS las cuentas${RESET}"
        echo -e "${RED}   de usuario detectadas por este script.${RESET}"
        echo

        read -rp "$(echo -e "${YELLOW}Escribe ${WHITE}ELIMINAR TODO${YELLOW} para confirmar: ${RESET}")" CONFIRMAR

        if [[ "$CONFIRMAR" != "ELIMINAR TODO" ]]; then
            echo
            echo -e "${YELLOW}Operación cancelada.${RESET}"
            sleep 2
            continue
        fi

        echo
        echo -e "${CYAN}Iniciando eliminación total...${RESET}"
        echo

        ELIMINADOS=0
        ERRORES=0

        for USER in "${LISTA[@]}"; do

            if eliminar_usuario "$USER"; then
                ((ELIMINADOS++))
            else
                ((ERRORES++))
            fi

            sleep 0.3
        done

        echo
        echo -e "${CYAN}══════════════════════════════════════════════════════════${RESET}"
        echo -e "${GREEN}✔ Eliminados : $ELIMINADOS${RESET}"
        echo -e "${RED}✘ Errores    : $ERRORES${RESET}"
        echo -e "${CYAN}══════════════════════════════════════════════════════════${RESET}"

        pausa
        continue
    fi

    #-------------------------------------------------------
    # SELECCIÓN INDIVIDUAL / MÚLTIPLE
    #-------------------------------------------------------

    SELECCIONADOS=()
    INVALIDO=0

    for NUM in $OPCION; do

        # Solo números
        if ! [[ "$NUM" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}✘ Selección inválida: $NUM${RESET}"
            INVALIDO=1
            continue
        fi

        USER="${LISTA_NUM[$NUM]}"

        if [[ -z "$USER" ]]; then
            echo -e "${RED}✘ Número inválido: $NUM${RESET}"
            INVALIDO=1
            continue
        fi

        # Evitar duplicados
        YA_EXISTE=0

        for U in "${SELECCIONADOS[@]}"; do
            [[ "$U" == "$USER" ]] && YA_EXISTE=1
        done

        if [[ $YA_EXISTE -eq 0 ]]; then
            SELECCIONADOS+=("$USER")
        fi

    done

    if [[ ${#SELECCIONADOS[@]} -eq 0 ]]; then
        echo
        echo -e "${RED}✘ No seleccionaste ningún usuario válido.${RESET}"
        sleep 2
        continue
    fi

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RED}                  ⚠ CONFIRMAR ELIMINACIÓN              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Usuarios seleccionados:${RESET}"
    echo

    for USER in "${SELECCIONADOS[@]}"; do

        SESIONES=$(sesiones_activas "$USER")
        PROCESOS=$(procesos_usuario "$USER")

        if [[ "$SESIONES" -gt 0 ]]; then
            ESTADO="${RED}ACTIVO${RESET}"
        else
            ESTADO="${GREEN}INACTIVO${RESET}"
        fi

        echo -e " ${RED}•${RESET} ${WHITE}$USER${RESET} | Sesiones: $SESIONES | Procesos: $PROCESOS | $ESTADO"
    done

    echo
    echo -e "${YELLOW}⚠ Los usuarios seleccionados serán eliminados.${RESET}"
    echo

    read -rp "$(echo -e "${YELLOW}¿Confirmar? [S/N]: ${RESET}")" RESPUESTA

    case "$RESPUESTA" in

        s|S|si|SI|Si|sí|Sí)

            ELIMINADOS=0
            ERRORES=0

            echo

            for USER in "${SELECCIONADOS[@]}"; do

                if eliminar_usuario "$USER"; then
                    ((ELIMINADOS++))
                else
                    ((ERRORES++))
                fi

                sleep 0.3
            done

            echo
            echo -e "${CYAN}══════════════════════════════════════════════════════════${RESET}"
            echo -e "${GREEN}✔ Eliminados : $ELIMINADOS${RESET}"
            echo -e "${RED}✘ Errores    : $ERRORES${RESET}"
            echo -e "${CYAN}══════════════════════════════════════════════════════════${RESET}"

            ;;

        *)
            echo
            echo -e "${YELLOW}⚠ Operación cancelada.${RESET}"
            ;;
    esac

    pausa

done