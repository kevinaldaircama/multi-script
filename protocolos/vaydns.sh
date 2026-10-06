#!/bin/bash
# ==========================================================
# KEVINTECH VAYDNS SERVER
# Instalador / Gestor independiente
# ==========================================================

set -u

BASE="/etc/kevintech"
DIR="/etc/vaydns"
BIN="/usr/bin/vaydns-server"
SERVICE="vaydns.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE}"
CONFIG="${BASE}/vaydns.conf"

VERSION="v0.2.8"
LISTEN_PORT="5301"

RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'
GRAY='\033[1;90m'
RESET='\033[0m'

info(){ echo -e "${CYAN}➜${RESET} $*"; }
ok(){ echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err(){ echo -e "${RED}✖${RESET} $*"; }
die(){ err "$*"; exit 1; }

need_root(){
    [[ "$EUID" -eq 0 ]] || die "Ejecuta este script como root."
}

has(){
    command -v "$1" >/dev/null 2>&1
}

install_deps(){
    local pkgs=()

    has curl || pkgs+=(curl)
    has openssl || pkgs+=(openssl)

    if has apt-get && ((${#pkgs[@]})); then
        export DEBIAN_FRONTEND=noninteractive
        info "Instalando dependencias..."
        apt-get update -y >/dev/null 2>&1 || die "Falló apt update."
        apt-get install -y "${pkgs[@]}" >/dev/null 2>&1 ||
            die "No se pudieron instalar las dependencias."
    fi

    has curl || die "curl no está disponible."
    has systemctl || die "systemctl no está disponible."
}

detect_arch(){
    case "$(uname -m)" in
        x86_64|amd64)
            ARCH="amd64"
            BIN_ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            BIN_ARCH="arm64"
            ;;
        armv7l|armv7)
            ARCH="arm"
            BIN_ARCH="armv7"
            ;;
        *)
            die "Arquitectura no soportada: $(uname -m)"
            ;;
    esac

    BIN_NAME="vaydns-server-linux-${BIN_ARCH}"
    DOWNLOAD_URL="https://github.com/net2share/vaydns/releases/download/${VERSION}/${BIN_NAME}"
}

save_config(){
    mkdir -p "$BASE"

    cat > "$CONFIG" <<EOF
# KEVINTECH VAYDNS
DOMAIN=$1
BACKEND_PORT=$2
LISTEN_PORT=$LISTEN_PORT
VERSION=$VERSION
EOF

    chmod 600 "$CONFIG"
}

load_config(){
    DOMAIN=""
    BACKEND_PORT=""

    if [[ -f "$CONFIG" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null || true
    fi
}

verify_existing_binary(){
    [[ -x "$BIN" ]] || return 1

    local output=""
    output="$("$BIN" -h 2>&1 || true)"

    [[ "$output" == *"-domain"* ]]
}

download_binary(){
    detect_arch

    local tmp="/tmp/kevintech-vaydns"
    local downloaded="$tmp/vaydns-server"

    rm -rf "$tmp"
    mkdir -p "$tmp"

    if verify_existing_binary; then
        ok "Binario VayDNS existente y válido."
        return 0
    fi

    info "Descargando VayDNS ${VERSION} para ${ARCH}..."

    curl -fL --retry 3 --connect-timeout 15 \
        -o "$downloaded" "$DOWNLOAD_URL" ||
        die "No se pudo descargar VayDNS desde GitHub."

    [[ -s "$downloaded" ]] ||
        die "El archivo descargado está vacío."

    install -m 0755 "$downloaded" "$BIN" ||
        die "No se pudo instalar $BIN."

    rm -rf "$tmp"

    verify_existing_binary ||
        die "El binario descargado no parece ser VayDNS."

    ok "VayDNS instalado en ${BIN}."
}

generate_keys(){
    mkdir -p "$DIR"

    if [[ -s "$DIR/server.key" && -s "$DIR/server.pub" ]]; then
        ok "Claves VayDNS existentes."
        return 0
    fi

    info "Generando claves VayDNS..."

    "$BIN" -gen-key \
        -privkey-file "$DIR/server.key" \
        -pubkey-file "$DIR/server.pub" \
        >/dev/null 2>&1 ||
        die "No se pudieron generar las claves VayDNS."

    [[ -s "$DIR/server.key" && -s "$DIR/server.pub" ]] ||
        die "VayDNS no generó correctamente las claves."

    chmod 600 "$DIR/server.key"
    chmod 644 "$DIR/server.pub"

    ok "Claves generadas."
}

create_service(){
    local domain="$1"
    local backend="$2"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech VayDNS Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${DIR}
ExecStart=${BIN} -udp :${LISTEN_PORT} -privkey-file ${DIR}/server.key -domain ${domain} -upstream 127.0.0.1:${backend}
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"

    systemctl daemon-reload
    systemctl enable "$SERVICE" >/dev/null 2>&1 || true
}

restart_service(){
    systemctl restart "$SERVICE" || return 1
    systemctl is-active --quiet "$SERVICE"
}

get_public_key(){
    [[ -f "$DIR/server.pub" ]] &&
        tr -d '\r\n' < "$DIR/server.pub"
}

install_vaydns(){
    need_root
    install_deps

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}             KEVINTECH VAYDNS                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
    echo

    read -rp "🌐 Dominio/SNI [vaydns.local]: " domain
    domain="${domain:-vaydns.local}"

    read -rp "🔌 Puerto backend local [443]: " backend
    backend="${backend:-443}"

    [[ "$backend" =~ ^[0-9]+$ ]] ||
        die "El puerto debe ser numérico."

    ((backend >= 1 && backend <= 65535)) ||
        die "Puerto fuera de rango."

    download_binary
    mkdir -p "$DIR"
    generate_keys
    save_config "$domain" "$backend"
    create_service "$domain" "$backend"

    info "Iniciando VayDNS..."
    systemctl restart "$SERVICE" ||
        die "No se pudo iniciar VayDNS."

    sleep 1

    if systemctl is-active --quiet "$SERVICE"; then
        ok "VayDNS está ACTIVO."
    else
        err "VayDNS no quedó activo."
        systemctl --no-pager -l status "$SERVICE" || true
        return 1
    fi

    show_info
}

remove_vaydns(){
    need_root

    echo
    echo -e "${RED}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}             ELIMINAR VAYDNS                 ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════╝${RESET}"
    echo

    read -rp "¿Eliminar VayDNS completamente? [s/N]: " confirm
    [[ "$confirm" =~ ^[sS]$ ]] || {
        warn "Operación cancelada."
        return 0
    }

    systemctl stop "$SERVICE" >/dev/null 2>&1 || true
    systemctl disable "$SERVICE" >/dev/null 2>&1 || true

    rm -f "$SERVICE_FILE"
    systemctl daemon-reload

    rm -rf "$DIR"
    rm -f "$BIN"
    rm -f "$CONFIG"

    ok "VayDNS fue desinstalado."
}

restart_vaydns(){
    need_root

    if restart_service; then
        ok "VayDNS reiniciado correctamente."
    else
        err "No se pudo reiniciar VayDNS."
        systemctl --no-pager -l status "$SERVICE" || true
        return 1
    fi
}

status_vaydns(){
    need_root

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}               ESTADO VAYDNS                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
    echo

    if verify_existing_binary; then
        echo -e "  ${GREEN}●${RESET} Binario : ${GREEN}INSTALADO${RESET}"
    else
        echo -e "  ${RED}●${RESET} Binario : ${RED}NO INSTALADO${RESET}"
    fi

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "  ${GREEN}●${RESET} Servicio: ${GREEN}ACTIVO${RESET}"
    else
        echo -e "  ${RED}●${RESET} Servicio: ${RED}INACTIVO${RESET}"
    fi

    load_config

    echo
    echo -e "${WHITE}Dominio/SNI:${RESET} ${DOMAIN:-N/D}"
    echo -e "${WHITE}Backend:${RESET}     127.0.0.1:${BACKEND_PORT:-N/D}"
    echo -e "${WHITE}Listener:${RESET}    UDP ${LISTEN_PORT}"
    echo -e "${WHITE}Clave pública:${RESET}"
    echo "  $(get_public_key || echo 'N/D')"

    echo
    systemctl --no-pager -l status "$SERVICE" 2>/dev/null |
        head -n 14 || true
}

logs_vaydns(){
    need_root
    journalctl -u "$SERVICE" -n 80 --no-pager
}

show_info(){
    load_config

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}             KEVINTECH VAYDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}Dominio/SNI:${RESET}  ${DOMAIN:-N/D}"
    echo -e "${WHITE}Backend:${RESET}      127.0.0.1:${BACKEND_PORT:-N/D}"
    echo -e "${WHITE}Listener:${RESET}     UDP ${LISTEN_PORT}"
    echo -e "${WHITE}Versión:${RESET}      ${VERSION}"
    echo -e "${WHITE}Binario:${RESET}      ${BIN}"
    echo -e "${WHITE}Clave privada:${RESET}${DIR}/server.key"
    echo -e "${WHITE}Clave pública:${RESET} ${DIR}/server.pub"
    echo
    echo -e "${WHITE}Clave pública:${RESET}"
    echo "  $(get_public_key || echo 'N/D')"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

menu(){
    need_root

    while true; do
        clear

        echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${WHITE}             KEVINTECH VAYDNS                ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${CYAN}║${RESET} [01] 🚀 Instalar / Actualizar               ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [02] 🔄 Reiniciar servicio                  ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [03] 📊 Ver estado                          ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [04] 📜 Ver logs                            ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [05] 🔑 Ver clave pública                    ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [06] ℹ️  Información                         ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [07] 🗑️  Desinstalar                        ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [00] ↩️  Regresar                            ${CYAN}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
        echo

        read -rp "Selecciona una opción: " op

        case "$op" in
            1|01)
                install_vaydns
                read -rp "Presiona Enter para continuar..."
                ;;
            2|02)
                restart_vaydns
                read -rp "Presiona Enter para continuar..."
                ;;
            3|03)
                status_vaydns
                read -rp "Presiona Enter para continuar..."
                ;;
            4|04)
                logs_vaydns
                read -rp "Presiona Enter para continuar..."
                ;;
            5|05)
                echo
                echo "Clave pública:"
                get_public_key || echo "N/D"
                echo
                read -rp "Presiona Enter para continuar..."
                ;;
            6|06)
                show_info
                read -rp "Presiona Enter para continuar..."
                ;;
            7|07)
                remove_vaydns
                read -rp "Presiona Enter para continuar..."
                ;;
            0|00)
                return
                ;;
            *)
                warn "Opción inválida."
                sleep 1
                ;;
        esac
    done
}

case "${1:-}" in
    --install)
        if [[ -n "${2:-}" && -n "${3:-}" ]]; then
            need_root
            install_deps
            download_binary
            mkdir -p "$DIR"
            generate_keys
            save_config "$2" "$3"
            create_service "$2" "$3"
            systemctl restart "$SERVICE" ||
                die "No se pudo iniciar VayDNS."
            systemctl is-active --quiet "$SERVICE" ||
                die "VayDNS no quedó activo."
            echo "PUBLIC_KEY=$(get_public_key)"
            ok "VayDNS instalado correctamente."
        else
            install_vaydns
        fi
        ;;
    --remove|--uninstall)
        remove_vaydns
        ;;
    --status)
        status_vaydns
        ;;
    --restart)
        restart_vaydns
        ;;
    --logs)
        logs_vaydns
        ;;
    --info)
        show_info
        ;;
    --public-key)
        get_public_key
        ;;
    --help|-h)
        echo "Uso:"
        echo "  $0                         Menú"
        echo "  $0 --install DOMINIO PUERTO"
        echo "  $0 --remove"
        echo "  $0 --status"
        echo "  $0 --restart"
        echo "  $0 --logs"
        echo "  $0 --info"
        echo "  $0 --public-key"
        ;;
    *)
        menu
        ;;
esac
