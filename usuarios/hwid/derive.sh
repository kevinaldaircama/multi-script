#!/bin/bash
#==================================================
# kevintech Network Premium
# Helper central: derivar contraseña desde HWID
# Uso: hwid_derive.sh <HWID>
# Salida: contraseña derivada (14 hex chars)
# Usado por add_hwid.sh, change_hwid.sh y el bot
# (ssh_utils.py ejecuta este script vía SSH para
#  que TODAS las cuentas HWID usen la misma fórmula)
#==================================================

BASE="/etc/kevintech"

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────

# Design System premium + navegación + idioma
[[ -f "$BASE/lib/ui.sh" ]] && source "$BASE/lib/ui.sh"
[[ -f "$BASE/lib/nav.sh" ]] && source "$BASE/lib/nav.sh" 2>/dev/null || true
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

CONFIG="$BASE/config.conf"

[[ -f "$CONFIG" ]] && source "$CONFIG"


HWID="$1"

if [[ -z "$HWID" ]] || [[ -z "$HWID_SECRET" ]]; then
    echo ""
    exit 1
fi

echo -n "${HWID}|${HWID_SECRET}" | sha256sum | cut -c1-14
