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
RESET="\e[0m"

BANNER="/etc/issue.net"

while true; do

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}            📢 BANNER SSH / DROPBEAR 📢             ${CYAN}║${RESET}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

echo -e "${GREEN}[1]${WHITE} Crear nuevo banner"
echo -e "${BLUE}[2]${WHITE} Ver banner actual"
echo -e "${YELLOW}[3]${WHITE} Editar banner"
echo -e "${RED}[4]${WHITE} Eliminar banner"
echo -e "${CYAN}[0]${WHITE} Regresar"

echo
read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

case "$OP" in

1)

clear
echo -e "${CYAN}Ingrese el contenido del banner.${RESET}"
echo -e "${YELLOW}Finalice escribiendo una línea con: EOF${RESET}"
echo

> "$BANNER"

while IFS= read -r LINEA; do
    [[ "$LINEA" == "EOF" ]] && break
    echo "$LINEA" >> "$BANNER"
done

grep -q "^Banner" /etc/ssh/sshd_config \
&& sed -i "s|^Banner.*|Banner $BANNER|" /etc/ssh/sshd_config \
|| echo "Banner $BANNER" >> /etc/ssh/sshd_config

if [ -f /etc/default/dropbear ]; then
    grep -q "^DROPBEAR_BANNER=" /etc/default/dropbear \
    && sed -i "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" /etc/default/dropbear \
    || echo "DROPBEAR_BANNER=\"$BANNER\"" >> /etc/default/dropbear
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

echo -e "${CYAN}══════════ BANNER ACTUAL ══════════${RESET}"
echo

if [ -f "$BANNER" ]; then
    cat "$BANNER"
else
    echo -e "${RED}No existe ningún banner.${RESET}"
fi

echo
read -n1 -s -r -p "Presione cualquier tecla..."
;;

3)

nano "$BANNER"

systemctl restart ssh 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

echo
echo -e "${GREEN}✔ Banner actualizado.${RESET}"
sleep 2
;;

4)

rm -f "$BANNER"

sed -i '/^Banner /d' /etc/ssh/sshd_config

if [ -f /etc/default/dropbear ]; then
    sed -i '/^DROPBEAR_BANNER=/d' /etc/default/dropbear
fi

systemctl restart ssh 2>/dev/null
systemctl restart sshd 2>/dev/null
systemctl restart dropbear 2>/dev/null

echo
echo -e "${GREEN}✔ Banner eliminado.${RESET}"
sleep 2
;;

0)
exit
;;

*)

echo
echo -e "${RED}Opción inválida.${RESET}"
sleep 2
;;

esac

done
