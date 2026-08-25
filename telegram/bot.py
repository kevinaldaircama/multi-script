#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KEVINTECH TELEGRAM BOT - FAST / FULL UI
Integrado con /etc/kevintech.

Las operaciones rápidas no llaman scripts interactivos.
Las instalaciones/desinstalaciones se ejecutan en segundo plano para que
Telegram no quede bloqueado mientras apt/curl/systemd trabajan.
"""
import json, os, re, shlex, subprocess, time, urllib.parse, urllib.request, threading
from pathlib import Path

BASE=Path("/etc/kevintech")
DIR=BASE/"telegram"
ENV=DIR/".env"
LOG=DIR/"logs"/"bot.log"
OFFSET=DIR/"offset"
API=""
ALLOWED=set()
STATES={}
LOCK=threading.Lock()

def log(x):
    LOG.parent.mkdir(parents=True,exist_ok=True)
    with LOG.open("a",encoding="utf-8") as f:
        f.write(time.strftime("[%F %T] ")+str(x)+"\n")

def load():
    global API,ALLOWED
    vals={}
    for line in ENV.read_text(errors="ignore").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k,v=line.split("=",1); vals[k.strip()]=v.strip().strip('"').strip("'")
    tok=vals.get("BOT_TOKEN",""); owner=vals.get("ADMIN_ID","")
    if not re.fullmatch(r"\d+:[A-Za-z0-9_-]+",tok): raise SystemExit("BOT_TOKEN inválido")
    if not owner.isdigit(): raise SystemExit("ADMIN_ID inválido")
    ALLOWED={int(owner)}
    for x in vals.get("ADMIN_IDS","").split(","):
        if x.strip().isdigit(): ALLOWED.add(int(x.strip()))
    API="https://api.telegram.org/bot"+tok

def tg(method,data=None):
    body=urllib.parse.urlencode(data or {}).encode()
    req=urllib.request.Request(API+"/"+method,data=body)
    with urllib.request.urlopen(req,timeout=45) as r: result=json.loads(r.read().decode())
    if not result.get("ok"): raise RuntimeError(result)
    return result

def esc(x): return str(x).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def send(chat,text,kb=None):
    d={"chat_id":str(chat),"text":text,"parse_mode":"HTML","disable_web_page_preview":"true"}
    if kb: d["reply_markup"]=json.dumps({"inline_keyboard":kb},ensure_ascii=False)
    return tg("sendMessage",d)

def edit(chat,msg,text,kb=None):
    d={"chat_id":str(chat),"message_id":str(msg),"text":text,"parse_mode":"HTML","disable_web_page_preview":"true"}
    if kb: d["reply_markup"]=json.dumps({"inline_keyboard":kb},ensure_ascii=False)
    try: return tg("editMessageText",d)
    except: return send(chat,text,kb)

def answer(cid,text=""):
    try: tg("answerCallbackQuery",{"callback_query_id":cid,"text":text})
    except: pass

def run(cmd,timeout=10,input_data=None):
    try:
        p=subprocess.run(cmd,shell=True,text=True,input=input_data,capture_output=True,timeout=timeout)
        return p.returncode,(p.stdout+p.stderr).strip()
    except subprocess.TimeoutExpired:
        return 124,"Tiempo de espera agotado."
    except Exception as e: return 1,str(e)

def q(x): return shlex.quote(str(x))

def async_script(chat,title,script,stdin="1\n",timeout=180,kb=None):
    send(chat,f"⏳ <b>{esc(title)}</b>\n\nLa operación se está ejecutando en segundo plano.\nTe enviaré el resultado al terminar.")
    def worker():
        rc,out=run(f"bash {q(script)}",timeout,stdin)
        if len(out)>5000: out=out[-5000:]
        icon="✅" if rc==0 else "❌"
        send(chat,f"{icon} <b>{esc(title)}</b>\n\n<pre>{esc(out or 'Operación terminada sin salida.')}</pre>",kb)
    threading.Thread(target=worker,daemon=True).start()

def service_state(s):
    rc,_=run(f"systemctl is-active --quiet {q(s)}",3)
    return "🟢 ACTIVO" if rc==0 else "🔴 INACTIVO"

def port_lines(names):
    wanted="|".join(re.escape(x) for x in names)
    rc,out=run(f"ss -lntup 2>/dev/null | grep -Ei '{wanted}' || true",4)
    return out

def listening_ports(pattern):
    rc,out=run(f"ss -lntup 2>/dev/null | grep -Ei {q(pattern)} || true",4)
    ports=[]
    for line in out.splitlines():
        m=re.search(r'(?::|\\])(\d+)\s',line)
        if m and m.group(1) not in ports: ports.append(m.group(1))
    return ",".join(ports) if ports else "—"

def exists_service(s):
    rc,_=run(f"systemctl cat {q(s)} >/dev/null 2>&1",3)
    return rc==0

def module(name):
    for p in (BASE/"protocolos"/name,BASE/"herramientas"/name,BASE/"usuarios"/name,BASE/name):
        if p.is_file(): return p
    return None

def installed_protocol(key):
    checks={
      "ssh": exists_service("ssh") or Path("/usr/sbin/sshd").exists(),
      "dropbear": exists_service("dropbear") or Path("/usr/sbin/dropbear").exists(),
      "openvpn": exists_service("openvpn-server@server") or Path("/etc/openvpn/server/server.conf").exists(),
      "xray": exists_service("xray") or Path("/usr/local/bin/xray").exists(),
      "checkuser": exists_service("checkuser") or Path("/etc/systemd/system/checkuser.service").exists(),
      "slowdns": exists_service("dnstt") or Path("/etc/slowdns").exists(),
      "zivpn": exists_service("zivpn") or Path("/etc/zivpn").exists(),
      "badvpn": exists_service("badvpn-7300") or exists_service("badvpn-7200") or Path("/usr/local/bin/badvpn-udpgw").exists(),
      "ssl": exists_service("haproxy") and (Path("/etc/haproxy").exists() or True),
      "udp": exists_service("udp-custom") or Path("/usr/local/bin/udp-custom").exists(),
    }
    return checks.get(key,False)

PROTO={
 "ssh":{"name":"OpenSSH","file":"openssh.sh","svc":"ssh","ports":"22","install":"1","uninstall":"5"},
 "dropbear":{"name":"Dropbear","file":"dropbear.sh","svc":"dropbear","ports":"90,143,109","install":"1","uninstall":"6"},
 "openvpn":{"name":"OpenVPN","file":"openvpn.sh","svc":"openvpn-server@server","ports":"1194/UDP,2200/TCP,443/TCP","install":"1","uninstall":"10"},
 "xray":{"name":"V2Ray / Xray","file":"v2ray.sh","svc":"xray","ports":"10002 + configuración del proyecto","install":"1","uninstall":"13"},
 "checkuser":{"name":"CheckUser","file":"checkuser.sh","svc":"checkuser","ports":"10016/TCP,10015/TCP,8888/TCP","install":"1","uninstall":"8"},
 "slowdns":{"name":"SlowDNS","file":"slowdns.sh","svc":"dnstt","ports":"5300/UDP","install":"1","uninstall":"7"},
 "zivpn":{"name":"ZiVPN","file":"zivpn.sh","svc":"zivpn","ports":"20000-29999/UDP","install":"1","uninstall":"10"},
 "badvpn":{"name":"BadVPN","file":"badvpn.sh","svc":"badvpn-7300","ports":"7300,7200","install":"1","uninstall":"4"},
 "ssl":{"name":"SSL Tunnel / WebSocket","file":"ssl.sh","svc":"haproxy","ports":"80,443,8080","install":"1","uninstall":"6"},
 "udp":{"name":"UDP Custom","file":"udpcustom.sh","svc":"udp-custom","ports":"configurado por el módulo","install":"1","uninstall":"7"},
}

def proto_kb():
    rows=[]
    for k in PROTO:
        rows.append([{"text":PROTO[k]["name"],"callback_data":"proto:"+k}])
    return rows+[ [{"text":"🔙 Volver","callback_data":"home"}] ]

def proto_detail(k):
    p=PROTO[k]; inst=installed_protocol(k)
    state="🟢 INSTALADO / ACTIVO" if inst and service_state(p["svc"])=="🟢 ACTIVO" else ("🟡 INSTALADO / DETENIDO" if inst else "⚪ NO INSTALADO")
    actual=listening_ports(p["svc"].replace("@","|")) if inst else "—"
    text=f"""🌐 <b>{esc(p["name"])}</b>

Estado: {state}
Puertos del módulo: <code>{esc(p["ports"])}</code>
Puertos escuchando ahora: <code>{esc(actual)}</code>
Servicio: <code>{esc(p["svc"])}</code>

Selecciona una acción:"""
    actions=[]
    if inst:
        actions.append([{"text":"🔄 Reiniciar","callback_data":"restart:"+k},{"text":"🗑️ Desinstalar","callback_data":"uninstall:"+k}])
    else:
        actions.append([{"text":"🚀 Instalar","callback_data":"install:"+k}])
    actions += [[{"text":"📊 Actualizar estado","callback_data":"proto:"+k}],
                [{"text":"🔙 Protocolos","callback_data":"protocols"}]]
    return text,actions

def users_kb():
    return [
      [{"text":"➕ Crear cuenta","callback_data":"u_create"},{"text":"♻️ Renovar","callback_data":"u_renew"}],
      [{"text":"📋 Lista","callback_data":"u_list"},{"text":"🟢 Online","callback_data":"u_online"}],
      [{"text":"🗑️ Eliminar","callback_data":"u_delete"},{"text":"🔑 Cambiar clave","callback_data":"u_pass"}],
      [{"text":"🔒 Bloquear","callback_data":"u_block"},{"text":"🔓 Desbloquear","callback_data":"u_unblock"}],
      [{"text":"💾 Backup","callback_data":"u_backup"},{"text":"🔙 Volver","callback_data":"home"}]
    ]

def tools_kb():
    return [
      [{"text":"🔥 Firewall","callback_data":"tool:firewall"},{"text":"🚀 Optimizar","callback_data":"tool:optimizar"}],
      [{"text":"🚫 Block Ads","callback_data":"tool:ads"},{"text":"🚫 Block Torrent","callback_data":"tool:torrent"}],
      [{"text":"📈 Speedtest","callback_data":"tool:speed"},{"text":"🔎 Scanner","callback_data":"tool:scanner"}],
      [{"text":"📁 Archivos","callback_data":"tool:files"},{"text":"🔄 Actualizar","callback_data":"tool:update"}],
      [{"text":"🔧 Reiniciar servicios","callback_data":"tool:restart"},{"text":"🔙 Volver","callback_data":"home"}]
    ]

def services_kb():
    return [
      [{"text":"🔐 SSH","callback_data":"svc:ssh"},{"text":"🟡 Dropbear","callback_data":"svc:dropbear"}],
      [{"text":"🔵 OpenVPN","callback_data":"svc:openvpn"},{"text":"🟣 Xray","callback_data":"svc:xray"}],
      [{"text":"🔎 CheckUser","callback_data":"svc:checkuser"},{"text":"🐌 SlowDNS","callback_data":"svc:slowdns"}],
      [{"text":"🚀 ZiVPN","callback_data":"svc:zivpn"},{"text":"⚡ BadVPN","callback_data":"svc:badvpn"}],
      [{"text":"🔒 SSL/Haproxy","callback_data":"svc:ssl"},{"text":"📡 UDP Custom","callback_data":"svc:udp"}],
      [{"text":"🔙 Volver","callback_data":"home"}]
    ]

def info():
    cfg={}
    cf=BASE/"config.conf"
    if cf.is_file():
        for line in cf.read_text(errors="ignore").splitlines():
            m=re.match(r'\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)',line)
            if m: cfg[m.group(1)]=m.group(2).strip().strip('"').strip("'")
    ip=subprocess.getoutput("hostname -I").split()
    ip=ip[0] if ip else subprocess.getoutput("curl -4 -fsS --max-time 3 ifconfig.me")
    domain=cfg.get("SERVER_DOMAIN") or cfg.get("DOMAIN") or "No configurado"
    mem=subprocess.getoutput("free -m | awk '/^Mem:/ {printf \"%d/%d MB (%d%%)\",$3,$2,($3*100)/$2}'")
    disk=subprocess.getoutput("df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}'")
    load=subprocess.getoutput("awk '{print $1\", \"$2\", \"$3}' /proc/loadavg")
    lines=[]
    for k,p in PROTO.items():
        inst=installed_protocol(k)
        lines.append(f"{'🟢' if inst else '⚪'} {p['name']}: {'INSTALADO' if inst else 'NO INSTALADO'} — {p['ports']}")
    return f"""ℹ️ <b>KEVINTECH MULTI SCRIPT — INFORMACIÓN COMPLETA</b>

🖥 <b>Sistema</b>
• Host: <code>{esc(subprocess.getoutput("hostname"))}</code>
• OS: <code>{esc(subprocess.getoutput("lsb_release -ds 2>/dev/null") or "Ubuntu")}</code>
• Kernel: <code>{esc(subprocess.getoutput("uname -r"))}</code>
• Uptime: <code>{esc(subprocess.getoutput("uptime -p"))}</code>

🌐 <b>Red</b>
• IP: <code>{esc(ip)}</code>
• Dominio: <code>{esc(domain)}</code>
• HTTPS: <code>{'🟢 ACTIVO' if cfg.get('SSL','OFF')=='ON' else '⚪ Revisar configuración'}</code>

⚙️ <b>Recursos</b>
• RAM: <code>{esc(mem)}</code>
• Disco: <code>{esc(disk)}</code>
• Load: <code>{esc(load)}</code>
• CPU: <code>{esc(subprocess.getoutput("nproc"))} núcleos</code>

🌐 <b>PROTOCOLOS</b>
{chr(10).join("• "+x for x in lines)}

🔐 <b>Bot</b>
• Servicio: <code>kevintech-telegram</code>
• Autoarranque: <code>systemd</code>
• Base del proyecto: <code>/etc/kevintech</code>"""

def user_exists(u):
    return re.fullmatch(r"[a-z][a-z0-9_-]{2,31}",u,re.I) and run(f"id {q(u)} >/dev/null 2>&1",3)[0]==0

def users_list():
    rc,out=run("awk -F: '$3>=1000 && $1!=\"nobody\"{print $1}' /etc/passwd",5)
    if rc:return "❌ Error al obtener usuarios."
    arr=[x for x in out.splitlines() if x]
    if not arr:return "📋 <b>USUARIOS</b>\n\nNo hay usuarios."
    rows=[]
    for i,u in enumerate(arr,1):
        exp=subprocess.getoutput(f"chage -l {q(u)} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'")
        st=subprocess.getoutput(f"passwd -S {q(u)} 2>/dev/null | awk '{{print $2}}'")
        rows.append(f"{i:02d}. <code>{esc(u)}</code> — {esc(exp or 'N/D')} — {'🔒' if st=='L' else '🟢'}")
    return "📋 <b>USUARIOS REGISTRADOS</b>\n\n"+"\n".join(rows)+f"\n\n<b>Total:</b> {len(rows)}"

def online():
    out=subprocess.getoutput("who")
    return "🟢 <b>USUARIOS ONLINE</b>\n\n"+("<pre>"+esc(out)+"</pre>" if out else "No hay sesiones activas.")

def create_user(chat):
    STATES[chat]={"flow":"create","step":"user","data":{}}
    send(chat,"➕ <b>CREAR CUENTA</b>\n\nEscribe el usuario:")

def renew_user(chat):
    STATES[chat]={"flow":"renew","step":"user","data":{}}
    send(chat,"♻️ <b>RENOVAR CUENTA</b>\n\nEscribe el usuario:")

def account_text(user,password,days,limit,renew=False):
    ip=subprocess.getoutput("hostname -I").split(); ip=ip[0] if ip else "0.0.0.0"
    domain=""; cf=BASE/"config.conf"
    if cf.exists():
        m=re.search(r'^\s*SERVER_DOMAIN="?([^"\n]+)"?',cf.read_text(errors="ignore"),re.M)
        if m: domain=m.group(1)
    host=domain or ip
    exp=subprocess.getoutput(f"date -d '+{int(days)} days' '+%d/%m/%Y'")
    ssh=listening_ports("sshd"); drop=listening_ports("dropbear"); hap=listening_ports("haproxy")
    title="♻️ <b>CUENTA RENOVADA EXITOSAMENTE</b>" if renew else "🎉 <b>CUENTA CREADA EXITOSAMENTE</b>"
    pwdline=f"🔑 <b>Contraseña:</b> <code>{esc(password)}</code>\n" if password else "🔐 <b>Contraseña:</b> se mantiene la actual\n"
    return f"""{title}

👤 <b>Usuario:</b> <code>{esc(user)}</code>
{pwdline}📅 <b>Expira:</b> <code>{esc(exp)}</code>
👥 <b>Límite:</b> <code>{'Ilimitado' if int(limit)==0 else str(limit)+' conexión(es)'}</code>

🌐 <b>DATOS DEL SERVIDOR</b>
• Host/IP: <code>{esc(host)}</code>
• IP: <code>{esc(ip)}</code>
• SSH: <code>{esc(ssh)}</code>
• Dropbear: <code>{esc(drop)}</code>
• SSL/Haproxy: <code>{esc(hap)}</code>

📡 <b>DATOS DE CONEXIÓN</b>
<code>{esc(host)}:80@{esc(user)}:{esc(password or '********')}</code>
<code>{esc(host)}:443@{esc(user)}:{esc(password or '********')}</code>
<code>{esc(host)}:8080@{esc(user)}:{esc(password or '********')}</code>
<code>{esc(ip)}:1-65535@{esc(user)}:{esc(password or '********')}</code>"""

def do_create(chat,d):
    user,pwd,days,limit=d["user"],d["pass"],int(d["days"]),int(d["limit"])
    if user_exists(user): return send(chat,"❌ El usuario ya existe.",users_kb())
    exp=subprocess.getoutput(f"date -d '+{days} days' +%Y-%m-%d")
    rc,out=run(f"useradd -e {q(exp)} -M -s /usr/sbin/nologin {q(user)}",12)
    if rc:return send(chat,f"❌ No se pudo crear.\n<pre>{esc(out)}</pre>",users_kb())
    rc,out=run(f"printf '%s\\n' {q(user+':'+pwd)} | chpasswd",12)
    if rc:
        run(f"userdel -f {q(user)}",8)
        return send(chat,f"❌ No se pudo establecer contraseña.\n<pre>{esc(out)}</pre>",users_kb())
    lim=BASE/"limits"; lim.mkdir(parents=True,exist_ok=True); (lim/user).write_text(str(limit))
    send(chat,account_text(user,pwd,days,limit),users_kb())

def do_renew(chat,d):
    user=d["user"]; days=int(d["days"])
    exp=subprocess.getoutput(f"date -d '+{days} days' +%Y-%m-%d")
    rc,out=run(f"chage -E {q(exp)} {q(user)}",10)
    if rc:return send(chat,f"❌ No se pudo renovar.\n<pre>{esc(out)}</pre>",users_kb())
    oldpass=""; # Linux no permite recuperar la contraseña actual
    send(chat,account_text(user,None,days,0,True),users_kb())

def text_handler(chat,text):
    if chat not in ALLOWED:return send(chat,"⛔ <b>Acceso denegado.</b>")
    st=STATES.get(chat)
    if not st:
        if text in ("/start","/menu"): send(chat,"🤖 <b>KEVINTECH MULTI SCRIPT</b>\n\nPanel de administración:",main_kb())
        elif text=="/id":send(chat,f"🆔 <code>{chat}</code>")
        return
    flow,step,d=st["flow"],st["step"],st["data"]
    if flow=="create":
        if step=="user":
            if not re.fullmatch(r"[a-z][a-z0-9_-]{2,31}",text,re.I):return send(chat,"❌ Usuario inválido:")
            if user_exists(text):return send(chat,"❌ Ese usuario ya existe:")
            d["user"]=text;st["step"]="pass";return send(chat,"🔑 Contraseña:")
        if step=="pass":
            if len(text)<4:return send(chat,"❌ Contraseña demasiado corta.")
            d["pass"]=text;st["step"]="days";return send(chat,"📅 Días de duración:")
        if step=="days":
            if not text.isdigit() or int(text)<1:return send(chat,"❌ Días inválidos.")
            d["days"]=text;st["step"]="limit";return send(chat,"👥 Límite de conexiones (<code>0</code>=ilimitado):")
        if step=="limit":
            if not text.isdigit():return send(chat,"❌ Límite inválido.")
            d["limit"]=text;st["step"]="confirm"
            return send(chat,f"""📝 <b>CONFIRMAR</b>

👤 <code>{esc(d["user"])}</code>
🔑 <code>{esc(d["pass"])}</code>
📅 <code>{d["days"]} días</code>
👥 <code>{'Ilimitado' if d["limit"]=='0' else d["limit"]}</code>""",[[{"text":"✅ CREAR","callback_data":"confirm:create"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
    if flow=="renew":
        if step=="user":
            if not user_exists(text):return send(chat,"❌ Usuario no encontrado:")
            d["user"]=text;st["step"]="days"
            exp=subprocess.getoutput(f"chage -l {q(text)} | awk -F': ' '/Account expires/{{print $2}}'")
            return send(chat,f"♻️ Usuario <code>{esc(text)}</code>\nExpiración actual: <code>{esc(exp)}</code>\n\n📅 Días a renovar:")
        if step=="days":
            if not text.isdigit() or int(text)<1:return send(chat,"❌ Días inválidos.")
            d["days"]=text;st["step"]="confirm"
            return send(chat,f"♻️ <b>CONFIRMAR RENOVACIÓN</b>\n\n👤 <code>{esc(d['user'])}</code>\n📅 <code>{d['days']} días</code>",[[{"text":"✅ RENOVAR","callback_data":"confirm:renew"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])


def _handle_user_flow(chat, text, st):
    flow,step,d=st["flow"],st["step"],st["data"]
    if flow not in ("delete","pass","block","unblock"): return False
    if step=="user":
        user=text.strip()
        if not user_exists(user):
            send(chat,"❌ Usuario no encontrado. Escribe otro:"); return True
        d["user"]=user
        if flow=="pass":
            st["step"]="newpass"; send(chat,f"🔑 Nueva contraseña para <code>{esc(user)}</code>:"); return True
        st["step"]="confirm"
        label={"delete":"eliminar","block":"bloquear","unblock":"desbloquear"}[flow]
        send(chat,f"⚠️ ¿Confirmar {label} <code>{esc(user)}</code>?",[[{"text":"✅ CONFIRMAR","callback_data":"userop:"+flow},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
        return True
    if flow=="pass" and step=="newpass":
        if len(text)<4: send(chat,"❌ Contraseña demasiado corta."); return True
        d["pass"]=text;st["step"]="confirm"
        send(chat,f"🔑 ¿Cambiar contraseña de <code>{esc(d['user'])}</code>?",[[{"text":"✅ CAMBIAR","callback_data":"userop:pass"},{"text":"❌ CANCELAR","callback_data":"cancel"}]])
        return True
    return False

# Wrap original text handler with user-operation flow support.
_old_text_handler=text_handler
def text_handler(chat,text):
    if chat not in ALLOWED:return send(chat,"⛔ <b>Acceso denegado.</b>")
    st=STATES.get(chat)
    if st and _handle_user_flow(chat,text,st): return
    return _old_text_handler(chat,text)

_old_callback=callback
def callback(chat,msg,uid,cid,data):
    if data.startswith("userop:"):
        if int(uid) not in ALLOWED:return answer(cid,"⛔ Acceso denegado")
        answer(cid); st=STATES.pop(chat,None)
        if not st:return send(chat,"❌ Operación expirada.",users_kb())
        flow=st["flow"];d=st["data"];u=d["user"]
        if flow=="delete": rc,out=run(f"pkill -u {q(u)} >/dev/null 2>&1 || true; userdel -f {q(u)}",15)
        elif flow=="block": rc,out=run(f"passwd -l {q(u)}; pkill -u {q(u)} >/dev/null 2>&1 || true",15)
        elif flow=="unblock": rc,out=run(f"passwd -u {q(u)}",15)
        else: rc,out=run(f"printf '%s\\n' {q(u+':'+d['pass'])} | chpasswd",15)
        icon="✅" if rc==0 else "❌"
        label={"delete":"Cuenta eliminada","block":"Cuenta bloqueada","unblock":"Cuenta desbloqueada","pass":"Contraseña actualizada"}[flow]
        extra=f"\n🔑 Nueva contraseña: <code>{esc(d['pass'])}</code>" if flow=="pass" and rc==0 else ""
        return send(chat,f"{icon} <b>{label}</b>\n\n👤 <code>{esc(u)}</code>{extra}\n\n<pre>{esc(out)}</pre>",users_kb())
    return _old_callback(chat,msg,uid,cid,data)

def tool_action(chat,key):
    scripts={
      "ads":("Block Ads",module("blockads.sh"),"1\n"),
      "torrent":("Block Torrent",module("blocktorrent.sh"),"1\n"),
      "optimizar":("Optimizar VPS",module("optimizar.sh"),"1\n"),
      "speed":("Speedtest",module("speedtest.sh"),"1\n"),
      "scanner":("Scanner",module("scanner.sh"),"3\n"),
      "restart":("Reiniciar servicios",module("reiniciar.sh"),"1\n"),
      "update":("Actualizar Multi Script",module("update.sh"),"1\n"),
    }
    if key=="firewall":
        STATES[chat]={"flow":"firewall","step":"port","data":{}}
        return send(chat,"🔥 <b>FIREWALL</b>\n\nEscribe el puerto TCP/UDP que deseas abrir:")
    if key=="files":
        out=subprocess.getoutput("find /etc/kevintech -maxdepth 2 -type f -printf '%p\\n' | sort | head -100")
        return send(chat,"📁 <b>ARCHIVOS DEL PROYECTO</b>\n\n<pre>"+esc(out)+"</pre>",tools_kb())
    title,p,stdin=scripts[key]
    if not p:return send(chat,"❌ Módulo no encontrado.",tools_kb())
    async_script(chat,title,p,stdin,180,tools_kb())

def services_detail(k):
    mapping={"ssh":"ssh","dropbear":"dropbear","openvpn":"openvpn-server@server","xray":"xray","checkuser":"checkuser","slowdns":"dnstt","zivpn":"zivpn","badvpn":"badvpn-7300","ssl":"haproxy","udp":"udp-custom"}
    svc=mapping[k]
    state=service_state(svc)
    ports=listening_ports(svc.replace("@","|"))
    return f"🔄 <b>SERVICIO {esc(k.upper())}</b>\n\nEstado: {state}\nServicio: <code>{esc(svc)}</code>\nPuertos escuchando: <code>{esc(ports)}</code>",[[{"text":"🔄 Reiniciar","callback_data":"svc_restart:"+k},{"text":"📊 Actualizar","callback_data":"svc:"+k}],[{"text":"🔙 Servicios","callback_data":"services"}]]

def callback(chat,msg,uid,cid,data):
    if int(uid) not in ALLOWED:return answer(cid,"⛔ Acceso denegado")
    answer(cid)
    if data=="home":return edit(chat,msg,"🏠 <b>KEVINTECH MULTI SCRIPT</b>\n\nSelecciona:",main_kb())
    if data=="users":return edit(chat,msg,"👤 <b>USUARIOS</b>\n\nGestión completa:",users_kb())
    if data=="protocols":return edit(chat,msg,"🌐 <b>PROTOCOLOS</b>\n\nCada protocolo muestra estado, puertos e instalación/desinstalación:",proto_kb())
    if data=="tools":return edit(chat,msg,"🛠 <b>HERRAMIENTAS</b>",tools_kb())
    if data=="services":return edit(chat,msg,"🔄 <b>SERVICIOS DEL VPS</b>\n\nSelecciona un servicio:",services_kb())
    if data=="status":
        txt=info()
        return edit(chat,msg,txt,main_kb())
    if data=="info":return edit(chat,msg,info(),main_kb())
    if data=="cancel":STATES.pop(chat,None);return edit(chat,msg,"❌ Operación cancelada.",users_kb())

    if data=="u_create":return create_user(chat)
    if data=="u_renew":return renew_user(chat)
    if data=="u_list":return edit(chat,msg,users_list(),users_kb())
    if data=="u_online":return edit(chat,msg,online(),users_kb())
    if data in ("u_delete","u_pass","u_block","u_unblock"):
        STATES[chat]={"flow":data[2:],"step":"user","data":{}}
        labels={"u_delete":"eliminar","u_pass":"cambiar contraseña de","u_block":"bloquear","u_unblock":"desbloquear"}
        return send(chat,f"Escribe el usuario para {labels[data]}:")
    if data=="u_backup":
        backup=BASE/"usuarios"/"backup.sh"
        if not backup:return send(chat,"❌ Backup no encontrado.",users_kb())
        # Direct non-interactive backup of account metadata.
        dest=Path("/root/kevintech-backups");dest.mkdir(parents=True,exist_ok=True)
        stamp=time.strftime("%d-%m-%Y_%H-%M-%S"); arc=dest/f"backup_{stamp}.tar.gz"
        cmdline=f"tar -czf {q(arc)} /etc/passwd /etc/shadow /etc/group /etc/kevintech/limits 2>/dev/null"
        send(chat,"⏳ Creando backup...")
        def b():
            rc,out=run(cmdline,60)
            if rc==0:send(chat,f"💾 <b>BACKUP CREADO</b>\n\nArchivo: <code>{esc(arc)}</code>\nTamaño: <code>{esc(subprocess.getoutput(f'du -h {q(arc)} | cut -f1'))}</code>",users_kb())
            else:send(chat,f"❌ Backup falló.\n<pre>{esc(out)}</pre>",users_kb())
        threading.Thread(target=b,daemon=True).start();return

    if data.startswith("proto:"):
        k=data.split(":",1)[1];txt,kb=proto_detail(k);return edit(chat,msg,txt,kb)
    if data.startswith("install:") or data.startswith("uninstall:"):
        action,k=data.split(":",1);p=PROTO[k];f=module(p["file"])
        if not f:return send(chat,"❌ Script del protocolo no encontrado.",proto_detail(k)[1])
        stdin=p[action]+ "\n" if action=="uninstall" else p[action]+"\n"
        return async_script(chat,("Instalando " if action=="install" else "Desinstalando ")+p["name"],f,stdin,300,proto_detail(k)[1])
    if data.startswith("restart:"):
        k=data.split(":",1)[1];svc=PROTO[k]["svc"];send(chat,f"⏳ Reiniciando {esc(PROTO[k]['name'])}...")
        def rr():
            rc,out=run(f"systemctl restart {q(svc)}",20)
            send(chat,("✅ Reiniciado." if rc==0 else "❌ No se pudo reiniciar.")+f"\n\n<pre>{esc(out)}</pre>",proto_detail(k)[1])
        threading.Thread(target=rr,daemon=True).start();return

    if data.startswith("tool:"):return tool_action(chat,data.split(":",1)[1])
    if data.startswith("svc_restart:"):
        k=data.split(":",1)[1];mapping={"ssh":"ssh","dropbear":"dropbear","openvpn":"openvpn-server@server","xray":"xray","checkuser":"checkuser","slowdns":"dnstt","zivpn":"zivpn","badvpn":"badvpn-7300","ssl":"haproxy","udp":"udp-custom"};svc=mapping[k]
        send(chat,"⏳ Reiniciando...")
        def sr():
            rc,out=run(f"systemctl restart {q(svc)}",20);txt,kb=services_detail(k);send(chat,("✅ Servicio reiniciado." if rc==0 else "❌ Error.")+f"\n\n{txt}",kb)
        threading.Thread(target=sr,daemon=True).start();return
    if data.startswith("svc:"):
        txt,kb=services_detail(data.split(":",1)[1]);return edit(chat,msg,txt,kb)

    if data.startswith("confirm:"):
        action=data.split(":",1)[1];st=STATES.pop(chat,None)
        if not st:return send(chat,"❌ Operación expirada.",users_kb())
        d=st["data"]
        if action=="create":return do_create(chat,d)
        if action=="renew":return do_renew(chat,d)

    if data.startswith("confirm_user:"): return

def process(u):
    if "callback_query" in u:
        qy=u["callback_query"];m=qy["message"];callback(m["chat"]["id"],m["message_id"],qy["from"]["id"],qy["id"],qy["data"])
    elif "message" in u:
        m=u["message"];chat=m["chat"]["id"];uid=m.get("from",{}).get("id");text=m.get("text","")
        if uid in ALLOWED:text_handler(chat,text)
        else:send(chat,"⛔ <b>Acceso denegado.</b>")

def main():
    load();LOG.parent.mkdir(parents=True,exist_ok=True);LOG.touch();LOG.chmod(0o600)
    tg("deleteWebhook",{"drop_pending_updates":"false"})
    if OFFSET.exists():
        try:off=int(OFFSET.read_text())
        except:off=0
    else:
        r=tg("getUpdates",{"timeout":"0","limit":"1"});a=r.get("result",[]);off=a[-1]["update_id"]+1 if a else 0
    log("Bot online")
    while True:
        try:
            r=tg("getUpdates",{"offset":str(off),"timeout":"30","allowed_updates":json.dumps(["message","callback_query"])})
            for u in r.get("result",[]):
                off=u["update_id"]+1;OFFSET.write_text(str(off))
                try:process(u)
                except Exception as e:log("Update error: "+repr(e))
        except Exception as e:log("Polling error: "+repr(e));time.sleep(3)

if __name__=="__main__":main()
