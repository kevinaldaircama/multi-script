#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="udpcustom"
PORT="36712"

BIN="/usr/local/bin/udpcustom"

while true; do

clear

source "$CONFIG"

if [[ "$UDPCUSTOM" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}            🚀 UDP CUSTOM MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado     : $STATUS"
echo -e " Puerto     : $PORT"
echo -e " Servicio   : UDP Custom"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


if [[ "$UDPCUSTOM" == "ON" ]]; then

cat <<EOF
 [1] ➮ Desinstalar UDP Custom
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF

else

cat <<EOF
 [1] ➮ Instalar UDP Custom
 [0] ➮ Regresar
EOF

fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP


case "$OP" in
1)

clear

if [[ "$UDPCUSTOM" == "ON" ]]; then


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "     DESINSTALAR UDP CUSTOM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


read -rp "¿Eliminar UDP Custom? (s/n): " R


if [[ "$R" =~ ^[Ss]$ ]]; then


systemctl stop $SERVICE 2>/dev/null
systemctl disable $SERVICE 2>/dev/null


rm -f /etc/systemd/system/$SERVICE.service
rm -f "$BIN"


systemctl daemon-reload


if grep -q "^UDPCUSTOM=" "$CONFIG"; then
    sed -i 's/^UDPCUSTOM=.*/UDPCUSTOM=ON/' "$CONFIG"
else
    echo "UDPCUSTOM=ON" >> "$CONFIG"
fi

UDPCUSTOM="OFF"


echo ""
echo "✅ UDP Custom eliminado."

else

echo "❌ Cancelado."

fi


else


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       INSTALANDO UDP CUSTOM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


apt update -y >/dev/null 2>&1

apt install -y wget curl >/dev/null 2>&1


echo "📦 Instalando dependencias..."

apt install -y git cmake build-essential >/dev/null 2>&1


echo "⬇️ Descargando fuente UDP Custom..."

rm -rf /tmp/udpcustom-build

git clone -q https://github.com/ambrop72/badvpn.git /tmp/udpcustom-build


cd /tmp/udpcustom-build


mkdir -p build
cd build


cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1


make -j$(nproc) >/dev/null 2>&1


if [ -f "udpgw/badvpn-udpgw" ]; then

    cp udpgw/badvpn-udpgw "$BIN"

    chmod +x "$BIN"

    echo "✅ Binario UDP Custom creado."

else

    echo "❌ Error compilando UDP Custom."
    exit 1

fi


rm -rf /tmp/udpcustom-build


cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=UDP Custom Server
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 0.0.0.0:$PORT --max-clients 999
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload

systemctl enable $SERVICE

systemctl restart $SERVICE


sed -i 's/^UDPCUSTOM=.*/UDPCUSTOM=ON/' "$CONFIG"

UDPCUSTOM="ON"


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      ✅ UDP CUSTOM ACTIVADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "🌐 Puerto UDP : $PORT"


fi


sleep 3

;;
2)

clear

echo "🔄 Reiniciando UDP Custom..."

systemctl restart $SERVICE

echo ""
echo "✅ Servicio reiniciado."

sleep 2

;;


3)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        ESTADO UDP CUSTOM${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""

systemctl status $SERVICE --no-pager


echo ""

echo "Puerto escuchando:"

ss -ulnp | grep "$PORT"


echo ""

read -n1 -r -p "Presione una tecla para continuar..."

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
