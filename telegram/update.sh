#!/usr/bin/env bash
set -Eeuo pipefail
D='/etc/kevintech/telegram'; systemctl stop kevintech-telegram || true
cp "$D/bot.py" "$D/bot.py.bak.$(date +%s)" 2>/dev/null || true
systemctl start kevintech-telegram
echo 'KevinTech Telegram actualizado.'
