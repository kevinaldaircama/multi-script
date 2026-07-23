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

if [ -z "${INSTALL_KEY:-}" ]; then
    read -p "🔑 Introduce tu Key de Instalación: " INSTALL_KEY
fi

if [ -z "$INSTALL_KEY" ]; then
    echo "❌ La Key no puede estar vacía."
    exit 1
fi

INSTALL_KEY=$(echo "$INSTALL_KEY" | tr -d '\r' | tr -d '\n' | tr -d ' ')

echo ""
echo "📦 Preparando verificación..."

apt update -y >/dev/null 2>&1
apt install -y curl wget ca-certificates >/dev/null 2>&1
update-ca-certificates >/dev/null 2>&1 || true

echo "🔍 Verificando licencia..."

if ! KEY_RESPONSE=$(curl -k -4 -s -m 10 "${FIREBASE_URL}/keys/${INSTALL_KEY}.json" \
    || wget --no-check-certificate -qO- --timeout=10 "${FIREBASE_URL}/keys/${INSTALL_KEY}.json"); then
    echo ""
    echo "❌ Error de conexión con Firebase."
    exit 1
fi

if [ "$KEY_RESPONSE" = "null" ] || [ -z "$KEY_RESPONSE" ]; then
    echo ""
    echo "❌ Key inválida o ya utilizada."
    exit 1
fi

echo ""
echo "✅ Key válida."

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
RESP=$(curl -4 -s -X POST \
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
"${FIREBASE_URL}/activations.json")

# Verificar que se guardó
if [[ "$RESP" != *"name"* ]]; then
    echo "❌ Error: no se pudo registrar la activación."
    echo "$RESP"
    exit 1
fi

# Eliminar la key solo si el POST fue exitoso
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

apt update -y

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
ca-certificates

echo "✅ Paquetes instalados."

#==============================
# INSTALAR OPENSSH
#==============================

echo "🔐 Instalando OpenSSH..."

apt install -y openssh-server

systemctl enable ssh
systemctl restart ssh

echo "✅ OpenSSH instalado y activo en el puerto 22."
sleep 2
#==============================  
  
# CONFIG SERVER  
  
#==============================  
  
clear  
  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        CONFIGURACIÓN DEL SERVIDOR"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
read -p "📝 Nombre servidor: " SERVER_NAME  
read -p "🌐 Dominio: " SERVER_DOMAIN  
  
SERVER_IP=$(curl -s ifconfig.me)  
  
CLOUDFLARE_STATUS="OFF"  
SSL_TUNNEL="OFF"  
DOMAIN_IP_MATCH="NO"  
PROXY_STATUS="UNKNOWN"  
if [[ -n "$SERVER_DOMAIN" ]]; then  
  
echo ""        
echo "🔍 Verificando dominio..."        
    
DOMAIN_IP=$(dig +short "$SERVER_DOMAIN" | head -n1)        
    
if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
    DOMAIN_IP_MATCH="YES"
    echo "✅ Dominio apunta al VPS"
    echo "ℹ️ El certificado SSL se podrá instalar desde el menú."

    SSL_TUNNEL="OFF"

else
    echo "❌ Dominio no apunta al VPS"
    SSL_TUNNEL="OFF"
fi
    
# Cloudflare detect        
CF=$(dig +short NS "$SERVER_DOMAIN" | grep cloudflare)        
    
[[ -n "$CF" ]] && CLOUDFLARE_STATUS="ON"  
  
fi  
BASE="/etc/kevintech"  
  
mkdir -p $BASE/{protocolos,usuarios,sistema,logs}  
  
#==============================  
  
# CONFIG FINAL  
  
#==============================  
  
cat > "$BASE/config.conf" <<EOF
SERVER_NAME="$SERVER_NAME"
SERVER_DOMAIN="$SERVER_DOMAIN"

CLOUDFLARE_STATUS="$CLOUDFLARE_STATUS"
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
echo "📝 Server : $SERVER_NAME"  
echo "🌐 Domain : $SERVER_DOMAIN"  
echo "🔐 SSL    : $SSL_TUNNEL"  
echo "☁️ CF     : $CLOUDFLARE_STATUS"  
echo ""  
echo ""
echo "📦 Estado de la instalación:"
echo "   ✅ Paquetes básicos instalados"
echo "   ✅ Sistema preparado correctamente"
echo "   ⚙️ Ningún protocolo fue instalado automáticamente"
echo "   💡 Instala los protocolos desde el menú principal"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "📥 Descargando KevinTech Multi Script..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /root || exit 1

rm -rf /tmp/multi-script

git clone https://github.com/kevinaldaircama/multi-script.git /tmp/multi-script || exit 1

mkdir -p /etc/kevintech

cp -a /tmp/multi-script/. /etc/kevintech/

chmod -R +x /etc/kevintech

rm -rf /tmp/multi-script

if [[ ! -f /etc/kevintech/menu.sh ]]; then
    echo "❌ ERROR: menu.sh no fue instalado"
    exit 1
fi
  
echo ""  
echo "💻 Abriendo menú..."  
  
sleep 2  
  
exec /etc/kevintech/menu.sh
