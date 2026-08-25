#!/usr/bin/env bash
set -Eeuo pipefail
BOT_DIR="/etc/kevintech/telegram"
ENV="$BOT_DIR/.env"
mkdir -p "$BOT_DIR/logs"
chmod 700 "$BOT_DIR" "$BOT_DIR/logs"
echo "╔══════════════════════════════════════════╗"
echo "║       KEVINTECH TELEGRAM BOT             ║"
echo "║          INSTALACIÓN COMPLETA            ║"
echo "╚══════════════════════════════════════════╝"
echo
read -r -p "🤖 Token del bot: " TOKEN
read -r -p "👑 Telegram ID del dueño: " OWNER
read -r -p "👥 IDs adicionales (opcional, separados por coma): " ADMINS
[[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo "❌ Token inválido"; exit 1; }
[[ "$OWNER" =~ ^[0-9]+$ ]] || { echo "❌ ID inválido"; exit 1; }
printf 'BOT_TOKEN=%q\nADMIN_ID=%q\nADMIN_IDS=%q\n' "$TOKEN" "$OWNER" "$ADMINS" > "$ENV"
chmod 600 "$ENV"
echo "✅ Credenciales guardadas."
echo "🔒 $ENV (600)"
