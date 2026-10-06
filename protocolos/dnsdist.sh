#!/bin/bash
# ==========================================================
# KEVINTECH DNSDIST MANAGER
# Multiplexor DNS para SlowDNS / VayDNS / Slipstream
# ==========================================================

set -u

BASE="/etc/kevintech"
CONFIG="${BASE}/dnsdist.conf"
DNSDIST_CONF="/etc/dnsdist/dnsdist.conf"
SERVICE="dnsdist.service"

DNSDIST_PORT="5380"
SLOWDNS_PORT="5300"
VAYDNS_PORT="5301"
SLIPSTREAM_PORT="5302"

RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'
GRAY='\033[1;90m'
RESET='\033[0m'

info(){ echo -e "${CYAN}➜${RESET} $*"; }
ok(){ echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err(){ echo -e "${RED}✖${RESET} $*"; }
die(){ err "$*"; exit 1; }

need_root(){
    [[ "$EUID" -eq 0 ]] || die "Ejecuta este script como root."
}

has(){
    command -v "$1" >/dev/null 2>&1
}

install_deps(){
    local pkgs=()

    has curl || pkgs+=(curl)
    has iptables || pkgs+=(iptables)
    has ip6tables || pkgs+=(iptables)

    if ((${#pkgs[@]})); then
        export DEBIAN_FRONTEND=noninteractive
        info "Instalando dependencias..."
        apt-get update -y >/dev/null 2>&1 ||
            die "Falló apt update."
        apt-get install -y "${pkgs[@]}" >/dev/null 2>&1 ||
            die "No se pudieron instalar las dependencias."
    fi

    has systemctl || die "systemctl no está disponible."
    has iptables || die "iptables no está disponible."
}

install_dnsdist(){
    if has dnsdist; then
        ok "dnsdist ya está instalado."
        return 0
    fi

    info "Instalando dnsdist..."

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y >/dev/null 2>&1 ||
        die "No se pudo actualizar APT."

    apt-get install -yq dnsdist >/dev/null 2>&1 ||
        die "No se pudo instalar dnsdist."

    has dnsdist ||
        die "dnsdist no quedó instalado."

    ok "dnsdist instalado."
}

ensure_config_dir(){
    mkdir -p "$(dirname "$DNSDIST_CONF")"
    mkdir -p "$BASE"
}

# ----------------------------------------------------------
# Configuración de protocolos
#
# Se guarda:
# SLOWDNS_NS=ns1.example.com
# VAYDNS_NS=ns2.example.com
# SLIPSTREAM_NS=ns3.example.com
#
# Si un NS está vacío, ese protocolo no se activa.
# ----------------------------------------------------------

load_config(){
    SLOWDNS_NS=""
    VAYDNS_NS=""
    SLIPSTREAM_NS=""

    if [[ -f "$CONFIG" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG" 2>/dev/null || true
    fi
}

save_config(){
    mkdir -p "$BASE"

    cat > "$CONFIG" <<EOF
# ==========================================================
# KEVINTECH DNSDIST
# ==========================================================
SLOWDNS_NS=${SLOWDNS_NS:-}
VAYDNS_NS=${VAYDNS_NS:-}
SLIPSTREAM_NS=${SLIPSTREAM_NS:-}
EOF

    chmod 600 "$CONFIG"
}

set_ns(){
    local key="$1"
    local value="$2"

    value="${value// /}"

    case "$key" in
        SLOWDNS_NS) SLOWDNS_NS="$value" ;;
        VAYDNS_NS) VAYDNS_NS="$value" ;;
        SLIPSTREAM_NS) SLIPSTREAM_NS="$value" ;;
    esac

    save_config
}

valid_ns(){
    local ns="$1"

    [[ -z "$ns" ]] && return 0

    [[ "$ns" =~ ^[A-Za-z0-9._-]+$ ]]
}

escape_regex(){
    local value="$1"

    # Escapa caracteres especiales para RegexRule()
    value="${value//\\/\\\\}"
    value="${value//./\\.}"
    value="${value//+/\\+}"
    value="${value//\*/\\*}"
    value="${value//\?/\\?}"
    value="${value//\[/\\[}"
    value="${value//\]/\\]}"
    value="${value//\(/\\(}"
    value="${value//\)/\\)}"
    value="${value//\{/\\{}"
    value="${value//\}/\\}}"
    value="${value//^/\\^}"
    value="${value//\$/\\$}"

    printf '%s' "$value"
}

# ----------------------------------------------------------
# Detección automática de servicios
# ----------------------------------------------------------

detect_slowdns(){
    [[ -n "$SLOWDNS_NS" ]] && return 0

    if systemctl is-active --quiet slowdns 2>/dev/null ||
       systemctl is-active --quiet slowdns-server 2>/dev/null ||
       systemctl is-active --quiet slowdns.service 2>/dev/null; then
        return 0
    fi

    return 1
}

detect_vaydns(){
    [[ -n "$VAYDNS_NS" ]] && return 0

    systemctl is-active --quiet vaydns 2>/dev/null
}

detect_slipstream(){
    [[ -n "$SLIPSTREAM_NS" ]] && return 0

    systemctl is-active --quiet slipstream 2>/dev/null
}

# ----------------------------------------------------------
# Generar dnsdist.conf
# ----------------------------------------------------------

generate_config(){
    load_config
    ensure_config_dir

    local has_slow="false"
    local has_vay="false"
    local has_slip="false"

    [[ -n "$SLOWDNS_NS" ]] && has_slow="true"
    [[ -n "$VAYDNS_NS" ]] && has_vay="true"
    [[ -n "$SLIPSTREAM_NS" ]] && has_slip="true"

    cat > "$DNSDIST_CONF" <<EOF
-- ==========================================================
-- KEVINTECH DNSDIST
-- Archivo generado automáticamente
-- ==========================================================

setLocal("0.0.0.0:${DNSDIST_PORT}")
addLocal("[::]:${DNSDIST_PORT}")

addACL("0.0.0.0/0")
addACL("::/0")

setMaxUDPOutstanding(65535)
setECSSourcePrefixV4(32)
setECSSourcePrefixV6(64)

EOF

    if [[ "$has_slow" == "true" ]]; then
        cat >> "$DNSDIST_CONF" <<EOF
-- SLOWDNS
newServer({
    address="127.0.0.1:${SLOWDNS_PORT}",
    name="slowdns",
    pool="slowdns"
})

EOF

        local regex
        regex="$(escape_regex "$SLOWDNS_NS")"

        cat >> "$DNSDIST_CONF" <<EOF
addAction(
    RegexRule("${regex}"),
    PoolAction("slowdns")
)

EOF
    fi

    if [[ "$has_vay" == "true" ]]; then
        cat >> "$DNSDIST_CONF" <<EOF
-- VAYDNS
newServer({
    address="127.0.0.1:${VAYDNS_PORT}",
    name="vaydns",
    pool="vaydns"
})

EOF

        local regex
        regex="$(escape_regex "$VAYDNS_NS")"

        cat >> "$DNSDIST_CONF" <<EOF
addAction(
    RegexRule("${regex}"),
    PoolAction("vaydns")
)

EOF
    fi

    if [[ "$has_slip" == "true" ]]; then
        cat >> "$DNSDIST_CONF" <<EOF
-- SLIPSTREAM
newServer({
    address="127.0.0.1:${SLIPSTREAM_PORT}",
    name="slipstream",
    pool="slipstream"
})

EOF

        local regex
        regex="$(escape_regex "$SLIPSTREAM_NS")"

        cat >> "$DNSDIST_CONF" <<EOF
addAction(
    RegexRule("${regex}"),
    PoolAction("slipstream")
)

EOF
    fi

    # Fallback:
    # Si solamente existe un protocolo, todo DNS que llegue a dnsdist
    # puede ir directamente a ese protocolo.
    local count=0
    [[ "$has_slow" == "true" ]] && ((count++))
    [[ "$has_vay" == "true" ]] && ((count++))
    [[ "$has_slip" == "true" ]] && ((count++))

    if ((count == 1)); then
        if [[ "$has_slow" == "true" ]]; then
            echo 'addAction(AllRule(), PoolAction("slowdns"))' >> "$DNSDIST_CONF"
        elif [[ "$has_vay" == "true" ]]; then
            echo 'addAction(AllRule(), PoolAction("vaydns"))' >> "$DNSDIST_CONF"
        else
            echo 'addAction(AllRule(), PoolAction("slipstream"))' >> "$DNSDIST_CONF"
        fi
    fi

    chmod 644 "$DNSDIST_CONF"
}

# ----------------------------------------------------------
# Firewall
# ----------------------------------------------------------

rule_exists_v4(){
    iptables -t nat -C PREROUTING "$@" >/dev/null 2>&1
}

rule_exists_v6(){
    ip6tables -t nat -C PREROUTING "$@" >/dev/null 2>&1
}

remove_dnsdist_nat(){
    if has iptables; then
        while iptables -t nat -C PREROUTING -p udp --dport 53 \
            -m u32 --u32 '0>>22&0x3C@12=0x00010000' \
            -j REDIRECT --to-ports "$DNSDIST_PORT" >/dev/null 2>&1; do
            iptables -t nat -D PREROUTING -p udp --dport 53 \
                -m u32 --u32 '0>>22&0x3C@12=0x00010000' \
                -j REDIRECT --to-ports "$DNSDIST_PORT" >/dev/null 2>&1 || break
        done

        while iptables -t nat -C PREROUTING -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT" >/dev/null 2>&1; do
            iptables -t nat -D PREROUTING -p udp --dport 53 \
                -j REDIRECT --to-ports "$DNSDIST_PORT" >/dev/null 2>&1 || break
        done
    fi

    if has ip6tables; then
        while ip6tables -t nat -C PREROUTING -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT" >/dev/null 2>&1; do
            ip6tables -t nat -D PREROUTING -p udp --dport 53 \
                -j REDIRECT --to-ports "$DNSDIST_PORT" >/dev/null 2>&1 || break
        done
    fi
}

configure_nat(){
    remove_dnsdist_nat

    if has iptables; then
        # IPv4: solamente paquetes DNS Query UDP.
        iptables -t nat -I PREROUTING 1 \
            -p udp --dport 53 \
            -m u32 --u32 '0>>22&0x3C@12=0x00010000' \
            -j REDIRECT --to-ports "$DNSDIST_PORT" \
            >/dev/null 2>&1 || warn "No se pudo crear regla U32 IPv4."
    fi

    if has ip6tables; then
        # IPv6: redirección UDP/53.
        ip6tables -t nat -I PREROUTING 1 \
            -p udp --dport 53 \
            -j REDIRECT --to-ports "$DNSDIST_PORT" \
            >/dev/null 2>&1 || warn "No se pudo crear regla IPv6."
    fi

    ok "Redirección DNS configurada."
}

# ----------------------------------------------------------
# Validar configuración
# ----------------------------------------------------------

validate_config(){
    has dnsdist || return 1

    # Dependiendo de la versión, dnsdist puede aceptar:
    # dnsdist --check-config
    # o dnsdist --check-config=...
    if dnsdist --check-config "$DNSDIST_CONF" >/dev/null 2>&1; then
        return 0
    fi

    if dnsdist --check-config="$DNSDIST_CONF" >/dev/null 2>&1; then
        return 0
    fi

    # Algunas versiones no soportan --check-config.
    # En ese caso no bloqueamos la instalación.
    warn "Esta versión de dnsdist no permitió validar con --check-config."
    return 0
}

sync_dnsdist(){
    need_root
    install_deps
    load_config

    local count=0
    [[ -n "$SLOWDNS_NS" ]] && ((count++))
    [[ -n "$VAYDNS_NS" ]] && ((count++))
    [[ -n "$SLIPSTREAM_NS" ]] && ((count++))

    if ((count == 0)); then
        info "No hay protocolos DNS configurados."

        systemctl stop "$SERVICE" >/dev/null 2>&1 || true
        systemctl disable "$SERVICE" >/dev/null 2>&1 || true

        remove_dnsdist_nat

        warn "dnsdist detenido."
        return 0
    fi

    install_dnsdist
    generate_config

    if ! validate_config; then
        err "La configuración de dnsdist no es válida."
        return 1
    fi

    configure_nat

    systemctl enable "$SERVICE" >/dev/null 2>&1 || true
    systemctl restart "$SERVICE" ||
        die "No se pudo reiniciar dnsdist."

    sleep 1

    if systemctl is-active --quiet "$SERVICE"; then
        ok "dnsdist está ACTIVO."
    else
        err "dnsdist no quedó activo."
        systemctl --no-pager -l status "$SERVICE" || true
        return 1
    fi
}

set_protocol(){
    local name="$1"
    local label="$2"
    local port="$3"

    load_config

    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${WHITE}Configurar ${label}${RESET}"
    echo -e "${GRAY}Backend: 127.0.0.1:${port}${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    local current=""

    case "$name" in
        slow) current="$SLOWDNS_NS" ;;
        vay) current="$VAYDNS_NS" ;;
        slip) current="$SLIPSTREAM_NS" ;;
    esac

    echo -e "Actual: ${current:-NO CONFIGURADO}"
    echo

    read -rp "NS/Dominio (Enter para desactivar): " value
    value="${value// /}"

    if [[ -n "$value" ]] && ! valid_ns "$value"; then
        err "El dominio contiene caracteres no válidos."
        return 1
    fi

    case "$name" in
        slow) SLOWDNS_NS="$value" ;;
        vay) VAYDNS_NS="$value" ;;
        slip) SLIPSTREAM_NS="$value" ;;
    esac

    save_config
    sync_dnsdist
}

show_protocols(){
    load_config

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}          PROTOCOLOS DNS ACTIVOS             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"

    if [[ -n "$SLOWDNS_NS" ]]; then
        echo -e "${CYAN}║${RESET} 🐌 SlowDNS    ${GREEN}ACTIVO${RESET}"
        echo -e "${CYAN}║${RESET}    NS: ${WHITE}${SLOWDNS_NS}${RESET}"
        echo -e "${CYAN}║${RESET}    Backend: 127.0.0.1:${SLOWDNS_PORT}"
    else
        echo -e "${CYAN}║${RESET} 🐌 SlowDNS    ${GRAY}OFF${RESET}"
    fi

    echo -e "${CYAN}║${RESET}"

    if [[ -n "$VAYDNS_NS" ]]; then
        echo -e "${CYAN}║${RESET} 🔐 VayDNS     ${GREEN}ACTIVO${RESET}"
        echo -e "${CYAN}║${RESET}    NS: ${WHITE}${VAYDNS_NS}${RESET}"
        echo -e "${CYAN}║${RESET}    Backend: 127.0.0.1:${VAYDNS_PORT}"
    else
        echo -e "${CYAN}║${RESET} 🔐 VayDNS     ${GRAY}OFF${RESET}"
    fi

    echo -e "${CYAN}║${RESET}"

    if [[ -n "$SLIPSTREAM_NS" ]]; then
        echo -e "${CYAN}║${RESET} 🚀 Slipstream ${GREEN}ACTIVO${RESET}"
        echo -e "${CYAN}║${RESET}    NS: ${WHITE}${SLIPSTREAM_NS}${RESET}"
        echo -e "${CYAN}║${RESET}    Backend: 127.0.0.1:${SLIPSTREAM_PORT}"
    else
        echo -e "${CYAN}║${RESET} 🚀 Slipstream ${GRAY}OFF${RESET}"
    fi

    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
}

show_status(){
    need_root
    load_config

    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${WHITE}              KEVINTECH DNSDIST              ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
    echo

    if has dnsdist; then
        echo -e "  ${GREEN}●${RESET} dnsdist: ${GREEN}INSTALADO${RESET}"
    else
        echo -e "  ${RED}●${RESET} dnsdist: ${RED}NO INSTALADO${RESET}"
    fi

    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "  ${GREEN}●${RESET} Servicio: ${GREEN}ACTIVO${RESET}"
    else
        echo -e "  ${RED}●${RESET} Servicio: ${RED}INACTIVO${RESET}"
    fi

    echo
    echo -e "${WHITE}Listener:${RESET} 0.0.0.0:${DNSDIST_PORT}"
    echo -e "${WHITE}IPv6:${RESET}     [::]:${DNSDIST_PORT}"

    show_protocols

    echo
    systemctl --no-pager -l status "$SERVICE" 2>/dev/null |
        head -n 14 || true
}

show_config(){
    need_root

    if [[ -f "$DNSDIST_CONF" ]]; then
        echo
        echo -e "${CYAN}━━━━━━━━ dnsdist.conf ━━━━━━━━${RESET}"
        cat "$DNSDIST_CONF"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    else
        warn "No existe $DNSDIST_CONF"
    fi
}

logs(){
    need_root
    journalctl -u "$SERVICE" -n 100 --no-pager
}

remove_dnsdist(){
    need_root

    echo
    echo -e "${RED}╔══════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${WHITE}            DESINSTALAR DNSDIST              ${RED}║${RESET}"
    echo -e "${RED}╚══════════════════════════════════════════════╝${RESET}"
    echo

    read -rp "¿Eliminar dnsdist y su configuración? [s/N]: " r
    [[ "$r" =~ ^[sS]$ ]] || return 0

    systemctl stop "$SERVICE" >/dev/null 2>&1 || true
    systemctl disable "$SERVICE" >/dev/null 2>&1 || true

    remove_dnsdist_nat

    rm -f "$DNSDIST_CONF"
    rm -f "$CONFIG"

    if has apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get remove -y dnsdist >/dev/null 2>&1 || true
        apt-get autoremove -y >/dev/null 2>&1 || true
    fi

    ok "dnsdist desinstalado."
}

menu(){
    need_root

    while true; do
        clear

        echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${WHITE}            KEVINTECH DNSDIST                ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${CYAN}║${RESET} [01] 🚀 Sincronizar / Instalar              ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [02] 🐌 Configurar SlowDNS                  ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [03] 🔐 Configurar VayDNS                   ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [04] 🚀 Configurar Slipstream               ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [05] 📊 Ver estado                           ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [06] 📜 Ver configuración                    ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [07] 📋 Ver logs                             ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [08] 🛑 Detener DNSDist                     ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [09] 🗑️  Desinstalar DNSDist                 ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET} [00] ↩️  Regresar                             ${CYAN}║${RESET}"
        echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
        echo

        read -rp "Selecciona una opción: " op

        case "$op" in
            1|01)
                sync_dnsdist
                read -rp "Presiona Enter para continuar..."
                ;;
            2|02)
                set_protocol slow "SlowDNS" "$SLOWDNS_PORT"
                read -rp "Presiona Enter para continuar..."
                ;;
            3|03)
                set_protocol vay "VayDNS" "$VAYDNS_PORT"
                read -rp "Presiona Enter para continuar..."
                ;;
            4|04)
                set_protocol slip "Slipstream" "$SLIPSTREAM_PORT"
                read -rp "Presiona Enter para continuar..."
                ;;
            5|05)
                show_status
                read -rp "Presiona Enter para continuar..."
                ;;
            6|06)
                show_config
                read -rp "Presiona Enter para continuar..."
                ;;
            7|07)
                logs
                read -rp "Presiona Enter para continuar..."
                ;;
            8|08)
                systemctl stop "$SERVICE" >/dev/null 2>&1 || true
                remove_dnsdist_nat
                ok "DNSDist detenido."
                read -rp "Presiona Enter para continuar..."
                ;;
            9|09)
                remove_dnsdist
                read -rp "Presiona Enter para continuar..."
                ;;
            0|00)
                return
                ;;
            *)
                warn "Opción inválida."
                sleep 1
                ;;
        esac
    done
}

case "${1:-}" in
    --sync|--install)
        sync_dnsdist
        ;;
    --status)
        show_status
        ;;
    --restart)
        need_root
        systemctl restart "$SERVICE" &&
            ok "dnsdist reiniciado." ||
            die "No se pudo reiniciar dnsdist."
        ;;
    --stop)
        need_root
        systemctl stop "$SERVICE" || true
        remove_dnsdist_nat
        ok "dnsdist detenido."
        ;;
    --logs)
        logs
        ;;
    --config)
        show_config
        ;;
    --remove|--uninstall)
        remove_dnsdist
        ;;
    --help|-h)
        echo "Uso:"
        echo "  $0              Menú"
        echo "  $0 --sync       Sincronizar protocolos"
        echo "  $0 --status     Estado"
        echo "  $0 --restart    Reiniciar"
        echo "  $0 --stop       Detener"
        echo "  $0 --logs       Logs"
        echo "  $0 --config     Ver configuración"
        echo "  $0 --remove     Desinstalar"
        ;;
    *)
        menu
        ;;
esac
