#!/bin/bash

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#           KEVINTECH MULTI SCRIPT             #
#             DROPBEAR MANAGER                 #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ ! -f "$CONFIG" ]] && {
    echo "No se encontró el archivo de configuración."
    exit 1
}

source "$CONFIG"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#                  COLORES                     #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

SERVICE="dropbear_custom"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#                  FUNCIONES                   #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

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
    echo ""
    read -n1 -r -p "Presione una tecla para continuar..."
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             OBTENER INFORMACIÓN              #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

get_status() {

    if systemctl is-active --quiet "$SERVICE"; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

}

get_ports() {

    PORTS=$(systemctl cat "$SERVICE" 2>/dev/null | \
        grep ExecStart | \
        grep -oP '(?<=-p )\d+' | \
        paste -sd "," -)

    [[ -z "$PORTS" ]] && PORTS="-"

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             INSTALAR DROPBEAR                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

install_dropbear() {

    clear
    line
    echo -e "${WHITE}        INSTALAR DROPBEAR${RESET}"
    line

    # Puertos predeterminados
    PORTS="90,143,109"

    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"

    for PORT in "${PORT_ARRAY[@]}"; do

        if ss -lnt | awk '{print $4}' | grep -q ":$PORT$"; then
            error "El puerto $PORT ya está en uso."
            pause
            return
        fi

    done

    info "Actualizando repositorios..."
    apt-get update

    info "Instalando Dropbear..."
    apt-get install -y dropbear

    mkdir -p /etc/dropbear

    if [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        info "Generando llave RSA..."
        dropbearkey -t rsa \
            -f /etc/dropbear/dropbear_rsa_host_key
    fi

    if [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]]; then
        info "Generando llave ECDSA..."
        dropbearkey -t ecdsa \
            -f /etc/dropbear/dropbear_ecdsa_host_key
    fi

   

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    EXEC="/usr/sbin/dropbear -F"

    for PORT in "${PORT_ARRAY[@]}"; do
        EXEC="$EXEC -p $PORT"
    done

    EXEC="$EXEC -W 65536 -b /etc/issue.net"

cat > /etc/systemd/system/dropbear_custom.service <<EOF
[Unit]
Description=KevinTech Dropbear Multi-Port
After=network.target

[Service]
Type=simple
ExecStart=$EXEC
Restart=always
RestartSec=3
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dropbear_custom
    systemctl restart dropbear_custom

    if systemctl is-active --quiet dropbear_custom; then

        if grep -q "^DROPBEAR=" "$CONFIG"; then
            sed -i 's/^DROPBEAR=.*/DROPBEAR=ON/' "$CONFIG"
        else
            echo "DROPBEAR=ON" >> "$CONFIG"
        fi

        if grep -q "^DROPBEAR_PORT=" "$CONFIG"; then
            sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$PORTS\"/" "$CONFIG"
        else
            echo "DROPBEAR_PORT=\"$PORTS\"" >> "$CONFIG"
        fi

        source "$CONFIG"

        line
        ok "Dropbear instalado correctamente."
        echo ""
        echo " Servicio : dropbear_custom"
        echo " Puertos  : $PORTS"
        echo " Banner   : $BANNER"
        line

    else

        error "No fue posible iniciar Dropbear."

    fi

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            REINICIAR SERVICIO                #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

restart_dropbear() {

    systemctl restart dropbear_custom

    if systemctl is-active --quiet dropbear_custom; then
        ok "Servicio reiniciado correctamente."
    else
        error "No fue posible reiniciar el servicio."
    fi

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#             INFORMACIÓN COMPLETA             #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

status_dropbear() {

    clear

    get_status
    get_ports

    line
    echo -e "${WHITE}          ESTADO DROPBEAR${RESET}"
    line

    echo "Estado      : $STATUS"
    echo "Servicio    : dropbear_custom"
    echo "Puertos     : $PORTS"
    echo "Banner      : /etc/issue.net"

    echo ""

    echo "Proceso"

    systemctl status dropbear_custom --no-pager -l

    pause

}
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#            DESINSTALAR DROPBEAR              #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

remove_dropbear() {

    clear
    line
    echo -e "${WHITE}       DESINSTALAR DROPBEAR${RESET}"
    line
    echo ""

    read -rp "¿Desea continuar? [s/N]: " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    info "Deteniendo servicios..."

    systemctl stop dropbear_custom 2>/dev/null
    systemctl disable dropbear_custom 2>/dev/null

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    info "Eliminando servicio personalizado..."

    rm -f /etc/systemd/system/dropbear_custom.service

    systemctl daemon-reload
    systemctl reset-failed

    info "Desinstalando paquete..."

    apt-get purge -y dropbear

    apt-get autoremove -y

    info "Limpiando archivos..."

    rm -rf /etc/dropbear
    

    if grep -q "^DROPBEAR=" "$CONFIG"; then
        sed -i 's/^DROPBEAR=.*/DROPBEAR=OFF/' "$CONFIG"
    else
        echo "DROPBEAR=OFF" >> "$CONFIG"
    fi

    sed -i '/^DROPBEAR_PORT=/d' "$CONFIG"

    source "$CONFIG"

    line
    ok "Dropbear fue eliminado correctamente."
    line

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#          VERIFICAR CONFIGURACIÓN             #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

check_dropbear() {

    clear

    line
    echo -e "${WHITE}      DIAGNÓSTICO DROPBEAR${RESET}"
    line

    echo ""

    if command -v dropbear >/dev/null 2>&1; then
        ok "Dropbear instalado"
    else
        error "Dropbear no instalado"
    fi

    if systemctl is-active --quiet dropbear_custom; then
        ok "Servicio activo"
    else
        error "Servicio detenido"
    fi

    if [[ -f /etc/systemd/system/dropbear_custom.service ]]; then
        ok "Servicio personalizado encontrado"
    else
        error "Servicio personalizado no existe"
    fi

    if [[ -f /etc/dropbear/dropbear_rsa_host_key ]]; then
        ok "Llave RSA encontrada"
    else
        error "Llave RSA inexistente"
    fi

    if [[ -f /etc/dropbear/dropbear_ecdsa_host_key ]]; then
        ok "Llave ECDSA encontrada"
    else
        error "Llave ECDSA inexistente"
    fi

    if [[ -f /etc/issue.net ]]; then
        ok "Banner encontrado"
    else
        error "Banner inexistente"
    fi

    echo ""
    info "Puertos escuchando"

    ss -lntp | grep dropbear

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#          VER INFORMACIÓN DEL SISTEMA         #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

system_info() {

    clear

    line
    echo -e "${WHITE}        INFORMACIÓN DEL SERVIDOR${RESET}"
    line

    echo ""

    echo "Hostname : $(hostname)"
    echo "Kernel   : $(uname -r)"
    echo "Sistema  : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"

    echo ""

    echo "IP Local"

    hostname -I

    echo ""

    echo "Uso de memoria"

    free -h

    echo ""

    echo "Espacio en disco"

    df -h /

    pause

}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#                  MENÚ                        #
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

while true; do

    clear

    get_status
    get_ports

    line
    echo -e "${WHITE}            🔐 DROPBEAR MANAGER${RESET}"
    line

    echo -e " Estado     : $STATUS"
    echo -e " Servicio   : $SERVICE"
    echo -e " Puertos    : $PORTS"
    echo -e " Instalado  : ${DROPBEAR:-OFF}"

    line

    if [[ "$DROPBEAR" == "ON" ]]; then

        cat <<EOF
 [1] Reinstalar Dropbear
 [2] Reiniciar Servicio
 [3] Estado del Servicio
 [4] Diagnóstico
 [5] Información del Servidor
 [6] Desinstalar Dropbear
 [0] Regresar
EOF

    else

        cat <<EOF
 [1] Instalar Dropbear
 [0] Regresar
EOF

    fi

    line

    read -rp " ► Opción: " OP

case "$OP" in

1)
    install_dropbear
;;

2)
    restart_dropbear
;;

3)
    status_dropbear
;;

4)
    check_dropbear
;;

5)
    system_info
;;

6)
    remove_dropbear
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
