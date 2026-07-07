#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || exit 1

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

while true; do

clear

source "$CONFIG"

if [[ "$SSL" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}            🔐 SSL/TLS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado      : $STATUS"
echo -e " Dominio     : ${SERVER_DOMAIN:-NO CONFIGURADO}"
echo -e " Puerto      : 443 ➜ SSH 22"
echo -e " Servicio    : Stunnel4"
echo -e " Destino     : 127.0.0.1:22"
echo -e " Certificado : Let's Encrypt"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$SSL" == "ON" ]]; then

echo " [1] ➮ Reinstalar SSL Tunnel"
echo " [2] ➮ Renovar Certificado"
echo " [3] ➮ Ver Información SSL"
echo " [4] ➮ Reiniciar Stunnel"
echo " [5] ➮ Desinstalar SSL Tunnel"
echo
echo " [0] ➮ Regresar"

else

echo " [1] ➮ Instalar SSL"
echo
echo " [0] ➮ Regresar"

fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in
1)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        INSTALANDO SSL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -z "$SERVER_DOMAIN" ]]; then
    echo "❌ No hay dominio configurado."
    sleep 3
    continue
fi

echo "📦 Actualizando paquetes..."
apt update -y >/dev/null 2>&1

echo "📦 Instalando Stunnel..."

apt install -y stunnel4 certbot >/dev/null 2>&1

echo ""
echo "🔐 Generando certificado SSL..."
echo ""
#==============================
# VERIFICAR PUERTO 443
#==============================

if ss -ltn | grep -q ":443 "; then

    echo ""
    echo "❌ El puerto 443 ya está siendo utilizado."
    echo ""

    echo "Servicio que lo está usando:"
    ss -ltnp | grep ":443"

    echo ""
    echo "Detén ese servicio e intenta nuevamente."
    sleep 5
    continue

fi
certbot certonly \
--standalone \
-d "$SERVER_DOMAIN" \
--non-interactive \
--agree-tos \
-m admin@"$SERVER_DOMAIN"

if [[ $? -ne 0 ]]; then
    echo "❌ Error al generar el certificado."
    sleep 4
    continue
fi

cat >/etc/stunnel/stunnel.conf <<EOF
pid=/var/run/stunnel.pid

[openssh]
client = no
accept = 443
connect = 127.0.0.1:22

cert=/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem
key=/etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem
EOF

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4

systemctl enable stunnel4
systemctl restart stunnel4
if systemctl is-active --quiet stunnel4; then

    sed -i 's/^SSL=.*/SSL=ON/' "$CONFIG"
    sed -i 's/^SSL_TUNNEL=.*/SSL_TUNNEL=ON/' "$CONFIG"

    SSL="ON"
    SSL_TUNNEL="ON"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      ✅ SSL TUNNEL INSTALADO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🌐 Dominio : $SERVER_DOMAIN"
    echo "🔒 SSL     : 443"
    echo "➡ Destino : 127.0.0.1:22"
    echo "🚀 Compatible con:"
    echo "   ✔ HTTP Injector"
    echo "   ✔ HTTP Custom"
    echo "   ✔ eHTTP"
    echo "   ✔ HTTP Custom Lite"

else

    sed -i 's/^SSL=.*/SSL=OFF/' "$CONFIG"
    sed -i 's/^SSL_TUNNEL=.*/SSL_TUNNEL=OFF/' "$CONFIG"

    SSL="OFF"
    SSL_TUNNEL="OFF"

    echo ""
    echo "❌ Error iniciando Stunnel4."

fi

sleep 4
continue
if [[ $? -eq 0 ]]; then

sed -i 's/^SSL=.*/SSL=ON/' "$CONFIG"
sed -i 's/^SSL_TUNNEL=.*/SSL_TUNNEL=ON/' "$CONFIG"

SSL="ON"
SSL_TUNNEL="ON"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      ✅ SSL INSTALADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Dominio : $SERVER_DOMAIN"
echo "🔒 Puerto  : 443"
echo "📜 Certificado generado correctamente."

else

sed -i 's/^SSL=.*/SSL=OFF/' "$CONFIG"
sed -i 's/^SSL_TUNNEL=.*/SSL_TUNNEL=OFF/' "$CONFIG"

SSL="OFF"
SSL_TUNNEL="OFF"

echo ""
echo "❌ No fue posible generar el certificado SSL."
fi

sleep 4
;;
2)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      RENOVANDO CERTIFICADO SSL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

certbot renew

echo ""
echo "✅ Proceso finalizado."

sleep 4
;;

3)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       INFORMACIÓN DEL SSL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -f "/etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem" ]]; then

openssl x509 \
-in /etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem \
-noout \
-subject \
-issuer \
-startdate \
-enddate

else

echo "❌ No existe certificado SSL."

fi

echo ""
read -n1 -r -p "Presione una tecla para continuar..."
;;

4)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      REINICIANDO STUNNEL4"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl restart stunnel4

echo ""
echo "✅ Stunnel4 reiniciado correctamente."

sleep 3
;;
5)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "     DESINSTALAR SSL TUNNEL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -rp "¿Seguro que deseas desinstalar SSL Tunnel? (s/n): " RESP

if [[ "$RESP" =~ ^[Ss]$ ]]; then

    # Eliminar certificado
    certbot delete \
    --cert-name "$SERVER_DOMAIN" \
    --non-interactive >/dev/null 2>&1

    # Detener servicio
    systemctl stop stunnel4 >/dev/null 2>&1

    # Eliminar configuración
    rm -f /etc/stunnel/stunnel.conf

    # Deshabilitar servicio
    sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/stunnel4 2>/dev/null

    # Desinstalar Stunnel4
    apt purge -y stunnel4 >/dev/null 2>&1
    apt autoremove -y >/dev/null 2>&1

    # Actualizar configuración
    sed -i 's/^SSL=.*/SSL=OFF/' "$CONFIG"
    sed -i 's/^SSL_TUNNEL=.*/SSL_TUNNEL=OFF/' "$CONFIG"

    SSL="OFF"
    SSL_TUNNEL="OFF"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "     ✅ SSL TUNNEL ELIMINADO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔓 Puerto 443 liberado."
    echo "🔐 OpenSSH (22) continúa funcionando."

else

    echo ""
    echo "❌ Operación cancelada."

fi

sleep 3
;;

0)

exec bash "$BASE/protocolos/menu.sh"
;;

*)

echo ""
echo "❌ Opción inválida."
sleep 2
;;

esac

done
