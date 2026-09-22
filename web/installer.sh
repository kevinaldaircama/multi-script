#!/bin/bash
set -u
BASE="/etc/kevintech"; WEB="$BASE/web"; DATA="$WEB/data"; SERVICE="kevintech-web.service"; ACME_SERVICE="kevintech-acme.service"; PORT=18080; ACME_PORT=18081
HAPROXY="/etc/haproxy/haproxy.cfg"; PEM="/etc/haproxy/kevintech-panel.pem"; DOMAIN_FILE="/etc/haproxy/kevintech-panel-domain"; ACME_ROOT="/var/www/letsencrypt"; HOOK="/etc/letsencrypt/renewal-hooks/deploy/kevintech-panel.sh"; CONFIG="$BASE/config.conf"
red='\e[1;91m'; green='\e[1;92m'; cyan='\e[1;96m'; yellow='\e[1;93m'; reset='\e[0m'
root_check(){ [[ $EUID -eq 0 ]] || { echo -e "${red}Ejecuta como root.${reset}"; exit 1; }; }
valid_domain(){ [[ "$1" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ && "$1" != *".."* ]]; }
configured_domain(){ local d=""; [[ -f "$CONFIG" ]] && d="$(awk -F'=' '/^SERVER_DOMAIN=/{gsub(/^"|"$/,"",$2); print $2; exit}' "$CONFIG" 2>/dev/null)"; printf '%s' "$d"; }
current_domain(){ [[ -f "$DOMAIN_FILE" ]] && tr -d '[:space:]' < "$DOMAIN_FILE" || true; }
write_domain_config(){ printf '%s\n' "$1" > "$DOMAIN_FILE"; chmod 600 "$DOMAIN_FILE"; }
write_service(){ cat > "/etc/systemd/system/$SERVICE" <<EOF2
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
EOF2
systemctl daemon-reload; systemctl enable "$SERVICE" >/dev/null 2>&1 || true; }
write_acme_service(){ mkdir -p "$ACME_ROOT/.well-known/acme-challenge"; cat > "/etc/systemd/system/$ACME_SERVICE" <<EOF2
[Unit]
Description=KevinTech ACME webroot helper
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=$ACME_ROOT
ExecStart=/usr/bin/python3 -m http.server $ACME_PORT --directory $ACME_ROOT --bind 127.0.0.1
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
EOF2
systemctl daemon-reload; systemctl enable "$ACME_SERVICE" >/dev/null 2>&1 || true; systemctl restart "$ACME_SERVICE"; }
write_renew_hook(){ mkdir -p /etc/letsencrypt/renewal-hooks/deploy; cat > "$HOOK" <<'EOF2'
#!/bin/sh
set -eu
domain_file=/etc/haproxy/kevintech-panel-domain
pem=/etc/haproxy/kevintech-panel.pem
cfg=/etc/haproxy/haproxy.cfg
[ -s "$domain_file" ] || exit 0
domain=$(tr -d '[:space:]' < "$domain_file")
cat "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/letsencrypt/live/$domain/privkey.pem" > "$pem"
chmod 600 "$pem"
haproxy -c -f "$cfg" >/dev/null 2>&1 && systemctl reload haproxy
EOF2
chmod 700 "$HOOK"; }
make_temp_cert(){ local d="$1"; mkdir -p "$(dirname "$PEM")"; openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj "/CN=$d" -keyout /tmp/kt-panel.key -out /tmp/kt-panel.crt >/dev/null 2>&1; cat /tmp/kt-panel.crt /tmp/kt-panel.key > "$PEM"; chmod 600 "$PEM"; rm -f /tmp/kt-panel.key /tmp/kt-panel.crt; }
patch_haproxy(){ local domain="$1"; [[ -f "$HAPROXY" ]] || { echo -e "${red}No existe $HAPROXY${reset}"; return 1; }; cp -a "$HAPROXY" "$HAPROXY.kevintech-web.bak"; DOMAIN="$domain" PEM="$PEM" PORT="$PORT" HAPROXY="$HAPROXY" python3 - <<'PY'
import os, subprocess, shutil
from pathlib import Path
p=Path(os.environ['HAPROXY']); s=p.read_text(errors='ignore'); domain=os.environ['DOMAIN']; pem=os.environ['PEM']; port=os.environ['PORT']
lines=s.splitlines(True); out=[]; skip=False
for line in lines:
    st=line.strip()
    if st=='backend kevintech_web' or st=='backend acme_backend': skip=True; continue
    if skip:
        if line and not line[0].isspace() and st: skip=False
        else: continue
    if any(x in line for x in ['acl acl_panel_sni ','use_backend kevintech_web if acl_panel_sni','acl acl_acme path_beg /.well-known/acme-challenge/','use_backend acme_backend if acl_acme']): continue
    out.append(line)
s=''.join(out)
# Ensure panel certificate is on the TLS bind.
out=[]
for line in s.splitlines(True):
    if line.strip().startswith('bind abns@haproxy-https') and 'ssl' in line and pem not in line:
        line=line.rstrip('\n')+' crt '+pem+'\n'
    out.append(line)
s=''.join(out)
# Insert panel routing and ACME routing in ssl_frontend before generic protocol rules.
lines=s.splitlines(True); out=[]; in_ssl=False; inserted_panel=False; inserted_acme=False
for line in lines:
    st=line.strip()
    if st.startswith('frontend '): in_ssl=(st=='frontend ssl_frontend')
    elif st.startswith(('backend ','listen ','global','defaults')): in_ssl=False
    if in_ssl and st.startswith('acl acl_upgrade') and not inserted_acme:
        out.append('    acl acl_acme path_beg /.well-known/acme-challenge/\n'); out.append('    use_backend acme_backend if acl_acme\n'); inserted_acme=True
    if in_ssl and st=='use_backend grpc_backend if acl_http2' and not inserted_panel:
        out.append('    acl acl_panel_sni ssl_fc_sni -i '+domain+'\n'); out.append('    use_backend kevintech_web if acl_panel_sni\n'); inserted_panel=True
    out.append(line)
s=''.join(out)
if not inserted_acme:
    raise SystemExit('No se encontró frontend ssl_frontend para ACME')
if not inserted_panel:
    raise SystemExit('No se encontró punto de inserción del panel')
s += '\nbackend acme_backend\n    mode http\n    option http-server-close\n    server acme_server 127.0.0.1:18081 check\n\nbackend kevintech_web\n    mode http\n    option http-server-close\n    option forwardfor\n    server kevintech_web 127.0.0.1:'+port+' check\n'
p.write_text(s)
r=subprocess.run(['haproxy','-c','-f',str(p)],capture_output=True,text=True)
if r.returncode:
    shutil.copy2(str(p)+'.kevintech-web.bak',p); print(r.stdout+r.stderr); raise SystemExit(3)
r=subprocess.run(['systemctl','reload','haproxy'],capture_output=True,text=True)
if r.returncode: print(r.stdout+r.stderr); raise SystemExit(4)
PY
}
copy_web_files(){ local src dst; src="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$WEB/templates"; for f in server.py requirements.txt version.txt README.md; do if [[ -f "$src/$f" ]]; then dst="$WEB/$f"; [[ "$(readlink -f "$src/$f")" == "$(readlink -f "$dst" 2>/dev/null || true)" ]] || cp -f "$src/$f" "$dst"; fi; done; for f in "$src/templates"/*.html; do [[ -f "$f" ]] || continue; dst="$WEB/templates/$(basename "$f")"; [[ "$(readlink -f "$f")" == "$(readlink -f "$dst" 2>/dev/null || true)" ]] || cp -f "$f" "$dst"; done; mkdir -p "$DATA"; }
save_credentials(){ python3 - "$DATA/config.json" "$1" "$2" "$3" <<'PY'
import json,sys,hashlib,base64,secrets,os
p,u,pw,domain=sys.argv[1:]; os.makedirs(os.path.dirname(p),exist_ok=True)
try:d=json.load(open(p))
except:d={}
salt=secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1)
d.setdefault('secret',secrets.token_hex(32)); d['admin_username']=u; d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode(); d.pop('initial_admin_password',None); d.setdefault('ads_enabled',True); d.setdefault('ad_provider','monetag'); d.setdefault('monetag_zone','11217882'); d.setdefault('ads',{'create':3,'delete':1,'renew':3}); d['server_domain']=domain; d['server_prefix']='/'
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); os.chmod(p,0o600)
PY
}
prompt_fresh(){ echo; read -rp "Usuario administrador [admin]: " WEB_ADMIN_USER; WEB_ADMIN_USER="${WEB_ADMIN_USER:-admin}"; while [[ ! "$WEB_ADMIN_USER" =~ ^[A-Za-z0-9_.-]{3,32}$ ]]; do read -rp "Usuario inválido: " WEB_ADMIN_USER; done; while true; do read -rsp "Contraseña administrador (mín. 8): " WEB_ADMIN_PASS; echo; [[ ${#WEB_ADMIN_PASS} -ge 8 ]] && break; done; local old="$(configured_domain)"; old="${old:-$(current_domain)}"; if [[ -n "$old" ]]; then read -rp "Dominio HTTPS [ENTER = $old]: " WEB_DOMAIN; WEB_DOMAIN="${WEB_DOMAIN:-$old}"; else read -rp "Dominio HTTPS: " WEB_DOMAIN; fi; WEB_DOMAIN="$(echo "$WEB_DOMAIN" | tr -d '[:space:]')"; valid_domain "$WEB_DOMAIN" || { echo -e "${red}Dominio inválido.${reset}"; return 1; }; export WEB_ADMIN_USER WEB_ADMIN_PASS WEB_DOMAIN; }
ensure_cert(){ local domain="$1" email; mkdir -p "$ACME_ROOT/.well-known/acme-challenge"; systemctl restart "$ACME_SERVICE"; echo "KEVINTECH-ACME-OK" > "$ACME_ROOT/.well-known/acme-challenge/installer-test"; sleep 1; if ! curl -fsS --max-time 15 "http://$domain/.well-known/acme-challenge/installer-test" | grep -q KEVINTECH-ACME-OK; then echo -e "${red}✘ El dominio no está llegando al ACME de HAProxy.${reset}"; echo "Prueba DNS/puerto 80 antes de solicitar el certificado."; return 1; fi; if [[ -s "/etc/letsencrypt/live/$domain/fullchain.pem" && -s "/etc/letsencrypt/live/$domain/privkey.pem" ]]; then :; else command -v certbot >/dev/null 2>&1 || { apt-get update -y && apt-get install -y certbot || return 1; }; read -rp "Correo para Let's Encrypt: " email; [[ -n "$email" ]] || return 1; certbot certonly --webroot -w "$ACME_ROOT" -d "$domain" --non-interactive --agree-tos --no-eff-email -m "$email" || return 1; fi; cat "/etc/letsencrypt/live/$domain/fullchain.pem" "/etc/letsencrypt/live/$domain/privkey.pem" > "$PEM"; chmod 600 "$PEM"; write_domain_config "$domain"; write_renew_hook; haproxy -c -f "$HAPROXY" >/dev/null || return 1; systemctl reload haproxy; }
install_or_update(){ root_check; copy_web_files || return 1; mkdir -p "$DATA" "$WEB/templates" "$ACME_ROOT/.well-known/acme-challenge"; local existing_domain="$(python3 - "$DATA/config.json" <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1])).get('server_domain',''))
except: print('')
PY
)"; existing_domain="${existing_domain:-$(current_domain)}"; if [[ -z "$existing_domain" ]]; then prompt_fresh || return 1; save_credentials "$WEB_ADMIN_USER" "$WEB_ADMIN_PASS" "$WEB_DOMAIN" || return 1; else WEB_DOMAIN="$existing_domain"; echo -e "${cyan}Actualizando: se conservan usuario, contraseña y dominio.${reset}"; fi; write_service; write_acme_service; make_temp_cert "$WEB_DOMAIN"; patch_haproxy "$WEB_DOMAIN" || return 1; ensure_cert "$WEB_DOMAIN" || return 1; systemctl daemon-reload; systemctl enable "$SERVICE" "$ACME_SERVICE" >/dev/null 2>&1 || true; systemctl restart "$SERVICE"; sleep 1; if systemctl is-active --quiet "$SERVICE"; then echo -e "${green}✔ KevinTech Web instalada/actualizada.${reset}"; echo -e "${cyan}✔ Panel: https://$WEB_DOMAIN/login${reset}"; else journalctl -u "$SERVICE" -n 40 --no-pager; return 1; fi; }
change_data(){
 root_check; [[ -f "$DATA/config.json" ]] || { echo -e "${red}Web no instalada. Primero usa opción 1.${reset}"; return 1; }
 local oldu olddomain u p domain
 oldu="$(python3 - "$DATA/config.json" <<'PY2'
import json,sys
try: print(json.load(open(sys.argv[1])).get('admin_username','admin'))
except: print('admin')
PY2
)"
 olddomain="$(python3 - "$DATA/config.json" <<'PY2'
import json,sys
try: print(json.load(open(sys.argv[1])).get('server_domain',''))
except: print('')
PY2
)"; olddomain="${olddomain:-$(current_domain)}"
 read -rp "Nuevo usuario admin [ENTER = $oldu]: " u; u="${u:-$oldu}"
 read -rsp "Nueva contraseña [ENTER = conservar]: " p; echo
 [[ "$u" =~ ^[A-Za-z0-9_.-]{3,32}$ ]] || { echo "Usuario inválido"; return 1; }
 read -rp "Nuevo dominio HTTPS [ENTER = $olddomain]: " domain; domain="${domain:-$olddomain}"; domain="$(echo "$domain"|tr -d '[:space:]')"; valid_domain "$domain" || { echo "Dominio inválido"; return 1; }
 python3 - "$DATA/config.json" "$u" "$p" "$domain" <<'PY2'
import json,sys,hashlib,base64,secrets,os
p,u,pw,domain=sys.argv[1:];d=json.load(open(p));d['admin_username']=u;d['server_domain']=domain
if pw:
 if len(pw)<8: raise SystemExit('Contraseña demasiado corta')
 salt=secrets.token_bytes(16);h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1);d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode()
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False);os.chmod(p,0o600)
PY2
 WEB_DOMAIN="$domain"; write_domain_config "$domain"; make_temp_cert "$domain"; patch_haproxy "$domain" || return 1; ensure_cert "$domain" || return 1; systemctl restart "$SERVICE"; echo -e "${green}✔ Datos actualizados.${reset}"; echo -e "${cyan}✔ Panel: https://$domain/login${reset}"; }

show_logs(){ root_check; journalctl -u "$SERVICE" -f -n 80 --no-pager; }
remove_web(){
 root_check
 systemctl stop "$SERVICE" 2>/dev/null || true; systemctl disable "$SERVICE" 2>/dev/null || true
 systemctl stop "$ACME_SERVICE" 2>/dev/null || true; systemctl disable "$ACME_SERVICE" 2>/dev/null || true
 rm -f "/etc/systemd/system/$SERVICE" "/etc/systemd/system/$ACME_SERVICE" "$HOOK" "$PEM" "$DOMAIN_FILE"
 local old_domain=""; [[ -f "$DATA/config.json" ]] && old_domain="$(python3 - "$DATA/config.json" <<'PY2'
import json,sys
try: print(json.load(open(sys.argv[1])).get('server_domain',''))
except: print('')
PY2
)"
 if [[ -n "$old_domain" ]] && command -v certbot >/dev/null 2>&1; then certbot delete --cert-name "$old_domain" --non-interactive >/dev/null 2>&1 || true; fi
 if [[ -f "$HAPROXY" ]]; then HAPROXY="$HAPROXY" PEM="$PEM" python3 - <<'PY2'
from pathlib import Path
import os,subprocess,shutil
p=Path(os.environ['HAPROXY']);s=p.read_text(errors='ignore');bak=str(p)+'.kevintech-web-remove.bak';shutil.copy2(p,bak)
lines=s.splitlines(True);out=[];skip=False
for line in lines:
 st=line.strip()
 if st in ('backend kevintech_web','backend acme_backend'): skip=True;continue
 if skip:
  if line and not line[0].isspace() and st: skip=False
  else: continue
 if any(x in line for x in ['acl acl_panel_sni ','use_backend kevintech_web if acl_panel_sni','acl acl_acme path_beg /.well-known/acme-challenge/','use_backend acme_backend if acl_acme','crt '+os.environ['PEM']]): continue
 out.append(line)
p.write_text(''.join(out));r=subprocess.run(['haproxy','-c','-f',str(p)],capture_output=True,text=True)
if r.returncode: shutil.copy2(bak,p); print(r.stdout+r.stderr)
else: subprocess.run(['systemctl','reload','haproxy'],check=False)
PY2
 fi
 systemctl daemon-reload; rm -rf "$WEB"
 echo -e "${green}✔ KevinTech Web desinstalada completamente.${reset}"; echo -e "${cyan}✔ Servicios, HAProxy, certificado y archivos de la web eliminados.${reset}"; echo -e "${cyan}✔ No se tocaron usuarios/, protocolos/, herramientas/ ni telegram/.${reset}"
}

menu(){ root_check; while true; do clear; echo -e "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"; echo -e "${cyan}║${reset}             KEVINTECH WEB INSTALLER                  ${cyan}║${reset}"; echo -e "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"; echo; echo -e "${green}[1]${reset} Instalar / Actualizar web"; echo -e "${yellow}[2]${reset} Cambiar datos de acceso"; echo -e "${cyan}[3]${reset} Ver logs"; echo -e "${red}[4]${reset} Detener web (conservar archivos)"; echo "[0] Salir"; echo; read -rp "Opción: " op; case "$op" in 1) install_or_update; read -rp "ENTER para continuar..." _;; 2) change_data; read -rp "ENTER para continuar..." _;; 3) show_logs;; 4) read -rp "Escribe DESINSTALAR para confirmar: " x; [[ "$x" == DESINSTALAR ]] && remove_web; read -rp "ENTER para continuar..." _;; 0) exit 0;; *) echo "Opción inválida"; sleep 1;; esac; done; }
case "${1:-menu}" in install|update) install_or_update;; change) change_data;; logs) show_logs;; remove|stop) remove_web;; menu) menu;; *) echo "Uso: $0 {install|update|change|logs|stop|menu}"; exit 1;; esac
