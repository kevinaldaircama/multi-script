#!/bin/bash

#==================================================
# KevinTech Multi Script
# Menú Principal
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

#==============================
# Verificar Configuración
#==============================

if [[ ! -f "$CONFIG" ]]; then
    echo "No se encontró la configuración."
    echo "Ejecute primero instalar.sh"
    exit 1
fi

source "$CONFIG"
#==============================
# FIX VARIABLES FALTANTES
#==============================

SYSTEMDNS=${SYSTEMDNS:-OFF}
CUPSD=${CUPSD:-OFF}

CLOUDFLARE_STATUS=${CLOUDFLARE_STATUS:-OFF}
SSL_TUNNEL=${SSL_TUNNEL:-OFF}
PROXY_STATUS=${PROXY_STATUS:-UNKNOWN}
#==============================
# COLORES
#==============================
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
CYAN="\e[1;36m"
WHITE="\e[1;37m"
RESET="\e[0m"

animacion() {
    echo -ne "${CYAN}Cargando KevinTech"
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
PROTO2=""
PROTO3=""
PROTO4=""
PROTO5=""

[[ "$OPENSSH" == "ON" ]]   && PROTO1+=" ∘ SSH: 22"
[[ "$SYSTEMDNS" == "ON" ]] && PROTO1+="             ∘ System-DNS: 53"

[[ "$WEBSOCKET" == "ON" ]] && PROTO2+=" ∘ WS-Epro: 80"
[[ "$NGINX" == "ON" ]]     && PROTO2+="         ∘ WEB-NGinx: 81"

[[ "$DROPBEAR" == "ON" ]]  && PROTO3+=" ∘ DROPBEAR: 90"
[[ "$SSL" == "ON" || "$SSL_TUNNEL" == "ON" ]] && PROTO3+=" ∘ SSL/TUNNEL: 443"

[[ "$CUPSD" == "ON" ]]     && PROTO4+=" ∘ cupsd: 631"
[[ "$BADVPN" == "ON" ]]    && PROTO4+="          ∘ BadVPN: 7200"

[[ "$BADVPN" == "ON" ]]    && PROTO5+=" ∘ BadVPN: 7300"
[[ "$UDP_CUSTOM" == "ON" ]]&& PROTO5+="      ∘ UDP-Custom: 36712"

clear
animacion
clear

echo "      =====>>►► 🛡️ kevintech ⚔️ multi script 🛡️ ◄◄<<====="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ∘ S.O: $OS"
echo " ∘ Base:$ARCH"
echo " ∘ CPU's:$CPU"
echo " ∘ IP: $IP"
echo " ∘ FECHA: $FECHA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$SERVER_DOMAIN" ]]; then
    echo " 🌐 DOMINIO: $SERVER_DOMAIN"
    echo " 🔐 SSL TÚNEL: $SSL_TUNNEL"
    echo " ☁️ CLOUDFLARE: $CLOUDFLARE_STATUS"
    echo " 🟠 PROXY CF: $PROXY_STATUS"
else
    echo " 🌐 DOMINIO: NO CONFIGURADO"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Verified【 Kevin Tech Tutorials © 】by (Privanox VPN)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ -n "$PROTO1" ]] && echo "$PROTO1"
[[ -n "$PROTO2" ]] && echo "$PROTO2"
[[ -n "$PROTO3" ]] && echo "$PROTO3"
[[ -n "$PROTO4" ]] && echo "$PROTO4"
[[ -n "$PROTO5" ]] && echo "$PROTO5"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo " ∘ TOTAL: $TOTAL_RAM  ∘ M|LIBRE: $FREE_RAM  ∘ EN USO: $USED_RAM"
echo " ∘ U/RAM: ${RAM_USE}%  ∘ U/CPU: ${CPU_USE}%  ∘ BUFFER: $BUFFER"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo " [01] ➮ CONTROL USUARIOS (SSH/SSL/VMESS)"
echo " [02] ➮ [!] OPTIMIZAR VPS  [OFF]"
echo " [03] ➮ CONTADOR ONLINE USERS  [OFF]"
echo " [04] ➮ AUTOINICIAR SCRIPT  [$AUTO_START]"
echo " [05] ➮ INSTALADOR DE PROTOCOLOS"

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
    if [[ -f "$BASE/sistema/optimizar.sh" ]]; then
        bash "$BASE/sistema/optimizar.sh"
    else
        echo ""
        echo "🚧 Función en desarrollo."
        sleep 2
        bash "$BASE/menu.sh"
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
    else
        echo ""
        echo "❌ No existe el menú de protocolos."
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
echo "Eliminando KevinTech..."

rm -rf /etc/kevintech
rm -f /usr/local/bin/menu
rm -f /etc/profile.d/kevintech.sh

echo ""
echo "✅ Script eliminado correctamente."
echo "🧹 Sistema limpiado."

sleep 3
exit
;;

2)
clear
echo "Actualizando desde GitHub..."

cd /etc/kevintech || exit

git pull

echo ""
echo "✅ Script actualizado."

sleep 2
exec menu
;;

*)
echo "Opción inválida."
sleep 2
exec menu
;;

esac
;;

0)
    clear
    echo ""
    echo "👋 Gracias por usar KevinTech Multi Script."
    echo ""
    exit
;;

*)
    echo ""
    echo "❌ Opción inválida."
    sleep 1
    exec bash "$BASE/menu.sh"
;;

esac
