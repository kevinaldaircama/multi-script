#!/bin/bash

#=========================================================
#        KEVINTECH MULTI SCRIPT INSTALLER
#        LICENSE SYSTEM v2.2
#        PREMIUM COLOR EDITION
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

# Colores 256
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

#=========================================================
# API DE LICENCIAS
# IMPORTANTE:
# NO SE MUESTRA EN PANTALLA
#=========================================================

LICENSE_API="https://usa.socialstreaming.xyz"

# Bot visible para el usuario
LICENSE_BOT="@multiscriptkeygen_bot"

#=========================================================
# CONFIGURACIÓN
#=========================================================

INSTALL_PROTOCOLS="ON"

SERVER_DOMAIN=""
SERVER_IP=""
DOMAIN_IP=""
DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

SSL_TUNNEL="OFF"
PROXY_STATUS="OFF"

INSTALL_KEY=""
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
    echo -e "${CYAN}║${RESET} ${PURPLE}                 PREMIUM INSTALLER v2.2${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${SKY}                 🚀  S E R V E R   E D I T I O N  🚀${RESET}"
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
        sleep 0.18
    done

    echo

}

barra() {

    local TEXT="$1"
    local WIDTH=35

    echo -ne " ${SKY}${TEXT}${RESET} ["

    for ((i=0; i<WIDTH; i++)); do
        echo -ne "${CYAN}█${RESET}"
        sleep 0.015
    done

    echo "] ${GREEN}100%${RESET}"

}

error_exit() {

    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}${BOLD}❌ INSTALACIÓN DETENIDA${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e " ${RED}✖${RESET} ${WHITE}$1${RESET}"
    echo
    exit 1

}

pausa() {
    sleep "${1:-1}"
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
# UBUNTU CHECK
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
echo -e "${WHITE}Licencia: ${MAGENTA}KevinTech License System${RESET}"
echo
linea_color

#=========================================================
# PASO 0
# DEPENDENCIAS
#=========================================================

seccion "📦 PASO 0  •  PREPARANDO EL SISTEMA"

echo -e "${GRAY}Inicializando componentes necesarios...${RESET}"
echo

loading "Actualizando repositorios"

export DEBIAN_FRONTEND=noninteractive

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
    >/dev/null 2>&1 || \
    error_exit "No se pudieron instalar las dependencias."

update-ca-certificates >/dev/null 2>&1 || true

ok "Dependencias instaladas."
echo

#=========================================================
# VERIFICAR API
#=========================================================

seccion "🔐 SISTEMA DE LICENCIAS"

echo -e "${WHITE}Obtén tu Key mediante nuestro bot oficial:${RESET}"
echo
echo -e " ${CYAN}🤖 Telegram:${RESET} ${PINK}${BOLD}${LICENSE_BOT}${RESET}"
echo
echo -e "${GRAY}La validación se realiza automáticamente.${RESET}"
echo
echo -e "${WHITE} basado del bot de @Dan3651 tg:${RESET}"
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

    echo
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

    read -r -p "$(echo -e "${GOLD}🔑 Key de Instalación:${RESET} ")" INSTALL_KEY

    INSTALL_KEY="$(
        printf '%s' "$INSTALL_KEY" |
        tr -d '[:space:]'
    )"

    if [[ -z "$INSTALL_KEY" ]]; then

        echo
        fail "La Key no puede estar vacía."
        echo

        continue

    fi

    echo
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

        echo
        fail "No fue posible conectar con el sistema de licencias."
        echo
        pausa 2
        continue

    fi

    if ! echo "$VALIDATE_BODY" |
        jq empty >/dev/null 2>&1; then

        echo
        fail "El servidor devolvió una respuesta inválida."
        echo
        pausa 2
        continue

    fi

    VALID="$(
        echo "$VALIDATE_BODY" |
        jq -r '.valid // false'
    )"

    ERROR_CODE="$(
        echo "$VALIDATE_BODY" |
        jq -r '.error // empty'
    )"

    if [[ "$VALID" != "true" ]]; then

        echo

        case "$ERROR_CODE" in

            key_not_found)
                echo -e "${RED}╭──────────────────────────────────────────────╮${RESET}"
                echo -e "${RED}│${RESET} ${WHITE}❌ KEY NO ENCONTRADA${RESET}"
                echo -e "${RED}╰──────────────────────────────────────────────╯${RESET}"
                ;;

            key_used)
                echo -e "${RED}╭──────────────────────────────────────────────╮${RESET}"
                echo -e "${RED}│${RESET} ${WHITE}❌ KEY YA UTILIZADA${RESET}"
                echo -e "${RED}╰──────────────────────────────────────────────╯${RESET}"
                ;;

            key_expired)
                echo -e "${YELLOW}╭──────────────────────────────────────────────╮${RESET}"
                echo -e "${YELLOW}│${RESET} ${WHITE}⚠ KEY EXPIRADA${RESET}"
                echo -e "${YELLOW}╰──────────────────────────────────────────────╯${RESET}"
                ;;

            key_required)
                fail "No se recibió una Key."
                ;;

            *)
                fail "La Key no es válida."
                ;;

        esac

        echo
        echo -e "${GRAY}No se instalará ningún archivo.${RESET}"
        echo

        pausa 2
        continue

    fi

    #=====================================================
    # DATOS DE LICENCIA
    #=====================================================

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
    echo

    ok "Licencia aceptada."
    echo

    break

done

#=========================================================
# PASO 2
# SISTEMA
#=========================================================

seccion "⚙️ PASO 2  •  PREPARANDO SERVIDOR"

echo -e "${GRAY}Configurando componentes principales del VPS.${RESET}"
echo

loading "Actualizando paquetes"

apt-get update -y >/dev/null 2>&1 || \
    error_exit "Error actualizando repositorios."

loading "Instalando componentes"

apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    tar \
    sudo \
    nano \
    cron \
    net-tools \
    dnsutils \
    lsof \
    screen \
    jq \
    bc \
    socat \
    openssl \
    ca-certificates \
    openssh-server \
    ufw \
    fail2ban \
    >/dev/null 2>&1 || \
    error_exit "No se pudieron instalar todos los paquetes."

ok "Componentes instalados."

#=========================================================
# OPENSSH
#=========================================================

echo
info "Configurando OpenSSH..."

systemctl enable ssh >/dev/null 2>&1 || true

systemctl restart ssh >/dev/null 2>&1 || \
    error_exit "No se pudo iniciar OpenSSH."

ok "OpenSSH activo."

#=========================================================
# FIREWALL
#=========================================================

echo
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

echo
info "Aplicando seguridad SSH..."

SSHD_CFG="/etc/ssh/sshd_config"

if [[ -f "$SSHD_CFG" ]]; then

    cp "$SSHD_CFG" "${SSHD_CFG}.kevintech.backup"

    sed -i \
        -e '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*PasswordAuthentication[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*MaxAuthTries[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveInterval[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveCountMax[[:space:]]/d' \
        "$SSHD_CFG"

    cat >> "$SSHD_CFG" <<'EOF'

#=========================================================
# KevinTech SSH configuration
#=========================================================

PermitRootLogin prohibit-password
PasswordAuthentication yes
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

echo
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

read -r -p "$(echo -e "${CYAN}🌐 Dominio del VPS:${RESET} ")" SERVER_DOMAIN

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

if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP="Desconocida"
fi

DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

if [[ -n "$SERVER_DOMAIN" ]]; then

    echo
    loading "Comprobando DNS"

    DOMAIN_IP="$(
        dig +short A "$SERVER_DOMAIN" |
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
        head -n1
    )"

    if [[ -n "$DOMAIN_IP" &&
          "$DOMAIN_IP" == "$SERVER_IP" ]]; then

        DOMAIN_IP_MATCH="YES"

        ok "El dominio apunta correctamente al VPS."

    else

        warn "El dominio todavía no apunta a este VPS."

        if [[ -n "$DOMAIN_IP" ]]; then

            echo -e " ${GRAY}IP encontrada:${RESET} ${YELLOW}$DOMAIN_IP${RESET}"
            echo -e " ${GRAY}IP del VPS:   ${RESET} ${CYAN}$SERVER_IP${RESET}"

        fi

    fi

    NS="$(
        dig +short NS "$SERVER_DOMAIN" |
        tr '\n' ' '
    )"

    if echo "$NS" | grep -qi "cloudflare"; then
        DNS_PROVIDER="Cloudflare"

    elif echo "$NS" | grep -Eqi "awsdns|route53"; then
        DNS_PROVIDER="AWS Route 53"

    elif echo "$NS" | grep -Eqi "googledomains|google"; then
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

    echo -e " ${GRAY}Proveedor DNS:${RESET} ${SKY}$DNS_PROVIDER${RESET}"

else

    warn "No se introdujo ningún dominio."

fi

#=========================================================
# PASO 4
# DESCARGAR SISTEMA
#=========================================================

seccion "📥 PASO 4  •  INSTALANDO KEVINTECH"

echo -e "${GRAY}Descargando los componentes oficiales del sistema.${RESET}"
echo

rm -rf "$TMP"
mkdir -p "$TMP"

loading "Conectando con repositorio"

if ! git clone \
    --depth 1 \
    "$REPO" \
    "$TMP" >/dev/null 2>&1; then

    rm -rf "$TMP"

    error_exit "No se pudieron descargar los archivos."

fi

ok "Archivos descargados."

#=========================================================
# BACKUPS
#=========================================================

echo
info "Creando copias de seguridad..."

if [[ -f "$BASE/config.conf" ]]; then
    cp "$BASE/config.conf" "$BASE/config.conf.kevintech.backup"
fi

if [[ -f "$BASE/license.conf" ]]; then
    cp "$BASE/license.conf" "$BASE/license.conf.kevintech.backup"
fi

ok "Backups preparados."

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
    "$BASE/logs"

ok "Archivos instalados."

#=========================================================
# CONFIGURACIÓN
#=========================================================

cat > "$BASE/config.conf" <<EOF
#=========================================================
# KEVINTECH CONFIGURATION
#=========================================================

SERVER_DOMAIN="$SERVER_DOMAIN"
SERVER_IP="$SERVER_IP"

DNS_PROVIDER="$DNS_PROVIDER"

SSL_TUNNEL="$SSL_TUNNEL"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"

PROXY_STATUS="$PROXY_STATUS"

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
SYSTEMDNS=OFF
WEBSOCKET=OFF
ZIPVPN=OFF
DROPBEAR=OFF
SSL=OFF

BADVPN=OFF
UDP_CUSTOM=OFF
HYSTERIA=OFF

SLOWDNS=OFF
V2RAY=OFF
XRAY=OFF

OPENVPN=OFF
SQUID=OFF
TROJAN=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF

WEBMIN=OFF
FAIL2BAN=ON
BBR=OFF
EOF

#=========================================================
# LICENSE CONF
# NO SE GUARDA LA KEY
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

#=========================================================
# PERMISOS
#=========================================================

chmod -R 755 "$BASE"
chmod 600 "$BASE/license.conf"

ok "Permisos configurados."

#=========================================================
# COMANDO MENU
#=========================================================

cat > /usr/local/bin/menu <<'EOF'
#!/bin/bash

if [[ -f /etc/kevintech/menu.sh ]]; then
    exec bash /etc/kevintech/menu.sh "$@"
else
    echo "❌ No se encontró /etc/kevintech/menu.sh"
    exit 1
fi
EOF

chmod +x /usr/local/bin/menu

ok "Comando 'menu' instalado."

#=========================================================
# PASO 5
# ROOT
#=========================================================

seccion "👑 PASO 5  •  ACCESO ROOT"

echo -e "${WHITE}Puedes establecer una contraseña para root.${RESET}"
echo
echo -e "${GREEN}Y${RESET} = Establecer contraseña root"
echo -e "${RED}N${RESET} = Continuar sin modificar"
echo

read -r -p "$(echo -e "${GOLD}[Y/N]:${RESET} ")" ROOT_ACCESS

ROOT_ACCESS="$(
    printf '%s' "$ROOT_ACCESS" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$ROOT_ACCESS" == "y" ]]; then

    echo
    echo -e "${YELLOW}Introduce la nueva contraseña de root:${RESET}"
    echo

    if passwd root; then

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

    pausa 2

fi

#=========================================================
# PASO 6
# PROTOCOLOS
#=========================================================

seccion "🚀 PASO 6  •  INSTALACIÓN DE PROTOCOLOS"

echo -e "${WHITE}Protocolos seleccionados para instalación automática:${RESET}"
echo

echo -e " ${CYAN}◆${RESET} ${WHITE}BadVPN${RESET}"
echo -e " ${PURPLE}◆${RESET} ${WHITE}SSL / TLS${RESET}"
echo -e " ${MAGENTA}◆${RESET} ${WHITE}ZIPVPN${RESET}"
echo -e " ${SKY}◆${RESET} ${WHITE}UDP Hysteria${RESET}"
echo -e " ${GREEN}◆${RESET} ${WHITE}OpenVPN${RESET}"
echo -e " ${GOLD}◆${RESET} ${WHITE}Xray / V2Ray${RESET}"
echo -e " ${PINK}◆${RESET} ${WHITE}Dropbear${RESET}"
echo -e " ${AQUA}◆${RESET} ${WHITE}UDP Custom${RESET}"
echo

pausa 2

if [[ "$INSTALL_PROTOCOLS" == "ON" ]]; then

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}             INSTALANDO PROTOCOLOS${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    instalar_protocolo() {

        local NOMBRE="$1"
        local ARCHIVO="$2"

        if [[ -f "$ARCHIVO" ]]; then

            echo
            echo -e "${PURPLE}┌──────────────────────────────────────────────────────────────┐${RESET}"
            echo -e "${PURPLE}│${RESET} ${WHITE}📦 $NOMBRE${RESET}"
            echo -e "${PURPLE}└──────────────────────────────────────────────────────────────┘${RESET}"

            if bash "$ARCHIVO" --auto; then

                ok "$NOMBRE instalado correctamente."

            else

                warn "$NOMBRE terminó con errores."

            fi

        else

            warn "No existe el módulo de $NOMBRE."
            echo -e " ${GRAY}$ARCHIVO${RESET}"

        fi

    }

    instalar_protocolo \
        "BadVPN" \
        "$BASE/protocolos/badvpn.sh"

    instalar_protocolo \
        "SSL Tunnel" \
        "$BASE/protocolos/ssl.sh"

    instalar_protocolo \
        "ZIPVPN" \
        "$BASE/protocolos/zipvpn.sh"

    instalar_protocolo \
        "UDP Hysteria" \
        "$BASE/protocolos/udphisteria.sh"

    instalar_protocolo \
        "OpenVPN" \
        "$BASE/protocolos/openvpn.sh"

    instalar_protocolo \
        "V2Ray / Xray" \
        "$BASE/protocolos/v2ray.sh"

    instalar_protocolo \
        "Dropbear" \
        "$BASE/protocolos/dropbear.sh"

    instalar_protocolo \
        "UDP Custom" \
        "$BASE/protocolos/udpcustom.sh"

fi

#=========================================================
# BANNER
#=========================================================

cat > /etc/profile.d/kevintech-banner.sh <<'EOF'
#!/bin/bash

[[ $- != *i* ]] && return

SERVER="$(hostname)"
DOMAIN="-"

if [[ -f /etc/kevintech/config.conf ]]; then

    source /etc/kevintech/config.conf

    DOMAIN="${SERVER_DOMAIN:--}"

fi

UPTIME="$(
    uptime -p 2>/dev/null |
    sed 's/up //'
)"

FECHA="$(date '+%d-%m-%Y')"
HORA="$(date '+%H:%M:%S')"

echo
echo -e "\e[1;96m╔══════════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[1;96m║\e[0m              \e[1;95m🚀 KEVINTECH MULTI SCRIPT 🚀\e[0m              \e[1;96m║\e[0m"
echo -e "\e[1;96m╚══════════════════════════════════════════════════════════════╝\e[0m"
echo
echo -e " \e[1;97mServidor :\e[0m \e[1;96m$SERVER\e[0m"
echo -e " \e[1;97mDominio  :\e[0m \e[1;95m$DOMAIN\e[0m"
echo -e " \e[1;97mUptime   :\e[0m \e[1;92m$UPTIME\e[0m"
echo -e " \e[1;97mFecha    :\e[0m \e[1;93m$FECHA\e[0m"
echo -e " \e[1;97mHora     :\e[0m \e[1;94m$HORA\e[0m"
echo
echo -e " \e[1;96m🤖 Licencias:\e[0m \e[1;95m@multiscriptkeygen_bot\e[0m"
echo -e "\e[1;96m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

if [[ "$EUID" -ne 0 ]]; then

    echo -e " 👤 Usuario : $(whoami)"
    echo -e " 🔒 Estado  : No eres root"
    echo -e " 👉 Ejecuta: \e[1;96msudo -i\e[0m"

else

    echo -e " 👑 Usuario : \e[1;92mroot\e[0m"
    echo -e " 👉 Panel   : \e[1;96mmenu\e[0m"

fi

echo
EOF

chmod +x /etc/profile.d/kevintech-banner.sh

#=========================================================
# PASO FINAL
# ACTIVAR KEY
#=========================================================

seccion "🔐 REGISTRANDO INSTALACIÓN"

echo -e "${GRAY}Registrando la activación de esta instalación...${RESET}"
echo

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

if [[ -z "$CLIENT_IP" ]]; then
    CLIENT_IP="Desconocida"
fi

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
echo

#=========================================================
# JSON ACTIVACIÓN
#=========================================================

ACTIVATION_JSON="$(
    jq -n \
        --arg key "$INSTALL_KEY" \
        --arg ip "$CLIENT_IP" \
        --arg hostname "$HOSTNAME_VALUE" \
        --arg os "$OS_NAME" \
        --arg date "$DATE_NOW" \
        '{
            key: $key,
            ip: $ip,
            hostname: $hostname,
            os: $os,
            date: $date
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

    echo
    fail "No se pudo conectar con el sistema de activación."
    echo
    echo -e "${YELLOW}La licencia no fue marcada como utilizada.${RESET}"
    echo
    exit 1

fi

if ! echo "$ACTIVATE_BODY" |
    jq empty >/dev/null 2>&1; then

    echo
    fail "El sistema devolvió una respuesta inválida."
    echo
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

    echo
    fail "No se pudo registrar la activación."
    echo
    echo -e "${YELLOW}Código: ${ACTIVATE_ERROR:-desconocido}${RESET}"
    echo
    echo -e "${RED}La instalación no será declarada como completada.${RESET}"
    echo

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

if [[ -n "$ACTIVATION_ID" ]]; then
    echo -e "${GRAY}ID de activación:${RESET} ${CYAN}${ACTIVATION_ID}${RESET}"
    echo
fi

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
# LIMPIAR VARIABLES SENSIBLES
#=========================================================

unset INSTALL_KEY
unset ACTIVATION_JSON
unset VALIDATE_RESPONSE
unset ACTIVATE_RESPONSE

#=========================================================
# LIMPIEZA
#=========================================================

rm -rf "$TMP"

#=========================================================
# FINAL
#=========================================================

titulo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}             🎉 INSTALACIÓN COMPLETADA 🎉${RESET}             ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

echo -e " ${GREEN}●${RESET} ${WHITE}Servidor:${RESET} ${CYAN}LISTO${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Licencia:${RESET} ${GREEN}ACTIVA${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Propietario:${RESET} ${WHITE}$LICENSE_OWNER${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Revendedor:${RESET} ${WHITE}$LICENSE_RESELLER${RESET}"
echo -e " ${GREEN}●${RESET} ${WHITE}Tipo:${RESET} ${CYAN}$LICENSE_TYPE${RESET}"

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
echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                 🔐 SOPORTE Y LICENCIAS${RESET}                ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY}Bot oficial:${RESET} ${PINK}${BOLD}${LICENSE_BOT}${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY}Panel      :${RESET} ${GREEN}menu${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo
echo -e "${GOLD}🚀 KevinTech Multi Script está listo.${RESET}"
echo

echo -e "${YELLOW}¿Reiniciar el servidor ahora? [Y/N]${RESET}"

read -r -p "$(echo -e "${CYAN}[Y/N]:${RESET} ")" REBOOT_SERVER

REBOOT_SERVER="$(
    printf '%s' "$REBOOT_SERVER" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$REBOOT_SERVER" == "y" ]]; then

    echo
    echo -e "${YELLOW}🔄 Reiniciando en 5 segundos...${RESET}"

    for i in 5 4 3 2 1; do
        echo -ne "\r${CYAN}Reinicio en ${WHITE}${i}${CYAN}...${RESET}"
        sleep 1
    done

    echo
    reboot

else

    echo
    echo -e "${GREEN}✅ Instalación finalizada sin reiniciar.${RESET}"
    echo
    echo -e "${CYAN}👉 Escribe ${WHITE}menu${CYAN} para abrir el panel.${RESET}"
    echo

fi

exit 0
