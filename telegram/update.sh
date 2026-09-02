#!/usr/bin/env bash
set -Eeuo pipefail
C='\033[1;36m'; G='\033[1;92m'; R='\033[1;91m'; Z='\033[0m'; D='/etc/kevintech/telegram'; SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo -e "${R}Ejecuta como root.${Z}"; exit 1; }
mkdir -p "$D/logs" "$D/backups"
# Only replace executable code. Persistent data is intentionally preserved.
if [[ "$SRC" != "$D" ]]; then
  install -m 700 "$SRC/bot.py" "$D/bot.py.new"
  python3 -m py_compile "$D/bot.py.new"
  [[ -f "$D/bot.py" ]] && cp -a "$D/bot.py" "$D/bot.py.before-update.$(date +%s)" || true
  mv -f "$D/bot.py.new" "$D/bot.py"
fi
python3 -m py_compile "$D/bot.py"
systemctl restart kevintech-telegram
echo -e "${G}✔ Bot actualizado.${Z}"
echo -e "${G}✔ Datos, .env, usuarios, admins, referidos, cuotas y respaldos conservados.${Z}"
