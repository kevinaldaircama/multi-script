#!/usr/bin/env python3
import base64, hashlib, hmac, json, os, re, secrets, sqlite3, subprocess, time, uuid, shlex
from datetime import datetime, timedelta
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

BASE=Path('/etc/kevintech'); WEB=BASE/'web'; DATA=WEB/'data'; DB=DATA/'web.sqlite3'; CONFIG=DATA/'config.json'; KEYFILE=DATA/'.credential.key'; LOG=DATA/'web.log'
HOST='127.0.0.1'; PORT=int(os.environ.get('KEVINTECH_WEB_PORT','18080')); PREFIX=os.environ.get('KEVINTECH_WEB_PREFIX','/').strip().rstrip('/'); SESSION_TTL=86400*3; TOKEN_TTL=600

def log(msg):
    DATA.mkdir(parents=True,exist_ok=True); LOG.open('a',encoding='utf-8').write(datetime.now().isoformat(timespec='seconds')+' '+str(msg)+'\n')

def db():
    DATA.mkdir(parents=True,exist_ok=True); c=sqlite3.connect(DB,timeout=10); c.row_factory=sqlite3.Row; c.execute('PRAGMA journal_mode=WAL'); c.execute('PRAGMA foreign_keys=ON')
    c.executescript('''CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,name TEXT NOT NULL,created_at TEXT NOT NULL,referral_code TEXT UNIQUE NOT NULL,referred_by TEXT,referral_points INTEGER NOT NULL DEFAULT 0,referral_renews INTEGER NOT NULL DEFAULT 0,active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL,username TEXT UNIQUE NOT NULL,type TEXT NOT NULL DEFAULT 'ssh',credential TEXT NOT NULL,expiration TEXT,ip_limit INTEGER NOT NULL DEFAULT 1,created_at TEXT NOT NULL,FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user_id INTEGER,role TEXT NOT NULL,expires REAL NOT NULL);
CREATE TABLE IF NOT EXISTS ad_tokens(token TEXT PRIMARY KEY,user_id INTEGER NOT NULL,action TEXT NOT NULL,account_id INTEGER,expires REAL NOT NULL,completed INTEGER NOT NULL DEFAULT 0,payload TEXT NOT NULL DEFAULT '{}');
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);'''); c.commit(); return c

def cfg():
    DATA.mkdir(parents=True,exist_ok=True)
    defaults={'admin_username':'admin','admin_password_hash':'','secret':secrets.token_hex(32),'ads_enabled':True,'ad_provider':'monetag','monetag_zone':'11217882','ads':{'create':3,'delete':1,'renew':3},'server_prefix':PREFIX,'server_domain':'','general':{'site_title':'KevinTech Multi Script','site_description':'Panel web para administrar tu servidor.'},'quotas':{'ssh':{'days':7,'limit':1},'v2ray':{'days':7,'limit':1}},'about':{'about':'Somos KevinTech. Bienvenido a nuestro panel Multi Script.','privacy':'Tu información se utiliza únicamente para el funcionamiento del servicio.','cookies':'Este sitio puede utilizar cookies técnicas para mantener la sesión.','terms':'El uso del servicio debe cumplir las leyes y las reglas del servidor.'}}
    if not CONFIG.exists(): CONFIG.write_text(json.dumps(defaults,indent=2,ensure_ascii=False),encoding='utf-8')
    try:
        c=json.loads(CONFIG.read_text(encoding='utf-8'))
    except Exception: c={}
    changed=False
    def merge(a,b):
        nonlocal changed
        for k,v in b.items():
            if k not in a:a[k]=v;changed=True
            elif isinstance(v,dict):
                if not isinstance(a[k],dict):a[k]={};changed=True
                merge(a[k],v)
    merge(c,defaults)
    if changed: save_cfg(c)
    return c

def save_cfg(c): CONFIG.write_text(json.dumps(c,indent=2,ensure_ascii=False),encoding='utf-8'); os.chmod(CONFIG,0o600)

def hash_password(pw,salt=None):
    salt=salt or secrets.token_bytes(16); h=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); return 'scrypt$'+base64.urlsafe_b64encode(salt).decode()+'$'+base64.urlsafe_b64encode(h).decode()
def verify_password(pw,stored):
    try:
        _,s,h=stored.split('$',2); salt=base64.urlsafe_b64decode(s.encode()); expected=base64.urlsafe_b64decode(h.encode()); got=hashlib.scrypt(pw.encode(),salt=salt,n=2**14,r=8,p=1); return hmac.compare_digest(got,expected)
    except Exception:return False
def credential_key():
    if not KEYFILE.exists(): KEYFILE.write_bytes(secrets.token_bytes(32)); os.chmod(KEYFILE,0o600)
    return KEYFILE.read_bytes()
def crypt_credential(text):
    try:
        p=subprocess.run(['openssl','enc','-aes-256-cbc','-a','-A','-salt','-pbkdf2','-iter','120000','-pass','file:'+str(KEYFILE)],input=text.encode(),capture_output=True,timeout=5)
        if p.returncode==0:return 'openssl$'+p.stdout.decode().strip()
    except Exception:pass
    return 'plain$'+text
def decrypt_credential(v):
    try:
        if v.startswith('openssl$'):
            p=subprocess.run(['openssl','enc','-d','-aes-256-cbc','-a','-A','-pbkdf2','-iter','120000','-pass','file:'+str(KEYFILE)],input=v[8:].encode(),capture_output=True,timeout=5)
            if p.returncode==0:return p.stdout.decode()
        if v.startswith('plain$'):return v[6:]
    except Exception:pass
    return ''
def ensure_admin():
    c=cfg(); credential_key(); changed=False
    if not c.get('admin_username'):c['admin_username']='admin';changed=True
    if not c.get('admin_password_hash'):
        pw=os.environ.get('WEB_ADMIN_PASS') or secrets.token_urlsafe(12); c['admin_password_hash']=hash_password(pw); c['initial_admin_password']=pw;changed=True
    if changed:save_cfg(c)
    x=db();x.close()
def now():return time.time()
def iso(dt):return dt.strftime('%Y-%m-%d')
def display_date(v):
    try:return datetime.strptime(str(v),'%Y-%m-%d').strftime('%d/%m/%Y')
    except:return str(v)
def safe_username(s):return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',s or ''))
def safe_web_username(s):return bool(re.fullmatch(r'[A-Za-z0-9_.-]{3,32}',s or ''))
def html_escape(s):return str(s).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;')
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
            pid=m.group(1); u=subprocess.run(['ps','-o','user=','-p',pid],capture_output=True,text=True,timeout=2).stdout.strip()
            if u!=username:continue
            parts=line.split(); peer=parts[4] if len(parts)>4 else '—'; ip=peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer; rows.append(ip)
        return sorted(set(rows))
    except Exception:return []
def all_online():
    try:
        out=subprocess.run(['ss','-tnp','state','established'],capture_output=True,text=True,timeout=5).stdout; rows=[]
        for line in out.splitlines():
            if ':22' not in line:continue
            m=re.search(r'users:\(\("sshd",pid=(\d+)',line)
            if not m:continue
            u=subprocess.run(['ps','-o','user=','-p',m.group(1)],capture_output=True,text=True,timeout=2).stdout.strip()
            if not u or u in ('root','sshd','users'):continue
            parts=line.split(); peer=parts[4] if len(parts)>4 else '—'; ip=peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer; rows.append((u,ip))
        return rows
    except Exception:return []

def create_ssh_account(username,password,days,limit):
    if not safe_username(username):return False,'Usuario inválido.',None
    if len(password)<4:return False,'La contraseña debe tener al menos 4 caracteres.',None
    if days<1 or days>3650:return False,'Días inválidos.',None
    if limit<0 or limit>100:return False,'Límite inválido.',None
    if subprocess.run(['id',username],capture_output=True).returncode==0:return False,'Ese usuario ya existe en el VPS.',None
    exp=iso(datetime.now()+timedelta(days=days)); rc,out=shell('useradd -e %s -M -s /usr/sbin/nologin %s && printf %s | chpasswd'%(shlex.quote(exp),shlex.quote(username),shlex.quote(username+':'+password)),15)
    if rc!=0:shell('userdel -f %s 2>/dev/null || true'%shlex.quote(username),10);return False,out or 'No se pudo crear el usuario.',None
    limits=BASE/'limits.conf';lines=limits.read_text(errors='ignore').splitlines() if limits.exists() else [];lines=[x for x in lines if not x.startswith(username+':')];lines.append(f'{username}:{limit}');limits.write_text('\n'.join(lines)+'\n');os.chmod(limits,0o600);return True,exp,None

def renew_ssh(username,days):
    if not safe_username(username) or subprocess.run(['id',username],capture_output=True).returncode!=0:return False,'Cuenta no encontrada.'
    if days<1 or days>3650:return False,'Días inválidos.'
    exp=iso(datetime.now()+timedelta(days=days));rc,out=shell('chage -E %s %s'%(shlex.quote(exp),shlex.quote(username)),10);return rc==0,exp if rc==0 else out

def xray_config_path():return Path('/usr/local/etc/xray/config.json')
def create_v2ray_account(username,password,days,limit):
    if not safe_username(username):return False,'Usuario inválido.',None
    path=xray_config_path()
    if not path.exists():return False,'V2Ray/Xray no está instalado o no existe su configuración.',None
    try:data=json.loads(path.read_text()); clients=data.setdefault('inbounds',[{}])[0].setdefault('settings',{}).setdefault('clients',[])
    except Exception as e:return False,'No se pudo leer la configuración de Xray: '+str(e),None
    if any(x.get('email')==username for x in clients):return False,'Ese usuario V2Ray ya existe.',None
    uid=str(uuid.uuid4());clients.append({'id':uid,'level':0,'email':username});tmp=path.with_suffix('.json.tmp');tmp.write_text(json.dumps(data,indent=2,ensure_ascii=False));os.replace(tmp,path)
    rc,out=shell('systemctl restart xray',15)
    if rc!=0:return False,out or 'No se pudo reiniciar Xray.',None
    exp=iso(datetime.now()+timedelta(days=days)); return True,exp,uid

def delete_account_real(a):
    if a['type']=='ssh':return shell('userdel -r -f %s'%shlex.quote(a['username']),15)[0]==0
    if a['type'] in ('v2ray','vmess'):
        p=xray_config_path()
        try:
            data=json.loads(p.read_text()); clients=data['inbounds'][0]['settings']['clients']; data['inbounds'][0]['settings']['clients']=[x for x in clients if x.get('email')!=a['username']]; p.write_text(json.dumps(data,indent=2,ensure_ascii=False)); shell('systemctl restart xray',15); return True
        except Exception:return False
    return False

def server_domain():
    c=cfg(); d=c.get('server_domain','')
    if d:return d
    try:
        if (BASE/'config.conf').exists():
            for line in (BASE/'config.conf').read_text(errors='ignore').splitlines():
                if line.startswith('SERVER_DOMAIN='):return line.split('=',1)[1].strip().strip('"')
    except Exception:pass
    return os.environ.get('SERVER_DOMAIN','localhost')

def server_ip():
    try:return subprocess.run("curl -4 -s --max-time 3 https://api.ipify.org",shell=True,capture_output=True,text=True).stdout.strip() or '—'
    except:return '—'

def quota(t):
    q=cfg().get('quotas',{}).get(t,{})
    try:return max(1,int(q.get('days',7))),max(0,int(q.get('limit',1)))
    except:return 7,1

def ad_required(action):
    c=cfg();
    if not c.get('ads_enabled',True):return 0
    try:return max(0,int(c.get('ads',{}).get(action,1)))
    except:return 1
def issue_ad(c,user_id,action,account_id=None,payload=None,completed=0):
    n=ad_required(action)
    if n<=0:return None
    token=secrets.token_urlsafe(24);c.execute('INSERT INTO ad_tokens VALUES(?,?,?,?,?,?,?)',(token,user_id,action,account_id,now()+TOKEN_TTL,completed,json.dumps(payload or {},ensure_ascii=False)));c.commit();return token
def get_ad(c,token,user_id):return c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND expires>?',(token,user_id,now())).fetchone()
def consume_pass(c,token,user_id):
    row=c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND expires>? AND completed=-1',(token,user_id,now())).fetchone()
    if not row:return None
    c.execute('DELETE FROM ad_tokens WHERE token=?',(token,));c.commit();return row

def render_template(name,**values):
    try:html=(WEB/'templates'/name).read_text(encoding='utf-8')
    except:return '<!doctype html><html><body>Template missing: '+html_escape(name)+'</body></html>'
    for k,v in values.items():html=html.replace('{{'+k+'}}',str(v))
    return html.replace('{{PREFIX}}',PREFIX)

def page(title,body,user=None):
    nav=''
    if user:
        role=user.get('role')
        home='/admin' if role=='admin' else '/dashboard'
        nav='<div class="brand">⚡ KEVINTECH</div><button class="hamb" id="menuBtn" type="button" aria-label="Abrir menú" aria-expanded="false">☰</button><div class="menu-backdrop" id="menuBackdrop"></div><nav id="mainNav" aria-label="Menú principal">'
        nav+='<a class="nav-main" href="%s%s">📊 Panel</a>'%(PREFIX,home)
        nav+='<details><summary>⚙️ Protocolos</summary><div class="submenu"><a href="%s/protocols?status=active">🟢 Protocolos activos</a><a href="%s/protocols?status=inactive">🔴 Protocolos inactivos</a></div></details>'%(PREFIX,PREFIX)
        if role=='admin':
            nav+='<a class="nav-main" href="%s/console">⌨️ Consola</a>'%PREFIX
            nav+='<details><summary>⚙️ Configuración</summary><div class="submenu"><a href="%s/admin/settings">👤 Perfil</a><a href="%s/admin/settings?tab=ads">📢 Ajuste de ads</a><a href="%s/admin/settings?tab=general">📝 Ajuste general</a><a href="%s/admin/settings?tab=quotas">📏 Cuotas de creación</a></div></details>'%(PREFIX,PREFIX,PREFIX,PREFIX)
        nav+='<details><summary>👤 Panel de usuario</summary><div class="submenu"><a href="%s/account/create">➕ Crear cuenta</a>'%PREFIX
        if role=='admin':nav+='<a href="%s/admin/accounts/delete">🗑️ Eliminar cuenta</a>'%PREFIX
        nav+='<a href="%s/online">🟢 Online</a><a href="%s/referrals">🎁 Referidos</a><a href="%s/profile">👤 Perfil</a></div></details>'%(PREFIX,PREFIX,PREFIX)
        nav+='<details><summary>ℹ️ About</summary><div class="submenu"><a href="%s/about">Sobre nosotros</a><a href="%s/about?section=privacy">Política de privacidad</a><a href="%s/about?section=cookies">Política de cookies</a><a href="%s/about?section=terms">Términos y condiciones</a></div></details>'%(PREFIX,PREFIX,PREFIX,PREFIX)
        nav+='<a class="nav-main nav-exit" href="%s/logout">↪ Salir</a></nav>'%PREFIX
    else:
        nav='<div class="brand">⚡ KEVINTECH</div>'
    return render_template('base.html',TITLE=html_escape(title),NAV=nav,BODY=body)

def tpl(name,user=None,title='',**values):return page(title,render_template(name,**values),user)

class Handler(BaseHTTPRequestHandler):
    server_version='KevinTechWeb/2.0'
    def log_message(self,fmt,*args):pass
    def route_path(self):
        p=urlparse(self.path).path or '/'
        if PREFIX and p.startswith(PREFIX):p=p[len(PREFIX):] or '/'
        # Normaliza rutas comunes para que /index.html y las rutas con / final
        # no terminen en el 404 del proxy/web.
        if p in ('/index.html','/index.htm','/home','/home/'):
            return '/'
        if len(p)>1 and p.endswith('/'):
            p=p.rstrip('/')
        return p
    def send(self,status=200,ctype='text/html; charset=utf-8',body=''):
        b=body.encode() if isinstance(body,str) else body;self.send_response(status);self.send_header('Content-Type',ctype);self.send_header('Content-Length',str(len(b)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(b)
    def redirect(self,to):self.send_response(303);self.send_header('Location',PREFIX+to if to.startswith('/') else to);self.send_header('Content-Length','0');self.end_headers()
    def cookies(self):c=cookies.SimpleCookie();c.load(self.headers.get('Cookie',''));return c
    def session(self):
        x=self.cookies().get('kt_session');
        if not x:return None
        c=db();r=c.execute('SELECT * FROM sessions WHERE token=? AND expires>?',(x.value,now())).fetchone()
        if not r:c.close();return None
        if r['role']=='admin':u={'role':'admin','username':cfg().get('admin_username','admin'),'name':'Administrador','id':0}
        else:
            q=c.execute('SELECT * FROM users WHERE id=? AND active=1',(r['user_id'],)).fetchone();u=dict(q) if q else None
            if u:u['role']='user'
        c.close();return u
    def set_session(self,uid,role):
        tok=secrets.token_urlsafe(32);c=db();c.execute('DELETE FROM sessions WHERE expires<?',(now(),));c.execute('INSERT INTO sessions VALUES(?,?,?,?)',(tok,uid,role,now()+SESSION_TTL));c.commit();c.close();o=cookies.SimpleCookie();o['kt_session']=tok;o['kt_session']['path']=PREFIX or '/';o['kt_session']['httponly']=True;o['kt_session']['secure']=True;o['kt_session']['samesite']='Lax';self.extra_cookie=o.output(header='').strip()
    def read_post(self):
        n=int(self.headers.get('Content-Length','0'));return parse_qs(self.rfile.read(min(n,1024*1024)).decode(errors='ignore'),keep_blank_values=True)
    def val(self,d,k,default=''):return d.get(k,[default])[0].strip()
    def do_GET(self):
        p=self.route_path();u=self.session()
        if p=='/':return self.send(200,body=tpl('index.html',None,'Inicio',TITLE=html_escape(cfg().get('general',{}).get('site_title','KevinTech Multi Script')),DESCRIPTION=html_escape(cfg().get('general',{}).get('site_description','Panel web para administrar tu servidor.'))))
        if p=='/404':return self.not_found()
        if p=='/login':return self.login_page()
        if p=='/register':return self.register_page()
        if p=='/logout':
            x=self.cookies().get('kt_session');
            if x:
                c=db();c.execute('DELETE FROM sessions WHERE token=?',(x.value,));c.commit();c.close()
            return self.redirect('/')
        if p=='/dashboard':return self.dashboard(u)
        if p=='/protocols':return self.protocols(u)
        if p=='/profile':return self.profile(u)
        if p=='/online':return self.online(u)
        if p=='/referrals':return self.referrals(u)
        if p=='/account':return self.account_detail(u)
        if p=='/account/create':return self.account_create_page(u)
        if p=='/admin':return self.admin(u)
        if p=='/admin/accounts/delete':return self.admin_delete_page(u)
        if p=='/console':return self.console(u)
        if p=='/admin/settings':return self.admin_settings(u)
        if p=='/about':return self.about(u)
        if p=='/ads':return self.ads_page(u)
        if p=='/static/health':return self.send(200,'application/json',json.dumps({'ok':True,'time':time.time()}))
        return self.not_found()
    def do_POST(self):
        p=self.route_path();d=self.read_post();u=self.session()
        if p=='/login':return self.login_post(d)
        if p=='/register':return self.register_post(d)
        if p=='/profile':return self.profile_post(u,d)
        if p=='/referrals/redeem':return self.referral_redeem(u,d)
        if p=='/account/create':return self.account_create(u,d)
        if p=='/account/delete':return self.account_delete(u,d)
        if p=='/account/renew':return self.account_renew(u,d)
        if p=='/ads/complete':return self.ad_complete(u,d)
        if p=='/admin/settings':return self.admin_settings_post(u,d)
        if p=='/console':return self.console_post(u,d)
        return self.not_found()
    def not_found(self):return self.send(404,body=render_template('404.html',TITLE='404'))
    def auth_redirect(self,to):
        self.send_response(303);self.send_header('Location',PREFIX+to);self.send_header('Set-Cookie',self.extra_cookie);self.send_header('Content-Length','0');self.end_headers()
    def login_page(self,msg=''):return self.send(200,body=tpl('login.html',None,'Ingreso',MSG=msg))
    def login_post(self,d):
        user=self.val(d,'username');pw=self.val(d,'password');c=db();a=cfg();ok=False;role='';uid=0
        if hmac.compare_digest(user,a.get('admin_username','')) and verify_password(pw,a.get('admin_password_hash','')):ok=True;role='admin'
        else:
            r=c.execute('SELECT * FROM users WHERE username=? AND active=1',(user,)).fetchone()
            if r and verify_password(pw,r['password_hash']):ok=True;role='user';uid=r['id']
        c.close()
        if not ok:return self.login_page('<div class="notice bad">Usuario o contraseña incorrectos.</div>')
        self.set_session(uid,role);return self.auth_redirect('/admin' if role=='admin' else '/dashboard')
    def register_page(self,msg=''):
        q=parse_qs(urlparse(self.path).query);ref=self.val(q,'ref','')
        ref=ref if re.fullmatch(r'[A-Za-z0-9_-]{4,32}',ref or '') else ''
        return self.send(200,body=tpl('register.html',None,'Registro',MSG=msg,REF=html_escape(ref)))
    def register_post(self,d):
        name=self.val(d,'name');user=self.val(d,'username');pw=self.val(d,'password');ref=self.val(d,'ref')
        if not name or not safe_web_username(user) or len(pw)<6:
            return self.send(400,body=tpl('register.html',None,'Registro',MSG='<div class="notice bad">Datos inválidos. La contraseña debe tener 6 caracteres o más.</div>',REF=html_escape(ref)))
        c=db()
        if user=='__admin_owner__' or c.execute('SELECT 1 FROM users WHERE username=?',(user,)).fetchone():
            c.close();return self.send(400,body=tpl('register.html',None,'Registro',MSG='<div class="notice bad">Ese usuario web ya existe.</div>',REF=html_escape(ref)))
        # El código de referido identifica al usuario que compartió el enlace.
        referrer=c.execute('SELECT id,username FROM users WHERE referral_code=? AND active=1',(ref,)).fetchone() if ref else None
        code=secrets.token_urlsafe(7)
        c.execute('INSERT INTO users(username,password_hash,name,created_at,referral_code,referred_by) VALUES(?,?,?,?,?,?)',(user,hash_password(pw),name,datetime.now().isoformat(timespec='seconds'),code,ref if referrer else None))
        uid=c.execute('SELECT last_insert_rowid()').fetchone()[0]
        # +2 para quien comparte y +1 para quien entra mediante el enlace.
        if referrer and referrer['id']!=uid:
            c.execute('UPDATE users SET referral_points=referral_points+2 WHERE id=?',(referrer['id'],))
            c.execute('UPDATE users SET referral_points=referral_points+1 WHERE id=?',(uid,))
        c.commit();c.close();self.set_session(uid,'user');return self.auth_redirect('/dashboard')
    def dashboard(self,u):
        if not u:return self.redirect('/login')
        if u['role']=='admin':return self.admin(u)
        c=db();a=c.execute('SELECT * FROM accounts WHERE user_id=? ORDER BY id DESC',(u['id'],)).fetchall();online=sum(len(account_online(x['username'])) for x in a);c.close();cards=''.join('<div class="card"><h3>👤 %s</h3><p class="muted">Tipo: %s · Expira: %s</p><p>Online: <b class="oktxt">%s</b></p><p><span class="tag">Límite %s IP</span></p><a class="btn" href="%s/account?id=%s">Ver</a></div>'%(html_escape(x['username']),html_escape(x['type']),html_escape(x['expiration'] or '—'),len(account_online(x['username'])),x['ip_limit'],PREFIX,x['id']) for x in a);return self.send(200,body=tpl('dashboard.html',u,'Inicio',COUNT=len(a),ONLINE=online,POINTS=u['referral_points'],REFERRAL_CODE=html_escape(u['referral_code']),ACCOUNTS=cards or '<div class="card">No tienes cuentas todavía.</div>'))
    def protocol_rows(self):
        services=[('OpenSSH','ssh','🔐'),('Dropbear','dropbear_custom','🚪'),('HAProxy / SSL','haproxy','🔒'),('SlowDNS','dnstt','🌐'),('Xray / V2Ray','xray','☁️'),('OpenVPN','openvpn-server@server','🔐'),('Hysteria','hysteria1-server','🛡️'),('BHTTP','bhttp','🌐'),('XHTTP','xhttp','🚀'),('Squid','squid','🌐'),('HCR','hcr-server','🛡️'),('WireGuard','wg-quick@wg0','🛡️'),('BTUN','btun','⚡'),('Shadowsocks','shadowsocks-libev-server@8388','🕶️'),('SOCKS5','sockd','🔐'),('3X-UI','x-ui','🖥️'),('VayDNS','vaydns','🔐'),('Slipstream','slipstream','🚀'),('DNSDist','dnsdist','🌐')];out=[]
        for n,s,i in services:
            try:on=subprocess.run(['systemctl','is-active','--quiet',s],timeout=3).returncode==0
            except:on=False
            out.append((n,i,on))
        return out
    def protocols(self,u):
        if not u:return self.redirect('/login')
        status=parse_qs(urlparse(self.path).query).get('status',['all'])[0].lower()
        if status not in ('all','active','inactive'):status='all'
        services=self.protocol_rows()
        rows=[x for x in services if status=='all' or (status=='active' and x[2]) or (status=='inactive' and not x[2])]
        html=''.join('<div class="service-card"><div class="service-icon">%s</div><div class="service-main"><strong>%s</strong><span class="muted">%s</span></div><span class="status %s">%s</span></div>'%(i,html_escape(n),'Activo' if on else 'Inactivo','on' if on else 'off','ACTIVO' if on else 'INACTIVO') for n,i,on in rows)
        if not html:html='<div class="card"><h3>No hay protocolos %s.</h3><p class="muted">Prueba con otro filtro.</p></div>'%('activos' if status=='active' else 'inactivos' if status=='inactive' else 'disponibles')
        active_cls='primary' if status=='active' else ''
        inactive_cls='primary' if status=='inactive' else ''
        all_cls='primary' if status=='all' else ''
        return self.send(200,body=tpl('protocols.html',u,'Protocolos',COUNT=len(rows),ROWS=html,ALL_ACTIVE=all_cls,ACTIVE_ACTIVE=active_cls,INACTIVE_ACTIVE=inactive_cls))
    def profile(self,u):
        if not u:return self.redirect('/login')
        if u['role']=='admin':return self.admin_settings(u)
        return self.send(200,body=tpl('profile.html',u,'Perfil',NAME=html_escape(u['name']),USERNAME=html_escape(u['username']),CREATED=u['created_at'],POINTS=u['referral_points'],CODE=html_escape(u['referral_code'])))
    def profile_post(self,u,d):
        if not u:return self.send(403,body='403')
        if u['role']=='admin':return self.admin_settings_post(u,d)
        name=self.val(d,'name') or u['name'];pw=self.val(d,'password');c=db();c.execute('UPDATE users SET name=?%s WHERE id=?'%(', password_hash=?' if pw else ''),(name,hash_password(pw),u['id']) if pw else (name,u['id']));c.commit();c.close();return self.redirect('/profile')
    def online(self,u):
        if not u:return self.redirect('/login')
        c=db();rows=all_online() if u['role']=='admin' else [(x[0],x[1]) for x in all_online() if x[0] in {r['username'] for r in c.execute('SELECT username FROM accounts WHERE user_id=?',(u['id'],)).fetchall()}];c.close();rows_html=''.join('<tr><td>%s</td><td>%s</td></tr>'%(html_escape(a),html_escape(b)) for a,b in rows) or '<tr><td colspan="2">No hay conexiones SSH activas.</td></tr>';return self.send(200,body=tpl('online.html',u,'Online',ROWS=rows_html))
    def referrals(self,u):
        if not u:return self.redirect('/login')
        c=db()
        if u['role']=='admin':
            rows=c.execute('SELECT username,name,referral_points,referral_renews,active FROM users ORDER BY id DESC').fetchall();c.close();h=''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(html_escape(x['username']),html_escape(x['name']),x['referral_points'],x['referral_renews']) for x in rows) or '<tr><td colspan="4">No hay usuarios.</td></tr>';return self.send(200,body=tpl('referrals.html',u,'Referidos',POINTS=sum(x['referral_points'] for x in rows),LINK='—',REDEEM='<div class="card table-wrap"><table class="table"><tr><th>Usuario</th><th>Nombre</th><th>Puntos</th><th>Renovaciones</th></tr>'+h+'</table></div>'))
        accounts=c.execute('SELECT id,username FROM accounts WHERE user_id=? ORDER BY username',(u['id'],)).fetchall();c.close();opts=''.join('<option value="%s">%s</option>'%(a['id'],html_escape(a['username'])) for a in accounts);redeem='<div class="card form"><h3>🎁 Canjear referidos</h3><p>Con 3 puntos puedes añadir 7 días a una cuenta.</p><form method="post" action="%s/referrals/redeem"><select class="input" name="account_id" required>%s</select><button class="btn primary">Canjear 3 puntos</button></form></div>'%(PREFIX,opts) if accounts else '<div class="card">Crea una cuenta para canjear puntos.</div>'
        domain=server_domain().strip()
        if domain and domain not in ('localhost','127.0.0.1'):
            scheme='https'
            link=scheme+'://'+domain.rstrip('/')+'/register?ref='+str(u['referral_code'])
        else:
            host=self.headers.get('Host','').split(':',1)[0].strip()
            scheme='https' if self.headers.get('X-Forwarded-Proto','https').lower()=='https' else 'http'
            link=(scheme+'://'+host+'/register?ref='+str(u['referral_code'])) if host else '/register?ref='+str(u['referral_code'])
        return self.send(200,body=tpl('referrals.html',u,'Referidos',POINTS=u['referral_points'],LINK=html_escape(link),REDEEM=redeem))
    def referral_redeem(self,u,d):
        if not u or u['role']!='user':return self.send(403,body='403')
        try:aid=int(self.val(d,'account_id'))
        except:return self.send(400,body='Cuenta inválida')
        c=db();me=c.execute('SELECT referral_points FROM users WHERE id=?',(u['id'],)).fetchone();a=c.execute('SELECT * FROM accounts WHERE id=? AND user_id=?',(aid,u['id'])).fetchone()
        if not me or me['referral_points']<3 or not a:c.close();return self.send(400,body=page('Referidos','<div class="notice bad">Necesitas 3 puntos y una cuenta propia.</div>',u))
        ok,msg=renew_ssh(a['username'],7)
        if ok:c.execute('UPDATE users SET referral_points=referral_points-3,referral_renews=referral_renews+1 WHERE id=?',(u['id'],));c.execute('UPDATE accounts SET expiration=? WHERE id=?',(msg,aid));c.commit()
        c.close();return self.send(200,body=page('Referidos','<div class="notice %s">%s</div>'%('oktxt' if ok else 'bad',html_escape('Canje realizado: '+msg if ok else msg)),u))
    def account_detail(self,u):
        if not u:return self.redirect('/login')
        try:aid=int(parse_qs(urlparse(self.path).query).get('id',['0'])[0])
        except:aid=0
        c=db();a=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id WHERE a.id=?',(aid,)).fetchone()
        if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.not_found()
        pw=decrypt_credential(a['credential']);ips=account_online(a['username']);c.close();extra=''
        if a['type'] in ('v2ray','vmess'):
            extra='<div class="notice">UUID: <code>%s</code><br>VMess: <code>vmess://%s</code></div>'%(html_escape(pw),html_escape(pw))
        return self.send(200,body=tpl('account.html',u,'Cuenta',USERNAME=html_escape(a['username']),TYPE=html_escape(a['type']),PASSWORD=html_escape(pw),EXPIRATION=html_escape(a['expiration'] or '—'),LIMIT=a['ip_limit'],ONLINE=len(ips),IPS=', '.join(html_escape(x) for x in ips) if ips else '',ID=a['id'],EXTRA=extra,SERVER=html_escape(server_domain())))
    def account_create_page(self,u):
        if not u:return self.redirect('/login')
        return self.send(200,body=tpl('account_create.html',u,'Crear cuenta',SSH_DAYS=quota('ssh')[0],SSH_LIMIT=quota('ssh')[1],V2_DAYS=quota('v2ray')[0],V2_LIMIT=quota('v2ray')[1]))
    def account_create(self,u,d):
        if not u:return self.send(403,body='403')
        typ=self.val(d,'type','ssh');user=self.val(d,'username').lower();pw=self.val(d,'password');days,limit=quota('v2ray' if typ=='v2ray' else 'ssh')
        if u['role']=='user':
            if not pw or not safe_username(user):return self.send(400,body=page('Crear cuenta','<div class="notice bad">Datos inválidos.</div>',u))
        else:
            if not pw:pw=secrets.token_urlsafe(6)
        ok,exp,extra=(create_v2ray_account(user,pw,days,limit) if typ=='v2ray' else create_ssh_account(user,pw,days,limit))
        if not ok:return self.send(400,body=page('Crear cuenta','<div class="notice bad">%s</div>'%html_escape(exp),u))
        if typ=='v2ray': pw=extra
        c=db();c.execute('INSERT INTO accounts(user_id,username,type,credential,expiration,ip_limit,created_at) VALUES(?,?,?,?,?,?,?)',(u['id'] if u['role']=='user' else self.ensure_admin_owner(c),user,typ,crypt_credential(extra or pw),exp,limit,datetime.now().isoformat(timespec='seconds')));c.commit();aid=c.execute('SELECT last_insert_rowid()').fetchone()[0];c.close()
        return self.send(200,body=tpl('account_created.html',u,'Cuenta creada',USERNAME=html_escape(user),PASSWORD=html_escape(pw),EXPIRATION=html_escape(display_date(exp)),DAYS=days,LIMIT=limit,TYPE=html_escape(typ.upper()),SERVER=html_escape(server_domain()),IP=html_escape(server_ip()),UUID=html_escape(extra or ''),ACCOUNT_ID=aid,V2INFO=('<div class=\"notice\">• V2Ray / VMess\n• UUID: <code>'+html_escape(extra or '')+'</code></div>' if typ=='v2ray' else '')))
    def ensure_admin_owner(self,c):
        r=c.execute("SELECT id FROM users WHERE username='__admin_owner__' LIMIT 1").fetchone()
        if r:return r['id']
        c.execute('INSERT INTO users(username,password_hash,name,created_at,referral_code) VALUES(?,?,?,?,?)',('__admin_owner__',hash_password(secrets.token_urlsafe(16)),'Administrador',datetime.now().isoformat(timespec='seconds'),'ADMIN'));return c.execute('SELECT last_insert_rowid()').fetchone()[0]
    def admin_delete_page(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        c=db();rows=c.execute('SELECT a.id,a.username,a.type,u.username owner,a.expiration FROM accounts a JOIN users u ON u.id=a.user_id ORDER BY a.id DESC').fetchall();c.close();h=''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td><form method="post" action="%s/account/delete"><input type="hidden" name="id" value="%s"><button class="btn danger">Eliminar</button></form></td></tr>'%(html_escape(x['username']),html_escape(x['owner']),html_escape(x['type']),html_escape(x['expiration'] or '—'),PREFIX,x['id']) for x in rows);return self.send(200,body=tpl('admin_delete.html',u,'Eliminar cuenta',ROWS=h))
    def account_delete(self,u,d):
        if not u or u['role']!='admin':return self.send(403,body='403')
        try:aid=int(self.val(d,'id'))
        except:return self.send(400,body='ID inválido')
        c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
        if not a:c.close();return self.not_found()
        ok=delete_account_real(a)
        if ok:c.execute('DELETE FROM accounts WHERE id=?',(aid,));c.commit()
        c.close();return self.send(200,body=page('Eliminar cuenta','<div class="notice %s">%s</div><a class="btn" href="%s/admin/accounts/delete">Volver</a>'%('oktxt' if ok else 'bad','Cuenta eliminada.' if ok else 'No se pudo eliminar la cuenta.',PREFIX),u))
    def account_renew(self,u,d):return self.send(403,body='Renovación desde esta versión: usa las cuotas configuradas por el administrador.')
    def admin(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        c=db();nu=c.execute('SELECT COUNT(*) n FROM users WHERE username!=?',( '__admin_owner__',)).fetchone()['n'];na=c.execute('SELECT COUNT(*) n FROM accounts').fetchone()['n'];online=len(all_online());users=c.execute('SELECT id,username,name,created_at,referral_points,active FROM users WHERE username!=? ORDER BY id DESC LIMIT 100',('__admin_owner__',)).fetchall();accounts=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id ORDER BY a.id DESC LIMIT 100').fetchall();c.close();ur=''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(html_escape(x['username']),html_escape(x['name']),x['referral_points'],'Activo' if x['active'] else 'Bloqueado') for x in users);ar=''.join('<tr><td><a href="%s/account?id=%s">%s</a></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(PREFIX,x['id'],html_escape(x['username']),html_escape(x['owner']),html_escape(x['type']),html_escape(x['expiration'] or '—'),len(account_online(x['username']))) for x in accounts);return self.send(200,body=tpl('admin.html',u,'Inicio',USERS=nu,ACCOUNTS=na,ONLINE=online,USERS_ROWS=ur,ACCOUNT_ROWS=ar))
    def admin_settings(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        c=cfg();q=parse_qs(urlparse(self.path).query);tab=q.get('tab',['profile'])[0];return self.send(200,body=tpl('admin_settings.html',u,'Configuración',TAB=html_escape(tab),USERNAME=html_escape(c.get('admin_username','admin')),ADS_CHECKED='checked' if c.get('ads_enabled',True) else '',ZONE=html_escape(c.get('monetag_zone','11217882')),CREATE=c.get('ads',{}).get('create',3),DELETE=c.get('ads',{}).get('delete',1),RENEW=c.get('ads',{}).get('renew',3),SITE_TITLE=html_escape(c.get('general',{}).get('site_title','KevinTech Multi Script')),SITE_DESC=html_escape(c.get('general',{}).get('site_description','')),SSH_DAYS=c.get('quotas',{}).get('ssh',{}).get('days',7),SSH_LIMIT=c.get('quotas',{}).get('ssh',{}).get('limit',1),V2_DAYS=c.get('quotas',{}).get('v2ray',{}).get('days',7),V2_LIMIT=c.get('quotas',{}).get('v2ray',{}).get('limit',1),ABOUT=html_escape(c.get('about',{}).get('about','')),PRIVACY=html_escape(c.get('about',{}).get('privacy','')),COOKIES=html_escape(c.get('about',{}).get('cookies','')),TERMS=html_escape(c.get('about',{}).get('terms',''))))
    def admin_settings_post(self,u,d):
        if not u or u['role']!='admin':return self.send(403,body='403')
        c=cfg();c['admin_username']=self.val(d,'admin_username') or c.get('admin_username','admin');pw=self.val(d,'admin_password');
        if pw:c['admin_password_hash']=hash_password(pw)
        c['ads_enabled']='ads_enabled' in d
        try:c['ads']={'create':max(0,min(20,int(self.val(d,'ad_create','3')))),'delete':max(0,min(20,int(self.val(d,'ad_delete','1')))),'renew':max(0,min(20,int(self.val(d,'ad_renew','3'))))}
        except:pass
        c['monetag_zone']=self.val(d,'monetag_zone',c.get('monetag_zone','11217882'));g=c.setdefault('general',{});g['site_title']=self.val(d,'site_title',g.get('site_title','KevinTech Multi Script'));g['site_description']=self.val(d,'site_description',g.get('site_description',''));q=c.setdefault('quotas',{})
        for t in ('ssh','v2ray'):
            try:q[t]={'days':max(1,min(3650,int(self.val(d,t+'_days','7')))),'limit':max(0,min(100,int(self.val(d,t+'_limit','1'))))}
            except:pass
        a=c.setdefault('about',{});a['about']=self.val(d,'about',a.get('about',''));a['privacy']=self.val(d,'privacy',a.get('privacy',''));a['cookies']=self.val(d,'cookies',a.get('cookies',''));a['terms']=self.val(d,'terms',a.get('terms',''));save_cfg(c);return self.redirect('/admin/settings')
    def about(self,u):
        if not u:return self.redirect('/login')
        c=cfg().get('about',{});q=parse_qs(urlparse(self.path).query);sec=q.get('section',['about'])[0];titles={'about':'Sobre nosotros','privacy':'Política de privacidad','cookies':'Política de cookies','terms':'Términos y condiciones'};return self.send(200,body=tpl('about.html',u,titles.get(sec,'Sobre nosotros'),SECTION=sec,TITLE_TEXT=titles.get(sec,'Sobre nosotros'),CONTENT=html_escape(c.get(sec,c.get('about','')))))
    def console(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        return self.send(200,body=tpl('console.html',u,'Consola',PREFIX=PREFIX))
    def console_post(self,u,d):
        if not u or u['role']!='admin':return self.send(403,body='403')
        cmd=self.val(d,'command');
        if not cmd or len(cmd)>4000:return self.send(400,body='Comando inválido')
        rc,out=shell(cmd,30);return self.send(200,'text/plain; charset=utf-8',out+'\n\n[exit %d]'%rc)
    def ads_page(self,u):return self.redirect('/account/create')
    def ad_complete(self,u,d):return self.send(400,body='Publicidad no disponible en este flujo.')

def main():
    if os.geteuid()!=0:raise SystemExit('KevinTech Web debe ejecutarse como root.')
    ensure_admin();log('WEB START %s:%s prefix=%s'%(HOST,PORT,PREFIX));ThreadingHTTPServer((HOST,PORT),Handler).serve_forever()
if __name__=='__main__':main()
