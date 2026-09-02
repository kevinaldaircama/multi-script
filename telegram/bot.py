#!/usr/bin/env python3
# KevinTech Telegram Bot - panel de usuarios + super admin
import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,shlex,datetime
from pathlib import Path

BASE=Path('/etc/kevintech'); TD=BASE/'telegram'; ENV=TD/'.env'; LOG=TD/'logs'/'bot.log'; OFF=TD/'offset'
DB=TD/'data.json'; BACK=TD/'backups'; STATE={}; API=''; OWNER=0; BOT_USERNAME=''

DEFAULT={
 'access':'private','admins':{},'bans':{},'users':{},
 'quotas':{'public_days':7,'public_devices':1,'admin_days':30,'admin_devices':2},
 'monetization':{'monetag':'','miniapp':''}, 'referrals':{}, 'referral_meta':{}
}

def log(s):
 LOG.parent.mkdir(parents=True,exist_ok=True); LOG.open('a').write(time.strftime('[%F %T] ')+str(s)+'\n')

def load_db():
 DB.parent.mkdir(parents=True,exist_ok=True)
 if not DB.exists(): DB.write_text(json.dumps(DEFAULT,indent=2,ensure_ascii=False)); return json.loads(json.dumps(DEFAULT))
 try:
  d=json.loads(DB.read_text(errors='ignore'))
 except Exception: d=json.loads(json.dumps(DEFAULT))
 for k,v in DEFAULT.items():
  if k not in d:d[k]=json.loads(json.dumps(v))
 if not isinstance(d.get('referrals'),dict):d['referrals']={}
 if not isinstance(d.get('referral_meta'),dict):d['referral_meta']={}
 for k in ('admins','bans','users'):
  if not isinstance(d.get(k),dict):d[k]={}
 if not isinstance(d.get('quotas'),dict):d['quotas']=DEFAULT['quotas'].copy()
 for k,v in DEFAULT['quotas'].items(): d['quotas'].setdefault(k,v)
 d.setdefault('monetization',DEFAULT['monetization'].copy())
 return d

def save_db(d):
 DB.write_text(json.dumps(d,indent=2,ensure_ascii=False)); os.chmod(DB,0o600)

def env():
 global API,OWNER,BOT_USERNAME
 d={}
 for l in ENV.read_text(errors='ignore').splitlines():
  if '=' in l and not l.lstrip().startswith('#'):
   k,v=l.split('=',1);d[k]=v.strip().strip('"').strip("'")
 t=d.get('BOT_TOKEN',''); a=d.get('ADMIN_ID','')
 if not re.fullmatch(r'\d+:[A-Za-z0-9_-]+',t) or not a.isdigit(): raise SystemExit('Credenciales inválidas en .env')
 OWNER=int(a); API='https://api.telegram.org/bot'+t
 try: BOT_USERNAME=api('getMe')['result'].get('username','')
 except Exception: BOT_USERNAME=''

def api(m,data=None,timeout=40):
 r=urllib.request.Request(API+'/'+m,data=urllib.parse.urlencode(data or {}).encode())
 with urllib.request.urlopen(r,timeout=timeout) as x:z=json.loads(x.read().decode())
 if not z.get('ok'):raise RuntimeError(z)
 return z

def e(x):return str(x).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
def send(c,t,k=None):
 d={'chat_id':c,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true'}
 if k:d['reply_markup']=json.dumps({'inline_keyboard':localize_keyboard(c,k)},ensure_ascii=False)
 return api('sendMessage',d)
def edit(c,m,t,k=None):
 try:return api('editMessageText',{'chat_id':c,'message_id':m,'text':t,'parse_mode':'HTML','disable_web_page_preview':'true','reply_markup':json.dumps({'inline_keyboard':localize_keyboard(c,k)},ensure_ascii=False) if k else None})
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
def bg(c,title,cmd,timeout=300,k=None,restart_after=False):
 send(c,f'⚡ <b>{e(title)}</b>\n\n🟡 Operación iniciada...')
 def w():
  rc,out=sh(cmd,timeout)
  if len(out)>4500:out=out[-4500:]
  send(c,('🟢' if rc==0 else '🔴')+f' <b>{e(title)}</b>\n\n<pre>{e(out or "Terminado sin salida")}</pre>',k)
  if rc==0 and restart_after: time.sleep(2); sh('reboot',10)
 threading.Thread(target=w,daemon=True).start()

def db():return load_db()
def is_owner(uid):return uid==OWNER
def is_admin(uid):
 if uid==OWNER:return True
 d=db(); a=d['admins'].get(str(uid));
 if not a:return False
 if a.get('until') and a['until']!='unlimited':
  try:
   if datetime.datetime.now().date()>datetime.date.fromisoformat(a['until']):
    d['admins'].pop(str(uid),None);save_db(d);return False
  except:pass
 return True
def allowed(uid):
 d=db();return is_admin(uid) or d.get('access')=='public'
def banned(uid):return str(uid) in db()['bans']
def registered(uid,name=None,username=None):
 d=db(); k=str(uid)
 if k not in d['users']:
  d['users'][k]={'id':uid,'name':name or str(uid),'username':username or '','created':time.strftime('%F'),'accounts':[],'referral_rewarded':False}
  save_db(d)
 else:
  changed=False
  if name and d['users'][k].get('name')!=name:d['users'][k]['name']=name;changed=True
  if username is not None and d['users'][k].get('username','')!=username:d['users'][k]['username']=username;changed=True
  if changed:save_db(d)

LANGS={
 'es':{'name':'🇪🇸 Español','title':'🎨 <b>KEVINTECH MULTI SCRIPT</b>','panel':'⚙️ <b>Panel de administración</b>','users':'👤 Usuarios','settings':'⚙️ Ajustes','create':'➕ Crear cuenta','renew':'♻️ Renovar','list':'📋 Lista','online':'🟢 Online','account':'👤 Cuenta','delete':'🗑️ Eliminar cuenta','ref':'🔗 Referidos','back':'🔙 Regresar','language':'🌐 Idioma','private':'PRIVADO','public':'PÚBLICO','account_prompt':'👤 <b>CUENTA</b>\n\nEscribe tu usuario para consultar la información:','delete_prompt':'🗑️ <b>ELIMINAR CUENTA</b>\n\nEscribe el usuario:','create_prompt':'➕ <b>CREAR CUENTA</b>\n\nUsuario:','renew_prompt':'♻️ <b>RENOVAR</b>\n\nUsuario:'},
 'en':{'name':'🇺🇸 English','title':'🎨 <b>KEVINTECH MULTI SCRIPT</b>','panel':'⚙️ <b>Administration Panel</b>','users':'👤 Users','settings':'⚙️ Settings','create':'➕ Create account','renew':'♻️ Renew','list':'📋 List','online':'🟢 Online','account':'👤 Account','delete':'🗑️ Delete account','ref':'🔗 Referrals','back':'🔙 Back','language':'🌐 Language','private':'PRIVATE','public':'PUBLIC','account_prompt':'👤 <b>ACCOUNT</b>\n\nEnter the username to view its information:','delete_prompt':'🗑️ <b>DELETE ACCOUNT</b>\n\nEnter the username:','create_prompt':'➕ <b>CREATE ACCOUNT</b>\n\nUsername:','renew_prompt':'♻️ <b>RENEW</b>\n\nEnter the username:'},
 'pt':{'name':'🇧🇷 Português','title':'🎨 <b>KEVINTECH MULTI SCRIPT</b>','panel':'⚙️ <b>Painel de administração</b>','users':'👤 Usuários','settings':'⚙️ Ajustes','create':'➕ Criar conta','renew':'♻️ Renovar','list':'📋 Lista','online':'🟢 Online','account':'👤 Conta','delete':'🗑️ Excluir conta','ref':'🔗 Referidos','back':'🔙 Voltar','language':'🌐 Idioma','private':'PRIVADO','public':'PÚBLICO','account_prompt':'👤 <b>CONTA</b>\n\nDigite o usuário para ver as informações:','delete_prompt':'🗑️ <b>EXCLUIR CONTA</b>\n\nDigite o usuário:','create_prompt':'➕ <b>CRIAR CONTA</b>\n\nUsuário:','renew_prompt':'♻️ <b>RENOVAR</b>\n\nDigite o usuário:'}
}

def lang(uid):
 d=db(); return d.get('users',{}).get(str(uid),{}).get('lang','es')

def tr(uid,key,default=None):
 return LANGS.get(lang(uid),LANGS['es']).get(key,default or key)

def language_menu():
 return [[{'text':v['name'],'callback_data':'lang:'+k}] for k,v in LANGS.items()]

def localize_keyboard(uid,kb):
 if not kb:return kb
 code=lang(uid)
 if code=='es':return kb
 maps={
  'en':{'👤 Usuarios':'👤 Users','⚙️ Ajustes':'⚙️ Settings','➕ Crear cuenta':'➕ Create account','♻️ Renovar':'♻️ Renew','📋 Lista':'📋 List','🟢 Online':'🟢 Online','👤 Cuenta':'👤 Account','🗑️ Eliminar cuenta':'🗑️ Delete account','🔗 Referidos':'🔗 Referrals','🔙 Regresar':'🔙 Back','🔙 Inicio':'🔙 Home','🔙 Ajustes':'🔙 Settings','👥 Administradores':'👥 Administrators','🌐 Dominio':'🌐 Domain','🚫 Banear usuario':'🚫 Ban user','♻️ Restauración':'♻️ Restore','💾 Respaldar JSON':'💾 JSON Backup','💰 Monetización':'💰 Monetization','👥 Personas registradas':'👥 Registered people','📢 Mensaje a usuarios':'📢 Message users','📅 Cuotas':'📅 Quotas','♻️ Reiniciar VPS':'♻️ Restart VPS','🛠 Herramientas':'🛠 Tools','📋 Lista de admins':'📋 Admin list','➕ Agregar admin':'➕ Add admin','🗑️ Quitar admin':'🗑️ Remove admin','✏️ Renombrar admin':'✏️ Rename admin','🚫 Banear usuarios':'🚫 Ban users','🔓 Desbanear':'🔓 Unban','📋 Lista de ban':'📋 Ban list','👥 Público':'👥 Public','👨‍💼 Admin':'👨‍💼 Admin','💰 Monetag':'💰 Monetag','📱 Mini App':'📱 Mini App','🔐 Acceso: PÚBLICO 🟢':'🔐 Access: PUBLIC 🟢','🔐 Acceso: PRIVADO 🔴':'🔐 Access: PRIVATE 🔴'},
  'pt':{'👤 Usuarios':'👤 Usuários','⚙️ Ajustes':'⚙️ Ajustes','➕ Crear cuenta':'➕ Criar conta','♻️ Renovar':'♻️ Renovar','📋 Lista':'📋 Lista','🟢 Online':'🟢 Online','👤 Cuenta':'👤 Conta','🗑️ Eliminar cuenta':'🗑️ Excluir conta','🔗 Referidos':'🔗 Indicados','🔙 Regresar':'🔙 Voltar','🔙 Inicio':'🔙 Início','🔙 Ajustes':'🔙 Ajustes','👥 Administradores':'👥 Administradores','🌐 Dominio':'🌐 Domínio','🚫 Banear usuario':'🚫 Banir usuário','♻️ Restauración':'♻️ Restauração','💾 Respaldar JSON':'💾 Backup JSON','💰 Monetización':'💰 Monetização','👥 Personas registradas':'👥 Pessoas registradas','📢 Mensaje a usuarios':'📢 Mensagem aos usuários','📅 Cuotas':'📅 Cotas','♻️ Reiniciar VPS':'♻️ Reiniciar VPS','🛠 Herramientas':'🛠 Ferramentas','📋 Lista de admins':'📋 Lista de admins','➕ Agregar admin':'➕ Adicionar admin','🗑️ Quitar admin':'🗑️ Remover admin','✏️ Renombrar admin':'✏️ Renomear admin','🚫 Banear usuarios':'🚫 Banir usuários','🔓 Desbanear':'🔓 Desbanir','📋 Lista de ban':'📋 Lista de banimentos','👥 Público':'👥 Público','👨‍💼 Admin':'👨‍💼 Admin','💰 Monetag':'💰 Monetag','📱 Mini App':'📱 Mini App','🔐 Acceso: PÚBLICO 🟢':'🔐 Access: PUBLIC 🟢','🔐 Acceso: PRIVADO 🔴':'🔐 Access: PRIVATE 🔴'}
 }
 mp=maps.get(code,{})
 return [[{'text':mp.get(b.get('text'),b.get('text','')),'callback_data':b.get('callback_data','')} for b in row] for row in kb]

def home(uid):
 rows=[[{'text':tr(uid,'users'),'callback_data':'users'},{'text':tr(uid,'ref'),'callback_data':'referrals'}]]
 if is_owner(uid):rows.append([{'text':tr(uid,'settings'),'callback_data':'settings'}])
 rows.append([{'text':tr(uid,'language'),'callback_data':'language'}])
 return rows

def users_menu(uid):
 return [[{'text':tr(uid,'create'),'callback_data':'create'},{'text':tr(uid,'renew'),'callback_data':'renew'}],[{'text':tr(uid,'list'),'callback_data':'list'},{'text':tr(uid,'online'),'callback_data':'online'}],[{'text':tr(uid,'account'),'callback_data':'account'},{'text':tr(uid,'delete'),'callback_data':'delete'}],[{'text':tr(uid,'ref'),'callback_data':'referrals'},{'text':tr(uid,'back'),'callback_data':'home'}]]

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

def info():
 d=db();ip=(subprocess.getoutput('curl -4 -fsS --max-time 4 ifconfig.me 2>/dev/null') or (subprocess.getoutput('hostname -I').split() or ['N/D'])[0]);cfg=BASE/'config.conf';domain='No configurado'
 if cfg.exists():
  for l in cfg.read_text(errors='ignore').splitlines():
   if l.startswith('SERVER_DOMAIN='):domain=l.split('=',1)[1].strip().strip('"') or 'No configurado'
 return f'''🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Panel de administración</b>\n\n🖥 <b>Servidor</b>\n• IP: <code>{e(ip)}</code>\n• Dominio: <code>{e(domain)}</code>\n• Host: <code>{e(subprocess.getoutput("hostname"))}</code>\n• Uptime: <code>{e(subprocess.getoutput("uptime -p"))}</code>\n\n👥 Personas registradas: <b>{len(d["users"])}</b>'''

def userlist():
 a=[]
 for u in subprocess.getoutput("awk -F: '$3>=1000&&$1!=\"nobody\"{print $1}' /etc/passwd").splitlines():a.append(u)
 return '📋 <b>USUARIOS SSH</b>\n\n'+('\n'.join('• <code>'+e(x)+'</code>' for x in a) if a else 'No hay usuarios.')+f'\n\nTotal: <b>{len(a)}</b>'

def quota(uid):
 d=db();return d['quotas']['admin_days' if is_admin(uid) else 'public_days'],d['quotas']['admin_devices' if is_admin(uid) else 'public_devices']

def account_info(uid,username):
 if not userexists(username):return '❌ Esa cuenta no existe.'
 exp=subprocess.getoutput(f"chage -l {q(username)} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'") or 'No disponible'
 lim='Ilimitado';p=BASE/'limits'/username
 if p.exists():lim=p.read_text(errors='ignore').strip() or 'Ilimitado'
 d=db();owner='—'
 for cid,x in d['users'].items():
  if username in x.get('accounts',[]):owner=x.get('name',cid);break
 return f'''👤 <b>INFORMACIÓN DE CUENTA</b>\n\n• Usuario: <code>{e(username)}</code>\n• Propietario: <code>{e(owner)}</code>\n• Expira: <code>{e(exp)}</code>\n• Límite de dispositivos/IP: <code>{e(lim)}</code>'''

def userexists(u):return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',u,re.I)) and sh(f'id {q(u)} >/dev/null 2>&1',3)[0]==0

def account_message(c,d,renew=False):
 u=d['user'];pw=d.get('pass');days=int(d['days']);exp=subprocess.getoutput(f"chage -l {q(u)} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'") or subprocess.getoutput(f"date -d '+{days} days' '+%d/%m/%Y'");ip=(subprocess.getoutput('curl -4 -fsS --max-time 4 ifconfig.me 2>/dev/null') or (subprocess.getoutput('hostname -I').split() or ['0.0.0.0'])[0]).strip();cfg=BASE/'config.conf';domain=''
 if cfg.exists():
  for l in cfg.read_text(errors='ignore').splitlines():
   if l.startswith('SERVER_DOMAIN='):domain=l.split('=',1)[1].strip().strip('"').strip("'")
 host=domain or ip
 title='♻️ CUENTA RENOVADA EXITOSAMENTE' if renew else '🎉 CUENTA CREADA EXITOSAMENTE'
 lim=d.get('limit','Ilimitado')
 return f'''<b>{title}</b>\n\n━━━━━━━━━━━━━━━━━━━━\n👤 <b>DATOS DEL USUARIO</b>\n━━━━━━━━━━━━━━━━━━━━\n• Usuario: <code>{e(u)}</code>\n• Contraseña: <code>{e(pw or '********')}</code>\n• Expira: <code>{e(exp)}</code>\n• Duración: <code>{days} días</code>\n• Dispositivos/IP: <code>{e(lim)}</code>\n\n━━━━━━━━━━━━━━━━━━━━\n🌐 <b>SERVIDOR</b>\n━━━━━━━━━━━━━━━━━━━━\n• Dominio: <code>{e(domain or 'No configurado')}</code>\n• IP: <code>{e(ip)}</code>\n\nHTTP/SSH:\n<code>{e(host)}:443@{e(u)}:{e(pw or '********')}</code>\n<code>{e(host)}:80@{e(u)}:{e(pw or '********')}</code>\n<code>{e(host)}:8080@{e(u)}:{e(pw or '********')}</code>\n\nUDP Custom:\n<code>{e(host)}:1-65535@{e(u)}:{e(pw or '********')}</code>\n\nℹ️ Si no hay dominio configurado, se utiliza la IP.'''

def send_document(c,path,caption='',k=None):
 try:
  boundary='----KevinTechBoundary'+str(int(time.time()*1000))
  body=[]
  def field(name,value):
   body.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
  field('chat_id',str(c));field('caption',caption);field('parse_mode','HTML')
  if k: field('reply_markup',json.dumps({'inline_keyboard':localize_keyboard(c,k)},ensure_ascii=False))
  data=path.read_bytes();fn=path.name
  body.append(f'--{boundary}\r\nContent-Disposition: form-data; name="document"; filename="{fn}"\r\nContent-Type: application/json\r\n\r\n'.encode()+data+b'\r\n')
  body.append(f'--{boundary}--\r\n'.encode())
  req=urllib.request.Request(API+'/sendDocument',data=b''.join(body),headers={'Content-Type':f'multipart/form-data; boundary={boundary}'})
  with urllib.request.urlopen(req,timeout=40) as r:return json.loads(r.read().decode())
 except Exception as er:
  log(f'SEND_DOCUMENT {c} {er!r}');return send(c,'🔴 No se pudo enviar el documento.',k)

def ssh_online():
 # Cuenta conexiones SSH TCP establecidas, no terminales del servidor.
 rows=[]
 out=subprocess.getoutput("ss -tnp state established '( sport = :22 or sport = :90 or sport = :143 or sport = :109 )' 2>/dev/null")
 for line in out.splitlines()[1:]:
  if 'users:((' not in line:continue
  m=re.search(r'users:\(\(\"[^"]+\",pid=(\d+)',line)
  if not m:continue
  pid=m.group(1);usr=subprocess.getoutput(f'ps -o user= -p {q(pid)} 2>/dev/null').strip()
  if usr and usr not in ('root','sshd','dropbear') and usr not in rows:rows.append(usr)
 return '🟢 <b>CUENTAS SSH ONLINE</b>\n\n'+('\n'.join('• <code>'+e(x)+'</code>' for x in rows) if rows else 'No hay cuentas SSH conectadas.')+f'\n\nTotal: <b>{len(rows)}</b>'

def process_text(c,t):
 d=db();uid=c
 if banned(uid):return send(c,'🚫 Tu acceso está bloqueado.')
 registered(uid)
 if not allowed(uid):return send(c,'🔒 El bot está en modo privado.')
 st=STATE.get(c)
 if not st:
  cmd=t.split()[0].lower() if t.split() else ''
  if cmd in ('/start','/star','/menu'):return send(c,tr(uid,'title')+'\n\n'+tr(uid,'panel'),home(uid))
  if cmd=='/referidos':
   link=f'https://t.me/{BOT_USERNAME}?start=ref_{uid}' if BOT_USERNAME else f'/start ref_{uid}'
   n=sum(1 for v in d.get('referrals',{}).values() if str(v)==str(uid));used=int(d.get('referral_meta',{}).get(str(uid),{}).get('renewals',0));available=max(0,min(3-used,n//3))
   return send(c,f'🔗 <b>REFERIDOS</b>\n\n🔗 <code>{e(link)}</code>\n👥 Referidos válidos: <b>{n}</b>\n♻️ Renovaciones disponibles: <b>{available}</b>')
  return None
 f,step,dat=st['f'],st['s'],st['d']
 if step=='u' and f in ('create','renew','delete','account'):
  u=t.strip()
  if f in ('delete','account') and not userexists(u):return send(c,'❌ Usuario no encontrado. Escribe otro:')
  if f=='renew' and not userexists(u):return send(c,'❌ Usuario no encontrado.')
  if f=='create' and userexists(u):return send(c,'❌ Usuario ya existe.')
  dat['user']=u
  if f=='account':STATE.pop(c,None);return send(c,account_info(c,u),users_menu(c))
  if f=='delete':return send(c,f'⚠️ ¿Eliminar la cuenta <code>{e(u)}</code>?',[[{'text':'✅ ELIMINAR','callback_data':'userop:delete'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
  if f=='create':
   st['s']='p';return send(c,'🔑 Contraseña:')
  # Renovación por referidos: 3 referidos = 7 días, máximo 3 renovaciones.
  count=sum(1 for v in db().get('referrals',{}).values() if str(v)==str(c))
  used=int(db().get('referral_meta',{}).get(str(c),{}).get('renewals',0))
  if count < (used+1)*3 or used >= 3:
   left=max(0,(used+1)*3-count)
   if used >= 3:return send(c,'❌ Ya utilizaste las 3 renovaciones disponibles por referidos.')
   return send(c,f'🔗 Necesitas <b>{left} referidos más</b> para renovar por 7 días.')
  dat['days']=7;dat['limit']=quota(c)[1];st['s']='ready';return send(c,'♻️ <b>Renovación lista</b>\n\nSe aplicarán <b>7 días</b> y se utilizarán <b>3 referidos</b>.',[[{'text':'✅ RENOVAR 7 DÍAS','callback_data':'do:renew'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
 if f=='create' and step=='p':
  dat['pass']=t;dat['days'],dat['limit']=quota(c);st['s']='ready'
  return send(c,f'⚡ <b>CREANDO CUENTA</b>\n\n📅 Cuota: <b>{dat["days"]} días</b>\n👥 Dispositivos/IP: <b>{dat["limit"]}</b>')

def cb(c,m,u,i,x):
 if banned(u) and not x.startswith('lang:'):return ans(i,'🚫 Baneado')
 registered(u)
 if x.startswith('lang:'):
  code=x.split(':',1)[1]
  if code not in LANGS:return ans(i,'Idioma no disponible')
  d0=db();d0['users'].setdefault(str(u),{'id':u,'name':str(u),'created':time.strftime('%F'),'accounts':[]})['lang']=code;save_db(d0)
  return edit(c,m,LANGS[code]['title']+'\n\n'+LANGS[code]['panel'],home(u))
 if not allowed(u):return ans(i,'🔒 Acceso privado')
 ans(i,'⚡')
 d=db()
 if x=='home':return edit(c,m,tr(u,'title')+'\n\n'+tr(u,'panel'),home(u))
 if x=='users':return edit(c,m,'👤 <b>USUARIOS</b>\n\nGestiona tus cuentas SSH.',users_menu(c))
 if x=='settings':
  if not is_owner(u):return ans(i,'Solo el super admin')
  return edit(c,m,'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚙️ <b>Panel de administración</b>\n━━━━━━━━━━━━━━━━━━━━\n🔧 <b>Centro de control del servidor</b>\nGestiona el bot y sus usuarios desde un solo lugar.',settings_keyboard())
 if x=='create':
  if not allowed(u):return send(c,'🔒 Acceso privado.')
  STATE[c]={'f':'create','s':'u','d':{}};return send(c,tr(u,'create_prompt'))
 if x=='renew':STATE[c]={'f':'renew','s':'u','d':{}};return send(c,tr(u,'renew_prompt'))
 if x=='account':STATE[c]={'f':'account','s':'u','d':{}};return send(c,tr(u,'account_prompt'))
 if x=='delete':STATE[c]={'f':'delete','s':'u','d':{}};return send(c,tr(u,'delete_prompt'))
 if x=='list':return edit(c,m,userlist(),users_menu(c))
 if x=='online':return edit(c,m,ssh_online(),users_menu(c))
 if x=='cancel':STATE.pop(c,None);return send(c,'❌ Cancelado.',users_menu(c))
 if x.startswith('do:'):
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.',users_menu(c))
  dat=st['d'];u0=dat['user'];days=int(dat['days']);exp=subprocess.getoutput(f"date -d '+{days} days' +%F")
  if x=='do:create':
   rc,o=sh(f'useradd -e {q(exp)} -M -s /usr/sbin/nologin {q(u0)} && printf "%s\\n" {q(u0+":"+dat["pass"])} | chpasswd',12)
   if rc==0:
    (BASE/'limits').mkdir(exist_ok=True);(BASE/'limits'/u0).write_text('0' if dat.get('limit') in ('Ilimitado',0,'0') else str(dat.get('limit')))
    d=db();d['users'][str(c)].setdefault('accounts',[]).append(u0)
    # Recompensa única: se acredita cuando el referido crea su primera cuenta.
    referrer=d.get('referrals',{}).get(str(c))
    if referrer and not d['users'][str(c)].get('referral_rewarded',False):
     d['users'][str(c)]['referral_rewarded']=True
     meta=d.setdefault('referral_meta',{}).setdefault(str(referrer),{'renewals':0})
     meta.setdefault('renewals',0)
     save_db(d)
     inv_username=d.get('users',{}).get(str(c),{}).get('username','')
     mention=(' @'+inv_username) if inv_username else ''
     try:send(int(referrer),f'🎉 ¡Felicidades!\nEl usuario{mention} ha creado su primera cuenta.\n¡Has ganado 1 de referido!\nUsa /referidos o el menú para canjearlo.')
     except Exception as er:log(f'REF_NOTIFY {referrer} {er!r}')
    else:save_db(d)
    send(c,account_message(c,dat),users_menu(c));return
   return send(c,'🔴 <b>Error al crear</b>\n<pre>'+e(o)+'</pre>',users_menu(c))
  if x=='do:renew':
   # Revalidar los referidos al confirmar para evitar saltarse el límite.
   d=db();count=sum(1 for v in d.get('referrals',{}).values() if str(v)==str(c));meta=d.setdefault('referral_meta',{}).setdefault(str(c),{'renewals':0});used=int(meta.get('renewals',0))
   if used>=3 or count<(used+1)*3:return send(c,'❌ No tienes suficientes referidos para esta renovación.',users_menu(c))
   exp=subprocess.getoutput(f"date -d '+7 days' +%F")
   rc,o=sh(f'chage -E {q(exp)} {q(u0)}',10)
   if rc==0:
    meta['renewals']=used+1;save_db(d)
    return send(c,account_message(c,{'user':u0,'pass':dat.get('pass','********'),'days':7,'limit':dat.get('limit','Ilimitado')},True),users_menu(c))
   return send(c,'🔴 <b>Error al renovar</b>\n<pre>'+e(o)+'</pre>',users_menu(c))
 if x=='userop:delete':
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.',users_menu(c))
  u0=st['d']['user'];rc,o=sh(f'pkill -u {q(u0)} 2>/dev/null || true; userdel -r -f {q(u0)}',15)
  if rc==0:
   d=db()
   for z in d['users'].values():z['accounts']=[a for a in z.get('accounts',[]) if a!=u0]
   save_db(d)
  return send(c,('🟢' if rc==0 else '🔴')+f' <b>Cuenta {"eliminada" if rc==0 else "no eliminada"}</b>\n\n👤 <code>{e(u0)}</code>',users_menu(c))
 if x.startswith('proto:'):
  k=x.split(':',1)[1];v=PROTO[k];ins=installed(k);buttons=[[{'text':'🔄 Reiniciar','callback_data':'svc_restart:'+k}]] if ins else []
  buttons += [[{'text':'🗑️ Desinstalar','callback_data':'un:'+k}]] if ins else [[{'text':'🚀 Instalar','callback_data':'in:'+k}]]
  buttons += [[{'text':'🔙 Protocolos','callback_data':'protocols'}]]
  return edit(c,m,f'🌐 <b>{e(v[0])}</b>\n\nEstado: {"🟢 INSTALADO" if ins else "⚪ NO INSTALADO"}\nPuertos: <code>{e(v[3])}</code>\nServicio: <code>{e(v[2])}</code>',buttons)
 if x.startswith('in:') or x.startswith('un:'):
  k=x.split(':')[1];v=PROTO[k];p=module(v[1]);
  if not p:return send(c,'🔴 Script no encontrado.',PK)
  return bg(c,('Instalando ' if x.startswith('in:') else 'Desinstalando ')+v[0],f'bash {q(p)} <<EOF\n{v[4] if x.startswith("in:") else v[5]}\nEOF',360,PK)
 if x.startswith('tool:'):
  if not is_owner(u):return ans(i,'Solo el super admin')
  k=x.split(':')[1];mp={'optimizar':'optimizar.sh','ads':'blockads.sh','torrent':'blocktorrent.sh','speed':'speedtest.sh','scanner':'scanner.sh','update':'update.sh'}
  if k=='files':return edit(c,m,'📁 <b>ARCHIVOS</b>\n\n<pre>'+e(subprocess.getoutput("find /etc/kevintech -maxdepth 2 -type f | sort | head -120"))+'</pre>',TOOLS)
  p=module(mp.get(k,''));return bg(c,k.title(),f'bash {q(p)}',180,TOOLS) if p else send(c,'🔴 Módulo no encontrado.',TOOLS)
 if x=='language':return edit(c,m,'🌐 <b>'+tr(u,'language')+'</b>\n\nSelecciona tu idioma:',language_menu())
 if x=='referrals':
  link=f'https://t.me/{BOT_USERNAME}?start=ref_{u}' if BOT_USERNAME else f'/start ref_{u}'
  n=sum(1 for v in d.get('referrals',{}).values() if str(v)==str(u))
  used=int(d.get('referral_meta',{}).get(str(u),{}).get('renewals',0))
  available=max(0,min(3-used,n//3))
  return edit(c,m,f'🔗 <b>REFERIDOS</b>\n\nComparte tu enlace y recibe referidos.\n\n🔗 <code>{e(link)}</code>\n👥 Referidos válidos: <b>{n}</b>\n♻️ Renovaciones disponibles: <b>{available}</b>\n\nCada renovación usa 3 referidos y entrega 7 días. Máximo: 3 renovaciones.',users_menu(u))
 if x=='admins':return admin_menu(c,m)
 if x=='admin_list':
  lines=[f'👤 <code>{e(k)}</code> — {e(v.get("name",""))} — {e(v.get("until","unlimited"))}' for k,v in d['admins'].items()]
  return edit(c,m,'👥 <b>LISTA DE ADMINS</b>\n\n'+('\n'.join(lines) if lines else 'No hay admins adicionales.'),ADMIN_MENU)
 if x=='admin_add':STATE[c]={'f':'admin_add','s':'id','d':{}};return send(c,'➕ ID del administrador:')
 if x=='admin_remove':STATE[c]={'f':'admin_remove','s':'id','d':{}};return send(c,'🗑️ ID del administrador:')
 if x=='admin_rename':STATE[c]={'f':'admin_rename','s':'id','d':{}};return send(c,'✏️ ID del administrador:')
 if x=='access_toggle':
  d['access']='public' if d['access']=='private' else 'private';save_db(d);return edit(c,m,f'🔐 <b>ACCESO CAMBIADO</b>\n\nAhora el bot está: <b>{"PÚBLICO 🟢" if d["access"]=="public" else "PRIVADO 🔴"}</b>',settings_keyboard())
 if x=='bans':return edit(c,m,'🚫 <b>BANEAR USUARIO</b>',BAN_MENU)
 if x=='ban_add':STATE[c]={'f':'ban_add','s':'id','d':{}};return send(c,'🚫 ID de Telegram a banear:')
 if x=='ban_remove':STATE[c]={'f':'ban_remove','s':'id','d':{}};return send(c,'🔓 ID de Telegram a desbanear:')
 if x=='ban_list':
  lines=[f'• <code>{e(k)}</code> — {e(v.get("name", ""))}' for k,v in d['bans'].items()];return edit(c,m,'🚫 <b>LISTA DE BANS</b>\n\n'+('\n'.join(lines) if lines else 'Vacía.'),BAN_MENU)
 if x=='backup':
  BACK.mkdir(parents=True,exist_ok=True);fn=BACK/'kevintech_backup.json';fn.write_text(json.dumps(d,indent=2,ensure_ascii=False));return send_document(c,fn,'💾 Respaldo JSON de KevinTech',SETTINGS)
 if x=='restore':return send(c,'♻️ <b>RESTAURACIÓN</b>\n\nEnvía un archivo JSON como documento y después el VPS se reiniciará automáticamente.',SETTINGS)
 if x=='monetization':return edit(c,m,'💰 <b>MONETIZACIÓN</b>\n\nConfigura los identificadores/enlaces de Monetag u otra Mini App.',MONETIZATION)
 if x=='monetag':STATE[c]={'f':'monetag','s':'value','d':{}};return send(c,'💰 Envía el código, enlace o identificador de Monetag:')
 if x=='miniapp':STATE[c]={'f':'miniapp','s':'value','d':{}};return send(c,'📱 Envía el enlace o identificador de tu Mini App:')
 if x=='restart_vps':return send(c,'♻️ ¿Reiniciar el VPS ahora?',[[{'text':'✅ REINICIAR VPS','callback_data':'do_reboot'},{'text':'❌ CANCELAR','callback_data':'settings'}]])
 if x=='do_reboot':return bg(c,'Reinicio del VPS','sleep 2; reboot',15,SETTINGS)
 if x=='people':return edit(c,m,f'👥 <b>PERSONAS REGISTRADAS: {len(d["users"])}</b>',SETTINGS)
 if x=='message_users':STATE[c]={'f':'message_users','s':'text','d':{}};return send(c,'📢 Escribe el mensaje que quieres enviar a todos los usuarios registrados:')
 if x=='quotas':return edit(c,m,quota_text(d),QUOTA)
 if x=='quota_public':STATE[c]={'f':'quota_public','s':'days','d':{}};return send(c,'📅 Días para usuarios públicos:')
 if x=='quota_admin':STATE[c]={'f':'quota_admin','s':'days','d':{}};return send(c,'📅 Días para administradores:')
 if x=='tools':return edit(c,m,'🛠 <b>HERRAMIENTAS</b>',TOOLS)

def admin_menu(c,m):return edit(c,m,'👥 <b>ADMINISTRADORES</b>',ADMIN_MENU)
def quota_text(d):
 qx=d['quotas'];return f'''📅 <b>CUOTAS ACTUALES</b>\n\nPúblico: <b>{qx["public_days"]} días</b> / <b>{qx["public_devices"]} dispositivos</b>\nAdmin: <b>{qx["admin_days"]} días</b> / <b>{qx["admin_devices"]} dispositivos</b>\n\nEl super admin no tiene límite.'''

SETTINGS=[[{'text':'🔐 Acceso: PRIVADO','callback_data':'access_toggle'}],[{'text':'👥 Administradores','callback_data':'admins'},{'text':'🌐 Dominio','callback_data':'domain'}],[{'text':'🚫 Banear usuario','callback_data':'bans'},{'text':'♻️ Restauración','callback_data':'restore'}],[{'text':'💾 Respaldar JSON','callback_data':'backup'},{'text':'💰 Monetización','callback_data':'monetization'}],[{'text':'👥 Personas registradas','callback_data':'people'},{'text':'📢 Mensaje a usuarios','callback_data':'message_users'}],[{'text':'📅 Cuotas','callback_data':'quotas'},{'text':'♻️ Reiniciar VPS','callback_data':'restart_vps'}],[{'text':'🛠 Herramientas','callback_data':'tools'}],[{'text':'🔙 Inicio','callback_data':'home'}]]
ADMIN_MENU=[[{'text':'📋 Lista de admins','callback_data':'admin_list'}],[{'text':'➕ Agregar admin','callback_data':'admin_add'},{'text':'🗑️ Quitar admin','callback_data':'admin_remove'}],[{'text':'✏️ Renombrar admin','callback_data':'admin_rename'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
BAN_MENU=[[{'text':'🚫 Banear usuarios','callback_data':'ban_add'}],[{'text':'🔓 Desbanear','callback_data':'ban_remove'},{'text':'📋 Lista de ban','callback_data':'ban_list'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
QUOTA=[[{'text':'👥 Público','callback_data':'quota_public'},{'text':'👨‍💼 Admin','callback_data':'quota_admin'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]
MONETIZATION=[[{'text':'💰 Monetag','callback_data':'monetag'},{'text':'📱 Mini App','callback_data':'miniapp'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]

# Replace settings access label dynamically before rendering.
def settings_keyboard():
 d=db();rows=[r[:] for r in SETTINGS];rows[0]=[{'text':('🔐 Acceso: PÚBLICO 🟢' if d['access']=='public' else '🔐 Acceso: PRIVADO 🔴'),'callback_data':'access_toggle'}];return rows
SETTINGS=settings_keyboard()

# State handler for admin/configuration text input.
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
   d['admins'][str(dat['id'])]={'name':dat['name'],'until':until};save_db(d);STATE.pop(c,None);send(dat['id'],f'👨‍💼 Fuiste agregado como administrador por <b>{e(dat["name"])}</b>.\nVencimiento: <code>{e(until)}</code>');return send(c,'🟢 Administrador agregado y notificado.',ADMIN_MENU)
 if f=='admin_remove' and step=='id':
  if not t.isdigit():return send(c,'❌ ID inválido.')
  aid=t;ex=d['admins'].pop(aid,None);save_db(d);STATE.pop(c,None)
  if ex:
   try: send(int(aid),'⚠️ Tu acceso de administrador fue retirado del bot.')
   except Exception as er: log(f'ADMIN_REMOVE_NOTIFY {aid} {er!r}')
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
  for sid in list(d.get('users',{})):
   try:
    api('sendMessage',{'chat_id':int(sid),'text':'📢 <b>Mensaje del administrador</b>\n\n'+e(t),'parse_mode':'HTML','disable_web_page_preview':'true'},timeout=15);ok+=1
   except Exception as er:
    fail+=1;log(f'BROADCAST_FAIL {sid} {er!r}')
  return send(c,f'📢 <b>Envío finalizado</b>\n\n🟢 Entregados: <b>{ok}</b>\n🔴 No entregados: <b>{fail}</b>\n\nLos fallos quedaron registrados para revisión.',SETTINGS)
 if f in ('monetag','miniapp') and step=='value':
  d['monetization']['monetag' if f=='monetag' else 'miniapp']=t.strip();save_db(d);STATE.pop(c,None);return send(c,'🟢 Configuración guardada.',MONETIZATION)
 if f=='domain' and step=='value':
  val=t.strip();cfg=BASE/'config.conf';lines=cfg.read_text(errors='ignore').splitlines() if cfg.exists() else [];found=False
  for i,l in enumerate(lines):
   if l.startswith('SERVER_DOMAIN='):lines[i]=f'SERVER_DOMAIN="{val}"';found=True
  if not found:lines.append(f'SERVER_DOMAIN="{val}"')
  cfg.write_text('\n'.join(lines)+'\n');STATE.pop(c,None);return send(c,'🟢 Dominio actualizado. Los protocolos que soportan IP y dominio usarán ambos.',SETTINGS)
 if f in ('quota_public','quota_admin'):
  key='public' if f=='quota_public' else 'admin'
  if step=='days':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Días inválidos.')
   dat['days']=int(t);st['s']='devices';return send(c,'📱 Número máximo de dispositivos/IP:')
  if step=='devices':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Número inválido.')
   d['quotas'][key+'_days']=dat['days'];d['quotas'][key+'_devices']=int(t);save_db(d);STATE.pop(c,None);return send(c,'🟢 Cuota actualizada.',QUOTA)

# Wrap original text processing with admin input routing.
_original_process=process_text
def process_text(c,t):
 registered(c)
 if is_owner(c) and c in STATE and STATE[c]['f'] in ('admin_add','admin_remove','admin_rename','ban_add','ban_remove','message_users','monetag','miniapp','domain','quota_public','quota_admin'):
  return admin_text(c,t)
 return _original_process(c,t)

# Document restore handler is included in update loop.
def restore_document(c,msg):
 if not is_owner(c):return
 doc=msg.get('document',{});name=doc.get('file_name','')
 if not name.lower().endswith('.json'):return send(c,'❌ Solo se acepta un archivo JSON.')
 try:
  z=api('getFile',{'file_id':doc['file_id']});fp=z['result']['file_path'];token=ENV.read_text().split('BOT_TOKEN=',1)[1].splitlines()[0].strip().strip('"');url=f'https://api.telegram.org/file/bot{token}/{fp}';raw=urllib.request.urlopen(url,timeout=30).read();new=json.loads(raw.decode());
  if not isinstance(new,dict) or 'quotas' not in new or 'users' not in new:raise ValueError('JSON incompatible')
  BACK.mkdir(parents=True,exist_ok=True);(BACK/f'restore_before_{time.strftime("%F_%H-%M-%S")}.json').write_text(DB.read_text() if DB.exists() else '{}');save_db(new);send(c,'🟢 <b>Restauración completada.</b>\n\n♻️ El VPS se reiniciará para aplicar la restauración.');time.sleep(2);sh('reboot',10)
 except Exception as er:log('RESTORE '+repr(er));send(c,'🔴 No se pudo restaurar el JSON.')

def register_referral(uid,text):
 if not text.startswith(('/start','/star')): return
 parts=text.split(maxsplit=1)
 if len(parts)<2 or not parts[1].startswith('ref_'): return
 rid=parts[1][4:]
 d=db()
 if rid.isdigit() and rid!=str(uid) and str(uid) not in d.get('referrals',{}):
  d.setdefault('referrals',{})[str(uid)]=rid;save_db(d)

def main():
 env();load_db();LOG.parent.mkdir(parents=True,exist_ok=True);LOG.touch();LOG.chmod(0o600);api('deleteWebhook',{'drop_pending_updates':'false'});off=int(OFF.read_text()) if OFF.exists() and OFF.read_text().strip().isdigit() else 0;log('BOT ONLINE')
 while True:
  try:
   r=api('getUpdates',{'offset':off,'timeout':30,'allowed_updates':json.dumps(['message','callback_query'])})
   for u in r.get('result',[]):
    off=u['update_id']+1;OFF.write_text(str(off))
    try:
     if 'callback_query' in u:
      z=u['callback_query'];m=z['message'];cb(m['chat']['id'],m['message_id'],z['from']['id'],z['id'],z.get('data',''))
     elif 'message' in u:
      m=u['message'];c=m['chat']['id'];registered(c,m.get('from',{}).get('first_name',''),m.get('from',{}).get('username',''))
      if m.get('document'):restore_document(c,m)
      elif m.get('text'):
       txt=m['text'].strip(); register_referral(c,txt)
       if txt.split()[0] in ('/start','/star') and 'lang' not in db()['users'].get(str(c),{}):
        send(c,'🌐 <b>Bienvenido a KEVINTECH MULTI SCRIPT</b>\n\nSelecciona tu idioma / Choose your language / Escolha seu idioma:',language_menu())
       else: process_text(c,txt)
    except Exception as er:log('UPDATE '+repr(er))
  except Exception as er:log('POLL '+repr(er));time.sleep(2)
if __name__=='__main__':main()
