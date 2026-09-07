#!/bin/bash
#==================================================
# KevinTech Multi Script
# Gestor de Eliminación de Usuarios SSH
#==================================================

# Colores
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
CYAN="\e[1;96m"
MAGENTA="\e[1;95m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"
RESET="\e[0m"

#==================================================
# CONFIGURACIÓN
#==================================================

MIN_UID=1000

#==================================================
# FUNCIONES
#==================================================

linea() {
    echo -e "${GRAY}────────────────────────────────────────────────────────${RESET}"
}

titulo() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RED}              🗑️  KEVINTECH USERS                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}           GESTOR DE USUARIOS SSH                     ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${RESET}"
}

#==================================================
# OBTENER USUARIOS SSH
#==================================================

obtener_usuarios() {
    awk -F: -v uid="$MIN_UID" '
        $3 >= uid &&
        $1 != "root" &&
        $1 != "nobody" &&
        $1 != "sync" &&
        $1 != "shutdown" &&
        $1 != "halt"
        {
            print $1
        }
    ' /etc/passwd
}

#==================================================
# MOSTRAR USUARIOS
#==================================================

mostrar_usuarios() {

    USERS=$(obtener_usuarios)

    if [[ -z "$USERS" ]]; then
        echo -e "${YELLOW}⚠ No existen usuarios SSH para eliminar.${RESET}"
        echo
        read -n1 -s -r -p "Presione una tecla para continuar..."
        return 1
    fi

    echo -e "${WHITE}👥 USUARIOS DISPONIBLES${RESET}"
    linea

    LISTA=()
    i=1

    while read -r user; do

        [[ -z "$user" ]] && continue

        FECHA=$(chage -l "$user" 2>/dev/null |
            awk -F': ' '/Account expires/{print $2}')

        [[ -z "$FECHA" ]] && FECHA="Sin vencimiento"

        printf "${GREEN}[%02d]${RESET} ${WHITE}%-20s${RESET} ${GRAY}│ Expira: %s${RESET}\n" \
            "$i" "$user" "$FECHA"

        LISTA[$i]="$user"

        ((i++))

    done <<< "$USERS"

    linea
    echo
    return 0
}

#==================================================
# ELIMINAR USUARIO
#==================================================

eliminar_usuario() {

    local USER="$1"

    [[ -z "$USER" ]] && return 1

    # Protección
    case "$USER" in
        root|nobody|sync|shutdown|halt)
            echo -e "${RED}✘ Usuario protegido: $USER${RESET}"
            return 1
            ;;
    esac

    if ! id "$USER" &>/dev/null; then
        return 1
    fi

    # Cerrar todas las sesiones
    pkill -KILL -u "$USER" &>/dev/null

    # Eliminar usuario y su HOME
    userdel -r -f "$USER" &>/dev/null

    if ! id "$USER" &>/dev/null; then
        return 0
    fi

    return 1
}

#==================================================
# ELIMINAR UN USUARIO
#==================================================

eliminar_uno() {

    titulo

    mostrar_usuarios || return

    echo -e "${WHITE}Selecciona el número del usuario:${RESET}"
    echo
    read -rp "$(echo -e "${GREEN}➜ Usuario: ${RESET}")" N

    [[ "$N" == "0" ]] && return

    USER="${LISTA[$N]}"

    if [[ -z "$USER" ]]; then
        echo
        echo -e "${RED}✘ Selección inválida.${RESET}"
        sleep 2
        return
    fi

    echo
    echo -e "${RED}🗑️ Eliminando:${RESET} ${WHITE}$USER${RESET}"
    echo

    if eliminar_usuario "$USER"; then
        echo -e "${GREEN}✔ Usuario eliminado correctamente.${RESET}"
    else
        echo -e "${RED}✘ No se pudo eliminar el usuario.${RESET}"
    fi

    echo
    read -n1 -s -r -p "Presione una tecla para continuar..."
}

#==================================================
# ELIMINAR VARIOS
#==================================================

eliminar_varios() {

    titulo

    mostrar_usuarios || return

    echo -e "${WHITE}Puedes seleccionar varios usuarios.${RESET}"
    echo -e "${GRAY}Ejemplo: 1 3 5 8${RESET}"
    echo

    read -rp "$(echo -e "${GREEN}➜ Selección: ${RESET}")" OP

    [[ "$OP" == "0" ]] && return

    echo
    echo -e "${RED}🗑️ Usuarios seleccionados:${RESET}"
    linea

    VALIDO=0

    for N in $OP; do

        USER="${LISTA[$N]}"

        if [[ -n "$USER" ]]; then
            echo -e "${WHITE} • $USER${RESET}"
            VALIDO=1
        fi

    done

    [[ "$VALIDO" -eq 0 ]] && {
        echo
        echo -e "${RED}✘ Selección inválida.${RESET}"
        sleep 2
        return
    }

    echo
    echo -e "${YELLOW}⚡ Eliminando automáticamente...${RESET}"
    echo

    BORRADOS=0
    FALLIDOS=0

    for N in $OP; do

        USER="${LISTA[$N]}"

        [[ -z "$USER" ]] && continue

        if eliminar_usuario "$USER"; then
            echo -e "${GREEN}✔${RESET} $USER"
            ((BORRADOS++))
        else
            echo -e "${RED}✘${RESET} $USER"
            ((FALLIDOS++))
        fi

    done

    echo
    linea

    echo -e "${GREEN}✔ Eliminados : $BORRADOS${RESET}"
    echo -e "${RED}✘ Fallidos   : $FALLIDOS${RESET}"

    linea
    echo

    read -n1 -s -r -p "Presione una tecla para continuar..."
}

#==================================================
# ELIMINAR TODOS
#==================================================

eliminar_todos() {

    titulo

    USERS=$(obtener_usuarios)

    if [[ -z "$USERS" ]]; then
        echo -e "${YELLOW}⚠ No existen usuarios SSH para eliminar.${RESET}"
        echo
        read -n1 -s -r -p "Presione una tecla para continuar..."
        return
    fi

    TOTAL=$(echo "$USERS" | wc -l)

    echo -e "${RED}💥 ELIMINACIÓN MASIVA${RESET}"
    linea

    echo -e "${WHITE}Se eliminarán automáticamente:${RESET}"
    echo

    while read -r USER; do
        echo -e "${RED} •${RESET} $USER"
    done <<< "$USERS"

    echo
    linea

    echo -e "${YELLOW}⚡ Eliminando $TOTAL usuarios...${RESET}"
    echo

    BORRADOS=0
    FALLIDOS=0

    while read -r USER; do

        [[ -z "$USER" ]] && continue

        if eliminar_usuario "$USER"; then
            echo -e "${GREEN}✔${RESET} $USER eliminado"
            ((BORRADOS++))
        else
            echo -e "${RED}✘${RESET} $USER no pudo eliminarse"
            ((FALLIDOS++))
        fi

    done <<< "$USERS"

    echo
    linea

    echo -e "${GREEN}╔══════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║       OPERACIÓN COMPLETADA          ║${RESET}"
    echo -e "${GREEN}╠══════════════════════════════════════╣${RESET}"
    printf "${GREEN}║${RESET} Eliminados : %-20s ${GREEN}║${RESET}\n" "$BORRADOS"
    printf "${RED}║${RESET} Fallidos   : %-20s ${RED}║${RESET}\n" "$FALLIDOS"
    echo -e "${GREEN}╚══════════════════════════════════════╝${RESET}"

    echo
    read -n1 -s -r -p "Presione una tecla para continuar..."
}

#==================================================
# MENÚ PRINCIPAL
#==================================================

while true; do

    titulo

    USERS=$(obtener_usuarios)

    TOTAL=0

    if [[ -n "$USERS" ]]; then
        TOTAL=$(echo "$USERS" | wc -l)
    fi

    echo -e "${WHITE}📊 ESTADO DEL SISTEMA${RESET}"
    linea

    echo -e " ${CYAN}👥 Usuarios SSH:${RESET} ${GREEN}$TOTAL${RESET}"
    echo

    echo -e "${WHITE}⚙️  OPCIONES${RESET}"
    linea

    echo -e " ${GREEN}[1]${RESET} 👤 Eliminar un usuario"
    echo -e " ${GREEN}[2]${RESET} 👥 Eliminar varios usuarios"
    echo -e " ${RED}[3]${RESET} 💥 Eliminar TODOS los usuarios"
    echo -e " ${BLUE}[4]${RESET} 📋 Ver usuarios"
    echo -e " ${GRAY}[0]${RESET} 🚪 Salir"

    linea
    echo

    read -rp "$(echo -e "${GREEN}➜ Seleccione una opción: ${RESET}")" OPCION

    case "$OPCION" in

        1)
            eliminar_uno
            ;;

        2)
            eliminar_varios
            ;;

        3)
            eliminar_todos
            ;;

        4)
            titulo
            mostrar_usuarios
            read -n1 -s -r -p "Presione una tecla para continuar..."
            ;;

        0)
            clear
            echo -e "${GREEN}✔ KevinTech Multi Script cerrado.${RESET}"
            exit 0
            ;;

        *)
            echo
            echo -e "${RED}✘ Opción inválida.${RESET}"
            sleep 1
            ;;

    esac

done