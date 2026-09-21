#!/bin/bash
set -u
BASE="/etc/kevintech"; WEB="$BASE/web"; DATA="$WEB/data"; SERVICE="kevintech-web.service"; PORT="18080"; PREFIX="/kevintech-web"; HAPROXY="/etc/haproxy/haproxy.cfg"; CONFIG="$BASE/config.conf"
red='\e[1;91m'; green='\e[1;92m'; cyan='\e[1;96m'; yellow='\e[1;93m'; white='\e[1;97m'; reset='\e[0m'
root_check(){ [[ $EUID -eq 0 ]] || { echo -e "${red}Ejecuta como root.${reset}"; exit 1; }; }
configured_domain(){ local d=""; if [[ -f "$CONFIG" ]]; then d="$(awk -F'=' '/^SERVER_DOMAIN=/{gsub(/^\"|\"$/,"",$2); print $2; exit}' "$CONFIG" 2>/dev/null)"; fi; printf '%s' "$d"; }

write_service(){
cat > "/etc/systemd/system/$SERVICE" <<EOF2
[Unit]
Description=KevinTech Web Panel
After=network-online.target haproxy.service
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=10

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WEB
Environment=PYTHONUNBUFFERED=1
Environment=KEVINTECH_WEB_PORT=$PORT
Environment=KEVINTECH_WEB_PREFIX=$PREFIX
ExecStart=/usr/bin/python3 $WEB/server.py
Restart=on-failure
RestartSec=5
TimeoutStartSec=30
TimeoutStopSec=20
LimitNOFILE=65535
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF2
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1 || true
}

write_haproxy_backup(){ [[ -f "$HAPROXY" ]] || return 0; [[ -f "$HAPROXY.kevintech-web.bak" ]] || cp -a "$HAPROXY" "$HAPROXY.kevintech-web.bak"; }

patch_haproxy(){
  [[ -f "$HAPROXY" ]] || { echo -e "${yellow}⚠ HAProxy no está instalado/configurado; la web queda local.${reset}"; return 0; }
  command -v haproxy >/dev/null 2>&1 || { echo -e "${yellow}⚠ No se encontró HAProxy; no se modificó.${reset}"; return 0; }
  write_haproxy_backup
  WEB_DOMAIN="$WEB_DOMAIN" HAPROXY="$HAPROXY" PORT="$PORT" PREFIX="$PREFIX" python3 - <<'PY'
import os, subprocess, shutil
from pathlib import Path
p=Path(os.environ['HAPROXY']); s=p.read_text(errors='ignore'); domain=os.environ.get('WEB_DOMAIN','').strip(); port=os.environ['PORT']; prefix=os.environ['PREFIX']
# Remove only this module's previous directives/backend. Keep all other HAProxy content.
lines=s.splitlines(True); out=[]; skip=False
for line in lines:
    st=line.strip()
    if st=='backend kevintech_web': skip=True; continue
    if skip:
        if line and not line[0].isspace() and st: skip=False
        else: continue
    if 'acl kevintech_web_host ' in line or 'acl kevintech_web_path ' in line or 'use_backend kevintech_web if ' in line: continue
    out.append(line)
s=''.join(out)
lines=s.splitlines(True); out=[]; section=None; patched=False
for line in lines:
    st=line.strip()
    if st.startswith('frontend '): section='frontend'
    elif st.startswith(('backend ','listen ','global','defaults')): section='other'
    out.append(line)
    if section=='frontend' and st.startswith('bind ') and ':443' in st and not patched:
        if domain and domain not in ('localhost','127.0.0.1'):
            out.append('    acl kevintech_web_host hdr(host) -i %s\n' % domain)
            out.append('    acl kevintech_web_path path_beg %s\n' % prefix)
            out.append('    use_backend kevintech_web if kevintech_web_host kevintech_web_path\n')
        else:
            out.append('    acl kevintech_web_path path_beg %s\n' % prefix)
            out.append('    use_backend kevintech_web if kevintech_web_path\n')
        patched=True
if not patched: raise SystemExit('No se encontró un frontend HTTPS con bind :443.')
if not s.endswith('\n'): s+='\n'
s+='\nbackend kevintech_web\n    mode http\n    option http-server-close\n    option forwardfor\n    server kevintech_web 127.0.0.1:%s check\n' % port
p.write_text(s)
r=subprocess.run(['haproxy','-c','-f',str(p)],capture_output=True,text=True)
if r.returncode:
    bak=Path(str(p)+'.kevintech-web.bak')
    if bak.exists(): shutil.copy2(bak,p)
    print(r.stdout+r.stderr); raise SystemExit(3)
r=subprocess.run(['systemctl','reload','haproxy'],capture_output=True,text=True)
if r.returncode: print(r.stdout+r.stderr); raise SystemExit(4)
PY
}

remove_haproxy(){
  [[ -f "$HAPROXY" ]] || return 0; command -v haproxy >/dev/null 2>&1 || return 0
  python3 - "$HAPROXY" <<'PY'
import sys,subprocess
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(errors='ignore'); lines=s.splitlines(True); out=[]; skip=False
for line in lines:
    st=line.strip()
    if st=='backend kevintech_web': skip=True; continue
    if skip:
        if line and not line[0].isspace() and st: skip=False
        else: continue
    if 'acl kevintech_web_host ' in line or 'acl kevintech_web_path ' in line or 'use_backend kevintech_web if ' in line: continue
    out.append(line)
p.write_text(''.join(out))
r=subprocess.run(['haproxy','-c','-f',str(p)],capture_output=True,text=True)
if r.returncode:
    print(r.stdout+r.stderr); raise SystemExit(2)
subprocess.run(['systemctl','reload','haproxy'],capture_output=True)
bak=Path(str(p)+'.kevintech-web.bak')
if bak.exists(): bak.unlink()
PY
}

prompt_credentials(){
  local olddomain; olddomain="$(configured_domain)"
  echo; echo -e "${cyan}Configuración de acceso de KevinTech Web${reset}"
  read -rp "Usuario administrador [admin]: " WEB_ADMIN_USER; WEB_ADMIN_USER="${WEB_ADMIN_USER:-admin}"
  while [[ ! "$WEB_ADMIN_USER" =~ ^[A-Za-z0-9_.-]{3,32}$ ]]; do read -rp "Usuario inválido. Escribe otro: " WEB_ADMIN_USER; done
  while true; do read -rsp "Contraseña administrador (mín. 8 caracteres): " WEB_ADMIN_PASS; echo; [[ ${#WEB_ADMIN_PASS} -ge 8 ]] && break; echo -e "${yellow}La contraseña debe tener al menos 8 caracteres.${reset}"; done
  if [[ -n "$olddomain" ]]; then read -rp "Dominio HTTPS [ENTER = $olddomain]: " WEB_DOMAIN; WEB_DOMAIN="${WEB_DOMAIN:-$olddomain}"; else read -rp "Dominio HTTPS [ENTER = usar el dominio configurado]: " WEB_DOMAIN; WEB_DOMAIN="${WEB_DOMAIN:-$(hostname -f 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}') }"; fi
  WEB_DOMAIN="$(echo "$WEB_DOMAIN" | tr -d '[:space:]')"; [[ -z "$WEB_DOMAIN" ]] && WEB_DOMAIN="localhost"; export WEB_ADMIN_USER WEB_ADMIN_PASS WEB_DOMAIN
}

install_web(){
  root_check
  if [[ ! -f "$WEB/server.py" ]]; then
    echo -e "${red}✘ Falta $WEB/server.py${reset}"
    echo -e "${yellow}El servicio NO se instalará ni se iniciará para evitar un bucle de reinicios.${reset}"
    echo -e "${yellow}Vuelve a copiar el directorio web completo y ejecuta nuevamente la instalación.${reset}"
    return 1
  fi
  mkdir -p "$DATA"; prompt_credentials
  python3 - "$DATA/config.json" "$WEB_ADMIN_USER" "$WEB_ADMIN_PASS" "$WEB_DOMAIN" <<'PY'
import json,sys,hashlib,base64,secrets,os
p,u,pw,domain=sys.argv[1:]
try: d=json.load(open(p)) if os.path.exists(p) else {}
except: d={}
salt=secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1)
d.setdefault('secret',secrets.token_hex(32)); d['admin_username']=u; d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode(); d.pop('initial_admin_password',None)
d.setdefault('ads_enabled',True); d.setdefault('ad_provider','monetag'); d.setdefault('monetag_zone','11217882'); d.setdefault('ads',{'create':3,'delete':1,'renew':3}); d['server_domain']=domain; d['server_prefix']='/kevintech-web'
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); os.chmod(p,0o600)
PY
  write_service; systemd-analyze verify "/etc/systemd/system/$SERVICE" >/dev/null 2>&1 || { echo -e "${red}✘ La unidad systemd generada es inválida.${reset}"; return 1; }; patch_haproxy || echo -e "${yellow}⚠ La web quedó local porque HAProxy no pudo actualizarse.${reset}"
  systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true; systemctl restart "$SERVICE"; sleep 1
  if systemctl is-active --quiet "$SERVICE"; then echo -e "${green}✔ KevinTech Web activa.${reset}"; echo -e "${cyan}✔ HTTPS: https://$WEB_DOMAIN$PREFIX/${reset}"; else echo -e "${red}✘ No se pudo iniciar $SERVICE${reset}"; journalctl -u "$SERVICE" -n 50 --no-pager || true; return 1; fi
}

update_web(){
  root_check; [[ -f "$WEB/server.py" ]] || { echo -e "${red}Falta $WEB/server.py; instalación incompleta.${reset}"; return 1; }
  WEB_DOMAIN="$(python3 - "$DATA/config.json" <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1])).get('server_domain',''))
except: print('')
PY
)"; [[ -n "$WEB_DOMAIN" ]] || WEB_DOMAIN="$(configured_domain)"; [[ -n "$WEB_DOMAIN" ]] || WEB_DOMAIN="localhost"
  write_service; systemd-analyze verify "/etc/systemd/system/$SERVICE" >/dev/null 2>&1 || { echo -e "${red}✘ La unidad systemd generada es inválida.${reset}"; return 1; }; patch_haproxy || true; systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true; systemctl restart "$SERVICE"; sleep 1
  if systemctl is-active --quiet "$SERVICE"; then echo -e "${green}✔ Web actualizada y activa.${reset}"; echo -e "${cyan}✔ HTTPS: https://$WEB_DOMAIN$PREFIX/${reset}"; else echo -e "${red}✘ La web no quedó activa.${reset}"; journalctl -u "$SERVICE" -n 50 --no-pager; return 1; fi
}

change_data(){
  root_check; [[ -f "$WEB/server.py" ]] || { echo -e "${red}Web no instalada.${reset}"; return 1; }; local u p; read -rp "Nuevo usuario admin [ENTER = conservar]: " u; read -rsp "Nueva contraseña [ENTER = conservar]: " p; echo
  python3 - "$DATA/config.json" "$u" "$p" <<'PY'
import json,sys,hashlib,base64,secrets,os
p,u,pw=sys.argv[1:]; d=json.load(open(p));
if u: d['admin_username']=u
if pw:
 salt=secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode()
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); os.chmod(p,0o600)
PY
  systemctl restart "$SERVICE"; echo -e "${green}✔ Datos actualizados.${reset}"
}
show_logs(){ root_check; echo -e "${cyan}═══ LOG EN VIVO: $SERVICE ═══${reset}"; journalctl -u "$SERVICE" -f -n 80 --no-pager; }
remove_web(){ root_check; systemctl stop "$SERVICE" 2>/dev/null || true; systemctl disable "$SERVICE" 2>/dev/null || true; rm -f "/etc/systemd/system/$SERVICE"; systemctl daemon-reload; remove_haproxy || true; rm -rf "$WEB"; systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true; echo -e "${green}✔ KevinTech Web eliminada completamente.${reset}"; echo -e "${green}✔ usuarios/protocolos/herramientas/telegram no fueron tocados.${reset}"; }

menu(){
  root_check; while true; do clear; echo -e "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"; echo -e "${cyan}║${white}             KEVINTECH WEB INSTALLER${cyan}                  ║${reset}"; echo -e "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"; echo; echo -e "${green}[1]${reset} Instalar / Actualizar web"; echo -e "${yellow}[2]${reset} Cambiar datos de acceso"; echo -e "${cyan}[3]${reset} Ver logs"; echo -e "${red}[4]${reset} Eliminar web"; echo -e "[0] Salir"; echo; read -rp "Opción: " op; case "$op" in 1) if [[ -f "$WEB/server.py" ]]; then update_web; else install_web; fi; read -rp "ENTER para continuar..." _;; 2) change_data; read -rp "ENTER para continuar..." _;; 3) show_logs;; 4) read -rp "Escribe ELIMINAR para confirmar: " x; [[ "$x" == ELIMINAR ]] && remove_web; read -rp "ENTER para continuar..." _;; 0) exit 0;; *) echo "Opción inválida"; sleep 1;; esac; done
}
case "${1:-menu}" in install|update) [[ "$1" == update ]] && update_web || install_web;; change) change_data;; logs) show_logs;; remove) remove_web;; menu) menu;; *) echo "Uso: $0 {install|update|change|logs|remove|menu}"; exit 1;; esac
