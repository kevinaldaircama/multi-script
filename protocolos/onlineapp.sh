#!/bin/bash

BASE="/etc/kevintech"
ONLINEAPP="/usr/local/bin/onlineapp"

IP=$(wget -qO- ipv4.icanhazip.com)

clear
echo "======================================"
echo "     KevinTech Multi Script"
echo "         ONLINE APP"
echo "======================================"
echo

if pgrep -f "$ONLINEAPP" >/dev/null; then

    echo "Estado: 🟢 ACTIVO"
    echo
    echo "URL:"
    echo "http://$IP:8888/server/online"
    echo "http://$IP:8888/server/online_app"
    echo
    read -rp "¿Desea detener la Online App? [S/N]: " OP

    if [[ "$OP" =~ ^[Ss]$ ]]; then
        pkill -f "$ONLINEAPP"
        screen -S onlineapp -X quit >/dev/null 2>&1
        echo
        echo "✓ Online App detenida."
    fi

else

    echo "Estado: 🔴 DETENIDO"
    echo
    read -rp "¿Desea iniciar la Online App? [S/N]: " OP

    if [[ "$OP" =~ ^[Ss]$ ]]; then

        apt install apache2 -y >/dev/null 2>&1
        sed -i 's/^Listen 80$/Listen 8888/' /etc/apache2/ports.conf >/dev/null 2>&1
        mkdir -p /var/www/html/server
        service apache2 restart >/dev/null 2>&1

        screen -dmS onlineapp "$ONLINEAPP"

        echo
        echo "✓ Online App iniciada."
        echo
        echo "URL:"
        echo "http://$IP:8888/server/online"
        echo "http://$IP:8888/server/online_app"
    fi

fi

echo
read -n1 -s -r -p "Presione una tecla para volver..."
exec bash "$BASE/protocolos/checkuser.sh"
