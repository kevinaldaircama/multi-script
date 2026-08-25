#!/usr/bin/env bash
# Configurador seguro del bot para el VPS.

set -Eeuo pipefail

ENV_DIR="/etc/kevintech/telegram"
ENV_FILE="$ENV_DIR/.env"

mkdir -p "$ENV_DIR"
chmod 700 "$ENV_DIR"

echo
echo "╔══════════════════════════════════════════╗"
echo "║       KEVINTECH TELEGRAM BOT             ║"
echo "║          CONFIGURACIÓN VPS               ║"
echo "╚══════════════════════════════════════════╝"
echo

read -r -p "🤖 Token del bot: " BOT_TOKEN
read -r -p "👤 Telegram ID principal: " ADMIN_ID
read -r -p "👥 IDs adicionales (opcional, separados por coma): " ADMIN_IDS

[[ -n "$BOT_TOKEN" ]] || { echo "Token vacío."; exit 1; }
[[ "$ADMIN_ID" =~ ^[0-9]+$ ]] || { echo "ADMIN_ID debe ser numérico."; exit 1; }

cat > "$ENV_FILE" <<EOF
BOT_TOKEN="$BOT_TOKEN"
ADMIN_ID="$ADMIN_ID"
ADMIN_IDS="$ADMIN_IDS"
EOF

chmod 600 "$ENV_FILE"

echo
echo "✅ Configuración guardada."
echo "📁 $ENV_FILE"
echo "🔒 Permisos: 600"
echo
echo "No subas este archivo a GitHub."
