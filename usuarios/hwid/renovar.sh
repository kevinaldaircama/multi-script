#!/bin/bash
#==================================================
# kevintech Network Premium
# RENOVAR cuenta HWID (+N días) sin recrearla
# (puerto de "/hwid set expire <hwid> <days>" de kevintech)
#
# - Extiende la fecha de expiración del usuario SSH
# - Opcional: reinicia consumo de cuota al renovar
# - Reactiva cuentas expiradas automáticamente
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
LOG="$BASE/sistema/hwid_renovaciones.log"

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

clear
mv_brand_header "🔄 RENOVAR CUENTA HWID ⏰"
if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  📭 No hay usuarios por HWID registrados todavía.${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

#--------------------------------------------------
# Listar con estado
#--------------------------------------------------
count=0
declare -A MENU_U

for f in "$HWID_DIR"/*.hwid; do
    [[ -e "$f" ]] || continue
    count=$((count + 1))
    U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
    EX=$(grep -m1 "^EXPIRE:" "$f" | cut -d' ' -f2)
    LIM=$(grep -m1 "^LIMIT_GB:" "$f" | cut -d' ' -f2); [[ "$LIM" =~ ^[0-9]+$ ]] || LIM=0
    USED=$(grep -m1 "^USED_BYTES:" "$f" | cut -d' ' -f2); [[ "$USED" =~ ^[0-9]+$ ]] || USED=0

    if ! id "$U" &>/dev/null; then
        EST="${RED}SIN CUENTA${RESET}"
    elif passwd -S "$U" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
        EST="${RED}BLOQUEADA${RESET}"
    elif [[ "$EX" < "$(date +%Y-%m-%d)" ]]; then
        EST="${YELLOW}EXPIRADA${RESET}"
    else
        EST="${GREEN}ACTIVA${RESET}"
    fi

    MENU_U["$count"]="$U"
    local_lim="∞"; (( LIM > 0 )) && local_lim="${LIM}GB ($(gb $USED))"
    printf "${CYAN}║ ${WHITE}%02d) ${GREEN}%-12s${WHITE} │ Exp: %s │ Cuota: %-16s │ %b${RESET}\n" \
        "$count" "$U" "${EX:-???}" "$local_lim" "$EST"
done

echo
echo -e "${WHITE}  Total: ${GREEN}$count${WHITE} cuenta(s) HWID${RESET}"
echo
read -rp "$(echo -e "${CYAN}➜ Seleccione la cuenta a renovar: ${RESET}")" SEL

if [[ -z "${MENU_U[$SEL]:-}" ]]; then
    echo
    echo -e "${RED}❌ Selección inválida.${RESET}"
    sleep 2
    exit 1
fi

USER="${MENU_U[$SEL]}"
F="$HWID_DIR/$USER.hwid"

if ! id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}❌ El usuario $USER no existe en el sistema (¿eliminado?).${RESET}"
    sleep 2
    exit 1
fi

OLD_EXP=$(grep -m1 "^EXPIRE:" "$F" | cut -d' ' -f2)

echo
echo -e "${WHITE}  Cuenta: ${GREEN}$USER${WHITE} │ Expira: ${YELLOW}${OLD_EXP}${RESET}"
read -rp "$(echo -e "${GREEN}📅 ¿Cuántos días AGREGAR? (ej: 30): ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30
if ! [[ "$DIAS" =~ ^[0-9]+$ ]] || [[ "$DIAS" -lt 1 ]] || [[ "$DIAS" -gt 3650 ]]; then
    echo
    echo -e "${RED}❌ Días inválido (1 a 3650).${RESET}"
    sleep 2
    exit 1
fi

# Base para sumar: si ya expiró, sumar desde HOY; si sigue activa, desde su fecha
HOY=$(date +%Y-%m-%d)
BASE_SUMA="$OLD_EXP"
[[ "$OLD_EXP" < "$HOY" ]] && BASE_SUMA="$HOY"
NEW_EXP=$(date -d "$BASE_SUMA +$DIAS days" +"%Y-%m-%d")

if [[ -z "$NEW_EXP" ]]; then
    echo -e "${RED}❌ Error calculando la nueva fecha.${RESET}"
    sleep 2
    exit 1
fi

#--------------------------------------------------
# Aplicar expiración al sistema (reactiva si estaba vencida)
#--------------------------------------------------
usermod -e "$NEW_EXP" "$USER"
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Error aplicando expiración al sistema.${RESET}"
    sleep 3
    exit 1
fi

upsert_field "$F" "EXPIRE" "$NEW_EXP"

#--------------------------------------------------
# ¿Reiniciar cuota también?
#--------------------------------------------------
WAS_QUOTA_LOCKED=$(grep -m1 "^QUOTA_LOCKED:" "$F" | cut -d' ' -f2)
RESET_CUOTA="n"

if (( $(grep -m1 "^LIMIT_GB:" "$F" | cut -d' ' -f2 || echo 0) > 0 )) 2>/dev/null; then
    echo
    read -rp "$(echo -e "${YELLOW}¿Reiniciar consumo de cuota y desbloquear? [S/N]: ${RESET}")" RESET_CUOTA
fi

case "$RESET_CUOTA" in
    s|S|si|SI|y|Y)
        CUR=$(iptables -vxL "MV_HWID_${USER}" 2>/dev/null | awk '/RETURN/{print $2; exit}')
        [[ "$CUR" =~ ^[0-9]+$ ]] || CUR=0
        upsert_field "$F" "USED_BYTES" "0"
        upsert_field "$F" "LAST_COUNTER" "$CUR"
        upsert_field "$F" "QUOTA_LOCKED" "no"
        if [[ "$WAS_QUOTA_LOCKED" == "yes" ]]; then
            passwd -u "$USER" >/dev/null 2>&1
        fi
        ;;
esac

# Si estaba bloqueada por otro motivo (manual), NO tocamos ese bloqueo.

echo "$(date '+%Y-%m-%d %H:%M:%S') ♻ RENOVADA: $USER ${OLD_EXP} → ${NEW_EXP} (+${DIAS}d)$([[ "$RESET_CUOTA" =~ ^[sSyY] ]] && echo ' + cuota reiniciada')" >> "$LOG"

#--------------------------------------------------
# Resumen
#--------------------------------------------------
clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ kevintech Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}          ✅ CUENTA RENOVADA CON ÉXITO                 ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 👤 Usuario      : ${GREEN}%-35s${WHITE}│\n" "$USER"
printf "${WHITE}│ 📅 Expiraba     : ${YELLOW}%-35s${WHITE}│\n" "$OLD_EXP"
printf "${WHITE}│ 📅 Expira AHORA : ${GREEN}%-35s${WHITE}│\n" "$NEW_EXP"
printf "${WHITE}│ ➕ Agregados    : ${GREEN}%-35s${WHITE}│\n" "$DIAS días"
[[ "$RESET_CUOTA" =~ ^[sSyY] ]] && printf "${WHITE}│ 📊 Cuota        : ${GREEN}%-35s${WHITE}│\n" "reiniciada y desbloqueada"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo
echo -e "${GRAY}  Registro: $LOG${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
