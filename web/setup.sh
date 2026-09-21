#!/bin/bash
set -euo pipefail
BASE="/etc/kevintech"
WEB="$BASE/web"
DATA="$WEB/data"
SERVICE="kevintech-web.service"
PORT="18080"
PREFIX="/kevintech-web"
HAPROXY="/etc/haproxy/haproxy.cfg"

red='\e[1;91m'; green='\e[1;92m'; cyan='\e[1;96m'; yellow='\e[1;93m'; white='\e[1;97m'; reset='\e[0m'

root_check(){ [[ $EUID -eq 0 ]] || { echo -e "${red}Ejecuta como root.${reset}"; exit 1; }; }

write_service(){
cat > /etc/systemd/system/$SERVICE <<EOF
[Unit]
Description=KevinTech Web Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WEB
Environment=PYTHONUNBUFFERED=1
Environment=KEVINTECH_WEB_PORT=$PORT
Environment=KEVINTECH_WEB_PREFIX=$PREFIX
ExecStart=/usr/bin/python3 $WEB/server.py
Restart=always
RestartSec=3
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null
}

patch_haproxy(){
  [[ -f "$HAPROXY" ]] || return 0
  command -v haproxy >/dev/null 2>&1 || return 0
  python3 - "$HAPROXY" <<'PY'
import sys, shutil, subprocess
from pathlib import Path
p=Path(sys.argv[1]); s=p.read_text(errors='ignore')
backend='backend kevintech_web\n    mode http\n    option http-server-close\n    server kevintech_web 127.0.0.1:18080 check\n'
if 'backend kevintech_web' in s and 'kevintech_web path_beg /kevintech-web' in s:
    raise SystemExit(0)
backup=p.with_name('haproxy.cfg.kevintech-web.bak')
shutil.copy2(p,backup)
lines=s.splitlines(True); out=[]; in_front=False; patched=False; section=None
for line in lines:
    stripped=line.strip()
    if stripped.startswith('frontend '):
        section='frontend'; in_front=False
    elif stripped.startswith('backend ') or stripped.startswith('listen ') or stripped.startswith('global') or stripped.startswith('defaults'):
        section='other'; in_front=False
    out.append(line)
    if section=='frontend' and stripped.startswith('bind ') and ':443' in stripped and not patched:
        out.append('    acl kevintech_web path_beg /kevintech-web\n')
        out.append('    use_backend kevintech_web if kevintech_web\n')
        patched=True
if not patched:
    shutil.copy2(backup,p); raise SystemExit(2)
if not s.endswith('\n'): out.append('\n')
out.append('\n'+backend)
p.write_text(''.join(out))
r=subprocess.run(['haproxy','-c','-f',str(p)],capture_output=True,text=True)
if r.returncode!=0:
    shutil.copy2(backup,p)
    print(r.stdout+r.stderr)
    raise SystemExit(3)
PY
}

install_web(){
  root_check
  mkdir -p "$DATA"
  write_service
  # First start creates secure DB/config and generates credentials if needed.
  systemctl restart "$SERVICE"
  sleep 1
  patch_haproxy || true
  if systemctl is-active --quiet "$SERVICE"; then
    echo -e "${green}✔ KevinTech Web activo en 127.0.0.1:$PORT${reset}"
  else
    echo -e "${red}✘ No se pudo iniciar $SERVICE${reset}"
    journalctl -u "$SERVICE" -n 40 --no-pager || true
    return 1
  fi
  if [[ -f "$DATA/config.json" ]]; then
    python3 - "$DATA/config.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
pw=d.pop('initial_admin_password',None)
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False); __import__('os').chmod(p,0o600)
if pw: print('ADMIN_PASSWORD='+pw)
PY
  fi
  echo -e "${cyan}URL:${reset} ${white}https://TU-DOMINIO/kevintech-web/${reset}"
}

update_web(){
  root_check
  [[ -f "$WEB/server.py" ]] || { echo -e "${red}Web no instalada.${reset}"; return 1; }
  write_service
  systemctl restart "$SERVICE"
  patch_haproxy || true
  echo -e "${green}✔ Web actualizada/reiniciada.${reset}"
}

change_data(){
  root_check
  [[ -f "$WEB/server.py" ]] || { echo -e "${red}Web no instalada.${reset}"; return 1; }
  local u p
  read -rp "Nuevo usuario admin [dejar vacío para conservar]: " u
  read -rsp "Nueva contraseña admin [dejar vacío para conservar]: " p; echo
  if [[ -n "$u" || -n "$p" ]]; then
    python3 - "$DATA/config.json" "$u" "$p" <<'PY'
import json,sys,hashlib,base64,secrets,os
p,u,pw=sys.argv[1:]
d=json.load(open(p))
if u:d['admin_username']=u
if pw:
    salt=secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1)
    d['admin_password_hash']='scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode()
json.dump(d,open(p,'w'),indent=2,ensure_ascii=False);os.chmod(p,0o600)
PY
  fi
  systemctl restart "$SERVICE"
  echo -e "${green}✔ Datos actualizados.${reset}"
}

remove_web(){
  root_check
  systemctl stop "$SERVICE" 2>/dev/null || true
  systemctl disable "$SERVICE" 2>/dev/null || true
  rm -f /etc/systemd/system/$SERVICE
  systemctl daemon-reload
  rm -rf "$WEB"
  echo -e "${green}✔ KevinTech Web eliminado. Los directorios usuarios/protocolos/herramientas/telegram no fueron tocados por este módulo.${reset}"
}

menu(){
  root_check
  while true; do
    clear
    echo -e "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${cyan}║${white}             KEVINTECH WEB INSTALLER${cyan}                  ║${reset}"
    echo -e "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"
    echo
    echo -e "${green}[1]${reset} Instalar / Actualizar web"
    echo -e "${yellow}[2]${reset} Cambiar datos de acceso"
    echo -e "${red}[3]${reset} Eliminar web"
    echo -e "[0] Salir"
    echo
    read -rp "Opción: " op
    case "$op" in
      1) install_web; read -rp "ENTER para continuar..." _ ;;
      2) change_data; read -rp "ENTER para continuar..." _ ;;
      3) read -rp "Escribe ELIMINAR para confirmar: " x; [[ "$x" == ELIMINAR ]] && remove_web; read -rp "ENTER para continuar..." _ ;;
      0) exit 0;;
      *) echo "Opción inválida"; sleep 1;;
    esac
  done
}

case "${1:-menu}" in
  install|update) install_web;;
  change) change_data;;
  remove) remove_web;;
  menu) menu;;
  *) echo "Uso: $0 {install|update|change|remove|menu}"; exit 1;;
esac
