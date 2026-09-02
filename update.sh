#!/bin/bash
#=========================================================
# KEVIN TECH MULTI SCRIPT - UPDATER
# Actualización directa desde GitHub - sin Key
#=========================================================
set -o pipefail
BASE="/etc/kevintech"
TMP="/tmp/kevintech_update_$$"
SRC="$TMP/repo"
REPO="https://github.com/kevinaldaircama/multi-script.git"
VERSION_FILE="$BASE/version.txt"
RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; YELLOW="\e[1;93m"; BLUE="\e[1;94m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"; CYAN="\e[1;96m"; GOLD="\e[38;5;220m"; SKY="\e[38;5;117m"
VERSION_ACTUAL="No disponible"; NUEVA_VERSION="No disponible"
titulo(){ clear 2>/dev/null || true; echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"; echo -e "${CYAN}║${RESET} ${WHITE}\e[1m              KEVIN TECH UPDATER${RESET}                  ${CYAN}║${RESET}"; echo -e "${CYAN}║${RESET} ${GRAY}                 MULTI SCRIPT PREMIUM${RESET}              ${CYAN}║${RESET}"; echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"; echo; }
ok(){ echo -e " ${GREEN}✔${RESET} ${WHITE}$1${RESET}"; }; info(){ echo -e " ${CYAN}◆${RESET} ${WHITE}$1${RESET}"; }; error(){ echo -e " ${RED}✘${RESET} ${WHITE}$1${RESET}"; }; warning(){ echo -e " ${YELLOW}⚠${RESET} ${WHITE}$1${RESET}"; }
error_exit(){ error "$1"; rm -rf "$TMP"; exit 1; }
[[ "$EUID" -eq 0 ]] || { exec sudo bash "$0" "$@"; }
[[ -d "$BASE" ]] || error_exit "No existe el directorio $BASE."
command -v curl >/dev/null 2>&1 || apt-get update -y >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 || apt-get install -y curl >/dev/null 2>&1
command -v git >/dev/null 2>&1 || { apt-get update -y >/dev/null 2>&1 && apt-get install -y git >/dev/null 2>&1; }
command -v git >/dev/null 2>&1 || error_exit "Git no está disponible."
titulo
echo -e "${GOLD}\e[1m◆ ACTUALIZACIÓN DEL SISTEMA${RESET}"; echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo
info "Preparando actualización..."; echo -e " ${GRAY}➜${RESET} Repositorio: ${SKY}$REPO${RESET}"; echo -e " ${GRAY}➜${RESET} Destino:     ${SKY}$BASE${RESET}"; echo -e " ${GRAY}➜${RESET} Autorización: ${GREEN}Telegram / administrador${RESET}"; echo
[[ -f "$VERSION_FILE" ]] && VERSION_ACTUAL="$(head -n1 "$VERSION_FILE" | tr -d '\r')"
echo -e "${BLUE}\e[1m◆ INFORMACIÓN DE VERSIÓN${RESET}"; echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo; echo -e " ${YELLOW}Versión instalada:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"; echo
rm -rf "$TMP"; mkdir -p "$TMP" || error_exit "No se pudo crear el directorio temporal."
echo -e "${CYAN}\e[1m◆ DESCARGANDO ACTUALIZACIÓN${RESET}"; echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo; info "Conectando con GitHub..."
git clone --depth 1 "$REPO" "$SRC" >/tmp/kevintech_git_$$.log 2>&1 || { cat /tmp/kevintech_git_$$.log; rm -f /tmp/kevintech_git_$$.log; error_exit "No se pudo descargar la actualización."; }; rm -f /tmp/kevintech_git_$$.log; ok "Actualización descargada correctamente."
[[ -f "$SRC/version.txt" ]] && NUEVA_VERSION="$(head -n1 "$SRC/version.txt" | tr -d '\r')"
echo; echo -e " ${YELLOW}Versión actual:${RESET} ${WHITE}${VERSION_ACTUAL}${RESET}"; echo -e " ${GREEN}Nueva versión:${RESET} ${WHITE}${NUEVA_VERSION}${RESET}"; echo
# Preservar únicamente datos de instalación y runtime.
PRESERVE_DIR="$TMP/preserve"; mkdir -p "$PRESERVE_DIR"
for item in config.conf license.conf limits telegram/.env telegram/data.json telegram/offset telegram/backups; do
  if [[ -e "$BASE/$item" ]]; then mkdir -p "$PRESERVE_DIR/$(dirname "$item")"; cp -a "$BASE/$item" "$PRESERVE_DIR/$item"; fi
done
# Backup completo por seguridad.
BACKUP_DIR="$BASE/backup"; mkdir -p "$BACKUP_DIR"; BACKUP_FILE="$BACKUP_DIR/backup_$(date '+%Y%m%d_%H%M%S').tar.gz"; tar -czf "$BACKUP_FILE" -C "$BASE" --exclude='./backup' . >/dev/null 2>&1 || warning "No se pudo crear el backup completo."
echo -e "${BLUE}\e[1m◆ INSTALANDO ARCHIVOS${RESET}"; echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo; info "Copiando archivos..."
cp -a "$SRC"/. "$BASE"/ || error_exit "No se pudieron copiar los archivos."
# Restaurar runtime sin sobrescribir el bot actualizado.
cp -a "$PRESERVE_DIR"/. "$BASE"/ 2>/dev/null || true
[[ -f "$SRC/version.txt" ]] && cp -f "$SRC/version.txt" "$VERSION_FILE"
chmod +x "$BASE"/*.sh "$BASE"/menu.sh 2>/dev/null || true
chmod +x "$BASE"/telegram/bot.py 2>/dev/null || true
# El bot es el único conjunto de archivos Python propios; mantenerlos en telegram.
find "$BASE/telegram" -maxdepth 1 -type f -name '*.py' -exec chmod 700 {} \; 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
if systemctl list-unit-files 2>/dev/null | grep -q '^kevintech-telegram.service'; then systemctl restart kevintech-telegram.service >/dev/null 2>&1 || true; fi
rm -rf "$TMP"
echo; echo -e "${GREEN}\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${GREEN}\e[1m              ✅ ACTUALIZACIÓN COMPLETADA${RESET}"; echo -e "${GREEN}\e[1m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo; echo -e " ${GRAY}Versión instalada:${RESET} ${WHITE}${NUEVA_VERSION}${RESET}"; echo -e " ${GRAY}Backup:${RESET} ${WHITE}${BACKUP_FILE}${RESET}"; echo
exit 0
