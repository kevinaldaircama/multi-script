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

    [[ -f "$CONFIG" ]] && source "$CONFIG"

    DOMAIN="${SERVER_DOMAIN:-$DOMAIN}"

    if [[ -z "$DOMAIN" && -f /etc/xray/domain ]]; then
        DOMAIN=$(cat /etc/xray/domain)
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
USERNAME=$(echo "$USERNAME" | xargs)

if [[ -z "$USERNAME" ]]; then
    echo -e "${RED}✘ Usuario inválido.${RESET}"
    return
fi

if vmess_user_exists "$USERNAME"; then
    echo -e "${RED}✘ El usuario ya existe.${RESET}"
    read -n1 -r -p "Presione cualquier tecla para continuar..."
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
        
if ! jq empty /tmp/xray.json >/dev/null 2>&1; then
    echo -e "${RED}✘ Error al generar config.json.${RESET}"
    rm -f /tmp/xray.json
    return
fi
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
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                  👥 USUARIOS VMESS                        ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════╦══════════════════════╦═══════════════════════════════╣${RESET}"

    printf "${CYAN}║${WHITE} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${WHITE} %-29s ${CYAN}║${RESET}\n" "#" "USUARIO" "UUID"

    echo -e "${CYAN}╠════╬══════════════════════╬═══════════════════════════════╣${RESET}"

    TOTAL=0

    while read -r USER
    do

        [[ -z "$USER" ]] && continue

        UUID=$(get_vmess_uuid "$USER")

        SHORT_UUID="${UUID:0:29}..."

        TOTAL=$((TOTAL+1))

        printf "${CYAN}║${GREEN} %-2s ${CYAN}║${WHITE} %-20s ${CYAN}║${YELLOW} %-29s ${CYAN}║${RESET}\n" \
            "$TOTAL" "$USER" "$SHORT_UUID"

    done < <(
        jq -r '.inbounds[0].settings.clients[].email' "$XRAY_CFG"
    )

    if [[ "$TOTAL" == "0" ]]; then

        echo -e "${CYAN}║${RED}              NO EXISTEN USUARIOS REGISTRADOS              ${CYAN}║${RESET}"
        TOTAL=0

    fi

    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    printf "${CYAN}║${WHITE} Total de usuarios : ${GREEN}%-34s${CYAN}║${RESET}\n" "$TOTAL"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "Presione cualquier tecla para continuar..."

}

#--------------------------------------------------
# Existe Usuario
#--------------------------------------------------

vmess_user_exists() {

    jq -e \
    --arg email "$1" \
    '.inbounds[0].settings.clients | any(.email == $email)' \
    "$XRAY_CFG" >/dev/null 2>&1

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
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                 ✅ CUENTA VMESS CREADA                     ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    printf "${CYAN}║${RESET} 👤 Usuario    ${WHITE}: %-40s${CYAN}║${RESET}\n" "$USER"
    printf "${CYAN}║${RESET} 🆔 UUID       ${WHITE}: %-40s${CYAN}║${RESET}\n" "$UUID"
    printf "${CYAN}║${RESET} 🌐 Dominio    ${WHITE}: %-40s${CYAN}║${RESET}\n" "$DOMAIN"
    printf "${CYAN}║${RESET} 🔒 Puerto     ${WHITE}: %-40s${CYAN}║${RESET}\n" "443"
    printf "${CYAN}║${RESET} 🛡 Seguridad  ${WHITE}: %-40s${CYAN}║${RESET}\n" "TLS"
    printf "${CYAN}║${RESET} 📡 Network    ${WHITE}: %-40s${CYAN}║${RESET}\n" "WebSocket"
    printf "${CYAN}║${RESET} 📂 Path       ${WHITE}: %-40s${CYAN}║${RESET}\n" "/vmess"

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${YELLOW}                     🔗 ENLACE VMESS                        ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo
    echo -e "${GREEN}$LINK${RESET}"
    echo

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "Presione cualquier tecla para continuar..."

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

    load_domain
if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}✘ No hay dominio configurado.${RESET}"
    return
fi
    LINK="vmess://$(generate_vmess_link "$VMESS_USER" "$VMESS_UUID")"

    clear

    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                 🎉 CUENTA VMESS CREADA EXITOSAMENTE              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"

    printf "${CYAN}║${RESET} 👤 Usuario     ${WHITE}: %-42s${CYAN}║${RESET}\n" "$VMESS_USER"
    printf "${CYAN}║${RESET} 🆔 UUID        ${WHITE}: %-42s${CYAN}║${RESET}\n" "$VMESS_UUID"
    printf "${CYAN}║${RESET} 🌐 Dominio     ${WHITE}: %-42s${CYAN}║${RESET}\n" "$DOMAIN"
    printf "${CYAN}║${RESET} 🔒 Puerto      ${WHITE}: %-42s${CYAN}║${RESET}\n" "443"
    printf "${CYAN}║${RESET} 📡 Network     ${WHITE}: %-42s${CYAN}║${RESET}\n" "WebSocket"
    printf "${CYAN}║${RESET} 🛡 Seguridad   ${WHITE}: %-42s${CYAN}║${RESET}\n" "TLS"
    printf "${CYAN}║${RESET} 📂 Path        ${WHITE}: %-42s${CYAN}║${RESET}\n" "/vmess"

    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${YELLOW}                     🔗 ENLACE VMESS                              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${RESET}"

    echo
    echo -e "${GREEN}$LINK${RESET}"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}✔ La cuenta está lista para usar.${RESET}"
    echo -e "${GREEN}✔ Comparta el enlace VMess con el cliente.${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo
    read -n1 -r -p "Presione cualquier tecla para regresar al menú..."

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
read -n1 -r -p "Presione cualquier tecla para continuar..."
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
echo
read -n1 -r -p "Presione cualquier tecla para continuar..."
}

#--------------------------------------------------
# Reiniciar
#--------------------------------------------------

restart_xray_service() {

    echo

    systemctl restart xray

    sleep 2
if ! systemctl is-active --quiet xray; then
    echo -e "${RED}✘ Xray no pudo iniciarse.${RESET}"
    return
fi

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

    if systemctl is-active --quiet xray; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    VERSION=$(xray version 2>/dev/null | head -1)
    VERSION=${VERSION:-NO INSTALADO}

    if xray run -test -config "$XRAY_CFG" >/dev/null 2>&1; then
        CONFIG_STATUS="${GREEN}🟢 CORRECTA${RESET}"
    else
        CONFIG_STATUS="${RED}🔴 ERROR${RESET}"
    fi

    if ss -lnt | grep -q ":10002 "; then
        PORT10002="${GREEN}🟢 ESCUCHANDO${RESET}"
    else
        PORT10002="${RED}🔴 CERRADO${RESET}"
    fi

    if ss -lnt | grep -q ":443 "; then
        PORT443="${GREEN}🟢 DISPONIBLE${RESET}"
    else
        PORT443="${YELLOW}🟡 Gestionado por HAProxy${RESET}"
    fi

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}                 📊 ESTADO DEL SERVICIO XRAY              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"

    printf " %-18s %b\n" "Estado:" "$STATUS"
    printf " %-18s ${GREEN}%s${RESET}\n" "Versión:" "$VERSION"
    printf " %-18s %b\n" "Configuración:" "$CONFIG_STATUS"
    printf " %-18s %b\n" "Puerto 443:" "$PORT443"
    printf " %-18s %b\n" "Puerto 10002:" "$PORT10002"

    echo
    echo -e " ${GREEN}🟢${RESET} VMess ............... Disponible"
    echo -e " ${GREEN}🟢${RESET} WebSocket ........... Disponible"
    echo -e " ${GREEN}🟢${RESET} TLS ................. Disponible"
    echo -e " ${GREEN}🟢${RESET} JSON Config ......... Cargado"

    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo
    read -n1 -r -p "Presione cualquier tecla para continuar..."

}

#--------------------------------------------------
# Menú
#--------------------------------------------------
xray_menu() {

while true
do

clear

source "$CONFIG" 2>/dev/null
load_domain

if systemctl is-active --quiet xray; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

VERSION=$(xray version 2>/dev/null | head -1)
VERSION=${VERSION:-NO INSTALADO}

DOMAIN_SHOW="${DOMAIN:-${SERVER_DOMAIN:-NO CONFIGURADO}}"

TOTAL_USERS=0
ONLINE_USERS=0

if [[ -f "$XRAY_CFG" ]]; then
    TOTAL_USERS=$(jq '.inbounds[0].settings.clients | length' "$XRAY_CFG" 2>/dev/null)
fi

if [[ -f "$XRAY_LOG" ]]; then
    LIMIT=$(date -d "60 seconds ago" "+%Y/%m/%d %H:%M:%S")
    ONLINE_USERS=$(awk -v LIM="$LIMIT" '
    /email:/{
        DATA=$1" "$2
        if(DATA>=LIM){
            split($0,a,"email: ")
            print a[2]
        }
    }' "$XRAY_LOG" | sort -u | wc -l)
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${WHITE}              🚀 KevinTech Multi Script              ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}                 XRAY MANAGER v3.0                  ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

echo -e "${CYAN}┌──────────────── INFORMACIÓN ────────────────┐${RESET}"
printf " ${WHITE}Estado      : %b\n" "$STATUS"
printf " ${WHITE}Dominio     : ${GREEN}%s${RESET}\n" "$DOMAIN_SHOW"
printf " ${WHITE}Protocolo   : ${GREEN}VMess + WebSocket + TLS${RESET}\n"
printf " ${WHITE}Puerto TLS  : ${GREEN}443${RESET}\n"
printf " ${WHITE}Path        : ${GREEN}/vmess${RESET}\n"
printf " ${WHITE}Servicio    : ${GREEN}Xray Core${RESET}\n"
printf " ${WHITE}Versión     : ${GREEN}%s${RESET}\n" "$VERSION"
printf " ${WHITE}Usuarios    : ${GREEN}%s${RESET}\n" "$TOTAL_USERS"
printf " ${WHITE}Online      : ${GREEN}%s${RESET}\n" "$ONLINE_USERS"
echo -e "${CYAN}└─────────────────────────────────────────────┘${RESET}"

echo

if systemctl is-active --quiet xray; then

echo -e "${CYAN}┌────────────── Gestión de Usuarios ──────────────┐${RESET}"
echo -e " ${GREEN}[1]${RESET} 👤 Crear Usuario VMess"
echo -e " ${GREEN}[2]${RESET} 🗑 Eliminar Usuario"
echo -e " ${GREEN}[3]${RESET} 📋 Listar Usuarios"
echo -e " ${GREEN}[4]${RESET} 📄 Mostrar Cuenta"
echo -e "${CYAN}└────────────────────────────────────────────────┘${RESET}"

echo

echo -e "${CYAN}┌──────────── Administración del Servicio ───────┐${RESET}"
echo -e " ${GREEN}[5]${RESET} 🌐 Usuarios Online"
echo -e " ${GREEN}[6]${RESET} ℹ Información VMess"
echo -e " ${GREEN}[7]${RESET} 🔄 Reiniciar Xray"
echo -e " ${GREEN}[8]${RESET} 📊 Estado del Servicio"
echo -e " ${GREEN}[9]${RESET} ♻ Reinstalar Xray"
echo -e " ${GREEN}[10]${RESET} 🗑 Desinstalar Xray"
echo -e "${CYAN}└────────────────────────────────────────────────┘${RESET}"

else

echo -e "${CYAN}┌──────────────── Instalación ────────────────┐${RESET}"
echo -e " ${GREEN}[1]${RESET} 🚀 Instalar Xray Core"
echo -e "${CYAN}└─────────────────────────────────────────────┘${RESET}"

fi

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e " ${GREEN}[0]${RESET} ↩ Regresar"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
read -rp " ► Opción: " opc

case "$opc" in

1)
if systemctl is-active --quiet xray; then
    create_vmess_account
else
    install_xray
fi
;;

2)
if systemctl is-active --quiet xray; then
    remove_vmess_user
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

3)
if systemctl is-active --quiet xray; then
    list_vmess_users
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

4)
if systemctl is-active --quiet xray; then
    show_vmess_account
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

5)
if systemctl is-active --quiet xray; then
    xray_online_users
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

6)
if systemctl is-active --quiet xray; then
    vmess_server_info
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

7)
if systemctl is-active --quiet xray; then
    restart_xray_service
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

8)
if systemctl is-active --quiet xray; then
    xray_status
else
    echo "❌ Xray no está instalado."
    sleep 2
fi
;;

9)
if systemctl is-active --quiet xray; then
    install_xray
fi
;;

10)
if systemctl is-active --quiet xray; then
    remove_xray
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
