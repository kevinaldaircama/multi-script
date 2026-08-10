#!/bin/bash

install_depwise() {
    if systemctl list-unit-files | grep -q "^depwise.service"; then
        echo "El Bot Depwise ya está instalado."
        return
    fi

    echo "Instalando Bot Depwise..."

    apt update -y
    apt install -y git curl wget make jq

    export PATH=$PATH:/usr/local/go/bin

    if ! command -v go >/dev/null; then
        wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        rm go1.21.0.linux-amd64.tar.gz
    fi

    read -p "Token del bot: " BOT_TOKEN
    read -p "Chat ID: " ADMIN_ID

    mkdir -p /opt/depwise_bot

    cat > /opt/depwise_bot/.env <<EOF
BOT_TOKEN=$BOT_TOKEN
SUPER_ADMIN=$ADMIN_ID
EOF

    rm -rf /tmp/privanox-code
    git clone https://github.com/kevinaldaircama/privanox-code.git /tmp/privanox-code
    cd /tmp/privanox-code || exit 1

    /usr/local/go/bin/go mod tidy
    /usr/local/go/bin/go build -o /usr/local/bin/depwise-bot cmd/depwise/main.go

    cat > /etc/systemd/system/depwise.service <<EOF
[Unit]
Description=Depwise Telegram Bot
After=network.target

[Service]
Type=simple
EnvironmentFile=/opt/depwise_bot/.env
ExecStart=/usr/local/bin/depwise-bot
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable depwise
    systemctl restart depwise

    echo
    echo "Bot instalado correctamente."
}

restart_depwise() {
    systemctl restart depwise
    echo "Bot reiniciado."
}

uninstall_depwise() {
    systemctl stop depwise 2>/dev/null
    systemctl disable depwise 2>/dev/null
    rm -f /etc/systemd/system/depwise.service
    rm -f /usr/local/bin/depwise-bot
    rm -rf /opt/depwise_bot
    systemctl daemon-reload
    echo "Bot desinstalado."
}

clear
echo "=============================="
echo "   Bot Telegram Depwise"
echo "=============================="
echo
echo "1) Instalar Bot"
echo "2) Reiniciar Bot"
echo "3) Desinstalar Bot"
echo "0) Volver"
echo

read -p "Opción: " op

case $op in
    1) install_depwise ;;
    2) restart_depwise ;;
    3) uninstall_depwise ;;
    0) exit ;;
    *) echo "Opción inválida" ;;
esac
