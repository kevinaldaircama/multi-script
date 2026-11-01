#!/bin/bash
# ============================================================
# KEVINTECH BANNER MANAGER v7.0
# Global: /etc/issue.net (OpenSSH pre-authentication banner)
# Individual: shown after login via /etc/profile.d (per-user)
# Editable per-user fields: announcement, location, support, bot/channel
# Protected connection fields: username, expiry, days, IP limit,
#                              connected sessions and remote IPs
# ============================================================

set -Eeuo pipefail

BASE="/etc/kevintech"
LIMITS_FILE="$BASE/limits.conf"
SSHD_CONFIG="/etc/ssh/sshd_config"
ISSUE_FILE="/etc/issue.net"
BANNER_DIR="/etc/ssh_banners"
USER_DIR="$BANNER_DIR/users"
BACKUP_DIR="$BASE/banner-backups"
STATE_FILE="$BASE/banner-state.conf"
PROFILE_SCRIPT="/etc/profile.d/kevintech-banner.sh"
HELPER="/usr/local/sbin/kevintech-banner-refresh"
START_MARK="# >>> KEVINTECH GLOBAL BANNER START >>>"
END_MARK="# <<< KEVINTECH GLOBAL BANNER END <<<"

RED='\e[1;91m'; GREEN='\e[1;92m'; YELLOW='\e[1;93m'
CYAN='\e[1;96m'; BLUE='\e[1;94m'; MAGENTA='\e[1;95m'
WHITE='\e[1;97m'; GRAY='\e[1;90m'; RESET='\e[0m'

[[ $EUID -eq 0 ]] || { echo -e "${RED}Ejecuta este script como root.${RESET}"; exit 1; }

mkdir -p "$BASE" "$BANNER_DIR" "$USER_DIR" "$BACKUP_DIR"
chmod 755 "$BANNER_DIR" "$USER_DIR"

pause(){ echo; read -rp 'Presiona ENTER para continuar...'; }
header(){
  clear 2>/dev/null || true
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║${WHITE}            KEVINTECH BANNER MANAGER v7.0            ${CYAN}║${RESET}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}║ ${WHITE}GLOBAL     ${GRAY}/etc/issue.net (antes de autenticar)${CYAN}   ║${RESET}"
  echo -e "${CYAN}║ ${WHITE}INDIVIDUAL ${GRAY}al iniciar sesión (por usuario)${CYAN}        ║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
  echo
}

get_users(){
  [[ -f "$LIMITS_FILE" ]] || return 0
  awk -F: 'NF>=1 && $1!="" && $1 !~ /^[[:space:]]*#/ && $1 ~ /^[a-zA-Z0-9._-]+$/ {print $1}' "$LIMITS_FILE" | sort -u
}
user_exists(){
  local u="$1"
  [[ "$u" =~ ^[a-zA-Z0-9._-]+$ ]] || return 1
  [[ -f "$LIMITS_FILE" ]] && awk -F: -v u="$u" '$1==u{f=1;exit} END{exit !f}' "$LIMITS_FILE"
}
get_limit(){
  local v='1'
  [[ -f "$LIMITS_FILE" ]] && v="$(awk -F: -v u="$1" '$1==u{print $2;exit}' "$LIMITS_FILE" 2>/dev/null || true)"
  printf '%s' "${v:-1}"
}
get_expire(){
  local v='Nunca'
  if id "$1" >/dev/null 2>&1; then
    v="$(chage -l "$1" 2>/dev/null | awk -F: '/Account expires/{sub(/^[ \t]+/,"",$2);print $2;exit}' || true)"
  fi
  printf '%s' "${v:-Nunca}"
}
get_days(){
  local exp ts now days
  exp="$(get_expire "$1")"
  case "$exp" in Nunca|never|Never|'') echo 'Ilimitado'; return;; esac
  ts="$(date -d "$exp 23:59:59" +%s 2>/dev/null || true)"
  [[ -n "$ts" ]] || { echo 'Desconocido'; return; }
  now="$(date +%s)"; days=$(( (ts-now)/86400 ))
  (( days < 0 )) && echo 'EXPIRADO' || echo "$days"
}
get_connections(){
  local u="$1" total ips
  total="$(who 2>/dev/null | awk -v u="$u" '$1==u{n++} END{print n+0}')"
  ips="$(who 2>/dev/null | awk -v u="$u" '$1==u && $5~/^\(/ {gsub(/[()]/,"",$5);print $5}' | sort -u | paste -sd, -)"
  echo "${total}|${ips:-Sin conexión}"
}
user_meta_file(){ printf '%s/%s.meta' "$USER_DIR" "$1"; }
user_banner_file(){ printf '%s/%s.txt' "$USER_DIR" "$1"; }

# Metadata is base64 encoded; it is never sourced as shell code.
read_meta(){
  local file key val
  file="$(user_meta_file "$1")"
  ANNOUNCEMENT=''; GEO=''; SUPPORT=''; BOT=''
  [[ -f "$file" ]] || return 0
  while IFS='=' read -r key val; do
    case "$key" in
      ANNOUNCEMENT) ANNOUNCEMENT="$(printf '%s' "$val" | base64 -d 2>/dev/null || true)";;
      GEO) GEO="$(printf '%s' "$val" | base64 -d 2>/dev/null || true)";;
      SUPPORT) SUPPORT="$(printf '%s' "$val" | base64 -d 2>/dev/null || true)";;
      BOT) BOT="$(printf '%s' "$val" | base64 -d 2>/dev/null || true)";;
    esac
  done < "$file"
}
save_meta(){
  local u="$1" file tmp
  file="$(user_meta_file "$u")"; tmp="${file}.tmp"
  {
    printf 'ANNOUNCEMENT=%s\n' "$(printf '%s' "$ANNOUNCEMENT" | base64 -w0)"
    printf 'GEO=%s\n' "$(printf '%s' "$GEO" | base64 -w0)"
    printf 'SUPPORT=%s\n' "$(printf '%s' "$SUPPORT" | base64 -w0)"
    printf 'BOT=%s\n' "$(printf '%s' "$BOT" | base64 -w0)"
  } > "$tmp"
  chmod 644 "$tmp"; chown root:root "$tmp"; mv "$tmp" "$file"
}

refresh_user_banner(){
  local u="$1" exp days lim conn total ips out
  user_exists "$u" || return 1
  read_meta "$u"
  exp="$(get_expire "$u")"; days="$(get_days "$u")"; lim="$(get_limit "$u")"
  conn="$(get_connections "$u")"; total="${conn%%|*}"; ips="${conn#*|}"
  out="$(user_banner_file "$u")"
  {
    printf '\n\033[1;96m╔══════════════════════════════════════════════════════╗\033[0m\n'
    printf '\033[1;96m║\033[1;97m                 🚀 KEVINTECH SSH                    \033[1;96m║\033[0m\n'
    printf '\033[1;96m║\033[1;95m                 ✦ CUENTA PERSONAL ✦                \033[1;96m║\033[0m\n'
    printf '\033[1;96m╠══════════════════════════════════════════════════════╣\033[0m\n'
    printf '\033[1;96m║ \033[1;97m👤 Usuario          : \033[1;92m%s\033[1;96m\n' "$u"
    printf '\033[1;96m║ \033[1;97m📅 Expiración       : \033[1;93m%s\033[1;96m\n' "$exp"
    printf '\033[1;96m║ \033[1;97m⏳ Días restantes   : \033[1;93m%s\033[1;96m\n' "$days"
    printf '\033[1;96m║ \033[1;97m👥 Límite de IP     : \033[1;93m%s\033[1;96m\n' "$lim"
    printf '\033[1;96m║ \033[1;97m🔌 Conexiones       : \033[1;92m%s\033[1;96m\n' "$total"
    printf '\033[1;96m║ \033[1;97m🌐 IP conectadas    : \033[1;90m%s\033[1;96m\n' "$ips"
    printf '\033[1;96m╠══════════════════════════════════════════════════════╣\033[0m\n'
    if [[ -n "$ANNOUNCEMENT" ]]; then printf '\033[1;95m📢 ANUNCIO\033[0m\n%s\n\n' "$ANNOUNCEMENT"; fi
    if [[ -n "$GEO" ]]; then printf '\033[1;94m📍 UBICACIÓN\033[0m\n%s\n\n' "$GEO"; fi
    if [[ -n "$SUPPORT" ]]; then printf '\033[1;92m🛠️ SOPORTE\033[0m\n%s\n\n' "$SUPPORT"; fi
    if [[ -n "$BOT" ]]; then printf '\033[1;95m🤖 BOT / CANAL\033[0m\n%s\n\n' "$BOT"; fi
    printf '\033[1;96m╠══════════════════════════════════════════════════════╣\033[0m\n'
    printf '\033[1;97m              KEVINTECH MULTI SCRIPT\033[0m\n'
    printf '\033[1;96m╚══════════════════════════════════════════════════════╝\033[0m\n\n'
  } > "$out"
  chmod 644 "$out"; chown root:root "$out"
}
refresh_all(){
  local u n=0
  while IFS= read -r u; do
    [[ -n "$u" ]] || continue
    refresh_user_banner "$u" && { echo -e "${GREEN}✔${RESET} Actualizado: $u"; ((n+=1)); }
  done < <(get_users)
  echo -e "\n${GREEN}Total actualizados: $n${RESET}"
}

install_profile_display(){
  cat > "$PROFILE_SCRIPT" <<'PROFILE'
# KevinTech per-user banner. It is displayed only in interactive shells.
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0;; esac
[ -n "${USER:-}" ] || return 0 2>/dev/null || exit 0
case "$USER" in *[!a-zA-Z0-9._-]*|'') return 0 2>/dev/null || exit 0;; esac
_banner="/etc/ssh_banners/users/${USER}.txt"
if [ -r "$_banner" ]; then
    cat -- "$_banner"
fi
unset _banner
PROFILE
  chmod 644 "$PROFILE_SCRIPT"; chown root:root "$PROFILE_SCRIPT"
}

# Put the global Banner directive before the first Match block.
# Existing global Banner directives are commented; Match-specific settings are left alone.
sync_sshd(){
  [[ -f "$SSHD_CONFIG" ]] || { echo -e "${RED}No existe $SSHD_CONFIG${RESET}"; return 1; }
  cp -a "$SSHD_CONFIG" "$BACKUP_DIR/sshd_config.$(date +%Y%m%d-%H%M%S)"
  local tmp; tmp="$(mktemp)"
  awk -v s="$START_MARK" -v e="$END_MARK" -v issue="$ISSUE_FILE" '
    $0==s {managed=1; next}
    $0==e {managed=0; next}
    managed {next}
    /^[[:space:]]*Match[[:space:]]/ && !inserted {
      print s
      print "Banner " issue
      print e
      print ""
      inserted=1
    }
    /^[[:space:]]*Banner[[:space:]]/ && !inmatch {
      print "# KevinTech: replaced by managed global Banner directive: " $0
      next
    }
    /^[[:space:]]*Match[[:space:]]/ {inmatch=1}
    {print}
    END {
      if (!inserted) {
        print ""
        print s
        print "Banner " issue
        print e
      }
    }
  ' "$SSHD_CONFIG" > "$tmp"
  cp "$tmp" "$SSHD_CONFIG"; rm -f "$tmp"
  if command -v sshd >/dev/null 2>&1; then
    if ! sshd -t; then
      echo -e "${RED}La configuración SSH no pasó la validación. Restaura el backup más reciente en $BACKUP_DIR.${RESET}"
      return 1
    fi
  fi
  systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
  echo -e "${GREEN}✔ OpenSSH configurado para usar $ISSUE_FILE${RESET}"
}

edit_global(){
  header
  echo -e "${CYAN}BANNER GLOBAL: $ISSUE_FILE${RESET}"
  echo 'Escribe el texto línea por línea. Escribe . en una línea sola para terminar.'
  echo 'Este texto se muestra antes de autenticar; issue.net es texto plano, no HTML.'
  echo
  [[ -f "$ISSUE_FILE" ]] && cp -a "$ISSUE_FILE" "$BACKUP_DIR/issue.net.$(date +%Y%m%d-%H%M%S)"
  local tmp line
  tmp="$(mktemp)"
  while IFS= read -r -p '> ' line; do
    [[ "$line" == '.' ]] && break
    printf '%s\n' "$line" >> "$tmp"
  done
  install -o root -g root -m 644 "$tmp" "$ISSUE_FILE"
  rm -f "$tmp"
  sync_sshd
  echo -e "${GREEN}✔ Banner global guardado en $ISSUE_FILE${RESET}"
  pause
}
view_global(){
  header
  if [[ -f "$ISSUE_FILE" ]]; then cat -n "$ISSUE_FILE"; else echo 'Todavía no existe /etc/issue.net'; fi
  pause
}

prompt_edit(){
  local label="$1" current="$2" answer
  echo -e "${WHITE}${label}${RESET}"
  [[ -n "$current" ]] && printf 'Actual: %s\n' "$current" || echo 'Actual: (vacío)'
  read -r -p 'Nuevo valor [ENTER=conservar, -=vaciar]: ' answer
  if [[ "$answer" == '-' ]]; then REPLY=''; elif [[ -z "$answer" ]]; then REPLY="$current"; else REPLY="$answer"; fi
}
edit_one_user(){
  header
  local u
  read -r -p 'Nombre exacto del usuario: ' u
  if ! user_exists "$u"; then echo -e "${RED}Usuario no encontrado en $LIMITS_FILE${RESET}"; pause; return; fi
  read_meta "$u"
  echo -e "${CYAN}Editando información comercial de: $u${RESET}"
  echo -e "${GRAY}Los datos de conexión son automáticos y no se pueden editar desde aquí.${RESET}"
  echo
  prompt_edit '📢 Anuncio' "$ANNOUNCEMENT"; ANNOUNCEMENT="$REPLY"
  prompt_edit '📍 Ubicación' "$GEO"; GEO="$REPLY"
  prompt_edit '🛠️ Soporte' "$SUPPORT"; SUPPORT="$REPLY"
  prompt_edit '🤖 Bot / Canal' "$BOT"; BOT="$REPLY"
  save_meta "$u"
  refresh_user_banner "$u"
  echo -e "\n${GREEN}✔ Banner individual actualizado para $u${RESET}"
  echo -e "${GRAY}Datos automáticos protegidos: usuario, vencimiento, días, límite IP y conexiones.${RESET}"
  pause
}
view_one_user(){
  header
  local u f
  read -r -p 'Usuario que deseas visualizar: ' u
  f="$(user_banner_file "$u")"
  if [[ -f "$f" ]]; then cat -v "$f"; else echo -e "${YELLOW}No hay banner generado para ese usuario.${RESET}"; fi
  pause
}

main_menu(){
  while true; do
    header
    echo -e "${CYAN}[1]${WHITE} Crear / editar banner GLOBAL (/etc/issue.net)"
    echo -e "${CYAN}[2]${WHITE} Ver banner GLOBAL"
    echo -e "${MAGENTA}[3]${WHITE} Editar banner INDIVIDUAL de un usuario"
    echo -e "${MAGENTA}[4]${WHITE} Actualizar banners individuales de todos"
    echo -e "${MAGENTA}[5]${WHITE} Ver banner individual de un usuario"
    echo -e "${BLUE}[6]${WHITE} Sincronizar configuración de SSH"
    echo -e "${RED}[0]${WHITE} Salir"
    echo
    echo -e "${GRAY}Usuarios detectados: $(get_users | wc -l | tr -d ' ')${RESET}"
    read -r -p '❯ Opción: ' op
    case "$op" in
      1) edit_global;;
      2) view_global;;
      3) edit_one_user;;
      4) header; refresh_all; pause;;
      5) view_one_user;;
      6) header; sync_sshd; pause;;
      0) exit 0;;
      *) echo -e "${RED}Opción inválida${RESET}"; sleep 1;;
    esac
  done
}

# Hook compatible con el alta de usuarios: banner.sh --auto-user USUARIO
if [[ "${1:-}" == "--auto-user" ]]; then
  u="${2:-}"
  [[ -n "$u" ]] && user_exists "$u" || exit 0
  install_profile_display
  refresh_user_banner "$u"
  exit 0
fi

install_profile_display
# Genera los archivos que falten, sin sobrescribir los personalizados ya guardados.
while IFS= read -r u; do
  [[ -n "$u" ]] || continue
  [[ -f "$(user_banner_file "$u")" ]] || refresh_user_banner "$u"
done < <(get_users)
main_menu
