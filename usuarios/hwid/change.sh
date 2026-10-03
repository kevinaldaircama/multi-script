#!/bin/bash
#==================================================
# kevintech Network Premium
# Cambiar HWID de un usuario existente
# (El cliente cambió de dispositivo → nuevo HWID)
# La contraseña se REGENERA automáticamente desde
# el nuevo HWID. La cuenta vieja deja de funcionar.
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

CONFIG="$BASE/config.conf"
HWID_DIR="$BASE/hwids"


[[ -f "$CONFIG" ]] && source "$CONFIG"

if [[ -z "$HWID_SECRET" ]]; then
    echo -e "${RED}❌ No hay HWID_SECRET en config.conf. Crea una cuenta HWID primero.${RESET}"
    sleep 3
    exit 1
fi

#==================================================
# DERIVAR CONTRASEÑA (misma fórmula que add_hwid.sh)
#==================================================
derive_pass() {
    local HW="$1"
    echo -n "${HW}|${HWID_SECRET}" | sha256sum | cut -c1-14
}

clear
mv_brand_header "🔄 CAMBIAR HWID DE USUARIO"
if [[ ! -d "$HWID_DIR" ]] || [[ -z "$(ls -A "$HWID_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}  📭 No hay usuarios por HWID registrados todavía.${RESET}"
    echo
    read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
    exit 0
fi

#==================================================
# LISTAR usuarios HWID numerados
#==================================================

count=0
declare -A HWID_MENU      # numero -> usuario

for f in "$HWID_DIR"/*.hwid; do
    [[ -e "$f" ]] || continue
    count=$((count + 1))
    U=$(grep -m1 "^USER:" "$f" | cut -d' ' -f2)
    HW=$(grep -m1 "^HWID:" "$f" | cut -d' ' -f2)
    EX=$(grep -m1 "^EXPIRE:" "$f" | cut -d' ' -f2)
    HWID_MENU["$count"]="$U"
    printf "${CYAN}║ ${WHITE}%02d) ${GREEN}%-12s${WHITE} │ HWID: ${YELLOW}%-22s${WHITE} │ Exp: ${GREEN}%s${RESET}\n" "$count" "$U" "$HW" "$EX"
done

echo
echo -e "${WHITE}  Total: ${GREEN}$count${WHITE} usuario(s) por HWID${RESET}"
echo
read -rp "$(echo -e "${CYAN}➜ ${GOLD}Seleccione el usuario${WHITE} ➤ ${RESET}")" SEL

if [[ -z "${HWID_MENU[$SEL]:-}" ]]; then
    echo
    echo -e "${RED}❌ Selección inválida.${RESET}"
    sleep 2
    exit 1
fi

USER="${HWID_MENU[$SEL]}"

if ! id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}❌ El usuario $USER no existe en el sistema (¿eliminado?).${RESET}"
    sleep 2
    exit 1
fi

#==================================================
# NUEVO HWID
#==================================================

echo
echo -e "${YELLOW}📲 Nuevo HWID del dispositivo (HTTP Custom → Ajustes → HWID)${RESET}"
read -rp "$(echo -e "${GREEN}🔒 Nuevo HWID        : ${RESET}")" NEWHWID

if [[ -z "$NEWHWID" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar el nuevo HWID.${RESET}"
    sleep 2
    exit 1
fi

if ! [[ "$NEWHWID" =~ ^[A-Za-z0-9_:.-]+$ ]] || [[ ${#NEWHWID} -lt 4 ]] || [[ ${#NEWHWID} -gt 64 ]]; then
    echo
    echo -e "${RED}❌ HWID inválido (solo letras, números y _ : . - ; de 4 a 64 caracteres).${RESET}"
    sleep 2
    exit 1
fi

# HWID ya registrado en OTRA cuenta?
DUPLICADO=$(grep -rl "^HWID: $NEWHWID$" "$HWID_DIR" 2>/dev/null | grep -v "/$USER.hwid$" | head -n1)
if [[ -n "$DUPLICADO" ]]; then
    echo
    echo -e "${RED}❌ Ese HWID ya está registrado en: $(basename "$DUPLICADO" .hwid)${RESET}"
    sleep 3
    exit 1
fi

#==================================================
# REGENERAR CONTRASEÑA + ACTUALIZAR REGISTRO
#==================================================

OLDPASS=$(derive_pass "$(grep -m1 "^HWID:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)")
NEWPASS=$(derive_pass "$NEWHWID")

# Bloquear sesiones activas del usuario antes de cambiar
pkill -u "$USER" >/dev/null 2>&1

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$NEWPASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al regenerar la contraseña.${RESET}"
    sleep 3
    exit 1
fi

# Actualizar registro .hwid (preservar EXPIRE/MAXCONN/CREATED)
EXPIRE=$(grep -m1 "^EXPIRE:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)
MAXCONN=$(grep -m1 "^MAXCONN:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)
CREATED=$(grep -m1 "^CREATED:" "$HWID_DIR/$USER.hwid" | cut -d' ' -f2)
[[ -z "$MAXCONN" ]] && MAXCONN=2

cat > "$HWID_DIR/$USER.hwid" <<EOF
# kevintech Network - Usuario por HWID (v2)
USER: $USER
HWID: $NEWHWID
PASS: $NEWPASS
EXPIRE: $EXPIRE
MAXCONN: $MAXCONN
CREATED: $CREATED
CHANGED: $(date +"%Y-%m-%d %H:%M:%S")
EOF

clear

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ kevintech Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}           HWID CAMBIADO CON ÉXITO ✅                 ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

echo -e "${YELLOW}              👤 CUENTA REGENERADA (Usuario + HWID + Días)${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 👤 Usuario      : ${GREEN}%-35s${WHITE}│\n" "$USER"
printf "${WHITE}│ 🔒 HWID (nuevo) : ${GREEN}%-35s${WHITE}│\n" "$NEWHWID"
printf "${WHITE}│ 📅 Expira       : ${GREEN}%-35s${WHITE}│\n" "$EXPIRE"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}       🔐 NUEVA CONTRASEÑA GENERADA (NO compartir)${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 🔑 Contraseña   : ${MAGENTA}%-35s${WHITE}│\n" "$NEWPASS"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${GREEN}  ✅ El config del cliente DEBE actualizarse con:${RESET}"
IP=$(curl -4 -s ifconfig.me)
[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')
HOST="${SERVER_DOMAIN:-$IP}"
printf "${GREEN}  📲 %s:80@%s:%s${RESET}\n" "$IP" "$USER" "$NEWPASS"
echo
echo -e "${RED}  ⚠ El config anterior (con el HWID viejo) YA NO FUNCIONA.${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Pulse Enter para volver...${RESET}")"
exit 0
