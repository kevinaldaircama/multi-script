#!/bin/bash

#==================================================
# KevinTech Multi Script Premium
# SlowDNS + DNSDist Manager
# Compatible:
# • HTTP Injector
# • HTTP Custom
# • UDP Custom
# • TLS Tunnel
#==================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] || {
    echo "❌ No existe $CONFIG"
    exit 1
}

source "$CONFIG"

CYAN="\e[1;96m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
WHITE="\e[1;97m"
RESET="\e[0m"

SERVICE="slowdns"
DNSDIST="dnsdist"

DIR="/etc/slowdns"

BIN="/usr/bin/slowdns-server"

PUBKEY="$DIR/server.pub"
PRIVKEY="$DIR/server.key"

DOMAIN_FILE="$DIR/domain.conf"

DNS_PORT="53"
SLOWDNS_PORT="5300"

STATUS=""
#==================================================
# Instalar dependencias
#==================================================

install_dependencies(){

    echo "📦 Instalando dependencias..."

    apt update -y

    apt install -y \
        curl \
        wget \
        dnsdist \
        iptables \
        dnsutils \
        ca-certificates

    mkdir -p "$DIR"

}

#==================================================
# Descargar SlowDNS Server
#==================================================

install_slowdns_binary(){

    ARCH=$(uname -m)

    case "$ARCH" in

        x86_64)
            URL="https://dnstt.network/dnstt-server-linux-amd64"
        ;;

        aarch64|arm64)
            URL="https://dnstt.network/dnstt-server-linux-arm64"
        ;;

        *)
            echo "❌ Arquitectura no soportada: $ARCH"
            return 1
        ;;

    esac

    echo ""
    echo "⬇️ Descargando SlowDNS Server..."

    rm -f "$BIN"

    curl -L --fail "$URL" -o "$BIN"

    if [[ ! -f "$BIN" ]]; then
        echo "❌ Error descargando SlowDNS."
        return 1
    fi

    chmod +x "$BIN"

}

#==================================================
# Generar claves
#==================================================

generate_keys(){

    echo "🔑 Generando claves..."

    if [[ ! -f "$PUBKEY" || ! -f "$PRIVKEY" ]]; then

        "$BIN" \
            -gen-key \
            -privkey-file "$PRIVKEY" \
            -pubkey-file "$PUBKEY"

    fi

}
#==================================================
# Configurar DNSDist
#==================================================

configure_dnsdist(){

    echo "⚙️ Configurando DNSDist..."

    mkdir -p /etc/dnsdist

    cat > /etc/dnsdist/dnsdist.conf <<EOF
-- KevinTech Multi Script Premium

setLocal("0.0.0.0:53")
setLocal("[::]:53")

addACL("0.0.0.0/0")
addACL("::/0")

newServer({
    address="127.0.0.1:5300",
    name="slowdns"
})
EOF

    systemctl daemon-reload
    systemctl enable dnsdist

}

#==================================================
# Crear servicio SlowDNS
#==================================================

create_slowdns_service(){

    DOMAIN=$(cat "$DOMAIN_FILE")

    cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=KevinTech SlowDNS Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN -udp :5300 -privkey-file $PRIVKEY $DOMAIN 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable slowdns

}

#==================================================
# Abrir puerto DNS
#==================================================

open_dns_port(){

    iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p udp --dport 53 -j ACCEPT

    iptables -C INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport 53 -j ACCEPT

}
#==================================================
# Instalar SlowDNS
#==================================================

install_slowdns(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🚀 INSTALAR SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "🌐 Dominio NS (Ej: ns.midominio.com): " DOMAIN

    [[ -z "$DOMAIN" ]] && {
        echo "❌ Dominio inválido."
        sleep 2
        return
    }

    install_dependencies || return

    install_slowdns_binary || return

    mkdir -p "$DIR"

    echo "$DOMAIN" > "$DOMAIN_FILE"

    generate_keys || return

    configure_dnsdist

    create_slowdns_service

    open_dns_port

    echo ""
    echo "🔄 Iniciando servicios..."

    systemctl daemon-reload

    systemctl enable dnsdist
    systemctl enable slowdns

    systemctl restart dnsdist
    systemctl restart slowdns

    sleep 3

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns
    then

        sed -i '/^SLOWDNS=/d' "$CONFIG"
        echo "SLOWDNS=ON" >> "$CONFIG"

        source "$CONFIG"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "      ✅ SLOWDNS INSTALADO"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌐 Dominio : $(cat "$DOMAIN_FILE")"
        echo ""
        echo "🔑 Public Key:"
        cat "$PUBKEY"
        echo ""
        echo "🌍 DNS : 53"
        echo "🐌 DNSTT : 5300"
        echo ""

    else

        echo ""
        echo "❌ Error iniciando SlowDNS"
        echo ""

        systemctl status slowdns --no-pager
        echo ""
        systemctl status dnsdist --no-pager

    fi

    sleep 4

}
#==================================================
# Eliminar SlowDNS
#==================================================

remove_slowdns(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}        🗑 ELIMINAR SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    read -rp "¿Eliminar SlowDNS? (s/n): " R

    [[ ! "$R" =~ ^[Ss]$ ]] && return

    systemctl stop slowdns 2>/dev/null
    systemctl stop dnsdist 2>/dev/null

    systemctl disable slowdns 2>/dev/null
    systemctl disable dnsdist 2>/dev/null

    rm -f /etc/systemd/system/slowdns.service
    rm -f /etc/dnsdist/dnsdist.conf

    rm -rf "$DIR"

    rm -f "$BIN"

    systemctl daemon-reload

    iptables -D INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null

    sed -i '/^SLOWDNS=/d' "$CONFIG"
    echo "SLOWDNS=OFF" >> "$CONFIG"

    source "$CONFIG"

    echo ""
    echo "✅ SlowDNS eliminado."

    sleep 3

}

#==================================================
# Reiniciar servicios
#==================================================

restart_slowdns(){

    clear

    echo "🔄 Reiniciando servicios..."

    systemctl restart dnsdist
    systemctl restart slowdns

    sleep 2

    if systemctl is-active --quiet dnsdist && \
       systemctl is-active --quiet slowdns
    then
        echo ""
        echo "✅ Servicios activos."
    else
        echo ""
        echo "❌ Error al reiniciar."
    fi

    sleep 3

}

#==================================================
# Estado
#==================================================

status_slowdns(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}         📊 ESTADO SLOWDNS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo ""
    systemctl status slowdns --no-pager

    echo ""
    systemctl status dnsdist --no-pager

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo "Puertos abiertos:"
    ss -ulnp | grep -E "53|5300" || true

    echo ""
    echo "Dominio:"
    [[ -f "$DOMAIN_FILE" ]] && cat "$DOMAIN_FILE"

    echo ""
    echo "Public Key:"
    [[ -f "$PUBKEY" ]] && cat "$PUBKEY"

    echo ""
    read -n1 -r -p "Presione una tecla..."

}

#==================================================
# Mostrar Public Key
#==================================================

show_key(){

    clear

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}          🔑 PUBLIC KEY${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if [[ -f "$PUBKEY" ]]; then
        cat "$PUBKEY"
    else
        echo "❌ No existe la Public Key."
    fi

    echo ""
    read -n1 -r -p "Presione una tecla..."

}
#==================================================
# Menú Principal
#==================================================

while true
do

    clear

    source "$CONFIG"

    if systemctl is-active --quiet slowdns; then
        STATUS="${GREEN}🟢 ACTIVO${RESET}"
    else
        STATUS="${RED}🔴 DETENIDO${RESET}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}           🐌 SLOWDNS MANAGER${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e " Estado      : $STATUS"
    echo -e " Puerto DNS  : 53"
    echo -e " DNSTT       : 5300"

    if [[ -f "$DOMAIN_FILE" ]]; then
        echo -e " Dominio NS  : ${YELLOW}$(cat "$DOMAIN_FILE")${RESET}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ "$SLOWDNS" == "ON" ]]; then

cat <<EOF

 [1] ➮ Desinstalar SlowDNS
 [2] ➮ Reiniciar Servicios
 [3] ➮ Ver Estado
 [4] ➮ Ver Public Key

 [0] ➮ Regresar

EOF

    else

cat <<EOF

 [1] ➮ Instalar SlowDNS

 [0] ➮ Regresar

EOF

    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    read -rp " ► Opción: " OP

    case "$OP" in

        1)

            if [[ "$SLOWDNS" == "ON" ]]; then
                remove_slowdns
            else
                install_slowdns
            fi

        ;;

        2)

            [[ "$SLOWDNS" == "ON" ]] && restart_slowdns

        ;;

        3)

            [[ "$SLOWDNS" == "ON" ]] && status_slowdns

        ;;

        4)

            [[ "$SLOWDNS" == "ON" ]] && show_key

        ;;

        0)

            exec bash "$BASE/protocolos/menu.sh"

        ;;

        *)

            echo ""
            echo "❌ Opción inválida."
            sleep 2

        ;;

    esac

done
