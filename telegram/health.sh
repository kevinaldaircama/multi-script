#!/usr/bin/env bash
set -Eeuo pipefail
C='\033[1;36m'; G='\033[1;92m'; Y='\033[1;93m'; R='\033[1;91m'; M='\033[1;95m'; Z='\033[0m'; D='/etc/kevintech/telegram'; U='kevintech-telegram'
echo -e "${C}╔════════════════════════════════════════════════════════════╗${Z}"; echo -e "${C}║${M}             ❤️ KEVINTECH TELEGRAM HEALTH              ${C}║${Z}"; echo -e "${C}╚════════════════════════════════════════════════════════════╝${Z}"
ok(){ echo -e "${G}✔ $1${Z}"; }; bad(){ echo -e "${R}✘ $1${Z}"; }
systemctl is-enabled --quiet "$U" && ok 'Autoarranque: ENABLED' || bad 'Autoarranque: OFF'; systemctl is-active --quiet "$U" && ok 'Servicio: ACTIVE' || bad 'Servicio: INACTIVE'; [[ -f "$D/.env" ]] && ok '.env: PRESENTE' || bad '.env: FALTA'; [[ "$(stat -c '%a' "$D/.env" 2>/dev/null || echo 0)" == 600 ]] && ok '.env permisos: 600' || bad '.env permisos incorrectos'; python3 -m py_compile "$D/bot.py" && ok 'Python: OK' || bad 'Python: ERROR'; echo; journalctl -u "$U" -n 8 --no-pager || true
