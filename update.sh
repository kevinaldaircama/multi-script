#!/bin/bash

#=========================================================
#        KEVIN TECH MULTI SCRIPT - UPDATER
#        Sistema de actualización + Licencia KEY
#=========================================================

BASE="/etc/kevintech"
TMP="/tmp/kevintech_update"
REPO="https://github.com/kevinaldaircama/multi-script.git"
VERSION_FILE="$BASE/version.txt"

#=========================================================
# CONFIGURACIÓN DE LICENCIA
#=========================================================

FIREBASE_URL_B64="aHR0cHM6Ly9rZXlnZW5icHQtZGVmYXVsdC1ydGRiLmZpcmViYXNlaW8uY29t"
FIREBASE_URL=$(echo "$FIREBASE_URL_B64" | base64 -d 2>/dev/null)

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
# COMPROBAR DEPENDENCIAS
#=========================================================

if [[ $EUID -ne 0 ]]; then

    echo -e "${RED}❌ Este actualizador necesita ejecutarse como root.${RESET}"
    echo ""

    if command -v sudo >/dev/null 2>&1; then
        exec sudo bash "$0" "$@"
    else
        exit 1
    fi

fi

#=========================================================
# DEPENDENCIAS DE LICENCIA
#=========================================================

if ! command -v curl >/dev/null 2>&1 ||
   ! command -v jq >/dev/null 2>&1; then

    echo -e "${CYAN}◆ Instalando dependencias necesarias...${RESET}"

    apt-get update -y >/dev/null 2>&1

    apt-get install -y \
        curl \
        jq \
        ca-certificates \
        git >/dev/null 2>&1

fi

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
# LICENCIA KEY
#=========================================================

echo -e "${GOLD}${BOLD}◆ AUTORIZACIÓN DE ACTUALIZACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e " ${YELLOW}🔐 Esta actualización requiere una Key válida.${RESET}"
echo -e " ${GRAY}La Key se obtiene desde el sistema de licencias.${RESET}"
echo ""

while true; do

    read -rp " 🔑 Introduce tu Key de Instalación: " INSTALL_KEY

    # Eliminar espacios, CR y LF
    INSTALL_KEY=$(echo "$INSTALL_KEY" | tr -d '\r\n ')

    if [[ -z "$INSTALL_KEY" ]]; then

        error "La Key no puede estar vacía."
        echo ""
        continue

    fi

    echo ""

    info "Verificando licencia..."

    KEY_RESPONSE=""

    #-----------------------------------------------------
    # CONSULTAR FIREBASE
    #-----------------------------------------------------

    KEY_RESPONSE=$(curl \
        -4 \
        -s \
        -k \
        --connect-timeout 10 \
        --max-time 15 \
        "${FIREBASE_URL}/keys/${INSTALL_KEY}.json" 2>/dev/null)

    #-----------------------------------------------------
    # COMPROBAR CONEXIÓN
    #-----------------------------------------------------

    if [[ -z "$KEY_RESPONSE" ]]; then

        error "No fue posible conectar con el servidor de licencias."
        echo ""

        echo -e " ${YELLOW}⚠${RESET} Comprueba tu conexión a Internet."
        echo ""

        sleep 2
        continue

    fi

    #-----------------------------------------------------
    # KEY INEXISTENTE
    #-----------------------------------------------------

    if [[ "$KEY_RESPONSE" == "null" ]]; then

        error "La Key es inválida, ya fue utilizada o no existe."
        echo ""

        sleep 2
        continue

    fi

    #-----------------------------------------------------
    # COMPROBAR QUE SEA JSON VÁLIDO
    #-----------------------------------------------------

    if ! echo "$KEY_RESPONSE" | jq empty >/dev/null 2>&1; then

        error "El servidor de licencias devolvió una respuesta inválida."
        echo ""

        sleep 2
        continue

    fi

    #-----------------------------------------------------
    # OBTENER DATOS DE LA KEY
    #-----------------------------------------------------

    OWNER=$(echo "$KEY_RESPONSE" | jq -r '.owner // empty')
    RESELLER=$(echo "$KEY_RESPONSE" | jq -r '.reseller // empty')

    #-----------------------------------------------------
    # COMPROBAR ESTADO
    #-----------------------------------------------------

    KEY_STATUS=$(echo "$KEY_RESPONSE" | jq -r '.status // "active"')

    if [[ "$KEY_STATUS" != "active" ]]; then

        error "La Key no está activa."
        echo -e " ${GRAY}Estado:${RESET} ${YELLOW}$KEY_STATUS${RESET}"
        echo ""

        sleep 2
        continue

    fi

    #-----------------------------------------------------
    # KEY CORRECTA
    #-----------------------------------------------------

    echo ""
    ok "Licencia verificada correctamente."

    echo ""

    echo -e " ${GRAY}Propietario:${RESET} ${WHITE}${OWNER:-No definido}${RESET}"
    echo -e " ${GRAY}Reseller:${RESET}    ${WHITE}${RESELLER:-No definido}${RESET}"

    echo ""

    break

done

#=========================================================
# INFORMACIÓN DEL SERVIDOR
#=========================================================

info "Recopilando información del servidor..."

CLIENT_IP=$(curl \
    -4 \
    -s \
    --connect-timeout 5 \
    --max-time 10 \
    ifconfig.me 2>/dev/null)

if [[ -z "$CLIENT_IP" ]]; then
    CLIENT_IP="Desconocida"
fi

OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release |
    cut -d'"' -f2)

[[ -z "$OS_NAME" ]] && OS_NAME="Desconocido"

HOSTNAME_SERVER=$(hostname)

DATE_NOW=$(date "+%Y-%m-%d %H:%M:%S")

echo ""

echo -e "${CYAN}${BOLD}◆ INFORMACIÓN DE ACTIVACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e " ${GRAY}IP:${RESET}       ${WHITE}$CLIENT_IP${RESET}"
echo -e " ${GRAY}Hostname:${RESET} ${WHITE}$HOSTNAME_SERVER${RESET}"
echo -e " ${GRAY}Sistema:${RESET}   ${WHITE}$OS_NAME${RESET}"
echo -e " ${GRAY}Fecha:${RESET}     ${WHITE}$DATE_NOW${RESET}"

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

    echo ""
    echo -e "${YELLOW}⚠${RESET} La Key NO será eliminada."

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
# REGISTRAR ACTIVACIÓN
#=========================================================

echo ""

echo -e "${GOLD}${BOLD}◆ REGISTRANDO ACTIVACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

info "Enviando información al servidor de licencias..."

ACTIVATION_RESPONSE=$(curl \
    -4 \
    -s \
    -k \
    --connect-timeout 10 \
    --max-time 15 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg owner "$OWNER" \
        --arg reseller "$RESELLER" \
        --arg token "$INSTALL_KEY" \
        --arg ip "$CLIENT_IP" \
        --arg hostname "$HOSTNAME_SERVER" \
        --arg os "$OS_NAME" \
        --arg date "$DATE_NOW" \
        '{
            owner: $owner,
            reseller: $reseller,
            token: $token,
            ip: $ip,
            hostname: $hostname,
            os: $os,
            date: $date,
            notified: false,
            version: "UPDATE"
        }')" \
    "${FIREBASE_URL}/activations.json" 2>/dev/null)

#=========================================================
# ELIMINAR KEY
#=========================================================

if [[ -n "$ACTIVATION_RESPONSE" ]]; then

    echo ""

    info "Finalizando licencia..."

    DELETE_RESPONSE=$(curl \
        -4 \
        -s \
        -k \
        --connect-timeout 10 \
        --max-time 15 \
        -X DELETE \
        "${FIREBASE_URL}/keys/${INSTALL_KEY}.json" 2>/dev/null)

    ok "Key consumida correctamente."

else

    echo ""

    error "No se pudo registrar la activación."

    echo -e " ${YELLOW}⚠${RESET} La actualización ya fue instalada."
    echo -e " ${YELLOW}⚠${RESET} La Key NO fue eliminada."

fi

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

echo -e " ${CYAN}◆${RESET} ${WHITE}Licencia:${RESET} ${GREEN}VERIFICADA${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Propietario:${RESET} ${WHITE}${OWNER:-No definido}${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Reseller:${RESET} ${WHITE}${RESELLER:-No definido}${RESET}"

echo ""

echo -e "${CYAN}🚀${RESET} ${WHITE}Reiniciando panel...${RESET}"

sleep 2

#=========================================================
# REGRESAR AL MENÚ
#=========================================================

exec "$BASE/menu.sh"
