#!/bin/bash
# KevinTech Telegram Bot - instalación / actualización del bot
set -euo pipefail
BASE="/etc/kevintech"
TD="$BASE/telegram"
ENV="$TD/.env"
SERVICE="kevintech-telegram.service"
PY="$TD/bot.py"

C="\e[1;96m"; G="\e[1;92m"; R="\e[1;91m"; Y="\e[1;93m"; W="\e[1;97m"; X="\e[0m"

pause(){ echo; read -rp "Presiona ENTER para continuar..."; }

install_bot(){
  clear
  echo -e "${C}╔══════════════════════════════════════════════════════════════╗${X}"
  echo -e "${C}║${X} ${W}\e[1m                 BOT TELEGRAM KEVINTECH${X}                 ${C}║${X}"
  echo -e "${C}╚══════════════════════════════════════════════════════════════╝${X}"
  echo
  mkdir -p "$TD/logs" "$TD/backups"
  command -v python3 >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1; apt-get install -y python3 >/dev/null 2>&1; }
  if [[ ! -f "$PY" ]]; then echo -e "${R}❌ No se encontró $PY${X}"; pause; return; fi

  if [[ ! -f "$ENV" ]]; then
    echo -e "${Y}Configuración inicial del bot${X}"; echo
    read -rp "Token del bot: " BOT_TOKEN
    read -rp "ID del super admin: " ADMIN_ID
    if [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ || ! "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
      echo -e "${R}❌ Token o ID inválido.${X}"; pause; return
    fi
    cat > "$ENV" <<EOT
BOT_TOKEN="$BOT_TOKEN"
ADMIN_ID="$ADMIN_ID"
EOT
    chmod 600 "$ENV"
  fi

  cat > "/etc/systemd/system/$SERVICE" <<EOT
[Unit]
Description=KevinTech Telegram Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$TD
ExecStart=/usr/bin/python3 $PY
Restart=always
RestartSec=3
User=root
ExecStartPre=/usr/bin/pkill -f "python3 $PY"
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOT

  chmod 700 "$PY"; chmod 600 "$ENV"
  python3 -m py_compile "$PY" || { echo -e "${R}❌ Error de sintaxis en bot.py. No se reinició el servicio.${X}"; pause; return; }
  # Evita conflictos de polling si quedó una instancia manual del mismo bot.
  pkill -f "python3 $PY" >/dev/null 2>&1 || true
  systemctl daemon-reload
  systemctl enable "$SERVICE" >/dev/null 2>&1
  systemctl restart "$SERVICE"
  sleep 2
  echo
  echo -e "${G}╔══════════════════════════════════════════════════════════════╗${X}"
  echo -e "${G}║${X} ${W}\e[1m             ✅ INSTALACIÓN REALIZADA${X}                  ${G}║${X}"
  echo -e "${G}╚══════════════════════════════════════════════════════════════╝${X}"
  echo
  echo -e "${G}✔ Bot Telegram instalado/actualizado correctamente.${X}"
  echo -e "${G}✔ Servicio: $SERVICE${X}"
  if systemctl is-active --quiet "$SERVICE"; then
    echo -e "${G}✔ Estado: ACTIVO${X}"
  else
    echo -e "${R}❌ Estado: DETENIDO${X}"
    echo -e "${Y}Últimos errores:${X}"
    journalctl -u "$SERVICE" -n 20 --no-pager 2>/dev/null || true
  fi
  echo
  pause
}

change_data(){
  clear
  echo -e "${C}╔══════════════════════════════════════════════════════════════╗${X}"
  echo -e "${C}║${X} ${W}\e[1m                 DATOS DEL BOT TELEGRAM${X}                 ${C}║${X}"
  echo -e "${C}╚══════════════════════════════════════════════════════════════╝${X}"
  echo
  echo "1) Cambiar ID del super admin"
  echo "2) Cambiar token del bot"
  echo "0) Volver"
  echo
  read -rp "Seleccione una opción: " op
  [[ -f "$ENV" ]] || { echo -e "${R}❌ Primero instala el bot.${X}"; pause; return; }
  case "$op" in
    1) read -rp "Nuevo ID del super admin: " id; [[ "$id" =~ ^[0-9]+$ ]] || { echo -e "${R}❌ ID inválido.${X}"; pause; return; }; sed -i "s/^ADMIN_ID=.*/ADMIN_ID=\"$id\"/" "$ENV"; echo -e "${G}✅ ID actualizado.${X}";;
    2) read -rp "Nuevo token del bot: " tok; [[ "$tok" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo -e "${R}❌ Token inválido.${X}"; pause; return; }; sed -i "s/^BOT_TOKEN=.*/BOT_TOKEN=\"$tok\"/" "$ENV"; echo -e "${G}✅ Token actualizado.${X}";;
    0) return;;
    *) echo -e "${R}❌ Opción inválida.${X}";;
  esac
  chmod 600 "$ENV"; systemctl restart "$SERVICE" 2>/dev/null || true; pause
}

remove_bot(){
  clear
  read -rp "¿Eliminar el bot y su servicio? [Y/N]: " a
  [[ "${a,,}" == "y" ]] || return
  systemctl disable --now "$SERVICE" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/$SERVICE"
  systemctl daemon-reload
  rm -rf "$TD"
  mkdir -p "$TD"
  echo -e "${G}✅ Bot Telegram desinstalado correctamente.${X}"
  pause
}

while true; do
 clear
 echo -e "${C}╔══════════════════════════════════════════════════════════════╗${X}"
 echo -e "${C}║${X} ${W}\e[1m                    BOT TELEGRAM${X}                         ${C}║${X}"
 echo -e "${C}╚══════════════════════════════════════════════════════════════╝${X}"
 echo
 echo -e "${Y}[1]${W} Instalar / Actualizar bot"
 echo -e "${Y}[2]${W} Cambiar datos"
 echo -e "${Y}[3]${W} Desinstalar bot"
 echo -e "${Y}[0]${W} Volver"
 echo
 read -rp "➜ Seleccione una opción: " op
 case "$op" in 1) install_bot;; 2) change_data;; 3) remove_bot;; 0) exit 0;; *) echo -e "${R}❌ Opción inválida.${X}"; sleep 1;; esac
done
