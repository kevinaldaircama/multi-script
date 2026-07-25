#!/bin/bash

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           KEVINTECH MULTI SCRIPT             #
#               ZIVPN INSTALLER                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="zivpn"

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

error() {
    echo -e "${RED}✘ $1${RESET}"
}

info() {
    echo -e "${CYAN}➜ $1${RESET}"
}

pause() {
    echo
    read -n1 -r -p "Presione una tecla para continuar..."
}

install_zivpn() {

    clear
    line
    echo -e "${WHITE}          INSTALAR ZIVPN${RESET}"
    line
    echo

    read -rp "Puerto UDP: " PORT

    [[ ! "$PORT" =~ ^[0-9]+$ ]] && {
        error "Puerto inválido."
        pause
        return
    }

    ((PORT<1 || PORT>65535)) && {
        error "Puerto fuera de rango."
        pause
        return
    }

    if ss -lun | awk '{print $5}' | grep -q ":$PORT$"; then
        error "El puerto ya está en uso."
        pause
        return
    fi

    info "Actualizando repositorios..."
    apt-get update

    info "Instalando dependencias..."
    apt-get install -y \
        curl \
        openssl \
        iptables \
        libc6-i386

    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || \
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    ARCH=$(uname -m)

    case "$ARCH" in

        x86_64)
            BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"
        ;;

        aarch64|arm64)
            BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"
        ;;

        *)
            error "Arquitectura no soportada: $ARCH"
            pause
            return
        ;;

    esac

    mkdir -p /etc/zivpn

    info "Descargando ZiVPN..."

    curl -L -o /usr/local/bin/zivpn "$BIN_URL"

    chmod +x /usr/local/bin/zivpn

    info "Generando certificados..."

    openssl req \
        -new \
        -newkey rsa:4096 \
        -nodes \
        -x509 \
        -days 3650 \
        -subj "/C=US/ST=CA/L=LA/O=ZiVPN/CN=zivpn" \
        -keyout /etc/zivpn/zivpn.key \
        -out /etc/zivpn/zivpn.crt

cat >/etc/zivpn/config.json <<EOF
{
    "listen": ":$PORT",
    "cert": "/etc/zivpn/zivpn.crt",
    "key": "/etc/zivpn/zivpn.key",
    "max_conn": 0,
    "auth": {
        "mode": "passwords",
        "config": [
            "1"
        ]
    }
}
EOF

cat >/etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZiVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable zivpn
    systemctl restart zivpn

    sleep 2

    if systemctl is-active --quiet zivpn; then

        if grep -q "^ZIPVPN=" "$CONFIG"; then
            sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG"
        else
            echo "ZIPVPN=ON" >> "$CONFIG"
        fi

        if grep -q "^ZIPVPN_PORT=" "$CONFIG"; then
            sed -i "s/^ZIPVPN_PORT=.*/ZIPVPN_PORT=\"$PORT\"/" "$CONFIG"
        else
            echo "ZIPVPN_PORT=\"$PORT\"" >> "$CONFIG"
        fi

        source "$CONFIG"

        line
        ok "ZiVPN instalado correctamente."
        echo
        echo "Servicio : zivpn"
        echo "Puerto   : $PORT"
        echo "Config   : /etc/zivpn/config.json"
        line

    else

        error "ZiVPN no pudo iniciar."

        journalctl -u zivpn --no-pager -n 20

    fi

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           CONFIGURAR IPTABLES                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

configure_zivpn_firewall() {

    local PORT="$1"

    info "Detectando interfaz de red..."

    DEV=$(ip -4 route show default | awk '{print $5}' | head -n1)

    [[ -z "$DEV" ]] && \
    DEV=$(ip link show up | awk -F': ' '/state UP/ && $2!="lo"{print $2;exit}')

    [[ -z "$DEV" ]] && {
        error "No se pudo detectar la interfaz de red."
        return 1
    }

    info "Interfaz detectada: $DEV"

    info "Limpiando reglas anteriores..."

    iptables -t nat -S PREROUTING | grep "6000:19999" | \
    sed 's/^-A /-D /' | while read -r RULE; do
        iptables -t nat $RULE
    done

    iptables -S INPUT | grep "6000:19999" | \
    sed 's/^-A /-D /' | while read -r RULE; do
        iptables $RULE
    done

    iptables -S INPUT | grep -w "$PORT" | \
    sed 's/^-A /-D /' | while read -r RULE; do
        iptables $RULE
    done

    iptables -t nat -D POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null

    info "Aplicando reglas..."

    iptables -t nat -I PREROUTING 1 \
        -i "$DEV" \
        -p udp \
        --dport 6000:19999 \
        -j REDIRECT \
        --to-port "$PORT"

    iptables -I INPUT 1 \
        -p udp \
        --dport "$PORT" \
        -j ACCEPT

    iptables -I INPUT 1 \
        -p udp \
        --dport 6000:19999 \
        -j ACCEPT

    iptables -t nat -A POSTROUTING \
        -o "$DEV" \
        -j MASQUERADE

    ok "Firewall configurado."

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            REINICIAR SERVICIO                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

restart_zivpn() {

    systemctl restart zivpn

    if systemctl is-active --quiet zivpn; then
        ok "ZiVPN reiniciado correctamente."
    else
        error "No fue posible reiniciar ZiVPN."
    fi

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#               ESTADO DEL SERVICIO            #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

status_zivpn() {

    clear

    line
    echo -e "${WHITE}            ESTADO ZIVPN${RESET}"
    line

    if systemctl is-active --quiet zivpn; then
        echo -e "Estado    : ${GREEN}ACTIVO${RESET}"
    else
        echo -e "Estado    : ${RED}DETENIDO${RESET}"
    fi

    PORT=$(grep '"listen"' /etc/zivpn/config.json 2>/dev/null | \
        grep -o '[0-9]\+')

    echo "Puerto    : ${PORT:-Desconocido}"
    echo "Servicio  : zivpn"

    echo
    systemctl status zivpn --no-pager -l

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             DESINSTALAR ZIVPN                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

remove_zivpn() {

    clear
    line
    echo -e "${WHITE}          DESINSTALAR ZIVPN${RESET}"
    line
    echo

    read -rp "¿Desea continuar? [s/N]: " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    PORT=$(grep '"listen"' /etc/zivpn/config.json 2>/dev/null | \
        grep -o '[0-9]\+')

    DEV=$(ip -4 route show default | awk '{print $5}' | head -n1)

    systemctl stop zivpn 2>/dev/null
    systemctl disable zivpn 2>/dev/null

    rm -f /etc/systemd/system/zivpn.service

    rm -rf /etc/zivpn

    rm -f /usr/local/bin/zivpn

    if [[ -n "$DEV" ]]; then

        iptables -t nat -S PREROUTING | grep "6000:19999" | \
        sed 's/^-A /-D /' | while read -r RULE; do
            iptables -t nat $RULE
        done

        iptables -S INPUT | grep "6000:19999" | \
        sed 's/^-A /-D /' | while read -r RULE; do
            iptables $RULE
        done

        [[ -n "$PORT" ]] && \
        iptables -S INPUT | grep -w "$PORT" | \
        sed 's/^-A /-D /' | while read -r RULE; do
            iptables $RULE
        done

        iptables -t nat -D POSTROUTING \
            -o "$DEV" \
            -j MASQUERADE 2>/dev/null

    fi

    systemctl daemon-reload
    systemctl reset-failed

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=OFF/' "$CONFIG"
    else
        echo "ZIPVPN=OFF" >> "$CONFIG"
    fi

    sed -i '/^ZIPVPN_PORT=/d' "$CONFIG"

    source "$CONFIG"

    ok "ZiVPN eliminado correctamente."

    pause
}
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            AGREGAR CONTRASEÑA                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

add_zivpn_password() {

    clear
    line
    echo -e "${WHITE}        AGREGAR CONTRASEÑA${RESET}"
    line
    echo

    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }

    read -rp "Nueva contraseña: " PASS

    [[ -z "$PASS" ]] && {
        error "Debe ingresar una contraseña."
        pause
        return
    }

    if grep -q "\"$PASS\"" /etc/zivpn/config.json; then
        error "La contraseña ya existe."
        pause
        return
    fi

    TMP=$(mktemp)

    jq --arg pass "$PASS" \
    '.auth.config += [$pass]' \
    /etc/zivpn/config.json > "$TMP"

    mv "$TMP" /etc/zivpn/config.json

    systemctl restart zivpn

    ok "Contraseña agregada."

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           ELIMINAR CONTRASEÑA                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

remove_zivpn_password() {

    clear
    line
    echo -e "${WHITE}       ELIMINAR CONTRASEÑA${RESET}"
    line
    echo

    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }

    mapfile -t PASSLIST < <(
        jq -r '.auth.config[]' /etc/zivpn/config.json
    )

    [[ ${#PASSLIST[@]} -eq 0 ]] && {
        error "No existen contraseñas."
        pause
        return
    }

    echo

    for ((i=0;i<${#PASSLIST[@]};i++)); do
        printf " [%02d] %s\n" "$((i+1))" "${PASSLIST[$i]}"
    done

    echo

    read -rp "Seleccione: " OP

    [[ ! "$OP" =~ ^[0-9]+$ ]] && {
        pause
        return
    }

    INDEX=$((OP-1))

    [[ $INDEX -lt 0 || $INDEX -ge ${#PASSLIST[@]} ]] && {
        error "Opción inválida."
        pause
        return
    }

    PASS="${PASSLIST[$INDEX]}"

    TMP=$(mktemp)

    jq --arg pass "$PASS" \
    '.auth.config |= map(select(. != $pass))' \
    /etc/zivpn/config.json > "$TMP"

    mv "$TMP" /etc/zivpn/config.json

    systemctl restart zivpn

    ok "Contraseña eliminada."

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#          LISTAR CONTRASEÑAS                  #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

list_zivpn_passwords() {

    clear

    line
    echo -e "${WHITE}      CONTRASEÑAS ZIVPN${RESET}"
    line
    echo

    [[ ! -f /etc/zivpn/config.json ]] && {
        error "ZiVPN no está instalado."
        pause
        return
    }

    jq -r '.auth.config[]' /etc/zivpn/config.json | nl

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             CAMBIAR PUERTO                   #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

change_zivpn_port() {

    clear

    line
    echo -e "${WHITE}         CAMBIAR PUERTO${RESET}"
    line
    echo

    CURRENT=$(jq -r '.listen' /etc/zivpn/config.json | tr -d ':')

    echo "Puerto actual : $CURRENT"
    echo

    read -rp "Nuevo puerto: " PORT

    [[ ! "$PORT" =~ ^[0-9]+$ ]] && {
        error "Puerto inválido."
        pause
        return
    }

    ((PORT<1 || PORT>65535)) && {
        error "Puerto fuera de rango."
        pause
        return
    }

    if ss -lun | awk '{print $5}' | grep -q ":$PORT$"; then
        error "Puerto ocupado."
        pause
        return
    fi

    TMP=$(mktemp)

    jq --arg p ":$PORT" \
    '.listen=$p' \
    /etc/zivpn/config.json > "$TMP"

    mv "$TMP" /etc/zivpn/config.json

    systemctl restart zivpn

    configure_zivpn_firewall "$PORT"

    sed -i "s/^ZIPVPN_PORT=.*/ZIPVPN_PORT=\"$PORT\"/" "$CONFIG"

    source "$CONFIG"

    ok "Puerto actualizado."

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#              VER LOGS                        #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

view_zivpn_logs() {

    clear

    line
    echo -e "${WHITE}            LOGS ZIVPN${RESET}"
    line
    echo

    journalctl -u zivpn --no-pager -n 50

    pause
}
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#              DIAGNÓSTICO ZIVPN               #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

check_zivpn() {

    clear

    line
    echo -e "${WHITE}        DIAGNÓSTICO ZIVPN${RESET}"
    line
    echo

    if command -v /usr/local/bin/zivpn >/dev/null 2>&1; then
        ok "Binario encontrado"
    else
        error "Binario inexistente"
    fi

    if [[ -f /etc/zivpn/config.json ]]; then
        ok "Config.json encontrado"
    else
        error "Config.json inexistente"
    fi

    if [[ -f /etc/zivpn/zivpn.crt ]]; then
        ok "Certificado SSL encontrado"
    else
        error "Certificado inexistente"
    fi

    if [[ -f /etc/zivpn/zivpn.key ]]; then
        ok "Llave privada encontrada"
    else
        error "Llave privada inexistente"
    fi

    if systemctl is-active --quiet zivpn; then
        ok "Servicio activo"
    else
        error "Servicio detenido"
    fi

    echo
    info "Puertos UDP"

    ss -lunp | grep zivpn

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           INFORMACIÓN DEL SERVIDOR           #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

system_info() {

    clear

    line
    echo -e "${WHITE}     INFORMACIÓN DEL SERVIDOR${RESET}"
    line
    echo

    echo "Hostname : $(hostname)"
    echo "Kernel   : $(uname -r)"
    echo "Sistema  : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"

    echo
    echo "IP"

    hostname -I

    echo
    echo "Memoria"

    free -h

    echo
    echo "Disco"

    df -h /

    pause
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#                   MENÚ                       #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

while true; do

    clear

    if systemctl is-active --quiet zivpn; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 OFF${RESET}"
    fi

    if [[ -f /etc/zivpn/config.json ]]; then
        PORT=$(grep '"listen"' /etc/zivpn/config.json | grep -o '[0-9]\+')
    else
        PORT="-"
    fi

    line
    echo -e "${WHITE}           🚀 ZIVPN MANAGER${RESET}"
    line

    echo -e " Estado     : $STATUS"
    echo -e " Servicio   : zivpn"
    echo -e " Puerto     : $PORT"
    echo -e " Instalado  : ${ZIPVPN:-OFF}"

    line

    if [[ "$ZIPVPN" == "ON" ]]; then

cat <<EOF
 [1] Reinstalar ZiVPN
 [2] Cambiar Puerto
 [3] Reiniciar Servicio
 [4] Estado del Servicio
 [5] Agregar Contraseña
 [6] Eliminar Contraseña
 [7] Listar Contraseñas
 [8] Ver Logs
 [9] Diagnóstico
 [10] Información del Servidor
 [11] Desinstalar ZiVPN
 [0] Regresar
EOF

    else

cat <<EOF
 [1] Instalar ZiVPN
 [0] Regresar
EOF

    fi

    line

    read -rp " ► Opción: " OP

    case "$OP" in

        1)
            install_zivpn
        ;;

        2)
            change_zivpn_port
        ;;

        3)
            restart_zivpn
        ;;

        4)
            status_zivpn
        ;;

        5)
            add_zivpn_password
        ;;

        6)
            remove_zivpn_password
        ;;

        7)
            list_zivpn_passwords
        ;;

        8)
            view_zivpn_logs
        ;;

        9)
            check_zivpn
        ;;

        10)
            system_info
        ;;

        11)
            remove_zivpn
        ;;

        0)
            exec bash "$BASE/protocolos/menu.sh"
        ;;

        *)
            error "Opción inválida."
            sleep 2
        ;;

    esac

done
