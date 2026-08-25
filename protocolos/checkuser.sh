#!/bin/bash

#=========================================================
#                 🛡️ KEVINTECH
#                CHECKUSER MANAGER
#=========================================================
# CheckUser fijo : 10016
# WebSocket SSH  : 10015
# Online App     : 8888
# Sistema        : Ubuntu 24.04
#=========================================================

CHECKUSER_PORT="10016"
WEBSOCKET_PORT="10015"
ONLINEAPP_PORT="8888"

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SERVICE="checkuser"
SERVICE_FILE="/etc/systemd/system/checkuser.service"

CHECKUSER_DIR="/usr/lib/checkgestor"
CHECKUSER_PY="$CHECKUSER_DIR/checkgestor.py"
CHECKGESTOR_BIN="/bin/checkgestor"
CHALL_BIN="/bin/chall"

ONLINEAPP="$BASE/protocolos/onlineapp"

VERSION="3.1"

#=========================================================
# COLORES
#=========================================================

RESET='\e[0m'
BOLD='\e[1m'
DIM='\e[2m'

RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
MAGENTA='\e[1;95m'
CYAN='\e[1;96m'
WHITE='\e[1;97m'
GRAY='\e[1;90m'

PINK='\e[38;5;213m'
PURPLE='\e[38;5;141m'
VIOLET='\e[38;5;177m'
SKY='\e[38;5;117m'
LIME='\e[38;5;154m'
GOLD='\e[38;5;220m'
ORANGE='\e[38;5;214m'
AQUA='\e[38;5;159m'

#=========================================================
# PREPARACIÓN
#=========================================================

mkdir -p "$BASE"

[[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este administrador requiere permisos de root.${RESET}"
    echo
    exit 1

fi

#=========================================================
# FUNCIONES VISUALES
#=========================================================

clear_screen() {

    clear 2>/dev/null || true

}

line() {

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

}

line_purple() {

    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

}

header() {

    clear_screen

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${PINK}${BOLD}                 🛡️ KEVINTECH                 ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                  CHECKUSER MANAGER            ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}CheckUser:${RESET} ${GREEN}${CHECKUSER_PORT}${RESET}  ${GRAY}WebSocket:${RESET} ${GREEN}${WEBSOCKET_PORT}${RESET}  ${GRAY}Online:${RESET} ${GREEN}${ONLINEAPP_PORT}${RESET} ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}Version:${RESET} ${WHITE}${VERSION}${RESET}          ${GRAY}Ubuntu 24.04${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

section() {

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${PURPLE}║${RESET} ${WHITE}${BOLD} %-58s ${RESET}${PURPLE}║${RESET}\n" "$1"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

msg_ok() {

    echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"

}

msg_error() {

    echo -e " ${RED}✘${RESET} ${WHITE}$1${RESET}"

}

msg_info() {

    echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"

}

msg_warn() {

    echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"

}

pause() {

    echo
    line
    echo
    read -r -p "$(echo -e "${GOLD}➜ Presiona ENTER para continuar... ${RESET}")"

}

#=========================================================
# CONFIG.CONF
#=========================================================

set_config() {

    local KEY="$1"
    local VALUE="$2"

    if grep -q "^${KEY}=" "$CONFIG" 2>/dev/null; then

        sed -i "s/^${KEY}=.*/${KEY}=${VALUE}/" "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi

}

#=========================================================
# VERIFICAR INSTALACIÓN
#=========================================================

check_installed() {

    [[ -f "$CHECKUSER_PY" ]] &&
    [[ -f "$CHECKGESTOR_BIN" ]] &&
    [[ -f "$CHALL_BIN" ]] &&
    [[ -f "$SERVICE_FILE" ]]

}

#=========================================================
# ESTADO DEL SERVICIO
#=========================================================

check_service_active() {

    systemctl is-active --quiet "$SERVICE"

}

#=========================================================
# BARRA DE PROGRESO
#=========================================================

fun_bar() {

    local CMD1="$1"
    local CMD2="$2"

    local DONE_FILE
    local STATUS_FILE
    local PID

    DONE_FILE=$(mktemp)
    STATUS_FILE=$(mktemp)

    (
        set +e

        bash -c "$CMD1" >/dev/null 2>&1
        local RESULT=$?

        if [[ -n "$CMD2" ]]; then
            bash -c "$CMD2" >/dev/null 2>&1
        fi

        echo "$RESULT" > "$STATUS_FILE"
        touch "$DONE_FILE"

    ) &

    PID=$!

    local WIDTH=30
    local START_TIME
    local ELAPSED
    local SPIN=(
        "⠋"
        "⠙"
        "⠹"
        "⠸"
        "⠼"
        "⠴"
        "⠦"
        "⠧"
        "⠇"
        "⠏"
    )

    local INDEX=0

    tput civis 2>/dev/null || true

    START_TIME=$(date +%s)

    while [[ ! -f "$DONE_FILE" ]]; do

        ELAPSED=$(( $(date +%s) - START_TIME ))

        printf "\r ${CYAN}%s${RESET} ${GRAY}[${RESET}" \
            "${SPIN[$INDEX]} Instalando"

        local FILLED=$(( (ELAPSED % (WIDTH + 1)) ))
        local EMPTY=$((WIDTH - FILLED))

        (( EMPTY < 0 )) && EMPTY=0

        printf "${GREEN}%${FILLED}s${RESET}" "" | tr ' ' '█'
        printf "${GRAY}%${EMPTY}s${RESET}" "" | tr ' ' '░'

        printf "${GRAY}]${RESET} ${WHITE}%3ds${RESET}" "$ELAPSED"

        INDEX=$(( (INDEX + 1) % ${#SPIN[@]} ))

        sleep 0.15

    done

    wait "$PID" 2>/dev/null

    local RESULT=1

    [[ -f "$STATUS_FILE" ]] &&
        RESULT=$(cat "$STATUS_FILE" 2>/dev/null)

    rm -f "$DONE_FILE" "$STATUS_FILE"

    if [[ "$RESULT" == "0" ]]; then

        printf "\r ${GREEN}✔ Instalación completada correctamente.${RESET}"
        echo

    else

        printf "\r ${RED}✘ La instalación terminó con errores.${RESET}"
        echo

    fi

    tput cnorm 2>/dev/null || true

    return "$RESULT"

}

#=========================================================
# INSTALAR CHECKUSER
#=========================================================

fun_install() {

    msg_info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then

        msg_error "No se pudo actualizar APT."
        return 1

    fi

    msg_info "Instalando dependencias..."

    if ! apt-get install -y \
        figlet \
        wget \
        curl \
        python3-flask \
        apache2 \
        screen \
        >/dev/null 2>&1; then

        msg_error "No se pudieron instalar las dependencias."
        return 1

    fi

    mkdir -p "$CHECKUSER_DIR"

    #=====================================================
    # DESCARGAR ARCHIVOS
    #=====================================================

    msg_info "Descargando CheckUser..."

    if ! wget -qO "$CHALL_BIN" \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/chall.sh; then

        msg_error "No se pudo descargar chall."
        return 1

    fi

    if ! wget -qO "$CHECKGESTOR_BIN" \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.sh; then

        msg_error "No se pudo descargar checkgestor."
        return 1

    fi

    if ! wget -qO "$CHECKUSER_PY" \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.py; then

        msg_error "No se pudo descargar checkgestor.py."
        return 1

    fi

    #=====================================================
    # VERIFICAR DESCARGAS
    #=====================================================

    [[ ! -s "$CHALL_BIN" ]] && {
        msg_error "chall está vacío."
        return 1
    }

    [[ ! -s "$CHECKGESTOR_BIN" ]] && {
        msg_error "checkgestor está vacío."
        return 1
    }

    [[ ! -s "$CHECKUSER_PY" ]] && {
        msg_error "checkgestor.py está vacío."
        return 1
    }

    chmod 755 "$CHALL_BIN"
    chmod 755 "$CHECKGESTOR_BIN"
    chmod 755 "$CHECKUSER_PY"

    #=====================================================
    # CHECKGESTOR KEVINTECH
    #=====================================================

    cat > "$CHECKGESTOR_BIN" <<'EOF'
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

check_data() {

    if ! id "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local DATAUSER

    DATAUSER=$(
        chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{gsub(/^ /,"",$2); print $2}'
    )

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

    DATAUSER=$(
        chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{gsub(/^ /,"",$2); print $2}'
    )

    if [[ -z "$DATAUSER" || "$DATAUSER" == "never" ]]; then
        echo "9999"
        return
    fi

    EXPIRATION=$(date -d "$DATAUSER" '+%Y-%m-%d' 2>/dev/null)

    [[ -z "$EXPIRATION" ]] && {
        echo "0"
        return
    }

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

    DATAUSER=$(
        chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{gsub(/^ /,"",$2); print $2}'
    )

    date -d "$DATAUSER" '+%Y%m%d' 2>/dev/null

}

datacheck_new() {

    if ! id "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local DATAUSER

    DATAUSER=$(
        chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{gsub(/^ /,"",$2); print $2}'
    )

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

    chmod 755 "$CHECKGESTOR_BIN"

    #=====================================================
    # CHECKUSER SERVICE
    #=====================================================

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech CheckUser API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$CHECKUSER_DIR
ExecStart=/usr/bin/python3 $CHECKUSER_PY $CHECKUSER_PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    #=====================================================
    # SYSTEMD
    #=====================================================

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE" >/dev/null 2>&1; then

        msg_error "No se pudo habilitar CheckUser."
        return 1

    fi

    msg_info "Iniciando CheckUser..."

    if ! systemctl restart "$SERVICE"; then

        msg_error "No se pudo reiniciar CheckUser."
        return 1

    fi

    sleep 2

    #=====================================================
    # VERIFICAR
    #=====================================================

    if check_service_active; then

        msg_ok "CheckUser activo en puerto ${CHECKUSER_PORT}."

    else

        msg_error "CheckUser no pudo iniciar."

        echo
        journalctl \
            -u "$SERVICE" \
            -n 30 \
            --no-pager \
            2>/dev/null

        return 1

    fi

    #=====================================================
    # LICENCIA
    #=====================================================

    mkdir -p /etc/licencec

    echo "By: @nandoslayer" > /etc/licencec/telegram

    #=====================================================
    # CONFIG KEVINTECH
    #=====================================================

    set_config "CHECKUSER" "ON"
    set_config "CHECKUSER_PORT" "$CHECKUSER_PORT"

    return 0

}

#=========================================================
# ONLINE APP - INICIAR
#=========================================================

onapp1() {

    clear_screen

    section "🌐 INICIANDO ONLINE APP"

    msg_info "Preparando Apache..."

    if ! apt-get install -y apache2 >/dev/null 2>&1; then

        msg_error "No se pudo instalar Apache."
        pause
        return 1

    fi

    #=====================================================
    # APACHE 8888
    #=====================================================

    if [[ -f /etc/apache2/ports.conf ]]; then

        sed -i \
            's/^Listen 80$/Listen 8888/' \
            /etc/apache2/ports.conf

        if ! grep -qE '^Listen 8888$' /etc/apache2/ports.conf; then
            echo "Listen 8888" >> /etc/apache2/ports.conf
        fi

    fi

    #=====================================================
    # DIRECTORIO
    #=====================================================

    mkdir -p /var/www/html/server

    #=====================================================
    # ONLINE APP
    #=====================================================

    if [[ ! -f "$ONLINEAPP" ]]; then

        echo
        msg_error "No existe:"
        echo -e " ${YELLOW}$ONLINEAPP${RESET}"
        echo

        pause
        return 1

    fi

    chmod +x "$ONLINEAPP"

    #=====================================================
    # CONFIGURAR APACHE
    #=====================================================

    msg_info "Reiniciando Apache..."

    if ! apache2ctl configtest >/dev/null 2>&1; then

        msg_error "La configuración de Apache contiene errores."
        apache2ctl configtest

        pause
        return 1

    fi

    systemctl enable apache2 >/dev/null 2>&1
    systemctl restart apache2

    sleep 2

    if ! systemctl is-active --quiet apache2; then

        msg_error "Apache no pudo iniciar."

        systemctl status apache2 --no-pager

        pause
        return 1

    fi

    #=====================================================
    # ONLINE APP
    #=====================================================

    screen -S onlineapp -X quit >/dev/null 2>&1

    screen -dmS onlineapp "$ONLINEAPP"

    sleep 2

    #=====================================================
    # AUTOSTART
    #=====================================================

    touch /etc/autostart

    sed -i '/onlineapp/d' /etc/autostart

    echo "pgrep -f '$ONLINEAPP' >/dev/null || screen -dmS onlineapp $ONLINEAPP" \
        >> /etc/autostart

    #=====================================================
    # IP
    #=====================================================

    local IP

    IP=$(wget -qO- --timeout=5 ipv4.icanhazip.com 2>/dev/null)

    [[ -z "$IP" ]] &&
        IP=$(hostname -I | awk '{print $1}')

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}               ✅ ONLINE APP ACTIVO                  ${RESET}${GREEN}║${RESET}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}Puerto:${RESET} ${CYAN}${ONLINEAPP_PORT}${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}URL:${RESET} ${SKY}http://${IP}:${ONLINEAPP_PORT}/server/online${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause

}

#=========================================================
# ONLINE APP - DETENER
#=========================================================

onapp2() {

    clear_screen

    section "🛑 DETENIENDO ONLINE APP"

    systemctl stop apache2 >/dev/null 2>&1

    screen -S onlineapp -X quit >/dev/null 2>&1

    pkill -f "$ONLINEAPP" >/dev/null 2>&1

    screen -wipe >/dev/null 2>&1

    [[ -f /etc/autostart ]] &&
        sed -i '/onlineapp/d' /etc/autostart

    rm -rf /var/www/html/server >/dev/null 2>&1

    sleep 2

    msg_ok "Online App detenido."

    pause

}

#=========================================================
# ONLINE APP - TOGGLE
#=========================================================

onapp_ssh() {

    if pgrep -f "$ONLINEAPP" >/dev/null 2>&1; then

        onapp2

    else

        onapp1

    fi

}

#=========================================================
# REINICIAR CHECKUSER
#=========================================================

restart_checkuser() {

    header

    section "♻️ REINICIAR CHECKUSER"

    if ! check_installed; then

        msg_error "CheckUser no está instalado."
        pause
        return 1

    fi

    msg_info "Reiniciando servicio..."

    systemctl restart "$SERVICE"

    sleep 2

    if check_service_active; then

        set_config "CHECKUSER" "ON"

        msg_ok "CheckUser reiniciado correctamente."

    else

        set_config "CHECKUSER" "OFF"

        msg_error "CheckUser no pudo iniciar."

        echo
        journalctl \
            -u "$SERVICE" \
            -n 25 \
            --no-pager \
            2>/dev/null

    fi

    pause

}

#=========================================================
# ESTADO
#=========================================================

status_checkuser() {

    header

    section "📊 ESTADO CHECKUSER"

    local STATUS

    if check_service_active; then

        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    elif check_installed; then

        STATUS="${RED}🔴 DETENIDO${RESET}"

    else

        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

    fi

    echo -e " ${WHITE}Estado:${RESET}       $STATUS"
    echo -e " ${WHITE}Servicio:${RESET}     ${CYAN}$SERVICE${RESET}"
    echo -e " ${WHITE}CheckUser:${RESET}    ${GREEN}${CHECKUSER_PORT}${RESET}"
    echo -e " ${WHITE}WebSocket:${RESET}    ${GREEN}${WEBSOCKET_PORT}${RESET}"
    echo -e " ${WHITE}Online App:${RESET}   ${GREEN}${ONLINEAPP_PORT}${RESET}"

    line

    echo -e "${WHITE}Puertos:${RESET}"

    echo

    if ss -lntup 2>/dev/null | grep -q ":${CHECKUSER_PORT}"; then

        msg_ok "Puerto ${CHECKUSER_PORT} está escuchando."

    else

        msg_warn "Puerto ${CHECKUSER_PORT} no está escuchando."

    fi

    if ss -lntup 2>/dev/null | grep -q ":${WEBSOCKET_PORT}"; then

        msg_ok "Puerto ${WEBSOCKET_PORT} está escuchando."

    else

        msg_warn "Puerto ${WEBSOCKET_PORT} no está escuchando."

    fi

    if ss -lntup 2>/dev/null | grep -q ":${ONLINEAPP_PORT}"; then

        msg_ok "Puerto ${ONLINEAPP_PORT} está escuchando."

    else

        msg_warn "Puerto ${ONLINEAPP_PORT} no está escuchando."

    fi

    line

    echo

    if check_installed; then

        systemctl \
            --no-pager \
            --full \
            status "$SERVICE" \
            2>/dev/null

    fi

    pause

}

#=========================================================
# DIAGNÓSTICO
#=========================================================

diagnostic_checkuser() {

    header

    section "🔎 DIAGNÓSTICO CHECKUSER"

    echo -e "${WHITE}Componentes:${RESET}"
    echo

    if [[ -x "$CHALL_BIN" ]]; then
        msg_ok "chall encontrado"
    else
        msg_error "chall no encontrado"
    fi

    if [[ -x "$CHECKGESTOR_BIN" ]]; then
        msg_ok "checkgestor encontrado"
    else
        msg_error "checkgestor no encontrado"
    fi

    if [[ -f "$CHECKUSER_PY" ]]; then
        msg_ok "checkgestor.py encontrado"
    else
        msg_error "checkgestor.py no encontrado"
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        msg_ok "Servicio systemd encontrado"
    else
        msg_error "Servicio systemd no encontrado"
    fi

    echo

    if check_service_active; then
        msg_ok "Servicio CheckUser activo"
    else
        msg_error "Servicio CheckUser detenido"
    fi

    line

    echo -e "${WHITE}Puerto CheckUser:${RESET} ${CYAN}${CHECKUSER_PORT}${RESET}"

    if ss -lntup 2>/dev/null | grep -q ":${CHECKUSER_PORT}"; then
        msg_ok "Puerto ${CHECKUSER_PORT} está escuchando"
    else
        msg_error "Puerto ${CHECKUSER_PORT} no está escuchando"
    fi

    line

    echo -e "${WHITE}Últimos logs:${RESET}"
    echo

    journalctl \
        -u "$SERVICE" \
        -n 20 \
        --no-pager \
        2>/dev/null

    pause

}

#=========================================================
# INFORMACIÓN VPS
#=========================================================

system_info() {

    header

    section "🖥️ INFORMACIÓN DEL VPS"

    local HOST
    local IP
    local OS
    local KERNEL
    local RAM
    local DISK
    local CPU
    local CORES
    local UPTIME

    HOST=$(hostname)

    IP=$(
        curl \
            -4 \
            -s \
            --connect-timeout 5 \
            https://api.ipify.org \
            2>/dev/null
    )

    OS=$(
        grep '^PRETTY_NAME=' \
            /etc/os-release |
        cut -d= -f2 |
        tr -d '"'
    )

    KERNEL=$(uname -r)

    RAM=$(
        free -h |
        awk '/Mem:/ {print $3" / "$2}'
    )

    DISK=$(
        df -h / |
        awk 'NR==2 {print $3" / "$2" ("$5")"}'
    )

    CPU=$(
        awk -F: '
            /model name/ {
                print $2
                exit
            }
        ' /proc/cpuinfo |
        sed 's/^ *//'
    )

    CORES=$(nproc)
    UPTIME=$(uptime -p)

    echo -e " ${WHITE}Hostname:${RESET} $HOST"
    echo -e " ${WHITE}Sistema:${RESET}  $OS"
    echo -e " ${WHITE}Kernel:${RESET}   $KERNEL"
    echo -e " ${WHITE}CPU:${RESET}      ${CPU:-Desconocida}"
    echo -e " ${WHITE}Núcleos:${RESET}  $CORES"
    echo -e " ${WHITE}RAM:${RESET}      $RAM"
    echo -e " ${WHITE}Disco:${RESET}    $DISK"
    echo -e " ${WHITE}Uptime:${RESET}   $UPTIME"
    echo -e " ${WHITE}IPv4:${RESET}     ${IP:-No disponible}"

    line

    echo -e "${WHITE}Carga:${RESET}"
    uptime

    pause

}

#=========================================================
# DESINSTALAR
#=========================================================

remove_checkuser() {

    header

    section "🗑️ DESINSTALAR CHECKUSER"

    echo -e "${YELLOW}Esta operación eliminará:${RESET}"
    echo
    echo "  • CheckUser"
    echo "  • checkgestor"
    echo "  • chall"
    echo "  • Servicio systemd"
    echo "  • Configuración de CheckUser"
    echo

    read -r -p \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        msg_warn "Operación cancelada."
        sleep 1
        return

    fi

    msg_info "Deteniendo CheckUser..."

    systemctl stop "$SERVICE" >/dev/null 2>&1
    systemctl disable "$SERVICE" >/dev/null 2>&1

    msg_info "Eliminando servicio..."

    rm -f "$SERVICE_FILE"

    systemctl daemon-reload

    systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true

    msg_info "Eliminando archivos..."

    rm -rf "$CHECKUSER_DIR"
    rm -f "$CHECKGESTOR_BIN"
    rm -f "$CHALL_BIN"

    rm -rf /etc/licencec

    set_config "CHECKUSER" "OFF"

    echo

    msg_ok "CheckUser eliminado correctamente."

    pause

}

#=========================================================
# INSTALACIÓN / REINSTALACIÓN
#=========================================================

install_checkuser() {

    header

    if check_installed; then

        section "🔄 REINSTALAR / ACTUALIZAR CHECKUSER"

        msg_warn "CheckUser ya está instalado."

        echo
        echo -e "${GRAY}Esta operación actualizará los archivos y reiniciará el servicio.${RESET}"
        echo

    else

        section "🚀 INSTALAR CHECKUSER"

    fi

    echo -e " ${GRAY}Sistema:${RESET}        ${SKY}Ubuntu 24.04${RESET}"
    echo -e " ${GRAY}CheckUser:${RESET}      ${GREEN}${CHECKUSER_PORT}${RESET}"
    echo -e " ${GRAY}WebSocket SSH:${RESET}  ${GREEN}${WEBSOCKET_PORT}${RESET}"
    echo -e " ${GRAY}Online App:${RESET}     ${GREEN}${ONLINEAPP_PORT}${RESET}"

    echo

    section "📦 INSTALANDO COMPONENTES"

    if ! fun_bar 'fun_install'; then

        echo

        msg_error "La instalación terminó con errores."

        echo

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

        pause

        return 1

    fi

    sleep 1

    header

    if check_service_active; then

        section "🎉 CHECKUSER INSTALADO"

        echo -e " ${GREEN}●${RESET} ${WHITE}CheckUser${RESET}      ${GREEN}ACTIVO${RESET}"
        echo -e " ${GREEN}●${RESET} ${WHITE}Puerto${RESET}         ${GREEN}${CHECKUSER_PORT}${RESET}"
        echo -e " ${GREEN}●${RESET} ${WHITE}WebSocket SSH${RESET}  ${GREEN}${WEBSOCKET_PORT}${RESET}"
        echo -e " ${GREEN}●${RESET} ${WHITE}Online App${RESET}     ${GREEN}${ONLINEAPP_PORT}${RESET}"

        local SERVER_IP

        SERVER_IP="$(hostname -I | awk '{print $1}')"

        echo

        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                    🌐 CHECKUSER API                    ${RESET}${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${CYAN}║${RESET} ${GRAY}URL:${RESET} ${SKY}http://${SERVER_IP}:${CHECKUSER_PORT}/checkUser${RESET}"
        echo -e "${CYAN}║${RESET} ${GRAY}Puerto:${RESET} ${GREEN}${CHECKUSER_PORT}${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

        echo

        echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                   🔌 WEBSOCKET SSH                   ${RESET}${PURPLE}║${RESET}"
        echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${PURPLE}║${RESET} ${GRAY}Puerto:${RESET} ${GREEN}${WEBSOCKET_PORT}${RESET}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"

        echo

        echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${MAGENTA}║${RESET} ${WHITE}${BOLD}                    📊 ONLINE APP                     ${RESET}${MAGENTA}║${RESET}"
        echo -e "${MAGENTA}╠══════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${MAGENTA}║${RESET} ${GRAY}Puerto:${RESET} ${GREEN}${ONLINEAPP_PORT}${RESET}"
        echo -e "${MAGENTA}║${RESET} ${GRAY}URL:${RESET} ${SKY}http://${SERVER_IP}:${ONLINEAPP_PORT}/server/online${RESET}"
        echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${RESET}"

        set_config "CHECKUSER" "ON"

    else

        set_config "CHECKUSER" "OFF"

        section "❌ INSTALACIÓN CON ERRORES"

        msg_error "CheckUser no está activo."

        echo

        systemctl status \
            "$SERVICE" \
            --no-pager

    fi

    echo

    pause

}

#=========================================================
# LIMPIEZA
#=========================================================

cleanup() {

    rm -f /root/instcheck* >/dev/null 2>&1
    rm -f /root/wget-log* >/dev/null 2>&1

}

#=========================================================
# MENÚ
#=========================================================

main_menu() {

    while true; do

        header

        #-------------------------------------------------
        # RECARGAR CONFIG
        #-------------------------------------------------

        [[ -f "$CONFIG" ]] &&
            source "$CONFIG" 2>/dev/null

        #-------------------------------------------------
        # ESTADO
        #-------------------------------------------------

        local STATUS

        if check_service_active; then

            STATUS="${GREEN}🟢 ACTIVO${RESET}"

        elif check_installed; then

            STATUS="${RED}🔴 DETENIDO${RESET}"

        else

            STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

        fi

        echo -e "${WHITE}Estado:${RESET}       $STATUS"
        echo -e "${WHITE}CheckUser:${RESET}    ${CYAN}${CHECKUSER_PORT}${RESET}"
        echo -e "${WHITE}WebSocket:${RESET}    ${CYAN}${WEBSOCKET_PORT}${RESET}"
        echo -e "${WHITE}Online App:${RESET}   ${CYAN}${ONLINEAPP_PORT}${RESET}"

        line

        #=================================================
        # INSTALADO
        #=================================================

        if check_installed; then

            echo -e "${BLUE}${BOLD}⚙️  ADMINISTRACIÓN${RESET}"
            echo

            echo -e \
                " ${GREEN}[01]${RESET} 🔄 Reinstalar / Actualizar"

            echo -e \
                " ${GREEN}[02]${RESET} ♻️  Reiniciar CheckUser"

            echo -e \
                " ${GREEN}[03]${RESET} 📊 Estado"

            echo -e \
                " ${GREEN}[04]${RESET} 🔎 Diagnóstico"

            echo -e \
                " ${GREEN}[05]${RESET} 🌐 Online App"

            echo -e \
                " ${GREEN}[06]${RESET} 🖥️  Información VPS"

            echo -e \
                " ${RED}[07]${RESET} 🗑️  Desinstalar CheckUser"

        else

            #=================================================
            # NO INSTALADO
            #=================================================

            echo -e "${BLUE}${BOLD}🚀 INSTALACIÓN${RESET}"
            echo

            echo -e \
                " ${GREEN}[01]${RESET} 🚀 Instalar CheckUser"

            echo -e \
                " ${GREEN}[02]${RESET} 🔎 Diagnóstico"

            echo -e \
                " ${GREEN}[03]${RESET} 🖥️  Información VPS"

        fi

        echo

        line_purple

        echo -e \
            " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

        echo

        echo -e \
            "${GRAY}KevinTech Multi Script • CheckUser Manager v${VERSION}${RESET}"

        echo

        read -r -p \
            "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
            OP

        case "$OP" in

            1)

                install_checkuser

                ;;

            2)

                if check_installed; then

                    restart_checkuser

                else

                    diagnostic_checkuser

                fi

                ;;

            3)

                if check_installed; then

                    status_checkuser

                else

                    system_info

                fi

                ;;

            4)

                if check_installed; then

                    diagnostic_checkuser

                else

                    system_info

                fi

                ;;

            5)

                if check_installed; then

                    onapp_ssh

                else

                    msg_error "CheckUser no está instalado."
                    sleep 1

                fi

                ;;

            6)

                if check_installed; then

                    system_info

                else

                    system_info

                fi

                ;;

            7)

                if check_installed; then

                    remove_checkuser

                else

                    msg_error "Opción inválida."
                    sleep 1

                fi

                ;;

            0)

                clear_screen

                if [[ -f "$BASE/protocolos/menu.sh" ]]; then

                    exec bash "$BASE/protocolos/menu.sh"

                else

                    exit 0

                fi

                ;;

            "")

                ;;

            *)

                msg_error "Opción inválida."
                sleep 1

                ;;

        esac

    done

}

#=========================================================
# LIMPIEZA
#=========================================================

cleanup

#=========================================================
# EJECUTAR MANAGER
#=========================================================

main_menu