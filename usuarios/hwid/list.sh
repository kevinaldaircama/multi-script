#!/bin/bash
#==================================================
# kevintech Network Premium
# Listar Usuarios con HWID
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

HWID_DIR="$BASE/hwids"


clear
mv_brand_header "📋 LISTA DE USUARIOS CON HWID 🔐"
if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  📭 No hay usuarios con HWID registrados todavía.${RESET}"
    echo
    echo -e "${WHITE}  ➤ Use la opción: ${GREEN}[09] Usuario HWID${WHITE} para crear uno.${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

count=0
for f in "$HWID_DIR"/*.hwid; do
    [[ -e "$f" ]] || continue
    count=$((count + 1))
    USER=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
    HWID=$(grep -m1 "^HWID:" "$f" | cut -d' ' -f2)
    PASS=$(grep -m1 "^PASS:" "$f" | cut -d' ' -f2)
    EXPIRE=$(grep -m1 "^EXPIRE:" "$f" | cut -d' ' -f2)
    MAXCONN=$(grep -m1 "^MAXCONN:" "$f" | cut -d' ' -f2)

    # Estado: BLOQUEADO / ACTIVO / EXPIRADO / CUOTA AGOTADA
    QLOCK=$(grep -m1 "^QUOTA_LOCKED:" "$f" | cut -d' ' -f2)
    if ! id "$USER" &>/dev/null; then
        ESTADO="${RED}❌ SIN CUENTA${RESET}"
    elif [[ "$QLOCK" == "yes" ]]; then
        ESTADO="${RED}📊 CUOTA AGOTADA${RESET}"
    elif passwd -S "$USER" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
        ESTADO="${RED}🔒 BLOQUEADO${RESET}"
    elif [[ "$EXPIRE" < "$(date +%Y-%m-%d)" ]]; then
        ESTADO="${YELLOW}⏰ EXPIRADO${RESET}"
    else
        ESTADO="${GREEN}✅ ACTIVO${RESET}"
    fi

    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
    printf "${WHITE}│ 👤 Usuario    : ${GREEN}%-35s${WHITE}│\n" "$USER"
    printf "${WHITE}│ 🔒 HWID       : ${YELLOW}%-35s${WHITE}│\n" "$HWID"
    printf "${WHITE}│ 🔑 Contraseña : ${MAGENTA}%-35s${WHITE}│\n" "$PASS"
    printf "${WHITE}│ 📅 Expira     : ${GREEN}%-35s${WHITE}│\n" "$EXPIRE"
    printf "${WHITE}│ 🔗 Conexiones : ${GREEN}%-35s${WHITE}│\n" "$MAXCONN"

    # Cuota de datos (si el monitor la registró)
    LIM=$(grep -m1 "^LIMIT_GB:" "$f" | cut -d' ' -f2)
    if [[ "$LIM" =~ ^[0-9]+$ ]] && (( LIM > 0 )); then
        USED=$(grep -m1 "^USED_BYTES:" "$f" | cut -d' ' -f2); [[ "$USED" =~ ^[0-9]+$ ]] || USED=0
        TXT=$(awk "BEGIN{printf \"%.2f / %s GB (%.0f%%)\", $USED/1073741824, $LIM, ($USED/($LIM*1073741824))*100}")
        COLOR_C="${GREEN}"
        PCT=$(awk "BEGIN{printf \"%d\", ($USED/($LIM*1073741824))*100}")
        (( PCT >= 80 )) && COLOR_C="${YELLOW}"
        (( PCT >= 100 )) && COLOR_C="${RED}"
        printf "${WHITE}│ 📊 Cuota      : ${COLOR_C}%-35s${WHITE}│\n" "$TXT"
    elif [[ "$LIM" == "0" ]]; then
        printf "${WHITE}│ 📊 Cuota      : ${GRAY}%-35s${WHITE}│\n" "∞ ilimitado"
    fi

    printf "${WHITE}│ 📊 Estado     : %b%-35s${WHITE}│\n" "$ESTADO" ""
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
    echo
done

echo -e "${GREEN}  Total: $count usuario(s) con HWID${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
