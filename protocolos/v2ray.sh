#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                 XRAY MANAGER v6.0
# ==============================================================
#
# Protocolos:
#   VLESS
#   VMess
#   Trojan
#   gRPC
#
# Frontend:
#   HAProxy
#
# Puertos públicos:
#   80
#   443
#   8080
#
# Puertos internos Xray:
#   VLESS  : 10001
#   VMess  : 10002
#   Trojan : 10003
#   gRPC   : 10004
#
# Config:
#   /etc/kevintech/config.conf
#
# Xray:
#   /usr/local/etc/xray/config.json
#
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"

XRAY_LOG_DIR="/var/log/xray"
XRAY_LOG="$XRAY_LOG_DIR/access.log"

XRAY_SERVICE="xray"

VERSION="6.0"

# ==============================================================
# PUERTOS INTERNOS
# ==============================================================

VLESS_PORT="10001"
VMESS_PORT="10002"
TROJAN_PORT="10003"
GRPC_PORT="10004"

# ==============================================================
# PUERTOS PUBLICOS HAProxy
# ==============================================================

PUBLIC_HTTP_PORT="80"
PUBLIC_TLS_PORT="443"
PUBLIC_ALT_PORT="8080"

# ==============================================================
# PATHS
# ==============================================================

VLESS_PATH="/vless"
VMESS_PATH="/vmess"
TROJAN_PATH="/trojan-ws"

GRPC_SERVICE="xray-grpc"

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
    echo -e "${WHITE}Este administrador requiere root.${RESET}"
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
# VISUALES
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
        "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                 ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}        ${GRAY}VLESS / VMess / Trojan / gRPC${RESET}                 ${CYAN}║${RESET}"

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
# DOMINIO / IP
# ==============================================================

load_host() {

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    HOST="${SERVER_DOMAIN:-}"

    if [[ -z "$HOST" &&
          -f /etc/xray/domain ]]; then

        HOST=$(cat /etc/xray/domain 2>/dev/null)
    fi

    HOST="$(echo "$HOST" | xargs 2>/dev/null)"

    # Si no existe dominio, obtener IPv4 pública/local
    if [[ -z "$HOST" ]]; then

        HOST=$(hostname -I 2>/dev/null |
            awk '{print $1}')
    fi

    # Último recurso
    if [[ -z "$HOST" ]]; then

        HOST="127.0.0.1"
    fi
}

# Alias para compatibilidad
load_domain() {
    load_host
    DOMAIN="$HOST"
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
# PASSWORD TROJAN
# ==============================================================

generate_password() {
    generate_uuid
}

# ==============================================================
# XRAY
# ==============================================================

xray_binary() {

    if command -v xray >/dev/null 2>&1; then

        command -v xray
        return 0
    fi

    if [[ -x /usr/local/bin/xray ]]; then

        echo "/usr/local/bin/xray"
        return 0
    fi

    return 1
}

xray_installed() {

    xray_binary >/dev/null 2>&1 &&
        [[ -f "$XRAY_CFG" ]]
}

xray_active() {

    systemctl is-active \
        --quiet "$XRAY_SERVICE" 2>/dev/null
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
# VALIDAR XRAY
# ==============================================================

validate_xray_file() {

    local FILE="$1"

    local XRAY_BIN

    XRAY_BIN=$(xray_binary) || {

        error_msg "Xray Core no está instalado."

        return 1
    }

    if ! validate_json_file "$FILE"; then

        error_msg "JSON inválido."

        return 1
    fi

    if ! "$XRAY_BIN" run \
        -test \
        -config "$FILE" \
        >/tmp/kevintech-xray-test.log 2>&1; then

        error_msg "Xray rechazó la configuración."

        echo
        echo -e \
            "${RED}──── ERROR DE XRAY ───────────────────────────────────────${RESET}"

        cat /tmp/kevintech-xray-test.log

        echo -e \
            "${RED}──────────────────────────────────────────────────────────${RESET}"

        rm -f /tmp/kevintech-xray-test.log

        return 1
    fi

    rm -f /tmp/kevintech-xray-test.log

    return 0
}

validate_xray_config() {

    validate_xray_file "$XRAY_CFG"
}

# ==============================================================
# CREAR CONFIGURACIÓN BASE
# ==============================================================

create_base_config() {

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

    if ! validate_json; then

        error_msg "No se pudo crear config.json."

        return 1
    fi

    ok "Configuración base creada."

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

    if ! xray_binary >/dev/null 2>&1; then

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
# INSTALAR XRAY COMPLETO
# ==============================================================

install_xray() {

    header

    echo -e \
        "${WHITE}${BOLD}          ⭐ INSTALACIÓN XRAY MULTIPROTOCOLO${RESET}"

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

    if [[ ! -f "$XRAY_CFG" ]]; then

        create_base_config || {

            pause
            return 1
        }

    elif ! validate_json; then

        warning "config.json existente es inválido."

        info "Creando una configuración limpia..."

        create_base_config || {

            pause
            return 1
        }

    else

        ok "Configuración existente conservada."

    fi

    ensure_xray_resilience

    if ! validate_xray_config; then

        error_msg "La configuración no es válida."

        pause

        return 1
    fi

    info "Reiniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        echo

        ok "Xray instalado y activo."

    else

        set_config "XRAY" "OFF"

        error_msg "Xray no pudo iniciar."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null

        pause

        return 1
    fi

    pause

    return 0
}

# ==============================================================
# BUSCAR INBOUND
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
# EXISTE USUARIO
# ==============================================================

user_exists() {

    local PROTOCOL="$1"
    local USERNAME="$2"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return 1

    [[ -f "$XRAY_CFG" ]] || return 1

    jq -e \
        --arg email "$USERNAME" \
        --argjson index "$INDEX" \
        '
        (.inbounds[$index].settings.clients // [])
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
        (.inbounds[$index].settings.clients // [])
        | .[]
        | select(.email == $email)
        | (.id // .password)
        ' \
        "$XRAY_CFG" 2>/dev/null |
        head -1
}

# ==============================================================
# OBTENER TOTAL
# ==============================================================

get_total() {

    local PROTOCOL="$1"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || {

        echo 0
        return
    }

    jq -r \
        --argjson index "$INDEX" \
        '(.inbounds[$index].settings.clients // []) | length' \
        "$XRAY_CFG" 2>/dev/null
}

# ==============================================================
# AGREGAR USUARIO A CONFIGURACIÓN TEMPORAL
# ==============================================================

add_user_to_file() {

    local FILE="$1"
    local PROTOCOL="$2"
    local USERNAME="$3"
    local ID="$4"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return 1

    if [[ "$PROTOCOL" == "trojan" ]]; then

        jq \
            --arg email "$USERNAME" \
            --arg password "$ID" \
            --argjson index "$INDEX" \
            '
            .inbounds[$index].settings.clients += [
                {
                    "password": $password,
                    "email": $email,
                    "level": 0
                }
            ]
            ' \
            "$FILE" > "${FILE}.new"

    else

        jq \
            --arg email "$USERNAME" \
            --arg uuid "$ID" \
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
            "$FILE" > "${FILE}.new"
    fi

    if [[ $? -ne 0 ]]; then

        rm -f "${FILE}.new"

        return 1
    fi

    mv "${FILE}.new" "$FILE"

    return 0
}

# ==============================================================
# CREAR CUENTA INDIVIDUAL
# ==============================================================

create_single_user() {

    local PROTOCOL="$1"
    local USERNAME="$2"
    local ID="$3"

    if user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "$USERNAME ya existe en ${PROTOCOL^^}."

        return 1
    fi

    local TMP

    TMP=$(mktemp --suffix=.json)

    if ! cp -f "$XRAY_CFG" "$TMP"; then

        rm -f "$TMP"

        return 1
    fi

    if ! add_user_to_file \
        "$TMP" \
        "$PROTOCOL" \
        "$USERNAME" \
        "$ID"; then

        rm -f "$TMP"

        return 1
    fi

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        return 1
    fi

    # Sin backup:
    # solo se reemplaza cuando Xray ya aceptó la configuración.

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    return 0
}

# ==============================================================
# CREAR CUENTA COMPLETA
# ==============================================================

create_all_user() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    if ! validate_xray_config; then

        return 1
    fi

    load_host

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

    echo

    echo -e "${WHITE}Usuario:${RESET} ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}Host:${RESET}    ${GREEN}$HOST${RESET}"

    if [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

        echo -e "${WHITE}Tipo:${RESET}    ${YELLOW}IP${RESET}"

    else

        echo -e "${WHITE}Tipo:${RESET}    ${GREEN}DOMINIO${RESET}"
    fi

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

    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then

        warning "Operación cancelada."

        return
    fi

    local ID

    ID=$(generate_uuid) || return 1

    local TMP

    TMP=$(mktemp --suffix=.json)

    if ! cp -f "$XRAY_CFG" "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo preparar la configuración."

        return 1
    fi

    # ----------------------------------------------------------
    # Comprobar que no exista en ninguno
    # ----------------------------------------------------------

    for PROTOCOL in vless vmess trojan grpc; do

        if user_exists "$PROTOCOL" "$USERNAME"; then

            rm -f "$TMP"

            error_msg \
                "El usuario '$USERNAME' ya existe en ${PROTOCOL^^}."

            return 1
        fi

    done

    # ----------------------------------------------------------
    # Agregar los cuatro protocolos al TEMP
    # ----------------------------------------------------------

    for PROTOCOL in vless vmess trojan grpc; do

        if ! add_user_to_file \
            "$TMP" \
            "$PROTOCOL" \
            "$USERNAME" \
            "$ID"; then

            rm -f "$TMP"

            error_msg \
                "No se pudo preparar ${PROTOCOL^^}."

            return 1
        fi

        ok "${PROTOCOL^^} preparado."
    done

    echo

    info "Validando configuración completa..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "El config.json original NO fue modificado."

        pause

        return 1
    fi

    # ----------------------------------------------------------
    # Reemplazo solamente después de validación
    # ----------------------------------------------------------

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    info "Reiniciando Xray..."

    if ! systemctl restart "$XRAY_SERVICE"; then

        error_msg "El comando de reinicio devolvió error."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null

        return 1
    fi

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo reiniciar."

        echo

        echo -e \
            "${RED}──── DIAGNÓSTICO ─────────────────────────────────────────${RESET}"

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null

        echo -e \
            "${RED}──────────────────────────────────────────────────────────${RESET}"

        return 1
    fi

    show_created_all \
        "$USERNAME" \
        "$ID"

    return 0
}

# ==============================================================
# SUBMENÚ CREAR
# ==============================================================

create_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}                 ⭐ CREAR CUENTA${RESET}"

        line

        echo

        echo -e \
            "  ${GREEN}[01]${RESET} VLESS"

        echo -e \
            "  ${GREEN}[02]${RESET} VMess"

        echo -e \
            "  ${GREEN}[03]${RESET} Trojan"

        echo -e \
            "  ${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} 🚀 TODOS LOS PROTOCOLOS"

        echo

        echo -e \
            "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)
                create_protocol_account "vless"
                ;;

            2)
                create_protocol_account "vmess"
                ;;

            3)
                create_protocol_account "trojan"
                ;;

            4)
                create_protocol_account "grpc"
                ;;

            5)
                create_all_user
                pause
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
# CREAR PROTOCOLO INDIVIDUAL
# ==============================================================

create_protocol_account() {

    local PROTOCOL="$1"

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        pause

        return
    fi

    if ! validate_xray_config; then

        pause

        return
    fi

    load_host

    header

    echo -e \
        "${WHITE}${BOLD}              ⭐ CREAR ${PROTOCOL^^}${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Nombre del usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if [[ -z "$USERNAME" ]]; then

        error_msg "El usuario no puede estar vacío."

        pause

        return
    fi

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre de usuario inválido."

        pause

        return
    fi

    if user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg \
            "El usuario '$USERNAME' ya existe en ${PROTOCOL^^}."

        pause

        return
    fi

    local ID

    ID=$(generate_uuid) || {

        pause
        return
    }

    if create_single_user \
        "$PROTOCOL" \
        "$USERNAME" \
        "$ID"; then

        info "Reiniciando Xray..."

        if systemctl restart "$XRAY_SERVICE"; then

            sleep 2

        fi

        if xray_active; then

            show_created_single \
                "$PROTOCOL" \
                "$USERNAME" \
                "$ID"

        else

            error_msg "Xray no pudo reiniciar."

            echo

            journalctl \
                -u "$XRAY_SERVICE" \
                -n 30 \
                --no-pager 2>/dev/null

            pause
        fi

    else

        error_msg \
            "No se pudo crear la cuenta ${PROTOCOL^^}."

        pause
    fi
}

# ==============================================================
# ELIMINAR DE ARCHIVO TEMPORAL
# ==============================================================

remove_user_from_file() {

    local FILE="$1"
    local PROTOCOL="$2"
    local USERNAME="$3"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return 1

    jq \
        --arg email "$USERNAME" \
        --argjson index "$INDEX" \
        '
        .inbounds[$index].settings.clients =
        (
            .inbounds[$index].settings.clients // []
            | map(select(.email != $email))
        )
        ' \
        "$FILE" > "${FILE}.new"

    if [[ $? -ne 0 ]]; then

        rm -f "${FILE}.new"

        return 1
    fi

    mv "${FILE}.new" "$FILE"

    return 0
}

# ==============================================================
# ELIMINAR USUARIO
# ==============================================================

remove_user() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    header

    echo -e \
        "${WHITE}${BOLD}                🗑️ ELIMINAR CUENTA${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Usuario a eliminar: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if [[ -z "$USERNAME" ]]; then

        return
    fi

    local FOUND=0

    for PROTOCOL in vless vmess trojan grpc; do

        if user_exists "$PROTOCOL" "$USERNAME"; then

            FOUND=1

            break
        fi
    done

    if [[ "$FOUND" -eq 0 ]]; then

        error_msg "El usuario '$USERNAME' no existe."

        pause

        return 1
    fi

    echo

    echo -e \
        "${YELLOW}Se eliminará $USERNAME de los protocolos donde exista.${RESET}"

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

    if ! cp -f "$XRAY_CFG" "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo preparar la configuración."

        pause

        return 1
    fi

    local REMOVED=0

    echo

    for PROTOCOL in vless vmess trojan grpc; do

        if user_exists "$PROTOCOL" "$USERNAME"; then

            if remove_user_from_file \
                "$TMP" \
                "$PROTOCOL" \
                "$USERNAME"; then

                ok "${PROTOCOL^^} eliminado."

                REMOVED=$((REMOVED + 1))

            else

                rm -f "$TMP"

                error_msg \
                    "No se pudo eliminar de ${PROTOCOL^^}."

                pause

                return 1
            fi
        fi
    done

    echo

    info "Validando configuración..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "El config.json NO fue modificado."

        pause

        return 1
    fi

    # ----------------------------------------------------------
    # Sin backup.
    # La configuración solamente se reemplaza después
    # de que Xray la haya validado.
    # ----------------------------------------------------------

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    echo

    info "Reiniciando Xray..."

    if ! systemctl restart "$XRAY_SERVICE"; then

        error_msg "El comando de reinicio falló."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null

        pause

        return 1
    fi

    sleep 2

    if xray_active; then

        echo

        ok "Xray reiniciado correctamente."

        ok "Usuario '$USERNAME' eliminado."

        echo
        echo -e \
            "${WHITE}Protocolos modificados:${RESET} ${GREEN}$REMOVED${RESET}"

    else

        echo

        error_msg "Xray no pudo reiniciar."

        echo

        echo -e \
            "${RED}──── ERROR REAL DE XRAY ──────────────────────────────────${RESET}"

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null

        echo -e \
            "${RED}──────────────────────────────────────────────────────────${RESET}"

        return 1
    fi

    pause
}

# ==============================================================
# LISTAR PROTOCOLO
# ==============================================================

list_protocol_users() {

    local PROTOCOL="$1"

    header

    echo -e \
        "${WHITE}${BOLD}              👥 USUARIOS ${PROTOCOL^^}${RESET}"

    line

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        pause

        return
    fi

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || {

        error_msg "Protocolo inválido."

        pause

        return
    }

    local TOTAL

    TOTAL=$(get_total "$PROTOCOL")

    TOTAL="${TOTAL:-0}"

    echo

    printf \
        "${CYAN}%-5s %-25s %-38s${RESET}\n" \
        "#" "USUARIO" "ID / UUID"

    echo -e \
        "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

    if [[ "$TOTAL" -eq 0 ]]; then

        echo -e \
            "${YELLOW}No existen usuarios registrados.${RESET}"

    else

        local I=0

        while IFS=$'\t' read -r USER ID; do

            I=$((I + 1))

            printf \
                "${GREEN}%-5s${RESET} ${WHITE}%-25s${RESET} ${YELLOW}%-38s${RESET}\n" \
                "$I" \
                "$USER" \
                "$ID"

        done < <(

            jq -r \
                --argjson index "$INDEX" \
                '
                (.inbounds[$index].settings.clients // [])
                | .[]
                | [
                    .email,
                    (.id // .password)
                  ]
                | @tsv
                ' \
                "$XRAY_CFG"
        )
    fi

    echo

    echo -e \
        "${WHITE}Total ${PROTOCOL^^}:${RESET} ${GREEN}$TOTAL${RESET}"

    pause
}

# ==============================================================
# LISTAR TODOS
# ==============================================================

list_all_users() {

    header

    echo -e \
        "${WHITE}${BOLD}             👥 TODOS LOS USUARIOS${RESET}"

    line

    echo

    for PROTOCOL in vless vmess trojan grpc; do

        local TOTAL

        TOTAL=$(get_total "$PROTOCOL")
        TOTAL="${TOTAL:-0}"

        echo -e \
            "${BLUE}${BOLD}${PROTOCOL^^}${RESET} ${GRAY}($TOTAL)${RESET}"

        if [[ "$TOTAL" -eq 0 ]]; then

            echo -e \
                "  ${YELLOW}Sin usuarios.${RESET}"

        else

            while IFS=$'\t' read -r USER ID; do

                echo -e \
                    "  ${GREEN}•${RESET} ${WHITE}$USER${RESET}"

                echo -e \
                    "    ${GRAY}$ID${RESET}"

            done < <(

                local INDEX

                INDEX=$(inbound_index "$PROTOCOL")

                jq -r \
                    --argjson index "$INDEX" \
                    '
                    (.inbounds[$index].settings.clients // [])
                    | .[]
                    | [
                        .email,
                        (.id // .password)
                      ]
                    | @tsv
                    ' \
                    "$XRAY_CFG"
            )
        fi

        echo
    done

    pause
}

# ==============================================================
# GENERAR VMESS
# ==============================================================

generate_vmess_link() {

    local USER="$1"
    local UUID="$2"
    local PORT="$3"
    local SECURITY="$4"

    load_host

    local TLS_VALUE=""

    if [[ "$SECURITY" == "tls" ]]; then

        TLS_VALUE="tls"

    else

        TLS_VALUE=""
    fi

    cat <<EOF | base64 -w 0
{
  "v":"2",
  "ps":"$USER",
  "add":"$HOST",
  "port":"$PORT",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$HOST",
  "path":"$VMESS_PATH",
  "tls":"$TLS_VALUE",
  "sni":"$HOST"
}
EOF
}

# ==============================================================
# GENERAR LINK
# ==============================================================

generate_link() {

    local PROTOCOL="$1"
    local USER="$2"
    local PUBLIC_PORT="$3"

    load_host

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USER")

    [[ -z "$ID" ||
       "$ID" == "null" ]] && return 1

    case "$PROTOCOL" in

        vmess)

            local VMESS_SECURITY="none"

            [[ "$PUBLIC_PORT" == "443" ]] &&
                VMESS_SECURITY="tls"

            echo \
                "vmess://$(generate_vmess_link \
                    "$USER" \
                    "$ID" \
                    "$PUBLIC_PORT" \
                    "$VMESS_SECURITY")"

            ;;

        vless)

            if [[ "$PUBLIC_PORT" == "443" ]]; then

                echo \
                    "vless://${ID}@${HOST}:443?encryption=none&security=tls&type=ws&host=${HOST}&path=${VLESS_PATH}&sni=${HOST}#${USER}"

            else

                echo \
                    "vless://${ID}@${HOST}:${PUBLIC_PORT}?encryption=none&security=none&type=ws&host=${HOST}&path=${VLESS_PATH}#${USER}"

            fi

            ;;

        trojan)

            if [[ "$PUBLIC_PORT" == "443" ]]; then

                echo \
                    "trojan://${ID}@${HOST}:443?security=tls&type=ws&host=${HOST}&path=${TROJAN_PATH}&sni=${HOST}#${USER}"

            else

                echo \
                    "trojan://${ID}@${HOST}:${PUBLIC_PORT}?security=none&type=ws&host=${HOST}&path=${TROJAN_PATH}#${USER}"

            fi

            ;;

        grpc)

            if [[ "$PUBLIC_PORT" == "443" ]]; then

                echo \
                    "vless://${ID}@${HOST}:443?encryption=none&security=tls&type=grpc&serviceName=${GRPC_SERVICE}&sni=${HOST}#${USER}"

            else

                echo \
                    "vless://${ID}@${HOST}:${PUBLIC_PORT}?encryption=none&security=none&type=grpc&serviceName=${GRPC_SERVICE}#${USER}"

            fi

            ;;

        *)

            return 1
            ;;
    esac
}

# ==============================================================
# SELECCIONAR PUERTO
# ==============================================================

select_public_port() {

    echo

    echo -e \
        "${WHITE}${BOLD}Selecciona puerto público HAProxy:${RESET}"

    echo

    echo -e \
        "${GREEN}[1]${RESET} 443 ${GRAY}(TLS)${RESET}"

    echo -e \
        "${GREEN}[2]${RESET} 80  ${GRAY}(HTTP)${RESET}"

    echo -e \
        "${GREEN}[3]${RESET} 8080 ${GRAY}(Alternativo)${RESET}"

    echo

    read -rp \
        "$(echo -e "${CYAN}➜ Puerto [1]: ${RESET}")" \
        PORT_OP

    case "$PORT_OP" in

        2)
            echo "80"
            ;;

        3)
            echo "8080"
            ;;

        *)
            echo "443"
            ;;
    esac
}

# ==============================================================
# MOSTRAR CUENTA INDIVIDUAL
# ==============================================================

show_created_single() {

    local PROTOCOL="$1"
    local USER="$2"
    local ID="$3"

    load_host

    local PORT

    PORT=$(select_public_port)

    local LINK

    LINK=$(generate_link \
        "$PROTOCOL" \
        "$USER" \
        "$PORT")

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}              ${GREEN}${BOLD}🎉 CUENTA CREADA${RESET}                          ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${WHITE}👤 Usuario:${RESET}  ${GREEN}$USER${RESET}"

    echo -e \
        "${WHITE}🔐 Protocolo:${RESET} ${GREEN}${PROTOCOL^^}${RESET}"

    echo -e \
        "${WHITE}🆔 ID:${RESET}       ${YELLOW}$ID${RESET}"

    echo -e \
        "${WHITE}🌐 Host:${RESET}     ${GREEN}$HOST${RESET}"

    echo -e \
        "${WHITE}🔌 Puerto:${RESET}   ${GREEN}$PORT${RESET}"

    case "$PROTOCOL" in

        vless)

            echo -e \
                "${WHITE}📡 Network:${RESET}  ${GREEN}WebSocket${RESET}"

            echo -e \
                "${WHITE}📂 Path:${RESET}     ${GREEN}$VLESS_PATH${RESET}"

            ;;

        vmess)

            echo -e \
                "${WHITE}📡 Network:${RESET}  ${GREEN}WebSocket${RESET}"

            echo -e \
                "${WHITE}📂 Path:${RESET}     ${GREEN}$VMESS_PATH${RESET}"

            ;;

        trojan)

            echo -e \
                "${WHITE}📡 Network:${RESET}  ${GREEN}WebSocket${RESET}"

            echo -e \
                "${WHITE}📂 Path:${RESET}     ${GREEN}$TROJAN_PATH${RESET}"

            ;;

        grpc)

            echo -e \
                "${WHITE}📡 Network:${RESET}  ${GREEN}gRPC${RESET}"

            echo -e \
                "${WHITE}⚙️ Service:${RESET}  ${GREEN}$GRPC_SERVICE${RESET}"

            ;;
    esac

    if [[ "$PORT" == "443" ]]; then

        echo -e \
            "${WHITE}🛡️ TLS:${RESET}      ${GREEN}Activado${RESET}"

    else

        echo -e \
            "${WHITE}🛡️ TLS:${RESET}      ${YELLOW}Según HAProxy${RESET}"

    fi

    line

    echo -e \
        "${YELLOW}${BOLD}🔗 ENLACE${RESET}"

    echo

    echo -e \
        "${GREEN}$LINK${RESET}"

    echo

    ok "Cuenta lista para utilizar."

    pause
}

# ==============================================================
# MOSTRAR CUATRO CUENTAS
# ==============================================================

show_created_all() {

    local USER="$1"
    local ID="$2"

    load_host

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}          ${GREEN}${BOLD}🎉 CUENTA MULTIPROTOCOLO CREADA${RESET}               ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${WHITE}👤 Usuario:${RESET} ${GREEN}$USER${RESET}"

    echo -e \
        "${WHITE}🌐 Host:${RESET}    ${GREEN}$HOST${RESET}"

    echo -e \
        "${WHITE}🆔 ID:${RESET}      ${YELLOW}$ID${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    # ----------------------------------------------------------
    # VLESS
    # ----------------------------------------------------------

    echo -e \
        "${BLUE}${BOLD}🔐 VLESS${RESET}"

    echo -e \
        "${WHITE}Puerto interno:${RESET} ${GREEN}$VLESS_PORT${RESET}"

    echo -e \
        "${WHITE}Path:${RESET}          ${GREEN}$VLESS_PATH${RESET}"

    echo -e \
        "${WHITE}Puerto público:${RESET} ${GREEN}443 / 80 / 8080${RESET}"

    echo

    echo -e \
        "${YELLOW}VLESS 443 TLS:${RESET}"

    echo -e \
        "${GREEN}$(generate_link vless "$USER" 443)${RESET}"

    echo

    echo -e \
        "${YELLOW}VLESS 80:${RESET}"

    echo -e \
        "${GREEN}$(generate_link vless "$USER" 80)${RESET}"

    echo

    echo -e \
        "${YELLOW}VLESS 8080:${RESET}"

    echo -e \
        "${GREEN}$(generate_link vless "$USER" 8080)${RESET}"

    echo

    line

    # ----------------------------------------------------------
    # VMESS
    # ----------------------------------------------------------

    echo -e \
        "${BLUE}${BOLD}⚡ VMess${RESET}"

    echo -e \
        "${WHITE}Puerto interno:${RESET} ${GREEN}$VMESS_PORT${RESET}"

    echo -e \
        "${WHITE}Path:${RESET}          ${GREEN}$VMESS_PATH${RESET}"

    echo

    echo -e \
        "${YELLOW}VMess 443 TLS:${RESET}"

    echo -e \
        "${GREEN}$(generate_link vmess "$USER" 443)${RESET}"

    echo

    echo -e \
        "${YELLOW}VMess 80:${RESET}"

    echo -e \
        "${GREEN}$(generate_link vmess "$USER" 80)${RESET}"

    echo

    echo -e \
        "${YELLOW}VMess 8080:${RESET}"

    echo -e \
        "${GREEN}$(generate_link vmess "$USER" 8080)${RESET}"

    echo

    line

    # ----------------------------------------------------------
    # TROJAN
    # ----------------------------------------------------------

    echo -e \
        "${BLUE}${BOLD}🛡️ Trojan${RESET}"

    echo -e \
        "${WHITE}Puerto interno:${RESET} ${GREEN}$TROJAN_PORT${RESET}"

    echo -e \
        "${WHITE}Path:${RESET}          ${GREEN}$TROJAN_PATH${RESET}"

    echo

    echo -e \
        "${YELLOW}Trojan 443 TLS:${RESET}"

    echo -e \
        "${GREEN}$(generate_link trojan "$USER" 443)${RESET}"

    echo

    echo -e \
        "${YELLOW}Trojan 80:${RESET}"

    echo -e \
        "${GREEN}$(generate_link trojan "$USER" 80)${RESET}"

    echo

    echo -e \
        "${YELLOW}Trojan 8080:${RESET}"

    echo -e \
        "${GREEN}$(generate_link trojan "$USER" 8080)${RESET}"

    echo

    line

    # ----------------------------------------------------------
    # GRPC
    # ----------------------------------------------------------

    echo -e \
        "${BLUE}${BOLD}🚀 gRPC${RESET}"

    echo -e \
        "${WHITE}Puerto interno:${RESET} ${GREEN}$GRPC_PORT${RESET}"

    echo -e \
        "${WHITE}Service:${RESET}       ${GREEN}$GRPC_SERVICE${RESET}"

    echo

    echo -e \
        "${YELLOW}gRPC 443 TLS:${RESET}"

    echo -e \
        "${GREEN}$(generate_link grpc "$USER" 443)${RESET}"

    echo

    echo -e \
        "${YELLOW}gRPC 80:${RESET}"

    echo -e \
        "${GREEN}$(generate_link grpc "$USER" 80)${RESET}"

    echo

    echo -e \
        "${YELLOW}gRPC 8080:${RESET}"

    echo -e \
        "${GREEN}$(generate_link grpc "$USER" 8080)${RESET}"

    echo

    echo -e \
        "${CYAN}══════════════════════════════════════════════════════════════${RESET}"

    ok "Los 4 protocolos fueron creados correctamente."

    pause
}

# ==============================================================
# MOSTRAR CUENTA
# ==============================================================

show_account() {

    header

    echo -e \
        "${WHITE}${BOLD}                 📄 MOSTRAR CUENTA${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    local FOUND=0

    for PROTOCOL in vless vmess trojan grpc; do

        if user_exists "$PROTOCOL" "$USERNAME"; then

            FOUND=1
            break
        fi
    done

    if [[ "$FOUND" -eq 0 ]]; then

        error_msg "Usuario no encontrado."

        pause

        return
    fi

    load_host

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}                 ${GREEN}${BOLD}📄 CUENTA${RESET}                            ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${WHITE}👤 Usuario:${RESET} ${GREEN}$USERNAME${RESET}"

    echo -e \
        "${WHITE}🌐 Host:${RESET}    ${GREEN}$HOST${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    for PROTOCOL in vless vmess trojan grpc; do

        if user_exists "$PROTOCOL" "$USERNAME"; then

            local ID

            ID=$(get_user_id "$PROTOCOL" "$USERNAME")

            echo -e \
                "${BLUE}${BOLD}━━ ${PROTOCOL^^} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

            echo -e \
                "${WHITE}ID:${RESET} ${YELLOW}$ID${RESET}"

            echo

            echo -e \
                "${YELLOW}443:${RESET}"

            echo -e \
                "${GREEN}$(generate_link "$PROTOCOL" "$USERNAME" 443)${RESET}"

            echo

            echo -e \
                "${YELLOW}80:${RESET}"

            echo -e \
                "${GREEN}$(generate_link "$PROTOCOL" "$USERNAME" 80)${RESET}"

            echo

            echo -e \
                "${YELLOW}8080:${RESET}"

            echo -e \
                "${GREEN}$(generate_link "$PROTOCOL" "$USERNAME" 8080)${RESET}"

            echo
        fi
    done

    pause
}

# ==============================================================
# GENERAR LINK
# ==============================================================

show_link() {

    header

    echo -e \
        "${WHITE}${BOLD}                 🔗 GENERAR ENLACE${RESET}"

    line

    echo

    echo -e "${GREEN}[1]${RESET} VLESS"
    echo -e "${GREEN}[2]${RESET} VMess"
    echo -e "${GREEN}[3]${RESET} Trojan"
    echo -e "${GREEN}[4]${RESET} gRPC"

    echo

    read -rp \
        "$(echo -e "${CYAN}➜ Protocolo: ${RESET}")" \
        OP

    case "$OP" in

        1)
            PROTOCOL="vless"
            ;;

        2)
            PROTOCOL="vmess"
            ;;

        3)
            PROTOCOL="trojan"
            ;;

        4)
            PROTOCOL="grpc"
            ;;

        *)
            error_msg "Protocolo inválido."
            pause
            return
            ;;
    esac

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if ! user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "Usuario no encontrado."

        pause

        return
    fi

    local PORT

    PORT=$(select_public_port)

    local LINK

    LINK=$(generate_link \
        "$PROTOCOL" \
        "$USERNAME" \
        "$PORT")

    echo

    echo -e \
        "${YELLOW}${BOLD}🔗 ENLACE${RESET}"

    echo

    echo -e \
        "${GREEN}$LINK${RESET}"

    pause
}

# ==============================================================
# USUARIOS ONLINE
# ==============================================================

xray_online_users() {

    header

    echo -e \
        "${WHITE}${BOLD}              🌐 USUARIOS ONLINE${RESET}"

    line

    if [[ ! -f "$XRAY_LOG" ]]; then

        error_msg "No existe access.log."

        pause

        return
    fi

    echo

    tail -n 500 "$XRAY_LOG" |
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
        "${WHITE}${BOLD}                 📊 ESTADO XRAY${RESET}"

    line

    echo

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

    load_host

    echo -e \
        "${WHITE}Estado:${RESET}        $STATUS"

    echo -e \
        "${WHITE}Versión:${RESET}       ${GREEN}$VERSION_INFO${RESET}"

    echo -e \
        "${WHITE}Servicio:${RESET}      ${GREEN}$XRAY_SERVICE${RESET}"

    echo -e \
        "${WHITE}Host:${RESET}          ${GREEN}$HOST${RESET}"

    echo -e \
        "${WHITE}Config:${RESET}        ${GREEN}$XRAY_CFG${RESET}"

    echo

    echo -e \
        "${WHITE}Puertos internos:${RESET}"

    echo -e \
        "  VLESS  : ${GREEN}127.0.0.1:$VLESS_PORT${RESET}"

    echo -e \
        "  VMess  : ${GREEN}127.0.0.1:$VMESS_PORT${RESET}"

    echo -e \
        "  Trojan : ${GREEN}127.0.0.1:$TROJAN_PORT${RESET}"

    echo -e \
        "  gRPC   : ${GREEN}127.0.0.1:$GRPC_PORT${RESET}"

    echo

    echo -e \
        "${WHITE}Puertos públicos HAProxy:${RESET}"

    echo -e \
        "  ${GREEN}80${RESET} / ${GREEN}443${RESET} / ${GREEN}8080${RESET}"

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        if validate_xray_config; then

            ok "Xray acepta la configuración."

        else

            error_msg "Xray rechaza la configuración."

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
        "${WHITE}${BOLD}                 🔎 DIAGNÓSTICO XRAY${RESET}"

    line

    echo

    if xray_binary >/dev/null 2>&1; then
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

    if validate_json; then
        ok "JSON válido"
    else
        error_msg "JSON inválido"
    fi

    if xray_installed; then

        if validate_xray_config; then
            ok "Xray acepta la configuración"
        else
            error_msg "Xray rechaza la configuración"
        fi
    fi

    if xray_active; then
        ok "Servicio Xray activo"
    else
        error_msg "Servicio Xray detenido"
    fi

    echo

    echo -e \
        "${WHITE}Puertos internos:${RESET}"

    ss -lntp 2>/dev/null |
        grep -E \
            ":(10001|10002|10003|10004)\b" ||
        warning "No se detectaron puertos internos."

    echo

    echo -e \
        "${WHITE}Puertos públicos esperados por HAProxy:${RESET}"

    ss -lntp 2>/dev/null |
        grep -E \
            ":(80|443|8080)\b" ||
        warning "No se detectaron 80/443/8080."

    echo

    echo -e \
        "${WHITE}Últimos registros:${RESET}"

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
        -n 50 \
        --no-pager 2>/dev/null

    echo

    if [[ -f "$XRAY_LOG" ]]; then

        echo -e \
            "${WHITE}Últimas líneas de access.log:${RESET}"

        tail -n 30 "$XRAY_LOG"
    fi

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_xray_service() {

    header

    echo -e \
        "${WHITE}${BOLD}                 ♻️ REINICIAR XRAY${RESET}"

    line

    echo

    info "Validando configuración..."

    if ! validate_xray_config; then

        pause

        return 1
    fi

    info "Reiniciando Xray..."

    if ! systemctl restart "$XRAY_SERVICE"; then

        error_msg "El comando de reinicio falló."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null

        pause

        return 1
    fi

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        ok "Xray reiniciado correctamente."

    else

        set_config "XRAY" "OFF"

        error_msg "Xray no pudo iniciar."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_xray() {

    header

    warning "Se eliminará Xray Core y su configuración."

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

    else

        warning "No se pudo descargar el desinstalador."

    fi

    rm -rf "$XRAY_DIR"
    rm -rf "$XRAY_LOG_DIR"

    rm -rf \
        /etc/systemd/system/xray.service.d

    systemctl daemon-reload
    systemctl reset-failed xray 2>/dev/null

    set_config "XRAY" "OFF"

    echo

    ok "Xray fue eliminado correctamente."

    pause
}

# ==============================================================
# SUBMENÚ LISTAR
# ==============================================================

list_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}                 📋 LISTAR CUENTAS${RESET}"

        line

        echo

        echo -e \
            "${GREEN}[01]${RESET} VLESS"

        echo -e \
            "${GREEN}[02]${RESET} VMess"

        echo -e \
            "${GREEN}[03]${RESET} Trojan"

        echo -e \
            "${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "${MAGENTA}[05]${RESET} 👥 TODOS"

        echo

        echo -e \
            "${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)
                list_protocol_users "vless"
                ;;

            2)
                list_protocol_users "vmess"
                ;;

            3)
                list_protocol_users "trojan"
                ;;

            4)
                list_protocol_users "grpc"
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

remove_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}                 🗑️ ELIMINAR CUENTA${RESET}"

        line

        echo

        echo -e \
            "${GREEN}[01]${RESET} Eliminar VLESS"

        echo -e \
            "${GREEN}[02]${RESET} Eliminar VMess"

        echo -e \
            "${GREEN}[03]${RESET} Eliminar Trojan"

        echo -e \
            "${GREEN}[04]${RESET} Eliminar gRPC"

        echo

        echo -e \
            "${MAGENTA}[05]${RESET} 🗑️ Eliminar de TODOS"

        echo

        echo -e \
            "${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" \
            OP

        case "$OP" in

            1)
                remove_single_protocol "vless"
                ;;

            2)
                remove_single_protocol "vmess"
                ;;

            3)
                remove_single_protocol "trojan"
                ;;

            4)
                remove_single_protocol "grpc"
                ;;

            5)
                remove_user
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
# ELIMINAR UN SOLO PROTOCOLO
# ==============================================================

remove_single_protocol() {

    local PROTOCOL="$1"

    header

    echo -e \
        "${WHITE}${BOLD}              🗑️ ELIMINAR ${PROTOCOL^^}${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Usuario: ${RESET}")" \
        USERNAME

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

    echo -e \
        "${WHITE}Usuario:${RESET} ${GREEN}$USERNAME${RESET}"

    echo -e \
        "${WHITE}ID:${RESET}      ${YELLOW}$ID${RESET}"

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    [[ "$CONFIRM" != "ELIMINAR" ]] && {

        warning "Operación cancelada."

        pause

        return
    }

    local TMP

    TMP=$(mktemp --suffix=.json)

    cp -f "$XRAY_CFG" "$TMP"

    if ! remove_user_from_file \
        "$TMP" \
        "$PROTOCOL" \
        "$USERNAME"; then

        rm -f "$TMP"

        error_msg "No se pudo modificar la configuración."

        pause

        return
    fi

    echo

    info "Validando configuración..."

    if ! validate_xray_file "$TMP"; then

        rm -f "$TMP"

        error_msg "El config.json NO fue modificado."

        pause

        return
    fi

    mv -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    info "Reiniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        ok "Xray reiniciado correctamente."

        ok "Usuario '$USERNAME' eliminado de ${PROTOCOL^^}."

    else

        error_msg "Xray no pudo reiniciar."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
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

        local TOTAL_VLESS
        local TOTAL_VMESS
        local TOTAL_TROJAN
        local TOTAL_GRPC

        TOTAL_VLESS=$(get_total vless)
        TOTAL_VMESS=$(get_total vmess)
        TOTAL_TROJAN=$(get_total trojan)
        TOTAL_GRPC=$(get_total grpc)

        TOTAL_VLESS="${TOTAL_VLESS:-0}"
        TOTAL_VMESS="${TOTAL_VMESS:-0}"
        TOTAL_TROJAN="${TOTAL_TROJAN:-0}"
        TOTAL_GRPC="${TOTAL_GRPC:-0}"

        local TOTAL_USERS=$(
            echo $((TOTAL_VLESS +
                TOTAL_VMESS +
                TOTAL_TROJAN +
                TOTAL_GRPC))
        )

        echo -e \
            "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

        echo -e \
            "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                  ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${WHITE}Estado:${RESET}        $STATUS"

        echo -e \
            "${WHITE}Host:${RESET}          ${GREEN}$HOST${RESET}"

        echo -e \
            "${WHITE}Frontend:${RESET}      ${GREEN}HAProxy${RESET}"

        echo -e \
            "${WHITE}Públicos:${RESET}      ${GREEN}80 / 443 / 8080${RESET}"

        echo -e \
            "${WHITE}Versión:${RESET}       ${GREEN}$VERSION_INFO${RESET}"

        echo -e \
            "${WHITE}VLESS:${RESET}         ${GREEN}$TOTAL_VLESS${RESET}"

        echo -e \
            "${WHITE}VMess:${RESET}         ${GREEN}$TOTAL_VMESS${RESET}"

        echo -e \
            "${WHITE}Trojan:${RESET}        ${GREEN}$TOTAL_TROJAN${RESET}"

        echo -e \
            "${WHITE}gRPC:${RESET}          ${GREEN}$TOTAL_GRPC${RESET}"

        echo -e \
            "${WHITE}Total cuentas:${RESET} ${GREEN}$TOTAL_USERS${RESET}"

        line

        if xray_installed; then

            echo -e \
                "${BLUE}${BOLD}  👥 GESTIÓN DE CUENTAS${RESET}"

            echo

            echo -e \
                "  ${GREEN}[01]${RESET} 👤 Crear Cuenta"

            echo -e \
                "  ${GREEN}[02]${RESET} 📋 Listar Cuentas"

            echo -e \
                "  ${GREEN}[03]${RESET} 🗑️  Eliminar Cuenta"

            echo -e \
                "  ${GREEN}[04]${RESET} 📄 Mostrar Cuenta"

            echo

            echo -e \
                "${BLUE}${BOLD}  🔗 HERRAMIENTAS${RESET}"

            echo

            echo -e \
                "  ${GREEN}[05]${RESET} 🔗 Generar Enlace"

            echo -e \
                "  ${GREEN}[06]${RESET} 🌐 Usuarios Online"

            echo

            echo -e \
                "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN XRAY${RESET}"

            echo

            echo -e \
                "  ${GREEN}[07]${RESET} ♻️  Reiniciar Xray"

            echo -e \
                "  ${GREEN}[08]${RESET} 📊 Estado"

            echo -e \
                "  ${GREEN}[09]${RESET} 🔎 Diagnóstico"

            echo -e \
                "  ${GREEN}[10]${RESET} 📜 Logs"

            echo -e \
                "  ${GREEN}[11]${RESET} 🔄 Reinstalar / Actualizar"

            echo -e \
                "  ${RED}[12]${RESET} 🗑️  Desinstalar Xray"

        else

            echo -e \
                "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"

            echo

            echo -e \
                "  ${GREEN}[01]${RESET} 🚀 Instalar Xray Core"

        fi

        echo

        echo -e \
            "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

        echo -e \
            "  ${RED}${BOLD}[00]${RESET} ↩️ Regresar"

        echo

        echo -e \
            "${GRAY}KevinTech Multi Script • Xray Manager v$VERSION${RESET}"

        echo

        read -rp \
            "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)

                if xray_installed; then

                    create_menu

                else

                    install_xray
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

                    remove_menu

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi

                ;;

            4)

                if xray_installed; then

                    show_account

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi

                ;;

            5)

                if xray_installed; then

                    show_link

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi

                ;;

            6)

                if xray_installed; then

                    xray_online_users

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi

                ;;

            7)

                if xray_installed; then

                    restart_xray_service

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi

                ;;

            8)

                xray_status

                ;;

            9)

                xray_diagnostic

                ;;

            10)

                if xray_installed; then

                    show_xray_logs

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi

                ;;

            11)

                install_xray

                ;;

            12)

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