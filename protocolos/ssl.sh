#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    SSL TUNNEL MANAGER
#                         v2.1
# ==============================================================
# Componentes:
#   HAProxy
#   SSL/TLS
#   SSH WebSocket Internal
#
# Puertos:
#   80
#   443
#   8080
#   10015 (interno)
#
# Mejoras v2.1:
#   • WebSocket interno más estable
#   • Limpieza correcta de conexiones
#   • Prevención de CLOSE-WAIT acumulados
#   • Timeout tunnel 7 días
#   • Timeout client/server 7 días
#   • TCP keepalive
#   • Mejor recuperación automática
#   • Validación antes de reiniciar HAProxy
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
VERSION="2.1"

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
CERT_FILE="/etc/haproxy/yha.pem"

SERVICE_FILE="/etc/systemd/system/ssh-ws-internal.service"
PROXY_SCRIPT="/usr/local/bin/ssh-ws-internal.py"

SERVICE_HAPROXY="haproxy"
SERVICE_WS="ssh-ws-internal"

WS_PORT="10015"

PORT_HTTP="80"
PORT_HTTPS="443"
PORT_ALT="8080"

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
    echo -e "${WHITE}SSL Tunnel Manager requiere permisos de root.${RESET}"
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
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
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
# CONFIG.CONF
# ==============================================================

set_config() {

    local KEY="$1"
    local VALUE="$2"

    if grep -q "^${KEY}=" "$CONFIG"; then
        sed -i "s/^${KEY}=.*/${KEY}=${VALUE}/" "$CONFIG"
    else
        echo "${KEY}=${VALUE}" >> "$CONFIG"
    fi
}

# ==============================================================
# SERVICIOS
# ==============================================================

service_exists() {
    systemctl cat "$1" &>/dev/null
}

service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# ==============================================================
# PUERTOS
# ==============================================================

port_in_use() {

    local PORT="$1"

    ss -H -lnt 2>/dev/null |
        awk -v P=":$PORT" '
            $4 ~ P"$" {
                found=1
            }
            END {
                exit !found
            }
        '
}

port_status() {

    local PORT="$1"

    if port_in_use "$PORT"; then
        echo -e "${GREEN}● ESCUCHANDO${RESET}"
    else
        echo -e "${RED}● CERRADO${RESET}"
    fi
}

# ==============================================================
# CONEXIONES
# ==============================================================

show_connections() {

    local PORT="$1"

    echo
    echo -e "${WHITE}Conexiones puerto ${PORT}:${RESET}"

    ss -tan 2>/dev/null |
        awk -v P=":${PORT}" '
            $4 ~ P"$" || $5 ~ P"$" {
                print $1
            }
        ' |
        sort |
        uniq -c |
        sort -nr
}

# ==============================================================
# ESTADO GENERAL
# ==============================================================

get_status() {

    if service_active "$SERVICE_HAPROXY" &&
       service_active "$SERVICE_WS"; then

        echo -e "${GREEN}● ACTIVO${RESET}"

    elif service_active "$SERVICE_HAPROXY" ||
         service_active "$SERVICE_WS"; then

        echo -e "${YELLOW}● PARCIAL${RESET}"

    elif [[ "${SSL:-OFF}" == "ON" ]]; then

        echo -e "${RED}● DETENIDO${RESET}"

    elif [[ -f "$HAPROXY_CFG" ]] ||
         [[ -f "$SERVICE_FILE" ]]; then

        echo -e "${YELLOW}● INSTALADO${RESET}"

    else

        echo -e "${GRAY}● NO INSTALADO${RESET}"

    fi
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
        haproxy \
        openssl \
        python3 \
        curl \
        socat \
        net-tools \
        lsof \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# CERTIFICADO
# ==============================================================

generate_certificate() {

    mkdir -p "$(dirname "$CERT_FILE")"

    if [[ -s "$CERT_FILE" ]]; then
        ok "Certificado SSL encontrado."
        chmod 600 "$CERT_FILE"
        return 0
    fi

    info "Generando certificado SSL..."

    local TMP_KEY="/tmp/kevintech_ssl_key.pem"
    local TMP_CERT="/tmp/kevintech_ssl_cert.pem"

    rm -f "$TMP_KEY" "$TMP_CERT"

    if ! openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 3650 \
        -keyout "$TMP_KEY" \
        -out "$TMP_CERT" \
        -subj "/CN=${SERVER_DOMAIN:-ssl-tunnel}" \
        >/dev/null 2>&1; then

        error_msg "No se pudo generar el certificado."

        rm -f "$TMP_KEY" "$TMP_CERT"

        return 1
    fi

    cat "$TMP_KEY" "$TMP_CERT" > "$CERT_FILE"

    rm -f "$TMP_KEY" "$TMP_CERT"

    chmod 600 "$CERT_FILE"

    if [[ ! -s "$CERT_FILE" ]]; then
        error_msg "El certificado no fue creado correctamente."
        return 1
    fi

    ok "Certificado SSL creado."

    return 0
}

# ==============================================================
# COMPROBAR PUERTOS
# ==============================================================

check_ports() {

    local PORT
    local FAILED=0

    for PORT in "$PORT_HTTP" "$PORT_HTTPS" "$PORT_ALT"; do

        if port_in_use "$PORT"; then

            warning "El puerto $PORT ya está ocupado."

            ss -lntp 2>/dev/null |
                grep -E ":${PORT}([[:space:]]|$)" ||
                true

            FAILED=1
        fi

    done

    if [[ "$FAILED" -eq 1 ]]; then

        echo
        error_msg "No se pueden utilizar todos los puertos requeridos."

        return 1
    fi

    return 0
}

# ==============================================================
# LIMPIAR WS ANTIGUOS
# ==============================================================

remove_old_ws() {

    info "Limpiando servicios WebSocket anteriores..."

    systemctl stop ssh-ws.service 2>/dev/null
    systemctl stop ssh-wss.service 2>/dev/null

    systemctl disable ssh-ws.service 2>/dev/null
    systemctl disable ssh-wss.service 2>/dev/null

    rm -f /etc/systemd/system/ssh-ws.service
    rm -f /etc/systemd/system/ssh-wss.service

    systemctl daemon-reload

    ok "Configuraciones antiguas limpiadas."
}

# ==============================================================
# SSH WEBSOCKET INTERNAL
# ==============================================================
#
# IMPORTANTE:
# El proceso escucha únicamente en 127.0.0.1:10015.
#
# El cierre de una dirección provoca el cierre controlado
# de toda la sesión para evitar conexiones CLOSE-WAIT.
# ==============================================================

install_ssh_ws_internal() {

    info "Instalando SSH WebSocket Internal v2.1..."

    cat > "$PROXY_SCRIPT" <<'PYEOF'
#!/usr/bin/env python3

import asyncio
import signal
import sys

BUFFER_SIZE = 65536

SSH_HOST = "127.0.0.1"
SSH_PORT = 22

CONNECT_TIMEOUT = 10

HTTP_101 = (
    b"HTTP/1.1 101 Switching Protocols\r\n"
    b"Upgrade: websocket\r\n"
    b"Connection: Upgrade\r\n\r\n"
)

HTTP_200 = (
    b"HTTP/1.1 200 Connection established\r\n"
    b"Connection: keep-alive\r\n\r\n"
)


async def close_writer(writer):
    if writer is None:
        return

    try:
        writer.close()
    except Exception:
        return

    try:
        await writer.wait_closed()
    except Exception:
        pass


async def pipe(reader, writer):

    try:

        while True:

            data = await reader.read(BUFFER_SIZE)

            if not data:
                break

            writer.write(data)

            await writer.drain()

    except (
        ConnectionResetError,
        BrokenPipeError,
        ConnectionAbortedError,
        asyncio.IncompleteReadError,
        asyncio.CancelledError
    ):

        pass

    except Exception:

        pass


async def handle(client_reader, client_writer):

    ssh_reader = None
    ssh_writer = None

    client_closed = False

    try:

        # ------------------------------------------------------
        # Recibir primer paquete
        # ------------------------------------------------------

        try:

            payload = await asyncio.wait_for(
                client_reader.read(BUFFER_SIZE),
                timeout=CONNECT_TIMEOUT
            )

        except asyncio.TimeoutError:

            return

        if not payload:
            return

        # ------------------------------------------------------
        # Detectar WebSocket / HTTP
        # ------------------------------------------------------

        text = payload.decode(
            "utf-8",
            errors="ignore"
        )

        upper = text.upper()

        is_websocket = (
            "UPGRADE: WEBSOCKET" in upper
            or (
                "UPGRADE" in upper
                and "WEBSOCKET" in upper
            )
        )

        if is_websocket:

            client_writer.write(HTTP_101)

        else:

            client_writer.write(HTTP_200)

        await client_writer.drain()

        # ------------------------------------------------------
        # Conectar a SSH
        # ------------------------------------------------------

        try:

            ssh_reader, ssh_writer = await asyncio.wait_for(
                asyncio.open_connection(
                    SSH_HOST,
                    SSH_PORT,
                    limit=BUFFER_SIZE
                ),
                timeout=CONNECT_TIMEOUT
            )

        except (
            asyncio.TimeoutError,
            ConnectionRefusedError,
            OSError
        ):

            return

        # ------------------------------------------------------
        # IMPORTANTE:
        #
        # El primer payload ya fue consumido.
        # Debemos enviarlo inmediatamente al SSH.
        # ------------------------------------------------------

        ssh_writer.write(payload)
        await ssh_writer.drain()

        # ------------------------------------------------------
        # Crear los dos sentidos
        # ------------------------------------------------------

        task_client_to_ssh = asyncio.create_task(
            pipe(client_reader, ssh_writer)
        )

        task_ssh_to_client = asyncio.create_task(
            pipe(ssh_reader, client_writer)
        )

        # ------------------------------------------------------
        # Esperar a que uno termine
        # ------------------------------------------------------

        done, pending = await asyncio.wait(
            {
                task_client_to_ssh,
                task_ssh_to_client
            },
            return_when=asyncio.FIRST_COMPLETED
        )

        # ------------------------------------------------------
        # Cancelar inmediatamente el otro sentido.
        #
        # Esto evita dejar una mitad de la conexión abierta.
        # ------------------------------------------------------

        for task in pending:

            task.cancel()

        if pending:

            await asyncio.gather(
                *pending,
                return_exceptions=True
            )

        for task in done:

            try:
                task.result()
            except Exception:
                pass

    except (
        ConnectionResetError,
        BrokenPipeError,
        ConnectionAbortedError,
        asyncio.CancelledError
    ):

        pass

    except Exception:

        pass

    finally:

        # ------------------------------------------------------
        # Cierre completo y ordenado
        # ------------------------------------------------------

        await close_writer(ssh_writer)
        await close_writer(client_writer)


async def main(port):

    server = await asyncio.start_server(
        handle,
        host="127.0.0.1",
        port=port,
        limit=BUFFER_SIZE,
        reuse_address=True
    )

    print(
        f"SSH WebSocket Internal escuchando "
        f"en 127.0.0.1:{port}",
        flush=True
    )

    async with server:

        await server.serve_forever()


def run():

    port = (
        int(sys.argv[1])
        if len(sys.argv) > 1
        else 10015
    )

    try:

        asyncio.run(main(port))

    except KeyboardInterrupt:

        pass


if __name__ == "__main__":

    run()

PYEOF

    chmod 755 "$PROXY_SCRIPT"

    # ----------------------------------------------------------
    # SYSTEMD
    # ----------------------------------------------------------

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech SSH WebSocket Internal v2.1
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple

ExecStart=/usr/bin/python3 $PROXY_SCRIPT $WS_PORT

Restart=always
RestartSec=3

KillMode=mixed
TimeoutStopSec=10

LimitNOFILE=65535
LimitNPROC=4096

NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE_WS" >/dev/null 2>&1; then

        error_msg "No se pudo habilitar $SERVICE_WS."

        return 1
    fi

    systemctl restart "$SERVICE_WS"

    sleep 1

    if service_active "$SERVICE_WS"; then

        ok "SSH WebSocket Internal activo."

        return 0
    fi

    error_msg "SSH WebSocket Internal no pudo iniciar."

    journalctl \
        -u "$SERVICE_WS" \
        -n 20 \
        --no-pager 2>/dev/null

    return 1
}

# ==============================================================
# CONFIGURACIÓN HAPROXY
# ==============================================================

create_haproxy_config() {

    mkdir -p /etc/haproxy

    info "Generando configuración HAProxy v2.1..."

    cat > "$HAPROXY_CFG" <<'EOF'
global

    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 1d

    tune.bufsize 10485760
    tune.maxrewrite 3072
    tune.ssl.default-dh-param 2048

    pidfile /run/haproxy.pid

    chroot /var/lib/haproxy

    user haproxy
    group haproxy

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384

    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256

    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private


defaults

    log global

    mode tcp

    option dontlognull
    option tcp-smart-connect
    option tcpka

    timeout connect 10s

    # Sesiones largas
    timeout client 7d
    timeout server 7d
    timeout tunnel 7d

    # Tiempo máximo esperando una petición inicial
    timeout http-request 30s


frontend multiport_frontend

    mode tcp

    bind *:443

    tcp-request inspect-delay 10ms

    tcp-request content accept if HTTP
    tcp-request content accept if { req.ssl_hello_type 1 }

    use_backend recir_http_backend if HTTP

    default_backend recir_https_backend


backend recir_https_backend

    mode tcp

    server recir_https_server abns@haproxy-https send-proxy-v2 check


backend recir_http_backend

    mode tcp

    server recir_http_server abns@haproxy-http send-proxy-v2 check


frontend multiports_frontend

    mode tcp

    bind abns@haproxy-http accept-proxy

    default_backend recir_https_www_backend


backend recir_https_www_backend

    mode tcp

    server recir_https_www_server 127.0.0.1:2223 check


frontend ssl_frontend

    mode tcp

    bind *:80
    bind *:8080

    bind abns@haproxy-https accept-proxy ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1

    tcp-request inspect-delay 200ms

    tcp-request content capture req.ssl_sni len 100

    tcp-request content accept if { req.ssl_hello_type 1 }

    acl acl_upgrade hdr(Connection) -i upgrade
    acl acl_websocket hdr(Upgrade) -i websocket

    acl acl_payload payload(0,7) -m bin 5353482d322e30

    acl acl_http2 ssl_fc_alpn -i h2

    acl acl_path_regex path_reg -i ^\/(.*)

    acl acl_path_vless path_reg -i ^\/vless.*

    acl acl_path_vmess path_reg -i ^\/vmess.*

    acl acl_path_trojan path_reg -i ^\/trojan-ws.*

    acl acl_path_grpc path_reg -i ^\/(vmess-grpc|trojan-grpc|ss-grpc).*

    acl acl_path_ssh path_reg -i ^\/fightertunnelssh.*

    use_backend grpc_backend if acl_http2

    use_backend payload_backend if acl_path_vless
    use_backend payload_backend if acl_path_vmess
    use_backend payload_backend if acl_path_trojan
    use_backend payload_backend if acl_path_grpc

    use_backend ssh_backend if acl_path_ssh

    use_backend websocket_backend if acl_upgrade acl_websocket

    use_backend websocket_backend if acl_path_regex

    use_backend bot_ftvpn_backend if acl_payload

    default_backend ssh_ws_default_backend


backend websocket_backend

    mode tcp

    option tcpka

    server ssh_ws_server 127.0.0.1:10015 check


backend grpc_backend

    mode tcp

    option tcpka

    server grpc_server 127.0.0.1:1013 check


backend ssh_ws_default_backend

    mode tcp

    option tcpka

    server ssh_ws_server 127.0.0.1:10015 check


backend bot_ftvpn_backend

    mode tcp

    option tcpka

    server ssh_direct 127.0.0.1:22 check


backend payload_backend

    mode tcp

    option tcpka

    balance roundrobin

    server payload_server_vless   127.0.0.1:10001 check
    server payload_server_vmess   127.0.0.1:10002 check
    server payload_server_trojan  127.0.0.1:10003 check
    server payload_server_grpc    127.0.0.1:10004 check

    server payload_server_vless2  127.0.0.1:10005 check
    server payload_server_vmess2  127.0.0.1:10006 check
    server payload_server_trojan2 127.0.0.1:10007 check
    server payload_server_grpc2   127.0.0.1:10008 check

    server ssh_server             127.0.0.1:10015 check


backend ssh_backend

    mode tcp

    option tcpka

    server ssh_server 127.0.0.1:10015 check
EOF

    # ----------------------------------------------------------
    # VALIDAR ANTES DE REINICIAR
    # ----------------------------------------------------------

    if ! haproxy -c -f "$HAPROXY_CFG"; then

        error_msg "La configuración de HAProxy contiene errores."

        return 1
    fi

    ok "Configuración HAProxy válida."

    return 0
}

# ==============================================================
# RESILIENCIA HAPROXY
# ==============================================================

ensure_haproxy_resilience() {

    local DIR="/etc/systemd/system/haproxy.service.d"
    local FILE="$DIR/10-kevintech-resilience.conf"

    mkdir -p "$DIR"

    cat > "$FILE" <<EOF
[Unit]
After=network-online.target $SERVICE_WS.service
Wants=network-online.target $SERVICE_WS.service

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
LimitNOFILE=65535
EOF

    systemctl daemon-reload

    ok "Recuperación automática configurada."
}

# ==============================================================
# INSTALAR SSL TUNNEL
# ==============================================================

install_ssl_tunnel() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 INSTALAR SSL TUNNEL${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Dominio:${RESET} ${GREEN}${SERVER_DOMAIN:-NO CONFIGURADO}${RESET}"
    echo -e "${WHITE}Puertos:${RESET} ${CYAN}$PORT_HTTP, $PORT_HTTPS, $PORT_ALT${RESET}"
    echo

    if ! install_dependencies; then
        pause
        return 1
    fi

    if ! generate_certificate; then
        pause
        return 1
    fi

    if ! check_ports; then
        warning "No se modificarán los servicios que ocupan esos puertos."
        pause
        return 1
    fi

    remove_old_ws

    if ! install_ssh_ws_internal; then
        pause
        return 1
    fi

    if ! create_haproxy_config; then
        pause
        return 1
    fi

    ensure_haproxy_resilience

    info "Iniciando HAProxy..."

    systemctl enable "$SERVICE_HAPROXY" >/dev/null 2>&1

    if ! systemctl restart "$SERVICE_HAPROXY"; then

        error_msg "No se pudo reiniciar HAProxy."

        journalctl \
            -u "$SERVICE_HAPROXY" \
            -n 20 \
            --no-pager 2>/dev/null

        set_config "SSL" "OFF"
        set_config "SSL_TUNNEL" "OFF"

        pause

        return 1
    fi

    sleep 2

    if ! service_active "$SERVICE_HAPROXY"; then

        error_msg "HAProxy no pudo iniciar."

        journalctl \
            -u "$SERVICE_HAPROXY" \
            -n 20 \
            --no-pager 2>/dev/null

        set_config "SSL" "OFF"
        set_config "SSL_TUNNEL" "OFF"

        pause

        return 1
    fi

    set_config "SSL" "ON"
    set_config "SSL_TUNNEL" "ON"

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}              ${BOLD}✔ SSL TUNNEL ACTIVADO${RESET}                   ${GREEN}║${RESET}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}║${RESET}  HAProxy       : ACTIVO"
    echo -e "${GREEN}║${RESET}  SSH WebSocket : ACTIVO"
    echo -e "${GREEN}║${RESET}  HTTP          : $PORT_HTTP"
    echo -e "${GREEN}║${RESET}  HTTPS         : $PORT_HTTPS"
    echo -e "${GREEN}║${RESET}  Alternativo   : $PORT_ALT"
    echo -e "${GREEN}║${RESET}  Backend       : 127.0.0.1:$WS_PORT"
    echo -e "${GREEN}║${RESET}  Tunnel timeout: 7 días"
    echo -e "${GREEN}║${RESET}  TCP Keepalive : ACTIVADO"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause

    return 0
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_ssl_tunnel() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}♻️ REINICIAR SSL TUNNEL${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! service_exists "$SERVICE_HAPROXY"; then

        error_msg "HAProxy no está instalado."

        pause

        return
    fi

    info "Reiniciando SSH WebSocket..."

    systemctl restart "$SERVICE_WS"

    sleep 1

    if ! service_active "$SERVICE_WS"; then

        error_msg "SSH WebSocket no pudo iniciar."

        journalctl \
            -u "$SERVICE_WS" \
            -n 20 \
            --no-pager 2>/dev/null

        pause

        return
    fi

    info "Validando configuración HAProxy..."

    if ! haproxy -c -f "$HAPROXY_CFG"; then

        error_msg "La configuración de HAProxy no es válida."

        pause

        return
    fi

    info "Reiniciando HAProxy..."

    if ! systemctl restart "$SERVICE_HAPROXY"; then

        error_msg "HAProxy no pudo reiniciarse."

        journalctl \
            -u "$SERVICE_HAPROXY" \
            -n 20 \
            --no-pager 2>/dev/null

        pause

        return
    fi

    sleep 2

    if service_active "$SERVICE_HAPROXY"; then

        set_config "SSL" "ON"
        set_config "SSL_TUNNEL" "ON"

        ok "SSL Tunnel reiniciado correctamente."

    else

        set_config "SSL" "OFF"
        set_config "SSL_TUNNEL" "OFF"

        error_msg "HAProxy no pudo iniciar."

    fi

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

show_status() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}                ${MAGENTA}${BOLD}📊 SSL TUNNEL STATUS${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                     ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Estado general:${RESET} $(get_status)"

    echo
    echo -e "${WHITE}HAProxy:${RESET}"

    if service_active "$SERVICE_HAPROXY"; then
        echo -e "  ${GREEN}● ACTIVO${RESET}"
    else
        echo -e "  ${RED}● DETENIDO${RESET}"
    fi

    echo
    echo -e "${WHITE}SSH WebSocket:${RESET}"

    if service_active "$SERVICE_WS"; then
        echo -e "  ${GREEN}● ACTIVO${RESET}"
    else
        echo -e "  ${RED}● DETENIDO${RESET}"
    fi

    line

    echo -e "${WHITE}Puertos:${RESET}"

    echo -e "  HTTP  $PORT_HTTP    $(port_status "$PORT_HTTP")"
    echo -e "  HTTPS $PORT_HTTPS   $(port_status "$PORT_HTTPS")"
    echo -e "  ALT   $PORT_ALT     $(port_status "$PORT_ALT")"
    echo -e "  WS    $WS_PORT      $(port_status "$WS_PORT")"

    line

    echo -e "${WHITE}Conexiones WS:${RESET}"

    ss -tan 2>/dev/null |
        awk -v P=":${WS_PORT}" '
            $4 ~ P"$" || $5 ~ P"$" {
                print $1
            }
        ' |
        sort |
        uniq -c |
        sort -nr

    line

    echo -e "${WHITE}Dominio:${RESET}        ${GREEN}${SERVER_DOMAIN:-NO CONFIGURADO}${RESET}"
    echo -e "${WHITE}Certificado:${RESET}    ${GREEN}$CERT_FILE${RESET}"
    echo -e "${WHITE}HAProxy config:${RESET} ${GREEN}$HAPROXY_CFG${RESET}"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostic_ssl() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🔎 DIAGNÓSTICO SSL TUNNEL${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Componentes:${RESET}"
    echo

    if command -v haproxy >/dev/null 2>&1; then
        ok "HAProxy instalado"
    else
        error_msg "HAProxy no instalado"
    fi

    if command -v openssl >/dev/null 2>&1; then
        ok "OpenSSL disponible"
    else
        error_msg "OpenSSL no disponible"
    fi

    if command -v python3 >/dev/null 2>&1; then
        ok "Python3 disponible"
    else
        error_msg "Python3 no disponible"
    fi

    if [[ -f "$HAPROXY_CFG" ]]; then

        if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
            ok "Configuración HAProxy válida"
        else
            error_msg "Configuración HAProxy inválida"
        fi

    else

        error_msg "haproxy.cfg no encontrado"

    fi

    if [[ -s "$CERT_FILE" ]]; then
        ok "Certificado SSL encontrado"
    else
        error_msg "Certificado SSL no encontrado"
    fi

    if service_active "$SERVICE_WS"; then
        ok "SSH WebSocket activo"
    else
        error_msg "SSH WebSocket detenido"
    fi

    if service_active "$SERVICE_HAPROXY"; then
        ok "HAProxy activo"
    else
        error_msg "HAProxy detenido"
    fi

    echo
    echo -e "${WHITE}Puertos:${RESET}"

    echo -e "  80     $(port_status 80)"
    echo -e "  443    $(port_status 443)"
    echo -e "  8080   $(port_status 8080)"
    echo -e "  10015  $(port_status 10015)"

    echo
    echo -e "${WHITE}Conexiones 10015:${RESET}"

    ss -tan 2>/dev/null |
        awk -v P=":${WS_PORT}" '
            $4 ~ P"$" || $5 ~ P"$" {
                print $1
            }
        ' |
        sort |
        uniq -c |
        sort -nr

    echo
    echo -e "${WHITE}CLOSE-WAIT en 10015:${RESET}"

    CLOSE_WAIT_COUNT=$(
        ss -tan 2>/dev/null |
            awk -v P=":${WS_PORT}" '
                $1 == "CLOSE-WAIT" &&
                ($4 ~ P"$" || $5 ~ P"$") {
                    count++
                }
                END {
                    print count+0
                }
            '
    )

    if [[ "$CLOSE_WAIT_COUNT" -eq 0 ]]; then
        echo -e "  ${GREEN}✔ 0 CLOSE-WAIT${RESET}"
    elif [[ "$CLOSE_WAIT_COUNT" -lt 20 ]]; then
        echo -e "  ${YELLOW}⚠ $CLOSE_WAIT_COUNT CLOSE-WAIT${RESET}"
    else
        echo -e "  ${RED}✘ $CLOSE_WAIT_COUNT CLOSE-WAIT${RESET}"
    fi

    echo
    echo -e "${WHITE}Últimos registros HAProxy:${RESET}"

    journalctl \
        -u "$SERVICE_HAPROXY" \
        -n 10 \
        --no-pager 2>/dev/null

    echo
    echo -e "${WHITE}Últimos registros SSH WebSocket:${RESET}"

    journalctl \
        -u "$SERVICE_WS" \
        -n 10 \
        --no-pager 2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

show_logs() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}                 ${MAGENTA}${BOLD}📜 SSL TUNNEL LOGS${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}1. HAProxy${RESET}"
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

    journalctl \
        -u "$SERVICE_HAPROXY" \
        -n 30 \
        --no-pager 2>/dev/null

    echo
    echo -e "${WHITE}2. SSH WebSocket${RESET}"
    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

    journalctl \
        -u "$SERVICE_WS" \
        -n 30 \
        --no-pager 2>/dev/null

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_ssl_tunnel() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${RED}${BOLD}🗑️ DESINSTALAR SSL TUNNEL${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    warning "Se eliminarán la configuración del túnel,"
    warning "el certificado, el proxy interno y los servicios creados."
    echo

    read -rp "$(echo -e "${RED}Escribe ELIMINAR para continuar: ${RESET}")" CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        sleep 1

        return
    fi

    echo

    info "Deteniendo servicios..."

    systemctl stop "$SERVICE_HAPROXY" 2>/dev/null
    systemctl stop "$SERVICE_WS" 2>/dev/null

    info "Deshabilitando servicios..."

    systemctl disable "$SERVICE_HAPROXY" 2>/dev/null
    systemctl disable "$SERVICE_WS" 2>/dev/null

    info "Eliminando servicio WebSocket..."

    rm -f "$SERVICE_FILE"

    info "Eliminando resiliencia de HAProxy..."

    rm -f \
        /etc/systemd/system/haproxy.service.d/10-kevintech-resilience.conf

    rmdir \
        /etc/systemd/system/haproxy.service.d \
        2>/dev/null || true

    info "Eliminando proxy interno..."

    rm -f "$PROXY_SCRIPT"

    info "Eliminando certificado..."

    rm -f "$CERT_FILE"

    info "Eliminando configuración HAProxy..."

    rm -f "$HAPROXY_CFG"

    systemctl daemon-reload

    systemctl reset-failed \
        "$SERVICE_HAPROXY" \
        "$SERVICE_WS" \
        2>/dev/null

    set_config "SSL" "OFF"
    set_config "SSL_TUNNEL" "OFF"

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}              ${BOLD}✔ SSL TUNNEL ELIMINADO${RESET}                   ${GREEN}║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}${BOLD}             🚀 INSTALACIÓN AUTOMÁTICA${RESET}"
    echo -e "${WHITE}                    SSL TUNNEL v${VERSION}${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    if install_ssl_tunnel; then

        echo
        ok "SSL Tunnel instalado correctamente."

        exit 0

    else

        echo
        error_msg "La instalación automática falló."

        exit 1
    fi
fi

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

while true; do

    clear

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}               ${MAGENTA}${BOLD}🔐 SSL TUNNEL MANAGER${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                  ${GRAY}HAProxy / TLS v$VERSION${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE}Estado:${RESET}       $(get_status)"

    echo -e "${WHITE}Dominio:${RESET}      ${GREEN}${SERVER_DOMAIN:-NO CONFIGURADO}${RESET}"

    echo -e "${WHITE}HAProxy:${RESET}      $(
        if service_active "$SERVICE_HAPROXY"; then
            echo -e "${GREEN}● ACTIVO${RESET}"
        else
            echo -e "${RED}● DETENIDO${RESET}"
        fi
    )"

    echo -e "${WHITE}SSH WebSocket:${RESET} $(
        if service_active "$SERVICE_WS"; then
            echo -e "${GREEN}● ACTIVO${RESET}"
        else
            echo -e "${RED}● DETENIDO${RESET}"
        fi
    )"

    line

    echo -e "${WHITE}Puertos:${RESET}"

    echo -e "  HTTP  $PORT_HTTP    $(port_status "$PORT_HTTP")"
    echo -e "  HTTPS $PORT_HTTPS   $(port_status "$PORT_HTTPS")"
    echo -e "  ALT   $PORT_ALT     $(port_status "$PORT_ALT")"

    line

    if [[ -f "$HAPROXY_CFG" ]] ||
       service_exists "$SERVICE_HAPROXY"; then

        echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN SSL TUNNEL${RESET}"
        echo

        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🔄 Reinstalar / Actualizar"
        echo -e "  ${GREEN}${BOLD}[02]${RESET} ♻️  Reiniciar Servicios"
        echo -e "  ${GREEN}${BOLD}[03]${RESET} 📊 Estado Detallado"
        echo -e "  ${GREEN}${BOLD}[04]${RESET} 🔎 Diagnóstico"
        echo -e "  ${GREEN}${BOLD}[05]${RESET} 📜 Ver Logs"
        echo -e "  ${GREEN}${BOLD}[06]${RESET} 🗑️  Desinstalar"

    else

        echo -e "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"
        echo

        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar SSL Tunnel"

    fi

    echo
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  ${WHITE}Regresar al Menú de Protocolos${RESET}"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)
            install_ssl_tunnel
            ;;

        2)
            restart_ssl_tunnel
            ;;

        3)
            show_status
            ;;

        4)
            diagnostic_ssl
            ;;

        5)
            show_logs
            ;;

        6)
            remove_ssl_tunnel
            ;;

        0)
            clear
            exec bash "$BASE/protocolos/menu.sh"
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