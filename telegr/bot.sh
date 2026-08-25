#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/etc/kevintech"
BOT_DIR="$BASE/telegram"
ENV_FILE="$BOT_DIR/.env"
LOG_FILE="$BOT_DIR/logs/bot.log"

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root."; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "Falta $ENV_FILE. Ejecuta setup.sh."; exit 1; }
command -v curl >/dev/null || { echo "Falta curl."; exit 1; }
command -v jq >/dev/null || { echo "Falta jq."; exit 1; }

# shellcheck disable=SC1090
source "$ENV_FILE"
: "${BOT_TOKEN:?BOT_TOKEN no configurado}"
: "${ADMIN_ID:?ADMIN_ID no configurado}"

API="https://api.telegram.org/bot${BOT_TOKEN}"
OFFSET=0
mkdir -p "$BOT_DIR/logs"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"; }

api(){
  local method="$1"; shift
  curl -fsS --connect-timeout 10 --max-time 40 -X POST "$API/$method" "$@"
}

auth(){
  local id="$1"
  [[ "$id" == "$ADMIN_ID" ]] && return 0
  [[ -n "${ADMIN_IDS:-}" ]] || return 1
  IFS=',' read -ra A <<< "$ADMIN_IDS"
  for x in "${A[@]}"; do [[ "$id" == "$x" ]] && return 0; done
  return 1
}

kb(){
  case "$1" in
    main) printf '%s' '{"inline_keyboard":[[{"text":"👤 Usuarios","callback_data":"users"},{"text":"🌐 Protocolos","callback_data":"protocols"}],[{"text":"📊 Estado VPS","callback_data":"status"},{"text":"🛠 Herramientas","callback_data":"tools"}],[{"text":"🔄 Servicios","callback_data":"services"},{"text":"ℹ️ Info","callback_data":"info"}]]}' ;;
    users) printf '%s' '{"inline_keyboard":[[{"text":"➕ Crear","callback_data":"u_add"},{"text":"🗑 Eliminar","callback_data":"u_del"}],[{"text":"📋 Lista","callback_data":"u_list"},{"text":"🟢 Online","callback_data":"u_online"}],[{"text":"🔄 Renovar","callback_data":"u_renew"},{"text":"🔒 Bloquear","callback_data":"u_block"}],[{"text":"💾 Backup","callback_data":"u_backup"},{"text":"🔙 Volver","callback_data":"home"}]]}' ;;
    protocols) printf '%s' '{"inline_keyboard":[[{"text":"🔐 OpenSSH","callback_data":"p_ssh"},{"text":"🟡 Dropbear","callback_data":"p_dropbear"}],[{"text":"🔵 OpenVPN","callback_data":"p_openvpn"},{"text":"🟣 Xray/V2Ray","callback_data":"p_xray"}],[{"text":"🔎 CheckUser","callback_data":"p_checkuser"},{"text":"🐌 SlowDNS","callback_data":"p_slowdns"}],[{"text":"🌐 SSL/WebSocket","callback_data":"p_ssl"},{"text":"🔙 Volver","callback_data":"home"}]]}' ;;
    tools) printf '%s' '{"inline_keyboard":[[{"text":"🔥 Firewall","callback_data":"t_firewall"},{"text":"⚡ Reiniciar","callback_data":"t_restart"}],[{"text":"📈 Recursos","callback_data":"status"},{"text":"🔄 Actualizar","callback_data":"t_update"}],[{"text":"🔙 Volver","callback_data":"home"}]]}' ;;
    services) printf '%s' '{"inline_keyboard":[[{"text":"🔐 SSH","callback_data":"s_ssh"},{"text":"🟡 Dropbear","callback_data":"s_dropbear"}],[{"text":"🔵 OpenVPN","callback_data":"s_openvpn"},{"text":"🟣 Xray","callback_data":"s_xray"}],[{"text":"🔎 CheckUser","callback_data":"s_checkuser"},{"text":"🔙 Volver","callback_data":"home"}]]}' ;;
  esac
}

send(){
  local chat="$1" text="$2" markup="${3:-}"
  if [[ -n "$markup" ]]; then
    api sendMessage -d "chat_id=$chat" --data-urlencode "text=$text" \
      --data-urlencode "parse_mode=HTML" --data-urlencode "reply_markup=$markup" >/dev/null
  else
    api sendMessage -d "chat_id=$chat" --data-urlencode "text=$text" \
      --data-urlencode "parse_mode=HTML" >/dev/null
  fi
}

edit(){
  local chat="$1" msg="$2" text="$3" markup="${4:-}"
  if [[ -n "$markup" ]]; then
    api editMessageText -d "chat_id=$chat" -d "message_id=$msg" \
      --data-urlencode "text=$text" --data-urlencode "parse_mode=HTML" \
      --data-urlencode "reply_markup=$markup" >/dev/null
  else
    api editMessageText -d "chat_id=$chat" -d "message_id=$msg" \
      --data-urlencode "text=$text" --data-urlencode "parse_mode=HTML" >/dev/null
  fi
}

svc_state(){
  local svc="$1"
  systemctl is-active --quiet "$svc" && echo "🟢 ACTIVO" || echo "🔴 INACTIVO"
}

status_text(){
  local mem disk load
  load="$(awk '{print $1}' /proc/loadavg)"
  mem="$(free -m | awk '/^Mem:/ {printf "%s/%s MB (%d%%)",$3,$2,($3*100)/$2}')"
  disk="$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
  cat <<EOF
📊 <b>ESTADO DEL VPS</b>

🖥 Host: <code>$(hostname)</code>
⏱ Uptime: <code>$(uptime -p)</code>
⚙️ Load: <code>$load</code>
🧠 RAM: <code>$mem</code>
💾 Disco: <code>$disk</code>

🔐 SSH: $(svc_state ssh)
🟡 Dropbear: $(svc_state dropbear)
🔵 OpenVPN: $(svc_state openvpn)
EOF
}

# Intenta localizar módulos existentes sin modificar el proyecto.
find_module(){
  local name="$1"
  find "$BASE" -type f -name "$name" -print -quit 2>/dev/null || true
}

run_safe_module(){
  local file="$1"
  shift || true
  [[ -n "$file" && -f "$file" ]] || return 1
  timeout 30s bash "$file" "$@" 2>&1 | tail -c 3500
}

module_response(){
  local key="$1" file out
  case "$key" in
    p_ssh) file="$(find_module openssh.sh)" ;;
    p_dropbear) file="$(find_module dropbear.sh)" ;;
    p_openvpn) file="$(find_module openvpn.sh)" ;;
    p_xray) file="$(find_module v2ray.sh)"; [[ -n "$file" ]] || file="$(find_module xray.sh)" ;;
    p_checkuser) file="$(find_module checkuser.sh)" ;;
    p_slowdns) file="$(find_module slowdns.sh)" ;;
    p_ssl) file="$(find_module ssl.sh)" ;;
    u_list) file="$(find_module list.sh)" ;;
    u_online) file="$(find_module online.sh)" ;;
    u_add) file="$(find_module add.sh)" ;;
    u_del) file="$(find_module delete.sh)" ;;
    u_renew) file="$(find_module edit.sh)" ;;
    u_block) file="$(find_module block.sh)" ;;
    u_backup) file="$(find_module backup.sh)" ;;
    t_firewall) file="$(find_module firewall.sh)" ;;
    t_restart) file="$(find_module reiniciar.sh)" ;;
    t_update) file="$(find_module update.sh)" ;;
    *) return 2 ;;
  esac

  if [[ -z "$file" ]]; then
    printf '⚠️ <b>Módulo no encontrado</b>\n\nLa función <code>%s</code> aún no tiene un archivo compatible en este proyecto.' "$key"
    return 0
  fi

  out="$(run_safe_module "$file" || true)"
  if [[ -n "$out" ]]; then
    printf '🧩 <b>Resultado</b>\n\n<pre>%s</pre>' "$(printf '%s' "$out" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g')"
  else
    printf '✅ Módulo ejecutado:\n<code>%s</code>' "$file"
  fi
}

callback(){
  local chat="$1" msg="$2" from="$3" data="$4"
  api answerCallbackQuery -d "callback_query_id=$msg" >/dev/null 2>&1 || true
  [[ "$from" =~ ^[0-9]+$ ]] || return
  auth "$from" || return

  case "$data" in
    home) send "$chat" "🏠 <b>KEVINTECH MULTI SCRIPT</b>\n\nSelecciona una sección:" "$(kb main)" ;;
    users) send "$chat" "👤 <b>USUARIOS</b>\n\nGestión del sistema de usuarios:" "$(kb users)" ;;
    protocols) send "$chat" "🌐 <b>PROTOCOLOS</b>\n\nSelecciona un módulo:" "$(kb protocols)" ;;
    tools) send "$chat" "🛠 <b>HERRAMIENTAS</b>" "$(kb tools)" ;;
    services) send "$chat" "🔄 <b>SERVICIOS</b>\n\nEstado rápido:" "$(kb services)" ;;
    status) send "$chat" "$(status_text)" "$(kb main)" ;;
    info) send "$chat" "🤖 <b>KEVINTECH TELEGRAM</b>\n\nInterfaz integrada para Multi Script.\n\n🔐 Acceso por Telegram ID." "$(kb main)" ;;
    s_ssh) send "$chat" "🔐 <b>OpenSSH:</b> $(svc_state ssh)" "$(kb services)" ;;
    s_dropbear) send "$chat" "🟡 <b>Dropbear:</b> $(svc_state dropbear)" "$(kb services)" ;;
    s_openvpn) send "$chat" "🔵 <b>OpenVPN:</b> $(svc_state openvpn)" "$(kb services)" ;;
    s_xray) send "$chat" "🟣 <b>Xray:</b> $(svc_state xray)" "$(kb services)" ;;
    s_checkuser) send "$chat" "🔎 <b>CheckUser:</b> $(svc_state checkuser)" "$(kb services)" ;;
    u_*|p_*|t_*)
      local result
      result="$(module_response "$data")"
      send "$chat" "$result" "$(kb main)"
      ;;
    *) send "$chat" "⚠️ Acción no reconocida." "$(kb main)" ;;
  esac
}

handle(){
  local u="$1" chat from text cbid data msgid
  cbid="$(jq -r '.callback_query.id // empty' <<<"$u")"
  if [[ -n "$cbid" ]]; then
    chat="$(jq -r '.callback_query.message.chat.id' <<<"$u")"
    msgid="$(jq -r '.callback_query.message.message_id' <<<"$u")"
    from="$(jq -r '.callback_query.from.id' <<<"$u")"
    data="$(jq -r '.callback_query.data' <<<"$u")"
    if auth "$from"; then callback "$chat" "$cbid" "$from" "$data"
    else api answerCallbackQuery -d "callback_query_id=$cbid" --data-urlencode "text=⛔ Acceso denegado" -d "show_alert=true" >/dev/null 2>&1 || true
    fi
    return
  fi

  chat="$(jq -r '.message.chat.id // empty' <<<"$u")"
  from="$(jq -r '.message.from.id // empty' <<<"$u")"
  text="$(jq -r '.message.text // empty' <<<"$u")"
  [[ -n "$chat" ]] || return

  if ! auth "$from"; then
    send "$chat" "⛔ <b>Acceso denegado.</b>\n\nTu Telegram ID no está autorizado."
    return
  fi

  case "$text" in
    /start|/menu) send "$chat" "🤖 <b>KEVINTECH MULTI SCRIPT</b>\n\nBienvenido al panel de administración:" "$(kb main)" ;;
    /id) send "$chat" "🆔 Tu Telegram ID:\n<code>$from</code>" ;;
    *) send "$chat" "Usa /menu para abrir el panel." "$(kb main)" ;;
  esac
}

log "Bot iniciado"
old="$(api getUpdates -d timeout=0 -d limit=1 2>/dev/null || true)"
last="$(jq -r '.result[-1].update_id // empty' <<<"$old" 2>/dev/null || true)"
[[ -n "$last" ]] && OFFSET=$((last+1))

while true; do
  response="$(api getUpdates -d "offset=$OFFSET" -d timeout=30 -d 'allowed_updates=["message","callback_query"]' 2>/dev/null || true)"
  [[ -n "$response" ]] || { sleep 2; continue; }
  [[ "$(jq -r '.ok // false' <<<"$response")" == "true" ]] || { log "API: $response"; sleep 5; continue; }
  while IFS= read -r u; do
    [[ -z "$u" ]] && continue
    id="$(jq -r '.update_id' <<<"$u")"
    OFFSET=$((id+1))
    handle "$u" &
  done < <(jq -c '.result[]' <<<"$response")
done
