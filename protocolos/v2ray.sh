#!/bin/bash

# ==============================================================
#              KEVINTECH MULTI SCRIPT
#                    XRAY MANAGER v5.0
# ==============================================================
#
# Core:
#   Xray
#
# Protocolos:
#   VMess
#   VLESS
#   Trojan
#   gRPC
#
# Puertos internos:
#   VLESS   : 10001
#   VMess   : 10002
#   Trojan  : 10003
#   gRPC    : 10004
#
# Xray:
#   /usr/local/etc/xray/config.json
#
# Config:
#   /etc/kevintech/config.conf
#
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"

XRAY_LOG_DIR="/var/log/xray"
XRAY_LOG="$XRAY_LOG_DIR/access.log"

XRAY_SERVICE="xray"

VERSION="5.0"

# ==============================================================
# PUERTOS
# ==============================================================

VLESS_PORT="10001"
VMESS_PORT="10002"
TROJAN_PORT="10003"
GRPC_PORT="10004"

# ==============================================================
# PATH
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
# FUNCIONES
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
        "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 XRAY MANAGER v$VERSION${RESET}                  ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}             ${GRAY}VMess / VLESS / Trojan / gRPC${RESET}             ${CYAN}║${RESET}"

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
# DOMINIO
# ==============================================================

load_domain() {

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    DOMAIN="${SERVER_DOMAIN:-}"

    if [[ -z "$DOMAIN" &&
          -f /etc/xray/domain ]]; then

        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)

    fi
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

xray_installed() {

    command -v xray >/dev/null 2>&1 &&
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
# BACKUP
# ==============================================================

backup_xray_config() {

    [[ ! -f "$XRAY_CFG" ]] && return 0

    local BACKUP_DIR="$XRAY_DIR/backups"

    mkdir -p "$BACKUP_DIR"

    local FILE

    FILE="$BACKUP_DIR/config-$(date '+%Y%m%d-%H%M%S').json"

    cp -f "$XRAY_CFG" "$FILE"

    chmod 600 "$FILE"

    echo "$FILE"
}

# ==============================================================
# VALIDAR JSON
# ==============================================================

validate_json() {

    [[ ! -f "$XRAY_CFG" ]] && return 1

    command -v jq >/dev/null 2>&1 || return 1

    jq empty "$XRAY_CFG" >/dev/null 2>&1
}

# ==============================================================
# VALIDAR XRAY
# ==============================================================

validate_xray_config() {

    if [[ ! -f "$XRAY_CFG" ]]; then

        error_msg "No existe config.json."

        return 1
    fi

    if ! validate_json; then

        error_msg "JSON inválido."

        return 1
    fi

    if ! xray run \
        -test \
        -config "$XRAY_CFG" \
        >/tmp/xray-test.log 2>&1; then

        error_msg "Xray rechazó la configuración."

        cat /tmp/xray-test.log

        rm -f /tmp/xray-test.log

        return 1
    fi

    rm -f /tmp/xray-test.log

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

        error_msg "No se pudo descargar el instalador."

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
# CONFIGURACIÓN BASE
# ==============================================================

create_base_config() {

    load_domain

    cat > "$XRAY_CFG" <<EOF
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

    chmod 600 "$XRAY_CFG"

    if ! validate_json; then

        error_msg "No se pudo crear JSON válido."

        return 1
    fi

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

    ok "Recuperación automática configurada."
}

# ==============================================================
# INSTALAR
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
    # CONSERVAR CONFIG EXISTENTE
    # ----------------------------------------------------------

    if [[ -f "$XRAY_CFG" ]] &&
       validate_json; then

        ok "Configuración existente detectada."

    else

        create_base_config || {
            pause
            return 1
        }

    fi

    ensure_xray_resilience

    if ! validate_xray_config; then

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

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 20 \
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

    local PROTOCOL="$1"

    case "$PROTOCOL" in

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
        .inbounds[$index].settings.clients
        | any(
            (.email? == $email)
            or
            (.email? // "" == $email)
        )
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

    load_domain

    if [[ -z "$DOMAIN" ]]; then

        error_msg "No existe SERVER_DOMAIN."

        return 1
    fi

    local INDEX

    INDEX=$(inbound_index "$PROTOCOL") || {

        error_msg "Protocolo inválido."

        return 1
    }

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

        error_msg "El usuario ya existe."

        return 1
    fi

    local ID

    ID=$(generate_uuid) || return 1

    local BACKUP

    BACKUP=$(backup_xray_config)

    local TMP

    TMP=$(mktemp)

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

            error_msg "No se pudo modificar config.json."

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
                "email": $email,
                "level": 0
              }
            ]
            ' \
            "$XRAY_CFG" > "$TMP"; then

            rm -f "$TMP"

            error_msg "No se pudo modificar config.json."

            return 1
        fi

    fi

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        error_msg "JSON inválido."

        return 1
    fi

    mv "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    if ! validate_xray_config; then

        error_msg "Xray rechazó la configuración."

        if [[ -n "$BACKUP" &&
              -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            warning "Backup restaurado."

        fi

        return 1
    fi

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

    ok "Cuenta $PROTOCOL creada."

    return 0
}

# ==============================================================
# ELIMINAR USUARIO
# ==============================================================

remove_user() {

    local PROTOCOL="$1"

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return
    fi

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

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USERNAME")

    echo

    echo -e "${WHITE}Protocolo:${RESET} ${GREEN}$PROTOCOL${RESET}"
    echo -e "${WHITE}Usuario:${RESET}   ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}ID:${RESET}        ${YELLOW}$ID${RESET}"

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

    local TMP

    TMP=$(mktemp)

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

        return
    fi

    mv "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    if ! validate_xray_config; then

        error_msg "Configuración inválida."

        [[ -n "$BACKUP" &&
           -f "$BACKUP" ]] &&
            cp -f "$BACKUP" "$XRAY_CFG"

        return
    fi

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        ok "Usuario eliminado."

    else

        error_msg "Xray no pudo iniciar."

        if [[ -n "$BACKUP" &&
              -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart "$XRAY_SERVICE"

            warning "Backup restaurado."

        fi
    fi
}

# ==============================================================
# LISTAR USUARIOS
# ==============================================================

list_users() {

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

    TOTAL=$(jq \
        --argjson index "$INDEX" \
        '.inbounds[$index].settings.clients | length' \
        "$XRAY_CFG" 2>/dev/null)

    TOTAL="${TOTAL:-0}"

    echo

    if [[ "$TOTAL" -eq 0 ]]; then

        echo -e \
            "${YELLOW}No existen usuarios registrados.${RESET}"

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
                .inbounds[$index].settings.clients[] |
                [
                  .email,
                  (.id // .password)
                ] |
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
# GENERAR VMESS
# ==============================================================

generate_vmess_link() {

    local USER="$1"
    local UUID="$2"

    load_domain

    cat <<EOF | base64 -w 0
{
  "v":"2",
  "ps":"$USER",
  "add":"$DOMAIN",
  "port":"443",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$DOMAIN",
  "path":"$VMESS_PATH",
  "tls":"tls",
  "sni":"$DOMAIN"
}
EOF
}

# ==============================================================
# CREAR LINK
# ==============================================================

generate_link() {

    local PROTOCOL="$1"
    local USER="$2"

    load_domain

    local ID

    ID=$(get_user_id "$PROTOCOL" "$USER")

    [[ -z "$ID" ||
       "$ID" == "null" ]] && return 1

    case "$PROTOCOL" in

        vmess)

            echo "vmess://$(generate_vmess_link "$USER" "$ID")"

            ;;

        vless)

            echo \
                "vless://${ID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=${VLESS_PATH}&sni=${DOMAIN}#${USER}"

            ;;

        trojan)

            echo \
                "trojan://${ID}@${DOMAIN}:443?security=tls&type=ws&host=${DOMAIN}&path=${TROJAN_PATH}&sni=${DOMAIN}#${USER}"

            ;;

        grpc)

            echo \
                "vless://${ID}@${DOMAIN}:443?encryption=none&security=tls&type=grpc&serviceName=${GRPC_SERVICE}&sni=${DOMAIN}#${USER}"

            ;;

        *)

            return 1

            ;;

    esac
}

# ==============================================================
# CREAR Y MOSTRAR
# ==============================================================

create_and_show() {

    local PROTOCOL="$1"

    if ! create_user "$PROTOCOL"; then

        pause

        return
    fi

    local LINK

    LINK=$(generate_link "$USER_PROTOCOL" "$USER_NAME")

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}                ${GREEN}${BOLD}🎉 CUENTA CREADA${RESET}                         ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${WHITE}Protocolo:${RESET} ${GREEN}${USER_PROTOCOL^^}${RESET}"

    echo -e \
        "${WHITE}Usuario:${RESET}   ${GREEN}$USER_NAME${RESET}"

    echo -e \
        "${WHITE}ID:${RESET}        ${YELLOW}$USER_ID${RESET}"

    echo -e \
        "${WHITE}Dominio:${RESET}   ${GREEN}$DOMAIN${RESET}"

    echo -e \
        "${WHITE}Puerto:${RESET}    ${GREEN}443${RESET}"

    case "$PROTOCOL" in

        vless)

            echo -e \
                "${WHITE}Path:${RESET}      ${GREEN}$VLESS_PATH${RESET}"

            ;;

        vmess)

            echo -e \
                "${WHITE}Path:${RESET}      ${GREEN}$VMESS_PATH${RESET}"

            ;;

        trojan)

            echo -e \
                "${WHITE}Path:${RESET}      ${GREEN}$TROJAN_PATH${RESET}"

            ;;

        grpc)

            echo -e \
                "${WHITE}Service:${RESET}   ${GREEN}$GRPC_SERVICE${RESET}"

            ;;

    esac

    echo

    line

    echo -e \
        "${YELLOW}${BOLD}🔗 ENLACE${RESET}"

    echo

    echo -e "${GREEN}$LINK${RESET}"

    echo

    pause
}

# ==============================================================
# MOSTRAR LINK
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

        1) PROTOCOL="vless" ;;
        2) PROTOCOL="vmess" ;;
        3) PROTOCOL="trojan" ;;
        4) PROTOCOL="grpc" ;;

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

    local LINK

    LINK=$(generate_link "$PROTOCOL" "$USERNAME")

    echo

    echo -e "${GREEN}$LINK${RESET}"

    pause
}

# ==============================================================
# ONLINE
# ==============================================================

online_users() {

    header

    echo -e \
        "${WHITE}${BOLD}              🌐 USUARIOS ACTIVOS${RESET}"

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

    echo -e \
        "${WHITE}VLESS:${RESET}   ${GREEN}127.0.0.1:$VLESS_PORT${RESET}"

    echo -e \
        "${WHITE}VMess:${RESET}   ${GREEN}127.0.0.1:$VMESS_PORT${RESET}"

    echo -e \
        "${WHITE}Trojan:${RESET}  ${GREEN}127.0.0.1:$TROJAN_PORT${RESET}"

    echo -e \
        "${WHITE}gRPC:${RESET}    ${GREEN}127.0.0.1:$GRPC_PORT${RESET}"

    echo

    load_domain

    echo -e \
        "${WHITE}Dominio:${RESET} ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

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

    if command -v xray >/dev/null 2>&1; then
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

    if [[ -f "$XRAY_LOG" ]]; then

        echo -e "${WHITE}access.log:${RESET}"

        tail -n 30 "$XRAY_LOG"

    fi

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

    warning "Se eliminará Xray y su configuración."

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para continuar: ${RESET}")" \
        CONFIRM

    [[ "$CONFIRM" != "ELIMINAR" ]] && {

        warning "Operación cancelada."

        return
    }

    echo

    local BACKUP

    BACKUP=$(backup_xray_config)

    if [[ -n "$BACKUP" ]]; then

        ok "Backup creado:"
        echo "$BACKUP"

    fi

    systemctl stop "$XRAY_SERVICE" 2>/dev/null || true
    systemctl disable "$XRAY_SERVICE" 2>/dev/null || true

    local INSTALLER="/tmp/xray-install.sh"

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

    set_config "XRAY" "OFF"

    ok "Xray eliminado."

    pause
}

# ==============================================================
# MENÚ
# ==============================================================

xray_menu() {

    while true; do

        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null

        load_domain

        clear

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

            TOTAL_VLESS=$(
                jq '.inbounds[0].settings.clients | length' \
                "$XRAY_CFG" 2>/dev/null
            )

            TOTAL_VMESS=$(
                jq '.inbounds[1].settings.clients | length' \
                "$XRAY_CFG" 2>/dev/null
            )

            TOTAL_TROJAN=$(
                jq '.inbounds[2].settings.clients | length' \
                "$XRAY_CFG" 2>/dev/null
            )

            TOTAL_GRPC=$(
                jq '.inbounds[3].settings.clients | length' \
                "$XRAY_CFG" 2>/dev/null
            )

        fi

        TOTAL_VLESS="${TOTAL_VLESS:-0}"
        TOTAL_VMESS="${TOTAL_VMESS:-0}"
        TOTAL_TROJAN="${TOTAL_TROJAN:-0}"
        TOTAL_GRPC="${TOTAL_GRPC:-0}"

        echo -e \
            "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

        echo -e \
            "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                 ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                            ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${WHITE}Estado:${RESET}  $STATUS"

        echo -e \
            "${WHITE}Dominio:${RESET} ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

        line

        echo -e \
            "${BLUE}${BOLD}  👥 CUENTAS${RESET}"

        echo

        echo -e \
            "  ${GREEN}[01]${RESET} Crear VLESS     ${GRAY}($TOTAL_VLESS)${RESET}"

        echo -e \
            "  ${GREEN}[02]${RESET} Crear VMess     ${GRAY}($TOTAL_VMESS)${RESET}"

        echo -e \
            "  ${GREEN}[03]${RESET} Crear Trojan    ${GRAY}($TOTAL_TROJAN)${RESET}"

        echo -e \
            "  ${GREEN}[04]${RESET} Crear gRPC      ${GRAY}($TOTAL_GRPC)${RESET}"

        echo

        echo -e \
            "  ${GREEN}[05]${RESET} Listar VLESS"

        echo -e \
            "  ${GREEN}[06]${RESET} Listar VMess"

        echo -e \
            "  ${GREEN}[07]${RESET} Listar Trojan"

        echo -e \
            "  ${GREEN}[08]${RESET} Listar gRPC"

        echo

        echo -e \
            "  ${GREEN}[09]${RESET} Eliminar VLESS"

        echo -e \
            "  ${GREEN}[10]${RESET} Eliminar VMess"

        echo -e \
            "  ${GREEN}[11]${RESET} Eliminar Trojan"

        echo -e \
            "  ${GREEN}[12]${RESET} Eliminar gRPC"

        line

        echo -e \
            "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN${RESET}"

        echo

        echo -e \
            "  ${GREEN}[13]${RESET} 🔗 Generar enlace"

        echo -e \
            "  ${GREEN}[14]${RESET} 🌐 Usuarios activos"

        echo -e \
            "  ${GREEN}[15]${RESET} 📊 Estado"

        echo -e \
            "  ${GREEN}[16]${RESET} 🔎 Diagnóstico"

        echo -e \
            "  ${GREEN}[17]${RESET} 📜 Logs"

        echo -e \
            "  ${GREEN}[18]${RESET} ♻️  Reiniciar Xray"

        echo -e \
            "  ${GREEN}[19]${RESET} 🔄 Instalar / Actualizar"

        echo -e \
            "  ${RED}[20]${RESET} 🗑️  Desinstalar"

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

                list_users "vless"

                ;;

            6)

                list_users "vmess"

                ;;

            7)

                list_users "trojan"

                ;;

            8)

                list_users "grpc"

                ;;

            9)

                remove_user "vless"

                pause

                ;;

            10)

                remove_user "vmess"

                pause

                ;;

            11)

                remove_user "trojan"

                pause

                ;;

            12)

                remove_user "grpc"

                pause

                ;;

            13)

                show_link

                ;;

            14)

                online_users

                ;;

            15)

                show_status

                ;;

            16)

                diagnostic

                ;;

            17)

                show_logs

                ;;

            18)

                restart_xray

                ;;

            19)

                install_xray

                ;;

            20)

                remove_xray

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