#!/bin/bash

#=========================================================
#        KEVINTECH MULTI SCRIPT INSTALLER
#        LICENSE SYSTEM v3.0
#        PREMIUM SERVER EDITION
#=========================================================

set -o pipefail

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
ORANGE="\e[38;5;214m"
AQUA="\e[38;5;159m"

#=========================================================
# VARIABLES
#=========================================================

BASE="/etc/kevintech"
TMP="/tmp/kevintech_install"

REPO="https://github.com/kevinaldaircama/multi-script.git"

LICENSE_API="https://usa.socialstreaming.xyz"
LICENSE_BOT="@multiscriptkeygen_bot"

INSTALL_PROTOCOLS="ON"

SERVER_DOMAIN=""
SERVER_IP=""
DOMAIN_IP=""
DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

SSL_TUNNEL="OFF"
PROXY_STATUS="OFF"

INSTALL_KEY="${INSTALL_KEY:-}"

LICENSE_OWNER=""
LICENSE_RESELLER=""
LICENSE_TYPE="normal"
LICENSE_DELETE_AT=""

CLIENT_IP=""
OS_NAME=""
HOSTNAME_VALUE=""
DATE_NOW=""

#=========================================================
# FUNCIONES VISUALES
#=========================================================

clear_screen() {
    clear 2>/dev/null || true
}

linea() {
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

linea_color() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

titulo() {

    clear_screen

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${PINK}${BOLD}                 KEVINTECH MULTI SCRIPT${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${PURPLE}${BOLD}                 PREMIUM INSTALLER v3.0${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${SKY}              🚀  S E R V E R   E D I T I O N  🚀${RESET}"
    echo

}

seccion() {

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD} $1${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

ok() {
    echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"
}

info() {
    echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"
}

warn() {
    echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

fail() {
    echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"
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

pausa() {
    sleep "${1:-1}"
}

error_exit() {

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}${BOLD}❌ INSTALACIÓN DETENIDA${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"
    echo

    rm -rf "$TMP"

    exit 1
}

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
# SISTEMA OPERATIVO
#=========================================================

if [[ ! -f /etc/os-release ]]; then
    error_exit "No se pudo detectar el sistema operativo."
fi

source /etc/os-release

if [[ "$ID" != "ubuntu" ]]; then
    error_exit "Este instalador solamente es compatible con Ubuntu."
fi

#=========================================================
# CABECERA
#=========================================================

titulo

echo -e "${GREEN}             ● SISTEMA COMPATIBLE DETECTADO ●${RESET}"
echo
echo -e "${WHITE}Sistema : ${SKY}${PRETTY_NAME}${RESET}"
echo -e "${WHITE}Usuario : ${GOLD}root${RESET}"
echo -e "${WHITE}Sistema : ${MAGENTA}KevinTech Multi Script${RESET}"

echo
linea_color

#=========================================================
# PASO 0
# DEPENDENCIAS
#=========================================================

seccion "📦 PASO 0  •  PREPARANDO EL SISTEMA"

echo -e "${GRAY}Instalando las herramientas necesarias para KevinTech.${RESET}"
echo

export DEBIAN_FRONTEND=noninteractive

loading "Actualizando repositorios"

apt-get update -y >/dev/null 2>&1 || \
    error_exit "No se pudieron actualizar los repositorios."

ok "Repositorios actualizados."

loading "Instalando dependencias"

apt-get install -y \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    dnsutils \
    sudo \
    openssl \
    unzip \
    zip \
    tar \
    nano \
    cron \
    net-tools \
    lsof \
    screen \
    bc \
    socat \
    openssh-server \
    ufw \
    fail2ban \
    >/dev/null 2>&1 || \
    error_exit "No se pudieron instalar las dependencias."

update-ca-certificates >/dev/null 2>&1 || true

ok "Dependencias instaladas."

#=========================================================
# SISTEMA DE LICENCIAS
#=========================================================

seccion "🔐 SISTEMA DE LICENCIAS"

echo -e "${WHITE}Obtén tu Key mediante nuestro bot oficial:${RESET}"
echo
echo -e " ${CYAN}🤖 Telegram:${RESET} ${PINK}${BOLD}${LICENSE_BOT}${RESET}"
echo

loading "Comprobando sistema de licencias"

HEALTH_RESPONSE="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        -4 \
        -w '\n%{http_code}' \
        "${LICENSE_API}/health" \
        2>/dev/null
)"

HEALTH_HTTP="$(
    printf '%s\n' "$HEALTH_RESPONSE" |
    tail -n1
)"

HEALTH_BODY="$(
    printf '%s\n' "$HEALTH_RESPONSE" |
    sed '$d'
)"

if [[ "$HEALTH_HTTP" != "200" ]]; then

    fail "Servidor de licencias no disponible."
    echo
    echo -e "${GRAY}Inténtalo nuevamente más tarde.${RESET}"
    echo

    exit 1
fi

if ! echo "$HEALTH_BODY" |
    jq -e '.ok == true' >/dev/null 2>&1; then

    error_exit "El sistema de licencias no está disponible."

fi

ok "Sistema de licencias operativo."

#=========================================================
# PASO 1
# LICENCIA
#=========================================================

seccion "🔑 PASO 1  •  VALIDACIÓN DE LICENCIA"

echo -e "${WHITE}Ingresa la Key proporcionada por KevinTech.${RESET}"
echo
echo -e "${GRAY}¿No tienes una Key?${RESET}"
echo -e " ${CYAN}🤖 Telegram:${RESET} ${PINK}${BOLD}${LICENSE_BOT}${RESET}"
echo

while true; do

    if [[ -z "${INSTALL_KEY:-}" ]]; then

        read -r -p "$(echo -e "${GOLD}🔑 Key de Instalación:${RESET} ")" INSTALL_KEY

    else

        echo -e "${GOLD}🔑 Key de Instalación:${RESET} ${INSTALL_KEY}"

    fi

    INSTALL_KEY="$(
        printf '%s' "$INSTALL_KEY" |
        tr -d '[:space:]'
    )"

    if [[ -z "$INSTALL_KEY" ]]; then

        fail "La Key no puede estar vacía."
        continue

    fi

    loading "Verificando licencia"

    REQUEST_JSON="$(
        jq -n \
            --arg key "$INSTALL_KEY" \
            '{key:$key}'
    )"

    VALIDATE_RESPONSE="$(
        curl \
            --silent \
            --show-error \
            --connect-timeout 5 \
            --max-time 15 \
            -4 \
            -w '\n%{http_code}' \
            -X POST \
            -H "Content-Type: application/json" \
            --data "$REQUEST_JSON" \
            "${LICENSE_API}/api/public/validate" \
            2>/dev/null
    )"

    CURL_STATUS=$?

    VALIDATE_HTTP="$(
        printf '%s\n' "$VALIDATE_RESPONSE" |
        tail -n1
    )"

    VALIDATE_BODY="$(
        printf '%s\n' "$VALIDATE_RESPONSE" |
        sed '$d'
    )"

    if [[ "$CURL_STATUS" -ne 0 ]]; then

        fail "No fue posible conectar con el sistema de licencias."
        pausa 2
        continue

    fi

    if ! echo "$VALIDATE_BODY" |
        jq empty >/dev/null 2>&1; then

        fail "El servidor devolvió una respuesta inválida."
        pausa 2
        continue

    fi

    VALID="$(
        echo "$VALIDATE_BODY" |
        jq -r '.ok // false'
    )"

    ERROR_CODE="$(
        echo "$VALIDATE_BODY" |
        jq -r '.error // empty'
    )"

    if [[ "$VALID" != "true" ]]; then

        echo

        case "$ERROR_CODE" in

            key_not_found)
                fail "KEY NO ENCONTRADA"
                ;;

            key_used)
                fail "KEY YA UTILIZADA"
                ;;

            key_expired)
                warn "KEY EXPIRADA"
                ;;

            key_required)
                fail "NO SE RECIBIÓ UNA KEY"
                ;;

            *)
                fail "LA KEY NO ES VÁLIDA"
                ;;

        esac

        echo
        echo -e "${GRAY}No se instalará ningún archivo.${RESET}"
        pausa 2

        continue
    fi

    LICENSE_OWNER="$(
        echo "$VALIDATE_BODY" |
        jq -r '.owner // "Desconocido"'
    )"

    LICENSE_RESELLER="$(
        echo "$VALIDATE_BODY" |
        jq -r '.reseller // "Desconocido"'
    )"

    LICENSE_TYPE="$(
        echo "$VALIDATE_BODY" |
        jq -r '.type // "normal"'
    )"

    LICENSE_DELETE_AT="$(
        echo "$VALIDATE_BODY" |
        jq -r '.deleteAt // empty'
    )"

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}                 ✅ LICENCIA VÁLIDA${RESET}                  ${GREEN}║${RESET}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}Propietario:${RESET} ${WHITE}${LICENSE_OWNER}${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}Revendedor :${RESET} ${WHITE}${LICENSE_RESELLER}${RESET}"
    echo -e "${GREEN}║${RESET} ${GRAY}Tipo       :${RESET} ${CYAN}${LICENSE_TYPE}${RESET}"

    if [[ -n "$LICENSE_DELETE_AT" &&
          "$LICENSE_DELETE_AT" != "null" ]]; then

        echo -e "${GREEN}║${RESET} ${GRAY}Expira     :${RESET} ${YELLOW}${LICENSE_DELETE_AT}${RESET}"

    fi

    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    ok "Licencia aceptada."

    break

done

#=========================================================
# PASO 2
# SISTEMA
#=========================================================

seccion "⚙️ PASO 2  •  PREPARANDO SERVIDOR"

loading "Configurando OpenSSH"

systemctl enable ssh >/dev/null 2>&1 || true

systemctl restart ssh >/dev/null 2>&1 || \
    error_exit "No se pudo iniciar OpenSSH."

ok "OpenSSH activo."

#=========================================================
# FIREWALL
#=========================================================

info "Configurando firewall..."

ufw --force reset >/dev/null 2>&1 || true

ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1

ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1

ufw --force enable >/dev/null 2>&1 || true

ok "Firewall configurado."

#=========================================================
# SSH HARDENING
#=========================================================

info "Configurando SSH..."

SSHD_CFG="/etc/ssh/sshd_config"

if [[ -f "$SSHD_CFG" ]]; then

    cp "$SSHD_CFG" \
        "${SSHD_CFG}.kevintech.backup"

    sed -i \
        -e '/^[[:space:]]*#\?[[:space:]]*MaxAuthTries[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveInterval[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveCountMax[[:space:]]/d' \
        "$SSHD_CFG"

    cat >> "$SSHD_CFG" <<'EOF'

#=========================================================
# KevinTech SSH configuration
#=========================================================

MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

EOF

fi

if sshd -t >/dev/null 2>&1; then

    systemctl restart ssh

    ok "Configuración SSH válida."

else

    fail "Error en la configuración SSH."

    if [[ -f "${SSHD_CFG}.kevintech.backup" ]]; then

        cp \
            "${SSHD_CFG}.kevintech.backup" \
            "$SSHD_CFG"

        systemctl restart ssh

        ok "Configuración anterior restaurada."

    fi

fi

#=========================================================
# FAIL2BAN
#=========================================================

info "Configurando Fail2Ban..."

mkdir -p /etc/fail2ban

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
backend = systemd
EOF

systemctl enable fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban >/dev/null 2>&1 || true

ok "Fail2Ban configurado."

#=========================================================
# PASO 3
# DOMINIO
#=========================================================

seccion "🌐 PASO 3  •  CONFIGURACIÓN DE DOMINIO"

read -r -p \
"$(echo -e "${CYAN}🌐 Dominio del VPS:${RESET} ")" \
SERVER_DOMAIN

SERVER_DOMAIN="$(
    printf '%s' "$SERVER_DOMAIN" |
    tr -d '[:space:]'
)"

SERVER_IP="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 10 \
        -4 \
        https://api.ipify.org \
        2>/dev/null
)"

[[ -z "$SERVER_IP" ]] &&
    SERVER_IP="Desconocida"

DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

if [[ -n "$SERVER_DOMAIN" ]]; then

    loading "Comprobando DNS"

    DOMAIN_IP="$(
        dig +short A "$SERVER_DOMAIN" |
        grep -E \
        '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
        head -n1
    )"

    if [[ -n "$DOMAIN_IP" &&
          "$DOMAIN_IP" == "$SERVER_IP" ]]; then

        DOMAIN_IP_MATCH="YES"

        ok "El dominio apunta correctamente al VPS."

    else

        warn "El dominio todavía no apunta a este VPS."

        [[ -n "$DOMAIN_IP" ]] && {
            echo -e \
                " ${GRAY}IP encontrada:${RESET} ${YELLOW}$DOMAIN_IP${RESET}"

            echo -e \
                " ${GRAY}IP VPS:${RESET} ${CYAN}$SERVER_IP${RESET}"
        }

    fi

    NS="$(
        dig +short NS "$SERVER_DOMAIN" |
        tr '\n' ' '
    )"

    if echo "$NS" | grep -qi "cloudflare"; then
        DNS_PROVIDER="Cloudflare"

    elif echo "$NS" | grep -Eqi "awsdns|route53"; then
        DNS_PROVIDER="AWS Route 53"

    elif echo "$NS" | grep -Eqi "google"; then
        DNS_PROVIDER="Google Cloud DNS"

    elif echo "$NS" | grep -qi "azure"; then
        DNS_PROVIDER="Azure DNS"

    elif echo "$NS" | grep -qi "namecheap"; then
        DNS_PROVIDER="Namecheap"

    elif echo "$NS" | grep -qi "godaddy"; then
        DNS_PROVIDER="GoDaddy"

    elif echo "$NS" | grep -qi "porkbun"; then
        DNS_PROVIDER="Porkbun"
    fi

    echo -e \
        " ${GRAY}Proveedor DNS:${RESET} ${SKY}$DNS_PROVIDER${RESET}"

else

    warn "No se introdujo ningún dominio."

fi

#=========================================================
# PASO 4
# DESCARGAR KEVINTECH
#=========================================================

seccion "📥 PASO 4  •  INSTALANDO KEVINTECH"

rm -rf "$TMP"
mkdir -p "$TMP"

loading "Descargando repositorio"

if ! git clone \
    --depth 1 \
    "$REPO" \
    "$TMP" >/dev/null 2>&1; then

    rm -rf "$TMP"

    error_exit "No se pudieron descargar los archivos."

fi

ok "Repositorio descargado."

#=========================================================
# INSTALAR ARCHIVOS
#=========================================================

mkdir -p "$BASE"

cp -a "$TMP"/. "$BASE"/ || {

    rm -rf "$TMP"

    error_exit "No se pudieron copiar los archivos."

}

rm -rf "$TMP"

mkdir -p \
    "$BASE/protocolos" \
    "$BASE/usuarios" \
    "$BASE/sistema" \
    "$BASE/logs" \
    "$BASE/herramientas"

find "$BASE" \
    -type f \
    -name "*.sh" \
    -exec chmod +x {} \;

ok "Archivos instalados."

#=========================================================
# CONFIGURACIÓN PRINCIPAL
#=========================================================

cat > "$BASE/config.conf" <<EOF
#=========================================================
# KEVINTECH MULTI SCRIPT
# CONFIGURATION
#=========================================================

SERVER_DOMAIN="$SERVER_DOMAIN"
SERVER_IP="$SERVER_IP"

DNS_PROVIDER="$DNS_PROVIDER"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"

SSL_TUNNEL="OFF"
PROXY_STATUS="OFF"

AUTO_START=OFF

#=========================================================
# LICENCIA
#=========================================================

LICENSE_API="$LICENSE_API"
LICENSE_OWNER="$LICENSE_OWNER"
LICENSE_RESELLER="$LICENSE_RESELLER"
LICENSE_TYPE="$LICENSE_TYPE"
LICENSE_DELETE_AT="$LICENSE_DELETE_AT"

#=========================================================
# PROTOCOLOS
#=========================================================

OPENSSH=ON

DROPBEAR=OFF
SSL=OFF
BADVPN=OFF
UDP_CUSTOM=OFF
HYSTERIA=OFF
SLOWDNS=OFF
XRAY=OFF
V2RAY=OFF
OPENVPN=OFF

ZIPVPN=OFF
WEBSOCKET=OFF
TROJAN=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF

#=========================================================
# SISTEMA
#=========================================================

SYSTEMDNS=OFF
SQUID=OFF
WEBMIN=OFF
FAIL2BAN=ON
BBR=OFF
EOF

#=========================================================
# LICENSE CONF
#=========================================================

cat > "$BASE/license.conf" <<EOF
LICENSE_OWNER="$LICENSE_OWNER"
LICENSE_RESELLER="$LICENSE_RESELLER"
LICENSE_TYPE="$LICENSE_TYPE"
LICENSE_DELETE_AT="$LICENSE_DELETE_AT"
LICENSE_API="$LICENSE_API"
LICENSE_STATUS="VALIDATED"
LICENSE_BOT="$LICENSE_BOT"
EOF

chmod 600 "$BASE/license.conf"

ok "Configuración creada."

#=========================================================
# COMANDO MENU
#=========================================================

cat > /usr/local/bin/menu <<'EOF'
#!/bin/bash

BASE="/etc/kevintech"

if [[ -f "$BASE/menu.sh" ]]; then
    exec bash "$BASE/menu.sh" "$@"
fi

echo "❌ No se encontró $BASE/menu.sh"
exit 1
EOF

chmod +x /usr/local/bin/menu

ok "Comando 'menu' instalado."

#=========================================================
# PASO 5
# ROOT
#=========================================================

seccion "👑 PASO 5  •  ACCESO ROOT"

echo -e "${WHITE}¿Deseas establecer una contraseña para root?${RESET}"
echo
echo -e "${GREEN}Y${RESET} = Establecer contraseña"
echo -e "${RED}N${RESET} = Continuar"
echo

read -r -p \
"$(echo -e "${GOLD}[Y/N]:${RESET} ")" \
ROOT_ACCESS

ROOT_ACCESS="$(
    printf '%s' "$ROOT_ACCESS" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$ROOT_ACCESS" == "y" ]]; then

    echo
    passwd root

    if [[ $? -eq 0 ]]; then

        if [[ -f "$SSHD_CFG" ]]; then

            sed -i \
                -e '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' \
                -e '/^[[:space:]]*#\?[[:space:]]*PasswordAuthentication[[:space:]]/d' \
                "$SSHD_CFG"

            cat >> "$SSHD_CFG" <<'EOF'

#=========================================================
# KevinTech root access
#=========================================================

PermitRootLogin yes
PasswordAuthentication yes

EOF

            if sshd -t >/dev/null 2>&1; then

                systemctl restart ssh

                ok "Acceso root habilitado."

            else

                fail "La configuración SSH no es válida."

            fi
        fi

    else

        fail "No se pudo cambiar la contraseña."

    fi

fi

#=========================================================
# PASO 6
# PROTOCOLOS
#=========================================================

seccion "🚀 PASO 6  •  INSTALACIÓN DE PROTOCOLOS"

echo -e "${WHITE}Instalando los protocolos disponibles en el sistema.${RESET}"
echo

#=========================================================
# FUNCIÓN GENERAL
#=========================================================

instalar_modulo() {

    local NOMBRE="$1"
    local ARCHIVO="$2"
    local VARIABLE="$3"

    echo
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}📦 $NOMBRE${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if [[ ! -f "$ARCHIVO" ]]; then

        warn "$NOMBRE no encontrado."

        echo -e \
            " ${GRAY}Archivo:${RESET} $ARCHIVO"

        return 2
    fi

    chmod +x "$ARCHIVO"

    info "Ejecutando modo automático..."

    if bash "$ARCHIVO" --auto; then

        if [[ -n "$VARIABLE" ]] &&
           grep -q "^${VARIABLE}=ON" "$BASE/config.conf"; then

            ok "$NOMBRE instalado correctamente."

        else

            ok "$NOMBRE finalizó correctamente."

        fi

        return 0

    fi

    fail "$NOMBRE terminó con errores."

    return 1
}

#=========================================================
# OPENSSH
#=========================================================

echo
info "Instalando OpenSSH..."

if apt-get install -y openssh-server >/dev/null 2>&1 &&
   systemctl enable ssh >/dev/null 2>&1 &&
   systemctl restart ssh >/dev/null 2>&1 &&
   systemctl is-active --quiet ssh; then

    sed -i \
        's/^OPENSSH=.*/OPENSSH=ON/' \
        "$BASE/config.conf"

    ok "OpenSSH instalado correctamente."

else

    sed -i \
        's/^OPENSSH=.*/OPENSSH=OFF/' \
        "$BASE/config.conf"

    fail "OpenSSH no pudo iniciarse."

fi

#=========================================================
# SSL TUNNEL
#=========================================================

if instalar_modulo \
    "SSL Tunnel" \
    "$BASE/protocolos/ssl.sh" \
    "SSL"; then

    :

fi

#=========================================================
# XRAY
#=========================================================

XRAY_SCRIPT=""

if [[ -f "$BASE/protocolos/xray.sh" ]]; then

    XRAY_SCRIPT="$BASE/protocolos/xray.sh"

elif [[ -f "$BASE/protocolos/v2ray.sh" ]]; then

    XRAY_SCRIPT="$BASE/protocolos/v2ray.sh"

fi

if [[ -n "$XRAY_SCRIPT" ]]; then

    instalar_modulo \
        "Xray / VMess" \
        "$XRAY_SCRIPT" \
        "XRAY"

else

    warn "No se encontró xray.sh ni v2ray.sh."

fi

#=========================================================
# UDP CUSTOM
#=========================================================

instalar_modulo \
    "UDP Custom" \
    "$BASE/protocolos/udpcustom.sh" \
    "UDP_CUSTOM"

#=========================================================
# PROTOCOLOS AÚN NO DISPONIBLES
#=========================================================

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}${BOLD}PROTOCOLOS DISPONIBLES PARA INSTALACIÓN POSTERIOR${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo
echo -e " ${GRAY}○${RESET} Dropbear"
echo -e " ${GRAY}○${RESET} BadVPN"
echo -e " ${GRAY}○${RESET} ZIPVPN"
echo -e " ${GRAY}○${RESET} Hysteria"
echo -e " ${GRAY}○${RESET} OpenVPN"
echo -e " ${GRAY}○${RESET} SlowDNS"
echo -e " ${GRAY}○${RESET} Trojan"
echo -e " ${GRAY}○${RESET} Shadowsocks"
echo -e " ${GRAY}○${RESET} SOCKS5"

echo
echo -e "${GRAY}Se activarán cuando sus módulos estén instalados.${RESET}"

#=========================================================
# BANNER SSH
#=========================================================

seccion "🎨 CONFIGURANDO BANNER"

cat > /etc/profile.d/kevintech-banner.sh <<'EOF'
#!/bin/bash

[[ $- != *i* ]] && return

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
SKY="\e[38;5;117m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

SERVER="$(hostname)"
DOMAIN="-"

if [[ -f "$CONFIG" ]]; then
    source "$CONFIG" 2>/dev/null
    DOMAIN="${SERVER_DOMAIN:--}"
fi

UPTIME="$(
    uptime -p 2>/dev/null |
    sed 's/up //'
)"

FECHA="$(date '+%d-%m-%Y')"
HORA="$(date '+%H:%M:%S')"

RAM="$(
    free -h 2>/dev/null |
    awk '/Mem:/ {print $3 "/" $2}'
)"

LOAD="$(
    uptime 2>/dev/null |
    awk -F'load average:' '{print $2}' |
    sed 's/^ //'
)"

echo
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${PINK}${BOLD}             🚀 KEVINTECH MULTI SCRIPT 🚀${RESET}           ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET} ${PURPLE}                    SERVER PANEL${RESET}                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e "${CYAN}┌────────────────── SERVIDOR ──────────────────┐${RESET}"

echo -e " ${WHITE}🖥 Servidor :${RESET} ${SKY}$SERVER${RESET}"
echo -e " ${WHITE}🌐 Dominio  :${RESET} ${MAGENTA}$DOMAIN${RESET}"
echo -e " ${WHITE}⏱ Uptime   :${RESET} ${GREEN}${UPTIME:-Desconocido}${RESET}"
echo -e " ${WHITE}💾 RAM      :${RESET} ${GREEN}${RAM:-Desconocida}${RESET}"
echo -e " ${WHITE}⚡ Carga    :${RESET} ${YELLOW}${LOAD:-Desconocida}${RESET}"
echo -e " ${WHITE}📅 Fecha    :${RESET} ${YELLOW}$FECHA${RESET}"
echo -e " ${WHITE}🕐 Hora     :${RESET} ${CYAN}$HORA${RESET}"

echo -e "${CYAN}└─────────────────────────────────────────────┘${RESET}"

echo

#=========================================================
# CRÉDITOS
#=========================================================

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                       ⭐ CRÉDITOS ⭐${RESET}                   ${PURPLE}║${RESET}"
echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Proyecto :${RESET} ${PINK}KevinTech Multi Script${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Autor    :${RESET} ${WHITE}Kevin Aldair Camacho Serna${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Edición  :${RESET} ${SKY}Premium Server Edition${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Soporte  :${RESET} ${MAGENTA}@multiscriptkeygen_bot${RESET}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

if [[ "$EUID" -eq 0 ]]; then

    echo -e " ${GREEN}👑 Usuario:${RESET} ${WHITE}root${RESET}"
    echo -e " ${CYAN}👉 Panel:${RESET} ${WHITE}menu${RESET}"

else

    echo -e " ${YELLOW}👤 Usuario:${RESET} ${WHITE}$(whoami)${RESET}"
    echo -e " ${YELLOW}⚠ Estado:${RESET} ${WHITE}No eres root${RESET}"

fi

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GRAY}          KevinTech Multi Script • Gracias por usarlo${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

EOF

chmod +x /etc/profile.d/kevintech-banner.sh

ok "Banner configurado con sección de créditos."

#=========================================================
# PASO FINAL
# ACTIVACIÓN
#=========================================================

seccion "🔐 REGISTRANDO INSTALACIÓN"

CLIENT_IP="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 10 \
        -4 \
        https://api.ipify.org \
        2>/dev/null
)"

[[ -z "$CLIENT_IP" ]] &&
    CLIENT_IP="Desconocida"

OS_NAME="$(
    grep '^PRETTY_NAME=' /etc/os-release |
    cut -d '"' -f2
)"

HOSTNAME_VALUE="$(hostname)"

DATE_NOW="$(
    date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

echo -e " ${GRAY}IP:${RESET}       ${CYAN}$CLIENT_IP${RESET}"
echo -e " ${GRAY}Hostname:${RESET} ${SKY}$HOSTNAME_VALUE${RESET}"
echo -e " ${GRAY}Sistema:${RESET}  ${WHITE}$OS_NAME${RESET}"

ACTIVATION_JSON="$(
    jq -n \
        --arg key "$INSTALL_KEY" \
        --arg ip "$CLIENT_IP" \
        --arg hostname "$HOSTNAME_VALUE" \
        --arg os "$OS_NAME" \
        --arg date "$DATE_NOW" \
        '{
            key:$key,
            ip:$ip,
            hostname:$hostname,
            os:$os,
            date:$date
        }'
)"

loading "Registrando licencia"

ACTIVATE_RESPONSE="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        -4 \
        -w '\n%{http_code}' \
        -X POST \
        -H "Content-Type: application/json" \
        --data "$ACTIVATION_JSON" \
        "${LICENSE_API}/api/public/activate" \
        2>/dev/null
)"

ACTIVATE_STATUS=$?

ACTIVATE_HTTP="$(
    printf '%s\n' "$ACTIVATE_RESPONSE" |
    tail -n1
)"

ACTIVATE_BODY="$(
    printf '%s\n' "$ACTIVATE_RESPONSE" |
    sed '$d'
)"

if [[ "$ACTIVATE_STATUS" -ne 0 ]]; then

    fail "No se pudo conectar con el sistema de activación."
    echo
    echo -e "${YELLOW}La licencia no fue marcada como utilizada.${RESET}"

    exit 1
fi

if ! echo "$ACTIVATE_BODY" |
    jq empty >/dev/null 2>&1; then

    fail "El sistema devolvió una respuesta inválida."

    exit 1
fi

ACTIVATE_OK="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.ok // false'
)"

ACTIVATE_ERROR="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.error // empty'
)"

if [[ "$ACTIVATE_OK" != "true" ]]; then

    fail "No se pudo registrar la activación."

    echo
    echo -e \
        "${YELLOW}Código: ${ACTIVATE_ERROR:-desconocido}${RESET}"

    exit 1
fi

ACTIVATION_ID="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.activationId // empty'
)"

echo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}              ✅ ACTIVACIÓN COMPLETADA${RESET}                ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

[[ -n "$ACTIVATION_ID" ]] &&
    echo -e \
        "${GRAY}ID de activación:${RESET} ${CYAN}${ACTIVATION_ID}${RESET}"

ok "La Key fue marcada como utilizada."

#=========================================================
# ESTADO LOCAL
#=========================================================

if [[ -f "$BASE/license.conf" ]]; then

    sed -i \
        's/^LICENSE_STATUS=.*/LICENSE_STATUS="ACTIVE"/' \
        "$BASE/license.conf"

    chmod 600 "$BASE/license.conf"

fi

#=========================================================
# PERMISOS
#=========================================================

chmod -R 755 "$BASE"
chmod 600 "$BASE/license.conf"

#=========================================================
# LIMPIEZA
#=========================================================

unset INSTALL_KEY
unset ACTIVATION_JSON
unset VALIDATE_RESPONSE
unset ACTIVATE_RESPONSE

rm -rf "$TMP"

#=========================================================
# FINAL
#=========================================================

titulo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}             🎉 INSTALACIÓN COMPLETADA 🎉${RESET}             ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e " ${GREEN}●${RESET} ${WHITE}Servidor:${RESET}    ${GREEN}LISTO${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Licencia:${RESET}    ${GREEN}ACTIVA${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Propietario:${RESET} ${WHITE}$LICENSE_OWNER${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Revendedor:${RESET}  ${WHITE}$LICENSE_RESELLER${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Tipo:${RESET}        ${CYAN}$LICENSE_TYPE${RESET}"

echo

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${PURPLE}║${RESET} ${WHITE}${BOLD}                 INFORMACIÓN DEL VPS${RESET}                   ${PURPLE}║${RESET}"
echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}Dominio:${RESET} ${SKY}${SERVER_DOMAIN:-No configurado}${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}IP     :${RESET} ${CYAN}${SERVER_IP}${RESET}"
echo -e "${PURPLE}║${RESET} ${GRAY}DNS    :${RESET} ${MAGENTA}${DNS_PROVIDER}${RESET}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                     ⭐ CRÉDITOS ⭐${RESET}                    ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY}Proyecto :${RESET} ${PINK}KevinTech Multi Script${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY}Autor    :${RESET} ${WHITE}Kevin tech tutorials${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY} dueño de la infraestructura:${RESET} ${SKY}@Dan3651${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY} bot de key:${RESET} ${MAGENTA}${LICENSE_BOT}${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e "${GOLD}🚀 KevinTech Multi Script está listo.${RESET}"
echo
echo -e "${CYAN}👉 Escribe ${WHITE}menu${CYAN} para abrir el panel.${RESET}"

echo

read -r -p \
"$(echo -e "${YELLOW}¿Reiniciar el servidor ahora? [Y/N]:${RESET} ")" \
REBOOT_SERVER

REBOOT_SERVER="$(
    printf '%s' "$REBOOT_SERVER" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$REBOOT_SERVER" == "y" ]]; then

    echo
    echo -e "${YELLOW}🔄 Reiniciando en 5 segundos...${RESET}"

    for i in 5 4 3 2 1; do

        echo -ne \
            "\r${CYAN}Reinicio en ${WHITE}${i}${CYAN}...${RESET}"

        sleep 1

    done

    echo

    reboot

else

    echo
    echo -e "${GREEN}✅ Instalación finalizada sin reiniciar.${RESET}"
    echo
    echo -e \
        "${CYAN}👉 Escribe ${WHITE}menu${CYAN} para abrir el panel.${RESET}"
    echo

fi

exit 0