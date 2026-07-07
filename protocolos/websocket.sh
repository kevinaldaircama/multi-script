#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || exit 1

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="websocket"
PORT="80"
TARGET="127.0.0.1:22"


instalar(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      INSTALANDO WEBSOCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📦 Instalando dependencias..."

apt update -y >/dev/null 2>&1
apt install -y wget tar curl >/dev/null 2>&1


echo "📥 Instalando wstunnel..."

ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
URL="https://github.com/erebe/wstunnel/releases/latest/download/wstunnel_linux_amd64"
else
URL="https://github.com/erebe/wstunnel/releases/latest/download/wstunnel_linux_arm64"
fi


wget -q "$URL" -O /usr/local/bin/wstunnel


if [[ ! -f /usr/local/bin/wstunnel ]]; then

echo "❌ Error descargando wstunnel"
sleep 3
return

fi


chmod +x /usr/local/bin/wstunnel


echo "⚙️ Creando servicio..."

cat > /etc/systemd/system/websocket.service <<EOF
[Unit]
Description=KevinTech WebSocket SSH Tunnel
After=network.target


[Service]
Type=simple
ExecStart=/usr/local/bin/wstunnel server ws://0.0.0.0:$PORT --restrict-to 127.0.0.1:22
Restart=always


[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload

systemctl enable websocket
systemctl restart websocket


sed -i 's/^WEBSOCKET=.*/WEBSOCKET=ON/' "$CONFIG"


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ WEBSOCKET INSTALADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Puerto : $PORT"
echo "➡ SSH    : $TARGET"

sleep 4

}
desinstalar(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    DESINSTALANDO WEBSOCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -rp "¿Eliminar WebSocket? (s/n): " RESP

if [[ "$RESP" =~ ^[Ss]$ ]]; then

systemctl stop websocket 2>/dev/null
systemctl disable websocket 2>/dev/null

rm -f /etc/systemd/system/websocket.service
rm -f /usr/local/bin/wstunnel

systemctl daemon-reload

sed -i 's/^WEBSOCKET=.*/WEBSOCKET=OFF/' "$CONFIG"

WEBSOCKET="OFF"

echo ""
echo "✅ WebSocket eliminado."

else

echo ""
echo "❌ Cancelado."

fi

sleep 3

}


reiniciar(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    REINICIANDO WEBSOCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

systemctl restart websocket

echo "✅ Servicio reiniciado."

sleep 3

}


estado(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       ESTADO WEBSOCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

systemctl status websocket --no-pager

echo ""
read -n1 -r -p "Presione una tecla para continuar..."

}
while true; do

clear

source "$CONFIG"

if [[ "$WEBSOCKET" == "ON" ]]; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DESINSTALADO${RESET}"
fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}          🌐 WEBSOCKET MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado     : $STATUS"
echo -e " Puerto     : $PORT"
echo -e " Destino    : $TARGET"
echo -e " Servicio   : $SERVICE"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


if [[ "$WEBSOCKET" == "ON" ]]; then

cat <<EOF
 [1] ➮ Desinstalar WebSocket
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [0] ➮ Regresar
EOF

else

cat <<EOF
 [1] ➮ Instalar WebSocket
 [0] ➮ Regresar
EOF

fi


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP


case "$OP" in


1)

if [[ "$WEBSOCKET" == "ON" ]]; then

desinstalar

else

instalar

fi

;;


2)

if [[ "$WEBSOCKET" == "ON" ]]; then

reiniciar

fi

;;


3)

if [[ "$WEBSOCKET" == "ON" ]]; then

estado

fi

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
