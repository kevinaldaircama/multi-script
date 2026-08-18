#!/bin/bash

#=========================================================
#          KEVINTECH MULTI SCRIPT INSTALLER
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

#=========================================================
# VARIABLES
#=========================================================

BASE="/etc/kevintech"
TMP="/tmp/kevintech_install"
REPO="https://github.com/kevinaldaircama/multi-script.git"

FIREBASE_URL_B64="aHR0cHM6Ly9rZXlnZW5icHQtZGVmYXVsdC1ydGRiLmZpcmViYXNlaW8uY29t"
FIREBASE_URL="$(printf '%s' "$FIREBASE_URL_B64" | base64 -d 2>/dev/null)"

INSTALL_PROTOCOLS="ON"
SERVER_DOMAIN=""
SERVER_IP=""
DOMAIN_IP=""
DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"
SSL_TUNNEL="OFF"
PROXY_STATUS="OFF"

#=========================================================
# FUNCIONES
#=========================================================

error_exit() {
    echo
    echo -e "${RED}❌ $1${RESET}"
    echo
    exit 1
}

titulo() {
    clear
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
    echo "y después vuelve a ejecutar el instalador."
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
# AUTO UPDATE
#=========================================================

if [[ -d "$BASE/.git" ]]; then

    echo -e "${CYAN}🔄 Instalación existente detectada...${RESET}"
    echo -e "${YELLOW}📦 Actualizando KevinTech...${RESET}"
    echo

    cd "$BASE" || error_exit "No se pudo acceder a $BASE."

    if git reset --hard >/dev/null 2>&1 &&
       git pull origin main >/dev/null 2>&1; then

        echo -e "${GREEN}✅ Sistema actualizado correctamente.${RESET}"
        exit 0

    else
        echo -e "${YELLOW}⚠️ No se pudo actualizar mediante Git.${RESET}"
        echo -e "${YELLOW}Continuando con la instalación...${RESET}"
        echo
    fi
fi

#=========================================================
# CABECERA
#=========================================================

titulo "🛡️ KevinTech Multi Script 🛡️"

echo -e "${GREEN}✔ Sistema Ubuntu detectado${RESET}"
echo

#=========================================================
# PASO 0 - DEPENDENCIAS DEL INSTALADOR
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
# VALIDAR FIREBASE
#=========================================================

if [[ -z "$FIREBASE_URL" ]]; then
    error_exit "No se pudo obtener la URL del servidor de licencias."
fi

FIREBASE_URL="${FIREBASE_URL%/}"

#=========================================================
# PASO 1 - LICENCIA
#=========================================================

titulo "PASO 1 - LICENCIA"

echo -e "${YELLOW}La Key se obtiene directamente desde el bot.${RESET}"
echo -e "${YELLOW}Si no tienes acceso, escríbeme en Telegram:${RESET}"
echo -e "${GREEN}@ktt${RESET}"
echo

while true; do

    read -r -p "Introduce tu Key de Instalación: " INSTALL_KEY

    INSTALL_KEY="$(printf '%s' "$INSTALL_KEY" | tr -d '[:space:]')"

    if [[ -z "$INSTALL_KEY" ]]; then
        echo -e "${RED}❌ La Key no puede estar vacía.${RESET}"
        continue
    fi

    echo
    echo -e "${YELLOW}🔐 Verificando licencia...${RESET}"

    KEY_URL="${FIREBASE_URL}/keys/${INSTALL_KEY}.json"

    KEY_RESPONSE="$(
        curl \
            --fail \
            --silent \
            --show-error \
            --connect-timeout 5 \
            --max-time 15 \
            -4 \
            "$KEY_URL" \
            2>/dev/null
    )"

    CURL_STATUS=$?

    if [[ "$CURL_STATUS" -ne 0 || -z "$KEY_RESPONSE" ]]; then
        echo -e "${RED}❌ No fue posible conectar con el servidor de licencias.${RESET}"
        echo
        echo "Comprueba que el VPS tenga conexión a Internet."
        pausa 2
        continue
    fi

    if [[ "$KEY_RESPONSE" == "null" ]]; then
        echo -e "${RED}❌ La Key es inválida, ya fue utilizada o no existe.${RESET}"
        pausa 2
        continue
    fi

    if ! echo "$KEY_RESPONSE" | jq empty >/dev/null 2>&1; then
        echo -e "${RED}❌ El servidor devolvió una respuesta inválida.${RESET}"
        pausa 2
        continue
    fi

    # Verificar que realmente exista información de la licencia
    if [[ "$(echo "$KEY_RESPONSE" | jq -r 'type')" != "object" ]]; then
        echo -e "${RED}❌ La Key no contiene datos válidos.${RESET}"
        pausa 2
        continue
    fi

    OWNER="$(echo "$KEY_RESPONSE" | jq -r '.owner // "Desconocido"')"
    RESELLER="$(echo "$KEY_RESPONSE" | jq -r '.reseller // "Desconocido"')"

    echo -e "${GREEN}✅ Licencia verificada correctamente.${RESET}"
    break

done

#=========================================================
# REGISTRAR ACTIVACIÓN
#=========================================================

echo
echo -e "${YELLOW}🔥 Registrando activación...${RESET}"

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

OS_NAME="$(grep '^PRETTY_NAME=' /etc/os-release | cut -d '"' -f2)"
HOSTNAME_VALUE="$(hostname)"
DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S')"

# Crear JSON correctamente con jq
ACTIVATION_JSON="$(
    jq -n \
        --arg owner "$OWNER" \
        --arg reseller "$RESELLER" \
        --arg token "$INSTALL_KEY" \
        --arg ip "$CLIENT_IP" \
        --arg hostname "$HOSTNAME_VALUE" \
        --arg os "$OS_NAME" \
        --arg date "$DATE_NOW" \
        '{
            owner: $owner,
            reseller: $reseller,
            token: $token,
            ip: $ip,
            hostname: $hostname,
            os: $os,
            date: $date,
            notified: false
        }'
)"

if curl \
    --fail \
    --silent \
    --show-error \
    --connect-timeout 5 \
    --max-time 15 \
    -4 \
    -X POST \
    -H "Content-Type: application/json" \
    --data "$ACTIVATION_JSON" \
    "${FIREBASE_URL}/activations.json" \
    >/dev/null 2>&1; then

    echo -e "${GREEN}✅ Activación registrada.${RESET}"

else

    echo -e "${YELLOW}⚠️ No se pudo registrar la activación.${RESET}"
    echo -e "${YELLOW}La instalación continuará, pero revisa Firebase.${RESET}"

fi

#=========================================================
# ELIMINAR KEY DESPUÉS DE ACTIVAR
#=========================================================

echo -e "${YELLOW}🔐 Marcando Key como utilizada...${RESET}"

if curl \
    --fail \
    --silent \
    --show-error \
    --connect-timeout 5 \
    --max-time 15 \
    -4 \
    -X DELETE \
    "${FIREBASE_URL}/keys/${INSTALL_KEY}.json" \
    >/dev/null 2>&1; then

    echo -e "${GREEN}✅ Key procesada correctamente.${RESET}"

else

    echo -e "${YELLOW}⚠️ No se pudo eliminar la Key del servidor.${RESET}"

fi

pausa 2

#=========================================================
# PASO 2 - PREPARAR SISTEMA
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

    # Eliminar configuraciones antiguas
    sed -i \
        -e '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*PasswordAuthentication[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*MaxAuthTries[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveInterval[[:space:]]/d' \
        -e '/^[[:space:]]*#\?[[:space:]]*ClientAliveCountMax[[:space:]]/d' \
        "$SSHD_CFG"

    cat >> "$SSHD_CFG" <<'EOF'

# KevinTech SSH configuration
PermitRootLogin prohibit-password
PasswordAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

EOF

fi

# Verificar configuración antes de reiniciar
if sshd -t >/dev/null 2>&1; then
    systemctl restart ssh
    echo -e "${GREEN}✅ Configuración SSH válida.${RESET}"
else
    echo -e "${RED}❌ Error en la configuración SSH.${RESET}"
    echo -e "${YELLOW}Restaurando configuración anterior...${RESET}"

    if [[ -f "${SSHD_CFG}.kevintech.backup" ]]; then
        cp "${SSHD_CFG}.kevintech.backup" "$SSHD_CFG"
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
# PASO 3 - DOMINIO
#=========================================================

titulo "PASO 3 - CONFIGURAR DOMINIO"

read -r -p "🌐 Escribe el dominio que apunta a este VPS: " SERVER_DOMAIN

SERVER_DOMAIN="$(printf '%s' "$SERVER_DOMAIN" | tr -d '[:space:]')"

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
SSL_TUNNEL="OFF"

if [[ -n "$SERVER_DOMAIN" ]]; then

    echo
    echo -e "${YELLOW}🔎 Verificando dominio...${RESET}"

    DOMAIN_IP="$(dig +short A "$SERVER_DOMAIN" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)"

    if [[ -n "$DOMAIN_IP" && "$DOMAIN_IP" == "$SERVER_IP" ]]; then

        DOMAIN_IP_MATCH="YES"
        echo -e "${GREEN}✅ El dominio apunta correctamente al VPS.${RESET}"

    else

        echo -e "${YELLOW}⚠️ El dominio todavía no apunta a este VPS.${RESET}"

        if [[ -n "$DOMAIN_IP" ]]; then
            echo "IP encontrada: $DOMAIN_IP"
            echo "IP del VPS:    $SERVER_IP"
        fi

    fi

    NS="$(dig +short NS "$SERVER_DOMAIN" | tr '\n' ' ')"

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
# PASO 4 - DESCARGAR SISTEMA
#=========================================================

titulo "PASO 4 - INSTALANDO SISTEMA"

echo -e "${YELLOW}📥 Descargando archivos desde GitHub...${RESET}"

rm -rf "$TMP"

mkdir -p "$TMP"

if ! git clone --depth 1 "$REPO" "$TMP" >/dev/null 2>&1; then
    rm -rf "$TMP"
    error_exit "No se pudieron descargar los archivos desde GitHub."
fi

echo -e "${GREEN}✅ Archivos descargados.${RESET}"

#=========================================================
# CREAR DIRECTORIOS
#=========================================================

mkdir -p "$BASE"

# Copiar archivos del repositorio
cp -a "$TMP"/. "$BASE"/ || {
    rm -rf "$TMP"
    error_exit "No se pudieron copiar los archivos a $BASE."
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
# PERMISOS
#=========================================================

chmod -R 755 "$BASE"

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
# PASO 5 - ACCESO ROOT
#=========================================================

titulo "PASO 5 - ACCESO ROOT"

echo -e "${YELLOW}Puedes establecer una contraseña para root.${RESET}"
echo
echo -e "${GREEN}Y = Establecer contraseña root${RESET}"
echo -e "${RED}N = Continuar${RESET}"
echo

read -r -p "[Y/N]: " ROOT_ACCESS

ROOT_ACCESS="$(printf '%s' "$ROOT_ACCESS" | tr '[:upper:]' '[:lower:]')"

if [[ "$ROOT_ACCESS" == "y" ]]; then

    echo
    echo -e "${YELLOW}Introduce la nueva contraseña de root:${RESET}"

    if passwd root; then

        # Permitir login root mediante contraseña
        if [[ -f "$SSHD_CFG" ]]; then

            sed -i \
                -e '/^[[:space:]]*#\?[[:space:]]*PermitRootLogin[[:space:]]/d' \
                -e '/^[[:space:]]*#\?[[:space:]]*PasswordAuthentication[[:space:]]/d' \
                "$SSHD_CFG"

            cat >> "$SSHD_CFG" <<'EOF'

# KevinTech root access
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
# PASO 6 - PROTOCOLOS
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

    #=====================================================
    # FUNCIÓN INSTALAR PROTOCOLO
    #=====================================================

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

UPTIME="$(uptime -p 2>/dev/null | sed 's/up //')"
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
# LIMPIEZA
#=========================================================

rm -f /tmp/kevintech_install

#=========================================================
# INSTALACIÓN COMPLETADA
#=========================================================

titulo "INSTALACIÓN COMPLETADA"

echo -e "${GREEN}✅ Servidor listo para usar.${RESET}"
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

REBOOT_SERVER="$(printf '%s' "$REBOOT_SERVER" | tr '[:upper:]' '[:lower:]')"

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