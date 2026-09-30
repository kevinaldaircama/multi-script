#!/usr/bin/env bash

# ============================================================
# KEVINTECH MULTI SCRIPT
# HCR SERVER
# ============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
PROTOCOL_DIR="$BASE/protocolos"

SERVICE_NAME="hcr-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

HCR_DIR="$PROTOCOL_DIR"
HCR_BINARY="$HCR_DIR/hcr-server"
HCR_CERT_DIR="$HCR_DIR/hcr-certs"
HCR_CERT="$HCR_CERT_DIR/fullchain.pem"
HCR_KEY="$HCR_CERT_DIR/privkey.pem"

HCR_PORT="${HCR_PORT:-8080}"
HCR_TRANSPORT="${HCR_TRANSPORT:-auto}"

MAX_DOWNLOAD_FRAME="6144"
DOWNLOAD_POLL_TIMEOUT="8s"

# ============================================================
# COLORES
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
RESET='\033[0m'
BOLD='\033[1m'

# ============================================================
# FUNCIONES
# ============================================================

pause() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

error_msg() {
    echo -e "${RED}✘ $1${RESET}"
}

success_msg() {
    echo -e "${GREEN}✔ $1${RESET}"
}

info_msg() {
    echo -e "${CYAN}➜ $1${RESET}"
}

warning_msg() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

load_config() {
    if [[ -f "$CONFIG" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG"
    fi

    HCR_PORT="${HCR_PORT:-8080}"
    HCR_TRANSPORT="${HCR_TRANSPORT:-auto}"
    HCR="${HCR:-OFF}"
}

save_config_value() {
    local key="$1"
    local value="$2"

    touch "$CONFIG"

    if grep -qE "^${key}=" "$CONFIG"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG"
    else
        echo "${key}=${value}" >> "$CONFIG"
    fi
}

validate_port() {
    local port="$1"

    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    (( port >= 1 && port <= 65535 )) || return 1

    return 0
}

validate_transport() {
    case "$1" in
        tls|plain|auto)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

binary_version() {
    if [[ -x "$HCR_BINARY" ]]; then
        "$HCR_BINARY" -version 2>/dev/null || true
    fi
}

check_binary() {
    if [[ ! -f "$HCR_BINARY" ]]; then
        error_msg "No se encontró el binario:"
        echo "  $HCR_BINARY"
        return 1
    fi

    if [[ ! -x "$HCR_BINARY" ]]; then
        chmod +x "$HCR_BINARY"
    fi

    if ! "$HCR_BINARY" -version >/dev/null 2>&1; then
        error_msg "El binario hcr-server no es válido o no soporta -version."
        return 1
    fi

    return 0
}

check_tls() {
    if [[ "$HCR_TRANSPORT" != "tls" && "$HCR_TRANSPORT" != "auto" ]]; then
        return 0
    fi

    if [[ ! -f "$HCR_CERT" ]]; then
        error_msg "No existe el certificado TLS:"
        echo "  $HCR_CERT"
        return 1
    fi

    if [[ ! -f "$HCR_KEY" ]]; then
        error_msg "No existe la clave TLS:"
        echo "  $HCR_KEY"
        return 1
    fi

    if ! command_exists openssl; then
        error_msg "OpenSSL no está instalado."
        return 1
    fi

    if ! openssl x509 -in "$HCR_CERT" -noout >/dev/null 2>&1; then
        error_msg "El certificado TLS no es válido."
        return 1
    fi

    if ! openssl pkey -in "$HCR_KEY" -passin pass: -noout >/dev/null 2>&1; then
        error_msg "La clave privada TLS no es válida o requiere contraseña."
        return 1
    fi

    local cert_key
    local private_key

    cert_key="$(openssl x509 -in "$HCR_CERT" -pubkey -noout 2>/dev/null)"
    private_key="$(openssl pkey -in "$HCR_KEY" -passin pass: -pubout 2>/dev/null)"

    if [[ "$cert_key" != "$private_key" ]]; then
        error_msg "El certificado y la clave TLS no coinciden."
        return 1
    fi

    chmod 600 "$HCR_KEY"

    return 0
}

create_directories() {
    mkdir -p "$HCR_CERT_DIR"

    chmod 755 "$HCR_DIR"
    chmod 700 "$HCR_CERT_DIR"
}

create_service() {

    local tls_arguments=""

    if [[ "$HCR_TRANSPORT" == "tls" || "$HCR_TRANSPORT" == "auto" ]]; then
        tls_arguments=" --tls-cert $HCR_CERT --tls-key $HCR_KEY"
    fi

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KEVINTECH HCR Server
Documentation=file:${HCR_DIR}/README.md
Wants=network-online.target
After=network-online.target ssh.service sshd.service

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=exec

User=root
Group=root

WorkingDirectory=${HCR_DIR}

ExecStart=${HCR_BINARY} --listen :${HCR_PORT} --target 127.0.0.1:22 --transport ${HCR_TRANSPORT}${tls_arguments} --max-download-frame ${MAX_DOWNLOAD_FRAME} --download-poll-timeout ${DOWNLOAD_POLL_TIMEOUT}

Restart=on-failure
RestartSec=5s

TimeoutStopSec=15s
KillSignal=SIGTERM

UMask=0077

NoNewPrivileges=true

CapabilityBoundingSet=
AmbientCapabilities=

PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=read-only
ProtectControlGroups=true

RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true

MemoryDenyWriteExecute=false

ReadOnlyPaths=${HCR_DIR}

LimitNOFILE=4096
LimitCORE=0

TasksMax=512
MemoryMax=384M

StandardOutput=journal
StandardError=journal

SyslogIdentifier=hcr-server

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"

    if command_exists systemd-analyze; then
        if ! systemd-analyze verify "$SERVICE_FILE" >/dev/null 2>&1; then
            error_msg "La configuración de systemd tiene errores."
            systemd-analyze verify "$SERVICE_FILE" || true
            return 1
        fi
    fi

    return 0
}

install_hcr() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║        INSTALAR HCR SERVER               ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    load_config

    if [[ $EUID -ne 0 ]]; then
        error_msg "Debes ejecutar este módulo como root."
        pause
        return
    fi

    if ! command_exists systemctl; then
        error_msg "systemctl no está disponible."
        pause
        return
    fi

    if ! check_binary; then
        echo
        warning_msg "Coloca el binario aquí:"
        echo "  $HCR_BINARY"
        echo
        echo "El binario debe ser compatible con la arquitectura de tu VPS."
        pause
        return
    fi

    echo
    echo -e "${WHITE}Puerto actual:${RESET} ${GREEN}${HCR_PORT}${RESET}"
    read -rp "Nuevo puerto [ENTER = ${HCR_PORT}]: " NEW_PORT

    if [[ -n "$NEW_PORT" ]]; then
        if ! validate_port "$NEW_PORT"; then
            error_msg "Puerto inválido. Usa un valor entre 1 y 65535."
            pause
            return
        fi

        HCR_PORT="$NEW_PORT"
    fi

    echo
    echo "Transporte:"
    echo "  1) TLS"
    echo "  2) Plain"
    echo "  3) Auto"
    echo

    local transport_option

    case "$HCR_TRANSPORT" in
        tls) transport_option=1 ;;
        plain) transport_option=2 ;;
        *) transport_option=3 ;;
    esac

    read -rp "Selecciona transporte [${transport_option}]: " NEW_TRANSPORT

    NEW_TRANSPORT="${NEW_TRANSPORT:-$transport_option}"

    case "$NEW_TRANSPORT" in
        1)
            HCR_TRANSPORT="tls"
            ;;
        2)
            HCR_TRANSPORT="plain"
            ;;
        3)
            HCR_TRANSPORT="auto"
            ;;
        *)
            error_msg "Opción inválida."
            pause
            return
            ;;
    esac

    create_directories

    if ! check_tls; then
        echo
        warning_msg "Para TLS/Auto necesitas:"
        echo "  $HCR_CERT"
        echo "  $HCR_KEY"
        pause
        return
    fi

    if [[ "$HCR_TRANSPORT" == "plain" ]]; then
        warning_msg "HCR se instalará sin TLS."
    fi

    if ! create_service; then
        pause
        return
    fi

    systemctl daemon-reload

    systemctl enable "$SERVICE_NAME.service" >/dev/null 2>&1

    systemctl reset-failed "$SERVICE_NAME.service" >/dev/null 2>&1 || true

    if ! systemctl restart "$SERVICE_NAME.service"; then
        error_msg "HCR Server no pudo iniciar."
        echo
        systemctl status "$SERVICE_NAME.service" --no-pager --full || true
        pause
        return
    fi

    sleep 2

    if ! systemctl is-active --quiet "$SERVICE_NAME.service"; then
        error_msg "HCR Server no quedó activo."
        systemctl status "$SERVICE_NAME.service" --no-pager --full || true
        pause
        return
    fi

    save_config_value "HCR" "ON"
    save_config_value "HCR_PORT" "$HCR_PORT"
    save_config_value "HCR_TRANSPORT" "$HCR_TRANSPORT"

    echo
    success_msg "HCR Server instalado correctamente."
    echo
    echo -e "${WHITE}Puerto:${RESET}     ${GREEN}${HCR_PORT}${RESET}"
    echo -e "${WHITE}Transporte:${RESET} ${GREEN}${HCR_TRANSPORT}${RESET}"
    echo -e "${WHITE}Servicio:${RESET}   ${GREEN}${SERVICE_NAME}${RESET}"

    if [[ "$HCR_TRANSPORT" != "plain" ]]; then
        echo -e "${WHITE}TLS:${RESET}         ${GREEN}ACTIVO${RESET}"
    fi

    pause
}

start_hcr() {

    if ! systemctl start "$SERVICE_NAME.service"; then
        error_msg "No se pudo iniciar HCR Server."
        return 1
    fi

    save_config_value "HCR" "ON"

    success_msg "HCR Server iniciado."
}

stop_hcr() {

    if ! systemctl stop "$SERVICE_NAME.service"; then
        error_msg "No se pudo detener HCR Server."
        return 1
    fi

    save_config_value "HCR" "OFF"

    success_msg "HCR Server detenido."
}

restart_hcr() {

    if ! systemctl restart "$SERVICE_NAME.service"; then
        error_msg "No se pudo reiniciar HCR Server."
        return 1
    fi

    save_config_value "HCR" "ON"

    success_msg "HCR Server reiniciado."
}

status_hcr() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          ESTADO HCR SERVER               ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    load_config

    echo
    echo -e "${WHITE}Configuración${RESET}"
    echo "──────────────────────────────────────────"
    echo "Estado config : $HCR"
    echo "Puerto        : $HCR_PORT"
    echo "Transporte    : $HCR_TRANSPORT"
    echo "Binario       : $HCR_BINARY"
    echo

    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        echo -e "Servicio      : ${GREEN}● ACTIVO${RESET}"
    else
        echo -e "Servicio      : ${RED}● INACTIVO${RESET}"
    fi

    echo
    systemctl status "$SERVICE_NAME.service" --no-pager --full || true

    echo
    pause
}

logs_hcr() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║             LOGS HCR SERVER              ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    journalctl -u "$SERVICE_NAME.service" -n 80 --no-pager

    echo
    pause
}

configure_hcr() {

    clear

    load_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          CONFIGURAR HCR SERVER            ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo "Puerto actual: $HCR_PORT"
    read -rp "Nuevo puerto [ENTER = mantener]: " NEW_PORT

    if [[ -n "$NEW_PORT" ]]; then
        if ! validate_port "$NEW_PORT"; then
            error_msg "Puerto inválido."
            pause
            return
        fi

        HCR_PORT="$NEW_PORT"
    fi

    echo
    echo "Transporte actual: $HCR_TRANSPORT"
    echo
    echo "1) TLS"
    echo "2) Plain"
    echo "3) Auto"
    echo

    read -rp "Nueva opción [ENTER = mantener]: " OPTION

    if [[ -n "$OPTION" ]]; then
        case "$OPTION" in
            1) HCR_TRANSPORT="tls" ;;
            2) HCR_TRANSPORT="plain" ;;
            3) HCR_TRANSPORT="auto" ;;
            *)
                error_msg "Opción inválida."
                pause
                return
                ;;
        esac
    fi

    save_config_value "HCR_PORT" "$HCR_PORT"
    save_config_value "HCR_TRANSPORT" "$HCR_TRANSPORT"

    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        if create_service; then
            systemctl daemon-reload
            systemctl restart "$SERVICE_NAME.service"
        fi
    fi

    success_msg "Configuración guardada."

    echo
    echo "Puerto: $HCR_PORT"
    echo "Transporte: $HCR_TRANSPORT"

    pause
}

uninstall_hcr() {

    clear

    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║         DESINSTALAR HCR SERVER           ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    warning_msg "Esto detendrá y eliminará el servicio hcr-server."
    echo
    read -rp "¿Continuar? [s/N]: " CONFIRM

    [[ "$CONFIRM" =~ ^[sS]$ ]] || return

    systemctl disable --now "$SERVICE_NAME.service" >/dev/null 2>&1 || true

    rm -f "$SERVICE_FILE"

    systemctl daemon-reload

    systemctl reset-failed "$SERVICE_NAME.service" >/dev/null 2>&1 || true

    save_config_value "HCR" "OFF"

    success_msg "HCR Server desinstalado."

    echo
    info_msg "El binario y los certificados fueron conservados."
    echo "Directorio:"
    echo "  $HCR_DIR"

    pause
}

# ============================================================
# INSTALACIÓN AUTOMÁTICA
# ============================================================

auto_install() {

    load_config

    if [[ $EUID -ne 0 ]]; then
        error_msg "Debes ejecutar como root."
        return 1
    fi

    if ! check_binary; then
        return 1
    fi

    create_directories

    if ! check_tls; then
        return 1
    fi

    create_service || return 1

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME.service" >/dev/null 2>&1
    systemctl restart "$SERVICE_NAME.service"

    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME.service"; then
        save_config_value "HCR" "ON"
        save_config_value "HCR_PORT" "$HCR_PORT"
        save_config_value "HCR_TRANSPORT" "$HCR_TRANSPORT"

        success_msg "HCR Server instalado automáticamente."
        return 0
    fi

    error_msg "HCR Server no quedó activo."
    return 1
}

# ============================================================
# MENÚ
# ============================================================

show_menu() {

    clear

    load_config

    local STATUS

    if systemctl is-active --quiet "$SERVICE_NAME.service" 2>/dev/null; then
        STATUS="${GREEN}● ACTIVO${RESET}"
    else
        STATUS="${RED}● INACTIVO${RESET}"
    fi

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          🔐 HCR SERVER                   ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e " Estado: $STATUS"
    echo -e " Puerto: ${GREEN}${HCR_PORT}${RESET}"
    echo -e " Modo:   ${GREEN}${HCR_TRANSPORT}${RESET}"

    echo
    echo -e "${WHITE}┌──────────────────────────────────────────┐${RESET}"
    echo -e "${WHITE}│${RESET} [1] 🚀 Instalar / Actualizar           ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [2] ▶️  Iniciar                         ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [3] ⏹️  Detener                         ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [4] 🔄 Reiniciar                        ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [5] 📊 Estado                           ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [6] 📜 Ver Logs                         ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [7] ⚙️  Configurar                      ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [8] 🗑️  Desinstalar                     ${WHITE}│${RESET}"
    echo -e "${WHITE}│${RESET} [0] ↩️  Volver                          ${WHITE}│${RESET}"
    echo -e "${WHITE}└──────────────────────────────────────────┘${RESET}"

    echo
    read -rp "Selecciona una opción: " OPTION

    case "$OPTION" in
        1) install_hcr ;;
        2) start_hcr; pause ;;
        3) stop_hcr; pause ;;
        4) restart_hcr; pause ;;
        5) status_hcr ;;
        6) logs_hcr ;;
        7) configure_hcr ;;
        8) uninstall_hcr ;;
        0) return ;;
        *) error_msg "Opción inválida."; pause ;;
    esac
}

# ============================================================
# AUTO
# ============================================================

if [[ "${1:-}" == "--auto" ]]; then
    auto_install
    exit $?
fi

# ============================================================
# EJECUCIÓN
# ============================================================

show_menu
