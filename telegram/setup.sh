#!/usr/bin/env bash
set -Eeuo pipefail
ENV_DIR="/etc/kevintech/telegram"
ENV_FILE="$ENV_DIR/.env"

mkdir -p "$ENV_DIR" "$ENV_DIR/logs"
chmod 700 "$ENV_DIR"

echo "╔══════════════════════════════════════════╗"
echo "║       KEVINTECH TELEGRAM BOT             ║"
echo "║             CONFIGURACIÓN                ║"
echo "╚══════════════════════════════════════════╝"
echo
read -r -p "🤖 Token del bot: " BOT_TOKEN
read -r -p "👤 Telegram ID principal: " ADMIN_ID
read -r -p "👥 IDs adicionales (opcional, separados por coma): " ADMIN_IDS

[[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo "❌ Token inválido."; exit 1; }
[[ "$ADMIN_ID" =~ ^[0-9]+$ ]] || { echo "❌ Telegram ID inválido."; exit 1; }

printf 'BOT_TOKEN=%q\nADMIN_ID=%q\nADMIN_IDS=%q\n' \
  "$BOT_TOKEN" "$ADMIN_ID" "$ADMIN_IDS" > "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo "✅ Configuración guardada en $ENV_FILE"
