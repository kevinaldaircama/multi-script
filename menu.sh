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
CUPSD=${CUPSD:-OFF}
SSL_TUNNEL=${SSL_TUNNEL:-OFF}
CLOUDFLARE_STATUS=${CLOUDFLARE_STATUS:-OFF}
PROXY_STATUS=${PROXY_STATUS:-OFF}
AUTO_START=${AUTO_START:-OFF}

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
# Animación Premium
#=========================================================

spinner() {

    local pid=$!

    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    while kill -0 "$pid" 2>/dev/null; do

        for i in $(seq 0 9); do

            printf "\r${CYAN}%s${RESET} Cargando..." "${spin:$i:1}"

            sleep 0.08

        done

    done

    printf "\r"

}

(
sleep 1
) & spinner

clear

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
# Construir lista de protocolos
#=========================================================

PROTO1=""
PROTO2=""
PROTO3=""
PROTO4=""
PROTO5=""
PROTO6=""

[[ "$OPENSSH" == "ON" ]]     && PROTO1+="🟢 OpenSSH        Puerto 22"
[[ "$SYSTEMDNS" == "ON" ]]   && PROTO1+="\n🟢 SystemDNS      Puerto 53"

[[ "$WEBSOCKET" == "ON" ]]   && PROTO2+="🟢 WebSocket      Puerto 80"
[[ "$ZIPVPN" == "ON" ]]      && PROTO2+="\n🟢 ZIP VPN"

[[ "$DROPBEAR" == "ON" ]]    && PROTO3+="🟢 Dropbear       Puerto 90"
[[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]] && PROTO3+="\n🟢 SSL/TLS        Puerto 443"

[[ "$BADVPN" == "ON" ]]      && PROTO4+="🟢 BadVPN         7200 / 7300"
[[ "$UDP_CUSTOM" == "ON" ]]  && PROTO4+="\n🟢 UDP Custom     Puerto 36712"

[[ "$SLOWDNS" == "ON" ]]     && PROTO5+="🟢 SlowDNS        Puerto 53"

[[ "$V2RAY" == "ON" ]] && PROTO6+="🟢 V2Ray / Xray   WebSocket"

clear

topline
printf "${WHITE}║             ⚡ KEVIN TECH MULTI SCRIPT PREMIUM ⚡             ║${RESET}\n"
printf "${GRAY}║                  Premium Edition v2.0                       ║${RESET}\n"
bottomline

echo ""

#=========================================================
# SISTEMA
#=========================================================

echo -e "${CYAN}┌──────────────────── 🖥 SISTEMA ────────────────────┐${RESET}"

printf "${WHITE}│ ${CYAN}OS${WHITE}        %-44s│\n" "$OS"

printf "${WHITE}│ ${CYAN}Kernel${WHITE}    %-44s│\n" "$ARCH"

printf "${WHITE}│ ${CYAN}CPU${WHITE}       %-44s│\n" "$CPU Cores"

printf "${WHITE}│ ${CYAN}Fecha${WHITE}     %-44s│\n" "$FECHA"

printf "${WHITE}│ ${CYAN}Uptime${WHITE}    %-44s│\n" "$UPTIME"

echo -ne "${WHITE}│ ${CYAN}RAM${WHITE}       "
progress_bar "$RAM_USE"
printf "%*s│\n" $((29-${#RAM_USE})) ""

echo -ne "${WHITE}│ ${CYAN}CPU Load${WHITE}  "
progress_bar "$CPU_USE"
printf "%*s│\n" $((29-${#CPU_USE})) ""

printf "${WHITE}│ ${CYAN}Disco${WHITE}     %-44s│\n" "$DISK usado"

echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"

echo ""

#=========================================================
# RED
#=========================================================

echo -e "${CYAN}┌───────────────────── 🌐 RED ───────────────────────┐${RESET}"

printf "${WHITE}│ ${CYAN}Dominio${WHITE}     %-42s│\n" "${SERVER_DOMAIN:-NO CONFIGURADO}"

printf "${WHITE}│ ${CYAN}IP Pública${WHITE}  %-42s│\n" "$IP"

printf "${WHITE}│ ${CYAN}Cloudflare${WHITE}  %-42b│\n" "$(status "$CLOUDFLARE_STATUS")"

printf "${WHITE}│ ${CYAN}Proxy CF${WHITE}    %-42s│\n" "$PROXY_STATUS"

printf "${WHITE}│ ${CYAN}SSL Tunnel${WHITE}  %-42b│\n" "$(status "$SSL_TUNNEL")"

echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"

echo ""

#=========================================================
# Protocolos
#=========================================================

echo -e "${CYAN}┌──────────────── 🚀 PROTOCOLOS ────────────────────┐${RESET}"

for LISTA in "$PROTO1" "$PROTO2" "$PROTO3" "$PROTO4" "$PROTO5" "$PROTO6"
do

    [[ -n "$LISTA" ]] || continue

    while IFS= read -r LINEA
    do
        printf "${WHITE}│ %-52s│${RESET}\n" "$LINEA"
    done <<< "$(echo -e "$LISTA")"

done

echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"

echo ""

#=========================================================
# Recursos
#=========================================================

echo -e "${CYAN}┌────────────────── 📊 RECURSOS ─────────────────────┐${RESET}"

printf "${WHITE}│ RAM Total : %-12s Libre : %-12s Usada : %-10s│\n" \
"$TOTAL_RAM" "$FREE_RAM" "$USED_RAM"

printf "${WHITE}│ Buffer    : %-41s│\n" "$BUFFER"

echo -e "${CYAN}└───────────────────────────────────────────────────┘${RESET}"

echo ""
#=========================================================
# MENÚ PRINCIPAL
#=========================================================

echo -e "${CYAN}╔══════════════════════ ⚙ MENÚ PRINCIPAL ══════════════════════╗${RESET}"

printf "${WHITE}║ ${YELLOW}[01]${WHITE} 👥 Control de Usuarios (SSH / SSL / VMESS)           ║${RESET}\n"

printf "${WHITE}║ ${YELLOW}[02]${WHITE} 🚀 Optimizar VPS                     %-15b║${RESET}\n" \
"$(status "$OPTIMIZAR")"

printf "${WHITE}║ ${YELLOW}[04]${WHITE} 🔄 Auto Inicio                      %-15b║${RESET}\n" \
"$(status "$AUTO_START")"

printf "${WHITE}║ ${YELLOW}[05]${WHITE} 📦 Instalador de Protocolos                     ║${RESET}\n"

printf "${WHITE}║ ${YELLOW}[06]${WHITE} 🛠 Update / Remove                              ║${RESET}\n"

printf "${WHITE}║ ${YELLOW}[00]${WHITE} 🚪 Salir                                        ║${RESET}\n"

echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${RESET}"

echo ""

echo -e "${GRAY}╭──────────────────────────────────────────────────────────────╮${RESET}"
echo -e "${GRAY}│${WHITE}     Kevin Tech Tutorials © Premium Edition v2.0             ${GRAY}│${RESET}"
echo -e "${GRAY}╰──────────────────────────────────────────────────────────────╯${RESET}"

echo ""

read -rp "$(echo -e "${CYAN}➜ Seleccione una opción ${WHITE}➤ ${RESET}")" OPCION

#=========================================================
# CASE PRINCIPAL
#=========================================================

case "$OPCION" in
1)

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${WHITE}║                 👥 CONTROL DE USUARIOS                      ║${RESET}"
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
