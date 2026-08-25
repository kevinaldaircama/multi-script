#!/usr/bin/env python3
# KevinTech Telegram Bot v3 - fast, colored UI, integrated with /etc/kevintech
import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,shlex
from pathlib import Path
BASE=Path('/etc/kevintech'); TD=BASE/'telegram'; ENV=TD/'.env'; LOG=TD/'logs'/'bot.log'; OFF=TD/'offset'
API=''; ADM=set(); STATE={}; JOBS={}

def log(s):
 LOG.parent.mkdir(parents=True,exist_ok=True); LOG.open('a').write(time.strftime('[%F %T] ')+str(s)+'\n')
def env():
 d={}
 for l in ENV.read_text(errors='ignore').splitlines():
  if '=' in l and not l.lstrip().startswith('#'):
   k,v=l.split('=',1); d[k]=v.strip().strip('"').strip("'")
 global API,ADM; t=d.get('BOT_TOKEN',''); a=d.get('ADMIN_ID','')
 if not re.fullmatch(r'\d+:[A-Za-z0-9_-]+',t) or not a.isdigit(): raise SystemExit('Credenciales inválidas en .env')
 ADM={int(a)}|{int(x) for x in d.get('ADMIN_IDS','').split(',') if x.strip().isdigit()}; API='https://api.telegram.org/bot'+t

def api(m,data=None,timeout=40):
 r=urllib.request.Request(API+'/'+m,data=urllib.parse.urlencode(data or {}).encode())
 with urllib.request.urlopen(r,timeout=timeout) as x: z=json.loads(x.read().decode())
 if not z.get('ok'): raise RuntimeError(z)
 return z

def e(x): return str(x).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
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
 job=f'J{int(time.time()*1000)}';send(c,f'⚡ <b>{e(title)}</b>\n\n🟡 Iniciado. No voy a bloquear el bot.\n🆔 <code>{job}</code>')
 def w():
  rc,out=sh(cmd,timeout)
  if len(out)>4500:out=out[-4500:]
  send(c,('🟢' if rc==0 else '🔴')+f' <b>{e(title)}</b>\n\n<pre>{e(out or "Terminado sin salida")}</pre>',k)
 threading.Thread(target=w,daemon=True).start()

def kb(rows):return rows
HOME=kb([[{'text':'👤 Usuarios','callback_data':'users'},{'text':'🌐 Protocolos','callback_data':'protocols'}],[{'text':'📊 Estado','callback_data':'status'},{'text':'🛠 Herramientas','callback_data':'tools'}],[{'text':'🔄 Servicios','callback_data':'services'},{'text':'ℹ️ Información','callback_data':'info'}]])
USERS=kb([[{'text':'➕ Crear','callback_data':'create'},{'text':'♻️ Renovar','callback_data':'renew'}],[{'text':'📋 Lista','callback_data':'list'},{'text':'🟢 Online','callback_data':'online'}],[{'text':'🗑️ Eliminar','callback_data':'delete'},{'text':'🔑 Contraseña','callback_data':'passwd'}],[{'text':'🔒 Bloquear','callback_data':'block'},{'text':'🔓 Desbloquear','callback_data':'unblock'}],[{'text':'💾 Backup','callback_data':'backup'},{'text':'🔙 Inicio','callback_data':'home'}]])
TOOLS=kb([[{'text':'🔥 Firewall','callback_data':'tool:firewall'},{'text':'🚀 Optimizar','callback_data':'tool:optimizar'}],[{'text':'🚫 Ads','callback_data':'tool:ads'},{'text':'🚫 Torrent','callback_data':'tool:torrent'}],[{'text':'📈 Speedtest','callback_data':'tool:speed'},{'text':'🔎 Scanner','callback_data':'tool:scanner'}],[{'text':'📁 Archivos','callback_data':'tool:files'},{'text':'🔄 Actualizar','callback_data':'tool:update'}],[{'text':'🔙 Inicio','callback_data':'home'}]])
PROTO={'openssh':('OpenSSH','openssh.sh','ssh','22','1','5'),'dropbear':('Dropbear','dropbear.sh','dropbear','90,143,109','1','6'),'openvpn':('OpenVPN','openvpn.sh','openvpn','1194/UDP,2200/TCP,443/TCP','1','10'),'v2ray':('V2Ray/Xray','v2ray.sh','xray','443/TCP','1','13'),'checkuser':('CheckUser','checkuser.sh','checkuser','10016,10015,8888','1','8'),'slowdns':('SlowDNS','slowdns.sh','dnstt','5300/UDP','1','7'),'badvpn':('BadVPN','badvpn.sh','badvpn-7300','7300,7200','1','4'),'ssl':('SSL/WebSocket','ssl.sh','haproxy','80,443,8080,10015','1','6'),'udpcustom':('UDP Custom','udpcustom.sh','udp-custom','1-65535/UDP','1','7'),'zivpn':('ZiVPN','zivpn.sh','zivpn','20000-29999/UDP','1','10')}
PK=kb([[{'text':v[0],'callback_data':'proto:'+k}] for k,v in PROTO.items()]+[[{'text':'🔙 Inicio','callback_data':'home'}]])
SVCS={k:v[2] for k,v in PROTO.items()}; SVK=kb([[{'text':v[0],'callback_data':'svc:'+k}] for k,v in PROTO.items()]+[[{'text':'🔙 Inicio','callback_data':'home'}]])
def svc(k):
 s=SVCS[k]; rc,_=sh(f'systemctl is-active --quiet {q(s)}',3); st='🟢 ACTIVO' if rc==0 else '🔴 INACTIVO'; _,ports=sh(f"ss -lntup 2>/dev/null | grep -Ei {q(s)} || true",4)
 if not ports: ports='—'
 return f'🔄 <b>{e(PROTO[k][0])}</b>\n\nEstado: {st}\nServicio: <code>{e(s)}</code>\nPuertos: <code>{e(ports)}</code>',[[{'text':'🔄 Reiniciar','callback_data':'svc_restart:'+k},{'text':'📊 Actualizar','callback_data':'svc:'+k}],[{'text':'🔙 Servicios','callback_data':'services'}]]
def module(name):
 for p in [BASE/'protocolos'/name,BASE/'herramientas'/name,BASE/'usuarios'/name]:
  if p.exists():return p
 return None
def installed(k):
 s=SVCS[k]; rc,_=sh(f'systemctl cat {q(s)} >/dev/null 2>&1',3); return rc==0

def info():
 ip=(subprocess.getoutput('hostname -I').split() or ['N/D'])[0]; mem=subprocess.getoutput("free -m|awk '/^Mem:/{printf \"%d/%dMB (%d%%)\",$3,$2,$3*100/$2}'");disk=subprocess.getoutput("df -h /|awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}'");load=subprocess.getoutput("awk '{print $1\", \"$2\", \"$3}' /proc/loadavg");domain='N/D'
 for l in (BASE/'config.conf').read_text(errors='ignore').splitlines() if (BASE/'config.conf').exists() else []:
  if l.startswith('SERVER_DOMAIN='):domain=l.split('=',1)[1].strip('"')
 ps='\n'.join(('🟢' if installed(k) else '⚪')+f' {v[0]} — {v[3]}' for k,v in PROTO.items())
 return f'''ℹ️ <b>KEVINTECH MULTI SCRIPT</b>\n\n🖥 <b>Servidor</b>\n• Host: <code>{e(subprocess.getoutput("hostname"))}</code>\n• IP: <code>{e(ip)}</code>\n• Dominio: <code>{e(domain)}</code>\n• OS: <code>{e(subprocess.getoutput("lsb_release -ds 2>/dev/null") or "Ubuntu")}</code>\n• Kernel: <code>{e(subprocess.getoutput("uname -r"))}</code>\n• Uptime: <code>{e(subprocess.getoutput("uptime -p"))}</code>\n\n⚙️ <b>Recursos</b>\n• RAM: <code>{e(mem)}</code>\n• Disco: <code>{e(disk)}</code>\n• Load: <code>{e(load)}</code>\n• CPU: <code>{e(subprocess.getoutput("nproc"))} núcleos</code>\n\n🌐 <b>PROTOCOLOS</b>\n{ps}\n\n🤖 <b>Bot</b>\n• Servicio: <code>kevintech-telegram</code>\n• Base: <code>/etc/kevintech</code>\n• Estado: 🟢 online'''
def status():return info()
def userexists(u):return bool(re.fullmatch(r'[a-z][a-z0-9_-]{2,31}',u,re.I)) and sh(f'id {q(u)} >/dev/null 2>&1',3)[0]==0
def userlist():
 _,o=sh("awk -F: '$3>=1000&&$1!=\"nobody\"{print $1}' /etc/passwd",4); a=o.splitlines();return '📋 <b>USUARIOS</b>\n\n'+('\n'.join(f'• <code>{e(x)}</code>' for x in a) if a else 'No hay usuarios.')+f'\n\nTotal: <b>{len(a)}</b>'
def account(c,d,renew=False):
 u=d['user'];pw=d.get('pass');days=int(d['days']);exp=subprocess.getoutput(f"date -d '+{days} days' '+%d/%m/%Y'");ip=(subprocess.getoutput('hostname -I').split() or ['N/D'])[0];title='♻️ CUENTA RENOVADA' if renew else '🎉 CUENTA CREADA';p=f'🔑 Contraseña: <code>{e(pw)}</code>' if pw else '🔐 Contraseña: se mantiene la actual';send(c,f'''<b>{title} EXITOSAMENTE</b>\n\n👤 Usuario: <code>{e(u)}</code>\n{p}\n📅 Expira: <code>{e(exp)}</code>\n👥 Límite: <code>{e(d.get('limit','Ilimitado'))}</code>\n\n🌐 <b>DATOS</b>\n• IP: <code>{e(ip)}</code>\n• SSH: <code>22</code>\n• Dropbear: <code>90,143,109</code>\n• HTTP: <code>{e(ip)}:80</code>\n• HTTPS: <code>{e(ip)}:443</code>\n• UDP Custom: <code>{e(ip)}:1-65535</code>''',USERS)

def process_text(c,t):
 if c not in ADM:return send(c,'⛔ Acceso denegado.')
 st=STATE.get(c)
 if not st:
  if t in ('/start','/menu'):return send(c,'🎨 <b>KEVINTECH MULTI SCRIPT</b>\n\n⚡ Panel rápido de administración:',HOME)
  return
 f=st['f'];d=st['d'];step=st['s']
 if f in ('create','renew'):
  if step=='u':
   if not userexists(t) and f=='renew':return send(c,'❌ Usuario no encontrado.')
   if f=='create' and userexists(t):return send(c,'❌ Usuario ya existe.')
   d['user']=t;st['s']='p' if f=='create' else 'days';return send(c,'🔑 Contraseña:') if f=='create' else send(c,'📅 Días a renovar:')
  if f=='create' and step=='p':d['pass']=t;st['s']='days';return send(c,'📅 Días de duración:')
  if step=='days':
   if not t.isdigit() or int(t)<1:return send(c,'❌ Número inválido.')
   d['days']=t;st['s']='limit' if f=='create' else 'confirm';return send(c,'👥 Límite (0=ilimitado):') if f=='create' else send(c,f'♻️ Confirmar renovación de <code>{e(d["user"])}</code> por <code>{t} días</code>?',[[{'text':'✅ RENOVAR','callback_data':'do:renew'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])
  if f=='create' and step=='limit':
   if not t.isdigit():return send(c,'❌ Límite inválido.')
   d['limit']='Ilimitado' if t=='0' else t;st['s']='confirm';return send(c,f'📝 <b>CONFIRMAR</b>\n\n👤 <code>{e(d["user"])}</code>\n🔑 <code>{e(d["pass"])}</code>\n📅 <code>{d["days"]} días</code>\n👥 <code>{e(d["limit"])}</code>',[[{'text':'✅ CREAR','callback_data':'do:create'},{'text':'❌ CANCELAR','callback_data':'cancel'}]])

def cb(c,m,u,i,x):
 if u not in ADM:return ans(i,'⛔ Acceso denegado')
 ans(i,'⚡')
 if x=='home':return edit(c,m,'🏠 <b>KEVINTECH MULTI SCRIPT</b>',HOME)
 if x=='users':return edit(c,m,'👤 <b>GESTIÓN DE USUARIOS</b>',USERS)
 if x=='protocols':return edit(c,m,'🌐 <b>PROTOCOLOS</b>\n\nEstado + puertos + instalar/desinstalar:',PK)
 if x=='tools':return edit(c,m,'🛠 <b>HERRAMIENTAS</b>\n\nOperaciones pesadas se ejecutan en segundo plano:',TOOLS)
 if x in ('info','status'):return edit(c,m,info(),HOME)
 if x=='services':return edit(c,m,'🔄 <b>SERVICIOS</b>',SVK)
 if x=='create':STATE[c]={'f':'create','s':'u','d':{}};return send(c,'➕ <b>CREAR CUENTA</b>\n\nUsuario:')
 if x=='renew':STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR</b>\n\nUsuario:')
 if x=='list':return edit(c,m,userlist(),USERS)
 if x=='online':return edit(c,m,'🟢 <b>ONLINE</b>\n\n<pre>'+e(subprocess.getoutput('who') or 'Sin sesiones')+'</pre>',USERS)
 if x=='backup':return bg(c,'Backup',"mkdir -p /root/kevintech-backups && tar -czf /root/kevintech-backups/backup_$(date +%F_%H-%M-%S).tar.gz /etc/kevintech 2>/dev/null",120,USERS)
 if x=='cancel':STATE.pop(c,None);return send(c,'❌ Cancelado.',USERS)
 if x.startswith('do:'):
  st=STATE.pop(c,None)
  if not st:return send(c,'❌ Operación expirada.',USERS)
  d=st['d'];u=d['user'];days=int(d['days']);exp=subprocess.getoutput(f"date -d '+{days} days' +%F")
  if x=='do:create':
   rc,o=sh(f'useradd -e {q(exp)} -M -s /usr/sbin/nologin {q(u)} && printf %s\\n {q(u+":"+d["pass"])} | chpasswd',12)
   if rc==0:(BASE/'limits').mkdir(exist_ok=True);(BASE/'limits'/u).write_text('0' if d.get('limit')=='Ilimitado' else d.get('limit','0'));return account(c,d)
   return send(c,'🔴 <b>Error al crear</b>\n<pre>'+e(o)+'</pre>',USERS)
  rc,o=sh(f'chage -E {q(exp)} {q(u)}',10);return account(c,d,True) if rc==0 else send(c,'🔴 <b>Error al renovar</b>\n<pre>'+e(o)+'</pre>',USERS)
 if x.startswith('proto:'):
  k=x.split(':')[1];v=PROTO[k];st='🟢 INSTALADO' if installed(k) else '⚪ NO INSTALADO';ports=v[3];buttons=[[{'text':'🔄 Reiniciar','callback_data':'svc_restart:'+k}]] if installed(k) else []
  buttons += [[{'text':'🗑️ Desinstalar','callback_data':'un:'+k}]] if installed(k) else [[{'text':'🚀 Instalar','callback_data':'in:'+k}]]
  buttons += [[{'text':'🔙 Protocolos','callback_data':'protocols'}]]
  return edit(c,m,f'🌐 <b>{e(v[0])}</b>\n\nEstado: {st}\nPuertos: <code>{e(ports)}</code>\nServicio: <code>{e(v[2])}</code>',buttons)
 if x.startswith('in:') or x.startswith('un:'):
  k=x.split(':')[1];v=PROTO[k];p=module(v[1]);
  if not p:return send(c,'🔴 Script no encontrado.',PK)
  option=v[4] if x.startswith('in:') else v[5];return bg(c,('Instalando ' if x.startswith('in:') else 'Desinstalando ')+v[0],f'bash {q(p)} <<EOF\n{option}\nEOF',360,PK)
 if x.startswith('svc_restart:'):
  k=x.split(':')[1];return bg(c,'Reiniciando '+PROTO[k][0],f'systemctl restart {q(PROTO[k][2])}',30,SVK)
 if x.startswith('svc:'):
  t,k=svc(x.split(':')[1]);return edit(c,m,t,k)
 if x.startswith('tool:'):
  k=x.split(':')[1];mp={'optimizar':'optimizar.sh','ads':'blockads.sh','torrent':'blocktorrent.sh','speed':'speedtest.sh','scanner':'scanner.sh','update':'update.sh'}
  if k=='files':return edit(c,m,'📁 <b>ARCHIVOS</b>\n\n<pre>'+e(subprocess.getoutput("find /etc/kevintech -maxdepth 2 -type f | sort | head -120"))+'</pre>',TOOLS)
  p=module(mp.get(k,''));return send(c,'🔴 Módulo no encontrado.',TOOLS) if not p else bg(c,k.title(),f'bash {q(p)}',180,TOOLS)

def main():
 env();LOG.parent.mkdir(parents=True,exist_ok=True);LOG.touch();LOG.chmod(0o600);api('deleteWebhook',{'drop_pending_updates':'false'})
 off=int(OFF.read_text()) if OFF.exists() and OFF.read_text().strip().isdigit() else 0;log('BOT ONLINE')
 while True:
  try:
   r=api('getUpdates',{'offset':off,'timeout':30,'allowed_updates':json.dumps(['message','callback_query'])})
   for u in r.get('result',[]):
    off=u['update_id']+1;OFF.write_text(str(off))
    try:
     if 'callback_query' in u:
      z=u['callback_query'];m=z['message'];cb(m['chat']['id'],m['message_id'],z['from']['id'],z['id'],z.get('data',''))
     elif 'message' in u:
      m=u['message'];process_text(m['chat']['id'],m.get('text',''))
    except Exception as er:log('UPDATE '+repr(er))
  except Exception as er:log('POLL '+repr(er));time.sleep(2)
if __name__=='__main__':main()
