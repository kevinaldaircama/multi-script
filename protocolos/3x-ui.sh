#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# KEVINTECH NETWORK
# 3X-UI PANEL
#
# Panel web para gestión de XRay:
# VLESS / VMess / Trojan / Shadowsocks / SOCKS / HTTP / etc.
#
# Instalación oficial:
# MHSanaei/3x-ui
#
# Integración:
# - systemd
# - HAProxy
# - HTTPS con certificado autofirmado por IP
# - Firewall
#
# Puerto HTTPS externo:
# 54323
# ═══════════════════════════════════════════════════════════════

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

mkdir -p "$BASE"

# ═══════════════════════════════════════════════════════════════
# COLORES
# ═══════════════════════════════════════════════════════════════

RESET="\e[0m"
CYAN="\e[1;96m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
RED="\e[1;91m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
GOLD="\e[1;93m"

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════

XUI_SERVICE="x-ui"
XUI_DIR="/usr/local/x-ui"
XUI_BIN="$XUI_DIR/x-ui"

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
HAPROXY_CERT_DIR="/etc/haproxy/certs"
HAPROXY_CERT="$HAPROXY_CERT_DIR/xui-selfsigned.pem"

HAPROXY_PORT="${XUI_HAPROXY_PORT:-54323}"

XUI_PANEL_PORT="${XUI_PANEL_PORT:-2053}"

# ═══════════════════════════════════════════════════════════════
# FUNCIONES VISUALES
# ═══════════════════════════════════════════════════════════════

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

header() {
    local TITLE="${1:-KEVINTECH}"
    local SUBTITLE="${2:-}"
    local VERSION="${3:-v1.0}"

    clear

    line
    echo -e "${WHITE}              ${TITLE}${RESET}"

    [[ -n "$SUBTITLE" ]] &&
        echo -e "${GRAY}        ${SUBTITLE}${RESET}"

    echo -e "${GRAY}                  ${VERSION}${RESET}"

    line
}

section() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║ $1${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
}

ok() {
    echo -e "${GREEN}✅ $1${RESET}"
}

error_msg() {
    echo -e "${RED}❌ $1${RESET}"
}

warn() {
    echo -e "${YELLOW}⚠️ $1${RESET}"
}

pause_menu() {
    echo ""
    read -r -p "Presiona Enter para continuar..."
}

# ═══════════════════════════════════════════════════════════════
# IP PÚBLICA
# ═══════════════════════════════════════════════════════════════

xui_ip() {

    local IP=""

    IP=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null)

    if [[ -z "$IP" ]]; then
        IP=$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null)
    fi

    if [[ -z "$IP" ]]; then
        IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    echo "${IP:-127.0.0.1}"
}

# ═══════════════════════════════════════════════════════════════
# OBTENER PUERTO REAL DEL PANEL
# ═══════════════════════════════════════════════════════════════

xui_port() {

    local PORT=""

    if [[ -x "$XUI_BIN" ]]; then

        PORT=$(
            "$XUI_BIN" setting -show 2>/dev/null |
            grep -oE 'port[[:space:]]*=[[:space:]]*[0-9]+' |
            grep -oE '[0-9]+' |
            head -1
        )

    fi

    if [[ -z "$PORT" ]]; then

        PORT=$(grep -RhoE 'port[=:][[:space:]]*[0-9]+' \
            /etc/x-ui \
            2>/dev/null |
            grep -oE '[0-9]+' |
            head -1)
    fi

    echo "${PORT:-$XUI_PANEL_PORT}"
}

# ═══════════════════════════════════════════════════════════════
# ESTADO
# ═══════════════════════════════════════════════════════════════

xui_status() {

    if systemctl is-active --quiet "$XUI_SERVICE"; then
        echo -e "${GREEN}🟢 ACTIVO${RESET}"
    else
        echo -e "${RED}🔴 DETENIDO${RESET}"
    fi
}

haproxy_status() {

    if systemctl is-active --quiet haproxy; then
        echo -e "${GREEN}🟢 ACTIVO${RESET}"
    else
        echo -e "${RED}🔴 DETENIDO${RESET}"
    fi
}

# ═══════════════════════════════════════════════════════════════
# FIREWALL
# ═══════════════════════════════════════════════════════════════

xui_open_firewall() {

    local PORT="${1:-$HAPROXY_PORT}"

    iptables -C INPUT \
        -p tcp \
        --dport "$PORT" \
        -j ACCEPT 2>/dev/null ||
    iptables -I INPUT \
        -p tcp \
        --dport "$PORT" \
        -j ACCEPT

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "${PORT}/tcp" >/dev/null 2>&1
        fi

    fi

    mkdir -p /etc/iptables

    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
}

xui_close_firewall() {

    local PORT="${1:-$HAPROXY_PORT}"

    while iptables -C INPUT \
        -p tcp \
        --dport "$PORT" \
        -j ACCEPT 2>/dev/null; do

        iptables -D INPUT \
            -p tcp \
            --dport "$PORT" \
            -j ACCEPT 2>/dev/null || break

    done

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw delete allow "${PORT}/tcp" >/dev/null 2>&1 || true
        fi

    fi

    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# INSTALAR DEPENDENCIAS
# ═══════════════════════════════════════════════════════════════

install_dependencies() {

    section "📦 DEPENDENCIAS"

    echo -e "${CYAN}➜ Actualizando repositorios...${RESET}"

    if ! apt update -y; then
        error_msg "No se pudo actualizar APT."
        return 1
    fi

    echo ""
    echo -e "${CYAN}➜ Instalando herramientas...${RESET}"

    if ! apt install -y \
        curl \
        openssl \
        iptables \
        iproute2 \
        ca-certificates \
        haproxy; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

# ═══════════════════════════════════════════════════════════════
# COMPROBAR 3X-UI
# ═══════════════════════════════════════════════════════════════

xui_installed() {

    [[ -x "$XUI_BIN" ]] ||
    [[ -f /etc/systemd/system/x-ui.service ]]
}

# ═══════════════════════════════════════════════════════════════
# MOSTRAR CREDENCIALES DE INSTALACIÓN
# ═══════════════════════════════════════════════════════════════

show_install_credentials() {

    local RESULT_FILE="/etc/x-ui/install-result.env"

    echo ""

    section "🔐 CREDENCIALES 3X-UI"

    if [[ -f "$RESULT_FILE" ]]; then

        echo ""

        echo -e "${GREEN}Credenciales generadas por 3X-UI:${RESET}"
        echo ""

        grep -E \
            '^(XUI_USERNAME|XUI_PASSWORD|XUI_WEB_BASE_PATH|USERNAME|PASSWORD|WEB_BASE_PATH)=' \
            "$RESULT_FILE" 2>/dev/null

        echo ""

        echo -e "${GRAY}Archivo: $RESULT_FILE${RESET}"

    else

        warn "No se encontró $RESULT_FILE."

        echo ""
        echo -e "${GRAY}Usa:${RESET}"
        echo -e "${CYAN}x-ui${RESET}"
        echo -e "${GRAY}para consultar o modificar las credenciales.${RESET}"

    fi
}

# ═══════════════════════════════════════════════════════════════
# INSTALAR 3X-UI
# ═══════════════════════════════════════════════════════════════

install_xui() {

    local VERBOSE="${1:-1}"

    header "🌐 KEVINTECH 3X-UI" \
        "Instalación del panel XRay" \
        "v1.0"

    if xui_installed; then

        warn "3X-UI ya está instalado."

        echo ""
        echo -e " Estado: $(xui_status)"
        echo -e " Puerto: ${WHITE}$(xui_port)${RESET}"

        pause_menu
        return 0
    fi

    install_dependencies || {
        pause_menu
        return 1
    }

    echo ""

    echo -e "${CYAN}➜ Instalando 3X-UI oficial...${RESET}"

    # Instalador oficial actual
    if ! bash <(
        curl -Ls \
        https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh
    ); then

        error_msg "Falló la instalación de 3X-UI."

        pause_menu
        return 1
    fi

    systemctl daemon-reload

    systemctl enable x-ui >/dev/null 2>&1
    systemctl start x-ui >/dev/null 2>&1

    sleep 3

    if systemctl is-active --quiet x-ui; then

        ok "3X-UI instalado y activo."

        local PORT
        PORT=$(xui_port)

        xui_open_firewall "$PORT"

        echo ""
        echo -e "${WHITE}Puerto interno del panel: ${GREEN}${PORT}${RESET}"

        show_install_credentials

        echo ""
        echo -e "${YELLOW}💡 Ahora puedes configurar HTTPS desde la opción 7.${RESET}"

    else

        error_msg "3X-UI se instaló pero el servicio no está activo."

        echo ""

        journalctl \
            -u x-ui \
            -n 20 \
            --no-pager 2>/dev/null

    fi

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# ACTUALIZAR 3X-UI
# ═══════════════════════════════════════════════════════════════

update_xui() {

    header "🔄 ACTUALIZAR 3X-UI" \
        "Manteniendo la configuración" \
        "KevinTech"

    if ! xui_installed; then

        error_msg "3X-UI no está instalado."

        pause_menu
        return 1
    fi

    warn "Se ejecutará el instalador oficial para actualizar 3X-UI."

    echo ""

    read -r -p "¿Continuar? (s/n): " RESP

    [[ "$RESP" =~ ^[Ss]$ ]] || return 0

    echo ""

    if bash <(
        curl -Ls \
        https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh
    ); then

        systemctl daemon-reload
        systemctl enable x-ui >/dev/null 2>&1
        systemctl restart x-ui >/dev/null 2>&1

        ok "3X-UI actualizado."

        sleep 2

        # Volver a configurar HAProxy por si cambió el puerto.
        if [[ -f "$HAPROXY_CFG" ]]; then
            xui_haproxy_setup
        fi

    else

        error_msg "Falló la actualización."

    fi

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# CERTIFICADO AUTOFIRMADO
# ═══════════════════════════════════════════════════════════════

xui_generate_certificate() {

    local IP="$1"

    mkdir -p "$HAPROXY_CERT_DIR"

    if [[ -f "$HAPROXY_CERT" ]]; then
        return 0
    fi

    echo -e "${CYAN}➜ Generando certificado HTTPS para ${IP}...${RESET}"

    local KEY_FILE="$HAPROXY_CERT_DIR/xui-key.pem"
    local CRT_FILE="$HAPROXY_CERT_DIR/xui-cert.pem"

    if ! openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -days 3650 \
        -keyout "$KEY_FILE" \
        -out "$CRT_FILE" \
        -subj "/CN=$IP" \
        -addext "subjectAltName=IP:$IP" \
        >/dev/null 2>&1; then

        error_msg "No se pudo generar el certificado."

        return 1
    fi

    cat "$CRT_FILE" "$KEY_FILE" > "$HAPROXY_CERT"

    chmod 600 "$KEY_FILE"
    chmod 644 "$CRT_FILE"
    chmod 600 "$HAPROXY_CERT"

    ok "Certificado HTTPS generado."

    return 0
}

# ═══════════════════════════════════════════════════════════════
# ELIMINAR BLOQUE KEVINTECH 3X-UI DE HAPROXY
# ═══════════════════════════════════════════════════════════════

xui_haproxy_remove_block() {

    [[ -f "$HAPROXY_CFG" ]] || return 0

    # Elimina solamente el bloque marcado por KevinTech.
    sed -i \
        '/# KEVINTECH 3X-UI BEGIN/,/# KEVINTECH 3X-UI END/d' \
        "$HAPROXY_CFG"

    # Elimina posibles restos del formato antiguo.
    sed -i \
        '/# 3x-ui Panel config/d' \
        "$HAPROXY_CFG"

    sed -i \
        '/include \/etc\/haproxy\/haproxy-3xui.cfg/d' \
        "$HAPROXY_CFG"

    return 0
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURAR HAPROXY HTTPS
# ═══════════════════════════════════════════════════════════════

xui_haproxy_setup() {

    if ! xui_installed; then

        error_msg "3X-UI no está instalado."

        return 1
    fi

    if [[ ! -f "$HAPROXY_CFG" ]]; then

        error_msg "No existe $HAPROXY_CFG."

        return 1
    fi

    local IP
    local PANEL_PORT

    IP=$(xui_ip)
    PANEL_PORT=$(xui_port)

    echo ""
    echo -e "${CYAN}➜ IP pública: ${WHITE}${IP}${RESET}"
    echo -e "${CYAN}➜ Puerto interno 3X-UI: ${WHITE}${PANEL_PORT}${RESET}"
    echo -e "${CYAN}➜ Puerto HTTPS externo: ${WHITE}${HAPROXY_PORT}${RESET}"

    xui_generate_certificate "$IP" || return 1

    # Backup
    cp -a \
        "$HAPROXY_CFG" \
        "${HAPROXY_CFG}.kevintech-backup.$(date +%Y%m%d-%H%M%S)" \
        2>/dev/null || true

    # Quitar bloque anterior
    xui_haproxy_remove_block

    cat >> "$HAPROXY_CFG" <<EOF

# KEVINTECH 3X-UI BEGIN
frontend kevintech_xui_frontend
    mode http
    bind *:${HAPROXY_PORT} ssl crt ${HAPROXY_CERT}
    option forwardfor
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-For %[src]
    default_backend kevintech_xui_backend

backend kevintech_xui_backend
    mode http
    server kevintech_xui_local 127.0.0.1:${PANEL_PORT} check inter 2000 rise 2 fall 3
# KEVINTECH 3X-UI END

EOF

    echo ""

    if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then

        systemctl enable haproxy >/dev/null 2>&1

        if systemctl is-active --quiet haproxy; then
            systemctl reload haproxy >/dev/null 2>&1
        else
            systemctl restart haproxy >/dev/null 2>&1
        fi

        xui_open_firewall "$HAPROXY_PORT"

        echo ""

        ok "HAProxy configurado correctamente."

        echo ""
        echo -e "${WHITE}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${WHITE}║              ACCESO 3X-UI                  ║${RESET}"
        echo -e "${WHITE}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${WHITE}║ IP      : ${GREEN}${IP}${WHITE}${RESET}"
        echo -e "${WHITE}║ HTTPS   : ${GREEN}${HAPROXY_PORT}${WHITE}${RESET}"
        echo -e "${WHITE}║ Panel   : ${GREEN}https://${IP}:${HAPROXY_PORT}${WHITE}${RESET}"
        echo -e "${WHITE}╚══════════════════════════════════════════════╝${RESET}"

        echo ""
        warn "El certificado es autofirmado."
        echo -e "${GRAY}El navegador mostrará una advertencia de seguridad.${RESET}"

        return 0

    fi

    error_msg "La configuración de HAProxy tiene errores."

    echo ""
    haproxy -c -f "$HAPROXY_CFG" 2>&1

    return 1
}

# ═══════════════════════════════════════════════════════════════
# CAMBIAR PUERTO DEL PANEL
# ═══════════════════════════════════════════════════════════════

change_xui_port() {

    header "⚙️ PUERTO 3X-UI" \
        "Cambiar puerto interno del panel" \
        "KevinTech"

    if ! xui_installed; then

        error_msg "3X-UI no está instalado."

        pause_menu
        return
    fi

    local CURRENT
    CURRENT=$(xui_port)

    echo -e "Puerto actual: ${GREEN}${CURRENT}${RESET}"

    echo ""

    read -r -p "Nuevo puerto [1-65535]: " NEW_PORT

    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then

        error_msg "Puerto inválido."

        pause_menu
        return 1
    fi

    if (( NEW_PORT < 1 || NEW_PORT > 65535 )); then

        error_msg "Puerto fuera de rango."

        pause_menu
        return 1
    fi

    if [[ "$NEW_PORT" == "$CURRENT" ]]; then

        warn "El puerto ya es $NEW_PORT."

        pause_menu
        return 0
    fi

    echo ""

    if [[ -x "$XUI_BIN" ]]; then

        if "$XUI_BIN" setting -port "$NEW_PORT" >/dev/null 2>&1; then
            ok "Puerto interno cambiado."
        else
            error_msg "No se pudo cambiar el puerto mediante x-ui."
            pause_menu
            return 1
        fi

    else

        error_msg "No se encontró el binario x-ui."

        pause_menu
        return 1
    fi

    systemctl restart x-ui >/dev/null 2>&1

    sleep 2

    xui_open_firewall "$NEW_PORT"

    # Regenerar configuración HAProxy.
    if [[ -f "$HAPROXY_CFG" ]]; then
        xui_haproxy_setup
    fi

    sed -i '/^XUI_PANEL_PORT=/d' "$CONFIG"
    echo "XUI_PANEL_PORT=$NEW_PORT" >> "$CONFIG"

    echo ""

    ok "Puerto del panel cambiado a $NEW_PORT."

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# RESET DE CREDENCIALES
# ═══════════════════════════════════════════════════════════════

reset_credentials() {

    header "🔐 CREDENCIALES 3X-UI" \
        "Gestión de usuario y contraseña" \
        "KevinTech"

    if ! xui_installed; then

        error_msg "3X-UI no está instalado."

        pause_menu
        return
    fi

    if [[ -x "$XUI_BIN" ]]; then

        echo ""
        echo -e "${CYAN}Puedes utilizar el menú oficial de x-ui para${RESET}"
        echo -e "${CYAN}consultar o modificar las credenciales.${RESET}"

        echo ""

        "$XUI_BIN" setting 2>/dev/null || true

    else

        error_msg "No se encontró el binario x-ui."

    fi

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# ESTADO
# ═══════════════════════════════════════════════════════════════

show_status() {

    header "📊 ESTADO 3X-UI" \
        "Panel XRay · KevinTech" \
        "v1.0"

    local IP
    local PORT

    IP=$(xui_ip)
    PORT=$(xui_port)

    echo ""

    echo -e "  3X-UI       : $(xui_status)"
    echo -e "  HAProxy     : $(haproxy_status)"
    echo -e "  IP pública  : ${WHITE}${IP}${RESET}"
    echo -e "  Panel local : ${WHITE}${PORT}${RESET}"
    echo -e "  HTTPS       : ${WHITE}${HAPROXY_PORT}${RESET}"

    echo ""

    echo -e "${CYAN}Puertos escuchando:${RESET}"

    ss -ltnp 2>/dev/null |
        grep -E ":(${PORT}|${HAPROXY_PORT}) " ||
        echo -e "${GRAY}No se encontraron puertos.${RESET}"

    echo ""

    echo -e "${CYAN}Servicios:${RESET}"

    systemctl is-active x-ui 2>/dev/null ||
        echo -e "${RED}x-ui: detenido${RESET}"

    systemctl is-active haproxy 2>/dev/null ||
        echo -e "${RED}haproxy: detenido${RESET}"

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# LOGS
# ═══════════════════════════════════════════════════════════════

show_logs() {

    clear

    header "📜 LOGS 3X-UI" \
        "journalctl" \
        "KevinTech"

    echo ""

    echo -e "${GRAY}Presiona Ctrl+C para regresar.${RESET}"

    echo ""

    journalctl \
        -u x-ui \
        -e \
        --no-pager \
        -f
}

# ═══════════════════════════════════════════════════════════════
# INFORMACIÓN
# ═══════════════════════════════════════════════════════════════

show_info() {

    header "ℹ️ INFORMACIÓN 3X-UI" \
        "Panel XRay · KevinTech" \
        "v1.0"

    local IP
    local PORT

    IP=$(xui_ip)
    PORT=$(xui_port)

    echo ""

    echo -e "${WHITE}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║               KEVINTECH 3X-UI              ║${RESET}"
    echo -e "${WHITE}╠══════════════════════════════════════════════╣${RESET}"
    echo -e "${WHITE}║${RESET} IP pública : ${GREEN}${IP}${RESET}"
    echo -e "${WHITE}║${RESET} Puerto     : ${GREEN}${PORT}${RESET}"
    echo -e "${WHITE}║${RESET} HTTPS      : ${GREEN}${HAPROXY_PORT}${RESET}"
    echo -e "${WHITE}║${RESET} Servicio   : ${GREEN}x-ui${RESET}"
    echo -e "${WHITE}║${RESET} HAProxy    : ${GREEN}54323${RESET}"
    echo -e "${WHITE}╚══════════════════════════════════════════════╝${RESET}"

    echo ""

    echo -e "${CYAN}Acceso HTTPS:${RESET}"
    echo -e "${GREEN}https://${IP}:${HAPROXY_PORT}${RESET}"

    echo ""

    echo -e "${GRAY}Credenciales:${RESET}"

    if [[ -f /etc/x-ui/install-result.env ]]; then

        echo -e "${GREEN}Generadas durante la instalación.${RESET}"
        echo -e "${GRAY}/etc/x-ui/install-result.env${RESET}"

    else

        echo -e "${GRAY}Consulta mediante el comando x-ui.${RESET}"

    fi

    echo ""

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# DESINSTALAR
# ═══════════════════════════════════════════════════════════════

uninstall_xui() {

    header "🗑️ DESINSTALAR 3X-UI" \
        "Eliminar panel y XRay" \
        "KevinTech"

    echo ""

    warn "Esto eliminará 3X-UI y su instalación local."

    echo ""

    read -r -p "¿Continuar? (s/n): " RESP

    [[ "$RESP" =~ ^[Ss]$ ]] || return 0

    echo ""

    echo -e "${CYAN}➜ Deteniendo x-ui...${RESET}"

    systemctl stop x-ui >/dev/null 2>&1 || true
    systemctl disable x-ui >/dev/null 2>&1 || true

    echo -e "${CYAN}➜ Eliminando servicio...${RESET}"

    rm -f /etc/systemd/system/x-ui.service

    systemctl daemon-reload

    echo -e "${CYAN}➜ Eliminando instalación...${RESET}"

    rm -rf /etc/x-ui
    rm -rf /usr/local/x-ui
    rm -f /usr/bin/x-ui

    # Eliminar bloque HAProxy
    if [[ -f "$HAPROXY_CFG" ]]; then

        xui_haproxy_remove_block

        if haproxy -c -f "$HAPROXY_CFG" >/dev/null 2>&1; then
            systemctl reload haproxy >/dev/null 2>&1
        fi

    fi

    echo -e "${CYAN}➜ Cerrando puerto HTTPS...${RESET}"

    xui_close_firewall "$HAPROXY_PORT"

    echo -e "${CYAN}➜ Eliminando certificado...${RESET}"

    rm -f "$HAPROXY_CERT"
    rm -f "$HAPROXY_CERT_DIR/xui-key.pem"
    rm -f "$HAPROXY_CERT_DIR/xui-cert.pem"

    sed -i '/^XUI_PANEL_PORT=/d' "$CONFIG"

    echo ""

    ok "3X-UI eliminado."

    pause_menu
}

# ═══════════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ═══════════════════════════════════════════════════════════════

manage_xui() {

    while true; do

        local IP
        local PORT

        IP=$(xui_ip)
        PORT=$(xui_port)

        header "🌐 KEVINTECH 3X-UI" \
            "Panel web para gestión de XRay" \
            "v1.0"

        echo ""

        echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║                ESTADO                       ║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

        echo -e "${WHITE}║${RESET} 3X-UI     : $(xui_status)"
        echo -e "${WHITE}║${RESET} HAProxy   : $(haproxy_status)"
        echo -e "${WHITE}║${RESET} IP        : ${GREEN}${IP}${RESET}"
        echo -e "${WHITE}║${RESET} Panel     : ${GREEN}${PORT}${RESET}"
        echo -e "${WHITE}║${RESET} HTTPS     : ${GREEN}${HAPROXY_PORT}${RESET}"

        echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

        echo ""

        if xui_installed; then

            echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║                GESTIÓN                      ║${RESET}"
            echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

            echo -e "${WHITE}║${RESET} [01] 🚀 Instalar / Reparar 3X-UI            ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [02] 🔄 Actualizar 3X-UI                   ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [03] 🗑️ Desinstalar 3X-UI                  ${WHITE}║${RESET}"

            echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

            echo -e "${WHITE}║${RESET} [04] ▶️ Iniciar Servicio                    ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [05] ⏹️ Detener Servicio                    ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [06] 🔄 Reiniciar Servicio                  ${WHITE}║${RESET}"

            echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

            echo -e "${WHITE}║${RESET} [07] 🔐 Configurar HTTPS + HAProxy          ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [08] 📊 Ver Estado                          ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [09] 📜 Ver Logs                            ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [10] 🔑 Credenciales                        ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [11] ⚙️ Cambiar Puerto                      ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [12] ℹ️ Información                         ${WHITE}║${RESET}"

            echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
            echo -e "${WHITE}║${RESET} [00] ↩️ Regresar                             ${WHITE}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

        else

            echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║             3X-UI NO INSTALADO              ║${RESET}"
            echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
            echo -e "${WHITE}║${RESET} [01] 🚀 Instalar 3X-UI                     ${WHITE}║${RESET}"
            echo -e "${WHITE}║${RESET} [00] ↩️ Regresar                             ${WHITE}║${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

        fi

        echo ""

        read -r -p "➜ Seleccione una opción: " OP

        case "$OP" in

            1)
                if xui_installed; then
                    install_xui
                else
                    install_xui
                fi
                ;;

            2)
                [[ "$XUI_SERVICE" == "x-ui" ]] &&
                    update_xui
                ;;

            3)
                uninstall_xui
                ;;

            4)
                systemctl start x-ui >/dev/null 2>&1
                ok "Servicio iniciado."
                sleep 2
                ;;

            5)
                systemctl stop x-ui >/dev/null 2>&1
                echo -e "${YELLOW}⏹️ Servicio detenido.${RESET}"
                sleep 2
                ;;

            6)
                systemctl restart x-ui >/dev/null 2>&1
                ok "Servicio reiniciado."
                sleep 2
                ;;

            7)
                xui_haproxy_setup
                pause_menu
                ;;

            8)
                show_status
                ;;

            9)
                show_logs
                ;;

            10)
                reset_credentials
                ;;

            11)
                change_xui_port
                ;;

            12)
                show_info
                ;;

            0)
                exec bash "$BASE/protocolos/menu.sh"
                ;;

            *)
                error_msg "Opción inválida."
                sleep 2
                ;;

        esac

    done
}

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════

case "${1:-}" in

    install)
        install_xui
        ;;

    update)
        update_xui
        ;;

    uninstall)
        uninstall_xui
        ;;

    start)
        systemctl start x-ui
        ok "3X-UI iniciado."
        ;;

    stop)
        systemctl stop x-ui
        echo -e "${YELLOW}⏹️ 3X-UI detenido.${RESET}"
        ;;

    restart)
        systemctl restart x-ui
        ok "3X-UI reiniciado."
        ;;

    status)
        show_status
        ;;

    log)
        show_logs
        ;;

    haproxy)
        xui_haproxy_setup
        ;;

    *)
        manage_xui
        ;;

esac