#!/usr/bin/env bash
set -Eeuo pipefail
DIR="/etc/kevintech/telegram"
ENV="$DIR/.env"
mkdir -p "$DIR/logs"
chmod 700 "$DIR" "$DIR/logs"
echo "╔════════════════════════════════════════════╗"
echo "║       KEVINTECH TELEGRAM BOT              ║"
echo "║       CONFIGURACIÓN DEL PROPIETARIO       ║"
echo "╚════════════════════════════════════════════╝"
echo
read -r -p "🤖 Token del bot: " TOKEN
read -r -p "👑 Telegram ID del dueño: " OWNER
read -r -p "👥 IDs adicionales (opcional): " ADMINS
[[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo "❌ Token inválido."; exit 1; }
[[ "$OWNER" =~ ^[0-9]+$ ]] || { echo "❌ Telegram ID inválido."; exit 1; }
printf 'BOT_TOKEN=%q\nADMIN_ID=%q\nADMIN_IDS=%q\n' "$TOKEN" "$OWNER" "$ADMINS" > "$ENV"
chmod 600 "$ENV"
echo "✅ Configuración guardada."
