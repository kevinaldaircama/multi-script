#!/bin/bash
#==================================================
# KevinTech Multi Script
# Xray Manager
# Parte 1 - Instalación
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CFG="$XRAY_DIR/config.json"
XRAY_LOG="/var/log/xray/access.log"

#==================================================
# Dependencias
#==================================================

install_xray_dependencies() {

    echo -e "${CYAN}➜ Actualizando repositorios...${RESET}"
    apt-get update -y

    echo -e "${CYAN}➜ Instalando dependencias...${RESET}"

    apt-get install -y \
        curl \
        wget \
        unzip \
        jq \
        socat \
        cron \
        bash-completion

}

#==================================================
# Instalar Core
#==================================================

install_xray_core() {

    echo -e "${CYAN}➜ Descargando Xray Core...${RESET}"

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    if [[ $? != 0 ]]; then
        echo -e "${RED}✘ Error instalando Xray.${RESET}"
        return 1
    fi

    echo -e "${GREEN}✔ Xray instalado.${RESET}"

}

#==================================================
# Crear Directorios
#==================================================

create_xray_dirs() {

    mkdir -p "$XRAY_DIR"
    mkdir -p /var/log/xray

    touch "$XRAY_LOG"

}

#==================================================
# Configuración Base
#==================================================

create_xray_config() {

cat > "$XRAY_CFG" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },

  "inbounds": [

    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",

      "settings": {
        "clients": []
      },

      "streamSettings": {
        "network": "ws",

        "wsSettings": {
          "path": "/vmess"
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }

    }

  ],

  "outbounds": [

    {
      "protocol":"freedom",
      "tag":"direct"
    },

    {
      "protocol":"blackhole",
      "tag":"block"
    }

  ]

}
EOF

}

#==================================================
# Resiliencia
#==================================================

ensure_xray_resilience() {

mkdir -p /etc/systemd/system/xray.service.d

cat >/etc/systemd/system/xray.service.d/10-resilience.conf <<EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
EOF

systemctl daemon-reload

systemctl enable xray >/dev/null 2>&1

}

#==================================================
# Reiniciar
#==================================================

restart_xray() {

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray
    then
        echo -e "${GREEN}✔ Xray iniciado correctamente.${RESET}"
    else
        echo -e "${RED}✘ No fue posible iniciar Xray.${RESET}"
    fi

}

#==================================================
# Instalar
#==================================================

install_xray() {

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        INSTALANDO XRAY CORE${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    install_xray_dependencies || return

    install_xray_core || return

    create_xray_dirs

    create_xray_config

    ensure_xray_resilience

    restart_xray

    if [[ -f "$CONFIG" ]]; then

        sed -i '/^XRAY=/d' "$CONFIG"

        echo "XRAY=ON" >> "$CONFIG"

    fi

    echo
    echo -e "${GREEN}✔ Instalación completada.${RESET}"

}

#==================================================
# Desinstalar
#==================================================

remove_xray() {

    systemctl stop xray 2>/dev/null

    systemctl disable xray 2>/dev/null

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove

    rm -rf "$XRAY_DIR"

    rm -rf /var/log/xray

    if [[ -f "$CONFIG" ]]; then

        sed -i '/^XRAY=/d' "$CONFIG"

        echo "XRAY=OFF" >> "$CONFIG"

    fi

    echo -e "${GREEN}✔ Xray eliminado.${RESET}"

}
#==================================================
# KevinTech Multi Script
# Xray Manager
# Parte 2 - Gestión de Usuarios VMess
#==================================================

#--------------------------------------------------
# Cargar Dominio
#--------------------------------------------------

load_domain() {

    if [[ -f "$CONFIG" ]]; then
        source "$CONFIG"
    fi

    if [[ -z "$DOMAIN" ]]; then
        DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
    fi

}

#--------------------------------------------------
# Verificar Config
#--------------------------------------------------

check_xray_config() {

    if [[ ! -f "$XRAY_CFG" ]]; then
        echo -e "${RED}✘ No existe config.json${RESET}"
        return 1
    fi

    command -v jq >/dev/null 2>&1 || {
        echo -e "${RED}✘ jq no está instalado.${RESET}"
        return 1
    }

}

#--------------------------------------------------
# Crear Usuario
#--------------------------------------------------

create_vmess_user() {

    check_xray_config || return

    load_domain

    echo
    read -rp "Usuario : " USERNAME

    if [[ -z "$USERNAME" ]]; then
        echo -e "${RED}✘ Usuario inválido.${RESET}"
        return
    fi

    UUID=$(cat /proc/sys/kernel/random/uuid)

    jq \
        --arg uuid "$UUID" \
        --arg email "$USERNAME" \
        '.inbounds[0].settings.clients +=
        [{
            "id":$uuid,
            "level":0,
            "email":$email
        }]' \
        "$XRAY_CFG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CFG"

    systemctl restart xray

    VMESS_UUID="$UUID"
    VMESS_USER="$USERNAME"

    echo
    echo -e "${GREEN}✔ Usuario creado correctamente.${RESET}"

}

#--------------------------------------------------
# Eliminar Usuario
#--------------------------------------------------

remove_vmess_user() {

    check_xray_config || return

    echo
    read -rp "Usuario : " USERNAME

    [[ -z "$USERNAME" ]] && return

    jq \
      --arg email "$USERNAME" \
      '.inbounds[0].settings.clients |=
      map(select(.email != $email))' \
      "$XRAY_CFG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CFG"

    systemctl restart xray

    echo
    echo -e "${GREEN}✔ Usuario eliminado.${RESET}"

}

#--------------------------------------------------
# Buscar UUID
#--------------------------------------------------

get_vmess_uuid() {

    jq -r \
    --arg email "$1" \
    '.inbounds[0].settings.clients[]
    | select(.email==$email)
    | .id' \
    "$XRAY_CFG"

}

#--------------------------------------------------
# Listar Usuarios
#--------------------------------------------------

list_vmess_users() {

    check_xray_config || return

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        USUARIOS VMESS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    TOTAL=0

    while read USER
    do

        [[ -z "$USER" ]] && continue

        UUID=$(get_vmess_uuid "$USER")

        TOTAL=$((TOTAL+1))

        echo -e "${GREEN}$TOTAL)${RESET} ${WHITE}$USER${RESET}"
        echo "    UUID : $UUID"
        echo

    done < <(

        jq -r \
        '.inbounds[0].settings.clients[].email' \
        "$XRAY_CFG"

    )

    if [[ "$TOTAL" == "0" ]]; then
        echo "No existen usuarios."
    fi

}

#--------------------------------------------------
# Existe Usuario
#--------------------------------------------------

vmess_user_exists() {

    jq -e \
    --arg email "$1" \
    '.inbounds[0].settings.clients[]
    | select(.email==$email)' \
    "$XRAY_CFG" >/dev/null

}
#==================================================
# KevinTech Multi Script
# Xray Manager
# Parte 3 - VMess Link e Información
#==================================================

#--------------------------------------------------
# Base64 sin saltos de línea
#--------------------------------------------------

base64_encode() {

    if base64 --help 2>/dev/null | grep -q "\-w"
    then
        base64 -w 0
    else
        base64 | tr -d '\n'
    fi

}

#--------------------------------------------------
# Generar Link VMess
#--------------------------------------------------

generate_vmess_link() {

    load_domain

    local USER="$1"
    local UUID="$2"

cat <<EOF | base64_encode
{
  "v":"2",
  "ps":"$USER",
  "add":"$DOMAIN",
  "port":"443",
  "id":"$UUID",
  "aid":"0",
  "scy":"auto",
  "net":"ws",
  "type":"none",
  "host":"$DOMAIN",
  "path":"/vmess",
  "tls":"tls",
  "sni":"$DOMAIN",
  "alpn":""
}
EOF

}

#--------------------------------------------------
# Mostrar Usuario
#--------------------------------------------------

show_vmess_user() {

    load_domain

    local USER="$1"
    local UUID="$2"

    LINK="vmess://$(generate_vmess_link "$USER" "$UUID")"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          CUENTA VMESS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e "${GREEN}Usuario :${RESET} $USER"
    echo -e "${GREEN}UUID    :${RESET} $UUID"
    echo -e "${GREEN}Host    :${RESET} $DOMAIN"
    echo -e "${GREEN}Puerto  :${RESET} 443"
    echo -e "${GREEN}TLS     :${RESET} Sí"
    echo -e "${GREEN}Network :${RESET} WebSocket"
    echo -e "${GREEN}Path    :${RESET} /vmess"

    echo
    echo -e "${YELLOW}══════════════════════════════════════════════${RESET}"
    echo "$LINK"
    echo -e "${YELLOW}══════════════════════════════════════════════${RESET}"
    echo

}

#--------------------------------------------------
# Mostrar Usuario por Nombre
#--------------------------------------------------

show_vmess_account() {

    check_xray_config || return

    echo
    read -rp "Usuario : " USERNAME

    [[ -z "$USERNAME" ]] && return

    UUID=$(get_vmess_uuid "$USERNAME")

    if [[ -z "$UUID" ]]; then
        echo
        echo -e "${RED}✘ Usuario no encontrado.${RESET}"
        return
    fi

    show_vmess_user "$USERNAME" "$UUID"

}

#--------------------------------------------------
# Crear Cuenta Completa
#--------------------------------------------------

create_vmess_account() {

    create_vmess_user || return

    show_vmess_user "$VMESS_USER" "$VMESS_UUID"

}

#--------------------------------------------------
# Exportar Link
#--------------------------------------------------

export_vmess_link() {

    check_xray_config || return

    echo
    read -rp "Usuario : " USERNAME

    [[ -z "$USERNAME" ]] && return

    UUID=$(get_vmess_uuid "$USERNAME")

    [[ -z "$UUID" ]] && {
        echo -e "${RED}✘ Usuario no encontrado.${RESET}"
        return
    }

    LINK="vmess://$(generate_vmess_link "$USERNAME" "$UUID")"

    echo "$LINK" >/tmp/vmess.txt

    echo
    echo -e "${GREEN}✔ Link exportado:${RESET}"
    echo "/tmp/vmess.txt"

}

#--------------------------------------------------
# Información del Servidor
#--------------------------------------------------

vmess_server_info() {

    load_domain

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         INFORMACIÓN VMESS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo "Dominio : $DOMAIN"
    echo "Puerto  : 443"
    echo "TLS     : Sí"
    echo "Network : ws"
    echo "Path    : /vmess"
    echo "Host    : $DOMAIN"

    echo
}
#==================================================
# KevinTech Multi Script
# Xray Manager
# Parte 4 - Online, Estado y Menú
#==================================================

#--------------------------------------------------
# Usuarios Online
#--------------------------------------------------

xray_online_users() {

    if [[ ! -f "$XRAY_LOG" ]]; then
        echo
        echo -e "${RED}✘ No existe el access.log.${RESET}"
        return
    fi

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        USUARIOS EN LÍNEA${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    LIMIT=$(date -d "60 seconds ago" "+%Y/%m/%d %H:%M:%S")

    awk -v LIM="$LIMIT" '
    /email:/ {

        DATA=$1" "$2

        if(DATA>=LIM){

            split($0,a,"email: ")

            print a[2]

        }

    }' "$XRAY_LOG" | sort -u

    TOTAL=$(awk -v LIM="$LIMIT" '
    /email:/ {

        DATA=$1" "$2

        if(DATA>=LIM){

            split($0,a,"email: ")

            print a[2]

        }

    }' "$XRAY_LOG" | sort -u | wc -l)

    echo
    echo -e "${GREEN}Usuarios conectados:${RESET} $TOTAL"
    echo

}

#--------------------------------------------------
# Reiniciar
#--------------------------------------------------

restart_xray_service() {

    echo

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray
    then
        echo -e "${GREEN}✔ Xray reiniciado correctamente.${RESET}"
    else
        echo -e "${RED}✘ Error al reiniciar Xray.${RESET}"
    fi

}

#--------------------------------------------------
# Estado
#--------------------------------------------------

xray_status() {

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}           ESTADO XRAY${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if systemctl is-active --quiet xray
    then
        STATUS="${GREEN}ACTIVO${RESET}"
    else
        STATUS="${RED}DETENIDO${RESET}"
    fi

    VERSION=$(xray version 2>/dev/null | head -1)

    echo
    echo -e "Estado  : $STATUS"
    echo -e "Versión : $VERSION"
    echo -e "Puerto  : 10002"
    echo -e "Path    : /vmess"
    echo

}

#--------------------------------------------------
# Menú
#--------------------------------------------------
xray_menu() {

while true
do

clear

source "$CONFIG" 2>/dev/null

if systemctl is-active --quiet xray; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

VERSION=$(xray version 2>/dev/null | head -1)

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              🚀 XRAY MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado      : $STATUS"
echo -e " Dominio     : ${DOMAIN:-${SERVER_DOMAIN:-NO CONFIGURADO}}"
echo -e " Puerto      : 443"
echo -e " Network     : WebSocket"
echo -e " Path        : /vmess"
echo -e " Servicio    : Xray Core"
echo -e " Versión     : ${VERSION:-NO INSTALADO}"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if systemctl is-active --quiet xray; then

echo " [1] ➮ Reinstalar Xray"
echo " [2] ➮ Crear Usuario VMess"
echo " [3] ➮ Eliminar Usuario"
echo " [4] ➮ Listar Usuarios"
echo " [5] ➮ Mostrar Cuenta"
echo " [6] ➮ Usuarios Online"
echo " [7] ➮ Información VMess"
echo " [8] ➮ Reiniciar Xray"
echo " [9] ➮ Estado del Servicio"
echo " [10] ➮ Desinstalar Xray"
echo
echo " [0] ➮ Regresar"

else

echo " [1] ➮ Instalar Xray"
echo
echo " [0] ➮ Regresar"

fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " opc

case "$opc" in

1)
install_xray
sleep 2
;;

2)
if systemctl is-active --quiet xray; then
    create_vmess_account
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

3)
if systemctl is-active --quiet xray; then
    remove_vmess_user
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

4)
if systemctl is-active --quiet xray; then
    list_vmess_users
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

5)
if systemctl is-active --quiet xray; then
    show_vmess_account
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

6)
if systemctl is-active --quiet xray; then
    xray_online_users
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

7)
if systemctl is-active --quiet xray; then
    vmess_server_info
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

8)
if systemctl is-active --quiet xray; then
    restart_xray_service
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

9)
if systemctl is-active --quiet xray; then
    xray_status
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

10)
if systemctl is-active --quiet xray; then
    remove_xray
    sleep 2
fi
;;

0)
exec bash "$BASE/protocolos/menu.sh"
;;

*)
echo
echo "❌ Opción inválida."
sleep 2
;;

esac

done

}

#==================================================
# Inicio
#==================================================

xray_menu
