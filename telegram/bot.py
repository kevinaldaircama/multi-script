#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KEVINTECH TELEGRAM BOT
Integrated controller for /etc/kevintech Multi Script.

- No third-party Python package required.
- Uses Telegram Bot API over urllib.
- Interactive state machine for user management.
- Direct service controls.
- Discovers existing Multi Script modules.
- Runs as a systemd service.
"""
import json, os, re, subprocess, time, urllib.parse, urllib.request
from pathlib import Path

BASE = Path("/etc/kevintech")
BOT_DIR = BASE / "telegram"
ENV = BOT_DIR / ".env"
LOG = BOT_DIR / "logs" / "bot.log"
OFFSET_FILE = BOT_DIR / "offset"
API = None
STATE = {}

def log(msg):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(time.strftime("[%Y-%m-%d %H:%M:%S] ") + msg + "\n")

def load_env():
    global API
    vals = {}
    if not ENV.exists():
        raise SystemExit(f"Missing {ENV}. Run setup.sh")
    for line in ENV.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k,v=line.split("=",1)
            vals[k.strip()] = v.strip().strip('"').strip("'")
    token=vals.get("BOT_TOKEN","")
    admin=vals.get("ADMIN_ID","")
    extra=vals.get("ADMIN_IDS","")
    if not re.fullmatch(r"\d+:[A-Za-z0-9_-]+", token):
        raise SystemExit("Invalid BOT_TOKEN")
    if not re.fullmatch(r"\d+", admin):
        raise SystemExit("Invalid ADMIN_ID")
    API=f"https://api.telegram.org/bot{token}"
    allowed={int(admin)}
    for x in extra.split(","):
        if x.strip().isdigit(): allowed.add(int(x.strip()))
    return allowed

ALLOWED=load_env()

def tg(method, data=None):
    data = data or {}
    body=urllib.parse.urlencode(data).encode()
    req=urllib.request.Request(API+"/"+method, data=body)
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())

def send(chat, text, keyboard=None):
    d={"chat_id":chat,"text":text,"parse_mode":"HTML"}
    if keyboard is not None: d["reply_markup"]=json.dumps({"inline_keyboard":keyboard}, ensure_ascii=False)
    return tg("sendMessage", d)

def edit(chat,msg,text,keyboard=None):
    d={"chat_id":chat,"message_id":msg,"text":text,"parse_mode":"HTML"}
    if keyboard is not None: d["reply_markup"]=json.dumps({"inline_keyboard":keyboard}, ensure_ascii=False)
    try: return tg("editMessageText", d)
    except Exception: return send(chat,text,keyboard)

def answer(cid,text=""):
    try: tg("answerCallbackQuery",{"callback_query_id":cid,"text":text})
    except Exception: pass

def esc(s):
    return str(s).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def run(cmd, timeout=20):
    try:
        p=subprocess.run(cmd,shell=True,text=True,capture_output=True,timeout=timeout,cwd=str(BASE))
        out=(p.stdout+p.stderr).strip()
        return p.returncode,out[-5000:]
    except subprocess.TimeoutExpired:
        return 124,"Tiempo de espera agotado."
    except Exception as e:
        return 1,str(e)

def service(name):
    rc,_=run(f"systemctl is-active --quiet {sh(name)}")
    return "🟢 ACTIVO" if rc==0 else "🔴 INACTIVO"

def sh(s):
    import shlex
    return shlex.quote(s)

def menu_main():
    return [
      [{"text":"👤 Usuarios","callback_data":"users"},{"text":"🌐 Protocolos","callback_data":"protocols"}],
      [{"text":"📊 Estado VPS","callback_data":"status"},{"text":"🛠 Herramientas","callback_data":"tools"}],
      [{"text":"🔄 Servicios","callback_data":"services"},{"text":"ℹ️ Información","callback_data":"info"}],
    ]

def menu_users():
    return [
      [{"text":"➕ Crear","callback_data":"u_create"},{"text":"🗑 Eliminar","callback_data":"u_delete"}],
      [{"text":"📋 Lista","callback_data":"u_list"},{"text":"🟢 Online","callback_data":"u_online"}],
      [{"text":"🔄 Renovar","callback_data":"u_renew"},{"text":"🔒 Bloquear","callback_data":"u_block"}],
      [{"text":"🔓 Desbloquear","callback_data":"u_unblock"},{"text":"💾 Backup","callback_data":"u_backup"}],
      [{"text":"🔙 Volver","callback_data":"home"}]
    ]

def menu_protocols():
    return [
      [{"text":"🔐 OpenSSH","callback_data":"p_ssh"},{"text":"🟡 Dropbear","callback_data":"p_dropbear"}],
      [{"text":"🔵 OpenVPN","callback_data":"p_openvpn"},{"text":"🟣 V2Ray/Xray","callback_data":"p_v2ray"}],
      [{"text":"🔎 CheckUser","callback_data":"p_checkuser"},{"text":"🐌 SlowDNS","callback_data":"p_slowdns"}],
      [{"text":"🔒 SSL/WebSocket","callback_data":"p_ssl"},{"text":"🚀 BadVPN","callback_data":"p_badvpn"}],
      [{"text":"📡 UDP Custom","callback_data":"p_udp"},{"text":"📡 ZiVPN","callback_data":"p_zivpn"}],
      [{"text":"🔙 Volver","callback_data":"home"}]
    ]

def menu_tools():
    return [
      [{"text":"🔥 Firewall","callback_data":"t_firewall"},{"text":"⚡ Reiniciar servicios","callback_data":"t_restart"}],
      [{"text":"🚀 Optimizar","callback_data":"t_opt"},{"text":"📈 Speedtest","callback_data":"t_speed"}],
      [{"text":"🔎 Scanner","callback_data":"t_scan"},{"text":"🔄 Actualizar","callback_data":"t_update"}],
      [{"text":"🔙 Volver","callback_data":"home"}]
    ]

def menu_services():
    return [
      [{"text":"🔐 SSH","callback_data":"s_ssh"},{"text":"🟡 Dropbear","callback_data":"s_dropbear"}],
      [{"text":"🔵 OpenVPN","callback_data":"s_openvpn"},{"text":"🟣 Xray","callback_data":"s_xray"}],
      [{"text":"🔎 CheckUser","callback_data":"s_checkuser"},{"text":"🐌 SlowDNS","callback_data":"s_slowdns"}],
      [{"text":"🔙 Volver","callback_data":"home"}]
    ]

def status():
    _,up=run("uptime -p")
    _,load=run("awk '{print $1\", \"$2\", \"$3}' /proc/loadavg")
    _,mem=run("free -m | awk '/^Mem:/ {printf \"%d/%d MB (%d%%)\",$3,$2,($3*100)/$2}'")
    _,disk=run("df -h / | awk 'NR==2 {print $3\"/\"$2\" (\"$5\")\"}'")
    return f"""📊 <b>KEVINTECH VPS</b>

🖥 Host: <code>{esc(subprocess.getoutput("hostname"))}</code>
⏱ Uptime: <code>{esc(up)}</code>
⚙️ Load: <code>{esc(load)}</code>
🧠 RAM: <code>{esc(mem)}</code>
💾 Disco: <code>{esc(disk)}</code>

🔐 SSH: {service("ssh")}
🟡 Dropbear: {service("dropbear")}
🔵 OpenVPN: {service("openvpn")}
🟣 Xray: {service("xray")}
🔎 CheckUser: {service("checkuser")}
🐌 SlowDNS: {service("slowdns")}
📡 ZiVPN: {service("zivpn")}"""

def users():
    rc,out=run("awk -F: '$3>=1000 && $1!=\"nobody\" {print $1}' /etc/passwd")
    if rc: return "❌ No se pudo leer la lista."
    arr=[x for x in out.splitlines() if x]
    if not arr: return "📋 <b>Usuarios</b>\n\nNo hay usuarios normales."
    lines=[]
    for u in arr:
        _,exp=run(f"chage -l {sh(u)} 2>/dev/null | awk -F': ' '/Account expires/ {{print $2}}'")
        lines.append(f"• <code>{esc(u)}</code> — {esc(exp or 'N/D')}")
    return "📋 <b>USUARIOS DEL VPS</b>\n\n"+"\n".join(lines[:80])

def online():
    rc,out=run("who")
    if not out: return "🟢 <b>USUARIOS ONLINE</b>\n\nNadie conectado."
    return "🟢 <b>USUARIOS ONLINE</b>\n\n<pre>"+esc(out[-4500:])+"</pre>"

def module_path(name):
    candidates=[BASE/"usuarios"/name,BASE/"protocolos"/name,BASE/"herramientas"/name,BASE/name]
    for p in candidates:
        if p.is_file(): return p
    return None

def execute_module(name, args=""):
    p=module_path(name)
    if not p: return f"⚠️ Módulo <code>{esc(name)}</code> no encontrado."
    # Only call known project modules; they may still be interactive.
    rc,out=run(f"bash {sh(str(p))} {args}",45)
    if not out: out="Módulo ejecutado sin salida."
    return f"🧩 <b>{esc(name)}</b>\n\n<pre>{esc(out)}</pre>"

def create_user(chat):
    STATE[chat]={"flow":"create","step":"username","data":{}}
    send(chat,"➕ <b>CREAR USUARIO</b>\n\nEscribe el nombre del usuario:")

def handle_text(chat,text):
    if not str(chat).isdigit() or int(chat) not in ALLOWED: return
    st=STATE.get(chat)
    if not st:
        if text in ("/start","/menu"):
            send(chat,"🤖 <b>KEVINTECH MULTI SCRIPT</b>\n\nPanel de administración:","")
            # edit/send without malformed empty keyboard
            send(chat,"Selecciona una sección:",menu_main())
        elif text=="/id": send(chat,f"🆔 ID: <code>{chat}</code>")
        return
    flow,step,data=st["flow"],st["step"],st["data"]
    if flow=="create":
        if step=="username":
            if not re.fullmatch(r"[a-z_][a-z0-9_-]{2,31}",text,re.I):
                return send(chat,"❌ Nombre inválido. Usa 3–32 caracteres alfanuméricos, _ o -.")
            data["u"]=text; st["step"]="password"
            return send(chat,"🔑 Escribe la contraseña:")
        if step=="password":
            if len(text)<4: return send(chat,"❌ Contraseña demasiado corta.")
            data["p"]=text; st["step"]="days"
            return send(chat,"📅 ¿Cuántos días? Escribe un número, por ejemplo <code>30</code>:")
        if step=="days":
            if not text.isdigit() or not 1<=int(text)<=3650: return send(chat,"❌ Días inválidos.")
            data["days"]=int(text); st["step"]="limit"
            return send(chat,"👥 Límite de conexiones. Escribe <code>0</code> para ilimitado:")
        if step=="limit":
            if not text.isdigit() or int(text)>1000: return send(chat,"❌ Límite inválido.")
            data["limit"]=int(text)
            u,p,d,l=data["u"],data["p"],data["days"],data["limit"]
            STATE[chat]["flow"]="confirm"
            return send(chat,f"📝 <b>CONFIRMAR</b>\n\n👤 Usuario: <code>{esc(u)}</code>\n🔑 Contraseña: <code>{esc(p)}</code>\n📅 Días: <code>{d}</code>\n👥 Límite: <code>{l}</code>",[[{"text":"✅ CREAR","callback_data":"u_confirm_create"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
    if flow=="renew":
        if step=="username":
            if not re.fullmatch(r"[a-z_][a-z0-9_-]{2,31}",text,re.I): return send(chat,"❌ Usuario inválido.")
            data["u"]=text; st["step"]="days"
            return send(chat,"📅 Días a renovar:")
        if step=="days":
            if not text.isdigit() or not 1<=int(text)<=3650: return send(chat,"❌ Días inválidos.")
            u,d=data["u"],int(text)
            rc,out=run(f"chage -d $(date +%Y-%m-%d) -E $(date -d '+{d} days' +%Y-%m-%d) {sh(u)}")
            STATE.pop(chat,None)
            return send(chat,("✅ Renovado." if rc==0 else "❌ Error.")+f"\n\n<pre>{esc(out)}</pre>",menu_users())

def callback(chat,msg,uid,data):
    answer(msg)
    if uid not in ALLOWED: return
    if data=="home": return edit(chat,msg,"🏠 <b>KEVINTECH MULTI SCRIPT</b>\n\nSelecciona una sección:",menu_main())
    if data=="users": return edit(chat,msg,"👤 <b>GESTIÓN DE USUARIOS</b>",menu_users())
    if data=="protocols": return edit(chat,msg,"🌐 <b>PROTOCOLOS</b>",menu_protocols())
    if data=="tools": return edit(chat,msg,"🛠 <b>HERRAMIENTAS</b>",menu_tools())
    if data=="services": return edit(chat,msg,status(),menu_services())
    if data=="status": return edit(chat,msg,status(),menu_main())
    if data=="info": return edit(chat,msg,"🤖 <b>KEVINTECH TELEGRAM</b>\n\nBot integrado en Multi Script.\n\n🔐 Acceso por Telegram ID.\n⚙️ Servicio systemd.",menu_main())
    if data=="cancel":
        STATE.pop(chat,None); return edit(chat,msg,"❌ Operación cancelada.",menu_users())
    if data=="u_create": return create_user(chat)
    if data=="u_list": return edit(chat,msg,users(),menu_users())
    if data=="u_online": return edit(chat,msg,online(),menu_users())
    if data=="u_renew":
        STATE[chat]={"flow":"renew","step":"username","data":{}}
        return send(chat,"🔄 <b>RENOVAR</b>\n\nEscribe el usuario:")
    if data=="u_confirm_create":
        st=STATE.pop(chat,None)
        if not st: return send(chat,"❌ Sesión expirada.",menu_users())
        d=st["data"]; u,p,days,limit=d["u"],d["p"],d["days"],d["limit"]
        # Native Linux user creation; keeps compatibility with the project's SSH users.
        rc,out=run(f"id {sh(u)} >/dev/null 2>&1 && echo EXISTS || true")
        if "EXISTS" in out: return send(chat,"❌ El usuario ya existe.",menu_users())
        cmd=f"useradd -m -s /bin/bash {sh(u)} && echo {sh(u+':'+p)} | chpasswd && chage -E $(date -d '+{days} days' +%Y-%m-%d) {sh(u)}"
        rc,out=run(cmd)
        if rc==0 and limit>0:
            # Store limit as a project-local metadata file; does not alter SSH daemon configuration.
            meta=BASE/"telegram"/"user_limits"
            meta.mkdir(parents=True,exist_ok=True)
            (meta/u).write_text(str(limit))
        return send(chat,("✅ <b>Usuario creado</b>" if rc==0 else "❌ <b>No se pudo crear</b>")+f"\n\n<pre>{esc(out)}</pre>",menu_users())
    if data in ("u_delete","u_block","u_unblock"):
        STATE[chat]={"flow":data,"step":"username","data":{}}
        labels={"u_delete":"eliminar","u_block":"bloquear","u_unblock":"desbloquear"}
        return send(chat,f"Escribe el usuario a {labels[data]}:")
    if data=="u_backup":
        return edit(chat,msg,execute_module("backup.sh"),menu_users())
    if data.startswith("p_"):
        mp={"p_ssh":"openssh.sh","p_dropbear":"dropbear.sh","p_openvpn":"openvpn.sh","p_v2ray":"v2ray.sh","p_checkuser":"checkuser.sh","p_slowdns":"slowdns.sh","p_ssl":"ssl.sh","p_badvpn":"badvpn.sh","p_udp":"udpcustom.sh","p_zivpn":"zivpn.sh"}
        return edit(chat,msg,execute_module(mp[data]),menu_protocols())
    if data.startswith("t_"):
        mp={"t_firewall":"firewall.sh","t_restart":"reiniciar.sh","t_opt":"optimizar.sh","t_speed":"speedtest.sh","t_scan":"scanner.sh","t_update":"update.sh"}
        return edit(chat,msg,execute_module(mp[data]),menu_tools())
    if data.startswith("s_"):
        mp={"s_ssh":"ssh","s_dropbear":"dropbear","s_openvpn":"openvpn","s_xray":"xray","s_checkuser":"checkuser","s_slowdns":"slowdns"}
        svc=mp[data]
        return edit(chat,msg,f"🔄 <b>{svc}</b>\n\nEstado: {service(svc)}",menu_services())

def process(update):
    if "callback_query" in update:
        q=update["callback_query"]; m=q.get("message",{}); return callback(m["chat"]["id"],q["id"],q["from"]["id"],q["data"])
    m=update.get("message")
    if not m: return
    uid=m.get("from",{}).get("id"); chat=m["chat"]["id"]; text=m.get("text","")
    if uid not in ALLOWED:
        send(chat,"⛔ <b>Acceso denegado.</b>")
        return
    handle_text(chat,text)

def main():
    LOG.parent.mkdir(parents=True,exist_ok=True)
    LOG.touch(); LOG.chmod(0o600)
    try:
        r=tg("getMe")
        if not r.get("ok"): raise SystemExit("Telegram API rejected the token")
    except Exception as e:
        log("Startup Telegram error: "+str(e)); raise
    # Start from latest update on first boot.
    if OFFSET_FILE.exists():
        try: offset=int(OFFSET_FILE.read_text().strip())
        except: offset=0
    else:
        r=tg("getUpdates",{"timeout":0,"limit":1})
        res=r.get("result",[])
        offset=(res[-1]["update_id"]+1) if res else 0
    log("Bot online")
    while True:
        try:
            r=tg("getUpdates",{"offset":offset,"timeout":30,"allowed_updates":json.dumps(["message","callback_query"])})
            for u in r.get("result",[]):
                offset=u["update_id"]+1
                OFFSET_FILE.write_text(str(offset))
                try: process(u)
                except Exception as e: log("Update error: "+repr(e))
        except Exception as e:
            log("Polling error: "+repr(e)); time.sleep(5)

if __name__=="__main__":
    main()
