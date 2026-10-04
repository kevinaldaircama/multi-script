#!/bin/bash

# ==============================================================
#              KEVINTECH MULTI SCRIPT
#                    SQUID PROXY
# ==============================================================
# Versión: 1.2 Premium
# Puerto: 3128
# Autenticación: PAM
# Usuarios: cuentas del sistema / usuarios SSH
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
# CONFIGURACIÓN
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SQUID_PORT="3128"
SQUID_CONF="/etc/squid/squid.conf"
PAM_CONF="/etc/pam.d/squid"

SERVICE="squid"

SQUID_VERSION="1.2 Premium"

mkdir -p "$BASE"
touch "$CONFIG"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# ==============================================================
# ROOT
# ==============================================================

if [[ $EUID -ne 0 ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BOLD}║                    ACCESO DENEGADO                         ║${RESET}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Squid requiere permisos de root.${RESET}"
    echo

    exit 1
fi

# ==============================================================
# FUNCIONES VISUALES
# ==============================================================

line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

separator() {
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

ok() {
    echo -e "${GREEN}${BOLD}✔${RESET} ${WHITE}$1${RESET}"
}

error_msg() {
    echo -e "${RED}${BOLD}✘${RESET} ${WHITE}$1${RESET}"
}

warning() {
    echo -e "${YELLOW}${BOLD}⚠${RESET} ${WHITE}$1${RESET}"
}

info() {
    echo -e "${CYAN}➜${RESET} ${WHITE}$1${RESET}"
}

pause() {

    echo

    read -rp \
        "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

# ==============================================================
# ESTADO
# ==============================================================

service_active() {

    systemctl is-active --quiet "$SERVICE" 2>/dev/null

}

# ==============================================================
# CABECERA
# ==============================================================

show_header() {

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                 ${MAGENTA}🌐 SQUID PROXY MANAGER${RESET}                ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"

    if service_active; then

        echo -e "${CYAN}║${RESET}  ${WHITE}Estado:${RESET}       ${GREEN}${BOLD}● ACTIVO${RESET}"

    else

        echo -e "${CYAN}║${RESET}  ${WHITE}Estado:${RESET}       ${RED}${BOLD}● INACTIVO${RESET}"

    fi

    echo -e "${CYAN}║${RESET}  ${WHITE}Puerto:${RESET}       ${YELLOW}${SQUID_PORT}${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Autenticación:${RESET} ${GREEN}PAM${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Usuarios:${RESET}     ${GREEN}Sistema / SSH${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Versión:${RESET}      ${MAGENTA}${SQUID_VERSION}${RESET}"

    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ==============================================================
# GUARDAR ESTADO EN CONFIG
# ==============================================================

set_squid_status() {

    local STATUS="$1"

    if grep -q '^SQUID=' "$CONFIG" 2>/dev/null; then

        sed -i "s/^SQUID=.*/SQUID=$STATUS/" "$CONFIG"

    else

        echo "SQUID=$STATUS" >> "$CONFIG"

    fi
}

# ==============================================================
# BUSCAR PAM HELPER
# ==============================================================

buscar_pam_helper() {

    local HELPER=""

    local PATHS=(
        "/usr/lib/squid/basic_pam_auth"
        "/usr/lib/squid/basic_pam_auth"
        "/usr/libexec/squid/basic_pam_auth"
    )

    for FILE in "${PATHS[@]}"; do

        if [[ -x "$FILE" ]]; then

            HELPER="$FILE"
            break

        fi

    done

    if [[ -z "$HELPER" ]] &&
       command -v basic_pam_auth >/dev/null 2>&1; then

        HELPER="$(command -v basic_pam_auth)"

    fi

    echo "$HELPER"
}

# ==============================================================
# INSTALAR DEPENDENCIAS
# ==============================================================

instalar_dependencias() {

    info "Actualizando repositorios..."

    export DEBIAN_FRONTEND=noninteractive

    if ! apt-get update -qq; then

        error_msg "No fue posible actualizar los repositorios."

        return 1

    fi

    info "Instalando Squid..."

    if ! apt-get install -y squid >/dev/null 2>&1; then

        error_msg "No fue posible instalar Squid."

        return 1

    fi

    ok "Squid instalado."

    return 0
}

# ==============================================================
# CONFIGURAR PAM
# ==============================================================

configurar_pam() {

    info "Configurando autenticación PAM..."

    cat > "$PAM_CONF" <<'EOF'
# =========================================================
# KEVINTECH MULTI SCRIPT
# SQUID PAM AUTHENTICATION
# =========================================================

auth       include common-auth
account    include common-account
EOF

    chmod 644 "$PAM_CONF"

    ok "Autenticación PAM configurada."
}

# ==============================================================
# CONFIGURAR SQUID
# ==============================================================

configurar_squid() {

    local PAM_HELPER

    PAM_HELPER="$(buscar_pam_helper)"

    if [[ -z "$PAM_HELPER" ]]; then

        error_msg "No se encontró basic_pam_auth."

        echo
        echo -e "${YELLOW}El paquete de Squid instalado no contiene${RESET}"
        echo -e "${YELLOW}el helper necesario para autenticación PAM.${RESET}"
        echo

        return 1
    fi

    configurar_pam

    # Backup de configuración existente

    if [[ -f "$SQUID_CONF" ]]; then

        cp "$SQUID_CONF" \
           "${SQUID_CONF}.backup" 2>/dev/null

    fi

    cat > "$SQUID_CONF" <<EOF
# =========================================================
# KEVINTECH MULTI SCRIPT PREMIUM
# SQUID PROXY
# =========================================================

http_port $SQUID_PORT

visible_hostname KevinTech-Squid

# =========================================================
# AUTENTICACIÓN PAM
# =========================================================

auth_param basic program $PAM_HELPER squid

auth_param basic children 5

auth_param basic realm KevinTech-Proxy

auth_param basic credentialsttl 2 hours

auth_param basic casesensitive off

acl usuarios_validos proxy_auth REQUIRED

# =========================================================
# PUERTOS
# =========================================================

acl SSL_ports port 443

acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl Safe_ports port 1025-65535

# =========================================================
# ACCESO
# =========================================================

http_access deny !Safe_ports

http_access deny CONNECT !SSL_ports

http_access allow usuarios_validos

http_access deny all

# =========================================================
# PRIVACIDAD
# =========================================================

via off

forwarded_for delete

request_header_access Via deny all

request_header_access X-Forwarded-For deny all

# =========================================================
# CACHE
# =========================================================

cache deny all

# =========================================================
# LOG
# =========================================================

access_log /var/log/squid/access.log

cache_log /var/log/squid/cache.log
EOF

    info "Comprobando configuración..."

    if ! squid -k parse >/dev/null 2>&1; then

        error_msg "La configuración de Squid contiene errores."

        echo

        squid -k parse 2>&1

        return 1

    fi

    ok "Configuración de Squid correcta."

    return 0
}

# ==============================================================
# INICIAR SERVICIO
# ==============================================================

iniciar_squid() {

    info "Habilitando servicio..."

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    info "Iniciando Squid..."

    if ! systemctl restart "$SERVICE"; then

        set_squid_status "OFF"

        error_msg "Squid no pudo iniciar."

        echo

        journalctl -u "$SERVICE" -n 20 --no-pager 2>/dev/null

        return 1

    fi

    sleep 2

    if service_active; then

        set_squid_status "ON"

        ok "Squid está activo."

        return 0

    fi

    set_squid_status "OFF"

    error_msg "Squid no quedó activo."

    echo

    journalctl -u "$SERVICE" -n 20 --no-pager 2>/dev/null

    return 1
}

# ==============================================================
# INSTALAR / ACTUALIZAR
# ==============================================================

instalar_squid() {

    clear

    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                  ${GREEN}🌐 SQUID PROXY${RESET}                     ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                 ${GRAY}INSTALL / UPDATE${RESET}                    ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Configuración:${RESET}"
    echo
    echo -e "  ${GRAY}•${RESET} Puerto        : ${GREEN}${SQUID_PORT}${RESET}"
    echo -e "  ${GRAY}•${RESET} Autenticación : ${GREEN}PAM${RESET}"
    echo -e "  ${GRAY}•${RESET} Usuarios      : ${GREEN}Sistema / SSH${RESET}"
    echo -e "  ${GRAY}•${RESET} Proxy         : ${GREEN}Squid${RESET}"
    echo

    separator

    if ! instalar_dependencias; then

        pause
        return 1

    fi

    echo

    if ! configurar_squid; then

        pause
        return 1

    fi

    echo

    if ! iniciar_squid; then

        pause
        return 1

    fi

    echo

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║              ✔ SQUID INSTALADO CORRECTAMENTE              ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "  ${WHITE}Puerto:${RESET}       ${GREEN}${SQUID_PORT}${RESET}"
    echo -e "  ${WHITE}Estado:${RESET}       ${GREEN}● ACTIVO${RESET}"
    echo -e "  ${WHITE}Autenticación:${RESET} ${GREEN}PAM${RESET}"
    echo -e "  ${WHITE}Usuarios:${RESET}     ${GREEN}cuentas del sistema${RESET}"
    echo

    echo -e "${GRAY}Squid utiliza las mismas cuentas creadas por tu sistema SSH.${RESET}"
    echo -e "${GRAY}No mantiene una base de usuarios independiente.${RESET}"

    pause
}

# ==============================================================
# LOG
# ==============================================================

ver_log() {

    clear

    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                   ${MAGENTA}📋 SQUID SERVER LOG${RESET}               ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! systemctl list-unit-files \
        | grep -q "^${SERVICE}.service"; then

        warning "Squid todavía no está instalado."
        pause
        return

    fi

    echo -e "${GRAY}Mostrando las últimas 100 líneas...${RESET}"
    echo

    line

    journalctl -u "$SERVICE" \
        -n 100 \
        --no-pager \
        --full

    line

    echo
    echo -e "${GRAY}También puedes consultar:${RESET}"
    echo -e "${WHITE}/var/log/squid/access.log${RESET}"
    echo -e "${WHITE}/var/log/squid/cache.log${RESET}"

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

desinstalar_squid() {

    clear

    echo
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BOLD}║${RESET}                ${RED}🗑 DESINSTALAR SQUID${RESET}                  ${RED}${BOLD}║${RESET}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! dpkg -s squid >/dev/null 2>&1; then

        warning "Squid no está instalado."

        pause
        return

    fi

    echo -e "${YELLOW}Se eliminará:${RESET}"
    echo
    echo -e "  ${GRAY}•${RESET} Paquete Squid"
    echo -e "  ${GRAY}•${RESET} Servicio Squid"
    echo -e "  ${GRAY}•${RESET} Configuración PAM de Squid"
    echo

    echo -e "${GRAY}Las cuentas SSH del sistema NO serán eliminadas.${RESET}"
    echo

    read -rp \
        "$(echo -e "${YELLOW}${BOLD}¿Confirmar desinstalación? [s/N]: ${RESET}")" CONFIRM

    case "${CONFIRM,,}" in

        s|si|sí|y|yes)

            echo

            info "Deteniendo Squid..."

            systemctl disable --now "$SERVICE" \
                >/dev/null 2>&1 || true

            info "Eliminando Squid..."

            if apt-get remove -y squid >/dev/null 2>&1; then

                rm -f "$PAM_CONF"

                set_squid_status "OFF"

                echo

                echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${GREEN}${BOLD}║              ✔ SQUID DESINSTALADO                          ║${RESET}"
                echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"

            else

                error_msg "No fue posible eliminar Squid."

            fi

            ;;

        *)

            echo

            warning "Operación cancelada."

            ;;

    esac

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    instalar_squid

    exit $?

fi

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

while true; do

    clear

    show_header

    echo
    echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN SQUID${RESET}"

    line

    echo -e "  ${GREEN}${BOLD}[01]${RESET}  🚀 ${WHITE}Instalar / Actualizar${RESET}"
    echo -e "  ${GREEN}${BOLD}[02]${RESET}  📋 ${WHITE}Ver Log${RESET}"
    echo -e "  ${RED}${BOLD}[03]${RESET}  🗑️  ${WHITE}Desinstalar${RESET}"

    echo
    separator

    echo -e "  ${RED}${BOLD}[00]${RESET}  ↩️  ${WHITE}Regresar${RESET}"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Squid Proxy • ${SQUID_VERSION}${RESET}"
    echo

    read -rp \
        "$(echo -e "${CYAN}${BOLD}  ➜ Selecciona una opción: ${RESET}")" OPCION

    case "$OPCION" in

        1|01)

            instalar_squid

            ;;

        2|02)

            ver_log

            ;;

        3|03)

            desinstalar_squid

            ;;

        0|00)

            clear
            exit 0

            ;;

        *)

            echo
            error_msg "Opción inválida."
            sleep 1

            ;;

    esac

done