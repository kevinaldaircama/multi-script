#!/bin/bash
# ============================================================
# KEVINTECH PER-USER BANNER MANAGER v4.0
# Automático para TODOS los usuarios de:
# /etc/kevintech/limits.conf
#
# NO usa /etc/issue.net como banner global.
# NO muestra dominio ni servidor.
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
# COMPROBACIONES
# ============================================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"
    exit 1
fi

mkdir -p "$BANNER_DIR" "$BACKUP_DIR"
chmod 700 "$BANNER_DIR"

pause() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

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
# CABECERA
# ============================================================
header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}             KEVINTECH BANNER MANAGER               ${CYAN}║${RESET}"
    echo -e "${CYAN}║${GRAY}                  PER-USER v4.0                     ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE} Usuarios: ${GRAY}/etc/kevintech/limits.conf${CYAN}           ║${RESET}"
    echo -e "${CYAN}║${WHITE} Banners : ${GRAY}/etc/ssh_banners${CYAN}                    ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo
}

# ============================================================
# USUARIOS DEL PRIMER CÓDIGO
# Formato: usuario:limite
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

user_exists() {
    local user="$1"
    [[ -f "$LIMITS_FILE" ]] || return 1
    awk -F: -v u="$user" '$1==u {found=1; exit} END {exit !found}' "$LIMITS_FILE"
}

count_users() {
    get_users | wc -l | tr -d ' '
}

get_limit() {
    local user="$1"
    local limit

    limit="$(awk -F: -v u="$user" '$1==u {print $2; exit}' "$LIMITS_FILE" 2>/dev/null || true)"
    [[ -n "$limit" ]] && echo "$limit" || echo "1"
}

get_expire() {
    local user="$1"
    local expire=""

    if id "$user" >/dev/null 2>&1; then
        expire="$(chage -l "$user" 2>/dev/null |
            awk -F: '/Account expires/ {
                gsub(/^[ \t]+/, "", $2)
                print $2
                exit
            }' || true)"
    fi

    [[ -n "$expire" ]] && echo "$expire" || echo "Nunca"
}

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

get_connected() {
    local user="$1"
    local total ips

    total="$(who 2>/dev/null |
        awk -v u="$user" '$1==u {n++} END {print n+0}')"

    ips="$(who 2>/dev/null |
        awk -v u="$user" '$1==u && $5 ~ /^\(/ {
            gsub(/[()]/, "", $5)
            print $5
        }' |
        sort -u |
        paste -sd, -)"

    [[ -z "$ips" ]] && ips="Sin conexión"

    echo "$total|$ips"
}

# ============================================================
# ESCAPE HTML
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
# TIPO DE BANNER
# ============================================================
banner_type() {
    local user="$1"
    local file="$BANNER_DIR/$user.banner"
    local template

    [[ -f "$file" ]] || {
        echo "Ninguno"
        return
    }

    if grep -q 'data-kevintech-type="custom"' "$file" 2>/dev/null; then
        echo "Personalizado"
        return
    fi

    if grep -q 'data-kevintech-type="template"' "$file" 2>/dev/null; then
        template="$(sed -n 's/.*data-kevintech-template="\([^"]*\)".*/\1/p' "$file" | head -1)"
        [[ -n "$template" ]] && echo "$template" || echo "Plantilla"
        return
    fi

    echo "Configurado"
}

# ============================================================
# DATOS DE UN USUARIO
# ============================================================
show_user_data() {
    local user="$1"
    local connected total ips

    connected="$(get_connected "$user")"
    total="${connected%%|*}"
    ips="${connected#*|}"

    echo -e "${CYAN}┌──────────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}│ ${WHITE}👤 Usuario        : ${GREEN}${user}${RESET}"
    echo -e "${CYAN}│ ${WHITE}📅 Expiración     : ${YELLOW}$(get_expire "$user")${RESET}"
    echo -e "${CYAN}│ ${WHITE}⏳ Días restantes : ${YELLOW}$(get_days "$user")${RESET}"
    echo -e "${CYAN}│ ${WHITE}👥 Límite IP      : ${YELLOW}$(get_limit "$user")${RESET}"
    echo -e "${CYAN}│ ${WHITE}🔌 Conectados     : ${GREEN}${total}${RESET}"
    echo -e "${CYAN}│ ${WHITE}🌐 IP(s)          : ${GRAY}${ips}${RESET}"
    echo -e "${CYAN}│ ${WHITE}🎨 Banner         : ${MAGENTA}$(banner_type "$user")${RESET}"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${RESET}"
}

# ============================================================
# RESUMEN GENERAL
# ============================================================
show_summary() {
    local total
    total="$(count_users)"

    echo -e "${BLUE}╭────────────────────────────────────────────────╮${RESET}"
    echo -e "${BLUE}│ ${WHITE}USUARIOS DEL PRIMER CÓDIGO${BLUE}                   │${RESET}"
    echo -e "${BLUE}├────────────────────────────────────────────────┤${RESET}"
    echo -e "${BLUE}│ ${WHITE}Total de usuarios : ${GREEN}${total}${BLUE}                    │${RESET}"
    echo -e "${BLUE}╰────────────────────────────────────────────────╯${RESET}"
    echo
}

# ============================================================
# GENERADOR DE BANNER
# ============================================================
generate_banner() {
    local user="$1"
    local title="$2"
    local text="$3"
    local template="$4"

    local expire days limit connected total ips
    local promo channel support bot
    local type

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

    if [[ "$template" == "PERSONALIZADO" ]]; then
        type="custom"
    else
        type="template"
    fi

    local eu et ex ed el ei ep ec es eb
    eu="$(html_escape "$user")"
    et="$(html_escape "$title")"
    ex="$(html_escape "$expire")"
    ed="$(html_escape "$days")"
    el="$(html_escape "$limit")"
    ei="$(html_escape "$ips")"
    ep="$(html_escape "$promo")"
    ec="$(html_escape "$channel")"
    es="$(html_escape "$support")"
    eb="$(html_escape "$bot")"
    text="$(html_escape "$text")"

    cat <<EOF
<!-- data-kevintech-type="$type" data-kevintech-template="$(html_escape "$template")" -->
<html>
<head>
<meta charset="UTF-8">
<title>KevinTech - $eu</title>
</head>
<body>
<center>

<font size="5"><b>✦ $et ✦</b></font>
<br><br>

<b>╭──────────────────────────────────────────────╮</b><br>
<b>│              KEVINTECH SSH                   │</b><br>
<b>├──────────────────────────────────────────────┤</b><br>
<b>│ 👤 Usuario        : $eu</b><br>
<b>│ 📅 Expiración     : $ex</b><br>
<b>│ ⏳ Días restantes : $ed</b><br>
<b>│ 👥 Límite IP      : $el</b><br>
<b>│ 🔌 Conectados     : $total</b><br>
<b>│ 🌐 IP(s)          : $ei</b><br>
<b>╰──────────────────────────────────────────────╯</b><br>
EOF

    if [[ -n "$text" ]]; then
        echo
        echo "<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b><br>"
        echo "<b>✦ MENSAJE ✦</b><br>"
        echo "<b>$text</b><br>"
        echo "<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b><br>"
    fi

    case "$template" in
        CLASICA)
            cat <<'EOF'
<br>
<b>KEVINTECH SSH</b><br>
Bienvenido. Tu cuenta está activa.<br>
EOF
            ;;
        PREMIUM)
            cat <<'EOF'
<br>
<b>★ KEVINTECH PREMIUM ★</b><br>
Servicio activo y administrado por KevinTech.<br>
EOF
            ;;
        MINIMAL)
            cat <<'EOF'
<br>
<b>KEVINTECH</b><br>
Cuenta autorizada.<br>
EOF
            ;;
        PERSONALIZADO)
            ;;
    esac

    [[ -n "$promo" ]] && echo "<br><b>$ep</b><br>"
    [[ -n "$channel" ]] && echo "<b>Canal:</b> $ec<br>"
    [[ -n "$support" ]] && echo "<b>Soporte:</b> $es<br>"
    [[ -n "$bot" ]] && echo "<b>Bot:</b> $eb<br>"

    cat <<'EOF'
<br>
<b>━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━</b>
</center>
</body>
</html>
EOF
}

# ============================================================
# GUARDAR BANNER
# ============================================================
write_banner() {
    local user="$1"
    local title="$2"
    local text="$3"
    local template="$4"
    local file="$BANNER_DIR/$user.banner"

    generate_banner "$user" "$title" "$text" "$template" > "$file"

    chmod 644 "$file"
    chown root:root "$file"

    echo -e "${GREEN}✔ Banner creado para: ${WHITE}$user${RESET}"
}

# ============================================================
# PLANTILLA
# ============================================================
choose_template() {
    echo
    echo -e "${CYAN}╭────────────── PLANTILLAS ──────────────╮${RESET}"
    echo -e "${CYAN}│ ${WHITE}[1]${RESET} Clásica                           ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${WHITE}[2]${RESET} Premium                           ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${WHITE}[3]${RESET} Minimal                           ${CYAN}│${RESET}"
    echo -e "${CYAN}│ ${WHITE}[0]${RESET} Cancelar                          ${CYAN}│${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────╯${RESET}"
    echo

    local option
    read -rp "Opción: " option

    case "$option" in
        1) echo "CLASICA" ;;
        2) echo "PREMIUM" ;;
        3) echo "MINIMAL" ;;
        *) return 1 ;;
    esac
}

# ============================================================
# BANNER PERSONALIZADO
# ============================================================
read_custom_text() {
    local text=""
    local line

    echo
    echo -e "${CYAN}Escribe el mensaje personalizado.${RESET}"
    echo -e "${GRAY}Puedes escribir varias líneas.${RESET}"
    echo -e "${YELLOW}Para terminar escribe exactamente: FINBANNER${RESET}"
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
# INSTALAR PARA TODOS
# ============================================================
install_all() {
    header
    show_summary

    local users
    users="$(get_users)"

    if [[ -z "$users" ]]; then
        echo -e "${RED}✘ No hay usuarios en $LIMITS_FILE${RESET}"
        pause
        return
    fi

    echo -e "${WHITE}¿Qué banner deseas instalar para TODOS los usuarios?${RESET}"
    echo
    echo -e "${GREEN}[1]${RESET} Banner personalizado"
    echo -e "${GREEN}[2]${RESET} Plantilla"
    echo -e "${RED}[0]${RESET} Cancelar"
    echo

    local mode title text template
    read -rp "Opción: " mode

    case "$mode" in
        1)
            read -rp "Título del banner: " title
            [[ -z "$title" ]] && title="KEVINTECH SSH"

            text="$(read_custom_text)"
            template="PERSONALIZADO"
            ;;
        2)
            template="$(choose_template)" || return
            title="KEVINTECH $template"
            text=""
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Opción inválida.${RESET}"
            pause
            return
            ;;
    esac

    echo
    echo -e "${CYAN}Instalando automáticamente para todos los usuarios...${RESET}"
    echo

    local user count=0

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        write_banner "$user" "$title" "$text" "$template"
        ((count+=1))
    done <<< "$users"

    sync_sshd

    echo
    echo -e "${GREEN}╭────────────────────────────────────────────╮${RESET}"
    echo -e "${GREEN}│ ✔ BANNER INSTALADO CORRECTAMENTE          │${RESET}"
    echo -e "${GREEN}│ Usuarios actualizados: ${WHITE}$count${GREEN}             │${RESET}"
    echo -e "${GREEN}╰────────────────────────────────────────────╯${RESET}"

    pause
}

# ============================================================
# VER TODOS
# ============================================================
view_all() {
    header
    show_summary

    local users
    users="$(get_users)"

    if [[ -z "$users" ]]; then
        echo -e "${RED}✘ No hay usuarios registrados.${RESET}"
        pause
        return
    fi

    local user file

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue

        echo
        show_user_data "$user"
        echo

        file="$BANNER_DIR/$user.banner"

        if [[ -f "$file" ]]; then
            echo -e "${BLUE}┌──────────── BANNER: $user ─────────────┐${RESET}"
            sed '/^<!-- data-kevintech-/d' "$file"
            echo -e "${BLUE}└─────────────────────────────────────────┘${RESET}"
        else
            echo -e "${YELLOW}⚠ Sin banner instalado.${RESET}"
        fi

        echo
        echo -e "${GRAY}────────────────────────────────────────────────${RESET}"
    done <<< "$users"

    pause
}

# ============================================================
# ELIMINAR TODOS
# ============================================================
delete_all() {
    header
    show_summary

    local users
    users="$(get_users)"

    if [[ -z "$users" ]]; then
        echo -e "${RED}✘ No hay usuarios registrados.${RESET}"
        pause
        return
    fi

    echo -e "${YELLOW}⚠ Esta acción eliminará los banners de TODOS los usuarios.${RESET}"
    echo
    read -rp "¿Continuar? [s/N]: " confirm

    [[ "$confirm" =~ ^[sS]$ ]] || {
        echo "Cancelado."
        pause
        return
    }

    local user count=0

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue

        if [[ -f "$BANNER_DIR/$user.banner" ]]; then
            rm -f "$BANNER_DIR/$user.banner"
            echo -e "${GREEN}✔ Eliminado: ${WHITE}$user${RESET}"
            ((count+=1))
        fi
    done <<< "$users"

    sync_sshd

    echo
    echo -e "${GREEN}✔ Se eliminaron $count banners.${RESET}"
    pause
}

# ============================================================
# EDITAR TODOS
# ============================================================
edit_all() {
    header
    show_summary

    local users
    users="$(get_users)"

    if [[ -z "$users" ]]; then
        echo -e "${RED}✘ No hay usuarios registrados.${RESET}"
        pause
        return
    fi

    echo -e "${CYAN}¿Qué deseas editar para TODOS los usuarios?${RESET}"
    echo
    echo -e "${GREEN}[1]${RESET} Banner personalizado"
    echo -e "${GREEN}[2]${RESET} Cambiar plantilla"
    echo -e "${RED}[0]${RESET} Cancelar"
    echo

    local mode title text template
    read -rp "Opción: " mode

    case "$mode" in
        1)
            read -rp "Nuevo título: " title
            [[ -z "$title" ]] && title="KEVINTECH SSH"
            text="$(read_custom_text)"
            template="PERSONALIZADO"
            ;;
        2)
            template="$(choose_template)" || return
            title="KEVINTECH $template"
            text=""
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Opción inválida.${RESET}"
            pause
            return
            ;;
    esac

    echo
    echo -e "${CYAN}Actualizando todos los banners...${RESET}"
    echo

    local user count=0

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        write_banner "$user" "$title" "$text" "$template"
        ((count+=1))
    done <<< "$users"

    sync_sshd

    echo
    echo -e "${GREEN}✔ $count banners actualizados.${RESET}"
    pause
}

# ============================================================
# SINCRONIZAR
# Solo crea bloques para banners que existen.
# ============================================================
backup_sshd() {
    [[ -f "$SSHD_CONFIG" ]] || return
    cp -a "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.$(date +%Y%m%d-%H%M%S)"
}

remove_blocks() {
    [[ -f "$SSHD_CONFIG" ]] || return

    awk -v start="$START_MARK" -v end="$END_MARK" '
        $0 == start {inside=1; next}
        $0 == end {inside=0; next}
        !inside {print}
    ' "$SSHD_CONFIG" > "${SSHD_CONFIG}.tmp"

    mv "${SSHD_CONFIG}.tmp" "$SSHD_CONFIG"
}

sync_sshd() {
    local user file

    backup_sshd
    remove_blocks

    {
        echo
        echo "$START_MARK"

        while IFS= read -r user; do
            [[ -z "$user" ]] && continue

            file="$BANNER_DIR/$user.banner"

            [[ -f "$file" ]] || continue

            echo "Match User $user"
            echo "    Banner $file"
            echo
        done < <(get_users)

        echo "$END_MARK"
    } >> "$SSHD_CONFIG"

    if command -v sshd >/dev/null 2>&1; then
        if ! sshd -t 2>/tmp/kevintech_sshd_error; then
            echo -e "${RED}✘ Error en la configuración de SSH:${RESET}"
            cat /tmp/kevintech_sshd_error
            return 1
        fi
    fi

    systemctl reload ssh 2>/dev/null ||
    systemctl reload sshd 2>/dev/null ||
    true

    echo -e "${GREEN}✔ SSH sincronizado.${RESET}"
}

# ============================================================
# SINCRONIZAR NUEVOS USUARIOS SIN CAMBIAR EL BANNER
# ============================================================
sync_new_users() {
    local user title template text file

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue

        file="$BANNER_DIR/$user.banner"

        [[ -f "$file" ]] && continue

        # Si existe configuración anterior, por defecto se crea
        # una plantilla Premium para el nuevo usuario.
        title="KEVINTECH PREMIUM"
        template="PREMIUM"
        text=""

        write_banner "$user" "$title" "$text" "$template"
    done < <(get_users)

    sync_sshd
}

# ============================================================
# MENÚ
# ============================================================
while true; do
    header
    show_summary

    echo -e "${CYAN}╭────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│${WHITE}                  MENÚ PRINCIPAL               ${CYAN}│${RESET}"
    echo -e "${CYAN}├────────────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}│ ${GREEN}[1]${WHITE}  INSTALAR BANNER                         ${CYAN}│${RESET}"
    echo -e "${CYAN}│      ${GRAY}Personalizado o plantilla${CYAN}              │${RESET}"
    echo -e "${CYAN}│                                                │${RESET}"
    echo -e "${CYAN}│ ${GREEN}[2]${WHITE}  VER BANNERS                             ${CYAN}│${RESET}"
    echo -e "${CYAN}│      ${GRAY}Todos los usuarios automáticamente${CYAN}    │${RESET}"
    echo -e "${CYAN}│                                                │${RESET}"
    echo -e "${CYAN}│ ${RED}[3]${WHITE}  ELIMINAR BANNERS                        ${CYAN}│${RESET}"
    echo -e "${CYAN}│      ${GRAY}Todos los usuarios${CYAN}                       │${RESET}"
    echo -e "${CYAN}│                                                │${RESET}"
    echo -e "${CYAN}│ ${YELLOW}[4]${WHITE}  EDITAR BANNER                           ${CYAN}│${RESET}"
    echo -e "${CYAN}│      ${GRAY}Personalizado o plantilla${CYAN}              │${RESET}"
    echo -e "${CYAN}│                                                │${RESET}"
    echo -e "${CYAN}│ ${BLUE}[0]${WHITE}  SALIR                                   ${CYAN}│${RESET}"
    echo -e "${CYAN}╰────────────────────────────────────────────────╯${RESET}"
    echo

    read -rp "  ❯ Selecciona una opción: " option

    case "$option" in
        1) install_all ;;
        2) view_all ;;
        3) delete_all ;;
        4) edit_all ;;
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
