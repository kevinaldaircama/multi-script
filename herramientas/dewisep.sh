#!/bin/bash    
set -euo pipefail    
    
# =========================================================    
# INSTALADOR UNIVERSAL V8.0.5: BOT TELEGRAM DEPWISE SSH 💎 (GO EDITION)    
# =========================================================    
    
RED='\033[0;31m'    
GREEN='\033[0;32m'    
YELLOW='\033[1;33m'    
CYAN='\033[0;36m'    
NC='\033[0m'    
    
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }    
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }    
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }    
    
if [ "$EUID" -ne 0 ]; then    
  log_error "Por favor, ejecuta este script como root"    
  exit 1    
fi    
# Verificar que el sistema sea Ubuntu    
if [ -f /etc/os-release ]; then    
    . /etc/os-release    
    if [ "$ID" != "ubuntu" ]; then    
        log_error "Este instalador solo es compatible con Ubuntu."    
        exit 1    
    fi    
else    
    log_error "No se pudo detectar el sistema operativo."    
    exit 1    
fi    
PROJECT_DIR="/opt/depwise_bot"    
ENV_FILE="$PROJECT_DIR/.env"    
    
install_bot() {    
    echo -e "${GREEN}=================================================="    
    echo -e "       CONFIGURACION BOT DEPWISE V8.0 (GO)"    
    echo -e "==================================================${NC}"    
        apt update -y >/dev/null 2>&1    
    apt install -y curl jq >/dev/null 2>&1   
    
    # Cargar credenciales si ya existen para no volver a pedirlas    
    if [ -f "$ENV_FILE" ]; then    
        log_info "Cargando credenciales existentes desde $ENV_FILE..."    
        # Extraer valores evitando problemas de formateo    
        BOT_TOKEN=$(grep -E "^BOT_TOKEN=" "$ENV_FILE" | cut -d'=' -f2-)    
        ADMIN_ID=$(grep -E "^SUPER_ADMIN=" "$ENV_FILE" | cut -d'=' -f2-)    
    fi    
    
    if [ -z "${BOT_TOKEN:-}" ] || [ -z "${ADMIN_ID:-}" ]; then    
        read -p "Introduce el TOKEN: " BOT_TOKEN    
        read -p "Introduce tu Chat ID de Telegram: " ADMIN_ID    
    fi    
    
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then    
        log_error "Error: Datos incompletos."    
        exit 1    
    fi    
    
    # 1. Preparar Entorno    
    mkdir -p "$PROJECT_DIR"    
    echo "BOT_TOKEN=$BOT_TOKEN" > "$ENV_FILE"    
    echo "SUPER_ADMIN=$ADMIN_ID" >> "$ENV_FILE"    
    chmod 600 "$ENV_FILE"    
    
    log_info "Instalando dependencias base..."    
    apt update -y && apt install -y curl git make wget jq    
    
    # 2. Instalar Go si no existe    
    export PATH=$PATH:/usr/local/go/bin    
    if ! command -v go &> /dev/null; then    
        log_info "Instalando GoLang..."    
        wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz    
        rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz    
        rm go1.21.0.linux-amd64.tar.gz    
    fi    
    
    # 3. Clonar y Compilar Proyecto Repo    
    log_info "Descargando y compilando el Bot en Go..."    
    cd /tmp    
    rm -rf privanox-code    
    git clone https://github.com/kevinaldaircama/privanox-code.git || { log_error "Error al descargar el bot."; exit 1; }    
    cd privanox-code    
    
    log_info "Descargando módulos necesarios..."    
    go mod tidy    
    
    go build -o /usr/local/bin/depwise-bot cmd/depwise/main.go    
    chmod +x /usr/local/bin/depwise-bot    
    rm -rf /tmp/privanox-code    
    cd ~    
    
    # 3.5 Compilar BadVPN nativamente (Asegura compatibilidad con ARM64/AMD64)    
    if [ ! -f "/usr/bin/badvpn-udpgw" ]; then    
        log_info "Compilando motor BadVPN (puede tomar 1 minuto)..."    
        apt install -y cmake build-essential    
        cd /tmp    
        rm -rf badvpn    
        git clone https://github.com/ambrop72/badvpn.git    
        cd badvpn    
        cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 .    
        make    
        cp udpgw/badvpn-udpgw /usr/bin/badvpn-udpgw    
        chmod +x /usr/bin/badvpn-udpgw    
        cd ~    
        rm -rf /tmp/badvpn    
    fi    
    
    # Las herramientas de Escaner (assetfinder/httpx) se instalan desde    
    # el menú Protocolos del bot. No se instalan aquí para evitar bloqueos.    
    
    # 4. Servicio Systemd    
    log_info "Generando sistema daemon SystemD..."    
    cat << EOF > /etc/systemd/system/depwise.service    
[Unit]    
Description=Depwise Telegram Bot (Go Edition)    
After=network.target    
    
[Service]    
Type=simple    
User=root    
EnvironmentFile=$ENV_FILE    
Environment="GOMEMLIMIT=40MiB" "GOGC=20"    
ExecStart=/usr/local/bin/depwise-bot    
Restart=always    
RestartSec=5    
    
[Install]    
WantedBy=multi-user.target    
EOF    
    
    systemctl daemon-reload    
    systemctl enable depwise.service    
    systemctl restart depwise.service    
    echo -e "${GREEN}=================================================="    
    echo -e "       INSTALACION V8.0 COMPLETADA 💎"    
    echo -e "=================================================="    
    echo -e "El bot de Go está escuchando. Puedes enviar /start en Telegram.${NC}"    
}    
    
uninstall_all() {    
    echo -e "${RED}=================================================="    
    echo -e "       ⚠️ ADVERTENCIA: DESINSTALACIÓN TOTAL ⚠️"    
    echo -e "==================================================${NC}"    
    echo -e "Esto eliminará:"    
    echo -e "- El Bot de Telegram y sus configuraciones"    
    echo -e "- Todos los servicios VPN instalados por el bot (SlowDNS, ProxyDT, SSL, etc.)"    
    echo -e "- Los binarios descargados"    
    echo -e "- La base de datos de usuarios (bot_data.json)"    
        
    read -p "¿Estás completamente seguro de continuar? (escribe 'si' para confirmar): " confirm    
    if [ "$confirm" != "si" ]; then    
        log_info "Desinstalación cancelada."    
        return    
    fi    
    
    log_info "1/4 Deteniendo servicios..."    
    systemctl stop depwise.service 2>/dev/null || true    
    systemctl disable depwise.service 2>/dev/null || true    
        
    # Detener proxies y vpns    
    local services=("badvpn" "proxydt" "stunnel4" "dropbear" "falconproxy" "udpcustom" "zivpn" "nsd")    
    for svc in "${services[@]}"; do    
        systemctl stop "$svc" 2>/dev/null || true    
        systemctl disable "$svc" 2>/dev/null || true    
        rm -f "/etc/systemd/system/${svc}.service"    
    done    
    
    log_info "2/4 Eliminando archivos y binarios..."    
    rm -f /usr/local/bin/depwise-bot    
    rm -f /etc/systemd/system/depwise.service    
    rm -rf "$PROJECT_DIR"    
    rm -f /root/bot_data.json    
        
    # VPN Binaries & Configs    
    rm -f /usr/local/bin/badvpn-udpgw    
    rm -f /usr/bin/badvpn-udpgw    
    rm -f /usr/bin/badvpn    
    rm -f /usr/local/bin/proxydt    
    rm -f /usr/local/bin/falconproxy    
    rm -f /usr/local/bin/udpcustom    
    rm -rf /etc/zivpn    
    rm -f /usr/local/bin/zivpn    
    rm -f /etc/falconproxy.conf    
    rm -rf /etc/slowdns    
    
    log_info "3/4 Limpiando GoLang..."    
    rm -rf /usr/local/go    
    # Remover del PATH si está en bashrc (opcional/precaución)    
    sed -i '/\/usr\/local\/go\/bin/d' /root/.bashrc || true    
    
    log_info "4/4 Recargando demonios de sistema..."    
    systemctl daemon-reload    
    
    echo -e "${GREEN}=================================================="    
    echo -e "   ✅ DESINSTALACIÓN COMPLETADA EXITOSAMENTE  "    
    echo -e "==================================================${NC}"    
}    
    
enable_root() {    
    echo -e "${CYAN}=================================================="    
    echo -e "       HABILITANDO ACCESO ROOT POR SSH"    
    echo -e "==================================================${NC}"    
    read -p "Introduce una nueva contraseña para el usuario root: " ROOT_PASS    
    if [ -z "$ROOT_PASS" ]; then    
        log_error "La contraseña no puede estar vacía."    
        sleep 2    
        return    
    fi    
    echo "root:$ROOT_PASS" | chpasswd    
        
    # Habilitar PermitRootLogin    
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config    
    if ! grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then    
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config    
    fi    
        
    # Habilitar PasswordAuthentication    
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config    
    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then    
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config    
    fi    
        
    # Solucionar archivos de sobreescritura de AWS (Ubuntu 22.04+)    
    if [ -d "/etc/ssh/sshd_config.d" ]; then    
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true    
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true    
    fi    
        
    # Reiniciar servicio SSH (soportado en Ubuntu 22.04 y 24.04)    
    log_info "Reiniciando servicio SSH..."    
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null    
        
    log_info "Acceso root habilitado correctamente con contraseña."    
    sleep 2    
}    
    
    
show_menu() {    
    clear    
    echo -e "${CYAN}=================================================="    
    echo -e "       DEPWISE BOT INSTALLER (GO EDITION)"    
    echo -e "==================================================${NC}"    
    echo -e "  1. ${GREEN}Instalar / Actualizar Bot${NC}"    
    echo -e "  2. ${RED}Desinstalar Todo (Bot + VPNs)${NC}"    
    echo -e "  3. ${YELLOW}Habilitar Acceso Root SSH (AWS/VPS)${NC}"    
    echo -e "  4. Salir"    
    echo -e "${CYAN}==================================================${NC}"    
    read -p "Selecciona una opción [1-4]: " opt    
    
    case $opt in    
        1) install_bot ;;    
        2) uninstall_all ;;    
        3) enable_root ; show_menu ;;    
        4) exit 0 ;;    
        *) log_error "Opción inválida"; sleep 2; show_menu ;;    
    esac    
}    
    
show_menu    
