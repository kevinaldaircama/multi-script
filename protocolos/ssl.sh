#!/usr/bin/env bash
# ============================================================
# KevinTech SSL Tunnel Manager - Bash Edition
# HAProxy + SSH WebSocket + Xray routing
# Ubuntu/Debian
# ============================================================

set -Eeuo pipefail

# -----------------------------
# CONFIGURACIÓN
# -----------------------------

readonly APP_NAME="KevinTech SSL Tunnel"
readonly CONFIG_DIR="/etc/kevintech-ssl"
readonly HAPROXY_DIR="/etc/haproxy"
readonly HAPROXY_CFG="${HAPROXY_DIR}/haproxy.cfg"
readonly CERT_FILE="${HAPROXY_DIR}/yha.pem"
readonly RESILIENCE_DIR="/etc/systemd/system/haproxy.service.d"
readonly RESILIENCE_FILE="${RESILIENCE_DIR}/10-kevintech-resilience.conf"

readonly WS_PORT="10015"

readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly WHITE='\033[1;37m'
readonly RESET='\033[0m'

# -----------------------------
# UTILIDADES
# -----------------------------

log() {
    echo -e "${GREEN}[✓]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $*"
}

error() {
    echo -e "${RED}[✗]${RESET} $*" >&2
}

info() {
    echo -e "${CYAN}[i]${RESET} $*"
}

die() {
    error "$*"
    exit 1
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Ejecuta este script como root."
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# -----------------------------
# BANNER
# -----------------------------

banner() {
    clear

    echo -e "${CYAN}"
    cat <<'EOF'

██╗  ██╗███████╗██╗   ██╗██╗███╗   ██╗
██║ ██╔╝██╔════╝╚██╗ ██╔╝██║████╗  ██║
█████╔╝ █████╗   ╚████╔╝ ██║██╔██╗ ██║
██╔═██╗ ██╔══╝    ╚██╔╝  ██║██║╚██╗██║
██║  ██╗███████╗   ██║   ██║██║ ╚████║
╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝

          SSL TUNNEL MANAGER
              BASH EDITION

EOF
    echo -e "${RESET}"
}

# -----------------------------
# DEPENDENCIAS
# -----------------------------

install_dependencies() {

    info "Actualizando repositorios..."

    apt-get update -y

    apt-get install -y \
        haproxy \
        openssl \
        curl \
        wget \
        jq \
        socat \
        ca-certificates \
        iproute2 \
        psmisc

    log "Dependencias instaladas."
}

# -----------------------------
# CERTIFICADO
# -----------------------------

generate_certificate() {

    mkdir -p "$HAPROXY_DIR"

    if [[ -s "$CERT_FILE" ]]; then
        log "Certificado existente: $CERT_FILE"
        return
    fi

    info "Generando certificado SSL..."

    local key cert

    key="$(mktemp)"
    cert="$(mktemp)"

    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 3650 \
        -keyout "$key" \
        -out "$cert" \
        -subj "/CN=ssl-tunnel"

    cat "$key" "$cert" > "$CERT_FILE"

    chmod 600 "$CERT_FILE"

    rm -f "$key" "$cert"

    log "Certificado creado."
}

# -----------------------------
# PUERTOS
# -----------------------------

kill_port() {

    local port="$1"

    if ss -ltnp 2>/dev/null | grep -q ":${port} "; then

        warn "Liberando puerto ${port}..."

        fuser -k "${port}/tcp" 2>/dev/null || true

        sleep 1
    fi
}

free_haproxy_ports() {

    kill_port 80
    kill_port 443
    kill_port 8080
}

# -----------------------------
# SERVICIOS WS ANTIGUOS
# -----------------------------

disable_old_ws() {

    for service in \
        ssh-ws.service \
        ssh-wss.service \
        ssh-ws-internal.service
    do

        systemctl stop "$service" 2>/dev/null || true
    done

    systemctl disable ssh-ws.service 2>/dev/null || true
    systemctl disable ssh-wss.service 2>/dev/null || true

    log "Servicios WS antiguos detenidos."
}

# ============================================================
# CONFIGURACIÓN HAPROXY
# ============================================================

write_haproxy_config() {

    mkdir -p "$HAPROXY_DIR"

    cat > "$HAPROXY_CFG" <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice

    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s

    pidfile /run/haproxy.pid

    user haproxy
    group haproxy

    daemon

    tune.bufsize 10485760
    tune.maxrewrite 3072

    tune.ssl.default-dh-param 2048

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384

    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256

    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private


defaults
    log global
    mode tcp

    option dontlognull
    option tcp-smart-connect

    timeout connect 5s
    timeout client 24h
    timeout server 24h


# ============================================================
# ENTRADA PRINCIPAL HTTPS
# ============================================================

frontend https_entry
    mode tcp

    bind *:443 tfo
    bind *:80 tfo
    bind *:8080 tfo

    tcp-request inspect-delay 200ms

    tcp-request content capture req.ssl_sni len 100

    tcp-request content accept if { req.ssl_hello_type 1 }

    acl ssh_payload payload(0,7) -m bin 5353482d322e30

    acl websocket_upgrade req.payload(0,4096) -m reg -i "upgrade:\s*websocket"

    acl vless_path req.payload(0,4096) -m reg -i "GET\s+/vless"
    acl vmess_path req.payload(0,4096) -m reg -i "GET\s+/vmess"
    acl trojan_path req.payload(0,4096) -m reg -i "GET\s+/trojan-ws"

    use_backend ssh_direct_backend if ssh_payload

    use_backend vless_backend if vless_path
    use_backend vmess_backend if vmess_path
    use_backend trojan_backend if trojan_path

    use_backend websocket_backend if websocket_upgrade

    default_backend ssh_ws_backend


# ============================================================
# SSH DIRECT
# ============================================================

backend ssh_direct_backend
    mode tcp

    server ssh 127.0.0.1:22 check


# ============================================================
# WEBSOCKET SSH
# ============================================================

backend websocket_backend
    mode tcp

    server sshws 127.0.0.1:10015 check


backend ssh_ws_backend
    mode tcp

    server sshws 127.0.0.1:10015 check


# ============================================================
# XRAY VLESS
# ============================================================

backend vless_backend
    mode tcp

    server vless1 127.0.0.1:10001 check


# ============================================================
# XRAY VMESS
# ============================================================

backend vmess_backend
    mode tcp

    server vmess1 127.0.0.1:10002 check


# ============================================================
# XRAY TROJAN
# ============================================================

backend trojan_backend
    mode tcp

    server trojan1 127.0.0.1:10003 check


# ============================================================
# GRPC
# ============================================================

backend grpc_backend
    mode tcp

    server grpc1 127.0.0.1:1013 check
EOF

    log "HAProxy configurado."
}

# -----------------------------
# RESILIENCIA SYSTEMD
# -----------------------------

configure_resilience() {

    mkdir -p "$RESILIENCE_DIR"

    cat > "$RESILIENCE_FILE" <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=3

StartLimitIntervalSec=0

ExecStartPre=/bin/mkdir -p /run/haproxy
EOF

    systemctl daemon-reload

    log "Resiliencia systemd configurada."
}

# -----------------------------
# VALIDAR HAPROXY
# -----------------------------

validate_haproxy() {

    info "Validando configuración HAProxy..."

    if haproxy -c -f "$HAPROXY_CFG"; then
        log "Configuración válida."
    else
        die "La configuración de HAProxy contiene errores."
    fi
}

# -----------------------------
# ARRANCAR
# -----------------------------

start_haproxy() {

    mkdir -p /run/haproxy

    systemctl daemon-reload

    systemctl enable haproxy

    systemctl restart haproxy

    sleep 2

    if systemctl is-active --quiet haproxy; then
        log "HAProxy está funcionando."
    else
        error "HAProxy no pudo iniciar."
        systemctl status haproxy --no-pager || true
        exit 1
    fi
}

# -----------------------------
# INSTALACIÓN PRINCIPAL
# -----------------------------

install_tunnel() {

    require_root

    banner

    echo -e "${WHITE}Instalación del sistema SSL Tunnel${RESET}"
    echo

    install_dependencies

    generate_certificate

    free_haproxy_ports

    disable_old_ws

    write_haproxy_config

    configure_resilience

    validate_haproxy

    start_haproxy

    echo
    echo -e "${GREEN}"
    echo "=============================================="
    echo "        INSTALACIÓN COMPLETADA"
    echo "=============================================="
    echo -e "${RESET}"

    show_status
}

# -----------------------------
# ESTADO
# -----------------------------

show_status() {

    echo
    echo -e "${CYAN}========== ESTADO DEL SISTEMA ==========${RESET}"

    printf "%-20s : " "HAProxy"

    if systemctl is-active --quiet haproxy; then
        echo -e "${GREEN}ONLINE${RESET}"
    else
        echo -e "${RED}OFFLINE${RESET}"
    fi

    printf "%-20s : " "SSH"

    if systemctl is-active --quiet ssh 2>/dev/null ||
       systemctl is-active --quiet sshd 2>/dev/null; then
        echo -e "${GREEN}ONLINE${RESET}"
    else
        echo -e "${RED}OFFLINE${RESET}"
    fi

    echo
    echo -e "${CYAN}Puertos:${RESET}"

    ss -ltnp 2>/dev/null |
        grep -E ':(22|80|443|8080|10001|10002|10003|1013|10015)\b' ||
        true

    echo
}

# -----------------------------
# REINICIO
# -----------------------------

restart_tunnel() {

    require_root

    info "Reiniciando túnel..."

    mkdir -p /run/haproxy

    systemctl restart haproxy

    sleep 2

    if systemctl is-active --quiet haproxy; then
        log "Túnel reiniciado correctamente."
    else
        error "HAProxy no está funcionando."
    fi
}

# -----------------------------
# REPARACIÓN
# -----------------------------

repair_tunnel() {

    require_root

    banner

    info "Iniciando reparación..."

    mkdir -p /run/haproxy

    if [[ ! -f "$CERT_FILE" ]]; then
        warn "Certificado inexistente."
        generate_certificate
    fi

    if [[ ! -f "$HAPROXY_CFG" ]]; then
        warn "Configuración inexistente."
        write_haproxy_config
    fi

    configure_resilience

    free_haproxy_ports

    validate_haproxy

    systemctl daemon-reload

    systemctl enable haproxy

    systemctl restart haproxy

    sleep 2

    if systemctl is-active --quiet haproxy; then
        log "Reparación completada."
    else
        error "No fue posible recuperar HAProxy."
        journalctl -u haproxy -n 50 --no-pager
    fi
}

# -----------------------------
# LOGS
# -----------------------------

show_logs() {

    require_root

    echo -e "${CYAN}========== HAProxy LOG ==========${RESET}"

    journalctl \
        -u haproxy \
        -n 100 \
        --no-pager
}

# -----------------------------
# DESINSTALAR
# -----------------------------

remove_tunnel() {

    require_root

    echo
    echo -e "${RED}Esto eliminará HAProxy y su configuración.${RESET}"
    read -rp "¿Continuar? [s/N]: " answer

    [[ "$answer" =~ ^[sS]$ ]] || return

    systemctl stop haproxy 2>/dev/null || true
    systemctl disable haproxy 2>/dev/null || true

    rm -f "$HAPROXY_CFG"
    rm -f "$CERT_FILE"

    rm -rf "$RESILIENCE_DIR"

    systemctl daemon-reload

    apt-get remove -y haproxy || true
    apt-get autoremove -y || true

    log "HAProxy eliminado."
}

# -----------------------------
# MENU
# -----------------------------

menu() {

    while true; do

        banner

        echo -e "${WHITE}1)${RESET} Instalar SSL Tunnel"
        echo -e "${WHITE}2)${RESET} Estado del sistema"
        echo -e "${WHITE}3)${RESET} Reiniciar HAProxy"
        echo -e "${WHITE}4)${RESET} Reparar instalación"
        echo -e "${WHITE}5)${RESET} Ver logs"
        echo -e "${WHITE}6)${RESET} Validar configuración"
        echo -e "${WHITE}7)${RESET} Desinstalar"
        echo -e "${WHITE}0)${RESET} Salir"

        echo
        read -rp "Selecciona una opción: " option

        case "$option" in

            1)
                install_tunnel
                read -rp "ENTER para continuar..."
                ;;

            2)
                show_status
                read -rp "ENTER para continuar..."
                ;;

            3)
                restart_tunnel
                read -rp "ENTER para continuar..."
                ;;

            4)
                repair_tunnel
                read -rp "ENTER para continuar..."
                ;;

            5)
                show_logs
                read -rp "ENTER para continuar..."
                ;;

            6)
                validate_haproxy
                read -rp "ENTER para continuar..."
                ;;

            7)
                remove_tunnel
                read -rp "ENTER para continuar..."
                ;;

            0)
                exit 0
                ;;

            *)
                error "Opción inválida."
                sleep 1
                ;;

        esac

    done
}

# ============================================================
# EJECUCIÓN
# ============================================================

case "${1:-menu}" in

    install)
        install_tunnel
        ;;

    status)
        require_root
        show_status
        ;;

    restart)
        restart_tunnel
        ;;

    repair)
        repair_tunnel
        ;;

    logs)
        show_logs
        ;;

    remove)
        remove_tunnel
        ;;

    validate)
        require_root
        validate_haproxy
        ;;

    menu)
        menu
        ;;

    *)
        echo
        echo "Uso:"
        echo "  $0 install"
        echo "  $0 status"
        echo "  $0 restart"
        echo "  $0 repair"
        echo "  $0 logs"
        echo "  $0 validate"
        echo "  $0 remove"
        echo
        ;;

esac