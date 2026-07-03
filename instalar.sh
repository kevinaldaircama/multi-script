#!/bin/bash

#==================================================
#   KevinTech Multi Script Installer
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
        echo "⚠️ Instalación no Git, reinstalando..."
        rm -rf /etc/kevintech
    fi
fi
clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      🛡️ KevinTech Multi Script 🛡️"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

#==============================
# Verificar Root
#==============================

if [[ $EUID -ne 0 ]]; then
    echo "❌ Este instalador necesita permisos de administrador."
    echo ""
    echo "Ingrese la contraseña para continuar..."
    exec sudo bash "$0" "$@"
fi

#==============================
# Verificar Ubuntu
#==============================

if [[ -f /etc/os-release ]]; then
    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        echo ""
        echo "❌ ERROR"
        echo "Este Script solo funciona en Ubuntu."
        exit 1
    fi
else
    echo "No se pudo detectar el sistema operativo."
    exit 1
fi

VERSION=$(lsb_release -rs)

clear

echo "✅ Sistema Detectado"
echo ""
echo "Ubuntu $VERSION"
echo ""

sleep 2
#==============================
# Nombre del Servidor
#==============================

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        CONFIGURACIÓN DEL SERVIDOR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "📝 Nombre del servidor (Opcional): " SERVER_NAME
read -p "🌐 Dominio (Opcional): " SERVER_DOMAIN
#==============================
# VALIDACIÓN DE DOMINIO + CLOUDFLARE
#==============================

CLOUDFLARE_STATUS="OFF"
SSL_TUNNEL="OFF"
DOMAIN_IP_MATCH="NO"
PROXY_STATUS="UNKNOWN"

SERVER_IP=$(curl -s ifconfig.me)

if [[ -n "$SERVER_DOMAIN" ]]; then

    echo ""
    echo "🔍 Verificando dominio: $SERVER_DOMAIN ..."
    
    DOMAIN_IP=$(dig +short "$SERVER_DOMAIN" | head -n1)

    if [[ -z "$DOMAIN_IP" ]]; then
        echo "⚠️ No se pudo resolver el dominio."
    else
        echo "🌐 IP del dominio: $DOMAIN_IP"
        echo "🖥️ IP del servidor: $SERVER_IP"

        if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
            DOMAIN_IP_MATCH="YES"
            echo "✅ El dominio apunta correctamente al servidor."
        else
            echo "❌ El dominio NO apunta a este servidor."
        fi
    fi

    #==============================
    # DETECTAR CLOUDFLARE
    #==============================

    CF_CHECK=$(dig +short "$SERVER_DOMAIN" NS | grep -i cloudflare)

    if [[ -n "$CF_CHECK" ]]; then
        CLOUDFLARE_STATUS="ON"
        echo "☁️ Cloudflare detectado en el dominio."

        #==============================
        # DETECTAR PROXY (IP CLOUDFLARE)
        #==============================

        CF_IPS=$(dig +short "$SERVER_DOMAIN")

        for ip in $CF_IPS; do
            if [[ "$ip" =~ ^104\.|^172\.|^188\.|^190\. ]]; then
                PROXY_STATUS="ACTIVE"
            fi
        done

        if [[ "$PROXY_STATUS" == "ACTIVE" ]]; then
            echo "🟠 Proxy de Cloudflare ACTIVO (nube naranja)."
        else
            echo "⚪ Proxy de Cloudflare DESACTIVADO (DNS only)."
        fi

    else
        echo "❌ Cloudflare NO detectado."
    fi

    #==============================
    # DECISIÓN SSL TÚNEL
    #==============================

    if [[ "$DOMAIN_IP_MATCH" == "YES" ]]; then
        SSL_TUNNEL="ON"
        echo "🔐 SSL Túnel habilitado en puerto 443."
    else
        echo "⚠️ SSL Túnel NO habilitado (dominio no apunta)."
    fi

else
    echo ""
    echo "ℹ️ No se ingresó dominio, se omitirá SSL túnel."
fi
#==============================
# Crear Directorios
#==============================

BASE="/etc/kevintech"

mkdir -p $BASE
mkdir -p $BASE/protocolos
mkdir -p $BASE/usuarios
mkdir -p $BASE/sistema
mkdir -p $BASE/extras
mkdir -p $BASE/backups
mkdir -p $BASE/logs

#==============================
# Crear Configuración
#==============================

cat > $BASE/config.conf <<EOF
SERVER_NAME="$SERVER_NAME"
SERVER_DOMAIN="$SERVER_DOMAIN"

AUTO_START=OFF

OPENSSH=OFF
DROPBEAR=OFF
OPENVPN=OFF
SSL=OFF
SQUID=OFF
BADVPN=OFF
UDP_CUSTOM=OFF
NGINX=OFF
WEBSOCKET=OFF
SLOWDNS=OFF
TROJAN=OFF
V2RAY=OFF
SHADOWSOCKS=OFF
SOCKS5=OFF
BROOK=OFF
WEBMIN=OFF
FAIL2BAN=OFF
BBR=OFF
EOF

#==============================
# Copiar menu.sh al sistema
#==============================

if [[ -f "menu.sh" ]]; then
    cp menu.sh $BASE/menu.sh
    chmod +x $BASE/menu.sh
else
    echo "❌ No se encontró el archivo menu.sh"
    exit 1
fi

#==============================
# Crear comando "menu"
#==============================

cat > /usr/local/bin/menu <<EOF
#!/bin/bash
exec bash $BASE/menu.sh
EOF

chmod +x /usr/local/bin/menu

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ✅ INSTALACIÓN COMPLETADA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Nombre : ${SERVER_NAME:-Sin definir}"
echo "Dominio: ${SERVER_DOMAIN:-Sin definir}"
echo ""
echo "Todos los protocolos fueron creados en estado OFF."
echo ""
echo "Ahora puedes abrir el panel escribiendo:"
echo ""
echo "menu"
echo ""

sleep 2

menu
