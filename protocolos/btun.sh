#!/bin/bash
#==================================================
# KEVINTECH NETWORK PREMIUM
# BTUN Manager v1.0
#
# VPN ligero sobre TCP/UDP con autenticación
# Subred: 10.77.0.0/16
# Interfaz: btun0
# Puerto por defecto: 7900
#
# • TCP + UDP
# • Usuarios gestionables
# • Autenticación mediante archivo
# • Binario multi-arquitectura
# • Instalación automática
# • Estado del servicio
# • Datos de conexión
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
# CONFIGURACIÓN BTUN
#==================================================

SERVICE="btun"
DIR="/etc/btun"
BIN="/usr/local/bin/btun-server"
AUTH_FILE="$DIR/users"

BTUN_PORT="${BTUN_PORT:-7900}"
SUBNET="${BTUN_SUBNET:-10.77.0.0/16}"

#==================================================
# FUNCIONES INTERNAS
# SIN LIBRERÍAS EXTERNAS
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
    local TITLE="${1:-BTUN}"

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}⚡ KEVINTECH${RESET}               ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${WHITE}${TITLE}${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}             ${GRAY}VPN TCP / UDP${RESET}               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
}

mv_header() {
    mv_brand_header "$1"
}

mv_deliv_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}          ${MAGENTA}$1${RESET}"
    [[ -n "$2" ]] && echo -e "${CYAN}║${RESET}          ${GRAY}$2${RESET}"
    [[ -n "$3" ]] && echo -e "${CYAN}║${RESET}          ${GRAY}$3${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
}

mv_deliv_sec() {
    echo ""
    echo -e "${CYAN}╭─ ${WHITE}$1${CYAN} ────────────────────────────────╮${RESET}"
}

mv_dcard_top() {
    echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
}

mv_dcard_row() {
    printf "${CYAN}│${RESET} %s %-13s ${WHITE}%-24s${RESET}${CYAN}│${RESET}\n" \
        "$1" "$2" "$3"
}

mv_dcard_bot() {
    echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"
}

mv_deliv_pie() {
    echo ""
    line
}

#==================================================
# DEPENDENCIAS
#==================================================

install_dependencies() {

    anim_step "Instalando dependencias"

    if command -v apt-get >/dev/null 2>&1; then

        anim_run "Actualizar paquetes" \
            apt-get update -qq

        anim_run "Instalar paquetes base" \
            apt-get install -y \
            curl \
            openssl \
            ca-certificates \
            iproute2 \
            iptables \
            iptables-persistent

    else

        echo -e "${RED}❌ Sistema compatible con apt no encontrado.${RESET}"
        return 1

    fi

    mkdir -p "$DIR"
}

#==================================================
# DETECTAR ARQUITECTURA
#==================================================

detect_arch() {

    local ARCH
    ARCH=$(uname -m)

    case "$ARCH" in

        x86_64)
            echo "linux-amd64"
            ;;

        aarch64|arm64)
            echo "linux-arm64"
            ;;

        armv7l|armv6l)
            echo "linux-arm"
            ;;

        i386|i686)
            echo "linux-386"
            ;;

        *)
            echo -e "${RED}❌ Arquitectura no soportada: $ARCH${RESET}" >&2
            return 1
            ;;

    esac
}

#==================================================
# INSTALAR BINARIO BTUN
#==================================================

install_binary() {

    local ARCH_TAG
    local LOCAL_SRC

    ARCH_TAG=$(detect_arch) || return 1

    echo ""
    echo -e "${CYAN}➜${RESET} Arquitectura: ${WHITE}$ARCH_TAG${RESET}"
    echo ""

    for LOCAL_SRC in \
        "$BASE/protocolos/btun/btun-server-${ARCH_TAG}" \
        "$BASE/protocolos/btun/btun-server" \
        "$(dirname "$(readlink -f "$0")")/btun-server-${ARCH_TAG}" \
        "$(dirname "$(readlink -f "$0")")/btun-server"
    do

        [[ -f "$LOCAL_SRC" ]] || continue

        echo -e " ${CYAN}➜${RESET} Encontrado: ${GRAY}$LOCAL_SRC${RESET}"

        if cp -f "$LOCAL_SRC" "$BIN" &&
           chmod +x "$BIN"; then

            if "$BIN" -version >/dev/null 2>&1 ||
               "$BIN" --version >/dev/null 2>&1; then

                echo -e " ${GREEN}✔${RESET} Binario BTUN instalado"
                return 0
            fi
        fi

        rm -f "$BIN"
    done

    echo ""
    echo -e "${RED}❌ No se encontró el binario btun-server.${RESET}"
    echo ""
    echo -e "${GRAY}Debe estar en:${RESET}"
    echo -e " ${CYAN}$BASE/protocolos/btun/btun-server${RESET}"
    echo ""
    echo -e "${GRAY}o:${RESET}"
    echo -e " ${CYAN}$BASE/protocolos/btun/btun-server-${ARCH_TAG}${RESET}"

    return 1
}

#==================================================
# CREAR USUARIO POR DEFECTO
#==================================================

gen_users() {

    mkdir -p "$DIR"

    if [[ ! -f "$AUTH_FILE" ]]; then

        local PASS

        PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 12)

        echo "kevintech:$PASS" > "$AUTH_FILE"

        chmod 600 "$AUTH_FILE"

        echo ""
        echo -e "${GREEN}✔ Credencial BTUN generada${RESET}"
        echo -e " ${WHITE}Usuario:${RESET} ${CYAN}kevintech${RESET}"
        echo -e " ${WHITE}Clave  :${RESET} ${CYAN}$PASS${RESET}"

    fi
}

#==================================================
# CREAR SERVICIO SYSTEMD
#==================================================

create_service() {

    mkdir -p /var/lib/btun

    cat > /etc/systemd/system/btun.service <<SVCEOF
[Unit]
Description=KevinTech BTUN VPN TCP UDP
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BIN -auth file -auth-file $AUTH_FILE -tcp-listen 0.0.0.0:$BTUN_PORT -udp-listen 0.0.0.0:$BTUN_PORT -subnet $SUBNET -tun btun0 -stats-file /var/lib/btun/stats.json -handshake-timeout 15s -idle-timeout 2m
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    echo -e " ${GREEN}✔${RESET} Servicio ${WHITE}btun.service${RESET} creado"
}

#==================================================
# ABRIR PUERTOS
#==================================================

open_ports() {

    echo ""
    echo -e "${CYAN}➜${RESET} Abriendo puerto ${WHITE}$BTUN_PORT${RESET}..."

    iptables -C INPUT \
        -p tcp \
        --dport "$BTUN_PORT" \
        -j ACCEPT 2>/dev/null ||
    iptables -A INPUT \
        -p tcp \
        --dport "$BTUN_PORT" \
        -j ACCEPT

    iptables -C INPUT \
        -p udp \
        --dport "$BTUN_PORT" \
        -j ACCEPT 2>/dev/null ||
    iptables -A INPUT \
        -p udp \
        --dport "$BTUN_PORT" \
        -j ACCEPT

    if command -v ufw >/dev/null 2>&1 &&
       ufw status 2>/dev/null | grep -q "Status: active"; then

        ufw allow "$BTUN_PORT/tcp" >/dev/null 2>&1
        ufw allow "$BTUN_PORT/udp" >/dev/null 2>&1
    fi

    mkdir -p /etc/iptables

    iptables-save > /etc/iptables/rules.v4 2>/dev/null

    echo -e " ${GREEN}✔${RESET} TCP/$BTUN_PORT y UDP/$BTUN_PORT abiertos"
}

#==================================================
# TEST BTUN
#==================================================

test_btun() {

    echo ""

    echo -e "${CYAN}╭─ PRUEBA DEL SERVICIO ───────────────────────╮${RESET}"

    if systemctl is-active --quiet "$SERVICE"; then

        echo -e "${CYAN}│${RESET} ${GREEN}● Servicio activo${RESET}"

        if ss -ltnp 2>/dev/null |
            grep -qE ":${BTUN_PORT}[[:space:]]"; then

            echo -e "${CYAN}│${RESET} ${GREEN}✔ TCP escuchando en $BTUN_PORT${RESET}"

        else

            echo -e "${CYAN}│${RESET} ${YELLOW}⚠ TCP no detectado por ss${RESET}"

        fi

        echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"

        return 0

    fi

    echo -e "${CYAN}│${RESET} ${RED}● Servicio detenido${RESET}"
    echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"

    return 1
}

#==================================================
# INSTALAR BTUN
#==================================================

install_btun() {

    clear

    mv_deliv_header \
        "🚀 INSTALAR BTUN" \
        "KevinTech VPN TCP / UDP"

    echo ""

    # Evitar conflicto con BadVPN
    if [[ "${BTUN_PORT_FORCED:-0}" != "1" ]] &&
       systemctl is-active --quiet badvpn-udpgw-7300 2>/dev/null &&
       [[ "$BTUN_PORT" == "7300" ]]; then

        echo -e " ${YELLOW}⚠ BadVPN está usando el puerto 7300.${RESET}"
        echo -e " ${GRAY}BTUN cambiará automáticamente a:${RESET} ${WHITE}7900${RESET}"

        BTUN_PORT="7900"

        echo ""
    fi

    install_dependencies || return 1

    install_binary || return 1

    anim_step "Configurando BTUN"

    gen_users

    create_service

    anim_step "Configurando firewall"

    open_ports

    echo ""

    anim_step "Iniciando BTUN"

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    if ! svc_restart_anim \
        "$SERVICE" \
        "Arrancando BTUN"; then

        echo ""
        echo -e "${RED}❌ BTUN no pudo iniciar.${RESET}"
        echo ""

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager

        return 1
    fi

    test_btun

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        sed -i '/^BTUN=/d' "$CONFIG"
        echo "BTUN=ON" >> "$CONFIG"

        sed -i '/^BTUN_PORT=/d' "$CONFIG"
        echo "BTUN_PORT=$BTUN_PORT" >> "$CONFIG"

        source "$CONFIG"

        local VPS_IP
        local BTUN_USER
        local BTUN_PASS

        VPS_IP=$(hostname -I | awk '{print $1}')

        BTUN_USER=$(head -n1 "$AUTH_FILE" 2>/dev/null |
            cut -d: -f1)

        BTUN_PASS=$(head -n1 "$AUTH_FILE" 2>/dev/null |
            cut -d: -f2)

        clear

        mv_deliv_header \
            "🎉 BTUN INSTALADO" \
            "KevinTech VPN Premium"

        echo ""

        mv_deliv_sec "🌐 DATOS DEL SERVIDOR"

        mv_dcard_top
        mv_dcard_row "🌍" "IP" "$VPS_IP"
        mv_dcard_row "🚀" "Puerto" "$BTUN_PORT"
        mv_dcard_row "📡" "Protocolo" "TCP + UDP"
        mv_dcard_row "🌐" "Subred" "$SUBNET"
        mv_dcard_row "🧵" "Interfaz" "btun0"
        mv_dcard_bot

        echo ""

        mv_deliv_sec "🔐 CREDENCIALES"

        mv_dcard_top
        mv_dcard_row "👤" "Usuario" "${BTUN_USER:-kevintech}"
        mv_dcard_row "🔑" "Clave" "${BTUN_PASS:-********}"
        mv_dcard_bot

        echo ""

        mv_deliv_sec "📱 CONFIGURACIÓN EN LA APP"

        echo -e " ${CYAN}➜${RESET} Modo   : ${WHITE}VPN / Túnel BTUN${RESET}"
        echo -e " ${CYAN}➜${RESET} Host   : ${WHITE}$VPS_IP${RESET}"
        echo -e " ${CYAN}➜${RESET} Puerto : ${WHITE}$BTUN_PORT${RESET}"
        echo -e " ${CYAN}➜${RESET} Red    : ${WHITE}$SUBNET${RESET}"

        echo ""

        line

        echo -e "${GREEN}✔ BTUN está listo para utilizar.${RESET}"

        echo ""

    else

        echo ""
        echo -e "${RED}❌ Error iniciando BTUN${RESET}"
        echo ""

        systemctl status "$SERVICE" --no-pager

    fi

    echo ""

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla para continuar...${RESET}")"
}

#==================================================
# ELIMINAR BTUN
#==================================================

remove_btun() {

    clear

    mv_deliv_header \
        "🗑️ DESINSTALAR BTUN" \
        "KevinTech VPN"

    echo ""

    echo -e "${YELLOW}⚠ Esta acción eliminará el servicio y el binario BTUN.${RESET}"
    echo -e "${GRAY}Las credenciales también serán eliminadas.${RESET}"

    echo ""

    read -rp \
        "$(echo -e "${RED}➜${RESET} ¿Continuar? [s/N]: ")" R

    [[ "$R" =~ ^[Ss]$ ]] || return

    echo ""

    anim_step "Desinstalando BTUN"

    anim_run \
        "Detener servicio" \
        systemctl stop "$SERVICE"

    anim_run \
        "Deshabilitar servicio" \
        systemctl disable "$SERVICE"

    anim_run \
        "Eliminar servicio" \
        rm -f /etc/systemd/system/btun.service

    anim_run \
        "Eliminar configuración" \
        rm -rf "$DIR"

    anim_run \
        "Eliminar binario" \
        rm -f "$BIN"

    anim_run \
        "Eliminar estadísticas" \
        rm -rf /var/lib/btun

    systemctl daemon-reload

    iptables -D INPUT \
        -p tcp \
        --dport "$BTUN_PORT" \
        -j ACCEPT 2>/dev/null

    iptables -D INPUT \
        -p udp \
        --dport "$BTUN_PORT" \
        -j ACCEPT 2>/dev/null

    if command -v ufw >/dev/null 2>&1 &&
       ufw status 2>/dev/null | grep -q "Status: active"; then

        ufw delete allow "$BTUN_PORT/tcp" >/dev/null 2>&1
        ufw delete allow "$BTUN_PORT/udp" >/dev/null 2>&1

    fi

    sed -i '/^BTUN=/d' "$CONFIG"
    echo "BTUN=OFF" >> "$CONFIG"

    sed -i '/^BTUN_PORT=/d' "$CONFIG"

    source "$CONFIG"

    echo ""

    echo -e "${GREEN}╭────────────────────────────────────────────╮${RESET}"
    echo -e "${GREEN}│${RESET}          ✅ BTUN DESINSTALADO             ${GREEN}│${RESET}"
    echo -e "${GREEN}╰────────────────────────────────────────────╯${RESET}"

    echo ""

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# GESTIÓN DE USUARIOS
#==================================================

manage_users() {

    while true
    do

        clear

        mv_deliv_header \
            "👤 USUARIOS BTUN" \
            "Gestión de cuentas"

        echo ""

        mv_deliv_sec "📋 USUARIOS REGISTRADOS"

        local COUNT=0

        if [[ -f "$AUTH_FILE" ]] &&
           [[ -s "$AUTH_FILE" ]]; then

            while IFS=: read -r U P; do

                [[ -z "$U" ]] && continue

                COUNT=$((COUNT + 1))

                echo -e \
                    " ${GREEN}[$COUNT]${RESET} 👤 ${WHITE}$U${RESET} ${GRAY}│${RESET} 🔑 ${CYAN}$P${RESET}"

            done < "$AUTH_FILE"

        fi

        if (( COUNT == 0 )); then
            echo -e " ${GRAY}○ No hay usuarios registrados.${RESET}"
        fi

        echo ""

        echo -e " ${GRAY}Total:${RESET} ${WHITE}$COUNT${RESET}"

        echo ""

        line

        echo -e " ${GREEN}[1]${RESET} 👤 Añadir Usuario"
        echo -e " ${RED}[2]${RESET} 🗑️ Eliminar Usuario"
        echo -e " ${GRAY}[0]${RESET} ↩️ Regresar"

        echo ""

        read -rp \
            "$(echo -e "${CYAN}╰─➤${RESET} ${WHITE}Opción:${RESET} ")" OP

        case "$OP" in

            1)

                echo ""

                read -rp \
                    "$(echo -e "${CYAN}➜${RESET} Usuario: ")" NUSER

                [[ -z "$NUSER" ]] && continue

                if [[ ! "$NUSER" =~ ^[a-zA-Z0-9._-]+$ ]]; then

                    echo ""
                    echo -e "${RED}❌ Nombre de usuario inválido.${RESET}"
                    sleep 2
                    continue

                fi

                read -rp \
                    "$(echo -e "${CYAN}➜${RESET} Clave ${GRAY}(Enter = automática)${RESET}: ")" NPASS

                if [[ -z "$NPASS" ]]; then
                    NPASS=$(openssl rand -base64 18 |
                        tr -dc 'a-zA-Z0-9' |
                        head -c 12)
                fi

                sed -i "/^${NUSER}:/d" "$AUTH_FILE" 2>/dev/null

                echo "$NUSER:$NPASS" >> "$AUTH_FILE"

                chmod 600 "$AUTH_FILE"

                if systemctl is-active --quiet "$SERVICE"; then
                    systemctl restart "$SERVICE" >/dev/null 2>&1
                fi

                echo ""

                mv_deliv_header \
                    "✅ USUARIO CREADO" \
                    "$NUSER"

                echo ""

                mv_dcard_top
                mv_dcard_row "👤" "Usuario" "$NUSER"
                mv_dcard_row "🔑" "Clave" "$NPASS"
                mv_dcard_bot

                echo ""

                read -n1 -r -p \
                    "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"

                ;;

            2)

                echo ""

                read -rp \
                    "$(echo -e "${RED}➜${RESET} Usuario a eliminar: ")" DUSER

                if [[ -n "$DUSER" ]] &&
                   grep -q "^${DUSER}:" "$AUTH_FILE" 2>/dev/null; then

                    sed -i "/^${DUSER}:/d" "$AUTH_FILE"

                    chmod 600 "$AUTH_FILE"

                    if systemctl is-active --quiet "$SERVICE"; then
                        systemctl restart "$SERVICE" >/dev/null 2>&1
                    fi

                    echo ""
                    echo -e "${GREEN}✔ Usuario eliminado: ${WHITE}$DUSER${RESET}"

                else

                    echo ""
                    echo -e "${RED}✘ El usuario no existe.${RESET}"

                fi

                sleep 2
                ;;

            0)
                return
                ;;

            *)
                echo ""
                echo -e "${RED}✘ Opción inválida.${RESET}"
                sleep 1
                ;;

        esac

    done
}

#==================================================
# REINICIAR SERVICIO
#==================================================

restart_btun() {

    clear

    mv_deliv_header \
        "🔄 REINICIAR BTUN" \
        "KevinTech VPN"

    echo ""

    if svc_restart_anim \
        "$SERVICE" \
        "Reiniciando servicio"; then

        echo ""
        echo -e "${GREEN}✔ Servicio BTUN activo.${RESET}"

        test_btun

    else

        echo ""
        echo -e "${RED}❌ Error al reiniciar BTUN.${RESET}"
        echo ""

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager

    fi

    echo ""

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla...${RESET}")"
}

#==================================================
# ESTADO BTUN
#==================================================

status_btun() {

    clear

    mv_deliv_header \
        "📊 ESTADO BTUN" \
        "KevinTech VPN TCP / UDP"

    echo ""

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e " ${GREEN}● SERVICIO ACTIVO${RESET}"
    else
        echo -e " ${RED}● SERVICIO DETENIDO${RESET}"
    fi

    echo ""

    mv_deliv_sec "⚙️ INFORMACIÓN DEL SERVICIO"

    mv_dcard_top
    mv_dcard_row "⚡" "Servicio" "btun.service"
    mv_dcard_row "🔌" "Puerto" "$BTUN_PORT TCP/UDP"
    mv_dcard_row "🌐" "Subred" "$SUBNET"
    mv_dcard_row "🧵" "Interfaz" "btun0"
    mv_dcard_bot

    echo ""

    mv_deliv_sec "📡 INTERFAZ TUN"

    if ip addr show btun0 >/dev/null 2>&1; then
        ip addr show btun0
    else
        echo -e " ${GRAY}○ Sin interfaz activa.${RESET}"
    fi

    echo ""

    mv_deliv_sec "📝 ÚLTIMOS LOGS"

    journalctl \
        -u "$SERVICE" \
        -n 8 \
        --no-pager

    echo ""

    mv_deliv_pie

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla para continuar...${RESET}")"
}

#==================================================
# DATOS DE CONEXIÓN
#==================================================

show_info() {

    clear

    local VPS_IP
    local BTUN_USER
    local BTUN_PASS

    VPS_IP=$(hostname -I | awk '{print $1}')

    BTUN_USER=$(head -n1 "$AUTH_FILE" 2>/dev/null |
        cut -d: -f1)

    BTUN_PASS=$(head -n1 "$AUTH_FILE" 2>/dev/null |
        cut -d: -f2)

    mv_deliv_header \
        "📱 DATOS DE CONEXIÓN" \
        "BTUN · KevinTech"

    echo ""

    mv_deliv_sec "🌐 CONFIGURACIÓN VPN"

    mv_dcard_top

    mv_dcard_row "🌍" "IP / HOST" "$VPS_IP"
    mv_dcard_row "🚀" "Puerto" "$BTUN_PORT"
    mv_dcard_row "📡" "Protocolo" "TCP + UDP"
    mv_dcard_row "🌐" "Subred" "$SUBNET"
    mv_dcard_row "🧵" "Interfaz" "btun0"

    mv_dcard_bot

    echo ""

    mv_deliv_sec "🔐 CREDENCIALES"

    mv_dcard_top

    mv_dcard_row \
        "👤" \
        "Usuario" \
        "${BTUN_USER:-kevintech}"

    mv_dcard_row \
        "🔑" \
        "Clave" \
        "${BTUN_PASS:-********}"

    mv_dcard_bot

    echo ""

    mv_deliv_sec "📲 CONFIGURACIÓN EN LA APP"

    echo -e \
        " ${CYAN}➜${RESET} Modo     : ${WHITE}VPN / Túnel BTUN${RESET}"

    echo -e \
        " ${CYAN}➜${RESET} Host     : ${WHITE}$VPS_IP${RESET}"

    echo -e \
        " ${CYAN}➜${RESET} Puerto   : ${WHITE}$BTUN_PORT${RESET}"

    echo -e \
        " ${CYAN}➜${RESET} Protocolo: ${WHITE}TCP + UDP${RESET}"

    echo ""

    mv_deliv_pie

    read -n1 -r -p \
        "$(echo -e "${GRAY}Presiona una tecla para continuar...${RESET}")"
}

#==================================================
# CLI HEADLESS
#==================================================

if [[ "${1:-}" == "--install" ]]; then

    if [[ -n "${2:-}" ]]; then
        export BTUN_PORT="$2"
        export BTUN_PORT_FORCED=1
    fi

    install_btun
    exit $?

fi

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true
do

    clear

    source "$CONFIG"

    #──────────────────────────────────────────────
    # ESTADO
    #──────────────────────────────────────────────

    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    elif [[ -f "/etc/systemd/system/${SERVICE}.service" ]]; then
        STATUS="${RED}🔴 DETENIDO${RESET}"
    else
        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"
    fi

    #──────────────────────────────────────────────
    # CABECERA PREMIUM
    #──────────────────────────────────────────────

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}⚡ KEVINTECH BTUN${RESET}          ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${WHITE}VPN TCP / UDP${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${GRAY}PREMIUM MANAGER${RESET}            ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    echo -e "${CYAN}║${RESET}  ${WHITE}Estado     :${RESET} $STATUS"
    echo -e "${CYAN}║${RESET}  ${WHITE}Puerto     :${RESET} ${CYAN}$BTUN_PORT${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Protocolo  :${RESET} ${CYAN}TCP + UDP${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Subred     :${RESET} ${CYAN}$SUBNET${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Interfaz   :${RESET} ${CYAN}btun0${RESET}"

    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}                ${WHITE}⚡ OPCIONES${RESET}                ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    if [[ "$BTUN" == "ON" ]]; then

        echo -e "${CYAN}║${RESET}  ${GREEN}[01]${RESET} 👤 Gestionar Usuarios                 ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}[02]${RESET} 🗑️  Desinstalar BTUN                  ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}[03]${RESET} 🔄 Reiniciar Servicio                 ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}[04]${RESET} 📊 Ver Estado                         ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}[05]${RESET} 📱 Datos de Conexión                  ${CYAN}║${RESET}"

    else

        echo -e "${CYAN}║${RESET}  ${GREEN}[01]${RESET} 🚀 Instalar BTUN                      ${CYAN}║${RESET}"

    fi

    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GRAY}[00]${RESET} ↩️  Regresar                            ${CYAN}║${RESET}"

    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    echo ""

    read -rp \
        "$(echo -e "${CYAN}╰─➤${RESET} ${WHITE}Selecciona una opción:${RESET} ")" OP

    case "$OP" in

        1)

            if [[ "$BTUN" == "ON" ]]; then
                manage_users
            else
                install_btun
            fi

            ;;

        2)

            [[ "$BTUN" == "ON" ]] &&
                remove_btun

            ;;

        3)

            [[ "$BTUN" == "ON" ]] &&
                restart_btun

            ;;

        4)

            [[ "$BTUN" == "ON" ]] &&
                status_btun

            ;;

        5)

            [[ "$BTUN" == "ON" ]] &&
                show_info

            ;;

        00|0)

            exec bash "$BASE/protocolos/menu.sh"

            ;;

        *)

            echo ""
            echo -e "${RED}✘ Opción inválida.${RESET}"
            sleep 1

            ;;

    esac

done