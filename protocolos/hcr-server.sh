#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/sbin:/usr/bin:/sbin:/bin"
LC_ALL="C"
LANG="C"
export PATH LC_ALL LANG

SERVICE_NAME="hcr-server"
SYSTEMD_DIR="/etc/systemd/system"

PORT="8080"
PORT_SET="false"
ACTION="install"

TEMP_UNIT=""

fail() {
    echo "Error: $*" >&2
    exit 1
}

command -v readlink >/dev/null 2>&1 || fail "readlink was not found."

SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname -- "${SCRIPT_PATH}")"

BINARY_PATH="${SCRIPT_DIR}/hcr-server"
UNIT_SOURCE_PATH="${SCRIPT_DIR}/${SERVICE_NAME}.service"
UNIT_LINK_PATH="${SYSTEMD_DIR}/${SERVICE_NAME}.service"

usage() {
    cat <<'EOF'
Instala HCR Server como servicio systemd.

Uso:
  sudo ./install.sh [--port <1-65535>]
  sudo ./install.sh --uninstall
  ./install.sh --help

Opciones:
  --port <number>     Puerto de escucha. Por defecto: 8080
  --uninstall         Detiene y elimina el servicio
  -h, --help          Muestra esta ayuda

Requisitos:
  hcr-server          Binario de HCR Server junto a este instalador

Este instalador utiliza únicamente hcr-server.
No requiere certificados TLS ni archivos adicionales.
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --port)
                [ "$#" -ge 2 ] || fail "--port requiere un valor."
                PORT="$2"
                PORT_SET="true"
                shift 2
                ;;

            --uninstall)
                ACTION="uninstall"
                shift
                ;;

            -h|--help)
                usage
                exit 0
                ;;

            *)
                fail "Opción desconocida: $1"
                ;;
        esac
    done

    case "${PORT}" in
        ""|*[!0-9]*)
            fail "--port debe ser un número entre 1 y 65535."
            ;;
    esac

    if [ "$((10#${PORT}))" -lt 1 ] || [ "$((10#${PORT}))" -gt 65535 ]; then
        fail "--port debe ser un número entre 1 y 65535."
    fi

    PORT="$((10#${PORT}))"

    if [ "${ACTION}" = "uninstall" ] && [ "${PORT_SET}" = "true" ]; then
        fail "--port no puede combinarse con --uninstall."
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        fail "$1 no fue encontrado."
}

require_environment() {
    [ "$(id -u)" -eq 0 ] ||
        fail "Ejecuta este instalador como root usando sudo."

    [ "$(uname -s)" = "Linux" ] ||
        fail "Este instalador solo funciona en Linux."

    for command_name in \
        stat \
        systemctl \
        systemd-analyze \
        flock \
        ln \
        mv \
        mktemp \
        sleep
    do
        require_command "${command_name}"
    done

    systemctl show --property=Version --value >/dev/null 2>&1 ||
        fail "El administrador systemd no está disponible."

    if [[ ! "${SCRIPT_DIR}" =~ ^/[-A-Za-z0-9._/@+:]+$ ]]; then
        fail "El directorio contiene caracteres no compatibles: ${SCRIPT_DIR}"
    fi
}

acquire_install_lock() {
    exec 9<"${SYSTEMD_DIR}" ||
        fail "No se pudo abrir ${SYSTEMD_DIR} para obtener el bloqueo."

    flock -n 9 ||
        fail "Otro instalador de HCR Server ya está ejecutándose."
}

mode_is_writable_by_others() {
    (( (8#$1 & 8#022) != 0 ))
}

validate_secure_directory() {
    local current="${SCRIPT_DIR}"
    local mode

    while :; do
        [ -d "${current}" ] && [ ! -L "${current}" ] ||
            fail "El componente debe ser un directorio real: ${current}"

        [ "$(stat -c '%u' -- "${current}")" = "0" ] ||
            fail "El directorio debe pertenecer a root: ${current}"

        mode="$(stat -c '%a' -- "${current}")"

        mode_is_writable_by_others "${mode}" &&
            fail "El directorio no debe permitir escritura a grupo u otros: ${current}"

        [ "${current}" = "/" ] && break

        current="$(dirname -- "${current}")"
    done
}

validate_root_file() {
    local executable="$1"
    local label="$2"
    local path="$3"
    local mode

    [ -f "${path}" ] && [ ! -L "${path}" ] ||
        fail "${label} debe ser un archivo normal: ${path}"

    [ "$(stat -c '%u' -- "${path}")" = "0" ] ||
        fail "${label} debe pertenecer a root: ${path}"

    mode="$(stat -c '%a' -- "${path}")"

    mode_is_writable_by_others "${mode}" &&
        fail "${label} no debe permitir escritura a grupo u otros: ${path}"

    if [ "${executable}" = "true" ] && [ ! -x "${path}" ]; then
        fail "${label} debe ser ejecutable: ${path}"
    fi
}

validate_unit_link() {
    if [ -L "${UNIT_LINK_PATH}" ]; then
        [ "$(readlink -- "${UNIT_LINK_PATH}")" = "${UNIT_SOURCE_PATH}" ] ||
            fail "Ya existe un enlace ${SERVICE_NAME}.service diferente."

    elif [ -e "${UNIT_LINK_PATH}" ]; then
        fail "Ya existe un archivo de servicio no simbólico: ${UNIT_LINK_PATH}"
    fi
}

loaded_fragment_path() {
    systemctl show \
        --property=FragmentPath \
        --value \
        "${SERVICE_NAME}.service" \
        2>/dev/null || true
}

validate_loaded_fragment() {
    case "$1" in
        "")
            ;;

        "${UNIT_SOURCE_PATH}")
            ;;

        "${UNIT_LINK_PATH}")
            ;;

        *)
            fail "systemd cargó ${SERVICE_NAME}.service desde una ubicación inesperada: $1"
            ;;
    esac
}

validate_binary_identity() {
    local output

    output="$("${BINARY_PATH}" -version 2>/dev/null)" ||
        fail "El binario no admite el parámetro -version."

    [[ "${output}" =~ ^hcr-server\ version\ [0-9]+\.[0-9]+\.[0-9]+(\ -\ Patch\ [1-9][0-9]*)?$ ]] ||
        fail "El binario devolvió una versión inesperada: ${output}"
}

validate_binary() {
    validate_root_file true "HCR binary" "${BINARY_PATH}"
    validate_binary_identity
}

validate_bundle() {
    validate_secure_directory

    validate_root_file true "Installer" "${SCRIPT_PATH}"

    validate_binary

    if [ -e "${UNIT_SOURCE_PATH}" ] || [ -L "${UNIT_SOURCE_PATH}" ]; then
        validate_root_file false \
            "Generated systemd unit" \
            "${UNIT_SOURCE_PATH}"
    fi
}

render_unit() {
    TEMP_UNIT="$(mktemp "${SCRIPT_DIR}/.${SERVICE_NAME}.XXXXXX.service")"

    chmod 0600 "${TEMP_UNIT}"

    cat >"${TEMP_UNIT}" <<EOF
[Unit]
Description=HCR relay
Wants=network-online.target
After=network-online.target ssh.service sshd.service

StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=exec

User=root
Group=root

WorkingDirectory=${SCRIPT_DIR}

ExecStart=${BINARY_PATH} --listen :${PORT} --target 127.0.0.1:22

Restart=on-failure
RestartSec=5s

TimeoutStopSec=15s
KillSignal=SIGTERM

UMask=0077

NoNewPrivileges=true
CapabilityBoundingSet=
AmbientCapabilities=

PrivateTmp=true
PrivateDevices=true

ProtectSystem=strict
ProtectHome=read-only
ProtectControlGroups=true

RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true

MemoryDenyWriteExecute=false

ReadOnlyPaths=${SCRIPT_DIR}

LimitNOFILE=4096
LimitCORE=0

TasksMax=512
MemoryMax=384M

StandardOutput=journal
StandardError=journal

SyslogIdentifier=hcr-server

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "${TEMP_UNIT}"

    systemd-analyze verify "${TEMP_UNIT}"
}

cleanup() {
    local exit_code=$?

    trap - EXIT
    set +e

    [ -n "${TEMP_UNIT}" ] &&
        rm -f -- "${TEMP_UNIT}"

    exit "${exit_code}"
}

verify_service_health() {
    local initial_pid

    initial_pid="$(
        systemctl show \
            --property=MainPID \
            --value \
            "${SERVICE_NAME}.service"
    )"

    [[ "${initial_pid}" =~ ^[1-9][0-9]*$ ]] ||
        fail "El servicio no informó un proceso activo."

    sleep 3

    systemctl is-active --quiet "${SERVICE_NAME}.service" ||
        fail "El servicio no permaneció activo."

    [ "$(systemctl show \
        --property=MainPID \
        --value \
        "${SERVICE_NAME}.service")" = "${initial_pid}" ] ||
        fail "El servicio se reinició durante la comprobación."
}

install_service() {
    validate_unit_link

    validate_loaded_fragment "$(loaded_fragment_path)"

    render_unit

    mv -f -- \
        "${TEMP_UNIT}" \
        "${UNIT_SOURCE_PATH}"

    TEMP_UNIT=""

    if [ ! -L "${UNIT_LINK_PATH}" ]; then
        ln -s -- \
            "${UNIT_SOURCE_PATH}" \
            "${UNIT_LINK_PATH}"
    fi

    systemctl daemon-reload

    systemctl enable "${SERVICE_NAME}.service"

    systemctl reset-failed \
        "${SERVICE_NAME}.service" \
        >/dev/null 2>&1 || true

    if ! systemctl restart "${SERVICE_NAME}.service"; then
        systemctl status \
            --no-pager \
            --full \
            "${SERVICE_NAME}.service" || true

        fail "El servicio no pudo iniciarse."
    fi

    systemctl is-active --quiet "${SERVICE_NAME}.service" ||
        fail "El servicio no permaneció activo."

    [ "$(systemctl show \
        --property=WorkingDirectory \
        --value \
        "${SERVICE_NAME}.service")" = "${SCRIPT_DIR}" ] ||
        fail "systemd informó un WorkingDirectory inesperado."

    verify_service_health

    echo
    echo "========================================"
    echo " HCR Server instalado correctamente"
    echo "========================================"
    echo
    echo "Directorio: ${SCRIPT_DIR}"
    echo "Binario:    ${BINARY_PATH}"
    echo "Servicio:   ${UNIT_SOURCE_PATH}"
    echo "Puerto:     ${PORT}"
    echo
    echo "Estado:"
    systemctl --no-pager --full status "${SERVICE_NAME}.service" || true
}

uninstall_service() {
    local fragment
    local owned="false"

    validate_secure_directory

    validate_root_file \
        true \
        "Installer" \
        "${SCRIPT_PATH}"

    if [ -e "${UNIT_SOURCE_PATH}" ]; then
        validate_root_file \
            false \
            "Generated systemd unit" \
            "${UNIT_SOURCE_PATH}"
    fi

    validate_unit_link

    fragment="$(loaded_fragment_path)"

    validate_loaded_fragment "${fragment}"

    [ -L "${UNIT_LINK_PATH}" ] &&
        owned="true"

    if [ "${fragment}" = "${UNIT_SOURCE_PATH}" ] ||
       [ "${fragment}" = "${UNIT_LINK_PATH}" ]; then
        owned="true"
    fi

    if [ "${owned}" = "false" ]; then
        echo "HCR Server no está instalado desde este directorio."
        echo "No se eliminó nada."
        return
    fi

    systemctl disable --now "${SERVICE_NAME}.service"

    if [ -L "${UNIT_LINK_PATH}" ]; then
        [ "$(readlink -- "${UNIT_LINK_PATH}")" = "${UNIT_SOURCE_PATH}" ] ||
            fail "El enlace del servicio cambió durante la desinstalación."

        rm -f -- "${UNIT_LINK_PATH}"
    fi

    systemctl daemon-reload

    systemctl reset-failed \
        "${SERVICE_NAME}.service" \
        >/dev/null 2>&1 || true

    echo
    echo "HCR Server fue desinstalado."
    echo
    echo "El binario y los archivos del directorio fueron conservados:"
    echo "${SCRIPT_DIR}"
}

main() {
    trap cleanup EXIT

    parse_args "$@"

    require_environment

    acquire_install_lock

    if [ "${ACTION}" = "uninstall" ]; then
        uninstall_service
    else
        validate_bundle
        install_service
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
