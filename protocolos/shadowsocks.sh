#!/bin/bash
#==================================================
# KEVINTECH NETWORK PREMIUM
# Shadowsocks Manager v1.0
#
# Proxy SOCKS5 cifrado — shadowsocks-libev
#
# • Paquete oficial: shadowsocks-libev
# • Cifrado: aes-256-gcm
# • Puerto por defecto: 8388
# • TCP + UDP
# • URL ss:// para compartir
# • Sin librerías externas de KevinTech
#==================================================

# ── i18n shim ─────────────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then
    trx() { printf '%s' "$1"; }
fi
#───────────────────────────────────────────────────

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

#==================================================
# COLORES
#==================================================

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
GOLD="${MV_GLD:-\e[1;93m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_DIM:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

#==================================================
# CONFIGURACIÓN
#==================================================

DIR="/etc/shadowsocks-libev"

SS_PORT="${SS_PORT:-8388}"
SS_PASSWORD="${SS_PASSWORD:-}"
SS_METHOD="aes-256-gcm"

CONF="$DIR/$SS_PORT.json"
SVC_NAME="shadowsocks-libev-server@$SS_PORT"

#==================================================
# FUNCIONES INTERNAS
#==================================================

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

anim_init() {
    return 0
}

anim_step() {
    echo ""
    echo -e "${CYAN}➜ ${WHITE}$1${RESET}"
}

anim_run() {
    local LABEL="$1"
    shift

    echo -ne " ${CYAN}➜${RESET} ${WHITE}${LABEL}${RESET} "

    if "$@" >/dev/null 2>&1; then
        echo -e "${GREEN}✔ OK${RESET}"
        return 0
    else
        echo -e "${RED}✘ ERROR${RESET}"
        return 1
    fi
}

svc_restart_anim() {
    local SERVICE_NAME="$1"
    local LABEL="$2"

    echo -ne " ${CYAN}➜${RESET} ${WHITE}${LABEL}${RESET} "

    if systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 &&
       systemctl is-active --quiet "$SERVICE_NAME"; then

        echo -e "${GREEN}✔ OK${RESET}"
        return 0
    fi

    echo -e "${RED}✘ ERROR${RESET}"
    return 1
}

anim_done() {
    echo -e " ${GREEN}✔ $1${RESET}"
}

anim_fail() {
    echo -e " ${RED}✘ $1${RESET}"
}

mv_brand_header() {

    local TITLE="${1:-SHADOWSOCKS}"

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}⚡ KEVINTECH${RESET}               ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${WHITE}${TITLE}${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}             ${GRAY}SOCKS5 ENCRYPTED${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
}

mv_header() {
    mv_brand_header "$1"
}

mv_deliv_header() {

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}          ${MAGENTA}$1${RESET}"

    [[ -n "$2" ]] &&
        echo -e "${CYAN}║${RESET}          ${GRAY}$2${RESET}"

    [[ -n "$3" ]] &&
        echo -e "${CYAN}║${RESET}          ${GRAY}$3${RESET}"

    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
}

mv_deliv_sec() {

    echo ""

    echo -e \
        "${CYAN}╭─ ${WHITE}$1${CYAN} ────────────────────────────────╮${RESET}"
}

mv_dcard_top() {
    echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
}

mv_dcard_row() {

    printf \
        "${CYAN}│${RESET} %s %-13s ${WHITE}%-24s${RESET}${CYAN}│${RESET}\n" \
        "$1" "$2" "$3"
}

mv_dcard_bot() {
    echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"
}

mv_deliv_pie() {

    echo ""

    line
}

mv_tick() {
    printf '%s' "$1"
}

#==================================================
# DATOS DEL SERVIDOR
#==================================================

get_vps_ip() {

    local IP

    IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    if [[ -z "$IP" ]]; then
        IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
    fi

    echo "$IP"
}

get_ss_url() {

    local VPS_IP="$1"

    [[ -z "$VPS_IP" ]] && return 1
    [[ -z "$SS_PASSWORD" ]] && return 1

    local DATA

    DATA="${SS_METHOD}:${SS_PASSWORD}@${VPS_IP}:${SS_PORT}"

    local ENCODED

    ENCODED=$(printf '%s' "$DATA" | base64 -w0 2>/dev/null)

    [[ -z "$ENCODED" ]] &&
        ENCODED=$(printf '%s' "$DATA" | base64 | tr -d '\n')

    echo "ss://${ENCODED}#KevinTech"
}

#==================================================
# INSTALAR DEPENDENCIAS
#==================================================

install_dependencies() {

    anim_step "Instalando Shadowsocks-libev"

    if ! command -v apt-get >/dev/null 2>&1; then

        echo -e \
            "${RED}❌ Este sistema no utiliza apt.${RESET}"

        return 1
    fi

    anim_run \
        "Actualizar paquetes" \
        apt-get update -qq

    anim_run \
        "Instalar Shadowsocks-libev" \
        apt-get install -y \
        shadowsocks-libev \
        openssl \
        iptables \
        iproute2

    mkdir -p "$DIR"

    if ! command -v ss-server >/dev/null 2>&1; then

        echo -e \
            "${RED}❌ No se pudo instalar shadowsocks-libev.${RESET}"

        return 1
    fi

    return 0
}

#==================================================
# CREAR CONFIGURACIÓN
#==================================================

create_config() {

    mkdir -p "$DIR"

    if [[ -z "$SS_PASSWORD" ]]; then

        SS_PASSWORD=$(
            openssl rand -base64 18 |
            tr -dc 'a-zA-Z0-9' |
            head -c 16
        )

    fi

    cat > "$CONF" <<EOFCONF
{
    "server": "0.0.0.0",
    "server_port": $SS_PORT,
    "password": "$SS_PASSWORD",
    "method": "$SS_METHOD",
    "mode": "tcp_and_udp",
    "fast_open": true
}
EOFCONF

    chmod 644 "$CONF"

    echo -e \
        " ${GREEN}✔${RESET} Configuración creada: ${GRAY}$CONF${RESET}"
}

#==================================================
# CREAR SERVICIO
#==================================================

create_service() {

    systemctl daemon-reload

    systemctl enable "$SVC_NAME" \
        >/dev/null 2>&1

    echo -e \
        " ${GREEN}✔${RESET} Servicio habilitado"
}

#==================================================
# ABRIR PUERTOS
#==================================================

open_ports() {

    echo ""
    echo -e \
        "${CYAN}➜${RESET} Abriendo puerto ${WHITE}$SS_PORT${RESET}..."

    iptables -C INPUT \
        -p tcp \
        --dport "$SS_PORT" \
        -j ACCEPT 2>/dev/null ||
    iptables -A INPUT \
        -p tcp \
        --dport "$SS_PORT" \
        -j ACCEPT

    iptables -C INPUT \
        -p udp \
        --dport "$SS_PORT" \
        -j ACCEPT 2>/dev/null ||
    iptables -A INPUT \
        -p udp \
        --dport "$SS_PORT" \
        -j ACCEPT

    if command -v ufw >/dev/null 2>&1 &&
       ufw status 2>/dev/null |
       grep -q "Status: active"; then

        ufw allow "$SS_PORT/tcp" \
            >/dev/null 2>&1

        ufw allow "$SS_PORT/udp" \
            >/dev/null 2>&1
    fi

    mkdir -p /etc/iptables

    iptables-save \
        > /etc/iptables/rules.v4 2>/dev/null

    echo -e \
        " ${GREEN}✔${RESET} TCP/$SS_PORT y UDP/$SS_PORT abiertos"
}

#==================================================
# TEST SHADOWSOCKS
#==================================================

test_shadowsocks() {

    echo ""

    echo -e \
        "${CYAN}╭─ PRUEBA DEL SERVICIO ───────────────────────╮${RESET}"

    if systemctl is-active --quiet "$SVC_NAME"; then

        echo -e \
            "${CYAN}│${RESET} ${GREEN}● Servicio activo${RESET}"

        if ss -ltnp 2>/dev/null |
            grep -qE ":${SS_PORT}[[:space:]]"; then

            echo -e \
                "${CYAN}│${RESET} ${GREEN}✔ TCP escuchando en $SS_PORT${RESET}"

        else

            echo -e \
                "${CYAN}│${RESET} ${YELLOW}⚠ TCP no detectado por ss${RESET}"

        fi

        if ss -lunp 2>/dev/null |
            grep -qE ":${SS_PORT}[[:space:]]"; then

            echo -e \
                "${CYAN}│${RESET} ${GREEN}✔ UDP escuchando en $SS_PORT${RESET}"

        fi

        echo -e \
            "${CYAN}╰────────────────────────────────────────────╯${RESET}"

        return 0
    fi

    echo -e \
        "${CYAN}│${RESET} ${RED}● Servicio detenido${RESET}"

    echo -e \
        "${CYAN}╰────────────────────────────────────────────╯${RESET}"

    return 1
}

#==================================================
# INSTALAR SHADOWSOCKS
#==================================================

install_shadowsocks() {

    clear

    mv_deliv_header \
        "🚀 INSTALAR SHADOWSOCKS" \
        "KevinTech SOCKS5 cifrado"

    echo ""

    install_dependencies || return 1

    # Evitar conflicto con servicio legacy
    systemctl stop \
        shadowsocks-libev.service \
        2>/dev/null

    systemctl disable \
        shadowsocks-libev.service \
        2>/dev/null

    rm -f "$DIR/config.json"

    anim_step "Configurando Shadowsocks"

    create_config

    create_service

    anim_step "Configurando firewall"

    open_ports

    echo ""

    anim_step "Iniciando Shadowsocks"

    systemctl daemon-reload

    systemctl enable "$SVC_NAME" \
        >/dev/null 2>&1

    if ! svc_restart_anim \
        "$SVC_NAME" \
        "Arrancando Shadowsocks"; then

        echo ""

        echo -e \
            "${RED}❌ Shadowsocks no pudo iniciar.${RESET}"

        echo ""

        journalctl \
            -u "$SVC_NAME" \
            -n 20 \
            --no-pager

        return 1
    fi

    test_shadowsocks

    sleep 2

    if systemctl is-active --quiet "$SVC_NAME"; then

        sed -i '/^SHADOWSOCKS=/d' "$CONFIG"
        echo "SHADOWSOCKS=ON" >> "$CONFIG"

        sed -i '/^SS_PORT=/d' "$CONFIG"
        echo "SS_PORT=$SS_PORT" >> "$CONFIG"

        sed -i '/^SS_PASSWORD=/d' "$CONFIG"
        echo "SS_PASSWORD=$SS_PASSWORD" >> "$CONFIG"

        source "$CONFIG"

        local VPS_IP
        local SS_URL

        VPS_IP=$(get_vps_ip)
        SS_URL=$(get_ss_url "$VPS_IP")

        clear

        mv_deliv_header \
            "🎉 SHADOWSOCKS INSTALADO" \
            "KevinTech SOCKS5 cifrado"

        echo ""

        mv_deliv_sec "📲 DATOS DE CONEXIÓN"

        mv_dcard_top

        mv_dcard_row \
            "🌍" \
            "IP / HOST" \
            "$VPS_IP"

        mv_dcard_row \
            "🚀" \
            "Puerto" \
            "$SS_PORT"

        mv_dcard_row \
            "🔐" \
            "Método" \
            "$SS_METHOD"

        mv_dcard_row \
            "🔑" \
            "Clave" \
            "$SS_PASSWORD"

        mv_dcard_bot

        echo ""

        mv_deliv_sec "🔗 ENLACE SS"

        echo ""

        echo -e \
            "${GREEN}${SS_URL}${RESET}"

        echo ""

        mv_deliv_sec "📱 CONFIGURACIÓN"

        echo -e \
            " ${CYAN}➜${RESET} Servidor : ${WHITE}$VPS_IP${RESET}"

        echo -e \
            " ${CYAN}➜${RESET} Puerto   : ${WHITE}$SS_PORT${RESET}"

        echo -e \
            " ${CYAN}➜${RESET} Método   : ${WHITE}$SS_METHOD${RESET}"

        echo -e \
            " ${CYAN}➜${RESET} Modo     : ${WHITE}TCP + UDP${RESET}"

        echo ""

        echo -e \
            "${GREEN}✔ Importa la URL ss:// en tu cliente Shadowsocks.${RESET}"

        echo ""

        mv_deliv_pie

        read -n1 -r -p \
            "$(echo -e "${GRAY}Presiona una tecla para continuar...${RESET}")"

    else

        echo ""

        echo -e \
            "${RED}❌ Error iniciando Shadowsocks${RESET}"

        echo ""

        systemctl status \
            "$SVC_NAME" \
            --no-pager

        sleep 3

    fi
}

#==================================================
# ELIMINAR SHADOWSOCKS
#==================================================

remove_shadowsocks() {

    clear

    mv_deliv_header \
        "🗑️ DESINSTALAR SHADOWSOCKS" \
        "KevinTech SOCKS5"

    echo ""

    echo -e \
        "${YELLOW}⚠ Se eliminará el servicio y su configuración.${RESET}"

    echo ""

    read -rp \
        "$(echo -e "${RED}➜${RESET} ¿Continuar? [s/N]: ")" R

    [[ "$R" =~ ^[Ss]$ ]] || return

    echo ""

    anim_step "Desinstalando Shadowsocks"

    anim_run \
        "Detener servicio" \
        systemctl stop "$SVC_NAME"

    anim_run \
        "Deshabilitar servicio" \
        systemctl disable "$SVC_NAME"

    anim_run \
        "Eliminar configuración" \
        rm -f "$CONF"

    systemctl daemon-reload

    iptables -D INPUT \
        -p tcp \
        --dport "$SS_PORT" \
        -j ACCEPT 2>/dev/null

    iptables -D INPUT \
        -p udp \
        --dport "$SS_PORT" \
        -j ACCEPT 2>/dev/null

    if command -v ufw >/dev/null 2>&1 &&
       ufw status 2>/dev/null |
       grep -q "Status: active"; then

        ufw delete allow "$SS_PORT/tcp" \
            >/dev/null 2>&1

        ufw delete allow "$SS_PORT/udp" \
            >/dev/null 2>&1
    fi

    sed -i '/^SHADOWSOCKS=/d' "$CONFIG"
    echo "SHADOWSOCKS=OFF" >> "$CONFIG"

    echo ""

    echo -e \
        "${GREEN}╭────────────────────────────────────────────╮${RESET}"

    echo -e \
        "${GREEN}│${RESET}       ✅ SHADOWSOCKS DESINSTALADO        ${GREEN}│${RESET}"

    echo -e \
        "${GREEN}╰────────────────────────────────────────────╯${RESET}"

    echo ""

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# NUEVA CLAVE
#==================================================

reconfig_shadowsocks() {

    clear

    mv_deliv_header \
        "🔄 NUEVA CLAVE SHADOWSOCKS" \
        "Actualizar credenciales"

    echo ""

    read -rp \
        "$(echo -e "${CYAN}➜${RESET} Nueva clave ${GRAY}(Enter = automática)${RESET}: ")" NPASS

    if [[ -z "$NPASS" ]]; then

        NPASS=$(
            openssl rand -base64 18 |
            tr -dc 'a-zA-Z0-9' |
            head -c 16
        )

    fi

    SS_PASSWORD="$NPASS"

    create_config

    if ! systemctl restart "$SVC_NAME" \
        >/dev/null 2>&1; then

        echo ""

        echo -e \
            "${RED}❌ No se pudo reiniciar Shadowsocks.${RESET}"

        sleep 2
        return
    fi

    sed -i '/^SS_PASSWORD=/d' "$CONFIG"
    echo "SS_PASSWORD=$SS_PASSWORD" >> "$CONFIG"

    source "$CONFIG"

    local VPS_IP
    local SS_URL

    VPS_IP=$(get_vps_ip)
    SS_URL=$(get_ss_url "$VPS_IP")

    clear

    mv_deliv_header \
        "🔄 CLAVE ACTUALIZADA" \
        "Shadowsocks · KevinTech"

    echo ""

    mv_deliv_sec "📲 NUEVAS CREDENCIALES"

    mv_dcard_top

    mv_dcard_row \
        "🌍" \
        "IP / HOST" \
        "$VPS_IP"

    mv_dcard_row \
        "🚀" \
        "Puerto" \
        "$SS_PORT"

    mv_dcard_row \
        "🔑" \
        "Nueva Clave" \
        "$SS_PASSWORD"

    mv_dcard_row \
        "🔐" \
        "Método" \
        "$SS_METHOD"

    mv_dcard_bot

    echo ""

    mv_deliv_sec "🔗 NUEVO ENLACE SS"

    echo ""

    echo -e \
        "${GREEN}${SS_URL}${RESET}"

    echo ""

    mv_deliv_pie

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# REINICIAR
#==================================================

restart_shadowsocks() {

    clear

    mv_deliv_header \
        "🔄 REINICIAR SHADOWSOCKS" \
        "KevinTech SOCKS5"

    echo ""

    if svc_restart_anim \
        "$SVC_NAME" \
        "Reiniciando servicio"; then

        echo ""

        echo -e \
            "${GREEN}✔ Shadowsocks está activo.${RESET}"

        test_shadowsocks

    else

        echo ""

        echo -e \
            "${RED}❌ Error al reiniciar.${RESET}"

    fi

    echo ""

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# ESTADO
#==================================================

status_shadowsocks() {

    clear

    mv_deliv_header \
        "📊 ESTADO SHADOWSOCKS" \
        "KevinTech SOCKS5 cifrado"

    echo ""

    if systemctl is-active --quiet "$SVC_NAME"; then
        echo -e \
            " ${GREEN}● SERVICIO ACTIVO${RESET}"
    else
        echo -e \
            " ${RED}● SERVICIO DETENIDO${RESET}"
    fi

    echo ""

    mv_deliv_sec "⚙️ INFORMACIÓN"

    mv_dcard_top

    mv_dcard_row \
        "⚡" \
        "Servicio" \
        "$SVC_NAME"

    mv_dcard_row \
        "🚀" \
        "Puerto" \
        "$SS_PORT"

    mv_dcard_row \
        "🔐" \
        "Método" \
        "$SS_METHOD"

    mv_dcard_row \
        "📡" \
        "Modo" \
        "TCP + UDP"

    mv_dcard_bot

    echo ""

    mv_deliv_sec "📡 PUERTOS"

    if ss -ltnp 2>/dev/null |
        grep -qE ":${SS_PORT}[[:space:]]"; then

        echo -e \
            " ${GREEN}✔ TCP $SS_PORT escuchando${RESET}"

    else

        echo -e \
            " ${RED}✘ TCP $SS_PORT no detectado${RESET}"

    fi

    if ss -lunp 2>/dev/null |
        grep -qE ":${SS_PORT}[[:space:]]"; then

        echo -e \
            " ${GREEN}✔ UDP $SS_PORT escuchando${RESET}"

    else

        echo -e \
            " ${YELLOW}⚠ UDP no detectado${RESET}"

    fi

    echo ""

    mv_deliv_sec "📝 ÚLTIMOS LOGS"

    journalctl \
        -u "$SVC_NAME" \
        -n 8 \
        --no-pager

    echo ""

    mv_deliv_pie

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# DATOS DE CONEXIÓN
#==================================================

show_info() {

    clear

    local VPS_IP
    local SS_URL

    VPS_IP=$(get_vps_ip)
    SS_URL=$(get_ss_url "$VPS_IP")

    mv_deliv_header \
        "📱 DATOS SHADOWSOCKS" \
        "Proxy SOCKS5 cifrado"

    echo ""

    mv_deliv_sec "📲 DATOS DE CONEXIÓN"

    mv_dcard_top

    mv_dcard_row \
        "🌍" \
        "IP / HOST" \
        "$VPS_IP"

    mv_dcard_row \
        "🚀" \
        "Puerto" \
        "$SS_PORT"

    mv_dcard_row \
        "🔑" \
        "Clave" \
        "$SS_PASSWORD"

    mv_dcard_row \
        "🔐" \
        "Método" \
        "$SS_METHOD"

    mv_dcard_row \
        "📡" \
        "Modo" \
        "TCP + UDP"

    mv_dcard_bot

    echo ""

    mv_deliv_sec "🔗 ENLACE SS"

    echo ""

    echo -e \
        "${GREEN}${SS_URL}${RESET}"

    echo ""

    mv_deliv_pie

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# CLI HEADLESS
#==================================================

if [[ "${1:-}" == "--install" ]]; then

    [[ -n "${2:-}" ]] &&
        export SS_PORT="$2"

    [[ -n "${3:-}" ]] &&
        export SS_PASSWORD="$3"

    # Actualizar variables derivadas
    CONF="$DIR/$SS_PORT.json"
    SVC_NAME="shadowsocks-libev-server@$SS_PORT"

    install_shadowsocks

    exit $?
fi

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true
do

    clear

    source "$CONFIG"

    SS_PORT="${SS_PORT:-8388}"
    SS_PASSWORD="${SS_PASSWORD:-}"

    CONF="$DIR/$SS_PORT.json"
    SVC_NAME="shadowsocks-libev-server@$SS_PORT"

    if systemctl is-active --quiet "$SVC_NAME" 2>/dev/null; then

        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    elif [[ -f "$CONF" ]]; then

        STATUS="${RED}🔴 DETENIDO${RESET}"

    else

        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

    fi

    #==================================================
    # CABECERA
    #==================================================

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}          ${MAGENTA}🐋 KEVINTECH SHADOWSOCKS${RESET}       ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}             ${WHITE}SOCKS5 CIFRADO${RESET}             ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}              ${GRAY}PREMIUM MANAGER${RESET}            ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${CYAN}║${RESET}  ${WHITE}Estado     :${RESET} $STATUS"

    echo -e \
        "${CYAN}║${RESET}  ${WHITE}Puerto     :${RESET} ${CYAN}$SS_PORT${RESET}"

    echo -e \
        "${CYAN}║${RESET}  ${WHITE}Método     :${RESET} ${CYAN}$SS_METHOD${RESET}"

    echo -e \
        "${CYAN}║${RESET}  ${WHITE}Protocolo  :${RESET} ${CYAN}TCP + UDP${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${CYAN}║${RESET}                ${WHITE}⚡ OPCIONES${RESET}                ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    if [[ "$SHADOWSOCKS" == "ON" ]]; then

        echo -e \
            "${CYAN}║${RESET}  ${GREEN}[01]${RESET} 🔑 Nueva Clave                        ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}  ${GREEN}[02]${RESET} 🗑️  Desinstalar                      ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}  ${GREEN}[03]${RESET} 🔄 Reiniciar Servicio                 ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}  ${GREEN}[04]${RESET} 📊 Ver Estado                         ${CYAN}║${RESET}"

        echo -e \
            "${CYAN}║${RESET}  ${GREEN}[05]${RESET} 📱 Datos de Conexión                  ${CYAN}║${RESET}"

    else

        echo -e \
            "${CYAN}║${RESET}  ${GREEN}[01]${RESET} 🚀 Instalar Shadowsocks               ${CYAN}║${RESET}"

    fi

    echo -e \
        "${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}  ${GRAY}[00]${RESET} ↩️  Regresar                            ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    echo ""

    read -rp \
        "$(echo -e "${CYAN}╰─➤${RESET} ${WHITE}Selecciona una opción:${RESET} ")" OP

    case "$OP" in

        1)

            if [[ "$SHADOWSOCKS" == "ON" ]]; then
                reconfig_shadowsocks
            else
                install_shadowsocks
            fi

            ;;

        2)

            [[ "$SHADOWSOCKS" == "ON" ]] &&
                remove_shadowsocks

            ;;

        3)

            [[ "$SHADOWSOCKS" == "ON" ]] &&
                restart_shadowsocks

            ;;

        4)

            [[ "$SHADOWSOCKS" == "ON" ]] &&
                status_shadowsocks

            ;;

        5)

            [[ "$SHADOWSOCKS" == "ON" ]] &&
                show_info

            ;;

        00|0)

            exec bash "$BASE/protocolos/menu.sh"

            ;;

        *)

            echo ""
            echo -e \
                "${RED}✘ Opción inválida.${RESET}"

            sleep 1

            ;;

    esac

done