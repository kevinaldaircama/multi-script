#!/bin/bash

# =========================================================
#       🛡️ KEVINTECH MULTI SCRIPT - SSH PANEL
#       KevinTech Tutorials • Privanox VPN
# =========================================================

BASE="/etc/kevintech"
VERSION="2.0"
PANEL_NAME="KevinTech Multi Script"

# =========================================================
# COLORES
# =========================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# =========================================================
# CONFIGURACIÓN
# =========================================================

WIDTH=68

# =========================================================
# FUNCIONES GENERALES
# =========================================================

pause() {
    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

line() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${RESET}"
}

top_line() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
}

bottom_line() {
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
}

title() {
    echo -e "${CYAN}║${RESET} ${MAGENTA}${BOLD}$1${RESET}"
}

# =========================================================
# INFORMACIÓN DEL SISTEMA
# =========================================================

get_cpu() {
    CPU=$(top -bn1 | awk -F'id,' '/Cpu/ {
        split($1,a,",")
        idle=a[length(a)]
        gsub(/ /,"",idle)
        printf "%.0f",100-idle
    }')

    echo "${CPU}%"
}

get_ram() {
    free -h | awk '/Mem:/ {print $3 "/" $2}'
}

get_ram_free() {
    free -h | awk '/Mem:/ {print $7}'
}

get_disk() {
    df -h / | awk 'NR==2 {print $3 "/" $2}'
}

get_disk_percent() {
    df -h / | awk 'NR==2 {print $5}'
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/up //'
}

get_load() {
    awk '{print $1}' /proc/loadavg
}

get_users() {
    awk -F: '$3 >= 1000 && $7 !~ /(nologin|false)$/ {count++} END {print count+0}' /etc/passwd
}

get_online() {
    who | wc -l
}

# =========================================================
# BARRA DE ESTADO
# =========================================================

status_bar() {

    CPU=$(get_cpu)
    RAM=$(get_ram)
    FREE_RAM=$(get_ram_free)
    DISK=$(get_disk)
    DISK_P=$(get_disk_percent)
    LOAD=$(get_load)
    USERS=$(get_users)
    ONLINE=$(get_online)

    echo -e "${CYAN}║${RESET} ${BLUE}⚡ CPU${RESET}: ${GREEN}${CPU}${RESET}   ${BLUE}🧠 RAM${RESET}: ${GREEN}${RAM}${RESET}"
    echo -e "${CYAN}║${RESET} ${BLUE}💾 DISCO${RESET}: ${GREEN}${DISK} (${DISK_P})${RESET}"
    echo -e "${CYAN}║${RESET} ${BLUE}📈 LOAD${RESET}: ${GREEN}${LOAD}${RESET}   ${BLUE}⏱️ UPTIME${RESET}: ${GREEN}$(get_uptime)${RESET}"
    echo -e "${CYAN}║${RESET} ${BLUE}👤 CUENTAS${RESET}: ${GREEN}${USERS}${RESET}   ${BLUE}🟢 ONLINE${RESET}: ${GREEN}${ONLINE}${RESET}"
}

# =========================================================
# ENCABEZADO
# =========================================================

header() {

    clear

    top_line

    echo -e "${CYAN}║${RESET}                                                                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}       ${MAGENTA}${BOLD}🛡️  KEVINTECH MULTI SCRIPT${RESET}                         ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}              ${WHITE}SSH ADMINISTRATION PANEL${RESET}                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}                                                                  ${CYAN}║${RESET}"

    line

    status_bar

    line
}

# =========================================================
# MENÚ
# =========================================================

menu() {

    echo -e "${CYAN}║${RESET} ${YELLOW}${BOLD}👤 GESTIÓN DE USUARIOS SSH${RESET}                              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}[01]${RESET} 👤 ${WHITE}Crear Usuario SSH${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}[02]${RESET} 🗑️  ${WHITE}Eliminar Usuario${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}[03]${RESET} ♻️  ${WHITE}Renovar / Editar Usuario${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}[04]${RESET} 📋 ${WHITE}Lista de Usuarios${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}[05]${RESET} 🌐 ${WHITE}Usuarios Conectados${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}[06]${RESET} 🔒 ${WHITE}Bloquear / Desbloquear${RESET}"
    echo -e "${CYAN}║${RESET}"
    
    line

    echo -e "${CYAN}║${RESET} ${YELLOW}${BOLD}⚙️  CONFIGURACIÓN SSH${RESET}                                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}[07]${RESET} 📢 ${WHITE}Banner SSH / Dropbear${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}[08]${RESET} 💾 ${WHITE}Backup de Usuarios${RESET}"
    echo -e "${CYAN}║${RESET}"
    
    line

    echo -e "${CYAN}║${RESET} ${YELLOW}${BOLD}🛠️  SISTEMA${RESET}                                            ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${MAGENTA}[09]${RESET} 📊 ${WHITE}Información del Sistema${RESET}"
    echo -e "${CYAN}║${RESET}  ${MAGENTA}[10]${RESET} 🔄 ${WHITE}Actualizar Panel${RESET}"
    echo -e "${CYAN}║${RESET}"
    
    line

    echo -e "${CYAN}║${RESET}  ${RED}[00]${RESET} 🚪 ${WHITE}Volver al Menú Principal${RESET}"
    
    bottom_line

    echo
}

# =========================================================
# EJECUTAR SCRIPT
# =========================================================

run_script() {

    SCRIPT="$1"

    if [[ ! -f "$SCRIPT" ]]; then

        echo
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║${RESET} ${RED}✘ ERROR: Script no encontrado${RESET}"
        echo -e "${RED}║${RESET}"
        echo -e "${RED}║${RESET} ${WHITE}$SCRIPT${RESET}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${RESET}"

        sleep 3
        return
    fi

    clear

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${GREEN}▶ Ejecutando KevinTech Module...${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    bash "$SCRIPT"

    echo
    echo -e "${GREEN}✔ Módulo finalizado.${RESET}"

    pause
}

# =========================================================
# INFORMACIÓN DEL SISTEMA
# =========================================================

system_info() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}📊 INFORMACIÓN DEL SISTEMA${RESET}                    ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    echo -e "${CYAN}║${RESET} 🖥️  Hostname     : ${GREEN}$(hostname)${RESET}"
    echo -e "${CYAN}║${RESET} 🐧 Sistema       : ${GREEN}$(. /etc/os-release && echo "$PRETTY_NAME")${RESET}"
    echo -e "${CYAN}║${RESET} 🔧 Kernel        : ${GREEN}$(uname -r)${RESET}"
    echo -e "${CYAN}║${RESET} 🏗️  Arquitectura  : ${GREEN}$(uname -m)${RESET}"
    echo -e "${CYAN}║${RESET} ⚡ CPU           : ${GREEN}$(get_cpu)${RESET}"
    echo -e "${CYAN}║${RESET} 🧠 RAM           : ${GREEN}$(get_ram)${RESET}"
    echo -e "${CYAN}║${RESET} 💾 Disco         : ${GREEN}$(get_disk)${RESET}"
    echo -e "${CYAN}║${RESET} 📈 Carga         : ${GREEN}$(get_load)${RESET}"
    echo -e "${CYAN}║${RESET} ⏱️  Uptime        : ${GREEN}$(get_uptime)${RESET}"
    echo -e "${CYAN}║${RESET} 👤 Usuarios      : ${GREEN}$(get_users)${RESET}"
    echo -e "${CYAN}║${RESET} 🟢 Conectados    : ${GREEN}$(get_online)${RESET}"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"

    pause
}

# =========================================================
# ACTUALIZAR PANEL
# =========================================================

update_panel() {

    clear

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}              ${MAGENTA}${BOLD}🔄 ACTUALIZANDO PANEL${RESET}                       ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

    if [[ -f "$BASE/update.sh" ]]; then
        bash "$BASE/update.sh"
    else
        echo -e "${YELLOW}⚠ No se encontró:${RESET} $BASE/update.sh"
        sleep 2
    fi

    pause
}

# =========================================================
# CTRL + C
# =========================================================

trap '
echo
echo -e "${YELLOW}⚠ Usa la opción [00] para salir correctamente.${RESET}"
sleep 1
' INT

# =========================================================
# COMPROBAR ROOT
# =========================================================

if [[ $EUID -ne 0 ]]; then
    clear
    echo
    echo -e "${RED}✘ Este panel debe ejecutarse como ROOT.${RESET}"
    echo
    echo -e "${YELLOW}Ejemplo:${RESET}"
    echo -e "${WHITE}sudo bash $0${RESET}"
    echo
    exit 1
fi

# =========================================================
# COMPROBAR BASE
# =========================================================

if [[ ! -d "$BASE" ]]; then

    echo
    echo -e "${RED}✘ Error: No existe el directorio:${RESET}"
    echo -e "${WHITE}$BASE${RESET}"
    echo
    exit 1

fi

# =========================================================
# BUCLE PRINCIPAL
# =========================================================

while true; do

    header
    menu

    read -rp "$(echo -e "${GREEN}➜ Seleccione una opción [00-10]: ${RESET}")" OP

    case "$OP" in

        1|01)
            run_script "$BASE/usuarios/add.sh"
            ;;

        2|02)
            run_script "$BASE/usuarios/delete.sh"
            ;;

        3|03)
            run_script "$BASE/usuarios/edit.sh"
            ;;

        4|04)
            run_script "$BASE/usuarios/list.sh"
            ;;

        5|05)
            run_script "$BASE/usuarios/online.sh"
            ;;

        6|06)
            run_script "$BASE/usuarios/block.sh"
            ;;

        7|07)
            run_script "$BASE/usuarios/banner.sh"
            ;;

        8|08)
            run_script "$BASE/usuarios/backup.sh"
            ;;

        9|09)
            system_info
            ;;

        10)
            update_panel
            ;;

        0|00)
            clear

            echo
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
            echo -e "${CYAN}║${RESET} ${GREEN}✔ Saliendo de KevinTech Multi Script...${RESET}"
            echo -e "${CYAN}║${RESET} ${GRAY}Gracias por utilizar KevinTech.${RESET}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
            echo

            sleep 1

            if [[ -f "$BASE/menu.sh" ]]; then
                exec bash "$BASE/menu.sh"
            else
                exit 0
            fi
            ;;

        *)
            echo
            echo -e "${RED}✘ Opción inválida.${RESET}"
            echo -e "${GRAY}Seleccione una opción entre 00 y 10.${RESET}"
            sleep 2
            ;;

    esac

done