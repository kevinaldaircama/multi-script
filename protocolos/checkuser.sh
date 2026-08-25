#!/bin/bash

#=========================================================
#        KEVINTECH CHECKUSER INSTALLER
#        PREMIUM EDITION v4.0
#
# CheckUser    : 10016
# WebSocket    : 10015
# Online App   : 8888
# OS           : Ubuntu 24.04+
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

#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

BLACK="\e[1;30m"
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
VIOLET="\e[38;5;177m"
SKY="\e[38;5;117m"
LIME="\e[38;5;154m"
GOLD="\e[38;5;220m"

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}${BOLD}🔒 PERMISOS ROOT NECESARIOS${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${YELLOW}Ejecuta:${RESET}"
    echo
    echo -e "${CYAN}sudo -i${RESET}"
    echo
    exit 1

fi

#=========================================================
# CONFIG KEVINTECH
#=========================================================

mkdir -p "$BASE"

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
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                    PREMIUM v4.0${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${SKY}             🚀 CHECKUSER • WEBSOCKET • ONLINE APP 🚀${RESET}"
    echo

}

section() {

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD} $1${RESET}"
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

    for i in 1 2 3; do
        echo -ne "${PURPLE}●${RESET}"
        sleep 0.15
    done

    echo

}

pause() {

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    read -r -p "$(echo -e "${GOLD}${BOLD}➜ Presiona ENTER para continuar...${RESET}")"
}

#=========================================================
# COMPROBAR PUERTO
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
# COMPROBAR SERVICIOS
#=========================================================

check_service() {

    systemctl is-active --quiet "$1"

}

#=========================================================
# INSTALAR DEPENDENCIAS
#=========================================================

install_dependencies() {

    section "📦 PREPARANDO SISTEMA"

    export DEBIAN_FRONTEND=noninteractive

    loading "Actualizando repositorios"

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudieron actualizar los repositorios."
        return 1
    fi

    ok "Repositorios actualizados."

    loading "Instalando dependencias"

    if ! apt-get install -y \
        wget \
        curl \
        ca-certificates \
        python3 \
        python3-flask \
        apache2 \
        screen \
        figlet \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

#=========================================================
# DESCARGAR ARCHIVOS CHECKUSER
#=========================================================

download_checkuser() {

    section "📥 INSTALANDO CHECKUSER"

    mkdir -p "$CHECKUSER_DIR"

    loading "Descargando chall"

    if ! wget -qO /bin/chall \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/chall.sh; then

        error_msg "No se pudo descargar chall."
        return 1
    fi

    [[ -s /bin/chall ]] ||
        {
            error_msg "chall descargado vacío."
            return 1
        }

    chmod 755 /bin/chall

    ok "chall instalado."

    loading "Descargando CheckGestor"

    if ! wget -qO /bin/checkgestor \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.sh; then

        error_msg "No se pudo descargar checkgestor."
        return 1
    fi

    chmod 755 /bin/checkgestor

    ok "CheckGestor instalado."

    loading "Descargando API CheckUser"

    if ! wget -qO "$CHECKUSER_PY" \
        https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main/checkgestor.py; then

        error_msg "No se pudo descargar checkgestor.py."
        return 1
    fi

    if [[ ! -s "$CHECKUSER_PY" ]]; then

        error_msg "checkgestor.py está vacío."
        return 1

    fi

    chmod 755 "$CHECKUSER_PY"

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

    1) user_exist ;;
    2) cont_online ;;
    3) limiter_user ;;
    4) check_data ;;
    5) check_dias ;;
    6) check_new_data ;;
    7) datacheck_new ;;
    *) echo "Not exist" ;;

esac
EOF

    chmod 755 /bin/checkgestor

    ok "CheckGestor KevinTech configurado."

}

#=========================================================
# SERVICIO CHECKUSER
#=========================================================

create_checkuser_service() {

    section "🌐 CONFIGURANDO API CHECKUSER"

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
# ONLINE APP SERVICE
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

    #-----------------------------------------------------
    # Apache
    #-----------------------------------------------------

    loading "Configurando Apache"

    if grep -qE '^[[:space:]]*Listen[[:space:]]+80$' \
        /etc/apache2/ports.conf 2>/dev/null; then

        sed -i \
            's/^[[:space:]]*Listen[[:space:]]\+80$/Listen 8888/' \
            /etc/apache2/ports.conf

    elif ! grep -qE '^[[:space:]]*Listen[[:space:]]+8888$' \
        /etc/apache2/ports.conf 2>/dev/null; then

        echo "Listen 8888" >> /etc/apache2/ports.conf

    fi

    # Eliminar duplicados de Listen 8888
    awk '
    !seen[$0]++ || $0 !~ /^[[:space:]]*Listen[[:space:]]+8888[[:space:]]*$/
    ' /etc/apache2/ports.conf > /tmp/ports.conf

    mv /tmp/ports.conf /etc/apache2/ports.conf

    #-----------------------------------------------------
    # VirtualHost
    #-----------------------------------------------------

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

    if ! apache2ctl configtest >/dev/null 2>&1; then

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

        return 1
    fi

    ok "Apache activo en puerto $ONLINEAPP_PORT."

    #-----------------------------------------------------
    # Servicio Online App
    #-----------------------------------------------------

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

    systemctl restart "$ONLINEAPP_SERVICE"

    sleep 2

    if check_service "$ONLINEAPP_SERVICE"; then

        ok "Online App activo."

    else

        warning "El proceso Online App no quedó activo."

    fi

    return 0
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
# CONFIGURAR LICENCIA
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

        echo -e \
            " ${GREEN}●${RESET} ${WHITE}CheckUser:${RESET} ${GREEN}ACTIVO${RESET}"

    else

        echo -e \
            " ${RED}●${RESET} ${WHITE}CheckUser:${RESET} ${RED}DETENIDO${RESET}"

    fi

    if check_service "$ONLINEAPP_SERVICE"; then

        echo -e \
            " ${GREEN}●${RESET} ${WHITE}Online App:${RESET} ${GREEN}ACTIVO${RESET}"

    else

        echo -e \
            " ${YELLOW}●${RESET} ${WHITE}Online App:${RESET} ${YELLOW}NO DISPONIBLE${RESET}"

    fi

    echo

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                 INFORMACIÓN DE SERVICIOS${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}CheckUser  :${RESET} ${GREEN}TCP ${CHECKUSER_PORT}${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}WebSocket  :${RESET} ${GREEN}TCP ${WEBSOCKET_PORT}${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}Online App :${RESET} ${GREEN}TCP ${ONLINEAPP_PORT}${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                    🌐 CHECKUSER API${RESET}                    ${PURPLE}║${RESET}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
    IP=$(curl -4 -s --connect-timeout 5 https://api.ipify.org)

if [[ -z "$IP" ]]; then
    IP=$(hostname -I | awk '{print $1}')
fi

echo
echo -e "${GREEN}http://${IP}:${CHECKUSER_PORT}/checkUser${RESET}"
echo
╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                     📱 ONLINE APP${RESET}                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}URL:${RESET} ${GREEN}http://${IP}:${ONLINEAPP_PORT}/server/online${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    line

    echo -e "${WHITE}${BOLD}📁 ARCHIVOS PRINCIPALES${RESET}"
    echo
    echo -e " ${GRAY}CheckUser:${RESET} $CHECKUSER_PY"
    echo -e " ${GRAY}CheckGestor:${RESET} /bin/checkgestor"
    echo -e " ${GRAY}Chall:${RESET} /bin/chall"
    echo -e " ${GRAY}Configuración:${RESET} $CONFIG"

    echo

    echo -e "${GREEN}✔ KevinTech CheckUser quedó instalado.${RESET}"

    pause
}

#=========================================================
# INSTALACIÓN PRINCIPAL
#=========================================================

install() {

    header

    section "🚀 INSTALACIÓN CHECKUSER"

    echo -e "${WHITE}Componentes que serán configurados:${RESET}"
    echo
    echo -e " ${GREEN}01${RESET} 🛡️ CheckUser API      → TCP ${CHECKUSER_PORT}"
    echo -e " ${GREEN}02${RESET} 🔌 WebSocket SSH      → TCP ${WEBSOCKET_PORT}"
    echo -e " ${GREEN}03${RESET} 🌐 Online App          → TCP ${ONLINEAPP_PORT}"
    echo

    line

    #-----------------------------------------------------
    # Zona horaria
    #-----------------------------------------------------

    info "Configurando zona horaria..."

    timedatectl set-timezone America/Lima \
        >/dev/null 2>&1 || true

    ok "Zona horaria configurada."

    #-----------------------------------------------------
    # Dependencias
    #-----------------------------------------------------

    install_dependencies || {

        error_msg "La instalación fue detenida."
        pause
        return 1
    }

    #-----------------------------------------------------
    # CheckUser
    #-----------------------------------------------------

    download_checkuser || {

        error_msg "No se pudo instalar CheckUser."
        pause
        return 1
    }

    create_checkgestor

    create_checkuser_service || {

        error_msg "CheckUser no pudo quedar activo."
        pause
        return 1
    }

    #-----------------------------------------------------
    # Online App
    #-----------------------------------------------------

    create_onlineapp_service || {

        warning "Online App no pudo configurarse completamente."

    }

    #-----------------------------------------------------
    # Licencia
    #-----------------------------------------------------

    create_license_info

    #-----------------------------------------------------
    # Resultado
    #-----------------------------------------------------

    show_result

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

    echo -e "${WHITE}Estado de CheckUser:${RESET}"

    if systemctl is-active --quiet checkuser.service; then
        echo -e " ${GREEN}●${RESET} ${GREEN}ACTIVO${RESET}"
    elif [[ -f "/etc/systemd/system/checkuser.service" ]]; then
        echo -e " ${RED}●${RESET} ${RED}DETENIDO${RESET}"
    else
        echo -e " ${GRAY}●${RESET} ${GRAY}NO INSTALADO${RESET}"
    fi

    echo

    echo -e "${WHITE}Puertos:${RESET}"
    echo -e " ${CYAN}◆${RESET} CheckUser  : ${GREEN}${CHECKUSER_PORT}${RESET}"
    echo -e " ${CYAN}◆${RESET} WebSocket  : ${GREEN}${WEBSOCKET_PORT}${RESET}"
    echo -e " ${CYAN}◆${RESET} Online App : ${GREEN}${ONLINEAPP_PORT}${RESET}"

    line

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

    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
    echo -e " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

    echo

    echo -e "${GRAY}KevinTech Multi Script • CheckUser Manager v4.0${RESET}"

    echo

    read -r -p \
        "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
        OP

    case "$OP" in

        1)
            install
            ;;

        2)
            header

            systemctl restart checkuser.service

            sleep 2

            if systemctl is-active --quiet checkuser.service; then
                ok "CheckUser reiniciado correctamente."
            else
                error_msg "CheckUser no pudo reiniciarse."
            fi

            pause
            ;;

        3)
            header

            echo
            echo -e "${WHITE}${BOLD}📊 ESTADO DE CHECKUSER${RESET}"
            echo

            if systemctl is-active --quiet checkuser.service; then
                ok "CheckUser: ACTIVO"
            else
                error_msg "CheckUser: DETENIDO"
            fi

            echo

            ss -lntp 2>/dev/null |
                grep -E ":${CHECKUSER_PORT}|:${WEBSOCKET_PORT}|:${ONLINEAPP_PORT}" ||
                echo -e "${GRAY}No se encontraron los puertos escuchando.${RESET}"

            pause
            ;;

        4)
            create_onlineapp_service
            pause
            ;;

        5)
            header

            systemctl stop "$ONLINEAPP_SERVICE" 2>/dev/null || true

            ok "Online App detenido."

            pause
            ;;

        6)
            header

            echo -e "${WHITE}${BOLD}🔎 DIAGNÓSTICO${RESET}"
            echo

            [[ -f /bin/chall ]] &&
                ok "chall encontrado" ||
                error_msg "chall no encontrado"

            [[ -f /bin/checkgestor ]] &&
                ok "checkgestor encontrado" ||
                error_msg "checkgestor no encontrado"

            [[ -f "$CHECKUSER_PY" ]] &&
                ok "CheckUser API encontrada" ||
                error_msg "CheckUser API no encontrada"

            [[ -f "/etc/systemd/system/$CHECKUSER_SERVICE" ]] &&
                ok "Servicio CheckUser encontrado" ||
                error_msg "Servicio CheckUser no encontrado"

            if systemctl is-active --quiet "$CHECKUSER_SERVICE"; then
                ok "CheckUser está activo"
            else
                error_msg "CheckUser está detenido"
            fi

            echo

            echo -e "${WHITE}Puertos:${RESET}"

            for PORT in \
                "$CHECKUSER_PORT" \
                "$WEBSOCKET_PORT" \
                "$ONLINEAPP_PORT"
            do

                if ss -lnt 2>/dev/null |
                    grep -q ":${PORT} "; then

                    ok "TCP $PORT está escuchando"

                else

                    warning "TCP $PORT no está escuchando"

                fi

            done

            echo

            echo -e "${WHITE}Últimos logs:${RESET}"

            journalctl \
                -u "$CHECKUSER_SERVICE" \
                -n 20 \
                --no-pager \
                2>/dev/null

            pause
            ;;

        7)
            header

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

            header

            warning "Se eliminará CheckUser."

            read -r -p \
                "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
                CONFIRM

            if [[ "$CONFIRM" == "ELIMINAR" ]]; then

                systemctl stop "$CHECKUSER_SERVICE" 2>/dev/null || true
                systemctl disable "$CHECKUSER_SERVICE" 2>/dev/null || true

                rm -f \
                    "/etc/systemd/system/$CHECKUSER_SERVICE" \
                    /bin/chall \
                    /bin/checkgestor

                rm -rf "$CHECKUSER_DIR"

                systemctl daemon-reload

                ok "CheckUser eliminado."

            else

                warning "Operación cancelada."

            fi

            pause
            ;;

        0)

            clear

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