#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                 UDP CUSTOM MANAGER v2.1
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SERVICE="udp-custom"
PORT="2100"

BIN="/usr/bin/udp"
UDP_CONFIG="/usr/bin/config.json"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"

VERSION="2.1"
AUTO_MODE="OFF"

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

if [[ "$EUID" -ne 0 ]]; then
    echo
    echo -e "${RED}${BOLD}✘ Este administrador requiere root.${RESET}"
    echo
    exit 1
fi

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then
    echo
    echo -e "${RED}${BOLD}✘ No existe la configuración KevinTech.${RESET}"
    echo -e "${WHITE}Archivo:${RESET} $CONFIG"
    echo
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null

# ==============================================================
# FUNCIONES VISUALES
# ==============================================================

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

header() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 UDP CUSTOM MANAGER${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                           ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
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

pause() {

    if [[ "$AUTO_MODE" == "ON" ]]; then
        return 0
    fi

    echo
    read -rp \
        "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

# ==============================================================
# CONFIG.CONF
# ==============================================================

set_config() {

    local KEY="$1"
    local VALUE="$2"

    [[ ! -f "$CONFIG" ]] && return 1

    if grep -qE "^${KEY}=" "$CONFIG"; then

        sed -i \
            "s|^${KEY}=.*|${KEY}=${VALUE}|" \
            "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi
}

# ==============================================================
# ESTADO REAL
# ==============================================================

udp_installed() {

    [[ -x "$BIN" &&
       -f "$SERVICE_FILE" &&
       -f "$UDP_CONFIG" ]]
}

udp_active() {

    systemctl is-active \
        --quiet "$SERVICE" 2>/dev/null
}

# ==============================================================
# ARQUITECTURA
# ==============================================================

get_udp_url() {

    local ARCH
    ARCH="$(uname -m)"

    case "$ARCH" in

        x86_64|amd64)
            echo "https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64"
            ;;

        aarch64|arm64)
            echo "https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm"
            ;;

        armv7l|armv7)
            echo "https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm"
            ;;

        *)
            return 1
            ;;

    esac
}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudo actualizar APT."
        return 1
    fi

    info "Instalando dependencias..."

    if ! apt-get install -y \
        curl \
        wget \
        ca-certificates \
        iptables \
        iproute2 \
        libpam0g \
        jq \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# IP FORWARD
# ==============================================================

enable_ip_forward() {

    info "Activando IPv4 Forward..."

    if ! sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1; then
        warning "No se pudo aplicar IPv4 Forward inmediatamente."
    fi

    if grep -qE "^[[:space:]]*net\.ipv4\.ip_forward=" /etc/sysctl.conf; then

        sed -i \
            's/^[[:space:]]*net\.ipv4\.ip_forward=.*/net.ipv4.ip_forward=1/' \
            /etc/sysctl.conf

    else

        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    fi

    ok "IPv4 Forward habilitado."
}

# ==============================================================
# COMPROBAR PUERTO
# ==============================================================

check_port() {

    if ss -H -lun 2>/dev/null |
        awk -v PORT=":$PORT" '$5 ~ PORT"$"' |
        grep -q .; then

        error_msg "El puerto UDP $PORT ya está ocupado."

        ss -ulnp 2>/dev/null |
            grep -E ":${PORT}([[:space:]]|$)" || true

        return 1
    fi

    return 0
}

# ==============================================================
# DESCARGAR BINARIO
# ==============================================================

download_udp() {

    local URL
    local TMP

    URL="$(get_udp_url)"

    if [[ -z "$URL" ]]; then

        error_msg \
            "Arquitectura no compatible: $(uname -m)"

        return 1
    fi

    info "Arquitectura: $(uname -m)"
    info "Descargando UDP Custom..."

    TMP="$(mktemp)"

    if ! curl \
        -fL \
        --connect-timeout 15 \
        --max-time 120 \
        --retry 3 \
        --retry-delay 2 \
        "$URL" \
        -o "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo descargar UDP Custom."

        return 1
    fi

    if [[ ! -s "$TMP" ]]; then

        rm -f "$TMP"

        error_msg "El archivo descargado está vacío."

        return 1
    fi

    if ! install -m 755 "$TMP" "$BIN"; then

        rm -f "$TMP"

        error_msg "No se pudo instalar el binario."

        return 1
    fi

    rm -f "$TMP"

    if [[ ! -x "$BIN" ]]; then

        error_msg "El binario no quedó ejecutable."

        return 1
    fi

    ok "Binario UDP instalado."

    return 0
}

# ==============================================================
# CONFIGURACIÓN UDP
# ==============================================================

create_udp_config() {

    info "Creando configuración UDP..."

    cat > "$UDP_CONFIG" <<EOF
{
    "listen": ":$PORT",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
EOF

    chmod 600 "$UDP_CONFIG"

    if ! jq empty "$UDP_CONFIG" >/dev/null 2>&1; then

        error_msg "config.json contiene errores."

        return 1
    fi

    ok "Configuración creada."

    return 0
}

# ==============================================================
# SERVICIO SYSTEMD
# ==============================================================

create_udp_service() {

    info "Creando servicio systemd..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech UDP Custom Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=$BIN server -exclude 2200,7300,7200,7100,323,10008,10004 $UDP_CONFIG
Restart=always
RestartSec=3
StartLimitIntervalSec=0
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    if ! systemctl daemon-reload; then
        error_msg "No se pudo recargar systemd."
        return 1
    fi

    systemctl enable "$SERVICE" >/dev/null 2>&1

    ok "Servicio systemd creado."

    return 0
}

# ==============================================================
# BACKUP
# ==============================================================

backup_udp_config() {

    [[ ! -f "$UDP_CONFIG" ]] && return 0

    local BACKUP_DIR="$BASE/backups/udp"
    local FILE

    mkdir -p "$BACKUP_DIR"

    FILE="$BACKUP_DIR/config-$(date '+%Y%m%d-%H%M%S').json"

    if cp -f "$UDP_CONFIG" "$FILE"; then

        chmod 600 "$FILE"

        echo "$FILE"

    fi
}

# ==============================================================
# INSTALAR UDP
# ==============================================================

install_udp() {

    if [[ "$AUTO_MODE" != "ON" ]]; then
        header
    fi

    echo -e \
        "${WHITE}${BOLD}              🚀 INSTALACIÓN UDP CUSTOM${RESET}"

    line
    echo

    install_dependencies || {
        pause
        return 1
    }

    enable_ip_forward

    echo

    check_port || {
        pause
        return 1
    }

    echo

    download_udp || {
        pause
        return 1
    }

    create_udp_config || {
        pause
        return 1
    }

    create_udp_service || {
        pause
        return 1
    }

    echo

    info "Iniciando UDP Custom..."

    systemctl restart "$SERVICE"

    sleep 2

    if udp_active; then

        set_config "UDP_CUSTOM" "ON"

        echo

        ok "UDP Custom instalado correctamente."

        echo
        echo -e "${WHITE}Puerto   :${RESET} ${GREEN}$PORT/UDP${RESET}"
        echo -e "${WHITE}Servicio :${RESET} ${GREEN}$SERVICE${RESET}"
        echo -e "${WHITE}Binario  :${RESET} ${GRAY}$BIN${RESET}"

        pause

        return 0

    fi

    set_config "UDP_CUSTOM" "OFF"

    echo

    error_msg "UDP Custom no pudo iniciar."

    echo

    journalctl \
        -u "$SERVICE" \
        -n 25 \
        --no-pager 2>/dev/null

    pause

    return 1
}

# ==============================================================
# REINSTALAR
# ==============================================================

reinstall_udp() {

    header

    echo -e \
        "${WHITE}${BOLD}             🔄 REINSTALAR UDP CUSTOM${RESET}"

    line
    echo

    warning "El binario será reemplazado."

    if [[ -f "$UDP_CONFIG" ]]; then

        local BACKUP
        BACKUP="$(backup_udp_config)"

        if [[ -n "$BACKUP" ]]; then
            ok "Backup creado:"
            echo -e "  ${GRAY}$BACKUP${RESET}"
        fi

    fi

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Continuar? [s/N]: ${RESET}")" \
        CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then

        warning "Operación cancelada."

        sleep 1

        return
    fi

    systemctl stop "$SERVICE" 2>/dev/null

    install_dependencies || {
        pause
        return 1
    }

    enable_ip_forward

    download_udp || {
        pause
        return 1
    }

    create_udp_config || {
        pause
        return 1
    }

    create_udp_service || {
        pause
        return 1
    }

    systemctl restart "$SERVICE"

    sleep 2

    if udp_active; then

        set_config "UDP_CUSTOM" "ON"

        ok "UDP Custom reinstalado correctamente."

    else

        set_config "UDP_CUSTOM" "OFF"

        error_msg "UDP Custom no pudo iniciar."

        journalctl \
            -u "$SERVICE" \
            -n 25 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_udp() {

    header

    echo -e \
        "${WHITE}${BOLD}                  ♻️ REINICIAR UDP${RESET}"

    line
    echo

    if ! udp_installed; then

        error_msg "UDP Custom no está instalado."

        pause

        return
    fi

    info "Reiniciando servicio..."

    systemctl restart "$SERVICE"

    sleep 2

    if udp_active; then

        set_config "UDP_CUSTOM" "ON"

        ok "UDP Custom reiniciado correctamente."

    else

        set_config "UDP_CUSTOM" "OFF"

        error_msg "UDP Custom no pudo iniciar."

        echo

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# PUERTO
# ==============================================================

udp_port_status() {

    if ss -H -lun 2>/dev/null |
        awk -v P=":$PORT" '$5 ~ P"$"' |
        grep -q .; then

        echo -e "${GREEN}🟢 ESCUCHANDO${RESET}"

    else

        echo -e "${RED}🔴 CERRADO${RESET}"

    fi
}

# ==============================================================
# ESTADO
# ==============================================================

status_udp() {

    header

    echo -e \
        "${WHITE}${BOLD}                📊 ESTADO UDP CUSTOM${RESET}"

    line
    echo

    local STATUS

    if udp_active; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    elif udp_installed; then
        STATUS="${RED}🔴 DETENIDO${RESET}"

    else
        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"
    fi

    echo -e "${WHITE}Estado        :${RESET} $STATUS"
    echo -e "${WHITE}Servicio      :${RESET} ${GREEN}$SERVICE${RESET}"
    echo -e "${WHITE}Puerto        :${RESET} ${GREEN}$PORT/UDP${RESET}"
    echo -e "${WHITE}Binario       :${RESET} ${GRAY}$BIN${RESET}"
    echo -e "${WHITE}Configuración :${RESET} ${GRAY}$UDP_CONFIG${RESET}"
    echo -e "${WHITE}Socket        :${RESET} $(udp_port_status)"

    echo

    if [[ -f "$SERVICE_FILE" ]]; then
        ok "Servicio systemd encontrado."
    else
        error_msg "Servicio systemd inexistente."
    fi

    if [[ -x "$BIN" ]]; then
        ok "Binario encontrado."
    else
        error_msg "Binario inexistente."
    fi

    if [[ -f "$UDP_CONFIG" ]]; then
        ok "Configuración encontrada."
    else
        error_msg "Configuración inexistente."
    fi

    echo
    info "Escuchando UDP:"

    ss -ulnp 2>/dev/null |
        grep -E ":${PORT}([[:space:]]|$)" ||
        echo "No se encontraron conexiones."

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostic_udp() {

    header

    echo -e \
        "${WHITE}${BOLD}                 🔎 DIAGNÓSTICO UDP${RESET}"

    line
    echo

    [[ -x "$BIN" ]] \
        && ok "Binario instalado" \
        || error_msg "Binario no instalado"

    [[ -f "$UDP_CONFIG" ]] \
        && ok "config.json encontrado" \
        || error_msg "config.json no encontrado"

    [[ -f "$SERVICE_FILE" ]] \
        && ok "Servicio systemd encontrado" \
        || error_msg "Servicio systemd inexistente"

    udp_active \
        && ok "Servicio activo" \
        || error_msg "Servicio detenido"

    if [[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" == "1" ]]; then
        ok "IPv4 Forward activo"
    else
        error_msg "IPv4 Forward desactivado"
    fi

    echo

    echo -e "${WHITE}Puerto UDP $PORT:${RESET}"

    ss -ulnp 2>/dev/null |
        grep -E ":${PORT}([[:space:]]|$)" ||
        echo "No está escuchando."

    echo

    echo -e "${WHITE}Últimos registros:${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 20 \
        --no-pager 2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

show_udp_logs() {

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}              ${MAGENTA}${BOLD}📜 UDP CUSTOM LOGS${RESET}                    ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    journalctl \
        -u "$SERVICE" \
        -n 40 \
        --no-pager 2>/dev/null

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_udp() {

    header

    echo -e \
        "${RED}${BOLD}                 🗑️ DESINSTALAR UDP${RESET}"

    line
    echo

    warning "Se eliminará UDP Custom."
    warning "Se eliminarán el binario y la configuración."

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        sleep 1

        return
    fi

    echo

    if [[ -f "$UDP_CONFIG" ]]; then

        local BACKUP
        BACKUP="$(backup_udp_config)"

        if [[ -n "$BACKUP" ]]; then
            ok "Backup creado:"
            echo -e "  ${GRAY}$BACKUP${RESET}"
        fi

    fi

    info "Deteniendo servicio..."

    systemctl stop "$SERVICE" 2>/dev/null
    systemctl disable "$SERVICE" 2>/dev/null

    info "Eliminando servicio..."

    rm -f "$SERVICE_FILE"

    info "Eliminando archivos..."

    rm -f "$BIN"
    rm -f "$UDP_CONFIG"

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE" 2>/dev/null

    info "Limpiando reglas relacionadas con $PORT..."

    while read -r RULE; do

        [[ -z "$RULE" ]] && continue

        iptables \
            -t nat \
            $RULE \
            2>/dev/null

    done < <(
        iptables -t nat -S 2>/dev/null |
        grep -E -- "--dport $PORT|--dports .*${PORT}" |
        sed 's/^-A/-D/'
    )

    while read -r RULE; do

        [[ -z "$RULE" ]] && continue

        iptables \
            $RULE \
            2>/dev/null

    done < <(
        iptables -S 2>/dev/null |
        grep -E -- "--dport $PORT|--dports .*${PORT}" |
        sed 's/^-A/-D/'
    )

    set_config "UDP_CUSTOM" "OFF"

    # Compatibilidad con versiones antiguas
    sed -i '/^UDPCUSTOM=/d' "$CONFIG"

    echo

    ok "UDP Custom eliminado correctamente."

    pause
}

# ==============================================================
# INFORMACIÓN VPS
# ==============================================================

server_info() {

    header

    echo -e \
        "${WHITE}${BOLD}             🖥️ INFORMACIÓN DEL SERVIDOR${RESET}"

    line
    echo

    echo -e "${WHITE}Hostname:${RESET} $(hostname)"
    echo -e "${WHITE}Arquitectura:${RESET} $(uname -m)"
    echo -e "${WHITE}Kernel:${RESET} $(uname -r)"
    echo -e "${WHITE}IPv4:${RESET} $(hostname -I 2>/dev/null)"

    echo
    echo -e "${WHITE}Memoria:${RESET}"
    free -h

    echo
    echo -e "${WHITE}Disco:${RESET}"
    df -h /

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    AUTO_MODE="ON"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}${BOLD}              🚀 INSTALACIÓN AUTOMÁTICA${RESET}"
    echo -e "${WHITE}                    UDP CUSTOM${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    if install_udp; then

        if udp_active; then

            echo
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${GREEN}✔ UDP Custom instalado correctamente.${RESET}"
            echo -e "${GREEN}✔ Servicio: $SERVICE${RESET}"
            echo -e "${GREEN}✔ Puerto: $PORT/UDP${RESET}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo

            exit 0
        fi
    fi

    echo
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${RED}✘ Error instalando UDP Custom.${RESET}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    journalctl \
        -u "$SERVICE" \
        -n 30 \
        --no-pager 2>/dev/null

    exit 1
fi

# ==============================================================
# MENÚ
# ==============================================================

udp_menu() {

    while true; do

        source "$CONFIG" 2>/dev/null

        clear

        local STATUS

        if udp_active; then

            STATUS="${GREEN}🟢 ACTIVO${RESET}"

        elif udp_installed; then

            STATUS="${RED}🔴 DETENIDO${RESET}"

        else

            STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

        fi

        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 UDP CUSTOM MANAGER${RESET}                    ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                           ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e "${WHITE}Estado:${RESET}         $STATUS"
        echo -e "${WHITE}Servicio:${RESET}       ${GREEN}$SERVICE${RESET}"
        echo -e "${WHITE}Puerto:${RESET}         ${GREEN}$PORT/UDP${RESET}"
        echo -e "${WHITE}IPv4 Forward:${RESET}   $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"

        echo

        if udp_installed; then

            echo -e "${BLUE}${BOLD}⚙️ ADMINISTRACIÓN${RESET}"
            echo

            echo -e " ${GREEN}[01]${RESET} 🔄 Reinstalar UDP Custom"
            echo -e " ${GREEN}[02]${RESET} ♻️  Reiniciar Servicio"
            echo -e " ${GREEN}[03]${RESET} 📊 Estado"
            echo -e " ${GREEN}[04]${RESET} 🔎 Diagnóstico"
            echo -e " ${GREEN}[05]${RESET} 📜 Ver Logs"
            echo -e " ${GREEN}[06]${RESET} 🖥️ Información VPS"
            echo -e " ${RED}[07]${RESET} 🗑️  Desinstalar"

        else

            echo -e "${BLUE}${BOLD}🚀 INSTALACIÓN${RESET}"
            echo

            echo -e " ${GREEN}[01]${RESET} 🚀 Instalar UDP Custom"
            echo -e " ${GREEN}[02]${RESET} 🔎 Diagnóstico"
            echo -e " ${GREEN}[03]${RESET} 🖥️ Información VPS"

        fi

        echo
        echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
        echo -e " ${RED}${BOLD}[00]${RESET} ↩️ Regresar"

        echo
        echo -e "${GRAY}KevinTech Multi Script • Privanox VPN • v$VERSION${RESET}"

        echo

        read -rp \
            "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)

                if udp_installed; then
                    reinstall_udp
                else
                    install_udp
                fi
                ;;

            2)

                if udp_installed; then
                    restart_udp
                else
                    diagnostic_udp
                fi
                ;;

            3)

                if udp_installed; then
                    status_udp
                else
                    server_info
                fi
                ;;

            4)

                if udp_installed; then
                    diagnostic_udp
                else
                    diagnostic_udp
                fi
                ;;

            5)

                if udp_installed; then
                    show_udp_logs
                else
                    error_msg "UDP Custom no está instalado."
                    sleep 1
                fi
                ;;

            6)

                if udp_installed; then
                    server_info
                else
                    server_info
                fi
                ;;

            7)

                if udp_installed; then
                    remove_udp
                else
                    error_msg "UDP Custom no está instalado."
                    sleep 1
                fi
                ;;

            0)

                if [[ -f "$BASE/protocolos/menu.sh" ]]; then

                    clear

                    exec bash \
                        "$BASE/protocolos/menu.sh"

                else

                    error_msg "Menú de protocolos no encontrado."

                    sleep 2

                    exit 1
                fi
                ;;

            "")

                ;;

            *)

                error_msg "Opción inválida."

                sleep 1
                ;;

        esac

    done
}

# ==============================================================
# INICIO
# ==============================================================

udp_menu