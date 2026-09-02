from pathlib import Path
import re
p=Path('/mnt/data/v10work/telegram/bot.py'); s=p.read_text()
s=s.replace('import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,shlex,datetime,io', 'import os,re,json,time,threading,subprocess,urllib.request,urllib.parse,shlex,datetime,io,secrets')
s=s.replace(" 'backup_schedule':{'mode':'once','next_at':0},\n", " 'backup_schedule':{'mode':'once','next_at':0},\n 'ad_tokens':{},\n")
s=s.replace(" d['backup_schedule'].setdefault('mode','once');d['backup_schedule'].setdefault('next_at',0)", " d['backup_schedule'].setdefault('mode','once');d['backup_schedule'].setdefault('next_at',0)\n if not isinstance(d.get('ad_tokens'),dict):d['ad_tokens']={}\n now=time.time();d['ad_tokens']={k:v for k,v in d['ad_tokens'].items() if isinstance(v,dict) and float(v.get('expires',0) or 0)>now}")
# helpers
marker='def process_text(c,t,chat_type=None):\n'
helpers='''def ad_configurations():
 d=db();m=d.get('monetization',{});items=[]
 try:
  v=m.get('monetag','')
  if v:
   z=json.loads(v)
   if z.get('enabled',True) and z.get('host_url'):items.append(('Monetag',z))
 except:pass
 try:
  v=m.get('adsgram','')
  if v:
   z=json.loads(v)
   if z.get('enabled',True) and z.get('host_url'):items.append(('Adsgram',z))
 except:pass
 return items

def ad_gate(c,action,extra=None):
 if is_admin(c):return False
 ads=ad_configurations()
 if not ads:return False
 host=ads[0][1].get('host_url','').strip()
 if not host:return False
 token=secrets.token_urlsafe(18);d=db();d.setdefault('ad_tokens',{})[token]={'uid':c,'action':action,'extra':extra or {},'expires':time.time()+900};save_db(d)
 sep='&' if '?' in host else '?';url=host+sep+urllib.parse.urlencode({'token':token,'uid':c})
 return send(c,'💰 <b>UN PASO ANTES DE CONTINUAR</b>\\n\\nPara mantener el servicio gratuito, mira el anuncio y completa la publicidad.\\n\\nAl terminar volverás automáticamente al bot.',[[{'text':'▶️ Ver anuncio y continuar','url':url}]]) or True

def consume_ad_token(c,token):
 d=db();item=d.get('ad_tokens',{}).get(token)
 if not item or int(item.get('uid',0))!=c or float(item.get('expires',0))<time.time():return None
 d['ad_tokens'].pop(token,None);save_db(d);return item

def start_create(c,kind):
 if ad_gate(c,'create',{'kind':kind}):return
 STATE[c]={'f':'create','s':'u','d':{'kind':kind}}
 return send(c,'🚀 <b>CREAR CUENTA V2RAY</b>\\n\\nUsuario:' if kind=='v2ray' else '👤 <b>CREAR CUENTA</b>\\n\\nUsuario:')

def start_renew(c,username=None):
 if username and ad_gate(c,'renew',{'username':username}):return
 if not username and ad_gate(c,'renew'):return
 STATE[c]={'f':'renew','s':'u','d':({'user':username} if username else {})};return send(c,'♻️ <b>RENOVAR CUENTA</b>\\n\\nEscribe el usuario que deseas renovar:')

def near_expiry_notifications():
 while True:
  try:
   d=db();today=datetime.date.today();changed=False
   for sid,z in d.get('users',{}).items():
    for username in list(z.get('accounts',[])):
     if username in z.get('v2ray_accounts',[]):ds=z.get('v2ray_expirations',{}).get(username,'')
     else:ds=subprocess.getoutput(f"chage -l {q(username)} 2>/dev/null | awk -F': ' '/Account expires/{{print $2}}'")
     try:
      if ds and '/' in str(ds):ex=datetime.datetime.strptime(str(ds).strip(),'%d/%m/%Y').date()
      else:ex=datetime.datetime.strptime(str(ds).strip(),'%b %d, %Y').date()
     except:continue
     left=(ex-today).days
     if 0<=left<=1:
      key=f'{username}:{ex.isoformat()}'
      if z.setdefault('expiry_notice',{}).get(username)==key:continue
      z['expiry_notice'][username]=key;changed=True
      owner=int(sid);mention='@'+z.get('username') if z.get('username') else str(owner)
      text=f'⏳ <b>CUENTA PRÓXIMA A VENCER</b>\\n\\n👤 Cuenta: <code>{e(username)}</code>\\n📅 Vencimiento: <b>{e(ex.strftime("%d/%m/%Y"))}</b>\\n⏱️ Tiempo restante: <b>{"hoy" if left==0 else "1 día"}</b>\\n\\nPuedes renovarla desde el botón inferior.'
      k=[[{'text':'♻️ Renovar cuenta','callback_data':'renew:'+username}]]
      try:send(owner,text,k)
      except:pass
      if owner!=OWNER:
       try:send(OWNER,f'🔔 <b>AVISO DE VENCIMIENTO</b>\\n\\n👤 Cuenta: <code>{e(username)}</code>\\n📱 Propietario: <code>{e(mention)}</code>\\n📅 Vence: <b>{e(ex.strftime("%d/%m/%Y"))}</b>',k)
       except:pass
   if changed:save_db(d)
  except Exception as ex:log('EXPIRY NOTICE '+repr(ex))
  time.sleep(1800)

'''
s=s.replace(marker,helpers+marker)
# command renew
s=s.replace("if cmd in ('/renovar','/renew'):\n  STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR CUENTA</b>\\n\\nEscribe el usuario que deseas renovar:')", "if cmd in ('/renovar','/renew'):\n  return start_renew(c)")
# callback create/renew block
old=""" if x in ('create:normal','create:v2ray'):\n  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado.')\n  if not allowed(u):return send(c,'🔒 Acceso privado.')\n  kind='v2ray' if x.endswith('v2ray') else 'normal'\n  STATE[c]={'f':'create','s':'u','d':{'kind':kind}}\n  return send(c,'🚀 <b>CREAR CUENTA V2RAY</b>\\n\\nUsuario:') if kind=='v2ray' else send(c,'👤 <b>CREAR CUENTA</b>\\n\\nUsuario:')\n if x=='renew':STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR</b>\\n\\nUsuario:')"""
new=""" if x in ('create:normal','create:v2ray'):\n  if not private_chat(c):return send(c,'🔒 <b>CREAR CUENTA</b> solo está disponible por privado.')\n  if not allowed(u):return send(c,'🔒 Acceso privado.')\n  kind='v2ray' if x.endswith('v2ray') else 'normal'\n  return start_create(c,kind)\n if x=='renew':return start_renew(c)\n if x.startswith('renew:'):\n  username=x.split(':',1)[1]\n  if not userexists(username):return send(c,'❌ Esa cuenta ya no existe.')\n  return start_renew(c,username)"""
s=s.replace(old,new)
# handle_start ad completion
needle=""" if not me.get('language_selected'):\n  STATE[c]={'f':'language','s':'pick','d':{}}"""
insert=""" if raw.startswith('/start adcompleted') or raw.startswith('/star adcompleted'):\n  tok=raw.split('adcompleted',1)[1].strip().lstrip('_ ')\n  item=consume_ad_token(c,tok)\n  if not item:return send(c,'❌ Este enlace de publicidad expiró o ya fue utilizado.')\n  if item.get('action')=='create':return start_create(c,item.get('extra',{}).get('kind','normal'))\n  if item.get('action')=='renew':\n   username=item.get('extra',{}).get('username')\n   if username:STATE[c]={'f':'renew','s':'u','d':{'user':username}};return cb(c,0,c,0,'do:renew')\n   return start_renew(c)\n if not me.get('language_selected'):\n  STATE[c]={'f':'language','s':'pick','d':{}}"""
s=s.replace(needle,insert)
# monetag steps
s=s.replace("if f=='monetag' and step=='reward':dat['reward']=t.strip();st['s']='url';return send(c,'🌐 <b>Paso 3</b>\\n\\nIngresa la URL de tu bot. Ejemplo:\\n<code>https://t.me/tu_bot</code>')", "if f=='monetag' and step=='reward':dat['reward']=t.strip();st['s']='boturl';return send(c,'🌐 <b>Paso 3</b>\\n\\nIngresa la URL de tu bot. Ejemplo:\\n<code>https://t.me/tu_bot</code>')\n if f=='monetag' and step=='boturl':dat['url']=t.strip();st['s']='hosturl';return send(c,'🌍 <b>Paso 4</b>\\n\\nIngresa la URL donde está alojado el archivo HTML.')\n if f=='monetag' and step=='hosturl':dat['host_url']=t.strip();dat['enabled']=True;d['monetization']['monetag']=json.dumps(dat,ensure_ascii=False);save_db(d);STATE.pop(c,None);fn=generate_monetag_html(c,dat);send(c,'🟢 <b>Monetag configurado correctamente.</b>');return send_document(c,fn,'📄 HTML personalizado.')")
# replace generator
start=s.index('def generate_monetag_html(uid,dat):');end=s.index('def admin_text(c,t):',start)
func=r'''def generate_monetag_html(uid,dat):
 bot_url=dat.get('url','').strip() or (f'https://t.me/{BOT_USERNAME}' if BOT_USERNAME else '')
 sdk=dat.get('sdk','').strip();reward=dat.get('reward','').strip();adsgram_code=''
 try:
  az=json.loads(db().get('monetization',{}).get('adsgram',''))
  adsgram_code=az.get('code','') if isinstance(az,dict) else ''
 except:pass
 m=re.search(r'data-sdk=["\']([^"\']+)',sdk,re.I);ad_fn=m.group(1) if m else ''
 html=r"""<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>KevinTech Premium</title>
<script src="https://telegram.org/js/telegram-web-app.js"></script>
__SDK__
__ADSGRAM__
<style>
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}:root{--cyan:#00e5ff;--blue:#0077ff;--purple:#8b5cf6;--green:#00ff9d;--red:#ff3158;--bg:#03050a}html,body{width:100%;height:100%}body{overflow:hidden;background:var(--bg);color:#fff;font-family:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.background{position:fixed;inset:0;overflow:hidden;pointer-events:none;background:radial-gradient(circle at 50% 20%,rgba(0,229,255,.12),transparent 30%),radial-gradient(circle at 10% 90%,rgba(139,92,246,.13),transparent 30%),#03050a}.grid{position:absolute;inset:-50%;background-image:linear-gradient(rgba(0,229,255,.035) 1px,transparent 1px),linear-gradient(90deg,rgba(0,229,255,.035) 1px,transparent 1px);background-size:45px 45px;transform:perspective(500px) rotateX(60deg) translateY(150px);animation:gridMove 12s linear infinite}@keyframes gridMove{from{transform:perspective(500px) rotateX(60deg) translateY(0)}to{transform:perspective(500px) rotateX(60deg) translateY(90px)}}.particles span{position:absolute;width:3px;height:3px;background:var(--cyan);border-radius:50%;box-shadow:0 0 10px var(--cyan);animation:particle 5s linear infinite}.particles span:nth-child(1){left:10%;top:20%}.particles span:nth-child(2){left:25%;top:70%;animation-delay:1s}.particles span:nth-child(3){left:70%;top:15%;animation-delay:2s}.particles span:nth-child(4){left:85%;top:65%;animation-delay:3s}.particles span:nth-child(5){left:50%;top:85%;animation-delay:4s}.particles span:nth-child(6){left:92%;top:35%;animation-delay:1.5s}@keyframes particle{0%{opacity:0;transform:translateY(40px)}30%{opacity:1}100%{opacity:0;transform:translateY(-100px)}}.app{position:relative;z-index:5;width:100%;height:100%;display:flex;align-items:center;justify-content:center;padding:20px}.panel{width:100%;max-width:390px;text-align:center}.logo-area{position:relative;width:150px;height:150px;margin:0 auto 25px;display:flex;align-items:center;justify-content:center}.ring{position:absolute;border:1px solid rgba(0,229,255,.45);border-radius:50%;animation:rotate 8s linear infinite}.ring.one{width:150px;height:150px}.ring.two{width:125px;height:125px;border-color:rgba(139,92,246,.5);animation-direction:reverse;animation-duration:6s}.ring.three{width:105px;height:105px;border-color:rgba(0,229,255,.25);animation-duration:4s}@keyframes rotate{from{transform:rotate(0)}to{transform:rotate(360deg)}}.logo{position:relative;width:82px;height:82px;display:flex;align-items:center;justify-content:center;border-radius:25px;background:linear-gradient(135deg,#00e5ff,#0077ff 55%,#8b5cf6);box-shadow:0 0 25px rgba(0,229,255,.45),0 0 70px rgba(0,119,255,.2);font-size:25px;font-weight:950;letter-spacing:-2px;animation:logoPulse 2.5s ease-in-out infinite}@keyframes logoPulse{0%,100%{box-shadow:0 0 25px rgba(0,229,255,.45),0 0 70px rgba(0,119,255,.2)}50%{box-shadow:0 0 45px rgba(0,229,255,.7),0 0 100px rgba(0,119,255,.35)}}.mini-title{font-size:10px;font-weight:800;letter-spacing:4px;color:var(--cyan);text-transform:uppercase;margin-bottom:10px}h1{font-size:32px;line-height:1;font-weight:900;letter-spacing:-1px;margin-bottom:13px}h1 span{background:linear-gradient(90deg,#fff,var(--cyan),#fff);background-size:200%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;animation:shine 3s linear infinite}@keyframes shine{to{background-position:200%}}.description{max-width:310px;margin:0 auto;color:rgba(255,255,255,.55);font-size:13px;line-height:1.6}.status{display:inline-flex;align-items:center;gap:7px;margin-top:18px;margin-bottom:18px;padding:7px 12px;border-radius:50px;background:rgba(0,255,157,.06);border:1px solid rgba(0,255,157,.15);color:rgba(255,255,255,.65);font-size:10px}.status-dot{width:6px;height:6px;border-radius:50%;background:var(--green);box-shadow:0 0 10px var(--green);animation:blink 1.5s infinite}@keyframes blink{50%{opacity:.3}}.button-wrap{position:relative;margin-top:5px}.glow{position:absolute;inset:-3px;border-radius:18px;background:linear-gradient(90deg,var(--cyan),var(--blue),var(--purple),var(--cyan));background-size:300%;filter:blur(12px);opacity:.35;animation:buttonGlow 4s linear infinite}@keyframes buttonGlow{to{background-position:300%}}#playBtn{position:relative;width:100%;padding:17px 20px;border:1px solid rgba(255,255,255,.18);border-radius:17px;background:linear-gradient(135deg,rgba(0,229,255,.18),rgba(0,119,255,.18));color:white;font-size:14px;font-weight:850;cursor:pointer;backdrop-filter:blur(10px);transition:transform .2s,background .2s}#playBtn:active{transform:scale(.96)}#playBtn:disabled{opacity:.65;cursor:wait}.loader{display:none;width:17px;height:17px;margin-right:8px;vertical-align:middle;border:2px solid rgba(255,255,255,.25);border-top-color:var(--cyan);border-radius:50%;animation:spin .7s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}.footer{margin-top:22px;color:rgba(255,255,255,.32);font-size:10px}.footer p{margin:6px}#error-msg{display:none}.error-icon{width:75px;height:75px;margin:0 auto 20px;display:flex;align-items:center;justify-content:center;border-radius:24px;background:rgba(255,49,88,.1);border:1px solid rgba(255,49,88,.25);font-size:30px;box-shadow:0 0 35px rgba(255,49,88,.12)}.continue{width:100%;margin-top:22px;padding:15px;border:0;border-radius:16px;background:linear-gradient(135deg,#00c987,#00a974);color:white;font-size:14px;font-weight:800}
</style></head><body><div class="background"><div class="grid"></div><div class="particles"><span></span><span></span><span></span><span></span><span></span><span></span></div></div><main class="app"><section class="panel"><div class="logo-area"><div class="ring one"></div><div class="ring two"></div><div class="ring three"></div><div class="logo">KT</div></div><div id="loading"><div class="mini-title">KevinTech System</div><h1><span>Acceso Premium</span></h1><p class="description">Estás a un paso de continuar. Mira un pequeño anuncio para mantener este servicio disponible gratuitamente.</p><div class="status"><span class="status-dot"></span>Sistema disponible</div><div class="button-wrap"><div class="glow"></div><button id="playBtn"><span id="loader" class="loader"></span><span id="btnText">▶ &nbsp; VER ANUNCIO</span></button></div></div><div id="error-msg"><div class="error-icon">⚠️</div><div class="mini-title">KevinTech System</div><h1>Anuncio no disponible</h1><p class="description">En este momento no hay publicidad disponible para tu región.</p><button class="continue" onclick="sendSuccessAndClose()">✓ CONTINUAR</button></div><div class="footer"><p>© KevinTech Multi Script</p></div></section></main><script>const tg=window.Telegram.WebApp;tg.ready();tg.expand();const playBtn=document.getElementById('playBtn'),btnText=document.getElementById('btnText'),loader=document.getElementById('loader'),loading=document.getElementById('loading'),errorMsg=document.getElementById('error-msg');const params=new URLSearchParams(location.search),token=params.get('token')||'';const botBase=__BOT_URL__,adFn=__AD_FN__;function sendSuccessAndClose(){const url=botBase+(botBase.includes('?')?'&':'?')+'start=adcompleted_'+encodeURIComponent(token);try{tg.openTelegramLink(url);setTimeout(()=>tg.close(),400)}catch(e){window.location.href=url}}function showError(){loading.style.display='none';errorMsg.style.display='block'}playBtn.addEventListener('click',async()=>{playBtn.disabled=true;loader.style.display='inline-block';btnText.textContent='CARGANDO ANUNCIO...';try{if(!adFn)throw new Error('SDK');await window[adFn]();loader.style.display='none';btnText.textContent='✓ COMPLETADO';setTimeout(sendSuccessAndClose,600)}catch(error){loader.style.display='none';showError()}});</script></body></html>"""
 html=html.replace('__SDK__',sdk).replace('__ADSGRAM__',adsgram_code).replace('__BOT_URL__',json.dumps(bot_url)).replace('__AD_FN__',json.dumps(ad_fn)).replace('</script></body></html>',reward+'</script></body></html>')
 fn=BACK/'monetag_webapp.html';fn.write_text(html,encoding='utf-8');os.chmod(fn,0o600);return fn

'''
s=s[:start]+func+s[end:]
# callback renewal old direct state should gate
s=s.replace("if x=='renew':STATE[c]={'f':'renew','s':'u','d':{}};return send(c,'♻️ <b>RENOVAR</b>\\n\\nUsuario:')", "if x=='renew':return start_renew(c)")
# thread
s=s.replace("threading.Thread(target=v2ray_expiration_monitor,daemon=True).start();threading.Thread(target=auto_update_monitor,daemon=True).start()", "threading.Thread(target=v2ray_expiration_monitor,daemon=True).start();threading.Thread(target=near_expiry_notifications,daemon=True).start();threading.Thread(target=auto_update_monitor,daemon=True).start()")
p.write_text(s)
