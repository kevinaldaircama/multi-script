#!/usr/bin/env bash

# ==============================================================
#                  🌐 KEVINTECH BHTTP
#                    PREMIUM MODULE
# ==============================================================
#
# Archivo : /etc/kevintech/protocolos/bhttp.sh
# Config  : /etc/kevintech/bhttp.conf
# Servicio: bhttp.service
# Versión : 3.3 Premium
#
# ==============================================================

set -o pipefail

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

BASE="/etc/kevintech"

BHTTP_DIR="/usr/local/lib/bhttp"
SERVER_PY="$BHTTP_DIR/bhttp-server.py"

UNIT="/etc/systemd/system/bhttp.service"
SERVICE="bhttp"

CONFIG="$BASE/bhttp.conf"

BHTTP_HOST="0.0.0.0"
BHTTP_PORT="8080"

SSH_HOST="127.0.0.1"
SSH_PORT="22"

VERSION="3.3"

# ==============================================================
# COLORES
# ==============================================================

RESET="\e[0m"
BOLD="\e[1m"

CYAN="\e[1;96m"
BLUE="\e[1;94m"
GREEN="\e[1;92m"
YELLOW="\e[1;93m"
MAGENTA="\e[1;95m"
RED="\e[1;91m"
WHITE="\e[1;97m"
GRAY="\e[1;90m"

# ==============================================================
# SEGURIDAD
# ==============================================================

if [[ $EUID -ne 0 ]]; then

    clear

    echo
    echo -e "${RED}${BOLD}✘ ACCESO DENEGADO${RESET}"
    echo
    echo -e "${WHITE}Este módulo requiere permisos de root.${RESET}"
    echo

    exit 1
fi

mkdir -p "$BASE"

# ==============================================================
# UTILIDADES
# ==============================================================

line() {

    echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"
}

separator() {

    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

pause() {

    echo
    read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"
}

valid_port() {

    [[ "$1" =~ ^[0-9]+$ ]] &&
    (( "$1" >= 1 )) &&
    (( "$1" <= 65535 ))
}

# ==============================================================
# CONFIGURACIÓN
# ==============================================================

crear_config() {

    if [[ ! -f "$CONFIG" ]]; then

        cat > "$CONFIG" <<EOF
BHTTP_PORT=8080
BHTTP_HOST=0.0.0.0
SSH_PORT=22
SSH_HOST=127.0.0.1
BHTTP=OFF
EOF

    fi
}

cargar_config() {

    crear_config

    # shellcheck disable=SC1090
    source "$CONFIG" 2>/dev/null || true

    BHTTP_PORT="${BHTTP_PORT:-8080}"
    BHTTP_HOST="${BHTTP_HOST:-0.0.0.0}"

    SSH_PORT="${SSH_PORT:-22}"
    SSH_HOST="${SSH_HOST:-127.0.0.1}"
}

guardar_config() {

    cat > "$CONFIG" <<EOF
BHTTP_PORT=$BHTTP_PORT
BHTTP_HOST=$BHTTP_HOST
SSH_PORT=$SSH_PORT
SSH_HOST=$SSH_HOST
BHTTP=$BHTTP
EOF

}

cargar_config

# ==============================================================
# DETECCIÓN DE SERVICIO
# ==============================================================

servicio_instalado() {

    [[ -f "$UNIT" ]] &&
    [[ -f "$SERVER_PY" ]]
}

servicio_online() {

    systemctl is-active --quiet "$SERVICE" 2>/dev/null
}

servicio_habilitado() {

    systemctl is-enabled --quiet "$SERVICE" 2>/dev/null
}

# ==============================================================
# DETECCIÓN DE PUERTO
# ==============================================================

puerto_escuchando() {

    local PORT="$1"

    [[ "$PORT" =~ ^[0-9]+$ ]] || return 1

    if command -v ss >/dev/null 2>&1; then

        ss -H -ltn 2>/dev/null |
            awk '{print $4}' |
            grep -qE ":${PORT}$"

        return $?

    fi

    return 1
}

puerto_ocupado() {

    local PORT="$1"

    puerto_escuchando "$PORT"
}

# ==============================================================
# ESTADO VISUAL
# ==============================================================

estado_servicio() {

    if ! servicio_instalado; then

        echo -e "${GRAY}● NO INSTALADO${RESET}"

        return
    fi

    if servicio_online && puerto_escuchando "$BHTTP_PORT"; then

        echo -e "${GREEN}● ONLINE${RESET}"

    elif servicio_online; then

        echo -e "${YELLOW}● ONLINE / PUERTO NO DETECTADO${RESET}"

    elif servicio_habilitado; then

        echo -e "${YELLOW}● STOPPED${RESET}"

    else

        echo -e "${RED}● OFF${RESET}"

    fi
}

# ==============================================================
# ESCRIBIR SERVIDOR BHTTP
# ==============================================================

instalar_servidor_python() {

    mkdir -p "$BHTTP_DIR"

    cat > "$SERVER_PY" <<'PYEOF'
#!/usr/bin/env python3

import argparse
import asyncio
import hashlib
import sys

MAGIC = b"BHP1"
LONGPOLL = 2.0


def log(msg):

    sys.stderr.write(
        "[bhttp] %s\n" % msg
    )

    sys.stderr.flush()


def keystream(
    sess,
    mode,
    seq,
    direction,
    length
):

    base = hashlib.sha256(
        sess +
        bytes([mode]) +
        seq.to_bytes(8, "big") +
        bytes([direction])
    )

    output = bytearray()
    counter = 0

    while len(output) < length:

        h = base.copy()

        h.update(
            counter.to_bytes(4, "big")
        )

        output += h.digest()

        counter += 1

    return bytes(output[:length])


def mask(
    data,
    sess,
    mode,
    seq,
    direction
):

    stream = keystream(
        sess,
        mode,
        seq,
        direction,
        len(data)
    )

    return bytes(
        a ^ b
        for a, b in zip(data, stream)
    )


def probe_reply(mode, size):

    length = (
        size
        if mode == 2 and size >= 10
        else 10
    )

    output = bytearray(
        MAGIC +
        bytes([1, mode]) +
        size.to_bytes(4, "big")
    )

    for i in range(10, length):

        output.append(
            (i * 31) & 255
        )

    return bytes(output)


class Session:

    def __init__(
        self,
        session_id,
        backend
    ):

        self.session_id = session_id
        self.backend = backend

        self.condition = asyncio.Condition()

        self.upload_next = 0
        self.upload_pending = {}

        self.download_raw = bytearray()
        self.download_chunks = {}
        self.download_assign = 0

        self.eof = False
        self.closed = False

        self.reader = None
        self.writer = None

    async def connect(self):

        host, port = self.backend

        self.reader, self.writer = (
            await asyncio.open_connection(
                host,
                port
            )
        )

        log(
            "sesion %s: conectada al backend %s:%d"
            % (
                self.session_id.hex()[:8],
                host,
                port
            )
        )

        asyncio.create_task(
            self.backend_reader()
        )

    async def backend_reader(self):

        total = 0

        try:

            while True:

                data = await self.reader.read(
                    65536
                )

                if not data:
                    break

                total += len(data)

                async with self.condition:

                    self.download_raw += data

                    self.condition.notify_all()

        except Exception as error:

            log(
                "sesion %s: error backend: %s"
                % (
                    self.session_id.hex()[:8],
                    error
                )
            )

        finally:

            log(
                "sesion %s: backend cerrado (%d B)"
                % (
                    self.session_id.hex()[:8],
                    total
                )
            )

            async with self.condition:

                self.eof = True

                self.condition.notify_all()

    async def upload(
        self,
        sequence,
        data
    ):

        async with self.condition:

            if data:

                self.upload_pending[
                    sequence
                ] = data

            while (
                self.upload_next
                in self.upload_pending
            ):

                chunk = self.upload_pending.pop(
                    self.upload_next
                )

                try:

                    self.writer.write(chunk)

                    await self.writer.drain()

                except Exception:

                    self.closed = True

                self.upload_next += 1

    async def download(
        self,
        sequence,
        maximum,
        deadline
    ):

        if maximum <= 0:
            maximum = 1399

        loop = asyncio.get_running_loop()

        async with self.condition:

            while True:

                if sequence < self.download_assign:

                    return self.download_chunks.get(
                        sequence,
                        b""
                    )

                if sequence == self.download_assign:

                    if self.download_raw:

                        chunk = bytes(
                            self.download_raw[:maximum]
                        )

                        del self.download_raw[:maximum]

                        self.download_chunks[
                            self.download_assign
                        ] = chunk

                        self.download_assign += 1

                        self.condition.notify_all()

                        return chunk

                    if self.eof:

                        self.download_assign += 1

                        self.condition.notify_all()

                        return b""

                if (
                    not self.eof
                    and
                    loop.time() < deadline
                ):

                    try:

                        await asyncio.wait_for(
                            self.condition.wait(),
                            timeout=max(
                                0.01,
                                deadline - loop.time()
                            )
                        )

                    except asyncio.TimeoutError:

                        pass

                    continue

                while (
                    self.download_assign <= sequence
                ):

                    self.download_assign += 1

                self.condition.notify_all()

                return b""

    async def acknowledge(
        self,
        sequence
    ):

        async with self.condition:

            for key in list(
                self.download_chunks.keys()
            ):

                if key <= sequence:

                    del self.download_chunks[key]

    async def close(self):

        async with self.condition:

            self.closed = True

            self.condition.notify_all()

        try:

            self.writer.close()

        except Exception:

            pass


class Server:

    def __init__(
        self,
        host,
        port,
        backend
    ):

        self.host = host
        self.port = port
        self.backend = backend

        self.sessions = {}

        self.session_lock = asyncio.Lock()

    async def get_session(
        self,
        session_id
    ):

        async with self.session_lock:

            session = self.sessions.get(
                session_id
            )

            if (
                session is None
                or
                session.closed
            ):

                for (
                    old_id,
                    old_session
                ) in list(
                    self.sessions.items()
                ):

                    if old_id != session_id:

                        await old_session.close()

                        del self.sessions[
                            old_id
                        ]

                session = Session(
                    session_id,
                    self.backend
                )

                await session.connect()

                self.sessions[
                    session_id
                ] = session

                log(
                    "sesion %s: registrada (sesiones vivas: %d)"
                    % (
                        session_id.hex()[:8],
                        len(self.sessions)
                    )
                )

            return session

    async def handle(
        self,
        reader,
        writer
    ):

        try:

            while True:

                header = await reader.readexactly(
                    29
                )

                mode = header[0]

                session_id = header[1:17]

                sequence = int.from_bytes(
                    header[17:25],
                    "big"
                )

                length = int.from_bytes(
                    header[25:29],
                    "big"
                )

                payload = b""

                if (
                    length
                    and
                    mode in (0, 1, 2, 3)
                ):

                    raw = await reader.readexactly(
                        length
                    )

                    payload = mask(
                        raw,
                        session_id,
                        mode,
                        sequence,
                        0
                    )

                if payload[:4] == MAGIC:

                    size = (
                        int.from_bytes(
                            payload[6:10],
                            "big"
                        )
                        if len(payload) >= 10
                        else 0
                    )

                    probe_mode = (
                        payload[5]
                        if len(payload) >= 6
                        else mode
                    )

                    reply = mask(
                        probe_reply(
                            probe_mode,
                            size
                        ),
                        session_id,
                        mode,
                        sequence,
                        1
                    )

                    writer.write(
                        bytes([0]) +
                        len(reply).to_bytes(
                            4,
                            "big"
                        ) +
                        reply
                    )

                    await writer.drain()

                    continue

                session = await self.get_session(
                    session_id
                )

                if mode == 1:

                    await session.upload(
                        sequence,
                        payload
                    )

                    writer.write(
                        bytes([0]) +
                        (0).to_bytes(4, "big")
                    )

                    await writer.drain()

                elif mode == 2:

                    chunk = await session.download(
                        sequence,
                        length
                        if length > 0
                        else 1399,
                        asyncio.get_running_loop().time()
                        + LONGPOLL
                    )

                    self.send_data(
                        writer,
                        session_id,
                        mode,
                        sequence,
                        chunk
                    )

                    await writer.drain()

                elif mode == 3:

                    if len(payload) >= 6:

                        chunk_size = int.from_bytes(
                            payload[0:4],
                            "big"
                        )

                        count = payload[5]

                    else:

                        chunk_size = 1399
                        count = 1

                    if chunk_size <= 0:
                        chunk_size = 1399

                    if count <= 0:
                        count = 1

                    deadline = (
                        asyncio.get_running_loop().time()
                        + LONGPOLL
                    )

                    for index in range(count):

                        chunk = await session.download(
                            sequence + index,
                            chunk_size,
                            deadline
                        )

                        self.send_data(
                            writer,
                            session_id,
                            mode,
                            sequence + index,
                            chunk
                        )

                    await writer.drain()

                elif mode == 4:

                    await session.acknowledge(
                        sequence
                    )

                    writer.write(
                        bytes([0]) +
                        (0).to_bytes(4, "big")
                    )

                    await writer.drain()

                else:

                    return

        except (
            asyncio.IncompleteReadError,
            ConnectionError,
            OSError
        ):

            pass

        except Exception as error:

            log(
                "handle: error inesperado: %r"
                % error
            )

        finally:

            try:

                writer.close()

            except Exception:

                pass

    def send_data(
        self,
        writer,
        session_id,
        mode,
        sequence,
        data
    ):

        real_length = len(data)

        encrypted = (
            mask(
                data,
                session_id,
                mode,
                sequence,
                1
            )
            if data
            else b""
        )

        body = (
            real_length.to_bytes(
                4,
                "big"
            )
            +
            encrypted
        )

        writer.write(
            bytes([2]) +
            len(body).to_bytes(
                4,
                "big"
            ) +
            body
        )

    async def serve(self):

        server = await asyncio.start_server(
            self.handle,
            self.host,
            self.port,
            backlog=512
        )

        print(
            "BHTTP escuchando en %s:%d -> backend %s:%d"
            % (
                self.host,
                self.port,
                self.backend[0],
                self.backend[1]
            ),
            flush=True
        )

        async with server:

            await server.serve_forever()


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--host",
        default="0.0.0.0"
    )

    parser.add_argument(
        "--port",
        type=int,
        required=True
    )

    parser.add_argument(
        "--backend-host",
        default="127.0.0.1"
    )

    parser.add_argument(
        "--backend-port",
        type=int,
        default=22
    )

    args = parser.parse_args()

    asyncio.run(
        Server(
            args.host,
            args.port,
            (
                args.backend_host,
                args.backend_port
            )
        ).serve()
    )


if __name__ == "__main__":

    main()

PYEOF

    chmod 755 "$SERVER_PY"
}

# ==============================================================
# CREAR SERVICIO SYSTEMD
# ==============================================================

crear_servicio() {

    local PYTHON

    PYTHON=$(command -v python3)

    if [[ -z "$PYTHON" ]]; then

        echo -e "${RED}✘ Python3 no está instalado.${RESET}"

        return 1
    fi

    cat > "$UNIT" <<EOF
[Unit]
Description=KevinTech BHTTP Server
After=network.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BHTTP_DIR
ExecStart=$PYTHON $SERVER_PY --host $BHTTP_HOST --port $BHTTP_PORT --backend-host $SSH_HOST --backend-port $SSH_PORT
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$UNIT"
}

# ==============================================================
# DETENER SERVICIO
# ==============================================================

detener_servicio_silencioso() {

    systemctl stop "$SERVICE" 2>/dev/null || true

    sleep 1
}

# ==============================================================
# INICIAR Y VERIFICAR
# ==============================================================

iniciar_y_verificar() {

    systemctl daemon-reload

    systemctl enable "$SERVICE" >/dev/null 2>&1

    systemctl restart "$SERVICE"

    local ONLINE=0
    local LISTEN=0

    echo
    echo -e "${GRAY}▸ Verificando BHTTP...${RESET}"

    for ((i=1; i<=10; i++)); do

        if servicio_online; then
            ONLINE=1
        fi

        if puerto_escuchando "$BHTTP_PORT"; then
            LISTEN=1
        fi

        if [[ "$ONLINE" == "1" &&
              "$LISTEN" == "1" ]]; then
            break
        fi

        sleep 1

    done

    if [[ "$ONLINE" == "1" &&
          "$LISTEN" == "1" ]]; then

        BHTTP="ON"

        guardar_config

        return 0

    fi

    BHTTP="OFF"

    guardar_config

    return 1
}

# ==============================================================
# MOSTRAR ERROR DE SERVICIO
# ==============================================================

mostrar_error_servicio() {

    echo

    echo -e "${RED}${BOLD}✘ BHTTP no quedó funcionando correctamente.${RESET}"

    echo

    echo -e "${WHITE}Estado:${RESET}"

    systemctl status "$SERVICE" \
        --no-pager \
        -l \
        2>/dev/null

    echo

    echo -e "${YELLOW}Últimos registros:${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 20 \
        --no-pager \
        -l \
        2>/dev/null
}

# ==============================================================
# INSTALAR / ACTUALIZAR
# ==============================================================

instalar_bhttp() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║                    🌐 INSTALAR BHTTP                        ║"
    echo "║                                                              ║"
    echo "║                 KEVINTECH PREMIUM v3.3                     ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    cargar_config

    echo
    echo -e "${WHITE}Configuración del servidor${RESET}"
    line

    local OLD_PORT="$BHTTP_PORT"

    read -rp \
        "$(echo -e "${CYAN}Puerto BHTTP [${BHTTP_PORT}]: ${RESET}")" NEW_PORT

    [[ -z "$NEW_PORT" ]] && NEW_PORT="$BHTTP_PORT"

    if ! valid_port "$NEW_PORT"; then

        echo
        echo -e "${RED}✘ Puerto inválido.${RESET}"

        pause

        return 1
    fi

    BHTTP_PORT="$NEW_PORT"

    read -rp \
        "$(echo -e "${CYAN}Puerto SSH backend [${SSH_PORT}]: ${RESET}")" NEW_SSH

    [[ -z "$NEW_SSH" ]] && NEW_SSH="$SSH_PORT"

    if ! valid_port "$NEW_SSH"; then

        echo
        echo -e "${RED}✘ Puerto SSH inválido.${RESET}"

        BHTTP_PORT="$OLD_PORT"

        pause

        return 1
    fi

    SSH_PORT="$NEW_SSH"

    BHTTP_HOST="0.0.0.0"
    SSH_HOST="127.0.0.1"
    BHTTP="ON"

    # ==========================================================
    # SI EL PUERTO ESTÁ OCUPADO
    # ==========================================================

    if puerto_ocupado "$BHTTP_PORT"; then

        # Si es nuestro propio BHTTP, podemos reutilizarlo.
        if [[ "$BHTTP_PORT" == "$OLD_PORT" ]] &&
           servicio_online; then

            echo
            echo -e "${YELLOW}⚠ El puerto $BHTTP_PORT pertenece actualmente a BHTTP.${RESET}"
            echo -e "${GRAY}Se actualizará y reiniciará el servicio.${RESET}"

        else

            echo
            echo -e "${RED}✘ El puerto $BHTTP_PORT ya está ocupado.${RESET}"
            echo
            echo -e "${GRAY}Comprueba con:${RESET}"
            echo -e "${WHITE}ss -ltnp | grep :$BHTTP_PORT${RESET}"

            pause

            return 1
        fi
    fi

    guardar_config

    echo
    echo -e "${MAGENTA}${BOLD}▸ Preparando BHTTP...${RESET}"

    # ==========================================================
    # DETENER VERSIÓN ANTERIOR
    # ==========================================================

    if servicio_instalado; then

        echo -e "${GRAY}▸ Deteniendo versión anterior...${RESET}"

        systemctl stop "$SERVICE" 2>/dev/null || true

        sleep 1

    fi

    # ==========================================================
    # PYTHON
    # ==========================================================

    if ! command -v python3 >/dev/null 2>&1; then

        echo -e "${YELLOW}▸ Instalando Python3...${RESET}"

        apt-get update -qq >/dev/null 2>&1

        apt-get install -y python3 >/dev/null 2>&1

        if ! command -v python3 >/dev/null 2>&1; then

            echo -e "${RED}✘ No se pudo instalar Python3.${RESET}"

            pause

            return 1
        fi

        echo -e "${GREEN}✔ Python3 instalado.${RESET}"

    fi

    # ==========================================================
    # SERVIDOR
    # ==========================================================

    echo -e "${GRAY}▸ Instalando servidor BHTTP...${RESET}"

    if ! instalar_servidor_python; then

        echo -e "${RED}✘ No se pudo instalar el servidor BHTTP.${RESET}"

        pause

        return 1
    fi

    echo -e "${GREEN}✔ Servidor BHTTP instalado.${RESET}"

    # ==========================================================
    # SYSTEMD
    # ==========================================================

    echo -e "${GRAY}▸ Configurando servicio systemd...${RESET}"

    if ! crear_servicio; then

        echo -e "${RED}✘ No se pudo crear bhttp.service.${RESET}"

        pause

        return 1
    fi

    echo -e "${GREEN}✔ Servicio creado.${RESET}"

    # ==========================================================
    # INICIAR AUTOMÁTICAMENTE
    # ==========================================================

    echo -e "${GRAY}▸ Activando inicio automático...${RESET}"

    systemctl daemon-reload

    if systemctl enable "$SERVICE" >/dev/null 2>&1; then

        echo -e "${GREEN}✔ Inicio automático activado.${RESET}"

    else

        echo -e "${YELLOW}⚠ No se pudo activar el inicio automático.${RESET}"

    fi

    # ==========================================================
    # ARRANCAR
    # ==========================================================

    echo -e "${GRAY}▸ Iniciando BHTTP...${RESET}"

    if iniciar_y_verificar; then

        echo
        echo -e "${GREEN}${BOLD}✔ BHTTP INICIADO CORRECTAMENTE${RESET}"

        echo
        echo -e "${WHITE}Servicio :${RESET} ${GREEN}ONLINE${RESET}"
        echo -e "${WHITE}Puerto   :${RESET} ${CYAN}$BHTTP_PORT${RESET}"
        echo -e "${WHITE}Backend  :${RESET} ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"
        echo -e "${WHITE}Listener :${RESET} ${GREEN}0.0.0.0:$BHTTP_PORT${RESET}"

    else

        mostrar_error_servicio

        pause

        return 1
    fi

    echo

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🌐 BHTTP LISTO                           ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  Estado      : ${GREEN}● ONLINE${CYAN}                                     ║"
    echo -e "║  Puerto      : ${WHITE}$BHTTP_PORT${CYAN}                                         ║"
    echo -e "║  SSH Backend : ${WHITE}$SSH_HOST:$SSH_PORT${CYAN}                               ║"
    echo -e "║  AutoInicio  : ${GREEN}✔ ACTIVADO${CYAN}                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    pause
}

# ==============================================================
# INICIAR
# ==============================================================

iniciar_bhttp() {

    cargar_config

    if ! servicio_instalado; then

        echo
        echo -e "${RED}✘ BHTTP no está instalado.${RESET}"

        pause

        return 1
    fi

    echo
    echo -e "${GRAY}▸ Iniciando BHTTP...${RESET}"

    systemctl enable "$SERVICE" >/dev/null 2>&1

    if iniciar_y_verificar; then

        echo
        echo -e "${GREEN}${BOLD}✔ BHTTP ONLINE${RESET}"
        echo -e "${WHITE}Puerto:${RESET} ${CYAN}$BHTTP_PORT${RESET}"

    else

        mostrar_error_servicio

    fi

    pause
}

# ==============================================================
# REINICIAR
# ==============================================================

reiniciar_bhttp() {

    cargar_config

    if ! servicio_instalado; then

        echo
        echo -e "${RED}✘ BHTTP no está instalado.${RESET}"

        pause

        return 1
    fi

    echo
    echo -e "${GRAY}▸ Reiniciando BHTTP...${RESET}"

    if iniciar_y_verificar; then

        echo
        echo -e "${GREEN}${BOLD}✔ BHTTP REINICIADO${RESET}"
        echo
        echo -e "${WHITE}Puerto:${RESET} ${CYAN}$BHTTP_PORT${RESET}"

    else

        mostrar_error_servicio

    fi

    pause
}

# ==============================================================
# DETENER
# ==============================================================

detener_bhttp() {

    if ! servicio_instalado; then

        echo
        echo -e "${RED}✘ BHTTP no está instalado.${RESET}"

        pause

        return 1
    fi

    echo
    echo -e "${GRAY}▸ Deteniendo BHTTP...${RESET}"

    systemctl stop "$SERVICE"

    sleep 1

    if ! servicio_online; then

        BHTTP="OFF"

        guardar_config

        echo
        echo -e "${GREEN}${BOLD}✔ BHTTP DETENIDO${RESET}"

    else

        echo
        echo -e "${RED}✘ BHTTP no pudo detenerse.${RESET}"

    fi

    pause
}

# ==============================================================
# CAMBIAR PUERTO
# ==============================================================

cambiar_puerto() {

    cargar_config

    if ! servicio_instalado; then

        echo
        echo -e "${RED}✘ Primero instala BHTTP.${RESET}"

        pause

        return 1
    fi

    echo
    echo -e "${WHITE}Puerto actual:${RESET} ${CYAN}$BHTTP_PORT${RESET}"

    read -rp \
        "$(echo -e "${CYAN}Nuevo puerto: ${RESET}")" NEW_PORT

    if ! valid_port "$NEW_PORT"; then

        echo
        echo -e "${RED}✘ Puerto inválido.${RESET}"

        pause

        return 1
    fi

    if [[ "$NEW_PORT" != "$BHTTP_PORT" ]] &&
       puerto_ocupado "$NEW_PORT"; then

        echo
        echo -e "${RED}✘ El puerto $NEW_PORT ya está ocupado.${RESET}"

        pause

        return 1
    fi

    local OLD_PORT="$BHTTP_PORT"

    echo
    echo -e "${GRAY}▸ Cambiando puerto...${RESET}"

    systemctl stop "$SERVICE"

    BHTTP_PORT="$NEW_PORT"

    BHTTP="ON"

    guardar_config

    if ! crear_servicio; then

        BHTTP_PORT="$OLD_PORT"

        guardar_config

        crear_servicio

        systemctl daemon-reload
        systemctl restart "$SERVICE"

        echo
        echo -e "${RED}✘ No se pudo actualizar el servicio.${RESET}"

        pause

        return 1
    fi

    systemctl daemon-reload

    if iniciar_y_verificar; then

        echo
        echo -e "${GREEN}${BOLD}✔ PUERTO CAMBIADO${RESET}"
        echo
        echo -e "${WHITE}Anterior :${RESET} ${GRAY}$OLD_PORT${RESET}"
        echo -e "${WHITE}Nuevo    :${RESET} ${CYAN}$BHTTP_PORT${RESET}"
        echo -e "${WHITE}Estado   :${RESET} ${GREEN}ONLINE${RESET}"

    else

        echo
        echo -e "${RED}✘ No se pudo iniciar en el puerto $NEW_PORT.${RESET}"

        # Intentar restaurar el puerto anterior.

        BHTTP_PORT="$OLD_PORT"

        guardar_config

        crear_servicio

        systemctl daemon-reload
        systemctl restart "$SERVICE"

        sleep 2

        if servicio_online &&
           puerto_escuchando "$OLD_PORT"; then

            echo
            echo -e "${YELLOW}⚠ Se restauró el puerto anterior: $OLD_PORT${RESET}"

        else

            echo
            echo -e "${RED}✘ No se pudo restaurar el puerto anterior.${RESET}"

        fi

    fi

    pause
}

# ==============================================================
# DIAGNÓSTICO
# ==============================================================

diagnostico() {

    clear

    cargar_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🔎 BHTTP DIAGNÓSTICO                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${WHITE}SERVICIO${RESET}"
    line

    echo -e "  Estado       : $(estado_servicio)"
    echo -e "  Habilitado   : $(

        if servicio_habilitado; then
            echo -e "${GREEN}SÍ${RESET}"
        else
            echo -e "${RED}NO${RESET}"
        fi

    )"

    echo
    echo -e "${WHITE}CONFIGURACIÓN${RESET}"
    line

    echo -e "  Host BHTTP   : ${CYAN}$BHTTP_HOST${RESET}"
    echo -e "  Puerto BHTTP : ${CYAN}$BHTTP_PORT${RESET}"
    echo -e "  Backend SSH  : ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"

    echo
    echo -e "${WHITE}PUERTOS${RESET}"
    line

    if puerto_escuchando "$BHTTP_PORT"; then

        echo -e "  BHTTP        : ${GREEN}✔ 0.0.0.0:$BHTTP_PORT${RESET}"

    else

        echo -e "  BHTTP        : ${RED}✘ $BHTTP_PORT no escucha${RESET}"

    fi

    if puerto_escuchando "$SSH_PORT"; then

        echo -e "  SSH          : ${GREEN}✔ $SSH_PORT escuchando${RESET}"

    else

        echo -e "  SSH          : ${RED}✘ $SSH_PORT no detectado${RESET}"

    fi

    echo
    echo -e "${WHITE}PROCESO${RESET}"
    line

    ps aux |
        grep '[b]http-server.py' ||
        echo -e "${GRAY}No hay proceso BHTTP activo.${RESET}"

    echo
    echo -e "${WHITE}ÚLTIMOS LOGS${RESET}"
    line

    journalctl \
        -u "$SERVICE" \
        -n 12 \
        --no-pager \
        2>/dev/null

    pause
}

# ==============================================================
# LOGS
# ==============================================================

ver_logs() {

    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      📜 BHTTP LOGS                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    journalctl \
        -u "$SERVICE" \
        -n 50 \
        --no-pager \
        -l \
        2>/dev/null

    pause
}

# ==============================================================
# PRUEBA DEL PUERTO
# ==============================================================

probar_bhttp() {

    clear

    cargar_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     🧪 PRUEBA BHTTP                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo

    if servicio_online; then

        echo -e "${WHITE}Servicio :${RESET} ${GREEN}ONLINE${RESET}"

    else

        echo -e "${WHITE}Servicio :${RESET} ${RED}OFFLINE${RESET}"

    fi

    if puerto_escuchando "$BHTTP_PORT"; then

        echo -e "${WHITE}Puerto   :${RESET} ${GREEN}$BHTTP_PORT ESCUCHANDO${RESET}"

    else

        echo -e "${WHITE}Puerto   :${RESET} ${RED}$BHTTP_PORT NO ESCUCHA${RESET}"

    fi

    echo
    echo -e "${GRAY}Listener:${RESET}"

    ss -ltnp 2>/dev/null |
        grep ":$BHTTP_PORT" ||
        echo -e "${GRAY}No se encontró listener.${RESET}"

    pause
}

# ==============================================================
# DESINSTALAR
# ==============================================================

desinstalar_bhttp() {

    clear

    cargar_config

    echo -e "${RED}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🗑️ DESINSTALAR BHTTP                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${YELLOW}Se eliminará:${RESET}"
    echo
    echo -e "  • Servicio bhttp.service"
    echo -e "  • Servidor BHTTP"
    echo -e "  • Configuración BHTTP"
    echo -e "  • Inicio automático"
    echo

    read -rp \
        "$(echo -e "${RED}¿Deseas continuar? [s/N]: ${RESET}")" CONFIRM

    case "${CONFIRM,,}" in

        s|si|sí|y|yes)

            ;;

        *)

            echo
            echo -e "${GRAY}Operación cancelada.${RESET}"

            pause

            return
            ;;

    esac

    echo
    echo -e "${GRAY}▸ Deteniendo BHTTP...${RESET}"

    systemctl stop "$SERVICE" 2>/dev/null || true

    sleep 1

    echo -e "${GRAY}▸ Deshabilitando inicio automático...${RESET}"

    systemctl disable "$SERVICE" 2>/dev/null || true

    echo -e "${GRAY}▸ Eliminando unidad systemd...${RESET}"

    rm -f "$UNIT"

    systemctl daemon-reload

    systemctl reset-failed "$SERVICE" 2>/dev/null || true

    echo -e "${GRAY}▸ Eliminando servidor BHTTP...${RESET}"

    rm -rf "$BHTTP_DIR"

    echo -e "${GRAY}▸ Eliminando configuración...${RESET}"

    rm -f "$CONFIG"

    BHTTP="OFF"

    echo
    echo -e "${GREEN}${BOLD}✔ BHTTP DESINSTALADO CORRECTAMENTE${RESET}"

    echo
    echo -e "${WHITE}Servicio :${RESET} ${GRAY}eliminado${RESET}"
    echo -e "${WHITE}Servidor :${RESET} ${GRAY}eliminado${RESET}"
    echo -e "${WHITE}Config   :${RESET} ${GRAY}eliminada${RESET}"

    pause
}

# ==============================================================
# RESUMEN
# ==============================================================

mostrar_resumen() {

    cargar_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     🌐 BHTTP STATUS                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${WHITE}Servicio :${RESET} $(estado_servicio)"
    echo -e "${WHITE}Puerto   :${RESET} ${CYAN}$BHTTP_PORT${RESET}"
    echo -e "${WHITE}Backend  :${RESET} ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"

    if servicio_habilitado; then

        echo -e "${WHITE}AutoInicio:${RESET} ${GREEN}✔ ACTIVADO${RESET}"

    else

        echo -e "${WHITE}AutoInicio:${RESET} ${RED}✘ DESACTIVADO${RESET}"

    fi

    if puerto_escuchando "$BHTTP_PORT"; then

        echo -e "${WHITE}Listener :${RESET} ${GREEN}0.0.0.0:$BHTTP_PORT${RESET}"

    else

        echo -e "${WHITE}Listener :${RESET} ${RED}NO ESCUCHANDO${RESET}"

    fi
}

# ==============================================================
# MENÚ
# ==============================================================

mostrar_menu() {

    clear

    cargar_config

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║                 🌐 KEVINTECH BHTTP 🌐                      ║"
    echo "║                                                              ║"
    echo "║                    PREMIUM PROTOCOL                         ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${GRAY}  BHTTP • KevinTech Multi Script • v${VERSION}${RESET}"

    echo
    echo -e "${WHITE}  ESTADO DEL SERVICIO${RESET}"

    line

    echo -e "  Servicio : $(estado_servicio)"
    echo -e "  Puerto   : ${CYAN}$BHTTP_PORT${RESET}"
    echo -e "  SSH      : ${CYAN}$SSH_PORT${RESET}"

    echo
    echo -e "${BLUE}${BOLD}  ⚙️ ADMINISTRACIÓN BHTTP${RESET}"

    line

    echo -e "  ${GREEN}${BOLD}[01]${RESET} 🚀 Instalar / Actualizar"
    echo -e "  ${GREEN}${BOLD}[02]${RESET} ▶️  Iniciar BHTTP"
    echo -e "  ${GREEN}${BOLD}[03]${RESET} 🔄 Reiniciar BHTTP"
    echo -e "  ${GREEN}${BOLD}[04]${RESET} ⏹️  Detener BHTTP"
    echo -e "  ${GREEN}${BOLD}[05]${RESET} 🔌 Cambiar puerto"
    echo -e "  ${GREEN}${BOLD}[06]${RESET} 🧪 Probar BHTTP"
    echo -e "  ${GREEN}${BOLD}[07]${RESET} 🔎 Diagnóstico"
    echo -e "  ${GREEN}${BOLD}[08]${RESET} 📜 Ver logs"

    echo
    echo -e "  ${RED}${BOLD}[09]${RESET} 🗑️  Desinstalar BHTTP"

    echo
    line

    echo -e "  ${RED}${BOLD}[00]${RESET} ↩️  Volver"

    echo
    echo -e "${GRAY}  KevinTech Multi Script • Privanox VPN${RESET}"

    echo
}

# ==============================================================
# ARGUMENTOS DIRECTOS
# ==============================================================

case "${1:-}" in

    --install|-i)

        if [[ -n "${2:-}" ]]; then

            BHTTP_PORT="$2"
            BHTTP="ON"

            guardar_config

        fi

        instalar_bhttp

        exit $?
        ;;

    --start)

        iniciar_bhttp

        exit $?
        ;;

    --restart)

        reiniciar_bhttp

        exit $?
        ;;

    --stop)

        detener_bhttp

        exit $?
        ;;

    --port|-p)

        if [[ -n "${2:-}" ]]; then

            BHTTP_PORT="$2"

            BHTTP="ON"

            guardar_config

            crear_servicio

            systemctl daemon-reload

            iniciar_y_verificar

        else

            cambiar_puerto

        fi

        exit $?
        ;;

    --status)

        mostrar_resumen

        exit 0
        ;;

    --probe)

        probar_bhttp

        exit $?
        ;;

    --diag)

        diagnostico

        exit $?
        ;;

    --logs)

        ver_logs

        exit 0
        ;;

    --desinstalar|--uninstall)

        desinstalar_bhttp

        exit $?
        ;;

    --help|-h)

        echo
        echo "KevinTech BHTTP v${VERSION}"
        echo
        echo "Uso:"
        echo
        echo "  bash bhttp.sh"
        echo "  bash bhttp.sh --install 970"
        echo "  bash bhttp.sh --start"
        echo "  bash bhttp.sh --restart"
        echo "  bash bhttp.sh --stop"
        echo "  bash bhttp.sh --port 970"
        echo "  bash bhttp.sh --status"
        echo "  bash bhttp.sh --probe"
        echo "  bash bhttp.sh --diag"
        echo "  bash bhttp.sh --logs"
        echo "  bash bhttp.sh --desinstalar"
        echo

        exit 0
        ;;

esac

# ==============================================================
# CTRL+C
# ==============================================================

trap '

    echo
    echo -e "${YELLOW}⚠️  Regresando...${RESET}"
    sleep 1
    clear
    exit 0

' INT TERM

# ==============================================================
# BUCLE PRINCIPAL
# ==============================================================

while true; do

    mostrar_menu

    read -rp \
        "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" OP

    case "$OP" in

        1|01)

            instalar_bhttp

            ;;

        2|02)

            iniciar_bhttp

            ;;

        3|03)

            reiniciar_bhttp

            ;;

        4|04)

            detener_bhttp

            ;;

        5|05)

            cambiar_puerto

            ;;

        6|06)

            probar_bhttp

            ;;

        7|07)

            diagnostico

            ;;

        8|08)

            ver_logs

            ;;

        9|09)

            desinstalar_bhttp

            ;;

        0|00)

            clear

            exit 0

            ;;

        "")

            ;;

        *)

            echo
            echo -e "${RED}${BOLD}✘ Opción inválida.${RESET}"

            sleep 1

            ;;

    esac

done