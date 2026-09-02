#!/usr/bin/env bash
set -Eeuo pipefail
C='\033[1;36m'; G='\033[1;92m'; R='\033[1;91m'; Z='\033[0m'; D='/etc/kevintech/telegram'; SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || exit 1
if [[ "$SRC" != "$D" ]]; then
  cp -a "$D/bot.py" "$D/bot.py.bak.$(date +%s)" 2>/dev/null || true
  [[ -f "$D/.env" ]] && cp -a "$D/.env" "$D/.env.preserve" 2>/dev/null || true
  [[ -f "$D/data.json" ]] && cp -a "$D/data.json" "$D/data.json.preserve" 2>/dev/null || true
  install -m 700 "$SRC/bot.py" "$D/bot.py"
  [[ -f "$D/.env.preserve" ]] && mv -f "$D/.env.preserve" "$D/.env" || true
  [[ -f "$D/data.json.preserve" ]] && mv -f "$D/data.json.preserve" "$D/data.json" || true
fi
python3 -m py_compile "$D/bot.py"; systemctl restart kevintech-telegram; echo -e "${G}✔ Bot actualizado sin tocar .env.${Z}"
