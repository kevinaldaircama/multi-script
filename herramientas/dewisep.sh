#!/bin/bash

#==================================================

KevinTech Multi Script

Privanox Bot Manager

Usa el install_go.sh ORIGINAL

#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
NC="\e[0m"

SERVICE="depwise.service"

is_installed() {
systemctl list-unit-files | grep -q "^${SERVICE}"
}

show_status() {
if is_installed; then
echo -e "${GREEN}Estado: INSTALADO${NC}"
else
echo -e "${RED}Estado: NO INSTALADO${NC}"
fi
}

install_privanox() {
clear
echo -e "${CYAN}========================================${NC}"
echo -e "${WHITE}      INSTALANDO PRIVANOX BOT${NC}"
echo -e "${CYAN}========================================${NC}"
echo

# Usa el instalador ORIGINAL.
# Si INSTALL_KEY ya existe por el instalador principal,
# install_go.sh no volverá a pedir la key.
bash <(curl -fsSL https://raw.githubusercontent.com/kevinaldaircama/privanox-code/main/install_go.sh)

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}     PRIVANOX BOT INSTALADO${NC}"
echo -e "${GREEN}========================================${NC}"
read -rp "Presiona ENTER para continuar..."

}

uninstall_privanox() {
clear
echo -e "${RED}========================================${NC}"
echo -e "${RED}      DESINSTALANDO PRIVANOX BOT${NC}"
echo -e "${RED}========================================${NC}"
echo

systemctl stop depwise.service 2>/dev/null || true
systemctl disable depwise.service 2>/dev/null || true
rm -f /etc/systemd/system/depwise.service
systemctl daemon-reload

rm -f /usr/local/bin/depwise-bot
rm -rf /opt/depwise_bot
rm -f /root/bot_data.json

rm -f /usr/local/bin/badvpn-udpgw
rm -f /usr/bin/badvpn-udpgw
rm -f /usr/bin/badvpn
rm -f /usr/local/bin/proxydt
rm -f /usr/local/bin/falconproxy
rm -f /usr/local/bin/udpcustom
rm -rf /etc/zivpn
rm -f /usr/local/bin/zivpn
rm -f /etc/falconproxy.conf
rm -rf /etc/slowdns

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   PRIVANOX BOT DESINSTALADO${NC}"
echo -e "${GREEN}========================================${NC}"
read -rp "Presiona ENTER para continuar..."

}

while true; do
clear
echo -e "${CYAN}========================================${NC}"
echo -e "${WHITE}          PRIVANOX BOT${NC}"
echo -e "${CYAN}========================================${NC}"
show_status
echo

if is_installed; then
    echo -e "${WHITE}1.${NC} Desinstalar Privanox Bot"
else
    echo -e "${WHITE}1.${NC} Instalar Privanox Bot"
fi

echo -e "${WHITE}0.${NC} Volver"
echo
read -rp "Selecciona una opción: " op

case "$op" in
    1)
        if is_installed; then
            uninstall_privanox
        else
            install_privanox
        fi
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}Opción inválida${NC}"
        sleep 1
        ;;
esac

done
