#!/bin/bash
#=========================================================
# KevinTech User Banner Manager
# Banner individual por usuario SSH
# Versión: 1.0
#
# NO utiliza /etc/issue.net como banner global.
#
# Cada usuario tendrá:
# /etc/kevintech/user-banners/USUARIO.banner
#
# Y SSH utilizará:
# Match User USUARIO
#     Banner /etc/kevintech/user-banners/USUARIO.banner
#=========================================================

#========================
# COLORES
#========================

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
CYAN='\e[1;96m'
MAGENTA='\e[1;95m'
WHITE='\e[1;97m'
GRAY='\e[1;90m'
RESET='\e[0m'

#========================
# CONFIGURACIÓN
#========================

BASE="/etc/kevintech"
BANNER_DIR="$BASE/user-banners"

SSHD_CONFIG="/etc/ssh/sshd_config"

MARKER_START="# >>> KEVINTECH USER BANNERS START <<<"
MARKER_END="# >>> KEVINTECH USER BANNERS END <<<"

BACKUP_DIR="$BASE/user-banners-backups"

mkdir -p "$BASE"
mkdir -p "$BANNER_DIR"
mkdir -p "$BACKUP_DIR"

chmod 755 "$BANNER_DIR"
chmod 700 "$BACKUP_DIR"

#========================
# ROOT
#========================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Ejecuta este script como root.${RESET}"
    exit 1
fi

#========================
# FUNCIONES
#========================

pause() {
    echo
    read -rp "$(echo -e "${YELLOW}Presiona ENTER para continuar...${RESET}")"
}

msg_ok() {
    echo -e "${GREEN}✔ $1${RESET}"
}

msg_error() {
    echo -e "${RED}✘ $1${RESET}"
}

msg_info() {
    echo -e "${CYAN}➜ $1${RESET}"
}

header() {
    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          KEVINTECH USER BANNER MANAGER              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}             BANNER INDIVIDUAL POR USUARIO           ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo
}

#=========================================================
# VALIDAR NOMBRE DE USUARIO
#=========================================================

validar_usuario() {

    local USERNAME="$1"

    [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]
}

#=========================================================
# BACKUP SSH
#=========================================================

backup_sshd() {

    local DATE
    DATE=$(date +"%Y%m%d_%H%M%S")

    local DIR="$BACKUP_DIR/$DATE"

    mkdir -p "$DIR"

    if [[ -f "$SSHD_CONFIG" ]]; then
        cp -a "$SSHD_CONFIG" "$DIR/sshd_config"
    fi

    echo "$DIR" > "$BACKUP_DIR/latest"

    msg_ok "Backup SSH creado: $DIR"
}

#=========================================================
# CREAR BANNER
#=========================================================

create_user_banner() {

    local USERNAME="$1"
    local TITLE="$2"
    local LIMIT="$3"
    local EXPIRE="$4"

    local FILE="$BANNER_DIR/${USERNAME}.banner"

    [[ -z "$TITLE" ]] && TITLE="INTERNET ILIMITADO"
    [[ -z "$LIMIT" ]] && LIMIT="∞ Ilimitado"
    [[ -z "$EXPIRE" ]] && EXPIRE="Ilimitado"

    cat > "$FILE" <<EOF
<html>

<h5 style="text-align:center;">
<font color="#29b6f6">
══════════════════════
</font>
</h5>

<h5 style="text-align:center;">
<font face="monospace" color="#00ff00">
⠀⠀⢀⣶⡆ KevinTech ⢰⣶⡀⠀⠀
</font>
</h5>

<h1 style="text-align:center;">
<font face="monospace" color="#00ff00">
<b>KEVINTECH</b>
</font>
</h1>

<h5 style="text-align:center;">
<font color="#29b6f6">
══════════════════════
</font>
</h5>

<h3 style="text-align:center;">
<font color="#FF00FF">
<b>⚡ $TITLE ⚡</b>
</font>
</h3>

<h5 style="text-align:center;">

<font color="#ffffff">
👤 Usuario:
</font>

<font color="#f1c40f">
<b>$USERNAME</b>
</font>

<br>

<font color="#ffffff">
📅 Vence:
</font>

<font color="#f1c40f">
<b>$EXPIRE</b>
</font>

<br>

<font color="#ffffff">
💻 Límite:
</font>

<font color="#f1c40f">
<b>$LIMIT</b>
</font>

</h5>

<h5 style="text-align:center;">
<font color="#29b6f6">
══════════════════════
</font>
</h5>

<h4 style="text-align:center;">
<font color="#FF00FF">
<b>🔥 SERVIDORES PREMIUM 🔥</b>
</font>
</h4>

<h5 style="text-align:center;">

<font color="#ffffff">
📢 Canal:
</font>

<a href="https://t.me/">
<font color="#f1c40f">
@KevinTech
</font>
</a>

<br>

<font color="#ffffff">
👤 Soporte:
</font>

<a href="https://t.me/">
<font color="#f1c40f">
@KevinSupport
</font>
</a>

</h5>

<h5 style="text-align:center;">
<font color="#29b6f6">
══════════════════════
</font>
</h5>

<h5 style="text-align:center;">
<font color="#00e676">
<b>✅ KEVINTECH VPN</b>
</font>
</h5>

<h5 style="text-align:center;">
<font color="#29b6f6">
══════════════════════
</font>
</h5>

</html>
EOF

    chmod 644 "$FILE"

    msg_ok "Banner creado: $FILE"
}

#=========================================================
# ELIMINAR BLOQUE ANTERIOR
#=========================================================

remove_managed_block() {

    [[ ! -f "$SSHD_CONFIG" ]] && return 0

    local TMP

    TMP=$(mktemp)

    awk -v start="$MARKER_START" \
        -v end="$MARKER_END" '
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
    ' "$SSHD_CONFIG" > "$TMP"

    cat "$TMP" > "$SSHD_CONFIG"

    rm -f "$TMP"
}

#=========================================================
# VALIDAR CONFIGURACIÓN SSH
#=========================================================

validate_ssh() {

    if sshd -t 2>/dev/null; then
        return 0
    fi

    return 1
}

#=========================================================
# SINCRONIZAR TODOS LOS USUARIOS
#=========================================================

sync_user_banners() {

    [[ ! -f "$SSHD_CONFIG" ]] && {
        msg_error "No existe $SSHD_CONFIG"
        return 1
    }

    msg_info "Creando backup de sshd_config..."

    backup_sshd

    local ORIGINAL

    ORIGINAL=$(mktemp)

    cp -a "$SSHD_CONFIG" "$ORIGINAL"

    # Eliminar solamente nuestro bloque
    remove_managed_block

    echo >> "$SSHD_CONFIG"
    echo "$MARKER_START" >> "$SSHD_CONFIG"
    echo >> "$SSHD_CONFIG"

    local COUNT=0

    for BANNER in "$BANNER_DIR"/*.banner; do

        [[ ! -f "$BANNER" ]] && continue

        local FILE
        FILE=$(basename "$BANNER")

        local USERNAME
        USERNAME="${FILE%.banner}"

        if ! id "$USERNAME" >/dev/null 2>&1; then
            continue
        fi

        echo "Match User $USERNAME" >> "$SSHD_CONFIG"
        echo "    Banner $BANNER" >> "$SSHD_CONFIG"
        echo >> "$SSHD_CONFIG"

        ((COUNT++))

    done

    echo "$MARKER_END" >> "$SSHD_CONFIG"

    # Validar
    if ! validate_ssh; then

        msg_error "La nueva configuración de SSH es inválida."

        cp -a "$ORIGINAL" "$SSHD_CONFIG"

        rm -f "$ORIGINAL"

        msg_error "Configuración anterior restaurada."

        return 1
    fi

    rm -f "$ORIGINAL"

    msg_ok "$COUNT usuario(s) sincronizado(s)."

    # Recargar SSH
    if systemctl reload ssh 2>/dev/null; then
        msg_ok "SSH recargado correctamente."
    elif systemctl reload sshd 2>/dev/null; then
        msg_ok "SSHD recargado correctamente."
    else
        msg_error "No fue posible recargar SSH."
        return 1
    fi

    return 0
}

#=========================================================
# CREAR / ACTUALIZAR USUARIO
#=========================================================

create_banner_for_user() {

    header

    echo -e "${MAGENTA}              BANNER INDIVIDUAL${RESET}"
    echo

    read -rp "Usuario SSH: " USERNAME

    USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

    if ! validar_usuario "$USERNAME"; then
        msg_error "Nombre de usuario inválido."
        pause
        return
    fi

    if ! id "$USERNAME" >/dev/null 2>&1; then
        msg_error "El usuario no existe."
        pause
        return
    fi

    echo

    read -rp "Título: " TITLE
    [[ -z "$TITLE" ]] && TITLE="INTERNET ILIMITADO"

    read -rp "Límite de IP/conexiones: " LIMIT
    [[ -z "$LIMIT" ]] && LIMIT=0

    if [[ "$LIMIT" == "0" ]]; then
        LIMIT="∞ Ilimitado"
    fi

    read -rp "Fecha de expiración [YYYY-MM-DD]: " EXPIRE
    [[ -z "$EXPIRE" ]] && EXPIRE="Ilimitado"

    echo

    backup_sshd

    create_user_banner \
        "$USERNAME" \
        "$TITLE" \
        "$LIMIT" \
        "$EXPIRE"

    echo

    msg_info "Sincronizando configuración SSH..."

    sync_user_banners

    echo

    msg_ok "Banner individual configurado para $USERNAME."

    pause
}

#=========================================================
# VER BANNER
#=========================================================

view_user_banner() {

    header

    read -rp "Usuario SSH: " USERNAME

    local FILE="$BANNER_DIR/${USERNAME}.banner"

    echo

    if [[ ! -f "$FILE" ]]; then
        msg_error "No existe banner para $USERNAME."
        pause
        return
    fi

    echo -e "${CYAN}Archivo:${RESET} $FILE"
    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    cat "$FILE"

    echo

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    pause
}

#=========================================================
# EDITAR BANNER
#=========================================================

edit_user_banner() {

    header

    read -rp "Usuario SSH: " USERNAME

    local FILE="$BANNER_DIR/${USERNAME}.banner"

    if [[ ! -f "$FILE" ]]; then
        msg_error "No existe banner para este usuario."
        pause
        return
    fi

    if ! command -v nano >/dev/null 2>&1; then
        msg_error "Nano no está instalado."
        echo
        echo "Instala con:"
        echo "apt install nano -y"
        pause
        return
    fi

    backup_sshd

    nano "$FILE"

    echo

    read -rp "¿Aplicar cambios? [S/N]: " RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            sync_user_banners
            ;;

        *)
            msg_info "Cambios guardados en el archivo, pero no se sincronizó SSH."
            ;;

    esac

    pause
}

#=========================================================
# ELIMINAR BANNER DE USUARIO
#=========================================================

remove_user_banner() {

    header

    read -rp "Usuario SSH: " USERNAME

    local FILE="$BANNER_DIR/${USERNAME}.banner"

    if [[ ! -f "$FILE" ]]; then
        msg_error "No existe banner para $USERNAME."
        pause
        return
    fi

    echo

    read -rp "¿Eliminar banner de $USERNAME? [S/N]: " RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            backup_sshd

            rm -f "$FILE"

            msg_ok "Archivo del banner eliminado."

            sync_user_banners

            ;;

        *)
            msg_info "Operación cancelada."
            ;;

    esac

    pause
}

#=========================================================
# LISTAR BANNERS
#=========================================================

list_banners() {

    header

    echo -e "${MAGENTA}                  BANNERS INDIVIDUALES${RESET}"
    echo

    local COUNT=0

    for FILE in "$BANNER_DIR"/*.banner; do

        [[ ! -f "$FILE" ]] && continue

        local USERNAME
        USERNAME=$(basename "$FILE" .banner)

        if id "$USERNAME" >/dev/null 2>&1; then
            echo -e "${GREEN}✔${RESET} $USERNAME"
        else
            echo -e "${YELLOW}⚠${RESET} $USERNAME ${GRAY}(usuario no existe)${RESET}"
        fi

        ((COUNT++))

    done

    if (( COUNT == 0 )); then
        echo -e "${GRAY}No hay banners individuales.${RESET}"
    fi

    echo

    echo "Total: $COUNT"

    pause
}

#=========================================================
# SINCRONIZAR
#=========================================================

manual_sync() {

    header

    msg_info "Sincronizando banners individuales..."

    echo

    sync_user_banners

    pause
}

#=========================================================
# RESTAURAR ÚLTIMO BACKUP
#=========================================================

restore_backup() {

    header

    if [[ ! -f "$BACKUP_DIR/latest" ]]; then
        msg_error "No existe ningún backup."
        pause
        return
    fi

    local BACKUP
    BACKUP=$(cat "$BACKUP_DIR/latest")

    if [[ ! -f "$BACKUP/sshd_config" ]]; then
        msg_error "El backup no contiene sshd_config."
        pause
        return
    fi

    echo -e "${YELLOW}Backup:${RESET}"
    echo "$BACKUP"

    echo

    read -rp "¿Restaurar? [S/N]: " RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            cp -a "$BACKUP/sshd_config" "$SSHD_CONFIG"

            if validate_ssh; then

                systemctl reload ssh 2>/dev/null ||
                systemctl reload sshd 2>/dev/null

                msg_ok "Backup restaurado."

            else

                msg_error "El backup restaurado contiene una configuración inválida."

            fi

            ;;

        *)
            msg_info "Operación cancelada."
            ;;

    esac

    pause
}

#=========================================================
# MENÚ
#=========================================================

while true; do

    header

    echo -e "${CYAN}Directorio:${RESET}"
    echo "$BANNER_DIR"

    echo

    echo -e "${GREEN}[1]${WHITE} Crear/actualizar banner de usuario"
    echo -e "${BLUE}[2]${WHITE} Ver banner de usuario"
    echo -e "${YELLOW}[3]${WHITE} Editar banner"
    echo -e "${MAGENTA}[4]${WHITE} Listar banners"
    echo -e "${CYAN}[5]${WHITE} Sincronizar SSH"
    echo -e "${RED}[6]${WHITE} Eliminar banner de usuario"
    echo -e "${GRAY}[7]${WHITE} Restaurar último backup"
    echo -e "${GRAY}[0]${WHITE} Salir"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

    case "$OP" in

        1)
            create_banner_for_user
            ;;

        2)
            view_user_banner
            ;;

        3)
            edit_user_banner
            ;;

        4)
            list_banners
            ;;

        5)
            manual_sync
            ;;

        6)
            remove_user_banner
            ;;

        7)
            restore_backup
            ;;

        0)
            clear
            exit 0
            ;;

        *)
            msg_error "Opción inválida."
            sleep 1
            ;;

    esac

done