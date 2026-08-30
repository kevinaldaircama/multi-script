#!/bin/bash
#==================================================
# KevinTech Multi Script
# Banner Manager - SSH / Dropbear
# Version: 3.0
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
SSHD="/etc/ssh/sshd_config"
DROPBEAR="/etc/default/dropbear"
BACKUP_DIR="$BASE/banner-backups"

mkdir -p "$BASE" "$BACKUP_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==============================
# COMPROBAR ROOT
#==============================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"
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
    echo -e "${CYAN}║${MAGENTA}          KEVINTECH BANNER MANAGER                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo
}

ssh_installed() {
    [[ -f "$SSHD" ]] || return 1
    command -v sshd >/dev/null 2>&1
}

dropbear_installed() {
    [[ -f "$DROPBEAR" ]] || return 1
}

service_exists() {
    systemctl list-unit-files "$1.service" 2>/dev/null |
        grep -q "^$1.service"
}

#==============================
# ESTADO
#==============================

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

show_status() {

    echo -e "${CYAN}Estado del sistema${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [[ -f "$BANNER" ]]; then
        echo -e "Banner   : ${GREEN}✔ ACTIVO${RESET}"
        echo -e "Archivo  : ${WHITE}$BANNER${RESET}"
    else
        echo -e "Banner   : ${RED}✘ NO EXISTE${RESET}"
    fi

    echo -n "OpenSSH  : "
    service_status

    echo -n "Dropbear : "
    dropbear_status

    echo
}

#==============================
# BACKUP
#==============================

create_backup() {

    local DATE
    DATE=$(date +"%Y%m%d_%H%M%S")

    local DIR="$BACKUP_DIR/$DATE"

    mkdir -p "$DIR"

    [[ -f "$BANNER" ]] &&
        cp -a "$BANNER" "$DIR/issue.net"

    [[ -f "$SSHD" ]] &&
        cp -a "$SSHD" "$DIR/sshd_config"

    [[ -f "$DROPBEAR" ]] &&
        cp -a "$DROPBEAR" "$DIR/dropbear"

    echo "$DIR" > "$BACKUP_DIR/latest"

    echo -e "${GREEN}✔ Backup creado:${RESET} $DIR"
}

#==============================
# CONFIGURAR OPENSSH
#==============================

configure_ssh() {

    if ! ssh_installed; then
        return 0
    fi

    # Eliminar configuraciones Banner anteriores
    sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD"

    echo "Banner $BANNER" >> "$SSHD"

    # Validar antes de reiniciar
    if ! sshd -t 2>/dev/null; then

        echo -e "${RED}✘ Error en la configuración de OpenSSH.${RESET}"
        echo -e "${YELLOW}Restaurando configuración...${RESET}"

        local BACKUP
        BACKUP=$(cat "$BACKUP_DIR/latest" 2>/dev/null)

        if [[ -f "$BACKUP/sshd_config" ]]; then
            cp -a "$BACKUP/sshd_config" "$SSHD"
        fi

        return 1
    fi

    echo -e "${GREEN}✔ Configuración OpenSSH válida.${RESET}"

    local SERVICE=""

    if systemctl list-unit-files 2>/dev/null |
        grep -q "^ssh.service"; then
        SERVICE="ssh"
    elif systemctl list-unit-files 2>/dev/null |
        grep -q "^sshd.service"; then
        SERVICE="sshd"
    fi

    if [[ -n "$SERVICE" ]]; then
        systemctl restart "$SERVICE"

        if systemctl is-active --quiet "$SERVICE"; then
            echo -e "${GREEN}✔ OpenSSH reiniciado correctamente.${RESET}"
        else
            echo -e "${RED}✘ OpenSSH no está activo.${RESET}"
            return 1
        fi
    fi

    return 0
}

#==============================
# CONFIGURAR DROPBEAR
#==============================

configure_dropbear() {

    if ! dropbear_installed; then
        return 0
    fi

    if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

        sed -i \
        "s|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER=\"$BANNER\"|" \
        "$DROPBEAR"

    else

        echo "DROPBEAR_BANNER=\"$BANNER\"" >> "$DROPBEAR"

    fi

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

#==============================
# APLICAR CONFIGURACIÓN
#==============================

apply_banner() {

    echo
    echo -e "${CYAN}Aplicando configuración...${RESET}"
    echo

    configure_ssh
    configure_dropbear

    echo
    echo -e "${GREEN}✔ Proceso terminado.${RESET}"
}

#==============================
# PLANTILLA 1
#==============================

template_classic() {

cat <<EOF
╔════════════════════════════════════════════════════╗
║                 $SERVER                         ║
╠════════════════════════════════════════════════════╣
║                                                    ║
║ $PROMO                                             ║
║                                                    ║
║ 📢 Canal   : $CHANNEL                              ║
║ 👤 Soporte : $SUPPORT                               ║
║                                                    ║
╠════════════════════════════════════════════════════╣
║              Gracias por usar el servicio          ║
╚════════════════════════════════════════════════════╝
EOF

}

#==============================
# PLANTILLA 2
#==============================

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

#==============================
# PLANTILLA 3
#==============================

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

#==============================
# CREAR BANNER
#==============================

create_banner() {

    header

    echo -e "${MAGENTA}              CREAR NUEVO BANNER${RESET}"
    echo
    echo -e "${GREEN}[1]${WHITE} Usar plantilla"
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

#==============================
# VER BANNER
#==============================

view_banner() {

    header

    echo -e "${MAGENTA}                 BANNER ACTUAL${RESET}"
    echo

    if [[ ! -f "$BANNER" ]]; then
        echo -e "${RED}✘ No existe ningún banner.${RESET}"
        pause
        return
    fi

    echo -e "${GREEN}Archivo:${RESET} $BANNER"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    cat "$BANNER"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    pause
}

#==============================
# EDITAR
#==============================

edit_banner() {

    header

    echo -e "${MAGENTA}                 EDITAR BANNER${RESET}"
    echo

    if [[ ! -f "$BANNER" ]]; then
        echo -e "${YELLOW}No existe un banner.${RESET}"
        echo
        read -rp "¿Crear uno vacío? [S/N]: " RESP

        case "$RESP" in
            s|S|si|SI)
                touch "$BANNER"
                ;;
            *)
                return
                ;;
        esac
    fi

    create_backup

    if ! command -v nano >/dev/null 2>&1; then
        echo -e "${RED}✘ Nano no está instalado.${RESET}"
        pause
        return
    fi

    nano "$BANNER"

    echo
    echo -e "${GREEN}✔ Banner editado.${RESET}"

    echo
    read -rp "$(echo -e "${YELLOW}¿Aplicar cambios? [S/N]: ${RESET}")" RESP

    case "$RESP" in
        s|S|si|SI|sí|Sí)
            apply_banner
            ;;
        *)
            echo -e "${YELLOW}Cambios guardados pero no aplicados.${RESET}"
            ;;
    esac

    sleep 2
}

#==============================
# PROBAR
#==============================

test_banner() {

    header

    echo -e "${MAGENTA}                 PRUEBA DEL BANNER${RESET}"
    echo

    if [[ ! -f "$BANNER" ]]; then
        echo -e "${RED}✘ El banner no existe.${RESET}"
        pause
        return
    fi

    echo -e "${GREEN}✔ Archivo del banner existe${RESET}"

    if ssh_installed; then

        if sshd -t 2>/dev/null; then
            echo -e "${GREEN}✔ Configuración OpenSSH válida${RESET}"
        else
            echo -e "${RED}✘ Configuración OpenSSH inválida${RESET}"
        fi

        if grep -qE "^[[:space:]]*Banner[[:space:]]+$BANNER" "$SSHD"; then
            echo -e "${GREEN}✔ OpenSSH apunta al banner${RESET}"
        else
            echo -e "${YELLOW}⚠ OpenSSH no apunta al banner${RESET}"
        fi

    else
        echo -e "${GRAY}⚠ OpenSSH no instalado${RESET}"
    fi

    if dropbear_installed; then

        if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then
            echo -e "${GREEN}✔ Dropbear apunta al banner${RESET}"
        else
            echo -e "${YELLOW}⚠ Dropbear no apunta al banner${RESET}"
        fi

    else
        echo -e "${GRAY}⚠ Dropbear no instalado${RESET}"
    fi

    pause
}

#==============================
# RESTAURAR BACKUP
#==============================

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

        [[ -f "$BACKUP/issue.net" ]] &&
            cp -a "$BACKUP/issue.net" "$BANNER"

        [[ -f "$BACKUP/sshd_config" ]] &&
            cp -a "$BACKUP/sshd_config" "$SSHD"

        [[ -f "$BACKUP/dropbear" ]] &&
            cp -a "$BACKUP/dropbear" "$DROPBEAR"

        echo
        echo -e "${GREEN}✔ Backup restaurado.${RESET}"

        if ssh_installed && sshd -t 2>/dev/null; then

            if systemctl list-unit-files 2>/dev/null |
                grep -q "^ssh.service"; then
                systemctl restart ssh
            elif systemctl list-unit-files 2>/dev/null |
                grep -q "^sshd.service"; then
                systemctl restart sshd
            fi

        fi

        systemctl restart dropbear 2>/dev/null

        ;;

    *)
        echo -e "${YELLOW}Operación cancelada.${RESET}"
        ;;

    esac

    sleep 2
}

#==============================
# ELIMINAR BANNER
#==============================

delete_banner() {

    header

    echo -e "${MAGENTA}                 ELIMINAR BANNER${RESET}"
    echo

    if [[ ! -f "$BANNER" ]]; then
        echo -e "${RED}✘ No existe ningún banner.${RESET}"
        pause
        return
    fi

    echo -e "${YELLOW}Se creará un backup antes de eliminarlo.${RESET}"
    echo

    read -rp "$(echo -e "${RED}¿Eliminar el banner? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        create_backup

        rm -f "$BANNER"

        if ssh_installed; then

            sed -i '/^[[:space:]]*Banner[[:space:]]/d' "$SSHD"

            if sshd -t 2>/dev/null; then

                if systemctl list-unit-files 2>/dev/null |
                    grep -q "^ssh.service"; then
                    systemctl restart ssh
                elif systemctl list-unit-files 2>/dev/null |
                    grep -q "^sshd.service"; then
                    systemctl restart sshd
                fi

            fi

        fi

        if dropbear_installed; then
            sed -i '/^DROPBEAR_BANNER=/d' "$DROPBEAR"
            systemctl restart dropbear 2>/dev/null
        fi

        echo
        echo -e "${GREEN}✔ Banner eliminado correctamente.${RESET}"

        ;;

    *)
        echo -e "${YELLOW}Operación cancelada.${RESET}"
        ;;

    esac

    sleep 2
}

#==============================
# MENÚ PRINCIPAL
#==============================

while true; do

    header

    show_status

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
    echo -e "${GREEN}[1]${WHITE} Crear nuevo Banner"
    echo -e "${BLUE}[2]${WHITE} Ver Banner actual"
    echo -e "${YELLOW}[3]${WHITE} Editar Banner"
    echo -e "${CYAN}[4]${WHITE} Probar configuración"
    echo -e "${MAGENTA}[5]${WHITE} Restaurar último Backup"
    echo -e "${RED}[6]${WHITE} Eliminar Banner"
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
        restore_backup
        ;;

    6)
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