#!/bin/bash
set -u
BASE="/etc/kevintech"; WEB="$BASE/web"; DATA="$WEB/data"; SERVICE="kevintech-web.service"; ACME_SERVICE="kevintech-acme.service"; PORT="18080"; ACME_PORT="18081"; HAPROXY="/etc/haproxy/haproxy.cfg"; PEM="/etc/haproxy/kevintech-panel.pem"; DOMAIN_FILE="/etc/haproxy/kevintech-panel-domain"; ACME_ROOT="/var/www/letsencrypt"; HOOK="/etc/letsencrypt/renewal-hooks/deploy/kevintech-panel.sh"; CONFIG="$BASE/config.conf"
red='\e[1;91m'; green='\e[1;92m'; cyan='\e[1;96m'; yellow='\e[1;93m'; reset='\e[0m'
root_check(){ [[ $EUID -eq 0 ]] || { echo -e "${red}Ejecuta como root.${reset}"; exit 1; }; }
configured_domain(){ local d=""; [[ -f "$CONFIG" ]] && d="$(awk -F'=' '/^SERVER_DOMAIN=/{gsub(/^"|"$/,"",$2); print $2; exit}' "$CONFIG" 2>/dev/null)"; printf '%s' "$d"; }
current_domain(){ [[ -f "$DOMAIN_FILE" ]] && tr -d '[:space:]' < "$DOMAIN_FILE" || true; }
write_domain_config(){ printf '%s\n' "$1" > "$DOMAIN_FILE"; chmod 600 "$DOMAIN_FILE"; }
write_service(){ cat > "/etc/systemd/system/$SERVICE" <<EOF
[Unit]
Description=KevinTech Web Panel
After=network-online.target haproxy.service
Wants=network-online.target
[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WEB
Environment=PYTHONUNBUFFERED=1
Environment=KEVINTECH_WEB_PORT=$PORT
Environment=KEVINTECH_WEB_PREFIX=/
ExecStart=/usr/bin/python3 $WEB/server.py
Restart=on-failure
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=20
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null 2>&1 || true; }
write_acme_service(){ cat > "/etc/systemd/system/$ACME_SERVICE" <<EOF
[Unit]
Description=KevinTech ACME webroot helper
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=$ACME_ROOT
ExecStart=/usr/bin/python3 -m http.server $ACME_PORT --directory $ACME_ROOT --bind 127.0.0.1
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable "$ACME_SERVICE" >/dev/null 2>&1 || true; }
write_renew_hook(){ mkdir -p /etc/letsencrypt/renewal-hooks/deploy; cat > "$HOOK" <<'EOF'
#!/bin/sh
set -eu
DOMAIN_FILE=/etc/haproxy/kevintech-panel-domain
PEM=/etc/haproxy/kevintech-panel.pem
HAPROXY=/etc/haproxy/haproxy.cfg
[ -s "$DOMAIN_FILE" ] || exit 0
domain=$(tr -d '[:space:]' < "$DOMAIN_FILE")
cat "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/letsencrypt/live/$domain/privkey.pem" > "$PEM"
chmod 600 "$PEM"
if haproxy -c -f "$HAPROXY" >/dev/null 2>&1; then systemctl reload haproxy; fi
EOF
chmod 700 "$HOOK"; }
patch_haproxy(){ [[ -f "$HAPROXY" ]] || return 0; local domain="$1"; cp -a "$HAPROXY" "$HAPROXY.kevintech-web.bak" 2>/dev/null || true; DOMAIN="$domain" PEM="$PEM" PORT="$PORT" HAPROXY="$HAPROXY" python3 - <<'PY'
import os,subprocess,shutil
from pathlib import Path
p=Path(os.environ['HAPROXY']); s=p.read_text(errors='ignore'); domain=os.environ['DOMAIN']; pem=os.environ['PEM']; port=os.environ['PORT']
lines=s.splitlines(True); out=[]; skip=False
for line in lines:
 st=line.strip()
 if st=='backend kevintech_web': skip=True; continue
 if skip:
  if line and not line[0].isspace() and st: skip=False
  else: continue
 if any(x in line for x in ['acl acl_panel_sni ','use_backend kevintech_web if acl_panel_sni','acl kevintech_web_host ','acl kevintech_web_path ','use_backend kevintech_web if kevintech_web']): continue
 out.append(line)
s=''.join(out); out=[]
for line in s.splitlines(True):
 if line.strip().startswith('bind abns@haproxy-https') and 'ssl' in line and pem not in line: line=line.rstrip('\n')+' crt '+pem+'\n'
 out.append(line)
s=''.join(out); lines=s.splitlines(True); out=[]; inserted=False; inf=False
for line in lines:
 st=line.strip()
 if st.startswith('frontend '): inf=True
 elif st.startswith(('backend ','listen ','global','defaults')): inf=False
 if inf and st=='use_backend grpc_backend if acl_http2' and not inserted:
  out += ['    acl acl_panel_sni ssl_fc_sni -i '+domain+'\n','    use_backend kevintech_web if acl_panel_sni\n']; inserted=True
 out.append(line)
if not inserted:
 lines=out; out=[]; inf=False
 for line in lines:
  st=line.strip()
  if st.startswith('frontend '): inf=True
  elif st.startswith(('backend ','listen ','global','defaults')): inf=False
  if inf and st.startswith('default_backend ') and not inserted:
   out += ['    acl acl_panel_sni ssl_fc_sni -i '+domain+'\n','    use_backend kevintech_web if acl_panel_sni\n']; inserted=True
  out.append(line)
s=''.join(out)
if 'acl acl_acme path_beg /.well-known/acme-challenge/' not in s:
 lines=s.splitlines(True); out=[]; done=False; inf=False
 for line in lines:
  st=line.strip()
  if st.startswith('frontend '): inf=True
  elif st.startswith(('backend ','listen ','global','defaults')): inf=False
  if inf and st.startswith('acl acl_upgrade') and not done:
   out += ['    acl acl_acme path_beg /.well-known/acme-challenge/\n','    use_backend acme_backend if acl_acme\n']; done=True
  out.append(line)
 s=''.join(out)
if 'backend acme_backend' not in s: s+='\nbackend acme_backend\n    mode http\n    option http-server-close\n    server acme_server 127.0.0.1:18081 check\n'
s+='\nbackend kevintech_web\n    mode http\n    option http-server-close\n    option forwardfor\n    server kevintech_web 127.0.0.1:'+port+' check\n'
p.write_text(s); r=subprocess.run(['haproxy','-c','-f',str(p)],capture_output=True,text=True)
if r.returncode:
 b=Path(str(p)+'.kevintech-web.bak')
 if b.exists(): shutil.copy2(b,p)
 print(r.stdout+r.stderr); raise SystemExit(3)
r=subprocess.run(['systemctl','reload','haproxy'],capture_output=True,text=True)
if r.returncode: print(r.stdout+r.stderr); raise SystemExit(4)
PY
}
ensure_cert(){ local domain="$1"; mkdir -p "$ACME_ROOT/.well-known/acme-challenge"; systemctl start "$ACME_SERVICE" >/dev/null 2>&1 || true; if [[ -s "/etc/letsencrypt/live/$domain/fullchain.pem" && -s "/etc/letsencrypt/live/$domain/privkey.pem" ]]; then :; else command -v certbot >/dev/null 2>&1 || { apt-get update -y && apt-get install -y certbot || return 1; }; local email; read -rp "Correo para Let's Encrypt: " email; [[ -n "$email" ]] || return 1; certbot certonly --webroot -w "$ACME_ROOT" -d "$domain" --non-interactive --agree-tos --no-eff-email -m "$email" || return 1; fi; cat "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/letsencrypt/live/$domain/privkey.pem" > "$PEM"; chmod 600 "$PEM"; write_domain_config "$domain"; write_renew_hook; }
prompt_fresh(){ echo; read -rp "Usuario administrador [admin]: " WEB_ADMIN_USER; WEB_ADMIN_USER="${WEB_ADMIN_USER:-admin}"; while [[ ! "$WEB_ADMIN_USER" =~ ^[A-Za-z0-9_.-]{3,32}$ ]]; do read -rp "Usuario inválido: " WEB_ADMIN_USER; done; while true; do read -rsp "Contraseña administrador (mín. 8): " WEB_ADMIN_PASS; echo; [[ ${#WEB_ADMIN_PASS} -ge 8 ]] && break; done; local old="$(configured_domain)"; old="${old:-$(current_domain)}"; if [[ -n "$old" ]]; then read -rp "Dominio HTTPS [ENTER = $old]: " WEB_DOMAIN; WEB_DOMAIN="${WEB_DOMAIN:-$old}"; else read -rp "Dominio HTTPS: " WEB_DOMAIN; fi; WEB_DOMAIN="$(echo "$WEB_DOMAIN" | tr -d '[:space:]')"; export WEB_ADMIN_USER WEB_ADMIN_PASS WEB_DOMAIN; }
save_credentials(){ python3 - "$DATA/config.json" "$1" "$2" "$3" <<'PY'
import json,sys,hashlib,base64,secrets,os
p,u,pw,domain=sys.argv[1:]; os.makedirs(os.path.dirname(p),exist_ok=True)
try:d=json.load(open(p))
except:d={}
salt=secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); d.setdefault('secret',secrets.token_hex(32)); d['admin_username']=u; d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode(); d.pop('initial_admin_password',None); d.setdefault('ads_enabled',True); d.setdefault('ad_provider','monetag'); d.setdefault('monetag_zone','11217882'); d.setdefault('ads',{'create':3,'delete':1,'renew':3}); d['server_domain']=domain; d['server_prefix']='/'; json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); os.chmod(p,0o600)
PY
}
install_or_update(){ root_check; [[ -f "$WEB/server.py" ]] || { echo -e "${red}✘ Falta $WEB/server.py${reset}"; return 1; }; mkdir -p "$DATA" "$WEB/templates" "$ACME_ROOT/.well-known/acme-challenge"; local existing_domain="$(python3 - "$DATA/config.json" <<'PY'
import json,sys
try:print(json.load(open(sys.argv[1])).get('server_domain',''))
except:print('')
PY
)"; existing_domain="${existing_domain:-$(current_domain)}"; if [[ -z "$existing_domain" ]]; then prompt_fresh || return 1; save_credentials "$WEB_ADMIN_USER" "$WEB_ADMIN_PASS" "$WEB_DOMAIN" || return 1; else WEB_DOMAIN="$existing_domain"; echo -e "${cyan}Actualizando sin cambiar usuario, contraseña ni dominio.${reset}"; fi; write_service; write_acme_service; ensure_cert "$WEB_DOMAIN" || return 1; patch_haproxy "$WEB_DOMAIN" || return 1; systemctl daemon-reload; systemctl enable "$SERVICE" "$ACME_SERVICE" >/dev/null 2>&1 || true; systemctl restart "$ACME_SERVICE"; systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true; systemctl restart "$SERVICE"; sleep 1; if systemctl is-active --quiet "$SERVICE"; then echo -e "${green}✔ KevinTech Web activa.${reset}"; echo -e "${cyan}✔ Panel: https://$WEB_DOMAIN/login${reset}"; else journalctl -u "$SERVICE" -n 40 --no-pager; return 1; fi; }
change_data(){ root_check; [[ -f "$DATA/config.json" ]] || { echo -e "${red}Web no instalada.${reset}"; return 1; }; local u p domain; domain="$(python3 - "$DATA/config.json" <<'PY'
import json,sys
try:print(json.load(open(sys.argv[1])).get('server_domain',''))
except:print('')
PY
)"; domain="${domain:-$(current_domain)}"; read -rp "Nuevo usuario admin [ENTER = conservar]: " u; read -rsp "Nueva contraseña [ENTER = conservar]: " p; echo; [[ -n "$u" || -n "$p" ]] || return 0; python3 - "$DATA/config.json" "$u" "$p" <<'PY'
import json,sys,hashlib,base64,secrets,os
p,u,pw=sys.argv[1:]; d=json.load(open(p));
if u:d['admin_username']=u
if pw:
 salt=secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode()
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); os.chmod(p,0o600)
PY
systemctl restart "$SERVICE" >/dev/null 2>&1 || true; echo -e "${green}✔ Datos cambiados. Dominio y enlace conservados: https://$domain/login${reset}"; }
show_logs(){ root_check; journalctl -u "$SERVICE" -f -n 80 --no-pager; }
remove_web(){ root_check; systemctl stop "$SERVICE" 2>/dev/null || true; systemctl disable "$SERVICE" 2>/dev/null || true; systemctl stop "$ACME_SERVICE" 2>/dev/null || true; systemctl disable "$ACME_SERVICE" 2>/dev/null || true; systemctl daemon-reload; echo -e "${green}✔ Servicios detenidos/deshabilitados.${reset}"; echo -e "${cyan}✔ Archivos conservados en $WEB${reset}"; echo -e "${cyan}✔ No se tocaron usuarios/, protocolos/, herramientas/ ni telegram/.${reset}"; }
menu(){ root_check; while true; do clear; echo -e "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"; echo -e "${cyan}║${reset}             KEVINTECH WEB INSTALLER                  ${cyan}║${reset}"; echo -e "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"; echo; echo -e "${green}[1]${reset} Instalar / Actualizar web"; echo -e "${yellow}[2]${reset} Cambiar datos de acceso"; echo -e "${cyan}[3]${reset} Ver logs"; echo -e "${red}[4]${reset} Detener web (conservar archivos)"; echo "[0] Salir"; echo; read -rp "Opción: " op; case "$op" in 1) install_or_update; read -rp "ENTER para continuar..." _;; 2) change_data; read -rp "ENTER para continuar..." _;; 3) show_logs;; 4) read -rp "Escribe DETENER para confirmar: " x; [[ "$x" == DETENER ]] && remove_web; read -rp "ENTER para continuar..." _;; 0) exit 0;; *) echo "Opción inválida"; sleep 1;; esac; done; }
case "${1:-menu}" in install|update) install_or_update;; change) change_data;; logs) show_logs;; remove|stop) remove_web;; menu) menu;; *) echo "Uso: $0 {install|update|change|logs|stop|menu}"; exit 1;; esac
