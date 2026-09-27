#!/bin/bash

#=========================================================
# KevinTech Multi Script Premium
# Módulo: Squid Proxy
# Versión: 1.1 Premium
#
# FUNCIONES:
# - Squid Proxy puerto 3128
# - Utiliza usuarios creados por usuarios/add.sh
# - Autenticación mediante PAM
# - Misma contraseña utilizada por SSH
# - Sin base de usuarios duplicada
# - Integración config.conf
#=========================================================

#========================#
#         COLORES
#========================#

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
MAGENTA='\e[1;95m'
WHITE='\e[1;97m'
GRAY='\e[1;90m'
RESET='\e[0m'

#========================#
#      CONFIGURACIÓN
#========================#

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SQUID_PORT="3128"
SQUID_CONF="/etc/squid/squid.conf"
PAM_CONF="/etc/pam.d/squid"

SERVICE="squid"

mkdir -p "$BASE"

touch "$CONFIG"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#=========================================================
# FUNCIONES
#=========================================================

line() {

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

}

pause() {

    echo

    read -rp \
        "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"

}

msg_ok() {

    echo -e "${GREEN}✔ $1${RESET}"

}

msg_error() {

    echo -e "${RED}✘ $1${RESET}"

}

msg_info() {

    echo -e "${CYAN}➜ $1${RESET}"

}

msg_warn() {

    echo -e "${YELLOW}⚠ $1${RESET}"

}

#=========================================================
# CONFIG.CONF
#=========================================================

set_squid_status() {

    local STATUS="$1"

    if grep -q '^SQUID=' "$CONFIG" 2>/dev/null; then

        sed -i "s/^SQUID=.*/SQUID=$STATUS/" "$CONFIG"

    else

        echo "SQUID=$STATUS" >> "$CONFIG"

    fi

}

#=========================================================
# INSTALAR DEPENDENCIAS
#=========================================================

instalar_dependencias() {

    msg_info "Instalando Squid..."

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq

    if ! apt-get install -y squid >/dev/null 2>&1; then

        msg_error "No fue posible instalar Squid."

        return 1

    fi

    return 0
}

#=========================================================
# BUSCAR BASIC PAM AUTH
#=========================================================

buscar_pam_helper() {

    local HELPER=""

    if [[ -x "/usr/lib/squid/basic_pam_auth" ]]; then

        HELPER="/usr/lib/squid/basic_pam_auth"

    elif [[ -x "/usr/lib/squid/basic_pam_auth" ]]; then

        HELPER="/usr/lib/squid/basic_pam_auth"

    elif command -v basic_pam_auth >/dev/null 2>&1; then

        HELPER="$(command -v basic_pam_auth)"

    fi

    echo "$HELPER"
}

#=========================================================
# CONFIGURAR PAM
#=========================================================

configurar_pam() {

    msg_info "Configurando autenticación PAM..."

    cat > "$PAM_CONF" <<'EOF'
#=========================================================
# KevinTech Multi Script
# Squid PAM Authentication
#=========================================================

auth       include common-auth
account    include common-account
EOF

    chmod 644 "$PAM_CONF"

    msg_ok "Autenticación PAM configurada."

}

#=========================================================
# CONFIGURAR SQUID
#=========================================================

configurar_squid() {

    local PAM_HELPER

    PAM_HELPER="$(buscar_pam_helper)"

    if [[ -z "$PAM_HELPER" ]]; then

        msg_error "No se encontró basic_pam_auth."

        echo

        echo -e "${YELLOW}El paquete de Squid instalado no incluye${RESET}"
        echo -e "${YELLOW}el helper PAM necesario para autenticar${RESET}"
        echo -e "${YELLOW}usuarios del sistema.${RESET}"

        return 1

    fi

    configurar_pam

    if [[ -f "$SQUID_CONF" ]]; then

        cp "$SQUID_CONF" "${SQUID_CONF}.backup" 2>/dev/null

    fi

    cat > "$SQUID_CONF" <<EOF
#=========================================================
# KevinTech Multi Script Premium
# SQUID PROXY
# Puerto: $SQUID_PORT
# Autenticación: usuarios del sistema
#=========================================================

#---------------------------------------------------------
# PUERTO
#---------------------------------------------------------

http_port $SQUID_PORT

visible_hostname KevinTech-Squid

#---------------------------------------------------------
# AUTENTICACIÓN PAM
#---------------------------------------------------------

auth_param basic program $PAM_HELPER squid

auth_param basic children 5

auth_param basic realm KevinTech-Proxy

auth_param basic credentialsttl 2 hours

auth_param basic casesensitive off

acl usuarios_validos proxy_auth REQUIRED

#---------------------------------------------------------
# PUERTOS SEGUROS
#---------------------------------------------------------

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

#---------------------------------------------------------
# REGLAS
#---------------------------------------------------------

http_access deny !Safe_ports

http_access deny CONNECT !SSL_ports

http_access allow usuarios_validos

http_access deny all

#---------------------------------------------------------
# PRIVACIDAD
#---------------------------------------------------------

via off

forwarded_for delete

request_header_access Via deny all

request_header_access X-Forwarded-For deny all

#---------------------------------------------------------
# CACHE
#---------------------------------------------------------

cache deny all

#---------------------------------------------------------
# LOG
#---------------------------------------------------------

access_log /var/log/squid/access.log

cache_log /var/log/squid/cache.log

EOF

    if ! squid -k parse >/dev/null 2>&1; then

        msg_error "La configuración de Squid contiene errores."

        echo

        squid -k parse 2>&1

        return 1

    fi

    msg_ok "Configuración de Squid correcta."

    return 0
}

#=========================================================
# INICIAR SQUID
#=========================================================

iniciar_squid() {

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        set_squid_status "ON"

        msg_ok "Squid está activo."

        return 0

    fi

    set_squid_status "OFF"

    msg_error "Squid no pudo iniciar."

    echo

    journalctl -u "$SERVICE" -n 15 --no-pager 2>/dev/null

    return 1
}

#=========================================================
# INSTALAR SQUID
#=========================================================

instalar_squid() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              🌐 SQUID PROXY KEVINTECH                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}                 INSTALACIÓN                               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

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

    msg_ok "Squid instalado correctamente."

    echo

    echo -e "${WHITE}Puerto:${RESET} ${GREEN}$SQUID_PORT${RESET}"

    echo -e "${WHITE}Usuario:${RESET} ${GREEN}usuario creado en add.sh${RESET}"

    echo -e "${WHITE}Contraseña:${RESET} ${GREEN}misma contraseña SSH${RESET}"

    echo

    echo -e "${GRAY}Squid no crea usuarios propios.${RESET}"

    echo -e "${GRAY}Utiliza las cuentas del sistema mediante PAM.${RESET}"

    pause
}

#=========================================================
# INICIAR
#=========================================================

op_iniciar() {

    clear

    if ! systemctl start "$SERVICE" >/dev/null 2>&1; then

        msg_error "No fue posible iniciar Squid."

        pause

        return

    fi

    set_squid_status "ON"

    msg_ok "Squid iniciado."

    pause
}

#=========================================================
# DETENER
#=========================================================

op_detener() {

    clear

    systemctl stop "$SERVICE" >/dev/null 2>&1

    set_squid_status "OFF"

    msg_ok "Squid detenido."

    pause
}

#=========================================================
# REINICIAR
#=========================================================

op_reiniciar() {

    clear

    systemctl restart "$SERVICE" >/dev/null 2>&1

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        set_squid_status "ON"

        msg_ok "Squid reiniciado correctamente."

    else

        set_squid_status "OFF"

        msg_error "Squid no pudo reiniciarse."

    fi

    pause
}

#=========================================================
# USUARIOS DEL SISTEMA
#=========================================================

listar_usuarios() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              👤 USUARIOS PARA SQUID                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${GRAY}Estos usuarios son los creados desde usuarios/add.sh.${RESET}"

    echo

    USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

    if [[ -z "$USERS" ]]; then

        msg_warn "No existen usuarios SSH."

        pause

        return

    fi

    echo -e "${GREEN}Usuarios disponibles:${RESET}"

    echo

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        FECHA=$(chage -l "$USER" 2>/dev/null |
            awk -F': ' '/Account expires/ {
                print $2
                exit
            }')

        [[ -z "$FECHA" ]] && FECHA="N/D"

        echo -e " ${GREEN}👤${RESET} ${WHITE}$USER${RESET} ${GRAY}| Expira: $FECHA${RESET}"

    done <<< "$USERS"

    echo

    echo -e "${GRAY}La contraseña no se muestra ni se almacena aquí.${RESET}"

    echo -e "${GRAY}Squid la valida directamente mediante PAM.${RESET}"

    pause
}

#=========================================================
# VER ESTADO
#=========================================================

ver_estado() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}                 📊 ESTADO SQUID                          ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}Servicio:${RESET}"

    if systemctl is-active --quiet "$SERVICE"; then

        echo -e " ${GREEN}● ACTIVO${RESET}"

    else

        echo -e " ${RED}● DETENIDO${RESET}"

    fi

    echo

    echo -e "${WHITE}Puerto:${RESET}"

    if ss -H -ltn 2>/dev/null |
        awk -v PORT=":$SQUID_PORT" '$4 ~ PORT"$"' |
        grep -q .; then

        echo -e " ${GREEN}● $SQUID_PORT ESCUCHANDO${RESET}"

    else

        echo -e " ${RED}● $SQUID_PORT NO ESTÁ ESCUCHANDO${RESET}"

    fi

    echo

    echo -e "${WHITE}KevinTech:${RESET}"

    if grep -q '^SQUID=ON' "$CONFIG" 2>/dev/null; then

        echo -e " ${GREEN}● SQUID=ON${RESET}"

    else

        echo -e " ${GRAY}● SQUID=OFF${RESET}"

    fi

    echo

    echo -e "${WHITE}Autenticación:${RESET}"

    echo -e " ${GREEN}● Usuarios del sistema / PAM${RESET}"

    echo

    pause
}

#=========================================================
# DESINSTALAR
#=========================================================

desinstalar_squid() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RED}                 🗑 DESINSTALAR SQUID                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Deseas desinstalar Squid? [s/N]: ${RESET}")" RESPUESTA

    case "${RESPUESTA,,}" in

        s|si|sí|y|yes)

            systemctl stop "$SERVICE" >/dev/null 2>&1

            systemctl disable "$SERVICE" >/dev/null 2>&1

            apt-get remove -y squid >/dev/null 2>&1

            rm -f "$PAM_CONF"

            rm -f "${SQUID_CONF}.backup"

            set_squid_status "OFF"

            msg_ok "Squid fue desinstalado."

            ;;

        *)

            msg_warn "Operación cancelada."

            ;;

    esac

    pause
}

#=========================================================
# MODO AUTOMÁTICO
#=========================================================

if [[ "$1" == "--auto" ]]; then

    instalar_squid

    exit $?

fi

#=========================================================
# MENÚ
#=========================================================

while true; do

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}              🌐 KEVINTECH SQUID PROXY                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}Puerto:${RESET} ${GREEN}$SQUID_PORT${RESET}"

    if systemctl is-active --quiet "$SERVICE"; then

        echo -e "${WHITE}Estado:${RESET} ${GREEN}● ACTIVO${RESET}"

    else

        echo -e "${WHITE}Estado:${RESET} ${RED}● DETENIDO${RESET}"

    fi

    line

    echo -e "${GREEN}[01]${WHITE} 📦 Instalar Squid"
    echo -e "${GREEN}[02]${WHITE} ▶️  Iniciar Squid"
    echo -e "${GREEN}[03]${WHITE} ⏹️  Detener Squid"
    echo -e "${GREEN}[04]${WHITE} 🔄 Reiniciar Squid"
    echo -e "${GREEN}[05]${WHITE} 👤 Ver usuarios de add.sh"
    echo -e "${GREEN}[06]${WHITE} 📊 Ver estado"
    echo -e "${RED}[07]${WHITE} 🗑️  Desinstalar Squid"

    echo

    echo -e "${RED}[00]${WHITE} ↩️  Regresar"

    echo

    read -rp \
        "$(echo -e "${YELLOW}Opción: ${RESET}")" OPCION

    case "$OPCION" in

        1|01)

            instalar_squid

            ;;

        2|02)

            op_iniciar

            ;;

        3|03)

            op_detener

            ;;

        4|04)

            op_reiniciar

            ;;

        5|05)

            listar_usuarios

            ;;

        6|06)

            ver_estado

            ;;

        7|07)

            desinstalar_squid

            ;;

        0|00)

            clear

            exit 0

            ;;

        *)

            msg_error "Opción inválida."

            sleep 1

            ;;

    esac

done
