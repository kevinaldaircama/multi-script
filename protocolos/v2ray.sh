#!/bin/bash

# ==============================================================
#              KEVINTECH MULTI SCRIPT
#                    XRAY MANAGER v5.3
# ==============================================================
#
# Protocolos:
#   VLESS
#   VMess
#   Trojan
#   gRPC
#
# Host:
#   DOMINIO o IP
#
# Xray:
#   /usr/local/bin/xray
#
# Config:
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

VERSION="5.3"

# ==============================================================
# PUERTOS INTERNOS
# ==============================================================

VLESS_PORT=10001
VMESS_PORT=10002
TROJAN_PORT=10003
GRPC_PORT=10004

# ==============================================================
# TRANSPORTES
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

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}✘ Ejecuta este script como root.${RESET}"
    exit 1
fi

# ==============================================================
# CONFIG
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then
    echo -e "${RED}✘ No existe: $CONFIG${RESET}"
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null

# ==============================================================
# VISUAL
# ==============================================================

line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

header() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                            ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}          ${GRAY}VLESS / VMess / Trojan / gRPC${RESET}              ${CYAN}║${RESET}"
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
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

# ==============================================================
# HOST: DOMINIO O IP
# ==============================================================

load_host() {

    DOMAIN=""

    # ----------------------------------------------------------
    # CONFIG.CONF
    # ----------------------------------------------------------

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    DOMAIN="${SERVER_DOMAIN:-}"
    DOMAIN="$(echo "$DOMAIN" | tr -d '[:space:]')"

    # ----------------------------------------------------------
    # DOMINIO CONFIGURADO
    # ----------------------------------------------------------

    if [[ -n "$DOMAIN" ]]; then

        HOST="$DOMAIN"
        HOST_TYPE="DOMINIO"

        return 0
    fi

    # ----------------------------------------------------------
    # /etc/xray/domain
    # ----------------------------------------------------------

    if [[ -f /etc/xray/domain ]]; then

        DOMAIN="$(cat /etc/xray/domain 2>/dev/null)"
        DOMAIN="$(echo "$DOMAIN" | tr -d '[:space:]')"

        if [[ -n "$DOMAIN" ]]; then

            HOST="$DOMAIN"
            HOST_TYPE="DOMINIO"

            return 0
        fi
    fi

    # ----------------------------------------------------------
    # IP PÚBLICA
    # ----------------------------------------------------------

    PUBLIC_IP=""

    if command -v curl >/dev/null 2>&1; then

        PUBLIC_IP=$(curl -4 -fsS \
            --max-time 5 \
            https://api.ipify.org 2>/dev/null)
    fi

    if [[ -z "$PUBLIC_IP" ]] &&
       command -v wget >/dev/null 2>&1; then

        PUBLIC_IP=$(wget -qO- \
            --timeout=5 \
            https://api.ipify.org 2>/dev/null)
    fi

    if [[ -z "$PUBLIC_IP" ]]; then

        PUBLIC_IP=$(hostname -I 2>/dev/null |
            awk '{print $1}')
    fi

    if [[ -n "$PUBLIC_IP" ]]; then

        HOST="$PUBLIC_IP"
        HOST_TYPE="IP"

        return 0
    fi

    HOST=""
    HOST_TYPE=""

    return 1
}

load_domain() {
    load_host
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
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    info "Instalando dependencias..."

    apt-get update -y >/dev/null 2>&1 || {
        error_msg "No se pudo actualizar APT."
        return 1
    }

    apt-get install -y \
        curl \
        wget \
        jq \
        ca-certificates \
        uuid-runtime \
        >/dev/null 2>&1 || {

        error_msg "No se pudieron instalar las dependencias."
        return 1
    }

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
# BACKUP
# ==============================================================

backup_xray_config() {

    [[ ! -f "$XRAY_CFG" ]] && return 0

    local DIR="$XRAY_DIR/backups"

    mkdir -p "$DIR"

    local FILE

    FILE="$DIR/config-$(date '+%Y%m%d-%H%M%S').json"

    cp -f "$XRAY_CFG" "$FILE"

    chmod 600 "$FILE"

    echo "$FILE"
}

# ==============================================================
# VALIDAR JSON
# ==============================================================

validate_json() {

    [[ -f "$XRAY_CFG" ]] || return 1

    jq empty "$XRAY_CFG" >/dev/null 2>&1
}

# ==============================================================
# VALIDAR CONFIG XRAY
# ==============================================================

validate_xray_config() {

    [[ -f "$XRAY_CFG" ]] || return 1

    if ! jq empty "$XRAY_CFG" >/dev/null 2>&1; then

        error_msg "JSON inválido."

        return 1
    fi

    if ! xray run \
        -test \
        -config "$XRAY_CFG" \
        >/tmp/kevintech-xray-test.log 2>&1; then

        error_msg "Xray rechazó la configuración."

        cat /tmp/kevintech-xray-test.log

        rm -f /tmp/kevintech-xray-test.log

        return 1
    fi

    rm -f /tmp/kevintech-xray-test.log

    return 0
}

# ==============================================================
# VALIDAR ARCHIVO TEMPORAL
#
# IMPORTANTE:
# Xray necesita reconocer el formato del archivo.
# Por eso SIEMPRE usamos extensión .json.
# ==============================================================

validate_temp_config() {

    local SOURCE="$1"

    [[ -f "$SOURCE" ]] || return 1

    local TEMP_JSON

    TEMP_JSON="$(mktemp --suffix=.json)"

    cp -f "$SOURCE" "$TEMP_JSON"

    # ----------------------------------------------------------
    # JSON
    # ----------------------------------------------------------

    if ! jq empty "$TEMP_JSON" >/dev/null 2>&1; then

        rm -f "$TEMP_JSON"

        error_msg "JSON temporal inválido."

        return 1
    fi

    # ----------------------------------------------------------
    # XRAY
    # ----------------------------------------------------------

    if ! xray run \
        -test \
        -config "$TEMP_JSON" \
        >/tmp/kevintech-temp-test.log 2>&1; then

        cat /tmp/kevintech-temp-test.log

        rm -f \
            "$TEMP_JSON" \
            /tmp/kevintech-temp-test.log

        return 1
    fi

    rm -f \
        "$TEMP_JSON" \
        /tmp/kevintech-temp-test.log

    return 0
}

# ==============================================================
# CREAR CONFIG BASE
# ==============================================================

create_base_config() {

    local TEMP

    TEMP="$(mktemp --suffix=.json)"

    cat > "$TEMP" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$XRAY_LOG"
  },

  "inbounds": [

    {
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

    if ! validate_temp_config "$TEMP"; then

        rm -f "$TEMP"

        error_msg "Xray rechazó la configuración base."

        return 1
    fi

    mv "$TEMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    ok "Configuración base creada."

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
}

# ==============================================================
# INSTALAR XRAY
# ==============================================================

install_xray_core() {

    info "Instalando Xray Core..."

    local INSTALLER="/tmp/xray-install.sh"

    rm -f "$INSTALLER"

    if ! curl -fL \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        -o "$INSTALLER"; then

        error_msg "No se pudo descargar Xray."

        rm -f "$INSTALLER"

        return 1
    fi

    chmod 700 "$INSTALLER"

    if ! bash "$INSTALLER" install; then

        error_msg "Falló la instalación de Xray."

        rm -f "$INSTALLER"

        return 1
    fi

    rm -f "$INSTALLER"

    command -v xray >/dev/null 2>&1 || {

        error_msg "Xray no quedó instalado."

        return 1
    }

    ok "Xray Core instalado."

    return 0
}

# ==============================================================
# INSTALAR / REPARAR
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

    # ----------------------------------------------------------
    # CONFIG EXISTENTE
    # ----------------------------------------------------------

    if [[ -f "$XRAY_CFG" ]] &&
       validate_json &&
       validate_xray_config; then

        ok "Configuración existente válida."

    else

        if [[ -f "$XRAY_CFG" ]]; then

            local BACKUP

            BACKUP=$(backup_xray_config)

            warning "La configuración existente no es válida."

            [[ -n "$BACKUP" ]] && {
                ok "Backup creado:"
                echo "$BACKUP"
            }
        fi

        if ! create_base_config; then

            pause
            return 1
        fi
    fi

    ensure_xray_resilience

    if ! validate_xray_config; then

        error_msg "La configuración final no es válida."

        pause

        return 1
    fi

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        ok "Xray está activo."

    else

        set_config "XRAY" "OFF"

        error_msg "Xray no pudo iniciar."

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 30 \
            --no-pager 2>/dev/null
    fi

    pause
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
        (.inbounds[$index].settings.clients // []) |
        any(.email == $email)
        ' \
        "$XRAY_CFG" >/dev/null 2>&1
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
        (.inbounds[$index].settings.clients // [])[]
        | select(.email == $email)
        | (.id // .password)
        ' \
        "$XRAY_CFG" 2>/dev/null
}

# ==============================================================
# AGREGAR USUARIO
# ==============================================================

add_user_to_file() {

    local FILE="$1"
    local PROTOCOL="$2"
    local USERNAME="$3"
    local ID="$4"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return 1

    local TMP

    TMP="$(mktemp --suffix=.json)"

    if [[ "$PROTOCOL" == "trojan" ]]; then

        jq \
            --arg password "$ID" \
            --arg email "$USERNAME" \
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
            "$FILE" > "$TMP"

    else

        jq \
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
            "$FILE" > "$TMP"
    fi

    if [[ $? -ne 0 ]]; then

        rm -f "$TMP"

        return 1
    fi

    mv "$TMP" "$FILE"

    return 0
}

# ==============================================================
# CREAR USUARIO
# ==============================================================

create_user() {

    local PROTOCOL="$1"

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    if ! validate_xray_config; then

        return 1
    fi

    load_host

    if [[ -z "$HOST" ]]; then

        error_msg "No existe dominio ni IP."

        return 1
    fi

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Nombre del usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && {
        error_msg "Usuario vacío."
        return 1
    }

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre inválido."

        return 1
    fi

    if user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "El usuario ya existe."

        return 1
    fi

    local ID

    ID=$(generate_uuid) || return 1

    local BACKUP

    BACKUP=$(backup_xray_config)

    local TEMP

    TEMP="$(mktemp --suffix=.json)"

    cp -f "$XRAY_CFG" "$TEMP"

    if ! add_user_to_file \
        "$TEMP" \
        "$PROTOCOL" \
        "$USERNAME" \
        "$ID"; then

        rm -f "$TEMP"

        error_msg "No se pudo modificar la configuración."

        return 1
    fi

    if ! validate_temp_config "$TEMP"; then

        rm -f "$TEMP"

        error_msg "Xray rechazó la configuración."

        return 1
    fi

    mv "$TEMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo reiniciar."

        if [[ -n "$BACKUP" &&
              -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart "$XRAY_SERVICE"

            warning "Backup restaurado."
        fi

        return 1
    fi

    USER_PROTOCOL="$PROTOCOL"
    USER_NAME="$USERNAME"
    USER_ID="$ID"

    ok "Cuenta ${PROTOCOL^^} creada."

    return 0
}

# ==============================================================
# VMESS LINK
# ==============================================================

generate_vmess_link() {

    local USER="$1"
    local UUID="$2"

    load_host

    cat <<EOF | base64 -w 0
{
  "v":"2",
  "ps":"$USER",
  "add":"$HOST",
  "port":"443",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$HOST",
  "path":"$VMESS_PATH",
  "tls":"tls",
  "sni":"$HOST"
}
EOF
}

# ==============================================================
# LINKS
# ==============================================================

generate_link_from_id() {

    local PROTOCOL="$1"
    local USER="$2"
    local ID="$3"

    load_host

    [[ -z "$HOST" ]] && return 1

    case "$PROTOCOL" in

        vless)

            echo \
                "vless://${ID}@${HOST}:443?encryption=none&security=tls&type=ws&host=${HOST}&path=${VLESS_PATH}&sni=${HOST}#${USER}"

            ;;

        vmess)

            echo \
                "vmess://$(generate_vmess_link "$USER" "$ID")"

            ;;

        trojan)

            echo \
                "trojan://${ID}@${HOST}:443?security=tls&type=ws&host=${HOST}&path=${TROJAN_PATH}&sni=${HOST}#${USER}"

            ;;

        grpc)

            echo \
                "vless://${ID}@${HOST}:443?encryption=none&security=tls&type=grpc&serviceName=${GRPC_SERVICE}&sni=${HOST}#${USER}"

            ;;

        *)

            return 1
            ;;
    esac
}

generate_link() {

    local PROTOCOL="$1"
    local USER="$2"

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USER")

    [[ -z "$ID" ||
       "$ID" == "null" ]] && return 1

    generate_link_from_id \
        "$PROTOCOL" \
        "$USER" \
        "$ID"
}

# ==============================================================
# MOSTRAR CUENTA
# ==============================================================

create_and_show() {

    local PROTOCOL="$1"

    if ! create_user "$PROTOCOL"; then

        pause
        return
    fi

    load_host

    local LINK

    LINK=$(generate_link \
        "$USER_PROTOCOL" \
        "$USER_NAME")

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}                ${GREEN}${BOLD}🎉 CUENTA CREADA${RESET}                         ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Protocolo:${RESET} ${GREEN}${USER_PROTOCOL^^}${RESET}"
    echo -e "${WHITE}Usuario:${RESET}   ${GREEN}$USER_NAME${RESET}"
    echo -e "${WHITE}ID:${RESET}        ${YELLOW}$USER_ID${RESET}"
    echo -e "${WHITE}Host:${RESET}      ${GREEN}$HOST${RESET}"
    echo -e "${WHITE}Tipo:${RESET}      ${GREEN}$HOST_TYPE${RESET}"
    echo -e "${WHITE}Puerto:${RESET}    ${GREEN}443${RESET}"

    echo

    line

    echo -e "${YELLOW}${BOLD}🔗 ENLACE${RESET}"
    echo
    echo -e "${GREEN}$LINK${RESET}"

    echo

    pause
}

# ==============================================================
# CREAR TODOS
# ==============================================================

create_all_users() {

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

    [[ -z "$HOST" ]] && {

        error_msg "No existe dominio ni IP."

        pause
        return
    }

    header

    echo -e \
        "${WHITE}${BOLD}          ⭐ CREAR CUENTA MULTIPROTOCOLO${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Nombre del usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && {

        error_msg "Usuario vacío."

        pause
        return
    }

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre inválido."

        pause
        return
    fi

    echo

    echo -e "${WHITE}Usuario:${RESET} ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}Host:${RESET}    ${GREEN}$HOST${RESET}"
    echo -e "${WHITE}Tipo:${RESET}    ${GREEN}$HOST_TYPE${RESET}"

    echo

    echo -e "${GRAY}Se crearán:${RESET}"
    echo -e "  ${GREEN}✔ VLESS${RESET}"
    echo -e "  ${GREEN}✔ VMess${RESET}"
    echo -e "  ${GREEN}✔ Trojan${RESET}"
    echo -e "  ${GREEN}✔ gRPC${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Continuar? [S/n]: ${RESET}")" \
        CONFIRM

    [[ -z "$CONFIRM" ]] && CONFIRM="s"

    [[ ! "$CONFIRM" =~ ^[SsYy]$ ]] && {

        warning "Operación cancelada."

        pause
        return
    }

    # ----------------------------------------------------------
    # COPIA TEMPORAL JSON
    # ----------------------------------------------------------

    local TEMP

    TEMP="$(mktemp --suffix=.json)"

    cp -f "$XRAY_CFG" "$TEMP"

    local VLESS_ID=""
    local VMESS_ID=""
    local TROJAN_ID=""
    local GRPC_ID=""

    local CREATED=0
    local EXISTING=0

    # ----------------------------------------------------------
    # VLESS
    # ----------------------------------------------------------

    if user_exists "vless" "$USERNAME"; then

        VLESS_ID=$(get_user_id "vless" "$USERNAME")

        EXISTING=$((EXISTING + 1))

        warning "VLESS ya existe."

    else

        VLESS_ID=$(generate_uuid)

        add_user_to_file \
            "$TEMP" \
            "vless" \
            "$USERNAME" \
            "$VLESS_ID" || {

            rm -f "$TEMP"

            error_msg "Error preparando VLESS."

            pause
            return
        }

        CREATED=$((CREATED + 1))

        ok "VLESS preparado."
    fi

    # ----------------------------------------------------------
    # VMESS
    # ----------------------------------------------------------

    if user_exists "vmess" "$USERNAME"; then

        VMESS_ID=$(get_user_id "vmess" "$USERNAME")

        EXISTING=$((EXISTING + 1))

        warning "VMess ya existe."

    else

        VMESS_ID=$(generate_uuid)

        add_user_to_file \
            "$TEMP" \
            "vmess" \
            "$USERNAME" \
            "$VMESS_ID" || {

            rm -f "$TEMP"

            error_msg "Error preparando VMess."

            pause
            return
        }

        CREATED=$((CREATED + 1))

        ok "VMess preparado."
    fi

    # ----------------------------------------------------------
    # TROJAN
    # ----------------------------------------------------------

    if user_exists "trojan" "$USERNAME"; then

        TROJAN_ID=$(get_user_id "trojan" "$USERNAME")

        EXISTING=$((EXISTING + 1))

        warning "Trojan ya existe."

    else

        TROJAN_ID=$(generate_uuid)

        add_user_to_file \
            "$TEMP" \
            "trojan" \
            "$USERNAME" \
            "$TROJAN_ID" || {

            rm -f "$TEMP"

            error_msg "Error preparando Trojan."

            pause
            return
        }

        CREATED=$((CREATED + 1))

        ok "Trojan preparado."
    fi

    # ----------------------------------------------------------
    # GRPC
    # ----------------------------------------------------------

    if user_exists "grpc" "$USERNAME"; then

        GRPC_ID=$(get_user_id "grpc" "$USERNAME")

        EXISTING=$((EXISTING + 1))

        warning "gRPC ya existe."

    else

        GRPC_ID=$(generate_uuid)

        add_user_to_file \
            "$TEMP" \
            "grpc" \
            "$USERNAME" \
            "$GRPC_ID" || {

            rm -f "$TEMP"

            error_msg "Error preparando gRPC."

            pause
            return
        }

        CREATED=$((CREATED + 1))

        ok "gRPC preparado."
    fi

    # ----------------------------------------------------------
    # VALIDACIÓN
    # ----------------------------------------------------------

    echo

    info "Validando configuración completa..."

    if ! validate_temp_config "$TEMP"; then

        rm -f "$TEMP"

        error_msg "Xray rechazó la configuración."

        warning "El config.json original NO fue modificado."

        pause

        return
    fi

    ok "Configuración validada correctamente."

    # ----------------------------------------------------------
    # BACKUP
    # ----------------------------------------------------------

    local BACKUP

    BACKUP=$(backup_xray_config)

    # ----------------------------------------------------------
    # INSTALAR CONFIG
    # ----------------------------------------------------------

    mv "$TEMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    # ----------------------------------------------------------
    # REINICIAR
    # ----------------------------------------------------------

    info "Reiniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo iniciar."

        if [[ -n "$BACKUP" &&
              -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            chmod 600 "$XRAY_CFG"

            systemctl restart "$XRAY_SERVICE"

            warning "Backup restaurado."
        fi

        pause

        return
    fi

    # ----------------------------------------------------------
    # RESULTADO
    # ----------------------------------------------------------

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}       ${GREEN}${BOLD}🎉 CUENTA MULTIPROTOCOLO CREADA${RESET}                ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Usuario:${RESET} ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}Host:${RESET}    ${GREEN}$HOST${RESET}"
    echo -e "${WHITE}Tipo:${RESET}    ${GREEN}$HOST_TYPE${RESET}"

    echo

    echo -e "${CYAN}${BOLD}VLESS${RESET}"
    echo -e "UUID: ${YELLOW}$VLESS_ID${RESET}"

    echo

    echo -e "${CYAN}${BOLD}VMess${RESET}"
    echo -e "UUID: ${YELLOW}$VMESS_ID${RESET}"

    echo

    echo -e "${CYAN}${BOLD}Trojan${RESET}"
    echo -e "Password: ${YELLOW}$TROJAN_ID${RESET}"

    echo

    echo -e "${CYAN}${BOLD}gRPC${RESET}"
    echo -e "UUID: ${YELLOW}$GRPC_ID${RESET}"

    echo

    line

    echo -e "${YELLOW}${BOLD}🔗 ENLACES${RESET}"

    echo

    echo -e "${CYAN}VLESS:${RESET}"
    generate_link_from_id \
        "vless" \
        "$USERNAME" \
        "$VLESS_ID"

    echo

    echo -e "${CYAN}VMess:${RESET}"
    generate_link_from_id \
        "vmess" \
        "$USERNAME" \
        "$VMESS_ID"

    echo

    echo -e "${CYAN}Trojan:${RESET}"
    generate_link_from_id \
        "trojan" \
        "$USERNAME" \
        "$TROJAN_ID"

    echo

    echo -e "${CYAN}gRPC:${RESET}"
    generate_link_from_id \
        "grpc" \
        "$USERNAME" \
        "$GRPC_ID"

    echo

    line

    echo -e \
        "${WHITE}Nuevas:${RESET} ${GREEN}$CREATED${RESET}"

    echo -e \
        "${WHITE}Existentes:${RESET} ${YELLOW}$EXISTING${RESET}"

    echo

    ok "Xray está funcionando correctamente."

    pause
}

# ==============================================================
# LISTAR
# ==============================================================

list_users() {

    local PROTOCOL="$1"

    header

    echo -e \
        "${WHITE}${BOLD}              👥 USUARIOS ${PROTOCOL^^}${RESET}"

    line

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL")

    local TOTAL

    TOTAL=$(jq \
        --argjson index "$INDEX" \
        '(.inbounds[$index].settings.clients // []) | length' \
        "$XRAY_CFG" 2>/dev/null)

    TOTAL="${TOTAL:-0}"

    echo

    if [[ "$TOTAL" -eq 0 ]]; then

        echo -e "${YELLOW}No existen usuarios.${RESET}"

    else

        local I=0

        while IFS=$'\t' read -r USER ID; do

            I=$((I + 1))

            echo -e \
                "${GREEN}[$I]${RESET} ${WHITE}$USER${RESET}"

            echo -e \
                "    ${GRAY}$ID${RESET}"

        done < <(

            jq -r \
                --argjson index "$INDEX" \
                '
                (.inbounds[$index].settings.clients // [])[] |
                [.email, (.id // .password)] |
                @tsv
                ' \
                "$XRAY_CFG"
        )
    fi

    echo

    echo -e \
        "${WHITE}Total:${RESET} ${GREEN}$TOTAL${RESET}"

    pause
}

# ==============================================================
# LISTAR TODOS
# ==============================================================

list_all_users() {

    header

    echo -e \
        "${WHITE}${BOLD}             👥 TODAS LAS CUENTAS${RESET}"

    line

    echo

    for PROTOCOL in \
        vless \
        vmess \
        trojan \
        grpc; do

        local INDEX

        INDEX=$(inbound_index "$PROTOCOL")

        echo -e \
            "${CYAN}${BOLD}━━━ ${PROTOCOL^^} ━━━${RESET}"

        jq -r \
            --argjson index "$INDEX" \
            '
            (.inbounds[$index].settings.clients // [])[] |
            [.email, (.id // .password)] |
            @tsv
            ' \
            "$XRAY_CFG" 2>/dev/null |
        while IFS=$'\t' read -r USER ID; do

            echo -e \
                "${GREEN}✔${RESET} ${WHITE}$USER${RESET}"

            echo -e \
                "  ${GRAY}$ID${RESET}"

        done

        echo

    done

    pause
}

# ==============================================================
# ELIMINAR
# ==============================================================

remove_user() {

    local PROTOCOL="$1"

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || return

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Usuario a eliminar: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    if ! user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "El usuario no existe."

        return
    fi

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    [[ "$CONFIRM" != "ELIMINAR" ]] && {

        warning "Operación cancelada."

        return
    }

    local BACKUP

    BACKUP=$(backup_xray_config)

    local TEMP

    TEMP="$(mktemp --suffix=.json)"

    cp -f "$XRAY_CFG" "$TEMP"

    jq \
        --arg email "$USERNAME" \
        --argjson index "$INDEX" \
        '
        .inbounds[$index].settings.clients |=
        map(select(.email != $email))
        ' \
        "$TEMP" > "${TEMP}.new" || {

        rm -f "$TEMP" "${TEMP}.new"

        error_msg "No se pudo eliminar."

        return
    }

    mv "${TEMP}.new" "$TEMP"

    if ! validate_temp_config "$TEMP"; then

        rm -f "$TEMP"

        error_msg "Xray rechazó la configuración."

        return
    fi

    mv "$TEMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        ok "Usuario eliminado."

    else

        error_msg "Xray no pudo reiniciar."

        if [[ -n "$BACKUP" &&
              -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart "$XRAY_SERVICE"

            warning "Backup restaurado."
        fi
    fi
}

# ==============================================================
# ELIMINAR TODOS LOS PROTOCOLOS
# ==============================================================

remove_all_users() {

    header

    echo -e \
        "${WHITE}${BOLD}          🗑️ ELIMINAR CUENTA COMPLETA${RESET}"

    line

    echo

    read -rp \
        "$(echo -e "${CYAN}👤 Usuario: ${RESET}")" \
        USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    local FOUND=0

    for PROTOCOL in \
        vless \
        vmess \
        trojan \
        grpc; do

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

    echo

    echo -e \
        "${RED}${BOLD}⚠ Se eliminará de TODOS los protocolos.${RESET}"

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    [[ "$CONFIRM" != "ELIMINAR" ]] && {

        warning "Operación cancelada."

        pause
        return
    }

    local BACKUP

    BACKUP=$(backup_xray_config)

    local TEMP

    TEMP="$(mktemp --suffix=.json)"

    cp -f "$XRAY_CFG" "$TEMP"

    jq \
        --arg email "$USERNAME" \
        '
        .inbounds |= map(
            if .settings.clients then
                .settings.clients |=
                map(select(.email != $email))
            else
                .
            end
        )
        ' \
        "$TEMP" > "${TEMP}.new" || {

        rm -f "$TEMP" "${TEMP}.new"

        error_msg "No se pudo modificar."

        pause
        return
    }

    mv "${TEMP}.new" "$TEMP"

    if ! validate_temp_config "$TEMP"; then

        rm -f "$TEMP"

        error_msg "Xray rechazó la configuración."

        pause
        return
    fi

    mv "$TEMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        ok "Cuenta eliminada de todos los protocolos."

    else

        error_msg "Xray no pudo iniciar."

        if [[ -n "$BACKUP" &&
              -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart "$XRAY_SERVICE"

            warning "Backup restaurado."
        fi
    fi

    pause
}

# ==============================================================
# SUBMENÚ CREAR
# ==============================================================

create_account_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}                 👤 CREAR CUENTA${RESET}"

        line

        echo

        echo -e "  ${GREEN}[01]${RESET} VLESS"
        echo -e "  ${GREEN}[02]${RESET} VMess"
        echo -e "  ${GREEN}[03]${RESET} Trojan"
        echo -e "  ${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} ⭐ TODOS"

        echo

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" OP

        case "$OP" in

            1)
                create_and_show "vless"
                ;;

            2)
                create_and_show "vmess"
                ;;

            3)
                create_and_show "trojan"
                ;;

            4)
                create_and_show "grpc"
                ;;

            5)
                create_all_users
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

list_account_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}                 👥 LISTAR CUENTAS${RESET}"

        line

        echo

        echo -e "  ${GREEN}[01]${RESET} VLESS"
        echo -e "  ${GREEN}[02]${RESET} VMess"
        echo -e "  ${GREEN}[03]${RESET} Trojan"
        echo -e "  ${GREEN}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} ⭐ TODOS"

        echo

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" OP

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

remove_account_menu() {

    while true; do

        header

        echo -e \
            "${WHITE}${BOLD}                🗑️ ELIMINAR CUENTA${RESET}"

        line

        echo

        echo -e "  ${RED}[01]${RESET} VLESS"
        echo -e "  ${RED}[02]${RESET} VMess"
        echo -e "  ${RED}[03]${RESET} Trojan"
        echo -e "  ${RED}[04]${RESET} gRPC"

        echo

        echo -e \
            "  ${MAGENTA}[05]${RESET} ⭐ TODOS"

        echo

        echo -e \
            "  ${RED}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}➜ Seleccione: ${RESET}")" OP

        case "$OP" in

            1)
                remove_user "vless"
                pause
                ;;

            2)
                remove_user "vmess"
                pause
                ;;

            3)
                remove_user "trojan"
                pause
                ;;

            4)
                remove_user "grpc"
                pause
                ;;

            5)
                remove_all_users
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
# GENERAR ENLACE
# ==============================================================

show_link() {

    header

    echo -e \
        "${WHITE}${BOLD}                 🔗 GENERAR ENLACE${RESET}"

    line

    echo

    echo "1) VLESS"
    echo "2) VMess"
    echo "3) Trojan"
    echo "4) gRPC"

    echo

    read -rp "➜ Protocolo: " P

    case "$P" in

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

    read -rp "👤 Usuario: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if ! user_exists "$PROTOCOL" "$USERNAME"; then

        error_msg "Usuario no encontrado."

        pause
        return
    fi

    echo

    generate_link \
        "$PROTOCOL" \
        "$USERNAME"

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

show_status() {

    header

    echo -e \
        "${WHITE}${BOLD}                  📊 ESTADO XRAY${RESET}"

    line

    echo

    if xray_active; then

        echo -e \
            "${WHITE}Servicio:${RESET} ${GREEN}🟢 ACTIVO${RESET}"

    else

        echo -e \
            "${WHITE}Servicio:${RESET} ${RED}🔴 DETENIDO${RESET}"
    fi

    echo

    load_host

    echo -e \
        "${WHITE}Host:${RESET} ${GREEN}${HOST:-NO CONFIGURADO}${RESET}"

    echo -e \
        "${WHITE}Tipo:${RESET} ${GREEN}${HOST_TYPE:-N/A}${RESET}"

    echo

    echo -e \
        "${WHITE}VLESS:${RESET} ${GREEN}127.0.0.1:$VLESS_PORT${RESET}"

    echo -e \
        "${WHITE}VMess:${RESET} ${GREEN}127.0.0.1:$VMESS_PORT${RESET}"

    echo -e \
        "${WHITE}Trojan:${RESET} ${GREEN}127.0.0.1:$TROJAN_PORT${RESET}"

    echo -e \
        "${WHITE}gRPC:${RESET} ${GREEN}127.0.0.1:$GRPC_PORT${RESET}"

    echo

    if validate_xray_config; then

        ok "Configuración válida."

    else

        error_msg "Configuración inválida."
    fi

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostic() {

    header

    echo -e \
        "${WHITE}${BOLD}                 🔎 DIAGNÓSTICO${RESET}"

    line

    echo

    load_host

    if [[ -n "$HOST" ]]; then

        ok "Host: $HOST"
        ok "Tipo: $HOST_TYPE"

    else

        error_msg "No se pudo obtener dominio/IP."
    fi

    if xray_installed; then
        ok "Xray instalado"
    else
        error_msg "Xray no instalado"
    fi

    if command -v jq >/dev/null 2>&1; then
        ok "jq disponible"
    else
        error_msg "jq no disponible"
    fi

    if [[ -f "$XRAY_CFG" ]]; then
        ok "config.json encontrado"
    else
        error_msg "config.json no encontrado"
    fi

    echo

    if validate_json; then
        ok "JSON válido"
    else
        error_msg "JSON inválido"
    fi

    if xray_installed &&
       validate_xray_config; then

        ok "Xray acepta la configuración."

    else

        error_msg "Xray rechaza la configuración."
    fi

    if xray_active; then
        ok "Servicio activo"
    else
        error_msg "Servicio detenido"
    fi

    echo

    echo -e "${WHITE}Puertos internos:${RESET}"

    ss -lntp 2>/dev/null |
        grep -E \
            ":(10001|10002|10003|10004)\b" ||
        warning "No se detectaron puertos."

    echo

    echo -e "${WHITE}Últimos logs:${RESET}"

    journalctl \
        -u "$XRAY_SERVICE" \
        -n 20 \
        --no-pager 2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

show_logs() {

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}                    ${MAGENTA}${BOLD}📜 XRAY LOGS${RESET}                      ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    journalctl \
        -u "$XRAY_SERVICE" \
        -n 50 \
        --no-pager 2>/dev/null

    echo

    [[ -f "$XRAY_LOG" ]] && {

        echo -e "${WHITE}access.log:${RESET}"

        tail -n 30 "$XRAY_LOG"
    }

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_xray() {

    header

    echo -e \
        "${WHITE}${BOLD}                 ♻️ REINICIAR XRAY${RESET}"

    line

    echo

    if ! validate_xray_config; then

        pause
        return
    fi

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        ok "Xray reiniciado."

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
# MENÚ
# ==============================================================

xray_menu() {

    while true; do

        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null

        load_host

        local STATUS

        if xray_active; then

            STATUS="${GREEN}🟢 ACTIVO${RESET}"

        elif xray_installed; then

            STATUS="${RED}🔴 DETENIDO${RESET}"

        else

            STATUS="${GRAY}⚪ NO INSTALADO${RESET}"
        fi

        local TOTAL_VLESS=0
        local TOTAL_VMESS=0
        local TOTAL_TROJAN=0
        local TOTAL_GRPC=0

        if [[ -f "$XRAY_CFG" ]]; then

            TOTAL_VLESS=$(jq \
                '(.inbounds[0].settings.clients // []) | length' \
                "$XRAY_CFG" 2>/dev/null)

            TOTAL_VMESS=$(jq \
                '(.inbounds[1].settings.clients // []) | length' \
                "$XRAY_CFG" 2>/dev/null)

            TOTAL_TROJAN=$(jq \
                '(.inbounds[2].settings.clients // []) | length' \
                "$XRAY_CFG" 2>/dev/null)

            TOTAL_GRPC=$(jq \
                '(.inbounds[3].settings.clients // []) | length' \
                "$XRAY_CFG" 2>/dev/null)
        fi

        TOTAL_VLESS="${TOTAL_VLESS:-0}"
        TOTAL_VMESS="${TOTAL_VMESS:-0}"
        TOTAL_TROJAN="${TOTAL_TROJAN:-0}"
        TOTAL_GRPC="${TOTAL_GRPC:-0}"

        clear

        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                 ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                            ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${WHITE}Estado:${RESET} $STATUS"

        echo -e \
            "${WHITE}Host:${RESET}   ${GREEN}${HOST:-NO CONFIGURADO}${RESET}"

        echo -e \
            "${WHITE}Tipo:${RESET}   ${GREEN}${HOST_TYPE:-N/A}${RESET}"

        line

        echo -e \
            "${BLUE}${BOLD}  👥 CUENTAS${RESET}"

        echo

        echo -e \
            "  ${GREEN}[01]${RESET} 👤 Crear cuenta"

        echo -e \
            "  ${GREEN}[02]${RESET} 👥 Listar cuentas"

        echo -e \
            "  ${RED}[03]${RESET} 🗑️ Eliminar cuenta"

        line

        echo -e \
            "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN${RESET}"

        echo

        echo -e \
            "  ${GREEN}[04]${RESET} 🔗 Generar enlace"

        echo -e \
            "  ${GREEN}[05]${RESET} 📊 Estado"

        echo -e \
            "  ${GREEN}[06]${RESET} 🔎 Diagnóstico"

        echo -e \
            "  ${GREEN}[07]${RESET} 📜 Logs"

        echo -e \
            "  ${GREEN}[08]${RESET} ♻️ Reiniciar Xray"

        echo -e \
            "  ${GREEN}[09]${RESET} 🔄 Instalar / Reparar"

        echo

        echo -e \
            "${GRAY}  VLESS:$TOTAL_VLESS  VMess:$TOTAL_VMESS  Trojan:$TOTAL_TROJAN  gRPC:$TOTAL_GRPC${RESET}"

        echo

        echo -e \
            "${RED}${BOLD}[00]${RESET} ↩️ Regresar"

        echo

        read -rp \
            "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)
                create_account_menu
                ;;

            2)
                list_account_menu
                ;;

            3)
                remove_account_menu
                ;;

            4)
                show_link
                ;;

            5)
                show_status
                ;;

            6)
                diagnostic
                ;;

            7)
                show_logs
                ;;

            8)
                restart_xray
                ;;

            9)
                install_xray
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
# AUTO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    install_xray

    exit $?
fi

# ==============================================================
# INICIO
# ==============================================================

xray_menu