#!/bin/bash
set -euo pipefail
BASE="/etc/kevintech"
WEB="$BASE/web"
SERVICE="kevintech-web"
PORT="18080"

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root."; exit 1; }
[[ -f "$WEB/server.py" ]] || { echo "No existe $WEB/server.py"; exit 1; }

mkdir -p "$WEB/static" "$WEB/logs"
chmod 755 "$WEB" "$WEB/static"

# Credenciales del panel. Se pueden predefinir para instalaciones automáticas.
USER="${WEB_ADMIN_USER:-}"
PASS="${WEB_ADMIN_PASSWORD:-}"
EXISTING_HASH=""
if [[ -f "$WEB/.env" && -z "$USER" && -z "$PASS" ]]; then
  USER=$(awk -F= '/^WEB_ADMIN_USER=/{print $2}' "$WEB/.env" | tail -n1)
  EXISTING_HASH=$(awk -F= '/^WEB_ADMIN_HASH=/{print $2}' "$WEB/.env" | tail -n1)
fi
if [[ -z "$USER" ]]; then
  read -r -p "Usuario administrador web [admin]: " USER
  USER="${USER:-admin}"
fi
if ! [[ "$USER" =~ ^[a-zA-Z0-9._-]{3,32}$ ]]; then echo "Usuario web inválido."; exit 1; fi
if [[ -z "$PASS" && -n "$EXISTING_HASH" ]]; then
  HASH="$EXISTING_HASH"
else
  if [[ -z "$PASS" ]]; then
    read -r -s -p "Contraseña administrador web (mín. 10): " PASS; echo
    if [[ ${#PASS} -lt 10 ]]; then echo "Contraseña demasiado corta."; exit 1; fi
  fi
  HASH=$(python3 - "$PASS" <<'PY'
import sys,base64,hashlib,secrets
p=sys.argv[1].encode(); salt=secrets.token_bytes(16)
d=hashlib.pbkdf2_hmac('sha256',p,salt,310000)
print(base64.urlsafe_b64encode(salt+d).decode())
PY
  )
fi

cat > "$WEB/.env" <<EOF
WEB_ADMIN_USER=$USER
WEB_ADMIN_HASH=$HASH
KEVINTECH_WEB_PORT=$PORT
EOF
chmod 600 "$WEB/.env"

[[ -s "$WEB/secret.key" ]] || { python3 - <<'PY' > "$WEB/secret.key"
import secrets,sys
sys.stdout.buffer.write(secrets.token_bytes(32))
PY
}
chmod 600 "$WEB/secret.key"

cat > "/etc/systemd/system/$SERVICE.service" <<EOF
[Unit]
Description=KevinTech Web Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$WEB
EnvironmentFile=$WEB/.env
ExecStart=/usr/bin/python3 $WEB/server.py
Restart=always
RestartSec=3
StartLimitIntervalSec=0
NoNewPrivileges=false
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=$BASE /run /tmp

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE.service"
sleep 1
systemctl is-active --quiet "$SERVICE.service" || { journalctl -u "$SERVICE" -n 30 --no-pager; exit 1; }

# Integra la web en HAProxy sin tocar los módulos originales. Se enruta por SNI del dominio
# únicamente en el frontend TLS interno; 80/8080 siguen perteneciendo al túnel existente.
PATCH="$WEB/haproxy-web-route.sh"
cat > "$PATCH" <<'PATCHSCRIPT'
#!/bin/bash
set -euo pipefail
CFG=/etc/haproxy/haproxy.cfg
WEB_PORT=18080
BASE=/etc/kevintech
[[ -f "$CFG" ]] || exit 0
source "$BASE/config.conf" 2>/dev/null || true
DOMAIN="${SERVER_DOMAIN:-}"
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || exit 0
cp -a "$CFG" "$CFG.web-backup" 2>/dev/null || true
# Idempotencia: elimina bloques previos que haya creado este instalador.
sed -i '/# KEVINTECH_WEB_BEGIN/,/# KEVINTECH_WEB_END/d' "$CFG"
# Inserta ACL antes del default_backend del frontend TLS interno y un backend al final.
python3 - "$CFG" "$DOMAIN" "$WEB_PORT" <<'PY'
import sys
p,domain,port=sys.argv[1:]
s=open(p).read()
needle='    use_backend websocket_backend if acl_upgrade acl_websocket\n'
block=f'''    # KEVINTECH_WEB_BEGIN\n    acl kevintech_web_sni ssl_fc_sni -i {domain}\n    use_backend kevintech_web_backend if kevintech_web_sni\n    # KEVINTECH_WEB_END\n'''
if needle in s and 'use_backend kevintech_web_backend if kevintech_web_sni' not in s:
    s=s.replace(needle,block+needle,1)
backend=f'''\n# KEVINTECH_WEB_BEGIN\nbackend kevintech_web_backend\n    mode http\n    option httpclose\n    option forwardfor\n    server kevintech_web 127.0.0.1:{port} check\n# KEVINTECH_WEB_END\n'''
if 'backend kevintech_web_backend' not in s:
    s += backend
open(p,'w').write(s)
PY
if haproxy -c -f "$CFG" >/dev/null 2>&1; then
  systemctl reload haproxy 2>/dev/null || systemctl restart haproxy 2>/dev/null || true
  echo "HAProxy: ruta web aplicada para $DOMAIN"
else
  echo "ADVERTENCIA: la configuración HAProxy no se modificó porque la validación falló." >&2
  cp -a "$CFG.web-backup" "$CFG" 2>/dev/null || true
  exit 2
fi
PATCHSCRIPT
chmod 755 "$PATCH"

cat > /etc/systemd/system/kevintech-web-route.service <<EOF
[Unit]
Description=KevinTech Web HAProxy route
After=network-online.target haproxy.service kevintech-web.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$PATCH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
mkdir -p /etc/systemd/system/haproxy.service.d
cat > /etc/systemd/system/haproxy.service.d/20-kevintech-web.conf <<EOF
[Service]
ExecStartPost=$PATCH
EOF

systemctl daemon-reload
systemctl enable kevintech-web-route.service >/dev/null 2>&1 || true

if systemctl is-active --quiet haproxy 2>/dev/null && [[ -f /etc/haproxy/haproxy.cfg ]]; then
  "$PATCH" || true
fi
systemctl start kevintech-web-route.service >/dev/null 2>&1 || true

echo
 echo "============================================================"
echo " KevinTech Web instalado"
echo " Ruta local : http://127.0.0.1:$PORT"
echo " Usuario    : $USER"
echo " Dominio    : $(awk -F'=' '/^SERVER_DOMAIN=/{gsub(/\"/,"",$2);print $2}' "$BASE/config.conf" 2>/dev/null || true)"
echo " HTTPS      : por HAProxy/SNI cuando el dominio coincide"
echo " Servicio   : $SERVICE.service (Restart=always)"
echo "============================================================"
