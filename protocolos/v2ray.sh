#!/bin/bash
# ============================================================
# KEVINTECH XRAY MANAGER v5.0
# ============================================================
# Protocolos:
#
# 10001 -> VLESS WebSocket
# 10002 -> VMess WebSocket
# 10003 -> Trojan WebSocket
# 10004 -> VLESS gRPC
# 10005 -> VLESS WebSocket 2
# 10006 -> VMess WebSocket 2
# 10007 -> Trojan WebSocket 2
# 10008 -> VLESS gRPC 2
#
# TLS externo:
# HAProxy / Nginx / Caddy
#
# Xray:
# 127.0.0.1:10001-10008
#
# ============================================================

set -Eeuo pipefail

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
XRAY_SERVICE="xray"

BACKUP_DIR="/etc/kevintech/xray-backups"
LOG_FILE="/var/log/xray/access.log"

EXTERNAL_PORT="443"

mkdir -p "$BASE"
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$XRAY_CONFIG")"
mkdir -p "$(dirname "$LOG_FILE")"

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
GRAY='\033[0;37m'
NC='\033[0m'

# ============================================================
# PROTOCOLOS
# ============================================================

declare -A P_PORT
declare -A P_NAME
declare -A P_TYPE
declare -A P_PATH
declare -A P_SERVICE

P_PORT[vless]="10001"
P_PORT[vmess]="10002"
P_PORT[trojan]="10003"
P_PORT[grpc]="10004"
P_PORT[vless2]="10005"
P_PORT[vmess2]="10006"
P_PORT[trojan2]="10007"
P_PORT[grpc2]="10008"

P_NAME[vless]="VLESS WS"
P_NAME[vmess]="VMess WS"
P_NAME[trojan]="Trojan WS"
P_NAME[grpc]="VLESS gRPC"
P_NAME[vless2]="VLESS WS 2"
P_NAME[vmess2]="VMess WS 2"
P_NAME[trojan2]="Trojan WS 2"
P_NAME[grpc2]="VLESS gRPC 2"

P_TYPE[vless]="vless"
P_TYPE[vmess]="vmess"
P_TYPE[trojan]="trojan"
P_TYPE[grpc]="vless"
P_TYPE[vless2]="vless"
P_TYPE[vmess2]="vmess"
P_TYPE[trojan2]="trojan"
P_TYPE[grpc2]="vless"

P_PATH[vless]="/vless"
P_PATH[vmess]="/vmess"
P_PATH[trojan]="/trojan-ws"
P_PATH[grpc]="kt-grpc"
P_PATH[vless2]="/vless2"
P_PATH[vmess2]="/vmess2"
P_PATH[trojan2]="/trojan-ws2"
P_PATH[grpc2]="kt-grpc2"

P_SERVICE[vless]="vless_ws"
P_SERVICE[vmess]="vmess_ws"
P_SERVICE[trojan]="trojan_ws"
P_SERVICE[grpc]="vless_grpc"
P_SERVICE[vless2]="vless_ws2"
P_SERVICE[vmess2]="vmess_ws2"
P_SERVICE[trojan2]="trojan_ws2"
P_SERVICE[grpc2]="vless_grpc2"

PROTOCOLS=(
    vless
    vmess
    trojan
    grpc
    vless2
    vmess2
    trojan2
    grpc2
)

# ============================================================
# UTILIDADES
# ============================================================

pause() {
    echo
    read -rp "Presiona ENTER para continuar..." _
}

header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              KEVINTECH XRAY MANAGER v5.0                 ║"
    echo "║              MULTI PROTOCOL EDITION                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

msg_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

msg_warn() {
    echo -e "${YELLOW}[AVISO]${NC} $*"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        msg_error "Ejecuta este script como root."
        exit 1
    fi
}

# ============================================================
# DEPENDENCIAS
# ============================================================

install_dependencies() {

    msg_info "Instalando dependencias..."

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y >/dev/null 2>&1 || true

    apt-get install -y \
        curl \
        wget \
        jq \
        uuid-runtime \
        ca-certificates \
        openssl \
        cron \
        unzip \
        socat \
        net-tools \
        lsof \
        >/dev/null 2>&1

    msg_ok "Dependencias instaladas."
}

# ============================================================
# DOMINIO / IP
# ============================================================

get_public_ip() {

    local ip=""

    ip="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"

    if [[ -z "$ip" ]]; then
        ip="$(curl -4fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)"
    fi

    if [[ -z "$ip" ]]; then
        ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    fi

    echo "$ip"
}

load_server_address() {

    SERVER_DOMAIN=""

    if [[ -f "$CONFIG" ]]; then
        SERVER_DOMAIN="$(grep -E '^SERVER_DOMAIN=' "$CONFIG" \
            | tail -n1 \
            | cut -d= -f2- \
            | tr -d '"' \
            | xargs || true)"
    fi

    if [[ -z "$SERVER_DOMAIN" && -f /etc/xray/domain ]]; then
        SERVER_DOMAIN="$(head -n1 /etc/xray/domain \
            | tr -d '[:space:]' || true)"
    fi

    SERVER_IP="$(get_public_ip)"

    if [[ -n "$SERVER_DOMAIN" ]]; then
        SERVER_ADDRESS="$SERVER_DOMAIN"
    else
        SERVER_ADDRESS="$SERVER_IP"
    fi
}

# ============================================================
# UUID / PASSWORD
# ============================================================

generate_uuid() {

    if command -v xray >/dev/null 2>&1; then
        xray uuid 2>/dev/null || uuidgen
    else
        uuidgen
    fi
}

generate_password() {
    openssl rand -hex 16
}

# ============================================================
# BACKUP
# ============================================================

backup_config() {

    [[ -f "$XRAY_CONFIG" ]] || return 0

    local stamp
    stamp="$(date '+%Y%m%d-%H%M%S')"

    cp -a \
        "$XRAY_CONFIG" \
        "$BACKUP_DIR/config-$stamp.json"

    find "$BACKUP_DIR" \
        -type f \
        -name 'config-*.json' \
        -mtime +7 \
        -delete 2>/dev/null || true
}

# ============================================================
# INSTALAR XRAY
# ============================================================

install_xray() {

    if [[ -x "$XRAY_BIN" ]] || command -v xray >/dev/null 2>&1; then
        msg_ok "Xray ya está instalado."
        return
    fi

    msg_info "Instalando Xray Core..."

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    if command -v xray >/dev/null 2>&1; then
        msg_ok "Xray instalado correctamente."
    else
        msg_error "No se pudo instalar Xray."
        exit 1
    fi
}

# ============================================================
# SYSTEMD RESILIENCIA
# ============================================================

configure_systemd() {

    mkdir -p /etc/systemd/system/xray.service.d

    cat > /etc/systemd/system/xray.service.d/10-kevintech-resilience.conf <<'EOF'
[Service]
Restart=always
RestartSec=3
LimitNOFILE=1048576
EOF

    systemctl daemon-reload
}

# ============================================================
# CREAR CONFIGURACIÓN BASE
# ============================================================

create_base_config() {

    mkdir -p "$(dirname "$XRAY_CONFIG")"

    if [[ -f "$XRAY_CONFIG" ]]; then
        msg_info "Existe configuración. Se conservará."
        return
    fi

    msg_info "Creando configuración Xray..."

    cat > "$XRAY_CONFIG" <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

    touch /var/log/xray/access.log
    touch /var/log/xray/error.log

    chmod 640 "$XRAY_CONFIG"

    msg_ok "Configuración base creada."
}

# ============================================================
# BUSCAR INBOUND POR TAG
# ============================================================

inbound_exists() {

    local tag="$1"

    jq -e \
        --arg tag "$tag" \
        '.inbounds[]? | select(.tag == $tag)' \
        "$XRAY_CONFIG" \
        >/dev/null 2>&1
}

# ============================================================
# ELIMINAR INBOUND POR TAG
# ============================================================

remove_inbound() {

    local tag="$1"

    jq \
        --arg tag "$tag" \
        '.inbounds = [.inbounds[]? | select(.tag != $tag)]' \
        "$XRAY_CONFIG" \
        > "${XRAY_CONFIG}.tmp"

    mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
}

# ============================================================
# AGREGAR INBOUND
# ============================================================

add_inbound() {

    local protocol="$1"
    local port="$2"
    local tag="$3"
    local path="$4"

    remove_inbound "$tag"

    case "$protocol" in

        vless)

            jq \
                --argjson port "$port" \
                --arg tag "$tag" \
                --arg path "$path" \
                '
                .inbounds += [{
                    "listen":"127.0.0.1",
                    "port":$port,
                    "protocol":"vless",
                    "tag":$tag,
                    "settings":{
                        "clients":[],
                        "decryption":"none"
                    },
                    "streamSettings":{
                        "network":"ws",
                        "security":"none",
                        "wsSettings":{
                            "path":$path
                        }
                    }
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"

            ;;

        vmess)

            jq \
                --argjson port "$port" \
                --arg tag "$tag" \
                --arg path "$path" \
                '
                .inbounds += [{
                    "listen":"127.0.0.1",
                    "port":$port,
                    "protocol":"vmess",
                    "tag":$tag,
                    "settings":{
                        "clients":[]
                    },
                    "streamSettings":{
                        "network":"ws",
                        "security":"none",
                        "wsSettings":{
                            "path":$path
                        }
                    }
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"

            ;;

        trojan)

            jq \
                --argjson port "$port" \
                --arg tag "$tag" \
                --arg path "$path" \
                '
                .inbounds += [{
                    "listen":"127.0.0.1",
                    "port":$port,
                    "protocol":"trojan",
                    "tag":$tag,
                    "settings":{
                        "clients":[]
                    },
                    "streamSettings":{
                        "network":"ws",
                        "security":"none",
                        "wsSettings":{
                            "path":$path
                        }
                    }
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"

            ;;

        grpc)

            jq \
                --argjson port "$port" \
                --arg tag "$tag" \
                --arg service "$path" \
                '
                .inbounds += [{
                    "listen":"127.0.0.1",
                    "port":$port,
                    "protocol":"vless",
                    "tag":$tag,
                    "settings":{
                        "clients":[],
                        "decryption":"none"
                    },
                    "streamSettings":{
                        "network":"grpc",
                        "security":"none",
                        "grpcSettings":{
                            "serviceName":$service,
                            "multiMode":false
                        }
                    }
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"

            ;;

    esac

    mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
}

# ============================================================
# CREAR INBOUNDS
# ============================================================

build_inbounds() {

    msg_info "Preparando los 8 servicios..."

    add_inbound vless 10001 "vless_ws" "/vless"
    add_inbound vmess 10002 "vmess_ws" "/vmess"
    add_inbound trojan 10003 "trojan_ws" "/trojan-ws"
    add_inbound grpc 10004 "vless_grpc" "kt-grpc"

    add_inbound vless 10005 "vless_ws2" "/vless2"
    add_inbound vmess 10006 "vmess_ws2" "/vmess2"
    add_inbound trojan 10007 "trojan_ws2" "/trojan-ws2"
    add_inbound grpc 10008 "vless_grpc2" "kt-grpc2"

    msg_ok "8 inbounds configurados."
}

# ============================================================
# CLIENTE EXISTE
# ============================================================

user_exists() {

    local protocol="$1"
    local username="$2"

    local tag="${P_SERVICE[$protocol]}"

    case "${P_TYPE[$protocol]}" in

        vless)

            jq -e \
                --arg tag "$tag" \
                --arg email "$username" \
                '
                .inbounds[]?
                | select(.tag == $tag)
                | .settings.clients[]?
                | select(.email == $email)
                ' \
                "$XRAY_CONFIG" \
                >/dev/null 2>&1
            ;;

        vmess)

            jq -e \
                --arg tag "$tag" \
                --arg email "$username" \
                '
                .inbounds[]?
                | select(.tag == $tag)
                | .settings.clients[]?
                | select(.email == $email)
                ' \
                "$XRAY_CONFIG" \
                >/dev/null 2>&1
            ;;

        trojan)

            jq -e \
                --arg tag "$tag" \
                --arg email "$username" \
                '
                .inbounds[]?
                | select(.tag == $tag)
                | .settings.clients[]?
                | select(.email == $email)
                ' \
                "$XRAY_CONFIG" \
                >/dev/null 2>&1
            ;;

    esac
}

# ============================================================
# OBTENER UUID
# ============================================================

get_uuid() {

    local protocol="$1"
    local username="$2"

    local tag="${P_SERVICE[$protocol]}"

    jq -r \
        --arg tag "$tag" \
        --arg email "$username" \
        '
        .inbounds[]?
        | select(.tag == $tag)
        | .settings.clients[]?
        | select(.email == $email)
        | .id // empty
        ' \
        "$XRAY_CONFIG" \
        | head -n1
}

# ============================================================
# OBTENER PASSWORD TROJAN
# ============================================================

get_password() {

    local protocol="$1"
    local username="$2"

    local tag="${P_SERVICE[$protocol]}"

    jq -r \
        --arg tag "$tag" \
        --arg email "$username" \
        '
        .inbounds[]?
        | select(.tag == $tag)
        | .settings.clients[]?
        | select(.email == $email)
        | .password // empty
        ' \
        "$XRAY_CONFIG" \
        | head -n1
}

# ============================================================
# AGREGAR CLIENTE
# ============================================================

add_client() {

    local protocol="$1"
    local username="$2"
    local uuid="$3"
    local password="$4"

    local tag="${P_SERVICE[$protocol]}"

    case "${P_TYPE[$protocol]}" in

        vless)

            jq \
                --arg tag "$tag" \
                --arg email "$username" \
                --arg id "$uuid" \
                '
                (.inbounds[] | select(.tag == $tag) | .settings.clients)
                += [{
                    "id":$id,
                    "email":$email,
                    "level":0
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"
            ;;

        vmess)

            jq \
                --arg tag "$tag" \
                --arg email "$username" \
                --arg id "$uuid" \
                '
                (.inbounds[] | select(.tag == $tag) | .settings.clients)
                += [{
                    "id":$id,
                    "email":$email,
                    "level":0
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"
            ;;

        trojan)

            jq \
                --arg tag "$tag" \
                --arg email "$username" \
                --arg password "$password" \
                '
                (.inbounds[] | select(.tag == $tag) | .settings.clients)
                += [{
                    "password":$password,
                    "email":$email,
                    "level":0
                }]
                ' \
                "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"
            ;;

    esac

    mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
}

# ============================================================
# ELIMINAR CLIENTE
# ============================================================

remove_client() {

    local protocol="$1"
    local username="$2"

    local tag="${P_SERVICE[$protocol]}"

    jq \
        --arg tag "$tag" \
        --arg email "$username" \
        '
        (.inbounds[] | select(.tag == $tag) | .settings.clients)
        |= [
            .[]?
            | select(.email != $email)
        ]
        ' \
        "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp"

    mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
}

# ============================================================
# VALIDAR CONFIGURACIÓN
# ============================================================

validate_config() {

    if ! jq empty "$XRAY_CONFIG" >/dev/null 2>&1; then
        msg_error "JSON inválido."
        return 1
    fi

    if ! xray run -test -config "$XRAY_CONFIG" >/tmp/xray-test.log 2>&1; then

        msg_error "Xray rechazó la configuración."

        echo
        cat /tmp/xray-test.log
        echo

        return 1
    fi

    msg_ok "Configuración Xray válida."
    return 0
}

# ============================================================
# REINICIAR
# ============================================================

restart_xray() {

    systemctl daemon-reload

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if systemctl is-active --quiet "$XRAY_SERVICE"; then
        msg_ok "Xray está activo."
    else
        msg_error "Xray no inició."
        systemctl status "$XRAY_SERVICE" --no-pager -l
        return 1
    fi
}

# ============================================================
# PREPARACIÓN
# ============================================================

prepare_xray() {

    install_dependencies
    install_xray
    configure_systemd
    create_base_config
    build_inbounds

    validate_config || exit 1

    systemctl enable xray >/dev/null 2>&1 || true

    restart_xray
}

# ============================================================
# CREAR CUENTA
# ============================================================

create_account_protocol() {

    local protocol="$1"

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ CREAR ${P_NAME[$protocol]}${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo

    read -rp "Usuario: " username

    if [[ -z "$username" ]]; then
        msg_error "Usuario vacío."
        pause
        return
    fi

    if [[ "$username" =~ [^a-zA-Z0-9_.-] ]]; then
        msg_error "Usa solamente letras, números, _, -, ."
        pause
        return
    fi

    if user_exists "$protocol" "$username"; then
        msg_error "La cuenta ya existe en ${P_NAME[$protocol]}."
        pause
        return
    fi

    backup_config

    local uuid
    local password=""

    case "${P_TYPE[$protocol]}" in
        vless|vmess)
            uuid="$(generate_uuid)"
            ;;
        trojan)
            password="$(generate_password)"
            ;;
    esac

    add_client "$protocol" "$username" "$uuid" "$password"

    if ! validate_config; then
        msg_error "Se restaurará el último backup."

        local last_backup
        last_backup="$(find "$BACKUP_DIR" \
            -type f \
            -name 'config-*.json' \
            -printf '%T@ %p\n' \
            | sort -nr \
            | head -n1 \
            | cut -d' ' -f2-)"

        if [[ -n "$last_backup" && -f "$last_backup" ]]; then
            cp "$last_backup" "$XRAY_CONFIG"
        fi

        pause
        return
    fi

    restart_xray

    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              CUENTA CREADA                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo

    echo -e "${WHITE}Usuario:${NC} $username"
    echo -e "${WHITE}Protocolo:${NC} ${P_NAME[$protocol]}"
    echo -e "${WHITE}Puerto interno:${NC} ${P_PORT[$protocol]}"

    if [[ -n "$uuid" ]]; then
        echo -e "${WHITE}UUID:${NC} $uuid"
    fi

    if [[ -n "$password" ]]; then
        echo -e "${WHITE}Password:${NC} $password"
    fi

    echo

    pause
}

# ============================================================
# CREAR TODOS
# ============================================================

create_all() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ CREAR CUENTA EN TODOS LOS PROTOCOLOS              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo

    read -rp "Usuario: " username

    if [[ -z "$username" ]]; then
        msg_error "Usuario vacío."
        pause
        return
    fi

    if [[ "$username" =~ [^a-zA-Z0-9_.-] ]]; then
        msg_error "Nombre de usuario inválido."
        pause
        return
    fi

    local uuid
    local password

    uuid="$(generate_uuid)"
    password="$(generate_password)"

    backup_config

    local p

    for p in "${PROTOCOLS[@]}"; do

        if user_exists "$p" "$username"; then
            echo -e "${YELLOW}[-]${NC} ${P_NAME[$p]} ya existe."
            continue
        fi

        case "${P_TYPE[$p]}" in
            vless|vmess)
                add_client "$p" "$username" "$uuid" ""
                ;;
            trojan)
                add_client "$p" "$username" "$uuid" "$password"
                ;;
        esac

        echo -e "${GREEN}[+]${NC} ${P_NAME[$p]}"
    done

    if ! validate_config; then
        msg_error "Configuración inválida."
        pause
        return
    fi

    restart_xray

    echo
    echo -e "${GREEN}CUENTA MULTIPROTOCOLO CREADA${NC}"
    echo
    echo -e "Usuario : ${WHITE}$username${NC}"
    echo -e "UUID    : ${WHITE}$uuid${NC}"
    echo -e "Trojan  : ${WHITE}$password${NC}"
    echo

    pause
}

# ============================================================
# MENÚ CREAR
# ============================================================

create_menu() {

    while true; do

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                 CREAR CUENTA                      ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
        echo

        echo "  [01] VLESS WS       :10001"
        echo "  [02] VMess WS       :10002"
        echo "  [03] Trojan WS      :10003"
        echo "  [04] VLESS gRPC     :10004"
        echo "  [05] VLESS WS 2     :10005"
        echo "  [06] VMess WS 2     :10006"
        echo "  [07] Trojan WS 2    :10007"
        echo "  [08] VLESS gRPC 2   :10008"
        echo
        echo -e "  ${GREEN}[09] TODOS LOS PROTOCOLOS${NC}"
        echo
        echo "  [00] Regresar"
        echo

        read -rp "Selecciona: " op

        case "$op" in
            1|01) create_account_protocol vless ;;
            2|02) create_account_protocol vmess ;;
            3|03) create_account_protocol trojan ;;
            4|04) create_account_protocol grpc ;;
            5|05) create_account_protocol vless2 ;;
            6|06) create_account_protocol vmess2 ;;
            7|07) create_account_protocol trojan2 ;;
            8|08) create_account_protocol grpc2 ;;
            9|09) create_all ;;
            0|00) return ;;
            *) msg_error "Opción inválida"; sleep 1 ;;
        esac

    done
}

# ============================================================
# ELIMINAR TODOS
# ============================================================

delete_all() {

    clear

    read -rp "Usuario a eliminar de TODOS los protocolos: " username

    if [[ -z "$username" ]]; then
        return
    fi

    echo
    read -rp "Confirmar eliminación de $username [s/N]: " confirm

    [[ "$confirm" =~ ^[SsYy]$ ]] || return

    backup_config

    local p

    for p in "${PROTOCOLS[@]}"; do

        if user_exists "$p" "$username"; then
            remove_client "$p" "$username"
            echo -e "${GREEN}[OK]${NC} ${P_NAME[$p]}"
        else
            echo -e "${GRAY}[-]${NC} No existe en ${P_NAME[$p]}"
        fi

    done

    validate_config || return
    restart_xray

    msg_ok "Usuario eliminado de todos los protocolos."

    pause
}

# ============================================================
# ELIMINAR INDIVIDUAL
# ============================================================

delete_account_protocol() {

    local protocol="$1"

    clear

    echo -e "${CYAN}Eliminar: ${P_NAME[$protocol]}${NC}"
    echo

    read -rp "Usuario: " username

    if ! user_exists "$protocol" "$username"; then
        msg_error "La cuenta no existe."
        pause
        return
    fi

    read -rp "¿Eliminar $username? [s/N]: " confirm

    [[ "$confirm" =~ ^[SsYy]$ ]] || return

    backup_config

    remove_client "$protocol" "$username"

    if ! validate_config; then
        msg_error "Error en configuración."
        return
    fi

    restart_xray

    msg_ok "Cuenta eliminada."

    pause
}

# ============================================================
# MENÚ ELIMINAR
# ============================================================

delete_menu() {

    while true; do

        clear

        echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                ELIMINAR CUENTA                    ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
        echo

        echo "  [01] VLESS WS"
        echo "  [02] VMess WS"
        echo "  [03] Trojan WS"
        echo "  [04] VLESS gRPC"
        echo "  [05] VLESS WS 2"
        echo "  [06] VMess WS 2"
        echo "  [07] Trojan WS 2"
        echo "  [08] VLESS gRPC 2"
        echo
        echo -e "  ${RED}[09] TODOS LOS PROTOCOLOS${NC}"
        echo
        echo "  [00] Regresar"
        echo

        read -rp "Selecciona: " op

        case "$op" in
            1|01) delete_account_protocol vless ;;
            2|02) delete_account_protocol vmess ;;
            3|03) delete_account_protocol trojan ;;
            4|04) delete_account_protocol grpc ;;
            5|05) delete_account_protocol vless2 ;;
            6|06) delete_account_protocol vmess2 ;;
            7|07) delete_account_protocol trojan2 ;;
            8|08) delete_account_protocol grpc2 ;;
            9|09) delete_all ;;
            0|00) return ;;
            *) msg_error "Opción inválida"; sleep 1 ;;
        esac

    done
}

# ============================================================
# LISTAR CUENTAS
# ============================================================

list_accounts() {

    clear

    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    CUENTAS XRAY${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo

    local p
    local found=0

    for p in "${PROTOCOLS[@]}"; do

        echo -e "${MAGENTA}▶ ${P_NAME[$p]}${NC}"

        local tag="${P_SERVICE[$p]}"

        jq -r \
            --arg tag "$tag" \
            '
            .inbounds[]?
            | select(.tag == $tag)
            | .settings.clients[]?
            | .email
            ' \
            "$XRAY_CONFIG" 2>/dev/null \
            | while read -r username; do
                [[ -n "$username" ]] &&
                    echo "   • $username"
            done

        echo

    done

    pause
}

# ============================================================
# GENERAR VLESS
# ============================================================

vless_link() {

    local username="$1"
    local protocol="$2"

    local uuid
    uuid="$(get_uuid "$protocol" "$username")"

    [[ -z "$uuid" ]] && return

    local path="${P_PATH[$protocol]}"

    local encoded

    encoded="$(python3 - "$SERVER_ADDRESS" "$EXTERNAL_PORT" "$uuid" "$path" "$SERVER_DOMAIN" <<'PY'
import sys
import urllib.parse

address=sys.argv[1]
port=sys.argv[2]
uuid=sys.argv[3]
path=sys.argv[4]
sni=sys.argv[5]

params={
    "encryption":"none",
    "security":"tls",
    "type":"ws",
    "host":address,
    "path":path
}

if sni:
    params["sni"]=sni

print(
    "vless://"
    + uuid
    + "@"
    + address
    + ":"
    + port
    + "?"
    + urllib.parse.urlencode(params)
    + "#"
    + urllib.parse.quote(username)
)
PY
)"

    echo "$encoded"
}

# ============================================================
# GENERAR VMESS
# ============================================================

vmess_link() {

    local username="$1"
    local protocol="$2"

    local uuid
    uuid="$(get_uuid "$protocol" "$username")"

    [[ -z "$uuid" ]] && return

    local path="${P_PATH[$protocol]}"

    python3 - "$SERVER_ADDRESS" "$EXTERNAL_PORT" "$uuid" "$path" "$SERVER_DOMAIN" "$username" <<'PY'
import sys
import json
import base64

address=sys.argv[1]
port=int(sys.argv[2])
uuid=sys.argv[3]
path=sys.argv[4]
sni=sys.argv[5]
username=sys.argv[6]

obj={
    "v":"2",
    "ps":username,
    "add":address,
    "port":str(port),
    "id":uuid,
    "aid":"0",
    "scy":"auto",
    "net":"ws",
    "type":"none",
    "host":address,
    "path":path,
    "tls":"tls",
    "sni":sni
}

raw=json.dumps(obj,separators=(",",":")).encode()
print("vmess://" + base64.b64encode(raw).decode())
PY
}

# ============================================================
# GENERAR TROJAN
# ============================================================

trojan_link() {

    local username="$1"
    local protocol="$2"

    local password
    password="$(get_password "$protocol" "$username")"

    [[ -z "$password" ]] && return

    local path="${P_PATH[$protocol]}"

    python3 - "$password" "$SERVER_ADDRESS" "$EXTERNAL_PORT" "$path" "$SERVER_DOMAIN" "$username" <<'PY'
import sys
import urllib.parse

password=sys.argv[1]
address=sys.argv[2]
port=sys.argv[3]
path=sys.argv[4]
sni=sys.argv[5]
username=sys.argv[6]

q={
    "security":"tls",
    "type":"ws",
    "host":address,
    "path":path
}

if sni:
    q["sni"]=sni

print(
    "trojan://"
    + urllib.parse.quote(password,safe="")
    + "@"
    + address
    + ":"
    + port
    + "?"
    + urllib.parse.urlencode(q)
    + "#"
    + urllib.parse.quote(username)
)
PY
}

# ============================================================
# GENERAR GRPC
# ============================================================

grpc_link() {

    local username="$1"
    local protocol="$2"

    local uuid
    uuid="$(get_uuid "$protocol" "$username")"

    [[ -z "$uuid" ]] && return

    local service="${P_PATH[$protocol]}"

    python3 - "$uuid" "$SERVER_ADDRESS" "$EXTERNAL_PORT" "$service" "$SERVER_DOMAIN" "$username" <<'PY'
import sys
import urllib.parse

uuid=sys.argv[1]
address=sys.argv[2]
port=sys.argv[3]
service=sys.argv[4]
sni=sys.argv[5]
username=sys.argv[6]

q={
    "encryption":"none",
    "security":"tls",
    "type":"grpc",
    "serviceName":service
}

if sni:
    q["sni"]=sni

print(
    "vless://"
    + uuid
    + "@"
    + address
    + ":"
    + port
    + "?"
    + urllib.parse.urlencode(q)
    + "#"
    + urllib.parse.quote(username)
)
PY
}

# ============================================================
# MOSTRAR ENLACES
# ============================================================

show_links() {

    clear

    read -rp "Usuario: " username

    echo

    local p

    for p in "${PROTOCOLS[@]}"; do

        if ! user_exists "$p" "$username"; then
            continue
        fi

        echo -e "${CYAN}━━━━━━━━ ${P_NAME[$p]} ━━━━━━━━${NC}"

        case "${P_TYPE[$p]}" in

            vless)
                vless_link "$username" "$p"
                ;;

            vmess)
                vmess_link "$username" "$p"
                ;;

            trojan)
                trojan_link "$username" "$p"
                ;;

        esac

        echo

    done

    pause
}

# ============================================================
# DETECTAR USUARIOS ONLINE
# ============================================================

online_users() {

    clear

    echo -e "${CYAN}USUARIOS ONLINE${NC}"
    echo

    if [[ ! -f "$LOG_FILE" ]]; then
        msg_warn "No existe access.log."
        pause
        return
    fi

    echo -e "${WHITE}Últimos 60 segundos:${NC}"
    echo

    awk -v now="$(date +%s)" '
    {
        # Xray puede variar el formato del log.
        # Mostramos coincidencias recientes de email.
        if ($0 ~ /email:/)
            print
    }
    ' "$LOG_FILE" | tail -50

    echo

    pause
}

# ============================================================
# ESTADO
# ============================================================

status_xray() {

    clear

    echo -e "${CYAN}ESTADO XRAY${NC}"
    echo

    systemctl status xray --no-pager -l

    echo
    echo -e "${CYAN}PUERTOS:${NC}"

    ss -lntp 2>/dev/null | grep -E \
        ':(10001|10002|10003|10004|10005|10006|10007|10008)\b' \
        || echo "No hay puertos Xray escuchando."

    pause
}

# ============================================================
# DIAGNÓSTICO
# ============================================================

diagnostic() {

    clear

    echo -e "${CYAN}DIAGNÓSTICO XRAY${NC}"
    echo

    echo -e "${WHITE}Binario:${NC}"
    command -v xray || true

    echo
    echo -e "${WHITE}Versión:${NC}"
    xray version 2>/dev/null || true

    echo
    echo -e "${WHITE}Configuración:${NC}"
    echo "$XRAY_CONFIG"

    echo
    echo -e "${WHITE}Servidor:${NC}"
    echo "$SERVER_ADDRESS"

    echo
    echo -e "${WHITE}Dominio:${NC}"
    echo "${SERVER_DOMAIN:-NO CONFIGURADO}"

    echo
    echo -e "${WHITE}IP:${NC}"
    echo "$SERVER_IP"

    echo
    echo -e "${WHITE}Test:${NC}"

    if validate_config; then
        echo -e "${GREEN}CONFIGURACIÓN OK${NC}"
    else
        echo -e "${RED}CONFIGURACIÓN CON ERRORES${NC}"
    fi

    echo

    pause
}

# ============================================================
# LOGS
# ============================================================

show_logs() {

    clear

    echo -e "${CYAN}LOG XRAY${NC}"
    echo

    if [[ -f /var/log/xray/error.log ]]; then
        tail -n 80 /var/log/xray/error.log
    fi

    echo
    echo "------------------------------------------------------------"

    if [[ -f "$LOG_FILE" ]]; then
        tail -n 80 "$LOG_FILE"
    fi

    pause
}

# ============================================================
# REINICIAR
# ============================================================

restart_menu() {

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray; then
        msg_ok "Xray reiniciado correctamente."
    else
        msg_error "Xray no está funcionando."
    fi

    pause
}

# ============================================================
# INFORMACIÓN
# ============================================================

show_info() {

    clear

    load_server_address

    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    INFORMACIÓN XRAY                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${WHITE}Dirección:${NC} $SERVER_ADDRESS"
    echo -e "${WHITE}IP:${NC} $SERVER_IP"
    echo -e "${WHITE}Dominio:${NC} ${SERVER_DOMAIN:-NO CONFIGURADO}"
    echo -e "${WHITE}Puerto externo:${NC} $EXTERNAL_PORT"
    echo

    for p in "${PROTOCOLS[@]}"; do
        echo -e "${GREEN}${P_NAME[$p]}${NC}"
        echo "  Interno : 127.0.0.1:${P_PORT[$p]}"
        echo "  Ruta     : ${P_PATH[$p]}"
        echo "  Tag      : ${P_SERVICE[$p]}"
        echo
    done

    pause
}

# ============================================================
# ACTUALIZAR ESTRUCTURA
# ============================================================

update_xray_config() {

    clear

    echo -e "${CYAN}Actualizando estructura Xray...${NC}"
    echo

    backup_config

    build_inbounds

    if validate_config; then
        restart_xray
        msg_ok "Estructura actualizada."
    else
        msg_error "La actualización produjo una configuración inválida."
    fi

    pause
}

# ============================================================
# DESINSTALAR
# ============================================================

uninstall_xray() {

    clear

    echo -e "${RED}ADVERTENCIA${NC}"
    echo
    echo "Esto eliminará Xray y su configuración."
    echo

    read -rp "Escribe ELIMINAR para continuar: " confirm

    [[ "$confirm" == "ELIMINAR" ]] || return

    systemctl disable --now xray 2>/dev/null || true

    rm -rf /etc/systemd/system/xray.service.d

    systemctl daemon-reload

    if [[ -f /usr/local/bin/xray ]]; then
        rm -f /usr/local/bin/xray
    fi

    rm -rf /usr/local/etc/xray

    msg_ok "Xray eliminado."

    pause
}

# ============================================================
# MENU PRINCIPAL
# ============================================================

main_menu() {

    while true; do

        load_server_address

        header

        echo -e "${WHITE}Servidor:${NC} ${GREEN}$SERVER_ADDRESS${NC}"
        echo -e "${WHITE}IP:${NC} ${GREEN}$SERVER_IP${NC}"
        echo -e "${WHITE}Dominio:${NC} ${GREEN}${SERVER_DOMAIN:-NO CONFIGURADO}${NC}"

        if systemctl is-active --quiet xray; then
            echo -e "${WHITE}Xray:${NC} ${GREEN}● ACTIVO${NC}"
        else
            echo -e "${WHITE}Xray:${NC} ${RED}● DETENIDO${NC}"
        fi

        echo
        echo "════════════════════════════════════════════════════════════"
        echo

        echo -e "  ${GREEN}[01]${NC} Crear cuenta"
        echo -e "  ${RED}[02]${NC} Eliminar cuenta"
        echo -e "  ${CYAN}[03]${NC} Listar cuentas"
        echo -e "  ${MAGENTA}[04]${NC} Mostrar enlaces"
        echo -e "  ${YELLOW}[05]${NC} Usuarios online"
        echo
        echo -e "  ${GREEN}[06]${NC} Estado Xray"
        echo -e "  ${GREEN}[07]${NC} Diagnóstico"
        echo -e "  ${GREEN}[08]${NC} Ver logs"
        echo -e "  ${GREEN}[09]${NC} Reiniciar Xray"
        echo -e "  ${GREEN}[10]${NC} Actualizar configuración"
        echo -e "  ${RED}[11]${NC} Desinstalar Xray"
        echo
        echo -e "  ${WHITE}[00]${NC} Salir"
        echo

        read -rp "Selecciona una opción: " op

        case "$op" in

            1|01)
                create_menu
                ;;

            2|02)
                delete_menu
                ;;

            3|03)
                list_accounts
                ;;

            4|04)
                show_links
                ;;

            5|05)
                online_users
                ;;

            6|06)
                status_xray
                ;;

            7|07)
                diagnostic
                ;;

            8|08)
                show_logs
                ;;

            9|09)
                restart_menu
                ;;

            10)
                update_xray_config
                ;;

            11)
                uninstall_xray
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
}

# ============================================================
# INICIO
# ============================================================

require_root

install_dependencies
install_xray
configure_systemd
create_base_config
build_inbounds

if ! validate_config; then
    msg_error "La configuración inicial no es válida."
    exit 1
fi

systemctl enable xray >/dev/null 2>&1 || true

if ! systemctl is-active --quiet xray; then
    systemctl start xray || true
fi

main_menu