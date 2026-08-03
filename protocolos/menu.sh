#!/bin/bash                      
                      
#==================================================                      
# KevinTech Multi Script                      
# Instalador de Protocolos                      
#==================================================                      
                      
BASE="/etc/kevintech"                      
CONFIG="$BASE/config.conf"                      
                      
[[ -f "$CONFIG" ]] || {                      
    echo "❌ No se encontró la configuración."                      
    exit 1                      
}                      
                      
source "$CONFIG" 2>/dev/null                      
                      
clear                      
                      
CYAN="\e[1;96m"                      
BLUE="\e[1;94m"                      
MAGENTA="\e[1;95m"                      
YELLOW="\e[1;93m"                      
GREEN="\e[1;92m"                      
RED="\e[1;91m"                      
WHITE="\e[1;97m"                      
RESET="\e[0m"                      
                      
loading() {                    
                    
    local MSG="$1"                    
                    
    echo                    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                    
    echo -e "${WHITE}        KevinTech Multi Script${RESET}"                    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                    
    echo                    
    echo -ne "${YELLOW}$MSG${RESET}"                    
                    
    for i in {1..6}; do                    
        echo -n "."                    
        sleep 0.2                    
    done                    
                    
    echo                    
}                    
                    
clear                  
                  
loading "Verificando protocolos"                  
                  
status_service() {                  
                  
    local SERVICE="$1"                  
    local CONF="$2"                  
                  
    if systemctl list-unit-files | grep -q "^${SERVICE}.service"; then                  
        if systemctl is-active --quiet "$SERVICE"; then                  
            echo -e "${GREEN}🟢 ACTIVO${RESET}"                  
        else                  
            echo -e "${RED}🔴 OFF${RESET}"                  
        fi                  
    else                  
        if [[ "$CONF" == "ON" ]]; then                  
            echo -e "${GREEN}🟢 ACTIVO${RESET}"                  
        else                  
            echo -e "${RED}🔴 OFF${RESET}"                  
        fi                  
    fi                  
}                  
                  
OPENSSH_STATUS=$(status_service ssh "$OPENSSH")                  
CHECKUSER_STATUS=$(status_service checkuser "$CHECKUSER")    
DROPBEAR_STATUS=$(status_service dropbear_custom "$DROPBEAR")                  
SSL_STATUS=$(status_service haproxy "$SSL")                  
UDP_STATUS=$(status_service udp-custom "$UDP_CUSTOM")                  
SLOWDNS_STATUS=$(status_service dnstt "$SLOWDNS")                  
XRAY_STATUS=$(status_service xray "$V2RAY")                  
OPENVPN_STATUS=$(status_service openvpn-server@server "$OPENVPN")                  
WIREGUARD_STATUS=$(status_service wg-quick@wg0 "$WIREGUARD")        
HYSTERIA_V2_STATUS=$(status_service hysteria-server "$HYSTERIA_V2")        
HYSTERIA2025_STATUS=$(status_service hysteria "$HYSTERIA2025")        
HYSTERIA_PRO_STATUS=$(status_service hysteria "$HYSTERIA_PRO")        
UDPMOD_STATUS=$(status_service udpmod "$UDPMOD")                 
if [[ "$ZIPVPN" == "ON" ]]; then             
    ZIPVPN_STATUS="${GREEN}🟢 ACTIVO${RESET}"                      
else                      
    ZIPVPN_STATUS="${RED}🔴 OFF${RESET}"                      
fi                      
                      
if [[ "$BADVPN" == "ON" ]]; then                      
    BADVPN_STATUS="${GREEN}🟢 ACTIVO${RESET}"                      
else                      
    BADVPN_STATUS="${RED}🔴 OFF${RESET}"                      
fi                      
                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
echo -e "${MAGENTA}           🛡 KevinTech Multi Script${RESET}"                      
echo -e "${WHITE}             MENÚ DE PROTOCOLOS${RESET}"                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
printf " ${GREEN}[01]${RESET} 🔐 OpenSSH          %b\n" "$OPENSSH_STATUS"                      
printf " ${GREEN}[02]${RESET} 📦 ZIPVPN           %b\n" "$ZIPVPN_STATUS"                      
printf " ${GREEN}[03]${RESET} 🚪 Dropbear         %b\n" "$DROPBEAR_STATUS"                      
printf " ${GREEN}[04]${RESET} 🔒 SSL / TLS        %b\n" "$SSL_STATUS"                      
printf " ${GREEN}[05]${RESET} ⚡ BadVPN           %b\n" "$BADVPN_STATUS"                      
printf " ${GREEN}[06]${RESET} 🚀 UDP Custom       %b\n" "$UDP_STATUS"                      
printf " ${GREEN}[07]${RESET} 🌐 SlowDNS          %b\n" "$SLOWDNS_STATUS"                      
printf " ${GREEN}[08]${RESET} ☁️ Xray / V2Ray     %b\n" "$XRAY_STATUS"                      
printf " ${GREEN}[09]${RESET} 👤 CheckUser        %b\n" "$CHECKUSER_STATUS"              
printf " ${GREEN}[10]${RESET} 🔐 OpenVPN Pro      %b\n" "$OPENVPN_STATUS"        
printf " ${GREEN}[11]${RESET} 🛡 WireGuard        %b\n" "$WIREGUARD_STATUS"        
printf " ${GREEN}[12]${RESET} 🚀 Hysteria Evozi   %b\n" "$HYSTERIA_V2_STATUS"        
printf " ${GREEN}[13]${RESET} ⚡ Hysteria 2025    %b\n" "$HYSTERIA2025_STATUS"        
printf " ${GREEN}[14]${RESET} 🔰 Hysteria Pro     %b\n" "$HYSTERIA_PRO_STATUS"        
printf " ${GREEN}[15]${RESET} 🌐 UDPMOD           %b\n" "$UDPMOD_STATUS"                    
echo                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
echo -e "${YELLOW}                🛠 SISTEMA${RESET}"                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
echo -e " ${GREEN}[16]${RESET} 🧰 Herramientas"                      
echo -e " ${GREEN}[17]${RESET} 🔄 Reiniciar Servicios"                      
echo -e " ${GREEN}[18]${RESET} 🔥 Firewall"                      
                      
echo                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
echo -e " ${GREEN}[00]${RESET} ↩ Regresar"                      
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"                      
                      
echo                      
read -rp " ► Opción: " OP                      
                      
case "$OP" in                      
1) bash "$BASE/protocolos/openssh.sh" ;;        
2) bash "$BASE/protocolos/zipvpn.sh" ;;        
3) bash "$BASE/protocolos/dropbear.sh" ;;        
4) bash "$BASE/protocolos/ssl.sh" ;;        
5) bash "$BASE/protocolos/badvpn.sh" ;;        
6) bash "$BASE/protocolos/udpcustom.sh" ;;        
7) bash "$BASE/protocolos/slowdns.sh" ;;        
8) bash "$BASE/protocolos/v2ray.sh" ;;        
9) bash "$BASE/protocolos/checkuser.sh" ;;        
        
10)    
clear    
echo "Instalando OpenVPN Pro..."    
bash <(curl -fsSL https://raw.githubusercontent.com/PhoenixxZ2023/OpenVPN/master/openvpn-install.sh)    
read -p "Presione ENTER para continuar..."    
bash "$BASE/protocolos/menu.sh"    
exit    
;;    
    
11)    
clear    
echo "Instalando WireGuard..."    
rm -f /tmp/wireguard-install.sh    
curl -fsSL -o /tmp/wireguard-install.sh https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh    
chmod +x /tmp/wireguard-install.sh    
bash /tmp/wireguard-install.sh    
read -p "Presione ENTER para continuar..."    
bash "$BASE/protocolos/menu.sh"    
exit    
;;    
    
12)    
clear    
echo "Instalando Hysteria Evozi V2..."    
wget -qO /tmp/hysteria2.sh https://raw.githubusercontent.com/evozi/hysteria-install/main/hy2/hysteria2.sh    
bash /tmp/hysteria2.sh    
read -p "Presione ENTER para continuar..."    
bash "$BASE/protocolos/menu.sh"    
exit    
;;    
    
13)    
clear    
echo "Instalando Hysteria 2025..."    
bash <(curl -fsSL https://raw.githubusercontent.com/ReturnFI/Hysteria2/main/install.sh)    
read -p "Presione ENTER para continuar..."    
bash "$BASE/protocolos/menu.sh"    
exit    
;;    
    
14)    
clear    
echo "Instalando Hysteria Pro..."    
wget -qO /tmp/install.sh https://github.com/thefather12/UDPHISTERIA/raw/main/install.sh    
chmod +x /tmp/install.sh    
bash /tmp/install.sh    
read -p "Presione ENTER para continuar..."    
bash "$BASE/protocolos/menu.sh"    
exit    
;;    
    
15)    
clear    
echo "Instalando UDPMOD Hysteria..."    
wget -qO /tmp/install.sh https://github.com/PhoenixxZ2023/UDPMOD/raw/main/install.sh    
chmod +x /tmp/install.sh    
bash /tmp/install.sh    
read -p "Presione ENTER para continuar..."    
bash "$BASE/protocolos/menu.sh"    
exit    
;;    
        
16) bash "$BASE/herramientas/menu.sh" ;;        
17) bash "$BASE/herramientas/reiniciar.sh" ;;        
18) bash "$BASE/herramientas/firewall.sh" ;;        
        
0) exec bash "$BASE/menu.sh" ;;                  
*)                      
echo "❌ Opción inválida."                      
sleep 2                      
exec bash "$BASE/protocolos/menu.sh"                      
;;                      
esac
