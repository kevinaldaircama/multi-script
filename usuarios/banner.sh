#!/bin/bash

#==================================================
# KevinTech Multi Script
# Banner Manager - SSH / Dropbear
# Banner + CheckUser
# Version: 3.1 PREMIUM
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
SSHRC="/etc/ssh/sshrc"
DROPBEAR="/etc/default/dropbear"

BACKUP_DIR="$BASE/banner-backups"

# CheckUser YA EXISTENTE
CHECKUSER="/usr/local/bin/kevintech-checkuser"

mkdir -p "$BASE" "$BACKUP_DIR"

[[ -f "$CONFIG" ]] && source "$CONFIG"

#==============================
# COMPROBAR ROOT
#==============================

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}✘ Este script debe ejecutarse como root.${RESET}"

    exit 1
fi

#==================================================
# FUNCIONES VISUALES
#==================================================

pause() {

    echo

    read -n1 -s -r \
        -p "$(echo -e "${YELLOW}Presione cualquier tecla para continuar...${RESET}")"

    echo
}

header() {

    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${MAGENTA}             ⚜ KEVINTECH BANNER MANAGER ⚜                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}              SSH • DROPBEAR • CHECKUSER                 ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo
}

line() {

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

#==================================================
# OPENSSH
#==================================================

ssh_installed() {

    [[ -f "$SSHD" ]] &&
    command -v sshd >/dev/null 2>&1
}

#==================================================
# DROPBEAR
#==================================================

dropbear_installed() {

    [[ -f "$DROPBEAR" ]]
}

#==================================================
# SERVICIO SSH
#==================================================

ssh_service() {

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

    if ! ssh_installed; then

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

        return
    fi

    local SERVICE

    SERVICE=$(ssh_service)

    if [[ -n "$SERVICE" ]] &&
       systemctl is-active --quiet "$SERVICE" 2>/dev/null; then

        echo -e "${GREEN}✔ ACTIVO${RESET}"

    else

        echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

    fi
}

#==================================================
# ESTADO DROPBEAR
#==================================================

dropbear_status() {

    if ! dropbear_installed; then

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

        return
    fi

    if systemctl is-active --quiet dropbear 2>/dev/null; then

        echo -e "${GREEN}✔ ACTIVO${RESET}"

    else

        echo -e "${YELLOW}⚠ INSTALADO / INACTIVO${RESET}"

    fi
}

#==================================================
# ESTADO CHECKUSER
#==================================================

checkuser_status() {

    if [[ ! -x "$CHECKUSER" ]]; then

        echo -e "${GRAY}✘ NO INSTALADO${RESET}"

        return
    fi

    if [[ -f "$SSHRC" ]] &&
       grep -q "BEGIN KEVINTECH CHECKUSER" "$SSHRC" 2>/dev/null; then

        echo -e "${GREEN}✔ INTEGRADO${RESET}"

    else

        echo -e "${YELLOW}⚠ INSTALADO / NO INTEGRADO${RESET}"

    fi
}

#==================================================
# INTEGRAR CHECKUSER
#==================================================

configure_checkuser() {

    echo -e "${BLUE}➜ Comprobando CheckUser...${RESET}"

    # IMPORTANTE:
    # Este script NO crea usuarios.
    # Solamente utiliza el CheckUser que ya existe.

    if [[ ! -x "$CHECKUSER" ]]; then

        echo -e "${YELLOW}⚠ No existe:${RESET}"
        echo -e "${WHITE}$CHECKUSER${RESET}"

        echo
        echo -e "${GRAY}El creador de cuentas debe proporcionar este archivo.${RESET}"

        return 0
    fi

    # Crear sshrc si no existe
    touch "$SSHRC"

    chmod 755 "$SSHRC"

    #==================================================
    # ELIMINAR ÚNICAMENTE NUESTRO BLOQUE
    #==================================================

    sed -i \
        '/# BEGIN KEVINTECH CHECKUSER/,/# END KEVINTECH CHECKUSER/d' \
        "$SSHRC"

    #==================================================
    # INSERTAR CHECKUSER
    #==================================================

    cat >> "$SSHRC" <<'EOF'

# BEGIN KEVINTECH CHECKUSER

if [[ -x /usr/local/bin/kevintech-checkuser ]]; then
    /usr/local/bin/kevintech-checkuser
fi

# END KEVINTECH CHECKUSER

EOF

    chmod 755 "$SSHRC"

    echo -e "${GREEN}✔ CheckUser integrado en /etc/ssh/sshrc${RESET}"
}

#==================================================
# REPARAR CHECKUSER
#==================================================

repair_checkuser() {

    header

    echo -e "${MAGENTA}              ⚡ REPARAR CHECKUSER ⚡${RESET}"

    echo

    if [[ ! -x "$CHECKUSER" ]]; then

        echo -e "${RED}✘ CheckUser no existe.${RESET}"

        echo
        echo -e "${GRAY}Ruta esperada:${RESET}"
        echo -e "${WHITE}$CHECKUSER${RESET}"

        pause

        return
    fi

    configure_checkuser

    echo

    echo -e "${GREEN}✔ Integración reparada.${RESET}"

    echo

    echo -e "${WHITE}Archivo:${RESET}"
    echo -e "${GRAY}$SSHRC${RESET}"

    pause
}

#==================================================
# BACKUP
#==================================================

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

    [[ -f "$SSHRC" ]] &&
        cp -a "$SSHRC" "$DIR/sshrc"

    echo "$DIR" > "$BACKUP_DIR/latest"

    echo
    echo -e "${GREEN}✔ Backup creado:${RESET}"
    echo -e "${WHITE}$DIR${RESET}"
}

#==================================================
# CONFIGURAR OPENSSH
#==================================================

configure_ssh() {

    if ! ssh_installed; then

        echo -e "${GRAY}⚠ OpenSSH no está instalado.${RESET}"

        return 0
    fi

    # Eliminar Banner anteriores
    sed -i \
        '/^[[:space:]]*Banner[[:space:]]/d' \
        "$SSHD"

    echo "Banner $BANNER" >> "$SSHD"

    # Validar configuración
    if ! sshd -t 2>/dev/null; then

        echo -e "${RED}✘ Error en la configuración de OpenSSH.${RESET}"

        local BACKUP

        BACKUP=$(cat "$BACKUP_DIR/latest" 2>/dev/null)

        if [[ -f "$BACKUP/sshd_config" ]]; then

            cp -a "$BACKUP/sshd_config" "$SSHD"

            echo -e "${YELLOW}⚠ Configuración restaurada.${RESET}"

        fi

        return 1
    fi

    echo -e "${GREEN}✔ Configuración OpenSSH válida.${RESET}"

    local SERVICE

    SERVICE=$(ssh_service)

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

#==================================================
# CONFIGURAR DROPBEAR
#==================================================

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

#==================================================
# APLICAR TODO
#==================================================

apply_configuration() {

    echo

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}              APLICANDO CONFIGURACIÓN                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo

    #----------------------------------------------
    # BANNER
    #----------------------------------------------

    echo -e "${BLUE}➜ Configurando Banner...${RESET}"

    configure_ssh

    configure_dropbear

    echo

    #----------------------------------------------
    # CHECKUSER
    #----------------------------------------------

    echo -e "${BLUE}➜ Integrando CheckUser...${RESET}"

    configure_checkuser

    echo

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${WHITE}             ✔ CONFIGURACIÓN COMPLETA                     ${GREEN}║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e "${WHITE}Flujo SSH configurado:${RESET}"

    echo -e " ${CYAN}①${RESET} Banner"
    echo -e " ${CYAN}②${RESET} CheckUser"
    echo -e " ${CYAN}③${RESET} Sesión SSH"

    echo
}

#==================================================
# CREAR BANNER
#==================================================

create_banner() {

    header

    echo -e "${MAGENTA}              CREAR NUEVO BANNER${RESET}"

    echo

    echo -e "${GREEN}[1]${WHITE} Usar plantilla"
    echo -e "${BLUE}[2]${WHITE} Banner personalizado"
    echo -e "${RED}[0]${WHITE} Cancelar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione:${RESET} ")" TYPE

    case "$TYPE" in

    #================================================
    # PLANTILLAS
    #================================================

    1)

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}                 DATOS DEL BANNER                         ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

        echo

        read -rp \
            "$(echo -e "${GREEN}Nombre del servidor:${RESET} ")" SERVER

        [[ -z "$SERVER" ]] &&
            SERVER="KevinTech VPN"

        read -rp \
            "$(echo -e "${GREEN}Texto promocional:${RESET} ")" PROMO

        [[ -z "$PROMO" ]] &&
            PROMO="🔥 Bienvenido a $SERVER 🔥"

        read -rp \
            "$(echo -e "${GREEN}Canal Telegram:${RESET} ")" CHANNEL

        [[ -z "$CHANNEL" ]] &&
            CHANNEL="@KevinTech"

        read -rp \
            "$(echo -e "${GREEN}Soporte:${RESET} ")" SUPPORT

        [[ -z "$SUPPORT" ]] &&
            SUPPORT="@KevinSupport"

        echo

        echo -e "${GREEN}[1]${WHITE} Clásica"
        echo -e "${BLUE}[2]${WHITE} Premium"
        echo -e "${YELLOW}[3]${WHITE} Minimalista"
        echo -e "${RED}[0]${WHITE} Cancelar"

        echo

        read -rp \
            "$(echo -e "${GREEN}Plantilla:${RESET} ")" TEMPLATE

        case "$TEMPLATE" in

        #--------------------------------------------
        # CLÁSICA
        #--------------------------------------------

        1)

            create_backup

            cat > "$BANNER" <<EOF
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

            ;;

        #--------------------------------------------
        # PREMIUM
        #--------------------------------------------

        2)

            create_backup

            cat > "$BANNER" <<EOF
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

            ;;

        #--------------------------------------------
        # MINIMAL
        #--------------------------------------------

        3)

            create_backup

            cat > "$BANNER" <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                 $SERVER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$PROMO

Canal   : $CHANNEL
Soporte : $SUPPORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

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

    #================================================
    # PERSONALIZADO
    #================================================

    2)

        clear

        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${MAGENTA}                BANNER PERSONALIZADO                      ${CYAN}║${RESET}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"

        echo

        create_backup

        touch "$BANNER"

        if ! command -v nano >/dev/null 2>&1; then

            echo -e "${RED}✘ Nano no está instalado.${RESET}"

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

    #================================================
    # VISTA PREVIA
    #================================================

    echo

    echo -e "${GREEN}✔ Banner preparado correctamente.${RESET}"

    echo

    echo -e "${CYAN}VISTA PREVIA${RESET}"

    line

    cat "$BANNER"

    line

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Aplicar Banner + CheckUser? [S/N]: ${RESET}")" APPLY

    case "$APPLY" in

    s|S|si|SI|sí|Sí)

        apply_configuration
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

    echo -e "${MAGENTA}                 BANNER ACTUAL${RESET}"

    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${RED}✘ No existe ningún banner.${RESET}"

        pause

        return
    fi

    echo -e "${GREEN}Archivo:${RESET} $BANNER"

    echo

    line

    cat "$BANNER"

    line

    pause
}

#==================================================
# EDITAR BANNER
#==================================================

edit_banner() {

    header

    echo -e "${MAGENTA}                 EDITAR BANNER${RESET}"

    echo

    if [[ ! -f "$BANNER" ]]; then

        echo -e "${YELLOW}No existe un banner.${RESET}"

        touch "$BANNER"
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

    read -rp \
        "$(echo -e "${YELLOW}¿Aplicar Banner + CheckUser? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        apply_configuration
        ;;

    *)

        echo -e "${YELLOW}Cambios guardados pero no aplicados.${RESET}"
        ;;

    esac

    sleep 2
}

#==================================================
# CHECKUSER MANAGER
#==================================================

checkuser_manager() {

    header

    echo -e "${MAGENTA}              ⚡ CHECKUSER MANAGER ⚡${RESET}"

    echo

    echo -n "Estado : "
    checkuser_status

    echo

    line

    echo

    echo -e "${GREEN}[1]${WHITE} Integrar CheckUser"
    echo -e "${BLUE}[2]${WHITE} Probar CheckUser"
    echo -e "${YELLOW}[3]${WHITE} Reparar integración"
    echo -e "${RED}[4]${WHITE} Desintegrar CheckUser"
    echo -e "${GRAY}[0]${WHITE} Regresar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione:${RESET} ")" OP

    case "$OP" in

    1)

        configure_checkuser

        pause
        ;;

    2)

        header

        echo -e "${MAGENTA}              ⚡ PRUEBA CHECKUSER ⚡${RESET}"

        echo

        if [[ -x "$CHECKUSER" ]]; then

            "$CHECKUSER"

        else

            echo -e "${RED}✘ CheckUser no existe.${RESET}"

        fi

        pause
        ;;

    3)

        repair_checkuser
        ;;

    4)

        if [[ -f "$SSHRC" ]]; then

            sed -i \
                '/# BEGIN KEVINTECH CHECKUSER/,/# END KEVINTECH CHECKUSER/d' \
                "$SSHRC"

            echo -e "${GREEN}✔ Integración eliminada.${RESET}"

        else

            echo -e "${YELLOW}⚠ No existe sshrc.${RESET}"

        fi

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
}

#==================================================
# DIAGNÓSTICO
#==================================================

test_banner() {

    header

    echo -e "${MAGENTA}              🔎 DIAGNÓSTICO DEL SISTEMA${RESET}"

    echo

    line

    echo

    # Banner

    if [[ -f "$BANNER" ]]; then

        echo -e "${GREEN}✔${RESET} /etc/issue.net existe"

    else

        echo -e "${RED}✘${RESET} /etc/issue.net no existe"

    fi

    # SSH

    if ssh_installed; then

        if sshd -t 2>/dev/null; then

            echo -e "${GREEN}✔${RESET} OpenSSH válido"

        else

            echo -e "${RED}✘${RESET} OpenSSH tiene errores"

        fi

        if grep -qE \
            "^[[:space:]]*Banner[[:space:]]+$BANNER" \
            "$SSHD"; then

            echo -e "${GREEN}✔${RESET} OpenSSH usa $BANNER"

        else

            echo -e "${YELLOW}⚠${RESET} OpenSSH no usa $BANNER"

        fi

    else

        echo -e "${GRAY}⚠${RESET} OpenSSH no instalado"

    fi

    # CheckUser

    if [[ -x "$CHECKUSER" ]]; then

        echo -e "${GREEN}✔${RESET} CheckUser existe"

    else

        echo -e "${RED}✘${RESET} CheckUser no existe"

    fi

    if [[ -f "$SSHRC" ]] &&
       grep -q "BEGIN KEVINTECH CHECKUSER" "$SSHRC"; then

        echo -e "${GREEN}✔${RESET} CheckUser integrado en sshrc"

    else

        echo -e "${YELLOW}⚠${RESET} CheckUser no integrado"

    fi

    # Dropbear

    if dropbear_installed; then

        if grep -q "^DROPBEAR_BANNER=" "$DROPBEAR"; then

            echo -e "${GREEN}✔${RESET} Dropbear usa el banner"

        else

            echo -e "${YELLOW}⚠${RESET} Dropbear no usa el banner"

        fi

    else

        echo -e "${GRAY}⚠${RESET} Dropbear no instalado"

    fi

    echo

    line

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
    echo -e "${WHITE}$BACKUP${RESET}"

    echo

    read -rp \
        "$(echo -e "${YELLOW}¿Restaurar este backup? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        [[ -f "$BACKUP/issue.net" ]] &&
            cp -a "$BACKUP/issue.net" "$BANNER"

        [[ -f "$BACKUP/sshd_config" ]] &&
            cp -a "$BACKUP/sshd_config" "$SSHD"

        [[ -f "$BACKUP/dropbear" ]] &&
            cp -a "$BACKUP/dropbear" "$DROPBEAR"

        [[ -f "$BACKUP/sshrc" ]] &&
            cp -a "$BACKUP/sshrc" "$SSHRC"

        echo

        echo -e "${GREEN}✔ Backup restaurado.${RESET}"

        if ssh_installed &&
           sshd -t 2>/dev/null; then

            SERVICE=$(ssh_service)

            [[ -n "$SERVICE" ]] &&
                systemctl restart "$SERVICE"

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
# ELIMINAR BANNER
#==================================================

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

    read -rp \
        "$(echo -e "${RED}¿Eliminar el banner? [S/N]: ${RESET}")" RESP

    case "$RESP" in

    s|S|si|SI|sí|Sí)

        create_backup

        rm -f "$BANNER"

        if ssh_installed; then

            sed -i \
                '/^[[:space:]]*Banner[[:space:]]/d' \
                "$SSHD"

            if sshd -t 2>/dev/null; then

                SERVICE=$(ssh_service)

                [[ -n "$SERVICE" ]] &&
                    systemctl restart "$SERVICE"

            fi

        fi

        if dropbear_installed; then

            sed -i \
                '/^DROPBEAR_BANNER=/d' \
                "$DROPBEAR"

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

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    header

    show_status() {

        echo -e "${CYAN}ESTADO DEL SISTEMA${RESET}"

        line

        if [[ -f "$BANNER" ]]; then

            echo -e "Banner    : ${GREEN}✔ ACTIVO${RESET}"
            echo -e "Archivo   : ${WHITE}$BANNER${RESET}"

        else

            echo -e "Banner    : ${RED}✘ NO EXISTE${RESET}"

        fi

        echo -n "OpenSSH   : "
        service_status

        echo -n "Dropbear  : "
        dropbear_status

        echo -n "CheckUser : "
        checkuser_status

        echo
    }

    show_status

    line

    echo

    echo -e "${GREEN}[1]${WHITE} 🎨 Crear nuevo Banner"
    echo -e "${BLUE}[2]${WHITE} 👁  Ver Banner actual"
    echo -e "${YELLOW}[3]${WHITE} ✏  Editar Banner"
    echo -e "${CYAN}[4]${WHITE} ⚡ CheckUser Manager"
    echo -e "${MAGENTA}[5]${WHITE} 🔎 Diagnóstico"
    echo -e "${BLUE}[6]${WHITE} ♻  Restaurar Backup"
    echo -e "${RED}[7]${WHITE} 🗑  Eliminar Banner"
    echo -e "${GRAY}[0]${WHITE} ↩  Regresar"

    echo

    read -rp \
        "$(echo -e "${GREEN}Seleccione una opción:${RESET} ")" OP

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
        checkuser_manager
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

        clear

        exit 0
        ;;

    *)

        echo

        echo -e "${RED}✘ Opción inválida.${RESET}"

        sleep 1
        ;;

    esac

done