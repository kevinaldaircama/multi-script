#!/bin/bash            
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#            
#            KevinTech Multi Script Premium            
#                  Xray / V2Ray Manager            
#            
# Compatible:            
#   Ubuntu 18.04            
#   Ubuntu 20.04            
#   Ubuntu 22.04            
#   Ubuntu 24.04            
#            
# Versión : 3.0 Premium            
# Autor   : KevinTech            
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#            
            
############################            
# COLORES            
############################            
            
RESET="\e[0m"            
            
BLACK="\e[1;30m"            
GRAY="\e[1;90m"            
            
RED="\e[1;91m"            
GREEN="\e[1;92m"            
YELLOW="\e[1;93m"            
BLUE="\e[1;94m"            
MAGENTA="\e[1;95m"            
CYAN="\e[1;96m"            
WHITE="\e[1;97m"            
            
############################            
# VARIABLES            
############################            
            
BASE="/etc/kevintech"            
            
CONFIG="$BASE/config.conf"            
            
XRAY_DIR="/usr/local/etc/xray"            
XRAY_CONFIG="$XRAY_DIR/config.json"            
            
DATA_DIR="$BASE/v2ray"            
            
USERS_DB="$DATA_DIR/users.db"            
            
LOG_DIR="$BASE/logs"            
            
VERSION="3.0 Premium"            
            
############################            
# COMPROBAR ROOT            
############################            
            
if [[ $EUID -ne 0 ]]            
then            
            
clear            
            
echo            
            
echo -e "${RED}╔══════════════════════════════════════╗${RESET}"            
echo -e "${RED}║      ESTE SCRIPT NECESITA ROOT      ║${RESET}"            
echo -e "${RED}╚══════════════════════════════════════╝${RESET}"            
            
echo            
            
exit 1            
            
fi            
            
############################            
# VALIDAR UBUNTU            
############################            
            
if [[ -f /etc/os-release ]]            
then            
            
source /etc/os-release            
            
case "$VERSION_ID" in            
            
18.04|20.04|22.04|24.04)            
            
;;            
            
*)            
            
clear            
            
echo            
            
echo -e "${RED}Ubuntu no compatible.${RESET}"            
            
echo            
            
echo "Versión detectada: $VERSION_ID"            
            
echo            
            
exit 1            
            
;;            
            
esac            
            
fi            
            
############################            
# CREAR DIRECTORIOS            
############################            
            
mkdir -p "$BASE"            
            
mkdir -p "$DATA_DIR"            
            
mkdir -p "$LOG_DIR"            
            
mkdir -p "$XRAY_DIR"            
            
touch "$USERS_DB"            
            
############################            
# CARGAR CONFIG            
############################            
            
if [[ -f "$CONFIG" ]]            
then            
            
source "$CONFIG"            
            
fi            
            
############################            
# FUNCIONES VISUALES            
############################            
            
line(){            
            
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"            
            
}            
            
title(){            
            
clear            
            
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"            
echo -e "${CYAN}║${MAGENTA}              ⚜️ KevinTech Multi Script ⚜️              ${CYAN}║${RESET}"            
echo -e "${CYAN}║${WHITE}                   Xray / V2Ray Manager                  ${CYAN}║${RESET}"            
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"            
            
echo            
            
}            
            
subtitle(){            
            
echo            
            
echo -e "${YELLOW}$1${RESET}"            
            
line            
            
}            
            
ok(){            
            
echo            
            
echo -e "${GREEN}✔ $1${RESET}"            
            
}            
            
error(){            
            
echo            
            
echo -e "${RED}✘ $1${RESET}"            
            
}            
            
info(){            
            
echo            
            
echo -e "${CYAN}➜ $1${RESET}"            
            
}            
            
pause(){            
            
echo            
            
read -n1 -rsp "Presiona cualquier tecla para continuar..."            
            
}            
            
############################            
# OBTENER DATOS VPS            
############################            
            
get_server_info(){            
            
IP=$(curl -4 -s ifconfig.me)            
            
[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')            
            
DOMAIN="${SERVER_DOMAIN:-No Configurado}"            
            
HOSTNAME=$(hostname)            
            
KERNEL=$(uname -r)            
            
RAM=$(free -h | awk '/Mem:/ {print $2}')            
            
CPU=$(nproc)            
            
UPTIME=$(uptime -p | sed 's/up //')            
            
}            
            
############################            
# PANEL PRINCIPAL            
############################            
            
header(){            
            
get_server_info            
            
title            
            
echo -e "${WHITE} Hostname : ${GREEN}$HOSTNAME"            
echo -e "${WHITE} Dominio  : ${GREEN}$DOMAIN"            
echo -e "${WHITE} IP VPS   : ${GREEN}$IP"            
echo -e "${WHITE} Kernel   : ${GREEN}$KERNEL"            
echo -e "${WHITE} CPU      : ${GREEN}$CPU Core(s)"            
echo -e "${WHITE} RAM      : ${GREEN}$RAM"            
echo -e "${WHITE} Uptime   : ${GREEN}$UPTIME"            
            
line            
            
}            
############################            
# VALIDACIONES            
############################            
            
check_command(){            
            
command -v "$1" >/dev/null 2>&1            
            
}            
            
check_service(){            
            
systemctl list-unit-files | grep -qw "$1.service"            
            
}            
            
service_status(){            
            
if systemctl is-active --quiet "$1"            
then            
    echo -e "${GREEN}🟢 ACTIVO${RESET}"            
else            
    echo -e "${RED}🔴 DETENIDO${RESET}"            
fi            
            
}            
            
############################            
# DETECTAR PUERTOS            
############################            
            
detect_port(){            
            
local SERVICE="$1"            
            
ss -tlnp 2>/dev/null |            
grep "$SERVICE" |            
awk '{print $4}' |            
awk -F: '{print $NF}' |            
head -1            
            
}            
            
############################            
# GUARDAR CONFIGURACIÓN            
############################            
            
save_config(){            
            
local KEY="$1"            
local VALUE="$2"            
            
mkdir -p "$BASE"            
            
touch "$CONFIG"            
            
if grep -q "^${KEY}=" "$CONFIG"            
then            
            
sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$CONFIG"            
            
else            
            
echo "${KEY}=${VALUE}" >> "$CONFIG"            
            
fi            
            
source "$CONFIG"            
            
}            
            
############################            
# CONFIRMACIÓN            
############################            
            
confirm(){            
            
read -rp "$(echo -e "${YELLOW}$1 [S/N]: ${RESET}")" RESP            
            
case "$RESP" in            
            
s|S|si|SI|Sí|sí|y|Y)            
            
return 0            
            
;;            
            
*)            
            
return 1            
            
;;            
            
esac            
            
}            
            
############################            
# BARRA DE PROGRESO            
############################            
            
progress(){            
            
local TEXT="$1"            
            
echo            
            
printf "${CYAN}%s${RESET}" "$TEXT"            
            
for i in {1..25}            
do            
printf "${GREEN}█${RESET}"            
sleep 0.03            
done            
            
echo            
            
}            
            
############################            
# COMPROBAR INTERNET            
############################            
            
check_internet(){            
            
curl -Is https://google.com --connect-timeout 5 >/dev/null            
            
if [[ $? -ne 0 ]]            
then            
            
error "No hay conexión a Internet."            
            
return 1            
            
fi            
            
return 0            
            
}            
            
############################            
# OBTENER FECHA            
############################            
            
today(){            
            
date +"%d/%m/%Y"            
            
}            
            
############################            
# GENERAR UUID            
############################            
            
generate_uuid(){            
            
uuidgen            
            
}            
            
############################            
# CONTAR USUARIOS            
############################            
            
total_users(){            
            
if [[ -f "$USERS_DB" ]]            
then            
grep -c "|" "$USERS_DB"            
else            
echo 0            
fi            
            
}            
            
############################            
# EXISTE USUARIO            
############################            
            
user_exists(){            
            
grep -q "^$1|" "$USERS_DB"            
            
}            
            
############################            
# OBTENER IP PÚBLICA            
############################            
            
public_ip(){            
            
curl -4 -s ifconfig.me            
            
}            
            
############################            
# LIMPIAR LOGS            
############################            
            
clean_logs(){            
            
rm -f "$LOG_DIR"/*.log 2>/dev/null            
            
}            
            
############################            
# REINICIAR SERVICIO            
############################            
            
restart_service(){            
            
local SERVICE="$1"            
            
systemctl restart "$SERVICE"            
            
sleep 2            
            
if systemctl is-active --quiet "$SERVICE"            
then            
            
ok "$SERVICE reiniciado correctamente."            
            
else            
            
error "No fue posible reiniciar $SERVICE."            
            
fi            
            
}            
            
############################            
# INSTALAR PAQUETES            
############################            
            
install_pkg(){            
            
for PKG in "$@"            
do            
            
if ! dpkg -s "$PKG" >/dev/null 2>&1            
then            
            
info "Instalando $PKG..."            
            
apt-get install -y "$PKG"            
            
fi            
            
done            
            
}            
            
############################            
# INFORMACIÓN DEL SISTEMA            
############################            
            
system_info(){            
            
header            
            
echo -e "${WHITE} Sistema      : ${GREEN}$PRETTY_NAME"            
echo -e "${WHITE} Arquitectura : ${GREEN}$(uname -m)"            
echo -e "${WHITE} Xray         : $(service_status xray)"            
echo -e "${WHITE} Nginx        : $(service_status nginx)"            
echo -e "${WHITE} Usuarios     : ${GREEN}$(total_users)"            
            
line            
            
}            
############################            
# INSTALAR DEPENDENCIAS            
############################            
            
install_dependencies(){            
            
header            
            
subtitle "INSTALACIÓN DE DEPENDENCIAS"            
            
check_internet || return            
            
PACKAGES=(            
curl            
wget            
jq            
uuid-runtime            
nginx            
openssl            
certbot            
python3            
python3-pip            
ca-certificates            
tar            
unzip            
cron            
socat            
)            
            
for PKG in "${PACKAGES[@]}"            
do            
            
if dpkg -s "$PKG" >/dev/null 2>&1            
then            
            
echo -e "${GREEN}✔${RESET} $PKG"            
            
else            
            
echo -e "${YELLOW}➜ Instalando $PKG...${RESET}"            
            
apt-get install -y "$PKG"            
            
fi            
            
done            
            
echo            
            
ok "Dependencias instaladas correctamente."            
            
pause            
            
}            
            
############################            
# INSTALAR XRAY CORE            
############################            
            
install_xray_core(){            
            
header            
            
subtitle "INSTALACIÓN DE XRAY CORE"            
            
check_internet || return            
            
if check_command xray            
then            
            
ok "Xray ya se encuentra instalado."            
            
pause            
            
return            
            
fi            
            
progress "Descargando Xray "            
            
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install            
            
if ! check_command xray            
then            
            
error "No fue posible instalar Xray."            
            
pause            
            
return            
            
fi            
            
mkdir -p "$XRAY_DIR"            
            
mkdir -p /var/log/xray            
            
touch /var/log/xray/access.log            
touch /var/log/xray/error.log            
            
chmod 755 "$XRAY_DIR"            
chmod 755 /var/log/xray            
            
systemctl enable xray            
            
cat >/etc/systemd/system/xray.service.d/restart.conf <<EOF            
[Service]            
Restart=always            
RestartSec=5            
EOF            
            
systemctl daemon-reload            
            
systemctl restart xray            
            
sleep 2            
            
if systemctl is-active --quiet xray            
then            
            
save_config V2RAY ON            
            
ok "Xray instalado correctamente."            
            
else            
            
error "Xray no pudo iniciar."            
            
journalctl -u xray -n 15 --no-pager            
            
fi            
            
pause            
            
}            
            
############################            
# DESINSTALAR XRAY            
############################            
            
remove_xray(){            
            
header            
            
subtitle "DESINSTALAR XRAY"            
            
confirm "¿Desea eliminar completamente Xray?" || return            
            
systemctl stop xray 2>/dev/null            
            
systemctl disable xray 2>/dev/null            
            
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove            
            
rm -rf "$XRAY_DIR"            
            
rm -rf /var/log/xray            
            
rm -rf "$DATA_DIR"            
            
save_config V2RAY OFF            
            
ok "Xray eliminado correctamente."            
            
pause            
            
}            
            
############################            
# REINICIAR XRAY            
############################            
            
restart_xray(){            
            
header            
            
subtitle "REINICIAR XRAY"            
            
restart_service xray            
            
pause            
            
}            
            
############################            
# ESTADO XRAY            
############################            
            
status_xray(){            
            
header            
            
subtitle "ESTADO DEL SERVICIO"            
            
echo            
            
systemctl --no-pager --full status xray            
            
echo            
            
line            
            
echo -e "${WHITE}Estado          : $(service_status xray)"            
echo -e "${WHITE}Puerto Interno  : ${GREEN}10000"            
echo -e "${WHITE}WebSocket Path  : ${GREEN}/vmess"            
echo -e "${WHITE}Usuarios VMess  : ${GREEN}$(total_users)"            
            
line            
            
pause            
            
}            
############################            
# CREAR CONFIGURACIÓN XRAY            
############################            
            
create_xray_config(){            
            
header            
            
subtitle "CONFIGURANDO XRAY"            
            
mkdir -p "$XRAY_DIR"            
            
cat > "$XRAY_CONFIG" <<EOF            
{            
  "log": {            
    "access": "/var/log/xray/access.log",            
    "error": "/var/log/xray/error.log",            
    "loglevel": "warning"            
  },            
            
  "inbounds":[            
    {            
      "listen":"127.0.0.1",            
      "port":10000,            
            
      "protocol":"vmess",            
            
      "settings":{            
        "clients":[]            
      },            
            
      "streamSettings":{            
        "network":"ws",            
        "security":"none",            
            
        "wsSettings":{            
          "path":"/vmess"            
        }            
      }            
    }            
  ],            
            
  "outbounds":[            
    {            
      "protocol":"freedom"            
    },            
    {            
      "protocol":"blackhole",            
      "tag":"blocked"            
    }            
  ]            
}            
EOF            
            
chmod 644 "$XRAY_CONFIG"            
            
systemctl restart xray            
            
if systemctl is-active --quiet xray            
then            
            
ok "Configuración Xray creada."            
            
else            
            
error "Xray no pudo iniciar."            
            
journalctl -u xray -n 20 --no-pager            
            
fi            
            
pause            
            
}            
            
############################            
# CONFIGURAR NGINX            
############################            
            
configure_nginx(){            
            
header            
            
subtitle "CONFIGURANDO NGINX"            
            
if [[ -z "$SERVER_DOMAIN" ]]            
then            
            
error "No existe un dominio configurado."            
            
pause            
            
return            
            
fi            
            
cat >/etc/nginx/conf.d/vmess.conf <<EOF            
server {            
            
    listen 80;            
            
    server_name $SERVER_DOMAIN;            
            
    location /vmess {            
            
        proxy_redirect off;            
            
        proxy_pass http://127.0.0.1:10000;            
            
        proxy_http_version 1.1;            
            
        proxy_set_header Upgrade \$http_upgrade;            
            
        proxy_set_header Connection "upgrade";            
            
        proxy_set_header Host \$host;            
            
        proxy_set_header X-Real-IP \$remote_addr;            
            
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;            
            
    }            
            
}            
EOF            
            
if nginx -t            
then            
            
systemctl restart nginx            
            
ok "Nginx configurado correctamente."            
            
else            
            
error "La configuración de Nginx contiene errores."            
            
fi            
            
pause            
            
}            
            
############################            
# INSTALAR SSL            
############################            
            
install_ssl(){            
            
header            
            
subtitle "GENERAR CERTIFICADO SSL"            
            
if [[ -z "$SERVER_DOMAIN" ]]            
then            
            
error "No hay dominio configurado."            
            
pause            
            
return            
            
fi            
            
IP=$(public_ip)            
            
DNS=$(dig +short "$SERVER_DOMAIN" | head -1)            
            
if [[ "$IP" != "$DNS" ]]            
then            
            
error "El dominio aún no apunta a esta VPS."            
            
echo            
            
echo "Dominio : $SERVER_DOMAIN"            
echo "DNS     : $DNS"            
echo "VPS     : $IP"            
            
pause            
            
return            
            
fi            
            
progress "Generando certificado "            
            
certbot certonly \            
--nginx \            
-d "$SERVER_DOMAIN" \            
--agree-tos \            
--register-unsafely-without-email \            
--non-interactive            
            
if [[ $? -ne 0 ]]            
then            
            
error "No fue posible generar el certificado."            
            
pause            
            
return            
            
fi            
            
ok "Certificado SSL instalado."            
            
pause            
            
}            
            
############################            
# ACTIVAR SSL EN NGINX            
############################            
            
enable_ssl(){            
            
header            
            
subtitle "ACTIVANDO SSL"            
            
cat >/etc/nginx/conf.d/vmess.conf <<EOF            
server {            
            
    listen 80;            
            
    server_name $SERVER_DOMAIN;            
            
    return 301 https://\$host\$request_uri;            
            
}            
            
server {            
            
    listen 444 ssl http2;            
            
    server_name $SERVER_DOMAIN;            
            
    ssl_certificate /etc/letsencrypt/live/$SERVER_DOMAIN/fullchain.pem;            
            
    ssl_certificate_key /etc/letsencrypt/live/$SERVER_DOMAIN/privkey.pem;            
            
    location /vmess {            
            
        proxy_redirect off;            
            
        proxy_pass http://127.0.0.1:10000;            
            
        proxy_http_version 1.1;            
            
        proxy_set_header Upgrade \$http_upgrade;            
            
        proxy_set_header Connection "upgrade";            
            
        proxy_set_header Host \$host;            
            
        proxy_set_header X-Real-IP \$remote_addr;            
            
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;            
            
    }            
            
}            
EOF            
            
if nginx -t            
then            
            
systemctl restart nginx            
            
save_config V2RAY ON            
            
ok "SSL activado correctamente."            
            
else            
            
error "No fue posible activar SSL."            
            
fi            
            
pause            
            
}            
            
############################            
# INSTALACIÓN AUTOMÁTICA            
############################            
            
setup_xray(){            
            
install_dependencies            
            
install_xray_core            
            
create_xray_config            
            
configure_nginx            
            
install_ssl            
            
enable_ssl            
            
}            
############################            
# CREAR USUARIO VMESS            
############################            
            
create_vmess_user(){            
            
header            
            
subtitle "CREAR NUEVA CUENTA VMESS"            
            
echo            
            
read -rp "$(echo -e "${GREEN}👤 Usuario             : ${RESET}")" USER            
            
[[ -z "$USER" ]] && {            
            
error "Debe ingresar un usuario."            
            
pause            
            
return            
            
}            
            
if user_exists "$USER"            
then            
            
error "El usuario ya existe."            
            
pause            
            
return            
            
fi            
            
echo            
            
read -rp "$(echo -e "${GREEN}📅 Duración (días)     : ${RESET}")" DAYS            
            
[[ -z "$DAYS" ]] && DAYS=30            
            
echo            
            
read -rp "$(echo -e "${GREEN}👥 Límite (0=Ilimitado): ${RESET}")" LIMIT            
            
[[ -z "$LIMIT" ]] && LIMIT=0            
            
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]            
then            
            
error "Límite inválido."            
            
pause            
            
return            
            
fi            
            
UUID=$(generate_uuid)            
            
EXP=$(date -d "+$DAYS days" +"%Y-%m-%d")            
            
if [[ "$LIMIT" == "0" ]]            
then            
            
LIMIT_SHOW="♾ Ilimitado"            
            
else            
            
LIMIT_SHOW="$LIMIT"            
            
fi            
            
############################            
# GUARDAR USUARIO            
############################            
            
echo "$USER|$UUID|$EXP|$LIMIT" >> "$USERS_DB"            
            
############################            
# AGREGAR A XRAY            
############################            
            
python3 <<PYTHON            
            
import json            
            
config="$XRAY_CONFIG"            
            
with open(config,"r") as f:            
    data=json.load(f)            
            
clients=data["inbounds"][0]["settings"]["clients"]            
            
clients.append({            
"id":"$UUID",            
"email":"$USER",            
"level":0            
})            
            
with open(config,"w") as f:            
    json.dump(data,f,indent=2)            
            
PYTHON            
            
systemctl restart xray            
            
############################            
# VERIFICAR            
############################            
            
if ! systemctl is-active --quiet xray            
then            
            
error "Xray no pudo iniciar."            
            
pause            
            
return            
            
fi            
            
header            
            
subtitle "CUENTA CREADA"            
            
IP=$(public_ip)            
            
echo            
            
echo -e "${CYAN}┌───────────────────────────────────────────────────────────┐${RESET}"            
printf "${WHITE}│ Usuario      : ${GREEN}%-38s${WHITE}│\n" "$USER"            
printf "${WHITE}│ UUID         : ${GREEN}%-38s${WHITE}│\n" "$UUID"            
printf "${WHITE}│ Expira       : ${GREEN}%-38s${WHITE}│\n" "$EXP"            
printf "${WHITE}│ Límite       : ${GREEN}%-38s${WHITE}│\n" "$LIMIT_SHOW"            
printf "${WHITE}│ Dominio      : ${GREEN}%-38s${WHITE}│\n" "$SERVER_DOMAIN"            
printf "${WHITE}│ Puerto TLS   : ${GREEN}%-38s${WHITE}│\n" "444"            
printf "${WHITE}│ WebSocket    : ${GREEN}%-38s${WHITE}│\n" "/vmess"            
echo -e "${CYAN}└───────────────────────────────────────────────────────────┘${RESET}"            
            
echo            
            
ok "Cuenta VMess creada correctamente."            
            
pause            
            
}            
############################            
# LISTAR USUARIOS VMESS            
############################            
            
list_vmess_users(){            
            
header            
            
subtitle "LISTA DE CUENTAS VMESS"            
            
if [[ ! -s "$USERS_DB" ]]            
then            
            
error "No existen usuarios registrados."            
            
pause            
            
return            
            
fi            
            
printf "${CYAN}┌────┬────────────────┬──────────────┬──────────────┬──────────────┐${RESET}\n"            
printf "${WHITE}│ Nº │ Usuario        │ Expira       │ Límite       │ Estado       │${RESET}\n"            
printf "${CYAN}├────┼────────────────┼──────────────┼──────────────┼──────────────┤${RESET}\n"            
            
NUM=1            
            
TODAY=$(date +%s)            
            
while IFS="|" read -r USER UUID EXP LIMIT            
do            
            
EXP_TIME=$(date -d "$EXP" +%s)            
            
if [[ "$LIMIT" == "0" ]]            
then            
    LIMIT_SHOW="♾"            
else            
    LIMIT_SHOW="$LIMIT"            
fi            
            
if (( EXP_TIME >= TODAY ))            
then            
    STATUS="${GREEN}🟢 Activo${RESET}"            
else            
    STATUS="${RED}🔴 Expirado${RESET}"            
fi            
            
printf "│ %-2s │ %-14s │ %-12s │ %-12s │ %-20b │\n" \            
"$NUM" \            
"$USER" \            
"$EXP" \            
"$LIMIT_SHOW" \            
"$STATUS"            
            
NUM=$((NUM+1))            
            
done < "$USERS_DB"            
            
printf "${CYAN}└────┴────────────────┴──────────────┴──────────────┴──────────────┘${RESET}\n"            
            
echo            
            
echo -e "${WHITE}Total de usuarios : ${GREEN}$((NUM-1))${RESET}"            
            
pause            
            
}            
            
############################            
# BUSCAR USUARIO            
############################            
            
search_vmess_user(){            
            
header            
            
subtitle "BUSCAR USUARIO"            
            
echo            
            
read -rp "$(echo -e "${GREEN}Usuario: ${RESET}")" USER            
            
DATA=$(grep "^$USER|" "$USERS_DB")            
            
if [[ -z "$DATA" ]]            
then            
            
error "Usuario no encontrado."            
            
pause            
            
return            
            
fi            
            
UUID=$(echo "$DATA" | cut -d "|" -f2)            
EXP=$(echo "$DATA" | cut -d "|" -f3)            
LIMIT=$(echo "$DATA" | cut -d "|" -f4)            
            
[[ "$LIMIT" == "0" ]] && LIMIT="♾ Ilimitado"            
            
echo            
            
echo -e "${CYAN}┌───────────────────────────────────────────────────────────┐${RESET}"            
printf "${WHITE}│ Usuario      : ${GREEN}%-38s${WHITE}│\n" "$USER"            
printf "${WHITE}│ UUID         : ${GREEN}%-38s${WHITE}│\n" "$UUID"            
printf "${WHITE}│ Expira       : ${GREEN}%-38s${WHITE}│\n" "$EXP"            
printf "${WHITE}│ Límite       : ${GREEN}%-38s${WHITE}│\n" "$LIMIT"            
echo -e "${CYAN}└───────────────────────────────────────────────────────────┘${RESET}"            
            
pause            
            
}            
            
############################            
# ELIMINAR USUARIO            
############################            
            
delete_vmess_user(){            
            
header            
            
subtitle "ELIMINAR USUARIO"            
            
echo            
            
read -rp "$(echo -e "${GREEN}Usuario: ${RESET}")" USER            
            
if ! user_exists "$USER"            
then            
            
error "El usuario no existe."            
            
pause            
            
return            
            
fi            
            
UUID=$(grep "^$USER|" "$USERS_DB" | cut -d "|" -f2)            
            
confirm "¿Eliminar la cuenta de $USER?" || return            
            
grep -v "^$USER|" "$USERS_DB" > "$USERS_DB.tmp"            
            
mv "$USERS_DB.tmp" "$USERS_DB"            
            
python3 <<PYTHON            
import json            
            
cfg="$XRAY_CONFIG"            
            
with open(cfg) as f:            
    data=json.load(f)            
            
clients=data["inbounds"][0]["settings"]["clients"]            
            
data["inbounds"][0]["settings"]["clients"]=[            
c for c in clients            
if c.get("id") != "$UUID"            
]            
            
with open(cfg,"w") as f:            
    json.dump(data,f,indent=2)            
PYTHON            
            
systemctl restart xray            
            
ok "Usuario eliminado correctamente."            
            
pause            
            
}            
############################            
# GENERAR LINK VMESS            
############################            
            
generate_vmess_link(){            
            
header            
            
subtitle "GENERAR LINK VMESS"            
            
echo            
            
read -rp "$(echo -e "${GREEN}👤 Usuario: ${RESET}")" USER            
            
DATA=$(grep "^$USER|" "$USERS_DB")            
            
if [[ -z "$DATA" ]]            
then            
            
error "El usuario no existe."            
            
pause            
            
return            
            
fi            
            
UUID=$(echo "$DATA" | cut -d "|" -f2)            
EXP=$(echo "$DATA" | cut -d "|" -f3)            
LIMIT=$(echo "$DATA" | cut -d "|" -f4)            
            
[[ "$LIMIT" == "0" ]] && LIMIT_SHOW="♾ Ilimitado" || LIMIT_SHOW="$LIMIT"            
            
IP=$(public_ip)            
            
VMESS_JSON=$(cat <<EOF            
{            
  "v":"2",            
  "ps":"$USER",            
  "add":"$SERVER_DOMAIN",            
  "port":"444",            
  "id":"$UUID",            
  "aid":"0",            
  "scy":"auto",            
  "net":"ws",            
  "type":"none",            
  "host":"$SERVER_DOMAIN",            
  "path":"/vmess",            
  "tls":"tls",            
  "sni":"$SERVER_DOMAIN"            
}            
EOF            
)            
            
LINK=$(echo -n "$VMESS_JSON" | base64 -w0)            
            
header            
            
subtitle "DATOS DE LA CUENTA VMESS"            
            
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"            
printf "${WHITE}│ Usuario      : ${GREEN}%-38s${WHITE}│\n" "$USER"            
printf "${WHITE}│ UUID         : ${GREEN}%-38s${WHITE}│\n" "$UUID"            
printf "${WHITE}│ Expira       : ${GREEN}%-38s${WHITE}│\n" "$EXP"            
printf "${WHITE}│ Límite       : ${GREEN}%-38s${WHITE}│\n" "$LIMIT_SHOW"            
printf "${WHITE}│ Dominio      : ${GREEN}%-38s${WHITE}│\n" "$SERVER_DOMAIN"            
printf "${WHITE}│ Host/IP      : ${GREEN}%-38s${WHITE}│\n" "$IP"            
printf "${WHITE}│ Puerto TLS   : ${GREEN}%-38s${WHITE}│\n" "444"            
printf "${WHITE}│ WebSocket    : ${GREEN}%-38s${WHITE}│\n" "/vmess"            
printf "${WHITE}│ TLS          : ${GREEN}%-38s${WHITE}│\n" "Activado"            
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"            
            
echo            
            
subtitle "CONFIGURACIÓN MANUAL"            
            
echo -e "${WHITE}🌐 Servidor  : ${GREEN}$SERVER_DOMAIN"            
echo -e "${WHITE}📡 Puerto    : ${GREEN}444"            
echo -e "${WHITE}📂 Path      : ${GREEN}/vmess"            
echo -e "${WHITE}🔒 TLS       : ${GREEN}Sí"            
echo -e "${WHITE}🛰 SNI       : ${GREEN}$SERVER_DOMAIN"            
            
echo            
            
subtitle "ENLACE VMESS"            
            
echo -e "${GREEN}vmess://$LINK${RESET}"            
            
echo            
            
subtitle "APLICACIONES COMPATIBLES"            
            
echo -e "${WHITE}✔ v2rayNG"            
echo -e "${WHITE}✔ NekoBox"            
echo -e "${WHITE}✔ Hiddify"            
echo -e "${WHITE}✔ HTTP Injector"            
echo -e "${WHITE}✔ HTTP Custom"            
echo -e "${WHITE}✔ NapsternetV"            
echo -e "${WHITE}✔ V2Box"            
echo -e "${WHITE}✔ Clash Meta"            
            
echo            
            
ok "Link generado correctamente."            
            
pause            
            
}            
############################            
# PANEL PRINCIPAL XRAY            
############################            
            
v2ray_manager(){            
            
while true            
do            
            
header            
            
XRAY_STATUS=$(service_status xray)            
NGINX_STATUS=$(service_status nginx)            
            
TOTAL=$(total_users)            
            
ACTIVE=0            
EXPIRED=0            
            
if [[ -s "$USERS_DB" ]]            
then            
            
NOW=$(date +%s)            
            
while IFS="|" read -r USER UUID EXP LIMIT            
do            
            
EXP_TIME=$(date -d "$EXP" +%s)            
            
if (( EXP_TIME >= NOW ))            
then            
            
ACTIVE=$((ACTIVE+1))            
else            
            
EXPIRED=$((EXPIRED+1))            
fi            
            
done < "$USERS_DB"            
            
fi            
            
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"            
printf "${WHITE}│ Estado Xray    : %-38b │\n" "$XRAY_STATUS"            
printf "${WHITE}│ Estado Nginx   : %-38b │\n" "$NGINX_STATUS"            
printf "${WHITE}│ Usuarios       : ${GREEN}%-38s${WHITE}│\n" "$TOTAL"            
printf "${WHITE}│ Activos        : ${GREEN}%-38s${WHITE}│\n" "$ACTIVE"            
printf "${WHITE}│ Expirados      : ${RED}%-38s${WHITE}│\n" "$EXPIRED"            
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"            
            
echo            
            
echo -e "${YELLOW}================== GESTIÓN DEL SERVIDOR ==================${RESET}"            
            
echo -e "${WHITE} ${GREEN}[01]${WHITE} Instalar Xray Completo"            
echo -e "${WHITE} ${GREEN}[02]${WHITE} Estado de Xray"            
echo -e "${WHITE} ${GREEN}[03]${WHITE} Reiniciar Xray"            
echo -e "${WHITE} ${GREEN}[04]${WHITE} Desinstalar Xray"            
            
echo            
echo -e "${YELLOW}================== GESTIÓN DE USUARIOS ===================${RESET}"            
            
echo -e "${WHITE} ${GREEN}[05]${WHITE} Crear Usuario VMess"            
echo -e "${WHITE} ${GREEN}[06]${WHITE} Listar Usuarios"            
echo -e "${WHITE} ${GREEN}[07]${WHITE} Buscar Usuario"            
echo -e "${WHITE} ${GREEN}[08]${WHITE} Generar Link VMess"            
echo -e "${WHITE} ${GREEN}[09]${WHITE} Eliminar Usuario"            
echo            
echo -e "${WHITE} ${RED}[00] Salir${RESET}"            
            
echo            
            
read -rp "$(echo -e "${GREEN}Seleccione una opción ➜ ${RESET}")" OP            
            
case "$OP" in            
            
1|01)            
            
setup_xray            
            
;;            
            
2|02)            
            
status_xray            
            
;;            
            
3|03)            
            
restart_xray            
            
;;            
            
4|04)            
            
remove_xray            
            
;;            
            
5|05)            
            
create_vmess_user            
            
;;            
            
6|06)            
            
list_vmess_users            
            
;;            
            
7|07)            
            
search_vmess_user            
            
;;            
            
8|08)            
            
generate_vmess_link            
            
;;            
            
9|09)            
            
delete_vmess_user            
            
;;            
            
0|00)            
            
clear            
            
echo            
            
echo -e "${GREEN}Gracias por utilizar KevinTech Multi Script Premium${RESET}"            
            
echo            
            
break            
            
;;            
            
*)            
            
error "Opción inválida"            
            
sleep 2            
            
;;            
            
esac            
            
done            
            
}            
            
############################            
# INICIO            
############################            
            
v2ray_manager
