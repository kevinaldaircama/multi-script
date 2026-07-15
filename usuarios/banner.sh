#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner SSH / Dropbear
#==================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==============================
# CONFIG KEVINTECH
#==============================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

BANNER="/etc/issue.net"
SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"

while true; do

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}            📢 BANNER SSH / DROPBEAR 📢            ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"

echo -e "${GREEN}[1]${WHITE} Crear nuevo Banner"
echo -e "${BLUE}[2]${WHITE} Ver Banner actual"
echo -e "${YELLOW}[3]${WHITE} Editar Banner"
echo -e "${RED}[4]${WHITE} Eliminar Banner"
echo -e "${CYAN}[0]${WHITE} Regresar"

echo
read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

case "$OP" in

1)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               CREAR NUEVO BANNER                 ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${GREEN}Nombre del Servidor:${RESET} ")" SERVER
[[ -z "$SERVER" ]] && SERVER="${SERVER_NAME:-KevinTech VPN}"

read -rp "$(echo -e "${GREEN}Texto Promocional:${RESET} ")" PROMO
[[ -z "$PROMO" ]] && PROMO="🔥 Bienvenido a $SERVER 🔥"

read -rp "$(echo -e "${GREEN}Canal Telegram (ej. @KevinTech):${RESET} ")" CHANNEL

read -rp "$(echo -e "${GREEN}Soporte (ej. @KevinSupport):${RESET} ")" SUPPORT

cat > "$BANNER" <<EOF
<html>

<center>
<font color="#00ff00"><b>$SERVER</b></font><br>
<font color="#29b6f6">══════════════════════</font><br><br>

<font color="#ffffff">$PROMO</font><br><br>

<font color="#ffff00">📢 Canal: $CHANNEL</font><br>
<font color="#00ffff">👤 Soporte: $SUPPORT</font><br><br>

<font color="#29b6f6">══════════════════════</font><br>
<font color="#00ff00">Gracias por usar nuestros servicios</font>

</center>

</html>
EOF

# Configurar OpenSSH
if grep -q "^Banner" "$SSHD"; then
    sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"
else
    echo "Banner $BANNER" >> "$SSHD"
fi

# Configurar Dropbear
if [[ -f "$DROPBEAR" ]]; then
    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
        sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" "$DROPBEAR"
    else
        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"
    fi
fi

systemctl restart ssh 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

echo
echo -e "${GREEN}✔ Banner creado correctamente.${RESET}"
sleep 2
;;

2)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                 BANNER ACTUAL                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

if [[ -f "$BANNER" ]]; then

    echo -e "${GREEN}Ruta:${RESET} $BANNER"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    cat "$BANNER"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

else

    echo -e "${RED}No existe ningún banner creado.${RESET}"

fi

echo
read -n1 -s -r -p "Presione cualquier tecla para regresar..."

;;

3)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}                 EDITAR BANNER                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

# Si no existe el banner, crear uno básico
if [[ ! -f "$BANNER" ]]; then

cat > "$BANNER" <<EOF
<html>

<center>

<font color="#00ff00"><b>${SERVER_NAME:-KevinTech VPN}</b></font><br>
<font color="#ffffff">Bienvenido a nuestro servidor</font>

</center>

</html>
EOF

fi

# Verificar que nano esté instalado
if ! command -v nano >/dev/null 2>&1; then
    echo -e "${RED}Nano no está instalado.${RESET}"
    sleep 2
    ;;
fi

# Abrir editor
nano "$BANNER"

# Configurar OpenSSH
if grep -q "^Banner" "$SSHD"; then
    sed -i "s|^Banner.*|Banner $BANNER|" "$SSHD"
else
    echo "Banner $BANNER" >> "$SSHD"
fi

# Configurar Dropbear
if [[ -f "$DROPBEAR" ]]; then
    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
        sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" "$DROPBEAR"
    else
        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"
    fi
fi

# Reiniciar servicios
systemctl restart ssh 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

echo
echo -e "${GREEN}✔ Banner actualizado correctamente.${RESET}"
sleep 2

;;

4)

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ELIMINAR BANNER                    ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
echo

if [[ ! -f "$BANNER" ]]; then
    echo -e "${RED}No existe ningún banner para eliminar.${RESET}"
    sleep 2
    ;;
fi

read -rp "$(echo -e "${YELLOW}¿Desea eliminar el banner? [S/N]: ${RESET}")" RESP

case "$RESP" in

s|S|si|SI|Sí|sí)

    # Eliminar archivo del banner
    rm -f "$BANNER"

    # Eliminar configuración de OpenSSH
    sed -i '/^Banner /d' "$SSHD"

    # Eliminar configuración de Dropbear
    if [[ -f "$DROPBEAR" ]]; then
        sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
    fi

    # Reiniciar servicios
    systemctl restart ssh 2>/dev/null
    systemctl restart sshd 2>/dev/null
    systemctl restart dropbear 2>/dev/null

    echo
    echo -e "${GREEN}✔ Banner eliminado correctamente.${RESET}"
    ;;

*)

    echo
    echo -e "${YELLOW}Operación cancelada.${RESET}"
    ;;

esac

sleep 2

;;

0)
break
;;

*)
echo
echo -e "${RED}Opción inválida.${RESET}"
sleep 2
;;

esac

done
