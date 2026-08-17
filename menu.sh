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
# COLORES PREMIUM
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

# Colores adicionales para interfaz
ORANGE="\e[38;5;214m"
PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
SKY="\e[38;5;117m"
LIME="\e[38;5;154m"
GOLD="\e[38;5;220m"

# Efectos
BOLD="\e[1m"
DIM="\e[2m"
BLINK="\e[5m"

#=========================================================
# VERSION DEL SCRIPT
#=========================================================

VERSION_FILE="$BASE/version.txt"
VERSION_URL="https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/version.txt"

# Versión instalada
if [[ -f "$VERSION_FILE" ]]; then
    VERSION_ACTUAL=$(head -n1 "$VERSION_FILE" | tr -d '\r')
else
    VERSION_ACTUAL="v2.0"
fi

# Consultar versión disponible en GitHub
NUEVA_VERSION=$(curl -fsSL --max-time 5 "$VERSION_URL" 2>/dev/null | head -n1 | tr -d '\r')

[[ -z "$NUEVA_VERSION" ]] && NUEVA_VERSION="No disponible"
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

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET} ${BOLD}${WHITE}             KEVIN TECH CONTROL PANEL${RESET}             ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET} ${GRAY}                  PREMIUM EDITION${RESET}                  ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo ""
echo -e " ${GOLD}◆${RESET} ${YELLOW}OS${RESET}      ${GRAY}:${RESET} ${WHITE}$OS${RESET}"
echo -e " ${GOLD}◆${RESET} ${YELLOW}UPTIME${RESET}  ${GRAY}:${RESET} ${WHITE}$UPTIME${RESET}"
echo -e " ${GOLD}◆${RESET} ${YELLOW}IP/DOM${RESET}  ${GRAY}:${RESET} ${SKY}$IP${RESET} ${GRAY}/${RESET} ${PINK}${SERVER_DOMAIN:-sin-dominio}${RESET}"
echo -e " ${GOLD}◆${RESET} ${YELLOW}DISCO${RESET}   ${GRAY}:${RESET} ${WHITE}$DISK usado${RESET}"
echo -e " ${GOLD}◆${RESET} ${YELLOW}CPU${RESET}     ${GRAY}:${RESET} ${LIME}${CPU_USE}%${RESET} ${GRAY}|${RESET} ${WHITE}Cores: $CPU${RESET}"
echo -e " ${GOLD}◆${RESET} ${YELLOW}RAM${RESET}     ${GRAY}:${RESET} ${LIME}${USED_RAM}/${TOTAL_RAM}${RESET} ${GRAY}|${RESET} ${WHITE}Libre: $FREE_RAM${RESET}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e " ${MAGENTA}${BOLD}◆ PROTOCOLOS ACTIVOS${RESET}"
echo ""

[[ "$OPENSSH" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}SSH${RESET}            ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(22)${RESET}"

[[ "$DROPBEAR" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}Dropbear${RESET}       ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(${DROPBEAR_PORT:-90})${RESET}"

[[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}SSL Tunnel${RESET}     ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(80,443,8080)${RESET}"

[[ "$ZIPVPN" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}ZiVPN${RESET}          ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(${ZIPVPN_PORT:-Desconocido})${RESET}"

[[ "$BADVPN" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}BadVPN${RESET}         ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(7200,7300)${RESET}"

[[ "$UDP_CUSTOM" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}UDP Custom${RESET}     ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(36712)${RESET}"

[[ "$SLOWDNS" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}SlowDNS${RESET}        ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(53)${RESET}"

[[ "$XRAY" == "ON" ]] && \
echo -e "   ${GREEN}●${RESET} ${WHITE}Xray/V2Ray${RESET}     ${GRAY}:${RESET} ${GREEN}${BOLD}ON${RESET} ${GRAY}(443)${RESET}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " ${BLUE}${BOLD}◆ CUENTAS${RESET} ${GRAY}:${RESET} SSH:${WHITE}${SSH_COUNT}${RESET}  V2Ray:${WHITE}${V2RAY_COUNT}${RESET}  Histeria:${WHITE}${HYSTERIA_COUNT}${RESET}  OpenVPN:${WHITE}${OPENVPN_COUNT}${RESET}"

echo -e " ${BLUE}${BOLD}◆ ESTADO ${RESET} ${GRAY}:${RESET} SSH:${GREEN}${OPENSSH:-OFF}${RESET}  V2Ray:${GREEN}${XRAY:-OFF}${RESET}  Histeria:${GREEN}${HYSTERIA:-OFF}${RESET}  OpenVPN:${GREEN}${OPENVPN:-OFF}${RESET}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " ${GOLD}${BOLD}[01]${RESET} ${WHITE}👥 Usuarios SSH${RESET}        ${GOLD}${BOLD}[05]${RESET} ${WHITE}📦 Instalar protocolos${RESET}"
echo -e " ${GOLD}${BOLD}[02]${RESET} ${WHITE}🛩️ Optimizar VPS${RESET}       ${GOLD}${BOLD}[06]${RESET} ${WHITE}🔄 Update / Remove${RESET}"
echo -e " ${GOLD}${BOLD}[03]${RESET} ${WHITE}🌐 Cambiar dominio${RESET}     ${GOLD}${BOLD}[00]${RESET} ${WHITE}🚪 Salir${RESET}"
echo -e " ${GOLD}${BOLD}[04]${RESET} ${WHITE}⚒️ Auto inicio${RESET}"

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

if [[ "$NUEVA_VERSION" != "No disponible" && "$NUEVA_VERSION" != "$VERSION_ACTUAL" ]]; then

    echo -e "${YELLOW}  ⚡ NUEVA VERSIÓN DISPONIBLE: ${GREEN}${NUEVA_VERSION}${RESET}"
    echo -e "${GRAY}  Versión instalada: ${WHITE}${VERSION_ACTUAL}${RESET}"

else

    echo -e "${GREEN}  ✔ SISTEMA ACTUALIZADO${RESET}"
    echo -e "${GRAY}  Versión: ${WHITE}${VERSION_ACTUAL}${RESET}"

fi

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"
echo -e "${WHITE}         Kevin Tech Multi Script${RESET}"
echo -e "${GRAY}              Premium Edition${RESET}"
echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

echo ""
echo -ne "${CYAN}${BOLD}➜${RESET} ${WHITE}Seleccione una opción ${GRAY}➤${RESET} "
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
echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}                 🔄 ACTUALIZANDO SCRIPT${RESET}              ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo ""
echo -e "${CYAN}◆${RESET} ${WHITE}Preparando actualización...${RESET}"
echo ""

UPDATE="/etc/kevintech/update.sh"

if [[ ! -f "$UPDATE" ]]; then

    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}❌ No se encontró update.sh${RESET}                            ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo ""
    echo -e "${YELLOW}Ubicación esperada:${RESET}"
    echo -e " ${GRAY}➜${RESET} ${WHITE}$UPDATE${RESET}"

    sleep 3
    exec menu

fi

chmod +x "$UPDATE"

echo -e "${CYAN}◆${RESET} ${WHITE}Ejecutando actualizador...${RESET}"
echo ""

bash "$UPDATE"

STATUS=$?

echo ""

if [[ $STATUS -eq 0 ]]; then

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}        ✅ ACTUALIZACIÓN COMPLETADA CORRECTAMENTE${RESET}      ${GREEN}║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

else

    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${WHITE}${BOLD}              ❌ ERROR EN LA ACTUALIZACIÓN${RESET}             ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

fi

echo ""
echo -e "${CYAN}🚀${RESET} ${WHITE}Regresando al panel...${RESET}"

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
