#!/bin/bash  
  
#==================================================  
  
# KevinTech Multi Script Installer  
  
#==================================================  
  
#==============================  
  
# AUTO UPDATE SYSTEM  
  
#==============================  
  
if [[ -d "/etc/kevintech" ]]; then
    echo "🔄 Instalación detectada..."
    echo "📦 Actualizando sistema..."

    if [[ -d "/etc/kevintech/.git" ]]; then
        cd /etc/kevintech || exit 1
        git reset --hard
        git pull origin main || git pull
        echo "✅ Sistema actualizado correctamente"
        exit 0
    else
        cd /
        rm -rf /etc/kevintech
    fi
fi
  
clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      🛡️ KevinTech Multi Script 🛡️"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

#=====================================
# CONFIGURACIÓN PRIVADA
#=====================================

FIREBASE_URL_B64="aHR0cHM6Ly9rZXlnZW5icHQtZGVmYXVsdC1ydGRiLmZpcmViYXNlaW8uY29t"
FIREBASE_URL=$(echo "$FIREBASE_URL_B64" | base64 -d)

#=====================================
# OBTENER KEY
#=====================================

apt update -y >/dev/null 2>&1
apt install -y curl wget ca-certificates >/dev/null 2>&1
update-ca-certificates >/dev/null 2>&1 || true

while true; do
    echo ""
    read -p "Introduce tu Key de Instalación: " INSTALL_KEY
    INSTALL_KEY=$(echo "$INSTALL_KEY" | tr -d '\r\n ')

    [ -z "$INSTALL_KEY" ] && { echo "La Key no puede estar vacía."; continue; }

    echo "Verificando licencia..."

    KEY_RESPONSE=$(curl -k -4 -s -m 10 "${FIREBASE_URL}/keys/${INSTALL_KEY}.json" \
        || wget --no-check-certificate -qO- --timeout=10 "${FIREBASE_URL}/keys/${INSTALL_KEY}.json")

    if [ -z "$KEY_RESPONSE" ]; then
        echo "No fue posible conectar con el servidor de licencias."
        sleep 1
        continue
    fi

    if [ "$KEY_RESPONSE" = "null" ]; then
        echo "La Key es inválida, ya fue utilizada o está vencida."
        sleep 1
        continue
    fi

    echo "Licencia verificada correctamente."
    break
done


echo "🔥 Registrando activación..."

# Obtener información de la Key
KEY_DATA=$(curl -4 -s "${FIREBASE_URL}/keys/${INSTALL_KEY}.json")

OWNER=$(echo "$KEY_DATA" | jq -r '.owner')
RESELLER=$(echo "$KEY_DATA" | jq -r '.reseller')

CLIENT_IP=$(curl -4 -s ifconfig.me)
OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
HOSTNAME=$(hostname)
DATE_NOW=$(date "+%Y-%m-%d %H:%M:%S")

# Guardar activación
curl -4 -s -X POST \
-H "Content-Type: application/json" \
-d "{
\"owner\":\"$OWNER\",
\"reseller\":\"$RESELLER\",
\"token\":\"$INSTALL_KEY\",
\"ip\":\"$CLIENT_IP\",
\"hostname\":\"$HOSTNAME\",
\"os\":\"$OS_NAME\",
\"date\":\"$DATE_NOW\",
\"notified\":false
}" \
"${FIREBASE_URL}/activations.json" >/dev/null

# Eliminar la Key
curl -4 -s -X DELETE \
"${FIREBASE_URL}/keys/${INSTALL_KEY}.json" >/dev/null

sleep 1
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      🛡️ KevinTech Multi Script 🛡️"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

#==============================  
  
# ROOT  
  
#==============================  
  
if [[ $EUID -ne 0 ]]; then  
echo "❌ Necesita root"  
exec sudo bash "$0" "$@"  
fi  
  
#==============================  
  
# UBUNTU CHECK  
  
#==============================  
  
source /etc/os-release  
  
if [[ "$ID" != "ubuntu" ]]; then  
echo "❌ Solo Ubuntu"  
exit 1  
fi  
  
clear  
  
echo "✔ Sistema Ubuntu detectado"  
sleep 1  
  #==============================
# INSTALAR PAQUETES BÁSICOS
#==============================

echo "📦 Instalando paquetes básicos..."

apt update -y >/dev/null 2>&1

apt install -y \
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
ca-certificates >/dev/null 2>&1

echo "✅ Paquetes instalados."

#==============================
# INSTALAR OPENSSH
#==============================

echo "🔐 Instalando OpenSSH..."

apt install -y openssh-server >/dev/null 2>&1

systemctl enable ssh
systemctl restart ssh

echo "✅ OpenSSH instalado y activo en el puerto 22."
sleep 2
#==============================
# SEGURIDAD DEL VPS
#==============================

echo "🛡️ Aplicando endurecimiento básico del sistema..."

apt install -y ufw fail2ban >/dev/null 2>&1

# Firewall
ufw --force reset >/dev/null 2>&1
ufw default deny incoming >/dev/null 2>&1
ufw default allow outgoing >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1

# Endurecer SSH
SSHD_CFG="/etc/ssh/sshd_config"

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CFG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CFG"
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CFG"
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CFG"
sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD_CFG"

systemctl restart ssh

# Fail2Ban
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
findtime = 10m
bantime = 1h
EOF

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban >/dev/null 2>&1

echo "✅ Seguridad básica aplicada correctamente."
sleep 1
#==============================  
  
# CONFIG SERVER  
  
#==============================  
  
clear  
  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        CONFIGURACIÓN DEL SERVIDOR"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
read -p "🌐 Dominio: " SERVER_DOMAIN

echo ""
read -rp "¿Deseas instalar los protocolos automáticamente? (s/n): " AUTO_PROTOCOLS

AUTO_PROTOCOLS=$(echo "$AUTO_PROTOCOLS" | tr '[:upper:]' '[:lower:]')

if [[ "$AUTO_PROTOCOLS" =~ ^(s|si|sí)$ ]]; then
    INSTALL_PROTOCOLS="ON"
    echo "🚀 Se instalarán automáticamente los protocolos."
else
    INSTALL_PROTOCOLS="OFF"
    echo "ℹ️ Los protocolos no se instalarán automáticamente."
fi

sleep 1

SERVER_IP=$(curl -s ifconfig.me)

SERVER_IP=$(curl -4 -s ifconfig.me)

DOMAIN_IP_MATCH="NO"
DNS_PROVIDER="Desconocido"

if [[ -n "$SERVER_DOMAIN" ]]; then
    echo ""
    echo "Verificando dominio..."

    DOMAIN_IP=$(dig +short A "$SERVER_DOMAIN" | head -n1)

    if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
        DOMAIN_IP_MATCH="YES"
        SSL_TUNNEL="OFF"
        echo "Dominio configurado correctamente."
        echo "El certificado SSL podrá instalarse desde el menú."
    else
        SSL_TUNNEL="OFF"
        echo "El dominio aún no apunta a este VPS."
    fi

    NS=$(dig +short NS "$SERVER_DOMAIN" | tr '\n' ' ')

    if echo "$NS" | grep -qi "cloudflare"; then
        DNS_PROVIDER="Cloudflare"
    elif echo "$NS" | grep -Eqi "awsdns|route53"; then
        DNS_PROVIDER="AWS Route 53"
    elif echo "$NS" | grep -qi "cloudfront"; then
        DNS_PROVIDER="Amazon CloudFront"
    elif echo "$NS" | grep -qi "googledomains\|google"; then
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
fi
BASE="/etc/kevintech"  
  
mkdir -p $BASE/{protocolos,usuarios,sistema,logs}  
  
#==============================  
  
# CONFIG FINAL  
  
#==============================  
  
cat > "$BASE/config.conf" <<EOF
SERVER_DOMAIN="$SERVER_DOMAIN"

DNS_PROVIDER="$DNS_PROVIDER"
SSL_TUNNEL="$SSL_TUNNEL"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"
PROXY_STATUS="$PROXY_STATUS"

AUTO_START=OFF

#==============================
# PROTOCOLOS
#==============================

OPENSSH=ON
SYSTEMDNS=OFF
WEBSOCKET=OFF
ZIPVPN=OFF
DROPBEAR=OFF
SSL=OFF

BADVPN=OFF
UDP_CUSTOM=OFF

SLOWDNS=OFF
V2RAY=OFF

OPENVPN=OFF
SQUID=OFF
TROJAN=OFF
V2RAY=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF
WEBMIN=OFF
FAIL2BAN=OFF
BBR=OFF
EOF
#==============================
# SLOWDNS
#==============================

INSTALL_SLOWDNS="n"

echo ""
echo "ℹ️ SlowDNS no se instala durante la instalación inicial."
echo "💡 Puedes instalarlo y configurarlo más tarde desde el menú."
echo ""
  
#==============================  
  
# INSTALACIÓN FINAL  
  
#==============================  
  
echo ""  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "     🚀 FINALIZANDO INSTALACIÓN"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
sleep 2  
  
# permisos  
  
chmod -R 777 $BASE  

  
# comando menu  
  
cat > /usr/local/bin/menu <<EOF
#!/bin/bash
exec bash /etc/kevintech/menu.sh
EOF
  
chmod +x /usr/local/bin/menu  
  
#==============================  
  
# RESUMEN FINAL  
  
#==============================  
  
clear  
  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        ✅ INSTALACIÓN COMPLETA"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo ""  
echo "🌐 Domain : $SERVER_DOMAIN"  
echo "🔐 SSL    : $SSL_TUNNEL"  
echo "🌐 DNS    : $DNS_PROVIDER"  
echo ""  
echo ""
echo "📦 Estado de la instalación:"
echo "   ✅ Paquetes básicos instalados"
echo "   ✅ Sistema preparado correctamente"
echo "   ⚙️ Ningún protocolo fue instalado automáticamente"
echo "   💡 Instala los protocolos desde el menú principal"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Instalando KevinTech Multi Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Preparando archivos del sistema..."
sleep 1
echo "⚙️ Configurando módulos principales..."
sleep 1
echo "🔐 Aplicando permisos y optimizaciones..."
sleep 1
echo "🛡️ Activando medidas de seguridad..."
sleep 1

cd /root || exit 1
rm -rf /tmp/multi-script

git clone -q https://github.com/kevinaldaircama/multi-script.git /tmp/multi-script >/dev/null 2>&1 || {
    echo "❌ Error al obtener los archivos del sistema."
    exit 1
}

mkdir -p /etc/kevintech
cp -a /tmp/multi-script/. /etc/kevintech/
chmod -R +x /etc/kevintech
rm -rf /tmp/multi-script

if [[ "$INSTALL_PROTOCOLS" == "ON" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   INSTALANDO PROTOCOLOS AUTOMÁTICOS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Instalar BadVPN
    bash /etc/kevintech/protocolos/badvpn.sh --auto

    # Instalar Dropbear
    bash /etc/kevintech/protocolos/dropbear.sh --auto

    # Instalar UDP Custom
    bash /etc/kevintech/protocolos/udpcustom.sh --auto

    # Instalar SSL Tunnel
    bash /etc/kevintech/protocolos/ssl.sh --auto
    
        # Instalar v2ray xray
    bash /etc/kevintech/protocolos/v2ray.sh --auto
    
    # Instalar udphiateria
    bash /etc/kevintech/protocolos/udphisteria.sh --auto
    
        # Instalar openvpn
    bash /etc/kevintech/protocolos/openvpn.sh --auto
    
    echo "✅ Protocolos instalados automáticamente."
    sleep 2
fi

echo "✅ Archivos del sistema instalados correctamente."
sleep 1

cat > /etc/profile.d/kevintech-banner.sh << 'EOF'
#!/bin/bash

[[ $- != *i* ]] && return

clear

SERVER=$(hostname)
DOMAIN="-"

if [[ -f /etc/kevintech/config.conf ]]; then
    source /etc/kevintech/config.conf
    DOMAIN="${SERVER_DOMAIN:-"-"}"
fi
UPTIME=$(uptime -p | sed 's/up //')
FECHA=$(date +"%d-%m-%Y")
HORA=$(date +"%H:%M:%S")

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
echo " Redes sociales  : kevin tech tutorials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $EUID -ne 0 ]]; then
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ KevinTech Multi Script instalado."
echo "🔄 El servidor se reiniciará en 10 segundos..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sleep 10

reboot
