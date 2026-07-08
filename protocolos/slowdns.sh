#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
YELLOW="\e[1;93m"
RESET="\e[0m"

SERVICE="iodined"
PORT="53"

PUBKEY="/etc/iodine/public.key"
DOMAIN_FILE="/etc/iodine/domain.conf"

while true; do

clear

source "$CONFIG"

if [[ "$SLOWDNS" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}             🐌 SLOWDNS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado     : $STATUS"
echo -e " Puerto DNS : $PORT"
echo -e " Servicio   : iodined"

if [[ -f "$DOMAIN_FILE" ]]; then
DOMAIN=$(cat $DOMAIN_FILE)
echo -e " Dominio NS : ${YELLOW}$DOMAIN${RESET}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


if [[ "$SLOWDNS" == "ON" ]]; then

cat <<EOF

 [1] ➮ Desinstalar SlowDNS
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [4] ➮ Ver Public Key
 [0] ➮ Regresar

EOF

else

cat <<EOF

 [1] ➮ Instalar SlowDNS
 [0] ➮ Regresar

EOF

fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP


case "$OP" in


1)

if [[ "$SLOWDNS" == "ON" ]]; then

echo ""
read -rp "¿Eliminar SlowDNS? (s/n): " R

if [[ "$R" =~ ^[Ss]$ ]]; then

systemctl stop iodined 2>/dev/null
systemctl disable iodined 2>/dev/null

apt remove iodine -y

rm -rf /etc/iodine

sed -i 's/^SLOWDNS=.*/SLOWDNS=OFF/' "$CONFIG"

echo ""
echo "✅ SlowDNS eliminado"

fi


else


echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "        INSTALAR SLOWDNS"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp "Ingrese dominio NS (ejemplo ns.midominio.com): " DOMAIN

if [[ -z "$DOMAIN" ]]; then

echo "❌ Dominio vacío"
sleep 2
continue

fi


mkdir -p /etc/iodine

echo "$DOMAIN" > "$DOMAIN_FILE"


echo ""
echo "📦 Instalando dependencias..."

apt update -y

apt install iodine openssh-server -y
systemctl unmask iodined 2>/dev/null


echo ""
echo "🔑 Generando Public Key..."

openssl rand -hex 16 > "$PUBKEY"


echo ""
echo "🚀 Configurando SlowDNS..."

PASSWORD=$(cat "$PUBKEY")

cat > /etc/systemd/system/iodined.service <<EOF
[Unit]
Description=SlowDNS Iodine Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/iodined -f -c -P ${PASSWORD} 10.0.0.1 ${DOMAIN}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload

systemctl unmask iodined

systemctl enable iodined

systemctl restart iodined


sed -i 's/^SLOWDNS=.*/SLOWDNS=ON/' "$CONFIG"


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SLOWDNS INSTALADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🌐 Dominio NS:"
echo "$DOMAIN"

echo ""
echo "🔐 Public Key:"
cat $PUBKEY

echo ""
echo "SSH REDIRECCIONADO:"
echo "Puerto destino: 22"

echo ""
echo "Escribe menu para volver"

fi

;;
2)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}       🔄 REINICIANDO SLOWDNS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

systemctl restart iodined

sleep 2

if systemctl is-active --quiet iodined; then

echo ""
echo -e "${GREEN}✅ SlowDNS reiniciado correctamente${RESET}"

else

echo ""
echo -e "${RED}❌ Error al reiniciar SlowDNS${RESET}"

fi


echo ""
echo "Escribe menu para volver"

;;

3)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          ESTADO SLOWDNS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

systemctl status iodined --no-pager

echo ""

echo "Puerto DNS:"
ss -ulnp | grep ":53"

echo ""

if [[ -f "$DOMAIN_FILE" ]]; then
echo "Dominio NS:"
cat "$DOMAIN_FILE"
fi

echo ""

echo "SSH DESTINO:"
echo "Puerto 22 (OpenSSH)"

echo ""

echo "Public Key:"
echo ""

cat "$PUBKEY" 2>/dev/null

echo ""

read -rp "Escribe menu para volver: " SALIR

if [[ "$SALIR" == "menu" ]]; then
    exec bash "$BASE/protocolos/menu.sh"
fi

;;
4)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          🔑 PUBLIC KEY SLOWDNS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ -f "$PUBKEY" ]]; then

echo ""
cat "$PUBKEY"

else

echo "❌ No existe Public Key"

fi

echo ""
read -rp "Escribe menu para volver: " SALIR

if [[ "$SALIR" == "menu" ]]; then
    exec bash "$BASE/protocolos/menu.sh"
fi

;;

0)

exec bash "$BASE/protocolos/menu.sh"

;;

*)

echo "❌ Opción inválida"
sleep 2

;;

esac

done
