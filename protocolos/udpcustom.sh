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
RESET="\e[0m"


SERVICE="udp-custom"
PORT="2100"
BIN="/usr/bin/udp"
CONFIG_UDP="/usr/bin/config.json"


set_udp_status(){

if systemctl is-active --quiet "$SERVICE"; then
    STATUS="${GREEN}🟢 ACTIVO${RESET}"
else
    STATUS="${RED}🔴 DETENIDO${RESET}"
fi

}


install_udp(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       🚀 INSTALANDO UDP CUSTOM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


apt update -y

apt install -y curl wget iptables libpam0g


echo "⚙️ Activando IP Forward..."

sysctl -w net.ipv4.ip_forward=1

grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || \
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf


ARCH=$(uname -m)


case "$ARCH" in

x86_64)
URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64"
;;

aarch64)
URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm"
;;

*)
echo "❌ Arquitectura no soportada: $ARCH"
return
;;

esac


echo "⬇️ Descargando UDP..."

curl -L -s -f "$URL" -o "$BIN"


if [[ ! -f "$BIN" ]]; then

echo "❌ Error descargando UDP"

return

fi


chmod +x "$BIN"



echo "📝 Creando configuración..."

cat > "$CONFIG_UDP" <<EOF
{
    "listen": ":2100",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
EOF



echo "⚙️ Creando servicio..."


cat > /etc/systemd/system/$SERVICE.service <<EOF
[Unit]
Description=UDP Custom Server KevinTech
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/udp server -exclude 2200,7300,7200,7100,323,10008,10004 /usr/bin/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload

systemctl enable "$SERVICE"

systemctl restart "$SERVICE"



if systemctl is-active --quiet "$SERVICE"; then

echo "UDPCUSTOM=ON" >> "$CONFIG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ UDP CUSTOM INSTALADO"
echo "Puerto: $PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

else

echo "❌ UDP no inició"
journalctl -u "$SERVICE" --no-pager -n 20

fi


sleep 3

}
remove_udp(){

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       🗑️ ELIMINAR UDP CUSTOM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


read -rp "¿Eliminar UDP Custom? (s/n): " CONFIRM


if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then

echo "❌ Cancelado"
sleep 2
return

fi



echo "⏳ Deteniendo servicio..."


systemctl stop "$SERVICE" 2>/dev/null

systemctl disable "$SERVICE" 2>/dev/null



echo "🧹 Eliminando archivos..."


rm -f "/etc/systemd/system/$SERVICE.service"

rm -f "$BIN"

rm -f "$CONFIG_UDP"



systemctl daemon-reload



echo "🧹 Limpiando reglas temporales..."


DEV=$(ip -4 route show default | awk '{print $5}' | head -1)



if [[ -n "$DEV" ]]; then


iptables -t nat -S PREROUTING 2>/dev/null \
| grep "2100" \
| sed 's/-A/-D/' \
| while read RULE
do
iptables -t nat $RULE 2>/dev/null
done



iptables -S INPUT 2>/dev/null \
| grep "2100" \
| sed 's/-A/-D/' \
| while read RULE
do
iptables $RULE 2>/dev/null
done


fi



sed -i '/^UDPCUSTOM=/d' "$CONFIG"

echo "UDPCUSTOM=OFF" >> "$CONFIG"


echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ UDP CUSTOM ELIMINADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


sleep 3

}



restart_udp(){


clear


echo "🔄 Reiniciando UDP Custom..."


systemctl restart "$SERVICE"



sleep 2



if systemctl is-active --quiet "$SERVICE"; then

echo "✅ Servicio activo"

else

echo "❌ No pudo iniciar"

journalctl -u "$SERVICE" --no-pager -n 15

fi


sleep 3


}



status_udp(){


clear


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       📊 ESTADO UDP CUSTOM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


echo ""


systemctl status "$SERVICE" --no-pager



echo ""

echo "Puerto interno: $PORT"


echo ""

echo "Escuchando UDP:"


ss -ulnp | grep ":$PORT"



echo ""

read -n1 -r -p "Presiona una tecla para continuar..."

}
while true
do

clear

source "$CONFIG"


set_udp_status



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}             🚀 UDP CUSTOM MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e " Estado   : $STATUS"
echo -e " Puerto   : $PORT"
echo -e " Servicio : udp-custom"


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


if [[ "$UDPCUSTOM" == "ON" ]]; then

remove_udp

else

install_udp

fi

;;



2)


if [[ "$UDPCUSTOM" == "ON" ]]; then

restart_udp

else

echo "❌ UDP Custom no está instalado"

sleep 2

fi

;;



3)


if [[ "$UDPCUSTOM" == "ON" ]]; then

status_udp

else

echo "❌ UDP Custom no está instalado"

sleep 2

fi

;;



0)


if [[ -f "$BASE/protocolos/menu.sh" ]]; then

exec bash "$BASE/protocolos/menu.sh"

else

clear

echo "❌ Menú principal no encontrado"

sleep 2

exit

fi

;;



*)

echo "❌ Opción inválida"

sleep 2

;;


esac


done
