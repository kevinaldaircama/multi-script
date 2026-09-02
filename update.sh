#!/bin/bash

#=========================================================
#        KEVIN TECH MULTI SCRIPT - UPDATER
#        Sistema de actualización + Licencia KEY
#        LICENSE API v2.2
#=========================================================

set -o pipefail

#=========================================================
# VARIABLES
#=========================================================

BASE="/etc/kevintech"
TMP="/tmp/kevintech_update"

REPO="https://github.com/kevinaldaircama/multi-script.git"

VERSION_FILE="$BASE/version.txt"

LICENSE_API="https://usa.socialstreaming.xyz"

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
# VARIABLES DE LICENCIA
#=========================================================

INSTALL_KEY=""
AUTO_MODE=false
BOT_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true
[[ "${1:-}" == "--bot" ]] && BOT_MODE=true

LICENSE_OWNER=""
LICENSE_RESELLER=""
LICENSE_TYPE="normal"
LICENSE_DELETE_AT=""

#=========================================================
# VARIABLES DEL SERVIDOR
#=========================================================

CLIENT_IP=""
OS_NAME=""
HOSTNAME_SERVER=""
DATE_NOW=""

VERSION_ACTUAL="No disponible"
NUEVA_VERSION="No disponible"

#=========================================================
# FUNCIONES
#=========================================================

titulo() {

    clear 2>/dev/null || true

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET} ${WHITE}${BOLD}              KEVIN TECH UPDATER${RESET}                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET} ${GRAY}                 MULTI SCRIPT PREMIUM${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo

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

warning() {
    echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"
}

#=========================================================
# ERROR
#=========================================================

error_exit() {

    echo
    error "$1"
    echo

    rm -rf "$TMP"

    exit 1
}

#=========================================================
# ROOT
#=========================================================

if [[ "$EUID" -ne 0 ]]; then

    echo -e "${RED}❌ Este actualizador necesita ejecutarse como root.${RESET}"
    echo

    if command -v sudo >/dev/null 2>&1; then

        exec sudo bash "$0" "$@"

    else

        exit 1

    fi

fi

#=========================================================
# COMPROBAR INSTALACIÓN
#=========================================================

if [[ ! -d "$BASE" ]]; then

    error "No existe el directorio $BASE."

    echo
    echo -e "${YELLOW}⚠ El sistema KevinTech no parece estar instalado.${RESET}"
    echo

    exit 1

fi

#=========================================================
# DEPENDENCIAS
#=========================================================

MISSING=""

command -v curl >/dev/null 2>&1 || MISSING+=" curl"
command -v jq >/dev/null 2>&1 || MISSING+=" jq"
command -v git >/dev/null 2>&1 || MISSING+=" git"

if [[ -n "$MISSING" ]]; then

    echo -e "${CYAN}◆ Instalando dependencias:${RESET}${WHITE}$MISSING${RESET}"
    echo

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y >/dev/null 2>&1 || \
        error_exit "No se pudieron actualizar los repositorios."

    apt-get install -y \
        curl \
        jq \
        git \
        ca-certificates \
        >/dev/null 2>&1 || \
        error_exit "No se pudieron instalar las dependencias."

fi

#=========================================================
# INICIO
#=========================================================

titulo

echo -e "${GOLD}${BOLD}◆ ACTUALIZACIÓN DEL SISTEMA${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

info "Preparando actualización..."

echo -e " ${GRAY}➜${RESET} Repositorio: ${SKY}$REPO${RESET}"
echo -e " ${GRAY}➜${RESET} Destino:     ${SKY}$BASE${RESET}"
echo -e " ${GRAY}➜${RESET} License API: ${SKY}$LICENSE_API${RESET}"

echo

#=========================================================
# VERSIÓN INSTALADA
#=========================================================

if [[ -f "$VERSION_FILE" ]]; then

    VERSION_ACTUAL="$(
        head -n1 "$VERSION_FILE" |
        tr -d '\r'
    )"

fi

[[ -z "$VERSION_ACTUAL" ]] && \
    VERSION_ACTUAL="No disponible"

echo -e "${BLUE}${BOLD}◆ INFORMACIÓN DE VERSIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${YELLOW}Versión instalada:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"

echo

#=========================================================
# VERIFICAR SERVIDOR DE LICENCIAS
#=========================================================

echo -e "${GOLD}${BOLD}◆ SERVIDOR DE LICENCIAS${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

info "Comprobando API..."

HEALTH_RESPONSE="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        -4 \
        -w '\n%{http_code}' \
        "${LICENSE_API}/health" \
        2>/dev/null
)"

HEALTH_HTTP="$(
    printf '%s\n' "$HEALTH_RESPONSE" |
    tail -n1
)"

HEALTH_BODY="$(
    printf '%s\n' "$HEALTH_RESPONSE" |
    sed '$d'
)"

if [[ "$HEALTH_HTTP" != "200" ]]; then

    error "Servidor de licencias no disponible."

    echo
    echo -e "${GRAY}HTTP: $HEALTH_HTTP${RESET}"
    echo

    exit 1

fi

if ! echo "$HEALTH_BODY" |
    jq -e '.ok == true' >/dev/null 2>&1; then

    error "La API de licencias devolvió un estado inválido."

    echo
    echo "$HEALTH_BODY"
    echo

    exit 1

fi

ok "Servidor de licencias disponible."

echo

if [[ "$BOT_MODE" != true ]]; then

#=========================================================
# LICENCIA
#=========================================================

echo -e "${GOLD}${BOLD}◆ AUTORIZACIÓN DE ACTUALIZACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${YELLOW}🔐 Esta actualización requiere una Key válida.${RESET}"
echo -e " ${GRAY}La Key será validada mediante la API pública.${RESET}"
echo

if [[ "$AUTO_MODE" == true && -f "$BASE/license.conf" ]]; then
    INSTALL_KEY="$(awk -F'"' '/^LICENSE_KEY=/{print $2}' "$BASE/license.conf" 2>/dev/null || true)"
fi

if [[ "$AUTO_MODE" == true && -z "$INSTALL_KEY" ]]; then
    error "No existe una Key guardada para la actualización automática."
    exit 1
fi

while true; do

    if [[ "$AUTO_MODE" == false ]]; then
        read -r -p " 🔑 Introduce tu Key de Instalación: " INSTALL_KEY
    fi

    INSTALL_KEY="$(
        printf '%s' "$INSTALL_KEY" |
        tr -d '[:space:]'
    )"

    if [[ -z "$INSTALL_KEY" ]]; then

        error "La Key no puede estar vacía."
        echo

        continue

    fi

    echo

    info "Verificando licencia..."

    #=====================================================
    # JSON
    #=====================================================

    VALIDATE_JSON="$(
        jq -n \
            --arg key "$INSTALL_KEY" \
            '{
                key: $key
            }'
    )"

    #=====================================================
    # API VALIDATE
    #=====================================================

    VALIDATE_RESPONSE="$(
        curl \
            --silent \
            --show-error \
            --connect-timeout 5 \
            --max-time 15 \
            -4 \
            -w '\n%{http_code}' \
            -X POST \
            -H "Content-Type: application/json" \
            --data "$VALIDATE_JSON" \
            "${LICENSE_API}/api/public/validate" \
            2>/dev/null
    )"

    CURL_STATUS=$?

    VALIDATE_HTTP="$(
        printf '%s\n' "$VALIDATE_RESPONSE" |
        tail -n1
    )"

    VALIDATE_BODY="$(
        printf '%s\n' "$VALIDATE_RESPONSE" |
        sed '$d'
    )"

    #=====================================================
    # ERROR DE CONEXIÓN
    #=====================================================

    if [[ "$CURL_STATUS" -ne 0 ]]; then

        error "No fue posible conectar con la API."

        echo
        echo -e "${YELLOW}Comprueba la conexión a Internet.${RESET}"
        echo

        sleep 2

        continue

    fi

    #=====================================================
    # HTTP VALIDACIÓN
    #=====================================================

    if [[ "$VALIDATE_HTTP" != "200" ]]; then

        error "La API de validación respondió con HTTP $VALIDATE_HTTP."

        echo
        echo -e "${GRAY}Respuesta:${RESET}"
        echo "$VALIDATE_BODY"
        echo

        sleep 2

        continue

    fi

    #=====================================================
    # JSON VÁLIDO
    #=====================================================

    if ! echo "$VALIDATE_BODY" |
        jq empty >/dev/null 2>&1; then

        error "La API devolvió una respuesta inválida."

        echo
        echo -e "${GRAY}HTTP: $VALIDATE_HTTP${RESET}"
        echo

        sleep 2

        continue

    fi

    #=====================================================
    # RESULTADO
    #=====================================================

    VALID="$(
        echo "$VALIDATE_BODY" |
        jq -r '.ok // .valid // false'
    )"

    ERROR_CODE="$(
        echo "$VALIDATE_BODY" |
        jq -r '.error // empty'
    )"

    #=====================================================
    # KEY INVÁLIDA
    #=====================================================

    if [[ "$VALID" != "true" ]]; then

        echo

        case "$ERROR_CODE" in

            key_not_found)

                error "La Key no existe."

                ;;

            key_used)

                error "La Key ya fue utilizada."

                ;;

            key_expired)

                error "La Key ha expirado."

                ;;

            key_required)

                error "No se recibió una Key."

                ;;

            *)

                error "La Key no es válida."

                ;;

        esac

        echo
        echo -e "${YELLOW}La actualización no continuará.${RESET}"
        echo

        sleep 2

        continue

    fi

    #=====================================================
    # DATOS
    #=====================================================

    LICENSE_OWNER="$(
        echo "$VALIDATE_BODY" |
        jq -r '.owner // "Desconocido"'
    )"

    LICENSE_RESELLER="$(
        echo "$VALIDATE_BODY" |
        jq -r '.reseller // "Desconocido"'
    )"

    LICENSE_TYPE="$(
        echo "$VALIDATE_BODY" |
        jq -r '.type // "normal"'
    )"

    LICENSE_DELETE_AT="$(
        echo "$VALIDATE_BODY" |
        jq -r '.deleteAt // empty'
    )"

    #=====================================================
    # MOSTRAR LICENCIA
    #=====================================================

    echo

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}              ✅ LICENCIA VÁLIDA${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    echo

    echo -e " ${GRAY}Propietario:${RESET} ${WHITE}${LICENSE_OWNER}${RESET}"
    echo -e " ${GRAY}Revendedor :${RESET} ${WHITE}${LICENSE_RESELLER}${RESET}"
    echo -e " ${GRAY}Tipo       :${RESET} ${WHITE}${LICENSE_TYPE}${RESET}"

    if [[ -n "$LICENSE_DELETE_AT" &&
          "$LICENSE_DELETE_AT" != "null" ]]; then

        echo -e " ${GRAY}Expira     :${RESET} ${WHITE}${LICENSE_DELETE_AT}${RESET}"

    fi

    echo

    ok "Licencia autorizada para continuar."

    echo

    break

done

#=========================================================
# INFORMACIÓN SERVIDOR
#=========================================================

info "Recopilando información del servidor..."

CLIENT_IP="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 10 \
        -4 \
        https://api.ipify.org \
        2>/dev/null
)"

if [[ -z "$CLIENT_IP" ]]; then
    CLIENT_IP="Desconocida"
fi

OS_NAME="$(
    grep '^PRETTY_NAME=' /etc/os-release |
    cut -d'"' -f2
)"

[[ -z "$OS_NAME" ]] && \
    OS_NAME="Desconocido"

HOSTNAME_SERVER="$(hostname)"

DATE_NOW="$(
    date -u '+%Y-%m-%dT%H:%M:%SZ'
)"

echo

echo -e "${CYAN}${BOLD}◆ INFORMACIÓN DEL SERVIDOR${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${GRAY}IP:${RESET}        ${WHITE}$CLIENT_IP${RESET}"
echo -e " ${GRAY}Hostname:${RESET}  ${WHITE}$HOSTNAME_SERVER${RESET}"
echo -e " ${GRAY}Sistema:${RESET}   ${WHITE}$OS_NAME${RESET}"
echo -e " ${GRAY}Fecha:${RESET}     ${WHITE}$DATE_NOW${RESET}"

echo

#=========================================================
# TEMPORAL
#=========================================================

info "Preparando archivos temporales..."

rm -rf "$TMP"

mkdir -p "$TMP" || \
    error_exit "No se pudo crear el directorio temporal."

echo

#=========================================================
# DESCARGAR ACTUALIZACIÓN
#=========================================================

echo -e "${MAGENTA}${BOLD}◆ DESCARGANDO ACTUALIZACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${CYAN}⬇${RESET} ${WHITE}Conectando con GitHub...${RESET}"
echo

if ! git clone \
    --depth 1 \
    "$REPO" \
    "$TMP"; then

    echo

    error "No se pudo descargar la actualización."

    echo
    echo -e " ${YELLOW}⚠${RESET} Comprueba:"
    echo -e "   ${GRAY}•${RESET} Conexión a Internet"
    echo -e "   ${GRAY}•${RESET} Acceso a GitHub"
    echo -e "   ${GRAY}•${RESET} Disponibilidad del repositorio"
    echo

    rm -rf "$TMP"

    exit 1

fi

echo

ok "Actualización descargada correctamente."

#=========================================================
# NUEVA VERSIÓN
#=========================================================

if [[ -f "$TMP/version.txt" ]]; then

    NUEVA_VERSION="$(
        head -n1 "$TMP/version.txt" |
        tr -d '\r'
    )"

fi

[[ -z "$NUEVA_VERSION" ]] && \
    NUEVA_VERSION="No disponible"

echo

echo -e "${PURPLE}${BOLD}◆ CONTROL DE VERSIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

echo -e " ${YELLOW}Versión actual:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"
echo -e " ${GREEN}Nueva versión:${RESET}  ${LIME}${NUEVA_VERSION}${RESET}"

echo

#=========================================================
# BACKUP
#=========================================================

echo -e "${BLUE}${BOLD}◆ COPIA DE SEGURIDAD${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

BACKUP_DIR="${BASE}/backup"

mkdir -p "$BACKUP_DIR" || \
    error_exit "No se pudo crear el directorio de backup."

BACKUP_FILE="$BACKUP_DIR/backup_$(date '+%Y%m%d_%H%M%S').tar.gz"

info "Creando copia de seguridad..."

if tar \
    -czf "$BACKUP_FILE" \
    -C "$BASE" \
    --exclude="./backup" \
    . >/dev/null 2>&1; then

    ok "Backup creado."

    echo -e " ${GRAY}➜${RESET} $BACKUP_FILE"

else

    warning "No se pudo crear el backup completo."
    echo -e "${YELLOW}La actualización continuará.${RESET}"

fi

echo


fi

#=========================================================
# INSTALAR
#=========================================================

echo -e "${BLUE}${BOLD}◆ INSTALANDO ARCHIVOS${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

info "Copiando archivos..."

if ! cp -a "$TMP"/. "$BASE"/; then

    echo

    error "No se pudieron copiar los archivos."

    echo
    warning "La Key NO será consumida."

    rm -rf "$TMP"

    exit 1

fi

ok "Archivos actualizados correctamente."

#=========================================================
# VERSIÓN
#=========================================================

if [[ -f "$TMP/version.txt" ]]; then

    cp -f \
        "$TMP/version.txt" \
        "$VERSION_FILE"

    ok "Versión instalada: ${NUEVA_VERSION}"

else

    warning "No se encontró version.txt."

fi

#=========================================================
# PERMISOS
#=========================================================

echo

info "Aplicando permisos..."

chmod -R 755 "$BASE" >/dev/null 2>&1 || true

if [[ -f "$BASE/license.conf" ]]; then

    chmod 600 "$BASE/license.conf" >/dev/null 2>&1 || true

fi

ok "Permisos actualizados."

if [[ "$BOT_MODE" != true ]]; then

#=========================================================
# ACTIVACIÓN
#=========================================================

echo

echo -e "${GOLD}${BOLD}◆ REGISTRANDO ACTUALIZACIÓN${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

info "Registrando actualización en License API..."

ACTIVATION_JSON="$(
    jq -n \
        --arg key "$INSTALL_KEY" \
        --arg ip "$CLIENT_IP" \
        --arg hostname "$HOSTNAME_SERVER" \
        --arg os "$OS_NAME" \
        --arg date "$DATE_NOW" \
        --arg version "$NUEVA_VERSION" \
        '{
            key: $key,
            ip: $ip,
            hostname: $hostname,
            os: $os,
            date: $date,
            version: $version
        }'
)"

ACTIVATE_RESPONSE="$(
    curl \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        -4 \
        -w '\n%{http_code}' \
        -X POST \
        -H "Content-Type: application/json" \
        --data "$ACTIVATION_JSON" \
        "${LICENSE_API}/api/public/activate" \
        2>/dev/null
)"

ACTIVATE_STATUS=$?

ACTIVATE_HTTP="$(
    printf '%s\n' "$ACTIVATE_RESPONSE" |
    tail -n1
)"

ACTIVATE_BODY="$(
    printf '%s\n' "$ACTIVATE_RESPONSE" |
    sed '$d'
)"

#=========================================================
# ERROR CONEXIÓN
#=========================================================

if [[ "$ACTIVATE_STATUS" -ne 0 ]]; then

    echo

    error "No se pudo conectar con la API de activación."

    echo
    warning "La actualización fue instalada."
    warning "La Key NO fue marcada como utilizada."

    echo
    echo -e "${YELLOW}IMPORTANTE:${RESET}"
    echo -e "${WHITE}La actualización necesita ser registrada manualmente.${RESET}"
    echo

    rm -rf "$TMP"

    exit 1

fi

#=========================================================
# JSON
#=========================================================

if ! echo "$ACTIVATE_BODY" |
    jq empty >/dev/null 2>&1; then

    error "La API devolvió una respuesta inválida."

    echo
    echo -e "${GRAY}HTTP: $ACTIVATE_HTTP${RESET}"
    echo
    echo "$ACTIVATE_BODY"
    echo

    rm -rf "$TMP"

    exit 1

fi

#=========================================================
# RESULTADO API
#=========================================================

ACTIVATE_OK="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.ok // false'
)"

ACTIVATE_ERROR="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.error // empty'
)"

#=========================================================
# VALIDACIÓN DE ACTIVACIÓN
#
# La API puede devolver:
#
# HTTP 200 = correcto
# HTTP 201 = activación creada correctamente
#
# La respuesta {"ok":true} tiene prioridad.
#=========================================================

if [[ "$ACTIVATE_OK" != "true" ]]; then

    echo

    error "No se pudo registrar la actualización."

    echo
    echo -e "${YELLOW}Código: ${ACTIVATE_ERROR:-desconocido}${RESET}"
    echo -e "${YELLOW}HTTP  : $ACTIVATE_HTTP${RESET}"

    echo

    echo -e "${GRAY}Respuesta:${RESET}"
    echo "$ACTIVATE_BODY"

    echo

    warning "La actualización ya fue instalada."
    warning "La Key NO fue consumida."

    echo

    rm -rf "$TMP"

    exit 1

fi

#=========================================================
# ACTIVACIÓN CORRECTA
#=========================================================

ACTIVATION_ID="$(
    echo "$ACTIVATE_BODY" |
    jq -r '.activationId // empty'
)"

echo

ok "Servidor de activación respondió correctamente."
echo -e " ${GRAY}HTTP:${RESET} ${GREEN}${ACTIVATE_HTTP}${RESET}"

echo

ok "Actualización registrada correctamente."

if [[ -n "$ACTIVATION_ID" ]]; then

    echo
    echo -e " ${GRAY}Activation ID:${RESET} ${WHITE}$ACTIVATION_ID${RESET}"

fi

echo
ok "La API marcó la Key como utilizada."


fi

#=========================================================
# LIMPIAR MEMORIA
#=========================================================

unset INSTALL_KEY
unset ACTIVATION_JSON
unset ACTIVATE_RESPONSE
unset VALIDATE_JSON
unset VALIDATE_RESPONSE

#=========================================================
# LIMPIEZA
#=========================================================

echo

info "Limpiando archivos temporales..."

rm -rf "$TMP"

ok "Limpieza completada."

#=========================================================
# FINAL
#=========================================================

echo

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET} ${WHITE}${BOLD}          ✅ ACTUALIZACIÓN COMPLETADA${RESET}              ${GREEN}║${RESET}"
echo -e "${GREEN}║${RESET} ${GRAY}          Kevin Tech Multi Script Premium${RESET}           ${GREEN}║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"

echo

echo -e " ${CYAN}◆${RESET} ${WHITE}Versión anterior:${RESET} ${GRAY}${VERSION_ACTUAL}${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Versión instalada:${RESET} ${GREEN}${NUEVA_VERSION}${RESET}"

echo

echo -e " ${CYAN}◆${RESET} ${WHITE}Licencia:${RESET} ${GREEN}ACTIVADA${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Propietario:${RESET} ${WHITE}${LICENSE_OWNER}${RESET}"
echo -e " ${CYAN}◆${RESET} ${WHITE}Revendedor:${RESET} ${WHITE}${LICENSE_RESELLER}${RESET}"

echo

echo -e "${CYAN}🚀${RESET} ${WHITE}Regresando al panel...${RESET}"

sleep 2

#=========================================================
# REGRESAR AL MENÚ
#=========================================================

if [[ "$AUTO_MODE" == true ]]; then
    exit 0
fi

if [[ -f "$BASE/menu.sh" ]]; then

    exec bash "$BASE/menu.sh"

else

    echo
    warning "No se encontró menu.sh."
    echo
    echo -e "${CYAN}Escribe:${RESET} menu"
    echo

fi

exit 0