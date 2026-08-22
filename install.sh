#!/bin/bash

#=========================================================
#          KEVINTECH MULTI SCRIPT INSTALLER
#          LICENSE SYSTEM v2.1
#=========================================================

set -o pipefail

#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"
RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
MAGENTA="\e[1;95m"
GRAY="\e[1;90m"

#=========================================================
# VARIABLES
#=========================================================

BASE="/etc/kevintech"
TMP="/tmp/kevintech_install"

REPO="https://github.com/kevinaldaircama/multi-script.git"

#=========================================================
# SERVIDOR DE LICENCIAS
#=========================================================

LICENSE_API="https://usa.socialstreaming.xyz"

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
# FUNCIONES
#=========================================================

error_exit() {

    echo
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${RED}❌ $1${RESET}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    exit 1
}

titulo() {

    clear 2>/dev/null || true

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}             $1${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}

pausa() {
    sleep "${1:-1}"
}

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo -e "${RED}❌ Este instalador necesita permisos ROOT.${RESET}"
    echo
    echo "Ejecuta:"
    echo
    echo "sudo -i"
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

titulo "🛡️ KevinTech Multi Script 🛡️"

echo -e "${GREEN}✔ Sistema Ubuntu detectado${RESET}"
echo
echo -e "${GRAY}Servidor de licencias:${RESET}"
echo -e "${CYAN}${LICENSE_API}${RESET}"
echo

#=========================================================
# PASO 0
# DEPENDENCIAS
#=========================================================

echo -e "${YELLOW}📦 Preparando dependencias...${RESET}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y >/dev/null 2>&1 || \
    error_exit "No se pudieron actualizar los repositorios."

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

echo -e "${GREEN}✅ Dependencias listas.${RESET}"

#=========================================================
# VERIFICAR API
#=========================================================

echo
echo -e "${YELLOW}🔐 Comprobando servidor de licencias...${RESET}"

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
    echo -e "${RED}❌ Servidor de licencias HTTP: $HEALTH_HTTP${RESET}"
    echo
    error_exit "No se pudo comprobar el servidor de licencias."

fi

if ! echo "$HEALTH_BODY" |
    jq -e '.ok == true' >/dev/null 2>&1; then

    error_exit "El servidor de licencias no está disponible."

fi

echo -e "${GREEN}✅ Servidor de licencias disponible.${RESET}"

#=========================================================
# PASO 1
# VALIDACIÓN DE LICENCIA
#=========================================================

titulo "PASO 1 - VALIDACIÓN DE LICENCIA"

echo -e "${WHITE}Introduce la Key proporcionada por KevinTech.${RESET}"
echo
echo -e "${GRAY}La Key será validada en:${RESET}"
echo -e "${CYAN}${LICENSE_API}${RESET}"
echo

while true; do

    read -r -p "🔑 Introduce tu Key de Instalación: " INSTALL_KEY

    INSTALL_KEY="$(
        printf '%s' "$INSTALL_KEY" |
        tr -d '[:space:]'
    )"

    if [[ -z "$INSTALL_KEY" ]]; then

        echo
        echo -e "${RED}❌ La Key no puede estar vacía.${RESET}"
        echo

        continue

    fi

    echo
    echo -e "${YELLOW}🔐 Verificando licencia...${RESET}"

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
        echo -e "${RED}❌ No fue posible conectar con el servidor.${RESET}"
        echo -e "${YELLOW}Comprueba la conexión a Internet del VPS.${RESET}"
        echo

        pausa 2
        continue

    fi

    if ! echo "$VALIDATE_BODY" |
        jq empty >/dev/null 2>&1; then

        echo
        echo -e "${RED}❌ El servidor devolvió una respuesta inválida.${RESET}"
        echo
        echo -e "${GRAY}HTTP: $VALIDATE_HTTP${RESET}"
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

    #=====================================================
    # KEY INVÁLIDA
    #=====================================================

    if [[ "$VALID" != "true" ]]; then

        echo

        case "$ERROR_CODE" in

            key_not_found)
                echo -e "${RED}❌ La Key no existe.${RESET}"
                ;;

            key_used)
                echo -e "${RED}❌ La Key ya fue utilizada.${RESET}"
                ;;

            key_expired)
                echo -e "${RED}❌ La Key ha expirado.${RESET}"
                ;;

            key_required)
                echo -e "${RED}❌ No se recibió una Key.${RESET}"
                ;;

            *)
                echo -e "${RED}❌ Key inválida.${RESET}"
                ;;

        esac

        echo
        echo -e "${YELLOW}No se instalará ningún archivo.${RESET}"
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
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}✅ LICENCIA VÁLIDA${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    echo -e "${WHITE}Propietario :${RESET} $LICENSE_OWNER"
    echo -e "${WHITE}Revendedor  :${RESET} $LICENSE_RESELLER"
    echo -e "${WHITE}Tipo        :${RESET} $LICENSE_TYPE"

    if [[ -n "$LICENSE_DELETE_AT" &&
          "$LICENSE_DELETE_AT" != "null" ]]; then

        echo -e "${WHITE}Expira      :${RESET} $LICENSE_DELETE_AT"

    fi

    echo
    echo -e "${GREEN}✔ Licencia aceptada.${RESET}"
    echo

    break

done

#=========================================================
# PASO 2
# PREPARAR SISTEMA
#=========================================================

titulo "PASO 2 - PREPARANDO EL SISTEMA"

echo -e "${GREEN}✔ Actualizando repositorios${RESET}"
echo -e "${GREEN}✔ Instalando dependencias${RESET}"
echo -e "${GREEN}✔ Configurando OpenSSH${RESET}"
echo -e "${GREEN}✔ Configurando seguridad${RESET}"
echo

apt-get update -y >/dev/null 2>&1 || \
    error_exit "Error actualizando repositorios."

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

echo -e "${GREEN}✅ Paquetes instalados.${RESET}"

#=========================================================
# OPENSSH
#=========================================================

echo
echo -e "${YELLOW}🔐 Configurando OpenSSH...${RESET}"

systemctl enable ssh >/dev/null 2>&1 || true

systemctl restart ssh >/dev/null 2>&1 || \
    error_exit "No se pudo iniciar OpenSSH."

echo -e "${GREEN}✅ OpenSSH activo.${RESET}"

#=========================================================
# FIREWALL
#=========================================================

echo
echo -e "${YELLOW}🛡️ Configurando firewall...${RESET}"

ufw --force reset >/dev/null 2>&1 || true

ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1

ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1

ufw --force enable >/dev/null 2>&1 || true

echo -e "${GREEN}✅ Firewall configurado.${RESET}"

#=========================================================
# SSH HARDENING
#=========================================================

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

    echo -e "${GREEN}✅ Configuración SSH válida.${RESET}"

else

    echo -e "${RED}❌ Error en la configuración SSH.${RESET}"
    echo -e "${YELLOW}Restaurando configuración anterior...${RESET}"

    if [[ -f "${SSHD_CFG}.kevintech.backup" ]]; then

        cp \
            "${SSHD_CFG}.kevintech.backup" \
            "$SSHD_CFG"

        systemctl restart ssh

    fi

fi

#=========================================================
# FAIL2BAN
#=========================================================

echo
echo -e "${YELLOW}🛡️ Configurando Fail2Ban...${RESET}"

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

echo -e "${GREEN}✅ Fail2Ban configurado.${RESET}"

#=========================================================
# PASO 3
# DOMINIO
#=========================================================

titulo "PASO 3 - CONFIGURAR DOMINIO"

read -r -p "🌐 Escribe el dominio que apunta a este VPS: " SERVER_DOMAIN

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
    echo -e "${YELLOW}🔎 Verificando dominio...${RESET}"

    DOMAIN_IP="$(
        dig +short A "$SERVER_DOMAIN" |
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' |
        head -n1
    )"

    if [[ -n "$DOMAIN_IP" &&
          "$DOMAIN_IP" == "$SERVER_IP" ]]; then

        DOMAIN_IP_MATCH="YES"

        echo -e "${GREEN}✅ El dominio apunta correctamente al VPS.${RESET}"

    else

        echo -e "${YELLOW}⚠️ El dominio todavía no apunta a este VPS.${RESET}"

        if [[ -n "$DOMAIN_IP" ]]; then

            echo "IP encontrada: $DOMAIN_IP"
            echo "IP del VPS:    $SERVER_IP"

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

    echo "Proveedor DNS: $DNS_PROVIDER"

else

    echo -e "${YELLOW}⚠️ No se introdujo ningún dominio.${RESET}"

fi

#=========================================================
# PASO 4
# DESCARGAR SISTEMA
#=========================================================

titulo "PASO 4 - INSTALANDO SISTEMA"

echo -e "${YELLOW}📥 Descargando archivos desde GitHub...${RESET}"

rm -rf "$TMP"

mkdir -p "$TMP"

if ! git clone \
    --depth 1 \
    "$REPO" \
    "$TMP" >/dev/null 2>&1; then

    rm -rf "$TMP"

    error_exit \
        "No se pudieron descargar los archivos desde GitHub."

fi

echo -e "${GREEN}✅ Archivos descargados.${RESET}"

#=========================================================
# BACKUPS
#=========================================================

if [[ -f "$BASE/config.conf" ]]; then

    cp \
        "$BASE/config.conf" \
        "$BASE/config.conf.kevintech.backup"

fi

if [[ -f "$BASE/license.conf" ]]; then

    cp \
        "$BASE/license.conf" \
        "$BASE/license.conf.kevintech.backup"

fi

#=========================================================
# CREAR DIRECTORIOS
#=========================================================

mkdir -p "$BASE"

cp -a "$TMP"/. "$BASE"/ || {

    rm -rf "$TMP"

    error_exit \
        "No se pudieron copiar los archivos a $BASE."

}

rm -rf "$TMP"

mkdir -p \
    "$BASE/protocolos" \
    "$BASE/usuarios" \
    "$BASE/sistema" \
    "$BASE/logs"

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
# INFORMACIÓN DE LICENCIA LOCAL
# NO SE GUARDA LA KEY
#=========================================================

cat > "$BASE/license.conf" <<EOF
LICENSE_OWNER="$LICENSE_OWNER"
LICENSE_RESELLER="$LICENSE_RESELLER"
LICENSE_TYPE="$LICENSE_TYPE"
LICENSE_DELETE_AT="$LICENSE_DELETE_AT"
LICENSE_API="$LICENSE_API"
LICENSE_STATUS="VALIDATED"
EOF

chmod 600 "$BASE/license.conf"

#=========================================================
# PERMISOS
#=========================================================

chmod -R 755 "$BASE"

chmod 600 "$BASE/license.conf"

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

#=========================================================
# PASO 5
# ACCESO ROOT
#=========================================================

titulo "PASO 5 - ACCESO ROOT"

echo -e "${YELLOW}Puedes establecer una contraseña para root.${RESET}"
echo
echo -e "${GREEN}Y = Establecer contraseña root${RESET}"
echo -e "${RED}N = Continuar${RESET}"
echo

read -r -p "[Y/N]: " ROOT_ACCESS

ROOT_ACCESS="$(
    printf '%s' "$ROOT_ACCESS" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$ROOT_ACCESS" == "y" ]]; then

    echo
    echo -e "${YELLOW}Introduce la nueva contraseña de root:${RESET}"

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

                echo -e "${GREEN}✅ Acceso root habilitado.${RESET}"

            else

                echo -e "${RED}❌ La configuración SSH no es válida.${RESET}"

            fi

        fi

    else

        echo -e "${RED}❌ No se pudo cambiar la contraseña.${RESET}"

    fi

    pausa 2

fi

#=========================================================
# PASO 6
# PROTOCOLOS
#=========================================================

titulo "PASO 6 - INSTALACIÓN DE PROTOCOLOS"

echo -e "${GREEN}Se instalarán automáticamente:${RESET}"
echo
echo "  ✔ BadVPN"
echo "  ✔ SSL / TLS"
echo "  ✔ ZIPVPN"
echo "  ✔ UDP Hysteria"
echo "  ✔ OpenVPN"
echo "  ✔ Xray / V2Ray"
echo "  ✔ Dropbear"
echo "  ✔ UDP Custom"
echo

pausa 2

if [[ "$INSTALL_PROTOCOLS" == "ON" ]]; then

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}     INSTALANDO PROTOCOLOS AUTOMÁTICOS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    instalar_protocolo() {

        local NOMBRE="$1"
        local ARCHIVO="$2"

        if [[ -f "$ARCHIVO" ]]; then

            echo -e "${YELLOW}📦 Instalando $NOMBRE...${RESET}"

            if bash "$ARCHIVO" --auto; then

                echo -e "${GREEN}✅ $NOMBRE instalado.${RESET}"

            else

                echo -e "${YELLOW}⚠️ $NOMBRE terminó con errores.${RESET}"

            fi

        else

            echo -e "${YELLOW}⚠️ No existe el módulo de $NOMBRE:${RESET}"
            echo "   $ARCHIVO"

        fi

        echo

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

echo " __  __       _ _   _   _      ____            _       _   "
echo "|  \/  |_   _| | |_(_) | |    / ___|  ___ _ __(_)_ __ | |_ "
echo "| |\/| | | | | | __| | | |    \___ \ / __| '__| | '_ \| __|"
echo "| |  | | |_| | | |_| | | |___  ___) | (__| |  | | |_) | |_ "
echo "|_|  |_|\__,_|_|\__|_| |_____| |____/ \___|_|  |_| .__/ \__|"
echo "                                                 |_|       "

echo
echo "              🚀 KevinTech Multi Script 🚀"
echo

echo " Servidor : $SERVER"
echo " Dominio  : $DOMAIN"
echo " Uptime   : $UPTIME"
echo " Fecha    : $FECHA"
echo " Hora     : $HORA"
echo " Redes sociales : kevin tech tutorials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$EUID" -ne 0 ]]; then

    echo "👤 Usuario : $(whoami)"
    echo "🔒 No eres root."
    echo "👉 Ejecuta: sudo -i"

else

    echo "👑 Usuario : root"
    echo "👉 Escribe: menu"

fi

echo
EOF

chmod +x /etc/profile.d/kevintech-banner.sh

#=========================================================
# PASO FINAL
# REGISTRAR ACTIVACIÓN
#=========================================================

titulo "REGISTRANDO INSTALACIÓN"

echo -e "${YELLOW}🔐 Registrando esta instalación...${RESET}"
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

#=========================================================
# JSON DE ACTIVACIÓN
# La API obtiene owner/reseller desde la Key.
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

echo -e "${GRAY}IP      : $CLIENT_IP${RESET}"
echo -e "${GRAY}Hostname: $HOSTNAME_VALUE${RESET}"
echo

#=========================================================
# ACTIVAR KEY
#=========================================================

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

#=========================================================
# ERROR CURL
#=========================================================

if [[ "$ACTIVATE_STATUS" -ne 0 ]]; then

    echo
    echo -e "${RED}❌ Error de conexión con la API de activación.${RESET}"
    echo
    echo -e "${YELLOW}La licencia NO fue marcada como utilizada.${RESET}"
    echo

    exit 1

fi

#=========================================================
# VALIDAR RESPUESTA JSON
#=========================================================

if ! echo "$ACTIVATE_BODY" |
    jq empty >/dev/null 2>&1; then

    echo
    echo -e "${RED}❌ La API devolvió una respuesta inválida.${RESET}"
    echo
    echo "HTTP: $ACTIVATE_HTTP"
    echo
    echo "$ACTIVATE_BODY"
    echo

    exit 1

fi

#=========================================================
# RESULTADO ACTIVACIÓN
#=========================================================

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
    echo -e "${RED}❌ No se pudo registrar la activación.${RESET}"
    echo
    echo -e "${YELLOW}Código: ${ACTIVATE_ERROR:-desconocido}${RESET}"
    echo -e "${YELLOW}HTTP  : $ACTIVATE_HTTP${RESET}"
    echo
    echo "$ACTIVATE_BODY"
    echo
    echo -e "${RED}La instalación no será declarada como completada.${RESET}"
    echo

    exit 1

fi

ACTIVATION_ID="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.activationId // empty'
)"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}✅ ACTIVACIÓN REGISTRADA${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

if [[ -n "$ACTIVATION_ID" ]]; then
    echo -e "${GRAY}ID de activación: $ACTIVATION_ID${RESET}"
fi

echo
echo -e "${GREEN}✅ La Key fue marcada como utilizada.${RESET}"
echo

#=========================================================
# MARCAR ESTADO LOCAL
#=========================================================

if [[ -f "$BASE/license.conf" ]]; then

    sed -i \
        's/^LICENSE_STATUS=.*/LICENSE_STATUS="ACTIVE"/' \
        "$BASE/license.conf"

    chmod 600 "$BASE/license.conf"

fi

#=========================================================
# LIMPIAR KEY DE MEMORIA
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
# INSTALACIÓN COMPLETADA
#=========================================================

titulo "INSTALACIÓN COMPLETADA"

echo -e "${GREEN}✅ Servidor listo para usar.${RESET}"
echo

echo -e "${WHITE}Licencia    :${RESET} ACTIVA"
echo -e "${WHITE}Propietario :${RESET} $LICENSE_OWNER"
echo -e "${WHITE}Revendedor  :${RESET} $LICENSE_RESELLER"
echo -e "${WHITE}Tipo        :${RESET} $LICENSE_TYPE"

echo

echo -e "${WHITE}Dominio :${RESET} $SERVER_DOMAIN"
echo -e "${WHITE}IP      :${RESET} $SERVER_IP"
echo -e "${WHITE}DNS     :${RESET} $DNS_PROVIDER"

echo

echo -e "${GREEN}Los archivos de KevinTech fueron instalados.${RESET}"

echo
echo -e "${YELLOW}Para abrir el panel:${RESET}"
echo
echo -e "${CYAN}menu${RESET}"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e "${YELLOW}¿Reiniciar el servidor ahora? [Y/N]${RESET}"

read -r -p "[Y/N]: " REBOOT_SERVER

REBOOT_SERVER="$(
    printf '%s' "$REBOOT_SERVER" |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "$REBOOT_SERVER" == "y" ]]; then

    echo
    echo -e "${YELLOW}🔄 Reiniciando en 5 segundos...${RESET}"

    sleep 5

    reboot

else

    echo
    echo -e "${GREEN}✅ Instalación finalizada sin reiniciar.${RESET}"
    echo
    echo -e "${CYAN}Escribe:${RESET} menu"
    echo

fi

exit 0
