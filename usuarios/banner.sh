#!/bin/bash
# ============================================================
# KEVINTECH - BANNER MANAGER
# Banner automático para usuarios SSH
# No recrea usuarios
# No recarga SSH al actualizar contenido
# ============================================================

set -u

# ============================================================
# CONFIGURACIÓN
# ============================================================

BANNER_DIR="/etc/ssh_banners"
LIMITS_FILE="/etc/kevintech/limits.conf"
SSHD_CONFIG="/etc/ssh/sshd_config"

# ============================================================
# CONFIGURA AQUÍ EL CONTENIDO DEL BANNER
# ============================================================

TITULO="KEVIN TECH TUTORIALS"

SERVIDORES="🔥 SERVIDORES PREMIUM 🔥"

CANAL="@KevinTech"

SOPORTE="@KevinSupport"

PRODUCTO="✅ KEVINTECH VPN"

# ============================================================
# MARCADORES DEL BLOQUE SSH
# ============================================================

MARKER_START="# >>> KEVINTECH USER BANNERS START <<<"
MARKER_END="# >>> KEVINTECH USER BANNERS END <<<"

# ============================================================
# COMPROBAR ROOT
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo "❌ Ejecuta este script como root."
    exit 1
fi

# ============================================================
# CREAR DIRECTORIOS
# ============================================================

mkdir -p "$BANNER_DIR"
mkdir -p "/etc/kevintech"

touch "$LIMITS_FILE"

chmod 755 "$BANNER_DIR"
chmod 600 "$LIMITS_FILE"

# ============================================================
# OBTENER LÍMITE DEL USUARIO
# ============================================================

get_user_limit() {
    local username="$1"
    local limit

    limit=$(awk -F: -v u="$username" '
        $1 == u {
            print $2
            exit
        }
    ' "$LIMITS_FILE" 2>/dev/null)

    if [[ -z "$limit" ]]; then
        limit="0"
    fi

    echo "$limit"
}

# ============================================================
# OBTENER FECHA DE EXPIRACIÓN
# ============================================================

get_expiration() {
    local username="$1"
    local expiration

    expiration=$(chage -l "$username" 2>/dev/null |
        awk -F': ' '/Account expires/ {
            print $2
            exit
        }')

    echo "$expiration"
}

# ============================================================
# CALCULAR DÍAS RESTANTES
# ============================================================

get_days_left() {
    local username="$1"
    local expiration="$2"

    if [[ -z "$expiration" ||
          "$expiration" == "never" ||
          "$expiration" == "Never" ||
          "$expiration" == "Nunca" ]]; then
        echo "∞"
        return
    fi

    local exp_epoch
    local now_epoch
    local days

    exp_epoch=$(date -d "$expiration 23:59:59" +%s 2>/dev/null)
    now_epoch=$(date +%s)

    if [[ -z "$exp_epoch" ]]; then
        echo "0"
        return
    fi

    days=$(( (exp_epoch - now_epoch) / 86400 ))

    if (( days < 0 )); then
        days=0
    fi

    echo "$days"
}

# ============================================================
# CREAR / ACTUALIZAR BANNER DE UN USUARIO
# ============================================================

update_user_banner() {

    local username="$1"

    # Comprobar que el usuario existe
    if ! id "$username" >/dev/null 2>&1; then
        return
    fi

    local expiration
    local days
    local limit
    local banner

    expiration=$(get_expiration "$username")
    days=$(get_days_left "$username" "$expiration")
    limit=$(get_user_limit "$username")

    if [[ "$limit" == "0" ]]; then
        limit="∞ Ilimitado"
    fi

    banner="$BANNER_DIR/${username}.banner"

    cat > "$banner" <<EOF
══════════════════════
$TITULO
══════════════════════

$SERVIDORES

📢 Canal: $CANAL
👤 Soporte: $SOPORTE

══════════════════════

$PRODUCTO

══════════════════════

👤 Usuario: $username
📅 Vence: $days
💻 Límite: $limit

══════════════════════
EOF

    chmod 644 "$banner"

    echo "✅ Banner actualizado: $username"
}

# ============================================================
# ACTUALIZAR TODOS LOS USUARIOS
# ============================================================

update_all_banners() {

    echo
    echo "════════════════════════════════════"
    echo "      KEVINTECH BANNER MANAGER"
    echo "════════════════════════════════════"
    echo
    echo "📂 Usuarios: $LIMITS_FILE"
    echo "📂 Banners : $BANNER_DIR"
    echo

    local found=0

    while IFS=: read -r username limit; do

        # Ignorar líneas vacías
        [[ -z "$username" ]] && continue

        # Ignorar comentarios
        [[ "$username" == \#* ]] && continue

        # Validar nombre de usuario
        if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            continue
        fi

        if id "$username" >/dev/null 2>&1; then
            update_user_banner "$username"
            found=1
        fi

    done < "$LIMITS_FILE"

    if (( found == 0 )); then
        echo "⚠️ No se encontraron usuarios en $LIMITS_FILE"
    fi

    echo
    echo "✅ Todos los banners fueron actualizados."
    echo "ℹ️ SSH NO fue recargado."
    echo
}

# ============================================================
# CONFIGURAR MATCH USER EN SSH
# SOLO SE EJECUTA CUANDO SE USA install
# ============================================================

configure_ssh_banners() {

    echo
    echo "🔧 Configurando asociación de banners en SSH..."
    echo

    local temp_config
    temp_config=$(mktemp)

    # Eliminar únicamente nuestro bloque anterior
    awk -v start="$MARKER_START" -v end="$MARKER_END" '
        $0 == start {
            skip=1
            next
        }

        $0 == end {
            skip=0
            next
        }

        !skip {
            print
        }
    ' "$SSHD_CONFIG" > "$temp_config"

    # Agregar nuevo bloque
    {
        cat "$temp_config"

        echo
        echo "$MARKER_START"

        while IFS=: read -r username limit; do

            [[ -z "$username" ]] && continue
            [[ "$username" == \#* ]] && continue

            if ! id "$username" >/dev/null 2>&1; then
                continue
            fi

            # Validación de seguridad del nombre
            if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                continue
            fi

            echo "Match User $username"
            echo "    Banner $BANNER_DIR/${username}.banner"
            echo

        done < "$LIMITS_FILE"

        echo "$MARKER_END"

    } > "${temp_config}.new"

    # Validar configuración antes de reemplazar
    if sshd -t -f "${temp_config}.new" 2>/tmp/kevintech_sshd_error; then

        cp "$SSHD_CONFIG" "$SSHD_CONFIG.kevintech.backup"

        mv "${temp_config}.new" "$SSHD_CONFIG"

        rm -f "$temp_config"

        echo "✅ Configuración SSH válida."

        # Solo aquí se recarga SSH.
        # Esto ocurre durante la instalación/configuración,
        # NO durante las actualizaciones normales del banner.

        if systemctl reload ssh 2>/dev/null; then
            echo "✅ SSH recargado correctamente."
        elif systemctl reload sshd 2>/dev/null; then
            echo "✅ SSHD recargado correctamente."
        else
            echo "⚠️ No se pudo recargar SSH automáticamente."
        fi

    else

        echo "❌ Error en sshd_config."
        echo
        cat /tmp/kevintech_sshd_error
        echo

        rm -f "$temp_config" "${temp_config}.new"

        exit 1
    fi
}

# ============================================================
# ELIMINAR BANNERS DE USUARIOS QUE YA NO EXISTEN
# ============================================================

clean_old_banners() {

    shopt -s nullglob

    for banner in "$BANNER_DIR"/*.banner; do

        local username
        username=$(basename "$banner" .banner)

        if ! grep -q "^${username}:" "$LIMITS_FILE"; then
            rm -f "$banner"
            echo "🧹 Banner eliminado: $username"
        fi

    done

    shopt -u nullglob
}

# ============================================================
# INSTALACIÓN INICIAL
# ============================================================

install_system() {

    echo
    echo "========================================"
    echo "   INSTALANDO KEVINTECH BANNER SYSTEM"
    echo "========================================"
    echo

    update_all_banners

    configure_ssh_banners

    echo
    echo "✅ Sistema de banners configurado."
    echo
}

# ============================================================
# ACTUALIZAR SOLAMENTE LOS BANNERS
# ============================================================

refresh() {

    clean_old_banners

    update_all_banners
}

# ============================================================
# MENÚ
# ============================================================

case "${1:-refresh}" in

    install)
        install_system
        ;;

    refresh)
        refresh
        ;;

    update)
        refresh
        ;;

    *)
        echo
        echo "Uso:"
        echo
        echo "  $0 install   → Configurar SSH por primera vez"
        echo "  $0 refresh   → Actualizar solamente banners"
        echo "  $0 update    → Actualizar solamente banners"
        echo
        ;;
esac