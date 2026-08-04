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
ca-certificates \
fail2ban \
rkhunter \
chkrootkit \
lynis
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
# SEGURIDAD
#==============================

echo ""
echo "🛡️ Instalando seguridad..."

cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
bantime.increment = true
bantime.maxtime = 1w

[sshd]
enabled = true
[dropbear]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable fail2ban
systemctl restart fail2ban

rkhunter --update >/dev/null 2>&1
rkhunter --propupd >/dev/null 2>&1
cat >/etc/cron.daily/kevintech-security <<'EOF'
#!/bin/bash

/usr/bin/rkhunter --update >/dev/null 2>&1
/usr/bin/rkhunter --check --skip-keypress >/dev/null 2>&1

/usr/sbin/chkrootkit >/dev/null 2>&1

/usr/bin/lynis audit system --quick >/var/log/kevintech-lynis.log 2>&1
EOF

chmod +x /etc/cron.daily/kevintech-security

echo "✅ Fail2Ban configurado"
echo "✅ RKHunter configurado"
echo "✅ Chkrootkit instalado"
echo "✅ Lynis instalado"

sleep 2
cat >/usr/local/bin/kevintech-network-monitor <<'EOF'
#!/bin/bash

BASE="/etc/kevintech"
STATE="$BASE/sistema/network_state.conf"

source "$STATE"

IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

RX=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)

if [[ "$RX_LAST" == "0" ]]; then
    RX_LAST=$RX
    TX_LAST=$TX
fi

DIFF_RX=$((RX-RX_LAST))
DIFF_TX=$((TX-TX_LAST))

RX_TOTAL=$((RX_TOTAL+DIFF_RX))
TX_TOTAL=$((TX_TOTAL+DIFF_TX))

TOTAL=$((RX_TOTAL+TX_TOTAL))
TOTAL_GB=$(echo "scale=2; $TOTAL/1024/1024/1024" | bc)

cat >"$STATE"<<EOL
RX_LAST=$RX
TX_LAST=$TX
RX_TOTAL=$RX_TOTAL
TX_TOTAL=$TX_TOTAL
TOTAL_GB=$TOTAL_GB
LIMIT_GB=$LIMIT_GB
LIMIT_ENABLED=$LIMIT_ENABLED
EOL
EOF

chmod +x /usr/local/bin/kevintech-network-monitor
cat >/etc/cron.d/kevintech-network<<EOF
* * * * * root /usr/local/bin/kevintech-network-monitor
EOF
cat >/etc/systemd/system/kevintech-network.timer<<EOF
[Unit]
Description=KevinTech Network Monitor Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now kevintech-network.timer
#==============================  
  
# CONFIG SERVER  
  
#==============================  
  
clear  
  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
echo "        CONFIGURACIÓN DEL SERVIDOR"  
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"  
  
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
touch $BASE/sistema/network_state.conf

cat > "$BASE/sistema/network_state.conf" <<EOF
RX_LAST=0
TX_LAST=0
RX_TOTAL=0
TX_TOTAL=0
TOTAL_GB=0
LIMIT_GB=0
LIMIT_ENABLED=OFF
EOF
#==============================  
  
# CONFIG FINAL  
  
#==============================  
  
cat > "$BASE/config.conf" <<EOF
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
FAIL2BAN=ON
RKHUNTER=ON
CHKROOTKIT=ON
LYNIS=ON
NETWORK_MONITOR=ON
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
echo " YouTube   : Kevin tech tutorials"
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
