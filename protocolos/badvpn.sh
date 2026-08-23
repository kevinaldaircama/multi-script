#!/bin/bash

# ==============================================================
#              🛡️ KEVINTECH MULTI SCRIPT
#                    BADVPN UDPGW MANAGER
# ==============================================================
# Servicio 1 : badvpn-udpgw-7300
# Servicio 2 : badvpn-udpgw-7200
# Puertos    : 7300 / 7200
# ==============================================================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

VERSION="2.0"

SERVICE1="badvpn-udpgw-7300"
SERVICE2="badvpn-udpgw-7200"

PORT1="7300"
PORT2="7200"

BIN="/usr/local/bin/badvpn-udpgw"
SOURCE_DIR="/tmp/kevintech-badvpn"

SERVICE_FILE1="/etc/systemd/system/${SERVICE1}.service"
SERVICE_FILE2="/etc/systemd/system/${SERVICE2}.service"

REPO="https://github.com/ambrop72/badvpn.git"

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

if [[ $EUID -ne 0 ]]; then
    clear
    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este administrador requiere permisos de root.${RESET}"
    echo
    exit 1
fi

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

if [[ ! -f "$CONFIG" ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}✘ CONFIGURACIÓN NO ENCONTRADA${RESET}"
    echo
    echo -e "${WHITE}Archivo:${RESET}"
    echo -e "${YELLOW}$CONFIG${RESET}"
    echo

    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null

# ==============================================================
# FUNCIONES VISUALES
# ==============================================================

separator() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

success() {
    echo -e "${GREEN}✔ $1${RESET}"
}

error_msg() {
    echo -e "${RED}✘ $1${RESET}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

info() {
    echo -e "${CYAN}➜ $1${RESET}"
}

# ==============================================================
# CONFIG.CNF
# ==============================================================

set_config() {

    local VALUE="$1"

    if grep -q '^BADVPN=' "$CONFIG"; then
        sed -i "s/^BADVPN=.*/BADVPN=$VALUE/" "$CONFIG"
    else
        echo "BADVPN=$VALUE" >> "$CONFIG"
    fi
}

# ==============================================================
# SERVICIOS
# ==============================================================

service_exists() {
    systemctl cat "$1" &>/dev/null
}

service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# ==============================================================
# ESTADO REAL DE BADVPN
# ==============================================================

get_status() {

    if service_active "$SERVICE1" && service_active "$SERVICE2"; then
        echo -e "${GREEN}● ACTIVO${RESET}"

    elif service_active "$SERVICE1" || service_active "$SERVICE2"; then
        echo -e "${YELLOW}● PARCIAL${RESET}"

    elif [[ "${BADVPN:-OFF}" == "ON" ]]; then
        echo -e "${RED}● DETENIDO${RESET}"

    else
        echo -e "${GRAY}● DESINSTALADO${RESET}"
    fi
}

# ==============================================================
# COMPROBAR BINARIO
# ==============================================================

binary_installed() {

    [[ -x "$BIN" ]]
}

# ==============================================================
# COMPROBAR PUERTO
# ==============================================================

port_status() {

    local PORT="$1"

    if ss -lunpt 2>/dev/null | grep -q ":$PORT "; then
        echo -e "${GREEN}● ESCUCHANDO${RESET}"
    else
        echo -e "${RED}● CERRADO${RESET}"
    fi
}

# ==============================================================
# DEPENDENCIAS
# ==============================================================

install_dependencies() {

    info "Actualizando lista de paquetes..."

    if ! apt-get update -y >/dev/null 2>&1; then
        error_msg "No se pudo actualizar APT."
        return 1
    fi

    info "Instalando dependencias..."

    if ! apt-get install -y \
        git \
        cmake \
        build-essential \
        >/dev/null 2>&1; then

        error_msg "No se pudieron instalar las dependencias."
        return 1
    fi

    success "Dependencias instaladas."

    return 0
}

# ==============================================================
# COMPILAR BADVPN
# ==============================================================

build_badvpn() {

    info "Preparando código fuente..."

    rm -rf "$SOURCE_DIR"

    if ! git clone --depth 1 "$REPO" "$SOURCE_DIR" >/dev/null 2>&1; then
        error_msg "No se pudo descargar BadVPN."
        return 1
    fi

    cd "$SOURCE_DIR" || return 1

    rm -rf build

    mkdir -p build

    cd build || return 1

    info "Configurando compilación..."

    if ! cmake .. \
        -DBUILD_NOTHING_BY_DEFAULT=1 \
        -DBUILD_UDPGW=1 \
        >/dev/null 2>&1; then

        error_msg "CMake no pudo configurar BadVPN."
        return 1
    fi

    info "Compilando BadVPN..."

    if ! make -j"$(nproc)" >/dev/null 2>&1; then
        error_msg "La compilación de BadVPN falló."
        return 1
    fi

    if [[ ! -f "udpgw/badvpn-udpgw" ]]; then
        error_msg "No se encontró el binario generado."
        return 1
    fi

    install -m 755 \
        "udpgw/badvpn-udpgw" \
        "$BIN"

    if [[ ! -x "$BIN" ]]; then
        error_msg "No se pudo instalar el binario."
        return 1
    fi

    success "BadVPN compilado correctamente."

    return 0
}

# ==============================================================
# SYSTEMD
# ==============================================================

create_services() {

    info "Configurando servicios systemd..."

    cat > "$SERVICE_FILE1" <<EOF
[Unit]
Description=KevinTech BadVPN UDPGW - Puerto 7300
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 127.0.0.1:$PORT1 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    cat > "$SERVICE_FILE2" <<EOF
[Unit]
Description=KevinTech BadVPN UDPGW - Puerto 7200
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 127.0.0.1:$PORT2 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    if ! systemctl enable "$SERVICE1" "$SERVICE2" >/dev/null 2>&1; then
        error_msg "No se pudieron habilitar los servicios."
        return 1
    fi

    success "Servicios configurados."

    return 0
}

# ==============================================================
# INICIAR BADVPN
# ==============================================================

start_badvpn() {

    info "Iniciando servicios..."

    systemctl restart "$SERVICE1" "$SERVICE2"

    sleep 1

    if service_active "$SERVICE1" &&
       service_active "$SERVICE2"; then

        set_config "ON"

        success "BadVPN está funcionando correctamente."

        return 0
    fi

    set_config "OFF"

    error_msg "Uno o ambos servicios no pudieron iniciarse."

    return 1
}

# ==============================================================
# INSTALAR BADVPN
# ==============================================================

install_badvpn() {

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}🚀 INSTALANDO BADVPN UDPGW${RESET}               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if ! install_dependencies; then
        return 1
    fi

    if ! build_badvpn; then
        return 1
    fi

    if ! create_services; then
        return 1
    fi

    if ! start_badvpn; then
        return 1
    fi

    rm -rf "$SOURCE_DIR"

    return 0
}

# ==============================================================
# REINICIAR
# ==============================================================

restart_badvpn() {

    echo
    info "Reiniciando servicios BadVPN..."

    systemctl restart "$SERVICE1" "$SERVICE2"

    sleep 1

    if service_active "$SERVICE1" &&
       service_active "$SERVICE2"; then

        set_config "ON"

        success "Los dos servicios están activos."

    else

        set_config "OFF"

        error_msg "No se pudieron iniciar correctamente ambos servicios."
    fi
}

# ==============================================================
# ESTADO DETALLADO
# ==============================================================

show_status() {

    clear

    local STATUS

    STATUS=$(get_status)

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}📊 BADVPN STATUS${RESET}                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                    ${GRAY}v$VERSION${RESET}                             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE} Estado general :${RESET} $STATUS"
    echo -e "${WHITE} Binario        :${RESET} $(
        if binary_installed; then
            echo -e "${GREEN}● INSTALADO${RESET}"
        else
            echo -e "${RED}● NO ENCONTRADO${RESET}"
        fi
    )"

    separator

    echo -e "${WHITE} 🔌 Puerto $PORT1 :${RESET} $(port_status "$PORT1")"
    echo -e "${WHITE} 🔌 Puerto $PORT2 :${RESET} $(port_status "$PORT2")"

    separator

    echo -e "${WHITE} Servicio $PORT1 :${RESET}"

    if service_exists "$SERVICE1"; then
        systemctl is-active "$SERVICE1" 2>/dev/null || true
    else
        echo -e "${GRAY}No instalado${RESET}"
    fi

    echo

    echo -e "${WHITE} Servicio $PORT2 :${RESET}"

    if service_exists "$SERVICE2"; then
        systemctl is-active "$SERVICE2" 2>/dev/null || true
    else
        echo -e "${GRAY}No instalado${RESET}"
    fi

    echo
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

uninstall_badvpn() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${RED}${BOLD}🗑️ DESINSTALAR BADVPN${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${YELLOW}Se eliminarán:${RESET}"
    echo -e "  • Servicios systemd"
    echo -e "  • Binario BadVPN"
    echo -e "  • Configuración BADVPN"
    echo

    read -rp "$(echo -e "${RED}¿Continuar? [s/N]: ${RESET}")" CONFIRM

    if [[ ! "$CONFIRM" =~ ^[SsYy]$ ]]; then
        warning "Operación cancelada."
        sleep 1
        return
    fi

    echo

    info "Deteniendo servicios..."

    systemctl stop "$SERVICE1" "$SERVICE2" 2>/dev/null

    info "Deshabilitando servicios..."

    systemctl disable "$SERVICE1" "$SERVICE2" 2>/dev/null

    info "Eliminando archivos systemd..."

    rm -f "$SERVICE_FILE1"
    rm -f "$SERVICE_FILE2"

    info "Eliminando binario..."

    rm -f "$BIN"

    rm -rf "$SOURCE_DIR"

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE1" "$SERVICE2" 2>/dev/null

    set_config "OFF"

    echo

    success "BadVPN fue eliminado correctamente."

    sleep 2
}

# ==============================================================
# MENÚ
# ==============================================================

while true; do

    clear

    BADVPN="${BADVPN:-OFF}"

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🌐 BADVPN MANAGER${RESET}                      ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                ${GRAY}UDP GATEWAY v$VERSION${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${WHITE} Estado:${RESET}       $(get_status)"
    echo -e "${WHITE} Binario:${RESET}      $(
        if binary_installed; then
            echo -e "${GREEN}● INSTALADO${RESET}"
        else
            echo -e "${GRAY}● NO INSTALADO${RESET}"
        fi
    )"

    echo -e "${WHITE} Puerto 1:${RESET}     ${CYAN}$PORT1${RESET}  $(port_status "$PORT1")"
    echo -e "${WHITE} Puerto 2:${RESET}     ${CYAN}$PORT2${RESET}  $(port_status "$PORT2")"

    separator

    if [[ "$BADVPN" == "ON" ]] ||
       service_exists "$SERVICE1" ||
       service_exists "$SERVICE2"; then

        echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN${RESET}"
        echo
        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🔄 Reinstalar / Actualizar"
        echo -e "  ${GREEN}${BOLD}[02]${RESET} ♻️  Reiniciar servicios"
        echo -e "  ${GREEN}${BOLD}[03]${RESET} 📊 Ver estado detallado"
        echo -e "  ${GREEN}${BOLD}[04]${RESET} 🗑️  Desinstalar BadVPN"

    else

        echo -e "${BLUE}${BOLD}  🚀 INSTALACIÓN${RESET}"
        echo
        echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar BadVPN"

    fi

    echo
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Regresar al Menú de Protocolos"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN • v${VERSION}${RESET}"
    echo

    read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1)

            clear

            if install_badvpn; then

                echo
                echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
                echo -e "${GREEN}║${RESET}              ${BOLD}✔ BADVPN INSTALADO${RESET}                      ${GREEN}║${RESET}"
                echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${RESET}"
                echo -e "${GREEN}║${RESET}  UDPGW 1  →  127.0.0.1:$PORT1                             ${GREEN}║${RESET}"
                echo -e "${GREEN}║${RESET}  UDPGW 2  →  127.0.0.1:$PORT2                             ${GREEN}║${RESET}"
                echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

            else

                echo
                error_msg "La instalación de BadVPN falló."

            fi

            pause
            ;;

        2)

            restart_badvpn
            pause
            ;;

        3)

            show_status
            ;;

        4)

            uninstall_badvpn
            ;;

        0)

            clear
            exec bash "$BASE/protocolos/menu.sh"
            ;;

        "")

            ;;

        *)

            echo
            error_msg "Opción inválida."
            sleep 1
            ;;

    esac

done