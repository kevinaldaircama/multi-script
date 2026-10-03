#!/bin/bash
#==================================================
# kevintech Network Premium
# Ver bloqueos automáticos por anti-share HWID
#==================================================

#======== COLORES ========#
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
CYAN="${MV_CYN:-\e[1;96m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_DIM:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

#======== CONFIG ========#
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

SISTEMA="$BASE/sistema"
LOG="$SISTEMA/hwid_bloqueos.log"


clear
mv_brand_header "🛡 BLOQUEOS POR ANTI-SHARE HWID 🛡"
if [[ ! -f "$LOG" ]] || [[ ! -s "$LOG" ]]; then
    echo -e "${GREEN}  ✅ No hay bloqueos por anti-share registrados.${RESET}"
    echo
    echo -e "${GRAY}  Los bloqueos aparecen aquí cuando una cuenta HWID excede${RESET}"
    echo -e "${GRAY}  sus conexiones simultáneas (señal de compartición).${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

echo -e "${YELLOW}  📋 HISTORIAL DE BLOQUEOS:${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
while IFS= read -r LINEA; do
    [[ -z "$LINEA" ]] && continue
    echo -e "${WHITE}│ ${RED}⚠${WHITE} ${LINEA:0:96}${CYAN}│${RESET}"
done < "$LOG"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${GREEN}  💡 Para desbloquear: Menú Usuarios → [07] Bloquear → desbloquear.${RESET}"
echo -e "${GRAY}  ⚠ Si un cliente fue bloqueado por anti-share, revisa si compartió${RESET}"
echo -e "${GRAY}  su config. Si fue un falso positivo (misma persona, varios túneles),${RESET}"
echo -e "${GRAY}  súbele las conexiones máx con: ${GREEN}Cambiar HWID [11]${RESET} o editando el .hwid.${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
