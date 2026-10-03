#!/usr/bin/env bash

# ==============================================================
#                 🛡️ KEVINTECH MULTI SCRIPT
#                    HWID MANAGEMENT PANEL
# ==============================================================
#
# Archivo : /etc/kevintech/usuarios/hwid/menu.sh
# Directorio: /etc/kevintech/usuarios/hwid
#
# Módulos:
#   add.sh       -> Crear usuario por HWID
#   list.sh      -> Listar cuentas HWID
#   change.sh    -> Cambiar HWID
#   renovar.sh   -> Renovar cuenta
#   limite.sh    -> Cuotas / consumo
#   bloqueos.sh  -> Historial anti-share
#   derive.sh    -> Derivar contraseña desde HWID
#
# ==============================================================

set -o pipefail

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

BASE="/etc/kevintech"
HWID_DIR="$BASE/usuarios/hwid"
DATA_DIR="$BASE/hwids"
CONFIG="$BASE/config.conf"

VERSION="1.0 Premium"
PANEL_NAME="KEVINTECH MULTI SCRIPT"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# SEGURIDAD
# ==============================================================

if [[ $EUID -ne 0 ]]; then
    clear
    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este panel requiere permisos de root.${RESET}"
    echo -e "${YELLOW}Ejecuta:${RESET} ${GREEN}sudo bash $0${RESET}"
    echo
    exit 1
fi

mkdir -p "$DATA_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null

# ==============================================================
# UTILIDADES
# ==============================================================

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

separator() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

line() {
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

option() {
    printf "  ${GREEN}${BOLD}[%02d]${RESET} ${WHITE}%-3s %-38s${RESET}\n" \
        "$1" "$2" "$3"
}

module_exists() {
    [[ -f "$HWID_DIR/$1" ]]
}

run_module() {
    local FILE="$1"

    if ! module_exists "$FILE"; then
        echo
        echo -e "${RED}${BOLD}✘ MÓDULO NO ENCONTRADO${RESET}"
        echo -e "${WHITE}Archivo:${RESET} ${YELLOW}$HWID_DIR/$FILE${RESET}"
        pause
        return 1
    fi

    chmod +x "$HWID_DIR/$FILE" 2>/dev/null

    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    KEVINTECH HWID                           ║"
    echo "║                    MODULE CENTER                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${GRAY}Ejecutando:${RESET} ${WHITE}$FILE${RESET}"
    echo

    bash "$HWID_DIR/$FILE"
    local EXIT_CODE=$?

    echo
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo -e "${GREEN}✔ Módulo finalizado correctamente.${RESET}"
    else
        echo -e "${RED}✘ El módulo terminó con código: $EXIT_CODE${RESET}"
    fi

    pause
}

get_hwid_count() {
    find "$DATA_DIR" -maxdepth 1 -type f -name '*.hwid' 2>/dev/null | wc -l
}

get_active_count() {
    local count=0
    local f user expire

    for f in "$DATA_DIR"/*.hwid; do
        [[ -f "$f" ]] || continue

        user=$(grep -m1 '^USER:' "$f" 2>/dev/null | cut -d' ' -f2)
        expire=$(grep -m1 '^EXPIRE:' "$f" 2>/dev/null | cut -d' ' -f2)

        [[ -n "$user" ]] || continue
        [[ -n "$expire" ]] || continue
        id "$user" &>/dev/null || continue

        if [[ ! "$expire" < "$(date +%Y-%m-%d)" ]] &&
           ! passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q '^L$'; then
            count=$((count + 1))
        fi
    done

    echo "$count"
}

get_expired_count() {
    local count=0
    local f expire

    for f in "$DATA_DIR"/*.hwid; do
        [[ -f "$f" ]] || continue

        expire=$(grep -m1 '^EXPIRE:' "$f" 2>/dev/null | cut -d' ' -f2)

        [[ -n "$expire" ]] || continue

        if [[ "$expire" < "$(date +%Y-%m-%d)" ]]; then
            count=$((count + 1))
        fi
    done

    echo "$count"
}

get_ip() {
    hostname -I 2>/dev/null | awk '{print $1}'
}

# ==============================================================
# CABECERA
# ==============================================================

show_header() {

    local hostname ip total active expired

    hostname=$(hostname 2>/dev/null)
    ip=$(get_ip)
    total=$(get_hwid_count)
    active=$(get_active_count)
    expired=$(get_expired_count)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🛡️ KEVINTECH MULTI SCRIPT${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                  ${GRAY}HWID MANAGEMENT PANEL${RESET}               ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf "${CYAN}║${RESET} ${WHITE}🖥 SERVIDOR${RESET} %-17s ${WHITE}🌐 IP${RESET} %-18s${CYAN}║${RESET}\n" \
        "${hostname:0:17}" "${ip:0:18}"

    printf "${CYAN}║${RESET} ${WHITE}🔐 HWID${RESET} %-11s ${WHITE}✅ ACTIVAS${RESET} %-12s ${CYAN}║${RESET}\n" \
        "$total" "$active"

    printf "${CYAN}║${RESET} ${WHITE}⏰ EXPIRADAS${RESET} %-7s ${WHITE}📁 DATOS${RESET} %-16s ${CYAN}║${RESET}\n" \
        "$expired" "$DATA_DIR"

    separator
    echo -e "${CYAN}║${RESET} ${YELLOW}${BOLD}          ⚜️ GESTIÓN DE CUENTAS POR HWID ⚜️${RESET}          ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ==============================================================
# MENÚ PRINCIPAL HWID
# ==============================================================

while true; do

    clear
    show_header

    echo
    echo -e "${BLUE}${BOLD}  👤 CUENTAS HWID${RESET}"
    line

    option 1  "➕" "Crear Usuario por HWID"
    option 2  "📋" "Lista de Usuarios HWID"
    option 3  "🔄" "Cambiar HWID"
    option 4  "♻️" "Renovar Cuenta HWID"

    echo
    echo -e "${BLUE}${BOLD}  🛡️ SEGURIDAD Y CONTROL${RESET}"
    line

    option 5  "📊" "Límites y Consumo"
    option 6  "🚫" "Historial de Bloqueos Anti-Share"
    option 7  "🔑" "Derivar Contraseña por HWID"

    echo
    echo -e "${BLUE}${BOLD}  ⚙️ SISTEMA${RESET}"
    line

    option 8  "🔧" "Comprobar Módulos HWID"
    option 9  "📁" "Abrir Directorio de Datos"

    echo
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${RED}${BOLD}[00]${RESET} 🚪 ${WHITE}Volver al Menú de Usuarios${RESET}"

    echo
    echo -e "${GRAY}  KevinTech • HWID Manager • v${VERSION}${RESET}"
    echo

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción:${RESET} ")" OP

    case "$OP" in

        1)
            run_module "add.sh"
            ;;

        2)
            run_module "list.sh"
            ;;

        3)
            run_module "change.sh"
            ;;

        4)
            run_module "renovar.sh"
            ;;

        5)
            run_module "limite.sh"
            ;;

        6)
            run_module "bloqueos.sh"
            ;;

        7)
            clear
            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🔑 DERIVAR CONTRASEÑA HWID${RESET}             ${CYAN}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo
            echo -e "${GRAY}La contraseña se genera usando el HWID y el secreto del servidor.${RESET}"
            echo -e "${YELLOW}⚠ No compartas HWID_SECRET.${RESET}"
            echo
            read -rp "$(echo -e "${GREEN}📲 HWID: ${RESET}")" HWID_INPUT

            if [[ -z "$HWID_INPUT" ]]; then
                echo -e "${RED}✘ Debes ingresar un HWID.${RESET}"
                pause
                continue
            fi

            if [[ ! -f "$HWID_DIR/derive.sh" ]]; then
                echo -e "${RED}✘ No se encontró derive.sh${RESET}"
                pause
                continue
            fi

            echo
            bash "$HWID_DIR/derive.sh" "$HWID_INPUT"
            echo
            pause
            ;;

        8)
            clear
            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🔧 MÓDULOS HWID${RESET}                     ${CYAN}║${RESET}"
            echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

            for FILE in add.sh list.sh change.sh renovar.sh limite.sh bloqueos.sh derive.sh; do
                if [[ -f "$HWID_DIR/$FILE" ]]; then
                    echo -e "${GREEN}✔${RESET} ${WHITE}$FILE${RESET} ${GREEN}disponible${RESET}"
                else
                    echo -e "${RED}✘${RESET} ${WHITE}$FILE${RESET} ${RED}faltante${RESET}"
                fi
            done

            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            pause
            ;;

        9)
            clear
            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET}               ${MAGENTA}${BOLD}📁 DATOS HWID${RESET}                      ${CYAN}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo
            echo -e "${WHITE}Directorio:${RESET} ${GREEN}$DATA_DIR${RESET}"
            echo
            echo -e "${GRAY}Archivos registrados:${RESET}"
            find "$DATA_DIR" -maxdepth 1 -type f -name '*.hwid' -printf '  • %f\n' 2>/dev/null
            echo
            pause
            ;;

        0|00)

            clear
            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET} ${GREEN}${BOLD}          ✔ VOLVIENDO A USUARIOS${RESET}                   ${CYAN}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo

            sleep 1

            if [[ -f "$BASE/usuarios/menu.sh" ]]; then
                exec bash "$BASE/usuarios/menu.sh"
            else
                exit 0
            fi
            ;;

        *)
            echo
            echo -e "${RED}${BOLD}✘ Opción inválida${RESET}"
            sleep 1
            ;;

    esac

done
