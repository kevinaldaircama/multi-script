#!/bin/bash

#==================================================
# KevinTech Multi Script
# CHECKUSER + ONLINE APP
#==================================================

BASE="/etc/kevintech"

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==================================================
# CONFIGURACIÓN
#==================================================

CHECKUSER_PORT="10016"
ONLINE_PORT="8888"

CHECKUSER_DIR="/usr/lib/checkgestor"
CHECKUSER_PY="$CHECKUSER_DIR/checkgestor.py"

CHECKUSER_CMD="/bin/checkgestor"
CHECKUSER_MANAGER="/bin/chall"

CHECKUSER_SERVICE="/etc/systemd/system/checkuser.service"

ONLINE_DIR="$BASE/protocolos"
ONLINE_APP="$ONLINE_DIR/onlineapp"

ONLINE_SERVICE="/etc/systemd/system/kevintech-onlineapp.service"

mkdir -p "$BASE"
mkdir -p "$ONLINE_DIR"

#==================================================
# FUNCIONES
#==================================================

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

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

#==================================================
# DETECTAR CHECKUSER
#==================================================

checkuser_installed() {

    [[ -f "$CHECKUSER_PY" ]] &&
    [[ -f "$CHECKUSER_CMD" ]]
}

#==================================================
# DETECTAR ONLINE APP
#==================================================

online_installed() {

    [[ -f "$ONLINE_APP" ]]
}

#==================================================
# ESTADO CHECKUSER
#==================================================

status_checkuser() {

    if systemctl is-active --quiet checkuser 2>/dev/null; then
        echo -e "${GREEN}🟢 ACTIVO : ${CHECKUSER_PORT}${RESET}"

    elif checkuser_installed; then
        echo -e "${YELLOW}🟡 INSTALADO / OFF${RESET}"

    else
        echo -e "${RED}🔴 NO INSTALADO${RESET}"
    fi
}

#==================================================
# ESTADO ONLINE APP
#==================================================

status_online() {

    if systemctl is-active --quiet kevintech-onlineapp 2>/dev/null; then
        echo -e "${GREEN}🟢 ACTIVO : ${ONLINE_PORT}${RESET}"

    elif online_installed; then
        echo -e "${YELLOW}🟡 INSTALADO / OFF${RESET}"

    else
        echo -e "${RED}🔴 NO INSTALADO${RESET}"
    fi
}

#==================================================
# COMPROBAR PUERTO
#==================================================

port_in_use() {

    local PORT="$1"

    ss -lntp 2>/dev/null |
        awk -v p=":$PORT" '$4 ~ p"$" {print}'
}

#==================================================
# INSTALAR DEPENDENCIAS
#==================================================

install_dependencies() {

    msg_info "Instalando dependencias..."

    apt update -y >/dev/null 2>&1

    apt install -y \
        python3 \
        python3-flask \
        python3-werkzeug \
        python3-itsdangerous \
        python3-asgiref \
        python3-simplejson \
        apache2 \
        screen \
        curl \
        wget \
        jq >/dev/null 2>&1

    if ! command -v python3 >/dev/null 2>&1; then
        msg_error "Python3 no está disponible."
        return 1
    fi

    if ! python3 -c "import flask" >/dev/null 2>&1; then
        msg_error "Flask no está disponible."
        return 1
    fi

    msg_ok "Dependencias instaladas."
}

#==================================================
# INSTALAR CHECKUSER
#==================================================

install_checkuser() {

    clear

    line
    echo -e "${MAGENTA}          INSTALANDO CHECKUSER${RESET}"
    line

    # IMPORTANTE:
    # 10015 NO SE TOCA.
    # Está reservado para SSH WebSocket.

    if [[ -n "$(port_in_use "$CHECKUSER_PORT")" ]]; then

        msg_error "El puerto $CHECKUSER_PORT ya está ocupado."

        port_in_use "$CHECKUSER_PORT"

        pause
        return 1
    fi

    install_dependencies || {
        pause
        return 1
    }

    mkdir -p "$CHECKUSER_DIR"

    #----------------------------------------------
    # CHECKGESTOR
    #----------------------------------------------

    msg_info "Instalando checkgestor..."

    cat > "$CHECKUSER_CMD" <<'EOF'
#!/bin/bash

USER_NAME="$1"
TYPE="$2"

DATABASE="/tmp/checkdb"

if [[ -f /root/usuarios.db ]]; then
    uniq /root/usuarios.db > "$DATABASE"
else
    : > "$DATABASE"
fi

user_exist() {

    if getent passwd "$USER_NAME" >/dev/null 2>&1; then
        echo "$USER_NAME"
    else
        echo "Not exist"
    fi
}

cont_online() {

    local limit

    limit="$(grep -w "$USER_NAME" "$DATABASE" 2>/dev/null | awk '{print $2}')"

    [[ -z "$limit" ]] && limit="1"

    local conssh

    conssh="$(ps -u "$USER_NAME" 2>/dev/null | grep sshd | wc -l)"

    if [[ "$conssh" -gt "$limit" ]]; then
        pkill -u "$USER_NAME" 2>/dev/null
    fi

    echo "$conssh"
}

limiter_user() {

    local limit

    limit="$(grep -w "$USER_NAME" "$DATABASE" 2>/dev/null | awk '{print $2}')"

    [[ -z "$limit" ]] && limit="1"

    echo "$limit"
}

check_data() {

    if ! getent passwd "$USER_NAME" >/dev/null 2>&1; then
        echo "Not exist"
        return
    fi

    local datauser

    datauser="$(chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{print $2}' |
        xargs)"

    if [[ -z "$datauser" || "$datauser" == "never" ]]; then
        echo "31/12/2099"
        return
    fi

    date -d "$datauser" '+%d/%m/%Y' 2>/dev/null
}

check_dias() {

    if ! getent passwd "$USER_NAME" >/dev/null 2>&1; then
        echo "0"
        return
    fi

    local datauser

    datauser="$(chage -l "$USER_NAME" 2>/dev/null |
        grep -i 'Account expires' |
        awk -F: '{print $2}' |
        xargs)"

    if [[ -z "$datauser" || "$datauser" == "never" ]]; then
        echo "99999"
        return
    fi

    local expiry

    expiry="$(date -d "$datauser" '+%Y-%m-%d' 2>/dev/null)"

    if [[ -z "$expiry" ]]; then
        echo "0"
        return
    fi

    echo "$(((
        $(date -ud "$expiry" +%s) -
        $(date -ud "$(date +%Y-%m-%d)" +%s)
    ) / 86400))"
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

    *)
        echo "Not exist"
        ;;

esac
EOF

    chmod 755 "$CHECKUSER_CMD"

    #----------------------------------------------
    # CHECKUSER PYTHON
    #----------------------------------------------

    msg_info "Instalando API CheckUser..."

    cat > "$CHECKUSER_PY" <<'PYEOF'
#!/usr/bin/python3

import os
import sys
from datetime import datetime

from flask import Flask, jsonify, request

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 10016

app = Flask(__name__)


def run_command(username, action):

    try:

        command = f"/bin/checkgestor '{username}' {action}"

        result = os.popen(command).readlines()

        if not result:
            return None

        return result[0].strip()

    except Exception:

        return None


def user_usuario(username):
    return run_command(username, 1)


def user_conectados(username):
    return run_command(username, 2)


def user_limite(username):
    return run_command(username, 3)


def user_data(username):
    return run_command(username, 4)


def user_dias_restantes(username):
    return run_command(username, 5)


def format_date_for_anymod(date_string):

    try:

        date = datetime.strptime(
            date_string,
            "%d/%m/%Y"
        )

        return date.strftime("%Y-%m-%d-")

    except Exception:

        return ""


#==================================================
# CONECTA4G
#==================================================

@app.route(
    "/checkUser",
    methods=["POST", "GET"]
)
def c4g():

    if request.method == "GET":

        return (
            "Por favor, use o metodo de "
            "requisição correto !\n\n"
            "Checkuser CONECTA4G"
        )

    try:

        req_data = request.get_json(
            silent=True
        ) or {}

        requested_user = req_data.get("user")

        if not requested_user:

            return jsonify({
                "error": "user is required"
            }), 400

        username = user_usuario(
            requested_user
        )

        if username == "Not exist":

            return jsonify({

                "username": "Not exist",
                "count_connection": None,
                "expiration_date": None,
                "expiration_days": None,
                "limiter_user": None

            })

        return jsonify({

            "username": username,

            "count_connection":
                user_conectados(username),

            "expiration_date":
                user_data(username),

            "expiration_days":
                user_dias_restantes(username),

            "limiter_user":
                user_limite(username)

        })

    except Exception as e:

        return jsonify({
            "error": str(e)
        }), 500


#==================================================
# GLTUNNEL
#==================================================

@app.route(
    "/gl/check/<username>",
    methods=["GET", "POST"]
)
def gl(username):

    if request.method == "POST":

        return (
            "Por favor, use o método de "
            "requisição correto!\n\n"
            "Checkuser GL"
        )

    try:

        user = user_usuario(username)

        if user == "Not exist":

            return jsonify({

                "username": "Not exist",
                "count_connection": None,
                "expiration_date": None,
                "expiration_days": None,
                "limit_connection": None

            })

        return jsonify({

            "username": user,

            "count_connection":
                user_conectados(user),

            "expiration_date":
                user_data(user),

            "expiration_days":
                user_dias_restantes(user),

            "limit_connection":
                user_limite(user)

        })

    except Exception as e:

        return jsonify({
            "error": str(e)
        }), 500


#==================================================
# ANYMOD
#==================================================

@app.route(
    "/anymod",
    methods=["POST", "GET"]
)
def anymod():

    if request.method == "GET":

        return (
            "Por favor, use o método de "
            "requisição correto!\n\n"
            "Checkuser ANY VPN MOD"
        )

    try:

        data = request.form

        username = data.get(
            "username"
        )

        deviceid = data.get(
            "deviceid"
        )

        user = user_usuario(username)

        if user == "Not exist":

            return jsonify({

                "USER_ID": username,
                "DEVICE": deviceid,
                "is_active": "false",
                "Status": "naoencontrado",
                "uuid": "null"

            })

        online = int(
            user_conectados(user) or 0
        )

        limite = int(
            user_limite(user) or 1
        )

        active = online <= limite

        return jsonify({

            "USER_ID": username,

            "DEVICE":
                deviceid if active else "false",

            "is_active":
                "true" if active else "false",

            "expiration_date":
                format_date_for_anymod(
                    user_data(user)
                ),

            "expiry":
                f"{user_dias_restantes(user)} dias.",

            "uuid": "null"

        })

    except Exception as e:

        return jsonify({
            "error": str(e)
        }), 500


if __name__ == "__main__":

    app.run(
        host="127.0.0.1",
        port=PORT,
        debug=False
    )
PYEOF

    chmod 755 "$CHECKUSER_PY"

    #----------------------------------------------
    # SERVICIO CHECKUSER
    #----------------------------------------------

    cat > "$CHECKUSER_SERVICE" <<EOF
[Unit]
Description=KevinTech CheckUser API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/
ExecStart=/usr/bin/python3 $CHECKUSER_PY $CHECKUSER_PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable checkuser >/dev/null 2>&1

    systemctl restart checkuser

    sleep 2

    if systemctl is-active --quiet checkuser; then

        msg_ok "CheckUser instalado correctamente."
        msg_ok "API local: 127.0.0.1:$CHECKUSER_PORT"

    else

        msg_error "CheckUser no pudo iniciar."

        systemctl status checkuser --no-pager

        pause
        return 1
    fi
}

#==================================================
# INSTALAR ONLINE APP
#==================================================

install_onlineapp() {

    clear

    line
    echo -e "${MAGENTA}          INSTALANDO ONLINE APP${RESET}"
    line

    if [[ -n "$(port_in_use "$ONLINE_PORT")" ]]; then

        msg_error "El puerto $ONLINE_PORT ya está ocupado."

        port_in_use "$ONLINE_PORT"

        pause
        return 1
    fi

    apt install -y apache2 screen >/dev/null 2>&1

    mkdir -p "$ONLINE_DIR"

    #----------------------------------------------
    # CONFIGURAR APACHE EN 8888
    #----------------------------------------------

    if [[ -f /etc/apache2/ports.conf ]]; then

        sed -i \
            's/^Listen 80$/#Listen 80/' \
            /etc/apache2/ports.conf

        grep -q "^Listen $ONLINE_PORT$" \
            /etc/apache2/ports.conf ||
            echo "Listen $ONLINE_PORT" >> \
            /etc/apache2/ports.conf
    fi

    # VirtualHost
    cat > /etc/apache2/sites-available/kevintech-onlineapp.conf <<EOF
<VirtualHost *:$ONLINE_PORT>

    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

</VirtualHost>
EOF

    a2dissite 000-default.conf >/dev/null 2>&1
    a2ensite kevintech-onlineapp.conf >/dev/null 2>&1

    #----------------------------------------------
    # ONLINE APP
    #----------------------------------------------

    if [[ ! -f "$ONLINE_APP" ]]; then

        cat > "$ONLINE_APP" <<'EOF'
#!/bin/bash

while true; do

    clear

    echo "========================================"
    echo "       KEVINTECH ONLINE APP"
    echo "========================================"
    echo
    echo "Usuarios SSH conectados:"
    echo

    USERS="$(who | awk '{print $1}' | sort -u)"

    if [[ -z "$USERS" ]]; then
        echo "Ningún usuario conectado."
    else
        echo "$USERS"
    fi

    echo
    sleep 10

done
EOF

    fi

    chmod +x "$ONLINE_APP"

    #----------------------------------------------
    # SERVICIO ONLINE APP
    #----------------------------------------------

    cat > "$ONLINE_SERVICE" <<EOF
[Unit]
Description=KevinTech Online App
After=network.target apache2.service

[Service]
Type=simple
User=root
ExecStart=$ONLINE_APP
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable apache2 >/dev/null 2>&1
    systemctl restart apache2

    systemctl enable kevintech-onlineapp >/dev/null 2>&1
    systemctl restart kevintech-onlineapp

    sleep 2

    if systemctl is-active --quiet apache2 &&
       systemctl is-active --quiet kevintech-onlineapp; then

        msg_ok "Online App instalado correctamente."
        msg_ok "Puerto Apache: $ONLINE_PORT"

    else

        msg_error "Online App no pudo iniciar."

        systemctl status apache2 --no-pager
        systemctl status kevintech-onlineapp --no-pager

        pause
        return 1
    fi
}

#==================================================
# INSTALAR TODO
#==================================================

install_all() {

    clear

    line
    echo -e "${MAGENTA}        INSTALACIÓN KEVINTECH${RESET}"
    line

    echo
    msg_info "10015 está reservado para SSH/WebSocket."
    msg_info "CheckUser utilizará $CHECKUSER_PORT."
    msg_info "Online App utilizará $ONLINE_PORT."
    echo

    install_checkuser || return 1

    echo

    install_onlineapp || return 1

    echo
    line
    msg_ok "INSTALACIÓN COMPLETA."
    line

    echo
    echo -e "${WHITE}CheckUser : ${GREEN}127.0.0.1:$CHECKUSER_PORT${RESET}"
    echo -e "${WHITE}Online App: ${GREEN}:$ONLINE_PORT${RESET}"

    echo
    pause
}

#==================================================
# DESINSTALAR CHECKUSER
#==================================================

remove_checkuser() {

    msg_info "Deteniendo CheckUser..."

    systemctl disable --now checkuser >/dev/null 2>&1

    rm -f "$CHECKUSER_SERVICE"

    systemctl daemon-reload

    rm -f "$CHECKUSER_CMD"
    rm -f "$CHECKUSER_MANAGER"

    rm -rf "$CHECKUSER_DIR"

    rm -rf /etc/licencec

    msg_ok "CheckUser eliminado."
}

#==================================================
# DESINSTALAR ONLINE APP
#==================================================

remove_onlineapp() {

    msg_info "Deteniendo Online App..."

    systemctl disable --now kevintech-onlineapp \
        >/dev/null 2>&1

    rm -f "$ONLINE_SERVICE"

    systemctl daemon-reload

    #----------------------------------------------
    # APACHE
    #----------------------------------------------

    a2dissite kevintech-onlineapp.conf \
        >/dev/null 2>&1

    rm -f \
        /etc/apache2/sites-available/kevintech-onlineapp.conf

    # Volver a 80 si no existe otro Listen 80
    sed -i \
        's/^#Listen 80$/Listen 80/' \
        /etc/apache2/ports.conf

    sed -i \
        "/^Listen $ONLINE_PORT$/d" \
        /etc/apache2/ports.conf

    systemctl restart apache2 >/dev/null 2>&1

    #----------------------------------------------
    # ARCHIVOS ONLINE APP
    #----------------------------------------------

    rm -f "$ONLINE_APP"

    rm -rf /var/www/html/server

    #----------------------------------------------
    # LIMPIAR SCREEN
    #----------------------------------------------

    screen -S onlineapp -X quit \
        >/dev/null 2>&1

    screen -wipe >/dev/null 2>&1

    msg_ok "Online App eliminado."
}

#==================================================
# DESINSTALAR TODO
#==================================================

remove_all() {

    clear

    line
    echo -e "${RED}       DESINSTALANDO KEVINTECH CHECKUSER${RESET}"
    line

    remove_checkuser

    echo

    remove_onlineapp

    echo

    # NO TOCAR 10015
    msg_info "Puerto 10015 no fue modificado."

    echo

    line
    msg_ok "DESINSTALACIÓN COMPLETA."
    line

    echo
    pause
}

#==================================================
# ONLINE APP MANUAL
#==================================================

toggle_onlineapp() {

    if systemctl is-active --quiet kevintech-onlineapp; then

        systemctl stop kevintech-onlineapp

        msg_ok "Online App detenido."

    else

        if [[ ! -f "$ONLINE_APP" ]]; then

            msg_warn "Online App no está instalado."
            install_onlineapp

            return
        fi

        systemctl start kevintech-onlineapp

        if systemctl is-active --quiet \
            kevintech-onlineapp; then

            msg_ok "Online App iniciado."

        else

            msg_error "No pudo iniciar."
        fi
    fi

    sleep 2
}

#==================================================
# MENÚ
#==================================================

while true; do

    clear

    CHECK_STATUS="$(status_checkuser)"
    ONLINE_STATUS="$(status_online)"

    line

    echo -e "${MAGENTA}           🛡 KEVINTECH MULTI SCRIPT${RESET}"
    echo -e "${WHITE}              CHECKUSER PREMIUM${RESET}"

    line

    echo -e " ${GREEN}[01]${RESET} 📦 Instalar CheckUser + Online App"
    echo -e " ${RED}[02]${RESET} 🗑️  Desinstalar todo"
    echo -e " ${CYAN}[03]${RESET} 🌐 Online App ON/OFF"

    echo

    echo -e " ${WHITE}CheckUser : ${RESET}$CHECK_STATUS"
    echo -e " ${WHITE}Online App: ${RESET}$ONLINE_STATUS"

    echo

    echo -e "${GRAY}CheckUser : puerto interno $CHECKUSER_PORT${RESET}"
    echo -e "${GRAY}Online App: puerto $ONLINE_PORT${RESET}"
    echo -e "${GRAY}SSH/WS    : puerto 10015 NO SE TOCA${RESET}"

    line

    echo -e " ${GREEN}[00]${RESET} ↩ Regresar"

    line

    echo

    read -rp " ► Opción: " OP

    case "$OP" in

        1|01)

            if checkuser_installed &&
               online_installed; then

                msg_warn "Ya está instalado."
                pause

            else

                install_all

            fi

        ;;

        2|02)

            remove_all

        ;;

        3|03)

            toggle_onlineapp

        ;;

        0|00)

            exec bash "$BASE/protocolos/menu.sh"

        ;;

        *)

            msg_error "Opción inválida."
            sleep 2

        ;;

    esac

done