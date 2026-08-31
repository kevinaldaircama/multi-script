#!/bin/bash
# ==============================================================
#              KEVINTECH MULTI SCRIPT
#                 XRAY MULTI MANAGER v5.0
# ==============================================================
# Xray: VLESS / VMess / Trojan / gRPC
# HAProxy: TLS termination on 443 + routing por path
#
# Puertos internos:
# 10001 VLESS WS       /vless
# 10002 VMess WS       /vmess
# 10003 Trojan WS      /trojan-ws
# 10004 VLESS gRPC     vless-grpc
# 10005 VLESS2 WS      /vless2
# 10006 VMess2 WS      /vmess2
# 10007 Trojan2 WS     /trojan2
# 10008 VMess gRPC     vmess-grpc
#
# Config: /etc/kevintech/config.conf
# Xray:   /usr/local/etc/xray/config.json
# HAProxy:/etc/haproxy/haproxy.cfg
# ==============================================================

set -u

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"
XRAY_LOG_DIR="/var/log/xray"
XRAY_LOG="$XRAY_LOG_DIR/access.log"
XRAY_SERVICE="xray"

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
CERT_FILE="/etc/haproxy/yha.pem"

VERSION="5.0"

declare -A PORTS=(
    [vless]=10001
    [vmess]=10002
    [trojan]=10003
    [vless_grpc]=10004
    [vless2]=10005
    [vmess2]=10006
    [trojan2]=10007
    [vmess_grpc]=10008
)

declare -A TAGS=(
    [vless]=vless-ws
    [vmess]=vmess-ws
    [trojan]=trojan-ws
    [vless_grpc]=vless-grpc
    [vless2]=vless-ws-2
    [vmess2]=vmess-ws-2
    [trojan2]=trojan-ws-2
    [vmess_grpc]=vmess-grpc
)

declare -A PATHS=(
    [vless]=/vless
    [vmess]=/vmess
    [trojan]=/trojan-ws
    [vless2]=/vless2
    [vmess2]=/vmess2
    [trojan2]=/trojan2
)

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

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Debes ejecutar este script como root.${RESET}"
    exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
    echo -e "${RED}✘ No existe $CONFIG${RESET}"
    exit 1
fi

source "$CONFIG" 2>/dev/null || true

line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}          ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MULTI MANAGER${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                       ${GRAY}v$VERSION${RESET}                         ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

ok()    { echo -e "${GREEN}✔ $1${RESET}"; }
error_msg() { echo -e "${RED}✘ $1${RESET}"; }
warning() { echo -e "${YELLOW}⚠ $1${RESET}"; }
info() { echo -e "${CYAN}➜ $1${RESET}"; }

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

set_config() {
    local KEY="$1"
    local VALUE="$2"

    if grep -q "^${KEY}=" "$CONFIG"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$CONFIG"
    else
        echo "${KEY}=${VALUE}" >> "$CONFIG"
    fi
}

load_domain() {
    source "$CONFIG" 2>/dev/null || true

    DOMAIN="${SERVER_DOMAIN:-}"

    if [[ -z "$DOMAIN" && -f /etc/xray/domain ]]; then
        DOMAIN="$(tr -d '[:space:]' </etc/xray/domain)"
    fi
}

service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

xray_installed() {
    command -v xray >/dev/null 2>&1 &&
    [[ -f "$XRAY_CFG" ]]
}

backup_xray_config() {
    [[ ! -f "$XRAY_CFG" ]] && return 0

    local BACKUP_DIR="$XRAY_DIR/backups"
    local FILE

    mkdir -p "$BACKUP_DIR"

    FILE="$BACKUP_DIR/config-$(date '+%Y%m%d-%H%M%S').json"

    cp -f "$XRAY_CFG" "$FILE"
    chmod 600 "$FILE"

    echo "$FILE"
}

validate_json() {
    [[ -f "$XRAY_CFG" ]] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    jq empty "$XRAY_CFG" >/dev/null 2>&1
}

validate_xray_config() {
    if ! validate_json; then
        return 1
    fi

    if ! xray run -test -config "$XRAY_CFG" >/tmp/kevintech-xray-test.log 2>&1; then
        error_msg "Xray rechazó la configuración."

        cat /tmp/kevintech-xray-test.log

        rm -f /tmp/kevintech-xray-test.log

        return 1
    fi

    rm -f /tmp/kevintech-xray-test.log

    return 0
}

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

install_dependencies() {
    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudo actualizar APT."
        return 1
    fi

    info "Instalando dependencias..."

    if ! apt-get install -y         curl wget unzip jq socat cron ca-certificates         uuid-runtime haproxy openssl >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."
    return 0
}

install_xray_core() {
    info "Instalando Xray Core..."

    local INSTALLER="/tmp/xray-install.sh"

    rm -f "$INSTALLER"

    if ! curl -fL         "https://github.com/XTLS/Xray-install/raw/main/install-release.sh"         -o "$INSTALLER"; then

        error_msg "No se pudo descargar el instalador de Xray."
        return 1
    fi

    chmod 700 "$INSTALLER"

    if ! bash "$INSTALLER" install; then
        rm -f "$INSTALLER"
        error_msg "El instalador de Xray devolvió un error."
        return 1
    fi

    rm -f "$INSTALLER"

    command -v xray >/dev/null 2>&1
}

create_directories() {
    mkdir -p "$XRAY_DIR"
    mkdir -p "$XRAY_LOG_DIR"

    touch "$XRAY_LOG"

    chmod 755 "$XRAY_DIR"
    chmod 755 "$XRAY_LOG_DIR"
    chmod 640 "$XRAY_LOG"
}

create_base_config() {
    create_directories

    cat >"$XRAY_CFG" <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },

  "inbounds": [

    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "tag": "vless-ws",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vless"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vmess",
      "tag": "vmess-ws",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vmess"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "tag": "trojan-ws",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/trojan-ws"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vless",
      "tag": "vless-grpc",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "grpc",
        "security": "none",

        "grpcSettings": {
          "serviceName": "vless-grpc"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vless",
      "tag": "vless-ws-2",

      "settings": {
        "clients": [],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vless2"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vmess",
      "tag": "vmess-ws-2",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/vmess2"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "tag": "trojan-ws-2",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",
        "security": "none",

        "wsSettings": {
          "path": "/trojan2"
        }
      }
    },

    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "vmess",
      "tag": "vmess-grpc",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "grpc",
        "security": "none",

        "grpcSettings": {
          "serviceName": "vmess-grpc"
        }
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

ensure_xray_resilience() {
    local DIR="/etc/systemd/system/xray.service.d"
    local FILE="$DIR/10-kevintech-resilience.conf"

    mkdir -p "$DIR"

    cat >"$FILE" <<EOF
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

    ok "Resiliencia de Xray configurada."
}

generate_certificate() {
    mkdir -p /etc/haproxy

    if [[ -s "$CERT_FILE" ]]; then
        chmod 600 "$CERT_FILE"
        return 0
    fi

    load_domain

    local KEY="/tmp/kevintech_ssl_key.pem"
    local CRT="/tmp/kevintech_ssl_cert.pem"

    rm -f "$KEY" "$CRT"

    info "Generando certificado TLS..."

    if ! openssl req         -x509         -nodes         -newkey rsa:2048         -days 3650         -keyout "$KEY"         -out "$CRT"         -subj "/CN=${DOMAIN:-ssl-tunnel}"         >/dev/null 2>&1; then

        rm -f "$KEY" "$CRT"
        return 1
    fi

    cat "$KEY" "$CRT" >"$CERT_FILE"

    rm -f "$KEY" "$CRT"

    chmod 600 "$CERT_FILE"

    [[ -s "$CERT_FILE" ]]
}

create_haproxy_config() {
    mkdir -p /etc/haproxy

    cat >"$HAPROXY_CFG" <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice

    stats socket /run/haproxy/admin.sock mode 660 level admin

    user haproxy
    group haproxy

    daemon

    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    ssl-default-bind-alpn h2,http/1.1


defaults
    log global
    mode http

    option httplog
    option dontlognull

    timeout connect 5s
    timeout client 24h
    timeout server 24h
    timeout tunnel 24h


frontend xray_tls
    mode http

    bind *:443 ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1

    acl path_vless       path_beg /vless
    acl path_vmess       path_beg /vmess
    acl path_trojan      path_beg /trojan-ws

    acl path_vless2      path_beg /vless2
    acl path_vmess2      path_beg /vmess2
    acl path_trojan2     path_beg /trojan2

    acl path_vless_grpc  path_beg /vless-grpc
    acl path_vmess_grpc  path_beg /vmess-grpc

    use_backend be_vless_grpc  if path_vless_grpc
    use_backend be_vmess_grpc  if path_vmess_grpc

    use_backend be_vless2      if path_vless2
    use_backend be_vmess2      if path_vmess2
    use_backend be_trojan2     if path_trojan2

    use_backend be_trojan      if path_trojan
    use_backend be_vless       if path_vless
    use_backend be_vmess       if path_vmess

    default_backend be_vmess


backend be_vless
    mode http
    server xray_vless 127.0.0.1:10001 check


backend be_vmess
    mode http
    server xray_vmess 127.0.0.1:10002 check


backend be_trojan
    mode http
    server xray_trojan 127.0.0.1:10003 check


backend be_vless_grpc
    mode http
    server xray_vless_grpc 127.0.0.1:10004 proto h2 check


backend be_vless2
    mode http
    server xray_vless2 127.0.0.1:10005 check


backend be_vmess2
    mode http
    server xray_vmess2 127.0.0.1:10006 check


backend be_trojan2
    mode http
    server xray_trojan2 127.0.0.1:10007 check


backend be_vmess_grpc
    mode http
    server xray_vmess_grpc 127.0.0.1:10008 proto h2 check


frontend xray_http
    mode http
    bind *:80

    http-request redirect scheme https code 301


frontend xray_alt
    mode http
    bind *:8080

    default_backend be_vmess
EOF

    haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1
}

restart_xray() {
    systemctl restart "$XRAY_SERVICE"
    sleep 2

    if service_active "$XRAY_SERVICE"; then
        set_config "XRAY" "ON"
        return 0
    fi

    set_config "XRAY" "OFF"
    return 1
}

install_stack() {
    header

    echo -e "${WHITE}${BOLD}       INSTALACIÓN XRAY + HAProxy${RESET}"
    line
    echo

    install_dependencies || {
        error_msg "Falló la instalación de dependencias."
        pause
        return 1
    }

    install_xray_core || {
        error_msg "Falló la instalación de Xray."
        pause
        return 1
    }

    create_directories

    if [[ ! -f "$XRAY_CFG" ]] || ! validate_json; then
        info "Creando configuración multi-protocolo..."
        create_base_config || {
            error_msg "No se pudo crear config.json."
            pause
            return 1
        }
    else
        ok "Configuración Xray existente conservada."
    fi

    if ! validate_xray_config; then
        error_msg "Xray rechazó config.json."
        pause
        return 1
    fi

    ensure_xray_resilience

    load_domain

    if [[ -z "$DOMAIN" ]]; then
        warning "SERVER_DOMAIN no está configurado."
        warning "Los enlaces se generarán con localhost hasta configurarlo."
    fi

    generate_certificate || {
        error_msg "No se pudo generar el certificado TLS."
        pause
        return 1
    }

    create_haproxy_config || {
        error_msg "HAProxy rechazó su configuración."
        haproxy -c -f "$HAPROXY_CFG"
        pause
        return 1
    }

    systemctl enable haproxy >/dev/null 2>&1

    restart_xray || {
        error_msg "Xray no pudo iniciar."
        journalctl -u xray -n 20 --no-pager
        pause
        return 1
    }

    systemctl restart haproxy
    sleep 2

    if ! service_active haproxy; then
        error_msg "HAProxy no pudo iniciar."
        journalctl -u haproxy -n 20 --no-pager
        pause
        return 1
    fi

    set_config "XRAY" "ON"
    set_config "SSL_TUNNEL" "ON"

    echo
    ok "XRAY MULTI + HAProxy instalados correctamente."

    echo
    echo -e "${WHITE}Dominio:${RESET} ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"
    echo -e "${WHITE}TLS público:${RESET} ${GREEN}:443${RESET}"

    echo
    echo -e "${GREEN}Puertos internos:${RESET}"

    for p in 10001 10002 10003 10004 10005 10006 10007 10008; do
        echo "  $p"
    done

    pause
}

find_tag() {
    case "$1" in
        vless) echo "vless-ws" ;;
        vmess) echo "vmess-ws" ;;
        trojan) echo "trojan-ws" ;;
        vless_grpc) echo "vless-grpc" ;;
        vless2) echo "vless-ws-2" ;;
        vmess2) echo "vmess-ws-2" ;;
        trojan2) echo "trojan-ws-2" ;;
        vmess_grpc) echo "vmess-grpc" ;;
        *) return 1 ;;
    esac
}

proto_from_num() {
    case "$1" in
        1) echo "vless" ;;
        2) echo "vmess" ;;
        3) echo "trojan" ;;
        4) echo "vless_grpc" ;;
        5) echo "vless2" ;;
        6) echo "vmess2" ;;
        7) echo "trojan2" ;;
        8) echo "vmess_grpc" ;;
        *) return 1 ;;
    esac
}

proto_menu() {
    echo -e "${GREEN}[1]${RESET} VLESS WS       → 10001 /vless"
    echo -e "${GREEN}[2]${RESET} VMess WS       → 10002 /vmess"
    echo -e "${GREEN}[3]${RESET} Trojan WS      → 10003 /trojan-ws"
    echo -e "${GREEN}[4]${RESET} VLESS gRPC     → 10004 vless-grpc"
    echo -e "${GREEN}[5]${RESET} VLESS2 WS      → 10005 /vless2"
    echo -e "${GREEN}[6]${RESET} VMess2 WS      → 10006 /vmess2"
    echo -e "${GREEN}[7]${RESET} Trojan2 WS     → 10007 /trojan2"
    echo -e "${GREEN}[8]${RESET} VMess gRPC     → 10008 vmess-grpc"
}

client_exists() {
    local TAG="$1"
    local USER="$2"

    jq -e         --arg t "$TAG"         --arg u "$USER"         '
        .inbounds[]
        | select(.tag == $t)
        | .settings.clients[]?
        | select((.email // .password) == $u)
        ' "$XRAY_CFG" >/dev/null 2>&1
}

get_client_credential() {
    local TAG="$1"
    local USER="$2"

    jq -r         --arg t "$TAG"         --arg u "$USER"         '
        .inbounds[]
        | select(.tag == $t)
        | .settings.clients[]?
        | select((.email // .password) == $u)
        | (.id // .password // empty)
        ' "$XRAY_CFG" 2>/dev/null
}

add_client() {
    local PROTO="$1"
    local USER="$2"
    local CRED="$3"

    local TAG
    TAG="$(find_tag "$PROTO")"

    if [[ "$PROTO" == "trojan" || "$PROTO" == "trojan2" ]]; then

        jq             --arg t "$TAG"             --arg p "$CRED"             --arg e "$USER"             '
            (.inbounds[] | select(.tag == $t) | .settings.clients)
            += [{
                "password": $p,
                "email": $e,
                "level": 0
            }]
            ' "$XRAY_CFG" >"$XRAY_CFG.tmp"

    else

        jq             --arg t "$TAG"             --arg id "$CRED"             --arg e "$USER"             '
            (.inbounds[] | select(.tag == $t) | .settings.clients)
            += [{
                "id": $id,
                "email": $e,
                "level": 0
            }]
            ' "$XRAY_CFG" >"$XRAY_CFG.tmp"
    fi

    mv "$XRAY_CFG.tmp" "$XRAY_CFG"
    chmod 600 "$XRAY_CFG"
}

urlencode_path() {
    printf '%s' "$1" |
        sed 's|/|%2F|g; s| |%20|g'
}

generate_link() {
    local PROTO="$1"
    local USER="$2"
    local CRED="$3"

    load_domain

    local D="${DOMAIN:-localhost}"

    case "$PROTO" in

        vless|vless2)

            echo             "vless://${CRED}@${D}:443?encryption=none&security=tls&type=ws&host=${D}&path=$(urlencode_path "${PATHS[$PROTO]}")&sni=${D}#${USER}"

            ;;

        vmess|vmess2)

            printf             '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls","sni":"%s"}'             "$USER"             "$D"             "$CRED"             "$D"             "${PATHS[$PROTO]}"             "$D" |
            base64 -w 0 |
            sed 's/^/vmess:\/\//'

            ;;

        trojan|trojan2)

            echo             "trojan://${CRED}@${D}:443?security=tls&type=ws&host=${D}&path=$(urlencode_path "${PATHS[$PROTO]}")&sni=${D}#${USER}"

            ;;

        vless_grpc)

            echo             "vless://${CRED}@${D}:443?encryption=none&security=tls&type=grpc&serviceName=vless-grpc&sni=${D}#${USER}"

            ;;

        vmess_grpc)

            printf             '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"grpc","type":"none","host":"%s","path":"","tls":"tls","sni":"%s","serviceName":"vmess-grpc"}'             "$USER"             "$D"             "$CRED"             "$D"             "$D" |
            base64 -w 0 |
            sed 's/^/vmess:\/\//'

            ;;

    esac
}

show_created_account() {
    local PROTO="$1"
    local USER="$2"
    local CRED="$3"

    load_domain

    header

    echo -e "${GREEN}${BOLD}🎉 CUENTA CREADA${RESET}"
    line

    echo -e "👤 Usuario      : ${WHITE}$USER${RESET}"
    echo -e "🔐 Protocolo    : ${GREEN}$PROTO${RESET}"
    echo -e "🆔 Credencial   : ${YELLOW}$CRED${RESET}"
    echo -e "🌐 Dominio      : ${GREEN}${DOMAIN:-localhost}${RESET}"
    echo -e "🔒 TLS          : ${GREEN}Activado${RESET}"
    echo -e "🚪 Puerto       : ${GREEN}443${RESET}"
    echo -e "🎯 Puerto interno: ${GREEN}${PORTS[$PROTO]}${RESET}"

    echo
    line

    echo -e "${YELLOW}${BOLD}🔗 LINK${RESET}"
    echo

    generate_link "$PROTO" "$USER" "$CRED"

    pause
}

create_account() {
    if ! xray_installed; then
        error_msg "Xray no está instalado."
        pause
        return
    fi

    load_domain

    header

    echo -e "${WHITE}${BOLD}👤 CREAR CUENTA${RESET}"
    line
    echo

    proto_menu

    echo

    read -rp "➜ Protocolo [1-8]: " OPTION

    local PROTO
    PROTO="$(proto_from_num "$OPTION")" || {
        error_msg "Opción inválida."
        pause
        return
    }

    echo

    read -rp "👤 Nombre de usuario: " USER

    USER="$(echo "$USER" | xargs)"

    if [[ ! "$USER" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        error_msg "Nombre de usuario inválido."
        pause
        return
    fi

    local TAG
    TAG="$(find_tag "$PROTO")"

    if client_exists "$TAG" "$USER"; then
        error_msg "La cuenta '$USER' ya existe en $PROTO."
        pause
        return
    fi

    local CRED

    CRED="$(generate_uuid)" || {
        pause
        return
    }

    if [[ "$PROTO" == "trojan" || "$PROTO" == "trojan2" ]]; then
        CRED="$(echo "$CRED" | tr -d '-')"
    fi

    local BACKUP
    BACKUP="$(backup_xray_config)"

    if ! add_client "$PROTO" "$USER" "$CRED"; then
        error_msg "No se pudo modificar config.json."
        pause
        return
    fi

    if ! validate_xray_config; then

        if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
            cp -f "$BACKUP" "$XRAY_CFG"
        fi

        error_msg "La configuración fue rechazada."
        pause
        return
    fi

    if ! restart_xray; then

        if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
            cp -f "$BACKUP" "$XRAY_CFG"
            systemctl restart "$XRAY_SERVICE"
        fi

        error_msg "Xray no inició. Backup restaurado."
        pause
        return
    fi

    show_created_account "$PROTO" "$USER" "$CRED"
}

list_accounts() {
    if ! xray_installed; then
        error_msg "Xray no está instalado."
        pause
        return
    fi

    header

    echo -e "${WHITE}${BOLD}📋 CUENTAS XRAY${RESET}"
    line

    local TOTAL=0

    printf "%-4s %-22s %-16s %-40s\n" "#" "USUARIO" "PROTOCOLO" "CREDENCIAL"
    echo "────────────────────────────────────────────────────────────────────────────"

    for PROTO in         vless vmess trojan vless_grpc         vless2 vmess2 trojan2 vmess_grpc; do

        local TAG
        TAG="$(find_tag "$PROTO")"

        while IFS=$'	' read -r USER CRED; do

            [[ -z "$USER" ]] && continue

            TOTAL=$((TOTAL + 1))

            printf             "%-4s %-22s %-16s %-40s\n"             "$TOTAL"             "$USER"             "$PROTO"             "$CRED"

        done < <(
            jq -r             --arg t "$TAG"             '
            .inbounds[]
            | select(.tag == $t)
            | .settings.clients[]?
            | [(.email // ""), (.id // .password // "")]
            | @tsv
            ' "$XRAY_CFG"
        )
    done

    echo

    echo -e "${WHITE}Total de cuentas:${RESET} ${GREEN}$TOTAL${RESET}"

    pause
}

show_account() {
    if ! xray_installed; then
        error_msg "Xray no está instalado."
        pause
        return
    fi

    load_domain

    header

    echo -e "${WHITE}${BOLD}📄 VER CUENTA${RESET}"
    line

    read -rp "👤 Usuario: " USER

    USER="$(echo "$USER" | xargs)"

    [[ -n "$USER" ]] || return

    local FOUND=0

    for PROTO in         vless vmess trojan vless_grpc         vless2 vmess2 trojan2 vmess_grpc; do

        [[ "$PROTO" == "vmess_grcp" ]] && PROTO="vmess_grpc"

        local TAG
        TAG="$(find_tag "$PROTO")"

        if client_exists "$TAG" "$USER"; then

            FOUND=1

            local CRED
            CRED="$(get_client_credential "$TAG" "$USER")"

            echo
            echo -e "${CYAN}──────────────────────────────────────────────────────────────${RESET}"
            echo -e "👤 Usuario       : ${WHITE}$USER${RESET}"
            echo -e "🔐 Protocolo     : ${GREEN}$PROTO${RESET}"
            echo -e "🆔 Credencial    : ${YELLOW}$CRED${RESET}"
            echo -e "🌐 Dominio       : ${GREEN}${DOMAIN:-localhost}${RESET}"
            echo -e "🚪 Puerto público: ${GREEN}443${RESET}"
            echo -e "🎯 Puerto interno: ${GREEN}${PORTS[$PROTO]}${RESET}"
            echo -e "🔒 TLS           : ${GREEN}Activado${RESET}"
            echo
            echo -e "${YELLOW}🔗 LINK:${RESET}"
            generate_link "$PROTO" "$USER" "$CRED"
        fi
    done

    if [[ "$FOUND" -eq 0 ]]; then
        error_msg "Usuario no encontrado."
    fi

    pause
}

edit_account() {
    if ! xray_installed; then
        error_msg "Xray no está instalado."
        pause
        return
    fi

    header

    echo -e "${WHITE}${BOLD}✏️ EDITAR CUENTA${RESET}"
    line

    read -rp "👤 Usuario actual: " USER
    USER="$(echo "$USER" | xargs)"

    [[ -n "$USER" ]] || return

    local PROTO=""
    local TAG=""

    for P in         vless vmess trojan vless_grpc         vless2 vmess2 trojan2 vmess_grpc; do

        local T
        T="$(find_tag "$P")"

        if client_exists "$T" "$USER"; then
            PROTO="$P"
            TAG="$T"
            break
        fi
    done

    if [[ -z "$PROTO" ]]; then
        error_msg "Cuenta no encontrada."
        pause
        return
    fi

    local BACKUP
    BACKUP="$(backup_xray_config)"

    echo
    echo -e "${WHITE}Cuenta encontrada:${RESET}"
    echo -e "Usuario   : ${GREEN}$USER${RESET}"
    echo -e "Protocolo : ${GREEN}$PROTO${RESET}"
    echo

    echo "[1] Cambiar nombre"
    echo "[2] Regenerar credencial"
    echo "[3] Cambiar protocolo"
    echo "[0] Cancelar"

    echo

    read -rp "➜ Opción: " OPTION

    case "$OPTION" in

        1)

            read -rp "Nuevo nombre: " NEW_USER
            NEW_USER="$(echo "$NEW_USER" | xargs)"

            if [[ ! "$NEW_USER" =~ ^[A-Za-z0-9_.-]+$ ]]; then
                error_msg "Nombre inválido."
                pause
                return
            fi

            if client_exists "$TAG" "$NEW_USER"; then
                error_msg "El nuevo nombre ya existe."
                pause
                return
            fi

            jq                 --arg t "$TAG"                 --arg old "$USER"                 --arg new "$NEW_USER"                 '
                .inbounds |= map(
                    if .tag == $t then
                        .settings.clients |= map(
                            if (.email // .password) == $old
                            then .email = $new
                            else .
                            end
                        )
                    else .
                    end
                )
                ' "$XRAY_CFG" >"$XRAY_CFG.tmp"

            USER="$NEW_USER"
            ;;

        2)

            local NEW_CRED
            NEW_CRED="$(generate_uuid)"

            if [[ "$PROTO" == "trojan" || "$PROTO" == "trojan2" ]]; then
                NEW_CRED="$(echo "$NEW_CRED" | tr -d '-')"

                jq                     --arg t "$TAG"                     --arg u "$USER"                     --arg c "$NEW_CRED"                     '
                    .inbounds |= map(
                        if .tag == $t then
                            .settings.clients |= map(
                                if (.email // .password) == $u
                                then .password = $c
                                else .
                                end
                            )
                        else .
                        end
                    )
                    ' "$XRAY_CFG" >"$XRAY_CFG.tmp"

            else

                jq                     --arg t "$TAG"                     --arg u "$USER"                     --arg c "$NEW_CRED"                     '
                    .inbounds |= map(
                        if .tag == $t then
                            .settings.clients |= map(
                                if (.email // .password) == $u
                                then .id = $c
                                else .
                                end
                            )
                        else .
                        end
                    )
                    ' "$XRAY_CFG" >"$XRAY_CFG.tmp"
            fi

            ;;

        3)

            echo
            proto_menu
            echo

            read -rp "➜ Nuevo protocolo [1-8]: " OPTION2

            local NEW_PROTO
            NEW_PROTO="$(proto_from_num "$OPTION2")" || {
                error_msg "Protocolo inválido."
                pause
                return
            }

            local NEW_TAG
            NEW_TAG="$(find_tag "$NEW_PROTO")"

            if [[ "$NEW_TAG" == "$TAG" ]]; then
                warning "La cuenta ya está en ese protocolo."
                pause
                return
            fi

            if client_exists "$NEW_TAG" "$USER"; then
                error_msg "Ya existe una cuenta con ese nombre en el nuevo protocolo."
                pause
                return
            fi

            local NEW_CRED
            NEW_CRED="$(generate_uuid)"

            if [[ "$NEW_PROTO" == "trojan" || "$NEW_PROTO" == "trojan2" ]]; then
                NEW_CRED="$(echo "$NEW_CRED" | tr -d '-')"
            fi

            jq                 --arg oldtag "$TAG"                 --arg newtag "$NEW_TAG"                 --arg user "$USER"                 --arg cred "$NEW_CRED"                 --arg proto "$NEW_PROTO"                 '
                .inbounds |= map(
                    if .tag == $oldtag then
                        .settings.clients |= map(
                            select((.email // .password) != $user)
                        )
                    elif .tag == $newtag then
                        .settings.clients += [
                            if ($proto == "trojan" or $proto == "trojan2")
                            then {
                                "password": $cred,
                                "email": $user,
                                "level": 0
                            }
                            else {
                                "id": $cred,
                                "email": $user,
                                "level": 0
                            }
                            end
                        ]
                    else .
                    end
                )
                ' "$XRAY_CFG" >"$XRAY_CFG.tmp"

            PROTO="$NEW_PROTO"
            TAG="$NEW_TAG"

            ;;

        0)
            warning "Operación cancelada."
            pause
            return
            ;;

        *)
            error_msg "Opción inválida."
            pause
            return
            ;;
    esac

    if [[ ! -s "$XRAY_CFG.tmp" ]]; then
        error_msg "No se pudo generar la nueva configuración."
        pause
        return
    fi

    mv "$XRAY_CFG.tmp" "$XRAY_CFG"
    chmod 600 "$XRAY_CFG"

    if ! validate_xray_config; then

        if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
            cp -f "$BACKUP" "$XRAY_CFG"
        fi

        error_msg "Xray rechazó el cambio."
        pause
        return
    fi

    if ! restart_xray; then

        if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
            cp -f "$BACKUP" "$XRAY_CFG"
            systemctl restart "$XRAY_SERVICE"
        fi

        error_msg "Xray no inició. Backup restaurado."
        pause
        return
    fi

    ok "Cuenta actualizada correctamente."

    pause
}

delete_account() {
    if ! xray_installed; then
        error_msg "Xray no está instalado."
        pause
        return
    fi

    header

    echo -e "${WHITE}${BOLD}🗑️ ELIMINAR CUENTA${RESET}"
    line

    read -rp "👤 Usuario: " USER
    USER="$(echo "$USER" | xargs)"

    [[ -n "$USER" ]] || return

    local FOUND=0

    for PROTO in         vless vmess trojan vless_grpc         vless2 vmess2 trojan2 vmess_grpc; do

        [[ "$PROTO" == "vmess_grcp" ]] && PROTO="vmess_grpc"

        local TAG
        TAG="$(find_tag "$PROTO")"

        if client_exists "$TAG" "$USER"; then
            FOUND=1
        fi
    done

    if [[ "$FOUND" -eq 0 ]]; then
        error_msg "Usuario no encontrado."
        pause
        return
    fi

    echo
    read -rp         "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")"         CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then
        warning "Operación cancelada."
        pause
        return
    fi

    local BACKUP
    BACKUP="$(backup_xray_config)"

    jq         --arg u "$USER"         '
        .inbounds |= map(
            .settings.clients |= map(
                select((.email // .password) != $u)
            )
        )
        ' "$XRAY_CFG" >"$XRAY_CFG.tmp"

    if [[ ! -s "$XRAY_CFG.tmp" ]]; then
        error_msg "No se pudo modificar config.json."
        pause
        return
    fi

    mv "$XRAY_CFG.tmp" "$XRAY_CFG"
    chmod 600 "$XRAY_CFG"

    if ! validate_xray_config; then

        [[ -n "$BACKUP" && -f "$BACKUP" ]] &&
            cp -f "$BACKUP" "$XRAY_CFG"

        error_msg "Configuración inválida."
        pause
        return
    fi

    if ! restart_xray; then

        if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
            cp -f "$BACKUP" "$XRAY_CFG"
            systemctl restart "$XRAY_SERVICE"
        fi

        error_msg "Xray no inició. Backup restaurado."
        pause
        return
    fi

    ok "Cuenta '$USER' eliminada."

    pause
}

xray_status() {
    header

    load_domain

    echo -e "${WHITE}${BOLD}📊 ESTADO DEL SISTEMA${RESET}"
    line

    if service_active "$XRAY_SERVICE"; then
        echo -e "Xray       : ${GREEN}🟢 ACTIVO${RESET}"
    else
        echo -e "Xray       : ${RED}🔴 DETENIDO${RESET}"
    fi

    if service_active "haproxy"; then
        echo -e "HAProxy    : ${GREEN}🟢 ACTIVO${RESET}"
    else
        echo -e "HAProxy    : ${RED}🔴 DETENIDO${RESET}"
    fi

    echo
    echo -e "Dominio    : ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"
    echo -e "TLS público: ${GREEN}:443${RESET}"

    echo
    echo -e "${WHITE}Inbounds:${RESET}"

    for PROTO in         vless vmess trojan vless_grpc         vless2 vmess2 trojan2 vmess_grpc; do

        local P
        P="${PORTS[$PROTO]}"

        if ss -H -lnt 2>/dev/null |
            awk -v X=":$P" '$4 ~ X"$" {found=1} END{exit !found}'; then

            echo -e "  $P  ${GREEN}● ESCUCHANDO${RESET}  $PROTO"

        else

            echo -e "  $P  ${RED}● CERRADO${RESET}     $PROTO"
        fi
    done

    pause
}

diagnostic() {
    header

    echo -e "${WHITE}${BOLD}🔎 DIAGNÓSTICO${RESET}"
    line

    command -v xray >/dev/null 2>&1 &&
        ok "Xray instalado" ||
        error_msg "Xray no instalado"

    command -v jq >/dev/null 2>&1 &&
        ok "jq disponible" ||
        error_msg "jq no disponible"

    command -v haproxy >/dev/null 2>&1 &&
        ok "HAProxy instalado" ||
        error_msg "HAProxy no instalado"

    [[ -f "$XRAY_CFG" ]] &&
        ok "config.json encontrado" ||
        error_msg "config.json no encontrado"

    [[ -s "$CERT_FILE" ]] &&
        ok "Certificado TLS encontrado" ||
        error_msg "Certificado TLS no encontrado"

    echo

    if [[ -f "$XRAY_CFG" ]]; then
        validate_xray_config &&
            ok "Xray acepta la configuración" ||
            error_msg "Xray rechaza la configuración"
    fi

    if [[ -f "$HAPROXY_CFG" ]]; then
        haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1 &&
            ok "HAProxy acepta la configuración" ||
            error_msg "HAProxy rechaza la configuración"
    fi

    service_active "$XRAY_SERVICE" &&
        ok "Servicio Xray activo" ||
        error_msg "Servicio Xray detenido"

    service_active "haproxy" &&
        ok "Servicio HAProxy activo" ||
        error_msg "Servicio HAProxy detenido"

    echo
    echo -e "${WHITE}Últimos registros Xray:${RESET}"

    journalctl         -u "$XRAY_SERVICE"         -n 15         --no-pager 2>/dev/null

    pause
}

show_logs() {
    header

    echo -e "${WHITE}${BOLD}📜 LOGS${RESET}"
    line

    echo -e "${WHITE}Xray:${RESET}"

    journalctl         -u "$XRAY_SERVICE"         -n 25         --no-pager 2>/dev/null

    echo
    echo -e "${WHITE}HAProxy:${RESET}"

    journalctl         -u haproxy         -n 20         --no-pager 2>/dev/null

    echo

    if [[ -f "$XRAY_LOG" ]]; then
        echo -e "${WHITE}access.log:${RESET}"
        tail -n 20 "$XRAY_LOG"
    fi

    pause
}

restart_services() {
    header

    info "Validando Xray..."

    if ! validate_xray_config; then
        error_msg "No se reiniciará Xray porque la configuración es inválida."
        pause
        return
    fi

    info "Reiniciando Xray..."

    restart_xray || {
        error_msg "Xray no pudo iniciar."
        journalctl -u xray -n 20 --no-pager
        pause
        return
    }

    info "Validando HAProxy..."

    if ! haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
        error_msg "HAProxy tiene una configuración inválida."
        pause
        return
    fi

    systemctl restart haproxy
    sleep 2

    if service_active haproxy; then
        set_config "SSL_TUNNEL" "ON"
        ok "Xray y HAProxy reiniciados."
    else
        error_msg "HAProxy no pudo iniciar."
    fi

    pause
}

uninstall_stack() {
    header

    warning "Se eliminarán Xray, HAProxy y sus configuraciones creadas."
    warning "Se realizará un backup de config.json antes de eliminarlo."

    echo

    read -rp         "$(echo -e "${RED}Escribe ELIMINAR para continuar: ${RESET}")"         CONFIRM

    [[ "$CONFIRM" == "ELIMINAR" ]] || {
        warning "Operación cancelada."
        pause
        return
    }

    backup_xray_config >/dev/null 2>&1 || true

    systemctl stop "$XRAY_SERVICE" haproxy 2>/dev/null || true
    systemctl disable "$XRAY_SERVICE" haproxy 2>/dev/null || true

    rm -rf "$XRAY_DIR"
    rm -rf "$XRAY_LOG_DIR"

    rm -rf /etc/systemd/system/xray.service.d

    rm -f "$HAPROXY_CFG"
    rm -f "$CERT_FILE"

    systemctl daemon-reload
    systemctl reset-failed xray haproxy 2>/dev/null || true

    set_config "XRAY" "OFF"
    set_config "SSL_TUNNEL" "OFF"

    ok "Configuraciones eliminadas."
    warning "Los paquetes xray/haproxy no se desinstalan."

    pause
}

xray_menu() {
    while true; do

        source "$CONFIG" 2>/dev/null || true
        load_domain

        clear

        local STATUS_XRAY
        local STATUS_HAPROXY

        if service_active "$XRAY_SERVICE"; then
            STATUS_XRAY="${GREEN}🟢 ACTIVO${RESET}"
        else
            STATUS_XRAY="${RED}🔴 DETENIDO${RESET}"
        fi

        if service_active "haproxy"; then
            STATUS_HAPROXY="${GREEN}🟢 ACTIVO${RESET}"
        else
            STATUS_HAPROXY="${RED}🔴 DETENIDO${RESET}"
        fi

        local TOTAL=0

        if [[ -f "$XRAY_CFG" ]]; then
            TOTAL="$(
                jq '
                [
                    .inbounds[].settings.clients[]?
                ] | length
                ' "$XRAY_CFG" 2>/dev/null
            )"
        fi

        TOTAL="${TOTAL:-0}"

        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}          ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY MULTI MANAGER${RESET}              ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}                       ${GRAY}v$VERSION${RESET}                         ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e "${WHITE}Xray:${RESET}        $STATUS_XRAY"
        echo -e "${WHITE}HAProxy:${RESET}     $STATUS_HAPROXY"
        echo -e "${WHITE}Dominio:${RESET}     ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"
        echo -e "${WHITE}TLS público:${RESET} ${GREEN}:443${RESET}"
        echo -e "${WHITE}Cuentas:${RESET}     ${GREEN}$TOTAL${RESET}"

        line

        echo -e "${BLUE}${BOLD}  👥 GESTIÓN DE CUENTAS${RESET}"
        echo

        echo -e "  ${GREEN}[01]${RESET} 👤 Crear cuenta"
        echo -e "  ${GREEN}[02]${RESET} ✏️  Editar cuenta"
        echo -e "  ${GREEN}[03]${RESET} 📋 Ver cuentas"
        echo -e "  ${RED}[04]${RESET} 🗑️  Eliminar cuenta"

        echo

        echo -e "${BLUE}${BOLD}  ⚙️ SERVICIO${RESET}"
        echo

        echo -e "  ${GREEN}[05]${RESET} 📊 Estado"
        echo -e "  ${GREEN}[06]${RESET} 🔎 Diagnóstico"
        echo -e "  ${GREEN}[07]${RESET} 📜 Logs"
        echo -e "  ${GREEN}[08]${RESET} ♻️  Reiniciar"
        echo -e "  ${GREEN}[09]${RESET} 🔄 Reinstalar / Actualizar"
        echo -e "  ${RED}[10]${RESET} 🗑️  Desinstalar"

        echo
        echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
        echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Regresar"

        echo

        read -rp             "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")"             OP

        case "$OP" in

            1)
                create_account
                ;;

            2)
                edit_account
                ;;

            3)
                list_accounts
                ;;

            4)
                delete_account
                ;;

            5)
                xray_status
                ;;

            6)
                diagnostic
                ;;

            7)
                show_logs
                ;;

            8)
                restart_services
                ;;

            9)
                install_stack
                ;;

            10)
                uninstall_stack
                ;;

            0)
                clear
                exec bash "$BASE/protocolos/menu.sh"
                ;;

            *)
                error_msg "Opción inválida."
                sleep 1
                ;;
        esac
    done
}

if [[ "${1:-}" == "--auto" ]]; then
    install_stack
    exit $?
fi

xray_menu
