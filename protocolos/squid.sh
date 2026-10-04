#!/bin/bash

#==================================================
# KEVINTECH NETWORK PREMIUM
# Squid Proxy Manager
# Proxy HTTP — Puerto fijo 3128
#
# Gestión:
#   01. Instalar / Actualizar
#   02. Ver Log
#   03. Desinstalar
#   00. Regresar
#==================================================

#==================================================
# i18n shim
#==================================================

if ! declare -F trx >/dev/null 2>&1; then
    trx() {
        printf '%s' "$1"
    }
fi

#==================================================
# CONFIGURACIÓN
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

#==================================================
# LIBRERÍAS KEVINTECH
#==================================================

[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

#==================================================
# COLORES
#==================================================

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
WHITE="${MV_WHT:-\e[1;97m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
GRAY="${MV_GRY:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

#==================================================
# SQUID
#==================================================

SQUID_PORT="3128"
SQUID_CONF="/etc/squid/squid.conf"
SQUID_SERVICE="squid"
SQUID_LOG_DIR="/var/log/squid"

#==================================================
# FUNCIONES DE RESPALDO VISUAL
#==================================================

if ! declare -F mv_brand_header >/dev/null 2>&1; then

    mv_brand_header() {

        clear

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${WHITE}                 $1${RESET}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo

    }

fi

if ! declare -F mv_header >/dev/null 2>&1; then

    mv_header() {

        clear

        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║ ${MAGENTA}${BOLD:-}${1}${RESET}"
        echo -e "${CYAN}║ ${GRAY}$2${RESET}"
        echo -e "${CYAN}║ ${MAGENTA}$3${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo

    }

fi

if ! declare -F anim_step >/dev/null 2>&1; then

    anim_step() {
        echo -e "${CYAN}➜ ${WHITE}$1${RESET}"
    }

fi

if ! declare -F svc_restart_anim >/dev/null 2>&1; then

    svc_restart_anim() {

        local SERVICE="$1"
        local TEXT="$2"

        echo -e "${CYAN}➜ ${WHITE}$TEXT${RESET}"

        systemctl restart "$SERVICE"

    }

fi

#==================================================
# ESTADO
#==================================================

squid_active() {

    systemctl is-active --quiet "$SQUID_SERVICE" 2>/dev/null

}

#==================================================
# GUARDAR ESTADO
#==================================================

set_squid_status() {

    local STATUS="$1"

    sed -i '/^SQUID=/d' "$CONFIG"

    echo "SQUID=$STATUS" >> "$CONFIG"

}

#==================================================
# ABRIR PUERTO 3128
#==================================================

open_squid_port() {

    if command -v iptables >/dev/null 2>&1; then

        iptables -C INPUT \
            -p tcp \
            --dport 3128 \
            -j ACCEPT \
            2>/dev/null ||

        iptables -A INPUT \
            -p tcp \
            --dport 3128 \
            -j ACCEPT

    fi

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null |
            grep -q "Status: active"; then

            ufw allow 3128/tcp >/dev/null 2>&1

        fi

    fi

}

#==================================================
# CERRAR PUERTO 3128
#==================================================

close_squid_port() {

    if command -v iptables >/dev/null 2>&1; then

        while iptables -D INPUT \
            -p tcp \
            --dport 3128 \
            -j ACCEPT \
            2>/dev/null
        do
            :
        done

    fi

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null |
            grep -q "Status: active"; then

            ufw delete allow 3128/tcp \
                >/dev/null 2>&1 || true

        fi

    fi

}

#==================================================
# INSTALAR / ACTUALIZAR
#==================================================

install_squid() {

    clear

    mv_brand_header "🌐 INSTALAR / ACTUALIZAR SQUID"

    echo -e "${GRAY}KEVINTECH NETWORK PREMIUM${RESET}"
    echo -e "${GRAY}Proxy HTTP · Puerto fijo 3128${RESET}"
    echo

    echo -e "${WHITE}Puerto:${RESET} ${GREEN}3128${RESET}"
    echo -e "${WHITE}Tipo:${RESET}   ${GREEN}HTTP Proxy${RESET}"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    #----------------------------------------------
    # Actualizar repositorios
    #----------------------------------------------

    anim_step "Actualizando repositorios..."

    if ! apt-get update -qq; then

        echo
        echo -e "${RED}❌ Error actualizando los repositorios.${RESET}"

        sleep 3

        return 1

    fi

    #----------------------------------------------
    # Instalar / actualizar Squid
    #----------------------------------------------

    anim_step "Instalando / actualizando Squid..."

    if ! DEBIAN_FRONTEND=noninteractive \
        apt-get install -y squid >/dev/null 2>&1; then

        echo
        echo -e "${RED}❌ Error instalando Squid.${RESET}"

        sleep 3

        return 1

    fi

    #----------------------------------------------
    # Crear configuración
    #----------------------------------------------

    anim_step "Configurando Squid en puerto 3128..."

    if [[ -f "$SQUID_CONF" ]]; then

        cp "$SQUID_CONF" \
            "${SQUID_CONF}.backup" 2>/dev/null

    fi

    cat > "$SQUID_CONF" <<'EOF'
#==================================================
# KEVINTECH NETWORK PREMIUM
# SQUID PROXY
# Puerto HTTP: 3128
#==================================================

http_port 3128

visible_hostname KevinTech-Squid

#==================================================
# PUERTOS SEGUROS
#==================================================

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

#==================================================
# ACCESO
#==================================================

http_access deny !Safe_ports

http_access deny CONNECT !SSL_ports

http_access allow localhost

http_access deny all

#==================================================
# PRIVACIDAD
#==================================================

via off

forwarded_for delete

request_header_access Via deny all

request_header_access X-Forwarded-For deny all

#==================================================
# CACHE
#==================================================

cache deny all

#==================================================
# LOG
#==================================================

access_log /var/log/squid/access.log

cache_log /var/log/squid/cache.log
EOF

    #----------------------------------------------
    # Validar configuración
    #----------------------------------------------

    anim_step "Comprobando configuración..."

    if ! squid -k parse >/dev/null 2>&1; then

        echo
        echo -e "${RED}❌ La configuración de Squid contiene errores.${RESET}"
        echo

        squid -k parse 2>&1

        sleep 4

        return 1

    fi

    #----------------------------------------------
    # Habilitar Squid
    #----------------------------------------------

    anim_step "Habilitando servicio..."

    systemctl enable "$SQUID_SERVICE" \
        >/dev/null 2>&1

    #----------------------------------------------
    # Iniciar Squid
    #----------------------------------------------

    anim_step "Iniciando Squid..."

    systemctl restart "$SQUID_SERVICE"

    sleep 2

    #----------------------------------------------
    # Comprobar
    #----------------------------------------------

    if squid_active; then

        set_squid_status "ON"

        open_squid_port

        echo

        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║             ✅ SQUID INSTALADO / ACTUALIZADO               ║${RESET}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo

        echo -e "${WHITE}Proxy HTTP :${RESET} ${GREEN}IP:3128${RESET}"
        echo -e "${WHITE}Puerto     :${RESET} ${GREEN}3128${RESET}"
        echo -e "${WHITE}Estado     :${RESET} ${GREEN}🟢 ACTIVO${RESET}"

    else

        set_squid_status "OFF"

        echo
        echo -e "${RED}❌ Squid no pudo iniciar.${RESET}"
        echo

        journalctl \
            -u "$SQUID_SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

    fi

    echo

    sleep 3

}

#==================================================
# VER LOG
#==================================================

view_squid_log() {

    clear

    mv_brand_header "📋 LOG SQUID"

    echo -e "${GRAY}Últimos registros del servicio Squid${RESET}"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    journalctl \
        -u "$SQUID_SERVICE" \
        -n 50 \
        --no-pager \
        --full \
        2>/dev/null

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ -f "$SQUID_LOG_DIR/access.log" ]]; then

        echo
        echo -e "${MAGENTA}📡 ÚLTIMAS CONEXIONES HTTP${RESET}"
        echo

        tail -20 "$SQUID_LOG_DIR/access.log"

    fi

    if [[ -f "$SQUID_LOG_DIR/cache.log" ]]; then

        echo
        echo -e "${MAGENTA}⚙️ ÚLTIMOS EVENTOS SQUID${RESET}"
        echo

        tail -20 "$SQUID_LOG_DIR/cache.log"

    fi

    echo

    read -n1 -r -p \
        "$(trx 'Presiona una tecla para continuar...')"

}

#==================================================
# DESINSTALAR
#==================================================

remove_squid() {

    clear

    mv_brand_header "🗑️ DESINSTALAR SQUID"

    echo -e "${WHITE}Puerto utilizado:${RESET} ${GREEN}3128${RESET}"
    echo

    echo -e "${YELLOW}Se eliminará Squid del sistema.${RESET}"
    echo -e "${GRAY}Las cuentas SSH no serán eliminadas.${RESET}"
    echo

    read -rp \
        "$(trx '¿Eliminar Squid? (s/n): ')" RESPUESTA

    [[ ! "$RESPUESTA" =~ ^[Ss]$ ]] && return

    echo

    anim_step "Deteniendo Squid..."

    systemctl stop "$SQUID_SERVICE" \
        >/dev/null 2>&1 || true

    systemctl disable "$SQUID_SERVICE" \
        >/dev/null 2>&1 || true

    anim_step "Eliminando Squid..."

    if ! DEBIAN_FRONTEND=noninteractive \
        apt-get purge -y squid >/dev/null 2>&1; then

        echo
        echo -e "${RED}❌ No fue posible eliminar Squid.${RESET}"

        sleep 3

        return 1

    fi

    #----------------------------------------------
    # Limpiar archivos PAM si existieran
    #----------------------------------------------

    rm -f /etc/pam.d/squid

    #----------------------------------------------
    # Firewall
    #----------------------------------------------

    close_squid_port

    #----------------------------------------------
    # Estado
    #----------------------------------------------

    set_squid_status "OFF"

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║                ✅ SQUID ELIMINADO                          ║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    sleep 3

}

#==================================================
# MODO CLI
#==================================================

case "${1:-}" in

    --install)

        install_squid
        exit $?

        ;;

    --log)

        view_squid_log
        exit $?

        ;;

    --uninstall)

        remove_squid
        exit $?

        ;;

esac

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    clear

    source "$CONFIG"

    #----------------------------------------------
    # Estado
    #----------------------------------------------

    if squid_active; then

        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    else

        STATUS="${RED}🔴 DETENIDO${RESET}"

    fi

    #----------------------------------------------
    # Header
    #----------------------------------------------

    if declare -F mv_header >/dev/null 2>&1; then

        mv_header \
            "🌐 Squid Proxy" \
            "$(trx 'Proxy HTTP · puerto 3128')" \
            "v7.0 Premium"

    else

        clear

        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}              ${MAGENTA}🌐 SQUID PROXY${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    fi

    #----------------------------------------------
    # Branding
    #----------------------------------------------

    if declare -F kevintech_contacts >/dev/null 2>&1; then

        kevintech_contacts 2>/dev/null || true

    fi

    echo -e "${WHITE}Estado :${RESET} $STATUS"
    echo -e "${WHITE}Puerto :${RESET} ${GREEN}3128${RESET}"

    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e "${MAGENTA}${BOLD:-}             SQUID PROXY MANAGER${RESET}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    #==================================================
    # SOLO 3 OPCIONES
    #==================================================

    echo -e "${GREEN}${BOLD}[01]${RESET} 🚀 ${WHITE}Instalar / Actualizar${RESET}"
    echo -e "${GREEN}${BOLD}[02]${RESET} 📋 ${WHITE}Ver Log${RESET}"
    echo -e "${RED}${BOLD}[03]${RESET} 🗑️  ${WHITE}Desinstalar${RESET}"

    echo

    echo -e "${RED}${BOLD}[00]${RESET} ↩️  ${WHITE}Regresar${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}${BOLD}► Opción: ${RESET}")" OPCION

    #==================================================
    # ACCIONES
    #==================================================

    case "$OPCION" in

        1|01)

            install_squid

            ;;

        2|02)

            view_squid_log

            ;;

        3|03)

            remove_squid

            ;;

        0|00)

            clear

            if [[ -f "$BASE/protocolos/menu.sh" ]]; then

                exec bash "$BASE/protocolos/menu.sh"

            else

                exit 0

            fi

            ;;

        *)

            echo
            echo -e "${RED}❌ Opción inválida.${RESET}"

            sleep 2

            ;;

    esac

done