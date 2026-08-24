#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    ZIVPN MANAGER
# ==============================================================
# Servicio : zivpn
# Puerto   : UDP automático 20000-29999
# Config   : /etc/zivpn/config.json
# Estado   : /etc/kevintech/config.conf
# ==============================================================

set -o pipefail

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

VERSION="3.0"

SERVICE="zivpn"
BIN="/usr/local/bin/zivpn"
ZIVPN_DIR="/etc/zivpn"
ZIVPN_CONFIG="$ZIVPN_DIR/config.json"
ZIVPN_KEY="$ZIVPN_DIR/zivpn.key"
ZIVPN_CERT="$ZIVPN_DIR/zivpn.crt"
SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"

PORT_MIN="20000"
PORT_MAX="29999"

BIN_BASE_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# ROOT
# ==============================================================

if [[ "$EUID" -ne 0 ]]; then

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este administrador requiere permisos de root.${RESET}"
    echo

    exit 1
fi

# ==============================================================
# CONFIGURACIÓN KEVINTECH
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
        "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🚀 ZIVPN MANAGER${RESET}                      ${CYAN}║${RESET}"

    echo -e \
        "${CYAN}║${RESET}                  ${GRAY}KevinTech v$VERSION${RESET}                     ${CYAN}║${RESET}"

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

    local PORT="$1"

    if grep -q '^ZIPVPN_PORT=' "$CONFIG"; then

        sed -i \
            "s/^ZIPVPN_PORT=.*/ZIPVPN_PORT=\"$PORT\"/" \
            "$CONFIG"

    else

        echo "ZIPVPN_PORT=\"$PORT\"" >> "$CONFIG"

    fi
}

remove_port_config() {

    sed -i '/^ZIPVPN_PORT=/d' "$CONFIG"
}

# ==============================================================
# DETECCIÓN DE RED
# ==============================================================

get_network_interface() {

    ip route |
        awk '/default/ {print $5; exit}'
}

# ==============================================================
# PUERTO UDP
# ==============================================================

udp_port_in_use() {

    local PORT="$1"

    ss -H -lun 2>/dev/null |
        awk -v p=":$PORT" '
            $5 == p || $5 ~ p"$" {
                found=1
            }
            END {
                exit !found
            }
        '
}

find_free_port() {

    local PORT
    local COUNT=0

    while [[ "$COUNT" -lt 10000 ]]; do

        PORT=$(
            shuf \
                -i "${PORT_MIN}-${PORT_MAX}" \
                -n 1
        )

        if ! udp_port_in_use "$PORT"; then

            echo "$PORT"
            return 0

        fi

        COUNT=$((COUNT + 1))

    done

    return 1
}

# ==============================================================
# DETECTAR ARQUITECTURA
# ==============================================================

get_binary_url() {

    case "$(uname -m)" in

        x86_64|amd64)

            echo \
                "${BIN_BASE_URL}/udp-zivpn-linux-amd64"

            ;;

        aarch64|arm64)

            echo \
                "${BIN_BASE_URL}/udp-zivpn-linux-arm64"

            ;;

        *)

            return 1

            ;;

    esac
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
        jq \
        openssl \
        iptables \
        iproute2 \
        ca-certificates \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."

        return 1
    fi

    ok "Dependencias instaladas."

    return 0
}

# ==============================================================
# IPV4 FORWARD
# ==============================================================

enable_ip_forward() {

    info "Activando IPv4 Forward..."

    sysctl -w \
        net.ipv4.ip_forward=1 \
        >/dev/null 2>&1

    if grep -q '^net.ipv4.ip_forward=' /etc/sysctl.conf; then

        sed -i \
            's/^net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' \
            /etc/sysctl.conf

    else

        echo \
            'net.ipv4.ip_forward=1' \
            >> /etc/sysctl.conf

    fi

    ok "IPv4 Forward habilitado."
}

# ==============================================================
# DESCARGAR BINARIO
# ==============================================================

download_binary() {

    local URL
    local TMP

    URL=$(get_binary_url)

    if [[ -z "$URL" ]]; then

        error_msg \
            "Arquitectura no compatible: $(uname -m)"

        return 1
    fi

    info "Arquitectura: $(uname -m)"

    info "Descargando ZiVPN..."

    TMP=$(mktemp)

    if ! curl \
        -fL \
        --connect-timeout 15 \
        --max-time 300 \
        --retry 3 \
        --retry-delay 2 \
        "$URL" \
        -o "$TMP"; then

        rm -f "$TMP"

        error_msg "No se pudo descargar ZiVPN."

        return 1
    fi

    if [[ ! -s "$TMP" ]]; then

        rm -f "$TMP"

        error_msg "El archivo descargado está vacío."

        return 1
    fi

    if ! install -m 755 \
        "$TMP" \
        "$BIN"; then

        rm -f "$TMP"

        error_msg "No se pudo instalar el binario."

        return 1
    fi

    rm -f "$TMP"

    if [[ ! -x "$BIN" ]]; then

        error_msg "El binario no quedó ejecutable."

        return 1
    fi

    ok "Binario ZiVPN instalado."

    return 0
}

# ==============================================================
# CERTIFICADOS
# ==============================================================

generate_certificates() {

    info "Generando certificados SSL..."

    mkdir -p "$ZIVPN_DIR"

    if [[ ! -f "$ZIVPN_KEY" ||
          ! -f "$ZIVPN_CERT" ]]; then

        if ! openssl req \
            -new \
            -newkey rsa:2048 \
            -nodes \
            -x509 \
            -days 3650 \
            -subj "/C=US/ST=CA/L=Server/O=KevinTech/CN=zivpn" \
            -keyout "$ZIVPN_KEY" \
            -out "$ZIVPN_CERT" \
            >/dev/null 2>&1; then

            error_msg "No se pudieron generar los certificados."

            return 1
        fi

    else

        info "Certificados existentes conservados."

    fi

    chmod 600 "$ZIVPN_KEY"
    chmod 644 "$ZIVPN_CERT"

    ok "Certificados SSL preparados."

    return 0
}

# ==============================================================
# CONFIGURACIÓN ZIVPN
# ==============================================================

create_config() {

    local PORT="$1"

    info "Creando configuración ZiVPN..."

    cat > "$ZIVPN_CONFIG" <<EOF
{
    "listen": ":$PORT",
    "cert": "$ZIVPN_CERT",
    "key": "$ZIVPN_KEY",
    "max_conn": 0,
    "auth": {
        "mode": "passwords",
        "config": []
    }
}
EOF

    chmod 600 "$ZIVPN_CONFIG"

    if ! jq empty "$ZIVPN_CONFIG" \
        >/dev/null 2>&1; then

        error_msg "config.json contiene errores."

        return 1
    fi

    ok "Configuración creada."

    return 0
}

# ==============================================================
# SYSTEMD
# ==============================================================

create_service() {

    info "Creando servicio systemd..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=KevinTech ZiVPN UDP Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$ZIVPN_DIR
ExecStart=$BIN server -c $ZIVPN_CONFIG
Restart=always
RestartSec=3
LimitNOFILE=1048576
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE" \
        >/dev/null 2>&1; then

        error_msg "No se pudo habilitar el servicio."

        return 1
    fi

    ok "Servicio systemd configurado."

    return 0
}

# ==============================================================
# FIREWALL
# ==============================================================

configure_zivpn_firewall() {

    local PORT="$1"
    local DEV

    info "Configurando firewall..."

    DEV=$(get_network_interface)

    if [[ -z "$DEV" ]]; then

        error_msg "No se pudo detectar la interfaz de red."

        return 1
    fi

    ok "Interfaz detectada: $DEV"

    # ----------------------------------------------------------
    # Eliminar reglas antiguas de esta instalación
    # ----------------------------------------------------------

    while iptables \
        -t nat \
        -C PREROUTING \
        -i "$DEV" \
        -p udp \
        --dport "$PORT_MIN:$PORT_MAX" \
        -j REDIRECT \
        --to-port "$PORT" \
        2>/dev/null; do

        iptables \
            -t nat \
            -D PREROUTING \
            -i "$DEV" \
            -p udp \
            --dport "$PORT_MIN:$PORT_MAX" \
            -j REDIRECT \
            --to-port "$PORT"

    done

    while iptables \
        -C INPUT \
        -p udp \
        --dport "$PORT" \
        -j ACCEPT \
        2>/dev/null; do

        iptables \
            -D INPUT \
            -p udp \
            --dport "$PORT" \
            -j ACCEPT

    done

    while iptables \
        -C INPUT \
        -p udp \
        --dport "$PORT_MIN:$PORT_MAX" \
        -j ACCEPT \
        2>/dev/null; do

        iptables \
            -D INPUT \
            -p udp \
            --dport "$PORT_MIN:$PORT_MAX" \
            -j ACCEPT

    done

    # ----------------------------------------------------------
    # Agregar reglas
    # ----------------------------------------------------------

    iptables \
        -t nat \
        -A PREROUTING \
        -i "$DEV" \
        -p udp \
        --dport "$PORT_MIN:$PORT_MAX" \
        -j REDIRECT \
        --to-port "$PORT"

    iptables \
        -A INPUT \
        -p udp \
        --dport "$PORT" \
        -j ACCEPT

    iptables \
        -A INPUT \
        -p udp \
        --dport "$PORT_MIN:$PORT_MAX" \
        -j ACCEPT

    ok "Firewall configurado."

    return 0
}

# ==============================================================
# GUARDAR IPTABLES
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
# INSTALAR ZIVPN
# ==============================================================

install_zivpn() {

    header

    echo -e \
        "${WHITE}${BOLD}             🚀 INSTALACIÓN ZIVPN${RESET}"

    line

    echo

    # ----------------------------------------------------------
    # Si existe y está funcionando
    # ----------------------------------------------------------

    if systemctl is-active --quiet "$SERVICE"; then

        warning "ZiVPN ya está instalado y activo."

        echo

        show_installed_info

        pause

        return 0
    fi

    install_dependencies || {
        pause
        return 1
    }

    enable_ip_forward

    echo

    info "Buscando puerto UDP disponible..."

    local PORT

    PORT=$(find_free_port)

    if [[ -z "$PORT" ]]; then

        error_msg \
            "No se encontró un puerto libre entre $PORT_MIN y $PORT_MAX."

        pause

        return 1
    fi

    ok "Puerto asignado: $PORT/UDP"

    echo

    download_binary || {
        pause
        return 1
    }

    generate_certificates || {
        pause
        return 1
    }

    create_config "$PORT" || {
        pause
        return 1
    }

    create_service || {
        pause
        return 1
    }

    echo

    configure_zivpn_firewall "$PORT" || {

        warning "No se pudo configurar completamente el firewall."

        warning "El servicio continuará instalándose."

    }

    save_firewall

    echo

    info "Iniciando ZiVPN..."

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        set_config "ZIPVPN" "ON"
        set_port_config "$PORT"

        source "$CONFIG" 2>/dev/null

        echo

        echo -e \
            "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"

        echo -e \
            "${GREEN}║${RESET}              ${BOLD}✔ ZIVPN INSTALADO${RESET}                       ${GREEN}║${RESET}"

        echo -e \
            "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"

        echo -e \
            "${GREEN}║${RESET} Servicio : ${CYAN}$SERVICE${RESET}"

        echo -e \
            "${GREEN}║${RESET} Estado   : ${GREEN}ACTIVO${RESET}"

        echo -e \
            "${GREEN}║${RESET} Puerto   : ${CYAN}$PORT/UDP${RESET}"

        echo -e \
            "${GREEN}║${RESET} Rango    : ${CYAN}$PORT_MIN-$PORT_MAX${RESET}"

        echo -e \
            "${GREEN}║${RESET} SSL      : ${GREEN}HABILITADO${RESET}"

        echo -e \
            "${GREEN}║${RESET} Config   : ${GRAY}$ZIVPN_CONFIG${RESET}"

        echo -e \
            "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

        pause

        return 0

    fi

    set_config "ZIPVPN" "OFF"

    error_msg "ZiVPN no pudo iniciar."

    echo

    journalctl \
        -u "$SERVICE" \
        -n 30 \
        --no-pager \
        2>/dev/null

    pause

    return 1
}

# ==============================================================
# INFORMACIÓN INSTALADA
# ==============================================================

show_installed_info() {

    local PORT="-"

    if [[ -f "$ZIVPN_CONFIG" ]] &&
       command -v jq >/dev/null 2>&1; then

        PORT=$(
            jq -r '.listen // "-" ' \
                "$ZIVPN_CONFIG" 2>/dev/null |
            sed 's/^://'
        )

    fi

    echo -e \
        "${WHITE}Servicio:${RESET} $SERVICE"

    echo -e \
        "${WHITE}Estado:${RESET} $(systemctl is-active "$SERVICE" 2>/dev/null)"

    echo -e \
        "${WHITE}Puerto:${RESET} ${PORT}/UDP"

    echo -e \
        "${WHITE}Configuración:${RESET} $ZIVPN_CONFIG"
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_zivpn() {

    header

    if [[ ! -f "$SERVICE_FILE" ]]; then

        error_msg "ZiVPN no está instalado."

        pause

        return
    fi

    info "Reiniciando ZiVPN..."

    systemctl restart "$SERVICE"

    sleep 2

    if systemctl is-active --quiet "$SERVICE"; then

        set_config "ZIPVPN" "ON"

        ok "ZiVPN reiniciado correctamente."

    else

        set_config "ZIPVPN" "OFF"

        error_msg "ZiVPN no pudo reiniciarse."

        echo

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

status_zivpn() {

    header

    local STATUS
    local PORT="-"

    if systemctl is-active --quiet "$SERVICE"; then

        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    elif [[ -f "$SERVICE_FILE" ]]; then

        STATUS="${RED}🔴 DETENIDO${RESET}"

    else

        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

    fi

    if [[ -f "$ZIVPN_CONFIG" ]]; then

        PORT=$(
            jq -r '.listen // "-"' \
                "$ZIVPN_CONFIG" 2>/dev/null |
            sed 's/^://'
        )

    fi

    echo -e \
        "${WHITE}Estado:${RESET}       $STATUS"

    echo -e \
        "${WHITE}Servicio:${RESET}     $SERVICE"

    echo -e \
        "${WHITE}Puerto UDP:${RESET}   ${GREEN}${PORT}${RESET}"

    echo -e \
        "${WHITE}Rango:${RESET}        ${PORT_MIN}-${PORT_MAX}"

    echo -e \
        "${WHITE}Binario:${RESET}      $BIN"

    echo -e \
        "${WHITE}Configuración:${RESET} $ZIVPN_CONFIG"

    line

    if [[ -f "$SERVICE_FILE" ]]; then

        systemctl \
            --no-pager \
            --full \
            status "$SERVICE" \
            2>/dev/null

    else

        echo -e "${GRAY}Servicio no instalado.${RESET}"

    fi

    pause
}

# ==============================================================
# AGREGAR CONTRASEÑA
# ==============================================================

add_zivpn_password() {

    header

    if [[ ! -f "$ZIVPN_CONFIG" ]]; then

        error_msg "ZiVPN no está instalado."

        pause

        return
    fi

    read -r -p \
        "$(echo -e "${CYAN}Nueva contraseña: ${RESET}")" \
        PASS

    if [[ -z "$PASS" ]]; then

        error_msg "La contraseña no puede estar vacía."

        pause

        return
    fi

    if jq -e \
        --arg pass "$PASS" \
        '.auth.config[]? | select(. == $pass)' \
        "$ZIVPN_CONFIG" \
        >/dev/null 2>&1; then

        error_msg "La contraseña ya existe."

        pause

        return
    fi

    local TMP

    TMP=$(mktemp)

    if jq \
        --arg pass "$PASS" \
        '.auth.config += [$pass]' \
        "$ZIVPN_CONFIG" > "$TMP"; then

        mv "$TMP" "$ZIVPN_CONFIG"

        chmod 600 "$ZIVPN_CONFIG"

        systemctl restart "$SERVICE"

        if systemctl is-active --quiet "$SERVICE"; then

            ok "Contraseña agregada correctamente."

        else

            error_msg \
                "La contraseña fue agregada, pero el servicio no inició."

        fi

    else

        rm -f "$TMP"

        error_msg "No se pudo modificar la configuración."

    fi

    pause
}

# ==============================================================
# ELIMINAR CONTRASEÑA
# ==============================================================

remove_zivpn_password() {

    header

    if [[ ! -f "$ZIVPN_CONFIG" ]]; then

        error_msg "ZiVPN no está instalado."

        pause

        return
    fi

    mapfile -t PASSLIST < <(
        jq -r '.auth.config[]?' "$ZIVPN_CONFIG"
    )

    if [[ ${#PASSLIST[@]} -eq 0 ]]; then

        warning "No existen contraseñas registradas."

        pause

        return
    fi

    echo

    for ((i=0; i<${#PASSLIST[@]}; i++)); do

        printf \
            " ${GREEN}[%02d]${RESET} %s\n" \
            "$((i + 1))" \
            "${PASSLIST[$i]}"

    done

    echo

    read -r -p \
        "$(echo -e "${CYAN}Seleccione una contraseña: ${RESET}")" \
        OP

    if [[ ! "$OP" =~ ^[0-9]+$ ]]; then

        error_msg "Opción inválida."

        pause

        return
    fi

    local INDEX=$((OP - 1))

    if (( INDEX < 0 || INDEX >= ${#PASSLIST[@]} )); then

        error_msg "Opción inválida."

        pause

        return
    fi

    local PASS="${PASSLIST[$INDEX]}"
    local TMP

    TMP=$(mktemp)

    if jq \
        --arg pass "$PASS" \
        '.auth.config |= map(select(. != $pass))' \
        "$ZIVPN_CONFIG" > "$TMP"; then

        mv "$TMP" "$ZIVPN_CONFIG"

        chmod 600 "$ZIVPN_CONFIG"

        systemctl restart "$SERVICE"

        ok "Contraseña eliminada correctamente."

    else

        rm -f "$TMP"

        error_msg "No se pudo modificar la configuración."

    fi

    pause
}

# ==============================================================
# LISTAR CONTRASEÑAS
# ==============================================================

list_zivpn_passwords() {

    header

    if [[ ! -f "$ZIVPN_CONFIG" ]]; then

        error_msg "ZiVPN no está instalado."

        pause

        return
    fi

    local TOTAL

    TOTAL=$(
        jq \
            '.auth.config | length' \
            "$ZIVPN_CONFIG" \
            2>/dev/null
    )

    echo

    echo -e \
        "${WHITE}Total de contraseñas:${RESET} ${GREEN}${TOTAL:-0}${RESET}"

    line

    if [[ "${TOTAL:-0}" -gt 0 ]]; then

        jq -r \
            '.auth.config[]' \
            "$ZIVPN_CONFIG" |
        nl -w2 -s". "

    else

        echo -e \
            "${GRAY}No existen contraseñas.${RESET}"

    fi

    line

    pause
}

# ==============================================================
# LOGS
# ==============================================================

view_zivpn_logs() {

    header

    info "Últimos 50 registros de ZiVPN..."

    line

    journalctl \
        -u "$SERVICE" \
        -n 50 \
        --no-pager \
        2>/dev/null

    line

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

check_zivpn() {

    header

    echo -e "${WHITE}${BOLD}Componentes:${RESET}"
    echo

    if [[ -x "$BIN" ]]; then
        ok "Binario ZiVPN encontrado"
    else
        error_msg "Binario ZiVPN no encontrado"
    fi

    if [[ -f "$ZIVPN_CONFIG" ]]; then
        ok "config.json encontrado"
    else
        error_msg "config.json no encontrado"
    fi

    if [[ -f "$ZIVPN_CERT" ]]; then
        ok "Certificado SSL encontrado"
    else
        error_msg "Certificado SSL no encontrado"
    fi

    if [[ -f "$ZIVPN_KEY" ]]; then
        ok "Llave privada encontrada"
    else
        error_msg "Llave privada no encontrada"
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        ok "Servicio systemd encontrado"
    else
        error_msg "Servicio systemd no encontrado"
    fi

    if systemctl is-active --quiet "$SERVICE"; then
        ok "Servicio activo"
    else
        error_msg "Servicio detenido"
    fi

    if [[ -f "$ZIVPN_CONFIG" ]] &&
       jq empty "$ZIVPN_CONFIG" >/dev/null 2>&1; then

        ok "JSON válido"

    else

        error_msg "JSON inválido"

    fi

    local PORT="-"

    if [[ -f "$ZIVPN_CONFIG" ]]; then

        PORT=$(
            jq -r '.listen // "-"' \
                "$ZIVPN_CONFIG" 2>/dev/null |
            sed 's/^://'
        )

    fi

    echo

    line

    echo -e \
        "${WHITE}Puerto configurado:${RESET} ${CYAN}$PORT${RESET}"

    echo

    echo -e \
        "${WHITE}Puerto escuchando:${RESET}"

    if [[ "$PORT" != "-" ]] &&
       ss -lunp 2>/dev/null |
       grep -q ":${PORT}"; then

        ok "UDP $PORT está escuchando."

    else

        error_msg "UDP $PORT no está escuchando."

    fi

    line

    echo -e "${WHITE}Últimos registros:${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 15 \
        --no-pager \
        2>/dev/null

    pause
}

# ==============================================================
# INFORMACIÓN VPS
# ==============================================================

system_info() {

    header

    local HOST
    local IP
    local OS
    local KERNEL
    local UPTIME
    local RAM
    local DISK
    local CPU
    local CORES

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
    UPTIME=$(uptime -p)

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

    echo
    echo -e "${WHITE}Hostname:${RESET}    $HOST"
    echo -e "${WHITE}Sistema:${RESET}     $OS"
    echo -e "${WHITE}Kernel:${RESET}      $KERNEL"
    echo -e "${WHITE}CPU:${RESET}         ${CPU:-Desconocida}"
    echo -e "${WHITE}Núcleos:${RESET}     $CORES"
    echo -e "${WHITE}Memoria:${RESET}     $RAM"
    echo -e "${WHITE}Disco:${RESET}       $DISK"
    echo -e "${WHITE}Uptime:${RESET}      $UPTIME"
    echo -e "${WHITE}IPv4:${RESET}        ${IP:-No disponible}"

    line

    echo -e "${WHITE}Carga:${RESET}"

    uptime

    line

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

remove_zivpn() {

    header

    warning "Se eliminará ZiVPN."

    echo
    echo -e "${GRAY}Se eliminarán:${RESET}"
    echo "  • Servicio systemd"
    echo "  • Binario ZiVPN"
    echo "  • Certificados"
    echo "  • Configuración"
    echo "  • Reglas firewall de ZiVPN"
    echo

    read -r -p \
        "$(echo -e "${RED}Escribe ELIMINAR para confirmar: ${RESET}")" \
        CONFIRM

    if [[ "$CONFIRM" != "ELIMINAR" ]]; then

        warning "Operación cancelada."

        sleep 1

        return
    fi

    local PORT
    local DEV

    PORT=""

    if [[ -f "$ZIVPN_CONFIG" ]]; then

        PORT=$(
            jq -r '.listen // empty' \
                "$ZIVPN_CONFIG" 2>/dev/null |
            sed 's/^://'
        )

    fi

    DEV=$(get_network_interface)

    info "Deteniendo ZiVPN..."

    systemctl stop "$SERVICE" 2>/dev/null

    systemctl disable "$SERVICE" 2>/dev/null

    info "Eliminando servicio..."

    rm -f "$SERVICE_FILE"

    systemctl daemon-reload

    info "Eliminando firewall..."

    if [[ -n "$DEV" ]]; then

        while iptables \
            -t nat \
            -C PREROUTING \
            -i "$DEV" \
            -p udp \
            --dport "$PORT_MIN:$PORT_MAX" \
            -j REDIRECT \
            --to-port "$PORT" \
            2>/dev/null; do

            iptables \
                -t nat \
                -D PREROUTING \
                -i "$DEV" \
                -p udp \
                --dport "$PORT_MIN:$PORT_MAX" \
                -j REDIRECT \
                --to-port "$PORT"

        done

        if [[ -n "$PORT" ]]; then

            while iptables \
                -C INPUT \
                -p udp \
                --dport "$PORT" \
                -j ACCEPT \
                2>/dev/null; do

                iptables \
                    -D INPUT \
                    -p udp \
                    --dport "$PORT" \
                    -j ACCEPT

            done

        fi

        while iptables \
            -C INPUT \
            -p udp \
            --dport "$PORT_MIN:$PORT_MAX" \
            -j ACCEPT \
            2>/dev/null; do

            iptables \
                -D INPUT \
                -p udp \
                --dport "$PORT_MIN:$PORT_MAX" \
                -j ACCEPT

        done

    fi

    save_firewall

    info "Eliminando archivos..."

    rm -rf "$ZIVPN_DIR"
    rm -f "$BIN"

    systemctl reset-failed "$SERVICE" \
        2>/dev/null

    set_config "ZIPVPN" "OFF"
    remove_port_config

    source "$CONFIG" 2>/dev/null

    echo

    ok "ZiVPN eliminado correctamente."

    pause
}

# ==============================================================
# SINCRONIZAR CONTRASEÑA
# ==============================================================

sync_zivpn_password() {

    local USER="$1"
    local PASS="$2"

    [[ -z "$USER" || -z "$PASS" ]] && return 1
    [[ ! -f "$ZIVPN_CONFIG" ]] && return 1

    if jq -e \
        --arg pass "$PASS" \
        '.auth.config[]? | select(. == $pass)' \
        "$ZIVPN_CONFIG" \
        >/dev/null 2>&1; then

        return 0
    fi

    local TMP

    TMP=$(mktemp)

    if jq \
        --arg pass "$PASS" \
        '.auth.config += [$pass]' \
        "$ZIVPN_CONFIG" > "$TMP"; then

        mv "$TMP" "$ZIVPN_CONFIG"

        chmod 600 "$ZIVPN_CONFIG"

        systemctl restart "$SERVICE" \
            >/dev/null 2>&1

        return 0
    fi

    rm -f "$TMP"

    return 1
}

# ==============================================================
# MODO AUTOMÁTICO
# ==============================================================

if [[ "$1" == "--auto" ]]; then

    echo

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e \
        "${MAGENTA}${BOLD}              🚀 INSTALACIÓN AUTOMÁTICA${RESET}"

    echo -e \
        "${WHITE}                         ZIVPN${RESET}"

    echo -e \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    if install_zivpn >/dev/null 2>&1; then

        if systemctl is-active --quiet "$SERVICE"; then

            echo
            echo -e \
                "${GREEN}✔ ZiVPN instalado y activo correctamente.${RESET}"

            exit 0

        fi

    fi

    echo

    echo -e \
        "${RED}✘ Error instalando ZiVPN.${RESET}"

    echo

    journalctl \
        -u "$SERVICE" \
        -n 20 \
        --no-pager \
        2>/dev/null

    exit 1
fi

# ==============================================================
# MENÚ
# ==============================================================

while true; do

    header

    # Recargar configuración
    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null

    if systemctl is-active --quiet "$SERVICE"; then

        STATUS="${GREEN}🟢 ACTIVO${RESET}"

    elif [[ -f "$SERVICE_FILE" ]]; then

        STATUS="${RED}🔴 DETENIDO${RESET}"

    else

        STATUS="${GRAY}⚪ NO INSTALADO${RESET}"

    fi

    PORT="-"

    if [[ -f "$ZIVPN_CONFIG" ]]; then

        PORT=$(
            jq -r '.listen // "-"' \
                "$ZIVPN_CONFIG" 2>/dev/null |
            sed 's/^://'
        )

    fi

    ARCH=$(uname -m)

    echo -e \
        "${WHITE}Estado:${RESET}       $STATUS"

    echo -e \
        "${WHITE}Servicio:${RESET}     ${CYAN}$SERVICE${RESET}"

    echo -e \
        "${WHITE}Puerto UDP:${RESET}   ${GREEN}$PORT${RESET}"

    echo -e \
        "${WHITE}Rango UDP:${RESET}    ${CYAN}$PORT_MIN-$PORT_MAX${RESET}"

    echo -e \
        "${WHITE}Arquitectura:${RESET} ${CYAN}$ARCH${RESET}"

    echo -e \
        "${WHITE}Binario:${RESET}      ${GRAY}$BIN${RESET}"

    line

    if [[ -f "$SERVICE_FILE" ]] ||
       [[ -x "$BIN" ]]; then

        echo -e \
            "${BLUE}${BOLD}⚙️ ADMINISTRACIÓN${RESET}"

        echo

        echo -e \
            " ${GREEN}[01]${RESET} 🔄 Reinstalar / Actualizar"

        echo -e \
            " ${GREEN}[02]${RESET} ♻️  Reiniciar Servicio"

        echo -e \
            " ${GREEN}[03]${RESET} 📊 Estado"

        echo -e \
            " ${GREEN}[04]${RESET} 🔐 Agregar Contraseña"

        echo -e \
            " ${GREEN}[05]${RESET} 🗑️  Eliminar Contraseña"

        echo -e \
            " ${GREEN}[06]${RESET} 📋 Listar Contraseñas"

        echo -e \
            " ${GREEN}[07]${RESET} 📜 Ver Logs"

        echo -e \
            " ${GREEN}[08]${RESET} 🔎 Diagnóstico"

        echo -e \
            " ${GREEN}[09]${RESET} 🖥️  Información VPS"

        echo -e \
            " ${RED}[10]${RESET} 🗑️  Desinstalar ZiVPN"

    else

        echo -e \
            "${BLUE}${BOLD}🚀 INSTALACIÓN${RESET}"

        echo

        echo -e \
            " ${GREEN}[01]${RESET} 🚀 Instalar ZiVPN"

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
        "${GRAY}KevinTech Multi Script • ZiVPN Manager v$VERSION${RESET}"

    echo

    read -r -p \
        "$(echo -e "${CYAN}${BOLD}➜ Seleccione una opción: ${RESET}")" \
        OP

    case "$OP" in

        1)

            install_zivpn

            ;;

        2)

            if [[ -f "$SERVICE_FILE" ]]; then

                restart_zivpn

            else

                check_zivpn

            fi

            ;;

        3)

            if [[ -f "$SERVICE_FILE" ]]; then

                status_zivpn

            else

                error_msg "ZiVPN no está instalado."

                sleep 1
            fi

            ;;

        4)

            add_zivpn_password

            ;;

        5)

            remove_zivpn_password

            ;;

        6)

            list_zivpn_passwords

            ;;

        7)

            view_zivpn_logs

            ;;

        8)

            check_zivpn

            ;;

        9)

            system_info

            ;;

        10)

            remove_zivpn

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