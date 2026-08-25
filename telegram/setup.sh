#!/usr/bin/env bash
set -Eeuo pipefail
C='\033[1;36m'; G='\033[1;92m'; Y='\033[1;93m'; R='\033[1;91m'; M='\033[1;95m'; W='\033[1;97m'; Z='\033[0m'; D='/etc/kevintech/telegram'; E="$D/.env"
mkdir -p "$D/logs"; chmod 700 "$D" "$D/logs"
echo -e "${C}╔════════════════════════════════════════════════════════════╗${Z}"; echo -e "${C}║${M}          🤖 KEVINTECH TELEGRAM • SETUP V4             ${C}║${Z}"; echo -e "${C}║${W}              CONFIGURACIÓN VPS PREMIUM                 ${C}║${Z}"; echo -e "${C}╚════════════════════════════════════════════════════════════╝${Z}"
if [[ -f "$E" ]]; then echo -e "${G}✔ Configuración actual encontrada.${Z}"; read -r -p '¿Reemplazar token/IDs? [s/N]: ' r; [[ "$r" =~ ^[sS]$ ]] || { chmod 600 "$E"; exit 0; }; fi
read -r -p '🤖 Token del bot: ' TOKEN; read -r -p '👑 Telegram ID dueño: ' OWNER; read -r -p '👥 IDs adicionales (opcional): ' IDS
[[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo -e "${R}✘ Token inválido.${Z}"; exit 1; }; [[ "$OWNER" =~ ^[0-9]+$ ]] || { echo -e "${R}✘ ID inválido.${Z}"; exit 1; }
umask 077; printf 'BOT_TOKEN=%q\nADMIN_ID=%q\nADMIN_IDS=%q\n' "$TOKEN" "$OWNER" "$IDS" > "$E"; chmod 600 "$E"
if command -v curl >/dev/null; then echo -e "${C}➜ Verificando Telegram...${Z}"; curl -fsS --max-time 8 "https://api.telegram.org/bot${TOKEN}/getMe" | grep -q '"ok":true' && echo -e "${G}✔ Token aceptado por Telegram.${Z}" || { echo -e "${R}✘ Token rechazado.${Z}"; exit 1; }; fi
echo -e "${G}✔ Configuración lista.${Z}"
