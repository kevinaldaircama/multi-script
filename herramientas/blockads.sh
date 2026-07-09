#!/bin/bash

#==================================================
# KevinTech Multi Script
# Block Ads
#==================================================

BASE="/etc/kevintech"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
RESET="\e[0m"

HOSTS="/etc/hosts"

bloquear() {

echo ""
echo "⏳ Bloqueando publicidad..."

cp "$HOSTS" "$HOSTS.bak"

cat <<EOF >> "$HOSTS"

# KevinTech Block Ads
0.0.0.0 ads.google.com
0.0.0.0 adservice.google.com
0.0.0.0 pagead2.googlesyndication.com
0.0.0.0 googleads.g.doubleclick.net
0.0.0.0 doubleclick.net
0.0.0.0 ad.doubleclick.net
0.0.0.0 ads.yahoo.com
0.0.0.0 ads.facebook.com
0.0.0.0 graph.facebook.com
0.0.0.0 ads.twitter.com
0.0.0.0 app-measurement.com
0.0.0.0 analytics.google.com
0.0.0.0 ssl.google-analytics.com
0.0.0.0 www.google-analytics.com
EOF

echo ""
echo -e "${GREEN}✅ Publicidad bloqueada.${RESET}"

sleep 3

}

desbloquear() {

echo ""
echo "⏳ Restaurando archivo hosts..."

if [[ -f "$HOSTS.bak" ]]; then
    mv -f "$HOSTS.bak" "$HOSTS"
    echo ""
    echo -e "${GREEN}✅ Bloqueo eliminado.${RESET}"
else
    echo ""
    echo -e "${RED}❌ No existe una copia de seguridad.${RESET}"
fi

sleep 3

}

while true
do

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}             🚫 BLOCK ADS${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo " [1] ➮ Bloquear Publicidad"
echo " [2] ➮ Desbloquear Publicidad"
echo ""
echo " [0] ➮ Regresar"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

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
