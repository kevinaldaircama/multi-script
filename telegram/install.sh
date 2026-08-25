#!/usr/bin/env bash
set -Eeuo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; TARGET="/etc/kevintech/telegram"
[[ $EUID -eq 0 ]] || { echo "Ejecuta como root."; exit 1; }
command -v python3 >/dev/null || { apt-get update -qq; apt-get install -y python3; }
mkdir -p "$TARGET/logs"
if [[ "$SRC" != "$TARGET" ]]; then
  install -m 700 "$SRC/bot.py" "$TARGET/bot.py"
  install -m 700 "$SRC/setup.sh" "$TARGET/setup.sh"
  install -m 700 "$SRC/install.sh" "$TARGET/install.sh"
fi
chmod 700 "$TARGET/bot.py" "$TARGET/setup.sh" "$TARGET/install.sh"
[[ -f "$TARGET/.env" ]] || bash "$TARGET/setup.sh"
cat > /etc/systemd/system/kevintech-telegram.service <<EOF
[Unit]
Description=KevinTech Multi Script Telegram Bot
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
WorkingDirectory=$TARGET
ExecStart=/usr/bin/python3 $TARGET/bot.py
Restart=always
RestartSec=3
StandardOutput=append:$TARGET/logs/bot.log
StandardError=append:$TARGET/logs/bot.log
[Install]
WantedBy=multi-user.target
EOF
chmod 600 "$TARGET/.env"
systemctl daemon-reload
systemctl enable --now kevintech-telegram.service
systemctl --no-pager --full status kevintech-telegram.service || true
