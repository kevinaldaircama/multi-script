#!/usr/bin/env bash
set -Eeuo pipefail
G='\033[1;32m'; R='\033[0m'; Y='\033[1;33m'; C='\033[1;36m'
echo -e "${C}╔════════ KEVINTECH TELEGRAM HEALTH ════════╗${R}"
if systemctl is-active --quiet kevintech-telegram; then echo -e "${G}✔ Bot: ACTIVO${R}"; else echo -e "${Y}⚠ Bot: INACTIVO${R}"; fi
python3 -m py_compile /etc/kevintech/telegram/bot.py && echo -e "${G}✔ Python: OK${R}"
ss -lntp 2>/dev/null | head -20
echo -e "${C}Logs:${R} /etc/kevintech/telegram/logs/bot.log"
