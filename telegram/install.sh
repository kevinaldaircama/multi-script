#!/usr/bin/env bash
set -Eeuo pipefail
C='\033[1;36m'; G='\033[1;92m'; Y='\033[1;93m'; R='\033[1;91m'; M='\033[1;95m'; W='\033[1;97m'; Z='\033[0m'
D='/etc/kevintech/telegram'; SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -eq 0 ]] || { echo -e "${R}✘ Ejecuta como root.${Z}"; exit 1; }
mkdir -p "$D/logs" "$D/handlers"; chmod 700 "$D" "$D/logs"
echo -e "${C}╔════════════════════════════════════════════════════════════╗${Z}"
echo -e "${C}║${M}       🚀 KEVINTECH TELEGRAM BOT • V4 PREMIUM         ${C}║${Z}"
echo -e "${C}║${W}          INSTALADOR SEGURO • AUTO RECOVERY           ${C}║${Z}"
echo -e "${C}╚════════════════════════════════════════════════════════════╝${Z}"
command -v python3 >/dev/null 2>&1 || { echo -e "${Y}➜ Instalando Python 3...${Z}"; apt-get update -qq; apt-get install -y python3; }
backup="$D/.backup-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$backup"
for f in bot.py setup.sh install.sh service.sh health.sh update.sh README.md .gitignore; do [[ -f "$D/$f" ]] && cp -a "$D/$f" "$backup/$f" || true; done
if [[ "$SRC" != "$D" ]]; then
  for f in bot.py setup.sh install.sh service.sh health.sh update.sh README.md .gitignore; do [[ -f "$SRC/$f" ]] && install -m 700 "$SRC/$f" "$D/$f" || true; done
  [[ -d "$SRC/handlers" ]] && cp -a "$SRC/handlers/." "$D/handlers/" 2>/dev/null || true
else
  echo -e "${G}✔ Origen = destino; no se copian archivos sobre sí mismos.${Z}"
fi
if [[ ! -f "$D/.env" ]]; then bash "$D/setup.sh"; else chmod 600 "$D/.env"; echo -e "${G}✔ .env existente conservado.${Z}"; fi
python3 -m py_compile "$D/bot.py"
cat > /etc/systemd/system/kevintech-telegram.service <<EOF
[Unit]
Description=KevinTech Multi Script Telegram Bot V4 Premium
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=10
[Service]
Type=simple
User=root
WorkingDirectory=$D
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 $D/bot.py
Restart=always
RestartSec=2
TimeoutStartSec=20
TimeoutStopSec=10
StandardOutput=append:$D/logs/bot.log
StandardError=append:$D/logs/bot.log
[Install]
WantedBy=multi-user.target
EOF
chmod 600 "$D/.env"; systemctl daemon-reload; systemctl enable kevintech-telegram >/dev/null; systemctl restart kevintech-telegram; sleep 1
if systemctl is-active --quiet kevintech-telegram; then echo -e "${G}╔════════════════════════════════════════════════════════════╗${Z}"; echo -e "${G}║              ✅ INSTALACIÓN COMPLETADA                   ║${Z}"; echo -e "${G}║              🟢 BOT ACTIVO Y PROTEGIDO                   ║${Z}"; echo -e "${G}╚════════════════════════════════════════════════════════════╝${Z}"; else echo -e "${R}✘ El servicio no inició.${Z}"; journalctl -u kevintech-telegram -n 40 --no-pager; exit 1; fi
echo -e "${C}📜 Logs:${Z} journalctl -u kevintech-telegram -f"
echo -e "${C}❤️ Health:${Z} bash $D/health.sh"
