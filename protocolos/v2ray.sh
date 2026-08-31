#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    XRAY MANAGER v4.1
# ==============================================================
#
# Core       : Xray
# Protocolo  : VMess
# Network    : WebSocket
# Seguridad  : TLS
#
# HAProxy:
#   80 / 443 / 8080
#        ↓
#   127.0.0.1:10002
#
# IMPORTANTE:
#   Este módulo SOLO modifica usuarios VMess.
#   NO reconstruye inbounds.
#   NO elimina VLESS / TROJAN / GRPC / OTROS.
#
# Configuración:
#   /etc/kevintech/config.conf
#
# Xray:
#   /usr/local/etc/xray/config.json
#
# Logs:
#   /var/log/xray/access.log
#
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"

XRAY_LOG_DIR="/var/log/xray"
XRAY_LOG="$XRAY_LOG_DIR/access.log"

XRAY_SERVICE="xray"

VERSION="4.1"

# Backend de VMess para HAProxy
VMESS_PORT="10002"
VMESS_PATH="/vmess"

# Puertos públicos manejados por HAProxy
PUBLIC_PORTS="443 80 8080"

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
# CONFIGURACIÓN
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
# FUNCIONES VISUALES
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
        "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 XRAY MANAGER${RESET}                         ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}                 ${GRAY}KevinTech v$VERSION${RESET}                       ${CYAN}║${RESET}"

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
            "s/^${KEY}=.*/${KEY}=${VALUE}/" \
            "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi
}

# ==============================================================
# DETECTAR XRAY
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

    DOMAIN="$(echo "$DOMAIN" | xargs 2>/dev/null)"
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

        error_msg "config.json contiene JSON inválido."

        return 1
    fi

    if ! xray run \
        -test \
        -config "$XRAY_CFG" \
        >/tmp/xray-test.log 2>&1; then

        error_msg "Xray rechazó la configuración."

        echo
        echo -e \
            "${RED}──── ERROR DE XRAY ───────────────────────────────────────${RESET}"

        cat /tmp/xray-test.log

        echo -e \
            "${RED}──────────────────────────────────────────────────────────${RESET}"

        rm -f /tmp/xray-test.log

        return 1
    fi

    rm -f /tmp/xray-test.log

    return 0
}

# ==============================================================
# VERIFICAR INBOUND VMESS
#
# IMPORTANTE:
# No importa si VMess está en [0], [1], [2], etc.
# Se busca por protocol == vmess.
# ==============================================================

find_vmess_inbound() {

    [[ -f "$XRAY_CFG" ]] || return 1

    jq -e '
        .inbounds |
        any(
            .[];
            .protocol == "vmess"
        )
    ' "$XRAY_CFG" >/dev/null 2>&1
}

# ==============================================================
# INFORMACIÓN DEL INBOUND VMESS
# ==============================================================

get_vmess_inbound_port() {

    jq -r '
        .inbounds[] |
        select(.protocol == "vmess") |
        .port // empty
    ' "$XRAY_CFG" 2>/dev/null |
        head -1
}

get_vmess_inbound_listen() {

    jq -r '
        .inbounds[] |
        select(.protocol == "vmess") |
        .listen // "0.0.0.0"
    ' "$XRAY_CFG" 2>/dev/null |
        head -1
}

get_vmess_inbound_path() {

    jq -r '
        .inbounds[] |
        select(.protocol == "vmess") |
        .streamSettings.wsSettings.path // "/vmess"
    ' "$XRAY_CFG" 2>/dev/null |
        head -1
}

# ==============================================================
# CREAR DIRECTORIOS
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
# CONFIGURACIÓN BASE
#
# SOLO se utiliza si NO existe config.json.
#
# NO se utiliza para reconstruir una configuración existente.
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

        error_msg "No se pudo crear un JSON válido."

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
# REINICIAR XRAY
# ==============================================================

restart_xray_service() {

    clear

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e \
        "${WHITE}${BOLD}                 ♻️ REINICIAR XRAY${RESET}"

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    if ! validate_xray_config; then

        pause

        return 1
    fi

    info "Reiniciando Xray..."

    if ! systemctl restart "$XRAY_SERVICE"; then

        set_config "XRAY" "OFF"

        error_msg "Xray no pudo reiniciar."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 20 \
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
        info "Últimos registros:"

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 20 \
            --no-pager 2>/dev/null
    fi

    pause
}

# ==============================================================
# INSTALAR XRAY COMPLETO
# ==============================================================

install_xray() {

    header

    echo -e \
        "${WHITE}${BOLD}             INSTALACIÓN DE XRAY CORE${RESET}"

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
    # Si existe config.json válido:
    # NO TOCARLO.
    # ----------------------------------------------------------

    if [[ -f "$XRAY_CFG" ]] &&
       validate_json; then

        ok "Configuración existente conservada."

    else

        create_base_config || {
            pause
            return 1
        }

    fi

    ensure_xray_resilience

    if ! validate_xray_config; then

        error_msg "La configuración de Xray no es válida."

        pause

        return 1
    fi

    info "Iniciando Xray..."

    systemctl restart "$XRAY_SERVICE"

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        echo
        ok "Xray instalado y activo."

    else

        set_config "XRAY" "OFF"

        error_msg "Xray fue instalado pero no pudo iniciar."

        echo

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
# EXISTE USUARIO VMESS
#
# SOLO busca dentro de inbounds VMess.
# ==============================================================

vmess_user_exists() {

    [[ -f "$XRAY_CFG" ]] || return 1

    jq -e \
        --arg email "$1" \
        '
        .inbounds |
        map(
            select(.protocol == "vmess")
            | .settings.clients // []
        )
        | flatten
        | any(.email == $email)
        ' \
        "$XRAY_CFG" \
        >/dev/null 2>&1
}

# ==============================================================
# OBTENER UUID
# ==============================================================

get_vmess_uuid() {

    jq -r \
        --arg email "$1" \
        '
        .inbounds[] |
        select(.protocol == "vmess") |
        .settings.clients[]? |
        select(.email == $email) |
        .id
        ' \
        "$XRAY_CFG" \
        2>/dev/null |
        head -1
}

# ==============================================================
# CREAR USUARIO VMESS
#
# SOLO agrega el usuario al inbound VMess.
# NO reconstruye la configuración.
# ==============================================================

create_vmess_user() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return 1
    fi

    if ! validate_xray_config; then

        error_msg "La configuración actual de Xray no es válida."

        return 1
    fi

    if ! find_vmess_inbound; then

        error_msg "No existe un inbound VMess en config.json."

        echo
        info "No se modificó ningún protocolo."

        return 1
    fi

    load_domain

    if [[ -z "$DOMAIN" ]]; then

        error_msg "No existe SERVER_DOMAIN en config.conf."

        return 1
    fi

    echo

    read -rp "👤 Nombre del usuario: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    if [[ -z "$USERNAME" ]]; then

        error_msg "El usuario no puede estar vacío."

        return 1
    fi

    if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre de usuario inválido."

        return 1
    fi

    if vmess_user_exists "$USERNAME"; then

        error_msg "El usuario '$USERNAME' ya existe."

        return 1
    fi

    local UUID

    UUID=$(generate_uuid) || return 1

    # ----------------------------------------------------------
    # Backup temporal de seguridad
    # ----------------------------------------------------------

    local OLD_CONFIG

    OLD_CONFIG=$(mktemp)

    if ! cp -f "$XRAY_CFG" "$OLD_CONFIG"; then

        rm -f "$OLD_CONFIG"

        error_msg "No se pudo crear copia temporal."

        return 1
    fi

    # ----------------------------------------------------------
    # Archivo temporal
    # ----------------------------------------------------------

    local TMP

    TMP=$(mktemp)

    # ----------------------------------------------------------
    # MODIFICACIÓN QUIRÚRGICA:
    #
    # Solo:
    # .inbounds[].protocol == "vmess"
    #
    # Todos los demás objetos quedan exactamente igual.
    # ----------------------------------------------------------

    if ! jq \
        --arg uuid "$UUID" \
        --arg email "$USERNAME" \
        '
        .inbounds |= map(
            if .protocol == "vmess"
            then
                .settings.clients =
                (
                    (.settings.clients // []) +
                    [{
                        "id": $uuid,
                        "level": 0,
                        "email": $email
                    }]
                )
            else
                .
            end
        )
        ' \
        "$XRAY_CFG" > "$TMP"; then

        rm -f "$TMP" "$OLD_CONFIG"

        error_msg "No se pudo modificar config.json."

        return 1
    fi

    # ----------------------------------------------------------
    # Validar JSON nuevo
    # ----------------------------------------------------------

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP" "$OLD_CONFIG"

        error_msg "La nueva configuración contiene JSON inválido."

        return 1
    fi

    # ----------------------------------------------------------
    # Instalar temporalmente el nuevo JSON
    # ----------------------------------------------------------

    if ! cp -f "$TMP" "$XRAY_CFG"; then

        rm -f "$TMP" "$OLD_CONFIG"

        error_msg "No se pudo guardar la configuración."

        return 1
    fi

    chmod 600 "$XRAY_CFG"

    rm -f "$TMP"

    echo

    info "Usuario VMess agregado."

    info "Validando configuración completa..."

    # ----------------------------------------------------------
    # Validar configuración COMPLETA existente.
    # ----------------------------------------------------------

    if ! validate_xray_config; then

        error_msg "Xray rechazó la configuración."

        cp -f "$OLD_CONFIG" "$XRAY_CFG"
        chmod 600 "$XRAY_CFG"

        warning "Configuración anterior restaurada."

        rm -f "$OLD_CONFIG"

        return 1
    fi

    # Ya no necesitamos la copia temporal.

    rm -f "$OLD_CONFIG"

    # ----------------------------------------------------------
    # Reiniciar
    # ----------------------------------------------------------

    info "Reiniciando Xray..."

    if ! systemctl restart "$XRAY_SERVICE"; then

        error_msg "Xray no pudo reiniciar."

        return 1
    fi

    sleep 2

    if ! xray_active; then

        error_msg "Xray no quedó activo."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 20 \
            --no-pager 2>/dev/null

        return 1
    fi

    VMESS_USER="$USERNAME"
    VMESS_UUID="$UUID"

    set_config "XRAY" "ON"

    echo
    ok "Usuario VMess creado correctamente."

    return 0
}

# ==============================================================
# ELIMINAR USUARIO VMESS
#
# SOLO elimina del inbound VMess.
# ==============================================================

remove_vmess_user() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return
    fi

    if ! find_vmess_inbound; then

        error_msg "No existe un inbound VMess."

        return
    fi

    echo

    read -rp "👤 Usuario a eliminar: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    if ! vmess_user_exists "$USERNAME"; then

        error_msg "El usuario '$USERNAME' no existe en VMess."

        return
    fi

    local UUID

    UUID=$(get_vmess_uuid "$USERNAME")

    echo
    echo -e "${YELLOW}Usuario:${RESET} $USERNAME"
    echo -e "${YELLOW}UUID:${RESET}    $UUID"
    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        return
    fi

    # ----------------------------------------------------------
    # Backup temporal
    # ----------------------------------------------------------

    local OLD_CONFIG

    OLD_CONFIG=$(mktemp)

    if ! cp -f "$XRAY_CFG" "$OLD_CONFIG"; then

        rm -f "$OLD_CONFIG"

        error_msg "No se pudo crear copia temporal."

        return
    fi

    local TMP

    TMP=$(mktemp)

    echo

    info "Eliminando solamente '$USERNAME' de VMess..."

    # ----------------------------------------------------------
    # SOLO modifica .protocol == vmess
    #
    # VLESS/TROJAN/GRPC/OTROS:
    #       else .
    #
    # quedan intactos.
    # ----------------------------------------------------------

    if ! jq \
        --arg email "$USERNAME" \
        '
        .inbounds |= map(
            if .protocol == "vmess"
            then
                .settings.clients =
                (
                    (.settings.clients // [])
                    | map(select(.email != $email))
                )
            else
                .
            end
        )
        ' \
        "$XRAY_CFG" > "$TMP"; then

        rm -f "$TMP" "$OLD_CONFIG"

        error_msg "No se pudo modificar config.json."

        return
    fi

    # ----------------------------------------------------------
    # Validar JSON
    # ----------------------------------------------------------

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP" "$OLD_CONFIG"

        error_msg "La configuración resultante no es válida."

        return
    fi

    cp -f "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    rm -f "$TMP"

    echo

    info "Validando configuración completa..."

    if ! validate_xray_config; then

        error_msg "Xray rechazó la configuración."

        cp -f "$OLD_CONFIG" "$XRAY_CFG"

        chmod 600 "$XRAY_CFG"

        warning "Configuración anterior restaurada."

        rm -f "$OLD_CONFIG"

        return
    fi

    rm -f "$OLD_CONFIG"

    # ----------------------------------------------------------
    # Reiniciar
    # ----------------------------------------------------------

    info "Reiniciando Xray..."

    if ! systemctl restart "$XRAY_SERVICE"; then

        error_msg "Xray no pudo reiniciar."

        return
    fi

    sleep 2

    if xray_active; then

        set_config "XRAY" "ON"

        echo
        ok "Usuario '$USERNAME' eliminado correctamente."

    else

        error_msg "Xray no pudo iniciar después de eliminar el usuario."

        echo

        journalctl \
            -u "$XRAY_SERVICE" \
            -n 20 \
            --no-pager 2>/dev/null
    fi
}

# ==============================================================
# LISTAR USUARIOS VMESS
# ==============================================================

list_vmess_users() {

    header

    echo -e \
        "${WHITE}${BOLD}                  👥 USUARIOS VMESS${RESET}"

    line

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        pause

        return
    fi

    if ! find_vmess_inbound; then

        error_msg "No existe inbound VMess."

        pause

        return
    fi

    local TOTAL

    TOTAL=$(
        jq '
            [
                .inbounds[] |
                select(.protocol == "vmess") |
                (.settings.clients // [])
            ]
            | flatten
            | length
        ' "$XRAY_CFG" 2>/dev/null
    )

    TOTAL="${TOTAL:-0}"

    echo

    printf \
        "${CYAN}%-5s %-24s %-38s${RESET}\n" \
        "#" "USUARIO" "UUID"

    echo -e \
        "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

    if [[ "$TOTAL" -eq 0 ]]; then

        echo -e \
            "${YELLOW}No existen usuarios VMess registrados.${RESET}"

    else

        local I=0

        while IFS=$'\t' read -r USER UUID; do

            I=$((I + 1))

            printf \
                "${GREEN}%-5s${RESET} ${WHITE}%-24s${RESET} ${YELLOW}%-38s${RESET}\n" \
                "$I" \
                "$USER" \
                "$UUID"

        done < <(

            jq -r '
                .inbounds[] |
                select(.protocol == "vmess") |
                .settings.clients[]? |
                [.email, .id] |
                @tsv
            ' "$XRAY_CFG"
        )
    fi

    echo

    echo -e \
        "${CYAN}Usuarios registrados: ${GREEN}${TOTAL}${RESET}"

    pause
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
# GENERAR LINK VMESS
#
# HAProxy:
# 80 / 443 / 8080 -> backend 10002
#
# El enlace principal usa 443.
# ==============================================================

generate_vmess_link() {

    local USER="$1"
    local UUID="$2"

    load_domain

    [[ -z "$DOMAIN" ]] && return 1

    cat <<EOF | base64_encode
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
  "sni":"$DOMAIN",
  "alpn":""
}
EOF
}

# ==============================================================
# MOSTRAR CUENTA
# ==============================================================

show_vmess_account() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return
    fi

    if ! find_vmess_inbound; then

        error_msg "No existe inbound VMess."

        return
    fi

    load_domain

    echo

    read -rp "👤 Usuario: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    local UUID

    UUID=$(get_vmess_uuid "$USERNAME")

    if [[ -z "$UUID" ||
          "$UUID" == "null" ]]; then

        error_msg "Usuario no encontrado."

        return
    fi

    if [[ -z "$DOMAIN" ]]; then

        error_msg "No existe dominio configurado."

        return
    fi

    local LINK

    LINK="vmess://$(generate_vmess_link "$USERNAME" "$UUID")"

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}             ${GREEN}${BOLD}🎉 CUENTA VMESS${RESET}                          ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf \
        "${CYAN}║${RESET} 👤 Usuario     : ${WHITE}%-40s${RESET}${CYAN}║${RESET}\n" \
        "$USERNAME"

    printf \
        "${CYAN}║${RESET} 🆔 UUID        : ${YELLOW}%-40s${RESET}${CYAN}║${RESET}\n" \
        "$UUID"

    printf \
        "${CYAN}║${RESET} 🌐 Dominio     : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "$DOMAIN"

    printf \
        "${CYAN}║${RESET} 🔒 Puerto TLS  : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "443"

    printf \
        "${CYAN}║${RESET} 🌐 HTTP        : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "80"

    printf \
        "${CYAN}║${RESET} 🌐 HTTP ALT    : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "8080"

    printf \
        "${CYAN}║${RESET} 🔧 Backend     : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "127.0.0.1:$VMESS_PORT"

    printf \
        "${CYAN}║${RESET} 📡 Network     : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "WebSocket"

    printf \
        "${CYAN}║${RESET} 📂 Path        : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "$VMESS_PATH"

    printf \
        "${CYAN}║${RESET} 🛡️ TLS         : ${GREEN}%-40s${RESET}${CYAN}║${RESET}\n" \
        "Activado"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${CYAN}║${RESET} ${YELLOW}${BOLD}🔗 ENLACE VMESS${RESET}                                      ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${GREEN}$LINK${RESET}"
    echo

    ok "Cuenta lista para utilizar."

    pause
}

# ==============================================================
# CREAR CUENTA COMPLETA
#
# AQUÍ SE MUESTRAN LOS DATOS Y SE ESPERA ENTER.
# ==============================================================

create_vmess_account() {

    if ! create_vmess_user; then

        pause

        return
    fi

    show_vmess_user \
        "$VMESS_USER" \
        "$VMESS_UUID"
}

# ==============================================================
# MOSTRAR CUENTA RECIÉN CREADA
# ==============================================================

show_vmess_user() {

    local USER="$1"
    local UUID="$2"

    load_domain

    local LINK

    LINK="vmess://$(generate_vmess_link "$USER" "$UUID")"

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}             ${GREEN}${BOLD}🎉 CUENTA CREADA${RESET}                          ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE} 👤 Usuario     : ${GREEN}$USER${RESET}"
    echo -e "${WHITE} 🆔 UUID        : ${YELLOW}$UUID${RESET}"
    echo -e "${WHITE} 🌐 Dominio     : ${GREEN}$DOMAIN${RESET}"
    echo -e "${WHITE} 🔒 Puerto TLS  : ${GREEN}443${RESET}"
    echo -e "${WHITE} 🌐 Puerto HTTP : ${GREEN}80${RESET}"
    echo -e "${WHITE} 🌐 Puerto ALT  : ${GREEN}8080${RESET}"
    echo -e "${WHITE} 🔧 Backend     : ${GREEN}127.0.0.1:$VMESS_PORT${RESET}"
    echo -e "${WHITE} 📡 Network     : ${GREEN}WebSocket${RESET}"
    echo -e "${WHITE} 📂 Path        : ${GREEN}$VMESS_PATH${RESET}"
    echo -e "${WHITE} 🛡️ TLS         : ${GREEN}Activado${RESET}"
    echo -e "${WHITE} 🔗 HAProxy     : ${GREEN}80 / 443 / 8080${RESET}"

    line

    echo -e \
        "${YELLOW}${BOLD}🔗 VMESS LINK${RESET}"

    echo

    echo -e "${GREEN}$LINK${RESET}"

    echo

    ok "Cuenta lista para utilizar."

    pause
}

# ==============================================================
# EXPORTAR LINK
# ==============================================================

export_vmess_link() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return
    fi

    echo

    read -rp "👤 Usuario: " USERNAME

    USERNAME="$(echo "$USERNAME" | xargs)"

    [[ -z "$USERNAME" ]] && return

    local UUID

    UUID=$(get_vmess_uuid "$USERNAME")

    if [[ -z "$UUID" ||
          "$UUID" == "null" ]]; then

        error_msg "Usuario no encontrado."

        return
    fi

    local LINK

    LINK="vmess://$(generate_vmess_link "$USERNAME" "$UUID")"

    local FILE="/tmp/vmess-${USERNAME}.txt"

    printf '%s\n' "$LINK" > "$FILE"

    chmod 600 "$FILE"

    ok "Link exportado."

    echo
    echo -e "${WHITE}Archivo:${RESET} ${GREEN}$FILE${RESET}"

    pause
}

# ==============================================================
# INFORMACIÓN VMESS
# ==============================================================

vmess_server_info() {

    load_domain

    local INTERNAL_PORT

    INTERNAL_PORT=$(get_vmess_inbound_port)

    INTERNAL_PORT="${INTERNAL_PORT:-$VMESS_PORT}"

    local LISTEN

    LISTEN=$(get_vmess_inbound_listen)

    LISTEN="${LISTEN:-127.0.0.1}"

    local PATH

    PATH=$(get_vmess_inbound_path)

    PATH="${PATH:-$VMESS_PATH}"

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}               ${MAGENTA}${BOLD}ℹ️ INFORMACIÓN VMESS${RESET}                      ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}Dominio:${RESET}          ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

    echo -e "${WHITE}HAProxy:${RESET}          ${GREEN}ACTIVO / EXTERNO${RESET}"

    echo -e "${WHITE}Puerto público TLS:${RESET} ${GREEN}443${RESET}"

    echo -e "${WHITE}Puerto público HTTP:${RESET} ${GREEN}80${RESET}"

    echo -e "${WHITE}Puerto público ALT:${RESET} ${GREEN}8080${RESET}"

    echo -e "${WHITE}Listen Xray:${RESET}      ${GREEN}$LISTEN${RESET}"

    echo -e "${WHITE}Puerto interno:${RESET}   ${GREEN}$INTERNAL_PORT${RESET}"

    echo -e "${WHITE}TLS:${RESET}              ${GREEN}Sí${RESET}"

    echo -e "${WHITE}Network:${RESET}          ${GREEN}WebSocket${RESET}"

    echo -e "${WHITE}Path:${RESET}             ${GREEN}$PATH${RESET}"

    echo -e "${WHITE}Host/SNI:${RESET}         ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

    echo

    echo -e \
        "${GRAY}HAProxy puede recibir 80/443/8080 y${RESET}"

    echo -e \
        "${GRAY}reenviar al backend Xray $LISTEN:$INTERNAL_PORT.${RESET}"

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

    local SINCE

    SINCE=$(date -d "60 seconds ago" \
        '+%Y/%m/%d %H:%M:%S')

    mapfile -t USERS < <(

        awk -v LIM="$SINCE" '
        /email:/ {

            DATA=$1 " " $2

            if (DATA >= LIM) {

                split($0, A, "email: ")

                if (A[2] != "")
                    print A[2]
            }
        }
        ' "$XRAY_LOG" |
        sort -u
    )

    local TOTAL="${#USERS[@]}"

    if [[ "$TOTAL" -eq 0 ]]; then

        echo -e \
            "${YELLOW}No se detectaron usuarios activos en los últimos 60 segundos.${RESET}"

    else

        local I=0

        for USER in "${USERS[@]}"; do

            I=$((I + 1))

            echo -e \
                "${GREEN}[$I]${RESET} ${WHITE}$USER${RESET}"
        done
    fi

    echo

    echo -e \
        "${WHITE}Usuarios detectados:${RESET} ${GREEN}$TOTAL${RESET}"

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

xray_status() {

    header

    echo -e \
        "${WHITE}${BOLD}                 📊 ESTADO DE XRAY${RESET}"

    line

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

    echo -e "${WHITE}Estado:${RESET}        $STATUS"

    echo -e \
        "${WHITE}Versión:${RESET}       ${GREEN}$VERSION_INFO${RESET}"

    echo -e \
        "${WHITE}Servicio:${RESET}      ${GREEN}$XRAY_SERVICE${RESET}"

    echo -e \
        "${WHITE}Configuración:${RESET} ${GREEN}$XRAY_CFG${RESET}"

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        if validate_xray_config; then

            ok "Configuración Xray válida."

        else

            error_msg "Configuración Xray inválida."

        fi

    else

        error_msg "config.json no existe."

    fi

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        local INTERNAL_PORT

        INTERNAL_PORT=$(get_vmess_inbound_port)

        INTERNAL_PORT="${INTERNAL_PORT:-$VMESS_PORT}"

        if ss -H -lnt 2>/dev/null |
            awk -v P=":$INTERNAL_PORT" '$4 ~ P"$"' |
            grep -q .; then

            ok "Puerto interno $INTERNAL_PORT escuchando."

        else

            warning "Puerto interno $INTERNAL_PORT no está escuchando."

        fi
    fi

    echo

    load_domain

    echo -e \
        "${WHITE}Dominio:${RESET} ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

    echo -e \
        "${WHITE}HAProxy:${RESET} ${GREEN}80 / 443 / 8080${RESET}"

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

    if [[ -f "$XRAY_LOG" ]]; then
        ok "access.log encontrado"
    else
        warning "access.log inexistente"
    fi

    if xray_active; then
        ok "Servicio Xray activo"
    else
        error_msg "Servicio Xray detenido"
    fi

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        if validate_json; then
            ok "JSON válido"
        else
            error_msg "JSON inválido"
        fi

        if find_vmess_inbound; then
            ok "Inbound VMess encontrado"
        else
            error_msg "Inbound VMess no encontrado"
        fi

        if validate_xray_config; then
            ok "Xray acepta la configuración"
        else
            error_msg "Xray rechaza la configuración"
        fi

    fi

    echo

    echo -e "${WHITE}Últimos registros:${RESET}"

    journalctl \
        -u "$XRAY_SERVICE" \
        -n 15 \
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

    echo -e "${WHITE}Últimos eventos del servicio:${RESET}"

    journalctl \
        -u "$XRAY_SERVICE" \
        -n 30 \
        --no-pager 2>/dev/null

    echo

    if [[ -f "$XRAY_LOG" ]]; then

        echo -e "${WHITE}Últimas líneas de access.log:${RESET}"

        tail -n 20 "$XRAY_LOG"

    fi

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_xray() {

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}              ${RED}${BOLD}🗑️ DESINSTALAR XRAY${RESET}                     ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    warning "Se eliminará Xray Core."

    warning "La configuración y los usuarios también serán eliminados."

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para continuar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        sleep 1

        return
    fi

    echo

    if [[ -f "$XRAY_CFG" ]]; then

        local BACKUP

        BACKUP=$(backup_xray_config)

        if [[ -n "$BACKUP" ]]; then

            ok "Backup creado:"

            echo -e \
                "  ${GRAY}$BACKUP${RESET}"
        fi
    fi

    info "Deteniendo Xray..."

    systemctl stop "$XRAY_SERVICE" 2>/dev/null
    systemctl disable "$XRAY_SERVICE" 2>/dev/null

    info "Eliminando instalación..."

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

    info "Limpiando configuración..."

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
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e \
        "${MAGENTA}${BOLD}                🚀 INSTALACIÓN AUTOMÁTICA${RESET}"

    echo -e \
        "${WHITE}                         XRAY${RESET}"

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    if install_xray; then

        echo

        ok "Xray instalado correctamente."

        exit 0

    else

        echo

        error_msg "Error instalando Xray."

        exit 1
    fi
fi

# ==============================================================
# MENÚ PRINCIPAL
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

        local VERSION_INFO

        VERSION_INFO=$(
            xray version 2>/dev/null |
            head -1
        )

        VERSION_INFO="${VERSION_INFO:-NO INSTALADO}"

        local TOTAL_USERS=0

        if [[ -f "$XRAY_CFG" ]]; then

            TOTAL_USERS=$(
                jq '
                    [
                        .inbounds[] |
                        select(.protocol == "vmess") |
                        (.settings.clients // [])
                    ]
                    | flatten
                    | length
                ' \
                "$XRAY_CFG" 2>/dev/null
            )
        fi

        TOTAL_USERS="${TOTAL_USERS:-0}"

        local ONLINE_USERS=0

        if [[ -f "$XRAY_LOG" ]]; then

            local SINCE

            SINCE=$(date \
                -d "60 seconds ago" \
                '+%Y/%m/%d %H:%M:%S')

            ONLINE_USERS=$(
                awk -v LIM="$SINCE" '
                /email:/ {

                    DATA=$1 " " $2

                    if (DATA >= LIM) {

                        split($0,A,"email: ")

                        if (A[2] != "")
                            print A[2]
                    }
                }
                ' "$XRAY_LOG" |
                sort -u |
                wc -l
            )
        fi

        echo -e \
            "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

        echo -e \
            "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MANAGER${RESET}                  ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${WHITE}Estado:${RESET}         $STATUS"

        echo -e \
            "${WHITE}Dominio:${RESET}        ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

        echo -e \
            "${WHITE}Protocolo:${RESET}      ${GREEN}VMess + WebSocket + TLS${RESET}"

        echo -e \
            "${WHITE}HAProxy:${RESET}        ${GREEN}80 / 443 / 8080${RESET}"

        echo -e \
            "${WHITE}Backend Xray:${RESET}   ${GREEN}127.0.0.1:$VMESS_PORT${RESET}"

        echo -e \
            "${WHITE}Path:${RESET}           ${GREEN}$VMESS_PATH${RESET}"

        echo -e \
            "${WHITE}Versión:${RESET}        ${GREEN}$VERSION_INFO${RESET}"

        echo -e \
            "${WHITE}Usuarios:${RESET}       ${GREEN}$TOTAL_USERS${RESET}"

        echo -e \
            "${WHITE}Online:${RESET}         ${GREEN}$ONLINE_USERS${RESET}"

        line

        if xray_installed; then

            echo -e \
                "${BLUE}${BOLD}  👥 GESTIÓN DE USUARIOS${RESET}"

            echo

            echo -e \
                "  ${GREEN}[01]${RESET} 👤 Crear Cuenta VMess"

            echo -e \
                "  ${GREEN}[02]${RESET} 🗑️  Eliminar Usuario"

            echo -e \
                "  ${GREEN}[03]${RESET} 📋 Listar Usuarios"

            echo -e \
                "  ${GREEN}[04]${RESET} 📄 Mostrar Cuenta"

            echo -e \
                "  ${GREEN}[05]${RESET} 📤 Exportar Link"

            echo

            echo -e \
                "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN XRAY${RESET}"

            echo

            echo -e \
                "  ${GREEN}[06]${RESET} 🌐 Usuarios Online"

            echo -e \
                "  ${GREEN}[07]${RESET} ℹ️  Información VMess"

            echo -e \
                "  ${GREEN}[08]${RESET} ♻️  Reiniciar Xray"

            echo -e \
                "  ${GREEN}[09]${RESET} 📊 Estado del Servicio"

            echo -e \
                "  ${GREEN}[10]${RESET} 🔎 Diagnóstico"

            echo -e \
                "  ${GREEN}[11]${RESET} 📜 Ver Logs"

            echo -e \
                "  ${GREEN}[12]${RESET} 🔄 Reinstalar / Actualizar"

            echo -e \
                "  ${RED}[13]${RESET} 🗑️  Desinstalar Xray"

        else

            echo -e \
                "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"

            echo

            echo -e \
                "  ${GREEN}[01]${RESET} 🚀 Instalar Xray Core"
        fi

        echo

        echo -e \
            "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"

        echo -e \
            "  ${RED}${BOLD}[00]${RESET} ↩️  ${WHITE}Regresar${RESET}"

        echo

        echo -e \
            "${GRAY}  KevinTech Multi Script • Privanox VPN • v$VERSION${RESET}"

        echo

        read -rp \
            "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)

                if xray_installed; then
                    create_vmess_account
                else
                    install_xray
                fi
                ;;

            2)

                if xray_installed; then

                    remove_vmess_user

                    pause

                else

                    error_msg "Xray no está instalado."

                    sleep 1
                fi
                ;;

            3)

                if xray_installed; then
                    list_vmess_users
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi
                ;;

            4)

                if xray_installed; then
                    show_vmess_account
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi
                ;;

            5)

                if xray_installed; then
                    export_vmess_link
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
                    vmess_server_info
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi
                ;;

            8)

                if xray_installed; then
                    restart_xray_service
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi
                ;;

            9)

                if xray_installed; then
                    xray_status
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi
                ;;

            10)

                xray_diagnostic
                ;;

            11)

                if xray_installed; then
                    show_xray_logs
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi
                ;;

            12)

                install_xray
                ;;

            13)

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

                echo

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