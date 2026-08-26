#!/bin/bash
#=========================================================
#        KEVINTECH CHECKUSER MANAGER
#        PREMIUM EDITION v5.1
#
#        CHECKUSER ORIGINAL INTEGRADO
#        SIN WEBSOCKET / SIN PUERTO 10015
#
# CheckUser  : TCP 10016
# Online App : TCP 8888
# OS         : Ubuntu 24.04+
#=========================================================

set -o pipefail

CHECKUSER_PORT="10016"
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

CHECKUSER_REPO="https://raw.githubusercontent.com/PhoenixxZ2023/checkUser2024/main"
CHALL_URL="$CHECKUSER_REPO/chall.sh"
CHECKGESTOR_URL="$CHECKUSER_REPO/checkgestor.sh"
CHECKGESTOR_PY_URL="$CHECKUSER_REPO/checkgestor.py"

LICENSE_DIR="/etc/licencec"
LICENSE_FILE="$LICENSE_DIR/telegram"
LICENSE_TEXT="By: @nandoslayer"

RESET="\e[0m"; BOLD="\e[1m"
RED="\e[1;91m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"
BLUE="\e[1;94m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"
GRAY="\e[1;90m"; PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"; SKY="\e[38;5;117m"; GOLD="\e[38;5;220m"

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}✘ EJECUTA ESTE SCRIPT COMO ROOT${RESET}"
    exit 1
fi

mkdir -p "$BASE" "$CHECKUSER_DIR"
[[ -f "$CONFIG" ]] && source "$CONFIG" 2>/dev/null || true

clear_screen(){ clear 2>/dev/null || true; }

line(){
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

header(){
    clear_screen
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${PINK}${BOLD}              🛡️ KEVINTECH CHECKUSER${RESET}                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                    PREMIUM v5.1${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${SKY}             🚀 CHECKUSER • ONLINE APP 🚀${RESET}"
    echo
}

section(){
    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    printf "${PURPLE}║${RESET} ${WHITE}${BOLD} %-58s${RESET} ${PURPLE}║${RESET}\n" "$1"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

ok(){ echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"; }
error_msg(){ echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"; }
warning(){ echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"; }
info(){ echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"; }

pause(){
    echo
    line
    read -r -p "$(echo -e "${GOLD}${BOLD}➜ Presiona ENTER para continuar...${RESET}")"
}

check_service(){ systemctl is-active --quiet "$1"; }

port_tcp_in_use(){
    local PORT="$1"
    ss -H -ltn 2>/dev/null | awk -v P=":$PORT" '$4==P || $4~P"$"{f=1} END{exit !f}'
}

get_public_ip(){
    local IP
    IP=$(curl -4 -fsS --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null)
    [[ -z "$IP" ]] && IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "${IP:-127.0.0.1}"
}

#=========================================================
# INSTALACION CHECKUSER ORIGINAL CORREGIDA
#=========================================================
fun_install(){
    local ERROR=0

    echo "Preparando dependencias..."

    if ! apt-get update -y >/dev/null 2>&1; then
        echo "ERROR: apt update falló."
        return 1
    fi

    if ! apt-get install -y \
        figlet python3 python3-pip python3-flask wget curl \
        ca-certificates screen iproute2 net-tools lsof apache2 \
        >/dev/null 2>&1; then
        echo "ERROR: no se pudieron instalar las dependencias."
        return 1
    fi

    mkdir -p "$CHECKUSER_DIR"

    echo "Descargando chall..."
    rm -f /bin/chall
    if ! wget -q --show-progress --timeout=30 --tries=3 \
        -O /bin/chall "$CHALL_URL"; then
        echo "ERROR: no se pudo descargar chall."
        ERROR=1
    fi

    if [[ ! -s /bin/chall ]]; then
        echo "ERROR: /bin/chall no existe o está vacío."
        ERROR=1
    else
        chmod 755 /bin/chall
        echo "OK: chall instalado."
    fi

    echo "Descargando checkgestor..."
    rm -f /bin/checkgestor
    if ! wget -q --show-progress --timeout=30 --tries=3 \
        -O /bin/checkgestor "$CHECKGESTOR_URL"; then
        echo "ERROR: no se pudo descargar checkgestor."
        ERROR=1
    fi

    if [[ ! -s /bin/checkgestor ]]; then
        echo "ERROR: /bin/checkgestor no existe o está vacío."
        ERROR=1
    else
        chmod 755 /bin/checkgestor
        echo "OK: checkgestor instalado."
    fi

    echo "Descargando checkgestor.py..."
    rm -f "$CHECKUSER_PY"
    if ! wget -q --show-progress --timeout=30 --tries=3 \
        -O "$CHECKUSER_PY" "$CHECKGESTOR_PY_URL"; then
        echo "ERROR: no se pudo descargar checkgestor.py."
        ERROR=1
    fi

    if [[ ! -s "$CHECKUSER_PY" ]]; then
        echo "ERROR: checkgestor.py no existe o está vacío."
        ERROR=1
    else
        chmod 755 "$CHECKUSER_PY"
        echo "OK: checkgestor.py instalado."
    fi

    echo "Comprobando Flask..."
    if python3 -c "import flask" >/dev/null 2>&1; then
        echo "OK: Flask disponible."
    else
        python3 -m pip install flask --break-system-packages >/dev/null 2>&1 || true
        if python3 -c "import flask" >/dev/null 2>&1; then
            echo "OK: Flask instalado."
        else
            echo "ERROR: Flask no pudo instalarse."
            ERROR=1
        fi
    fi

    mkdir -p "$LICENSE_DIR"
    echo "$LICENSE_TEXT" > "$LICENSE_FILE"
    chmod 644 "$LICENSE_FILE"
    echo "OK: información de instalación registrada."

    if [[ -s "$CHECKUSER_PY" ]]; then
        if python3 -m py_compile "$CHECKUSER_PY" >/dev/null 2>&1; then
            echo "OK: sintaxis Python correcta."
        else
            echo "ERROR: checkgestor.py tiene errores de sintaxis."
            python3 -m py_compile "$CHECKUSER_PY"
            ERROR=1
        fi
    fi

    (( ERROR == 0 )) || {
        echo
        echo "=============================================="
        echo " ERROR EN LA INSTALACIÓN CHECKUSER"
        echo "=============================================="
        return 1
    }

    sleep 2
    return 0
}

check_installed(){
    [[ -s /bin/chall && -s /bin/checkgestor && -s "$CHECKUSER_PY" ]]
}

install_dependencies(){
    section "📦 PREPARANDO SISTEMA"
    export DEBIAN_FRONTEND=noninteractive
    info "Actualizando repositorios..."
    apt-get update -y >/dev/null 2>&1 || {
        error_msg "No se pudieron actualizar los repositorios."
        return 1
    }
    ok "Repositorios actualizados."
    info "Instalando dependencias..."
    apt-get install -y wget curl ca-certificates python3 python3-pip \
        python3-flask apache2 screen figlet iproute2 net-tools lsof \
        >/dev/null 2>&1 || {
        error_msg "No se pudieron instalar las dependencias."
        return 1
    }
    ok "Dependencias instaladas."
}

create_checkgestor(){
    section "⚙️ CONFIGURANDO CHECKGESTOR"
    [[ -x /bin/checkgestor ]] || {
        error_msg "No existe /bin/checkgestor."
        return 1
    }
    chmod 755 /bin/checkgestor
    mkdir -p /etc/kevintech/limits
    ok "CheckGestor configurado."
    [[ -f /root/usuarios.db ]] && ok "/root/usuarios.db detectado." ||
        warning "/root/usuarios.db no existe."
}

create_checkuser_service(){
    section "🌐 CONFIGURANDO CHECKUSER API"

    [[ -s "$CHECKUSER_PY" ]] || {
        error_msg "No existe $CHECKUSER_PY."
        return 1
    }

    if port_tcp_in_use "$CHECKUSER_PORT" && ! check_service "$CHECKUSER_SERVICE"; then
        warning "TCP $CHECKUSER_PORT ya está ocupado."
        ss -lntp 2>/dev/null | grep ":$CHECKUSER_PORT" || true
        return 1
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
    systemctl enable "$CHECKUSER_SERVICE" >/dev/null 2>&1
    info "Iniciando CheckUser..."
    systemctl restart "$CHECKUSER_SERVICE"
    sleep 2

    if check_service "$CHECKUSER_SERVICE"; then
        ok "CheckUser activo en TCP $CHECKUSER_PORT."
        return 0
    fi

    error_msg "CheckUser no pudo iniciar."
    journalctl -u "$CHECKUSER_SERVICE" -n 25 --no-pager 2>/dev/null
    return 1
}

#=========================================================
# APACHE: SOLO 8888 - NO SE USA LISTEN 80
#=========================================================
configure_apache(){
    info "Configurando Apache únicamente en puerto $ONLINEAPP_PORT..."

    mkdir -p "$ONLINEAPP_DIR"

    cat > /etc/apache2/ports.conf <<EOF
Listen $ONLINEAPP_PORT
EOF

    rm -f /etc/apache2/sites-enabled/000-default.conf
    rm -f /etc/apache2/sites-enabled/kevintech-onlineapp.conf

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

    a2ensite kevintech-onlineapp.conf >/dev/null 2>&1

    apache2ctl configtest >/dev/null 2>&1 || {
        error_msg "Configuración Apache inválida."
        apache2ctl configtest
        return 1
    }

    systemctl enable apache2 >/dev/null 2>&1
    systemctl restart apache2
    sleep 2

    if systemctl is-active --quiet apache2; then
        ok "Apache activo únicamente en TCP $ONLINEAPP_PORT."
        return 0
    fi

    error_msg "Apache no pudo iniciar."
    journalctl -u apache2 -n 25 --no-pager 2>/dev/null
    return 1
}

create_onlineapp_service(){
    section "🌐 CONFIGURANDO ONLINE APP"

    if [[ ! -f "$ONLINEAPP_SCRIPT" ]]; then
        warning "No existe $ONLINEAPP_SCRIPT."
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
    systemctl enable "$ONLINEAPP_SERVICE" >/dev/null 2>&1
    systemctl restart "$ONLINEAPP_SERVICE"
    sleep 2

    if check_service "$ONLINEAPP_SERVICE"; then
        ok "Online App activo."
    else
        warning "Online App no quedó activo."
        journalctl -u "$ONLINEAPP_SERVICE" -n 15 --no-pager 2>/dev/null
    fi
}

create_license_info(){
    mkdir -p "$LICENSE_DIR"
    printf '%s\nKevinTech CheckUser Manager\n' "$LICENSE_TEXT" > "$LICENSE_FILE"
    chmod 644 "$LICENSE_FILE"
}

show_original_install_info(){
    clear_screen
    echo -e "\E[44;1;37m  INSTALAR CHECKUSER PARA CONECTA4G,  \E[0m"
    echo -e "\E[44;1;37m      GLTUNNEL, DTUNNEL, ANYMOD.      \E[0m"
    echo -e "\E[44;1;37mVERSIÓN 1.6       Integrado KevinTech \E[0m"
    echo
    echo -e "\033[1;33m • \033[1;32mINSTALACIÓN COMPLETADA\033[1;33m • \033[0m"
    echo
    echo -e "\033[1;33mCOMANDO PRINCIPAL: \033[1;32mchall\033[0m"
    echo
    echo -e "${CYAN}CHECKUSER TCP: ${CHECKUSER_PORT}${RESET}"
    echo
    read -r -p "$(echo -e "${GREEN}➜ Presiona ENTER para continuar...${RESET}")"
}

show_result(){
    local IP
    IP=$(get_public_ip)

    header
    section "🎉 INSTALACIÓN COMPLETADA"

    check_service "$CHECKUSER_SERVICE" &&
        ok "CheckUser activo en TCP $CHECKUSER_PORT." ||
        error_msg "CheckUser está detenido."

    check_service "$ONLINEAPP_SERVICE" &&
        ok "Online App activo en TCP $ONLINEAPP_PORT." ||
        warning "Online App no está activo."

    echo
    section "🔗 ENLACES DE CONEXIÓN"

    echo -e "${GREEN}📱 CONECTA4G${RESET}"
    echo "http://${IP}:10016/checkUser"
    echo
    echo -e "${GREEN}📱 DTUNNEL MOD${RESET}"
    echo "http://${IP}:10016"
    echo
    echo -e "${GREEN}📱 GLTUNNEL MOD${RESET}"
    echo "http://${IP}:10016/gl"
    echo
    echo -e "${GREEN}📱 ANYVPN MOD${RESET}"
    echo "http://${IP}:10016/anymod"
    echo
    echo -e "${CYAN}🌐 ONLINE APP${RESET}"
    echo "http://${IP}:8888/server/online"

    line
    echo
    echo -e "${WHITE}${BOLD}📁 ARCHIVOS PRINCIPALES${RESET}"
    echo " CheckUser:     $CHECKUSER_PY"
    echo " CheckGestor:   /bin/checkgestor"
    echo " Chall:         /bin/chall"
    echo " Licencia:      $LICENSE_FILE"
    echo
    ok "KevinTech CheckUser quedó instalado."
    pause
}

diagnostic(){
    header
    section "🔎 DIAGNÓSTICO CHECKUSER"

    [[ -s /bin/chall ]] && ok "chall encontrado." || error_msg "chall no encontrado."
    [[ -x /bin/checkgestor ]] && ok "checkgestor encontrado." || error_msg "checkgestor no encontrado."
    [[ -s "$CHECKUSER_PY" ]] && ok "API CheckUser encontrada." || error_msg "API CheckUser no encontrada."
    [[ -f "$LICENSE_FILE" ]] && ok "Información de instalación encontrada." || warning "Información no encontrada."

    echo
    check_service "$CHECKUSER_SERVICE" && ok "CheckUser está ACTIVO." ||
        error_msg "CheckUser está DETENIDO."

    check_service "$ONLINEAPP_SERVICE" && ok "Online App está ACTIVO." ||
        warning "Online App está DETENIDO."

    echo
    section "🔌 PUERTOS"

    for PORT in "$CHECKUSER_PORT" "$ONLINEAPP_PORT"; do
        if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${PORT}$"; then
            ok "TCP $PORT está escuchando."
        else
            warning "TCP $PORT no está escuchando."
        fi
    done

    echo
    section "🐍 PYTHON"
    python3 -m py_compile "$CHECKUSER_PY" >/dev/null 2>&1 &&
        ok "checkgestor.py tiene sintaxis correcta." ||
        error_msg "checkgestor.py tiene errores."

    echo
    section "📜 LOGS CHECKUSER"
    journalctl -u "$CHECKUSER_SERVICE" -n 20 --no-pager 2>/dev/null
    pause
}

status_checkuser(){
    header
    section "📊 ESTADO DEL SERVIDOR"

    check_service "$CHECKUSER_SERVICE" && ok "CheckUser : ACTIVO" ||
        error_msg "CheckUser : DETENIDO"

    check_service "$ONLINEAPP_SERVICE" && ok "Online App : ACTIVO" ||
        warning "Online App : DETENIDO"

    echo
    echo -e "${WHITE}Puertos TCP:${RESET}"

    for PORT in "$CHECKUSER_PORT" "$ONLINEAPP_PORT"; do
        if ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${PORT}$"; then
            echo -e " ${GREEN}●${RESET} TCP $PORT ${GREEN}ACTIVO${RESET}"
        else
            echo -e " ${RED}●${RESET} TCP $PORT ${RED}CERRADO${RESET}"
        fi
    done

    echo
    echo -e "${WHITE}CheckUser:${RESET}"
    echo -e "${GREEN}http://$(get_public_ip):10016/checkUser${RESET}"
    pause
}

restart_checkuser(){
    header
    section "♻️ REINICIANDO CHECKUSER"
    systemctl restart "$CHECKUSER_SERVICE"
    sleep 2
    check_service "$CHECKUSER_SERVICE" &&
        ok "CheckUser reiniciado correctamente." ||
        error_msg "CheckUser no pudo reiniciarse."
    pause
}

start_onlineapp(){
    header
    section "🌐 INICIAR ONLINE APP"
    [[ -f "$ONLINEAPP_SCRIPT" ]] || { warning "No existe $ONLINEAPP_SCRIPT."; pause; return; }
    systemctl start "$ONLINEAPP_SERVICE"
    sleep 2
    check_service "$ONLINEAPP_SERVICE" &&
        ok "Online App iniciado correctamente." ||
        error_msg "Online App no pudo iniciar."
    pause
}

stop_onlineapp(){
    header
    section "⛔ DETENER ONLINE APP"
    systemctl stop "$ONLINEAPP_SERVICE" >/dev/null 2>&1 || true
    ok "Online App detenido."
    pause
}

system_info(){
    header
    section "🖥️ INFORMACIÓN VPS"
    echo -e "${WHITE}Hostname:${RESET} $(hostname)"
    echo -e "${WHITE}Sistema:${RESET} $(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')"
    echo -e "${WHITE}Kernel:${RESET} $(uname -r)"
    echo -e "${WHITE}CPU:${RESET} $(nproc) cores"
    echo -e "${WHITE}RAM:${RESET} $(free -h | awk '/^Mem:/ {print $3" / "$2}')"
    echo -e "${WHITE}Disco:${RESET} $(df -h / | awk 'NR==2 {print $5}')"
    echo -e "${WHITE}Uptime:${RESET} $(uptime -p 2>/dev/null)"
    echo -e "${WHITE}IPv4:${RESET} $(get_public_ip)"
    pause
}

update_checkuser(){
    header
    section "🔄 ACTUALIZAR CHECKUSER"
    if ! fun_install; then
        error_msg "La actualización falló."
        pause
        return 1
    fi
    create_checkgestor || true
    create_checkuser_service || true
    ok "Archivos CheckUser actualizados."
    pause
}

test_api(){
    header
    section "🧪 PRUEBA API CHECKUSER"
    if ! check_service "$CHECKUSER_SERVICE"; then
        error_msg "El servicio CheckUser está detenido."
        pause
        return
    fi
    info "Probando TCP $CHECKUSER_PORT..."
    if curl -fsS --max-time 5 "http://127.0.0.1:${CHECKUSER_PORT}/checkUser" >/tmp/kevintech_checkuser_test 2>/dev/null; then
        ok "El servidor CheckUser responde."
        cat /tmp/kevintech_checkuser_test
        rm -f /tmp/kevintech_checkuser_test
    else
        warning "El puerto está activo, pero /checkUser puede requerir una petición válida."
    fi
    pause
}

uninstall_checkuser(){
    header
    section "🗑️ DESINSTALAR CHECKUSER"
    warning "Se eliminará la instalación de CheckUser."
    read -r -p "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" CONFIRM
    [[ "$CONFIRM" == "ELIMINAR" ]] || { warning "Operación cancelada."; pause; return; }

    systemctl stop "$CHECKUSER_SERVICE" "$ONLINEAPP_SERVICE" >/dev/null 2>&1 || true
    systemctl disable "$CHECKUSER_SERVICE" "$ONLINEAPP_SERVICE" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/$CHECKUSER_SERVICE" "/etc/systemd/system/$ONLINEAPP_SERVICE"
    systemctl daemon-reload

    rm -f /bin/chall /bin/checkgestor
    rm -rf "$CHECKUSER_DIR"
    rm -f /etc/apache2/sites-enabled/kevintech-onlineapp.conf
    rm -f /etc/apache2/sites-available/kevintech-onlineapp.conf
    rm -f "$LICENSE_FILE"

    if [[ -f /etc/apache2/ports.conf ]]; then
        cat > /etc/apache2/ports.conf <<EOF
Listen 80
EOF
    fi

    rm -f /etc/apache2/sites-enabled/000-default.conf
    systemctl restart apache2 >/dev/null 2>&1 || true

    ok "CheckUser eliminado correctamente."
    pause
}

install(){
    header
    section "🚀 INSTALACIÓN / ACTUALIZACIÓN CHECKUSER"

    echo -e "${WHITE}Componentes:${RESET}"
    echo
    echo -e " ${GREEN}01${RESET} 🛡️ CheckUser API → TCP $CHECKUSER_PORT"
    echo -e " ${GREEN}02${RESET} 🌐 Online App → TCP $ONLINEAPP_PORT"
    echo -e " ${GREEN}03${RESET} 📥 Chall"
    echo -e " ${GREEN}04${RESET} ⚙️ CheckGestor"
    echo -e " ${GREEN}05${RESET} 🐍 Flask"
    line

    timedatectl set-timezone America/Lima >/dev/null 2>&1 || true
    ok "Zona horaria: America/Lima"

    install_dependencies || { error_msg "La instalación fue detenida."; pause; return 1; }

    section "⏳ INSTALACIÓN CHECKUSER ORIGINAL"
    echo -e "${YELLOW}AGUARDE - preparando componentes...${RESET}"

    if ! fun_install; then
        error_msg "La instalación de CheckUser falló."
        pause
        return 1
    fi

    section "🔎 VALIDANDO INSTALACIÓN"
    check_installed || {
        error_msg "Faltan archivos de CheckUser."
        pause
        return 1
    }

    ok "chall encontrado."
    ok "checkgestor encontrado."
    ok "checkgestor.py encontrado."

    create_checkgestor || { pause; return 1; }
    create_checkuser_service || { pause; return 1; }
    create_onlineapp_service || warning "Online App no pudo configurarse."
    create_license_info

    show_original_install_info
    show_result
}

if [[ "$1" == "--auto" ]]; then
    install
    exit $?
fi

while true; do
    header
    section "📊 ESTADO"

    if check_service "$CHECKUSER_SERVICE"; then
        echo -e " ${GREEN}●${RESET} CheckUser ${GREEN}ACTIVO${RESET}"
    elif [[ -f "/etc/systemd/system/$CHECKUSER_SERVICE" ]]; then
        echo -e " ${RED}●${RESET} CheckUser ${RED}DETENIDO${RESET}"
    else
        echo -e " ${GRAY}●${RESET} CheckUser ${GRAY}NO INSTALADO${RESET}"
    fi

    check_service "$ONLINEAPP_SERVICE" &&
        echo -e " ${GREEN}●${RESET} Online App ${GREEN}ACTIVO${RESET}" ||
        echo -e " ${GRAY}●${RESET} Online App ${GRAY}DETENIDO${RESET}"

    echo
    echo -e "${WHITE}Puertos:${RESET}"
    echo -e " ${CYAN}◆${RESET} CheckUser  : ${GREEN}$CHECKUSER_PORT${RESET}"
    echo -e " ${CYAN}◆${RESET} Online App : ${GREEN}$ONLINEAPP_PORT${RESET}"

    line
    echo -e "${BLUE}${BOLD}🛡️ CHECKUSER MANAGER${RESET}"
    echo
    echo -e " ${GREEN}[01]${RESET} 🚀 Instalar / Actualizar"
    echo -e " ${GREEN}[02]${RESET} ♻️ Reiniciar CheckUser"
    echo -e " ${GREEN}[03]${RESET} 📊 Estado"
    echo -e " ${GREEN}[04]${RESET} 🌐 Iniciar Online App"
    echo -e " ${GREEN}[05]${RESET} ⛔ Detener Online App"
    echo -e " ${GREEN}[06]${RESET} 🔎 Diagnóstico"
    echo -e " ${GREEN}[07]${RESET} 🖥️ Información VPS"
    echo -e " ${GREEN}[08]${RESET} 🔄 Actualizar archivos CheckUser"
    echo -e " ${GREEN}[09]${RESET} 🧪 Probar API"
    echo -e " ${RED}[10]${RESET} 🗑️ Desinstalar"
    echo
    line
    echo -e " ${RED}[00]${RESET} ↩️ Regresar al Menú de Protocolos"
    echo
    echo -e "${GRAY}KevinTech Multi Script • CheckUser Manager v5.1${RESET}"
    echo

    read -r -p "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in
        1) install ;;
        2) restart_checkuser ;;
        3) status_checkuser ;;
        4) start_onlineapp ;;
        5) stop_onlineapp ;;
        6) diagnostic ;;
        7) system_info ;;
        8) update_checkuser ;;
        9) test_api ;;
        10) uninstall_checkuser ;;
        0)
            clear_screen
            if [[ -f "$BASE/protocolos/menu.sh" ]]; then
                exec bash "$BASE/protocolos/menu.sh"
            else
                echo -e "${YELLOW}Menú de protocolos no encontrado.${RESET}"
                exit 0
            fi
            ;;
        "") ;;
        *) error_msg "Opción inválida."; sleep 1 ;;
    esac
done
