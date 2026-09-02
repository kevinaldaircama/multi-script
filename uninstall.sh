#!/bin/bash
set -e
BASE="/etc/kevintech"
if [[ $EUID -ne 0 ]]; then echo "❌ Ejecuta como root."; exit 1; fi
clear 2>/dev/null || true
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  KEVINTECH MULTI SCRIPT — DESINSTALADOR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Esto eliminará el panel, bot, configuración y servicios instalados."
echo "Los datos de /etc/kevintech también serán eliminados."
echo
echo -n "Escribe DESINSTALAR para continuar: "
read -r confirm
[[ "$confirm" == "DESINSTALAR" ]] || { echo "❌ Cancelado."; exit 0; }

systemctl stop kevintech-telegram.service 2>/dev/null || true
systemctl disable kevintech-telegram.service 2>/dev/null || true
rm -f /etc/systemd/system/kevintech-telegram.service
systemctl daemon-reload 2>/dev/null || true

rm -f /usr/local/bin/menu /etc/profile.d/kevintech-banner.sh

# Elimina usuarios SSH creados por el panel, conservando root y cuentas del sistema.
if [[ -d "$BASE/usuarios" ]]; then
  awk -F: '$3>=1000&&$1!="nobody"{print $1}' /etc/passwd | while read -r u; do
    [[ -f "$BASE/limits/$u" ]] && userdel -r -f "$u" 2>/dev/null || true
  done
fi

rm -rf "$BASE"
echo
echo "🟢 KEVINTECH MULTI SCRIPT fue desinstalado correctamente."
