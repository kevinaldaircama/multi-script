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

SERVICE1="badvpn-udpgw-7300"
SERVICE2="badvpn-udpgw-7200"

PORT1="7300"
PORT2="7200"

BIN="/usr/local/bin/badvpn-udpgw"
while true; do

clear

source "$CONFIG"

if [[ "$BADVPN" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}            🌐 BADVPN MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado      : $STATUS"
echo -e " Puerto 1    : $PORT1"
echo -e " Puerto 2    : $PORT2"
echo -e " Servicio    : BadVPN UDPGW"

echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$BADVPN" == "ON" ]]; then
cat <<EOF
 [1] ➮ Reinstalar BadVPN
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [4] ➮ Desinstalar
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar BadVPN
 [0] ➮ Regresar
EOF
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in
1)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        INSTALANDO BADVPN UDPGW${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""

apt update -y >/dev/null 2>&1

echo "📦 Instalando dependencias..."

apt install -y git cmake build-essential >/dev/null 2>&1


echo "⬇️ Descargando BadVPN..."

rm -rf /tmp/badvpn

git clone -q https://github.com/ambrop72/badvpn.git /tmp/badvpn


echo "⚙️ Compilando..."

cd /tmp/badvpn

mkdir -p build

cd build


cmake .. \
-DBUILD_NOTHING_BY_DEFAULT=1 \
-DBUILD_UDPGW=1 >/dev/null 2>&1


make -j$(nproc) >/dev/null 2>&1


if [[ -f "udpgw/badvpn-udpgw" ]]; then

cp udpgw/badvpn-udpgw "$BIN"

chmod +x "$BIN"


echo "✅ Binario instalado."

else

echo "❌ Error compilando BadVPN."

sleep 3
continue

fi
echo "⚙️ Creando servicios BadVPN..."


cat > /etc/systemd/system/$SERVICE1.service <<EOF
[Unit]
Description=BadVPN UDPGW Puerto 7300
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 127.0.0.1:$PORT1 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


cat > /etc/systemd/system/$SERVICE2.service <<EOF
[Unit]
Description=BadVPN UDPGW Puerto 7200
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 127.0.0.1:$PORT2 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload


systemctl enable $SERVICE1 >/dev/null 2>&1
systemctl enable $SERVICE2 >/dev/null 2>&1


systemctl restart $SERVICE1
systemctl restart $SERVICE2


sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG"

BADVPN="ON"


echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}       ✅ BADVPN ACTIVADO${RESET}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo "🎮 Juegos      : Puerto $PORT1"
echo "📞 Videollamada: Puerto $PORT2"
echo ""

read -rp "¿Iniciar después de reiniciar VPS? (s/n): " AUTO

if [[ "$AUTO" =~ ^[Ss]$ ]]; then

systemctl enable $SERVICE1
systemctl enable $SERVICE2

echo "✅ Inicio automático activado."

else

systemctl disable $SERVICE1
systemctl disable $SERVICE2

echo "ℹ️ Inicio automático desactivado."

fi


sleep 3

;;

