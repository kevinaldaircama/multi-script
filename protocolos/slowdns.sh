#!/bin/bash

#==================================================
# KevinTech Multi Script
# SlowDNS + DNSDist Manager
#==================================================


BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"


if [[ ! -f "$CONFIG" ]]; then
    echo "❌ No existe configuración KevinTech"
    exit 1
fi


source "$CONFIG"


CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
WHITE="\e[1;97m"
YELLOW="\e[1;93m"
RESET="\e[0m"



SERVICE="slowdns"
DNSDIST="dnsdist"

PORT="5300"
DNSDIST_PORT="5380"

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



install_dependencies(){


echo "📦 Instalando dependencias..."


apt update -y


apt install -y \
curl \
wget \
dnsdist \
iptables \
ca-certificates


systemctl enable dnsdist


}



install_slowdns_binary(){


mkdir -p "$DIR"


ARCH=$(uname -m)



case "$ARCH" in


x86_64)

URL="https://dnstt.network/dnstt-server-linux-amd64"

;;


aarch64|arm64)

URL="https://dnstt.network/dnstt-server-linux-arm64"

;;


*)

echo "❌ Arquitectura no soportada: $ARCH"

return 1

;;

esac



echo "⬇️ Descargando SlowDNS Server..."



curl -L -s -f "$URL" -o "$BIN"



if [[ ! -f "$BIN" ]]; then

echo "❌ Error descargando SlowDNS"

return 1

fi



chmod +x "$BIN"



}



generate_keys(){


echo "🔑 Generando claves DNSTT..."



if [[ ! -f "$PUBKEY" || ! -f "$PRIVKEY" ]]; then


"$BIN" \
-gen-key \
-privkey-file "$PRIVKEY" \
-pubkey-file "$PUBKEY"


fi


}
configure_dnsdist(){


echo "⚙️ Configurando DNSDist..."


mkdir -p /etc/dnsdist



cat > /etc/dnsdist/dnsdist.conf <<EOF
-- KevinTech DNSDist Auto Config

setLocal("0.0.0.0:5380")

addACL("0.0.0.0/0")
addACL("::/0")


newServer({
    address="127.0.0.1:5300",
    name="slowdns",
    pool="slowdns"
})


local ns = "$(cat $DOMAIN_FILE | sed 's/\./\\\\./g')"


addAction(
    RegexRule(ns),
    PoolAction("slowdns")
)


EOF



systemctl enable dnsdist


}



create_slowdns_service(){


echo "⚙️ Creando servicio SlowDNS..."



DOMAIN=$(cat "$DOMAIN_FILE")



cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=KevinTech SlowDNS Server
After=network.target


[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN -udp :5300 -privkey-file $PRIVKEY $DOMAIN 127.0.0.1:22
Restart=always
RestartSec=3


[Install]
WantedBy=multi-user.target
EOF



systemctl daemon-reload


systemctl enable slowdns


}



install_slowdns(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}        🚀 INSTALAR SLOWDNS${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



read -rp "🌐 Dominio NS (ejemplo ns.midominio.com): " DOMAIN



if [[ -z "$DOMAIN" ]]; then

echo "❌ Dominio vacío"

sleep 2

return

fi



install_dependencies



install_slowdns_binary



echo "$DOMAIN" > "$DOMAIN_FILE"



generate_keys



create_slowdns_service



configure_dnsdist



echo "🔄 Reiniciando servicios..."



systemctl restart slowdns

systemctl restart dnsdist



sleep 3



if systemctl is-active --quiet slowdns && systemctl is-active --quiet dnsdist; then


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


echo "❌ Error iniciando servicios"

echo ""

systemctl status slowdns --no-pager

systemctl status dnsdist --no-pager


fi


sleep 4


}
remove_slowdns(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}        🗑️ ELIMINAR SLOWDNS${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



read -rp "¿Eliminar SlowDNS? (s/n): " CONFIRM



if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then

echo "❌ Cancelado"

sleep 2

return

fi



echo "⏳ Deteniendo servicios..."



systemctl stop "$SERVICE" 2>/dev/null

systemctl disable "$SERVICE" 2>/dev/null



systemctl stop "$DNSDIST" 2>/dev/null

systemctl disable "$DNSDIST" 2>/dev/null



echo "🧹 Eliminando servicios..."



rm -f "/etc/systemd/system/$SERVICE.service"



rm -f "/etc/dnsdist/dnsdist.conf"



rm -f "$BIN"



rm -rf "$DIR"



systemctl daemon-reload



echo "🧹 Limpiando reglas DNS..."



iptables -t nat -S PREROUTING 2>/dev/null \
| grep "5380" \
| sed 's/-A/-D/' \
| while read RULE
do
iptables -t nat $RULE 2>/dev/null
done



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

systemctl restart "$DNSDIST"



sleep 3



if systemctl is-active --quiet "$SERVICE" && systemctl is-active --quiet "$DNSDIST"; then


echo "✅ SlowDNS + DNSDist activos"



else


echo "❌ Error reiniciando servicios"



journalctl -u "$SERVICE" --no-pager -n 20

journalctl -u "$DNSDIST" --no-pager -n 20



fi



sleep 3


}



status_slowdns(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}        📊 ESTADO SLOWDNS${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



echo ""

echo "🐌 Servicio SlowDNS"

echo ""

systemctl status "$SERVICE" --no-pager



echo ""

echo "🌐 Servicio DNSDist"

echo ""

systemctl status "$DNSDIST" --no-pager



echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


echo "Puertos:"


ss -ulnp | grep -E "5300|5380"



echo ""


echo "Dominio NS:"

if [[ -f "$DOMAIN_FILE" ]]; then

cat "$DOMAIN_FILE"

else

echo "No configurado"

fi



echo ""

echo "Public Key:"

echo ""


if [[ -f "$PUBKEY" ]]; then

cat "$PUBKEY"

else

echo "No existe"

fi



echo ""

read -n1 -r -p "Presiona una tecla para continuar..."


}
show_key(){


clear


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${WHITE}          🔑 PUBLIC KEY SLOWDNS${RESET}"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



echo ""


if [[ -f "$PUBKEY" ]]; then

cat "$PUBKEY"

else

echo "❌ No existe Public Key"

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
echo -e "${WHITE}             🐌 SLOWDNS MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e " Estado       : $STATUS"

echo -e " Puerto DNS   : $PORT"

echo -e " DNSDist      : $DNSDIST_PORT"



if [[ -f "$DOMAIN_FILE" ]]; then

echo -e " Dominio NS   : ${YELLOW}$(cat "$DOMAIN_FILE")${RESET}"

fi



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



if [[ "$SLOWDNS" == "ON" ]]; then


cat <<EOF

 [1] ➮ Desinstalar SlowDNS
 [2] ➮ Reiniciar Servicios
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
