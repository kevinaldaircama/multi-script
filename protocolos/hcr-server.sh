#!/bin/bash

# ==============================================================
#              KEVINTECH MULTI SCRIPT
#                  HCR SERVER MANAGER
# ==============================================================
# Versión: 1.0 Premium
# Arquitectura: Linux AMD64
# Transporte: PLAIN
# Puerto: 8880
# Target: 127.0.0.1:22
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

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

HCR_BINARY="$SCRIPT_DIR/hcr-server"

SERVICE_NAME="hcr-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

DEFAULT_PORT="8880"

MAX_DOWNLOAD_FRAME="6144"
DOWNLOAD_POLL_TIMEOUT="8s"

HCR_VERSION="1.0 Premium"

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
    echo -e "${WHITE}HCR Server requiere permisos de root.${RESET}"
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
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

# ==============================================================
# ESTADO DEL SERVICIO
# ==============================================================

service_active() {
    systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

service_exists() {
    systemctl cat "$SERVICE_NAME" >/dev/null 2>&1
}

# ==============================================================
# CABECERA PRINCIPAL
# ==============================================================

show_header() {

    local PORT
    PORT="$(get_port)"

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                 ${MAGENTA}⚡ HCR SERVER MANAGER${RESET}                 ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"

    if service_active; then
        echo -e "${CYAN}║${RESET}  ${WHITE}Estado:${RESET}      ${GREEN}${BOLD}● ACTIVO${RESET}"
    else
        echo -e "${CYAN}║${RESET}  ${WHITE}Estado:${RESET}      ${RED}${BOLD}● INACTIVO${RESET}"
    fi

    echo -e "${CYAN}║${RESET}  ${WHITE}Puerto:${RESET}      ${YELLOW}${PORT}${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Transporte:${RESET}  ${GREEN}PLAIN${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Target:${RESET}      ${GREEN}127.0.0.1:22${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Versión:${RESET}     ${MAGENTA}${HCR_VERSION}${RESET}"

    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

# ==============================================================
# VERIFICAR BINARIO
# ==============================================================

check_binary() {

    if [[ ! -f "$HCR_BINARY" ]]; then

        error_msg "No se encontró el binario hcr-server."
        echo
        echo -e "${WHITE}Ruta esperada:${RESET}"
        echo -e "${YELLOW}$HCR_BINARY${RESET}"
        echo

        return 1
    fi

    if [[ ! -x "$HCR_BINARY" ]]; then
        chmod +x "$HCR_BINARY"
    fi

    if ! "$HCR_BINARY" -version >/dev/null 2>&1; then

        error_msg "El archivo hcr-server no parece ser un binario válido."
        echo

        return 1
    fi

    return 0
}

# ==============================================================
# PUERTO
# ==============================================================

get_port() {

    local PORT=""

    if [[ -f "$CONFIG" ]]; then
        PORT="$(grep '^HCR_PORT=' "$CONFIG" 2>/dev/null | cut -d= -f2)"
    fi

    [[ -z "$PORT" ]] && PORT="$DEFAULT_PORT"

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
# CREAR SERVICIO SYSTEMD
# ==============================================================

create_service() {

    local PORT="$1"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=HCR Server - KevinTech Multi Script
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
    echo -e "${CYAN}${BOLD}║${RESET}                ${GREEN}⚡ HCR SERVER${RESET}                        ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}              ${GRAY}INSTALL / UPDATE${RESET}                       ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! check_binary; then
        pause
        return
    fi

    local PORT="8880"

    echo -e "${WHITE}Configuración:${RESET}"
    echo
    echo -e "  ${GRAY}•${RESET} Puerto       : ${GREEN}${PORT}${RESET}"
    echo -e "  ${GRAY}•${RESET} Transporte   : ${GREEN}PLAIN${RESET}"
    echo -e "  ${GRAY}•${RESET} Target       : ${GREEN}127.0.0.1:22${RESET}"
    echo -e "  ${GRAY}•${RESET} Frame        : ${GREEN}${MAX_DOWNLOAD_FRAME}${RESET}"
    echo -e "  ${GRAY}•${RESET} Poll timeout  : ${GREEN}${DOWNLOAD_POLL_TIMEOUT}${RESET}"
    echo

    save_port "$PORT"

    separator

    info "Preparando HCR Server..."
    sleep 1

    if service_exists; then
        systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    fi

    create_service "$PORT"

    echo
    info "Habilitando servicio..."

    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

    echo
    info "Iniciando HCR Server..."

    if systemctl restart "$SERVICE_NAME"; then

        sleep 2

        if service_active; then

            echo
            echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${GREEN}${BOLD}║              ✔ HCR INSTALADO CORRECTAMENTE                ║${RESET}"
            echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo

            echo -e "  ${WHITE}Servicio:${RESET}    ${GREEN}${SERVICE_NAME}${RESET}"
            echo -e "  ${WHITE}Puerto:${RESET}      ${GREEN}${PORT}${RESET}"
            echo -e "  ${WHITE}Transporte:${RESET}  ${GREEN}PLAIN${RESET}"
            echo -e "  ${WHITE}Target:${RESET}      ${GREEN}127.0.0.1:22${RESET}"
            echo -e "  ${WHITE}Estado:${RESET}      ${GREEN}● ACTIVO${RESET}"

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
    echo -e "${CYAN}${BOLD}║${RESET}                  ${MAGENTA}📋 HCR SERVER LOG${RESET}                   ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! service_exists; then

        warning "HCR Server todavía no está instalado."
        echo

        pause
        return

    fi

    echo -e "${GRAY}Mostrando las últimas 100 líneas...${RESET}"
    echo

    line

    journalctl -u "$SERVICE_NAME" -n 100 --no-pager --full

    line

    echo
    echo -e "${GRAY}Para salir del visor de logs, presiona ENTER.${RESET}"

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

uninstall_hcr() {

    clear

    echo
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}${BOLD}║${RESET}                ${RED}🗑 DESINSTALAR HCR SERVER${RESET}              ${RED}${BOLD}║${RESET}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! service_exists && [[ ! -f "$SERVICE_FILE" ]]; then

        warning "HCR Server no está instalado."
        echo

        pause
        return

    fi

    echo -e "${YELLOW}Esta acción eliminará:${RESET}"
    echo
    echo -e "  ${GRAY}•${RESET} Servicio systemd"
    echo -e "  ${GRAY}•${RESET} Arranque automático"
    echo -e "  ${GRAY}•${RESET} Configuración del servicio"
    echo
    echo -e "${GRAY}El binario hcr-server será conservado.${RESET}"
    echo

    read -rp "$(echo -e "${YELLOW}${BOLD}¿Confirmar desinstalación? [s/N]: ${RESET}")" CONFIRM

    case "${CONFIRM,,}" in

        s|si|sí|y|yes)

            echo

            info "Deteniendo HCR Server..."

            systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true

            info "Eliminando servicio..."

            rm -f "$SERVICE_FILE"

            systemctl daemon-reload
            systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

            echo

            echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${GREEN}${BOLD}║              ✔ HCR DESINSTALADO                           ║${RESET}"
            echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo

            echo -e "${GRAY}El binario hcr-server permanece disponible para reinstalar.${RESET}"

            ;;

        *)

            echo
            warning "Operación cancelada."

            ;;

    esac

    pause
}

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

HCR() {

    while true; do

        clear

        show_header

        echo
        echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN HCR${RESET}"
        line

        echo -e "  ${GREEN}${BOLD}[1]${RESET}  🚀 ${WHITE}Instalar / Actualizar${RESET}"
        echo -e "  ${GREEN}${BOLD}[2]${RESET}  📋 ${WHITE}Ver Log${RESET}"
        echo -e "  ${RED}${BOLD}[3]${RESET}  🗑️ ${WHITE}Desinstalar${RESET}"

        echo
        separator

        echo -e "  ${RED}${BOLD}[0]${RESET}  ↩️ ${WHITE}Regresar${RESET}"

        echo
        echo -e "${GRAY}  KevinTech Multi Script • HCR Server • ${HCR_VERSION}${RESET}"
        echo

        read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Selecciona una opción: ${RESET}")" OPTION

        case "$OPTION" in

            1)
                install_hcr
                ;;

            2)
                show_log
                ;;

            3)
                uninstall_hcr
                ;;

            0)
                return
                ;;

            *)
                echo
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
