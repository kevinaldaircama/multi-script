from pathlib import Path
p=Path('/mnt/data/work/v10/telegram/bot.py'); s=p.read_text()
s=s.replace("'monetization':{'monetag':'','miniapp':''},", "'monetization':{'monetag':'','adsgram':''},\n 'auto_update':{'enabled':False,'last_version':'','checked_at':0},")
s=s.replace("for k,v in DEFAULT.items():\n  if k not in d:d[k]=json.loads(json.dumps(v))", "for k,v in DEFAULT.items():\n  if k not in d:d[k]=json.loads(json.dumps(v))\n if 'miniapp' in d.get('monetization',{}):d['monetization']['adsgram']=d['monetization'].pop('miniapp')\n if not isinstance(d.get('auto_update'),dict):d['auto_update']=json.loads(json.dumps(DEFAULT['auto_update']))\n for k,v in DEFAULT['auto_update'].items():d['auto_update'].setdefault(k,v)")
needle="def bg(c,title,cmd,timeout=300,k=None,restart_after=False):"
insert="""VERSION_LOCAL=TD/'version.txt'
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
 try:return tuple(int(x) for x in re.findall(r'\\d+',v))
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

"""
s=s.replace(needle,insert+needle)
s=s.replace("MONETIZATION=[[{'text':'💰 Monetag','callback_data':'monetag'},{'text':'📱 Mini App','callback_data':'miniapp'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]", "MONETIZATION=[[{'text':'💰 Monetag','callback_data':'monetag'},{'text':'📱 Adsgram','callback_data':'adsgram'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]]")
# Replace monetization callback lines
s=s.replace("if x=='monetization':return edit(c,m,'💰 <b>MONETIZACIÓN</b>\\n\\nConfigura Monetag u otra Mini App.',MONETIZATION)\n if x=='monetag':STATE[c]={'f':'monetag','s':'value','d':{}};return send(c,'💰 Envía el código, enlace o identificador de Monetag:')\n if x=='miniapp':STATE[c]={'f':'miniapp','s':'value','d':{}};return send(c,'📱 Envía el enlace o identificador de tu Mini App:')", "if x=='monetization':return edit(c,m,'💰 <b>MONETIZACIÓN</b>\\n\\nSelecciona la plataforma que deseas configurar.',MONETIZATION)\n if x=='monetag':return monetag_menu(c,m)\n if x=='monetag_config':STATE[c]={'f':'monetag','s':'sdk','d':{}};return send(c,\"💰 <b>MONETAG — PASO 1</b>\\n\\nPega aquí tu SDK. Ejemplo:\\n<code>&lt;script src='//libtl.com/sdk.js' data-zone='11217882' data-sdk='show_11217882'&gt;&lt;/script&gt;</code>\")\n if x=='monetag_toggle':\n  d['monetization']['monetag']='' if d.get('monetization',{}).get('monetag') else json.dumps({'sdk':\"<script src='//libtl.com/sdk.js' data-zone='11217882' data-sdk='show_11217882'></script>\",'reward':'','url':f'https://t.me/{BOT_USERNAME}?start=adcompleted'},ensure_ascii=False);save_db(d);return monetag_menu(c,m)\n if x=='adsgram':return adsgram_menu(c,m)\n if x=='adsgram_config':STATE[c]={'f':'adsgram','s':'value','d':{}};return send(c,'📱 <b>ADSGRAM</b>\\n\\nEnvía el código de configuración de Adsgram.')\n if x=='adsgram_toggle':d['monetization']['adsgram']='' if d.get('monetization',{}).get('adsgram') else 'enabled';save_db(d);return adsgram_menu(c,m)")
# insert funcs before admin_text
needle="def admin_text(c,t):"
insert="""def monetag_menu(c,m=0):
 d=db();v=d.get('monetization',{}).get('monetag','');configured=bool(v)
 text='💰 <b>MONETAG</b>\\n\\nEstado: <b>'+('🟢 CONFIGURADO' if configured else '🔴 NO CONFIGURADO')+'</b>'
 if configured:
  try:text+='\\n\\n🌐 URL: <code>'+e(json.loads(v).get('url',''))+'</code>'
  except:pass
 k=[[{'text':'⏻ Apagar','callback_data':'monetag_toggle'},{'text':'⚙️ Reconfigurar','callback_data':'monetag_config'}]] if configured else [[{'text':'⚙️ Configurar','callback_data':'monetag_config'}]]
 k.append([{'text':'🔙 Monetización','callback_data':'monetization'}]);return edit(c,m,text,k) if m else send(c,text,k)
def adsgram_menu(c,m=0):
 configured=bool(db().get('monetization',{}).get('adsgram',''));text='📱 <b>ADSGRAM</b>\\n\\nEstado: <b>'+('🟢 CONFIGURADO' if configured else '🔴 NO CONFIGURADO')+'</b>'
 k=[[{'text':'⏻ Apagar','callback_data':'adsgram_toggle'},{'text':'⚙️ Reconfigurar','callback_data':'adsgram_config'}]] if configured else [[{'text':'⚙️ Configurar','callback_data':'adsgram_config'}]]
 k.append([{'text':'🔙 Monetización','callback_data':'monetization'}]);return edit(c,m,text,k) if m else send(c,text,k)
def generate_monetag_html(uid,dat):
 bot_url=dat.get('url') or (f'https://t.me/{BOT_USERNAME}?start=adcompleted' if BOT_USERNAME else '')
 sdk=dat.get('sdk','');reward=dat.get('reward','')
 html='''<!DOCTYPE html>\n<html lang="es">\n<head>\n<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1.0">\n<title>KEVINTECH MULTI SCRIPT</title>\n<script src="https://telegram.org/js/telegram-web-app.js"></script>\n'''+sdk+'''\n<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#03050a;color:#fff;font-family:Arial,sans-serif;display:flex;align-items:center;justify-content:center}.panel{width:min(390px,90%);text-align:center}.logo{width:82px;height:82px;margin:auto auto 24px;border-radius:25px;background:linear-gradient(135deg,#00e5ff,#0077ff,#8b5cf6);display:flex;align-items:center;justify-content:center;font-size:25px;font-weight:900}button{width:100%;padding:17px;border:0;border-radius:16px;background:linear-gradient(135deg,#00e5ff,#0077ff);color:white;font-weight:800}p{color:#aaa;line-height:1.6}</style>\n</head>\n<body><main class="panel"><div class="logo">KT</div><h1>Acceso Premium</h1><p>Mira un anuncio para continuar.</p><button id="play">▶ VER ANUNCIO</button><p>© KEVINTECH MULTI SCRIPT</p></main>\n<script>const tg=window.Telegram.WebApp;tg.ready();tg.expand();document.getElementById('play').onclick=async()=>{try{await show_11217882();window.location.href='''+json.dumps(bot_url)+''';}catch(e){alert('Anuncio no disponible');}};\n/* Rewarded Interstitial configurado por el super admin */\n'''+reward+'''\n</script></body></html>'''
 fn=BACK/'monetag_webapp.html';fn.write_text(html,encoding='utf-8');os.chmod(fn,0o600);return fn

"""
s=s.replace(needle,insert+needle)
# admin state conditions and handling
s=s.replace("if f in ('monetag','miniapp') and step=='value':\n  d['monetization']['monetag' if f=='monetag' else 'miniapp']=t.strip();save_db(d);STATE.pop(c,None);return send(c,'🟢 Configuración guardada.',MONETIZATION)", "if f=='monetag' and step=='sdk':dat['sdk']=t.strip();st['s']='reward';return send(c,'✅ Script guardado.\\n\\n<b>Paso 2:</b> Ahora copia el código de activación del formato <b>Rewarded Interstitial</b> (el bloque que contiene <code>show_XXXXXXX().then(...)</code>).\\n\\nPor favor, pégalo aquí y envíamelo.')\n if f=='monetag' and step=='reward':dat['reward']=t.strip();st['s']='url';return send(c,'🌐 <b>Paso 3</b>\\n\\nIngresa la URL de tu bot. Ejemplo:\\n<code>https://t.me/tu_bot</code>')\n if f=='monetag' and step=='url':dat['url']=t.strip();d['monetization']['monetag']=json.dumps(dat,ensure_ascii=False);save_db(d);STATE.pop(c,None);fn=generate_monetag_html(c,dat);send(c,'🟢 <b>Monetag configurado correctamente.</b>');return send_document(c,fn,'📄 HTML personalizado de Monetag.')\n if f=='adsgram' and step=='value':d['monetization']['adsgram']=t.strip();save_db(d);STATE.pop(c,None);return send(c,'🟢 Configuración de Adsgram guardada.',MONETIZATION)")
s=s.replace("'message_users','monetag','miniapp','domain'", "'message_users','monetag','adsgram','domain'")
# settings update button
s=s.replace("[{'text':'🛡️ Seguridad','callback_data':'security'},{'text':'🛠 Herramientas','callback_data':'tools'}]", "[{'text':'🛡️ Seguridad','callback_data':'security'},{'text':'🛠 Herramientas','callback_data':'tools'}],[{'text':'🔄 Actualizar sistema','callback_data':'system_update'}]")
needle="if x=='settings':"
insert="""if x=='system_update':
 cur,new,available=update_available();enabled=bool(d.get('auto_update',{}).get('enabled'));status='🟢 Nueva versión disponible' if available else '✅ Sin actualizaciones'
 text=f'🔄 <b>ACTUALIZACIÓN DEL SISTEMA</b>\\n\\n📌 Versión instalada: <b>{e(cur)}</b>\\n🆕 Nueva versión: <b>{e(new)}</b>\\n📡 Estado: <b>{status}</b>\\n🤖 Actualización automática: <b>'+('ACTIVADA' if enabled else 'DESACTIVADA')+'</b>'
 return edit(c,m,text,[[{'text':'⬇️ Actualizar ahora','callback_data':'system_update_now'}],[{'text':('⛔ Desactivar automática' if enabled else '🤖 Activar automática'),'callback_data':'auto_update_toggle'}],[{'text':'🔙 Ajustes','callback_data':'settings'}]])
 if x=='auto_update_toggle':d['auto_update']['enabled']=not bool(d.get('auto_update',{}).get('enabled'));d['auto_update']['checked_at']=0;save_db(d);return cb(c,m,u,i,'system_update')
 if x=='system_update_now':return run_update(c,False)
 """
s=s.replace(needle,insert+needle)
s=s.replace("threading.Thread(target=v2ray_expiration_monitor,daemon=True).start()", "threading.Thread(target=v2ray_expiration_monitor,daemon=True).start();threading.Thread(target=auto_update_monitor,daemon=True).start()")
p.write_text(s)
