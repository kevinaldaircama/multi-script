#!/usr/bin/env bash

# ==============================================================
#                 🛡️ KEVINTECH MULTI SCRIPT
#                    XRAY MANAGER
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/v2ray.sh
# Motor   : Xray Core
# Soporta : VMess / VLESS / Trojan
# Versión : 4.0 KevinTech
#
# IMPORTANTE:
# - Sin librerías externas de MoviVIP
# - Sin anim.sh
# - Sin nav.sh
# - Sin delivery.sh
# - Sin duracion.sh
# - Sin pkg.sh
# - Todo lo necesario está dentro de este archivo
#
# ==============================================================

set -o pipefail

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"
XRAY_LOG="/var/log/xray/access.log"

XRAY_PORTS_FILE="$BASE/sistema/xray_ports.conf"
XRAY_LIMITS_FILE="$BASE/sistema/xray_limites.conf"
XRAY_SUSPEND_FILE="$BASE/sistema/xray_suspendidos.conf"
XRAY_CORTES_LOG="$BASE/sistema/xray_cortes.log"

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

VERSION="4.0"
PANEL_NAME="KEVINTECH XRAY MANAGER"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

GOLD="$YELLOW"

# ==============================================================
# SEGURIDAD
# ==============================================================

if [[ $EUID -ne 0 ]]; then
    echo
    echo -e "${RED}${BOLD}✘ Debes ejecutar este script como ROOT.${RESET}"
    echo
    exit 1
fi

mkdir -p "$BASE/sistema"
mkdir -p "$XRAY_DIR"
mkdir -p /var/log/xray

# ==============================================================
# CONFIG
# ==============================================================

if [[ -f "$CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null
fi

XRAY_PORT="${XRAY_PORT:-443}"

# ==============================================================
# UTILIDADES INTERNAS
# ==============================================================

trx() {
    printf '%s' "$1"
}

pause_screen() {
    echo
    read -r -n1 -p "$(echo -e "${GRAY}Presiona cualquier tecla para continuar...${RESET}")"
    echo
}

anim_init() {
    return 0
}

anim_step() {
    echo
    echo -e "${CYAN}➜ $1${RESET}"
}

anim_run() {

    local LABEL="$1"
    shift

    echo -ne "${CYAN}➜ ${LABEL}...${RESET} "

    if "$@" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${RESET}"
        return 0
    fi

    echo -e "${RED}ERROR${RESET}"
    return 1
}

anim_done() {
    echo -e "${GREEN}✔ $1${RESET}"
}

anim_fail() {
    echo -e "${RED}✘ $1${RESET}"
}

svc_up() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

svc_restart_anim() {

    local SERVICE="$1"
    local LABEL="${2:-Reiniciando servicio}"

    echo -ne "${CYAN}➜ ${LABEL}...${RESET} "

    systemctl restart "$SERVICE" >/dev/null 2>&1

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "${GREEN}OK${RESET}"
        return 0
    fi

    echo -e "${RED}ERROR${RESET}"
    return 1
}

mv_header() {

    local TITLE="${1:-$PANEL_NAME}"
    local SUBTITLE="${2:-}"
    local VER="${3:-v$VERSION}"

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${CYAN}║${RESET} ${MAGENTA}${BOLD}%-58s${RESET} ${CYAN}║${RESET}\n" "$TITLE"
    [[ -n "$SUBTITLE" ]] &&
        printf "${CYAN}║${RESET} ${GRAY}%-58s${RESET} ${CYAN}║${RESET}\n" "$SUBTITLE"
    printf "${CYAN}║${RESET} ${GRAY}%-58s${RESET} ${CYAN}║${RESET}\n" "$VER"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

mv_deliv_header() {
    mv_header "$1" "$2" "KevinTech Xray v$VERSION"
}

mv_deliv_sec() {

    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${RESET}"
    printf "${CYAN}│${RESET} ${WHITE}${BOLD}%-60s${RESET}${CYAN}│${RESET}\n" "$1"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${RESET}"
}

mv_dcard_top() {
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${RESET}"
}

mv_dcard_row() {

    local ICON="$1"
    local LABEL="$2"
    local VALUE="$3"

    printf "${CYAN}│${RESET} %s ${WHITE}%-15s${RESET}: ${GREEN}%-38s${RESET}${CYAN}│${RESET}\n" \
        "$ICON" "$LABEL" "$VALUE"
}

mv_dcard_bot() {
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${RESET}"
}

mv_deliv_pie() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GRAY}             KEVINTECH MULTI SCRIPT • XRAY${RESET}"
}

mv_tick() {
    printf '%s' "$1"
}

# ==============================================================
# MENÚ NUMÉRICO INTERNO
# ==============================================================

nav_pick() {

    local TITLE="$1"
    shift

    local ITEMS=("$@")
    local COUNT="${#ITEMS[@]}"
    local OP

    echo
    echo -e "${CYAN}${BOLD}${TITLE}${RESET}"
    echo

    local I=1

    for ITEM in "${ITEMS[@]}"; do

        if [[ "$I" -eq "$COUNT" ]]; then
            printf "  ${RED}[00]${RESET} %s\n" "$ITEM"
        else
            printf "  ${GREEN}[%02d]${RESET} %s\n" "$I" "$ITEM"
        fi

        I=$((I + 1))
    done

    echo

    read -rp "$(echo -e "${CYAN}➜ Seleccione una opción: ${RESET}")" OP

    if [[ -z "$OP" ]]; then
        echo "$COUNT"
        return
    fi

    if [[ "$OP" == "00" || "$OP" == "0" ]]; then
        echo "$COUNT"
        return
    fi

    if [[ "$OP" =~ ^[0-9]+$ ]] && (( OP >= 1 && OP < COUNT )); then
        echo "$OP"
        return
    fi

    echo "-1"
}

# ==============================================================
# PAQUETES
# ==============================================================

pkg_update() {

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
}

pkg_install() {

    export DEBIAN_FRONTEND=noninteractive

    apt-get install -y "$@"
}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_xray_dependencies() {

    anim_step "Actualizando repositorios"

    if ! pkg_update >/dev/null 2>&1; then
        anim_fail "No se pudo actualizar APT"
        return 1
    fi

    anim_step "Instalando dependencias"

    if ! pkg_install \
        curl \
        wget \
        unzip \
        jq \
        socat \
        cron \
        bash-completion \
        ca-certificates \
        iptables \
        iproute2 \
        openssl \
        >/dev/null 2>&1; then

        anim_fail "No se pudieron instalar las dependencias"
        return 1
    fi

    anim_done "Dependencias instaladas"
}

# ==============================================================
# INSTALAR XRAY CORE
# ==============================================================

install_xray_core() {

    anim_step "Descargando Xray Core oficial"

    if ! bash -c "$(curl -fsSL \
        https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
        install; then

        anim_fail "Error instalando Xray Core"
        return 1
    fi

    anim_done "Xray Core instalado"
}

# ==============================================================
# DIRECTORIOS
# ==============================================================

create_xray_dirs() {

    mkdir -p "$XRAY_DIR"
    mkdir -p /var/log/xray
    mkdir -p "$BASE/sistema"

    touch "$XRAY_LOG"
    touch "$XRAY_PORTS_FILE"
    touch "$XRAY_LIMITS_FILE"
    touch "$XRAY_SUSPEND_FILE"
    touch "$XRAY_CORTES_LOG"
}

# ==============================================================
# CONFIGURACIÓN BASE
# ==============================================================

create_xray_config() {

    if [[ -f "$XRAY_CFG" ]]; then
        cp -a "$XRAY_CFG" "${XRAY_CFG}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    cat > "$XRAY_CFG" <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },

  "api": {
    "tag": "api",
    "listen": "127.0.0.1:10085",
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ]
  },

  "stats": {},

  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },

  "inbounds": [

    {
      "tag": "vmess-in",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/vmess"
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
      "tag": "vless-in",
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "vless",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/vless"
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
      "tag": "trojan-in",
      "port": 10004,
      "listen": "127.0.0.1",
      "protocol": "trojan",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/trojan-ws"
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
  ],

  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
}

# ==============================================================
# GARANTIZAR API
# ==============================================================

ensure_xray_api_config() {

    [[ -f "$XRAY_CFG" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local TMP="/tmp/kevintech-xray-api.json"

    jq '
        .api = {
            "tag":"api",
            "listen":"127.0.0.1:10085",
            "services":[
                "HandlerService",
                "LoggerService",
                "StatsService"
            ]
        }
        | .stats = {}
        | .policy = {
            "levels":{
                "0":{
                    "statsUserUplink":true,
                    "statsUserDownlink":true
                }
            },
            "system":{
                "statsInboundUplink":true,
                "statsInboundDownlink":true
            }
        }
        | .routing = (.routing // {"rules":[]})
        | .routing.rules = (
            [.routing.rules[]? |
             select(
                 .inboundTag != ["api"] and
                 .outboundTag != "api"
             )
            ]
            +
            [{
                "type":"field",
                "inboundTag":["api"],
                "outboundTag":"direct"
            }]
        )
    ' "$XRAY_CFG" > "$TMP" 2>/dev/null || {
        rm -f "$TMP"
        return 1
    }

    if jq empty "$TMP" >/dev/null 2>&1; then

        cp -a "$XRAY_CFG" "${XRAY_CFG}.api-backup"

        mv "$TMP" "$XRAY_CFG"

        return 0
    fi

    rm -f "$TMP"
    return 1
}

# ==============================================================
# GARANTIZAR INBOUNDS
# ==============================================================

ensure_xray_inbounds() {

    [[ -f "$XRAY_CFG" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local TMP="/tmp/kevintech-xray-inbounds.json"

    jq '
    .inbounds = (
        (.inbounds // [])
        |
        (
            if any(.[]; .tag == "vmess-in") then .
            else . + [{
                "tag":"vmess-in",
                "port":10002,
                "listen":"127.0.0.1",
                "protocol":"vmess",
                "settings":{"clients":[]},
                "streamSettings":{
                    "network":"ws",
                    "wsSettings":{"path":"/vmess"}
                },
                "sniffing":{
                    "enabled":true,
                    "destOverride":["http","tls"]
                }
            }]
            end
        )
        |
        (
            if any(.[]; .tag == "vless-in") then .
            else . + [{
                "tag":"vless-in",
                "port":10003,
                "listen":"127.0.0.1",
                "protocol":"vless",
                "settings":{
                    "clients":[],
                    "decryption":"none"
                },
                "streamSettings":{
                    "network":"ws",
                    "wsSettings":{"path":"/vless"}
                },
                "sniffing":{
                    "enabled":true,
                    "destOverride":["http","tls"]
                }
            }]
            end
        )
        |
        (
            if any(.[]; .tag == "trojan-in") then .
            else . + [{
                "tag":"trojan-in",
                "port":10004,
                "listen":"127.0.0.1",
                "protocol":"trojan",
                "settings":{"clients":[]},
                "streamSettings":{
                    "network":"ws",
                    "wsSettings":{"path":"/trojan-ws"}
                },
                "sniffing":{
                    "enabled":true,
                    "destOverride":["http","tls"]
                }
            }]
            end
        )
    )
    ' "$XRAY_CFG" > "$TMP" 2>/dev/null || {
        rm -f "$TMP"
        return 1
    }

    if jq empty "$TMP" >/dev/null 2>&1; then
        mv "$TMP" "$XRAY_CFG"
        return 0
    fi

    rm -f "$TMP"
    return 1
}

# ==============================================================
# RESILIENCIA SYSTEMD
# ==============================================================

ensure_xray_resilience() {

    mkdir -p /etc/systemd/system/xray.service.d

    cat > /etc/systemd/system/xray.service.d/10-kevintech-resilience.conf <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
EOF

    systemctl daemon-reload
    systemctl enable xray >/dev/null 2>&1
}

# ==============================================================
# FIREWALL
# ==============================================================

open_xray_ports() {

    for PORT in 80 443 8080 8443; do

        iptables -C INPUT \
            -p tcp \
            --dport "$PORT" \
            -j ACCEPT 2>/dev/null ||
        iptables -A INPUT \
            -p tcp \
            --dport "$PORT" \
            -j ACCEPT

    done

    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
}

# ==============================================================
# HAPROXY
# ==============================================================

ensure_haproxy_xray_ports() {

    command -v haproxy >/dev/null 2>&1 || return 0
    [[ -f "$HAPROXY_CFG" ]] || return 0

    # Evitar duplicados.
    if ! grep -q "bind \*:8443 ssl" "$HAPROXY_CFG" 2>/dev/null; then

        if grep -q "yha.pem" "$HAPROXY_CFG" 2>/dev/null; then

            sed -i \
                '/bind abns@haproxy-https/i\    bind *:8443 ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1' \
                "$HAPROXY_CFG"

        fi

    fi

    if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
        systemctl reload haproxy >/dev/null 2>&1 || true
    fi
}

ensure_haproxy_xray_backends() {

    command -v haproxy >/dev/null 2>&1 || return 0
    [[ -f "$HAPROXY_CFG" ]] || return 0

    if ! grep -q "^backend kevintech_vless_backend" "$HAPROXY_CFG" 2>/dev/null; then

        cat >> "$HAPROXY_CFG" <<'EOF'

# ============================================================
# KEVINTECH XRAY VLESS
# ============================================================
backend kevintech_vless_backend
    mode tcp
    server kevintech_vless 127.0.0.1:10003 check

# ============================================================
# KEVINTECH XRAY TROJAN
# ============================================================
backend kevintech_trojan_backend
    mode tcp
    server kevintech_trojan 127.0.0.1:10004 check
EOF

    fi

    if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
        systemctl reload haproxy >/dev/null 2>&1 || true
    fi
}

# ==============================================================
# REINICIAR XRAY
# ==============================================================

restart_xray() {

    svc_restart_anim xray "Reiniciando Xray"
}

# ==============================================================
# INSTALAR XRAY
# ==============================================================

install_xray() {

    clear

    mv_header \
        "🚀 INSTALANDO XRAY CORE" \
        "VMess · VLESS · Trojan" \
        "KevinTech v$VERSION"

    install_xray_dependencies || return 1

    anim_step "Configurando firewall"

    open_xray_ports

    anim_done "Puertos preparados"

    install_xray_core || return 1

    create_xray_dirs

    anim_step "Generando configuración Xray"

    if [[ -f "$XRAY_CFG" ]]; then
        ensure_xray_api_config || true
        ensure_xray_inbounds || true
    else
        create_xray_config
    fi

    ensure_xray_api_config || true
    ensure_xray_inbounds || true
    ensure_xray_resilience

    if ! xray run -test -config "$XRAY_CFG" >/dev/null 2>&1; then

        echo
        echo -e "${RED}✘ La configuración de Xray contiene errores.${RESET}"
        echo

        xray run -test -config "$XRAY_CFG" 2>&1 | tail -30

        return 1
    fi

    anim_step "Iniciando Xray"

    systemctl daemon-reload
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray

    anim_step "Integrando HAProxy"

    ensure_haproxy_xray_ports
    ensure_haproxy_xray_backends

    if [[ -f "$CONFIG" ]]; then

        sed -i '/^V2RAY=/d;/^XRAY=/d' "$CONFIG"

        echo "V2RAY=ON" >> "$CONFIG"

        grep -q "^XRAY_PORT=" "$CONFIG" ||
            echo "XRAY_PORT=443" >> "$CONFIG"

    fi

    XRAY_PORT=443

    echo

    if svc_up xray; then

        anim_done "Xray instalado y ACTIVO"

    else

        anim_fail "Xray fue instalado pero no está activo"

        echo
        echo -e "${YELLOW}Revisa:${RESET}"
        echo "  journalctl -u xray -n 50 --no-pager"

    fi

    pause_screen
}

# ==============================================================
# DESINSTALAR XRAY
# ==============================================================

remove_xray() {

    clear

    mv_header \
        "🗑️ DESINSTALAR XRAY" \
        "Eliminación del Xray Core" \
        "KevinTech v$VERSION"

    echo -e "${YELLOW}⚠️ Esto detendrá y eliminará Xray Core.${RESET}"
    echo

    read -rp "¿Continuar? [s/N]: " CONFIRM

    [[ "$CONFIRM" =~ ^[sSyY]$ ]] || return

    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true

    if command -v xray >/dev/null 2>&1; then

        bash -c "$(curl -fsSL \
            https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
            remove >/dev/null 2>&1 || true

    fi

    rm -rf "$XRAY_DIR"
    rm -rf /var/log/xray

    rm -f /etc/systemd/system/xray.service.d/10-kevintech-resilience.conf

    systemctl daemon-reload

    if [[ -f "$CONFIG" ]]; then

        sed -i '/^V2RAY=/d;/^XRAY=/d' "$CONFIG"

        echo "V2RAY=OFF" >> "$CONFIG"

    fi

    echo
    echo -e "${GREEN}✔ Xray eliminado correctamente.${RESET}"

    pause_screen
}

# ==============================================================
# IP PÚBLICA
# ==============================================================

mv_pub_ip() {

    local IP=""

    if [[ -s "$BASE/sistema/.pub_ip" ]]; then
        IP=$(tr -d '[:space:]' < "$BASE/sistema/.pub_ip")
    fi

    if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

        IP=$(curl -4 -fsS --max-time 5 ifconfig.me 2>/dev/null)

        [[ -z "$IP" ]] &&
            IP=$(curl -4 -fsS --max-time 5 api.ipify.org 2>/dev/null)

        [[ -z "$IP" ]] &&
            IP=$(hostname -I 2>/dev/null | awk '{print $1}')

        if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

            mkdir -p "$BASE/sistema"

            printf '%s' "$IP" > "$BASE/sistema/.pub_ip"

        else

            IP=""

        fi
    fi

    printf '%s' "$IP"
}

# ==============================================================
# DOMINIO
# ==============================================================

load_domain() {

    [[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null

    DOMAIN="${SERVER_DOMAIN:-${DOMAIN:-}}"

    XRAY_PORT="${XRAY_PORT:-443}"

    if [[ -z "$DOMAIN" && -f /etc/xray/domain ]]; then
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
    fi

    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$(mv_pub_ip)"
    fi
}

# ==============================================================
# VALIDAR CONFIG
# ==============================================================

check_xray_config() {

    if [[ ! -f "$XRAY_CFG" ]]; then

        echo
        echo -e "${RED}✘ No existe:${RESET}"
        echo -e "${YELLOW}$XRAY_CFG${RESET}"

        return 1
    fi

    command -v jq >/dev/null 2>&1 || {

        echo -e "${RED}✘ jq no está instalado.${RESET}"

        return 1
    }

    return 0
}

# ==============================================================
# DURACIÓN
# ==============================================================

ask_duration() {

    NEW_DAYS=0

    echo
    echo -e "${CYAN}┌────────────── VIGENCIA ──────────────┐${RESET}"
    echo -e " ${GRAY}0 = ilimitado${RESET}"
    echo -e "${CYAN}└───────────────────────────────────────┘${RESET}"
    echo

    read -rp "Días de vigencia [0]: " NEW_DAYS

    [[ -z "$NEW_DAYS" ]] && NEW_DAYS=0

    if ! [[ "$NEW_DAYS" =~ ^[0-9]+$ ]]; then
        NEW_DAYS=0
    fi
}

# ==============================================================
# PUERTO
# ==============================================================

select_xray_port() {

    echo
    echo -e "${CYAN}┌──────────── PUERTO DEL USUARIO ────────────┐${RESET}"
    echo -e " ${GREEN}[1]${RESET} 🔒 443  — TLS"
    echo -e " ${GREEN}[2]${RESET} 🌐 80   — HTTP"
    echo -e " ${GREEN}[3]${RESET} 🚀 8080 — HTTP"
    echo -e " ${GREEN}[4]${RESET} 🛡️ 8443 — TLS"
    echo -e " ${RED}[0]${RESET} ↩ Cancelar"
    echo -e "${CYAN}└─────────────────────────────────────────────┘${RESET}"
    echo

    read -rp "➜ Puerto: " OPORT

    case "$OPORT" in
        1) NEW_PORT=443 ;;
        2) NEW_PORT=80 ;;
        3) NEW_PORT=8080 ;;
        4) NEW_PORT=8443 ;;
        *) return 1 ;;
    esac

    return 0
}

# ==============================================================
# PUERTOS POR USUARIO
# ==============================================================

get_xray_port() {

    local USER="$1"
    local P=""

    P=$(grep -F "^${USER}=" "$XRAY_PORTS_FILE" 2>/dev/null |
        tail -1 |
        cut -d= -f2)

    echo "${P:-${XRAY_PORT:-443}}"
}

save_xray_port() {

    local USER="$1"
    local PORT="$2"

    mkdir -p "$BASE/sistema"

    touch "$XRAY_PORTS_FILE"

    sed -i "/^${USER}=/d" "$XRAY_PORTS_FILE"

    echo "$USER=$PORT" >> "$XRAY_PORTS_FILE"
}

# ==============================================================
# LÍMITES
# ==============================================================
#
# FORMATO:
# usuario=CONEXIONES:GB:DIAS:FECHA_INICIO
#
# 0 = ilimitado
# ==============================================================

get_xray_limit() {

    local USER="$1"
    local FIELD="$2"
    local LINE
    local -a VALUES

    LINE=$(grep -F "^${USER}=" "$XRAY_LIMITS_FILE" 2>/dev/null |
        tail -1)

    [[ -z "$LINE" ]] && {
        echo "0"
        return
    }

    IFS=':' read -r -a VALUES <<< "${LINE#*=}"

    case "$FIELD" in
        conn)
            echo "${VALUES[0]:-0}"
            ;;
        gb)
            echo "${VALUES[1]:-0}"
            ;;
        dias)
            echo "${VALUES[2]:-0}"
            ;;
        fecha)
            echo "${VALUES[3]:-$(date +%Y-%m-%d)}"
            ;;
        *)
            echo "0"
            ;;
    esac
}

save_xray_limits() {

    local USER="$1"
    local MAXCONN="$2"
    local MAXGB="$3"
    local MAXDIAS="$4"

    mkdir -p "$BASE/sistema"

    touch "$XRAY_LIMITS_FILE"

    sed -i "/^${USER}=/d" "$XRAY_LIMITS_FILE"

    echo "$USER=${MAXCONN:-0}:${MAXGB:-0}:${MAXDIAS:-0}:$(date +%Y-%m-%d)" \
        >> "$XRAY_LIMITS_FILE"
}

xray_dias_restantes() {

    local USER="$1"

    local MAXDIAS
    local FECHA
    local VENCE
    local RESTANTES

    MAXDIAS=$(get_xray_limit "$USER" dias)
    FECHA=$(get_xray_limit "$USER" fecha)

    [[ "$MAXDIAS" == "0" ]] && {
        echo "9999"
        return
    }

    VENCE=$(date \
        -d "$FECHA + $MAXDIAS days" \
        +%Y-%m-%d 2>/dev/null)

    [[ -z "$VENCE" ]] && {
        echo "9999"
        return
    }

    RESTANTES=$(( \
        ( \
            $(date -d "$VENCE" +%s) \
            - \
            $(date +%s) \
            + 86399 \
        ) / 86400 \
    ))

    (( RESTANTES < 0 )) && RESTANTES=0

    echo "$RESTANTES"
}

# ==============================================================
# VMESS
# ==============================================================

vmess_user_exists() {

    jq -e \
        --arg email "$1" \
        '.inbounds[] |
         select(.tag=="vmess-in") |
         .settings.clients[]? |
         select(.email==$email)' \
        "$XRAY_CFG" >/dev/null 2>&1
}

get_vmess_uuid() {

    jq -r \
        --arg email "$1" \
        '.inbounds[] |
         select(.tag=="vmess-in") |
         .settings.clients[]? |
         select(.email==$email) |
         .id' \
        "$XRAY_CFG"
}

create_vmess_user() {

    check_xray_config || return 1

    load_domain

    echo
    read -rp "Usuario: " USERNAME

    USERNAME=$(echo "$USERNAME" | xargs)

    [[ -z "$USERNAME" ]] && {
        echo -e "${RED}✘ Usuario inválido.${RESET}"
        return 1
    }

    if vmess_user_exists "$USERNAME"; then

        echo -e "${RED}✘ El usuario ya existe.${RESET}"

        return 1
    fi

    UUID=$(cat /proc/sys/kernel/random/uuid)

    local TMP="/tmp/kevintech-vmess.json"

    jq \
        --arg uuid "$UUID" \
        --arg email "$USERNAME" \
        '
        (.inbounds[] |
         select(.tag=="vmess-in") |
         .settings.clients)
        += [{
            "id":$uuid,
            "level":0,
            "email":$email
        }]
        ' "$XRAY_CFG" > "$TMP"

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        echo -e "${RED}✘ Error modificando config.json.${RESET}"

        return 1
    fi

    mv "$TMP" "$XRAY_CFG"

    if ! xray run -test -config "$XRAY_CFG" >/dev/null 2>&1; then

        echo -e "${RED}✘ Configuración inválida.${RESET}"

        return 1
    fi

    systemctl restart xray

    VMESS_UUID="$UUID"
    VMESS_USER="$USERNAME"

    return 0
}

remove_vmess_user() {

    check_xray_config || return

    echo
    read -rp "Usuario VMess: " USERNAME

    [[ -z "$USERNAME" ]] && return

    if ! vmess_user_exists "$USERNAME"; then

        echo -e "${RED}✘ Usuario no encontrado.${RESET}"

        pause_screen

        return
    fi

    local TMP="/tmp/kevintech-vmess-remove.json"

    jq \
        --arg email "$USERNAME" \
        '
        (.inbounds[] |
         select(.tag=="vmess-in") |
         .settings.clients)
        |= map(select(.email != $email))
        ' "$XRAY_CFG" > "$TMP"

    mv "$TMP" "$XRAY_CFG"

    sed -i "/^${USERNAME}=/d" "$XRAY_PORTS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_LIMITS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_SUSPEND_FILE" 2>/dev/null

    systemctl restart xray

    echo -e "${GREEN}✔ Usuario VMess eliminado.${RESET}"

    pause_screen
}

# ==============================================================
# VLESS
# ==============================================================

vless_user_exists() {

    jq -e \
        --arg email "$1" \
        '.inbounds[] |
         select(.tag=="vless-in") |
         .settings.clients[]? |
         select(.email==$email)' \
        "$XRAY_CFG" >/dev/null 2>&1
}

get_vless_uuid() {

    jq -r \
        --arg email "$1" \
        '.inbounds[] |
         select(.tag=="vless-in") |
         .settings.clients[]? |
         select(.email==$email) |
         .id' \
        "$XRAY_CFG"
}

create_vless_user() {

    check_xray_config || return 1

    ensure_xray_inbounds

    echo
    read -rp "Usuario VLESS: " USERNAME

    USERNAME=$(echo "$USERNAME" | xargs)

    [[ -z "$USERNAME" ]] && return 1

    if vless_user_exists "$USERNAME"; then

        echo -e "${RED}✘ El usuario ya existe.${RESET}"

        return 1
    fi

    UUID=$(cat /proc/sys/kernel/random/uuid)

    local TMP="/tmp/kevintech-vless.json"

    jq \
        --arg uuid "$UUID" \
        --arg email "$USERNAME" \
        '
        (.inbounds[] |
         select(.tag=="vless-in") |
         .settings.clients)
        += [{
            "id":$uuid,
            "level":0,
            "email":$email
        }]
        ' "$XRAY_CFG" > "$TMP"

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        echo -e "${RED}✘ Error modificando config.json.${RESET}"

        return 1
    fi

    mv "$TMP" "$XRAY_CFG"

    systemctl restart xray

    VLESS_UUID="$UUID"
    VLESS_USER="$USERNAME"

    return 0
}

remove_vless_user() {

    check_xray_config || return

    echo
    read -rp "Usuario VLESS: " USERNAME

    [[ -z "$USERNAME" ]] && return

    if ! vless_user_exists "$USERNAME"; then

        echo -e "${RED}✘ Usuario no encontrado.${RESET}"

        pause_screen

        return
    fi

    local TMP="/tmp/kevintech-vless-remove.json"

    jq \
        --arg email "$USERNAME" \
        '
        (.inbounds[] |
         select(.tag=="vless-in") |
         .settings.clients)
        |= map(select(.email != $email))
        ' "$XRAY_CFG" > "$TMP"

    mv "$TMP" "$XRAY_CFG"

    sed -i "/^${USERNAME}=/d" "$XRAY_PORTS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_LIMITS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_SUSPEND_FILE" 2>/dev/null

    systemctl restart xray

    echo -e "${GREEN}✔ Usuario VLESS eliminado.${RESET}"

    pause_screen
}

# ==============================================================
# TROJAN
# ==============================================================

trojan_user_exists() {

    jq -e \
        --arg email "$1" \
        '.inbounds[] |
         select(.tag=="trojan-in") |
         .settings.clients[]? |
         select(.email==$email)' \
        "$XRAY_CFG" >/dev/null 2>&1
}

get_trojan_pass() {

    jq -r \
        --arg email "$1" \
        '.inbounds[] |
         select(.tag=="trojan-in") |
         .settings.clients[]? |
         select(.email==$email) |
         .password' \
        "$XRAY_CFG"
}

create_trojan_user() {

    check_xray_config || return 1

    ensure_xray_inbounds

    echo
    read -rp "Usuario Trojan: " USERNAME

    USERNAME=$(echo "$USERNAME" | xargs)

    [[ -z "$USERNAME" ]] && return 1

    if trojan_user_exists "$USERNAME"; then

        echo -e "${RED}✘ El usuario ya existe.${RESET}"

        return 1
    fi

    PASSWORD=$(cat /proc/sys/kernel/random/uuid)

    local TMP="/tmp/kevintech-trojan.json"

    jq \
        --arg pass "$PASSWORD" \
        --arg email "$USERNAME" \
        '
        (.inbounds[] |
         select(.tag=="trojan-in") |
         .settings.clients)
        += [{
            "password":$pass,
            "level":0,
            "email":$email
        }]
        ' "$XRAY_CFG" > "$TMP"

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        echo -e "${RED}✘ Error modificando config.json.${RESET}"

        return 1
    fi

    mv "$TMP" "$XRAY_CFG"

    systemctl restart xray

    TROJAN_PASSWORD="$PASSWORD"
    TROJAN_USER="$USERNAME"

    return 0
}

remove_trojan_user() {

    check_xray_config || return

    echo
    read -rp "Usuario Trojan: " USERNAME

    [[ -z "$USERNAME" ]] && return

    if ! trojan_user_exists "$USERNAME"; then

        echo -e "${RED}✘ Usuario no encontrado.${RESET}"

        pause_screen

        return
    fi

    local TMP="/tmp/kevintech-trojan-remove.json"

    jq \
        --arg email "$USERNAME" \
        '
        (.inbounds[] |
         select(.tag=="trojan-in") |
         .settings.clients)
        |= map(select(.email != $email))
        ' "$XRAY_CFG" > "$TMP"

    mv "$TMP" "$XRAY_CFG"

    sed -i "/^${USERNAME}=/d" "$XRAY_PORTS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_LIMITS_FILE" 2>/dev/null
    sed -i "/^${USERNAME}=/d" "$XRAY_SUSPEND_FILE" 2>/dev/null

    systemctl restart xray

    echo -e "${GREEN}✔ Usuario Trojan eliminado.${RESET}"

    pause_screen
}

# ==============================================================
# GENERAR LINKS
# ==============================================================

generate_vmess_link() {

    local USER="$1"
    local UUID="$2"
    local PORT="${3:-$(get_xray_port "$USER")}"

    load_domain

    local TLS="tls"
    local SNI="$DOMAIN"
    local ALLOW="false"

    if [[ "$PORT" == "80" || "$PORT" == "8080" ]]; then

        TLS=""
        SNI=""
        ALLOW="false"

    else

        ALLOW="true"

    fi

    local JSON

    JSON=$(cat <<EOF
{
  "v":"2",
  "ps":"$USER",
  "add":"$DOMAIN",
  "port":"$PORT",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$DOMAIN",
  "path":"/vmess",
  "tls":"$TLS",
  "sni":"$SNI",
  "alpn":"",
  "allowInsecure":$ALLOW
}
EOF
)

    printf '%s' "$JSON" |
        base64 -w 0 2>/dev/null ||
    printf '%s' "$JSON" |
        base64 |
        tr -d '\n'
}

generate_vless_link() {

    local USER="$1"
    local UUID="$2"
    local PORT="${3:-$(get_xray_port "$USER")}"

    load_domain

    local SEC="tls"
    local EXTRA="&allowInsecure=true"

    if [[ "$PORT" == "80" || "$PORT" == "8080" ]]; then

        SEC="none"
        EXTRA=""

    fi

    printf \
        'vless://%s@%s:%s?encryption=none&security=%s&type=ws&path=%%2Fvless&host=%s&sni=%s%s#%s\n' \
        "$UUID" \
        "$DOMAIN" \
        "$PORT" \
        "$SEC" \
        "$DOMAIN" \
        "$DOMAIN" \
        "$EXTRA" \
        "$USER"
}

generate_trojan_link() {

    local USER="$1"
    local PASSWORD="$2"
    local PORT="${3:-$(get_xray_port "$USER")}"

    load_domain

    local SEC="tls"
    local EXTRA="&allowInsecure=true"

    if [[ "$PORT" == "80" || "$PORT" == "8080" ]]; then

        SEC="none"
        EXTRA=""

    fi

    printf \
        'trojan://%s@%s:%s?security=%s&type=ws&path=%%2Ftrojan-ws&host=%s&sni=%s%s#%s\n' \
        "$PASSWORD" \
        "$DOMAIN" \
        "$PORT" \
        "$SEC" \
        "$DOMAIN" \
        "$DOMAIN" \
        "$EXTRA" \
        "$USER"
}

# ==============================================================
# CREAR CUENTA VMESS
# ==============================================================

create_vmess_account() {

    clear

    mv_deliv_header \
        "⚡ CREAR CUENTA VMESS" \
        "Xray · VMess · WebSocket"

    select_xray_port || return

    local USERPORT="$NEW_PORT"

    echo
    read -rp "Límite conexiones [0=ilimitado]: " MAXCONN
    MAXCONN="${MAXCONN:-0}"

    read -rp "Límite GB [0=ilimitado]: " MAXGB
    MAXGB="${MAXGB:-0}"

    ask_duration
    local MAXDIAS="$NEW_DAYS"

    create_vmess_user || {
        pause_screen
        return
    }

    save_xray_port "$VMESS_USER" "$USERPORT"
    save_xray_limits "$VMESS_USER" "$MAXCONN" "$MAXGB" "$MAXDIAS"

    local LINK

    LINK="vmess://$(generate_vmess_link \
        "$VMESS_USER" \
        "$VMESS_UUID" \
        "$USERPORT")"

    clear

    mv_deliv_header \
        "✅ CUENTA VMESS CREADA" \
        "Xray · Protocolo VMess"

    mv_deliv_sec "📲 CONFIGURACIÓN"

    mv_dcard_top
    mv_dcard_row "👤" "Usuario" "$VMESS_USER"
    mv_dcard_row "🆔" "UUID" "$VMESS_UUID"
    mv_dcard_row "🌐" "Dominio" "$DOMAIN"
    mv_dcard_row "🔒" "Puerto" "$USERPORT"
    mv_dcard_row "📡" "Network" "WebSocket"
    mv_dcard_row "📂" "Path" "/vmess"
    mv_dcard_row "💾" "Límite GB" "$MAXGB"
    mv_dcard_row "🔗" "Conexiones" "$MAXCONN"
    mv_dcard_row "📅" "Días" "$MAXDIAS"

    mv_dcard_bot

    echo
    mv_deliv_sec "🔗 ENLACE VMESS"

    echo -e "${GREEN}${LINK}${RESET}"

    echo
    mv_deliv_pie

    pause_screen
}

# ==============================================================
# CREAR CUENTA VLESS
# ==============================================================

create_vless_account() {

    clear

    mv_deliv_header \
        "🔰 CREAR CUENTA VLESS" \
        "Xray · VLESS · WebSocket"

    select_xray_port || return

    local USERPORT="$NEW_PORT"

    echo
    read -rp "Límite conexiones [0=ilimitado]: " MAXCONN
    MAXCONN="${MAXCONN:-0}"

    read -rp "Límite GB [0=ilimitado]: " MAXGB
    MAXGB="${MAXGB:-0}"

    ask_duration
    local MAXDIAS="$NEW_DAYS"

    create_vless_user || {
        pause_screen
        return
    }

    save_xray_port "$VLESS_USER" "$USERPORT"
    save_xray_limits "$VLESS_USER" "$MAXCONN" "$MAXGB" "$MAXDIAS"

    local LINK

    LINK=$(generate_vless_link \
        "$VLESS_USER" \
        "$VLESS_UUID" \
        "$USERPORT")

    clear

    mv_deliv_header \
        "✅ CUENTA VLESS CREADA" \
        "Xray · Protocolo VLESS"

    mv_deliv_sec "📲 CONFIGURACIÓN"

    mv_dcard_top
    mv_dcard_row "👤" "Usuario" "$VLESS_USER"
    mv_dcard_row "🆔" "UUID" "$VLESS_UUID"
    mv_dcard_row "🌐" "Dominio" "$DOMAIN"
    mv_dcard_row "🔒" "Puerto" "$USERPORT"
    mv_dcard_row "📡" "Network" "WebSocket"
    mv_dcard_row "📂" "Path" "/vless"
    mv_dcard_row "💾" "Límite GB" "$MAXGB"
    mv_dcard_row "🔗" "Conexiones" "$MAXCONN"
    mv_dcard_row "📅" "Días" "$MAXDIAS"

    mv_dcard_bot

    echo
    mv_deliv_sec "🔗 ENLACE VLESS"

    echo -e "${GREEN}${LINK}${RESET}"

    echo
    mv_deliv_pie

    pause_screen
}

# ==============================================================
# CREAR CUENTA TROJAN
# ==============================================================

create_trojan_account() {

    clear

    mv_deliv_header \
        "🛡️ CREAR CUENTA TROJAN" \
        "Xray · Trojan · WebSocket"

    select_xray_port || return

    local USERPORT="$NEW_PORT"

    echo
    read -rp "Límite conexiones [0=ilimitado]: " MAXCONN
    MAXCONN="${MAXCONN:-0}"

    read -rp "Límite GB [0=ilimitado]: " MAXGB
    MAXGB="${MAXGB:-0}"

    ask_duration
    local MAXDIAS="$NEW_DAYS"

    create_trojan_user || {
        pause_screen
        return
    }

    save_xray_port "$TROJAN_USER" "$USERPORT"
    save_xray_limits "$TROJAN_USER" "$MAXCONN" "$MAXGB" "$MAXDIAS"

    local LINK

    LINK=$(generate_trojan_link \
        "$TROJAN_USER" \
        "$TROJAN_PASSWORD" \
        "$USERPORT")

    clear

    mv_deliv_header \
        "✅ CUENTA TROJAN CREADA" \
        "Xray · Protocolo Trojan"

    mv_deliv_sec "📲 CONFIGURACIÓN"

    mv_dcard_top
    mv_dcard_row "👤" "Usuario" "$TROJAN_USER"
    mv_dcard_row "🔑" "Password" "$TROJAN_PASSWORD"
    mv_dcard_row "🌐" "Dominio" "$DOMAIN"
    mv_dcard_row "🔒" "Puerto" "$USERPORT"
    mv_dcard_row "📡" "Network" "WebSocket"
    mv_dcard_row "📂" "Path" "/trojan-ws"
    mv_dcard_row "💾" "Límite GB" "$MAXGB"
    mv_dcard_row "🔗" "Conexiones" "$MAXCONN"
    mv_dcard_row "📅" "Días" "$MAXDIAS"

    mv_dcard_bot

    echo
    mv_deliv_sec "🔗 ENLACE TROJAN"

    echo -e "${GREEN}${LINK}${RESET}"

    echo
    mv_deliv_pie

    pause_screen
}

# ==============================================================
# LISTAR USUARIOS
# ==============================================================

list_users_by_tag() {

    local TAG="$1"
    local TITLE="$2"

    check_xray_config || return

    local TOTAL=0
    local USER
    local SECRET
    local PORT

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${CYAN}║${WHITE} %-58s ${CYAN}║${RESET}\n" "$TITLE"
    echo -e "${CYAN}╠════╦══════════════════════╦════════════════════════╦════════╣${RESET}"

    printf "${CYAN}║${WHITE} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${WHITE} %-22s ${CYAN}║${WHITE} %-6s ${CYAN}║${RESET}\n" \
        "#" "USUARIO" "UUID/PASSWORD" "PUERTO"

    echo -e "${CYAN}╠════╬══════════════════════╬════════════════════════╬════════╣${RESET}"

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        if [[ "$TAG" == "vmess-in" ]]; then

            SECRET=$(get_vmess_uuid "$USER")

        elif [[ "$TAG" == "vless-in" ]]; then

            SECRET=$(get_vless_uuid "$USER")

        else

            SECRET=$(get_trojan_pass "$USER")

        fi

        SECRET="${SECRET:0:22}..."

        PORT=$(get_xray_port "$USER")

        TOTAL=$((TOTAL + 1))

        printf \
            "${CYAN}║${GREEN} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${YELLOW} %-22s ${CYAN}║${MAGENTA} %-6s ${CYAN}║${RESET}\n" \
            "$TOTAL" \
            "$USER" \
            "$SECRET" \
            "$PORT"

    done < <(
        jq -r \
            --arg tag "$TAG" \
            '.inbounds[] |
             select(.tag==$tag) |
             .settings.clients[]?.email' \
            "$XRAY_CFG" 2>/dev/null
    )

    if [[ "$TOTAL" == "0" ]]; then

        echo -e "${CYAN}║${RED}                 NO HAY USUARIOS                         ${CYAN}║${RESET}"

    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf \
        "${CYAN}║${WHITE} Total: ${GREEN}%-50s${CYAN}║${RESET}\n" \
        "$TOTAL"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause_screen
}

# ==============================================================
# MOSTRAR CUENTA
# ==============================================================

show_account() {

    local TYPE="$1"

    check_xray_config || return

    echo
    read -rp "Usuario: " USERNAME

    [[ -z "$USERNAME" ]] && return

    local SECRET
    local LINK
    local PORT

    case "$TYPE" in

        vmess)

            SECRET=$(get_vmess_uuid "$USERNAME")

            [[ -z "$SECRET" || "$SECRET" == "null" ]] && {
                echo -e "${RED}✘ Usuario no encontrado.${RESET}"
                pause_screen
                return
            }

            PORT=$(get_xray_port "$USERNAME")

            LINK="vmess://$(generate_vmess_link \
                "$USERNAME" \
                "$SECRET" \
                "$PORT")"

            ;;

        vless)

            SECRET=$(get_vless_uuid "$USERNAME")

            [[ -z "$SECRET" || "$SECRET" == "null" ]] && {
                echo -e "${RED}✘ Usuario no encontrado.${RESET}"
                pause_screen
                return
            }

            PORT=$(get_xray_port "$USERNAME")

            LINK=$(generate_vless_link \
                "$USERNAME" \
                "$SECRET" \
                "$PORT")

            ;;

        trojan)

            SECRET=$(get_trojan_pass "$USERNAME")

            [[ -z "$SECRET" || "$SECRET" == "null" ]] && {
                echo -e "${RED}✘ Usuario no encontrado.${RESET}"
                pause_screen
                return
            }

            PORT=$(get_xray_port "$USERNAME")

            LINK=$(generate_trojan_link \
                "$USERNAME" \
                "$SECRET" \
                "$PORT")

            ;;

    esac

    load_domain

    clear

    mv_deliv_header \
        "✅ CUENTA $TYPE" \
        "KevinTech Xray Manager"

    mv_deliv_sec "📲 DATOS"

    mv_dcard_top
    mv_dcard_row "👤" "Usuario" "$USERNAME"

    if [[ "$TYPE" == "trojan" ]]; then
        mv_dcard_row "🔑" "Password" "$SECRET"
    else
        mv_dcard_row "🆔" "UUID" "$SECRET"
    fi

    mv_dcard_row "🌐" "Dominio" "$DOMAIN"
    mv_dcard_row "🔒" "Puerto" "$PORT"

    mv_dcard_bot

    echo
    mv_deliv_sec "🔗 ENLACE"

    echo -e "${GREEN}${LINK}${RESET}"

    echo
    mv_deliv_pie

    pause_screen
}

# ==============================================================
# EXPORTAR LINK
# ==============================================================

export_link() {

    local TYPE="$1"

    check_xray_config || return

    echo
    read -rp "Usuario: " USERNAME

    [[ -z "$USERNAME" ]] && return

    local SECRET
    local LINK
    local FILE

    case "$TYPE" in

        vmess)

            SECRET=$(get_vmess_uuid "$USERNAME")
            FILE="/tmp/vmess.txt"

            [[ -z "$SECRET" || "$SECRET" == "null" ]] && return

            LINK="vmess://$(generate_vmess_link \
                "$USERNAME" \
                "$SECRET")"

            ;;

        vless)

            SECRET=$(get_vless_uuid "$USERNAME")
            FILE="/tmp/vless.txt"

            [[ -z "$SECRET" || "$SECRET" == "null" ]] && return

            LINK=$(generate_vless_link \
                "$USERNAME" \
                "$SECRET")

            ;;

        trojan)

            SECRET=$(get_trojan_pass "$USERNAME")
            FILE="/tmp/trojan.txt"

            [[ -z "$SECRET" || "$SECRET" == "null" ]] && return

            LINK=$(generate_trojan_link \
                "$USERNAME" \
                "$SECRET")

            ;;

        *)

            return
            ;;

    esac

    printf '%s\n' "$LINK" > "$FILE"

    echo
    echo -e "${GREEN}✔ Link exportado correctamente.${RESET}"
    echo -e "${WHITE}Archivo:${RESET} ${YELLOW}$FILE${RESET}"

    pause_screen
}

# ==============================================================
# CONSUMO XRAY
# ==============================================================

get_user_traffic() {

    local USER="$1"
    local OUT
    local TOTAL

    OUT=$(xray api statsquery \
        --server=127.0.0.1:10085 \
        -pattern "user>>>$USER>>>traffic>>>" \
        2>/dev/null)

    TOTAL=$(echo "$OUT" |
        grep -oE 'Value: [0-9]+' |
        awk '{s += $2} END {print s+0}')

    echo "${TOTAL:-0}"
}

# ==============================================================
# CONEXIONES
# ==============================================================

count_user_conns() {

    local USER="$1"

    [[ -f "$XRAY_LOG" ]] || {
        echo 0
        return
    }

    local LIMIT

    LIMIT=$(date -d "60 seconds ago" \
        "+%Y/%m/%d %H:%M:%S")

    awk -v LIM="$LIMIT" -v USER="$USER" '
    /email:/ {
        DATA=$1" "$2

        if (DATA >= LIM) {
            split($0,a,"email: ")

            if (a[2] == USER)
                count++
        }
    }

    END {
        print count+0
    }
    ' "$XRAY_LOG"
}

# ==============================================================
# USUARIOS ONLINE
# ==============================================================

xray_online_users() {

    clear

    mv_header \
        "👥 USUARIOS ONLINE" \
        "Conexiones detectadas en los últimos 60 segundos"

    if [[ ! -f "$XRAY_LOG" ]]; then

        echo -e "${RED}✘ No existe access.log.${RESET}"

        pause_screen
        return
    fi

    local LIMIT

    LIMIT=$(date -d "60 seconds ago" \
        "+%Y/%m/%d %H:%M:%S")

    local USERS

    USERS=$(awk -v LIM="$LIMIT" '
    /email:/ {
        DATA=$1" "$2

        if (DATA >= LIM) {
            split($0,a,"email: ")
            print a[2]
        }
    }
    ' "$XRAY_LOG" | sort -u)

    if [[ -z "$USERS" ]]; then

        echo -e "${GRAY}No hay usuarios conectados.${RESET}"

    else

        echo "$USERS" |
        while read -r USER; do
            [[ -n "$USER" ]] &&
                echo -e " ${GREEN}●${RESET} $USER"
        done

    fi

    echo
    echo -e "${GREEN}Usuarios online:${RESET} $(printf '%s\n' "$USERS" | sed '/^$/d' | wc -l)"

    pause_screen
}

# ==============================================================
# ESTADO
# ==============================================================

xray_status() {

    clear

    mv_header \
        "📊 ESTADO XRAY" \
        "Servicio · configuración · puertos"

    local STATUS

    if systemctl is-active --quiet xray; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    local VERSION_X

    VERSION_X=$(xray version 2>/dev/null | head -1)

    [[ -z "$VERSION_X" ]] &&
        VERSION_X="NO INSTALADO"

    local CFG_STATUS

    if [[ -f "$XRAY_CFG" ]] &&
       xray run -test -config "$XRAY_CFG" >/dev/null 2>&1; then

        CFG_STATUS="${GREEN}🟢 CORRECTA${RESET}"

    else

        CFG_STATUS="${RED}🔴 ERROR${RESET}"

    fi

    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${RESET}"
    printf " ${WHITE}Estado        :${RESET} %b\n" "$STATUS"
    printf " ${WHITE}Versión       :${RESET} ${GREEN}%s${RESET}\n" "$VERSION_X"
    printf " ${WHITE}Configuración :${RESET} %b\n" "$CFG_STATUS"
    printf " ${WHITE}Puerto API    :${RESET} ${GREEN}10085${RESET}"
    echo
    printf " ${WHITE}VMess         :${RESET} ${GREEN}127.0.0.1:10002${RESET}\n"
    printf " ${WHITE}VLESS         :${RESET} ${GREEN}127.0.0.1:10003${RESET}\n"
    printf " ${WHITE}Trojan        :${RESET} ${GREEN}127.0.0.1:10004${RESET}\n"
    printf " ${WHITE}Entrada       :${RESET} ${GREEN}%s${RESET}\n" "$XRAY_PORT"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${RESET}"

    pause_screen
}

# ==============================================================
# CAMBIAR PUERTO PRINCIPAL
# ==============================================================

change_xray_port() {

    clear

    mv_header \
        "🔧 PUERTO XRAY" \
        "Puerto anunciado para las nuevas cuentas"

    select_xray_port || return

    [[ -f "$CONFIG" ]] || touch "$CONFIG"

    sed -i '/^XRAY_PORT=/d' "$CONFIG"

    echo "XRAY_PORT=$NEW_PORT" >> "$CONFIG"

    XRAY_PORT="$NEW_PORT"

    ensure_haproxy_xray_ports

    echo
    echo -e "${GREEN}✔ Puerto configurado: ${WHITE}$NEW_PORT${RESET}"

    if [[ "$NEW_PORT" == "80" || "$NEW_PORT" == "8080" ]]; then
        echo -e "${YELLOW}⚠️ Las nuevas cuentas utilizarán HTTP sin TLS.${RESET}"
    else
        echo -e "${GREEN}🔒 Las nuevas cuentas utilizarán TLS.${RESET}"
    fi

    pause_screen
}

# ==============================================================
# SUSPENDER USUARIO
# ==============================================================
#
# IMPORTANTE:
# NO elimina el cliente de config.json.
# Solo lo registra como suspendido.
#
# ==============================================================

get_user_inbound() {

    local USER="$1"
    local TAG
    local INDEX=0

    while read -r TAG; do

        if jq -e \
            --arg tag "$TAG" \
            --arg email "$USER" \
            '.inbounds[] |
             select(.tag==$tag) |
             .settings.clients[]? |
             select(.email==$email)' \
            "$XRAY_CFG" >/dev/null 2>&1; then

            echo "$INDEX"
            return

        fi

        INDEX=$((INDEX + 1))

    done < <(
        jq -r '.inbounds[].tag' "$XRAY_CFG" 2>/dev/null
    )

    echo 0
}

suspend_xray_user() {

    local USER="$1"
    local REASON="$2"

    mkdir -p "$BASE/sistema"

    touch "$XRAY_SUSPEND_FILE"
    touch "$XRAY_CORTES_LOG"

    sed -i "/^${USER}=/d" "$XRAY_SUSPEND_FILE"

    echo "$USER=$(date '+%Y-%m-%d %H:%M:%S')|$REASON" \
        >> "$XRAY_SUSPEND_FILE"

    echo "$(date '+%Y-%m-%d %H:%M:%S') SUSPENDIDO $USER — $REASON" \
        >> "$XRAY_CORTES_LOG"
}

reactivate_xray_user() {

    local USER="$1"

    if ! grep -q "^${USER}=" "$XRAY_SUSPEND_FILE" 2>/dev/null; then

        echo -e "${YELLOW}⚠️ El usuario no está suspendido.${RESET}"

        return
    fi

    sed -i "/^${USER}=/d" "$XRAY_SUSPEND_FILE"

    xray api statsreset \
        --server=127.0.0.1:10085 \
        -pattern "user>>>$USER>>>traffic>>>" \
        >/dev/null 2>&1 || true

    echo "$(date '+%Y-%m-%d %H:%M:%S') REACTIVADO $USER" \
        >> "$XRAY_CORTES_LOG"

    echo -e "${GREEN}✔ Usuario reactivado: $USER${RESET}"
}

# ==============================================================
# MENÚ REACTIVAR
# ==============================================================

reactivate_menu() {

    clear

    mv_header \
        "♻️ REACTIVAR USUARIO" \
        "Suspensiones registradas por KevinTech"

    if [[ ! -s "$XRAY_SUSPEND_FILE" ]]; then

        echo -e "${GREEN}✔ No hay usuarios suspendidos.${RESET}"

        pause_screen

        return
    fi

    local -a USERS=()
    local LINE
    local USER
    local I=1

    while IFS= read -r LINE; do

        [[ -z "$LINE" ]] && continue

        USER="${LINE%%=*}"

        USERS+=("$USER")

        printf " ${GREEN}[%02d]${RESET} %s\n" "$I" "$USER"

        I=$((I + 1))

    done < "$XRAY_SUSPEND_FILE"

    echo
    echo -e "${RED}[00]${RESET} Regresar"
    echo

    local OP

    read -rp "➜ Opción: " OP

    [[ "$OP" == "0" || "$OP" == "00" ]] && return

    if ! [[ "$OP" =~ ^[0-9]+$ ]] ||
       (( OP < 1 || OP >= I )); then

        echo -e "${RED}✘ Opción inválida.${RESET}"

        sleep 1

        return
    fi

    USER="${USERS[$((OP - 1))]}"

    reactivate_xray_user "$USER"

    pause_screen
}

# ==============================================================
# VERIFICAR LÍMITES
# ==============================================================

check_xray_limits() {

    [[ -f "$XRAY_CFG" ]] || return 0
    [[ -f "$XRAY_LIMITS_FILE" ]] || return 0

    local LINE
    local USER
    local MAXCONN
    local MAXGB
    local MAXDIAS
    local CONNS
    local TRAFFIC
    local MAXBYTES
    local REST
    local REASON

    while IFS= read -r LINE; do

        [[ -z "$LINE" ]] && continue
        [[ "$LINE" == \#* ]] && continue

        USER="${LINE%%=*}"

        [[ -z "$USER" ]] && continue

        # Ya suspendido.
        grep -q "^${USER}=" "$XRAY_SUSPEND_FILE" 2>/dev/null &&
            continue

        MAXCONN=$(get_xray_limit "$USER" conn)
        MAXGB=$(get_xray_limit "$USER" gb)
        MAXDIAS=$(get_xray_limit "$USER" dias)

        REASON=""

        if [[ "$MAXCONN" != "0" ]]; then

            CONNS=$(count_user_conns "$USER")

            if (( CONNS > MAXCONN )); then

                REASON="límite conexiones ${CONNS}/${MAXCONN}"

            fi
        fi

        if [[ -z "$REASON" && "$MAXGB" != "0" ]]; then

            TRAFFIC=$(get_user_traffic "$USER")

            MAXBYTES=$((MAXGB * 1024 * 1024 * 1024))

            if (( TRAFFIC > MAXBYTES )); then

                REASON="límite consumo"

            fi
        fi

        if [[ -z "$REASON" && "$MAXDIAS" != "0" ]]; then

            REST=$(xray_dias_restantes "$USER")

            if [[ "$REST" == "0" ]]; then

                REASON="cuenta vencida"

            fi
        fi

        if [[ -n "$REASON" ]]; then

            suspend_xray_user "$USER" "$REASON"

        fi

    done < "$XRAY_LIMITS_FILE"
}

# ==============================================================
# CONSUMO Y LÍMITES
# ==============================================================

show_xray_limits() {

    clear

    mv_header \
        "📊 CONSUMO Y LÍMITES" \
        "Control de usuarios Xray"

    if [[ ! -f "$XRAY_CFG" ]]; then

        echo -e "${RED}✘ Xray no está configurado.${RESET}"

        pause_screen

        return
    fi

    local TOTAL=0
    local USER
    local MAXCONN
    local MAXGB
    local MAXDIAS
    local TRAFFIC
    local GB
    local REST
    local STATUS

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        MAXCONN=$(get_xray_limit "$USER" conn)
        MAXGB=$(get_xray_limit "$USER" gb)
        MAXDIAS=$(get_xray_limit "$USER" dias)

        TRAFFIC=$(get_user_traffic "$USER")

        GB=$(awk \
            -v b="$TRAFFIC" \
            'BEGIN {printf "%.2f", b/1073741824}')

        if [[ "$MAXDIAS" == "0" ]]; then
            REST="∞"
        else
            REST="$(xray_dias_restantes "$USER")d"
        fi

        if grep -q "^${USER}=" "$XRAY_SUSPEND_FILE" 2>/dev/null; then
            STATUS="${RED}SUSPENDIDO${RESET}"
        else
            STATUS="${GREEN}OK${RESET}"
        fi

        TOTAL=$((TOTAL + 1))

        printf \
            " ${WHITE}%-20s${RESET} | ${YELLOW}%8s GB${RESET} | Conn: ${MAGENTA}%-4s${RESET} | Días: ${BLUE}%-6s${RESET} | %b\n" \
            "$USER" \
            "$GB/$MAXGB" \
            "$MAXCONN" \
            "$REST" \
            "$STATUS"

    done < <(
        jq -r \
            '.inbounds[].settings.clients[]?.email' \
            "$XRAY_CFG" 2>/dev/null |
        sort -u
    )

    echo
    echo -e "${GREEN}Total de usuarios: $TOTAL${RESET}"

    pause_screen
}

# ==============================================================
# INFORMACIÓN DEL SERVIDOR
# ==============================================================

server_info() {

    load_domain

    clear

    mv_header \
        "🌐 INFORMACIÓN XRAY" \
        "Configuración del servidor"

    echo -e "${WHITE}Dominio:${RESET}     ${GREEN}$DOMAIN${RESET}"
    echo -e "${WHITE}Puerto:${RESET}      ${GREEN}$XRAY_PORT${RESET}"
    echo -e "${WHITE}VMess Path:${RESET}  ${GREEN}/vmess${RESET}"
    echo -e "${WHITE}VLESS Path:${RESET}  ${GREEN}/vless${RESET}"
    echo -e "${WHITE}Trojan Path:${RESET} ${GREEN}/trojan-ws${RESET}"
    echo -e "${WHITE}API:${RESET}         ${GREEN}127.0.0.1:10085${RESET}"
    echo -e "${WHITE}VMess interno:${RESET} ${GREEN}10002${RESET}"
    echo -e "${WHITE}VLESS interno:${RESET} ${GREEN}10003${RESET}"
    echo -e "${WHITE}Trojan interno:${RESET} ${GREEN}10004${RESET}"

    pause_screen
}

# ==============================================================
# SUBMENÚ VMESS
# ==============================================================

vmess_menu() {

    while true; do

        clear

        mv_header \
            "⚡ GESTIÓN VMESS" \
            "Usuarios VMess"

        echo -e "${GREEN}[01]${RESET} 👤 Crear Usuario"
        echo -e "${GREEN}[02]${RESET} 🗑️ Eliminar Usuario"
        echo -e "${GREEN}[03]${RESET} 📋 Listar Usuarios"
        echo -e "${GREEN}[04]${RESET} 🔗 Mostrar Cuenta"
        echo -e "${GREEN}[05]${RESET} 📤 Exportar Link"
        echo -e "${GREEN}[06]${RESET} 📊 Consumo y Límites"
        echo -e "${GREEN}[07]${RESET} 👥 Usuarios Online"
        echo -e "${GREEN}[08]${RESET} ♻️ Reactivar Suspendido"
        echo -e "${RED}[00]${RESET} ↩️ Regresar"
        echo

        read -rp "➜ Opción: " OP

        case "$OP" in

            1|01)
                create_vmess_account
                ;;

            2|02)
                remove_vmess_user
                ;;

            3|03)
                list_users_by_tag "vmess-in" "👥 USUARIOS VMESS"
                ;;

            4|04)
                show_account "vmess"
                ;;

            5|05)
                export_link "vmess"
                ;;

            6|06)
                show_xray_limits
                ;;

            7|07)
                xray_online_users
                ;;

            8|08)
                reactivate_menu
                ;;

            0|00)
                return
                ;;

            *)
                echo -e "${RED}✘ Opción inválida.${RESET}"
                sleep 1
                ;;

        esac

    done
}

# ==============================================================
# SUBMENÚ VLESS
# ==============================================================

vless_menu() {

    while true; do

        clear

        mv_header \
            "🔰 GESTIÓN VLESS" \
            "Usuarios VLESS"

        echo -e "${GREEN}[01]${RESET} 👤 Crear Usuario"
        echo -e "${GREEN}[02]${RESET} 🗑️ Eliminar Usuario"
        echo -e "${GREEN}[03]${RESET} 📋 Listar Usuarios"
        echo -e "${GREEN}[04]${RESET} 🔗 Mostrar Cuenta"
        echo -e "${GREEN}[05]${RESET} 📤 Exportar Link"
        echo -e "${GREEN}[06]${RESET} 📊 Consumo y Límites"
        echo -e "${GREEN}[07]${RESET} 👥 Usuarios Online"
        echo -e "${GREEN}[08]${RESET} ♻️ Reactivar Suspendido"
        echo -e "${RED}[00]${RESET} ↩️ Regresar"
        echo

        read -rp "➜ Opción: " OP

        case "$OP" in

            1|01)
                create_vless_account
                ;;

            2|02)
                remove_vless_user
                ;;

            3|03)
                list_users_by_tag "vless-in" "👥 USUARIOS VLESS"
                ;;

            4|04)
                show_account "vless"
                ;;

            5|05)
                export_link "vless"
                ;;

            6|06)
                show_xray_limits
                ;;

            7|07)
                xray_online_users
                ;;

            8|08)
                reactivate_menu
                ;;

            0|00)
                return
                ;;

            *)
                echo -e "${RED}✘ Opción inválida.${RESET}"
                sleep 1
                ;;

        esac

    done
}

# ==============================================================
# SUBMENÚ TROJAN
# ==============================================================

trojan_menu() {

    while true; do

        clear

        mv_header \
            "🛡️ GESTIÓN TROJAN" \
            "Usuarios Trojan"

        echo -e "${GREEN}[01]${RESET} 👤 Crear Usuario"
        echo -e "${GREEN}[02]${RESET} 🗑️ Eliminar Usuario"
        echo -e "${GREEN}[03]${RESET} 📋 Listar Usuarios"
        echo -e "${GREEN}[04]${RESET} 🔗 Mostrar Cuenta"
        echo -e "${GREEN}[05]${RESET} 📤 Exportar Link"
        echo -e "${GREEN}[06]${RESET} 📊 Consumo y Límites"
        echo -e "${GREEN}[07]${RESET} 👥 Usuarios Online"
        echo -e "${GREEN}[08]${RESET} ♻️ Reactivar Suspendido"
        echo -e "${RED}[00]${RESET} ↩️ Regresar"
        echo

        read -rp "➜ Opción: " OP

        case "$OP" in

            1|01)
                create_trojan_account
                ;;

            2|02)
                remove_trojan_user
                ;;

            3|03)
                list_users_by_tag "trojan-in" "👥 USUARIOS TROJAN"
                ;;

            4|04)
                show_account "trojan"
                ;;

            5|05)
                export_link "trojan"
                ;;

            6|06)
                show_xray_limits
                ;;

            7|07)
                xray_online_users
                ;;

            8|08)
                reactivate_menu
                ;;

            0|00)
                return
                ;;

            *)
                echo -e "${RED}✘ Opción inválida.${RESET}"
                sleep 1
                ;;

        esac

    done
}

# ==============================================================
# MENÚ PRINCIPAL XRAY
# ==============================================================

xray_menu() {

    while true; do

        clear

        load_domain

        local STATUS
        local VERSION_X
        local TOTAL_USERS
        local ONLINE_USERS

        if systemctl is-active --quiet xray; then
            STATUS="${GREEN}🟢 ACTIVO${RESET}"
        else
            STATUS="${RED}🔴 DETENIDO${RESET}"
        fi

        VERSION_X=$(xray version 2>/dev/null | head -1)
        [[ -z "$VERSION_X" ]] && VERSION_X="NO INSTALADO"

        TOTAL_USERS=$(jq \
            '[.inbounds[].settings.clients[]?] | length' \
            "$XRAY_CFG" 2>/dev/null)

        [[ "$TOTAL_USERS" =~ ^[0-9]+$ ]] || TOTAL_USERS=0

        ONLINE_USERS=0

        if [[ -f "$XRAY_LOG" ]]; then

            local LIMIT

            LIMIT=$(date -d "60 seconds ago" \
                "+%Y/%m/%d %H:%M:%S")

            ONLINE_USERS=$(awk -v LIM="$LIMIT" '
            /email:/ {
                DATA=$1" "$2

                if (DATA >= LIM) {
                    split($0,a,"email: ")
                    print a[2]
                }
            }
            ' "$XRAY_LOG" |
            sort -u |
            wc -l)

        fi

        mv_header \
            "🚀 KEVINTECH XRAY MANAGER" \
            "VMess · VLESS · Trojan" \
            "v$VERSION"

        echo -e "${CYAN}┌──────────────── INFORMACIÓN ────────────────────────────────┐${RESET}"
        printf " ${WHITE}Estado      :${RESET} %b\n" "$STATUS"
        printf " ${WHITE}Dominio     :${RESET} ${GREEN}%s${RESET}\n" "${DOMAIN:-NO CONFIGURADO}"
        printf " ${WHITE}Puerto      :${RESET} ${GREEN}%s${RESET}\n" "$XRAY_PORT"
        printf " ${WHITE}Protocolos  :${RESET} ${GREEN}VMess · VLESS · Trojan${RESET}\n"
        printf " ${WHITE}Paths       :${RESET} ${GREEN}/vmess /vless /trojan-ws${RESET}\n"
        printf " ${WHITE}Usuarios    :${RESET} ${GREEN}%s${RESET}\n" "$TOTAL_USERS"
        printf " ${WHITE}Online      :${RESET} ${GREEN}%s${RESET}\n" "$ONLINE_USERS"
        printf " ${WHITE}Versión     :${RESET} ${GREEN}%s${RESET}\n" "$VERSION_X"
        echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${RESET}"

        echo

        if systemctl is-active --quiet xray; then

            echo -e "${GREEN}[01]${RESET} ⚡ Gestionar VMess"
            echo -e "${GREEN}[02]${RESET} 🔰 Gestionar VLESS"
            echo -e "${GREEN}[03]${RESET} 🛡️ Gestionar Trojan"
            echo -e "${GREEN}[04]${RESET} 🔄 Reiniciar Xray"
            echo -e "${GREEN}[05]${RESET} 📊 Estado del Servicio"
            echo -e "${GREEN}[06]${RESET} 👥 Usuarios Online"
            echo -e "${GREEN}[07]${RESET} 📈 Consumo y Límites"
            echo -e "${GREEN}[08]${RESET} 🔧 Cambiar Puerto"
            echo -e "${GREEN}[09]${RESET} 🌐 Información del Servidor"
            echo -e "${GREEN}[10]${RESET} ♻️ Reactivar Suspendido"
            echo -e "${YELLOW}[11]${RESET} 🔄 Reparar / Actualizar Configuración"
            echo -e "${RED}[12]${RESET} 🗑️ Desinstalar Xray"

        else

            echo -e "${GREEN}[01]${RESET} 🚀 Instalar Xray Core"

        fi

        echo -e "${RED}[00]${RESET} ↩️ Regresar"
        echo

        read -rp "➜ Seleccione una opción: " OP

        if ! systemctl is-active --quiet xray; then

            case "$OP" in

                1|01)
                    install_xray
                    ;;

                0|00)
                    return
                    ;;

                *)
                    echo -e "${RED}✘ Opción inválida.${RESET}"
                    sleep 1
                    ;;

            esac

            continue
        fi

        case "$OP" in

            1|01)
                vmess_menu
                ;;

            2|02)
                vless_menu
                ;;

            3|03)
                trojan_menu
                ;;

            4|04)
                restart_xray
                pause_screen
                ;;

            5|05)
                xray_status
                ;;

            6|06)
                xray_online_users
                ;;

            7|07)
                show_xray_limits
                ;;

            8|08)
                change_xray_port
                ;;

            9|09)
                server_info
                ;;

            10)
                reactivate_menu
                ;;

            11)

                ensure_xray_api_config
                ensure_xray_inbounds
                ensure_xray_resilience
                ensure_haproxy_xray_ports
                ensure_haproxy_xray_backends

                systemctl restart xray

                echo
                echo -e "${GREEN}✔ Configuración reparada.${RESET}"

                pause_screen

                ;;

            12)

                remove_xray
                ;;

            0|00)

                return
                ;;

            *)

                echo -e "${RED}✘ Opción inválida.${RESET}"

                sleep 1

                ;;

        esac

    done
}

# ==============================================================
# ARGUMENTOS HEADLESS
# ==============================================================

case "${1:-}" in

    --install)

        install_xray

        exit $?
        ;;

    --check-limits)

        source "$CONFIG" 2>/dev/null || true

        check_xray_limits

        exit $?
        ;;

    --ensure-api)

        source "$CONFIG" 2>/dev/null || true

        echo -e "${CYAN}🔧 Activando API de estadísticas...${RESET}"

        if ensure_xray_api_config; then

            ensure_xray_inbounds

            systemctl restart xray 2>/dev/null

            sleep 1

            if systemctl is-active --quiet xray; then

                echo -e "${GREEN}✅ API activada correctamente.${RESET}"

                exit 0

            fi

        fi

        echo -e "${RED}❌ No se pudo activar la API.${RESET}"

        exit 1
        ;;

    --ensure-cleanup)

        ensure_xray_api_config || true
        ensure_xray_inbounds || true
        ensure_xray_resilience || true

        systemctl restart xray 2>/dev/null

        exit 0
        ;;

    --status)

        xray_status

        exit $?
        ;;

    --restart)

        restart_xray

        exit $?
        ;;

    --uninstall)

        remove_xray

        exit $?
        ;;

esac

# ==============================================================
# INICIO
# ==============================================================

xray_menu
