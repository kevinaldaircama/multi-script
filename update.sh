#!/bin/bash

#=========================================================
#        KEVIN TECH MULTI SCRIPT - UPDATER
#=========================================================

BASE="/etc/kevintech"
TMP="/tmp/kevintech_update"
REPO="https://github.com/kevinaldaircama/multi-script.git"
VERSION_FILE="$BASE/version.txt"

#=========================================================
# COLORES
#=========================================================

RESET="\e[0m"

RED="\e[1;91m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
BLUE="\e[1;94m"
BOLD="\e[1m"
MAGENTA="\e[1;95m"
CYAN="\e[1;96m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

GOLD="\e[38;5;220m"
SKY="\e[38;5;117m"
PURPLE="\e[38;5;141m"
LIME="\e[38;5;154m"

#=========================================================
# FUNCIONES
#=========================================================

titulo() {

    clear

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}              KEVIN TECH UPDATER${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}                 MULTI SCRIPT PREMIUM${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

}

ok() {
    echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"
}

info() {
    echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"
}

error() {
    echo -e " ${RED}✘${RESET} ${WHITE}$1${RESET}"
}

#=========================================================
# INICIO
#=========================================================

titulo

echo -e "${GOLD}${BOLD}◆ ACTUALIZACIÓN DEL SISTEMA${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

info "Preparando actualización..."
echo -e " ${GRAY}➜${RESET} Repositorio: ${SKY}$REPO${RESET}"
echo -e " ${GRAY}➜${RESET} Destino:     ${SKY}$BASE${RESET}"

echo ""

#=========================================================
# VERIFICAR DIRECTORIO
#=========================================================

if [[ ! -d "$BASE" ]]; then

    error "No existe el directorio $BASE"

    echo ""
    echo -e "${YELLOW}⚠${RESET} ${WHITE}El script principal no parece estar instalado.${RESET}"
    echo ""

    exit 1

fi

#=========================================================
# VERSIÓN INSTALADA
#=========================================================

VERSION_ACTUAL="No disponible"

if [[ -f "$VERSION_FILE" ]]; then

    VERSION_ACTUAL=$(head -n1 "$VERSION_FILE" | tr -d '\r')

fi

[[ -z "$VERSION_ACTUAL" ]] && VERSION_ACTUAL="No disponible"

echo -e "${BLUE}${BOLD}◆ INFORMACIÓN DE VERSIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e " ${YELLOW}Versión instalada:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"

echo ""

#=========================================================
# LIMPIAR TEMPORAL
#=========================================================

info "Preparando archivos temporales..."

rm -rf "$TMP"

mkdir -p "$TMP"

echo ""

#=========================================================
# DESCARGAR ACTUALIZACIÓN
#=========================================================

echo -e "${MAGENTA}${BOLD}◆ DESCARGANDO ACTUALIZACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e " ${CYAN}⬇${RESET} ${WHITE}Conectando con GitHub...${RESET}"

if ! git clone --depth 1 "$REPO" "$TMP"; then

    echo ""

    error "No se pudo descargar la actualización."

    echo ""
    echo -e " ${YELLOW}⚠${RESET} ${WHITE}Comprueba:${RESET}"
    echo -e "   ${GRAY}•${RESET} Conexión a Internet"
    echo -e "   ${GRAY}•${RESET} Acceso a GitHub"
    echo -e "   ${GRAY}•${RESET} Que el repositorio esté disponible"
    echo ""

    rm -rf "$TMP"

    exit 1

fi

echo ""
ok "Actualización descargada correctamente."

#=========================================================
# LEER NUEVA VERSIÓN
#=========================================================

NUEVA_VERSION="No disponible"

if [[ -f "$TMP/version.txt" ]]; then

    NUEVA_VERSION=$(head -n1 "$TMP/version.txt" | tr -d '\r')

fi

[[ -z "$NUEVA_VERSION" ]] && NUEVA_VERSION="No disponible"

echo ""
echo -e "${PURPLE}${BOLD}◆ CONTROL DE VERSIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e " ${YELLOW}Versión actual:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"
echo -e " ${GREEN}Nueva versión:${RESET}  ${LIME}${NUEVA_VERSION}${RESET}"

echo ""

#=========================================================
# INSTALAR ARCHIVOS
#=========================================================

echo -e "${BLUE}${BOLD}◆ INSTALANDO ARCHIVOS${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

info "Copiando nuevos archivos..."

if ! cp -rf "$TMP"/. "$BASE/"; then

    echo ""

    error "No se pudieron copiar los archivos."

    rm -rf "$TMP"

    exit 1

fi

ok "Archivos instalados correctamente."

#=========================================================
# GUARDAR VERSIÓN
#=========================================================

if [[ -f "$TMP/version.txt" ]]; then

    cp -f "$TMP/version.txt" "$VERSION_FILE"

    ok "Versión instalada: ${NUEVA_VERSION}"

else

    echo ""
    echo -e "${YELLOW}⚠${RESET} ${WHITE}No se encontró version.txt en la actualización.${RESET}"

fi

#=========================================================
# PERMISOS
#=========================================================

echo ""

info "Aplicando permisos..."

chmod -R +x "$BASE"

ok "Permisos actualizados."

#=========================================================
# LIMPIEZA
#=========================================================

echo ""

info "Limpiando archivos temporales..."

rm -rf "$TMP"

ok "Limpieza completada."

#=========================================================
# FINAL
#=========================================================

echo ""

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}          ✅ ACTUALIZACIÓN COMPLETADA${RESET}              ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET} ${GRAY}          Kevin Tech Multi Script Premium${RESET}           ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo ""

echo -e " ${CYAN}◆${RESET} ${WHITE}Versión anterior:${RESET} ${GRAY}${VERSION_ACTUAL}${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Versión instalada:${RESET} ${GREEN}${NUEVA_VERSION}${RESET}"

echo ""
echo -e "${CYAN}🚀${RESET} ${WHITE}Reiniciando panel...${RESET}"

sleep 2

#=========================================================
# REGRESAR AL MENÚ
#=========================================================

exec "$BASE/menu.sh"
