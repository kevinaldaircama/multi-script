#!/bin/bash
set -euo pipefail

# =========================================================
#   INSTALADOR ZIVPN PANEL v1.0.0
#   Uso: bash <(curl -sL URL_DEL_SCRIPT)
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

if [ "$EUID" -ne 0 ]; then
    log_error "Por favor, ejecuta este script como root"
    exit 1
fi

REPO_URL="https://github.com/Depwisescript/zivpn-panel.git"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="zivpn-panel"
BUILD_DIR="/tmp/zivpn-panel-build"
BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

install_panel() {
    echo -e "${CYAN}=================================================="
    echo -e "        INSTALADOR ZIVPN PANEL v1.0.0"
    echo -e "==================================================${NC}"

    # 1. Dependencias
    log_info "Instalando dependencias..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y curl git wget > /dev/null 2>&1

    # 2. Instalar Go si no existe
    export PATH=$PATH:/usr/local/go/bin
    if ! command -v go &> /dev/null; then
        log_info "Instalando Go 1.21..."

        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            GO_ARCH="amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            GO_ARCH="arm64"
        else
            log_error "Arquitectura no soportada: $ARCH"
            exit 1
        fi

        wget -q "https://go.dev/dl/go1.21.0.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz
        rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz

        # Add to PATH permanently
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
    fi

    log_info "Go version: $(go version)"

    # 3. Clonar y compilar
    log_info "Descargando ZiVPN Panel..."
    rm -rf "$BUILD_DIR"
    git clone "$REPO_URL" "$BUILD_DIR" || { log_error "Error al clonar el repositorio."; exit 1; }

    log_info "Compilando..."
    cd "$BUILD_DIR"
    go build -o "${INSTALL_DIR}/${BINARY_NAME}" ./cmd/zivpn-panel/
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    # 4. Limpiar
    rm -rf "$BUILD_DIR"

    echo -e "${GREEN}=================================================="
    echo -e "   ✅ INSTALACIÓN COMPLETADA"
    echo -e "==================================================${NC}"
    if [[ -f "$CONFIG" ]]; then
    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG"
    else
        echo "ZIPVPN=ON" >> "$CONFIG"
    fi
fi

echo -e ""
echo -e "  Ejecuta el panel con:  ${CYAN}zivpn-panel${NC}"
echo -e ""
}

uninstall_panel() {
    echo -e "${RED}=================================================="
    echo -e "   ⚠️  DESINSTALACIÓN DEL PANEL"
    echo -e "==================================================${NC}"

    read -p "¿Estás seguro? (escribe 'si' para confirmar): " confirm
    if [ "$confirm" != "si" ]; then
        log_info "Cancelado."
        return
    fi

    log_info "Eliminando binario..."
rm -f "${INSTALL_DIR}/${BINARY_NAME}"

if [[ -f "$CONFIG" ]]; then
    if grep -q "^ZIPVPN=" "$CONFIG"; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=OFF/' "$CONFIG"
    else
        echo "ZIPVPN=OFF" >> "$CONFIG"
    fi
fi

    echo -e "${GREEN}=================================================="
    echo -e "   ✅ PANEL DESINSTALADO"
    echo -e "==================================================${NC}"
    echo -e ""
    echo -e "  Nota: ZiVPN y sus usuarios NO fueron eliminados."
    echo -e "  Para desinstalar ZiVPN, usa la opción 2 del panel antes de desinstalar."
    echo -e ""
}

show_menu() {
    clear
    echo -e "${CYAN}=================================================="
    echo -e "        ZIVPN PANEL - INSTALADOR"
    echo -e "==================================================${NC}"
    echo -e "  1. ${GREEN}Instalar / Actualizar Panel${NC}"
    echo -e "  2. ${RED}Desinstalar Panel${NC}"
    echo -e "  3. Salir"
    echo -e "${CYAN}==================================================${NC}"
    read -p "Selecciona una opción [1-3]: " opt

    case $opt in
        1) install_panel ;;
        2) uninstall_panel ;;
        3) exit 0 ;;
        *) log_error "Opción inválida"; sleep 2; show_menu ;;
    esac
}

show_menu
