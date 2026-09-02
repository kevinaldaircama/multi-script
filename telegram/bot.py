#!/usr/bin/env python3
# KevinTech Telegram Bot - panel de usuarios + super admin
import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,shlex,datetime,io
from pathlib import Path

BASE=Path('/etc/kevintech'); TD=BASE/'telegram'; ENV=TD/'.env'; LOG=TD/'logs'/'bot.log'; OFF=TD/'offset'
DB=TD/'data.json'; BACK=TD/'backups'; STATE={}; CHAT_TYPES={}; API=''; OWNER=0; BOT_USERNAME=''

DEFAULT={
 'access':'private','admins':{},'bans':{},'users':{},
 'quotas':{'public_days':7,'public_devices':1,'admin_days':30,'admin_devices':2},
 'security':{'auto_ban_ssh':False,'violations':{}},
 'monetization':{'monetag':'','adsgram':''},
 'auto_update':{'enabled':False,'last_version':'','checked_at':0},
 'backup_schedule':{'mode':'once','next_at':0},
}

def log(s):
 LOG.parent.mkdir(parents=True,exist_ok=True); LOG.open('a').write(time.strftime('[%F %T] ')+str(s)+'\n')

def load_db():
 DB.parent.mkdir(parents=True,exist_ok=True)
 if not DB.exists(): DB.write_text(json.dumps(DEFAULT,indent=2,ensure_ascii=False)); return json.loads(json.dumps(DEFAULT))
 try:d=json.loads(DB.read_text(errors='ignore'))
 except Exception:d=json.loads(json.dumps(DEFAULT))
 for k,v in DEFAULT.items():
  if k not in d:d[k]=json.loads(json.dumps(v))
 if 'miniapp' in d.get('monetization',{}):d['monetization']['adsgram']=d['monetization'].pop('miniapp')
 if not isinstance(d.get('auto_update'),dict):d['auto_update']=json.loads(json.dumps(DEFAULT['auto_update']))
 for k,v in DEFAULT['auto_update'].items():d['auto_update'].setdefault(k,v)
 for k in ('admins','bans','users'):
  if not isinstance(d.get(k),dict):d[k]={}
 if not isinstance(d.get('quotas'),dict):d['quotas']=json.loads(json.dumps(DEFAULT['quotas']))
 for k,v in DEFAULT['quotas'].items():d['quotas'].setdefault(k,v)
 # Compatibilidad: V2Ray usa siempre la misma cuota pública y ya no tiene cuota propia.
 d['quotas'].pop('v2ray_days',None); d['quotas'].pop('v2ray_devices',None)
 if not isinstance(d.get('security'),dict):d['security']=json.loads(json.dumps(DEFAULT['security']))
 for k,v in DEFAULT['security'].items():d['security'].setdefault(k,json.loads(json.dumps(v)) if isinstance(v,dict) else v)
 if not isinstance(d.get('monetization'),dict):d['monetization']=json.loads(json.dumps(DEFAULT['monetization']))
 for k,v in DEFAULT['monetization'].items():d['monetization'].setdefault(k,v)
 if not isinstance(d.get('backup_schedule'),dict):d['backup_schedule']=json.loads(json.dumps(DEFAULT['backup_schedule']))
 d['backup_schedule'].setdefault('mode','once');d['backup_schedule'].setdefault('next_at',0)
 return d

def save_db(d):
 DB.write_text(json.dumps(d,indent=2,ensure_ascii=False)); os.chmod(DB,0o600)

def env():
 global API,OWNER
 d={}
 if not ENV.exists():raise SystemExit('Falta /etc/kevintech/telegram/.env')
 for l in ENV.read_text(errors='ignore').splitlines():
  if '=' in l and not l.lstrip().startswith('#'):
   k,v=l.split('=',1);d[k]=v.strip().strip('"').strip("'")
 t=d.get('BOT_TOKEN','');a=d.get('ADMIN_ID','')
 if not re.fullmatch(r'\d+:[A-Za-z0-9_-]+',t) or not a.isdigit():raise SystemExit('Credenciales inválidas en .env')
 OWNER=int(a);API='https://api.telegram.org/bot'+t

def api(m,data=None,timeout=40):
 r=urllib.request.Request(API+'/'+m,data=urllib.parse.urlencode(data or {}).encode())
 with urllib.request.urlopen(r,timeout=timeout) as x:z=json.loads(x.read().decode())
 if not z.get('ok'):raise RuntimeError(z)
 return z

def api_multipart(method,fields,files,timeout=60):
 boundary='----KevinTechBoundary'+str(int(time.time()*1000));body=bytearray()
 for name,value in fields.items():
  body.extend((f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n').encode())
 for name,(filename,data,ctype) in files.items():
  body.extend((f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\nContent-Type: {ctype}\r\n\r\n').encode());body.extend(data);body.extend(b'\r\n')
 body.extend((f'--{boundary}--\r\n').encode())
 req=urllib.request.Request(API+'/'+method,data=bytes(body),headers={'Content-Type':f'multipart/form-data; boundary={boundary}'})
 with urllib.request.urlopen(req,timeout=timeout) as x:z=json.loads(x.read().decode())
 if not z.get('ok'):raise RuntimeError(z)
 return z

def e(x):return str(x).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
def lang(uid):
 d=db();return d.get('users',{}).get(str(uid),{}).get('language','es')

I18N={
 'home':{'es':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Panel principal</b>\n\nAdministra tus cuentas de forma rápida y sencilla desde Telegram.\n\n🔐 Acceso · 👤 Cuentas · 🟢 Conexiones · 🔗 Referidos','en':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Main panel</b>\n\nManage your accounts quickly and easily from Telegram.\n\n🔐 Access · 👤 Accounts · 🟢 Connections · 🔗 Referrals','pt':'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Painel principal</b>\n\nGerencie suas contas de forma rápida e simples pelo Telegram.\n\n🔐 Acesso · 👤 Contas · 🟢 Conexões · 🔗 Indicações'},
 'users':{'es':'👤 <b>USUARIOS</b>\n\nGestiona tus cuentas.','en':'👤 <b>USERS</b>\n\nManage your accounts.','pt':'👤 <b>USUÁRIOS</b>\n\nGerencie suas contas.'},
 'info':{'es':'ℹ️ <b>INFORMACIÓN</b>\n\nEste bot te permite gestionar tus accesos desde Telegram: crear cuentas normales o V2Ray, consultar tus cuentas, revisar conexiones, renovar, eliminar y usar el sistema de referidos. Las cuotas definidas por el super admin se aplican automáticamente a los usuarios públicos.','en':'ℹ️ <b>INFORMATION</b>\n\nThis bot lets you create and manage your server access accounts, view your accounts, check connections and manage referrals.','pt':'ℹ️ <b>INFORMAÇÕES</b>\n\nEste bot permite criar e gerenciar suas contas de acesso ao servidor, consultar suas contas, ver conexões e gerenciar indicações.'},
 'choose_lang':{'es':'🌎 <b>Selecciona tu idioma</b>\n\nElige el idioma que quieres usar.','en':'🌎 <b>Select your language</b>\n\nChoose the language you want to use.','pt':'🌎 <b>Selecione seu idioma</b>\n\nEscolha o idioma que deseja usar.'},
 'settings':{'es':'⚙️ <b>AJUSTES DEL SUPER ADMIN</b>\n\nControl central del panel.','en':'⚙️ <b>SUPER ADMIN SETTINGS</b>\n\nCentral panel controls.','pt':'⚙️ <b>AJUSTES DO SUPER ADMIN</b>\n\nControles centrais do painel.'},
 'language_saved':{'es':'🟢 Idioma guardado.','en':'🟢 Language saved.','pt':'🟢 Idioma salvo.'},
}
def tr(uid,key):return I18N.get(key,I18N['home']).get(lang(uid),I18N.get(key,I18N['home'])['es'])

def send(c,t,k=None):
 d={'chat_id':c,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true'}
 if k:d['reply_markup']=json.dumps({'inline_keyboard':k},ensure_ascii=False)
 return api('sendMessage',d)
def send_document(c,path,caption=''):
 return api_multipart('sendDocument',{'chat_id':str(c),'caption':caption,'parse_mode':'HTML'}, {'document':(Path(path).name,Path(path).read_bytes(),'application/json')})
def edit(c,m,t,k=None):
 try:return api('editMessageText',{'chat_id':c,'message_id':m,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true','reply_markup':json.dumps({'inline_keyboard':k},ensure_ascii=False) if k is not None else json.dumps({'inline_keyboard':[]})})
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
VERSION_LOCAL=TD/'version.txt'
VERSION_URL='https://raw.githubusercontent.com/kevinaldaircama/multi-script/main/version.txt'
def current_version():
 try:
  p=VERSION_LOCAL if VERSION_LOCAL.exists() else BASE/'version.txt';return p.read_text(errors='ignore').splitlines()[0].strip() or 'No disponible'
 except:return 'No disponible'
def new_version():
 try:
  req=urllib.request.Request(VERSION_URL,headers={'User-Agent':'KevinTech-Updater'})
  with urllib.request.urlopen(req,timeout=8) as r:return r.read().decode().splitlines()[0].strip() or 'No disponible'
 except:return 'No disponible'
def version_key(v):
 try:return tuple(int(x) for x in re.findall(r'\d+',v))
 except:return (0,)
def update_available():
 cur=current_version();new=new_version();return cur,new,(new!='No disponible' and cur!='No disponible' and version_key(new)>version_key(cur))
def run_update(c=None,auto=False):
 updater=BASE/'update.sh'
 if not updater.exists():
  if c:send(c,'❌ No se encontró el actualizador del sistema.')
  return
 cmd=f'bash {q(updater)} --auto' if auto else f'bash {q(updater)}'
 if c:bg(c,'Actualización del sistema',cmd,900,settings_keyboard())
 else:sh(cmd,900)
def auto_update_monitor():
 while True:
  try:
   d=db()
   if d.get('auto_update',{}).get('enabled'):
    cur,new,available=update_available()
    if available:
     log(f'AUTO UPDATE {cur} -> {new}');run_update(auto=True)
    d=db();d['auto_update']['last_version']=new;d['auto_update']['checked_at']=time.time();save_db(d)
  except Exception as ex:log('AUTO UPDATE '+repr(ex))
  time.sleep(21600)

def bg(c,title,cmd,timeout=300,k=None,restart_after=False):
 send(c,f'⚡ <b>{e(title)}</b>\n\n🟡 Operación iniciada...')
 def w():
  rc,out=sh(cmd,timeout)
  if len(out)>4500:out=out[-4500:]
  send(c,('🟢' if rc==0 else '🔴')+f' <b>{e(title)}</b>\n\n<pre>{e(out or "Terminado sin salida")}</pre>',k)
  if rc==0 and restart_after:time.sleep(2);sh('reboot',10)
 threading.Thread(target=w,daemon=True).start()

def db():return load_db()
def is_owner(uid):return uid==OWNER
def is_admin(uid):
 if uid==OWNER:return True
 d=db();a=d['admins'].get(str(uid))
 if not a:return False
 if a.get('until') and a['until']!='unlimited':
  try:
   if datetime.date.today()>datetime.date.fromisoformat(a['until']):
    d['admins'].pop(str(uid),None);save_db(d);return False
  except:pass
 return True
def allowed(uid):d=db();return is_admin(uid) or d.get('access')=='public'
def banned(uid):return str(uid) in db()['bans']
def registered(uid,name=None,username=None):
 d=db();k=str(uid)
 if k not in d['users']:
  d['users'][k]={'id':uid,'name':name or str(uid),'username':username or '','created':time.strftime('%F'),'started':False,'accounts':[],'v2ray_accounts':[],'language':'es','language_selected':False,'referrer':None,'referrals':[],'referral_renews':0}
  save_db(d)
 else:
  changed=False
  if name and d['users'][k].get('name')!=name:d['users'][k]['name']=name;changed=True
  if username is not None and d['users'][k].get('username','')!=username:d['users'][k]['username']=username;changed=True
  if 'v2ray_accounts' not in d['users'][k]:d['users'][k]['v2ray_accounts']=[];changed=True
  if changed:save_db(d)

def home(uid):
 rows=[[{'text':'👤 Usuarios','callback_data':'users'},{'text':'🔗 Referidos','callback_data':'referrals'}],[{'text':'🌐 Idioma','callback_data':'language'},{'text':'ℹ️ Información','callback_data':'info'}]]
 if is_owner(uid):rows.append([{'text':'⚙️ Ajustes','callback_data':'settings'}])
 return rows
USERS=[[{'text':'➕ Crear cuenta','callback_data':'create'},{'text':'♻️ Renovar','callback_data':'renew'}],[{'text':'📋 Lista','callback_data':'list'},{'text':'🟢 Online','callback_data':'online'}],[{'text':'👤 Cuenta','callback_data':'account'},{'text':'🗑️ Eliminar cuenta','callback_data':'delete'}],[{'text':'🔙 Inicio','callback_data':'home'}]]
CREATE_MENU=[[{'text':'👤 Cuenta normal','callback_data':'create:normal'},{'text':'🚀 Cuenta V2Ray','callback_data':'create:v2ray'}],[{'text':'🔙 Usuarios','callback_data':'users'}]]
PROTO={'openssh':('OpenSSH','openssh.sh','ssh','22','1','5'),'dropbear':('Dropbear','dropbear.sh','dropbear','90,143,109','1','6'),'openvpn':('OpenVPN','openvpn.sh','openvpn','1194/UDP,2200/TCP,443/TCP','1','10'),'v2ray':('V2Ray/Xray','v2ray.sh','xray','443/TCP','1','13'),'checkuser':('CheckUser','checkuser.sh','checkuser','10016,10015,8888','1','8'),'slowdns':('SlowDNS','slowdns.sh','dnstt','5300/UDP','1','7'),'badvpn':('BadVPN','badvpn.sh','badvpn-7300','7300,7200','1','4'),'ssl':('SSL/WebSocket','ssl.sh','haproxy','80,443,8080,10015','1','6'),'udpcustom':('UDP Custom','udpcustom.sh','udp-custom','1-65535/UDP','1','7'),'zivpn':('ZiVPN','zivpn.sh','zivpn','20000-29999/UDP','1','10')}
PK=[[{'text':v[0],'callback_data':'proto:'+k}] for k,v in PROTO.items()]+[[{'text':'🔙 Inicio','callback_data':'home'}]]
SVCS={k:v[2] for k,v in PROTO.items()}
TOOLS=[[{'text':'🔥 Firewall','callback_data':'tool:firewall'},{'text':'🚀 Optimizar','callback_data':'tool:optimizar'}],[{'text':'🚫 Ads','callback_data':'tool:ads'},{'text':'🚫 Torrent','callback_data':'tool:torrent'}],[{'text':'📈 Speedtest','callback_data':'tool:speed'},{'text':'🔎 Scanner','callback_data':'tool:scanner'}],[{'text':'📁 Archivos','callback_data':'tool:files'},{'text':'🔄 Actualizar','callback_data':'tool:update'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]

def module(name):
 for p in [BASE/'protocolos'/name,BASE/'herramientas'/name,BASE/'usuarios'/name]:
  if p.exists():return p
 return None
def installed(k):
 s=SVCS[k];paths={'openssh':['/usr/sbin/sshd'],'dropbear':['/usr/sbin/dropbear'],'openvpn':['/usr/sbin/openvpn'],'v2ray':['/usr/local/bin/xray','/usr/bin/xray','/etc/xray'],'checkuser':['/etc/systemd/system/checkuser.service'],'slowdns':['/etc/slowdns','/usr/local/bin/dnstt-server'],'badvpn':['/usr/local/bin/badvpn-udpgw'],'ssl':['/usr/sbin/haproxy'],'udpcustom':['/usr/local/bin/udp-custom'],'zivpn':['/etc/zivpn']}
 if any(Path(x).exists() for x in paths.get(k,[])):return True
 return sh(f'systemctl cat {q(s)} >/dev/null 2>&1',3)[0]==0

def userlist():
 a=subprocess.getoutput("awk -F: '$3>=1000&&$1!=\"nobody\"{print $1}' /etc/passwd").splitlines()
 return '📋 <b>USUARIOS SSH</b>\n\n'+('\n'.join('• <code>'+e(x)+'</code>' for x in a) if a else 'No hay usuarios.')+f'\n\nTotal: <b>{len(a)}</b>'
def quota(uid):
 d=db();return d['quotas']['admin_days' if is_admin(uid) else 'public_days'],d['quotas']['admin_devices' if is_admin(uid) else 'public_devices']
def userexists(u):return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',u,re.I)) and sh(f'id {q(u)} >/dev/null 2>&1',3)[0]==0

def account_info(uid,username):
 d=db();owner='—';owner_user=''
 is_v2=False;vexp='No disponible'
 for cid,x in d['users'].items():
  if username in x.get('accounts',[]):
   owner=x.get('name',cid);owner_user=x.get('username','')
   is_v2=username in x.get('v2ray_accounts',[])
   vexp=x.get('v2ray_expirations',{}).get(username,'No disponible')
   break
 if is_v2:
  return f'''🚀 <b>INFORMACIÓN V2RAY</b>\n\n• Usuario: <code>{e(username)}</code>\n• Propietario: <code>{e(('@'+owner_user) if owner_user else owner)}</code>\n• Expira: <code>{e(vexp)}</code>\n• Tipo: <b>V2Ray / VMess</b>'''
 if not userexists(username):return '❌ Esa cuenta no existe.'
 exp=subprocess.getoutput(f"chage -l {q(username)} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'") or 'No disponible';lim='Ilimitado';p=BASE/'limits'/username
 if p.exists():lim=p.read_text(errors='ignore').strip() or 'Ilimitado'
 return f'''👤 <b>INFORMACIÓN DE CUENTA</b>\n\n• Usuario: <code>{e(username)}</code>\n• Propietario: <code>{e(('@'+owner_user) if owner_user else owner)}</code>\n• Expira: <code>{e(exp)}</code>\n• Límite de dispositivos/IP: <code>{e(lim)}</code>'''

def referral_info(uid):
 d=db();u=d['users'].get(str(uid),{});refs=u.get('referrals',[]);renews=int(u.get('referral_renews',0));used=renews*3;available=max(0,len(refs)-used);left=max(0,3-len(refs)%3 if available<3 else 0)
 link=f'https://t.me/{BOT_USERNAME}?start=ref_{uid}' if BOT_USERNAME else f'/start ref_{uid}'
 return f'''🔗 <b>PROGRAMA DE REFERIDOS</b>\n\n👥 Referidos válidos: <b>{len(refs)}</b>\n🎁 Renovaciones usadas: <b>{renews}/3</b>\n⭐ Créditos disponibles: <b>{available}</b>\n\n🔗 <b>Tu enlace:</b>\n<code>{e(link)}</code>\n\n🎯 Cada <b>3 referidos</b> permite renovar una cuenta durante <b>24 horas</b>.\n♻️ Máximo: <b>3 renovaciones</b>.'''

def online_ssh():
 out=subprocess.getoutput("ss -tnp state established 2>/dev/null | grep -E ':22[[:space:]]|sshd' || true")
 names=[]
 for line in out.splitlines():
  m=re.search(r'users:\(\("sshd".*pid=([0-9]+)',line)
  if m:
   pid=m.group(1);name=subprocess.getoutput(f"ps -o user= -p {pid} 2>/dev/null").strip()
   if name and name not in ('root','sshd') and name not in names:names.append(name)
 if not names:
  # Fallback to SSH sessions only; does not count terminal/web sessions unrelated to SSH.
  for line in subprocess.getoutput("who 2>/dev/null").splitlines():
   if 'pts/' in line:
    name=line.split()[0]
    if name!='root' and name not in names:names.append(name)
 return names

def create_v2ray(username,days):
 try:
  cfg=Path('/usr/local/etc/xray/config.json')
  if not cfg.exists():return 1,'Xray no está instalado.'
  data=json.loads(cfg.read_text())
  clients=data.setdefault('inbounds',[{}])[0].setdefault('settings',{}).setdefault('clients',[])
  if any(str(x.get('email','')).lower()==username.lower() for x in clients):return 1,'El usuario V2Ray ya existe.'
  import uuid
  uid=str(uuid.uuid4());clients.append({'id':uid,'level':0,'email':username})
  tmp=cfg.with_suffix('.json.tmp');tmp.write_text(json.dumps(data,indent=2,ensure_ascii=False));os.chmod(tmp,0o600);tmp.replace(cfg)
  rc,out=sh('systemctl restart xray',20)
  if rc:return rc,out
  return 0,uid
 except Exception as ex:return 1,str(ex)

def delete_v2ray(username):
 try:
  cfg=Path('/usr/local/etc/xray/config.json');data=json.loads(cfg.read_text());clients=data.get('inbounds',[{}])[0].get('settings',{}).get('clients',[])
  new=[x for x in clients if x.get('email')!=username]
  if len(new)==len(clients):return 1,'Usuario V2Ray no encontrado.'
  data['inbounds'][0]['settings']['clients']=new;cfg.write_text(json.dumps(data,indent=2,ensure_ascii=False));os.chmod(cfg,0o600);return sh('systemctl restart xray',20)
 except Exception as ex:return 1,str(ex)

def v2ray_account_message(c,d):
 username=d['user'];uuid=d.get('uuid')
 if not uuid:
  cfg=Path('/usr/local/etc/xray/config.json');data=json.loads(cfg.read_text());
  uuid=next((x.get('id') for x in data.get('inbounds',[{}])[0].get('settings',{}).get('clients',[]) if x.get('email')==username),'')
 cfg=BASE/'config.conf';domain=''
 if cfg.exists():
  for l in cfg.read_text(errors='ignore').splitlines():
   if l.startswith('SERVER_DOMAIN='):domain=l.split('=',1)[1].strip().strip('"').strip("'")
 ip=(subprocess.getoutput('curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null') or (subprocess.getoutput('hostname -I').split() or ['0.0.0.0'])[0]).strip()
 host=domain or ip;exp=subprocess.getoutput(f"date -d '+{int(d['days'])} days' '+%d/%m/%Y'")
 import base64
 raw=f'v:vmess@{host}:443?type=ws&path=/vmess&security=tls&uuid={uuid}'
 link='vmess://'+base64.b64encode(raw.encode()).decode()
 return f'''🚀 <b>CUENTA V2RAY CREADA</b>\n\n👤 Usuario: <code>{e(username)}</code>\n🆔 UUID: <code>{e(uuid)}</code>\n📅 Expira: <code>{e(exp)}</code>\n🌐 Servidor: <code>{e(host)}</code>\n🔒 Puerto: <code>443</code>\n📡 WS: <code>/vmess</code>\n\n🔗 <b>VMess</b>\n<code>{e(link)}</code>'''

def account_message(c,d,renew=False):
 u=d['user'];pw=d.get('pass');days=int(d['days']);exp=subprocess.getoutput(f"date -d '+{days} days' '+%d/%m/%Y'")
 ip=(subprocess.getoutput('curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null') or (subprocess.getoutput('hostname -I').split() or ['0.0.0.0'])[0]).strip()
 cfg=BASE/'config.conf';domain=''
 if cfg.exists():
  for l in cfg.read_text(errors='ignore').splitlines():
   if l.startswith('SERVER_DOMAIN='):domain=l.split('=',1)[1].strip().strip('"').strip("'")
 host=domain or ip
 title='♻️ CUENTA RENOVADA EXITOSAMENTE' if renew else '🎉 CUENTA CREADA EXITOSAMENTE'
 lim=d.get('limit','Ilimitado');limtxt='Ilimitado' if str(lim).lower() in ('0','ilimitado','unlimited') else str(lim)
 slow_ns=f'ns-{domain}' if domain else 'Requiere dominio real'
 slow_key=(Path('/etc/slowdns/server.pub').read_text(errors='ignore').strip() if Path('/etc/slowdns/server.pub').exists() else 'No configurado')
 return f'''<b>{title}</b>

━━━━━━━━━━━━━━━━━━━━
👤 <b>DATOS DEL USUARIO</b>
━━━━━━━━━━━━━━━━━━━━
• Usuario: <code>{e(u)}</code>
• 🔑 Contraseña: <code>{e(pw or '********')}</code>
• Expira: <code>{e(exp)}</code>
• Duración: <code>{days} días</code>
• Límite IP: <code>{e(limtxt)}</code>

━━━━━━━━━━━━━━━━━━━━
🌐 <b>INFORMACIÓN DEL SERVIDOR</b>
━━━━━━━━━━━━━━━━━━━━
• Host/IP: <code>{e(host)}</code>
• IP: <code>{e(ip)}</code>
• SSH: <code>22</code>
• Dropbear: <code>143,90,109</code>
• SSL Tunnel: <code>8080,443,80</code>
• OpenVPN: <code>1194,2200,443</code>
• BadVPN: <code>7300,7200</code>

━━━━━━━━━━━━━━━━━━━━
📡 <b>HTTP CUSTOM</b>
━━━━━━━━━━━━━━━━━━━━
<code>{e(host)}:443@{e(u)}:{e(pw or '********')}</code>
<code>{e(host)}:80@{e(u)}:{e(pw or '********')}</code>
<code>{e(host)}:8080@{e(u)}:{e(pw or '********')}</code>

━━━━━━━━━━━━━━━━━━━━
🚀 <b>UDP CUSTOM</b>
━━━━━━━━━━━━━━━━━━━━
<code>{e(host)}:1-65535@{e(u)}:{e(pw or '********')}</code>

━━━━━━━━━━━━━━━━━━━━
🟣 <b>HYSTERIA V1</b>
━━━━━━━━━━━━━━━━━━━━
• Servidor: <code>{e(host)}:No instalado</code>
• OBFS: <code>No configurado</code>
• Credenciales: <code>{e(u)}:{e(pw or '********')}</code>

━━━━━━━━━━━━━━━━━━━━
🚀 <b>ZIVPN UDP</b>
━━━━━━━━━━━━━━━━━━━━
• Servidor: <code>{e(host)}:21992</code>
• Contraseña: <code>{e(pw or '********')}</code>
• Puerto UDP: <code>20000-29999</code>

━━━━━━━━━━━━━━━━━━━━
🐌 <b>SLOWDNS (5300)</b>
━━━━━━━━━━━━━━━━━━━━
• NS: <code>{e(slow_ns)}</code>
• KEY: <code>{e(slow_key)}</code>
• Puerto: <code>5300</code>

━━━━━━━━━━━━━━━━━━━━
🌐 <b>BHTTP</b>
━━━━━━━━━━━━━━━━━━━━
• Servidor: <code>{e(host)}:8088</code>
• Backend SSH: <code>22</code>

━━━━━━━━━━━━━━━━━━━━
💎 <b>KEVINTECH MULTI SCRIPT</b>
━━━━━━━━━━━━━━━━━━━━'''

def private_chat(c):return CHAT_TYPES.get(c)=='private'

def parse_referral(t):
 m=re.search(r'(?:/start|/star)(?:\s+|\?start=)ref_(\d+)',t,re.I)
 return int(m.group(1)) if m else None

def handle_start(c,raw):
 global BOT_USERNAME
 registered(c)
 if banned(c):return send(c,'🚫 Tu acceso está bloqueado.')
 ref=parse_referral(raw)
 d=db();me=d['users'][str(c)]
 me['started']=True
 save_db(d)
 if ref and ref!=c and str(ref) in d['users'] and not me.get('referrer'):
  me['referrer']=ref;save_db(d)
 if not me.get('language_selected'):
  STATE[c]={'f':'language','s':'pick','d':{}}
  return send(c,I18N['choose_lang']['es']+'\n\n🇪🇸 / 🇺🇸 / 🇧🇷',[[{'text':'🇪🇸 Español','callback_data':'lang:es'},{'text':'🇺🇸 English','callback_data':'lang:en'}],[{'text':'🇧🇷 Português','callback_data':'lang:pt'}]])
 return send(c,tr(c,'home'),home(c))

def process_text(c,t,chat_type=None):
 CHAT_TYPES[c]=chat_type or CHAT_TYPES.get(c,'private')
 d=db();uid=c
 if banned(uid):return send(c,'🚫 Tu acceso está bloqueado.')
 registered(uid)
 if t.startswith('/start') or t.startswith('/star'):return handle_start(c,t)
 cmd=t.split()[0].lower() if t.split() else ''
 if cmd in ('/crear','/crearcuenta','/create'):
  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado. Abre el chat privado del bot y usa /crear.')
  if not allowed(uid):return send(c,'🔒 El bot está en modo privado.')
  return send(c,'➕ <b>CREAR CUENTA</b>\n\nSelecciona el tipo de cuenta:',CREATE_MENU)
 if cmd in ('/renovar','/renew'):
  STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR CUENTA</b>\n\nEscribe el usuario que deseas renovar:')
 if cmd in ('/lista','/cuentas','/list'):return cb(c,0,c,0,'list')
 if cmd in ('/online','/conectados'):return cb(c,0,c,0,'online')
 if cmd in ('/cuenta','/info_cuenta'):
  STATE[c]={'f':'account','s':'u','d':{}};return send(c,'👤 <b>CONSULTAR CUENTA</b>\n\nEscribe el usuario:')
 if cmd in ('/eliminar','/borrar'):
  STATE[c]={'f':'delete','s':'u','d':{}};return send(c,'🗑️ <b>ELIMINAR CUENTA</b>\n\nEscribe el usuario:')
 if cmd in ('/referidos','/referrals'):return send(c,referral_info(c),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if cmd in ('/idioma','/language'):return send(c,I18N['choose_lang'].get(lang(c),I18N['choose_lang']['es']),[[{'text':'🇪🇸 Español','callback_data':'lang:es'},{'text':'🇺🇸 English','callback_data':'lang:en'}],[{'text':'🇧🇷 Português','callback_data':'lang:pt'}]])
 if cmd in ('/informacion','/info'):return send(c,tr(c,'info'),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if cmd in ('/respaldo','/backup') and is_owner(uid):return cb(c,0,c,0,'backup_restore')
 if cmd in ('/ajustes','/settings') and is_owner(uid):return cb(c,0,c,0,'settings')
 if cmd in ('/cuotas','/quota') and is_owner(uid):return cb(c,0,c,0,'quotas')
 if cmd in ('/seguridad','/security') and is_owner(uid):return cb(c,0,c,0,'security')
 if cmd in ('/admins','/administradores') and is_owner(uid):return cb(c,0,c,0,'admins')
 if cmd in ('/ban','/baneos') and is_owner(uid):return cb(c,0,c,0,'bans')
 if cmd in ('/monetizacion','/monetization') and is_owner(uid):return cb(c,0,c,0,'monetization')
 if cmd in ('/herramientas','/tools') and is_owner(uid):return cb(c,0,c,0,'tools')
 if t.startswith('/referidos'):return send(c,referral_info(c))
 if not allowed(uid):return send(c,'🔒 El bot está en modo privado.')
 st=STATE.get(c)
 if not st:return None
 f,step,dat=st['f'],st['s'],st['d']
 if step=='u' and f in ('create','renew','delete','account'):
  u=t.strip()
  if f in ('delete','account') and not userexists(u):return send(c,'❌ Cuenta no encontrada. Escribe un usuario válido:')
  if f=='renew' and not userexists(u):return send(c,'❌ Cuenta no encontrada. Escribe un usuario válido:')
  if f=='create' and userexists(u):return send(c,'❌ Ese usuario ya existe. Elige otro nombre:')
  dat['user']=u
  if f=='account':STATE.pop(c,None);return send(c,account_info(c,u))
  if f=='delete':st['s']='confirm';return send(c,f'⚠️ ¿Seguro que deseas eliminar <code>{e(u)}</code>?',[[{'text':'🗑️ Eliminar','callback_data':'userop:delete'},{'text':'Cancelar','callback_data':'cancel'}]])
  if f=='create':
   # Usuarios: días/dispositivos salen de la cuota. El super admin puede definirlos.
   if dat.get('kind')=='v2ray':
    if is_owner(c):st['s']='days';return send(c,'📅 Duración de la cuenta (días):')
    maxdays,maxdev=quota(c);dat['days']=maxdays;dat['limit']=maxdev;return cb(c,0,c,0,'do:create')
   st['s']='p';return send(c,'🔑 Contraseña:')
  # Renovación: usuarios usan automáticamente su cuota; super admin puede definirla.
  if is_owner(c):st['s']='days';return send(c,'📅 Días para renovar:')
  maxdays,maxdev=quota(c);dat['days']=maxdays;dat['limit']=maxdev;return cb(c,0,c,0,'do:renew')
 if f=='create' and step=='p':
  dat['pass']=t
  if is_owner(c):st['s']='days';return send(c,'📅 Duración de la cuenta (días):')
  maxdays,maxdev=quota(c);dat['days']=maxdays;dat['limit']=maxdev;return cb(c,0,c,0,'do:create')
 if f in ('create','renew') and step=='days':
  if not t.isdigit() or int(t)<1:return send(c,'❌ Debes indicar un número de días válido.')
  maxdays,maxdev=quota(c)
  if not is_owner(c) and int(t)>maxdays:return send(c,f'❌ Tu cuota permite como máximo <b>{maxdays} días</b>.')
  dat['days']=int(t)
  if is_owner(c):
   st['s']='devices';return send(c,'📱 Límite de dispositivos/IP:')
  dat['limit']=maxdev;return cb(c,0,c,0,'do:'+f)
 if f in ('create','renew') and step=='devices':
  if not t.isdigit() or int(t)<1:return send(c,'❌ Debes indicar un número válido.')
  dat['limit']=int(t);return cb(c,0,c,0,'do:'+f)

def cb(c,m,u,i,x,chat_type=None):
 CHAT_TYPES[c]=chat_type or CHAT_TYPES.get(c,'private')
 if banned(u):return ans(i,'🚫 Baneado')
 registered(u);ans(i,'⚡');d=db()
 if x.startswith('lang:'):
  language=x.split(':',1)[1];d['users'][str(u)]['language']=language;d['users'][str(u)]['language_selected']=True;save_db(d);STATE.pop(u,None);return edit(c,m,tr(u,'home'),home(u))
 if x=='home':return edit(c,m,tr(u,'home'),home(u))
 if x=='info':return edit(c,m,tr(u,'info'),[[{'text':'🔙 Inicio','callback_data':'home'}]])
 if x=='language':return edit(c,m,I18N['choose_lang'].get(lang(u),I18N['choose_lang']['es']),[[{'text':'🇪🇸 Español','callback_data':'lang:es'},{'text':'🇺🇸 English','callback_data':'lang:en'}],[{'text':'🇧🇷 Português','callback_data':'lang:pt'}],[{'text':'🔙 Inicio','callback_data':'home'}]])
 if x=='users':return edit(c,m,'👤 <b>USUARIOS</b>\n\nGestiona tus cuentas SSH.',USERS)
 if x=='referrals':return edit(c,m,referral_info(u),[[{'text':'♻️ Renovar 24h (3 referidos)','callback_data':'ref_renew'}],[{'text':'🔙 Inicio','callback_data':'home'}]])
 if x=='create':
  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado. Usa /crear en el chat privado del bot.')
  if not allowed(u):return send(c,'🔒 Acceso privado.')
  return edit(c,m,'➕ <b>CREAR CUENTA</b>\n\nSelecciona el tipo de cuenta:',CREATE_MENU)
 if x in ('create:normal','create:v2ray'):
  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado.')
  if not allowed(u):return send(c,'🔒 Acceso privado.')
  kind='v2ray' if x.endswith('v2ray') else 'normal'
  STATE[c]={'f':'create','s':'u','d':{'kind':kind}}
  return send(c,'🚀 <b>CREAR CUENTA V2RAY</b>\n\nUsuario:') if kind=='v2ray' else send(c,'👤 <b>CREAR CUENTA</b>\n\nUsuario:')
 if x=='renew':STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR</b>\n\nUsuario:')
 if x=='account':STATE[c]={'f':'account','s':'u','d':{}};return send(c,'👤 <b>CUENTA</b>\n\nEscribe tu usuario para consultar la información:')
 if x=='delete':STATE[c]={'f':'delete','s':'u','d':{}};return send(c,'🗑️ <b>ELIMINAR CUENTA</b>\n\nEscribe el usuario:')
 if x=='list':
  if is_owner(u):
   lines=[]
   for sid,z in d['users'].items():
    mention='@'+str(z.get('username')) if z.get('username') else '<code>'+sid+'</code>'
    ac=z.get('accounts',[]);lines.append(f'👤 {e(mention)}\n   Cuentas: '+( ', '.join('<code>'+e(a)+'</code>' for a in ac) if ac else 'Ninguna'))
   text='📋 <b>LISTA DE CUENTAS</b>\n\n'+'\n'.join(lines) if lines else '📋 <b>LISTA DE CUENTAS</b>\n\nNo hay cuentas.'
  else:
   z=d['users'].get(str(u),{});ac=z.get('accounts',[]);text='📋 <b>TUS CUENTAS</b>\n\n'+('\n'.join('• <code>'+e(a)+'</code>' for a in ac) if ac else 'No tienes cuentas.')
  return edit(c,m,text)
 if x=='online':
  names=online_ssh();rows=[]
  for n in names:
   owner='—'
   for sid,z in d['users'].items():
    if n in z.get('accounts',[]):owner='@'+z.get('username') if z.get('username') else str(sid);break
   rows.append(f'• <code>{e(n)}</code> — {e(owner)}')
  text='🟢 <b>CUENTAS SSH ONLINE</b>\n\nConectados: <b>'+str(len(names))+'</b>\n\n'+('\n'.join(rows) if rows else 'No hay cuentas SSH conectadas.')
  return edit(c,m,text)
 if x=='cancel':STATE.pop(c,None);return send(c,'❌ Cancelado.')
 if x.startswith('do:'):
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.')
  dat=st['d'];u0=dat['user'];days=int(dat['days']);exp=subprocess.getoutput(f"date -d '+{days} days' +%F")
  if x=='do:create':
   if dat.get('kind')=='v2ray':
    rc,o=create_v2ray(dat['user'],days)
    if rc==0:
     dat['uuid']=o
     d=db();urow=d['users'][str(c)];urow.setdefault('v2ray_accounts',[]).append(dat['user']);urow.setdefault('accounts',[]).append(dat['user']);urow.setdefault('v2ray_expirations',{})[dat['user']]=subprocess.getoutput(f"date -d '+{days} days' '+%d/%m/%Y'")
     ref=urow.get('referrer')
     if ref and str(ref) in d['users'] and c not in d['users'][str(ref)].setdefault('referrals',[]):
      d['users'][str(ref)]['referrals'].append(c);save_db(d)
      try:send(int(ref),f'🎉 <b>¡Felicidades!</b>\nEl usuario @{e(urow.get("name",str(c)))} ha creado su primera cuenta.\n¡Has ganado <b>1 referido</b>!\nUsa /referidos o el menú para canjearlo.')
      except:pass
     save_db(d)
     return send(c,v2ray_account_message(c,dat))
    return send(c,'🔴 <b>No se pudo crear la cuenta V2Ray</b>\n<pre>'+e(o)+'</pre>')
   rc,o=sh(f'useradd -e {q(exp)} -M -s /usr/sbin/nologin {q(u0)} && printf "%s\\n" {q(u0+":"+dat["pass"])} | chpasswd',12)
   if rc==0:
    (BASE/'limits').mkdir(exist_ok=True);(BASE/'limits'/u0).write_text('0' if dat.get('limit') in ('Ilimitado',0,'0') else str(dat.get('limit')))
    d=db();d['users'][str(c)].setdefault('accounts',[]).append(u0)
    ref=d['users'][str(c)].get('referrer')
    if ref and str(ref) in d['users']:
     inviter=d['users'][str(ref)];
     if c not in inviter.setdefault('referrals',[]):
      inviter['referrals'].append(c);save_db(d)
      uname=d['users'][str(c)].get('username') or '';mention=f'@{uname}' if uname else f'<code>{c}</code>'
      try:send(int(ref),f'🎉 <b>¡Felicidades!</b>\nEl {e(mention)} ha creado su primera cuenta.\n¡Has ganado <b>1 referido</b>!\nUsa /referidos o el menú para canjearlo.')
      except Exception as er:log('REF NOTIFY '+repr(er))
    else:save_db(d)
    return send(c,account_message(c,dat))
   return send(c,'🔴 <b>Error al crear</b>\n<pre>'+e(o)+'</pre>')
  if x=='do:renew':
   rc,o=sh(f'chage -E {q(exp)} {q(u0)}',10);return send(c,account_message(c,dat,True)) if rc==0 else send(c,'🔴 <b>Error al renovar</b>\n<pre>'+e(o)+'</pre>')
 if x=='ref_renew':
  d=db();z=d['users'][str(u)];used=int(z.get('referral_renews',0));available=len(z.get('referrals',[]))-used*3
  if used>=3:return send(c,'❌ Ya utilizaste las 3 renovaciones disponibles.')
  if available<3:return send(c,f'❌ Necesitas 3 referidos. Te faltan <b>{3-available}</b>.')
  STATE[c]={'f':'ref_renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVACIÓN POR REFERIDOS</b>\n\nEscribe el usuario SSH que quieres renovar durante <b>24 horas</b>:')
 if x=='userop:delete':
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.')
  u0=st['d']['user'];d=db();isv=any(u0 in z.get('v2ray_accounts',[]) for z in d['users'].values())
  if isv:
   rc,o=delete_v2ray(u0)
  else:
   rc,o=sh(f'pkill -u {q(u0)} 2>/dev/null || true; userdel -r -f {q(u0)}',15)
  if rc==0:
   for z in d['users'].values():
    z['accounts']=[a for a in z.get('accounts',[]) if a!=u0];z['v2ray_accounts']=[a for a in z.get('v2ray_accounts',[]) if a!=u0];z.get('v2ray_expirations',{}).pop(u0,None)
   save_db(d)
  return send(c,('🟢' if rc==0 else '🔴')+f' <b>Cuenta {"eliminada" if rc==0 else "no eliminada"}</b>\n\n👤 <code>{e(u0)}</code>')
 if x=='system_update':
  cur,new,available=update_available();enabled=bool(d.get('auto_update',{}).get('enabled'));status='🟢 Nueva versión disponible' if available else '✅ Sin actualizaciones'
  text=f'🔄 <b>ACTUALIZACIÓN DEL SISTEMA</b>\n\n📌 Versión instalada: <b>{e(cur)}</b>\n🆕 Nueva versión: <b>{e(new)}</b>\n📡 Estado: <b>{status}</b>\n🤖 Actualización automática: <b>'+('ACTIVADA' if enabled else 'DESACTIVADA')+'</b>'
  return edit(c,m,text,[[{'text':'⬇️ Actualizar ahora','callback_data':'system_update_now'}],[{'text':('⛔ Desactivar automática' if enabled else '🤖 Activar automática'),'callback_data':'auto_update_toggle'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if x=='auto_update_toggle':d['auto_update']['enabled']=not bool(d.get('auto_update',{}).get('enabled'));d['auto_update']['checked_at']=0;save_db(d);return cb(c,m,u,i,'system_update')
 if x=='system_update_now':return run_update(c,True)
 if x=='settings':
  if not is_owner(u):return ans(i,'Solo el super admin')
  return edit(c,m,tr(u,'settings'),settings_keyboard())
 if x=='admins':return admin_menu(c,m)
 if x=='admin_list':
  lines=[f'👤 <code>{e(k)}</code> — {e(v.get("name",""))} — {e(v.get("until","unlimited"))}' for k,v in d['admins'].items()]
  return edit(c,m,'👥 <b>LISTA DE ADMINS</b>\n\n'+('\n'.join(lines) if lines else 'No hay admins adicionales.'),ADMIN_MENU)
 if x=='admin_add':STATE[c]={'f':'admin_add','s':'id','d':{}};return send(c,'➕ ID del administrador:')
 if x=='admin_remove':STATE[c]={'f':'admin_remove','s':'id','d':{}};return send(c,'🗑️ ID del administrador:')
 if x=='admin_rename':STATE[c]={'f':'admin_rename','s':'id','d':{}};return send(c,'✏️ ID del administrador:')
 if x=='access_toggle':
  d['access']='public' if d['access']=='private' else 'private';save_db(d);return edit(c,m,f'🔐 <b>ACCESO CAMBIADO</b>\n\nEl acceso ahora está <b>{"PÚBLICO 🟢" if d["access"]=="public" else "PRIVADO 🔴"}</b>.',settings_keyboard())
 if x=='bans':return edit(c,m,'🚫 <b>BANEAR USUARIO</b>',BAN_MENU)
 if x=='ban_add':STATE[c]={'f':'ban_add','s':'id','d':{}};return send(c,'🚫 ID de Telegram a banear:')
 if x=='ban_remove':STATE[c]={'f':'ban_remove','s':'id','d':{}};return send(c,'🔓 ID de Telegram a desbanear:')
 if x=='ban_list':
  lines=[f'• <code>{e(k)}</code> — {e(v.get("name", ""))}' for k,v in d['bans'].items()];return edit(c,m,'🚫 <b>LISTA DE BANS</b>\n\n'+('\n'.join(lines) if lines else 'Vacía.'),BAN_MENU)
 if x=='backup_restore':return edit(c,m,backup_text(d),[[{'text':'💾 Respaldar','callback_data':'backup_menu'},{'text':'♻️ Restaurar','callback_data':'restore'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if x=='backup_menu':return edit(c,m,'💾 <b>RESPALDAR</b>\n\nSelecciona cuándo quieres recibir el documento JSON.',[[{'text':'📤 Enviar ahora','callback_data':'backup_now'}],[{'text':'📅 Enviar diario','callback_data':'backup:daily'}],[{'text':'7️⃣ Cada 7 días','callback_data':'backup:7d'}],[{'text':'1️⃣5️⃣ Cada 15 días','callback_data':'backup:15d'}],[{'text':'3️⃣0️⃣ Cada 30 días','callback_data':'backup:30d'}],[{'text':'☝️ Solo una vez','callback_data':'backup:once'}],[{'text':'🔙 Respaldos','callback_data':'backup_restore'}]])
 if x.startswith('backup:'):return configure_backup(c,x.split(':',1)[1])
 if x=='backup_now':
  fn=backup_now();return send_document(c,fn,'💾 Respaldo actual del sistema.')
 if x=='restore':return send(c,'♻️ <b>RESTAURACIÓN</b>\n\nEnvía ahora el archivo JSON como documento. La restauración se aplicará y el VPS se reiniciará automáticamente.')
 if x=='monetization':return edit(c,m,'💰 <b>MONETIZACIÓN</b>\n\nSelecciona la plataforma que deseas configurar.',MONETIZATION)
 if x=='monetag':return monetag_menu(c,m)
 if x=='monetag_config':STATE[c]={'f':'monetag','s':'sdk','d':{}};return send(c,"💰 <b>MONETAG — PASO 1</b>\n\nPega aquí tu SDK. Ejemplo:\n<code>&lt;script src='//libtl.com/sdk.js' data-zone='11217882' data-sdk='show_11217882'&gt;&lt;/script&gt;</code>")
 if x=='monetag_toggle':
  v=d.get('monetization',{}).get('monetag','')
  if not v:return monetag_menu(c,m)
  try:z=json.loads(v)
  except:z={'sdk':v,'reward':'','url':f'https://t.me/{BOT_USERNAME}?start=adcompleted'}
  z['enabled']=not bool(z.get('enabled',True));d['monetization']['monetag']=json.dumps(z,ensure_ascii=False);save_db(d);return monetag_menu(c,m)
 if x=='adsgram':return adsgram_menu(c,m)
 if x=='adsgram_config':STATE[c]={'f':'adsgram','s':'value','d':{}};return send(c,'📱 <b>ADSGRAM</b>\n\nEnvía el código de configuración de Adsgram.')
 if x=='adsgram_toggle':d['monetization']['adsgram']='' if d.get('monetization',{}).get('adsgram') else 'enabled';save_db(d);return adsgram_menu(c,m)
 if x=='restart_vps':return send(c,'♻️ ¿Reiniciar el VPS ahora?',[[{'text':'✅ REINICIAR VPS','callback_data':'do_reboot'},{'text':'❌ CANCELAR','callback_data':'settings'}]])
 if x=='people':
  total=sum(1 for z in d['users'].values() if z.get('started'))
  return edit(c,m,f'👥 <b>PERSONAS REGISTRADAS</b>\n\nUsuarios que han iniciado el bot con /start: <b>{total}</b>',settings_keyboard())
 if x=='message_users':STATE[c]={'f':'message_users','s':'text','d':{}};return send(c,'📢 Escribe el mensaje que quieres enviar a todos los usuarios registrados:')
 if x=='quotas':return edit(c,m,quota_text(d),QUOTA)
 if x=='quota_public':STATE[c]={'f':'quota_public','s':'days','d':{}};return send(c,'📅 Días para usuarios públicos:')
 if x=='quota_admin':STATE[c]={'f':'quota_admin','s':'days','d':{}};return send(c,'📅 Días para administradores:')
 if x=='security':
  if not is_owner(u):return ans(i,'Solo el super admin')
  stxt='🛡️ <b>SEGURIDAD</b>\n\nAuto banea SSH: <b>'+('ACTIVADO 🟢' if d.get('security',{}).get('auto_ban_ssh') else 'DESACTIVADO 🔴')+'</b>\n\nSi una cuenta supera su límite de conexiones, recibe una advertencia. Al llegar a 3 infracciones, la cuenta se elimina y el usuario recibe aviso.'
  return edit(c,m,stxt,SECURITY_MENU)
 if x=='security:auto':
  d['security']['auto_ban_ssh']=not d['security'].get('auto_ban_ssh',False);save_db(d)
  return edit(c,m,'🛡️ <b>SEGURIDAD ACTUALIZADA</b>\n\nAuto banea SSH: <b>'+('ACTIVADO 🟢' if d['security']['auto_ban_ssh'] else 'DESACTIVADO 🔴')+'</b>',SECURITY_MENU)
 if x=='tools':return edit(c,m,'🛠 <b>HERRAMIENTAS</b>',TOOLS)
 if x.startswith('tool:'):
  if not is_owner(u):return ans(i,'Solo el super admin')
  k=x.split(':')[1];mp={'optimizar':'optimizar.sh','ads':'blockads.sh','torrent':'blocktorrent.sh','speed':'speedtest.sh','scanner':'scanner.sh','update':'update.sh'}
  if k=='files':return edit(c,m,'📁 <b>ARCHIVOS</b>\n\n<pre>'+e(subprocess.getoutput("find /etc/kevintech -maxdepth 2 -type f | sort | head -120"))+'</pre>',TOOLS)
  p=module(mp.get(k,''));return bg(c,k.title(),f'bash {q(p)}',180,TOOLS) if p else send(c,'🔴 Módulo no encontrado.')
 if x.startswith('svc_restart:'):
  k=x.split(':')[1];return bg(c,'Reiniciando '+PROTO[k][0],f'systemctl restart {q(PROTO[k][2])}',30,settings_keyboard())
 if x.startswith('proto:'):
  k=x.split(':',1)[1];v=PROTO[k];ins=installed(k);buttons=[[{'text':'🔄 Reiniciar','callback_data':'svc_restart:'+k}]] if ins else []
  buttons += [[{'text':'🗑️ Desinstalar','callback_data':'un:'+k}]] if ins else [[{'text':'🚀 Instalar','callback_data':'in:'+k}]];buttons += [[{'text':'🔙 Protocolos','callback_data':'home'}]]
  return edit(c,m,f'🌐 <b>{e(v[0])}</b>\n\nEstado: {"🟢 INSTALADO" if ins else "⚪ NO INSTALADO"}\nPuertos: <code>{e(v[3])}</code>\nServicio: <code>{e(v[2])}</code>',buttons)
 if x.startswith('in:') or x.startswith('un:'):
  k=x.split(':')[1];v=PROTO[k];p=module(v[1]);
  if not p:return send(c,'🔴 Script no encontrado.')
  return bg(c,('Instalando ' if x.startswith('in:') else 'Desinstalando ')+v[0],f'bash {q(p)} <<EOF\n{v[4] if x.startswith("in:") else v[5]}\nEOF',360,PK)
 if x=='do_reboot':return bg(c,'Reinicio del VPS','sleep 2; reboot',15,settings_keyboard())

def admin_menu(c,m):return edit(c,m,'👥 <b>ADMINISTRADORES</b>',ADMIN_MENU)
def quota_text(d):
 qx=d['quotas'];return f'''📅 <b>CUOTAS</b>\n\n👥 Público: <b>{qx["public_days"]} días</b> · <b>{qx["public_devices"]} dispositivos/IP</b>\n👨‍💼 Administradores: <b>{qx["admin_days"]} días</b> · <b>{qx["admin_devices"]} dispositivos/IP</b>\n🚀 V2Ray: utiliza automáticamente la cuota pública.\n\n👑 El super admin puede definir días y dispositivos al crear o renovar.'''

def backup_text(d):
 s=d.get('backup_schedule',{});mode=s.get('mode','once');label={'once':'Solo una vez','daily':'Diario','7d':'Cada 7 días','15d':'Cada 15 días','30d':'Cada 30 días'}.get(mode,'Solo una vez');return f'''💾 <b>RESPALDOS Y RESTAURACIÓN</b>\n\n📌 Configuración actual: <b>{label}</b>\n\nPuedes generar un respaldo manual o programarlo. El archivo siempre se entrega como <b>documento JSON</b> al super admin. Para restaurar, envía un documento JSON válido.'''

 d=db();d['backup_schedule']={'mode':mode,'next_at':time.time()};save_db(d);return send(c,'🟢 <b>Respaldo configurado</b>\n\n'+{'once':'Se enviará una sola vez.','daily':'Se enviará diariamente.','7d':'Se enviará cada 7 días.','15d':'Se enviará cada 15 días.','30d':'Se enviará cada 30 días.'}.get(mode,'Se enviará una sola vez.'),[[{'text':'💾 Respaldos y restauración','callback_data':'backup_restore'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]])

def backup_now():
 BACK.mkdir(parents=True,exist_ok=True);fn=BACK/'kevintech_backup.json';fn.write_text(json.dumps(db(),indent=2,ensure_ascii=False));os.chmod(fn,0o600);return fn

def backup_scheduler():
 while True:
  try:
   d=db();s=d.get('backup_schedule',{});mode=s.get('mode','once');next_at=float(s.get('next_at',0) or 0)
   if mode!='once' and next_at<=time.time() or mode=='once' and next_at and next_at<=time.time():
    fn=backup_now();
    try:send_document(OWNER,fn,'💾 <b>Respaldo automático de KevinTech</b>')
    except Exception as er:log('BACKUP SEND '+repr(er))
    if mode=='daily':delta=86400
    elif mode=='7d':delta=7*86400
    elif mode=='15d':delta=15*86400
    elif mode=='30d':delta=30*86400
    else:delta=0
    d=db();d['backup_schedule']['next_at']=time.time()+delta if delta else 0;save_db(d)
  except Exception as er:log('BACKUP SCHED '+repr(er))
  time.sleep(60)

SETTINGS=[[{'text':'🔐 Acceso: PRIVADO','callback_data':'access_toggle'}],[{'text':'👥 Administradores','callback_data':'admins'},{'text':'🌐 Dominio','callback_data':'domain'}],[{'text':'🚫 Banear usuario','callback_data':'bans'},{'text':'💾 Respaldos y restauración','callback_data':'backup_restore'},{'text':'💰 Monetización','callback_data':'monetization'}],[{'text':'👥 Personas registradas','callback_data':'people'},{'text':'📢 Mensaje a usuarios','callback_data':'message_users'}],[{'text':'📅 Cuotas','callback_data':'quotas'},{'text':'♻️ Reiniciar VPS','callback_data':'restart_vps'}],[{'text':'🛡️ Seguridad','callback_data':'security'},{'text':'🛠 Herramientas','callback_data':'tools'}],[{'text':'🔄 Actualizar sistema','callback_data':'system_update'}],[{'text':'🔙 Inicio','callback_data':'home'}]]
ADMIN_MENU=[[{'text':'📋 Lista de admins','callback_data':'admin_list'}],[{'text':'➕ Agregar admin','callback_data':'admin_add'},{'text':'🗑️ Quitar admin','callback_data':'admin_remove'}],[{'text':'✏️ Renombrar admin','callback_data':'admin_rename'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
BAN_MENU=[[{'text':'🚫 Banear usuarios','callback_data':'ban_add'}],[{'text':'🔓 Desbanear','callback_data':'ban_remove'},{'text':'📋 Lista de ban','callback_data':'ban_list'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
QUOTA=[[{'text':'👥 Público','callback_data':'quota_public'},{'text':'👨‍💼 Admin','callback_data':'quota_admin'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
SECURITY_MENU=[[{'text':'🛡️ Auto banea SSH','callback_data':'security:auto'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
MONETIZATION=[[{'text':'💰 Monetag','callback_data':'monetag'},{'text':'📱 Adsgram','callback_data':'adsgram'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]

def settings_keyboard():
 d=db();rows=[r[:] for r in SETTINGS];rows[0]=[{'text':('🔐 Acceso: PÚBLICO 🟢' if d['access']=='public' else '🔐 Acceso: PRIVADO 🔴'),'callback_data':'access_toggle'}];return rows

def monetag_menu(c,m=0):
 d=db();v=d.get('monetization',{}).get('monetag','');configured=bool(v);enabled=True
 if configured:
  try:enabled=bool(json.loads(v).get('enabled',True))
  except:pass
 text='💰 <b>MONETAG</b>\n\nEstado: <b>'+('🟢 ENCENDIDO' if enabled else '⛔ APAGADO')+'</b>' if configured else '💰 <b>MONETAG</b>\n\nEstado: <b>🔴 NO CONFIGURADO</b>'
 if configured:
  try:text+='\n\n🌐 URL: <code>'+e(json.loads(v).get('url',''))+'</code>'
  except:pass
  k=[[{'text':'⛔ Apagar' if enabled else '🟢 Encender','callback_data':'monetag_toggle'}],[{'text':'⚙️ Reconfigurar','callback_data':'monetag_config'}]]
 else:k=[[{'text':'⚙️ Configurar','callback_data':'monetag_config'}]]
 k.append([{'text':'🔙 Monetización','callback_data':'monetization'}]);return edit(c,m,text,k) if m else send(c,text,k)
def adsgram_menu(c,m=0):
 configured=bool(db().get('monetization',{}).get('adsgram',''));text='📱 <b>ADSGRAM</b>\n\nEstado: <b>'+('🟢 CONFIGURADO' if configured else '🔴 NO CONFIGURADO')+'</b>'
 k=[[{'text':'⏻ Apagar','callback_data':'adsgram_toggle'},{'text':'⚙️ Reconfigurar','callback_data':'adsgram_config'}]] if configured else [[{'text':'⚙️ Configurar','callback_data':'adsgram_config'}]]
 k.append([{'text':'🔙 Monetización','callback_data':'monetization'}]);return edit(c,m,text,k) if m else send(c,text,k)
def generate_monetag_html(uid,dat):
 bot_url=dat.get('url') or (f'https://t.me/{BOT_USERNAME}?start=adcompleted' if BOT_USERNAME else '')
 sdk=dat.get('sdk','');reward=dat.get('reward','');m=re.search(r'data-sdk=[\"\']([^\"\']+)',sdk,re.I);ad_fn=m.group(1) if m else ((re.search(r'\b(show_\d+)\b',reward) or re.search(r'\b(show_\d+)\b',sdk)).group(1) if (re.search(r'\b(show_\d+)\b',reward) or re.search(r'\b(show_\d+)\b',sdk)) else '')
 html='''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KEVINTECH MULTI SCRIPT</title>
<script src="https://telegram.org/js/telegram-web-app.js"></script>
'''+sdk+'''
<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#03050a;color:#fff;font-family:Arial,sans-serif;display:flex;align-items:center;justify-content:center}.panel{width:min(390px,90%);text-align:center}.logo{width:82px;height:82px;margin:auto auto 24px;border-radius:25px;background:linear-gradient(135deg,#00e5ff,#0077ff,#8b5cf6);display:flex;align-items:center;justify-content:center;font-size:25px;font-weight:900}button{width:100%;padding:17px;border:0;border-radius:16px;background:linear-gradient(135deg,#00e5ff,#0077ff);color:white;font-weight:800}p{color:#aaa;line-height:1.6}</style>
</head>
<body><main class="panel"><div class="logo">KT</div><h1>Acceso Premium</h1><p>Mira un anuncio para continuar.</p><button id="play">▶ VER ANUNCIO</button><p>© KEVINTECH MULTI SCRIPT</p></main>
<script>const tg=window.Telegram.WebApp;tg.ready();tg.expand();document.getElementById('play').onclick=async()=>{try{if(!'''+json.dumps(ad_fn)+''')throw new Error('SDK');await window['''+json.dumps(ad_fn)+''']();window.location.href='''+json.dumps(bot_url)+''';}catch(e){alert('Anuncio no disponible');}};
/* Rewarded Interstitial configurado por el super admin */
'''+reward+'''
</script></body></html>'''
 fn=BACK/'monetag_webapp.html';fn.write_text(html,encoding='utf-8');os.chmod(fn,0o600);return fn

def admin_text(c,t):
 st=STATE.get(c);d=db();f=st['f'];step=st['s'];dat=st['d']
 if f=='admin_add':
  if step=='id' and t.isdigit():dat['id']=int(t);st['s']='name';return send(c,'👤 Nombre del administrador:')
  if step=='name':dat['name']=t[:80];st['s']='until';return send(c,'📅 Fecha de vencimiento (YYYY-MM-DD) o escribe <code>ilimitado</code>:')
  if step=='until':
   until='unlimited' if t.lower()=='ilimitado' else t
   if until!='unlimited':
    try:datetime.date.fromisoformat(until)
    except:return send(c,'❌ Fecha inválida. Usa YYYY-MM-DD o ilimitado.')
   d['admins'][str(dat['id'])]={'name':dat['name'],'until':until};save_db(d);STATE.pop(c,None)
   try:send(dat['id'],f'👨‍💼 Fuiste agregado como administrador por <b>{e(dat["name"])}</b>.\nVencimiento: <code>{e(until)}</code>')
   except:pass
   return send(c,'🟢 Administrador agregado y notificado.',ADMIN_MENU)
 if f=='admin_remove' and step=='id':
  if not t.isdigit():return send(c,'❌ ID inválido.')
  aid=t;ex=d['admins'].pop(aid,None);save_db(d);STATE.pop(c,None)
  if ex:
   try:send(int(aid),'⚠️ Tu acceso de administrador fue retirado.')
   except:pass
   return send(c,'🟢 Administrador eliminado y notificado.',ADMIN_MENU)
  return send(c,'❌ Ese ID no es administrador.',ADMIN_MENU)
 if f=='admin_rename':
  if step=='id' and t.isdigit():
   if t not in d['admins']:STATE.pop(c,None);return send(c,'❌ ID no encontrado.',ADMIN_MENU)
   dat['id']=t;st['s']='name';return send(c,'✏️ Nuevo nombre:')
  if step=='name':d['admins'][dat['id']]['name']=t[:80];save_db(d);STATE.pop(c,None);return send(c,'🟢 Administrador renombrado.',ADMIN_MENU)
 if f in ('ban_add','ban_remove') and step=='id':
  if not t.isdigit():return send(c,'❌ ID inválido.')
  if f=='ban_add':
   if int(t)==OWNER:return send(c,'❌ No puedes banear al super admin.')
   d['bans'][t]={'name':d['users'].get(t,{}).get('name',''),'date':time.strftime('%F')};save_db(d);STATE.pop(c,None)
   try:send(int(t),'🚫 Has sido baneado del bot por el super admin.')
   except:pass
   return send(c,'🟢 Usuario baneado y notificado.',BAN_MENU)
  existed=d['bans'].pop(t,None);save_db(d);STATE.pop(c,None)
  if existed:
   try:send(int(t),'🟢 Has sido desbaneado del bot.')
   except:pass
   return send(c,'🟢 Usuario desbaneado y notificado.',BAN_MENU)
  return send(c,'❌ Ese ID no está baneado.',BAN_MENU)
 if f=='message_users' and step=='text':
  STATE.pop(c,None);ok=0;fail=0
  for sid in d['users']:
   try:send(int(sid),'📢 <b>Mensaje del administrador</b>\n\n'+e(t));ok+=1
   except Exception as er:fail+=1;log('MSG '+sid+' '+repr(er))
  return send(c,f'🟢 Enviados: <b>{ok}</b>\n🔴 No entregados: <b>{fail}</b>.',settings_keyboard())
 if f=='monetag' and step=='sdk':dat['sdk']=t.strip();st['s']='reward';return send(c,'✅ Script guardado.\n\n<b>Paso 2:</b> Ahora copia el código de activación del formato <b>Rewarded Interstitial</b> (el bloque que contiene <code>show_XXXXXXX().then(...)</code>).\n\nPor favor, pégalo aquí y envíamelo.')
 if f=='monetag' and step=='reward':dat['reward']=t.strip();st['s']='url';return send(c,'🌐 <b>Paso 3</b>\n\nIngresa la URL de tu bot. Ejemplo:\n<code>https://t.me/tu_bot</code>')
 if f=='monetag' and step=='url':dat['url']=t.strip();dat['enabled']=True;d['monetization']['monetag']=json.dumps(dat,ensure_ascii=False);save_db(d);STATE.pop(c,None);fn=generate_monetag_html(c,dat);send(c,'🟢 <b>Monetag configurado correctamente.</b>');return send_document(c,fn,'📄 HTML personalizado de Monetag.')
 if f=='adsgram' and step=='value':d['monetization']['adsgram']=t.strip();save_db(d);STATE.pop(c,None);return send(c,'🟢 Configuración de Adsgram guardada.',MONETIZATION)
 if f=='domain' and step=='value':
  val=t.strip();cfg=BASE/'config.conf';lines=cfg.read_text(errors='ignore').splitlines() if cfg.exists() else [];found=False
  for i,l in enumerate(lines):
   if l.startswith('SERVER_DOMAIN='):lines[i]=f'SERVER_DOMAIN="{val}"';found=True
  if not found:lines.append(f'SERVER_DOMAIN="{val}"')
  cfg.write_text('\n'.join(lines)+'\n');STATE.pop(c,None);return send(c,'🟢 Dominio actualizado.',settings_keyboard())
 if f in ('quota_public','quota_admin'):
  key='public' if f=='quota_public' else 'admin'
  if step=='days':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Días inválidos.')
   dat['days']=int(t);st['s']='devices';return send(c,'📱 Máximo de dispositivos/IP:')
  if step=='devices':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Número inválido.')
   d['quotas'][key+'_days']=dat['days'];d['quotas'][key+'_devices']=int(t);save_db(d);STATE.pop(c,None);return send(c,'🟢 Cuota actualizada.',QUOTA)

_original_process=process_text
def process_text(c,t,chat_type=None):
 CHAT_TYPES[c]=chat_type or CHAT_TYPES.get(c,'private')
 registered(c)
 if is_owner(c) and c in STATE and STATE[c]['f'] in ('admin_add','admin_remove','admin_rename','ban_add','ban_remove','message_users','monetag','adsgram','domain','quota_public','quota_admin'):
  return admin_text(c,t)
 st=STATE.get(c)
 if st and st.get('f')=='ref_renew' and st.get('s')=='u':
  username=t.strip()
  if not userexists(username):return send(c,'❌ Usuario SSH no encontrado. Escribe otro:')
  d=db();z=d['users'][str(c)];used=int(z.get('referral_renews',0));available=len(z.get('referrals',[]))-used*3
  if used>=3 or available<3:return send(c,'❌ No tienes una renovación disponible.')
  exp=subprocess.getoutput("date -d '+24 hours' +%F");rc,o=sh(f'chage -E {q(exp)} {q(username)}',10)
  if rc!=0:return send(c,'🔴 No se pudo renovar la cuenta.\n<pre>'+e(o)+'</pre>')
  z['referral_renews']=used+1;save_db(d);STATE.pop(c,None);return send(c,'🎉 <b>Renovación realizada</b>\n\n👤 Cuenta: <code>'+e(username)+'</code>\n⏱ Duración: <b>24 horas</b>\n🎁 Referidos usados: <b>3</b>')
 if st and st.get('f')=='language':return _original_process(c,t)
 return _original_process(c,t)

def restore_document(c,msg):
 if not is_owner(c):return
 doc=msg.get('document',{});name=doc.get('file_name','')
 if not name.lower().endswith('.json'):return send(c,'❌ Solo se acepta un archivo JSON.')
 try:
  z=api('getFile',{'file_id':doc['file_id']});fp=z['result']['file_path'];token=ENV.read_text().split('BOT_TOKEN=',1)[1].splitlines()[0].strip().strip('"');url=f'https://api.telegram.org/file/bot{token}/{fp}';raw=urllib.request.urlopen(url,timeout=30).read();new=json.loads(raw.decode())
  if not isinstance(new,dict) or 'quotas' not in new or 'users' not in new:raise ValueError('JSON incompatible')
  BACK.mkdir(parents=True,exist_ok=True);(BACK/'restore_before.json').write_text(DB.read_text() if DB.exists() else '{}');current=db(); preserved={k:current.get(k) for k in ('backup_schedule','security')}
  for k,v in preserved.items():
   if k not in new:new[k]=v
  save_db(new);send(c,'🟢 <b>Restauración completada.</b>\n\n♻️ El VPS se reiniciará para aplicar la restauración.');time.sleep(2);sh('reboot',10)
 except Exception as er:log('RESTORE '+repr(er));send(c,'🔴 No se pudo restaurar el JSON.')

def ssh_connections_by_user():
 rc,out=sh("ss -tnp state established '( sport = :22 )' 2>/dev/null",8)
 counts={}
 for line in out.splitlines():
  m=re.search(r'users:\(\"sshd\",pid=(\d+)',line)
  if not m:continue
  pid=m.group(1);user=subprocess.getoutput(f"ps -o user= -p {pid} 2>/dev/null").strip()
  if user and user!='root':counts[user]=counts.get(user,0)+1
 return counts

def v2ray_expiration_monitor():
 while True:
  try:
   d=db();changed=False;today=datetime.datetime.now().date()
   for sid,z in d['users'].items():
    for username,ds in list(z.get('v2ray_expirations',{}).items()):
     try:expired=datetime.datetime.strptime(ds,'%d/%m/%Y').date()<today
     except:expired=False
     if expired:
      rc,_=delete_v2ray(username)
      if rc==0:
       z['accounts']=[a for a in z.get('accounts',[]) if a!=username];z['v2ray_accounts']=[a for a in z.get('v2ray_accounts',[]) if a!=username];z['v2ray_expirations'].pop(username,None);changed=True
       try:send(int(sid),f'⌛ <b>Cuenta V2Ray vencida</b>\n\nLa cuenta <code>{e(username)}</code> fue eliminada al finalizar su periodo.')
       except:pass
   if changed:save_db(d)
  except Exception as ex:log('V2 EXPIRY '+repr(ex))
  time.sleep(60)

def security_monitor():
 while True:
  try:
   d=db()
   if d.get('security',{}).get('auto_ban_ssh'):
    counts=ssh_connections_by_user();viol=d['security'].setdefault('violations',{})
    for user,n in counts.items():
     if not userexists(user):continue
     owner=None
     for sid,z in d['users'].items():
      if user in z.get('accounts',[]):owner=int(sid);break
     if owner is None or owner==OWNER:continue
     limit=d['quotas']['admin_devices' if is_admin(owner) else 'public_devices']
     if n>int(limit):
      key=user;viol[key]=int(viol.get(key,0))+1;step=viol[key]
      if step>=3:
       sh(f'pkill -u {q(user)} 2>/dev/null || true; userdel -r -f {q(user)}',15)
       d['security']['violations'].pop(key,None)
       for z in d['users'].values():z['accounts']=[a for a in z.get('accounts',[]) if a!=user];z['v2ray_accounts']=[a for a in z.get('v2ray_accounts',[]) if a!=user]
       save_db(d)
       try:send(owner,f'🚫 <b>Cuenta eliminada por seguridad</b>\n\n👤 Cuenta: <code>{e(user)}</code>\n⚠️ Superó el límite de conexiones 3 veces.')
       except:pass
       try:send(owner,f'🚫 <b>Tu cuenta fue eliminada</b>\n\nLa cuenta <code>{e(user)}</code> superó el límite de conexiones 3 veces y fue eliminada automáticamente.')
       except:pass
      else:
       save_db(d)
       try:send(owner,f'⚠️ <b>Advertencia de seguridad</b>\n\n👤 Cuenta: <code>{e(user)}</code>\n🔌 Conexiones: <b>{n}</b>\n📌 Límite: <b>{limit}</b>\n⚠️ Infracción: <b>{step}/3</b>')
       except:pass
    # reset users no longer exceeding limit
    for k in list(viol):
     if k not in counts or counts.get(k,0)<=0:viol.pop(k,None)
    save_db(d)
  except Exception as ex:log('SECURITY '+repr(ex))
  time.sleep(30)

def main():
 global BOT_USERNAME
 env();load_db();LOG.parent.mkdir(parents=True,exist_ok=True);LOG.touch();LOG.chmod(0o600);api('deleteWebhook',{'drop_pending_updates':'false'})
 try:BOT_USERNAME=api('getMe')['result'].get('username','')
 except:BOT_USERNAME=''
 threading.Thread(target=backup_scheduler,daemon=True).start()
 threading.Thread(target=security_monitor,daemon=True).start()
 threading.Thread(target=v2ray_expiration_monitor,daemon=True).start();threading.Thread(target=auto_update_monitor,daemon=True).start()
 off=int(OFF.read_text()) if OFF.exists() and OFF.read_text().strip().isdigit() else 0;log('BOT ONLINE')
 while True:
  try:
   r=api('getUpdates',{'offset':off,'timeout':30,'allowed_updates':json.dumps(['message','callback_query'])})
   for u in r.get('result',[]):
    off=u['update_id']+1;OFF.write_text(str(off))
    try:
     if 'callback_query' in u:
      z=u['callback_query'];m=z['message'];cb(m['chat']['id'],m['message_id'],z['from']['id'],z['id'],z.get('data',''),m['chat'].get('type','private'))
     elif 'message' in u:
      m=u['message'];c=m['chat']['id'];CHAT_TYPES[c]=m.get('chat',{}).get('type','private')
      if m.get('document'):restore_document(c,m)
      elif m.get('text'):process_text(c,m['text'],CHAT_TYPES[c])
    except Exception as er:log('UPDATE '+repr(er))
  except Exception as er:log('POLL '+repr(er));time.sleep(2)
if __name__=='__main__':main()
