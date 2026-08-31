#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    XRAY MANAGER v5.5
# ==============================================================
#
# Core:
#   Xray
#
# Protocolos:
#   VLESS
#   VMess
#   Trojan
#   gRPC (VLESS + gRPC)
#
# Administración:
#   Crear cuenta
#   Listar cuentas
#   Eliminar cuenta
#   Generar enlaces
#
# Host:
#   Dominio si existe
#   IP pública si no existe dominio
#
# IMPORTANTE:
#   Este script NO CREA BACKUPS.
#
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"

XRAY_LOG_DIR="/var/log/xray"
XRAY_LOG="$XRAY_LOG_DIR/access.log"

XRAY_SERVICE="xray"

VERSION="5.5"

# ==============================================================
# PUERTOS INTERNOS
# ==============================================================

VLESS_PORT="10001"
VMESS_PORT="10002"
TROJAN_PORT="10003"
GRPC_PORT="10004"

# ==============================================================
# PATH / SERVICE
# ==============================================================

VLESS_PATH="/vless"
VMESS_PATH="/vmess"
TROJAN_PATH="/trojan-ws"

GRPC_SERVICE="xray-grpc"

PUBLIC_PORT="443"

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
    echo -e "${WHITE}Xray Manager requiere permisos de root.${RESET}"
    echo

    exit 1
fi

# ==============================================================
# CONFIG
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
# VISUAL
# ==============================================================

line() {

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

header() {

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                  ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}                   ${GRAY}v$VERSION${RESET}                            ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${CYAN}║${RESET}       ${WHITE}VLESS / VMess / Trojan / gRPC${RESET}                    ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

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

    if grep -q "^${KEY}=" "$CONFIG"; then

        sed -i \
            "s|^${KEY}=.*|${KEY}=${VALUE}|" \
            "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi
}

# ==============================================================
# XRAY
# ==============================================================

xray_installed() {

    command -v xray >/dev/null 2>&1
}

xray_active() {

    systemctl is-active \
        --quiet "$XRAY_SERVICE" 2>/dev/null
}

# ==============================================================
# OBTENER HOST
# ==============================================================

get_public_ip() {

    local IP=""

    if command -v curl >/dev/null 2>&1; then

        IP=$(curl -4 -fsS \
            --connect-timeout 3 \
            --max-time 5 \
            https://api.ipify.org 2>/dev/null)

    fi

    if [[ -z "$IP" ]]; then

        IP=$(
            ip -4 route get 1.1.1.1 2>/dev/null |
            awk '
                {
                    for (i=1;i<=NF;i++)
                        if ($i=="src") {
                            print $(i+1)
                            exit
                        }
                }
            '
        )

    fi

    echo "$IP"
}

load_host() {

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    DOMAIN="${SERVER_DOMAIN:-}"

    DOMAIN="$(echo "$DOMAIN" | xargs 2>/dev/null)"

    if [[ -z "$DOMAIN" &&
          -f /etc/xray/domain ]]; then

        DOMAIN=$(cat /etc/xray/domain 2>/dev/null |
            head -1 |
            xargs)

    fi

    if [[ -n "$DOMAIN" ]]; then

        XRAY_HOST="$DOMAIN"
        HOST_TYPE="DOMINIO"

    else

        XRAY_HOST=$(get_public_ip)
        HOST_TYPE="IP"

    fi
}

# Compatibilidad con funciones antiguas
load_domain() {

    load_host

    DOMAIN="$XRAY_HOST"
}

# ==============================================================
# UUID
# ==============================================================

generate_uuid() {

    if [[ -r /proc/sys/kernel/random/uuid ]]; then

        cat /proc/sys/kernel/random/uuid

        return 0
    fi

    if command -v uuidgen >/dev/null 2>&1; then

        uuidgen

        return 0
    fi

    error_msg "No se pudo generar UUID."

    return 1
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
        unzip \
        jq \
        socat \
        cron \
        ca-certificates \
        uuid-runtime \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."

        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# DIRECTORIOS
# ==============================================================

create_directories() {

    mkdir -p "$XRAY_DIR"
    mkdir -p "$XRAY_LOG_DIR"

    touch "$XRAY_LOG"

    chmod 755 "$XRAY_DIR"
    chmod 755 "$XRAY_LOG_DIR"

    chmod 640 "$XRAY_LOG"
}

# ==============================================================
# VALIDAR JSON
# ==============================================================

validate_json_file() {

    local FILE="$1"

    [[ -f "$FILE" ]] || return 1

    command -v jq >/dev/null 2>&1 || return 1

    jq empty "$FILE" >/dev/null 2>&1
}

validate_json() {

    validate_json_file "$XRAY_CFG"
}

# ==============================================================
# VALIDAR CONFIGURACIÓN XRAY
# ==============================================================

validate_xray_file() {

    local FILE="$1"

    if [[ ! -f "$FILE" ]]; then

        error_msg "Archivo de configuración inexistente."

        return 1
    fi

    if ! validate_json_file "$FILE"; then

        error_msg "JSON inválido."

        return 1
    fi

    local TEST_LOG

    TEST_LOG=$(mktemp --suffix=.log)

    if ! xray run \
        -test \
        -config "$FILE" \
        >"$TEST_LOG" 2>&1; then

        cat "$TEST_LOG"

        rm -f "$TEST_LOG"

        return 1
    fi

    rm -f "$TEST_LOG"

    return 0
}

validate_xray_config() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    validate_xray_file "$XRAY_CFG"
}

# ==============================================================
# ÍNDICES
# ==============================================================

inbound_index() {

    case "$1" in

        vless)
            echo 0
            ;;

        vmess)
            echo 1
            ;;

        trojan)
            echo 2
            ;;

        grpc)
            echo 3
            ;;

        *)
            return 1
            ;;

    esac
}

# ==============================================================
# PROTOCOLO
# ==============================================================

protocol_name() {

    case "$1" in

        vless)
            echo "VLESS"
            ;;

        vmess)
            echo "VMess"
            ;;

        trojan)
            echo "Trojan"
            ;;

        grpc)
            echo "gRPC"
            ;;

        *)
            echo "$1"
            ;;

    esac
}

# ==============================================================
# CLIENTES VACÍOS
# ==============================================================

empty_clients() {

    echo '[]'
}

# ==============================================================
# CONFIGURACIÓN BASE LIMPIA
# ==============================================================

create_clean_config() {

    mkdir -p "$XRAY_DIR"

    cat > "$XRAY_CFG" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$XRAY_LOG"
  },

  "inbounds": [

    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": $VLESS_PORT,
      "protocol": "vless",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "$VLESS_PATH"
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "tag": "vmess-ws",
      "listen": "127.0.0.1",
      "port": $VMESS_PORT,
      "protocol": "vmess",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "$VMESS_PATH"
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "tag": "trojan-ws",
      "listen": "127.0.0.1",
      "port": $TROJAN_PORT,
      "protocol": "trojan",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "$TROJAN_PATH"
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "tag": "grpc",
      "listen": "127.0.0.1",
      "port": $GRPC_PORT,
      "protocol": "vless",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "grpc",

        "grpcSettings": {
          "serviceName": "$GRPC_SERVICE"
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }

  ],

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

    chmod 600 "$XRAY_CFG"

    validate_json
}

# ==============================================================
# ASEGURAR CONFIGURACIÓN MULTIPROTOCOLO
# ==============================================================

ensure_multiprotocol_config() {

    create_directories

    # ----------------------------------------------------------
    # Si no existe o no es JSON válido, crear limpio.
    # ----------------------------------------------------------

    if [[ ! -f "$XRAY_CFG" ]] ||
       ! validate_json; then

        info "Creando configuración Xray multiprotocolo..."

        if ! create_clean_config; then

            error_msg "No se pudo crear config.json."

            return 1
        fi

        ok "Configuración multiprotocolo creada."

        return 0
    fi

    # ----------------------------------------------------------
    # Detectar inbounds.
    # ----------------------------------------------------------

    local COUNT

    COUNT=$(jq '.inbounds | length' \
        "$XRAY_CFG" 2>/dev/null)

    COUNT="${COUNT:-0}"

    # ----------------------------------------------------------
    # Si no hay inbounds, crear configuración limpia.
    # ----------------------------------------------------------

    if [[ "$COUNT" -eq 0 ]]; then

        info "No existen inbounds."

        info "Inicializando configuración multiprotocolo..."

        if ! create_clean_config; then

            error_msg "No se pudo inicializar Xray."

            return 1
        fi

        ok "VLESS / VMess / Trojan / gRPC preparados."

        return 0
    fi

    # ----------------------------------------------------------
    # Verificar que existan los cuatro protocolos.
    # Si falta alguno, reconstruimos conservando clientes.
    # ----------------------------------------------------------

    local HAS_VLESS
    local HAS_VMESS
    local HAS_TROJAN
    local HAS_GRPC

    HAS_VLESS=$(
        jq '[.inbounds[]? | select(.protocol=="vless" and
            (.streamSettings.network=="ws"))] | length' \
            "$XRAY_CFG" 2>/dev/null
    )

    HAS_VMESS=$(
        jq '[.inbounds[]? | select(.protocol=="vmess" and
            (.streamSettings.network=="ws"))] | length' \
            "$XRAY_CFG" 2>/dev/null
    )

    HAS_TROJAN=$(
        jq '[.inbounds[]? | select(.protocol=="trojan" and
            (.streamSettings.network=="ws"))] | length' \
            "$XRAY_CFG" 2>/dev/null
    )

    HAS_GRPC=$(
        jq '[.inbounds[]? | select(.protocol=="vless" and
            (.streamSettings.network=="grpc"))] | length' \
            "$XRAY_CFG" 2>/dev/null
    )

    if [[ "$HAS_VLESS" -ge 1 &&
          "$HAS_VMESS" -ge 1 &&
          "$HAS_TROJAN" -ge 1 &&
          "$HAS_GRPC" -ge 1 ]]; then

        return 0
    fi

    # ----------------------------------------------------------
    # Crear configuración nueva conservando clientes.
    # NO BACKUP.
    # ----------------------------------------------------------

    info "Actualizando estructura multiprotocolo..."

    local OLD="$XRAY_CFG"
    local NEW

    NEW=$(mktemp --suffix=.json)

    local VLESS_CLIENTS='[]'
    local VMESS_CLIENTS='[]'
    local TROJAN_CLIENTS='[]'
    local GRPC_CLIENTS='[]'

    VLESS_CLIENTS=$(
        jq -c '
            [
                .inbounds[]?
                | select(
                    .protocol=="vless"
                    and
                    .streamSettings.network=="ws"
                )
                | .settings.clients[]?
            ]
        ' "$OLD" 2>/dev/null
    )

    VMESS_CLIENTS=$(
        jq -c '
            [
                .inbounds[]?
                | select(
                    .protocol=="vmess"
                    and
                    .streamSettings.network=="ws"
                )
                | .settings.clients[]?
            ]
        ' "$OLD" 2>/dev/null
    )

    TROJAN_CLIENTS=$(
        jq -c '
            [
                .inbounds[]?
                | select(
                    .protocol=="trojan"
                    and
                    .streamSettings.network=="ws"
                )
                | .settings.clients[]?
            ]
        ' "$OLD" 2>/dev/null
    )

    GRPC_CLIENTS=$(
        jq -c '
            [
                .inbounds[]?
                | select(
                    .protocol=="vless"
                    and
                    .streamSettings.network=="grpc"
                )
                | .settings.clients[]?
            ]
        ' "$OLD" 2>/dev/null
    )

    [[ -z "$VLESS_CLIENTS" ]] && VLESS_CLIENTS='[]'
    [[ -z "$VMESS_CLIENTS" ]] && VMESS_CLIENTS='[]'
    [[ -z "$TROJAN_CLIENTS" ]] && TROJAN_CLIENTS='[]'
    [[ -z "$GRPC_CLIENTS" ]] && GRPC_CLIENTS='[]'

    cat > "$NEW" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$XRAY_LOG"
  },

  "inbounds": [

    {
      "tag": "vless-ws",
      "listen": "127.0.0.1",
      "port": $VLESS_PORT,
      "protocol": "vless",
      "settings": {
        "clients": $VLESS_CLIENTS,
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$VLESS_PATH"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "tag": "vmess-ws",
      "listen": "127.0.0.1",
      "port": $VMESS_PORT,
      "protocol": "vmess",
      "settings": {
        "clients": $VMESS_CLIENTS
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$VMESS_PATH"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "tag": "trojan-ws",
      "listen": "127.0.0.1",
      "port": $TROJAN_PORT,
      "protocol": "trojan",
      "settings": {
        "clients": $TROJAN_CLIENTS
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$TROJAN_PATH"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },

    {
      "tag": "grpc",
      "listen": "127.0.0.1",
      "port": $GRPC_PORT,
      "protocol": "vless",
      "settings": {
        "clients": $GRPC_CLIENTS,
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "$GRPC_SERVICE"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }

  ],

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

    if ! validate_json_file "$NEW"; then

        rm -f "$NEW"

        error_msg "La nueva configuración JSON es inválida."

        return 1
    fi

    # ----------------------------------------------------------
    # MUY IMPORTANTE:
    # probar el archivo temporal ANTES de reemplazar.
    # ----------------------------------------------------------

    info "Validando configuración multiprotocolo..."

    if ! validate_xray_file "$NEW"; then

        rm -f "$NEW"

        error_msg "Xray rechazó la nueva configuración."

        warning "El config.json actual NO fue modificado."

        return 1
    fi

    mv -f "$NEW" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    ok "Configuración multiprotocolo actualizada."

    return 0
}

# ==============================================================
# INSTALAR XRAY CORE
# ==============================================================

install_xray_core() {

    info "Instalando Xray Core..."

    local INSTALLER="/tmp/xray-install.sh"

    rm -f "$INSTALLER"

    if ! curl -fL \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        -o "$INSTALLER"; then

        error_msg "No se pudo descargar el instalador oficial."

        rm -f "$INSTALLER"

        return 1
    fi

    chmod 700 "$INSTALLER"

    if ! bash "$INSTALLER" install; then

        error_msg "El instalador de Xray devolvió un error."

        rm -f "$INSTALLER"

        return 1
    fi

    rm -f "$INSTALLER"

    if ! command -v xray >/dev/null 2>&1; then

        error_msg "Xray no quedó disponible."

        return 1
    fi

    ok "Xray Core instalado."

    return 0
}

# ==============================================================
# RESILIENCIA
# ==============================================================

ensure_xray_resilience() {

    local DIR="/etc/systemd/system/xray.service.d"
    local FILE="$DIR/10-kevintech-resilience.conf"

    mkdir -p "$DIR"

    cat > "$FILE" <<EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
EOF

    systemctl daemon-reload

    systemctl enable "$XRAY_SERVICE" \
        >/dev/null 2>&1

    ok "Recuperación automática configurada."
}

# ==============================================================
# INSTALAR / ACTUALIZAR XRAY
# ==============================================================

install_xray() {

    header

    echo -e \
        "${WHITE}${BOLD}          INSTALACIÓN XRAY MULTIPROTOCOLO${RESET}"

    line

    echo

    install_dependencies || {

        pause

        return 1
    }

    install_xray_core || {

        pause

        return 1
    }

    create_directories

    if ! ensure_multiprotocol_config; then

        pause

        return 1
    fi

    ensure_xray_resilience

    echo

    info "Validando configuración final..."

    if ! validate_xray_config; then

        error_msg "Xray rechazó config.json."

        pause

        return 1
    fi

    info "Reiniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        ok "Xray está activo."

    else

        set_config "XRAY" "OFF"

        error_msg "Xray no pudo iniciar."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 25 \
            --no-pager 2>/dev/null

        pause

        return 1
    fi

    echo

    load_host

    echo -e \
        "${WHITE}Host:${RESET} ${GREEN}$XRAY_HOST${RESET}"

    echo -e \
        "${WHITE}Tipo:${RESET} ${GREEN}$HOST_TYPE${RESET}"

    echo

    ok "VLESS / VMess / Trojan / gRPC disponibles."

    pause

    return 0
}

# ==============================================================
# EXISTE USUARIO
# ==============================================================

user_exists() {

    local PROTOCOL="$1"
    local USERNAME="$2"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return 1

    jq -e \
        --arg email "$USERNAME" \
        --argjson index "$INDEX" \
        '
        .inbounds[$index].settings.clients
        | any(.email == $email)
        ' \
        "$XRAY_CFG" \
        >/dev/null 2>&1
}

# ==============================================================
# OBTENER ID
# ==============================================================

get_user_id() {

    local PROTOCOL="$1"
    local USERNAME="$2"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return 1

    jq -r \
        --arg email "$USERNAME" \
        --argjson index "$INDEX" \
        '
        .inbounds[$index].settings.clients[]
        | select(.email == $email)
        | (.id // .password)
        ' \
        "$XRAY_CFG" 2>/dev/null
}

# ==============================================================
# TOTAL USUARIOS
# ==============================================================

count_users() {

    local PROTOCOL="$1"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || {

        echo 0

        return
    }

    jq -r \
        --argjson index "$INDEX" \
        '
        .inbounds[$index].settings.clients | length
        ' \
        "$XRAY_CFG" 2>/dev/null
}

# ==============================================================
# CREAR UNA CUENTA
# ==============================================================

create_user() {

    local PROTOCOL="$1"

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    if ! ensure_multiprotocol_config; then

        return 1
    fi

    if ! validate_xray_config; then

        error_msg "La configuración actual de Xray no es válida."

        return 1
    fi

    load_host

    if [[ -z "$XRAY_HOST" ]]; then

        error_msg "No se pudo obtener dominio ni IP."

        return 1
    fi

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || {

        error_msg "Protocolo inválido."

        return 1
    }

    echo

    echo -e \
        "${WHITE}${BOLD}Crear cuenta $(protocol_name "$PROTOCOL")${RESET}"

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Nombre del usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if [[ -z "$USERNAME" ]]; then

        error_msg "El usuario no puede estar vacío."

        return 1
    fi

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre de usuario inválido."

        return 1
    fi

    if user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg \
            "El usuario '$USERNAME' ya existe en $(protocol_name "$PROTOCOL")."

        return 1
    fi

    local ID

    ID=$(generate_uuid) || return 1

    local TMP

    TMP=$(mktemp --suffix=.json)

    # ----------------------------------------------------------
    # VMESS / VLESS / GRPC
    # ----------------------------------------------------------

    if [[ "$PROTOCOL" == "vmess" ||
          "$PROTOCOL" == "vless" ||
          "$PROTOCOL" == "grpc" ]]; then

        if ! jq \
            --arg uuid "$ID" \
            --arg email "$USERNAME" \
            --argjson index "$INDEX" \
            '
            .inbounds[$index].settings.clients += [
                {
                    "id": $uuid,
                    "level": 0,
                    "email": $email
                }
            ]
            ' \
            "$XRAY_CFG" > "$TMP"; then

            rm -f "$TMP"

            error_msg "No se pudo crear la cuenta."

            return 1
        fi

    # ----------------------------------------------------------
    # TROJAN
    # ----------------------------------------------------------

    else

        if ! jq \
            --arg password "$ID" \
            --arg email "$USERNAME" \
            --argjson index "$INDEX" \
            '
            .inbounds[$index].settings.clients += [
                {
                    "password": $password,
                    "level": 0,
                    "email": $email
                }
            ]
            ' \
            "$XRAY_CFG" > "$TMP"; then

            rm -f "$TMP"

            error_msg "No se pudo crear la cuenta."

            return 1
        fi

    fi

    # ----------------------------------------------------------
    # JSON
    # ----------------------------------------------------------

    if ! validate_json_file "$TMP"; then

        rm -f "$TMP"

        error_msg "La configuración generada no es JSON válida."

        return 1
    fi

    # ----------------------------------------------------------
    # VALIDAR CON XRAY ANTES DE MODIFICAR
    # ----------------------------------------------------------

    info "Validando configuración..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "Xray rechazó la configuración."

        warning "El config.json NO fue modificado."

        return 1
    fi

    # ----------------------------------------------------------
    # AHORA SÍ REEMPLAZAR
    # ----------------------------------------------------------

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if ! xray_active; then

        error_msg "Xray no inició después de crear la cuenta."

        return 1
    fi

    CREATED_PROTOCOL="$PROTOCOL"
    CREATED_USER="$USERNAME"
    CREATED_ID="$ID"

    ok "Cuenta $(protocol_name "$PROTOCOL") creada."

    return 0
}

# ==============================================================
# CREAR TODOS
# ==============================================================

create_all_user() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    if ! ensure_multiprotocol_config; then

        return 1
    fi

    load_host

    if [[ -z "$XRAY_HOST" ]]; then

        error_msg "No se pudo obtener dominio ni IP."

        return 1
    fi

    echo

    echo -e \
        "${WHITE}${BOLD}⭐ CREAR CUENTA MULTIPROTOCOLO${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Nombre del usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if [[ -z "$USERNAME" ]]; then

        error_msg "Usuario vacío."

        return 1
    fi

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre de usuario inválido."

        return 1
    fi

    # ----------------------------------------------------------
    # Comprobar duplicados.
    # ----------------------------------------------------------

    local P

    for P in vless vmess trojan grpc; do

        if user_exists "$P" "$USERNAME"; then

            error_msg \
                "'$USERNAME' ya existe en $(protocol_name "$P")."

            return 1
        fi

    done

    echo

    echo -e "${WHITE}Usuario:${RESET} ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}Host:${RESET}   ${GREEN}$XRAY_HOST${RESET}"
    echo -e "${WHITE}Tipo:${RESET}   ${GREEN}$HOST_TYPE${RESET}"

    echo

    echo -e "${WHITE}Se crearán:${RESET}"
    echo -e "  ${GREEN}✔${RESET} VLESS"
    echo -e "  ${GREEN}✔${RESET} VMess"
    echo -e "  ${GREEN}✔${RESET} Trojan"
    echo -e "  ${GREEN}✔${RESET} gRPC"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Continuar? [S/n]: ${RESET}")" \
        CONFIRM

    [[ -z "$CONFIRM" ]] && CONFIRM="s"

    case "$CONFIRM" in

        s|S|si|SI|Si)

            ;;

        *)

            warning "Operación cancelada."

            return 0

            ;;

    esac

    local VLESS_ID
    local VMESS_ID
    local TROJAN_ID
    local GRPC_ID

    VLESS_ID=$(generate_uuid) || return 1
    VMESS_ID=$(generate_uuid) || return 1
    TROJAN_ID=$(generate_uuid) || return 1
    GRPC_ID=$(generate_uuid) || return 1

    local TMP

    TMP=$(mktemp --suffix=.json)

    # ----------------------------------------------------------
    # UNA SOLA OPERACIÓN JQ
    # ----------------------------------------------------------

    if ! jq \
        --arg user "$USERNAME" \
        --arg vless "$VLESS_ID" \
        --arg vmess "$VMESS_ID" \
        --arg trojan "$TROJAN_ID" \
        --arg grpc "$GRPC_ID" \
        '
        .inbounds[0].settings.clients += [
            {
                "id": $vless,
                "level": 0,
                "email": $user
            }
        ]
        |
        .inbounds[1].settings.clients += [
            {
                "id": $vmess,
                "level": 0,
                "email": $user
            }
        ]
        |
        .inbounds[2].settings.clients += [
            {
                "password": $trojan,
                "level": 0,
                "email": $user
            }
        ]
        |
        .inbounds[3].settings.clients += [
            {
                "id": $grpc,
                "level": 0,
                "email": $user
            }
        ]
        ' \
        "$XRAY_CFG" > "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo preparar la cuenta."

        return 1
    fi

    if ! validate_json_file "$TMP"; then

        rm -f "$TMP"

        error_msg "JSON generado inválido."

        return 1
    fi

    # ----------------------------------------------------------
    # VALIDAR COMPLETO
    # ----------------------------------------------------------

    echo

    info "Validando configuración completa..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "Xray rechazó la configuración."

        warning "El config.json NO fue modificado."

        return 1
    fi

    # ----------------------------------------------------------
    # APLICAR
    # ----------------------------------------------------------

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    echo

    ok "VLESS preparado."
    ok "VMess preparado."
    ok "Trojan preparado."
    ok "gRPC preparado."

    info "Reiniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo iniciar."

        return 1
    fi

    show_all_created_account \
        "$USERNAME" \
        "$VLESS_ID" \
        "$VMESS_ID" \
        "$TROJAN_ID" \
        "$GRPC_ID"
}

# ==============================================================
# MOSTRAR CUENTA CREADA
# ==============================================================

show_all_created_account() {

    local USER="$1"
    local VLESS_ID="$2"
    local VMESS_ID="$3"
    local TROJAN_ID="$4"
    local GRPC_ID="$5"

    load_host

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}            ${GREEN}${BOLD}🎉 CUENTA MULTIPROTOCOLO${RESET}                    ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${WHITE}👤 Usuario:${RESET} ${GREEN}$USER${RESET}"

    echo -e \
        "${WHITE}🌐 Host:${RESET}    ${GREEN}$XRAY_HOST${RESET}"

    echo -e \
        "${WHITE}📡 Tipo:${RESET}    ${GREEN}$HOST_TYPE${RESET}"

    echo

    line

    echo -e "${MAGENTA}${BOLD}🔐 VLESS${RESET}"

    echo -e "${WHITE}ID:${RESET} $VLESS_ID"

    echo -e "${WHITE}Path:${RESET} $VLESS_PATH"

    echo -e "${WHITE}Puerto:${RESET} $PUBLIC_PORT"

    echo

    echo -e "${YELLOW}vless://$(build_vless_link "$USER" "$VLESS_ID")${RESET}"

    echo

    line

    echo -e "${MAGENTA}${BOLD}⚡ VMess${RESET}"

    echo -e "${WHITE}ID:${RESET} $VMESS_ID"

    echo -e "${WHITE}Path:${RESET} $VMESS_PATH"

    echo -e "${WHITE}Puerto:${RESET} $PUBLIC_PORT"

    echo

    echo -e "${YELLOW}vmess://$(generate_vmess_base64 "$USER" "$VMESS_ID")${RESET}"

    echo

    line

    echo -e "${MAGENTA}${BOLD}🛡️ TROJAN${RESET}"

    echo -e "${WHITE}Password:${RESET} $TROJAN_ID"

    echo -e "${WHITE}Path:${RESET} $TROJAN_PATH"

    echo -e "${WHITE}Puerto:${RESET} $PUBLIC_PORT"

    echo

    echo -e \
        "${YELLOW}$(build_trojan_link "$USER" "$TROJAN_ID")${RESET}"

    echo

    line

    echo -e "${MAGENTA}${BOLD}🚀 gRPC${RESET}"

    echo -e "${WHITE}ID:${RESET} $GRPC_ID"

    echo -e "${WHITE}Service:${RESET} $GRPC_SERVICE"

    echo -e "${WHITE}Puerto:${RESET} $PUBLIC_PORT"

    echo

    echo -e \
        "${YELLOW}$(build_grpc_link "$USER" "$GRPC_ID")${RESET}"

    echo

    line

    ok "Los 4 protocolos fueron creados correctamente."

    pause
}

# ==============================================================
# VLESS LINK
# ==============================================================

build_vless_link() {

    local USER="$1"
    local ID="$2"

    load_host

    echo -n \
        "${ID}@${XRAY_HOST}:${PUBLIC_PORT}?encryption=none&security=tls&type=ws&host=${XRAY_HOST}&path=${VLESS_PATH}&sni=${XRAY_HOST}#${USER}"
}

# ==============================================================
# TROJAN LINK
# ==============================================================

build_trojan_link() {

    local USER="$1"
    local PASSWORD="$2"

    load_host

    echo -n \
        "trojan://${PASSWORD}@${XRAY_HOST}:${PUBLIC_PORT}?security=tls&type=ws&host=${XRAY_HOST}&path=${TROJAN_PATH}&sni=${XRAY_HOST}#${USER}"
}

# ==============================================================
# gRPC LINK
# ==============================================================

build_grpc_link() {

    local USER="$1"
    local ID="$2"

    load_host

    echo -n \
        "vless://${ID}@${XRAY_HOST}:${PUBLIC_PORT}?encryption=none&security=tls&type=grpc&serviceName=${GRPC_SERVICE}&sni=${XRAY_HOST}#${USER}"
}

# ==============================================================
# BASE64
# ==============================================================

base64_encode() {

    if base64 --help 2>/dev/null |
        grep -q -- '-w'; then

        base64 -w 0

    else

        base64 | tr -d '\n'
    fi
}

# ==============================================================
# VMESS BASE64
# ==============================================================

generate_vmess_base64() {

    local USER="$1"
    local UUID="$2"

    load_host

    cat <<EOF | base64_encode
{
  "v":"2",
  "ps":"$USER",
  "add":"$XRAY_HOST",
  "port":"$PUBLIC_PORT",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$XRAY_HOST",
  "path":"$VMESS_PATH",
  "tls":"tls",
  "sni":"$XRAY_HOST",
  "alpn":""
}
EOF
}

# ==============================================================
# GENERAR LINK
# ==============================================================

generate_link() {

    local PROTOCOL="$1"
    local USER="$2"

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USER")

    [[ -z "$ID" ||
       "$ID" == "null" ]] && return 1

    case "$PROTOCOL" in

        vless)

            echo \
                "vless://$(build_vless_link "$USER" "$ID")"

            ;;

        vmess)

            echo \
                "vmess://$(generate_vmess_base64 "$USER" "$ID")"

            ;;

        trojan)

            echo \
                "$(build_trojan_link "$USER" "$ID")"

            ;;

        grpc)

            echo \
                "$(build_grpc_link "$USER" "$ID")"

            ;;

        *)

            return 1

            ;;

    esac
}

# ==============================================================
# MOSTRAR CUENTA
# ==============================================================

show_user_account() {

    local PROTOCOL="$1"

    header

    echo -e \
        "${WHITE}${BOLD}🔗 MOSTRAR CUENTA $(protocol_name "$PROTOCOL")${RESET}"

    line

    echo

    read -rp "👤 Usuario: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if ! user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "Usuario no encontrado."

        pause

        return
    fi

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USERNAME")

    load_host

    local LINK

    LINK=$(generate_link "$PROTOCOL" "$USERNAME")

    echo

    echo -e "${WHITE}Protocolo:${RESET} ${GREEN}$(protocol_name "$PROTOCOL")${RESET}"
    echo -e "${WHITE}Usuario:${RESET}   ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}Host:${RESET}      ${GREEN}$XRAY_HOST${RESET}"
    echo -e "${WHITE}Tipo:${RESET}      ${GREEN}$HOST_TYPE${RESET}"
    echo -e "${WHITE}ID:${RESET}        ${YELLOW}$ID${RESET}"
    echo -e "${WHITE}Puerto:${RESET}    ${GREEN}$PUBLIC_PORT${RESET}"

    echo

    case "$PROTOCOL" in

        vless)

            echo -e "${WHITE}Path:${RESET} ${GREEN}$VLESS_PATH${RESET}"
            ;;

        vmess)

            echo -e "${WHITE}Path:${RESET} ${GREEN}$VMESS_PATH${RESET}"
            ;;

        trojan)

            echo -e "${WHITE}Path:${RESET} ${GREEN}$TROJAN_PATH${RESET}"
            ;;

        grpc)

            echo -e "${WHITE}Service:${RESET} ${GREEN}$GRPC_SERVICE${RESET}"
            ;;

    esac

    echo

    line

    echo -e "${YELLOW}${BOLD}🔗 ENLACE${RESET}"

    echo

    echo -e "${GREEN}$LINK${RESET}"

    echo

    pause
}

# ==============================================================
# LISTAR UN PROTOCOLO
# ==============================================================

list_users() {

    local PROTOCOL="$1"

    header

    echo -e \
        "${WHITE}${BOLD}👥 USUARIOS $(protocol_name "$PROTOCOL")${RESET}"

    line

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || {

        error_msg "Protocolo inválido."

        pause

        return
    }

    local TOTAL

    TOTAL=$(count_users "$PROTOCOL")

    TOTAL="${TOTAL:-0}"

    echo

    if [[ "$TOTAL" -eq 0 ]]; then

        echo -e \
            "${YELLOW}No existen usuarios registrados.${RESET}"

        pause

        return
    fi

    local I=0

    while IFS=$'\t' read -r USER ID; do

        I=$((I + 1))

        echo -e \
            "${GREEN}[$I]${RESET} ${WHITE}$USER${RESET}"

        echo -e \
            "    ${GRAY}$ID${RESET}"

        echo -e \
            "    ${CYAN}$(generate_link "$PROTOCOL" "$USER")${RESET}"

        echo

    done < <(

        jq -r \
            --argjson index "$INDEX" \
            '
            .inbounds[$index].settings.clients[] |
            [.email, (.id // .password)] |
            @tsv
            ' \
            "$XRAY_CFG"
    )

    echo -e \
        "${WHITE}Total $(protocol_name "$PROTOCOL"):${RESET} ${GREEN}$TOTAL${RESET}"

    pause
}

# ==============================================================
# LISTAR TODOS
# ==============================================================

list_all_users() {

    header

    echo -e \
        "${WHITE}${BOLD}👥 TODAS LAS CUENTAS${RESET}"

    line

    local P
    local TOTAL_ALL=0

    for P in vless vmess trojan grpc; do

        local TOTAL

        TOTAL=$(count_users "$P")

        TOTAL="${TOTAL:-0}"

        echo

        echo -e \
            "${MAGENTA}${BOLD}◆ $(protocol_name "$P")${RESET} ${GRAY}($TOTAL)${RESET}"

        if [[ "$TOTAL" -eq 0 ]]; then

            echo -e \
                "  ${GRAY}Sin usuarios.${RESET}"

            continue
        fi

        while IFS=$'\t' read -r USER ID; do

            echo -e \
                "  ${GREEN}●${RESET} ${WHITE}$USER${RESET}"

            echo -e \
                "    ${GRAY}$ID${RESET}"

        done < <(

            local INDEX

            INDEX=$(inbound_index "$P")

            jq -r \
                --argjson index "$INDEX" \
                '
                .inbounds[$index].settings.clients[] |
                [.email, (.id // .password)] |
                @tsv
                ' \
                "$XRAY_CFG"

        )

        TOTAL_ALL=$((TOTAL_ALL + TOTAL))

    done

    echo

    line

    echo -e \
        "${WHITE}Total de cuentas:${RESET} ${GREEN}$TOTAL_ALL${RESET}"

    pause
}

# ==============================================================
# ELIMINAR UN USUARIO
# ==============================================================

remove_user() {

    local PROTOCOL="$1"

    header

    echo -e \
        "${WHITE}${BOLD}🗑️ ELIMINAR $(protocol_name "$PROTOCOL")${RESET}"

    line

    echo

    read -rp "👤 Usuario a eliminar: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    if ! user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "Usuario no encontrado."

        pause

        return
    fi

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USERNAME")

    echo

    echo -e "${WHITE}Protocolo:${RESET} ${GREEN}$(protocol_name "$PROTOCOL")${RESET}"
    echo -e "${WHITE}Usuario:${RESET}   ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}ID:${RESET}        ${YELLOW}$ID${RESET}"

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        pause

        return
    fi

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL")

    local TMP

    TMP=$(mktemp --suffix=.json)

    if ! jq \
        --arg email "$USERNAME" \
        --argjson index "$INDEX" \
        '
        .inbounds[$index].settings.clients |=
        map(select(.email != $email))
        ' \
        "$XRAY_CFG" > "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo modificar config.json."

        pause

        return
    fi

    if ! validate_json_file "$TMP"; then

        rm -f "$TMP"

        error_msg "JSON inválido."

        pause

        return
    fi

    info "Validando configuración..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "Xray rechazó la configuración."

        warning "El config.json NO fue modificado."

        pause

        return
    fi

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        ok \
            "Usuario '$USERNAME' eliminado de $(protocol_name "$PROTOCOL")."

    else

        error_msg "Xray no pudo reiniciar."

    fi

    pause
}

# ==============================================================
# ELIMINAR TODOS LOS PROTOCOLOS DE UN USUARIO
# ==============================================================

remove_all_user() {

    header

    echo -e \
        "${WHITE}${BOLD}🗑️ ELIMINAR CUENTA MULTIPROTOCOLO${RESET}"

    line

    echo

    read -rp "👤 Usuario: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    local FOUND=0
    local P

    for P in vless vmess trojan grpc; do

        if user_exists "$P" "$USERNAME"; then

            FOUND=1

            break
        fi

    done

    if [[ "$FOUND" -eq 0 ]]; then

        error_msg "Usuario no encontrado."

        pause

        return
    fi

    echo

    echo -e \
        "${WHITE}Se eliminará ${GREEN}$USERNAME${RESET} de los protocolos donde exista."

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        pause

        return
    fi

    local TMP

    TMP=$(mktemp --suffix=.json)

    if ! jq \
        --arg email "$USERNAME" \
        '
        .inbounds |=
        map(
            .settings.clients =
            (
                (.settings.clients // [])
                | map(select(.email != $email))
            )
        )
        ' \
        "$XRAY_CFG" > "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo preparar la eliminación."

        pause

        return
    fi

    if ! validate_json_file "$TMP"; then

        rm -f "$TMP"

        error_msg "JSON inválido."

        pause

        return
    fi

    info "Validando configuración..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "Xray rechazó la configuración."

        warning "El config.json NO fue modificado."

        pause

        return
    fi

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        ok "Cuenta '$USERNAME' eliminada de todos los protocolos."

    else

        error_msg "Xray no pudo reiniciar."

    fi

    pause
}

# ==============================================================
# SUBMENÚ CREAR
# ==============================================================

create_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}⭐ CREAR CUENTA${RESET}"

        line

        echo

        echo -e "  ${GREEN}[01]${RESET} VLESS"
        echo -e "  ${GREEN}[02]${RESET} VMess"
        echo -e "  ${GREEN}[03]${RESET} Trojan"
        echo -e "  ${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} ⭐ TODOS LOS PROTOCOLOS"

        echo

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)

                create_user "vless"

                pause

                ;;

            2)

                create_user "vmess"

                pause

                ;;

            3)

                create_user "trojan"

                pause

                ;;

            4)

                create_user "grpc"

                pause

                ;;

            5)

                create_all_user

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
# SUBMENÚ LISTAR
# ==============================================================

list_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}👥 LISTAR CUENTAS${RESET}"

        line

        echo

        echo -e "  ${GREEN}[01]${RESET} VLESS"
        echo -e "  ${GREEN}[02]${RESET} VMess"
        echo -e "  ${GREEN}[03]${RESET} Trojan"
        echo -e "  ${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} ⭐ TODOS LOS PROTOCOLOS"

        echo

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)

                list_users "vless"

                ;;

            2)

                list_users "vmess"

                ;;

            3)

                list_users "trojan"

                ;;

            4)

                list_users "grpc"

                ;;

            5)

                list_all_users

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
# SUBMENÚ ELIMINAR
# ==============================================================

delete_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}🗑️ ELIMINAR CUENTA${RESET}"

        line

        echo

        echo -e "  ${GREEN}[01]${RESET} VLESS"
        echo -e "  ${GREEN}[02]${RESET} VMess"
        echo -e "  ${GREEN}[03]${RESET} Trojan"
        echo -e "  ${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} ⭐ TODOS LOS PROTOCOLOS"

        echo

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)

                remove_user "vless"

                ;;

            2)

                remove_user "vmess"

                ;;

            3)

                remove_user "trojan"

                ;;

            4)

                remove_user "grpc"

                ;;

            5)

                remove_all_user

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
# MOSTRAR CUENTA / LINK
# ==============================================================

account_link_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}🔗 CUENTA / ENLACE${RESET}"

        line

        echo

        echo -e "  ${GREEN}[01]${RESET} Mostrar VLESS"
        echo -e "  ${GREEN}[02]${RESET} Mostrar VMess"
        echo -e "  ${GREEN}[03]${RESET} Mostrar Trojan"
        echo -e "  ${GREEN}[04]${RESET} Mostrar gRPC"

        echo

        echo -e \
            "${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)

                show_user_account "vless"

                ;;

            2)

                show_user_account "vmess"

                ;;

            3)

                show_user_account "trojan"

                ;;

            4)

                show_user_account "grpc"

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
# USUARIOS ONLINE
# ==============================================================

xray_online_users() {

    header

    echo -e \
        "${WHITE}${BOLD}🌐 USUARIOS ONLINE${RESET}"

    line

    if [[ ! -f "$XRAY_LOG" ]]; then

        error_msg "No existe access.log."

        pause

        return
    fi

    echo

    tail -n 300 "$XRAY_LOG" |
        grep -E \
            'email:|accepted' |
        tail -n 50

    echo

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

xray_status() {

    header

    echo -e \
        "${WHITE}${BOLD}📊 ESTADO DE XRAY${RESET}"

    line

    echo

    if xray_active; then

        echo -e \
            "${WHITE}Estado:${RESET} ${GREEN}🟢 ACTIVO${RESET}"

    elif xray_installed; then

        echo -e \
            "${WHITE}Estado:${RESET} ${RED}🔴 DETENIDO${RESET}"

    else

        echo -e \
            "${WHITE}Estado:${RESET} ${GRAY}⚪ NO INSTALADO${RESET}"

    fi

    local XV

    XV=$(
        xray version 2>/dev/null |
        head -1
    )

    echo -e \
        "${WHITE}Versión:${RESET} ${GREEN}${XV:-NO INSTALADO}${RESET}"

    load_host

    echo

    echo -e \
        "${WHITE}Host:${RESET} ${GREEN}${XRAY_HOST:-NO DISPONIBLE}${RESET}"

    echo -e \
        "${WHITE}Tipo:${RESET} ${GREEN}${HOST_TYPE:-N/A}${RESET}"

    echo

    echo -e \
        "${WHITE}VLESS:${RESET}  ${GREEN}127.0.0.1:$VLESS_PORT${RESET}"

    echo -e \
        "${WHITE}VMess:${RESET}  ${GREEN}127.0.0.1:$VMESS_PORT${RESET}"

    echo -e \
        "${WHITE}Trojan:${RESET} ${GREEN}127.0.0.1:$TROJAN_PORT${RESET}"

    echo -e \
        "${WHITE}gRPC:${RESET}   ${GREEN}127.0.0.1:$GRPC_PORT${RESET}"

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        if validate_xray_config; then

            ok "Configuración Xray válida."

        else

            error_msg "Configuración Xray inválida."

        fi

    fi

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

xray_diagnostic() {

    header

    echo -e \
        "${WHITE}${BOLD}🔎 DIAGNÓSTICO XRAY${RESET}"

    line

    echo

    if command -v xray >/dev/null 2>&1; then
        ok "Xray Core instalado"
    else
        error_msg "Xray Core no instalado"
    fi

    if command -v jq >/dev/null 2>&1; then
        ok "jq disponible"
    else
        error_msg "jq no disponible"
    fi

    if [[ -f "$XRAY_CFG" ]]; then
        ok "config.json encontrado"
    else
        error_msg "config.json inexistente"
    fi

    if [[ -f "$XRAY_CFG" ]] &&
       validate_json; then

        ok "JSON válido"

    else

        error_msg "JSON inválido"

    fi

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        echo -e "${WHITE}Inbounds:${RESET}"

        jq -r '
            .inbounds[]? |
            "  \(.tag // "SIN TAG") | \(.protocol) | \(.listen // "N/A"):\(.port // "N/A") | \(.streamSettings.network // "N/A")"
        ' \
        "$XRAY_CFG" 2>/dev/null

    fi

    echo

    if [[ -f "$XRAY_CFG" ]] &&
       validate_xray_config; then

        ok "Xray acepta la configuración."

    else

        error_msg "Xray rechaza la configuración."

    fi

    echo

    if xray_active; then
        ok "Servicio Xray activo"
    else
        error_msg "Servicio Xray detenido"
    fi

    echo

    journalctl \
        -u "$XRAY_SERVICE" \
        -n 20 \
        --no-pager 2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

show_xray_logs() {

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}                  ${MAGENTA}${BOLD}📜 XRAY LOGS${RESET}                         ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    journalctl \
        -u "$XRAY_SERVICE" \
        -n 40 \
        --no-pager 2>/dev/null

    echo

    if [[ -f "$XRAY_LOG" ]]; then

        echo -e "${WHITE}access.log:${RESET}"

        tail -n 30 "$XRAY_LOG"

    fi

    pause
}

# ==============================================================
# REINICIAR XRAY
# ==============================================================

restart_xray_service() {

    header

    echo -e \
        "${WHITE}${BOLD}♻️ REINICIAR XRAY${RESET}"

    line

    echo

    if ! validate_xray_config; then

        pause

        return 1
    fi

    info "Reiniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        ok "Xray reiniciado correctamente."

    else

        set_config "XRAY" "OFF"

        error_msg "Xray no pudo iniciar."

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 20 \
            --no-pager 2>/dev/null

    fi

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_xray() {

    header

    echo -e \
        "${RED}${BOLD}🗑️ DESINSTALAR XRAY${RESET}"

    line

    echo

    warning "Se eliminará Xray Core y su configuración."

    warning "Esta acción NO crea backup."

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para continuar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        pause

        return
    fi

    echo

    info "Deteniendo Xray..."

    systemctl stop "$XRAY_SERVICE" 2>/dev/null || true

    systemctl disable "$XRAY_SERVICE" 2>/dev/null || true

    info "Eliminando Xray..."

    local INSTALLER="/tmp/xray-remove.sh"

    if curl -fL \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        -o "$INSTALLER" >/dev/null 2>&1; then

        chmod 700 "$INSTALLER"

        bash "$INSTALLER" remove >/dev/null 2>&1

        rm -f "$INSTALLER"

    fi

    rm -rf "$XRAY_DIR"
    rm -rf "$XRAY_LOG_DIR"

    rm -rf \
        /etc/systemd/system/xray.service.d

    systemctl daemon-reload

    systemctl reset-failed xray 2>/dev/null || true

    set_config "XRAY" "OFF"

    echo

    ok "Xray eliminado correctamente."

    pause
}

# ==============================================================
# AUTO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    install_xray

    exit $?
fi

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

xray_menu() {

    while true; do

        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null

        load_host

        clear

        local STATUS

        if xray_active; then

            STATUS="${GREEN}🟢 ACTIVO${RESET}"

        elif xray_installed; then

            STATUS="${RED}🔴 DETENIDO${RESET}"

        else

            STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

        fi

        local VERSION_INFO

        VERSION_INFO=$(
            xray version 2>/dev/null |
            head -1
        )

        VERSION_INFO="${VERSION_INFO:-NO INSTALADO}"

        local TOTAL_VLESS=0
        local TOTAL_VMESS=0
        local TOTAL_TROJAN=0
        local TOTAL_GRPC=0

        if [[ -f "$XRAY_CFG" ]] &&
           validate_json; then

            TOTAL_VLESS=$(count_users "vless")
            TOTAL_VMESS=$(count_users "vmess")
            TOTAL_TROJAN=$(count_users "trojan")
            TOTAL_GRPC=$(count_users "grpc")

        fi

        echo -e \
            "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

        echo -e \
            "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                  ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                            ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${WHITE}Estado:${RESET}        $STATUS"

        echo -e \
            "${WHITE}Host:${RESET}          ${GREEN}${XRAY_HOST:-NO DISPONIBLE}${RESET}"

        echo -e \
            "${WHITE}Tipo:${RESET}          ${GREEN}${HOST_TYPE:-N/A}${RESET}"

        echo -e \
            "${WHITE}Puerto público:${RESET} ${GREEN}$PUBLIC_PORT${RESET}"

        echo -e \
            "${WHITE}VLESS:${RESET}         ${GREEN}$TOTAL_VLESS${RESET}"

        echo -e \
            "${WHITE}VMess:${RESET}         ${GREEN}$TOTAL_VMESS${RESET}"

        echo -e \
            "${WHITE}Trojan:${RESET}        ${GREEN}$TOTAL_TROJAN${RESET}"

        echo -e \
            "${WHITE}gRPC:${RESET}          ${GREEN}$TOTAL_GRPC${RESET}"

        echo -e \
            "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${BLUE}${BOLD}  👥 GESTIÓN DE CUENTAS${RESET}"

        echo

        echo -e \
            "  ${GREEN}[01]${RESET} 👤 Crear cuenta"

        echo -e \
            "  ${GREEN}[02]${RESET} 👥 Listar cuentas"

        echo -e \
            "  ${GREEN}[03]${RESET} 🗑️  Eliminar cuenta"

        echo -e \
            "  ${GREEN}[04]${RESET} 🔗 Mostrar cuenta / enlace"

        echo

        echo -e \
            "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN XRAY${RESET}"

        echo

        echo -e \
            "  ${GREEN}[05]${RESET} 🌐 Usuarios online"

        echo -e \
            "  ${GREEN}[06]${RESET} 📊 Estado"

        echo -e \
            "  ${GREEN}[07]${RESET} 🔎 Diagnóstico"

        echo -e \
            "  ${GREEN}[08]${RESET} 📜 Logs"

        echo -e \
            "  ${GREEN}[09]${RESET} ♻️  Reiniciar Xray"

        echo -e \
            "  ${GREEN}[10]${RESET} 🔄 Instalar / Actualizar"

        echo -e \
            "  ${RED}[11]${RESET} 🗑️  Desinstalar Xray"

        echo

        echo -e \
            "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"

        echo -e \
            "  ${RED}${BOLD}[00]${RESET} ↩️  Regresar"

        echo

        echo -e \
            "${GRAY}  KevinTech Multi Script • Xray v$VERSION${RESET}"

        echo

        read -rp \
            "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)

                if xray_installed; then

                    create_menu

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            2)

                if xray_installed; then

                    list_menu

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            3)

                if xray_installed; then

                    delete_menu

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            4)

                if xray_installed; then

                    account_link_menu

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            5)

                if xray_installed; then

                    xray_online_users

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            6)

                xray_status

                ;;

            7)

                xray_diagnostic

                ;;

            8)

                if xray_installed; then

                    show_xray_logs

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            9)

                if xray_installed; then

                    restart_xray_service

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            10)

                install_xray

                ;;

            11)

                if xray_installed; then

                    remove_xray

                else

                    error_msg "Xray no está instalado."

                    sleep 1

                fi

                ;;

            0)

                clear

                exec bash \
                    "$BASE/protocolos/menu.sh"

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

xray_menu