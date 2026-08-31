#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    XRAY SSL MANAGER v5.0
# ==============================================================
#
# Arquitectura:
#
# INTERNET
#    │
#    ├── :80
#    ├── :443  ← HAProxy TLS
#    └── :8080
#          │
#          ▼
#       HAProxy
#          │
#          ├── /vless       → 10001
#          ├── /vmess       → 10002
#          ├── /trojan-ws   → 10003
#          ├── vless-grpc   → 10004
#          ├── /vless2      → 10005
#          ├── /vmess2      → 10006
#          ├── /trojan2     → 10007
#          └── vmess-grpc   → 10008
#
# Xray escucha SOLO en 127.0.0.1.
#
# TLS:
#   HAProxy
#
# Xray:
#   HTTP / WebSocket / gRPC interno
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

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
HAPROXY_CERT="/etc/haproxy/yha.pem"

HAPROXY_SERVICE="haproxy"

VERSION="5.0"

# ==============================================================
# PUERTOS INTERNOS XRAY
# ==============================================================

VLESS_PORT="10001"
VMESS_PORT="10002"
TROJAN_PORT="10003"
VLESS_GRPC_PORT="10004"

VLESS2_PORT="10005"
VMESS2_PORT="10006"
TROJAN2_PORT="10007"
VMESS_GRPC_PORT="10008"

# ==============================================================
# RUTAS
# ==============================================================

VLESS_PATH="/vless"
VMESS_PATH="/vmess"
TROJAN_PATH="/trojan-ws"

VLESS2_PATH="/vless2"
VMESS2_PATH="/vmess2"
TROJAN2_PATH="/trojan2"

VLESS_GRPC_SERVICE="vless-grpc"
VMESS_GRPC_SERVICE="vmess-grpc"

# ==============================================================
# PUERTOS PUBLICOS
# ==============================================================

PUBLIC_HTTP="80"
PUBLIC_HTTPS="443"
PUBLIC_ALT="8080"

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

    echo
    echo -e "${RED}${BOLD}✘ Este script requiere ROOT.${RESET}"
    echo
    exit 1

fi

# ==============================================================
# CONFIG
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then

    echo
    echo -e "${RED}✘ No existe:${RESET} $CONFIG"
    echo
    exit 1

fi

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
        "${CYAN}║${RESET}            ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY SSL MANAGER${RESET}             ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"

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

    source "$CONFIG" 2>/dev/null

    DOMAIN="${SERVER_DOMAIN:-}"

    if [[ -z "$DOMAIN" &&
          -f /etc/xray/domain ]]; then

        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)

    fi

}

# ==============================================================
# SERVICIO
# ==============================================================

xray_active() {

    systemctl is-active \
        --quiet "$XRAY_SERVICE" 2>/dev/null

}

haproxy_active() {

    systemctl is-active \
        --quiet "$HAPROXY_SERVICE" 2>/dev/null

}

# ==============================================================
# XRAY INSTALADO
# ==============================================================

xray_installed() {

    command -v xray >/dev/null 2>&1 &&
        [[ -f "$XRAY_CFG" ]]

}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    info "Actualizando repositorios..."

    apt-get update -y >/dev/null 2>&1 || {

        error_msg "APT no pudo actualizarse."

        return 1

    }

    info "Instalando dependencias..."

    apt-get install -y \
        curl \
        wget \
        unzip \
        jq \
        openssl \
        haproxy \
        ca-certificates \
        uuid-runtime \
        >/dev/null 2>&1 || {

        error_msg "No se pudieron instalar las dependencias."

        return 1

    }

    ok "Dependencias instaladas."

}

# ==============================================================
# UUID
# ==============================================================

generate_uuid() {

    if [[ -r /proc/sys/kernel/random/uuid ]]; then

        cat /proc/sys/kernel/random/uuid

        return

    fi

    if command -v uuidgen >/dev/null 2>&1; then

        uuidgen

        return

    fi

    error_msg "No se pudo generar UUID."

    return 1

}

# ==============================================================
# BACKUP XRAY
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

    jq empty "$XRAY_CFG" \
        >/dev/null 2>&1

}

# ==============================================================
# VALIDAR XRAY
# ==============================================================

validate_xray_config() {

    [[ -f "$XRAY_CFG" ]] || {

        error_msg "No existe config.json."

        return 1

    }

    if ! validate_json; then

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
# INSTALAR XRAY CORE
# ==============================================================

install_xray_core() {

    if command -v xray >/dev/null 2>&1; then

        ok "Xray Core ya está instalado."

        return 0

    fi

    info "Descargando instalador oficial de Xray..."

    local INSTALLER="/tmp/xray-install.sh"

    rm -f "$INSTALLER"

    curl -fL \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        -o "$INSTALLER" || {

        error_msg "No se pudo descargar Xray."

        return 1

    }

    chmod 700 "$INSTALLER"

    bash "$INSTALLER" install || {

        error_msg "La instalación de Xray falló."

        rm -f "$INSTALLER"

        return 1

    }

    rm -f "$INSTALLER"

    command -v xray >/dev/null 2>&1 || {

        error_msg "Xray no quedó instalado."

        return 1

    }

    ok "Xray Core instalado."

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
# CONFIGURACIÓN BASE XRAY
# ==============================================================

create_xray_config() {

    mkdir -p "$XRAY_DIR"

    cat > "$XRAY_CFG" <<'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },

  "inbounds": [

    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "tag": "vless-ws",
      "settings": {
        "clients": []
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
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vmess",
      "tag": "vmess-ws",
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
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "trojan",
      "tag": "trojan-ws",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
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
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
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
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
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

    if validate_json; then

        ok "Configuración Xray creada."

    else

        error_msg "No se pudo crear config.json."

        return 1

    fi

}

# ==============================================================
# RESILIENCIA XRAY
# ==============================================================

ensure_xray_resilience() {

    local DIR="/etc/systemd/system/xray.service.d"

    mkdir -p "$DIR"

    cat > "$DIR/10-kevintech-resilience.conf" <<EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
EOF

    systemctl daemon-reload

    systemctl enable xray \
        >/dev/null 2>&1

    ok "Resiliencia Xray configurada."

}

# ==============================================================
# CERTIFICADO SSL
# ==============================================================

generate_ssl_certificate() {

    mkdir -p /etc/haproxy

    if [[ -s "$HAPROXY_CERT" ]]; then

        ok "Certificado SSL existente."

        chmod 600 "$HAPROXY_CERT"

        return 0

    fi

    load_domain

    local CN="${DOMAIN:-ssl-tunnel}"

    local KEY="/tmp/kevintech-key.pem"
    local CRT="/tmp/kevintech-cert.pem"

    rm -f "$KEY" "$CRT"

    info "Generando certificado SSL..."

    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 3650 \
        -keyout "$KEY" \
        -out "$CRT" \
        -subj "/CN=$CN" \
        >/dev/null 2>&1 || {

        error_msg "No se pudo generar certificado."

        rm -f "$KEY" "$CRT"

        return 1

    }

    cat "$KEY" "$CRT" > "$HAPROXY_CERT"

    rm -f "$KEY" "$CRT"

    chmod 600 "$HAPROXY_CERT"

    ok "Certificado SSL creado."

}

# ==============================================================
# CONFIGURAR HAPROXY
# ==============================================================

create_haproxy_config() {

    load_domain

    [[ -z "$DOMAIN" ]] && {

        error_msg "SERVER_DOMAIN no está configurado."

        return 1

    }

    info "Generando HAProxy SSL..."

    cat > "$HAPROXY_CFG" <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice

    stats socket /run/haproxy/admin.sock mode 660 level admin

    user haproxy
    group haproxy

    daemon

    maxconn 65535

    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384

defaults
    log global

    mode http

    option dontlognull
    option http-server-close

    timeout connect 10s
    timeout client 24h
    timeout server 24h
    timeout tunnel 24h

# ==============================================================
# HTTPS SSL
# ==============================================================

frontend kevintech_https

    bind *:443 ssl crt $HAPROXY_CERT alpn h2,http/1.1

    mode http

    option http-buffer-request

    acl path_vless path_beg $VLESS_PATH
    acl path_vmess path_beg $VMESS_PATH
    acl path_trojan path_beg $TROJAN_PATH

    acl path_vless2 path_beg $VLESS2_PATH
    acl path_vmess2 path_beg $VMESS2_PATH
    acl path_trojan2 path_beg $TROJAN2_PATH

    use_backend xray_vless if path_vless
    use_backend xray_vmess if path_vmess
    use_backend xray_trojan if path_trojan

    use_backend xray_vless2 if path_vless2
    use_backend xray_vmess2 if path_vmess2
    use_backend xray_trojan2 if path_trojan2

    use_backend xray_vless_grpc if { ssl_fc_alpn -i h2 }
    use_backend xray_vmess_grpc if { path_beg /$VMESS_GRPC_SERVICE }

    default_backend xray_vmess

# ==============================================================
# HTTP 80
# ==============================================================

frontend kevintech_http

    bind *:80

    mode http

    acl path_vless path_beg $VLESS_PATH
    acl path_vmess path_beg $VMESS_PATH
    acl path_trojan path_beg $TROJAN_PATH

    acl path_vless2 path_beg $VLESS2_PATH
    acl path_vmess2 path_beg $VMESS2_PATH
    acl path_trojan2 path_beg $TROJAN2_PATH

    use_backend xray_vless if path_vless
    use_backend xray_vmess if path_vmess
    use_backend xray_trojan if path_trojan

    use_backend xray_vless2 if path_vless2
    use_backend xray_vmess2 if path_vmess2
    use_backend xray_trojan2 if path_trojan2

    default_backend xray_vmess

# ==============================================================
# HTTP 8080
# ==============================================================

frontend kevintech_alt

    bind *:8080

    mode http

    acl path_vless path_beg $VLESS_PATH
    acl path_vmess path_beg $VMESS_PATH
    acl path_trojan path_beg $TROJAN_PATH

    acl path_vless2 path_beg $VLESS2_PATH
    acl path_vmess2 path_beg $VMESS2_PATH
    acl path_trojan2 path_beg $TROJAN2_PATH

    use_backend xray_vless if path_vless
    use_backend xray_vmess if path_vmess
    use_backend xray_trojan if path_trojan

    use_backend xray_vless2 if path_vless2
    use_backend xray_vmess2 if path_vmess2
    use_backend xray_trojan2 if path_trojan2

    default_backend xray_vmess

# ==============================================================
# BACKENDS
# ==============================================================

backend xray_vless

    mode http

    server vless 127.0.0.1:$VLESS_PORT check

backend xray_vmess

    mode http

    server vmess 127.0.0.1:$VMESS_PORT check

backend xray_trojan

    mode http

    server trojan 127.0.0.1:$TROJAN_PORT check

backend xray_vless2

    mode http

    server vless2 127.0.0.1:$VLESS2_PORT check

backend xray_vmess2

    mode http

    server vmess2 127.0.0.1:$VMESS2_PORT check

backend xray_trojan2

    mode http

    server trojan2 127.0.0.1:$TROJAN2_PORT check

backend xray_vless_grpc

    mode http

    server vless_grpc 127.0.0.1:$VLESS_GRPC_PORT check proto h2

backend xray_vmess_grpc

    mode http

    server vmess_grpc 127.0.0.1:$VMESS_GRPC_PORT check proto h2
EOF

    if ! haproxy \
        -c \
        -f "$HAPROXY_CFG" \
        >/tmp/kevintech-haproxy-test.log 2>&1; then

        error_msg "HAProxy rechazó la configuración."

        cat /tmp/kevintech-haproxy-test.log

        rm -f /tmp/kevintech-haproxy-test.log

        return 1

    fi

    rm -f /tmp/kevintech-haproxy-test.log

    ok "Configuración HAProxy válida."

}

# ==============================================================
# RESILIENCIA HAPROXY
# ==============================================================

ensure_haproxy_resilience() {

    local DIR="/etc/systemd/system/haproxy.service.d"

    mkdir -p "$DIR"

    cat > "$DIR/10-kevintech-resilience.conf" <<EOF
[Unit]
After=network-online.target xray.service
Wants=network-online.target xray.service

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
EOF

    systemctl daemon-reload

    systemctl enable haproxy \
        >/dev/null 2>&1

    ok "Resiliencia HAProxy configurada."

}

# ==============================================================
# INSTALACIÓN COMPLETA
# ==============================================================

install_xray_ssl() {

    header

    echo -e \
        "${WHITE}${BOLD}          🚀 INSTALACIÓN XRAY + SSL HAProxy${RESET}"

    line

    load_domain

    echo
    echo -e "${WHITE}Dominio:${RESET} ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"
    echo -e "${WHITE}TLS público:${RESET} ${GREEN}:443${RESET}"
    echo -e "${WHITE}HTTP:${RESET} ${GREEN}:80${RESET}"
    echo -e "${WHITE}Alternativo:${RESET} ${GREEN}:8080${RESET}"

    echo

    if [[ -z "$DOMAIN" ]]; then

        error_msg "Configura SERVER_DOMAIN primero."

        pause

        return 1

    fi

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

        create_xray_config || {
            pause
            return 1
        }

    else

        if ! validate_json; then

            warning "config.json inválido."

            local BACKUP

            BACKUP=$(backup_xray_config)

            create_xray_config || {
                pause
                return 1
            }

            [[ -n "$BACKUP" ]] &&
                info "Backup: $BACKUP"

        else

            ok "Configuración Xray existente conservada."

        fi

    fi

    ensure_xray_resilience

    generate_ssl_certificate || {
        pause
        return 1
    }

    create_haproxy_config || {
        pause
        return 1
    }

    ensure_haproxy_resilience

    if ! validate_xray_config; then

        error_msg "Xray no acepta la configuración."

        pause

        return 1

    fi

    info "Reiniciando Xray..."

    systemctl restart xray

    sleep 2

    if ! xray_active; then

        error_msg "Xray no inició."

        journalctl \
            -u xray \
            -n 20 \
            --no-pager

        pause

        return 1

    fi

    ok "Xray activo."

    info "Reiniciando HAProxy..."

    systemctl restart haproxy

    sleep 2

    if ! haproxy_active; then

        error_msg "HAProxy no inició."

        journalctl \
            -u haproxy \
            -n 20 \
            --no-pager

        pause

        return 1

    fi

    ok "HAProxy activo."

    set_config "XRAY" "ON"
    set_config "SSL" "ON"
    set_config "SSL_TUNNEL" "ON"

    echo

    echo -e \
        "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${GREEN}║${RESET}          ${BOLD}✔ XRAY + SSL INSTALADO${RESET}                       ${GREEN}║${RESET}"

    echo -e \
        "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${GREEN}║${RESET} Dominio : ${WHITE}$DOMAIN${RESET}"

    echo -e \
        "${GREEN}║${RESET} TLS     : ${GREEN}443${RESET}"

    echo -e \
        "${GREEN}║${RESET} HTTP    : ${GREEN}80${RESET}"

    echo -e \
        "${GREEN}║${RESET} ALT     : ${GREEN}8080${RESET}"

    echo -e \
        "${GREEN}║${RESET} Xray    : ${GREEN}ACTIVO${RESET}"

    echo -e \
        "${GREEN}║${RESET} HAProxy : ${GREEN}ACTIVO${RESET}"

    echo -e \
        "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause

}

# ==============================================================
# MAPEO PROTOCOLO
# ==============================================================

protocol_name() {

    case "$1" in

        10001)
            echo "VLESS"
            ;;

        10002)
            echo "VMess"
            ;;

        10003)
            echo "Trojan"
            ;;

        10004)
            echo "VLESS gRPC"
            ;;

        10005)
            echo "VLESS2"
            ;;

        10006)
            echo "VMess2"
            ;;

        10007)
            echo "Trojan2"
            ;;

        10008)
            echo "VMess gRPC"
            ;;

        *)
            echo "Desconocido"
            ;;

    esac

}

# ==============================================================
# TAG POR PUERTO
# ==============================================================

port_to_tag() {

    case "$1" in

        10001) echo "vless-ws" ;;
        10002) echo "vmess-ws" ;;
        10003) echo "trojan-ws" ;;
        10004) echo "vless-grpc" ;;
        10005) echo "vless-ws-2" ;;
        10006) echo "vmess-ws-2" ;;
        10007) echo "trojan-ws-2" ;;
        10008) echo "vmess-grpc" ;;

    esac

}

# ==============================================================
# UUID / CLIENTE
# ==============================================================

user_exists_in_port() {

    local PORT="$1"
    local USER="$2"

    local INDEX

    INDEX=$(jq \
        --arg tag "$(port_to_tag "$PORT")" \
        '.inbounds | map(.tag) | index($tag)' \
        "$XRAY_CFG" 2>/dev/null)

    [[ "$INDEX" == "null" ]] && return 1

    jq -e \
        --arg tag "$(port_to_tag "$PORT")" \
        --arg email "$USER" \
        '
        .inbounds[]
        | select(.tag == $tag)
        | .settings.clients
        | any(.email == $email)
        ' \
        "$XRAY_CFG" \
        >/dev/null 2>&1

}

get_user_uuid() {

    local PORT="$1"
    local USER="$2"

    jq -r \
        --arg tag "$(port_to_tag "$PORT")" \
        --arg email "$USER" \
        '
        .inbounds[]
        | select(.tag == $tag)
        | .settings.clients[]
        | select(.email == $email)
        | .id
        ' \
        "$XRAY_CFG" 2>/dev/null

}

get_user_password() {

    local PORT="$1"
    local USER="$2"

    jq -r \
        --arg tag "$(port_to_tag "$PORT")" \
        --arg email "$USER" \
        '
        .inbounds[]
        | select(.tag == $tag)
        | .settings.clients[]
        | select(.email == $email)
        | .password
        ' \
        "$XRAY_CFG" 2>/dev/null

}

# ==============================================================
# CREAR CLIENTE
# ==============================================================

add_client_to_port() {

    local PORT="$1"
    local USER="$2"
    local UUID="$3"

    local TAG

    TAG=$(port_to_tag "$PORT")

    local TMP

    TMP=$(mktemp)

    case "$PORT" in

        10003|10007)

            jq \
                --arg tag "$TAG" \
                --arg email "$USER" \
                --arg password "$UUID" \
                '
                .inbounds |= map(
                    if .tag == $tag then
                        .settings.clients += [
                            {
                                "password": $password,
                                "email": $email,
                                "level": 0
                            }
                        ]
                    else
                        .
                    end
                )
                ' \
                "$XRAY_CFG" > "$TMP"

            ;;

        *)

            jq \
                --arg tag "$TAG" \
                --arg email "$USER" \
                --arg uuid "$UUID" \
                '
                .inbounds |= map(
                    if .tag == $tag then
                        .settings.clients += [
                            {
                                "id": $uuid,
                                "email": $email,
                                "level": 0
                            }
                        ]
                    else
                        .
                    end
                )
                ' \
                "$XRAY_CFG" > "$TMP"

            ;;

    esac

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        error_msg "No se pudo modificar Xray."

        return 1

    fi

    mv "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

}

# ==============================================================
# CREAR CUENTA
# ==============================================================

create_account() {

    if ! xray_installed; then

        error_msg "Xray no está instalado."

        return

    fi

    load_domain

    if [[ -z "$DOMAIN" ]]; then

        error_msg "No existe SERVER_DOMAIN."

        return

    fi

    header

    echo -e \
        "${WHITE}${BOLD}                    👤 CREAR CUENTA${RESET}"

    line

    echo
    echo -e "${GREEN}[01]${RESET} VLESS"
    echo -e "${GREEN}[02]${RESET} VMess"
    echo -e "${GREEN}[03]${RESET} Trojan"
    echo -e "${GREEN}[04]${RESET} VLESS gRPC"
    echo -e "${GREEN}[05]${RESET} VLESS2"
    echo -e "${GREEN}[06]${RESET} VMess2"
    echo -e "${GREEN}[07]${RESET} Trojan2"
    echo -e "${GREEN}[08]${RESET} VMess gRPC"

    echo

    read -rp "➜ Protocolo: " OPTION

    local PORT

    case "$OPTION" in

        1) PORT=10001 ;;
        2) PORT=10002 ;;
        3) PORT=10003 ;;
        4) PORT=10004 ;;
        5) PORT=10005 ;;
        6) PORT=10006 ;;
        7) PORT=10007 ;;
        8) PORT=10008 ;;

        *)

            error_msg "Protocolo inválido."

            pause

            return

            ;;

    esac

    echo

    read -rp "👤 Nombre de usuario: " USER

    USER=$(echo "$USER" | xargs)

    if [[ -z "$USER" ]]; then

        error_msg "Usuario vacío."

        pause

        return

    fi

    if ! [[ "$USER" =~ ^[a-zA-Z0-9_.-]+$ ]]; then

        error_msg "Nombre de usuario inválido."

        pause

        return

    fi

    if user_exists_in_port "$PORT" "$USER"; then

        error_msg "El usuario ya existe en este protocolo."

        pause

        return

    fi

    local UUID

    UUID=$(generate_uuid) || {

        pause

        return

    }

    local BACKUP

    BACKUP=$(backup_xray_config)

    if ! add_client_to_port \
        "$PORT" \
        "$USER" \
        "$UUID"; then

        pause

        return

    fi

    if ! validate_xray_config; then

        error_msg "Xray rechazó el cambio."

        [[ -f "$BACKUP" ]] &&
            cp -f "$BACKUP" "$XRAY_CFG"

        pause

        return

    fi

    systemctl restart xray

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo reiniciar."

        if [[ -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart xray

            warning "Backup restaurado."

        fi

        pause

        return

    fi

    ok "Cuenta creada correctamente."

    show_account_data "$PORT" "$USER"

}

# ==============================================================
# OBTENER PATH
# ==============================================================

get_user_path() {

    case "$1" in

        10001) echo "$VLESS_PATH" ;;
        10002) echo "$VMESS_PATH" ;;
        10003) echo "$TROJAN_PATH" ;;
        10004) echo "$VLESS_GRPC_SERVICE" ;;
        10005) echo "$VLESS2_PATH" ;;
        10006) echo "$VMESS2_PATH" ;;
        10007) echo "$TROJAN2_PATH" ;;
        10008) echo "$VMESS_GRPC_SERVICE" ;;

    esac

}

# ==============================================================
# GENERAR VMESS
# ==============================================================

generate_vmess_link() {

    local PORT="$1"
    local USER="$2"
    local UUID="$3"

    local PATH

    PATH=$(get_user_path "$PORT")

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
  "path":"$PATH",
  "tls":"tls",
  "sni":"$DOMAIN"
}
EOF

}

# ==============================================================
# GENERAR VLESS
# ==============================================================

generate_vless_link() {

    local PORT="$1"
    local UUID="$2"

    local PATH

    PATH=$(get_user_path "$PORT")

    echo \
        "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=$(printf '%s' "$PATH" | sed 's|/|%2F|g')&sni=${DOMAIN}#VLESS-${DOMAIN}"

}

# ==============================================================
# GENERAR TROJAN
# ==============================================================

generate_trojan_link() {

    local PASSWORD="$1"

    local PATH

    PATH=$(get_user_path "$PORT")

    echo \
        "trojan://${PASSWORD}@${DOMAIN}:443?security=tls&type=ws&host=${DOMAIN}&path=$(printf '%s' "$PATH" | sed 's|/|%2F|g')&sni=${DOMAIN}#Trojan-${DOMAIN}"

}

# ==============================================================
# MOSTRAR CUENTA
# ==============================================================

show_account_data() {

    local PORT="$1"
    local USER="$2"

    load_domain

    local PROTOCOL

    PROTOCOL=$(protocol_name "$PORT")

    local UUID

    UUID=$(get_user_uuid "$PORT" "$USER")

    local PASSWORD

    PASSWORD=$(get_user_password "$PORT" "$USER")

    local PATH

    PATH=$(get_user_path "$PORT")

    local LINK=""

    case "$PORT" in

        10001|10004|10005)

            LINK=$(generate_vless_link "$PORT" "$UUID")

            ;;

        10002|10006|10008)

            LINK="vmess://$(generate_vmess_link "$PORT" "$USER" "$UUID")"

            ;;

        10003|10007)

            LINK=$(generate_trojan_link "$PASSWORD")

            ;;

    esac

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}                 ${GREEN}${BOLD}🎉 CUENTA XRAY${RESET}                       ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${WHITE}👤 Usuario    :${RESET} ${GREEN}$USER${RESET}"

    echo -e \
        "${WHITE}🔐 Protocolo  :${RESET} ${GREEN}$PROTOCOL${RESET}"

    echo -e \
        "${WHITE}🆔 UUID       :${RESET} ${YELLOW}${UUID:-N/A}${RESET}"

    if [[ "$PORT" == "10003" ||
          "$PORT" == "10007" ]]; then

        echo -e \
            "${WHITE}🔑 Password   :${RESET} ${YELLOW}$PASSWORD${RESET}"

    fi

    echo -e \
        "${WHITE}🌐 Dominio    :${RESET} ${GREEN}$DOMAIN${RESET}"

    echo -e \
        "${WHITE}🔒 Puerto     :${RESET} ${GREEN}443${RESET}"

    echo -e \
        "${WHITE}🎯 Interno    :${RESET} ${GREEN}127.0.0.1:$PORT${RESET}"

    echo -e \
        "${WHITE}📡 Transporte :${RESET} ${GREEN}$(
            case "$PORT" in
                10004|10008) echo "gRPC" ;;
                *) echo "WebSocket" ;;
            esac
        )${RESET}"

    echo -e \
        "${WHITE}📂 Path/Service:${RESET} ${GREEN}$PATH${RESET}"

    echo -e \
        "${WHITE}🛡️ TLS        :${RESET} ${GREEN}HAProxy / 443${RESET}"

    line

    echo -e \
        "${YELLOW}${BOLD}🔗 ENLACE${RESET}"

    echo

    echo -e \
        "${GREEN}$LINK${RESET}"

    echo

    pause

}

# ==============================================================
# BUSCAR CUENTA
# ==============================================================

select_account() {

    header

    echo -e \
        "${WHITE}${BOLD}                 📋 BUSCAR CUENTA${RESET}"

    line

    echo

    read -rp "👤 Usuario: " USER

    USER=$(echo "$USER" | xargs)

    [[ -z "$USER" ]] && return 1

    local RESULTS=()

    while read -r PORT; do

        if user_exists_in_port "$PORT" "$USER"; then

            RESULTS+=("$PORT")

        fi

    done <<EOF
10001
10002
10003
10004
10005
10006
10007
10008
EOF

    if [[ "${#RESULTS[@]}" -eq 0 ]]; then

        error_msg "Usuario no encontrado."

        pause

        return 1

    fi

    if [[ "${#RESULTS[@]}" -eq 1 ]]; then

        SELECTED_PORT="${RESULTS[0]}"

        return 0

    fi

    echo

    echo -e "${WHITE}El usuario existe en:${RESET}"

    local I=0

    for PORT in "${RESULTS[@]}"; do

        I=$((I + 1))

        echo -e \
            "${GREEN}[$I]${RESET} $(protocol_name "$PORT") - $PORT"

    done

    echo

    read -rp "➜ Seleccione: " OPTION

    if ! [[ "$OPTION" =~ ^[0-9]+$ ]] ||
       (( OPTION < 1 || OPTION > ${#RESULTS[@]} )); then

        error_msg "Selección inválida."

        pause

        return 1

    fi

    SELECTED_PORT="${RESULTS[$((OPTION - 1))]}"

    return 0

}

# ==============================================================
# VER CUENTA
# ==============================================================

view_account() {

    if ! select_account; then

        return

    fi

    show_account_data \
        "$SELECTED_PORT" \
        "$USER"

}

# ==============================================================
# LISTAR TODAS
# ==============================================================

list_accounts() {

    header

    echo -e \
        "${WHITE}${BOLD}                    📋 CUENTAS XRAY${RESET}"

    line

    printf \
        "${CYAN}%-5s %-22s %-18s %-38s${RESET}\n" \
        "#" \
        "USUARIO" \
        "PROTOCOLO" \
        "UUID"

    echo -e \
        "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

    local I=0
    local TOTAL=0

    while read -r PORT; do

        while IFS=$'\t' read -r USER UUID; do

            [[ -z "$USER" ]] && continue

            I=$((I + 1))
            TOTAL=$((TOTAL + 1))

            printf \
                "${GREEN}%-5s${RESET} ${WHITE}%-22s${RESET} ${YELLOW}%-18s${RESET} ${GRAY}%-38s${RESET}\n" \
                "$I" \
                "$USER" \
                "$(protocol_name "$PORT")" \
                "$UUID"

        done < <(
            jq -r \
                --arg tag "$(port_to_tag "$PORT")" \
                '
                .inbounds[]
                | select(.tag == $tag)
                | .settings.clients[]
                | [
                    .email,
                    (.id // .password // "N/A")
                  ]
                | @tsv
                ' \
                "$XRAY_CFG" 2>/dev/null
        )

    done <<EOF
10001
10002
10003
10004
10005
10006
10007
10008
EOF

    echo

    echo -e \
        "${WHITE}Total de cuentas:${RESET} ${GREEN}$TOTAL${RESET}"

    pause

}

# ==============================================================
# EDITAR CUENTA
# ==============================================================

edit_account() {

    if ! select_account; then

        return

    fi

    local PORT="$SELECTED_PORT"

    local OLD_USER="$USER"

    local UUID

    UUID=$(get_user_uuid "$PORT" "$OLD_USER")

    local PASSWORD

    PASSWORD=$(get_user_password "$PORT" "$OLD_USER")

    header

    echo -e \
        "${WHITE}${BOLD}                    ✏️ EDITAR CUENTA${RESET}"

    line

    echo
    echo -e "${WHITE}Usuario actual:${RESET} ${GREEN}$OLD_USER${RESET}"
    echo -e "${WHITE}Protocolo:${RESET} ${GREEN}$(protocol_name "$PORT")${RESET}"

    echo

    echo -e "${GREEN}[1]${RESET} Cambiar usuario"
    echo -e "${GREEN}[2]${RESET} Regenerar credencial"
    echo -e "${GREEN}[3]${RESET} Cambiar usuario + credencial"
    echo -e "${GREEN}[0]${RESET} Cancelar"

    echo

    read -rp "➜ Opción: " OPTION

    case "$OPTION" in

        0)
            return
            ;;

        1)

            read -rp "Nuevo usuario: " NEW_USER

            NEW_USER=$(echo "$NEW_USER" | xargs)

            [[ -z "$NEW_USER" ]] && return

            ;;

        2)

            NEW_USER="$OLD_USER"

            ;;

        3)

            read -rp "Nuevo usuario: " NEW_USER

            NEW_USER=$(echo "$NEW_USER" | xargs)

            [[ -z "$NEW_USER" ]] && return

            ;;

        *)

            error_msg "Opción inválida."

            pause

            return

            ;;

    esac

    if [[ "$NEW_USER" != "$OLD_USER" ]] &&
       user_exists_in_port "$PORT" "$NEW_USER"; then

        error_msg "El nuevo usuario ya existe."

        pause

        return

    fi

    local NEW_UUID="$UUID"

    if [[ "$PORT" == "10003" ||
          "$PORT" == "10007" ]]; then

        NEW_UUID="$PASSWORD"

    fi

    if [[ "$OPTION" == "2" ||
          "$OPTION" == "3" ]]; then

        NEW_UUID=$(generate_uuid) || {

            pause

            return

        }

    fi

    local BACKUP

    BACKUP=$(backup_xray_config)

    local TAG

    TAG=$(port_to_tag "$PORT")

    local TMP

    TMP=$(mktemp)

    case "$PORT" in

        10003|10007)

            jq \
                --arg tag "$TAG" \
                --arg old "$OLD_USER" \
                --arg new "$NEW_USER" \
                --arg pass "$NEW_UUID" \
                '
                .inbounds |= map(
                    if .tag == $tag then
                        .settings.clients |= map(
                            if .email == $old then
                                .email = $new |
                                .password = $pass
                            else
                                .
                            end
                        )
                    else
                        .
                    end
                )
                ' \
                "$XRAY_CFG" > "$TMP"

            ;;

        *)

            jq \
                --arg tag "$TAG" \
                --arg old "$OLD_USER" \
                --arg new "$NEW_USER" \
                --arg uuid "$NEW_UUID" \
                '
                .inbounds |= map(
                    if .tag == $tag then
                        .settings.clients |= map(
                            if .email == $old then
                                .email = $new |
                                .id = $uuid
                            else
                                .
                            end
                        )
                    else
                        .
                    end
                )
                ' \
                "$XRAY_CFG" > "$TMP"

            ;;

    esac

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        error_msg "No se pudo modificar la cuenta."

        pause

        return

    fi

    mv "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    if ! validate_xray_config; then

        error_msg "Configuración inválida."

        [[ -f "$BACKUP" ]] &&
            cp -f "$BACKUP" "$XRAY_CFG"

        pause

        return

    fi

    systemctl restart xray

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo iniciar."

        if [[ -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart xray

            warning "Backup restaurado."

        fi

        pause

        return

    fi

    ok "Cuenta actualizada."

    show_account_data "$PORT" "$NEW_USER"

}

# ==============================================================
# ELIMINAR CUENTA
# ==============================================================

delete_account() {

    if ! select_account; then

        return

    fi

    local PORT="$SELECTED_PORT"

    local USERNAME="$USER"

    local UUID

    UUID=$(get_user_uuid "$PORT" "$USERNAME")

    local PASSWORD

    PASSWORD=$(get_user_password "$PORT" "$USERNAME")

    header

    echo -e \
        "${WHITE}${BOLD}                  🗑️ ELIMINAR CUENTA${RESET}"

    line

    echo
    echo -e "${WHITE}Usuario:${RESET} ${GREEN}$USERNAME${RESET}"
    echo -e "${WHITE}Protocolo:${RESET} ${GREEN}$(protocol_name "$PORT")${RESET}"

    if [[ "$PORT" == "10003" ||
          "$PORT" == "10007" ]]; then

        echo -e "${WHITE}Password:${RESET} ${YELLOW}$PASSWORD${RESET}"

    else

        echo -e "${WHITE}UUID:${RESET} ${YELLOW}$UUID${RESET}"

    fi

    echo

    read -rp \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        pause

        return

    fi

    local BACKUP

    BACKUP=$(backup_xray_config)

    local TAG

    TAG=$(port_to_tag "$PORT")

    local TMP

    TMP=$(mktemp)

    jq \
        --arg tag "$TAG" \
        --arg email "$USERNAME" \
        '
        .inbounds |= map(
            if .tag == $tag then
                .settings.clients |=
                map(select(.email != $email))
            else
                .
            end
        )
        ' \
        "$XRAY_CFG" > "$TMP"

    if ! jq empty "$TMP" >/dev/null 2>&1; then

        rm -f "$TMP"

        error_msg "No se pudo modificar Xray."

        pause

        return

    fi

    mv "$TMP" "$XRAY_CFG"

    chmod 600 "$XRAY_CFG"

    if ! validate_xray_config; then

        error_msg "Configuración inválida."

        [[ -f "$BACKUP" ]] &&
            cp -f "$BACKUP" "$XRAY_CFG"

        pause

        return

    fi

    systemctl restart xray

    sleep 2

    if ! xray_active; then

        error_msg "Xray no pudo iniciar."

        if [[ -f "$BACKUP" ]]; then

            cp -f "$BACKUP" "$XRAY_CFG"

            systemctl restart xray

            warning "Backup restaurado."

        fi

        pause

        return

    fi

    ok "Cuenta eliminada correctamente."

    pause

}

# ==============================================================
# ESTADO
# ==============================================================

show_status() {

    header

    echo -e \
        "${WHITE}${BOLD}                    📊 ESTADO${RESET}"

    line

    if xray_active; then

        echo -e \
            "${WHITE}Xray:${RESET} ${GREEN}🟢 ACTIVO${RESET}"

    else

        echo -e \
            "${WHITE}Xray:${RESET} ${RED}🔴 DETENIDO${RESET}"

    fi

    if haproxy_active; then

        echo -e \
            "${WHITE}HAProxy:${RESET} ${GREEN}🟢 ACTIVO${RESET}"

    else

        echo -e \
            "${WHITE}HAProxy:${RESET} ${RED}🔴 DETENIDO${RESET}"

    fi

    load_domain

    echo
    echo -e "${WHITE}Dominio:${RESET} ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

    echo

    echo -e "${WHITE}Puertos públicos:${RESET}"

    echo -e "  80    ${GREEN}HTTP${RESET}"
    echo -e "  443   ${GREEN}HTTPS / TLS${RESET}"
    echo -e "  8080  ${GREEN}HTTP ALT${RESET}"

    echo

    echo -e "${WHITE}Puertos Xray internos:${RESET}"

    for PORT in \
        10001 \
        10002 \
        10003 \
        10004 \
        10005 \
        10006 \
        10007 \
        10008; do

        if ss -H -lnt 2>/dev/null |
            awk -v P=":$PORT" '$4 ~ P"$"' |
            grep -q .; then

            echo -e \
                "  $PORT  ${GREEN}● ESCUCHANDO${RESET}  $(protocol_name "$PORT")"

        else

            echo -e \
                "  $PORT  ${RED}● CERRADO${RESET}      $(protocol_name "$PORT")"

        fi

    done

    echo

    load_domain

    echo -e \
        "${WHITE}Certificado:${RESET} ${GREEN}$HAPROXY_CERT${RESET}"

    echo -e \
        "${WHITE}Xray config:${RESET} ${GREEN}$XRAY_CFG${RESET}"

    echo -e \
        "${WHITE}HAProxy config:${RESET} ${GREEN}$HAPROXY_CFG${RESET}"

    pause

}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostic() {

    header

    echo -e \
        "${WHITE}${BOLD}                   🔎 DIAGNÓSTICO${RESET}"

    line

    echo

    if command -v xray >/dev/null 2>&1; then
        ok "Xray Core instalado"
    else
        error_msg "Xray no instalado"
    fi

    if command -v haproxy >/dev/null 2>&1; then
        ok "HAProxy instalado"
    else
        error_msg "HAProxy no instalado"
    fi

    if command -v jq >/dev/null 2>&1; then
        ok "jq disponible"
    else
        error_msg "jq no disponible"
    fi

    if [[ -f "$XRAY_CFG" ]]; then

        if validate_json; then
            ok "JSON válido"
        else
            error_msg "JSON inválido"
        fi

        if validate_xray_config; then
            ok "Xray acepta la configuración"
        else
            error_msg "Xray rechaza la configuración"
        fi

    else

        error_msg "No existe config.json"

    fi

    if [[ -f "$HAPROXY_CFG" ]]; then

        if haproxy \
            -c \
            -f "$HAPROXY_CFG" \
            >/dev/null 2>&1; then

            ok "HAProxy acepta la configuración"

        else

            error_msg "HAProxy rechaza la configuración"

        fi

    else

        error_msg "No existe haproxy.cfg"

    fi

    if [[ -s "$HAPROXY_CERT" ]]; then
        ok "Certificado SSL encontrado"
    else
        error_msg "Certificado SSL inexistente"
    fi

    echo

    echo -e "${WHITE}Servicios:${RESET}"

    systemctl is-active xray \
        && ok "Xray activo" \
        || error_msg "Xray detenido"

    systemctl is-active haproxy \
        && ok "HAProxy activo" \
        || error_msg "HAProxy detenido"

    echo

    echo -e "${WHITE}Últimos registros Xray:${RESET}"

    journalctl \
        -u xray \
        -n 10 \
        --no-pager 2>/dev/null

    echo

    echo -e "${WHITE}Últimos registros HAProxy:${RESET}"

    journalctl \
        -u haproxy \
        -n 10 \
        --no-pager 2>/dev/null

    pause

}

# ==============================================================
# LOGS
# ==============================================================

show_logs() {

    header

    echo -e \
        "${WHITE}${BOLD}                     📜 LOGS${RESET}"

    line

    echo -e \
        "${WHITE}──── XRAY ────${RESET}"

    journalctl \
        -u xray \
        -n 30 \
        --no-pager 2>/dev/null

    echo

    echo -e \
        "${WHITE}──── HAPROXY ────${RESET}"

    journalctl \
        -u haproxy \
        -n 30 \
        --no-pager 2>/dev/null

    echo

    if [[ -f "$XRAY_LOG" ]]; then

        echo -e \
            "${WHITE}──── ACCESS LOG ────${RESET}"

        tail -n 20 "$XRAY_LOG"

    fi

    pause

}

# ==============================================================
# REINICIAR
# ==============================================================

restart_services() {

    header

    info "Validando Xray..."

    if ! validate_xray_config; then

        pause

        return

    fi

    info "Reiniciando Xray..."

    systemctl restart xray

    sleep 2

    if xray_active; then

        ok "Xray activo."

    else

        error_msg "Xray no inició."

    fi

    info "Validando HAProxy..."

    if ! haproxy \
        -c \
        -f "$HAPROXY_CFG" \
        >/dev/null 2>&1; then

        error_msg "HAProxy tiene errores."

        pause

        return

    fi

    info "Reiniciando HAProxy..."

    systemctl restart haproxy

    sleep 2

    if haproxy_active; then

        ok "HAProxy activo."

    else

        error_msg "HAProxy no inició."

    fi

    pause

}

# ==============================================================
# ACTUALIZAR
# ==============================================================

update_xray() {

    header

    info "Creando backup..."

    local BACKUP

    BACKUP=$(backup_xray_config)

    [[ -n "$BACKUP" ]] &&
        ok "Backup: $BACKUP"

    info "Actualizando dependencias..."

    install_dependencies || {

        pause

        return

    }

    info "Actualizando Xray Core..."

    local INSTALLER="/tmp/xray-update.sh"

    curl -fL \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        -o "$INSTALLER" || {

        error_msg "No se pudo descargar actualización."

        pause

        return

    }

    chmod 700 "$INSTALLER"

    bash "$INSTALLER" install

    rm -f "$INSTALLER"

    systemctl daemon-reload

    if validate_xray_config; then

        systemctl restart xray

        sleep 2

        if xray_active; then

            ok "Xray actualizado correctamente."

        else

            error_msg "Xray no inició."

        fi

    else

        error_msg "La configuración actual no es válida."

    fi

    pause

}

# ==============================================================
# DESINSTALAR
# ==============================================================

uninstall_xray_ssl() {

    header

    warning "Se eliminará Xray + configuración HAProxy creada"
    warning "por este administrador."

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

    [[ -n "$BACKUP" ]] &&
        ok "Backup guardado: $BACKUP"

    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null

    systemctl stop haproxy 2>/dev/null
    systemctl disable haproxy 2>/dev/null

    rm -rf \
        /etc/systemd/system/xray.service.d

    rm -rf \
        /etc/systemd/system/haproxy.service.d

    rm -rf "$XRAY_DIR"

    rm -rf "$XRAY_LOG_DIR"

    rm -f "$HAPROXY_CFG"

    rm -f "$HAPROXY_CERT"

    systemctl daemon-reload

    set_config "XRAY" "OFF"
    set_config "SSL" "OFF"
    set_config "SSL_TUNNEL" "OFF"

    ok "Configuración KevinTech eliminada."

    warning "El paquete HAProxy no fue eliminado."

    warning "El paquete Xray Core tampoco se elimina automáticamente."

    pause

}

# ==============================================================
# MENÚ
# ==============================================================

xray_menu() {

    while true; do

        source "$CONFIG" 2>/dev/null

        load_domain

        local STATUS

        if xray_active &&
           haproxy_active; then

            STATUS="${GREEN}🟢 XRAY + SSL ACTIVO${RESET}"

        elif xray_active ||
             haproxy_active; then

            STATUS="${YELLOW}🟡 PARCIAL${RESET}"

        elif xray_installed; then

            STATUS="${RED}🔴 DETENIDO${RESET}"

        else

            STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

        fi

        local TOTAL_USERS=0

        if [[ -f "$XRAY_CFG" ]]; then

            TOTAL_USERS=$(jq \
                '[.inbounds[].settings.clients[]] | length' \
                "$XRAY_CFG" 2>/dev/null)

        fi

        TOTAL_USERS="${TOTAL_USERS:-0}"

        clear

        echo -e \
            "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

        echo -e \
            "${CYAN}║${RESET}            ${MAGENTA}${BOLD}🚀 KEVINTECH XRAY SSL${RESET}                    ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${WHITE}Estado:${RESET}        $STATUS"

        echo -e \
            "${WHITE}Dominio:${RESET}       ${GREEN}${DOMAIN:-NO CONFIGURADO}${RESET}"

        echo -e \
            "${WHITE}TLS:${RESET}           ${GREEN}HAProxy :443${RESET}"

        echo -e \
            "${WHITE}Cuentas:${RESET}       ${GREEN}$TOTAL_USERS${RESET}"

        line

        if ! xray_installed; then

            echo -e \
                "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"

            echo

            echo -e \
                "${GREEN}[01]${RESET} 🚀 Instalar Xray + SSL"

        else

            echo -e \
                "${BLUE}${BOLD}  👥 GESTIÓN DE CUENTAS${RESET}"

            echo

            echo -e \
                "${GREEN}[01]${RESET} 👤 Crear cuenta"

            echo -e \
                "${GREEN}[02]${RESET} ✏️  Editar cuenta"

            echo -e \
                "${GREEN}[03]${RESET} 📋 Ver cuenta"

            echo -e \
                "${GREEN}[04]${RESET} 🗑️  Eliminar cuenta"

            echo

            echo -e \
                "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN${RESET}"

            echo

            echo -e \
                "${GREEN}[05]${RESET} 📋 Listar todas"

            echo -e \
                "${GREEN}[06]${RESET} 📊 Estado"

            echo -e \
                "${GREEN}[07]${RESET} 🔎 Diagnóstico"

            echo -e \
                "${GREEN}[08]${RESET} 📜 Logs"

            echo -e \
                "${GREEN}[09]${RESET} ♻️  Reiniciar"

            echo -e \
                "${GREEN}[10]${RESET} 🔄 Actualizar"

            echo -e \
                "${RED}[11]${RESET} 🗑️  Desinstalar"

        fi

        echo

        echo -e \
            "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

        echo -e \
            "${RED}${BOLD}[00]${RESET} ↩️  Regresar"

        echo

        echo -e \
            "${GRAY}KevinTech Multi Script • Privanox VPN • v$VERSION${RESET}"

        echo

        read -rp \
            "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)

                if xray_installed; then
                    create_account
                else
                    install_xray_ssl
                fi

                ;;

            2)

                if xray_installed; then
                    edit_account
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi

                ;;

            3)

                if xray_installed; then
                    view_account
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi

                ;;

            4)

                if xray_installed; then
                    delete_account
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi

                ;;

            5)

                if xray_installed; then
                    list_accounts
                else
                    error_msg "Xray no está instalado."
                    sleep 1
                fi

                ;;

            6)

                show_status

                ;;

            7)

                diagnostic

                ;;

            8)

                show_logs

                ;;

            9)

                restart_services

                ;;

            10)

                update_xray

                ;;

            11)

                uninstall_xray_ssl

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
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    install_xray_ssl

    exit $?

fi

# ==============================================================
# INICIO
# ==============================================================

xray_menu