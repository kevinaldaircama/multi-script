#!/bin/bash

#==================================================
# Multi Script
# Menú Principal
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

#==============================
# Verificar Configuración
#==============================

if [[ ! -f "$CONFIG" ]]; then
    echo "No se encontró la configuración."
    echo "Ejecute primero install.sh"
    exit 1
fi

source "$CONFIG"
# Crear variable si no existe
if ! grep -q "^OPTIMIZAR=" "$CONFIG"; then
    echo "OPTIMIZAR=OFF" >> "$CONFIG"
fi

source "$CONFIG"
ZIPVPN=${ZIPVPN:-OFF}
OPTIMIZAR=${OPTIMIZAR:-OFF}
#==============================
# FIX VARIABLES FALTANTES
#==============================

SYSTEMDNS=${SYSTEMDNS:-OFF}
CUPSD=${CUPSD:-OFF}

CLOUDFLARE_STATUS=${CLOUDFLARE_STATUS:-OFF}
SSL_TUNNEL=${SSL_TUNNEL:-OFF}
PROXY_STATUS=${PROXY_STATUS:-UNKNOWN}
OPTIMIZAR=${OPTIMIZAR:-OFF}
#==============================
# COLORES
#==============================
RED2="\e[1;31m"
BLUE2="\e[1;34m"
CYAN2="\e[1;36m"
WHITE="\e[1;97m"
RESET="\e[0m"
INFO_COLOR="\e[1;35m"   # morado (puedes cambiarlo)
INFO2="\e[1;36m"        # cyan suave
RESET="\e[0m"
RED="\e[1;91m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

animacion() {
    echo -ne "${CYAN}Cargando script espera unos segundos..."
    for i in {1..3}; do
        echo -n "."
        sleep 0.3
    done
    echo -e "${RESET}"
}
#==============================
# Obtener Información del VPS
#==============================

OS=$(source /etc/os-release && echo "$NAME $VERSION_ID")
ARCH=$(uname -m)
CPU=$(nproc)

IP=$(hostname -I | awk '{print $1}')

FECHA=$(date +"%d/%m/%Y-%H:%M")

TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')
FREE_RAM=$(free -h | awk '/Mem:/ {print $7}')
USED_RAM=$(free -h | awk '/Mem:/ {print $3}')

RAM_USE=$(free | awk '/Mem:/ {printf("%.2f"), $3/$2*100}')

CPU_USE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')

BUFFER=$(free -h | awk '/Mem:/ {print $6}')
#==============================
# Construir Lista de Protocolos
#==============================

PROTO1=""
PROTO1=""
PROTO2=""
PROTO3=""
PROTO4=""
PROTO5=""

[[ "$OPENSSH" == "ON" ]]     && PROTO1+=" ∘ OpenSSH:22"
[[ "$SYSTEMDNS" == "ON" ]]   && PROTO1+="    ∘ SystemDNS:53"

[[ "$WEBSOCKET" == "ON" ]]   && PROTO2+=" ∘ WebSocket:80"
[[ "$ZIPVPN" == "ON" ]]      && PROTO2+="    ∘ ZIPVPN"

[[ "$DROPBEAR" == "ON" ]]    && PROTO3+=" ∘ Dropbear:90"
[[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]] && PROTO3+="    ∘ SSL/TLS:443"

[[ "$BADVPN" == "ON" ]]      && PROTO4+=" ∘ BadVPN:7200/7300"
[[ "$UDP_CUSTOM" == "ON" ]]  && PROTO4+="    ∘ UDP Custom:36712"

[[ "$SLOWDNS" == "ON" ]]     && PROTO5+=" ∘ SlowDNS:53"

clear
animacion
clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA}        🛡️ KevinTech Multi Script 🛡️${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${INFO_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${INFO_COLOR} ∘ S.O: ${INFO2}$OS${INFO_COLOR}"
echo -e "${INFO_COLOR} ∘ Base: ${INFO2}$ARCH${INFO_COLOR}"
echo -e "${INFO_COLOR} ∘ CPU's: ${INFO2}$CPU${INFO_COLOR}"
echo -e "${INFO_COLOR} ∘ IP: ${INFO2}$IP${INFO_COLOR}"
echo -e "${INFO_COLOR} ∘ FECHA: ${INFO2}$FECHA${INFO_COLOR}"
echo -e "${INFO_COLOR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
if [[ -n "$SERVER_DOMAIN" ]]; then
    echo -e "${CYAN} 🌐 DOMINIO: ${WHITE}$SERVER_DOMAIN${RESET}"
echo -e "${CYAN} 🔐 SSL TÚNEL: ${WHITE}$SSL_TUNNEL${RESET}"
echo -e "${CYAN} ☁️ CLOUDFLARE: ${WHITE}$CLOUDFLARE_STATUS${RESET}"
echo -e "${CYAN} 🟠 PROXY CF: ${WHITE}$PROXY_STATUS${RESET}"
else
    echo " 🌐 DOMINIO: NO CONFIGURADO"
fi
echo -e "${BLUE2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${RED2} Verified【 Kevin Tech Tutorials © 】 by (Privanox VPN)${RESET}"
echo -e "${BLUE2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${RED2} Protocolos Instalados:${RESET}"

[[ -n "$PROTO1" ]] && echo -e "${WHITE}${PROTO1}${RESET}"
[[ -n "$PROTO2" ]] && echo -e "${WHITE}${PROTO2}${RESET}"
[[ -n "$PROTO3" ]] && echo -e "${WHITE}${PROTO3}${RESET}"
[[ -n "$PROTO4" ]] && echo -e "${WHITE}${PROTO4}${RESET}"
[[ -n "$PROTO5" ]] && echo -e "${WHITE}${PROTO5}${RESET}"

echo -e "${BLUE2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${BLUE2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${CYAN2} ∘ TOTAL: ${WHITE}$TOTAL_RAM  ∘ M|LIBRE: $FREE_RAM  ∘ EN USO: $USED_RAM${RESET}"
echo -e "${CYAN2} ∘ U/RAM: ${WHITE}${RAM_USE}%  ∘ U/CPU: ${WHITE}${CPU_USE}%  ∘ BUFFER: ${WHITE}$BUFFER${RESET}"

echo -e "${BLUE2}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${YELLOW} [01]${WHITE} ➮ CONTROL USUARIOS (SSH/SSL/VMESS)"
echo -e "${YELLOW} [02]${WHITE} ➮ OPTIMIZAR VPS ${CYAN}[$OPTIMIZAR]${RESET}"
echo -e "${YELLOW} [03]${WHITE} ➮ CONTADOR ONLINE USERS [OFF]"
echo -e "${YELLOW} [04]${WHITE} ➮ AUTOINICIAR SCRIPT ${CYAN}[$AUTO_START]${RESET}"
echo -e "${YELLOW} [05]${WHITE} ➮ INSTALADOR DE PROTOCOLOS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo " [06] ➮ [!] UPDATE / REMOVE  |  [0] ⇦ [ SALIR ]"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
#==============================
# Esperar Opción
#==============================

echo ""
read -rp " ► Opcion : " OPCION

case "$OPCION" in

1)
    if [[ -f "$BASE/usuarios/menu.sh" ]]; then
        bash "$BASE/usuarios/menu.sh"
    else
        echo ""
        echo "❌ Módulo no instalado."
        sleep 2
        bash "$BASE/menu.sh"
    fi
;;

2)

# Si existe en la instalación
if [[ -f "$BASE/sistema/optimizar.sh" ]]; then
    bash "$BASE/sistema/optimizar.sh"

# Si existe en la carpeta del proyecto
elif [[ -f "$HOME/multi-script/sistema/optimizar.sh" ]]; then

    mkdir -p "$BASE/sistema"

    cp "$HOME/multi-script/sistema/optimizar.sh" "$BASE/sistema/optimizar.sh"

    chmod +x "$BASE/sistema/optimizar.sh"

    bash "$BASE/sistema/optimizar.sh"

else

    echo ""
    echo "❌ No se encontró optimizar.sh"

    sleep 2

    exec bash "$BASE/menu.sh"

fi
;;
3)
    if [[ -f "$BASE/sistema/contador.sh" ]]; then
        bash "$BASE/sistema/contador.sh"
    else
        echo ""
        echo "🚧 Función en desarrollo."
        sleep 2
        bash "$BASE/menu.sh"
    fi
;;

4)
    FILE="/etc/profile.d/kevintech.sh"

    if [[ "$AUTO_START" == "OFF" ]]; then
        sed -i 's/AUTO_START=OFF/AUTO_START=ON/' "$CONFIG"

        cat > "$FILE" <<EOF
#!/bin/bash
if [[ \$- == *i* ]]; then
    menu
fi
EOF

        chmod +x "$FILE"
    else
        sed -i 's/AUTO_START=ON/AUTO_START=OFF/' "$CONFIG"
        rm -f "$FILE"
    fi

    exec bash "$BASE/menu.sh"
;;
5)
    if [[ -f "$BASE/protocolos/menu.sh" ]]; then
        bash "$BASE/protocolos/menu.sh"

    elif [[ -f "$HOME/multi-script/protocolos/menu.sh" ]]; then
        mkdir -p "$BASE/protocolos"
        cp -rf "$HOME/multi-script/protocolos/menu.sh" "$BASE/protocolos/menu.sh"
        chmod +x "$BASE/protocolos/menu.sh"
        bash "$BASE/protocolos/menu.sh"

    else
        echo ""
        echo "❌ No se encontró el menú de protocolos."
        sleep 2
        exec bash "$BASE/menu.sh"
    fi
;;

6)
clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "         UPDATE / REMOVE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " [1] ➮ Remover Script"
echo " [2] ➮ Actualizar Script"
echo ""
read -rp " ► Opción: " OP6

case "$OP6" in

1)
    clear
    echo "Eliminando script de kevinTech..."

    rm -rf /etc/kevintech
    rm -f /usr/local/bin/menu
    rm -f /etc/profile.d/kevintech.sh

    echo ""
    echo "✅ Script eliminado correctamente."
    echo "🧹 Sistema limpiado correctamente."

    sleep 3
    exit
;;

2)
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "        ACTUALIZANDO SCRIPT..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    TMP="/tmp/kevintech_update"

    rm -rf "$TMP"

    echo "📥 Descargando actualización si existe..."
sleep 1

git clone https://github.com/kevinaldaircama/multi-script.git "$TMP" >/dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo ""
    echo "❌ No se pudo descargar la actualización ya estás en la última versión."
    sleep 3
    exec menu
fi

echo "📦 Instalando y copiando archivos..."
sleep 1

cp -rf "$TMP"/* /etc/kevintech/

chmod -R +x /etc/kevintech

echo "🧹 Limpiando y eliminando archivos temporales..."
sleep 1

rm -rf "$TMP"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        ✅ ACTUALIZACIÓN COMPLETADA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo '✔️ El script de "Kevin Tech Tutorials" se actualizó correctamente.'
echo ""
echo "🚀 Reiniciando el panel espere un momento..."
echo ""

sleep 2
exec menu
;;
*)
    echo "❌ Opción invalida intente de nuevo."
    sleep 2
    exec menu
;;

esac
;;
0)
    clear
    echo ""
    echo "👋 Gracias por usar Multi Script de Kevin tech tutorials."
    echo ""
    exit
;;

*)
    echo ""
    echo "❌ Opción inválida verifica de nuevo."
    sleep 1
    exec bash "$BASE/menu.sh"
;;

esac
