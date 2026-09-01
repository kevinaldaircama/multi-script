#!/usr/bin/env python3
# KevinTech Telegram Bot - panel privado/publico + super admin
import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,urllib.error,shlex,tempfile
from pathlib import Path
BASE=Path('/etc/kevintech'); TD=BASE/'telegram'; ENV=TD/'.env'; LOG=TD/'logs'/'bot.log'; OFF=TD/'offset'
SET=TD/'settings.json'; ADMINS=TD/'admins.json'; BANS=TD/'bans.json'; QUOTAS=TD/'quotas.json'; MON=TD/'monetization.json'
API=''; OWNER=0; ADM=set(); STATE={}
DEFAULT_SETTINGS={'access':'private','domain':'','public_max_days':30,'public_max_devices':1,'admin_max_days':365,'admin_max_devices':10}
DEFAULT_MON={'monetag':{'enabled':False,'url':''},'miniapp':{'enabled':False,'url':''}}

def log(s):
 LOG.parent.mkdir(parents=True,exist_ok=True); LOG.open('a').write(time.strftime('[%F %T] ')+str(s)+'\n')
def load_json(p,default):
 try:
  x=json.loads(p.read_text(errors='ignore')); return x if isinstance(x,type(default)) else default
 except:return default
def save_json(p,x):
 p.parent.mkdir(parents=True,exist_ok=True); tmp=p.with_suffix(p.suffix+'.tmp'); tmp.write_text(json.dumps(x,ensure_ascii=False,indent=2)); os.replace(tmp,p); p.chmod(0o600)
def settings():
 x=load_json(SET,DEFAULT_SETTINGS.copy()); changed=False
 for k,v in DEFAULT_SETTINGS.items():
  if k not in x:x[k]=v;changed=True
 if changed:save_json(SET,x)
 return x
def env():
 d={}
 if not ENV.exists():raise SystemExit('No existe .env')
 for l in ENV.read_text(errors='ignore').splitlines():
  if '=' in l and not l.lstrip().startswith('#'):
   k,v=l.split('=',1);d[k]=v.strip().strip('"').strip("'")
 global API,OWNER,ADM
 t=d.get('BOT_TOKEN',''); a=d.get('ADMIN_ID','')
 if not re.fullmatch(r'\d+:[A-Za-z0-9_-]+',t) or not a.isdigit():raise SystemExit('Credenciales invalidas en .env')
 OWNER=int(a); ADM={OWNER}|{int(x) for x in d.get('ADMIN_IDS','').split(',') if x.strip().isdigit()}
 for x in load_json(ADMINS,{}).values():
  if isinstance(x,dict) and str(x.get('id','')).isdigit() and x.get('active',True):
   exp=x.get('expires')
   if exp and exp!='unlimited' and time.strftime('%Y-%m-%d')>exp:continue
   ADM.add(int(x['id']))
 API='https://api.telegram.org/bot'+t

def api(m,data=None,timeout=40):
 r=urllib.request.Request(API+'/'+m,data=urllib.parse.urlencode(data or {}).encode())
 with urllib.request.urlopen(r,timeout=timeout) as x:z=json.loads(x.read().decode())
 if not z.get('ok'):raise RuntimeError(z)
 return z
def api_json(m,data):return api(m,data)
def e(x):return str(x).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
def send(c,t,k=None):
 d={'chat_id':c,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true'}
 if k:d['reply_markup']=json.dumps({'inline_keyboard':k},ensure_ascii=False)
 return api('sendMessage',d)
def edit(c,m,t,k=None):
 try:return api('editMessageText',{'chat_id':c,'message_id':m,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true','reply_markup':json.dumps({'inline_keyboard':k},ensure_ascii=False) if k else None})
 except:return send(c,t,k)
def ans(i,t=''):
 try:api('answerCallbackQuery',{'callback_query_id':i,'text':t})
 except:pass
def sh(cmd,timeout=8,input=None):
 try:
  p=subprocess.run(cmd,shell=True,text=True,input=input,capture_output=True,timeout=timeout);return p.returncode,(p.stdout+p.stderr).strip()
 except subprocess.TimeoutExpired:return 124,'Timeout'
 except Exception as x:return 1,str(x)
def q(x):return shlex.quote(str(x))
def bg(c,title,cmd,timeout=300,k=None):
 send(c,f'⚡ <b>{e(title)}</b>\n\n🟡 Iniciado.\n')
 def w():
  rc,out=sh(cmd,timeout)
  if len(out)>4500:out=out[-4500:]
  send(c,('🟢' if rc==0 else '🔴')+f' <b>{e(title)}</b>\n\n<pre>{e(out or "Terminado sin salida")}</pre>',k)
 threading.Thread(target=w,daemon=True).start()
def multipart_send_document(c,path,caption=''):
 token=API.split('/bot',1)[1]; url=API+'/sendDocument'; boundary='----KevinTechBoundary'+str(int(time.time()*1000));
 data=[]
 data.append((f'--{boundary}\r\nContent-Disposition: form-data; name="chat_id"\r\n\r\n{c}\r\n').encode())
 if caption:data.append((f'--{boundary}\r\nContent-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n').encode())
 name=Path(path).name; body=Path(path).read_bytes()
 data.append((f'--{boundary}\r\nContent-Disposition: form-data; name="document"; filename="{name}"\r\nContent-Type: application/json\r\n\r\n').encode()+body+b'\r\n')
 data.append((f'--{boundary}--\r\n').encode()); req=urllib.request.Request(url,data=b''.join(data),headers={'Content-Type':f'multipart/form-data; boundary={boundary}'})
 with urllib.request.urlopen(req,timeout=60) as r:return json.loads(r.read().decode())
def download_document(file_id):
 z=api('getFile',{'file_id':file_id}); fp=z['result']['file_path']; token=API.split('/bot',1)[1]; url='https://api.telegram.org/file/bot'+token+'/'+fp
 dest=TD/'restore_tmp.json'; urllib.request.urlretrieve(url,dest); return dest

def admin_records():return load_json(ADMINS,{})
def is_owner(uid):return uid==OWNER
def is_admin(uid):
 if uid==OWNER:return True
 return uid in ADM
def is_banned(uid):return str(uid) in load_json(BANS,{})
def public_enabled():return settings().get('access')=='public'
def can_use(uid):return not is_banned(uid) and (is_admin(uid) or public_enabled())
def display_name(uid):
 r=admin_records().get(str(uid),{});return r.get('name') or str(uid)
def public_limit(uid):
 s=settings();return (s['admin_max_days'],s['admin_max_devices']) if is_admin(uid) else (s['public_max_days'],s['public_max_devices'])

def set_server_domain(value):
 value=value.strip()
 if not value or value.upper() in ('IP','AUTO'):
  ip=(subprocess.getoutput('curl -4 -fsS --max-time 4 ifconfig.me 2>/dev/null') or (subprocess.getoutput('hostname -I').split() or [''])[0]).strip()
  host=ip
  value=''
 else:
  host=value
 cfg=BASE/'config.conf'
 if cfg.exists():
  lines=cfg.read_text(errors='ignore').splitlines(); found=False; out=[]
  for line in lines:
   if line.startswith('SERVER_DOMAIN='):
    out.append('SERVER_DOMAIN='+json.dumps('' if value.upper() in ('','IP','AUTO') else value)); found=True
   elif line.startswith('SERVER_HOST='):
    out.append('SERVER_HOST='+json.dumps(host));
   else: out.append(line)
  if not found:out.append('SERVER_DOMAIN='+json.dumps('' if value.upper() in ('','IP','AUTO') else value))
  if not any(x.startswith('SERVER_HOST=') for x in lines):out.append('SERVER_HOST='+json.dumps(host))
  cfg.write_text('\n'.join(out)+'\n')

def domain_ip():
 ip=(subprocess.getoutput('curl -4 -fsS --max-time 4 ifconfig.me 2>/dev/null') or (subprocess.getoutput('hostname -I').split() or ['0.0.0.0'])[0]).strip(); dom=settings().get('domain','')
 if not dom and (BASE/'config.conf').exists():
  for l in (BASE/'config.conf').read_text(errors='ignore').splitlines():
   if l.startswith('SERVER_DOMAIN='):dom=l.split('=',1)[1].strip().strip('"').strip("'")
 return dom,ip

def home_for(uid):
 if is_admin(uid):
  return [[{'text':'👤 Usuarios','callback_data':'users'},{'text':'🌐 Protocolos','callback_data':'protocols'}],[{'text':'📊 Estado','callback_data':'status'},{'text':'🛠 Herramientas','callback_data':'tools'}],[{'text':'🔄 Servicios','callback_data':'services'},{'text':'⚙️ Ajustes','callback_data':'settings'}]]
 return [[{'text':'➕ Crear cuenta','callback_data':'create'},{'text':'🟢 Usuarios online','callback_data':'online'}],[{'text':'ℹ️ Servidor','callback_data':'info'}]]
USERS=[[{'text':'➕ Crear','callback_data':'create'},{'text':'♻️ Renovar','callback_data':'renew'}],[{'text':'📋 Lista','callback_data':'list'},{'text':'🟢 Online','callback_data':'online'}],[{'text':'🗑️ Eliminar','callback_data':'delete'},{'text':'🔑 Contraseña','callback_data':'passwd'}],[{'text':'🔒 Bloquear','callback_data':'block'},{'text':'🔓 Desbloquear','callback_data':'unblock'}],[{'text':'💾 Backup','callback_data':'backup'},{'text':'🔙 Inicio','callback_data':'home'}]]
TOOLS=[[{'text':'🔥 Firewall','callback_data':'tool:firewall'},{'text':'🚀 Optimizar','callback_data':'tool:optimizar'}],[{'text':'🚫 Ads','callback_data':'tool:ads'},{'text':'🚫 Torrent','callback_data':'tool:torrent'}],[{'text':'📈 Speedtest','callback_data':'tool:speed'},{'text':'🔎 Scanner','callback_data':'tool:scanner'}],[{'text':'📁 Archivos','callback_data':'tool:files'},{'text':'🔄 Actualizar','callback_data':'tool:update'}],[{'text':'🔙 Inicio','callback_data':'home'}]]
PROTO={'openssh':('OpenSSH','openssh.sh','ssh','22','1','5'),'dropbear':('Dropbear','dropbear.sh','dropbear','90,143,109','1','6'),'openvpn':('OpenVPN','openvpn.sh','openvpn','1194/UDP,2200/TCP,443/TCP','1','10'),'v2ray':('V2Ray/Xray','v2ray.sh','xray','443/TCP','1','13'),'checkuser':('CheckUser','checkuser.sh','checkuser','10016,10015,8888','1','8'),'slowdns':('SlowDNS','slowdns.sh','dnstt','5300/UDP','1','7'),'badvpn':('BadVPN','badvpn.sh','badvpn-7300','7300,7200','1','4'),'ssl':('SSL/WebSocket','ssl.sh','haproxy','80,443,8080,10015','1','6'),'udpcustom':('UDP Custom','udpcustom.sh','udp-custom','1-65535/UDP','1','7'),'zivpn':('ZiVPN','zivpn.sh','zivpn','20000-29999/UDP','1','10')}
PK=[[{'text':v[0],'callback_data':'proto:'+k}] for k,v in PROTO.items()]+[[{'text':'🔙 Inicio','callback_data':'home'}]]
SVCS={k:v[2] for k,v in PROTO.items()}; SVK=[[{'text':v[0],'callback_data':'svc:'+k}] for k,v in PROTO.items()]+[[{'text':'🔙 Inicio','callback_data':'home'}]]
def module(name):
 for p in [BASE/'protocolos'/name,BASE/'herramientas'/name,BASE/'usuarios'/name]:
  if p.exists():return p
 return None
def installed(k):
 paths={'openssh':['/usr/sbin/sshd'],'dropbear':['/usr/sbin/dropbear'],'openvpn':['/usr/sbin/openvpn','/etc/openvpn'],'v2ray':['/usr/local/bin/xray','/etc/xray'],'checkuser':['/etc/systemd/system/checkuser.service'],'slowdns':['/etc/slowdns'],'badvpn':['/usr/local/bin/badvpn-udpgw'],'ssl':['/usr/sbin/haproxy'],'udpcustom':['/usr/local/bin/udp-custom'],'zivpn':['/etc/zivpn']}
 if any(Path(x).exists() for x in paths.get(k,[])):return True
 return sh(f'systemctl cat {q(SVCS[k])} >/dev/null 2>&1',3)[0]==0
def info():
 dom,ip=domain_ip(); mem=subprocess.getoutput("free -m|awk '/^Mem:/{printf \"%d/%dMB (%d%%)\",$3,$2,$3*100/$2}");disk=subprocess.getoutput("df -h /|awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}'");load=subprocess.getoutput("awk '{print $1\", \"$2\", \"$3}' /proc/loadavg"); ps='\n'.join(('🟢' if installed(k) else '⚪')+f' {v[0]} — {v[3]}' for k,v in PROTO.items())
 return f'ℹ️ <b>KEVINTECH MULTI SCRIPT</b>\n\n🖥 <b>Servidor</b>\n• IP: <code>{e(ip)}</code>\n• Dominio: <code>{e(dom or "No configurado")}</code>\n• Host activo: <code>{e(dom or ip)}</code>\n• OS: <code>{e(subprocess.getoutput("lsb_release -ds 2>/dev/null") or "Ubuntu")}</code>\n• Kernel: <code>{e(subprocess.getoutput("uname -r"))}</code>\n• Uptime: <code>{e(subprocess.getoutput("uptime -p"))}</code>\n\n⚙️ <b>Recursos</b>\n• RAM: <code>{e(mem)}</code>\n• Disco: <code>{e(disk)}</code>\n• Load: <code>{e(load)}</code>\n• CPU: <code>{e(subprocess.getoutput("nproc"))} núcleos</code>\n\n🌐 <b>PROTOCOLOS</b>\n{ps}'
def userexists(u):return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',u,re.I)) and sh(f'id {q(u)} >/dev/null 2>&1',3)[0]==0
def userlist():
 _,o=sh("awk -F: '$3>=1000&&$1!=\"nobody\"{print $1}' /etc/passwd",4);a=o.splitlines();return '📋 <b>USUARIOS</b>\n\n'+('\n'.join(f'• <code>{e(x)}</code>' for x in a) if a else 'No hay usuarios.')+f'\n\nTotal: <b>{len(a)}</b>'
def online():return '🟢 <b>USUARIOS ONLINE</b>\n\n<pre>'+e(subprocess.getoutput('who') or 'Sin sesiones')+'</pre>'
def account(c,d,renew=False):
 u=d['user'];pw=d.get('pass');days=int(d['days']);exp=subprocess.getoutput(f"date -d '+{days} days' '+%d/%m/%Y'");dom,ip=domain_ip();host=dom or ip
 def ports(proc):
  out=subprocess.getoutput(f'ss -ltnp 2>/dev/null | grep -i {q(proc)} || true'); vals=[]
  for ln in out.splitlines():
   m=re.search(r':(\d+)\s',ln)
   if m and m.group(1) not in vals:vals.append(m.group(1))
  return ','.join(vals) if vals else 'No instalado'
 ssh=ports('sshd');drop=ports('dropbear');hap=ports('haproxy');bad=ports('badvpn');lim=e(d.get('limit','Ilimitado'))
 send(c,f'''<b>{'♻️ CUENTA RENOVADA EXITOSAMENTE' if renew else '🎉 CUENTA CREADA EXITOSAMENTE'}</b>\n\n━━━━━━━━━━━━━━━━━━━━\n👤 <b>DATOS</b>\n━━━━━━━━━━━━━━━━━━━━\n• Usuario: <code>{e(u)}</code>\n• Contraseña: <code>{e(pw or '********')}</code>\n• Expira: <code>{e(exp)}</code>\n• Duración: <code>{days} días</code>\n• Límite IP: <code>{lim}</code>\n\n━━━━━━━━━━━━━━━━━━━━\n🌐 <b>SERVIDOR</b>\n━━━━━━━━━━━━━━━━━━━━\n• Dominio: <code>{e(dom or 'No configurado')}</code>\n• IP: <code>{e(ip)}</code>\n• Host recomendado: <code>{e(host)}</code>\n• SSH: <code>{e(ssh)}</code>\n• Dropbear: <code>{e(drop)}</code>\n• SSL Tunnel: <code>{e(hap)}</code>\n• OpenVPN: <code>1194,2200,443</code>\n• BadVPN: <code>{e(bad)}</code>\n\n━━━━━━━━━━━━━━━━━━━━\n📡 <b>CONEXIONES</b>\n━━━━━━━━━━━━━━━━━━━━\n<code>{e(host)}:443@{e(u)}:{e(pw or '********')}</code>\n<code>{e(ip)}:443@{e(u)}:{e(pw or '********')}</code>\n<code>{e(host)}:80@{e(u)}:{e(pw or '********')}</code>\n<code>{e(ip)}:80@{e(u)}:{e(pw or '********')}</code>\n\n🚀 UDP CUSTOM\n<code>{e(host)}:1-65535@{e(u)}:{e(pw or '********')}</code>\n<code>{e(ip)}:1-65535@{e(u)}:{e(pw or '********')}</code>''',USERS if is_admin(c) else [[{'text':'➕ Crear otra','callback_data':'create'},{'text':'🟢 Online','callback_data':'online'}]])
def process_text(c,t):
 if is_banned(c):return send(c,'⛔ Tu ID está bloqueado.')
 if not can_use(c):return send(c,'⛔ Acceso privado. Solo administradores.')
 st=STATE.get(c)
 if not st:return
 f=st['f'];d=st['d'];step=st['s']
 if f in ('delete','block','unblock','passwd'):
  if step=='u':
   u=t.strip()
   if not userexists(u):return send(c,'❌ Usuario no encontrado. Escribe otro:')
   d['user']=u
   if f=='passwd':st['s']='p';return send(c,f'🔑 Nueva contraseña para <code>{e(u)}</code>:')
   st['s']='confirm';return send(c,f'⚠️ ¿Confirmar operación sobre <code>{e(u)}</code>?',[[{'text':'✅ CONFIRMAR','callback_data':'userop:'+f},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
  if f=='passwd' and step=='p':
   if len(t)<4:return send(c,'❌ Contraseña demasiado corta.')
   d['pass']=t;st['s']='confirm';return send(c,f'🔑 Confirmar cambio para <code>{e(d["user"])}</code>?',[[{'text':'✅ CAMBIAR','callback_data':'userop:passwd'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
 if f in ('create','renew'):
  if step=='u':
   t=t.strip()
   if not re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',t,re.I):return send(c,'❌ Usuario inválido. Usa 3-32 caracteres.')
   if not userexists(t) and f=='renew':return send(c,'❌ Usuario no encontrado.')
   if f=='create' and userexists(t):return send(c,'❌ Usuario ya existe.')
   d['user']=t;st['s']='p' if f=='create' else 'days';return send(c,'🔑 Contraseña:') if f=='create' else send(c,'📅 Días a renovar:')
  if f=='create' and step=='p':d['pass']=t;st['s']='days';return send(c,'📅 Días de duración:')
  if step=='days':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Número inválido.')
   maxd,maxdev=public_limit(c)
   if int(t)>maxd:return send(c,f'❌ Máximo permitido: <b>{maxd} días</b>.')
   d['days']=t;st['s']='limit' if f=='create' else 'confirm';return send(c,f'📱 Dispositivos/IP (máx. {maxdev}, 0=ilimitado):') if f=='create' else send(c,f'♻️ Confirmar renovación de <code>{e(d["user"])}</code> por <code>{t} días</code>?',[[{'text':'✅ RENOVAR','callback_data':'do:renew'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
  if f=='create' and step=='limit':
   maxd,maxdev=public_limit(c)
   if not t.isdigit() or int(t)<0:return send(c,'❌ Límite inválido.')
   if int(t)>maxdev:return send(c,f'❌ Máximo permitido: <b>{maxdev}</b> dispositivos.')
   d['limit']='Ilimitado' if t=='0' else t;st['s']='confirm';return send(c,f'📝 <b>CONFIRMAR</b>\n\n👤 <code>{e(d["user"])}</code>\n🔑 <code>{e(d["pass"])}</code>\n📅 <code>{d["days"]} días</code>\n📱 <code>{e(d["limit"])}</code>',[[{'text':'✅ CREAR','callback_data':'do:create'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
def settings_menu():
 s=settings();acc='🟢 PÚBLICO' if s['access']=='public' else '🔴 PRIVADO';return f'⚙️ <b>AJUSTES • SUPER ADMIN</b>\n\n🔐 Acceso: <b>{acc}</b>\n🌐 Dominio: <code>{e(s.get("domain") or "IP automática")}</code>\n\n📅 Cuota pública: <b>{s["public_max_days"]} días</b> / <b>{s["public_max_devices"]} dispositivos</b>\n📅 Cuota admin: <b>{s["admin_max_days"]} días</b> / <b>{s["admin_max_devices"]} dispositivos</b>',[[{'text':'🔐 Acceso','callback_data':'set:access'},{'text':'👑 Admin','callback_data':'set:admins'}],[{'text':'🌐 Dominio','callback_data':'set:domain'},{'text':'🚫 Ban','callback_data':'set:ban'}],[{'text':'♻️ Restauración','callback_data':'set:restore'},{'text':'💰 Monetización','callback_data':'set:money'}],[{'text':'🔄 Reiniciar VPS','callback_data':'set:reboot'}],[{'text':'📅 Cuotas','callback_data':'set:quota'}],[{'text':'🔙 Inicio','callback_data':'home'}]]
def admins_menu():
 r=admin_records(); lines=[]
 for k,v in r.items():
  if int(k)==OWNER:continue
  exp='Ilimitado' if v.get('expires') in ('unlimited',None,'') else v.get('expires'); lines.append(f'• <code>{e(k)}</code> — {e(v.get("name","Admin"))} — {e(exp)}')
 txt='👑 <b>ADMINISTRADORES</b>\n\n'+'\n'.join(lines) if lines else '👑 <b>ADMINISTRADORES</b>\n\nNo hay administradores adicionales.'
 return txt,[[{'text':'📋 Lista','callback_data':'admin:list'},{'text':'➕ Agregar','callback_data':'admin:add'}],[{'text':'🗑️ Quitar','callback_data':'admin:remove'},{'text':'✏️ Renombrar','callback_data':'admin:rename'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
def money_menu():
 m=load_json(MON,DEFAULT_MON.copy());a=m['monetag'];b=m['miniapp'];txt=f'💰 <b>MONETIZACIÓN</b>\n\nMonetag: <b>{"🟢 ACTIVO" if a.get('enabled') else "🔴 INACTIVO"}</b>\nURL: <code>{e(a.get('url') or "No configurada")}</code>\n\nMini App: <b>{"🟢 ACTIVO" if b.get('enabled') else "🔴 INACTIVO"}</b>\nURL: <code>{e(b.get('url') or "No configurada")}</code>'; rows=[[{'text':'Monetag','callback_data':'money:monetag'},{'text':'Mini App','callback_data':'money:miniapp'}]]; opens=[]; a.get('url') and opens.append({'text':'🌐 Abrir Monetag','url':a['url']}); b.get('url') and opens.append({'text':'📱 Abrir Mini App','url':b['url']});
 if opens:rows.append(opens)
 rows.append([{'text':'🔙 Ajustes','callback_data':'settings'}]);return txt,rows
def cb(c,m,u,i,x):
 if is_banned(u):return ans(i,'⛔ Bloqueado')
 if not can_use(u):return ans(i,'⛔ Acceso privado')
 ans(i,'⚡')
 if x=='home':return edit(c,m,'🏠 <b>KEVINTECH MULTI SCRIPT</b>',home_for(u))
 if x=='users' and is_admin(u):return edit(c,m,'👤 <b>GESTIÓN DE USUARIOS</b>',USERS)
 if x=='protocols' and is_admin(u):return edit(c,m,'🌐 <b>PROTOCOLOS</b>\n\nEstado + puertos + instalar/desinstalar:',PK)
 if x=='tools' and is_admin(u):return edit(c,m,'🛠 <b>HERRAMIENTAS</b>',TOOLS)
 if x in ('info','status'):return edit(c,m,info(),home_for(u))
 if x=='services' and is_admin(u):return edit(c,m,'🔄 <b>SERVICIOS</b>',SVK)
 if x=='create':STATE[c]={'f':'create','s':'u','d':{}};return send(c,'➕ <b>CREAR CUENTA</b>\n\nUsuario:')
 if x=='renew' and is_admin(u):STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR</b>\n\nUsuario:')
 if x=='list' and is_admin(u):return edit(c,m,userlist(),USERS)
 if x=='online':return edit(c,m,online(),USERS if is_admin(u) else home_for(u))
 if x in ('backup','backup:json') and is_admin(u):
  p=TD/'settings-backup.json';save_json(p,{'settings':settings(),'admins':admin_records(),'bans':load_json(BANS,{}),'quotas':{'public_max_days':settings()['public_max_days'],'public_max_devices':settings()['public_max_devices'],'admin_max_days':settings()['admin_max_days'],'admin_max_devices':settings()['admin_max_devices']},'monetization':load_json(MON,DEFAULT_MON.copy())});return multipart_send_document(c,p,'💾 Respaldo JSON de ajustes')
 if x=='cancel':STATE.pop(c,None);return send(c,'❌ Cancelado.',USERS if is_admin(u) else home_for(u))
 if x.startswith('do:'):
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.')
  d=st['d'];uu=d['user'];days=int(d['days']);exp=subprocess.getoutput(f"date -d '+{days} days' +%F")
  if x=='do:create':
   rc,o=sh(f'useradd -e {q(exp)} -M -s /usr/sbin/nologin {q(uu)} && printf "%s\\n" {q(uu+":"+d["pass"])} | chpasswd',12)
   if rc==0:(BASE/'limits').mkdir(exist_ok=True);(BASE/'limits'/uu).write_text('0' if d.get('limit')=='Ilimitado' else d.get('limit','0'));return account(c,d)
   return send(c,'🔴 <b>Error al crear</b>\n<pre>'+e(o)+'</pre>')
  rc,o=sh(f'chage -E {q(exp)} {q(uu)}',10);return account(c,d,True) if rc==0 else send(c,'🔴 <b>Error al renovar</b>\n<pre>'+e(o)+'</pre>')
 if x in ('delete','block','unblock','passwd') and is_admin(u):STATE[c]={'f':x,'s':'u','d':{}};return send(c,'👤 <b>USUARIO</b>\n\nEscribe el usuario:')
 if x.startswith('userop:') and is_admin(u):
  op=x.split(':',1)[1];st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.')
  uu=st['d']['user']
  if op=='delete':rc,o=sh(f'pkill -u {q(uu)} 2>/dev/null || true; userdel -r -f {q(uu)}',15)
  elif op=='block':rc,o=sh(f'passwd -l {q(uu)}; pkill -u {q(uu)} 2>/dev/null || true',15)
  elif op=='unblock':rc,o=sh(f'passwd -u {q(uu)}',15)
  else:rc,o=sh(f'printf "%s\\n" {q(uu+":"+st["d"]["pass"])} | chpasswd',15)
  return send(c,('🟢' if rc==0 else '🔴')+f' <b>Operación completada</b>\n\n<pre>{e(o or "OK")}</pre>',USERS)
 if x.startswith('proto:') and is_admin(u):
  k=x.split(':')[1];v=PROTO[k];ins=installed(k);buttons=[[{'text':'🔄 Reiniciar','callback_data':'svc_restart:'+k}]] if ins else [];buttons += [[{'text':'🗑️ Desinstalar','callback_data':'un:'+k}]] if ins else [[{'text':'🚀 Instalar','callback_data':'in:'+k}]];buttons += [[{'text':'🔙 Protocolos','callback_data':'protocols'}]];return edit(c,m,f'🌐 <b>{e(v[0])}</b>\n\nEstado: {"🟢 INSTALADO" if ins else "⚪ NO INSTALADO"}\nPuertos: <code>{e(v[3])}</code>\nServicio: <code>{e(v[2])}</code>',buttons)
 if x.startswith('in:') or x.startswith('un:'):
  if not is_admin(u):return ans(i,'Solo admin')
  k=x.split(':')[1];v=PROTO[k];p=module(v[1]);
  if not p:return send(c,'🔴 Script no encontrado.')
  return bg(c,('Instalando ' if x.startswith('in:') else 'Desinstalando ')+v[0],f'bash {q(p)} <<EOF\n{v[4] if x.startswith("in:") else v[5]}\nEOF',360,PK)
 if x.startswith('svc_restart:') and is_admin(u):return bg(c,'Reiniciando '+PROTO[x.split(':')[1]][0],f'systemctl restart {q(PROTO[x.split(":")[1]][2])}',30,SVK)
 if x.startswith('svc:') and is_admin(u):
  k=x.split(':')[1];s=SVCS[k];rc,_=sh(f'systemctl is-active --quiet {q(s)}',3);_,ports=sh(f"ss -lntup 2>/dev/null | grep -Ei {q(s)} || true",4);return edit(c,m,f'🔄 <b>{e(PROTO[k][0])}</b>\n\nEstado: {"🟢 ACTIVO" if rc==0 else "🔴 INACTIVO"}\nPuertos: <code>{e(ports or "—")}</code>',[[{'text':'🔄 Reiniciar','callback_data':'svc_restart:'+k},{'text':'📊 Actualizar','callback_data':'svc:'+k}],[{'text':'🔙 Servicios','callback_data':'services'}]])
 if x.startswith('tool:') and is_admin(u):
  k=x.split(':')[1];mp={'optimizar':'optimizar.sh','ads':'blockads.sh','torrent':'blocktorrent.sh','speed':'speedtest.sh','scanner':'scanner.sh','update':'update.sh'}
  if k=='files':return edit(c,m,'📁 <b>ARCHIVOS</b>\n\n<pre>'+e(subprocess.getoutput('find /etc/kevintech -maxdepth 2 -type f | sort | head -120'))+'</pre>',TOOLS)
  p=module(mp.get(k,''));return bg(c,k.title(),f'bash {q(p)}',180,TOOLS) if p else send(c,'🔴 Módulo no encontrado.')
 if x=='settings' and is_owner(u):
  t,k=settings_menu();return edit(c,m,t,k)
 if x=='set:access' and is_owner(u):
  s=settings();s['access']='public' if s['access']=='private' else 'private';save_json(SET,s);t,k=settings_menu();return edit(c,m,t,k)
 if x=='set:admins' and is_owner(u):t,k=admins_menu();return edit(c,m,t,k)
 if x=='admin:list' and is_owner(u):t,k=admins_menu();return edit(c,m,t,k)
 if x in ('admin:add','admin:remove','admin:rename') and is_owner(u):
  STATE[c]={'f':x,'s':'data','d':{}};return send(c,'👑 <b>ADMIN</b>\n\n'+('Escribe: ID | Nombre | DD/MM/AAAA o ilimitado' if x=='admin:add' else 'Escribe el ID' if x=='admin:remove' else 'Escribe: ID | Nuevo nombre'))
 if x=='set:domain' and is_owner(u):STATE[c]={'f':'domain','s':'data','d':{}};return send(c,'🌐 Escribe el dominio.\n\nUsa <code>IP</code> o déjalo vacío para usar automáticamente la IP del VPS:')
 if x=='set:ban' and is_owner(u):STATE[c]={'f':'ban','s':'data','d':{}};return send(c,'🚫 Escribe el Telegram ID que deseas bloquear:')
 if x=='set:restore' and is_owner(u):return edit(c,m,'♻️ <b>RESTAURACIÓN</b>\n\nRespalda o restaura la configuración mediante archivo JSON.',[[{'text':'💾 Respaldar JSON','callback_data':'backup:json'},{'text':'📥 Restaurar JSON','callback_data':'restore:json'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if x=='restore:json' and is_owner(u):STATE[c]={'f':'restore','s':'file','d':{}};return send(c,'♻️ Envíame ahora el archivo <b>JSON</b> de respaldo.')
 if x=='set:money' and is_owner(u):
  t,k=money_menu();return edit(c,m,t,k)
 if x.startswith('money:') and is_owner(u):
  k=x.split(':')[1];STATE[c]={'f':'money','s':'data','d':{'platform':k}};return send(c,f'💰 <b>{k.title()}</b>\n\nEscribe la URL de tu Mini App/plataforma. Se guardará para usarla desde el bot:')
 if x=='set:quota' and is_owner(u):STATE[c]={'f':'quota','s':'data','d':{}};return send(c,'📅 Cuotas actuales:\n\nEscribe: <code>public_days | public_devices | admin_days | admin_devices</code>')
 if x=='set:reboot' and is_owner(u):return send(c,'⚠️ ¿Reiniciar la VPS ahora?',[[{'text':'✅ REINICIAR','callback_data':'reboot:yes'},{'text':'❌ CANCELAR','callback_data':'settings'}]])
 if x=='reboot:yes' and is_owner(u):return bg(c,'Reiniciando VPS','sleep 2; reboot',20)
 if x.startswith('money:') and is_owner(u):return

def handle_state(c,t):
 st=STATE.get(c)
 if not st:return False
 f=st['f']
 if f in ('domain','ban','quota','money','admin:add','admin:remove','admin:rename') and not is_owner(c):STATE.pop(c,None);return True
 if f=='domain':
  t=t.strip();s=settings();s['domain']='' if t.upper() in ('','IP','AUTO') else t;save_json(SET,s);set_server_domain(s['domain']);STATE.pop(c,None);tt,kk=settings_menu();return send(c,'🟢 Dominio actualizado.\n\n'+tt,kk)
 if f=='ban':
  if not t.strip().isdigit():return send(c,'❌ ID inválido.')
  b=load_json(BANS,{});b[t.strip()]={'at':time.strftime('%F'),'by':c};save_json(BANS,b);STATE.pop(c,None);return send(c,f'🟢 ID <code>{e(t.strip())}</code> bloqueado.',[[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if f=='quota':
  a=[x.strip() for x in t.split('|')]
  if len(a)!=4 or not all(x.isdigit() for x in a):return send(c,'❌ Formato inválido.')
  s=settings();s.update(public_max_days=int(a[0]),public_max_devices=int(a[1]),admin_max_days=int(a[2]),admin_max_devices=int(a[3]));save_json(SET,s);STATE.pop(c,None);return send(c,'🟢 Cuotas actualizadas.',[[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if f=='money':
  url=t.strip()
  if not re.match(r'^https?://',url):return send(c,'❌ URL inválida. Debe comenzar con http:// o https://')
  m=load_json(MON,DEFAULT_MON.copy());k=st['d']['platform'];m[k]={'enabled':True,'url':url};save_json(MON,m);STATE.pop(c,None);return send(c,'🟢 Monetización guardada.',[[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if f=='admin:add':
  a=[x.strip() for x in t.split('|')]
  if len(a)!=3 or not a[0].isdigit() or not a[1]:return send(c,'❌ Formato: ID | Nombre | DD/MM/AAAA o ilimitado')
  exp=a[2].lower()
  if exp!='ilimitado':
   try:import datetime as dt; exp=dt.datetime.strptime(a[2],'%d/%m/%Y').strftime('%Y-%m-%d')
   except:return send(c,'❌ Fecha inválida. Usa DD/MM/AAAA o ilimitado.')
  r=admin_records();r[a[0]]={'id':int(a[0]),'name':a[1],'expires':exp,'active':True};save_json(ADMINS,r);env();STATE.pop(c,None);return send(c,'🟢 Administrador agregado.',[[{'text':'👑 Admin','callback_data':'set:admins'}]])
 if f=='admin:remove':
  x=t.strip()
  if not x.isdigit():return send(c,'❌ ID inválido.')
  r=admin_records();r.pop(x,None);save_json(ADMINS,r);env();STATE.pop(c,None);return send(c,'🟢 Administrador eliminado.',[[{'text':'👑 Admin','callback_data':'set:admins'}]])
 if f=='admin:rename':
  a=[x.strip() for x in t.split('|')]
  if len(a)!=2 or not a[0].isdigit() or not a[1]:return send(c,'❌ Formato: ID | Nuevo nombre')
  r=admin_records();
  if a[0] not in r:return send(c,'❌ Administrador no encontrado.')
  r[a[0]]['name']=a[1];save_json(ADMINS,r);STATE.pop(c,None);return send(c,'🟢 Administrador renombrado.',[[{'text':'👑 Admin','callback_data':'set:admins'}]])
 if f=='restore':return True
 return False

def process_message(m):
 c=m['chat']['id'];u=m['from']['id'];t=m.get('text','')
 if is_banned(u):return send(c,'⛔ Tu ID está bloqueado.')
 if not can_use(u):return send(c,'⛔ Acceso privado. Solo administradores.')
 if handle_state(c,t):return
 if t in ('/start','/menu'):return send(c,'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n'+('⚙️ Panel de administración' if is_admin(u) else '🌐 Acceso público'),home_for(u))
 process_text(c,t)
def process_document(m):
 c=m['chat']['id'];u=m['from']['id'];st=STATE.get(c)
 if not st or st.get('f')!='restore' or not is_owner(u):return
 doc=m.get('document',{});name=doc.get('file_name','')
 if not name.lower().endswith('.json'):return send(c,'❌ Solo se acepta un archivo JSON.')
 try:
  p=download_document(doc['file_id']);x=json.loads(p.read_text());
  if not all(k in x for k in ('settings','admins','bans','monetization')):raise ValueError('Estructura inválida')
  save_json(SET,x['settings']);save_json(ADMINS,x['admins']);save_json(BANS,x['bans']);save_json(MON,x['monetization']);STATE.pop(c,None);env();return send(c,'🟢 Respaldo JSON restaurado correctamente.',[[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 except Exception as er:log('RESTORE '+repr(er));return send(c,'🔴 No se pudo restaurar el JSON.')
def main():
 env();settings();LOG.parent.mkdir(parents=True,exist_ok=True);LOG.touch();LOG.chmod(0o600);api('deleteWebhook',{'drop_pending_updates':'false'});off=int(OFF.read_text()) if OFF.exists() and OFF.read_text().strip().isdigit() else 0;log('BOT ONLINE')
 while True:
  try:
   r=api('getUpdates',{'offset':off,'timeout':30,'allowed_updates':json.dumps(['message','callback_query'])})
   for z in r.get('result',[]):
    off=z['update_id']+1;OFF.write_text(str(off))
    try:
     if 'callback_query' in z:
      qz=z['callback_query'];mm=qz['message'];cb(mm['chat']['id'],mm['message_id'],qz['from']['id'],qz['id'],qz.get('data',''))
     elif 'message' in z:
      if 'document' in z['message']:process_document(z['message'])
      else:process_message(z['message'])
    except Exception as er:log('UPDATE '+repr(er))
  except Exception as er:log('POLL '+repr(er));time.sleep(2)
if __name__=='__main__':main()
