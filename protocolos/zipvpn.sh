#!/bin/bash          
          
# =====================================================          
#        KevinTech Multi Script          
#        ZiVPN Manager 1.4.9          
#        UDP VPN Installer          
# =====================================================          
          
          
# ==========================          
# COLORES          
# ==========================          
          
RED="\e[31m"          
GREEN="\e[32m"          
YELLOW="\e[33m"          
BLUE="\e[34m"          
MAGENTA="\e[35m"          
CYAN="\e[36m"          
WHITE="\e[97m"          
          
BOLD="\e[1m"          
RESET="\e[0m"          
          
          
          
# ==========================          
# RUTAS          
# ==========================          
          
ZIVPN_DIR="/etc/zivpn"          
          
BIN="/usr/local/bin/zivpn"          
          
CONFIG="$ZIVPN_DIR/config.json"          
          
SERVICE="/etc/systemd/system/zivpn.service"          
          
PORT_FILE="$ZIVPN_DIR/port"          
          
          
          
# ==========================          
# ICONOS          
# ==========================          
          
OK="✔"          
FAIL="✘"          
INFO="➜"          
WARN="!"          
          
          
          
# ==========================          
# FUNCIONES DE COLOR          
# ==========================          
          
          
title(){          
          
echo -e "${BOLD}${MAGENTA}$1${RESET}"          
          
}          
          
          
          
msg(){          
          
echo -e "${GREEN}[${OK}]${RESET} $1"          
          
}          
          
          
          
info(){          
          
echo -e "${CYAN}[${INFO}]${RESET} $1"          
          
}          
          
          
          
warning(){          
          
echo -e "${YELLOW}[${WARN}]${RESET} $1"          
          
}          
          
          
          
error(){          
          
echo -e "${RED}[${FAIL}]${RESET} $1"          
          
}          
          
          
          
pause(){          
          
echo          
          
read -p "Presiona ENTER para continuar..."          
          
}          
          
          
          
# ==========================          
# BANNER          
# ==========================          
          
          
banner(){          
          
clear          
          
echo -e "${MAGENTA}${BOLD}"          
          
echo "          
╔══════════════════════════════╗          
║                              ║          
║       KevinTech ZiVPN        ║          
║          Version 1.4.9       ║          
║                              ║          
╚══════════════════════════════╝          
"          
          
echo -e "${RESET}"          
          
}          
          
          
          
# ==========================          
# VERIFICAR ROOT          
# ==========================          
          
          
check_root(){          
          
if [ "$EUID" -ne 0 ]; then          
          
error "Ejecuta este script como root"          
          
exit 1          
          
fi          
          
}          
          
          
          
# ==========================          
# INICIO          
# ==========================          
          
          
check_root          
# ==========================          
# INSTALAR DEPENDENCIAS          
# ==========================          
          
          
install_dependencies(){          
          
info "Actualizando paquetes..."          
          
          
apt-get update -y >/dev/null 2>&1          
          
          
          
info "Instalando dependencias..."          
          
          
apt-get install -y \          
curl \          
openssl \          
iptables \          
jq \          
libc6-i386 \          
net-tools \          
>/dev/null 2>&1          
          
          
          
if [ $? -eq 0 ]; then          
          
msg "Dependencias instaladas correctamente"          
          
else          
          
error "Error instalando dependencias"          
          
exit 1          
          
fi          
          
          
}          
          
          
          
          
# ==========================          
# ACTIVAR IP FORWARD          
# ==========================          
          
          
enable_forward(){          
          
          
info "Activando IPv4 Forward..."          
          
          
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1          
          
          
          
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf          
          
then          
          
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf          
          
fi          
          
          
          
msg "IPv4 Forward activado"          
          
          
}          
          
          
          
          
# ==========================          
# DETECTAR ARQUITECTURA          
# ==========================          
          
          
detect_arch(){          
          
          
info "Detectando arquitectura..."          
          
          
ARCH=$(uname -m)          
          
          
          
case "$ARCH" in          
          
          
x86_64)          
          
ZIVPN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"          
          
CPU="amd64"          
          
;;          
          
          
          
aarch64|arm64)          
          
ZIVPN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64"          
          
CPU="arm64"          
          
;;          
          
          
          
*)          
          
error "Arquitectura no compatible: $ARCH"          
          
exit 1          
          
;;          
          
esac          
          
          
          
msg "Arquitectura detectada: $CPU"          
          
          
}          
          
          
          
          
# ==========================          
# DESCARGAR BINARIO          
# ==========================          
          
          
install_binary(){          
          
          
if [ -f "$BIN" ]          
          
then          
          
warning "ZiVPN ya está instalado"          
          
return          
          
fi          
          
          
          
info "Descargando ZiVPN 1.4.9..."          
          
          
          
curl -L \          
--fail \          
-o "$BIN" \          
"$ZIVPN_URL"          
          
          
          
if [ ! -f "$BIN" ]          
          
then          
          
error "No se pudo descargar ZiVPN"          
          
exit 1          
          
fi          
          
          
          
chmod +x "$BIN"          
          
          
          
msg "Binario ZiVPN instalado"          
          
          
}          
# ==========================          
# CREAR CARPETAS          
# ==========================          
          
          
prepare_zivpn(){          
          
          
info "Preparando directorios ZiVPN..."          
          
          
mkdir -p "$ZIVPN_DIR"          
          
          
chmod 755 "$ZIVPN_DIR"          
          
          
          
msg "Directorio creado: $ZIVPN_DIR"          
          
          
}          
          
          
          
          
          
# ==========================          
# CREAR CERTIFICADOS          
# ==========================          
          
          
create_certificates(){          
          
          
info "Generando certificados ZiVPN..."          
          
          
          
if [ -f "$ZIVPN_DIR/zivpn.crt" ] && [ -f "$ZIVPN_DIR/zivpn.key" ]          
          
then          
          
warning "Certificados existentes"          
          
return          
          
fi          
          
          
          
openssl req \          
-new \          
-newkey rsa:4096 \          
-days 3650 \          
-nodes \          
-x509 \          
-subj "/C=US/ST=CA/L=LA/O=KevinTech/CN=zivpn" \          
-keyout "$ZIVPN_DIR/zivpn.key" \          
-out "$ZIVPN_DIR/zivpn.crt" \          
>/dev/null 2>&1          
          
          
          
if [ -f "$ZIVPN_DIR/zivpn.crt" ]          
          
then          
          
msg "Certificados creados"          
          
else          
          
error "No se pudieron crear certificados"          
          
exit 1          
          
fi          
          
          
}          
          
          
          
          
          
# ==========================          
# CREAR CONFIGURACIÓN          
# ==========================          
          
          
create_config(){          
          
          
PORT=$1          
          
          
info "Creando configuración ZiVPN..."          
          
          
          
cat > "$CONFIG" <<EOF          
{          
    "listen": ":$PORT",          
    "cert": "$ZIVPN_DIR/zivpn.crt",          
    "key": "$ZIVPN_DIR/zivpn.key",          
    "max_conn": 0,          
    "auth": {          
        "mode": "passwords",          
        "config": []          
    }          
}          
EOF          
          
          
          
echo "$PORT" > "$PORT_FILE"          
          
          
          
chmod 644 "$CONFIG"          
          
          
          
msg "Config creada"          
          
}          
          
# ==========================          
# CREAR SERVICIO SYSTEMD          
# ==========================          
          
          
create_service(){          
          
          
info "Creando servicio ZiVPN..."          
          
          
          
cat > "$SERVICE" <<EOF          
[Unit]          
Description=KevinTech ZiVPN UDP Server          
After=network.target          
          
          
[Service]          
Type=simple          
User=root          
WorkingDirectory=/etc/zivpn          
          
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json          
          
Restart=always          
RestartSec=3          
          
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW          
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW          
          
          
[Install]          
WantedBy=multi-user.target          
EOF          
          
          
          
systemctl daemon-reload          
          
          
systemctl enable zivpn.service >/dev/null 2>&1          
          
          
msg "Servicio creado correctamente"          
          
          
}          
          
          
          
          
          
# ==========================          
# INICIAR SERVICIO          
# ==========================          
          
          
start_zivpn(){          
          
          
info "Iniciando ZiVPN..."          
          
          
systemctl restart zivpn.service          
          
          
          
sleep 2          
          
          
          
if systemctl is-active --quiet zivpn.service          
          
then          
          
msg "ZiVPN está activo"          
          
else          
          
error "ZiVPN no pudo iniciar"          
          
          
journalctl -u zivpn.service \          
-n 20 \          
--no-pager          
          
          
exit 1          
          
fi          
          
          
}          
          
          
          
          
          
# ==========================          
# INSTALACIÓN COMPLETA          
# ==========================          
          
          
install_zivpn(){          
          
          
banner          
          
          
title " INSTALACIÓN ZiVPN "          
          
          
read -p "Puerto UDP ZiVPN [7300]: " PORT          
          
          
          
if [ -z "$PORT" ]          
          
then          
          
PORT="7300"          
          
fi          
          
          
          
install_dependencies          
          
          
enable_forward          
          
          
detect_arch          
          
          
install_binary          
          
          
prepare_zivpn          
          
          
create_certificates          
          
          
create_config "$PORT"          
          
                    
          
          
create_service          
          
          
start_zivpn          
          
          
          
msg "ZiVPN instalado correctamente"          
          
          
}          
# ==========================          
# CONFIGURAR IPTABLES          
# ==========================          
          
          
setup_iptables(){          
          
          
PORT=$(cat "$PORT_FILE" 2>/dev/null)          
          
          
          
if [ -z "$PORT" ]          
          
then          
          
error "No se encontró puerto ZiVPN"          
          
return          
          
fi          
          
          
          
info "Configurando reglas de red..."          
          
          
          
DEV=$(ip -4 route show default | awk '{print $5}' | head -1)          
          
          
          
if [ -z "$DEV" ]          
          
then          
          
error "No se detectó interfaz de red"          
          
return          
          
fi          
          
          
          
          
# Limpiar reglas antiguas ZiVPN          
          
iptables -t nat -S PREROUTING | grep "6000:19999" |          
sed 's/-A/-D/' |          
while read RULE          
          
do          
          
iptables -t nat $RULE          
          
done          
          
          
          
iptables -S INPUT | grep "6000:19999" |          
sed 's/-A/-D/' |          
while read RULE          
          
do          
          
iptables $RULE          
          
done          
          
          
          
          
# Permitir puerto interno          
          
iptables -I INPUT 1 \          
-p udp \          
--dport "$PORT" \          
-j ACCEPT          
          
          
          
# Permitir rango externo          
          
iptables -I INPUT 1 \          
-p udp \          
--dport 6000:19999 \          
-j ACCEPT          
          
          
          
          
# Redirección UDP          
          
iptables -t nat -I PREROUTING 1 \          
-i "$DEV" \          
-p udp \          
--dport 6000:19999 \          
-j REDIRECT \          
--to-port "$PORT"          
          
          
          
          
# NAT salida          
          
iptables -t nat -D POSTROUTING \          
-o "$DEV" \          
-j MASQUERADE 2>/dev/null          
          
          
          
iptables -t nat -A POSTROUTING \          
-o "$DEV" \          
-j MASQUERADE          
          
          
          
          
msg "IPTables configurado"          
          
}          
          
          
          
          
          
# ==========================          
# AGREGAR USUARIO          
# ==========================          
          
          
add_user(){       
   
if [ ! -f "$CONFIG" ]; then
    error "ZiVPN no está instalado."
    return
fi
          
IP=$(curl -s ifconfig.me)

source /etc/kevintech/config.conf

DOMAIN=$SERVER_DOMAIN
         
read -p "🔑 Contraseña: " PASS
read -p "⏳ Días: " DAYS

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    error "Ingrese un número válido de días."
    return
fi

EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d")
          
if [ -z "$PASS" ]          
          
then          
          
error "Contraseña vacía"          
          
return          
          
fi          
          
          
          
jq ".auth.config += [\"$PASS\"] | .auth.config |= unique" \
"$CONFIG" \
> /tmp/zivpn.json

mv /tmp/zivpn.json "$CONFIG"

mkdir -p /etc/kevintech/usuarios
echo "$PASS|$DAYS|$EXPIRE" >> /etc/kevintech/usuarios/zivpn.db

systemctl restart zivpn.service          
          
          
          
clear
echo "✅ Acceso ZiVPN Creado"
echo "━━━━━━━━━━━━━━"
echo "🔑 Password: $PASS"
echo "⏳ Días: $DAYS"
echo "📅 Expira: $EXPIRE"
echo "━━━━━━━━━━━━━━"
echo "🌐 IP: $IP"
echo "☁️ Cloudflare: $DOMAIN"     
          
          
}          
          
          
          
          
          
# ==========================          
# ELIMINAR USUARIO          
# ==========================          
          
          
remove_user(){          
          
          
read -p "Contraseña a eliminar: " PASS          
          
          
          
jq ".auth.config -= [\"$PASS\"]" \          
"$CONFIG" \          
> /tmp/zivpn.json          
          
          
          
mv /tmp/zivpn.json "$CONFIG"          
          
          
          
systemctl restart zivpn.service          
          
          
          
msg "Usuario eliminado"          
          
          
}          
          
          
          
          
          
# ==========================          
# LISTAR USUARIOS          
# ==========================          
          
          
list_users(){

title "Usuarios ZiVPN"

FILE="/etc/kevintech/usuarios/zivpn.db"

if [ ! -f "$FILE" ]; then
    warning "No hay usuarios."
    return
fi

while IFS="|" read -r PASS DAYS EXPIRE
do
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo "👤 Usuario : $PASS"
    echo "⏳ Días    : $DAYS"
    echo "📅 Expira  : $EXPIRE"
done < "$FILE"

echo "━━━━━━━━━━━━━━━━━━━━━━"
}
# ==========================          
# RESTAURAR USUARIOS          
# ==========================          
          
          
restore_users(){          
          
          
FILE="/etc/kevintech/usuarios/zivpn.db"          
          
          
          
if [ ! -f "$FILE" ]          
          
then          
          
warning "No existe archivo de usuarios"          
          
return          
          
fi          
          
          
          
info "Restaurando usuarios..."          
          
          
          
while IFS="|" read -r PASS DAYS EXPIRE
do
          
          
if [ -n "$PASS" ]          
          
then          
          
          
jq ".auth.config += [\"$PASS\"] | .auth.config |= unique" \          
"$CONFIG" \          
> /tmp/zivpn.json          
          
          
          
mv /tmp/zivpn.json "$CONFIG"          
          
          
fi          
          
          
done < "$FILE"          
          
          
          
systemctl restart zivpn.service          
          
          
          
msg "Usuarios restaurados"          
          
}          
          
          
          
          
          
# ==========================          
# ESTADO          
# ==========================          
          
          
status_zivpn(){          
          
          
title "Estado ZiVPN"          
          
          
          
systemctl status zivpn.service --no-pager          
          
          
}          
          
          
          
          
          
# ==========================          
# DESINSTALAR          
# ==========================          
          
          
remove_zivpn(){          
          
          
warning "Eliminando ZiVPN..."          
          
          
          
systemctl stop zivpn.service 2>/dev/null          
          
systemctl disable zivpn.service 2>/dev/null          
          
          
          
rm -f "$SERVICE"          
          
rm -f "$BIN"          
          
rm -rf "$ZIVPN_DIR"          
          
          
          
systemctl daemon-reload          
          
          
          
msg "ZiVPN eliminado completamente"          
          
          
}          
          
          
          
          
          
# ==========================          
# MENU PRINCIPAL          
# ==========================          
          
          
menu(){          
          

while true          
          
do          
          
          
banner          
if [ -f "$BIN" ]; then
    ESTADO="${GREEN}✅ INSTALADO${RESET}"
else
    ESTADO="${RED}❌ DESINSTALADO${RESET}"
fi
          
          
echo -e "${CYAN}${BOLD}
╔══════════════════════════════╗
║        MENÚ ZiVPN            ║
╠══════════════════════════════╣
echo -e "\nEstado: $ESTADO\n"
╠══════════════════════════════╣
║ 1) 🚀 Instalar ZiVPN         ║
║ 2) ➕ Agregar usuario        ║
║ 3) ❌ Eliminar usuario       ║
║ 4) 👥 Lista usuarios         ║
║ 5) 🔄 Restaurar usuarios     ║
║ 6) 📊 Estado ZiVPN           ║
║ 7) 🗑️ Desinstalar ZiVPN      ║
║ 0) 🚪 Salir                  ║
╚══════════════════════════════╝
${RESET}"
          
          
          
read -p "Seleccione una opción: " OP          
          
          
          
case $OP in          
          
          
1)          
          
install_zivpn          
          
setup_iptables          
          
pause          
          
;;          
          
          
          
2)          
          
add_user          
          
pause          
          
;;          
          
          
          
3)          
          
remove_user          
          
pause          
          
;;          
          
          
          
4)          
          
list_users          
          
pause          
          
;;          
          
          
          
5)          
          
restore_users          
          
pause          
          
;;          
          
          
          
6)          
          
status_zivpn          
          
pause          
          
;;          
          
          
          
7)          
          
remove_zivpn          
          
pause          
          
;;          
          
          
          
0)          
          
exit          
          
;;          
          
          
          
*)          
          
warning "Opción incorrecta"          
          
pause          
          
;;          
          
          
esac          
          
          
done          
          
          
}          
          
          
          
          
          
# ==========================          
# EJECUCIÓN          
# ==========================          
          
          
check_root          
          
menu        
