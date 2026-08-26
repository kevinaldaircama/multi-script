#!/bin/bash

#=========================================================
#        KEVINTECH CHECKUSER MANAGER
#        PREMIUM EDITION v5.1
#
#        INTEGRACIÓN CHECKUSER ORIGINAL
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
# URL CHECKUSER ORIGINAL
#=========================================================

CHECKUSER_REPO="https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main"

CHALL_URL="$CHECKUSER_REPO/chall.sh"
CHECKGESTOR_URL="$CHECKUSER_REPO/checkgestor.sh"
CHECKGESTOR_PY_URL="$CHECKUSER_REPO/checkgestor.py"

#=========================================================
# LICENCIA
#=========================================================

LICENSE_DIR="/etc/licencec"
LICENSE_FILE="$LICENSE_DIR/telegram"

LICENSE_TEXT="By: @nandoslayer"

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

    echo -e \
        "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

line_color() {

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

header() {

    clear_screen

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${PINK}${BOLD}              🛡️ KEVINTECH CHECKUSER${RESET}                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                    PREMIUM v5.1${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${SKY}          🚀 CHECKUSER • WEBSOCKET • ONLINE APP 🚀${RESET}"
    echo
}

section() {

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"

    printf \
        "${PURPLE}║${RESET} ${WHITE}${BOLD} %-58s${RESET} ${PURPLE}║${RESET}\n" \
        "$1"

    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

ok() {

    echo -e \
        " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"
}

error_msg() {

    echo -e \
        " ${RED}✖${RESET} ${WHITE}$1${RESET}"
}

warning() {

    echo -e \
        " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

info() {

    echo -e \
        " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"
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
# BARRA DE INSTALACIÓN - CORREGIDA
#=========================================================

fun_bar() {

    local COMMAND="$1"
    local RESULT_FILE="/tmp/kevintech_install_result"
    local LOG_FILE="/tmp/kevintech_install.log"

    rm -f "$RESULT_FILE" "$LOG_FILE"

    (
        # IMPORTANTE:
        # No usar bash -c aquí porque fun_install()
        # es una función del script actual.
        if eval "$COMMAND" >"$LOG_FILE" 2>&1; then

            echo "0" > "$RESULT_FILE"

        else

            echo "1" > "$RESULT_FILE"

        fi

    ) &

    local PID=$!

    tput civis 2>/dev/null || true

    echo -ne \
        "\033[1;33mAGUARDE \033[1;37m- \033[1;33m["

    while kill -0 "$PID" 2>/dev/null; do

        for ((i=0; i<18; i++)); do

            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi

            echo -ne "\033[1;31m#"

            sleep 0.10

        done

        if kill -0 "$PID" 2>/dev/null; then

            echo -e "\033[1;33m]"

            sleep 0.5

            tput cuu1 2>/dev/null || true
            tput dl1 2>/dev/null || true

            echo -ne \
                "\033[1;33mAGUARDE \033[1;37m- \033[1;33m["

        fi

    done

    wait "$PID" 2>/dev/null

    local RESULT

    RESULT=$(cat "$RESULT_FILE" 2>/dev/null)

    tput cnorm 2>/dev/null || true

    if [[ "$RESULT" == "0" ]]; then

        echo -e \
            "\033[1;33m]\033[1;37m - \033[1;32mOK !\033[1;37m"

        echo

        cat "$LOG_FILE" 2>/dev/null

        rm -f \
            "$RESULT_FILE" \
            "$LOG_FILE"

        return 0

    fi

    echo -e \
        "\033[1;33m]\033[1;37m - \033[1;31mERROR !\033[1;37m"

    echo
    echo -e "${RED}ERROR DURANTE LA INSTALACIÓN:${RESET}"
    echo

    cat "$LOG_FILE" 2>/dev/null

    echo

    rm -f \
        "$RESULT_FILE" \
        "$LOG_FILE"

    return 1
}
#=========================================================
# CHECK INSTALADO
#=========================================================

check_installed() {

    if [[ -f "/bin/chall" ]] &&
       [[ -f "/bin/checkgestor" ]] &&
       [[ -f "$CHECKUSER_PY" ]]; then

        return 0

    fi

    return 1
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
# DEPENDENCIAS
#=========================================================

install_dependencies() {

    section "📦 PREPARANDO SISTEMA"

    export DEBIAN_FRONTEND=noninteractive

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then

        error_msg \
            "No se pudieron actualizar los repositorios."

        return 1
    fi

    ok "Repositorios actualizados."

    info "Instalando dependencias..."

    if ! apt-get install -y \
        wget \
        curl \
        ca-certificates \
        python3 \
        python3-pip \
        python3-flask \
        apache2 \
        screen \
        figlet \
        iproute2 \
        net-tools \
        lsof \
        >/dev/null 2>&1; then

        error_msg \
            "No se pudieron instalar las dependencias."

        return 1
    fi

    ok "Dependencias instaladas."

    if python3 -c "import flask" >/dev/null 2>&1; then

        ok "Flask ya está disponible."

    else

        info "Instalando Flask..."

        if python3 -m pip install \
            flask \
            --break-system-packages \
            >/dev/null 2>&1; then

            ok "Flask instalado."

        else

            error_msg "No se pudo instalar Flask."

            return 1

        fi
    fi

    return 0
}

#=========================================================
# INSTALACIÓN CHECKUSER ORIGINAL - CORREGIDA
#=========================================================

fun_install() {

    local ERROR=0

    echo "Preparando dependencias..."

    if ! apt-get update -y >/dev/null 2>&1; then

        echo "ERROR: apt update falló."

        return 1
    fi

    if ! apt-get install -y \
        figlet \
        python3 \
        python3-pip \
        python3-flask \
        wget \
        curl \
        ca-certificates \
        screen \
        iproute2 \
        net-tools \
        lsof \
        >/dev/null 2>&1; then

        echo "ERROR: no se pudieron instalar las dependencias."

        return 1
    fi

    #=====================================================
    # DIRECTORIO
    #=====================================================

    mkdir -p "$CHECKUSER_DIR"

    #=====================================================
    # CHALL
    #=====================================================

    echo "Descargando chall..."

    rm -f /bin/chall

    if ! wget \
        -q \
        --show-progress \
        --timeout=30 \
        --tries=3 \
        -O /bin/chall \
        "$CHALL_URL"; then

        echo
        echo "ERROR: no se pudo descargar chall."

        ERROR=1
    fi

    if [[ ! -s /bin/chall ]]; then

        echo
        echo "ERROR: /bin/chall no existe o está vacío."

        ERROR=1

    else

        chmod 755 /bin/chall

        echo "OK: chall instalado."

    fi

    #=====================================================
    # CHECKGESTOR
    #=====================================================

    echo "Descargando checkgestor..."

    rm -f /bin/checkgestor

    if ! wget \
        -q \
        --show-progress \
        --timeout=30 \
        --tries=3 \
        -O /bin/checkgestor \
        "$CHECKGESTOR_URL"; then

        echo
        echo "ERROR: no se pudo descargar checkgestor."

        ERROR=1
    fi

    if [[ ! -s /bin/checkgestor ]]; then

        echo
        echo "ERROR: /bin/checkgestor no existe o está vacío."

        ERROR=1

    else

        chmod 755 /bin/checkgestor

        echo "OK: checkgestor instalado."

    fi

    #=====================================================
    # CHECKGESTOR PYTHON
    #=====================================================

    echo "Descargando checkgestor.py..."

    rm -f "$CHECKUSER_PY"

    if ! wget \
        -q \
        --show-progress \
        --timeout=30 \
        --tries=3 \
        -O "$CHECKUSER_PY" \
        "$CHECKGESTOR_PY_URL"; then

        echo
        echo "ERROR: no se pudo descargar checkgestor.py."

        ERROR=1
    fi

    if [[ ! -s "$CHECKUSER_PY" ]]; then

        echo
        echo "ERROR: checkgestor.py no existe o está vacío."

        ERROR=1

    else

        chmod 755 "$CHECKUSER_PY"

        echo "OK: checkgestor.py instalado."

    fi

    #=====================================================
    # FLASK
    #=====================================================

    echo "Comprobando Flask..."

    if python3 -c "import flask" >/dev/null 2>&1; then

        echo "OK: Flask disponible."

    else

        echo "Flask no está disponible."

        python3 -m pip install \
            flask \
            --break-system-packages \
            >/dev/null 2>&1 || true

        if python3 -c "import flask" >/dev/null 2>&1; then

            echo "OK: Flask instalado."

        else

            echo "ERROR: Flask no pudo instalarse."

            ERROR=1

        fi
    fi

    #=====================================================
    # LICENCIA
    #=====================================================

    mkdir -p "$LICENSE_DIR"

    echo "$LICENSE_TEXT" > "$LICENSE_FILE"

    chmod 644 "$LICENSE_FILE"

    echo "OK: información de instalación registrada."

    #=====================================================
    # VALIDAR PYTHON
    #=====================================================

    if [[ -s "$CHECKUSER_PY" ]]; then

        if python3 -m py_compile \
            "$CHECKUSER_PY" \
            >/dev/null 2>&1; then

            echo "OK: sintaxis Python correcta."

        else

            echo
            echo "ERROR: checkgestor.py tiene errores de sintaxis."

            python3 -m py_compile \
                "$CHECKUSER_PY"

            ERROR=1

        fi
    fi

    #=====================================================
    # RESULTADO
    #=====================================================

    if (( ERROR != 0 )); then

        echo
        echo "=============================================="
        echo " ERROR EN LA INSTALACIÓN CHECKUSER"
        echo "=============================================="
        echo

        return 1
    fi

    sleep 2

    return 0
}

#=========================================================
# CONFIGURAR CHECKGESTOR
#=========================================================

create_checkgestor() {

    section "⚙️ CONFIGURANDO CHECKGESTOR"

    if [[ ! -f /bin/checkgestor ]]; then

        error_msg \
            "No existe /bin/checkgestor."

        return 1
    fi

    chmod 755 /bin/checkgestor

    ok "CheckGestor configurado."

    if [[ -f /root/usuarios.db ]]; then

        ok "/root/usuarios.db detectado."

    else

        warning \
            "/root/usuarios.db no existe."

    fi

    return 0
}

#=========================================================
# SERVICIO CHECKUSER
#=========================================================

create_checkuser_service() {

    section "🌐 CONFIGURANDO CHECKUSER API"

    if [[ ! -f "$CHECKUSER_PY" ]]; then

        error_msg \
            "No existe $CHECKUSER_PY."

        return 1
    fi

    if port_tcp_in_use "$CHECKUSER_PORT"; then

        if ! check_service "$CHECKUSER_SERVICE"; then

            warning \
                "TCP $CHECKUSER_PORT ya está ocupado."

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

        ok \
            "CheckUser activo en TCP $CHECKUSER_PORT."

        return 0
    fi

    error_msg \
        "CheckUser no pudo iniciar."

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

    info \
        "Configurando Apache en puerto $ONLINEAPP_PORT..."

    mkdir -p "$ONLINEAPP_DIR"

    if [[ ! -f /etc/apache2/ports.conf ]]; then

        touch /etc/apache2/ports.conf

    fi

    sed -i \
        -E "/^[[:space:]]*Listen[[:space:]]+$ONLINEAPP_PORT[[:space:]]*$/d" \
        /etc/apache2/ports.conf

    echo "Listen $ONLINEAPP_PORT" \
        >> /etc/apache2/ports.conf

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

        error_msg \
            "La configuración de Apache es inválida."

        apache2ctl configtest

        return 1
    fi

    systemctl enable apache2 \
        >/dev/null 2>&1

    systemctl restart apache2

    sleep 2

    if ! systemctl is-active --quiet apache2; then

        error_msg \
            "Apache no pudo iniciar."

        journalctl \
            -u apache2 \
            -n 20 \
            --no-pager \
            2>/dev/null

        return 1
    fi

    ok \
        "Apache activo en TCP $ONLINEAPP_PORT."

    return 0
}

#=========================================================
# ONLINE APP
#=========================================================

create_onlineapp_service() {

    section "🌐 CONFIGURANDO ONLINE APP"

    if [[ ! -f "$ONLINEAPP_SCRIPT" ]]; then

        warning "No existe:"
        echo -e \
            " ${GRAY}$ONLINEAPP_SCRIPT${RESET}"

        warning \
            "Online App será omitido."

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

        warning \
            "Online App no quedó activo."

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

    mkdir -p "$LICENSE_DIR"

    cat > "$LICENSE_FILE" <<EOF
$LICENSE_TEXT
KevinTech CheckUser Manager
EOF

    chmod 644 "$LICENSE_FILE"

    ok \
        "Información de instalación registrada."
}

#=========================================================
# RESULTADO ORIGINAL
#=========================================================

show_original_install_info() {

    clear_screen

    echo -e \
        "\E[44;1;37m  INSTALAR CHECKUSER PARA CONECTA4G,  \E[0m"

    echo -e \
        "\E[44;1;37m      GLTUNNEL, DTUNNEL, ANYMOD.      \E[0m"

    echo -e \
        "\E[44;1;37mVERSIÓN 1.6       Integrado KevinTech \E[0m"

    echo

    echo -e \
        "      \033[1;33m • \033[1;32mINSTALACIÓN COMPLETADA\033[1;33m • \033[0m"

    sleep 1

    echo

    echo -e \
        "\033[1;31m \033[1;33mCOMANDO PRINCIPAL: \033[1;32mchall\033[0m"

    echo

    echo -e \
        "${YELLOW}RUTAS COMPATIBLES:${RESET}"

    echo

    echo -e \
        "${GREEN}/checkUser${RESET}"

    echo -e \
        "${GREEN}/gl/check/<usuario>${RESET}"

    echo -e \
        "${GREEN}/anymod${RESET}"

    echo

    echo -e \
        "${CYAN}CHECKUSER TCP: ${CHECKUSER_PORT}${RESET}"

    echo

    read -r -p \
        "$(echo -e "${GREEN}➜ Presiona ENTER para continuar...${RESET}")"
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

        ok \
            "CheckUser activo en TCP $CHECKUSER_PORT."

    else

        error_msg \
            "CheckUser está detenido."

    fi

    if check_service "$ONLINEAPP_SERVICE"; then

        ok \
            "Online App activo en TCP $ONLINEAPP_PORT."

    else

        warning \
            "Online App no está activo."

    fi

    echo

    section "🌐 DIRECCIONES"

    echo -e \
        "${GREEN}CheckUser:${RESET}"

    echo -e \
        "http://${IP}:${CHECKUSER_PORT}${CHECKUSER_URL_PATH}"

    echo

    echo -e \
        "${CYAN}Online App:${RESET}"

    echo -e \
        "http://${IP}:${ONLINEAPP_PORT}${ONLINEAPP_URL_PATH}"

    echo

    section "📡 RUTAS COMPATIBLES"

    echo -e \
        "${GREEN}CONECTA4G${RESET}"

    echo -e \
        "http://${IP}:${CHECKUSER_PORT}/checkUser"

    echo

    echo -e \
        "${GREEN}GLTUNNEL${RESET}"

    echo -e \
        "http://${IP}:${CHECKUSER_PORT}/gl/check/USUARIO"

    echo

    echo -e \
        "${GREEN}ANYMOD${RESET}"

    echo -e \
        "http://${IP}:${CHECKUSER_PORT}/anymod"

    echo

    line

    echo -e \
        "${WHITE}${BOLD}📁 ARCHIVOS PRINCIPALES${RESET}"

    echo

    echo -e \
        " ${GRAY}CheckUser:${RESET}     $CHECKUSER_PY"

    echo -e \
        " ${GRAY}CheckGestor:${RESET}   /bin/checkgestor"

    echo -e \
        " ${GRAY}Chall:${RESET}         /bin/chall"

    echo -e \
        " ${GRAY}Licencia:${RESET}      $LICENSE_FILE"

    echo -e \
        " ${GRAY}Configuración:${RESET} $CONFIG"

    echo

    echo -e \
        "${GREEN}✔ KevinTech CheckUser quedó instalado.${RESET}"

    pause
}

#=========================================================
# INSTALACIÓN COMPLETA
#=========================================================

install() {

    header

    section "🚀 INSTALACIÓN / ACTUALIZACIÓN CHECKUSER"

    echo -e "${WHITE}Componentes:${RESET}"

    echo

    echo -e \
        " ${GREEN}01${RESET} 🛡️ CheckUser API  → TCP $CHECKUSER_PORT"

    echo -e \
        " ${GREEN}02${RESET} 🔌 WebSocket      → TCP $WEBSOCKET_PORT"

    echo -e \
        " ${GREEN}03${RESET} 🌐 Online App     → TCP $ONLINEAPP_PORT"

    echo -e \
        " ${GREEN}04${RESET} 📥 Chall"

    echo -e \
        " ${GREEN}05${RESET} ⚙️ CheckGestor"

    echo -e \
        " ${GREEN}06${RESET} 🐍 Flask"

    echo

    line

    #=====================================================
    # ZONA HORARIA
    #=====================================================

    info "Configurando zona horaria..."

    timedatectl set-timezone America/Lima \
        >/dev/null 2>&1 || true

    ok "Zona horaria: America/Lima"

    #=====================================================
    # DEPENDENCIAS
    #=====================================================

    if ! install_dependencies; then

        error_msg \
            "La instalación fue detenida."

        pause

        return 1
    fi

    #=====================================================
    # INSTALACIÓN ORIGINAL CON BARRA
    #=====================================================

    section "⏳ INSTALACIÓN CHECKUSER ORIGINAL"

    echo -e \
        "${YELLOW}AGUARDE - preparando componentes...${RESET}"

    echo

    if ! fun_bar 'fun_install'; then

        error_msg \
            "La instalación de CheckUser falló."

        echo

        pause

        return 1
    fi

    #=====================================================
    # VALIDACIÓN
    #=====================================================

    section "🔎 VALIDANDO INSTALACIÓN"

    if [[ ! -s /bin/chall ]]; then

        error_msg \
            "chall no fue instalado correctamente."

        pause

        return 1
    fi

    ok "chall encontrado."

    if [[ ! -s /bin/checkgestor ]]; then

        error_msg \
            "checkgestor no fue instalado correctamente."

        pause

        return 1
    fi

    ok "checkgestor encontrado."

    if [[ ! -s "$CHECKUSER_PY" ]]; then

        error_msg \
            "checkgestor.py no fue instalado correctamente."

        pause

        return 1
    fi

    ok "checkgestor.py encontrado."

    #=====================================================
    # CHECKGESTOR
    #=====================================================

    create_checkgestor || {

        error_msg \
            "No se pudo configurar CheckGestor."

        pause

        return 1
    }

    #=====================================================
    # SERVICIO CHECKUSER
    #=====================================================

    create_checkuser_service || {

        error_msg \
            "CheckUser no pudo quedar activo."

        pause

        return 1
    }

    #=====================================================
    # ONLINE APP
    #=====================================================

    if ! create_onlineapp_service; then

        warning \
            "Online App no pudo configurarse."

    fi

    #=====================================================
    # MOSTRAR RESULTADO ORIGINAL
    #=====================================================

    show_original_install_info

    #=====================================================
    # MOSTRAR RESULTADO KEVINTECH
    #=====================================================

    show_result

    return 0
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

    if [[ -f "$LICENSE_FILE" ]]; then
        ok "Información de instalación encontrada."
    else
        warning "Información de instalación no encontrada."
    fi

    if [[ -f "/root/usuarios.db" ]]; then
        ok "/root/usuarios.db encontrado."
    else
        warning "/root/usuarios.db no encontrado."
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

    section "🐍 PYTHON"

    if [[ -f "$CHECKUSER_PY" ]] &&
       python3 -m py_compile \
        "$CHECKUSER_PY" \
        >/dev/null 2>&1; then

        ok "checkgestor.py tiene sintaxis correcta."

    else

        error_msg \
            "checkgestor.py tiene errores."

    fi

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

    echo -e \
        "${GREEN}http://${IP}:${CHECKUSER_PORT}${CHECKUSER_URL_PATH}${RESET}"

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

        ok \
            "CheckUser reiniciado correctamente."

    else

        error_msg \
            "CheckUser no pudo reiniciarse."

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
    local SISTEMA
    local RAM
    local DISCO

    IP=$(get_public_ip)

    SISTEMA=$(
        grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null |
        cut -d= -f2- |
        tr -d '"'
    )

    RAM=$(
        free -h 2>/dev/null |
        awk '/^Mem:/ {
            print $3 " / " $2
        }'
    )

    DISCO=$(
        df -h / 2>/dev/null |
        awk 'NR==2 {
            print $5
        }'
    )

    echo -e \
        "${WHITE}Hostname:${RESET} $(hostname)"

    echo -e \
        "${WHITE}Sistema:${RESET} ${SISTEMA:-Desconocido}"

    echo -e \
        "${WHITE}Kernel:${RESET} $(uname -r)"

    echo -e \
        "${WHITE}CPU:${RESET} $(nproc) cores"

    echo -e \
        "${WHITE}RAM:${RESET} ${RAM:-Desconocida}"

    echo -e \
        "${WHITE}Disco:${RESET} ${DISCO:-Desconocido}"

    echo -e \
        "${WHITE}Uptime:${RESET} $(uptime -p 2>/dev/null)"

    echo -e \
        "${WHITE}IPv4:${RESET} ${IP}"

    pause
}

#=========================================================
# INICIAR ONLINE APP
#=========================================================

start_onlineapp() {

    header

    section "🌐 INICIAR ONLINE APP"

    if [[ ! -f "$ONLINEAPP_SCRIPT" ]]; then

        warning \
            "No existe $ONLINEAPP_SCRIPT."

        pause

        return
    fi

    systemctl start "$ONLINEAPP_SERVICE"

    sleep 2

    if check_service "$ONLINEAPP_SERVICE"; then

        ok \
            "Online App iniciado correctamente."

    else

        error_msg \
            "Online App no pudo iniciar."

        journalctl \
            -u "$ONLINEAPP_SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

    fi

    pause
}

#=========================================================
# DETENER ONLINE APP
#=========================================================

stop_onlineapp() {

    header

    section "⛔ DETENER ONLINE APP"

    systemctl stop "$ONLINEAPP_SERVICE" \
        >/dev/null 2>&1 || true

    ok "Online App detenido."

    pause
}

#=========================================================
# DESINSTALAR
#=========================================================

uninstall_checkuser() {

    header

    section "🗑️ DESINSTALAR CHECKUSER"

    warning \
        "Se eliminará la instalación de CheckUser."

    echo

    read -r -p \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning \
            "Operación cancelada."

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

    rm -f "$LICENSE_FILE"

    if [[ -f /etc/apache2/ports.conf ]]; then

        sed -i \
            -E "/^[[:space:]]*Listen[[:space:]]+$ONLINEAPP_PORT[[:space:]]*$/d" \
            /etc/apache2/ports.conf

    fi

    if ! grep -qE \
        '^[[:space:]]*Listen[[:space:]]+80[[:space:]]*$' \
        /etc/apache2/ports.conf \
        2>/dev/null; then

        echo "Listen 80" \
            >> /etc/apache2/ports.conf

    fi

    systemctl restart apache2 \
        >/dev/null 2>&1 || true

    systemctl reset-failed \
        "$CHECKUSER_SERVICE" \
        >/dev/null 2>&1 || true

    systemctl reset-failed \
        "$ONLINEAPP_SERVICE" \
        >/dev/null 2>&1 || true

    ok \
        "CheckUser eliminado correctamente."

    pause
}

#=========================================================
# ACTUALIZAR ARCHIVOS
#=========================================================

update_checkuser() {

    header

    section "🔄 ACTUALIZAR CHECKUSER"

    if ! fun_bar 'fun_install'; then

        error_msg \
            "La actualización falló."

        pause

        return 1
    fi

    if ! create_checkuser_service; then

        error_msg \
            "No se pudo reiniciar CheckUser."

        pause

        return 1
    fi

    ok \
        "CheckUser actualizado correctamente."

    pause
}

#=========================================================
# PRUEBA API
#=========================================================

test_api() {

    header

    section "🧪 PRUEBA API CHECKUSER"

    if ! check_service "$CHECKUSER_SERVICE"; then

        error_msg \
            "El servicio CheckUser está detenido."

        pause

        return
    fi

    info "Probando TCP $CHECKUSER_PORT..."

    if ss -lnt 2>/dev/null |
        awk '{print $4}' |
        grep -Eq "(^|:)${CHECKUSER_PORT}$"; then

        ok \
            "TCP $CHECKUSER_PORT está escuchando."

    else

        error_msg \
            "TCP $CHECKUSER_PORT no está escuchando."

    fi

    echo

    info "Prueba GET /checkUser..."

    if curl \
        -sS \
        --max-time 5 \
        -o /tmp/kevintech_api_test \
        -w "%{http_code}" \
        "http://127.0.0.1:${CHECKUSER_PORT}/checkUser" \
        >/tmp/kevintech_http_code 2>/dev/null; then

        local CODE

        CODE=$(cat /tmp/kevintech_http_code)

        echo

        echo -e \
            "${WHITE}HTTP:${RESET} $CODE"

        cat /tmp/kevintech_api_test 2>/dev/null

        echo

    else

        warning \
            "No se pudo contactar con la API."

    fi

    rm -f \
        /tmp/kevintech_api_test \
        /tmp/kevintech_http_code

    pause
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

    echo -e \
        "${BLUE}${BOLD}🛡️ CHECKUSER MANAGER${RESET}"

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
        " ${GREEN}[08]${RESET} 🔄 Actualizar archivos CheckUser"

    echo -e \
        " ${GREEN}[09]${RESET} 🧪 Probar API"

    echo -e \
        " ${RED}[10]${RESET} 🗑️  Desinstalar"

    echo

    line

    echo -e \
        " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

    echo

    echo -e \
        "${GRAY}KevinTech Multi Script • CheckUser Manager v5.1${RESET}"

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
            start_onlineapp
            ;;

        5)
            stop_onlineapp
            ;;

        6)
            diagnostic
            ;;

        7)
            system_info
            ;;

        8)
            update_checkuser
            ;;

        9)
            test_api
            ;;

        10)
            uninstall_checkuser
            ;;

        0)

            clear_screen

            if [[ -f "$BASE/protocolos/menu.sh" ]]; then

                exec bash \
                    "$BASE/protocolos/menu.sh"

            else

                echo
                echo -e \
                    "${YELLOW}Menú de protocolos no encontrado.${RESET}"
                echo

                exit 0

            fi

            ;;

        "")

            ;;

        *)

            error_msg \
                "Opción inválida."

            sleep 1

            ;;

    esac

done