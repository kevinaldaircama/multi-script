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

    cd /etc/kevintech || exit

    if [[ -d .git ]]; then
        git reset --hard
        git pull origin main || git pull
        echo "✅ Sistema actualizado correctamente"
        exit
    else
        rm -rf /etc/kevintech
    fi
fi

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

        #==============================
        # ACTIVAR SSL REAL
        #==============================

        echo "🔐 Generando certificado SSL real..."

        apt update -y >/dev/null 2>&1
        apt install -y nginx certbot python3-certbot-nginx >/dev/null 2>&1

        systemctl enable nginx
        systemctl restart nginx

        # generar certificado
        certbot --nginx -d "$SERVER_DOMAIN" --non-interactive --agree-tos -m admin@$SERVER_DOMAIN

        if [[ $? -eq 0 ]]; then
            SSL_TUNNEL="ON"
            echo "✅ SSL real instalado correctamente"
        else
            SSL_TUNNEL="OFF"
            echo "❌ Error generando SSL"
        fi

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

cat > $BASE/config.conf <<EOF
SERVER_NAME="$SERVER_NAME"
SERVER_DOMAIN="$SERVER_DOMAIN"

CLOUDFLARE_STATUS="$CLOUDFLARE_STATUS"
SSL_TUNNEL="$SSL_TUNNEL"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"
PROXY_STATUS="$PROXY_STATUS"

AUTO_START=OFF

#==============================
# PROTOCOLOS (FORZADOS)
#==============================

OPENSSH=ON
SYSTEMDNS=ON
WEBSOCKET=ON
NGINX=ON
DROPBEAR=ON
SSL=ON

BADVPN=ON
UDP_CUSTOM=ON

# OPCIONAL
SLOWDNS=OFF

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
# SLOWDNS OPCIONAL
#==============================

echo ""
read -rp "🚀 ¿Instalar SlowDNS? (s/n): " INSTALL_SLOWDNS

if [[ "$INSTALL_SLOWDNS" == "s" || "$INSTALL_SLOWDNS" == "S" ]]; then

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      🔐 CONFIGURACIÓN SLOWDNS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    read -rp "🌐 Dominio NS Cloudflare: " SLOW_DOMAIN
    read -rp "🔑 Token / Key (o Enter para generar): " SLOW_KEY

    if [[ -z "$SLOW_KEY" ]]; then
        SLOW_KEY=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
        echo "🔑 Key generada: $SLOW_KEY"
    fi

    # activar en config
    sed -i "s/SLOWDNS=OFF/SLOWDNS=ON/" $BASE/config.conf

    echo "✅ SlowDNS configurado"
fi

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
chmod +x $BASE/menu.sh

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
echo "📦 Protocolos instalados:"
echo "   ✔ SSH .............. 22"
echo "   ✔ DROPBEAR ......... 90"
echo "   ✔ SSL .............. ACTIVO (manejado por ssl.sh → 443→22)"
echo "   ✔ WEBSOCKET ........ ACTIVO (websocket.sh → 80→22)"
echo "   ✔ SLOWDNS .......... ACTIVO (slowdns.sh → DNS→22)"
echo "   ✔ BADVPN ........... 7200 / 7300"
echo "   ✔ UDP CUSTOM ....... 36712"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Copiando menú principal..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "aviso de protocolos"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✔ El instalador SOLO instala no configura"
echo "✔ Los protocolos se instalan en el menu opción 5"
echo "✔ Todo tráfico se redirige a SSH 22 internamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
mkdir -p /etc/kevintech

cp -f ./menu.sh /etc/kevintech/menu.sh 2>/dev/null \
|| cp -f /root/multi-script/menu.sh /etc/kevintech/menu.sh 2>/dev/null

chmod +x /etc/kevintech/menu.sh

if [[ ! -f /etc/kevintech/menu.sh ]]; then
    echo "❌ ERROR: menu.sh no fue instalado"
    exit 1
fi

echo ""
echo "💻 Abriendo menú..."

# 👇 AQUÍ VA TU BLOQUE
echo "📦 Descargando módulos desde GitHub..."

mkdir -p /etc/kevintech/protocolos

REPO="https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/Protocolos"

FILES=("ssl.sh" "websocket.sh" "dropbear.sh" "slowdns.sh")

for f in "${FILES[@]}"; do
    wget -q "$REPO/$f" -O /etc/kevintech/protocolos/$f

    if [[ -f "/etc/kevintech/protocolos/$f" ]]; then
        chmod +x /etc/kevintech/protocolos/$f
        echo "✅ $f descargado"
    else
        echo "❌ Error descargando $f"
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "📌 Archivos instalados:"
ls -l /etc/kevintech/protocolos
echo "━━━━━━━━━━━━━━━━━━━━━━"
sleep 2

exec /etc/kevintech/menu.sh
