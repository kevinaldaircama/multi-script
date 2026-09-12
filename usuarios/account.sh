#!/bin/bash
# ==================================================
# KevinTech Multi Script Premium
# account.sh — Interfaz NO interactiva de cuentas
# v4: protocolos INDEPENDIENTES por cuenta
# Cada protocolo (hysteria/ss/btun/socks5) crea recurso propio
# (puerto/credencial) POR USUARIO. SSH usa la cuenta Linux.
# Registro de cuentas extra: $BASE/bot_ssh/cuentas_extra.conf (tipo|user|puerto|pass|extra)
#
# Uso:
#   account.sh add_ssh user pass dias limite
#   account.sh delete_ssh user
#   account.sh renew ssh user dias
#   account.sh hysteria_add user | hysteria_del user | hysteria_existe user
#   account.sh ss_add user       | ss_del user
#   account.sh btun_add user     | btun_del user
#   account.sh socks5_add user [pass] | socks5_del user
# ==================================================

# ---- Detección de base (MoviVIP / KevinTech) ----
if [ -d /etc/movivip ]; then
  BASE="/etc/movivip"
elif [ -d /etc/kevintech ]; then
  BASE="/etc/kevintech"
else
  BASE="/etc/movivip"
  mkdir -p "$BASE"
fi

CONFIG="$BASE/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

ACCT_USERS="$BASE/usuarios/account.sh"
REG="$BASE/bot_ssh/cuentas_extra.conf"
mkdir -p "$(dirname "$REG")"
touch "$REG"

ACTION="$1"
USER="$2"

log() { echo "$@"; }

puerto_libre() {
  # $1=inicio $2=fin -> primer puerto libre
  local ini="$1" fin="$2" p
  for p in $(seq "$ini" "$fin"); do
    if ! ss -lnt | awk '{print $4}' | grep -q ":$p$"; then
      echo "$p"
      return 0
    fi
  done
  echo ""
}

registrar_linea() { echo "$1" >> "$REG"; }
quitar_registro() { awk -F'|' -v u="$1" '$2 != u' "$REG" > /tmp/reg_tmp 2>/dev/null; mv /tmp/reg_tmp "$REG" 2>/dev/null; }

# ==================================================
# SSH (cuenta Linux)
# ==================================================
add_ssh() {
  local U="$2" P="$3" DIAS="$4" LIM="$5" FECHA
  [ -z "$U" ] && { echo "ERROR: falta user"; exit 1; }
  [ -z "$P" ] && { echo "ERROR: falta pass"; exit 1; }
  [ -z "$DIAS" ] && DIAS=7
  [ -z "$LIM" ] && LIM=0
  FECHA=$(date -d "+${DIAS} days" +"%Y-%m-%d")
  if id "$U" >/dev/null 2>&1; then
    echo "ERROR: user_exists:$U"
    exit 1
  fi
  useradd -e "$FECHA" -M -s /usr/sbin/nologin "$U" 2>/dev/null \
    || useradd -e "$FECHA" -M -s /bin/false "$U" 2>/dev/null
  echo "$U:$P" | chpasswd
  echo "OK:ssh_added:$U:$FECHA"
}

delete_ssh() {
  local U="$2"
  [ -z "$U" ] && { echo "ERROR: falta user"; exit 1; }
  pkill -u "$U" >/dev/null 2>&1
  userdel -f "$U" >/dev/null 2>&1 || userdel "$U" >/dev/null 2>&1
  echo "OK:ssh_removed:$U"
}

renew() {
  local U="$2" DIAS="$3" FECHA NEW
  [ -z "$U" ] && { echo "ERROR: falta user"; exit 1; }
  [ -z "$DIAS" ] && DIAS=7
  if ! id "$U" >/dev/null 2>&1; then
    # renueva el recurso individual si existe
    if grep -q "^hysteria|${U}|" "$REG" 2>/dev/null; then
      echo "OK:renew_extra:$U:$DIAS"
      exit 0
    fi
    echo "ERROR: user_not_found:$U"
    exit 1
  fi
  FECHA=$(date -d "+${DIAS} days" +"%Y-%m-%d")
  chage -E "$(date -d "$FECHA" +%Y-%m-%d)" "$U" 2>/dev/null || true
  NEW=$(date -d "$(chage -l "$U" | awk -F': ' '/Account expires/{print $2}')" +%Y-%m-%d 2>/dev/null)
  [ -z "$NEW" ] && NEW="$FECHA"
  echo "OK:renewed:$U:$NEW"
}

# ==================================================
# HYSTERIA individual
# ==================================================
hysteria_add() {
  # $2=user  (genera puerto libre + auth + obfs, escribe config por puerto)
  [ -z "$USER" ] && { echo "ERROR: falta user"; exit 1; }
  quote() { python3 -c "import sys,json; print(json.dumps(sys.argv[1]))" "$1"; }
  PORT=$(puerto_libre 21000 31000)
  [ -z "$PORT" ] && { echo "ERROR: sin puertos libres"; exit 1; }
  AUTH=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 18)
  OBFS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 18)
  CFG="/etc/hysteria/config.${PORT}.json"
  cat > "$CFG" <<EOF
{
"protocol":"udp",
"listen":":${PORT}",
"obfs":"${OBFS}",
"cert":"/etc/hysteria/server.crt",
"key":"/etc/hysteria/server.key",
"alpn":"h3",
"auth":{"mode":"password","config":{"password":"${AUTH}"}}
}
EOF
  if [ ! -f /etc/systemd/system/hysteria1@.service ]; then
    cat > /etc/systemd/system/hysteria1@.service <<UNITEOF
[Unit]
Description=MoviVIP Hysteria Server %i
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria1 -config /etc/hysteria/config.%i.json server
Restart=always
RestartSec=3
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
UNITEOF
    systemctl daemon-reload
  fi
  systemctl enable "hysteria1@${PORT}" >/dev/null 2>&1
  systemctl restart "hysteria1@${PORT}"
  sleep 1
  if systemctl is-active --quiet "hysteria1@${PORT}"; then
    ufw allow "${PORT}/udp" >/dev/null 2>&1 || true
    firewall-cmd --add-port="${PORT}/udp" --permanent >/dev/null 2>&1 || true
    iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT >/dev/null 2>&1 || true
    registrar_linea "hysteria|${USER}|${PORT}|${AUTH}|${OBFS}"
    echo "OK:hysteria_added:${USER}:${PORT}:${AUTH}:${OBFS}"
  else
    rm -f "$CFG"
    echo "ERROR: hysteria no arranco puerto ${PORT}"
    journalctl -u "hysteria1@${PORT}" -n 6 --no-pager 2>/dev/null | tail -6
    exit 1
  fi
}

hysteria_del() {
  LINE=$(grep "^hysteria|${USER}|" "$REG" | tail -1)
  [ -z "$LINE" ] && { echo "OK:hysteria_not_found:${USER}"; exit 0; }
  PORT=$(echo "$LINE" | cut -d'|' -f3)
  systemctl disable --now "hysteria1@${PORT}" >/dev/null 2>&1
  rm -f "/etc/hysteria/config.${PORT}.json"
  quitar_registro "$USER"
  iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT >/dev/null 2>&1 || true
  echo "OK:hysteria_removed:${USER}:${PORT}"
}

hysteria_existe() {
  grep -q "^hysteria|${USER}|" "$REG" 2>/dev/null && echo "YES" || echo "NO"
}

# ==================================================
# SHADOWSOCKS individual
# ==================================================
ss_add() {
  [ -z "$USER" ] && { echo "ERROR: falta user"; exit 1; }
  PORT=$(puerto_libre 12000 19000)
  [ -z "$PORT" ] && { echo "ERROR: sin puertos libres"; exit 1; }
  PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 18)
  CFG="/etc/shadowsocks-libev/${PORT}.json"
  cat > "$CFG" <<EOF
{
    "server": "0.0.0.0",
    "server_port": ${PORT},
    "password": "${PASS}",
    "method": "aes-256-gcm",
    "mode": "tcp_and_udp",
    "fast_open": true
}
EOF
  systemctl enable "shadowsocks-libev-server@${PORT}" >/dev/null 2>&1
  systemctl restart "shadowsocks-libev-server@${PORT}"
  sleep 1
  if systemctl is-active --quiet "shadowsocks-libev-server@${PORT}"; then
    ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
    ufw allow "${PORT}/udp" >/dev/null 2>&1 || true
    iptables -I INPUT -p tcp --dport "$PORT" -j ACCEPT >/dev/null 2>&1 || true
    iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT >/dev/null 2>&1 || true
    registrar_linea "ss|${USER}|${PORT}|${PASS}|"
    echo "OK:ss_added:${USER}:${PORT}:${PASS}"
  else
    rm -f "$CFG"
    echo "ERROR: ss no arranco puerto ${PORT}"
    exit 1
  fi
}

ss_del() {
  LINE=$(grep "^ss|${USER}|" "$REG" | tail -1)
  [ -z "$LINE" ] && { echo "OK:ss_not_found:${USER}"; exit 0; }
  PORT=$(echo "$LINE" | cut -d'|' -f3)
  systemctl disable --now "shadowsocks-libev-server@${PORT}" >/dev/null 2>&1
  rm -f "/etc/shadowsocks-libev/${PORT}.json"
  quitar_registro "$USER"
  iptables -D INPUT -p tcp --dport "$PORT" -j ACCEPT >/dev/null 2>&1 || true
  iptables -D INPUT -p udp --dport "$PORT" -j ACCEPT >/dev/null 2>&1 || true
  echo "OK:ss_removed:${USER}:${PORT}"
}

# ==================================================
# BTUN individual
# ==================================================
btun_add() {
  [ -z "$USER" ] && { echo "ERROR: falta user"; exit 1; }
  PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 14)
  AUTH_FILE="/etc/btun/users"
  [ -f "$AUTH_FILE" ] || touch "$AUTH_FILE"
  sed -i "/^${USER}:/d" "$AUTH_FILE" 2>/dev/null
  echo "${USER}:${PASS}" >> "$AUTH_FILE"
  systemctl restart btun >/dev/null 2>&1 || systemctl restart btun
  sleep 1
  if systemctl is-active --quiet btun; then
    registrar_linea "btun|${USER}|7900|${PASS}|"
    echo "OK:btun_added:${USER}:7900:${PASS}"
  else
    echo "ERROR: btun no arranco"
    exit 1
  fi
}

btun_del() {
  AUTH_FILE="/etc/btun/users"
  [ -f "$AUTH_FILE" ] && sed -i "/^${USER}:/d" "$AUTH_FILE"
  quitar_registro "$USER"
  systemctl restart btun >/dev/null 2>&1 || true
  echo "OK:btun_removed:${USER}"
}

# ==================================================
# SOCKS5 individual (dante usa cuentas Linux)
# ==================================================
socks5_add() {
  [ -z "$USER" ] && { echo "ERROR: falta user"; exit 1; }
  PASS="$3"
  [ -z "$PASS" ] && PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 14)
  if id "$USER" >/dev/null 2>&1; then
    echo "$USER:$PASS" | chpasswd
  else
    useradd -M -s /usr/sbin/nologin "$USER" 2>/dev/null \
      || useradd -M -s /bin/false "$USER" 2>/dev/null
    echo "$USER:$PASS" | chpasswd
  fi
  systemctl restart sockd >/dev/null 2>&1 || true
  sleep 1
  if systemctl is-active --quiet sockd; then
    registrar_linea "socks5|${USER}|1080|${PASS}|"
    echo "OK:socks_added:${USER}:1080:${PASS}"
  else
    echo "ERROR: sockd no arranco"
    exit 1
  fi
}

socks5_del() {
  userdel -r "$USER" >/dev/null 2>&1 || userdel "$USER" >/dev/null 2>&1 || true
  quitar_registro "$USER"
  systemctl restart sockd >/dev/null 2>&1 || true
  echo "OK:socks_removed:${USER}"
}

# ==================================================
# Despacho
# ==================================================
case "$ACTION" in
  add|add_ssh)          add_ssh "$@" ;;
  del|delete|delete_ssh) delete_ssh "$@" ;;
  renew)                renew "$@" ;;
  hysteria_add|hysteria_del|hysteria_existe) "$ACTION" "$@" ;;
  ss_add|ss_del)        "$ACTION" "$@" ;;
  btun_add|btun_del)    "$ACTION" "$@" ;;
  socks5_add|socks5_add) "$ACTION" "$@" ;;

  *)
    echo "Uso: account.sh <add_ssh|delete_ssh|renew|hysteria_add|hysteria_del|ss_add|ss_del|btun_add|btun_del|socks5_add|socks5_del> [args]"
    exit 1
    ;;
esac