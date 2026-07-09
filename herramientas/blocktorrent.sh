#!/bin/bash

#==================================================
# KevinTech Multi Script
# Block Torrent
#==================================================

BASE="/etc/kevintech"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

bloquear() {

echo "⏳ Bloqueando BitTorrent..."

iptables -I INPUT -p tcp --dport 6881:6999 -j DROP
iptables -I OUTPUT -p tcp --sport 6881:6999 -j DROP

iptables -I INPUT -p udp --dport 6881:6999 -j DROP
iptables -I OUTPUT -p udp --sport 6881:6999 -j DROP

iptables -I INPUT -m string --algo bm --string "BitTorrent" -j DROP
iptables -I INPUT -m string --algo bm --string "peer_id=" -j DROP
iptables -I INPUT -m string --algo bm --string ".torrent" -j DROP
iptables -I INPUT -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -I INPUT -m string --algo bm --string "info_hash" -j DROP

echo ""
echo -e "${GREEN}✅ BitTorrent bloqueado correctamente.${RESET}"

sleep 3

}

desbloquear() {

echo "⏳ Eliminando reglas..."

iptables -F

echo ""
echo -e "${GREEN}✅ Reglas eliminadas.${RESET}"

sleep 3

}

while true
do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}          🛡️ Block Torrent 🛡️${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo " [1] ➮ Bloquear BitTorrent"
echo " [2] ➮ Desbloquear"
echo ""
echo " [0] ➮ Regresar"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " op

case "$op" in

1)
bloquear
;;

2)
desbloquear
;;

0)
exec bash "$BASE/herramientas/menu.sh"
;;

*)
echo ""
echo -e "${RED}❌ Opción inválida.${RESET}"
sleep 2
;;

esac

done
