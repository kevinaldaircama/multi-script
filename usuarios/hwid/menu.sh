#!/bin/bash

# ============================================================
# KEVIN TECH - HWID MANAGER
# ============================================================

BASE="/etc/kevintech"
HWID_DIR="$BASE/usuarios/hwid"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

pause() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

header() {
    clear
    echo -e "${CYAN}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "          KEVIN TECH - HWID"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Debes ejecutar este menú como root.${NC}"
        exit 1
    fi
}

find_hwid_files() {
    if [[ ! -d "$HWID_DIR" ]]; then
        echo -e "${YELLOW}No existe el directorio HWID:${NC}"
        echo "$HWID_DIR"
        return 1
    fi

    find "$HWID_DIR" -type f 2>/dev/null
}

list_hwid() {
    header

    echo -e "${WHITE}📋 HWID registrados${NC}"
    echo

    if [[ ! -d "$HWID_DIR" ]]; then
        echo -e "${YELLOW}No existe el directorio HWID.${NC}"
        pause
        return
    fi

    local count
    count=$(find "$HWID_DIR" -type f 2>/dev/null | wc -l)

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}No hay registros HWID.${NC}"
        pause
        return
    fi

    echo -e "${GREEN}Registros encontrados: $count${NC}"
    echo

    find "$HWID_DIR" -type f -print | while read -r file; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}Archivo:${NC} $file"
        echo

        if [[ -s "$file" ]]; then
            cat "$file"
        else
            echo -e "${YELLOW}(vacío)${NC}"
        fi

        echo
    done

    pause
}

search_hwid() {
    header

    read -rp "🔎 Introduce usuario o HWID: " query

    if [[ -z "$query" ]]; then
        echo -e "${RED}No introdujiste ningún valor.${NC}"
        pause
        return
    fi

    echo
    echo -e "${WHITE}Resultados:${NC}"
    echo

    if grep -Rni -- "$query" "$HWID_DIR" 2>/dev/null; then
        echo
        echo -e "${GREEN}Búsqueda finalizada.${NC}"
    else
        echo -e "${YELLOW}No se encontraron resultados.${NC}"
    fi

    pause
}

show_hwid() {
    header

    read -rp "👤 Usuario: " username

    if [[ -z "$username" ]]; then
        echo -e "${RED}Usuario vacío.${NC}"
        pause
        return
    fi

    echo
    echo -e "${WHITE}HWID de:${NC} $username"
    echo

    local found=0

    while IFS= read -r file; do
        if grep -qi -- "$username" "$file" 2>/dev/null; then
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${WHITE}Archivo:${NC} $file"
            grep -i -- "$username" "$file"
            found=1
        fi
    done < <(find "$HWID_DIR" -type f 2>/dev/null)

    if [[ "$found" -eq 0 ]]; then
        echo -e "${YELLOW}No se encontró HWID para ese usuario.${NC}"
    fi

    pause
}

reset_hwid() {
    header

    read -rp "👤 Usuario cuyo HWID quieres resetear: " username

    if [[ -z "$username" ]]; then
        echo -e "${RED}Usuario vacío.${NC}"
        pause
        return
    fi

    echo
    echo -e "${YELLOW}⚠️ Esto eliminará el HWID asociado al usuario.${NC}"
    read -rp "Escribe SI para confirmar: " confirm

    if [[ "$confirm" != "SI" ]]; then
        echo -e "${YELLOW}Operación cancelada.${NC}"
        pause
        return
    fi

    local found=0

    while IFS= read -r file; do
        if grep -qi -- "$username" "$file" 2>/dev/null; then
            cp -a "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"

            sed -i "/$username/d" "$file"

            found=1
        fi
    done < <(find "$HWID_DIR" -type f 2>/dev/null)

    if [[ "$found" -eq 1 ]]; then
        echo -e "${GREEN}✅ HWID reseteado correctamente.${NC}"
    else
        echo -e "${YELLOW}No se encontró el usuario.${NC}"
    fi

    pause
}

delete_hwid_file() {
    header

    echo -e "${WHITE}Archivos HWID disponibles:${NC}"
    echo

    mapfile -t files < <(find "$HWID_DIR" -type f 2>/dev/null)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No hay archivos HWID.${NC}"
        pause
        return
    fi

    local i=1

    for file in "${files[@]}"; do
        echo "$i) $file"
        ((i++))
    done

    echo

    read -rp "Selecciona archivo: " option

    if ! [[ "$option" =~ ^[0-9]+$ ]] ||
       (( option < 1 || option > ${#files[@]} )); then
        echo -e "${RED}Opción inválida.${NC}"
        pause
        return
    fi

    local selected="${files[$((option-1))]}"

    echo
    echo -e "${RED}⚠️ Vas a eliminar:${NC}"
    echo "$selected"
    echo

    read -rp "Escribe ELIMINAR para confirmar: " confirm

    if [[ "$confirm" != "ELIMINAR" ]]; then
        echo -e "${YELLOW}Operación cancelada.${NC}"
        pause
        return
    fi

    cp -a "$selected" "$selected.bak.$(date +%Y%m%d%H%M%S)"
    rm -f -- "$selected"

    echo -e "${GREEN}✅ Archivo eliminado.${NC}"

    pause
}

backup_hwid() {
    header

    mkdir -p "$BASE/backups"

    local backup="$BASE/backups/hwid-$(date +%Y%m%d-%H%M%S).tar.gz"

    if [[ ! -d "$HWID_DIR" ]]; then
        echo -e "${RED}No existe el directorio HWID.${NC}"
        pause
        return
    fi

    tar -czf "$backup" -C "$BASE" "usuarios/hwid"

    chmod 600 "$backup"

    echo -e "${GREEN}✅ Backup creado:${NC}"
    echo "$backup"

    pause
}

main_menu() {
    while true; do
        header

        echo "1) 📋 Listar HWID"
        echo "2) 🔎 Buscar HWID"
        echo "3) 👤 Consultar HWID de usuario"
        echo "4) 🔄 Resetear HWID"
        echo "5) 🗑️ Eliminar archivo HWID"
        echo "6) 💾 Crear backup"
        echo "0) 🚪 Salir"
        echo

        read -rp "Selecciona una opción: " option

        case "$option" in
            1) list_hwid ;;
            2) search_hwid ;;
            3) show_hwid ;;
            4) reset_hwid ;;
            5) delete_hwid_file ;;
            6) backup_hwid ;;
            0)
                clear
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida.${NC}"
                sleep 1
                ;;
        esac
    done
}

check_root
main_menu
