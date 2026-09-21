#!/usr/bin/env python3
import base64, hashlib, hmac, http.cookies, http.server, json, os, re, secrets, shlex, subprocess, time, urllib.parse
from pathlib import Path

BASE = Path('/etc/kevintech')
WEB = BASE / 'web'
ENV = WEB / '.env'
SECRET_FILE = WEB / 'secret.key'
PORT = int(os.environ.get('KEVINTECH_WEB_PORT', '18080'))
HOST = '127.0.0.1'


def read_env():
    data = {}
    if ENV.exists():
        for line in ENV.read_text(errors='ignore').splitlines():
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            data[k] = v.strip().strip('"').strip("'")
    return data

CFG = read_env()
ADMIN_USER = CFG.get('WEB_ADMIN_USER', 'admin')
ADMIN_HASH = CFG.get('WEB_ADMIN_HASH', '')

if not SECRET_FILE.exists():
    SECRET_FILE.write_bytes(secrets.token_bytes(32))
    os.chmod(SECRET_FILE, 0o600)
SECRET = SECRET_FILE.read_bytes()

SESSIONS = {}
SESSION_TTL = 12 * 3600


def hash_password(password, salt=None):
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 310000)
    return base64.urlsafe_b64encode(salt + digest).decode()


def verify_password(password, encoded):
    try:
        raw = base64.urlsafe_b64decode(encoded.encode())
        salt, expected = raw[:16], raw[16:]
        actual = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 310000)
        return hmac.compare_digest(actual, expected)
    except Exception:
        return False


def sign_session(sid):
    return sid + '.' + hmac.new(SECRET, sid.encode(), hashlib.sha256).hexdigest()


def valid_session(token):
    try:
        sid, sig = token.split('.', 1)
        if not hmac.compare_digest(sig, hmac.new(SECRET, sid.encode(), hashlib.sha256).hexdigest()):
            return None
        item = SESSIONS.get(sid)
        if not item or item['expires'] < time.time():
            SESSIONS.pop(sid, None)
            return None
        item['expires'] = time.time() + SESSION_TTL
        return item
    except Exception:
        return None


def run(cmd, timeout=30, input_text=None):
    p = subprocess.run(cmd, shell=True, text=True, input=input_text, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout, executable='/bin/bash')
    return p.returncode, p.stdout[-20000:]


def safe_name(s):
    return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}', s or ''))


def server_config():
    cfg = {}
    f = BASE / 'config.conf'
    if f.exists():
        for line in f.read_text(errors='ignore').splitlines():
            m = re.match(r'^([A-Z0-9_]+)="?(.*?)"?$', line.strip())
            if m:
                cfg[m.group(1)] = m.group(2).strip('"')
    return cfg


def linux_users():
    result = []
    limits = {}
    lf = BASE / 'limits.conf'
    if lf.exists():
        for line in lf.read_text(errors='ignore').splitlines():
            if ':' in line:
                u, n = line.split(':', 1)
                try: limits[u] = int(n)
                except ValueError: pass
    try:
        passwd = Path('/etc/passwd').read_text(errors='ignore').splitlines()
    except Exception:
        passwd = []
    for line in passwd:
        parts = line.split(':')
        if len(parts) < 7: continue
        u, uid, shell = parts[0], parts[2], parts[6]
        try: uidn = int(uid)
        except ValueError: continue
        if uidn < 1000 or u == 'nobody': continue
        exp = subprocess.run(['chage','-l',u], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
        em = re.search(r'Account expires\s*:\s*(.+)', exp)
        expires = em.group(1).strip() if em else 'unknown'
        locked = subprocess.run(['passwd','-S',u], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
        blocked = ' L ' in (' ' + locked + ' ') or bool(re.search(r'^\S+\s+L\s', locked))
        result.append({'username':u,'expires':expires,'limit':limits.get(u,0),'blocked':blocked})
    return result


def online():
    rc, out = run("who 2>/dev/null | awk '{print $1"|"$5}' | sed 's/[()]//g' | sort -u", 5)
    rows=[]
    for line in out.splitlines():
        if '|' in line:
            u, ip = line.split('|',1)
            rows.append({'username':u,'ip':ip})
    return rows


def services():
    names=['ssh','haproxy','fail2ban','kevintech-telegram','kevintech-web','kevintech-limit','openvpn','dropbear','zivpn']
    out=[]
    for n in names:
        p=subprocess.run(['systemctl','is-active',n],text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
        out.append({'name':n,'active':p.stdout.strip()=='active'})
    return out


def json_bytes(obj):
    return json.dumps(obj, ensure_ascii=False).encode()

class Handler(http.server.BaseHTTPRequestHandler):
    server_version = 'KevinTechWeb/1.0'
    def log_message(self, fmt, *args):
        print('[web]', fmt % args, flush=True)

    def headers_common(self):
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('X-Frame-Options','DENY')
        self.send_header('Referrer-Policy','same-origin')
        self.send_header('Cache-Control','no-store')

    def send_json(self, code, obj):
        body=json_bytes(obj)
        self.send_response(code); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Content-Length',str(len(body))); self.headers_common(); self.end_headers(); self.wfile.write(body)

    def send_text(self, code, body, ctype='text/plain; charset=utf-8'):
        if isinstance(body,str): body=body.encode()
        self.send_response(code); self.send_header('Content-Type',ctype); self.send_header('Content-Length',str(len(body))); self.headers_common(); self.end_headers(); self.wfile.write(body)

    def session(self):
        c=http.cookies.SimpleCookie(self.headers.get('Cookie','')); token=c.get('kt_session'); return valid_session(token.value) if token else None

    def require(self):
        s=self.session()
        if not s: self.send_json(401,{'ok':False,'error':'Sesión no válida'}); return None
        return s

    def csrf_ok(self, s, payload):
        return hmac.compare_digest(str(payload.get('csrf','')), str(s.get('csrf','')))

    def do_HEAD(self):
        path=urllib.parse.urlsplit(self.path).path
        if path in ('/','/index.html'):
            body=(WEB/'static'/'index.html').read_bytes()
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.send_header('Content-Length',str(len(body)))
            self.headers_common(); self.end_headers(); return
        self.send_response(404); self.headers_common(); self.end_headers()

    def do_GET(self):
        path=urllib.parse.urlsplit(self.path).path
        if path in ('/','/index.html'):
            self.send_text(200,(WEB/'static'/'index.html').read_bytes(),'text/html; charset=utf-8'); return
        if path.startswith('/static/'):
            f=WEB/path.lstrip('/')
            if f.is_file() and WEB in f.parents:
                c='text/plain; charset=utf-8'
                if f.suffix=='.css': c='text/css; charset=utf-8'
                elif f.suffix=='.js': c='application/javascript; charset=utf-8'
                self.send_text(200,f.read_bytes(),c); return
        if path=='/api/me':
            s=self.session(); self.send_json(200,{'ok':bool(s),'user':ADMIN_USER if s else None}); return
        if path=='/api/csrf':
            s=self.require()
            if s: self.send_json(200,{'ok':True,'csrf':s['csrf']})
            return
        if path=='/api/status':
            s=self.require()
            if not s:return
            cfg=server_config(); rc,up=run('uptime -p',5); rc2,mem=run("free -m | awk '/Mem:/ {print $3 \"/\" $2 \" MB\"}'",5); rc3,disk=run("df -h / | awk 'NR==2 {print $3 \"/\" $2 \" (\" $5 \")\"}'",5)
            self.send_json(200,{'ok':True,'domain':cfg.get('SERVER_DOMAIN',''),'ip':cfg.get('SERVER_IP',''),'uptime':up.strip(),'memory':mem.strip(),'disk':disk.strip(),'services':services(),'ports':self.ports()}); return
        if path=='/api/users':
            if not self.require(): return
            self.send_json(200,{'ok':True,'users':linux_users(),'online':online()}); return
        self.send_json(404,{'ok':False,'error':'No encontrado'})

    def ports(self):
        rc,out=run("ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -oE ':[0-9]+$' | tr -d ':' | sort -nu | grep -E '^(80|443|8080|18080)$' | paste -sd, -",5)
        return out.strip().split(',') if out.strip() else []

    def read_body(self):
        n=int(self.headers.get('Content-Length','0')); raw=self.rfile.read(n)
        try:return json.loads(raw.decode() or '{}')
        except:return {}

    def do_POST(self):
        path=urllib.parse.urlsplit(self.path).path
        data=self.read_body()
        if path=='/api/login':
            if not hmac.compare_digest(str(data.get('username','')),ADMIN_USER) or not verify_password(str(data.get('password','')),ADMIN_HASH):
                self.send_json(401,{'ok':False,'error':'Usuario o contraseña incorrectos'}); return
            sid=secrets.token_urlsafe(32); csrf=secrets.token_urlsafe(24); SESSIONS[sid]={'expires':time.time()+SESSION_TTL,'csrf':csrf}
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Set-Cookie',f'kt_session={sign_session(sid)}; HttpOnly; SameSite=Strict; Secure; Path=/'); self.headers_common(); body=json_bytes({'ok':True}); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if path=='/api/logout':
            s=self.session();
            if s:
                c=http.cookies.SimpleCookie(self.headers.get('Cookie','')); token=c.get('kt_session');
                if token:
                    try: SESSIONS.pop(token.value.split('.',1)[0],None)
                    except: pass
            self.send_json(200,{'ok':True}); return
        s=self.require()
        if not s:return
        if not self.csrf_ok(s,data): self.send_json(403,{'ok':False,'error':'CSRF inválido'}); return

        try:
            if path=='/api/user/create':
                u=str(data.get('username','')).lower(); pw=str(data.get('password','')); days=int(data.get('days',0)); limit=int(data.get('limit',0))
                if not safe_name(u): raise ValueError('Usuario inválido')
                if len(pw)<4: raise ValueError('Contraseña demasiado corta')
                if days<0 or limit<0: raise ValueError('Valores inválidos')
                if subprocess.run(['id',u],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0: raise ValueError('El usuario ya existe')
                subprocess.run(['useradd','-M','-s','/usr/sbin/nologin'] + (['-e',(time.strftime('%Y-%m-%d',time.localtime(time.time()+days*86400)))] if days else []) + [u],check=True)
                try:
                    subprocess.run(['chpasswd'],input=f'{u}:{pw}\n',text=True,check=True)
                except:
                    subprocess.run(['userdel','-f',u],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); raise
                lf=BASE/'limits.conf'; lf.parent.mkdir(parents=True,exist_ok=True); old=[x for x in lf.read_text(errors='ignore').splitlines() if x and not x.startswith(u+':')] if lf.exists() else []; old.append(f'{u}:{limit}'); lf.write_text('\n'.join(old)+'\n'); os.chmod(lf,0o600)
                self.send_json(200,{'ok':True,'message':'Usuario creado'}); return
            if path=='/api/user/delete':
                u=str(data.get('username',''))
                if not safe_name(u): raise ValueError('Usuario inválido')
                subprocess.run(['userdel','-f',u],check=True)
                lf=BASE/'limits.conf'
                if lf.exists(): lf.write_text('\n'.join(x for x in lf.read_text(errors='ignore').splitlines() if not x.startswith(u+':'))+'\n')
                self.send_json(200,{'ok':True,'message':'Usuario eliminado'}); return
            if path=='/api/user/block':
                u=str(data.get('username','')); action=data.get('action')
                if not safe_name(u) or action not in ('block','unblock'): raise ValueError('Solicitud inválida')
                subprocess.run(['usermod','-L' if action=='block' else '-U',u],check=True); self.send_json(200,{'ok':True}); return
            if path=='/api/user/renew':
                u=str(data.get('username','')); days=int(data.get('days',0))
                if not safe_name(u) or days<=0: raise ValueError('Datos inválidos')
                subprocess.run(['chage','-E',time.strftime('%Y-%m-%d',time.localtime(time.time()+days*86400)),u],check=True); self.send_json(200,{'ok':True}); return
            if path=='/api/command':
                cmd=str(data.get('command','')).strip()
                if len(cmd)>500: raise ValueError('Comando demasiado largo')
                dangerous=re.compile(r'(^|[;&|`$()<>])\s*(rm|mkfs|dd|shutdown|reboot|poweroff|useradd|userdel|passwd|chpasswd)\b',re.I)
                # User-management is exposed only through the dedicated API above.
                if dangerous.search(cmd): raise ValueError('Comando no permitido desde la consola web')
                rc,out=run(cmd,30); self.send_json(200,{'ok':rc==0,'code':rc,'output':out}); return
            self.send_json(404,{'ok':False,'error':'No encontrado'})
        except subprocess.CalledProcessError as e:
            self.send_json(400,{'ok':False,'error':f'Operación falló (código {e.returncode})'})
        except Exception as e:
            self.send_json(400,{'ok':False,'error':str(e)})

if __name__=='__main__':
    if os.geteuid()!=0:
        raise SystemExit('El servidor web debe ejecutarse como root')
    httpd=http.server.ThreadingHTTPServer((HOST,PORT),Handler)
    print(f'KevinTech Web escuchando en http://{HOST}:{PORT}',flush=True)
    httpd.serve_forever()
