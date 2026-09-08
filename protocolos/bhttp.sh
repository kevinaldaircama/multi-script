#!/usr/bin/env bash
# ==============================================================
#                 🌐 KEVINTECH BHTTP 🌐
#                    PROTOCOLO COMPATIBLE
# ==============================================================
# Integrado a partir de los archivos Bhttp-main:
#   - bhttp-install.sh  -> servidor BHTTP
#   - bhttp-probe.sh    -> prueba real del protocolo
#
# Puertos por defecto de este módulo:
#   BHTTP : 8088
#   SSH   : 22
# ==============================================================
set -uo pipefail

BASE="/etc/kevintech"
DIR="/usr/local/lib/bhttp"
SERVER_PY="$DIR/bhttp-server.py"
PROBE="$DIR/bhttp-probe.sh"
UNIT="/etc/systemd/system/bhttp.service"
SERVICE="bhttp"
CONFIG="$BASE/bhttp.conf"
BHTTP_HOST="0.0.0.0"
BHTTP_PORT="8088"
SSH_HOST="127.0.0.1"
SSH_PORT="22"
VERSION="4.0"

RESET="\e[0m"; BOLD="\e[1m"; CYAN="\e[1;96m"; BLUE="\e[1;94m"
GREEN="\e[1;92m"; YELLOW="\e[1;93m"; MAGENTA="\e[1;95m"; RED="\e[1;91m"
WHITE="\e[1;97m"; GRAY="\e[1;90m"

[[ $EUID -eq 0 ]] || { echo -e "${RED}${BOLD}✘ Ejecuta este módulo como root.${RESET}"; exit 1; }
mkdir -p "$BASE" "$DIR"
line(){ echo -e "${GRAY}──────────────────────────────────────────────────────────────${RESET}"; }
pause(){ echo; read -rp "$(echo -e "${GRAY}Presiona ENTER para continuar...${RESET}")"; }
ok(){ echo -e "${GREEN}✔ $*${RESET}"; }
err(){ echo -e "${RED}✘ $*${RESET}"; }
info(){ echo -e "${CYAN}➜ $*${RESET}"; }
warn(){ echo -e "${YELLOW}⚠ $*${RESET}"; }

estado(){ systemctl is-active --quiet "$SERVICE" 2>/dev/null && echo -e "${GREEN}● ONLINE${RESET}" || echo -e "${RED}● OFFLINE${RESET}"; }
escucha(){ ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -qE ":${1}$"; }
ssh_ok(){ ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -qE ":${SSH_PORT}$"; }

instalar_dependencias(){
  local miss=()
  command -v python3 >/dev/null 2>&1 || miss+=(python3)
  command -v openssl >/dev/null 2>&1 || miss+=(openssl)
  command -v xxd >/dev/null 2>&1 || miss+=(xxd)
  command -v sha256sum >/dev/null 2>&1 || miss+=(coreutils)
  command -v ss >/dev/null 2>&1 || miss+=(iproute2)
  ((${#miss[@]})) || return 0
  info "Instalando dependencias: ${miss[*]}"
  apt-get update -qq >/dev/null 2>&1 || return 1
  apt-get install -y python3 openssl xxd coreutils iproute2 >/dev/null 2>&1 || return 1
}

crear_config(){
  cat > "$CONFIG" <<EOF
BHTTP_HOST=$BHTTP_HOST
BHTTP_PORT=$BHTTP_PORT
SSH_HOST=$SSH_HOST
SSH_PORT=$SSH_PORT
BHTTP=ON
EOF
  chmod 600 "$CONFIG"
}

instalar_servidor(){
  cat > "$SERVER_PY" <<'PYEOF'
#!/usr/bin/env python3
# Servidor BHTTP autonomo para DTunnel (version asyncio).
# Mismo protocolo binario que la app (extraido de classes.dex), pero con un event
# loop en vez de un hilo por conexion: aguanta las 48+ conexiones concurrentes del
# cliente (32 download + 16 upload) sin saturar la CPU de una VPS pequena.
#
# Trama peticion : mode(1) sessionId(16) seq(8 BE) len(4 BE) + payload enmascarado
# Trama respuesta: status(1) len(4 BE) + payload enmascarado
# Mascara        : XOR con SHA256(sessionId||mode||seq||dir||contador), dir 0=req 1=resp
# Modos          : 0=probe 1=subida 2=bajada(probe calib) 3=lote(download real) 4=ack
import argparse, asyncio, hashlib, struct, sys

MAGIC = b"BHP1"
LONGPOLL = 2.0   # espera max de un batch vacio a que el backend produzca datos

def log(msg):
    sys.stderr.write("[bhttp] %s\n" % msg); sys.stderr.flush()

def keystream(sess, mode, seq, d, n):
    base = hashlib.sha256(sess + bytes([mode]) + seq.to_bytes(8, "big") + bytes([d]))
    out = bytearray(); c = 0
    while len(out) < n:
        h = base.copy(); h.update(c.to_bytes(4, "big")); out += h.digest(); c += 1
    return bytes(out[:n])

def mask(data, sess, mode, seq, d):
    return bytes(a ^ b for a, b in zip(data, keystream(sess, mode, seq, d, len(data))))

def probe_reply(mode, size):
    n = size if (mode == 2 and size >= 10) else 10
    out = bytearray(MAGIC + bytes([1, mode]) + size.to_bytes(4, "big"))
    for i in range(10, n):
        out.append((i * 31) & 255)
    return bytes(out)


class Session:
    """Un tunel logico: empareja el flujo BHTTP con la conexion al backend (sshd)."""
    def __init__(self, sess, backend):
        self.sess = sess
        self.backend = backend
        self.cond = asyncio.Condition()
        self.up_next = 0
        self.up_pending = {}
        self.down_raw = bytearray()
        self.down_chunks = {}
        self.down_assign = 0
        self.eof = False
        self.closed = False
        self.br = None      # backend reader
        self.bw = None      # backend writer

    async def connect(self):
        host, port = self.backend
        self.br, self.bw = await asyncio.open_connection(host, port)
        log("sesion %s: conectada al backend %s:%d" % (self.sess.hex()[:8], host, port))
        asyncio.create_task(self._reader())

    async def _reader(self):
        total = 0
        try:
            while True:
                data = await self.br.read(65536)
                if not data:
                    break
                total += len(data)
                async with self.cond:
                    self.down_raw += data
                    self.cond.notify_all()
        except Exception as e:
            log("sesion %s: error leyendo del backend: %s" % (self.sess.hex()[:8], e))
        finally:
            log("sesion %s: el backend cerro (recibidos %d B en bajada)"
                % (self.sess.hex()[:8], total))
            async with self.cond:
                self.eof = True
                self.cond.notify_all()

    async def upload(self, seq, data):
        async with self.cond:
            if data:
                self.up_pending[seq] = data
            while self.up_next in self.up_pending:
                chunk = self.up_pending.pop(self.up_next)
                try:
                    self.bw.write(chunk)
                    await self.bw.drain()
                except Exception:
                    self.closed = True
                self.up_next += 1

    async def download(self, seq, maxlen, deadline):
        # ORDEN ESTRICTO: cada slot se sirve a su turno (down_assign) y quien pide
        # un slot futuro espera; asi down_assign avanza al ritmo del cliente y un
        # dato tras idle no cae en un slot ya pasado. 'deadline' (compartido por el
        # batch) da por vacios los slots sin datos para no colgar.
        if maxlen <= 0:
            maxlen = 1399
        loop = asyncio.get_running_loop()
        async with self.cond:
            while True:
                if seq < self.down_assign:
                    return self.down_chunks.get(seq, b"")
                if seq == self.down_assign:
                    if self.down_raw:
                        take = bytes(self.down_raw[:maxlen]); del self.down_raw[:maxlen]
                        self.down_chunks[self.down_assign] = take
                        self.down_assign += 1
                        self.cond.notify_all()
                        return take
                    if self.eof:
                        self.down_assign += 1
                        self.cond.notify_all()
                        return b""
                if not self.eof and loop.time() < deadline:
                    try:
                        await asyncio.wait_for(self.cond.wait(),
                                               timeout=max(0.01, deadline - loop.time()))
                    except asyncio.TimeoutError:
                        pass
                    continue
                while self.down_assign <= seq:
                    self.down_assign += 1
                self.cond.notify_all()
                return b""

    async def ack(self, seq):
        async with self.cond:
            for k in [k for k in self.down_chunks if k <= seq]:
                del self.down_chunks[k]

    async def close(self):
        async with self.cond:
            self.closed = True
            self.cond.notify_all()
        try:
            self.bw.close()
        except Exception:
            pass


class Server:
    def __init__(self, host, port, backend):
        self.host, self.port, self.backend = host, port, backend
        self.sessions = {}
        self.slock = asyncio.Lock()

    async def get_session(self, sess):
        async with self.slock:
            s = self.sessions.get(sess)
            if s is None or s.closed:
                for old_sid, old in list(self.sessions.items()):
                    if old_sid != sess:
                        await old.close()
                        del self.sessions[old_sid]
                s = Session(sess, self.backend)
                await s.connect()
                self.sessions[sess] = s
                log("sesion %s: registrada (sesiones vivas: %d)"
                    % (sess.hex()[:8], len(self.sessions)))
            return s

    async def handle(self, reader, writer):
        try:
            while True:
                hdr = await reader.readexactly(29)
                mode = hdr[0]
                sess = hdr[1:17]
                seq = int.from_bytes(hdr[17:25], "big")
                ln = int.from_bytes(hdr[25:29], "big")
                payload = b""
                if ln and mode in (0, 1, 2, 3):
                    raw = await reader.readexactly(ln)
                    payload = mask(raw, sess, mode, seq, 0)

                if payload[:4] == MAGIC:  # probe (calibracion / handshake)
                    size = int.from_bytes(payload[6:10], "big") if len(payload) >= 10 else 0
                    pmode = payload[5] if len(payload) >= 6 else mode
                    body = mask(probe_reply(pmode, size), sess, mode, seq, 1)
                    writer.write(bytes([0]) + len(body).to_bytes(4, "big") + body)
                    await writer.drain()
                    continue

                s = await self.get_session(sess)
                if mode == 1:                       # subida (len 0 = registro)
                    await s.upload(seq, payload)
                    writer.write(bytes([0]) + (0).to_bytes(4, "big"))
                    await writer.drain()
                elif mode == 2:                     # bajada simple (raro)
                    chunk = await s.download(seq, ln if ln > 0 else 1399,
                                             asyncio.get_running_loop().time() + LONGPOLL)
                    self._send_data(writer, sess, mode, seq, chunk)
                    await writer.drain()
                elif mode == 3:                     # lote de bajadas (download real)
                    if len(payload) >= 6:
                        chunk_size = int.from_bytes(payload[0:4], "big"); count = payload[5]
                    else:
                        chunk_size, count = 1399, 1
                    if chunk_size <= 0: chunk_size = 1399
                    if count <= 0: count = 1
                    deadline = asyncio.get_running_loop().time() + LONGPOLL
                    for i in range(count):
                        chunk = await s.download(seq + i, chunk_size, deadline)
                        self._send_data(writer, sess, mode, seq + i, chunk)
                    await writer.drain()
                elif mode == 4:                     # ack
                    await s.ack(seq)
                    writer.write(bytes([0]) + (0).to_bytes(4, "big"))
                    await writer.drain()
                else:
                    return
        except (asyncio.IncompleteReadError, ConnectionError, OSError):
            pass
        except Exception as e:
            log("handle: excepcion inesperada: %r" % e)
        finally:
            try:
                writer.close()
            except Exception:
                pass

    def _send_data(self, writer, sess, mode, seq, data):
        # respuesta de bajada (status 2): [4B longitud EN CLARO][datos enmascarados]
        real = len(data)
        masked = mask(data, sess, mode, seq, 1) if data else b""
        body = real.to_bytes(4, "big") + masked
        writer.write(bytes([2]) + len(body).to_bytes(4, "big") + body)

    async def serve(self):
        srv = await asyncio.start_server(self.handle, self.host, self.port, backlog=512)
        print("BHTTP escuchando en %s:%d -> backend %s:%d"
              % (self.host, self.port, self.backend[0], self.backend[1]), flush=True)
        async with srv:
            await srv.serve_forever()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--backend-host", default="127.0.0.1")
    ap.add_argument("--backend-port", type=int, default=22)
    a = ap.parse_args()
    asyncio.run(Server(a.host, a.port, (a.backend_host, a.backend_port)).serve())


if __name__ == "__main__":
    main()
PYEOF
  chmod 755 "$SERVER_PY"
  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$SERVER_PY" || return 1
}

instalar_probe(){
  cat > "$PROBE" <<'PROBEOF'
#!/usr/bin/env bash
# bhttp-probe.sh - cliente minimo del protocolo BHTTP de DTunnel.
#
# Hace, a mano, lo mismo que la app hace sola al conectar:
#   1. TCP (o TLS, para los puertos con SSL)
#   2. Handshake / sondeo BHP1            (mode 0)
#   3. Path probe: tamano maximo de trama (mode 1, busqueda binaria)
#   4. Abrir sesion                       (mode 1, seq 0, len 0, sin payload)
#   5. Mover datos por el tunel           (mode 1 = subida, mode 2 = bajada, mode 4 = ack)
#
# Contra un DTProto Server (el del instalador oficial), que escucha en
# 0.0.0.0:80 sin SSL y 0.0.0.0:443 con SSL, si no le pasas puerto prueba los
# dos solo, poniendo TLS donde hace falta.
#
# ---------------------------------------------------------------------------
# Protocolo (extraido de classes.dex):
#
#   PETICION  = cabecera 29 bytes + payload enmascarado
#      [0]      mode        0=probe/echo 1=subida 2=descarga 3=lote 4=ack
#      [1..16]  sessionId   16 bytes (UUID de la sesion)
#      [17..24] sequence    big-endian 64 bits
#      [25..28] length      big-endian 32 bits
#                           en mode 2 NO es la longitud del payload (no hay):
#                           es el tamano de chunk que se pide de vuelta
#
#   RESPUESTA = cabecera 5 bytes + payload enmascarado
#      [0]      status      0 = OK
#                           2 = OK con relleno: el cuerpo empieza por 4 bytes
#                               en claro con la longitud real, luego el payload
#                           otro = el cuerpo es un error UTF-8 SIN enmascarar
#      [1..4]   length      big-endian 32 bits
#
#   MASCARA (no es cifrado: el sessionId viaja en claro, es anti-DPI)
#      keystream = SHA256( sessionId(16) || mode(1) || seq(8) || dir(1) || contador(4) )
#      dir = 0 en peticiones, 1 en respuestas; contador sube cada 32 bytes
#      en_el_cable = payload XOR keystream
#
#   PAYLOAD DE SONDEO
#      "BHP1"(4) || version=1(1) || mode(1) || size(4 BE) || relleno[i]=(byte)(i*31)
#
#   OJO: el host es el serverHost de la config (el del SSH), NO proxyHost:
#        en modo bhttp la app ignora proxyHost/proxyPort.
# ---------------------------------------------------------------------------
#
# Uso:   ./bhttp-probe.sh                  <- MODO AUTOMATICO, en la propia VPS:
#                                            busca los puertos del proto-server,
#                                            detecta solo si llevan TLS y se
#                                            prueba a si mismo. No pide nada.
#        ./bhttp-probe.sh <host> [puerto] [opciones]   <- desde fuera (PC/movil)
#
#        opciones:
#          sin puerto     prueba 80 (plano) y 443 (TLS) y se queda en el que ande
#          --tls          fuerza TLS
#          --no-tls       fuerza texto plano
#          --sni <nombre> nombre SNI para el TLS (por defecto, el host)
#          -v             imprime cada trama en hexadecimal
#          --fast         salta el path probe (paso 3), va mas rapido
#          --solo-sondeo  se queda en el paso 3, no abre sesion ni manda datos
#          -d <texto>     manda ese texto en vez del banner SSH
#          -t <segundos>  timeout de lectura (por defecto 10)
#
# Requiere: bash, openssl, xxd, sha256sum (todo eso ya viene en Git Bash / Termux).

set -uo pipefail

HOST=""; PORT=""; SNI=""; VERBOSE=0; LADDER=1; DATAPHASE=1; TMO=10; TLSMODE="auto"
SEND_TEXT=$'SSH-2.0-OpenSSH_8.9\r\n'

while [ $# -gt 0 ]; do
  case "$1" in
    -v)            VERBOSE=1 ;;
    --tls)         TLSMODE="on" ;;
    --no-tls)      TLSMODE="off" ;;
    --sni)         shift; SNI="$1" ;;
    --fast)        LADDER=0 ;;
    --solo-sondeo) DATAPHASE=0 ;;
    -d)            shift; SEND_TEXT="$1" ;;
    -t)            shift; TMO="$1" ;;
    -h|--help)     sed -n '2,56p' "$0"; exit 0 ;;
    *)             if [ -z "$HOST" ]; then HOST="$1"; elif [ -z "$PORT" ]; then PORT="$1"; fi ;;
  esac
  shift
done

# sin host = modo automatico contra el servidor local
AUTO=0
if [ -z "$HOST" ]; then AUTO=1; HOST="127.0.0.1"; fi
[ -z "$SNI" ] && SNI="$HOST"
SHOWHOST=""

for req in openssl xxd sha256sum; do
  command -v "$req" >/dev/null 2>&1 || { echo "falta '$req' en el PATH" >&2; exit 2; }
done

MAGIC="42485031"            # "BHP1"
DOWNCHUNK=1350              # maxDownloadChunkSize por defecto de la app (Lqk.b())

# Escalera de tamanos que prueba la app (Lcl.<clinit>). Cortada en 4096:
# por encima, generar el keystream en bash cuesta demasiadas llamadas a sha256sum.
# ponytail: escalera recortada; subir el tope si hace falta medir por encima de 4096.
LADDER_SIZES=(512 1024 1200 1280 1320 1350 1360 1370 1380 1388 1390 1400 1402 1410 1450 1600 2048 3205 4096)

SESS=""; USETLS=0; TLS_PID=""

# ---------- utilidades hex ----------

emit()   { printf '%s' "$1" | xxd -r -p; }            # hex -> bytes por stdout
wire()   { { printf '%s' "$1" | xxd -r -p >&4; } 2>/dev/null; }  # hex -> bytes al socket
tohex()  { printf '%s' "$1" | xxd -p | tr -d '\n'; }  # texto -> hex
totext() { emit "$1" | tr -c '\11\12\15\40-\176' '.'; }

# lee N bytes del socket y los devuelve en hex; vacio si timeout/EOF
recv() { { timeout "$TMO" dd bs=1 count="$1" <&3 | xxd -p | tr -d '\n'; } 2>/dev/null; }

# keystream(mode, seq, dir, nbytes) -> hex
keystream() {
  local mode="$1" seq="$2" dir="$3" n="$4" c=0 nonce out=""
  while [ ${#out} -lt $((n * 2)) ]; do
    nonce="$(printf '%s%02x%016x%02x%08x' "$SESS" "$mode" "$seq" "$dir" "$c")"
    out+="$(emit "$nonce" | sha256sum | cut -d' ' -f1)"
    c=$((c + 1))
  done
  printf '%s' "${out:0:$((n * 2))}"
}

# xorhex(a_hex, b_hex) -> hex
xorhex() {
  local a="$1" b="$2" i byte
  local -a acc=()
  for ((i = 0; i < ${#a}; i += 2)); do
    printf -v byte '%02x' $(( 0x${a:i:2} ^ 0x${b:i:2} ))
    acc+=("$byte")
  done
  local IFS=''
  printf '%s' "${acc[*]}"
}

# probe_payload(mode, size) -> hex del payload de sondeo
probe_payload() {
  local mode="$1" size="$2" len=10 i byte
  local -a acc=()
  if [ "$mode" = 1 ] && [ "$size" -ge 10 ]; then len="$size"; fi
  printf -v byte '%s01%02x%08x' "$MAGIC" "$mode" "$size"
  acc+=("$byte")
  for ((i = 10; i < len; i++)); do
    printf -v byte '%02x' $(( (i * 31) & 255 ))
    acc+=("$byte")
  done
  local IFS=''
  printf '%s' "${acc[*]}"
}

cut64() { if [ ${#1} -gt 64 ]; then printf '%s...' "${1:0:64}"; else printf '%s' "$1"; fi; }
# el log va a stderr: recv_frame se llama dentro de $(...) y no debe contaminar el valor
log()   { if [ "$VERBOSE" = 1 ]; then printf '    %s\n' "$*" >&2; fi; return 0; }

# ---------- transporte: fd 3 = lectura, fd 4 = escritura ----------

open_conn() {
  if [ "$USETLS" = 1 ]; then
    local tr tw
    coproc TLSC { openssl s_client -quiet -connect "$HOST:$PORT" -servername "$SNI" 2>/dev/null; }
    [ -z "${TLSC_PID:-}" ] && return 1
    TLS_PID="$TLSC_PID"
    tr="${TLSC[0]}"; tw="${TLSC[1]}"
    exec 3<&"$tr" 4>&"$tw" || return 1
    exec {tr}<&- {tw}>&-              # sueltas las copias, si no el coproc no cierra
    return 0
  fi
  { exec 3<>"/dev/tcp/$HOST/$PORT"; } 2>/dev/null || return 1
  exec 4>&3
  return 0
}

close_conn() {
  { exec 3<&-; exec 4>&-; } 2>/dev/null
  if [ -n "$TLS_PID" ]; then
    kill "$TLS_PID" 2>/dev/null
    wait "$TLS_PID" 2>/dev/null
    TLS_PID=""
  fi
  return 0
}

# ---------- protocolo ----------

# send_frame(mode, seq, payload_hex, len_field)
send_frame() {
  local mode="$1" seq="$2" payload="$3" lenf="$4" hdr masked ks
  printf -v hdr '%02x%s%016x%08x' "$mode" "$SESS" "$seq" "$lenf"
  log "-> cabecera 29B: $hdr"
  log "   mode=$mode session=$SESS seq=$seq length=$lenf"
  wire "$hdr"
  if [ -n "$payload" ]; then
    ks="$(keystream "$mode" "$seq" 0 $(( ${#payload} / 2 )))"
    masked="$(xorhex "$payload" "$ks")"
    log "-> payload $(( ${#payload} / 2 ))B en claro: $(cut64 "$payload")"
    log "-> payload enmascarado   : $(cut64 "$masked")"
    wire "$masked"
  fi
}

# recv_frame(mode, seq) -> imprime "status payload_hex"; 1 si falla
recv_frame() {
  local mode="$1" seq="$2" hdr status len body real plain ks
  hdr="$(recv 5)"
  if [ ${#hdr} -ne 10 ]; then return 1; fi
  log "<- cabecera 5B: $hdr"
  status=$(( 0x${hdr:0:2} ))
  len=$(( 0x${hdr:2:8} ))
  log "   status=$status length=$len"
  plain=""
  if [ "$len" -gt 0 ]; then
    body="$(recv "$len")"
    if [ ${#body} -ne $((len * 2)) ]; then return 1; fi
    if [ "$status" != 0 ] && [ "$status" != 2 ]; then
      # los cuerpos de error van en claro, sin mascara (Lbw.L() los lee tal cual)
      plain="$body"
      log "<- error en claro: $(totext "$plain")"
    else
      # status 2 = respuesta rellenada: 4 bytes en claro con la longitud real
      # delante y relleno detras. Se quita antes de desenmascarar (Lbw.y()).
      if [ "$status" = 2 ] && [ "$len" -ge 4 ]; then
        real=$(( 0x${body:0:8} ))
        if [ "$real" -gt 0 ] && [ "$real" -le $((len - 4)) ]; then
          body="${body:8:$((real * 2))}"
        else
          body=""
        fi
      fi
      if [ -n "$body" ]; then
        ks="$(keystream "$mode" "$seq" 1 $(( ${#body} / 2 )))"
        plain="$(xorhex "$body" "$ks")"
        log "<- payload en claro: $(cut64 "$plain")"
      fi
    fi
  fi
  printf '%s %s' "$status" "$plain"
}

# request(mode, seq, payload_hex, len_field) -> "status plain_hex"; 1 si falla
request() {
  local res
  open_conn || return 1
  send_frame "$1" "$2" "$3" "$4"
  res="$(recv_frame "$1" "$2")" || { close_conn; return 1; }
  close_conn
  printf '%s' "$res"
}

# check_echo(mode, size_esperado, plain_hex) -> 0 si el eco BHP1 es valido
check_echo() {
  local mode="$1" size="$2" p="$3" want
  if [ ${#p} -lt 20 ]; then return 1; fi
  if [ "${p:0:8}" != "$MAGIC" ]; then return 1; fi
  if [ "${p:8:2}" != "01" ]; then return 1; fi
  printf -v want '%02x' "$mode"
  if [ "${p:10:2}" != "$want" ]; then return 1; fi
  printf -v want '%08x' "$size"
  if [ "${p:12:8}" != "$want" ]; then return 1; fi
  return 0
}

# probe_wire(wire_size) -> 0 si una trama de subida de ese tamano pasa
probe_wire() {
  local wire="$1" plen payload res status plain
  plen=$(( wire - 29 )); [ "$plen" -lt 10 ] && plen=10
  payload="$(probe_payload 1 "$plen")"
  res="$(request 1 "$wire" "$payload" $(( ${#payload} / 2 )))" || return 1
  status="${res%% *}"; plain="${res#* }"
  if [ "$status" != 0 ] && [ "$status" != 2 ]; then return 1; fi
  check_echo 1 "$plen" "$plain"
}

# ---------- descubrimiento (modo automatico) ----------

# try_handshake -> 0 si en PORT/USETLS hay un servidor BHTTP. No imprime nada.
try_handshake() {
  local PAY RES ST PL
  SESS="$(openssl rand -hex 16)"
  PAY="$(probe_payload 0 0)"
  RES="$(request 0 0 "$PAY" $(( ${#PAY} / 2 )))" || return 1
  ST="${RES%% *}"; PL="${RES#* }"
  if [ "$ST" != 0 ] && [ "$ST" != 2 ]; then return 1; fi
  check_echo 0 0 "$PL"
}

# scan_port(puerto) -> imprime "plano" o "tls" si hay BHTTP; nada si no
scan_port() {
  PORT="$1"
  if [ "$TLSMODE" != "on" ]; then
    USETLS=0; if try_handshake; then printf 'plano'; return 0; fi
  fi
  if [ "$TLSMODE" != "off" ]; then
    USETLS=1; if try_handshake; then printf 'tls'; return 0; fi
  fi
  return 1
}

# puertos donde puede haber un proto-server, mirando el sistema
discover_ports() {
  local out=""
  # 1. puertos que escucha el propio proto-server
  if command -v ss >/dev/null 2>&1; then
    out="$(ss -tlnp 2>/dev/null | grep -i 'proto-server' \
           | grep -oE ':[0-9]+ ' | tr -d ': ')"
  fi
  if [ -z "$out" ] && command -v netstat >/dev/null 2>&1; then
    out="$(netstat -tlnp 2>/dev/null | grep -i 'proto-server' \
           | grep -oE ':[0-9]+ ' | tr -d ': ')"
  fi
  # 2. puertos que aparezcan en la config del servidor
  if [ -r /etc/config.json ]; then
    out="$out
$(grep -oE '"port"[[:space:]]*:[[:space:]]*[0-9]+' /etc/config.json \
      | grep -oE '[0-9]+')"
  fi
  # 3. los del instalador oficial, por si acaso
  out="$out
80
443"
  printf '%s\n' "$out" | grep -E '^[0-9]+$' | sort -n -u
}

# ip publica, para decirle al usuario que poner en la app
public_ip() {
  local ip=""
  if command -v curl >/dev/null 2>&1; then
    ip="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null)"
  fi
  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  printf '%s' "$ip"
}

# ---------- pasos ----------

# 0 = todo bien, 1 = fallo definitivo, 2 = no habla BHTTP (se puede reintentar
# con el otro transporte), 3 = ni siquiera abre el TCP
run_target() {
  local TOTAL=5 RES ST PL lo hi mid w BEST GOT TXT SEND_HEX NSEND intento
  [ "$DATAPHASE" = 0 ] && TOTAL=3
  SESS="$(openssl rand -hex 16)"

  local via="TCP plano"
  [ "$USETLS" = 1 ] && via="TLS (sni=$SNI)"
  echo "== $HOST:$PORT via $via"
  echo "   sessionId = $SESS"

  # --- 1: conexion ---
  printf '[1/%d] Conexion .......... ' "$TOTAL"
  if ! open_conn; then
    echo "FALLO"
    [ "$USETLS" = 1 ] && echo "      No se pudo abrir TLS contra $HOST:$PORT." \
                      || echo "      No conecta a $HOST:$PORT (cerrado, DNS, o filtrado)."
    close_conn
    return 3
  fi
  close_conn
  echo "OK"

  # --- 2: handshake ---
  printf '[2/%d] Handshake BHP1 .... ' "$TOTAL"
  local PAY; PAY="$(probe_payload 0 0)"
  if RES="$(request 0 0 "$PAY" $(( ${#PAY} / 2 )))"; then
    ST="${RES%% *}"; PL="${RES#* }"
  else
    ST=""; PL=""
  fi

  if [ -z "$ST" ]; then
    echo "FALLO"
    if [ "$USETLS" = 1 ]; then
      echo "      TLS abre pero no responde BHTTP: puerto equivocado, SNI que no"
      echo "      le gusta, o ese puerto en realidad no lleva SSL."
    else
      echo "      Acepta TCP pero no responde: puede que ese puerto lleve TLS."
    fi
    return 2
  elif [ "$ST" != 0 ] && [ "$ST" != 2 ]; then
    echo "FALLO (status=$ST)"
    echo "      El servidor contesta pero rechaza: \"$(totext "$PL")\""
    return 1
  elif ! check_echo 0 0 "$PL"; then
    echo "FALLO"
    echo "      Responde, pero el eco no es un BHP1 valido: status=$ST payload=$PL"
    return 2
  fi
  echo "OK"
  echo "      es un servidor BHTTP con path probe v1"

  # --- 3: path probe ---
  printf '[3/%d] Path probe ........ ' "$TOTAL"
  BEST=0
  if [ "$LADDER" = 0 ]; then
    echo "(saltado con --fast)"
  else
    echo
    lo=0; hi=$(( ${#LADDER_SIZES[@]} - 1 ))
    while [ "$lo" -le "$hi" ]; do
      mid=$(( (lo + hi) / 2 ))
      w="${LADDER_SIZES[$mid]}"
      printf '      trama de %6d B ... ' "$w"
      if probe_wire "$w"; then
        echo "pasa"; BEST="$w"; lo=$(( mid + 1 ))
      else
        echo "bloqueada"; hi=$(( mid - 1 ))
      fi
    done
    if [ "$BEST" -gt 0 ]; then
      echo "      subida: trama max $BEST B -> $(( BEST - 29 )) B utiles por chunk"
      echo "      (la app resta ademas un margen de ~1/16 y baja un escalon)"
    else
      echo "      ningun tamano paso: el servidor no acepta sondeos de subida"
    fi
  fi

  if [ "$DATAPHASE" = 0 ]; then
    echo
    echo "Listo (--solo-sondeo)."
    return 0
  fi

  # --- 4: abrir sesion (igual que Lpk.a(): mode 1, seq 0, len 0, sin payload) ---
  printf '[4/%d] Abrir sesion ...... ' "$TOTAL"
  if RES="$(request 1 0 "" 0)"; then
    ST="${RES%% *}"; PL="${RES#* }"
  else
    ST=""; PL=""
  fi
  if [ -z "$ST" ]; then
    echo "FALLO (sin respuesta)"
    return 1
  elif [ "$ST" != 0 ] && [ "$ST" != 2 ]; then
    echo "FALLO (status=$ST)"
    echo "      \"$(totext "$PL")\""
    return 1
  fi
  echo "OK"

  # --- 5: datos ---
  echo "[5/$TOTAL] Datos ............."
  SEND_HEX="$(tohex "$SEND_TEXT")"
  NSEND=$(( ${#SEND_HEX} / 2 ))

  printf '      -> mode 1 seq 0   %4d B ... ' "$NSEND"
  if RES="$(request 1 0 "$SEND_HEX" "$NSEND")"; then
    ST="${RES%% *}"; PL="${RES#* }"
  else
    ST=""
  fi
  if [ -z "$ST" ]; then
    echo "sin respuesta"
    echo "      La subida no fue aceptada; el tunel no llega al backend."
    return 1
  elif [ "$ST" != 0 ] && [ "$ST" != 2 ]; then
    echo "rechazada (status=$ST)"
    echo "      \"$(totext "$PL")\""
    return 1
  fi
  echo "aceptada"

  GOT=""
  for intento in 1 2 3; do
    printf '      <- mode 2 seq 0        ... '
    if RES="$(request 2 0 "" "$DOWNCHUNK")"; then
      ST="${RES%% *}"; PL="${RES#* }"
    else
      ST=""; PL=""
    fi
    if [ -z "$ST" ]; then
      echo "sin respuesta"; break
    elif [ "$ST" != 0 ] && [ "$ST" != 2 ]; then
      echo "status=$ST -> \"$(totext "$PL")\""; break
    elif [ -n "$PL" ]; then
      GOT="$PL"; echo "$(( ${#PL} / 2 )) B recibidos"; break
    fi
    echo "vacio, reintento $intento/3"
    sleep 1
  done

  echo
  if [ -n "$GOT" ]; then
    request 4 0 "" 0 >/dev/null 2>&1        # ack, como el hilo BhttpDownload-Ack
    TXT="$(totext "$GOT")"
    echo "      primeros bytes: $(printf '%s' "$TXT" | head -c 120)"
    echo "      hex           : $(cut64 "$GOT")"
    echo
    case "$TXT" in
      SSH-2.0*|SSH-1*)
        echo "  TUNEL OK: mueve bytes en ambos sentidos y detras hay un SSH." ;;
      *)
        echo "  TUNEL OK: mueve bytes en ambos sentidos."
        echo "            Lo que responde no parece un banner SSH; mira el texto de arriba." ;;
    esac
    echo
    echo "  Para la app:  host ${SHOWHOST:-$HOST}   puerto $PORT   protocolo bhttp"
    [ "$USETLS" = 1 ] && echo "                con TLS activado y SNI = $SNI"
    return 0
  fi

  echo "  El servidor BHTTP responde, pero el tunel no devolvio datos."
  echo "  La sesion se abre y acepta la subida, pero la bajada viene vacia."
  echo "  Los pasos 1-4 estan bien: el problema no es la conexion, es que el"
  echo "  backend de detras (SSH o el propio proto-server) no arranca la sesion."
  return 1
}

# ---------- main ----------

# ===== modo automatico: en la propia VPS, sin argumentos =====
if [ "$AUTO" = 1 ]; then
  echo "BHTTP - modo automatico (servidor local)"
  echo

  if [ -r /etc/config.json ]; then
    echo "  config del servidor : /etc/config.json"
  else
    echo "  config del servidor : no encontrada (/etc/config.json)"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    est="$(systemctl is-active proto-server 2>/dev/null)"
    echo "  proto-server.service: ${est:-desconocido}"
  fi

  CAND="$(discover_ports)"
  echo "  puertos a probar    : $(printf '%s' "$CAND" | tr '\n' ' ')"
  echo
  echo "Buscando servidores BHTTP..."

  declare -a OKPORT=() OKVIA=()
  for p in $CAND; do
    printf '  puerto %-6s ... ' "$p"
    if via="$(scan_port "$p")"; then
      echo "BHTTP OK ($via)"
      OKPORT+=("$p"); OKVIA+=("$via")
    else
      echo "nada"
    fi
  done
  echo

  if [ "${#OKPORT[@]}" -eq 0 ]; then
    echo "No encontre ningun servidor BHTTP escuchando en esta maquina."
    echo
    echo "Comprueba:   systemctl status proto-server"
    echo "             cat /etc/config.json"
    echo "             ss -tlnp | grep proto-server"
    exit 1
  fi

  echo "Encontrados ${#OKPORT[@]}: $(for i in "${!OKPORT[@]}"; do printf '%s(%s) ' "${OKPORT[$i]}" "${OKVIA[$i]}"; done)"
  SHOWHOST="$(public_ip)"
  [ -n "$SHOWHOST" ] && echo "IP publica de esta VPS: $SHOWHOST"
  echo
  echo "Prueba completa en el puerto ${OKPORT[0]}:"
  echo

  PORT="${OKPORT[0]}"
  if [ "${OKVIA[0]}" = "tls" ]; then USETLS=1; else USETLS=0; fi
  run_target; RC=$?

  if [ "${#OKPORT[@]}" -gt 1 ]; then
    echo
    echo "  Los otros puertos que tambien responden BHTTP:"
    for i in "${!OKPORT[@]}"; do
      [ "$i" = 0 ] && continue
      echo "    puerto ${OKPORT[$i]} (${OKVIA[$i]}) - pruebalo con:  $0 ${SHOWHOST:-<host>} ${OKPORT[$i]}"
    done
  fi
  echo
  echo "  Recuerda: esto se prueba contra 127.0.0.1, asi que el paso 3 no mide"
  echo "  la red del operador. Para eso, corre el script desde el movil o el PC:"
  echo "      $0 ${SHOWHOST:-<tu-servidor>}"
  exit "$RC"
fi

# ===== modo normal: host dado por el usuario =====
# que puertos y con que transporte
declare -a TRY_PORT=() TRY_TLS=()
if [ -n "$PORT" ]; then
  TRY_PORT+=("$PORT")
  case "$TLSMODE" in
    on)  TRY_TLS+=(1) ;;
    off) TRY_TLS+=(0) ;;
    *)   if [ "$PORT" = 443 ]; then TRY_TLS+=(1); else TRY_TLS+=(0); fi ;;
  esac
else
  # DTProto Server: 80 sin SSL, 443 con SSL
  case "$TLSMODE" in
    on)  TRY_PORT+=(443 80);   TRY_TLS+=(1 1) ;;
    off) TRY_PORT+=(80 443);   TRY_TLS+=(0 0) ;;
    *)   TRY_PORT+=(80 443);   TRY_TLS+=(0 1) ;;
  esac
fi

RC=1
for i in "${!TRY_PORT[@]}"; do
  PORT="${TRY_PORT[$i]}"; USETLS="${TRY_TLS[$i]}"
  [ "$i" -gt 0 ] && echo
  run_target; RC=$?
  if [ "$RC" = 0 ]; then break; fi
  # si no habla BHTTP y el transporte lo elegimos nosotros, probamos el otro
  if [ "$RC" = 2 ] && [ "$TLSMODE" = "auto" ]; then
    echo
    if [ "$USETLS" = 1 ]; then USETLS=0; else USETLS=1; fi
    echo "   -> reintentando el mismo puerto con el otro transporte"
    echo
    run_target; RC=$?
    [ "$RC" = 0 ] && break
  fi
done

exit "$RC"

PROBEOF
  chmod 755 "$PROBE"
  "$PROBE" --help >/dev/null 2>&1 || true
  ln -sf "$PROBE" /usr/local/bin/bhttp-probe
}

crear_servicio(){
  local py; py="$(command -v python3)"
  cat > "$UNIT" <<EOF
[Unit]
Description=KevinTech BHTTP Server (DTunnel compatible)
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$py $SERVER_PY --host $BHTTP_HOST --port $BHTTP_PORT --backend-host $SSH_HOST --backend-port $SSH_PORT
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF
  chmod 644 "$UNIT"
}

probar_real(){
  [[ -x "$PROBE" ]] || { err "No existe el probador BHTTP."; return 1; }
  "$PROBE" 127.0.0.1 "$BHTTP_PORT" --no-tls --fast
}

instalar(){
  clear
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗
║                 🌐 KEVINTECH BHTTP 🌐                       ║
║                  INSTALAR / ACTUALIZAR                     ║
╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo; line
  echo -e "  BHTTP : ${CYAN}$BHTTP_HOST:$BHTTP_PORT${RESET}"
  echo -e "  SSH   : ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"
  line; echo
  instalar_dependencias || { err "No se pudieron instalar las dependencias."; pause; return 1; }
  ok "Dependencias listas."
  ssh_ok && ok "SSH escuchando en $SSH_PORT." || warn "No se detecta SSH en $SSH_PORT; BHTTP se instalará, pero el backend debe estar activo."
  systemctl stop "$SERVICE" 2>/dev/null || true
  info "Instalando el servidor BHTTP compatible..."
  instalar_servidor || { err "No se pudo instalar/validar bhttp-server.py"; pause; return 1; }
  instalar_probe || { err "No se pudo instalar bhttp-probe."; pause; return 1; }
  crear_servicio || { err "No se pudo crear bhttp.service"; pause; return 1; }
  crear_config
  systemctl daemon-reload
  systemctl enable "$SERVICE" >/dev/null 2>&1
  systemctl restart "$SERVICE"
  local up=0
  for _ in $(seq 1 15); do
    if systemctl is-active --quiet "$SERVICE" && escucha "$BHTTP_PORT"; then up=1; break; fi
    sleep 1
  done
  if (( ! up )); then
    err "El servicio no inició correctamente."
    journalctl -u "$SERVICE" -n 30 --no-pager -l 2>/dev/null
    pause; return 1
  fi
  ok "Servicio activo y puerto $BHTTP_PORT escuchando."
  echo; info "Ejecutando la prueba REAL del protocolo BHTTP..."; echo
  if probar_real; then
    echo; ok "BHTTP respondió correctamente al protocolo."
  else
    echo; warn "El servicio está escuchando, pero la prueba de protocolo falló."
    echo; journalctl -u "$SERVICE" -n 20 --no-pager -l 2>/dev/null
  fi
  echo; echo -e "${GREEN}${BOLD}BHTTP instalado:${RESET} $BHTTP_HOST:$BHTTP_PORT → $SSH_HOST:$SSH_PORT"
  pause
}

reiniciar(){ clear; info "Reiniciando BHTTP..."; systemctl restart "$SERVICE"; sleep 2; systemctl is-active --quiet "$SERVICE" && escucha "$BHTTP_PORT" && ok "BHTTP reiniciado correctamente." || { err "No pudo iniciar."; journalctl -u "$SERVICE" -n 20 --no-pager -l; }; pause; }

probar(){ clear; echo -e "${CYAN}${BOLD}🧪 PRUEBA REAL BHTTP${RESET}"; echo; line; echo -e "Servicio : $(estado)"; echo -e "Puerto   : $(escucha "$BHTTP_PORT" && echo -e "${GREEN}✔ $BHTTP_PORT${RESET}" || echo -e "${RED}✘ $BHTTP_PORT${RESET}")"; echo -e "SSH      : $(ssh_ok && echo -e "${GREEN}✔ $SSH_PORT${RESET}" || echo -e "${RED}✘ $SSH_PORT${RESET}")"; echo; line; echo; "$PROBE" 127.0.0.1 "$BHTTP_PORT" --no-tls --fast; pause; }

diag(){ clear; echo -e "${CYAN}${BOLD}🔎 DIAGNÓSTICO BHTTP${RESET}"; echo; line; echo -e "Servicio : $(estado)"; echo -e "Auto     : $(systemctl is-enabled "$SERVICE" 2>/dev/null || echo no)"; echo -e "Listener : $BHTTP_HOST:$BHTTP_PORT"; echo -e "Backend  : $SSH_HOST:$SSH_PORT"; echo; line; echo; ss -ltnp 2>/dev/null | grep -E ":($BHTTP_PORT|$SSH_PORT)\b" || true; echo; line; echo; journalctl -u "$SERVICE" -n 30 --no-pager -l 2>/dev/null; pause; }
logs(){ clear; journalctl -u "$SERVICE" -n 80 --no-pager -l 2>/dev/null; pause; }

uninstall(){
  clear; echo -e "${RED}${BOLD}🗑️ DESINSTALAR BHTTP${RESET}"; echo; read -rp "¿Confirmar? [s/N]: " c
  case "${c,,}" in s|si|sí|y|yes) ;; *) echo "Cancelado."; pause; return;; esac
  systemctl stop "$SERVICE" 2>/dev/null || true
  systemctl disable "$SERVICE" 2>/dev/null || true
  rm -f "$UNIT" /usr/local/bin/bhttp-probe
  rm -rf "$DIR"
  rm -f "$CONFIG"
  systemctl daemon-reload
  systemctl reset-failed "$SERVICE" 2>/dev/null || true
  ok "BHTTP desinstalado. SSH y sus cuentas no fueron modificados."
  pause
}

menu(){
  clear
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗
║                 🌐 KEVINTECH BHTTP 🌐                       ║
║                    PROTOCOLO v$VERSION                      ║
╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo; echo -e "  Servicio : $(estado)"; echo -e "  BHTTP    : ${CYAN}$BHTTP_HOST:$BHTTP_PORT${RESET}"; echo -e "  Backend  : ${CYAN}$SSH_HOST:$SSH_PORT${RESET}"; echo
  line; echo -e "  ${GREEN}[01]${RESET} 🚀 Instalar / Actualizar"; echo -e "  ${GREEN}[02]${RESET} 🔄 Reiniciar BHTTP"; echo -e "  ${GREEN}[03]${RESET} 🧪 Probar protocolo REAL"; echo -e "  ${GREEN}[04]${RESET} 🔎 Diagnóstico"; echo -e "  ${GREEN}[05]${RESET} 📜 Ver logs"; echo -e "  ${RED}[06]${RESET} 🗑️  Desinstalar"; echo -e "  ${RED}[00]${RESET} ↩️  Volver"; line; echo
}

trap 'echo; echo -e "${YELLOW}⚠ Regresando...${RESET}"; sleep 1; clear; exit 0' INT TERM

case "${1:-}" in
  --install|-i) instalar; exit $?;;
  --restart) reiniciar; exit $?;;
  --probe) probar; exit $?;;
  --diag) diag; exit $?;;
  --logs) logs; exit $?;;
  --uninstall|--desinstalar) uninstall; exit $?;;
  --status) menu; exit 0;;
esac

while true; do
  menu
  read -rp "$(echo -e "${CYAN}${BOLD}  ➜ Seleccione una opción: ${RESET}")" op
  case "$op" in
    1|01) instalar;; 2|02) reiniciar;; 3|03) probar;; 4|04) diag;; 5|05) logs;; 6|06) uninstall;; 0|00) clear; exit 0;; *) [[ -z "$op" ]] || { err "Opción inválida."; sleep 1; };;
  esac
done
