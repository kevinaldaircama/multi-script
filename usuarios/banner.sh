#!/bin/bash
# ============================================================
# KEVINTECH BANNER MANAGER v6.0
# ============================================================
# 🌐 Banner Global
# 👤 Banner Individual
# ⚡ Auto banner para nuevos usuarios
#
# Usuarios:
#   /etc/kevintech/limits.conf
#
# Config:
#   /etc/kevintech/config.conf
#
# Banners:
#   /etc/ssh_banners/
#
# Global:
#   /etc/ssh_banners/global.html
#   /etc/ssh_banners/global.txt
#
# Individual:
#   /etc/ssh_banners/USUARIO.html
#   /etc/ssh_banners/USUARIO.txt
#
# Estado:
#   /etc/kevintech/banner-state.conf
#
# NO utiliza:
#   /etc/issue.net
# ============================================================

set -u

# ============================================================
# RUTAS
# ============================================================

BASE="/etc/kevintech"

LIMITS_FILE="$BASE/limits.conf"
CONFIG="$BASE/config.conf"

BANNER_DIR="/etc/ssh_banners"
SSHD_CONFIG="/etc/ssh/sshd_config"

BACKUP_DIR="$BASE/banner-backups"
STATE_FILE="$BASE/banner-state.conf"

GLOBAL_HTML="$BANNER_DIR/global.html"
GLOBAL_TXT="$BANNER_DIR/global.txt"

START_MARK="# >>> KEVINTECH_BANNER_START <<<"
END_MARK="# >>> KEVINTECH_BANNER_END <<<"

# ============================================================
# COLORES
# ============================================================

BLACK="\e[30m"
RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

BOLD="\e[1m"

# ============================================================
# ROOT
# ============================================================

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"

    exit 1

fi

# ============================================================
# DIRECTORIOS
# ============================================================

mkdir -p "$BANNER_DIR"
mkdir -p "$BACKUP_DIR"

chmod 700 "$BANNER_DIR"
chmod 700 "$BACKUP_DIR"

# ============================================================
# CONFIG PRINCIPAL
# ============================================================

load_config() {

    if [[ -f "$CONFIG" ]]; then

        set +u

        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null || true

        set -u

    fi

}

load_config

# ============================================================
# PAUSA
# ============================================================

pause() {

    echo

    read -rp "Presiona ENTER para continuar..."

}

# ============================================================
# CABECERA
# ============================================================

header() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}           KEVINTECH BANNER MANAGER                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${MAGENTA}                     v6.0                            ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║ ${WHITE}🌐 Global    : ${GRAY}HTML + SSH${CYAN}                         ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}👤 Individual: ${GRAY}limits.conf${CYAN}                       ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}⚡ Automático: ${GRAY}add --auto-user${CYAN}                   ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

    echo

}

# ============================================================
# USUARIOS
# ============================================================

get_users() {

    [[ -f "$LIMITS_FILE" ]] || return 0

    awk -F: '
        NF >= 1 &&
        $1 != "" &&
        $1 !~ /^[[:space:]]*#/ &&
        $1 ~ /^[a-zA-Z0-9._-]+$/ {
            print $1
        }
    ' "$LIMITS_FILE" |
    sort -u

}

count_users() {

    get_users |
    wc -l |
    tr -d ' '

}

user_exists() {

    local user="$1"

    [[ -f "$LIMITS_FILE" ]] || return 1

    awk -F: -v u="$user" '
        $1 == u {
            found=1
            exit
        }

        END {
            exit !found
        }
    ' "$LIMITS_FILE"

}

# ============================================================
# DATOS USUARIO
# ============================================================

get_limit() {

    local user="$1"
    local limit

    limit="$(
        awk -F: -v u="$user" '
            $1 == u {
                print $2
                exit
            }
        ' "$LIMITS_FILE" 2>/dev/null || true
    )"

    [[ -n "$limit" ]] &&
        echo "$limit" ||
        echo "1"

}

get_expire() {

    local user="$1"
    local expire=""

    if id "$user" >/dev/null 2>&1; then

        expire="$(
            chage -l "$user" 2>/dev/null |
            awk -F: '
                /Account expires/ {
                    gsub(/^[ \t]+/, "", $2)
                    print $2
                    exit
                }
            ' || true
        )"

    fi

    [[ -n "$expire" ]] &&
        echo "$expire" ||
        echo "Nunca"

}

get_days() {

    local user="$1"
    local expire
    local timestamp
    local now
    local days

    expire="$(get_expire "$user")"

    case "$expire" in

        Nunca|never|Never)
            echo "Ilimitado"
            return
            ;;

    esac

    timestamp="$(
        date -d "$expire 23:59:59" +%s 2>/dev/null || true
    )"

    if [[ -z "$timestamp" ]]; then

        echo "Desconocido"

        return

    fi

    now="$(date +%s)"

    days=$(( (timestamp - now) / 86400 ))

    if (( days < 0 )); then

        echo "EXPIRADO"

    else

        echo "$days"

    fi

}

# ============================================================
# CONEXIONES
# ============================================================

get_connected() {

    local user="$1"

    local total
    local ips

    total="$(
        who 2>/dev/null |
        awk -v u="$user" '
            $1 == u {
                n++
            }

            END {
                print n+0
            }
        '
    )"

    ips="$(
        who 2>/dev/null |
        awk -v u="$user" '
            $1 == u && $5 ~ /^\(/ {
                gsub(/[()]/, "", $5)
                print $5
            }
        ' |
        sort -u |
        paste -sd, -
    )"

    [[ -z "$ips" ]] &&
        ips="Sin conexión"

    echo "$total|$ips"

}

# ============================================================
# ESCAPAR HTML
# ============================================================

html_escape() {

    local value="${1:-}"

    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    value="${value//\"/&quot;}"
    value="${value//\'/&#39;}"

    printf '%s' "$value"

}

# ============================================================
# ARCHIVOS
# ============================================================

individual_html() {

    echo "$BANNER_DIR/$1.html"

}

individual_txt() {

    echo "$BANNER_DIR/$1.txt"

}

# ============================================================
# ESTADO
# ============================================================

get_state_value() {

    local key="$1"

    [[ -f "$STATE_FILE" ]] || return 0

    grep "^${key}=" "$STATE_FILE" 2>/dev/null |
        head -1 |
        cut -d= -f2-

}

get_saved_announcement() {

    get_state_value "BANNER_ANNOUNCEMENT"

}

get_saved_geo() {

    get_state_value "BANNER_GEO"

}

get_saved_support() {

    get_state_value "BANNER_SUPPORT"

}

get_saved_bot() {

    get_state_value "BANNER_BOT"

}

save_state() {

    local announcement="$1"
    local geo="$2"
    local support="$3"
    local bot="$4"

    cat > "$STATE_FILE" <<EOF
BANNER_ANNOUNCEMENT=$announcement
BANNER_GEO=$geo
BANNER_SUPPORT=$support
BANNER_BOT=$bot
EOF

    chmod 600 "$STATE_FILE"

}

# ============================================================
# CREAR BANNER INDIVIDUAL HTML
# ============================================================

generate_individual_html() {

    local user="$1"
    local announcement="$2"
    local geo="$3"
    local support="$4"
    local bot="$5"

    local expire
    local days
    local limit
    local connected
    local total
    local ips

    expire="$(get_expire "$user")"
    days="$(get_days "$user")"
    limit="$(get_limit "$user")"

    connected="$(get_connected "$user")"

    total="${connected%%|*}"
    ips="${connected#*|}"

    user="$(html_escape "$user")"
    announcement="$(html_escape "$announcement")"
    geo="$(html_escape "$geo")"
    support="$(html_escape "$support")"
    bot="$(html_escape "$bot")"

    expire="$(html_escape "$expire")"
    days="$(html_escape "$days")"
    limit="$(html_escape "$limit")"
    ips="$(html_escape "$ips")"

    cat <<EOF
<!-- KEVINTECH INDIVIDUAL BANNER -->

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<meta name="viewport" content="width=device-width,initial-scale=1.0">

<title>KevinTech SSH</title>

<style>

body{
    margin:0;
    padding:20px;
    background:#050505;
    color:#ffffff;
    font-family:Arial,sans-serif;
    text-align:center;
}

.box{
    max-width:700px;
    margin:auto;
    padding:25px;
    border-radius:20px;
    background:linear-gradient(145deg,#090909,#151515);
    border:2px solid #00eaff;
    box-shadow:
        0 0 15px #00eaff,
        0 0 35px #7a00ff;
}

.title{
    font-size:30px;
    font-weight:bold;
    color:#00eaff;
    text-shadow:
        0 0 10px #00eaff,
        0 0 20px #7a00ff;
}

.subtitle{
    color:#ff00ff;
    font-size:18px;
    font-weight:bold;
}

.info{
    margin-top:20px;
    padding:15px;
    border-radius:15px;
    background:#090909;
    border:1px solid #7a00ff;
}

.row{
    padding:7px;
    font-size:16px;
}

.label{
    color:#00eaff;
    font-weight:bold;
}

.value{
    color:#ffffff;
}

.promo{
    margin-top:20px;
    padding:15px;
    border-radius:15px;
    background:linear-gradient(90deg,#001f29,#18002b);
    border:1px solid #00ff88;
}

.footer{
    margin-top:20px;
    color:#888;
    font-size:13px;
}

</style>

</head>

<body>

<div class="box">

<div class="title">
🚀 KEVINTECH SSH
</div>

<div class="subtitle">
✦ CUENTA AUTORIZADA ✦
</div>

<div class="info">

<div class="row">
<span class="label">👤 Usuario:</span>
<span class="value">$user</span>
</div>

<div class="row">
<span class="label">📅 Expiración:</span>
<span class="value">$expire</span>
</div>

<div class="row">
<span class="label">⏳ Días restantes:</span>
<span class="value">$days</span>
</div>

<div class="row">
<span class="label">👥 Límite IP:</span>
<span class="value">$limit</span>
</div>

<div class="row">
<span class="label">🔌 Conectados:</span>
<span class="value">$total</span>
</div>

<div class="row">
<span class="label">🌐 IP:</span>
<span class="value">$ips</span>
</div>

</div>

EOF

    if [[ -n "$announcement" ]]; then

        cat <<EOF

<div class="promo">

<div class="subtitle">
📢 ANUNCIO
</div>

<br>

$announcement

</div>

EOF

    fi

    if [[ -n "$geo" ]]; then

        cat <<EOF

<div class="promo">

<div class="subtitle">
📍 UBICACIÓN
</div>

<br>

$geo

</div>

EOF

    fi

    if [[ -n "$support" ]]; then

        cat <<EOF

<div class="promo">

<div class="subtitle">
🛠️ SOPORTE
</div>

<br>

$support

</div>

EOF

    fi

    if [[ -n "$bot" ]]; then

        cat <<EOF

<div class="promo">

<div class="subtitle">
🤖 BOT / CANAL
</div>

<br>

$bot

</div>

EOF

    fi

    cat <<'EOF'

<div class="footer">

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<br>

KEVINTECH MULTI SCRIPT

<br>

Sistema administrado por KevinTech

</div>

</div>

</body>

</html>

EOF

}

# ============================================================
# BANNER INDIVIDUAL ANSI
# ============================================================

generate_individual_txt() {

    local user="$1"
    local announcement="$2"
    local geo="$3"
    local support="$4"
    local bot="$5"

    local expire
    local days
    local limit
    local connected
    local total
    local ips

    expire="$(get_expire "$user")"
    days="$(get_days "$user")"
    limit="$(get_limit "$user")"

    connected="$(get_connected "$user")"

    total="${connected%%|*}"
    ips="${connected#*|}"

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}              🚀 KEVINTECH SSH              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${MAGENTA}             ✦ PREMIUM ACCESS ✦             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    echo -e "${CYAN}║ ${WHITE}👤 Usuario       : ${GREEN}$user${CYAN}                  ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}📅 Expiración    : ${YELLOW}$expire${CYAN}                 ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}⏳ Días restantes: ${YELLOW}$days${CYAN}                   ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}👥 Límite IP     : ${YELLOW}$limit${CYAN}                   ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}🔌 Conectados    : ${GREEN}$total${CYAN}                   ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}🌐 IP            : ${GRAY}$ips${CYAN}                     ║${RESET}"

    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    if [[ -n "$announcement" ]]; then
        echo -e "${CYAN}║ ${MAGENTA}📢 ANUNCIO${RESET}${CYAN}                                  ║${RESET}"
        echo -e "${CYAN}║ ${WHITE}$announcement${CYAN}                              ║${RESET}"
    fi

    if [[ -n "$geo" ]]; then
        echo -e "${CYAN}║ ${BLUE}📍 UBICACIÓN:${RESET}${CYAN} $geo                         ║${RESET}"
    fi

    if [[ -n "$support" ]]; then
        echo -e "${CYAN}║ ${GREEN}🛠️ SOPORTE:${RESET}${CYAN} $support                       ║${RESET}"
    fi

    if [[ -n "$bot" ]]; then
        echo -e "${CYAN}║ ${MAGENTA}🤖 BOT/CANAL:${RESET}${CYAN} $bot                       ║${RESET}"
    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE}       KEVINTECH MULTI SCRIPT                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

}

# ============================================================
# CREAR BANNER INDIVIDUAL
# ============================================================

create_user_banner() {

    local user="$1"
    local announcement="$2"
    local geo="$3"
    local support="$4"
    local bot="$5"

    local html
    local txt

    html="$(individual_html "$user")"
    txt="$(individual_txt "$user")"

    generate_individual_html \
        "$user" \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot" > "$html"

    generate_individual_txt \
        "$user" \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot" > "$txt"

    chmod 644 "$html" "$txt"
    chown root:root "$html" "$txt"

}

# ============================================================
# CREAR TODOS
# ============================================================

create_all_banners() {

    local announcement="$1"
    local geo="$2"
    local support="$3"
    local bot="$4"

    local user
    local count=0

    while IFS= read -r user; do

        [[ -z "$user" ]] && continue

        create_user_banner \
            "$user" \
            "$announcement" \
            "$geo" \
            "$support" \
            "$bot"

        echo -e "${GREEN}✔${RESET} Banner creado: ${WHITE}$user${RESET}"

        count=$((count + 1))

    done < <(get_users)

    echo
    echo -e "${GREEN}✔ Total: $count banners creados.${RESET}"

}

# ============================================================
# BACKUP SSH
# ============================================================

backup_sshd() {

    [[ -f "$SSHD_CONFIG" ]] || return 0

    cp -a "$SSHD_CONFIG" \
        "$BACKUP_DIR/sshd_config.$(date +%Y%m%d-%H%M%S)"

}

# ============================================================
# ELIMINAR BLOQUE KEVINTECH
# ============================================================

remove_kevintech_blocks() {

    [[ -f "$SSHD_CONFIG" ]] || return 0

    awk \
        -v start="$START_MARK" \
        -v end="$END_MARK" '

        $0 == start {
            inside=1
            next
        }

        $0 == end {
            inside=0
            next
        }

        !inside {
            print
        }

    ' "$SSHD_CONFIG" > "$SSHD_CONFIG.tmp"

    mv "$SSHD_CONFIG.tmp" "$SSHD_CONFIG"

}

# ============================================================
# SINCRONIZAR SSH
# ============================================================

sync_sshd() {

    local user
    local file

    [[ -f "$SSHD_CONFIG" ]] || {
        echo -e "${RED}✘ No existe $SSHD_CONFIG${RESET}"
        return 1
    }

    backup_sshd

    remove_kevintech_blocks

    {

        echo
        echo "$START_MARK"

        while IFS= read -r user; do

            [[ -z "$user" ]] && continue

            file="$(individual_txt "$user")"

            [[ -f "$file" ]] || continue

            echo "Match User $user"
            echo "    Banner $file"
            echo

        done < <(get_users)

        # ----------------------------------------------------
        # BANNER GLOBAL
        # ----------------------------------------------------

        if [[ -f "$GLOBAL_TXT" ]]; then

            echo "Match All"
            echo "    Banner $GLOBAL_TXT"
            echo

        fi

        echo "$END_MARK"

    } >> "$SSHD_CONFIG"

    if command -v sshd >/dev/null 2>&1; then

        if ! sshd -t 2>/tmp/kevintech_sshd_error; then

            echo
            echo -e "${RED}✘ Error en sshd_config${RESET}"

            cat /tmp/kevintech_sshd_error

            return 1

        fi

    fi

    systemctl reload ssh 2>/dev/null ||
    systemctl reload sshd 2>/dev/null ||
    true

    echo -e "${GREEN}✔ SSH sincronizado correctamente.${RESET}"

}

# ============================================================
# BANNER GLOBAL HTML
# ============================================================

create_global_html() {

    local announcement="$1"
    local geo="$2"
    local support="$3"
    local bot="$4"

    announcement="$(html_escape "$announcement")"
    geo="$(html_escape "$geo")"
    support="$(html_escape "$support")"
    bot="$(html_escape "$bot")"

    cat > "$GLOBAL_HTML" <<EOF
<!-- KEVINTECH GLOBAL BANNER -->

<!DOCTYPE html>

<html lang="es">

<head>

<meta charset="UTF-8">

<meta name="viewport" content="width=device-width,initial-scale=1.0">

<title>KevinTech Global Banner</title>

<style>

body{
    margin:0;
    padding:25px;
    background:#030303;
    color:#ffffff;
    font-family:Arial,sans-serif;
    text-align:center;
}

.global{
    max-width:800px;
    margin:auto;
    padding:35px;
    border-radius:25px;
    background:
        linear-gradient(145deg,#050505,#17002a,#001d27);
    border:2px solid #00eaff;
    box-shadow:
        0 0 15px #00eaff,
        0 0 30px #ff00ff,
        0 0 60px #7a00ff;
}

h1{
    color:#00eaff;
    font-size:38px;
    text-shadow:
        0 0 10px #00eaff,
        0 0 25px #7a00ff;
}

h2{
    color:#ff00ff;
}

.card{
    margin:18px 0;
    padding:20px;
    border-radius:18px;
    background:rgba(0,0,0,.55);
    border:1px solid #00ff88;
}

.label{
    color:#00eaff;
    font-weight:bold;
}

.footer{
    margin-top:25px;
    color:#888;
}

</style>

</head>

<body>

<div class="global">

<h1>🚀 KEVINTECH</h1>

<h2>🔥 MULTI SCRIPT SSH 🔥</h2>

EOF

    if [[ -n "$announcement" ]]; then

        cat >> "$GLOBAL_HTML" <<EOF

<div class="card">

<div class="label">
📢 ANUNCIO
</div>

<br>

$announcement

</div>

EOF

    fi

    if [[ -n "$geo" ]]; then

        cat >> "$GLOBAL_HTML" <<EOF

<div class="card">

<div class="label">
📍 GEOLOCALIZACIÓN
</div>

<br>

$geo

</div>

EOF

    fi

    if [[ -n "$support" ]]; then

        cat >> "$GLOBAL_HTML" <<EOF

<div class="card">

<div class="label">
🛠️ SOPORTE
</div>

<br>

$support

</div>

EOF

    fi

    if [[ -n "$bot" ]]; then

        cat >> "$GLOBAL_HTML" <<EOF

<div class="card">

<div class="label">
🤖 BOT / CANAL
</div>

<br>

$bot

</div>

EOF

    fi

    cat >> "$GLOBAL_HTML" <<'EOF'

<div class="footer">

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

<br>

KEVINTECH MULTI SCRIPT

<br>

Sistema administrado por KevinTech

</div>

</div>

</body>

</html>

EOF

    chmod 644 "$GLOBAL_HTML"
    chown root:root "$GLOBAL_HTML"

}

# ============================================================
# GLOBAL ANSI
# ============================================================

create_global_txt() {

    local announcement="$1"
    local geo="$2"
    local support="$3"
    local bot="$4"

    {

        echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${WHITE}              🚀 KEVINTECH                  ${CYAN}║${RESET}"
        echo -e "${CYAN}║${MAGENTA}          🔥 MULTI SCRIPT SSH 🔥            ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

        if [[ -n "$announcement" ]]; then
            echo -e "${CYAN}║ ${MAGENTA}📢 ANUNCIO${RESET}${CYAN}                                  ║${RESET}"
            echo -e "${CYAN}║ ${WHITE}$announcement${CYAN}                              ║${RESET}"
        fi

        if [[ -n "$geo" ]]; then
            echo -e "${CYAN}║ ${BLUE}📍 GEO:${RESET}${CYAN} $geo                              ║${RESET}"
        fi

        if [[ -n "$support" ]]; then
            echo -e "${CYAN}║ ${GREEN}🛠️ SOPORTE:${RESET}${CYAN} $support                       ║${RESET}"
        fi

        if [[ -n "$bot" ]]; then
            echo -e "${CYAN}║ ${MAGENTA}🤖 BOT/CANAL:${RESET}${CYAN} $bot                       ║${RESET}"
        fi

        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${CYAN}║${WHITE}       KEVINTECH MULTI SCRIPT                 ${CYAN}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    } > "$GLOBAL_TXT"

    chmod 644 "$GLOBAL_TXT"
    chown root:root "$GLOBAL_TXT"

}

# ============================================================
# CREAR / EDITAR GLOBAL
# ============================================================

global_create_edit() {

    header

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}            🌐 BANNER GLOBAL                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${GRAY}Este banner se mostrará para las conexiones SSH.${RESET}"
    echo

    local announcement
    local geo
    local support
    local bot

    read -rp "📢 Anuncio: " announcement
    read -rp "📍 Geolocalización: " geo
    read -rp "🛠️ Soporte: " support
    read -rp "🤖 Bot / Canal: " bot

    create_global_html \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot"

    create_global_txt \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot"

    save_state \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot"

    sync_sshd

    echo
    echo -e "${GREEN}✔ Banner global creado/actualizado.${RESET}"
    echo -e "${GRAY}HTML: $GLOBAL_HTML${RESET}"
    echo -e "${GRAY}SSH : $GLOBAL_TXT${RESET}"

    pause

}

# ============================================================
# ELIMINAR GLOBAL
# ============================================================

global_delete() {

    header

    echo -e "${RED}⚠ ELIMINAR BANNER GLOBAL${RESET}"

    echo
    echo "Esto eliminará únicamente el banner global."
    echo

    local confirm

    read -rp "¿Continuar? [s/N]: " confirm

    if [[ "$confirm" =~ ^[sS]$ ]]; then

        rm -f "$GLOBAL_HTML"
        rm -f "$GLOBAL_TXT"

        sync_sshd

        echo
        echo -e "${GREEN}✔ Banner global eliminado.${RESET}"

    else

        echo -e "${YELLOW}Cancelado.${RESET}"

    fi

    pause

}

# ============================================================
# MENÚ GLOBAL
# ============================================================

submenu_global() {

    while true; do

        header

        echo -e "${CYAN}╭──────────────────────────────────────────────╮${RESET}"
        echo -e "${CYAN}│${WHITE}              🌐 BANNER GLOBAL               ${CYAN}│${RESET}"
        echo -e "${CYAN}├──────────────────────────────────────────────┤${RESET}"
        echo -e "${CYAN}│ ${GREEN}[1]${WHITE} Crear / Editar HTML                     ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${BLUE}[2]${WHITE} Ver HTML                                ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${RED}[3]${WHITE} Eliminar banner                         ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${RED}[0]${WHITE} Volver                                   ${CYAN}│${RESET}"
        echo -e "${CYAN}╰──────────────────────────────────────────────╯${RESET}"

        echo

        local option

        read -rp "❯ Opción: " option

        case "$option" in

            1)

                global_create_edit

                ;;

            2)

                header

                if [[ -f "$GLOBAL_HTML" ]]; then

                    echo -e "${GREEN}✔ Banner global encontrado:${RESET}"
                    echo
                    sed 's/<[^>]*>//g' "$GLOBAL_HTML"

                else

                    echo -e "${YELLOW}⚠ No existe banner global.${RESET}"

                fi

                pause

                ;;

            3)

                global_delete

                ;;

            0)

                return

                ;;

            *)

                echo -e "${RED}✘ Opción inválida.${RESET}"

                sleep 1

                ;;

        esac

    done

}

# ============================================================
# CONFIGURAR BANNER INDIVIDUAL
# ============================================================

individual_config() {

    header

    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}           👤 BANNER INDIVIDUAL              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${GRAY}Solo necesitas configurar la información comercial.${RESET}"
    echo -e "${GRAY}El resto del banner se genera automáticamente.${RESET}"

    echo

    local announcement
    local geo
    local support
    local bot

    read -rp "📢 Anuncio: " announcement
    read -rp "📍 Geolocalización: " geo
    read -rp "🛠️ Soporte: " support
    read -rp "🤖 Bot / Canal: " bot

    save_state \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot"

    create_all_banners \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot"

    sync_sshd

    echo
    echo -e "${GREEN}✔ Banner individual configurado correctamente.${RESET}"
    echo -e "${GRAY}Los nuevos usuarios recibirán este banner automáticamente.${RESET}"

    pause

}

# ============================================================
# VER BANNERS
# ============================================================

view_banners() {

    while true; do

        header

        echo -e "${CYAN}╭──────────────────────────────────────────────╮${RESET}"
        echo -e "${CYAN}│${WHITE}                👁️ VER BANNERS               ${CYAN}│${RESET}"
        echo -e "${CYAN}├──────────────────────────────────────────────┤${RESET}"
        echo -e "${CYAN}│ ${GREEN}[1]${WHITE} Banner global                           ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[2]${WHITE} Banners individuales                    ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${RED}[0]${WHITE} Volver                                   ${CYAN}│${RESET}"
        echo -e "${CYAN}╰──────────────────────────────────────────────╯${RESET}"

        echo

        local option
        local user
        local file

        read -rp "❯ Opción: " option

        case "$option" in

            1)

                header

                if [[ -f "$GLOBAL_HTML" ]]; then

                    echo -e "${GREEN}✔ BANNER GLOBAL${RESET}"
                    echo

                    cat "$GLOBAL_HTML"

                else

                    echo -e "${YELLOW}⚠ No existe banner global.${RESET}"

                fi

                pause

                ;;

            2)

                header

                echo -e "${CYAN}Usuarios detectados: ${GREEN}$(count_users)${RESET}"

                echo

                while IFS= read -r user; do

                    [[ -z "$user" ]] && continue

                    file="$(individual_txt "$user")"

                    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                    echo -e "${WHITE}👤 $user${RESET}"
                    echo

                    if [[ -f "$file" ]]; then

                        cat "$file"

                    else

                        echo -e "${YELLOW}⚠ Sin banner.${RESET}"

                    fi

                    echo

                done < <(get_users)

                pause

                ;;

            0)

                return

                ;;

            *)

                echo -e "${RED}✘ Opción inválida.${RESET}"

                sleep 1

                ;;

        esac

    done

}

# ============================================================
# ELIMINAR BANNERS INDIVIDUALES
# ============================================================

delete_individual_banners() {

    header

    echo -e "${RED}⚠ ELIMINAR BANNERS INDIVIDUALES${RESET}"

    echo

    read -rp \
        "¿Eliminar todos los banners individuales? [s/N]: " \
        confirm

    if [[ "$confirm" =~ ^[sS]$ ]]; then

        while IFS= read -r user; do

            [[ -z "$user" ]] && continue

            rm -f "$(individual_html "$user")"
            rm -f "$(individual_txt "$user")"

        done < <(get_users)

        rm -f "$STATE_FILE"

        sync_sshd

        echo
        echo -e "${GREEN}✔ Banners individuales eliminados.${RESET}"

    else

        echo -e "${YELLOW}Cancelado.${RESET}"

    fi

    pause

}

# ============================================================
# AUTO USER
# ============================================================
# Uso:
#
# banner.sh --auto-user USUARIO
#
# El ADD debe ejecutar esto después de crear
# el usuario y agregarlo a limits.conf.
# ============================================================

auto_user() {

    local new_user="$1"

    [[ -n "$new_user" ]] || exit 1

    # --------------------------------------------------------
    # Verificar usuario en limits.conf
    # --------------------------------------------------------

    if ! user_exists "$new_user"; then
        exit 1
    fi

    # --------------------------------------------------------
    # Leer configuración
    # --------------------------------------------------------

    local announcement
    local geo
    local support
    local bot

    announcement="$(get_saved_announcement)"
    geo="$(get_saved_geo)"
    support="$(get_saved_support)"
    bot="$(get_saved_bot)"

    # --------------------------------------------------------
    # Si nunca se configuró banner individual
    # --------------------------------------------------------

    if [[ -z "$announcement" &&
          -z "$geo" &&
          -z "$support" &&
          -z "$bot" ]]; then

        exit 0

    fi

    # --------------------------------------------------------
    # Crear banner
    # --------------------------------------------------------

    create_user_banner \
        "$new_user" \
        "$announcement" \
        "$geo" \
        "$support" \
        "$bot"

    # --------------------------------------------------------
    # Actualizar SSH
    # --------------------------------------------------------

    sync_sshd >/dev/null 2>&1 || true

    exit 0

}

# ============================================================
# DETECTAR NUEVAS CUENTAS
# ============================================================

auto_sync_new_users() {

    local announcement
    local geo
    local support
    local bot

    announcement="$(get_saved_announcement)"
    geo="$(get_saved_geo)"
    support="$(get_saved_support)"
    bot="$(get_saved_bot)"

    if [[ -z "$announcement" &&
          -z "$geo" &&
          -z "$support" &&
          -z "$bot" ]]; then

        return

    fi

    local user
    local file

    while IFS= read -r user; do

        [[ -z "$user" ]] && continue

        file="$(individual_txt "$user")"

        if [[ ! -f "$file" ]]; then

            create_user_banner \
                "$user" \
                "$announcement" \
                "$geo" \
                "$support" \
                "$bot"

        fi

    done < <(get_users)

}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================

main_menu() {

    while true; do

        header

        echo -e "${BLUE}╭──────────────────────────────────────────────╮${RESET}"
        echo -e "${BLUE}│${WHITE}                MENÚ PRINCIPAL                ${BLUE}│${RESET}"
        echo -e "${BLUE}├──────────────────────────────────────────────┤${RESET}"

        echo -e "${BLUE}│ ${GREEN}[1]${WHITE} 🌐 BANNER GLOBAL                         ${BLUE}│${RESET}"
        echo -e "${BLUE}│ ${GRAY}    Crear / Editar / Eliminar HTML          ${BLUE}│${RESET}"

        echo -e "${BLUE}│ ${MAGENTA}[2]${WHITE} 👤 BANNER INDIVIDUAL                     ${BLUE}│${RESET}"
        echo -e "${BLUE}│ ${GRAY}    Anuncio / Geo / Soporte / Bot           ${BLUE}│${RESET}"

        echo -e "${BLUE}│ ${CYAN}[3]${WHITE} 👁️ VER BANNERS                           ${BLUE}│${RESET}"

        echo -e "${BLUE}│ ${RED}[0]${WHITE} ❌ SALIR                                  ${BLUE}│${RESET}"

        echo -e "${BLUE}╰──────────────────────────────────────────────╯${RESET}"

        echo

        echo -e "${GRAY}Cuentas detectadas: ${GREEN}$(count_users)${RESET}"

        echo

        local option

        read -rp "  ❯ Selecciona una opción: " option

        case "$option" in

            1)

                submenu_global

                ;;

            2)

                individual_config

                ;;

            3)

                view_banners

                ;;

            0)

                clear

                echo -e "${GREEN}✔ KevinTech Banner Manager cerrado.${RESET}"

                exit 0

                ;;

            *)

                echo -e "${RED}✘ Opción inválida.${RESET}"

                sleep 1

                ;;

        esac

    done

}

# ============================================================
# AUTO USER
# ============================================================

if [[ "${1:-}" == "--auto-user" ]]; then

    auto_user "${2:-}"

fi

# ============================================================
# DETECTAR CUENTAS NUEVAS AL ABRIR
# ============================================================

auto_sync_new_users

# ============================================================
# INICIAR
# ============================================================

main_menu