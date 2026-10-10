#!/bin/bash

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

#==================================================
# kevintech Network Premium
# BHTTP v2 Manager v1 (estilo kevintech)
# Servidor SSH-BHTTP (HTTP/2 Bootstrap — multiplexa
# hasta 128 conexiones por túnel)
#
# • HTTP/2 nativo en :80 + xhttp TLS en :8443
# • Bloqueo configurable de dominios no autorizados
# • SSH fallback directo → OpenSSH 127.0.0.1:22
# • Binario incluido: protocolos/bhttp/bhttp-server
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"


# Sistema de animación/progreso — estilo KevinTech XHTTP
[[ -f "$BASE/lib/anim.sh" ]] && source "$BASE/lib/anim.sh"

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_GRY:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

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
    else
        echo -e "${RED}ERROR${RESET}"
        return 1
    fi
}

svc_restart_anim() {
    local SERVICE_NAME="$1"
    local LABEL="$2"

    echo -ne "${CYAN}➜ ${LABEL}...${RESET} "
    systemctl restart "$SERVICE_NAME" >/dev/null 2>&1

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}OK${RESET}"
        return 0
    else
        echo -e "${RED}ERROR${RESET}"
        return 1
    fi
}

mv_header() {
    local TITLE="${1:-KEVINTECH}"
    local SUBTITLE="${2:-}"
    local VERSION="${3:-}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        ${TITLE}${RESET}"
    [[ -n "$SUBTITLE" ]] && echo -e "${GRAY}   ${SUBTITLE}${RESET}"
    [[ -n "$VERSION" ]] && echo -e "${GRAY}        ${VERSION}${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

mv_brand_header() {
    mv_header "$1" "kevintech BHTTP" "v6.2"
}

kevintech_contacts() {
    return 0
}
SERVICE="bhttp"
DIR="/etc/bhttp"
BIN="/usr/local/bin/bhttp-server"
CERT="$DIR/server.crt"
KEY="$DIR/server.key"

BHTTP_PORT="${BHTTP_PORT:-80}"
BHTTP_XPORT="${BHTTP_XPORT:-8443}"
DOMAIN="${SERVER_DOMAIN:-kevintech}"
BHTTP_HOST="${BHTTP_HOST:-$DOMAIN}"
# Puertos locales cuando haproxy gestiona 80/443/8080/8443 (modo integrado)
BHTTP_LOCAL_PLAIN="${BHTTP_LOCAL_PLAIN:-2005}"
BHTTP_LOCAL_TLS="${BHTTP_LOCAL_TLS:-2007}"

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
# Instalar binario BHTTP (incluido o fallback)
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
        "$BASE/protocolos/bhttp/bhttp-server-${ARCH_TAG}" \
        "$BASE/protocolos/bhttp/bhttp-server" \
        "$(dirname "$(readlink -f "$0")")/bhttp-server-${ARCH_TAG}" \
        "$(dirname "$(readlink -f "$0")")/bhttp-server"
    do
        [[ -f "$LOCAL_SRC" ]] || continue

        if cp -f "$LOCAL_SRC" "$BIN" && chmod +x "$BIN" && "$BIN" -h >/dev/null 2>&1; then
            anim_run "$(trx 'Binario BHTTP instalado')" true
            return 0
        fi
        rm -f "$BIN"
    done

    echo "$(trx '❌ No se encontró el binario bhttp-server.')"
    echo "$(trx '   Debe estar en protocolos/bhttp/bhttp-server')"
    echo "$(trx '   o protocolos/bhttp/bhttp-server-')${ARCH_TAG}"
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
        -subj "/CN=$BHTTP_HOST" \
        -addext "subjectAltName=DNS:$BHTTP_HOST,IP:127.0.0.1,IP:0.0.0.0" 2>/dev/null

    chmod 600 "$KEY"

}

#==================================================
# Crear servicio BHTTP
#==================================================

create_service(){

    if [[ "$HAPROXY_ON" == "1" ]]; then
        LISTEN="127.0.0.1:$BHTTP_LOCAL_PLAIN"
        XLISTEN="127.0.0.1:$BHTTP_LOCAL_TLS"
    else
        LISTEN="0.0.0.0:$BHTTP_PORT"
        XLISTEN="0.0.0.0:$BHTTP_XPORT"
    fi

    cat > /etc/systemd/system/bhttp.service <<SVCEOF
[Unit]
Description=kevintech BHTTP v2 (SSH-HTTP/2 Bootstrap)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN -listen $LISTEN -xhttp-listen $XLISTEN -tls-cert $CERT -tls-key $KEY -target 127.0.0.1:22 -bhttp-v2-max-lanes 128 -session-timeout 2m
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable bhttp >/dev/null 2>&1

    echo "$(trx '✅ Servicio bhttp.service creado.')"
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

    for P in "$BHTTP_PORT" "$BHTTP_XPORT"; do
        iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
    done

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        for P in "$BHTTP_PORT" "$BHTTP_XPORT"; do
            ufw allow "$P"/tcp >/dev/null 2>&1
        done
    fi

    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

}

#==================================================
# Integración con HAProxy (SSL=ON)
# HAProxy gestiona 80/443/8080/8443 — BHTTP vive en
# 127.0.0.1:$BHTTP_LOCAL_PLAIN (h2c) / 127.0.0.1:$BHTTP_LOCAL_TLS (TLS)
#   • TLS  → passthrough SNI: req.ssl_sni == $BHTTP_HOST → bhttp TLS
#   • h2c  → Host header == $BHTTP_HOST → bhttp plain
# Cualquier otro payload sigue su ruta normal (SSH-2.0, Xray, WS...)
#==================================================

haproxy_integrate_bhttp(){

    [[ "$HAPROXY_ON" == "1" ]] || return 0

    local HCFG="/etc/haproxy/haproxy.cfg"
    local MARK="# kevintech BHTTP"

    [[ -f "$HCFG" ]] || { echo "$(trx '⚠  haproxy sin cfg — modo standalone')"; return 0; }
    grep -q "frontend ssl_frontend" "$HCFG" || { echo "$(trx '⚠  ssl_frontend no encontrado — modo standalone')"; return 0; }
    grep -q "$MARK" "$HCFG" && { echo "$(trx '✅ HAProxy ya integrado con BHTTP')"; return 0; }

    # 1) multiport_frontend (443): SNI passthrough → bhttp TLS + Host header (443 plain)
    #    insertar ANTES del bloque ANY-PAYLOAD de XHTTP_S si existe (para que
    #    Host: bhttp gane sobre recir_http any_http); fallback: ancla base
    local ANCLA="use_backend recir_http_backend if HTTP"
    grep -q "acl acl_any_http" "$HCFG" && ANCLA="acl acl_any_http"
    awk -v ancla="$ANCLA" -v bloque="    # kevintech BHTTP: SNI passthrough TLS + Host header (443 plain)
    acl acl_sni_bhttp req.ssl_sni -i $BHTTP_HOST
    acl acl_bhttp_host hdr(host) -i $BHTTP_HOST
    tcp-request content accept if acl_bhttp_host
    use_backend bhttp_tls_backend if acl_sni_bhttp
    use_backend bhttp_plain_backend if acl_bhttp_host" '
        { if (!done && index($0, ancla) > 0) { print bloque; done=1 } print }' "$HCFG" > "$HCFG.tmp"
    mv -f "$HCFG.tmp" "$HCFG"

    # 2) ssl_frontend: ACLs SNI + Host (prioridad sobre paths/WS)
    awk -v ancla="acl acl_upgrade hdr(Connection) -i upgrade" -v bloque="    acl acl_sni_bhttp req.ssl_sni -i $BHTTP_HOST
    acl acl_bhttp_host hdr(host) -i $BHTTP_HOST
    use_backend bhttp_tls_backend if acl_sni_bhttp
    use_backend bhttp_plain_backend if acl_bhttp_host" '
        { if (!done && index($0, ancla) > 0) { print bloque; done=1 } print }' "$HCFG" > "$HCFG.tmp"
    mv -f "$HCFG.tmp" "$HCFG"

    # 3) ssl_frontend: aceptar inspección HTTP (para Host en 80/8080)
    if ! grep -q "tcp-request content accept if HTTP" "$HCFG"; then
        awk -v ancla="tcp-request content capture req.ssl_sni len 100" -v bloque="    tcp-request content accept if HTTP" '
            { if (!done && index($0, ancla) > 0) { print $0; print bloque; done=1; next } print }' "$HCFG" > "$HCFG.tmp"
        mv -f "$HCFG.tmp" "$HCFG"
    fi

    # 4) backends al final (idempotente)
    grep -qE "^backend bhttp_tls_backend" "$HCFG" || cat >> "$HCFG" <<EOF

# kevintech BHTTP backends
backend bhttp_tls_backend
    mode tcp
    server bhttp_tls_local 127.0.0.1:$BHTTP_LOCAL_TLS check

backend bhttp_plain_backend
    mode tcp
    server bhttp_plain_local 127.0.0.1:$BHTTP_LOCAL_PLAIN check
EOF

    if haproxy -c -f "$HCFG" >/dev/null 2>&1; then
        systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
        echo "$(trx '✅ HAProxy enruta BHTTP')"
        echo "$(trx "   SNI $BHTTP_HOST  → :$BHTTP_LOCAL_TLS (TLS)")"
        echo "$(trx "   Host $BHTTP_HOST → :$BHTTP_LOCAL_PLAIN (h2c)")"
        return 0
    fi

    echo "$(trx '❌ haproxy -c falló — revisa /etc/haproxy/haproxy.cfg')"
    return 0
}

haproxy_remove_bhttp(){

    [[ -f /etc/haproxy/haproxy.cfg ]] || return 0
    grep -q "bhttp_tls_backend" /etc/haproxy/haproxy.cfg || {
        echo "$(trx 'HAProxy sin integración BHTTP')"
        return 0
    }

    sed -i '/acl acl_sni_bhttp/d; /acl acl_bhttp_host/d; /tcp-request content accept if acl_bhttp_host/d; /use_backend bhttp_tls_backend/d; /use_backend bhttp_plain_backend/d; /# kevintech BHTTP/d' /etc/haproxy/haproxy.cfg
    sed -i '/^backend bhttp_tls_backend/,/^$/d' /etc/haproxy/haproxy.cfg
    sed -i '/^backend bhttp_plain_backend/,/^$/d' /etc/haproxy/haproxy.cfg

    if haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1; then
        systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
    fi

    echo "$(trx '✅ HAProxy: integración BHTTP eliminada')"
}

#==================================================
# Test funcional
#==================================================

test_bhttp(){

    echo ""
    echo "$(trx '🧪 Verificando BHTTP...')"

    if systemctl is-active --quiet bhttp && \
       ss -ltnp 2>/dev/null | grep -qE ":$BHTTP_PORT |:$BHTTP_XPORT |:$BHTTP_LOCAL_PLAIN |:$BHTTP_LOCAL_TLS "; then
        echo "$(trx '✅ BHTTP activo y escuchando.')"
        return 0
    fi

    if systemctl is-active --quiet bhttp; then
        echo "$(trx '✅ Servicio activo.')"
        return 0
    fi

    echo "$(trx '⚠️  El servicio no está activo.')"
    echo "$(trx '    Revisa: journalctl -u bhttp -n 20 --no-pager')"
    return 1
}

#==================================================
# Instalar BHTTP
#==================================================

install_bhttp(){

    clear
mv_brand_header "INSTALAR BHTTP v2"
    # Modo de operación (integración con HAProxy)
    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo -e "  ${CYAN}➜ Modo integrado (HAProxy):${RESET}"
        echo -e "    BHTTP vive en 127.0.0.1:${BHTTP_LOCAL_PLAIN}/${BHTTP_LOCAL_TLS}"
        echo -e "    HAProxy enruta por SNI o Host (${BHTTP_HOST})."
        echo -e "    Clientes usan 80/443/8080/8443 — sin conflicto."
        echo ""
    else
        echo -e "  ${CYAN}➜ Modo standalone:${RESET} puertos ${BHTTP_PORT}/${BHTTP_XPORT} directos."
        echo ""
    fi

    anim_init 6
    anim_step "$(trx 'Instalando dependencias')"
    install_dependencies || return

    install_binary || return

    anim_step "$(trx 'Configurando BHTTP')"
    gen_certs

    create_service

    anim_step "$(trx 'Abriendo puertos')"
    open_ports

    echo ""
    anim_step "$(trx 'Iniciando servicios')"
    anim_run "daemon-reload" systemctl daemon-reload

    systemctl enable bhttp >/dev/null 2>&1

    svc_restart_anim bhttp "$(trx 'Arrancando BHTTP')"

    if ! systemctl is-active --quiet bhttp; then
        echo "$(trx '❌ BHTTP no pudo iniciar.')"
        journalctl -u bhttp -n 20 --no-pager
        return 1
    fi

    test_bhttp

    anim_step "$(trx 'Integrando con HAProxy')"
    haproxy_integrate_bhttp

    sleep 3

    if systemctl is-active --quiet bhttp; then

        sed -i '/^BHTTP=/d' "$CONFIG"
        echo "BHTTP=ON" >> "$CONFIG"
        sed -i '/^BHTTP_PORT=/d' "$CONFIG"
        echo "BHTTP_PORT=$BHTTP_PORT" >> "$CONFIG"
        sed -i '/^BHTTP_XPORT=/d' "$CONFIG"
        echo "BHTTP_XPORT=$BHTTP_XPORT" >> "$CONFIG"

        source "$CONFIG"

        VPS_IP=$(hostname -I | awk '{print $1}')

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '      ✅ BHTTP v2 INSTALADO')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌍 IP          : $VPS_IP"
        if [[ "$HAPROXY_ON" == "1" ]]; then
            echo "🚀 Público     : 80/443/8080/8443 (HAProxy)"
            echo "🔑 SNI/Host    : $BHTTP_HOST"
            echo "🚀 Local       : $BHTTP_LOCAL_PLAIN (h2c) / $BHTTP_LOCAL_TLS (TLS)"
        else
            echo "🚀 HTTP/2      : $BHTTP_PORT"
            echo "🚀 HTTP/2 TLS  : $BHTTP_XPORT"
            echo "🔑 TLS         : autofirmado (SNI: $BHTTP_HOST)"
        fi
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$(trx '  📱 CONFIGURACIÓN EN LA APP')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$(trx '  HTTP Custom:')"
        echo "   Tipo     : SSH-BHTTP v2 (Server publish)"
        echo "   Host     : $VPS_IP"
        if [[ "$HAPROXY_ON" == "1" ]]; then
            echo "   Puerto   : 80  (Host: $BHTTP_HOST)"
        else
            echo "   Puerto   : $BHTTP_PORT"
        fi
        echo "   Usuario  : $(trx 'cuenta SSH del panel')"
        echo "   Payload  : GET / HTTP/1.1 (Host: $BHTTP_HOST)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

    else

        echo ""
        echo "$(trx '❌ Error iniciando BHTTP')"
        echo ""
        systemctl status bhttp --no-pager

    fi

    sleep 4
}

#==================================================
# Eliminar BHTTP
#==================================================

remove_bhttp(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR BHTTP v2${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "$(trx '¿Eliminar BHTTP? (s/n): ')" R
    [[ ! "$R" =~ ^[Ss]$ ]] && return

    anim_step "$(trx 'Desinstalando BHTTP')"
    anim_run "$(trx 'Detener y deshabilitar')" bash -c "systemctl stop bhttp 2>/dev/null; systemctl disable bhttp 2>/dev/null"
    anim_run "$(trx 'Eliminar servicio')" rm -f /etc/systemd/system/bhttp.service
    anim_run "$(trx 'Eliminar directorio')" rm -rf "$DIR"
    anim_run "$(trx 'Eliminar binario')" rm -f "$BIN"
    anim_run "daemon-reload" systemctl daemon-reload

    anim_step "$(trx 'Quitar integración HAProxy')"
    haproxy_remove_bhttp

    for P in "$BHTTP_PORT" "$BHTTP_XPORT"; do
        iptables -D INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null
    done

    sed -i '/^BHTTP=/d' "$CONFIG"
    echo "BHTTP=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "$(trx '✅ BHTTP eliminado.')"
    sleep 3
}

#==================================================
# Reiniciar servicio
#==================================================

restart_bhttp(){

    clear
    svc_restart_anim bhttp "$(trx 'Reiniciando BHTTP')"
    sleep 2

    if systemctl is-active --quiet bhttp; then
        echo ""
        echo "$(trx '✅ Servicio activo.')"
        test_bhttp
    else
        echo ""
        echo "$(trx '❌ Error al reiniciar.')"
    fi
    sleep 3
}

#==================================================
# Estado
#==================================================

status_bhttp(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO BHTTP v2${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    systemctl status bhttp --no-pager

    echo ""
    echo "$(trx 'Puertos:')"
    ss -ltnp | grep -E ":${BHTTP_PORT} |:${BHTTP_XPORT} |:${BHTTP_LOCAL_PLAIN} |:${BHTTP_LOCAL_TLS} " | grep bhttp || true

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}

#==================================================
# Datos de conexión
#==================================================

show_info(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📱 DATOS BHTTP v2${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    VPS_IP=$(hostname -I | awk '{print $1}')

    [[ -f "$CERT" ]] && DOMAIN_INFO=$(openssl x509 -in "$CERT" -noout -subject 2>/dev/null | sed 's/.*CN=//')

    echo "🌍 IP          : $VPS_IP"
    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo "🚀 Público     : 80/443/8080/8443 (HAProxy)"
        echo "🚀 Local       : $BHTTP_LOCAL_PLAIN (h2c) / $BHTTP_LOCAL_TLS (TLS)"
        echo "🔑 SNI/Host    : $BHTTP_HOST"
    else
        echo "🚀 HTTP/2      : $BHTTP_PORT"
        echo "🚀 HTTP/2 TLS  : $BHTTP_XPORT"
        echo "🔑 TLS         : autofirmado (CN: ${DOMAIN_INFO:-$BHTTP_HOST})"
    fi
    echo ""
    echo "📱 App (HTTP Custom):"
    echo "   Tipo   : SSH-BHTTP v2 (Server publish)"
    echo "   Host   : $VPS_IP"
    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo "   Puerto : 80 (Host: $BHTTP_HOST)"
    else
        echo "   Puerto : $BHTTP_PORT"
    fi
    echo "   Usuario: $(trx 'crea uno en Usuarios del panel')"

    echo ""
    read -n1 -r -p "$(trx 'Presione una tecla...')"
}


#==================================================
# MENÚ PRINCIPAL KEVINTECH BHTTP
#==================================================

# Instalación por CLI: bash bhttp.sh --install [puerto1] [puerto2]
if [[ "${1:-}" == "--install" ]]; then
    [[ -n "${2:-}" ]] && export BHTTP_PORT="$2" BHTTP_FORCE_STANDALONE=1
    [[ -n "${3:-}" ]] && export BHTTP_XPORT="$3" BHTTP_FORCE_STANDALONE=1
    [[ -n "${BHTTP_FORCE_STANDALONE:-}" ]] && HAPROXY_ON=0
    install_bhttp
    exit $?
fi

while true; do
    clear
    source "$CONFIG"

    if systemctl is-active --quiet bhttp; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    if systemctl is-active --quiet haproxy 2>/dev/null; then
        HAPROXY_STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        HAPROXY_STATUS="${RED}🔴 INACTIVO${RESET}"
    fi

    mv_header "📡 BHTTP MANAGER" \
        "$(trx 'SSH-HTTP/2 Bootstrap')" "v6.2"

    kevintech_contacts 2>/dev/null || true

    echo
    echo -e " ${WHITE}Estado      :${RESET} $STATUS"
    echo -e " ${WHITE}Puertos     :${RESET} ${CYAN}$BHTTP_PORT / $BHTTP_XPORT${RESET}"
    echo -e " ${WHITE}HAProxy     :${RESET} $HAPROXY_STATUS"

    if [[ "$HAPROXY_ON" == "1" ]]; then
        echo -e " ${WHITE}Modo        :${RESET} ${CYAN}Integrado${RESET}"
    else
        echo -e " ${WHITE}Modo        :${RESET} ${CYAN}Standalone${RESET}"
    fi

    echo

    if [[ "$BHTTP" == "ON" ]]; then
        echo -e "${CYAN}  [1]${RESET} 🗑️ Desinstalar BHTTP"
        echo -e "${CYAN}  [2]${RESET} 🔄 Reiniciar servicio"
        echo -e "${CYAN}  [3]${RESET} 📊 Ver estado"
        echo -e "${CYAN}  [4]${RESET} 📱 Datos de conexión"
    else
        echo -e "${CYAN}  [1]${RESET} 🚀 Instalar BHTTP"
    fi

    echo
    echo -e "${RED}  [0]${RESET} ↩️ Regresar"
    echo

    read -r -p "$(echo -e "${CYAN}  ➜ Seleccione una opción: ${RESET}")" SEL

    case "$SEL" in
        1)
            if [[ "$BHTTP" == "ON" ]]; then
                remove_bhttp
            else
                install_bhttp
            fi
            ;;
        2)
            [[ "$BHTTP" == "ON" ]] && restart_bhttp
            ;;
        3)
            [[ "$BHTTP" == "ON" ]] && status_bhttp
            ;;
        4)
            [[ "$BHTTP" == "ON" ]] && show_info
            ;;
        0)
            exec bash "$BASE/protocolos/menu.sh"
            ;;
        *)
            echo
            echo -e "${RED}❌ Opción inválida.${RESET}"
            sleep 2
            ;;
    esac
done
