#!/bin/bash

# =========================================================
# DEPWISE USER BANNER SYSTEM
# Conversión independiente de Go → Bash
# =========================================================

BANNER_DIR="/etc/ssh_banners"
SSHD_CONFIG="/etc/ssh/sshd_config"
CONFIG_FILE="$BANNER_DIR/config.conf"

MARKER_START="# >>> DEPWISE_USER_BANNERS_START <<<"
MARKER_END="# >>> DEPWISE_USER_BANNERS_END <<<"

mkdir -p "$BANNER_DIR"
chmod 755 "$BANNER_DIR"

# =========================================================
# CONFIGURACIÓN
# =========================================================

PROMO_TEXT="🔥 ¡SERVIDORES PREMIUM! 🔥"
PROMO_CHANNEL="@vpn_privanox"
PROMO_SUPPORT="@KTTOFICIAL"
PROMO_BOT="@sshprivanoxbot"

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# =========================================================
# ESCAPAR HTML
# =========================================================

html_escape() {
    local text="$1"

    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    text="${text//\"/&quot;}"

    printf '%s' "$text"
}

# =========================================================
# GENERAR BANNER
# =========================================================

generate_user_banner() {

    local username="$1"
    local title="$2"
    local limit="$3"
    local expire_date="$4"

    [[ -z "$title" ]] &&
        title="INTERNET ILIMITADO"

    [[ -z "$PROMO_TEXT" ]] &&
        PROMO_TEXT="🔥 ¡SERVIDORES PREMIUM! 🔥"

    [[ -z "$PROMO_CHANNEL" ]] &&
        PROMO_CHANNEL="@vpn_privanox"

    [[ -z "$PROMO_SUPPORT" ]] &&
        PROMO_SUPPORT="@KTTOFICIAL"

    [[ -z "$PROMO_BOT" ]] &&
        PROMO_BOT="@sshprivanoxbot"

    # -----------------------------------------------------
    # ESCAPAR DATOS
    # -----------------------------------------------------

    username=$(html_escape "$username")
    title=$(html_escape "$title")
    expire_date=$(html_escape "$expire_date")
    PROMO_TEXT=$(html_escape "$PROMO_TEXT")
    PROMO_CHANNEL=$(html_escape "$PROMO_CHANNEL")
    PROMO_SUPPORT=$(html_escape "$PROMO_SUPPORT")
    PROMO_BOT=$(html_escape "$PROMO_BOT")

    # -----------------------------------------------------
    # DÍAS RESTANTES
    # -----------------------------------------------------

    local days_left=0
    local expiration_timestamp
    local now_timestamp

    expiration_timestamp=$(date -d "$expire_date 23:59:59" +%s 2>/dev/null)
    now_timestamp=$(date +%s)

    if [[ -n "$expiration_timestamp" ]]; then

        days_left=$(
            awk -v exp="$expiration_timestamp" \
                -v now="$now_timestamp" \
                'BEGIN {
                    diff=(exp-now)/86400
                    if (diff < 0)
                        print 0
                    else
                        print int(diff+0.999999)
                }'
        )

    else

        days_left=0

    fi

    # -----------------------------------------------------
    # LÍMITE
    # -----------------------------------------------------

    local limit_str

    if [[ "$limit" =~ ^[0-9]+$ ]] &&
       (( limit > 0 )); then

        limit_str="$limit"

    else

        limit_str="∞ Ilimitado"

    fi

    # -----------------------------------------------------
    # TELEGRAM
    # -----------------------------------------------------

    local channel_name
    local support_name

    channel_name="${PROMO_CHANNEL#@}"
    support_name="${PROMO_SUPPORT#@}"

    cat <<EOF
<html>

<h5 style="text-align:center;">
<font color='#29b6f6'>══════════════════════</font>
</h5>

<h5 style="text-align:center;">
<font face="monospace" color="#00ff00">
⠀⠀⢀⣶⡆kevin tech tutorials⢰⣶⡀⠀⠀<br>
</font>
</h5>

<h1 style="text-align:center;">
<font face="monospace" color="#00ff00">
<b>DEPWISE</b>
</font>
</h1>

<h5 style="text-align:center;">
<font color='#29b6f6'>══════════════════════</font>
</h5>

<h3 style="text-align:center;">
<font color='#FF00FF'>
<b>⚡ ${title} ⚡</b>
</font>
</h3>

<h5 style="text-align:center;">
<font color='#29b6f6'>══════════════════════</font>
</h5>

<h5 style="text-align:center;">

<font color='#ffffff'>👤 Usuario: </font>
<font color='#f1c40f'><b>${username}</b></font>
<br>

<font color='#ffffff'>📅 Vence: </font>
<font color='#f1c40f'><b>${expire_date}</b></font>
<br>

<font color='#ffffff'>⏳ Días Restant.: </font>
<font color='#f1c40f'><b>${days_left}</b></font>
<br>

<font color='#ffffff'>💻 Límite: </font>
<font color='#f1c40f'><b>${limit_str}</b></font>

</h5>

<h5 style="text-align:center;">
<font color='#29b6f6'>══════════════════════</font>
</h5>

<h4 style="text-align:center;">
<font color='#FF00FF'>
<b>${PROMO_TEXT}</b>
</font>
</h4>

<h5 style="text-align:center;">

<font color='#ffffff'>📢 Canal: </font>
<a href="https://t.me/${channel_name}">
<font color='#f1c40f'>${PROMO_CHANNEL}</font>
</a>
<br>

<font color='#ffffff'>👤 Soporte: </font>
<a href="https://t.me/${support_name}">
<font color='#f1c40f'>${PROMO_SUPPORT}</font>
</a>

</h5>

<h5 style="text-align:center;">
<font color='#29b6f6'>══════════════════════</font>
</h5>

<h5 style="text-align:center;">
<font color='#00e676'>
<b>✅ CREADO EN : ${PROMO_BOT}</b>
</font>
</h5>

<h5 style="text-align:center;">
<font color='#29b6f6'>══════════════════════</font>
</h5>

</html>
EOF
}

# =========================================================
# CREAR BANNER DE USUARIO
# =========================================================

write_user_banner() {

    local username="$1"
    local title="$2"
    local limit="$3"
    local expire_date="$4"

    [[ -z "$username" ]] && return 1

    local banner_file="$BANNER_DIR/${username}.banner"

    generate_user_banner \
        "$username" \
        "$title" \
        "$limit" \
        "$expire_date" \
        > "$banner_file"

    chmod 644 "$banner_file"

    echo "Banner creado: $banner_file"
}

# =========================================================
# ELIMINAR BANNER
# =========================================================

remove_user_banner() {

    local username="$1"

    [[ -z "$username" ]] && return 1

    rm -f "$BANNER_DIR/${username}.banner"

    echo "Banner eliminado: $username"
}

# =========================================================
# OBTENER LÍMITES
# =========================================================

get_all_user_max_logins() {

    [[ ! -f /etc/security/limits.conf ]] && return

    awk '
        /^[[:space:]]*#/ { next }
        NF < 4 { next }

        $2 == "hard" &&
        $3 == "maxlogins" {

            print $1 ":" $4
        }

    ' /etc/security/limits.conf
}

# =========================================================
# OBTENER LÍMITE DE UN USUARIO
# =========================================================

get_user_limit() {

    local username="$1"

    local limit

    limit=$(
        awk -v user="$username" '
            $1 == user &&
            $2 == "hard" &&
            $3 == "maxlogins" {

                print $4
                exit
            }
        ' /etc/security/limits.conf
    )

    [[ "$limit" =~ ^[0-9]+$ ]] &&
        printf '%s' "$limit" ||
        printf '0'
}

# =========================================================
# OBTENER FECHA DE EXPIRACIÓN
# =========================================================

get_user_expiration() {

    local username="$1"

    local expiration

    expiration=$(
        chage -l "$username" 2>/dev/null |
        awk -F': ' '
            /Account expires/ {
                print $2
                exit
            }
        '
    )

    if [[ -z "$expiration" ||
          "$expiration" == "never" ||
          "$expiration" == "Nunca" ]]; then

        printf '%s' "Ilimitada"

        return

    fi

    date -d "$expiration" +"%Y-%m-%d" 2>/dev/null ||
        printf '%s' "$expiration"
}

# =========================================================
# OBTENER USUARIOS SSH
# =========================================================

get_ssh_users() {

    awk -F: '
        $3 >= 1000 &&
        $1 != "nobody" {

            print $1
        }
    ' /etc/passwd
}

# =========================================================
# SINCRONIZAR SSHD_CONFIG
# =========================================================

sync_sshd_banners() {

    [[ ! -f "$SSHD_CONFIG" ]] && {
        echo "ERROR: no existe $SSHD_CONFIG"
        return 1
    }

    local temp

    temp=$(mktemp) || return 1

    # -----------------------------------------------------
    # ELIMINAR BLOQUE DEPWISE ANTERIOR
    # -----------------------------------------------------

    awk -v start="$MARKER_START" \
        -v end="$MARKER_END" '

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

    ' "$SSHD_CONFIG" > "$temp"

    # -----------------------------------------------------
    # AGREGAR NUEVO BLOQUE
    # -----------------------------------------------------

    {
        echo
        echo "$MARKER_START"

        find "$BANNER_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.banner" \
            -print |
        sort |
        while read -r banner_file; do

            username=$(basename "$banner_file" .banner)

            [[ "$username" =~ ^[a-zA-Z0-9_-]+$ ]] || continue

            echo "Match User $username"
            echo "    Banner $banner_file"
            echo

        done

        echo "$MARKER_END"

    } >> "$temp"

    # -----------------------------------------------------
    # VALIDAR SSH ANTES DE REEMPLAZAR
    # -----------------------------------------------------

    if sshd -t -f "$temp" >/dev/null 2>&1; then

        cp "$temp" "$SSHD_CONFIG"

        rm -f "$temp"

        echo "Configuración SSH válida."

    else

        echo "ERROR: sshd_config generado no es válido."

        rm -f "$temp"

        return 1
    fi

    # -----------------------------------------------------
    # RECARGAR SSH
    # -----------------------------------------------------

    if systemctl reload ssh 2>/dev/null; then

        echo "SSH recargado correctamente."

    elif systemctl reload sshd 2>/dev/null; then

        echo "SSHD recargado correctamente."

    else

        echo "ADVERTENCIA: no se pudo recargar SSH."

    fi
}

# =========================================================
# REFRESCAR TODOS LOS BANNERS
# =========================================================

refresh_all_banners() {

    mkdir -p "$BANNER_DIR"

    declare -A USERS_FOUND

    while IFS=: read -r username _ uid _ _ _ shell; do

        [[ "$uid" =~ ^[0-9]+$ ]] || continue

        (( uid >= 1000 )) || continue

        [[ "$username" == "nobody" ]] && continue

        USERS_FOUND["$username"]=1

    done < /etc/passwd

    while read -r username; do

        [[ -z "$username" ]] && continue

        USERS_FOUND["$username"]=1

    done < <(
        find "$BANNER_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.banner" |
        sed 's|.*/||;s/\.banner$//'
    )

    for username in "${!USERS_FOUND[@]}"; do

        id "$username" >/dev/null 2>&1 || continue

        local limit
        local expiration
        local title

        limit=$(get_user_limit "$username")
        expiration=$(get_user_expiration "$username")

        title=""

        if [[ -f "$BANNER_DIR/${username}.title" ]]; then
            title=$(cat "$BANNER_DIR/${username}.title")
        fi

        write_user_banner \
            "$username" \
            "$title" \
            "$limit" \
            "$expiration" \
            >/dev/null

    done

    echo "Banners actualizados."

    sync_sshd_banners
}

# =========================================================
# CREAR TÍTULO PERSONALIZADO
# =========================================================

set_user_title() {

    local username="$1"
    local title="$2"

    [[ -z "$username" ]] && return 1

    printf '%s\n' "$title" \
        > "$BANNER_DIR/${username}.title"

    echo "Título actualizado."

    local limit
    local expiration

    limit=$(get_user_limit "$username")
    expiration=$(get_user_expiration "$username")

    write_user_banner \
        "$username" \
        "$title" \
        "$limit" \
        "$expiration"

    sync_sshd_banners
}

# =========================================================
# MOSTRAR BANNER
# =========================================================

show_user_banner() {

    local username="$1"

    if [[ -f "$BANNER_DIR/${username}.banner" ]]; then

        cat "$BANNER_DIR/${username}.banner"

    else

        echo "Banner no encontrado."

        return 1
    fi
}

# =========================================================
# AYUDA
# =========================================================

usage() {

    cat <<EOF

DEPWISE USER BANNER SYSTEM

Uso:

  $0 create USUARIO [TITULO]
  $0 remove USUARIO
  $0 title USUARIO "TITULO"
  $0 refresh
  $0 sync
  $0 show USUARIO
  $0 list

Ejemplos:

  $0 create kevin
  $0 create kevin "INTERNET ILIMITADO"
  $0 title kevin "SERVIDOR PREMIUM"
  $0 remove kevin
  $0 refresh
  $0 sync
  $0 show kevin
  $0 list

EOF
}

# =========================================================
# LISTAR BANNERS
# =========================================================

list_banners() {

    echo
    echo "════════════════ DEPWISE BANNERS ════════════════"
    echo

    shopt -s nullglob

    local files=(
        "$BANNER_DIR"/*.banner
    )

    if (( ${#files[@]} == 0 )); then

        echo "No hay banners."

        return
    fi

    for file in "${files[@]}"; do

        basename "$file" .banner

    done

    echo
}

# =========================================================
# PROGRAMA PRINCIPAL
# =========================================================

case "$1" in

    create)

        USERNAME="$2"
        TITLE="$3"

        if [[ -z "$USERNAME" ]]; then

            echo "Falta usuario."

            usage

            exit 1
        fi

        if ! id "$USERNAME" >/dev/null 2>&1; then

            echo "El usuario no existe."

            exit 1
        fi

        LIMIT=$(get_user_limit "$USERNAME")
        EXPIRATION=$(get_user_expiration "$USERNAME")

        write_user_banner \
            "$USERNAME" \
            "$TITLE" \
            "$LIMIT" \
            "$EXPIRATION"

        sync_sshd_banners
        ;;

    remove)

        USERNAME="$2"

        remove_user_banner "$USERNAME"

        rm -f "$BANNER_DIR/${USERNAME}.title"

        sync_sshd_banners
        ;;

    title)

        USERNAME="$2"
        TITLE="$3"

        set_user_title \
            "$USERNAME" \
            "$TITLE"
        ;;

    refresh)

        refresh_all_banners
        ;;

    sync)

        sync_sshd_banners
        ;;

    show)

        show_user_banner "$2"
        ;;

    list)

        list_banners
        ;;

    *)

        usage
        ;;

esac