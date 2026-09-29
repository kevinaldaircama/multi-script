#!/bin/bash

# ==============================================================
#                 🔥 KEVINTECH HCR 🔥
#              HCR SERVER - PROTOCOLO
# ==============================================================
#
# HCR funciona como entrada independiente hacia SSH.
#
# Puerto externo : ALEATORIO
# Backend        : 127.0.0.1:22
#
# Los usuarios y contraseñas son los mismos usuarios
# creados por KEVINTECH / usuarios/add.sh.
#
# NO crea una base de usuarios independiente.
#
# ==============================================================

set -uo pipefail

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

HCR_DIR="/opt/hcr"
HCR_BIN="$HCR_DIR/hcr-server"
HCR_UNIT="hcr-server.service"

HCR_PORT=""
HCR_BACKEND_HOST="127.0.0.1"
HCR_BACKEND_PORT="22"

HCR_URL_BASE="https://raw.githubusercontent.com/JotchuaDevz/BHTTP-LIBS/refs/heads/main"

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
# INTERFAZ
# ==============================================================

line() {
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

header() {
    clear

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}${BOLD}                    🔥 KEVINTECH HCR 🔥                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${GRAY}                  HCR SERVER PROTOCOL                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

ok() {
    echo -e "${GREEN}✔ $*${RESET}"
}

err() {
    echo -e "${RED}✘ $*${RESET}"
}

info() {
    echo -e "${CYAN}➜ $*${RESET}"
}

warn() {
    echo -e "${YELLOW}⚠ $*${RESET}"
}

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

load_config() {

    HCR_PORT=""

    if [[ -f "$CONFIG" ]]; then

        set +u

        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null || true

        set -u

    fi

    HCR_PORT="${HCR_PORT:-}"
}

set_config() {

    local KEY="$1"
    local VALUE="$2"

    mkdir -p "$BASE"

    touch "$CONFIG"

    if grep -qE "^${KEY}=" "$CONFIG"; then

        sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi
}

remove_config() {

    local KEY="$1"

    [[ -f "$CONFIG" ]] || return 0

    sed -i "/^${KEY}=/d" "$CONFIG"
}

# ==============================================================
# COMPROBAR PUERTO
# ==============================================================

port_in_use() {

    local PORT="$1"

    if command -v ss >/dev/null 2>&1; then

        ss -H -ltn 2>/dev/null |
            awk '{print $4}' |
            grep -Eq "(:|\.)${PORT}$"

        return $?

    fi

    if command -v lsof >/dev/null 2>&1; then

        lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1

        return $?

    fi

    return 1
}

# ==============================================================
# PUERTO ALEATORIO
# ==============================================================

generate_random_port() {

    local PORT
    local ATTEMPTS=0

    while true; do

        ATTEMPTS=$((ATTEMPTS + 1))

        if (( ATTEMPTS > 100 )); then

            err "No se pudo encontrar un puerto libre."

            return 1
        fi

        # Rango alto para reducir posibilidades de conflicto
        PORT=$((RANDOM % 50000 + 10000))

        # Evitar puertos conocidos del sistema
        case "$PORT" in
            10022|1080|3128|8080|8088|8443|8888|10000)
                continue
                ;;
        esac

        if ! port_in_use "$PORT"; then

            HCR_PORT="$PORT"

            return 0

        fi

    done
}

# ==============================================================
# VALIDAR PUERTO GUARDADO
# ==============================================================

validate_saved_port() {

    load_config

    if [[ ! "$HCR_PORT" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if (( HCR_PORT < 1024 || HCR_PORT > 65535 )); then
        return 1
    fi

    # Si HCR está activo, su propio puerto puede aparecer ocupado.
    if systemctl is-active --quiet "$HCR_UNIT" 2>/dev/null; then
        return 0
    fi

    if port_in_use "$HCR_PORT"; then
        return 1
    fi

    return 0
}

# ==============================================================
# ASIGNAR PUERTO
# ==============================================================

assign_port() {

    load_config

    if validate_saved_port; then

        info "Usando puerto HCR existente: $HCR_PORT"

        return 0
    fi

    info "Buscando puerto aleatorio libre..."

    generate_random_port || return 1

    set_config "HCR_PORT" "$HCR_PORT"

    ok "Puerto HCR asignado: $HCR_PORT"

    return 0
}

# ==============================================================
# ARQUITECTURA
# ==============================================================

detect_arch() {

    case "$(uname -m)" in

        x86_64|amd64)
            HCR_ARCH="amd64"
            ;;

        aarch64|arm64)
            HCR_ARCH="arm64"
            ;;

        *)
            err "Arquitectura no soportada: $(uname -m)"
            return 1
            ;;

    esac

    HCR_FILENAME="hcr-server-linux-${HCR_ARCH}"
    HCR_URL="${HCR_URL_BASE}/${HCR_FILENAME}"

    return 0
}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    local NEED=()

    command -v curl >/dev/null 2>&1 || NEED+=("curl")
    command -v wget >/dev/null 2>&1 || NEED+=("wget")
    command -v ss >/dev/null 2>&1 || NEED+=("iproute2")
    command -v systemctl >/dev/null 2>&1 || NEED+=("systemd")

    if (( ${#NEED[@]} == 0 )); then
        ok "Dependencias disponibles."
        return 0
    fi

    info "Instalando dependencias: ${NEED[*]}"

    apt-get update -qq >/dev/null 2>&1 || {
        err "No se pudo actualizar APT."
        return 1
    }

    apt-get install -y \
        curl \
        wget \
        iproute2 \
        systemd \
        >/dev/null 2>&1 || {

        err "No se pudieron instalar las dependencias."

        return 1
    }

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# DESCARGAR HCR
# ==============================================================

download_hcr() {

    detect_arch || return 1

    mkdir -p "$HCR_DIR"

    info "Arquitectura detectada: $HCR_ARCH"
    info "Descargando HCR..."

    local TMP="/tmp/hcr-server-download"

    rm -f "$TMP"

    if command -v curl >/dev/null 2>&1; then

        if ! curl -fL \
            --connect-timeout 15 \
            --max-time 300 \
            --retry 2 \
            -o "$TMP" \
            "$HCR_URL"; then

            err "No se pudo descargar HCR."

            rm -f "$TMP"

            return 1
        fi

    else

        if ! wget \
            -q \
            --timeout=30 \
            --tries=3 \
            -O "$TMP" \
            "$HCR_URL"; then

            err "No se pudo descargar HCR."

            rm -f "$TMP"

            return 1
        fi

    fi

    if [[ ! -s "$TMP" ]]; then

        err "El archivo HCR descargado está vacío."

        rm -f "$TMP"

        return 1
    fi

    mv -f "$TMP" "$HCR_BIN"

    chmod 755 "$HCR_BIN"

    if [[ ! -x "$HCR_BIN" ]]; then

        err "El binario HCR no es ejecutable."

        return 1
    fi

    ok "HCR descargado correctamente."

    return 0
}

# ==============================================================
# CREAR SERVICIO
# ==============================================================

create_service() {

    load_config

    if [[ -z "$HCR_PORT" ]]; then

        err "No se ha definido el puerto HCR."

        return 1
    fi

    info "Creando servicio independiente HCR..."

    cat > "/etc/systemd/system/$HCR_UNIT" <<EOF
[Unit]
Description=KevinTech HCR Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$HCR_DIR

ExecStart=$HCR_BIN --listen :$HCR_PORT --target $HCR_BACKEND_HOST:$HCR_BACKEND_PORT --transport plain

Restart=always
RestartSec=3

KillMode=mixed
TimeoutStopSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=kevintech-hcr

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "/etc/systemd/system/$HCR_UNIT"

    systemctl daemon-reload

    systemctl enable "$HCR_UNIT" >/dev/null 2>&1

    ok "Servicio HCR creado."

    return 0
}

# ==============================================================
# FIREWALL
# ==============================================================

open_firewall() {

    load_config

    if ! command -v iptables >/dev/null 2>&1; then
        warn "iptables no está disponible. Se omite firewall."
        return 0
    fi

    iptables -C INPUT \
        -p tcp \
        --dport "$HCR_PORT" \
        -j ACCEPT \
        2>/dev/null ||

    iptables -I INPUT \
        -p tcp \
        --dport "$HCR_PORT" \
        -j ACCEPT \
        2>/dev/null || true

    ok "Puerto TCP $HCR_PORT permitido."
}

# ==============================================================
# FIREWALL - ELIMINAR
# ==============================================================

close_firewall() {

    load_config

    [[ "$HCR_PORT" =~ ^[0-9]+$ ]] || return 0

    if command -v iptables >/dev/null 2>&1; then

        while iptables -C INPUT \
            -p tcp \
            --dport "$HCR_PORT" \
            -j ACCEPT \
            2>/dev/null; do

            iptables -D INPUT \
                -p tcp \
                --dport "$HCR_PORT" \
                -j ACCEPT \
                2>/dev/null || break

        done

    fi
}

# ==============================================================
# INSTALAR
# ==============================================================

install_hcr() {

    header

    echo -e "${WHITE}${BOLD}                 INSTALAR HCR${RESET}"

    line

    echo

    if [[ $EUID -ne 0 ]]; then

        err "Ejecuta este módulo como root."

        pause

        return 1
    fi

    install_dependencies || {
        pause
        return 1
    }

    assign_port || {
        pause
        return 1
    }

    echo

    echo -e "  ${WHITE}Puerto externo : ${GREEN}${HCR_PORT}${RESET}"
    echo -e "  ${WHITE}Backend        : ${GREEN}${HCR_BACKEND_HOST}:${HCR_BACKEND_PORT}${RESET}"
    echo

    line

    # Detener SOLO HCR si ya existe.
    systemctl stop "$HCR_UNIT" 2>/dev/null || true

    if [[ ! -x "$HCR_BIN" ]]; then

        download_hcr || {
            pause
            return 1
        }

    else

        ok "HCR ya está instalado."

    fi

    create_service || {
        pause
        return 1
    }

    open_firewall

    # Activar HCR en configuración
    set_config "HCR" "ON"
    set_config "HCR_PORT" "$HCR_PORT"

    systemctl daemon-reload

    # Iniciar SOLO HCR
    info "Iniciando HCR..."

    systemctl restart "$HCR_UNIT"

    sleep 2

    if systemctl is-active --quiet "$HCR_UNIT"; then

        ok "HCR iniciado correctamente."
        ok "Puerto: $HCR_PORT"

    else

        err "HCR no pudo iniciar."

        echo

        journalctl \
            -u "$HCR_UNIT" \
            -n 25 \
            --no-pager

        pause

        return 1
    fi

    echo
    line

    echo -e "${GREEN}${BOLD}✓ HCR INSTALADO Y ACTIVO${RESET}"
    echo
    echo -e "  ${WHITE}Puerto HCR : ${GREEN}${HCR_PORT}${RESET}"
    echo -e "  ${WHITE}Backend    : ${GREEN}127.0.0.1:22${RESET}"
    echo -e "  ${WHITE}Servicio   : ${GREEN}${HCR_UNIT}${RESET}"
    echo
    echo -e "  ${GRAY}Los usuarios utilizan las mismas cuentas SSH${RESET}"
    echo -e "  ${GRAY}creadas desde KEVINTECH / usuarios/add.sh.${RESET}"

    pause
}

# ==============================================================
# INICIAR
# ==============================================================

start_hcr() {

    if [[ ! -f "/etc/systemd/system/$HCR_UNIT" ]]; then

        err "HCR no está instalado."

        return 1
    fi

    systemctl start "$HCR_UNIT"

    sleep 1

    if systemctl is-active --quiet "$HCR_UNIT"; then

        set_config "HCR" "ON"

        ok "HCR iniciado."

    else

        err "HCR no pudo iniciar."

        journalctl \
            -u "$HCR_UNIT" \
            -n 20 \
            --no-pager
    fi
}

# ==============================================================
# DETENER
# ==============================================================

stop_hcr() {

    systemctl stop "$HCR_UNIT" 2>/dev/null || true

    if ! systemctl is-active --quiet "$HCR_UNIT"; then

        set_config "HCR" "OFF"

        ok "HCR detenido."

    else

        err "HCR continúa activo."

    fi
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_hcr() {

    systemctl restart "$HCR_UNIT"

    sleep 2

    if systemctl is-active --quiet "$HCR_UNIT"; then

        set_config "HCR" "ON"

        ok "HCR reiniciado correctamente."

    else

        set_config "HCR" "OFF"

        err "HCR no pudo reiniciar."

        journalctl \
            -u "$HCR_UNIT" \
            -n 20 \
            --no-pager
    fi
}

# ==============================================================
# ESTADO
# ==============================================================

status_hcr() {

    header

    load_config

    echo -e "${WHITE}${BOLD}                    ESTADO HCR${RESET}"

    line

    echo

    if systemctl is-active --quiet "$HCR_UNIT"; then
        echo -e "  Estado : ${GREEN}● ACTIVO${RESET}"
    else
        echo -e "  Estado : ${RED}● INACTIVO${RESET}"
    fi

    echo -e "  Puerto : ${YELLOW}${HCR_PORT:-N/D}${RESET}"
    echo -e "  Backend: ${CYAN}${HCR_BACKEND_HOST}:${HCR_BACKEND_PORT}${RESET}"
    echo -e "  Unidad : ${GRAY}${HCR_UNIT}${RESET}"

    echo

    systemctl status "$HCR_UNIT" --no-pager

    pause
}

# ==============================================================
# LOGS
# ==============================================================

logs_hcr() {

    header

    echo -e "${WHITE}${BOLD}                    LOGS HCR${RESET}"

    line

    echo

    journalctl \
        -u "$HCR_UNIT" \
        -n 80 \
        --no-pager

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

uninstall_hcr() {

    header

    echo -e "${RED}${BOLD}                    DESINSTALAR HCR${RESET}"

    line

    load_config

    echo

    echo -e "${YELLOW}⚠ Esto eliminará únicamente HCR.${RESET}"
    echo -e "${GRAY}Los demás protocolos de KEVINTECH no serán detenidos.${RESET}"

    echo

    read -rp "Escribe CONFIRMAR para continuar: " CONFIRM

    if [[ "$CONFIRM" != "CONFIRMAR" ]]; then

        warn "Desinstalación cancelada."

        pause

        return 0
    fi

    echo

    # ==========================================================
    # 1. DETENER HCR
    # ==========================================================

    info "Deteniendo HCR..."

    systemctl stop "$HCR_UNIT" 2>/dev/null || true

    # ==========================================================
    # 2. DESHABILITAR HCR
    # ==========================================================

    info "Deshabilitando HCR..."

    systemctl disable "$HCR_UNIT" >/dev/null 2>&1 || true

    # ==========================================================
    # 3. ELIMINAR FIREWALL HCR
    # ==========================================================

    info "Eliminando regla del puerto HCR..."

    close_firewall

    # ==========================================================
    # 4. ELIMINAR SERVICIO
    # ==========================================================

    info "Eliminando servicio HCR..."

    rm -f "/etc/systemd/system/$HCR_UNIT"

    systemctl daemon-reload

    # ==========================================================
    # 5. ELIMINAR BINARIO HCR
    # ==========================================================

    info "Eliminando archivos HCR..."

    rm -rf "$HCR_DIR"

    # ==========================================================
    # 6. CONFIGURACIÓN
    # ==========================================================

    remove_config "HCR"
    remove_config "HCR_PORT"

    ok "HCR detenido y eliminado completamente."

    echo
    echo -e "${GREEN}${BOLD}Los demás servicios de KEVINTECH continúan intactos.${RESET}"

    pause
}

# ==============================================================
# MENÚ HCR
# ==============================================================

menu_hcr() {

    while true; do

        header

        load_config

        if systemctl is-active --quiet "$HCR_UNIT" 2>/dev/null; then
            STATUS="${GREEN}● ACTIVO${RESET}"
        else
            STATUS="${RED}● INACTIVO${RESET}"
        fi

        echo -e "  Estado : $STATUS"
        echo -e "  Puerto : ${YELLOW}${HCR_PORT:-N/D}${RESET}"
        echo -e "  SSH    : ${CYAN}${HCR_BACKEND_HOST}:${HCR_BACKEND_PORT}${RESET}"

        echo

        line

        echo
        echo -e " ${GREEN}[01]${RESET} 🚀 Instalar / Actualizar HCR"
        echo -e " ${GREEN}[02]${RESET} ▶️  Iniciar HCR"
        echo -e " ${GREEN}[03]${RESET} ⛔ Detener HCR"
        echo -e " ${GREEN}[04]${RESET} ♻️  Reiniciar HCR"
        echo -e " ${GREEN}[05]${RESET} 📊 Estado"
        echo -e " ${GREEN}[06]${RESET} 📜 Ver logs"
        echo -e " ${RED}[07]${RESET} 🗑️  Desinstalar HCR"

        echo

        line

        echo -e " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

        echo

        read -r -p "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" OP

        case "$OP" in

            1)
                install_hcr
                ;;

            2)
                start_hcr
                pause
                ;;

            3)
                stop_hcr
                pause
                ;;

            4)
                restart_hcr
                pause
                ;;

            5)
                status_hcr
                ;;

            6)
                logs_hcr
                ;;

            7)
                uninstall_hcr
                ;;

            0|00)

                if [[ -f "$BASE/protocolos/menu.sh" ]]; then
                    exec bash "$BASE/protocolos/menu.sh"
                else
                    exit 0
                fi
                ;;

            *)
                err "Opción inválida."
                sleep 1
                ;;

        esac

    done
}

# ==============================================================
# ROOT
# ==============================================================

if [[ $EUID -ne 0 ]]; then

    err "Este módulo debe ejecutarse como root."

    exit 1

fi

mkdir -p "$BASE"

menu_hcr