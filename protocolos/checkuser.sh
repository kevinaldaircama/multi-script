#!/bin/bash

#=========================================================
#        KEVINTECH CHECKUSER MANAGER
#        PREMIUM EDITION v4.1
#
# CheckUser  : TCP 10016
# WebSocket  : TCP 10015
# Online App : TCP 8888
# OS         : Ubuntu 24.04+
#=========================================================

set -o pipefail

#=========================================================
# CONFIGURACIÓN
#=========================================================

CHECKUSER_PORT="10016"
WEBSOCKET_PORT="10015"
ONLINEAPP_PORT="8888"

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

CHECKUSER_DIR="/usr/lib/checkgestor"
CHECKUSER_PY="$CHECKUSER_DIR/checkgestor.py"
CHECKUSER_SERVICE="checkuser.service"

ONLINEAPP_DIR="/var/www/html/server"
ONLINEAPP_SCRIPT="$BASE/protocolos/onlineapp"
ONLINEAPP_SERVICE="kevintech-onlineapp.service"

CHECKUSER_URL_PATH="/checkUser"
ONLINEAPP_URL_PATH="/server/online"

#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
SKY="\e[38;5;117m"
GOLD="\e[38;5;220m"

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo
    echo -e "${RED}${BOLD}✘ EJECUTA ESTE SCRIPT COMO ROOT${RESET}"
    echo
    echo -e "${CYAN}sudo -i${RESET}"
    echo

    exit 1
fi

#=========================================================
# DIRECTORIOS
#=========================================================

mkdir -p "$BASE"
mkdir -p "$CHECKUSER_DIR"

if [[ -f "$CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null || true
fi

#=========================================================
# FUNCIONES VISUALES
#=========================================================

clear_screen() {
    clear 2>/dev/null || true
}

line() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

line_color() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

header() {

    clear_screen

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${PINK}${BOLD}              🛡️ KEVINTECH CHECKUSER${RESET}                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                    PREMIUM v4.1${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${SKY}          🚀 CHECKUSER • WEBSOCKET • ONLINE APP 🚀${RESET}"
    echo
}

section() {

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${PURPLE}║${RESET} ${WHITE}${BOLD} %-58s${RESET} ${PURPLE}║${RESET}\n" "$1"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

ok() {
    echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"
}

error_msg() {
    echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"
}

warning() {
    echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

info() {
    echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"
}

loading() {

    local TEXT="$1"

    echo -ne " ${CYAN}${TEXT}${RESET} "

    for _ in 1 2 3; do
        echo -ne "${PURPLE}●${RESET}"
        sleep 0.15
    done

    echo
}

pause() {

    echo
    line_color
    echo
    read -r -p \
        "$(echo -e "${GOLD}${BOLD}➜ Presiona ENTER para continuar...${RESET}")"
}

#=========================================================
# SERVICIOS
#=========================================================

check_service() {
    systemctl is-active --quiet "$1"
}

#=========================================================
# PUERTO TCP
#=========================================================

port_tcp_in_use() {

    local PORT="$1"

    ss -H -ltn 2>/dev/null |
        awk -v P=":$PORT" '
            $4 == P || $4 ~ P"$" {
                found=1
            }
            END {
                exit !found
            }
        '
}

#=========================================================
# IP PÚBLICA
#=========================================================

get_public_ip() {

    local IP=""

    IP=$(
        curl \
            -4 \
            -fsS \
            --connect-timeout 5 \
            --max-time 10 \
            https://api.ipify.org \
            2>/dev/null
    )

    if [[ -z "$IP" ]]; then
        IP=$(
            hostname -I 2>/dev/null |
            awk '{print $1}'
        )
    fi

    echo "${IP:-127.0.0.1}"
}

#=========================================================
# INSTALAR DEPENDENCIAS
#=========================================================

install_dependencies() {

    section "📦 PREPARANDO SISTEMA"

    export DEBIAN_FRONTEND=noninteractive

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudieron actualizar los repositorios."
        return 1
    fi

    ok "Repositorios actualizados."

    info "Instalando dependencias..."

    if ! apt-get install -y \
        wget \
        curl \
        ca-certificates \
        python3 \
        python3-flask \
        apache2 \
        screen \
        figlet \
        iproute2 \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

#=========================================================
# DESCARGAR CHECKUSER
#=========================================================

download_checkuser() {

    section "📥 INSTALANDO CHECKUSER"

    mkdir -p "$CHECKUSER_DIR"

    #-----------------------------------------------------
    # CHALL
    #-----------------------------------------------------

    info "Descargando chall..."

    if ! wget \
        -q \
        -O /bin/chall \
        "https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/chall.sh"; then

        error_msg "No se pudo descargar chall."
        return 1
    fi

    if [[ ! -s /bin/chall ]]; then

        error_msg "El archivo chall está vacío."
        return 1
    fi

    chmod 755 /bin/chall

    ok "chall instalado."

    #-----------------------------------------------------
    # CHECKGESTOR
    #-----------------------------------------------------

    info "Descargando CheckGestor..."

    if ! wget \
        -q \
        -O /bin/checkgestor \
        "https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.sh"; then

        error_msg "No se pudo descargar checkgestor."
        return 1
    fi

    if [[ ! -s /bin/checkgestor ]]; then

        error_msg "El archivo checkgestor está vacío."
        return 1
    fi

    chmod 755 /bin/checkgestor

    ok "CheckGestor descargado."

    #-----------------------------------------------------
    # API PYTHON
    #-----------------------------------------------------

    info "Descargando API CheckUser..."

    if ! wget \
        -q \
        -O "$CHECKUSER_PY" \
        "https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.py"; then

        error_msg "No se pudo descargar checkgestor.py."
        return 1
    fi

    if [[ ! -s "$CHECKUSER_PY" ]]; then

        error_msg "checkgestor.py está vacío."
        return 1
    fi

    chmod 755 "$CHECKUSER_PY"

    #-----------------------------------------------------
    # COMPROBAR PYTHON
    #-----------------------------------------------------

    if ! python3 -m py_compile "$CHECKUSER_PY" \
        >/dev/null 2>&1; then

        error_msg "checkgestor.py contiene un error de Python."

        python3 -m py_compile "$CHECKUSER_PY" 2>&1

        return 1
    fi

    ok "API CheckUser instalada."

    return 0
}

#=========================================================
# CHECKGESTOR KEVINTECH
#=========================================================

create_checkgestor() {

    section "⚙️ CONFIGURANDO CHECKGESTOR"

    cat > /bin/checkgestor <<'EOF'
#!/bin/bash

USER_NAME="$1"
TYPE="$2"

LIMIT_DIR="/etc/kevintech/limits"

user_exist() {

    if id "$USER_NAME" >/dev/null 2>&1; then
        echo "$USER_NAME"
    else
        echo "Not exist"
    fi
}

get_limit() {

    local FILE="$LIMIT_DIR/$USER_NAME"

    if [[ -f "$FILE" ]]; then

        local LIMIT

        LIMIT=$(cat "$FILE" 2>/dev/null)

        if [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
            echo "$LIMIT"
        else
            echo "1"
        fi

    else

        echo "1"

    fi
}

cont_online() {

    local LIMIT
    local CONSSH

    LIMIT=$(get_limit)

    CONSSH=$(
        ps -u "$USER_NAME" -o comm= 2>/dev/null |
        grep -c '^sshd$'
    )

    if (( LIMIT > 0 && CONSSH > LIMIT )); then
        pkill -KILL -u "$USER_NAME" 2>/dev/null
    fi

    echo "$CONSSH"
}

limiter_user() {

    get_limit
}

get_expiration() {

    chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{gsub(/^ /,"",$2); print $2}'
}

check_data() {

    if ! id "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local DATAUSER

    DATAUSER=$(get_expiration)

    if [[ -z "$DATAUSER" || "$DATAUSER" == "never" ]]; then
        echo "31/12/2099"
        return
    fi

    date -d "$DATAUSER" '+%d/%m/%Y' 2>/dev/null
}

check_dias() {

    if ! id "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local DATAUSER
    local EXPIRATION
    local TODAY
    local DAYS

    DATAUSER=$(get_expiration)

    if [[ -z "$DATAUSER" || "$DATAUSER" == "never" ]]; then
        echo "9999"
        return
    fi

    EXPIRATION=$(date -d "$DATAUSER" '+%Y-%m-%d' 2>/dev/null)

    if [[ -z "$EXPIRATION" ]]; then
        echo "0"
        return
    fi

    TODAY=$(date '+%Y-%m-%d')

    DAYS=$(((
        $(date -ud "$EXPIRATION" +%s) -
        $(date -ud "$TODAY" +%s)
    ) / 86400))

    echo "$DAYS"
}

check_new_data() {

    if ! id "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local DATAUSER

    DATAUSER=$(get_expiration)

    if [[ -z "$DATAUSER" || "$DATAUSER" == "never" ]]; then
        echo "20991231"
        return
    fi

    date -d "$DATAUSER" '+%Y%m%d' 2>/dev/null
}

datacheck_new() {

    if ! id "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local DATAUSER

    DATAUSER=$(get_expiration)

    if [[ -z "$DATAUSER" || "$DATAUSER" == "never" ]]; then
        echo "31122099"
        return
    fi

    date -d "$DATAUSER" '+%d%m%Y' 2>/dev/null
}

case "$TYPE" in

    1)
        user_exist
        ;;

    2)
        cont_online
        ;;

    3)
        limiter_user
        ;;

    4)
        check_data
        ;;

    5)
        check_dias
        ;;

    6)
        check_new_data
        ;;

    7)
        datacheck_new
        ;;

    *)
        echo "Not exist"
        ;;

esac
EOF

    chmod 755 /bin/checkgestor

    mkdir -p /etc/kevintech/limits

    ok "CheckGestor KevinTech configurado."

    return 0
}

#=========================================================
# SERVICIO CHECKUSER
#=========================================================

create_checkuser_service() {

    section "🌐 CONFIGURANDO CHECKUSER API"

    if port_tcp_in_use "$CHECKUSER_PORT"; then

        if ! check_service "$CHECKUSER_SERVICE"; then

            warning "TCP $CHECKUSER_PORT ya está ocupado."

            ss -lntp 2>/dev/null |
                grep ":$CHECKUSER_PORT" || true

            return 1
        fi
    fi

    cat > "/etc/systemd/system/$CHECKUSER_SERVICE" <<EOF
[Unit]
Description=KevinTech CheckUser API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$CHECKUSER_DIR

ExecStart=/usr/bin/python3 $CHECKUSER_PY $CHECKUSER_PORT

Restart=always
RestartSec=3

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable "$CHECKUSER_SERVICE" \
        >/dev/null 2>&1

    info "Iniciando CheckUser..."

    systemctl restart "$CHECKUSER_SERVICE"

    sleep 2

    if check_service "$CHECKUSER_SERVICE"; then

        ok "CheckUser activo en TCP $CHECKUSER_PORT."

        return 0
    fi

    error_msg "CheckUser no pudo iniciar."

    echo

    journalctl \
        -u "$CHECKUSER_SERVICE" \
        -n 25 \
        --no-pager \
        2>/dev/null

    return 1
}

#=========================================================
# CONFIGURAR APACHE
#=========================================================

configure_apache() {

    info "Configurando Apache en puerto $ONLINEAPP_PORT..."

    # Eliminar Listen 80/8888 existentes
    sed -i \
        -E '/^[[:space:]]*Listen[[:space:]]+(80|8888)[[:space:]]*$/d' \
        /etc/apache2/ports.conf

    # Agregar únicamente nuestro puerto
    echo "Listen $ONLINEAPP_PORT" \
        >> /etc/apache2/ports.conf

    # Eliminar VirtualHost antiguo de este proyecto
    rm -f \
        /etc/apache2/sites-enabled/kevintech-onlineapp.conf

    cat > /etc/apache2/sites-available/kevintech-onlineapp.conf <<EOF
<VirtualHost *:${ONLINEAPP_PORT}>

    ServerName localhost

    DocumentRoot ${ONLINEAPP_DIR}

    <Directory ${ONLINEAPP_DIR}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/kevintech-onlineapp-error.log
    CustomLog \${APACHE_LOG_DIR}/kevintech-onlineapp-access.log combined

</VirtualHost>
EOF

    a2dissite 000-default.conf \
        >/dev/null 2>&1 || true

    a2ensite kevintech-onlineapp.conf \
        >/dev/null 2>&1

    if ! apache2ctl configtest \
        >/dev/null 2>&1; then

        error_msg "La configuración de Apache es inválida."

        apache2ctl configtest

        return 1
    fi

    systemctl enable apache2 \
        >/dev/null 2>&1

    systemctl restart apache2

    sleep 2

    if ! systemctl is-active --quiet apache2; then

        error_msg "Apache no pudo iniciar."

        journalctl \
            -u apache2 \
            -n 20 \
            --no-pager \
            2>/dev/null

        return 1
    fi

    ok "Apache activo en TCP $ONLINEAPP_PORT."

    return 0
}

#=========================================================
# ONLINE APP
#=========================================================

create_onlineapp_service() {

    section "🌐 CONFIGURANDO ONLINE APP"

    if [[ ! -f "$ONLINEAPP_SCRIPT" ]]; then

        warning "No existe:"
        echo -e " ${GRAY}$ONLINEAPP_SCRIPT${RESET}"

        warning "Online App será omitido."

        return 0
    fi

    mkdir -p "$ONLINEAPP_DIR"

    chmod +x "$ONLINEAPP_SCRIPT"

    configure_apache || return 1

    cat > "/etc/systemd/system/$ONLINEAPP_SERVICE" <<EOF
[Unit]
Description=KevinTech Online App
After=network-online.target apache2.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BASE/protocolos

ExecStart=$ONLINEAPP_SCRIPT

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable "$ONLINEAPP_SERVICE" \
        >/dev/null 2>&1

    info "Iniciando Online App..."

    systemctl restart "$ONLINEAPP_SERVICE"

    sleep 2

    if check_service "$ONLINEAPP_SERVICE"; then

        ok "Online App activo."

    else

        warning "Online App no quedó activo."

        journalctl \
            -u "$ONLINEAPP_SERVICE" \
            -n 15 \
            --no-pager \
            2>/dev/null

    fi

    return 0
}

#=========================================================
# LICENCIA
#=========================================================

create_license_info() {

    mkdir -p /etc/licencec

    cat > /etc/licencec/telegram <<'EOF'
By: @nandoslayer
KevinTech CheckUser
EOF

    chmod 644 /etc/licencec/telegram
}

#=========================================================
# MOSTRAR RESULTADO
#=========================================================

show_result() {

    local IP

    IP=$(get_public_ip)

    header

    section "🎉 INSTALACIÓN COMPLETADA"

    if check_service "$CHECKUSER_SERVICE"; then

        ok "CheckUser activo en TCP $CHECKUSER_PORT."

    else

        error_msg "CheckUser está detenido."

    fi

    if check_service "$ONLINEAPP_SERVICE"; then

        ok "Online App activo en TCP $ONLINEAPP_PORT."

    else

        warning "Online App no está activo."

    fi

    echo

    #=====================================================
    # CHECKUSER
    #=====================================================

    echo -e "${GREEN}${BOLD}http://${IP}:${CHECKUSER_PORT}${CHECKUSER_URL_PATH}${RESET}"

    echo

    #=====================================================
    # ONLINE APP
    #=====================================================

    if check_service "$ONLINEAPP_SERVICE"; then

        echo -e "${CYAN}http://${IP}:${ONLINEAPP_PORT}${ONLINEAPP_URL_PATH}${RESET}"

        echo

    fi

    line

    echo -e "${WHITE}${BOLD}📁 ARCHIVOS PRINCIPALES${RESET}"

    echo
    echo -e " ${GRAY}CheckUser:${RESET}     $CHECKUSER_PY"
    echo -e " ${GRAY}CheckGestor:${RESET}   /bin/checkgestor"
    echo -e " ${GRAY}Chall:${RESET}         /bin/chall"
    echo -e " ${GRAY}Configuración:${RESET} $CONFIG"

    echo

    echo -e "${GREEN}✔ KevinTech CheckUser quedó instalado.${RESET}"

    pause
}

#=========================================================
# DIAGNÓSTICO
#=========================================================

diagnostic() {

    header

    section "🔎 DIAGNÓSTICO CHECKUSER"

    if [[ -f /bin/chall ]]; then
        ok "chall encontrado."
    else
        error_msg "chall no encontrado."
    fi

    if [[ -x /bin/checkgestor ]]; then
        ok "checkgestor encontrado."
    else
        error_msg "checkgestor no encontrado."
    fi

    if [[ -f "$CHECKUSER_PY" ]]; then
        ok "API CheckUser encontrada."
    else
        error_msg "API CheckUser no encontrada."
    fi

    if [[ -f "/etc/systemd/system/$CHECKUSER_SERVICE" ]]; then
        ok "Servicio CheckUser encontrado."
    else
        error_msg "Servicio CheckUser no encontrado."
    fi

    echo

    if check_service "$CHECKUSER_SERVICE"; then
        ok "CheckUser está ACTIVO."
    else
        error_msg "CheckUser está DETENIDO."
    fi

    if check_service "$ONLINEAPP_SERVICE"; then
        ok "Online App está ACTIVO."
    else
        warning "Online App está DETENIDO."
    fi

    echo

    section "🔌 PUERTOS"

    for PORT in \
        "$CHECKUSER_PORT" \
        "$WEBSOCKET_PORT" \
        "$ONLINEAPP_PORT"
    do

        if ss -lnt 2>/dev/null |
            awk '{print $4}' |
            grep -Eq "(^|:)${PORT}$"; then

            ok "TCP $PORT está escuchando."

        else

            warning "TCP $PORT no está escuchando."

        fi

    done

    echo

    section "📜 LOGS CHECKUSER"

    journalctl \
        -u "$CHECKUSER_SERVICE" \
        -n 20 \
        --no-pager \
        2>/dev/null

    pause
}

#=========================================================
# ESTADO
#=========================================================

status_checkuser() {

    header

    section "📊 ESTADO DEL SERVIDOR"

    if check_service "$CHECKUSER_SERVICE"; then
        ok "CheckUser : ACTIVO"
    else
        error_msg "CheckUser : DETENIDO"
    fi

    if check_service "$ONLINEAPP_SERVICE"; then
        ok "Online App : ACTIVO"
    else
        warning "Online App : DETENIDO"
    fi

    echo

    echo -e "${WHITE}Puertos TCP:${RESET}"

    for PORT in \
        "$CHECKUSER_PORT" \
        "$WEBSOCKET_PORT" \
        "$ONLINEAPP_PORT"
    do

        if ss -lnt 2>/dev/null |
            awk '{print $4}' |
            grep -Eq "(^|:)${PORT}$"; then

            echo -e \
                " ${GREEN}●${RESET} TCP $PORT ${GREEN}ACTIVO${RESET}"

        else

            echo -e \
                " ${RED}●${RESET} TCP $PORT ${RED}CERRADO${RESET}"

        fi

    done

    echo

    local IP
    IP=$(get_public_ip)

    echo -e "${WHITE}CheckUser:${RESET}"
    echo -e "${GREEN}http://${IP}:${CHECKUSER_PORT}${CHECKUSER_URL_PATH}${RESET}"

    pause
}

#=========================================================
# REINICIAR CHECKUSER
#=========================================================

restart_checkuser() {

    header

    section "♻️ REINICIANDO CHECKUSER"

    systemctl restart "$CHECKUSER_SERVICE"

    sleep 2

    if check_service "$CHECKUSER_SERVICE"; then

        ok "CheckUser reiniciado correctamente."

    else

        error_msg "CheckUser no pudo reiniciarse."

        journalctl \
            -u "$CHECKUSER_SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

    fi

    pause
}

#=========================================================
# INFORMACIÓN VPS
#=========================================================

system_info() {

    header

    section "🖥️ INFORMACIÓN VPS"

    local IP
    IP=$(get_public_ip)

    echo -e "${WHITE}Hostname:${RESET} $(hostname)"

    echo -e "${WHITE}Sistema:${RESET} $(
        grep '^PRETTY_NAME=' \
            /etc/os-release |
        cut -d= -f2 |
        tr -d '"'
    )"

    echo -e "${WHITE}Kernel:${RESET} $(uname -r)"

    echo -e "${WHITE}CPU:${RESET} $(nproc) cores"

    echo -e "${WHITE}RAM:${RESET} $(
        free -h |
        awk '/Mem:/ {print $3" / "$2}'
    )"

    echo -e "${WHITE}Disco:${RESET} $(
        df -h / |
        awk 'NR==2 {print $5}'
    )"

    echo -e "${WHITE}Uptime:${RESET} $(uptime -p)"

    echo -e "${WHITE}IPv4:${RESET} $IP"

    pause
}

#=========================================================
# DESINSTALAR
#=========================================================

uninstall_checkuser() {

    header

    section "🗑️ DESINSTALAR CHECKUSER"

    warning "Se eliminará la instalación de CheckUser."

    echo

    read -r -p \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        pause

        return
    fi

    info "Deteniendo servicios..."

    systemctl stop "$CHECKUSER_SERVICE" \
        >/dev/null 2>&1 || true

    systemctl disable "$CHECKUSER_SERVICE" \
        >/dev/null 2>&1 || true

    systemctl stop "$ONLINEAPP_SERVICE" \
        >/dev/null 2>&1 || true

    systemctl disable "$ONLINEAPP_SERVICE" \
        >/dev/null 2>&1 || true

    info "Eliminando servicios..."

    rm -f \
        "/etc/systemd/system/$CHECKUSER_SERVICE" \
        "/etc/systemd/system/$ONLINEAPP_SERVICE"

    systemctl daemon-reload

    info "Eliminando archivos..."

    rm -f \
        /bin/chall \
        /bin/checkgestor

    rm -rf "$CHECKUSER_DIR"

    rm -f \
        /etc/apache2/sites-enabled/kevintech-onlineapp.conf \
        /etc/apache2/sites-available/kevintech-onlineapp.conf

    # Restaurar Apache Listen 80 si no existe
    if ! grep -qE '^[[:space:]]*Listen[[:space:]]+80[[:space:]]*$' \
        /etc/apache2/ports.conf 2>/dev/null; then

        echo "Listen 80" >> /etc/apache2/ports.conf
    fi

    systemctl restart apache2 \
        >/dev/null 2>&1 || true

    systemctl reset-failed "$CHECKUSER_SERVICE" \
        >/dev/null 2>&1 || true

    systemctl reset-failed "$ONLINEAPP_SERVICE" \
        >/dev/null 2>&1 || true

    ok "CheckUser eliminado correctamente."

    pause
}

#=========================================================
# INSTALACIÓN
#=========================================================

install() {

    header

    section "🚀 INSTALACIÓN CHECKUSER"

    echo -e "${WHITE}Componentes:${RESET}"
    echo
    echo -e " ${GREEN}01${RESET} 🛡️ CheckUser API  → TCP $CHECKUSER_PORT"
    echo -e " ${GREEN}02${RESET} 🔌 WebSocket SSH  → TCP $WEBSOCKET_PORT"
    echo -e " ${GREEN}03${RESET} 🌐 Online App      → TCP $ONLINEAPP_PORT"

    echo

    line

    #-----------------------------------------------------
    # ZONA HORARIA
    #-----------------------------------------------------

    info "Configurando zona horaria..."

    timedatectl set-timezone America/Lima \
        >/dev/null 2>&1 || true

    ok "Zona horaria: America/Lima"

    #-----------------------------------------------------
    # DEPENDENCIAS
    #-----------------------------------------------------

    install_dependencies || {

        error_msg "La instalación fue detenida."

        pause

        return 1
    }

    #-----------------------------------------------------
    # CHECKUSER
    #-----------------------------------------------------

    download_checkuser || {

        error_msg "No se pudo instalar CheckUser."

        pause

        return 1
    }

    create_checkgestor || {

        error_msg "No se pudo configurar CheckGestor."

        pause

        return 1
    }

    create_checkuser_service || {

        error_msg "CheckUser no pudo quedar activo."

        pause

        return 1
    }

    #-----------------------------------------------------
    # ONLINE APP
    #-----------------------------------------------------

    if ! create_onlineapp_service; then

        warning "Online App no pudo configurarse."

    fi

    #-----------------------------------------------------
    # LICENCIA
    #-----------------------------------------------------

    create_license_info

    #-----------------------------------------------------
    # RESULTADO
    #-----------------------------------------------------

    show_result

    return 0
}

#=========================================================
# MODO AUTOMÁTICO
#=========================================================

if [[ "$1" == "--auto" ]]; then

    install

    exit $?
fi

#=========================================================
# MENÚ PRINCIPAL
#=========================================================

while true; do

    header

    section "📊 ESTADO"

    if check_service "$CHECKUSER_SERVICE"; then

        echo -e \
            " ${GREEN}●${RESET} CheckUser ${GREEN}ACTIVO${RESET}"

    elif [[ -f "/etc/systemd/system/$CHECKUSER_SERVICE" ]]; then

        echo -e \
            " ${RED}●${RESET} CheckUser ${RED}DETENIDO${RESET}"

    else

        echo -e \
            " ${GRAY}●${RESET} CheckUser ${GRAY}NO INSTALADO${RESET}"

    fi

    if check_service "$ONLINEAPP_SERVICE"; then

        echo -e \
            " ${GREEN}●${RESET} Online App ${GREEN}ACTIVO${RESET}"

    else

        echo -e \
            " ${GRAY}●${RESET} Online App ${GRAY}DETENIDO${RESET}"

    fi

    echo

    echo -e "${WHITE}Puertos:${RESET}"

    echo -e \
        " ${CYAN}◆${RESET} CheckUser  : ${GREEN}$CHECKUSER_PORT${RESET}"

    echo -e \
        " ${CYAN}◆${RESET} WebSocket  : ${GREEN}$WEBSOCKET_PORT${RESET}"

    echo -e \
        " ${CYAN}◆${RESET} Online App : ${GREEN}$ONLINEAPP_PORT${RESET}"

    line

    echo -e "${BLUE}${BOLD}🛡️ CHECKUSER MANAGER${RESET}"

    echo

    echo -e \
        " ${GREEN}[01]${RESET} 🚀 Instalar / Actualizar"

    echo -e \
        " ${GREEN}[02]${RESET} ♻️  Reiniciar CheckUser"

    echo -e \
        " ${GREEN}[03]${RESET} 📊 Estado"

    echo -e \
        " ${GREEN}[04]${RESET} 🌐 Iniciar Online App"

    echo -e \
        " ${GREEN}[05]${RESET} ⛔ Detener Online App"

    echo -e \
        " ${GREEN}[06]${RESET} 🔎 Diagnóstico"

    echo -e \
        " ${GREEN}[07]${RESET} 🖥️  Información VPS"

    echo -e \
        " ${RED}[08]${RESET} 🗑️  Desinstalar"

    echo

    line

    echo -e \
        " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

    echo

    echo -e \
        "${GRAY}KevinTech Multi Script • CheckUser Manager v4.1${RESET}"

    echo

    read -r -p \
        "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
        OP

    case "$OP" in

        1)
            install
            ;;

        2)
            restart_checkuser
            ;;

        3)
            status_checkuser
            ;;

        4)

            header

            create_onlineapp_service

            pause

            ;;

        5)

            header

            systemctl stop "$ONLINEAPP_SERVICE" \
                >/dev/null 2>&1 || true

            ok "Online App detenido."

            pause

            ;;

        6)
            diagnostic
            ;;

        7)
            system_info
            ;;

        8)
            uninstall_checkuser
            ;;

        0)

            clear_screen

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