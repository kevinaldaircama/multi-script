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
# Información VPS                    
#=========================================================                    
                    
OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")                          
CPU=$(nproc)                    
IP=$(hostname -I | awk '{print $1}')                                        
                    
TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')                    
USED_RAM=$(free -h | awk '/Mem:/ {print $3}')                    
FREE_RAM=$(free -h | awk '/Mem:/ {print $7}')                    
                    
RAM_USE=$(free | awk '/Mem:/ {printf("%.0f"),$3/$2*100}')                    
CPU_USE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')                    
                    
DISK=$(df -h / | awk 'NR==2 {print $5}')                    
                    
UPTIME=$(uptime -p | sed 's/up //')                                      
        
#=========================================================                    
# MENÚ PRINCIPAL                    
#=========================================================                    
                    
clear  
  
echo -e "${CYAN}┌──────────────────────────────────────────────┐${RESET}"  
echo -e "${CYAN}│${WHITE}         KEVIN TECH CONTROL PANEL             ${CYAN}│${RESET}"  
echo -e "${CYAN}└──────────────────────────────────────────────┘${RESET}"  
  
echo -e " ${YELLOW}OS${RESET}      : ${WHITE}$OS${RESET}"  
echo -e " ${YELLOW}UPTIME${RESET}  : ${WHITE}$UPTIME${RESET}"  
echo -e " ${YELLOW}IP/DOM${RESET}  : ${WHITE}$IP${RESET} ${GRAY}/${RESET} ${WHITE}${SERVER_DOMAIN:-sin-dominio}${RESET}"  
echo -e " ${YELLOW}DISCO${RESET}   : ${WHITE}$DISK usado${RESET}"  
echo -e " ${YELLOW}CPU${RESET}     : ${WHITE}${CPU_USE}%${RESET} ${GRAY}|${RESET} ${WHITE}Cores: $CPU${RESET}"  
echo -e " ${YELLOW}RAM${RESET}     : ${WHITE}${USED_RAM}/${TOTAL_RAM}${RESET} ${GRAY}|${RESET} ${WHITE}Libre: ${FREE_RAM}${RESET}"  
  
echo -e "${CYAN}────────────────────────────────────────────────${RESET}"  
echo -e "${MAGENTA} PROTOCOLOS${RESET}"  
  
[[ "$OPENSSH" == "ON" ]] && echo -e "   ${GREEN}●${RESET} SSH            ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(22)${RESET}"  
[[ "$DROPBEAR" == "ON" ]] && echo -e "   ${GREEN}●${RESET} Dropbear       ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(${DROPBEAR_PORT:-90})${RESET}"  
[[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]] && echo -e "   ${GREEN}●${RESET} SSL Tunnel     ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(80,443,8080)${RESET}"  
[[ "$ZIPVPN" == "ON" ]] && echo -e "   ${GREEN}●${RESET} ZiVPN          ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(${ZIPVPN_PORT:-Desconocido})${RESET}"  
[[ "$BADVPN" == "ON" ]] && echo -e "   ${GREEN}●${RESET} BadVPN         ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(7200,7300)${RESET}"  
[[ "$UDP_CUSTOM" == "ON" ]] && echo -e "   ${GREEN}●${RESET} UDP Custom     ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(36712)${RESET}"  
[[ "$SLOWDNS" == "ON" ]] && echo -e "   ${GREEN}●${RESET} SlowDNS        ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(53)${RESET}"  
[[ "$XRAY" == "ON" ]] && echo -e "   ${GREEN}●${RESET} Xray/V2Ray     ${GRAY}:${RESET} ${GREEN}ON${RESET} ${GRAY}(443)${RESET}"  
echo -e "${CYAN}────────────────────────────────────────────────${RESET}"
#=========================================================
# Contadores de cuentas
#=========================================================
SSH_COUNT=$(awk -F: '$3 >= 1000 && $1 != "nobody" {c++} END {print c+0}' /etc/passwd)

V2RAY_COUNT=0
HYSTERIA_COUNT=0
OPENVPN_COUNT=0

echo -e " ${BLUE}CUENTAS${RESET} : SSH:${WHITE}${SSH_COUNT}${RESET}  V2Ray:${WHITE}${V2RAY_COUNT}${RESET}  Histeria:${WHITE}${HYSTERIA_COUNT}${RESET}  OpenVPN:${WHITE}${OPENVPN_COUNT}${RESET}"
echo -e " ${BLUE}ESTADO${RESET}  : SSH:${GREEN}${OPENSSH:-OFF}${RESET}  V2Ray:${GREEN}${XRAY:-OFF}${RESET}  Histeria:${RED}OFF${RESET}  OpenVPN:${RED}OFF${RESET}"

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"  
echo -e " ${YELLOW}[01]${RESET} Usuarios SSH      ${YELLOW}[05]${RESET} Instalar protocolos"  
echo -e " ${YELLOW}[02]${RESET} Optimizar VPS     ${YELLOW}[06]${RESET} Update / Remove"  
echo -e " ${YELLOW}[03]${RESET} Cambiar dominio   ${YELLOW}[00]${RESET} Salir"  
echo -e " ${YELLOW}[04]${RESET} Auto inicio"  
echo -e "${CYAN}────────────────────────────────────────────────${RESET}"  
echo -e "${WHITE}         Kevin Tech Multi Script v2.0${RESET}"  
echo -e "${CYAN}────────────────────────────────────────────────${RESET}"  
echo  
  
echo -ne "${CYAN}Seleccione una opción:${RESET} "
read -r OPCION
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
                    
cat > "$FILE" <<'EOF'
#!/bin/bash
if [[ $- == *i* ]]; then
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
                    
git clone https://github.com/kevinaldaircama/multi-script.git "$TMP" >/dev/null 2>&1                    
                    
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
