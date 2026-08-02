#!/bin/bash
#==================================================
# KevinTech Multi Script
# UDP & VPN Manager
# Compatible: Ubuntu
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"

# Colores
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

#=========================
# Funciones de mensajes
#=========================

msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

msg_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

pause() {
    echo
    read -rp "Presione ENTER para continuar..."
}

#=========================
# Verificar Ubuntu
#=========================

check_system() {
    if [[ ! -f /etc/os-release ]]; then
        msg_error "No se pudo detectar el sistema operativo."
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        msg_error "Este módulo solo es compatible con Ubuntu."
        exit 1
    fi
}

#=========================
# Cabecera
#=========================

header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           KevinTech Multi Script            ║${NC}"
    echo -e "${CYAN}║              UDP & VPN Manager              ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE} Sistema : ${GREEN}Ubuntu${NC}"
    echo -e "${WHITE} Estado  : ${GREEN}Disponible${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo
}

#=========================
# Menú principal
#=========================

udp_vpn_menu() {
    check_system

    while true; do
        header

        echo -e "${GREEN}[01]${NC} Instalar UDP-Custom"
        echo -e "${GREEN}[02]${NC} Abrir menú UDP-Custom"
        echo -e "${GREEN}[03]${NC} Instalar SlowUDP Evozi"
        echo -e "${GREEN}[04]${NC} Instalar WireGuard"
        echo -e "${GREEN}[05]${NC} Instalar OpenVPN Pro"
        echo -e "${GREEN}[06]${NC} Instalar WS-EPro"
        echo -e "${GREEN}[07]${NC} Instalar Hysteria Evozi V2"
        echo -e "${GREEN}[08]${NC} Instalar Hysteria 2025"
        echo -e "${GREEN}[09]${NC} Instalar Hysteria Pro"
        echo -e "${GREEN}[10]${NC} Instalar UDPMOD Hysteria"
        echo -e "${RED}[00]${NC} Volver"

        echo
        read -rp "Seleccione una opción: " opt

        case "$opt" in
            1|01)
                install_udp_custom
                ;;
            2|02)
                open_udp_custom
                ;;
            3|03)
                install_slowudp
                ;;
            4|04)
                install_wireguard
                ;;
            5|05)
                install_openvpn
                ;;
            6|06)
                install_ws_epro
                ;;
            7|07)
                install_hysteria_v2
                ;;
            8|08)
                install_hysteria2025
                ;;
            9|09)
                install_hysteria_pro
                ;;
            10)
                install_udpmod
                ;;
            0|00)
                return
                ;;
            *)
                msg_error "Opción inválida."
                sleep 2
                ;;
        esac
    done
}

#==================================================
# UDP-CUSTOM
#==================================================

install_udp_custom() {
    header
    msg_info "Instalando UDP-Custom..."

    rm -f /tmp/install.sh

    wget -qO /tmp/install.sh \
    https://raw.githubusercontent.com/thefather12/UDP-PRO/main/install.sh

    if [[ $? -ne 0 ]]; then
        msg_error "No se pudo descargar el instalador."
        pause
        return
    fi

    chmod +x /tmp/install.sh
    bash /tmp/install.sh

    pause
}

open_udp_custom() {
    header

    if command -v udp >/dev/null 2>&1; then
        udp
    else
        msg_error "UDP-Custom no está instalado."
        pause
    fi
}

#==================================================
# SLOW UDP EVOZI
#==================================================

install_slowudp() {
    header
    msg_info "Instalando SlowUDP Evozi..."

    rm -f /tmp/slowudp.sh

    wget -qO /tmp/slowudp.sh \
    https://raw.githubusercontent.com/evozi/hysteria-install/main/slowudp/slowudp.sh

    if [[ $? -ne 0 ]]; then
        msg_error "No se pudo descargar SlowUDP."
        pause
        return
    fi

    bash /tmp/slowudp.sh

    pause
}
#==================================================
# WIREGUARD
#==================================================

install_wireguard() {
    header
    msg_info "Instalando WireGuard..."

    rm -f /tmp/wireguard-install.sh

    curl -fsSL -o /tmp/wireguard-install.sh \
        https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh

    if [[ $? -ne 0 ]]; then
        msg_error "No se pudo descargar el instalador de WireGuard."
        pause
        return
    fi

    chmod +x /tmp/wireguard-install.sh
    bash /tmp/wireguard-install.sh

    pause
}

#==================================================
# OPENVPN PRO
#==================================================

install_openvpn() {
    header
    msg_info "Instalando OpenVPN Pro..."

    bash <(
        curl -fsSL \
        https://raw.githubusercontent.com/PhoenixxZ2023/OpenVPN/master/openvpn-install.sh
    )

    if [[ $? -eq 0 ]]; then
        msg_ok "OpenVPN instalado correctamente."
    else
        msg_error "La instalación de OpenVPN falló."
    fi

    pause
}

#==================================================
# WS-EPRO
#==================================================

install_ws_epro() {
    header
    msg_info "Instalando WS-EPro..."

    bash <(
        curl -fsSL \
        https://raw.githubusercontent.com/PhoenixxZ2023/ws-epro/main/install.sh
    )

    if [[ $? -eq 0 ]]; then
        msg_ok "WS-EPro instalado correctamente."
    else
        msg_error "La instalación de WS-EPro falló."
    fi

    pause
}
#==================================================
# HYSTERIA EVOZI V2
#==================================================

install_hysteria_v2() {
    header
    msg_info "Instalando Hysteria Evozi V2..."

    rm -f /tmp/hysteria2.sh

    wget -qO /tmp/hysteria2.sh \
        https://raw.githubusercontent.com/evozi/hysteria-install/main/hy2/hysteria2.sh

    if [[ $? -ne 0 ]]; then
        msg_error "No se pudo descargar Hysteria Evozi V2."
        pause
        return
    fi

    bash /tmp/hysteria2.sh

    if [[ $? -eq 0 ]]; then
        msg_ok "Hysteria Evozi V2 instalado correctamente."
    else
        msg_error "La instalación falló."
    fi

    pause
}

#==================================================
# HYSTERIA 2025
#==================================================

install_hysteria2025() {
    header
    msg_info "Instalando Hysteria 2025..."

    bash <(
        curl -fsSL \
        https://raw.githubusercontent.com/ReturnFI/Hysteria2/main/install.sh
    )

    if [[ $? -eq 0 ]]; then
        msg_ok "Hysteria 2025 instalado correctamente."
    else
        msg_error "La instalación falló."
    fi

    pause
}

#==================================================
# HYSTERIA PRO
#==================================================

install_hysteria_pro() {
    header
    msg_info "Instalando Hysteria Pro..."

    rm -f /tmp/install.sh

    wget -qO /tmp/install.sh \
        https://github.com/thefather12/UDPHISTERIA/raw/main/install.sh

    if [[ $? -ne 0 ]]; then
        msg_error "No se pudo descargar Hysteria Pro."
        pause
        return
    fi

    chmod +x /tmp/install.sh
    bash /tmp/install.sh

    if [[ $? -eq 0 ]]; then
        msg_ok "Hysteria Pro instalado correctamente."
    else
        msg_error "La instalación falló."
    fi

    pause
}
#==================================================
# UDPMOD HYSTERIA (V1/V2)
#==================================================

install_udpmod() {
    header
    msg_info "Instalando UDPMOD Hysteria..."

    rm -f /tmp/install.sh

    wget -qO /tmp/install.sh \
        https://github.com/PhoenixxZ2023/UDPMOD/raw/main/install.sh

    if [[ $? -ne 0 ]]; then
        msg_error "No se pudo descargar UDPMOD."
        pause
        return
    fi

    chmod +x /tmp/install.sh
    bash /tmp/install.sh

    if [[ $? -eq 0 ]]; then
        msg_ok "UDPMOD instalado correctamente."
    else
        msg_error "La instalación falló."
    fi

    rm -f /tmp/install.sh

    pause
}

#==================================================
# LIMPIEZA
#==================================================

cleanup_udp_vpn() {
    rm -f \
        /tmp/install.sh \
        /tmp/slowudp.sh \
        /tmp/hysteria2.sh \
        /tmp/wireguard-install.sh
}

#==================================================
# INICIO DEL MÓDULO
#==================================================

cleanup_udp_vpn
udp_vpn_menu
