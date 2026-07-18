#!/bin/bash
#==================================================
# KevinTech Multi Script
# SSL Tunnel Manager
# Parte 1
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
CERT_FILE="/etc/haproxy/yha.pem"
SERVICE_FILE="/etc/systemd/system/ssh-ws-internal.service"
PROXY_SCRIPT="/usr/local/bin/ssh-ws-internal.py"
BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

msg_ok() {
    echo -e "${GREEN}✔${RESET} $1"
}

msg_error() {
    echo -e "${RED}✘${RESET} $1"
}

msg_info() {
    echo -e "${YELLOW}➜${RESET} $1"
}

install_dependencies() {

    msg_info "Actualizando repositorios..."
    apt-get update -y >/dev/null 2>&1

    msg_info "Instalando dependencias..."

    apt-get install -y \
        haproxy \
        openssl \
        python3 \
        curl \
        socat \
        net-tools \
        lsof >/dev/null 2>&1

    if [[ $? == 0 ]]; then
        msg_ok "Dependencias instaladas."
    else
        msg_error "No se pudieron instalar."
        return 1
    fi

}

generate_certificate() {

    if [[ -f "$CERT_FILE" ]]; then
        msg_ok "Certificado encontrado."
        return
    fi

    msg_info "Generando certificado SSL..."

    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 3650 \
        -keyout /tmp/key.pem \
        -out /tmp/cert.pem \
        -subj "/CN=ssl-tunnel"

    cat /tmp/key.pem /tmp/cert.pem > "$CERT_FILE"

    rm -f /tmp/key.pem
    rm -f /tmp/cert.pem

    chmod 600 "$CERT_FILE"

    msg_ok "Certificado creado."

}

kill_ports() {

    msg_info "Liberando puertos..."

    fuser -k 80/tcp >/dev/null 2>&1
    fuser -k 443/tcp >/dev/null 2>&1
    fuser -k 8080/tcp >/dev/null 2>&1

    msg_ok "Puertos liberados."

}

remove_old_ws() {

    systemctl stop ssh-ws.service >/dev/null 2>&1
    systemctl stop ssh-wss.service >/dev/null 2>&1

    systemctl disable ssh-ws.service >/dev/null 2>&1
    systemctl disable ssh-wss.service >/dev/null 2>&1

    rm -f /etc/systemd/system/ssh-ws.service
    rm -f /etc/systemd/system/ssh-wss.service

}

ssl_tunnel_status() {

    line

    if systemctl is-active --quiet haproxy; then
        echo -e "${GREEN}HAProxy : ACTIVO${RESET}"
    else
        echo -e "${RED}HAProxy : DETENIDO${RESET}"
    fi

    if systemctl is-active --quiet ssh-ws-internal.service; then
        echo -e "${GREEN}SSH WS : ACTIVO${RESET}"
    else
        echo -e "${RED}SSH WS : DETENIDO${RESET}"
    fi

    line

}

restart_ssl_tunnel() {

    systemctl restart ssh-ws-internal.service
    systemctl restart haproxy

    msg_ok "Servicios reiniciados."

}

remove_ssl_tunnel() {

    systemctl stop haproxy
    systemctl disable haproxy

    systemctl stop ssh-ws-internal.service
    systemctl disable ssh-ws-internal.service

    rm -f "$HAPROXY_CFG"
    rm -f "$CERT_FILE"
    rm -f "$SERVICE_FILE"
    rm -f "$PROXY_SCRIPT"

    systemctl daemon-reload
grep -q "^WEBSOCKET=" "$CONFIG" \
    && sed -i 's/^WEBSOCKET=.*/WEBSOCKET=OFF/' "$CONFIG"

grep -q "^WS_PORT=" "$CONFIG" \
    && sed -i 's/^WS_PORT=.*/WS_PORT=OFF/' "$CONFIG"
    msg_ok "SSL Tunnel eliminado."

}

ssl_tunnel_menu() {

while true
do
clear

source "$CONFIG" 2>/dev/null

if systemctl is-active --quiet haproxy; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          🔐 SSL TUNNEL MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado      : $STATUS"
echo -e " Dominio     : ${SERVER_DOMAIN:-NO CONFIGURADO}"
echo -e " Puertos     : 80, 443, 8080"
echo -e " Servicio    : HAProxy"
echo -e " Backend     : SSH WebSocket"
echo -e " Certificado : Auto Firmado"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if systemctl is-active --quiet haproxy; then

echo " [1] ➮ Reinstalar SSL Tunnel"
echo " [2] ➮ Reiniciar Servicios"
echo " [3] ➮ Ver Estado"
echo " [4] ➮ Desinstalar SSL Tunnel"
echo
echo " [0] ➮ Regresar"

else

echo " [1] ➮ Instalar SSL Tunnel"
echo
echo " [0] ➮ Regresar"

fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " opc

case "$opc" in

1)
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      INSTALANDO SSL TUNNEL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

install_ssl_tunnel

sleep 3
;;

2)

if systemctl is-active --quiet haproxy; then
    restart_ssl_tunnel
else
    echo "❌ SSL Tunnel no está instalado."
    sleep 3
fi

;;

3)

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ESTADO DEL SERVICIO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

ssl_tunnel_status

echo
read -n1 -r -p "Presione una tecla para continuar..."
;;

4)

if systemctl is-active --quiet haproxy; then
    remove_ssl_tunnel
    sleep 3
else
    echo "❌ SSL Tunnel no está instalado."
    sleep 3
fi

;;

0)

break
;;

*)

echo
echo "❌ Opción inválida."
sleep 2
;;

esac

done

}
create_haproxy_config() {

cat >/etc/haproxy/haproxy.cfg <<'EOF'
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
    daemon

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

frontend multiport_frontend
    mode tcp

    bind *:443 tfo

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

    server recir_http_server \
        abns@haproxy-http \
        send-proxy-v2 \
        check

frontend multiports_frontend
    mode tcp

    bind abns@haproxy-http accept-proxy tfo

    default_backend recir_https_www_backend

backend recir_https_www_backend
    mode tcp

    server recir_https_www_server 127.0.0.1:2223 check

frontend ssl_frontend

    mode tcp

    bind *:80 tfo
    bind *:8080 tfo

    bind abns@haproxy-https accept-proxy ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo

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

    server ssh_ws_server 127.0.0.1:10015 check

backend grpc_backend
    mode tcp

    server grpc_server 127.0.0.1:1013 check

backend ssh_ws_default_backend
    mode tcp

    balance roundrobin

    server ssh_ws_server 127.0.0.1:10015 check

backend bot_ftvpn_backend
    mode tcp

    server ssh_direct 127.0.0.1:22 check
backend payload_backend
    mode tcp

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

    server ssh_server 127.0.0.1:10015 check

EOF

    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then

        msg_ok "Configuración HAProxy creada correctamente."

    else

        msg_error "La configuración contiene errores."

        haproxy -c -f /etc/haproxy/haproxy.cfg

        return 1

    fi

    systemctl daemon-reload

    systemctl enable haproxy >/dev/null 2>&1

    systemctl restart haproxy

    if systemctl is-active --quiet haproxy; then

        msg_ok "HAProxy iniciado correctamente."

    else

        msg_error "HAProxy no pudo iniciar."

    fi

}
install_ssh_ws_internal() {

cat > /usr/local/bin/ssh-ws-internal.py <<'PYEOF'
#!/usr/bin/env python3

import asyncio
import signal
import sys

BUFFER_SIZE = 65536

SSH_HOST = "127.0.0.1"
SSH_PORT = 22

RESPONSE_101 = (
    b"HTTP/1.1 101 Switching Protocols\r\n"
    b"Upgrade: websocket\r\n"
    b"Connection: Upgrade\r\n\r\n"
)

RESPONSE_200 = (
    b"HTTP/1.1 200 Connection established\r\n\r\n"
)

active = 0


async def pipe(reader, writer):

    try:

        while True:

            data = await reader.read(BUFFER_SIZE)

            if not data:
                break

            writer.write(data)
            await writer.drain()

    except:

        pass

    finally:

        try:
            writer.close()
        except:
            pass


async def handle(client_reader, client_writer):

    global active

    active += 1

    ssh_writer = None

    try:

        try:

            payload = await asyncio.wait_for(
                client_reader.read(BUFFER_SIZE),
                timeout=10
            )

        except asyncio.TimeoutError:

            client_writer.close()

            active -= 1

            return

        if not payload:

            client_writer.close()

            active -= 1

            return

        request = payload.decode(
            "utf-8",
            errors="ignore"
        ).upper()

        if "UPGRADE" in request or "WEBSOCKET" in request:

            client_writer.write(RESPONSE_101)

        else:

            client_writer.write(RESPONSE_200)

        await client_writer.drain()

        try:

            ssh_reader, ssh_writer = await asyncio.open_connection(
                SSH_HOST,
                SSH_PORT
            )

        except:

            client_writer.close()

            active -= 1

            return

        await asyncio.gather(

            pipe(client_reader, ssh_writer),

            pipe(ssh_reader, client_writer)

        )

    except:

        pass
    finally:

        active -= 1

        try:
            client_writer.close()
        except:
            pass

        if ssh_writer:

            try:
                ssh_writer.close()
            except:
                pass


async def start(port):

    server = await asyncio.start_server(
        handle,
        "127.0.0.1",
        port
    )

    async with server:

        await server.serve_forever()


def main():

    port = int(sys.argv[1]) if len(sys.argv) > 1 else 10015

    loop = asyncio.new_event_loop()

    asyncio.set_event_loop(loop)

    for sig in (signal.SIGTERM, signal.SIGINT):

        try:

            loop.add_signal_handler(
                sig,
                lambda: loop.stop()
            )

        except:

            pass

    try:

        loop.run_until_complete(start(port))

    except KeyboardInterrupt:

        pass

    finally:

        loop.close()


if __name__ == "__main__":

    main()

PYEOF

chmod +x /usr/local/bin/ssh-ws-internal.py

cat >/etc/systemd/system/ssh-ws-internal.service <<EOF
[Unit]
Description=SSH WebSocket Proxy Internal
After=network.target ssh.service sshd.service
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws-internal.py 10015
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-ws-internal.service >/dev/null 2>&1
systemctl restart ssh-ws-internal.service

if systemctl is-active --quiet ssh-ws-internal.service; then

    msg_ok "SSH WebSocket Internal iniciado correctamente."

else

    msg_error "No fue posible iniciar SSH WebSocket Internal."

fi

}
install_ssl_tunnel() {

    line
    msg_info "Iniciando instalación del SSL Tunnel..."
    line

    install_dependencies || return 1

generate_certificate || return 1

kill_ports

remove_old_ws

install_ssh_ws_internal || return 1

create_haproxy_config || return 1

ensure_haproxy_resilience

    if ! haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then

        msg_error "La configuración de HAProxy es inválida."

        haproxy -c -f /etc/haproxy/haproxy.cfg

        return 1

    fi

    systemctl daemon-reload

    systemctl enable haproxy >/dev/null 2>&1

    if systemctl restart haproxy; then
    
# Actualizar configuración
grep -q "^WEBSOCKET=" "$CONFIG" \
    && sed -i 's/^WEBSOCKET=.*/WEBSOCKET=ON/' "$CONFIG" \
    || echo "WEBSOCKET=ON" >> "$CONFIG"

grep -q "^WS_PORT=" "$CONFIG" \
    && sed -i 's/^WS_PORT=.*/WS_PORT=80,443,8080/' "$CONFIG" \
    || echo "WS_PORT=80,443,8080" >> "$CONFIG"
    
        msg_ok "HAProxy iniciado correctamente."

    else

        msg_error "No fue posible iniciar HAProxy."

        return 1

    fi

    sleep 2

    echo

    line

    if systemctl is-active --quiet haproxy; then
        echo -e "${GREEN}HAProxy:${RESET} ACTIVO"
    else
        echo -e "${RED}HAProxy:${RESET} DETENIDO"
    fi

    if systemctl is-active --quiet ssh-ws-internal.service; then
        echo -e "${GREEN}SSH WS Internal:${RESET} ACTIVO"
    else
        echo -e "${RED}SSH WS Internal:${RESET} DETENIDO"
    fi

    line

    msg_ok "SSL Tunnel instalado correctamente."

}
ensure_haproxy_resilience() {

    local DIR="/etc/systemd/system/haproxy.service.d"
    local OVERRIDE="${DIR}/10-resilience.conf"

    # Si ya existe el override, no volver a crearlo
    if [[ -f "$OVERRIDE" ]]; then
        return 0
    fi

    mkdir -p "$DIR"

    cat > "$OVERRIDE" <<EOF
[Unit]
After=network-online.target ssh-ws-internal.service
Wants=network-online.target ssh-ws-internal.service

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
ExecStartPre=/bin/mkdir -p /run/haproxy
EOF

    systemctl daemon-reload

    msg_ok "Resiliencia de HAProxy configurada."

}
ensure_haproxy_running() {

    # Verificar configuración
    [[ -f /etc/haproxy/haproxy.cfg ]] || return
    [[ -f /etc/haproxy/yha.pem ]] || return

    # Recrear directorio del socket
    mkdir -p /run/haproxy

    # Aplicar resiliencia
    ensure_haproxy_resilience

    # Verificar servicio interno
    if ! systemctl is-active --quiet ssh-ws-internal.service; then

        if [[ -f /etc/systemd/system/ssh-ws-internal.service ]]; then

            systemctl restart ssh-ws-internal.service >/dev/null 2>&1

        else

            install_ssh_ws_internal

        fi

    fi

    # Si HAProxy ya está activo no hacer nada
    if systemctl is-active --quiet haproxy; then

        return

    fi

    msg_info "Recuperando HAProxy..."

    # Liberar puertos
    fuser -k 80/tcp >/dev/null 2>&1 || true
    fuser -k 443/tcp >/dev/null 2>&1 || true
    fuser -k 8080/tcp >/dev/null 2>&1 || true

    systemctl restart haproxy >/dev/null 2>&1

    sleep 2

    if systemctl is-active --quiet haproxy; then

        msg_ok "HAProxy recuperado correctamente."

    else

        msg_error "No fue posible iniciar HAProxy."

    fi

}
#==================================================
# INICIAR MENÚ
#==================================================

ssl_tunnel_menu
