#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner Manager - SSH / Dropbear
# Version: 5.0
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

BANNER_DIR="/etc/ssh_banners"

LIMITS_FILE="$BASE/limits.conf"

SSHD="/etc/ssh/sshd_config"

DROPBEAR="/etc/default/dropbear"

BACKUP_DIR="$BASE/banner-backups"

mkdir -p "$BASE"
mkdir -p "$BACKUP_DIR"
mkdir -p "$BANNER_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==================================================
# CONFIGURACIÓN DEL BANNER
#==================================================
#
# EDITA SOLAMENTE ESTO
#
#==================================================

BANNER_TITULO="KEVIN TECH TUTORIALS"

BANNER_SERVIDORES="🔥 SERVIDORES PREMIUM 🔥"

BANNER_CANAL="@KevinTech"

BANNER_SOPORTE="@KevinSupport"

BANNER_PRODUCTO="✅ KEVINTECH VPN"

#==================================================
# MARCADORES SSH
#==================================================

MARKER_START="# >>> KEVINTECH USER BANNERS START <<<"
MARKER_END="# >>> KEVINTECH USER BANNERS END <<<"

#==================================================
# ROOT
#==================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"
    exit 1
fi

#==================================================
# FUNCIONES GENERALES
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
# OPENSSH
#==================================================

ssh_installed() {

    [[ -f "$SSHD" ]] &&
    command -v sshd >/dev/null 2>&1
}

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
# DROPBEAR
#==================================================

dropbear_installed() {

    [[ -f "$DROPBEAR" ]]
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

    find "$BANNER_DIR" \
        -maxdepth 1 \
        -type f \
        -name "*.banner" \
        ! -name "default.banner" \
        2>/dev/null |
        wc -l
}

#==================================================
# ESTADO
#==================================================

show_status() {

    echo -e "${CYAN}Estado del sistema${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo -e "Banners usuarios : ${GREEN}$(count_banners)${RESET}"

    echo -e "Directorio       : ${WHITE}$BANNER_DIR${RESET}"

    echo -n "OpenSSH           : "
    service_status

    echo -n "Dropbear          : "
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

        cp -a "$BANNER_DIR" "$DIR/ssh_banners"

    fi

    echo "$DIR" > "$BACKUP_DIR/latest"

    echo -e "${GREEN}✔ Backup creado:${RESET} $DIR"
}

#==================================================
# OBTENER LÍMITE
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

    [[ -z "$LIMIT" ]] && LIMIT="0"

    echo "$LIMIT"
}

#==================================================
# OBTENER EXPIRACIÓN
#==================================================

get_user_expiration() {

    local USERNAME="$1"

    chage -l "$USERNAME" 2>/dev/null |
        awk -F': ' '
            /Account expires/ {
                print $2
                exit
            }
        '
}

#==================================================
# DÍAS RESTANTES
#==================================================

get_user_days() {

    local USERNAME="$1"

    local EXPIRATION
    local EXP_EPOCH
    local NOW_EPOCH
    local DAYS

    EXPIRATION=$(get_user_expiration "$USERNAME")

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

    (( DAYS < 0 )) && DAYS=0

    echo "$DAYS"
}

#==================================================
# FORMATO LÍMITE
#==================================================

format_limit() {

    local LIMIT="$1"

    if [[ -z "$LIMIT" || "$LIMIT" == "0" ]]; then

        echo "∞ Ilimitado"

    else

        echo "$LIMIT"

    fi
}

#==================================================
# GENERAR BANNER INDIVIDUAL
#==================================================

generate_user_banner() {

    local USERNAME="$1"

    local LIMIT
    local DAYS
    local BANNER_FILE
    local TEMP_FILE

    LIMIT=$(get_user_limit "$USERNAME")

    DAYS=$(get_user_days "$USERNAME")

    LIMIT=$(format_limit "$LIMIT")

    BANNER_FILE="$BANNER_DIR/${USERNAME}.banner"

    TEMP_FILE="${BANNER_FILE}.tmp"

    cat > "$TEMP_FILE" <<EOF
══════════════════════
$BANNER_TITULO
══════════════════════

$BANNER_SERVIDORES

📢 Canal: $BANNER_CANAL
👤 Soporte: $BANNER_SOPORTE

══════════════════════

$BANNER_PRODUCTO

══════════════════════

👤 Usuario: $USERNAME
📅 Vence: $DAYS
💻 Límite: $LIMIT

══════════════════════
EOF

    # Reemplazo atómico
    mv -f "$TEMP_FILE" "$BANNER_FILE"

    chmod 644 "$BANNER_FILE"

    echo -e "${GREEN}✔ Banner actualizado:${RESET} $USERNAME"
}

#==================================================
# ACTUALIZAR TODOS LOS BANNERS
#==================================================

refresh_all_banners() {

    if [[ ! -f "$LIMITS_FILE" ]]; then

        echo -e "${YELLOW}⚠ No existe $LIMITS_FILE${RESET}"

        return 1
    fi

    local FOUND=0

    while IFS=: read -r USERNAME LIMIT; do

        [[ -z "$USERNAME" ]] && continue

        [[ "$USERNAME" == \#* ]] && continue

        if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            continue
        fi

        if ! id "$USERNAME" >/dev/null 2>&1; then
            continue
        fi

        generate_user_banner "$USERNAME"

        FOUND=1

    done < "$LIMITS_FILE"

    if (( FOUND == 0 )); then

        echo -e "${YELLOW}⚠ No se encontraron usuarios.${RESET}"

    fi
}

#==================================================
# LIMPIAR BANNERS ANTIGUOS
#==================================================

clean_old_banners() {

    [[ ! -f "$LIMITS_FILE" ]] && return

    shopt -s nullglob

    local FILE
    local USERNAME

    for FILE in "$BANNER_DIR"/*.banner; do

        [[ "$(basename "$FILE")" == "default.banner" ]] && continue

        USERNAME=$(basename "$FILE" .banner)

        if ! grep -q "^${USERNAME}:" "$LIMITS_FILE"; then

            rm -f "$FILE"

            echo -e "${YELLOW}🧹 Banner eliminado:${RESET} $USERNAME"

        fi

    done

    shopt -u nullglob
}

#==================================================
# CONSTRUIR BLOQUE SSH
#==================================================

build_ssh_block() {

    echo "$MARKER_START"
    echo "# KevinTech - Banners individuales"
    echo

    if [[ -f "$LIMITS_FILE" ]]; then

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

    fi

    echo "$MARKER_END"
}

#==================================================
# SINCRONIZAR USUARIOS CON SSH
#==================================================
#
# IMPORTANTE:
#
# Esta función compara la configuración actual
# con los usuarios existentes.
#
# Si NO hay usuarios nuevos:
#     NO recarga SSH.
#
# Si aparece un usuario nuevo:
#     modifica sshd_config
#     valida
#     hace UN reload.
#
#==================================================

sync_ssh_users() {

    if ! ssh_installed; then
        return 0
    fi

    local CURRENT_BLOCK
    local NEW_BLOCK
    local TEMP
    local CURRENT_FILE
    local NEW_FILE

    CURRENT_FILE=$(mktemp)
    NEW_FILE=$(mktemp)
    TEMP=$(mktemp)

    # Extraer nuestro bloque actual
    awk \
        -v START="$MARKER_START" \
        -v END="$MARKER_END" '

        $0 == START {
            INSIDE=1
        }

        INSIDE {
            print
        }

        $0 == END {
            INSIDE=0
        }

    ' "$SSHD" > "$CURRENT_FILE"

    # Construir bloque nuevo
    build_ssh_block > "$NEW_FILE"

    CURRENT_BLOCK=$(cat "$CURRENT_FILE" 2>/dev/null)
    NEW_BLOCK=$(cat "$NEW_FILE" 2>/dev/null)

    #==================================================
    # SI NO CAMBIÓ LA LISTA DE USUARIOS
    #==================================================

    if [[ "$CURRENT_BLOCK" == "$NEW_BLOCK" ]]; then

        rm -f "$CURRENT_FILE" "$NEW_FILE" "$TEMP"

        echo -e "${GRAY}ℹ No hay usuarios nuevos para SSH.${RESET}"

        return 0
    fi

    echo -e "${CYAN}Detectado cambio en usuarios de banners.${RESET}"

    #==================================================
    # ELIMINAR BLOQUE ANTERIOR
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
    # AGREGAR BLOQUE NUEVO
    #==================================================

    {
        cat "$TEMP"

        echo

        cat "$NEW_FILE"

    } > "${TEMP}.new"

    #==================================================
    # VALIDAR
    #==================================================

    if ! sshd -t -f "${TEMP}.new" 2>/tmp/kevintech_sshd_error; then

        echo -e "${RED}✘ Error en sshd_config.${RESET}"
        echo

        cat /tmp/kevintech_sshd_error

        rm -f \
            "$CURRENT_FILE" \
            "$NEW_FILE" \
            "$TEMP" \
            "${TEMP}.new"

        return 1
    fi

    #==================================================
    # BACKUP
    #==================================================

    cp -a "$SSHD" "$SSHD.kevintech.backup"

    #==================================================
    # APLICAR
    #==================================================

    mv "${TEMP}.new" "$SSHD"

    rm -f \
        "$CURRENT_FILE" \
        "$NEW_FILE" \
        "$TEMP"

    echo -e "${GREEN}✔ Configuración SSH actualizada.${RESET}"

    #==================================================
    # RELOAD SOLAMENTE POR CAMBIO DE USUARIOS
    #==================================================

    local SERVICE

    SERVICE=$(get_ssh_service)

    if [[ -n "$SERVICE" ]]; then

        if systemctl reload "$SERVICE" 2>/dev/null; then

            echo -e "${GREEN}✔ OpenSSH recargado por cambio de usuarios.${RESET}"

        else

            echo -e "${RED}✘ No se pudo recargar OpenSSH.${RESET}"

            return 1

        fi

    fi

    return 0
}

#==================================================
# ACTUALIZACIÓN COMPLETA
#==================================================

update_system() {

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}       ACTUALIZANDO SISTEMA DE BANNERS${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    # Primero genera los archivos de todos los usuarios
    refresh_all_banners

    echo

    # Limpia usuarios eliminados
    clean_old_banners

    echo

    # Solo recarga SSH si aparece/desaparece un usuario
    sync_ssh_users

    echo
    echo -e "${GREEN}✔ Actualización terminada.${RESET}"
    echo -e "${GRAY}ℹ Los usuarios existentes no fueron recreados.${RESET}"
    echo -e "${GRAY}ℹ Los banners fueron actualizados individualmente.${RESET}"
    echo
}

#==================================================
# CONFIGURACIÓN INICIAL
#==================================================

install_banner_system() {

    echo
    echo -e "${CYAN}Instalando sistema de banners...${RESET}"
    echo

    create_backup

    refresh_all_banners

    clean_old_banners

    sync_ssh_users

    configure_dropbear

    echo
    echo -e "${GREEN}✔ Sistema configurado correctamente.${RESET}"
    echo
}

#==================================================
# DROPBEAR
#==================================================

configure_dropbear() {

    if ! dropbear_installed; then
        return 0
    fi

    local DEFAULT_BANNER="$BANNER_DIR/default.banner"

    cat > "$DEFAULT_BANNER" <<EOF
══════════════════════
$BANNER_TITULO
══════════════════════

$BANNER_SERVIDORES

📢 Canal: $BANNER_CANAL
👤 Soporte: $BANNER_SOPORTE

══════════════════════

$BANNER_PRODUCTO

══════════════════════

🔥 Bienvenido al servidor 🔥

══════════════════════
EOF

    chmod 644 "$DEFAULT_BANNER"

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
            "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$DEFAULT_BANNER\"|" \
            "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$DEFAULT_BANNER\"" >> "$DROPBEAR"

    fi

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^dropbear.service"; then

        systemctl restart dropbear 2>/dev/null

        if systemctl is-active --quiet dropbear 2>/dev/null; then

            echo -e "${GREEN}✔ Dropbear configurado.${RESET}"

        else

            echo -e "${YELLOW}⚠ Dropbear no está activo.${RESET}"

        fi

    fi
}

#==================================================
# VER BANNERS
#==================================================

view_banner() {

    header

    echo -e "${MAGENTA}              BANNERS DE USUARIOS${RESET}"
    echo

    if [[ ! -d "$BANNER_DIR" ]]; then

        echo -e "${RED}✘ No existe $BANNER_DIR${RESET}"

        pause

        return
    fi

    local FOUND=0
    local FILE
    local USERNAME

    shopt -s nullglob

    for FILE in "$BANNER_DIR"/*.banner; do

        [[ "$(basename "$FILE")" == "default.banner" ]] && continue

        USERNAME=$(basename "$FILE" .banner)

        echo -e "${GREEN}👤 Usuario: $USERNAME${RESET}"
        echo -e "${GRAY}📂 $FILE${RESET}"
        echo

        cat "$FILE"

        echo
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

        FOUND=1

    done

    shopt -u nullglob

    if (( FOUND == 0 )); then

        echo -e "${YELLOW}No existen banners.${RESET}"

    fi

    pause
}

#==================================================
# VER CONFIGURACIÓN
#==================================================

show_configuration() {

    header

    echo -e "${MAGENTA}              CONFIGURACIÓN DEL BANNER${RESET}"
    echo

    echo -e "${WHITE}Título:${RESET}"
    echo "$BANNER_TITULO"

    echo

    echo -e "${WHITE}Servidores:${RESET}"
    echo "$BANNER_SERVIDORES"

    echo

    echo -e "${WHITE}Canal:${RESET}"
    echo "$BANNER_CANAL"

    echo

    echo -e "${WHITE}Soporte:${RESET}"
    echo "$BANNER_SOPORTE"

    echo

    echo -e "${WHITE}Producto:${RESET}"
    echo "$BANNER_PRODUCTO"

    echo

    echo -e "${WHITE}Directorio:${RESET}"
    echo "$BANNER_DIR"

    echo

    pause
}

#==================================================
# PROBAR CONFIGURACIÓN
#==================================================

test_banner() {

    header

    echo -e "${MAGENTA}              PRUEBA DEL SISTEMA${RESET}"
    echo

    echo -e "${CYAN}Configuración:${RESET}"
    echo

    echo "Título     : $BANNER_TITULO"
    echo "Servidores : $BANNER_SERVIDORES"
    echo "Canal      : $BANNER_CANAL"
    echo "Soporte    : $BANNER_SOPORTE"
    echo "Producto   : $BANNER_PRODUCTO"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    echo -e "${WHITE}Banners encontrados:${RESET} $(count_banners)"

    echo

    if ssh_installed; then

        if sshd -t 2>/dev/null; then

            echo -e "${GREEN}✔ sshd_config válido${RESET}"

        else

            echo -e "${RED}✘ sshd_config tiene errores${RESET}"

        fi

        if grep -q "$MARKER_START" "$SSHD"; then

            echo -e "${GREEN}✔ Sistema de banners individuales activo${RESET}"

        else

            echo -e "${YELLOW}⚠ Sistema de banners individuales no configurado${RESET}"

        fi

    else

        echo -e "${GRAY}⚠ OpenSSH no instalado${RESET}"

    fi

    echo

    pause
}

#==================================================
# RESTAURAR BACKUP
#==================================================

restore_backup() {

    header

    echo -e "${MAGENTA}              RESTAURAR BACKUP${RESET}"
    echo

    if [[ ! -f "$BACKUP_DIR/latest" ]]; then

        echo -e "${RED}✘ No existe ningún backup.${RESET}"

        pause

        return
    fi

    local BACKUP

    BACKUP=$(cat "$BACKUP_DIR/latest")

    echo -e "${GREEN}Último backup:${RESET}"
    echo "$BACKUP"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Restaurar? [S/N]: ${RESET}")" \
        RESP

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
# ELIMINAR SISTEMA
#==================================================

delete_banner_system() {

    header

    echo -e "${MAGENTA}          ELIMINAR SISTEMA DE BANNERS${RESET}"
    echo

    echo -e "${YELLOW}Esto NO elimina ningún usuario SSH.${RESET}"
    echo

    read -rp \
        "$(echo -e "${RED}¿Continuar? [S/N]: ${RESET}")" \
        RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            create_backup

            if [[ -f "$SSHD" ]]; then

                local TEMP

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

                    local SERVICE

                    SERVICE=$(get_ssh_service)

                    [[ -n "$SERVICE" ]] &&
                        systemctl reload "$SERVICE"

                else

                    rm -f "$TEMP"

                    echo -e "${RED}✘ Error al limpiar sshd_config.${RESET}"

                fi

            fi

            rm -rf "$BANNER_DIR"

            mkdir -p "$BANNER_DIR"

            echo
            echo -e "${GREEN}✔ Sistema eliminado.${RESET}"
            echo -e "${GREEN}✔ Usuarios SSH conservados.${RESET}"

            ;;

        *)

            echo -e "${YELLOW}Operación cancelada.${RESET}"

            ;;

    esac

    sleep 2
}

#==================================================
# MENÚ
#==================================================

while true; do

    header

    show_status

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo

    echo -e "${GREEN}[1]${WHITE} Configurar / sincronizar usuarios"
    echo -e "${BLUE}[2]${WHITE} Ver banners de usuarios"
    echo -e "${YELLOW}[3]${WHITE} Actualizar todos los banners"
    echo -e "${CYAN}[4]${WHITE} Ver configuración"
    echo -e "${MAGENTA}[5]${WHITE} Probar configuración"
    echo -e "${GRAY}[6]${WHITE} Restaurar último backup"
    echo -e "${RED}[7]${WHITE} Eliminar sistema de banners"
    echo -e "${GRAY}[0]${WHITE} Regresar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" \
        OP

    case "$OP" in

        1)
            create_backup
            install_banner_system
            pause
            ;;

        2)
            view_banner
            ;;

        3)
            update_system
            pause
            ;;

        4)
            show_configuration
            ;;

        5)
            test_banner
            ;;

        6)
            restore_backup
            ;;

        7)
            delete_banner_system
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