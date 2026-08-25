#!/usr/bin/env bash
set -Eeuo pipefail
R='\033[0m'; G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; M='\033[1;35m'; Rr='\033[1;31m'; B='\033[1;37m'
D='/etc/kevintech/telegram'; mkdir -p "$D/logs"; chmod 700 "$D" "$D/logs"
echo -e "${C}╔════════════════════════════════════════════════════╗${R}"
echo -e "${C}║${M}          KEVINTECH TELEGRAM BOT v3${C}             ║${R}"
echo -e "${C}║${B}          CONFIGURACIÓN SEGURA VPS${C}              ║${R}"
echo -e "${C}╚════════════════════════════════════════════════════╝${R}"
echo -e "${Y}El token solo se guarda en $D/.env${R}"
read -r -p '🤖 Token del bot: ' TOKEN
read -r -p '👑 Telegram ID dueño: ' OWNER
read -r -p '👥 IDs adicionales (opcional): ' IDS
[[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo -e "${Rr}Token inválido${R}"; exit 1; }
[[ "$OWNER" =~ ^[0-9]+$ ]] || { echo -e "${Rr}ID inválido${R}"; exit 1; }
printf 'BOT_TOKEN=%q\nADMIN_ID=%q\nADMIN_IDS=%q\n' "$TOKEN" "$OWNER" "$IDS" > "$D/.env"; chmod 600 "$D/.env"
echo -e "${G}✔ Configuración guardada.${R}"
