#!/bin/bash
#=========================================================
# KEVINTECH CHECKUSER INSTALLER
# CheckUser fijo: 10016
# WebSocket SSH: 10015
# Online App: 8888
# Ubuntu 24.04
#=========================================================

CHECKUSER_PORT="10016"
WEBSOCKET_PORT="10015"
ONLINEAPP_PORT="8888"

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
MAGENTA='\e[1;95m'
WHITE='\e[1;97m'
RESET='\e[0m'

mkdir -p "$BASE"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#=========================================================
# FUNCIONES
#=========================================================

msg_ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

msg_error() {
    echo -e "${RED}✘ $1${RESET}"
}

msg_info() {
    echo -e "${CYAN}➜ $1${RESET}"
}

msg_warn() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"
}

#=========================================================
# BARRA
#=========================================================

fun_bar() {

    comando[0]="$1"
    comando[1]="$2"

    (
        rm -f "$HOME/fim"

        ${comando[0]} >/dev/null 2>&1

        if [[ -n "${comando[1]}" ]]; then
            ${comando[1]} >/dev/null 2>&1
        fi

        touch "$HOME/fim"

    ) >/dev/null 2>&1 &

    tput civis

    echo -ne "\033[1;33mAGUARDE \033[1;37m- \033[1;33m["

    while true; do

        for ((i=0; i<18; i++)); do
            echo -ne "\033[1;31m#"
            sleep 0.1
        done

        if [[ -e "$HOME/fim" ]]; then
            rm -f "$HOME/fim"
            break
        fi

        echo -e "\033[1;33m]"
        sleep 1

        tput cuu1
        tput dl1

        echo -ne "\033[1;33mAGUARDE \033[1;37m- \033[1;33m["

    done

    echo -e "\033[1;33m]\033[1;37m - \033[1;32mOK !\033[1;37m"

    tput cnorm
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

    #-----------------------------------------------
    # Descargar archivos originales
    #-----------------------------------------------

    wget -qO /bin/chall \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/chall.sh

    wget -qO /bin/checkgestor \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.sh

    wget -qO /usr/lib/checkgestor/checkgestor.py \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.py

    #-----------------------------------------------
    # Verificar descargas
    #-----------------------------------------------

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

    #-----------------------------------------------
    # Permisos
    #-----------------------------------------------

    chmod 755 /bin/chall
    chmod 755 /bin/checkgestor
    chmod 755 /usr/lib/checkgestor/checkgestor.py

    #=================================================
    # CHECKGESTOR KEVINTECH
    #=================================================

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

    # 0 = ilimitado
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

    #=================================================
    # CHECKUSER SERVICE
    #=================================================

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

    #-----------------------------------------------
    # Activar servicio
    #-----------------------------------------------

    systemctl daemon-reload

    systemctl enable checkuser.service >/dev/null 2>&1

    systemctl restart checkuser.service

    sleep 2

    #-----------------------------------------------
    # Verificar CheckUser
    #-----------------------------------------------

    if systemctl is-active --quiet checkuser.service; then
        msg_ok "CheckUser activo en puerto ${CHECKUSER_PORT}."
    else
        msg_error "CheckUser no pudo iniciar."
        systemctl status checkuser.service --no-pager
        return 1
    fi

    #-----------------------------------------------
    # Licencia
    #-----------------------------------------------

    mkdir -p /etc/licencec

    echo "By: @nandoslayer" \
        > /etc/licencec/telegram

}

#=========================================================
# OPCIÓN 04 - ONLINE APP
#=========================================================

function onapp1() {

    clear

    echo -e "\n\033[1;32mINICIANDO O ONLINE APP...\033[0m"
    echo ""

    apt install apache2 -y > /dev/null 2>&1

    #-----------------------------------------------
    # Apache 8888
    #-----------------------------------------------

    if grep -qE '^Listen 80$' /etc/apache2/ports.conf; then
        sed -i 's/^Listen 80$/Listen 8888/' \
            /etc/apache2/ports.conf
    elif ! grep -qE '^Listen 8888$' /etc/apache2/ports.conf; then
        echo "Listen 8888" >> /etc/apache2/ports.conf
    fi

    #-----------------------------------------------
    # Evitar conflicto Listen 80 en otros archivos
    #-----------------------------------------------

    sed -i 's/^Listen 80$/Listen 8888/' \
        /etc/apache2/ports.conf 2>/dev/null

    #-----------------------------------------------
    # Directorio
    #-----------------------------------------------

    rm -rf /var/www/html/server >/dev/null 2>&1

    mkdir -p /var/www/html/server >/dev/null 2>&1

    #-----------------------------------------------
    # Online App
    #-----------------------------------------------

    if [[ ! -f "$BASE/protocolos/onlineapp" ]]; then

        echo ""
        echo -e "${RED}✘ No existe:${RESET}"
        echo -e "${YELLOW}$BASE/protocolos/onlineapp${RESET}"
        echo ""

        return 1
    fi

    chmod +x "$BASE/protocolos/onlineapp"

    #-----------------------------------------------
    # Reiniciar Apache
    #-----------------------------------------------

    systemctl restart apache2 >/dev/null 2>&1

    #-----------------------------------------------
    # Iniciar Online App
    #-----------------------------------------------

    screen -S onlineapp -X quit >/dev/null 2>&1

    screen -dmS onlineapp \
        "$BASE/protocolos/onlineapp"

    sleep 3

    #-----------------------------------------------
    # AUTOSTART
    #-----------------------------------------------

    touch /etc/autostart

    sed -i '/onlineapp/d' /etc/autostart

    echo "ps x | grep '$BASE/protocolos/onlineapp' | grep -v grep >/dev/null || screen -dmS onlineapp $BASE/protocolos/onlineapp" \
        >> /etc/autostart

    #-----------------------------------------------
    # IP
    #-----------------------------------------------

    IP=$(wget -qO- --timeout=5 ipv4.icanhazip.com)

    [[ -z "$IP" ]] && \
        IP=$(hostname -I | awk '{print $1}')

    echo ""

    echo -e "\033[1;32mONLINE APP ACTIVO!\033[0m"

    echo -e "\033[1;33mURL de Usuários Online:\033[0m"

    echo "http://$IP:${ONLINEAPP_PORT}/server/online"

    echo ""

    sleep 3
}

function onapp2() {

    clear

    echo -e "\n\033[1;31mPARANDO O ONLINE APP...\033[0m"
    echo ""

    systemctl stop apache2 >/dev/null 2>&1

    screen -S onlineapp -X quit >/dev/null 2>&1

    pkill -f "$BASE/protocolos/onlineapp" >/dev/null 2>&1

    screen -wipe >/dev/null 2>&1

    [[ -f /etc/autostart ]] && \
        sed -i '/onlineapp/d' /etc/autostart

    rm -rf /var/www/html/server >/dev/null 2>&1

    sleep 3

    echo ""

    echo -e "\033[1;31mONLINE APP PARADO!\033[0m"

    sleep 3
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

    #-----------------------------------------------
    # Zona horaria
    #-----------------------------------------------

    echo "America/Lima" > /etc/timezone

    ln -fs \
        /usr/share/zoneinfo/America/Lima \
        /etc/localtime >/dev/null 2>&1

    dpkg-reconfigure \
        --frontend noninteractive \
        tzdata >/dev/null 2>&1

    clear

    echo -e "\E[44;1;37m  INSTALAR CHECKUSER PARA CONECTA4G,  \E[0m"
    echo -e "\E[44;1;37m      GLTUNNEL, DTUNNEL, ANYMOD.      \E[0m"
    echo -e "\E[44;1;37mVERSIÓN KEVINTECH                \E[0m"

    echo ""

    echo -e \
        "      \033[1;33m • \033[1;32mINICIANDO INSTALACIÓN\033[1;33m • \033[0m"

    echo ""

    fun_bar 'fun_install'

    clear

    echo -e "\E[44;1;37m       CHECKUSER KEVINTECH          \E[0m"

    echo -e "\E[44;1;37m       PUERTO: ${CHECKUSER_PORT}              \E[0m"

    echo -e "\E[44;1;37m       WEBSOCKET: ${WEBSOCKET_PORT}           \E[0m"

    echo -e "\E[44;1;37m       ONLINE APP: ${ONLINEAPP_PORT}          \E[0m"

    echo ""

    if systemctl is-active --quiet checkuser.service; then

        echo -e \
            "      \033[1;33m • \033[1;32mINSTALACIÓN CONCLUIDA\033[1;33m • \033[0m"

        echo ""

        echo -e "${GREEN}CheckUser:${RESET}"

        echo "http://$(hostname -I | awk '{print $1}'):${CHECKUSER_PORT}/checkUser"

        echo ""

        echo -e "${GREEN}WebSocket SSH:${RESET}"

        echo "Puerto ${WEBSOCKET_PORT}"

        echo ""

        echo -e "${GREEN}Online App:${RESET}"

        echo "Puerto ${ONLINEAPP_PORT}"

    else

        echo -e \
            "${RED}✘ CheckUser no está activo.${RESET}"

        echo ""

        systemctl status checkuser.service --no-pager

    fi

    echo ""

    echo -ne \
        "\033[1;32mDE UM ENTER PARA \033[1;33mCONTINUAR...\033[1;37m: "

    read -r

}

#=========================================================
# LIMPIEZA
#=========================================================

cat /dev/null > ~/.bash_history 2>/dev/null

history -c 2>/dev/null

rm -f /root/instcheck* >/dev/null 2>&1

rm -f /root/wget-log* >/dev/null 2>&1

#=========================================================
# EJECUTAR
#=========================================================

install