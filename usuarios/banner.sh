#!/bin/bash
#=========================================================
# KevinTech Per-User Banner Manager
# Versión: 1.0
#
# Crea un banner INDIVIDUAL para cada usuario SSH creado
# por el módulo KevinTech de usuarios.
#
# NO utiliza Banner global (/etc/issue.net).
#
# Fuentes:
#   Usuarios : /etc/kevintech/limits.conf
#   Expira   : chage
#   Límite   : /etc/kevintech/limits.conf
#   Banner   : /etc/ssh_banners/<usuario>.banner
#
# OpenSSH:
#   Match User usuario
#       Banner /etc/ssh_banners/usuario.banner
#=========================================================

set -u

#==============================
# COLORES
#==============================
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==============================
# RUTAS
#==============================
BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"
CONFIG="$BASE/config.conf"

BANNER_DIR="/etc/ssh_banners"
SSHD_CONFIG="/etc/ssh/sshd_config"

MARKER_START="# >>> KEVINTECH_PER_USER_BANNERS_START <<<"
MARKER_END="# >>> KEVINTECH_PER_USER_BANNERS_END <<<"

BACKUP_DIR="$BASE/banner-backups"
LATEST_BACKUP="$BACKUP_DIR/latest"

mkdir -p "$BASE" "$BANNER_DIR" "$BACKUP_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==============================
# ROOT
#==============================
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}✘ Ejecuta este script como root.${RESET}"
    exit 1
fi

#==============================
# UTILIDADES
#==============================
pause() {
    echo
    read -r -n1 -s -p "Presione cualquier tecla para continuar..."
    echo
}

msg_ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

msg_warn() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

msg_error() {
    echo -e "${RED}✘ $1${RESET}"
}

# Devuelve el servicio SSH disponible.
ssh_service() {
    if systemctl list-unit-files 2>/dev/null | grep -q '^ssh.service'; then
        echo "ssh"
        return 0
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q '^sshd.service'; then
        echo "sshd"
        return 0
    fi

    return 1
}

#==============================
# OBTENER HOST / IP
#==============================
get_host() {
    local host=""

    if [[ -n "${SERVER_DOMAIN:-}" ]]; then
        host="$SERVER_DOMAIN"
    fi

    if [[ -z "$host" && -f "$BASE/domain" ]]; then
        host=$(head -n1 "$BASE/domain" 2>/dev/null)
    fi

    if [[ -z "$host" && -f "/etc/xray/domain" ]]; then
        host=$(head -n1 /etc/xray/domain 2>/dev/null)
    fi

    if [[ -z "$host" ]]; then
        host=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    [[ -z "$host" ]] && host="Servidor"

    printf '%s' "$host"
}

HOST="$(get_host)"

#==============================
# LEER CONFIG PROMOCIONAL
# Compatible con config.conf
#==============================
PROMO="${BANNER_PROMO_TEXT:-🔥 SERVIDORES PREMIUM 🔥}"
CHANNEL="${BANNER_PROMO_CHANNEL:-@KevinTech}"
SUPPORT="${BANNER_PROMO_SUPPORT:-@KevinSupport}"
BOT="${BANNER_PROMO_BOT_NAME:-@KevinTechBot}"

#==============================
# ESCAPAR TEXTO PARA HTML
# Evita que caracteres &, < y > rompan el banner.
#==============================
html_escape() {
    local text="$1"
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    text="${text//\"/&quot;}"
    printf '%s' "$text"
}

#==============================
# VALIDAR NOMBRE DE USUARIO
#==============================
valid_username() {
    [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

#==============================
# LISTAR USUARIOS KEVINTECH
#
# El primer script guarda:
#   usuario:limite
#
# Por eso usamos limits.conf como fuente.
#==============================
get_users() {
    [[ -f "$LIMITS_FILE" ]] || return 0

    awk -F: '
        NF >= 2 &&
        $1 !~ /^[[:space:]]*#/ &&
        $1 != "" {
            print $1
        }
    ' "$LIMITS_FILE" |
    while IFS= read -r user; do
        if valid_username "$user" && id "$user" >/dev/null 2>&1; then
            printf '%s\n' "$user"
        fi
    done
}

#==============================
# OBTENER LÍMITE
#==============================
get_limit() {
    local user="$1"
    local limit

    limit=$(awk -F: -v u="$user" '$1 == u {print $2; exit}' "$LIMITS_FILE" 2>/dev/null)

    if [[ "$limit" =~ ^[0-9]+$ ]]; then
        printf '%s' "$limit"
    else
        printf '0'
    fi
}

#==============================
# OBTENER FECHA DE EXPIRACIÓN
#==============================
get_expire() {
    local user="$1"
    local exp

    exp=$(chage -l "$user" 2>/dev/null |
        awk -F': ' '/Account expires/ {print $2; exit}')

    if [[ -z "$exp" || "$exp" == "never" || "$exp" == "Never" ||
          "$exp" == "Nunca" ]]; then
        printf 'Ilimitada'
    else
        printf '%s' "$exp"
    fi
}

#==============================
# CALCULAR DÍAS RESTANTES
#==============================
get_days_left() {
    local user="$1"
    local exp exp_epoch now diff

    exp=$(chage -l "$user" 2>/dev/null |
        awk -F': ' '/Account expires/ {print $2; exit}')

    if [[ -z "$exp" || "$exp" == "never" || "$exp" == "Never" ||
          "$exp" == "Nunca" ]]; then
        printf '∞'
        return
    fi

    exp_epoch=$(date -d "$exp" +%s 2>/dev/null) || {
        printf 'N/D'
        return
    }

    now=$(date +%s)
    diff=$(( (exp_epoch - now) / 86400 ))

    (( diff < 0 )) && diff=0

    printf '%s' "$diff"
}

#==============================
# OBTENER TÍTULO INDIVIDUAL
#
# Opcional:
# BANNER_TITLE_usuario="..."
# en config.conf
#==============================
get_title() {
    local user="$1"
    local var="BANNER_TITLE_${user}"
    local value="${!var:-}"

    if [[ -n "$value" ]]; then
        printf '%s' "$value"
    else
        printf '%s' "${BANNER_DEFAULT_TITLE:-INTERNET ILIMITADO}"
    fi
}

#==============================
# CREAR BANNER INDIVIDUAL
#==============================
generate_banner() {
    local user="$1"
    local title limit expire days
    local channel support promo bot host

    title=$(get_title "$user")
    limit=$(get_limit "$user")
    expire=$(get_expire "$user")
    days=$(get_days_left "$user")

    promo=$(html_escape "$PROMO")
    channel=$(html_escape "$CHANNEL")
    support=$(html_escape "$SUPPORT")
    bot=$(html_escape "$BOT")
    host=$(html_escape "$HOST")
    title=$(html_escape "$title")
    user=$(html_escape "$user")

    if [[ "$limit" == "0" ]]; then
        limit="∞ Ilimitado"
    else
        limit="${limit} IP"
        [[ "${limit% IP}" != "1" ]] && limit="${limit% IP} IPs"
    fi

    cat <<EOF
<html>
<h5 style="text-align:center;">
<font color="#29b6f6">══════════════════════</font>
</h5>

<h5 style="text-align:center;">
<font face="monospace" color="#00ff00">
⠀⠀⢀⣶⡆ KevinTech ⢰⣶⡀⠀⠀<br>
</font>
</h5>

<h1 style="text-align:center;">
<font face="monospace" color="#00ff00"><b>KEVINTECH</b></font>
</h1>

<h5 style="text-align:center;">
<font color="#29b6f6">══════════════════════</font>
</h5>

<h3 style="text-align:center;">
<font color="#FF00FF"><b>⚡ ${title} ⚡</b></font>
</h3>

<h5 style="text-align:center;">
<font color="#29b6f6">══════════════════════</font>
</h5>

<h5 style="text-align:center;">
<font color="#ffffff">👤 Usuario: </font>
<font color="#f1c40f"><b>${user}</b></font><br>

<font color="#ffffff">🌐 Servidor: </font>
<font color="#f1c40f"><b>${host}</b></font><br>

<font color="#ffffff">📅 Vence: </font>
<font color="#f1c40f"><b>${expire}</b></font><br>

<font color="#ffffff">⏳ Días Restant.: </font>
<font color="#f1c40f"><b>${days}</b></font><br>

<font color="#ffffff">💻 Límite: </font>
<font color="#f1c40f"><b>${limit}</b></font>
</h5>

<h5 style="text-align:center;">
<font color="#29b6f6">══════════════════════</font>
</h5>

<h4 style="text-align:center;">
<font color="#FF00FF"><b>${promo}</b></font>
</h4>

<h5 style="text-align:center;">
<font color="#ffffff">📢 Canal: </font>
<font color="#f1c40f"><b>${channel}</b></font><br>

<font color="#ffffff">👤 Soporte: </font>
<font color="#f1c40f"><b>${support}</b></font>
</h5>

<h5 style="text-align:center;">
<font color="#29b6f6">══════════════════════</font>
</h5>

<h5 style="text-align:center;">
<font color="#00e676"><b>✅ CREADO EN: ${bot}</b></font>
</h5>

<h5 style="text-align:center;">
<font color="#29b6f6">══════════════════════</font>
</h5>
</html>
EOF
}

#==============================
# ESCRIBIR BANNER
#==============================
write_user_banner() {
    local user="$1"
    local file="$BANNER_DIR/$user.banner"

    generate_banner "$user" > "$file" || return 1

    chown root:root "$file"
    chmod 0644 "$file"

    return 0
}

#==============================
# BACKUP SSHD CONFIG
#==============================
backup_sshd() {
    local date dir

    date=$(date +"%Y%m%d_%H%M%S")
    dir="$BACKUP_DIR/$date"

    mkdir -p "$dir" || return 1

    if [[ -f "$SSHD_CONFIG" ]]; then
        cp -a "$SSHD_CONFIG" "$dir/sshd_config" || return 1
    fi

    echo "$dir" > "$LATEST_BACKUP"

    printf '%s' "$dir"
}

#==============================
# QUITAR SOLO NUESTRO BLOQUE
#==============================
remove_our_block() {
    local file="$1"
    local content

    content=$(cat "$file") || return 1

    if [[ "$content" == *"$MARKER_START"* ]]; then
        awk -v start="$MARKER_START" -v end="$MARKER_END" '
            $0 == start {inside=1; next}
            $0 == end   {inside=0; next}
            !inside {print}
        ' "$file" > "${file}.tmp" || return 1

        mv "${file}.tmp" "$file" || return 1
    fi
}

#==============================
# CONSTRUIR MATCH USER
#==============================
build_match_blocks() {
    local user banner_file

    printf '%s\n' "$MARKER_START"

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue

        banner_file="$BANNER_DIR/$user.banner"

        if [[ -f "$banner_file" ]]; then
            printf 'Match User %s\n' "$user"
            printf '    Banner %s\n\n' "$banner_file"
        fi
    done < <(get_users)

    printf '%s\n' "$MARKER_END"
}

#==============================
# VALIDAR SSH
#==============================
validate_sshd() {
    if command -v sshd >/dev/null 2>&1; then
        sshd -t >/dev/null 2>&1
        return $?
    fi

    return 1
}

#==============================
# SINCRONIZAR SSHD_CONFIG
#
# IMPORTANTE:
# Solo modifica el bloque entre nuestros marcadores.
# No toca Banner global de otros módulos.
#==============================
sync_sshd() {
    local backup service tmp

    [[ -f "$SSHD_CONFIG" ]] || {
        msg_error "No existe $SSHD_CONFIG."
        return 1
    }

    backup=$(backup_sshd) || {
        msg_error "No se pudo crear backup de sshd_config."
        return 1
    }

    if ! remove_our_block "$SSHD_CONFIG"; then
        msg_error "No se pudo limpiar el bloque anterior."
        return 1
    fi

    tmp="${SSHD_CONFIG}.tmp"

    {
        cat "$SSHD_CONFIG"
        printf '\n'
        build_match_blocks
    } > "$tmp" || {
        rm -f "$tmp"
        msg_error "No se pudo construir sshd_config."
        return 1
    }

    cp -a "$tmp" "$SSHD_CONFIG"
    rm -f "$tmp"

    if ! validate_sshd; then
        msg_error "sshd_config es inválido. Restaurando backup."

        if [[ -f "$backup/sshd_config" ]]; then
            cp -a "$backup/sshd_config" "$SSHD_CONFIG"
        fi

        return 1
    fi

    service=$(ssh_service 2>/dev/null || true)

    if [[ -n "$service" ]]; then
        if systemctl reload "$service" >/dev/null 2>&1; then
            msg_ok "OpenSSH recargado correctamente."
        else
            msg_warn "La configuración es válida, pero no se pudo recargar $service."
        fi
    else
        msg_warn "No se encontró el servicio ssh/sshd."
    fi

    msg_ok "Configuración por usuario sincronizada."
    return 0
}

#==============================
# REFRESCAR TODOS
#==============================
refresh_all() {
    local user count=0

    if [[ ! -s "$LIMITS_FILE" ]]; then
        msg_warn "No hay usuarios en $LIMITS_FILE."
        return 0
    fi

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue

        if write_user_banner "$user"; then
            echo -e "${GREEN}✔ Banner actualizado: ${WHITE}$user${RESET}"
            ((count++))
        else
            msg_error "No se pudo generar el banner de $user."
        fi
    done < <(get_users)

    if (( count > 0 )); then
        msg_ok "$count banner(s) generado(s)."
    else
        msg_warn "No se generaron banners."
    fi
}

#==============================
# CREAR/ACTUALIZAR UNO
#==============================
refresh_one() {
    local user="$1"

    if ! valid_username "$user" || ! id "$user" >/dev/null 2>&1; then
        msg_error "Usuario no válido o inexistente: $user"
        return 1
    fi

    if ! grep -qE "^${user}:" "$LIMITS_FILE" 2>/dev/null; then
        msg_warn "El usuario no aparece en $LIMITS_FILE."
        msg_warn "Se actualizará igualmente su banner."
    fi

    if write_user_banner "$user"; then
        msg_ok "Banner creado/actualizado: $BANNER_DIR/$user.banner"
        return 0
    fi

    msg_error "No se pudo escribir el banner."
    return 1
}

#==============================
# MOSTRAR BANNER
#==============================
view_one() {
    local user="$1"
    local file="$BANNER_DIR/$user.banner"

    if [[ ! -f "$file" ]]; then
        msg_error "No existe: $file"
        return 1
    fi

    clear
    echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}Banner de: ${GREEN}$user${RESET}"
    echo -e "${WHITE}Archivo  : ${GRAY}$file${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"
    echo

    cat "$file"

    echo
    echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"
}

#==============================
# ELIMINAR UNO
#==============================
remove_one() {
    local user="$1"
    local file="$BANNER_DIR/$user.banner"

    if [[ -f "$file" ]]; then
        rm -f "$file"
        msg_ok "Banner eliminado: $file"
    else
        msg_warn "El banner no existe: $file"
    fi
}

#==============================
# LISTAR
#==============================
list_users() {
    local user limit expire days banner

    clear
    echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"
    echo -e "${WHITE}Usuarios KevinTech y sus banners${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"
    echo

    printf "%-18s %-10s %-14s %-10s\n" "USUARIO" "LÍMITE" "EXPIRA" "BANNER"
    printf "%-18s %-10s %-14s %-10s\n" "------------------" "----------" "--------------" "----------"

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue

        limit=$(get_limit "$user")
        expire=$(get_expire "$user")
        days=$(get_days_left "$user")
        banner="NO"

        [[ -f "$BANNER_DIR/$user.banner" ]] && banner="SI"

        printf "%-18s %-10s %-14s %-10s\n" \
            "$user" "$limit" "$expire" "$banner"
    done < <(get_users)

    echo
    pause
}

#==============================
# LIMPIAR BANNERS DE USUARIOS
#==============================
cleanup_old_banners() {
    local file user

    shopt -s nullglob

    for file in "$BANNER_DIR"/*.banner; do
        user=$(basename "$file" .banner)

        if ! id "$user" >/dev/null 2>&1 ||
           ! grep -qE "^${user}:" "$LIMITS_FILE" 2>/dev/null; then
            rm -f "$file"
            echo -e "${YELLOW}⚠ Eliminado banner huérfano: $user${RESET}"
        fi
    done

    shopt -u nullglob
}

#==============================
# INSTALAR / SINCRONIZAR
#==============================
install_system() {
    echo
    msg_ok "Preparando sistema de banners individuales..."

    mkdir -p "$BANNER_DIR"
    chmod 0755 "$BANNER_DIR"

    refresh_all
    cleanup_old_banners

    echo
    msg_info "Sincronizando Match User con OpenSSH..."

    if sync_sshd; then
        msg_ok "Sistema instalado y sincronizado."
    else
        msg_error "No se pudo sincronizar OpenSSH."
        return 1
    fi
}

msg_info() {
    echo -e "${CYAN}➜ $1${RESET}"
}

#==============================
# MENÚ
#==============================
while true; do
    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}        KEVINTECH PER-USER BANNER MANAGER         ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo

    echo -e "${WHITE}Directorio:${RESET} $BANNER_DIR"
    echo -e "${WHITE}Usuarios  :${RESET} $LIMITS_FILE"
    echo

    echo -e "${GREEN}[1]${WHITE} Instalar / sincronizar sistema"
    echo -e "${GREEN}[2]${WHITE} Actualizar todos los banners"
    echo -e "${BLUE}[3]${WHITE} Actualizar un usuario"
    echo -e "${CYAN}[4]${WHITE} Ver banner de un usuario"
    echo -e "${YELLOW}[5]${WHITE} Listar usuarios"
    echo -e "${RED}[6]${WHITE} Eliminar banner de un usuario"
    echo -e "${MAGENTA}[7]${WHITE} Limpiar banners huérfanos"
    echo -e "${GRAY}[0]${WHITE} Salir"
    echo

    read -r -p "Seleccione una opción: " OP

    case "$OP" in
        1)
            install_system
            pause
            ;;
        2)
            refresh_all
            cleanup_old_banners
            sync_sshd
            pause
            ;;
        3)
            read -r -p "Usuario: " USER
            if refresh_one "$USER"; then
                sync_sshd
            fi
            pause
            ;;
        4)
            read -r -p "Usuario: " USER
            view_one "$USER"
            pause
            ;;
        5)
            list_users
            ;;
        6)
            read -r -p "Usuario: " USER
            remove_one "$USER"
            sync_sshd
            pause
            ;;
        7)
            cleanup_old_banners
            sync_sshd
            pause
            ;;
        0)
            exit 0
            ;;
        *)
            msg_error "Opción inválida."
            sleep 1
            ;;
    esac
done
