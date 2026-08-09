#!/bin/bash    
#=========================================================    
# KevinTech Multi Script Premium    
# Módulo: Crear Usuario SSH    
# Versión: Premium    
# Autor: KevinTech    
#=========================================================    
    
#========================#    
#         COLORES        #    
#========================#    
GREEN='\e[1;92m'    
RED='\e[1;91m'    
YELLOW='\e[1;93m'    
BLUE='\e[1;94m'    
CYAN='\e[1;96m'    
MAGENTA='\e[1;95m'    
WHITE='\e[1;97m'    
GRAY='\e[1;90m'    
RESET='\e[0m'    
    
#========================#    
#      CONFIGURACIÓN     #    
#========================#    
    
BASE="/etc/kevintech"    
CONFIG="$BASE/config.conf"    
    
mkdir -p "$BASE"    
    
[[ -f "$CONFIG" ]] && source "$CONFIG"    
    
#========================#    
#       FUNCIONES        #    
#========================#    
    
line() {    
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$CYAN" "$RESET"    
}    
    
pause() {    
    echo    
    read -rp "$(echo -e "${YELLOW}Presione ENTER para continuar...${RESET}")"    
}    
    
msg_ok() {    
    echo -e "${GREEN}✔ $1${RESET}"    
}    
    
msg_error() {    
    echo -e "${RED}✘ $1${RESET}"    
}    
    
msg_info() {    
    echo -e "${CYAN}➜ $1${RESET}"    
}    
    
msg_warn() {    
    echo -e "${YELLOW}⚠ $1${RESET}"    
}    
    
titulo() {    
    
clear    
    
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"    
echo -e "${CYAN}║${MAGENTA}               ⚜ KevinTech Multi Script ⚜                ${CYAN}║${RESET}"    
echo -e "${CYAN}║${WHITE}                 CREAR USUARIO SSH PREMIUM               ${CYAN}║${RESET}"    
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"    
    
echo    
    
}    
    
#========================#    
#      VARIABLES         #    
#========================#    
    
SERVER_DOMAIN="${SERVER_DOMAIN:-}"    
OPENSSH="${OPENSSH:-OFF}"    
DROPBEAR="${DROPBEAR:-OFF}"    
WEBSOCKET="${WEBSOCKET:-OFF}"    
SSL="${SSL:-OFF}"    
SLOWDNS="${SLOWDNS:-OFF}"    
    
#========================#    
#    OBTENER IP PÚBLICA  #    
#========================#    
    
obtener_ip() {    
    
IP=$(curl -4 -s --max-time 5 ifconfig.me)    
    
[[ -z "$IP" ]] && \    
IP=$(hostname -I | awk '{print $1}')    
    
[[ -z "$IP" ]] && \    
IP="0.0.0.0"    
    
}    
    
#========================#    
#   INICIO DEL PROGRAMA  #    
#========================#    
    
while true; do    
    
titulo    
    
obtener_ip    
    
#========================#    
#   DATOS DEL USUARIO    #    
#========================#    
    
while true; do    
    read -rp "$(echo -e "${GREEN}👤 Usuario               : ${RESET}")" USER    
    
    USER=$(echo "$USER" | tr '[:upper:]' '[:lower:]')    
    
    if [[ -z "$USER" ]]; then    
        msg_error "Debe ingresar un nombre de usuario."    
        continue    
    fi    
    
    if ! [[ "$USER" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then    
        msg_error "Solo letras, números, _ y -. Mínimo 3 caracteres."    
        continue    
    fi    
    
    if id "$USER" &>/dev/null; then    
        msg_error "El usuario ya existe."    
        continue    
    fi    
    
    break    
done    
    
echo    
    
while true; do    
    read -rsp "$(echo -e "${GREEN}🔑 Contraseña            : ${RESET}")" PASS    
    echo    
    
    if [[ -z "$PASS" ]]; then    
        msg_error "Debe ingresar una contraseña."    
        continue    
    fi    
    
    if [[ ${#PASS} -lt 4 ]]; then    
        msg_warn "Se recomienda una contraseña de al menos 4 caracteres."    
    fi    
    
    break    
done    
    
echo    
    
while true; do    
    read -rp "$(echo -e "${GREEN}📅 Duración (días)       : ${RESET}")" DIAS    
    
    [[ -z "$DIAS" ]] && DIAS=30    
    
    if ! [[ "$DIAS" =~ ^[0-9]+$ ]]; then    
        msg_error "Debe ingresar un número."    
        continue    
    fi    
    
    if (( DIAS <= 0 )); then    
        msg_error "La duración debe ser mayor que 0."    
        continue    
    fi    
    
    break    
done    
    
echo    
    
while true; do    
    read -rp "$(echo -e "${GREEN}👥 Límite (0=Ilimitado) : ${RESET}")" LIMITE    
    
    [[ -z "$LIMITE" ]] && LIMITE=0    
    
    if ! [[ "$LIMITE" =~ ^[0-9]+$ ]]; then    
        msg_error "El límite debe ser un número."    
        continue    
    fi    
    
    break    
done    
    
if (( LIMITE == 0 )); then    
    LIMITE_MOSTRAR="♾ Ilimitado"    
else    
    LIMITE_MOSTRAR="$LIMITE Usuario(s)"    
fi    
    
#========================#    
#   FECHA DE EXPIRACIÓN  #    
#========================#    
    
FECHA=$(date -d "+${DIAS} days" +"%Y-%m-%d")    
FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")    
    
#========================#    
#    CREAR USUARIO SSH   #    
#========================#    
    
msg_info "Creando usuario SSH..."    
    
useradd \    
    -e "$FECHA" \    
    -M \    
    -s /usr/sbin/nologin \    
    "$USER"    
    
if [[ $? -ne 0 ]]; then    
    msg_error "No fue posible crear el usuario."    
    sleep 2    
    continue    
fi    
    
echo "${USER}:${PASS}" | chpasswd    
    
if [[ $? -ne 0 ]]; then    
    msg_error "No fue posible establecer la contraseña."    
    
    userdel -f "$USER" &>/dev/null    
    
    sleep 2    
    continue    
fi    
    
msg_ok "Usuario creado correctamente."    
    
HOST="${SERVER_DOMAIN:-$IP}"    
    
echo    
#========================#    
# DETECTAR SERVICIOS     #    
#========================#    
    
# OpenSSH    
SSH_PORTS=$(ss -ltnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]}' | sort -nu | paste -sd "," -)    
[[ -z "$SSH_PORTS" ]] && SSH_PORTS="22"    
    
# Dropbear    
DROPBEAR_PORTS=$(ss -ltnp 2>/dev/null | awk '/dropbear/ {split($4,a,":"); print a[length(a)]}' | sort -nu | paste -sd "," -)    
    
# HAProxy    
HAPROXY_PORTS=$(ss -ltnp 2>/dev/null | awk '/haproxy/ {split($4,a,":"); print a[length(a)]}' | sort -nu | paste -sd "," -)    
    
# BadVPN    
BADVPN_PORTS=$(ss -ltnp 2>/dev/null | awk '/badvpn/ {split($4,a,":"); print a[length(a)]}' | sort -nu | paste -sd "," -)    
    
#========================#    
# WEBSOCKET              #    
#========================#    
    
WS_PORT="80"    
WSS_PORT="443"    
WS_CDN_PORT="8080"    
    
if [[ -n "$HAPROXY_PORTS" ]]; then    
    
    [[ "$HAPROXY_PORTS" == *"80"* ]] && WS_PORT="80"    
    [[ "$HAPROXY_PORTS" == *"443"* ]] && WSS_PORT="443"    
    [[ "$HAPROXY_PORTS" == *"8080"* ]] && WS_CDN_PORT="8080"    
    
fi    
    
#========================#    
# DOMINIO               #    
#========================#    
    
HOST="${SERVER_DOMAIN:-$IP}"    
    
#========================#    
# SLOWDNS              #    
#========================#    
    
if [[ -f /etc/slowdns/domain.conf ]]; then    
    SLOWDNS_NS=$(cat /etc/slowdns/domain.conf)    
else    
    SLOWDNS_NS="N/D"    
fi    
    
if [[ -f /etc/slowdns/server.pub ]]; then    
    SLOWDNS_KEY=$(cat /etc/slowdns/server.pub)    
else    
    SLOWDNS_KEY="N/D"    
fi    
#========================#    
# ESTADO DE SERVICIOS    #    
#========================#    
    
OPENSSH_STATUS="OFF"    
DROPBEAR_STATUS="OFF"    
SSL_STATUS="OFF"    
WEBSOCKET_STATUS="OFF"    
SLOWDNS_STATUS="OFF"    
    
[[ -n "$SSH_PORTS" ]] && OPENSSH_STATUS="ON"    
[[ -n "$DROPBEAR_PORTS" ]] && DROPBEAR_STATUS="ON"    
[[ -n "$HAPROXY_PORTS" ]] && SSL_STATUS="ON"    
    
if [[ "$SSL_STATUS" == "ON" ]]; then    
    WEBSOCKET_STATUS="ON"    
fi    
    
if systemctl is-active --quiet slowdns 2>/dev/null; then    
    SLOWDNS_STATUS="ON"    
fi    
    
#========================#    
# PAYLOADS              #    
#========================#    
    
PAYLOAD_WS="GET / HTTP/1.1[crlf]Host: ${HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]"    
    
PAYLOAD_WSS="GET wss://${HOST}/ HTTP/1.1[crlf]Host: ${HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]"    
    
PAYLOAD_HTTP="[method] [host_port] HTTP/1.1[crlf]Host: ${HOST}[crlf]Upgrade: websocket[crlf]Connection: Keep-Alive[crlf][crlf]"    
    
#========================#    
# CONEXIONES LISTAS      #    
#========================#    
    
WS_HTTP="${HOST}:${WS_PORT}@${USER}:${PASS}"    
WS_SSL="${HOST}:${WSS_PORT}@${USER}:${PASS}"    
    
if [[ -n "$DROPBEAR_PORTS" ]]; then    
    DB_CONN="${HOST}:$(echo "$DROPBEAR_PORTS" | cut -d',' -f1)@${USER}:${PASS}"    
else    
    DB_CONN=""    
fi    
    
SSH_UDP="${IP}:1-65535@${USER}:${PASS}"    
#==================================================    
# PANEL PREMIUM    
#==================================================    
    
clear

# Detectar puerto de Hysteria
HYSTERIA_PORT=$(grep -oP '"listen":\s*":\K[0-9]+' /etc/hysteria/config.json 2>/dev/null)
[[ -z "$HYSTERIA_PORT" ]] && HYSTERIA_PORT="No instalado"

# Detectar OBFS de Hysteria
HYSTERIA_OBFS=$(grep -oP '"obfs":\s*"\K[^"]+' /etc/hysteria/config.json 2>/dev/null)
[[ -z "$HYSTERIA_OBFS" ]] && HYSTERIA_OBFS="No configurado"

# Detectar puerto ZiVPN
ZIVPN_PORT=$(ss -ltnu 2>/dev/null | awk '/20254|5667/ {split($5,a,":"); print a[length(a)]}' | head -n1)
[[ -z "$ZIVPN_PORT" ]] && ZIVPN_PORT="No instalado"

HOST="${SERVER_DOMAIN:-$IP}"

echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "${GREEN}    CUENTA CREADA EXITOSAMENTE${RESET}"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   Tipo          : NORMAL"
echo -e "   Usuario/ID    : ${GREEN}$USER${RESET}"
echo -e "   Contraseña    : ${GREEN}$PASS${RESET}"
echo -e "   Expira        : ${GREEN}$FECHA${RESET} (${DIAS} Días)"
echo -e "   Límite IP     : ${GREEN}$LIMITE_MOSTRAR${RESET}"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   Host/IP       : ${GREEN}$HOST${RESET}"
echo -e "   Puertos SSH   : ${GREEN}$SSH_PORTS${RESET}"
echo -e "   Dropbear      : ${GREEN}${DROPBEAR_PORTS:-No instalado}${RESET}"
echo -e "   Ssl tunel     : ${GREEN}${HAPROXY_PORTS:-No instalado}${RESET}"
echo -e "   OpenVPN       : ${GREEN}1194, 2200, 443${RESET}"
echo -e "   BadVPN        : ${GREEN}${BADVPN_PORTS:-No instalado}${RESET}"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   HTTP CUSTOM   :"
echo -e "   ${HOST}:443@${USER}:${PASS}"
echo -e "   ${HOST}:80@${USER}:${PASS}"
echo -e "   ${HOST}:8080@${USER}:${PASS}"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   UDP CUSTOM    :"
echo -e "   ${HOST}:1-65535@${USER}:${PASS}"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   HYSTERIA V1 (Port:${HYSTERIA_PORT}):"
echo -e "   Servidor  : ${HOST}:${HYSTERIA_PORT}"
echo -e "   Obfs      : ${HYSTERIA_OBFS}"
echo -e "   Contraseña: ${USER}:${PASS}"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   ZIVPN (UDP):"
echo -e "   Servidor  : ${HOST}:${ZIVPN_PORT}"
echo -e "   Contraseña: ${PASS}"
echo -e "   Puerto    : 20000-29999"
echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "   SLOW DNS PORT 5300:"

if [[ "$SLOWDNS_STATUS" == "ON" ]]; then
    echo -e "   NS  : ${SLOWDNS_NS}"
    echo -e "   KEY : ${SLOWDNS_KEY}"
else
    echo -e "   No instalado"
    echo -e "   Ns Subdominio:"
    echo -e "   Sin NS"
fi

echo -e "${GREEN}────────────────────────────────────────────────${RESET}"
echo -e "       >> Presione enter para continuar <<${RESET}"
read   
    
exec bash "$BASE/usuarios/menu.sh"    
done    
