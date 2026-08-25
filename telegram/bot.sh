#!/usr/bin/env bash
# =========================================================
# KEVINTECH TELEGRAM BOT
# Integrated Telegram interface for Multi Script
# Credentials are loaded from /etc/kevintech/telegram/.env
# =========================================================

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/etc/kevintech/telegram/.env"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/bot.log"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE" 2>/dev/null || true

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

die() {
    log "ERROR: $*"
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ -f "$ENV_FILE" ]] || die "Configuración no encontrada: $ENV_FILE"
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${BOT_TOKEN:?Falta BOT_TOKEN en $ENV_FILE}"
: "${ADMIN_ID:?Falta ADMIN_ID en $ENV_FILE}"

API="https://api.telegram.org/bot${BOT_TOKEN}"
OFFSET=0

api() {
    local method="$1"
    shift
    curl -fsS --max-time 35 -X POST "$API/$method" "$@"
}

send_message() {
    local chat_id="$1"
    local text="$2"
    local keyboard="${3:-}"
    if [[ -n "$keyboard" ]]; then
        api sendMessage \
            -d "chat_id=$chat_id" \
            --data-urlencode "text=$text" \
            --data-urlencode "reply_markup=$keyboard" >/dev/null
    else
        api sendMessage \
            -d "chat_id=$chat_id" \
            --data-urlencode "text=$text" >/dev/null
    fi
}

main_menu() {
    printf '%s' '{"inline_keyboard":[[{"text":"👤 Usuarios","callback_data":"users"},{"text":"🌐 Protocolos","callback_data":"protocols"}],[{"text":"📊 Estado VPS","callback_data":"status"},{"text":"🛠 Herramientas","callback_data":"tools"}],[{"text":"ℹ️ Información","callback_data":"info"}]]}'
}

users_menu() {
    printf '%s' '{"inline_keyboard":[[{"text":"➕ Crear usuario","callback_data":"users_add"},{"text":"🗑 Eliminar","callback_data":"users_delete"}],[{"text":"📋 Lista","callback_data":"users_list"},{"text":"🟢 Online","callback_data":"users_online"}],[{"text":"🔄 Renovar","callback_data":"users_renew"},{"text":"🔙 Volver","callback_data":"home"}]]}'
}

protocols_menu() {
    printf '%s' '{"inline_keyboard":[[{"text":"🔐 OpenSSH","callback_data":"proto_ssh"},{"text":"🟡 Dropbear","callback_data":"proto_dropbear"}],[{"text":"🔵 OpenVPN","callback_data":"proto_openvpn"},{"text":"🟣 Xray/V2Ray","callback_data":"proto_xray"}],[{"text":"🔎 CheckUser","callback_data":"proto_checkuser"},{"text":"🔙 Volver","callback_data":"home"}]]}'
}

tools_menu() {
    printf '%s' '{"inline_keyboard":[[{"text":"🔥 Firewall","callback_data":"tool_firewall"},{"text":"⚡ Reiniciar","callback_data":"tool_restart"}],[{"text":"📈 Recursos","callback_data":"status"},{"text":"🔙 Volver","callback_data":"home"}]]}'
}

authorized() {
    local id="$1"
    [[ "$id" == "$ADMIN_ID" ]] && return 0

    if [[ -n "${ADMIN_IDS:-}" ]]; then
        IFS=',' read -ra ids <<< "$ADMIN_IDS"
        for allowed in "${ids[@]}"; do
            [[ "$id" == "$allowed" ]] && return 0
        done
    fi
    return 1
}

vps_status() {
    local host uptime cpu mem disk
    host="$(hostname)"
    uptime="$(uptime -p 2>/dev/null || true)"
    cpu="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo '?')"
    mem="$(free -m | awk '/^Mem:/ {printf "%s/%s MB (%s%%)", $3,$2,($3/$2)*100}' 2>/dev/null || echo '?')"
    disk="$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}' 2>/dev/null || echo '?')"

    printf '🖥️ <b>KEVINTECH VPS</b>\n\nHost: <code>%s</code>\n⏱ Uptime: <code>%s</code>\n⚙️ Load: <code>%s</code>\n🧠 RAM: <code>%s</code>\n💾 Disco: <code>%s</code>' \
        "$host" "$uptime" "$cpu" "$mem" "$disk"
}

handle_callback() {
    local chat_id="$1"
    local callback_id="$2"
    local data="$3"

    api answerCallbackQuery -d "callback_query_id=$callback_id" >/dev/null 2>&1 || true

    case "$data" in
        home)
            send_message "$chat_id" "🏠 <b>MENÚ PRINCIPAL</b>\n\nSelecciona una opción:" "$(main_menu)"
            ;;
        users)
            send_message "$chat_id" "👤 <b>GESTIÓN DE USUARIOS</b>\n\nSelecciona una opción:" "$(users_menu)"
            ;;
        protocols)
            send_message "$chat_id" "🌐 <b>PROTOCOLOS</b>\n\nSelecciona una opción:" "$(protocols_menu)"
            ;;
        tools)
            send_message "$chat_id" "🛠 <b>HERRAMIENTAS</b>\n\nSelecciona una opción:" "$(tools_menu)"
            ;;
        status)
            send_message "$chat_id" "$(vps_status)" "$(main_menu)"
            ;;
        info)
            send_message "$chat_id" "🤖 <b>KEVINTECH TELEGRAM BOT</b>\n\nBot integrado en Multi Script.\n\n🔐 Acceso protegido por Telegram ID." "$(main_menu)"
            ;;
        *)
            send_message "$chat_id" "ℹ️ Esta función está preparada para conectarse al módulo correspondiente." "$(main_menu)"
            ;;
    esac
}

handle_update() {
    local update="$1"
    local chat_id callback_id data text from_id

    callback_id="$(jq -r '.callback_query.id // empty' <<< "$update")"
    if [[ -n "$callback_id" ]]; then
        chat_id="$(jq -r '.callback_query.message.chat.id // empty' <<< "$update")"
        data="$(jq -r '.callback_query.data // empty' <<< "$update")"
        from_id="$(jq -r '.callback_query.from.id // empty' <<< "$update")"

        if ! authorized "$from_id"; then
            api answerCallbackQuery \
                -d "callback_query_id=$callback_id" \
                --data-urlencode "text=⛔ Acceso denegado" \
                -d "show_alert=true" >/dev/null 2>&1 || true
            log "Unauthorized callback from Telegram ID $from_id"
            return
        fi

        handle_callback "$chat_id" "$callback_id" "$data"
        return
    fi

    chat_id="$(jq -r '.message.chat.id // empty' <<< "$update")"
    text="$(jq -r '.message.text // empty' <<< "$update")"
    from_id="$(jq -r '.message.from.id // empty' <<< "$update")"

    [[ -n "$chat_id" ]] || return

    if ! authorized "$from_id"; then
        send_message "$chat_id" "⛔ <b>Acceso denegado.</b>\n\nTu Telegram ID no está autorizado."
        log "Unauthorized message from Telegram ID $from_id"
        return
    fi

    case "$text" in
        /start|/menu)
            send_message "$chat_id" "🤖 <b>KEVINTECH MULTI SCRIPT</b>\n\nBienvenido. Selecciona una opción:" "$(main_menu)"
            ;;
        /id)
            send_message "$chat_id" "🆔 Tu Telegram ID es: <code>$from_id</code>"
            ;;
        *)
            send_message "$chat_id" "Usa /menu para abrir el panel." "$(main_menu)"
            ;;
    esac
}

log "Bot iniciado"

# Dependencias mínimas.
command -v curl >/dev/null || die "curl no está instalado."
command -v jq >/dev/null || die "jq no está instalado."

# Evita recibir mensajes antiguos al iniciar.
if initial="$(api getUpdates -d 'timeout=0' -d 'limit=1' 2>/dev/null)"; then
    last_id="$(jq -r '.result[-1].update_id // empty' <<< "$initial")"
    [[ -n "$last_id" ]] && OFFSET=$((last_id + 1))
fi

while true; do
    response="$(api getUpdates \
        -d "offset=$OFFSET" \
        -d 'timeout=30' \
        -d 'allowed_updates=["message","callback_query"]' 2>/dev/null || true)"

    if [[ -z "$response" ]]; then
        sleep 2
        continue
    fi

    ok="$(jq -r '.ok // false' <<< "$response" 2>/dev/null || echo false)"
    [[ "$ok" == "true" ]] || {
        log "Telegram API error: $response"
        sleep 5
        continue
    }

    while IFS= read -r update; do
        [[ -z "$update" ]] && continue
        id="$(jq -r '.update_id' <<< "$update")"
        OFFSET=$((id + 1))
        handle_update "$update" &
    done < <(jq -c '.result[]' <<< "$response")
done
