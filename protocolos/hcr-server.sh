#!/usr/bin/env bash
# ==============================================================
# KEVINTECH MULTI SCRIPT - HCR SERVER MANAGER
# Adaptado para HAProxy con terminación SSL:
# HAProxy (SSL) -> 127.0.0.1:8080 (HCR PLAIN) -> 127.0.0.1:22 (SSH)
# Requiere el binario hcr-server actualizado en la misma carpeta.
# ==============================================================

set -Eeuo pipefail

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
CONFIG="$BASE/hcr.conf"

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
HCR_BINARY="$SCRIPT_DIR/hcr-server"

SERVICE_NAME="hcr-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# HAProxy termina SSL; HCR recibe tráfico PLAIN solo desde localhost.
DEFAULT_PORT="8080"
DEFAULT_LISTEN_HOST="127.0.0.1"
DEFAULT_TARGET="127.0.0.1:22"
DEFAULT_TRANSPORT="plain"

MAX_DOWNLOAD_FRAME="16384"
DOWNLOAD_POLL_TIMEOUT="8s"
MAX_CONNECTIONS="2048"
MAX_SESSIONS="32"
MAX_SESSIONS_PER_IP="16"
SESSION_STATS_INTERVAL="0"
DIAGNOSTICS_INTERVAL="0"

HCR_VERSION="1.0 Premium (binary 0.1.29 Patch 1)"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}Este administrador requiere permisos de root.${RESET}"
    exit 1
fi

line() { echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"; }
separator() { echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"; }
ok() { echo -e "${GREEN}${BOLD}✔${RESET} ${WHITE}$1${RESET}"; }
error_msg() { echo -e "${RED}${BOLD}✘${RESET} ${WHITE}$1${RESET}"; }
warning() { echo -e "${YELLOW}${BOLD}⚠${RESET} ${WHITE}$1${RESET}"; }
info() { echo -e "${CYAN}➜${RESET} ${WHITE}$1${RESET}"; }
pause() { echo; read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"; }

service_active() { systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; }
service_exists() { systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; }

load_config() {
    PORT="$DEFAULT_PORT"
    LISTEN_HOST="$DEFAULT_LISTEN_HOST"
    TARGET="$DEFAULT_TARGET"
    TRANSPORT="$DEFAULT_TRANSPORT"

    if [[ -f "$CONFIG" ]]; then
        # Archivo generado por este script, no introducir contenido externo.
        while IFS='=' read -r key value; do
            case "$key" in
                HCR_PORT) PORT="$value" ;;
                HCR_LISTEN_HOST) LISTEN_HOST="$value" ;;
                HCR_TARGET) TARGET="$value" ;;
                HCR_TRANSPORT) TRANSPORT="$value" ;;
            esac
        done < "$CONFIG"
    fi
}

save_config() {
    install -d -m 700 "$BASE"
    cat > "$CONFIG" <<EOF
HCR_PORT=$PORT
HCR_LISTEN_HOST=$LISTEN_HOST
HCR_TARGET=$TARGET
HCR_TRANSPORT=$TRANSPORT
EOF
    chmod 600 "$CONFIG"
}

validate_settings() {
    [[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || {
        error_msg "Puerto inválido: $PORT"; return 1;
    }
    [[ "$LISTEN_HOST" == "127.0.0.1" ]] || {
        error_msg "Por seguridad con HAProxy, HCR debe escuchar en 127.0.0.1."; return 1;
    }
    [[ "$TARGET" == "127.0.0.1:22" ]] || {
        error_msg "Este perfil espera SSH local en 127.0.0.1:22."; return 1;
    }
    [[ "$TRANSPORT" == "plain" ]] || {
        error_msg "Con HAProxy terminando SSL, el transporte HCR debe ser plain."; return 1;
    }
    [[ "$MAX_DOWNLOAD_FRAME" =~ ^[0-9]+$ ]] && (( MAX_DOWNLOAD_FRAME >= 1 && MAX_DOWNLOAD_FRAME <= 262140 )) || {
        error_msg "MAX_DOWNLOAD_FRAME debe estar entre 1 y 262140."; return 1;
    }
}

check_binary() {
    if [[ ! -f "$HCR_BINARY" ]]; then
        error_msg "No se encontró el binario: $HCR_BINARY"
        return 1
    fi
    chmod 755 "$HCR_BINARY"
    if ! "$HCR_BINARY" --version >/dev/null 2>&1; then
        error_msg "El binario hcr-server no es válido o no puede ejecutarse."
        return 1
    fi
    local version
    version="$("$HCR_BINARY" --version 2>&1 | head -n 1)"
    info "Binario detectado: $version"
}

show_header() {
    load_config
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                 ${MAGENTA}⚡ HCR SERVER MANAGER${RESET}                 ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
    if service_active; then
        echo -e "${CYAN}║${RESET}  ${WHITE}Estado:${RESET}      ${GREEN}${BOLD}● ACTIVO${RESET}"
    else
        echo -e "${CYAN}║${RESET}  ${WHITE}Estado:${RESET}      ${RED}${BOLD}● INACTIVO${RESET}"
    fi
    echo -e "${CYAN}║${RESET}  ${WHITE}Escucha:${RESET}     ${YELLOW}${LISTEN_HOST}:${PORT}${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Transporte:${RESET}  ${GREEN}PLAIN (SSL en HAProxy)${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Destino:${RESET}     ${GREEN}${TARGET}${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Frame:${RESET}       ${GREEN}${MAX_DOWNLOAD_FRAME} bytes${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
}

create_service() {
    validate_settings
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=HCR Server - KevinTech Multi Script (HAProxy SSL backend)
After=network-online.target ssh.service sshd.service haproxy.service
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${HCR_BINARY} --listen ${LISTEN_HOST}:${PORT} --target ${TARGET} --transport plain --max-download-frame ${MAX_DOWNLOAD_FRAME} --download-poll-timeout ${DOWNLOAD_POLL_TIMEOUT} --max-connections ${MAX_CONNECTIONS} --max-sessions ${MAX_SESSIONS} --max-sessions-per-ip ${MAX_SESSIONS_PER_IP}
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

install_hcr() {
    clear
    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║                 ${GREEN}HCR SERVER INSTALL / UPDATE${RESET}             ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    check_binary || { pause; return; }
    load_config

    # Perfil deliberado para HAProxy con terminación SSL.
    PORT="8080"
    LISTEN_HOST="127.0.0.1"
    TARGET="127.0.0.1:22"
    TRANSPORT="plain"

    echo -e "${WHITE}Configuración que se instalará:${RESET}"
    echo "  HAProxy SSL -> HCR ${LISTEN_HOST}:${PORT} (PLAIN) -> SSH ${TARGET}"
    echo "  Frame descarga       : ${MAX_DOWNLOAD_FRAME}"
    echo "  Poll timeout         : ${DOWNLOAD_POLL_TIMEOUT}"
    echo "  Máximo conexiones    : ${MAX_CONNECTIONS}"
    echo "  Máximo sesiones      : ${MAX_SESSIONS}"
    echo "  Sesiones por IP      : ${MAX_SESSIONS_PER_IP}"
    echo "  Estadísticas         : ${SESSION_STATS_INTERVAL} (0 = desactivadas)"
    echo "  Diagnóstico          : ${DIAGNOSTICS_INTERVAL} (0 = desactivado)"
    echo

    validate_settings || { pause; return; }

    if service_exists; then
        info "Deteniendo versión anterior..."
        systemctl stop "$SERVICE_NAME" || true
    fi

    # Comprueba si otro proceso ocupa el puerto local elegido.
    if command -v ss >/dev/null 2>&1 && ss -ltnH "sport = :${PORT}" | grep -q .; then
        error_msg "El puerto ${PORT} ya está ocupado. Revisa: ss -ltnp 'sport = :${PORT}'"
        pause
        return
    fi

    save_config
    create_service

    systemctl enable "$SERVICE_NAME" >/dev/null
    systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true

    if systemctl restart "$SERVICE_NAME"; then
        sleep 2
        if service_active; then
            ok "HCR instalado y activo en ${LISTEN_HOST}:${PORT}."
            echo
            echo "IMPORTANTE: configura HAProxy para enviar el tráfico SSL descifrado"
            echo "al backend TCP ${LISTEN_HOST}:${PORT}."
        else
            error_msg "El servicio no quedó activo."
            systemctl status "$SERVICE_NAME" --no-pager --full || true
        fi
    else
        error_msg "No se pudo iniciar HCR."
        systemctl status "$SERVICE_NAME" --no-pager --full || true
    fi
    pause
}

show_log() {
    clear
    echo
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║                    ${MAGENTA}HCR SERVER LOG${RESET}                     ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
    if ! service_exists; then
        warning "HCR Server todavía no está instalado."
    else
        journalctl -u "$SERVICE_NAME" -n 100 --no-pager --full
    fi
    pause
}

uninstall_hcr() {
    clear
    echo
    warning "Se eliminará el servicio systemd; se conservarán el binario y la configuración."
    read -rp "¿Confirmar desinstalación? [s/N]: " confirm
    case "${confirm,,}" in
        s|si|sí|y|yes)
            systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
            rm -f "$SERVICE_FILE"
            systemctl daemon-reload
            systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true
            ok "Servicio HCR desinstalado."
            ;;
        *) warning "Operación cancelada." ;;
    esac
    pause
}

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
        read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Selecciona una opción: ${RESET}")" OPTION
        case "$OPTION" in
            1) install_hcr ;;
            2) show_log ;;
            3) uninstall_hcr ;;
            0) return ;;
            *) error_msg "Opción inválida."; sleep 1 ;;
        esac
    done
}

HCR
