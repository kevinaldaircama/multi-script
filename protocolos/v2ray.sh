#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#
#          KevinTech Multi Script Premium
#                 Xray Manager v4.0
#
# Compatible:
#   Ubuntu 18.04 / 20.04 / 22.04 / 24.04
#
# Integración:
#   ✔ WebSocket Manager
#   ✔ SSL Manager (Stunnel)
#   ✔ VMess
#   ✔ VLESS
#   ✔ Trojan
#
# Autor : KevinTech
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#

############################
# COLORES
############################

RESET="\e[0m"

BLACK="\e[1;30m"
RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

############################
# RUTAS
############################

BASE="/etc/kevintech"

CONFIG="$BASE/config.conf"

XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="$XRAY_DIR/config.json"

DATA_DIR="$BASE/v2ray"

VMESS_DB="$DATA_DIR/vmess.db"
VLESS_DB="$DATA_DIR/vless.db"
TROJAN_DB="$DATA_DIR/trojan.db"

LOG_DIR="/var/log/xray"

VERSION="4.0 Premium"

############################
# VALIDAR ROOT
############################

if [[ $EUID -ne 0 ]]; then
    clear
    echo
    echo -e "${RED}Este módulo requiere permisos ROOT.${RESET}"
    echo
    exit 1
fi

############################
# VALIDAR UBUNTU
############################

if [[ -f /etc/os-release ]]; then
    source /etc/os-release

    case "$VERSION_ID" in
        18.04|20.04|22.04|24.04)
        ;;
        *)
            clear
            echo
            echo -e "${RED}Ubuntu $VERSION_ID no soportado.${RESET}"
            echo
            exit 1
        ;;
    esac
fi

############################
# CREAR DIRECTORIOS
############################

mkdir -p "$BASE"
mkdir -p "$DATA_DIR"
mkdir -p "$XRAY_DIR"
mkdir -p "$LOG_DIR"

touch "$VMESS_DB"
touch "$VLESS_DB"
touch "$TROJAN_DB"

############################
# CARGAR CONFIG
############################

[[ -f "$CONFIG" ]] && source "$CONFIG"

############################
# FUNCIONES VISUALES
############################

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

title() {
    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          ⚡ KevinTech Multi Script Premium ⚡          ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}                 Xray Manager v4.0                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo
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
    read -n1 -rsp "Presiona cualquier tecla para continuar..."
}

############################
# INFORMACIÓN VPS
############################

get_info() {

    VPS_IP=$(curl -4 -s ifconfig.me)

    [[ -z "$VPS_IP" ]] && VPS_IP=$(hostname -I | awk '{print $1}')

    HOST=$(hostname)

    DOMAIN="${SERVER_DOMAIN:-Sin configurar}"

    CPU=$(nproc)

    RAM=$(free -h | awk '/Mem:/ {print $2}')

    UPTIME=$(uptime -p | sed 's/up //')

    KERNEL=$(uname -r)

}

############################
# ENCABEZADO
############################

header() {

    get_info

    title

    echo -e "${WHITE} Hostname : ${GREEN}$HOST${RESET}"
    echo -e "${WHITE} Dominio  : ${GREEN}$DOMAIN${RESET}"
    echo -e "${WHITE} IP VPS   : ${GREEN}$VPS_IP${RESET}"
    echo -e "${WHITE} Kernel   : ${GREEN}$KERNEL${RESET}"
    echo -e "${WHITE} CPU      : ${GREEN}${CPU} Core(s)${RESET}"
    echo -e "${WHITE} RAM      : ${GREEN}$RAM${RESET}"
    echo -e "${WHITE} Uptime   : ${GREEN}$UPTIME${RESET}"

    line

}

############################
# FUNCIONES GENERALES
############################

public_ip() {
    curl -4 -s ifconfig.me
}

generate_uuid() {
    uuidgen
}

today() {
    date +"%Y-%m-%d"
}

save_config() {

    local KEY="$1"
    local VALUE="$2"

    mkdir -p "$BASE"

    touch "$CONFIG"

    if grep -q "^${KEY}=" "$CONFIG"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$CONFIG"
    else
        echo "${KEY}=${VALUE}" >> "$CONFIG"
    fi

}

service_status() {

    if systemctl is-active --quiet "$1"; then
        echo -e "${GREEN}ACTIVO${RESET}"
    else
        echo -e "${RED}DETENIDO${RESET}"
    fi

}

restart_service() {

    systemctl restart "$1"

    sleep 2

    if systemctl is-active --quiet "$1"; then
        ok "$1 iniciado correctamente."
    else
        error "No fue posible iniciar $1."
    fi

}

check_internet() {

    curl -Is https://google.com --connect-timeout 5 >/dev/null

    [[ $? -eq 0 ]]

}
############################
# INSTALAR DEPENDENCIAS
############################

install_dependencies(){

    header

    echo -e "${YELLOW}Instalando dependencias...${RESET}"

    apt-get update

    PACKAGES=(
        curl
        wget
        unzip
        tar
        jq
        uuid-runtime
        socat
        cron
        openssl
        ca-certificates
    )

    for PKG in "${PACKAGES[@]}"
    do
        if ! dpkg -s "$PKG" >/dev/null 2>&1
        then
            info "Instalando $PKG..."
            apt-get install -y "$PKG"
        fi
    done

    ok "Dependencias instaladas."

}

############################
# INSTALAR XRAY CORE
############################

install_xray_core(){

    header

    echo -e "${YELLOW}Instalando Xray Core...${RESET}"

    if command -v xray >/dev/null 2>&1
    then
        ok "Xray ya está instalado."
        return
    fi

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    if ! command -v xray >/dev/null 2>&1
    then
        error "No fue posible instalar Xray."
        pause
        return
    fi

    mkdir -p "$XRAY_DIR"

    mkdir -p /var/log/xray

    touch /var/log/xray/access.log
    touch /var/log/xray/error.log

    chmod 755 "$XRAY_DIR"
    chmod 755 /var/log/xray

    systemctl enable xray

    mkdir -p /etc/systemd/system/xray.service.d

    cat >/etc/systemd/system/xray.service.d/restart.conf <<EOF
[Service]
Restart=always
RestartSec=3
LimitNOFILE=1048576
EOF

    systemctl daemon-reload

    ok "Xray instalado correctamente."

}

############################
# CONFIGURACIÓN INICIAL
############################

prepare_xray(){

    header

    echo -e "${YELLOW}Preparando entorno Xray...${RESET}"

    mkdir -p "$DATA_DIR"

    touch "$VMESS_DB"
    touch "$VLESS_DB"
    touch "$TROJAN_DB"

    mkdir -p "$XRAY_DIR"

    chmod -R 755 "$XRAY_DIR"

    save_config XRAY ON

    ok "Entorno preparado."

}

############################
# REINICIAR XRAY
############################

restart_xray(){

    restart_service xray

}

############################
# ESTADO
############################

status_xray(){

    header

    echo
    echo -e "Estado del servicio : $(service_status xray)"
    echo

    systemctl --no-pager --full status xray

    pause

}

############################
# DESINSTALAR XRAY
############################

remove_xray(){

    header

    read -rp "¿Eliminar Xray completamente? [S/N]: " R

    [[ "$R" != "S" && "$R" != "s" ]] && return

    systemctl stop xray

    systemctl disable xray

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove

    rm -rf "$XRAY_DIR"
    rm -rf "$DATA_DIR"

    save_config XRAY OFF

    ok "Xray eliminado."

    pause

}

############################
# INSTALACIÓN COMPLETA
############################

setup_xray(){

    install_dependencies

    install_xray_core

    prepare_xray

    restart_xray

}
############################
# CREAR CONFIGURACIÓN XRAY
############################

create_xray_config(){

    header

    echo -e "${YELLOW}Creando configuración Xray...${RESET}"

    mkdir -p "$XRAY_DIR"

    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },

  "inbounds":[

    {
      "tag":"vmess-tcp",
      "listen":"0.0.0.0",
      "port":10000,
      "protocol":"vmess",

      "settings":{
        "clients":[]
      },

      "streamSettings":{
        "network":"tcp",
        "security":"none"
      }
    },

    {
      "tag":"vless-tcp",
      "listen":"0.0.0.0",
      "port":10001,
      "protocol":"vless",

      "settings":{
        "clients":[]
      },

      "streamSettings":{
        "network":"tcp",
        "security":"none"
      }
    },

    {
      "tag":"trojan",
      "listen":"0.0.0.0",
      "port":10002,
      "protocol":"trojan",

      "settings":{
        "clients":[]
      },

      "streamSettings":{
        "network":"tcp",
        "security":"none"
      }
    }

  ],

  "outbounds":[
    {
      "protocol":"freedom",
      "tag":"direct"
    },
    {
      "protocol":"blackhole",
      "tag":"blocked"
    }
  ]
}
EOF

    chmod 644 "$XRAY_CONFIG"

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray
    then

        ok "Configuración creada correctamente."

    else

        error "Xray no pudo iniciar."

        journalctl -u xray -n 30 --no-pager

    fi

    pause

}

############################
# INFORMACIÓN DEL SERVICIO
############################

show_ports(){

    header

    echo

    echo -e "${WHITE}Estado        : $(service_status xray)"
    echo -e "${WHITE}VMess TCP     : ${GREEN}10000${RESET}"
    echo -e "${WHITE}VLESS TCP     : ${GREEN}10001${RESET}"
    echo -e "${WHITE}Trojan TCP    : ${GREEN}10002${RESET}"

    echo
    line

    ss -tlnp | grep xray

    echo

    pause

}

############################
# INSTALACIÓN COMPLETA
############################

setup_xray(){

    install_dependencies

    install_xray_core

    prepare_xray

    create_xray_config

    restart_xray

}
############################
# CREAR USUARIO VMESS
############################

create_vmess(){

    header

    echo -e "${CYAN}Crear Usuario VMess${RESET}"
    echo

    read -rp "Usuario : " USER

    [[ -z "$USER" ]] && {
        error "Nombre inválido."
        pause
        return
    }

    if grep -qw "^${USER}|" "$VMESS_DB"; then
        error "El usuario ya existe."
        pause
        return
    fi

    read -rp "Días de duración : " DAYS

    [[ -z "$DAYS" ]] && DAYS=30

    UUID=$(generate_uuid)

    EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

    jq \
    --arg uuid "$UUID" \
    --arg email "$USER" \
    '.inbounds[0].settings.clients += [{
        "id":$uuid,
        "alterId":0,
        "email":$email
    }]' \
    "$XRAY_CONFIG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CONFIG"

    echo "${USER}|${UUID}|${EXP}" >> "$VMESS_DB"

    restart_xray

    IP=$(public_ip)

    clear

    line
    echo "       VMESS CREADO"
    line

    echo
    echo "Usuario : $USER"
    echo "UUID    : $UUID"
    echo "Expira  : $EXP"
    echo
    echo "IP      : $IP"
    echo "Puerto  : 10000"
    echo
    line

    pause

}

############################
# LISTAR VMESS
############################

list_vmess(){

    header

    if [[ ! -s "$VMESS_DB" ]]; then
        info "No existen usuarios."
        pause
        return
    fi

    printf "%-20s %-15s\n" "USUARIO" "EXPIRACIÓN"

    line

    while IFS="|" read USER UUID EXP
    do
        printf "%-20s %-15s\n" "$USER" "$EXP"
    done < "$VMESS_DB"

    echo

    pause

}

############################
# ELIMINAR VMESS
############################

remove_vmess(){

    header

    read -rp "Usuario : " USER

    if ! grep -qw "^${USER}|" "$VMESS_DB"; then
        error "Usuario inexistente."
        pause
        return
    fi

    UUID=$(grep "^${USER}|" "$VMESS_DB" | cut -d'|' -f2)

    jq \
    --arg uuid "$UUID" \
    '(.inbounds[0].settings.clients) |= map(select(.id != $uuid))' \
    "$XRAY_CONFIG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CONFIG"

    grep -vw "^${USER}|" "$VMESS_DB" > /tmp/vmess.db

    mv /tmp/vmess.db "$VMESS_DB"

    restart_xray

    ok "Usuario eliminado."

    pause

}
############################
# CREAR USUARIO VLESS
############################

create_vless(){

    header

    echo -e "${CYAN}Crear Usuario VLESS${RESET}"
    echo

    read -rp "Usuario : " USER

    [[ -z "$USER" ]] && {
        error "Nombre inválido."
        pause
        return
    }

    if grep -qw "^${USER}|" "$VLESS_DB"; then
        error "El usuario ya existe."
        pause
        return
    fi

    read -rp "Días de duración : " DAYS

    [[ -z "$DAYS" ]] && DAYS=30

    UUID=$(generate_uuid)

    EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

    jq \
    --arg uuid "$UUID" \
    --arg email "$USER" \
    '.inbounds[1].settings.clients += [{
        "id":$uuid,
        "email":$email
    }]' \
    "$XRAY_CONFIG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CONFIG"

    echo "${USER}|${UUID}|${EXP}" >> "$VLESS_DB"

    restart_xray

    IP=$(public_ip)

    clear

    line
    echo "       VLESS CREADO"
    line
    echo
    echo "Usuario : $USER"
    echo "UUID    : $UUID"
    echo "Expira  : $EXP"
    echo
    echo "IP      : $IP"
    echo "Puerto  : 10001"
    echo
    line

    pause

}

############################
# LISTAR VLESS
############################

list_vless(){

    header

    if [[ ! -s "$VLESS_DB" ]]; then
        info "No existen usuarios."
        pause
        return
    fi

    printf "%-20s %-15s\n" "USUARIO" "EXPIRACIÓN"

    line

    while IFS="|" read USER UUID EXP
    do
        printf "%-20s %-15s\n" "$USER" "$EXP"
    done < "$VLESS_DB"

    echo

    pause

}

############################
# ELIMINAR VLESS
############################

remove_vless(){

    header

    read -rp "Usuario : " USER

    if ! grep -qw "^${USER}|" "$VLESS_DB"; then
        error "Usuario inexistente."
        pause
        return
    fi

    UUID=$(grep "^${USER}|" "$VLESS_DB" | cut -d'|' -f2)

    jq \
    --arg uuid "$UUID" \
    '(.inbounds[1].settings.clients) |= map(select(.id != $uuid))' \
    "$XRAY_CONFIG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CONFIG"

    grep -vw "^${USER}|" "$VLESS_DB" > /tmp/vless.db

    mv /tmp/vless.db "$VLESS_DB"

    restart_xray

    ok "Usuario eliminado."

    pause

}
############################
# CREAR USUARIO TROJAN
############################

create_trojan(){

    header

    echo -e "${CYAN}Crear Usuario Trojan${RESET}"
    echo

    read -rp "Usuario : " USER

    [[ -z "$USER" ]] && {
        error "Nombre inválido."
        pause
        return
    }

    if grep -qw "^${USER}|" "$TROJAN_DB"; then
        error "El usuario ya existe."
        pause
        return
    fi

    read -rp "Días de duración : " DAYS

    [[ -z "$DAYS" ]] && DAYS=30

    PASSWORD=$(openssl rand -hex 16)

    EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

    jq \
    --arg pass "$PASSWORD" \
    --arg email "$USER" \
    '.inbounds[2].settings.clients += [{
        "password":$pass,
        "email":$email
    }]' \
    "$XRAY_CONFIG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CONFIG"

    echo "${USER}|${PASSWORD}|${EXP}" >> "$TROJAN_DB"

    restart_xray

    IP=$(public_ip)

    clear

    line
    echo "        TROJAN CREADO"
    line
    echo
    echo "Usuario    : $USER"
    echo "Password   : $PASSWORD"
    echo "Expira     : $EXP"
    echo
    echo "Servidor   : $IP"
    echo "Puerto     : 10002"
    echo
    line

    pause

}

############################
# LISTAR TROJAN
############################

list_trojan(){

    header

    if [[ ! -s "$TROJAN_DB" ]]; then
        info "No existen usuarios."
        pause
        return
    fi

    printf "%-20s %-15s\n" "USUARIO" "EXPIRACIÓN"

    line

    while IFS="|" read USER PASS EXP
    do
        printf "%-20s %-15s\n" "$USER" "$EXP"
    done < "$TROJAN_DB"

    echo

    pause

}

############################
# ELIMINAR TROJAN
############################

remove_trojan(){

    header

    read -rp "Usuario : " USER

    if ! grep -qw "^${USER}|" "$TROJAN_DB"; then
        error "Usuario inexistente."
        pause
        return
    fi

    PASS=$(grep "^${USER}|" "$TROJAN_DB" | cut -d'|' -f2)

    jq \
    --arg pass "$PASS" \
    '(.inbounds[2].settings.clients) |= map(select(.password != $pass))' \
    "$XRAY_CONFIG" > /tmp/xray.json

    mv /tmp/xray.json "$XRAY_CONFIG"

    grep -vw "^${USER}|" "$TROJAN_DB" > /tmp/trojan.db

    mv /tmp/trojan.db "$TROJAN_DB"

    restart_xray

    ok "Usuario eliminado."

    pause

}
############################
# RENOVAR USUARIO VMESS
############################

renew_vmess(){

    header

    read -rp "Usuario : " USER

    if ! grep -q "^${USER}|" "$VMESS_DB"; then
        error "Usuario no encontrado."
        pause
        return
    fi

    read -rp "Días adicionales : " DAYS

    [[ -z "$DAYS" ]] && DAYS=30

    UUID=$(grep "^${USER}|" "$VMESS_DB" | cut -d'|' -f2)

    NEW_EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

    sed -i "/^${USER}|/d" "$VMESS_DB"

    echo "${USER}|${UUID}|${NEW_EXP}" >> "$VMESS_DB"

    ok "Cuenta renovada."

    pause

}

############################
# RENOVAR USUARIO VLESS
############################

renew_vless(){

    header

    read -rp "Usuario : " USER

    if ! grep -q "^${USER}|" "$VLESS_DB"; then
        error "Usuario no encontrado."
        pause
        return
    fi

    read -rp "Días adicionales : " DAYS

    [[ -z "$DAYS" ]] && DAYS=30

    UUID=$(grep "^${USER}|" "$VLESS_DB" | cut -d'|' -f2)

    NEW_EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

    sed -i "/^${USER}|/d" "$VLESS_DB"

    echo "${USER}|${UUID}|${NEW_EXP}" >> "$VLESS_DB"

    ok "Cuenta renovada."

    pause

}

############################
# RENOVAR USUARIO TROJAN
############################

renew_trojan(){

    header

    read -rp "Usuario : " USER

    if ! grep -q "^${USER}|" "$TROJAN_DB"; then
        error "Usuario no encontrado."
        pause
        return
    fi

    read -rp "Días adicionales : " DAYS

    [[ -z "$DAYS" ]] && DAYS=30

    PASS=$(grep "^${USER}|" "$TROJAN_DB" | cut -d'|' -f2)

    NEW_EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")

    sed -i "/^${USER}|/d" "$TROJAN_DB"

    echo "${USER}|${PASS}|${NEW_EXP}" >> "$TROJAN_DB"

    ok "Cuenta renovada."

    pause

}

############################
# ELIMINAR CUENTAS EXPIRADAS
############################

remove_expired(){

    TODAY=$(date +%F)

    for DB in "$VMESS_DB" "$VLESS_DB" "$TROJAN_DB"
    do

        [[ -f "$DB" ]] || continue

        TMP=$(mktemp)

        while IFS="|" read -r USER KEY EXP
        do

            [[ -z "$USER" ]] && continue

            if [[ "$EXP" > "$TODAY" || "$EXP" == "$TODAY" ]]; then
                echo "$USER|$KEY|$EXP" >> "$TMP"
            fi

        done < "$DB"

        mv "$TMP" "$DB"

    done

    sync_xray

}

############################
# SINCRONIZAR CONFIG.JSON
############################

sync_xray(){

    create_xray_config

    while IFS="|" read -r USER UUID EXP
    do

        [[ -z "$USER" ]] && continue

        jq \
        --arg uuid "$UUID" \
        --arg email "$USER" \
        '.inbounds[0].settings.clients += [{
            "id":$uuid,
            "alterId":0,
            "email":$email
        }]' \
        "$XRAY_CONFIG" > /tmp/xray.json

        mv /tmp/xray.json "$XRAY_CONFIG"

    done < "$VMESS_DB"

    while IFS="|" read -r USER UUID EXP
    do

        [[ -z "$USER" ]] && continue

        jq \
        --arg uuid "$UUID" \
        --arg email "$USER" \
        '.inbounds[1].settings.clients += [{
            "id":$uuid,
            "email":$email
        }]' \
        "$XRAY_CONFIG" > /tmp/xray.json

        mv /tmp/xray.json "$XRAY_CONFIG"

    done < "$VLESS_DB"

    while IFS="|" read -r USER PASS EXP
    do

        [[ -z "$USER" ]] && continue

        jq \
        --arg pass "$PASS" \
        --arg email "$USER" \
        '.inbounds[2].settings.clients += [{
            "password":$pass,
            "email":$email
        }]' \
        "$XRAY_CONFIG" > /tmp/xray.json

        mv /tmp/xray.json "$XRAY_CONFIG"

    done < "$TROJAN_DB"

    restart_xray

}
############################
# GENERAR CONFIG.JSON
############################

generate_xray_config(){

cat > "$XRAY_CONFIG" <<EOF
{
  "log":{
    "access":"/var/log/xray/access.log",
    "error":"/var/log/xray/error.log",
    "loglevel":"warning"
  },

  "inbounds":[

    {
      "tag":"vmess-tcp",
      "listen":"0.0.0.0",
      "port":10000,
      "protocol":"vmess",
      "settings":{
        "clients":[]
      },
      "streamSettings":{
        "network":"tcp",
        "security":"none"
      }
    },

    {
      "tag":"vless-tcp",
      "listen":"0.0.0.0",
      "port":10001,
      "protocol":"vless",
      "settings":{
        "clients":[]
      },
      "streamSettings":{
        "network":"tcp",
        "security":"none"
      }
    },

    {
      "tag":"trojan",
      "listen":"0.0.0.0",
      "port":10002,
      "protocol":"trojan",
      "settings":{
        "clients":[]
      },
      "streamSettings":{
        "network":"tcp",
        "security":"none"
      }
    }

  ],

  "outbounds":[
    {
      "protocol":"freedom",
      "tag":"direct"
    },
    {
      "protocol":"blackhole",
      "tag":"blocked"
    }
  ]
}
EOF

chmod 644 "$XRAY_CONFIG"

}

############################
# RECONSTRUIR CONFIG.JSON
############################

rebuild_xray(){

    generate_xray_config

    sync_xray

}

############################
# TAREA AUTOMÁTICA
############################

install_cron(){

cat >/etc/cron.daily/xray-clean <<'EOF'
#!/bin/bash

BASE="/etc/kevintech/xray"

[[ -f "$BASE/vmess.db" ]] || exit 0

bash "$BASE/expire.sh"
EOF

chmod +x /etc/cron.daily/xray-clean

}

############################
# SCRIPT DE EXPIRACIÓN
############################

cat > "$XRAY_DIR/expire.sh" <<'EOF'
#!/bin/bash

BASE="/etc/kevintech/xray"

VMESS_DB="$BASE/vmess.db"
VLESS_DB="$BASE/vless.db"
TROJAN_DB="$BASE/trojan.db"

XRAY_CONFIG="/usr/local/etc/xray/config.json"

TODAY=$(date +%F)

clean_db(){

DB="$1"

TMP=$(mktemp)

while IFS="|" read USER KEY EXP
do

[[ -z "$USER" ]] && continue

if [[ "$EXP" > "$TODAY" || "$EXP" == "$TODAY" ]]
then
echo "$USER|$KEY|$EXP" >> "$TMP"
fi

done < "$DB"

mv "$TMP" "$DB"

}

clean_db "$VMESS_DB"
clean_db "$VLESS_DB"
clean_db "$TROJAN_DB"

exit 0
EOF

chmod +x "$XRAY_DIR/expire.sh"

############################
# FINALIZAR INSTALACIÓN
############################

finish_install(){

    install_cron

    rebuild_xray

    restart_xray

    ok "Xray configurado correctamente."

}
############################
# MENÚ VMESS
############################

menu_vmess(){

while true
do

header

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        VMESS MANAGER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo " [1] Crear Usuario"
echo " [2] Eliminar Usuario"
echo " [3] Renovar Usuario"
echo " [4] Listar Usuarios"
echo
echo " [0] Regresar"
echo

read -rp "Opción : " OP

case "$OP" in

1) create_vmess ;;

2) remove_vmess ;;

3) renew_vmess ;;

4) list_vmess ;;

0) break ;;

*) error "Opción inválida"; sleep 2 ;;

esac

done

}

############################
# MENÚ VLESS
############################

menu_vless(){

while true
do

header

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        VLESS MANAGER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo " [1] Crear Usuario"
echo " [2] Eliminar Usuario"
echo " [3] Renovar Usuario"
echo " [4] Listar Usuarios"
echo
echo " [0] Regresar"
echo

read -rp "Opción : " OP

case "$OP" in

1) create_vless ;;

2) remove_vless ;;

3) renew_vless ;;

4) list_vless ;;

0) break ;;

*) error "Opción inválida"; sleep 2 ;;

esac

done

}

############################
# MENÚ TROJAN
############################

menu_trojan(){

while true
do

header

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       TROJAN MANAGER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo " [1] Crear Usuario"
echo " [2] Eliminar Usuario"
echo " [3] Renovar Usuario"
echo " [4] Listar Usuarios"
echo
echo " [0] Regresar"
echo

read -rp "Opción : " OP

case "$OP" in

1) create_trojan ;;

2) remove_trojan ;;

3) renew_trojan ;;

4) list_trojan ;;

0) break ;;

*) error "Opción inválida"; sleep 2 ;;

esac

done

}

############################
# INFORMACIÓN XRAY
############################

info_xray(){

header

echo
echo "Estado : $(service_status xray)"
echo
echo "VMess  : $(wc -l < "$VMESS_DB") Usuarios"
echo "VLESS  : $(wc -l < "$VLESS_DB") Usuarios"
echo "Trojan : $(wc -l < "$TROJAN_DB") Usuarios"
echo

systemctl --no-pager --full status xray

echo

pause

}

############################
# MENÚ PRINCIPAL
############################

menu_xray(){

while true
do

header

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        XRAY MANAGER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo " Estado : $(service_status xray)"
echo

echo " [1] VMess"
echo " [2] VLESS"
echo " [3] Trojan"
echo
echo " [4] Reiniciar Xray"
echo " [5] Estado del Servicio"
echo " [6] Sincronizar Configuración"
echo " [7] Eliminar Cuentas Expiradas"
echo
echo " [0] Regresar"
echo

read -rp "Opción : " OP

case "$OP" in

1)

menu_vmess

;;

2)

menu_vless

;;

3)

menu_trojan

;;

4)

restart_xray

;;

5)

info_xray

;;

6)

sync_xray

;;

7)

remove_expired

;;

0)

break

;;

*)

error "Opción inválida"

sleep 2

;;

esac

done

}

############################
# INICIAR
############################

menu_xray
