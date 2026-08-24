#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    SLOWDNS MANAGER
# ==============================================================
# Servicio principal : slowdns
# Servicio DNS       : dnsdist
# DNS público        : UDP 53
# DNSDist interno    : UDP 5380
# SlowDNS / DNSTT    : UDP 5300
#
# Compatible con:
# • HTTP Injector
# • HTTP Custom
# • UDP Custom
# • TLS Tunnel
#
# Configuración:
# /etc/kevintech/config.conf
# ==============================================================

set -o pipefail

# ==============================================================
# VARIABLES
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

SERVICE="slowdns"
DNSDIST_SERVICE="dnsdist"

DIR="/etc/slowdns"

BIN="/usr/bin/slowdns-server"

PUBKEY="$DIR/server.pub"
PRIVKEY="$DIR/server.key"
DOMAIN_FILE="$DIR/domain.conf"

SERVICE_FILE="/etc/systemd/system/slowdns.service"
DNSDIST_CONFIG="/etc/dnsdist/dnsdist.conf"

DNS_PORT="53"
DNSDIST_PORT="5380"
SLOWDNS_PORT="5300"

VERSION="3.0"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# ROOT
# ==============================================================

if [[ "$EUID" -ne 0 ]]; then

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}SlowDNS requiere permisos de root.${RESET}"
    echo

    exit 1
fi

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then

    echo
    echo -e "${RED}${BOLD}✘ CONFIGURACIÓN NO ENCONTRADA${RESET}"
    echo
    echo -e "${WHITE}Archivo:${RESET} $CONFIG"
    echo

    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null

# ==============================================================
# FUNCIONES VISUALES
# ==============================================================

line() {

    echo -e \
        "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

header() {

    clear

    echo -e \
        "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${CYAN}║${RESET}               ${MAGENTA}${BOLD}🐌 SLOWDNS MANAGER${RESET}                    ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}                 ${GRAY}KevinTech v$VERSION${RESET}                    ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

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

    read -rp \
        "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

# ==============================================================
# CONFIG.CONF
# ==============================================================

set_config() {

    local KEY="$1"
    local VALUE="$2"

    if grep -q "^${KEY}=" "$CONFIG"; then

        sed -i \
            "s/^${KEY}=.*/${KEY}=${VALUE}/" \
            "$CONFIG"

    else

        echo "${KEY}=${VALUE}" >> "$CONFIG"

    fi
}

set_port_config() {

    local KEY="$1"
    local VALUE="$2"

    if grep -q "^${KEY}=" "$CONFIG"; then

        sed -i \
            "s/^${KEY}=.*/${KEY}=\"$VALUE\"/" \
            "$CONFIG"

    else

        echo "${KEY}=\"$VALUE\"" >> "$CONFIG"

    fi
}

remove_config_key() {

    local KEY="$1"

    sed -i \
        "/^${KEY}=/d" \
        "$CONFIG"
}

# ==============================================================
# VALIDAR DOMINIO
# ==============================================================

valid_domain() {

    local DOMAIN="$1"

    [[ -z "$DOMAIN" ]] && return 1

    [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] ||
        return 1

    return 0
}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    info "Actualizando repositorios..."

    if ! apt-get update -y >/dev/null 2>&1; then

        error_msg "No se pudo actualizar APT."

        return 1
    fi

    info "Instalando dependencias..."

    if ! apt-get install -y \
        curl \
        wget \
        dnsdist \
        iptables \
        iproute2 \
        dnsutils \
        ca-certificates \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."

        return 1
    fi

    mkdir -p "$DIR"

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# DETECTAR ARQUITECTURA
# ==============================================================

get_binary_name() {

    case "$(uname -m)" in

        x86_64|amd64)

            echo "dnstt-server-linux-amd64"

            ;;

        aarch64|arm64)

            echo "dnstt-server-linux-arm64"

            ;;

        i386|i686)

            echo "dnstt-server-linux-386"

            ;;

        *)

            return 1

            ;;

    esac
}

# ==============================================================
# INSTALAR BINARIO
# ==============================================================

install_slowdns_binary() {

    local BIN_NAME
    local URL
    local TMP

    BIN_NAME=$(get_binary_name)

    if [[ -z "$BIN_NAME" ]]; then

        error_msg \
            "Arquitectura no soportada: $(uname -m)"

        return 1
    fi

    if [[ -x "$BIN" ]]; then

        ok "SlowDNS Server ya está instalado."

        return 0
    fi

    local MIRRORS=(

        "https://dnstt.network/$BIN_NAME"

        "https://github.com/bugfloyd/dnstt-deploy/raw/main/bin/$BIN_NAME"

        "https://raw.githubusercontent.com/Dan3651/scripts/main/slowdns-server"

    )

    info "Descargando SlowDNS Server..."

    TMP=$(mktemp)

    for URL in "${MIRRORS[@]}"; do

        echo
        echo -e \
            "${GRAY}Probando:${RESET} $URL"

        if curl \
            -fL \
            --connect-timeout 15 \
            --max-time 180 \
            --retry 2 \
            "$URL" \
            -o "$TMP" \
            >/dev/null 2>&1; then

            if [[ -s "$TMP" ]]; then

                chmod +x "$TMP"

                if "$TMP" -h \
                    >/dev/null 2>&1; then

                    install \
                        -m 755 \
                        "$TMP" \
                        "$BIN"

                    rm -f "$TMP"

                    if [[ -x "$BIN" ]]; then

                        ok "SlowDNS Server instalado."

                        return 0

                    fi
                fi
            fi
        fi

        rm -f "$TMP"

    done

    error_msg \
        "No fue posible descargar SlowDNS Server."

    return 1
}

# ==============================================================
# GENERAR CLAVES
# ==============================================================

generate_keys() {

    mkdir -p "$DIR"

    chmod 700 "$DIR"

    if [[ -f "$PUBKEY" &&
          -f "$PRIVKEY" ]]; then

        ok "Claves SlowDNS existentes."

        chmod 600 "$PRIVKEY"
        chmod 644 "$PUBKEY"

        return 0
    fi

    info "Generando claves SlowDNS..."

    if ! "$BIN" \
        -gen-key \
        -privkey-file "$PRIVKEY" \
        -pubkey-file "$PUBKEY" \
        >/dev/null 2>&1; then

        error_msg "No se pudieron generar las claves."

        return 1
    fi

    if [[ ! -f "$PUBKEY" ||
          ! -f "$PRIVKEY" ]]; then

        error_msg \
            "Las claves no fueron generadas correctamente."

        return 1
    fi

    chmod 600 "$PRIVKEY"
    chmod 644 "$PUBKEY"

    ok "Claves generadas."

    return 0
}

# ==============================================================
# CONFIGURAR DNSDIST
# ==============================================================

configure_dnsdist() {

    local DOMAIN="$1"
    local ESCAPED_DOMAIN

    if [[ -z "$DOMAIN" ]]; then

        error_msg "Dominio vacío."

        return 1
    fi

    info "Configurando DNSDist..."

    mkdir -p /etc/dnsdist

    ESCAPED_DOMAIN=$(
        printf '%s' "$DOMAIN" |
        sed 's/[.[\*^$()+?{|\\]/\\&/g'
    )

    cat > "$DNSDIST_CONFIG" <<EOF
-- =========================================================
-- KevinTech Multi Script
-- DNSDist + SlowDNS
-- =========================================================

setLocal("0.0.0.0:${DNSDIST_PORT}")

newServer({
    address="127.0.0.1:${SLOWDNS_PORT}",
    name="slowdns",
    pool="slowdns"
})

addAction(
    RegexRule("${ESCAPED_DOMAIN}"),
    PoolAction("slowdns")
)
EOF

    if ! dnsdist \
        --check-config \
        "$DNSDIST_CONFIG" \
        >/dev/null 2>&1; then

        error_msg "La configuración de DNSDist es inválida."

        dnsdist \
            --check-config \
            "$DNSDIST_CONFIG" \
            2>&1

        return 1
    fi

    systemctl daemon-reload

    ok "DNSDist configurado."

    return 0
}

# ==============================================================
# CREAR SERVICIO SLOWDNS
# ==============================================================

create_slowdns_service() {

    local DOMAIN="$1"

    if [[ -z "$DOMAIN" ]]; then

        error_msg "No se recibió el dominio."

        return 1
    fi

    info "Creando servicio SlowDNS..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech SlowDNS Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR

ExecStart=$BIN -udp :$SLOWDNS_PORT -privkey-file $PRIVKEY $DOMAIN 127.0.0.1:22

Restart=always
RestartSec=3

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE" \
        >/dev/null 2>&1; then

        error_msg \
            "No se pudo habilitar SlowDNS."

        return 1
    fi

    ok "Servicio SlowDNS creado."

    return 0
}

# ==============================================================
# COMPROBAR PUERTOS
# ==============================================================

port_udp_in_use() {

    local PORT="$1"

    ss -H -lun 2>/dev/null |
        awk -v P=":$PORT" '
            $5 == P || $5 ~ P"$" {
                found=1
            }

            END {
                exit !found
            }
        '
}

check_required_ports() {

    local PORT

    for PORT in "$DNS_PORT" "$DNSDIST_PORT" "$SLOWDNS_PORT"; do

        if port_udp_in_use "$PORT"; then

            warning \
                "UDP $PORT ya está siendo utilizado."

            ss -lunp 2>/dev/null |
                grep ":$PORT" ||
                true

            return 1
        fi

    done

    return 0
}

# ==============================================================
# FIREWALL
# ==============================================================

open_dns_port() {

    info "Configurando reglas DNS..."

    # ----------------------------------------------------------
    # IPv4
    # ----------------------------------------------------------

    while iptables \
        -t nat \
        -C PREROUTING \
        -p udp \
        --dport "$DNS_PORT" \
        -m u32 \
        --u32 "0>>22&0x3C@12=0x00010000" \
        -j REDIRECT \
        --to-ports "$DNSDIST_PORT" \
        2>/dev/null; do

        iptables \
            -t nat \
            -D PREROUTING \
            -p udp \
            --dport "$DNS_PORT" \
            -m u32 \
            --u32 "0>>22&0x3C@12=0x00010000" \
            -j REDIRECT \
            --to-ports "$DNSDIST_PORT"

    done

    # ----------------------------------------------------------
    # IPv6
    # ----------------------------------------------------------

    while ip6tables \
        -t nat \
        -C PREROUTING \
        -p udp \
        --dport "$DNS_PORT" \
        -j REDIRECT \
        --to-ports "$DNSDIST_PORT" \
        2>/dev/null; do

        ip6tables \
            -t nat \
            -D PREROUTING \
            -p udp \
            --dport "$DNS_PORT" \
            -j REDIRECT \
            --to-ports "$DNSDIST_PORT"

    done

    # ----------------------------------------------------------
    # Agregar IPv4
    # ----------------------------------------------------------

    if ! iptables \
        -t nat \
        -A PREROUTING \
        -p udp \
        --dport "$DNS_PORT" \
        -m u32 \
        --u32 "0>>22&0x3C@12=0x00010000" \
        -j REDIRECT \
        --to-ports "$DNSDIST_PORT"; then

        error_msg "No se pudo agregar la regla IPv4."

        return 1
    fi

    # ----------------------------------------------------------
    # Agregar IPv6
    # ----------------------------------------------------------

    if command -v ip6tables >/dev/null 2>&1; then

        ip6tables \
            -t nat \
            -A PREROUTING \
            -p udp \
            --dport "$DNS_PORT" \
            -j REDIRECT \
            --to-ports "$DNSDIST_PORT" \
            2>/dev/null || true

    fi

    ok "Reglas DNS aplicadas."

    return 0
}

# ==============================================================
# GUARDAR FIREWALL
# ==============================================================

save_firewall() {

    if command -v netfilter-persistent >/dev/null 2>&1; then

        netfilter-persistent save \
            >/dev/null 2>&1 || true

    elif command -v iptables-save >/dev/null 2>&1; then

        iptables-save \
            > /etc/iptables.rules \
            2>/dev/null || true

    fi
}

# ==============================================================
# INSTALAR SLOWDNS
# ==============================================================

install_slowdns() {

    header

    echo -e \
        "${WHITE}${BOLD}              🚀 INSTALAR SLOWDNS${RESET}"

    line

    echo

    if systemctl is-active --quiet "$SERVICE" &&
       systemctl is-active --quiet "$DNSDIST_SERVICE"; then

        warning "SlowDNS ya está instalado y activo."

        show_status_short

        pause

        return 0
    fi

    # ----------------------------------------------------------
    # Dominio
    # ----------------------------------------------------------

    read -r -p \
        "$(echo -e "${CYAN}🌐 Dominio NS: ${RESET}")" \
        DOMAIN

    DOMAIN=$(
        printf '%s' "$DOMAIN" |
        tr -d '[:space:]'
    )

    if ! valid_domain "$DOMAIN"; then

        error_msg "Dominio inválido."

        pause

        return 1
    fi

    # ----------------------------------------------------------
    # Dependencias
    # ----------------------------------------------------------

    install_dependencies || {

        pause

        return 1
    }

    # ----------------------------------------------------------
    # Puertos
    # ----------------------------------------------------------

    if ! check_required_ports; then

        error_msg \
            "Uno de los puertos necesarios está ocupado."

        pause

        return 1
    fi

    # ----------------------------------------------------------
    # Binario
    # ----------------------------------------------------------

    install_slowdns_binary || {

        pause

        return 1
    }

    # ----------------------------------------------------------
    # Directorio
    # ----------------------------------------------------------

    mkdir -p "$DIR"

    chmod 700 "$DIR"

    printf '%s\n' "$DOMAIN" > "$DOMAIN_FILE"

    chmod 600 "$DOMAIN_FILE"

    # ----------------------------------------------------------
    # Claves
    # ----------------------------------------------------------

    generate_keys || {

        pause

        return 1
    }

    # ----------------------------------------------------------
    # DNSDist
    # ----------------------------------------------------------

    configure_dnsdist "$DOMAIN" || {

        pause

        return 1
    }

    # ----------------------------------------------------------
    # SlowDNS
    # ----------------------------------------------------------

    create_slowdns_service "$DOMAIN" || {

        pause

        return 1
    }

    # ----------------------------------------------------------
    # Firewall
    # ----------------------------------------------------------

    open_dns_port || {

        warning \
            "No se pudo configurar completamente el firewall."

    }

    save_firewall

    # ----------------------------------------------------------
    # Iniciar servicios
    # ----------------------------------------------------------

    echo

    info "Iniciando DNSDist..."

    systemctl enable "$DNSDIST_SERVICE" \
        >/dev/null 2>&1

    systemctl restart "$DNSDIST_SERVICE"

    sleep 2

    if ! systemctl is-active --quiet "$DNSDIST_SERVICE"; then

        error_msg "DNSDist no pudo iniciar."

        journalctl \
            -u "$DNSDIST_SERVICE" \
            -n 30 \
            --no-pager \
            2>/dev/null

        set_config "SLOWDNS" "OFF"

        pause

        return 1
    fi

    ok "DNSDist activo."

    # ----------------------------------------------------------
    # SlowDNS
    # ----------------------------------------------------------

    info "Iniciando SlowDNS..."

    systemctl enable "$SERVICE" \
        >/dev/null 2>&1

    systemctl restart "$SERVICE"

    sleep 2

    if ! systemctl is-active --quiet "$SERVICE"; then

        error_msg "SlowDNS no pudo iniciar."

        journalctl \
            -u "$SERVICE" \
            -n 30 \
            --no-pager \
            2>/dev/null

        set_config "SLOWDNS" "OFF"

        pause

        return 1
    fi

    ok "SlowDNS activo."

    # ----------------------------------------------------------
    # Configuración KevinTech
    # ----------------------------------------------------------

    set_config "SLOWDNS" "ON"

    set_port_config "SLOWDNS_PORT" "$SLOWDNS_PORT"
    set_port_config "DNSDIST_PORT" "$DNSDIST_PORT"

    source "$CONFIG" 2>/dev/null

    # ----------------------------------------------------------
    # Resultado
    # ----------------------------------------------------------

    echo

    echo -e \
        "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"

    echo -e \
        "${GREEN}║${RESET}              ${BOLD}✔ SLOWDNS INSTALADO${RESET}                      ${GREEN}║${RESET}"

    echo -e \
        "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e \
        "${GREEN}║${RESET} Dominio NS : ${CYAN}$DOMAIN${RESET}"

    echo -e \
        "${GREEN}║${RESET} DNS público: ${CYAN}UDP $DNS_PORT${RESET}"

    echo -e \
        "${GREEN}║${RESET} DNSDist    : ${CYAN}UDP $DNSDIST_PORT${RESET}"

    echo -e \
        "${GREEN}║${RESET} SlowDNS    : ${CYAN}UDP $SLOWDNS_PORT${RESET}"

    echo -e \
        "${GREEN}║${RESET} DNSDist    : ${GREEN}ACTIVO${RESET}"

    echo -e \
        "${GREEN}║${RESET} SlowDNS    : ${GREEN}ACTIVO${RESET}"

    echo -e \
        "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}${BOLD}🔑 PUBLIC KEY${RESET}"
    line

    cat "$PUBKEY"

    line

    pause

    return 0
}

# ==============================================================
# ESTADO CORTO
# ==============================================================

show_status_short() {

    local DOMAIN="-"

    [[ -f "$DOMAIN_FILE" ]] &&
        DOMAIN=$(cat "$DOMAIN_FILE")

    echo
    echo -e \
        "${WHITE}Dominio:${RESET} ${CYAN}$DOMAIN${RESET}"

    echo -e \
        "${WHITE}DNS:${RESET}     ${GREEN}UDP $DNS_PORT${RESET}"

    echo -e \
        "${WHITE}DNSDist:${RESET} ${GREEN}UDP $DNSDIST_PORT${RESET}"

    echo -e \
        "${WHITE}SlowDNS:${RESET} ${GREEN}UDP $SLOWDNS_PORT${RESET}"
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_slowdns() {

    header

    warning \
        "Esta operación eliminará SlowDNS y su configuración."

    echo

    read -r -p \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        sleep 1

        return
    fi

    info "Deteniendo SlowDNS..."

    systemctl stop "$SERVICE" \
        2>/dev/null

    systemctl disable "$SERVICE" \
        2>/dev/null

    info "Deteniendo DNSDist..."

    systemctl stop "$DNSDIST_SERVICE" \
        2>/dev/null

    systemctl disable "$DNSDIST_SERVICE" \
        2>/dev/null

    # ----------------------------------------------------------
    # Firewall IPv4
    # ----------------------------------------------------------

    while iptables \
        -t nat \
        -C PREROUTING \
        -p udp \
        --dport "$DNS_PORT" \
        -m u32 \
        --u32 "0>>22&0x3C@12=0x00010000" \
        -j REDIRECT \
        --to-ports "$DNSDIST_PORT" \
        2>/dev/null; do

        iptables \
            -t nat \
            -D PREROUTING \
            -p udp \
            --dport "$DNS_PORT" \
            -m u32 \
            --u32 "0>>22&0x3C@12=0x00010000" \
            -j REDIRECT \
            --to-ports "$DNSDIST_PORT"

    done

    # ----------------------------------------------------------
    # Firewall IPv6
    # ----------------------------------------------------------

    if command -v ip6tables >/dev/null 2>&1; then

        while ip6tables \
            -t nat \
            -C PREROUTING \
            -p udp \
            --dport "$DNS_PORT" \
            -j REDIRECT \
            --to-ports "$DNSDIST_PORT" \
            2>/dev/null; do

            ip6tables \
                -t nat \
                -D PREROUTING \
                -p udp \
                --dport "$DNS_PORT" \
                -j REDIRECT \
                --to-ports "$DNSDIST_PORT"

        done

    fi

    save_firewall

    # ----------------------------------------------------------
    # Archivos
    # ----------------------------------------------------------

    info "Eliminando archivos..."

    rm -f "$SERVICE_FILE"
    rm -f "$DNSDIST_CONFIG"

    rm -rf "$DIR"

    rm -f "$BIN"

    systemctl daemon-reload

    systemctl reset-failed "$SERVICE" \
        2>/dev/null || true

    # ----------------------------------------------------------
    # Configuración KevinTech
    # ----------------------------------------------------------

    set_config "SLOWDNS" "OFF"

    remove_config_key "SLOWDNS_PORT"
    remove_config_key "DNSDIST_PORT"

    source "$CONFIG" 2>/dev/null

    echo

    ok "SlowDNS eliminado correctamente."

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_slowdns() {

    header

    if [[ ! -f "$SERVICE_FILE" ]]; then

        error_msg "SlowDNS no está instalado."

        pause

        return
    fi

    info "Reiniciando DNSDist..."

    systemctl restart "$DNSDIST_SERVICE"

    sleep 2

    if ! systemctl is-active --quiet "$DNSDIST_SERVICE"; then

        error_msg "DNSDist no pudo iniciar."

        journalctl \
            -u "$DNSDIST_SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null

        pause

        return 1
    fi

    ok "DNSDist activo."

    info "Reiniciando SlowDNS..."

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        ok "SlowDNS reiniciado correctamente."

        set_config "SLOWDNS" "ON"

    else

        error_msg "SlowDNS no pudo iniciar."

        set_config "SLOWDNS" "OFF"

        journalctl \
            -u "$SERVICE" \
            -n 20 \
            --no-pager \
            2>/dev/null
    fi

    pause
}

# ==============================================================
# ESTADO
# ==============================================================

status_slowdns() {

    header

    local DOMAIN="-"

    [[ -f "$DOMAIN_FILE" ]] &&
        DOMAIN=$(cat "$DOMAIN_FILE")

    if systemctl is-active --quiet "$SERVICE"; then

        SLOW_STATUS="${GREEN}🟢 ACTIVO${RESET}"

    else

        SLOW_STATUS="${RED}🔴 DETENIDO${RESET}"

    fi

    if systemctl is-active --quiet "$DNSDIST_SERVICE"; then

        DNS_STATUS="${GREEN}🟢 ACTIVO${RESET}"

    else

        DNS_STATUS="${RED}🔴 DETENIDO${RESET}"

    fi

    echo -e \
        "${WHITE}SlowDNS:${RESET}     $SLOW_STATUS"

    echo -e \
        "${WHITE}DNSDist:${RESET}     $DNS_STATUS"

    echo -e \
        "${WHITE}Dominio NS:${RESET}  ${CYAN}$DOMAIN${RESET}"

    echo -e \
        "${WHITE}DNS público:${RESET} ${CYAN}UDP $DNS_PORT${RESET}"

    echo -e \
        "${WHITE}DNSDist:${RESET}     ${CYAN}UDP $DNSDIST_PORT${RESET}"

    echo -e \
        "${WHITE}SlowDNS:${RESET}     ${CYAN}UDP $SLOWDNS_PORT${RESET}"

    line

    echo -e "${WHITE}Puertos UDP:${RESET}"

    ss -lunp 2>/dev/null |
        grep -E \
            "(:${DNS_PORT}|:${DNSDIST_PORT}|:${SLOWDNS_PORT})" ||
        echo -e "${GRAY}No se encontraron puertos.${RESET}"

    line

    echo -e "${WHITE}Servicios:${RESET}"

    echo

    systemctl \
        --no-pager \
        --full \
        status "$SERVICE" \
        2>/dev/null

    echo

    systemctl \
        --no-pager \
        --full \
        status "$DNSDIST_SERVICE" \
        2>/dev/null

    pause
}

# ==============================================================
# PUBLIC KEY
# ==============================================================

show_key() {

    header

    echo -e \
        "${WHITE}${BOLD}🔑 PUBLIC KEY SLOWDNS${RESET}"

    line

    if [[ -f "$PUBKEY" ]]; then

        cat "$PUBKEY"

    else

        error_msg "No existe la Public Key."

    fi

    line

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

check_slowdns() {

    header

    echo -e \
        "${WHITE}${BOLD}🔎 DIAGNÓSTICO SLOWDNS${RESET}"

    echo

    if [[ -x "$BIN" ]]; then
        ok "Binario SlowDNS encontrado"
    else
        error_msg "Binario SlowDNS no encontrado"
    fi

    if [[ -f "$PRIVKEY" ]]; then
        ok "Clave privada encontrada"
    else
        error_msg "Clave privada no encontrada"
    fi

    if [[ -f "$PUBKEY" ]]; then
        ok "Public Key encontrada"
    else
        error_msg "Public Key no encontrada"
    fi

    if [[ -f "$DOMAIN_FILE" ]]; then
        ok "Dominio configurado"
    else
        error_msg "Dominio no configurado"
    fi

    if [[ -f "$DNSDIST_CONFIG" ]]; then
        ok "Configuración DNSDist encontrada"
    else
        error_msg "Configuración DNSDist no encontrada"
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        ok "Servicio SlowDNS encontrado"
    else
        error_msg "Servicio SlowDNS no encontrado"
    fi

    echo

    if systemctl is-active --quiet "$SERVICE"; then
        ok "SlowDNS activo"
    else
        error_msg "SlowDNS detenido"
    fi

    if systemctl is-active --quiet "$DNSDIST_SERVICE"; then
        ok "DNSDist activo"
    else
        error_msg "DNSDist detenido"
    fi

    echo

    line

    echo -e "${WHITE}Puertos:${RESET}"

    for PORT in \
        "$DNS_PORT" \
        "$DNSDIST_PORT" \
        "$SLOWDNS_PORT"; do

        if port_udp_in_use "$PORT"; then

            ok "UDP $PORT está escuchando"

        else

            warning "UDP $PORT no está escuchando"

        fi

    done

    line

    echo -e "${WHITE}Logs SlowDNS:${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 15 \
        --no-pager \
        2>/dev/null

    echo

    echo -e "${WHITE}Logs DNSDist:${RESET}"

    journalctl \
        -u "$DNSDIST_SERVICE" \
        -n 15 \
        --no-pager \
        2>/dev/null

    pause
}

# ==============================================================
# INFORMACIÓN DEL SERVIDOR
# ==============================================================

system_info() {

    header

    local HOST
    local IP
    local OS
    local KERNEL
    local RAM
    local DISK
    local CPU
    local CORES
    local UPTIME

    HOST=$(hostname)

    IP=$(
        curl \
            -4 \
            -s \
            --connect-timeout 5 \
            https://api.ipify.org \
            2>/dev/null
    )

    OS=$(
        grep '^PRETTY_NAME=' \
            /etc/os-release |
        cut -d= -f2 |
        tr -d '"'
    )

    KERNEL=$(uname -r)

    RAM=$(
        free -h |
        awk '/Mem:/ {print $3" / "$2}'
    )

    DISK=$(
        df -h / |
        awk 'NR==2 {print $3" / "$2" ("$5")"}'
    )

    CPU=$(
        awk -F: '
            /model name/ {
                print $2
                exit
            }
        ' /proc/cpuinfo |
        sed 's/^ *//'
    )

    CORES=$(nproc)
    UPTIME=$(uptime -p)

    echo -e "${WHITE}Hostname:${RESET} $HOST"
    echo -e "${WHITE}Sistema:${RESET}  $OS"
    echo -e "${WHITE}Kernel:${RESET}   $KERNEL"
    echo -e "${WHITE}CPU:${RESET}      ${CPU:-Desconocida}"
    echo -e "${WHITE}Núcleos:${RESET}  $CORES"
    echo -e "${WHITE}RAM:${RESET}      $RAM"
    echo -e "${WHITE}Disco:${RESET}    $DISK"
    echo -e "${WHITE}Uptime:${RESET}   $UPTIME"
    echo -e "${WHITE}IPv4:${RESET}     ${IP:-No disponible}"

    line

    echo -e "${WHITE}Carga:${RESET}"

    uptime

    line

    pause
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e \
        "${MAGENTA}${BOLD}             🚀 INSTALACIÓN AUTOMÁTICA${RESET}"

    echo -e \
        "${WHITE}                       SLOWDNS${RESET}"

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    if install_slowdns >/dev/null 2>&1; then

        if systemctl is-active --quiet "$SERVICE" &&
           systemctl is-active --quiet "$DNSDIST_SERVICE"; then

            echo
            echo -e \
                "${GREEN}✔ SlowDNS instalado y activo correctamente.${RESET}"

            exit 0
        fi
    fi

    echo

    echo -e \
        "${RED}✘ Error instalando SlowDNS.${RESET}"

    echo

    journalctl \
        -u "$SERVICE" \
        -n 20 \
        --no-pager \
        2>/dev/null

    echo

    journalctl \
        -u "$DNSDIST_SERVICE" \
        -n 20 \
        --no-pager \
        2>/dev/null

    exit 1
fi

# ==============================================================
# MENÚ PRINCIPAL
# ==============================================================

while true; do

    header

    # Recargar configuración
    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    if systemctl is-active --quiet "$SERVICE" &&
       systemctl is-active --quiet "$DNSDIST_SERVICE"; then

        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    elif [[ -f "$SERVICE_FILE" ]]; then

        STATUS="${RED}🔴 DETENIDO${RESET}"

    else

        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

    fi

    DOMAIN="-"

    [[ -f "$DOMAIN_FILE" ]] &&
        DOMAIN=$(cat "$DOMAIN_FILE")

    echo -e \
        "${WHITE}Estado:${RESET}       $STATUS"

    echo -e \
        "${WHITE}Dominio NS:${RESET}   ${YELLOW}$DOMAIN${RESET}"

    echo -e \
        "${WHITE}DNS público:${RESET} ${CYAN}UDP $DNS_PORT${RESET}"

    echo -e \
        "${WHITE}DNSDist:${RESET}     ${CYAN}UDP $DNSDIST_PORT${RESET}"

    echo -e \
        "${WHITE}SlowDNS:${RESET}     ${CYAN}UDP $SLOWDNS_PORT${RESET}"

    line

    if [[ -f "$SERVICE_FILE" ]] ||
       [[ -x "$BIN" ]]; then

        echo -e \
            "${BLUE}${BOLD}⚙️ ADMINISTRACIÓN${RESET}"

        echo

        echo -e \
            " ${GREEN}[01]${RESET} 🔄 Reinstalar / Actualizar"

        echo -e \
            " ${GREEN}[02]${RESET} ♻️  Reiniciar Servicios"

        echo -e \
            " ${GREEN}[03]${RESET} 📊 Estado"

        echo -e \
            " ${GREEN}[04]${RESET} 🔑 Ver Public Key"

        echo -e \
            " ${GREEN}[05]${RESET} 🔎 Diagnóstico"

        echo -e \
            " ${GREEN}[06]${RESET} 🖥️  Información VPS"

        echo -e \
            " ${RED}[07]${RESET} 🗑️  Desinstalar SlowDNS"

    else

        echo -e \
            "${BLUE}${BOLD}🚀 INSTALACIÓN${RESET}"

        echo

        echo -e \
            " ${GREEN}[01]${RESET} 🚀 Instalar SlowDNS"

        echo -e \
            " ${GREEN}[02]${RESET} 🔎 Diagnóstico"

        echo -e \
            " ${GREEN}[03]${RESET} 🖥️  Información VPS"

    fi

    echo

    echo -e \
        "${GRAY}──────────────────────────────────────────────────────────────${RESET}"

    echo -e \
        " ${RED}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

    echo

    echo -e \
        "${GRAY}KevinTech Multi Script • SlowDNS Manager v$VERSION${RESET}"

    echo

    read -r -p \
        "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
        OP

    case "$OP" in

        1)

            install_slowdns

            ;;

        2)

            if [[ -f "$SERVICE_FILE" ]]; then

                restart_slowdns

            else

                check_slowdns

            fi

            ;;

        3)

            if [[ -f "$SERVICE_FILE" ]]; then

                status_slowdns

            else

                system_info

            fi

            ;;

        4)

            if [[ -f "$SERVICE_FILE" ]]; then

                show_key

            else

                system_info

            fi

            ;;

        5)

            check_slowdns

            ;;

        6)

            system_info

            ;;

        7)

            remove_slowdns

            ;;

        0)

            clear

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