#!/usr/bin/env bash
set -Eeuo pipefail
R='\033[0m'; G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; Rr='\033[1;31m'; B='\033[1;37m'
[[ $EUID -eq 0 ]] || { echo -e "${Rr}Ejecuta como root.${R}"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"; D='/etc/kevintech/telegram'
mkdir -p "$D/logs"; command -v python3 >/dev/null || { apt-get update -qq; apt-get install -y python3; }
install -m 700 "$SRC/bot.py" "$D/bot.py"; install -m 700 "$SRC/setup.sh" "$D/setup.sh"; install -m 700 "$SRC/service.sh" "$D/service.sh"; install -m 700 "$SRC/health.sh" "$D/health.sh"
[[ -f "$D/.env" ]] || bash "$D/setup.sh"
cat > /etc/systemd/system/kevintech-telegram.service <<EOF
[Unit]
Description=KevinTech Telegram Bot v3
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
WorkingDirectory=$D
ExecStart=/usr/bin/python3 $D/bot.py
Restart=always
RestartSec=2
TimeoutStopSec=10
StandardOutput=append:$D/logs/bot.log
StandardError=append:$D/logs/bot.log
[Install]
WantedBy=multi-user.target
EOF
chmod 600 "$D/.env"; systemctl daemon-reload; systemctl enable --now kevintech-telegram.service
sleep 1
systemctl --no-pager --full status kevintech-telegram.service || true
echo -e "${G}✔ KEVINTECH TELEGRAM v3 ACTIVO${R}"
echo -e "${C}Logs:${R} journalctl -u kevintech-telegram -f"
