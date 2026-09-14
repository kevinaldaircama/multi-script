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

DROPBEAR=${DROPBEAR:-OFF}
BADVPN=${BADVPN:-OFF}
UDP_CUSTOM=${UDP_CUSTOM:-OFF}
SLOWDNS=${SLOWDNS:-OFF}
HYSTERIA=${HYSTERIA:-OFF}
OPENVPN=${OPENVPN:-OFF}
OPENSSH=${OPENSSH:-ON}
BHTTP=${BHTTP:-OFF}

#=========================================================
# Detectar HAProxy / SSL
#=========================================================

if systemctl is-active --quiet haproxy; then
    SSL="ON"
    SSL_TUNNEL="ON"
else
    SSL="OFF"
    SSL_TUNNEL="OFF"
fi

#=========================================================
# Detectar Cloudflare
#=========================================================

if [[ -n "$SERVER_DOMAIN" ]] && command -v dig >/dev/null 2>&1; then

    if dig +short NS "$SERVER_DOMAIN" 2>/dev/null | grep -qi cloudflare; then
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

ORANGE="\e[38;5;214m"
PINK="\e[38;5;213m"
PURPLE="\e[38;5;141m"
SKY="\e[38;5;117m"
LIME="\e[38;5;154m"
GOLD="\e[38;5;220m"

BOLD="\e[1m"
DIM="\e[2m"
BLINK="\e[5m"

#=========================================================
# VERSION DEL SCRIPT
#=========================================================

VERSION_FILE="$BASE/version.txt"
VERSION_URL="https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/version.txt"

if [[ -f "$VERSION_FILE" ]]; then
    VERSION_ACTUAL=$(head -n1 "$VERSION_FILE" | tr -d '\r')
else
    VERSION_ACTUAL="v2.0"
fi

NUEVA_VERSION=$(curl -fsSL --max-time 5 "$VERSION_URL" 2>/dev/null | head -n1 | tr -d '\r')

[[ -z "$NUEVA_VERSION" ]] && NUEVA_VERSION="No disponible"

#=========================================================
# INFORMACIÓN VPS
#=========================================================

OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")

CPU=$(nproc)

IP=$(hostname -I 2>/dev/null | awk '{print $1}')

TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')
USED_RAM=$(free -h | awk '/Mem:/ {print $3}')
FREE_RAM=$(free -h | awk '/Mem:/ {print $7}')

RAM_USE=$(free | awk '/Mem:/ {printf("%.0f"),$3/$2*100}')

CPU_USE=$(top -bn1 2>/dev/null |
    grep "Cpu(s)" |
    awk '{print int($2+$4)}')

DISK=$(df -h / | awk 'NR==2 {print $5}')

UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')

#=========================================================
# FUNCIONES DE CUENTAS
#=========================================================

#---------------------------------------------------------
# SSH / DROPBEAR
# Cuenta usuarios normales creados para SSH
#---------------------------------------------------------

get_ssh_users() {

    local TOTAL

    TOTAL=$(awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" &&
        $7 != "/usr/sbin/nologin" &&
        $7 != "/bin/false" {
            count++
        }

        END {
            print count+0
        }
    ' /etc/passwd 2>/dev/null)

    echo "${TOTAL:-0}"
}

#---------------------------------------------------------
# SSH CONECTADOS
#---------------------------------------------------------

get_ssh_online() {

    local ONLINE

    ONLINE=$(who 2>/dev/null |
        awk 'NF >= 1 {print $1}' |
        sort -u |
        wc -l)

    echo "${ONLINE:-0}"
}

#---------------------------------------------------------
# XRAY / VMESS CREADOS
#---------------------------------------------------------

get_v2ray_users() {

    local CFG="/usr/local/etc/xray/config.json"
    local TOTAL=0

    if [[ -f "$CFG" ]] &&
       command -v jq >/dev/null 2>&1; then

        TOTAL=$(jq '
            [
                .inbounds[]?.settings.clients[]?
            ] | length
        ' "$CFG" 2>/dev/null)

    fi

    echo "${TOTAL:-0}"
}

#---------------------------------------------------------
# XRAY / VMESS CONECTADOS
# Detecta actividad reciente en access.log
#---------------------------------------------------------

get_v2ray_online() {

    local LOG="/var/log/xray/access.log"

    if [[ ! -f "$LOG" ]]; then
        echo "0"
        return
    fi

    local ONLINE

    ONLINE=$(tail -n 1000 "$LOG" 2>/dev/null |
        grep -Ei "email:|accepted|proxy" |
        tail -n 200 |
        sed -nE 's/.*email: ([^, ]+).*/\1/p' |
        sort -u |
        wc -l)

    echo "${ONLINE:-0}"
}

#---------------------------------------------------------
# OPENVPN CREADOS
#---------------------------------------------------------

get_openvpn_users() {

    local DIR="/etc/openvpn/server/easy-rsa/pki/issued"
    local TOTAL=0
    local CERT
    local NAME

    if [[ ! -d "$DIR" ]]; then
        echo "0"
        return
    fi

    for CERT in "$DIR"/*.crt; do

        [[ ! -f "$CERT" ]] && continue

        NAME="$(basename "$CERT" .crt)"

        [[ "$NAME" == "server" ]] && continue

        TOTAL=$((TOTAL + 1))

    done

    echo "$TOTAL"
}

#---------------------------------------------------------
# OPENVPN CONECTADOS
#---------------------------------------------------------

get_openvpn_online() {

    local STATUS=""

    if [[ -f "/etc/openvpn/server/openvpn-status.log" ]]; then
        STATUS="/etc/openvpn/server/openvpn-status.log"

    elif [[ -f "/var/log/openvpn/status.log" ]]; then
        STATUS="/var/log/openvpn/status.log"

    elif [[ -f "/etc/openvpn/openvpn-status.log" ]]; then
        STATUS="/etc/openvpn/openvpn-status.log"
    fi

    if [[ -z "$STATUS" ]]; then
        echo "0"
        return
    fi

    local ONLINE

    ONLINE=$(awk -F',' '
        /^CLIENT_LIST,/ {
            count++
        }

        END {
            print count+0
        }
    ' "$STATUS" 2>/dev/null)

    echo "${ONLINE:-0}"
}

#---------------------------------------------------------
# HYSTERIA
#
# Si no existe un gestor independiente de usuarios
# se muestra 0 en lugar de inventar cuentas.
#---------------------------------------------------------

get_hysteria_users() {

    local TOTAL=0

    # Intentar detectar archivos de usuarios comunes
    if [[ -f "/etc/hysteria/config.yaml" ]]; then

        TOTAL=$(grep -Eic \
            '^[[:space:]]*(user|username|password)[[:space:]]*:' \
            "/etc/hysteria/config.yaml" 2>/dev/null)

    fi

    echo "${TOTAL:-0}"
}

get_hysteria_online() {

    local ONLINE=0

    if systemctl is-active --quiet hysteria 2>/dev/null; then

        ONLINE=$(journalctl \
            -u hysteria \
            --since "5 minutes ago" \
            --no-pager \
            2>/dev/null |
            grep -Eic \
            'connected|connection|client|accepted')

    fi

    echo "${ONLINE:-0}"
}

#---------------------------------------------------------
# BHTTP
#---------------------------------------------------------

get_bhttp_status() {

    if systemctl is-active --quiet bhttp.service 2>/dev/null; then
        echo "ON"
    else
        echo "OFF"
    fi
}

#=========================================================
# CALCULAR CUENTAS
#=========================================================

SSH_COUNT=$(get_ssh_users)
SSH_ONLINE=$(get_ssh_online)

DROPBEAR_COUNT="$SSH_COUNT"
DROPBEAR_ONLINE="$SSH_ONLINE"

V2RAY_COUNT=$(get_v2ray_users)
V2RAY_ONLINE=$(get_v2ray_online)

HYSTERIA_COUNT=$(get_hysteria_users)
HYSTERIA_ONLINE=$(get_hysteria_online)

OPENVPN_COUNT=$(get_openvpn_users)
OPENVPN_ONLINE=$(get_openvpn_online)

#=========================================================
# DETECTAR BHTTP REAL
#=========================================================

BHTTP_STATUS=$(get_bhttp_status)

if [[ "$BHTTP_STATUS" == "ON" ]]; then
    BHTTP="ON"
else
    BHTTP="${BHTTP:-OFF}"
fi

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

#=========================================================
# PROTOCOLOS ACTIVOS - 2 COLUMNAS
#=========================================================

echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e " ${MAGENTA}${BOLD}◆ PROTOCOLOS${RESET}"

echo ""

#---------------------------------------------------------
# FILA 1
#---------------------------------------------------------

if [[ "$OPENSSH" == "ON" ]]; then
    SSH_STATE="${GREEN}${BOLD}ON${RESET}"
else
    SSH_STATE="${RED}OFF${RESET}"
fi

if [[ "$DROPBEAR" == "ON" ]]; then
    DROPBEAR_STATE="${GREEN}${BOLD}ON${RESET}"
else
    DROPBEAR_STATE="${RED}OFF${RESET}"
fi

printf "   ${GREEN}●${RESET} ${WHITE}SSH${RESET}          ${GRAY}:${RESET} %-18b" \
    "$SSH_STATE"

printf "${GREEN}●${RESET} ${WHITE}Dropbear${RESET}     ${GRAY}:${RESET} %b\n" \
    "$DROPBEAR_STATE"


#---------------------------------------------------------
# FILA 2
#---------------------------------------------------------

if [[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]]; then
    SSL_STATE="${GREEN}${BOLD}ON${RESET}"
else
    SSL_STATE="${RED}OFF${RESET}"
fi

if [[ "$ZIPVPN" == "ON" ]]; then
    ZIPVPN_STATE="${GREEN}${BOLD}ON${RESET}"
else
    ZIPVPN_STATE="${RED}OFF${RESET}"
fi

printf "   ${GREEN}●${RESET} ${WHITE}SSL Tunnel${RESET}   ${GRAY}:${RESET} %-18b" \
    "$SSL_STATE"

printf "${GREEN}●${RESET} ${WHITE}ZiVPN${RESET}        ${GRAY}:${RESET} %b\n" \
    "$ZIPVPN_STATE"


#---------------------------------------------------------
# FILA 3
#---------------------------------------------------------

if [[ "$BADVPN" == "ON" ]]; then
    BADVPN_STATE="${GREEN}${BOLD}ON${RESET}"
else
    BADVPN_STATE="${RED}OFF${RESET}"
fi

if [[ "$UDP_CUSTOM" == "ON" ]]; then
    UDP_STATE="${GREEN}${BOLD}ON${RESET}"
else
    UDP_STATE="${RED}OFF${RESET}"
fi

printf "   ${GREEN}●${RESET} ${WHITE}BadVPN${RESET}       ${GRAY}:${RESET} %-18b" \
    "$BADVPN_STATE"

printf "${GREEN}●${RESET} ${WHITE}UDP Custom${RESET}   ${GRAY}:${RESET} %b\n" \
    "$UDP_STATE"


#---------------------------------------------------------
# FILA 4
#---------------------------------------------------------

if [[ "$SLOWDNS" == "ON" ]]; then
    SLOWDNS_STATE="${GREEN}${BOLD}ON${RESET}"
else
    SLOWDNS_STATE="${RED}OFF${RESET}"
fi

if [[ "$XRAY" == "ON" || systemctl is-active --quiet xray 2>/dev/null ]]; then
    XRAY_STATE="${GREEN}${BOLD}ON${RESET}"
else
    XRAY_STATE="${RED}OFF${RESET}"
fi

printf "   ${GREEN}●${RESET} ${WHITE}SlowDNS${RESET}      ${GRAY}:${RESET} %-18b" \
    "$SLOWDNS_STATE"

printf "${GREEN}●${RESET} ${WHITE}Xray/V2Ray${RESET}   ${GRAY}:${RESET} %b\n" \
    "$XRAY_STATE"


#---------------------------------------------------------
# FILA 5
#---------------------------------------------------------

if [[ "$HYSTERIA" == "ON" ]]; then
    HYSTERIA_STATE="${GREEN}${BOLD}ON${RESET}"
else
    HYSTERIA_STATE="${RED}OFF${RESET}"
fi

if [[ "$OPENVPN" == "ON" ]]; then
    OPENVPN_STATE="${GREEN}${BOLD}ON${RESET}"
else
    OPENVPN_STATE="${RED}OFF${RESET}"
fi

printf "   ${GREEN}●${RESET} ${WHITE}Hysteria${RESET}     ${GRAY}:${RESET} %-18b" \
    "$HYSTERIA_STATE"

printf "${GREEN}●${RESET} ${WHITE}OpenVPN${RESET}      ${GRAY}:${RESET} %b\n" \
    "$OPENVPN_STATE"


#---------------------------------------------------------
# FILA 6 - BHTTP / CHECKUSER
#---------------------------------------------------------

if [[ "$BHTTP_STATUS" == "ON" ]]; then
    BHTTP_STATE="${GREEN}${BOLD}ON${RESET}"
else
    BHTTP_STATE="${RED}OFF${RESET}"
fi

if [[ "$CHECKUSER" == "ON" ]] ||
   systemctl is-active --quiet checkgestor 2>/dev/null ||
   systemctl is-active --quiet ssh-ws-internal 2>/dev/null; then

    CHECKUSER_STATE="${GREEN}${BOLD}ON${RESET}"

else

    CHECKUSER_STATE="${RED}OFF${RESET}"

fi

printf "   ${GREEN}●${RESET} ${WHITE}BHTTP${RESET}        ${GRAY}:${RESET} %-18b" \
    "$BHTTP_STATE"

printf "${GREEN}●${RESET} ${WHITE}CheckUser${RESET}    ${GRAY}:${RESET} %b\n" \
    "$CHECKUSER_STATE"


echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

#=========================================================
# CUENTAS POR PROTOCOLO
#=========================================================

echo -e " ${BLUE}${BOLD}◆ CUENTAS POR PROTOCOLO${RESET}"

echo ""

#---------------------------------------------------------
# FILA 1
#---------------------------------------------------------

printf "   ${WHITE}SSH${RESET}        ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}    " \
    "$SSH_COUNT" "$SSH_ONLINE"

printf "${WHITE}Dropbear${RESET}   ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
    "$DROPBEAR_COUNT" "$DROPBEAR_ONLINE"


#---------------------------------------------------------
# FILA 2
#---------------------------------------------------------

printf "   ${WHITE}V2Ray${RESET}      ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}    " \
    "$V2RAY_COUNT" "$V2RAY_ONLINE"

printf "${WHITE}Hysteria${RESET}   ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}\n" \
    "$HYSTERIA_COUNT" "$HYSTERIA_ONLINE"


#---------------------------------------------------------
# FILA 3
#---------------------------------------------------------

printf "   ${WHITE}OpenVPN${RESET}    ${GRAY}:${RESET} ${CYAN}%s creados${RESET} / ${GREEN}%s conectados${RESET}    " \
    "$OPENVPN_COUNT" "$OPENVPN_ONLINE"

printf "${WHITE}BHTTP${RESET}      ${GRAY}:${RESET} ${CYAN}SSH${RESET} ${GRAY}(usa cuentas SSH)${RESET}\n"


echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

#=========================================================
# OPCIONES PRINCIPALES
#=========================================================

echo -e " ${GOLD}${BOLD}[01]${RESET} ${WHITE}👥 Usuarios SSH${RESET}        ${GOLD}${BOLD}[05]${RESET} ${WHITE}📦 Instalar protocolos${RESET}"

echo -e " ${GOLD}${BOLD}[02]${RESET} ${WHITE}🛩️ Optimizar VPS${RESET}       ${GOLD}${BOLD}[06]${RESET} ${WHITE}🔄 Update / Remove${RESET}"

echo -e " ${GOLD}${BOLD}[03]${RESET} ${WHITE}🌐 Cambiar dominio${RESET}     ${GOLD}${BOLD}[00]${RESET} ${WHITE}🚪 Salir${RESET}"

echo -e " ${GOLD}${BOLD}[04]${RESET} ${WHITE}⚒️ Auto inicio${RESET}"

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

#=========================================================
# VERSION
#=========================================================

if [[ "$NUEVA_VERSION" != "No disponible" &&
      "$NUEVA_VERSION" != "$VERSION_ACTUAL" ]]; then

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

wget https://raw.githubusercontent.com/oktaviaps/rebuild-vps/main/uinstal

chmod 777 *

./uinstal

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
