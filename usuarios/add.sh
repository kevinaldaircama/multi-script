#!/bin/bash
#==================================================
# KevinTech Multi Script
# Crear Usuario SSH
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

if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi


clear


while true; do


clear


echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}             👤 CREAR USUARIO SSH 👤              ${CYAN}║${RESET}"
echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"


read -rp "$(echo -e "${GREEN}➤ Usuario:${RESET} ")" USER


if [[ -z "$USER" ]]; then

    echo -e "\n${RED}Debe ingresar un usuario.${RESET}"
    sleep 2
    continue

fi



if id "$USER" &>/dev/null; then

    echo -e "\n${RED}El usuario ya existe.${RESET}"
    sleep 2
    continue

fi



read -rsp "$(echo -e "${GREEN}➤ Contraseña:${RESET} ")" PASS

echo



if [[ -z "$PASS" ]]; then

    echo -e "\n${RED}Debe ingresar una contraseña.${RESET}"
    sleep 2
    continue

fi



read -rp "$(echo -e "${GREEN}➤ Días de duración:${RESET} ")" DIAS


[[ -z "$DIAS" ]] && DIAS=30



FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")



#==============================
# CREAR USUARIO SSH
#==============================


useradd -e "$FECHA" -M -s /bin/false "$USER"


echo "$USER:$PASS" | chpasswd



clear



#==============================
# DATOS VPS
#==============================


IP=$(curl -4 -s ifconfig.me 2>/dev/null)


FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")
#==============================
# MOSTRAR CUENTA CREADA
#==============================


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}             ⚜️ ${SERVER_NAME:-KevinTech} ⚜️${RESET}"
echo -e "${WHITE}          ❑ MENU DE CREACION DE USUARIOS ❒${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo
echo -e "${YELLOW}* Puertas Activas en su Servidor *${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


# SSH

if [[ "$OPENSSH" == "ON" ]]; then
echo -e "${WHITE}∘ SSH:${GREEN} 22"
fi


# WEBSOCKET

if [[ "$WEBSOCKET" == "ON" ]]; then
echo -e "${WHITE}∘ WEB-NGINX:${GREEN} 80"
fi


# DROPBEAR

if [[ "$DROPBEAR" == "ON" ]]; then
echo -e "${WHITE}∘ DROPBEAR:${GREEN} 90"
fi


# SSL

if [[ "$SSL" == "ON" ]]; then
echo -e "${WHITE}∘ SSL:${GREEN} 443"
fi


# SLOWDNS

if [[ "$SLOWDNS" == "ON" ]]; then
echo -e "${WHITE}∘ SlowDNS:${GREEN} 5300"
fi



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"



echo -e "${WHITE}DOMAIN  : ${GREEN}${SERVER_DOMAIN:-$IP}"
echo -e "${WHITE}Host/IP : ${GREEN}$IP"

echo -e "${WHITE}USUARIO : ${GREEN}$USER"
echo -e "${WHITE}PASSWD  : ${GREEN}$PASS"

echo -e "${WHITE}LIMITE  : ${GREEN}1"
echo -e "${WHITE}VALIDEZ : ${GREEN}$FECHA_MOSTRAR"



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e "${YELLOW}En APPS como HTTP Injector,CUSTOM,KPN Rev,etc${RESET}"


echo


# HTTP DIRECT

if [[ "$WEBSOCKET" == "ON" ]]; then

echo -e "${WHITE}🙍 HTTP-Direct  : ${GREEN}$IP:80@$USER:$PASS"

fi



# SSL SNI

if [[ "$SSL" == "ON" ]]; then

echo -e "${WHITE}🙍 SSL/TLS(SNI) : ${GREEN}${SERVER_DOMAIN}:443@$USER:$PASS"

fi



# SSH UDP

echo -e "${WHITE}🙍 SSH UDP      : ${GREEN}$IP:1-65535@$USER:$PASS"



echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"


echo -e "${GREEN}        ✅ USUARIO CREADO EXITOSAMENTE        ${RESET}"


echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

read -rp "¿Crear otro usuario? [S/N]: " RESP


case "$RESP" in

s|S|si|SI|Sí|sí)

continue

;;

*)

break

;;

esac


done
