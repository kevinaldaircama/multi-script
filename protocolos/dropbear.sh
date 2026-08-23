#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    DROPBEAR MANAGER
# ==============================================================
# Servicio : dropbear_custom
# Puertos  : 90 / 143 / 109
# Config   : /etc/kevintech/config.conf
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
VERSION="2.0"

SERVICE="dropbear_custom"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"

PORTS="90,143,109"
BIN="/usr/sbin/dropbear"

DROPBEAR_DIR="/etc/dropbear"
BANNER_FILE="/etc/issue.net"

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
    echo -e "${WHITE}Dropbear Manager requiere permisos de root.${RESET}"
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
# FUNCIONES VISUALES
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

    if grep -q '^DROPBEAR=' "$CONFIG"; then
        sed -i "s/^DROPBEAR=.*/DROPBEAR=$VALUE/" "$CONFIG"
    else
        echo "DROPBEAR=$VALUE" >> "$CONFIG"
    fi
}

set_ports_config() {

    local VALUE="$1"

    if grep -q '^DROPBEAR_PORT=' "$CONFIG"; then
        sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$VALUE\"/" "$CONFIG"
    else
        echo "DROPBEAR_PORT=\"$VALUE\"" >> "$CONFIG"
    fi
}

remove_ports_config() {
    sed -i '/^DROPBEAR_PORT=/d' "$CONFIG"
}

# ==============================================================
# SERVICIO
# ==============================================================

service_exists() {
    systemctl cat "$SERVICE" &>/dev/null
}

service_active() {
    systemctl is-active --quiet "$SERVICE" 2>/dev/null
}

# ==============================================================
# ESTADO
# ==============================================================

get_status() {

    if ! command -v dropbear >/dev/null 2>&1 &&
       ! service_exists; then

        echo -e "${GRAY}● NO INSTALADO${RESET}"

    elif service_active; then

        echo -e "${GREEN}● ACTIVO${RESET}"

    elif service_exists; then

        echo -e "${RED}● DETENIDO${RESET}"

    else

        echo -e "${YELLOW}● CONFIGURADO${RESET}"
    fi
}

# ==============================================================
# PUERTOS
# ==============================================================

port_in_use() {

    local PORT="$1"

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

port_listening() {

    local PORT="$1"

    if port_in_use "$PORT"; then
        echo -e "${GREEN}● ESCUCHANDO${RESET}"
    else
        echo -e "${RED}● CERRADO${RESET}"
    fi
}

check_install_ports() {

    local PORT

    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT in "${PORT_ARRAY[@]}"; do

        if port_in_use "$PORT"; then

            error_msg "El puerto $PORT ya está siendo utilizado."

            echo
            echo -e "${GRAY}Puedes comprobarlo con:${RESET}"
            echo -e "${WHITE}ss -lntp | grep :$PORT${RESET}"

            return 1
        fi

    done

    return 0
}

# ==============================================================
# GENERAR CLAVES
# ==============================================================

generate_keys() {

    mkdir -p "$DROPBEAR_DIR"

    chmod 700 "$DROPBEAR_DIR"

    if [[ ! -f "$DROPBEAR_DIR/dropbear_rsa_host_key" ]]; then

        info "Generando clave RSA..."

        if ! dropbearkey \
            -t rsa \
            -f "$DROPBEAR_DIR/dropbear_rsa_host_key" \
            >/dev/null 2>&1; then

            error_msg "No se pudo generar la clave RSA."
            return 1
        fi
    fi

    if [[ ! -f "$DROPBEAR_DIR/dropbear_ecdsa_host_key" ]]; then

        info "Generando clave ECDSA..."

        if ! dropbearkey \
            -t ecdsa \
            -f "$DROPBEAR_DIR/dropbear_ecdsa_host_key" \
            >/dev/null 2>&1; then

            error_msg "No se pudo generar la clave ECDSA."
            return 1
        fi
    fi

    return 0
}

# ==============================================================
# INSTALAR DEPENDENCIAS
# ==============================================================

install_package() {

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudo actualizar APT."
        return 1
    fi

    info "Instalando Dropbear..."

    if ! apt-get install -y dropbear >/dev/null 2>&1; then
        error_msg "No se pudo instalar Dropbear."
        return 1
    fi

    if ! command -v dropbear >/dev/null 2>&1; then
        error_msg "El binario de Dropbear no está disponible."
        return 1
    fi

    ok "Dropbear instalado."

    return 0
}

# ==============================================================
# CREAR SERVICIO
# ==============================================================

create_service() {

    local EXEC="$BIN -F"

    local PORT

    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT in "${PORT_ARRAY[@]}"; do
        EXEC="$EXEC -p $PORT"
    done

    EXEC="$EXEC -W 65536"

    if [[ -f "$BANNER_FILE" ]]; then
        EXEC="$EXEC -b $BANNER_FILE"
    fi

    info "Creando servicio systemd..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech Dropbear Multi-Port
Documentation=https://matt.ucc.asn.au/dropbear/dropbear.html
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$EXEC
Restart=always
RestartSec=3
KillMode=process
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE" >/dev/null 2>&1; then
        error_msg "No se pudo habilitar $SERVICE."
        return 1
    fi

    return 0
}

# ==============================================================
# INSTALAR DROPBEAR
# ==============================================================

install_dropbear() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 INSTALAR DROPBEAR${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                    ${GRAY}v$VERSION${RESET}                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Puertos:${RESET} ${CYAN}$PORTS${RESET}"
    echo

    if ! check_install_ports; then
        pause
        return 1
    fi

    if ! install_package; then
        pause
        return 1
    fi

    if ! generate_keys; then
        pause
        return 1
    fi

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    if ! create_service; then
        pause
        return 1
    fi

    info "Iniciando Dropbear..."

    systemctl restart "$SERVICE"

    sleep 1

    if service_active; then

        set_config "ON"
        set_ports_config "$PORTS"

        # Recargar variables
        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null

        echo
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${RESET}              ${BOLD}✔ DROPBEAR ACTIVADO${RESET}                    ${GREEN}║${RESET}"
        echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${GREEN}║${RESET}  Servicio : $SERVICE"
        echo -e "${GREEN}║${RESET}  Puertos  : $PORTS"
        echo -e "${GREEN}║${RESET}  Banner   : $BANNER_FILE"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

        return 0

    else

        set_config "OFF"

        echo
        error_msg "Dropbear no pudo iniciarse."

        echo
        info "Últimos registros del servicio:"
        journalctl -u "$SERVICE" -n 15 --no-pager 2>/dev/null

        return 1
    fi
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_dropbear() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}♻️ REINICIAR DROPBEAR${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! service_exists; then
        error_msg "El servicio $SERVICE no está instalado."
        pause
        return
    fi

    info "Reiniciando servicio..."

    systemctl restart "$SERVICE"

    sleep 1

    if service_active; then

        set_config "ON"

        ok "Dropbear está funcionando correctamente."

    else

        set_config "OFF"

        error_msg "Dropbear no pudo reiniciarse."

        echo
        journalctl -u "$SERVICE" -n 15 --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# ESTADO DETALLADO
# ==============================================================

status_dropbear() {

    clear

    local PORT
    local PORT_STATUS

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${MAGENTA}${BOLD}📊 DROPBEAR STATUS${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Estado:${RESET}       $(get_status)"
    echo -e "${WHITE}Servicio:${RESET}     ${CYAN}$SERVICE${RESET}"
    echo -e "${WHITE}Binario:${RESET}      ${CYAN}$BIN${RESET}"
    echo -e "${WHITE}Banner:${RESET}       ${CYAN}$BANNER_FILE${RESET}"
    echo -e "${WHITE}Configuración:${RESET} ${CYAN}${DROPBEAR:-OFF}${RESET}"

    line

    echo -e "${WHITE}Puertos:${RESET}"

    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT in "${PORT_ARRAY[@]}"; do
        printf "  ${GREEN}%-6s${RESET} %b\n" \
            "$PORT" \
            "$(port_listening "$PORT")"
    done

    line

    if service_exists; then

        echo -e "${WHITE}Estado systemd:${RESET}"
        systemctl is-active "$SERVICE" 2>/dev/null || true

        echo
        echo -e "${WHITE}Arranque automático:${RESET}"
        systemctl is-enabled "$SERVICE" 2>/dev/null || true

    else

        echo -e "${GRAY}El servicio personalizado no existe.${RESET}"

    fi

    echo
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

check_dropbear() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🔎 DIAGNÓSTICO DROPBEAR${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Componentes:${RESET}"
    echo

    # Binario
    if command -v dropbear >/dev/null 2>&1; then
        ok "Binario Dropbear encontrado"
    else
        error_msg "Binario Dropbear no encontrado"
    fi

    # Servicio
    if service_exists; then
        ok "Servicio personalizado encontrado"
    else
        error_msg "Servicio personalizado inexistente"
    fi

    # Servicio activo
    if service_active; then
        ok "Servicio activo"
    else
        error_msg "Servicio detenido"
    fi

    # RSA
    if [[ -f "$DROPBEAR_DIR/dropbear_rsa_host_key" ]]; then
        ok "Clave RSA encontrada"
    else
        error_msg "Clave RSA inexistente"
    fi

    # ECDSA
    if [[ -f "$DROPBEAR_DIR/dropbear_ecdsa_host_key" ]]; then
        ok "Clave ECDSA encontrada"
    else
        error_msg "Clave ECDSA inexistente"
    fi

    # Banner
    if [[ -f "$BANNER_FILE" ]]; then
        ok "Banner encontrado"
    else
        warning "Banner /etc/issue.net no encontrado"
    fi

    echo
    echo -e "${WHITE}Puertos:${RESET}"

    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT in "${PORT_ARRAY[@]}"; do

        if port_in_use "$PORT"; then
            ok "Puerto $PORT escuchando"
        else
            error_msg "Puerto $PORT no está escuchando"
        fi

    done

    echo
    echo -e "${WHITE}Procesos Dropbear:${RESET}"

    if pgrep -a dropbear 2>/dev/null; then
        :
    else
        echo -e "${GRAY}No se encontraron procesos.${RESET}"
    fi

    echo
    echo -e "${WHITE}Puertos detectados:${RESET}"

    ss -lntp 2>/dev/null |
        grep -E ':(90|109|143)([[:space:]]|$)' ||
        echo -e "${GRAY}No se detectaron puertos Dropbear.${RESET}"

    pause
}

# ==============================================================
# INFORMACIÓN DEL SERVIDOR
# ==============================================================

system_info() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}📊 INFORMACIÓN DEL SERVIDOR${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Hostname:${RESET}    ${GREEN}$(hostname)${RESET}"
    echo -e "${WHITE}Kernel:${RESET}      ${GREEN}$(uname -r)${RESET}"
    echo -e "${WHITE}Arquitectura:${RESET} ${GREEN}$(uname -m)${RESET}"

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo -e "${WHITE}Sistema:${RESET}     ${GREEN}${PRETTY_NAME}${RESET}"
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

remove_dropbear() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${RED}${BOLD}🗑️ DESINSTALAR DROPBEAR${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    warning "Esta operación eliminará Dropbear y su servicio personalizado."
    echo

    read -rp "$(echo -e "${RED}¿Continuar? [s/N]: ${RESET}")" CONFIRM

    if [[ ! "$CONFIRM" =~ ^[SsYy]$ ]]; then
        warning "Operación cancelada."
        sleep 1
        return
    fi

    echo

    info "Deteniendo servicio personalizado..."

    systemctl stop "$SERVICE" 2>/dev/null

    info "Deshabilitando servicio personalizado..."

    systemctl disable "$SERVICE" 2>/dev/null

    info "Eliminando servicio systemd..."

    rm -f "$SERVICE_FILE"

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE" 2>/dev/null

    info "Deteniendo servicio oficial de Dropbear..."

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    info "Desinstalando paquete..."

    if apt-get purge -y dropbear >/dev/null 2>&1; then
        ok "Paquete Dropbear eliminado."
    else
        warning "APT informó un problema al eliminar Dropbear."
    fi

    apt-get autoremove -y >/dev/null 2>&1

    info "Limpiando archivos..."

    rm -rf "$DROPBEAR_DIR"

    set_config "OFF"
    remove_ports_config

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}              ${BOLD}✔ DROPBEAR ELIMINADO${RESET}                   ${GREEN}║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}${BOLD}             🚀 INSTALACIÓN AUTOMÁTICA${RESET}"
    echo -e "${WHITE}                    DROPBEAR${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    if install_dropbear; then

        echo
        ok "Dropbear instalado correctamente."

        exit 0

    else

        echo
        error_msg "La instalación automática de Dropbear falló."

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

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🔐 DROPBEAR MANAGER${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                 ${GRAY}SSH GATEWAY v$VERSION${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Estado:${RESET}       $(get_status)"
    echo -e "${WHITE}Servicio:${RESET}     ${CYAN}$SERVICE${RESET}"
    echo -e "${WHITE}Puertos:${RESET}      ${GREEN}$PORTS${RESET}"
    echo -e "${WHITE}Configuración:${RESET} ${CYAN}${DROPBEAR:-OFF}${RESET}"

    line

    if service_exists || command -v dropbear >/dev/null 2>&1; then

        echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN DROPBEAR${RESET}"
        echo
        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🔄 Reinstalar / Actualizar"
        echo -e "  ${GREEN}${BOLD}[02]${RESET} ♻️  Reiniciar Servicio"
        echo -e "  ${GREEN}${BOLD}[03]${RESET} 📊 Estado Detallado"
        echo -e "  ${GREEN}${BOLD}[04]${RESET} 🔎 Diagnóstico"
        echo -e "  ${GREEN}${BOLD}[05]${RESET} 🖥️  Información del Servidor"
        echo -e "  ${GREEN}${BOLD}[06]${RESET} 🗑️  Desinstalar Dropbear"

    else

        echo -e "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"
        echo
        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar Dropbear"

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
            install_dropbear
            pause
            ;;

        2)
            restart_dropbear
            ;;

        3)
            status_dropbear
            ;;

        4)
            check_dropbear
            ;;

        5)
            system_info
            ;;

        6)
            remove_dropbear
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