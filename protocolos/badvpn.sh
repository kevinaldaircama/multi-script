#!/bin/bash                      
                      
BASE="/etc/kevintech"                      
CONFIG="$BASE/config.conf"                      
                      
source "$CONFIG"                      
                      
CYAN="\e[1;96m"                      
GREEN="\e[1;92m"                      
RED="\e[1;91m"                      
WHITE="\e[1;97m"                      
YELLOW="\e[1;93m"                      
RESET="\e[0m"                      
                      
SERVICE1="badvpn-udpgw-7300"                      
SERVICE2="badvpn-udpgw-7200"                      
                      
PORT1="7300"                      
PORT2="7200"                      
                      
BIN="/usr/local/bin/badvpn-udpgw"                   
install_badvpn() {   
    cd /root || cd /
    
    apt update -y >/dev/null 2>&1              
    apt install -y git cmake build-essential >/dev/null 2>&1              
              
    rm -rf /tmp/badvpn              
    git clone -q https://github.com/ambrop72/badvpn.git /tmp/badvpn              
              
    cd /tmp/badvpn || return 1              
    mkdir -p build              
    cd build || return 1              
              
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1              
    make -j$(nproc) >/dev/null 2>&1              
              
    if [[ ! -f "udpgw/badvpn-udpgw" ]]; then              
        return 1              
    fi              
              
    cp udpgw/badvpn-udpgw "$BIN"              
    chmod +x "$BIN"              
              
    cat > /etc/systemd/system/$SERVICE1.service <<EOF
[Unit]
Description=BadVPN UDPGW Puerto 7300
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 127.0.0.1:$PORT1 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/$SERVICE2.service <<EOF
[Unit]
Description=BadVPN UDPGW Puerto 7200
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 127.0.0.1:$PORT2 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload              
    systemctl enable $SERVICE1 $SERVICE2 >/dev/null 2>&1              
    systemctl restart $SERVICE1 $SERVICE2              
              
    if grep -q '^BADVPN=' "$CONFIG"; then        
    sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG"        
else        
    echo "BADVPN=ON" >> "$CONFIG"        
fi             
}                 
# ==== MODO AUTOMÁTICO ====        
if [[ "$1" == "--auto" ]]; then        
    echo "🚀 Instalando BadVPN automáticamente..."        
    if install_badvpn; then        
        echo "✅ BadVPN instalado correctamente."        
        exit 0        
    else        
        echo "❌ Error instalando BadVPN."        
        exit 1        
    fi        
fi        
            
while true; do                      
                      
clear                      
                      
source "$CONFIG"                      
                      
if [[ "$BADVPN" == "ON" ]]; then                      
    STATUS="${GREEN}🟢 ACTIVO${RESET}"                      
else                      
    STATUS="${RED}🔴 DESINSTALADO${RESET}"                      
fi                      
                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
echo -e "${WHITE}            🌐 BADVPN MANAGER${RESET}"                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
echo -e " Estado      : $STATUS"                      
echo -e " Puerto 1    : $PORT1"                      
echo -e " Puerto 2    : $PORT2"                      
echo -e " Servicio    : BadVPN UDPGW"                      
                      
echo                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
if [[ "$BADVPN" == "ON" ]]; then
cat <<EOF
 [1] ➮ Reinstalar BadVPN
 [2] ➮ Reiniciar Servicio
 [3] ➮ Ver Estado
 [4] ➮ Desinstalar
 [0] ➮ Regresar
EOF
else
cat <<EOF
 [1] ➮ Instalar BadVPN
 [0] ➮ Regresar
EOF
fi                      
                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
read -rp " ► Opción: " OP                      
                      
case "$OP" in                      
1)
clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}        INSTALANDO BADVPN UDPGW${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

if install_badvpn; then
    BADVPN="ON"
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}       ✅ BADVPN ACTIVADO${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo "🎮 Juegos      : Puerto $PORT1"
    echo "📞 Videollamada: Puerto $PORT2"
else
    echo -e "${RED}❌ Error instalando BadVPN.${RESET}"
fi

sleep 3
;;

2)                      
                      
clear                      
                      
echo "🔄 Reiniciando BadVPN..."                      
                      
systemctl restart $SERVICE1                      
systemctl restart $SERVICE2                      
                      
echo ""                      
echo "✅ Servicios reiniciados."                      
                      
sleep 2                      
                      
;;                      
                      
                      
3)                      
                      
clear                      
                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
echo -e "${WHITE}        ESTADO BADVPN UDPGW${RESET}"                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
echo ""                      
                      
systemctl status $SERVICE1 --no-pager                      
                      
echo ""                      
                      
systemctl status $SERVICE2 --no-pager                      
                      
echo ""                      
                      
echo "Puertos activos:"                      
                      
ss -lnpt | grep -E "7300|7200"                      
                      
echo ""                      
                      
read -n1 -r -p "Presione una tecla para continuar..."                      
                      
;;                      
                      
                      
4)                      
                      
clear                      
                      
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"                      
echo "        DESINSTALAR BADVPN"                      
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"                      
                      
read -rp "¿Seguro que deseas eliminar BadVPN? (s/n): " R                      
                      
                      
if [[ "$R" =~ ^[Ss]$ ]]; then                      
                      
                      
systemctl stop $SERVICE1 2>/dev/null                      
systemctl stop $SERVICE2 2>/dev/null                      
                      
                      
systemctl disable $SERVICE1 2>/dev/null                      
systemctl disable $SERVICE2 2>/dev/null                      
                      
                      
rm -f /etc/systemd/system/$SERVICE1.service                      
rm -f /etc/systemd/system/$SERVICE2.service                      
                      
                      
rm -f "$BIN"                      
                      
                      
systemctl daemon-reload                      
                      
                      
sed -i 's/^BADVPN=.*/BADVPN=OFF/' "$CONFIG"                      
                      
                      
BADVPN="OFF"                      
                      
                      
echo ""                      
                      
echo "✅ BadVPN eliminado."                      
                      
else                      
                      
echo "❌ Cancelado."                      
                      
fi                      
                      
                      
sleep 3                      
                      
;;                      
                      
                      
0)                      
                      
exec bash "$BASE/protocolos/menu.sh"                      
                      
;;                      
                      
                      
*)                      
                      
echo "❌ Opción inválida."                      
                      
sleep 2                      
                      
;;                      
                      
esac                      
                      
done
