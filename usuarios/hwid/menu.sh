#!/bin/bash

# ============================================================
#              KEVIN TECH - HWID MANAGER
# ============================================================

BASE="/etc/kevintech"
HWID_DIR="$BASE/usuarios/hwid"
BACKUP_DIR="$BASE/backups"

# ============================================================
# COLORES
# ============================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

BOLD='\033[1m'

# ============================================================
# FUNCIONES GENERALES
# ============================================================

pause() {
    echo
    read -rp "  Presiona ENTER para continuar..."
}

header() {
    clear

    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║              ${WHITE}KEVIN TECH${CYAN} - ${WHITE}HWID MANAGER${CYAN}             ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "  ${GRAY}Directorio:${NC} ${WHITE}$HWID_DIR${NC}"
    echo
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo
        echo -e "${RED}✖ ERROR${NC}"
        echo -e "  Este administrador debe ejecutarse como ${WHITE}root${NC}."
        echo
        exit 1
    fi
}

check_directory() {
    if [[ ! -d "$HWID_DIR" ]]; then
        mkdir -p "$HWID_DIR"
    fi
}

get_files() {
    find "$HWID_DIR" -type f 2>/dev/null | sort
}

count_files() {
    get_files | wc -l
}

count_lines() {
    local total=0

    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        local lines
        lines=$(wc -l < "$file" 2>/dev/null)

        total=$((total + lines))
    done < <(get_files)

    echo "$total"
}

# ============================================================
# BANNER DE SECCIÓN
# ============================================================

section() {
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# ============================================================
# ESTADÍSTICAS
# ============================================================

show_stats() {
    local files
    local records

    files=$(count_files)
    records=$(count_lines)

    echo -e "  ${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "  ${BLUE}│${NC} ${WHITE}ARCHIVOS HWID${NC}       ${GREEN}$files${NC}"
    echo -e "  ${BLUE}│${NC} ${WHITE}REGISTROS${NC}           ${GREEN}$records${NC}"
    echo -e "  ${BLUE}│${NC} ${WHITE}ESTADO${NC}              ${GREEN}● ACTIVO${NC}"
    echo -e "  ${BLUE}└─────────────────────────────────────────┘${NC}"
}

# ============================================================
# LISTAR HWID
# ============================================================

list_hwid() {
    header
    section "📋 LISTADO DE HWID"

    local files
    files=$(get_files)

    if [[ -z "$files" ]]; then
        echo -e "  ${YELLOW}⚠ No existen registros HWID.${NC}"
        pause
        return
    fi

    local number=1

    while IFS= read -r file; do
        echo -e "  ${MAGENTA}[$number]${NC} ${WHITE}$(basename "$file")${NC}"
        echo -e "      ${GRAY}$file${NC}"

        if [[ -s "$file" ]]; then
            echo -e "      ${GREEN}● Contenido:${NC}"

            while IFS= read -r line; do
                [[ -n "$line" ]] && \
                    echo -e "        ${CYAN}→${NC} $line"
            done < "$file"
        else
            echo -e "      ${YELLOW}○ Archivo vacío${NC}"
        fi

        echo
        ((number++))

    done <<< "$files"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}✓ Total de archivos: $((number - 1))${NC}"

    pause
}

# ============================================================
# BUSCAR
# ============================================================

search_hwid() {
    header
    section "🔎 BUSCAR HWID"

    read -rp "  Introduce usuario o HWID: " query

    if [[ -z "$query" ]]; then
        echo -e "  ${RED}✖ Debes introducir un valor.${NC}"
        pause
        return
    fi

    echo
    echo -e "  ${GRAY}Buscando:${NC} ${WHITE}$query${NC}"
    echo

    local found=0

    while IFS= read -r file; do

        if grep -Fqi -- "$query" "$file" 2>/dev/null; then

            echo -e "${CYAN}  ┌─────────────────────────────────────────────${NC}"
            echo -e "${CYAN}  │${NC} ${WHITE}$(basename "$file")${NC}"
            echo -e "${CYAN}  └─────────────────────────────────────────────${NC}"

            grep -Fin -- "$query" "$file" 2>/dev/null

            echo
            found=1

        fi

    done < <(get_files)

    if [[ "$found" -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ No se encontraron coincidencias.${NC}"
    else
        echo -e "  ${GREEN}✓ Búsqueda completada.${NC}"
    fi

    pause
}

# ============================================================
# CONSULTAR USUARIO
# ============================================================

show_hwid() {
    header
    section "👤 CONSULTAR USUARIO"

    read -rp "  Usuario: " username

    if [[ -z "$username" ]]; then
        echo -e "  ${RED}✖ Usuario vacío.${NC}"
        pause
        return
    fi

    echo
    echo -e "  ${GRAY}Consultando:${NC} ${WHITE}$username${NC}"
    echo

    local found=0

    while IFS= read -r file; do

        if grep -Fqi -- "$username" "$file" 2>/dev/null; then

            echo -e "${GREEN}  ┌─────────────────────────────────────────────${NC}"
            echo -e "${GREEN}  │${NC} ${WHITE}USUARIO ENCONTRADO${NC}"
            echo -e "${GREEN}  └─────────────────────────────────────────────${NC}"

            echo -e "  ${GRAY}Archivo:${NC} $(basename "$file")"
            echo

            grep -Fi -- "$username" "$file"

            echo
            found=1
        fi

    done < <(get_files)

    if [[ "$found" -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ No se encontró el usuario.${NC}"
    fi

    pause
}

# ============================================================
# RESET HWID
# ============================================================

reset_hwid() {
    header
    section "🔄 RESETEAR HWID"

    read -rp "  Usuario: " username

    if [[ -z "$username" ]]; then
        echo -e "  ${RED}✖ Usuario vacío.${NC}"
        pause
        return
    fi

    echo
    echo -e "  ${YELLOW}⚠ ADVERTENCIA${NC}"
    echo
    echo -e "  Se eliminarán las líneas asociadas a:"
    echo -e "  ${WHITE}$username${NC}"
    echo

    read -rp "  Escribe CONFIRMAR para continuar: " confirm

    if [[ "$confirm" != "CONFIRMAR" ]]; then
        echo
        echo -e "  ${YELLOW}○ Operación cancelada.${NC}"
        pause
        return
    fi

    local found=0
    local changed=0

    while IFS= read -r file; do

        if grep -Fqi -- "$username" "$file" 2>/dev/null; then

            local backup_file
            backup_file="${file}.bak.$(date +%Y%m%d-%H%M%S)"

            cp -a -- "$file" "$backup_file"

            # Uso de awk para evitar problemas con caracteres
            # especiales que puedan existir en el nombre.
            awk -v search="$username" '
                index(tolower($0), tolower(search)) == 0 {
                    print
                }
            ' "$file" > "${file}.tmp"

            mv -f -- "${file}.tmp" "$file"

            echo -e "  ${GREEN}✓ HWID eliminado:${NC} $(basename "$file")"
            echo -e "  ${GRAY}Backup:${NC} $backup_file"

            found=1
            changed=1
        fi

    done < <(get_files)

    echo

    if [[ "$changed" -eq 1 ]]; then
        echo -e "  ${GREEN}✔ HWID reseteado correctamente.${NC}"
    elif [[ "$found" -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ No se encontró el usuario.${NC}"
    fi

    pause
}

# ============================================================
# ELIMINAR ARCHIVO
# ============================================================

delete_hwid_file() {
    header
    section "🗑️ ELIMINAR ARCHIVO HWID"

    mapfile -t files < <(get_files)

    if [[ "${#files[@]}" -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ No existen archivos HWID.${NC}"
        pause
        return
    fi

    echo -e "  ${WHITE}Archivos disponibles:${NC}"
    echo

    local i=1

    for file in "${files[@]}"; do
        echo -e "  ${MAGENTA}$i)${NC} $(basename "$file")"
        ((i++))
    done

    echo
    read -rp "  Selecciona archivo: " option

    if ! [[ "$option" =~ ^[0-9]+$ ]]; then
        echo -e "  ${RED}✖ Opción inválida.${NC}"
        pause
        return
    fi

    if (( option < 1 || option > ${#files[@]} )); then
        echo -e "  ${RED}✖ Opción fuera de rango.${NC}"
        pause
        return
    fi

    local selected="${files[$((option - 1))]}"

    echo
    echo -e "  ${RED}⚠ ARCHIVO SELECCIONADO${NC}"
    echo
    echo -e "  ${WHITE}$(basename "$selected")${NC}"
    echo -e "  ${GRAY}$selected${NC}"
    echo

    read -rp "  Escribe ELIMINAR para confirmar: " confirm

    if [[ "$confirm" != "ELIMINAR" ]]; then
        echo -e "  ${YELLOW}○ Operación cancelada.${NC}"
        pause
        return
    fi

    local backup
    backup="${selected}.bak.$(date +%Y%m%d-%H%M%S)"

    cp -a -- "$selected" "$backup"
    rm -f -- "$selected"

    echo
    echo -e "  ${GREEN}✔ Archivo eliminado.${NC}"
    echo -e "  ${GRAY}Backup guardado en:${NC}"
    echo -e "  $backup"

    pause
}

# ============================================================
# BACKUP GENERAL
# ============================================================

backup_hwid() {
    header
    section "💾 CREAR BACKUP"

    if [[ ! -d "$HWID_DIR" ]]; then
        echo -e "  ${YELLOW}⚠ No existe el directorio HWID.${NC}"
        pause
        return
    fi

    mkdir -p "$BACKUP_DIR"

    local backup
    backup="$BACKUP_DIR/hwid-$(date +%Y%m%d-%H%M%S).tar.gz"

    if tar -czf "$backup" -C "$BASE" "usuarios/hwid" 2>/dev/null; then

        chmod 600 "$backup"

        echo -e "  ${GREEN}✔ BACKUP CREADO${NC}"
        echo
        echo -e "  ${GRAY}Archivo:${NC}"
        echo -e "  ${WHITE}$backup${NC}"
        echo
        echo -e "  ${GRAY}Tamaño:${NC} $(du -h "$backup" | awk '{print $1}')"

    else

        echo -e "  ${RED}✖ No se pudo crear el backup.${NC}"

    fi

    pause
}

# ============================================================
# LISTAR BACKUPS
# ============================================================

list_backups() {
    header
    section "📦 BACKUPS DISPONIBLES"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "  ${YELLOW}⚠ No existe ningún backup.${NC}"
        pause
        return
    fi

    mapfile -t backups < <(
        find "$BACKUP_DIR" \
            -maxdepth 1 \
            -type f \
            -name "hwid-*.tar.gz" \
            2>/dev/null | sort -r
    )

    if [[ "${#backups[@]}" -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ No existen backups.${NC}"
        pause
        return
    fi

    local i=1

    for backup in "${backups[@]}"; do
        local size
        size=$(du -h "$backup" | awk '{print $1}')

        echo -e "  ${MAGENTA}$i)${NC} ${WHITE}$(basename "$backup")${NC}"
        echo -e "      ${GRAY}Tamaño: $size${NC}"

        ((i++))
    done

    echo
    echo -e "  ${GREEN}✓ ${#backups[@]} backup(s) encontrado(s).${NC}"

    pause
}

# ============================================================
# LIMPIAR BACKUPS ANTIGUOS
# ============================================================

clean_backups() {
    header
    section "🧹 LIMPIAR BACKUPS"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "  ${YELLOW}⚠ No existen backups.${NC}"
        pause
        return
    fi

    echo -e "  ${WHITE}Esta opción elimina backups antiguos.${NC}"
    echo
    echo -e "  ${YELLOW}Se conservarán los últimos 5 backups.${NC}"
    echo

    read -rp "  Escribe LIMPIAR para confirmar: " confirm

    if [[ "$confirm" != "LIMPIAR" ]]; then
        echo -e "  ${YELLOW}○ Operación cancelada.${NC}"
        pause
        return
    fi

    mapfile -t backups < <(
        find "$BACKUP_DIR" \
            -maxdepth 1 \
            -type f \
            -name "hwid-*.tar.gz" \
            2>/dev/null | sort -r
    )

    local total="${#backups[@]}"

    if (( total <= 5 )); then
        echo
        echo -e "  ${GREEN}✓ No hay backups antiguos para eliminar.${NC}"
        pause
        return
    fi

    for ((i=5; i<total; i++)); do
        rm -f -- "${backups[$i]}"
    done

    echo
    echo -e "  ${GREEN}✔ Limpieza completada.${NC}"
    echo -e "  ${GRAY}Backups eliminados: $((total - 5))${NC}"

    pause
}

# ============================================================
# INFORMACIÓN DEL SISTEMA
# ============================================================

system_info() {
    header
    section "ℹ️ INFORMACIÓN"

    echo -e "  ${WHITE}KEVIN TECH - HWID MANAGER${NC}"
    echo
    echo -e "  ${GRAY}Base:${NC}"
    echo -e "  $BASE"
    echo
    echo -e "  ${GRAY}HWID:${NC}"
    echo -e "  $HWID_DIR"
    echo
    echo -e "  ${GRAY}Backups:${NC}"
    echo -e "  $BACKUP_DIR"
    echo

    show_stats

    echo
    echo -e "  ${GRAY}Usuario:${NC} $(whoami)"
    echo -e "  ${GRAY}Hostname:${NC} $(hostname)"
    echo -e "  ${GRAY}Fecha:${NC} $(date '+%Y-%m-%d %H:%M:%S')"

    pause
}

# ============================================================
# MENÚ PRINCIPAL
# ============================================================

main_menu() {

    while true; do

        header

        show_stats

        echo

        echo -e "  ${WHITE}GESTIÓN DE HWID${NC}"
        echo
        echo -e "  ${CYAN}01${NC}  📋 Listar HWID"
        echo -e "  ${CYAN}02${NC}  🔎 Buscar HWID"
        echo -e "  ${CYAN}03${NC}  👤 Consultar usuario"
        echo -e "  ${CYAN}04${NC}  🔄 Resetear HWID"
        echo -e "  ${CYAN}05${NC}  🗑️  Eliminar archivo"
        echo

        echo -e "  ${WHITE}BACKUPS${NC}"
        echo
        echo -e "  ${CYAN}06${NC}  💾 Crear backup"
        echo -e "  ${CYAN}07${NC}  📦 Ver backups"
        echo -e "  ${CYAN}08${NC}  🧹 Limpiar backups"
        echo

        echo -e "  ${WHITE}SISTEMA${NC}"
        echo
        echo -e "  ${CYAN}09${NC}  ℹ️  Información"
        echo -e "  ${RED}00${NC}  🚪 Salir"

        echo
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo

        read -rp "  Selecciona una opción: " option

        case "$option" in

            1|01)
                list_hwid
                ;;

            2|02)
                search_hwid
                ;;

            3|03)
                show_hwid
                ;;

            4|04)
                reset_hwid
                ;;

            5|05)
                delete_hwid_file
                ;;

            6|06)
                backup_hwid
                ;;

            7|07)
                list_backups
                ;;

            8|08)
                clean_backups
                ;;

            9|09)
                system_info
                ;;

            0|00)
                clear
                echo
                echo -e "  ${GREEN}✓ KEVIN TECH${NC}"
                echo -e "  ${GRAY}HWID Manager cerrado.${NC}"
                echo
                exit 0
                ;;

            *)
                echo
                echo -e "  ${RED}✖ Opción inválida.${NC}"
                sleep 1
                ;;

        esac

    done
}

# ============================================================
# INICIO
# ============================================================

check_root
check_directory
main_menu
