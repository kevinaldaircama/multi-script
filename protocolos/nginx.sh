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

BIN="/usr/local/bin/zivpn-panel"

while true; do

clear

source "$CONFIG"

if command -v zivpn-panel >/dev/null 2>&1; then

    STATUS="${GREEN}🟢 INSTALADO${RESET}"

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG"
    else
        echo "ZIPVPN=ON" >> "$CONFIG"
    fi

else

    STATUS="${RED}🔴 DESINSTALADO${RESET}"

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=OFF/' "$CONFIG"
    else
        echo "ZIPVPN=OFF" >> "$CONFIG"
    fi

fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}         🚀 ZIPVPN MANAGER${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " Estado  : $STATUS"
echo -e " Binario : $BIN"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if command -v zivpn-panel >/dev/null 2>&1; then

cat <<EOF

 [1] ➮ Actualizar ZIPVPN
 [2] ➮ Abrir Panel ZIPVPN
 [3] ➮ Desinstalar Panel
 [0] ➮ Regresar

EOF

else

cat <<EOF

 [1] ➮ Instalar ZIPVPN
 [0] ➮ Regresar

EOF

fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

read -rp " ► Opción: " OP

case "$OP" in

1)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}      INSTALANDO ZIPVPN${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

bash <(curl -fsSL https://raw.githubusercontent.com/Depwisescript/zivpn-panel/main/install.sh)
if command -v zivpn-panel >/dev/null 2>&1; then

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG"
    else
        echo "ZIPVPN=ON" >> "$CONFIG"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ ZIPVPN INSTALADO / ACTUALIZADO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

else

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=OFF/' "$CONFIG"
    else
        echo "ZIPVPN=OFF" >> "$CONFIG"
    fi

    echo ""
    echo "❌ Error al instalar ZIPVPN."

fi

echo ""
while true; do
    read -rp "Escribe menu para volver: " SALIR
    [[ "$SALIR" == "menu" ]] && exec bash "$BASE/protocolos/menu.sh"
done

;;

2)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}      ABRIENDO ZIPVPN PANEL${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if command -v zivpn-panel >/dev/null 2>&1; then
    zivpn-panel
else
    echo "❌ ZIPVPN no está instalado."
    sleep 2
fi

;;
3)

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}       DESINSTALAR ZIPVPN PANEL${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""

read -rp "¿Eliminar ZIPVPN Panel? (s/n): " R

if [[ "$R" =~ ^[Ss]$ ]]; then

    rm -f "$BIN"

    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=OFF/' "$CONFIG"
    else
        echo "ZIPVPN=OFF" >> "$CONFIG"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ ZIPVPN PANEL ELIMINADO"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo ""
    echo "⚠️ Nota:"
    echo "Los datos de ZiVPN no fueron eliminados."
    echo "El panel original administra esos datos."

else

    echo ""
    echo "❌ Cancelado."

fi


sleep 3

;;

0)

exec bash "$BASE/protocolos/menu.sh"

;;

*)

echo ""
echo "❌ Opción inválida"
sleep 2

;;

esac

done
