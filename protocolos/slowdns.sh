#!/bin/bash

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ ! -f "$CONFIG" ]] && {
    echo "❌ No existe configuración KevinTech"
    exit 1
}

source "$CONFIG"


CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
YELLOW="\e[1;93m"
RESET="\e[0m"


SERVICE="slowdns"

PORT="5300"

BIN="/usr/bin/slowdns-server"

DIR="/etc/slowdns"

PUBKEY="$DIR/server.pub"

PRIVKEY="$DIR/server.key"

DOMAIN_FILE="$DIR/domain.conf"



set_status(){

if systemctl is-active --quiet "$SERVICE"; then

STATUS="${GREEN}🟢 ACTIVO${RESET}"

else

STATUS="${RED}🔴 DETENIDO${RESET}"

fi

}



install_slowdns(){


clear


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        🚀 INSTALAR SLOWDNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"



read -rp "🌐 Dominio NS (ejemplo ns.midominio.com): " DOMAIN


if [[ -z "$DOMAIN" ]]; then

echo "❌ Dominio vacío"

sleep 2

return

fi



apt update -y

apt install -y curl wget openssl



mkdir -p "$DIR"



echo "$DOMAIN" > "$DOMAIN_FILE"



ARCH=$(uname -m)



case "$ARCH" in


x86_64)

URL="https://dnstt.network/dnstt-server-linux-amd64"

;;


aarch64)

URL="https://dnstt.network/dnstt-server-linux-arm64"

;;


*)

echo "❌ Arquitectura no soportada: $ARCH"

return

;;

esac



echo "⬇️ Descargando SlowDNS..."



curl -L -s -f "$URL" -o "$BIN"



if [[ ! -f "$BIN" ]]; then

echo "❌ Error descargando binario"

return

fi



chmod +x "$BIN"



echo "🔑 Generando claves..."



if [[ ! -f "$PUBKEY" ]]; then


"$BIN" \
-gen-key \
-privkey-file "$PRIVKEY" \
-pubkey-file "$PUBKEY"


fi
echo "⚙️ Creando servicio systemd..."


cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=KevinTech SlowDNS Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN -udp :$PORT -privkey-file $PRIVKEY $(cat $DOMAIN_FILE) 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload


systemctl enable "$SERVICE"


systemctl restart "$SERVICE"



sleep 2



if systemctl is-active --quiet "$SERVICE"; then


sed -i '/^SLOWDNS=/d' "$CONFIG"

echo "SLOWDNS=ON" >> "$CONFIG"



echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "✅ SLOWDNS INSTALADO"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""

echo "🌐 Dominio:"
cat "$DOMAIN_FILE"

echo ""

echo "🔑 Public Key:"

cat "$PUBKEY"


else


echo "❌ Error iniciando SlowDNS"

journalctl -u "$SERVICE" --no-pager -n 20


fi



sleep 3


}



remove_slowdns(){


clear


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "        🗑️ ELIMINAR SLOWDNS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"



read -rp "¿Eliminar SlowDNS? (s/n): " CONFIRM



if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then

echo "❌ Cancelado"

sleep 2

return

fi



systemctl stop "$SERVICE" 2>/dev/null


systemctl disable "$SERVICE" 2>/dev/null



rm -f "/etc/systemd/system/$SERVICE.service"


rm -f "$BIN"


rm -rf "$DIR"



systemctl daemon-reload



sed -i '/^SLOWDNS=/d' "$CONFIG"

echo "SLOWDNS=OFF" >> "$CONFIG"



echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "✅ SLOWDNS ELIMINADO"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"



sleep 3


}



restart_slowdns(){


clear


echo "🔄 Reiniciando SlowDNS..."



systemctl restart "$SERVICE"



sleep 2



if systemctl is-active --quiet "$SERVICE"; then


echo "✅ SlowDNS activo"


else


echo "❌ Error reiniciando SlowDNS"

journalctl -u "$SERVICE" --no-pager -n 15


fi



sleep 3


}
status_slowdns(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}            📊 ESTADO SLOWDNS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo ""


systemctl status "$SERVICE" --no-pager



echo ""

echo "Puerto UDP DNS: $PORT"


echo ""

echo "Puerto escuchando:"

ss -ulnp | grep ":$PORT"



echo ""

if [[ -f "$DOMAIN_FILE" ]]; then

echo "🌐 Dominio NS:"

cat "$DOMAIN_FILE"

fi



echo ""

echo "🔑 Public Key:"

echo ""


if [[ -f "$PUBKEY" ]]; then

cat "$PUBKEY"

else

echo "❌ No existe Public Key"

fi



echo ""

read -n1 -r -p "Presiona una tecla para continuar..."

}



show_key(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}             🔑 PUBLIC KEY SLOWDNS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo ""


if [[ -f "$PUBKEY" ]]; then

cat "$PUBKEY"

else

echo "❌ Public Key no encontrada"

fi



echo ""

read -n1 -r -p "Presiona una tecla para continuar..."


}



while true
do


clear


source "$CONFIG"


set_status



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}              🐌 SLOWDNS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e " Estado       : $STATUS"

echo -e " Puerto DNS   : $PORT"

echo -e " Servicio     : slowdns"



if [[ -f "$DOMAIN_FILE" ]]; then

echo -e " Dominio NS   : ${YELLOW}$(cat $DOMAIN_FILE)${RESET}"

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

remove_slowdns

else

install_slowdns

fi

;;



2)


restart_slowdns

;;



3)


status_slowdns

;;



4)


show_key

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
