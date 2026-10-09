#!/usr/bin/env python3
import base64, hashlib, hmac, json, os, re, secrets, sqlite3, subprocess, time, uuid, shlex
from datetime import datetime, timedelta
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse

BASE=Path('/etc/kevintech'); WEB=BASE/'web'; DATA=WEB/'data'; DB=DATA/'web.sqlite3'; CONFIG=DATA/'config.json'; KEYFILE=DATA/'.credential.key'; LOG=DATA/'web.log'
HOST='127.0.0.1'; PORT=int(os.environ.get('KEVINTECH_WEB_PORT','18080')); PREFIX=os.environ.get('KEVINTECH_WEB_PREFIX','').strip().rstrip('/'); SESSION_TTL=86400*3; TOKEN_TTL=600
DEFAULT_SETTINGS={'site_title':'KevinTech Multi Script','site_description':'Panel web para administrar tu VPS y tus cuentas.','quota_user_days':7,'quota_user_limit':1,'quota_admin_days':30,'quota_admin_limit':5,'about_us':'Somos un proyecto dedicado a ofrecer herramientas sencillas para administrar servicios de VPS.','privacy':'Usamos tus datos únicamente para administrar tu cuenta web y las funciones del panel.','cookies':'Este panel utiliza cookies técnicas para mantener la sesión iniciada.','terms':'El uso del panel y de los servicios del VPS debe respetar las leyes y las políticas de tu proveedor.','home_title':'Inicio','home_description':'Administra tus cuentas y consulta el estado de tu VPS.','protocols_title':'Protocolos','protocols_description':'Consulta el estado real de los servicios del VPS.','online_title':'Online','online_description':'Conexiones SSH detectadas actualmente.','referrals_title':'Referidos','referrals_description':'Comparte tu enlace y acumula puntos.'}
SERVICES=[('OpenSSH','ssh','🔐'),('Dropbear','dropbear_custom','🚪'),('HAProxy / SSL','haproxy','🔒'),('SlowDNS','dnstt','🌐'),('Xray / V2Ray','xray','☁️'),('OpenVPN','openvpn-server@server','🔐'),('Hysteria','hysteria1-server','🛡️'),('BHTTP','bhttp','🌐'),('XHTTP','xhttp','🚀'),('Squid','squid','🌐'),('HCR','hcr-server','🛡️'),('WireGuard','wg-quick@wg0','🛡️'),('BTUN','btun','⚡'),('Shadowsocks','shadowsocks-libev-server@8388','🕶️'),('SOCKS5','sockd','🔐'),('3X-UI','x-ui','🖥️'),('VayDNS','vaydns','🔐'),('Slipstream','slipstream','🚀'),('DNSDist','dnsdist','🌐')]

def log(msg):
 DATA.mkdir(parents=True,exist_ok=True); LOG.open('a',encoding='utf8').write(datetime.now().isoformat(timespec='seconds')+' '+str(msg)+'\n')

def hash_password(pw,salt=None):
 salt=salt or secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); return 'scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode()
def verify_password(pw,stored):
 try:
  _,s,h=stored.split('$',2); salt=base64.urlsafe_b64decode(s); expected=base64.urlsafe_b64decode(h); got=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); return hmac.compare_digest(got,expected)
 except Exception:return False

def credential_key():
 DATA.mkdir(parents=True,exist_ok=True)
 if not KEYFILE.exists():KEYFILE.write_bytes(secrets.token_bytes(32)); os.chmod(KEYFILE,0o600)
 return KEYFILE.read_bytes()
def crypt_credential(text):
 credential_key()
 try:
  p=subprocess.run(['openssl','enc','-aes-256-cbc','-a','-A','-salt','-pbkdf2','-iter','120000','-pass','file:'+str(KEYFILE)],input=text.encode(),capture_output=True,timeout=5)
  if p.returncode==0:return 'openssl$'+p.stdout.decode().strip()
 except Exception:pass
 return 'plain$'+text
def decrypt_credential(value):
 credential_key()
 try:
  if value.startswith('openssl$'):
   p=subprocess.run(['openssl','enc','-d','-aes-256-cbc','-a','-A','-pbkdf2','-iter','120000','-pass','file:'+str(KEYFILE)],input=value[8:].encode(),capture_output=True,timeout=5)
   if p.returncode==0:return p.stdout.decode()
  if value.startswith('plain$'):return value[6:]
 except Exception:pass
 return ''

def cfg():
 DATA.mkdir(parents=True,exist_ok=True)
 if not CONFIG.exists(): CONFIG.write_text(json.dumps({'admin_username':'admin','admin_password_hash':'','secret':secrets.token_hex(32),'ads_enabled':True,'ad_provider':'monetag','monetag_zone':'11217882','ads':{'create':0,'delete':0,'renew':0},'server_prefix':PREFIX,'server_domain':''},indent=2),encoding='utf8')
 try:return json.loads(CONFIG.read_text(encoding='utf8'))
 except:return {}
def save_cfg(c):CONFIG.write_text(json.dumps(c,indent=2,ensure_ascii=False),encoding='utf8');os.chmod(CONFIG,0o600)

def db():
 DATA.mkdir(parents=True,exist_ok=True); c=sqlite3.connect(DB,timeout=10); c.row_factory=sqlite3.Row; c.execute('PRAGMA journal_mode=WAL'); c.execute('PRAGMA foreign_keys=ON')
 c.executescript('''CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,name TEXT NOT NULL,created_at TEXT NOT NULL,referral_code TEXT UNIQUE NOT NULL,referred_by TEXT,referral_points INTEGER NOT NULL DEFAULT 0,referral_renews INTEGER NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1);
 CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,username TEXT UNIQUE NOT NULL,type TEXT NOT NULL DEFAULT 'ssh',credential TEXT NOT NULL,expiration TEXT,ip_limit INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
 CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id INTEGER,role TEXT NOT NULL,expires REAL NOT NULL);
 CREATE TABLE IF NOT EXISTS ad_tokens(token TEXT PRIMARY KEY,user_id INTEGER NOT NULL,action TEXT NOT NULL,account_id INTEGER,expires REAL NOT NULL,completed INTEGER NOT NULL DEFAULT 0,payload TEXT NOT NULL DEFAULT '{}');
 CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);''')
 for k,v in DEFAULT_SETTINGS.items():c.execute('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)',(k,json.dumps(v,ensure_ascii=False)))
 c.commit();return c

def site_settings():
 c=db(); rows=c.execute('SELECT key,value FROM settings').fetchall();c.close(); out=dict(DEFAULT_SETTINGS)
 for r in rows:
  try:out[r['key']]=json.loads(r['value'])
  except:out[r['key']]=r['value']
 return out
def save_settings(values):
 c=db()
 for k,v in values.items():c.execute('INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',(k,json.dumps(v,ensure_ascii=False)))
 c.commit();c.close()

def ensure_admin():
 credential_key(); c=cfg(); changed=False
 if not c.get('secret'):c['secret']=secrets.token_hex(32);changed=True
 if not c.get('admin_username'):c['admin_username']='admin';changed=True
 if not c.get('admin_password_hash'):
  pw=os.environ.get('WEB_ADMIN_PASS') or secrets.token_urlsafe(12);c['admin_password_hash']=hash_password(pw);c['initial_admin_password']=pw;changed=True
 for k,v in {'ads_enabled':False,'ad_provider':'monetag','monetag_zone':'11217882','ads':{'create':0,'delete':0,'renew':0},'server_prefix':PREFIX,'server_domain':''}.items():
  if k not in c:c[k]=v;changed=True
 if not c.get('admin_referral_code'):c['admin_referral_code']=secrets.token_urlsafe(7);changed=True
 if 'admin_referral_points' not in c:c['admin_referral_points']=0;changed=True
 if changed:save_cfg(c)
 c=db();c.close()

def now():return time.time()
def iso(dt):return dt.strftime('%Y-%m-%d')
def safe_username(s):return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',s or ''))
def safe_web_username(s):return bool(re.fullmatch(r'[A-Za-z0-9_.-]{3,32}',s or ''))
def html_escape(s):return str(s).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;').replace("'",'&#39;')

def shell(cmd,timeout=30):
 try:
  p=subprocess.run(cmd,shell=True,executable='/bin/bash',capture_output=True,text=True,timeout=timeout);return p.returncode,(p.stdout+p.stderr).strip()
 except subprocess.TimeoutExpired:return 124,'Tiempo agotado.'
 except Exception as e:return 1,str(e)

def account_online(username):
 try:
  out=subprocess.run(['ss','-tnp','state','established'],capture_output=True,text=True,timeout=5).stdout; rows=[]
  for line in out.splitlines():
   if ':22' not in line:continue
   m=re.search(r'users:\(\("sshd",pid=(\d+)',line)
   if not m:continue
   pid=m.group(1);u=subprocess.run(['ps','-o','user=','-p',pid],capture_output=True,text=True,timeout=2).stdout.strip()
   if u!=username:continue
   parts=line.split();peer=parts[4] if len(parts)>4 else '—';rows.append(peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer)
  return sorted(set(rows))
 except:return []
def all_online():
 try:
  out=subprocess.run(['ss','-tnp','state','established'],capture_output=True,text=True,timeout=5).stdout; rows=[]
  for line in out.splitlines():
   if ':22' not in line:continue
   m=re.search(r'users:\(\("sshd",pid=(\d+)',line)
   if not m:continue
   pid=m.group(1);u=subprocess.run(['ps','-o','user=','-p',pid],capture_output=True,text=True,timeout=2).stdout.strip()
   if not u or u in ('root','sshd','users'):continue
   parts=line.split();peer=parts[4] if len(parts)>4 else '—';rows.append((u,peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer))
  return rows
 except:return []

def create_ssh_account(username,password,days,limit):
 if not safe_username(username):return False,'Usuario SSH inválido.'
 if len(password)<4:return False,'La contraseña debe tener al menos 4 caracteres.'
 if days<1 or days>3650:return False,'Días inválidos.'
 if limit<0 or limit>100:return False,'Límite inválido.'
 if subprocess.run(['id',username],capture_output=True).returncode==0:return False,'Ese usuario ya existe en el VPS.'
 exp=iso(datetime.now()+timedelta(days=days));rc,out=shell('useradd -e %s -M -s /usr/sbin/nologin %s && printf %s | chpasswd'%(shlex.quote(exp),shlex.quote(username),shlex.quote(username+':'+password)),15)
 if rc!=0:return False,out or 'No se pudo crear el usuario.'
 limits=BASE/'limits.conf';lines=limits.read_text(errors='ignore').splitlines() if limits.exists() else [];lines=[x for x in lines if not x.startswith(username+':')];lines.append(f'{username}:{limit}');limits.write_text('\n'.join(lines)+'\n');os.chmod(limits,0o600);return True,exp

def create_v2ray_account(username,days):
 cfgp=Path('/usr/local/etc/xray/config.json')
 if not cfgp.exists():
  alt=Path('/etc/xray/config.json');cfgp=alt if alt.exists() else cfgp
 if not cfgp.exists():return False,'Xray/V2Ray no está instalado o no existe su configuración.',''
 if not re.fullmatch(r'[A-Za-z0-9_.-]{3,32}',username or ''):return False,'Usuario V2Ray inválido.',''
 try:
  data=json.loads(cfgp.read_text()); inbound=data.setdefault('inbounds',[{}])[0];clients=inbound.setdefault('settings',{}).setdefault('clients',[])
  if any(str(x.get('email','')).lower()==username.lower() for x in clients):return False,'El usuario V2Ray ya existe.',''
  uid=str(uuid.uuid4());clients.append({'id':uid,'level':0,'email':username});tmp=cfgp.with_suffix('.json.tmp');tmp.write_text(json.dumps(data,indent=2,ensure_ascii=False));os.chmod(tmp,0o600);tmp.replace(cfgp)
  rc,out=shell('systemctl restart xray',20)
  if rc:return False,out or 'No se pudo reiniciar Xray.',''
  return True,iso(datetime.now()+timedelta(days=days)),uid
 except Exception as e:return False,str(e),''

def delete_v2ray(username):
 for cfgp in [Path('/usr/local/etc/xray/config.json'),Path('/etc/xray/config.json')]:
  if cfgp.exists():
   try:
    data=json.loads(cfgp.read_text());clients=data.get('inbounds',[{}])[0].get('settings',{}).get('clients',[]);new=[x for x in clients if str(x.get('email','')).lower()!=username.lower()]
    if len(new)==len(clients):continue
    data['inbounds'][0]['settings']['clients']=new;cfgp.write_text(json.dumps(data,indent=2,ensure_ascii=False));os.chmod(cfgp,0o600);return shell('systemctl restart xray',20)[0]==0
   except:return False
 return False

def renew_account(a,days):
 if a['type']=='ssh':return renew_ssh(a['username'],days)
 if a['type']=='v2ray':
  exp=iso(datetime.now()+timedelta(days=days));return True,exp
 return False,'Tipo no soportado.'
def renew_ssh(username,days):
 if not safe_username(username) or subprocess.run(['id',username],capture_output=True).returncode!=0:return False,'Cuenta no encontrada.'
 if days<1 or days>3650:return False,'Días inválidos.'
 exp=iso(datetime.now()+timedelta(days=days));rc,out=shell('chage -E %s %s'%(shlex.quote(exp),shlex.quote(username)),10);return rc==0,(exp if rc==0 else out)

def server_domain():
 c=cfg();
 if c.get('server_domain'):return str(c['server_domain'])
 p=BASE/'config.conf'
 if p.exists():
  for line in p.read_text(errors='ignore').splitlines():
   if line.startswith('SERVER_DOMAIN='):return line.split('=',1)[1].strip().strip('"').strip("'")
 return ''
def server_ip():
 try:
  x=subprocess.getoutput('curl -4 -fsS --max-time 4 https://api.ipify.org 2>/dev/null').strip()
  if x:return x
 except:pass
 return (subprocess.getoutput('hostname -I').split() or ['0.0.0.0'])[0]
def slowdns_key():
 p=Path('/etc/slowdns/server.pub');return p.read_text(errors='ignore').strip() if p.exists() else 'No configurado'
def server_info():
 domain=server_domain();ip=server_ip();host=domain or ip;return {'host':host,'ip':ip,'ssh':'22','dropbear':'143,90,109','ssl':'8080,443,80','badvpn':'7300,7200','bhttp':'8088','slowdns':'5300','zivpn':'21992','zivpn_udp':'20000-29999','slowdns_ns':('ns-'+domain if domain else 'No configurado'),'slowdns_key':slowdns_key()}

def ssh_message(username,password,expiration,days,limit):
 s=server_info();lim='Ilimitado' if int(limit)==0 else str(limit)
 return f'''🎉 CUENTA CREADA EXITOSAMENTE\n\n━━━━━━━━━━━━━━━━━━━━\n👤 DATOS DEL USUARIO\n━━━━━━━━━━━━━━━━━━━━\n• Usuario: {username}\n• 🔑 Contraseña: {password}\n• Expira: {datetime.strptime(expiration,'%Y-%m-%d').strftime('%d/%m/%Y')}\n• Duración: {days} días\n• Límite IP: {lim}\n\n━━━━━━━━━━━━━━━━━━━━\n🌐 INFORMACIÓN DEL SERVIDOR\n━━━━━━━━━━━━━━━━━━━━\n• Host/IP: {s['host']}\n• IP: {s['ip']}\n• SSH: {s['ssh']}\n• Dropbear: {s['dropbear']}\n• SSL Tunnel: {s['ssl']}\n• BadVPN: {s['badvpn']}\n• BHTTP: {s['bhttp']}\n\n━━━━━━━━━━━━━━━━━━━━\n📡 HTTP CUSTOM\n━━━━━━━━━━━━━━━━━━━━\n{s['host']}:443@{username}:{password}\n{s['host']}:80@{username}:{password}\n{s['host']}:8080@{username}:{password}\n\n━━━━━━━━━━━━━━━━━━━━\n🚀 UDP CUSTOM\n━━━━━━━━━━━━━━━━━━━━\n{s['host']}:1-65535@{username}:{password}\n\n━━━━━━━━━━━━━━━━━━━━\n🚀 ZIVPN UDP\n━━━━━━━━━━━━━━━━━━━━\n• Servidor: {s['host']}:{s['zivpn']}\n• Contraseña: {password}\n• Puerto UDP: {s['zivpn_udp']}\n\n━━━━━━━━━━━━━━━━━━━━\n🐌 SLOWDNS (5300)\n━━━━━━━━━━━━━━━━━━━━\n• NS: {s['slowdns_ns']}\n• KEY: {s['slowdns_key']}\n• Puerto: {s['slowdns']}\n\n━━━━━━━━━━━━━━━━━━━━\n💎 KEVINTECH MULTI SCRIPT\n━━━━━━━━━━━━━━━━━━━━'''

def v2ray_message(username,uid,expiration,days):
 s=server_info();exp=datetime.strptime(expiration,'%Y-%m-%d').strftime('%d/%m/%Y');raw=f'v:vmess@{s["host"]}:443?type=ws&path=/vmess&security=tls&uuid={uid}';link='vmess://'+base64.b64encode(raw.encode()).decode()
 return f'''🚀 CUENTA V2RAY CREADA EXITOSAMENTE\n\n━━━━━━━━━━━━━━━━━━━━\n👤 DATOS DEL USUARIO\n━━━━━━━━━━━━━━━━━━━━\n• Usuario: {username}\n• 🆔 UUID: {uid}\n• Expira: {exp}\n• Duración: {days} días\n\n━━━━━━━━━━━━━━━━━━━━\n🌐 INFORMACIÓN DEL SERVIDOR\n━━━━━━━━━━━━━━━━━━━━\n• Host/IP: {s['host']}\n• IP: {s['ip']}\n• Puerto: 443\n• Red: WebSocket\n• Path: /vmess\n• Seguridad: TLS\n\n━━━━━━━━━━━━━━━━━━━━\n🔗 VMESS\n━━━━━━━━━━━━━━━━━━━━\n{link}\n\n━━━━━━━━━━━━━━━━━━━━\n💎 KEVINTECH MULTI SCRIPT\n━━━━━━━━━━━━━━━━━━━━'''

def protocol_status():
 out=[]
 for name,svc,icon in SERVICES:
  try:active=subprocess.run(['systemctl','is-active','--quiet',svc],timeout=3).returncode==0
  except:active=False
  out.append((name,svc,icon,active))
 return out

def render_template(name,**values):
 try:html=(WEB/'templates'/name).read_text(encoding='utf8')
 except:return '<!doctype html><html><body><h1>404</h1><p>Plantilla no encontrada.</p></body></html>'
 for k,v in values.items():html=html.replace('{{'+k+'}}',str(v))
 return html.replace('{{PREFIX}}',PREFIX)

def page(title,body,user=None):
 s=site_settings();nav=''
 if user:
  role=user.get('role');
  toggle='<button class="menu-toggle" id="menuToggle" aria-label="Abrir menú" aria-expanded="false">☰</button>'
  sidebar=f'''<aside class="sidebar" id="sidebar" aria-label="Menú principal"><div class="brand">⚡ KEVINTECH <button class="menu-close" id="menuClose" aria-label="Cerrar menú">×</button></div><div class="menu-scroll">
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false">🏠 Inicio <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/dashboard">📊 Panel</a><a href="{PREFIX}/account/create">➕ Crear cuenta</a>{'<a href="'+PREFIX+'/admin/users">👥 Usuarios</a>' if role=='admin' else ''}<a href="{PREFIX}/online">🟢 Online</a><a href="{PREFIX}/referrals">🎁 Referidos</a>{'<a href="'+PREFIX+'/admin/accounts/delete">🗑️ Eliminar cuenta</a>'}</div></div>
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false">⚙️ Protocolos <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/protocols">📋 Todos</a><a href="{PREFIX}/protocols?status=active">🟢 Protocolos activos</a><a href="{PREFIX}/protocols?status=inactive">🔴 Protocolos inactivos</a></div></div>
  {'<a class="menu-item-link" href="'+PREFIX+'/console">⌨️ Consola</a>' if role=='admin' else ''}
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false">⚙️ Configuración <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/profile">👤 Perfil</a>{'<a href="'+PREFIX+'/admin/settings/ads">📢 Ajuste de ads</a><a href="'+PREFIX+'/admin/settings/general">📝 Ajuste general</a><a href="'+PREFIX+'/admin/settings/quotas">📅 Cuotas de creación</a>' if role=='admin' else ''}</div></div>
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false">ℹ️ About <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/about">🏢 Sobre nosotros</a><a href="{PREFIX}/about?section=privacy">🔒 Política de privacidad</a><a href="{PREFIX}/about?section=cookies">🍪 Política de cookies</a><a href="{PREFIX}/about?section=terms">📜 Términos y condiciones</a></div></div>
  </div><a class="menu-item-link exit" href="{PREFIX}/logout">↪ Salir</a></aside>'''
 else:toggle='';sidebar=''
 return render_template('base.html',TITLE=html_escape(title),SITE_TITLE=html_escape(s.get('site_title','KevinTech Multi Script')),TOGGLE=toggle,SIDEBAR=sidebar,BODY=body)

def tpl(name,user=None,title='',**values):return page(title,render_template(name,**values),user)

class Handler(BaseHTTPRequestHandler):
 server_version='KevinTechWeb/4.0'
 def log_message(self,fmt,*args):pass
 def route_path(self):
  p=urlparse(self.path).path
  if PREFIX and p.startswith(PREFIX):p=p[len(PREFIX):] or '/'
  return p
 def do_HEAD(self):self.send(200,'text/html; charset=utf8','')
 def send(self,status=200,ctype='text/html; charset=utf8',body=''):
  b=body.encode() if isinstance(body,str) else body;self.send_response(status);self.send_header('Content-Type',ctype);self.send_header('Content-Length',str(len(b)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(b)
 def redirect(self,to):self.send_response(303);self.send_header('Location',PREFIX+to if to.startswith('/') else to);self.send_header('Content-Length','0');self.end_headers()
 def cookies(self):c=cookies.SimpleCookie();c.load(self.headers.get('Cookie',''));return c
 def session(self):
  c=self.cookies().get('kt_session');
  if not c:return None
  con=db();r=con.execute('SELECT * FROM sessions WHERE token=? AND expires>?',(c.value,now())).fetchone()
  if not r:con.close();return None
  if r['role']=='admin':u={'role':'admin','username':cfg().get('admin_username','admin'),'id':0}
  else:
   x=con.execute('SELECT * FROM users WHERE id=? AND active=1',(r['user_id'],)).fetchone();u=dict(x) if x else None
   if u:u['role']='user'
  con.close();return u
 def set_session(self,user_id,role):
  tok=secrets.token_urlsafe(32);con=db();con.execute('DELETE FROM sessions WHERE expires<?',(now(),));con.execute('INSERT INTO sessions VALUES(?,?,?,?)',(tok,user_id,role,now()+SESSION_TTL));con.commit();con.close();c=cookies.SimpleCookie();c['kt_session']=tok;c['kt_session']['path']=PREFIX or '/';c['kt_session']['httponly']=True;c['kt_session']['secure']=True;c['kt_session']['samesite']='Lax';self.extra_cookie=c.output(header='').strip()
 def read_post(self):n=int(self.headers.get('Content-Length','0'));return parse_qs(self.rfile.read(min(n,1024*1024)).decode(errors='ignore'),keep_blank_values=True)
 def val(self,d,k,default=''):return d.get(k,[default])[0].strip()
 def auth_cookie_redirect(self,to):self.send_response(303);self.send_header('Location',PREFIX+to);self.send_header('Set-Cookie',self.extra_cookie);self.send_header('Content-Length','0');self.end_headers()
 def do_GET(self):
  p=self.route_path();u=self.session()
  routes={'/login':self.login_page,'/register':self.register_page,'/dashboard':lambda:self.dashboard(u),'/protocols':lambda:self.protocols(u),'/profile':lambda:self.profile(u),'/online':lambda:self.online(u),'/referrals':lambda:self.referrals(u),'/account':lambda:self.account_detail(u),'/account/create':lambda:self.account_create_page(u),'/admin':lambda:self.admin(u),'/admin/users':lambda:self.admin_users(u),'/admin/accounts/delete':lambda:self.admin_delete_accounts(u),'/console':lambda:self.console(u),'/admin/settings':lambda:self.admin_settings_redirect(u),'/admin/settings/ads':lambda:self.admin_settings(u,'ads'),'/admin/settings/general':lambda:self.admin_settings(u,'general'),'/admin/settings/quotas':lambda:self.admin_settings(u,'quotas'),'/about':lambda:self.about(u),'/ad/watch':lambda:self.ad_watch(u)}
  if p in ('/','/index','/index.html'):return self.redirect('/dashboard' if u else '/login')
  if p=='/logout':
   c=self.cookies().get('kt_session');
   if c:
    con=db();con.execute('DELETE FROM sessions WHERE token=?',(c.value,));con.commit();con.close()
   return self.redirect('/login')
  if p=='/404.html':return self.send(404,body=tpl('404.html',u,'Página no encontrada'))
  if p in routes:return routes[p]()
  return self.send(404,body=tpl('404.html',u,'Página no encontrada'))
 def do_POST(self):
  p=self.route_path();d=self.read_post();u=self.session()
  routes={'/login':lambda:self.login_post(d),'/register':lambda:self.register_post(d),'/profile':lambda:self.profile_post(u,d),'/account/create':lambda:self.account_create(u,d),'/account/delete':lambda:self.account_delete(u,d),'/account/renew':lambda:self.account_renew(u,d),'/admin/settings/ads':lambda:self.admin_settings_post(u,d,'ads'),'/admin/settings/general':lambda:self.admin_settings_post(u,d,'general'),'/admin/settings/quotas':lambda:self.admin_settings_post(u,d,'quotas'),'/admin/accounts/delete':lambda:self.admin_delete_post(u,d),'/console':lambda:self.console_post(u,d),'/referrals/redeem':lambda:self.referral_redeem(u,d),'/ad/complete':lambda:self.ad_complete(u,d)}
  if p in routes:return routes[p]()
  return self.send(404,body=tpl('404.html',u,'Página no encontrada'))
 def login_page(self,msg=''):return self.send(200,body=tpl('login.html',None,'Ingreso',MSG=msg))
 def login_post(self,d):
  user=self.val(d,'username');pw=self.val(d,'password');con=db();a=cfg();ok=False;role='';uid=0
  if hmac.compare_digest(user,a.get('admin_username','')) and verify_password(pw,a.get('admin_password_hash','')):ok=True;role='admin'
  else:
   r=con.execute('SELECT * FROM users WHERE username=? AND active=1',(user,)).fetchone()
   if r and verify_password(pw,r['password_hash']):ok=True;role='user';uid=r['id']
  con.close()
  if not ok:return self.login_page('<div class="notice bad">Usuario o contraseña incorrectos.</div>')
  self.set_session(uid,role);return self.auth_cookie_redirect('/dashboard')
 def register_page(self,msg=''):
  ref=html_escape(parse_qs(urlparse(self.path).query).get('ref',[''])[0]);return self.send(200,body=tpl('register.html',None,'Registro',MSG=msg,REF=ref))
 def register_post(self,d):
  name=self.val(d,'name');user=self.val(d,'username');pw=self.val(d,'password');ref=self.val(d,'ref')
  if not name or not safe_web_username(user) or len(pw)<6:return self.register_page('<div class="notice bad">Datos inválidos. La contraseña debe tener 6 caracteres o más.</div>')
  c=db()
  if c.execute('SELECT 1 FROM users WHERE username=?',(user,)).fetchone():c.close();return self.register_page('<div class="notice bad">Ese usuario web ya existe.</div>')
  code=secrets.token_urlsafe(7);referred=None
  admin_code=cfg().get('admin_referral_code','')
  admin_referred=bool(ref and admin_code and hmac.compare_digest(ref,admin_code))
  if ref and not admin_referred:
   rr=c.execute('SELECT id FROM users WHERE referral_code=? AND active=1',(ref,)).fetchone()
   if rr:referred=rr['id']
  c.execute('INSERT INTO users(username,password_hash,name,created_at,referral_code,referred_by,referral_points) VALUES(?,?,?,?,?,?,?)',(user,hash_password(pw),name,datetime.now().isoformat(timespec='seconds'),code,referred,1))
  uid=c.execute('SELECT last_insert_rowid()').fetchone()[0]
  if referred:c.execute('UPDATE users SET referral_points=referral_points+2 WHERE id=?',(referred,))
  c.commit();c.close()
  if admin_referred:
   conf=cfg();conf['admin_referral_points']=int(conf.get('admin_referral_points',0))+2;save_cfg(conf)
  self.set_session(uid,'user');return self.auth_cookie_redirect('/dashboard')
 def dashboard(self,u):
  if not u:return self.redirect('/login')
  c=db();q='SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id '
  if u['role']=='user':rows=c.execute(q+'WHERE a.user_id=? ORDER BY a.id DESC',(u['id'],)).fetchall()
  else:rows=c.execute(q+'ORDER BY a.id DESC LIMIT 100').fetchall()
  cards_list=[]
  for a in rows:
   renew_button='<form class="inline" method="post" action="%s/account/renew"><input type="hidden" name="id" value="%s"><button class="btn primary">Renovar</button></form>'%(PREFIX,a['id']) if u['role']=='admin' else ''
   delete_button='<form class="inline" method="post" action="%s/account/delete"><input type="hidden" name="id" value="%s"><button class="btn danger">Eliminar</button></form>'%(PREFIX,a['id'])
   cards_list.append('<div class="card account-card"><div class="account-head"><h3>👤 %s</h3><span class="tag">%s</span></div><p class="muted">Propietario: %s · Expira: %s</p><p>Online: <b class="oktxt">%s</b> · Límite: <b>%s</b> IP</p><a class="btn" href="%s/account?id=%s">Ver cuenta</a>%s%s</div>'%(html_escape(a['username']),html_escape(a['type']).upper(),html_escape(a['owner']),html_escape(a['expiration'] or '—'),len(account_online(a['username'])),a['ip_limit'],PREFIX,a['id'],renew_button,delete_button))
  cards=''.join(cards_list)
  c.close();st=site_settings();return self.send(200,body=tpl('dashboard.html',u,'Inicio',COUNT=len(rows),ONLINE=len(all_online()),POINTS=(u.get('referral_points',0) if u['role']=='user' else int(cfg().get('admin_referral_points',0)) ),ACCOUNTS=cards or '<div class="card">No hay cuentas para mostrar.</div>',SITE_TITLE=html_escape(st.get('home_title') or st['site_title']),SITE_DESC=html_escape(st.get('home_description') or st['site_description'])) )
 def protocols(self,u):
  if not u:return self.redirect('/login')
  status=parse_qs(urlparse(self.path).query).get('status',['all'])[0]
  items=protocol_status()
  if status=='active':items=[x for x in items if x[3]]
  elif status=='inactive':items=[x for x in items if not x[3]]
  rows=[]
  for n,s,i,a in items:
   rows.append('<div class="service-card"><div class="service-icon">%s</div><div class="service-main"><strong>%s</strong><span class="muted">%s</span></div><span class="status %s">%s</span></div>'%(i,html_escape(n),html_escape(s),'on' if a else 'off','ACTIVO' if a else 'INACTIVO'))
  st=site_settings();return self.send(200,body=tpl('protocols.html',u,'Protocolos',ROWS=''.join(rows),COUNT=len(items),FILTER=html_escape(status),PROTO_TITLE=html_escape(st.get('protocols_title','Protocolos')),PROTO_DESC=html_escape(st.get('protocols_description','Consulta el estado real de los servicios del VPS.'))))
 def profile(self,u):
  if not u:return self.redirect('/login')
  if u['role']=='admin':
   c=cfg();body=tpl('profile.html',u,'Perfil',NAME='Administrador',USERNAME=html_escape(c.get('admin_username','admin')),CREATED='—',POINTS=int(c.get('admin_referral_points',0)),CODE=html_escape(c.get('admin_referral_code','')),ADMIN=True)
  else:
   body=tpl('profile.html',u,'Perfil',NAME=html_escape(u['name']),USERNAME=html_escape(u['username']),CREATED=html_escape(u['created_at']),POINTS=u['referral_points'],CODE=html_escape(u['referral_code']),ADMIN=False)
  return self.send(200,body=body)
 def profile_post(self,u,d):
  if not u:return self.redirect('/login')
  if u['role']=='admin':
   c=cfg();c['admin_username']=self.val(d,'name') or c.get('admin_username','admin');pw=self.val(d,'password')
   if pw:
    if len(pw)<8:return self.send(400,body=tpl('message.html',u,'Perfil',MESSAGE='<div class="notice bad">La contraseña de administrador debe tener al menos 8 caracteres.</div>'))
    c['admin_password_hash']=hash_password(pw)
   save_cfg(c);return self.redirect('/profile')
  name=self.val(d,'name') or u['name'];pw=self.val(d,'password');c=db();c.execute('UPDATE users SET name=?,password_hash=? WHERE id=?',(name,hash_password(pw),u['id'])) if pw else c.execute('UPDATE users SET name=? WHERE id=?',(name,u['id']));c.commit();c.close();return self.redirect('/profile')
 def online(self,u):
  if not u:return self.redirect('/login')
  c=db();rows=all_online() if u['role']=='admin' else []
  if u['role']=='user':
   names={r['username'] for r in c.execute('SELECT username FROM accounts WHERE user_id=?',(u['id'],)).fetchall()};rows=[x for x in all_online() if x[0] in names]
  c.close();html=''.join('<tr><td>%s</td><td>%s</td></tr>'%(html_escape(a),html_escape(b)) for a,b in rows) or '<tr><td colspan="2">No hay conexiones activas.</td></tr>'
  st=site_settings();return self.send(200,body=tpl('online.html',u,'Online',ROWS=html,ONLINE_TITLE=html_escape(st.get('online_title','Online')),ONLINE_DESC=html_escape(st.get('online_description','Conexiones SSH detectadas actualmente.'))))
 def referrals(self,u):
  if not u:return self.redirect('/login')
  if u['role']=='admin':
   c=db();rows=c.execute('SELECT username,name,referral_points,active FROM users ORDER BY referral_points DESC').fetchall();c.close();html=''.join('<tr><td>%s</td><td>%s</td><td><b>%s</b></td><td>%s</td></tr>'%(html_escape(x['username']),html_escape(x['name']),x['referral_points'],'Activo' if x['active'] else 'Bloqueado') for x in rows) or '<tr><td colspan="4">No hay usuarios.</td></tr>'
   host=(server_domain() or self.headers.get('X-Forwarded-Host','').split(',')[0].strip() or self.headers.get('Host','').split(':')[0]).strip()
   scheme='https' if self.headers.get('X-Forwarded-Proto','https').split(',')[0].strip()=='https' else 'http'
   root=(host if host.startswith('http://') or host.startswith('https://') else scheme+'://'+host).rstrip('/')
   link=root+'/register?ref='+cfg().get('admin_referral_code','')
   st=site_settings();return self.send(200,body=tpl('referrals.html',u,'Referidos',ADMIN_ROWS=html,POINTS=int(cfg().get('admin_referral_points',0)),LINK=html_escape(link),REF_TITLE=html_escape(st.get('referrals_title','Referidos')),REF_DESC=html_escape(st.get('referrals_description','Comparte tu enlace y acumula puntos.'))))
  host=(server_domain() or self.headers.get('X-Forwarded-Host','').split(',')[0].strip() or self.headers.get('Host','').split(':')[0]).strip()
  scheme='https' if self.headers.get('X-Forwarded-Proto','https').split(',')[0].strip()=='https' else 'http'
  root=(host if host.startswith('http://') or host.startswith('https://') else scheme+'://'+host).rstrip('/')
  link=root+'/register?ref='+u['referral_code']
  st=site_settings();return self.send(200,body=tpl('referrals.html',u,'Referidos',POINTS=u['referral_points'],LINK=html_escape(link),ADMIN_ROWS='',REF_TITLE=html_escape(st.get('referrals_title','Referidos')),REF_DESC=html_escape(st.get('referrals_description','Comparte tu enlace y acumula puntos.'))))
 def referral_redeem(self,u,d):return self.send(400,body=page('Referidos','<div class="notice bad">El canje se gestionará desde una versión posterior.</div>',u))
 def account_detail(self,u):
  if not u:return self.redirect('/login')
  try:aid=int(parse_qs(urlparse(self.path).query).get('id',['0'])[0])
  except:aid=0
  c=db();a=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id WHERE a.id=?',(aid,)).fetchone()
  if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body=tpl('404.html',u,'Cuenta no encontrada'))
  pw=decrypt_credential(a['credential']);ips=account_online(a['username']);c.close();info=server_info()
  if a['type']=='ssh':details=ssh_message(a['username'],pw,a['expiration'],max(1,(datetime.strptime(a['expiration'],'%Y-%m-%d')-datetime.strptime(a['created_at'][:10],'%Y-%m-%d')).days),a['ip_limit'])
  else:details=v2ray_message(a['username'],pw,a['expiration'],max(1,(datetime.strptime(a['expiration'],'%Y-%m-%d')-datetime.strptime(a['created_at'][:10],'%Y-%m-%d')).days))
  return self.send(200,body=tpl('account.html',u,'Cuenta',USERNAME=html_escape(a['username']),TYPE=html_escape(a['type']),PASSWORD=html_escape(pw),EXPIRATION=html_escape(a['expiration'] or '—'),LIMIT=a['ip_limit'],ONLINE=len(ips),IPS=', '.join(html_escape(x) for x in ips) if ips else 'Ninguna',ID=a['id'],DETAILS=html_escape(details),OWNER=html_escape(a['owner']),HOST=html_escape(info['host']),RENEW_BUTTON='<form class="inline" method="post" action="'+PREFIX+'/account/renew"><input type="hidden" name="id" value="'+str(a['id'])+'"><button class="btn primary">♻️ Renovar</button></form>' if u['role']=='admin' else ''))
 def account_create_page(self,u):
  if not u:return self.redirect('/login')
  st=site_settings();days=st['quota_admin_days'] if u['role']=='admin' else st['quota_user_days'];limit=st['quota_admin_limit'] if u['role']=='admin' else st['quota_user_limit']
  return self.send(200,body=tpl('account_create.html',u,'Crear cuenta',DAYS=days,LIMIT=limit,OWNERS=''))
 def account_create(self,u,d):
  if not u:return self.send(403,body='403')
  # A configured ad gate is mandatory before account creation.
  conf=cfg();ad_count=int(conf.get('ads',{}).get('create',0) or 0)
  if conf.get('ads_enabled') and ad_count>0:
   token=secrets.token_urlsafe(32);payload={k:v[0] for k,v in d.items() if k not in ('ad_token',)}
   c=db();c.execute('INSERT INTO ad_tokens(token,user_id,action,account_id,expires,completed,payload) VALUES(?,?,?,?,?,?,?)',(token,int(u['id']), 'create',None,now()+TOKEN_TTL,0,json.dumps(payload)));c.commit();c.close()
   return self.redirect('/ad/watch?token='+token)
  return self.create_account_now(u,d)
 def create_account_now(self,u,d):
  st=site_settings();days=int(st['quota_admin_days'] if u['role']=='admin' else st['quota_user_days']);limit=int(st['quota_admin_limit'] if u['role']=='admin' else st['quota_user_limit']);typ=self.val(d,'type','ssh');user=self.val(d,'username').lower();pw=self.val(d,'password')
  owner_id=u['id'] if u['role']=='user' else 0
  if u['role']=='admin':
   c=db();first=c.execute('SELECT id FROM users WHERE active=1 ORDER BY id LIMIT 1').fetchone();c.close()
   if not first:return self.send(400,body=tpl('message.html',u,'Crear cuenta',MESSAGE='<div class="notice bad">No hay usuarios web registrados para asignar esta cuenta. Crea un usuario web primero.</div>'))
   owner_id=first['id']
  if typ=='ssh':ok,msg=create_ssh_account(user,pw,days,limit);credential=pw;expiration=msg
  elif typ in ('v2ray','vmess'):ok,msg,credential=create_v2ray_account(user,days);expiration=msg
  else:return self.send(400,body='Tipo de cuenta inválido')
  if not ok:return self.send(400,body=tpl('message.html',u,'Error',MESSAGE='<div class="notice bad">%s</div>'%html_escape(msg)))
  c=db();c.execute('INSERT INTO accounts(user_id,username,type,credential,expiration,ip_limit,created_at) VALUES(?,?,?,?,?,?,?)',(owner_id,user,'v2ray' if typ!='ssh' else 'ssh',crypt_credential(credential),expiration,limit,datetime.now().isoformat(timespec='seconds')));aid=c.execute('SELECT last_insert_rowid()').fetchone()[0];c.commit();c.close();return self.redirect('/account?id=%d'%aid)
 def ad_watch(self,u):
  if not u:return self.redirect('/login')
  token=parse_qs(urlparse(self.path).query).get('token',[''])[0]
  c=db();row=c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND action=? AND expires>? AND completed=0',(token,int(u['id']),'create',now())).fetchone();c.close()
  if not row:return self.send(400,body=tpl('message.html',u,'Publicidad',MESSAGE='<div class="notice bad">El paso de publicidad expiró. Vuelve a intentar crear la cuenta.</div><a class="btn" href="%s/account/create">Volver</a>'%PREFIX))
  conf=cfg();count=int(conf.get('ads',{}).get('create',0) or 0);zone=html_escape(conf.get('monetag_zone','11217882'))
  return self.send(200,body=tpl('ad_watch.html',u,'Publicidad',COUNT=count,ACTION='crear la cuenta',ZONE=zone,TOKEN=html_escape(token),COMPLETE=PREFIX+'/ad/complete'))
 def ad_complete(self,u,d):
  if not u:return self.send(403,body='403')
  token=self.val(d,'token');c=db();row=c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND action=? AND expires>? AND completed=0',(token,int(u['id']),'create',now())).fetchone()
  if not row:c.close();return self.send(400,body=tpl('message.html',u,'Publicidad',MESSAGE='<div class="notice bad">El token de publicidad es inválido o expiró.</div>'))
  c.execute('UPDATE ad_tokens SET completed=1 WHERE token=?',(token,));c.commit();c.close()
  try:payload=json.loads(row['payload'])
  except:payload={}
  return self.create_account_now(u,payload)
 def account_delete(self,u,d):
  if not u:return self.send(403,body='403')
  try:aid=int(self.val(d,'id'))
  except:return self.send(400,body='ID inválido')
  c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
  if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body='Cuenta no encontrada')
  ok=delete_v2ray(a['username']) if a['type']=='v2ray' else delete_ssh(a['username'])[0];c.execute('DELETE FROM accounts WHERE id=?',(aid,));c.commit();c.close();return self.send(200,body=tpl('message.html',u,'Eliminar cuenta',MESSAGE='<div class="notice %s">%s</div><a class="btn" href="%s/dashboard">Volver</a>'%('oktxt' if ok else 'bad','Cuenta eliminada.' if ok else 'No se pudo eliminar completamente la cuenta.',PREFIX)))
 def account_renew(self,u,d):
  if not u or u['role']!='admin':return self.send(403,body='Solo el administrador puede renovar cuentas.')
  try:aid=int(self.val(d,'id'))
  except:return self.send(400,body='ID inválido')
  st=site_settings();days=int(st['quota_admin_days'] if u['role']=='admin' else st['quota_user_days']);c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
  if not a:c.close();return self.send(404,body='Cuenta no encontrada')
  ok,msg=renew_account(a,days)
  if ok:c.execute('UPDATE accounts SET expiration=? WHERE id=?',(msg,aid));c.commit()
  c.close();return self.send(200,body=tpl('message.html',u,'Renovar',MESSAGE='<div class="notice %s">%s</div><a class="btn" href="%s/account?id=%s">Volver</a>'%('oktxt' if ok else 'bad',html_escape(msg),PREFIX,aid)))
 def admin(self,u):
  if not u or u['role']!='admin':return self.redirect('/login')
  return self.dashboard(u)
 def admin_users(self,u):
  if not u or u['role']!='admin':return self.redirect('/login')
  c=db();rows=c.execute('SELECT id,username,name,referral_points,active FROM users ORDER BY id DESC').fetchall();c.close();html=''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(html_escape(x['username']),html_escape(x['name']),x['referral_points'],'Activo' if x['active'] else 'Bloqueado') for x in rows) or '<tr><td colspan="4">No hay usuarios.</td></tr>';return self.send(200,body=tpl('admin_users.html',u,'Usuarios',ROWS=html))
 def admin_delete_accounts(self,u):
  if not u:return self.redirect('/login')
  c=db()
  if u['role']=='admin':rows=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id ORDER BY a.id DESC').fetchall()
  else:rows=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id WHERE a.user_id=? ORDER BY a.id DESC',(u['id'],)).fetchall()
  c.close();html=''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td><form method="post"><input type="hidden" name="id" value="%s"><button class="btn danger">Eliminar</button></form></td></tr>'%(html_escape(x['username']),html_escape(x['owner']),html_escape(x['type']),x['id']) for x in rows) or '<tr><td colspan="4">No hay cuentas.</td></tr>';return self.send(200,body=tpl('admin_delete.html',u,'Eliminar cuenta',ROWS=html))
 def admin_delete_post(self,u,d):return self.account_delete(u,d)
 def admin_settings_redirect(self,u):return self.redirect('/admin/settings/general' if u and u.get('role')=='admin' else '/profile')
 def admin_settings(self,u,section):
  if not u or u['role']!='admin':return self.redirect('/login')
  c=cfg();st=site_settings();
  if section=='ads':body=tpl('admin_settings_ads.html',u,'Ajuste de ads',ADS_CHECKED='checked' if c.get('ads_enabled') else '',ZONE=html_escape(c.get('monetag_zone','11217882')),CREATE=c.get('ads',{}).get('create',0),DELETE=c.get('ads',{}).get('delete',0),RENEW=c.get('ads',{}).get('renew',0))
  elif section=='quotas':body=tpl('admin_settings_quotas.html',u,'Cuotas',USER_DAYS=st['quota_user_days'],USER_LIMIT=st['quota_user_limit'],ADMIN_DAYS=st['quota_admin_days'],ADMIN_LIMIT=st['quota_admin_limit'])
  else:body=tpl('admin_settings_general.html',u,'Ajuste general',TITLE=html_escape(st['site_title']),DESCRIPTION=html_escape(st['site_description']),HOME_TITLE=html_escape(st.get('home_title','Inicio')),HOME_DESC=html_escape(st.get('home_description','')),PROTOCOLS_TITLE=html_escape(st.get('protocols_title','Protocolos')),PROTOCOLS_DESC=html_escape(st.get('protocols_description','')),ONLINE_TITLE=html_escape(st.get('online_title','Online')),ONLINE_DESC=html_escape(st.get('online_description','')),REFERRALS_TITLE=html_escape(st.get('referrals_title','Referidos')),REFERRALS_DESC=html_escape(st.get('referrals_description','')),ABOUT=html_escape(st['about_us']),PRIVACY=html_escape(st['privacy']),COOKIES=html_escape(st['cookies']),TERMS=html_escape(st['terms']))
  return self.send(200,body=body)
 def admin_settings_post(self,u,d,section):
  if not u or u['role']!='admin':return self.send(403,body='403')
  if section=='ads':
   c=cfg();c['ads_enabled']='ads_enabled' in d;c['monetag_zone']=self.val(d,'monetag_zone','11217882')
   try:c['ads']={'create':max(0,min(20,int(self.val(d,'ad_create','0')))),'delete':max(0,min(20,int(self.val(d,'ad_delete','0')))),'renew':max(0,min(20,int(self.val(d,'ad_renew','0'))))}
   except:pass
   save_cfg(c);return self.redirect('/admin/settings/ads')
  if section=='quotas':
   try:vals={'quota_user_days':max(1,min(3650,int(self.val(d,'user_days')))),'quota_user_limit':max(0,min(100,int(self.val(d,'user_limit')))),'quota_admin_days':max(1,min(3650,int(self.val(d,'admin_days')))),'quota_admin_limit':max(0,min(100,int(self.val(d,'admin_limit'))))}
   except:return self.send(400,body='Cuotas inválidas')
   save_settings(vals);return self.redirect('/admin/settings/quotas')
  save_settings({'site_title':self.val(d,'site_title','KevinTech Multi Script'),'site_description':self.val(d,'site_description'),'home_title':self.val(d,'home_title','Inicio'),'home_description':self.val(d,'home_description'),'protocols_title':self.val(d,'protocols_title','Protocolos'),'protocols_description':self.val(d,'protocols_description'),'online_title':self.val(d,'online_title','Online'),'online_description':self.val(d,'online_description'),'referrals_title':self.val(d,'referrals_title','Referidos'),'referrals_description':self.val(d,'referrals_description'),'about_us':self.val(d,'about_us'),'privacy':self.val(d,'privacy'),'cookies':self.val(d,'cookies'),'terms':self.val(d,'terms')});return self.redirect('/admin/settings/general')
 def about(self,u):
  if not u:return self.redirect('/login')
  st=site_settings();section=parse_qs(urlparse(self.path).query).get('section',['about'])[0];mapx={'about':('Sobre nosotros','about_us'),'privacy':('Política de privacidad','privacy'),'cookies':('Política de cookies','cookies'),'terms':('Términos y condiciones','terms')};title,key=mapx.get(section,mapx['about']);edit=''
  if u['role']=='admin':edit='<a class="btn" href="%s/admin/settings/general">✏️ Editar contenido</a>'%PREFIX
  return self.send(200,body=tpl('about.html',u,title,HEADING=title,CONTENT=html_escape(st[key]).replace('\n','<br>'),EDIT=edit))
 def console(self,u):
  if not u or u['role']!='admin':return self.redirect('/login')
  return self.send(200,body=tpl('console.html',u,'Consola',PREFIX=PREFIX))
 def console_post(self,u,d):
  if not u or u['role']!='admin':return self.send(403,body='403')
  cmd=self.val(d,'command');
  if not cmd or len(cmd)>4000:return self.send(400,body='Comando inválido')
  rc,out=shell(cmd,30);return self.send(200,'text/plain; charset=utf8',out+'\n\n[exit %d]'%rc)

def delete_ssh(username):
 if not safe_username(username) or username in ('root','nobody','daemon','www-data'):return False,'Cuenta protegida.'
 rc,out=shell('userdel -r -f %s'%shlex.quote(username),15);limits=BASE/'limits.conf'
 if limits.exists():limits.write_text('\n'.join(x for x in limits.read_text(errors='ignore').splitlines() if not x.startswith(username+':'))+'\n')
 return rc==0,out or ('Cuenta eliminada.' if rc==0 else 'No se pudo eliminar la cuenta.')

def main():
 if os.geteuid()!=0:raise SystemExit('KevinTech Web debe ejecutarse como root.')
 ensure_admin();log('WEB START %s:%s prefix=%s'%(HOST,PORT,PREFIX));ThreadingHTTPServer((HOST,PORT),Handler).serve_forever()
if __name__=='__main__':main()
