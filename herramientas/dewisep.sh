#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

PROJECT_DIR="/opt/depwise_bot"
ENV_FILE="$PROJECT_DIR/.env"

install_bot() {
echo -e "${GREEN}=================================================="
echo -e "      INSTALANDO BOT DEPWISE (GO EDITION)"
echo -e "==================================================${NC}"

apt update -y
apt install -y curl jq git wget make

export PATH=$PATH:/usr/local/go/bin

# Instalar Go si no existe
if ! command -v go &>/dev/null; then
    log_info "Instalando GoLang..."
    wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
    rm go1.21.0.linux-amd64.tar.gz
fi

# Pedir solo TOKEN y Chat ID
if [ -f "$ENV_FILE" ]; then
    BOT_TOKEN=$(grep -E "^BOT_TOKEN=" "$ENV_FILE" | cut -d'=' -f2- || true)
    ADMIN_ID=$(grep -E "^SUPER_ADMIN=" "$ENV_FILE" | cut -d'=' -f2- || true)
fi

if [ -z "${BOT_TOKEN:-}" ]; then
    read -p "Token del Bot: " BOT_TOKEN
fi

if [ -z "${ADMIN_ID:-}" ]; then
    read -p "Chat ID del Administrador: " ADMIN_ID
fi

mkdir -p "$PROJECT_DIR"

cat > "$ENV_FILE" <<EOF

BOT_TOKEN=$BOT_TOKEN
SUPER_ADMIN=$ADMIN_ID
EOF

chmod 600 "$ENV_FILE"

log_info "Descargando bot desde GitHub..."

cd /tmp
rm -rf privanox-code
git clone https://github.com/kevinaldaircama/privanox-code.git

cd /tmp/privanox-code

/usr/local/go/bin/go mod tidy
/usr/local/go/bin/go build -o /usr/local/bin/depwise-bot cmd/depwise/main.go

chmod +x /usr/local/bin/depwise-bot

rm -rf /tmp/privanox-code

log_info "Creando servicio systemd..."

cat > /etc/systemd/system/depwise.service <<EOF

[Unit]
Description=Depwise Telegram Bot (Go Edition)
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=$ENV_FILE
ExecStart=/usr/local/bin/depwise-bot
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable depwise.service
systemctl restart depwise.service

echo
echo -e "${GREEN}=================================================="
echo -e "       BOT INSTALADO CORRECTAMENTE"
echo -e "==================================================${NC}"
echo -e "Envía /start a tu bot en Telegram."

}

uninstall_bot() {
systemctl stop depwise.service 2>/dev/null || true
systemctl disable depwise.service 2>/dev/null || true
rm -f /etc/systemd/system/depwise.service
rm -f /usr/local/bin/depwise-bot
rm -rf "$PROJECT_DIR"
systemctl daemon-reload
echo "Bot desinstalado correctamente."
}

clear
echo -e "${CYAN}=================================================="
echo -e "        BOT TELEGRAM DEPWISE (GO EDITION)"
echo -e "==================================================${NC}"
echo "1) Instalar / Actualizar"
echo "2) Desinstalar"
echo "0) Volver"
echo

read -p "Selecciona una opción: " opt

case $opt in
1) install_bot ;;
2) uninstall_bot ;;
0) exit ;;
*) echo "Opción inválida" ;;
esac
