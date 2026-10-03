#!/bin/bash
#==================================================
# kevintech Network Premium
# Crear Usuario SSH por HWID (v2 — sin contraseña elegida)
# El vendedor solo ingresa: USUARIO + HWID + DÍAS
# La contraseña se DERIVA del HWID + secreto del servidor:
#   nadie la elige, es única por dispositivo y regenerable.
# Entrega: Usuario + HWID + Días (config con credencial incrustada)
#==================================================

#======== COLORES ========#
GREEN="${MV_GRN:-\e[1;92m}"
RED="${MV_RED:-\e[1;91m}"
YELLOW="${MV_YLW:-\e[1;93m}"
BLUE="${MV_BLU:-\e[1;94m}"
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


[[ -f "$CONFIG" ]] && source "$CONFIG"
HWID_DIR="$BASE/hwids"

[[ -f "$CONFIG" ]] && source "$CONFIG"

mkdir -p "$HWID_DIR" "$SISTEMA"

#==================================================
# SECRETO MAESTRO HWID (crear si no existe)
#==================================================
if [[ -z "$HWID_SECRET" ]]; then
    HWID_SECRET=$(openssl rand -hex 24 2>/dev/null || (echo "mv$(date +%s%N)$RANDOM" | sha256sum | cut -c1-48))
    if grep -q '^HWID_SECRET=' "$CONFIG" 2>/dev/null; then
        sed -i "s|^HWID_SECRET=.*|HWID_SECRET=\"$HWID_SECRET\"|" "$CONFIG"
    else
        echo "" >> "$CONFIG"
        echo "#==============================" >> "$CONFIG"
        echo "# SECRETO MAESTRO HWID" >> "$CONFIG"
        echo "# Contraseña de cuenta HWID = derivada(HWID + HWID_SECRET)" >> "$CONFIG"
        echo "# No compartirlo. Cambiarlo invalida todas las cuentas HWID." >> "$CONFIG"
        echo "#==============================" >> "$CONFIG"
        echo "HWID_SECRET=\"$HWID_SECRET\"" >> "$CONFIG"
    fi
fi

#==================================================
# DERIVAR CONTRASEÑA desde HWID + SECRETO
# Determinística: mismo HWID => misma contraseña.
#==================================================
derive_pass() {
    local HW="$1"
    echo -n "${HW}|${HWID_SECRET}" | sha256sum | cut -c1-14
}

while true; do

clear
mv_brand_header "CREAR USUARIO POR HWID 🔐 (v2)"
read -rp "$(echo -e "${GREEN}👤 Usuario            : ${RESET}")" USER

if [[ -z "$USER" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar un nombre de usuario.${RESET}"
    sleep 2
    continue
fi

if ! [[ "$USER" =~ ^[a-z0-9_]{3,20}$ ]]; then
    echo
    echo -e "${RED}❌ Usuario inválido (minúsculas, números y _ ; 3 a 20 caracteres).${RESET}"
    sleep 2
    continue
fi

if id "$USER" &>/dev/null; then
    echo
    echo -e "${RED}❌ El usuario ya existe.${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}📅 Duración (días)    : ${RESET}")" DIAS

[[ -z "$DIAS" ]] && DIAS=30

if ! [[ "$DIAS" =~ ^[0-9]+$ ]] || [[ "$DIAS" -lt 1 ]] || [[ "$DIAS" -gt 3650 ]]; then
    echo
    echo -e "${RED}❌ Días inválido (1 a 3650).${RESET}"
    sleep 2
    continue
fi

read -rp "$(echo -e "${GREEN}👥 Conexiones máx (2): ${RESET}")" MAXCONN

[[ -z "$MAXCONN" ]] && MAXCONN=2

if ! [[ "$MAXCONN" =~ ^[0-9]+$ ]] || [[ "$MAXCONN" -lt 1 ]] || [[ "$MAXCONN" -gt 10 ]]; then
    echo
    echo -e "${RED}❌ Conexiones inválidas (1 a 10).${RESET}"
    sleep 2
    continue
fi

echo
echo -e "${YELLOW}📲 HWID del dispositivo (HTTP Custom → Ajustes → HWID / ID del dispositivo)${RESET}"
read -rp "$(echo -e "${GREEN}🔒 HWID               : ${RESET}")" HWID

if [[ -z "$HWID" ]]; then
    echo
    echo -e "${RED}❌ Debe ingresar el HWID del dispositivo.${RESET}"
    sleep 2
    continue
fi

if ! [[ "$HWID" =~ ^[A-Za-z0-9_:.-]+$ ]] || [[ ${#HWID} -lt 4 ]] || [[ ${#HWID} -gt 64 ]]; then
    echo
    echo -e "${RED}❌ HWID inválido (solo letras, números y _ : . - ; de 4 a 64 caracteres).${RESET}"
    sleep 2
    continue
fi

# HWID ya registrado en otra cuenta?
DUPLICADO=$(grep -rl "^HWID: $HWID$" "$HWID_DIR" 2>/dev/null | head -n1)
if [[ -n "$DUPLICADO" ]]; then
    echo
    echo -e "${RED}❌ Ese HWID ya está registrado en: $(basename "$DUPLICADO" .hwid)${RESET}"
    echo -e "${RED}   Un dispositivo solo puede tener UNA cuenta.${RESET}"
    sleep 3
    continue
fi

#==================================================
# CONTRASEÑA DERIVADA + CREAR USUARIO SSH
#==================================================

PASS=$(derive_pass "$HWID")

FECHA=$(date -d "+$DIAS days" +"%Y-%m-%d")

useradd -e "$FECHA" -M -s /usr/sbin/nologin "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al crear el usuario.${RESET}"
    sleep 3
    continue
fi

# Establecer contrasena sin validacion PAM (compatible ARM)
HASH=$(openssl passwd -6 "$PASS" 2>/dev/null)
usermod -p "$HASH" "$USER"

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al establecer la contraseña.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# GUARDAR REGISTRO HWID
#==================================================

cat > "$HWID_DIR/$USER.hwid" <<EOF
# kevintech Network - Usuario por HWID (v2)
USER: $USER
HWID: $HWID
PASS: $PASS
EXPIRE: $FECHA
MAXCONN: $MAXCONN
CREATED: $(date +"%Y-%m-%d %H:%M:%S")
EOF

if [[ $? -ne 0 ]]; then
    echo
    echo -e "${RED}❌ Error al guardar el HWID.${RESET}"
    userdel -f "$USER" &>/dev/null
    sleep 3
    continue
fi

#==================================================
# INFORMACIÓN DEL SERVIDOR
#==================================================

clear

IP=$(curl -4 -s ifconfig.me)

[[ -z "$IP" ]] && IP=$(hostname -I | awk '{print $1}')

HOST="${SERVER_DOMAIN:-$IP}"

FECHA_MOSTRAR=$(date -d "$FECHA" +"%d/%m/%Y")

#==================================================
# MOSTRAR INFORMACIÓN DE LA CUENTA
# (Entrega: Usuario + HWID + Días)
#==================================================

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${MAGENTA}               ⚜️ kevintech Network ⚜️                ${CYAN}║${RESET}"
echo -e "${CYAN}║${WHITE}        CUENTA POR HWID CREADA CON ÉXITO 🎉           ${CYAN}║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

echo -e "${YELLOW}               👤 ENTREGA AL CLIENTE (Usuario + HWID + Días)${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 👤 Usuario      : ${GREEN}%-35s${WHITE}│\n" "$USER"
printf "${WHITE}│ 🔒 HWID         : ${GREEN}%-35s${WHITE}│\n" "$HWID"
printf "${WHITE}│ 📅 Días         : ${GREEN}%-35s${WHITE}│\n" "$DIAS"
printf "${WHITE}│ 🚪 Expira       : ${GREEN}%-35s${WHITE}│\n" "$FECHA_MOSTRAR"
printf "${WHITE}│ 🔑 Conexiones   : ${GREEN}%-35s${WHITE}│\n" "$MAXCONN (anti-share: se bloquea si excede)"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}       🔐 CREDENCIAL GENERADA AUTOMÁTICAMENTE (NO compartir)${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 🔑 Contraseña   : ${MAGENTA}%-35s${WHITE}│\n" "$PASS"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo -e "${GRAY}   La contraseña deriva del HWID. Si el cliente cambia de${RESET}"
echo -e "${GRAY}   dispositivo, usa 'Cambiar HWID' y se regenera sola.${RESET}"
echo

echo -e "${YELLOW}               🌐 INFORMACIÓN DEL SERVIDOR${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
printf "${WHITE}│ 🌍 Dominio      : ${GREEN}%-35s${WHITE}│\n" "${SERVER_DOMAIN:-$IP}"
printf "${WHITE}│ 🖥 Host/IP      : ${GREEN}%-35s${WHITE}│\n" "$IP"
echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}                 🚪 PUERTOS DISPONIBLES${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"

[[ "$OPENSSH" == "ON" ]]  && printf "${WHITE}│ ✓ SSH           : ${GREEN}22%-37s${WHITE}│\n" ""
[[ "$WEBSOCKET" == "ON" ]] && printf "${WHITE}│ ✓ WebSocket     : ${GREEN}80%-37s${WHITE}│\n" ""
[[ "$DROPBEAR" == "ON" ]] && printf "${WHITE}│ ✓ Dropbear      : ${GREEN}90%-37s${WHITE}│\n" ""
[[ "$SSL" == "ON" ]]      && printf "${WHITE}│ ✓ SSL/TLS       : ${GREEN}443%-36s${WHITE}│\n" ""
[[ "$SLOWDNS" == "ON" ]]  && printf "${WHITE}│ ✓ SlowDNS       : ${GREEN}5300%-35s${WHITE}│\n" ""

echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}                 📲 CONEXIONES DISPONIBLES${RESET}"
echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${RESET}"
# HTTP Direct
if [[ "$WEBSOCKET" == "ON" ]]; then
    printf "${WHITE}│ 🌐 HTTP Direct                                        │\n"
    printf "${GREEN}│ %-58s${WHITE}│\n" "$IP:80@$USER:$PASS"
    printf "${WHITE}├────────────────────────────────────────────────────────────┤\n"
fi

# SSL/TLS (SNI)
if [[ "$SSL" == "ON" ]]; then
    printf "${WHITE}│ 🔒 SSL/TLS (SNI)                                      │\n"
    printf "${GREEN}│ %-58s${WHITE}│\n" "${SERVER_DOMAIN}:443@$USER:$PASS"
    printf "${WHITE}├────────────────────────────────────────────────────────────┤\n"
fi

# SSH UDP
printf "${WHITE}│ 🚀 SSH UDP                                            │\n"
printf "${GREEN}│ %-58s${WHITE}│\n" "$IP:1-65535@$USER:$PASS"

echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${RESET}"
echo

echo -e "${YELLOW}        💡 Este usuario queda ATADO al HWID del dispositivo.${RESET}"
echo -e "${YELLOW}        🛡 Anti-share: más de $MAXCONN conexiones simultáneas = BLOQUEO automático.${RESET}"
echo -e "${YELLOW}        📁 Registro: ${GRAY}$HWID_DIR/$USER.hwid${RESET}"
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║             ✅ USUARIO POR HWID CREADO EXITOSAMENTE         ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo

read -rp "$(echo -e "${YELLOW}¿Desea crear otro usuario por HWID? [S/N]: ${RESET}")" RESP

case "$RESP" in
    s|S|si|SI|sí|Sí|y|Y)
        continue
        ;;
    *)
        break
        ;;
esac

done
