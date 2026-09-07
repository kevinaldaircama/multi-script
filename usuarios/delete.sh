#!/bin/bash

# ============================================================
#        ⚜ KEVINTECH MULTI SCRIPT — USER MANAGER ⚜
#        Módulo: Eliminar Usuarios SSH
#        Versión: 4.0 PREMIUM
#
#        FUNCIONES:
#        • Eliminar 1 usuario
#        • Eliminar varios usuarios
#        • Eliminar todos los usuarios administrables
#        • Mostrar expiración
#        • Mostrar conexiones
#        • Cerrar sesiones antes de eliminar
#        • Limpiar límites de KevinTech
#        • Protección contra usuarios del sistema
#        • Confirmación de seguridad
# ============================================================

# ============================================================
# COLORES
# ============================================================

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
MAGENTA='\e[1;95m'
WHITE='\e[1;97m'
GRAY='\e[1;90m'
ORANGE='\e[1;38;5;208m'
RESET='\e[0m'

# ============================================================
# CONFIGURACIÓN
# ============================================================

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"

mkdir -p "$BASE"
touch "$LIMITS_FILE"

# ============================================================
# FUNCIONES VISUALES
# ============================================================

banner() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          ⚜ KEVINTECH MULTI SCRIPT ⚜                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RED}              🗑 GESTOR DE USUARIOS SSH                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${GRAY}                 PREMIUM USER MANAGER                       ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

line() {

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

pause() {

    echo
    read -rp "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"
}

ok() {

    echo -e "${GREEN}✔ $1${RESET}"
}

error() {

    echo -e "${RED}✘ $1${RESET}"
}

warn() {

    echo -e "${YELLOW}⚠ $1${RESET}"
}

info() {

    echo -e "${CYAN}➜ $1${RESET}"
}

# ============================================================
# USUARIOS PROTEGIDOS
# ============================================================

es_usuario_protegido() {

    local USERNAME="$1"

    case "$USERNAME" in

        root|sync|shutdown|halt|mail|news|uucp|man|proxy|backup|list|irc|gnats|nobody|libuuid|syslog|messagebus|usbmux|dnsmasq|avahi|polkitd|rtkit|saned|whoopsie|uuidd|tcpdump|_apt|systemd-network|systemd-resolve|systemd-timesync|systemd-coredump|systemd-oom|ubuntu)

            return 0
            ;;

    esac

    return 1
}

# ============================================================
# DETECTAR SI ES USUARIO ADMINISTRABLE
# ============================================================

es_usuario_admin() {

    local USERNAME="$1"

    [[ -z "$USERNAME" ]] && return 1

    id "$USERNAME" >/dev/null 2>&1 || return 1

    # Nunca tocar root
    [[ "$USERNAME" == "root" ]] && return 1

    # Lista de protección
    es_usuario_protegido "$USERNAME" && return 1

    local UID_USER

    UID_USER=$(id -u "$USERNAME" 2>/dev/null)

    # Usuarios normales
    if [[ "$UID_USER" =~ ^[0-9]+$ ]] &&
       (( UID_USER >= 1000 )); then

        return 0
    fi

    # Si KevinTech tiene registrado el usuario,
    # también se considera administrable.
    if grep -qE "^${USERNAME}:" "$LIMITS_FILE" 2>/dev/null; then

        return 0
    fi

    return 1
}

# ============================================================
# OBTENER USUARIOS SSH ADMINISTRABLES
# ============================================================

obtener_usuarios() {

    awk -F: '{print $1}' /etc/passwd |
    while read -r USERNAME; do

        if es_usuario_admin "$USERNAME"; then

            echo "$USERNAME"

        fi

    done
}

# ============================================================
# CONTAR CONEXIONES
# ============================================================

contar_conexiones() {

    local USERNAME="$1"

    who 2>/dev/null |
        awk -v u="$USERNAME" '$1 == u {count++} END {print count+0}'
}

# ============================================================
# OBTENER IPs
# ============================================================

obtener_ips() {

    local USERNAME="$1"

    who 2>/dev/null |
        awk -v u="$USERNAME" '
            $1 == u {
                ip=$5
                gsub(/[()]/, "", ip)

                if (ip != "")
                    print ip
            }
        ' |
        sort -u |
        paste -sd "," -
}

# ============================================================
# OBTENER EXPIRACIÓN
# ============================================================

obtener_expiracion() {

    local USERNAME="$1"

    local EXP

    EXP=$(chage -l "$USERNAME" 2>/dev/null |
        awk -F': ' '/Account expires/ {
            print $2
            exit
        }')

    [[ -z "$EXP" ]] && EXP="Ilimitada"

    case "$EXP" in

        never|Nunca)
            echo "Ilimitada"
            ;;

        *)
            echo "$EXP"
            ;;

    esac
}

# ============================================================
# CREAR LISTA
# ============================================================

crear_lista() {

    mapfile -t LISTA < <(obtener_usuarios)

    TOTAL=${#LISTA[@]}
}

# ============================================================
# MOSTRAR USUARIOS
# ============================================================

mostrar_usuarios() {

    crear_lista

    if (( TOTAL == 0 )); then

        echo
        echo -e "${YELLOW}╭──────────────────────────────────────────────────────────╮${RESET}"
        echo -e "${YELLOW}│${WHITE}          No hay usuarios SSH administrables.            ${YELLOW}│${RESET}"
        echo -e "${YELLOW}╰──────────────────────────────────────────────────────────╯${RESET}"

        return 1
    fi

    echo -e "${WHITE}USUARIOS ADMINISTRABLES${RESET}"
    echo

    printf "${GRAY}%-5s %-20s %-18s %-8s %-22s${RESET}\n" \
        "#" "USUARIO" "EXPIRACIÓN" "SESIONES" "IP"

    line

    local I=1

    for USERNAME in "${LISTA[@]}"; do

        EXP=$(obtener_expiracion "$USERNAME")
        SESIONES=$(contar_conexiones "$USERNAME")
        IPS=$(obtener_ips "$USERNAME")

        [[ -z "$IPS" ]] && IPS="-"

        if (( SESIONES > 0 )); then
            ESTADO="${GREEN}ONLINE${RESET}"
        else
            ESTADO="${GRAY}OFFLINE${RESET}"
        fi

        printf "${GREEN}[%02d]${RESET}  ${WHITE}%-18s${RESET} %-18s %-8s %-22s %b\n" \
            "$I" \
            "$USERNAME" \
            "$EXP" \
            "$SESIONES" \
            "$IPS" \
            "$ESTADO"

        MAPA[$I]="$USERNAME"

        ((I++))

    done

    echo
    line

    echo -e "${GRAY}Total de usuarios administrables: ${WHITE}${TOTAL}${RESET}"
}

# ============================================================
# CERRAR SESIONES
# ============================================================

cerrar_sesiones() {

    local USERNAME="$1"

    if pgrep -u "$USERNAME" >/dev/null 2>&1; then

        pkill -TERM -u "$USERNAME" 2>/dev/null

        sleep 1

        pkill -KILL -u "$USERNAME" 2>/dev/null

    fi
}

# ============================================================
# LIMPIAR LIMITS.CONF
# ============================================================

limpiar_limite() {

    local USERNAME="$1"

    [[ ! -f "$LIMITS_FILE" ]] && return

    sed -i \
        -E "/^${USERNAME//\//\\/}:/d" \
        "$LIMITS_FILE"

}

# ============================================================
# ELIMINAR UN USUARIO
# ============================================================

eliminar_usuario() {

    local USERNAME="$1"

    if ! es_usuario_admin "$USERNAME"; then

        error "Usuario no permitido: $USERNAME"
        return 1
    fi

    info "Cerrando sesiones de ${WHITE}${USERNAME}${RESET}..."

    cerrar_sesiones "$USERNAME"

    info "Eliminando cuenta ${WHITE}${USERNAME}${RESET}..."

    if userdel -r "$USERNAME" >/dev/null 2>&1; then

        limpiar_limite "$USERNAME"

        ok "Usuario ${WHITE}${USERNAME}${GREEN} eliminado correctamente."

        return 0

    fi

    # Si -r falla, intentar sin eliminar HOME
    if userdel -f "$USERNAME" >/dev/null 2>&1; then

        limpiar_limite "$USERNAME"

        ok "Usuario ${WHITE}${USERNAME}${GREEN} eliminado."

        return 0

    fi

    error "No se pudo eliminar: $USERNAME"

    return 1
}

# ============================================================
# CONFIRMACIÓN NORMAL
# ============================================================

confirmar() {

    local MENSAJE="$1"

    echo

    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}                       ⚠ ATENCIÓN                            ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${YELLOW}${MENSAJE}${RESET}"
    echo

    read -rp "$(echo -e "${WHITE}Escriba ${RED}SI${WHITE} para confirmar: ${RESET}")" RESP

    [[ "$RESP" == "SI" || "$RESP" == "si" || "$RESP" == "Sí" || "$RESP" == "sí" ]]

}

# ============================================================
# ELIMINAR VARIOS
# ============================================================

eliminar_seleccionados() {

    local OPCION="$1"

    local SELECCIONADOS=()
    local N USERNAME

    for N in $OPCION; do

        if [[ "$N" =~ ^[0-9]+$ ]] &&
           [[ -n "${MAPA[$N]}" ]]; then

            USERNAME="${MAPA[$N]}"

            # Evitar duplicados
            if [[ ! " ${SELECCIONADOS[*]} " =~ " ${USERNAME} " ]]; then

                SELECCIONADOS+=("$USERNAME")

            fi

        fi

    done

    if (( ${#SELECCIONADOS[@]} == 0 )); then

        error "No se seleccionaron usuarios válidos."
        return 1
    fi

    echo
    echo -e "${RED}USUARIOS QUE SERÁN ELIMINADOS:${RESET}"
    echo

    for USERNAME in "${SELECCIONADOS[@]}"; do

        echo -e " ${RED}✖${RESET} ${WHITE}${USERNAME}${RESET}"

    done

    echo

    if ! confirmar "Esta operación eliminará las cuentas seleccionadas."; then

        warn "Operación cancelada."
        return 0
    fi

    echo

    BORRADOS=0
    ERRORES=0

    for USERNAME in "${SELECCIONADOS[@]}"; do

        if eliminar_usuario "$USERNAME"; then

            ((BORRADOS++))

        else

            ((ERRORES++))

        fi

    done

    echo
    line

    echo -e "${GREEN}✔ Eliminados : ${BORRADOS}${RESET}"
    echo -e "${RED}✘ Errores    : ${ERRORES}${RESET}"

    line
}

# ============================================================
# ELIMINAR TODOS
# ============================================================

eliminar_todos() {

    crear_lista

    if (( TOTAL == 0 )); then

        warn "No existen usuarios administrables."
        return
    fi

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}              ☠ ELIMINACIÓN MASIVA ☠                       ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${YELLOW}Se eliminarán TODOS los usuarios administrables:${RESET}"
    echo

    for USERNAME in "${LISTA[@]}"; do

        echo -e " ${RED}✖${RESET} ${WHITE}${USERNAME}${RESET}"

    done

    echo

    echo -e "${GRAY}Los usuarios del sistema están protegidos.${RESET}"
    echo -e "${GRAY}root y cuentas de servicio NO serán eliminados.${RESET}"

    echo

    read -rp "$(echo -e "${RED}Escriba ${WHITE}ELIMINAR TODO${RED} para continuar: ${RESET}")" RESP

    if [[ "$RESP" != "ELIMINAR TODO" ]]; then

        warn "Operación cancelada."

        return
    fi

    echo

    BORRADOS=0
    ERRORES=0

    for USERNAME in "${LISTA[@]}"; do

        if eliminar_usuario "$USERNAME"; then

            ((BORRADOS++))

        else

            ((ERRORES++))

        fi

    done

    # Limpieza final de límites
    if [[ -f "$LIMITS_FILE" ]]; then

        : > "$LIMITS_FILE"
        chmod 600 "$LIMITS_FILE"

    fi

    echo
    line

    echo -e "${GREEN}✔ Usuarios eliminados : ${BORRADOS}${RESET}"
    echo -e "${RED}✘ Errores             : ${ERRORES}${RESET}"

    line
}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================

while true; do

    banner

    crear_lista

    echo -e "${WHITE}╭──────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${WHITE}│${CYAN}              PANEL DE CONTROL DE USUARIOS                ${WHITE}│${RESET}"
    echo -e "${WHITE}╰──────────────────────────────────────────────────────────╯${RESET}"

    echo

    echo -e " ${GREEN}[1]${RESET} 🗑  Eliminar un usuario"
    echo -e " ${GREEN}[2]${RESET} 🗑  Eliminar varios usuarios"
    echo -e " ${RED}[3]${RESET} ☠  Eliminar TODOS los usuarios"
    echo -e " ${BLUE}[4]${RESET} 👥  Actualizar lista"
    echo -e " ${YELLOW}[0]${RESET} ↩  Salir"

    echo
    line

    echo -e "${GRAY}Usuarios administrables: ${WHITE}${TOTAL}${RESET}"

    echo
    read -rp "$(echo -e "${CYAN}Seleccione una opción: ${RESET}")" OPCION

    case "$OPCION" in

        1)

            banner

            if mostrar_usuarios; then

                echo
                read -rp "$(echo -e "${GREEN}Número del usuario a eliminar: ${RESET}")" NUMERO

                USERNAME="${MAPA[$NUMERO]}"

                if [[ -z "$USERNAME" ]]; then

                    error "Número inválido."

                else

                    echo
                    echo -e "${RED}Usuario seleccionado:${RESET} ${WHITE}${USERNAME}${RESET}"

                    if confirmar "Se eliminará la cuenta ${USERNAME}."; then

                        eliminar_usuario "$USERNAME"

                    else

                        warn "Operación cancelada."

                    fi

                fi

            fi

            pause
            ;;

        2)

            banner

            if mostrar_usuarios; then

                echo
                echo -e "${YELLOW}Ejemplos:${RESET}"
                echo -e " ${WHITE}1${RESET}       → un usuario"
                echo -e " ${WHITE}1 3 5${RESET}   → varios usuarios"
                echo -e " ${WHITE}2 4 7 8${RESET} → múltiples usuarios"

                echo

                read -rp "$(echo -e "${GREEN}Seleccione números: ${RESET}")" SELECCION

                eliminar_seleccionados "$SELECCION"

            fi

            pause
            ;;

        3)

            banner

            eliminar_todos

            pause
            ;;

        4)

            info "Actualizando lista..."
            sleep 1
            ;;

        0)

            clear

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${GREEN}             ✔ KEVINTECH USER MANAGER                       ${CYAN}║${RESET}"
            echo -e "${CYAN}║${WHITE}                    Hasta luego...                           ${CYAN}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo

            exit 0
            ;;

        *)

            error "Opción inválida."
            sleep 1
            ;;

    esac

done