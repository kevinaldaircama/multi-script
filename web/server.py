#!/usr/bin/env python3
import base64, hashlib, hmac, json, os, re, secrets, sqlite3, subprocess, time, uuid, shlex, shutil, io, zipfile, socket, urllib.request, urllib.error
from datetime import datetime, timedelta
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse, quote

BASE=Path('/etc/kevintech'); WEB=BASE/'web'; DATA=WEB/'data'; DB=DATA/'web.sqlite3'; CONFIG=DATA/'config.json'; KEYFILE=DATA/'.credential.key'; LOG=DATA/'web.log'
HOST='127.0.0.1'; PORT=int(os.environ.get('KEVINTECH_WEB_PORT','18080')); PREFIX=os.environ.get('KEVINTECH_WEB_PREFIX','').strip().rstrip('/'); SESSION_TTL=86400*3; TOKEN_TTL=600
DEFAULT_SETTINGS={'site_title':'KevinTech Multi Script','site_description':'Panel web para administrar tu VPS y tus cuentas.','currency_symbol':'S/','quota_user_days':7,'quota_user_limit':1,'quota_admin_days':30,'quota_admin_limit':5,'quota_user_accounts':2,'quota_renew_points':4,'about_us':'Somos un proyecto dedicado a ofrecer herramientas sencillas para administrar servicios de VPS.','privacy':'Usamos tus datos únicamente para administrar tu cuenta web y las funciones del panel.','cookies':'Este panel utiliza cookies técnicas para mantener la sesión iniciada.','terms':'El uso del panel y de los servicios del VPS debe respetar las leyes y las políticas de tu proveedor.','home_title':'Inicio','home_description':'Administra tus cuentas y consulta el estado de tu VPS.','protocols_title':'Protocolos','protocols_description':'Consulta el estado real de los servicios del VPS.','online_title':'Online','online_description':'Conexiones SSH detectadas actualmente.','referrals_title':'Referidos','referrals_description':'Comparte tu enlace y acumula puntos.','social_facebook':'','social_instagram':'','social_tiktok':'','social_whatsapp':'','contact_email':'','contact_phone':''}
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
 # SQL is the primary store for application configuration; config.json remains a compatibility mirror.
 try:
  con=db();row=con.execute("SELECT value FROM settings WHERE key='__app_config__'").fetchone();con.close()
  if row:return json.loads(row['value'])
 except Exception:pass
 try:return json.loads(CONFIG.read_text(encoding='utf8'))
 except:return {}
def save_cfg(c):
 payload=json.dumps(c,indent=2,ensure_ascii=False);CONFIG.write_text(payload,encoding='utf8');os.chmod(CONFIG,0o600)
 con=db();con.execute("INSERT INTO settings(key,value) VALUES('__app_config__',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",(json.dumps(c,ensure_ascii=False),));con.commit();con.close()

def db():
 DATA.mkdir(parents=True,exist_ok=True); c=sqlite3.connect(DB,timeout=10); c.row_factory=sqlite3.Row; c.execute('PRAGMA journal_mode=WAL'); c.execute('PRAGMA foreign_keys=ON')
 c.executescript('''CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,name TEXT NOT NULL,created_at TEXT NOT NULL,referral_code TEXT UNIQUE NOT NULL,referred_by TEXT,referral_points INTEGER NOT NULL DEFAULT 0,referral_renews INTEGER NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1);
 CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,username TEXT UNIQUE NOT NULL,type TEXT NOT NULL DEFAULT 'ssh',credential TEXT NOT NULL,expiration TEXT,ip_limit INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
 CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id INTEGER,role TEXT NOT NULL,expires REAL NOT NULL);
 CREATE TABLE IF NOT EXISTS ad_tokens(token TEXT PRIMARY KEY,user_id INTEGER NOT NULL,action TEXT NOT NULL,account_id INTEGER,expires REAL NOT NULL,completed INTEGER NOT NULL DEFAULT 0,payload TEXT NOT NULL DEFAULT '{}');
 CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL); CREATE TABLE IF NOT EXISTS notifications(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER,title TEXT NOT NULL,message TEXT NOT NULL,kind TEXT NOT NULL DEFAULT 'general',is_read INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS plan_orders(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,plan_id TEXT NOT NULL,plan_title TEXT NOT NULL,price TEXT NOT NULL,payment TEXT NOT NULL,status TEXT NOT NULL,created_at TEXT NOT NULL);''')
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
  toggle='<button class="menu-toggle" id="menuToggle" aria-label="Abrir menú" aria-expanded="false"><i class="fa-solid fa-bars"></i></button><a class="notification-bell" href="'+PREFIX+'/notifications" aria-label="Notificaciones"><i class="fa-regular fa-bell"></i><span class="bell-label">Notificaciones</span></a>'
  sidebar=f'''<aside class="sidebar" id="sidebar" aria-label="Menú principal"><div class="brand">⚡ {html_escape(s.get('site_title','KevinTech Multi Script'))} <button class="menu-close" id="menuClose" aria-label="Cerrar menú">×</button></div><div class="menu-scroll">
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false"><i class="fa-solid fa-house"></i> Inicio <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/dashboard"><i class="fa-solid fa-chart-line"></i> Panel</a><a href="{PREFIX}/account/create"><i class="fa-solid fa-user-plus"></i> Crear cuenta</a>{'<a href="'+PREFIX+'/admin/users"><i class="fa-solid fa-users"></i> Usuarios</a><a href="'+PREFIX+'/admin/accounts/renew"><i class="fa-solid fa-rotate"></i> Renovar cuenta</a>' if role=='admin' else ''}<a href="{PREFIX}/online"><i class="fa-solid fa-circle-check"></i> Online</a><a href="{PREFIX}/referrals"><i class="fa-solid fa-gift"></i> Referidos</a><a href="{PREFIX}/admin/accounts/delete"><i class="fa-solid fa-trash"></i> Eliminar cuenta</a></div></div>
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false"><i class="fa-solid fa-gears"></i> Protocolos <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/protocols"><i class="fa-solid fa-list"></i> Todos</a><a href="{PREFIX}/protocols?status=active"><i class="fa-solid fa-circle-check"></i> Protocolos activos</a><a href="{PREFIX}/protocols?status=inactive"><i class="fa-solid fa-circle-xmark"></i> Protocolos inactivos</a></div></div>
  {'<a class="menu-item-link" href="'+PREFIX+'/console"><i class="fa-solid fa-terminal"></i> Consola</a>' if role=='admin' else ''}
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false"><i class="fa-solid fa-gem"></i> Planes <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/plans"><i class="fa-solid fa-gem"></i> Planes</a>{'<a href="'+PREFIX+'/plans/settings">⚙️ Configuración</a>' if role=='admin' else ''}<a href="{PREFIX}/plans/history"><i class="fa-solid fa-receipt"></i> Historial</a><a href="{PREFIX}/plans/invoice"><i class="fa-solid fa-file-invoice"></i> Recibos y PDF</a></div></div>
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false"><i class="fa-solid fa-screwdriver-wrench"></i> Herramientas <span>⌄</span></button><div class="submenu">{'<a href="'+PREFIX+'/tools/backup"><i class="fa-solid fa-database"></i> Backup y restauración</a><a href="'+PREFIX+'/tools/block-torrent"><i class="fa-solid fa-ban"></i> Block Torrent</a><a href="'+PREFIX+'/tools/archivo-online"><i class="fa-solid fa-folder-open"></i> Archivo Online</a><a href="'+PREFIX+'/tools/speedtest"><i class="fa-solid fa-gauge-high"></i> Speedtest</a><a href="'+PREFIX+'/tools/detalles-vps"><i class="fa-solid fa-server"></i> Detalles VPS</a><a href="'+PREFIX+'/tools/block-ads"><i class="fa-solid fa-shield-halved"></i> Block Ads</a>' if role=='admin' else ''}<a href="{PREFIX}/tools/scanner"><i class="fa-solid fa-magnifying-glass"></i> Scanner</a><a href="{PREFIX}/tools/payloads"><i class="fa-solid fa-bolt"></i> Generador de Payloads</a></div></div>
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false"><i class="fa-solid fa-gear"></i> Configuración <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/profile"><i class="fa-solid fa-user"></i> Perfil</a>{'<a href="'+PREFIX+'/admin/settings/ads"><i class="fa-solid fa-rectangle-ad"></i> Ajuste de ads</a><a href="'+PREFIX+'/admin/settings/general"><i class="fa-solid fa-sliders"></i> Ajuste general</a><a href="'+PREFIX+'/admin/settings/quotas"><i class="fa-solid fa-calendar-days"></i> Cuotas de creación</a><a href="'+PREFIX+'/admin/notifications"><i class="fa-solid fa-paper-plane"></i> Enviar notificaciones</a>' if role=='admin' else ''}</div></div>
  <div class="menu-group"><button type="button" class="menu-item has-sub" aria-expanded="false"><i class="fa-solid fa-circle-info"></i> About <span>⌄</span></button><div class="submenu"><a href="{PREFIX}/about"><i class="fa-solid fa-building"></i> Sobre nosotros</a><a href="{PREFIX}/about?section=privacy"><i class="fa-solid fa-lock"></i> Política de privacidad</a><a href="{PREFIX}/about?section=cookies"><i class="fa-solid fa-cookie-bite"></i> Política de cookies</a><a href="{PREFIX}/about?section=terms"><i class="fa-solid fa-file-contract"></i> Términos y condiciones</a><a href="{PREFIX}/about?section=social"><i class="fa-solid fa-share-nodes"></i> Redes sociales y contacto</a></div></div>
  </div><div class="theme-actions"><button type="button" class="menu-item-link" id="themeToggle"><i class="fa-solid fa-circle-half-stroke"></i> Cambiar a modo claro</button><a class="menu-item-link exit" href="{PREFIX}/logout"><i class="fa-solid fa-right-from-bracket"></i> Salir</a></div></aside>'''
 else:toggle='';sidebar=''
 lang=s.get('language_'+str(user.get('id',0)),'es') if user else 'es'
 return render_template('base.html',TITLE=html_escape(title),SITE_TITLE=html_escape(s.get('site_title','KevinTech Multi Script')),TOGGLE=toggle,SIDEBAR=sidebar,BODY=body,LANG=lang)

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
 def read_multipart(self):
  from email.parser import BytesParser
  from email.policy import default
  n=min(int(self.headers.get('Content-Length','0')),25*1024*1024);raw=self.rfile.read(n)
  msg=BytesParser(policy=default).parsebytes(('MIME-Version: 1.0\r\nContent-Type: '+self.headers.get('Content-Type','')+'\r\n\r\n').encode()+raw)
  out={}
  if msg.is_multipart():
   for part in msg.iter_parts():
    name=part.get_param('name',header='content-disposition')
    if not name:continue
    payload=part.get_payload(decode=True) or b'';filename=part.get_filename()
    if filename:out['_file_'+name]=payload;out['_filename_'+name]=filename
    else:out[name]=[payload.decode(part.get_content_charset() or 'utf8',errors='replace').strip()]
  return out
 def val(self,d,k,default=''):
  v=d.get(k,[default]);v=v[0] if isinstance(v,list) else v
  return v.strip() if isinstance(v,str) else default
 def auth_cookie_redirect(self,to):self.send_response(303);self.send_header('Location',PREFIX+to);self.send_header('Set-Cookie',self.extra_cookie);self.send_header('Content-Length','0');self.end_headers()
 def do_GET(self):
  p=self.route_path();u=self.session()
  routes={'/login':self.login_page,'/register':self.register_page,'/notifications':lambda:self.notifications(u),'/admin/notifications':lambda:self.admin_notifications(u),'/dashboard':lambda:self.dashboard(u),'/protocols':lambda:self.protocols(u),'/profile':lambda:self.profile(u),'/online':lambda:self.online(u),'/referrals':lambda:self.referrals(u),'/account':lambda:self.account_detail(u),'/account/create':lambda:self.account_create_page(u),'/admin':lambda:self.admin(u),'/admin/users':lambda:self.admin_users(u),'/admin/accounts/delete':lambda:self.admin_delete_accounts(u),'/admin/accounts/renew':lambda:self.admin_renew_accounts(u),'/plans':lambda:self.plans(u),'/plans/settings':lambda:self.plans_settings(u),'/plans/history':lambda:self.plans_history(u),'/plans/invoice':lambda:self.plans_invoice(u),'/console':lambda:self.console(u),'/admin/settings':lambda:self.admin_settings_redirect(u),'/admin/settings/ads':lambda:self.admin_settings(u,'ads'),'/admin/settings/general':lambda:self.admin_settings(u,'general'),'/admin/settings/quotas':lambda:self.admin_settings(u,'quotas'),'/about':lambda:self.about(u),'/ad/watch':lambda:self.ad_watch(u),'/tools/block-torrent':lambda:self.tool_page(u,'block-torrent','Block Torrent',True),'/tools/archivo-online':lambda:self.tool_page(u,'archivo-online','Archivo Online',True),'/tools/speedtest':lambda:self.tool_page(u,'speedtest','Speedtest',True),'/tools/detalles-vps':lambda:self.tool_page(u,'detalles-vps','Detalles VPS',True),'/tools/block-ads':lambda:self.tool_page(u,'block-ads','Block Ads',True),'/tools/scanner':lambda:self.tool_page(u,'scanner','Scanner',False),'/tools/payloads':lambda:self.payloads_page(u),'/tools/backup':lambda:self.backup_page(u),'/tools/backup/download':lambda:self.backup_download(u),'/tools/archive-download':lambda:self.archive_download(u)}
  if p in ('/','/index','/index.html'):return self.public_index(u)
  if p=='/logout':
   c=self.cookies().get('kt_session');
   if c:
    con=db();con.execute('DELETE FROM sessions WHERE token=?',(c.value,));con.commit();con.close()
   return self.redirect('/login')
  if p=='/404.html':return self.send(404,body=tpl('404.html',u,'Página no encontrada'))
  if p in routes:return routes[p]()
  return self.send(404,body=tpl('404.html',u,'Página no encontrada'))
 def do_POST(self):
  p=self.route_path();ctype=self.headers.get('Content-Type','');d=self.read_multipart() if ctype.lower().startswith('multipart/form-data') else self.read_post();u=self.session()
  routes={'/login':lambda:self.login_post(d),'/register':lambda:self.register_post(d),'/profile':lambda:self.profile_post(u,d),'/account/create':lambda:self.account_create(u,d),'/account/delete':lambda:self.account_delete(u,d),'/account/renew':lambda:self.account_renew(u,d),'/admin/settings/ads':lambda:self.admin_settings_post(u,d,'ads'),'/admin/settings/general':lambda:self.admin_settings_post(u,d,'general'),'/admin/settings/quotas':lambda:self.admin_settings_post(u,d,'quotas'),'/admin/accounts/delete':lambda:self.admin_delete_post(u,d),'/plans/settings':lambda:self.plans_settings_post(u,d),'/plans/history/action':lambda:self.plans_history_action(u,d),'/admin/notifications':lambda:self.admin_notifications_post(u,d),'/plans/settings/payments':lambda:self.plan_payment_settings_post(u,d),'/plans/buy':lambda:self.plans_buy(u,d),'/console':lambda:self.console_post(u,d),'/referrals/redeem':lambda:self.referral_redeem(u,d),'/ad/complete':lambda:self.ad_complete(u,d),'/tools/payloads':lambda:self.payloads_page(u,d),'/tools/speedtest/run':lambda:self.speedtest_run(u),'/tools/run':lambda:self.tool_run(u,d),'/tools/archive-upload':lambda:self.archive_upload(u,d),'/tools/backup/restore':lambda:self.backup_restore(u,d)}
  if p in routes:return routes[p]()
  return self.send(404,body=tpl('404.html',u,'Página no encontrada'))
 def tool_page(self,u,slug,title,admin_only=False):
  if not u:return self.redirect('/login')
  if admin_only and u.get('role')!='admin':return self.send(403,body=tpl('message.html',u,'Acceso denegado',MESSAGE='<div class="notice bad">Esta herramienta es solo para administradores.</div>'))
  if slug=='detalles-vps':
   cmds=[['bash','-lc','printf "Sistema: "; . /etc/os-release; echo "$PRETTY_NAME"; printf "Kernel: "; uname -r; printf "Arquitectura: "; uname -m; printf "Hostname: "; hostname; printf "CPU: "; grep -m1 "model name" /proc/cpuinfo | cut -d: -f2; printf "Núcleos: "; nproc; free -h; df -h /; uptime -p']]
   try:out=subprocess.run(cmds[0],capture_output=True,text=True,timeout=10).stdout
   except Exception as e:out=str(e)
   body='<div class="hero"><h1><i class="fa-solid fa-server"></i> Detalles del VPS</h1><p>Información actual del servidor.</p></div><div class="card"><pre class="terminal">'+html_escape(out or 'No se pudo obtener información.')+'</pre><a class="btn" href="'+PREFIX+'/tools/detalles-vps">Actualizar</a></div>'
   return self.send(200,body=page(title,body,u))
  if slug=='speedtest':
   has=shutil.which('speedtest') or shutil.which('speedtest-cli')
   msg='El comando de prueba está instalado.' if has else 'No se encontró speedtest ni speedtest-cli en el VPS.'
   body='<div class="hero"><h1><i class="fa-solid fa-gauge-high"></i> Speedtest</h1><p>Comprueba la velocidad de conexión del VPS.</p></div><div class="card"><p>'+html_escape(msg)+'</p>'+(('<form method="post" action="'+PREFIX+'/tools/speedtest/run"><button class="btn primary">Ejecutar prueba</button></form>') if has else '')+'</div>'
   return self.send(200,body=page(title,body,u))
  if slug=='block-torrent':
   body='<div class="hero"><h1><i class="fa-solid fa-ban"></i> Block Torrent</h1><p>Aplica o retira reglas aisladas de BitTorrent sin vaciar todas las reglas del firewall.</p></div><div class="card"><div class="notice">Requiere permisos de administrador del VPS. Se modificará únicamente la cadena KEVINTECH_TORRENT.</div><form method="post" action="'+PREFIX+'/tools/run"><button class="btn primary" name="tool_action" value="torrent_block">Bloquear BitTorrent</button><button class="btn danger" name="tool_action" value="torrent_unblock" data-confirm="¿Retirar las reglas BitTorrent de KevinTech?">Desbloquear BitTorrent</button></form></div>'
   return self.send(200,body=page(title,body,u))
  if slug=='block-ads':
   body='<div class="hero"><h1><i class="fa-solid fa-shield-halved"></i> Block Ads</h1><p>Administra el bloque de dominios publicitarios del archivo hosts.</p></div><div class="card"><p>Se conserva una copia de seguridad y solo se quita el bloque marcado por KevinTech.</p><form method="post" action="'+PREFIX+'/tools/run"><button class="btn primary" name="tool_action" value="ads_block">Bloquear dominios de anuncios</button><button class="btn danger" name="tool_action" value="ads_unblock" data-confirm="¿Eliminar solamente el bloque de anuncios de KevinTech?">Desbloquear anuncios</button></form></div>'
   return self.send(200,body=page(title,body,u))
  if slug=='archivo-online':
   up=DATA/'uploads';up.mkdir(parents=True,exist_ok=True);files=[]
   for f in sorted(up.iterdir(),key=lambda x:x.stat().st_mtime,reverse=True)[:100]:
    if f.is_file():files.append('<tr><td>'+html_escape(f.name)+'</td><td>'+str(round(f.stat().st_size/1024,1))+' KB</td><td><a class="btn" href="'+PREFIX+'/tools/archive-download?name='+quote(f.name)+'">Descargar</a> <form class="inline" method="post" action="'+PREFIX+'/tools/run"><input type="hidden" name="tool_action" value="archive_share"><input type="hidden" name="name" value="'+html_escape(f.name)+'"><button class="btn" data-confirm="El archivo se enviará a un servicio externo. No compartas información sensible. ¿Continuar?">Compartir externamente</button></form></td></tr>')
   body='<div class="hero"><h1><i class="fa-solid fa-folder-open"></i> Archivo Online</h1><p>Sube archivos desde el navegador y administra los archivos guardados.</p></div><div class="card"><form method="post" enctype="multipart/form-data" action="'+PREFIX+'/tools/archive-upload"><label>Seleccionar archivo (máximo 20 MB)</label><input class="input" type="file" name="upload" required><button class="btn primary">Subir archivo</button></form><h3>Archivos guardados</h3><div class="table-wrap"><table class="table"><thead><tr><th>Archivo</th><th>Tamaño</th><th>Acción</th></tr></thead><tbody>'+(''.join(files) or '<tr><td colspan="3">Todavía no hay archivos.</td></tr>')+'</tbody></table></div></div>'
   return self.send(200,body=page(title,body,u))
  if slug=='scanner':
   body='<div class="hero"><h1><i class="fa-solid fa-magnifying-glass"></i> Scanner</h1><p>Comprobaciones pasivas de DNS y disponibilidad HTTP.</p></div><div class="card"><div class="notice">Utiliza solo dominios que poseas o para los que tengas autorización. Esta interfaz no instala herramientas ni ejecuta escaneos intrusivos.</div><form method="post" action="'+PREFIX+'/tools/run"><input type="hidden" name="tool_action" value="scanner"><label>Dominio autorizado</label><input class="input" name="domain" placeholder="ejemplo.com" pattern="[A-Za-z0-9.-]+" required><button class="btn primary">Comprobar subdominios y HTTP</button></form></div>'
   return self.send(200,body=page(title,body,u))
  body='<div class="hero"><h1><i class="fa-solid fa-screwdriver-wrench"></i> '+html_escape(title)+'</h1><p>Herramienta web.</p></div><div class="card"><p>Esta herramienta no ejecuta scripts interactivos de terminal desde una visita al navegador.</p></div>'
  return self.send(200,body=page(title,body,u))
 def tool_run(self,u,d):
  if not u:return self.redirect('/login')
  action=self.val(d,'tool_action');admin_actions={'torrent_block','torrent_unblock','ads_block','ads_unblock','archive_share'}
  if action in admin_actions and u.get('role')!='admin':return self.send(403,body='403 - Solo administrador')
  out='';rc=0
  try:
   if action in ('torrent_block','torrent_unblock'):
    if not shutil.which('iptables'):raise RuntimeError('No se encontró iptables.')
    def ipt(args,check=False):
     return subprocess.run(['iptables']+args,capture_output=True,text=True,timeout=10).returncode
    if action=='torrent_block':
     ipt(['-N','KEVINTECH_TORRENT']);ipt(['-F','KEVINTECH_TORRENT'])
     for args in (['-p','tcp','--dport','6881:6999','-j','DROP'],['-p','udp','--dport','6881:6999','-j','DROP'],['-m','string','--algo','bm','--string','BitTorrent','-j','DROP'],['-m','string','--algo','bm','--string','peer_id=','-j','DROP']):
      ipt(['-A','KEVINTECH_TORRENT']+args)
     for chain in ('INPUT','OUTPUT'):
      if ipt(['-C',chain,'-j','KEVINTECH_TORRENT'])!=0:ipt(['-I',chain,'-j','KEVINTECH_TORRENT'])
     out='Reglas de BitTorrent activadas en la cadena aislada KEVINTECH_TORRENT.'
    else:
     for chain in ('INPUT','OUTPUT'):
      while ipt(['-C',chain,'-j','KEVINTECH_TORRENT'])==0:ipt(['-D',chain,'-j','KEVINTECH_TORRENT'])
     ipt(['-F','KEVINTECH_TORRENT']);ipt(['-X','KEVINTECH_TORRENT']);out='Reglas de KevinTech retiradas. No se vació el firewall completo.'
   elif action in ('ads_block','ads_unblock'):
    hosts=Path('/etc/hosts');marker='# KEVINTECH BLOCK ADS BEGIN';end='# KEVINTECH BLOCK ADS END';text=hosts.read_text(errors='replace')
    if action=='ads_block':
     if marker not in text:
      bak=Path('/etc/hosts.kevintech.bak')
      if not bak.exists():shutil.copy2(hosts,bak)
      block='\n'+marker+'\n'+'\n'.join('0.0.0.0 '+x for x in ['ads.google.com','adservice.google.com','pagead2.googlesyndication.com','googleads.g.doubleclick.net','doubleclick.net','ad.doubleclick.net','ads.yahoo.com','ads.facebook.com','app-measurement.com','analytics.google.com'])+'\n'+end+'\n'
      hosts.write_text(text.rstrip()+block)
     out='Bloqueo de anuncios aplicado.'
    else:
     if marker in text and end in text:text=text[:text.index(marker)]+text[text.index(end)+len(end):];hosts.write_text(text)
     out='Bloque de KevinTech retirado; las demás entradas de hosts se conservaron.'
   elif action=='scanner':
    domain=self.val(d,'domain').lower().strip().rstrip('.')
    if len(domain)>253 or not re.fullmatch(r'(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}',domain):raise ValueError('Dominio no válido.')
    found=[];subdomains=set()
    assetfinder=shutil.which('assetfinder');httpxbin=shutil.which('httpx')
    if assetfinder:
     proc=subprocess.run([assetfinder,'--subs-only',domain],capture_output=True,text=True,timeout=90)
     if proc.returncode==0:subdomains.update(x.strip().lower() for x in proc.stdout.splitlines() if x.strip().endswith(domain))
    for sub in ('','www','mail','api','vpn','cdn','webmail','panel','ftp'):
     host=(sub+'.' if sub else '')+domain
     try:
      infos=socket.getaddrinfo(host,None);ips=sorted({x[4][0] for x in infos});found.append(host+' -> '+', '.join(ips));subdomains.add(host)
     except Exception:pass
    if httpxbin and subdomains:
     try:
      proc=subprocess.run([httpxbin,'-silent','-status-code','-ip','-tech-detect','-title'],input='\n'.join(sorted(subdomains))+'\n',capture_output=True,text=True,timeout=120)
      if proc.stdout.strip():found.append('\nResultados HTTP / tecnologías:\n'+proc.stdout.strip())
      elif proc.stderr.strip():found.append('httpx: '+proc.stderr.strip()[:250])
     except Exception as e:found.append('httpx no pudo completar la prueba: '+str(e)[:150])
    else:
     try:
      req=urllib.request.Request('https://'+domain,method='HEAD',headers={'User-Agent':'KevinTech-Web-Scanner/1.0'});resp=urllib.request.urlopen(req,timeout=7);found.append('HTTPS '+domain+' -> HTTP '+str(resp.status));resp.close()
     except Exception as e:found.append('HTTPS '+domain+' -> '+str(e)[:180])
    out='\n'.join(found) or 'No se encontraron registros DNS en los nombres probados. Para el análisis ampliado instala assetfinder y ProjectDiscovery httpx en el VPS.'
    scan_dir=DATA/'scanner';scan_dir.mkdir(parents=True,exist_ok=True);(scan_dir/(domain.replace('.','_')+'_'+datetime.now().strftime('%Y%m%d%H%M%S')+'.txt')).write_text(out,encoding='utf8')
   elif action=='archive_share':
    if u.get('role')!='admin':raise PermissionError('Solo administrador')
    name=Path(self.val(d,'name')).name;f=DATA/'uploads'/name
    if not f.is_file():raise ValueError('Archivo no encontrado.')
    proc=subprocess.run(['curl','-fsS','--max-time','90','--upload-file',str(f),'https://transfer.sh/'+quote(name)],capture_output=True,text=True,timeout=95)
    if proc.returncode:raise RuntimeError(proc.stderr or 'No se pudo subir a transfer.sh.')
    out='Archivo compartido en servicio externo. Enlace: '+proc.stdout.strip()
   else:raise ValueError('Acción desconocida.')
  except Exception as e:rc=1;out=str(e)
  body='<div class="hero"><h1><i class="fa-solid fa-terminal"></i> Resultado de herramienta</h1></div><div class="card"><div class="notice '+('bad' if rc else 'oktxt')+'">'+('Error: ' if rc else 'Resultado: ') + html_escape(out).replace('\\n','<br>').replace('\n','<br>')+'</div><a class="btn primary" href="'+PREFIX+('/tools/scanner' if action=='scanner' else '/tools/'+('block-torrent' if action.startswith('torrent') else 'block-ads' if action.startswith('ads') else 'archivo-online'))+'">Volver</a></div>'
  return self.send(200 if not rc else 400,body=page('Resultado',body,u))
 def archive_upload(self,u,d):
  if not u:return self.redirect('/login')
  if u.get('role')!='admin':return self.send(403,body='403 - Solo administrador')
  payload=d.get('_file_upload',b'');name=Path(d.get('_filename_upload','archivo.bin')).name
  if not payload:return self.send(400,body=tpl('message.html',u,'Archivo',MESSAGE='<div class="notice bad">No se recibió ningún archivo.</div>'))
  if len(payload)>20*1024*1024:return self.send(413,body='Archivo demasiado grande (máximo 20 MB).')
  if not name or name in ('.','..'):name='archivo.bin'
  clean=re.sub(r'[^A-Za-z0-9._ -]','_',name)[:120];folder=DATA/'uploads';folder.mkdir(parents=True,exist_ok=True);target=folder/(secrets.token_hex(4)+'_'+clean);target.write_bytes(payload);os.chmod(target,0o600)
  return self.send(200,body=tpl('message.html',u,'Archivo cargado',MESSAGE='<div class="notice oktxt">Archivo guardado de forma privada en el VPS.</div><a class="btn primary" href="'+PREFIX+'/tools/archivo-online">Ver archivos</a>'))
 def archive_download(self,u):
  if not u:return self.redirect('/login')
  if u.get('role')!='admin':return self.send(403,body='403 - Solo administrador')
  name=Path(parse_qs(urlparse(self.path).query).get('name',[''])[0]).name;f=DATA/'uploads'/name
  if not f.is_file():return self.send(404,body='Archivo no encontrado.')
  b=f.read_bytes();self.send_response(200);self.send_header('Content-Type','application/octet-stream');self.send_header('Content-Disposition','attachment; filename="'+name.replace('"','')+'"');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)
 def backup_page(self,u):
  if not u or u.get('role')!='admin':return self.send(403,body='403 - Solo administrador')
  body='<div class="hero"><h1><i class="fa-solid fa-database"></i> Respaldar y restaurar</h1><p>La base de datos del panel es SQLite, una base de datos SQL. Puedes descargar el respaldo y restaurarlo aquí.</p></div><div class="grid"><div class="card"><h2>Crear respaldo</h2><p>Incluye base de datos SQLite, exportación SQL y configuración del panel.</p><a class="btn primary" href="'+PREFIX+'/tools/backup/download"><i class="fa-solid fa-download"></i> Descargar backup ZIP</a></div><div class="card"><h2>Restaurar respaldo</h2><div class="notice bad">Restaurar reemplaza la base de datos y configuración actuales. Descarga un backup antes de continuar.</div><form method="post" enctype="multipart/form-data" action="'+PREFIX+'/tools/backup/restore"><label>Archivo ZIP de respaldo KevinTech</label><input class="input" type="file" name="backup" accept=".zip,application/zip" required><label><input type="checkbox" name="confirm_restore" value="yes" required> Entiendo que se reemplazarán los datos actuales</label><button class="btn danger" data-confirm="¿Restaurar este backup y reemplazar los datos actuales?">Restaurar backup</button></form></div></div>'
  return self.send(200,body=page('Backup y restauración',body,u))
 def backup_download(self,u):
  if not u or u.get('role')!='admin':return self.send(403,body='403 - Solo administrador')
  folder=DATA;folder.mkdir(parents=True,exist_ok=True);tmp=folder/('backup_'+secrets.token_hex(4)+'.sqlite3');src=db();dst=sqlite3.connect(tmp);src.backup(dst);dst.execute('PRAGMA journal_mode=DELETE');dst.close();src.close()
  con=sqlite3.connect(tmp);sql='\n'.join(con.iterdump());con.close();archive=io.BytesIO();conf=CONFIG.read_bytes() if CONFIG.exists() else b'{}'
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
   z.write(tmp,'web.sqlite3');z.writestr('database.sql',sql);z.writestr('config.json',conf);z.writestr('README.txt','Backup KevinTech Web. Contiene información sensible. Mantener privado. Restaurar desde Herramientas > Backup.')
  tmp.unlink(missing_ok=True);b=archive.getvalue();self.send_response(200);self.send_header('Content-Type','application/zip');self.send_header('Content-Disposition','attachment; filename="kevintech-backup-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'.zip"');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)
 def backup_restore(self,u,d):
  if not u or u.get('role')!='admin':return self.send(403,body='403 - Solo administrador')
  if self.val(d,'confirm_restore')!='yes':return self.send(400,body='Debes confirmar la restauración.')
  payload=d.get('_file_backup',b'')
  if not payload or len(payload)>25*1024*1024:return self.send(400,body='ZIP de respaldo inválido o demasiado grande.')
  try:
   with zipfile.ZipFile(io.BytesIO(payload)) as z:
    names=set(z.namelist())
    if not {'web.sqlite3','config.json','database.sql'}.issubset(names):raise ValueError('El ZIP no parece un backup KevinTech completo.')
    if any(info.file_size>100*1024*1024 for info in z.infolist()):raise ValueError('El backup contiene un archivo demasiado grande.')
    dbbytes=z.read('web.sqlite3');confbytes=z.read('config.json')
   test=sqlite3.connect(':memory:');test.deserialize(dbbytes);check=test.execute('PRAGMA integrity_check').fetchone()[0];test.close()
   if check!='ok':raise ValueError('La base de datos no pasó la comprobación de integridad.')
   conf=json.loads(confbytes.decode('utf8'))
   if not isinstance(conf,dict):raise ValueError('La configuración no es válida.')
   DATA.mkdir(parents=True,exist_ok=True);(DATA/'web.sqlite3.restore').write_bytes(dbbytes);(DATA/'config.json.restore').write_bytes(confbytes);os.chmod(DATA/'web.sqlite3.restore',0o600);os.chmod(DATA/'config.json.restore',0o600)
   # Remove WAL files before atomically replacing the DB.
   for suffix in ('-wal','-shm'):(DATA/('web.sqlite3'+suffix)).unlink(missing_ok=True)
   os.replace(DATA/'web.sqlite3.restore',DB);os.replace(DATA/'config.json.restore',CONFIG)
   return self.send(200,body=tpl('message.html',u,'Respaldo restaurado',MESSAGE='<div class="notice oktxt">Respaldo validado y restaurado. La sesión puede pedirte iniciar sesión otra vez.</div><a class="btn primary" href="'+PREFIX+'/login">Continuar</a>'))
  except Exception as e:
   log('backup_restore_error '+repr(e))
   (DATA/'web.sqlite3.restore').unlink(missing_ok=True);(DATA/'config.json.restore').unlink(missing_ok=True)
   return self.send(400,body=tpl('message.html',u,'Error al restaurar',MESSAGE='<div class="notice bad">No se restauró el respaldo: '+html_escape(str(e))+'</div><a class="btn" href="'+PREFIX+'/tools/backup">Volver</a>'))
 def payloads_page(self,u,d=None):
  if not u:return self.redirect('/login')
  kind=self.val(d,'kind','http_get') if d else 'http_get'
  host=self.val(d,'host') if d else '';route=self.val(d,'route','/') if d else '/';data=self.val(d,'data') if d else '';port=self.val(d,'port') if d else '';payload='';error=''
  if d:
   if kind not in ('http_get','http_post','websocket','tcp','udp','custom'):kind='http_get'
   if kind!='custom' and not host:error='Escribe el host.'
   elif kind in ('tcp','udp') and (not port.isdigit() or not 1<=int(port)<=65535):error='El puerto debe estar entre 1 y 65535.'
   else:
    route=route or '/'
    if not route.startswith('/'):route='/'+route
    if kind=='http_get':payload=f'GET {route} HTTP/1.1\nHost: {host}\nUser-Agent: KevinTech\nConnection: keep-alive'
    elif kind=='http_post':payload=f'POST {route} HTTP/1.1\nHost: {host}\nUser-Agent: KevinTech\nContent-Type: application/x-www-form-urlencoded\nContent-Length: {len(data)}\nConnection: keep-alive\n\n{data}'
    elif kind=='websocket':payload=f'GET {route} HTTP/1.1\nHost: {host}\nUpgrade: websocket\nConnection: Upgrade\nSec-WebSocket-Version: 13\nUser-Agent: KevinTech'
    elif kind=='tcp':payload=f'TCP://{host}:{port}\n{data}'
    elif kind=='udp':payload=f'UDP://{host}:{port}\n{data}'
    else:payload=data
    if kind=='custom' and not payload:error='Escribe el payload personalizado.'
  options=''.join('<option value="'+v+'" '+('selected' if kind==v else '')+'>'+label+'</option>' for v,label in [('http_get','HTTP GET'),('http_post','HTTP POST'),('websocket','WebSocket'),('tcp','TCP'),('udp','UDP'),('custom','Personalizado')])
  body='<div class="hero"><h1><i class="fa-solid fa-bolt"></i> Generador de Payloads</h1><p>Genera plantillas HTTP, WebSocket, TCP, UDP o personalizadas.</p></div><div class="card"><form method="post" action="'+PREFIX+'/tools/payloads"><label>Tipo de payload</label><select class="input" name="kind">'+options+'</select><label>Host / dominio</label><input class="input" name="host" value="'+html_escape(host)+'" placeholder="ejemplo.com"><label>Ruta HTTP</label><input class="input" name="route" value="'+html_escape(route)+'" placeholder="/"><label>Puerto (para TCP/UDP)</label><input class="input" name="port" type="number" min="1" max="65535" value="'+html_escape(port)+'" placeholder="443"><label>Datos POST / TCP / UDP / payload personalizado</label><textarea class="input" name="data" rows="4" placeholder="Contenido opcional">'+html_escape(data)+'</textarea><button class="btn primary">Generar payload</button></form>'
  if error:body+='<div class="notice bad">'+html_escape(error)+'</div>'
  if payload:body+='<h3>Resultado</h3><pre class="copybox">'+html_escape(payload)+'</pre><button type="button" class="btn" onclick="navigator.clipboard.writeText(document.querySelector(&quot;.copybox&quot;).textContent)">Copiar payload</button>'
  body+='</div>'
  return self.send(200,body=page('Generador de Payloads',body,u))
 def speedtest_run(self,u):
  if not u:return self.redirect('/login')
  command=shutil.which('speedtest') or shutil.which('speedtest-cli')
  if not command:return self.send(404,body=tpl('message.html',u,'Speedtest no instalado',MESSAGE='<div class="notice bad">No se encontró speedtest ni speedtest-cli.</div>'))
  rc,out=shell(shlex.quote(command)+' --accept-license --accept-gdpr' if command.endswith('/speedtest') else shlex.quote(command),90)
  body='<div class="hero"><h1><i class="fa-solid fa-gauge-high"></i> Resultado de Speedtest</h1></div><div class="card"><p>Resultado: '+('Correcto' if rc==0 else 'Código '+str(rc))+'</p><pre class="terminal">'+html_escape(out or 'Sin salida')+'</pre><a class="btn" href="'+PREFIX+'/tools/speedtest">Volver</a></div>'
  return self.send(200,body=page('Resultado Speedtest',body,u))
 def public_index(self,u):
  st=site_settings();title=html_escape(st.get('site_title','KevinTech Multi Script'));desc=html_escape(st.get('site_description','Panel web para administrar tu VPS y tus cuentas.'))
  body='<section class="public-hero"><div class="public-badge"><i class="fa-solid fa-shield-halved"></i> Plataforma de administración</div><h1>'+title+'</h1><p>'+desc+'</p><div class="public-actions"><a class="btn primary" href="'+PREFIX+'/login"><i class="fa-solid fa-right-to-bracket"></i> Ingresar</a><a class="btn" href="'+PREFIX+'/register"><i class="fa-solid fa-user-plus"></i> Registrarse</a></div></section><section class="grid public-features"><article class="card"><i class="fa-solid fa-server"></i><h2>Gestión centralizada</h2><p class="muted">Administra cuentas y consulta los servicios de tu servidor.</p></article><article class="card"><i class="fa-solid fa-user-shield"></i><h2>Acceso seguro</h2><p class="muted">Funciones privadas protegidas por inicio de sesión.</p></article><article class="card"><i class="fa-solid fa-headset"></i><h2>Soporte y planes</h2><p class="muted">Consulta los planes disponibles después de ingresar.</p></article></section>'
  return self.send(200,body=page('Inicio',body,u))
 def login_page(self,msg=''):return self.send(200,body=tpl('login.html',None,'Ingreso',MSG=msg,SITE_TITLE=html_escape(site_settings().get('site_title','KevinTech Multi Script'))))
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
   renew_button='<form class="inline" method="post" action="%s/account/renew"><input type="hidden" name="id" value="%s"><button class="btn primary">♻️ Renovar</button></form>'%(PREFIX,a['id'])
   delete_button='<form class="inline" method="post" action="%s/account/delete"><input type="hidden" name="id" value="%s"><button class="btn danger">Eliminar</button></form>'%(PREFIX,a['id'])
   cards_list.append('<div class="card account-card"><div class="account-head"><h3>👤 %s</h3><span class="tag">%s</span></div><p class="muted">Propietario: %s · Expira: %s</p><p>Online: <b class="oktxt">%s</b> · Límite: <b>%s</b> IP</p><a class="btn" href="%s/account?id=%s">Ver cuenta</a>%s%s</div>'%(html_escape(a['username']),html_escape(a['type']).upper(),html_escape(a['owner']),html_escape(a['expiration'] or '—'),len(account_online(a['username'])),a['ip_limit'],PREFIX,a['id'],renew_button,delete_button))
  cards=''.join(cards_list)
  c.close();st=site_settings();modal=''
  if u['role']=='user':
   expiring=[]
   for a in rows:
    try:
     remaining=(datetime.strptime(a['expiration'],'%Y-%m-%d').date()-datetime.now().date()).days
     if 0 <= remaining <= 3: expiring.append((a,remaining))
    except: pass
   if expiring:
    alerts=''.join('<div class="notice bad"><b>⚠️ La cuenta '+html_escape(a['username'])+' vence en '+str(days)+' día(s).</b><p>Necesitas 4 puntos para renovar esta cuenta.</p><form class="inline" method="post" action="'+PREFIX+'/account/renew"><input type="hidden" name="id" value="'+str(a['id'])+'"><button class="btn primary"><i class="fa-solid fa-rotate"></i> Renovar cuenta</button></form></div>' for a,days in expiring)
    modal='<div class="expiry-modal" id="expiryModal"><div class="expiry-modal-card"><button type="button" class="modal-x" onclick="document.getElementById(\'expiryModal\').remove()">×</button><h2>⚠️ Cuenta próxima a vencer</h2>'+alerts+'<button type="button" class="btn" onclick="document.getElementById(\'expiryModal\').remove()">Cerrar</button></div></div>'
  if u['role']=='user':
   nc=db();decision=nc.execute("SELECT * FROM notifications WHERE user_id=? AND kind IN ('plan_approved','plan_rejected') AND is_read=0 ORDER BY id DESC LIMIT 1",(u['id'],)).fetchone()
   if decision:
    nc.execute('UPDATE notifications SET is_read=1 WHERE id=?',(decision['id'],));nc.commit()
    ok=decision['kind']=='plan_approved';modal+='<div class="expiry-modal" id="planDecisionModal"><div class="expiry-modal-card"><h2>'+('✅ Solicitud aceptada' if ok else '❌ Solicitud rechazada')+'</h2><p>'+html_escape(decision['message'])+'</p><button class="btn primary" onclick="this.parentElement.parentElement.remove()">Entendido</button></div></div>'
   nc.close()
  return self.send(200,body=tpl('dashboard.html',u,'Inicio',COUNT=len(rows),ONLINE=len(all_online()),POINTS=(u.get('referral_points',0) if u['role']=='user' else int(cfg().get('admin_referral_points',0)) ),ACCOUNTS=modal+(cards or '<div class="card">No hay cuentas para mostrar.</div>'),SITE_TITLE=html_escape(st.get('home_title') or st['site_title']),SITE_DESC=html_escape(st.get('home_description') or st['site_description'])) )
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
 def user_language(self,u):
  if not u:return 'es'
  return site_settings().get('language_'+str(u.get('id',0)),'es')
 def profile(self,u):
  if not u:return self.redirect('/login')
  if u['role']=='admin':
   c=cfg();body=tpl('profile.html',u,'Perfil',NAME='Administrador',USERNAME=html_escape(c.get('admin_username','admin')),CREATED='—',POINTS=int(c.get('admin_referral_points',0)),CODE=html_escape(c.get('admin_referral_code','')),ADMIN=True,LANG_ES='selected' if self.user_language(u)=='es' else '',LANG_EN='selected' if self.user_language(u)=='en' else '',LANG_PT='selected' if self.user_language(u)=='pt' else '')
  else:
   body=tpl('profile.html',u,'Perfil',NAME=html_escape(u['name']),USERNAME=html_escape(u['username']),CREATED=html_escape(u['created_at']),POINTS=u['referral_points'],CODE=html_escape(u['referral_code']),ADMIN=False,LANG_ES='selected' if self.user_language(u)=='es' else '',LANG_EN='selected' if self.user_language(u)=='en' else '',LANG_PT='selected' if self.user_language(u)=='pt' else '')
  return self.send(200,body=body)
 def profile_post(self,u,d):
  if not u:return self.redirect('/login')
  lang=self.val(d,'language','es')
  if lang not in ('es','en','pt'):lang='es'
  save_settings({'language_'+str(u.get('id',0)):lang})
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
  return self.send(200,body=tpl('account_create.html',u,'Crear cuenta',DAYS=days,LIMIT=limit,OWNERS='',ADMIN=(u['role']=='admin')))
 def account_create(self,u,d):
  if not u:return self.send(403,body='403')
  if u['role']!='admin':
   st=site_settings();con=db();owned=con.execute('SELECT COUNT(*) n FROM accounts WHERE user_id=?',(u['id'],)).fetchone()['n'];con.close()
   if owned>=max(0,int(st.get('quota_user_accounts',2))):return self.send(403,body=tpl('message.html',u,'Cuota alcanzada',MESSAGE='<div class="notice bad">Has alcanzado el máximo de cuentas permitido por el administrador.</div>'))
   if int(u.get('referral_points',0))<3:return self.send(403,body=tpl('message.html',u,'Puntos insuficientes',MESSAGE='<div class="notice bad">Necesitas 3 puntos de referidos por cada cuenta. Comparte tu enlace para ganar puntos.</div><a class="btn" href="%s/referrals">Ir a referidos</a>'%PREFIX))
  # A configured ad gate is mandatory before account creation.
  conf=cfg();ad_count=int(conf.get('ads',{}).get('create',0) or 0)
  if u['role']!='admin' and conf.get('ads_enabled') and ad_count>0:
   token=secrets.token_urlsafe(32);payload={k:v[0] for k,v in d.items() if k not in ('ad_token',)}
   c=db();c.execute('INSERT INTO ad_tokens(token,user_id,action,account_id,expires,completed,payload) VALUES(?,?,?,?,?,?,?)',(token,int(u['id']), 'create',None,now()+TOKEN_TTL,0,json.dumps(payload)));c.commit();c.close()
   return self.redirect('/ad/watch?token='+token)
  return self.create_account_now(u,d)
 def create_account_now(self,u,d):
  st=site_settings();days=int(st['quota_admin_days'] if u['role']=='admin' else st['quota_user_days']);limit=int(st['quota_admin_limit'] if u['role']=='admin' else st['quota_user_limit']);typ=self.val(d,'type','ssh').strip().lower().replace(' ','').replace('/','');typ={'vmess':'v2ray','v2rayvmess':'v2ray','ssh':'ssh'}.get(typ,typ);user=self.val(d,'username').lower();pw=self.val(d,'password')
  if u['role']!='admin':
   con=db();owned=con.execute('SELECT COUNT(*) n FROM accounts WHERE user_id=?',(u['id'],)).fetchone()['n'];con.close()
   max_accounts=max(0,int(st.get('quota_user_accounts',2)))
   if owned>=max_accounts:return self.send(403,body=tpl('message.html',u,'Cuota alcanzada',MESSAGE='<div class="notice bad">Has alcanzado el máximo de cuentas permitido por el administrador.</div>'))
   if int(u.get('referral_points',0))<3:return self.send(403,body=tpl('message.html',u,'Puntos insuficientes',MESSAGE='<div class="notice bad">Necesitas 3 puntos de referidos por cada cuenta. Comparte tu enlace para ganar puntos.</div><a class="btn" href="%s/referrals">Ir a referidos</a>'%PREFIX))
  owner_id=u['id'] if u['role']=='user' else 0
  if u['role']=='admin':
   c=db();first=c.execute('SELECT id FROM users WHERE active=1 ORDER BY id LIMIT 1').fetchone();c.close()
   if not first:return self.send(400,body=tpl('message.html',u,'Crear cuenta',MESSAGE='<div class="notice bad">No hay usuarios web registrados para asignar esta cuenta. Crea un usuario web primero.</div>'))
   owner_id=first['id']
  if typ=='ssh':ok,msg=create_ssh_account(user,pw,days,limit);credential=pw;expiration=msg
  elif typ in ('v2ray','vmess'):ok,msg,credential=create_v2ray_account(user,days);expiration=msg
  else:return self.send(400,body='Tipo de cuenta inválido')
  if not ok:return self.send(400,body=tpl('message.html',u,'Error',MESSAGE='<div class="notice bad">%s</div>'%html_escape(msg)))
  c=db();c.execute('INSERT INTO accounts(user_id,username,type,credential,expiration,ip_limit,created_at) VALUES(?,?,?,?,?,?,?)',(owner_id,user,'v2ray' if typ!='ssh' else 'ssh',crypt_credential(credential),expiration,limit,datetime.now().isoformat(timespec='seconds')));aid=c.execute('SELECT last_insert_rowid()').fetchone()[0]
  if u['role']!='admin':c.execute('UPDATE users SET referral_points=MAX(0,referral_points-3) WHERE id=?',(u['id'],))
  c.commit();c.close();return self.redirect('/account?id=%d'%aid)
 def ad_watch(self,u):
  if not u:return self.redirect('/login')
  token=parse_qs(urlparse(self.path).query).get('token',[''])[0]
  c=db();row=c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND expires>? AND completed=0',(token,int(u['id']),now())).fetchone();c.close()
  if not row:return self.send(400,body=tpl('message.html',u,'Publicidad',MESSAGE='<div class="notice bad">El paso de publicidad expiró. Vuelve a intentar la operación.</div>'))
  conf=cfg();count=int(conf.get('ads',{}).get(row['action'],0) or 0);zone=html_escape(conf.get('monetag_zone','11217882'))
  return self.send(200,body=tpl('ad_watch.html',u,'Publicidad',COUNT=count,ACTION={'create':'crear la cuenta','delete':'eliminar la cuenta','renew':'renovar la cuenta'}.get(row['action'],'continuar'),ZONE=zone,TOKEN=html_escape(token),COMPLETE=PREFIX+'/ad/complete'))
 def ad_complete(self,u,d):
  if not u:return self.send(403,body='403')
  token=self.val(d,'token');c=db();row=c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND expires>? AND completed=0',(token,int(u['id']),now())).fetchone()
  if not row:c.close();return self.send(400,body=tpl('message.html',u,'Publicidad',MESSAGE='<div class="notice bad">El token de publicidad es inválido o expiró.</div>'))
  c.execute('UPDATE ad_tokens SET completed=1 WHERE token=?',(token,));c.commit();c.close()
  try:payload=json.loads(row['payload'])
  except:payload={}
  if row['action']=='create':return self.create_account_now(u,payload)
  if row['action']=='delete':return self.delete_account_now(u,payload)
  if row['action']=='renew':return self.renew_account_now(u,payload)
  return self.send(400,body='Acción publicitaria inválida.')
 def account_delete(self,u,d):
  if not u:return self.send(403,body='403')
  try:aid=int(self.val(d,'id'))
  except:return self.send(400,body='ID inválido')
  if u['role']!='admin':
   conf=cfg();count=int(conf.get('ads',{}).get('delete',0) or 0)
   if conf.get('ads_enabled') and count>0:return self.start_ad_action(u,'delete',aid,{'id':str(aid)})
  return self.delete_account_now(u,{'id':str(aid)})
 def delete_account_now(self,u,d):
  try:aid=int(self.val(d,'id'))
  except:return self.send(400,body='ID inválido')
  c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
  if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body='Cuenta no encontrada')
  ok=delete_v2ray(a['username']) if a['type']=='v2ray' else delete_ssh(a['username'])[0];c.execute('DELETE FROM accounts WHERE id=?',(aid,));c.commit();c.close();return self.send(200,body=tpl('message.html',u,'Eliminar cuenta',MESSAGE='<div class="notice %s">%s</div><a class="btn" href="%s/dashboard">Volver</a>'%('oktxt' if ok else 'bad','Cuenta eliminada.' if ok else 'No se pudo eliminar completamente la cuenta.',PREFIX)))
 def account_renew(self,u,d):
  if not u:return self.send(403,body='403')
  try:aid=int(self.val(d,'id'))
  except:return self.send(400,body='ID inválido')
  c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone();c.close()
  if not a or (u['role']!='admin' and a['user_id']!=u['id']):return self.send(404,body='Cuenta no encontrada')
  if u['role']!='admin':
   st=site_settings();need=max(1,int(st.get('quota_renew_points',4)))
   if int(u.get('referral_points',0))<need:return self.send(403,body=tpl('message.html',u,'Puntos insuficientes',MESSAGE='<div class="notice bad">Necesitas '+str(need)+' puntos para renovar esta cuenta.</div><a class="btn" href="'+PREFIX+'/referrals">Ir a referidos</a>'))
   conf=cfg();count=int(conf.get('ads',{}).get('renew',0) or 0)
   if conf.get('ads_enabled') and count>0:return self.start_ad_action(u,'renew',aid,{'id':str(aid)})
  return self.renew_account_now(u,{'id':str(aid)})
 def renew_account_now(self,u,d):
  if not u:return self.send(403,body='403')
  try:aid=int(self.val(d,'id'))
  except:return self.send(400,body='ID inválido')
  st=site_settings();c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
  if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body='Cuenta no encontrada')
  days=int(st['quota_admin_days'] if u['role']=='admin' else st['quota_user_days']);ok,msg=renew_account(a,days)
  if ok:
   c.execute('UPDATE accounts SET expiration=? WHERE id=?',(msg,aid))
   if u['role']!='admin':c.execute('UPDATE users SET referral_points=MAX(0,referral_points-?) WHERE id=?',(max(1,int(st.get('quota_renew_points',4))),u['id']))
   c.commit()
  c.close();return self.send(200,body=tpl('message.html',u,'Renovar',MESSAGE='<div class="notice %s">%s</div><a class="btn" href="%s/account?id=%s">Volver</a>'%('oktxt' if ok else 'bad',html_escape(msg),PREFIX,aid)))
 def start_ad_action(self,u,action,aid,payload):
  conf=cfg();count=int(conf.get('ads',{}).get(action,0) or 0)
  if u['role']=='admin' or not conf.get('ads_enabled') or count<=0:return None
  token=secrets.token_urlsafe(32);c=db();c.execute('INSERT INTO ad_tokens(token,user_id,action,account_id,expires,completed,payload) VALUES(?,?,?,?,?,?,?)',(token,int(u['id']),action,aid,now()+TOKEN_TTL,0,json.dumps(payload)));c.commit();c.close();return self.redirect('/ad/watch?token='+token)
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
 def admin_renew_accounts(self,u):
  if not u or u['role']!='admin':return self.redirect('/login')
  c=db();rows=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id ORDER BY a.id DESC').fetchall();c.close()
  html=''.join('<tr><td>'+html_escape(x['username'])+'</td><td>'+html_escape(x['owner'])+'</td><td>'+html_escape(x['type'])+'</td><td>'+html_escape(x['expiration'] or '—')+'</td><td><form method="post" action="'+PREFIX+'/account/renew"><input type="hidden" name="id" value="'+str(x['id'])+'"><button class="btn primary">Renovar</button></form></td></tr>' for x in rows) or '<tr><td colspan="5">No hay cuentas.</td></tr>'
  return self.send(200,body=tpl('admin_renew.html',u,'Renovar cuentas',ROWS=html))
 def admin_settings_redirect(self,u):return self.redirect('/admin/settings/general' if u and u.get('role')=='admin' else '/profile')
 def admin_settings(self,u,section):
  if not u or u['role']!='admin':return self.redirect('/login')
  c=cfg();st=site_settings();
  if section=='ads':body=tpl('admin_settings_ads.html',u,'Ajuste de ads',ADS_CHECKED='checked' if c.get('ads_enabled') else '',ZONE=html_escape(c.get('monetag_zone','11217882')),CREATE=c.get('ads',{}).get('create',0),DELETE=c.get('ads',{}).get('delete',0),RENEW=c.get('ads',{}).get('renew',0))
  elif section=='quotas':body=tpl('admin_settings_quotas.html',u,'Cuotas',USER_DAYS=st['quota_user_days'],USER_LIMIT=st['quota_user_limit'],USER_ACCOUNTS=st.get('quota_user_accounts',2),ADMIN_DAYS=st['quota_admin_days'],ADMIN_LIMIT=st['quota_admin_limit'],RENEW_POINTS=st.get('quota_renew_points',4))
  else:body=tpl('admin_settings_general.html',u,'Ajuste general',TITLE=html_escape(st['site_title']),DESCRIPTION=html_escape(st['site_description']),CURRENCY=html_escape(st.get('currency_symbol','S/')),HOME_TITLE=html_escape(st.get('home_title','Inicio')),HOME_DESC=html_escape(st.get('home_description','')),PROTOCOLS_TITLE=html_escape(st.get('protocols_title','Protocolos')),PROTOCOLS_DESC=html_escape(st.get('protocols_description','')),ONLINE_TITLE=html_escape(st.get('online_title','Online')),ONLINE_DESC=html_escape(st.get('online_description','')),REFERRALS_TITLE=html_escape(st.get('referrals_title','Referidos')),REFERRALS_DESC=html_escape(st.get('referrals_description','')),ABOUT=html_escape(st['about_us']),PRIVACY=html_escape(st['privacy']),COOKIES=html_escape(st['cookies']),TERMS=html_escape(st['terms']),SOCIAL_FACEBOOK=html_escape(st.get('social_facebook','')),SOCIAL_INSTAGRAM=html_escape(st.get('social_instagram','')),SOCIAL_TIKTOK=html_escape(st.get('social_tiktok','')),SOCIAL_WHATSAPP=html_escape(st.get('social_whatsapp','')),CONTACT_EMAIL=html_escape(st.get('contact_email','')),CONTACT_PHONE=html_escape(st.get('contact_phone','')))
  return self.send(200,body=body)
 def admin_settings_post(self,u,d,section):
  if not u or u['role']!='admin':return self.send(403,body='403')
  if section=='ads':
   c=cfg();c['ads_enabled']='ads_enabled' in d;c['monetag_zone']=self.val(d,'monetag_zone','11217882')
   try:c['ads']={'create':max(0,min(20,int(self.val(d,'ad_create','0')))),'delete':max(0,min(20,int(self.val(d,'ad_delete','0')))),'renew':max(0,min(20,int(self.val(d,'ad_renew','0'))))}
   except:pass
   save_cfg(c);return self.redirect('/admin/settings/ads')
  if section=='quotas':
   try:vals={'quota_user_days':max(1,min(3650,int(self.val(d,'user_days')))),'quota_user_limit':max(0,min(100,int(self.val(d,'user_limit')))),'quota_user_accounts':max(0,min(100,int(self.val(d,'user_accounts','2')))),'quota_admin_days':max(1,min(3650,int(self.val(d,'admin_days')))),'quota_admin_limit':max(0,min(100,int(self.val(d,'admin_limit')))),'quota_renew_points':max(1,min(1000,int(self.val(d,'renew_points','4'))))}
   except:return self.send(400,body='Cuotas inválidas')
   save_settings(vals);return self.redirect('/admin/settings/quotas')
  symbol=self.val(d,'currency_symbol','S/')[:8] or 'S/';save_settings({'currency_symbol':symbol,'site_title':self.val(d,'site_title','KevinTech Multi Script'),'site_description':self.val(d,'site_description'),'home_title':self.val(d,'home_title','Inicio'),'home_description':self.val(d,'home_description'),'protocols_title':self.val(d,'protocols_title','Protocolos'),'protocols_description':self.val(d,'protocols_description'),'online_title':self.val(d,'online_title','Online'),'online_description':self.val(d,'online_description'),'referrals_title':self.val(d,'referrals_title','Referidos'),'referrals_description':self.val(d,'referrals_description'),'about_us':self.val(d,'about_us'),'privacy':self.val(d,'privacy'),'cookies':self.val(d,'cookies'),'terms':self.val(d,'terms'),'social_facebook':self.val(d,'social_facebook')[:500],'social_instagram':self.val(d,'social_instagram')[:500],'social_tiktok':self.val(d,'social_tiktok')[:500],'social_whatsapp':self.val(d,'social_whatsapp')[:500],'contact_email':self.val(d,'contact_email')[:254],'contact_phone':self.val(d,'contact_phone')[:80]});conf=cfg();conf['currency_symbol']=symbol;save_cfg(conf);return self.redirect('/admin/settings/general')
 def plans_data(self):
  c=cfg();plans=c.get('plans')
  if not isinstance(plans,list):
   plans=[{'id':'oro','title':'Plan Oro','benefits':'100 puntos','price':'10.00','period':'mensual','payment':'manual'},{'id':'diamante','title':'Plan Diamante','benefits':'200 puntos','price':'20.00','period':'mensual','payment':'manual'}];c['plans']=plans;save_cfg(c)
  return plans
 def plans(self,u):
  if not u:return self.redirect('/login')
  conf=cfg();currency=conf.get('currency_symbol') or site_settings().get('currency_symbol','S/') or 'S/';plans=self.plans_data();cards=''.join('<div class="card"><h2>'+html_escape(x.get('title','Plan'))+'</h2><p>'+html_escape(x.get('benefits',''))+'</p><p><b>Precio: '+html_escape(currency)+' '+html_escape(x.get('price','0'))+'</b> · '+html_escape(x.get('period','mensual'))+'</p><p>Método configurado: '+html_escape(x.get('payment','manual'))+'</p><button type="button" class="btn primary" data-plan-buy data-id="'+html_escape(x.get('id',''))+'" data-title="'+html_escape(x.get('title','Plan'))+'" data-benefits="'+html_escape(x.get('benefits',''))+'" data-price="'+html_escape(x.get('price','0'))+'" data-currency="'+html_escape(currency)+'" data-period="'+html_escape(x.get('period','mensual'))+'"><i class="fa-solid fa-cart-shopping"></i> Solicitar plan</button></div>' for x in plans) or '<p>No hay planes disponibles.</p>';manuals_html=''.join('<div class="manual-payment-option" data-name="'+html_escape(m.get('name',''))+'" data-info="'+html_escape(m.get('info',''))+'"></div>' for m in conf.get('manual_payment_methods',[]));cards += '<div id="manualPaymentOptions" style="display:none">'+manuals_html+'</div>'
  return self.send(200,body=tpl('plans.html',u,'Planes',CARDS=cards))
 def plans_settings(self,u):
  if not u or u['role']!='admin':return self.redirect('/login')
  c=cfg();manuals=c.get('manual_payment_methods',[])
  rows=''.join('<div class="card"><form method="post"><input type="hidden" name="id" value="'+html_escape(x.get('id',''))+'"><label>Título</label><input class="input" name="title" value="'+html_escape(x.get('title',''))+'"><label>Beneficios</label><textarea class="input" name="benefits">'+html_escape(x.get('benefits',''))+'</textarea><label>Precio</label><input class="input" name="price" type="number" step="0.01" value="'+html_escape(x.get('price','0'))+'"><label>Periodo</label><select class="input" name="period"><option value="mensual" '+('selected' if x.get('period')=='mensual' else '')+'>Mensual</option></select><label>Método de pago</label><select class="input" name="payment"><option value="manual" '+('selected' if x.get('payment')=='manual' else '')+'>Manual</option><option value="paypal" '+('selected' if x.get('payment')=='paypal' else '')+'>PayPal</option><option value="mercadopago" '+('selected' if x.get('payment')=='mercadopago' else '')+'>Mercado Pago</option></select><button class="btn primary" name="action" value="save">Guardar plan</button> <button class="btn danger" name="action" value="delete">Eliminar</button></form></div>' for x in self.plans_data())
  rows+='<div class="card"><h2>Agregar plan</h2><form method="post"><input type="hidden" name="id" value=""><label>Título</label><input class="input" name="title" required><label>Beneficios</label><textarea class="input" name="benefits" required></textarea><label>Precio</label><input class="input" name="price" type="number" min="0" step="0.01" required><label>Periodo</label><select class="input" name="period"><option value="mensual">Mensual</option></select><label>Método de pago</label><select class="input" name="payment"><option value="manual">Manual</option><option value="paypal">PayPal</option><option value="mercadopago">Mercado Pago</option></select><button class="btn primary" name="action" value="save">Agregar plan</button></form></div>'
  manuals_html=''.join('<div class="notice"><b>'+html_escape(m.get('name','Pago manual'))+'</b><p>'+html_escape(m.get('info',''))+'</p><form method="post" action="'+PREFIX+'/plans/settings/payments"><input type="hidden" name="action" value="delete_manual"><input type="hidden" name="id" value="'+html_escape(m.get('id',''))+'"><button class="btn danger">Eliminar método</button></form></div>' for m in manuals)
  payment_box='<div class="card"><h2><i class="fa-solid fa-coins"></i> Moneda local</h2><form method="post" action="'+PREFIX+'/plans/settings/payments"><input type="hidden" name="action" value="currency"><label>Símbolo o código de moneda (ej. S/, $, MXN, COP)</label><input class="input" name="currency_symbol" maxlength="8" value="'+html_escape(c.get('currency_symbol') or site_settings().get('currency_symbol','S/'))+'" required><button class="btn primary">Guardar moneda</button></form></div><div class="card"><h2><i class="fa-solid fa-wallet"></i> Métodos de pago</h2><button type="button" class="btn primary" data-open-dialog="manualDialog">Agregar método manual</button><dialog class="config-dialog" id="manualDialog"><button type="button" class="modal-x" data-close-dialog>×</button><h3>Agregar pago manual</h3><form method="post" action="'+PREFIX+'/plans/settings/payments"><input type="hidden" name="action" value="add_manual"><label>Nombre del método</label><input class="input" name="manual_name" placeholder="Ej. Yape, transferencia" required><label>Información e instrucciones</label><textarea class="input" name="manual_info" required></textarea><button class="btn primary">Guardar método manual</button></form></dialog>'+manuals_html+'<hr><button type="button" class="btn primary" data-open-dialog="paypalDialog">Configurar PayPal</button><dialog class="config-dialog" id="paypalDialog"><button type="button" class="modal-x" data-close-dialog>×</button><h3>Credenciales PayPal</h3><form method="post" action="'+PREFIX+'/plans/settings/payments"><input type="hidden" name="action" value="paypal"><label>Client ID</label><input class="input" name="paypal_client_id" value="'+html_escape(decrypt_credential(c.get('paypal_client_id','')) if c.get('paypal_client_id') else '')+'"><label>Client Secret</label><input class="input" name="paypal_secret" type="password" placeholder="Dejar vacío para conservar"><label>Modo</label><select class="input" name="paypal_mode"><option value="sandbox">Sandbox / pruebas</option><option value="live" '+('selected' if c.get('paypal_mode')=='live' else '')+'>Producción</option></select><button class="btn primary">Guardar PayPal</button></form></dialog><hr><button type="button" class="btn primary" data-open-dialog="mpDialog">Configurar Mercado Pago</button><dialog class="config-dialog" id="mpDialog"><button type="button" class="modal-x" data-close-dialog>×</button><h3>Credenciales Mercado Pago</h3><form method="post" action="'+PREFIX+'/plans/settings/payments"><input type="hidden" name="action" value="mercadopago"><label>Access Token</label><input class="input" name="mp_access_token" type="password" placeholder="Dejar vacío para conservar"><label>Public Key</label><input class="input" name="mp_public_key" value="'+html_escape(decrypt_credential(c.get('mp_public_key','')) if c.get('mp_public_key') else '')+'"><button class="btn primary">Guardar Mercado Pago</button></form></dialog><p class="muted small">Las credenciales se guardan protegidas. El cobro automático requiere configurar y probar las notificaciones/webhooks oficiales del proveedor; guardar credenciales por sí solo no confirma pagos.</p></div>'
  return self.send(200,body=tpl('plans_settings.html',u,'Configuración de planes',ROWS=rows+payment_box))
 def plans_settings_post(self,u,d):
  if not u or u['role']!='admin':return self.send(403,body='403')
  c=cfg();plans=self.plans_data();action=self.val(d,'action','save');pid=self.val(d,'id');
  if action=='delete':plans=[x for x in plans if x.get('id')!=pid]
  else:
   item={'id':pid or secrets.token_hex(5),'title':self.val(d,'title')[:100],'benefits':self.val(d,'benefits')[:2000],'price':self.val(d,'price','0')[:30],'period':self.val(d,'period','mensual'),'payment':self.val(d,'payment','manual')}
   if not item['title']:return self.send(400,body='El título es obligatorio')
   if pid and any(x.get('id')==pid for x in plans):plans=[item if x.get('id')==pid else x for x in plans]
   else:plans.append(item)
  c['plans']=plans;save_cfg(c);return self.redirect('/plans/settings')
 def plan_payment_settings_post(self,u,d):
  if not u or u.get('role')!='admin':return self.send(403,body='403')
  c=cfg();action=self.val(d,'action')
  if action=='currency':
   c['currency_symbol']=self.val(d,'currency_symbol','S/')[:8] or 'S/'
   save_settings({'currency_symbol':c['currency_symbol']})
  elif action=='add_manual':
   name=self.val(d,'manual_name')[:100];info=self.val(d,'manual_info')[:3000]
   if name and info:
    items=c.get('manual_payment_methods',[]);items.append({'id':secrets.token_hex(5),'name':name,'info':info});c['manual_payment_methods']=items
  elif action=='delete_manual':c['manual_payment_methods']=[x for x in c.get('manual_payment_methods',[]) if x.get('id')!=self.val(d,'id')]
  elif action=='paypal':
   if self.val(d,'paypal_client_id'):c['paypal_client_id']=crypt_credential(self.val(d,'paypal_client_id'))
   if self.val(d,'paypal_secret'):c['paypal_secret']=crypt_credential(self.val(d,'paypal_secret'))
   c['paypal_mode']=self.val(d,'paypal_mode','sandbox')
  elif action=='mercadopago':
   if self.val(d,'mp_access_token'):c['mp_access_token']=crypt_credential(self.val(d,'mp_access_token'))
   if self.val(d,'mp_public_key'):c['mp_public_key']=crypt_credential(self.val(d,'mp_public_key'))
  save_cfg(c);return self.redirect('/plans/settings')
 def plan_orders_init(self,c):
  c.execute('CREATE TABLE IF NOT EXISTS plan_orders(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,plan_id TEXT NOT NULL,plan_title TEXT NOT NULL,price TEXT NOT NULL,payment TEXT NOT NULL,status TEXT NOT NULL,created_at TEXT NOT NULL)')
 def add_notification(self,user_id,title,message,kind='general'):
  c=db();c.execute('INSERT INTO notifications(user_id,title,message,kind,created_at) VALUES(?,?,?,?,?)',(user_id,title[:160],message[:4000],kind,datetime.now().isoformat(timespec='seconds')));c.commit();c.close()
 def admin_notifications(self,u):
  if not u or u.get('role')!='admin':return self.redirect('/login')
  c=db();rows=c.execute('SELECT * FROM notifications WHERE user_id IS NULL ORDER BY id DESC LIMIT 50').fetchall();c.close()
  html=''.join('<div class="notice"><b>'+html_escape(x['title'])+'</b><p>'+html_escape(x['message'])+'</p><small>'+html_escape(x['created_at'])+'</small></div>' for x in rows) or '<p class="muted">Todavía no has enviado notificaciones.</p>'
  body='<div class="hero"><h1><i class="fa-solid fa-paper-plane"></i> Enviar notificaciones</h1><p>Las notificaciones se mostrarán en la campana de los usuarios.</p></div><div class="card form"><form method="post"><label>Título</label><input class="input" name="title" required maxlength="160"><label>Mensaje</label><textarea class="input" name="message" required rows="5"></textarea><label>Destinatarios</label><select class="input" name="target"><option value="all">Todos los usuarios</option></select><button class="btn primary">Enviar notificación</button></form></div><div class="hero"><h2>Enviadas recientemente</h2></div>'+html
  return self.send(200,body=page('Notificaciones',body,u))
 def admin_notifications_post(self,u,d):
  if not u or u.get('role')!='admin':return self.send(403,body='403')
  title=self.val(d,'title');message=self.val(d,'message')
  if not title or not message:return self.send(400,body='Título y mensaje son obligatorios')
  self.add_notification(None,title,message,'broadcast')
  c=db();users=c.execute('SELECT id FROM users WHERE active=1').fetchall();c.executemany('INSERT INTO notifications(user_id,title,message,kind,created_at) VALUES(?,?,?,?,?)',[(x['id'],title[:160],message[:4000],'broadcast',datetime.now().isoformat(timespec='seconds')) for x in users]);c.commit();c.close()
  return self.redirect('/admin/notifications')
 def notifications(self,u):
  if not u:return self.redirect('/login')
  c=db();rows=c.execute('SELECT * FROM notifications WHERE user_id=? ORDER BY id DESC LIMIT 100',(u['id'],)).fetchall();c.execute('UPDATE notifications SET is_read=1 WHERE user_id=?',(u['id'],));c.commit();c.close()
  cards=''.join('<div class="card"><h3>'+html_escape(x['title'])+'</h3><p>'+html_escape(x['message'])+'</p><small class="muted">'+html_escape(x['created_at'])+'</small></div>' for x in rows) or '<div class="card">No tienes notificaciones.</div>'
  modal=''
  return self.send(200,body=tpl('notifications.html',u,'Notificaciones',CARDS=modal+'<div class="grid">'+cards+'</div>'))
 def plans_history_action(self,u,d):
  if not u or u.get('role')!='admin':return self.send(403,body='403')
  try:oid=int(self.val(d,'order_id'))
  except:return self.send(400,body='Solicitud inválida')
  action=self.val(d,'action');c=db();self.plan_orders_init(c);order=c.execute('SELECT * FROM plan_orders WHERE id=?',(oid,)).fetchone()
  if not order:c.close();return self.send(404,body='Solicitud no encontrada')
  if action=='delete':c.execute('DELETE FROM plan_orders WHERE id=?',(oid,));c.commit();c.close();return self.redirect('/plans/history')
  if action not in ('approve','reject'):c.close();return self.send(400,body='Acción inválida')
  new_status='aprobado' if action=='approve' else 'rechazado'
  # Benefits are only applied once, on first transition to approved.
  if action=='approve' and order['status']=='pendiente':
   plan=next((x for x in self.plans_data() if x.get('id')==order['plan_id']),{})
   benefits=plan.get('benefits','')
   nums=re.findall(r'(?i)(\d+)\s*(?:puntos?|points?)',benefits)
   points=sum(int(n) for n in nums) if nums else 0
   if points:c.execute('UPDATE users SET referral_points=referral_points+? WHERE id=?',(points,order['user_id']))
   account_nums=re.findall(r'(?i)(\d+)\s*(?:cuentas?|accounts?)',benefits)
   if account_nums:
    try:
     entcfg=cfg();ent=entcfg.setdefault('user_plan_entitlements',{});key=str(order['user_id']);ent[key]=int(ent.get(key,0))+sum(int(n) for n in account_nums);save_cfg(entcfg)
    except Exception:pass
  c.execute('UPDATE plan_orders SET status=? WHERE id=?',(new_status,oid));c.commit();uid=order['user_id'];c.close()
  title='Plan aprobado' if action=='approve' else 'Plan rechazado'
  message=('Tu solicitud para el plan '+order['plan_title']+' fue aceptada. Los beneficios configurados se han aplicado a tu cuenta.' if action=='approve' else 'Tu solicitud para el plan '+order['plan_title']+' fue rechazada. No se aplicaron beneficios.')
  self.add_notification(uid,title,message,'plan_approved' if action=='approve' else 'plan_rejected')
  return self.send(200,body=tpl('message.html',u,'Acción completada',MESSAGE='<div class="expiry-modal" style="position:relative;inset:auto;background:transparent"><div class="expiry-modal-card"><h2><i class="fa-solid '+('fa-trash' if action=='delete' else ('fa-circle-check' if action=='approve' else 'fa-circle-xmark'))+'"></i> '+html_escape('Solicitud eliminada' if action=='delete' else ('Solicitud aprobada' if action=='approve' else 'Solicitud rechazada'))+'</h2><p>'+html_escape('Solicitud eliminada.' if action=='delete' else ('Beneficios aplicados.' if action=='approve' else 'No se aplicaron beneficios.'))+'</p><a class="btn primary" href="'+PREFIX+'/plans/history">Entendido</a></div></div>'))
 def plans_buy(self,u,d):
  if not u:return self.redirect('/login')
  pid=self.val(d,'plan_id');plans=self.plans_data();plan=next((x for x in plans if x.get('id')==pid),None)
  if not plan:return self.send(404,body='Plan no encontrado')
  payment=self.val(d,'payment_method','manual')
  if payment not in ('manual','paypal','mercadopago'):payment='manual'
  conf=cfg()
  if payment=='paypal' and not (conf.get('paypal_client_id') and conf.get('paypal_secret')):return self.send(400,body=tpl('message.html',u,'PayPal no configurado',MESSAGE='<div class="notice bad">El administrador debe configurar las credenciales de PayPal y la integración de pago antes de cobrar.</div><a class="btn" href="'+PREFIX+'/plans">Volver a planes</a>'))
  if payment=='mercadopago' and not conf.get('mp_access_token'):return self.send(400,body=tpl('message.html',u,'Mercado Pago no configurado',MESSAGE='<div class="notice bad">El administrador debe configurar Mercado Pago y su integración de pago antes de cobrar.</div><a class="btn" href="'+PREFIX+'/plans">Volver a planes</a>'))
  if payment!='manual':return self.send(501,body=tpl('message.html',u,'Pasarela pendiente de integrar',MESSAGE='<div class="notice bad">Las credenciales están guardadas, pero falta completar la creación de checkout y la verificación del webhook del proveedor. No se ha realizado ningún cobro ni aplicado beneficios.</div><a class="btn" href="'+PREFIX+'/plans">Volver a planes</a>'))
  c=db();self.plan_orders_init(c);c.execute('INSERT INTO plan_orders(user_id,plan_id,plan_title,price,payment,status,created_at) VALUES(?,?,?,?,?,?,?)',(u['id'],pid,plan['title'],plan['price'],payment,'pendiente',datetime.now().isoformat(timespec='seconds')));c.commit();c.close()
  return self.send(200,body=tpl('message.html',u,'Solicitud de plan',MESSAGE='<div class="notice">Solicitud manual registrada. Espera a que el administrador verifique el pago y apruebe el plan.</div><a class="btn" href="'+PREFIX+'/plans/history">Ver historial</a>'))
 def plans_history(self,u):
  if not u:return self.redirect('/login')
  c=db();self.plan_orders_init(c);rows=c.execute('SELECT o.*,u.username FROM plan_orders o LEFT JOIN users u ON u.id=o.user_id '+('' if u['role']=='admin' else 'WHERE o.user_id=? ')+'ORDER BY o.id DESC',(() if u['role']=='admin' else (u['id'],))).fetchall();c.close();html=[]
  for x in rows:
   actions='<a class="btn" href="'+PREFIX+'/plans/invoice?order='+str(x['id'])+'">Ver recibo</a> <a class="btn" href="'+PREFIX+'/plans/invoice?order='+str(x['id'])+'&download=pdf">PDF</a>'
   if u['role']=='admin':
    actions='<a class="btn" href="'+PREFIX+'/plans/invoice?order='+str(x['id'])+'">Recibo</a> <a class="btn" href="'+PREFIX+'/plans/invoice?order='+str(x['id'])+'&download=pdf">PDF</a> <form class="inline" method="post" action="'+PREFIX+'/plans/history/action"><input type="hidden" name="order_id" value="'+str(x['id'])+'"><button class="btn primary" name="action" value="approve" data-confirm="¿Aprobar esta solicitud y aplicar sus beneficios?">Aprobar</button><button class="btn danger" name="action" value="reject" data-confirm="¿Rechazar esta solicitud sin aplicar beneficios?">Rechazar</button><button class="btn" name="action" value="delete" data-confirm="¿Eliminar esta solicitud?">Eliminar</button></form>'
   html.append('<tr><td>'+html_escape(x['username'] or 'Usuario')+'</td><td>'+html_escape(x['plan_title'])+'</td><td>'+html_escape(cfg().get('currency_symbol') or site_settings().get('currency_symbol','S/'))+' '+html_escape(x['price'])+'</td><td>'+html_escape(x['payment'])+'</td><td>'+html_escape(x['status'])+'</td><td>'+html_escape(x['created_at'])+'</td><td>'+actions+'</td></tr>')
  return self.send(200,body=tpl('plans_history.html',u,'Historial',ROWS=''.join(html) or '<tr><td colspan="7">Sin solicitudes todavía.</td></tr>',ACTIONS_HEADER='<th>Recibo / acciones</th>'))
 def plans_invoice(self,u):
  if not u:return self.redirect('/login')
  query=parse_qs(urlparse(self.path).query);order_id=query.get('order',[''])[0]
  c=db();self.plan_orders_init(c)
  if order_id:
   try:oid=int(order_id)
   except:c.close();return self.send(400,body='Número de recibo inválido.')
   row=c.execute('SELECT o.*,u.username,u.name FROM plan_orders o LEFT JOIN users u ON u.id=o.user_id WHERE o.id=?'+('' if u['role']=='admin' else ' AND o.user_id=?'),(oid,) if u['role']=='admin' else (oid,u['id'])).fetchone();c.close()
   if not row:return self.send(404,body='Recibo no encontrado.')
   if query.get('download',[''])[0]=='pdf':
    lines=['KEVINTECH WEB - RECIBO DE PAGO','Recibo interno no tributario','Numero: '+str(row['id']),'Usuario: '+str(row['username'] or 'Usuario'),'Nombre: '+str(row['name'] or ''),'Plan: '+str(row['plan_title']),'Precio: '+str(cfg().get('currency_symbol') or site_settings().get('currency_symbol','S/'))+' '+str(row['price']),'Metodo: '+str(row['payment']),'Estado: '+str(row['status']).upper(),'Fecha: '+str(row['created_at']),'','Este recibo refleja el estado registrado en el panel.','No es un comprobante tributario.']
    b=self.make_pdf(lines);self.send_response(200);self.send_header('Content-Type','application/pdf');self.send_header('Content-Disposition','attachment; filename="recibo-kevintech-'+str(row['id'])+'.pdf"');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b);return
   body='<div class="hero"><h1><i class="fa-solid fa-receipt"></i> Recibo #'+str(row['id'])+'</h1><p>Recibo interno del panel; incluye solicitudes pendientes.</p></div><div class="card"><p><b>Usuario:</b> '+html_escape(row['username'] or 'Usuario')+'</p><p><b>Plan:</b> '+html_escape(row['plan_title'])+'</p><p><b>Precio:</b> '+html_escape(cfg().get('currency_symbol') or site_settings().get('currency_symbol','S/'))+' '+html_escape(row['price'])+'</p><p><b>Método:</b> '+html_escape(row['payment'])+'</p><p><b>Estado:</b> '+html_escape(row['status'])+'</p><p><b>Fecha:</b> '+html_escape(row['created_at'])+'</p><div class="notice">Este es un recibo interno del panel, no un comprobante tributario. Si está pendiente, seguirá indicando pendiente hasta que el administrador actualice la solicitud.</div><a class="btn primary" href="'+PREFIX+'/plans/invoice?order='+str(row['id'])+'&download=pdf"><i class="fa-solid fa-file-pdf"></i> Descargar PDF</a> <a class="btn" href="'+PREFIX+'/plans/invoice">Todos los recibos</a></div>'
   return self.send(200,body=page('Recibo #'+str(row['id']),body,u))
  rows=c.execute('SELECT o.*,u.username FROM plan_orders o LEFT JOIN users u ON u.id=o.user_id '+('' if u['role']=='admin' else 'WHERE o.user_id=? ')+'ORDER BY o.id DESC',(() if u['role']=='admin' else (u['id'],))).fetchall();c.close();items=[];currency=html_escape(cfg().get('currency_symbol') or site_settings().get('currency_symbol','S/'))
  for r in rows:
   items.append('<tr><td>#'+str(r['id'])+'</td><td>'+html_escape(r['username'] or 'Usuario')+'</td><td>'+html_escape(r['plan_title'])+'</td><td>'+currency+' '+html_escape(r['price'])+'</td><td>'+html_escape(r['payment'])+'</td><td>'+html_escape(r['status'])+'</td><td>'+html_escape(r['created_at'])+'</td><td><a class="btn" href="'+PREFIX+'/plans/invoice?order='+str(r['id'])+'">Ver</a> <a class="btn primary" href="'+PREFIX+'/plans/invoice?order='+str(r['id'])+'&download=pdf">PDF</a></td></tr>')
  body='<div class="hero"><h1><i class="fa-solid fa-file-invoice"></i> Recibos de pagos</h1><p>Todos los pagos y solicitudes, incluidos los que siguen pendientes.</p></div><div class="card table-wrap"><table class="table"><thead><tr><th>N.º</th><th>Usuario</th><th>Plan</th><th>Precio</th><th>Método</th><th>Estado</th><th>Fecha</th><th>Recibo</th></tr></thead><tbody>'+(''.join(items) or '<tr><td colspan="8">Todavía no hay solicitudes de pago.</td></tr>')+'</tbody></table></div>'
  return self.send(200,body=page('Recibos de pagos',body,u))
 def make_pdf(self,lines):
  def esc(x):return str(x).encode('latin-1','replace').decode('latin-1').replace('\\','\\\\').replace('(','\\(').replace(')','\\)')
  commands=['BT','/F1 12 Tf','50 790 Td','16 TL']
  for i,line in enumerate(lines):
   if i:commands.append('T*')
   commands.append('('+esc(line[:110])+') Tj')
  commands.append('ET');stream='\n'.join(commands).encode('latin-1');objs=[b'<< /Type /Catalog /Pages 2 0 R >>',b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',b'<< /Length '+str(len(stream)).encode()+b' >>\nstream\n'+stream+b'\nendstream']
  out=bytearray(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');offsets=[0]
  for i,obj in enumerate(objs,1):offsets.append(len(out));out.extend(str(i).encode()+b' 0 obj\n'+obj+b'\nendobj\n')
  xref=len(out);out.extend(b'xref\n0 6\n0000000000 65535 f \n')
  for off in offsets[1:]:out.extend(f'{off:010d} 00000 n \n'.encode())
  out.extend(b'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n'+str(xref).encode()+b'\n%%EOF');return bytes(out)
 def about(self,u):
  if not u:return self.redirect('/login')
  st=site_settings();section=parse_qs(urlparse(self.path).query).get('section',['about'])[0];mapx={'about':('Sobre nosotros','about_us'),'privacy':('Política de privacidad','privacy'),'cookies':('Política de cookies','cookies'),'terms':('Términos y condiciones','terms')};edit=''
  if section=='social':
   title='Redes sociales y contacto';parts=[]
   for label,key,icon in [('Facebook','social_facebook','fa-brands fa-facebook'),('Instagram','social_instagram','fa-brands fa-instagram'),('TikTok','social_tiktok','fa-brands fa-tiktok'),('WhatsApp','social_whatsapp','fa-brands fa-whatsapp')]:
    val=str(st.get(key,'')).strip()
    if val and val.startswith(('https://','http://')):parts.append('<p><i class="'+icon+'"></i> <a rel="noopener noreferrer" target="_blank" href="'+html_escape(val)+'">'+label+'</a></p>')
   email=str(st.get('contact_email','')).strip();phone=str(st.get('contact_phone','')).strip()
   if email and re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+',email):parts.append('<p><i class="fa-solid fa-envelope"></i> <a href="mailto:'+html_escape(email)+'">'+html_escape(email)+'</a></p>')
   if phone:parts.append('<p><i class="fa-solid fa-phone"></i> '+html_escape(phone)+'</p>')
   content=''.join(parts) or '<p>Aún no se han configurado redes sociales ni datos de contacto.</p>'
  else:
   title,key=mapx.get(section,mapx['about']);content=html_escape(st[key]).replace('\n','<br>')
  if u['role']=='admin':edit='<a class="btn" href="%s/admin/settings/general"><i class="fa-solid fa-gear"></i> Editar contenido y contacto</a>'%PREFIX
  return self.send(200,body=tpl('about.html',u,title,HEADING=title,CONTENT=content,EDIT=edit))
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
