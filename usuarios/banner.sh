#!/bin/bash
# ============================================================
# KEVINTECH PER-USER BANNER MANAGER v5.0
# ============================================================
# Usuarios: /etc/kevintech/limits.conf
# Banners : /etc/ssh_banners
#
# - Menú principal: 4 opciones
# - Submenús
# - Usuarios automáticos desde limits.conf
# - Detecta cuentas nuevas
# - Sin dominio / servidor
# - Banner individual por usuario
# - No utiliza /etc/issue.net como banner global
# ============================================================

set -u

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"
CONFIG="$BASE/config.conf"

BANNER_DIR="/etc/ssh_banners"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="$BASE/banner-backups"

START_MARK="# >>> KEVINTECH_PER_USER_BANNERS_START <<<"
END_MARK="# >>> KEVINTECH_PER_USER_BANNERS_END <<<"

STATE_FILE="$BASE/banner-state.conf"

# ============================================================
# COLORES
# ============================================================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

# ============================================================
# ROOT
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Ejecuta este script como root.${RESET}"
    exit 1
fi

mkdir -p "$BANNER_DIR"
mkdir -p "$BACKUP_DIR"

chmod 700 "$BANNER_DIR"

# ============================================================
# CONFIG
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
    echo -e "${CYAN}║${WHITE}              KEVINTECH BANNER MANAGER              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${GRAY}                       v5.0                         ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║ ${WHITE}Usuarios automáticos : ${GRAY}limits.conf${CYAN}              ║${RESET}"
    echo -e "${CYAN}║ ${WHITE}Banner individual    : ${GRAY}ssh_banners${CYAN}               ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

    echo

}

# ============================================================
# OBTENER USUARIOS DEL PRIMER CÓDIGO
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
    ' "$LIMITS_FILE" | sort -u

}

# ============================================================
# CONTAR USUARIOS
# ============================================================

count_users() {

    get_users | wc -l | tr -d ' '

}

# ============================================================
# COMPROBAR USUARIO
# ============================================================

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
# LIMITE IP
# ============================================================

get_limit() {

    local user="$1"
    local limit

    limit="$(awk -F: -v u="$user" '
        $1 == u {
            print $2
            exit
        }
    ' "$LIMITS_FILE" 2>/dev/null || true)"

    [[ -n "$limit" ]] && echo "$limit" || echo "1"

}

# ============================================================
# EXPIRACIÓN
# ============================================================

get_expire() {

    local user="$1"
    local expire=""

    if id "$user" >/dev/null 2>&1; then

        expire="$(chage -l "$user" 2>/dev/null |
            awk -F: '
                /Account expires/ {
                    gsub(/^[ \t]+/, "", $2)
                    print $2
                    exit
                }
            ' || true)"

    fi

    [[ -n "$expire" ]] && echo "$expire" || echo "Nunca"

}

# ============================================================
# DÍAS RESTANTES
# ============================================================

get_days() {

    local user="$1"
    local expire timestamp now days

    expire="$(get_expire "$user")"

    case "$expire" in

        Nunca|never|Never)
            echo "Ilimitado"
            return
            ;;

    esac

    timestamp="$(date -d "$expire 23:59:59" +%s 2>/dev/null || true)"

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

    total="$(who 2>/dev/null |
        awk -v u="$user" '
            $1 == u {
                n++
            }

            END {
                print n+0
            }
        ')"

    ips="$(who 2>/dev/null |
        awk -v u="$user" '
            $1 == u && $5 ~ /^\(/ {
                gsub(/[()]/, "", $5)
                print $5
            }
        ' |
        sort -u |
        paste -sd, -)"

    [[ -z "$ips" ]] && ips="Sin conexión"

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
# ARCHIVO DEL BANNER
# ============================================================

banner_file() {

    echo "$BANNER_DIR/$1.banner"

}

# ============================================================
# TIPO DE BANNER
# ============================================================

banner_type() {

    local user="$1"
    local file

    file="$(banner_file "$user")"

    [[ -f "$file" ]] || {
        echo "Sin banner"
        return
    }

    if grep -q 'data-kevintech-type="custom"' "$file" 2>/dev/null; then

        echo "Personalizado"
        return

    fi

    if grep -q 'data-kevintech-type="template"' "$file" 2>/dev/null; then

        sed -n \
            's/.*data-kevintech-template="\([^"]*\)".*/\1/p' \
            "$file" |
            head -1

        return

    fi

    echo "Configurado"

}

# ============================================================
# DATOS DEL USUARIO
# ============================================================

show_user_data() {

    local user="$1"

    local connected
    local total
    local ips

    connected="$(get_connected "$user")"

    total="${connected%%|*}"
    ips="${connected#*|}"

    echo -e "${CYAN}╭──────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│ ${WHITE}👤 Usuario        : ${GREEN}$user${RESET}"
    echo -e "${CYAN}│ ${WHITE}📅 Expiración     : ${YELLOW}$(get_expire "$user")${RESET}"
    echo -e "${CYAN}│ ${WHITE}⏳ Días restantes : ${YELLOW}$(get_days "$user")${RESET}"
    echo -e "${CYAN}│ ${WHITE}👥 Límite IP      : ${YELLOW}$(get_limit "$user")${RESET}"
    echo -e "${CYAN}│ ${WHITE}🔌 Conectados     : ${GREEN}$total${RESET}"
    echo -e "${CYAN}│ ${WHITE}🌐 IP(s)          : ${GRAY}$ips${RESET}"
    echo -e "${CYAN}│ ${WHITE}🎨 Banner         : ${MAGENTA}$(banner_type "$user")${RESET}"
    echo -e "${CYAN}╰──────────────────────────────────────────────╯${RESET}"

}

# ============================================================
# RESUMEN
# ============================================================

summary() {

    local total

    total="$(count_users)"

    echo -e "${BLUE}╭──────────────────────────────────────────────╮${RESET}"
    echo -e "${BLUE}│ ${WHITE}CUENTAS DETECTADAS : ${GREEN}$total${BLUE}                  │${RESET}"
    echo -e "${BLUE}╰──────────────────────────────────────────────╯${RESET}"

    echo

}

# ============================================================
# LEER CONFIGURACIÓN DEL BANNER
# ============================================================

get_saved_mode() {

    if [[ -f "$STATE_FILE" ]]; then

        grep '^BANNER_MODE=' "$STATE_FILE" |
            cut -d= -f2- |
            head -1

    fi

}

get_saved_title() {

    if [[ -f "$STATE_FILE" ]]; then

        grep '^BANNER_TITLE=' "$STATE_FILE" |
            cut -d= -f2- |
            head -1

    fi

}

get_saved_text() {

    if [[ -f "$STATE_FILE" ]]; then

        sed -n '/^BANNER_TEXT_START$/,/^BANNER_TEXT_END$/{
            /^BANNER_TEXT_START$/d
            /^BANNER_TEXT_END$/d
            p
        }' "$STATE_FILE"

    fi

}

# ============================================================
# GUARDAR CONFIGURACIÓN
# ============================================================

save_config() {

    local mode="$1"
    local title="$2"
    local text="$3"

    {
        echo "BANNER_MODE=$mode"
        echo "BANNER_TITLE=$title"
        echo "BANNER_TEXT_START"
        printf '%s\n' "$text"
        echo "BANNER_TEXT_END"
    } > "$STATE_FILE"

    chmod 600 "$STATE_FILE"

}

# ============================================================
# GENERAR BANNER
# ============================================================

generate_banner() {

    local user="$1"
    local title="$2"
    local text="$3"
    local template="$4"

    local expire
    local days
    local limit
    local connected
    local total
    local ips

    local promo
    local channel
    local support
    local bot

    expire="$(get_expire "$user")"
    days="$(get_days "$user")"
    limit="$(get_limit "$user")"

    connected="$(get_connected "$user")"

    total="${connected%%|*}"
    ips="${connected#*|}"

    set +u

    promo="${BANNER_PROMO_TEXT:-}"
    channel="${BANNER_PROMO_CHANNEL:-}"
    support="${BANNER_PROMO_SUPPORT:-}"
    bot="${BANNER_PROMO_BOT_NAME:-}"

    set -u

    user="$(html_escape "$user")"
    title="$(html_escape "$title")"
    expire="$(html_escape "$expire")"
    days="$(html_escape "$days")"
    limit="$(html_escape "$limit")"
    ips="$(html_escape "$ips")"
    text="$(html_escape "$text")"

    promo="$(html_escape "$promo")"
    channel="$(html_escape "$channel")"
    support="$(html_escape "$support")"
    bot="$(html_escape "$bot")"

    local type

    if [[ "$template" == "PERSONALIZADO" ]]; then
        type="custom"
    else
        type="template"
    fi

    cat <<EOF
<!-- data-kevintech-type="$type" data-kevintech-template="$template" -->

<html>

<head>

<meta charset="UTF-8">

<title>KevinTech</title>

</head>

<body>

<center>

<font size="5">
<b>✦ $title ✦</b>
</font>

<br>
<br>

<b>╭──────────────────────────────────────────────╮</b><br>
<b>│              KEVINTECH SSH                   │</b><br>
<b>├──────────────────────────────────────────────┤</b><br>
<b>│ 👤 Usuario        : $user</b><br>
<b>│ 📅 Expiración     : $expire</b><br>
<b>│ ⏳ Días restantes : $days</b><br>
<b>│ 👥 Límite IP      : $limit</b><br>
<b>│ 🔌 Conectados     : $total</b><br>
<b>│ 🌐 IP(s)          : $ips</b><br>
<b>╰──────────────────────────────────────────────╯</b>

<br>
<br>

EOF

    if [[ -n "$text" ]]; then

        echo "<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b><br>"
        echo "<b>✦ MENSAJE ✦</b><br>"
        echo "<b>$text</b><br>"
        echo "<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b><br>"

    fi

    case "$template" in

        CLASICA)

            echo "<br>"
            echo "<b>KEVINTECH SSH</b><br>"
            echo "Bienvenido. Tu cuenta está activa.<br>"

            ;;

        PREMIUM)

            echo "<br>"
            echo "<b>★ KEVINTECH PREMIUM ★</b><br>"
            echo "Servicio activo y administrado por KevinTech.<br>"

            ;;

        MINIMAL)

            echo "<br>"
            echo "<b>KEVINTECH</b><br>"
            echo "Cuenta autorizada.<br>"

            ;;

        PERSONALIZADO)

            ;;

    esac

    [[ -n "$promo" ]] &&
        echo "<br><b>$promo</b><br>"

    [[ -n "$channel" ]] &&
        echo "<b>Canal:</b> $channel<br>"

    [[ -n "$support" ]] &&
        echo "<b>Soporte:</b> $support<br>"

    [[ -n "$bot" ]] &&
        echo "<b>Bot:</b> $bot<br>"

    cat <<'EOF'

<br>

<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>

</center>

</body>

</html>
EOF

}

# ============================================================
# CREAR BANNER DE UN USUARIO
# ============================================================

create_user_banner() {

    local user="$1"
    local title="$2"
    local text="$3"
    local template="$4"

    local file

    file="$(banner_file "$user")"

    generate_banner \
        "$user" \
        "$title" \
        "$text" \
        "$template" > "$file"

    chmod 644 "$file"
    chown root:root "$file"

}

# ============================================================
# CREAR PARA TODOS
# ============================================================

create_all_banners() {

    local title="$1"
    local text="$2"
    local template="$3"

    local user
    local count=0

    while IFS= read -r user; do

        [[ -z "$user" ]] && continue

        create_user_banner \
            "$user" \
            "$title" \
            "$text" \
            "$template"

        echo -e "${GREEN}✔${RESET} $user"

        ((count+=1))

    done < <(get_users)

    echo
    echo -e "${GREEN}✔ Banners creados: $count${RESET}"

}

# ============================================================
# BACKUP SSH
# ============================================================

backup_sshd() {

    [[ -f "$SSHD_CONFIG" ]] || return

    cp -a "$SSHD_CONFIG" \
        "$BACKUP_DIR/sshd_config.$(date +%Y%m%d-%H%M%S)"

}

# ============================================================
# QUITAR BLOQUE KEVINTECH
# ============================================================

remove_kevintech_blocks() {

    [[ -f "$SSHD_CONFIG" ]] || return

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

    backup_sshd

    remove_kevintech_blocks

    {

        echo
        echo "$START_MARK"

        while IFS= read -r user; do

            [[ -z "$user" ]] && continue

            file="$(banner_file "$user")"

            [[ -f "$file" ]] || continue

            echo "Match User $user"
            echo "    Banner $file"
            echo

        done < <(get_users)

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
# SINCRONIZACIÓN AUTOMÁTICA DE CUENTAS NUEVAS
# ============================================================

auto_sync_new_users() {

    local mode
    local title
    local text

    mode="$(get_saved_mode)"

    [[ -z "$mode" ]] && return

    title="$(get_saved_title)"
    text="$(get_saved_text)"

    case "$mode" in

        PERSONALIZADO)

            while IFS= read -r user; do

                [[ -z "$user" ]] && continue

                if [[ ! -f "$(banner_file "$user")" ]]; then

                    create_user_banner \
                        "$user" \
                        "$title" \
                        "$text" \
                        "PERSONALIZADO"

                fi

            done < <(get_users)

            ;;

        CLASICA|PREMIUM|MINIMAL)

            while IFS= read -r user; do

                [[ -z "$user" ]] && continue

                if [[ ! -f "$(banner_file "$user")" ]]; then

                    create_user_banner \
                        "$user" \
                        "$title" \
                        "$text" \
                        "$mode"

                fi

            done < <(get_users)

            ;;

    esac

    sync_sshd >/dev/null 2>&1 || true

}

# ============================================================
# SELECCIONAR PLANTILLA
# ============================================================

choose_template() {

    echo
    echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${WHITE}              SELECCIONAR PLANTILLA        ${CYAN}│${RESET}"
    echo -e "${CYAN}├────────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}│ ${GREEN}[1]${WHITE} Clásica                                ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${MAGENTA}[2]${WHITE} Premium                                ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${BLUE}[3]${WHITE} Minimal                                ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${RED}[0]${WHITE} Volver                                  ${CYAN}│${RESET}"
    echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"
    echo

    local option

    read -rp "❯ Opción: " option

    case "$option" in

        1)
            echo "CLASICA"
            ;;

        2)
            echo "PREMIUM"
            ;;

        3)
            echo "MINIMAL"
            ;;

        *)
            return 1
            ;;

    esac

}

# ============================================================
# LEER TEXTO PERSONALIZADO
# ============================================================

read_custom_text() {

    local text=""
    local line

    echo
    echo -e "${CYAN}Escribe tu mensaje personalizado.${RESET}"
    echo -e "${GRAY}Puedes escribir varias líneas.${RESET}"
    echo -e "${YELLOW}Para terminar escribe: FINBANNER${RESET}"
    echo

    while IFS= read -r line; do

        [[ "$line" == "FINBANNER" ]] && break

        if [[ -n "$text" ]]; then
            text+=$'\n'
        fi

        text+="$line"

    done

    printf '%s' "$text"

}

# ============================================================
# INSTALAR SUBMENÚ
# ============================================================

submenu_install() {

    while true; do

        header

        echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
        echo -e "${CYAN}│${WHITE}              INSTALAR BANNER               ${CYAN}│${RESET}"
        echo -e "${CYAN}├────────────────────────────────────────────┤${RESET}"
        echo -e "${CYAN}│ ${GREEN}[1]${WHITE} Banner personalizado                  ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[2]${WHITE} Plantilla clásica                     ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[3]${WHITE} Plantilla premium                     ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[4]${WHITE} Plantilla minimal                     ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${RED}[0]${WHITE} Volver                                ${CYAN}│${RESET}"
        echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"

        echo

        local option
        local title
        local text
        local template

        read -rp "❯ Opción: " option

        case "$option" in

            1)

                read -rp "Título del banner: " title

                [[ -z "$title" ]] &&
                    title="KEVINTECH SSH"

                text="$(read_custom_text)"

                save_config \
                    "PERSONALIZADO" \
                    "$title" \
                    "$text"

                echo
                create_all_banners \
                    "$title" \
                    "$text" \
                    "PERSONALIZADO"

                sync_sshd

                pause

                ;;

            2)

                template="CLASICA"
                title="KEVINTECH SSH"
                text=""

                save_config \
                    "$template" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "$template"

                sync_sshd

                pause

                ;;

            3)

                template="PREMIUM"
                title="KEVINTECH PREMIUM"
                text=""

                save_config \
                    "$template" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "$template"

                sync_sshd

                pause

                ;;

            4)

                template="MINIMAL"
                title="KEVINTECH"
                text=""

                save_config \
                    "$template" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "$template"

                sync_sshd

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
# VER SUBMENÚ
# ============================================================

submenu_view() {

    while true; do

        header

        echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
        echo -e "${CYAN}│${WHITE}                VER BANNERS                 ${CYAN}│${RESET}"
        echo -e "${CYAN}├────────────────────────────────────────────┤${RESET}"
        echo -e "${CYAN}│ ${GREEN}[1]${WHITE} Ver todos los usuarios                ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[2]${WHITE} Ver resumen                            ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${RED}[0]${WHITE} Volver                                 ${CYAN}│${RESET}"
        echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"

        echo

        local option
        local user
        local file

        read -rp "❯ Opción: " option

        case "$option" in

            1)

                header
                summary

                while IFS= read -r user; do

                    [[ -z "$user" ]] && continue

                    echo
                    show_user_data "$user"
                    echo

                    file="$(banner_file "$user")"

                    if [[ -f "$file" ]]; then

                        echo -e "${BLUE}┌──────────── BANNER $user ─────────────┐${RESET}"

                        sed '/^<!-- data-kevintech-/d' "$file"

                        echo -e "${BLUE}└─────────────────────────────────────────┘${RESET}"

                    else

                        echo -e "${YELLOW}⚠ Sin banner instalado.${RESET}"

                    fi

                    echo
                    echo -e "${GRAY}────────────────────────────────────────────────${RESET}"

                done < <(get_users)

                pause

                ;;

            2)

                header
                summary

                echo -e "${WHITE}Estado de las cuentas:${RESET}"
                echo

                printf "%-20s %-10s %-18s %-15s\n" \
                    "USUARIO" \
                    "LÍMITE" \
                    "EXPIRACIÓN" \
                    "BANNER"

                echo "----------------------------------------------------------------"

                while IFS= read -r user; do

                    [[ -z "$user" ]] && continue

                    printf "%-20s %-10s %-18s %-15s\n" \
                        "$user" \
                        "$(get_limit "$user")" \
                        "$(get_expire "$user")" \
                        "$(banner_type "$user")"

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
# ELIMINAR SUBMENÚ
# ============================================================

submenu_delete() {

    while true; do

        header

        echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
        echo -e "${CYAN}│${WHITE}              ELIMINAR BANNERS             ${CYAN}│${RESET}"
        echo -e "${CYAN}├────────────────────────────────────────────┤${RESET}"
        echo -e "${CYAN}│ ${RED}[1]${WHITE} Eliminar todos los banners           ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${YELLOW}[2]${WHITE} Eliminar configuración automática    ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${RED}[0]${WHITE} Volver                                ${CYAN}│${RESET}"
        echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"

        echo

        local option
        local confirm
        local user

        read -rp "❯ Opción: " option

        case "$option" in

            1)

                echo
                echo -e "${RED}⚠ ATENCIÓN${RESET}"
                echo -e "${YELLOW}Esto eliminará los banners de todas las cuentas.${RESET}"
                echo

                read -rp "¿Continuar? [s/N]: " confirm

                if [[ "$confirm" =~ ^[sS]$ ]]; then

                    while IFS= read -r user; do

                        [[ -z "$user" ]] && continue

                        rm -f "$(banner_file "$user")"

                        echo -e "${GREEN}✔ Eliminado:${RESET} $user"

                    done < <(get_users)

                    rm -f "$STATE_FILE"

                    sync_sshd

                    echo
                    echo -e "${GREEN}✔ Todos los banners fueron eliminados.${RESET}"

                else

                    echo "Cancelado."

                fi

                pause

                ;;

            2)

                rm -f "$STATE_FILE"

                echo -e "${GREEN}✔ Configuración automática eliminada.${RESET}"

                echo
                echo -e "${GRAY}Los banners existentes no fueron eliminados.${RESET}"

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
# EDITAR SUBMENÚ
# ============================================================

submenu_edit() {

    while true; do

        header

        echo -e "${CYAN}╭────────────────────────────────────────────╮${RESET}"
        echo -e "${CYAN}│${WHITE}               EDITAR BANNER                ${CYAN}│${RESET}"
        echo -e "${CYAN}├────────────────────────────────────────────┤${RESET}"
        echo -e "${CYAN}│ ${GREEN}[1]${WHITE} Editar banner personalizado          ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[2]${WHITE} Cambiar a plantilla clásica          ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[3]${WHITE} Cambiar a plantilla premium          ${CYAN}│${RESET}"
        echo -e "${CYAN}│ ${GREEN}[4]${WHITE} Cambiar a plantilla minimal          ${CYAN}│${RESET}"
        echo -e "${RED}│ [0]${WHITE} Volver                                ${CYAN}│${RESET}"
        echo -e "${CYAN}╰────────────────────────────────────────────╯${RESET}"

        echo

        local option
        local title
        local text
        local template

        read -rp "❯ Opción: " option

        case "$option" in

            1)

                read -rp "Nuevo título: " title

                [[ -z "$title" ]] &&
                    title="KEVINTECH SSH"

                text="$(read_custom_text)"

                save_config \
                    "PERSONALIZADO" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "PERSONALIZADO"

                sync_sshd

                pause

                ;;

            2)

                template="CLASICA"
                title="KEVINTECH SSH"
                text=""

                save_config \
                    "$template" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "$template"

                sync_sshd

                pause

                ;;

            3)

                template="PREMIUM"
                title="KEVINTECH PREMIUM"
                text=""

                save_config \
                    "$template" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "$template"

                sync_sshd

                pause

                ;;

            4)

                template="MINIMAL"
                title="KEVINTECH"
                text=""

                save_config \
                    "$template" \
                    "$title" \
                    "$text"

                create_all_banners \
                    "$title" \
                    "$text" \
                    "$template"

                sync_sshd

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
# SINCRONIZACIÓN INICIAL
# ============================================================

auto_sync_new_users
# ============================================================
# MODO AUTOMÁTICO PARA NUEVAS CUENTAS
# ============================================================
# Uso:
#   banner.sh --auto-user USUARIO
#
# Este modo NO muestra el menú.
# Lee la última configuración guardada y crea
# automáticamente el banner para el nuevo usuario.
# ============================================================

if [[ "${1:-}" == "--auto-user" ]]; then

    NEW_USER="${2:-}"

    # Verificar que se recibió usuario
    if [[ -z "$NEW_USER" ]]; then
        exit 1
    fi

    # Verificar que el usuario exista en limits.conf
    if ! user_exists "$NEW_USER"; then
        exit 1
    fi

    # Leer configuración automática guardada
    MODE="$(get_saved_mode)"

    # Si todavía no se configuró ningún banner,
    # no hacemos nada.
    if [[ -z "$MODE" ]]; then
        exit 0
    fi

    TITLE="$(get_saved_title)"
    TEXT="$(get_saved_text)"

    case "$MODE" in

        PERSONALIZADO)

            [[ -z "$TITLE" ]] && TITLE="KEVINTECH SSH"

            create_user_banner \
                "$NEW_USER" \
                "$TITLE" \
                "$TEXT" \
                "PERSONALIZADO"

            ;;

        CLASICA)

            create_user_banner \
                "$NEW_USER" \
                "KEVINTECH SSH" \
                "" \
                "CLASICA"

            ;;

        PREMIUM)

            create_user_banner \
                "$NEW_USER" \
                "KEVINTECH PREMIUM" \
                "" \
                "PREMIUM"

            ;;

        MINIMAL)

            create_user_banner \
                "$NEW_USER" \
                "KEVINTECH" \
                "" \
                "MINIMAL"

            ;;

        *)

            exit 1

            ;;

    esac

    # Actualizar Match User en sshd_config
    sync_sshd >/dev/null 2>&1 || true

    exit 0

fi
# ============================================================
# MENÚ PRINCIPAL
# ============================================================

while true; do

    header
    summary

    echo -e "${CYAN}╭──────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${WHITE}                 MENÚ PRINCIPAL              ${CYAN}│${RESET}"
    echo -e "${CYAN}├──────────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}│ ${GREEN}[1]${WHITE}  INSTALAR BANNER                         ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${GREEN}[2]${WHITE}  VER BANNERS                             ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${RED}[3]${WHITE}  ELIMINAR BANNERS                        ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${YELLOW}[4]${WHITE}  EDITAR BANNER                            ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${RED}[0]${WHITE}  SALIR                                    ${CYAN}│${RESET}"
    echo -e "${CYAN}╰──────────────────────────────────────────────╯${RESET}"

    echo

    read -rp "  ❯ Selecciona una opción: " option

    case "$option" in

        1)
            submenu_install
            ;;

        2)
            submenu_view
            ;;

        3)
            submenu_delete
            ;;

        4)
            submenu_edit
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