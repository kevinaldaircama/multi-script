#!/bin/bash

#==================================================
# KEVINTECH NETWORK PREMIUM
# SOCKS5 Proxy Manager
# Dante Server + usuarios Linux
#
# Puerto : TCP 1080
# Método : username/password
# Servicio: sockd
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"
USERS_FILE="$BASE/socks5-users"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

mkdir -p "$BASE"
touch "$USERS_FILE"

#==================================================
# COLORES
#==================================================

CYAN="${MV_CYN:-\e[1;96m}"
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
GOLD="\e[1;93m"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_DIM:-\e[1;90m}"
MAGENTA="\e[1;95m"
RESET="${MV_R:-\e[0m}"

#==================================================
# CONFIGURACIÓN
#==================================================

SOCKS5_PORT="${SOCKS5_PORT:-1080}"
SOCKS5_USER_PREFIX="${SOCKS5_USER_PREFIX:-kt_}"

DANTE_CONF="/etc/dante/sockd.conf"
SERVICE_FILE="/etc/systemd/system/sockd.service"

SOCKS5_BIN=""

#==================================================
# FUNCIONES VISUALES
#==================================================

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

anim_init() {
    return 0
}

anim_step() {
    echo ""
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
    local SERVICE="$1"
    local LABEL="$2"

    echo -ne "${CYAN}➜ ${LABEL}...${RESET} "

    systemctl restart "$SERVICE" >/dev/null 2>&1

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "${GREEN}OK${RESET}"
        return 0
    fi

    echo -e "${RED}ERROR${RESET}"
    return 1
}

anim_done() {
    echo -e "${GREEN}✔ $1${RESET}"
}

anim_fail() {
    echo -e "${RED}✖ $1${RESET}"
}

mv_header() {
    local TITLE="${1:-KEVINTECH}"
    local SUBTITLE="${2:-}"
    local VERSION="${3:-}"

    line

    echo -e "${WHITE}              ${TITLE}${RESET}"

    [[ -n "$SUBTITLE" ]] &&
        echo -e "${GRAY}       ${SUBTITLE}${RESET}"

    [[ -n "$VERSION" ]] &&
        echo -e "${GRAY}                 ${VERSION}${RESET}"

    line
}

mv_brand_header() {
    mv_header "$1" "kevintech SOCKS5 · Dante" "v2.0"
}

mv_deliv_header() {
    line
    echo -e "${WHITE}           🚀 DATOS SOCKS5${RESET}"
    line
}

pause_menu() {
    echo ""
    read -n1 -r -p "Presione una tecla para continuar..."
}

#==================================================
# DETECTAR DANTE
#==================================================

detect_dante() {

    SOCKS5_BIN=""

    for B in danted sockd; do

        if command -v "$B" >/dev/null 2>&1; then
            SOCKS5_BIN="$(command -v "$B")"
            break
        fi

    done

    [[ -z "$SOCKS5_BIN" && -x /usr/sbin/danted ]] &&
        SOCKS5_BIN="/usr/sbin/danted"

    [[ -z "$SOCKS5_BIN" && -x /usr/sbin/sockd ]] &&
        SOCKS5_BIN="/usr/sbin/sockd"

    if [[ -z "$SOCKS5_BIN" ]]; then
        return 1
    fi

    return 0
}

#==================================================
# ESTADO
#==================================================

STATE() {

    if systemctl is-active --quiet "$1"; then
        echo -e "${GREEN}🟢 ACTIVO${RESET}"
    else
        echo -e "${RED}🔴 DETENIDO${RESET}"
    fi
}

#==================================================
# IP DEL VPS
#==================================================

get_vps_ip() {

    local IP

    IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    if [[ -z "$IP" ]]; then
        IP=$(ip route get 1.1.1.1 2>/dev/null |
            awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    fi

    echo "${IP:-127.0.0.1}"
}

#==================================================
# INTERFAZ DE RED
#==================================================

get_interface() {

    local IFACE

    IFACE=$(ip route get 8.8.8.8 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')

    echo "${IFACE:-eth0}"
}

#==================================================
# INSTALAR DEPENDENCIAS
#==================================================

install_dependencies() {

    anim_step "Actualizando repositorios"

    if ! apt update -y >/dev/null 2>&1; then
        anim_fail "No se pudo actualizar APT"
        return 1
    fi

    anim_step "Instalando Dante Server"

    if ! apt install -y dante-server iptables iproute2 >/dev/null 2>&1; then
        anim_fail "No se pudo instalar dante-server"
        return 1
    fi

    detect_dante || {
        anim_fail "No se encontró danted/sockd"
        return 1
    }

    echo -e "${GREEN}✔ Dante: ${SOCKS5_BIN}${RESET}"

    return 0
}

#==================================================
# CREAR CONFIGURACIÓN DANTE
#==================================================

create_sockd_conf() {

    local IFACE

    IFACE=$(get_interface)

    mkdir -p /etc/dante

    cat > "$DANTE_CONF" <<EOF
#==================================================
# KEVINTECH SOCKS5
# Dante Server
#==================================================

logoutput: /var/log/sockd.log

internal: ${IFACE} port = ${SOCKS5_PORT}
external: ${IFACE}

socksmethod: username

user.privileged: root
user.unprivileged: nobody

clientmethod: none

client pass {
    from: 0.0.0.0/0
    to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0
    to: 0.0.0.0/0
    command: connect bind udpassociate
    log: connect disconnect error
}
EOF

    chmod 644 "$DANTE_CONF"

    echo -e "${GREEN}✔ Configuración creada${RESET}"
    echo -e "${GRAY}  Interfaz : ${IFACE}${RESET}"
    echo -e "${GRAY}  Puerto   : ${SOCKS5_PORT}${RESET}"
}

#==================================================
# CREAR SERVICIO SYSTEMD
#==================================================

create_service() {

    detect_dante || {
        echo -e "${RED}❌ Dante no está instalado.${RESET}"
        return 1
    }

    # Detener unidades nativas
    systemctl disable --now danted.service >/dev/null 2>&1 || true
    systemctl disable --now sockd.service >/dev/null 2>&1 || true

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KEVINTECH SOCKS5 Proxy - Dante
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/sockd.pid

ExecStart=${SOCKS5_BIN} -f ${DANTE_CONF} -p /run/sockd.pid -D

ExecReload=/bin/kill -HUP \$MAINPID

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sockd >/dev/null 2>&1

    echo -e "${GREEN}✔ Servicio systemd creado${RESET}"
}

#==================================================
# ABRIR PUERTOS
#==================================================

open_ports() {

    echo -e "${CYAN}🛡 Abriendo puerto TCP ${SOCKS5_PORT}...${RESET}"

    iptables -C INPUT \
        -p tcp \
        --dport "$SOCKS5_PORT" \
        -j ACCEPT 2>/dev/null ||
    iptables -A INPUT \
        -p tcp \
        --dport "$SOCKS5_PORT" \
        -j ACCEPT

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "${SOCKS5_PORT}/tcp" >/dev/null 2>&1
        fi

    fi

    mkdir -p /etc/iptables

    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

    echo -e "${GREEN}✔ Puerto TCP ${SOCKS5_PORT} abierto${RESET}"
}

#==================================================
# CERRAR PUERTOS
#==================================================

close_ports() {

    iptables -D INPUT \
        -p tcp \
        --dport "$SOCKS5_PORT" \
        -j ACCEPT 2>/dev/null || true

    if command -v ufw >/dev/null 2>&1; then

        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw delete allow "${SOCKS5_PORT}/tcp" >/dev/null 2>&1 || true
        fi

    fi

    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
}

#==================================================
# REGISTRO DE USUARIOS
#==================================================

register_user() {

    local USER="$1"

    grep -qxF "$USER" "$USERS_FILE" 2>/dev/null ||
        echo "$USER" >> "$USERS_FILE"
}

unregister_user() {

    local USER="$1"

    sed -i "\|^${USER}$|d" "$USERS_FILE" 2>/dev/null || true
}

#==================================================
# COMPROBAR USUARIO
#==================================================

_socks5_exists_user() {

    id "$1" >/dev/null 2>&1
}

#==================================================
# VALIDAR NOMBRE
#==================================================

valid_username() {

    [[ "$1" =~ ^[a-zA-Z0-9._-]{1,32}$ ]]
}

#==================================================
# AGREGAR USUARIO
#==================================================

add_user() {

    local USER="${1:-}"
    local PASS="${2:-}"

    clear

    mv_brand_header "👤 AGREGAR USUARIO SOCKS5"

    echo ""

    if [[ -z "$USER" ]]; then
        read -rp "👤 Usuario: " USER
    fi

    if [[ -z "$USER" ]]; then
        echo -e "${RED}❌ Usuario vacío.${RESET}"
        pause_menu
        return 1
    fi

    if ! valid_username "$USER"; then
        echo -e "${RED}❌ Nombre de usuario inválido.${RESET}"
        echo -e "${GRAY}Usa letras, números, punto, guion o guion bajo.${RESET}"
        pause_menu
        return 1
    fi

    if [[ -n "$SOCKS5_USER_PREFIX" &&
          "$USER" != "${SOCKS5_USER_PREFIX}"* ]]; then
        USER="${SOCKS5_USER_PREFIX}${USER}"
    fi

    if _socks5_exists_user "$USER"; then

        echo -e "${YELLOW}⚠️ El usuario '${USER}' ya existe.${RESET}"

        read -rp "¿Reemplazarlo? (s/n): " R

        [[ ! "$R" =~ ^[Ss]$ ]] && return 1

        userdel -f "$USER" >/dev/null 2>&1 || true
        unregister_user "$USER"
    fi

    if [[ -z "$PASS" ]]; then

        read -rsp "🔑 Contraseña: " PASS
        echo ""

        [[ -z "$PASS" ]] && {
            echo -e "${RED}❌ Contraseña vacía.${RESET}"
            pause_menu
            return 1
        }

    fi

    echo ""

    anim_step "Creando usuario"

    if ! useradd \
        -M \
        -s /usr/sbin/nologin \
        "$USER" >/dev/null 2>&1; then

        if ! useradd \
            -M \
            -s /bin/false \
            "$USER" >/dev/null 2>&1; then

            anim_fail "No se pudo crear el usuario"
            pause_menu
            return 1
        fi
    fi

    if ! echo "$USER:$PASS" | chpasswd; then

        userdel -f "$USER" >/dev/null 2>&1 || true

        anim_fail "No se pudo establecer la contraseña"
        pause_menu
        return 1
    fi

    register_user "$USER"

    local VPS_IP
    VPS_IP=$(get_vps_ip)

    echo ""

    line

    echo -e "${GREEN}        ✅ USUARIO CREADO${RESET}"

    line

    echo ""
    echo -e " 👤 Usuario : ${WHITE}${USER}${RESET}"
    echo -e " 🔑 Password : ${WHITE}${PASS}${RESET}"
    echo -e " 🌍 Servidor : ${WHITE}${VPS_IP}${RESET}"
    echo -e " 🚀 Puerto   : ${WHITE}${SOCKS5_PORT}${RESET}"
    echo -e " 🔐 Tipo     : ${WHITE}SOCKS5${RESET}"

    line

    echo ""

    pause_menu
}

#==================================================
# ELIMINAR USUARIO
#==================================================

remove_user() {

    local USER="${1:-}"

    clear

    mv_brand_header "🗑️ ELIMINAR USUARIO"

    echo ""

    if [[ -z "$USER" ]]; then
        read -rp "👤 Usuario: " USER
    fi

    if ! _socks5_exists_user "$USER"; then
        echo -e "${YELLOW}⚠️ El usuario '${USER}' no existe.${RESET}"
        pause_menu
        return 1
    fi

    if ! grep -qxF "$USER" "$USERS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ '${USER}' no pertenece al registro de SOCKS5.${RESET}"
        echo -e "${GRAY}No se eliminará para proteger otros servicios.${RESET}"
        pause_menu
        return 1
    fi

    read -rp "¿Eliminar '${USER}'? (s/n): " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return 0

    userdel -f "$USER" >/dev/null 2>&1

    unregister_user "$USER"

    echo ""
    echo -e "${GREEN}✅ Usuario '${USER}' eliminado.${RESET}"

    pause_menu
}

#==================================================
# LISTAR USUARIOS
#==================================================

list_users() {

    clear

    mv_brand_header "👥 USUARIOS SOCKS5"

    echo ""

    if [[ ! -s "$USERS_FILE" ]]; then

        echo -e "${YELLOW}⚠️ No hay usuarios SOCKS5 registrados.${RESET}"

        pause_menu
        return
    fi

    local NUM=0

    while IFS= read -r USER; do

        [[ -z "$USER" ]] && continue

        if id "$USER" >/dev/null 2>&1; then

            NUM=$((NUM + 1))

            echo -e " ${GREEN}[${NUM}]${RESET} 👤 ${WHITE}${USER}${RESET}"

        fi

    done < "$USERS_FILE"

    if [[ "$NUM" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ No hay usuarios activos.${RESET}"
    fi

    echo ""

    echo -e "${GRAY}Total: ${NUM}${RESET}"

    pause_menu
}

#==================================================
# TEST SOCKS5
#==================================================

test_socks5() {

    echo ""
    echo -e "${CYAN}🧪 Verificando SOCKS5...${RESET}"

    if systemctl is-active --quiet sockd; then

        echo -e "${GREEN}🟢 SOCKS5 está ACTIVO${RESET}"

        if ss -ltn 2>/dev/null |
            grep -q ":${SOCKS5_PORT} "; then

            echo -e "${GREEN}✔ Puerto TCP ${SOCKS5_PORT} escuchando${RESET}"

        else

            echo -e "${RED}❌ Puerto ${SOCKS5_PORT} no está escuchando${RESET}"
            return 1
        fi

        return 0
    fi

    echo -e "${RED}🔴 SOCKS5 está DETENIDO${RESET}"

    echo ""
    echo -e "${YELLOW}Últimos registros:${RESET}"

    journalctl -u sockd \
        -n 15 \
        --no-pager 2>/dev/null |
        tail -10

    return 1
}

#==================================================
# INSTALAR SOCKS5
#==================================================

install_socks5() {

    clear

    mv_brand_header "🐋 INSTALAR SOCKS5"

    echo ""

    if ! install_dependencies; then
        pause_menu
        return 1
    fi

    create_sockd_conf || {
        pause_menu
        return 1
    }

    create_service || {
        pause_menu
        return 1
    }

    open_ports

    echo ""

    svc_restart_anim \
        "sockd" \
        "Iniciando SOCKS5"

    if systemctl is-active --quiet sockd; then

        sed -i '/^SOCKS5=/d' "$CONFIG"
        echo "SOCKS5=ON" >> "$CONFIG"

        source "$CONFIG"

        local VPS_IP
        VPS_IP=$(get_vps_ip)

        echo ""

        mv_deliv_header

        echo ""
        echo -e " 🌍 Servidor : ${WHITE}${VPS_IP}${RESET}"
        echo -e " 🚀 Puerto   : ${WHITE}${SOCKS5_PORT}${RESET}"
        echo -e " 🔐 Método   : ${WHITE}Usuario + contraseña${RESET}"
        echo -e " ⚡ Protocolo: ${WHITE}SOCKS5${RESET}"
        echo ""

        echo -e "${GREEN}✅ SOCKS5 INSTALADO CORRECTAMENTE${RESET}"

        line

        echo ""
        echo -e "${GRAY}Crea usuarios desde:${RESET}"
        echo -e "${CYAN}Protocolos → SOCKS5 → Agregar Usuario${RESET}"

    else

        echo ""
        echo -e "${RED}❌ Error iniciando SOCKS5${RESET}"

        echo ""
        journalctl -u sockd \
            -n 20 \
            --no-pager 2>/dev/null

    fi

    pause_menu
}

#==================================================
# DESINSTALAR SOCKS5
#==================================================

remove_socks5() {

    clear

    mv_brand_header "🗑️ DESINSTALAR SOCKS5"

    echo ""

    read -rp "¿Eliminar SOCKS5 completamente? (s/n): " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    echo ""

    anim_step "Deteniendo servicio"

    systemctl stop sockd >/dev/null 2>&1 || true
    systemctl disable sockd >/dev/null 2>&1 || true

    anim_step "Eliminando servicio"

    rm -f "$SERVICE_FILE"

    systemctl daemon-reload

    anim_step "Cerrando puerto"

    close_ports

    anim_step "Eliminando usuarios SOCKS5"

    if [[ -f "$USERS_FILE" ]]; then

        while IFS= read -r USER; do

            [[ -z "$USER" ]] && continue

            if id "$USER" >/dev/null 2>&1; then
                userdel -f "$USER" >/dev/null 2>&1 || true
            fi

        done < "$USERS_FILE"

    fi

    rm -f "$USERS_FILE"

    anim_step "Eliminando configuración"

    rm -rf /etc/dante

    sed -i '/^SOCKS5=/d' "$CONFIG"
    echo "SOCKS5=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo -e "${GREEN}✅ SOCKS5 eliminado correctamente.${RESET}"

    pause_menu
}

#==================================================
# REINICIAR
#==================================================

restart_socks5() {

    clear

    mv_brand_header "🔄 REINICIAR SOCKS5"

    echo ""

    if ! systemctl list-unit-files |
        grep -q "^sockd.service"; then

        echo -e "${RED}❌ SOCKS5 no está instalado.${RESET}"
        pause_menu
        return
    fi

    svc_restart_anim \
        "sockd" \
        "Reiniciando Dante"

    echo ""

    test_socks5

    pause_menu
}

#==================================================
# ESTADO
#==================================================

status_socks5() {

    clear

    mv_brand_header "📊 ESTADO SOCKS5"

    echo ""

    echo -e " Estado  : $(STATE sockd)"
    echo -e " Puerto  : ${WHITE}TCP ${SOCKS5_PORT}${RESET}"
    echo -e " Binario : ${WHITE}${SOCKS5_BIN:-No detectado}${RESET}"

    echo ""

    echo -e "${CYAN}Puertos escuchando:${RESET}"

    ss -ltnp 2>/dev/null |
        grep ":${SOCKS5_PORT} " ||
        echo -e "${RED}❌ No está escuchando${RESET}"

    echo ""

    echo -e "${CYAN}Usuarios registrados:${RESET}"

    if [[ -s "$USERS_FILE" ]]; then

        while IFS= read -r USER; do

            [[ -z "$USER" ]] && continue

            if id "$USER" >/dev/null 2>&1; then
                echo -e " ${GREEN}●${RESET} $USER"
            fi

        done < "$USERS_FILE"

    else

        echo -e "${GRAY}Ninguno${RESET}"

    fi

    pause_menu
}

#==================================================
# DATOS DE CONEXIÓN
#==================================================

show_info() {

    clear

    mv_brand_header "📱 DATOS DE CONEXIÓN"

    local VPS_IP
    VPS_IP=$(get_vps_ip)

    echo ""

    echo -e "${WHITE}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${WHITE}║              SOCKS5 KEVINTECH               ║${RESET}"
    echo -e "${WHITE}╚══════════════════════════════════════════════╝${RESET}"

    echo ""

    echo -e " 🌍 Host/IP : ${GREEN}${VPS_IP}${RESET}"
    echo -e " 🚀 Puerto  : ${GREEN}${SOCKS5_PORT}${RESET}"
    echo -e " 🔐 Tipo    : ${GREEN}SOCKS5${RESET}"
    echo -e " 👤 Auth    : ${GREEN}Usuario + contraseña${RESET}"

    echo ""

    echo -e "${CYAN}Configuración:${RESET}"

    echo -e " ${WHITE}Host:${RESET} ${VPS_IP}"
    echo -e " ${WHITE}Port:${RESET} ${SOCKS5_PORT}"
    echo -e " ${WHITE}Type:${RESET} SOCKS5"
    echo -e " ${WHITE}Username:${RESET} usuario creado"
    echo -e " ${WHITE}Password:${RESET} contraseña del usuario"

    echo ""

    echo -e "${YELLOW}⚠️ IMPORTANTE${RESET}"
    echo -e "${GRAY}SOCKS5 no cifra por sí mismo el tráfico.${RESET}"
    echo -e "${GRAY}Para cifrado utiliza Shadowsocks, OpenVPN, Xray, etc.${RESET}"

    echo ""

    pause_menu
}

#==================================================
# CAMBIAR PUERTO
#==================================================

change_port() {

    clear

    mv_brand_header "⚙️ CAMBIAR PUERTO"

    echo ""

    echo -e "Puerto actual: ${GREEN}${SOCKS5_PORT}${RESET}"

    echo ""

    read -rp "Nuevo puerto: " NEW_PORT

    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ Puerto inválido.${RESET}"
        pause_menu
        return 1
    fi

    if (( NEW_PORT < 1 || NEW_PORT > 65535 )); then
        echo -e "${RED}❌ Puerto fuera de rango.${RESET}"
        pause_menu
        return 1
    fi

    if [[ "$NEW_PORT" == "$SOCKS5_PORT" ]]; then
        echo -e "${YELLOW}⚠️ El puerto ya es ${NEW_PORT}.${RESET}"
        pause_menu
        return 0
    fi

    local OLD_PORT="$SOCKS5_PORT"

    SOCKS5_PORT="$NEW_PORT"

    sed -i '/^SOCKS5_PORT=/d' "$CONFIG"
    echo "SOCKS5_PORT=$NEW_PORT" >> "$CONFIG"

    source "$CONFIG"

    create_sockd_conf
    create_service

    # Cerrar puerto antiguo
    iptables -D INPUT \
        -p tcp \
        --dport "$OLD_PORT" \
        -j ACCEPT 2>/dev/null || true

    if command -v ufw >/dev/null 2>&1 &&
       ufw status 2>/dev/null | grep -q "Status: active"; then

        ufw delete allow "${OLD_PORT}/tcp" >/dev/null 2>&1 || true

    fi

    open_ports

    svc_restart_anim \
        "sockd" \
        "Aplicando nuevo puerto"

    echo ""
    echo -e "${GREEN}✅ Puerto cambiado a ${NEW_PORT}.${RESET}"

    pause_menu
}

#==================================================
# CLI HEADLESS
#==================================================

case "${1:-}" in

    --install)

        if [[ -n "${2:-}" ]]; then
            SOCKS5_PORT="$2"
        fi

        if [[ -n "${3:-}" ]]; then
            DEFAULT_USER="$3"
            DEFAULT_PASS="${4:-}"
        fi

        install_dependencies || exit 1
        create_sockd_conf || exit 1
        create_service || exit 1
        open_ports

        systemctl restart sockd

        if systemctl is-active --quiet sockd; then

            sed -i '/^SOCKS5=/d' "$CONFIG"
            echo "SOCKS5=ON" >> "$CONFIG"

            if [[ -n "${DEFAULT_USER:-}" &&
                  -n "${DEFAULT_PASS:-}" ]]; then

                add_user \
                    "$DEFAULT_USER" \
                    "$DEFAULT_PASS"

            fi

            exit 0
        fi

        exit 1
        ;;

    --add-user)

        add_user "$2" "$3"
        exit $?
        ;;

    --remove-user)

        remove_user "$2"
        exit $?
        ;;

    --list)

        list_users
        exit $?
        ;;

    --status)

        test_socks5
        exit $?
        ;;

esac

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    clear

    source "$CONFIG"

    detect_dante >/dev/null 2>&1 || true

    if systemctl is-active --quiet sockd; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    mv_brand_header "🐋 KEVINTECH SOCKS5"

    echo ""

    echo -e " Estado : $STATUS"
    echo -e " Puerto : ${WHITE}TCP ${SOCKS5_PORT}${RESET}"

    echo ""

    if [[ "$SOCKS5" == "ON" ]]; then

        echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║              MENÚ SOCKS5                    ║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

        echo -e "${WHITE}║${RESET} [01] 👤 Agregar Usuario                     ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [02] 🗑️ Eliminar Usuario                    ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [03] 👥 Listar Usuarios                     ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [04] 🔄 Reiniciar Servicio                  ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [05] 📊 Ver Estado                          ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [06] 📱 Datos de Conexión                   ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [07] ⚙️ Cambiar Puerto                      ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [08] 🗑️ Desinstalar SOCKS5                  ${WHITE}║${RESET}"

        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${WHITE}║${RESET} [00] ↩️ Regresar                             ${WHITE}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    else

        echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║             SOCKS5 NO INSTALADO             ║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${WHITE}║${RESET} [01] 🚀 Instalar SOCKS5                     ${WHITE}║${RESET}"
        echo -e "${WHITE}║${RESET} [00] ↩️ Regresar                             ${WHITE}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    fi

    echo ""

    read -rp "➜ Seleccione una opción: " OP

    case "$OP" in

        1)

            if [[ "$SOCKS5" == "ON" ]]; then
                add_user
            else
                install_socks5
            fi
            ;;

        2)

            [[ "$SOCKS5" == "ON" ]] &&
                remove_user
            ;;

        3)

            [[ "$SOCKS5" == "ON" ]] &&
                list_users
            ;;

        4)

            [[ "$SOCKS5" == "ON" ]] &&
                restart_socks5
            ;;

        5)

            [[ "$SOCKS5" == "ON" ]] &&
                status_socks5
            ;;

        6)

            [[ "$SOCKS5" == "ON" ]] &&
                show_info
            ;;

        7)

            [[ "$SOCKS5" == "ON" ]] &&
                change_port
            ;;

        8)

            [[ "$SOCKS5" == "ON" ]] &&
                remove_socks5
            ;;

        0)

            exec bash "$BASE/protocolos/menu.sh"
            ;;

        *)

            echo ""
            echo -e "${RED}❌ Opción inválida.${RESET}"
            sleep 2
            ;;

    esac

done