#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner Manager - SSH / Dropbear
# Version: 4.0
# Banner individual automático por usuario
#==================================================

#==============================
# COLORES
#==============================

GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==============================
# CONFIGURACIÓN
#==============================

BASE="/etc/kevintech"
CONFIG="$BASE/config.conf"

# Directorio donde se guarda un banner por usuario
BANNER_DIR="/etc/ssh_banners"

# Archivo de límites creado por tu módulo de cuentas SSH
LIMITS_FILE="$BASE/limits.conf"

# OpenSSH
SSHD="/etc/ssh/sshd_config"

# Dropbear
DROPBEAR="/etc/default/dropbear"

# Backups
BACKUP_DIR="$BASE/banner-backups"

mkdir -p "$BASE"
mkdir -p "$BACKUP_DIR"
mkdir -p "$BANNER_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==================================================
# CONFIGURACIÓN DEL BANNER
#==================================================
#
# SOLO CAMBIA ESTOS VALORES
#
# No necesitas volver a crear usuarios.
#
#==================================================

TITULO="KEVIN TECH TUTORIALS"

SERVIDORES="🔥 SERVIDORES PREMIUM 🔥"

CANAL="@KevinTech"

SOPORTE="@KevinSupport"

PRODUCTO="✅ KEVINTECH VPN"

#==================================================
# MARCADORES DE CONFIGURACIÓN SSH
#==================================================

MARKER_START="# >>> KEVINTECH USER BANNERS START <<<"
MARKER_END="# >>> KEVINTECH USER BANNERS END <<<"

#==================================================
# COMPROBAR ROOT
#==================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"
    exit 1
fi

#==================================================
# FUNCIONES
#==================================================

pause() {
    echo
    read -n1 -s -r -p "Presione cualquier tecla para continuar..."
}

header() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}          KEVINTECH BANNER MANAGER                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo
}

#==================================================
# DETECTAR SSH
#==================================================

ssh_installed() {

    [[ -f "$SSHD" ]] || return 1
    command -v sshd >/dev/null 2>&1
}

#==================================================
# DETECTAR DROPBEAR
#==================================================

dropbear_installed() {

    [[ -f "$DROPBEAR" ]] || return 1
}

#==================================================
# OBTENER SERVICIO SSH
#==================================================

get_ssh_service() {

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^ssh.service"; then

        echo "ssh"

    elif systemctl list-unit-files 2>/dev/null |
        grep -q "^sshd.service"; then

        echo "sshd"

    fi
}

#==================================================
# ESTADO SSH
#==================================================

service_status() {

    if ssh_installed; then

        if systemctl is-active --quiet ssh 2>/dev/null ||
           systemctl is-active --quiet sshd 2>/dev/null; then

            echo -e "${GREEN}✔ ACTIVO${RESET}"

        else

            echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

        fi

    else

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

    fi
}

#==================================================
# ESTADO DROPBEAR
#==================================================

dropbear_status() {

    if dropbear_installed; then

        if systemctl is-active --quiet dropbear 2>/dev/null; then

            echo -e "${GREEN}✔ ACTIVO${RESET}"

        else

            echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

        fi

    else

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

    fi
}

#==================================================
# CONTAR BANNERS
#==================================================

count_banners() {

    local COUNT=0

    if [[ -d "$BANNER_DIR" ]]; then

        COUNT=$(find "$BANNER_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.banner" \
            2>/dev/null | wc -l)

    fi

    echo "$COUNT"
}

#==================================================
# ESTADO GENERAL
#==================================================

show_status() {

    echo -e "${CYAN}Estado del sistema${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e "Banner global : ${YELLOW}Desactivado${RESET}"

    echo -e "Banner usuarios : ${GREEN}$(count_banners) archivos${RESET}"

    echo -e "Directorio : ${WHITE}$BANNER_DIR${RESET}"

    echo -n "OpenSSH  : "
    service_status

    echo -n "Dropbear : "
    dropbear_status

    echo
}

#==================================================
# BACKUP
#==================================================

create_backup() {

    local DATE
    DATE=$(date +"%Y%m%d_%H%M%S")

    local DIR="$BACKUP_DIR/$DATE"

    mkdir -p "$DIR"

    [[ -f "$SSHD" ]] &&
        cp -a "$SSHD" "$DIR/sshd_config"

    [[ -f "$DROPBEAR" ]] &&
        cp -a "$DROPBEAR" "$DIR/dropbear"

    if [[ -d "$BANNER_DIR" ]]; then

        cp -a "$BANNER_DIR" "$DIR/ssh_banners" 2>/dev/null

    fi

    echo "$DIR" > "$BACKUP_DIR/latest"

    echo -e "${GREEN}✔ Backup creado:${RESET} $DIR"
}

#==================================================
# OBTENER LÍMITE DEL USUARIO
#==================================================

get_user_limit() {

    local USERNAME="$1"
    local LIMIT

    LIMIT=$(awk -F: -v U="$USERNAME" '
        $1 == U {
            print $2
            exit
        }
    ' "$LIMITS_FILE" 2>/dev/null)

    if [[ -z "$LIMIT" ]]; then
        LIMIT="0"
    fi

    echo "$LIMIT"
}

#==================================================
# OBTENER FECHA DE EXPIRACIÓN
#==================================================

get_user_expiration() {

    local USERNAME="$1"
    local EXPIRATION

    EXPIRATION=$(chage -l "$USERNAME" 2>/dev/null |
        awk -F': ' '/Account expires/ {
            print $2
            exit
        }')

    echo "$EXPIRATION"
}

#==================================================
# CALCULAR DÍAS RESTANTES
#==================================================

get_user_days() {

    local USERNAME="$1"

    local EXPIRATION
    local EXP_EPOCH
    local NOW_EPOCH
    local DAYS

    EXPIRATION=$(get_user_expiration "$USERNAME")

    # Cuenta sin vencimiento
    if [[ -z "$EXPIRATION" ||
          "$EXPIRATION" == "never" ||
          "$EXPIRATION" == "Never" ||
          "$EXPIRATION" == "Nunca" ]]; then

        echo "∞"
        return

    fi

    EXP_EPOCH=$(date -d "$EXPIRATION 23:59:59" +%s 2>/dev/null)

    if [[ -z "$EXP_EPOCH" ]]; then

        echo "0"
        return

    fi

    NOW_EPOCH=$(date +%s)

    DAYS=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))

    if (( DAYS < 0 )); then
        DAYS=0
    fi

    echo "$DAYS"
}

#==================================================
# FORMATO DEL LÍMITE
#==================================================

format_limit() {

    local LIMIT="$1"

    if [[ "$LIMIT" == "0" ||
          "$LIMIT" == "" ]]; then

        echo "∞ Ilimitado"

    else

        echo "$LIMIT"

    fi
}

#==================================================
# CREAR BANNER INDIVIDUAL
#==================================================

generate_user_banner() {

    local USERNAME="$1"

    local LIMIT
    local DAYS
    local BANNER_FILE

    LIMIT=$(get_user_limit "$USERNAME")

    DAYS=$(get_user_days "$USERNAME")

    LIMIT=$(format_limit "$LIMIT")

    BANNER_FILE="$BANNER_DIR/${USERNAME}.banner"

    cat > "$BANNER_FILE" <<EOF
══════════════════════
$TITULO
══════════════════════

$SERVIDORES

📢 Canal: $CANAL
👤 Soporte: $SOPORTE

══════════════════════

$PRODUCTO

══════════════════════

👤 Usuario: $USERNAME
📅 Vence: $DAYS
💻 Límite: $LIMIT

══════════════════════
EOF

    chmod 644 "$BANNER_FILE"

    echo -e "${GREEN}✔ Banner actualizado:${RESET} $USERNAME"

}

#==================================================
# ACTUALIZAR TODOS LOS BANNERS
#==================================================

refresh_all_banners() {

    echo
    echo -e "${CYAN}Actualizando banners de usuarios...${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    if [[ ! -f "$LIMITS_FILE" ]]; then

        echo -e "${YELLOW}⚠ No existe:${RESET} $LIMITS_FILE"
        echo

        return 1

    fi

    local FOUND=0

    while IFS=: read -r USERNAME LIMIT; do

        [[ -z "$USERNAME" ]] && continue

        [[ "$USERNAME" == \#* ]] && continue

        # Validar nombre de usuario
        if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            continue
        fi

        # Comprobar que el usuario existe
        if ! id "$USERNAME" >/dev/null 2>&1; then

            echo -e "${YELLOW}⚠ Usuario no existe:${RESET} $USERNAME"

            continue

        fi

        generate_user_banner "$USERNAME"

        FOUND=1

    done < "$LIMITS_FILE"

    echo

    if (( FOUND == 0 )); then

        echo -e "${YELLOW}⚠ No se encontraron usuarios.${RESET}"

    else

        echo -e "${GREEN}✔ Todos los banners fueron actualizados.${RESET}"

    fi

    echo
    echo -e "${GRAY}ℹ OpenSSH NO fue recargado.${RESET}"
    echo -e "${GRAY}ℹ No se recrearon usuarios.${RESET}"
    echo

}

#==================================================
# ELIMINAR BANNERS DE USUARIOS BORRADOS
#==================================================

clean_old_banners() {

    shopt -s nullglob

    for FILE in "$BANNER_DIR"/*.banner; do

        local USERNAME

        USERNAME=$(basename "$FILE" .banner)

        if ! grep -q "^${USERNAME}:" "$LIMITS_FILE" 2>/dev/null; then

            rm -f "$FILE"

            echo -e "${YELLOW}🧹 Banner eliminado:${RESET} $USERNAME"

        fi

    done

    shopt -u nullglob
}

#==================================================
# CONFIGURAR OPENSSH
#==================================================

configure_ssh() {

    if ! ssh_installed; then

        echo -e "${GRAY}⚠ OpenSSH no está instalado.${RESET}"

        return 0

    fi

    echo
    echo -e "${CYAN}Configurando banners individuales de OpenSSH...${RESET}"
    echo

    local TEMP
    TEMP=$(mktemp)

    #==================================================
    # ELIMINAR SOLAMENTE NUESTRO BLOQUE
    #==================================================

    awk \
        -v START="$MARKER_START" \
        -v END="$MARKER_END" '

        $0 == START {
            SKIP=1
            next
        }

        $0 == END {
            SKIP=0
            next
        }

        !SKIP {
            print
        }

    ' "$SSHD" > "$TEMP"

    #==================================================
    # AGREGAR CONFIGURACIÓN INDIVIDUAL
    #==================================================

    {

        cat "$TEMP"

        echo
        echo "$MARKER_START"
        echo "# KevinTech - Banners individuales"
        echo

        while IFS=: read -r USERNAME LIMIT; do

            [[ -z "$USERNAME" ]] && continue

            [[ "$USERNAME" == \#* ]] && continue

            if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                continue
            fi

            if ! id "$USERNAME" >/dev/null 2>&1; then
                continue
            fi

            echo "Match User $USERNAME"
            echo "    Banner $BANNER_DIR/${USERNAME}.banner"
            echo

        done < "$LIMITS_FILE"

        echo "$MARKER_END"

    } > "${TEMP}.new"

    #==================================================
    # VALIDAR
    #==================================================

    if ! sshd -t -f "${TEMP}.new" 2>/tmp/kevintech_sshd_error; then

        echo -e "${RED}✘ Error en la configuración de OpenSSH.${RESET}"
        echo

        cat /tmp/kevintech_sshd_error

        rm -f "$TEMP" "${TEMP}.new"

        return 1

    fi

    #==================================================
    # BACKUP
    #==================================================

    cp -a "$SSHD" "$SSHD.kevintech.backup"

    #==================================================
    # APLICAR CONFIGURACIÓN
    #==================================================

    mv "${TEMP}.new" "$SSHD"

    rm -f "$TEMP"

    echo
    echo -e "${GREEN}✔ Configuración OpenSSH válida.${RESET}"

    #==================================================
    # RECARGAR SSH SOLAMENTE AQUÍ
    #==================================================

    local SERVICE

    SERVICE=$(get_ssh_service)

    if [[ -n "$SERVICE" ]]; then

        if systemctl reload "$SERVICE" 2>/dev/null; then

            echo -e "${GREEN}✔ OpenSSH recargado correctamente.${RESET}"

        else

            echo -e "${YELLOW}⚠ No se pudo recargar OpenSSH.${RESET}"

        fi

    fi

    return 0
}

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

configure_dropbear() {

    if ! dropbear_installed; then
        return 0
    fi

    echo
    echo -e "${CYAN}Configurando Dropbear...${RESET}"
    echo

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
        "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER_DIR/default.banner\"|" \
        "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$BANNER_DIR/default.banner\"" >> "$DROPBEAR"

    fi

    # Banner padrão do Dropbear
    cat > "$BANNER_DIR/default.banner" <<EOF
══════════════════════
$TITULO
══════════════════════

$SERVIDORES

📢 Canal: $CANAL
👤 Soporte: $SOPORTE

══════════════════════

$PRODUCTO

══════════════════════

🔥 Bienvenido al servidor 🔥

══════════════════════
EOF

    chmod 644 "$BANNER_DIR/default.banner"

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^dropbear.service"; then

        systemctl restart dropbear

        if systemctl is-active --quiet dropbear; then

            echo -e "${GREEN}✔ Dropbear reiniciado correctamente.${RESET}"

        else

            echo -e "${YELLOW}⚠ Dropbear no está activo.${RESET}"

        fi

    fi
}

#==================================================
# APLICAR CONFIGURACIÓN INICIAL
#==================================================

apply_banner() {

    echo
    echo -e "${CYAN}Aplicando configuración inicial...${RESET}"
    echo

    # Crear banners
    refresh_all_banners

    # Configurar asociación SSH
    configure_ssh

    # Configurar Dropbear
    configure_dropbear

    echo
    echo -e "${GREEN}✔ Configuración terminada.${RESET}"
    echo

}

#==================================================
# ACTUALIZAR SOLO CONTENIDO
#==================================================

update_only() {

    echo
    echo -e "${CYAN}Actualizando únicamente el contenido de los banners...${RESET}"
    echo

    refresh_all_banners

    clean_old_banners

    echo
    echo -e "${GREEN}✔ Actualización completada.${RESET}"
    echo -e "${GRAY}ℹ SSH no fue reiniciado.${RESET}"
    echo -e "${GRAY}ℹ SSH no fue recargado.${RESET}"
    echo -e "${GRAY}ℹ Los usuarios no fueron modificados.${RESET}"
    echo

}

#==================================================
# PLANTILLA CLÁSICA
#==================================================

template_classic() {

cat <<EOF
╔════════════════════════════════════════════════════╗
║                 $SERVER                            ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║ $PROMO                                             ║
║                                                    ║
║ 📢 Canal   : $CHANNEL                              ║
║ 👤 Soporte : $SUPPORT                              ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║              Gracias por usar el servicio          ║
╚════════════════════════════════════════════════════╝
EOF

}

#==================================================
# PLANTILLA PREMIUM
#==================================================

template_premium() {

cat <<EOF
╔════════════════════════════════════════════════════╗
║                                                    ║
║                 ★ $SERVER ★                       ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║              $PROMO                               ║
║                                                    ║
║        Telegram : $CHANNEL                         ║
║        Soporte  : $SUPPORT                         ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║              ★ SERVICIO PREMIUM ★                  ║
╚════════════════════════════════════════════════════╝
EOF

}

#==================================================
# PLANTILLA MINIMAL
#==================================================

template_minimal() {

cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                 $SERVER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$PROMO

Canal   : $CHANNEL
Soporte : $SUPPORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

}

#==================================================
# CREAR BANNER
#==================================================

create_banner() {

    header

    echo -e "${MAGENTA}              CREAR NUEVO BANNER${RESET}"
    echo

    echo -e "${GREEN}[1]${WHITE} Usar plantilla global"
    echo -e "${BLUE}[2]${WHITE} Banner personalizado"
    echo -e "${RED}[0]${WHITE} Cancelar"
    echo

    read -rp "$(echo -e "${GREEN}Seleccione:${RESET} ")" TYPE

    case "$TYPE" in

    1)

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}              SELECCIONAR PLANTILLA              ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
        echo

        read -rp "$(echo -e "${GREEN}Nombre del servidor:${RESET} ")" SERVER
        [[ -z "$SERVER" ]] && SERVER="KevinTech VPN"

        read -rp "$(echo -e "${GREEN}Texto promocional:${RESET} ")" PROMO
        [[ -z "$PROMO" ]] && PROMO="🔥 Bienvenido a $SERVER 🔥"

        read -rp "$(echo -e "${GREEN}Canal Telegram:${RESET} ")" CHANNEL
        [[ -z "$CHANNEL" ]] && CHANNEL="@KevinTech"

        read -rp "$(echo -e "${GREEN}Soporte:${RESET} ")" SUPPORT
        [[ -z "$SUPPORT" ]] && SUPPORT="@KevinSupport"

        echo
        echo -e "${GREEN}[1]${WHITE} Clásica"
        echo -e "${BLUE}[2]${WHITE} Premium"
        echo -e "${YELLOW}[3]${WHITE} Minimalista"
        echo -e "${RED}[0]${WHITE} Cancelar"
        echo

        read -rp "$(echo -e "${GREEN}Plantilla:${RESET} ")" TEMPLATE

        case "$TEMPLATE" in

        1)
            create_backup
            template_classic > "$BANNER"
            ;;

        2)
            create_backup
            template_premium > "$BANNER"
            ;;

        3)
            create_backup
            template_minimal > "$BANNER"
            ;;

        0)
            return
            ;;

        *)
            echo -e "${RED}Plantilla inválida.${RESET}"
            sleep 2
            return
            ;;

        esac

        ;;

    2)

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}            BANNER PERSONALIZADO                  ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
        echo

        echo -e "${YELLOW}Se abrirá Nano.${RESET}"
        echo -e "${GRAY}Escribe o pega tu banner personalizado.${RESET}"
        echo

        create_backup

        touch "$BANNER"

        if ! command -v nano >/dev/null 2>&1; then

            echo -e "${RED}✘ Nano no está instalado.${RESET}"
            echo
            echo "Instálalo con:"
            echo "apt install nano -y"

            pause

            return

        fi

        nano "$BANNER"

        ;;

    0)

        return
        ;;

    *)

        echo -e "${RED}Opción inválida.${RESET}"

        sleep 2

        return

        ;;

    esac

    echo
    echo -e "${GREEN}✔ Banner preparado correctamente.${RESET}"

    echo
    echo -e "${CYAN}Vista previa:${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    cat "$BANNER"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo
    read -rp "$(echo -e "${YELLOW}¿Aplicar este banner? [S/N]: ${RESET}")" APPLY

    case "$APPLY" in

    s|S|si|SI|sí|Sí)

        apply_banner

        ;;

    *)

        echo -e "${YELLOW}Banner guardado, pero no aplicado.${RESET}"

        ;;

    esac

    sleep 2
}

#==================================================
# VER BANNER
#==================================================

view_banner() {

    header

    echo -e "${MAGENTA}                 BANNERS DE USUARIOS${RESET}"
    echo

    if [[ ! -d "$BANNER_DIR" ]]; then

        echo -e "${RED}✘ No existe el directorio de banners.${RESET}"

        pause

        return

    fi

    local FOUND=0

    shopt -s nullglob

    for FILE in "$BANNER_DIR"/*.banner; do

        [[ "$(basename "$FILE")" == "default.banner" ]] && continue

        echo -e "${GREEN}Usuario:${RESET} $(basename "$FILE" .banner)"
        echo -e "${GRAY}Archivo:${RESET} $FILE"
        echo
        cat "$FILE"
        echo
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

        FOUND=1

    done

    shopt -u nullglob

    if (( FOUND == 0 )); then

        echo -e "${YELLOW}No existen banners de usuarios.${RESET}"

    fi

    pause
}

#==================================================
# EDITAR CONFIGURACIÓN
#==================================================

edit_banner() {

    header

    echo -e "${MAGENTA}              CONFIGURACIÓN DEL BANNER${RESET}"
    echo

    echo -e "${CYAN}Configuración actual:${RESET}"
    echo

    echo -e "${WHITE}TITULO     :${RESET} $TITULO"
    echo -e "${WHITE}SERVIDORES :${RESET} $SERVIDORES"
    echo -e "${WHITE}CANAL      :${RESET} $CANAL"
    echo -e "${WHITE}SOPORTE    :${RESET} $SOPORTE"
    echo -e "${WHITE}PRODUCTO   :${RESET} $PRODUCTO"

    echo
    echo -e "${YELLOW}La configuración principal está dentro del código.${RESET}"
    echo
    echo "Edita:"
    echo
    echo 'TITULO="..."'
    echo 'SERVIDORES="..."'
    echo 'CANAL="..."'
    echo 'SOPORTE="..."'
    echo 'PRODUCTO="..."'
    echo

    pause
}

#==================================================
# ACTUALIZAR TODOS
#==================================================

update_banners_menu() {

    header

    echo -e "${MAGENTA}          ACTUALIZAR BANNERS DE USUARIOS${RESET}"
    echo

    echo -e "${CYAN}Configuración utilizada:${RESET}"
    echo
    echo -e "🔥 $SERVIDORES"
    echo -e "📢 Canal: $CANAL"
    echo -e "👤 Soporte: $SOPORTE"
    echo -e "📦 $PRODUCTO"
    echo

    read -rp "$(echo -e "${YELLOW}¿Actualizar todos los usuarios? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        update_only

        pause

        ;;

    *)

        echo -e "${YELLOW}Operación cancelada.${RESET}"

        sleep 1

        ;;

    esac
}

#==================================================
# PROBAR
#==================================================

test_banner() {

    header

    echo -e "${MAGENTA}                 PRUEBA DEL BANNER${RESET}"
    echo

    echo -e "${CYAN}Directorio:${RESET}"
    echo "$BANNER_DIR"

    echo

    local COUNT

    COUNT=$(count_banners)

    echo -e "${GREEN}✔ Banners encontrados:${RESET} $COUNT"

    echo

    if ssh_installed; then

        if sshd -t 2>/dev/null; then

            echo -e "${GREEN}✔ Configuración OpenSSH válida${RESET}"

        else

            echo -e "${RED}✘ Configuración OpenSSH inválida${RESET}"

        fi

        if grep -q "$MARKER_START" "$SSHD"; then

            echo -e "${GREEN}✔ Sistema de banners individuales configurado${RESET}"

        else

            echo -e "${YELLOW}⚠ Banners individuales todavía no configurados${RESET}"

        fi

    else

        echo -e "${GRAY}⚠ OpenSSH no instalado${RESET}"

    fi

    if dropbear_installed; then

        if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

            echo -e "${GREEN}✔ Dropbear configurado${RESET}"

        else

            echo -e "${YELLOW}⚠ Dropbear no configurado${RESET}"

        fi

    else

        echo -e "${GRAY}⚠ Dropbear no instalado${RESET}"

    fi

    echo

    echo -e "${CYAN}Configuración actual:${RESET}"
    echo
    echo "Título     : $TITULO"
    echo "Servidores : $SERVIDORES"
    echo "Canal      : $CANAL"
    echo "Soporte    : $SOPORTE"
    echo "Producto   : $PRODUCTO"

    pause
}

#==================================================
# RESTAURAR BACKUP
#==================================================

restore_backup() {

    header

    echo -e "${MAGENTA}                 RESTAURAR BACKUP${RESET}"
    echo

    if [[ ! -f "$BACKUP_DIR/latest" ]]; then

        echo -e "${RED}✘ No existe ningún backup.${RESET}"

        pause

        return

    fi

    BACKUP=$(cat "$BACKUP_DIR/latest")

    echo -e "${GREEN}Último backup:${RESET}"
    echo "$BACKUP"
    echo

    read -rp "$(echo -e "${YELLOW}¿Restaurar este backup? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        if [[ -f "$BACKUP/sshd_config" ]]; then

            cp -a "$BACKUP/sshd_config" "$SSHD"

        fi

        if [[ -f "$BACKUP/dropbear" ]]; then

            cp -a "$BACKUP/dropbear" "$DROPBEAR"

        fi

        if [[ -d "$BACKUP/ssh_banners" ]]; then

            rm -rf "$BANNER_DIR"

            cp -a "$BACKUP/ssh_banners" "$BANNER_DIR"

        fi

        echo
        echo -e "${GREEN}✔ Backup restaurado.${RESET}"

        local SERVICE

        SERVICE=$(get_ssh_service)

        if [[ -n "$SERVICE" ]] &&
           sshd -t 2>/dev/null; then

            systemctl reload "$SERVICE"

            echo -e "${GREEN}✔ OpenSSH recargado.${RESET}"

        fi

        systemctl restart dropbear 2>/dev/null

        ;;

    *)

        echo -e "${YELLOW}Operación cancelada.${RESET}"

        ;;

    esac

    sleep 2
}

#==================================================
# ELIMINAR SISTEMA DE BANNERS
#==================================================

delete_banner() {

    header

    echo -e "${MAGENTA}              ELIMINAR SISTEMA DE BANNERS${RESET}"
    echo

    echo -e "${YELLOW}Esto elimina la configuración de banners individuales.${RESET}"
    echo -e "${YELLOW}NO elimina usuarios SSH.${RESET}"
    echo

    read -rp "$(echo -e "${RED}¿Continuar? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        create_backup

        # Eliminar solamente nuestro bloque
        if [[ -f "$SSHD" ]]; then

            TEMP=$(mktemp)

            awk \
                -v START="$MARKER_START" \
                -v END="$MARKER_END" '

                $0 == START {
                    SKIP=1
                    next
                }

                $0 == END {
                    SKIP=0
                    next
                }

                !SKIP {
                    print
                }

            ' "$SSHD" > "$TEMP"

            if sshd -t -f "$TEMP" 2>/dev/null; then

                mv "$TEMP" "$SSHD"

                SERVICE=$(get_ssh_service)

                if [[ -n "$SERVICE" ]]; then
                    systemctl reload "$SERVICE"
                fi

            else

                rm -f "$TEMP"

                echo -e "${RED}✘ No se pudo modificar sshd_config.${RESET}"

            fi

        fi

        # Eliminar banners
        rm -rf "$BANNER_DIR"

        mkdir -p "$BANNER_DIR"

        echo
        echo -e "${GREEN}✔ Sistema de banners eliminado.${RESET}"
        echo -e "${GREEN}✔ Los usuarios SSH NO fueron eliminados.${RESET}"

        ;;

    *)

        echo -e "${YELLOW}Operación cancelada.${RESET}"

        ;;

    esac

    sleep 2
}

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    header

    show_status

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    echo -e "${GREEN}[1]${WHITE} Configurar Banner Individual"
    echo -e "${BLUE}[2]${WHITE} Ver Banners de Usuarios"
    echo -e "${YELLOW}[3]${WHITE} Actualizar todos los Banners"
    echo -e "${CYAN}[4]${WHITE} Ver configuración"
    echo -e "${MAGENTA}[5]${WHITE} Probar configuración"
    echo -e "${GRAY}[6]${WHITE} Restaurar último Backup"
    echo -e "${RED}[7]${WHITE} Eliminar sistema de Banners"
    echo -e "${GRAY}[0]${WHITE} Regresar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

    1)
        create_backup
        apply_banner
        pause
        ;;

    2)
        view_banner
        ;;

    3)
        update_banners_menu
        ;;

    4)
        edit_banner
        ;;

    5)
        test_banner
        ;;

    6)
        restore_backup
        ;;

    7)
        delete_banner
        ;;

    0)
        break
        ;;

    *)
        echo
        echo -e "${RED}✘ Opción inválida.${RESET}"
        sleep 2
        ;;

    esac

done