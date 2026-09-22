#!/usr/bin/env python3
import base64, hashlib, hmac, json, os, re, secrets, sqlite3, subprocess, time, uuid, shlex
from datetime import datetime, timedelta, timezone
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse

BASE = Path('/etc/kevintech')
WEB = BASE / 'web'
DATA = WEB / 'data'
DB = DATA / 'web.sqlite3'
CONFIG = DATA / 'config.json'
KEYFILE = DATA / '.credential.key'
LOG = DATA / 'web.log'
HOST = '127.0.0.1'
PORT = int(os.environ.get('KEVINTECH_WEB_PORT', '18080'))
PREFIX = os.environ.get('KEVINTECH_WEB_PREFIX', '/').strip().rstrip('/')
SESSION_TTL = 86400 * 3
TOKEN_TTL = 600


def log(msg):
    DATA.mkdir(parents=True, exist_ok=True)
    with LOG.open('a', encoding='utf-8') as f:
        f.write(datetime.now().isoformat(timespec='seconds') + ' ' + str(msg) + '\n')


def db():
    DATA.mkdir(parents=True, exist_ok=True)
    c = sqlite3.connect(DB, timeout=10)
    c.row_factory = sqlite3.Row
    c.execute('PRAGMA journal_mode=WAL')
    c.execute('PRAGMA foreign_keys=ON')
    c.executescript('''
    CREATE TABLE IF NOT EXISTS users(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL,
      referral_code TEXT UNIQUE NOT NULL,
      referred_by TEXT,
      referral_points INTEGER NOT NULL DEFAULT 0,
      referral_renews INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1
    );
    CREATE TABLE IF NOT EXISTS accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      username TEXT UNIQUE NOT NULL,
      type TEXT NOT NULL DEFAULT 'ssh',
      credential TEXT NOT NULL,
      expiration TEXT,
      ip_limit INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY, user_id INTEGER, role TEXT NOT NULL, expires REAL NOT NULL);
    CREATE TABLE IF NOT EXISTS ad_tokens(token TEXT PRIMARY KEY, user_id INTEGER NOT NULL, action TEXT NOT NULL, account_id INTEGER, expires REAL NOT NULL, completed INTEGER NOT NULL DEFAULT 0, payload TEXT NOT NULL DEFAULT '{}');
    CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ''')
    c.commit()
    return c


def cfg():
    DATA.mkdir(parents=True, exist_ok=True)
    if not CONFIG.exists():
        CONFIG.write_text(json.dumps({'admin_username':'admin','admin_password_hash':'','secret':secrets.token_hex(32),'ads_enabled':True,'ad_provider':'monetag','monetag_zone':'11217882','ads':{'create':3,'delete':1,'renew':3},'server_prefix':PREFIX}, indent=2), encoding='utf-8')
    try: return json.loads(CONFIG.read_text(encoding='utf-8'))
    except Exception: return {}


def save_cfg(c):
    CONFIG.write_text(json.dumps(c, indent=2, ensure_ascii=False), encoding='utf-8')
    os.chmod(CONFIG, 0o600)


def hash_password(pw, salt=None):
    salt = salt or secrets.token_bytes(16)
    h = hashlib.scrypt(pw.encode(), salt=salt, n=2**14, r=8, p=1)
    return 'scrypt$' + base64.urlsafe_b64encode(salt).decode() + '$' + base64.urlsafe_b64encode(h).decode()


def verify_password(pw, stored):
    try:
        _, s, h = stored.split('$', 2)
        salt = base64.urlsafe_b64decode(s.encode()); expected = base64.urlsafe_b64decode(h.encode())
        got = hashlib.scrypt(pw.encode(), salt=salt, n=2**14, r=8, p=1)
        return hmac.compare_digest(got, expected)
    except Exception: return False


def credential_key():
    if not KEYFILE.exists():
        KEYFILE.write_bytes(secrets.token_bytes(32)); os.chmod(KEYFILE, 0o600)
    return KEYFILE.read_bytes()


def crypt_credential(text):
    # AES-256 via the system openssl binary; no Python dependency required.
    try:
        p = subprocess.run(['openssl','enc','-aes-256-cbc','-a','-A','-salt','-pbkdf2','-iter','120000','-pass','file:'+str(KEYFILE)], input=text.encode(), capture_output=True, timeout=5)
        if p.returncode == 0: return 'openssl$' + p.stdout.decode().strip()
    except Exception: pass
    return 'plain$' + text


def decrypt_credential(value):
    try:
        if value.startswith('openssl$'):
            p = subprocess.run(['openssl','enc','-d','-aes-256-cbc','-a','-A','-pbkdf2','-iter','120000','-pass','file:'+str(KEYFILE)], input=value[8:].encode(), capture_output=True, timeout=5)
            if p.returncode == 0: return p.stdout.decode()
        if value.startswith('plain$'): return value[6:]
    except Exception: pass
    return ''


def ensure_admin():
    c = cfg(); changed=False
    credential_key()
    if not c.get('secret'): c['secret']=secrets.token_hex(32); changed=True
    if not c.get('admin_username'): c['admin_username']='admin'; changed=True
    if not c.get('admin_password_hash'):
        pw=os.environ.get('WEB_ADMIN_PASS') or secrets.token_urlsafe(12)
        c['admin_password_hash']=hash_password(pw); c['initial_admin_password']=pw; changed=True
    for k,v in {'ads_enabled':True,'ad_provider':'monetag','monetag_zone':'11217882','ads':{'create':3,'delete':1,'renew':3},'server_prefix':PREFIX}.items():
        if k not in c: c[k]=v; changed=True
    if changed: save_cfg(c)
    c=db(); c.close()


def now(): return time.time()
def iso(dt): return dt.strftime('%Y-%m-%d')

def safe_username(s): return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}', s or ''))
def safe_web_username(s): return bool(re.fullmatch(r'[A-Za-z0-9_.-]{3,32}', s or ''))

def account_online(username):
    try:
        out=subprocess.run(['ss','-tnp','state','established'],capture_output=True,text=True,timeout=5).stdout
        rows=[]
        for line in out.splitlines():
            if ':22' not in line: continue
            m=re.search(r'users:\(\("sshd",pid=(\d+)', line)
            if not m: continue
            pid=m.group(1)
            u=subprocess.run(['ps','-o','user=','-p',pid],capture_output=True,text=True,timeout=2).stdout.strip()
            if u != username: continue
            parts=line.split(); peer=parts[4] if len(parts)>4 else '—'
            ip=peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer
            rows.append(ip)
        return sorted(set(rows))
    except Exception: return []


def all_online():
    try:
        out=subprocess.run(['ss','-tnp','state','established'],capture_output=True,text=True,timeout=5).stdout
        rows=[]
        for line in out.splitlines():
            if ':22' not in line: continue
            m=re.search(r'users:\(\("sshd",pid=(\d+)', line)
            if not m: continue
            pid=m.group(1); u=subprocess.run(['ps','-o','user=','-p',pid],capture_output=True,text=True,timeout=2).stdout.strip()
            if not u or u in ('root','sshd','users'): continue
            parts=line.split(); peer=parts[4] if len(parts)>4 else '—'; ip=peer.rsplit(':',1)[0].strip('[]') if ':' in peer else peer
            rows.append((u,ip))
        return rows
    except Exception: return []


def shell(cmd, timeout=30):
    try:
        p=subprocess.run(cmd, shell=True, executable='/bin/bash', capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr).strip()
    except subprocess.TimeoutExpired: return 124, 'Tiempo agotado.'
    except Exception as e: return 1, str(e)


def create_ssh_account(username,password,days,limit):
    if not safe_username(username): return False,'Usuario inválido.'
    if len(password)<4: return False,'La contraseña debe tener al menos 4 caracteres.'
    if days < 1 or days > 3650: return False,'Días inválidos.'
    if limit < 0 or limit > 100: return False,'Límite inválido.'
    if subprocess.run(['id',username],capture_output=True).returncode==0: return False,'Ese usuario ya existe en el VPS.'
    exp=iso(datetime.now()+timedelta(days=days))
    rc,out=shell('useradd -e %s -M -s /usr/sbin/nologin %s && printf %s | chpasswd' % (shlex.quote(exp), shlex.quote(username), shlex.quote(username+':'+password)), 15)
    if rc!=0:
        shell('userdel -f %s 2>/dev/null || true' % shlex.quote(username), 10)
        return False,out or 'No se pudo crear el usuario.'
    limits=BASE/'limits.conf'; lines=[]
    if limits.exists(): lines=limits.read_text(errors='ignore').splitlines()
    lines=[x for x in lines if not x.startswith(username+':')]
    lines.append(f'{username}:{limit}')
    limits.write_text('\n'.join(lines)+'\n'); os.chmod(limits,0o600)
    return True,exp


def delete_ssh(username):
    if not safe_username(username): return False,'Usuario inválido.'
    if username in ('root','nobody','daemon','www-data'): return False,'Cuenta protegida.'
    rc,out=shell('userdel -r -f %s' % shlex.quote(username),15)
    limits=BASE/'limits.conf'
    if limits.exists(): limits.write_text('\n'.join(x for x in limits.read_text(errors='ignore').splitlines() if not x.startswith(username+':'))+'\n'); os.chmod(limits,0o600)
    return rc==0,out or ('Cuenta eliminada.' if rc==0 else 'No se pudo eliminar la cuenta.')


def renew_ssh(username,days):
    if not safe_username(username) or subprocess.run(['id',username],capture_output=True).returncode!=0: return False,'Cuenta no encontrada.'
    if days<1 or days>3650:return False,'Días inválidos.'
    exp=iso(datetime.now()+timedelta(days=days)); rc,out=shell('chage -E %s %s' % (shlex.quote(exp),shlex.quote(username)),10)
    return rc==0, exp if rc==0 else out


def ad_required(action):
    c=cfg();
    if not c.get('ads_enabled',True): return 0
    try:return max(0,int(c.get('ads',{}).get(action,1)))
    except:return 1


def issue_ad(c,user_id,action,account_id=None,payload=None,completed=0):
    n=ad_required(action)
    if n<=0:return None
    token=secrets.token_urlsafe(24)
    c.execute('INSERT INTO ad_tokens(token,user_id,action,account_id,expires,completed,payload) VALUES(?,?,?,?,?,?,?)',(token,user_id,action,account_id,now()+TOKEN_TTL,completed,json.dumps(payload or {},ensure_ascii=False)));c.commit();return token


def get_ad(c,token,user_id):
    return c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND expires>?',(token,user_id,now())).fetchone()


def consume_pass(c,token,user_id):
    row=c.execute('SELECT * FROM ad_tokens WHERE token=? AND user_id=? AND expires>? AND completed=-1',(token,user_id,now())).fetchone()
    if not row:return None
    c.execute('DELETE FROM ad_tokens WHERE token=?',(token,));c.commit();return row

def page(title, body, user=None):
    nav = ''
    if user:
        nav = '<a href="%s/dashboard">Panel</a><a href="%s/profile">Perfil</a><a href="%s/online">Online</a><a href="%s/referrals">Referidos</a>' % (PREFIX, PREFIX, PREFIX, PREFIX)
        if user.get('role') == 'admin': nav = '<a href="%s/admin">Admin</a><a href="%s/console">Consola</a>' % (PREFIX, PREFIX)
        nav += '<a href="%s/logout">Salir</a>' % PREFIX
    else: nav = '<a href="%s/login">Ingresar</a><a href="%s/register">Registrarse</a>' % (PREFIX, PREFIX)
    template = WEB / 'templates' / 'base.html'
    try: html = template.read_text(encoding='utf-8')
    except Exception: html = '<!doctype html><html><head><title>{{TITLE}}</title></head><body>{{NAV}}{{BODY}}</body></html>'
    return html.replace('{{TITLE}}', html_escape(title)).replace('{{NAV}}', nav).replace('{{BODY}}', body)

def form_page(title,action,fields,button='Continuar',extra=''):
    fs=''.join('<label>%s</label><input class="input" name="%s" type="%s" %s>'%(lab,name,typ,attrs) for name,lab,typ,attrs in fields)
    return page(title,'<div class="card form"><h2>%s</h2><form method="post" action="%s"><input type="hidden" name="csrf" value="%s">%s%s<button class="btn primary" type="submit">%s</button></form></div>'%(title,action,html_escape(CSRF_PLACEHOLDER),fs,extra,button))


def html_escape(s):
    return str(s).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;')


class Handler(BaseHTTPRequestHandler):
    server_version='KevinTechWeb/1.0'
    def log_message(self,fmt,*args): pass

    def route_path(self):
        p=urlparse(self.path).path
        if PREFIX and p.startswith(PREFIX): p=p[len(PREFIX):] or '/'
        return p

    def do_HEAD(self):
        self.send(200, 'text/html; charset=utf-8', '')

    def send(self,status=200,ctype='text/html; charset=utf-8',body=''):
        b=body.encode() if isinstance(body,str) else body
        self.send_response(status);self.send_header('Content-Type',ctype);self.send_header('Content-Length',str(len(b)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(b)

    def redirect(self,to): self.send_response(303);self.send_header('Location',PREFIX+to if to.startswith('/') else to);self.send_header('Content-Length','0');self.end_headers()

    def cookies(self):
        c=cookies.SimpleCookie(); c.load(self.headers.get('Cookie','')); return c

    def csrf(self):
        c=self.cookies().get('kt_csrf');
        if not c:
            v=secrets.token_urlsafe(18); out=cookies.SimpleCookie();out['kt_csrf']=v;out['kt_csrf']['path']=PREFIX or '/';out['kt_csrf']['secure']=True;out['kt_csrf']['httponly']=True;out['kt_csrf']['samesite']='Strict';self.extra_cookie=out.output(header='').strip();return v
        return c.value

    def session(self):
        c=self.cookies().get('kt_session');
        if not c:return None
        con=db(); row=con.execute('SELECT * FROM sessions WHERE token=? AND expires>?',(c.value,now())).fetchone()
        if not row:con.close();return None
        if row['role']=='admin': u={'role':'admin','username':cfg().get('admin_username','admin')}
        else:
            x=con.execute('SELECT * FROM users WHERE id=? AND active=1',(row['user_id'],)).fetchone();u=dict(x) if x else None
            if u:u['role']='user'
        con.close();return u

    def set_session(self,user_id,role):
        tok=secrets.token_urlsafe(32); con=db();con.execute('DELETE FROM sessions WHERE expires<?',(now(),));con.execute('INSERT INTO sessions VALUES(?,?,?,?)',(tok,user_id,role,now()+SESSION_TTL));con.commit();con.close();c=cookies.SimpleCookie();c['kt_session']=tok;c['kt_session']['path']=PREFIX or '/';c['kt_session']['httponly']=True;c['kt_session']['secure']=True;c['kt_session']['samesite']='Lax';self.extra_cookie=c.output(header='').strip()

    def require(self,role=None):
        u=self.session()
        if not u:return None
        if role and u.get('role')!=role:return None
        return u

    def read_post(self):
        n=int(self.headers.get('Content-Length','0')); raw=self.rfile.read(min(n,1024*1024)); return parse_qs(raw.decode(errors='ignore'),keep_blank_values=True)
    def val(self,d,k,default=''):return d.get(k,[default])[0].strip()


    def do_GET(self):
        p=self.route_path(); u=self.session()
        if p=='/': return self.redirect('/dashboard' if u else '/login')
        if p=='/login': return self.login_page()
        if p=='/register': return self.register_page()
        if p=='/logout':
            c=self.cookies().get('kt_session');
            if c:
                con=db();con.execute('DELETE FROM sessions WHERE token=?',(c.value,));con.commit();con.close()
            return self.redirect('/login')
        if p=='/ads': return self.ads_page(u)
        if p=='/dashboard': return self.dashboard(u)
        if p=='/profile': return self.profile(u)
        if p=='/online': return self.online(u)
        if p=='/referrals': return self.referrals(u)
        if p=='/account': return self.account_detail(u)
        if p=='/admin': return self.admin(u)
        if p=='/console': return self.console(u)
        if p=='/admin/settings': return self.admin_settings(u)
        if p=='/static/health': return self.send(200,'application/json',json.dumps({'ok':True,'time':time.time()}))
        return self.send(404,body='404')

    def do_POST(self):
        p=self.route_path(); d=self.read_post(); u=self.session()
        # Cookie handling is done by setting headers directly for auth endpoints.
        if p=='/login': return self.login_post(d)
        if p=='/register': return self.register_post(d)
        if p=='/profile': return self.profile_post(u,d)
        if p=='/referrals/redeem': return self.referral_redeem(u,d)
        if p=='/account/create': return self.account_create(u,d)
        if p=='/account/delete': return self.account_delete(u,d)
        if p=='/account/renew': return self.account_renew(u,d)
        if p=='/ads/complete': return self.ad_complete(u,d)
        if p=='/admin/settings': return self.admin_settings_post(u,d)
        if p=='/console': return self.console_post(u,d)
        return self.send(404,body='404')

    def auth_cookie_redirect(self,to):
        self.send_response(303);self.send_header('Location',PREFIX+to);self.send_header('Set-Cookie',self.extra_cookie);self.send_header('Content-Length','0');self.end_headers()

    def login_page(self,msg=''):
        body='<div class="card form"><h2>Ingresar</h2>%s<form method="post"><label>Usuario</label><input class="input" name="username" required><label>Contraseña</label><input class="input" name="password" type="password" required><button class="btn primary">Ingresar</button></form><p class="muted">También puedes iniciar como administrador con las credenciales configuradas en el instalador.</p><a href="%s/register">Crear cuenta</a></div>'%(msg,PREFIX)
        return self.send(200,body=page('Ingreso',body))

    def login_post(self,d):
        user=self.val(d,'username');pw=self.val(d,'password');c=db(); admin=cfg(); ok=False; role=''
        if hmac.compare_digest(user,admin.get('admin_username','')) and verify_password(pw,admin.get('admin_password_hash','')):ok=True;role='admin';uid=0
        else:
            r=c.execute('SELECT * FROM users WHERE username=? AND active=1',(user,)).fetchone()
            if r and verify_password(pw,r['password_hash']):ok=True;role='user';uid=r['id']
        c.close()
        if not ok:return self.login_page('<div class="notice bad">Usuario o contraseña incorrectos.</div>')
        self.set_session(uid,role); return self.auth_cookie_redirect('/admin' if role=='admin' else '/dashboard')

    def register_page(self,msg=''):
        q=parse_qs(urlparse(self.path).query); ref=html_escape(q.get('ref',[''])[0])
        body='<div class="card form"><h2>Crear cuenta web</h2>%s<form method="post"><label>Nombre</label><input class="input" name="name" required><label>Usuario</label><input class="input" name="username" required pattern="[A-Za-z0-9_.-]{3,32}"><label>Contraseña</label><input class="input" name="password" type="password" minlength="6" required><label>Código de referido (opcional)</label><input class="input" name="ref" value="%s"><button class="btn primary">Registrarme</button></form><p><a href="%s/login">Ya tengo cuenta</a></p></div>'%(msg,ref,PREFIX)
        return self.send(200,body=page('Registro',body))

    def register_post(self,d):
        name=self.val(d,'name');user=self.val(d,'username');pw=self.val(d,'password');ref=self.val(d,'ref')
        if not name or not safe_web_username(user) or len(pw)<6:return self.register_page('<div class="notice bad">Datos inválidos. La contraseña debe tener 6 caracteres o más.</div>')
        c=db()
        if c.execute('SELECT 1 FROM users WHERE username=?',(user,)).fetchone():c.close();return self.register_page('<div class="notice bad">Ese usuario web ya existe.</div>')
        code=secrets.token_urlsafe(7); referred=None
        if ref:
            rr=c.execute('SELECT id,username FROM users WHERE referral_code=? AND active=1',(ref,)).fetchone()
            if rr:referred=rr['id']
        c.execute('INSERT INTO users(username,password_hash,name,created_at,referral_code,referred_by) VALUES(?,?,?,?,?,?)',(user,hash_password(pw),name,datetime.now().isoformat(timespec='seconds'),code,referred));uid=c.execute('SELECT last_insert_rowid()').fetchone()[0]
        if referred:c.execute('UPDATE users SET referral_points=referral_points+1 WHERE id=?',(referred,))
        c.commit();c.close();self.set_session(uid,'user');return self.auth_cookie_redirect('/dashboard')

    def dashboard(self,u):
        if not u:return self.redirect('/login')
        if u['role']=='admin':return self.admin(u)
        c=db(); accounts=c.execute('SELECT * FROM accounts WHERE user_id=? ORDER BY id DESC',(u['id'],)).fetchall(); online=sum(len(account_online(x['username'])) for x in accounts); pts=u['referral_points']
        cards=''.join('<div class="card"><h3>👤 %s</h3><p class="muted">Tipo: %s · Expira: %s</p><p>Online: <b class="oktxt">%s</b></p><p><span class="tag">Límite %s IP</span></p><a class="btn" href="%s/account?id=%s">Ver</a> <a class="btn primary" href="%s/ads?action=renew&account=%s">Renovar</a> <a class="btn danger" href="%s/ads?action=delete&account=%s">Eliminar</a></div>'%(html_escape(a['username']),html_escape(a['type']),html_escape(a['expiration'] or '—'),len(account_online(a['username'])),a['ip_limit'],PREFIX,a['id'],PREFIX,a['id'],PREFIX,a['id']) for a in accounts)
        c.close()
        body='<div class="hero"><h1>Mi panel</h1><p class="muted">Crea y administra tus cuentas desde el navegador.</p></div><div class="grid"><div class="card"><div class="stat">%d</div><div class="muted">Cuentas</div></div><div class="card"><div class="stat">%d</div><div class="muted">Conexiones online</div></div><div class="card"><div class="stat">%d</div><div class="muted">Puntos de referido</div></div></div><br><div class="grid"><div class="card"><h3>Crear cuenta</h3><p class="muted">La operación puede requerir anuncios según la configuración.</p><a class="btn primary" href="%s/ads?action=create">➕ Crear</a></div><div class="card"><h3>Referidos</h3><p>Comparte tu código: <code>%s</code></p><a class="btn" href="%s/referrals">Ver programa</a></div></div><br><h2>Mis cuentas</h2><div class="grid">%s</div>'%(len(accounts),online,pts,PREFIX,html_escape(u['referral_code']),PREFIX,cards or '<div class="card">No tienes cuentas todavía.</div>')
        return self.send(200,body=page('Panel',body,u))

    def profile(self,u):
        if not u:return self.redirect('/login')
        if u['role']=='admin':return self.admin_settings(u)
        body='<div class="card form"><h2>Mi perfil</h2><p><b>Nombre:</b> %s</p><p><b>Usuario:</b> %s</p><p><b>Registrado:</b> %s</p><p><b>Referidos:</b> %s</p><p><b>Código:</b> <code>%s</code></p><hr><form method="post"><label>Nuevo nombre</label><input class="input" name="name" value="%s"><label>Nueva contraseña</label><input class="input" name="password" type="password" minlength="6"><button class="btn primary">Guardar cambios</button></form></div>'%(html_escape(u['name']),html_escape(u['username']),u['created_at'],u['referral_points'],html_escape(u['referral_code']),html_escape(u['name']))
        return self.send(200,body=page('Perfil',body,u))

    def profile_post(self,u,d):
        if not u or u['role']!='user':return self.send(403,body='403')
        name=self.val(d,'name') or u['name'];pw=self.val(d,'password');c=db()
        if pw:c.execute('UPDATE users SET name=?,password_hash=? WHERE id=?',(name,hash_password(pw),u['id']))
        else:c.execute('UPDATE users SET name=? WHERE id=?',(name,u['id']))
        c.commit();c.close();return self.redirect('/profile')

    def online(self,u):
        if not u:return self.redirect('/login')
        c=db(); rows=all_online() if u['role']=='admin' else []
        if u['role']=='user':
            names={r['username'] for r in c.execute('SELECT username FROM accounts WHERE user_id=?',(u['id'],)).fetchall()}; rows=[x for x in all_online() if x[0] in names]
        body='<div class="card"><h2>🟢 Usuarios online</h2><table class="table"><tr><th>Usuario</th><th>IP</th></tr>%s</table></div>'%''.join('<tr><td>%s</td><td>%s</td></tr>'%(html_escape(a),html_escape(b)) for a,b in rows) or '<tr><td colspan="2">No hay conexiones SSH activas.</td></tr>'
        c.close();return self.send(200,body=page('Online',body,u))

    def referrals(self,u):
        if not u or u['role']!='user':return self.redirect('/login')
        c=db();accounts=c.execute('SELECT id,username,expiration FROM accounts WHERE user_id=? ORDER BY username',(u['id'],)).fetchall();c.close()
        opts=''.join('<option value="%s">%s</option>'%(a['id'],html_escape(a['username'])) for a in accounts)
        redeem='<div class="card form"><h3>🎁 Canjear referidos</h3><p>Con 3 puntos puedes añadir 7 días a una cuenta.</p><form method="post" action="%s/referrals/redeem"><select class="input" name="account_id" required>%s</select><button class="btn primary">Canjear 3 puntos</button></form></div>'%(PREFIX,opts) if accounts else '<div class="card"><h3>🎁 Recompensa</h3><p class="muted">Crea una cuenta para poder canjear puntos.</p></div>'
        body='<div class="grid"><div class="card"><div class="stat">%s</div><div class="muted">Puntos</div></div><div class="card"><h3>Tu enlace</h3><input class="input" readonly value="%s/register?ref=%s"><p class="muted">Cada registro válido con tu código suma un punto.</p></div></div><br>%s'%(u['referral_points'],PREFIX,html_escape(u['referral_code']),redeem)
        return self.send(200,body=page('Referidos',body,u))

    def referral_redeem(self,u,d):
        if not u or u['role']!='user':return self.redirect('/login')
        try:aid=int(self.val(d,'account_id'))
        except:return self.send(400,body='Cuenta inválida')
        c=db();me=c.execute('SELECT referral_points FROM users WHERE id=?',(u['id'],)).fetchone();a=c.execute('SELECT * FROM accounts WHERE id=? AND user_id=?',(aid,u['id'])).fetchone()
        if not me or me['referral_points']<3 or not a:c.close();return self.send(400,body=page('Referidos','<div class="notice bad">Necesitas 3 puntos y una cuenta propia.</div>',u))
        ok,msg=renew_ssh(a['username'],7)
        if ok:
            c.execute('UPDATE users SET referral_points=referral_points-3, referral_renews=referral_renews+1 WHERE id=?',(u['id'],));c.execute('UPDATE accounts SET expiration=? WHERE id=?',(msg,aid));c.commit()
        c.close();return self.send(200,body=page('Referidos','<div class="notice %s">%s</div><a class="btn" href="%s/referrals">Volver</a>'%('oktxt' if ok else 'bad',html_escape('Canje realizado: '+msg if ok else msg),PREFIX),u))

    def account_detail(self,u):
        if not u:return self.redirect('/login')
        try:aid=int(parse_qs(urlparse(self.path).query).get('id',['0'])[0])
        except:aid=0
        c=db(); a=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id WHERE a.id=?',(aid,)).fetchone()
        if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body='Cuenta no encontrada')
        pw=decrypt_credential(a['credential']);ips=account_online(a['username']);c.close()
        body='<div class="card"><h2>👤 %s</h2><p>Tipo: <b>%s</b></p><p>Contraseña: <code>%s</code></p><p>Expira: <b>%s</b></p><p>Límite: <b>%s</b> IP</p><p>Online: <b class="oktxt">%d</b> %s</p><a class="btn primary" href="%s/ads?action=renew&account=%s">Renovar</a> <a class="btn" href="%s/dashboard">Volver</a></div>'%(html_escape(a['username']),html_escape(a['type']),html_escape(pw),html_escape(a['expiration'] or '—'),a['ip_limit'],len(ips),', '.join(html_escape(x) for x in ips) if ips else '',PREFIX,a['id'],PREFIX)
        return self.send(200,body=page('Cuenta',body,u))

    def account_create(self,u,d):
        if not u or u['role']!='user':return self.send(403,body='403')
        payload={'username':self.val(d,'username').lower(),'password':self.val(d,'password'),'days':self.val(d,'days','7'),'limit':self.val(d,'limit','1')}
        passed=self.ad_is_completed(u,d,'create',payload=payload)
        if passed is None:return
        if isinstance(passed,dict):payload=passed
        user=payload.get('username','').lower();pw=payload.get('password','')
        try:days=int(payload.get('days','7'));limit=int(payload.get('limit','1'))
        except:return self.send(400,body='Datos inválidos')
        ok,msg=create_ssh_account(user,pw,days,limit)
        if not ok:return self.send(400,body=page('Error','<div class="notice bad">%s</div>'%html_escape(msg),u))
        c=db();c.execute('INSERT INTO accounts(user_id,username,type,credential,expiration,ip_limit,created_at) VALUES(?,?,?,?,?,?,?)',(u['id'],user,'ssh',crypt_credential(pw),msg,limit,datetime.now().isoformat(timespec='seconds')));c.commit();aid=c.execute('SELECT last_insert_rowid()').fetchone()[0];c.close()
        return self.redirect('/account?id=%d'%aid)

    def account_delete(self,u,d):
        if not u:return self.send(403,body='403')
        try:aid=int(self.val(d,'id'))
        except:return self.send(400,body='ID inválido')
        c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
        if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body='Cuenta no encontrada')
        if u['role']!='admin':
            passed=self.ad_is_completed(u,d,'delete',aid,{'id':aid})
            if passed is None:c.close();return
        ok,msg=delete_ssh(a['username']);c.execute('DELETE FROM accounts WHERE id=?',(aid,));c.commit();c.close();return self.send(200,body=page('Eliminar','<div class="notice %s">%s</div><a class="btn" href="%s/dashboard">Volver</a>'%('oktxt' if ok else 'bad',html_escape(msg or 'Operación terminada.'),PREFIX),u))

    def account_renew(self,u,d):
        if not u:return self.send(403,body='403')
        try:aid=int(self.val(d,'id'));days=int(self.val(d,'days','7'))
        except:return self.send(400,body='Datos inválidos')
        c=db();a=c.execute('SELECT * FROM accounts WHERE id=?',(aid,)).fetchone()
        if not a or (u['role']!='admin' and a['user_id']!=u['id']):c.close();return self.send(404,body='Cuenta no encontrada')
        if u['role']!='admin':
            passed=self.ad_is_completed(u,d,'renew',aid,{'id':aid,'days':days})
            if passed is None:c.close();return
            if isinstance(passed,dict):
                try: days=int(passed.get('days',days))
                except: pass
        ok,msg=renew_ssh(a['username'],days)
        if ok:c.execute('UPDATE accounts SET expiration=? WHERE id=?',(msg,aid));c.commit()
        c.close();return self.send(200,body=page('Renovar','<div class="notice %s">%s</div><a class="btn" href="%s/account?id=%s">Volver</a>'%('oktxt' if ok else 'bad',html_escape(msg),PREFIX,aid),u))

    def ad_is_completed(self,u,d,action,aid=None,payload=None):
        token=self.val(d,'ad_token')
        if token:
            c=db();r=consume_pass(c,token,u['id']);c.close()
            if r and r['action']==action and (aid is None or r['account_id']==aid):
                try:return json.loads(r['payload'] or '{}')
                except:return {}
        n=ad_required(action)
        if n<=0:return payload if payload is not None else True
        c=db();tok=issue_ad(c,u['id'],action,aid,payload or {},0);c.close();self.redirect('/ads?token=%s'%tok);return None

    def ads_page(self,u):
        if not u or u['role']!='user':return self.redirect('/login')
        q=parse_qs(urlparse(self.path).query); action=q.get('action',[''])[0]; token=q.get('token',[''])[0]; adpass=q.get('adpass',[''])[0]
        if token:
            c=db();row=get_ad(c,token,u['id']);c.close()
            if not row:return self.send(400,body=page('Publicidad','<div class="notice bad">Este anuncio expiró. Vuelve a intentar la operación.</div>',u))
            n=ad_required(row['action']); zone=html_escape(str(cfg().get('monetag_zone','11217882'))); provider=cfg().get('ad_provider','monetag')
            complete='%s/ads/complete'%PREFIX; nexturl='%s/dashboard'%PREFIX
            if row['account_id']:nexturl='%s/account?id=%s'%(PREFIX,row['account_id'])
            body='''<div class="card" style="max-width:520px;margin:auto;text-align:center"><h2>💰 Anuncio %s</h2><p class="muted">Completa la publicidad para continuar con: <b>%s</b>.</p><button id="ad" class="btn primary">▶ Ver anuncio</button><p id="status" class="muted"></p><form id="done" method="post" action="%s"><input type="hidden" name="token" value="%s"></form></div><script src="https://libtl.com/sdk.js" data-zone="%s" data-sdk="show_%s"></script><script>const b=document.getElementById('ad'),s=document.getElementById('status');b.onclick=async()=>{b.disabled=true;s.textContent='Cargando publicidad...';try{const fn=window['show_%s'];if(typeof fn!== 'function')throw Error('SDK no disponible');await fn();s.textContent='Anuncio completado';document.getElementById('done').submit()}catch(e){s.textContent='No se pudo cargar el anuncio. Intenta nuevamente.';b.disabled=false}}</script>'''%(n,html_escape(row['action']),complete,html_escape(token),zone,zone,zone)
            return self.send(200,body=page('Publicidad',body,u))
        if action=='delete':
            try:aid=int(q.get('account',['0'])[0])
            except:aid=0
            c=db();a=c.execute('SELECT * FROM accounts WHERE id=? AND user_id=?',(aid,u['id'])).fetchone();passrow=get_ad(c,adpass,u['id']) if adpass else None;c.close()
            if not a:return self.send(404,body='Cuenta no encontrada')
            body='<div class="card form"><h2>🗑️ Eliminar cuenta</h2><p>Cuenta: <b>%s</b></p><p class="muted">La eliminación es permanente.</p><form method="post" action="%s/account/delete"><input type="hidden" name="id" value="%s"><input type="hidden" name="ad_token" value="%s"><button class="btn danger">Eliminar cuenta</button></form></div>'%(html_escape(a['username']),PREFIX,aid,html_escape(adpass))
        elif action=='create':
            c=db();passrow=get_ad(c,adpass,u['id']) if adpass else None;c.close(); payload=json.loads(passrow['payload']) if passrow else {}
            body='<div class="card form"><h2>➕ Crear cuenta</h2><form method="post" action="%s/account/create"><input type="hidden" name="ad_token" value="%s"><label>Usuario</label><input class="input" name="username" value="%s" required pattern="[a-z][a-z0-9_-]{2,31}"><label>Contraseña</label><input class="input" name="password" value="%s" type="text" required minlength="4"><label>Días</label><input class="input" name="days" type="number" value="%s" min="1" max="3650"><label>Límite IP</label><input class="input" name="limit" type="number" value="%s" min="0" max="100"><button class="btn primary">Crear cuenta</button></form></div>'%(PREFIX,html_escape(adpass),html_escape(payload.get('username','')),html_escape(payload.get('password','')),html_escape(payload.get('days','7')),html_escape(payload.get('limit','1')))
        else:
            try:aid=int(q.get('account',['0'])[0])
            except:aid=0
            c=db();a=c.execute('SELECT * FROM accounts WHERE id=? AND user_id=?',(aid,u['id'])).fetchone();c.close()
            if not a:return self.send(404,body='Cuenta no encontrada')
            body='<div class="card form"><h2>♻️ Renovar cuenta</h2><p>Cuenta: <b>%s</b></p><form method="post" action="%s/account/renew"><input type="hidden" name="id" value="%s"><input type="hidden" name="ad_token" value="%s"><label>Días</label><input class="input" name="days" type="number" value="7" min="1" max="3650"><button class="btn primary">Renovar cuenta</button></form></div>'%(html_escape(a['username']),PREFIX,aid,html_escape(adpass))
        return self.send(200,body=page('Publicidad',body,u))

    def ad_complete(self,u,d):
        if not u or u['role']!='user':return self.send(403,body='403')
        token=self.val(d,'token');c=db();r=get_ad(c,token,u['id'])
        if not r or r['completed']<0:c.close();return self.send(400,body=page('Publicidad','<div class="notice bad">Token inválido o expirado.</div>',u))
        try:payload=json.loads(r['payload'] or '{}')
        except:payload={}
        step=r['completed']+1;required=ad_required(r['action'])
        c.execute('DELETE FROM ad_tokens WHERE token=?',(token,))
        if step<required:
            nxt=issue_ad(c,u['id'],r['action'],r['account_id'],payload,step)
            c.close();return self.redirect('/ads?token=%s'%nxt)
        passcode=issue_ad(c,u['id'],r['action'],r['account_id'],payload,-1)
        c.close()
        if r['action']=='create':return self.redirect('/ads?action=create&adpass=%s'%passcode)
        return self.redirect('/ads?action=%s&account=%s&adpass=%s'%(r['action'],r['account_id'] or '',passcode))

    def admin(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        c=db();nu=c.execute('SELECT COUNT(*) n FROM users').fetchone()['n'];na=c.execute('SELECT COUNT(*) n FROM accounts').fetchone()['n'];online=len(all_online()); users=c.execute('SELECT id,username,name,created_at,referral_points,active FROM users ORDER BY id DESC LIMIT 100').fetchall(); accounts=c.execute('SELECT a.*,u.username owner FROM accounts a JOIN users u ON u.id=a.user_id ORDER BY a.id DESC LIMIT 100').fetchall();c.close()
        body='<div class="hero"><h1>Centro de administración</h1><p class="muted">Administración web y acceso a la consola del VPS.</p></div><div class="grid"><div class="card"><div class="stat">%s</div><div class="muted">Usuarios web</div></div><div class="card"><div class="stat">%s</div><div class="muted">Cuentas</div></div><div class="card"><div class="stat">%s</div><div class="muted">Online</div></div></div><br><div class="grid"><div class="card"><h3>⚙️ Configuración</h3><a class="btn" href="%s/admin/settings">Datos admin y Ads</a></div><div class="card"><h3>🖥️ Consola</h3><a class="btn primary" href="%s/console">Abrir terminal web</a></div><div class="card"><h3>🧰 Sistema</h3><p class="small">Desde la consola puedes ejecutar los menús existentes de usuarios, protocolos y herramientas sin modificar sus archivos.</p></div></div><br><div class="card"><h3>Usuarios registrados</h3><table class="table"><tr><th>Usuario</th><th>Nombre</th><th>Referidos</th><th>Estado</th></tr>%s</table></div><br><div class="card"><h3>Cuentas</h3><table class="table"><tr><th>Cuenta</th><th>Propietario</th><th>Tipo</th><th>Expira</th><th>Online</th></tr>%s</table></div>'%(nu,na,online,PREFIX,PREFIX,''.join('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(html_escape(x['username']),html_escape(x['name']),x['referral_points'],'Activo' if x['active'] else 'Bloqueado') for x in users),''.join('<tr><td><a href="%s/account?id=%s">%s</a></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>'%(PREFIX,x['id'],html_escape(x['username']),html_escape(x['owner']),html_escape(x['type']),html_escape(x['expiration'] or '—'),len(account_online(x['username'])) ) for x in accounts))
        return self.send(200,body=page('Admin',body,u))

    def admin_settings(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        c=cfg();body='<div class="card form"><h2>⚙️ Datos del administrador</h2><form method="post"><label>Usuario admin</label><input class="input" name="admin_username" value="%s"><label>Nueva contraseña (vacío = no cambiar)</label><input class="input" name="admin_password" type="password"><hr><h3>Ads</h3><label><input type="checkbox" name="ads_enabled" %s> Activar anuncios</label><label>Proveedor</label><select class="input" name="ad_provider"><option value="monetag" %s>Monetag</option></select><label>Zone ID</label><input class="input" name="monetag_zone" value="%s"><label>Ads para crear</label><input class="input" name="ad_create" type="number" min="0" max="20" value="%s"><label>Ads para eliminar</label><input class="input" name="ad_delete" type="number" min="0" max="20" value="%s"><label>Ads para renovar</label><input class="input" name="ad_renew" type="number" min="0" max="20" value="%s"><button class="btn primary">Guardar</button></form><hr><p class="small">El instalador recomienda comenzar con Monetag porque este proyecto ya trae su integración Web/Telegram preparada. Puedes cambiar proveedor/SDK en una actualización posterior.</p></div>'%(html_escape(c.get('admin_username','admin')),'checked' if c.get('ads_enabled',True) else '', 'selected' if c.get('ad_provider','monetag')=='monetag' else '',html_escape(c.get('monetag_zone','11217882')),c.get('ads',{}).get('create',3),c.get('ads',{}).get('delete',1),c.get('ads',{}).get('renew',3))
        return self.send(200,body=page('Configuración',body,u))

    def admin_settings_post(self,u,d):
        if not u or u['role']!='admin':return self.send(403,body='403')
        c=cfg();c['admin_username']=self.val(d,'admin_username') or 'admin';pw=self.val(d,'admin_password');
        if pw:c['admin_password_hash']=hash_password(pw)
        c['ads_enabled']='ads_enabled' in d;c['ad_provider']=self.val(d,'ad_provider','monetag');c['monetag_zone']=self.val(d,'monetag_zone','11217882')
        try:c['ads']={'create':max(0,min(20,int(self.val(d,'ad_create','3')))),'delete':max(0,min(20,int(self.val(d,'ad_delete','1')))),'renew':max(0,min(20,int(self.val(d,'ad_renew','3'))))}
        except:pass
        save_cfg(c);return self.redirect('/admin/settings')

    def console(self,u):
        if not u or u['role']!='admin':return self.redirect('/login')
        body="""<div class="card"><h2>🖥️ Consola VPS</h2><p class="muted">Solo administradores. Ejecuta comandos con el mismo usuario del servicio (root). No compartas estas credenciales.</p><div id="out" class="terminal">KevinTech Web Console\nListo.\n</div><div class="cmdrow"><input id="cmd" class="input" placeholder="Escribe un comando..."><button class="btn primary" onclick="run()">Ejecutar</button></div></div><script>async function run(){let x=document.getElementById('cmd'),o=document.getElementById('out'),c=x.value.trim();if(!c)return;o.textContent+='\n# '+c+'\nEjecutando...\n';x.value='';let r=await fetch('%s/console',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({command:c})});o.textContent=await r.text();o.scrollTop=o.scrollHeight}</script>"""%PREFIX
        return self.send(200,body=page('Consola',body,u))

    def console_post(self,u,d):
        if not u or u['role']!='admin':return self.send(403,body='403')
        cmd=self.val(d,'command');
        if not cmd or len(cmd)>4000:return self.send(400,body='Comando inválido')
        rc,out=shell(cmd,30);return self.send(200,'text/plain; charset=utf-8',out+'\n\n[exit %d]'%rc)


def main():
    if os.geteuid()!=0:
        raise SystemExit('KevinTech Web debe ejecutarse como root.')
    ensure_admin();log('WEB START %s:%s prefix=%s'%(HOST,PORT,PREFIX))
    server=ThreadingHTTPServer((HOST,PORT),Handler);server.serve_forever()

if __name__=='__main__':main()
