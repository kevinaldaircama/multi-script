#!/bin/bash
#=========================================================
# KEVINTECH MULTI SCRIPT
# UDP CUSTOM MANAGER
# Version: 2.3 Premium
#=========================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SERVICE="udp-custom"
PORT="2100"
BIN="/usr/bin/udp"
CONFIG_UDP="/usr/bin/config.json"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"

#=========================================================
# COLORES
#=========================================================

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
PURPLE="\e[1;95m"
RESET="\e[0m"
BOLD="\e[1m"

#=========================================================
# CARGAR CONFIG
#=========================================================

if [[ ! -f "$CONFIG" ]]; then
    echo -e "${RED}✘ No existe $CONFIG${RESET}"
    exit 1
fi

source "$CONFIG"

#=========================================================
# FUNCIONES VISUALES
#=========================================================

banner() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${WHITE}${BOLD}⚡ UDP CUSTOM MANAGER ⚡${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                  ${GRAY}KevinTech Premium${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

ok() {
    echo -e " ${GREEN}✔${RESET} $1"
}

error() {
    echo -e " ${RED}✘${RESET} $1"
}

info() {
    echo -e " ${CYAN}➜${RESET} $1"
}

warn() {
    echo -e " ${YELLOW}⚠${RESET} $1"
}

#=========================================================
# ESTADO
#=========================================================

udp_instalado() {

    [[ "$UDP_CUSTOM" == "ON" ]] &&
    [[ -f "$SERVICE_FILE" ]] &&
    systemctl is-active --quiet "$SERVICE"

}

set_udp_status() {

    if udp_instalado; then
        STATUS="${GREEN}● ACTIVO${RESET}"
    else
        STATUS="${RED}● INACTIVO${RESET}"
    fi

}

#=========================================================
# PUERTO
#=========================================================

puerto_udp() {

    ss -lntup 2>/dev/null |
        grep -E "[:.]${PORT}[[:space:]]" |
        grep -E "udp|tcp" |
        head -1

}

#=========================================================
# CONFIGURAR IP FORWARD
#=========================================================

configurar_forward() {

    info "Activando IPv4 Forward..."

    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1

    if grep -qE '^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=' /etc/sysctl.conf; then

        sed -i \
            's/^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=.*/net.ipv4.ip_forward=1/' \
            /etc/sysctl.conf

    else

        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    fi

}

#=========================================================
# CONFIGURAR REPOSITORIOS / DEPENDENCIAS
#=========================================================

instalar_dependencias() {

    info "Instalando dependencias..."

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y >/dev/null 2>&1

    apt-get install -y \
        curl \
        wget \
        iptables \
        libpam0g \
        ca-certificates \
        >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        error "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."

}

#=========================================================
# DESCARGAR BINARIO
#=========================================================

descargar_binario() {

    local ARCH
    local URL

    ARCH=$(uname -m)

    case "$ARCH" in

        x86_64)
            URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64"
            ;;

        aarch64|arm64)
            URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm"
            ;;

        *)
            error "Arquitectura no soportada: $ARCH"
            return 1
            ;;

    esac

    info "Arquitectura: ${WHITE}${ARCH}${RESET}"
    info "Descargando UDP Custom..."

    local TMP_FILE="/tmp/udp-custom"

    rm -f "$TMP_FILE"

    if ! curl -L --fail --silent --show-error \
        "$URL" \
        -o "$TMP_FILE"; then

        error "No se pudo descargar UDP Custom."
        rm -f "$TMP_FILE"
        return 1

    fi

    if [[ ! -s "$TMP_FILE" ]]; then

        error "El archivo descargado está vacío."
        rm -f "$TMP_FILE"
        return 1

    fi

    mv -f "$TMP_FILE" "$BIN"
    chmod 755 "$BIN"

    if [[ ! -x "$BIN" ]]; then
        error "No se pudo preparar el binario."
        return 1
    fi

    ok "Binario instalado en ${WHITE}${BIN}${RESET}"

}

#=========================================================
# CONFIGURACIÓN UDP
#=========================================================

crear_configuracion() {

    info "Creando configuración..."

    cat > "$CONFIG_UDP" <<EOF
{
    "listen": ":${PORT}",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
EOF

    chmod 644 "$CONFIG_UDP"

    if [[ ! -s "$CONFIG_UDP" ]]; then
        error "No se pudo crear $CONFIG_UDP"
        return 1
    fi

    ok "Configuración creada."

}

#=========================================================
# CREAR SYSTEMD
#=========================================================

crear_servicio() {

    info "Creando servicio systemd..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech UDP Custom Server
Documentation=https://github.com/Depwisescript/UDP
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/udp server -exclude 2200,7300,7200,7100,323,10008,10004 /usr/bin/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    ok "Servicio systemd configurado."

}

#=========================================================
# GUARDAR ESTADO
#=========================================================

activar_config() {

    touch "$CONFIG"

    sed -i '/^UDP_CUSTOM=/d' "$CONFIG"

    echo "UDP_CUSTOM=ON" >> "$CONFIG"

}

desactivar_config() {

    touch "$CONFIG"

    sed -i '/^UDP_CUSTOM=/d' "$CONFIG"

    echo "UDP_CUSTOM=OFF" >> "$CONFIG"

}

#=========================================================
# INSTALAR UDP CUSTOM
#=========================================================

install_udp() {

    banner

    echo -e "${WHITE}${BOLD}🚀 INSTALACIÓN DE UDP CUSTOM${RESET}"
    line
    echo

    if udp_instalado; then

        ok "UDP Custom ya está instalado y activo."
        echo
        echo -e " ${WHITE}Puerto : ${GREEN}${PORT}${RESET}"
        echo
        read -r -p "Presiona ENTER para continuar..."
        return 0

    fi

    instalar_dependencias || return 1

    echo

    configurar_forward || return 1

    echo

    descargar_binario || return 1

    echo

    crear_configuracion || return 1

    echo

    crear_servicio || return 1

    echo

    info "Iniciando UDP Custom..."

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        activar_config

        echo
        line
        echo -e "${GREEN}${BOLD}              ✔ UDP CUSTOM INSTALADO${RESET}"
        line
        echo
        echo -e " ${WHITE}Estado : ${GREEN}● ACTIVO${RESET}"
        echo -e " ${WHITE}Puerto : ${GREEN}${PORT}${RESET}"
        echo -e " ${WHITE}IPv4   : ${GREEN}0.0.0.0${RESET}"
        echo

        if puerto_udp >/dev/null 2>&1; then
            ok "Puerto ${PORT} detectado."
        else
            warn "El servicio está activo, pero no se pudo detectar el puerto."
        fi

        echo
        line

        if [[ "${AUTO_MODE:-NO}" != "SI" ]]; then
            echo
            read -r -p "Presiona ENTER para continuar..."
        fi

        return 0

    fi

    error "UDP Custom no pudo iniciar."

    echo
    journalctl -u "$SERVICE" --no-pager -n 25

    desactivar_config

    return 1

}

#=========================================================
# DESINSTALAR
#=========================================================

remove_udp() {

    banner

    echo -e "${WHITE}${BOLD}🗑️ DESINSTALAR UDP CUSTOM${RESET}"
    line
    echo

    if [[ "${AUTO_MODE:-NO}" != "SI" ]]; then

        read -r -p "¿Eliminar UDP Custom? (s/n): " CONFIRM

        if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
            warn "Operación cancelada."
            sleep 2
            return 0
        fi

    fi

    info "Deteniendo servicio..."

    systemctl stop "$SERVICE" >/dev/null 2>&1
    systemctl disable "$SERVICE" >/dev/null 2>&1

    info "Eliminando archivos..."

    rm -f "$SERVICE_FILE"
    rm -f "$BIN"
    rm -f "$CONFIG_UDP"

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE" >/dev/null 2>&1

    # Limpiar reglas relacionadas con el puerto
    while read -r RULE; do
        [[ -n "$RULE" ]] && iptables $RULE >/dev/null 2>&1
    done < <(
        iptables -S INPUT 2>/dev/null |
        grep -E "(-p udp|-p tcp).*--dport ${PORT}" |
        sed 's/^-A/-D/'
    )

    while read -r RULE; do
        [[ -n "$RULE" ]] && iptables -t nat $RULE >/dev/null 2>&1
    done < <(
        iptables -t nat -S PREROUTING 2>/dev/null |
        grep "$PORT" |
        sed 's/^-A/-D/'
    )

    desactivar_config

    echo
    line
    echo -e "${GREEN}${BOLD}              ✔ UDP CUSTOM ELIMINADO${RESET}"
    line
    echo

    if [[ "${AUTO_MODE:-NO}" != "SI" ]]; then
        read -r -p "Presiona ENTER para continuar..."
    fi

}

#=========================================================
# REINICIAR
#=========================================================

restart_udp() {

    banner

    echo -e "${WHITE}${BOLD}🔄 REINICIAR UDP CUSTOM${RESET}"
    line
    echo

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        ok "UDP Custom reiniciado correctamente."

    else

        error "UDP Custom no pudo iniciar."

        echo
        journalctl -u "$SERVICE" --no-pager -n 20

    fi

    echo

    if [[ "${AUTO_MODE:-NO}" != "SI" ]]; then
        read -r -p "Presiona ENTER para continuar..."
    fi

}

#=========================================================
# ESTADO
#=========================================================

status_udp() {

    banner

    echo -e "${WHITE}${BOLD}📊 ESTADO DE UDP CUSTOM${RESET}"
    line
    echo

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e " ${WHITE}Estado       : ${GREEN}● ACTIVO${RESET}"
    else
        echo -e " ${WHITE}Estado       : ${RED}● DETENIDO${RESET}"
    fi

    echo -e " ${WHITE}Servicio     : ${GREEN}${SERVICE}${RESET}"
    echo -e " ${WHITE}Puerto       : ${GREEN}${PORT}${RESET}"
    echo -e " ${WHITE}Configuración: ${GREEN}${CONFIG_UDP}${RESET}"

    echo
    line
    echo -e "${WHITE}${BOLD}🔌 ESCUCHANDO${RESET}"
    line
    echo

    if puerto_udp; then
        echo
    else
        warn "No se detectó el puerto ${PORT}."
    fi

    echo
    line
    echo

    systemctl status "$SERVICE" --no-pager -l

    echo

    read -r -p "Presiona ENTER para continuar..."

}

#=========================================================
# MODO AUTOMÁTICO
#=========================================================

AUTO_MODE="NO"

if [[ "${1:-}" == "--auto" ]]; then

    AUTO_MODE="SI"

    source "$CONFIG" 2>/dev/null

    if udp_instalado; then
        exit 0
    fi

    install_udp

    exit $?

fi

#=========================================================
# MENÚ
#=========================================================

while true; do

    source "$CONFIG" 2>/dev/null

    set_udp_status

    banner

    echo -e " ${WHITE}Estado   :${RESET} $STATUS"
    echo -e " ${WHITE}Puerto   :${RESET} ${GREEN}${PORT}${RESET}"
    echo -e " ${WHITE}Servicio :${RESET} ${GREEN}${SERVICE}${RESET}"

    echo
    line
    echo

    if udp_instalado; then

        echo -e " ${GREEN}[1]${RESET} ➮ Reiniciar UDP Custom"
        echo -e " ${GREEN}[2]${RESET} ➮ Ver Estado"
        echo -e " ${GREEN}[3]${RESET} ➮ Desinstalar UDP Custom"

    else

        echo -e " ${GREEN}[1]${RESET} ➮ Instalar UDP Custom"
        echo -e " ${GREEN}[2]${RESET} ➮ Ver Estado"

    fi

    echo
    echo -e " ${RED}[0]${RESET} ➮ Regresar"

    echo
    line
    echo

    read -r -p " ${CYAN}➜${RESET} Selecciona una opción: " OP

    case "$OP" in

        1)

            if udp_instalado; then
                restart_udp
            else
                install_udp
            fi

            ;;

        2)
            status_udp
            ;;

        3)

            if udp_instalado; then
                remove_udp
            else
                warn "UDP Custom no está instalado."
                sleep 2
            fi

            ;;

        0)
            clear
            exit 0
            ;;

        *)
            error "Opción inválida."
            sleep 2
            ;;

    esac

done
