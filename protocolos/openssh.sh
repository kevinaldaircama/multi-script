#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    OPENSSH MANAGER
# ==============================================================
# Servicio : ssh / sshd
# Puerto   : 22
# Config   : /etc/kevintech/config.conf
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
VERSION="2.0"

SERVICE="ssh"
PORT="22"

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
# ROOT
# ==============================================================

if [[ $EUID -ne 0 ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}OpenSSH Manager requiere permisos de root.${RESET}"
    echo

    exit 1
fi

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}✘ CONFIGURACIÓN NO ENCONTRADA${RESET}"
    echo
    echo -e "${WHITE}Archivo:${RESET}"
    echo -e "${YELLOW}$CONFIG${RESET}"
    echo

    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null

# ==============================================================
# FUNCIONES
# ==============================================================

line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

error_msg() {
    echo -e "${RED}✘ $1${RESET}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

info() {
    echo -e "${CYAN}➜ $1${RESET}"
}

# ==============================================================
# CONFIG.CONF
# ==============================================================

set_config() {

    local VALUE="$1"

    if grep -q '^OPENSSH=' "$CONFIG"; then
        sed -i "s/^OPENSSH=.*/OPENSSH=$VALUE/" "$CONFIG"
    else
        echo "OPENSSH=$VALUE" >> "$CONFIG"
    fi
}

# ==============================================================
# DETECTAR SERVICIO
# ==============================================================

get_service() {

    if systemctl cat ssh &>/dev/null; then
        echo "ssh"

    elif systemctl cat sshd &>/dev/null; then
        echo "sshd"

    else
        echo ""
    fi
}

# ==============================================================
# ESTADO SERVICIO
# ==============================================================

service_active() {

    local CURRENT_SERVICE

    CURRENT_SERVICE=$(get_service)

    [[ -n "$CURRENT_SERVICE" ]] &&
        systemctl is-active --quiet "$CURRENT_SERVICE" 2>/dev/null
}

service_exists() {

    [[ -n "$(get_service)" ]]
}

# ==============================================================
# PUERTO
# ==============================================================

port_listening() {

    ss -H -lnt 2>/dev/null |
        awk -v port=":$PORT" '
            $4 ~ port"$" {
                found=1
            }
            END {
                exit !found
            }
        '
}

get_port_status() {

    if port_listening; then
        echo -e "${GREEN}● ESCUCHANDO${RESET}"
    else
        echo -e "${RED}● CERRADO${RESET}"
    fi
}

# ==============================================================
# ESTADO GENERAL
# ==============================================================

get_status() {

    if ! service_exists &&
       ! command -v sshd >/dev/null 2>&1; then

        echo -e "${GRAY}● NO INSTALADO${RESET}"

    elif service_active; then

        echo -e "${GREEN}● ACTIVO${RESET}"

    elif service_exists; then

        echo -e "${RED}● DETENIDO${RESET}"

    else

        echo -e "${YELLOW}● INSTALADO${RESET}"
    fi
}

# ==============================================================
# INSTALAR OPENSSH
# ==============================================================

install_openssh() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 INSTALAR OPENSSH${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudo actualizar APT."
        pause
        return 1
    fi

    info "Instalando OpenSSH Server..."

    if ! apt-get install -y openssh-server >/dev/null 2>&1; then
        error_msg "No se pudo instalar OpenSSH Server."
        pause
        return 1
    fi

    local CURRENT_SERVICE

    CURRENT_SERVICE=$(get_service)

    if [[ -z "$CURRENT_SERVICE" ]]; then
        error_msg "No se encontró el servicio SSH después de instalarlo."
        pause
        return 1
    fi

    info "Habilitando servicio..."

    if ! systemctl enable "$CURRENT_SERVICE" >/dev/null 2>&1; then
        warning "No se pudo habilitar automáticamente el servicio."
    fi

    info "Iniciando OpenSSH..."

    systemctl restart "$CURRENT_SERVICE"

    sleep 1

    if service_active; then

        set_config "ON"

        echo
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${RESET}               ${BOLD}✔ OPENSSH ACTIVADO${RESET}                     ${GREEN}║${RESET}"
        echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${GREEN}║${RESET}  Servicio : $CURRENT_SERVICE"
        echo -e "${GREEN}║${RESET}  Puerto   : $PORT"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    else

        set_config "OFF"

        error_msg "OpenSSH no pudo iniciarse."

        echo
        info "Últimos registros:"

        journalctl -u "$CURRENT_SERVICE" \
            -n 15 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# REINICIAR OPENSSH
# ==============================================================

restart_openssh() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}♻️ REINICIAR OPENSSH${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    local CURRENT_SERVICE

    CURRENT_SERVICE=$(get_service)

    if [[ -z "$CURRENT_SERVICE" ]]; then
        error_msg "OpenSSH no está instalado."
        pause
        return
    fi

    info "Reiniciando $CURRENT_SERVICE..."

    systemctl restart "$CURRENT_SERVICE"

    sleep 1

    if service_active; then

        set_config "ON"

        ok "OpenSSH está funcionando correctamente."

    else

        set_config "OFF"

        error_msg "OpenSSH no pudo reiniciarse."

        echo
        journalctl -u "$CURRENT_SERVICE" \
            -n 15 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# ESTADO DETALLADO
# ==============================================================

status_openssh() {

    clear

    local CURRENT_SERVICE

    CURRENT_SERVICE=$(get_service)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${MAGENTA}${BOLD}📊 OPENSSH STATUS${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Estado:${RESET}       $(get_status)"
    echo -e "${WHITE}Servicio:${RESET}     ${CYAN}${CURRENT_SERVICE:-N/A}${RESET}"
    echo -e "${WHITE}Puerto:${RESET}       ${CYAN}$PORT${RESET} $(get_port_status)"
    echo -e "${WHITE}Configuración:${RESET} ${CYAN}${OPENSSH:-OFF}${RESET}"

    line

    if [[ -n "$CURRENT_SERVICE" ]]; then

        echo -e "${WHITE}Estado systemd:${RESET}"
        systemctl is-active "$CURRENT_SERVICE" 2>/dev/null || true

        echo
        echo -e "${WHITE}Arranque automático:${RESET}"
        systemctl is-enabled "$CURRENT_SERVICE" 2>/dev/null || true

    else

        echo -e "${GRAY}Servicio SSH no encontrado.${RESET}"

    fi

    echo
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostic_openssh() {

    clear

    local CURRENT_SERVICE

    CURRENT_SERVICE=$(get_service)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${MAGENTA}${BOLD}🔎 DIAGNÓSTICO OPENSSH${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Componentes:${RESET}"
    echo

    # Cliente
    if command -v ssh >/dev/null 2>&1; then
        ok "Cliente SSH encontrado"
    else
        error_msg "Cliente SSH no encontrado"
    fi

    # Servidor
    if command -v sshd >/dev/null 2>&1; then
        ok "Servidor SSH encontrado"
    else
        error_msg "sshd no encontrado"
    fi

    # Servicio
    if [[ -n "$CURRENT_SERVICE" ]]; then
        ok "Servicio $CURRENT_SERVICE encontrado"
    else
        error_msg "Servicio OpenSSH no encontrado"
    fi

    # Estado
    if service_active; then
        ok "Servicio activo"
    else
        error_msg "Servicio detenido"
    fi

    # Puerto
    if port_listening; then
        ok "Puerto $PORT escuchando"
    else
        error_msg "Puerto $PORT no está escuchando"
    fi

    # Configuración
    if [[ -f /etc/ssh/sshd_config ]]; then
        ok "sshd_config encontrado"
    else
        error_msg "sshd_config no encontrado"
    fi

    echo
    echo -e "${WHITE}Configuración SSH:${RESET}"

    if [[ -f /etc/ssh/sshd_config ]]; then

        sshd -t 2>&1

        if [[ $? -eq 0 ]]; then
            ok "Configuración SSH válida"
        else
            error_msg "La configuración SSH contiene errores"
        fi

    fi

    echo
    echo -e "${WHITE}Puertos escuchando:${RESET}"

    ss -lntp 2>/dev/null |
        grep -E ':(22)([[:space:]]|$)' ||
        echo -e "${GRAY}No se detectó SSH en el puerto 22.${RESET}"

    pause
}

# ==============================================================
# INFORMACIÓN DEL SERVIDOR
# ==============================================================

system_info() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🖥️ INFORMACIÓN DEL SERVIDOR${RESET}                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Hostname:${RESET}      ${GREEN}$(hostname)${RESET}"
    echo -e "${WHITE}Kernel:${RESET}        ${GREEN}$(uname -r)${RESET}"
    echo -e "${WHITE}Arquitectura:${RESET} ${GREEN}$(uname -m)${RESET}"

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo -e "${WHITE}Sistema:${RESET}       ${GREEN}${PRETTY_NAME}${RESET}"
    fi

    echo
    echo -e "${WHITE}IP:${RESET}"
    hostname -I 2>/dev/null

    echo
    echo -e "${WHITE}Memoria:${RESET}"
    free -h

    echo
    echo -e "${WHITE}Disco:${RESET}"
    df -h /

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_openssh() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${RED}${BOLD}🗑️ DESINSTALAR OPENSSH${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    warning "OpenSSH puede ser tu acceso principal al VPS."
    warning "Si lo eliminas, podrías perder el acceso SSH."
    echo

    read -rp "$(echo -e "${RED}Escribe ELIMINAR para continuar: ${RESET}")" CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then
        warning "Operación cancelada."
        sleep 1
        return
    fi

    echo

    local CURRENT_SERVICE

    CURRENT_SERVICE=$(get_service)

    if [[ -n "$CURRENT_SERVICE" ]]; then

        info "Deteniendo servicio..."

        systemctl stop "$CURRENT_SERVICE" 2>/dev/null

        info "Deshabilitando servicio..."

        systemctl disable "$CURRENT_SERVICE" 2>/dev/null
    fi

    info "Desinstalando OpenSSH Server..."

    if apt-get remove -y openssh-server >/dev/null 2>&1; then

        set_config "OFF"

        echo
        ok "OpenSSH Server fue eliminado."

    else

        error_msg "No se pudo eliminar OpenSSH Server."

    fi

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}${BOLD}             🚀 INSTALACIÓN AUTOMÁTICA${RESET}"
    echo -e "${WHITE}                    OPENSSH${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    if install_openssh; then
        echo
        ok "OpenSSH instalado correctamente."
        exit 0
    else
        echo
        error_msg "La instalación automática de OpenSSH falló."
        exit 1
    fi
fi

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

while true; do

    clear

    # Recargar configuración
    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    CURRENT_SERVICE=$(get_service)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${MAGENTA}${BOLD}🔐 OPENSSH MANAGER${RESET}                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                  ${GRAY}SSH SERVER v$VERSION${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Estado:${RESET}        $(get_status)"
    echo -e "${WHITE}Servicio:${RESET}      ${CYAN}${CURRENT_SERVICE:-N/A}${RESET}"
    echo -e "${WHITE}Puerto:${RESET}        ${CYAN}$PORT${RESET} $(get_port_status)"
    echo -e "${WHITE}Configuración:${RESET} ${CYAN}${OPENSSH:-OFF}${RESET}"

    line

    if service_exists ||
       command -v sshd >/dev/null 2>&1; then

        echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN OPENSSH${RESET}"
        echo
        echo -e "  ${GREEN}${BOLD}[01]${RESET} ♻️  Reiniciar Servicio"
        echo -e "  ${GREEN}${BOLD}[02]${RESET} 📊 Estado Detallado"
        echo -e "  ${GREEN}${BOLD}[03]${RESET} 🔎 Diagnóstico"
        echo -e "  ${GREEN}${BOLD}[04]${RESET} 🖥️  Información del Servidor"
        echo -e "  ${GREEN}${BOLD}[05]${RESET} 🗑️  Desinstalar OpenSSH"

    else

        echo -e "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"
        echo
        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar OpenSSH"

    fi

    echo
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  ${WHITE}Regresar al Menú de Protocolos${RESET}"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)

            if service_exists ||
               command -v sshd >/dev/null 2>&1; then

                restart_openssh

            else

                install_openssh

            fi

            ;;

        2)

            status_openssh

            ;;

        3)

            diagnostic_openssh

            ;;

        4)

            system_info

            ;;

        5)

            remove_openssh

            ;;

        0)

            clear
            exec bash "$BASE/protocolos/menu.sh"

            ;;

        "")

            ;;

        *)

            echo
            error_msg "Opción inválida."
            sleep 1

            ;;

    esac

done