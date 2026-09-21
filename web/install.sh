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

# Integra la web en HAProxy como una ruta HTTP/HTTPS adicional.
# IMPORTANTE: NO cambia los backends de protocolos existentes.
# La web se identifica por las rutas propias del panel y por /.
PATCH="$WEB/haproxy-web-route.sh"
cat > "$PATCH" <<'PATCHSCRIPT'
#!/bin/bash
set -euo pipefail
CFG=/etc/haproxy/haproxy.cfg
WEB_PORT=18080
BASE=/etc/kevintech
[[ -f "$CFG" ]] || exit 0

BACKUP="$CFG.web-backup"
cp -a "$CFG" "$BACKUP" 2>/dev/null || true

python3 - "$CFG" "$WEB_PORT" <<'PYCODE'
import sys
from pathlib import Path
cfg=Path(sys.argv[1]); port=sys.argv[2]
s=cfg.read_text()
BEGIN='# KEVINTECH_WEB_BEGIN'
END='# KEVINTECH_WEB_END'
while BEGIN in s and END in s:
    a=s.index(BEGIN)
    b=s.index(END,a)+len(END)
    s=s[:a]+s[b:]
marker='    use_backend websocket_backend if acl_upgrade acl_websocket\n'
block='''    # KEVINTECH_WEB_BEGIN
    # Solo rutas HTTP del panel; los protocolos conservan sus backends.
    acl kevintech_web_path path -i / /index.html
    acl kevintech_web_path path_beg /api/ /static/
    use_backend kevintech_web_backend if kevintech_web_path
    # KEVINTECH_WEB_END
'''
if marker not in s:
    raise SystemExit('No se encontró el punto seguro de integración en ssl_frontend')
if 'use_backend kevintech_web_backend if kevintech_web_path' not in s:
    s=s.replace(marker,block+marker,1)
backend='''
# KEVINTECH_WEB_BEGIN
backend kevintech_web_backend
    mode http
    option httpclose
    option forwardfor
    server kevintech_web 127.0.0.1:%s check
# KEVINTECH_WEB_END
''' % port
if 'backend kevintech_web_backend' not in s:
    s += backend
cfg.write_text(s)
PYCODE

if haproxy -c -f "$CFG" >/dev/null 2>&1; then
    systemctl reload haproxy
    echo "HAProxy: panel web integrado sin modificar los backends de protocolos."
else
    echo "ERROR: validación HAProxy falló; restaurando configuración anterior." >&2
    cp -a "$BACKUP" "$CFG"
    exit 2
fi
PATCHSCRIPT
chmod 755 "$PATCH"

cat > /etc/systemd/system/kevintech-web-route.service <<EOF2
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
EOF2

systemctl daemon-reload
systemctl enable kevintech-web-route.service >/dev/null 2>&1 || true
if systemctl is-active --quiet haproxy 2>/dev/null; then
    "$PATCH"
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
