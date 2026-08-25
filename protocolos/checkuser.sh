#!/bin/bash
#=========================================================
#                 🛡️ KEVINTECH
#              CHECKUSER INSTALLER
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

#=========================================================
# COLORES
#=========================================================

RESET='\e[0m'
BOLD='\e[1m'
DIM='\e[2m'

BLACK='\e[1;30m'
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

[[ -f "$CONFIG" ]] && source "$CONFIG"

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
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                 CHECKUSER INSTALLER          ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}CheckUser:${RESET} ${GREEN}${CHECKUSER_PORT}${RESET}  ${GRAY}WebSocket:${RESET} ${GREEN}${WEBSOCKET_PORT}${RESET}  ${GRAY}Online:${RESET} ${GREEN}${ONLINEAPP_PORT}${RESET} ${CYAN}║${RESET}"
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
# BARRA DE PROGRESO
#=========================================================

fun_bar() {

    local CMD1="$1"
    local CMD2="$2"

    (
        rm -f "$HOME/.kevintech_install_done"

        bash -c "$CMD1" >/dev/null 2>&1

        if [[ -n "$CMD2" ]]; then
            bash -c "$CMD2" >/dev/null 2>&1
        fi

        touch "$HOME/.kevintech_install_done"

    ) >/dev/null 2>&1 &

    local PID=$!
    local WIDTH=30
    local FILLED
    local EMPTY
    local PERCENT

    tput civis 2>/dev/null || true

    while kill -0 "$PID" 2>/dev/null; do

        for PERCENT in 10 20 30 40 50 60 70 80 90; do

            if [[ -f "$HOME/.kevintech_install_done" ]]; then
                break
            fi

            FILLED=$((WIDTH * PERCENT / 100))
            EMPTY=$((WIDTH - FILLED))

            printf "\r ${CYAN}Instalando${RESET} ${GRAY}[${RESET}"

            printf "${GREEN}%${FILLED}s${RESET}" "" | tr ' ' '█'
            printf "${GRAY}%${EMPTY}s${RESET}" "" | tr ' ' '░'

            printf "${GRAY}]${RESET} ${WHITE}%3d%%${RESET}" "$PERCENT"

            sleep 0.35

        done

    done

    wait "$PID" 2>/dev/null

    rm -f "$HOME/.kevintech_install_done"

    printf "\r ${CYAN}Instalando${RESET} ${GRAY}[${RESET}"
    printf "${GREEN}%${WIDTH}s${RESET}" "" | tr ' ' '█'
    printf "${GRAY}]${RESET} ${GREEN}100%% ✔ COMPLETADO${RESET}"
    echo

    tput cnorm 2>/dev/null || true
}

#=========================================================
# VERIFICAR CHECKUSER
#=========================================================

check_installed() {

    [[ -f "/usr/lib/checkgestor/checkgestor.py" ]] &&
    [[ -f "/bin/checkgestor" ]] &&
    [[ -f "/bin/chall" ]]

}

#=========================================================
# INSTALAR CHECKUSER
#=========================================================

fun_install() {

    apt update -y >/dev/null 2>&1

    apt install -y \
        figlet \
        wget \
        curl \
        python3-flask \
        apache2 \
        screen \
        >/dev/null 2>&1

    mkdir -p /usr/lib/checkgestor

    #=====================================================
    # DESCARGAR ARCHIVOS
    #=====================================================

    wget -qO /bin/chall \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/chall.sh

    wget -qO /bin/checkgestor \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.sh

    wget -qO /usr/lib/checkgestor/checkgestor.py \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.py

    #=====================================================
    # VERIFICAR DESCARGAS
    #=====================================================

    if [[ ! -s /bin/chall ]]; then
        msg_error "No se pudo descargar chall."
        return 1
    fi

    if [[ ! -s /bin/checkgestor ]]; then
        msg_error "No se pudo descargar checkgestor."
        return 1
    fi

    if [[ ! -s /usr/lib/checkgestor/checkgestor.py ]]; then
        msg_error "No se pudo descargar checkgestor.py."
        return 1
    fi

    #=====================================================
    # PERMISOS
    #=====================================================

    chmod 755 /bin/chall
    chmod 755 /bin/checkgestor
    chmod 755 /usr/lib/checkgestor/checkgestor.py

    #=====================================================
    # CHECKGESTOR KEVINTECH
    #=====================================================

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

    chmod 755 /bin/checkgestor

    #=====================================================
    # CHECKUSER SERVICE
    #=====================================================

    cat > /etc/systemd/system/checkuser.service <<EOF
[Unit]
Description=KevinTech CheckUser API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/lib/checkgestor
ExecStart=/usr/bin/python3 /usr/lib/checkgestor/checkgestor.py ${CHECKUSER_PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    #=====================================================
    # SYSTEMD
    #=====================================================

    systemctl daemon-reload

    systemctl enable checkuser.service >/dev/null 2>&1

    systemctl restart checkuser.service

    sleep 2

    #=====================================================
    # VERIFICAR SERVICIO
    #=====================================================

    if systemctl is-active --quiet checkuser.service; then

        msg_ok "CheckUser activo en puerto ${CHECKUSER_PORT}."

    else

        msg_error "CheckUser no pudo iniciar."

        systemctl status checkuser.service --no-pager

        return 1

    fi

    #=====================================================
    # LICENCIA
    #=====================================================

    mkdir -p /etc/licencec

    echo "By: @nandoslayer" \
        > /etc/licencec/telegram

    return 0
}

#=========================================================
# OPCIÓN 04 - ONLINE APP
#=========================================================

function onapp1() {

    clear_screen

    section "🌐 INICIANDO ONLINE APP"

    msg_info "Preparando Apache..."

    apt install apache2 -y >/dev/null 2>&1

    #=====================================================
    # APACHE 8888
    #=====================================================

    if grep -qE '^Listen 80$' /etc/apache2/ports.conf; then

        sed -i \
            's/^Listen 80$/Listen 8888/' \
            /etc/apache2/ports.conf

    elif ! grep -qE '^Listen 8888$' /etc/apache2/ports.conf; then

        echo "Listen 8888" >> /etc/apache2/ports.conf

    fi

    sed -i \
        's/^Listen 80$/Listen 8888/' \
        /etc/apache2/ports.conf 2>/dev/null

    #=====================================================
    # DIRECTORIO
    #=====================================================

    rm -rf /var/www/html/server >/dev/null 2>&1

    mkdir -p /var/www/html/server >/dev/null 2>&1

    #=====================================================
    # ONLINE APP
    #=====================================================

    if [[ ! -f "$BASE/protocolos/onlineapp" ]]; then

        echo
        msg_error "No existe:"
        echo -e " ${YELLOW}$BASE/protocolos/onlineapp${RESET}"
        echo

        return 1

    fi

    chmod +x "$BASE/protocolos/onlineapp"

    #=====================================================
    # APACHE
    #=====================================================

    msg_info "Reiniciando Apache..."

    systemctl restart apache2 >/dev/null 2>&1

    #=====================================================
    # ONLINE APP
    #=====================================================

    screen -S onlineapp -X quit >/dev/null 2>&1

    screen -dmS onlineapp \
        "$BASE/protocolos/onlineapp"

    sleep 3

    #=====================================================
    # AUTOSTART
    #=====================================================

    touch /etc/autostart

    sed -i '/onlineapp/d' /etc/autostart

    echo "ps x | grep '$BASE/protocolos/onlineapp' | grep -v grep >/dev/null || screen -dmS onlineapp $BASE/protocolos/onlineapp" \
        >> /etc/autostart

    #=====================================================
    # IP
    #=====================================================

    IP=$(wget -qO- --timeout=5 ipv4.icanhazip.com)

    [[ -z "$IP" ]] && \
        IP=$(hostname -I | awk '{print $1}')

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}               ✅ ONLINE APP ACTIVO                  ${RESET}${GREEN}║${RESET}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}Puerto:${RESET} ${CYAN}${ONLINEAPP_PORT}${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}URL:${RESET} ${SKY}http://${IP}:${ONLINEAPP_PORT}/server/online${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    pause
}

function onapp2() {

    clear_screen

    section "🛑 DETENIENDO ONLINE APP"

    msg_info "Deteniendo Apache..."

    systemctl stop apache2 >/dev/null 2>&1

    screen -S onlineapp -X quit >/dev/null 2>&1

    pkill -f "$BASE/protocolos/onlineapp" >/dev/null 2>&1

    screen -wipe >/dev/null 2>&1

    [[ -f /etc/autostart ]] && \
        sed -i '/onlineapp/d' /etc/autostart

    rm -rf /var/www/html/server >/dev/null 2>&1

    sleep 2

    msg_ok "Online App detenido."

    pause
}

function onapp_ssh() {

    if pgrep -f "$BASE/protocolos/onlineapp" >/dev/null; then

        onapp2

    else

        onapp1

    fi

}

#=========================================================
# INSTALACIÓN PRINCIPAL
#=========================================================

install() {

    #=====================================================
    # ZONA HORARIA
    #=====================================================

    echo "America/Lima" > /etc/timezone

    ln -fs \
        /usr/share/zoneinfo/America/Lima \
        /etc/localtime >/dev/null 2>&1

    dpkg-reconfigure \
        --frontend noninteractive \
        tzdata >/dev/null 2>&1

    #=====================================================
    # CABECERA
    #=====================================================

    header

    section "🚀 INSTALACIÓN PRINCIPAL"

    echo -e "${WHITE}Preparando ${PINK}KevinTech CheckUser${WHITE}...${RESET}"
    echo

    echo -e " ${GRAY}Sistema:${RESET}        ${SKY}Ubuntu 24.04${RESET}"
    echo -e " ${GRAY}CheckUser:${RESET}      ${GREEN}${CHECKUSER_PORT}${RESET}"
    echo -e " ${GRAY}WebSocket SSH:${RESET}  ${GREEN}${WEBSOCKET_PORT}${RESET}"
    echo -e " ${GRAY}Online App:${RESET}     ${GREEN}${ONLINEAPP_PORT}${RESET}"

    echo

    section "📦 INSTALANDO COMPONENTES"

    fun_bar 'fun_install'

    sleep 1

    #=====================================================
    # RESULTADO
    #=====================================================

    header

    if systemctl is-active --quiet checkuser.service; then

        section "🎉 INSTALACIÓN COMPLETADA"

        echo -e " ${GREEN}●${RESET} ${WHITE}CheckUser${RESET}      ${GREEN}ACTIVO${RESET}"
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

    else

        section "❌ INSTALACIÓN CON ERRORES"

        msg_error "CheckUser no está activo."

        echo

        echo -e "${GRAY}Estado del servicio:${RESET}"
        echo

        systemctl status checkuser.service --no-pager

    fi

    echo

    line

    echo

    echo -e "${GOLD}${BOLD}              🚀 KEVINTECH MULTI SCRIPT${RESET}"
    echo -e "${GRAY}                    CHECKUSER INSTALLER${RESET}"

    echo

    line

    echo

    read -r -p \
        "$(echo -e "${YELLOW}➜ Presiona ENTER para continuar... ${RESET}")"

}

#=========================================================
# LIMPIEZA
#=========================================================

cat /dev/null > ~/.bash_history 2>/dev/null

history -c 2>/dev/null

rm -f /root/instcheck* >/dev/null 2>&1

rm -f /root/wget-log* >/dev/null 2>&1

#=========================================================
# ESTADO CHECKUSER
#=========================================================

get_checkuser_status() {

    if systemctl is-active --quiet checkuser.service; then

        echo -e "${GREEN}🟢 ACTIVO${RESET}"

    elif check_installed; then

        echo -e "${RED}🔴 DETENIDO${RESET}"

    else

        echo -e "${GRAY}⚪ NO INSTALADO${RESET}"

    fi
}

#=========================================================
# REINICIAR CHECKUSER
#=========================================================

restart_checkuser() {

    header

    section "♻️ REINICIAR CHECKUSER"

    if [[ ! -f /etc/systemd/system/checkuser.service ]]; then

        msg_error "CheckUser no está instalado."
        pause
        return
    fi

    msg_info "Reiniciando CheckUser..."

    systemctl daemon-reload >/dev/null 2>&1
    systemctl restart checkuser.service

    sleep 2

    if systemctl is-active --quiet checkuser.service; then

        msg_ok "CheckUser reiniciado correctamente."

    else

        msg_error "CheckUser no pudo iniciar."

        echo
        journalctl \
            -u checkuser.service \
            -n 20 \
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

    echo -e " ${GRAY}Servicio:${RESET}       ${CYAN}checkuser.service${RESET}"
    echo -e " ${GRAY}Estado:${RESET}         $(get_checkuser_status)"
    echo -e " ${GRAY}CheckUser:${RESET}      ${GREEN}${CHECKUSER_PORT}${RESET}"
    echo -e " ${GRAY}WebSocket:${RESET}      ${GREEN}${WEBSOCKET_PORT}${RESET}"
    echo -e " ${GRAY}Online App:${RESET}     ${GREEN}${ONLINEAPP_PORT}${RESET}"
    echo -e " ${GRAY}Directorio:${RESET}     ${WHITE}/usr/lib/checkgestor${RESET}"

    line

    echo
    echo -e "${WHITE}${BOLD}Puertos escuchando:${RESET}"
    echo

    ss -lntup 2>/dev/null |
        grep -E ":(${CHECKUSER_PORT}|${WEBSOCKET_PORT}|${ONLINEAPP_PORT})" ||
        echo -e "${GRAY}No se encontraron los puertos.${RESET}"

    line

    echo
    echo -e "${WHITE}${BOLD}Servicio:${RESET}"
    echo

    systemctl \
        --no-pager \
        --full \
        status checkuser.service \
        2>/dev/null

    pause
}

#=========================================================
# DIAGNÓSTICO
#=========================================================

diagnostic_checkuser() {

    header

    section "🔎 DIAGNÓSTICO CHECKUSER"

    echo

    if [[ -f "/usr/lib/checkgestor/checkgestor.py" ]]; then
        msg_ok "checkgestor.py encontrado"
    else
        msg_error "checkgestor.py no encontrado"
    fi

    if [[ -x "/bin/checkgestor" ]]; then
        msg_ok "/bin/checkgestor encontrado"
    else
        msg_error "/bin/checkgestor no encontrado"
    fi

    if [[ -x "/bin/chall" ]]; then
        msg_ok "/bin/chall encontrado"
    else
        msg_error "/bin/chall no encontrado"
    fi

    if [[ -f "/etc/systemd/system/checkuser.service" ]]; then
        msg_ok "Servicio systemd encontrado"
    else
        msg_error "Servicio systemd no encontrado"
    fi

    if systemctl is-active --quiet checkuser.service; then
        msg_ok "CheckUser está activo"
    else
        msg_error "CheckUser está detenido"
    fi

    echo

    line

    echo
    echo -e "${WHITE}${BOLD}Puertos:${RESET}"
    echo

    if ss -lntup 2>/dev/null | grep -q ":${CHECKUSER_PORT}"; then
        msg_ok "Puerto ${CHECKUSER_PORT} activo"
    else
        msg_error "Puerto ${CHECKUSER_PORT} no está escuchando"
    fi

    if ss -lntup 2>/dev/null | grep -q ":${ONLINEAPP_PORT}"; then
        msg_ok "Puerto ${ONLINEAPP_PORT} activo"
    else
        msg_warn "Puerto ${ONLINEAPP_PORT} no está escuchando"
    fi

    echo

    line

    echo
    echo -e "${WHITE}${BOLD}Últimos logs:${RESET}"
    echo

    journalctl \
        -u checkuser.service \
        -n 20 \
        --no-pager \
        2>/dev/null

    pause
}

#=========================================================
# INFORMACIÓN VPS
#=========================================================

system_info_checkuser() {

    header

    section "🖥️ INFORMACIÓN VPS"

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

    IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    OS=$(
        grep '^PRETTY_NAME=' /etc/os-release |
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

    echo -e " ${GRAY}Hostname:${RESET}    ${WHITE}$HOST${RESET}"
    echo -e " ${GRAY}Sistema:${RESET}     ${WHITE}$OS${RESET}"
    echo -e " ${GRAY}Kernel:${RESET}      ${WHITE}$KERNEL${RESET}"
    echo -e " ${GRAY}CPU:${RESET}         ${WHITE}${CPU:-Desconocida}${RESET}"
    echo -e " ${GRAY}Núcleos:${RESET}     ${GREEN}$CORES${RESET}"
    echo -e " ${GRAY}Memoria:${RESET}     ${WHITE}$RAM${RESET}"
    echo -e " ${GRAY}Disco:${RESET}       ${WHITE}$DISK${RESET}"
    echo -e " ${GRAY}Uptime:${RESET}      ${WHITE}$UPTIME${RESET}"
    echo -e " ${GRAY}IPv4:${RESET}        ${CYAN}${IP:-No disponible}${RESET}"

    line

    echo
    echo -e "${WHITE}${BOLD}Carga:${RESET}"
    uptime

    pause
}

#=========================================================
# DESINSTALAR CHECKUSER
#=========================================================

remove_checkuser() {

    header

    section "🗑️ DESINSTALAR CHECKUSER"

    msg_warn "Esta operación eliminará CheckUser."

    echo
    echo -e "${GRAY}Se eliminarán:${RESET}"
    echo " • Servicio CheckUser"
    echo " • checkgestor"
    echo " • chall"
    echo " • Archivos de CheckUser"
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

    systemctl stop checkuser.service \
        >/dev/null 2>&1

    systemctl disable checkuser.service \
        >/dev/null 2>&1

    msg_info "Eliminando servicio..."

    rm -f \
        /etc/systemd/system/checkuser.service

    systemctl daemon-reload

    systemctl reset-failed checkuser.service \
        >/dev/null 2>&1 || true

    msg_info "Eliminando archivos..."

    rm -f /bin/checkgestor
    rm -f /bin/chall

    rm -rf /usr/lib/checkgestor

    rm -rf /etc/licencec

    echo

    msg_ok "CheckUser eliminado correctamente."

    pause
}

#=========================================================
# MENÚ CHECKUSER
#=========================================================

checkuser_menu() {

    while true; do

        header

        local STATUS

        STATUS=$(get_checkuser_status)

        echo -e \
            " ${GRAY}Estado:${RESET}        $STATUS"

        echo -e \
            " ${GRAY}CheckUser:${RESET}     ${GREEN}${CHECKUSER_PORT}${RESET}"

        echo -e \
            " ${GRAY}WebSocket:${RESET}     ${GREEN}${WEBSOCKET_PORT}${RESET}"

        echo -e \
            " ${GRAY}Online App:${RESET}    ${GREEN}${ONLINEAPP_PORT}${RESET}"

        line

        #=================================================
        # NO INSTALADO
        #=================================================

        if ! check_installed; then

            section "🚀 INSTALACIÓN"

            echo -e \
                " ${GREEN}[01]${RESET} 🚀 Instalar CheckUser"

            echo -e \
                " ${GREEN}[02]${RESET} 🔎 Diagnóstico"

            echo -e \
                " ${GREEN}[03]${RESET} 🖥️ Información VPS"

        #=================================================
        # INSTALADO
        #=================================================

        else

            section "⚙️ ADMINISTRACIÓN"

            echo -e \
                " ${GREEN}[01]${RESET} 🔄 Reinstalar / Actualizar"

            echo -e \
                " ${GREEN}[02]${RESET} ♻️ Reiniciar CheckUser"

            echo -e \
                " ${GREEN}[03]${RESET} 📊 Estado"

            echo -e \
                " ${GREEN}[04]${RESET} 🔎 Diagnóstico"

            echo -e \
                " ${GREEN}[05]${RESET} 🌐 Online App"

            echo -e \
                " ${GREEN}[06]${RESET} 🖥️ Información VPS"

            echo -e \
                " ${RED}[07]${RESET} 🗑️ Desinstalar CheckUser"

        fi

        echo

        line

        echo -e \
            " ${RED}[00]${RESET} ↩️ Regresar al Menú de Protocolos"

        echo

        echo -e \
            "${GRAY}KevinTech Multi Script • CheckUser${RESET}"

        echo

        read -r -p \
            "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
            OP

        #=================================================
        # MENÚ NO INSTALADO
        #=================================================

        if ! check_installed; then

            case "$OP" in

                1)

                    install

                    ;;

                2)

                    diagnostic_checkuser

                    ;;

                3)

                    system_info_checkuser

                    ;;

                0)

                    clear_screen

                    if [[ -f "$BASE/protocolos/menu.sh" ]]; then

                        exec bash \
                            "$BASE/protocolos/menu.sh"

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

        #=================================================
        # MENÚ INSTALADO
        #=================================================

        else

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

                    diagnostic_checkuser

                    ;;

                5)

                    onapp_ssh

                    ;;

                6)

                    system_info_checkuser

                    ;;

                7)

                    remove_checkuser

                    ;;

                0)

                    clear_screen

                    if [[ -f "$BASE/protocolos/menu.sh" ]]; then

                        exec bash \
                            "$BASE/protocolos/menu.sh"

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

        fi

    done
}

#=========================================================
# EJECUTAR
#=========================================================

checkuser_menu