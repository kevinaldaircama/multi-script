#!/bin/bash
#==================================================
# kevintech Network Premium
# CUOTA DE DATOS por cuenta HWID
# (puerto de "/hwid set limit <hwid> <num> MB/GB/TB" de kevintech)
#
# - Fijar cuota GB (0 = ilimitado)
# - Ver consumo en tiempo real (iptables counters)
# - Reiniciar consumo / desbloquear por cuota
# - Instalar monitor cron cada 5 min
#==================================================

GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
CYAN="${MV_CYN:-\e[1;96m}"
MAGENTA="${MV_MAG:-\e[1;95m}"
WHITE="${MV_WHT:-\e[1;97m}"
GRAY="${MV_DIM:-\e[1;90m}"
RESET="${MV_R:-\e[0m}"

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
HWID_DIR="$BASE/hwids"
LOG="$BASE/sistema/hwid_bloqueos.log"
MONITOR="$BASE/herramientas/hwid_quota_monitor.sh"
CRON_TAG="kevintech-hwid-quota"

[[ -f "$CONFIG" ]] && source "$CONFIG"

mkdir -p "$HWID_DIR" "$BASE/sistema"

upsert_field() {
    local FILE="$1" KEY="$2" VAL="$3"
    if grep -q "^${KEY}:" "$FILE" 2>/dev/null; then
        sed -i "s|^${KEY}:.*|${KEY}: ${VAL}|" "$FILE"
    else
        echo "${KEY}: ${VAL}" >> "$FILE"
    fi
}
gb() { awk "BEGIN{printf \"%.2f\", $1/1073741824}"; }

instalar_cron() {
    if crontab -l 2>/dev/null | grep -q "hwid_quota_monitor"; then
        echo -e "${GREEN}  ✓ Monitor ya instalado (cron */5).${RESET}"
        return 0
    fi
    chmod +x "$MONITOR" 2>/dev/null
    (crontab -l 2>/dev/null | grep -v "$CRON_TAG"; \
     echo "*/5 * * * * bash $MONITOR >/dev/null 2>&1 #$CRON_TAG") | crontab -
    [[ $? -eq 0 ]] && echo -e "${GREEN}  ✅ Monitor de cuota instalado (cada 5 min).${RESET}"
}

listar_uso() {
    local count=0
    printf "${CYAN}  %-14s %10s %10s %8s  %s\n${RESET}" "USUARIO" "USADO" "CUOTA" "USO%" "ESTADO"
    echo -e "${GRAY}  ────────────────────────────────────────────────────────────${RESET}"
    for f in "$HWID_DIR"/*.hwid; do
        [[ -e "$f" ]] || continue
        local U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
        id "$U" &>/dev/null || continue
        count=$((count+1))
        local LIM=$(grep -m1 "^LIMIT_GB:" "$f" | cut -d' ' -f2); [[ "$LIM" =~ ^[0-9]+$ ]] || LIM=0
        local USED=$(grep -m1 "^USED_BYTES:" "$f" | cut -d' ' -f2); [[ "$USED" =~ ^[0-9]+$ ]] || USED=0
        local LOCKED=$(grep -m1 "^QUOTA_LOCKED:" "$f" | cut -d' ' -f2)
        local EST="${GREEN}ACTIVO${RESET}"
        passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L" && EST="${RED}BLOQUEADO${RESET}"
        [[ "$LOCKED" == "yes" ]] && EST="${RED}CUOTA✗${RESET}"
        local PCT="--"
        (( LIM > 0 )) && PCT=$(awk "BEGIN{printf \"%d\", ($USED/($LIM*1073741824))*100; exit ($USED/($LIM*1073741824)>1)?0:1}" 2>/dev/null || echo "100")
        local COLOR_PCT="${GREEN}"
        (( LIM > 0 )) && (( ${PCT:-0} >= 80 )) && COLOR_PCT="${YELLOW}"
        (( LIM > 0 )) && (( ${PCT:-0} >= 100 )) && COLOR_PCT="${RED}"
        local LIMTXT="${LIM}GB"; (( LIM == 0 )) && LIMTXT="∞"
        printf "  %-14s %8sGB %8sGB %6s%%  %b\n" "$U" "$(gb $USED)" "$LIMTXT" "${COLOR_PCT}${PCT}${RESET}" "$EST"
    done
    (( count == 0 )) && echo -e "${YELLOW}  📭 No hay cuentas HWID.${RESET}"
    return $count
}

while true; do
clear
mv_brand_header "📊 CUOTA DE DATOS HWID 🔐"
if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  📭 No hay usuarios por HWID. Crea uno con [09] Usuario HWID.${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

echo -e "${WHITE}  ➤ [1] ${GREEN}Fijar cuota a un usuario${RESET}"
echo -e "${WHITE}  ➤ [2] ${GREEN}Reiniciar consumo / desbloquear cuota${RESET}"
echo -e "${WHITE}  ➤ [3] ${GREEN}Instalar monitor automático (cron)${RESET}"
echo -e "${WHITE}  ➤ [4] ${GREEN}Actualizar tabla ahora${RESET}"
echo -e "${WHITE}  ➤ [0] ${YELLOW}Volver${RESET}"
echo
echo -e "${CYAN}  ─── CONSUMO ACTUAL ───${RESET}"
listar_uso
echo

read -rp "$(echo -e "${CYAN}➜ Opción: ${RESET}")" OP

case "$OP" in

1)
    read -rp "$(echo -e "${GREEN}👤 Usuario: ${RESET}")" SEL_U
    F="$HWID_DIR/$SEL_U.hwid"
    if [[ ! -f "$F" ]] || ! id "$SEL_U" &>/dev/null; then
        echo -e "${RED}❌ Usuario HWID no válido.${RESET}"; sleep 2; continue
    fi
    echo -e "${GRAY}  Cuota total acumulada de la cuenta. Ej: 200, 500, 1000 (GB)${RESET}"
    echo -e "${GRAY}  0 = ILIMITADO (desactiva la cuota)${RESET}"
    read -rp "$(echo -e "${GREEN}📊 Cuota (GB): ${RESET}")" NEWLIM
    [[ "$NEWLIM" =~ ^[0-9]+$ ]] || { echo -e "${RED}❌ Valor inválido.${RESET}"; sleep 2; continue; }

    upsert_field "$F" "LIMIT_GB" "$NEWLIM"

    # Aplicar efecto inmediato si ya se pasó
    USED=$(grep -m1 "^USED_BYTES:" "$F" | cut -d' ' -f2); [[ "$USED" =~ ^[0-9]+$ ]] || USED=0
    if (( NEWLIM > 0 )) && (( USED >= NEWLIM * 1073741824 )); then
        passwd -l "$SEL_U" >/dev/null 2>&1; pkill -u "$SEL_U" >/dev/null 2>&1
        upsert_field "$F" "QUOTA_LOCKED" "yes"
        echo "$(date '+%Y-%m-%d %H:%M:%S') ⚠ CUOTA FIJADA < CONSUMO: $SEL_U bloqueado (${NEWLIM}GB < $(gb $USED)GB)" >> "$LOG"
        echo -e "${RED}  ⚠ El consumo actual YA supera la cuota → cuenta BLOQUEADA ahora.${RESET}"
    else
        echo -e "${GREEN}  ✅ Cuota ${NEWLIM}GB fijada para $SEL_U${RESET}"
    fi
    instalar_cron >/dev/null 2>&1
    sleep 2
    ;;

2)
    read -rp "$(echo -e "${GREEN}👤 Usuario: ${RESET}")" SEL_U
    F="$HWID_DIR/$SEL_U.hwid"
    if [[ ! -f "$F" ]] || ! id "$SEL_U" &>/dev/null; then
        echo -e "${RED}❌ Usuario HWID no válido.${RESET}"; sleep 2; continue
    fi
    WAS_LOCKED=$(grep -m1 "^QUOTA_LOCKED:" "$F" | cut -d' ' -f2)

    UID_N=$(id -u "$SEL_U")
    CUR=$(iptables -vxL "MV_HWID_${SEL_U}" 2>/dev/null | awk '/RETURN/{print $2; exit}')
    [[ "$CUR" =~ ^[0-9]+$ ]] || CUR=0

    upsert_field "$F" "USED_BYTES" "0"
    upsert_field "$F" "LAST_COUNTER" "$CUR"
    upsert_field "$F" "QUOTA_LOCKED" "no"

    # Desbloquear SOLO si el bloqueo fue por cuota
    if [[ "$WAS_LOCKED" == "yes" ]]; then
        passwd -u "$SEL_U" >/dev/null 2>&1
        echo "$(date '+%Y-%m-%d %H:%M:%S') ♻ CUOTA REINICIADA: $SEL_U desbloqueado y consumo a 0" >> "$LOG"
        echo -e "${GREEN}  ✅ Consumo reiniciado y cuenta DESBLOQUEADA.${RESET}"
    else
        echo -e "${GREEN}  ✅ Consumo reiniciado a 0.${RESET}"
    fi
    sleep 2
    ;;

3)
    instalar_cron
    sleep 2
    ;;

4)
    bash "$MONITOR" 2>/dev/null
    echo -e "${GREEN}  ✅ Tabla actualizada.${RESET}"
    sleep 1
    ;;

0) exit 0 ;;
*) ;;
esac

done
