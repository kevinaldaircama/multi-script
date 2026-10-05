#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# kevintech Network Premium
# XHTTP_S Manager v1 (estilo kevintech)
# Servidor SSH-XHTTP TLS/HTTP2 — protocolo moderno
# de HTTP Custom 2.x / apps SSH-XHTTP
#
# • TLS + HTTP/2 autofirmado en :443 y :8080
# • Routing por HTTP Host (btun-hosts / auto-hosts)
# • SSH fallback directo → OpenSSH 127.0.0.1:22
# • Binario incluido: protocolos/xhttp/xhttp-server
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"


# Sistema de animación/progreso + detección de estado
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
WHITE="${MV_WHT:-\e[1;97m}"
RESET="${MV_R:-\e[0m}"

SERVICE="xhttp"
DIR="/etc/xhttp"
BIN="/usr/local/bin/xhttp-server"
CERT="$DIR/server.crt"
KEY="$DIR/server.key"

XHTTP_PORT="${XHTTP_PORT:-443}"
XHTTP_PORT2="${XHTTP_PORT2:-8080}"
DOMAIN="${SERVER_DOMAIN:-kevintech}"
XHTTP_HOST="${XHTTP_HOST:-$DOMAIN}"
# Puertos locales cuando haproxy gestiona 80/443/8080/8443 (modo integrado)
XHTTP_LOCAL_TLS="${XHTTP_LOCAL_TLS:-2001}"
XHTTP_LOCAL_PLAIN="${XHTTP_LOCAL_PLAIN:-2002}"

STATUS=""
HAPROXY_ON=0
systemctl is-active --quiet haproxy 2>/dev/null && HAPROXY_ON=1

#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    anim_step "$(trx 'Instalando dependencias')"

    anim_run "apt update" apt update -y

    anim_run "$(trx 'Instalar paquetes base')" apt install -y curl openssl ca-certificates

    [[ -d "$DIR" ]] || mkdir -p "$DIR"

}

#==================================================
# Detectar arquitectura del sistema (patrón multi-arch)
#==================================================

detect_arch(){

    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64)            echo "linux-amd64" ;;
        aarch64|arm64)     echo "linux-arm64" ;;
        armv7l|armv6l)     echo "linux-arm" ;;
        i386|i686)         echo "linux-386" ;;
        *)
            echo "$(trx '❌ Arquitectura no soportada:') $arch"
            return 1
            ;;
    esac
}

#==================================================
# Instalar binario XHTTP_S (incluido o fallback)
#==================================================

install_binary(){

    ARCH_TAG=""
    if ARCH_TAG=$(detect_arch 2>/dev/null); then
        :
    else
        detect_arch
        echo "$(trx '   Binarios disponibles: linux-amd64, linux-arm64, linux-arm, linux-386')"
        return 1
    fi

    for LOCAL_SRC in \
        "$BASE/protocolos/xhttp/xhttp-server-${ARCH_TAG}" \
        "$BASE/protocolos/xhttp/xhttp-server" \
        "$(dirname "$(readlink -f "$0")")/xhttp-server-${ARCH_TAG}" \
        "$(dirname "$(readlink -f "$0")")/xhttp-server"
    do
        [[ -f "$LOCAL_SRC" ]] || continue

        if cp -f "$LOCAL_SRC" "$BIN" && chmod +x "$BIN" && "$BIN" -h >/dev/null 2>&1; then
            anim_run "$(trx 'Binario XHTTP_S instalado')" true
            return 0
        fi
        rm -f "$BIN"
    done

    echo "$(trx '❌ No se encontró el binario xhttp-server.')"
    echo "$(trx '   Debe estar en protocolos/xhttp/xhttp-server')"
    echo "$(trx '   o protocolos/xhttp/xhttp-server-')${ARCH_TAG}"
    return 1
}

#==================================================
# Generar certificado TLS autofirmado
#==================================================

gen_certs(){

    if [[ -f "$CERT" && -f "$KEY" ]]; then
        return 0
    fi

    echo "$(trx '🔑 Generando certificado TLS autofirmado...')"

    openssl req -x509 -newkey ec \
        -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout "$KEY" -out "$CERT" \
        -days 3650 -nodes \
        -subj "/CN=$XHTTP_HOST" \
        -addext "subjectAltName=DNS:$XHTTP_HOST,IP:127.0.0.1,IP:0.0.0.0" 2>/dev/null

    chmod 600 "$KEY"

}

#==================================================
# Crear servicio XHTTP_S
#==================================================

create_service(){

    if [[ "$HAPROXY_ON" == "1" ]]; then
        LISTEN="127.0.0.1:$XHTTP_LOCAL_TLS,127.0.0.1:$XHTTP_LOCAL_PLAIN"
    else
        LISTEN="0.0.0.0:$XHTTP_PORT,0.0.0.0:$XHTTP_PORT2"
    fi

    cat > /etc/systemd/system/xhttp.service <<SVCEOF
[Unit]
Description=kevintech XHTTP_S (SSH-XHTTP TLS/HTTP2)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN -listen $LISTEN -tls-cert $CERT -tls-key $KEY -target 127.0.0.1:22 -session-timeout 2m
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable xhttp >/dev/null 2>&1

    echo "$(trx '✅ Servicio xhttp.service creado.')"
}

#==================================================
# Abrir puertos
#==================================================

open_ports(){

    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo "$(trx '🛡 Puertos gestionados por HAProxy (modo integrado)')"
        return 0
    fi

    echo "$(trx '🛡 Abriendo puertos...')"

    for P in "$XHTTP_PORT" "$XHTTP_PORT2"; do
        iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
    done

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        for P in "$XHTTP_PORT" "$XHTTP_PORT2"; do
            ufw allow "$P"/tcp >/dev/null 2>&1
        done
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

}

#==================================================
# Integración con HAProxy (SSL=ON)
# HAProxy gestiona 80/443/8080/8443 — XHTTP_S vive en
# 127.0.0.1:$XHTTP_LOCAL_TLS (TLS) / 127.0.0.1:$XHTTP_LOCAL_PLAIN (h2c)
#   • TLS → passthrough SNI: req.ssl_sni == $XHTTP_HOST → xhttp TLS
#   • h2c → preface "PRI * HTTP/2.0" → xhttp plain
# Cualquier otro payload sigue su ruta normal (SSH-2.0, Xray, WS...)
#==================================================

haproxy_integrate_xhttp(){

    [[ "$HAPROXY_ON" == "1" ]] || return 0

    local HCFG="/etc/haproxy/haproxy.cfg"
    local MARK="# kevintech XHTTP_S"

    [[ -f "$HCFG" ]] || { echo "$(trx '⚠  haproxy sin cfg — modo standalone')"; return 0; }
    grep -q "frontend ssl_frontend" "$HCFG" || { echo "$(trx '⚠  ssl_frontend no encontrado — modo standalone')"; return 0; }
    grep -q "$MARK" "$HCFG" && { echo "$(trx '✅ HAProxy ya integrado con XHTTP_S')"; return 0; }

    # 1a) multiport_frontend (443): SNI passthrough → xhttp TLS (PRIMERO, antes de BHTTP)
    awk -v ancla="tcp-request content accept if { req.ssl_hello_type 1 }" -v bloque="    # kevintech XHTTP_S: SNI passthrough TLS (443)
    acl acl_sni_xhttp req.ssl_sni -i $XHTTP_HOST
    use_backend xhttp_tls_backend if acl_sni_xhttp" '
        { if (!done && index($0, ancla) > 0) { print $0; print bloque; done=1; next } print }' "$HCFG" > "$HCFG.tmp"
    mv -f "$HCFG.tmp" "$HCFG"

    # 1b) multiport_frontend (443): ANY-PAYLOAD (request-line HTTP/1.x genérica:
    #     GET/POST/CONNECT/HEAD/OPTIONS/PUT/DELETE, absolute-form wss:// https:// http://,
    #     front/back query, h2c preface "PRI ") → recir 2223 / xhttp plain
    awk -v ancla="use_backend recir_http_backend if HTTP" -v bloque="    # kevintech ANY-PAYLOAD: acepta/enruta cualquier request-line HTTP/1.x (443 plain)
    acl acl_any_http payload(0,100) -m reg ^[A-Za-z]+[[:space:]]+[^[:space:]]+[[:space:]]+HTTP/1\\.[01]
    acl acl_connect payload(0,8) -m bin 434f4e4e45435420
    acl acl_xhttp_h2 payload(0,3) -m bin 505249
    tcp-request content accept if acl_any_http
    tcp-request content accept if acl_connect
    tcp-request content accept if acl_xhttp_h2
    use_backend xhttp_plain_backend if acl_xhttp_h2
    use_backend recir_http_backend if acl_connect
    use_backend recir_http_backend if acl_any_http" '
        { if (!done && index($0, ancla) > 0) { print bloque; done=1 } print }' "$HCFG" > "$HCFG.tmp"
    mv -f "$HCFG.tmp" "$HCFG"

    # 2) ssl_frontend: ACLs SNI + HTTP/2 preface (prioridad sobre paths/WS)
    awk -v ancla="acl acl_upgrade hdr(Connection) -i upgrade" -v bloque="    acl acl_sni_xhttp req.ssl_sni -i $XHTTP_HOST
    acl acl_xhttp_h2 payload(0,3) -m bin 505249
    use_backend xhttp_tls_backend if acl_sni_xhttp
    use_backend xhttp_plain_backend if acl_xhttp_h2" '
        { if (!done && index($0, ancla) > 0) { print bloque; done=1 } print }' "$HCFG" > "$HCFG.tmp"
    mv -f "$HCFG.tmp" "$HCFG"

    # 3) ssl_frontend: aceptar inspección de HTTP y h2c (para 80/8080)
    if ! grep -q "505249 }" "$HCFG"; then
        awk -v ancla="tcp-request content capture req.ssl_sni len 100" -v bloque="    tcp-request content accept if HTTP
    tcp-request content accept if { payload(0,3) -m bin 505249 }" '
            { if (!done && index($0, ancla) > 0) { print $0; print bloque; done=1; next } print }' "$HCFG" > "$HCFG.tmp"
        mv -f "$HCFG.tmp" "$HCFG"
    fi

    # 4) backends al final (idempotente)
    grep -qE "^backend xhttp_tls_backend" "$HCFG" || cat >> "$HCFG" <<EOF

# kevintech XHTTP_S backends
backend xhttp_tls_backend
    mode tcp
    server xhttp_tls_local 127.0.0.1:$XHTTP_LOCAL_TLS check

backend xhttp_plain_backend
    mode tcp
    server xhttp_plain_local 127.0.0.1:$XHTTP_LOCAL_PLAIN check
EOF

    if haproxy -c -f "$HCFG" >/dev/null 2>&1; then
        systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
        echo "$(trx '✅ HAProxy enruta XHTTP_S')"
        echo "$(trx "   SNI $XHTTP_HOST → :$XHTTP_LOCAL_TLS (TLS)")"
        echo "$(trx "   preface HTTP/2  → :$XHTTP_LOCAL_PLAIN (h2c)")"
        return 0
    fi

    echo "$(trx '❌ haproxy -c falló — revisa /etc/haproxy/haproxy.cfg')"
    return 0
}

haproxy_remove_xhttp(){

    [[ -f /etc/haproxy/haproxy.cfg ]] || return 0
    grep -q "xhttp_tls_backend" /etc/haproxy/haproxy.cfg || {
        echo "$(trx 'HAProxy sin integración XHTTP_S')"
        return 0
    }

    sed -i '/acl acl_sni_xhttp/d; /acl acl_xhttp_h2/d; /acl acl_any_http/d; /acl acl_connect/d; /tcp-request content accept if acl_any_http/d; /tcp-request content accept if acl_connect/d; /tcp-request content accept if acl_xhttp_h2/d; /use_backend xhttp_tls_backend/d; /use_backend xhttp_plain_backend/d; /use_backend recir_http_backend if acl_connect/d; /use_backend recir_http_backend if acl_any_http/d; /# kevintech XHTTP_S/d' /etc/haproxy/haproxy.cfg
    sed -i '/^backend xhttp_tls_backend/,/^$/d' /etc/haproxy/haproxy.cfg
    sed -i '/^backend xhttp_plain_backend/,/^$/d' /etc/haproxy/haproxy.cfg

    # remover accept h2c solo si ya nadie lo usa
    grep -q "acl acl_xhttp_h2" /etc/haproxy/haproxy.cfg || \
        sed -i '/tcp-request content accept if { payload(0,3) -m bin 505249 }/d' /etc/haproxy/haproxy.cfg

    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
    fi

    echo "$(trx '✅ HAProxy: integración XHTTP_S eliminada')"
}

#==================================================
# Test funcional
#==================================================

test_xhttp(){

    echo ""
    echo "$(trx '🧪 Verificando XHTTP_S...')"

    if systemctl is-active --quiet xhttp && \
       ss -ltnp 2>/dev/null | grep -qE ":$XHTTP_PORT |:$XHTTP_PORT2 |:$XHTTP_LOCAL_TLS |:$XHTTP_LOCAL_PLAIN "; then
        echo "$(trx '✅ XHTTP_S activo y escuchando.')"
        return 0
    fi

    if systemctl is-active --quiet xhttp; then
        echo "$(trx '✅ Servicio activo.')"
        return 0
    fi

    echo "$(trx '⚠️  El servicio no está activo.')"
    echo "$(trx '    Revisa: journalctl -u xhttp -n 20 --no-pager')"
    return 1
}

#==================================================
# Instalar XHTTP_S
#==================================================

install_xhttp(){

    clear
mv_brand_header "INSTALAR XHTTP_S"
    # Modo de operación (integración con HAProxy)
    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo -e "  ${CYAN}➜ Modo integrado (HAProxy):${RESET}"
        echo -e "    XHTTP_S vive en 127.0.0.1:${XHTTP_LOCAL_TLS}/${XHTTP_LOCAL_PLAIN}"
        echo -e "    HAProxy enruta por SNI (${XHTTP_HOST}) o preface HTTP/2."
        echo -e "    Clientes usan 443/8080/8443 — sin conflicto de puertos."
        echo ""
    else
        echo -e "  ${CYAN}➜ Modo standalone:${RESET} puertos ${XHTTP_PORT}/${XHTTP_PORT2} directos."
        echo ""
    fi

    anim_init 6
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    install_binary || return

    anim_step "$(trx 'Configurando XHTTP_S')"
    gen_certs

    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicios')"
    anim_run "daemon-reload" systemctl daemon-reload

    systemctl enable xhttp >/dev/null 2>&1

    svc_restart_anim xhttp "$(trx 'Arrancando XHTTP_S')"

    if ! systemctl is-active --quiet xhttp; then
        echo "$(trx '❌ XHTTP_S no pudo iniciar.')"
        journalctl -u xhttp -n 20 --no-pager
        return 1
    fi

    test_xhttp

    anim_step "$(trx 'Integrando con HAProxy')"
    haproxy_integrate_xhttp

    sleep 3

    if systemctl is-active --quiet xhttp; then

        sed -i '/^XHTTP=/d' "$CONFIG"
        echo "XHTTP=ON" >> "$CONFIG"
        sed -i '/^XHTTP_PORT=/d' "$CONFIG"
        echo "XHTTP_PORT=$XHTTP_PORT" >> "$CONFIG"
        sed -i '/^XHTTP_PORT2=/d' "$CONFIG"
        echo "XHTTP_PORT2=$XHTTP_PORT2" >> "$CONFIG"

        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ XHTTP_S INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP         : $VPS_IP"
        if [[ "$HAPROXY_ON" == "1" ]]; then
            echo "🚀 Público    : 443/8080/8443 (HAProxy)"
            echo "🔑 SNI TLS    : $XHTTP_HOST (passthrough)"
            echo "🔑 h2c plain  : preface HTTP/2 (any 80/8080)"
        else
            echo "🚀 Puertos    : $XHTTP_PORT / $XHTTP_PORT2"
            echo "🔑 TLS        : autofirmado (SNI: $XHTTP_HOST)"
        fi
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '  📱 CONFIGURACIÓN EN LA APP')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$(trx '  HTTP Custom / HTTP Injector:')"
        echo "   Tipo     : SSH-XHTTP (Server publish)"
        echo "   Host     : $VPS_IP"
        if [[ "$HAPROXY_ON" == "1" ]]; then
            echo "   Puerto   : 443  (SNI: $XHTTP_HOST)"
        else
            echo "   Puerto   : $XHTTP_PORT  (SNI: $XHTTP_HOST)"
        fi
        echo "   Usuario  : $(trx 'cuenta SSH del panel')"
        echo "   Payload  : $(trx 'vacío — HTTP/2 directo')"
        echo ""
        echo "$(trx '  ⚠️  Los clientes deben aceptar el')"
        echo "$(trx '  certificado autofirmado (o usar el')"
        echo "$(trx '  dominio como SNI con nube gris).')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando XHTTP_S')"
        echo ""
        systemctl status xhttp --no-pager

    fi

    sleep 4
}

#==================================================
# Eliminar XHTTP_S
#==================================================

remove_xhttp(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR XHTTP_S${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar XHTTP_S? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando XHTTP_S')"
    anim_run "$(trx 'Detener y deshabilitar')" bash -c "systemctl stop xhttp 2>/dev/null; systemctl disable xhttp 2>/dev/null"
    anim_run "$(trx 'Eliminar servicio')" rm -f /etc/systemd/system/xhttp.service
    anim_run "$(trx 'Eliminar directorio')" rm -rf "$DIR"
    anim_run "$(trx 'Eliminar binario')" rm -f "$BIN"
    anim_run "daemon-reload" systemctl daemon-reload

    anim_step "$(trx 'Quitar integración HAProxy')"
    haproxy_remove_xhttp

    for P in "$XHTTP_PORT" "$XHTTP_PORT2"; do
        iptables -D INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null
    done

    sed -i '/^XHTTP=/d' "$CONFIG"
    echo "XHTTP=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ XHTTP_S eliminado.')"
    sleep 3
}

#==================================================
# Reiniciar servicio
#==================================================

restart_xhttp(){

    clear
    svc_restart_anim xhttp "$(trx 'Reiniciando XHTTP_S')"
    sleep 2

    if systemctl is-active --quiet xhttp; then
        echo ""
        echo "$(trx '✅ Servicio activo.')"
        test_xhttp
    else
        echo ""
        echo "$(trx '❌ Error al reiniciar.')"
    fi
    sleep 3
}

#==================================================
# Estado
#==================================================

status_xhttp(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO XHTTP_S${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    systemctl status xhttp --no-pager

    echo ""
    echo "$(trx 'Puertos abiertos:')"
    ss -ltnp | grep -E ":$XHTTP_PORT |:$XHTTP_PORT2 " || true

    echo ""
    ss -ltnp | grep -E ":${XHTTP_PORT} |:${XHTTP_PORT2} |:${XHTTP_LOCAL_TLS} |:${XHTTP_LOCAL_PLAIN} " | grep xhttp || true

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS XHTTP_S${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')

    [[ -f "$CERT" ]] && DOMAIN_INFO=$(openssl x509 -in "$CERT" -noout -subject 2>/dev/null | sed 's/.*CN=//')

    echo "🌍 IP         : $VPS_IP"
    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo "🚀 Público    : 443/8080/8443 (HAProxy)"
        echo "🚀 Local      : $XHTTP_LOCAL_TLS (TLS) / $XHTTP_LOCAL_PLAIN (h2c)"
        echo "🔑 SNI        : $XHTTP_HOST"
    else
        echo "🚀 Puerto 1   : $XHTTP_PORT"
        echo "🚀 Puerto 2   : $XHTTP_PORT2"
        echo "🔑 TLS        : autofirmado (CN: ${DOMAIN_INFO:-$XHTTP_HOST})"
    fi
    echo ""
    echo "📱 App (HTTP Custom / HTTP Injector):"
    echo "   Tipo   : SSH-XHTTP (Server publish)"
    echo "   Host   : $VPS_IP"
    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo "   Puerto : 443 (SNI: $XHTTP_HOST)"
    else
        echo "   Puerto : $XHTTP_PORT"
    fi
    echo "   Usuario: $(trx 'crea uno en Usuarios del panel')"
    echo "   Payload: $(trx 'vacío (HTTP/2)')"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Menú Principal
#==================================================

# Navegación con flechitas
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh"

# ── CLI headless: bash xhttp.sh --install [puerto1] [puerto2]
if [[ "${1:-}" == "--install" ]]; then
    [[ -n "${2:-}" ]] && export XHTTP_PORT="$2" XHTTP_FORCE_STANDALONE=1
    [[ -n "${3:-}" ]] && export XHTTP_PORT2="$3" XHTTP_FORCE_STANDALONE=1
    [[ -n "${XHTTP_FORCE_STANDALONE:-}" ]] && HAPROXY_ON=0
    install_xhttp
    exit $?
fi

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet xhttp; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_header "🚀 XHTTP_S Manager" "$(trx 'SSH-XHTTP TLS/HTTP2 · 443/8080')" "v6.2"
    kevintech_contacts 2>/dev/null || true

    echo -e " Estado      : $STATUS"
    echo -e " Puertos     : $XHTTP_PORT / $XHTTP_PORT2"

    echo ""

    if [[ "$XHTTP" == "ON" ]]; then
        LBL=("Desinstalar XHTTP_S" "Reiniciar Servicio" "Ver Estado" "Ver Datos de Conexión")
    else
        LBL=("Instalar XHTTP_S")
    fi
    SEL=$(nav_pick "► Opción:" "${LBL[@]}" "↩ Regresar") || SEL=0
    [[ $SEL -eq $((${#LBL[@]}+1)) ]] && SEL=0
    OP="$SEL"

    case "$OP" in

        1)
            if [[ "$XHTTP" == "ON" ]]; then
                remove_xhttp
            else
                install_xhttp
            fi
        ;;

        2)
            [[ "$XHTTP" == "ON" ]] && restart_xhttp
        ;;

        3)
            [[ "$XHTTP" == "ON" ]] && status_xhttp
        ;;

        4)
            [[ "$XHTTP" == "ON" ]] && show_info
        ;;

        0)
            exec bash "$BASE/protocolos/menu.sh"
        ;;

        *)
            echo ""
            echo "$(trx '❌ Opción inválida.')"
            sleep 2
        ;;

    esac

done