#!/bin/bash

# ==============================================================
#                  KEVINTECH MULTI SCRIPT
#                       HCR SERVER
# ==============================================================
# Arquitectura: Linux AMD64
# Versión soportada: v7.10.12 (808) y superiores
# Transporte: PLAIN
# Puerto por defecto: 8880
# ==============================================================
#
# Coloca este archivo junto a:
#
#   hcr-server
#
# Ejemplo:
#   /etc/kevintech/protocolos/hcr.sh
#   /etc/kevintech/protocolos/hcr-server
#
# ==============================================================
# FUNCIONES VISUALES
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

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

HCR_BINARY="$SCRIPT_DIR/hcr-server"

SERVICE_NAME="hcr-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

DEFAULT_PORT="8880"

# Ajustes de rendimiento
MAX_DOWNLOAD_FRAME="6144"
DOWNLOAD_POLL_TIMEOUT="8s"

# ==============================================================
# ROOT
# ==============================================================

if [[ $EUID -ne 0 ]]; then
    clear
    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}HCR Server requiere permisos de root.${RESET}"
    echo
    exit 1
fi

# ==============================================================
# FUNCIONES
# ==============================================================

line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
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
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

service_active() {
    systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

service_exists() {
    systemctl cat "$SERVICE_NAME" >/dev/null 2>&1
}

# ==============================================================
# VERIFICAR BINARIO
# ==============================================================

check_binary() {

    if [[ ! -f "$HCR_BINARY" ]]; then
        error_msg "No se encontró hcr-server."
        echo
        echo -e "${WHITE}Debe estar en:${RESET}"
        echo -e "${YELLOW}${HCR_BINARY}${RESET}"
        echo
        return 1
    fi

    if [[ ! -x "$HCR_BINARY" ]]; then
        chmod +x "$HCR_BINARY"
    fi

    if ! "$HCR_BINARY" -version >/dev/null 2>&1; then
        error_msg "El archivo hcr-server no parece ser un binario válido."
        return 1
    fi

    return 0
}

# ==============================================================
# PUERTO
# ==============================================================

get_port() {

    local PORT

    if [[ -f "$CONFIG" ]]; then
        PORT="$(grep '^HCR_PORT=' "$CONFIG" 2>/dev/null | cut -d= -f2)"
    fi

    if [[ -z "$PORT" ]]; then
        PORT="$DEFAULT_PORT"
    fi

    echo "$PORT"
}

save_port() {

    local PORT="$1"

    mkdir -p "$BASE"

    if [[ -f "$CONFIG" ]]; then

        if grep -q '^HCR_PORT=' "$CONFIG"; then
            sed -i "s/^HCR_PORT=.*/HCR_PORT=${PORT}/" "$CONFIG"
        else
            echo "HCR_PORT=${PORT}" >> "$CONFIG"
        fi

    else
        echo "HCR_PORT=${PORT}" > "$CONFIG"
    fi
}

# ==============================================================
# CREAR SERVICIO
# ==============================================================

create_service() {

    local PORT="$1"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=HCR Server
After=network-online.target ssh.service sshd.service
Wants=network-online.target

[Service]
Type=exec
User=root
Group=root
WorkingDirectory=${SCRIPT_DIR}

ExecStart=${HCR_BINARY} --listen :${PORT} --target 127.0.0.1:22 --transport plain --max-download-frame ${MAX_DOWNLOAD_FRAME} --download-poll-timeout ${DOWNLOAD_POLL_TIMEOUT}

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

ReadOnlyPaths=${SCRIPT_DIR}

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

    systemctl daemon-reload
}

# ==============================================================
# INSTALAR / ACTUALIZAR
# ==============================================================

install_hcr() {

    clear

    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║                    HCR SERVER                              ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! check_binary; then
        pause
        return
    fi

    local PORT="8880"

echo -e "${WHITE}Puerto HCR:${RESET} ${GREEN}${PORT}${RESET}"

    save_port "$PORT"

    echo
    info "Preparando HCR Server..."
    sleep 1

    # Detener versión anterior si existe
    if service_exists; then
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    fi

    create_service "$PORT"

    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

    if systemctl restart "$SERVICE_NAME"; then

        sleep 2

        if service_active; then

            echo
            ok "HCR Server instalado/actualizado correctamente."
            echo
            echo -e "${WHITE}Servicio:${RESET} ${GREEN}${SERVICE_NAME}${RESET}"
            echo -e "${WHITE}Puerto:${RESET} ${GREEN}${PORT}${RESET}"
            echo -e "${WHITE}Transporte:${RESET} ${GREEN}plain${RESET}"
            echo -e "${WHITE}Target:${RESET} ${GREEN}127.0.0.1:22${RESET}"
            echo -e "${WHITE}Frame:${RESET} ${GREEN}${MAX_DOWNLOAD_FRAME}${RESET}"
            echo -e "${WHITE}Poll timeout:${RESET} ${GREEN}${DOWNLOAD_POLL_TIMEOUT}${RESET}"
            echo

        else

            error_msg "HCR Server no quedó activo."
            echo
            systemctl status "$SERVICE_NAME" --no-pager --full
        fi

    else

        error_msg "No se pudo iniciar HCR Server."
        echo
        systemctl status "$SERVICE_NAME" --no-pager --full
    fi

    pause
}

# ==============================================================
# LOG
# ==============================================================

show_log() {

    clear

    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║                     HCR SERVER LOG                          ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! service_exists; then
        warning "HCR Server todavía no está instalado."
        echo
        pause
        return
    fi

    journalctl -u "$SERVICE_NAME" -n 100 --no-pager --full

    echo
    echo -e "${GRAY}Últimas 100 líneas.${RESET}"
    echo

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

uninstall_hcr() {

    clear

    echo
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BOLD}║                  DESINSTALAR HCR SERVER                    ║${RESET}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! service_exists && [[ ! -f "$SERVICE_FILE" ]]; then
        warning "HCR Server no está instalado."
        echo
        pause
        return
    fi

    read -rp "$(echo -e "${YELLOW}¿Seguro que deseas desinstalar HCR? [s/N]: ${RESET}")" CONFIRM

    case "${CONFIRM,,}" in

        s|si|sí|y|yes)

            echo
            info "Deteniendo HCR Server..."

            systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true

            rm -f "$SERVICE_FILE"

            systemctl daemon-reload
            systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

            ok "HCR Server fue desinstalado."
            echo
            echo -e "${GRAY}El binario hcr-server fue conservado.${RESET}"
            echo

            ;;

        *)

            warning "Operación cancelada."

            ;;
    esac

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

show_status() {

    clear

    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║                     HCR SERVER                             ║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if service_active; then
        echo -e "${GREEN}${BOLD}● ACTIVO${RESET}"
    else
        echo -e "${RED}${BOLD}● INACTIVO${RESET}"
    fi

    echo
    echo -e "${WHITE}Puerto:${RESET} $(get_port)"
    echo -e "${WHITE}Transporte:${RESET} plain"
    echo -e "${WHITE}Target:${RESET} 127.0.0.1:22"
    echo

    systemctl status "$SERVICE_NAME" --no-pager --full 2>/dev/null || true

    echo
    pause
}

# ==============================================================
# MENÚ
# ==============================================================

HCR() {

    while true; do

        clear

        echo
        echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}${BOLD}║                    HCR SERVER                              ║${RESET}"
        echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
        echo

        if service_active; then
            STATUS="${GREEN}● ACTIVO${RESET}"
        else
            STATUS="${RED}● INACTIVO${RESET}"
        fi

        echo -e "  Estado: ${STATUS}"
        echo -e "  Puerto: ${YELLOW}$(get_port)${RESET}"
        echo

        line

        echo -e "  ${GREEN}${BOLD}[1]${RESET} Instalar / Actualizar"
        echo -e "  ${GREEN}${BOLD}[2]${RESET} Ver Log"
        echo -e "  ${GREEN}${BOLD}[3]${RESET} Estado"
        echo -e "  ${RED}${BOLD}[4]${RESET} Desinstalar"
        echo -e "  ${RED}${BOLD}[0]${RESET} Regresar"
        echo

        read -rp "$(echo -e "${CYAN}Selecciona una opción: ${RESET}")" OPTION

        case "$OPTION" in

            1)
                install_hcr
                ;;

            2)
                show_log
                ;;

            3)
                show_status
                ;;

            4)
                uninstall_hcr
                ;;

            0)
                return
                ;;

            *)
                error_msg "Opción inválida."
                sleep 1
                ;;

        esac

    done
}

# ==============================================================
# EJECUTAR
# ==============================================================

HCR