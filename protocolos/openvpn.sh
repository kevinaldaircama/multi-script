#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    OPENVPN MANAGER
#                         v3.0
# ==============================================================
# Compatible con:
# • Ubuntu
# • KevinTech Multi Script
# • Instalación automática --auto
#
# Puerto por defecto : 1194
# Protocolo           : TCP
# Red VPN             : 10.8.0.0/24
# Configuración       : /etc/kevintech/config.conf
# ==============================================================

set -o pipefail

# ==============================================================
# VARIABLES
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

VERSION="3.0"

OPENVPN_DIR="/etc/openvpn/server"
EASYRSA_DIR="$OPENVPN_DIR/easy-rsa"

SERVICE="openvpn-server@server.service"
IPTABLES_SERVICE="openvpn-iptables.service"

SERVER_CONF="$OPENVPN_DIR/server.conf"
CLIENT_COMMON="$OPENVPN_DIR/client-common.txt"
TC_KEY="$OPENVPN_DIR/tc.key"
CRL_FILE="$OPENVPN_DIR/crl.pem"

PORT="${OPENVPN_PORT:-1194}"
PROTOCOL="${OPENVPN_PROTOCOL:-tcp}"
VPN_NETWORK="10.8.0.0"
VPN_NETMASK="255.255.255.0"

CLIENT_DEFAULT="client"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

if [[ -f "$CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null
fi

SERVER_DOMAIN="${SERVER_DOMAIN:-}"

# ==============================================================
# FUNCIONES
# ==============================================================

clear_screen() {
    clear 2>/dev/null || true
}

line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

title() {

    clear_screen

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🛡️ KEVINTECH OPENVPN${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                 ${GRAY}VPN MANAGER v${VERSION}${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

section() {

    echo
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${MAGENTA}║${RESET} ${WHITE}${BOLD}$1${RESET}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

}

ok() {
    echo -e "${GREEN}✔${RESET} $1"
}

error_msg() {
    echo -e "${RED}✘${RESET} $1"
}

warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

info() {
    echo -e "${CYAN}➜${RESET} $1"
}

pause() {
    echo
    read -r -p "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

# ==============================================================
# ROOT
# ==============================================================

check_root() {

    if [[ "$EUID" -ne 0 ]]; then
        error_msg "Este administrador requiere permisos de root."
        return 1
    fi

    return 0
}

# ==============================================================
# CONFIG
# ==============================================================

set_config() {

    local KEY="$1"
    local VALUE="$2"

    [[ ! -f "$CONFIG" ]] && return 1

    if grep -q "^${KEY}=" "$CONFIG"; then

        sed -i \
            "s|^${KEY}=.*|${KEY}=${VALUE}|" \
            "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi
}

# ==============================================================
# COMPROBAR UBUNTU
# ==============================================================

check_ubuntu() {

    [[ ! -f /etc/os-release ]] && {
        error_msg "No se pudo detectar el sistema operativo."
        return 1
    }

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        error_msg "KevinTech OpenVPN requiere Ubuntu."
        return 1
    fi

    return 0
}

# ==============================================================
# COMPROBAR TUN
# ==============================================================

check_tun() {

    if [[ ! -e /dev/net/tun ]]; then
        error_msg "El dispositivo TUN no existe."
        echo
        echo -e "${YELLOW}Activa TUN en tu VPS antes de instalar OpenVPN.${RESET}"
        return 1
    fi

    if ! (exec 7<>/dev/net/tun) 2>/dev/null; then
        error_msg "No se puede acceder al dispositivo TUN."
        return 1
    fi

    exec 7>&-

    return 0
}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudieron actualizar los repositorios."
        return 1
    fi

    info "Instalando dependencias..."

    if ! apt-get install -y \
        openvpn \
        openssl \
        ca-certificates \
        iptables \
        curl \
        wget \
        tar \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    if ! command -v openvpn >/dev/null 2>&1; then
        error_msg "OpenVPN no quedó instalado."
        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# OBTENER IP DEL SERVIDOR
# ==============================================================

get_server_ip() {

    local IP=""

    IP="$(
        curl \
            -4 \
            --silent \
            --connect-timeout 5 \
            --max-time 10 \
            https://api.ipify.org \
            2>/dev/null
    )"

    if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$IP"
        return 0
    fi

    ip -4 route get 1.1.1.1 2>/dev/null |
        awk '
            /src/ {
                for(i=1;i<=NF;i++)
                    if($i=="src")
                        print $(i+1)
            }
        ' |
        head -n1
}

# ==============================================================
# OBTENER INTERFAZ
# ==============================================================

get_interface() {

    ip route get 1.1.1.1 2>/dev/null |
        awk '
            /dev/ {
                for(i=1;i<=NF;i++)
                    if($i=="dev")
                        print $(i+1)
            }
        ' |
        head -n1
}

# ==============================================================
# COMPROBAR PUERTO
# ==============================================================

port_available() {

    local P="$1"

    if ss -H -lntup 2>/dev/null |
        awk -v p=":$P" '$0 ~ p"([[:space:]]|$)"' |
        grep -q .; then

        return 1
    fi

    return 0
}

# ==============================================================
# DESCARGAR EASY-RSA
# ==============================================================

install_easy_rsa() {

    local URL

    URL="https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.1/EasyRSA-3.2.1.tgz"

    info "Instalando Easy-RSA..."

    rm -rf "$EASYRSA_DIR"

    mkdir -p "$EASYRSA_DIR"

    if ! {
        wget -qO- "$URL" 2>/dev/null ||
        curl -fsSL "$URL"
    } |
        tar xz \
            -C "$EASYRSA_DIR" \
            --strip-components=1; then

        error_msg "No se pudo descargar Easy-RSA."
        return 1
    fi

    if [[ ! -x "$EASYRSA_DIR/easyrsa" ]]; then
        error_msg "Easy-RSA no quedó instalado correctamente."
        return 1
    fi

    chown -R root:root "$EASYRSA_DIR"

    ok "Easy-RSA instalado."

    return 0
}

# ==============================================================
# CREAR PKI
# ==============================================================

create_pki() {

    cd "$EASYRSA_DIR" || return 1

    info "Creando PKI..."

    ./easyrsa --batch init-pki >/dev/null 2>&1 ||
        return 1

    info "Generando autoridad certificadora..."

    ./easyrsa \
        --batch \
        build-ca nopass \
        >/dev/null 2>&1 ||
        return 1

    info "Generando certificado del servidor..."

    ./easyrsa \
        --batch \
        --days=3650 \
        build-server-full server nopass \
        >/dev/null 2>&1 ||
        return 1

    info "Generando CRL..."

    ./easyrsa \
        --batch \
        --days=3650 \
        gen-crl \
        >/dev/null 2>&1 ||
        return 1

    cp pki/ca.crt "$OPENVPN_DIR/"
    cp pki/private/ca.key "$OPENVPN_DIR/"
    cp pki/issued/server.crt "$OPENVPN_DIR/"
    cp pki/private/server.key "$OPENVPN_DIR/"
    cp pki/crl.pem "$CRL_FILE"

    chown root:root \
        "$OPENVPN_DIR/ca.crt" \
        "$OPENVPN_DIR/ca.key" \
        "$OPENVPN_DIR/server.crt" \
        "$OPENVPN_DIR/server.key" \
        "$CRL_FILE"

    chown nobody:nogroup "$CRL_FILE" 2>/dev/null || true

    chmod 600 "$OPENVPN_DIR/ca.key"
    chmod 600 "$OPENVPN_DIR/server.key"
    chmod 644 "$OPENVPN_DIR/ca.crt"
    chmod 644 "$OPENVPN_DIR/server.crt"

    chmod 644 "$CRL_FILE"

    ok "PKI creada correctamente."

    return 0
}

# ==============================================================
# TLS CRYPT
# ==============================================================

generate_tls_key() {

    info "Generando clave TLS..."

    if ! openvpn \
        --genkey secret "$TC_KEY" \
        >/dev/null 2>&1; then

        error_msg "No se pudo generar la clave TLS."
        return 1
    fi

    chmod 600 "$TC_KEY"

    ok "TLS-Crypt activado."

    return 0
}

# ==============================================================
# CONFIGURAR OPENVPN
# ==============================================================

create_server_config() {

    local SERVER_IP="$1"

    info "Creando server.conf..."

    cat > "$SERVER_CONF" <<EOF
# ==========================================================
# KevinTech Multi Script - OpenVPN
# ==========================================================

port $PORT
proto $PROTOCOL

dev tun

ca ca.crt
cert server.crt
key server.key
dh none

topology subnet

server $VPN_NETWORK $VPN_NETMASK

ifconfig-pool-persist ipp.txt

push "redirect-gateway def1 bypass-dhcp"

push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"

auth SHA256

tls-crypt tc.key

keepalive 10 120

user nobody
group nogroup

persist-key
persist-tun

status openvpn-status.log

verb 3

crl-verify crl.pem

client-to-client

duplicate-cn

EOF

    if [[ "$PROTOCOL" == "udp" ]]; then
        echo "explicit-exit-notify" >> "$SERVER_CONF"
    fi

    chmod 644 "$SERVER_CONF"

    ok "Configuración del servidor creada."

    return 0
}

# ==============================================================
# CONFIGURAR FORWARDING
# ==============================================================

configure_forwarding() {

    info "Activando IP forwarding..."

    cat > /etc/sysctl.d/99-kevintech-openvpn.conf <<'EOF'
net.ipv4.ip_forward=1
EOF

    sysctl --system >/dev/null 2>&1 || true

    echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

    ok "IP forwarding activado."
}

# ==============================================================
# CREAR SERVICIO IPTABLES
# ==============================================================

create_iptables_service() {

    local SERVER_IP="$1"
    local DEV="$2"
    local IPTABLES

    IPTABLES="$(command -v iptables)"

    [[ -z "$IPTABLES" ]] && {
        error_msg "No se encontró iptables."
        return 1
    }

    info "Configurando NAT..."

    cat > "/etc/systemd/system/$IPTABLES_SERVICE" <<EOF
[Unit]
Description=KevinTech OpenVPN Firewall
Before=openvpn-server@server.service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot

ExecStart=$IPTABLES -t nat -C POSTROUTING -s $VPN_NETWORK/24 ! -d $VPN_NETWORK/24 -o $DEV -j MASQUERADE
ExecStart=$IPTABLES -t nat -A POSTROUTING -s $VPN_NETWORK/24 ! -d $VPN_NETWORK/24 -o $DEV -j MASQUERADE

ExecStart=$IPTABLES -C INPUT -p $PROTOCOL --dport $PORT -j ACCEPT
ExecStart=$IPTABLES -I INPUT -p $PROTOCOL --dport $PORT -j ACCEPT

ExecStart=$IPTABLES -C FORWARD -s $VPN_NETWORK/24 -j ACCEPT
ExecStart=$IPTABLES -I FORWARD -s $VPN_NETWORK/24 -j ACCEPT

ExecStart=$IPTABLES -C FORWARD -d $VPN_NETWORK/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ExecStart=$IPTABLES -I FORWARD -d $VPN_NETWORK/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

RemainAfterExit=yes

ExecStop=$IPTABLES -t nat -D POSTROUTING -s $VPN_NETWORK/24 ! -d $VPN_NETWORK/24 -o $DEV -j MASQUERADE
ExecStop=$IPTABLES -D INPUT -p $PROTOCOL --dport $PORT -j ACCEPT
ExecStop=$IPTABLES -D FORWARD -s $VPN_NETWORK/24 -j ACCEPT
ExecStop=$IPTABLES -D FORWARD -d $VPN_NETWORK/24 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable "$IPTABLES_SERVICE" >/dev/null 2>&1

    # Las reglas ExecStart -C pueden impedir que systemd continúe.
    # Aplicamos las reglas de forma idempotente aquí.
    iptables -t nat -C POSTROUTING \
        -s "$VPN_NETWORK/24" \
        ! -d "$VPN_NETWORK/24" \
        -o "$DEV" \
        -j MASQUERADE \
        2>/dev/null ||
    iptables -t nat -A POSTROUTING \
        -s "$VPN_NETWORK/24" \
        ! -d "$VPN_NETWORK/24" \
        -o "$DEV" \
        -j MASQUERADE

    iptables -C INPUT \
        -p "$PROTOCOL" \
        --dport "$PORT" \
        -j ACCEPT \
        2>/dev/null ||
    iptables -I INPUT \
        -p "$PROTOCOL" \
        --dport "$PORT" \
        -j ACCEPT

    iptables -C FORWARD \
        -s "$VPN_NETWORK/24" \
        -j ACCEPT \
        2>/dev/null ||
    iptables -I FORWARD \
        -s "$VPN_NETWORK/24" \
        -j ACCEPT

    iptables -C FORWARD \
        -d "$VPN_NETWORK/24" \
        -m conntrack \
        --ctstate RELATED,ESTABLISHED \
        -j ACCEPT \
        2>/dev/null ||
    iptables -I FORWARD \
        -d "$VPN_NETWORK/24" \
        -m conntrack \
        --ctstate RELATED,ESTABLISHED \
        -j ACCEPT

    systemctl start "$IPTABLES_SERVICE" >/dev/null 2>&1 || true

    ok "NAT configurado."

    return 0
}

# ==============================================================
# CLIENT COMMON
# ==============================================================

create_client_common() {

    local DOMAIN="$1"

    info "Creando plantilla de clientes..."

    cat > "$CLIENT_COMMON" <<EOF
client
dev tun
proto $PROTOCOL
remote $DOMAIN $PORT

resolv-retry infinite
nobind

persist-key
persist-tun

remote-cert-tls server

auth SHA256

ignore-unknown-option block-outside-dns

auth-user-pass

verb 3
EOF

    chmod 644 "$CLIENT_COMMON"

    ok "Plantilla de cliente creada."
}

# ==============================================================
# GENERAR CLIENTE
# ==============================================================

new_client() {

    local CLIENT="$1"

    [[ -z "$CLIENT" ]] && return 1

    if [[ ! -f "$EASYRSA_DIR/pki/issued/$CLIENT.crt" ]]; then
        error_msg "El certificado del cliente no existe."
        return 1
    fi

    {
        cat "$CLIENT_COMMON"

        echo "<ca>"
        cat "$EASYRSA_DIR/pki/ca.crt"
        echo "</ca>"

        echo "<cert>"
        sed -ne '/BEGIN CERTIFICATE/,$ p' \
            "$EASYRSA_DIR/pki/issued/$CLIENT.crt"
        echo "</cert>"

        echo "<key>"
        cat "$EASYRSA_DIR/pki/private/$CLIENT.key"
        echo "</key>"

        echo "<tls-crypt>"
        cat "$TC_KEY"
        echo "</tls-crypt>"

    } > "/root/${CLIENT}.ovpn"

    chmod 600 "/root/${CLIENT}.ovpn"

    return 0
}

# ==============================================================
# CREAR PRIMER CLIENTE
# ==============================================================

create_client_certificate() {

    local CLIENT="$1"

    [[ -z "$CLIENT" ]] && CLIENT="$CLIENT_DEFAULT"

    CLIENT="$(
        printf '%s' "$CLIENT" |
        sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g'
    )"

    [[ -z "$CLIENT" ]] && CLIENT="$CLIENT_DEFAULT"

    if [[ -f "$EASYRSA_DIR/pki/issued/$CLIENT.crt" ]]; then
        error_msg "El cliente $CLIENT ya existe."
        return 1
    fi

    cd "$EASYRSA_DIR" || return 1

    info "Generando certificado para $CLIENT..."

    if ! ./easyrsa \
        --batch \
        --days=3650 \
        build-client-full "$CLIENT" nopass \
        >/dev/null 2>&1; then

        error_msg "No se pudo crear el cliente."
        return 1
    fi

    if ! new_client "$CLIENT"; then
        error_msg "No se pudo generar el archivo .ovpn."
        return 1
    fi

    ok "Cliente $CLIENT creado."

    return 0
}

# ==============================================================
# INSTALACIÓN COMPLETA
# ==============================================================

install_openvpn() {

    title

    section "🚀 INSTALACIÓN DE OPENVPN"

    if [[ -f "$SERVER_CONF" ]] &&
       systemctl is-enabled "$SERVICE" >/dev/null 2>&1; then

        warning "OpenVPN ya parece estar instalado."
        pause
        return 0
    fi

    check_root || return 1
    check_ubuntu || return 1
    check_tun || return 1

    # ----------------------------------------------------------
    # DOMINIO
    # ----------------------------------------------------------

    if [[ -z "$SERVER_DOMAIN" ]]; then

        echo -e "${WHITE}No existe un dominio configurado.${RESET}"
        echo

        read -r -p \
            "$(echo -e "${CYAN}🌐 Dominio para OpenVPN: ${RESET}")" \
            SERVER_DOMAIN

        SERVER_DOMAIN="$(
            printf '%s' "$SERVER_DOMAIN" |
            tr -d '[:space:]'
        )"

        if [[ -z "$SERVER_DOMAIN" ]]; then
            error_msg "El dominio no puede estar vacío."
            return 1
        fi
    fi

    # ----------------------------------------------------------
    # PUERTO
    # ----------------------------------------------------------

    if [[ ! "$PORT" =~ ^[0-9]+$ ]] ||
       (( PORT < 1 || PORT > 65535 )); then

        PORT="1194"
    fi

    if ! port_available "$PORT"; then
        error_msg "El puerto TCP $PORT ya está ocupado."
        return 1
    fi

    echo
    echo -e "${WHITE}Dominio : ${CYAN}$SERVER_DOMAIN${RESET}"
    echo -e "${WHITE}Puerto  : ${CYAN}$PORT${RESET}"
    echo -e "${WHITE}Proto   : ${CYAN}$PROTOCOL${RESET}"
    echo

    # ----------------------------------------------------------
    # DEPENDENCIAS
    # ----------------------------------------------------------

    install_dependencies || return 1

    mkdir -p "$OPENVPN_DIR"

    # ----------------------------------------------------------
    # EASY-RSA
    # ----------------------------------------------------------

    install_easy_rsa || return 1

    # ----------------------------------------------------------
    # PKI
    # ----------------------------------------------------------

    create_pki || {
        error_msg "No se pudo crear la PKI."
        return 1
    }

    # ----------------------------------------------------------
    # TLS
    # ----------------------------------------------------------

    generate_tls_key || return 1

    # ----------------------------------------------------------
    # IP
    # ----------------------------------------------------------

    local SERVER_IP
    SERVER_IP="$(get_server_ip)"

    if [[ -z "$SERVER_IP" ]]; then
        error_msg "No se pudo detectar la IP pública."
        return 1
    fi

    local DEV
    DEV="$(get_interface)"

    if [[ -z "$DEV" ]]; then
        error_msg "No se pudo detectar la interfaz de red."
        return 1
    fi

    ok "IP pública: $SERVER_IP"
    ok "Interfaz: $DEV"

    # ----------------------------------------------------------
    # CONFIG
    # ----------------------------------------------------------

    create_server_config "$SERVER_IP" || return 1

    configure_forwarding

    create_iptables_service \
        "$SERVER_IP" \
        "$DEV" || return 1

    create_client_common "$SERVER_DOMAIN" || return 1

    # ----------------------------------------------------------
    # SERVICIO
    # ----------------------------------------------------------

    info "Activando OpenVPN..."

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    if ! systemctl restart "$SERVICE"; then
        error_msg "No se pudo iniciar OpenVPN."
        journalctl -u "$SERVICE" -n 30 --no-pager
        return 1
    fi

    sleep 2

    if ! systemctl is-active --quiet "$SERVICE"; then

        error_msg "OpenVPN quedó detenido."

        echo
        journalctl -u "$SERVICE" -n 30 --no-pager

        return 1
    fi

    # ----------------------------------------------------------
    # CLIENTE INICIAL
    # ----------------------------------------------------------

    create_client_certificate "$CLIENT_DEFAULT" || {
        error_msg "OpenVPN inició, pero no se pudo crear el cliente inicial."
        return 1
    }

    # ----------------------------------------------------------
    # CONFIG KEVINTECH
    # ----------------------------------------------------------

    if [[ -f "$CONFIG" ]]; then

        set_config "OPENVPN" "ON"
        set_config "OPENVPN_PORT" "\"$PORT\""
        set_config "OPENVPN_PROTOCOL" "\"$PROTOCOL\""

        # Recargar
        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null

    fi

    # ----------------------------------------------------------
    # RESULTADO
    # ----------------------------------------------------------

    echo

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}             ${BOLD}✔ OPENVPN INSTALADO${RESET}                      ${GREEN}║${RESET}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${GREEN}║${RESET}  Dominio : ${CYAN}$SERVER_DOMAIN${RESET}"
    echo -e "${GREEN}║${RESET}  Puerto  : ${CYAN}$PORT${RESET}"
    echo -e "${GREEN}║${RESET}  Protocolo: ${CYAN}$PROTOCOL${RESET}"
    echo -e "${GREEN}║${RESET}  Red VPN : ${CYAN}$VPN_NETWORK/24${RESET}"
    echo -e "${GREEN}║${RESET}  Cliente : ${CYAN}$CLIENT_DEFAULT${RESET}"
    echo -e "${GREEN}║${RESET}  Archivo : ${CYAN}/root/${CLIENT_DEFAULT}.ovpn${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    return 0
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_openvpn() {

    title

    if [[ ! -f "$SERVER_CONF" ]]; then
        error_msg "OpenVPN no está instalado."
        pause
        return
    fi

    info "Reiniciando firewall..."

    systemctl restart "$IPTABLES_SERVICE" >/dev/null 2>&1 || true

    info "Reiniciando OpenVPN..."

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then
        ok "OpenVPN está funcionando correctamente."
    else
        error_msg "OpenVPN no pudo reiniciarse."
        journalctl -u "$SERVICE" -n 20 --no-pager
    fi

    pause
}

# ==============================================================
# LISTAR CLIENTES
# ==============================================================

list_clients() {

    title

    if [[ ! -d "$EASYRSA_DIR/pki/issued" ]]; then
        error_msg "No existe la PKI."
        pause
        return
    fi

    section "👥 CLIENTES OPENVPN"

    local FOUND=0

    for CERT in "$EASYRSA_DIR"/pki/issued/*.crt; do

        [[ ! -f "$CERT" ]] && continue

        local NAME
        NAME="$(basename "$CERT" .crt)"

        [[ "$NAME" == "server" ]] && continue

        FOUND=1

        if grep -q "^V.*CN=$NAME" \
            "$EASYRSA_DIR/pki/index.txt" 2>/dev/null; then

            echo -e " ${GREEN}●${RESET} $NAME"

        else

            echo -e " ${RED}●${RESET} $NAME ${GRAY}(revocado)${RESET}"

        fi
    done

    if [[ "$FOUND" -eq 0 ]]; then
        echo -e "${GRAY}No existen clientes.${RESET}"
    fi

    pause
}

# ==============================================================
# CREAR CLIENTE
# ==============================================================

create_client_menu() {

    title

    if [[ ! -f "$SERVER_CONF" ]]; then
        error_msg "OpenVPN no está instalado."
        pause
        return
    fi

    section "👤 CREAR CLIENTE"

    read -r -p \
        "$(echo -e "${CYAN}Nombre del cliente: ${RESET}")" \
        CLIENT

    CLIENT="$(
        printf '%s' "$CLIENT" |
        sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g'
    )"

    if [[ -z "$CLIENT" ]]; then
        error_msg "Nombre inválido."
        pause
        return
    fi

    if [[ -f "$EASYRSA_DIR/pki/issued/$CLIENT.crt" ]]; then
        error_msg "Ese cliente ya existe."
        pause
        return
    fi

    if create_client_certificate "$CLIENT"; then

        echo
        ok "Cliente creado correctamente."
        echo
        echo -e "${WHITE}Archivo:${RESET}"
        echo -e "${CYAN}/root/${CLIENT}.ovpn${RESET}"

    fi

    pause
}

# ==============================================================
# REVOCAR CLIENTE
# ==============================================================

revoke_client() {

    title

    if [[ ! -f "$EASYRSA_DIR/pki/index.txt" ]]; then
        error_msg "No existe la PKI."
        pause
        return
    fi

    section "❌ REVOCAR CLIENTE"

    mapfile -t CLIENTS < <(
        awk -F'=' '
            $1 ~ /^V/ {
                sub(/^.*CN=/,"",$NF)
                print $NF
            }
        ' "$EASYRSA_DIR/pki/index.txt"
    )

    if [[ "${#CLIENTS[@]}" -eq 0 ]]; then
        warning "No existen clientes activos."
        pause
        return
    fi

    local I

    for I in "${!CLIENTS[@]}"; do
        printf " ${GREEN}[%02d]${RESET} %s\n" \
            "$((I+1))" \
            "${CLIENTS[$I]}"
    done

    echo

    read -r -p \
        "$(echo -e "${CYAN}Seleccione el cliente: ${RESET}")" \
        NUM

    if [[ ! "$NUM" =~ ^[0-9]+$ ]] ||
       (( NUM < 1 || NUM > ${#CLIENTS[@]} )); then

        error_msg "Selección inválida."
        pause
        return
    fi

    local CLIENT
    CLIENT="${CLIENTS[$((NUM-1))]}"

    echo

    read -r -p \
        "$(echo -e "${YELLOW}¿Revocar $CLIENT? [s/N]: ${RESET}")" \
        CONFIRM

    if [[ ! "$CONFIRM" =~ ^[SsYy]$ ]]; then
        warning "Operación cancelada."
        pause
        return
    fi

    cd "$EASYRSA_DIR" || return

    info "Revocando certificado..."

    if ! ./easyrsa \
        --batch \
        revoke "$CLIENT" \
        >/dev/null 2>&1; then

        error_msg "No se pudo revocar el cliente."
        pause
        return
    fi

    info "Regenerando CRL..."

    ./easyrsa \
        --batch \
        --days=3650 \
        gen-crl \
        >/dev/null 2>&1

    cp pki/crl.pem "$CRL_FILE"

    chown nobody:nogroup "$CRL_FILE" 2>/dev/null || true
    chmod 644 "$CRL_FILE"

    rm -f "/root/${CLIENT}.ovpn"

    systemctl restart "$SERVICE"

    ok "Cliente $CLIENT revocado correctamente."

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

status_openvpn() {

    title

    section "📊 ESTADO OPENVPN"

    echo -e "${WHITE}Servicio:${RESET}"

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "${GREEN}● ACTIVO${RESET}"
    else
        echo -e "${RED}● DETENIDO${RESET}"
    fi

    echo

    echo -e "${WHITE}Arranque automático:${RESET}"
    systemctl is-enabled "$SERVICE" 2>/dev/null || true

    echo

    echo -e "${WHITE}Puerto:${RESET} ${CYAN}$PORT${RESET}"
    echo -e "${WHITE}Protocolo:${RESET} ${CYAN}$PROTOCOL${RESET}"
    echo -e "${WHITE}Red VPN:${RESET} ${CYAN}$VPN_NETWORK/24${RESET}"

    echo

    echo -e "${WHITE}Puerto escuchando:${RESET}"

    ss -lntup 2>/dev/null |
        grep -E ":${PORT}[[:space:]]" ||
        echo -e "${RED}No está escuchando.${RESET}"

    echo

    echo -e "${WHITE}Clientes conectados:${RESET}"

    if [[ -f "$OPENVPN_DIR/openvpn-status.log" ]]; then

        grep '^CLIENT_LIST' \
            "$OPENVPN_DIR/openvpn-status.log" 2>/dev/null |
            wc -l

    else

        echo "0"

    fi

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostic_openvpn() {

    title

    section "🔎 DIAGNÓSTICO OPENVPN"

    if command -v openvpn >/dev/null 2>&1; then
        ok "Binario OpenVPN"
    else
        error_msg "Binario OpenVPN no encontrado"
    fi

    if [[ -f "$SERVER_CONF" ]]; then
        ok "server.conf"
    else
        error_msg "server.conf no encontrado"
    fi

    if [[ -f "$OPENVPN_DIR/ca.crt" ]]; then
        ok "Certificado CA"
    else
        error_msg "CA no encontrada"
    fi

    if [[ -f "$OPENVPN_DIR/server.crt" ]]; then
        ok "Certificado del servidor"
    else
        error_msg "Certificado del servidor no encontrado"
    fi

    if [[ -f "$OPENVPN_DIR/server.key" ]]; then
        ok "Clave del servidor"
    else
        error_msg "Clave del servidor no encontrada"
    fi

    if [[ -f "$TC_KEY" ]]; then
        ok "TLS-Crypt"
    else
        error_msg "TLS-Crypt no encontrado"
    fi

    if [[ -f "$CRL_FILE" ]]; then
        ok "CRL"
    else
        error_msg "CRL no encontrada"
    fi

    if [[ -e /dev/net/tun ]]; then
        ok "Dispositivo TUN"
    else
        error_msg "Dispositivo TUN"
    fi

    if systemctl is-active --quiet "$SERVICE"; then
        ok "Servicio OpenVPN activo"
    else
        error_msg "Servicio OpenVPN detenido"
    fi

    echo

    echo -e "${WHITE}Últimos registros:${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 15 \
        --no-pager \
        2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

view_logs() {

    title

    section "📜 LOGS OPENVPN"

    journalctl \
        -u "$SERVICE" \
        -n 50 \
        --no-pager

    pause
}

# ==============================================================
# INFORMACIÓN
# ==============================================================

system_info() {

    title

    section "🖥️ INFORMACIÓN DEL SERVIDOR"

    local HOST
    local IP
    local OS
    local KERNEL
    local CPU
    local RAM
    local DISK
    local UPTIME

    HOST="$(hostname)"

    IP="$(get_server_ip)"
    OS="$(
        grep '^PRETTY_NAME=' /etc/os-release |
        cut -d '"' -f2
    )"

    KERNEL="$(uname -r)"

    CPU="$(
        grep -m1 "model name" /proc/cpuinfo |
        cut -d: -f2 |
        sed 's/^ //'
    )"

    RAM="$(
        free -h |
        awk '/Mem:/ {print $3 " / " $2}'
    )"

    DISK="$(
        df -h / |
        awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}'
    )"

    UPTIME="$(uptime -p)"

    echo -e "${WHITE}Hostname :${RESET} ${GREEN}$HOST${RESET}"
    echo -e "${WHITE}Sistema  :${RESET} ${GREEN}$OS${RESET}"
    echo -e "${WHITE}Kernel   :${RESET} ${GREEN}$KERNEL${RESET}"
    echo -e "${WHITE}CPU      :${RESET} ${GREEN}${CPU:-Desconocida}${RESET}"
    echo -e "${WHITE}RAM      :${RESET} ${GREEN}${RAM:-Desconocida}${RESET}"
    echo -e "${WHITE}Disco    :${RESET} ${GREEN}${DISK:-Desconocido}${RESET}"
    echo -e "${WHITE}Uptime   :${RESET} ${GREEN}${UPTIME:-Desconocido}${RESET}"
    echo -e "${WHITE}IPv4     :${RESET} ${CYAN}${IP:-Desconocida}${RESET}"

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_openvpn() {

    title

    section "🗑️ DESINSTALAR OPENVPN"

    warning "Se eliminarán OpenVPN, certificados, clientes y reglas NAT."
    echo

    read -r -p \
        "$(echo -e "${RED}¿Continuar? [s/N]: ${RESET}")" \
        CONFIRM

    [[ ! "$CONFIRM" =~ ^[SsYy]$ ]] && {
        warning "Operación cancelada."
        pause
        return
    }

    local DEV
    DEV="$(get_interface)"

    info "Deteniendo OpenVPN..."

    systemctl disable --now "$SERVICE" 2>/dev/null || true
    systemctl disable --now "$IPTABLES_SERVICE" 2>/dev/null || true

    rm -f "/etc/systemd/system/$IPTABLES_SERVICE"
    rm -f "/etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf"

    # ----------------------------------------------------------
    # ELIMINAR REGLAS
    # ----------------------------------------------------------

    if [[ -n "$DEV" ]]; then

        while iptables -t nat -C POSTROUTING \
            -s "$VPN_NETWORK/24" \
            ! -d "$VPN_NETWORK/24" \
            -o "$DEV" \
            -j MASQUERADE \
            2>/dev/null; do

            iptables -t nat -D POSTROUTING \
                -s "$VPN_NETWORK/24" \
                ! -d "$VPN_NETWORK/24" \
                -o "$DEV" \
                -j MASQUERADE

        done

    fi

    while iptables -C INPUT \
        -p "$PROTOCOL" \
        --dport "$PORT" \
        -j ACCEPT \
        2>/dev/null; do

        iptables -D INPUT \
            -p "$PROTOCOL" \
            --dport "$PORT" \
            -j ACCEPT

    done

    while iptables -C FORWARD \
        -s "$VPN_NETWORK/24" \
        -j ACCEPT \
        2>/dev/null; do

        iptables -D FORWARD \
            -s "$VPN_NETWORK/24" \
            -j ACCEPT

    done

    while iptables -C FORWARD \
        -d "$VPN_NETWORK/24" \
        -m conntrack \
        --ctstate RELATED,ESTABLISHED \
        -j ACCEPT \
        2>/dev/null; do

        iptables -D FORWARD \
            -d "$VPN_NETWORK/24" \
            -m conntrack \
            --ctstate RELATED,ESTABLISHED \
            -j ACCEPT

    done

    # ----------------------------------------------------------
    # ARCHIVOS
    # ----------------------------------------------------------

    rm -rf "$OPENVPN_DIR"

    rm -rf /etc/openvpn

    # ----------------------------------------------------------
    # PAQUETE
    # ----------------------------------------------------------

    apt-get purge -y openvpn >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true

    # ----------------------------------------------------------
    # CONFIG KEVINTECH
    # ----------------------------------------------------------

    if [[ -f "$CONFIG" ]]; then

        set_config "OPENVPN" "OFF"

        sed -i \
            '/^OPENVPN_PORT=/d' \
            "$CONFIG"

        sed -i \
            '/^OPENVPN_PROTOCOL=/d' \
            "$CONFIG"

    fi

    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true

    ok "OpenVPN fue eliminado correctamente."

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}${BOLD}             🚀 INSTALACIÓN AUTOMÁTICA${RESET}"
    echo -e "${WHITE}                    OPENVPN${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    # Valores automáticos
    PORT="${OPENVPN_PORT:-1194}"
    PROTOCOL="${OPENVPN_PROTOCOL:-tcp}"

    if install_openvpn; then
        echo
        ok "OpenVPN instalado correctamente."
        exit 0
    else
        echo
        error_msg "La instalación automática de OpenVPN falló."
        exit 1
    fi

fi

# ==============================================================
# MENÚ
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then

    echo
    error_msg "No existe $CONFIG"
    exit 1

fi

while true; do

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    OPENVPN_STATUS="${OPENVPN:-OFF}"

    title

    echo -e "${WHITE}Estado:${RESET}"

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "${GREEN}● ACTIVO${RESET}"
    elif [[ "$OPENVPN_STATUS" == "ON" ]]; then
        echo -e "${RED}● DETENIDO${RESET}"
    else
        echo -e "${GRAY}● NO INSTALADO${RESET}"
    fi

    echo

    echo -e "${WHITE}Dominio:${RESET} ${CYAN}${SERVER_DOMAIN:-No configurado}${RESET}"
    echo -e "${WHITE}Puerto:${RESET} ${CYAN}${OPENVPN_PORT:-1194}${RESET}"
    echo -e "${WHITE}Protocolo:${RESET} ${CYAN}${OPENVPN_PROTOCOL:-tcp}${RESET}"
    echo -e "${WHITE}Red VPN:${RESET} ${CYAN}${VPN_NETWORK}/24${RESET}"

    line

    if [[ "$OPENVPN_STATUS" == "ON" ]] &&
       [[ -f "$SERVER_CONF" ]]; then

        echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN OPENVPN${RESET}"
        echo

        echo -e " ${GREEN}[01]${RESET} 👤 Crear Cliente"
        echo -e " ${GREEN}[02]${RESET} ❌ Revocar Cliente"
        echo -e " ${GREEN}[03]${RESET} 👥 Listar Clientes"
        echo -e " ${GREEN}[04]${RESET} ♻️  Reiniciar Servicio"
        echo -e " ${GREEN}[05]${RESET} 📊 Estado Detallado"
        echo -e " ${GREEN}[06]${RESET} 🔎 Diagnóstico"
        echo -e " ${GREEN}[07]${RESET} 📜 Ver Logs"
        echo -e " ${GREEN}[08]${RESET} 🖥️  Información del Servidor"
        echo -e " ${GREEN}[09]${RESET} 🔄 Reinstalar / Actualizar"
        echo -e " ${RED}[10]${RESET} 🗑️  Desinstalar OpenVPN"

    else

        echo -e "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"
        echo

        echo -e " ${GREEN}[01]${RESET} 🚀 Instalar OpenVPN"

    fi

    echo
    echo -e "${GRAY} ────────────────────────────────────────────────────────────${RESET}"
    echo -e " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"
    echo

    read -r -p \
        "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
        OPTION

    case "$OPTION" in

        1|01)

            if [[ "$OPENVPN_STATUS" == "ON" ]] &&
               [[ -f "$SERVER_CONF" ]]; then

                create_client_menu

            else

                install_openvpn
                pause

            fi

            ;;

        2|02)

            [[ "$OPENVPN_STATUS" == "ON" ]] &&
                revoke_client

            ;;

        3|03)

            [[ "$OPENVPN_STATUS" == "ON" ]] &&
                list_clients

            ;;

        4|04)

            if [[ "$OPENVPN_STATUS" == "ON" ]]; then
                restart_openvpn
            fi

            ;;

        5|05)

            if [[ "$OPENVPN_STATUS" == "ON" ]]; then
                status_openvpn
            fi

            ;;

        6|06)

            if [[ "$OPENVPN_STATUS" == "ON" ]]; then
                diagnostic_openvpn
            fi

            ;;

        7|07)

            if [[ "$OPENVPN_STATUS" == "ON" ]]; then
                view_logs
            fi

            ;;

        8|08)

            system_info

            ;;

        9|09)

            if [[ "$OPENVPN_STATUS" == "ON" ]]; then
                install_openvpn
                pause
            fi

            ;;

        10)

            if [[ "$OPENVPN_STATUS" == "ON" ]]; then
                remove_openvpn
            fi

            ;;

        0|00)

            clear_screen

            exec bash \
                "$BASE/protocolos/menu.sh"

            ;;

        "")

            ;;

        *)

            error_msg "Opción inválida."
            sleep 1

            ;;

    esac

done