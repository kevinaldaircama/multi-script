#!/bin/bash                
                
#=========================================================                
#        KEVIN TECH MULTI SCRIPT - PREMIUM EDITION                
#=========================================================                
                
BASE="/etc/kevintech"                
CONFIG="$BASE/config.conf"                
                
#=========================================================                
# Verificar configuración                
#=========================================================                
                
[[ ! -f "$CONFIG" ]] && {                
    clear                
    echo ""                
    echo "❌ No se encontró config.conf"                
    echo "👉 Ejecuta primero install.sh"                
    echo ""                
    exit 1                
}                
                
source "$CONFIG"                
                
grep -q "^OPTIMIZAR=" "$CONFIG" || echo "OPTIMIZAR=OFF" >> "$CONFIG"                
                
source "$CONFIG"                
                
#=========================================================                
# Variables                
#=========================================================                
                
ZIPVPN=${ZIPVPN:-OFF}                
OPTIMIZAR=${OPTIMIZAR:-OFF}                
SYSTEMDNS=${SYSTEMDNS:-OFF}                
XRAY=${XRAY:-OFF}                
CUPSD=${CUPSD:-OFF}                
SSL_TUNNEL=${SSL_TUNNEL:-OFF}                
CLOUDFLARE_STATUS=${CLOUDFLARE_STATUS:-OFF}                
PROXY_STATUS=${PROXY_STATUS:-OFF}                
AUTO_START=${AUTO_START:-OFF}                
                
# Detectar HAProxy                
if systemctl is-active --quiet haproxy; then                
    SSL="ON"                
    SSL_TUNNEL="ON"                
else                
    SSL="OFF"                
    SSL_TUNNEL="OFF"                
fi                
# Detectar Cloudflare                
if [[ -n "$SERVER_DOMAIN" ]]; then                
    if dig +short NS "$SERVER_DOMAIN" | grep -qi cloudflare; then                
        CLOUDFLARE_STATUS="ON"                
    else                
        CLOUDFLARE_STATUS="OFF"                
    fi                
fi                
#=========================================================                
# Colores Premium                
#=========================================================                
                
RESET="\e[0m"                
                
RED="\e[1;91m"                
GREEN="\e[1;92m"                
YELLOW="\e[1;93m"                
BLUE="\e[1;94m"                
MAGENTA="\e[1;95m"                
CYAN="\e[1;96m"                
WHITE="\e[1;97m"                
GRAY="\e[1;90m"                
                
#=========================================================                
# Funciones                
#=========================================================                
                
line() {                
    printf "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}\n"                
}                
                
topline() {                
    printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}\n"                
}                
                
bottomline() {                
    printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}\n"                
}                
                
status() {                
    [[ "$1" == "ON" ]] && echo -e "${GREEN}🟢 ON${RESET}" || echo -e "${RED}🔴 OFF${RESET}"                
}                
                
#=========================================================                
# Barra de porcentaje                
#=========================================================                
                
progress_bar() {                
                
    local percent=$1                
                
    local total=20                
                
    local filled=$((percent*total/100))                
                
    local empty=$((total-filled))                
                
    printf "${GREEN}"                
                
    for ((i=0;i<filled;i++));do                
        printf "█"                
    done                
                
    printf "${GRAY}"                
                
    for ((i=0;i<empty;i++));do                
        printf "░"                
    done                
                
    printf "${RESET} ${percent}%%"                
                
}                             
#=========================================================                
# Información VPS                
#=========================================================                
                
OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")                
ARCH=$(uname -m)                
CPU=$(nproc)                
IP=$(hostname -I | awk '{print $1}')                
FECHA=$(date +"%d/%m/%Y %H:%M")                
                
TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')                
USED_RAM=$(free -h | awk '/Mem:/ {print $3}')                
FREE_RAM=$(free -h | awk '/Mem:/ {print $7}')                
                
RAM_USE=$(free | awk '/Mem:/ {printf("%.0f"),$3/$2*100}')                
CPU_USE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')                
                
DISK=$(df -h / | awk 'NR==2 {print $5}')                
                
UPTIME=$(uptime -p | sed 's/up //')                
                
BUFFER=$(free -h | awk '/Mem:/ {print $6}')                
    
#=========================================================                
# MENÚ PRINCIPAL                
#=========================================================                
                
clear    
    
echo "┌──────────────────────────────────────────────┐"    
echo "│         KEVIN TECH CONTROL PANEL             │"    
echo "└──────────────────────────────────────────────┘"    
echo " OS      : $OS"    
echo " UPTIME  : $UPTIME"    
echo " IP/DOM  : $IP / ${SERVER_DOMAIN:-sin-dominio}"    
echo " DISCO   : $DISK usado"    
echo " CPU     : ${CPU_USE}%   Cores: $CPU"    
echo " RAM     : ${USED_RAM}/${TOTAL_RAM}   Libre: ${FREE_RAM}"    
echo "────────────────────────────────────────────────"    
echo " PROTOCOLOS:"    
    
[[ "$OPENSSH" == "ON" ]]     && echo "   SSH            : ON (22)"    
[[ "$DROPBEAR" == "ON" ]]    && echo "   Dropbear       : ON (${DROPBEAR_PORT:-90})"    
[[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]] && echo "   SSL Tunnel     : ON (80,443,8080)"    
[[ "$ZIPVPN" == "ON" ]]      && echo "   ZiVPN          : ON (${ZIPVPN_PORT:-Desconocido})"    
[[ "$BADVPN" == "ON" ]]      && echo "   BadVPN         : ON (7200,7300)"    
[[ "$UDP_CUSTOM" == "ON" ]]  && echo "   UDP Custom     : ON (36712)"    
[[ "$SLOWDNS" == "ON" ]]     && echo "   SlowDNS        : ON (53)"    
[[ "$XRAY" == "ON" ]]        && echo "   Xray/V2Ray     : ON (443)"    
    
echo "────────────────────────────────────────────────"    
echo " [01] Usuarios SSH      [05] Instalar protocolos"    
echo " [02] Optimizar VPS     [06] Update / Remove"    
echo " [03] Cambiar dominio   [00] Salir"    
echo " [04] Auto inicio"    
echo "────────────────────────────────────────────────"    
echo "         Kevin Tech Multi Script v2.0"    
echo "────────────────────────────────────────────────"    
echo    
    
read -rp "Seleccione una opción: " OPCION    
#=========================================================                
# CASE PRINCIPAL                
#=========================================================                
                
case "$OPCION" in                
1)                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                 👥 CREACION DE USUARIOS                      ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
echo ""                
                
if [[ -f "$BASE/usuarios/menu.sh" ]]; then                
                
    bash "$BASE/usuarios/menu.sh"                
                
else                
                
    echo -e "${RED}❌ El módulo de usuarios no está instalado.${RESET}"                
    sleep 2                
    exec bash "$BASE/menu.sh"                
                
fi                
                
;;                
                
#=========================================================                
                
2)                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                    🚀 OPTIMIZAR VPS                         ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
echo ""                
                
if [[ -f "$BASE/herramientas/optimizar.sh" ]]; then                
                
    bash "$BASE/herramientas/optimizar.sh"                
                
elif [[ -f "$HOME/multi-script/herramientas/optimizar.sh" ]]; then                
                
    mkdir -p "$BASE/herramientas"                
                
    cp "$HOME/multi-script/herramientas/optimizar.sh" \                
    "$BASE/herramientas/optimizar.sh"                
                
    chmod +x "$BASE/herramientas/optimizar.sh"                
                
    bash "$BASE/herramientas/optimizar.sh"                
                
else                
                
    echo -e "${RED}❌ No se encontró optimizar.sh${RESET}"                
    sleep 2                
    exec bash "$BASE/menu.sh"                
                
fi                
                
;;                
#=========================================================                
                
3)                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                  🌐 CAMBIAR DOMINIO                         ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
echo ""                
                
if [[ -f "$BASE/herramientas/change-domain" ]]; then                
                
    bash "$BASE/herramientas/change-domain"                
                
elif [[ -f "$HOME/multi-script/herramientas/change-domain" ]]; then                
                
    mkdir -p "$BASE/herramientas"                
                
    cp "$HOME/multi-script/herramientas/change-domain" \                
       "$BASE/herramientas/change-domain"                
                
    chmod +x "$BASE/herramientas/change-domain"                
                
    bash "$BASE/herramientas/change-domain"                
                
else                
                
    echo -e "${RED}❌ No se encontró change-domain.${RESET}"                
                
    sleep 2                
                
    exec bash "$BASE/menu.sh"                
                
fi                
                
;;                
#=========================================================                
                
4)                
                
FILE="/etc/profile.d/kevintech.sh"                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                    🔄 AUTO INICIO                           ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
echo ""                
                
if [[ "$AUTO_START" == "OFF" ]]; then                
                
    sed -i 's/AUTO_START=OFF/AUTO_START=ON/' "$CONFIG"                
                
cat > "$FILE" << EOF                
#!/bin/bash                
if [[ \$- == *i* ]]; then                
    menu                
fi                
EOF                
                
    chmod +x "$FILE"                
                
    echo -e "${GREEN}✅ Auto inicio activado correctamente.${RESET}"                
                
else                
                
    sed -i 's/AUTO_START=ON/AUTO_START=OFF/' "$CONFIG"                
                
    rm -f "$FILE"                
                
    echo -e "${YELLOW}⚠️ Auto inicio desactivado.${RESET}"                
                
fi                
                
sleep 2                
exec bash "$BASE/menu.sh"                
                
;;                
                
#=========================================================                
                
5)                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                📦 INSTALADOR DE PROTOCOLOS                  ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
echo ""                
                
if [[ -f "$BASE/protocolos/menu.sh" ]]; then                
                
    bash "$BASE/protocolos/menu.sh"                
                
elif [[ -f "$HOME/multi-script/protocolos/menu.sh" ]]; then                
                
    mkdir -p "$BASE/protocolos"                
                
    cp -rf "$HOME/multi-script/protocolos/menu.sh" \                
    "$BASE/protocolos/menu.sh"                
                
    chmod +x "$BASE/protocolos/menu.sh"                
                
    bash "$BASE/protocolos/menu.sh"                
                
else                
                
    echo -e "${RED}❌ No se encontró el menú de protocolos.${RESET}"                
                
    sleep 2                
                
    exec bash "$BASE/menu.sh"                
                
fi                
                
;;                
                
#=========================================================                
                
6)                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                    🛠 UPDATE / REMOVE                        ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
                
echo ""                
echo -e "${YELLOW}[1]${WHITE} 🗑 Remover Script"                
echo -e "${YELLOW}[2]${WHITE} 🔄 Actualizar Script"                
echo ""                
                
read -rp "$(echo -e "${CYAN}➜ Seleccione una opción ${WHITE}➤ ${RESET}")" OP6                
                
case "$OP6" in                
                
1)                
                
clear                
                
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                  ⚠️ ELIMINAR SCRIPT                         ║${RESET}"                
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"                
echo ""                
                
echo -e "${YELLOW}[1]${WHITE} 🗑 Eliminar Kevin Tech Multi Script"                
echo -e "${YELLOW}[2]${WHITE} ♻️ Reconstruir / Reinstalar VPS"                
echo -e "${YELLOW}[0]${WHITE} 🔙 Volver"                
echo ""                
                
read -rp "$(echo -e "${CYAN}➜ Seleccione una opción ${WHITE}➤ ${RESET}")" OPDEL                
                
case "$OPDEL" in                
                
1)                
                
clear                
                
echo -e "${RED}⚠️ Eliminando Kevin Tech Multi Script...${RESET}"                
                
sleep 1                
                
rm -rf /etc/kevintech                
rm -f /usr/local/bin/menu                
rm -f /etc/profile.d/kevintech.sh                
                
echo ""                
echo -e "${GREEN}✅ Script eliminado correctamente.${RESET}"                
echo -e "${GREEN}🧹 Sistema limpiado correctamente.${RESET}"                
                
sleep 3                
                
exit                
                
;;                
                
2)                
                
clear                
                
echo -e "${YELLOW}♻️ Iniciando reconstrucción del VPS...${RESET}"                
                
cd /root || exit                
                
wget https://raw.githubusercontent.com/oktaviaps/rebuild-vps/main/uinstal; chmod 777 *; ./uinstal                
                
;;                
                
0)                
                
exec menu                
                
;;                
                
*)                
                
echo -e "${RED}❌ Opción inválida.${RESET}"                
                
sleep 2                
                
exec menu                
                
;;                
                
esac                
                
;;                
                
#=========================================================                
                
2)                
                
clear                
                
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                 🔄 ACTUALIZANDO SCRIPT                      ║${RESET}"                
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
                
echo ""                
                
TMP="/tmp/kevintech_update"                
                
rm -rf "$TMP"                
                
echo -e "${CYAN}📥 Descargando actualización...${RESET}"                
                
sleep 1                
                
git clone \                
https://github.com/kevinaldaircama/multi-script.git \                
"$TMP" >/dev/null 2>&1                
                
if [[ $? -ne 0 ]]; then                
                
    echo ""                
    echo -e "${RED}❌ No se pudo descargar la actualización.${RESET}"                
                
    sleep 3                
                
    exec menu                
                
fi                
                
echo -e "${CYAN}📦 Instalando archivos...${RESET}"                
                
sleep 1                
                
cp -rf "$TMP"/* /etc/kevintech/                
                
chmod -R +x /etc/kevintech                
                
echo -e "${CYAN}🧹 Limpiando archivos temporales...${RESET}"                
                
sleep 1                
                
rm -rf "$TMP"                
                
clear                
                
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"                
echo -e "${WHITE}║                ✅ ACTUALIZACIÓN COMPLETADA                  ║${RESET}"                
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"                
                
echo ""                
echo -e "${GREEN}✔️ Kevin Tech Multi Script actualizado.${RESET}"                
echo ""                
echo -e "${CYAN}🚀 Reiniciando panel...${RESET}"                
                
sleep 2                
                
exec menu                
                
;;                
                
*)                
                
echo -e "${RED}❌ Opción inválida.${RESET}"                
                
sleep 2                
                
exec menu                
                
;;                
                
esac                
                
;;                
                
#=========================================================                
                
0)                
                
clear                
                
echo ""                
echo -e "${GREEN}👋 Gracias por usar Kevin Tech Multi Script Premium.${RESET}"                
echo ""                
                
exit                
                
;;                
                
#=========================================================                
                
*)                
                
echo ""                
                
echo -e "${RED}❌ Opción inválida.${RESET}"                
                
sleep 1                
                
exec bash "$BASE/menu.sh"                
                
;;                
                
esac    
