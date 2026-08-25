#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/etc/kevintech"
BOT_DIR="$BASE/telegram"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root."; exit 1; }

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl jq >/dev/null

mkdir -p "$BOT_DIR" "$BOT_DIR/logs" "$BOT_DIR/handlers"
cp "$SCRIPT_DIR/bot.sh" "$BOT_DIR/bot.sh"
cp "$SCRIPT_DIR/setup.sh" "$BOT_DIR/setup.sh"
cp "$SCRIPT_DIR/service.sh" "$BOT_DIR/service.sh"
chmod 700 "$BOT_DIR"
chmod 700 "$BOT_DIR"/*.sh

echo
echo "╔════════════════════════════════════════════╗"
echo "║ KEVINTECH TELEGRAM BOT - INSTALACIÓN      ║"
echo "╚════════════════════════════════════════════╝"
echo

bash "$BOT_DIR/setup.sh"

cat > /etc/systemd/system/kevintech-telegram.service <<EOF
[Unit]
Description=KevinTech Multi Script Telegram Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
ExecStart=$BOT_DIR/bot.sh
Restart=always
RestartSec=5
StandardOutput=append:$BOT_DIR/logs/bot.log
StandardError=append:$BOT_DIR/logs/bot.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kevintech-telegram.service

echo
echo "✅ Bot instalado e iniciado."
echo "📌 Estado: systemctl status kevintech-telegram --no-pager"
echo "📜 Logs:   journalctl -u kevintech-telegram -f"
