#!/bin/bash

#=========================================================
#        KEVINTECH CHECKUSER INSTALLER
#        CheckUser fijo: 10016
#        WebSocket SSH: 10015
#        Online App: 8888
#        Ubuntu 24.04+
#=========================================================

set -o pipefail

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

[[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null || true

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
    read -r -p "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"
}

#=========================================================
# BARRA DE PROGRESO
#=========================================================

fun_bar() {

    local CMD="$1"
    local TMPFILE

    TMPFILE=$(mktemp)

    tput civis 2>/dev/null || true

    echo
    echo -ne "${YELLOW}AGUARDE ${WHITE}- ${YELLOW}[${RESET}"

    (
        bash -c "$CMD" >"$TMPFILE" 2>&1
        echo $? > "${TMPFILE}.exit"
    ) &

    local PID=$!

    while kill -0 "$PID" 2>/dev/null; do

        for ((i=0; i<18; i++)); do

            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi

            echo -ne "${GREEN}#${RESET}"
            sleep 0.08

        done

        if kill -0 "$PID" 2>/dev/null; then

            echo -e "${YELLOW}]${RESET}"
            sleep 0.5

            printf '\033[1A'
            printf '\033[2K'
            echo -ne "${YELLOW}AGUARDE ${WHITE}- ${YELLOW}[${RESET}"

        fi

    done

    wait "$PID" 2>/dev/null || true

    echo -ne "${GREEN}##################${RESET}${YELLOW}]${RESET}"

    local RESULT=1

    if [[ -f "${TMPFILE}.exit" ]]; then
        RESULT=$(cat "${TMPFILE}.exit" 2>/dev/null)
    fi

    echo

    tput cnorm 2>/dev/null || true

    if [[ "$RESULT" == "0" ]]; then

        echo -e "${GREEN}✔ INSTALACIÓN FINALIZADA${RESET}"

    else

        echo -e "${RED}✘ LA INSTALACIÓN PRESENTÓ UN ERROR${RESET}"

        echo
        echo -e "${YELLOW}Último resultado:${RESET}"
        cat "$TMPFILE" 2>/dev/null

    fi

    rm -f "$TMPFILE" "${TMPFILE}.exit"

    return "$RESULT"
}

#=========================================================
# VERIFICAR CHECKUSER
#=========================================================

check_installed() {

    [[ -f "/usr/lib/checkgestor/checkgestor.py" ]] &&
    [[ -f "/bin/checkgestor" ]] &&
    [[ -f "/bin/chall" ]] &&
    systemctl is-enabled \
        checkuser.service \
        >/dev/null 2>&1

}

#=========================================================
# INSTALAR CHECKUSER
#=========================================================

fun_install() {

    export DEBIAN_FRONTEND=noninteractive

    msg_info "Actualizando repositorios..."

    if ! apt-get update -y; then

        msg_error "No se pudo actualizar APT."
        return 1

    fi

    msg_ok "Repositorios actualizados."

    msg_info "Instalando dependencias..."

    if ! apt-get install -y \
        figlet \
        wget \
        curl \
        ca-certificates \
        python3 \
        python3-flask \
        apache2 \
        screen
    then

        msg_error "No se pudieron instalar las dependencias."
        return 1

    fi

    msg_ok "Dependencias instaladas."

    mkdir -p /usr/lib/checkgestor

    #=====================================================
    # DESCARGAR ARCHIVOS
    #=====================================================

    msg_info "Descargando chall..."

    if ! wget -qO /bin/chall \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/chall.sh
    then

        msg_error "No se pudo descargar chall."
        return 1

    fi

    [[ -s /bin/chall ]] || {
        msg_error "chall está vacío."
        return 1
    }

    chmod 755 /bin/chall

    msg_ok "chall instalado."

    #-----------------------------------------------------

    msg_info "Descargando checkgestor..."

    if ! wget -qO /bin/checkgestor \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.sh
    then

        msg_error "No se pudo descargar checkgestor."
        return 1

    fi

    [[ -s /bin/checkgestor ]] || {
        msg_error "checkgestor está vacío."
        return 1
    }

    chmod 755 /bin/checkgestor

    msg_ok "checkgestor descargado."

    #-----------------------------------------------------

    msg_info "Descargando CheckUser API..."

    if ! wget -qO /usr/lib/checkgestor/checkgestor.py \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.py
    then

        msg_error "No se pudo descargar checkgestor.py."
        return 1

    fi

    [[ -s /usr/lib/checkgestor/checkgestor.py ]] || {

        msg_error "checkgestor.py está vacío."
        return 1

    }

    chmod 755 /usr/lib/checkgestor/checkgestor.py

    msg_ok "CheckUser API descargada."

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
    # SERVICIO CHECKUSER
    #=====================================================

    msg_info "Configurando servicio CheckUser..."

    cat > /etc/systemd/system/checkuser.service <<EOF
[Unit]
Description=KevinTech CheckUser API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/lib/checkgestor

ExecStart=/usr/bin/python3 /usr/lib/checkgestor/checkgestor.py ${CHECKUSER_PORT}

Restart=always
RestartSec=3

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    if ! systemctl enable checkuser.service >/dev/null 2>&1; then

        msg_error "No se pudo habilitar CheckUser."
        return 1

    fi

    systemctl restart checkuser.service

    sleep 2

    if systemctl is-active --quiet checkuser.service; then

        msg_ok "CheckUser activo en puerto ${CHECKUSER_PORT}."

    else

        msg_error "CheckUser no pudo iniciar."

        echo
        journalctl \
            -u checkuser.service \
            -n 25 \
            --no-pager

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
# ONLINE APP
#=========================================================

onapp1() {

    clear

    echo
    echo -e "${GREEN}INICIANDO ONLINE APP...${RESET}"
    echo

    apt-get install -y apache2 >/dev/null 2>&1 || {

        msg_error "No se pudo instalar Apache."
        return 1

    }

    if grep -qE '^Listen 80$' \
        /etc/apache2/ports.conf 2>/dev/null; then

        sed -i \
            's/^Listen 80$/Listen 8888/' \
            /etc/apache2/ports.conf

    elif ! grep -qE '^Listen 8888$' \
        /etc/apache2/ports.conf 2>/dev/null; then

        echo "Listen 8888" \
            >> /etc/apache2/ports.conf

    fi

    rm -rf /var/www/html/server >/dev/null 2>&1

    mkdir -p /var/www/html/server

    if [[ ! -f "$BASE/protocolos/onlineapp" ]]; then

        msg_error "No existe:"
        echo "$BASE/protocolos/onlineapp"

        return 1

    fi

    chmod +x "$BASE/protocolos/onlineapp"

    systemctl restart apache2 >/dev/null 2>&1

    screen -S onlineapp -X quit >/dev/null 2>&1 || true

    screen -dmS onlineapp \
        "$BASE/protocolos/onlineapp"

    sleep 3

    IP=$(wget -qO- \
        --timeout=5 \
        https://api.ipify.org 2>/dev/null)

    [[ -z "$IP" ]] &&
        IP=$(hostname -I | awk '{print $1}')

    echo
    echo -e "${GREEN}ONLINE APP ACTIVO${RESET}"
    echo
    echo "http://${IP}:${ONLINEAPP_PORT}/server/online"
    echo

}

onapp2() {

    clear

    echo
    echo -e "${RED}PARANDO ONLINE APP...${RESET}"
    echo

    screen -S onlineapp -X quit >/dev/null 2>&1 || true

    pkill -f "$BASE/protocolos/onlineapp" >/dev/null 2>&1 || true

    screen -wipe >/dev/null 2>&1 || true

    echo
    echo -e "${RED}ONLINE APP PARADO${RESET}"
    echo

}

onapp_ssh() {

    if pgrep -f "$BASE/protocolos/onlineapp" >/dev/null; then
        onapp2
    else
        onapp1
    fi

}

#=========================================================
# OBTENER IP
#=========================================================

get_public_ip() {

    local IP

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
        IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    echo "${IP:-No disponible}"

}

#=========================================================
# INSTALACIÓN PRINCIPAL
#=========================================================

install() {

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
    echo -e "\E[44;1;37m        VERSIÓN KEVINTECH             \E[0m"

    echo

    echo -e \
        "      \033[1;33m • \033[1;32mINICIANDO INSTALACIÓN\033[1;33m • \033[0m"

    echo

    if ! fun_bar 'fun_install'; then

        echo
        echo -e "${RED}✘ LA INSTALACIÓN FALLÓ.${RESET}"
        echo

        pause

        return 1

    fi

    clear

    if systemctl is-active --quiet checkuser.service; then

        IP=$(get_public_ip)

        echo
        echo -e "${GREEN}✔ CHECKUSER INSTALADO CORRECTAMENTE${RESET}"
        echo
        echo -e "${GREEN}http://${IP}:${CHECKUSER_PORT}/checkUser${RESET}"
        echo

    else

        echo
        echo -e "${RED}✘ CHECKUSER NO ESTÁ ACTIVO${RESET}"
        echo

        journalctl \
            -u checkuser.service \
            -n 20 \
            --no-pager

        echo

    fi

    echo
    echo -ne \
        "${GREEN}PRESIONA ENTER PARA ${YELLOW}CONTINUAR...${RESET}"

    read -r

    #=====================================================
    # REGRESAR AL MENÚ DE PROTOCOLOS
    #=====================================================

    clear

    if [[ -f "$BASE/protocolos/menu.sh" ]]; then

        exec bash \
            "$BASE/protocolos/menu.sh"

    fi

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
# MENÚ
#=========================================================

while true; do

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${GREEN}🛡️ KEVINTECH CHECKUSER${RESET}                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                    ${WHITE}MANAGER v3.0${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    if systemctl is-active --quiet checkuser.service; then

        echo -e "${GREEN}● CHECKUSER: ACTIVO${RESET}"

    elif [[ -f /etc/systemd/system/checkuser.service ]]; then

        echo -e "${RED}● CHECKUSER: DETENIDO${RESET}"

    else

        echo -e "${YELLOW}● CHECKUSER: NO INSTALADO${RESET}"

    fi

    echo

    echo -e "${WHITE}Puertos configurados:${RESET}"
    echo -e " ${CYAN}◆${RESET} CheckUser  : ${GREEN}${CHECKUSER_PORT}${RESET}"
    echo -e " ${CYAN}◆${RESET} WebSocket  : ${GREEN}${WEBSOCKET_PORT}${RESET}"
    echo -e " ${CYAN}◆${RESET} Online App : ${GREEN}${ONLINEAPP_PORT}${RESET}"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    echo -e "${BLUE}${BOLD}🛡️ CHECKUSER${RESET}"
    echo

    echo -e " ${GREEN}[01]${RESET} 🚀 Instalar / Actualizar"
    echo -e " ${GREEN}[02]${RESET} ♻️  Reiniciar CheckUser"
    echo -e " ${GREEN}[03]${RESET} 📊 Estado"
    echo -e " ${GREEN}[04]${RESET} 🌐 Online App"
    echo -e " ${GREEN}[05]${RESET} ⛔ Detener Online App"
    echo -e " ${GREEN}[06]${RESET} 🔎 Diagnóstico"
    echo -e " ${GREEN}[07]${RESET} 🖥️  Información VPS"
    echo -e " ${RED}[08]${RESET} 🗑️  Desinstalar"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " ${RED}[00]${RESET} ↩️ Regresar al Menú de Protocolos"
    echo

    read -r -p \
        "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)

            install

            ;;

        2)

            clear

            systemctl restart checkuser.service

            sleep 2

            if systemctl is-active --quiet checkuser.service; then
                msg_ok "CheckUser reiniciado correctamente."
            else
                msg_error "CheckUser no pudo reiniciarse."
            fi

            pause

            ;;

        3)

            clear

            echo -e "${WHITE}${BOLD}📊 ESTADO CHECKUSER${RESET}"
            echo

            if systemctl is-active --quiet checkuser.service; then
                msg_ok "CheckUser: ACTIVO"
            else
                msg_error "CheckUser: DETENIDO"
            fi

            echo

            ss -lntp 2>/dev/null |
                grep -E ":${CHECKUSER_PORT}|:${WEBSOCKET_PORT}|:${ONLINEAPP_PORT}" ||
                echo -e "${YELLOW}No se encontraron puertos escuchando.${RESET}"

            pause

            ;;

        4)

            onapp_ssh

            pause

            ;;

        5)

            onapp2

            pause

            ;;

        6)

            clear

            echo -e "${WHITE}${BOLD}🔎 DIAGNÓSTICO CHECKUSER${RESET}"
            echo

            [[ -f /bin/chall ]] &&
                msg_ok "chall encontrado" ||
                msg_error "chall no encontrado"

            [[ -f /bin/checkgestor ]] &&
                msg_ok "checkgestor encontrado" ||
                msg_error "checkgestor no encontrado"

            [[ -f /usr/lib/checkgestor/checkgestor.py ]] &&
                msg_ok "CheckUser API encontrada" ||
                msg_error "CheckUser API no encontrada"

            [[ -f /etc/systemd/system/checkuser.service ]] &&
                msg_ok "Servicio encontrado" ||
                msg_error "Servicio no encontrado"

            if systemctl is-active --quiet checkuser.service; then
                msg_ok "Servicio activo"
            else
                msg_error "Servicio detenido"
            fi

            echo
            echo -e "${WHITE}Puerto CheckUser:${RESET}"

            if ss -lnt 2>/dev/null |
                grep -q ":${CHECKUSER_PORT} "; then

                msg_ok "TCP ${CHECKUSER_PORT} está escuchando"

            else

                msg_error "TCP ${CHECKUSER_PORT} no está escuchando"

            fi

            echo
            echo -e "${WHITE}Últimos logs:${RESET}"

            journalctl \
                -u checkuser.service \
                -n 20 \
                --no-pager \
                2>/dev/null

            pause

            ;;

        7)

            clear

            echo -e "${WHITE}${BOLD}🖥️ INFORMACIÓN VPS${RESET}"
            echo

            echo -e "${WHITE}Hostname:${RESET} $(hostname)"
            echo -e "${WHITE}Sistema:${RESET} $(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
            echo -e "${WHITE}Kernel:${RESET} $(uname -r)"
            echo -e "${WHITE}RAM:${RESET} $(free -h | awk '/Mem:/ {print $3" / "$2}')"
            echo -e "${WHITE}Disco:${RESET} $(df -h / | awk 'NR==2 {print $5}')"
            echo -e "${WHITE}Uptime:${RESET} $(uptime -p)"

            pause

            ;;

        8)

            clear

            msg_warn "Se eliminará CheckUser."

            echo

            read -r -p \
                "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
                CONFIRM

            if [[ "$CONFIRM" == "ELIMINAR" ]]; then

                systemctl stop checkuser.service \
                    2>/dev/null || true

                systemctl disable checkuser.service \
                    2>/dev/null || true

                rm -f \
                    /etc/systemd/system/checkuser.service \
                    /bin/chall \
                    /bin/checkgestor

                rm -rf /usr/lib/checkgestor

                systemctl daemon-reload

                msg_ok "CheckUser eliminado correctamente."

            else

                msg_warn "Operación cancelada."

            fi

            pause

            ;;

        0)

            clear

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

done