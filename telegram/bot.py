#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KEVINTECH TELEGRAM BOT - FULL INTEGRATION
Interfaz Telegram para /etc/kevintech.

No requiere pip ni librerías externas.
Usa únicamente la biblioteca estándar de Python y Telegram Bot API.
"""
import json, os, re, shlex, subprocess, time, urllib.parse, urllib.request
from pathlib import Path

BASE = Path("/etc/kevintech")
BOT_DIR = BASE / "telegram"
ENV_FILE = BOT_DIR / ".env"
LOG_FILE = BOT_DIR / "logs" / "bot.log"
OFFSET_FILE = BOT_DIR / "offset"

STATES = {}
API = None
ALLOWED = set()

def log(message):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(time.strftime("[%Y-%m-%d %H:%M:%S] ") + str(message) + "\n")

def load_env():
    global API, ALLOWED
    if not ENV_FILE.is_file():
        raise SystemExit(f"Falta {ENV_FILE}. Ejecuta setup.sh.")
    vals = {}
    for line in ENV_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
        line=line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k,v=line.split("=",1)
        vals[k.strip()] = v.strip().strip('"').strip("'")
    token=vals.get("BOT_TOKEN","")
    owner=vals.get("ADMIN_ID","")
    extras=vals.get("ADMIN_IDS","")
    if not re.fullmatch(r"\d+:[A-Za-z0-9_-]+", token):
        raise SystemExit("BOT_TOKEN inválido.")
    if not owner.isdigit():
        raise SystemExit("ADMIN_ID inválido.")
    ALLOWED={int(owner)}
    for x in extras.split(","):
        if x.strip().isdigit():
            ALLOWED.add(int(x.strip()))
    API=f"https://api.telegram.org/bot{token}"

def tg(method, data=None):
    body=urllib.parse.urlencode(data or {}).encode()
    req=urllib.request.Request(API+"/"+method, data=body)
    with urllib.request.urlopen(req, timeout=45) as resp:
        raw=resp.read().decode()
    result=json.loads(raw)
    if not result.get("ok"):
        raise RuntimeError(f"Telegram API: {result}")
    return result

def send(chat, text, keyboard=None):
    data={"chat_id":str(chat),"text":text,"parse_mode":"HTML","disable_web_page_preview":"true"}
    if keyboard:
        data["reply_markup"]=json.dumps({"inline_keyboard":keyboard}, ensure_ascii=False)
    return tg("sendMessage",data)

def edit(chat, message_id, text, keyboard=None):
    data={"chat_id":str(chat),"message_id":str(message_id),"text":text,"parse_mode":"HTML","disable_web_page_preview":"true"}
    if keyboard:
        data["reply_markup"]=json.dumps({"inline_keyboard":keyboard}, ensure_ascii=False)
    try:
        return tg("editMessageText",data)
    except Exception:
        return send(chat,text,keyboard)

def answer(callback_id,text=""):
    try: tg("answerCallbackQuery",{"callback_query_id":callback_id,"text":text})
    except Exception: pass

def esc(value):
    return str(value).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def cmd(command, timeout=25):
    try:
        p=subprocess.run(command,shell=True,text=True,capture_output=True,timeout=timeout)
        return p.returncode,(p.stdout+p.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124,"Tiempo de espera agotado."
    except Exception as e:
        return 1,str(e)

def q(value):
    return shlex.quote(str(value))

def module(name):
    for p in (BASE/"usuarios"/name,BASE/"protocolos"/name,BASE/"herramientas"/name,BASE/name):
        if p.is_file():
            return p
    return None

def run_module(name, timeout=20):
    p=module(name)
    if not p:
        return f"⚠️ <b>{esc(name)}</b>\n\nMódulo no encontrado en <code>/etc/kevintech</code>."
    rc,out=cmd(f"bash {q(p)}",timeout)
    if len(out)>4500: out=out[-4500:]
    return f"🧩 <b>{esc(name)}</b>\n\n<pre>{esc(out or 'Sin salida.')}</pre>"

def service_state(name):
    rc,_=cmd(f"systemctl is-active --quiet {q(name)}",5)
    return "🟢 ACTIVO" if rc==0 else "🔴 INACTIVO"

def main_kb():
    return [
        [{"text":"👤 Usuarios","callback_data":"users"},{"text":"🌐 Protocolos","callback_data":"protocols"}],
        [{"text":"📊 Estado VPS","callback_data":"status"},{"text":"🛠 Herramientas","callback_data":"tools"}],
        [{"text":"🔄 Servicios","callback_data":"services"},{"text":"ℹ️ Información","callback_data":"info"}]
    ]

def users_kb():
    return [
        [{"text":"➕ Crear cuenta","callback_data":"u_create"},{"text":"🗑 Eliminar","callback_data":"u_delete"}],
        [{"text":"📋 Lista","callback_data":"u_list"},{"text":"🟢 Online","callback_data":"u_online"}],
        [{"text":"♻️ Renovar","callback_data":"u_renew"},{"text":"🔑 Cambiar clave","callback_data":"u_password"}],
        [{"text":"🔒 Bloquear","callback_data":"u_block"},{"text":"🔓 Desbloquear","callback_data":"u_unblock"}],
        [{"text":"💾 Backup","callback_data":"u_backup"},{"text":"🔙 Volver","callback_data":"home"}]
    ]

def protocols_kb():
    return [
        [{"text":"🔐 OpenSSH","callback_data":"p_ssh"},{"text":"🟡 Dropbear","callback_data":"p_dropbear"}],
        [{"text":"🔵 OpenVPN","callback_data":"p_openvpn"},{"text":"🟣 V2Ray/Xray","callback_data":"p_v2ray"}],
        [{"text":"🔎 CheckUser","callback_data":"p_checkuser"},{"text":"🐌 SlowDNS","callback_data":"p_slowdns"}],
        [{"text":"🔒 SSL","callback_data":"p_ssl"},{"text":"🚀 BadVPN","callback_data":"p_badvpn"}],
        [{"text":"📡 UDP Custom","callback_data":"p_udp"},{"text":"📡 ZiVPN","callback_data":"p_zivpn"}],
        [{"text":"🔙 Volver","callback_data":"home"}]
    ]

def tools_kb():
    return [
        [{"text":"🔥 Firewall","callback_data":"t_firewall"},{"text":"⚡ Reiniciar","callback_data":"t_restart"}],
        [{"text":"🚀 Optimizar","callback_data":"t_opt"},{"text":"📈 Speedtest","callback_data":"t_speed"}],
        [{"text":"🔎 Scanner","callback_data":"t_scan"},{"text":"📁 Archivo Online","callback_data":"t_online"}],
        [{"text":"🚫 Block Ads","callback_data":"t_ads"},{"text":"🚫 Block Torrent","callback_data":"t_torrent"}],
        [{"text":"🔄 Actualizar","callback_data":"t_update"},{"text":"🔙 Volver","callback_data":"home"}]
    ]

def services_kb():
    return [
        [{"text":"🔐 SSH","callback_data":"s_ssh"},{"text":"🟡 Dropbear","callback_data":"s_dropbear"}],
        [{"text":"🔵 OpenVPN","callback_data":"s_openvpn"},{"text":"🟣 Xray","callback_data":"s_xray"}],
        [{"text":"🔎 CheckUser","callback_data":"s_checkuser"},{"text":"🐌 SlowDNS","callback_data":"s_slowdns"}],
        [{"text":"🚀 ZiVPN","callback_data":"s_zivpn"},{"text":"🔙 Volver","callback_data":"home"}]
    ]

def parse_config():
    cfg={}
    f=BASE/"config.conf"
    if f.is_file():
        for line in f.read_text(errors="ignore").splitlines():
            m=re.match(r'\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)',line)
            if m:
                cfg[m.group(1)]=m.group(2).strip().strip('"').strip("'")
    return cfg

def public_ip():
    rc,out=cmd("curl -4 -fsS --max-time 5 ifconfig.me",8)
    if rc==0 and out.strip(): return out.strip()
    return subprocess.getoutput("hostname -I").split()[0] if subprocess.getoutput("hostname -I").split() else "0.0.0.0"

def ports_for(process):
    rc,out=cmd(f"ss -ltnp 2>/dev/null | grep -i {q(process)} || true",5)
    ports=set()
    for line in out.splitlines():
        m=re.search(r':(\d+)\s',line)
        if m: ports.add(m.group(1))
    return ",".join(sorted(ports,key=int)) or "No instalado"

def account_data(user,password,days,limit):
    cfg=parse_config()
    host=cfg.get("SERVER_DOMAIN") or public_ip()
    ip=public_ip()
    expire=subprocess.getoutput(f"date -d '+{int(days)} days' +%Y-%m-%d")
    expire_show=subprocess.getoutput(f"date -d '+{int(days)} days' '+%d/%m/%Y'")
    ssh=ports_for("sshd")
    drop=ports_for("dropbear")
    hap=ports_for("haproxy")
    bad=ports_for("badvpn")
    hyst="No instalado"
    hyst_obfs="No configurado"
    hc=Path("/etc/hysteria/config.json")
    if hc.is_file():
        try:
            data=json.loads(hc.read_text(errors="ignore"))
            listen=str(data.get("listen","")).lstrip(":")
            if listen: hyst=listen
            if isinstance(data.get("obfs"),str): hyst_obfs=data["obfs"]
        except Exception: pass
    zivpn="No instalado"
    zc=Path("/etc/zivpn/config.json")
    if zc.is_file():
        try:
            data=json.loads(zc.read_text(errors="ignore"))
            zivpn=str(data.get("listen","")).lstrip(":") or zivpn
        except Exception: pass
    slowdns=None
    dn=Path("/etc/slowdns/domain.conf"); key=Path("/etc/slowdns/server.pub")
    if dn.is_file() and key.is_file():
        slowdns=(dn.read_text().strip(),key.read_text().strip())
    lim="♾ Ilimitado" if int(limit)==0 else f"{limit} conexión(es)"
    text=f"""🎉 <b>CUENTA CREADA EXITOSAMENTE</b>

👤 <b>Usuario:</b> <code>{esc(user)}</code>
🔑 <b>Contraseña:</b> <code>{esc(password)}</code>
📅 <b>Expira:</b> <code>{esc(expire_show)}</code> ({days} días)
👥 <b>Límite IP:</b> <code>{esc(lim)}</code>

🌐 <b>SERVIDOR</b>
• Host/IP: <code>{esc(host)}</code>
• IP: <code>{esc(ip)}</code>
• SSH: <code>{esc(ssh)}</code>
• Dropbear: <code>{esc(drop)}</code>
• SSL: <code>{esc(hap)}</code>
• OpenVPN: <code>1194,2200,443</code>
• BadVPN: <code>{esc(bad)}</code>

📡 <b>HTTP CUSTOM</b>
<code>{esc(host)}:443@{esc(user)}:{esc(password)}</code>
<code>{esc(host)}:80@{esc(user)}:{esc(password)}</code>
<code>{esc(host)}:8080@{esc(user)}:{esc(password)}</code>

🚀 <b>UDP CUSTOM</b>
<code>{esc(ip)}:1-65535@{esc(user)}:{esc(password)}</code>

🟣 <b>HYSTERIA V1</b>
• Servidor: <code>{esc(host)}:{esc(hyst)}</code>
• OBFS: <code>{esc(hyst_obfs)}</code>
• Credenciales: <code>{esc(user)}:{esc(password)}</code>

🚀 <b>ZIVPN UDP</b>
• Servidor: <code>{esc(host)}:{esc(zivpn)}</code>
• Contraseña: <code>{esc(password)}</code>
• Puerto UDP: <code>20000-29999</code>"""
    if slowdns:
        text+=f"""

🐌 <b>SLOWDNS</b>
• NS: <code>{esc(slowdns[0])}</code>
• KEY: <code>{esc(slowdns[1])}</code>
• Puerto: <code>5300</code>"""
    return text

def user_exists(user):
    return bool(re.fullmatch(r"[a-z][a-z0-9_-]{2,31}",user,re.I)) and subprocess.call(f"id {q(user)} >/dev/null 2>&1",shell=True)==0

def create_account(user,password,days,limit):
    if not re.fullmatch(r"[a-z][a-z0-9_-]{2,31}",user,re.I):
        return False,"Nombre de usuario inválido."
    if len(password)<4: return False,"La contraseña debe tener al menos 4 caracteres."
    if not str(days).isdigit() or int(days)<=0: return False,"Duración inválida."
    if not str(limit).isdigit() or int(limit)<0: return False,"Límite inválido."
    if user_exists(user): return False,"El usuario ya existe."
    expire=subprocess.getoutput(f"date -d '+{int(days)} days' +%Y-%m-%d")
    rc,out=cmd(f"useradd -e {q(expire)} -M -s /usr/sbin/nologin {q(user)}",15)
    if rc!=0: return False,out or "useradd falló."
    rc,out=cmd(f"printf '%s\\n' {q(user+':'+password)} | chpasswd",15)
    if rc!=0:
        cmd(f"userdel -f {q(user)}",10)
        return False,out or "No se pudo establecer la contraseña."
    # Keep the project's limit mechanism.
    limdir=BASE/"limits"; limdir.mkdir(parents=True,exist_ok=True)
    (limdir/user).write_text(str(int(limit)))
    # Synchronize password with ZiVPN exactly as the project add.sh does.
    zc=Path("/etc/zivpn/config.json")
    if zc.is_file():
        try:
            data=json.loads(zc.read_text())
            auth=data.setdefault("auth",{}); arr=auth.setdefault("config",[])
            if password not in arr:
                arr.append(password)
                tmp=zc.with_suffix(".tmp")
                tmp.write_text(json.dumps(data,indent=2))
                os.chmod(tmp,0o600); tmp.replace(zc)
                cmd("systemctl restart zivpn",15)
        except Exception as e:
            log("ZiVPN sync: "+repr(e))
    # Ensure the same limiter used by the project exists.
    limiter=Path("/usr/local/bin/kevintech-limit.sh")
    if not limiter.exists():
        limiter.write_text("""#!/bin/bash
LIMIT_DIR="/etc/kevintech/limits"
mkdir -p "$LIMIT_DIR"
for FILE in "$LIMIT_DIR"/*; do
 [ -f "$FILE" ] || continue
 USER=$(basename "$FILE"); LIMIT=$(cat "$FILE")
 [ "$LIMIT" = "0" ] && continue
 IPS=$(ps -u "$USER" -o pid= | while read PID; do ss -tnp 2>/dev/null | grep "pid=$PID,"; done | awk '{print $5}' | cut -d: -f1 | sort -u | wc -l)
 [ "$IPS" -gt "$LIMIT" ] && pkill -KILL -u "$USER" 2>/dev/null
done
""")
        limiter.chmod(0o755)
        Path("/etc/cron.d/kevintech-limit").write_text("* * * * * root /usr/local/bin/kevintech-limit.sh\n")
        cmd("systemctl enable cron >/dev/null 2>&1; systemctl restart cron",15)
    return True,"OK"

def list_users():
    rc,out=cmd("awk -F: '$3>=1000 && $1!=\"nobody\"{print $1}' /etc/passwd",10)
    if rc: return "❌ No se pudo obtener la lista."
    arr=[x for x in out.splitlines() if x]
    if not arr: return "📋 <b>USUARIOS</b>\n\nNo hay usuarios."
    lines=["📋 <b>USUARIOS REGISTRADOS</b>",""]
    for i,u in enumerate(arr,1):
        exp=subprocess.getoutput(f"chage -l {q(u)} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'")
        locked=subprocess.getoutput(f"passwd -S {q(u)} 2>/dev/null | awk '{{print $2}}'")
        state="🔒 Bloqueado" if locked=="L" else "🟢 Activo"
        lines.append(f"{i:02d}. <code>{esc(u)}</code> — <code>{esc(exp or 'N/D')}</code> — {state}")
    lines.append(f"\n<b>Total:</b> {len(arr)}")
    return "\n".join(lines)

def online_users():
    rc,out=cmd("""ps -C sshd -o args= 2>/dev/null | grep '\\[priv\\]' | awk -F'sshd: ' '{print $2}' | awk '{print $1}' | sort | uniq -c""",10)
    if not out: return "🟢 <b>USUARIOS ONLINE</b>\n\nNo hay usuarios conectados."
    return "🟢 <b>USUARIOS ONLINE</b>\n\n<pre>"+esc(out)+"</pre>"

def status_text():
    host=subprocess.getoutput("hostname")
    up=subprocess.getoutput("uptime -p")
    load=subprocess.getoutput("awk '{print $1\", \"$2\", \"$3}' /proc/loadavg")
    mem=subprocess.getoutput("free -m | awk '/^Mem:/ {printf \"%d/%d MB (%d%%)\",$3,$2,($3*100)/$2}'")
    disk=subprocess.getoutput("df -h / | awk 'NR==2 {print $3\"/\"$2\" (\"$5\")\"}'")
    return f"""📊 <b>ESTADO DEL VPS</b>

🖥 Host: <code>{esc(host)}</code>
⏱ Uptime: <code>{esc(up)}</code>
⚙️ Load: <code>{esc(load)}</code>
🧠 RAM: <code>{esc(mem)}</code>
💾 Disco: <code>{esc(disk)}</code>

🔐 SSH: {service_state("ssh")}
🟡 Dropbear: {service_state("dropbear")}
🔵 OpenVPN: {service_state("openvpn")}
🟣 Xray: {service_state("xray")}
🔎 CheckUser: {service_state("checkuser")}
🐌 SlowDNS: {service_state("slowdns")}
🚀 ZiVPN: {service_state("zivpn")}"""

def begin(chat,flow,step,data=None):
    STATES[chat]={"flow":flow,"step":step,"data":data or {}}

def text_handler(chat,text):
    if chat not in ALLOWED:
        send(chat,"⛔ <b>Acceso denegado.</b>")
        return
    st=STATES.get(chat)
    if not st:
        if text in ("/start","/menu"):
            send(chat,"🤖 <b>KEVINTECH MULTI SCRIPT</b>\n\nPanel de administración:",main_kb())
        elif text=="/id":
            send(chat,f"🆔 Tu Telegram ID: <code>{chat}</code>")
        else:
            send(chat,"Usa /menu para abrir el panel.",main_kb())
        return

    flow,step,data=st["flow"],st["step"],st["data"]

    if flow=="create":
        if step=="username":
            user=text.strip().lower()
            if not re.fullmatch(r"[a-z][a-z0-9_-]{2,31}",user,re.I):
                return send(chat,"❌ Usuario inválido.\n\nUsa 3–32 caracteres: letras, números, <code>_</code> o <code>-</code>.")
            if user_exists(user):
                return send(chat,"❌ Ese usuario ya existe. Escribe otro:")
            data["user"]=user; st["step"]="password"
            return send(chat,"🔑 <b>Contraseña</b>\n\nEscribe la contraseña de la cuenta:")
        if step=="password":
            if len(text)<4: return send(chat,"❌ La contraseña debe tener al menos 4 caracteres.")
            data["password"]=text; st["step"]="days"
            return send(chat,"📅 <b>Duración</b>\n\nEscribe los días de la cuenta.\n\nEjemplo: <code>30</code>")
        if step=="days":
            if not text.isdigit() or int(text)<=0: return send(chat,"❌ Introduce un número de días mayor que 0.")
            data["days"]=int(text); st["step"]="limit"
            return send(chat,"👥 <b>Límite de conexiones</b>\n\nEscribe el límite.\n\n<code>0</code> = ilimitado")
        if step=="limit":
            if not text.isdigit() or int(text)<0: return send(chat,"❌ Límite inválido.")
            data["limit"]=int(text)
            st["step"]="confirm"
            d=data
            return send(chat,f"""📝 <b>CONFIRMAR CUENTA</b>

👤 Usuario: <code>{esc(d["user"])}</code>
🔑 Contraseña: <code>{esc(d["password"])}</code>
📅 Duración: <code>{d["days"]} días</code>
👥 Límite: <code>{"Ilimitado" if d["limit"]==0 else d["limit"]}</code>""",[[{"text":"✅ CREAR CUENTA","callback_data":"u_confirm_create"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
    elif flow=="renew":
        if step=="username":
            user=text.strip().lower()
            if not user_exists(user): return send(chat,"❌ Usuario no encontrado. Escribe otro:")
            data["user"]=user; st["step"]="days"
            exp=subprocess.getoutput(f"chage -l {q(user)} | awk -F': ' '/Account expires/{{print $2}}'")
            return send(chat,f"♻️ <b>RENOVAR</b>\n\nUsuario: <code>{esc(user)}</code>\nExpiración actual: <code>{esc(exp)}</code>\n\n📅 Escribe cuántos días deseas renovar:")
        if step=="days":
            if not text.isdigit() or int(text)<=0: return send(chat,"❌ Días inválidos.")
            data["days"]=int(text); st["step"]="confirm"
            return send(chat,f"♻️ <b>CONFIRMAR RENOVACIÓN</b>\n\n👤 Usuario: <code>{esc(data['user'])}</code>\n📅 Renovar: <code>{data['days']} días</code>",[[{"text":"✅ RENOVAR","callback_data":"u_confirm_renew"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
    elif flow in ("delete","block","unblock","password"):
        if step=="username":
            user=text.strip()
            if not user_exists(user): return send(chat,"❌ Usuario no encontrado. Escribe otro:")
            data["user"]=user
            if flow=="delete":
                st["step"]="confirm"
                return send(chat,f"🗑️ <b>ELIMINAR</b>\n\n¿Confirmar eliminación de <code>{esc(user)}</code>?",[[{"text":"✅ ELIMINAR","callback_data":"u_confirm_delete"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
            if flow=="password":
                st["step"]="password"
                return send(chat,f"🔑 Nueva contraseña para <code>{esc(user)}</code>:")
            if flow=="block":
                st["step"]="confirm"
                return send(chat,f"🔒 <b>BLOQUEAR</b>\n\n¿Bloquear <code>{esc(user)}</code>?",[[{"text":"✅ BLOQUEAR","callback_data":"u_confirm_block"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
            if flow=="unblock":
                st["step"]="confirm"
                return send(chat,f"🔓 <b>DESBLOQUEAR</b>\n\n¿Desbloquear <code>{esc(user)}</code>?",[[{"text":"✅ DESBLOQUEAR","callback_data":"u_confirm_unblock"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
        if flow=="password" and step=="password":
            if len(text)<4: return send(chat,"❌ Contraseña demasiado corta.")
            data["password"]=text; st["step"]="confirm"
            return send(chat,f"🔑 <b>CONFIRMAR CAMBIO</b>\n\nUsuario: <code>{esc(data['user'])}</code>",[[{"text":"✅ CAMBIAR","callback_data":"u_confirm_password"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])

def callback(chat,message_id,uid,cid,data):
    answer(cid)
    if int(uid) not in ALLOWED:
        answer(cid,"⛔ Acceso denegado"); return
    if data=="home": return edit(chat,message_id,"🏠 <b>KEVINTECH MULTI SCRIPT</b>\n\nSelecciona una sección:",main_kb())
    if data=="users": return edit(chat,message_id,"👤 <b>GESTIÓN DE USUARIOS</b>\n\nSelecciona una función:",users_kb())
    if data=="protocols": return edit(chat,message_id,"🌐 <b>PROTOCOLOS</b>\n\nFunciones disponibles:",protocols_kb())
    if data=="tools": return edit(chat,message_id,"🛠 <b>HERRAMIENTAS</b>\n\nFunciones disponibles:",tools_kb())
    if data=="services": return edit(chat,message_id,status_text(),services_kb())
    if data=="status": return edit(chat,message_id,status_text(),main_kb())
    if data=="info": return edit(chat,message_id,"🤖 <b>KEVINTECH TELEGRAM</b>\n\nControl integrado de <code>/etc/kevintech</code>.\n\n🔐 Acceso por Telegram ID\n🟢 Servicio systemd\n🔄 Reinicio automático",main_kb())
    if data=="cancel":
        STATES.pop(chat,None); return edit(chat,message_id,"❌ Operación cancelada.",users_kb())

    if data=="u_create":
        begin(chat,"create","username"); return send(chat,"➕ <b>CREAR CUENTA SSH</b>\n\nEscribe el nombre de usuario:")
    if data=="u_renew":
        begin(chat,"renew","username"); return send(chat,"♻️ <b>RENOVAR CUENTA</b>\n\nEscribe el usuario:")
    if data=="u_delete":
        begin(chat,"delete","username"); return send(chat,"🗑️ <b>ELIMINAR CUENTA</b>\n\nEscribe el usuario:")
    if data=="u_block":
        begin(chat,"block","username"); return send(chat,"🔒 <b>BLOQUEAR CUENTA</b>\n\nEscribe el usuario:")
    if data=="u_unblock":
        begin(chat,"unblock","username"); return send(chat,"🔓 <b>DESBLOQUEAR CUENTA</b>\n\nEscribe el usuario:")
    if data=="u_password":
        begin(chat,"password","username"); return send(chat,"🔑 <b>CAMBIAR CONTRASEÑA</b>\n\nEscribe el usuario:")

    if data=="u_list": return edit(chat,message_id,list_users(),users_kb())
    if data=="u_online": return edit(chat,message_id,online_users(),users_kb())
    if data=="u_backup": return edit(chat,message_id,run_module("backup.sh"),users_kb())

    st=STATES.get(chat,{})
    d=st.get("data",{})

    if data=="u_confirm_create" and st.get("flow")=="create":
        STATES.pop(chat,None)
        ok,msg=create_account(d["user"],d["password"],d["days"],d["limit"])
        if not ok: return send(chat,f"❌ <b>No se pudo crear la cuenta.</b>\n\n<pre>{esc(msg)}</pre>",users_kb())
        return send(chat,account_data(d["user"],d["password"],d["days"],d["limit"]),users_kb())

    if data=="u_confirm_renew" and st.get("flow")=="renew":
        STATES.pop(chat,None)
        user=d["user"]; days=d["days"]
        new_exp=subprocess.getoutput(f"date -d '+{days} days' +%Y-%m-%d")
        rc,out=cmd(f"chage -E {q(new_exp)} {q(user)}",15)
        if rc!=0: return send(chat,f"❌ <b>Error al renovar</b>\n\n<pre>{esc(out)}</pre>",users_kb())
        # Send complete account data after renewal, with password omitted because it is not recoverable.
        exp_show=subprocess.getoutput(f"date -d {q(new_exp)} '+%d/%m/%Y'")
        text=f"""♻️ <b>CUENTA RENOVADA EXITOSAMENTE</b>

👤 <b>Usuario:</b> <code>{esc(user)}</code>
📅 <b>Nueva expiración:</b> <code>{esc(exp_show)}</code>
⏳ <b>Renovado:</b> <code>{days} días</code>

🔐 La contraseña actual se mantiene.
🌐 Host/IP: <code>{esc(parse_config().get("SERVER_DOMAIN") or public_ip())}</code>
🔐 SSH: <code>{esc(ports_for("sshd"))}</code>
🟡 Dropbear: <code>{esc(ports_for("dropbear"))}</code>"""
        return send(chat,text,users_kb())

    if data=="u_confirm_delete" and st.get("flow")=="delete":
        STATES.pop(chat,None)
        user=d["user"]; rc,out=cmd(f"pkill -u {q(user)} >/dev/null 2>&1 || true; userdel -f {q(user)}",15)
        lim=BASE/"limits"/user
        if lim.exists(): lim.unlink()
        return send(chat,("🗑️ <b>Cuenta eliminada correctamente.</b>" if rc==0 else f"❌ <b>No se pudo eliminar.</b>\n\n<pre>{esc(out)}</pre>"),users_kb())

    if data=="u_confirm_block" and st.get("flow")=="block":
        STATES.pop(chat,None)
        user=d["user"]; rc,out=cmd(f"passwd -l {q(user)} >/dev/null 2>&1; pkill -u {q(user)} >/dev/null 2>&1 || true",15)
        return send(chat,("🔒 <b>Cuenta bloqueada.</b>\n\nUsuario: <code>"+esc(user)+"</code>" if rc==0 else f"❌ Error\n<pre>{esc(out)}</pre>"),users_kb())

    if data=="u_confirm_unblock" and st.get("flow")=="unblock":
        STATES.pop(chat,None)
        user=d["user"]; rc,out=cmd(f"passwd -u {q(user)}",15)
        return send(chat,("🔓 <b>Cuenta desbloqueada.</b>\n\nUsuario: <code>"+esc(user)+"</code>" if rc==0 else f"❌ Error\n<pre>{esc(out)}</pre>"),users_kb())

    if data=="u_confirm_password" and st.get("flow")=="password":
        STATES.pop(chat,None)
        user,pwd=d["user"],d["password"]
        rc,out=cmd(f"printf '%s\\n' {q(user+':'+pwd)} | chpasswd",15)
        if rc==0:
            # Keep ZiVPN password sync compatible with add.sh.
            zc=Path("/etc/zivpn/config.json")
            if zc.is_file():
                try:
                    j=json.loads(zc.read_text()); arr=j.setdefault("auth",{}).setdefault("config",[])
                    if pwd not in arr:
                        arr.append(pwd); tmp=zc.with_suffix(".tmp"); tmp.write_text(json.dumps(j,indent=2)); os.chmod(tmp,0o600); tmp.replace(zc); cmd("systemctl restart zivpn",15)
                except Exception as e: log("ZiVPN password sync: "+repr(e))
        return send(chat,("🔑 <b>Contraseña actualizada.</b>\n\n👤 Usuario: <code>"+esc(user)+"</code>\n🔑 Nueva contraseña: <code>"+esc(pwd)+"</code>" if rc==0 else f"❌ Error\n<pre>{esc(out)}</pre>"),users_kb())

    # Protocols/tools: modules are discovered from the existing project.
    protocol_map={"p_ssh":"openssh.sh","p_dropbear":"dropbear.sh","p_openvpn":"openvpn.sh","p_v2ray":"v2ray.sh","p_checkuser":"checkuser.sh","p_slowdns":"slowdns.sh","p_ssl":"ssl.sh","p_badvpn":"badvpn.sh","p_udp":"udpcustom.sh","p_zivpn":"zivpn.sh"}
    tool_map={"t_firewall":"firewall.sh","t_restart":"reiniciar.sh","t_opt":"optimizar.sh","t_speed":"speedtest.sh","t_scan":"scanner.sh","t_online":"archivoonline.sh","t_ads":"blockads.sh","t_torrent":"blocktorrent.sh","t_update":"update.sh"}
    if data in protocol_map:
        return edit(chat,message_id,run_module(protocol_map[data],25),protocols_kb())
    if data in tool_map:
        return edit(chat,message_id,run_module(tool_map[data],30),tools_kb())

    services={"s_ssh":"ssh","s_dropbear":"dropbear","s_openvpn":"openvpn","s_xray":"xray","s_checkuser":"checkuser","s_slowdns":"slowdns","s_zivpn":"zivpn"}
    if data in services:
        svc=services[data]
        return edit(chat,message_id,f"🔄 <b>{esc(svc)}</b>\n\nEstado: {service_state(svc)}",services_kb())

def process(update):
    if "callback_query" in update:
        qy=update["callback_query"]; m=qy.get("message",{})
        callback(m["chat"]["id"],m.get("message_id"),qy["from"]["id"],qy["id"],qy.get("data",""))
    elif "message" in update:
        m=update["message"]; uid=m.get("from",{}).get("id"); chat=m["chat"]["id"]; text=m.get("text","")
        if uid in ALLOWED: text_handler(chat,text)
        else: send(chat,"⛔ <b>Acceso denegado.</b>")

def main():
    load_env()
    LOG_FILE.parent.mkdir(parents=True,exist_ok=True)
    LOG_FILE.touch(); LOG_FILE.chmod(0o600)
    me=tg("getMe")
    if not me.get("ok"): raise SystemExit("Token rechazado por Telegram.")
    if OFFSET_FILE.exists():
        try: offset=int(OFFSET_FILE.read_text().strip())
        except: offset=0
    else:
        # Ensure webhook is absent before long polling.
        try: tg("deleteWebhook",{"drop_pending_updates":"false"})
        except Exception as e: log("deleteWebhook: "+repr(e))
        r=tg("getUpdates",{"timeout":"0","limit":"1"})
        items=r.get("result",[])
        offset=items[-1]["update_id"]+1 if items else 0
    log("Bot online")
    while True:
        try:
            r=tg("getUpdates",{
                "offset":str(offset),
                "timeout":"30",
                "allowed_updates":json.dumps(["message","callback_query"])
            })
            for update in r.get("result",[]):
                offset=update["update_id"]+1
                OFFSET_FILE.write_text(str(offset))
                try: process(update)
                except Exception as e: log("Update error: "+repr(e))
        except Exception as e:
            log("Polling error: "+repr(e)); time.sleep(5)

if __name__=="__main__":
    main()
