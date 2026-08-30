#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner Manager SSH / Dropbear
# Versión mejorada
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

BANNER="/etc/issue.net"
SSHD_CONFIG="/etc/ssh/sshd_config"
DROPBEAR_CONFIG="/etc/default/dropbear"

BACKUP_DIR="$BASE/backups/banner"
DATE_NOW="$(date '+%Y%m%d_%H%M%S')"

mkdir -p "$BACKUP_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==============================
# COMPROBAR ROOT
#==============================

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar este script como root.${RESET}"
    exit 1
fi

#==============================
# FUNCIONES
#==============================

pause() {
    echo
    read -n1 -s -r -p "Presione cualquier tecla para continuar..."
}

header() {
    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             KEVINTECH BANNER MANAGER              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${RESET}"
}

service_exists() {
    systemctl list-unit-files 2>/dev/null | grep -q "^$1.service"
}

service_active() {
    systemctl is-active --quiet "$1"
}

show_status() {

    local SSH_STATUS="${RED}✘ INACTIVO${RESET}"
    local DROP_STATUS="${RED}✘ INACTIVO${RESET}"

    if service_active ssh || service_active sshd; then
        SSH_STATUS="${GREEN}✔ ACTIVO${RESET}"
    fi

    if service_active dropbear; then
        DROP_STATUS="${GREEN}✔ ACTIVO${RESET}"
    fi

    local BANNER_STATUS="${RED}✘ NO EXISTE${RESET}"

    if [[ -f "$BANNER" ]]; then
        BANNER_STATUS="${GREEN}✔ ACTIVO${RESET}"
    fi

    echo -e "${WHITE}║${RESET} Banner  : $BANNER_STATUS"
    echo -e "${WHITE}║${RESET} SSH     : $SSH_STATUS"
    echo -e "${WHITE}║${RESET} Dropbear: $DROP_STATUS"
    echo -e "${WHITE}║${RESET} Archivo : ${GRAY}$BANNER${RESET}"

    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
}

#==============================
# BACKUP
#==============================

backup_file() {

    local FILE="$1"

    [[ ! -f "$FILE" ]] && return

    local NAME
    NAME="$(basename "$FILE")"

    cp -a "$FILE" "$BACKUP_DIR/${NAME}_${DATE_NOW}.bak"

    echo -e "${GREEN}✔ Backup creado:${RESET}"
    echo -e "${GRAY}$BACKUP_DIR/${NAME}_${DATE_NOW}.bak${RESET}"
}

#==============================
# CONFIGURAR OPENSSH
#==============================

configure_ssh() {

    if [[ ! -f "$SSHD_CONFIG" ]]; then
        echo -e "${YELLOW}⚠ OpenSSH no está instalado.${RESET}"
        return 1
    fi

    backup_file "$SSHD_CONFIG"

    if grep -qE '^[[:space:]]*Banner[[:space:]]+' "$SSHD_CONFIG"; then
        sed -i -E "s|^[[:space:]]*Banner[[:space:]]+.*$|Banner $BANNER|" "$SSHD_CONFIG"
    else
        echo "Banner $BANNER" >> "$SSHD_CONFIG"
    fi

    if command -v sshd >/dev/null 2>&1; then

        if sshd -t 2>/dev/null; then
            echo -e "${GREEN}✔ Configuración SSH válida.${RESET}"
        else
            echo -e "${RED}❌ Error en la configuración SSH.${RESET}"
            echo -e "${YELLOW}⚠ No se reiniciará SSH.${RESET}"
            return 1
        fi

    fi

    return 0
}

#==============================
# CONFIGURAR DROPBEAR
#==============================

configure_dropbear() {

    if [[ ! -f "$DROPBEAR_CONFIG" ]]; then
        echo -e "${YELLOW}⚠ Dropbear no está instalado/configurado.${RESET}"
        return 0
    fi

    backup_file "$DROPBEAR_CONFIG"

    if grep -q '^DROPBEAR_BANNER=' "$DROPBEAR_CONFIG"; then

        sed -i \
        "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" \
        "$DROPBEAR_CONFIG"

    else

        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR_CONFIG"

    fi

    echo -e "${GREEN}✔ Dropbear configurado.${RESET}"

    return 0
}

#==============================
# REINICIAR SERVICIOS
#==============================

restart_services() {

    echo

    # SSH

    if service_exists ssh; then

        echo -e "${CYAN}Reiniciando SSH...${RESET}"

        if systemctl restart ssh 2>/dev/null; then
            echo -e "${GREEN}✔ SSH reiniciado correctamente.${RESET}"
        else
            echo -e "${RED}❌ No se pudo reiniciar SSH.${RESET}"
        fi

    elif service_exists sshd; then

        echo -e "${CYAN}Reiniciando SSHD...${RESET}"

        if systemctl restart sshd 2>/dev/null; then
            echo -e "${GREEN}✔ SSHD reiniciado correctamente.${RESET}"
        else
            echo -e "${RED}❌ No se pudo reiniciar SSHD.${RESET}"
        fi

    fi

    # DROPBEAR

    if service_exists dropbear; then

        echo -e "${CYAN}Reiniciando Dropbear...${RESET}"

        if systemctl restart dropbear 2>/dev/null; then
            echo -e "${GREEN}✔ Dropbear reiniciado correctamente.${RESET}"
        else
            echo -e "${RED}❌ No se pudo reiniciar Dropbear.${RESET}"
        fi

    fi
}

#==============================
# CREAR BANNER
#==============================

create_banner() {

    header

    echo -e "${MAGENTA}                 CREAR NUEVO BANNER${RESET}"
    echo

    read -rp "$(echo -e "${GREEN}Nombre del servidor: ${RESET}")" SERVER

    [[ -z "$SERVER" ]] && SERVER="${SERVER_NAME:-KevinTech VPN}"

    read -rp "$(echo -e "${GREEN}Texto promocional: ${RESET}")" PROMO

    [[ -z "$PROMO" ]] && PROMO="🔥 Bienvenido a $SERVER 🔥"

    read -rp "$(echo -e "${GREEN}Canal Telegram: ${RESET}")" CHANNEL

    read -rp "$(echo -e "${GREEN}Soporte: ${RESET}")" SUPPORT

    echo

    # Backup del banner anterior

    if [[ -f "$BANNER" ]]; then
        backup_file "$BANNER"
    fi

    # Crear banner

    cat > "$BANNER" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              $SERVER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$PROMO

📢 Canal  : $CHANNEL
👤 Soporte: $SUPPORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
           Gracias por usar nuestros servicios
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    chmod 644 "$BANNER"

    echo -e "${GREEN}✔ Banner creado:${RESET} $BANNER"

    echo

    # Configurar SSH

    configure_ssh

    # Configurar Dropbear

    configure_dropbear

    # Reiniciar

    restart_services

    echo
    echo -e "${GREEN}✔ Banner instalado correctamente.${RESET}"

    pause
}

#==============================
# VER BANNER
#==============================

view_banner() {

    header

    echo -e "${MAGENTA}                    BANNER ACTUAL${RESET}"
    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${RED}❌ No existe ningún banner.${RESET}"

        pause
        return

    fi

    echo -e "${GREEN}Ruta:${RESET} $BANNER"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    cat "$BANNER"

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    pause
}

#==============================
# EDITAR BANNER
#==============================

edit_banner() {

    header

    echo -e "${MAGENTA}                    EDITAR BANNER${RESET}"
    echo

    if ! command -v nano >/dev/null 2>&1; then

        echo -e "${RED}❌ Nano no está instalado.${RESET}"
        echo

        read -rp "¿Desea instalar nano? [S/N]: " RESP

        case "$RESP" in

            s|S|si|SI|sí|Sí)

                apt-get update -qq
                apt-get install -y nano

                ;;

            *)

                return
                ;;

        esac

    fi

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${YELLOW}⚠ El banner no existe.${RESET}"
        echo "Creando banner básico..."

        cat > "$BANNER" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
              ${SERVER_NAME:-KevinTech VPN}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

             Bienvenido a nuestro servidor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    else

        backup_file "$BANNER"

    fi

    nano "$BANNER"

    echo

    configure_ssh

    configure_dropbear

    restart_services

    echo
    echo -e "${GREEN}✔ Banner actualizado.${RESET}"

    pause
}

#==============================
# PROBAR BANNER
#==============================

test_banner() {

    header

    echo -e "${MAGENTA}                    PRUEBA DEL SISTEMA${RESET}"
    echo

    # Banner

    if [[ -f "$BANNER" ]]; then
        echo -e "${GREEN}✔ Banner:${RESET} $BANNER"
    else
        echo -e "${RED}✘ Banner:${RESET} No existe"
    fi

    # SSH

    if [[ -f "$SSHD_CONFIG" ]]; then

        if grep -qE '^[[:space:]]*Banner[[:space:]]+' "$SSHD_CONFIG"; then
            echo -e "${GREEN}✔ OpenSSH:${RESET} Banner configurado"
        else
            echo -e "${RED}✘ OpenSSH:${RESET} Banner no configurado"
        fi

        if command -v sshd >/dev/null 2>&1; then

            if sshd -t 2>/dev/null; then
                echo -e "${GREEN}✔ OpenSSH:${RESET} Configuración válida"
            else
                echo -e "${RED}✘ OpenSSH:${RESET} Configuración inválida"
            fi

        fi

    else

        echo -e "${YELLOW}⚠ OpenSSH:${RESET} No encontrado"

    fi

    # Dropbear

    if [[ -f "$DROPBEAR_CONFIG" ]]; then

        if grep -q '^DROPBEAR_BANNER=' "$DROPBEAR_CONFIG"; then
            echo -e "${GREEN}✔ Dropbear:${RESET} Banner configurado"
        else
            echo -e "${RED}✘ Dropbear:${RESET} Banner no configurado"
        fi

    else

        echo -e "${YELLOW}⚠ Dropbear:${RESET} No encontrado"

    fi

    echo

    # Servicios

    if service_active ssh || service_active sshd; then
        echo -e "${GREEN}✔ Servicio SSH activo${RESET}"
    else
        echo -e "${RED}✘ Servicio SSH inactivo${RESET}"
    fi

    if service_active dropbear; then
        echo -e "${GREEN}✔ Servicio Dropbear activo${RESET}"
    else
        echo -e "${GRAY}• Dropbear no está activo${RESET}"
    fi

    pause
}

#==============================
# BACKUPS
#==============================

show_backups() {

    header

    echo -e "${MAGENTA}                     BACKUPS${RESET}"
    echo

    if [[ -z "$(find "$BACKUP_DIR" -type f 2>/dev/null)" ]]; then

        echo -e "${YELLOW}No existen backups.${RESET}"

    else

        ls -lah "$BACKUP_DIR"

    fi

    pause
}

#==============================
# RESTAURAR
#==============================

restore_backup() {

    header

    echo -e "${MAGENTA}                 RESTAURAR BACKUP${RESET}"
    echo

    mapfile -t FILES < <(find "$BACKUP_DIR" -type f -name '*.bak' 2>/dev/null | sort -r)

    if [[ "${#FILES[@]}" -eq 0 ]]; then

        echo -e "${YELLOW}No existen backups.${RESET}"
        pause
        return

    fi

    local I=1

    for FILE in "${FILES[@]}"; do

        echo -e "${GREEN}[$I]${WHITE} $(basename "$FILE")"

        ((I++))

    done

    echo
    read -rp "Seleccione backup: " NUM

    if ! [[ "$NUM" =~ ^[0-9]+$ ]] ||
       (( NUM < 1 || NUM > ${#FILES[@]} )); then

        echo -e "${RED}❌ Opción inválida.${RESET}"
        sleep 2
        return

    fi

    SELECTED="${FILES[$((NUM-1))]}"

    echo
    echo -e "${YELLOW}Backup seleccionado:${RESET}"
    echo "$(basename "$SELECTED")"

    echo

    read -rp "¿Restaurar este backup? [S/N]: " RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            NAME="$(basename "$SELECTED")"

            # Detectar tipo de backup

            if [[ "$NAME" == issue.net_* ]]; then

                cp -a "$SELECTED" "$BANNER"

                echo -e "${GREEN}✔ Banner restaurado.${RESET}"

            elif [[ "$NAME" == sshd_config_* ]]; then

                cp -a "$SELECTED" "$SSHD_CONFIG"

                if command -v sshd >/dev/null 2>&1 &&
                   sshd -t 2>/dev/null; then

                    systemctl restart ssh 2>/dev/null ||
                    systemctl restart sshd 2>/dev/null

                    echo -e "${GREEN}✔ SSH restaurado.${RESET}"

                else

                    echo -e "${RED}❌ La configuración restaurada de SSH no es válida.${RESET}"

                fi

            elif [[ "$NAME" == dropbear_* ]]; then

                cp -a "$SELECTED" "$DROPBEAR_CONFIG"

                systemctl restart dropbear 2>/dev/null

                echo -e "${GREEN}✔ Dropbear restaurado.${RESET}"

            else

                echo -e "${RED}❌ Tipo de backup desconocido.${RESET}"
            fi

            ;;

        *)

            echo -e "${YELLOW}Operación cancelada.${RESET}"

            ;;

    esac

    pause
}

#==============================
# ELIMINAR BANNER
#==============================

delete_banner() {

    header

    echo -e "${MAGENTA}                   ELIMINAR BANNER${RESET}"
    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${RED}❌ No existe ningún banner.${RESET}"

        pause
        return

    fi

    echo -e "${YELLOW}⚠ Se creará un backup antes de eliminarlo.${RESET}"
    echo

    read -rp "¿Desea eliminar el banner? [S/N]: " RESP

    case "$RESP" in

        s|S|si|SI|sí|Sí)

            backup_file "$BANNER"

            rm -f "$BANNER"

            # OpenSSH

            if [[ -f "$SSHD_CONFIG" ]]; then

                backup_file "$SSHD_CONFIG"

                sed -i -E '/^[[:space:]]*Banner[[:space:]]+/d' "$SSHD_CONFIG"

                if command -v sshd >/dev/null 2>&1 &&
                   sshd -t 2>/dev/null; then

                    systemctl restart ssh 2>/dev/null ||
                    systemctl restart sshd 2>/dev/null

                fi

            fi

            # Dropbear

            if [[ -f "$DROPBEAR_CONFIG" ]]; then

                backup_file "$DROPBEAR_CONFIG"

                sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR_CONFIG"

                systemctl restart dropbear 2>/dev/null

            fi

            echo
            echo -e "${GREEN}✔ Banner eliminado correctamente.${RESET}"

            ;;

        *)

            echo
            echo -e "${YELLOW}Operación cancelada.${RESET}"

            ;;

    esac

    pause
}

#==============================
# MENÚ PRINCIPAL
#==============================

while true; do

    header
    show_status

    echo
    echo -e "${GREEN}[1]${WHITE} Crear nuevo Banner"
    echo -e "${BLUE}[2]${WHITE} Ver Banner actual"
    echo -e "${YELLOW}[3]${WHITE} Editar Banner"
    echo -e "${CYAN}[4]${WHITE} Probar configuración"
    echo -e "${MAGENTA}[5]${WHITE} Ver Backups"
    echo -e "${BLUE}[6]${WHITE} Restaurar Backup"
    echo -e "${RED}[7]${WHITE} Eliminar Banner"
    echo -e "${GRAY}[0]${WHITE} Regresar"

    echo

    read -rp "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

    case "$OP" in

        1)
            create_banner
            ;;

        2)
            view_banner
            ;;

        3)
            edit_banner
            ;;

        4)
            test_banner
            ;;

        5)
            show_backups
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
            echo -e "${RED}❌ Opción inválida.${RESET}"
            sleep 2
            ;;

    esac

done